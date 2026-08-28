///|
// `office render`: a DOCX laid out and drawn as paginated PDF or SVG.
//
// This is the seam where the page-layout engine meets the agent surface.
// `preview` already produces HTML, and that is a different artifact for a
// different question: HTML reflows, so it answers "what does this document
// say" and cannot answer "what is on page 3". Pagination is the whole point
// here, which is why the report leads with page counts rather than bytes.
//
// The two backends answer different questions too. PDF is the deliverable --
// one file, embedded fonts, what a person opens. SVG is the readable one: an
// agent can diff it, grep it for a string, and see the coordinates a glyph
// was placed at, none of which a compressed PDF allows.
//
// Byte determinism is per runtime, not across runtimes, and the report says
// so rather than leaving a caller to discover it. Rendering the same document
// twice on one backend is byte-identical; rendering it on native and on wasm
// is not, because `pdflite/flate` compresses through the vendored miniz on
// native and through its own encoder elsewhere. The *document* is the same --
// same pages, same glyph positions, same embedded font subset. SVG is not
// compressed and so does not have even that difference.

///|
/// Ceiling on one published artifact.
let office_render_max_output_bytes : Int = 64 * 1024 * 1024

///|
/// Ceiling on engine notices carried into the report.
let office_render_max_notices : Int = 64

///|
/// Ceiling on pages one invocation may publish, so a pathological document
/// cannot turn one command into thousands of files.
let office_render_max_pages : Int = 2048

///|
/// Ceiling on the total bytes one invocation may publish across every
/// artifact.
///
/// A per-file limit alone does not bound the work. One image referenced from
/// every page produces a set that is arbitrarily large while every member
/// stays comfortably under the per-file cap.
let office_render_max_total_bytes : Int64 = 256L * 1024L * 1024L

///|
/// Ceiling on one engine notice, so a pathological message cannot make the
/// report unbounded through a field that is otherwise bounded only by count.
let office_render_max_notice_chars : Int = 512

///|
priv enum OfficeRenderBackend {
  RenderPdf
  RenderSvg
}

///|
fn OfficeRenderBackend::name(self : OfficeRenderBackend) -> String {
  match self {
    RenderPdf => "pdf"
    RenderSvg => "svg"
  }
}

///|
priv struct OfficeRenderStats {
  pages_total : Int
  pages_rendered : Int
  width_pt : Double
  height_pt : Double
  fonts_used : Int
  unsupported : Array[String]
  unsupported_total : Int
  images_dropped : Int
}

///|
/// The destination extension chooses the backend. A separate `--format` flag
/// would let the two disagree, and there is no reading of `--output page.svg
/// --format pdf` worth honouring.
fn office_render_backend(output : String) -> OfficeRenderBackend raise {
  let lower = output.to_lower()
  if lower.has_suffix(".pdf") {
    RenderPdf
  } else if lower.has_suffix(".svg") {
    RenderSvg
  } else {
    raise CliFailure(
      @lib.protocol_error(
        "office.invalid_arguments", "--output must end in .pdf or .svg so the rendered artifact is unambiguous",
      ),
    )
  }
}

///|
/// The one refusal every `--pages` rejection reports, so a caller sees the
/// same message whether the spec was malformed, reversed, or out of range.
fn office_render_pages_error(total : Int) -> @lib.ProtocolError {
  @lib.protocol_error(
    "office.invalid_arguments",
    "--pages must be 1-based pages or N-M ranges separated by commas, within the document's \{total} page(s)",
  )
}

///|
/// One page number from `--pages`, validated against the document length.
fn office_render_page_number(text : StringView, total : Int) -> Int raise {
  guard text.length() > 0 && text.length() <= 7 else {
    raise CliFailure(office_render_pages_error(total))
  }
  let mut value = 0
  for char in text {
    guard char is ('0'..='9') else {
      raise CliFailure(office_render_pages_error(total))
    }
    value = value * 10 + (char.to_int() - '0'.to_int())
  }
  guard value >= 1 && value <= total else {
    raise CliFailure(office_render_pages_error(total))
  }
  value
}

///|
/// Parse `--pages`: a comma-separated list of 1-based pages and `N-M` ranges,
/// resolved against a document of `total` pages.
///
/// Returns page numbers in ascending order with duplicates removed, so
/// `3,1-2,3` and `1-3` select the same pages and publish the same files. An
/// agent composing a range from other output should not have to normalise it
/// first, and should not be able to publish page 3 twice by failing to.
fn office_render_parse_pages(spec : String, total : Int) -> Array[Int] raise {
  let selected : Map[Int, Unit] = Map([])
  for part in spec.split(",") {
    let trimmed = part.trim()
    guard trimmed.length() > 0 else {
      raise CliFailure(office_render_pages_error(total))
    }
    match trimmed.find("-") {
      Some(dash) => {
        let low = office_render_page_number(trimmed[0:dash], total)
        let high = office_render_page_number(trimmed[dash + 1:], total)
        guard low <= high else {
          raise CliFailure(office_render_pages_error(total))
        }
        for page in low..<=high {
          selected[page] = ()
        }
      }
      None => selected[office_render_page_number(trimmed, total)] = ()
    }
  }
  let pages = []
  for page in 1..<=total {
    if selected.contains(page) {
      pages.push(page)
    }
  }
  guard pages.length() > 0 else {
    raise CliFailure(office_render_pages_error(total))
  }
  pages
}

