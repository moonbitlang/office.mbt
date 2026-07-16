///|
enum XlsxCellFilter {
  PresentCells
  TextCells
  QueryCells(Array[XlsxCellPredicate])
}

///|
struct XlsxCellPage {
  cells : Array[XlsxCellSnapshot]
  matched_total : Int
  scanned_cells : Int
  offset : Int
  limit : Int
}

///|
fn xlsx_sheet_state_name(state : @xlsx.SheetState) -> String {
  match state {
    Visible => "visible"
    Hidden => "hidden"
    VeryHidden => "very-hidden"
  }
}

///|
fn xlsx_conditional_format_range_count(
  projection : XlsxProjection,
  sheet : String,
) -> Int raise CliFailure {
  let formats = xlsx_call(projection.file, () => {
    projection.workbook.get_conditional_formats(sheet)
  })
  let mut count = 0
  for ranges, _ in formats {
    for part in ranges.split(" ") {
      if part.length() > 0 {
        count += 1
      }
    }
  }
  count
}

///|
fn xlsx_sheet_summary_json(
  projection : XlsxProjection,
  sheet : XlsxSheetTarget,
  metadata : XlsxMetadataBudget,
) -> Json raise CliFailure {
  metadata.charge_item([sheet.name, sheet.path])
  let fields : Map[String, Json] = {
    "path": Json::string(sheet.path),
    "name": Json::string(sheet.name),
    "index": Json::number((sheet.index + 1).to_double()),
  }
  match sheet.content {
    ChartSheet(chart_sheet) => {
      fields["kind"] = Json::string("chart-sheet")
      fields["state"] = Json::string(xlsx_sheet_state_name(chart_sheet.state()))
      fields["counts"] = Json::object({ "charts": Json::number(1) })
    }
    Worksheet(worksheet) => {
      fields["kind"] = Json::string("worksheet")
      fields["state"] = Json::string(xlsx_sheet_state_name(worksheet.state()))
      let max_row = worksheet.max_row()
      let max_col = worksheet.max_col()
      fields["max_row"] = Json::number(max_row.to_double())
      fields["max_column"] = Json::number(max_col.to_double())
      match xlsx_used_rect(worksheet) {
        Some(rect) => {
          let reference = rect.reference(projection.file)
          let path = canonical_xlsx_range_path(sheet.name, reference)
          metadata.charge_item([reference, path])
          fields["used_range"] = Json::object({
            "path": Json::string(path),
            "reference": Json::string(reference),
            "cell_count": Json::number(rect.cell_count().to_double()),
          })
        }
        None => ()
      }
      let merges = xlsx_call(projection.file, () => {
        projection.workbook.get_merge_cells(sheet.name)
      })
      let tables = xlsx_call(projection.file, () => {
        projection.workbook.get_tables(sheet.name)
      })
      let comments = xlsx_call(projection.file, () => {
        projection.workbook.get_comments(sheet.name)
      })
      let hyperlinks = xlsx_call(projection.file, () => {
        projection.workbook.get_hyperlink_cells(sheet.name)
      })
      let validations = xlsx_call(projection.file, () => {
        projection.workbook.get_data_validations(sheet.name)
      })
      let pivots = xlsx_call(projection.file, () => {
        projection.workbook.get_pivot_tables(sheet.name)
      })
      let slicers = xlsx_call(projection.file, () => {
        projection.workbook.get_slicers(sheet.name)
      })
      fields["counts"] = Json::object({
        "merges": Json::number(merges.length().to_double()),
        "tables": Json::number(tables.length().to_double()),
        "charts": Json::number(worksheet.charts().length().to_double()),
        "images": Json::number(worksheet.images().length().to_double()),
        "pivot_tables": Json::number(pivots.length().to_double()),
        "comments": Json::number(comments.length().to_double()),
        "hyperlinks": Json::number(hyperlinks.length().to_double()),
        "data_validations": Json::number(validations.length().to_double()),
        "conditional_format_ranges": Json::number(
          xlsx_conditional_format_range_count(projection, sheet.name).to_double(),
        ),
        "slicers": Json::number(slicers.length().to_double()),
      })
    }
  }
  Json::object(fields)
}

