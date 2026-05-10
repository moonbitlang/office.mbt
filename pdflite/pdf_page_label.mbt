///|
fn pdf_page_label_name(text : String) -> PdfName {
  pdf_name_of_bytes(@ascii.encode(text))
}

///|
let pdf_page_label_root_key_name : PdfName = pdf_page_label_name("/Root")

///|
fn pdf_page_label_root_key() -> PdfName {
  pdf_page_label_root_key_name
}

///|
let pdf_page_label_page_labels_key_name : PdfName = pdf_page_label_name(
  "/PageLabels",
)

///|
fn pdf_page_label_page_labels_key() -> PdfName {
  pdf_page_label_page_labels_key_name
}

///|
let pdf_page_label_style_key_name : PdfName = pdf_page_label_name("/S")

///|
fn pdf_page_label_style_key() -> PdfName {
  pdf_page_label_style_key_name
}

///|
let pdf_page_label_prefix_key_name : PdfName = pdf_page_label_name("/P")

///|
fn pdf_page_label_prefix_key() -> PdfName {
  pdf_page_label_prefix_key_name
}

///|
let pdf_page_label_start_value_key_name : PdfName = pdf_page_label_name("/St")

///|
fn pdf_page_label_start_value_key() -> PdfName {
  pdf_page_label_start_value_key_name
}

///|
let pdf_page_label_style_decimal_name_value : PdfName = pdf_page_label_name(
  "/D",
)

///|
fn pdf_page_label_style_decimal_name() -> PdfName {
  pdf_page_label_style_decimal_name_value
}

///|
let pdf_page_label_style_upper_roman_name_value : PdfName = pdf_page_label_name(
  "/R",
)

///|
fn pdf_page_label_style_upper_roman_name() -> PdfName {
  pdf_page_label_style_upper_roman_name_value
}

///|
let pdf_page_label_style_lower_roman_name_value : PdfName = pdf_page_label_name(
  "/r",
)

///|
fn pdf_page_label_style_lower_roman_name() -> PdfName {
  pdf_page_label_style_lower_roman_name_value
}

///|
let pdf_page_label_style_upper_letters_name_value : PdfName = pdf_page_label_name(
  "/A",
)

///|
fn pdf_page_label_style_upper_letters_name() -> PdfName {
  pdf_page_label_style_upper_letters_name_value
}

///|
let pdf_page_label_style_lower_letters_name_value : PdfName = pdf_page_label_name(
  "/a",
)

