///|
/// Collapse adjacent page-label ranges that produce the same numbering stream.
///
/// Ranges are merged only when their style, prefix, and `start_page -
/// start_value` offset are identical, so visible labels for every page remain
/// unchanged.
pub fn pdf_page_label_coalesce(
  labels : ArrayView[@label.PdfPageLabel],
) -> Array[@label.PdfPageLabel] {
  let output : Array[@label.PdfPageLabel] = Array::new(capacity=labels.length())
  let mut index = 0
  while index < labels.length() {
    let label = labels[index]
    output.push(label)
    index += 1
    while index < labels.length() &&
          labels[index].label_style == label.label_style &&
          labels[index].label_prefix == label.label_prefix &&
          labels[index].start_page - labels[index].start_value ==
          label.start_page - label.start_value {
      index += 1
    }
  }
  output
}

///|
/// Merge page labels for selected pages from several source documents.
///
/// `ranges` contains 1-based source page numbers for each document. The merged
/// result preserves the visible labels from those source pages at their new
/// concatenated positions and coalesces adjacent equivalent ranges.
///
/// Raises if the document and range arrays have different lengths, or if a
/// source document's page-label tree cannot be read.
pub fn pdf_page_label_merge(
  pdfs : ArrayView[PdfDocument],
  ranges : ArrayView[Array[Int]],
) -> Array[@label.PdfPageLabel] raise PdfError {
  if pdfs.length() != ranges.length() {
    raise PageTreeExpected
  }
  let mut total_pages = 0
  for range in ranges {
    total_pages += range.length()
  }
  let labels : Array[@label.PdfPageLabel] = Array::new(capacity=total_pages)
  let mut merged_page = 1
  for index in 0..<pdfs.length() {
    let source_labels = @label.pdf_page_label_complete(
      pdfs[index].read_page_labels(),
    )
    for page_number in ranges[index] {
      let label = @label.pdf_page_label_of_page_number(
        page_number, source_labels,
      ).unwrap()
      labels.push({ ..label, start_page: merged_page })
      merged_page += 1
    }
  }
  pdf_page_label_coalesce(labels)
}
