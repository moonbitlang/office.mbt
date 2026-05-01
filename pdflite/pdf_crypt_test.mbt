///|
fn crypt_model_bytes_for_test(values : ArrayView[Int]) -> @pdflite.PdfBytes {
  try! @pdflite.pdf_bytes_of_int_array(values)
}

///|
test "pdf_pad_password truncates or pads with PDF password padding" {
  @test.assert_eq(@pdflite.pdf_password_padding().length(), 32)
  @test.assert_eq(@pdflite.pdf_password_padding()[0].to_int(), 0x28)
  @test.assert_eq(
    @pdflite.pdf_pad_password(@ascii.encode("abc")[:]),
    crypt_model_bytes_for_test([
      0x61, 0x62, 0x63, 0x28, 0xbf, 0x4e, 0x5e, 0x4e, 0x75, 0x8a, 0x41, 0x64, 0x00,
      0x4e, 0x56, 0xff, 0xfa, 0x01, 0x08, 0x2e, 0x2e, 0x00, 0xb6, 0xd0, 0x68, 0x3e,
      0x80, 0x2f, 0x0c, 0xa9, 0xfe, 0x64,
    ]),
  )
  @test.assert_eq(
    @pdflite.pdf_pad_password(
      @ascii.encode("012345678901234567890123456789012345")[:],
    ),
    @ascii.encode("01234567890123456789012345678901"),
  )
}

///|
test "pdf_encryption_file_key matches CamlPDF R2 through R4 derivation" {
  let owner = crypt_model_bytes_for_test([ for value in 0..<32 => value ])
  @test.assert_eq(
    @pdflite.pdf_encryption_file_key(
      false,
      @ascii.encode("user")[:],
      2,
      owner[:],
      -4,
      @ascii.encode("doc-id")[:],
      40,
    ),
    crypt_model_bytes_for_test([0x09, 0xf0, 0x7c, 0x27, 0xf0]),
  )
  @test.assert_eq(
    @pdflite.pdf_encryption_file_key(
      false,
      Bytes::new(0)[:],
      3,
      owner[:],
      -3904,
      @ascii.encode("doc-id")[:],
      128,
    ),
    crypt_model_bytes_for_test([
      0x48, 0xd9, 0x52, 0xab, 0x8e, 0xdc, 0x9b, 0x82, 0xa0, 0x3a, 0xf2, 0x1c, 0xb1,
      0x6b, 0x61, 0x94,
    ]),
  )
  @test.assert_eq(
    @pdflite.pdf_encryption_file_key(
      true,
      Bytes::new(0)[:],
      4,
      owner[:],
      -3904,
      @ascii.encode("doc-id")[:],
      128,
    ),
    crypt_model_bytes_for_test([
      0x78, 0xcf, 0xeb, 0x72, 0x67, 0x35, 0x0d, 0x09, 0x98, 0xf4, 0xd4, 0xd5, 0x23,
      0x75, 0x5c, 0x12,
    ]),
  )
}

///|
test "pdf_make_user_password_entry matches CamlPDF U values" {
  let owner = crypt_model_bytes_for_test([ for value in 0..<32 => value ])
  @test.assert_eq(
    try! @pdflite.pdf_make_user_password_entry(
      false,
      @ascii.encode("user")[:],
      2,
      owner[:],
      -4,
      @ascii.encode("doc-id")[:],
      40,
    ),
    crypt_model_bytes_for_test([
      0x20, 0x54, 0x2f, 0x95, 0x6b, 0x5f, 0x5d, 0x84, 0x77, 0x36, 0x04, 0xf4, 0x9c,
      0x46, 0xfb, 0xdf, 0x57, 0x65, 0xe3, 0xa2, 0x96, 0x6c, 0xd3, 0x82, 0xb4, 0x96,
      0x0b, 0xd3, 0x77, 0xa3, 0x03, 0x41,
    ]),
  )
  @test.assert_eq(
    try! @pdflite.pdf_make_user_password_entry(
      false,
      Bytes::new(0)[:],
      3,
      owner[:],
      -3904,
      @ascii.encode("doc-id")[:],
      128,
    ),
    crypt_model_bytes_for_test([
      0x3d, 0xae, 0x18, 0x1a, 0x3c, 0x13, 0x8f, 0x79, 0xa6, 0xe2, 0xfa, 0x16, 0x86,
      0x96, 0x32, 0x9f, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
      0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    ]),
  )
  @test.assert_eq(
    try! @pdflite.pdf_make_user_password_entry(
      true,
      Bytes::new(0)[:],
      4,
      owner[:],
      -3904,
      @ascii.encode("doc-id")[:],
      128,
    ),
    crypt_model_bytes_for_test([
      0x93, 0x47, 0x7f, 0x4b, 0x13, 0x20, 0xa8, 0x08, 0x4f, 0x6a, 0x03, 0x20, 0xdc,
      0x1f, 0xd2, 0x9f, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
      0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    ]),
  )
}