///|
/// Lay out a DOCX into a page model.
///
/// `read_docx` rather than `render_docx`, for the same reason the pagelayout
/// CLI does it: the latter discards the frontend's record of what it could not
/// lay out. Content the frontend rejected never reaches the backend to be
/// counted there, so a dropped WMF image would otherwise be invisible in the
/// report -- and silently missing content is the worst thing a renderer can
/// do, because the output looks entirely plausible.
fn office_render_layout(
  source : OfficeReadPackage,
) -> (@pagelayout.PageModel, Array[String]) raise {
  let document = @pagelayout_docx.read_docx(source.bytes) catch {
    error =>
      raise CliFailure(
        @lib.protocol_error(
          "office.docx.render_failed",
          "cannot lay out this document: \{error}",
        ),
      )
  }
  let model = @paginate.paginate(
    document.blocks,
    section=document.section,
    furniture=document.furniture,
  )
  (model, document.unsupported)
}

///|
/// The model restricted to `pages`, keeping the font table intact.
///
/// Glyph runs address fonts by index into `model.fonts`, so the table has to
/// travel whole: dropping the faces an unselected page used would renumber
/// the rest and repaint every remaining page in the wrong typeface.
fn office_render_select(
  model : @pagelayout.PageModel,
  pages : Array[Int],
) -> @pagelayout.PageModel {
  let selected = []
  for page in pages {
    selected.push(model.pages[page - 1])
  }
  { fonts: model.fonts, pages: selected, }
}

///|
/// Faces the selected pages actually reference.
///
/// Not `selected.fonts.length()`: the font table is deliberately carried
/// whole so glyph runs keep their original indices, so its length describes
/// the document rather than the selection. Rendering page 1 of a document
/// whose later pages introduce other faces would otherwise report those too.
fn office_render_font_count(selected : @pagelayout.PageModel) -> Int {
  let seen : Map[Int, Unit] = Map([])
  for page in selected.pages {
    for item in page.items {
      if item is Text(run) {
        seen[run.font] = ()
      }
    }
  }
  seen.length()
}

///|
fn office_render_stats(
  model : @pagelayout.PageModel,
  selected : @pagelayout.PageModel,
  backend : OfficeRenderBackend,
  unsupported_all : Array[String],
) -> OfficeRenderStats {
  let (width_pt, height_pt) = match selected.pages.get(0) {
    Some(page) => (page.width_pt, page.height_pt)
    None => (0.0, 0.0)
  }
  let unsupported = []
  for notice in unsupported_all {
    if unsupported.length() >= office_render_max_notices {
      break
    }
    unsupported.push(
      office_preview_clean_text(
        human_text(notice, office_render_max_notice_chars),
      ),
    )
  }
  {
    pages_total: model.pages.length(),
    pages_rendered: selected.pages.length(),
    width_pt,
    height_pt,
    fonts_used: office_render_font_count(selected),
    unsupported,
    unsupported_total: unsupported_all.length(),
    // "which images can this backend not embed" is a PDF question. SVG
    // embeds every image as a data URI, so asking the PDF checker about an
    // SVG render would report a malformed PNG as dropped while it sits in
    // the output. One entry per distinct reason carries its own occurrence
    // count, so the image count is the sum and not the entry count.
    images_dropped: match backend {
      RenderPdf => {
        let mut total = 0
        for entry in @pagelayout_pdf.unembeddable_images(selected) {
          total = total + entry.1
        }
        total
      }
      RenderSvg => 0
    },
  }
}

///|
/// Where page `index` of `total` is published.
///
/// One page writes to `output` verbatim; several write `<stem>-<n>`. This is
/// the convention `pagelayout/cmd/pagelayout` already uses, and matching it
/// matters more than any improvement on it -- an agent that learns one of
/// these tools should not have to learn the other's file naming.
fn office_render_page_path(
  output : String,
  page : Int,
  total : Int,
  suffix : String,
) -> String {
  if total <= 1 {
    return output
  }
  let stem = if output.to_lower().has_suffix(suffix) {
    output[0:output.length() - suffix.length()].to_owned()
  } else {
    output
  }
  "\{stem}-\{page}\{suffix}"
}

