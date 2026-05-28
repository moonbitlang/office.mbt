///|
/// Encrypt a copy of the document with AESV3/AES-256 security.
///
/// `random_provider` supplies the file key, salts, and permissions padding;
/// `iv_provider` supplies CBC IVs for encrypted strings and streams. `iso=true`
/// selects the ISO/PDF 2.0 hash variant.
pub fn PdfDocument::encrypt_256bit_aesv3_with_providers(
  self : PdfDocument,
  user_password : BytesView,
  owner_password : BytesView,
  denied_permissions : ArrayView[PdfPermission],
  random_provider : (PdfAesV3RandomField, Int) -> PdfBytes raise PdfError,
  iv_provider : (Int, Int, Int) -> PdfBytes raise PdfError,
  iso? : Bool = false,
  encrypt_metadata? : Bool = true,
  file_id? : BytesView = [],
) -> PdfDocument raise PdfError {
  let no_encrypt_metadata = !encrypt_metadata
  let (document, id) = self.with_file_id(file_id~)
  let permissions = pdf_p_of_permissions(denied_permissions)
  let file_key = pdf_aesv3_random_bytes(random_provider, PdfAesV3FileKey, 32)
  let user_validation_salt = pdf_aesv3_random_bytes(
    random_provider,
    PdfAesV3UserValidationSalt,
    8,
  )
  let user_key_salt = pdf_aesv3_random_bytes(
    random_provider,
    PdfAesV3UserKeySalt,
    8,
  )
  let owner_validation_salt = pdf_aesv3_random_bytes(
    random_provider,
    PdfAesV3OwnerValidationSalt,
    8,
  )
  let owner_key_salt = pdf_aesv3_random_bytes(
    random_provider,
    PdfAesV3OwnerKeySalt,
    8,
  )
  let permissions_padding = pdf_aesv3_random_bytes(
    random_provider,
    PdfAesV3PermissionsPadding,
    4,
  )
  let user_entry = pdf_aesv3_entry(
    iso, user_password, user_validation_salt, user_key_salt,
  )
  let owner_entry = pdf_aesv3_entry(
    iso,
    owner_password,
    owner_validation_salt,
    owner_key_salt,
    user_entry~,
  )
  let user_encryption_key = pdf_aesv3_wrap_file_key(
    iso, user_password, user_key_salt, file_key,
  )
  let owner_encryption_key = pdf_aesv3_wrap_file_key(
    iso,
    owner_password,
    owner_key_salt,
    file_key,
    user_entry~,
  )
  let permissions_entry = pdf_aesv3_permissions_entry(
    file_key, permissions, encrypt_metadata, permissions_padding,
  )
  let encrypted = document.aesv3_encrypt_parsed_objects_with_iv_provider(
    file_key, iv_provider, no_encrypt_metadata,
  )
  let encrypt_dictionary = pdf_crypt_saved_aesv3_dictionary({
    crypt_type: PdfCryptAESV3(iso),
    user_entry,
    owner_entry,
    permissions,
    file_id: id,
    encrypt_metadata,
    permissions_entry: Some(permissions_entry),
    user_encryption_key: Some(user_encryption_key),
    owner_encryption_key: Some(owner_encryption_key),
  })
  let encrypt_number = encrypted.add_object(encrypt_dictionary)
  encrypted.set_trailer_dict(
    encrypted
    .trailer_dict()
    .add_dict_entry(pdf_crypt_encrypt_name, PdfIndirect(encrypt_number)),
  )
  encrypted
}

///|
/// Encrypt a copy of the document with the ISO AESV3/AES-256 variant.
///
/// This is a convenience wrapper around
/// `encrypt_256bit_aesv3_with_providers` with `iso=true`.
pub fn PdfDocument::encrypt_256bit_aesv3_iso_with_providers(
  self : PdfDocument,
  user_password : BytesView,
  owner_password : BytesView,
  denied_permissions : ArrayView[PdfPermission],
  random_provider : (PdfAesV3RandomField, Int) -> PdfBytes raise PdfError,
  iv_provider : (Int, Int, Int) -> PdfBytes raise PdfError,
  encrypt_metadata? : Bool = true,
  file_id? : BytesView = [],
) -> PdfDocument raise PdfError {
  self.encrypt_256bit_aesv3_with_providers(
    user_password,
    owner_password,
    denied_permissions,
    random_provider,
    iv_provider,
    iso=true,
    encrypt_metadata~,
    file_id~,
  )
}
