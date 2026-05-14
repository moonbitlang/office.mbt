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
    key,
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
  let decrypted = try! doc.aesv2_decrypt_parsed_objects(key, 128)
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
  let encrypted = try! doc.aesv3_encrypt_parsed_objects_with_iv_provider(key, fn(
    _,
    _,
    index,
  ) {
    crypt_wb_iv_for_test(index)
  })
  @test.assert_eq(
    try! pdf_aesv3_decrypt_pdf_object(key, encrypted.lookup_object_or_null(1)),
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
  let decrypted = try! doc.aesv3_decrypt_parsed_objects(key)
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
    key,
    @ascii.encode("x"),
  )
  guard result is Err(PdfError::InvalidCryptoDataLength(1)) else {
    fail("expected invalid AESV3 CBC data length")
  }
}

///|
test "private document decrypt supports ISO AESV3 object crypt with a file key" {
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
  let doc = pdf_document_empty()
  let secret : PdfObject = PdfString(@ascii.encode("revision 6 secret"))
  let encrypted = try! pdf_aesv3_encrypt_pdf_object_with_iv_provider(
    file_key,
    secret,
    fn(index) { crypt_wb_iv_for_test(index) },
  )
  doc.add_object_given_number(1, encrypted)
  let decrypted = try! doc.decrypt_with_file_key(values, file_key)
  @test.assert_eq(decrypted.document.lookup_object_or_null(1), secret)
}

///|
test "private AESV2 object data uses object key and IV prefix" {
  let file_key = crypt_wb_bytes_for_test([ for value in 0..<16 => value ])
  let iv = crypt_wb_bytes_for_test([
    0x20, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27, 0x28, 0x29, 0x2a, 0x2b, 0x2c,
    0x2d, 0x2e, 0x2f,
  ])
  let data = @ascii.encode("hello")
  let encrypted = try! pdf_aesv2_encrypt_object_data(
    12, 0, file_key, 128, data, iv,
  )
  let object_key = crypt_wb_bytes_for_test([
    0x70, 0x06, 0x4f, 0xbf, 0x73, 0x41, 0xdd, 0x2a, 0x2b, 0xf2, 0x8a, 0xd4, 0xce,
    0xf2, 0xd8, 0xd5,
  ])
  @test.assert_eq(
    encrypted,
    try! pdf_aes_cbc_encrypt_with_iv(object_key, iv, data),
  )
  @test.assert_eq(encrypted[:16], iv)
  @test.assert_eq(
    try! pdf_aesv2_decrypt_object_data(12, 0, file_key, 128, encrypted),
    data,
  )
}

///|
test "private AESV3 object data uses file key and IV prefix" {
  let file_key = crypt_wb_bytes_for_test([ for value in 0..<32 => value ])
  let iv = crypt_wb_bytes_for_test([
    0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x3a, 0x3b, 0x3c,
    0x3d, 0x3e, 0x3f,
  ])
  let data = @ascii.encode("hello")
  let encrypted = try! pdf_aesv3_encrypt_object_data(file_key, data, iv)
  @test.assert_eq(
    encrypted,
    try! pdf_aes_cbc_encrypt_with_iv(file_key, iv, data),
  )
  @test.assert_eq(encrypted[:16], iv)
  @test.assert_eq(try! pdf_aesv3_decrypt_object_data(file_key, encrypted), data)
}

///|
test "private object key derivation matches CamlPDF Algorithm 3.1" {
  @test.assert_eq(
    pdf_encryption_object_key(
      PdfCryptARC4(40, 2),
      12,
      0,
      crypt_wb_bytes_for_test([1, 2, 3, 4, 5]),
      40,
    ),
    crypt_wb_bytes_for_test([
      0x1e, 0x30, 0xc8, 0x8e, 0x24, 0x47, 0x1b, 0x28, 0x1f, 0x19,
    ]),
  )
  let key128 = crypt_wb_bytes_for_test([
    0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15,
  ])
  @test.assert_eq(
    pdf_encryption_object_key(PdfCryptARC4(128, 3), 65537, 2, key128, 128),
    crypt_wb_bytes_for_test([
      0xab, 0xa1, 0xa7, 0x87, 0x99, 0x05, 0xa0, 0x15, 0x56, 0xf0, 0xf5, 0x74, 0xaa,
      0x57, 0x5d, 0x8b,
    ]),
  )
  @test.assert_eq(
    pdf_encryption_object_key(PdfCryptAESV2, 65537, 2, key128, 128),
    crypt_wb_bytes_for_test([
      0x42, 0x0e, 0x4b, 0x00, 0xf8, 0x95, 0x95, 0x78, 0x19, 0xf2, 0xff, 0x83, 0x4b,
      0x41, 0x14, 0x61,
    ]),
  )
}

///|
test "private ARC4 object crypt applies derived object key" {
  let file_key = crypt_wb_bytes_for_test([1, 2, 3, 4, 5])
  let encrypted = try! pdf_arc4_crypt_object(
    12,
    0,
    file_key,
    40,
    @ascii.encode("hello"),
  )
  @test.assert_eq(
    encrypted,
    crypt_wb_bytes_for_test([0x7d, 0x1c, 0x38, 0x4c, 0xca]),
  )
  @test.assert_eq(
    try! pdf_arc4_crypt_object(12, 0, file_key, 40, encrypted),
    @ascii.encode("hello"),
  )
}
