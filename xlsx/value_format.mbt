///|
fn format_cell_value(
  value_type : CellValueType,
  raw : String,
  style : Style?,
  options : Options,
) -> String {
  match value_type {
    CellValueType::String => raw
    CellValueType::Error => raw
    CellValueType::Bool => if parse_cell_bool(raw) { "TRUE" } else { "FALSE" }
    CellValueType::Number =>
      match style {
        Some(style) =>
          match style.number_format {
            Some(format) => format_number_with_format(raw, format, options)
            None => raw
          }
        None => raw
      }
  }
}

///|
fn format_number_with_format(
  raw : String,
  format : NumberFormat,
  options : Options,
) -> String {
  match format {
    NumberFormat::Builtin(id) => format_number_builtin(raw, id, options)
    NumberFormat::Custom(code) => format_number_code(raw, code)
  }
}

///|
fn format_number_builtin(raw : String, id : Int, options : Options) -> String {
  let short_date = options.short_date_pattern
  let long_date = options.long_date_pattern
  let long_time = options.long_time_pattern
  match id {
    0 => raw
    1 => format_number_simple(raw, 0, false, false)
    2 => format_number_simple(raw, 2, false, false)
    3 => format_number_simple(raw, 0, true, false)
    4 => format_number_simple(raw, 2, true, false)
    9 => format_number_simple(raw, 0, false, true)
    10 => format_number_simple(raw, 2, false, true)
    14 =>
      if short_date != "" {
        format_excel_date(raw, short_date)
      } else {
        format_excel_date(raw, "m/d/yy")
      }
    15 =>
      if long_date != "" {
        format_excel_date(raw, long_date)
      } else {
        format_excel_date(raw, "d-mmm-yy")
      }
    16 => format_excel_date(raw, "d-mmm")
    17 => format_excel_date(raw, "mmm-yy")
    18 => format_excel_date(raw, "h:mm am/pm")
    19 => format_excel_date(raw, "h:mm:ss am/pm")
    20 =>
      if long_time != "" {
        format_excel_date(raw, long_time)
      } else {
        format_excel_date(raw, "h:mm")
      }
    21 =>
      if long_time != "" {
        format_excel_date(raw, long_time)
      } else {
        format_excel_date(raw, "h:mm:ss")
      }
    22 =>
      if short_date != "" {
        format_excel_date(raw, "\{short_date} h:mm")
      } else {
        format_excel_date(raw, "m/d/yy h:mm")
      }
    _ => raw
  }
}

///|
fn format_number_code(raw : String, code : String) -> String {
  let normalized = normalize_format_code(code)
  if normalized == "" {
    return raw
  }
  if has_date_tokens(normalized) {
    return format_excel_date(raw, normalized)
  }
  let percent = normalized.contains("%")
  let decimals = count_decimal_places(normalized)
  let use_group = normalized.contains(",")
  format_number_simple(raw, decimals, use_group, percent)
}

///|
fn normalize_format_code(code : String) -> String {
  let section = match code.find(";") {
    Some(pos) => code[:pos] catch { _ => code }
    None => code
  }
  strip_format_decorations(section).to_lower()
}

///|
fn strip_format_decorations(code : StringView) -> String {
  let sb = StringBuilder::new()
  let mut in_quote = false
  let mut bracket_depth = 0
  let mut escape_next = false
  for c in code {
    if escape_next {
      if !in_quote && bracket_depth == 0 {
        sb.write_char(c)
      }
      escape_next = false
      continue
    }
    match c {
      '\\' => escape_next = true
      '"' => in_quote = !in_quote
      '[' => if !in_quote { bracket_depth = bracket_depth + 1 }
      ']' =>
        if !in_quote && bracket_depth > 0 {
          bracket_depth = bracket_depth - 1
        }
      _ => if !in_quote && bracket_depth == 0 { sb.write_char(c) }
    }
  }
  sb.to_string()
}

///|
fn has_date_tokens(code : StringView) -> Bool {
  code.contains("y") ||
  code.contains("m") ||
  code.contains("d") ||
  code.contains("h") ||
  code.contains("s")
}

///|
fn count_decimal_places(code : StringView) -> Int {
  let text = code.to_string()
  let dot = match text.find(".") {
    Some(pos) => pos
    None => return 0
  }
  let rest = text[dot + 1:] catch { _ => return 0 }
  let mut count = 0
  for c in rest {
    match c {
      '0' | '#' => count = count + 1
      _ => return count
    }
  }
  count
}

///|
fn format_number_simple(
  raw : String,
  decimals : Int,
  use_group : Bool,
  percent : Bool,
) -> String {
  let value = @strconv.parse_double(raw) catch { _ => return raw }
  let scaled = if percent { value * 100.0 } else { value }
  let formatted = format_fixed_number(scaled, decimals, use_group)
  if percent {
    formatted + "%"
  } else {
    formatted
  }
}

