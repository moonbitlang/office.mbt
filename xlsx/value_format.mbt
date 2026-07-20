///|
fn format_cell_value(
  value_type : CellValueType,
  raw : String,
  style : Style?,
  options : Options,
  use_1904_format? : Bool = false,
) -> String raise XlsxError {
  format_cell_value_limited(value_type, raw, style, options, use_1904_format~)
}

///|
/// Formats a cell while optionally bounding the materialized UTF-16 output.
/// The text-pattern path checks each append before it reaches `StringBuilder`,
/// so repeated `@` placeholders cannot amplify a small cell into an unbounded
/// intermediate string.
fn format_cell_value_limited(
  value_type : CellValueType,
  raw : String,
  style : Style?,
  options : Options,
  use_1904_format? : Bool = false,
  max_output_chars? : Int,
) -> String raise XlsxError {
  let output = match value_type {
    String =>
      match style {
        Some(style) =>
          match style.number_format {
            Some(format) => format_text_value(raw, format, max_output_chars?)
            None => raw
          }
        None => raw
      }
    Error => raw
    Bool => if parse_cell_bool(raw) { "TRUE" } else { "FALSE" }
    Number =>
      match style {
        Some(style) =>
          match style.number_format {
            Some(format) =>
              format_number_with_format(
                raw,
                format,
                options,
                use_1904_format,
                max_output_chars?,
              )
            None => raw
          }
        None => raw
      }
  }
  check_formatted_output_length(output, max_output_chars)
  output
}

///|
// Bounded formatting is used from cooperative async commands. Keeping every
// synchronous format program below half of the command's 64-KiB work quantum
// ensures one cell cannot monopolize the scheduler before the caller reaches
// its next suspension point.
let max_bounded_format_program_chars : Int = 32 * 1024

///|
fn check_bounded_format_program(
  program : StringView,
  maximum : Int?,
) -> Unit raise XlsxError {
  match maximum {
    None => ()
    Some(_) =>
      if program.length() > max_bounded_format_program_chars {
        raise ResourceLimitExceeded(
          kind="formatted_number_format_work_units",
          limit=max_bounded_format_program_chars,
          actual=program.length(),
        )
      }
  }
}

///|
// Proves a conservative upper bound before any formatted result is allocated.
// `program_multiplier` covers literal prefixes/suffixes, grouping separators,
// fraction placeholders, and date-token expansion. Callers select a tighter
// multiplier for the format family they are about to execute.
fn check_bounded_numeric_output(
  fallback_chars : Int,
  program_chars : Int,
  program_multiplier : Int,
  fixed_overhead : Int,
  maximum : Int?,
) -> Unit raise XlsxError {
  match maximum {
    None => ()
    Some(limit) => {
      if limit < 0 {
        raise InvalidOptions(msg="formatted output limit must be non-negative")
      }
      if fallback_chars > limit ||
        program_chars < 0 ||
        program_multiplier < 0 ||
        fixed_overhead < 0 ||
        fixed_overhead > limit ||
        program_multiplier == 0 ||
        program_chars > (limit - fixed_overhead) / program_multiplier {
        raise ResourceLimitExceeded(
          kind="formatted_cell_value_chars",
          limit~,
          actual=if limit < 0x7fffffff { limit + 1 } else { limit },
        )
      }
    }
  }
}

///|
fn format_text_value(
  raw : String,
  format : NumberFormat,
  max_output_chars? : Int,
) -> String raise XlsxError {
  match format {
    Builtin(_id) => raw
    Custom(code) =>
      if code.to_lower().trim() is "general" {
        raw
      } else {
        check_bounded_format_program(code, max_output_chars)
        format_text_pattern(raw, code, max_output_chars?)
      }
  }
}

///|
fn checked_formatted_output_growth(
  current : Int,
  amount : Int,
  maximum : Int?,
) -> Int raise XlsxError {
  match maximum {
    None => current + amount
    Some(limit) => {
      if limit < 0 {
        raise InvalidOptions(msg="formatted output limit must be non-negative")
      }
      if amount < 0 || current < 0 || amount > limit - current {
        raise ResourceLimitExceeded(
          kind="formatted_cell_value_chars",
          limit~,
          actual=if limit < 0x7fffffff { limit + 1 } else { limit },
        )
      }
      current + amount
    }
  }
}

///|
fn check_formatted_output_length(
  output : String,
  maximum : Int?,
) -> Unit raise XlsxError {
  ignore(checked_formatted_output_growth(0, output.length(), maximum))
}

///|
fn format_number_with_format(
  raw : String,
  format : NumberFormat,
  options : Options,
  use_1904_format : Bool,
  max_output_chars? : Int,
) -> String raise XlsxError {
  match format {
    Builtin(id) =>
      format_number_builtin(
        raw,
        id,
        options,
        use_1904_format,
        max_output_chars?,
      )
    Custom(code) =>
      format_number_code(
        raw,
        code,
        options,
        use_1904_format~,
        max_output_chars?,
      )
  }
}

