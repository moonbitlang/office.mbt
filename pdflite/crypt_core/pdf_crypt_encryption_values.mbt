///|
/// Parsed standard-security-handler values from an encryption dictionary.
///
/// Password entries, permission masks, file IDs, and optional AESV3 wrapping
/// entries are stored as PDF bytes. `crypt_type` describes the actual object
/// encryption algorithm used for strings and streams.
///
/// This is shared security state: it is parsed by the document crypt code and
/// retained on a decrypted document (`PdfSavedEncryption`), so it lives in the
/// low-level `crypt_core` package that the document core can depend on without a
/// cycle. Fields are public so the (still root-resident) crypt logic can build
/// and read them across the package boundary.
pub(all) struct PdfEncryptionValues {
  crypt_type : @core.PdfCryptType
  user_entry : @core.PdfBytes
  owner_entry : @core.PdfBytes
  permissions : Int
  file_id : @core.PdfBytes
  encrypt_metadata : Bool
  permissions_entry : @core.PdfBytes?
  user_encryption_key : @core.PdfBytes?
  owner_encryption_key : @core.PdfBytes?
} derive(Debug, Eq)

///|
/// Saved encryption state retained on a decrypted document.
///
/// Recrypt helpers use this to put a previously encrypted document back into
/// its original security-handler shape after edits.
pub(all) struct PdfSavedEncryption {
  values : PdfEncryptionValues
} derive(Debug, Eq)
