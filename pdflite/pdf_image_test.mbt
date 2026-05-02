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
    try! doc.colspace(
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
  let gray_jpeg = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (image_name_for_test("/Width"), PdfInteger(1)),
      (image_name_for_test("/Height"), PdfInteger(1)),
      (
        image_name_for_test("/Filter"),
        PdfNameObject(image_name_for_test("/DCTDecode")),
      ),
      (
        image_name_for_test("/ColorSpace"),
        PdfNameObject(image_name_for_test("/DeviceGray")),
      ),
    ]),
    StreamGot(@ascii.encode("gray-jpg")),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(@pdflite.pdf_dictionary([]), gray_jpeg),
    PdfJPEG(@ascii.encode("gray-jpg"), Some([0.0, 1.0])),
  )
  let array_jpeg = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (image_name_for_test("/Width"), PdfInteger(1)),
      (image_name_for_test("/Height"), PdfInteger(1)),
      (
        image_name_for_test("/Filter"),
        PdfArray([PdfNameObject(image_name_for_test("/DCTDecode"))]),
      ),
    ]),
    StreamGot(@ascii.encode("array-jpg")),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(@pdflite.pdf_dictionary([]), array_jpeg),
    PdfJPEG(@ascii.encode("array-jpg"), None),
  )
  doc.add_object_given_number(
    8,
    PdfNameObject(image_name_for_test("/DCTDecode")),
  )
  let indirect_array_jpeg = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (image_name_for_test("/Width"), PdfInteger(1)),
      (image_name_for_test("/Height"), PdfInteger(1)),
      (image_name_for_test("/Filter"), PdfArray([PdfIndirect(8)])),
    ]),
    StreamGot(@ascii.encode("indirect-array-jpg")),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(@pdflite.pdf_dictionary([]), indirect_array_jpeg),
    PdfJPEG(@ascii.encode("indirect-array-jpg"), None),
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
  let jbig2_short_decodeparms = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (image_name_for_test("/Width"), PdfInteger(1)),
      (image_name_for_test("/Height"), PdfInteger(1)),
      (
        image_name_for_test("/Filter"),
        PdfNameObject(image_name_for_test("/JBIG2Decode")),
      ),
      (
        image_name_for_test("/DP"),
        @pdflite.pdf_dictionary([
          (image_name_for_test("/JBIG2Globals"), PdfIndirect(77)),
        ]),
      ),
    ]),
    StreamGot(@ascii.encode("short-jbig")),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(
      @pdflite.pdf_dictionary([]),
      jbig2_short_decodeparms,
    ),
    PdfJBIG2(@ascii.encode("short-jbig"), None, Some(77)),
  )
  let jbig2_array_decodeparms = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (image_name_for_test("/Width"), PdfInteger(1)),
      (image_name_for_test("/Height"), PdfInteger(1)),
      (
        image_name_for_test("/Filter"),
        PdfArray([PdfNameObject(image_name_for_test("/JBIG2Decode"))]),
      ),
      (
        image_name_for_test("/DecodeParms"),
        PdfArray([
          @pdflite.pdf_dictionary([
            (image_name_for_test("/JBIG2Globals"), PdfIndirect(42)),
          ]),
        ]),
      ),
    ]),
    StreamGot(@ascii.encode("array-jbig")),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(
      @pdflite.pdf_dictionary([]),
      jbig2_array_decodeparms,
    ),
    PdfJBIG2(@ascii.encode("array-jbig"), None, Some(42)),
  )
  let jbig2_empty_decodeparms = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (image_name_for_test("/Width"), PdfInteger(1)),
      (image_name_for_test("/Height"), PdfInteger(1)),
      (
        image_name_for_test("/Filter"),
        PdfNameObject(image_name_for_test("/JBIG2Decode")),
      ),
      (image_name_for_test("/DecodeParms"), @pdflite.pdf_dictionary([])),
    ]),
    StreamGot(@ascii.encode("empty-dp-jbig")),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(
      @pdflite.pdf_dictionary([]),
      jbig2_empty_decodeparms,
    ),
    PdfJBIG2(@ascii.encode("empty-dp-jbig"), None, None),
  )
  let jbig2_bad_array_decodeparms = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (image_name_for_test("/Width"), PdfInteger(1)),
      (image_name_for_test("/Height"), PdfInteger(1)),
      (
        image_name_for_test("/Filter"),
        PdfArray([PdfNameObject(image_name_for_test("/JBIG2Decode"))]),
      ),
      (image_name_for_test("/DecodeParms"), PdfArray([PdfInteger(1)])),
    ]),
    StreamGot(@ascii.encode("bad-array-jbig")),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(
      @pdflite.pdf_dictionary([]),
      jbig2_bad_array_decodeparms,
    ),
    PdfJBIG2(@ascii.encode("bad-array-jbig"), None, None),
  )
  let jbig2_without_globals = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (image_name_for_test("/Width"), PdfInteger(1)),
      (image_name_for_test("/Height"), PdfInteger(1)),
      (
        image_name_for_test("/Filter"),
        PdfNameObject(image_name_for_test("/JBIG2Decode")),
      ),
    ]),
    StreamGot(@ascii.encode("plain-jbig")),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(@pdflite.pdf_dictionary([]), jbig2_without_globals),
    PdfJBIG2(@ascii.encode("plain-jbig"), None, None),
  )
  let jbig2_bad_decodeparms = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (image_name_for_test("/Width"), PdfInteger(1)),
      (image_name_for_test("/Height"), PdfInteger(1)),
      (
        image_name_for_test("/Filter"),
        PdfNameObject(image_name_for_test("/JBIG2Decode")),
      ),
      (image_name_for_test("/DecodeParms"), PdfInteger(1)),
    ]),
    StreamGot(@ascii.encode("bad-jbig")),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(@pdflite.pdf_dictionary([]), jbig2_bad_decodeparms),
    PdfJBIG2(@ascii.encode("bad-jbig"), None, None),
  )
}

