///|
/// Ceiling on bytes for one embedded DOCX preview image.
let office_preview_max_image_bytes : Int = 4 * 1024 * 1024

///|
/// Ceiling on total embedded DOCX preview image bytes.
let office_preview_max_total_image_bytes : Int = 16 * 1024 * 1024

///|
/// Ceiling on the published preview document size.
let office_preview_max_output_bytes : Int = 32 * 1024 * 1024

///|
/// Row/column ceilings applied per XLSX sheet, mirrored into the report.
let office_preview_max_rows : Int = 1000

///|
let office_preview_max_cols : Int = 256

///|
/// Ceiling on converter warnings carried into the preview report.
let office_preview_max_warnings : Int = 64

///|
priv struct OfficePreviewStats {
  charts_rendered : Int
  charts_placeholder : Int
  truncated_sheets : Array[String]
  images_embedded : Int
  images_omitted : Int
  warnings : Array[String]
}

///|
fn office_preview_count_occurrences(text : String, needle : String) -> Int {
  guard needle.length() > 0 else { return 0 }
  let mut count = 0
  let mut position = 0
  while position < text.length() {
    match text[position:].find(needle) {
      Some(index) => {
        count += 1
        position += index + needle.length()
      }
      None => break
    }
  }
  count
}

///|
/// Renders the XLSX preview: the shared bounded HTML renderer plus a
/// truthful truncation/chart report computed from the workbook itself.
fn office_preview_render_xlsx(
  source : OfficeReadPackage,
) -> (String, OfficePreviewStats) raise {
  let workbook = open_xlsx_read_package(
    source,
    cancelled=office_async_cancelled,
  )
  let html = @xlsx2html.render_workbook(
    workbook,
    title=source.file,
    max_rows=office_preview_max_rows,
    max_cols=office_preview_max_cols,
    include_images=true,
  ) catch {
    error =>
      raise CliFailure(
        @lib.protocol_error(
          "office.xlsx.preview_failed",
          "XLSX preview rendering failed: " + bounded_text("\{error}", 240),
          details=Json::object({
            "file": Json::string(bounded_text(source.file, 160)),
          }),
        ),
      )
  }
  let truncated_sheets : Array[String] = []
  for name in workbook.get_sheet_list() {
    match workbook.sheet(name) {
      Some(worksheet) => {
        let bounds = worksheet.used_bounds_limited(
          maximum_stored_cells=office_read_max_parser_items,
          cancelled=office_async_cancelled,
        ) catch {
          ReadCancelled as error => raise error
          _ => continue
        }
        let (max_row, max_col) = bounds
        if max_row > office_preview_max_rows ||
          max_col > office_preview_max_cols {
          truncated_sheets.push(name)
        }
      }
      None => ()
    }
  }
  let stats : OfficePreviewStats = {
    charts_rendered: office_preview_count_occurrences(
      html, "<figure class=\"chart\"",
    ),
    charts_placeholder: office_preview_count_occurrences(
      html, "<figure class=\"chart-placeholder\"",
    ),
    truncated_sheets,
    images_embedded: office_preview_count_occurrences(
      html, "<figure class=\"image\"",
    ),
    images_omitted: 0,
    warnings: [],
  }
  (html, stats)
}

///|
/// Renders the DOCX preview: the shared HTML converter with bounded inline
/// data-URI images, wrapped into one portable page shell.
fn office_preview_render_docx(
  source : OfficeReadPackage,
) -> (String, OfficePreviewStats) raise {
  let mut total_image_bytes = 0
  let mut images_embedded = 0
  let mut images_omitted = 0
  let conversion = @word.convert_to_html(source.bytes, convert_image=image => {
    if image.data.length() > office_preview_max_image_bytes ||
      total_image_bytes + image.data.length() >
      office_preview_max_total_image_bytes {
      images_omitted += 1
      {
        nodes: [],
        messages: [
          @docx_core.warning(
            "preview image omitted by the bounded asset allowance",
          ),
        ],
      }
    } else {
      total_image_bytes += image.data.length()
      images_embedded += 1
      @word.data_uri_image(image)
    }
  }) catch {
    InvalidZip(message~)
    | InvalidXml(message~)
    | MissingPart(message~)
    | Unsupported(message~)
    | ResourceLimit(message~, ..) =>
      raise CliFailure(
        @lib.protocol_error(
          "office.docx.preview_failed",
          "DOCX preview rendering failed: " + bounded_text(message, 240),
          details=Json::object({
            "file": Json::string(bounded_text(source.file, 160)),
          }),
        ),
      )
  }
  let warnings : Array[String] = []
  for message in conversion.messages {
    if warnings.length() >= office_preview_max_warnings {
      break
    }
    let text = match message {
      Error(text) => text
      Warning(text) => text
    }
    warnings.push(bounded_text(text, 240))
  }
  let page = StringBuilder()
  page.write_string(
    "<!DOCTYPE html>\n<html>\n<head>\n<meta charset=\"utf-8\">\n",
  )
  page.write_string(
    "<title>" + @xlsx2html.escape_html(source.file) + "</title>\n<style>\n",
  )
  page.write_string(
    (
      #|body{font-family:Calibri,Arial,sans-serif;margin:24px;max-width:52em}
      #|img{max-width:100%}
      #|table{border-collapse:collapse}
      #|td,th{border:1px solid #d9d9d9;padding:2px 6px}
    ),
  )
  page.write_string("</style>\n</head>\n<body>\n")
  page.write_string(conversion.value)
  page.write_string("\n</body>\n</html>\n")
  let stats : OfficePreviewStats = {
    charts_rendered: 0,
    charts_placeholder: 0,
    truncated_sheets: [],
    images_embedded,
    images_omitted,
    warnings,
  }
  (page.to_string(), stats)
}

