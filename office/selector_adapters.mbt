///|
fn legacy_selector_error(path : String, message : String) -> SelectorError {
  SelectorError(
    code="office.selector.legacy_docx",
    offset=0,
    input=bounded_selector_text(path, 160),
    message=bounded_selector_text(message, 320),
  )
}

///|
fn check_legacy_selector_length(path : String) -> Unit raise SelectorError {
  let mut length = 0
  for _ in path {
    length = length + 1
    if length > SELECTOR_MAX_LENGTH {
      raise SelectorError(
        code="office.selector.too_long",
        offset=SELECTOR_MAX_LENGTH,
        input=bounded_selector_text(path, 160),
        message="selector exceeds \{SELECTOR_MAX_LENGTH} characters",
      )
    }
  }
}

///|
fn append_docx_root(output : StringBuilder, root : @docxpaths.PathRoot) -> Unit {
  match root {
    Body => output.write_string("/docx/body") |> ignore
    Header(index) => output.write_string("/docx/header[\{index}]") |> ignore
    Footer(index) => output.write_string("/docx/footer[\{index}]") |> ignore
    Footnotes => output.write_string("/docx/footnotes") |> ignore
    Endnotes => output.write_string("/docx/endnotes") |> ignore
    Comments => output.write_string("/docx/comments") |> ignore
  }
}

///|
fn append_docx_step(output : StringBuilder, step : @docxpaths.PathStep) -> Unit {
  output.write_char('/') |> ignore
  output.write_string(step.kind) |> ignore
  match step.selector {
    Ordinal(index) => output.write_string("[\{index}]") |> ignore
    ById(id) => {
      output.write_string("[id=") |> ignore
      output.write_string(Json::string(id).stringify()) |> ignore
      output.write_char(']') |> ignore
    }
  }
}

///|
/// Converts the DOCX projection paths already emitted by `docx text` and
/// `docx get` into the shared canonical selector AST. This adapts syntax only;
/// it does not load a package or resolve the path.
pub fn selector_from_docx_projection_path(
  path : String,
) -> OfficeSelector raise SelectorError {
  check_legacy_selector_length(path)
  let parsed = @docxpaths.parse_path(path) catch {
    PathError(message) => raise legacy_selector_error(path, message)
  }
  let canonical = StringBuilder::new()
  append_docx_root(canonical, parsed.root)
  for step in parsed.steps {
    append_docx_step(canonical, step)
  }
  parse_selector(canonical.to_string())
}

///|
fn selector_for_xlsx_coordinate(
  sheet_name : String,
  leaf : String,
  reference : String,
) -> OfficeSelector raise SelectorError {
  parse_selector(
    "/xlsx/sheet[name=\{Json::string(sheet_name).stringify()}]/\{leaf}[\{reference}]",
  )
}

///|
/// Builds a canonical, syntax-validated selector for one cell on a named
/// worksheet. It does not look up the sheet or cell in a workbook.
pub fn selector_for_xlsx_cell(
  sheet_name : String,
  address : String,
) -> OfficeSelector raise SelectorError {
  selector_for_xlsx_coordinate(sheet_name, "cell", address)
}

///|
/// Builds a canonical, normalized selector for one rectangular range on a
/// named worksheet. It does not look up the sheet or range in a workbook.
pub fn selector_for_xlsx_range(
  sheet_name : String,
  range : String,
) -> OfficeSelector raise SelectorError {
  selector_for_xlsx_coordinate(sheet_name, "range", range)
}