///|
test "PdfDocument get_image_24bpp decodes filter stages before image extraction" {
  let doc = @pdflite.pdf_document_empty()
  let raw_data = image_bytes_for_test([1, 2, 3, 4, 5, 6])
  let flate_raw_data = @pdflite.pdf_flate_encode(raw_data)
  let flate_raw = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (image_name_for_test("/Length"), PdfInteger(flate_raw_data.length())),
      (image_name_for_test("/Width"), PdfInteger(2)),
      (image_name_for_test("/Height"), PdfInteger(1)),
      (
        image_name_for_test("/ColorSpace"),
        PdfNameObject(image_name_for_test("/DeviceRGB")),
      ),
      (image_name_for_test("/BitsPerComponent"), PdfInteger(8)),
      (
        image_name_for_test("/Filter"),
        PdfNameObject(image_name_for_test("/FlateDecode")),
      ),
    ]),
    StreamGot(flate_raw_data),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(@pdflite.pdf_dictionary([]), flate_raw),
    PdfRawImage(2, 1, PdfBPP24, raw_data),
  )
  let flate_jpeg_data = @pdflite.pdf_flate_encode(@ascii.encode("jpg"))
  let encoded_jpeg = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (image_name_for_test("/Length"), PdfInteger(flate_jpeg_data.length())),
      (image_name_for_test("/Width"), PdfInteger(1)),
      (image_name_for_test("/Height"), PdfInteger(1)),
      (
        image_name_for_test("/Filter"),
        PdfArray([
          PdfNameObject(image_name_for_test("/FlateDecode")),
          PdfNameObject(image_name_for_test("/DCTDecode")),
        ]),
      ),
    ]),
    StreamGot(flate_jpeg_data),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(@pdflite.pdf_dictionary([]), encoded_jpeg),
    PdfJPEG(@ascii.encode("jpg"), None),
  )
  let flate_jbig2_data = @pdflite.pdf_flate_encode(@ascii.encode("jbig-stage"))
  let encoded_jbig2 = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (image_name_for_test("/Length"), PdfInteger(flate_jbig2_data.length())),
      (image_name_for_test("/Width"), PdfInteger(1)),
      (image_name_for_test("/Height"), PdfInteger(1)),
      (
        image_name_for_test("/Filter"),
        PdfArray([
          PdfNameObject(image_name_for_test("/FlateDecode")),
          PdfNameObject(image_name_for_test("/JBIG2Decode")),
        ]),
      ),
      (
        image_name_for_test("/DecodeParms"),
        PdfArray([
          PdfNull,
          @pdflite.pdf_dictionary([
            (image_name_for_test("/JBIG2Globals"), PdfIndirect(123)),
          ]),
        ]),
      ),
    ]),
    StreamGot(flate_jbig2_data),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(@pdflite.pdf_dictionary([]), encoded_jbig2),
    PdfJBIG2(@ascii.encode("jbig-stage"), None, Some(123)),
  )
}

///|
test "PdfDocument get_image_24bpp handles filter arrays and deferred image data" {
  let doc = @pdflite.pdf_document_empty()
  let empty_resources = @pdflite.pdf_dictionary([])
  let empty_filter_raw = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (image_name_for_test("/Width"), PdfInteger(1)),
      (image_name_for_test("/Height"), PdfInteger(1)),
      (
        image_name_for_test("/ColorSpace"),
        PdfNameObject(image_name_for_test("/DeviceRGB")),
      ),
      (image_name_for_test("/BitsPerComponent"), PdfInteger(8)),
      (image_name_for_test("/Filter"), PdfArray([])),
    ]),
    StreamGot(image_bytes_for_test([10, 20, 30])),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(empty_resources, empty_filter_raw),
    PdfRawImage(1, 1, PdfBPP24, image_bytes_for_test([10, 20, 30])),
  )
  let malformed_filter = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (image_name_for_test("/Width"), PdfInteger(1)),
      (image_name_for_test("/Height"), PdfInteger(1)),
      (
        image_name_for_test("/ColorSpace"),
        PdfNameObject(image_name_for_test("/DeviceRGB")),
      ),
      (image_name_for_test("/BitsPerComponent"), PdfInteger(8)),
      (image_name_for_test("/Filter"), PdfInteger(1)),
    ]),
    StreamGot(image_bytes_for_test([10, 20, 30])),
  )
  let malformed : Result[@pdflite.PdfImage, Error] = try? doc.get_image_24bpp(
    empty_resources, malformed_filter,
  )
  guard malformed is Err(@pdflite.PdfError::FilterExpected) else {
    fail("expected malformed filter")
  }
  let cursor = @pdflite.byte_cursor_of_bytes(image_bytes_for_test([1, 2, 3]))
  let deferred_raw = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (image_name_for_test("/Width"), PdfInteger(1)),
      (image_name_for_test("/Height"), PdfInteger(1)),
      (
        image_name_for_test("/ColorSpace"),
        PdfNameObject(image_name_for_test("/DeviceRGB")),
      ),
      (image_name_for_test("/BitsPerComponent"), PdfInteger(8)),
    ]),
    StreamToGet(@pdflite.stream_to_get(cursor, 0, 3)),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(empty_resources, deferred_raw),
    PdfRawImage(1, 1, PdfBPP24, image_bytes_for_test([1, 2, 3])),
  )
}

