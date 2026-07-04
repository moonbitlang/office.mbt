///|
/// Add paragraph tags around a cpdftype stream.
///
/// This mirrors `cpdftexttopdf.ml`: a blank line closes the current paragraph,
/// preserves both line breaks, and starts a new paragraph with tag number zero.
pub fn pdf_texttopdf_tag_paragraphs(
  elements : ArrayView[PdfTypeElement],
) -> Array[PdfTypeElement] {
  let output : Array[PdfTypeElement] = [PdfTypeTag("P", 0)]
  let mut index = 0
  while index < elements.length() {
    match elements[index] {
      PdfTypeNewLine if index + 1 < elements.length() &&
        elements[index + 1] is PdfTypeNewLine => {
        output.push(PdfTypeEndTag)
        output.push(PdfTypeNewLine)
        output.push(PdfTypeNewLine)
        output.push(PdfTypeTag("P", 0))
        index += 2
      }
      element => {
        output.push(element)
        index += 1
      }
    }
  }
  output.push(PdfTypeEndTag)
  output
}

///|
fn pdf_texttopdf_first_font(
  elements : ArrayView[PdfTypeElement],
) -> PdfTypeElement? {
  let mut found = None
  for element in elements {
    match element {
      PdfTypeFont(_, _, _) if found is None => found = Some(element)
      _ => ()
    }
  }
  found
}

///|
fn pdf_texttopdf_document_elements(
  elements : ArrayView[PdfTypeElement],
) -> Array[PdfTypeElement] {
  match pdf_texttopdf_first_font(elements) {
    Some(first_font) => {
      let output : Array[PdfTypeElement] = [first_font, PdfTypeBeginDocument]
      for element in elements {
        output.push(element)
      }
      output
    }
    None => []
  }
}