///|
fn xlsx_outline_data(projection : XlsxProjection) -> Json raise CliFailure {
  let metadata = XlsxMetadataBudget::new()
  let sheets : Array[Json] = []
  for name in projection.sheet_names {
    match projection.find_sheet_by_name(name) {
      Some(sheet) =>
        sheets.push(xlsx_sheet_summary_json(projection, sheet, metadata))
      None =>
        raise xlsx_cli_failure(
          "office.xlsx.read_failed",
          "workbook tab order contains an unresolved sheet",
          details=Json::object({
            "sheet": Json::string(bounded_text(name, 160)),
          }),
        )
    }
  }
  let defined_names : Array[Json] = []
  for defined in projection.workbook.get_defined_names() {
    metadata.charge_item([
      defined.name,
      defined.refers_to,
      defined.scope,
      defined.comment,
    ])
    let fields : Map[String, Json] = {
      "name": Json::string(defined.name),
      "refers_to": Json::string(defined.refers_to),
    }
    if defined.scope != "" {
      fields["scope"] = Json::string(defined.scope)
    }
    if defined.comment != "" {
      fields["comment"] = Json::string(defined.comment)
    }
    defined_names.push(Json::object(fields))
  }
  let fields : Map[String, Json] = {
    "schema": Json::string(@lib.SCHEMA_XLSX_OUTLINE),
    "file": Json::string(projection.file),
    "format": Json::string("xlsx"),
    "path": Json::string("/xlsx/workbook"),
    "sheet_count": Json::number(sheets.length().to_double()),
    "sheets": Json::array(sheets),
    "defined_names": Json::array(defined_names),
    "limits": Json::object({
      "max_scan_cells": Json::number(projection.max_scan_cells.to_double()),
      "max_metadata_items": Json::number(metadata.maximum_items.to_double()),
      "max_metadata_string_chars": Json::number(
        metadata.maximum_string_chars.to_double(),
      ),
    }),
  }
  if !projection.sheet_names.is_empty() {
    let active_index = projection.workbook.get_active_sheet_index()
    match projection.sheet_names.get(active_index) {
      Some(name) =>
        match projection.find_sheet_by_name(name) {
          Some(sheet) =>
            fields["active_sheet"] = Json::object({
              "path": Json::string(sheet.path),
              "name": Json::string(sheet.name),
              "index": Json::number((sheet.index + 1).to_double()),
            })
          None => ()
        }
      None => ()
    }
  }
  Json::object(fields)
}

///|
fn xlsx_outline_payload(
  projection : XlsxProjection,
  max_output_chars : Int,
) -> BoundedOfficePayload raise CliFailure {
  bounded_office_payload(
    xlsx_outline_data(projection),
    [],
    max_output_chars,
    "xlsx",
  )
}

///|
fn xlsx_raw_value_json(value : @xlsx.CellValue) -> Json {
  match value {
    String(text) =>
      Json::object({
        "type": Json::string("string"),
        "value": Json::string(text),
      })
    Numeric(number) =>
      Json::object({
        "type": Json::string("number"),
        "value": Json::number(number),
      })
    Bool(flag) =>
      Json::object({
        "type": Json::string("bool"),
        "value": Json::boolean(flag),
      })
    Error(code) =>
      Json::object({
        "type": Json::string("error"),
        "value": Json::string(code),
      })
  }
}

///|
fn xlsx_cell_json(cell : XlsxCellSnapshot) -> Json {
  let fields : Map[String, Json] = {
    "path": Json::string(cell.path),
    "reference": Json::string(cell.reference),
    "row": Json::number(cell.row.to_double()),
    "column": Json::number(cell.column.to_double()),
  }
  match cell.formatted {
    Some(value) => fields["value"] = Json::string(value)
    None => ()
  }
  match cell.raw {
    Some(value) => fields["raw"] = xlsx_raw_value_json(value)
    None => ()
  }
  match cell.formula {
    Some(value) => fields["formula"] = Json::string(value)
    None => ()
  }
  if cell.style_id != 0 {
    fields["style_id"] = Json::number(cell.style_id.to_double())
  }
  Json::object(fields)
}

///|
fn xlsx_styles_json(
  projection : XlsxProjection,
  cells : Array[XlsxCellSnapshot],
) -> Json raise CliFailure {
  let fields : Map[String, Json] = Map([])
  for cell in cells {
    if cell.style_id != 0 {
      let key = cell.style_id.to_string()
      if !fields.contains(key) {
        let style = xlsx_call(projection.file, () => {
          projection.workbook.get_style(cell.style_id)
        })
        fields[key] = @inspect.style_to_json(style)
      }
    }
  }
  Json::object(fields)
}

