///|
/// Decrypt with a user password only.
///
/// Unencrypted documents return a copied document and empty denied permissions.
/// Encrypted documents return `None` when the user password does not
/// authenticate.
pub fn PdfDocument::decrypt_with_user_password(
  self : PdfDocument,
  password : BytesView,
  no_encrypt_metadata? : Bool = false,
) -> PdfDecryptionResult? raise PdfError {
  match self.trailer_dict().lookup_immediate(pdf_crypt_encrypt_name) {
    None => Some({ document: self.copy(), denied_permissions: [] })
    Some(_) => {
      let values = self.encryption_values()
      let file_key = match
        values.file_key_for_user_password(password, no_encrypt_metadata~) {
        Some(key) => key
        None => return None
      }
      Some(self.decrypt_with_file_key(values, file_key, no_encrypt_metadata))
    }
  }
}

///|
/// Decrypt with an owner password only.
///
/// Unencrypted documents return a copied document and empty denied permissions.
/// Encrypted documents return `None` when the owner password does not
/// authenticate.
pub fn PdfDocument::decrypt_with_owner_password(
  self : PdfDocument,
  password : BytesView,
  no_encrypt_metadata? : Bool = false,
) -> PdfDecryptionResult? raise PdfError {
  match self.trailer_dict().lookup_immediate(pdf_crypt_encrypt_name) {
    None => Some({ document: self.copy(), denied_permissions: [] })
    Some(_) => {
      let values = self.encryption_values()
      let file_key = match
        values.file_key_for_owner_password(password, no_encrypt_metadata~) {
        Some(key) => key
        None => return None
      }
      Some(self.decrypt_with_file_key(values, file_key, no_encrypt_metadata))
    }
  }
}
