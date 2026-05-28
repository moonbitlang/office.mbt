///|
fn PdfDocument::pdf_page_content_references(
  self : PdfDocument,
  content : ArrayView[PdfObject],
) -> Array[PdfObject] {
  let refs : Array[PdfObject] = Array::new(capacity=content.length())
  for object in content {
    match object {
      PdfIndirect(_) => refs.push(object)
      _ => refs.push(PdfIndirect(self.add_object(object)))
    }
  }
  refs
}

///|
fn PdfDocument::pdf_page_object(
  self : PdfDocument,
  page : PdfPage,
  parent : Int,
) -> PdfObject raise PdfError {
  let rest_entries = pdf_page_rest_entries(page.rest)
  let entries : Array[(PdfName, PdfObject)] = Array::new(
    capacity=6 + rest_entries.length(),
  )
  entries.push((pdf_page_type_key(), PdfNameObject(pdf_page_type_page())))
  entries.push((pdf_page_parent_key(), PdfIndirect(parent)))
  entries.push((pdf_page_resources_key(), page.resources))
  entries.push((pdf_page_mediabox_key(), page.mediabox))
  match pdf_page_int_of_rotation(page.rotate) {
    0 => ()
    value => entries.push((pdf_page_rotate_key(), PdfInteger(value)))
  }
  let content_refs = self.pdf_page_content_references(page.content)
  if content_refs.length() > 0 {
    entries.push((pdf_page_contents_key(), PdfArray(content_refs)))
  }
  for entry in rest_entries {
    entries.push(entry)
  }
  PdfDictionary(entries)
}

///|
fn pdf_page_slice(
  pages : ArrayView[PdfPage],
  start : Int,
  stop : Int,
) -> Array[PdfPage] {
  let output : Array[PdfPage] = Array::new(capacity=stop - start)
  for i in start..<stop {
    output.push(pages[i])
  }
  output
}

///|
fn pdf_page_pages_node_object(
  kids : ArrayView[Int],
  count : Int,
  parent : Int,
) -> PdfObject {
  let kid_refs : Array[PdfObject] = Array::new(capacity=kids.length())
  for number in kids {
    kid_refs.push(PdfIndirect(number))
  }
  let entries : Array[(PdfName, PdfObject)] = Array::new(
    capacity=if parent == 0 { 3 } else { 4 },
  )
  entries.push((pdf_page_type_key(), PdfNameObject(pdf_page_type_pages())))
  entries.push((pdf_page_kids_key(), PdfArray(kid_refs)))
  entries.push((pdf_page_count_key(), PdfInteger(count)))
  if parent != 0 {
    entries.push((pdf_page_parent_key(), PdfIndirect(parent)))
  }
  PdfDictionary(entries)
}

///|
fn PdfDocument::pdf_page_add_pagetree_node(
  self : PdfDocument,
  pages : ArrayView[PdfPage],
  parent : Int,
  node_number : Int,
) -> Unit raise PdfError {
  if pages.length() < 10 {
    let page_numbers : Array[Int] = Array::new(capacity=pages.length())
    for page in pages {
      page_numbers.push(
        self.add_object(self.pdf_page_object(page, node_number)),
      )
    }
    self.add_object_given_number(
      node_number,
      pdf_page_pages_node_object(page_numbers, pages.length(), parent),
    )
  } else {
    let middle_count = 5
    let left_count = (pages.length() - middle_count) / 2
    let middle_end = left_count + middle_count
    let left_number = self.add_object(PdfNull)
    self.pdf_page_add_pagetree_node(
      pdf_page_slice(pages, 0, left_count),
      node_number,
      left_number,
    )
    let kid_numbers : Array[Int] = Array::new(capacity=middle_count + 2)
    kid_numbers.push(left_number)
    for i in left_count..<middle_end {
      kid_numbers.push(
        self.add_object(self.pdf_page_object(pages[i], node_number)),
      )
    }
    let right_number = self.add_object(PdfNull)
    self.pdf_page_add_pagetree_node(
      pdf_page_slice(pages, middle_end, pages.length()),
      node_number,
      right_number,
    )
    kid_numbers.push(right_number)
    self.add_object_given_number(
      node_number,
      pdf_page_pages_node_object(kid_numbers, pages.length(), parent),
    )
  }
}

///|
/// Add a balanced page tree for `pages` and return its root object number.
///
/// Page content objects that are not already indirect are inserted into the
/// document. The document is mutated in place.
pub fn PdfDocument::add_pagetree(
  self : PdfDocument,
  pages : ArrayView[PdfPage],
) -> Int raise PdfError {
  let page_root_number = self.add_object(PdfNull)
  self.pdf_page_add_pagetree_node(pages, 0, page_root_number)
  page_root_number
}

///|
/// Copy a document, add a page tree, and return the copy with the tree root.
pub fn pdf_add_pagetree(
  pages : ArrayView[PdfPage],
  document : PdfDocument,
) -> (PdfDocument, Int) raise PdfError {
  let pdf = document.copy()
  let page_root_number = pdf.add_pagetree(pages)
  (pdf, page_root_number)
}