///|
fn format_number_builtin(
  raw : String,
  id : Int,
  options : Options,
  use_1904_format : Bool,
  max_output_chars? : Int,
) -> String raise XlsxError {
  let short_date = options.short_date_pattern
  let long_date = options.long_date_pattern
  let long_time = options.long_time_pattern
  match id {
    0 => raw
    1 => {
      check_bounded_numeric_output(raw.length(), 0, 1, 64, max_output_chars)
      format_number_simple(raw, 0, false, false)
    }
    2 => {
      check_bounded_numeric_output(raw.length(), 0, 1, 64, max_output_chars)
      format_number_simple(raw, 2, false, false)
    }
    3 => {
      check_bounded_numeric_output(raw.length(), 0, 1, 64, max_output_chars)
      format_number_simple(raw, 0, true, false)
    }
    4 => {
      check_bounded_numeric_output(raw.length(), 0, 1, 64, max_output_chars)
      format_number_simple(raw, 2, true, false)
    }
    9 => {
      check_bounded_numeric_output(raw.length(), 0, 1, 65, max_output_chars)
      format_number_simple(raw, 0, false, true)
    }
    10 => {
      check_bounded_numeric_output(raw.length(), 0, 1, 65, max_output_chars)
      format_number_simple(raw, 2, false, true)
    }
    14 =>
      if short_date != "" {
        format_excel_date(raw, short_date, use_1904_format~, max_output_chars?)
      } else {
        format_excel_date(raw, "mm-dd-yy", use_1904_format~, max_output_chars?)
      }
    15 =>
      if long_date != "" {
        format_excel_date(raw, long_date, use_1904_format~, max_output_chars?)
      } else {
        format_excel_date(raw, "d-mmm-yy", use_1904_format~, max_output_chars?)
      }
    16 => format_excel_date(raw, "d-mmm", use_1904_format~, max_output_chars?)
    17 => format_excel_date(raw, "mmm-yy", use_1904_format~, max_output_chars?)
    18 =>
      format_excel_date(raw, "h:mm AM/PM", use_1904_format~, max_output_chars?)
    19 =>
      format_excel_date(
        raw,
        "h:mm:ss AM/PM",
        use_1904_format~,
        max_output_chars?,
      )
    20 =>
      if long_time != "" {
        format_excel_date(raw, long_time, use_1904_format~, max_output_chars?)
      } else {
        format_excel_date(raw, "hh:mm", use_1904_format~, max_output_chars?)
      }
    21 =>
      if long_time != "" {
        format_excel_date(raw, long_time, use_1904_format~, max_output_chars?)
      } else {
        format_excel_date(raw, "hh:mm:ss", use_1904_format~, max_output_chars?)
      }
    22 =>
      if short_date != "" {
        format_excel_date(
          raw,
          "\{short_date} hh:mm",
          use_1904_format~,
          max_output_chars?,
        )
      } else {
        format_excel_date(
          raw,
          "m/d/yy hh:mm",
          use_1904_format~,
          max_output_chars?,
        )
      }
    // language-glyph builtin IDs resolve through the workbook culture
    27..=36 | 50..=62 | 67..=81 =>
      match lang_num_fmt_code(options, id) {
        Some(code) =>
          if code == "" {
            raw
          } else {
            format_number_code(
              raw,
              code,
              options,
              use_1904_format~,
              max_output_chars?,
            )
          }
        None => raw
      }
    _ => raw
  }
}

///|
fn format_number_code(
  raw : String,
  code : String,
  options : Options,
  use_1904_format? : Bool = false,
  max_output_chars? : Int,
) -> String raise XlsxError {
  let _ = options
  check_bounded_format_program(code, max_output_chars)
  let sections = split_format_sections(code)
  if sections.length() == 0 {
    return raw
  }
  let parsed : Result[Double, Error] = Ok(@string.parse_double(raw)) catch {
    e => Err(e)
  }
  match parsed {
    Err(_) => format_text_pattern(raw, code, max_output_chars?)
    Ok(value) => {
      let (section, add_minus) = select_format_section(sections, value)
      let (pattern, locale, currency_prefix) = parse_section_metadata(section)
      if pattern == "" {
        return ""
      }
      let normalized = pattern.to_lower()
      if normalized == "general" {
        check_bounded_numeric_output(raw.length(), 0, 1, 0, max_output_chars)
        return format_general_number(raw)
      }
      if has_date_tokens(pattern) {
        match locale {
          Some(tag) => if !is_supported_locale(tag) { return raw }
          None => ()
        }
        check_bounded_numeric_output(
          raw.length(),
          code.length(),
          3,
          32,
          max_output_chars,
        )
        let formatted = format_excel_date(raw, pattern, use_1904_format~)
        let output = currency_prefix + formatted
        return if add_minus { "-" + output } else { output }
      }
      if !pattern_has_number_placeholders(pattern) {
        check_bounded_numeric_output(0, code.length(), 2, 2, max_output_chars)
        let literal = render_literal_segment(pattern)
        let output = currency_prefix + literal
        return if add_minus { "-" + output } else { output }
      }
      check_bounded_numeric_output(0, code.length(), 4, 64, max_output_chars)
      format_number_pattern(raw, pattern, add_minus, currency_prefix)
    }
  }
}

///|
fn split_format_sections(code : String) -> Array[String] {
  let sections : Array[String] = []
  let mut current = StringBuilder::new()
  let mut in_quote = false
  let mut escape_next = false
  let mut bracket_depth = 0
  for c in code {
    if escape_next {
      current.write_char(c)
      escape_next = false
      continue
    }
    match c {
      '\\' => {
        escape_next = true
        current.write_char(c)
      }
      '"' => {
        in_quote = !in_quote
        current.write_char(c)
      }
      '[' => {
        if !in_quote {
          bracket_depth = bracket_depth + 1
        }
        current.write_char(c)
      }
      ']' => {
        if !in_quote && bracket_depth > 0 {
          bracket_depth = bracket_depth - 1
        }
        current.write_char(c)
      }
      ';' =>
        if !in_quote && bracket_depth == 0 {
          sections.push(current.to_string())
          current = StringBuilder::new()
        } else {
          current.write_char(c)
        }
      _ => current.write_char(c)
    }
  }
  sections.push(current.to_string())
  sections
}

///|
fn select_format_section(
  sections : ArrayView[String],
  value : Double,
) -> (String, Bool) {
  let mut idx = 0
  let mut add_minus = false
  if value < 0.0 {
    if sections.length() >= 2 {
      idx = 1
    } else {
      add_minus = true
    }
  } else if value == 0.0 && sections.length() >= 3 {
    idx = 2
  }
  (sections[idx], add_minus)
}