///|
fn office_preview_report(
  source : OfficeReadPackage,
  output : String,
  bytes_written : Int,
  stats : OfficePreviewStats,
) -> Json {
  let truncation : Map[String, Json] = {
    "max_rows": Json::number(office_preview_max_rows.to_double()),
    "max_cols": Json::number(office_preview_max_cols.to_double()),
    "truncated_sheets": Json::array(
      stats.truncated_sheets.map(name => Json::string(bounded_text(name, 80))),
    ),
    "images_omitted": Json::number(stats.images_omitted.to_double()),
  }
  let fields : Map[String, Json] = {
    "schema": Json::string(@lib.SCHEMA_PREVIEW_RESULT),
    "file": Json::string(bounded_text(source.file, 160)),
    "format": Json::string(source.format.name()),
    "output": Json::string(bounded_text(output, 160)),
    "bytes_written": Json::number(bytes_written.to_double()),
    "charts_rendered": Json::number(stats.charts_rendered.to_double()),
    "charts_placeholder": Json::number(stats.charts_placeholder.to_double()),
    "images_embedded": Json::number(stats.images_embedded.to_double()),
    "truncation": Json::object(truncation),
  }
  if !stats.warnings.is_empty() {
    fields["warnings"] = Json::array(
      stats.warnings.map(warning => Json::string(warning)),
    )
  }
  Json::object(fields)
}

///|
async fn run_preview(matches : @argparse.Matches) -> Unit {
  let file = required_value(matches, "file")
  let output = required_value(matches, "output")
  let overwrite = matches.flags.get_or_default("overwrite", false)
  let mode = office_validate_output_mode(matches)
  guard output.to_lower().has_suffix(".html") else {
    raise CliFailure(
      @lib.protocol_error(
        "office.invalid_arguments", "--output must end in .html so the preview artifact is unambiguous",
      ),
    )
  }
  let source = read_office_package(file, cancelled=office_async_cancelled)
  let (html, stats) = match source.format {
    Xlsx => office_preview_render_xlsx(source)
    Docx => office_preview_render_docx(source)
  }
  // a source file's stored strings can decode to isolated UTF-16
  // surrogates; encoding must stay total and the report must say so
  let (safe_html, replaced_units) = @xlsx2html.sanitize_utf16_lossy(html)
  if replaced_units > 0 {
    stats.warnings.push(
      "\{replaced_units} unpaired UTF-16 unit(s) replaced with U+FFFD",
    )
  }
  let payload = @utf8.encode(safe_html)
  if payload.length() > office_preview_max_output_bytes {
    raise CliFailure(
      @lib.protocol_error(
        "office.\{source.format.name()}.resource_limit",
        "preview output exceeds the configured limit",
        details=Json::object({
          "resource": Json::string("preview_output_bytes"),
          "limit": Json::number(office_preview_max_output_bytes.to_double()),
          "actual": Json::number(payload.length().to_double()),
        }),
      ),
    )
  }
  if overwrite {
    // replacement keeps the same staged-write path; the brief remove
    // window is documented in the capability constraints
    @afs.remove(output) catch {
      _ => ()
    }
  }
  @transaction.atomic_write_new(output, payload) catch {
    @transaction.TransactionError(..) as error =>
      raise transaction_failure(error)
    error => raise error
  }
  let report = office_preview_report(source, output, payload.length(), stats)
  match mode {
    JsonDocument => println(@lib.output_success(report).stringify(indent=2))
    JsonLines => println(@lib.output_success(report).stringify())
    Human =>
      println(
        "\{source.format.name()} preview written to " +
        human_text(output, 160) +
        " (\{payload.length()} bytes)",
      )
  }
}

///|
fn preview_command() -> @argparse.Command {
  let summary = match @lib.find_capability_command("preview") {
    Some(command) => command.summary
    None => "Render a deterministic offline HTML preview"
  }
  Command(
    "preview",
    about=summary,
    positionals=[
      PositionArg(
        "file",
        about="path to an .xlsx or .docx file",
        num_args=@argparse.ValueRange::single(),
      ),
    ],
    options=[OptionArg("output", long="output", about="destination .html path")],
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
