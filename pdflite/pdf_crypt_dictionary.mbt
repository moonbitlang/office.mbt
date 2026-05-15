///|
fn pdf_crypt_arc4_v4_length(
  pdf : PdfDocument,
  encrypt_dictionary : PdfObject,
  cf_dictionary : PdfObject,
) -> Int? {
  match pdf_crypt_lookup_int(pdf, pdf_crypt_length_name, encrypt_dictionary) {
    Some(value) => Some(value)
    None => pdf_crypt_lookup_int(pdf, pdf_crypt_length_name, cf_dictionary)
  }
}

///|
fn pdf_crypt_type_from_encrypt_dictionary(
  pdf : PdfDocument,
  encrypt_dictionary : PdfObject,
) -> PdfCryptType? {
  let standard = pdf_crypt_standard_name
  let filter = pdf_crypt_lookup_name(
    pdf, pdf_crypt_filter_name, encrypt_dictionary,
  )
  let version = pdf_crypt_lookup_int(pdf, pdf_crypt_v_name, encrypt_dictionary)
  let length = pdf_crypt_lookup_int(
    pdf, pdf_crypt_length_name, encrypt_dictionary,
  )
  let revision = pdf_crypt_lookup_int(pdf, pdf_crypt_r_name, encrypt_dictionary)
  match (filter, version, length, revision) {
    (Some(name), Some(1), _, Some(revision)) if name == standard =>
      Some(PdfCryptARC4(40, revision))
    (Some(name), Some(2), None, Some(revision)) if name == standard =>
      Some(PdfCryptARC4(40, revision))
    (Some(name), Some(2), Some(length), _) if name == standard &&
      length % 8 == 0 &&
      length >= 40 &&
      length <= 128 => Some(PdfCryptARC4(length, 3))
    (Some(name), Some(version), _, Some(revision)) if name == standard &&
      (version == 4 || version == 5) =>
      match pdf.lookup_direct(pdf_crypt_cf_name, encrypt_dictionary) {
        Some(cf_dictionary) =>
          match pdf.lookup_direct(pdf_crypt_std_cf_name, cf_dictionary) {
            Some(std_cf_dictionary) =>
              match
                pdf_crypt_lookup_name(
                  pdf, pdf_crypt_cfm_name, std_cf_dictionary,
                ) {
                Some(cfm) if cfm == pdf_crypt_v2_name =>
                  match
                    pdf_crypt_arc4_v4_length(
                      pdf, encrypt_dictionary, cf_dictionary,
                    ) {
                    Some(length) => Some(PdfCryptARC4(length, 4))
                    None => None
                  }
                Some(cfm) if cfm == pdf_crypt_aesv2_name => Some(PdfCryptAESV2)
                Some(cfm) if cfm == pdf_crypt_aesv3_name =>
                  Some(PdfCryptAESV3(revision == 6))
                _ => None
              }
            None => None
          }
        None => None
      }
    _ => None
  }
}

///|
/// Parse the document trailer's `/Encrypt` dictionary.
///
/// The returned value contains the normalized security-handler parameters
/// needed for authentication and object crypt. Missing encryption dictionaries,
/// unsupported handlers, malformed `/O` or `/U` entries, and missing trailer
/// `/ID` values raise `PdfError`.
fn PdfDocument::encryption_values(
  self : PdfDocument,
) -> PdfEncryptionValues raise PdfError {
  let encrypt_key = pdf_crypt_encrypt_name
  let encrypt_dictionary = match
    self.lookup_direct(encrypt_key, self.trailer_dict()) {
    Some(value) => value
    None => raise PdfError::EncryptionExpected
  }
  let crypt_type = match
    pdf_crypt_type_from_encrypt_dictionary(self, encrypt_dictionary) {
    Some(value) => value
    None => raise PdfError::EncryptionMethodExpected
  }
  let user_owner_length = match crypt_type {
    PdfCryptAESV3(_) => 48
    _ => 32
  }
  let owner_key = pdf_crypt_o_name
  let user_key = pdf_crypt_u_name
  let id_key = pdf_crypt_id_name
  let owner_entry = pdf_crypt_chop_string(
    owner_key,
    pdf_crypt_required_string(self, owner_key, encrypt_dictionary),
    user_owner_length,
  )
  let user_entry = pdf_crypt_chop_string(
    user_key,
    pdf_crypt_required_string(self, user_key, encrypt_dictionary),
    user_owner_length,
  )
  let permissions = pdf_crypt_required_int(
    self, pdf_crypt_p_name, encrypt_dictionary,
  )
  let file_id = match self.lookup_direct(id_key, self.trailer_dict()) {
    Some(PdfArray([PdfString(file_id), _])) => file_id
    _ => raise PdfError::EncryptionIDExpected
  }
  let encrypt_metadata = match
    self.lookup_direct(pdf_crypt_encrypt_metadata_name, encrypt_dictionary) {
    Some(PdfBoolean(false)) => false
    _ => true
  }
  {
    crypt_type,
    user_entry,
    owner_entry,
    permissions,
    file_id,
    encrypt_metadata,
    permissions_entry: pdf_crypt_lookup_string(
      self, pdf_crypt_perms_name, encrypt_dictionary,
    ),
    user_encryption_key: pdf_crypt_lookup_string(
      self, pdf_crypt_ue_name, encrypt_dictionary,
    ),
    owner_encryption_key: pdf_crypt_lookup_string(
      self, pdf_crypt_oe_name, encrypt_dictionary,
    ),
  }
}

///|
/// Return true when the trailer contains an `/Encrypt` entry.
pub fn PdfDocument::is_encrypted(self : PdfDocument) -> Bool {
  self.lookup_direct(pdf_crypt_encrypt_name, self.trailer_dict()) != None
}

///|
/// Return the document encryption method, or `None` for unencrypted documents.
///
/// Unknown or unsupported encryption dictionaries may also return `None` after
/// the dictionary has been parsed.
pub fn PdfDocument::what_encryption(
  self : PdfDocument,
) -> PdfEncryptionMethod? raise PdfError {
  if self.is_encrypted() {
    let values = self.encryption_values()
    match values.crypt_type {
      PdfCryptARC4(40, _) => Some(PdfEncryption40Bit)
      PdfCryptARC4(128, _) => Some(PdfEncryption128Bit)
      PdfCryptAESV2 => Some(PdfEncryptionAES128(values.encrypt_metadata))
      PdfCryptAESV3(false) => Some(PdfEncryptionAES256(values.encrypt_metadata))
      PdfCryptAESV3(true) =>
        Some(PdfEncryptionAES256ISO(values.encrypt_metadata))
      _ => None
    }
  } else {
    None
  }
}

///|
/// Decode the denied permissions from the document encryption dictionary.
///
/// Unencrypted documents return an empty array. Encrypted documents parse
/// `/Encrypt` and may raise if the encryption dictionary is malformed.
pub fn PdfDocument::permissions(
  self : PdfDocument,
) -> Array[PdfPermission] raise PdfError {
  if self.is_encrypted() {
    pdf_permissions_of_p(self.encryption_values().permissions)
  } else {
    []
  }
}
