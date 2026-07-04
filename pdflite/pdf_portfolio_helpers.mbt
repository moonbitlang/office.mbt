///|
fn pdf_portfolio_is_path_separator(code_unit : UInt16) -> Bool {
  let value = code_unit.to_int()
  value == 47 || value == 92
}

///|
fn pdf_portfolio_basename(path : String) -> String {
  let mut start = 0
  for index in 0..<path.length() {
    if pdf_portfolio_is_path_separator(path.at(index)) {
      start = index + 1
    }
  }
  path[start:].to_owned()
}

///|
fn pdf_portfolio_relationship_name(relationship : String?) -> @core.PdfName {
  match relationship {
    Some(text) => pdf_portfolio_name("/" + text)
    None => pdf_portfolio_unspecified_relationship()
  }
}

///|
fn pdf_portfolio_description(
  entry : @portfolio.PdfPortfolioEntry,
  basename : String,
) -> String {
  match entry.description {
    Some(description) => description
    None => basename
  }
}

///|
fn pdf_portfolio_pad2(value : Int) -> String {
  if value < 10 {
    "0" + value.to_string()
  } else {
    value.to_string()
  }
}

///|
fn pdf_portfolio_pad4(value : Int) -> String {
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
fn pdf_portfolio_is_leap_year(year : Int) -> Bool {
  (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
}

///|
fn pdf_portfolio_days_in_month(year : Int, month : Int) -> Int {
  match month {
    1 | 3 | 5 | 7 | 8 | 10 | 12 => 31
    4 | 6 | 9 | 11 => 30
    2 => if pdf_portfolio_is_leap_year(year) { 29 } else { 28 }
    _ => 30
  }
}

///|
fn pdf_portfolio_date_text_from_unix_millis(milliseconds : UInt64) -> String {
  let total_seconds = (milliseconds / (1000 : UInt64)).reinterpret_as_int64()
  let mut days = (total_seconds / 86400L).to_int()
  let seconds_of_day = (total_seconds % 86400L).to_int()
  let hour = seconds_of_day / 3600
  let minute = seconds_of_day % 3600 / 60
  let second = seconds_of_day % 60
  let mut year = 1970
  let mut year_days = if pdf_portfolio_is_leap_year(year) { 366 } else { 365 }
  while days >= year_days {
    days -= year_days
    year += 1
    year_days = if pdf_portfolio_is_leap_year(year) { 366 } else { 365 }
  }
  let mut month = 1
  while days >= pdf_portfolio_days_in_month(year, month) {
    days -= pdf_portfolio_days_in_month(year, month)
    month += 1
  }
  let day = days + 1
  "D:" +
  pdf_portfolio_pad4(year) +
  pdf_portfolio_pad2(month) +
  pdf_portfolio_pad2(day) +
  pdf_portfolio_pad2(hour) +
  pdf_portfolio_pad2(minute) +
  pdf_portfolio_pad2(second)
}

///|
fn pdf_portfolio_current_mod_date() -> @core.PdfBytes {
  let text = match @env.get_env_var("CPDF_REPRODUCIBLE_DATES") {
    Some("true") =>
      @date.pdf_strftime_with_time(
        @date.pdf_strftime_dummy_time(),
        "D:%Y%m%d%H%M%S",
      )
    _ => pdf_portfolio_date_text_from_unix_millis(@env.now())
  }
  @ascii.encode(text)
}
