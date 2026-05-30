///|
fn pdf_addtext_resolve_font_source(
  source : PdfAddTextFontSource,
) -> (PdfFont?, PdfFontPack?) raise PdfError {
  match source {
    PdfAddTextPreMadeFontPack(pack) =>
      if pack.fonts.length() == 0 {
        raise SoftError("addtexts: fontpack is empty")
      } else {
        (Some(pack.fonts[0]), None)
      }
    PdfAddTextExistingNamedFont => (None, None)
  }
}

///|
/// Add cpdf add-text to selected pages from a non-embedding font source.
pub fn PdfDocument::addtexts_with_source(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  text : String,
  time : PdfStrftimeTime,
  bookmarks : ArrayView[PdfBookmark],
  font_source : PdfAddTextFontSource,
  fontname : PdfName,
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
  justification? : @addtext.PdfAddTextJustification = PdfAddTextLeftJustify,
  rotation? : @addtext.PdfAddTextRotation = PdfAddTextRot0,
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
      "addtexts_with_source",
    )
    let lines = pdf_addtext_lines_for_rotation(text, rotation)
    let used = self.pdf_addtext_used_codepoints_for_pages(
      pages, page_numbers, lines, time, bookmarks, filename, bates, bates_pad,
    )
    if used.length() == 0 {
      self
    } else {
      let (font, fontpack) = pdf_addtext_resolve_font_source(font_source)
      self.addtexts_with_font(
        page_numbers,
        text,
        time,
        bookmarks,
        font,
        fontpack,
        fontname,
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
  }
}

///|
/// Compatibility wrapper for `PdfDocument::addtexts_with_source`.
pub fn pdf_addtexts_with_source(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
  text : String,
  time : PdfStrftimeTime,
  bookmarks : ArrayView[PdfBookmark],
  font_source : PdfAddTextFontSource,
  fontname : PdfName,
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
  justification? : @addtext.PdfAddTextJustification = PdfAddTextLeftJustify,
  rotation? : @addtext.PdfAddTextRotation = PdfAddTextRot0,
  midline? : Bool = false,
  topline? : Bool = false,
  outline? : Bool = false,
  line_width? : Double = 1.0,
  underneath? : Bool = false,
  fast? : Bool = false,
  raw? : Bool = false,
  url_border? : Bool = false,
) -> PdfDocument raise PdfError {
  document.addtexts_with_source(
    page_numbers,
    text,
    time,
    bookmarks,
    font_source,
    fontname,
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