///|
fn format_fixed_number(
  value : Double,
  decimals : Int,
  use_group : Bool,
) -> String {
  let negative = value < 0.0
  let abs_value = if negative { -value } else { value }
  let places = if decimals < 0 {
    0
  } else if decimals > 9 {
    9
  } else {
    decimals
  }
  let scale = pow10_int(places)
  let scaled = Double::round(abs_value * Double::from_int(scale))
  let scaled_int = Double::to_int(scaled)
  let int_part = if scale == 0 { scaled_int } else { scaled_int / scale }
  let frac_part = if scale == 0 { 0 } else { scaled_int % scale }
  let result = StringBuilder::new()
  if negative {
    result.write_char('-')
  }
  result.write_view(format_int_grouped(int_part, use_group))
  if places > 0 {
    result.write_char('.')
    result.write_view(pad_left_int(frac_part, places))
  }
  result.to_string()
}

///|
fn pow10_int(exp : Int) -> Int {
  let mut value = 1
  let mut i = 0
  let limit = if exp > 9 { 9 } else { exp }
  while i < limit {
    value = value * 10
    i = i + 1
  }
  value
}

///|
fn pad_left_int(value : Int, width : Int) -> String {
  let text = value.to_string()
  if text.length() >= width {
    return text
  }
  let sb = StringBuilder::new()
  let mut i = text.length()
  while i < width {
    sb.write_char('0')
    i = i + 1
  }
  sb.write_view(text)
  sb.to_string()
}

///|
fn format_int_grouped(value : Int, use_group : Bool) -> String {
  let text = value.to_string()
  if !use_group {
    return text
  }
  let len = text.length()
  let sb = StringBuilder::new()
  let mut i = 0
  for c in text {
    if i > 0 && (len - i) % 3 == 0 {
      sb.write_char(',')
    }
    sb.write_char(c)
    i = i + 1
  }
  sb.to_string()
}

///|
fn format_excel_date(raw : String, pattern : String) -> String {
  let value = @strconv.parse_double(raw) catch { _ => return raw }
  let parts = excel_serial_to_parts(value)
  match parts {
    None => raw
    Some((year, month, day, hour, minute, second)) =>
      format_date_pattern(pattern, year, month, day, hour, minute, second)
  }
}

///|
fn excel_serial_to_parts(value : Double) -> (Int, Int, Int, Int, Int, Int)? {
  if value < 0.0 {
    return None
  }
  let whole = Double::to_int(Double::floor(value))
  let mut days = whole
  if days > 59 {
    days = days - 1
  }
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
  let (year, month, day) = add_days_to_base(days + add_day)
  let hour = total_seconds / 3600
  let minute = total_seconds % 3600 / 60
  let second = total_seconds % 60
  Some((year, month, day, hour, minute, second))
}

///|
fn add_days_to_base(days : Int) -> (Int, Int, Int) {
  let mut year = 1899
  let mut month = 12
  let mut day = 31
  let mut remaining = days
  while remaining > 0 {
    let dim = days_in_month(year, month)
    if day + remaining <= dim {
      day = day + remaining
      remaining = 0
    } else {
      remaining = remaining - (dim - day + 1)
      day = 1
      month = month + 1
      if month > 12 {
        month = 1
        year = year + 1
      }
    }
  }
  (year, month, day)
}

///|
fn is_leap_year(year : Int) -> Bool {
  if year % 400 == 0 {
    true
  } else if year % 100 == 0 {
    false
  } else {
    year % 4 == 0
  }
}

///|
fn days_in_month(year : Int, month : Int) -> Int {
  match month {
    1 | 3 | 5 | 7 | 8 | 10 | 12 => 31
    4 | 6 | 9 | 11 => 30
    2 => if is_leap_year(year) { 29 } else { 28 }
    _ => 30
  }
}

