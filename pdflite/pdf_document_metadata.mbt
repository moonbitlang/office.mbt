///|
/// Return whether the source PDF was marked as linearized.
pub fn PdfDocument::was_linearized(self : PdfDocument) -> Bool {
  self.was_linearized
}

///|
/// Set whether the source PDF was marked as linearized.
pub fn PdfDocument::set_was_linearized(
  self : PdfDocument,
  was_linearized : Bool,
) -> Unit {
  self.was_linearized = was_linearized
}

///|
/// Return saved encryption metadata, if the document is encrypted.
fn PdfDocument::saved_encryption(
  self : PdfDocument,
) -> @crypt_core.PdfSavedEncryption? {
  self.saved_encryption
}

///|
/// Set saved encryption metadata for the document.
fn PdfDocument::set_saved_encryption(
  self : PdfDocument,
  saved_encryption : @crypt_core.PdfSavedEncryption?,
) -> Unit {
  self.saved_encryption = saved_encryption
}

///|
/// Return the byte offset of the first xref section read from the input.
pub fn PdfDocument::first_xref(self : PdfDocument) -> Int {
  self.first_xref
}

///|
/// Set the byte offset of the first xref section read from the input.
pub fn PdfDocument::set_first_xref(
  self : PdfDocument,
  first_xref : Int,
) -> Unit {
  self.first_xref = first_xref
}

///|
/// Return the number of document revisions read from the input.
pub fn PdfDocument::revision_read(self : PdfDocument) -> Int {
  self.revision_read
}

///|
/// Set the number of document revisions read from the input.
pub fn PdfDocument::set_revision_read(
  self : PdfDocument,
  revision_read : Int,
) -> Unit {
  self.revision_read = revision_read
}
