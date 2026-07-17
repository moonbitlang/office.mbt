///|
let xlsx_cli_hard_max_scan_cells : Int = 100_000

///|
let xlsx_cli_max_cell_string_chars : Int = 1024 * 1024

///|
let xlsx_cli_max_scanned_string_chars : Int = 16 * 1024 * 1024

///|
let xlsx_cli_max_format_work_units : Int = 16 * 1024 * 1024

///|
let xlsx_cli_max_metadata_items : Int = 10_000

///|
let xlsx_cli_max_metadata_string_chars : Int = 8 * 1024 * 1024

///|
enum XlsxSheetContent {
  Worksheet(@xlsx.Worksheet)
  ChartSheet(@xlsx.ChartSheet)
}

///|
struct XlsxSheetTarget {
  name : String
  index : Int
  path : String
  content : XlsxSheetContent
  shared_formula_masters : Map[Int, @xlsx.SharedFormulaMaster]
  mut shared_formulas_indexed : Bool
}

///|
struct XlsxProjection {
  file : String
  workbook : @xlsx.Workbook
  sheets : Array[XlsxSheetTarget]
  sheet_index : Map[String, Int]
  max_scan_cells : Int
}

///|
struct XlsxRect {
  col_lo : Int
  row_lo : Int
  col_hi : Int
  row_hi : Int
}

///|
enum XlsxResolvedSelector {
  Workbook(path~ : String)
  Sheet(XlsxSheetTarget)
  Cell(XlsxSheetTarget, XlsxRect, path~ : String)
  Range(XlsxSheetTarget, XlsxRect, path~ : String)
}

///|
struct XlsxCellSnapshot {
  path : String
  reference : String
  row : Int
  column : Int
  raw : @xlsx.CellValue?
  mut formatted : String?
  mut formatted_ready : Bool
  formula : String?
  style_id : Int
  worksheet : @xlsx.Worksheet
}

///|
struct XlsxScanRegion {
  sheet : XlsxSheetTarget
  rect : XlsxRect
}

///|
struct XlsxStringBudget {
  maximum : Int
  per_value_maximum : Int
  mut used : Int
}

///|
struct XlsxScanBudget {
  maximum : Int
  strings : XlsxStringBudget
  formatting : XlsxFormatBudget
  mut scanned : Int
}

///|
struct XlsxFormatBudget {
  maximum : Int
  mut used : Int
}

///|
struct XlsxMetadataBudget {
  maximum_items : Int
  maximum_string_chars : Int
  mut items : Int
  mut string_chars : Int
}

///|
fn xlsx_cli_failure(
  code : String,
  message : String,
  details? : Json,
) -> CliFailure {
  CliFailure(@lib.protocol_error(code, message, details?))
}

///|
fn xlsx_resource_failure(
  resource : String,
  limit : Int,
  actual? : Int,
) -> CliFailure {
  format_resource_failure("xlsx", resource, limit, actual?)
}

///|
fn xlsx_scan_resource_failure(
  resource : String,
  limit : Int,
  actual : Int64,
) -> CliFailure {
  xlsx_cli_failure(
    "office.xlsx.resource_limit",
    "XLSX \{resource} exceeds the configured limit",
    details=Json::object({
      "format": Json::string("xlsx"),
      "resource": Json::string(resource),
      "limit": Json::number(limit.to_double()),
      "actual": Json::number(actual.to_double()),
    }),
  )
}

///|
fn[T] xlsx_call(
  file : String,
  action : () -> T raise @xlsx.XlsxError,
) -> T raise CliFailure {
  action() catch {
    error => raise xlsx_read_failure(error, file)
  }
}

///|
fn canonical_xlsx_sheet_path(name : String) -> String raise CliFailure {
  @lib.selector_for_xlsx_sheet(name).render() catch {
    error => raise selector_failure(error)
  }
}

///|
fn canonical_xlsx_cell_path(
  sheet : String,
  reference : String,
) -> String raise CliFailure {
  @lib.selector_for_xlsx_cell(sheet, reference).render() catch {
    error => raise selector_failure(error)
  }
}

///|
fn canonical_xlsx_range_path(
  sheet : String,
  reference : String,
) -> String raise CliFailure {
  @lib.selector_for_xlsx_range(sheet, reference).render() catch {
    error => raise selector_failure(error)
  }
}

