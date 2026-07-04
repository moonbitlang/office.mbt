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
) -> Unit raise @core.PdfError {
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
) -> Array[PdfTypeElement] raise @core.PdfError {
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