///|
fn parse_section_metadata(section : String) -> (String, String?, String) {
  let sb = StringBuilder::new()
  let mut in_quote = false
  let mut escape_next = false
  let mut skip_next = false
  let mut locale : String? = None
  let mut currency_prefix = ""
  let len = section.length()
  let mut i = 0
  while i < len {
    let c = section[i]
    if escape_next {
      sb.write_view(section[i:i + 1])
      escape_next = false
      i = i + 1
      continue
    }
    if skip_next {
      skip_next = false
      i = i + 1
      continue
    }
    match c {
      '\\' => {
        escape_next = true
        sb.write_char('\\')
      }
      '"' => {
        in_quote = !in_quote
        sb.write_char('"')
      }
      '_' => if !in_quote { skip_next = true } else { sb.write_char('_') }
      '*' => if !in_quote { skip_next = true } else { sb.write_char('*') }
      '[' =>
        if !in_quote {
          let mut j = i + 1
          while j < len && section[j] != ']' {
            j = j + 1
          }
          if j < len {
            let content = section[i + 1:j]
            let lower = content.to_lower().to_owned()
            if lower == "h" ||
              lower == "hh" ||
              lower == "m" ||
              lower == "mm" ||
              lower == "s" ||
              lower == "ss" {
              sb.write_char('[')
              sb.write_view(lower)
              sb.write_char(']')
            } else if content.has_prefix("$") {
              let trimmed = content[1:]
              match trimmed.rev_find("-") {
                Some(pos) => {
                  let prefix = trimmed[:pos].to_owned()
                  let tag = trimmed[pos + 1:].to_owned()
                  if prefix != "" {
                    currency_prefix = prefix
                  }
                  if tag != "" {
                    locale = Some(tag)
                  }
                }
                None => ()
              }
            }
            i = j
          }
        } else {
          sb.write_char('[')
        }
      _ => sb.write_view(section[i:i + 1])
    }
    i = i + 1
  }
  (sb.to_string(), locale, currency_prefix)
}

///|
fn is_supported_locale(tag : String) -> Bool {
  let normalized = tag.to_lower().trim().to_owned()
  normalized == "409" ||
  normalized == "0409" ||
  normalized == "en-us" ||
  normalized == "en_us"
}

///|
fn render_literal_segment(segment : String) -> String {
  let sb = StringBuilder::new()
  let mut in_quote = false
  let mut escape_next = false
  let mut skip_next = false
  for c in segment {
    if escape_next {
      sb.write_char(c)
      escape_next = false
      continue
    }
    if skip_next {
      skip_next = false
      continue
    }
    match c {
      '\\' => escape_next = true
      '"' => in_quote = !in_quote
      '_' => if !in_quote { skip_next = true } else { sb.write_char('_') }
      '*' => if !in_quote { skip_next = true } else { sb.write_char('*') }
      _ => sb.write_char(c)
    }
  }
  sb.to_string()
}

///|
fn format_text_pattern(
  raw : String,
  code : String,
  max_output_chars? : Int,
) -> String raise XlsxError {
  let sections = split_format_sections(code)
  if sections.length() == 0 {
    return raw
  }
  let section = if sections.length() >= 4 { sections[3] } else { sections[0] }
  let (pattern, _locale, currency_prefix) = parse_section_metadata(section)
  let sb = StringBuilder::new()
  let mut output_chars = checked_formatted_output_growth(
    0,
    currency_prefix.length(),
    max_output_chars,
  )
  sb.write_view(currency_prefix)
  let mut in_quote = false
  let mut escape_next = false
  let mut skip_next = false
  for c in pattern {
    if escape_next {
      output_chars = checked_formatted_output_growth(
        output_chars,
        if c.to_int() > 0xffff {
          2
        } else {
          1
        },
        max_output_chars,
      )
      sb.write_char(c)
      escape_next = false
      continue
    }
    if skip_next {
      skip_next = false
      continue
    }
    match c {
      '\\' => escape_next = true
      '"' => in_quote = !in_quote
      '_' =>
        if !in_quote {
          skip_next = true
        } else {
          output_chars = checked_formatted_output_growth(
            output_chars, 1, max_output_chars,
          )
          sb.write_char('_')
        }
      '*' =>
        if !in_quote {
          skip_next = true
        } else {
          output_chars = checked_formatted_output_growth(
            output_chars, 1, max_output_chars,
          )
          sb.write_char('*')
        }
      '@' =>
        if !in_quote {
          output_chars = checked_formatted_output_growth(
            output_chars,
            raw.length(),
            max_output_chars,
          )
          sb.write_view(raw)
        } else {
          output_chars = checked_formatted_output_growth(
            output_chars, 1, max_output_chars,
          )
          sb.write_char('@')
        }
      _ => {
        output_chars = checked_formatted_output_growth(
          output_chars,
          if c.to_int() > 0xffff {
            2
          } else {
            1
          },
          max_output_chars,
        )
        sb.write_char(c)
      }
    }
  }
  sb.to_string()
}

