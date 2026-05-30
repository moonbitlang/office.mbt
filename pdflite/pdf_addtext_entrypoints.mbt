///|
fn pdf_addtext_append_unique_codepoints(
  used : Array[Int],
  codepoints : ArrayView[Int],
) -> Unit {
  for codepoint in codepoints {
    if !pdf_addtext_codepoints_contains(used, codepoint) {
      used.push(codepoint)
    }
  }
}

///|
fn PdfDocument::pdf_addtext_used_codepoints_for_pages(
  self : PdfDocument,
  pages : ArrayView[PdfPage],
  page_numbers : ArrayView[Int],
  lines : ArrayView[String],
  time : PdfStrftimeTime,
  bookmarks : ArrayView[PdfBookmark],
  filename : String,
  bates : Int,
  bates_pad : Int?,
) -> Array[Int] raise PdfError {
  let used : Array[Int] = Array::new(
    capacity=page_numbers.length() * lines.length(),
  )
  for page_number in page_numbers {
    let values = self.addtext_replacement_values(
      bookmarks,
      page_number,
      pages.length(),
      filename,
      bates,
      bates_pad,
    )
    let replacement_pairs = pdf_addtext_replacement_pairs(values)
    let expanded = pdf_addtext_expand_lines_with_time(
      time, lines, replacement_pairs,
    )
    pdf_addtext_append_unique_codepoints(
      used,
      pdf_addtext_used_codepoints(expanded),
    )
  }
  used
}

///|
fn PdfDocument::pdf_addtext_write_fontpack_objects(
  self : PdfDocument,
  fontpack : PdfFontPack?,
) -> Array[Int] raise PdfError {
  let objects : Array[Int] = match fontpack {
    Some(pack) => Array::new(capacity=pack.fonts.length())
    None => []
  }
  match fontpack {
    Some(fontpack) =>
      for font in fontpack.fonts {
        objects.push(self.write_font(font))
      }
    None => ()
  }
  objects
}

///|
/// Add cpdf add-text to selected pages with deterministic time and resolved fonts.
///
/// This ports the outer source-level `addtexts` orchestration once callers have
/// already chosen an existing font, parsed font, or font pack. It prepares the
/// input text lines, skips empty visible output before writing fonts, writes
/// selected/fontpack font objects, and delegates page rewriting to
/// `addtext_pages_with_font`.
pub fn PdfDocument::addtexts_with_font(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  text : String,
  time : PdfStrftimeTime,
  bookmarks : ArrayView[PdfBookmark],
  font : PdfFont?,
  fontpack : PdfFontPack?,
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
      "addtexts_with_font",
    )
    let lines = pdf_addtext_lines_for_rotation(text, rotation)
    let used = self.pdf_addtext_used_codepoints_for_pages(
      pages, page_numbers, lines, time, bookmarks, filename, bates, bates_pad,
    )
    if used.length() == 0 {
      self
    } else {
      let font_object = match fontpack {
        Some(_) => None
        None => self.addtext_selected_font_object(font)
      }
      let fontpack_font_objects = self.pdf_addtext_write_fontpack_objects(
        fontpack,
      )
      self.addtext_pages_with_font(
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
  }
}

///|
/// Compatibility wrapper for `PdfDocument::addtexts_with_font`.
pub fn pdf_addtexts_with_font(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
  text : String,
  time : PdfStrftimeTime,
  bookmarks : ArrayView[PdfBookmark],
  font : PdfFont?,
  fontpack : PdfFontPack?,
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
  document.addtexts_with_font(
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
