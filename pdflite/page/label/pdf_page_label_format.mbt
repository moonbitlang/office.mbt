///|
fn pdf_page_label_copy_bytes(
  output : Array[Byte],
  position : Int,
  bytes : PdfBytes,
) -> Int {
  let mut position = position
  for byte in bytes {
    output[position] = byte
    position += 1
  }
  position
}

///|
fn pdf_page_label_ascii_bytes(text : String) -> PdfBytes {
  @ascii.encode(text)
}

///|
fn pdf_page_label_roman_pair(pair_index : Int) -> (Int, Byte, Byte?) {
  match pair_index {
    0 => (900, b'C', Some(b'M'))
    1 => (500, b'D', None)
    2 => (400, b'C', Some(b'D'))
    3 | 4 | 5 => (100, b'C', None)
    6 => (90, b'X', Some(b'C'))
    7 => (50, b'L', None)
    8 => (40, b'X', Some(b'L'))
    9 | 10 | 11 => (10, b'X', None)
    12 => (9, b'I', Some(b'X'))
    13 => (5, b'V', None)
    14 => (4, b'I', Some(b'V'))
    _ => (1, b'I', None)
  }
}

///|
fn pdf_page_label_roman_pair_length(pair_index : Int) -> Int {
  let (_, _, suffix) = pdf_page_label_roman_pair(pair_index)
  match suffix {
    Some(_) => 2
    None => 1
  }
}

///|
fn pdf_page_label_copy_roman_pair(
  output : Array[Byte],
  position : Int,
  pair_index : Int,
) -> Int {
  let (_, prefix, suffix) = pdf_page_label_roman_pair(pair_index)
  output[position] = prefix
  match suffix {
    Some(byte) => {
      output[position + 1] = byte
      position + 2
    }
    None => position + 1
  }
}

///|
fn pdf_page_label_roman_upper_length(number : Int) -> Int {
  let mut length = 0
  let mut remaining = number
  if remaining >= 1000 {
    length += remaining / 1000
    remaining = remaining % 1000
  }
  if remaining > 0 {
    let mut pair_index = 0
    while pair_index < 18 {
      let (value, _, _) = pdf_page_label_roman_pair(pair_index)
      if remaining >= value {
        length += pdf_page_label_roman_pair_length(pair_index)
        remaining -= value
      } else {
        pair_index += 1
      }
    }
  }
  length
}

///|
/// Format a positive integer as uppercase Roman numeral bytes.
///
/// Values less than or equal to zero produce an empty byte string, matching
/// cpdf's page-label formatter behavior.
pub fn pdf_page_label_roman_upper(number : Int) -> PdfBytes {
  let output = Array::make(pdf_page_label_roman_upper_length(number), b'\x00')
  let mut position = 0
  let mut remaining = number
  if remaining >= 1000 {
    for _ in 0..<(remaining / 1000) {
      output[position] = b'M'
      position += 1
    }
    remaining = remaining % 1000
  }
  if remaining > 0 {
    let mut pair_index = 0
    while pair_index < 18 {
      let (value, _, _) = pdf_page_label_roman_pair(pair_index)
      if remaining >= value {
        position = pdf_page_label_copy_roman_pair(output, position, pair_index)
        remaining -= value
      } else {
        pair_index += 1
      }
    }
  }
  Bytes::from_array(output)
}

///|
/// Lowercase ASCII A-Z bytes and preserve all other bytes unchanged.
pub fn pdf_page_label_lowercase(bytes : PdfBytes) -> PdfBytes {
  let output = Array::make(bytes.length(), b'\x00')
  for i in 0..<bytes.length() {
    let byte = bytes[i]
    let value = byte.to_int()
    if value >= 65 && value <= 90 {
      output[i] = (value + 32).to_byte()
    } else {
      output[i] = byte
    }
  }
  Bytes::from_array(output)
}

///|
fn pdf_page_label_letters(number : Int, lowercase : Bool) -> PdfBytes {
  if number > 0 {
    let letter = (number - 1) % 26
    let count = (number - 1) / 26 + 1
    let base = if lowercase { 97 } else { 65 }
    let output = Array::make(count, (base + letter).to_byte())
    Bytes::from_array(output)
  } else {
    []
  }
}

///|
/// Format the numeric suffix for a page label style.
///
/// Prefix-only labels return an empty byte string.
pub fn pdf_page_label_number_bytes(
  number : Int,
  style : PdfPageLabelStyle,
) -> PdfBytes {
  match style {
    PageLabelNoLabelPrefixOnly => []
    PageLabelDecimalArabic => pdf_page_label_ascii_bytes(number.to_string())
    PageLabelUppercaseRoman => pdf_page_label_roman_upper(number)
    PageLabelLowercaseRoman =>
      pdf_page_label_lowercase(pdf_page_label_roman_upper(number))
    PageLabelUppercaseLetters => pdf_page_label_letters(number, false)
    PageLabelLowercaseLetters => pdf_page_label_letters(number, true)
  }
}

///|
/// Render the visible label text for one page within a label range.
///
/// The optional prefix bytes are copied first. The numeric suffix is calculated
/// from the range's 1-based `start_page` and `start_value`, then formatted with
/// the range style.
pub fn pdf_page_label_text_of_single(
  page_number : Int,
  label : PdfPageLabel,
) -> PdfBytes {
  let real_number = page_number - (label.start_page - label.start_value)
  let number_bytes = pdf_page_label_number_bytes(real_number, label.label_style)
  let prefix_length = match label.label_prefix {
    Some(prefix) => prefix.length()
    None => 0
  }
  let output = Array::make(prefix_length + number_bytes.length(), b'\x00')
  let mut position = 0
  match label.label_prefix {
    Some(prefix) =>
      for byte in prefix {
        output[position] = byte
        position += 1
      }
    None => ()
  }
  for byte in number_bytes {
    output[position] = byte
    position += 1
  }
  Bytes::from_array(output)
}

///|
/// Return the effective page-label range for one concrete page.
///
/// The returned range keeps the style and prefix, but normalizes `start_page`
/// and `start_value` to the numeric value displayed on `page_number`.
pub fn pdf_page_label_of_single(
  page_number : Int,
  label : PdfPageLabel,
) -> PdfPageLabel {
  let real_number = page_number - (label.start_page - label.start_value)
  { ..label, start_page: real_number, start_value: real_number }
}

///|
/// Find the active page-label range for a 1-based page number.
///
/// The input ranges are expected in document order. Returns `None` when the
/// document has no page-label ranges.
pub fn pdf_page_label_of_page_number(
  page_number : Int,
  labels : ArrayView[PdfPageLabel],
) -> PdfPageLabel? {
  if labels.length() == 0 {
    None
  } else {
    let mut label = labels[0]
    for index in 1..<labels.length() {
      if page_number < labels[index].start_page {
        break
      } else {
        label = labels[index]
      }
    }
    Some(pdf_page_label_of_single(page_number, label))
  }
}

///|
/// Render the visible label text for a 1-based page number.
///
/// Returns `None` when there are no label ranges. Label prefixes are returned as
/// raw PDF bytes, preserving the encoding stored in the PDF string.
pub fn pdf_page_label_text_of_page_number(
  page_number : Int,
  labels : ArrayView[PdfPageLabel],
) -> PdfBytes? {
  if labels.length() == 0 {
    None
  } else {
    let mut label = labels[0]
    for index in 1..<labels.length() {
      if page_number < labels[index].start_page {
        break
      } else {
        label = labels[index]
      }
    }
    Some(pdf_page_label_text_of_single(page_number, label))
  }
}
