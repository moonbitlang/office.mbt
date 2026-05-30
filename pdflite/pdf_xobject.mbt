///|
fn pdf_xobject_name(text : String) -> PdfName {
  pdf_name_of_bytes(@ascii.encode(text))
}

///|
let pdf_xobject_type_key_name : PdfName = pdf_xobject_name("/Type")

///|
fn pdf_xobject_type_key() -> PdfName {
  pdf_xobject_type_key_name
}

///|
let pdf_xobject_xobject_name : PdfName = pdf_xobject_name("/XObject")

///|
fn pdf_xobject_xobject() -> PdfName {
  pdf_xobject_xobject_name
}

///|
let pdf_xobject_subtype_key_name : PdfName = pdf_xobject_name("/Subtype")

///|
fn pdf_xobject_subtype_key() -> PdfName {
  pdf_xobject_subtype_key_name
}

///|
let pdf_xobject_form_name : PdfName = pdf_xobject_name("/Form")

///|
fn pdf_xobject_form() -> PdfName {
  pdf_xobject_form_name
}

///|
let pdf_xobject_bbox_key_name : PdfName = pdf_xobject_name("/BBox")

///|
fn pdf_xobject_bbox_key() -> PdfName {
  pdf_xobject_bbox_key_name
}

///|
let pdf_xobject_matrix_key_name : PdfName = pdf_xobject_name("/Matrix")

///|
fn pdf_xobject_matrix_key() -> PdfName {
  pdf_xobject_matrix_key_name
}

///|
let pdf_xobject_resources_key_name : PdfName = pdf_xobject_name("/Resources")

///|
fn pdf_xobject_resources_key() -> PdfName {
  pdf_xobject_resources_key_name
}

///|
let pdf_xobject_length_key_name : PdfName = pdf_xobject_name("/Length")

///|
fn pdf_xobject_length_key() -> PdfName {
  pdf_xobject_length_key_name
}

///|
let pdf_xobject_id_key_name : PdfName = pdf_xobject_name("/ID")

///|
fn pdf_xobject_id_key() -> PdfName {
  pdf_xobject_id_key_name
}

///|
fn pdf_xobject_all_page_range(
  document : PdfDocument,
) -> Array[Int] raise PdfError {
  let count = document.pages_of_pagetree().length()
  [
    for page_number in 1..<=count => page_number
  ]
}

///|
fn pdf_xobject_identity_changes(count : Int) -> Array[(Int, Int)] {
  [
    for page_number in 1..<=count => (page_number, page_number)
  ]
}

///|
fn pdf_xobject_all_but_last_page(
  pages : ArrayView[@page.PdfPage],
) -> Array[@page.PdfPage] {
  [
    for index in 0..<(pages.length() - 1) => pages[index]
  ]
}

///|
fn PdfDocument::pdf_xobject_form_object_of_page(
  self : PdfDocument,
  page : @page.PdfPage,
) -> PdfObject raise PdfError {
  let ops = self.parse_content_ops_with_resources(page.resources, page.content)
  let data = pdf_content_bytes_of_ops(ops)
  pdf_stream(
    PdfDictionary([
      (pdf_xobject_type_key(), PdfNameObject(pdf_xobject_xobject())),
      (pdf_xobject_subtype_key(), PdfNameObject(pdf_xobject_form())),
      (pdf_xobject_bbox_key(), page.mediabox),
      (pdf_xobject_resources_key(), page.resources),
      (pdf_xobject_length_key(), PdfInteger(data.length())),
    ]),
    StreamGot(data),
  )
}

///|
fn PdfDocument::pdf_xobject_add_to_page(
  self : PdfDocument,
  page : @page.PdfPage,
  name : PdfName,
  object_number : Int,
) -> @page.PdfPage raise PdfError {
  let xobjects = match
    self.lookup_direct(pdf_xobject_xobject(), page.resources) {
    Some(value) => value
    None => PdfDictionary([])
  }
  let xobjects = xobjects.add_dict_entry(name, PdfIndirect(object_number))
  {
    ..page,
    resources: page.resources.add_dict_entry(pdf_xobject_xobject(), xobjects),
  }
}

