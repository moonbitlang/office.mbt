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
  fonts_embedded : Int
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
    let trimmed = part.trim_space()
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
  { fonts: model.fonts, pages: selected }
}

///|
fn office_render_stats(
  model : @pagelayout.PageModel,
  selected : @pagelayout.PageModel,
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
    unsupported.push(office_preview_clean_text(notice))
  }
  {
    pages_total: model.pages.length(),
    pages_rendered: selected.pages.length(),
    width_pt,
    height_pt,
    fonts_embedded: selected.fonts.length(),
    unsupported,
    unsupported_total: unsupported_all.length(),
    images_dropped: @pagelayout_pdf.unembeddable_images(selected).length(),
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
/// Publish one artifact through the shared create-new transaction.
async fn office_render_publish(
  path : String,
  payload : Bytes,
  overwrite : Bool,
) -> Unit {
  if payload.length() > office_render_max_output_bytes {
    raise CliFailure(
      @lib.protocol_error(
        "office.docx.resource_limit",
        "rendered output exceeds the configured limit",
        details=Json::object({
          "resource": Json::string("render_output_bytes"),
          "limit": Json::number(office_render_max_output_bytes.to_double()),
          "actual": Json::number(payload.length().to_double()),
          "output": Json::string(human_text(path, 512)),
        }),
      ),
    )
  }
  if overwrite {
    @afs.remove(path) catch {
      _ => ()
    }
  }
  @transaction.atomic_write_new(path, payload) catch {
    @transaction.TransactionError(..) as error =>
      raise transaction_failure(error)
    error => raise error
  }
}

///|
fn office_render_report(
  source : OfficeReadPackage,
  backend : OfficeRenderBackend,
  outputs : Array[(String, Int)],
  stats : OfficeRenderStats,
) -> Json {
  let mut written = 0
  for entry in outputs {
    written = written + entry.1
  }
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
    "fonts_embedded": Json::number(stats.fonts_embedded.to_double()),
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
  let stats = office_render_stats(model, selected, unsupported)
  let outputs : Array[(String, Int)] = []
  match backend {
    RenderPdf => {
      let payload = @pagelayout_pdf.render_pdf(selected) catch {
        error =>
          raise CliFailure(
            @lib.protocol_error(
              "office.docx.render_failed",
              "cannot draw this document: \{error}",
            ),
          )
      }
      office_render_publish(output, payload, overwrite)
      outputs.push((output, payload.length()))
    }
    RenderSvg => {
      // Publication is per file. With more than one page this is not a single
      // atomic swap: an interruption can leave earlier pages published and
      // later ones absent. Each individual file is still created atomically
      // and never half-written, and the report lists exactly what landed.
      let documents = @pagelayout_svg.render_pages(selected)
      for index, document in documents {
        let path = office_render_page_path(
          output,
          pages[index],
          documents.length(),
          ".svg",
        )
        let payload = @utf8.encode(document)
        office_render_publish(path, payload, overwrite)
        outputs.push((path, payload.length()))
      }
    }
  }
  let report = office_render_report(source, backend, outputs, stats)
  match mode {
    JsonDocument => println(@lib.output_success(report).stringify(indent=2))
    JsonLines => println(@lib.output_success(report).stringify())
    Human => {
      let mut written = 0
      for entry in outputs {
        written = written + entry.1
      }
      println(
        "docx rendered to \{outputs.length()} \{backend.name()} file(s), " +
        "\{stats.pages_rendered} of \{stats.pages_total} page(s), \{written} bytes",
      )
    }
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
