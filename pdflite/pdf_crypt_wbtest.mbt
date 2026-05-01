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

///|
test "PdfDocument AESV2 decrypt preserves parser-private object states" {
  let key = try! pdf_bytes_of_int_array([ for value in 0..<16 => value ])
  let doc = pdf_document_empty()
  doc.objects.set_entry(
    1,
    pdf_object_entry(
      ObjectParsedAlreadyDecrypted(PdfString(@ascii.encode("plain"))),
    ),
  )
  doc.objects.set_entry(2, pdf_object_entry(ObjectToParse))
  doc.objects.set_entry(
    3,
    pdf_object_entry(
      ObjectToParseFromObjectStream({ object_stream_number: 7, index: 0 }),
    ),
  )
  let decrypted = try! doc.aesv2_decrypt_parsed_objects(key[:], 128)
  @test.assert_eq(decrypted.objects.get_entry(1), doc.objects.get_entry(1))
  @test.assert_eq(decrypted.objects.get_entry(2), doc.objects.get_entry(2))
  @test.assert_eq(decrypted.objects.get_entry(3), doc.objects.get_entry(3))
}
