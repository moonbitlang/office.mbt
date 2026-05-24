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
/// Numbering style used for a page-label range.
///
/// `PageLabelNoLabelPrefixOnly` means no numeric suffix is generated; only the
/// optional prefix contributes to the visible label.
pub(all) enum PdfPageLabelStyle {
  PageLabelDecimalArabic
  PageLabelUppercaseRoman
  PageLabelLowercaseRoman
  PageLabelUppercaseLetters
  PageLabelLowercaseLetters
  PageLabelNoLabelPrefixOnly
} derive(Debug, Eq, ToJson)

///|
/// One page-label range.
///
/// `start_page` is 1-based. `start_value` is the numeric value shown on that
/// page before style formatting, and `label_prefix` is stored as PDF bytes.
pub(all) struct PdfPageLabel {
  label_style : PdfPageLabelStyle
  label_prefix : PdfBytes?
  start_page : Int
  start_value : Int
} derive(Debug, Eq, ToJson)

///|
/// Return a stable debug name for a page-label style.
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
/// Parse a debug-style page-label style name.
///
/// Unknown names raise `PdfError::PageLabelStyleExpected`.
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
/// Format a page-label range as a diagnostic byte string.
pub fn pdf_string_of_page_label(label : PdfPageLabel) -> PdfBytes {
  let labelstyle_key = pdf_page_label_ascii_bytes("labelstyle: ")
  let labelstyle_value = pdf_page_label_ascii_bytes(
    label.label_style.debug_name(),
  )
  let labelprefix_key = pdf_page_label_ascii_bytes("labelprefix: ")
  let labelprefix_value = match label.label_prefix {
    Some(prefix) => prefix
    None => pdf_page_label_ascii_bytes("None")
  }
  let startpage_key = pdf_page_label_ascii_bytes("startpage: ")
  let startpage_value = pdf_page_label_ascii_bytes(label.start_page.to_string())
  let startvalue_key = pdf_page_label_ascii_bytes("startvalue: ")
  let startvalue_value = pdf_page_label_ascii_bytes(
    label.start_value.to_string(),
  )
  let output = Array::make(
    labelstyle_key.length() +
    labelstyle_value.length() +
    labelprefix_key.length() +
    labelprefix_value.length() +
    startpage_key.length() +
    startpage_value.length() +
    startvalue_key.length() +
    startvalue_value.length() +
    4,
    b'\n',
  )
  let mut position = 0
  position = pdf_page_label_copy_bytes(output, position, labelstyle_key)
  position = pdf_page_label_copy_bytes(output, position, labelstyle_value)
  position += 1
  position = pdf_page_label_copy_bytes(output, position, labelprefix_key)
  position = pdf_page_label_copy_bytes(output, position, labelprefix_value)
  position += 1
  position = pdf_page_label_copy_bytes(output, position, startpage_key)
  position = pdf_page_label_copy_bytes(output, position, startpage_value)
  position += 1
  position = pdf_page_label_copy_bytes(output, position, startvalue_key)
  ignore(pdf_page_label_copy_bytes(output, position, startvalue_value))
  Bytes::from_array(output)
}

///|
/// Default decimal page-label range starting at page 1 with value 1.
pub let pdf_page_label_basic : PdfPageLabel = {
  label_style: PageLabelDecimalArabic,
  label_prefix: None,
  start_page: 1,
  start_value: 1,
}

///|
/// Ensure a label list has an initial range covering page 1.
///
/// Empty lists or lists that start after page 1 receive `pdf_page_label_basic`.
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
/// Insert or replace a label range over a page interval.
///
/// Existing ranges after `range_end_page` are preserved, and a continuation
/// range is inserted when needed so later labels keep their previous numbering.
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
fn pdf_page_label_range_extents(
  page_numbers : ArrayView[Int],
) -> Array[(Int, Int)] {
  let ranges : Array[(Int, Int)] = []
  if page_numbers.length() > 0 {
    let mut start = page_numbers[0]
    let mut previous = page_numbers[0]
    for index in 1..<page_numbers.length() {
      let page_number = page_numbers[index]
      if page_number == previous + 1 {
        previous = page_number
      } else {
        ranges.push((start, previous))
        start = page_number
        previous = page_number
      }
    }
    ranges.push((start, previous))
  }
  ranges
}

///|
fn pdf_page_label_has_page_one(labels : ArrayView[PdfPageLabel]) -> Bool {
  for label in labels {
    if label.start_page == 1 {
      break true
    }
  } nobreak {
    false
  }
}

///|
fn pdf_page_label_start_additions(ranges : ArrayView[(Int, Int)]) -> Array[Int] {
  let additions : Array[Int] = []
  let mut so_far = 0
  for range in ranges {
    let (start_page, end_page) = range
    additions.push(so_far)
    so_far += end_page - start_page + 1
  }
  additions
}

///|
fn pdf_page_label_with_basic_if_needed(
  labels : ArrayView[PdfPageLabel],
) -> Array[PdfPageLabel] {
  let output : Array[PdfPageLabel] = []
  if !pdf_page_label_has_page_one(labels) {
    output.push(pdf_page_label_basic)
  }
  for label in labels {
    output.push(label)
  }
  output
}

