///|
fn PdfDocument::pdf_page_redact_page(
  self : PdfDocument,
  page : PdfPage,
) -> PdfPage raise PdfError {
  ignore(self)
  {
    ..page,
    content: [],
    resources: PdfDictionary([]),
    rest: page.rest.remove_dict_entry(pdf_page_annots_key()),
  }
}

///|
/// Redact whole selected pages by emptying their visible content.
///
/// This ports cpdfpage's `redact`: selected pages keep their page geometry and
/// rotation, but page content, resources, and `/Annots` are removed. When
/// `process_struct_tree` is true, structure entries for the redacted pages are
/// trimmed.
pub fn PdfDocument::redact_pages(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  process_struct_tree? : Bool = false,
) -> PdfDocument raise PdfError {
  let pages = self.pages_of_pagetree()
  pdf_page_box_validate_page_numbers(
    page_numbers,
    pages.length(),
    "redact_pages",
  )
  let selected_pages = @core.pdf_number_set(page_numbers)
  let rewritten : Array[PdfPage] = Array::new(capacity=pages.length())
  for index, page in pages {
    let page_number = index + 1
    if selected_pages.contains(page_number) {
      rewritten.push(self.pdf_page_redact_page(page))
    } else {
      rewritten.push(page)
    }
  }
  let redacted = self.change_pages(rewritten, change_references=true)
  if process_struct_tree {
    redacted.trim_structure_tree(
      @spec.pdf_invert_page_range(pages.length(), page_numbers),
    )
  }
  redacted
}

///|
/// Compatibility wrapper for `PdfDocument::redact_pages`.
pub fn pdf_redact_pages(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
  process_struct_tree? : Bool = false,
) -> PdfDocument raise PdfError {
  document.redact_pages(page_numbers, process_struct_tree~)
}

///|
/// Compatibility wrapper matching cpdfpage's `redact` argument order.
pub fn pdf_redact_pages_cpdf_order(
  process_struct_tree : Bool,
  document : PdfDocument,
  page_numbers : ArrayView[Int],
) -> PdfDocument raise PdfError {
  document.redact_pages(page_numbers, process_struct_tree~)
}