///|
test "pdf_authenticate_user_password validates R2 and R3 user entries" {
  let owner = crypt_model_bytes_for_test([ for value in 0..<32 => value ])
  let r2_entry = try! @pdflite.pdf_make_user_password_entry(
    false,
    @ascii.encode("user")[:],
    2,
    owner[:],
    -4,
    @ascii.encode("doc-id")[:],
    40,
  )
  @test.assert_eq(
    try! @pdflite.pdf_authenticate_user_password(
      false,
      @ascii.encode("user")[:],
      2,
      r2_entry[:],
      owner[:],
      -4,
      @ascii.encode("doc-id")[:],
      40,
    ),
    true,
  )
  @test.assert_eq(
    try! @pdflite.pdf_authenticate_user_password(
      false,
      @ascii.encode("bad")[:],
      2,
      r2_entry[:],
      owner[:],
      -4,
      @ascii.encode("doc-id")[:],
      40,
    ),
    false,
  )
  let r3_entry = try! @pdflite.pdf_make_user_password_entry(
    false,
    Bytes::new(0)[:],
    3,
    owner[:],
    -3904,
    @ascii.encode("doc-id")[:],
    128,
  )
  @test.assert_eq(
    try! @pdflite.pdf_authenticate_user_password(
      false,
      Bytes::new(0)[:],
      3,
      r3_entry[:16],
      owner[:],
      -3904,
      @ascii.encode("doc-id")[:],
      128,
    ),
    true,
  )
  @test.assert_eq(
    try! @pdflite.pdf_authenticate_user_password(
      false,
      Bytes::new(0)[:],
      3,
      r3_entry[:8],
      owner[:],
      -3904,
      @ascii.encode("doc-id")[:],
      128,
    ),
    false,
  )
}

///|
test "pdf_make_owner_password_entry matches CamlPDF O values" {
  @test.assert_eq(
    try! @pdflite.pdf_make_owner_password_entry(
      2,
      @ascii.encode("owner")[:],
      @ascii.encode("user")[:],
      40,
    ),
    crypt_model_bytes_for_test([
      0x94, 0xe8, 0x09, 0x44, 0x19, 0x66, 0x2a, 0x77, 0x44, 0x42, 0xfb, 0x07, 0x2e,
      0x3d, 0x9f, 0x19, 0xe9, 0xd1, 0x30, 0xec, 0x09, 0xa4, 0xd0, 0x06, 0x1e, 0x78,
      0xfe, 0x92, 0x0f, 0x7a, 0xb6, 0x2f,
    ]),
  )
  @test.assert_eq(
    try! @pdflite.pdf_make_owner_password_entry(
      3,
      @ascii.encode("owner")[:],
      Bytes::new(0)[:],
      128,
    ),
    crypt_model_bytes_for_test([
      0x56, 0x6f, 0xa8, 0x73, 0xee, 0x33, 0xc7, 0x97, 0xcd, 0x3b, 0x90, 0x4f, 0xda,
      0xdf, 0x81, 0x4a, 0xfa, 0x34, 0xdf, 0x9a, 0x38, 0xf6, 0xed, 0x41, 0xb9, 0x84,
      0xe2, 0xc6, 0xda, 0x2a, 0xa6, 0xf5,
    ]),
  )
  @test.assert_eq(
    try! @pdflite.pdf_make_owner_password_entry(
      2,
      Bytes::new(0)[:],
      @ascii.encode("user")[:],
      40,
    ),
    crypt_model_bytes_for_test([
      0x8e, 0xc9, 0x9e, 0x00, 0xc3, 0xd1, 0x84, 0x91, 0x0a, 0x40, 0x64, 0xdf, 0x0f,
      0x95, 0x16, 0xb0, 0x41, 0x36, 0x2b, 0x9b, 0xf1, 0xdc, 0x3f, 0x68, 0xd1, 0x5b,
      0xf7, 0x1f, 0xb1, 0x6d, 0xc5, 0xf3,
    ]),
  )
}

