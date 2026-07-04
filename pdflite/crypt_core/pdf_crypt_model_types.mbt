///|
/// Encryption method detected from or requested for a document.
///
/// AES entries carry the effective `EncryptMetadata` flag. The
/// `PdfEncryptionAlreadyEncrypted` value is used by writer paths that preserve
/// existing encrypted object data rather than decrypting and re-encrypting it.
pub(all) enum PdfEncryptionMethod {
  PdfEncryption40Bit
  PdfEncryption128Bit
  PdfEncryptionAES128(Bool)
  PdfEncryptionAES256(Bool)
  PdfEncryptionAES256ISO(Bool)
  PdfEncryptionAlreadyEncrypted
} derive(Debug, Eq, ToJson)

///|
/// Random material requested while constructing PDF 2.0 AESV3 encryption data.
///
/// Provider callbacks receive this field tag and a byte length, allowing tests
/// and reproducible builds to supply deterministic file keys, salts, and
/// permissions padding.
pub(all) enum PdfAesV3RandomField {
  PdfAesV3FileKey
  PdfAesV3UserValidationSalt
  PdfAesV3UserKeySalt
  PdfAesV3OwnerValidationSalt
  PdfAesV3OwnerKeySalt
  PdfAesV3PermissionsPadding
} derive(Debug, Eq, ToJson)