///|
/// Add page-label ranges to the selected one-based page numbers.
///
/// `page_numbers` is interpreted in its existing order; contiguous runs are
/// labelled as ranges. When `progress` is true, each later range starts after
/// the number of pages already labelled by earlier ranges.
pub fn PdfDocument::add_page_labels(
  self : PdfDocument,
  progress : Bool,
  style : PdfPageLabelStyle,
  prefix : PdfBytes?,
  start_value : Int,
  page_numbers : ArrayView[Int],
) -> PdfDocument raise PdfError {
  let ranges = pdf_page_label_range_extents(page_numbers)
  if ranges.length() == 0 {
    raise BadPageSpecification("empty page label range")
  }
  let additions = pdf_page_label_start_additions(ranges)
  let end_page = self.endpage()
  let mut labels = pdf_page_label_with_basic_if_needed(self.read_page_labels())
  for index in 0..<ranges.length() {
    let (range_start, range_end) = ranges[index]
    let addition = if progress { additions[index] } else { 0 }
    labels = pdf_page_label_add_label(
      end_page,
      labels,
      {
        label_style: style,
        label_prefix: prefix,
        start_page: range_start,
        start_value: start_value + addition,
      },
      range_end,
    )
  }
  self.write_page_labels(labels)
}

///|
/// Compatibility wrapper for `PdfDocument::add_page_labels`.
pub fn pdf_add_page_labels(
  document : PdfDocument,
  progress : Bool,
  style : PdfPageLabelStyle,
  prefix : PdfBytes?,
  start_value : Int,
  page_numbers : ArrayView[Int],
) -> PdfDocument raise PdfError {
  document.add_page_labels(progress, style, prefix, start_value, page_numbers)
}

///|
fn pdf_page_label_json_integral_number(value : Double) -> Int raise PdfError {
  let integer = value.to_int()
  guard integer.to_double() == value else { raise NumberExpected }
  integer
}

///|
fn pdf_page_label_json_int(value : Json?) -> Int raise PdfError {
  match value {
    Some(Number(number, repr=_)) => pdf_page_label_json_integral_number(number)
    _ => raise BadText
  }
}

///|
fn pdf_page_label_json_string(value : Json?) -> String raise PdfError {
  match value {
    Some(String(text)) => text
    _ => raise BadText
  }
}

///|
fn pdf_page_label_json_prefix(value : Json?) -> PdfBytes? raise PdfError {
  match value {
    Some(Null) => None
    Some(String(text)) => Some(pdf_pdfdocstring_of_utf8(@utf8.encode(text)))
    _ => raise BadText
  }
}

///|
fn pdf_page_label_of_json(json : Json) -> PdfPageLabel raise PdfError {
  match json {
    Object(entries) => {
      let style = pdf_page_label_style_of_string(
        pdf_page_label_json_string(entries.get("labelstyle")),
      )
      {
        label_style: style,
        label_prefix: pdf_page_label_json_prefix(entries.get("labelprefix")),
        start_page: pdf_page_label_json_int(entries.get("startpage")),
        start_value: pdf_page_label_json_int(entries.get("startvalue")),
      }
    }
    _ => raise BadText
  }
}

///|
/// Add page labels from cpdf's JSON page-label array shape.
///
/// Each entry must contain `labelstyle`, `labelprefix`, `startpage`, and
/// `startvalue`. Prefix strings are interpreted as UTF-8 and encoded as compact
/// PDFDocStrings, matching cpdf's `add_page_labels_json`.
pub fn PdfDocument::add_page_labels_json(
  self : PdfDocument,
  json : Json,
) -> PdfDocument raise PdfError {
  match json {
    Array(items) => {
      let labels : Array[PdfPageLabel] = []
      for item in items {
        labels.push(pdf_page_label_of_json(item))
      }
      self.write_page_labels(labels)
    }
    _ => raise BadText
  }
}

///|
/// Compatibility wrapper for `PdfDocument::add_page_labels_json`.
pub fn pdf_add_page_labels_json(
  document : PdfDocument,
  json : Json,
) -> PdfDocument raise PdfError {
  document.add_page_labels_json(json)
}

///|
fn pdf_page_label_push_bytes(output : Array[Byte], bytes : PdfBytes) -> Unit {
  for byte in bytes {
    output.push(byte)
  }
}

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

///|
/// Collapse adjacent page-label ranges that produce the same numbering stream.
///
/// Ranges are merged only when their style, prefix, and `start_page -
/// start_value` offset are identical, so visible labels for every page remain
/// unchanged.
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
/// Merge page labels for selected pages from several source documents.
///
/// `ranges` contains 1-based source page numbers for each document. The merged
/// result preserves the visible labels from those source pages at their new
/// concatenated positions and coalesces adjacent equivalent ranges.
///
/// Raises if the document and range arrays have different lengths, or if a
/// source document's page-label tree cannot be read.
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
/// Read the document catalog `/PageLabels` number tree.
///
/// The returned `start_page` values are converted from PDF's zero-based page
/// indexes to the public 1-based page numbering used by this module. Documents
/// without page labels return an empty array.
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
/// Compatibility wrapper for `PdfDocument::read_page_labels`.
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
/// Return a copy of the document with catalog `/PageLabels` removed.
///
/// The original document is not mutated; the returned document has a new root
/// object and trailer root reference.
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
/// Compatibility wrapper for `PdfDocument::remove_page_labels`.
pub fn pdf_remove_page_labels(
  document : PdfDocument,
) -> PdfDocument raise PdfError {
  document.remove_page_labels()
}

///|
/// Return a copy of the document with catalog `/PageLabels` replaced.
///
/// Public `start_page` values are written as zero-based PDF number-tree keys.
/// Passing an empty label list removes any existing page-label tree.
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
/// Compatibility wrapper for `PdfDocument::write_page_labels`.
pub fn pdf_write_page_labels(
  document : PdfDocument,
  labels : ArrayView[PdfPageLabel],
) -> PdfDocument raise PdfError {
  document.write_page_labels(labels)
}