///|
fn pdf_page_label_style_lower_letters_name() -> PdfName {
  pdf_page_label_style_lower_letters_name_value
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
pub fn PdfPageLabelStyle::debug_name(self : PdfPageLabelStyle) -> String {
  match self {
    PageLabelDecimalArabic => "DecimalArabic"
    PageLabelUppercaseRoman => "UppercaseRoman"
    PageLabelLowercaseRoman => "LowercaseRoman"
    PageLabelUppercaseLetters => "UppercaseLetters"
    PageLabelLowercaseLetters => "LowercaseLetters"
    PageLabelNoLabelPrefixOnly => "NoLabelPrefixOnly"
  }
}

///|
pub fn pdf_page_label_style_of_string(
  text : String,
) -> PdfPageLabelStyle raise PdfError {
  match text {
    "DecimalArabic" => PageLabelDecimalArabic
    "UppercaseRoman" => PageLabelUppercaseRoman
    "LowercaseRoman" => PageLabelLowercaseRoman
    "UppercaseLetters" => PageLabelUppercaseLetters
    "LowercaseLetters" => PageLabelLowercaseLetters
    "NoLabelPrefixOnly" => PageLabelNoLabelPrefixOnly
    _ => raise PageLabelStyleExpected(text)
  }
}

///|
pub fn pdf_string_of_page_label(label : PdfPageLabel) -> PdfBytes {
  let output : Array[Byte] = []
  pdf_writer_push_ascii(output, "labelstyle: ")
  pdf_writer_push_ascii(output, label.label_style.debug_name())
  pdf_writer_push_byte(output, 10)
  pdf_writer_push_ascii(output, "labelprefix: ")
  match label.label_prefix {
    Some(prefix) => pdf_writer_push_view(output, prefix)
    None => pdf_writer_push_ascii(output, "None")
  }
  pdf_writer_push_byte(output, 10)
  pdf_writer_push_ascii(output, "startpage: ")
  pdf_writer_push_ascii(output, label.start_page.to_string())
  pdf_writer_push_byte(output, 10)
  pdf_writer_push_ascii(output, "startvalue: ")
  pdf_writer_push_ascii(output, label.start_value.to_string())
  pdf_writer_push_byte(output, 10)
  Bytes::from_array(output)
}

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
fn pdf_page_label_continuation(
  labels : ArrayView[PdfPageLabel],
  start_page : Int,
) -> PdfPageLabel? {
  if labels.length() == 0 {
    None
  } else {
    let label = labels[labels.length() - 1]
    Some({
      ..label,
      start_page,
      start_value: start_page + (label.start_value - label.start_page),
    })
  }
}

///|
pub fn pdf_page_label_add_label(
  end_page : Int,
  labels : ArrayView[PdfPageLabel],
  label : PdfPageLabel,
  range_end_page : Int,
) -> Array[PdfPageLabel] {
  let before_or_during_or_equal : Array[PdfPageLabel] = []
  let after : Array[PdfPageLabel] = []
  for existing in labels {
    if existing.start_page <= range_end_page {
      before_or_during_or_equal.push(existing)
    } else {
      after.push(existing)
    }
  }
  let before_or_during : Array[PdfPageLabel] = []
  for existing in before_or_during_or_equal {
    if existing.start_page != label.start_page {
      before_or_during.push(existing)
    }
  }
  let before : Array[PdfPageLabel] = []
  for existing in before_or_during {
    if !(existing.start_page > label.start_page &&
      existing.start_page <= range_end_page) {
      before.push(existing)
    }
  }
  let output = before
  output.push(label)
  if range_end_page != end_page &&
    !(after.length() > 0 && after[0].start_page == range_end_page + 1) {
    match
      pdf_page_label_continuation(before_or_during_or_equal, range_end_page + 1) {
      Some(replica) => output.push(replica)
      None => ()
    }
  }
  for existing in after {
    output.push(existing)
  }
  output
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
pub fn pdf_page_label_merge(
  pdfs : ArrayView[PdfDocument],
  ranges : ArrayView[Array[Int]],
) -> Array[PdfPageLabel] raise PdfError {
  if pdfs.length() != ranges.length() {
    raise PageTreeExpected
  }
  let labels : Array[PdfPageLabel] = []
  let mut merged_page = 1
  for index in 0..<pdfs.length() {
    let source_labels = pdf_page_label_complete(pdfs[index].read_page_labels())
    for page_number in ranges[index] {
      let label = pdf_page_label_of_page_number(page_number, source_labels).unwrap()
      labels.push({ ..label, start_page: merged_page })
      merged_page += 1
    }
  }
  pdf_page_label_coalesce(labels)
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
fn PdfDocument::pdf_page_label_raw_entries(
  self : PdfDocument,
  tree : PdfObject,
) -> Array[(PdfObject, PdfObject)] raise PdfError {
  let output : Array[(PdfObject, PdfObject)] = []
  match
    self.lookup_direct_or_else(pdf_tree_names_key(), pdf_tree_nums_key(), tree) {
    Some(PdfArray(items)) =>
      for i in 0..<(items.length() / 2) {
        output.push((items[i * 2], items[i * 2 + 1]))
      }
    _ =>
      match self.lookup_direct(pdf_tree_kids_key(), tree) {
        Some(PdfArray(kids)) =>
          for kid in kids {
            for entry in self.pdf_page_label_raw_entries(kid) {
              output.push(entry)
            }
          }
        _ => raise PageTreeExpected
      }
  }
  output
}

///|
fn PdfDocument::pdf_page_label_of_range(
  self : PdfDocument,
  start_page_object : PdfObject,
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
    start_page: match start_page_object {
      PdfInteger(start_page_zero_based) => start_page_zero_based + 1
      _ => 1
    },
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
fn PdfDocument::pdf_page_label_catalog(
  self : PdfDocument,
) -> PdfObject raise PdfError {
  self.catalog()
}

///|
pub fn PdfDocument::read_page_labels(
  self : PdfDocument,
) -> Array[PdfPageLabel] raise PdfError {
  let root = self.pdf_page_label_catalog()
  match self.lookup_direct(pdf_page_label_page_labels_key(), root) {
    Some(label_tree) =>
      [
        for entry in self.pdf_page_label_raw_entries(label_tree) => {
          self.pdf_page_label_of_range(entry.0, entry.1)
        }
      ]
    None => []
  }
}

///|
pub fn pdf_read_page_labels(
  document : PdfDocument,
) -> Array[PdfPageLabel] raise PdfError {
  document.read_page_labels()
}

///|
fn PdfDocument::pdf_page_label_has_labels(
  self : PdfDocument,
) -> Bool raise PdfError {
  let root = self.pdf_page_label_catalog()
  self.lookup_direct(pdf_page_label_page_labels_key(), root) is Some(_)
}

///|
pub fn PdfDocument::remove_page_labels(
  self : PdfDocument,
) -> PdfDocument raise PdfError {
  let root = self.pdf_page_label_catalog()
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
pub fn pdf_remove_page_labels(
  document : PdfDocument,
) -> PdfDocument raise PdfError {
  document.remove_page_labels()
}

///|
pub fn PdfDocument::write_page_labels(
  self : PdfDocument,
  labels : ArrayView[PdfPageLabel],
) -> PdfDocument raise PdfError {
  if labels.length() == 0 {
    self.remove_page_labels()
  } else {
    let root = self.pdf_page_label_catalog()
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

///|
pub fn pdf_write_page_labels(
  document : PdfDocument,
  labels : ArrayView[PdfPageLabel],
) -> PdfDocument raise PdfError {
  document.write_page_labels(labels)
}