///|
fn has_date_tokens(code : StringView) -> Bool {
  let mut in_quote = false
  let mut escape_next = false
  let mut i = 0
  let len = code.length()
  let lower = code.to_owned().to_lower()
  while i < len {
    let c = code[i]
    if escape_next {
      escape_next = false
      i = i + 1
      continue
    }
    match c {
      '\\' => escape_next = true
      '"' => in_quote = !in_quote
      '[' =>
        if !in_quote {
          let mut j = i + 1
          while j < len && code[j] != ']' {
            j = j + 1
          }
          if j < len {
            let content = lower[i + 1:j]
            if content == "h" ||
              content == "hh" ||
              content == "m" ||
              content == "mm" ||
              content == "s" ||
              content == "ss" {
              return true
            }
            i = j
          }
        }
      _ =>
        if !in_quote &&
          (
            c == 'y' ||
            c == 'Y' ||
            c == 'm' ||
            c == 'M' ||
            c == 'd' ||
            c == 'D' ||
            c == 'h' ||
            c == 'H' ||
            c == 's' ||
            c == 'S'
          ) {
          return true
        }
    }
    i = i + 1
  }
  lower.contains("am/pm") || lower.contains("a/p")
}

///|
fn pattern_has_number_placeholders(code : StringView) -> Bool {
  let mut in_quote = false
  let mut escape_next = false
  for c in code {
    if escape_next {
      escape_next = false
      continue
    }
    match c {
      '\\' => escape_next = true
      '"' => in_quote = !in_quote
      _ => if !in_quote && (c == '0' || c == '#' || c == '?') { return true }
    }
  }
  false
}

///|
fn format_number_pattern(
  raw : String,
  pattern : String,
  add_minus : Bool,
  currency_prefix : String,
) -> String raise XlsxError {
  let value = @string.parse_double(raw) catch { _ => return raw }
  if value.is_nan() || value.is_inf() {
    raise InvalidXml(msg="cell number must be finite")
  }
  let negative = value < 0.0
  let abs_value = if negative { -value } else { value }
  let (prefix, suffix, info) = parse_number_pattern(pattern)
  let scaled = scale_number_for_percent_format(abs_value, info.percent_count)
  let formatted = if info.has_fraction {
    format_fraction_number(scaled, info)
  } else if info.has_scientific {
    format_scientific_number(scaled, info)
  } else {
    format_decimal_number(scaled, info)
  }
  let output = StringBuilder::new()
  if add_minus {
    output.write_char('-')
  }
  output.write_view(currency_prefix)
  output.write_view(prefix)
  output.write_view(formatted)
  output.write_view(suffix)
  output.to_string()
}

///|
fn scale_number_for_percent_format(
  value : Double,
  percent_count : Int,
) -> Double raise XlsxError {
  // Applying the entire power first can overflow even when the final product
  // is representable (for example, 1e-300 * 100^155). Scaling one marker at a
  // time preserves that finite result and lets us fail at the first genuinely
  // non-finite intermediate. Keeping zero on an explicit fast path also avoids
  // manufacturing NaN from IEEE-754's 0 * infinity rule.
  if value == 0.0 || percent_count == 0 {
    return value
  }
  let mut scaled = value
  for _ in 0..<percent_count {
    scaled = scaled * 100.0
    if scaled.is_nan() || scaled.is_inf() {
      raise InvalidXml(msg="number format scale must remain finite")
    }
  }
  scaled
}

///|
priv struct NumberPatternInfo {
  min_int_digits : Int
  required_decimals : Int
  max_decimals : Int
  use_group : Bool
  percent_count : Int
  has_scientific : Bool
  exp_digits : Int
  exp_upper : Bool
  has_fraction : Bool
  numerator_digits : Int
  denominator_digits : Int
}

///|
fn parse_number_pattern(
  pattern : String,
) -> (String, String, NumberPatternInfo) {
  let len = pattern.length()
  let mut in_quote = false
  let mut escape_next = false
  let mut first_placeholder : Int? = None
  let mut last_placeholder : Int? = None
  let mut percent_count = 0
  let mut has_scientific = false
  let mut exp_digits = 0
  let mut exp_upper = false
  let mut has_fraction = false
  let mut i = 0
  while i < len {
    let c = pattern[i]
    if escape_next {
      escape_next = false
      i = i + 1
      continue
    }
    match c {
      '\\' => escape_next = true
      '"' => in_quote = !in_quote
      '%' => if !in_quote { percent_count = percent_count + 1 }
      'E' | 'e' =>
        if !in_quote {
          has_scientific = true
          exp_upper = c == 'E'
          let mut j = i + 1
          if j < len && (pattern[j] == '+' || pattern[j] == '-') {
            j = j + 1
          }
          let mut digits = 0
          while j < len && (pattern[j] == '0' || pattern[j] == '#') {
            digits = digits + 1
            j = j + 1
          }
          exp_digits = if digits > 0 { digits } else { exp_digits }
        }
      '0' | '#' | '?' =>
        if !in_quote {
          if first_placeholder is None {
            first_placeholder = Some(i)
          }
          last_placeholder = Some(i)
        }
      _ => ()
    }
    i = i + 1
  }
  let (prefix, suffix) = match (first_placeholder, last_placeholder) {
    (Some(start), Some(end)) => {
      let prefix = render_literal_segment(pattern[:start].to_owned())
      let suffix = render_literal_segment(pattern[end + 1:].to_owned())
      (prefix, suffix)
    }
    _ => (render_literal_segment(pattern), "")
  }
  let placeholder_body = match (first_placeholder, last_placeholder) {
    (Some(start), Some(end)) => pattern[start:end + 1].to_owned()
    _ => ""
  }
  let mut min_int_digits = 0
  let mut required_decimals = 0
  let mut max_decimals = 0
  let mut use_group = false
  let mut numerator_digits = 0
  let mut denominator_digits = 0
  let slash_pos = placeholder_body.find("/")
  has_fraction = slash_pos is Some(_)
  match slash_pos {
    Some(pos) => {
      let left = placeholder_body[:pos].to_owned()
      let right = placeholder_body[pos + 1:].to_owned()
      let mut j = left.length() - 1
      while j >= 0 {
        let ch = left[j]
        if ch == '0' || ch == '#' || ch == '?' {
          numerator_digits = numerator_digits + 1
          j = j - 1
        } else {
          break
        }
      }
      let int_part = if j >= 0 { left[:j + 1].to_owned() } else { "" }
      use_group = int_part.contains(",")
      for c in int_part {
        if c == '0' {
          min_int_digits = min_int_digits + 1
        }
      }
      let mut k = 0
      while k < right.length() {
        let ch = right[k]
        if ch == '0' || ch == '#' || ch == '?' {
          denominator_digits = denominator_digits + 1
          k = k + 1
        } else {
          break
        }
      }
    }
    None => {
      let dot_pos = placeholder_body.find(".")
      let (int_part, dec_part) = match dot_pos {
        Some(pos) =>
          (
            placeholder_body[:pos].to_owned(),
            placeholder_body[pos + 1:].to_owned(),
          )
        None => (placeholder_body, "")
      }
      use_group = int_part.contains(",")
      for c in int_part {
        if c == '0' {
          min_int_digits = min_int_digits + 1
        }
      }
      for c in dec_part {
        match c {
          '0' => {
            required_decimals = required_decimals + 1
            max_decimals = max_decimals + 1
          }
          '#' | '?' => max_decimals = max_decimals + 1
          'E' | 'e' => break
          _ => ()
        }
      }
    }
  }
  let info = {
    min_int_digits,
    required_decimals,
    max_decimals,
    use_group,
    percent_count,
    has_scientific,
    exp_digits,
    exp_upper,
    has_fraction,
    numerator_digits,
    denominator_digits,
  }
  (prefix, suffix, info)
}

