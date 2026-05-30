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
  time : @date.PdfStrftimeTime,
  bookmarks : ArrayView[@bookmark.PdfBookmark],
  font : PdfFont?,
  fontpack : PdfFontPack?,
  fontname : PdfName,
  font_object : PdfObject?,
  fontpack_font_objects : ArrayView[Int],
  font_size : Double,
  line_spacing : Double,
  colour : @colour.PdfContentColour,
  position : @geometry.PdfPosition,
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
      "addtext_pages_with_font",
    )
    let shifts = self.parse_coordinates(shift)
    let selected_pages = @core.pdf_number_set(page_numbers)
    let rewritten : Array[@page.PdfPage] = Array::new(capacity=pages.length())
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
  time : @date.PdfStrftimeTime,
  bookmarks : ArrayView[@bookmark.PdfBookmark],
  font : PdfFont?,
  fontpack : PdfFontPack?,
  fontname : PdfName,
  font_object : PdfObject?,
  fontpack_font_objects : ArrayView[Int],
  font_size : Double,
  line_spacing : Double,
  colour : @colour.PdfContentColour,
  position : @geometry.PdfPosition,
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