///|
fn make_xlsx_projection(
  file : String,
  workbook : @xlsx.Workbook,
  max_elements : Int,
) -> XlsxProjection raise CliFailure {
  if max_elements < 1 || max_elements > docx_cli_hard_max_elements {
    raise xlsx_cli_failure(
      "office.invalid_arguments",
      "--max-elements must be between 1 and \{docx_cli_hard_max_elements}",
      details=Json::object({
        "argument": Json::string("max-elements"),
        "minimum": Json::number(1),
        "maximum": Json::number(docx_cli_hard_max_elements.to_double()),
      }),
    )
  }
  let worksheets : Map[String, @xlsx.Worksheet] = Map([])
  for worksheet in workbook.sheets() {
    worksheets[worksheet.name()] = worksheet
  }
  let chart_sheets : Map[String, @xlsx.ChartSheet] = Map([])
  for chart_sheet in workbook.chart_sheets() {
    chart_sheets[chart_sheet.name()] = chart_sheet
  }
  let sheets : Array[XlsxSheetTarget] = []
  let sheet_index : Map[String, Int] = Map([])
  for index, name in workbook.get_sheet_list() {
    let normalized_name = name.to_lower()
    if sheet_index.contains(normalized_name) {
      raise xlsx_cli_failure(
        "office.xlsx.read_failed",
        "workbook tab order contains a duplicate sheet name",
        details=Json::object({ "sheet": Json::string(bounded_text(name, 160)) }),
      )
    }
    let content = match worksheets.get(name) {
      Some(worksheet) => Worksheet(worksheet)
      None =>
        match chart_sheets.get(name) {
          Some(chart_sheet) => ChartSheet(chart_sheet)
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
    let target : XlsxSheetTarget = {
      name,
      index,
      path: canonical_xlsx_sheet_path(name),
      content,
      shared_formula_masters: Map([]),
      shared_formulas_indexed: content is ChartSheet(_),
    }
    sheet_index[normalized_name] = index
    sheets.push(target)
  }
  {
    file,
    workbook,
    sheets,
    sheet_index,
    max_scan_cells: max_elements.min(xlsx_cli_hard_max_scan_cells),
  }
}

///|
fn open_xlsx_projection(
  source : OfficeReadPackage,
  max_elements : Int,
) -> XlsxProjection raise CliFailure {
  let workbook = open_xlsx_read_package(source)
  make_xlsx_projection(source.file, workbook, max_elements)
}

///|
fn XlsxRect::cell_count(self : XlsxRect) -> Int64 {
  (self.col_hi - self.col_lo + 1).to_int64() *
  (self.row_hi - self.row_lo + 1).to_int64()
}

///|
fn XlsxRect::cell_reference(
  self : XlsxRect,
  file : String,
) -> String raise CliFailure {
  xlsx_call(file, () => @xlsx.coordinates_to_cell_name(self.col_lo, self.row_lo))
}

///|
fn XlsxRect::range_reference(
  self : XlsxRect,
  file : String,
) -> String raise CliFailure {
  let first = self.cell_reference(file)
  let last = xlsx_call(file, () => {
    @xlsx.coordinates_to_cell_name(self.col_hi, self.row_hi)
  })
  first + ":" + last
}

///|
fn xlsx_rect_from_coordinate(coordinate : @lib.SelectorCoordinate) -> XlsxRect {
  match coordinate {
    Cell(address) =>
      {
        col_lo: address.column(),
        row_lo: address.row(),
        col_hi: address.column(),
        row_hi: address.row(),
      }
    Range(first, last) =>
      {
        col_lo: first.column(),
        row_lo: first.row(),
        col_hi: last.column(),
        row_hi: last.row(),
      }
  }
}

///|
fn xlsx_used_rect(worksheet : @xlsx.Worksheet) -> XlsxRect? {
  let max_col = worksheet.max_col()
  let max_row = worksheet.max_row()
  if max_col < 1 || max_row < 1 {
    None
  } else {
    Some({ col_lo: 1, row_lo: 1, col_hi: max_col, row_hi: max_row })
  }
}

///|
fn XlsxProjection::check_scan_rect(
  self : XlsxProjection,
  rect : XlsxRect,
) -> Unit raise CliFailure {
  let actual = rect.cell_count()
  if actual > self.max_scan_cells.to_int64() {
    raise xlsx_scan_resource_failure(
      "scanned cells",
      self.max_scan_cells,
      actual,
    )
  }
}

///|
fn XlsxProjection::find_sheet_by_name(
  self : XlsxProjection,
  name : String,
) -> XlsxSheetTarget? {
  match self.sheet_index.get(name.to_lower()) {
    Some(index) => self.sheets.get(index)
    None => None
  }
}

///|
fn XlsxProjection::resolve_sheet_segment(
  self : XlsxProjection,
  segment : @lib.SelectorSegment,
  requested : String,
) -> XlsxSheetTarget raise CliFailure {
  let target = match segment.key_value("name") {
    Some(name) => self.find_sheet_by_name(name)
    None =>
      match segment.position() {
        Some(position) => self.sheets.get(position - 1)
        None => None
      }
  }
  match target {
    Some(sheet) => sheet
    None =>
      raise xlsx_cli_failure(
        "office.xlsx.selector_not_found",
        "XLSX selector did not resolve in this workbook snapshot",
        details=Json::object({
          "selector": Json::string(bounded_text(requested, 240)),
        }),
      )
  }
}

///|
fn XlsxSheetTarget::worksheet(
  self : XlsxSheetTarget,
  selector : String,
) -> @xlsx.Worksheet raise CliFailure {
  match self.content {
    Worksheet(sheet) => sheet
    ChartSheet(_) =>
      raise xlsx_cli_failure(
        "office.xlsx.unsupported_sheet_kind",
        "cell and range selectors require a worksheet, not a chart sheet",
        details=Json::object({
          "selector": Json::string(selector),
          "sheet": Json::string(self.name),
          "sheet_kind": Json::string("chart_sheet"),
        }),
      )
  }
}

///|
/// Resolves shared-formula masters on demand. Most reads never encounter a
/// shared follower, so they avoid a worksheet-wide formula pass; the first
/// follower builds every master in one pass and later lookups are O(1).
fn XlsxSheetTarget::shared_formula_master(
  self : XlsxSheetTarget,
  projection : XlsxProjection,
  worksheet : @xlsx.Worksheet,
  shared_index : Int,
) -> @xlsx.SharedFormulaMaster? raise CliFailure {
  if !self.shared_formulas_indexed {
    let masters = xlsx_call(projection.file, () => {
      worksheet.shared_formula_masters()
    })
    for index, formula in masters {
      self.shared_formula_masters[index] = formula
    }
    self.shared_formulas_indexed = true
  }
  self.shared_formula_masters.get(shared_index)
}

///|
fn resolve_xlsx_selector(
  projection : XlsxProjection,
  input : String,
) -> XlsxResolvedSelector raise CliFailure {
  let selector = @lib.parse_selector(input) catch {
    error => raise selector_failure(error)
  }
  if selector.document_format() is Docx {
    raise xlsx_cli_failure(
      "office.xlsx.selector_format_mismatch",
      "XLSX structured reads require an /xlsx selector",
      details=Json::object({
        "selector": Json::string(selector.render()),
        "expected_format": Json::string("xlsx"),
        "actual_format": Json::string("docx"),
      }),
    )
  }
  let segments = selector.segments()
  if segments.length() == 1 && segments[0].name() == "workbook" {
    return Workbook(path="/xlsx/workbook")
  }
  let sheet = projection.resolve_sheet_segment(segments[0], selector.render())
  match selector.coordinate() {
    None => Sheet(sheet)
    Some(coordinate) => {
      ignore(sheet.worksheet(selector.render()))
      let rect = xlsx_rect_from_coordinate(coordinate)
      projection.check_scan_rect(rect)
      match coordinate {
        Cell(_) => {
          let reference = rect.cell_reference(projection.file)
          Cell(
            sheet,
            rect,
            path=canonical_xlsx_cell_path(sheet.name, reference),
          )
        }
        Range(_, _) => {
          let reference = rect.range_reference(projection.file)
          Range(
            sheet,
            rect,
            path=canonical_xlsx_range_path(sheet.name, reference),
          )
        }
      }
    }
  }
}

///|
fn XlsxResolvedSelector::path(self : XlsxResolvedSelector) -> String {
  match self {
    Workbook(path~) => path
    Sheet(sheet) => sheet.path
    Cell(_, _, path~) | Range(_, _, path~) => path
  }
}

///|
fn xlsx_scan_regions(
  projection : XlsxProjection,
  under : XlsxResolvedSelector?,
) -> Array[XlsxScanRegion] raise CliFailure {
  let regions : Array[XlsxScanRegion] = []
  match under {
    Some(Cell(sheet, rect, ..)) | Some(Range(sheet, rect, ..)) =>
      regions.push({ sheet, rect })
    Some(Sheet(sheet)) =>
      match sheet.content {
        Worksheet(worksheet) =>
          match xlsx_used_rect(worksheet) {
            Some(rect) => regions.push({ sheet, rect })
            None => ()
          }
        ChartSheet(_) => ()
      }
    Some(Workbook(..)) | None =>
      for sheet in projection.sheets {
        match sheet.content {
          Worksheet(worksheet) =>
            match xlsx_used_rect(worksheet) {
              Some(rect) => regions.push({ sheet, rect })
              None => ()
            }
          ChartSheet(_) => ()
        }
      }
  }
  let mut total = 0L
  for region in regions {
    total += region.rect.cell_count()
    if total > projection.max_scan_cells.to_int64() {
      raise xlsx_scan_resource_failure(
        "scanned cells",
        projection.max_scan_cells,
        total,
      )
    }
  }
  regions
}

///|
fn XlsxStringBudget::new(
  maximum? : Int = xlsx_cli_max_scanned_string_chars,
  per_value_maximum? : Int = xlsx_cli_max_cell_string_chars,
) -> XlsxStringBudget {
  { maximum, per_value_maximum, used: 0 }
}

///|
fn XlsxStringBudget::charge(
  self : XlsxStringBudget,
  resource : String,
  value : String,
) -> Unit raise CliFailure {
  let count = value.length()
  if count > self.per_value_maximum {
    raise xlsx_resource_failure(
      "\{resource} characters",
      self.per_value_maximum,
      actual=count,
    )
  }
  if count > self.maximum - self.used {
    raise xlsx_resource_failure(
      "scanned string characters",
      self.maximum,
      actual=self.used + count,
    )
  }
  self.used += count
}

///|
fn XlsxFormatBudget::new(
  maximum? : Int = xlsx_cli_max_format_work_units,
) -> XlsxFormatBudget {
  { maximum, used: 0 }
}

///|
/// Charges the linear parse cost of a custom number format before invoking
/// the formatter. Built-in and absent formats have bounded constant work and
/// are already bounded by the scanned-cell ceiling.
fn XlsxFormatBudget::charge_style(
  self : XlsxFormatBudget,
  projection : XlsxProjection,
  style_id : Int,
) -> Unit raise CliFailure {
  let style = xlsx_call(projection.file, () => {
    projection.workbook.get_style(style_id)
  })
  let cost = match style.number_format {
    Some(Custom(code)) => code.length().max(1)
    _ => 0
  }
  if cost > self.maximum - self.used {
    raise xlsx_resource_failure(
      "cell formatting work units",
      self.maximum,
      actual=self.used + cost,
    )
  }
  self.used += cost
}

///|
fn XlsxScanBudget::new(
  maximum : Int,
  format_work_maximum? : Int = xlsx_cli_max_format_work_units,
) -> XlsxScanBudget {
  {
    maximum,
    strings: XlsxStringBudget::new(),
    formatting: XlsxFormatBudget::new(maximum=format_work_maximum),
    scanned: 0,
  }
}

///|
fn XlsxScanBudget::charge_cell(self : XlsxScanBudget) -> Unit raise CliFailure {
  if self.scanned >= self.maximum {
    raise xlsx_resource_failure(
      "scanned cells",
      self.maximum,
      actual=self.scanned + 1,
    )
  }
  self.scanned += 1
}

///|
fn XlsxScanBudget::charge_snapshot_strings(
  self : XlsxScanBudget,
  snapshot : XlsxCellSnapshot,
) -> Unit raise CliFailure {
  match snapshot.raw {
    Some(String(value)) => self.strings.charge("cell value", value)
    Some(Error(value)) => self.strings.charge("cell error", value)
    _ => ()
  }
  match snapshot.formula {
    Some(value) => self.strings.charge("cell formula", value)
    None => ()
  }
}

///|
fn xlsx_cell_formula(
  projection : XlsxProjection,
  sheet : XlsxSheetTarget,
  worksheet : @xlsx.Worksheet,
  row : Int,
  column : Int,
) -> (String?, Bool) raise CliFailure {
  match
    xlsx_call(projection.file, () => {
      worksheet.get_cell_formula_info_rc(row, column)
    }) {
    None => (None, false)
    Some(info) if info.formula != "" =>
      (Some(info.formula), info.cached_value_present)
    Some(info) =>
      (
        match info.shared_index {
          Some(shared_index) =>
            // `Some("")` is intentional when a malformed package has a shared
            // follower but no resolvable master: preserve formula presence even
            // when no formula text can be supplied.
            match
              sheet.shared_formula_master(projection, worksheet, shared_index) {
              Some(master) =>
                Some(
                  xlsx_call(projection.file, () => {
                    master.translate_to(row, column)
                  }),
                )
              None => Some("")
            }
          None => Some("")
        },
        info.cached_value_present,
      )
  }
}

///|
fn xlsx_cell_snapshot(
  projection : XlsxProjection,
  sheet : XlsxSheetTarget,
  row : Int,
  column : Int,
  budget : XlsxScanBudget,
) -> XlsxCellSnapshot raise CliFailure {
  budget.charge_cell()
  let worksheet = sheet.worksheet(sheet.path)
  let reference = xlsx_call(projection.file, () => {
    @xlsx.coordinates_to_cell_name(column, row)
  })
  let raw = xlsx_call(projection.file, () => {
    worksheet.get_cell_value_raw(reference)
  })
  let (formula, cached_value_present) = xlsx_cell_formula(
    projection, sheet, worksheet, row, column,
  )
  let normalized_raw = match raw {
    Some(String("")) if formula is Some(_) && cached_value_present => raw
    Some(String("")) => None
    value => value
  }
  let style_id = xlsx_call(projection.file, () => {
    worksheet.effective_style_id_rc(row, column)
  })
  let snapshot : XlsxCellSnapshot = {
    path: canonical_xlsx_cell_path(sheet.name, reference),
    reference,
    row,
    column,
    raw: normalized_raw,
    formatted: None,
    formatted_ready: false,
    formula,
    style_id,
    worksheet,
  }
  budget.charge_snapshot_strings(snapshot)
  snapshot
}

///|
/// Materializes display text at most once. Custom format parse work is charged
/// before formatting and the produced string joins the aggregate scan-string
/// budget, so neither CPU nor retained text can grow only as a side effect of
/// a large scan.
fn XlsxCellSnapshot::ensure_formatted(
  self : XlsxCellSnapshot,
  projection : XlsxProjection,
  budget : XlsxScanBudget,
) -> Unit raise CliFailure {
  if self.formatted_ready {
    return
  }
  match self.raw {
    Some(String(_)) | Some(Numeric(_)) =>
      budget.formatting.charge_style(projection, self.style_id)
    _ => ()
  }
  let formatted = match self.raw {
    Some(_) =>
      Some(
        xlsx_call(projection.file, () => {
          projection.workbook.get_cell_value_styled_from_worksheet_rc(
            self.worksheet,
            self.row,
            self.column,
            self.style_id,
          )
        }).unwrap_or(""),
      )
    None => None
  }
  match formatted {
    Some(value) => budget.strings.charge("formatted cell value", value)
    None => ()
  }
  self.formatted = formatted
  self.formatted_ready = true
}

///|
fn XlsxCellSnapshot::is_present(self : XlsxCellSnapshot) -> Bool {
  self.raw is Some(_) || self.formula is Some(_) || self.style_id != 0
}

///|
fn XlsxMetadataBudget::new() -> XlsxMetadataBudget {
  {
    maximum_items: xlsx_cli_max_metadata_items,
    maximum_string_chars: xlsx_cli_max_metadata_string_chars,
    items: 0,
    string_chars: 0,
  }
}

///|
fn XlsxMetadataBudget::charge_item(
  self : XlsxMetadataBudget,
  strings : Array[String],
) -> Unit raise CliFailure {
  if self.items >= self.maximum_items {
    raise xlsx_resource_failure(
      "metadata items",
      self.maximum_items,
      actual=self.items + 1,
    )
  }
  self.items += 1
  for value in strings {
    let count = value.length()
    if count > xlsx_cli_max_cell_string_chars {
      raise xlsx_resource_failure(
        "metadata string characters",
        xlsx_cli_max_cell_string_chars,
        actual=count,
      )
    }
    if count > self.maximum_string_chars - self.string_chars {
      raise xlsx_resource_failure(
        "metadata string characters",
        self.maximum_string_chars,
        actual=self.string_chars + count,
      )
    }
    self.string_chars += count
  }
}
