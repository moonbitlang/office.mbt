///|
/// Convert UTF-8 add-text input to PDF charcode bytes for `font`.
///
/// Codepoints not representable by the font are skipped, matching cpdf's
/// `option_map` behavior in `charcodes_of_utf8`.
pub fn pdf_addtext_charcodes_of_utf8(
  font : PdfFont,
  text : String,
) -> @core.PdfBytes raise @core.PdfError {
  let extractor = pdf_charcode_extractor_of_font_real(font)
  let codepoints = pdf_codepoints_of_utf8(@utf8.encode(text))
  let mut length = 0
  for codepoint in codepoints {
    match extractor(codepoint) {
      Some(_) => length += 1
      None => ()
    }
  }
  let output = Array::make(length, b'\x00')
  let mut position = 0
  for codepoint in codepoints {
    match extractor(codepoint) {
      Some(charcode) => {
        output[position] = @core.pdf_byte_of_int(charcode)
        position += 1
      }
      None => ()
    }
  }
  Bytes::from_array(output)
}

///|
/// Measure cpdf add-text charcode bytes with simple-font metrics.
///
/// This mirrors cpdf's narrow `width_of_text` helper: only simple fonts with
/// explicit `fontmetrics` are measured, and any missing metric makes the whole
/// result `0`.
pub fn pdf_addtext_width_of_text(font : PdfFont, text : BytesView) -> Double {
  match font {
    PdfFontSimple({ fontmetrics: Some(metrics), .. }) => {
      let mut width = 0.0
      for byte in text {
        let code = byte.to_int()
        if code >= metrics.length() {
          return 0.0
        }
        width += metrics[code]
      }
      width
    }
    _ => 0.0
  }
}

///|
/// Measure add-text bytes with the selected parsed font at `font_size`.
pub fn pdf_addtext_width_of_selected_font(
  font : PdfFont,
  font_size : Double,
  text : BytesView,
) -> Double {
  let raw_width = match font {
    PdfFontStandard({ font, .. }) =>
      font.text_width(PdfImplicitInFontFile, text).to_double()
    _ => pdf_addtext_width_of_text(font, text)
  }
  raw_width * font_size / 1000.0
}

///|
/// Measure UTF-8 add-text with a cpdf font pack at `font_size`.
pub fn pdf_addtext_width_of_fontpack(
  fontpack : PdfFontPack,
  font_size : Double,
  text : String,
) -> Double raise @core.PdfError {
  let width_tables : Array[Array[Double]] = Array::new(
    capacity=fontpack.fonts.length(),
  )
  for font in fontpack.fonts {
    width_tables.push(pdf_type_font_widths(font, font_size))
  }
  let mut width = 0.0
  for codepoint in pdf_codepoints_of_utf8(@utf8.encode(text)) {
    match fontpack.get_char(codepoint) {
      Some((charcode, font_index, _)) => {
        let widths = width_tables[font_index]
        if charcode < 0 || charcode >= widths.length() {
          raise FontWidthExpected
        }
        width += widths[charcode]
      }
      None => ()
    }
  }
  width
}

///|
fn pdf_addtext_utf8_string(bytes : BytesView) -> String raise @core.PdfError {
  @utf8.decode(bytes) catch {
    _ => raise InvalidUTF8
  }
}

///|
/// Measure text bytes with cpdf add-text's selected font mode.
///
/// This ports the local `calc_textwidth` branch in `cpdfaddtext.ml`. Font packs
/// interpret `text` as UTF-8 so codepoints can select pack members; selected
/// parsed fonts and existing page fonts treat `text` as the PDF text bytes to
/// measure.
pub fn PdfDocument::addtext_calc_textwidth(
  self : PdfDocument,
  page : @page.PdfPage,
  font : PdfFont?,
  fontpack : PdfFontPack?,
  fontname : @core.PdfName,
  font_size : Double,
  text : BytesView,
) -> Double raise @core.PdfError {
  match fontpack {
    Some(fontpack) =>
      pdf_addtext_width_of_fontpack(
        fontpack,
        font_size,
        pdf_addtext_utf8_string(text),
      )
    None =>
      match font {
        Some(font) => pdf_addtext_width_of_selected_font(font, font_size, text)
        None => {
          let (_, width) = self.addtext_width_of_existing_font_resource(
            page, fontname, font_size, text,
          )
          width
        }
      }
  }
}

///|
/// Compatibility wrapper for `PdfDocument::addtext_calc_textwidth`.
pub fn pdf_addtext_calc_textwidth(
  document : PdfDocument,
  page : @page.PdfPage,
  font : PdfFont?,
  fontpack : PdfFontPack?,
  fontname : @core.PdfName,
  font_size : Double,
  text : BytesView,
) -> Double raise @core.PdfError {
  document.addtext_calc_textwidth(
    page, font, fontpack, fontname, font_size, text,
  )
}

///|
/// Measure cpdf add-text's current line and expanded paragraph widths.
///
/// This ports the local `textwidth`, `allwidths`, and `longest_w` block in
/// `cpdfaddtext.ml` after replacement expansion and URL stripping.
pub fn PdfDocument::addtext_line_widths(
  self : PdfDocument,
  page : @page.PdfPage,
  font : PdfFont?,
  fontpack : PdfFontPack?,
  fontname : @core.PdfName,
  font_size : Double,
  text : BytesView,
  expanded_lines : ArrayView[Bytes],
) -> @addtext.PdfAddTextLineWidths raise @core.PdfError {
  let text_width = self.addtext_calc_textwidth(
    page, font, fontpack, fontname, font_size, text,
  )
  let widths : Array[Double] = Array::new(capacity=expanded_lines.length())
  for line in expanded_lines {
    widths.push(
      self.addtext_calc_textwidth(
        page, font, fontpack, fontname, font_size, line,
      ),
    )
  }
  { text_width, widths, longest_width: pdf_addtext_longest_width(widths) }
}

///|
/// Compatibility wrapper for `PdfDocument::addtext_line_widths`.
pub fn pdf_addtext_line_widths(
  document : PdfDocument,
  page : @page.PdfPage,
  font : PdfFont?,
  fontpack : PdfFontPack?,
  fontname : @core.PdfName,
  font_size : Double,
  text : BytesView,
  expanded_lines : ArrayView[Bytes],
) -> @addtext.PdfAddTextLineWidths raise @core.PdfError {
  document.addtext_line_widths(
    page, font, fontpack, fontname, font_size, text, expanded_lines,
  )
}

///|
/// Return the widest add-text line width.
pub fn pdf_addtext_longest_width(
  widths : ArrayView[Double],
) -> Double raise @core.PdfError {
  if widths.length() == 0 {
    raise SoftError("empty add-text width list")
  }
  let mut longest = widths[0]
  for index in 1..<widths.length() {
    if widths[index] > longest {
      longest = widths[index]
    }
  }
  longest
}
