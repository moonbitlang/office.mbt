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
  denied_permissions : ArrayView[PdfPermission],
  file_id? : BytesView = [],
) -> PdfDocument raise PdfError {
  self.encrypt_arc4_standard(
    user_password,
    owner_password,
    denied_permissions,
    1,
    2,
    40,
    false,
    file_id~,
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
  denied_permissions : ArrayView[PdfPermission],
  file_id? : BytesView = [],
) -> PdfDocument raise PdfError {
  self.encrypt_arc4_standard(
    user_password,
    owner_password,
    denied_permissions,
    2,
    3,
    128,
    true,
    file_id~,
  )
}

///|
/// Encrypt a copy of the document with revision-4 128-bit ARC4.
///
/// This writes a crypt-filter dictionary using `/V2`. `encrypt_metadata=false`
/// follows the revision-4 no-metadata key derivation and stream policy.
pub fn PdfDocument::encrypt_128bit_r4(
  self : PdfDocument,
  user_password : BytesView,
  owner_password : BytesView,
  denied_permissions : ArrayView[PdfPermission],
  encrypt_metadata? : Bool = true,
  file_id? : BytesView = [],
) -> PdfDocument raise PdfError {
  let no_encrypt_metadata = !encrypt_metadata
  let (document, id) = self.with_file_id(file_id~)
  let permissions = pdf_p_of_permissions(denied_permissions)
  let owner_entry = @crypt_core.pdf_make_owner_password_entry(
    4, owner_password, user_password, 128,
  )
  let user_entry = @crypt_core.pdf_make_user_password_entry(
    no_encrypt_metadata, user_password, 4, owner_entry, permissions, id, 128,
  )
  let file_key = @crypt_core.pdf_encryption_file_key(
    no_encrypt_metadata, user_password, 4, owner_entry, permissions, id, 128,
  )
  let encrypted = document.arc4_crypt_parsed_objects(
    file_key,
    128,
    no_encrypt_metadata~,
  )
  let std_cf = pdf_crypt_std_cf_name
  let encrypt_dictionary : PdfObject = PdfDictionary([
    (pdf_crypt_filter_name, PdfNameObject(pdf_crypt_standard_name)),
    (pdf_crypt_v_name, PdfInteger(4)),
    (
      pdf_crypt_cf_name,
      PdfDictionary([
        (
          std_cf,
          PdfDictionary([
            (pdf_crypt_length_name, PdfInteger(16)),
            (pdf_crypt_auth_event_name, PdfNameObject(pdf_crypt_doc_open_name)),
            (pdf_crypt_cfm_name, PdfNameObject(pdf_crypt_v2_name)),
          ]),
        ),
      ]),
    ),
    (pdf_crypt_encrypt_metadata_name, PdfBoolean(encrypt_metadata)),
    (pdf_crypt_length_name, PdfInteger(128)),
    (pdf_crypt_r_name, PdfInteger(4)),
    (pdf_crypt_o_name, PdfString(owner_entry)),
    (pdf_crypt_u_name, PdfString(user_entry)),
    (pdf_crypt_p_name, PdfInteger(permissions)),
    (pdf_crypt_strf_name, PdfNameObject(std_cf)),
    (pdf_crypt_stmf_name, PdfNameObject(std_cf)),
  ])
  let encrypt_number = encrypted.add_object(encrypt_dictionary)
  encrypted.set_trailer_dict(
    encrypted
    .trailer_dict()
    .add_dict_entry(pdf_crypt_encrypt_name, PdfIndirect(encrypt_number)),
  )
  encrypted
}

///|
/// Encrypt a copy of the document with revision-4 AESV2.
///
/// `iv_provider` supplies per-object 16-byte CBC IVs by object number,
/// generation, and IV index. This makes tests reproducible while allowing
/// production callers to provide secure random IVs.
pub fn PdfDocument::encrypt_128bit_aesv2_with_iv_provider(
  self : PdfDocument,
  user_password : BytesView,
  owner_password : BytesView,
  denied_permissions : ArrayView[PdfPermission],
  iv_provider : (Int, Int, Int) -> PdfBytes raise PdfError,
  encrypt_metadata? : Bool = true,
  file_id? : BytesView = [],
) -> PdfDocument raise PdfError {
  let no_encrypt_metadata = !encrypt_metadata
  let (document, id) = self.with_file_id(file_id~)
  let permissions = pdf_p_of_permissions(denied_permissions)
  let owner_entry = @crypt_core.pdf_make_owner_password_entry(
    4, owner_password, user_password, 128,
  )
  let user_entry = @crypt_core.pdf_make_user_password_entry(
    no_encrypt_metadata, user_password, 4, owner_entry, permissions, id, 128,
  )
  let file_key = @crypt_core.pdf_encryption_file_key(
    no_encrypt_metadata, user_password, 4, owner_entry, permissions, id, 128,
  )
  let encrypted = document.aesv2_encrypt_parsed_objects_with_iv_provider(
    file_key,
    128,
    iv_provider,
    no_encrypt_metadata~,
  )
  let std_cf = pdf_crypt_std_cf_name
  let encrypt_dictionary : PdfObject = PdfDictionary([
    (pdf_crypt_filter_name, PdfNameObject(pdf_crypt_standard_name)),
    (pdf_crypt_v_name, PdfInteger(4)),
    (
      pdf_crypt_cf_name,
      PdfDictionary([
        (
          std_cf,
          PdfDictionary([
            (pdf_crypt_length_name, PdfInteger(16)),
            (pdf_crypt_auth_event_name, PdfNameObject(pdf_crypt_doc_open_name)),
            (pdf_crypt_cfm_name, PdfNameObject(pdf_crypt_aesv2_name)),
          ]),
        ),
      ]),
    ),
    (pdf_crypt_encrypt_metadata_name, PdfBoolean(encrypt_metadata)),
    (pdf_crypt_length_name, PdfInteger(128)),
    (pdf_crypt_r_name, PdfInteger(4)),
    (pdf_crypt_o_name, PdfString(owner_entry)),
    (pdf_crypt_u_name, PdfString(user_entry)),
    (pdf_crypt_p_name, PdfInteger(permissions)),
    (pdf_crypt_strf_name, PdfNameObject(std_cf)),
    (pdf_crypt_stmf_name, PdfNameObject(std_cf)),
  ])
  let encrypt_number = encrypted.add_object(encrypt_dictionary)
  encrypted.set_trailer_dict(
    encrypted
    .trailer_dict()
    .add_dict_entry(pdf_crypt_encrypt_name, PdfIndirect(encrypt_number)),
  )
  encrypted
}

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
    file_key,
    iv_provider,
    no_encrypt_metadata~,
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

///|
fn PdfDocument::encrypt_arc4_standard(
  self : PdfDocument,
  user_password : BytesView,
  owner_password : BytesView,
  denied_permissions : ArrayView[PdfPermission],
  version : Int,
  revision : Int,
  key_length_bits : Int,
  write_length : Bool,
  file_id? : BytesView = [],
) -> PdfDocument raise PdfError {
  let (document, id) = self.with_file_id(file_id~)
  let permissions = pdf_p_of_permissions(denied_permissions)
  let owner_entry = @crypt_core.pdf_make_owner_password_entry(
    revision, owner_password, user_password, key_length_bits,
  )
  let user_entry = @crypt_core.pdf_make_user_password_entry(
    false, user_password, revision, owner_entry, permissions, id, key_length_bits,
  )
  let file_key = @crypt_core.pdf_encryption_file_key(
    false, user_password, revision, owner_entry, permissions, id, key_length_bits,
  )
  let encrypted = document.arc4_crypt_parsed_objects(file_key, key_length_bits)
  let entries : Array[(PdfName, PdfObject)] = [
    (pdf_crypt_filter_name, PdfNameObject(pdf_crypt_standard_name)),
    (pdf_crypt_v_name, PdfInteger(version)),
    (pdf_crypt_r_name, PdfInteger(revision)),
    (pdf_crypt_o_name, PdfString(owner_entry)),
    (pdf_crypt_u_name, PdfString(user_entry)),
    (pdf_crypt_p_name, PdfInteger(permissions)),
  ]
  if write_length {
    entries.push((pdf_crypt_length_name, PdfInteger(key_length_bits)))
  }
  let encrypt_dictionary : PdfObject = PdfDictionary(entries)
  let encrypt_number = encrypted.add_object(encrypt_dictionary)
  encrypted.set_trailer_dict(
    encrypted
    .trailer_dict()
    .add_dict_entry(pdf_crypt_encrypt_name, PdfIndirect(encrypt_number)),
  )
  encrypted
}

///|
fn pdf_crypt_saved_arc4_dictionary(
  values : PdfEncryptionValues,
  key_length_bits : Int,
  revision : Int,
) -> PdfObject {
  if revision == 4 {
    let std_cf = pdf_crypt_std_cf_name
    PdfDictionary([
      (pdf_crypt_filter_name, PdfNameObject(pdf_crypt_standard_name)),
      (pdf_crypt_v_name, PdfInteger(4)),
      (
        pdf_crypt_cf_name,
        PdfDictionary([
          (
            std_cf,
            PdfDictionary([
              (pdf_crypt_length_name, PdfInteger(key_length_bits / 8)),
              (
                pdf_crypt_auth_event_name,
                PdfNameObject(pdf_crypt_doc_open_name),
              ),
              (pdf_crypt_cfm_name, PdfNameObject(pdf_crypt_v2_name)),
            ]),
          ),
        ]),
      ),
      (pdf_crypt_encrypt_metadata_name, PdfBoolean(values.encrypt_metadata)),
      (pdf_crypt_length_name, PdfInteger(key_length_bits)),
      (pdf_crypt_r_name, PdfInteger(4)),
      (pdf_crypt_o_name, PdfString(values.owner_entry)),
      (pdf_crypt_u_name, PdfString(values.user_entry)),
      (pdf_crypt_p_name, PdfInteger(values.permissions)),
      (pdf_crypt_strf_name, PdfNameObject(std_cf)),
      (pdf_crypt_stmf_name, PdfNameObject(std_cf)),
    ])
  } else {
    let entries : Array[(PdfName, PdfObject)] = [
      (pdf_crypt_filter_name, PdfNameObject(pdf_crypt_standard_name)),
      (
        pdf_crypt_v_name,
        PdfInteger(if revision == 2 && key_length_bits == 40 { 1 } else { 2 }),
      ),
      (pdf_crypt_r_name, PdfInteger(revision)),
      (pdf_crypt_o_name, PdfString(values.owner_entry)),
      (pdf_crypt_u_name, PdfString(values.user_entry)),
      (pdf_crypt_p_name, PdfInteger(values.permissions)),
    ]
    if key_length_bits != 40 {
      entries.push((pdf_crypt_length_name, PdfInteger(key_length_bits)))
    }
    PdfDictionary(entries)
  }
}

///|
fn pdf_crypt_saved_aesv2_dictionary(values : PdfEncryptionValues) -> PdfObject {
  let std_cf = pdf_crypt_std_cf_name
  PdfDictionary([
    (pdf_crypt_filter_name, PdfNameObject(pdf_crypt_standard_name)),
    (pdf_crypt_v_name, PdfInteger(4)),
    (
      pdf_crypt_cf_name,
      PdfDictionary([
        (
          std_cf,
          PdfDictionary([
            (pdf_crypt_length_name, PdfInteger(16)),
            (pdf_crypt_auth_event_name, PdfNameObject(pdf_crypt_doc_open_name)),
            (pdf_crypt_cfm_name, PdfNameObject(pdf_crypt_aesv2_name)),
          ]),
        ),
      ]),
    ),
    (pdf_crypt_encrypt_metadata_name, PdfBoolean(values.encrypt_metadata)),
    (pdf_crypt_length_name, PdfInteger(128)),
    (pdf_crypt_r_name, PdfInteger(4)),
    (pdf_crypt_o_name, PdfString(values.owner_entry)),
    (pdf_crypt_u_name, PdfString(values.user_entry)),
    (pdf_crypt_p_name, PdfInteger(values.permissions)),
    (pdf_crypt_strf_name, PdfNameObject(std_cf)),
    (pdf_crypt_stmf_name, PdfNameObject(std_cf)),
  ])
}

///|
fn pdf_crypt_saved_aesv3_dictionary(
  values : PdfEncryptionValues,
) -> PdfObject raise PdfError {
  let std_cf = pdf_crypt_std_cf_name
  let revision = match values.crypt_type {
    PdfCryptAESV3(true) => 6
    _ => 5
  }
  PdfDictionary([
    (pdf_crypt_filter_name, PdfNameObject(pdf_crypt_standard_name)),
    (pdf_crypt_v_name, PdfInteger(5)),
    (
      pdf_crypt_cf_name,
      PdfDictionary([
        (
          std_cf,
          PdfDictionary([
            (pdf_crypt_length_name, PdfInteger(32)),
            (pdf_crypt_auth_event_name, PdfNameObject(pdf_crypt_doc_open_name)),
            (pdf_crypt_cfm_name, PdfNameObject(pdf_crypt_aesv3_name)),
          ]),
        ),
      ]),
    ),
    (pdf_crypt_encrypt_metadata_name, PdfBoolean(values.encrypt_metadata)),
    (pdf_crypt_length_name, PdfInteger(256)),
    (pdf_crypt_r_name, PdfInteger(revision)),
    (pdf_crypt_o_name, PdfString(values.owner_entry)),
    (pdf_crypt_u_name, PdfString(values.user_entry)),
    (
      pdf_crypt_oe_name,
      PdfString(
        pdf_aesv3_crypt_entry(pdf_crypt_oe_name, values.owner_encryption_key),
      ),
    ),
    (
      pdf_crypt_ue_name,
      PdfString(
        pdf_aesv3_crypt_entry(pdf_crypt_ue_name, values.user_encryption_key),
      ),
    ),
    (
      pdf_aesv3_permissions_key(),
      PdfString(
        pdf_crypt_chop_string(
          pdf_aesv3_permissions_key(),
          match values.permissions_entry {
            Some(value) => value
            None =>
              raise EncryptionDictionaryEntryExpected(
                pdf_aesv3_permissions_key(),
              )
          },
          16,
        ),
      ),
    ),
    (pdf_crypt_p_name, PdfInteger(values.permissions)),
    (pdf_crypt_strf_name, PdfNameObject(std_cf)),
    (pdf_crypt_stmf_name, PdfNameObject(std_cf)),
  ])
}