///|
fn xlsx_cell_text(cell : XlsxCellSnapshot) -> String? {
  match cell.formatted {
    Some(value) if value != "" => Some(value)
    _ =>
      match cell.formula {
        Some(formula) => Some("=" + formula)
        None => None
      }
  }
}

///|
fn XlsxCellFilter::matches(
  self : XlsxCellFilter,
  cell : XlsxCellSnapshot,
) -> Bool {
  match self {
    PresentCells => cell.is_present()
    TextCells => xlsx_cell_text(cell) is Some(_)
    QueryCells(predicates) => xlsx_cell_matches(cell, predicates)
  }
}

///|
fn collect_xlsx_cell_page(
  projection : XlsxProjection,
  regions : Array[XlsxScanRegion],
  filter : XlsxCellFilter,
  offset : Int,
  limit : Int,
) -> XlsxCellPage raise CliFailure {
  let scan = XlsxScanBudget::new(projection.max_scan_cells)
  let cells : Array[XlsxCellSnapshot] = []
  let mut matched = 0
  for region in regions {
    for row in region.rect.row_lo..<=region.rect.row_hi {
      for column in region.rect.col_lo..<=region.rect.col_hi {
        let cell = xlsx_cell_snapshot(
          projection,
          region.sheet,
          row,
          column,
          scan,
        )
        if filter.matches(cell) {
          if matched >= offset && cells.length() < limit {
            cells.push(cell)
          }
          matched += 1
        }
      }
    }
  }
  { cells, matched_total: matched, scanned_cells: scan.scanned, offset, limit }
}

///|
fn xlsx_page_fields(page : XlsxCellPage) -> Map[String, Json] {
  {
    "matched_total": Json::number(page.matched_total.to_double()),
    "offset": Json::number(page.offset.to_double()),
    "limit": Json::number(page.limit.to_double()),
    "returned": Json::number(page.cells.length().to_double()),
    "truncated": Json::boolean(
      page.offset + page.cells.length() < page.matched_total,
    ),
    "scanned_cells": Json::number(page.scanned_cells.to_double()),
  }
}

///|
fn xlsx_get_data(
  projection : XlsxProjection,
  resolved : XlsxResolvedSelector,
) -> Json raise CliFailure {
  match resolved {
    Workbook(path~) => {
      let outline = xlsx_outline_data(projection)
      guard outline is Object(outline_fields) else { abort("outline object") }
      Json::object({
        "schema": Json::string(@lib.SCHEMA_XLSX_ELEMENT),
        "file": Json::string(projection.file),
        "format": Json::string("xlsx"),
        "path": Json::string(path),
        "kind": Json::string("workbook"),
        "stability": Json::string("stable"),
        "sheet_count": outline_fields
        .get("sheet_count")
        .unwrap_or(Json::number(0)),
        "sheets": outline_fields.get("sheets").unwrap_or(Json::array([])),
        "defined_names": outline_fields
        .get("defined_names")
        .unwrap_or(Json::array([])),
      })
    }
    Sheet(sheet) =>
      Json::object({
        "schema": Json::string(@lib.SCHEMA_XLSX_ELEMENT),
        "file": Json::string(projection.file),
        "format": Json::string("xlsx"),
        "path": Json::string(sheet.path),
        "kind": Json::string("sheet"),
        "stability": Json::string("stable"),
        "sheet": xlsx_sheet_summary_json(
          projection,
          sheet,
          XlsxMetadataBudget::new(),
        ),
      })
    Cell(sheet, rect, path~) => {
      let page = collect_xlsx_cell_page(
        projection,
        [{ sheet, rect }],
        PresentCells,
        0,
        1,
      )
      guard page.cells.get(0) is Some(cell) else {
        raise xlsx_cli_failure(
          "office.xlsx.selector_not_found",
          "XLSX cell selector resolved to a blank, unstyled coordinate",
          details=Json::object({ "selector": Json::string(path) }),
        )
      }
      Json::object({
        "schema": Json::string(@lib.SCHEMA_XLSX_ELEMENT),
        "file": Json::string(projection.file),
        "format": Json::string("xlsx"),
        "path": Json::string(path),
        "kind": Json::string("cell"),
        "stability": Json::string("snapshot-relative"),
        "parent": Json::string(sheet.path),
        "cell": xlsx_cell_json(cell),
        "styles": xlsx_styles_json(projection, [cell]),
        "scanned_cells": Json::number(page.scanned_cells.to_double()),
      })
    }
    Range(sheet, rect, path~) => {
      let page = collect_xlsx_cell_page(
        projection,
        [{ sheet, rect }],
        PresentCells,
        0,
        projection.max_scan_cells,
      )
      Json::object({
        "schema": Json::string(@lib.SCHEMA_XLSX_ELEMENT),
        "file": Json::string(projection.file),
        "format": Json::string("xlsx"),
        "path": Json::string(path),
        "kind": Json::string("range"),
        "stability": Json::string("snapshot-relative"),
        "parent": Json::string(sheet.path),
        "reference": Json::string(rect.reference(projection.file)),
        "cells": Json::array(page.cells.map(xlsx_cell_json)),
        "styles": xlsx_styles_json(projection, page.cells),
        "scanned_cells": Json::number(page.scanned_cells.to_double()),
        "returned": Json::number(page.cells.length().to_double()),
      })
    }
  }
}