///|
fn format_date_pattern(
  pattern : String,
  year : Int,
  month : Int,
  day : Int,
  hour : Int,
  minute : Int,
  second : Int,
) -> String {
  let normalized = normalize_format_code(pattern)
  match normalized {
    "m/d/yy" => "\{month}/\{day}/\{pad_left_int(year % 100, 2)}"
    "m/d/yyyy" => "\{month}/\{day}/\{pad_left_int(year, 4)}"
    "mm/dd/yy" =>
      "\{pad_left_int(month, 2)}/\{pad_left_int(day, 2)}/\{pad_left_int(year % 100, 2)}"
    "yyyy-mm-dd" =>
      "\{pad_left_int(year, 4)}-\{pad_left_int(month, 2)}-\{pad_left_int(day, 2)}"
    "d-mmm-yy" =>
      "\{day}-\{month_short_name(month)}-\{pad_left_int(year % 100, 2)}"
    "d-mmm" => "\{day}-\{month_short_name(month)}"
    "mmm-yy" => "\{month_short_name(month)}-\{pad_left_int(year % 100, 2)}"
    "h:mm am/pm" => "\{hour12(hour)}:\{pad_left_int(minute, 2)} \{am_pm(hour)}"
    "h:mm:ss am/pm" =>
      "\{hour12(hour)}:\{pad_left_int(minute, 2)}:\{pad_left_int(second, 2)} \{am_pm(hour)}"
    "h:mm" => "\{hour}:\{pad_left_int(minute, 2)}"
    "h:mm:ss" => "\{hour}:\{pad_left_int(minute, 2)}:\{pad_left_int(second, 2)}"
    "m/d/yy h:mm" =>
      "\{month}/\{day}/\{pad_left_int(year % 100, 2)} \{hour}:\{pad_left_int(minute, 2)}"
    "m/d/yy h:mm:ss" =>
      "\{month}/\{day}/\{pad_left_int(year % 100, 2)} \{hour}:\{pad_left_int(minute, 2)}:\{pad_left_int(second, 2)}"
    _ =>
      format_date_pattern_tokens(
        normalized, year, month, day, hour, minute, second,
      )
  }
}

///|
fn format_date_pattern_tokens(
  normalized : String,
  year : Int,
  month : Int,
  day : Int,
  hour : Int,
  minute : Int,
  second : Int,
) -> String {
  let use_ampm = normalized.contains("am/pm")
  let hour_value = if use_ampm { hour12(hour) } else { hour }
  let len = normalized.length()
  let sb = StringBuilder::new()
  let mut i = 0
  while i < len {
    if i + 4 < len &&
      normalized[i] == 'a' &&
      normalized[i + 1] == 'm' &&
      normalized[i + 2] == '/' &&
      normalized[i + 3] == 'p' &&
      normalized[i + 4] == 'm' {
      sb.write_view(am_pm(hour))
      i = i + 5
      continue
    }
    let c = normalized[i]
    if c == 'y' || c == 'm' || c == 'd' || c == 'h' || c == 's' {
      let mut j = i
      while j < len && normalized[j] == c {
        j = j + 1
      }
      let count = j - i
      let text = match c {
        'y' =>
          if count == 2 {
            pad_left_int(year % 100, 2)
          } else if count >= 4 {
            pad_left_int(year, 4)
          } else {
            year.to_string()
          }
        'm' => {
          let prev_is_colon = i > 0 && normalized[i - 1] == ':'
          let next_is_colon = j < len && normalized[j] == ':'
          let is_minute = prev_is_colon || next_is_colon
          if is_minute {
            if count >= 2 {
              pad_left_int(minute, 2)
            } else {
              minute.to_string()
            }
          } else if count >= 4 {
            month_long_name(month)
          } else if count == 3 {
            month_short_name(month)
          } else if count == 2 {
            pad_left_int(month, 2)
          } else {
            month.to_string()
          }
        }
        'd' => if count >= 2 { pad_left_int(day, 2) } else { day.to_string() }
        'h' =>
          if count >= 2 {
            pad_left_int(hour_value, 2)
          } else {
            hour_value.to_string()
          }
        's' =>
          if count >= 2 {
            pad_left_int(second, 2)
          } else {
            second.to_string()
          }
        _ => ""
      }
      sb.write_view(text)
      i = j
      continue
    }
    sb.write_view(try! normalized[i:i + 1])
    i = i + 1
  }
  sb.to_string()
}

///|
fn month_short_name(month : Int) -> String {
  match month {
    1 => "Jan"
    2 => "Feb"
    3 => "Mar"
    4 => "Apr"
    5 => "May"
    6 => "Jun"
    7 => "Jul"
    8 => "Aug"
    9 => "Sep"
    10 => "Oct"
    11 => "Nov"
    12 => "Dec"
    _ => ""
  }
}

///|
fn month_long_name(month : Int) -> String {
  match month {
    1 => "January"
    2 => "February"
    3 => "March"
    4 => "April"
    5 => "May"
    6 => "June"
    7 => "July"
    8 => "August"
    9 => "September"
    10 => "October"
    11 => "November"
    12 => "December"
    _ => ""
  }
}

///|
fn hour12(hour : Int) -> Int {
  let h = hour % 12
  if h == 0 {
    12
  } else {
    h
  }
}

///|
fn am_pm(hour : Int) -> String {
  if hour >= 12 {
    "PM"
  } else {
    "AM"
  }
}