///|
test "PdfDocument get_image_24bpp validates malformed image dictionary values" {
  let doc = @pdflite.pdf_document_empty()
  let empty_resources = @pdflite.pdf_dictionary([])
  let bad_width = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (
        image_name_for_test("/Width"),
        PdfNameObject(image_name_for_test("/Bad")),
      ),
      (image_name_for_test("/Height"), PdfInteger(1)),
      (
        image_name_for_test("/Filter"),
        PdfNameObject(image_name_for_test("/DCTDecode")),
      ),
    ]),
    StreamGot(@ascii.encode("jpg")),
  )
  let width_result : Result[@pdflite.PdfImage, Error] = try? doc.get_image_24bpp(
    empty_resources, bad_width,
  )
  guard width_result is Err(@pdflite.PdfError::NumberExpected) else {
    fail("expected malformed width")
  }
  let bad_bpc = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (image_name_for_test("/Width"), PdfInteger(1)),
      (image_name_for_test("/Height"), PdfInteger(1)),
      (
        image_name_for_test("/ColorSpace"),
        PdfNameObject(image_name_for_test("/DeviceRGB")),
      ),
      (
        image_name_for_test("/BitsPerComponent"),
        PdfNameObject(image_name_for_test("/Bad")),
      ),
    ]),
    StreamGot(image_bytes_for_test([10, 20, 30])),
  )
  let bpc_result : Result[@pdflite.PdfImage, Error] = try? doc.get_image_24bpp(
    empty_resources, bad_bpc,
  )
  guard bpc_result is Err(@pdflite.PdfError::NumberExpected) else {
    fail("expected malformed bits per component")
  }
  let bad_decode = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (image_name_for_test("/Width"), PdfInteger(1)),
      (image_name_for_test("/Height"), PdfInteger(1)),
      (
        image_name_for_test("/Filter"),
        PdfNameObject(image_name_for_test("/DCTDecode")),
      ),
      (
        image_name_for_test("/Decode"),
        PdfNameObject(image_name_for_test("/Bad")),
      ),
    ]),
    StreamGot(@ascii.encode("jpg")),
  )
  let decode_result : Result[@pdflite.PdfImage, Error] = try? doc.get_image_24bpp(
    empty_resources, bad_decode,
  )
  guard decode_result is Err(@pdflite.PdfError::NumberExpected) else {
    fail("expected malformed decode")
  }
  let missing_width = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (image_name_for_test("/Height"), PdfInteger(1)),
      (
        image_name_for_test("/Filter"),
        PdfNameObject(image_name_for_test("/DCTDecode")),
      ),
    ]),
    StreamGot(@ascii.encode("jpg")),
  )
  let missing_width_result : Result[@pdflite.PdfImage, Error] = try? doc.get_image_24bpp(
    empty_resources, missing_width,
  )
  guard missing_width_result
    is Err(@pdflite.PdfError::DictionaryKeyNotFound(name)) &&
    name == image_name_for_test("/Width") else {
    fail("expected missing width")
  }
  let missing_bpc = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (image_name_for_test("/Width"), PdfInteger(1)),
      (image_name_for_test("/Height"), PdfInteger(1)),
      (
        image_name_for_test("/ColorSpace"),
        PdfNameObject(image_name_for_test("/DeviceRGB")),
      ),
    ]),
    StreamGot(image_bytes_for_test([10, 20, 30])),
  )
  let missing_bpc_result : Result[@pdflite.PdfImage, Error] = try? doc.get_image_24bpp(
    empty_resources, missing_bpc,
  )
  guard missing_bpc_result is Err(@pdflite.PdfError::FilterExpected) else {
    fail("expected missing bits per component")
  }
  let not_stream : Result[@pdflite.PdfImage, Error] = try? doc.get_image_24bpp(
    empty_resources,
    PdfInteger(1),
  )
  guard not_stream is Err(@pdflite.PdfError::ParseStreamExpected) else {
    fail("expected image stream")
  }
}

