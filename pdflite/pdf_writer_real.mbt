///|
fn pdf_writer_exponent_marker(text : BytesView) -> Int {
  for i in 0..<text.length() {
    if text[i] is (b'E' | b'e') {
      break i
    }
  } nobreak {
    -1
  }
}

///|
fn pdf_writer_parse_signed_int(
  text : BytesView,
  start : Int,
) -> Int raise @core.PdfError {
  let digit_start = match text.get(start) {
    Some(b'+') | Some(b'-') => start + 1
    _ => start
  }
  guard digit_start < text.length() else { raise NumberExpected }
  let mut value = 0
  for index in digit_start..<text.length() {
    guard text[index] is (b'0'..=b'9') else { raise NumberExpected }
    value = value * 10 + (text[index].to_int() - '0')
  }
  if text[start] is b'-' {
    -value
  } else {
    value
  }
}

///|
/// Number of significant digits kept when rounding a real for output.
const PDF_WRITER_SIGNIFICANT_DIGITS : Int = 12

///|
/// Emit decimal digit values with the decimal point logically placed after
/// `decimal_position` digits: drop leading zeros, round to the
/// significant-digit budget (half-up with carry), trim trailing fractional
/// zeros, then render as `0.00ddd`, `ddd00`, or `dd.dd` depending on where
/// the point falls. All-zero input renders as a bare `0`.
///
/// The `ddd00` magnitude padding applies to both call paths. The previous
/// plain-path copy emitted only the retained significant digits, so reals
/// with more than the budget's integer digits lost a factor of ten
/// (1234567890123.5 -> "123456789012"); this is a deliberate fix, pinned by
/// the wide-real regression test.
fn pdf_writer_push_significant_digits(
  output : Array[Byte],
  digits : Array[Int],
  decimal_position : Int,
) -> Unit {
  let significant_start = for i in 0..<digits.length() {
    if digits[i] != 0 {
      break i
    }
  } nobreak {
    -1
  }
  guard significant_start >= 0 else {
    pdf_writer_push_byte(output, '0')
    return
  }
  let keep_end = significant_start + PDF_WRITER_SIGNIFICANT_DIGITS
  let copy_end = if keep_end < digits.length() {
    keep_end
  } else {
    digits.length()
  }
  let rounded = digits[significant_start:copy_end].to_owned()
  let mut adjusted_decimal_position = decimal_position - significant_start
  if keep_end < digits.length() && digits[keep_end] >= 5 {
    let carried = for carry_index = rounded.length() - 1; carry_index >= 0; {
      if rounded[carry_index] == 9 {
        rounded[carry_index] = 0
        continue carry_index - 1
      }
      rounded[carry_index] += 1
      break true
    } nobreak {
      false
    }
    if !carried {
      rounded.insert(0, 1)
      adjusted_decimal_position += 1
    }
  }
  let end = for end = rounded.length(); end > adjusted_decimal_position &&
               end > 0 &&
               rounded[end - 1] == 0; {
    continue end - 1
  } nobreak {
    end
  }
  if adjusted_decimal_position <= 0 {
    pdf_writer_push_ascii(output, "0.")
    for _ in 0..<-adjusted_decimal_position {
      pdf_writer_push_byte(output, '0')
    }
    pdf_writer_push_digit_values(output, rounded, 0, end)
  } else if adjusted_decimal_position >= end {
    pdf_writer_push_digit_values(output, rounded, 0, end)
    for _ in 0..<(adjusted_decimal_position - end) {
      pdf_writer_push_byte(output, '0')
    }
  } else {
    pdf_writer_push_digit_values(output, rounded, 0, adjusted_decimal_position)
    pdf_writer_push_byte(output, '.')
    pdf_writer_push_digit_values(
      output, rounded, adjusted_decimal_position, end,
    )
  }
}

///|
fn pdf_writer_push_digit_values(
  output : Array[Byte],
  digits : ArrayView[Int],
  start : Int,
  end : Int,
) -> Unit {
  for i in start..<end {
    pdf_writer_push_byte(output, '0' + digits[i])
  }
}