///|
fn xlsx_get_payload(
  projection : XlsxProjection,
  resolved : XlsxResolvedSelector,
  max_output_chars : Int,
) -> BoundedOfficePayload raise CliFailure {
  bounded_office_payload(
    xlsx_get_data(projection, resolved),
    [],
    max_output_chars,
    "xlsx",
  )
}

///|
fn xlsx_text_data(
  projection : XlsxProjection,
  under : XlsxResolvedSelector?,
  offset : Int,
  limit : Int,
) -> Json raise CliFailure {
  let page = collect_xlsx_cell_page(
    projection,
    xlsx_scan_regions(projection, under),
    TextCells,
    offset,
    limit,
  )
  let entries : Array[Json] = []
  for cell in page.cells {
    guard xlsx_cell_text(cell) is Some(text) else { continue }
    entries.push(
      Json::object({
        "path": Json::string(cell.path),
        "stability": Json::string("snapshot-relative"),
        "text": Json::string(text),
      }),
    )
  }
  let fields = xlsx_page_fields(page)
  fields["schema"] = Json::string(@lib.SCHEMA_XLSX_TEXT)
  fields["file"] = Json::string(projection.file)
  fields["format"] = Json::string("xlsx")
  fields["entries"] = Json::array(entries)
  match under {
    Some(value) => fields["under"] = Json::string(value.path())
    None => ()
  }
  Json::object(fields)
}

///|
fn xlsx_text_payload(
  projection : XlsxProjection,
  under : XlsxResolvedSelector?,
  offset : Int,
  limit : Int,
  max_output_chars : Int,
) -> BoundedOfficePayload raise CliFailure {
  bounded_office_payload(
    xlsx_text_data(projection, under, offset, limit),
    [],
    max_output_chars,
    "xlsx",
  )
}

///|
fn xlsx_query_data(
  projection : XlsxProjection,
  under : XlsxResolvedSelector?,
  spec : XlsxQuerySpec,
) -> Json raise CliFailure {
  let page = collect_xlsx_cell_page(
    projection,
    xlsx_scan_regions(projection, under),
    QueryCells(spec.predicates),
    spec.offset,
    spec.limit,
  )
  let fields = xlsx_page_fields(page)
  fields["schema"] = Json::string(@lib.SCHEMA_XLSX_QUERY)
  fields["file"] = Json::string(projection.file)
  fields["format"] = Json::string("xlsx")
  fields["selector"] = Json::string(spec.selector)
  fields["matches"] = Json::array(page.cells.map(xlsx_cell_json))
  fields["styles"] = xlsx_styles_json(projection, page.cells)
  match under {
    Some(value) => fields["under"] = Json::string(value.path())
    None => ()
  }
  Json::object(fields)
}

///|
fn xlsx_query_payload(
  projection : XlsxProjection,
  under : XlsxResolvedSelector?,
  spec : XlsxQuerySpec,
  max_output_chars : Int,
) -> BoundedOfficePayload raise CliFailure {
  bounded_office_payload(
    xlsx_query_data(projection, under, spec),
    [],
    max_output_chars,
    "xlsx",
  )
}

