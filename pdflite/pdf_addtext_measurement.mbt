///|
/// Convert UTF-8 add-text input to PDF charcode bytes for `font`.
///
/// Codepoints not representable by the font are skipped, matching cpdf's
/// `option_map` behavior in `charcodes_of_utf8`.
pub fn pdf_addtext_charcodes_of_utf8(
  font : PdfFont,
  text : String,
) -> PdfBytes raise PdfError {
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
        output[position] = pdf_byte_of_int(charcode)
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
) -> Double raise PdfError {
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
/// Measure text bytes with cpdf add-text's selected font mode.
///
/// This ports the local `calc_textwidth` branch in `cpdfaddtext.ml`. Font packs
/// interpret `text` as UTF-8 so codepoints can select pack members; selected
/// parsed fonts and existing page fonts treat `text` as the PDF text bytes to
/// measure.
pub fn PdfDocument::addtext_calc_textwidth(
  self : PdfDocument,
  page : PdfPage,
  font : PdfFont?,
  fontpack : PdfFontPack?,
  fontname : PdfName,
  font_size : Double,
  text : BytesView,
) -> Double raise PdfError {
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
  page : PdfPage,
  font : PdfFont?,
  fontpack : PdfFontPack?,
  fontname : PdfName,
  font_size : Double,
  text : BytesView,
) -> Double raise PdfError {
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
  page : PdfPage,
  font : PdfFont?,
  fontpack : PdfFontPack?,
  fontname : PdfName,
  font_size : Double,
  text : BytesView,
  expanded_lines : ArrayView[Bytes],
) -> PdfAddTextLineWidths raise PdfError {
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
  page : PdfPage,
  font : PdfFont?,
  fontpack : PdfFontPack?,
  fontname : PdfName,
  font_size : Double,
  text : BytesView,
  expanded_lines : ArrayView[Bytes],
) -> PdfAddTextLineWidths raise PdfError {
  document.addtext_line_widths(
    page, font, fontpack, fontname, font_size, text, expanded_lines,
  )
}

///|
/// Return the byte string cpdf add-text uses for measuring a visible line.
///
/// Raw mode and font-pack mode keep UTF-8 bytes. Selected simple-font mode
/// converts Unicode text to PDF character codes first, matching cpdf's
/// non-raw line measurement path.
pub fn pdf_addtext_measurement_bytes(
  font : PdfFont?,
  fontpack : PdfFontPack?,
  raw : Bool,
  text : String,
) -> PdfBytes raise PdfError {
  if raw || fontpack is Some(_) {
    @utf8.encode(text)
  } else {
    match font {
      Some(font) => pdf_addtext_charcodes_of_utf8(font, text)
      None => @utf8.encode(text)
    }
  }
}

///|
fn PdfDocument::pdf_addtext_measurement_bytes_for_page(
  self : PdfDocument,
  page : PdfPage,
  font : PdfFont?,
  fontpack : PdfFontPack?,
  fontname : PdfName,
  raw : Bool,
  text : String,
) -> PdfBytes raise PdfError {
  if raw || fontpack is Some(_) {
    @utf8.encode(text)
  } else {
    match font {
      Some(font) => pdf_addtext_charcodes_of_utf8(font, text)
      None => {
        let (_, font_object) = self.addtext_existing_font_resource(
          page, fontname,
        )
        pdf_addtext_charcodes_of_utf8(self.read_font(font_object), text)
      }
    }
  }
}

///|
/// Prepare one cpdf add-text line for later content and annotation emission.
///
/// This ports the source-level block which expands page-local replacement
/// fields, strips `%URL[text|url]` markup, measures the current and paragraph
/// line widths, and resolves the final cpdf placement offsets.
pub fn PdfDocument::addtext_prepare_line(
  self : PdfDocument,
  page : PdfPage,
  time : PdfStrftimeTime,
  lines : ArrayView[String],
  replacements : ArrayView[(String, () -> String)],
  font : PdfFont?,
  fontpack : PdfFontPack?,
  fontname : PdfName,
  font_size : Double,
  text : String,
  position : PdfPosition,
  relative_to_box? : PdfName = pdf_page_mediabox_key(),
  horizontal_offset? : Double = 0.0,
  vertical_offset? : Double = 0.0,
  justification? : PdfAddTextJustification = PdfAddTextLeftJustify,
  rotation? : PdfAddTextRotation = PdfAddTextRot0,
  raw? : Bool = false,
) -> PdfAddTextPreparedLine raise PdfError {
  let processed = pdf_addtext_process_text_with_time(time, text, replacements)
  let parsed = pdf_addtext_get_urls_line(processed)
  let expanded_lines = pdf_addtext_expand_lines_with_time(
    time, lines, replacements,
  )
  let text_bytes = self.pdf_addtext_measurement_bytes_for_page(
    page,
    font,
    fontpack,
    fontname,
    raw,
    parsed.text,
  )
  let expanded_line_bytes : Array[PdfBytes] = Array::new(
    capacity=expanded_lines.length(),
  )
  for line in expanded_lines {
    expanded_line_bytes.push(
      self.pdf_addtext_measurement_bytes_for_page(
        page, font, fontpack, fontname, raw, line,
      ),
    )
  }
  let widths = self.addtext_line_widths(
    page, font, fontpack, fontname, font_size, text_bytes, expanded_line_bytes,
  )
  let bounds = self.pdf_addtext_rectangle_bounds(page, relative_to_box)
  let placement = pdf_addtext_line_placement(
    bounds,
    position,
    rotation,
    widths.text_width,
    widths.longest_width,
    horizontal_offset,
    vertical_offset,
    justification,
  )
  {
    text: parsed.text,
    text_bytes,
    urls: parsed.urls,
    expanded_lines,
    expanded_line_bytes,
    widths,
    placement,
  }
}

///|
/// Compatibility wrapper for `PdfDocument::addtext_prepare_line`.
pub fn pdf_addtext_prepare_line(
  document : PdfDocument,
  page : PdfPage,
  time : PdfStrftimeTime,
  lines : ArrayView[String],
  replacements : ArrayView[(String, () -> String)],
  font : PdfFont?,
  fontpack : PdfFontPack?,
  fontname : PdfName,
  font_size : Double,
  text : String,
  position : PdfPosition,
  relative_to_box? : PdfName = pdf_page_mediabox_key(),
  horizontal_offset? : Double = 0.0,
  vertical_offset? : Double = 0.0,
  justification? : PdfAddTextJustification = PdfAddTextLeftJustify,
  rotation? : PdfAddTextRotation = PdfAddTextRot0,
  raw? : Bool = false,
) -> PdfAddTextPreparedLine raise PdfError {
  document.addtext_prepare_line(
    page,
    time,
    lines,
    replacements,
    font,
    fontpack,
    fontname,
    font_size,
    text,
    position,
    relative_to_box~,
    horizontal_offset~,
    vertical_offset~,
    justification~,
    rotation~,
    raw~,
  )
}

///|
/// Return the widest add-text line width.
pub fn pdf_addtext_longest_width(
  widths : ArrayView[Double],
) -> Double raise PdfError {
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