///|
fn format_general_number(raw : String) -> String {
  let value = @string.parse_double(raw) catch { _ => return raw }
  let negative = value < 0.0
  let abs_value = if negative { -value } else { value }
  let int_part = Double::to_int64(Double::floor(abs_value))
  let int_len = int_part.to_string().length()
  if int_len >= 11 {
    return raw
  }
  let decimals = if int_len >= 10 { 0 } else { 10 - int_len }
  let formatted = format_decimal_number(abs_value, {
    min_int_digits: 1,
    required_decimals: 0,
    max_decimals: decimals,
    use_group: false,
    percent_count: 0,
    has_scientific: false,
    exp_digits: 0,
    exp_upper: false,
    has_fraction: false,
    numerator_digits: 0,
    denominator_digits: 0,
  })
  if negative {
    "-" + formatted
  } else {
    formatted
  }
}

///|
fn format_scientific_number(value : Double, info : NumberPatternInfo) -> String {
  if value == 0.0 {
    let mantissa = format_fixed_number(0.0, info.max_decimals, false, 1)
    let exp = pad_left_int(
      0,
      if info.exp_digits > 0 {
        info.exp_digits
      } else {
        2
      },
    )
    let marker = if info.exp_upper { "E" } else { "e" }
    return mantissa + marker + "+" + exp
  }
  let abs_value = value.abs()
  let mut exp = Double::to_int(@math.log10(abs_value))
  let mut mantissa = abs_value / @math.pow(10.0, Double::from_int(exp))
  let mut mantissa_text = format_fixed_number(
    mantissa,
    info.max_decimals,
    false,
    1,
  )
  if mantissa_text.has_prefix("10") {
    exp = exp + 1
    mantissa = mantissa / 10.0
    mantissa_text = format_fixed_number(mantissa, info.max_decimals, false, 1)
  }
  let marker = if info.exp_upper { "E" } else { "e" }
  let sign = if exp < 0 { "-" } else { "+" }
  let exp_abs = if exp < 0 { -exp } else { exp }
  let exp_text = pad_left_int(
    exp_abs,
    if info.exp_digits > 0 {
      info.exp_digits
    } else {
      2
    },
  )
  let result = mantissa_text + marker + sign + exp_text
  if value < 0.0 {
    "-" + result
  } else {
    result
  }
}

///|
fn format_fraction_number(value : Double, info : NumberPatternInfo) -> String {
  // The integer part is non-negative here. Keep the full UInt64 range instead
  // of passing through Double::to_int64, whose saturating conversion would
  // manufacture Int64::MAX at the signed boundary.
  if value >= uint64_exclusive_upper_bound_double {
    return value.to_string()
  }
  let integer_double = Double::floor(value)
  let int_part = nonnegative_double_to_uint64(integer_double)
  let frac = value - integer_double
  let integer_text = format_uint64_padded(
    int_part,
    info.min_int_digits,
    info.use_group,
  )
  if info.numerator_digits <= 0 || info.denominator_digits <= 0 {
    return integer_text
  }
  let fraction = float_to_fraction(
    frac,
    info.numerator_digits,
    info.denominator_digits,
  )
  integer_text + " " + fraction
}

///|
fn float_to_fraction(
  value : Double,
  numerator_placeholders : Int,
  denominator_placeholders : Int,
) -> String {
  if denominator_placeholders <= 0 {
    return ""
  }
  let limit = pow10_int64(denominator_placeholders)
  let (num, den) = float_to_frac_use_continued_fraction(value, limit)
  if num == 0L {
    return String::repeat(
      " ",
      numerator_placeholders + denominator_placeholders + 1,
    )
  }
  let num_str = num.to_string()
  let den_str = den.to_string()
  let num_pad = if numerator_placeholders > num_str.length() {
    numerator_placeholders - num_str.length()
  } else {
    0
  }
  let den_pad = if denominator_placeholders > den_str.length() {
    denominator_placeholders - den_str.length()
  } else {
    0
  }
  String::repeat(" ", num_pad) +
  num_str +
  "/" +
  den_str +
  String::repeat(" ", den_pad)
}

