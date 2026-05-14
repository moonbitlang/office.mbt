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
fn crypt_wb_aesv3_r5_user_entry_for_test() -> PdfBytes {
  crypt_wb_bytes_for_test([
    0xad, 0x7c, 0x98, 0xe2, 0x51, 0xcb, 0x1c, 0x7b, 0x3e, 0x28, 0x30, 0xb6, 0xf0,
    0xbe, 0xcb, 0xd8, 0x35, 0x2a, 0x6a, 0xb7, 0x12, 0x23, 0x2d, 0x6e, 0x82, 0xf2,
    0xfc, 0xa4, 0x5f, 0x30, 0x4d, 0xcc, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
    0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f, 0x10,
  ])
}

///|
fn crypt_wb_aesv3_r5_owner_entry_for_test() -> PdfBytes {
  crypt_wb_bytes_for_test([
    0xf9, 0x90, 0x4f, 0x90, 0x02, 0x10, 0x0b, 0x3e, 0xba, 0x57, 0x69, 0x0b, 0x67,
    0x32, 0x30, 0xde, 0xfc, 0xcd, 0x12, 0x39, 0x9f, 0x8d, 0xa1, 0xa8, 0x73, 0x41,
    0x48, 0x36, 0x93, 0x7e, 0xbf, 0xf7, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17,
    0x18, 0x19, 0x1a, 0x1b, 0x1c, 0x1d, 0x1e, 0x1f, 0x20,
  ])
}

///|
fn crypt_wb_aesv3_r5_file_key_for_test() -> PdfBytes {
  crypt_wb_bytes_for_test([ for value in 0..<32 => value ])
}

///|
fn crypt_wb_aesv3_r5_user_encryption_key_for_test() -> PdfBytes {
  crypt_wb_bytes_for_test([
    0xe4, 0x35, 0xfd, 0x1c, 0x68, 0x70, 0xfc, 0x3b, 0x50, 0x7f, 0x7c, 0x3d, 0x30,
    0xd0, 0x2e, 0x06, 0xb7, 0x60, 0x68, 0x50, 0x81, 0x95, 0xc1, 0x29, 0x87, 0x9c,
    0x23, 0xce, 0x43, 0xee, 0xda, 0x22,
  ])
}

///|
fn crypt_wb_aesv3_r5_owner_encryption_key_for_test() -> PdfBytes {
  crypt_wb_bytes_for_test([
    0x93, 0x8a, 0x69, 0x29, 0xac, 0xa0, 0x6a, 0x79, 0x47, 0xde, 0x9d, 0xc4, 0x68,
    0x29, 0x04, 0xca, 0xda, 0x26, 0xbf, 0x1b, 0xb2, 0x8e, 0xc9, 0xc8, 0x2b, 0x83,
    0x9d, 0x5b, 0x89, 0x4e, 0x6c, 0xec,
  ])
}

///|
fn crypt_wb_aesv3_r5_permissions_for_test() -> PdfBytes {
  crypt_wb_bytes_for_test([
    0x61, 0x58, 0xb9, 0xdd, 0xf6, 0x26, 0xa8, 0xfa, 0x36, 0x68, 0x20, 0xad, 0x7e,
    0xd7, 0xde, 0x4d,
  ])
}

