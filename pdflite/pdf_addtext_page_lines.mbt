///|
/// Add all cpdf add-text lines to one page using cpdf paragraph advancement.
///
/// This ports the outer per-line loop around cpdf's local `addtext` call:
/// initial multi-line offsets, midline/topline baseline adjustment, repeated
/// line emission, and rotation-dependent line advancement.
pub fn PdfDocument::addtext_page_lines(
  self : PdfDocument,
  page : PdfPage,
  time : PdfStrftimeTime,
  lines : ArrayView[String],
  replacements : ArrayView[(String, () -> String)],
  font : PdfFont?,
  fontpack : PdfFontPack?,
  fontname : PdfName,
  font_object : PdfObject?,
  fontpack_font_objects : ArrayView[Int],
  font_size : Double,
  line_spacing : Double,
  colour : PdfContentColour,
  position : PdfPosition,
  relative_to_box? : PdfName = pdf_page_mediabox_key(),
  opacity? : Double = 1.0,
  justification? : PdfAddTextJustification = PdfAddTextLeftJustify,
  rotation? : PdfAddTextRotation = PdfAddTextRot0,
  midline? : Bool = false,
  topline? : Bool = false,
  shift_x? : Double = 0.0,
  shift_y? : Double = 0.0,
  outline? : Bool = false,
  line_width? : Double = 1.0,
  underneath? : Bool = false,
  fast? : Bool = false,
  raw? : Bool = false,
  url_border? : Bool = false,
) -> PdfPage raise PdfError {
  let (initial_h_offset, initial_v_offset) = @addtext.pdf_addtext_initial_line_offsets(
    position,
    lines.length(),
    line_spacing,
    font_size,
  )
  let (baseline_h_offset, baseline_v_offset) = pdf_addtext_baseline_offsets(
    font, font_size, position, rotation, midline, topline,
  )
  let advance = @addtext.pdf_addtext_line_advance(
    rotation, line_spacing, font_size,
  )
  let mut horizontal_offset = initial_h_offset + baseline_h_offset
  let mut vertical_offset = initial_v_offset + baseline_v_offset
  let mut output = page
  for line in lines {
    output = self.addtext_line_page(
      output,
      time,
      lines,
      replacements,
      font,
      fontpack,
      fontname,
      font_object,
      fontpack_font_objects,
      font_size,
      line,
      colour,
      position,
      relative_to_box~,
      horizontal_offset~,
      vertical_offset~,
      shift_x~,
      shift_y~,
      opacity~,
      justification~,
      rotation~,
      outline~,
      line_width~,
      underneath~,
      fast~,
      raw~,
      url_border~,
    )
    horizontal_offset += advance.0
    vertical_offset += advance.1
  }
  output
}

///|
/// Compatibility wrapper for `PdfDocument::addtext_page_lines`.
pub fn pdf_addtext_page_lines(
  document : PdfDocument,
  page : PdfPage,
  time : PdfStrftimeTime,
  lines : ArrayView[String],
  replacements : ArrayView[(String, () -> String)],
  font : PdfFont?,
  fontpack : PdfFontPack?,
  fontname : PdfName,
  font_object : PdfObject?,
  fontpack_font_objects : ArrayView[Int],
  font_size : Double,
  line_spacing : Double,
  colour : PdfContentColour,
  position : PdfPosition,
  relative_to_box? : PdfName = pdf_page_mediabox_key(),
  opacity? : Double = 1.0,
  justification? : PdfAddTextJustification = PdfAddTextLeftJustify,
  rotation? : PdfAddTextRotation = PdfAddTextRot0,
  midline? : Bool = false,
  topline? : Bool = false,
  shift_x? : Double = 0.0,
  shift_y? : Double = 0.0,
  outline? : Bool = false,
  line_width? : Double = 1.0,
  underneath? : Bool = false,
  fast? : Bool = false,
  raw? : Bool = false,
  url_border? : Bool = false,
) -> PdfPage raise PdfError {
  document.addtext_page_lines(
    page,
    time,
    lines,
    replacements,
    font,
    fontpack,
    fontname,
    font_object,
    fontpack_font_objects,
    font_size,
    line_spacing,
    colour,
    position,
    relative_to_box~,
    opacity~,
    justification~,
    rotation~,
    midline~,
    topline~,
    shift_x~,
    shift_y~,
    outline~,
    line_width~,
    underneath~,
    fast~,
    raw~,
    url_border~,
  )
}
