///|
fn image_name_for_test(text : String) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn image_bytes_for_test(values : ArrayView[Int]) -> @pdflite.PdfBytes {
  try! @pdflite.pdf_bytes_of_int_array(values)
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
test "PdfDocument get_image_24bpp returns encoded JPEG images" {
  let doc = @pdflite.pdf_document_empty()
  let image = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (image_name_for_test("/Width"), PdfInteger(1)),
      (image_name_for_test("/Height"), PdfInteger(1)),
      (
        image_name_for_test("/Filter"),
        PdfNameObject(image_name_for_test("/DCTDecode")),
      ),
      (image_name_for_test("/Decode"), PdfArray([PdfInteger(0), PdfInteger(1)])),
    ]),
    StreamGot(@ascii.encode("jpg")),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(@pdflite.pdf_dictionary([]), image),
    PdfJPEG(@ascii.encode("jpg"), Some([0.0, 1.0])),
  )
}

///|
test "PdfDocument get_image_24bpp returns encoded JPX and JBIG2 images" {
  let doc = @pdflite.pdf_document_empty()
  let jpx = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (image_name_for_test("/W"), PdfInteger(1)),
      (image_name_for_test("/H"), PdfInteger(1)),
      (
        image_name_for_test("/F"),
        PdfNameObject(image_name_for_test("/JPXDecode")),
      ),
    ]),
    StreamGot(@ascii.encode("jpx")),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(@pdflite.pdf_dictionary([]), jpx),
    PdfJPEG2000(@ascii.encode("jpx"), None),
  )
  let jbig2 = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (image_name_for_test("/Width"), PdfInteger(1)),
      (image_name_for_test("/Height"), PdfInteger(1)),
      (
        image_name_for_test("/Filter"),
        PdfNameObject(image_name_for_test("/JBIG2Decode")),
      ),
      (
        image_name_for_test("/DecodeParms"),
        @pdflite.pdf_dictionary([
          (image_name_for_test("/JBIG2Globals"), PdfIndirect(99)),
        ]),
      ),
    ]),
    StreamGot(@ascii.encode("jbig")),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(@pdflite.pdf_dictionary([]), jbig2),
    PdfJBIG2(@ascii.encode("jbig"), None, Some(99)),
  )
}

///|
test "PdfDocument get_image_24bpp reads raw RGB gray and CMYK images" {
  let doc = @pdflite.pdf_document_empty()
  let empty_resources = @pdflite.pdf_dictionary([])
  let rgb = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (image_name_for_test("/Width"), PdfInteger(2)),
      (image_name_for_test("/Height"), PdfInteger(1)),
      (
        image_name_for_test("/ColorSpace"),
        PdfNameObject(image_name_for_test("/DeviceRGB")),
      ),
      (image_name_for_test("/BitsPerComponent"), PdfInteger(8)),
    ]),
    StreamGot(image_bytes_for_test([1, 2, 3, 4, 5, 6])),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(empty_resources, rgb),
    PdfRawImage(2, 1, PdfBPP24, image_bytes_for_test([1, 2, 3, 4, 5, 6])),
  )
  let gray = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (image_name_for_test("/Width"), PdfInteger(2)),
      (image_name_for_test("/Height"), PdfInteger(1)),
      (
        image_name_for_test("/ColorSpace"),
        PdfNameObject(image_name_for_test("/DeviceGray")),
      ),
      (image_name_for_test("/BitsPerComponent"), PdfInteger(8)),
    ]),
    StreamGot(image_bytes_for_test([9, 10])),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(empty_resources, gray),
    PdfRawImage(2, 1, PdfBPP24, image_bytes_for_test([9, 9, 9, 10, 10, 10])),
  )
  let cmyk = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (image_name_for_test("/Width"), PdfInteger(1)),
      (image_name_for_test("/Height"), PdfInteger(1)),
      (
        image_name_for_test("/ColorSpace"),
        PdfNameObject(image_name_for_test("/DeviceCMYK")),
      ),
      (image_name_for_test("/BitsPerComponent"), PdfInteger(8)),
    ]),
    StreamGot(image_bytes_for_test([0, 0, 0, 0])),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(empty_resources, cmyk),
    PdfRawImage(1, 1, PdfBPP24, image_bytes_for_test([255, 255, 255])),
  )
}