///|
test "PdfDocument get_image_24bpp derives encoded image decode defaults" {
  let doc = @pdflite.pdf_document_empty()
  let lab_space : @pdflite.PdfObject = PdfArray([
    PdfNameObject(image_name_for_test("/Lab")),
    @pdflite.pdf_dictionary([
      (
        image_name_for_test("/WhitePoint"),
        PdfArray([PdfInteger(1), PdfInteger(1), PdfInteger(1)]),
      ),
      (
        image_name_for_test("/Range"),
        PdfArray([
          PdfInteger(-80),
          PdfInteger(90),
          PdfInteger(-70),
          PdfInteger(85),
        ]),
      ),
    ]),
  ])
  let lab_jpeg = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (image_name_for_test("/Width"), PdfInteger(1)),
      (image_name_for_test("/Height"), PdfInteger(1)),
      (
        image_name_for_test("/Filter"),
        PdfNameObject(image_name_for_test("/DCTDecode")),
      ),
      (image_name_for_test("/ColorSpace"), lab_space),
    ]),
    StreamGot(@ascii.encode("lab")),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(@pdflite.pdf_dictionary([]), lab_jpeg),
    PdfJPEG(@ascii.encode("lab"), Some([0.0, 1.0, -80.0, 90.0, -70.0, 85.0])),
  )
  let tint = @pdflite.pdf_dictionary([
    (image_name_for_test("/FunctionType"), PdfInteger(2)),
  ])
  let device_n_space : @pdflite.PdfObject = PdfArray([
    PdfNameObject(image_name_for_test("/DeviceN")),
    PdfArray([
      PdfNameObject(image_name_for_test("/Cyan")),
      PdfNameObject(image_name_for_test("/Magenta")),
    ]),
    PdfNameObject(image_name_for_test("/DeviceCMYK")),
    tint,
  ])
  let device_n_jpeg = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (image_name_for_test("/Width"), PdfInteger(1)),
      (image_name_for_test("/Height"), PdfInteger(1)),
      (
        image_name_for_test("/Filter"),
        PdfNameObject(image_name_for_test("/DCTDecode")),
      ),
      (image_name_for_test("/ColorSpace"), device_n_space),
    ]),
    StreamGot(@ascii.encode("device-n")),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(@pdflite.pdf_dictionary([]), device_n_jpeg),
    PdfJPEG(@ascii.encode("device-n"), Some([0.0, 1.0, 0.0, 1.0])),
  )
  let indexed_rgb : @pdflite.PdfObject = PdfArray([
    PdfNameObject(image_name_for_test("/Indexed")),
    PdfNameObject(image_name_for_test("/DeviceRGB")),
    PdfInteger(0),
    PdfString(image_bytes_for_test([10, 20, 30])),
  ])
  let indexed_jpeg = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (image_name_for_test("/Width"), PdfInteger(1)),
      (image_name_for_test("/Height"), PdfInteger(1)),
      (
        image_name_for_test("/Filter"),
        PdfNameObject(image_name_for_test("/DCTDecode")),
      ),
      (image_name_for_test("/ColorSpace"), indexed_rgb),
      (image_name_for_test("/Decode"), PdfArray([PdfInteger(0), PdfInteger(1)])),
    ]),
    StreamGot(@ascii.encode("indexed")),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(@pdflite.pdf_dictionary([]), indexed_jpeg),
    PdfJPEG(@ascii.encode("indexed"), None),
  )
  let pattern_jpeg = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (image_name_for_test("/Width"), PdfInteger(1)),
      (image_name_for_test("/Height"), PdfInteger(1)),
      (
        image_name_for_test("/Filter"),
        PdfNameObject(image_name_for_test("/DCTDecode")),
      ),
      (
        image_name_for_test("/ColorSpace"),
        PdfNameObject(image_name_for_test("/Pattern")),
      ),
    ]),
    StreamGot(@ascii.encode("pattern")),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(@pdflite.pdf_dictionary([]), pattern_jpeg),
    PdfJPEG(@ascii.encode("pattern"), None),
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
test "PdfDocument get_image_24bpp reads raw ICCBased images through alternate space" {
  let doc = @pdflite.pdf_document_empty()
  let icc_gray : @pdflite.PdfObject = PdfArray([
    PdfNameObject(image_name_for_test("/ICCBased")),
    @pdflite.pdf_stream(
      @pdflite.pdf_dictionary([(image_name_for_test("/N"), PdfInteger(1))]),
      StreamGot(@ascii.encode("icc")),
    ),
  ])
  let image = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (image_name_for_test("/Width"), PdfInteger(2)),
      (image_name_for_test("/Height"), PdfInteger(1)),
      (image_name_for_test("/ColorSpace"), icc_gray),
      (image_name_for_test("/BitsPerComponent"), PdfInteger(8)),
    ]),
    StreamGot(image_bytes_for_test([9, 10])),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(@pdflite.pdf_dictionary([]), image),
    PdfRawImage(2, 1, PdfBPP24, image_bytes_for_test([9, 9, 9, 10, 10, 10])),
  )
}

///|
test "PdfDocument get_image_24bpp reads Separation images with Type 2 CMYK tint" {
  let doc = @pdflite.pdf_document_empty()
  let tint_function = @pdflite.pdf_dictionary([
    (image_name_for_test("/FunctionType"), PdfInteger(2)),
    (image_name_for_test("/Domain"), PdfArray([PdfInteger(0), PdfInteger(1)])),
    (
      image_name_for_test("/C0"),
      PdfArray([PdfInteger(0), PdfInteger(0), PdfInteger(0), PdfInteger(0)]),
    ),
    (
      image_name_for_test("/C1"),
      PdfArray([PdfInteger(0), PdfInteger(1), PdfInteger(0), PdfInteger(0)]),
    ),
    (image_name_for_test("/N"), PdfInteger(1)),
  ])
  let separation : @pdflite.PdfObject = PdfArray([
    PdfNameObject(image_name_for_test("/Separation")),
    PdfNameObject(image_name_for_test("/Spot")),
    PdfNameObject(image_name_for_test("/DeviceCMYK")),
    tint_function,
  ])
  let image = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (image_name_for_test("/Width"), PdfInteger(1)),
      (image_name_for_test("/Height"), PdfInteger(1)),
      (image_name_for_test("/ColorSpace"), separation),
      (image_name_for_test("/BitsPerComponent"), PdfInteger(8)),
    ]),
    StreamGot(image_bytes_for_test([255])),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(@pdflite.pdf_dictionary([]), image),
    PdfRawImage(1, 1, PdfBPP24, image_bytes_for_test([255, 255, 0])),
  )
}

///|
test "PdfDocument get_image_24bpp reads Separation images with Type 4 CMYK tint" {
  let doc = @pdflite.pdf_document_empty()
  let tint_data = @ascii.encode(
    "{ dup 0.5 lt { 0 } { 1 } ifelse exch pop 0 exch 0 0 }",
  )
  let tint_function = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (image_name_for_test("/Length"), PdfInteger(tint_data.length())),
      (image_name_for_test("/FunctionType"), PdfInteger(4)),
      (image_name_for_test("/Domain"), PdfArray([PdfInteger(0), PdfInteger(1)])),
      (
        image_name_for_test("/Range"),
        PdfArray([
          PdfInteger(0),
          PdfInteger(1),
          PdfInteger(0),
          PdfInteger(1),
          PdfInteger(0),
          PdfInteger(1),
          PdfInteger(0),
          PdfInteger(1),
        ]),
      ),
    ]),
    StreamGot(tint_data),
  )
  let separation : @pdflite.PdfObject = PdfArray([
    PdfNameObject(image_name_for_test("/Separation")),
    PdfNameObject(image_name_for_test("/Spot")),
    PdfNameObject(image_name_for_test("/DeviceCMYK")),
    tint_function,
  ])
  let image = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (image_name_for_test("/Width"), PdfInteger(2)),
      (image_name_for_test("/Height"), PdfInteger(1)),
      (image_name_for_test("/ColorSpace"), separation),
      (image_name_for_test("/BitsPerComponent"), PdfInteger(8)),
    ]),
    StreamGot(image_bytes_for_test([0, 255])),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(@pdflite.pdf_dictionary([]), image),
    PdfRawImage(
      2,
      1,
      PdfBPP24,
      image_bytes_for_test([255, 255, 255, 255, 255, 0]),
    ),
  )
}

