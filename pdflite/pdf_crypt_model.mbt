///|
/// Parsed standard-security-handler values from an encryption dictionary.
///
/// Password entries, permission masks, file IDs, and optional AESV3 wrapping
/// entries are stored as PDF bytes. `crypt_type` describes the actual object
/// encryption algorithm used for strings and streams.
struct PdfEncryptionValues {
  crypt_type : PdfCryptType
  user_entry : PdfBytes
  owner_entry : PdfBytes
  permissions : Int
  file_id : PdfBytes
  encrypt_metadata : Bool
  permissions_entry : PdfBytes?
  user_encryption_key : PdfBytes?
  owner_encryption_key : PdfBytes?
} derive(Debug, Eq, ToJson)

///|
/// Saved encryption state retained on a decrypted document.
///
/// Recrypt helpers use this to put a previously encrypted document back into
/// its original security-handler shape after edits.
struct PdfSavedEncryption {
  values : PdfEncryptionValues
} derive(Debug, Eq, ToJson)

///|
/// Result of successfully decrypting a document.
///
/// `document` is a decrypted copy with encryption removed from the trailer and
/// saved encryption state attached. `denied_permissions` is decoded from the
/// original `/P` permission mask.
pub(all) struct PdfDecryptionResult {
  document : PdfDocument
  denied_permissions : Array[PdfPermission]
} derive(Debug, Eq, ToJson)

///|
fn pdf_crypt_name(text : String) -> PdfName {
  pdf_name_of_bytes(@ascii.encode(text))
}

///|
let pdf_crypt_length_name : PdfName = pdf_crypt_name("/Length")

///|
let pdf_crypt_encrypt_name : PdfName = pdf_crypt_name("/Encrypt")

///|
let pdf_crypt_u_name : PdfName = pdf_crypt_name("/U")

///|
let pdf_crypt_o_name : PdfName = pdf_crypt_name("/O")

///|
let pdf_crypt_filter_name : PdfName = pdf_crypt_name("/Filter")

///|
let pdf_crypt_v_name : PdfName = pdf_crypt_name("/V")

///|
let pdf_crypt_standard_name : PdfName = pdf_crypt_name("/Standard")

///|
let pdf_crypt_r_name : PdfName = pdf_crypt_name("/R")

///|
let pdf_crypt_p_name : PdfName = pdf_crypt_name("/P")

///|
let pdf_crypt_std_cf_name : PdfName = pdf_crypt_name("/StdCF")

///|
let pdf_crypt_encrypt_metadata_name : PdfName = pdf_crypt_name(
  "/EncryptMetadata",
)

///|
let pdf_crypt_cfm_name : PdfName = pdf_crypt_name("/CFM")

///|
let pdf_crypt_cf_name : PdfName = pdf_crypt_name("/CF")

///|
let pdf_crypt_strf_name : PdfName = pdf_crypt_name("/StrF")

///|
let pdf_crypt_stmf_name : PdfName = pdf_crypt_name("/StmF")

///|
let pdf_crypt_doc_open_name : PdfName = pdf_crypt_name("/DocOpen")

///|
let pdf_crypt_auth_event_name : PdfName = pdf_crypt_name("/AuthEvent")

///|
let pdf_crypt_ue_name : PdfName = pdf_crypt_name("/UE")

///|
let pdf_crypt_oe_name : PdfName = pdf_crypt_name("/OE")

///|
let pdf_crypt_v2_name : PdfName = pdf_crypt_name("/V2")

///|
let pdf_crypt_id_name : PdfName = pdf_crypt_name("/ID")

///|
let pdf_crypt_aesv2_name : PdfName = pdf_crypt_name("/AESV2")

///|
let pdf_crypt_perms_name : PdfName = pdf_crypt_name("/Perms")

///|
let pdf_crypt_crypt_name : PdfName = pdf_crypt_name("/Crypt")

///|
let pdf_crypt_aesv3_name : PdfName = pdf_crypt_name("/AESV3")

///|
let pdf_crypt_user_validation_salt_name : PdfName = pdf_crypt_name(
  "/UserValidationSalt",
)

///|
let pdf_crypt_user_key_salt_name : PdfName = pdf_crypt_name("/UserKeySalt")

///|
let pdf_crypt_type_name : PdfName = pdf_crypt_name("/Type")

///|
let pdf_crypt_metadata_name : PdfName = pdf_crypt_name("/Metadata")

///|
let pdf_crypt_perms_padding_name : PdfName = pdf_crypt_name("/PermsPadding")

///|
let pdf_crypt_owner_validation_salt_name : PdfName = pdf_crypt_name(
  "/OwnerValidationSalt",
)

///|
let pdf_crypt_owner_key_salt_name : PdfName = pdf_crypt_name("/OwnerKeySalt")

///|
let pdf_crypt_name_key_name : PdfName = pdf_crypt_name("/Name")

///|
let pdf_crypt_identity_name : PdfName = pdf_crypt_name("/Identity")

///|
let pdf_crypt_iv_name : PdfName = pdf_crypt_name("/IV")

///|
let pdf_crypt_file_key_name : PdfName = pdf_crypt_name("/FileKey")

///|
let pdf_crypt_decodeparms_name : PdfName = pdf_crypt_name("/DecodeParms")

///|
fn pdf_crypt_lookup_name(
  pdf : PdfDocument,
  key : PdfName,
  dictionary : PdfObject,
) -> PdfName? {
  match pdf.lookup_direct(key, dictionary) {
    Some(PdfNameObject(name)) => Some(name)
    _ => None
  }
}

///|
fn pdf_crypt_lookup_int(
  pdf : PdfDocument,
  key : PdfName,
  dictionary : PdfObject,
) -> Int? {
  match pdf.lookup_direct(key, dictionary) {
    Some(PdfInteger(value)) => Some(value)
    _ => None
  }
}

///|
fn pdf_crypt_lookup_string(
  pdf : PdfDocument,
  key : PdfName,
  dictionary : PdfObject,
) -> PdfBytes? {
  match pdf.lookup_direct(key, dictionary) {
    Some(PdfString(value)) => Some(value)
    _ => None
  }
}

///|
fn pdf_crypt_required_string(
  pdf : PdfDocument,
  key : PdfName,
  dictionary : PdfObject,
) -> PdfBytes raise PdfError {
  match pdf_crypt_lookup_string(pdf, key, dictionary) {
    Some(value) => value
    None => raise EncryptionDictionaryEntryExpected(key)
  }
}

///|
fn pdf_crypt_required_int(
  pdf : PdfDocument,
  key : PdfName,
  dictionary : PdfObject,
) -> Int raise PdfError {
  match pdf_crypt_lookup_int(pdf, key, dictionary) {
    Some(value) => value
    None => raise EncryptionDictionaryEntryExpected(key)
  }
}

///|
fn pdf_crypt_chop_string(
  key : PdfName,
  value : PdfBytes,
  need : Int,
) -> PdfBytes raise PdfError {
  pdf_crypt_chop_view(key, value, need)
}

///|
fn pdf_crypt_chop_view(
  key : PdfName,
  value : BytesView,
  need : Int,
) -> PdfBytes raise PdfError {
  if value.length() < need {
    raise EncryptionDictionaryEntryTooShort(key)
  }
  value[:need].to_owned()
}