///|
test "PdfDocument get_image_24bpp reads one and four bit grayscale images" {
  let doc = @pdflite.pdf_document_empty()
  let mask = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (image_name_for_test("/Width"), PdfInteger(3)),
      (image_name_for_test("/Height"), PdfInteger(2)),
      (image_name_for_test("/ImageMask"), PdfBoolean(true)),
    ]),
    StreamGot(image_bytes_for_test([0b1010_0000, 0b0100_0000])),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(@pdflite.pdf_dictionary([]), mask),
    PdfRawImage(
      3,
      2,
      PdfBPP24,
      image_bytes_for_test([
        255, 255, 255, 0, 0, 0, 255, 255, 255, 0, 0, 0, 255, 255, 255, 0, 0, 0,
      ]),
    ),
  )
  let gray4 = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (image_name_for_test("/Width"), PdfInteger(3)),
      (image_name_for_test("/Height"), PdfInteger(1)),
      (
        image_name_for_test("/ColorSpace"),
        PdfNameObject(image_name_for_test("/DeviceGray")),
      ),
      (image_name_for_test("/BitsPerComponent"), PdfInteger(4)),
    ]),
    StreamGot(image_bytes_for_test([0x0F, 0x80])),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(@pdflite.pdf_dictionary([]), gray4),
    PdfRawImage(
      3,
      1,
      PdfBPP24,
      image_bytes_for_test([0, 0, 0, 255, 255, 255, 136, 136, 136]),
    ),
  )
}

///|
test "PdfDocument get_image_24bpp reads indexed image tables" {
  let doc = @pdflite.pdf_document_empty()
  let empty_resources = @pdflite.pdf_dictionary([])
  let indexed_rgb : @pdflite.PdfObject = PdfArray([
    PdfNameObject(image_name_for_test("/Indexed")),
    PdfNameObject(image_name_for_test("/DeviceRGB")),
    PdfInteger(1),
    PdfString(image_bytes_for_test([10, 20, 30, 40, 50, 60])),
  ])
  let rgb8 = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (image_name_for_test("/Width"), PdfInteger(2)),
      (image_name_for_test("/Height"), PdfInteger(1)),
      (image_name_for_test("/ColorSpace"), indexed_rgb),
      (image_name_for_test("/BitsPerComponent"), PdfInteger(8)),
    ]),
    StreamGot(image_bytes_for_test([0, 1])),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(empty_resources, rgb8),
    PdfRawImage(2, 1, PdfBPP24, image_bytes_for_test([10, 20, 30, 40, 50, 60])),
  )
  let indexed_cmyk : @pdflite.PdfObject = PdfArray([
    PdfNameObject(image_name_for_test("/Indexed")),
    PdfNameObject(image_name_for_test("/DeviceCMYK")),
    PdfInteger(1),
    PdfString(image_bytes_for_test([0, 0, 0, 0, 0, 255, 255, 0])),
  ])
  let cmyk4 = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (image_name_for_test("/Width"), PdfInteger(2)),
      (image_name_for_test("/Height"), PdfInteger(1)),
      (image_name_for_test("/ColorSpace"), indexed_cmyk),
      (image_name_for_test("/BitsPerComponent"), PdfInteger(4)),
    ]),
    StreamGot(image_bytes_for_test([0x01])),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(empty_resources, cmyk4),
    PdfRawImage(
      2,
      1,
      PdfBPP24,
      image_bytes_for_test([255, 255, 255, 255, 0, 0]),
    ),
  )
}

///|
test "PdfDocument get_image_24bpp reports malformed raw images" {
  let doc = @pdflite.pdf_document_empty()
  let short_rgb = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (image_name_for_test("/Width"), PdfInteger(2)),
      (image_name_for_test("/Height"), PdfInteger(1)),
      (
        image_name_for_test("/ColorSpace"),
        PdfNameObject(image_name_for_test("/DeviceRGB")),
      ),
      (image_name_for_test("/BitsPerComponent"), PdfInteger(8)),
    ]),
    StreamGot(image_bytes_for_test([1, 2, 3])),
  )
  let result : Result[@pdflite.PdfImage, Error] = try? doc.get_image_24bpp(
    @pdflite.pdf_dictionary([]),
    short_rgb,
  )
  guard result is Err(@pdflite.PdfError::EndOfInput) else {
    fail("expected EndOfInput for short raw image")
  }
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