///|
test "PdfDocument get_image_24bpp reads packed grayscale images" {
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
  let gray2 = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (image_name_for_test("/Width"), PdfInteger(5)),
      (image_name_for_test("/Height"), PdfInteger(2)),
      (
        image_name_for_test("/ColorSpace"),
        PdfNameObject(image_name_for_test("/DeviceGray")),
      ),
      (image_name_for_test("/BitsPerComponent"), PdfInteger(2)),
    ]),
    StreamGot(image_bytes_for_test([0b0001_1011, 0, 0b1110_0100, 0b1100_0000])),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(@pdflite.pdf_dictionary([]), gray2),
    PdfRawImage(
      5,
      2,
      PdfBPP24,
      image_bytes_for_test([
        0, 0, 0, 85, 85, 85, 170, 170, 170, 255, 255, 255, 0, 0, 0, 255, 255, 255,
        170, 170, 170, 85, 85, 85, 0, 0, 0, 255, 255, 255,
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
  let cal_gray_space : @pdflite.PdfObject = PdfArray([
    PdfNameObject(image_name_for_test("/CalGray")),
    @pdflite.pdf_dictionary([]),
  ])
  let cal_gray2 = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (image_name_for_test("/Width"), PdfInteger(4)),
      (image_name_for_test("/Height"), PdfInteger(1)),
      (image_name_for_test("/ColorSpace"), cal_gray_space),
      (image_name_for_test("/BitsPerComponent"), PdfInteger(2)),
    ]),
    StreamGot(image_bytes_for_test([0b0001_1011])),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(@pdflite.pdf_dictionary([]), cal_gray2),
    PdfRawImage(
      4,
      1,
      PdfBPP24,
      image_bytes_for_test([0, 0, 0, 85, 85, 85, 170, 170, 170, 255, 255, 255]),
    ),
  )
  let cal_gray4 = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (image_name_for_test("/Width"), PdfInteger(2)),
      (image_name_for_test("/Height"), PdfInteger(1)),
      (image_name_for_test("/ColorSpace"), cal_gray_space),
      (image_name_for_test("/BitsPerComponent"), PdfInteger(4)),
    ]),
    StreamGot(image_bytes_for_test([0x0F])),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(@pdflite.pdf_dictionary([]), cal_gray4),
    PdfRawImage(2, 1, PdfBPP24, image_bytes_for_test([0, 0, 0, 255, 255, 255])),
  )
}

///|
test "PdfDocument get_image_24bpp reads packed RGB images" {
  let doc = @pdflite.pdf_document_empty()
  let empty_resources = @pdflite.pdf_dictionary([])
  let rgb1 = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (image_name_for_test("/Width"), PdfInteger(2)),
      (image_name_for_test("/Height"), PdfInteger(1)),
      (
        image_name_for_test("/ColorSpace"),
        PdfNameObject(image_name_for_test("/DeviceRGB")),
      ),
      (image_name_for_test("/BitsPerComponent"), PdfInteger(1)),
    ]),
    StreamGot(image_bytes_for_test([0b1010_1000])),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(empty_resources, rgb1),
    PdfRawImage(2, 1, PdfBPP24, image_bytes_for_test([255, 0, 255, 0, 255, 0])),
  )
  let rgb2 = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (image_name_for_test("/Width"), PdfInteger(2)),
      (image_name_for_test("/Height"), PdfInteger(1)),
      (
        image_name_for_test("/ColorSpace"),
        PdfNameObject(image_name_for_test("/DeviceRGB")),
      ),
      (image_name_for_test("/BitsPerComponent"), PdfInteger(2)),
    ]),
    StreamGot(image_bytes_for_test([0b0001_1011, 0b1001_0000])),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(empty_resources, rgb2),
    PdfRawImage(
      2,
      1,
      PdfBPP24,
      image_bytes_for_test([0, 85, 170, 255, 170, 85]),
    ),
  )
  let rgb4 = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (image_name_for_test("/Width"), PdfInteger(2)),
      (image_name_for_test("/Height"), PdfInteger(1)),
      (
        image_name_for_test("/ColorSpace"),
        PdfNameObject(image_name_for_test("/DeviceRGB")),
      ),
      (image_name_for_test("/BitsPerComponent"), PdfInteger(4)),
    ]),
    StreamGot(image_bytes_for_test([0x0F, 0x81, 0x23])),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(empty_resources, rgb4),
    PdfRawImage(2, 1, PdfBPP24, image_bytes_for_test([0, 255, 136, 17, 34, 51])),
  )
  let cal_rgb_space : @pdflite.PdfObject = PdfArray([
    PdfNameObject(image_name_for_test("/CalRGB")),
    @pdflite.pdf_dictionary([]),
  ])
  let cal_rgb2 = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (image_name_for_test("/Width"), PdfInteger(1)),
      (image_name_for_test("/Height"), PdfInteger(1)),
      (image_name_for_test("/ColorSpace"), cal_rgb_space),
      (image_name_for_test("/BitsPerComponent"), PdfInteger(2)),
    ]),
    StreamGot(image_bytes_for_test([0b1100_0100])),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(empty_resources, cal_rgb2),
    PdfRawImage(1, 1, PdfBPP24, image_bytes_for_test([255, 0, 85])),
  )
}

