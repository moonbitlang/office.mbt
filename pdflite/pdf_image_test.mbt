///|
fn image_name_for_test(text : String) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(@ascii.encode(text))
}

///|
test "PdfImage public variants preserve image payload metadata" {
  let layout : @pdflite.PdfPixelLayout = PdfBPP24
  @test.assert_eq(layout, PdfBPP24)
  let jpeg : @pdflite.PdfImage = PdfJPEG(@ascii.encode("jpg"), Some([0.0, 1.0]))
  @test.assert_eq(jpeg, PdfJPEG(@ascii.encode("jpg"), Some([0.0, 1.0])))
  let jbig2 : @pdflite.PdfImage = PdfJBIG2(@ascii.encode("jbig"), None, Some(7))
  @test.assert_eq(jbig2, PdfJBIG2(@ascii.encode("jbig"), None, Some(7)))
  let raw : @pdflite.PdfImage = PdfRawImage(1, 1, PdfBPP8, @ascii.encode("x"))
  @test.assert_eq(raw, PdfRawImage(1, 1, PdfBPP8, @ascii.encode("x")))
}

///|
test "PdfDocument image_colour_space resolves direct and resource colour spaces" {
  let doc = @pdflite.pdf_document_empty()
  let resources = @pdflite.pdf_dictionary([
    (
      image_name_for_test("/ColorSpace"),
      @pdflite.pdf_dictionary([
        (
          image_name_for_test("/CS1"),
          PdfNameObject(image_name_for_test("/DeviceRGB")),
        ),
      ]),
    ),
  ])
  @test.assert_eq(
    try! doc.image_colour_space(
      @pdflite.pdf_dictionary([
        (
          image_name_for_test("/ColorSpace"),
          PdfNameObject(image_name_for_test("/DeviceCMYK")),
        ),
      ]),
      resources,
    ),
    PdfDeviceCMYK,
  )
  @test.assert_eq(
    try! doc.image_colour_space(
      @pdflite.pdf_dictionary([
        (image_name_for_test("/CS"), PdfNameObject(image_name_for_test("/CS1"))),
      ]),
      resources,
    ),
    PdfDeviceRGB,
  )
}

///|
test "PdfDocument image_colour_space treats image masks as DeviceGray" {
  let doc = @pdflite.pdf_document_empty()
  @test.assert_eq(
    try! doc.image_colour_space(
      @pdflite.pdf_dictionary([
        (image_name_for_test("/ImageMask"), PdfBoolean(true)),
      ]),
      @pdflite.pdf_dictionary([]),
    ),
    PdfDeviceGray,
  )
  @test.assert_eq(
    try! doc.image_colour_space(
      @pdflite.pdf_dictionary([(image_name_for_test("/IM"), PdfBoolean(true))]),
      @pdflite.pdf_dictionary([]),
    ),
    PdfDeviceGray,
  )
}

///|
test "PdfDocument image_colour_space reports missing colour spaces" {
  let doc = @pdflite.pdf_document_empty()
  let missing : Result[@pdflite.PdfColourSpace, Error] = try? doc.image_colour_space(
    @pdflite.pdf_dictionary([]),
    @pdflite.pdf_dictionary([]),
  )
  guard missing is Err(@pdflite.PdfError::DictionaryKeyNotFound(name)) &&
    name == image_name_for_test("/ColorSpace") else {
    fail("expected missing image colour space")
  }
  let unknown : Result[@pdflite.PdfColourSpace, Error] = try? doc.image_colour_space(
    @pdflite.pdf_dictionary([
      (
        image_name_for_test("/ColorSpace"),
        PdfNameObject(image_name_for_test("/CS1")),
      ),
    ]),
    @pdflite.pdf_dictionary([]),
  )
  guard unknown is Err(@pdflite.PdfError::DictionaryKeyNotFound(name)) &&
    name == image_name_for_test("/ColorSpace") else {
    fail("expected unknown image colour space")
  }
}

///|
test "PdfDocument image_bits_per_component reads long and abbreviated keys" {
  let doc = @pdflite.pdf_document_empty()
  @test.assert_eq(
    doc.image_bits_per_component(
      @pdflite.pdf_dictionary([
        (image_name_for_test("/BitsPerComponent"), PdfInteger(8)),
      ]),
    ),
    Some(PdfInteger(8)),
  )
  @test.assert_eq(
    doc.image_bits_per_component(
      @pdflite.pdf_dictionary([(image_name_for_test("/BPC"), PdfInteger(4))]),
    ),
    Some(PdfInteger(4)),
  )
}

///|
test "PdfDocument image_bits_per_component defaults masks to one bit" {
  let doc = @pdflite.pdf_document_empty()
  @test.assert_eq(
    doc.image_bits_per_component(
      @pdflite.pdf_dictionary([
        (image_name_for_test("/ImageMask"), PdfBoolean(true)),
      ]),
    ),
    Some(PdfInteger(1)),
  )
  @test.assert_eq(
    doc.image_bits_per_component(
      @pdflite.pdf_dictionary([(image_name_for_test("/IM"), PdfBoolean(true))]),
    ),
    Some(PdfInteger(1)),
  )
  @test.assert_eq(
    doc.image_bits_per_component(@pdflite.pdf_dictionary([])),
    None,
  )
}
