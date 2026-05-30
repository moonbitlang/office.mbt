///|
fn pdf_addtext_roman_upper(number : Int) -> String {
  @ascii.decode_lossy(@label.pdf_page_label_roman_upper(number))
}

///|
fn pdf_addtext_roman_lower(number : Int) -> String {
  @ascii.decode_lossy(
    @label.pdf_page_label_lowercase(@label.pdf_page_label_roman_upper(number)),
  )
}

///|
/// Format cpdf add-text's `%Bates` replacement for one page.
pub fn pdf_addtext_bates_number(
  bates : Int,
  page_number : Int,
  bates_pad : Int?,
) -> String {
  let number_text = (bates + page_number - 1).to_string()
  match bates_pad {
    None => number_text
    Some(width) =>
      if number_text.length() >= width {
        number_text
      } else {
        let mut output = number_text
        for _ in 0..<(width - number_text.length()) {
          output = "0" + output
        }
        output
      }
  }
}

///|
fn pdf_addtext_bookmark_replacement(
  values : @addtext.PdfAddTextReplacementValues,
  level : Int,
) -> String {
  if level >= 0 && level < values.bookmarks.length() {
    values.bookmarks[level]
  } else {
    ""
  }
}

///|
/// Build cpdf add-text replacement callbacks for page-local fields.
///
/// Page labels and bookmark strings are supplied by the caller; this helper
/// preserves cpdf's marker names and Bates/roman/page-number formatting.
pub fn pdf_addtext_replacement_pairs(
  values : @addtext.PdfAddTextReplacementValues,
) -> Array[(String, () -> String)] {
  [
    ("%PageDiv2", fn() { ((values.page_number + 1) / 2).to_string() }),
    ("%Page", fn() { values.page_number.to_string() }),
    ("%Roman", fn() { pdf_addtext_roman_upper(values.page_number) }),
    ("%roman", fn() { pdf_addtext_roman_lower(values.page_number) }),
    ("%filename", fn() { values.filename }),
    ("%Label", fn() { values.page_label }),
    ("%EndPage", fn() { values.end_page.to_string() }),
    ("%EndLabel", fn() { values.end_label }),
    ("%Bookmark0", fn() { pdf_addtext_bookmark_replacement(values, 0) }),
    ("%Bookmark1", fn() { pdf_addtext_bookmark_replacement(values, 1) }),
    ("%Bookmark2", fn() { pdf_addtext_bookmark_replacement(values, 2) }),
    ("%Bookmark3", fn() { pdf_addtext_bookmark_replacement(values, 3) }),
    ("%Bookmark4", fn() { pdf_addtext_bookmark_replacement(values, 4) }),
    (
      "%Bates",
      fn() {
        pdf_addtext_bates_number(
          values.bates,
          values.page_number,
          values.bates_pad,
        )
      },
    ),
  ]
}

///|
fn pdf_addtext_pdfdocstring_to_string(
  bytes : BytesView,
) -> String raise PdfError {
  @utf8.decode(pdf_utf8_of_pdfdocstring(bytes)) catch {
    _ => raise InvalidUTF8
  }
}

///|
fn pdf_addtext_page_label_prefix(label : PdfPageLabel) -> String raise PdfError {
  match label.label_prefix {
    Some(prefix) => pdf_addtext_pdfdocstring_to_string(prefix)
    None => ""
  }
}

///|
fn pdf_addtext_page_label_number(label : PdfPageLabel) -> String {
  @ascii.decode_lossy(
    @label.pdf_page_label_number_bytes(label.start_value, label.label_style),
  )
}

///|
/// Return cpdf add-text's visible page label for a 1-based page number.
///
/// Documents without page labels fall back to decimal page numbers.
pub fn PdfDocument::addtext_page_label(
  self : PdfDocument,
  page_number : Int,
) -> String raise PdfError {
  let labels = pdf_page_label_complete(self.read_page_labels())
  match pdf_page_label_of_page_number(page_number, labels) {
    Some(label) =>
      pdf_addtext_page_label_prefix(label) +
      pdf_addtext_page_label_number(label)
    None => page_number.to_string()
  }
}

///|
/// Compatibility wrapper for `PdfDocument::addtext_page_label`.
pub fn pdf_addtext_page_label(
  document : PdfDocument,
  page_number : Int,
) -> String raise PdfError {
  document.addtext_page_label(page_number)
}

