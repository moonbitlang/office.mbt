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
      Some(self.decrypt_with_file_key(values, file_key, no_encrypt_metadata~))
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
      Some(self.decrypt_with_file_key(values, file_key, no_encrypt_metadata~))
    }
  }
}

///|
/// CamlPDF-shaped decrypt helper returning document and denied permissions.
///
/// A failed authentication returns `(None, current_permissions)`, while
/// malformed encryption dictionaries raise `PdfError`.
pub fn pdf_decrypt_pdf(
  document : PdfDocument,
  user_password : BytesView,
  owner_password? : BytesView? = None,
  no_encrypt_metadata? : Bool = false,
) -> (PdfDocument?, Array[PdfPermission]) raise PdfError {
  match
    document.decrypt_with_passwords(
      user_password=Some(user_password),
      owner_password~,
      no_encrypt_metadata~,
    ) {
    Some(result) => (Some(result.document), result.denied_permissions)
    None => (None, document.permissions())
  }
}

///|
/// CamlPDF-shaped owner-password decrypt helper.
pub fn pdf_decrypt_pdf_owner(
  document : PdfDocument,
  owner_password : BytesView,
  no_encrypt_metadata? : Bool = false,
) -> PdfDocument? raise PdfError {
  match
    document.decrypt_with_owner_password(owner_password, no_encrypt_metadata~) {
    Some(result) => Some(result.document)
    None => None
  }
}

///|
/// Compatibility wrapper for `PdfDocument::encrypt_40bit`.
pub fn pdf_encrypt_pdf_40bit(
  document : PdfDocument,
  user_password : BytesView,
  owner_password : BytesView,
  denied_permissions : ArrayView[PdfPermission],
  file_id? : BytesView = [],
) -> PdfDocument raise PdfError {
  document.encrypt_40bit(
    user_password,
    owner_password,
    denied_permissions,
    file_id~,
  )
}

///|
/// Compatibility wrapper for `PdfDocument::encrypt_128bit`.
pub fn pdf_encrypt_pdf_128bit(
  document : PdfDocument,
  user_password : BytesView,
  owner_password : BytesView,
  denied_permissions : ArrayView[PdfPermission],
  file_id? : BytesView = [],
) -> PdfDocument raise PdfError {
  document.encrypt_128bit(
    user_password,
    owner_password,
    denied_permissions,
    file_id~,
  )
}

///|
/// Compatibility wrapper for AESV2 encryption with caller-supplied IVs.
pub fn pdf_encrypt_pdf_AES_with_iv_provider(
  document : PdfDocument,
  encrypt_metadata : Bool,
  user_password : BytesView,
  owner_password : BytesView,
  denied_permissions : ArrayView[PdfPermission],
  iv_provider : (Int, Int, Int) -> PdfBytes raise PdfError,
  file_id? : BytesView = [],
) -> PdfDocument raise PdfError {
  document.encrypt_128bit_aesv2_with_iv_provider(
    user_password,
    owner_password,
    denied_permissions,
    iv_provider,
    encrypt_metadata~,
    file_id~,
  )
}

///|
/// Compatibility wrapper for AESV3 encryption with caller-supplied providers.
pub fn pdf_encrypt_pdf_AES256_with_providers(
  document : PdfDocument,
  encrypt_metadata : Bool,
  user_password : BytesView,
  owner_password : BytesView,
  denied_permissions : ArrayView[PdfPermission],
  random_provider : (PdfAesV3RandomField, Int) -> PdfBytes raise PdfError,
  iv_provider : (Int, Int, Int) -> PdfBytes raise PdfError,
  file_id? : BytesView = [],
) -> PdfDocument raise PdfError {
  document.encrypt_256bit_aesv3_with_providers(
    user_password,
    owner_password,
    denied_permissions,
    random_provider,
    iv_provider,
    encrypt_metadata~,
    file_id~,
  )
}

///|
/// Compatibility wrapper for ISO AESV3 encryption with caller-supplied providers.
pub fn pdf_encrypt_pdf_AES256ISO_with_providers(
  document : PdfDocument,
  encrypt_metadata : Bool,
  user_password : BytesView,
  owner_password : BytesView,
  denied_permissions : ArrayView[PdfPermission],
  random_provider : (PdfAesV3RandomField, Int) -> PdfBytes raise PdfError,
  iv_provider : (Int, Int, Int) -> PdfBytes raise PdfError,
  file_id? : BytesView = [],
) -> PdfDocument raise PdfError {
  document.encrypt_256bit_aesv3_iso_with_providers(
    user_password,
    owner_password,
    denied_permissions,
    random_provider,
    iv_provider,
    encrypt_metadata~,
    file_id~,
  )
}

///|
/// Re-encrypt a decrypted document, optionally compact-renumbering first.
///
/// AES documents use `iv_provider`; ARC4 documents ignore it. The input must
/// carry saved encryption state from a previous decrypt.
pub fn pdf_recrypt_pdf_with_iv_provider(
  document : PdfDocument,
  password : BytesView,
  iv_provider : (Int, Int, Int) -> PdfBytes raise PdfError,
  renumber? : Bool = true,
) -> PdfDocument raise PdfError {
  let input = if renumber {
    document.renumber_objects_compact()
  } else {
    document.copy()
  }
  let saved = match input.saved_encryption() {
    Some(saved) => saved
    None => raise EncryptionSavedStateExpected
  }
  match saved.values.crypt_type {
    PdfCryptAESV2 =>
      input.recrypt_with_password_aesv2_with_iv_provider(password, iv_provider)
    PdfCryptAESV3(_) =>
      input.recrypt_with_password_aesv3_with_iv_provider(password, iv_provider)
    PdfCryptARC4(_, _) => input.recrypt_with_password(password)
  }
}

///|
/// Re-encrypt a decrypted ARC4 document, optionally compact-renumbering first.
///
/// AES documents require `pdf_recrypt_pdf_with_iv_provider` so fresh IVs can be
/// supplied.
pub fn pdf_recrypt_pdf(
  document : PdfDocument,
  password : BytesView,
  renumber? : Bool = true,
) -> PdfDocument raise PdfError {
  let input = if renumber {
    document.renumber_objects_compact()
  } else {
    document.copy()
  }
  input.recrypt_with_password(password)
}
