///|
fn pdf_toc_original_page_changes(
  original_page_count : Int,
  toc_page_count : Int,
) -> Array[(Int, Int)] {
  [
    for index in 0..<original_page_count => {
      (index + 1, index + 1 + toc_page_count)
    }
  ]
}

///|
fn pdf_toc_prepend_pages(
  toc_pages : ArrayView[@page.PdfPage],
  original_pages : ArrayView[@page.PdfPage],
) -> Array[@page.PdfPage] {
  let output : Array[@page.PdfPage] = []
  for page in toc_pages {
    output.push(page)
  }
  for page in original_pages {
    output.push(page)
  }
  output
}

///|
/// Shift existing page-label ranges after prepended TOC pages.
///
/// cpdftoc writes a no-label range for the inserted TOC pages, then preserves
/// existing labels by moving their start pages forward by the TOC page count.
pub fn pdf_toc_shift_page_labels(
  toc_page_count : Int,
  labels : ArrayView[@label.PdfPageLabel],
) -> Array[@label.PdfPageLabel] {
  let output : Array[@label.PdfPageLabel] = [
    {
      label_style: PageLabelNoLabelPrefixOnly,
      label_prefix: None,
      start_page: 1,
      start_value: 1,
    },
  ]
  for label in labels {
    output.push({ ..label, start_page: label.start_page + toc_page_count })
  }
  output
}

///|
/// Prepend already-typeset TOC pages and shift existing page labels.
///
/// Page references in destinations, annotations, open actions, and bookmarks
/// are rewritten from original one-based page serials to their new serials
/// after the inserted TOC pages.
pub fn PdfDocument::toc_insert_pages(
  self : PdfDocument,
  toc_pages : ArrayView[@page.PdfPage],
  labels : ArrayView[@label.PdfPageLabel],
) -> PdfDocument raise PdfError {
  let original_pages = self.pages_of_pagetree()
  let toc_page_count = toc_pages.length()
  let pages = pdf_toc_prepend_pages(toc_pages, original_pages)
  let inserted = self.change_pages(
    pages,
    change_references=true,
    changes=pdf_toc_original_page_changes(
      original_pages.length(),
      toc_page_count,
    ),
  )
  inserted.write_page_labels(pdf_toc_shift_page_labels(toc_page_count, labels))
}

///|
/// Compatibility wrapper for `PdfDocument::toc_insert_pages`.
pub fn pdf_toc_insert_pages(
  document : PdfDocument,
  toc_pages : ArrayView[@page.PdfPage],
  labels : ArrayView[@label.PdfPageLabel],
) -> PdfDocument raise PdfError {
  document.toc_insert_pages(toc_pages, labels)
}
