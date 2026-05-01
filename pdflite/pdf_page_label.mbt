///|
fn pdf_page_label_name(text : String) -> PdfName {
  pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn pdf_page_label_root_key() -> PdfName {
  pdf_page_label_name("/Root")
}

///|
fn pdf_page_label_page_labels_key() -> PdfName {
  pdf_page_label_name("/PageLabels")
}

///|
fn pdf_page_label_style_key() -> PdfName {
  pdf_page_label_name("/S")
}

///|
fn pdf_page_label_prefix_key() -> PdfName {
  pdf_page_label_name("/P")
}

///|
fn pdf_page_label_start_value_key() -> PdfName {
  pdf_page_label_name("/St")
}

///|
fn pdf_page_label_style_decimal_name() -> PdfName {
  pdf_page_label_name("/D")
}

///|
fn pdf_page_label_style_upper_roman_name() -> PdfName {
  pdf_page_label_name("/R")
}

///|
fn pdf_page_label_style_lower_roman_name() -> PdfName {
  pdf_page_label_name("/r")
}

///|
fn pdf_page_label_style_upper_letters_name() -> PdfName {
  pdf_page_label_name("/A")
}

///|
fn pdf_page_label_style_lower_letters_name() -> PdfName {
  pdf_page_label_name("/a")
}

///|
pub(all) enum PdfPageLabelStyle {
  PageLabelDecimalArabic
  PageLabelUppercaseRoman
  PageLabelLowercaseRoman
  PageLabelUppercaseLetters
  PageLabelLowercaseLetters
  PageLabelNoLabelPrefixOnly
} derive(Debug, Eq, ToJson)

///|
pub(all) struct PdfPageLabel {
  label_style : PdfPageLabelStyle
  label_prefix : PdfBytes?
  start_page : Int
  start_value : Int
} derive(Debug, Eq, ToJson)

///|
pub let pdf_page_label_basic : PdfPageLabel = {
  label_style: PageLabelDecimalArabic,
  label_prefix: None,
  start_page: 1,
  start_value: 1,
}

///|
pub fn pdf_page_label_complete(
  labels : ArrayView[PdfPageLabel],
) -> Array[PdfPageLabel] {
  if labels.length() == 0 {
    [pdf_page_label_basic]
  } else if labels[0].start_page > 1 {
    let output : Array[PdfPageLabel] = [pdf_page_label_basic]
    for label in labels {
      output.push(label)
    }
    output
  } else {
    [
      for label in labels => label
    ]
  }
}

///|
fn pdf_page_label_push_bytes(output : Array[Byte], bytes : PdfBytes) -> Unit {
  for byte in bytes {
    output.push(byte)
  }
}

///|
fn pdf_page_label_ascii_bytes(text : String) -> PdfBytes {
  @ascii.encode(text)
}

///|
fn pdf_page_label_roman_pair(value : Int) -> (Int, String) {
  match value {
    0 => (900, "CM")
    1 => (500, "D")
    2 => (400, "CD")
    3 | 4 | 5 => (100, "C")
    6 => (90, "XC")
    7 => (50, "L")
    8 => (40, "XL")
    9 | 10 | 11 => (10, "X")
    12 => (9, "IX")
    13 => (5, "V")
    14 => (4, "IV")
    _ => (1, "I")
  }
}

///|
fn pdf_page_label_roman_upper(number : Int) -> PdfBytes {
  let output : Array[Byte] = []
  let mut remaining = number
  if remaining >= 1000 {
    for _ in 0..<(remaining / 1000) {
      pdf_page_label_push_bytes(output, pdf_page_label_ascii_bytes("M"))
    }
    remaining = remaining % 1000
  }
  if remaining > 0 {
    let mut pair_index = 0
    while pair_index < 18 {
      let (value, text) = pdf_page_label_roman_pair(pair_index)
      if remaining >= value {
        pdf_page_label_push_bytes(output, pdf_page_label_ascii_bytes(text))
        remaining -= value
      } else {
        pair_index += 1
      }
    }
  }
  Bytes::from_array(output)
}

///|
fn pdf_page_label_lowercase(bytes : PdfBytes) -> PdfBytes {
  let output : Array[Byte] = []
  for byte in bytes {
    let value = byte.to_int()
    if value >= 65 && value <= 90 {
      output.push((value + 32).to_byte())
    } else {
      output.push(byte)
    }
  }
  Bytes::from_array(output)
}

///|
fn pdf_page_label_letters(number : Int, lowercase : Bool) -> PdfBytes {
  let output : Array[Byte] = []
  if number > 0 {
    let letter = (number - 1) % 26
    let count = (number - 1) / 26 + 1
    let base = if lowercase { 97 } else { 65 }
    for _ in 0..<count {
      output.push((base + letter).to_byte())
    }
  }
  Bytes::from_array(output)
}

///|
fn pdf_page_label_number_bytes(
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
pub fn pdf_page_label_text_of_single(
  page_number : Int,
  label : PdfPageLabel,
) -> PdfBytes {
  let real_number = page_number - (label.start_page - label.start_value)
  let output : Array[Byte] = []
  match label.label_prefix {
    Some(prefix) => pdf_page_label_push_bytes(output, prefix)
    None => ()
  }
  pdf_page_label_push_bytes(
    output,
    pdf_page_label_number_bytes(real_number, label.label_style),
  )
  Bytes::from_array(output)
}

///|
pub fn pdf_page_label_of_single(
  page_number : Int,
  label : PdfPageLabel,
) -> PdfPageLabel {
  let real_number = page_number - (label.start_page - label.start_value)
  { ..label, start_page: real_number, start_value: real_number }
}

///|
pub fn pdf_page_label_of_page_number(
  page_number : Int,
  labels : ArrayView[PdfPageLabel],
) -> PdfPageLabel? {
  if labels.length() == 0 {
    None
  } else {
    for index in 0..<labels.length() {
      if index + 1 == labels.length() ||
        page_number < labels[index + 1].start_page {
        break Some(pdf_page_label_of_single(page_number, labels[index]))
      }
    } nobreak {
      None
    }
  }
}

///|
pub fn pdf_page_label_text_of_page_number(
  page_number : Int,
  labels : ArrayView[PdfPageLabel],
) -> PdfBytes? {
  if labels.length() == 0 {
    None
  } else {
    for index in 0..<labels.length() {
      if index + 1 == labels.length() ||
        page_number < labels[index + 1].start_page {
        break Some(pdf_page_label_text_of_single(page_number, labels[index]))
      }
    } nobreak {
      None
    }
  }
}

///|
pub fn pdf_page_label_coalesce(
  labels : ArrayView[PdfPageLabel],
) -> Array[PdfPageLabel] {
  let output : Array[PdfPageLabel] = []
  let mut index = 0
  while index < labels.length() {
    let label = labels[index]
    output.push(label)
    index += 1
    while index < labels.length() &&
          labels[index].label_style == label.label_style &&
          labels[index].label_prefix == label.label_prefix &&
          labels[index].start_page - labels[index].start_value ==
          label.start_page - label.start_value {
      index += 1
    }
  }
  output
}

///|
fn pdf_page_label_style_of_object(object : PdfObject?) -> PdfPageLabelStyle {
  match object {
    Some(PdfNameObject(name)) if name == pdf_page_label_style_decimal_name() =>
      PageLabelDecimalArabic
    Some(PdfNameObject(name)) if name == pdf_page_label_style_upper_roman_name() =>
      PageLabelUppercaseRoman
    Some(PdfNameObject(name)) if name == pdf_page_label_style_lower_roman_name() =>
      PageLabelLowercaseRoman
    Some(PdfNameObject(name)) if name ==
      pdf_page_label_style_upper_letters_name() => PageLabelUppercaseLetters
    Some(PdfNameObject(name)) if name ==
      pdf_page_label_style_lower_letters_name() => PageLabelLowercaseLetters
    _ => PageLabelNoLabelPrefixOnly
  }
}

///|
fn pdf_page_label_style_object(style : PdfPageLabelStyle) -> PdfObject? {
  match style {
    PageLabelDecimalArabic =>
      Some(PdfNameObject(pdf_page_label_style_decimal_name()))
    PageLabelUppercaseRoman =>
      Some(PdfNameObject(pdf_page_label_style_upper_roman_name()))
    PageLabelLowercaseRoman =>
      Some(PdfNameObject(pdf_page_label_style_lower_roman_name()))
    PageLabelUppercaseLetters =>
      Some(PdfNameObject(pdf_page_label_style_upper_letters_name()))
    PageLabelLowercaseLetters =>
      Some(PdfNameObject(pdf_page_label_style_lower_letters_name()))
    PageLabelNoLabelPrefixOnly => None
  }
}

///|
fn PdfDocument::pdf_page_label_of_range(
  self : PdfDocument,
  start_page_zero_based : Int,
  object : PdfObject,
) -> PdfPageLabel {
  {
    label_style: pdf_page_label_style_of_object(
      self.lookup_direct(pdf_page_label_style_key(), object),
    ),
    label_prefix: match
      self.lookup_direct(pdf_page_label_prefix_key(), object) {
      Some(PdfString(prefix)) => Some(prefix)
      _ => None
    },
    start_page: start_page_zero_based + 1,
    start_value: match
      self.lookup_direct(pdf_page_label_start_value_key(), object) {
      Some(PdfInteger(value)) => value
      _ => 1
    },
  }
}

///|
fn pdf_page_label_object(label : PdfPageLabel) -> PdfObject {
  let entries : Array[(PdfName, PdfObject)] = []
  match pdf_page_label_style_object(label.label_style) {
    Some(style) => entries.push((pdf_page_label_style_key(), style))
    None => ()
  }
  match label.label_prefix {
    Some(prefix) =>
      entries.push((pdf_page_label_prefix_key(), PdfString(prefix)))
    None => ()
  }
  if label.start_value != 1 {
    entries.push(
      (pdf_page_label_start_value_key(), PdfInteger(label.start_value)),
    )
  }
  PdfDictionary(entries)
}

///|
pub fn PdfDocument::read_page_labels(
  self : PdfDocument,
) -> Array[PdfPageLabel] raise PdfError {
  let root = self.lookup_object_or_null(self.root())
  if root == PdfNull {
    raise RootExpected
  }
  match self.lookup_direct(pdf_page_label_page_labels_key(), root) {
    Some(label_tree) =>
      [
        for entry in self.read_number_tree(label_tree) => {
          self.pdf_page_label_of_range(entry.0, entry.1)
        }
      ]
    None => []
  }
}

///|
pub fn PdfDocument::remove_page_labels(
  self : PdfDocument,
) -> PdfDocument raise PdfError {
  let root = self.lookup_object_or_null(self.root())
  if root == PdfNull {
    raise RootExpected
  }
  let pdf = self.copy()
  let root_without_labels = root.remove_dict_entry(
    pdf_page_label_page_labels_key(),
  )
  let new_root = pdf.add_object(root_without_labels)
  pdf.set_root(new_root)
  pdf.set_trailer_dict(
    pdf
    .trailer_dict()
    .add_dict_entry(pdf_page_label_root_key(), PdfIndirect(new_root)),
  )
  pdf
}

///|
pub fn PdfDocument::write_page_labels(
  self : PdfDocument,
  labels : ArrayView[PdfPageLabel],
) -> PdfDocument raise PdfError {
  if labels.length() == 0 {
    self.remove_page_labels()
  } else {
    let root = self.lookup_object_or_null(self.root())
    if root == PdfNull {
      raise RootExpected
    }
    let pdf = self.copy()
    let entries : Array[(Int, PdfObject)] = []
    for label in labels {
      entries.push((label.start_page - 1, pdf_page_label_object(label)))
    }
    let new_root = pdf.add_object(
      root.add_dict_entry(
        pdf_page_label_page_labels_key(),
        pdf.build_number_tree(entries),
      ),
    )
    pdf.set_root(new_root)
    pdf.set_trailer_dict(
      pdf
      .trailer_dict()
      .add_dict_entry(pdf_page_label_root_key(), PdfIndirect(new_root)),
    )
    pdf
  }
}
