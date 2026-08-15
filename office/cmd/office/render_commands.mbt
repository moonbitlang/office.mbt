///|
// `office render`: a DOCX laid out and drawn as a paginated PDF.
//
// This is the seam where the page-layout engine meets the agent surface.
// `preview` already produces HTML, and that is a different artifact for a
// different question: HTML reflows, so it answers "what does this document
// say" and cannot answer "what is on page 3". Pagination is the whole point
// here, which is why the report leads with the page count and the page
// geometry rather than with bytes written.
//
// Byte determinism is per runtime, not across runtimes, and the report says
// so rather than leaving a caller to discover it. Rendering the same document
// twice on one backend is byte-identical; rendering it on native and on wasm
// is not, because `pdflite/flate` compresses through the vendored miniz on
// native and through its own encoder elsewhere. The *document* is the same --
// same pages, same glyph positions, same embedded font subset -- and that is
// the property a caller can rely on and the one the cross-runtime gate
// checks.

///|
/// Ceiling on the published PDF size.
let office_render_max_output_bytes : Int = 64 * 1024 * 1024

///|
/// Ceiling on engine notices carried into the report.
let office_render_max_notices : Int = 64

///|
priv struct OfficeRenderStats {
  pages : Int
  width_pt : Double
  height_pt : Double
  fonts_embedded : Int
  unsupported : Array[String]
  unsupported_total : Int
  images_dropped : Int
}

///|
/// Lay out a DOCX and draw it as PDF.
///
/// `read_docx` rather than `render_docx`, for the same reason the pagelayout
/// CLI does it: the latter discards the frontend's record of what it could not
/// lay out. Content the frontend rejected never reaches the backend to be
/// counted there, so a dropped WMF image would otherwise be invisible in the
/// report -- and silently missing content is the worst thing a renderer can
/// do, because the output looks entirely plausible.
fn office_render_docx_pdf(
  source : OfficeReadPackage,
) -> (Bytes, OfficeRenderStats) raise {
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
  let payload = @pagelayout_pdf.render_pdf(model) catch {
    error =>
      raise CliFailure(
        @lib.protocol_error(
          "office.docx.render_failed",
          "cannot draw this document: \{error}",
        ),
      )
  }
  // an empty document still paginates to one page, so this is a real geometry
  // rather than a placeholder
  let (width_pt, height_pt) = match model.pages.get(0) {
    Some(page) => (page.width_pt, page.height_pt)
    None => (0.0, 0.0)
  }
  let unsupported_total = document.unsupported.length()
  let unsupported = []
  for notice in document.unsupported {
    if unsupported.length() >= office_render_max_notices {
      break
    }
    unsupported.push(office_preview_clean_text(notice))
  }
  let stats = {
    pages: model.pages.length(),
    width_pt,
    height_pt,
    fonts_embedded: model.fonts.length(),
    unsupported,
    unsupported_total,
    images_dropped: @pagelayout_pdf.unembeddable_images(model).length(),
  }
  (payload, stats)
}

///|
fn office_render_report(
  source : OfficeReadPackage,
  output : String,
  bytes_written : Int,
  stats : OfficeRenderStats,
) -> Json {
  Json::object({
    "schema": Json::string("office.render/1"),
    "file": Json::string(office_preview_clean_text(human_text(source.file, 512))),
    "format": Json::string(source.format.name()),
    "output": Json::string(office_preview_clean_text(human_text(output, 512))),
    "backend": Json::string("pdf"),
    "bytes_written": Json::number(bytes_written.to_double()),
    "pages": Json::number(stats.pages.to_double()),
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
    "byte_determinism": Json::string("per-runtime"),
  })
}

///|
async fn run_render(matches : @argparse.Matches) -> Unit {
  let file = required_value(matches, "file")
  let output = required_value(matches, "output")
  let overwrite = matches.flags.get_or_default("overwrite", false)
  let mode = office_validate_output_mode(matches)
  guard output.to_lower().has_suffix(".pdf") else {
    raise CliFailure(
      @lib.protocol_error(
        "office.invalid_arguments", "--output must end in .pdf so the rendered artifact is unambiguous",
      ),
    )
  }
  let source = read_office_package(file, cancelled=office_async_cancelled)
  // XLSX has no frontend into the layout engine yet. Refusing by name beats
  // rendering a blank page, and beats a generic parse failure that reads like
  // the workbook is broken.
  guard source.format is Docx else {
    raise CliFailure(
      @lib.protocol_error(
        "office.xlsx.unsupported", "render currently produces PDF from DOCX only; the layout engine has no XLSX frontend",
      ),
    )
  }
  let (payload, stats) = office_render_docx_pdf(source)
  if payload.length() > office_render_max_output_bytes {
    raise CliFailure(
      @lib.protocol_error(
        "office.docx.resource_limit",
        "rendered output exceeds the configured limit",
        details=Json::object({
          "resource": Json::string("render_output_bytes"),
          "limit": Json::number(office_render_max_output_bytes.to_double()),
          "actual": Json::number(payload.length().to_double()),
        }),
      ),
    )
  }
  if overwrite {
    @afs.remove(output) catch {
      _ => ()
    }
  }
  @transaction.atomic_write_new(output, payload) catch {
    @transaction.TransactionError(..) as error => raise transaction_failure(error)
    error => raise error
  }
  let report = office_render_report(source, output, payload.length(), stats)
  match mode {
    JsonDocument => println(@lib.output_success(report).stringify(indent=2))
    JsonLines => println(@lib.output_success(report).stringify())
    Human =>
      println(
        "docx rendered to " +
        office_preview_clean_text(human_text(output, 160)) +
        " (\{stats.pages} page(s), \{payload.length()} bytes)",
      )
  }
}

///|
fn render_command() -> @argparse.Command {
  let summary = match @lib.find_capability_command("render") {
    Some(command) => command.summary
    None => "Render a DOCX as a paginated PDF"
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
    options=[OptionArg("output", long="output", about="destination .pdf path")],
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
