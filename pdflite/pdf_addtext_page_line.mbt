///|
fn pdf_addtext_height_font_name(fontname : PdfName) -> String {
  let text = @ascii.decode_lossy(fontname.bytes())
  if text.has_prefix("/") {
    text[1:].to_owned()
  } else {
    text
  }
}

///|
fn PdfDocument::pdf_addtext_effective_fontname(
  self : PdfDocument,
  page : PdfPage,
  font : PdfFont?,
  fontpack : PdfFontPack?,
  fontname : PdfName,
) -> PdfName raise PdfError {
  match (font, fontpack) {
    (None, None) => {
      let (resource_name, _) = self.addtext_existing_font_resource(
        page, fontname,
      )
      resource_name
    }
    _ => fontname
  }
}

///|
/// Add one prepared cpdf add-text line to a page.
///
/// This is the single-page counterpart of cpdf's local `addtext_page`: it
/// prepares text and placement, installs resources, emits `/CPDFSTAMP` text
/// operators, creates URL annotations, and appends or prepends the content.
pub fn PdfDocument::addtext_line_page(
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
  text : String,
  colour : PdfContentColour,
  position : PdfPosition,
  relative_to_box? : PdfName = pdf_page_mediabox_key(),
  horizontal_offset? : Double = 0.0,
  vertical_offset? : Double = 0.0,
  shift_x? : Double = 0.0,
  shift_y? : Double = 0.0,
  opacity? : Double = 1.0,
  justification? : PdfAddTextJustification = PdfAddTextLeftJustify,
  rotation? : PdfAddTextRotation = PdfAddTextRot0,
  outline? : Bool = false,
  line_width? : Double = 1.0,
  underneath? : Bool = false,
  fast? : Bool = false,
  raw? : Bool = false,
  url_border? : Bool = false,
) -> PdfPage raise PdfError {
  let effective_fontname = self.pdf_addtext_effective_fontname(
    page, font, fontpack, fontname,
  )
  let prepared = self.addtext_prepare_line(
    page,
    time,
    lines,
    replacements,
    font,
    fontpack,
    effective_fontname,
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
  let setup = self.addtext_resource_setup(
    page, font, fontpack, effective_fontname, font_object, fontpack_font_objects,
    opacity,
  )
  let ops = pdf_addtext_text_ops_with_bytes(
    fontpack,
    prepared.placement.origin.x + shift_x,
    prepared.placement.origin.y + shift_y,
    prepared.placement.base_rotation,
    prepared.placement.horizontal_offset,
    prepared.placement.vertical_offset,
    outline,
    line_width,
    setup.unique_fontname,
    setup.unique_fontnames,
    setup.extgstate_name,
    colour,
    font_size,
    prepared.text,
    prepared.text_bytes,
    prepared.placement.text_rotation,
    prepared.placement.rotation_offset.x,
    prepared.placement.rotation_offset.y,
  )
  let annotations = self.addtext_url_annotation_references(
    prepared.text,
    prepared.urls,
    fn(prefix) raise PdfError {
      let bytes = self.pdf_addtext_measurement_bytes_for_page(
        page, font, fontpack, effective_fontname, raw, prefix,
      )
      self.addtext_calc_textwidth(
        page, font, fontpack, effective_fontname, font_size, bytes,
      )
    },
    prepared.placement.origin,
    prepared.placement.horizontal_offset,
    prepared.placement.vertical_offset,
    prepared.placement.justification_offset,
    prepared.placement.text_rotation,
    prepared.placement.rotation_offset,
    prepared.placement.base_rotation,
    font,
    pdf_addtext_height_font_name(effective_fontname),
    font_size,
    url_border,
  )
  let page = {
    ..page,
    resources: setup.resources,
    rest: self.addtext_page_rest_with_annotations(page.rest, annotations),
  }
  if underneath {
    self.prepend_operators(page, ops, fast~)
  } else {
    self.postpend_operators(page, ops, fast~)
  }
}

///|
/// Compatibility wrapper for `PdfDocument::addtext_line_page`.
pub fn pdf_addtext_line_page(
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
  text : String,
  colour : PdfContentColour,
  position : PdfPosition,
  relative_to_box? : PdfName = pdf_page_mediabox_key(),
  horizontal_offset? : Double = 0.0,
  vertical_offset? : Double = 0.0,
  shift_x? : Double = 0.0,
  shift_y? : Double = 0.0,
  opacity? : Double = 1.0,
  justification? : PdfAddTextJustification = PdfAddTextLeftJustify,
  rotation? : PdfAddTextRotation = PdfAddTextRot0,
  outline? : Bool = false,
  line_width? : Double = 1.0,
  underneath? : Bool = false,
  fast? : Bool = false,
  raw? : Bool = false,
  url_border? : Bool = false,
) -> PdfPage raise PdfError {
  document.addtext_line_page(
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
    text,
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
}
