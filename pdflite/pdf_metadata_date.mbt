///|
fn pdf_metadata_pad2(value : Int) -> String {
  let absolute = if value < 0 { -value } else { value }
  if absolute < 10 {
    "0" + absolute.to_string()
  } else {
    absolute.to_string()
  }
}

///|
fn pdf_metadata_pad4(value : Int) -> String {
  if value < 10 {
    "000" + value.to_string()
  } else if value < 100 {
    "00" + value.to_string()
  } else if value < 1000 {
    "0" + value.to_string()
  } else {
    value.to_string()
  }
}

///|
fn pdf_metadata_xmp_date(date : String) -> String raise @core.PdfError {
  if !date.has_prefix("D:") {
    "0000-01-01T00:00:00Z"
  } else {
    let parsed = @date.pdf_date_of_string(date)
    let tzd = if parsed.hour_offset == 0 && parsed.minute_offset == 0 {
      "Z"
    } else {
      let sign = if parsed.hour_offset < 0 || parsed.minute_offset < 0 {
        "-"
      } else {
        "+"
      }
      sign +
      pdf_metadata_pad2(parsed.hour_offset) +
      ":" +
      pdf_metadata_pad2(parsed.minute_offset)
    }
    pdf_metadata_pad4(parsed.year) +
    "-" +
    pdf_metadata_pad2(parsed.month) +
    "-" +
    pdf_metadata_pad2(parsed.day) +
    "T" +
    pdf_metadata_pad2(parsed.hour) +
    ":" +
    pdf_metadata_pad2(parsed.minute) +
    ":" +
    pdf_metadata_pad2(parsed.second) +
    tzd
  }
}

///|
fn pdf_metadata_is_leap_year(year : Int) -> Bool {
  (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
}

///|
fn pdf_metadata_days_in_month(year : Int, month : Int) -> Int {
  match month {
    1 | 3 | 5 | 7 | 8 | 10 | 12 => 31
    4 | 6 | 9 | 11 => 30
    2 => if pdf_metadata_is_leap_year(year) { 29 } else { 28 }
    _ => 30
  }
}

///|
fn pdf_metadata_pdf_date_from_unix_millis(milliseconds : UInt64) -> String {
  let total_seconds = (milliseconds / (1000 : UInt64)).reinterpret_as_int64()
  let mut days = (total_seconds / 86400L).to_int()
  let seconds_of_day = (total_seconds % 86400L).to_int()
  let hour = seconds_of_day / 3600
  let minute = seconds_of_day % 3600 / 60
  let second = seconds_of_day % 60
  let mut year = 1970
  let mut year_days = if pdf_metadata_is_leap_year(year) { 366 } else { 365 }
  while days >= year_days {
    days -= year_days
    year += 1
    year_days = if pdf_metadata_is_leap_year(year) { 366 } else { 365 }
  }
  let mut month = 1
  while days >= pdf_metadata_days_in_month(year, month) {
    days -= pdf_metadata_days_in_month(year, month)
    month += 1
  }
  let day = days + 1
  "D:" +
  pdf_metadata_pad4(year) +
  pdf_metadata_pad2(month) +
  pdf_metadata_pad2(day) +
  pdf_metadata_pad2(hour) +
  pdf_metadata_pad2(minute) +
  pdf_metadata_pad2(second)
}

///|
fn pdf_metadata_expand_date(date : String) -> String {
  if date == "now" {
    match @env.get_env_var("CPDF_REPRODUCIBLE_DATES") {
      Some("true") =>
        @date.pdf_strftime_with_time(
          @date.pdf_strftime_dummy_time(),
          "D:%Y%m%d%H%M%S",
        )
      _ => pdf_metadata_pdf_date_from_unix_millis(@env.now())
    }
  } else {
    date
  }
}

///|
/// Expand cpdf's metadata date alias.
///
/// This mirrors `Cpdfmetadata.expand_date`: `"now"` becomes a PDF date string
/// and all other inputs are returned unchanged. Setting
/// `CPDF_REPRODUCIBLE_DATES=true` uses the deterministic dummy timestamp.
pub fn pdf_expand_date(date : String) -> String {
  pdf_metadata_expand_date(date)
}