///|
test "PdfDocument get_image_24bpp applies raw image Decode arrays" {
  let doc = @pdflite.pdf_document_empty()
  let inverted_mask = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (image_name_for_test("/Width"), PdfInteger(2)),
      (image_name_for_test("/Height"), PdfInteger(1)),
      (image_name_for_test("/ImageMask"), PdfBoolean(true)),
      (image_name_for_test("/Decode"), PdfArray([PdfInteger(1), PdfInteger(0)])),
    ]),
    StreamGot(image_bytes_for_test([0b1000_0000])),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(@pdflite.pdf_dictionary([]), inverted_mask),
    PdfRawImage(2, 1, PdfBPP24, image_bytes_for_test([0, 0, 0, 255, 255, 255])),
  )
  let inverted_gray = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (image_name_for_test("/Width"), PdfInteger(2)),
      (image_name_for_test("/Height"), PdfInteger(1)),
      (
        image_name_for_test("/ColorSpace"),
        PdfNameObject(image_name_for_test("/DeviceGray")),
      ),
      (image_name_for_test("/BitsPerComponent"), PdfInteger(8)),
      (
        image_name_for_test("/Decode"),
        PdfArray([PdfInteger(255), PdfInteger(0)]),
      ),
    ]),
    StreamGot(image_bytes_for_test([0, 255])),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(@pdflite.pdf_dictionary([]), inverted_gray),
    PdfRawImage(2, 1, PdfBPP24, image_bytes_for_test([255, 255, 255, 0, 0, 0])),
  )
  let decoded_cmyk = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (image_name_for_test("/Width"), PdfInteger(1)),
      (image_name_for_test("/Height"), PdfInteger(1)),
      (
        image_name_for_test("/ColorSpace"),
        PdfNameObject(image_name_for_test("/DeviceCMYK")),
      ),
      (image_name_for_test("/BitsPerComponent"), PdfInteger(8)),
      (
        image_name_for_test("/Decode"),
        PdfArray([
          PdfInteger(0),
          PdfInteger(255),
          PdfInteger(0),
          PdfInteger(255),
          PdfInteger(0),
          PdfInteger(255),
          PdfInteger(255),
          PdfInteger(0),
        ]),
      ),
    ]),
    StreamGot(image_bytes_for_test([0, 0, 0, 0])),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(@pdflite.pdf_dictionary([]), decoded_cmyk),
    PdfRawImage(1, 1, PdfBPP24, image_bytes_for_test([0, 0, 0])),
  )
  let identity_empty_decode = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (image_name_for_test("/Width"), PdfInteger(1)),
      (image_name_for_test("/Height"), PdfInteger(1)),
      (
        image_name_for_test("/ColorSpace"),
        PdfNameObject(image_name_for_test("/DeviceRGB")),
      ),
      (image_name_for_test("/BitsPerComponent"), PdfInteger(8)),
      (image_name_for_test("/Decode"), PdfArray([])),
    ]),
    StreamGot(image_bytes_for_test([4, 5, 6])),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(@pdflite.pdf_dictionary([]), identity_empty_decode),
    PdfRawImage(1, 1, PdfBPP24, image_bytes_for_test([4, 5, 6])),
  )
  let malformed_decode = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (image_name_for_test("/Width"), PdfInteger(1)),
      (image_name_for_test("/Height"), PdfInteger(1)),
      (
        image_name_for_test("/ColorSpace"),
        PdfNameObject(image_name_for_test("/DeviceGray")),
      ),
      (image_name_for_test("/BitsPerComponent"), PdfInteger(8)),
      (image_name_for_test("/Decode"), PdfArray([PdfInteger(0)])),
    ]),
    StreamGot(image_bytes_for_test([0])),
  )
  let malformed_result : Result[@pdflite.PdfImage, Error] = try? doc.get_image_24bpp(
    @pdflite.pdf_dictionary([]),
    malformed_decode,
  )
  guard malformed_result is Err(@pdflite.PdfError::FilterExpected) else {
    fail("expected malformed decode array")
  }
  let decoded_gray4 = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (image_name_for_test("/Width"), PdfInteger(2)),
      (image_name_for_test("/Height"), PdfInteger(1)),
      (
        image_name_for_test("/ColorSpace"),
        PdfNameObject(image_name_for_test("/DeviceGray")),
      ),
      (image_name_for_test("/BitsPerComponent"), PdfInteger(4)),
      (image_name_for_test("/Decode"), PdfArray([PdfInteger(1), PdfInteger(0)])),
    ]),
    StreamGot(image_bytes_for_test([0x0F])),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(@pdflite.pdf_dictionary([]), decoded_gray4),
    PdfRawImage(2, 1, PdfBPP24, image_bytes_for_test([0, 0, 0, 255, 255, 255])),
  )
  let tint_function = @pdflite.pdf_dictionary([
    (image_name_for_test("/FunctionType"), PdfInteger(2)),
    (image_name_for_test("/Domain"), PdfArray([PdfInteger(0), PdfInteger(1)])),
    (
      image_name_for_test("/C0"),
      PdfArray([PdfInteger(0), PdfInteger(0), PdfInteger(0), PdfInteger(0)]),
    ),
    (
      image_name_for_test("/C1"),
      PdfArray([PdfInteger(0), PdfInteger(1), PdfInteger(0), PdfInteger(0)]),
    ),
    (image_name_for_test("/N"), PdfInteger(1)),
  ])
  let decoded_separation : @pdflite.PdfObject = PdfArray([
    PdfNameObject(image_name_for_test("/Separation")),
    PdfNameObject(image_name_for_test("/Spot")),
    PdfNameObject(image_name_for_test("/DeviceCMYK")),
    tint_function,
  ])
  let decoded_separation_image = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (image_name_for_test("/Width"), PdfInteger(1)),
      (image_name_for_test("/Height"), PdfInteger(1)),
      (image_name_for_test("/ColorSpace"), decoded_separation),
      (image_name_for_test("/BitsPerComponent"), PdfInteger(8)),
      (
        image_name_for_test("/Decode"),
        PdfArray([PdfInteger(255), PdfInteger(0)]),
      ),
    ]),
    StreamGot(image_bytes_for_test([0])),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(
      @pdflite.pdf_dictionary([]),
      decoded_separation_image,
    ),
    PdfRawImage(1, 1, PdfBPP24, image_bytes_for_test([255, 255, 0])),
  )
}

