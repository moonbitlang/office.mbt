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
    let output : Array[PdfPageLabel] = Array::new(capacity=labels.length() + 1)
    output.push(pdf_page_label_basic)
    for label in labels {
      output.push(label)
    }
    output
  } else {
    let output : Array[PdfPageLabel] = Array::new(capacity=labels.length())
    for label in labels {
      output.push(label)
    }
    output
  }
}
