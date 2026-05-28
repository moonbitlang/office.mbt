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