///|
test "PdfDocument get_image_24bpp rejects unsupported raw image spaces" {
  let doc = @pdflite.pdf_document_empty()
  let unsupported_rgb16 = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (image_name_for_test("/Width"), PdfInteger(1)),
      (image_name_for_test("/Height"), PdfInteger(1)),
      (
        image_name_for_test("/ColorSpace"),
        PdfNameObject(image_name_for_test("/DeviceRGB")),
      ),
      (image_name_for_test("/BitsPerComponent"), PdfInteger(16)),
    ]),
    StreamGot(image_bytes_for_test([0, 0, 0, 0, 0, 0])),
  )
  let unsupported : Result[@pdflite.PdfImage, Error] = try? doc.get_image_24bpp(
    @pdflite.pdf_dictionary([]),
    unsupported_rgb16,
  )
  guard unsupported is Err(@pdflite.PdfError::FilterExpected) else {
    fail("expected unsupported raw image")
  }
  let short_tint = @pdflite.pdf_dictionary([
    (image_name_for_test("/FunctionType"), PdfInteger(2)),
    (image_name_for_test("/Domain"), PdfArray([PdfInteger(0), PdfInteger(1)])),
    (image_name_for_test("/C0"), PdfArray([PdfInteger(0)])),
    (image_name_for_test("/C1"), PdfArray([PdfInteger(1)])),
    (image_name_for_test("/N"), PdfInteger(1)),
  ])
  let separation : @pdflite.PdfObject = PdfArray([
    PdfNameObject(image_name_for_test("/Separation")),
    PdfNameObject(image_name_for_test("/Spot")),
    PdfNameObject(image_name_for_test("/DeviceCMYK")),
    short_tint,
  ])
  let bad_separation = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (image_name_for_test("/Width"), PdfInteger(1)),
      (image_name_for_test("/Height"), PdfInteger(1)),
      (image_name_for_test("/ColorSpace"), separation),
      (image_name_for_test("/BitsPerComponent"), PdfInteger(8)),
    ]),
    StreamGot(image_bytes_for_test([255])),
  )
  let bad_tint : Result[@pdflite.PdfImage, Error] = try? doc.get_image_24bpp(
    @pdflite.pdf_dictionary([]),
    bad_separation,
  )
  guard bad_tint is Err(@pdflite.PdfError::FilterExpected) else {
    fail("expected malformed separation tint output")
  }
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
  let indexed_rgb4 : @pdflite.PdfObject = PdfArray([
    PdfNameObject(image_name_for_test("/Indexed")),
    PdfNameObject(image_name_for_test("/DeviceRGB")),
    PdfInteger(3),
    PdfString(
      image_bytes_for_test([10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 110, 120]),
    ),
  ])
  let rgb2 = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (image_name_for_test("/Width"), PdfInteger(5)),
      (image_name_for_test("/Height"), PdfInteger(1)),
      (image_name_for_test("/ColorSpace"), indexed_rgb4),
      (image_name_for_test("/BitsPerComponent"), PdfInteger(2)),
    ]),
    StreamGot(image_bytes_for_test([0b0001_1011, 0b1000_0000])),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(empty_resources, rgb2),
    PdfRawImage(
      5,
      1,
      PdfBPP24,
      image_bytes_for_test([
        10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 110, 120, 70, 80, 90,
      ]),
    ),
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
  let indexed_cmyk4 : @pdflite.PdfObject = PdfArray([
    PdfNameObject(image_name_for_test("/Indexed")),
    PdfNameObject(image_name_for_test("/DeviceCMYK")),
    PdfInteger(3),
    PdfString(
      image_bytes_for_test([
        0, 0, 0, 0, 0, 255, 255, 0, 255, 0, 255, 0, 255, 255, 0, 0,
      ]),
    ),
  ])
  let cmyk2 = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (image_name_for_test("/Width"), PdfInteger(4)),
      (image_name_for_test("/Height"), PdfInteger(1)),
      (image_name_for_test("/ColorSpace"), indexed_cmyk4),
      (image_name_for_test("/BitsPerComponent"), PdfInteger(2)),
    ]),
    StreamGot(image_bytes_for_test([0b0001_1011])),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(empty_resources, cmyk2),
    PdfRawImage(
      4,
      1,
      PdfBPP24,
      image_bytes_for_test([255, 255, 255, 255, 0, 0, 0, 255, 0, 0, 0, 255]),
    ),
  )
  let cmyk8 = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (image_name_for_test("/Width"), PdfInteger(2)),
      (image_name_for_test("/Height"), PdfInteger(1)),
      (image_name_for_test("/ColorSpace"), indexed_cmyk),
      (image_name_for_test("/BitsPerComponent"), PdfInteger(8)),
    ]),
    StreamGot(image_bytes_for_test([0, 1])),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(empty_resources, cmyk8),
    PdfRawImage(
      2,
      1,
      PdfBPP24,
      image_bytes_for_test([255, 255, 255, 255, 0, 0]),
    ),
  )
  let rgb4 = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (image_name_for_test("/Width"), PdfInteger(2)),
      (image_name_for_test("/Height"), PdfInteger(1)),
      (image_name_for_test("/ColorSpace"), indexed_rgb),
      (image_name_for_test("/BitsPerComponent"), PdfInteger(4)),
    ]),
    StreamGot(image_bytes_for_test([0x01])),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(empty_resources, rgb4),
    PdfRawImage(2, 1, PdfBPP24, image_bytes_for_test([10, 20, 30, 40, 50, 60])),
  )
  let icc_rgb_base = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([(image_name_for_test("/N"), PdfInteger(3))]),
    StreamGot(@ascii.encode("icc")),
  )
  let indexed_icc_rgb : @pdflite.PdfObject = PdfArray([
    PdfNameObject(image_name_for_test("/Indexed")),
    PdfArray([PdfNameObject(image_name_for_test("/ICCBased")), icc_rgb_base]),
    PdfInteger(1),
    PdfString(image_bytes_for_test([1, 2, 3, 4, 5, 6])),
  ])
  let icc_rgb4 = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (image_name_for_test("/Width"), PdfInteger(2)),
      (image_name_for_test("/Height"), PdfInteger(1)),
      (image_name_for_test("/ColorSpace"), indexed_icc_rgb),
      (image_name_for_test("/BitsPerComponent"), PdfInteger(4)),
    ]),
    StreamGot(image_bytes_for_test([0x01])),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(empty_resources, icc_rgb4),
    PdfRawImage(2, 1, PdfBPP24, image_bytes_for_test([1, 2, 3, 4, 5, 6])),
  )
  let device_n_cmyk_base : @pdflite.PdfObject = PdfArray([
    PdfNameObject(image_name_for_test("/DeviceN")),
    PdfArray([PdfNameObject(image_name_for_test("/Spot"))]),
    PdfNameObject(image_name_for_test("/DeviceCMYK")),
    PdfNull,
  ])
  let indexed_device_n_cmyk : @pdflite.PdfObject = PdfArray([
    PdfNameObject(image_name_for_test("/Indexed")),
    device_n_cmyk_base,
    PdfInteger(1),
    PdfString(image_bytes_for_test([0, 0, 0, 0, 0, 255, 255, 0])),
  ])
  let device_n_cmyk8 = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (image_name_for_test("/Width"), PdfInteger(2)),
      (image_name_for_test("/Height"), PdfInteger(1)),
      (image_name_for_test("/ColorSpace"), indexed_device_n_cmyk),
      (image_name_for_test("/BitsPerComponent"), PdfInteger(8)),
    ]),
    StreamGot(image_bytes_for_test([0, 1])),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(empty_resources, device_n_cmyk8),
    PdfRawImage(
      2,
      1,
      PdfBPP24,
      image_bytes_for_test([255, 255, 255, 255, 0, 0]),
    ),
  )
  let missing_index = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (image_name_for_test("/Width"), PdfInteger(1)),
      (image_name_for_test("/Height"), PdfInteger(1)),
      (image_name_for_test("/ColorSpace"), indexed_rgb),
      (image_name_for_test("/BitsPerComponent"), PdfInteger(8)),
    ]),
    StreamGot(image_bytes_for_test([2])),
  )
  let missing_result : Result[@pdflite.PdfImage, Error] = try? doc.get_image_24bpp(
    empty_resources, missing_index,
  )
  guard missing_result is Err(@pdflite.PdfError::EndOfInput) else {
    fail("expected indexed table lookup failure")
  }
}