///|
/// Refuse every destination that already exists, before anything is drawn.
///
/// This is what keeps the common multi-file failure whole. Publishing page 5
/// into an occupied path after pages 1-4 have landed leaves a set that is
/// half new and half old, and no error envelope can put that back. Checking
/// first turns it into a refusal with nothing written.
///
/// It is a check, not a lock: a path created between here and publication is
/// still caught by the create-new transaction, which is the guarantee that
/// actually holds.
async fn office_render_preflight(
  paths : Array[String],
  overwrite : Bool,
) -> Unit {
  if overwrite {
    return
  }
  for path in paths {
    let taken = @afs.exists(path) catch { _ => false }
    if taken {
      raise CliFailure(
        @lib.protocol_error(
          "office.transaction.output_exists",
          "destination already exists",
          details=Json::object({
            "output": Json::string(human_text(path, 512)),
            "outputs_planned": Json::number(paths.length().to_double()),
          }),
        ),
      )
    }
  }
}

///|
/// Publish one artifact through the shared create-new transaction, charging
/// it against the invocation's aggregate byte budget.
///
/// `published` is threaded through so a failure part-way into a multi-file
/// render can name what already landed. A caller that cannot see that has to
/// guess which files to clean up.
async fn office_render_publish(
  path : String,
  payload : Bytes,
  overwrite : Bool,
  written : Int64,
  published : Array[String],
) -> Int64 {
  let total = written + payload.length().to_int64()
  if payload.length() > office_render_max_output_bytes ||
    total > office_render_max_total_bytes {
    raise CliFailure(
      @lib.protocol_error(
        "office.docx.resource_limit",
        "rendered output exceeds the configured limit",
        details=Json::object({
          "resource": Json::string(
            if payload.length() > office_render_max_output_bytes {
              "render_output_bytes"
            } else {
              "render_total_bytes"
            },
          ),
          "limit": Json::number(
            if payload.length() > office_render_max_output_bytes {
              office_render_max_output_bytes.to_double()
            } else {
              office_render_max_total_bytes.to_double()
            },
          ),
          "actual": Json::number(
            if payload.length() > office_render_max_output_bytes {
              payload.length().to_double()
            } else {
              total.to_double()
            },
          ),
          "output": Json::string(human_text(path, 512)),
          "published": Json::array(
            published.map(done => Json::string(human_text(done, 512))),
          ),
        }),
      ),
    )
  }
  if overwrite {
    @afs.remove(path) catch {
      _ => ()
    }
  }
  // Preflight cannot make this whole. It is a check and not a lock, so a
  // destination can appear afterwards; and --overwrite skips it entirely,
  // since "already there" is not a failure in that mode. Either way a page
  // can fail after earlier pages have landed, and a refusal naming only the
  // page that failed leaves a caller guessing which files to clean up. So
  // once anything has been published, the refusal carries the list.
  @transaction.atomic_write_new(path, payload) catch {
    // Only a transaction failure becomes a publication report. Anything else
    // -- cancellation above all -- keeps its own meaning: turning a cancelled
    // run into "publication failed" would misreport why it stopped, and a
    // list of published pages is not worth that.
    @transaction.TransactionError(..) as inner =>
      if published.length() == 0 {
        raise transaction_failure(inner)
      } else {
        raise CliFailure(
          @lib.protocol_error(
            "office.render.partial_publication",
            "publication failed after earlier pages were already written",
            details=Json::object({
              "output": Json::string(human_text(path, 512)),
              "published": Json::array(
                published.map(done => Json::string(human_text(done, 512))),
              ),
            }),
          ),
        )
      }
    other => raise other
  }
  published.push(path)
  total
}

///|
fn office_render_report(
  source : OfficeReadPackage,
  backend : OfficeRenderBackend,
  outputs : Array[(String, Int)],
  written : Int64,
  stats : OfficeRenderStats,
) -> Json {
  Json::object({
    "schema": Json::string("office.render/1"),
    "file": Json::string(
      office_preview_clean_text(human_text(source.file, 512)),
    ),
    "format": Json::string(source.format.name()),
    "backend": Json::string(backend.name()),
    "outputs": Json::array(
      outputs.map(entry => {
        Json::object({
          "path": Json::string(
            office_preview_clean_text(human_text(entry.0, 512)),
          ),
          "bytes_written": Json::number(entry.1.to_double()),
        })
      }),
    ),
    "bytes_written": Json::number(written.to_double()),
    "pages_rendered": Json::number(stats.pages_rendered.to_double()),
    "pages_total": Json::number(stats.pages_total.to_double()),
    "page_width_pt": Json::number(stats.width_pt),
    "page_height_pt": Json::number(stats.height_pt),
    "fonts_used": Json::number(stats.fonts_used.to_double()),
    "images_dropped": Json::number(stats.images_dropped.to_double()),
    "unsupported": Json::array(
      stats.unsupported.map(notice => Json::string(notice)),
    ),
    "unsupported_total": Json::number(stats.unsupported_total.to_double()),
    // stated rather than left to be discovered: identical within one runtime,
    // not across them, because the deflate implementation differs by backend
    "byte_determinism": Json::string(
      match backend {
        RenderPdf => "per-runtime"
        RenderSvg => "cross-runtime"
      },
    ),
  })
}

