///|
/// A JPEG's markers up to its frame header: JFIF when `jfif`, an Adobe
/// marker when `adobe`, and a frame (baseline, or of marker `frame`) of
/// `components` samples a pixel of `precision` bits.
fn image_jpeg_of_components_for_test(
  components : Int,
  adobe : Bool,
  precision? : Int = 8,
  frame? : Int = 0xC0,
  jfif? : Bool = true,
) -> @core.PdfBytes {
  let bytes : Array[Int] = [0xFF, 0xD8]
  if jfif {
    bytes.append([
      0xFF, 0xE0, 0x00, 0x09, 0x4A, 0x46, 0x49, 0x46, 0x00, 0xAA, 0xBB,
    ])
  }
  if adobe {
    // APP14: "Adobe", version, flags, colour transform
    bytes.append([
      0xFF, 0xEE, 0x00, 0x0E, 0x41, 0x64, 0x6F, 0x62, 0x65, 0x00, 0x64, 0x00, 0x00,
      0x00, 0x00, 0x00,
    ])
  }
  // the frame header: length, precision, height 300, width 400, the
  // components
  bytes.append([
    0xFF,
    frame,
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

///|
test "pdf_image_object_of_jpeg_data takes every JPEG DCTDecode decodes" {
  let taken = (jpeg : @core.PdfBytes) => {
    try @pdflite.pdf_image_object_of_jpeg_data(jpeg) catch {
      InvalidJPEGBlock => false
      err => raise err
    } noraise {
      _ => true
    }
  }
  // baseline, extended sequential and progressive frames
  for frame in [0xC0, 0xC1, 0xC2] {
    @test.assert_eq(
      taken(image_jpeg_of_components_for_test(3, false, frame~)),
      true,
    )
  }
  // not lossless, differential or arithmetic-coded ones
  for frame in [0xC3, 0xC5, 0xC9, 0xCA] {
    @test.assert_eq(
      taken(image_jpeg_of_components_for_test(3, false, frame~)),
      false,
    )
  }
  // whatever it starts with: Adobe's CMYK often has no JFIF header
  let cmyk = image_jpeg_of_components_for_test(4, true, jfif=false)
  @test.assert_eq(taken(cmyk), true)
  guard image_jpeg_colour_for_test(cmyk) is (_, Some(_)) else {
    fail("expected Adobe's CMYK, without a JFIF header, to get a /Decode")
  }
}

///|
test "pdf_jpeg_info_view reads the frame and the Adobe marker" {
  let info = @codec.pdf_jpeg_info_view(
    image_jpeg_of_components_for_test(4, true, frame=0xC2, jfif=false),
  )
  @test.assert_eq(
    (info.width, info.height, info.bits, info.components, info.frame),
    (400, 300, 8, 4, 0xC2),
  )
  // (the transform of the test's marker is 0: CMYK as stored)
  @test.assert_eq(info.adobe_transform, Some(0))
  let plain = @codec.pdf_jpeg_info_view(
    image_jpeg_of_components_for_test(1, false),
  )
  @test.assert_eq((plain.components, plain.frame), (1, 0xC0))
  @test.assert_eq(plain.adobe_transform, None)
  // not a JPEG; a JPEG that ends before its frame
  let failure = (data : @core.PdfBytes) => {
    try @codec.pdf_jpeg_info_view(data) catch {
      BadJPEGHeader => "BadJPEGHeader"
      JPEGDimensionsExpected => "JPEGDimensionsExpected"
      _ => "another error"
    } noraise {
      _ => "none"
    }
  }
  @test.assert_eq(failure(image_bytes_for_test([0x89, 0x50])), "BadJPEGHeader")
  @test.assert_eq(
    failure(image_bytes_for_test([0xFF, 0xD8, 0xFF, 0xDB])),
    "JPEGDimensionsExpected",
  )
  @test.assert_eq(
    failure(image_bytes_for_test([0xFF, 0xD8, 0xFF, 0xD9])),
    "JPEGDimensionsExpected",
  )
}

///|
test "pdf_image_object_of_jpeg_data refuses a hierarchical JPEG" {
  // a DHP marker before the frames: the first frame, baseline as it may be,
  // is one of several sizes and not the image
  let plain = image_jpeg_of_components_for_test(3, false, jfif=false)
  let bytes : Array[Byte] = [..plain[:2]]
  for
    value in [
      0xFF, 0xDE, 0x00, 0x0B, 0x08, 0x01, 0x2C, 0x01, 0x90, 0x01, 0x01, 0x11, 0x00,
    ] {
    bytes.push(value.to_byte())
  }
  bytes.append(plain[2:].to_array())
  let jpeg = Bytes::from_array(bytes)
  @test.assert_eq(@codec.pdf_jpeg_info_view(jpeg).hierarchical, true)
  @test.assert_eq(@codec.pdf_jpeg_info_view(plain).hierarchical, false)
  let result : Result[@syntax.PdfObject, Error] = try
    @pdflite.pdf_image_object_of_jpeg_data(jpeg)
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
test "pdf_image_document_of_jpeg_data is of PDF 1.3 for a progressive JPEG" {
  let progressive = @pdflite.pdf_image_document_of_jpeg_data(
    image_jpeg_of_components_for_test(3, false, frame=0xC2),
  )
  @test.assert_eq(progressive.version(), (1, 3))
  // a baseline one is of the version it was
  let baseline = @pdflite.pdf_image_document_of_jpeg_data(
    image_jpeg_of_components_for_test(3, false),
  )
  let plain = @pdflite.pdf_image_document_of_jpeg_data(
    image_jpeg_for_document_test(),
  )
  @test.assert_eq(baseline.version(), plain.version())
  @test.assert_eq(baseline.version().1 < 3, true)
}

///|
test "pdf_image_object_of_jpeg_data has components named R, G and B untransformed" {
  let transform = (jpeg : @core.PdfBytes) => {
    guard @pdflite.pdf_image_object_of_jpeg_data(jpeg)
      is PdfStreamObject(stream) else {
      fail("expected a JPEG stream object")
    }
    match
      stream.dictionary.lookup_immediate(image_name_for_test("/DecodeParms")) {
      Some(parms) => Some(image_lookup_for_test(parms, "/ColorTransform"))
      None => None
    }
  }
  // the frame's component identifiers follow its count: R, G, B for 1, 2, 3
  let named = (jpeg : @core.PdfBytes, at : Int) => {
    let bytes = jpeg.to_array()
    bytes[at] = b'R'
    bytes[at + 3] = b'G'
    bytes[at + 6] = b'B'
    Bytes::from_array(bytes)
  }
  // with no JFIF or Adobe marker they are RGB as they are
  let bare = image_jpeg_of_components_for_test(3, false, jfif=false)
  @test.assert_eq(@codec.pdf_jpeg_info_view(bare).component_ids, [1, 2, 3])
  @test.assert_eq(transform(bare), None)
  let rgb = named(bare, 12)
  @test.assert_eq(@codec.pdf_jpeg_info_view(rgb).component_ids, [
    0x52, 0x47, 0x42,
  ])
  @test.assert_eq(transform(rgb), Some(PdfInteger(0)))
  // JFIF's are YCbCr whatever they are named, and Adobe's marker says its own
  let jfif = named(image_jpeg_of_components_for_test(3, false), 23)
  @test.assert_eq(@codec.pdf_jpeg_info_view(jfif).jfif, true)
  @test.assert_eq(@codec.pdf_jpeg_info_view(jfif).component_ids, [
    0x52, 0x47, 0x42,
  ])
  @test.assert_eq(transform(jfif), None)
  let adobe = named(image_jpeg_of_components_for_test(3, true, jfif=false), 28)
  @test.assert_eq(@codec.pdf_jpeg_info_view(adobe).component_ids, [
    0x52, 0x47, 0x42,
  ])
  @test.assert_eq(transform(adobe), None)
}
