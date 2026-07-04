///|
fn pdf_type_ascii(text : String) -> @core.PdfBytes {
  @ascii.encode(text)
}

///|
fn pdf_type_ocaml_string_of_float(value : Double) -> String {
  if value.is_nan() {
    "nan"
  } else if value.is_pos_inf() {
    "inf"
  } else if value.is_neg_inf() {
    "-inf"
  } else {
    let text = value.to_string()
    if !text.contains(".") && !text.contains("e") && !text.contains("E") {
      text + "."
    } else {
      text
    }
  }
}

///|
/// Render one cpdftype element using the CamlPDF debug spelling.
pub fn pdf_string_of_type_element(element : PdfTypeElement) -> @core.PdfBytes {
  match element {
    PdfTypeText(text) => text
    PdfTypeHGlue(length) =>
      pdf_type_ascii("HGLUE" + pdf_type_ocaml_string_of_float(length))
    PdfTypeVGlue(_) => pdf_type_ascii("VGLUE")
    PdfTypeNewLine => pdf_type_ascii("NewLine")
    PdfTypeNewPage => pdf_type_ascii("NewPage")
    PdfTypeFont(_, _, _) => pdf_type_ascii("Font")
    PdfTypeBeginDest(_, _) => pdf_type_ascii("BeginDest")
    PdfTypeEndDest => pdf_type_ascii("EndDest")
    PdfTypeBeginDocument => pdf_type_ascii("BeginDocument")
    PdfTypeTag(name, number) =>
      pdf_type_ascii("Tag " + name + " " + number.to_string())
    PdfTypeEndTag => pdf_type_ascii("EndTag")
  }
}

///|
/// Render a cpdftype element stream using CamlPDF's leading-newline format.
pub fn pdf_string_of_type(
  elements : ArrayView[PdfTypeElement],
) -> @core.PdfBytes {
  let rendered = Array::make(elements.length(), pdf_type_ascii(""))
  let mut output_length = 0
  for i in 0..<elements.length() {
    let element_bytes = pdf_string_of_type_element(elements[i])
    rendered[i] = element_bytes
    output_length += 1 + element_bytes.length()
  }
  let output = Array::make(output_length, b'\x00')
  let mut position = 0
  for element_bytes in rendered {
    output[position] = 10
    position += 1
    for byte in element_bytes {
      output[position] = byte
      position += 1
    }
  }
  Bytes::from_array(output)
}

///|
/// Source-spelled compatibility alias for cpdftype's `to_string`.
pub fn pdf_type_to_string(
  elements : ArrayView[PdfTypeElement],
) -> @core.PdfBytes {
  pdf_string_of_type(elements)
}
