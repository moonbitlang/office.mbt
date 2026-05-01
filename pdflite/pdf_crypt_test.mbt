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
