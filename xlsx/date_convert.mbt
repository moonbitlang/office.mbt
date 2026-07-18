///|
let maximum_excel_serial_1900 = 2_958_465

///|
let maximum_excel_serial_1904 = 2_957_003

///|
/// Splits a finite, supported Excel serial after rounding its clock to whole
/// seconds. The returned day is also rounded when 23:59:59.5 spills into the
/// next date, and can therefore be checked before calendar conversion.
fn excel_serial_day_and_clock(
  value : Double,
  maximum_day : Int,
) -> (Int, Int, Int, Int)? {
  if value.is_nan() ||
    value.is_inf() ||
    value < 0.0 ||
    value >= Double::from_int(maximum_day + 1) {
    return None
  }
  let mut serial_day = Double::to_int(Double::floor(value))
  let fraction = value - Double::from_int(serial_day)
  let mut total_seconds = Double::to_int(Double::round(fraction * 86400.0))
  if total_seconds >= 86400 {
    total_seconds = total_seconds - 86400
    serial_day = serial_day + 1
  }
  if serial_day > maximum_day {
    return None
  }
  Some(
    (
      serial_day,
      total_seconds / 3600,
      total_seconds % 3600 / 60,
      total_seconds % 60,
    ),
  )
}

///|
fn excel_serial_to_parts(value : Double) -> (Int, Int, Int, Int, Int, Int)? {
  guard excel_serial_day_and_clock(value, maximum_excel_serial_1900)
    is Some((serial_day, hour, minute, second)) else {
    return None
  }
  if serial_day == 60 {
    return Some((1900, 2, 29, hour, minute, second))
  }
  let civil_day = if serial_day > 59 { serial_day - 1 } else { serial_day }
  let (year, month, day) = civil_from_days(
    days_from_civil(1899, 12, 31) + civil_day,
  )
  Some((year, month, day, hour, minute, second))
}

///|
fn excel_serial_to_parts_1904(
  value : Double,
) -> (Int, Int, Int, Int, Int, Int)? {
  guard excel_serial_day_and_clock(value, maximum_excel_serial_1904)
    is Some((serial_day, hour, minute, second)) else {
    return None
  }
  let (year, month, day) = civil_from_days(
    days_from_civil(1904, 1, 1) + serial_day,
  )
  Some((year, month, day, hour, minute, second))
}

///|
pub fn excel_date_to_time(
  excel_date : Double,
  use_1904_format? : Bool = false,
) -> @time.ZonedDateTime raise XlsxError {
  if excel_date < 0.0 {
    raise InvalidExcelDate(value=excel_date)
  }
  let parts = if use_1904_format {
    excel_serial_to_parts_1904(excel_date)
  } else {
    excel_serial_to_parts(excel_date)
  }
  match parts {
    Some((year, month, day, hour, minute, second)) =>
      @time.date_time(
        year,
        month,
        day,
        hour~,
        minute~,
        second~,
        nanosecond=0,
        zone=@time.utc_zone,
      ) catch {
        _ => raise InvalidExcelDate(value=excel_date)
      }
    None => raise InvalidExcelDate(value=excel_date)
  }
}

///|
test "date convert wb: 1904 serial negative returns None" {
  debug_inspect(excel_serial_to_parts_1904(-1.0), content="None")
}
