///|
fn pdf_document_name(text : String) -> @core.PdfName {
  @core.pdf_name_of_bytes(@ascii.encode(text))
}

///|
let pdf_document_root_key_name : @core.PdfName = pdf_document_name("/Root")

///|
fn pdf_document_root_key() -> @core.PdfName {
  pdf_document_root_key_name
}

///|
/// Construct an empty PDF document with CamlPDF-compatible defaults.
///
/// The default version is `1.0`, the root object number is `0`, the trailer is
/// an empty dictionary, and `revision_read` starts at `1`.
pub fn pdf_document_empty() -> PdfDocument {
  {
    major: 1,
    minor: 0,
    root: 0,
    objects: pdf_objects_empty(),
    trailer_dict: PdfDictionary([]),
    was_linearized: false,
    saved_encryption: None,
    first_xref: 0,
    revision_read: 1,
  }
}

///|
/// Deep-copy the document object table and trailer.
///
/// Parsed object containers and stream data are copied so mutations to the copy
/// do not alter the original document's object graph.
pub fn PdfDocument::copy(self : PdfDocument) -> PdfDocument {
  {
    major: self.major,
    minor: self.minor,
    root: self.root,
    objects: self.objects.copy(),
    trailer_dict: self.trailer_dict.deep_copy(),
    was_linearized: self.was_linearized,
    saved_encryption: self.saved_encryption,
    first_xref: self.first_xref,
    revision_read: self.revision_read,
  }
}

///|
/// Return the PDF version as `(major, minor)`.
pub fn PdfDocument::version(self : PdfDocument) -> (Int, Int) {
  (self.major, self.minor)
}

///|
/// Set the PDF version stored on the document.
pub fn PdfDocument::set_version(
  self : PdfDocument,
  major : Int,
  minor : Int,
) -> Unit {
  self.major = major
  self.minor = minor
}

///|
/// Return the catalog root object number tracked on the document.
pub fn PdfDocument::root(self : PdfDocument) -> Int {
  self.root
}

///|
/// Return the resolved document catalog object.
///
/// A `/Root` entry in the trailer dictionary is preferred over the stored root
/// number. The selected reference is resolved through `direct`; if it resolves
/// to `PdfNull`, this raises `@core.PdfError::RootExpected`.
pub fn PdfDocument::catalog(
  self : PdfDocument,
) -> @syntax.PdfObject raise @core.PdfError {
  let object = match
    self.trailer_dict.lookup_immediate(pdf_document_root_key()) {
    Some(root) => self.direct(root)
    None => self.lookup_object_or_null(self.root)
  }
  match object {
    PdfNull => raise RootExpected
    catalog => catalog
  }
}

///|
/// Set the catalog root object number.
pub fn PdfDocument::set_root(self : PdfDocument, root : Int) -> Unit {
  self.root = root
}

///|
/// Return the current trailer dictionary object.
///
/// The returned object may share mutable container state with the document.
pub fn PdfDocument::trailer_dict(self : PdfDocument) -> @syntax.PdfObject {
  self.trailer_dict
}

///|
/// Replace the document trailer dictionary object.
pub fn PdfDocument::set_trailer_dict(
  self : PdfDocument,
  trailer_dict : @syntax.PdfObject,
) -> Unit {
  self.trailer_dict = trailer_dict
}