///|
test "pdf_user_password_from_owner_password recovers padded user password" {
  let owner_entry = try! @pdflite.pdf_make_owner_password_entry(
    2,
    @ascii.encode("owner")[:],
    @ascii.encode("user")[:],
    40,
  )
  @test.assert_eq(
    try! @pdflite.pdf_user_password_from_owner_password(
      2,
      @ascii.encode("owner")[:],
      owner_entry[:],
      40,
    ),
    @pdflite.pdf_pad_password(@ascii.encode("user")[:]),
  )
  let owner_entry_r3 = try! @pdflite.pdf_make_owner_password_entry(
    3,
    @ascii.encode("owner")[:],
    Bytes::new(0)[:],
    128,
  )
  @test.assert_eq(
    try! @pdflite.pdf_user_password_from_owner_password(
      3,
      @ascii.encode("owner")[:],
      owner_entry_r3[:],
      128,
    ),
    @pdflite.pdf_password_padding(),
  )
}

///|
test "pdf_authenticate_owner_password validates through recovered user password" {
  let owner_entry = try! @pdflite.pdf_make_owner_password_entry(
    3,
    @ascii.encode("owner")[:],
    Bytes::new(0)[:],
    128,
  )
  let user_entry = try! @pdflite.pdf_make_user_password_entry(
    false,
    Bytes::new(0)[:],
    3,
    owner_entry[:],
    -3904,
    @ascii.encode("doc-id")[:],
    128,
  )
  @test.assert_eq(
    try! @pdflite.pdf_authenticate_owner_password(
      false,
      @ascii.encode("owner")[:],
      3,
      user_entry[:],
      owner_entry[:],
      -3904,
      @ascii.encode("doc-id")[:],
      128,
    ),
    true,
  )
  @test.assert_eq(
    try! @pdflite.pdf_authenticate_owner_password(
      false,
      @ascii.encode("bad")[:],
      3,
      user_entry[:],
      owner_entry[:],
      -3904,
      @ascii.encode("doc-id")[:],
      128,
    ),
    false,
  )
}

///|
test "pdf_permissions_of_p parses CamlPDF denied permission bits" {
  @test.assert_eq(@pdflite.pdf_permissions_of_p(-4), [])
  @test.assert_eq(@pdflite.pdf_permissions_of_p(-8), [PdfNoPrint])
  @test.assert_eq(@pdflite.pdf_permissions_of_p(-3904), [
    PdfNoHqPrint,
    PdfNoAssemble,
    PdfNoExtract,
    PdfNoForms,
    PdfNoAnnot,
    PdfNoCopy,
    PdfNoEdit,
    PdfNoPrint,
  ])
}

///|
test "pdf_p_of_permissions writes signed CamlPDF permission masks" {
  @test.assert_eq(@pdflite.pdf_p_of_permissions([]), -4)
  @test.assert_eq(@pdflite.pdf_p_of_permissions([PdfNoPrint]), -8)
  @test.assert_eq(
    @pdflite.pdf_p_of_permissions([
      PdfNoEdit,
      PdfNoPrint,
      PdfNoCopy,
      PdfNoAnnot,
      PdfNoForms,
      PdfNoExtract,
      PdfNoAssemble,
      PdfNoHqPrint,
    ]),
    -3904,
  )
}

///|
test "permission masks roundtrip denied permissions" {
  let denied : Array[@pdflite.PdfPermission] = [
    PdfNoCopy,
    PdfNoExtract,
    PdfNoHqPrint,
  ]
  @test.assert_eq(
    @pdflite.pdf_permissions_of_p(@pdflite.pdf_p_of_permissions(denied)),
    [PdfNoHqPrint, PdfNoExtract, PdfNoCopy],
  )
}
