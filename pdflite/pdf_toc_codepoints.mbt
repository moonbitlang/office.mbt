///|
/// Convert UTF-8 text into the font/text runs used by cpdftoc.
///
/// Unrepresentable codepoints are skipped, matching cpdf's `option_map
/// (Cpdfembed.get_char fontpack)` behavior. Unlike the text-to-PDF paragraph
/// helper, this function treats input as a single run and does not interpret
/// newline characters.
pub fn pdf_toc_of_utf8(
  fontpack : PdfFontPack,
  font_size : Double,
  text : BytesView,
) -> Array[PdfTypeElement] raise PdfError {
  let mapped : Array[(Int, Int, PdfFont)] = []
  for codepoint in pdf_codepoints_of_utf8(text) {
    match fontpack.get_char(codepoint) {
      Some(run) => mapped.push(run)
      None => ()
    }
  }
  let output : Array[PdfTypeElement] = []
  pdf_toc_push_font_text_runs(output, mapped, font_size)
  output
}

///|
fn pdf_toc_codepoints_contains(
  codepoints : ArrayView[Int],
  codepoint : Int,
) -> Bool {
  for current in codepoints {
    if current == codepoint {
      return true
    }
  }
  false
}

///|
fn pdf_toc_append_unique_codepoints(
  output : Array[Int],
  codepoints : ArrayView[Int],
) -> Unit {
  for codepoint in codepoints {
    if !pdf_toc_codepoints_contains(output, codepoint) {
      output.push(codepoint)
    }
  }
}

///|
fn pdf_toc_append_utf8_codepoints(
  output : Array[Int],
  text : BytesView,
) -> Unit raise PdfError {
  pdf_toc_append_unique_codepoints(output, pdf_codepoints_of_utf8(text))
}

///|
fn pdf_toc_append_pdfdocstring_codepoints(
  output : Array[Int],
  text : BytesView,
) -> Unit raise PdfError {
  pdf_toc_append_utf8_codepoints(output, pdf_utf8_of_pdfdocstring(text))
}

///|
fn pdf_toc_page_label_text(
  page_number : Int,
  labels : ArrayView[@label.PdfPageLabel],
) -> PdfBytes {
  if page_number < 1 {
    pdf_toc_ascii(page_number.to_string())
  } else {
    match @label.pdf_page_label_text_of_page_number(page_number, labels) {
      Some(label) => label
      None => pdf_toc_ascii(page_number.to_string())
    }
  }
}

///|
/// Return the unique Unicode codepoints cpdftoc needs before embedding a font.
///
/// The scan includes the dot used by ellipses/leaders, the TOC title, bookmark
/// titles, and the visible page-label text for each bookmark target. The
/// returned order is first occurrence for deterministic callers and tests.
pub fn PdfDocument::toc_used_codepoints(
  self : PdfDocument,
  labels : ArrayView[@label.PdfPageLabel],
  title : BytesView,
  bookmarks : ArrayView[@bookmark.PdfBookmark],
) -> Array[Int] raise PdfError {
  let used : Array[Int] = [46]
  pdf_toc_append_utf8_codepoints(used, title)
  for bookmark in bookmarks {
    pdf_toc_append_pdfdocstring_codepoints(used, bookmark.text)
    let page_number = self.page_number_of_target(bookmark.target)
    pdf_toc_append_pdfdocstring_codepoints(
      used,
      pdf_toc_page_label_text(page_number, labels),
    )
  }
  used
}

///|
/// Compatibility wrapper for `PdfDocument::toc_used_codepoints`.
pub fn pdf_toc_used_codepoints(
  document : PdfDocument,
  labels : ArrayView[@label.PdfPageLabel],
  title : BytesView,
  bookmarks : ArrayView[@bookmark.PdfBookmark],
) -> Array[Int] raise PdfError {
  document.toc_used_codepoints(labels, title, bookmarks)
}

///|
/// Convert PDFDocEncoding/PDFDocString bytes into the font/text runs used by
/// cpdftoc.
pub fn pdf_toc_of_pdfdocencoding(
  fontpack : PdfFontPack,
  font_size : Double,
  text : BytesView,
) -> Array[PdfTypeElement] raise PdfError {
  pdf_toc_of_utf8(fontpack, font_size, pdf_utf8_of_pdfdocstring(text))
}