///|
fn pdf_addtext_bookmark_text(bookmark : PdfBookmark) -> String raise PdfError {
  pdf_addtext_pdfdocstring_to_string(bookmark.text)
}

///|
/// Return cpdf add-text's current bookmark text at `level` for `page_number`.
///
/// The search is constrained to the current bookmark branch so section
/// bookmarks from a previous chapter do not leak into a later chapter.
pub fn PdfDocument::addtext_bookmark_for_page(
  self : PdfDocument,
  bookmarks : ArrayView[PdfBookmark],
  level : Int,
  page_number : Int,
) -> String raise PdfError {
  let before : Array[PdfBookmark] = Array::new(capacity=bookmarks.length())
  for bookmark in bookmarks {
    if self.page_number_of_target(bookmark.target) <= page_number {
      before.push(bookmark)
    } else {
      break
    }
  }
  let branch : Array[PdfBookmark] = Array::new(capacity=before.length())
  let mut before_index = before.length()
  while before_index > 0 {
    before_index -= 1
    let bookmark = before[before_index]
    if bookmark.level >= level {
      branch.push(bookmark)
    } else {
      break
    }
  }
  let pickfrom : Array[PdfBookmark] = Array::new(capacity=branch.length())
  let mut branch_index = branch.length()
  while branch_index > 0 {
    branch_index -= 1
    let bookmark = branch[branch_index]
    if bookmark.level == level {
      pickfrom.push(bookmark)
    }
  }
  let mut fallback : PdfBookmark? = None
  for bookmark in pickfrom {
    if self.page_number_of_target(bookmark.target) == page_number {
      return pdf_addtext_bookmark_text(bookmark)
    }
    fallback = Some(bookmark)
  }
  match fallback {
    Some(bookmark) => pdf_addtext_bookmark_text(bookmark)
    None => ""
  }
}

///|
/// Compatibility wrapper for `PdfDocument::addtext_bookmark_for_page`.
pub fn pdf_addtext_bookmark_for_page(
  document : PdfDocument,
  bookmarks : ArrayView[PdfBookmark],
  level : Int,
  page_number : Int,
) -> String raise PdfError {
  document.addtext_bookmark_for_page(bookmarks, level, page_number)
}

///|
/// Build cpdf add-text replacement values from document-local state.
pub fn PdfDocument::addtext_replacement_values(
  self : PdfDocument,
  bookmarks : ArrayView[PdfBookmark],
  page_number : Int,
  end_page : Int,
  filename : String,
  bates : Int,
  bates_pad : Int?,
) -> @addtext.PdfAddTextReplacementValues raise PdfError {
  let bookmark_values : Array[String] = Array::new(capacity=5)
  for level in 0..<5 {
    bookmark_values.push(
      self.addtext_bookmark_for_page(bookmarks, level, page_number),
    )
  }
  {
    page_number,
    end_page,
    filename,
    page_label: self.addtext_page_label(page_number),
    end_label: self.addtext_page_label(end_page),
    bates,
    bates_pad,
    bookmarks: bookmark_values,
  }
}

///|
/// Compatibility wrapper for `PdfDocument::addtext_replacement_values`.
pub fn pdf_addtext_replacement_values(
  document : PdfDocument,
  bookmarks : ArrayView[PdfBookmark],
  page_number : Int,
  end_page : Int,
  filename : String,
  bates : Int,
  bates_pad : Int?,
) -> @addtext.PdfAddTextReplacementValues raise PdfError {
  document.addtext_replacement_values(
    bookmarks, page_number, end_page, filename, bates, bates_pad,
  )
}

///|
/// Source-spelled compatibility wrapper matching cpdfaddtext's `replace_pairs`.
///
/// The OCaml API receives precomputed page-reference lookup state and the page
/// record; this wrapper derives the same page-local values from `document`.
pub fn pdf_replace_pairs(
  bookmarks : ArrayView[PdfBookmark],
  document : PdfDocument,
  end_page : Int,
  filename : String,
  bates : Int,
  bates_pad : Int?,
  page_number : Int,
) -> Array[(String, () -> String)] raise PdfError {
  let values = document.addtext_replacement_values(
    bookmarks, page_number, end_page, filename, bates, bates_pad,
  )
  pdf_addtext_replacement_pairs(values)
}
