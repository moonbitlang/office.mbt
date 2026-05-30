///|
/// Encrypt a copy of the document with revision-4 128-bit ARC4.
///
/// This writes a crypt-filter dictionary using `/V2`. `encrypt_metadata=false`
/// follows the revision-4 no-metadata key derivation and stream policy.
pub fn PdfDocument::encrypt_128bit_r4(
  self : PdfDocument,
  user_password : BytesView,
  owner_password : BytesView,
  denied_permissions : ArrayView[@crypt_core.PdfPermission],
  encrypt_metadata? : Bool = true,
  file_id? : BytesView = [],
) -> PdfDocument raise PdfError {
  let no_encrypt_metadata = !encrypt_metadata
  let (document, id) = self.with_file_id(file_id~)
  let permissions = @crypt_core.pdf_p_of_permissions(denied_permissions)
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
    file_key, 128, no_encrypt_metadata, 0,
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
  denied_permissions : ArrayView[@crypt_core.PdfPermission],
  iv_provider : (Int, Int, Int) -> PdfBytes raise PdfError,
  encrypt_metadata? : Bool = true,
  file_id? : BytesView = [],
) -> PdfDocument raise PdfError {
  let no_encrypt_metadata = !encrypt_metadata
  let (document, id) = self.with_file_id(file_id~)
  let permissions = @crypt_core.pdf_p_of_permissions(denied_permissions)
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
    file_key, 128, iv_provider, no_encrypt_metadata,
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
