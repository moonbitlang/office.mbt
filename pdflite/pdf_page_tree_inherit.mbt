///|
fn pdf_page_inherited_object(
  current : @syntax.PdfObject?,
  inherited : @syntax.PdfObject?,
) -> @syntax.PdfObject? {
  match current {
    Some(value) => Some(value)
    None => inherited
  }
}

///|
fn PdfDocument::pdf_page_inherited_rotation(
  self : PdfDocument,
  node : @syntax.PdfObject,
  inherited : @page.PdfPageRotation,
) -> @page.PdfPageRotation raise @core.PdfError {
  match self.lookup_direct(pdf_page_rotate_key(), node) {
    Some(PdfInteger(value)) => @page.pdf_page_rotation_of_int(value)
    _ => inherited
  }
}

///|
fn PdfDocument::pdf_page_find_inherited_attribute(
  self : PdfDocument,
  object : @syntax.PdfObject,
  key : @core.PdfName,
  depth : Int,
) -> @syntax.PdfObject? raise @core.PdfError {
  if depth > 10000 {
    raise PageTreeExpected
  }
  match self.lookup_direct(key, object) {
    Some(_) => None
    None =>
      match self.lookup_direct(pdf_page_parent_key(), object) {
        Some(parent) =>
          match parent.lookup_immediate(key) {
            Some(value) => Some(value)
            None =>
              self.pdf_page_find_inherited_attribute(parent, key, depth + 1)
          }
        None => None
      }
  }
}

///|
fn PdfDocument::pdf_page_replace_inherited_key(
  self : PdfDocument,
  object : @syntax.PdfObject,
  key : @core.PdfName,
) -> @syntax.PdfObject? raise @core.PdfError {
  match self.pdf_page_find_inherited_attribute(object, key, 0) {
    Some(value) => Some(object.add_dict_entry(key, value))
    None => None
  }
}

///|
/// Materialize inherited page attributes onto page dictionaries.
///
/// For each object number, inherited `/MediaBox`, `/CropBox`, `/Rotate`, and
/// `/Resources` values are copied onto the page object when available. This is
/// useful before page extraction or object-level rewriting.
pub fn PdfDocument::replace_inherit(
  self : PdfDocument,
  object_numbers : ArrayView[Int],
) -> Unit raise @core.PdfError {
  let keys = [
    pdf_page_mediabox_key(),
    pdf_page_cropbox_key(),
    pdf_page_rotate_key(),
    pdf_page_resources_key(),
  ]
  for number in object_numbers {
    let original = self.lookup_object_or_null(number)
    let mut updated = original
    for key in keys {
      match self.pdf_page_replace_inherited_key(updated, key) {
        Some(next) => updated = next
        None => ()
      }
    }
    if updated != original {
      self.add_object_given_number(number, updated)
    }
  }
}