///|
fn crypt_wb_aesv3_r5_values_for_test() -> PdfEncryptionValues {
  {
    crypt_type: PdfCryptAESV3(false),
    user_entry: crypt_wb_aesv3_r5_user_entry_for_test(),
    owner_entry: crypt_wb_aesv3_r5_owner_entry_for_test(),
    permissions: -3904,
    file_id: @ascii.encode("doc-id"),
    encrypt_metadata: true,
    permissions_entry: Some(crypt_wb_aesv3_r5_permissions_for_test()),
    user_encryption_key: Some(crypt_wb_aesv3_r5_user_encryption_key_for_test()),
    owner_encryption_key: Some(
      crypt_wb_aesv3_r5_owner_encryption_key_for_test(),
    ),
  }
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
test "private encryption values derive raw file keys for authenticated passwords" {
  let arc4_doc = try! pdf_document_empty().encrypt_128bit(
    @ascii.encode("user"),
    @ascii.encode("owner"),
    pdf_permissions_of_p(-3904),
    file_id=@ascii.encode("doc-id"),
  )
  let arc4_values = try! arc4_doc.encryption_values()
  let arc4_key = try! arc4_values.file_key_for_user_password(
    @ascii.encode("user"),
  )
  guard arc4_key is Some(key) else { fail("expected ARC4 user file key") }
  @test.assert_eq(
    try! arc4_values.file_key_for_owner_password(@ascii.encode("owner")),
    Some(key),
  )
  @test.assert_eq(
    try! arc4_values.file_key_for_user_password(@ascii.encode("bad")),
    None,
  )
  @test.assert_eq(
    try! arc4_values.file_key_for_owner_password(@ascii.encode("bad")),
    None,
  )

  let aesv2_doc = try! pdf_document_empty().encrypt_128bit_aesv2_with_iv_provider(
    @ascii.encode("user"),
    @ascii.encode("owner"),
    pdf_permissions_of_p(-3904),
    fn(_, _, _) { Bytes::new(16) },
    file_id=@ascii.encode("doc-id"),
  )
  let aesv2_values = try! aesv2_doc.encryption_values()
  let aesv2_key_option = try! aesv2_values.file_key_for_user_password(
    @ascii.encode("user"),
  )
  guard aesv2_key_option is Some(aesv2_key) else {
    fail("expected AESV2 user file key")
  }
  @test.assert_eq(
    try! aesv2_values.file_key_for_owner_password(@ascii.encode("owner")),
    Some(aesv2_key),
  )
}

///|
test "private AESV3 encryption values derive fixture file keys" {
  let values = crypt_wb_aesv3_r5_values_for_test()
  @test.assert_eq(
    try! values.file_key_for_user_password(@ascii.encode("user")),
    Some(crypt_wb_aesv3_r5_file_key_for_test()),
  )
  @test.assert_eq(
    try! values.file_key_for_user_password(@ascii.encode("bad")),
    None,
  )
  @test.assert_eq(
    try! values.file_key_for_owner_password(@ascii.encode("owner")),
    Some(crypt_wb_aesv3_r5_file_key_for_test()),
  )
  @test.assert_eq(
    try! values.file_key_for_owner_password(@ascii.encode("bad")),
    None,
  )
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
test "private password padding helpers truncate and pad PDF passwords" {
  @test.assert_eq(pdf_password_padding().length(), 32)
  @test.assert_eq(pdf_password_padding()[0].to_int(), 0x28)
  @test.assert_eq(
    pdf_pad_password(@ascii.encode("abc")),
    crypt_wb_bytes_for_test([
      0x61, 0x62, 0x63, 0x28, 0xbf, 0x4e, 0x5e, 0x4e, 0x75, 0x8a, 0x41, 0x64, 0x00,
      0x4e, 0x56, 0xff, 0xfa, 0x01, 0x08, 0x2e, 0x2e, 0x00, 0xb6, 0xd0, 0x68, 0x3e,
      0x80, 0x2f, 0x0c, 0xa9, 0xfe, 0x64,
    ]),
  )
  @test.assert_eq(
    pdf_pad_password(@ascii.encode("012345678901234567890123456789012345")),
    @ascii.encode("01234567890123456789012345678901"),
  )
}

///|
test "private standard file key derivation matches CamlPDF R2 through R4" {
  let owner = crypt_wb_bytes_for_test([ for value in 0..<32 => value ])
  @test.assert_eq(
    pdf_encryption_file_key(
      false,
      @ascii.encode("user"),
      2,
      owner,
      -4,
      @ascii.encode("doc-id"),
      40,
    ),
    crypt_wb_bytes_for_test([0x09, 0xf0, 0x7c, 0x27, 0xf0]),
  )
  @test.assert_eq(
    pdf_encryption_file_key(
      false,
      Bytes::new(0),
      3,
      owner,
      -3904,
      @ascii.encode("doc-id"),
      128,
    ),
    crypt_wb_bytes_for_test([
      0x48, 0xd9, 0x52, 0xab, 0x8e, 0xdc, 0x9b, 0x82, 0xa0, 0x3a, 0xf2, 0x1c, 0xb1,
      0x6b, 0x61, 0x94,
    ]),
  )
  @test.assert_eq(
    pdf_encryption_file_key(
      true,
      Bytes::new(0),
      4,
      owner,
      -3904,
      @ascii.encode("doc-id"),
      128,
    ),
    crypt_wb_bytes_for_test([
      0x78, 0xcf, 0xeb, 0x72, 0x67, 0x35, 0x0d, 0x09, 0x98, 0xf4, 0xd4, 0xd5, 0x23,
      0x75, 0x5c, 0x12,
    ]),
  )
}

///|
test "private user password entries match CamlPDF U values" {
  let owner = crypt_wb_bytes_for_test([ for value in 0..<32 => value ])
  @test.assert_eq(
    try! pdf_make_user_password_entry(
      false,
      @ascii.encode("user"),
      2,
      owner,
      -4,
      @ascii.encode("doc-id"),
      40,
    ),
    crypt_wb_bytes_for_test([
      0x20, 0x54, 0x2f, 0x95, 0x6b, 0x5f, 0x5d, 0x84, 0x77, 0x36, 0x04, 0xf4, 0x9c,
      0x46, 0xfb, 0xdf, 0x57, 0x65, 0xe3, 0xa2, 0x96, 0x6c, 0xd3, 0x82, 0xb4, 0x96,
      0x0b, 0xd3, 0x77, 0xa3, 0x03, 0x41,
    ]),
  )
  @test.assert_eq(
    try! pdf_make_user_password_entry(
      false,
      Bytes::new(0),
      3,
      owner,
      -3904,
      @ascii.encode("doc-id"),
      128,
    ),
    crypt_wb_bytes_for_test([
      0x3d, 0xae, 0x18, 0x1a, 0x3c, 0x13, 0x8f, 0x79, 0xa6, 0xe2, 0xfa, 0x16, 0x86,
      0x96, 0x32, 0x9f, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
      0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    ]),
  )
  @test.assert_eq(
    try! pdf_make_user_password_entry(
      true,
      Bytes::new(0),
      4,
      owner,
      -3904,
      @ascii.encode("doc-id"),
      128,
    ),
    crypt_wb_bytes_for_test([
      0x93, 0x47, 0x7f, 0x4b, 0x13, 0x20, 0xa8, 0x08, 0x4f, 0x6a, 0x03, 0x20, 0xdc,
      0x1f, 0xd2, 0x9f, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
      0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    ]),
  )
}

///|
test "private user password entry handles MD5 padding boundary file IDs" {
  let owner = crypt_wb_bytes_for_test([ for value in 0..<32 => value ])
  let file_id = @ascii.encode("123456789012345678901234")
  @test.assert_eq(file_id.length(), 24)
  let user_entry = try! pdf_make_user_password_entry(
    false,
    @ascii.encode("user"),
    4,
    owner,
    -3904,
    file_id,
    128,
  )
  @test.assert_eq(user_entry.length(), 32)
  @test.assert_eq(
    pdf_encryption_file_key(
      false,
      @ascii.encode("user"),
      4,
      owner,
      -3904,
      file_id,
      128,
    ).length(),
    16,
  )
  let values : PdfEncryptionValues = {
    crypt_type: PdfCryptARC4(128, 4),
    user_entry,
    owner_entry: owner,
    permissions: -3904,
    file_id,
    encrypt_metadata: true,
    permissions_entry: None,
    user_encryption_key: None,
    owner_encryption_key: None,
  }
  @test.assert_eq(
    try! values.authenticate_user_password(@ascii.encode("user")),
    true,
  )
}

///|
test "private owner password entries match CamlPDF O values" {
  @test.assert_eq(
    try! pdf_make_owner_password_entry(
      2,
      @ascii.encode("owner"),
      @ascii.encode("user"),
      40,
    ),
    crypt_wb_bytes_for_test([
      0x94, 0xe8, 0x09, 0x44, 0x19, 0x66, 0x2a, 0x77, 0x44, 0x42, 0xfb, 0x07, 0x2e,
      0x3d, 0x9f, 0x19, 0xe9, 0xd1, 0x30, 0xec, 0x09, 0xa4, 0xd0, 0x06, 0x1e, 0x78,
      0xfe, 0x92, 0x0f, 0x7a, 0xb6, 0x2f,
    ]),
  )
  @test.assert_eq(
    try! pdf_make_owner_password_entry(
      3,
      @ascii.encode("owner"),
      Bytes::new(0),
      128,
    ),
    crypt_wb_bytes_for_test([
      0x56, 0x6f, 0xa8, 0x73, 0xee, 0x33, 0xc7, 0x97, 0xcd, 0x3b, 0x90, 0x4f, 0xda,
      0xdf, 0x81, 0x4a, 0xfa, 0x34, 0xdf, 0x9a, 0x38, 0xf6, 0xed, 0x41, 0xb9, 0x84,
      0xe2, 0xc6, 0xda, 0x2a, 0xa6, 0xf5,
    ]),
  )
  @test.assert_eq(
    try! pdf_make_owner_password_entry(
      2,
      Bytes::new(0),
      @ascii.encode("user"),
      40,
    ),
    crypt_wb_bytes_for_test([
      0x8e, 0xc9, 0x9e, 0x00, 0xc3, 0xd1, 0x84, 0x91, 0x0a, 0x40, 0x64, 0xdf, 0x0f,
      0x95, 0x16, 0xb0, 0x41, 0x36, 0x2b, 0x9b, 0xf1, 0xdc, 0x3f, 0x68, 0xd1, 0x5b,
      0xf7, 0x1f, 0xb1, 0x6d, 0xc5, 0xf3,
    ]),
  )
}

///|
test "private owner-password recovery returns padded user password" {
  let owner_entry = try! pdf_make_owner_password_entry(
    2,
    @ascii.encode("owner"),
    @ascii.encode("user"),
    40,
  )
  @test.assert_eq(
    try! pdf_user_password_from_owner_password(
      2,
      @ascii.encode("owner"),
      owner_entry,
      40,
    ),
    crypt_wb_bytes_for_test([
      0x75, 0x73, 0x65, 0x72, 0x28, 0xbf, 0x4e, 0x5e, 0x4e, 0x75, 0x8a, 0x41, 0x64,
      0x00, 0x4e, 0x56, 0xff, 0xfa, 0x01, 0x08, 0x2e, 0x2e, 0x00, 0xb6, 0xd0, 0x68,
      0x3e, 0x80, 0x2f, 0x0c, 0xa9, 0xfe,
    ]),
  )
  let owner_entry_r3 = try! pdf_make_owner_password_entry(
    3,
    @ascii.encode("owner"),
    Bytes::new(0),
    128,
  )
  @test.assert_eq(
    try! pdf_user_password_from_owner_password(
      3,
      @ascii.encode("owner"),
      owner_entry_r3,
      128,
    ),
    crypt_wb_bytes_for_test([
      0x28, 0xbf, 0x4e, 0x5e, 0x4e, 0x75, 0x8a, 0x41, 0x64, 0x00, 0x4e, 0x56, 0xff,
      0xfa, 0x01, 0x08, 0x2e, 0x2e, 0x00, 0xb6, 0xd0, 0x68, 0x3e, 0x80, 0x2f, 0x0c,
      0xa9, 0xfe, 0x64, 0x53, 0x69, 0x7a,
    ]),
  )
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
