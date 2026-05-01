// Whitebox tests for private encryption guards.

///|
fn crypt_wb_bytes_for_test(values : ArrayView[Int]) -> PdfBytes {
  try! pdf_bytes_of_int_array(values)
}

///|
fn crypt_wb_iv_for_test(index : Int) -> PdfBytes {
  crypt_wb_bytes_for_test(
    [
      for offset in 0..<16 => 0x30 + index * 16 + offset
    ],
  )
}

///|
test "private encryption password settings reject AESV3" {
  let values : PdfEncryptionValues = {
    crypt_type: PdfCryptAESV3(false),
    user_entry: Bytes::new(0),
    owner_entry: Bytes::new(0),
    permissions: 0,
    file_id: Bytes::new(0),
    encrypt_metadata: true,
    permissions_entry: None,
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
test "PdfDocument AESV2 encrypt preserves parser-private object states" {
  let key = crypt_wb_bytes_for_test([ for value in 0..<16 => value ])
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
  let encrypted = try! doc.aesv2_encrypt_parsed_objects_with_iv_provider(
    key[:],
    128,
    fn(_, _, index) { crypt_wb_iv_for_test(index) },
  )
  @test.assert_eq(encrypted.objects.get_entry(1), doc.objects.get_entry(1))
  @test.assert_eq(encrypted.objects.get_entry(2), doc.objects.get_entry(2))
  @test.assert_eq(encrypted.objects.get_entry(3), doc.objects.get_entry(3))
}

///|
test "PdfDocument AESV2 decrypt preserves parser-private object states" {
  let key = crypt_wb_bytes_for_test([ for value in 0..<16 => value ])
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

///|
test "PdfDocument AESV3 encrypt recurses and preserves parser-private object states" {
  let key = crypt_wb_bytes_for_test([ for value in 0..<32 => value ])
  let doc = pdf_document_empty()
  doc.add_object_given_number(1, PdfString(@ascii.encode("secret")))
  doc.objects.set_entry(
    2,
    pdf_object_entry(
      ObjectParsedAlreadyDecrypted(PdfString(@ascii.encode("plain"))),
    ),
  )
  doc.objects.set_entry(3, pdf_object_entry(ObjectToParse))
  doc.objects.set_entry(
    4,
    pdf_object_entry(
      ObjectToParseFromObjectStream({ object_stream_number: 7, index: 0 }),
    ),
  )
  let encrypted = try! doc.aesv3_encrypt_parsed_objects_with_iv_provider(
    key[:],
    fn(_, _, index) { crypt_wb_iv_for_test(index) },
  )
  @test.assert_eq(
    try! pdf_aesv3_decrypt_pdf_object(
      key[:],
      encrypted.lookup_object_or_null(1),
    ),
    PdfString(@ascii.encode("secret")),
  )
  @test.assert_eq(encrypted.objects.get_entry(2), doc.objects.get_entry(2))
  @test.assert_eq(encrypted.objects.get_entry(3), doc.objects.get_entry(3))
  @test.assert_eq(encrypted.objects.get_entry(4), doc.objects.get_entry(4))
}

///|
test "PdfDocument AESV3 decrypt preserves parser-private object states" {
  let key = crypt_wb_bytes_for_test([ for value in 0..<32 => value ])
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
  let decrypted = try! doc.aesv3_decrypt_parsed_objects(key[:])
  @test.assert_eq(decrypted.objects.get_entry(1), doc.objects.get_entry(1))
  @test.assert_eq(decrypted.objects.get_entry(2), doc.objects.get_entry(2))
  @test.assert_eq(decrypted.objects.get_entry(3), doc.objects.get_entry(3))
}

///|
test "private AESV3 saved dictionary requires permissions entry" {
  let values : PdfEncryptionValues = {
    crypt_type: PdfCryptAESV3(false),
    user_entry: Bytes::new(48),
    owner_entry: Bytes::new(48),
    permissions: -3904,
    file_id: @ascii.encode("doc-id"),
    encrypt_metadata: true,
    permissions_entry: None,
    user_encryption_key: Some(Bytes::new(32)),
    owner_encryption_key: Some(Bytes::new(32)),
  }
  let result : Result[PdfObject, Error] = try? pdf_crypt_saved_aesv3_dictionary(
    values,
  )
  match result {
    Err(PdfError::EncryptionDictionaryEntryExpected(key)) =>
      @test.assert_eq(key, pdf_aesv3_permissions_key())
    _ => fail("expected missing AESV3 permissions entry")
  }
}

///|
test "private AESV3 CBC no-padding encryption rejects partial blocks" {
  let key = crypt_wb_bytes_for_test([ for value in 0..<32 => value ])
  let result : Result[PdfBytes, Error] = try? pdf_aesv3_cbc_encrypt_no_padding(
    key[:],
    @ascii.encode("x")[:],
  )
  guard result is Err(PdfError::InvalidCryptoDataLength(1)) else {
    fail("expected invalid AESV3 CBC data length")
  }
}

///|
test "private document decrypt reports unsupported ISO AESV3 object crypt" {
  let values : PdfEncryptionValues = {
    crypt_type: PdfCryptAESV3(true),
    user_entry: Bytes::new(0),
    owner_entry: Bytes::new(0),
    permissions: 0,
    file_id: Bytes::new(0),
    encrypt_metadata: true,
    permissions_entry: None,
    user_encryption_key: None,
    owner_encryption_key: None,
  }
  let file_key = crypt_wb_bytes_for_test([ for value in 0..<32 => value ])
  let result : Result[PdfDecryptionResult, Error] = try? pdf_document_empty().decrypt_with_file_key(
    values, file_key,
  )
  guard result
    is Err(PdfError::EncryptionObjectCryptUnsupported(PdfCryptAESV3(true))) else {
    fail("expected unsupported ISO AESV3 object crypt")
  }
}
