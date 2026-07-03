///|
/// Days since 1970-01-01 for a proleptic-Gregorian calendar date
/// (Howard Hinnant's civil-days algorithm).
fn days_from_civil(year : Int, month : Int, day : Int) -> Int {
  let y = if month <= 2 { year - 1 } else { year }
  let era = (if y >= 0 { y } else { y - 399 }) / 400
  let yoe = y - era * 400
  let mp = (month + 9) % 12
  let doy = (153 * mp + 2) / 5 + day - 1
  let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
  era * 146097 + doe - 719468
}

///|
let nanos_per_day : Double = 86_400_000_000_000.0

///|
/// Converts a wall-clock datetime to an Excel serial date, mirroring
/// Excelize's `timeToExcelTime`: days are counted from the 1900 epoch
/// (1899-12-31, with the intentional Lotus 1-2-3 bug adding one day from
/// 1900-03-01 onward) or from the 1904 epoch (1904-01-01). Values before
/// the epoch return 0. The datetime's own wall-clock fields are used, so
/// the zone offset never shifts the stored value.
///
/// # Example
/// ```mbt check
/// test {
///   let dt = @time.date_time(2021, 1, 1, hour=12)
///   inspect(@xlsx.time_to_excel_date(dt), content="44197.5")
/// }
/// ```
pub fn time_to_excel_date(
  value : @time.ZonedDateTime,
  use_1904_format? : Bool = false,
) -> Double {
  let epoch_days = if use_1904_format {
    days_from_civil(1904, 1, 1)
  } else {
    days_from_civil(1899, 12, 31)
  }
  let day_number = days_from_civil(value.year(), value.month(), value.day())
  let nanos_of_day = (value.hour() * 3600 + value.minute() * 60 + value.second()).to_int64() *
    1_000_000_000L +
    value.nanosecond().to_int64()
  let serial = (day_number - epoch_days).to_double() +
    nanos_of_day.to_double() / nanos_per_day
  if serial < 0.0 {
    return 0.0
  }
  if !use_1904_format && day_number >= days_from_civil(1900, 3, 1) {
    serial + 1.0
  } else {
    serial
  }
}

///|
/// Default number format for a time cell, mirroring Excelize's
/// `getTimeNumFmt`: first of a month -> 17 (mmm-yy), midnight -> 14
/// (mm-dd-yy), otherwise 22 (m/d/yy h:mm).
fn time_num_fmt(value : @time.ZonedDateTime) -> Int {
  if value.day() == 1 {
    17
  } else if value.hour() == 0 &&
    value.minute() == 0 &&
    value.second() == 0 &&
    value.nanosecond() == 0 {
    14
  } else {
    22
  }
}

///|
/// Default number format for a duration cell, mirroring Excelize's
/// `getDurationNumFmt`: >= 24h -> 46 ([h]:mm:ss), whole minutes -> 20
/// (hh:mm), otherwise 21 (hh:mm:ss).
fn duration_num_fmt(nanos : Int64) -> Int {
  if nanos >= 86_400_000_000_000L {
    46
  } else if nanos % 60_000_000_000L == 0L {
    20
  } else {
    21
  }
}

///|
/// ISO-8601 text for the pre-epoch fallback. Excelize shifts the value
/// by its zone offset before formatting (cell.go setCellTime), so the
/// rendered wall clock moves forward by the offset while keeping the
/// original zone suffix; the trailing `[Zone]` id ZonedDateTime appends
/// for non-UTC zones is dropped to match Go's RFC3339 rendering.
fn zoned_date_time_iso_string(value : @time.ZonedDateTime) -> String {
  let shifted = value.add_seconds(value.offset().seconds().to_int64()) catch {
    _ => value
  }
  let text = shifted.to_string()
  match text.find("[") {
    Some(pos) => (try! text[:pos]).to_string()
    None => text
  }
}

///|
/// Effective style a cell write should start from, mirroring Excelize's
/// `prepareCellStyle` precedence: the cell's own style, else the row
/// style, else the column style, else 0.
fn Workbook::resolve_cell_base_style(
  self : Workbook,
  sheet_name : StringView,
  reference : String,
) -> Int raise XlsxError {
  let (row, col) = cell_ref_to_rc(reference)
  match self.get_cell_style(sheet_name, reference) {
    Some(idx) if idx != 0 => idx
    _ =>
      match self.get_row_style(sheet_name, row) {
        Some(idx) if idx != 0 => idx
        _ =>
          match self.get_col_style(sheet_name, col) {
            Some(idx) if idx != 0 => idx
            _ => 0
          }
      }
  }
}

///|
/// Applies the default date/time number format to a cell, mirroring
/// Excelize's `setDefaultTimeStyle`: the inherited base style keeps its
/// attributes and only the number format is swapped; with no inherited
/// style the cell gets a fresh number-format-only style.
fn Workbook::set_default_time_style(
  self : Workbook,
  sheet_name : StringView,
  reference : String,
  num_fmt : Int,
) -> Unit raise XlsxError {
  let base_idx = self.resolve_cell_base_style(sheet_name, reference)
  let base = if base_idx != 0 { self.get_style(base_idx) } else { Style::new() }
  // number_format is what the styles.xml writer reads; num_fmt mirrors the
  // excelize-options field, and any inherited custom format is replaced.
  let style = {
    ..base,
    number_format: Some(Builtin(num_fmt)),
    num_fmt: Some(num_fmt),
    custom_num_fmt: None,
    decimal_places: None,
    neg_red: None,
  }
  let style_idx = self.new_style(style)
  self.set_cell_style(sheet_name, reference, style_idx)
}

///|
/// Sets a cell to a datetime value the way Excelize's
/// `SetCellValue(time.Time)` does: the value is stored as an Excel date
/// serial (honoring the workbook's date-1904 setting) and the cell
/// receives a default date/time number format. Datetimes before the
/// epoch are stored as ISO-8601 text instead.
pub fn Workbook::set_cell_time(
  self : Workbook,
  sheet_name : StringView,
  reference : String,
  value : @time.ZonedDateTime,
) -> Unit raise XlsxError {
  let date1904 = match self.get_workbook_props().date_1904 {
    Some(flag) => flag
    None => false
  }
  let serial = time_to_excel_date(value, use_1904_format=date1904)
  if serial > 0.0 {
    self.set_cell_value(sheet_name, reference, Numeric(serial))
    self.set_default_time_style(sheet_name, reference, time_num_fmt(value))
  } else {
    self.set_cell_value(
      sheet_name,
      reference,
      String(zoned_date_time_iso_string(value)),
    )
    // Go's prepareCellStyle runs on this path too: the text cell still
    // inherits an explicit row/column style, just without a number format.
    let base_idx = self.resolve_cell_base_style(sheet_name, reference)
    if base_idx != 0 {
      self.set_cell_style(sheet_name, reference, base_idx)
    }
  }
}

///|
/// Sets a cell to a duration value the way Excelize's
/// `SetCellValue(time.Duration)` does: the value is stored as a fraction
/// of a day and the cell receives a default elapsed-time number format.
/// The serial keeps full double precision (Go rounds through float32).
pub fn Workbook::set_cell_duration(
  self : Workbook,
  sheet_name : StringView,
  reference : String,
  value : @time.Duration,
) -> Unit raise XlsxError {
  let nanos = value.to_nanoseconds()
  let serial = nanos.to_double() / nanos_per_day
  self.set_cell_value(sheet_name, reference, Numeric(serial))
  self.set_default_time_style(sheet_name, reference, duration_num_fmt(nanos))
}