///|
fn xlsx_outline_human(
  projection : XlsxProjection,
  maximum : Int,
) -> String raise CliFailure {
  let output = DocxHumanWriter::new(maximum, format="xlsx")
  output.begin_line()
  output.write_plain("xlsx: ")
  output.write_terminal_safe(projection.file)
  output.begin_line()
  output.write_plain("workbook\t/xlsx/workbook\t")
  output.write_plain("\{projection.sheet_names.length()} sheets")
  for name in projection.sheet_names {
    guard projection.find_sheet_by_name(name) is Some(sheet) else { continue }
    output.begin_line()
    output.write_terminal_safe(sheet.path)
    output.write_char('\t')
    output.write_terminal_safe(sheet.name, single_line=true)
    match sheet.content {
      ChartSheet(_) => output.write_plain("\tchart-sheet")
      Worksheet(worksheet) => {
        output.write_plain("\tworksheet")
        match xlsx_used_rect(worksheet) {
          Some(rect) => {
            output.write_char('\t')
            output.write_terminal_safe(rect.reference(projection.file))
          }
          None => output.write_plain("\tempty")
        }
      }
    }
  }
  output.finish()
}

///|
fn xlsx_page_human(
  page : XlsxCellPage,
  include_kind : Bool,
  maximum : Int,
) -> String raise CliFailure {
  let output = DocxHumanWriter::new(maximum, format="xlsx")
  for cell in page.cells {
    output.begin_line()
    output.write_terminal_safe(cell.path)
    if include_kind {
      output.write_plain("\tcell")
    }
    match xlsx_cell_text(cell) {
      Some(text) => {
        output.write_char('\t')
        output.write_terminal_safe(text, single_line=true)
      }
      None => ()
    }
  }
  output.begin_line()
  output.write_plain(
    "# matched \{page.matched_total}; returned \{page.cells.length()}; scanned \{page.scanned_cells}; offset \{page.offset}",
  )
  output.finish()
}

///|
fn xlsx_get_human(
  projection : XlsxProjection,
  resolved : XlsxResolvedSelector,
  maximum : Int,
) -> String raise CliFailure {
  match resolved {
    Workbook(..) => xlsx_outline_human(projection, maximum)
    Sheet(sheet) => {
      let output = DocxHumanWriter::new(maximum, format="xlsx")
      output.begin_line()
      output.write_terminal_safe(sheet.path)
      output.write_char('\t')
      output.write_terminal_safe(sheet.name, single_line=true)
      output.finish()
    }
    Cell(sheet, rect, path~) => {
      let page = collect_xlsx_cell_page(
        projection,
        [{ sheet, rect }],
        PresentCells,
        0,
        1,
      )
      if page.cells.is_empty() {
        raise xlsx_cli_failure(
          "office.xlsx.selector_not_found",
          "XLSX cell selector resolved to a blank, unstyled coordinate",
          details=Json::object({ "selector": Json::string(path) }),
        )
      }
      xlsx_page_human(page, false, maximum)
    }
    Range(sheet, rect, ..) =>
      xlsx_page_human(
        collect_xlsx_cell_page(
          projection,
          [{ sheet, rect }],
          PresentCells,
          0,
          projection.max_scan_cells,
        ),
        false,
        maximum,
      )
  }
}

///|
fn xlsx_text_human(
  projection : XlsxProjection,
  under : XlsxResolvedSelector?,
  offset : Int,
  limit : Int,
  maximum : Int,
) -> String raise CliFailure {
  xlsx_page_human(
    collect_xlsx_cell_page(
      projection,
      xlsx_scan_regions(projection, under),
      TextCells,
      offset,
      limit,
    ),
    false,
    maximum,
  )
}

///|
fn xlsx_query_human(
  projection : XlsxProjection,
  under : XlsxResolvedSelector?,
  spec : XlsxQuerySpec,
  maximum : Int,
) -> String raise CliFailure {
  xlsx_page_human(
    collect_xlsx_cell_page(
      projection,
      xlsx_scan_regions(projection, under),
      QueryCells(spec.predicates),
      spec.offset,
      spec.limit,
    ),
    true,
    maximum,
  )
}
