// Whitebox tests for private encryption guards.

///|
test "private encryption password settings reject AESV3" {
  let values : PdfEncryptionValues = {
    crypt_type: PdfCryptAESV3(false),
    user_entry: Bytes::new(0),
    owner_entry: Bytes::new(0),
    permissions: 0,
    file_id: Bytes::new(0),
    user_encryption_key: None,
    owner_encryption_key: None,
  }
  let result : Result[(Int, Int), Error] = try? values.password_settings()
  guard result
    is Err(PdfError::EncryptionAuthenticationUnsupported(PdfCryptAESV3(false))) else {
    fail("expected unsupported AESV3 password settings")
  }
}
