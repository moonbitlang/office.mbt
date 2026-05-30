///|
fn PdfDocument::encrypt_arc4_standard(
  self : PdfDocument,
  user_password : BytesView,
  owner_password : BytesView,
  denied_permissions : ArrayView[@crypt_core.PdfPermission],
  version : Int,
  revision : Int,
  key_length_bits : Int,
  write_length : Bool,
  file_id : BytesView,
) -> PdfDocument raise PdfError {
  let (document, id) = self.with_file_id(file_id~)
  let permissions = @crypt_core.pdf_p_of_permissions(denied_permissions)
  let owner_entry = @crypt_core.pdf_make_owner_password_entry(
    revision, owner_password, user_password, key_length_bits,
  )
  let user_entry = @crypt_core.pdf_make_user_password_entry(
    false, user_password, revision, owner_entry, permissions, id, key_length_bits,
  )
  let file_key = @crypt_core.pdf_encryption_file_key(
    false, user_password, revision, owner_entry, permissions, id, key_length_bits,
  )
  let encrypted = document.arc4_crypt_parsed_objects(
    file_key, key_length_bits, false, 0,
  )
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
