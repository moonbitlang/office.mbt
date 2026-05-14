///|
fn pdf_page_reference_numbers_inner(
  pdf : PdfDocument,
  pages_node : PdfObject,
  node_number : Int,
  depth : Int,
) -> Array[Int] raise PdfError {
  if depth > 10000 {
    raise PageTreeExpected
  }
  match pdf.lookup_direct(pdf_page_type_key(), pages_node) {
    Some(PdfNameObject(name)) if name == pdf_page_type_page() => [node_number]
    _ =>
      match pdf.lookup_direct(pdf_page_kids_key(), pages_node) {
        Some(PdfArray(kids)) => {
          let output : Array[Int] = []
          for kid in kids {
            match kid {
              PdfIndirect(number) => {
                let child = pdf.direct(kid)
                if child != PdfNull {
                  for
                    page_number in pdf_page_reference_numbers_inner(
                      pdf,
                      child,
                      number,
                      depth + 1,
                    ) {
                    output.push(page_number)
                  }
                }
              }
              _ => ()
            }
          }
          output
        }
        _ => [node_number]
      }
  }
}

///|
fn PdfDocument::pdf_pages_of_pagetree_quick_node(
  self : PdfDocument,
  node : PdfObject,
  depth : Int,
) -> Int raise PdfError {
  if depth > 10000 {
    raise PageTreeExpected
  }
  if node == PdfNull {
    0
  } else {
    match self.lookup_direct(pdf_page_type_key(), node) {
      Some(PdfNameObject(name)) if name != pdf_page_type_pages() => 1
      _ =>
        match self.lookup_direct(pdf_page_kids_key(), node) {
          Some(PdfArray(kids)) => {
            let mut count = 0
            for kid in kids {
              match kid {
                PdfIndirect(number) => {
                  let child = self.lookup_object_or_null(number)
                  if child == PdfNull {
                    raise PageTreeExpected
                  }
                  count += self.pdf_pages_of_pagetree_quick_node(
                    child,
                    depth + 1,
                  )
                }
                PdfDictionary(_) =>
                  count += self.pdf_pages_of_pagetree_quick_node(kid, depth + 1)
                _ => raise PageTreeExpected
              }
            }
            count
          }
          _ => raise PageTreeExpected
        }
    }
  }
}

///|
fn pdf_page_root_pages_node(pdf : PdfDocument) -> PdfObject raise PdfError {
  let root = match pdf.pdf_page_active_catalog() {
    Some((catalog, _)) => catalog
    None => raise RootExpected
  }
  match pdf.lookup_direct(pdf_page_pages_key(), root) {
    Some(pages) => pages
    None => raise PageTreeExpected
  }
}

///|
/// Return page object numbers in page-tree order.
pub fn PdfDocument::page_reference_numbers(
  self : PdfDocument,
) -> Array[Int] raise PdfError {
  pdf_page_reference_numbers_inner(self, pdf_page_root_pages_node(self), -1, 0)
}

///|
/// Compatibility wrapper for `PdfDocument::page_reference_numbers`.
pub fn pdf_page_reference_numbers(
  document : PdfDocument,
) -> Array[Int] raise PdfError {
  document.page_reference_numbers()
}

///|
/// Count pages by walking the page tree without materializing `PdfPage` records.
pub fn PdfDocument::pages_of_pagetree_quick(
  self : PdfDocument,
) -> Int raise PdfError {
  self.pdf_pages_of_pagetree_quick_node(pdf_page_root_pages_node(self), 0)
}

///|
/// Return the object number for a 1-based page number.
///
/// Out-of-range page numbers return `None`.
pub fn PdfDocument::page_object_number(
  self : PdfDocument,
  page_number : Int,
) -> Int? raise PdfError {
  let references = self.page_reference_numbers()
  if page_number < 1 || page_number > references.length() {
    None
  } else {
    Some(references[page_number - 1])
  }
}

///|
/// Compatibility wrapper for `PdfDocument::page_object_number`.
pub fn pdf_page_object_number(
  document : PdfDocument,
  page_number : Int,
) -> Int? raise PdfError {
  document.page_object_number(page_number)
}

///|
/// Resolve a destination target to a 1-based page number.
pub fn PdfDocument::page_number_of_target(
  self : PdfDocument,
  destination : PdfDestination,
) -> Int raise PdfError {
  self.pdf_destination_page_number(destination, self.page_reference_numbers())
}

///|
/// Compatibility wrapper for `PdfDocument::page_number_of_target`.
pub fn pdf_pagenumber_of_target(
  document : PdfDocument,
  destination : PdfDestination,
) -> Int raise PdfError {
  document.page_number_of_target(destination)
}

///|
/// Build a fit destination for a 1-based page number.
///
/// Out-of-range page numbers return `DestNull`.
pub fn PdfDocument::target_of_page_number(
  self : PdfDocument,
  page_number : Int,
) -> PdfDestination raise PdfError {
  match self.page_object_number(page_number) {
    Some(object_number) => DestFit(TargetPageObject(object_number))
    None => DestNull
  }
}

///|
/// Compatibility wrapper for `PdfDocument::target_of_page_number`.
pub fn pdf_target_of_pagenumber(
  document : PdfDocument,
  page_number : Int,
) -> PdfDestination raise PdfError {
  document.target_of_page_number(page_number)
}

///|
/// Return the number of pages by walking the page tree.
pub fn PdfDocument::endpage(self : PdfDocument) -> Int raise PdfError {
  self.pages_of_pagetree_quick()
}

///|
/// Compatibility wrapper for `PdfDocument::endpage`.
pub fn pdf_endpage(document : PdfDocument) -> Int raise PdfError {
  document.endpage()
}

///|
/// Return the root page-tree `/Count` value without validating child pages.
///
/// Missing or malformed counts return `0`.
pub fn PdfDocument::endpage_fast(self : PdfDocument) -> Int raise PdfError {
  match
    self.lookup_direct(pdf_page_count_key(), pdf_page_root_pages_node(self)) {
    Some(PdfInteger(count)) => count
    _ => 0
  }
}

///|
/// Compatibility wrapper for `PdfDocument::endpage_fast`.
pub fn pdf_endpage_fast(document : PdfDocument) -> Int raise PdfError {
  document.endpage_fast()
}
