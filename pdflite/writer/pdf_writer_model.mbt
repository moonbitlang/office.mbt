///|
/// Cross-reference format used when serializing a document.
///
/// Classic writes a traditional xref table and trailer. XRefStream writes an
/// uncompressed xref stream, and CompressedXRefStream wraps that stream in
/// Flate compression.
pub(all) enum PdfWriteMode {
  PdfWriteClassic
  PdfWriteXRefStream
  PdfWriteCompressedXRefStream
} derive(Debug, Eq, ToJson)

///|
/// Encryption options for `pdf_write_document_options`.
///
/// Passwords are stored as owned PDF bytes so callers can pass borrowed
/// `BytesView` values safely.
pub(all) struct PdfWriteEncryption {
  encryption_method : PdfEncryptionMethod
  user_password : PdfBytes
  owner_password : PdfBytes
  denied_permissions : Array[PdfPermission]
} derive(Debug, Eq, ToJson)

///|
/// Build owned encryption options for the writer options API.
pub fn pdf_write_encryption(
  encryption_method : PdfEncryptionMethod,
  user_password : BytesView,
  owner_password : BytesView,
  denied_permissions : ArrayView[PdfPermission],
) -> PdfWriteEncryption {
  let permissions : Array[PdfPermission] = []
  for permission in denied_permissions {
    permissions.push(permission)
  }
  {
    encryption_method,
    user_password: user_password.to_owned(),
    owner_password: owner_password.to_owned(),
    denied_permissions: permissions,
  }
}
