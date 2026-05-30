///|
fn pdf_writer_exponent_marker(text : BytesView) -> Int {
  for i in 0..<text.length() {
    let value = text[i].to_int()
    if value == 69 || value == 101 {
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
  let mut index = start
  let mut sign = 1
  if index < text.length() {
    match text[index].to_int() {
      43 => index += 1
      45 => {
        sign = -1
        index += 1
      }
      _ => ()
    }
  }
  if index >= text.length() {
    raise NumberExpected
  }
  let mut value = 0
  while index < text.length() {
    let digit = text[index].to_int()
    if !@core.pdf_is_digit_byte(digit) {
      raise NumberExpected
    }
    value = value * 10 + digit - 48
    index += 1
  }
  sign * value
}

///|
fn pdf_writer_push_digits(
  output : Array[Byte],
  digits : Array[Byte],
  start : Int,
  end : Int,
) -> Unit {
  for i in start..<end {
    output.push(digits[i])
  }
}

///|
fn pdf_writer_push_rounded_significant_digits(
  output : Array[Byte],
  digits : Array[Byte],
  decimal_position : Int,
) -> Unit {
  let significant_start = for i in 0..<digits.length() {
    if digits[i].to_int() != 48 {
      break i
    }
  } nobreak {
    -1
  }
  if significant_start < 0 {
    pdf_writer_push_byte(output, 48)
  } else {
    let keep_end = significant_start + 12
    let copy_end = if keep_end < digits.length() {
      keep_end
    } else {
      digits.length()
    }
    let rounded : Array[Byte] = []
    for i in significant_start..<copy_end {
      rounded.push(digits[i])
    }
    let mut adjusted_decimal_position = decimal_position - significant_start
    if keep_end < digits.length() && digits[keep_end].to_int() >= 53 {
      let mut carry = true
      let mut carry_index = rounded.length() - 1
      while carry && carry_index >= 0 {
        let next = rounded[carry_index].to_int() - 48 + 1
        if next == 10 {
          rounded[carry_index] = 48
          carry_index -= 1
        } else {
          rounded[carry_index] = (48 + next).to_byte()
          carry = false
        }
      }
      if carry {
        rounded.insert(0, 49)
        adjusted_decimal_position += 1
      }
    }
    let mut end = rounded.length()
    while end > adjusted_decimal_position &&
          end > 0 &&
          rounded[end - 1].to_int() == 48 {
      end -= 1
    }
    if adjusted_decimal_position <= 0 {
      pdf_writer_push_ascii(output, "0.")
      for _ in 0..<-adjusted_decimal_position {
        pdf_writer_push_byte(output, 48)
      }
      pdf_writer_push_digits(output, rounded, 0, end)
    } else if adjusted_decimal_position >= end {
      pdf_writer_push_digits(output, rounded, 0, end)
      for _ in 0..<(adjusted_decimal_position - end) {
        pdf_writer_push_byte(output, 48)
      }
    } else {
      pdf_writer_push_digits(output, rounded, 0, adjusted_decimal_position)
      pdf_writer_push_byte(output, 46)
      pdf_writer_push_digits(output, rounded, adjusted_decimal_position, end)
    }
  }
}

///|
fn pdf_writer_push_int_digits(
  output : Array[Byte],
  digits : ArrayView[Int],
  start : Int,
  end : Int,
) -> Unit {
  for i in start..<end {
    pdf_writer_push_byte(output, 48 + digits[i])
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
    match text[0].to_int() {
      43 => mantissa_start = 1
      45 => {
        pdf_writer_push_byte(output, 45)
        mantissa_start = 1
      }
      _ => ()
    }
  }
  let exponent = pdf_writer_parse_signed_int(text, exponent_at + 1)
  let digits : Array[Byte] = []
  let mut fractional_digits = 0
  let mut seen_decimal = false
  for i in mantissa_start..<exponent_at {
    let value = text[i].to_int()
    if value == 46 {
      seen_decimal = true
    } else if @core.pdf_is_digit_byte(value) {
      digits.push(text[i])
      if seen_decimal {
        fractional_digits += 1
      }
    } else {
      raise NumberExpected
    }
  }
  if digits.length() == 0 {
    pdf_writer_push_byte(output, 48)
  } else {
    let decimal_position = digits.length() + exponent - fractional_digits
    pdf_writer_push_rounded_significant_digits(output, digits, decimal_position)
  }
}

///|
fn pdf_writer_push_plain_significant_real(
  output : Array[Byte],
  text : BytesView,
) -> Unit raise @core.PdfError {
  let mut index = 0
  let mut negative = false
  if text.length() > 0 {
    match text[0].to_int() {
      43 => index = 1
      45 => {
        negative = true
        index = 1
      }
      _ => ()
    }
  }
  let digits : Array[Int] = []
  let mut decimal_position = -1
  while index < text.length() {
    let value = text[index].to_int()
    if value == 46 {
      if decimal_position >= 0 {
        raise NumberExpected
      }
      decimal_position = digits.length()
    } else if @core.pdf_is_digit_byte(value) {
      digits.push(value - 48)
    } else {
      raise NumberExpected
    }
    index += 1
  }
  if decimal_position < 0 {
    pdf_writer_push_view(output, text)
  } else {
    let significant_start = for i in 0..<digits.length() {
      if digits[i] != 0 {
        break i
      }
    } nobreak {
      -1
    }
    if significant_start < 0 {
      pdf_writer_push_byte(output, 48)
    } else {
      let keep_end = significant_start + 12
      let copy_end = if keep_end < digits.length() {
        keep_end
      } else {
        digits.length()
      }
      let mut rounded : Array[Int] = []
      for i in 0..<copy_end {
        rounded.push(digits[i])
      }
      if keep_end < digits.length() && digits[keep_end] >= 5 {
        let mut carry = true
        let mut carry_index = rounded.length() - 1
        while carry && carry_index >= 0 {
          let next = rounded[carry_index] + 1
          if next == 10 {
            rounded[carry_index] = 0
            carry_index -= 1
          } else {
            rounded[carry_index] = next
            carry = false
          }
        }
        if carry {
          let with_carry : Array[Int] = [1]
          with_carry.append(rounded)
          rounded = with_carry
          decimal_position += 1
        }
      }
      let mut end = rounded.length()
      while end > decimal_position && end > 0 && rounded[end - 1] == 0 {
        end -= 1
      }
      if negative {
        pdf_writer_push_byte(output, 45)
      }
      if decimal_position <= 0 {
        pdf_writer_push_ascii(output, "0.")
        pdf_writer_push_int_digits(output, rounded, 0, end)
      } else if decimal_position >= end {
        pdf_writer_push_int_digits(output, rounded, 0, end)
      } else {
        pdf_writer_push_int_digits(output, rounded, 0, decimal_position)
        pdf_writer_push_byte(output, 46)
        pdf_writer_push_int_digits(output, rounded, decimal_position, end)
      }
    }
  }
}

///|
fn pdf_writer_push_fixed_six_real(output : Array[Byte], value : Double) -> Unit {
  if value < 0.0 {
    pdf_writer_push_byte(output, 45)
  }
  pdf_writer_push_ascii(output, "0.")
  let magnitude = if value < 0.0 { -value } else { value }
  let scaled = (magnitude * 1000000.0).round().to_int()
  let mut divisor = 100000
  while divisor > 0 {
    pdf_writer_push_byte(output, 48 + scaled / divisor % 10)
    divisor /= 10
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
