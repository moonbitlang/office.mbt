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