///|
fn pdf_writer_push_scientific_real(
  output : Array[Byte],
  text : BytesView,
  exponent_at : Int,
) -> Unit raise @core.PdfError {
  let mut mantissa_start = 0
  if exponent_at > 0 {
    match text[0] {
      b'+' => mantissa_start = 1
      b'-' => {
        pdf_writer_push_byte(output, '-')
        mantissa_start = 1
      }
      _ => ()
    }
  }
  let exponent = pdf_writer_parse_signed_int(text, exponent_at + 1)
  let digits : Array[Int] = []
  let mut fractional_digits = 0
  let mut seen_decimal = false
  for i in mantissa_start..<exponent_at {
    match text[i] {
      b'.' => seen_decimal = true
      b'0'..=b'9' => {
        digits.push(text[i].to_int() - '0')
        if seen_decimal {
          fractional_digits += 1
        }
      }
      _ => raise NumberExpected
    }
  }
  if digits is [] {
    pdf_writer_push_byte(output, '0')
  } else {
    let decimal_position = digits.length() + exponent - fractional_digits
    pdf_writer_push_significant_digits(output, digits, decimal_position)
  }
}

///|
fn pdf_writer_push_plain_significant_real(
  output : Array[Byte],
  text : BytesView,
) -> Unit raise @core.PdfError {
  let (start, negative) = match text.get(0) {
    Some(b'+') => (1, false)
    Some(b'-') => (1, true)
    _ => (0, false)
  }
  let digits : Array[Int] = []
  let mut decimal_position = -1
  for index in start..<text.length() {
    match text[index] {
      b'.' => {
        guard decimal_position < 0 else { raise NumberExpected }
        decimal_position = digits.length()
      }
      b'0'..=b'9' => digits.push(text[index].to_int() - '0')
      _ => raise NumberExpected
    }
  }
  guard decimal_position >= 0 else {
    pdf_writer_push_view(output, text)
    return
  }
  // the sign is emitted only when a significant digit exists, matching the
  // previous behavior where -0.000 rendered as a bare 0
  if negative && digits.iter().any(digit => digit != 0) {
    pdf_writer_push_byte(output, '-')
  }
  pdf_writer_push_significant_digits(output, digits, decimal_position)
}

///|
fn pdf_writer_push_fixed_six_real(output : Array[Byte], value : Double) -> Unit {
  if value < 0.0 {
    pdf_writer_push_byte(output, '-')
  }
  pdf_writer_push_ascii(output, "0.")
  let magnitude = if value < 0.0 { -value } else { value }
  let scaled = (magnitude * 1000000.0).round().to_int()
  for divisor = 100000; divisor > 0; {
    pdf_writer_push_byte(output, '0' + scaled / divisor % 10)
    continue divisor / 10
  }
}

///|
fn pdf_writer_push_real(
  output : Array[Byte],
  value : Double,
) -> Unit raise @core.PdfError {
  if value.trunc() != value && value < 0.0001 && value > -0.0001 {
    pdf_writer_push_fixed_six_real(output, value)
  } else {
    let text = @ascii.encode(value.to_string())
    match pdf_writer_exponent_marker(text) {
      -1 => pdf_writer_push_plain_significant_real(output, text)
      exponent_at => pdf_writer_push_scientific_real(output, text, exponent_at)
    }
  }
}

///|
/// Format a PDF real number as bytes.
///
/// Scientific notation is expanded to PDF-compatible decimal form where
/// possible. Non-finite or unparsable numeric text raises `@core.PdfError`.
pub fn pdf_write_real(value : Double) -> @core.PdfBytes raise @core.PdfError {
  let output : Array[Byte] = []
  pdf_writer_push_real(output, value)
  Bytes::from_array(output)
}

///|
/// Compatibility alias for `pdf_write_real`.
pub fn pdf_format_real(value : Double) -> @core.PdfBytes raise @core.PdfError {
  pdf_write_real(value)
}
