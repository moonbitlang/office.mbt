///|
fn add_days_to_date(
  year : Int,
  month : Int,
  day : Int,
  days : Int,
) -> (Int, Int, Int) {
  let mut y = year
  let mut m = month
  let mut d = day
  let mut remaining = days
  while remaining > 0 {
    let dim = days_in_month(y, m)
    if d + remaining <= dim {
      d = d + remaining
      remaining = 0
    } else {
      remaining = remaining - (dim - d + 1)
      d = 1
      m = m + 1
      if m > 12 {
        m = 1
        y = y + 1
      }
    }
  }
  (y, m, d)
}

///|
fn excel_serial_to_parts_1904(
  value : Double,
) -> (Int, Int, Int, Int, Int, Int)? {
  if value < 0.0 {
    return None
  }
  let whole = Double::to_int(Double::floor(value))
  let days = whole
  let mut fraction = value - Double::from_int(whole)
  if fraction < 0.0 {
    fraction = 0.0
  }
  let mut total_seconds = Double::to_int(Double::round(fraction * 86400.0))
  let mut add_day = 0
  if total_seconds >= 86400 {
    total_seconds = total_seconds - 86400
    add_day = 1
  }
  let (year, month, day) = add_days_to_date(1904, 1, 1, days + add_day)
  let hour = total_seconds / 3600
  let minute = total_seconds % 3600 / 60
  let second = total_seconds % 60
  Some((year, month, day, hour, minute, second))
}

///|
pub fn excel_date_to_time(
  excel_date : Double,
  use_1904_format? : Bool = false,
) -> @time.ZonedDateTime raise XlsxError {
  if excel_date < 0.0 {
    raise XlsxError::InvalidExcelDate(value=excel_date)
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
        _ => raise XlsxError::InvalidExcelDate(value=excel_date)
      }
    None => raise XlsxError::InvalidExcelDate(value=excel_date)
  }
}
