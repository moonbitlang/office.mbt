///|
fn PdfEncryptionValues::file_key_for_recrypt_password(
  self : PdfEncryptionValues,
  password : BytesView,
) -> @core.PdfBytes raise @core.PdfError {
  match self.file_key_for_user_password(password) {
    Some(key) => key
    None =>
      match self.file_key_for_owner_password(password) {
        Some(key) => key
        None => raise EncryptionRecryptFailed
      }
  }
}

///|
fn PdfDocument::pdf_crypt_prepare_plaintext_for_recrypt(
  self : PdfDocument,
) -> Unit {
  for number in self.object_numbers() {
    match self.objects.get_entry(number) {
      Some({ data: ObjectParsedAlreadyDecrypted(object), generation }) =>
        self.objects.set_entry(number, {
          data: ObjectParsed(object),
          generation,
        })
      _ => ()
    }
  }
}

///|
fn PdfDocument::recrypt_arc4_with_file_key(
  self : PdfDocument,
  values : PdfEncryptionValues,
  file_key : BytesView,
  key_length_bits : Int,
  revision : Int,
) -> PdfDocument raise @core.PdfError {
  let (document, _) = self.with_file_id(file_id=values.file_id)
  document.pdf_crypt_prepare_plaintext_for_recrypt()
  document.set_saved_encryption(None)
  let encrypted = document.arc4_crypt_parsed_objects(
    file_key,
    key_length_bits,
    !values.encrypt_metadata,
    0,
  )
  encrypted.set_saved_encryption(None)
  let encrypt_dictionary = pdf_crypt_saved_arc4_dictionary(
    values, key_length_bits, revision,
  )
  let encrypt_number = encrypted.add_object(encrypt_dictionary)
  encrypted.set_trailer_dict(
    encrypted
    .trailer_dict()
    .add_dict_entry(pdf_crypt_encrypt_name, PdfIndirect(encrypt_number)),
  )
  encrypted
}

///|
fn PdfDocument::recrypt_aesv2_with_file_key(
  self : PdfDocument,
  values : PdfEncryptionValues,
  file_key : BytesView,
  iv_provider : (Int, Int, Int) -> @core.PdfBytes raise @core.PdfError,
) -> PdfDocument raise @core.PdfError {
  let (document, _) = self.with_file_id(file_id=values.file_id)
  document.pdf_crypt_prepare_plaintext_for_recrypt()
  document.set_saved_encryption(None)
  let encrypted = document.aesv2_encrypt_parsed_objects_with_iv_provider(
    file_key,
    128,
    iv_provider,
    !values.encrypt_metadata,
  )
  encrypted.set_saved_encryption(None)
  let encrypt_dictionary = pdf_crypt_saved_aesv2_dictionary(values)
  let encrypt_number = encrypted.add_object(encrypt_dictionary)
  encrypted.set_trailer_dict(
    encrypted
    .trailer_dict()
    .add_dict_entry(pdf_crypt_encrypt_name, PdfIndirect(encrypt_number)),
  )
  encrypted
}

///|
fn PdfDocument::recrypt_aesv3_with_file_key(
  self : PdfDocument,
  values : PdfEncryptionValues,
  file_key : BytesView,
  iv_provider : (Int, Int, Int) -> @core.PdfBytes raise @core.PdfError,
) -> PdfDocument raise @core.PdfError {
  let (document, _) = self.with_file_id(file_id=values.file_id)
  document.pdf_crypt_prepare_plaintext_for_recrypt()
  document.set_saved_encryption(None)
  let encrypted = document.aesv3_encrypt_parsed_objects_with_iv_provider(
    file_key,
    iv_provider,
    !values.encrypt_metadata,
  )
  encrypted.set_saved_encryption(None)
  let encrypt_dictionary = pdf_crypt_saved_aesv3_dictionary(values)
  let encrypt_number = encrypted.add_object(encrypt_dictionary)
  encrypted.set_trailer_dict(
    encrypted
    .trailer_dict()
    .add_dict_entry(pdf_crypt_encrypt_name, PdfIndirect(encrypt_number)),
  )
  encrypted
}

///|
/// Re-encrypt a previously decrypted document using its saved ARC4 settings.
///
/// The document must have saved encryption state from a successful decrypt.
/// The supplied password is authenticated against that state before the
/// original encryption dictionary shape is restored.
pub fn PdfDocument::recrypt_with_password(
  self : PdfDocument,
  password : BytesView,
) -> PdfDocument raise @core.PdfError {
  let saved = match self.saved_encryption() {
    Some(saved) => saved
    None => raise EncryptionSavedStateExpected
  }
  let values = saved.values
  match values.crypt_type {
    PdfCryptARC4(key_length_bits, revision) if (
        key_length_bits == 40 || key_length_bits == 128
      ) &&
      (revision == 2 || revision == 3 || revision == 4) => {
      let file_key = values.file_key_for_recrypt_password(password)
      self.recrypt_arc4_with_file_key(
        values, file_key, key_length_bits, revision,
      )
    }
    _ => raise EncryptionRecryptUnsupported(values.crypt_type)
  }
}

///|
/// Re-encrypt a decrypted AESV2 document using its saved encryption settings.
///
/// `iv_provider` supplies fresh IVs for encrypted object data. The saved
/// encryption state determines passwords, permissions, and crypt-filter shape.
pub fn PdfDocument::recrypt_with_password_aesv2_with_iv_provider(
  self : PdfDocument,
  password : BytesView,
  iv_provider : (Int, Int, Int) -> @core.PdfBytes raise @core.PdfError,
) -> PdfDocument raise @core.PdfError {
  let saved = match self.saved_encryption() {
    Some(saved) => saved
    None => raise EncryptionSavedStateExpected
  }
  let values = saved.values
  match values.crypt_type {
    PdfCryptAESV2 => {
      let file_key = values.file_key_for_recrypt_password(password)
      self.recrypt_aesv2_with_file_key(values, file_key, iv_provider)
    }
    _ => raise EncryptionRecryptUnsupported(values.crypt_type)
  }
}

///|
/// Re-encrypt a decrypted AESV3 document using its saved encryption settings.
///
/// `iv_provider` supplies fresh IVs for encrypted object data. The saved
/// encryption state supplies the existing AESV3 password entries and file key
/// wrapping metadata.
pub fn PdfDocument::recrypt_with_password_aesv3_with_iv_provider(
  self : PdfDocument,
  password : BytesView,
  iv_provider : (Int, Int, Int) -> @core.PdfBytes raise @core.PdfError,
) -> PdfDocument raise @core.PdfError {
  let saved = match self.saved_encryption() {
    Some(saved) => saved
    None => raise EncryptionSavedStateExpected
  }
  let values = saved.values
  match values.crypt_type {
    PdfCryptAESV3(_) => {
      let file_key = values.file_key_for_recrypt_password(password)
      self.recrypt_aesv3_with_file_key(values, file_key, iv_provider)
    }
    _ => raise EncryptionRecryptUnsupported(values.crypt_type)
  }
}
