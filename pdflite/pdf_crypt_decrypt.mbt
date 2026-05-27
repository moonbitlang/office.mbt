///|
fn PdfDocument::finish_decrypted_copy(
  self : PdfDocument,
  values : PdfEncryptionValues,
) -> Unit raise PdfError {
  self.set_trailer_dict(
    self.trailer_dict().remove_dict_entry(pdf_crypt_encrypt_name),
  )
  self.set_saved_encryption(Some({ values, }))
}

///|
fn PdfDocument::decrypt_with_file_key(
  self : PdfDocument,
  values : PdfEncryptionValues,
  file_key : PdfBytes,
  no_encrypt_metadata : Bool,
) -> PdfDecryptionResult raise PdfError {
  let no_encrypt_metadata = values.effective_no_encrypt_metadata(
    no_encrypt_metadata,
  )
  match values.crypt_type {
    PdfCryptARC4(key_length_bits, _) => {
      let output = self.arc4_crypt_parsed_objects(
        file_key,
        key_length_bits,
        no_encrypt_metadata,
        self.encryption_object_number(),
      )
      output.finish_decrypted_copy(values)
      {
        document: output,
        denied_permissions: pdf_permissions_of_p(values.permissions),
      }
    }
    PdfCryptAESV2 => {
      let output = self.aesv2_decrypt_parsed_objects(
        file_key,
        128,
        no_encrypt_metadata,
        self.encryption_object_number(),
      )
      output.finish_decrypted_copy(values)
      {
        document: output,
        denied_permissions: pdf_permissions_of_p(values.permissions),
      }
    }
    PdfCryptAESV3(_) => {
      let output = self.aesv3_decrypt_parsed_objects(
        file_key,
        no_encrypt_metadata,
        self.encryption_object_number(),
      )
      output.finish_decrypted_copy(values)
      {
        document: output,
        denied_permissions: pdf_permissions_of_p(values.permissions),
      }
    }
  }
}

///|
fn PdfEncryptionValues::file_key_for_available_password(
  self : PdfEncryptionValues,
  user_password : BytesView?,
  owner_password : BytesView?,
  no_encrypt_metadata : Bool,
) -> PdfBytes? raise PdfError {
  match user_password {
    Some(password) =>
      match self.file_key_for_user_password(password, no_encrypt_metadata~) {
        Some(key) => return Some(key)
        None =>
          match owner_password {
            Some(password) =>
              self.file_key_for_owner_password(password, no_encrypt_metadata~)
            None => None
          }
      }
    None =>
      match owner_password {
        Some(password) =>
          self.file_key_for_owner_password(password, no_encrypt_metadata~)
        None => self.file_key_for_user_password([], no_encrypt_metadata~)
      }
  }
}

///|
fn PdfEncryptionValues::decrypt_single_stream_with_file_key(
  self : PdfEncryptionValues,
  object_number : Int,
  generation : Int,
  stream : PdfObject,
  file_key : BytesView,
  no_encrypt_metadata : Bool,
) -> PdfObject raise PdfError {
  let no_encrypt_metadata = self.effective_no_encrypt_metadata(
    no_encrypt_metadata,
  )
  match self.crypt_type {
    PdfCryptARC4(key_length_bits, _) =>
      pdf_arc4_crypt_pdf_object(
        object_number, generation, file_key, key_length_bits, stream, no_encrypt_metadata,
      )
    PdfCryptAESV2 =>
      pdf_aesv2_decrypt_pdf_object(
        object_number, generation, file_key, 128, stream, no_encrypt_metadata,
      )
    PdfCryptAESV3(_) =>
      pdf_aesv3_decrypt_pdf_object(file_key, stream, no_encrypt_metadata)
  }
}

///|
/// Decrypt one encrypted stream object with available passwords.
///
/// Unencrypted documents return `stream` unchanged. Encrypted documents return
/// `None` when no supplied password authenticates. The caller supplies the
/// stream object's number and generation because object keys depend on them.
pub fn PdfDocument::decrypt_single_stream(
  self : PdfDocument,
  object_number : Int,
  generation : Int,
  stream : PdfObject,
  user_password? : BytesView? = None,
  owner_password? : BytesView? = None,
  no_encrypt_metadata? : Bool = false,
) -> PdfObject? raise PdfError {
  if !self.is_encrypted() {
    Some(stream)
  } else {
    let values = self.encryption_values()
    match
      values.file_key_for_available_password(
        user_password, owner_password, no_encrypt_metadata,
      ) {
      Some(file_key) =>
        Some(
          values.decrypt_single_stream_with_file_key(
            object_number, generation, stream, file_key, no_encrypt_metadata,
          ),
        )
      None => None
    }
  }
}

///|
/// Decrypt this document using optional user and owner passwords.
///
/// If the document is not encrypted, a copied document and empty permissions
/// list are returned. If it is encrypted and no password works, the result is
/// `None`; malformed encryption data still raises `PdfError`.
pub fn PdfDocument::decrypt_with_passwords(
  self : PdfDocument,
  user_password? : BytesView? = None,
  owner_password? : BytesView? = None,
  no_encrypt_metadata? : Bool = false,
) -> PdfDecryptionResult? raise PdfError {
  if !self.is_encrypted() {
    Some({ document: self.copy(), denied_permissions: [] })
  } else {
    let values = self.encryption_values()
    match
      values.file_key_for_available_password(
        user_password, owner_password, no_encrypt_metadata,
      ) {
      Some(file_key) =>
        Some(self.decrypt_with_file_key(values, file_key, no_encrypt_metadata))
      None => None
    }
  }
}