///|
fn PdfDocument::pdf_xobject_add_page_as_xobject(
  self : PdfDocument,
  range : ArrayView[Int],
  page : @page.PdfPage,
  name : PdfName,
) -> PdfDocument raise PdfError {
  let pdf = self.copy()
  let xobject_number = pdf.add_object(pdf.pdf_xobject_form_object_of_page(page))
  let pages = pdf.pages_of_pagetree()
  let selected_pages = @core.pdf_number_set(range)
  let rewritten : Array[@page.PdfPage] = Array::new(capacity=pages.length())
  for index in 0..<pages.length() {
    let page_number = index + 1
    if selected_pages.contains(page_number) {
      rewritten.push(
        pdf.pdf_xobject_add_to_page(pages[index], name, xobject_number),
      )
    } else {
      rewritten.push(pages[index])
    }
  }
  let changed = pdf.change_pages(
    rewritten,
    change_references=true,
    changes=pdf_xobject_identity_changes(pages.length()),
  )
  changed.remove_unreferenced()
  changed
}

///|
fn PdfDocument::pdf_xobject_copy_trailer_id_from(
  self : PdfDocument,
  source : PdfDocument,
) -> Unit raise PdfError {
  match source.lookup_direct(pdf_xobject_id_key(), source.trailer_dict()) {
    Some(id) =>
      self.set_trailer_dict(
        self.trailer_dict().add_dict_entry(pdf_xobject_id_key(), id),
      )
    None => ()
  }
}

///|
fn pdf_xobject_retained_bookmarks(
  bookmarks : ArrayView[@bookmark.PdfBookmark],
  old_page_numbers : ArrayView[Int],
  new_page_numbers : ArrayView[Int],
) -> Array[@bookmark.PdfBookmark] raise PdfError {
  let change_map = pdf_page_reference_map(
    pdf_page_reference_changes(old_page_numbers, new_page_numbers),
  )
  [
    for bookmark in bookmarks => {
      pdf_merge_renumber_bookmark_with_map(bookmark, change_map)
    }
  ]
}

///|
/// Stamp the first page of `overlay` into this document as a Form XObject.
///
/// The returned name is the resource name added to each selected base page.
/// The overlay page itself is not retained as a visible page; its content and
/// resources are embedded in the new Form XObject. Existing bookmarks in the
/// base document are preserved and retargeted to the rebuilt page tree.
pub fn PdfDocument::stamp_as_xobject(
  self : PdfDocument,
  range : ArrayView[Int],
  overlay : PdfDocument,
) -> (PdfDocument, PdfName) raise PdfError {
  let prefix = self.shortest_unused_prefix()
  let overlay = overlay.copy()
  overlay.add_prefix(prefix)
  let bookmarks = self.read_bookmarks(preserve_actions=true) catch { _ => [] }
  let bookmark_page_numbers = self.page_reference_numbers()
  let base = self.remove_bookmarks()
  let overlay = overlay.remove_bookmarks()
  let base_range = pdf_xobject_all_page_range(base)
  let overlay_first_page = overlay.pdf_of_pages([1])
  let merged = pdf_merge_pdfs(
    false,
    false,
    ["a", "b"],
    [base, overlay_first_page],
    [base_range, [1]],
  )
  merged.set_saved_encryption(self.saved_encryption())
  merged.pdf_xobject_copy_trailer_id_from(self)
  let merged_pages = merged.pages_of_pagetree()
  guard merged_pages.length() > 0 else { raise PageTreeExpected }
  let overlay_page = merged_pages[merged_pages.length() - 1]
  let under_pages = pdf_xobject_all_but_last_page(merged_pages)
  let changed = merged.change_pages(
    under_pages,
    change_references=true,
    changes=pdf_xobject_identity_changes(under_pages.length()),
  )
  let final_page_numbers = changed.page_reference_numbers()
  let changed = if bookmarks.length() > 0 {
    changed.add_bookmarks(
      pdf_xobject_retained_bookmarks(
        bookmarks, bookmark_page_numbers, final_page_numbers,
      ),
    )
  } else {
    changed
  }
  let name = pdf_xobject_name(
    "/" + changed.shortest_unused_prefix() + "CPDFXObj",
  )
  (changed.pdf_xobject_add_page_as_xobject(range, overlay_page, name), name)
}

///|
/// Compatibility wrapper for `PdfDocument::stamp_as_xobject`.
pub fn pdf_stamp_as_xobject(
  document : PdfDocument,
  range : ArrayView[Int],
  overlay : PdfDocument,
) -> (PdfDocument, PdfName) raise PdfError {
  document.stamp_as_xobject(range, overlay)
}

///|
/// Compatibility wrapper matching cpdfxobject's string resource-name result.
pub fn pdf_stamp_as_xobject_string(
  document : PdfDocument,
  range : ArrayView[Int],
  overlay : PdfDocument,
) -> (PdfDocument, String) raise PdfError {
  let (stamped, name) = document.stamp_as_xobject(range, overlay)
  (stamped, @ascii.decode_lossy(name.bytes()))
}