///|
test "PdfDocument get_image_24bpp converts Lab indexed image tables" {
  let doc = @pdflite.pdf_document_empty()
  let lab_space : @pdflite.PdfObject = PdfArray([
    PdfNameObject(image_name_for_test("/Lab")),
    @pdflite.pdf_dictionary([
      (
        image_name_for_test("/WhitePoint"),
        PdfArray([PdfInteger(1000), PdfInteger(1000), PdfInteger(1000)]),
      ),
    ]),
  ])
  let indexed_lab : @pdflite.PdfObject = PdfArray([
    PdfNameObject(image_name_for_test("/Indexed")),
    lab_space,
    PdfInteger(3),
    PdfString(
      image_bytes_for_test([
        127, 127, 127, 255, 127, 127, 255, 255, 255, 255, 0, 0,
      ]),
    ),
  ])
  let image8 = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (image_name_for_test("/Width"), PdfInteger(4)),
      (image_name_for_test("/Height"), PdfInteger(1)),
      (image_name_for_test("/ColorSpace"), indexed_lab),
      (image_name_for_test("/BitsPerComponent"), PdfInteger(8)),
    ]),
    StreamGot(image_bytes_for_test([0, 1, 2, 3])),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(@pdflite.pdf_dictionary([]), image8),
    PdfRawImage(
      4,
      1,
      PdfBPP24,
      image_bytes_for_test([0, 0, 0, 141, 141, 141, 255, 104, 47, 25, 178, 235]),
    ),
  )
  let image4 = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (image_name_for_test("/Width"), PdfInteger(4)),
      (image_name_for_test("/Height"), PdfInteger(1)),
      (image_name_for_test("/ColorSpace"), indexed_lab),
      (image_name_for_test("/BitsPerComponent"), PdfInteger(4)),
    ]),
    StreamGot(image_bytes_for_test([0x12, 0x30])),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(@pdflite.pdf_dictionary([]), image4),
    PdfRawImage(
      4,
      1,
      PdfBPP24,
      image_bytes_for_test([141, 141, 141, 255, 104, 47, 25, 178, 235, 0, 0, 0]),
    ),
  )
  let image2 = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (image_name_for_test("/Width"), PdfInteger(5)),
      (image_name_for_test("/Height"), PdfInteger(1)),
      (image_name_for_test("/ColorSpace"), indexed_lab),
      (image_name_for_test("/BitsPerComponent"), PdfInteger(2)),
    ]),
    StreamGot(image_bytes_for_test([0b0001_1011, 0b0100_0000])),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(@pdflite.pdf_dictionary([]), image2),
    PdfRawImage(
      5,
      1,
      PdfBPP24,
      image_bytes_for_test([
        0, 0, 0, 141, 141, 141, 255, 104, 47, 25, 178, 235, 141, 141, 141,
      ]),
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
  @test.assert_eq(
    doc.bpc(
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
