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
  let (initial_h_offset, initial_v_offset) = pdf_addtext_initial_line_offsets(
    position,
    lines.length(),
    line_spacing,
    font_size,
  )
  let (baseline_h_offset, baseline_v_offset) = pdf_addtext_baseline_offsets(
    font, font_size, position, rotation, midline, topline,
  )
  let advance = pdf_addtext_line_advance(rotation, line_spacing, font_size)
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

///|
/// Add cpdf add-text lines to selected pages with an already resolved font.
///
/// This ports the document/page-selection layer after font selection: selected
/// one-based pages get page-local replacement callbacks, cpdf shift-coordinate
/// parsing, and page-line emission. Font embedding and existing-font discovery
/// remain separate slices.
pub fn PdfDocument::addtext_pages_with_font(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  lines : ArrayView[String],
  time : PdfStrftimeTime,
  bookmarks : ArrayView[PdfBookmark],
  font : PdfFont?,
  fontpack : PdfFontPack?,
  fontname : PdfName,
  font_object : PdfObject?,
  fontpack_font_objects : ArrayView[Int],
  font_size : Double,
  line_spacing : Double,
  colour : PdfContentColour,
  position : PdfPosition,
  filename? : String = "",
  bates? : Int = 1,
  bates_pad? : Int? = None,
  relative_to_box? : PdfName = pdf_page_mediabox_key(),
  shift? : String = "0 0",
  opacity? : Double = 1.0,
  justification? : PdfAddTextJustification = PdfAddTextLeftJustify,
  rotation? : PdfAddTextRotation = PdfAddTextRot0,
  midline? : Bool = false,
  topline? : Bool = false,
  outline? : Bool = false,
  line_width? : Double = 1.0,
  underneath? : Bool = false,
  fast? : Bool = false,
  raw? : Bool = false,
  url_border? : Bool = false,
) -> PdfDocument raise PdfError {
  if page_numbers.length() == 0 {
    self
  } else {
    let pages = self.pages_of_pagetree()
    pdf_addtext_validate_page_numbers(
      page_numbers,
      pages.length(),
      "addtext_pages_with_font",
    )
    let shifts = self.parse_coordinates(shift)
    let selected_pages = @number_set.pdf_number_set(page_numbers)
    let rewritten : Array[PdfPage] = Array::new(capacity=pages.length())
    for index in 0..<pages.length() {
      let page_number = index + 1
      let page = pages[index]
      if selected_pages.contains(page_number) {
        let values = self.addtext_replacement_values(
          bookmarks,
          page_number,
          pages.length(),
          filename,
          bates,
          bates_pad,
        )
        let replacement_pairs = pdf_addtext_replacement_pairs(values)
        rewritten.push(
          self.addtext_page_lines(
            page,
            time,
            lines,
            replacement_pairs,
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
            shift_x=shifts[index].x,
            shift_y=shifts[index].y,
            outline~,
            line_width~,
            underneath~,
            fast~,
            raw~,
            url_border~,
          ),
        )
      } else {
        rewritten.push(page)
      }
    }
    self.change_pages(rewritten, change_references=true)
  }
}

///|
/// Compatibility wrapper for `PdfDocument::addtext_pages_with_font`.
pub fn pdf_addtext_pages_with_font(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
  lines : ArrayView[String],
  time : PdfStrftimeTime,
  bookmarks : ArrayView[PdfBookmark],
  font : PdfFont?,
  fontpack : PdfFontPack?,
  fontname : PdfName,
  font_object : PdfObject?,
  fontpack_font_objects : ArrayView[Int],
  font_size : Double,
  line_spacing : Double,
  colour : PdfContentColour,
  position : PdfPosition,
  filename? : String = "",
  bates? : Int = 1,
  bates_pad? : Int? = None,
  relative_to_box? : PdfName = pdf_page_mediabox_key(),
  shift? : String = "0 0",
  opacity? : Double = 1.0,
  justification? : PdfAddTextJustification = PdfAddTextLeftJustify,
  rotation? : PdfAddTextRotation = PdfAddTextRot0,
  midline? : Bool = false,
  topline? : Bool = false,
  outline? : Bool = false,
  line_width? : Double = 1.0,
  underneath? : Bool = false,
  fast? : Bool = false,
  raw? : Bool = false,
  url_border? : Bool = false,
) -> PdfDocument raise PdfError {
  document.addtext_pages_with_font(
    page_numbers,
    lines,
    time,
    bookmarks,
    font,
    fontpack,
    fontname,
    font_object,
    fontpack_font_objects,
    font_size,
    line_spacing,
    colour,
    position,
    filename~,
    bates~,
    bates_pad~,
    relative_to_box~,
    shift~,
    opacity~,
    justification~,
    rotation~,
    midline~,
    topline~,
    outline~,
    line_width~,
    underneath~,
    fast~,
    raw~,
    url_border~,
  )
}