///|
async fn run_render(matches : @argparse.Matches) -> Unit {
  let file = required_value(matches, "file")
  let output = required_value(matches, "output")
  let overwrite = matches.flags.get_or_default("overwrite", false)
  let mode = office_validate_output_mode(matches)
  let backend = office_render_backend(output)
  let source = read_office_package(file, cancelled=office_async_cancelled)
  // XLSX has no frontend into the layout engine yet. Refusing by name beats
  // rendering a blank page, and beats a generic parse failure that reads like
  // the workbook is broken.
  guard source.format is Docx else {
    raise CliFailure(
      @lib.protocol_error(
        "office.xlsx.unsupported", "render currently draws DOCX only; the layout engine has no XLSX frontend",
      ),
    )
  }
  let (model, unsupported) = office_render_layout(source)
  let pages = match matches.values.get("pages") {
    Some(values) if values.length() == 1 =>
      office_render_parse_pages(values[0], model.pages.length())
    _ => {
      let all = []
      for page in 1..<=model.pages.length() {
        all.push(page)
      }
      all
    }
  }
  guard pages.length() <= office_render_max_pages else {
    raise CliFailure(
      @lib.protocol_error(
        "office.docx.resource_limit",
        "render would publish more pages than the configured limit",
        details=Json::object({
          "resource": Json::string("render_pages"),
          "limit": Json::number(office_render_max_pages.to_double()),
          "actual": Json::number(pages.length().to_double()),
        }),
      ),
    )
  }
  let selected = office_render_select(model, pages)
  let stats = office_render_stats(model, selected, backend, unsupported)
  let outputs : Array[(String, Int)] = []
  let published : Array[String] = []
  let mut written : Int64 = 0
  match backend {
    RenderPdf => {
      office_render_preflight([output], overwrite)
      let payload = @pagelayout_pdf.render_pdf(selected) catch {
        error =>
          raise CliFailure(
            @lib.protocol_error(
              "office.docx.render_failed",
              "cannot draw this document: \{error}",
            ),
          )
      }
      written = office_render_publish(
        output, payload, overwrite, written, published,
      )
      outputs.push((output, payload.length()))
    }
    RenderSvg => {
      // Destinations are checked before a single page is drawn, so the
      // ordinary "one of these already exists" failure publishes nothing at
      // all rather than leaving a set that is part new and part old.
      let paths = []
      for page in pages {
        paths.push(
          office_render_page_path(output, page, pages.length(), ".svg"),
        )
      }
      office_render_preflight(paths, overwrite)
      // One page at a time. Materializing every page first would hold the
      // whole render in memory, which one image repeated across many pages
      // turns into gigabytes while each individual file stays well under the
      // per-file cap.
      for index, page in pages {
        let document = @pagelayout_svg.render_page(selected, index)
        let payload = @utf8.encode(document)
        written = office_render_publish(
          paths[index],
          payload,
          overwrite,
          written,
          published,
        )
        outputs.push((paths[index], payload.length()))
        ignore(page)
      }
    }
  }
  let report = office_render_report(source, backend, outputs, written, stats)
  match mode {
    JsonDocument => println(@lib.output_success(report).stringify(indent=2))
    JsonLines => println(@lib.output_success(report).stringify())
    Human =>
      println(
        "docx rendered to \{outputs.length()} \{backend.name()} file(s), " +
        "\{stats.pages_rendered} of \{stats.pages_total} page(s), \{written} bytes",
      )
  }
}

///|
fn render_command() -> @argparse.Command {
  let summary = match @lib.find_capability_command("render") {
    Some(command) => command.summary
    None => "Render a DOCX as paginated PDF or SVG"
  }
  Command(
    "render",
    about=summary,
    positionals=[
      PositionArg(
        "file",
        about="path to a .docx file",
        num_args=@argparse.ValueRange::single(),
      ),
    ],
    options=[
      OptionArg("output", long="output", about="destination .pdf or .svg path"),
      OptionArg(
        "pages",
        long="pages",
        about="pages to render, e.g. 3 or 2-5 or 1,4-6",
      ),
    ],
    flags=[
      FlagArg(
        "overwrite",
        long="overwrite",
        about="replace an existing destination",
      ),
      FlagArg("json", long="json", about="print office.output/1 JSON"),
      FlagArg("jsonl", long="jsonl", about="print one office.output/1 line"),
    ],
  )
}
