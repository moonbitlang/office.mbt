///|
fn pdf_texttopdf_font_id(font_index : Int) -> String {
  font_index.to_string()
}

///|
fn pdf_texttopdf_push_text(
  output : Array[PdfTypeElement],
  text : Array[Byte],
) -> Unit {
  output.push(PdfTypeText(Bytes::from_array(text)))
}

///|
fn pdf_texttopdf_process_codepoints(
  fontpack : PdfFontPack,
  font_size : Double,
  current_font : Ref[Int],
  output : Array[PdfTypeElement],
  codepoints : ArrayView[Int],
) -> Unit raise PdfError {
  let mut current_text : Array[Byte] = []
  for codepoint in codepoints {
    match fontpack.get_char(codepoint) {
      Some((charcode, font_index, font)) => {
        guard charcode >= 0 && charcode < 256 else { raise BadText }
        if font_index != current_font.val {
          if current_text.length() > 0 {
            pdf_texttopdf_push_text(output, current_text)
            current_text = []
          }
          current_font.val = font_index
          output.push(
            PdfTypeFont(pdf_texttopdf_font_id(font_index), font, font_size),
          )
        }
        current_text.push(charcode.to_byte())
      }
      None => ()
    }
  }
  pdf_texttopdf_push_text(output, current_text)
}

///|
/// Convert UTF-8 text into cpdftype instructions using a font pack.
///
/// Newlines become `PdfTypeNewLine`, carriage returns are ignored, and
/// representable Unicode codepoints are emitted as one-byte PDF charcodes.
pub fn pdf_texttopdf_of_utf8_with_newlines(
  fontpack : PdfFontPack,
  font_size : Double,
  text : BytesView,
) -> Array[PdfTypeElement] raise PdfError {
  let output : Array[PdfTypeElement] = []
  let current_font : Ref[Int] = { val: -1 }
  let codepoints = pdf_codepoints_of_utf8(text)
  let mut buffer : Array[Int] = []
  for codepoint in codepoints {
    match codepoint {
      10 => {
        if buffer.length() > 0 {
          pdf_texttopdf_process_codepoints(
            fontpack, font_size, current_font, output, buffer,
          )
        }
        output.push(PdfTypeNewLine)
        buffer = []
      }
      13 => ()
      _ => buffer.push(codepoint)
    }
  }
  if buffer.length() > 0 {
    pdf_texttopdf_process_codepoints(
      fontpack, font_size, current_font, output, buffer,
    )
  }
  output
}

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

///|
/// Typeset UTF-8 text into a standalone PDF document using an existing font
/// pack.
///
/// This covers the non-PDF/UA `cpdftexttopdf.ml` path. Structure-tree assembly
/// is kept separate because it mutates the catalog and parent tree after page
/// generation.
pub fn pdf_texttopdf_typeset(
  fontpack : PdfFontPack,
  font_size : Double,
  paper : PaperSize,
  text : BytesView,
) -> PdfDocument raise PdfError {
  let document = pdf_document_empty()
  let instructions = pdf_texttopdf_of_utf8_with_newlines(
    fontpack, font_size, text,
  )
  let elements = pdf_texttopdf_document_elements(instructions)
  let margin = unit_points(paper.width(), paper.unit()) / 15.0
  let result = document.pdf_type_typeset(
    false, margin, margin, margin, margin, paper, elements,
  )
  let page_root = document.add_pagetree(result.pages)
  ignore(document.add_root(page_root, []))
  document
}
