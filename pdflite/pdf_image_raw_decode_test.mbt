///|
fn image_raw_name_for_test(text : String) -> @core.PdfName {
  @core.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn image_raw_bytes_for_test(values : ArrayView[Int]) -> @core.PdfBytes {
  try! @core.pdf_bytes_of_int_array(values)
}

///|
test "PdfDocument get_image_24bpp validates malformed image dictionary values" {
  let doc = @pdflite.pdf_document_empty()
  let empty_resources = @syntax.pdf_dictionary([])
  let bad_width = @syntax.pdf_stream(
    @syntax.pdf_dictionary([
      (
        image_raw_name_for_test("/Width"),
        PdfNameObject(image_raw_name_for_test("/Bad")),
      ),
      (image_raw_name_for_test("/Height"), PdfInteger(1)),
      (
        image_raw_name_for_test("/Filter"),
        PdfNameObject(image_raw_name_for_test("/DCTDecode")),
      ),
    ]),
    StreamGot(@ascii.encode("jpg")),
  )
  let width_result : Result[@pdflite.PdfImage, Error] = try
    doc.get_image_24bpp(empty_resources, bad_width)
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard width_result is Err(@core.PdfError::NumberExpected) else {
    fail("expected malformed width")
  }
  let bad_bpc = @syntax.pdf_stream(
    @syntax.pdf_dictionary([
      (image_raw_name_for_test("/Width"), PdfInteger(1)),
      (image_raw_name_for_test("/Height"), PdfInteger(1)),
      (
        image_raw_name_for_test("/ColorSpace"),
        PdfNameObject(image_raw_name_for_test("/DeviceRGB")),
      ),
      (
        image_raw_name_for_test("/BitsPerComponent"),
        PdfNameObject(image_raw_name_for_test("/Bad")),
      ),
    ]),
    StreamGot(image_raw_bytes_for_test([10, 20, 30])),
  )
  let bpc_result : Result[@pdflite.PdfImage, Error] = try
    doc.get_image_24bpp(empty_resources, bad_bpc)
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard bpc_result is Err(@core.PdfError::NumberExpected) else {
    fail("expected malformed bits per component")
  }
  let bad_decode = @syntax.pdf_stream(
    @syntax.pdf_dictionary([
      (image_raw_name_for_test("/Width"), PdfInteger(1)),
      (image_raw_name_for_test("/Height"), PdfInteger(1)),
      (
        image_raw_name_for_test("/Filter"),
        PdfNameObject(image_raw_name_for_test("/DCTDecode")),
      ),
      (
        image_raw_name_for_test("/Decode"),
        PdfNameObject(image_raw_name_for_test("/Bad")),
      ),
    ]),
    StreamGot(@ascii.encode("jpg")),
  )
  let decode_result : Result[@pdflite.PdfImage, Error] = try
    doc.get_image_24bpp(empty_resources, bad_decode)
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard decode_result is Err(@core.PdfError::NumberExpected) else {
    fail("expected malformed decode")
  }
  let missing_width = @syntax.pdf_stream(
    @syntax.pdf_dictionary([
      (image_raw_name_for_test("/Height"), PdfInteger(1)),
      (
        image_raw_name_for_test("/Filter"),
        PdfNameObject(image_raw_name_for_test("/DCTDecode")),
      ),
    ]),
    StreamGot(@ascii.encode("jpg")),
  )
  let missing_width_result : Result[@pdflite.PdfImage, Error] = try
    doc.get_image_24bpp(empty_resources, missing_width)
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard missing_width_result is Err(@core.PdfError::DictionaryKeyNotFound(name)) &&
    name == image_raw_name_for_test("/Width") else {
    fail("expected missing width")
  }
  let missing_bpc = @syntax.pdf_stream(
    @syntax.pdf_dictionary([
      (image_raw_name_for_test("/Width"), PdfInteger(1)),
      (image_raw_name_for_test("/Height"), PdfInteger(1)),
      (
        image_raw_name_for_test("/ColorSpace"),
        PdfNameObject(image_raw_name_for_test("/DeviceRGB")),
      ),
    ]),
    StreamGot(image_raw_bytes_for_test([10, 20, 30])),
  )
  let missing_bpc_result : Result[@pdflite.PdfImage, Error] = try
    doc.get_image_24bpp(empty_resources, missing_bpc)
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard missing_bpc_result is Err(@core.PdfError::FilterExpected) else {
    fail("expected missing bits per component")
  }
  let not_stream : Result[@pdflite.PdfImage, Error] = try
    doc.get_image_24bpp(empty_resources, PdfInteger(1))
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard not_stream is Err(@core.PdfError::ParseStreamExpected) else {
    fail("expected image stream")
  }
}

///|
test "PdfDocument get_image_24bpp derives encoded image decode defaults" {
  let doc = @pdflite.pdf_document_empty()
  let lab_space : @syntax.PdfObject = PdfArray([
    PdfNameObject(image_raw_name_for_test("/Lab")),
    @syntax.pdf_dictionary([
      (
        image_raw_name_for_test("/WhitePoint"),
        PdfArray([PdfInteger(1), PdfInteger(1), PdfInteger(1)]),
      ),
      (
        image_raw_name_for_test("/Range"),
        PdfArray([
          PdfInteger(-80),
          PdfInteger(90),
          PdfInteger(-70),
          PdfInteger(85),
        ]),
      ),
    ]),
  ])
  let lab_jpeg = @syntax.pdf_stream(
    @syntax.pdf_dictionary([
      (image_raw_name_for_test("/Width"), PdfInteger(1)),
      (image_raw_name_for_test("/Height"), PdfInteger(1)),
      (
        image_raw_name_for_test("/Filter"),
        PdfNameObject(image_raw_name_for_test("/DCTDecode")),
      ),
      (image_raw_name_for_test("/ColorSpace"), lab_space),
    ]),
    StreamGot(@ascii.encode("lab")),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(@syntax.pdf_dictionary([]), lab_jpeg),
    PdfJPEG(@ascii.encode("lab"), Some([0.0, 1.0, -80.0, 90.0, -70.0, 85.0])),
  )
  let tint = @syntax.pdf_dictionary([
    (image_raw_name_for_test("/FunctionType"), PdfInteger(2)),
  ])
  let device_n_space : @syntax.PdfObject = PdfArray([
    PdfNameObject(image_raw_name_for_test("/DeviceN")),
    PdfArray([
      PdfNameObject(image_raw_name_for_test("/Cyan")),
      PdfNameObject(image_raw_name_for_test("/Magenta")),
    ]),
    PdfNameObject(image_raw_name_for_test("/DeviceCMYK")),
    tint,
  ])
  let device_n_jpeg = @syntax.pdf_stream(
    @syntax.pdf_dictionary([
      (image_raw_name_for_test("/Width"), PdfInteger(1)),
      (image_raw_name_for_test("/Height"), PdfInteger(1)),
      (
        image_raw_name_for_test("/Filter"),
        PdfNameObject(image_raw_name_for_test("/DCTDecode")),
      ),
      (image_raw_name_for_test("/ColorSpace"), device_n_space),
    ]),
    StreamGot(@ascii.encode("device-n")),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(@syntax.pdf_dictionary([]), device_n_jpeg),
    PdfJPEG(@ascii.encode("device-n"), Some([0.0, 1.0, 0.0, 1.0])),
  )
  let indexed_rgb : @syntax.PdfObject = PdfArray([
    PdfNameObject(image_raw_name_for_test("/Indexed")),
    PdfNameObject(image_raw_name_for_test("/DeviceRGB")),
    PdfInteger(0),
    PdfString(image_raw_bytes_for_test([10, 20, 30])),
  ])
  let indexed_jpeg = @syntax.pdf_stream(
    @syntax.pdf_dictionary([
      (image_raw_name_for_test("/Width"), PdfInteger(1)),
      (image_raw_name_for_test("/Height"), PdfInteger(1)),
      (
        image_raw_name_for_test("/Filter"),
        PdfNameObject(image_raw_name_for_test("/DCTDecode")),
      ),
      (image_raw_name_for_test("/ColorSpace"), indexed_rgb),
      (
        image_raw_name_for_test("/Decode"),
        PdfArray([PdfInteger(0), PdfInteger(1)]),
      ),
    ]),
    StreamGot(@ascii.encode("indexed")),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(@syntax.pdf_dictionary([]), indexed_jpeg),
    PdfJPEG(@ascii.encode("indexed"), Some([0.0, 1.0])),
  )
  let pattern_jpeg = @syntax.pdf_stream(
    @syntax.pdf_dictionary([
      (image_raw_name_for_test("/Width"), PdfInteger(1)),
      (image_raw_name_for_test("/Height"), PdfInteger(1)),
      (
        image_raw_name_for_test("/Filter"),
        PdfNameObject(image_raw_name_for_test("/DCTDecode")),
      ),
      (
        image_raw_name_for_test("/ColorSpace"),
        PdfNameObject(image_raw_name_for_test("/Pattern")),
      ),
    ]),
    StreamGot(@ascii.encode("pattern")),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(@syntax.pdf_dictionary([]), pattern_jpeg),
    PdfJPEG(@ascii.encode("pattern"), None),
  )
}

///|
test "PdfDocument get_image_24bpp reads raw RGB gray and CMYK images" {
  let doc = @pdflite.pdf_document_empty()
  let empty_resources = @syntax.pdf_dictionary([])
  let rgb_data = image_raw_bytes_for_test([1, 2, 3, 4, 5, 6])
  let rgb = @syntax.pdf_stream(
    @syntax.pdf_dictionary([
      (image_raw_name_for_test("/Width"), PdfInteger(2)),
      (image_raw_name_for_test("/Height"), PdfInteger(1)),
      (
        image_raw_name_for_test("/ColorSpace"),
        PdfNameObject(image_raw_name_for_test("/DeviceRGB")),
      ),
      (image_raw_name_for_test("/BitsPerComponent"), PdfInteger(8)),
    ]),
    StreamGot(rgb_data),
  )
  let rgb_result = doc.get_image_24bpp(empty_resources, rgb)
  @test.assert_eq(
    rgb_result,
    PdfRawImage(2, 1, PdfBPP24, image_raw_bytes_for_test([1, 2, 3, 4, 5, 6])),
  )
  match rgb_result {
    PdfRawImage(_, _, _, data) =>
      @test.assert_eq(physical_equal(rgb_data, data), true)
    _ => fail("expected raw RGB image")
  }
  let rgb_extra_data = image_raw_bytes_for_test([1, 2, 3, 4, 5, 6, 7])
  let rgb_extra = @syntax.pdf_stream(
    @syntax.pdf_dictionary([
      (image_raw_name_for_test("/Width"), PdfInteger(2)),
      (image_raw_name_for_test("/Height"), PdfInteger(1)),
      (
        image_raw_name_for_test("/ColorSpace"),
        PdfNameObject(image_raw_name_for_test("/DeviceRGB")),
      ),
      (image_raw_name_for_test("/BitsPerComponent"), PdfInteger(8)),
    ]),
    StreamGot(rgb_extra_data),
  )
  let rgb_extra_result = doc.get_image_24bpp(empty_resources, rgb_extra)
  @test.assert_eq(
    rgb_extra_result,
    PdfRawImage(2, 1, PdfBPP24, image_raw_bytes_for_test([1, 2, 3, 4, 5, 6])),
  )
  match rgb_extra_result {
    PdfRawImage(_, _, _, data) =>
      @test.assert_eq(physical_equal(rgb_extra_data, data), false)
    _ => fail("expected raw RGB image")
  }
  let gray = @syntax.pdf_stream(
    @syntax.pdf_dictionary([
      (image_raw_name_for_test("/Width"), PdfInteger(2)),
      (image_raw_name_for_test("/Height"), PdfInteger(1)),
      (
        image_raw_name_for_test("/ColorSpace"),
        PdfNameObject(image_raw_name_for_test("/DeviceGray")),
      ),
      (image_raw_name_for_test("/BitsPerComponent"), PdfInteger(8)),
    ]),
    StreamGot(image_raw_bytes_for_test([9, 10])),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(empty_resources, gray),
    PdfRawImage(2, 1, PdfBPP24, image_raw_bytes_for_test([9, 9, 9, 10, 10, 10])),
  )
  let cmyk = @syntax.pdf_stream(
    @syntax.pdf_dictionary([
      (image_raw_name_for_test("/Width"), PdfInteger(1)),
      (image_raw_name_for_test("/Height"), PdfInteger(1)),
      (
        image_raw_name_for_test("/ColorSpace"),
        PdfNameObject(image_raw_name_for_test("/DeviceCMYK")),
      ),
      (image_raw_name_for_test("/BitsPerComponent"), PdfInteger(8)),
    ]),
    StreamGot(image_raw_bytes_for_test([0, 0, 0, 0])),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(empty_resources, cmyk),
    PdfRawImage(1, 1, PdfBPP24, image_raw_bytes_for_test([255, 255, 255])),
  )
}

///|
test "PdfDocument get_image_24bpp reads raw ICCBased images through alternate space" {
  let doc = @pdflite.pdf_document_empty()
  let icc_gray : @syntax.PdfObject = PdfArray([
    PdfNameObject(image_raw_name_for_test("/ICCBased")),
    @syntax.pdf_stream(
      @syntax.pdf_dictionary([(image_raw_name_for_test("/N"), PdfInteger(1))]),
      StreamGot(@ascii.encode("icc")),
    ),
  ])
  let image = @syntax.pdf_stream(
    @syntax.pdf_dictionary([
      (image_raw_name_for_test("/Width"), PdfInteger(2)),
      (image_raw_name_for_test("/Height"), PdfInteger(1)),
      (image_raw_name_for_test("/ColorSpace"), icc_gray),
      (image_raw_name_for_test("/BitsPerComponent"), PdfInteger(8)),
    ]),
    StreamGot(image_raw_bytes_for_test([9, 10])),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(@syntax.pdf_dictionary([]), image),
    PdfRawImage(2, 1, PdfBPP24, image_raw_bytes_for_test([9, 9, 9, 10, 10, 10])),
  )
}

///|
test "PdfDocument get_image_24bpp reads Separation images with Type 2 CMYK tint" {
  let doc = @pdflite.pdf_document_empty()
  let tint_function = @syntax.pdf_dictionary([
    (image_raw_name_for_test("/FunctionType"), PdfInteger(2)),
    (
      image_raw_name_for_test("/Domain"),
      PdfArray([PdfInteger(0), PdfInteger(1)]),
    ),
    (
      image_raw_name_for_test("/C0"),
      PdfArray([PdfInteger(0), PdfInteger(0), PdfInteger(0), PdfInteger(0)]),
    ),
    (
      image_raw_name_for_test("/C1"),
      PdfArray([PdfInteger(0), PdfInteger(1), PdfInteger(0), PdfInteger(0)]),
    ),
    (image_raw_name_for_test("/N"), PdfInteger(1)),
  ])
  let separation : @syntax.PdfObject = PdfArray([
    PdfNameObject(image_raw_name_for_test("/Separation")),
    PdfNameObject(image_raw_name_for_test("/Spot")),
    PdfNameObject(image_raw_name_for_test("/DeviceCMYK")),
    tint_function,
  ])
  let image = @syntax.pdf_stream(
    @syntax.pdf_dictionary([
      (image_raw_name_for_test("/Width"), PdfInteger(1)),
      (image_raw_name_for_test("/Height"), PdfInteger(1)),
      (image_raw_name_for_test("/ColorSpace"), separation),
      (image_raw_name_for_test("/BitsPerComponent"), PdfInteger(8)),
    ]),
    StreamGot(image_raw_bytes_for_test([255])),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(@syntax.pdf_dictionary([]), image),
    PdfRawImage(1, 1, PdfBPP24, image_raw_bytes_for_test([255, 255, 0])),
  )
}

///|
test "PdfDocument get_image_24bpp reads Separation images with Type 4 CMYK tint" {
  let doc = @pdflite.pdf_document_empty()
  let tint_data = @ascii.encode(
    "{ dup 0.5 lt { 0 } { 1 } ifelse exch pop 0 exch 0 0 }",
  )
  let tint_function = @syntax.pdf_stream(
    @syntax.pdf_dictionary([
      (image_raw_name_for_test("/Length"), PdfInteger(tint_data.length())),
      (image_raw_name_for_test("/FunctionType"), PdfInteger(4)),
      (
        image_raw_name_for_test("/Domain"),
        PdfArray([PdfInteger(0), PdfInteger(1)]),
      ),
      (
        image_raw_name_for_test("/Range"),
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
  let separation : @syntax.PdfObject = PdfArray([
    PdfNameObject(image_raw_name_for_test("/Separation")),
    PdfNameObject(image_raw_name_for_test("/Spot")),
    PdfNameObject(image_raw_name_for_test("/DeviceCMYK")),
    tint_function,
  ])
  let image = @syntax.pdf_stream(
    @syntax.pdf_dictionary([
      (image_raw_name_for_test("/Width"), PdfInteger(2)),
      (image_raw_name_for_test("/Height"), PdfInteger(1)),
      (image_raw_name_for_test("/ColorSpace"), separation),
      (image_raw_name_for_test("/BitsPerComponent"), PdfInteger(8)),
    ]),
    StreamGot(image_raw_bytes_for_test([0, 255])),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(@syntax.pdf_dictionary([]), image),
    PdfRawImage(
      2,
      1,
      PdfBPP24,
      image_raw_bytes_for_test([255, 255, 255, 255, 255, 0]),
    ),
  )
}

///|
test "PdfDocument get_image_24bpp reads packed grayscale images" {
  let doc = @pdflite.pdf_document_empty()
  let mask = @syntax.pdf_stream(
    @syntax.pdf_dictionary([
      (image_raw_name_for_test("/Width"), PdfInteger(3)),
      (image_raw_name_for_test("/Height"), PdfInteger(2)),
      (image_raw_name_for_test("/ImageMask"), PdfBoolean(true)),
    ]),
    StreamGot(image_raw_bytes_for_test([0b1010_0000, 0b0100_0000])),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(@syntax.pdf_dictionary([]), mask),
    PdfRawImage(
      3,
      2,
      PdfBPP24,
      image_raw_bytes_for_test([
        255, 255, 255, 0, 0, 0, 255, 255, 255, 0, 0, 0, 255, 255, 255, 0, 0, 0,
      ]),
    ),
  )
  let gray2 = @syntax.pdf_stream(
    @syntax.pdf_dictionary([
      (image_raw_name_for_test("/Width"), PdfInteger(5)),
      (image_raw_name_for_test("/Height"), PdfInteger(2)),
      (
        image_raw_name_for_test("/ColorSpace"),
        PdfNameObject(image_raw_name_for_test("/DeviceGray")),
      ),
      (image_raw_name_for_test("/BitsPerComponent"), PdfInteger(2)),
    ]),
    StreamGot(
      image_raw_bytes_for_test([0b0001_1011, 0, 0b1110_0100, 0b1100_0000]),
    ),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(@syntax.pdf_dictionary([]), gray2),
    PdfRawImage(
      5,
      2,
      PdfBPP24,
      image_raw_bytes_for_test([
        0, 0, 0, 85, 85, 85, 170, 170, 170, 255, 255, 255, 0, 0, 0, 255, 255, 255,
        170, 170, 170, 85, 85, 85, 0, 0, 0, 255, 255, 255,
      ]),
    ),
  )
  let gray4 = @syntax.pdf_stream(
    @syntax.pdf_dictionary([
      (image_raw_name_for_test("/Width"), PdfInteger(3)),
      (image_raw_name_for_test("/Height"), PdfInteger(1)),
      (
        image_raw_name_for_test("/ColorSpace"),
        PdfNameObject(image_raw_name_for_test("/DeviceGray")),
      ),
      (image_raw_name_for_test("/BitsPerComponent"), PdfInteger(4)),
    ]),
    StreamGot(image_raw_bytes_for_test([0x0F, 0x80])),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(@syntax.pdf_dictionary([]), gray4),
    PdfRawImage(
      3,
      1,
      PdfBPP24,
      image_raw_bytes_for_test([0, 0, 0, 255, 255, 255, 136, 136, 136]),
    ),
  )
  let cal_gray_space : @syntax.PdfObject = PdfArray([
    PdfNameObject(image_raw_name_for_test("/CalGray")),
    @syntax.pdf_dictionary([]),
  ])
  let cal_gray2 = @syntax.pdf_stream(
    @syntax.pdf_dictionary([
      (image_raw_name_for_test("/Width"), PdfInteger(4)),
      (image_raw_name_for_test("/Height"), PdfInteger(1)),
      (image_raw_name_for_test("/ColorSpace"), cal_gray_space),
      (image_raw_name_for_test("/BitsPerComponent"), PdfInteger(2)),
    ]),
    StreamGot(image_raw_bytes_for_test([0b0001_1011])),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(@syntax.pdf_dictionary([]), cal_gray2),
    PdfRawImage(
      4,
      1,
      PdfBPP24,
      image_raw_bytes_for_test([
        0, 0, 0, 85, 85, 85, 170, 170, 170, 255, 255, 255,
      ]),
    ),
  )
  let cal_gray4 = @syntax.pdf_stream(
    @syntax.pdf_dictionary([
      (image_raw_name_for_test("/Width"), PdfInteger(2)),
      (image_raw_name_for_test("/Height"), PdfInteger(1)),
      (image_raw_name_for_test("/ColorSpace"), cal_gray_space),
      (image_raw_name_for_test("/BitsPerComponent"), PdfInteger(4)),
    ]),
    StreamGot(image_raw_bytes_for_test([0x0F])),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(@syntax.pdf_dictionary([]), cal_gray4),
    PdfRawImage(
      2,
      1,
      PdfBPP24,
      image_raw_bytes_for_test([0, 0, 0, 255, 255, 255]),
    ),
  )
}

///|
test "PdfDocument get_image_24bpp reads packed RGB images" {
  let doc = @pdflite.pdf_document_empty()
  let empty_resources = @syntax.pdf_dictionary([])
  let rgb1 = @syntax.pdf_stream(
    @syntax.pdf_dictionary([
      (image_raw_name_for_test("/Width"), PdfInteger(2)),
      (image_raw_name_for_test("/Height"), PdfInteger(1)),
      (
        image_raw_name_for_test("/ColorSpace"),
        PdfNameObject(image_raw_name_for_test("/DeviceRGB")),
      ),
      (image_raw_name_for_test("/BitsPerComponent"), PdfInteger(1)),
    ]),
    StreamGot(image_raw_bytes_for_test([0b1010_1000])),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(empty_resources, rgb1),
    PdfRawImage(
      2,
      1,
      PdfBPP24,
      image_raw_bytes_for_test([255, 0, 255, 0, 255, 0]),
    ),
  )
  let rgb2 = @syntax.pdf_stream(
    @syntax.pdf_dictionary([
      (image_raw_name_for_test("/Width"), PdfInteger(2)),
      (image_raw_name_for_test("/Height"), PdfInteger(1)),
      (
        image_raw_name_for_test("/ColorSpace"),
        PdfNameObject(image_raw_name_for_test("/DeviceRGB")),
      ),
      (image_raw_name_for_test("/BitsPerComponent"), PdfInteger(2)),
    ]),
    StreamGot(image_raw_bytes_for_test([0b0001_1011, 0b1001_0000])),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(empty_resources, rgb2),
    PdfRawImage(
      2,
      1,
      PdfBPP24,
      image_raw_bytes_for_test([0, 85, 170, 255, 170, 85]),
    ),
  )
  let rgb4 = @syntax.pdf_stream(
    @syntax.pdf_dictionary([
      (image_raw_name_for_test("/Width"), PdfInteger(2)),
      (image_raw_name_for_test("/Height"), PdfInteger(1)),
      (
        image_raw_name_for_test("/ColorSpace"),
        PdfNameObject(image_raw_name_for_test("/DeviceRGB")),
      ),
      (image_raw_name_for_test("/BitsPerComponent"), PdfInteger(4)),
    ]),
    StreamGot(image_raw_bytes_for_test([0x0F, 0x81, 0x23])),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(empty_resources, rgb4),
    PdfRawImage(
      2,
      1,
      PdfBPP24,
      image_raw_bytes_for_test([0, 255, 136, 17, 34, 51]),
    ),
  )
  let cal_rgb_space : @syntax.PdfObject = PdfArray([
    PdfNameObject(image_raw_name_for_test("/CalRGB")),
    @syntax.pdf_dictionary([]),
  ])
  let cal_rgb2 = @syntax.pdf_stream(
    @syntax.pdf_dictionary([
      (image_raw_name_for_test("/Width"), PdfInteger(1)),
      (image_raw_name_for_test("/Height"), PdfInteger(1)),
      (image_raw_name_for_test("/ColorSpace"), cal_rgb_space),
      (image_raw_name_for_test("/BitsPerComponent"), PdfInteger(2)),
    ]),
    StreamGot(image_raw_bytes_for_test([0b1100_0100])),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(empty_resources, cal_rgb2),
    PdfRawImage(1, 1, PdfBPP24, image_raw_bytes_for_test([255, 0, 85])),
  )
}

///|
test "PdfDocument get_image_24bpp applies raw image Decode arrays" {
  let doc = @pdflite.pdf_document_empty()
  let inverted_mask = @syntax.pdf_stream(
    @syntax.pdf_dictionary([
      (image_raw_name_for_test("/Width"), PdfInteger(2)),
      (image_raw_name_for_test("/Height"), PdfInteger(1)),
      (image_raw_name_for_test("/ImageMask"), PdfBoolean(true)),
      (
        image_raw_name_for_test("/Decode"),
        PdfArray([PdfInteger(1), PdfInteger(0)]),
      ),
    ]),
    StreamGot(image_raw_bytes_for_test([0b1000_0000])),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(@syntax.pdf_dictionary([]), inverted_mask),
    PdfRawImage(
      2,
      1,
      PdfBPP24,
      image_raw_bytes_for_test([0, 0, 0, 255, 255, 255]),
    ),
  )
  let inverted_gray = @syntax.pdf_stream(
    @syntax.pdf_dictionary([
      (image_raw_name_for_test("/Width"), PdfInteger(2)),
      (image_raw_name_for_test("/Height"), PdfInteger(1)),
      (
        image_raw_name_for_test("/ColorSpace"),
        PdfNameObject(image_raw_name_for_test("/DeviceGray")),
      ),
      (image_raw_name_for_test("/BitsPerComponent"), PdfInteger(8)),
      (
        image_raw_name_for_test("/Decode"),
        PdfArray([PdfInteger(255), PdfInteger(0)]),
      ),
    ]),
    StreamGot(image_raw_bytes_for_test([0, 255])),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(@syntax.pdf_dictionary([]), inverted_gray),
    PdfRawImage(
      2,
      1,
      PdfBPP24,
      image_raw_bytes_for_test([255, 255, 255, 0, 0, 0]),
    ),
  )
  let decoded_cmyk = @syntax.pdf_stream(
    @syntax.pdf_dictionary([
      (image_raw_name_for_test("/Width"), PdfInteger(1)),
      (image_raw_name_for_test("/Height"), PdfInteger(1)),
      (
        image_raw_name_for_test("/ColorSpace"),
        PdfNameObject(image_raw_name_for_test("/DeviceCMYK")),
      ),
      (image_raw_name_for_test("/BitsPerComponent"), PdfInteger(8)),
      (
        image_raw_name_for_test("/Decode"),
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
    StreamGot(image_raw_bytes_for_test([0, 0, 0, 0])),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(@syntax.pdf_dictionary([]), decoded_cmyk),
    PdfRawImage(1, 1, PdfBPP24, image_raw_bytes_for_test([0, 0, 0])),
  )
  let identity_empty_decode = @syntax.pdf_stream(
    @syntax.pdf_dictionary([
      (image_raw_name_for_test("/Width"), PdfInteger(1)),
      (image_raw_name_for_test("/Height"), PdfInteger(1)),
      (
        image_raw_name_for_test("/ColorSpace"),
        PdfNameObject(image_raw_name_for_test("/DeviceRGB")),
      ),
      (image_raw_name_for_test("/BitsPerComponent"), PdfInteger(8)),
      (image_raw_name_for_test("/Decode"), PdfArray([])),
    ]),
    StreamGot(image_raw_bytes_for_test([4, 5, 6])),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(@syntax.pdf_dictionary([]), identity_empty_decode),
    PdfRawImage(1, 1, PdfBPP24, image_raw_bytes_for_test([4, 5, 6])),
  )
  let malformed_decode = @syntax.pdf_stream(
    @syntax.pdf_dictionary([
      (image_raw_name_for_test("/Width"), PdfInteger(1)),
      (image_raw_name_for_test("/Height"), PdfInteger(1)),
      (
        image_raw_name_for_test("/ColorSpace"),
        PdfNameObject(image_raw_name_for_test("/DeviceGray")),
      ),
      (image_raw_name_for_test("/BitsPerComponent"), PdfInteger(8)),
      (image_raw_name_for_test("/Decode"), PdfArray([PdfInteger(0)])),
    ]),
    StreamGot(image_raw_bytes_for_test([0])),
  )
  let malformed_result : Result[@pdflite.PdfImage, Error] = try
    doc.get_image_24bpp(@syntax.pdf_dictionary([]), malformed_decode)
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard malformed_result is Err(@core.PdfError::FilterExpected) else {
    fail("expected malformed decode array")
  }
  let decoded_gray4 = @syntax.pdf_stream(
    @syntax.pdf_dictionary([
      (image_raw_name_for_test("/Width"), PdfInteger(2)),
      (image_raw_name_for_test("/Height"), PdfInteger(1)),
      (
        image_raw_name_for_test("/ColorSpace"),
        PdfNameObject(image_raw_name_for_test("/DeviceGray")),
      ),
      (image_raw_name_for_test("/BitsPerComponent"), PdfInteger(4)),
      (
        image_raw_name_for_test("/Decode"),
        PdfArray([PdfInteger(1), PdfInteger(0)]),
      ),
    ]),
    StreamGot(image_raw_bytes_for_test([0x0F])),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(@syntax.pdf_dictionary([]), decoded_gray4),
    PdfRawImage(
      2,
      1,
      PdfBPP24,
      image_raw_bytes_for_test([0, 0, 0, 255, 255, 255]),
    ),
  )
  let tint_function = @syntax.pdf_dictionary([
    (image_raw_name_for_test("/FunctionType"), PdfInteger(2)),
    (
      image_raw_name_for_test("/Domain"),
      PdfArray([PdfInteger(0), PdfInteger(1)]),
    ),
    (
      image_raw_name_for_test("/C0"),
      PdfArray([PdfInteger(0), PdfInteger(0), PdfInteger(0), PdfInteger(0)]),
    ),
    (
      image_raw_name_for_test("/C1"),
      PdfArray([PdfInteger(0), PdfInteger(1), PdfInteger(0), PdfInteger(0)]),
    ),
    (image_raw_name_for_test("/N"), PdfInteger(1)),
  ])
  let decoded_separation : @syntax.PdfObject = PdfArray([
    PdfNameObject(image_raw_name_for_test("/Separation")),
    PdfNameObject(image_raw_name_for_test("/Spot")),
    PdfNameObject(image_raw_name_for_test("/DeviceCMYK")),
    tint_function,
  ])
  let decoded_separation_image = @syntax.pdf_stream(
    @syntax.pdf_dictionary([
      (image_raw_name_for_test("/Width"), PdfInteger(1)),
      (image_raw_name_for_test("/Height"), PdfInteger(1)),
      (image_raw_name_for_test("/ColorSpace"), decoded_separation),
      (image_raw_name_for_test("/BitsPerComponent"), PdfInteger(8)),
      (
        image_raw_name_for_test("/Decode"),
        PdfArray([PdfInteger(255), PdfInteger(0)]),
      ),
    ]),
    StreamGot(image_raw_bytes_for_test([0])),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(
      @syntax.pdf_dictionary([]),
      decoded_separation_image,
    ),
    PdfRawImage(1, 1, PdfBPP24, image_raw_bytes_for_test([255, 255, 0])),
  )
}

///|
test "PdfDocument get_image_24bpp rejects unsupported raw image spaces" {
  let doc = @pdflite.pdf_document_empty()
  let unsupported_rgb16 = @syntax.pdf_stream(
    @syntax.pdf_dictionary([
      (image_raw_name_for_test("/Width"), PdfInteger(1)),
      (image_raw_name_for_test("/Height"), PdfInteger(1)),
      (
        image_raw_name_for_test("/ColorSpace"),
        PdfNameObject(image_raw_name_for_test("/DeviceRGB")),
      ),
      (image_raw_name_for_test("/BitsPerComponent"), PdfInteger(16)),
    ]),
    StreamGot(image_raw_bytes_for_test([0, 0, 0, 0, 0, 0])),
  )
  let unsupported : Result[@pdflite.PdfImage, Error] = try
    doc.get_image_24bpp(@syntax.pdf_dictionary([]), unsupported_rgb16)
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard unsupported is Err(@core.PdfError::FilterExpected) else {
    fail("expected unsupported raw image")
  }
  let short_tint = @syntax.pdf_dictionary([
    (image_raw_name_for_test("/FunctionType"), PdfInteger(2)),
    (
      image_raw_name_for_test("/Domain"),
      PdfArray([PdfInteger(0), PdfInteger(1)]),
    ),
    (image_raw_name_for_test("/C0"), PdfArray([PdfInteger(0)])),
    (image_raw_name_for_test("/C1"), PdfArray([PdfInteger(1)])),
    (image_raw_name_for_test("/N"), PdfInteger(1)),
  ])
  let separation : @syntax.PdfObject = PdfArray([
    PdfNameObject(image_raw_name_for_test("/Separation")),
    PdfNameObject(image_raw_name_for_test("/Spot")),
    PdfNameObject(image_raw_name_for_test("/DeviceCMYK")),
    short_tint,
  ])
  let bad_separation = @syntax.pdf_stream(
    @syntax.pdf_dictionary([
      (image_raw_name_for_test("/Width"), PdfInteger(1)),
      (image_raw_name_for_test("/Height"), PdfInteger(1)),
      (image_raw_name_for_test("/ColorSpace"), separation),
      (image_raw_name_for_test("/BitsPerComponent"), PdfInteger(8)),
    ]),
    StreamGot(image_raw_bytes_for_test([255])),
  )
  let bad_tint : Result[@pdflite.PdfImage, Error] = try
    doc.get_image_24bpp(@syntax.pdf_dictionary([]), bad_separation)
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard bad_tint is Err(@core.PdfError::FilterExpected) else {
    fail("expected malformed separation tint output")
  }
}

///|
test "PdfDocument get_image_24bpp reads indexed image tables" {
  let doc = @pdflite.pdf_document_empty()
  let empty_resources = @syntax.pdf_dictionary([])
  let indexed_rgb : @syntax.PdfObject = PdfArray([
    PdfNameObject(image_raw_name_for_test("/Indexed")),
    PdfNameObject(image_raw_name_for_test("/DeviceRGB")),
    PdfInteger(1),
    PdfString(image_raw_bytes_for_test([10, 20, 30, 40, 50, 60])),
  ])
  let rgb8 = @syntax.pdf_stream(
    @syntax.pdf_dictionary([
      (image_raw_name_for_test("/Width"), PdfInteger(2)),
      (image_raw_name_for_test("/Height"), PdfInteger(1)),
      (image_raw_name_for_test("/ColorSpace"), indexed_rgb),
      (image_raw_name_for_test("/BitsPerComponent"), PdfInteger(8)),
    ]),
    StreamGot(image_raw_bytes_for_test([0, 1])),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(empty_resources, rgb8),
    PdfRawImage(
      2,
      1,
      PdfBPP24,
      image_raw_bytes_for_test([10, 20, 30, 40, 50, 60]),
    ),
  )
  let rgb8_with_decode = @syntax.pdf_stream(
    @syntax.pdf_dictionary([
      (image_raw_name_for_test("/Width"), PdfInteger(1)),
      (image_raw_name_for_test("/Height"), PdfInteger(1)),
      (image_raw_name_for_test("/ColorSpace"), indexed_rgb),
      (image_raw_name_for_test("/BitsPerComponent"), PdfInteger(8)),
      (
        image_raw_name_for_test("/Decode"),
        PdfArray([PdfInteger(1), PdfInteger(0)]),
      ),
    ]),
    StreamGot(image_raw_bytes_for_test([0])),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(empty_resources, rgb8_with_decode),
    PdfRawImage(1, 1, PdfBPP24, image_raw_bytes_for_test([10, 20, 30])),
  )
  let rgb1 = @syntax.pdf_stream(
    @syntax.pdf_dictionary([
      (image_raw_name_for_test("/Width"), PdfInteger(3)),
      (image_raw_name_for_test("/Height"), PdfInteger(1)),
      (image_raw_name_for_test("/ColorSpace"), indexed_rgb),
      (image_raw_name_for_test("/BitsPerComponent"), PdfInteger(1)),
    ]),
    StreamGot(image_raw_bytes_for_test([0b0100_0000])),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(empty_resources, rgb1),
    PdfRawImage(
      3,
      1,
      PdfBPP24,
      image_raw_bytes_for_test([10, 20, 30, 40, 50, 60, 10, 20, 30]),
    ),
  )
  let indexed_rgb4 : @syntax.PdfObject = PdfArray([
    PdfNameObject(image_raw_name_for_test("/Indexed")),
    PdfNameObject(image_raw_name_for_test("/DeviceRGB")),
    PdfInteger(3),
    PdfString(
      image_raw_bytes_for_test([
        10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 110, 120,
      ]),
    ),
  ])
  let rgb2 = @syntax.pdf_stream(
    @syntax.pdf_dictionary([
      (image_raw_name_for_test("/Width"), PdfInteger(5)),
      (image_raw_name_for_test("/Height"), PdfInteger(1)),
      (image_raw_name_for_test("/ColorSpace"), indexed_rgb4),
      (image_raw_name_for_test("/BitsPerComponent"), PdfInteger(2)),
    ]),
    StreamGot(image_raw_bytes_for_test([0b0001_1011, 0b1000_0000])),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(empty_resources, rgb2),
    PdfRawImage(
      5,
      1,
      PdfBPP24,
      image_raw_bytes_for_test([
        10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 110, 120, 70, 80, 90,
      ]),
    ),
  )
  let indexed_cmyk : @syntax.PdfObject = PdfArray([
    PdfNameObject(image_raw_name_for_test("/Indexed")),
    PdfNameObject(image_raw_name_for_test("/DeviceCMYK")),
    PdfInteger(1),
    PdfString(image_raw_bytes_for_test([0, 0, 0, 0, 0, 255, 255, 0])),
  ])
  let cmyk4 = @syntax.pdf_stream(
    @syntax.pdf_dictionary([
      (image_raw_name_for_test("/Width"), PdfInteger(2)),
      (image_raw_name_for_test("/Height"), PdfInteger(1)),
      (image_raw_name_for_test("/ColorSpace"), indexed_cmyk),
      (image_raw_name_for_test("/BitsPerComponent"), PdfInteger(4)),
    ]),
    StreamGot(image_raw_bytes_for_test([0x01])),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(empty_resources, cmyk4),
    PdfRawImage(
      2,
      1,
      PdfBPP24,
      image_raw_bytes_for_test([255, 255, 255, 255, 0, 0]),
    ),
  )
  let cmyk1 = @syntax.pdf_stream(
    @syntax.pdf_dictionary([
      (image_raw_name_for_test("/Width"), PdfInteger(2)),
      (image_raw_name_for_test("/Height"), PdfInteger(1)),
      (image_raw_name_for_test("/ColorSpace"), indexed_cmyk),
      (image_raw_name_for_test("/BitsPerComponent"), PdfInteger(1)),
    ]),
    StreamGot(image_raw_bytes_for_test([0b0100_0000])),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(empty_resources, cmyk1),
    PdfRawImage(
      2,
      1,
      PdfBPP24,
      image_raw_bytes_for_test([255, 255, 255, 255, 0, 0]),
    ),
  )
  let indexed_cmyk4 : @syntax.PdfObject = PdfArray([
    PdfNameObject(image_raw_name_for_test("/Indexed")),
    PdfNameObject(image_raw_name_for_test("/DeviceCMYK")),
    PdfInteger(3),
    PdfString(
      image_raw_bytes_for_test([
        0, 0, 0, 0, 0, 255, 255, 0, 255, 0, 255, 0, 255, 255, 0, 0,
      ]),
    ),
  ])
  let cmyk2 = @syntax.pdf_stream(
    @syntax.pdf_dictionary([
      (image_raw_name_for_test("/Width"), PdfInteger(4)),
      (image_raw_name_for_test("/Height"), PdfInteger(1)),
      (image_raw_name_for_test("/ColorSpace"), indexed_cmyk4),
      (image_raw_name_for_test("/BitsPerComponent"), PdfInteger(2)),
    ]),
    StreamGot(image_raw_bytes_for_test([0b0001_1011])),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(empty_resources, cmyk2),
    PdfRawImage(
      4,
      1,
      PdfBPP24,
      image_raw_bytes_for_test([255, 255, 255, 255, 0, 0, 0, 255, 0, 0, 0, 255]),
    ),
  )
  let cmyk8 = @syntax.pdf_stream(
    @syntax.pdf_dictionary([
      (image_raw_name_for_test("/Width"), PdfInteger(2)),
      (image_raw_name_for_test("/Height"), PdfInteger(1)),
      (image_raw_name_for_test("/ColorSpace"), indexed_cmyk),
      (image_raw_name_for_test("/BitsPerComponent"), PdfInteger(8)),
    ]),
    StreamGot(image_raw_bytes_for_test([0, 1])),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(empty_resources, cmyk8),
    PdfRawImage(
      2,
      1,
      PdfBPP24,
      image_raw_bytes_for_test([255, 255, 255, 255, 0, 0]),
    ),
  )
  let rgb4 = @syntax.pdf_stream(
    @syntax.pdf_dictionary([
      (image_raw_name_for_test("/Width"), PdfInteger(2)),
      (image_raw_name_for_test("/Height"), PdfInteger(1)),
      (image_raw_name_for_test("/ColorSpace"), indexed_rgb),
      (image_raw_name_for_test("/BitsPerComponent"), PdfInteger(4)),
    ]),
    StreamGot(image_raw_bytes_for_test([0x01])),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(empty_resources, rgb4),
    PdfRawImage(
      2,
      1,
      PdfBPP24,
      image_raw_bytes_for_test([10, 20, 30, 40, 50, 60]),
    ),
  )
  let icc_rgb_base = @syntax.pdf_stream(
    @syntax.pdf_dictionary([(image_raw_name_for_test("/N"), PdfInteger(3))]),
    StreamGot(@ascii.encode("icc")),
  )
  let indexed_icc_rgb : @syntax.PdfObject = PdfArray([
    PdfNameObject(image_raw_name_for_test("/Indexed")),
    PdfArray([PdfNameObject(image_raw_name_for_test("/ICCBased")), icc_rgb_base]),
    PdfInteger(1),
    PdfString(image_raw_bytes_for_test([1, 2, 3, 4, 5, 6])),
  ])
  let icc_rgb4 = @syntax.pdf_stream(
    @syntax.pdf_dictionary([
      (image_raw_name_for_test("/Width"), PdfInteger(2)),
      (image_raw_name_for_test("/Height"), PdfInteger(1)),
      (image_raw_name_for_test("/ColorSpace"), indexed_icc_rgb),
      (image_raw_name_for_test("/BitsPerComponent"), PdfInteger(4)),
    ]),
    StreamGot(image_raw_bytes_for_test([0x01])),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(empty_resources, icc_rgb4),
    PdfRawImage(2, 1, PdfBPP24, image_raw_bytes_for_test([1, 2, 3, 4, 5, 6])),
  )
  let device_n_cmyk_base : @syntax.PdfObject = PdfArray([
    PdfNameObject(image_raw_name_for_test("/DeviceN")),
    PdfArray([PdfNameObject(image_raw_name_for_test("/Spot"))]),
    PdfNameObject(image_raw_name_for_test("/DeviceCMYK")),
    PdfNull,
  ])
  let indexed_device_n_cmyk : @syntax.PdfObject = PdfArray([
    PdfNameObject(image_raw_name_for_test("/Indexed")),
    device_n_cmyk_base,
    PdfInteger(1),
    PdfString(image_raw_bytes_for_test([0, 0, 0, 0, 0, 255, 255, 0])),
  ])
  let device_n_cmyk8 = @syntax.pdf_stream(
    @syntax.pdf_dictionary([
      (image_raw_name_for_test("/Width"), PdfInteger(2)),
      (image_raw_name_for_test("/Height"), PdfInteger(1)),
      (image_raw_name_for_test("/ColorSpace"), indexed_device_n_cmyk),
      (image_raw_name_for_test("/BitsPerComponent"), PdfInteger(8)),
    ]),
    StreamGot(image_raw_bytes_for_test([0, 1])),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(empty_resources, device_n_cmyk8),
    PdfRawImage(
      2,
      1,
      PdfBPP24,
      image_raw_bytes_for_test([255, 255, 255, 255, 0, 0]),
    ),
  )
  let missing_index = @syntax.pdf_stream(
    @syntax.pdf_dictionary([
      (image_raw_name_for_test("/Width"), PdfInteger(1)),
      (image_raw_name_for_test("/Height"), PdfInteger(1)),
      (image_raw_name_for_test("/ColorSpace"), indexed_rgb),
      (image_raw_name_for_test("/BitsPerComponent"), PdfInteger(8)),
    ]),
    StreamGot(image_raw_bytes_for_test([2])),
  )
  let missing_result : Result[@pdflite.PdfImage, Error] = try
    doc.get_image_24bpp(empty_resources, missing_index)
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard missing_result is Err(@core.PdfError::EndOfInput) else {
    fail("expected indexed table lookup failure")
  }
}

///|
test "PdfDocument get_image_24bpp converts Lab indexed image tables" {
  let doc = @pdflite.pdf_document_empty()
  let lab_space : @syntax.PdfObject = PdfArray([
    PdfNameObject(image_raw_name_for_test("/Lab")),
    @syntax.pdf_dictionary([
      (
        image_raw_name_for_test("/WhitePoint"),
        PdfArray([PdfInteger(1000), PdfInteger(1000), PdfInteger(1000)]),
      ),
    ]),
  ])
  let indexed_lab : @syntax.PdfObject = PdfArray([
    PdfNameObject(image_raw_name_for_test("/Indexed")),
    lab_space,
    PdfInteger(3),
    PdfString(
      image_raw_bytes_for_test([
        127, 127, 127, 255, 127, 127, 255, 255, 255, 255, 0, 0,
      ]),
    ),
  ])
  let image8 = @syntax.pdf_stream(
    @syntax.pdf_dictionary([
      (image_raw_name_for_test("/Width"), PdfInteger(4)),
      (image_raw_name_for_test("/Height"), PdfInteger(1)),
      (image_raw_name_for_test("/ColorSpace"), indexed_lab),
      (image_raw_name_for_test("/BitsPerComponent"), PdfInteger(8)),
    ]),
    StreamGot(image_raw_bytes_for_test([0, 1, 2, 3])),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(@syntax.pdf_dictionary([]), image8),
    PdfRawImage(
      4,
      1,
      PdfBPP24,
      image_raw_bytes_for_test([
        0, 0, 0, 141, 141, 141, 255, 104, 47, 25, 178, 235,
      ]),
    ),
  )
  let image4 = @syntax.pdf_stream(
    @syntax.pdf_dictionary([
      (image_raw_name_for_test("/Width"), PdfInteger(4)),
      (image_raw_name_for_test("/Height"), PdfInteger(1)),
      (image_raw_name_for_test("/ColorSpace"), indexed_lab),
      (image_raw_name_for_test("/BitsPerComponent"), PdfInteger(4)),
    ]),
    StreamGot(image_raw_bytes_for_test([0x12, 0x30])),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(@syntax.pdf_dictionary([]), image4),
    PdfRawImage(
      4,
      1,
      PdfBPP24,
      image_raw_bytes_for_test([
        141, 141, 141, 255, 104, 47, 25, 178, 235, 0, 0, 0,
      ]),
    ),
  )
  let image2 = @syntax.pdf_stream(
    @syntax.pdf_dictionary([
      (image_raw_name_for_test("/Width"), PdfInteger(5)),
      (image_raw_name_for_test("/Height"), PdfInteger(1)),
      (image_raw_name_for_test("/ColorSpace"), indexed_lab),
      (image_raw_name_for_test("/BitsPerComponent"), PdfInteger(2)),
    ]),
    StreamGot(image_raw_bytes_for_test([0b0001_1011, 0b0100_0000])),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(@syntax.pdf_dictionary([]), image2),
    PdfRawImage(
      5,
      1,
      PdfBPP24,
      image_raw_bytes_for_test([
        0, 0, 0, 141, 141, 141, 255, 104, 47, 25, 178, 235, 141, 141, 141,
      ]),
    ),
  )
  let image1 = @syntax.pdf_stream(
    @syntax.pdf_dictionary([
      (image_raw_name_for_test("/Width"), PdfInteger(2)),
      (image_raw_name_for_test("/Height"), PdfInteger(1)),
      (image_raw_name_for_test("/ColorSpace"), indexed_lab),
      (image_raw_name_for_test("/BitsPerComponent"), PdfInteger(1)),
    ]),
    StreamGot(image_raw_bytes_for_test([0b0100_0000])),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(@syntax.pdf_dictionary([]), image1),
    PdfRawImage(
      2,
      1,
      PdfBPP24,
      image_raw_bytes_for_test([0, 0, 0, 141, 141, 141]),
    ),
  )
}

///|
test "PdfDocument get_image_24bpp reports malformed raw images" {
  let doc = @pdflite.pdf_document_empty()
  let short_rgb = @syntax.pdf_stream(
    @syntax.pdf_dictionary([
      (image_raw_name_for_test("/Width"), PdfInteger(2)),
      (image_raw_name_for_test("/Height"), PdfInteger(1)),
      (
        image_raw_name_for_test("/ColorSpace"),
        PdfNameObject(image_raw_name_for_test("/DeviceRGB")),
      ),
      (image_raw_name_for_test("/BitsPerComponent"), PdfInteger(8)),
    ]),
    StreamGot(image_raw_bytes_for_test([1, 2, 3])),
  )
  let result : Result[@pdflite.PdfImage, Error] = try
    doc.get_image_24bpp(@syntax.pdf_dictionary([]), short_rgb)
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard result is Err(@core.PdfError::EndOfInput) else {
    fail("expected @core.PdfError::EndOfInput for short raw image")
  }
}