///|
fn float_to_frac_use_continued_fraction(
  value : Double,
  denominator_limit : Int64,
) -> (Int64, Int64) {
  if value.is_nan() || value.is_inf() || value <= 0.0 || denominator_limit <= 1L {
    return (0L, 1L)
  }
  let maximum_int64 = 9_223_372_036_854_775_807L
  let mut p1 : Int64 = 1L
  let mut q1 : Int64 = 0L
  let mut p2 : Int64 = 0L
  let mut q2 : Int64 = 1L
  let mut lasta : Int64 = 0L
  let mut lastb : Int64 = 0L
  let mut r = value
  // A finite Double has at most 53 significant binary digits, so 128
  // continued-fraction steps are more than enough to reach its exact rational
  // representation. The hard bound also makes this helper total if a future
  // backend changes floating-point corner-case behavior.
  for _ in 0..<128 {
    if r.is_nan() || r.is_inf() || r < 0.0 {
      return if lastb > 0L { (lasta, lastb) } else { (0L, 1L) }
    }
    let floored = Double::floor(r)
    if floored >= int64_exclusive_upper_bound_double {
      return if lastb > 0L { (lasta, lastb) } else { (0L, 1L) }
    }
    let a = Double::to_int64(floored)
    if a < 0L ||
      (p1 > 0L && a > (maximum_int64 - p2) / p1) ||
      (q1 > 0L && a > (maximum_int64 - q2) / q1) {
      return if lastb > 0L { (lasta, lastb) } else { (0L, 1L) }
    }
    let curra = a * p1 + p2
    let currb = a * q1 + q2
    if currb <= 0L || currb >= denominator_limit {
      return if lastb > 0L { (lasta, lastb) } else { (0L, 1L) }
    }
    p2 = p1
    q2 = q1
    p1 = curra
    q1 = currb
    let frac = r - a.to_double()
    if frac.abs() < 0.000000000001 {
      return (curra, currb)
    }
    lasta = curra
    lastb = currb
    r = 1.0 / frac
  }
  if lastb > 0L {
    (lasta, lastb)
  } else {
    (0L, 1L)
  }
}

///|
fn pow10_int64(exp : Int) -> Int64 {
  let mut value : Int64 = 1L
  let mut i = 0
  let limit = if exp > 18 { 18 } else { exp }
  while i < limit {
    value = value * 10L
    i = i + 1
  }
  value
}

///|
fn format_number_simple(
  raw : String,
  decimals : Int,
  use_group : Bool,
  percent : Bool,
) -> String raise XlsxError {
  let value = @string.parse_double(raw) catch { _ => return raw }
  if value.is_nan() || value.is_inf() {
    raise InvalidXml(msg="cell number must be finite")
  }
  let scaled = if percent { value * 100.0 } else { value }
  if scaled.is_nan() || scaled.is_inf() {
    raise InvalidXml(msg="number format scale must remain finite")
  }
  let info = {
    min_int_digits: 1,
    required_decimals: decimals,
    max_decimals: decimals,
    use_group,
    percent_count: if percent {
      1
    } else {
      0
    },
    has_scientific: false,
    exp_digits: 0,
    exp_upper: false,
    has_fraction: false,
    numerator_digits: 0,
    denominator_digits: 0,
  }
  let formatted = format_decimal_number(scaled, info)
  if percent {
    formatted + "%"
  } else {
    formatted
  }
}

///|
fn format_decimal_number(value : Double, info : NumberPatternInfo) -> String {
  let negative = value < 0.0
  let abs_value = if negative { -value } else { value }
  let formatted = format_fixed_number(
    abs_value,
    info.max_decimals,
    info.use_group,
    if info.min_int_digits > 0 {
      info.min_int_digits
    } else {
      1
    },
  )
  let trimmed = if info.max_decimals > info.required_decimals {
    trim_optional_decimals(formatted, info.required_decimals)
  } else {
    formatted
  }
  if negative {
    "-" + trimmed
  } else {
    trimmed
  }
}

///|
fn trim_optional_decimals(text : String, required_decimals : Int) -> String {
  let dot = text.find(".")
  match dot {
    None => text
    Some(pos) => {
      let exponent_pos = match text.find("e") {
        Some(value) => value
        None => text.find("E").unwrap_or(text.length())
      }
      // A fallback from fixed-point formatting can be scientific notation.
      // Trim only the significand's fractional zeros and retain the exponent
      // verbatim (especially its trailing zero).
      if exponent_pos < pos {
        return text
      }
      let int_part = text[:pos].to_owned()
      let frac_part = text[pos + 1:exponent_pos].to_owned()
      let exponent = text[exponent_pos:].to_owned()
      let mut end = frac_part.length()
      while end > required_decimals {
        if frac_part[end - 1] == '0' {
          end = end - 1
        } else {
          break
        }
      }
      if end == 0 && required_decimals == 0 {
        int_part + exponent
      } else {
        int_part + "." + frac_part[:end].to_owned() + exponent
      }
    }
  }
}

///|
let int64_exclusive_upper_bound_double : Double = 9_223_372_036_854_775_808.0

///|
let uint64_exclusive_upper_bound_double : Double = 18_446_744_073_709_551_616.0

///|
fn nonnegative_double_to_uint64(value : Double) -> UInt64 {
  // Some MoonBit backends currently saturate Double::to_uint64 at the signed
  // boundary. Split off bit 63 explicitly so behavior is identical across
  // backends for every finite integral Double in [0, 2^64).
  if value >= int64_exclusive_upper_bound_double {
    0x8000_0000_0000_0000UL +
    Double::to_int64(value - int64_exclusive_upper_bound_double).reinterpret_as_uint64()
  } else {
    Double::to_int64(value).reinterpret_as_uint64()
  }
}

