///|
/// Encrypt a copy of the document with the revision-2 40-bit ARC4 handler.
///
/// `denied_permissions` is converted to the PDF `/P` mask. `file_id` can be
/// supplied for deterministic output; when omitted, the document gets a
/// CamlPDF-style generated file ID.
pub fn PdfDocument::encrypt_40bit(
  self : PdfDocument,
  user_password : BytesView,
  owner_password : BytesView,
  denied_permissions : ArrayView[@crypt_core.PdfPermission],
  file_id? : BytesView = [],
) -> PdfDocument raise @core.PdfError {
  self.encrypt_arc4_standard(
    user_password, owner_password, denied_permissions, 1, 2, 40, false, file_id,
  )
}

///|
/// Encrypt a copy of the document with the revision-3 128-bit ARC4 handler.
///
/// `denied_permissions` is converted to the PDF `/P` mask. `file_id` can be
/// supplied for deterministic output; when omitted, a generated file ID is
/// added as needed.
pub fn PdfDocument::encrypt_128bit(
  self : PdfDocument,
  user_password : BytesView,
  owner_password : BytesView,
  denied_permissions : ArrayView[@crypt_core.PdfPermission],
  file_id? : BytesView = [],
) -> PdfDocument raise @core.PdfError {
  self.encrypt_arc4_standard(
    user_password, owner_password, denied_permissions, 2, 3, 128, true, file_id,
  )
}
