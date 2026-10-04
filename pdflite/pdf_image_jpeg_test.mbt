///|
/// A JPEG's markers up to its frame header: JFIF, an Adobe marker when
/// `adobe`, and a baseline frame of `components` samples a pixel.
fn image_jpeg_of_components_for_test(
  components : Int,
  adobe : Bool,
  precision? : Int = 8,
) -> @core.PdfBytes {
  let bytes : Array[Int] = [
    0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x09, 0x4A, 0x46, 0x49, 0x46, 0x00, 0xAA, 0xBB,
  ]
  if adobe {
    // APP14: "Adobe", version, flags, colour transform
    bytes.append([
      0xFF, 0xEE, 0x00, 0x0E, 0x41, 0x64, 0x6F, 0x62, 0x65, 0x00, 0x64, 0x00, 0x00,
      0x00, 0x00, 0x00,
    ])
  }
  // SOF0: length, precision 8, height 300, width 400, the components
  bytes.append([
    0xFF,
    0xC0,
    0x00,
    8 + 3 * components,
    precision,
    0x01,
    0x2C,
    0x01,
    0x90,
    components,
  ])
  for k in 0..<components {
    bytes.append([k + 1, 0x11, 0x00])
  }
  bytes.append([0xFF, 0xD9])
  image_bytes_for_test(bytes)
}

///|
/// The /ColorSpace and /Decode of the image a JPEG becomes.
fn image_jpeg_colour_for_test(
  jpeg : @core.PdfBytes,
) -> (@syntax.PdfObject, @syntax.PdfObject?) raise {
  guard @pdflite.pdf_image_object_of_jpeg_data(jpeg) is PdfStreamObject(stream) else {
    fail("expected a JPEG stream object")
  }
  (
    image_lookup_for_test(stream.dictionary, "/ColorSpace"),
    stream.dictionary.lookup_immediate(image_name_for_test("/Decode")),
  )
}

///|
test "pdf_image_object_of_jpeg_data takes its colour space from the frame" {
  let name = (text : String) => {
    let object : @syntax.PdfObject = PdfNameObject(image_name_for_test(text))
    object
  }
  @test.assert_eq(
    image_jpeg_colour_for_test(image_jpeg_of_components_for_test(1, false)),
    (name("/DeviceGray"), None),
  )
  @test.assert_eq(
    image_jpeg_colour_for_test(image_jpeg_of_components_for_test(3, false)),
    (name("/DeviceRGB"), None),
  )
  // an Adobe marker changes nothing for colour
  @test.assert_eq(
    image_jpeg_colour_for_test(image_jpeg_of_components_for_test(3, true)),
    (name("/DeviceRGB"), None),
  )
  // CMYK as it is, and Adobe's, inverted, put right by its /Decode
  @test.assert_eq(
    image_jpeg_colour_for_test(image_jpeg_of_components_for_test(4, false)),
    (name("/DeviceCMYK"), None),
  )
  let one : @syntax.PdfObject = PdfInteger(1)
  let zero : @syntax.PdfObject = PdfInteger(0)
  @test.assert_eq(
    image_jpeg_colour_for_test(image_jpeg_of_components_for_test(4, true)),
    (
      name("/DeviceCMYK"),
      Some(PdfArray([one, zero, one, zero, one, zero, one, zero])),
    ),
  )
}

///|
test "pdf_image_object_of_jpeg_data takes only a whole Adobe marker as Adobe's" {
  // an APP14 of just the name (no version, flags or transform) is not one
  // libjpeg takes as Adobe's, and its CMYK is not inverted
  let jpeg = image_bytes_for_test([
    0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x09, 0x4A, 0x46, 0x49, 0x46, 0x00, 0xAA, 0xBB,
    0xFF, 0xEE, 0x00, 0x07, 0x41, 0x64, 0x6F, 0x62, 0x65, 0xFF, 0xC0, 0x00, 0x14,
    0x08, 0x01, 0x2C, 0x01, 0x90, 0x04, 0x01, 0x11, 0x00, 0x02, 0x11, 0x00, 0x03,
    0x11, 0x00, 0x04, 0x11, 0x00, 0xFF, 0xD9,
  ])
  let (space, decode) = image_jpeg_colour_for_test(jpeg)
  @test.assert_eq(space, PdfNameObject(image_name_for_test("/DeviceCMYK")))
  @test.assert_eq(decode, None)
}

///|
test "pdf_image_object_of_jpeg_data refuses samples not of 8 bits" {
  let result : Result[@syntax.PdfObject, Error] = try
    @pdflite.pdf_image_object_of_jpeg_data(
      image_jpeg_of_components_for_test(3, false, precision=12),
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard result is Err(@core.PdfError::InvalidJPEGBlock) else {
    fail("expected InvalidJPEGBlock")
  }
}

///|
test "pdf_image_object_of_jpeg_data refuses a frame of two samples a pixel" {
  let result : Result[@syntax.PdfObject, Error] = try
    @pdflite.pdf_image_object_of_jpeg_data(
      image_jpeg_of_components_for_test(2, false),
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard result is Err(@core.PdfError::InvalidJPEGBlock) else {
    fail("expected InvalidJPEGBlock")
  }
}