///|
fn format_fixed_number(
  value : Double,
  decimals : Int,
  use_group : Bool,
  min_int_digits : Int,
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
  let integer_double = Double::floor(abs_value)
  if integer_double >= uint64_exclusive_upper_bound_double {
    return abs_value.to_string()
  }
  let scale64 = scale.to_uint64()
  let mut int_part = nonnegative_double_to_uint64(integer_double)
  let mut frac_part = nonnegative_double_to_uint64(
    Double::round((abs_value - integer_double) * Double::from_int(scale)),
  )
  if frac_part >= scale64 {
    if int_part == 0xffff_ffff_ffff_ffffUL {
      return abs_value.to_string()
    }
    int_part = int_part + 1UL
    frac_part = 0UL
  }
  let result = StringBuilder::new()
  if negative {
    result.write_char('-')
  }
  result.write_view(format_uint64_padded(int_part, min_int_digits, use_group))
  if places > 0 {
    result.write_char('.')
    result.write_view(pad_left_uint64(frac_part, places))
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
fn pad_left_int64(value : Int64, width : Int) -> String {
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
fn pad_left_uint64(value : UInt64, width : Int) -> String {
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
fn format_uint64_padded(
  value : UInt64,
  min_digits : Int,
  use_group : Bool,
) -> String {
  let text = value.to_string()
  let padding = if min_digits > text.length() {
    min_digits - text.length()
  } else {
    0
  }
  let padded = if padding > 0 {
    String::repeat("0", padding) + text
  } else {
    text
  }
  if use_group {
    format_int_grouped_string(padded)
  } else {
    padded
  }
}

///|
fn format_int_grouped_string(text : String) -> String {
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
fn format_excel_date(
  raw : String,
  pattern : String,
  use_1904_format? : Bool = false,
  max_output_chars? : Int,
) -> String raise XlsxError {
  check_bounded_format_program(pattern, max_output_chars)
  check_bounded_numeric_output(
    raw.length(),
    pattern.length(),
    2,
    32,
    max_output_chars,
  )
  let value = @string.parse_double(raw) catch { _ => return raw }
  let parts = if use_1904_format {
    excel_serial_to_parts_1904(value)
  } else {
    excel_serial_to_parts(value)
  }
  match parts {
    None => raw
    Some((year, month, day, hour, minute, second)) =>
      format_date_pattern(
        pattern, year, month, day, hour, minute, second, value,
      )
  }
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
fn weekday_index(year : Int, month : Int, day : Int) -> Int {
  if year == 1900 && month == 2 && day == 29 {
    return 4
  }
  let mut y = year
  let mut m = month
  if m < 3 {
    m = m + 12
    y = y - 1
  }
  let k = y % 100
  let j = y / 100
  let h = (day + 13 * (m + 1) / 5 + k + k / 4 + j / 4 + 5 * j) % 7
  match h {
    0 => 6
    1 => 0
    2 => 1
    3 => 2
    4 => 3
    5 => 4
    _ => 5
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
  serial_value : Double,
) -> String {
  format_date_pattern_tokens(
    pattern, year, month, day, hour, minute, second, serial_value,
  )
}

///|
priv enum DateToken {
  Literal(String)
  Year(Int)
  Month(Int)
  Day(Int)
  Hour(Int)
  Second(Int)
  AmPm(Bool)
  Ap(Bool)
  ElapsedHour(Int)
  ElapsedMinute(Int)
  ElapsedSecond(Int)
}

///|
fn tokenize_date_pattern(pattern : String) -> Array[DateToken] {
  let tokens : Array[DateToken] = []
  let mut sb = StringBuilder::new()
  let mut has_literal = false
  let mut in_quote = false
  let mut escape_next = false
  let len = pattern.length()
  let lower = pattern.to_lower()
  let mut i = 0
  while i < len {
    if escape_next {
      sb.write_view(pattern[i:i + 1])
      has_literal = true
      escape_next = false
      i = i + 1
      continue
    }
    let c = pattern[i]
    match c {
      '\\' => escape_next = true
      '"' => in_quote = !in_quote
      '[' =>
        if !in_quote {
          let mut j = i + 1
          while j < len && pattern[j] != ']' {
            j = j + 1
          }
          if j < len {
            let content = lower[i + 1:j]
            if has_literal {
              tokens.push(Literal(sb.to_string()))
              sb = StringBuilder::new()
              has_literal = false
            }
            match content {
              "h" | "hh" => tokens.push(ElapsedHour(content.length()))
              "m" | "mm" => tokens.push(ElapsedMinute(content.length()))
              "s" | "ss" => tokens.push(ElapsedSecond(content.length()))
              _ => ()
            }
            i = j
          }
        } else {
          sb.write_char('[')
          has_literal = true
        }
      _ =>
        if !in_quote {
          let maybe_ampm = if i + 4 < len {
            lower[i:i + 5].to_owned()
          } else {
            ""
          }
          if maybe_ampm == "am/pm" {
            if has_literal {
              tokens.push(Literal(sb.to_string()))
              sb = StringBuilder::new()
              has_literal = false
            }
            let raw = pattern[i:i + 5].to_owned()
            let upper = raw.contains("A") || raw.contains("P")
            tokens.push(AmPm(upper))
            i = i + 5
            continue
          }
          let maybe_ap = if i + 2 < len {
            lower[i:i + 3].to_owned()
          } else {
            ""
          }
          if maybe_ap == "a/p" {
            if has_literal {
              tokens.push(Literal(sb.to_string()))
              sb = StringBuilder::new()
              has_literal = false
            }
            let raw = pattern[i:i + 3].to_owned()
            let upper = raw.contains("A") || raw.contains("P")
            tokens.push(Ap(upper))
            i = i + 3
            continue
          }
          if c == 'y' ||
            c == 'Y' ||
            c == 'm' ||
            c == 'M' ||
            c == 'd' ||
            c == 'D' ||
            c == 'h' ||
            c == 'H' ||
            c == 's' ||
            c == 'S' {
            if has_literal {
              tokens.push(Literal(sb.to_string()))
              sb = StringBuilder::new()
              has_literal = false
            }
            let mut j = i
            while j < len && lower[j] == lower[i] {
              j = j + 1
            }
            let count = j - i
            let kind = match lower[i] {
              'y' => Year(count)
              'm' => Month(count)
              'd' => Day(count)
              'h' => Hour(count)
              's' => Second(count)
              _ => Literal(pattern[i:j].to_owned())
            }
            tokens.push(kind)
            i = j
            continue
          }
          sb.write_view(pattern[i:i + 1])
          has_literal = true
        } else {
          sb.write_view(pattern[i:i + 1])
          has_literal = true
        }
    }
    i = i + 1
  }
  if has_literal {
    tokens.push(Literal(sb.to_string()))
  }
  tokens
}

///|
fn format_date_pattern_tokens(
  pattern : String,
  year : Int,
  month : Int,
  day : Int,
  hour : Int,
  minute : Int,
  second : Int,
  serial_value : Double,
) -> String {
  let tokens = tokenize_date_pattern(pattern)
  let mut use_ampm = false
  for token in tokens {
    match token {
      AmPm(_) | Ap(_) => {
        use_ampm = true
        break
      }
      _ => ()
    }
  }
  let weekday = weekday_index(year, month, day)
  let total_seconds = Double::to_int64(Double::round(serial_value * 86400.0))
  let elapsed_hours = total_seconds / 3600L
  let elapsed_minutes = total_seconds / 60L
  let elapsed_seconds = total_seconds
  let output = StringBuilder::new()
  for idx, token in tokens {
    match token {
      Literal(text) => output.write_view(text)
      Year(count) =>
        if count == 2 {
          output.write_view(pad_left_int(year % 100, 2))
        } else if count >= 4 {
          output.write_view(pad_left_int(year, 4))
        } else {
          output.write_view(year.to_string())
        }
      Month(count) => {
        let mut treat_as_minute = false
        if count <= 2 {
          let mut prev_idx = idx - 1
          while prev_idx >= 0 {
            match tokens[prev_idx] {
              Literal(_) => prev_idx = prev_idx - 1
              Hour(_) | ElapsedHour(_) => {
                treat_as_minute = true
                break
              }
              _ => break
            }
          }
          let mut next_idx = idx + 1
          while next_idx < tokens.length() {
            match tokens[next_idx] {
              Literal(_) => next_idx = next_idx + 1
              Second(_) | ElapsedSecond(_) => {
                treat_as_minute = true
                break
              }
              _ => break
            }
          }
        }
        if treat_as_minute {
          if count >= 2 {
            output.write_view(pad_left_int(minute, 2))
          } else {
            output.write_view(minute.to_string())
          }
        } else if count >= 6 {
          output.write_view(month_long_name(month))
        } else if count == 5 {
          output.write_view(month_initial_name(month))
        } else if count == 4 {
          output.write_view(month_long_name(month))
        } else if count == 3 {
          output.write_view(month_short_name(month))
        } else if count == 2 {
          output.write_view(pad_left_int(month, 2))
        } else {
          output.write_view(month.to_string())
        }
      }
      Day(count) =>
        if count >= 4 {
          output.write_view(weekday_long_name(weekday))
        } else if count == 3 {
          output.write_view(weekday_short_name(weekday))
        } else if count == 2 {
          output.write_view(pad_left_int(day, 2))
        } else {
          output.write_view(day.to_string())
        }
      Hour(count) => {
        let hour_value = if use_ampm { hour12(hour) } else { hour }
        if count >= 2 {
          output.write_view(pad_left_int(hour_value, 2))
        } else {
          output.write_view(hour_value.to_string())
        }
      }
      Second(count) =>
        if count >= 2 {
          output.write_view(pad_left_int(second, 2))
        } else {
          output.write_view(second.to_string())
        }
      AmPm(upper) =>
        if upper {
          output.write_view(if hour >= 12 { "PM" } else { "AM" })
        } else {
          output.write_view(if hour >= 12 { "pm" } else { "am" })
        }
      Ap(upper) =>
        if upper {
          output.write_view(if hour >= 12 { "P" } else { "A" })
        } else {
          output.write_view(if hour >= 12 { "p" } else { "a" })
        }
      ElapsedHour(count) =>
        if count >= 2 {
          output.write_view(pad_left_int64(elapsed_hours, 2))
        } else {
          output.write_view(elapsed_hours.to_string())
        }
      ElapsedMinute(count) =>
        if count >= 2 {
          output.write_view(pad_left_int64(elapsed_minutes, 2))
        } else {
          output.write_view(elapsed_minutes.to_string())
        }
      ElapsedSecond(count) =>
        if count >= 2 {
          output.write_view(pad_left_int64(elapsed_seconds, 2))
        } else {
          output.write_view(elapsed_seconds.to_string())
        }
    }
  }
  output.to_string()
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
fn month_initial_name(month : Int) -> String {
  let name = month_short_name(month)
  if name.length() == 0 {
    ""
  } else {
    name[:1].to_owned()
  }
}

///|
fn weekday_short_name(index : Int) -> String {
  match index {
    0 => "Sun"
    1 => "Mon"
    2 => "Tue"
    3 => "Wed"
    4 => "Thu"
    5 => "Fri"
    6 => "Sat"
    _ => ""
  }
}

///|
fn weekday_long_name(index : Int) -> String {
  match index {
    0 => "Sunday"
    1 => "Monday"
    2 => "Tuesday"
    3 => "Wednesday"
    4 => "Thursday"
    5 => "Friday"
    6 => "Saturday"
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
