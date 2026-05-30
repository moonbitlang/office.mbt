///|
fn image_name_for_test(text : String) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn image_bytes_for_test(values : ArrayView[Int]) -> @pdflite.PdfBytes {
  try! @pdflite.pdf_bytes_of_int_array(values)
}

///|
fn image_json_int_for_test(value : Int) -> Json {
  Json::number(value.to_double(), repr=value.to_string())
}

///|
fn image_json_int_or_null_for_test(value : Int?) -> Json {
  match value {
    Some(value) => image_json_int_for_test(value)
    None => Json::null()
  }
}

///|
fn image_json_string_or_null_for_test(value : String?) -> Json {
  match value {
    Some(value) => Json::string(value)
    None => Json::null()
  }
}

///|
fn image_json_entry_for_test(
  object_number : Int,
  pages : ArrayView[Int],
  name : String,
  width : Int,
  height : Int,
  byte_count : Int,
  bits_per_component : Int?,
  colourspace : String?,
  filter : String?,
  mask : String,
  mask_object_number : Int?,
) -> Json {
  Json::object(
    Map([
      ("Object", image_json_int_for_test(object_number)),
      (
        "Pages",
        Json::array(
          [
            for page_number in pages => image_json_int_for_test(page_number)
          ],
        ),
      ),
      ("Name", Json::string(name)),
      ("Width", image_json_int_for_test(width)),
      ("Height", image_json_int_for_test(height)),
      ("Bytes", image_json_int_for_test(byte_count)),
      ("BitsPerComponent", image_json_int_or_null_for_test(bits_per_component)),
      ("Colourspace", image_json_string_or_null_for_test(colourspace)),
      ("Filter", image_json_string_or_null_for_test(filter)),
      ("Mask", Json::string(mask)),
      ("MaskObjNum", image_json_int_or_null_for_test(mask_object_number)),
    ]),
  )
}

///|
fn image_resolution_json_entry_for_test(
  object_number : Int,
  page_number : Int,
  xobject : String,
  width : Int,
  height : Int,
  xdpi : Double,
  ydpi : Double,
) -> Json {
  Json::object(
    Map([
      ("Object", image_json_int_for_test(object_number)),
      ("Page", image_json_int_for_test(page_number)),
      ("XObject", Json::string(xobject)),
      ("W", image_json_int_for_test(width)),
      ("H", image_json_int_for_test(height)),
      ("Xdpi", Json::number(xdpi)),
      ("Ydpi", Json::number(ydpi)),
    ]),
  )
}

///|
fn image_lookup_for_test(
  object : @syntax.PdfObject,
  key : String,
) -> @syntax.PdfObject raise {
  match object.lookup_immediate(image_name_for_test(key)) {
    Some(value) => value
    None => {
      fail("missing dictionary key " + key)
      PdfNull
    }
  }
}

///|
fn image_lookup_indirect_object_for_test(
  document : @pdflite.PdfDocument,
  object : @syntax.PdfObject,
  key : String,
) -> (Int, @syntax.PdfObject) raise {
  let reference = try! image_lookup_for_test(object, key)
  guard reference is PdfIndirect(number) else {
    fail("expected dictionary key " + key + " to be indirect")
    (0, PdfNull)
  }
  (number, document.lookup_object_or_null(number))
}

///|
fn image_jpeg_for_document_test() -> @pdflite.PdfBytes {
  image_bytes_for_test([
    0xFF, 0xD8, 0xFF, 0xE0,
    // APP0 length = 9, followed by "JFIF\0" and padding.
     0x00, 0x09, 0x4A, 0x46, 0x49, 0x46, 0x00, 0xAA, 0xBB,
    // SOF0 marker, length, precision, height 300, width 400.
     0xFF, 0xC0, 0x00, 0x0B, 0x08, 0x01, 0x2C, 0x01, 0x90, 0x03, 0x01, 0xFF, 0xD9,
  ])
}

///|
fn image_jpeg2000_for_document_test() -> @pdflite.PdfBytes {
  image_bytes_for_test([
    0x00, 0x00, 0x00, 0x0C, 0x6A, 0x50, 0x20, 0x20, 0x0D, 0x0A, 0x87, 0x0A,
    // ihdr, height 300, width 400
     0x69, 0x68, 0x64, 0x72, 0x00, 0x00, 0x01, 0x2C, 0x00, 0x00, 0x01, 0x90,
  ])
}

///|
fn image_jbig2_for_document_test() -> @pdflite.PdfBytes {
  image_bytes_for_test([
    0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A,
    // Width 640, height 480 at the cpdf JBIG2 dimension offsets.
     0x00, 0x00, 0x02, 0x80, 0x00, 0x00, 0x01, 0xE0, 0xAA,
  ])
}

///|
fn image_push_byte_for_test(output : Array[Byte], value : Int) -> Unit {
  output.push(try! @pdflite.pdf_byte_of_int(value))
}

///|
fn image_push_u32_for_test(output : Array[Byte], value : Int) -> Unit {
  image_push_byte_for_test(output, (value >> 24) & 0xFF)
  image_push_byte_for_test(output, (value >> 16) & 0xFF)
  image_push_byte_for_test(output, (value >> 8) & 0xFF)
  image_push_byte_for_test(output, value & 0xFF)
}

///|
fn image_append_bytes_for_test(output : Array[Byte], bytes : BytesView) -> Unit {
  for index in 0..<bytes.length() {
    output.push(bytes[index])
  }
}

///|
fn image_png_chunk_for_test(
  chunk_type : ArrayView[Int],
  data : BytesView,
) -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  image_push_u32_for_test(output, data.length())
  for value in chunk_type {
    image_push_byte_for_test(output, value)
  }
  image_append_bytes_for_test(output, data)
  image_push_u32_for_test(output, 0)
  Bytes::from_array(output)
}

///|
fn image_png_header_for_test(
  width : Int,
  height : Int,
  bit_depth : Int,
  color_type : Int,
  interlace : Int,
) -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  image_push_u32_for_test(output, width)
  image_push_u32_for_test(output, height)
  image_push_byte_for_test(output, bit_depth)
  image_push_byte_for_test(output, color_type)
  image_push_byte_for_test(output, 0)
  image_push_byte_for_test(output, 0)
  image_push_byte_for_test(output, interlace)
  Bytes::from_array(output)
}

///|
fn image_png_for_test(
  width : Int,
  height : Int,
  bit_depth : Int,
  color_type : Int,
  interlace : Int,
  idat_chunks : ArrayView[@pdflite.PdfBytes],
) -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  for value in [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A] {
    image_push_byte_for_test(output, value)
  }
  image_append_bytes_for_test(
    output,
    image_png_chunk_for_test(
      [0x49, 0x48, 0x44, 0x52],
      image_png_header_for_test(width, height, bit_depth, color_type, interlace),
    ),
  )
  for idat in idat_chunks {
    image_append_bytes_for_test(
      output,
      image_png_chunk_for_test([0x49, 0x44, 0x41, 0x54], idat),
    )
  }
  image_append_bytes_for_test(
    output,
    image_png_chunk_for_test([0x49, 0x45, 0x4E, 0x44], []),
  )
  Bytes::from_array(output)
}

///|
fn image_png_split_idat_for_test(
  idat : @pdflite.PdfBytes,
) -> Array[@pdflite.PdfBytes] {
  let split = idat.length() / 2
  [idat[:split].to_owned(), idat[split:].to_owned()]
}

///|
fn image_png_rgb_for_test() -> (@pdflite.PdfBytes, @pdflite.PdfBytes) {
  let raw = image_bytes_for_test([0, 10, 20, 30, 40, 50, 60])
  let idat = @flate.pdf_flate_encode(raw)
  (image_png_for_test(2, 1, 8, 2, 0, image_png_split_idat_for_test(idat)), idat)
}

///|
fn image_png_rgba_for_test() -> @pdflite.PdfBytes {
  let raw = image_bytes_for_test([0, 10, 20, 30, 40, 50, 60, 70, 80])
  image_png_for_test(
    2,
    1,
    8,
    6,
    0,
    image_png_split_idat_for_test(@flate.pdf_flate_encode(raw)),
  )
}

///|
fn image_bytes_start_with_at_for_test(
  haystack : BytesView,
  needle : BytesView,
  start : Int,
) -> Bool {
  if start < 0 || start + needle.length() > haystack.length() {
    false
  } else {
    for index in 0..<needle.length() {
      if haystack[start + index] != needle[index] {
        break false
      }
    } nobreak {
      true
    }
  }
}

///|
fn image_find_bytes_for_test(haystack : BytesView, needle : BytesView) -> Int {
  if needle.length() == 0 {
    0
  } else if haystack.length() < needle.length() {
    -1
  } else {
    let max_start = haystack.length() - needle.length()
    for start in 0..<=max_start {
      if image_bytes_start_with_at_for_test(haystack, needle, start) {
        break start
      }
    } nobreak {
      -1
    }
  }
}

///|
test "PdfDocument images_json lists image xobjects and soft masks" {
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(
    21,
    @syntax.pdf_stream(
      @syntax.pdf_dictionary([
        (
          image_name_for_test("/Subtype"),
          PdfNameObject(image_name_for_test("/Image")),
        ),
        (image_name_for_test("/Width"), PdfInteger(2)),
        (image_name_for_test("/Height"), PdfInteger(2)),
        (image_name_for_test("/ImageMask"), PdfBoolean(true)),
        (image_name_for_test("/Length"), PdfInteger(7)),
      ]),
      StreamGot(@ascii.encode("mask")),
    ),
  )
  doc.add_object_given_number(
    20,
    @syntax.pdf_stream(
      @syntax.pdf_dictionary([
        (
          image_name_for_test("/Subtype"),
          PdfNameObject(image_name_for_test("/Image")),
        ),
        (image_name_for_test("/Width"), PdfInteger(10)),
        (image_name_for_test("/Height"), PdfInteger(5)),
        (image_name_for_test("/BitsPerComponent"), PdfInteger(8)),
        (
          image_name_for_test("/ColorSpace"),
          PdfNameObject(image_name_for_test("/DeviceRGB")),
        ),
        (
          image_name_for_test("/Filter"),
          PdfNameObject(image_name_for_test("/DCTDecode")),
        ),
        (image_name_for_test("/Length"), PdfInteger(123)),
        (image_name_for_test("/SMask"), PdfIndirect(21)),
      ]),
      StreamGot(@ascii.encode("jpg")),
    ),
  )
  let page = {
    ..@page.pdf_page_blank(@geometry.paper_a4),
    resources: @syntax.pdf_dictionary([
      (
        image_name_for_test("/XObject"),
        @syntax.pdf_dictionary([(image_name_for_test("/Im1"), PdfIndirect(20))]),
      ),
    ]),
  }
  let page_root = try! doc.add_pagetree([page])
  ignore(try! doc.add_root(page_root, []))
  let expected = Json::array([
    image_json_entry_for_test(
      21,
      [1],
      "/SMask",
      2,
      2,
      7,
      Some(1),
      Some("/DeviceGray"),
      None,
      "ImageMask",
      None,
    ),
    image_json_entry_for_test(
      20,
      [1],
      "/Im1",
      10,
      5,
      123,
      Some(8),
      Some("/DeviceRGB"),
      Some("/DCTDecode"),
      "SMask",
      Some(21),
    ),
  ])
  @test.assert_eq(try! doc.images_json([1]), expected)
  @test.assert_eq(try! @pdflite.pdf_image_images(false, doc, [1]), expected)
  @test.assert_eq(try! @pdflite.pdf_images(false, doc, [1]), expected)
  @test.assert_eq(
    try! doc.images_json_blob([1]),
    @utf8.encode(expected.stringify()),
  )
  let bad_page : Result[Json, Error] = try? doc.images_json([2])
  guard bad_page is Err(@pdflite.PdfError::BadPageSpecification(_)) else {
    fail("expected images_json invalid page to raise BadPageSpecification")
  }
}

///|
test "PdfDocument images_json optionally includes form inline images" {
  let doc = @pdflite.pdf_document_empty()
  let inline_dict = @syntax.pdf_dictionary([
    (image_name_for_test("/W"), PdfInteger(3)),
    (image_name_for_test("/H"), PdfInteger(1)),
    (image_name_for_test("/BPC"), PdfInteger(8)),
    (
      image_name_for_test("/CS"),
      PdfNameObject(image_name_for_test("/DeviceRGB")),
    ),
  ])
  let form = (try! @pdflite.pdf_content_stream_of_ops([
      Op_InlineImage(inline_dict, None, @ascii.encode("abc")),
    ]))
    .add_dict_entry(
      image_name_for_test("/Subtype"),
      PdfNameObject(image_name_for_test("/Form")),
    )
    .add_dict_entry(
      image_name_for_test("/Resources"),
      @syntax.pdf_dictionary([]),
    )
  doc.add_object_given_number(30, form)
  let page = {
    ..@page.pdf_page_blank(@geometry.paper_a4),
    resources: @syntax.pdf_dictionary([
      (
        image_name_for_test("/XObject"),
        @syntax.pdf_dictionary([(image_name_for_test("/Fm1"), PdfIndirect(30))]),
      ),
    ]),
  }
  let page_root = try! doc.add_pagetree([page])
  ignore(try! doc.add_root(page_root, []))
  @test.assert_eq(try! doc.images_json([1]), Json::array([]))
  let with_inline = try! doc.images_json([1], inline=true)
  let expected = Json::array([
    image_json_entry_for_test(
      0,
      [1],
      "/InlineImage",
      3,
      1,
      3,
      Some(8),
      Some("/DeviceRGB"),
      None,
      "NoMask",
      None,
    ),
  ])
  @test.assert_eq(with_inline, expected)
  @test.assert_eq(
    try! @pdflite.pdf_image_images_json_blob(true, doc, [1]),
    @utf8.encode(expected.stringify()),
  )
}

///|
test "PdfDocument image_resolution reports selected image xobject DPI" {
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(
    20,
    @syntax.pdf_stream(
      @syntax.pdf_dictionary([
        (
          image_name_for_test("/Subtype"),
          PdfNameObject(image_name_for_test("/Image")),
        ),
        (image_name_for_test("/Width"), PdfInteger(400)),
        (image_name_for_test("/Height"), PdfInteger(300)),
        (image_name_for_test("/Length"), PdfInteger(0)),
      ]),
      StreamGot([]),
    ),
  )
  let placement = { ..@geometry.transform_identity_matrix, a: 400.0, d: 300.0 }
  let page = {
    ..@page.pdf_page_blank(@geometry.paper_a4),
    resources: @syntax.pdf_dictionary([
      (
        image_name_for_test("/XObject"),
        @syntax.pdf_dictionary([(image_name_for_test("/Im1"), PdfIndirect(20))]),
      ),
    ]),
    content: [
      try! @pdflite.pdf_content_stream_of_ops([
        Op_cm(placement),
        Op_Do(image_name_for_test("/Im1")),
      ]),
    ],
  }
  let page_root = try! doc.add_pagetree([page])
  ignore(try! doc.add_root(page_root, []))
  let expected = [(1, "/Im1", 400, 300, 72.0, 72.0, 20)]
  @test.assert_eq(try! doc.image_resolution([1], 100.0), expected)
  @test.assert_eq(
    try! @pdflite.pdf_image_resolution(false, doc, [1], 100.0),
    expected,
  )
  @test.assert_eq(try! doc.image_resolution([1], 50.0), [])
  let expected_json = Json::array([
    image_resolution_json_entry_for_test(20, 1, "/Im1", 400, 300, 72.0, 72.0),
  ])
  @test.assert_eq(try! doc.image_resolution_json([1], 100.0), expected_json)
  @test.assert_eq(
    try! @pdflite.pdf_image_resolution_json(false, doc, [1], 100.0),
    expected_json,
  )
  @test.assert_eq(
    try! doc.image_resolution_json_blob([1], 100.0),
    @utf8.encode(expected_json.stringify()),
  )
}

///|
test "PdfDocument image_resolution optionally includes inline images" {
  let doc = @pdflite.pdf_document_empty()
  let inline_dict = @syntax.pdf_dictionary([
    (image_name_for_test("/W"), PdfInteger(288)),
    (image_name_for_test("/H"), PdfInteger(72)),
    (image_name_for_test("/BPC"), PdfInteger(8)),
    (
      image_name_for_test("/CS"),
      PdfNameObject(image_name_for_test("/DeviceRGB")),
    ),
  ])
  let placement = { ..@geometry.transform_identity_matrix, a: 144.0, d: 72.0 }
  let page = {
    ..@page.pdf_page_blank(@geometry.paper_a4),
    content: [
      try! @pdflite.pdf_content_stream_of_ops([
        Op_cm(placement),
        Op_InlineImage(inline_dict, None, @ascii.encode("abc")),
      ]),
    ],
  }
  let page_root = try! doc.add_pagetree([page])
  ignore(try! doc.add_root(page_root, []))
  @test.assert_eq(try! doc.image_resolution([1], 100.0), [])
  let expected = [(1, "/InlineImage", 288, 72, 144.0, 72.0, 0)]
  @test.assert_eq(try! doc.image_resolution([1], 100.0, inline=true), expected)
  @test.assert_eq(
    try! @pdflite.pdf_image_resolution_json_blob(true, doc, [1], 100.0),
    @utf8.encode(
      Json::array([
        image_resolution_json_entry_for_test(
          0, 1, "/InlineImage", 288, 72, 144.0, 72.0,
        ),
      ]).stringify(),
    ),
  )
}

///|
test "PdfDocument image_resolution descends into form xobjects" {
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(
    22,
    @syntax.pdf_stream(
      @syntax.pdf_dictionary([
        (
          image_name_for_test("/Subtype"),
          PdfNameObject(image_name_for_test("/Image")),
        ),
        (image_name_for_test("/Width"), PdfInteger(72)),
        (image_name_for_test("/Height"), PdfInteger(72)),
        (image_name_for_test("/Length"), PdfInteger(0)),
      ]),
      StreamGot([]),
    ),
  )
  let form_scale = { ..@geometry.transform_identity_matrix, a: 72.0, d: 72.0 }
  let form = (try! @pdflite.pdf_content_stream_of_ops([
      Op_cm(form_scale),
      Op_Do(image_name_for_test("/Inner")),
    ]))
    .add_dict_entry(
      image_name_for_test("/Subtype"),
      PdfNameObject(image_name_for_test("/Form")),
    )
    .add_dict_entry(
      image_name_for_test("/Resources"),
      @syntax.pdf_dictionary([
        (
          image_name_for_test("/XObject"),
          @syntax.pdf_dictionary([
            (image_name_for_test("/Inner"), PdfIndirect(22)),
          ]),
        ),
      ]),
    )
  doc.add_object_given_number(30, form)
  let page_scale = { ..@geometry.transform_identity_matrix, a: 2.0, d: 2.0 }
  let page = {
    ..@page.pdf_page_blank(@geometry.paper_a4),
    resources: @syntax.pdf_dictionary([
      (
        image_name_for_test("/XObject"),
        @syntax.pdf_dictionary([(image_name_for_test("/Fm1"), PdfIndirect(30))]),
      ),
    ]),
    content: [
      try! @pdflite.pdf_content_stream_of_ops([
        Op_cm(page_scale),
        Op_Do(image_name_for_test("/Fm1")),
      ]),
    ],
  }
  let page_root = try! doc.add_pagetree([page])
  ignore(try! doc.add_root(page_root, []))
  @test.assert_eq(try! doc.image_resolution([1], 100.0), [
    (1, "/Inner", 72, 72, 36.0, 36.0, 22),
  ])
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
test "pdf_image_debug_image_processing stores cpdf debug flag" {
  let original = @pdflite.pdf_image_debug_image_processing()
  @pdflite.pdf_image_set_debug_image_processing(false)
  @test.assert_eq(@pdflite.pdf_image_debug_image_processing(), false)
  @test.assert_eq(@pdflite.pdf_debug_image_processing(), false)
  @pdflite.pdf_image_set_debug_image_processing(true)
  @test.assert_eq(@pdflite.pdf_image_debug_image_processing(), true)
  @test.assert_eq(@pdflite.pdf_debug_image_processing(), true)
  @pdflite.pdf_image_set_debug_image_processing(false)
  @test.assert_eq(@pdflite.pdf_image_debug_image_processing(), false)
  @pdflite.pdf_set_debug_image_processing(true)
  @test.assert_eq(@pdflite.pdf_image_debug_image_processing(), true)
  @test.assert_eq(@pdflite.pdf_debug_image_processing(), true)
  @pdflite.pdf_set_debug_image_processing(false)
  @test.assert_eq(@pdflite.pdf_image_debug_image_processing(), false)
  @pdflite.pdf_image_set_debug_image_processing(original)
}

///|
test "pdf_image_object_of_jpeg_data builds DCT image XObject" {
  let jpeg = image_jpeg_for_document_test()
  let object = try! @pdflite.pdf_image_object_of_jpeg_data(jpeg)
  guard object is PdfStreamObject(stream) else {
    fail("expected JPEG stream object")
  }
  @test.assert_eq(
    try! image_lookup_for_test(stream.dictionary, "/Length"),
    PdfInteger(jpeg.length()),
  )
  @test.assert_eq(
    try! image_lookup_for_test(stream.dictionary, "/Filter"),
    PdfNameObject(image_name_for_test("/DCTDecode")),
  )
  @test.assert_eq(
    try! image_lookup_for_test(stream.dictionary, "/BitsPerComponent"),
    PdfInteger(8),
  )
  @test.assert_eq(
    try! image_lookup_for_test(stream.dictionary, "/ColorSpace"),
    PdfNameObject(image_name_for_test("/DeviceRGB")),
  )
  @test.assert_eq(
    try! image_lookup_for_test(stream.dictionary, "/Subtype"),
    PdfNameObject(image_name_for_test("/Image")),
  )
  @test.assert_eq(
    try! image_lookup_for_test(stream.dictionary, "/Width"),
    PdfInteger(400),
  )
  @test.assert_eq(
    try! image_lookup_for_test(stream.dictionary, "/Height"),
    PdfInteger(300),
  )
  @test.assert_eq(stream.data, StreamGot(jpeg))
}

///|
test "pdf_image_obj_of_jpeg_data returns cpdf tuple shape" {
  let jpeg = image_jpeg_for_document_test()
  let (object, extra) = try! @pdflite.pdf_image_obj_of_jpeg_data(
    jpeg,
    path_to_im="/usr/bin/convert",
  )
  @test.assert_eq(extra.length(), 0)
  @test.assert_eq(object, try! @pdflite.pdf_image_object_of_jpeg_data(jpeg))
  @test.assert_eq(
    try! @pdflite.pdf_obj_of_jpeg_data(jpeg, path_to_im="/usr/bin/convert"),
    (object, extra),
  )
}

///|
test "pdf_image_object_of_jpeg2000_data builds JPX image XObject" {
  let jpeg2000 = image_jpeg2000_for_document_test()
  let object = try! @pdflite.pdf_image_object_of_jpeg2000_data(jpeg2000)
  guard object is PdfStreamObject(stream) else {
    fail("expected JPEG2000 stream object")
  }
  @test.assert_eq(
    try! image_lookup_for_test(stream.dictionary, "/Length"),
    PdfInteger(jpeg2000.length()),
  )
  @test.assert_eq(
    try! image_lookup_for_test(stream.dictionary, "/Filter"),
    PdfNameObject(image_name_for_test("/JPXDecode")),
  )
  @test.assert_eq(
    try! image_lookup_for_test(stream.dictionary, "/Subtype"),
    PdfNameObject(image_name_for_test("/Image")),
  )
  @test.assert_eq(
    try! image_lookup_for_test(stream.dictionary, "/Width"),
    PdfInteger(400),
  )
  @test.assert_eq(
    try! image_lookup_for_test(stream.dictionary, "/Height"),
    PdfInteger(300),
  )
  @test.assert_eq(
    stream.dictionary.lookup_immediate(image_name_for_test("/ColorSpace")),
    None,
  )
  @test.assert_eq(stream.data, StreamGot(jpeg2000))
}

///|
test "pdf_image_obj_of_jpeg2000_data returns cpdf tuple shape" {
  let jpeg2000 = image_jpeg2000_for_document_test()
  let (object, extra) = try! @pdflite.pdf_image_obj_of_jpeg2000_data(jpeg2000)
  @test.assert_eq(extra.length(), 0)
  @test.assert_eq(
    object,
    try! @pdflite.pdf_image_object_of_jpeg2000_data(jpeg2000),
  )
  @test.assert_eq(
    try! @pdflite.pdf_obj_of_jpeg2000_data(jpeg2000),
    (object, extra),
  )
}

///|
test "pdf_read_png reads IHDR and concatenated IDAT chunks" {
  let (png_bytes, idat) = image_png_rgb_for_test()
  let png = try! @pdflite.pdf_read_png(png_bytes)
  @test.assert_eq(png.width, 2)
  @test.assert_eq(png.height, 1)
  @test.assert_eq(png.bit_depth, 8)
  @test.assert_eq(png.color_type, 2)
  @test.assert_eq(png.idat, idat)
  @test.assert_eq(
    try! @flate.pdf_flate_decode(png.idat),
    image_bytes_for_test([0, 10, 20, 30, 40, 50, 60]),
  )
}

///|
test "pdf_read_png rejects unsupported palette and interlaced inputs" {
  let palette : Result[@pdflite.PdfPNG, Error] = try? @pdflite.pdf_read_png(
    image_png_for_test(1, 1, 8, 3, 0, []),
  )
  guard palette is Err(@pdflite.PdfError::BadPNG(_)) else {
    fail("expected palette PNG to raise BadPNG")
  }
  let interlaced : Result[@pdflite.PdfPNG, Error] = try? @pdflite.pdf_read_png(
    image_png_for_test(1, 1, 8, 2, 1, []),
  )
  guard interlaced is Err(@pdflite.PdfError::BadPNG(_)) else {
    fail("expected interlaced PNG to raise BadPNG")
  }
}

///|
test "pdf_image_object_of_png_data builds RGB Flate image XObject" {
  let (png_bytes, idat) = image_png_rgb_for_test()
  let document = @pdflite.pdf_document_empty()
  let object = try! @pdflite.pdf_image_object_of_png_data(document, png_bytes)
  guard object is PdfStreamObject(stream) else {
    fail("expected PNG stream object")
  }
  @test.assert_eq(
    try! image_lookup_for_test(stream.dictionary, "/Length"),
    PdfInteger(idat.length()),
  )
  @test.assert_eq(
    try! image_lookup_for_test(stream.dictionary, "/Filter"),
    PdfNameObject(image_name_for_test("/FlateDecode")),
  )
  @test.assert_eq(
    try! image_lookup_for_test(stream.dictionary, "/ColorSpace"),
    PdfNameObject(image_name_for_test("/DeviceRGB")),
  )
  @test.assert_eq(
    try! image_lookup_for_test(stream.dictionary, "/Subtype"),
    PdfNameObject(image_name_for_test("/Image")),
  )
  @test.assert_eq(
    try! image_lookup_for_test(stream.dictionary, "/Width"),
    PdfInteger(2),
  )
  @test.assert_eq(
    try! image_lookup_for_test(stream.dictionary, "/Height"),
    PdfInteger(1),
  )
  let decodeparms = try! image_lookup_for_test(
    stream.dictionary,
    "/DecodeParms",
  )
  @test.assert_eq(
    try! image_lookup_for_test(decodeparms, "/Predictor"),
    PdfInteger(15),
  )
  @test.assert_eq(
    try! image_lookup_for_test(decodeparms, "/Colors"),
    PdfInteger(3),
  )
  @test.assert_eq(
    try! image_lookup_for_test(decodeparms, "/BitsPerComponent"),
    PdfInteger(8),
  )
  @test.assert_eq(
    try! image_lookup_for_test(decodeparms, "/Columns"),
    PdfInteger(2),
  )
  @test.assert_eq(stream.data, StreamGot(idat))
}

///|
test "pdf_image_obj_of_png_data returns cpdf tuple shape" {
  let document = @pdflite.pdf_document_empty()
  let (object, extra) = try! @pdflite.pdf_image_obj_of_png_data(
    document,
    image_png_rgba_for_test(),
  )
  @test.assert_eq(extra.length(), 0)
  guard object is PdfStreamObject(stream) else {
    fail("expected PNG stream object")
  }
  let smask_reference = try! image_lookup_for_test(stream.dictionary, "/SMask")
  guard smask_reference is PdfIndirect(smask_number) else {
    fail("expected alpha SMask reference")
  }
  guard document.lookup_object_or_null(smask_number) is PdfStreamObject(_) else {
    fail("expected PNG wrapper to add alpha mask to document")
  }
  let source_document = @pdflite.pdf_document_empty()
  let source_tuple = try! @pdflite.pdf_obj_of_png_data(
    source_document,
    image_png_rgba_for_test(),
  )
  @test.assert_eq(source_tuple.1.length(), 0)
  guard source_tuple.0 is PdfStreamObject(source_stream) else {
    fail("expected PNG stream object through source-spelled alias")
  }
  let source_smask = try! image_lookup_for_test(
    source_stream.dictionary,
    "/SMask",
  )
  guard source_smask is PdfIndirect(source_smask_number) else {
    fail("expected alias alpha SMask reference")
  }
  guard source_document.lookup_object_or_null(source_smask_number)
    is PdfStreamObject(_) else {
    fail("expected alias PNG wrapper to add alpha mask to document")
  }
}

///|
test "pdf_image_object_of_png_data splits alpha into SMask" {
  let document = @pdflite.pdf_document_empty()
  let object = try! @pdflite.pdf_image_object_of_png_data(
    document,
    image_png_rgba_for_test(),
  )
  guard object is PdfStreamObject(stream) else {
    fail("expected PNG stream object")
  }
  @test.assert_eq(
    stream.dictionary.lookup_immediate(image_name_for_test("/DecodeParms")),
    None,
  )
  @test.assert_eq(
    try! image_lookup_for_test(stream.dictionary, "/ColorSpace"),
    PdfNameObject(image_name_for_test("/DeviceRGB")),
  )
  let smask_reference = try! image_lookup_for_test(stream.dictionary, "/SMask")
  guard smask_reference is PdfIndirect(smask_number) else {
    fail("expected alpha SMask reference")
  }
  guard stream.data is StreamGot(image_data) else {
    fail("expected materialized color image data")
  }
  @test.assert_eq(
    try! @flate.pdf_flate_decode(image_data),
    image_bytes_for_test([10, 20, 30, 50, 60, 70]),
  )
  let smask = document.lookup_object_or_null(smask_number)
  guard smask is PdfStreamObject(smask_stream) else {
    fail("expected SMask stream object")
  }
  @test.assert_eq(
    try! image_lookup_for_test(smask_stream.dictionary, "/ColorSpace"),
    PdfNameObject(image_name_for_test("/DeviceGray")),
  )
  @test.assert_eq(
    smask_stream.dictionary.lookup_immediate(
      image_name_for_test("/DecodeParms"),
    ),
    None,
  )
  guard smask_stream.data is StreamGot(mask_data) else {
    fail("expected materialized mask data")
  }
  @test.assert_eq(
    try! @flate.pdf_flate_decode(mask_data),
    image_bytes_for_test([40, 80]),
  )
}

///|
test "pdf_image_document_of_png_data preserves alpha mask in image document" {
  let document = try! @pdflite.pdf_image_document_of_png_data(
    image_png_rgba_for_test(),
    process_struct_tree=true,
    title=Some("PNG alt"),
  )
  let pages = try! document.pages_of_pagetree()
  @test.assert_eq(pages.length(), 1)
  @test.assert_eq(
    pages[0].mediabox,
    PdfArray([PdfReal(0.0), PdfReal(0.0), PdfReal(2.0), PdfReal(1.0)]),
  )
  @test.assert_eq(
    try! image_lookup_for_test(pages[0].rest, "/StructParents"),
    PdfInteger(1),
  )
  let xobjects = try! image_lookup_for_test(pages[0].resources, "/XObject")
  let (_, image_object) = try! image_lookup_indirect_object_for_test(
    document, xobjects, "/I0",
  )
  guard image_object is PdfStreamObject(image_stream) else {
    fail("expected page image stream")
  }
  let smask_reference = try! image_lookup_for_test(
    image_stream.dictionary,
    "/SMask",
  )
  guard smask_reference is PdfIndirect(smask_number) else {
    fail("expected page image SMask")
  }
  guard document.lookup_object_or_null(smask_number) is PdfStreamObject(_) else {
    fail("expected SMask object to remain in document")
  }
}

///|
test "pdf_image_object_of_png_data rejects 16-bit alpha PNGs" {
  let document = @pdflite.pdf_document_empty()
  let result : Result[@syntax.PdfObject, Error] = try? @pdflite.pdf_image_object_of_png_data(
    document,
    image_png_for_test(1, 1, 16, 6, 0, []),
  )
  guard result is Err(@pdflite.PdfError::BadPNG(_)) else {
    fail("expected 16-bit alpha PNG to raise BadPNG")
  }
}

///|
test "pdf_image_object_of_jbig2_data builds JBIG2 image XObject" {
  let data = image_jbig2_for_document_test()
  let (object, extra) = try! @pdflite.pdf_image_object_of_jbig2_data(data)
  @test.assert_eq(extra.length(), 0)
  guard object is PdfStreamObject(stream) else {
    fail("expected JBIG2 stream object")
  }
  @test.assert_eq(
    try! image_lookup_for_test(stream.dictionary, "/Length"),
    PdfInteger(data.length()),
  )
  @test.assert_eq(
    try! image_lookup_for_test(stream.dictionary, "/Filter"),
    PdfNameObject(image_name_for_test("/JBIG2Decode")),
  )
  @test.assert_eq(
    try! image_lookup_for_test(stream.dictionary, "/Subtype"),
    PdfNameObject(image_name_for_test("/Image")),
  )
  @test.assert_eq(
    try! image_lookup_for_test(stream.dictionary, "/BitsPerComponent"),
    PdfInteger(1),
  )
  @test.assert_eq(
    try! image_lookup_for_test(stream.dictionary, "/ColorSpace"),
    PdfNameObject(image_name_for_test("/DeviceGray")),
  )
  @test.assert_eq(
    try! image_lookup_for_test(stream.dictionary, "/Width"),
    PdfInteger(640),
  )
  @test.assert_eq(
    try! image_lookup_for_test(stream.dictionary, "/Height"),
    PdfInteger(480),
  )
  @test.assert_eq(
    stream.dictionary.lookup_immediate(image_name_for_test("/DecodeParms")),
    None,
  )
  @test.assert_eq(stream.data, StreamGot(data))
}

///|
test "pdf_image_object_of_jbig2_data returns globals extra object" {
  let data = image_jbig2_for_document_test()
  let globals = @ascii.encode("jbig2-globals")
  let (object, extra) = try! @pdflite.pdf_image_object_of_jbig2_data(
    data,
    global=Some(globals),
  )
  @test.assert_eq(extra.length(), 1)
  @test.assert_eq(extra[0].0, 10000)
  guard extra[0].1 is PdfStreamObject(global_stream) else {
    fail("expected JBIG2 globals stream")
  }
  @test.assert_eq(
    try! image_lookup_for_test(global_stream.dictionary, "/Length"),
    PdfInteger(globals.length()),
  )
  @test.assert_eq(global_stream.data, StreamGot(globals))
  guard object is PdfStreamObject(stream) else {
    fail("expected JBIG2 stream object")
  }
  let decodeparms = try! image_lookup_for_test(
    stream.dictionary,
    "/DecodeParms",
  )
  @test.assert_eq(
    try! image_lookup_for_test(decodeparms, "/JBIG2Globals"),
    PdfIndirect(10000),
  )
}

///|
test "pdf_image_obj_of_jbig2_data returns cpdf tuple shape" {
  let data = image_jbig2_for_document_test()
  let globals = @ascii.encode("wrapper-jbig2-globals")
  let (object, extra) = try! @pdflite.pdf_image_obj_of_jbig2_data(
    data,
    global=Some(globals),
  )
  let (expected, expected_extra) = try! @pdflite.pdf_image_object_of_jbig2_data(
    data,
    global=Some(globals),
  )
  @test.assert_eq(object, expected)
  @test.assert_eq(extra, expected_extra)
  @test.assert_eq(extra.length(), 1)
  @test.assert_eq(extra[0].0, 10000)
  @test.assert_eq(
    try! @pdflite.pdf_obj_of_jbig2_data(data, global=Some(globals)),
    (object, extra),
  )
}

///|
test "pdf_image_document_of_jbig2_data preserves globals object" {
  let globals = @ascii.encode("document-jbig2-globals")
  let document = try! @pdflite.pdf_image_document_of_jbig2_data(
    image_jbig2_for_document_test(),
    global=Some(globals),
    process_struct_tree=true,
    title=Some("JBIG2 alt"),
  )
  let pages = try! document.pages_of_pagetree()
  @test.assert_eq(pages.length(), 1)
  @test.assert_eq(
    pages[0].mediabox,
    PdfArray([PdfReal(0.0), PdfReal(0.0), PdfReal(640.0), PdfReal(480.0)]),
  )
  @test.assert_eq(
    try! image_lookup_for_test(pages[0].rest, "/StructParents"),
    PdfInteger(1),
  )
  let xobjects = try! image_lookup_for_test(pages[0].resources, "/XObject")
  let (_, image_object) = try! image_lookup_indirect_object_for_test(
    document, xobjects, "/I0",
  )
  guard image_object is PdfStreamObject(image_stream) else {
    fail("expected page JBIG2 image stream")
  }
  let decodeparms = try! image_lookup_for_test(
    image_stream.dictionary,
    "/DecodeParms",
  )
  @test.assert_eq(
    try! image_lookup_for_test(decodeparms, "/JBIG2Globals"),
    PdfIndirect(10000),
  )
  guard document.lookup_object_or_null(10000) is PdfStreamObject(global_stream) else {
    fail("expected document-level JBIG2 globals object")
  }
  @test.assert_eq(global_stream.data, StreamGot(globals))
}

///|
test "pdf_image_object_of_jbig2_data reports short data" {
  let result : Result[
    (@syntax.PdfObject, Array[(Int, @syntax.PdfObject)]),
    Error,
  ] = try? @pdflite.pdf_image_object_of_jbig2_data(
    image_bytes_for_test([0, 1, 2]),
  )
  guard result is Err(@pdflite.PdfError::EndOfInput) else {
    fail("expected short JBIG2 data to raise EndOfInput")
  }
}

///|
test "pdf_image_document_of_jpeg_data creates structured image page" {
  let document = try! @pdflite.pdf_image_document_of_jpeg_data(
    image_jpeg_for_document_test(),
    process_struct_tree=true,
    title=Some("Figure alt"),
  )
  let pages = try! document.pages_of_pagetree()
  @test.assert_eq(pages.length(), 1)
  @test.assert_eq(
    pages[0].mediabox,
    PdfArray([PdfReal(0.0), PdfReal(0.0), PdfReal(400.0), PdfReal(300.0)]),
  )
  @test.assert_eq(
    try! image_lookup_for_test(pages[0].rest, "/StructParents"),
    PdfInteger(1),
  )
  let placement = { ..@geometry.transform_identity_matrix, a: 400.0, d: 300.0 }
  @test.assert_eq(try! document.parse_content_ops(pages[0].content), [
    Op_BDC(
      image_name_for_test("/Figure"),
      PdfDictionary([(image_name_for_test("/MCID"), PdfInteger(0))]),
    ),
    Op_cm(placement),
    Op_Do(image_name_for_test("/I0")),
    Op_EMC,
  ])
  let xobjects = try! image_lookup_for_test(pages[0].resources, "/XObject")
  let (_, image_object) = try! image_lookup_indirect_object_for_test(
    document, xobjects, "/I0",
  )
  guard image_object is PdfStreamObject(image_stream) else {
    fail("expected page image stream")
  }
  @test.assert_eq(
    try! image_lookup_for_test(image_stream.dictionary, "/Filter"),
    PdfNameObject(image_name_for_test("/DCTDecode")),
  )
  let catalog = try! document.catalog()
  let (struct_root_number, struct_root) = try! image_lookup_indirect_object_for_test(
    document, catalog, "/StructTreeRoot",
  )
  let root_k = try! image_lookup_for_test(struct_root, "/K")
  guard root_k is PdfArray([PdfIndirect(figure_number)]) else {
    fail("expected image figure in StructTreeRoot /K")
  }
  let parent_tree_ref = try! image_lookup_for_test(struct_root, "/ParentTree")
  guard parent_tree_ref is PdfIndirect(parent_tree_number) else {
    fail("expected image parent tree")
  }
  @test.assert_eq(
    try! image_lookup_for_test(
      document.lookup_object_or_null(parent_tree_number),
      "/Nums",
    ),
    PdfArray([PdfInteger(1), PdfArray([PdfIndirect(figure_number)])]),
  )
  let figure = document.lookup_object_or_null(figure_number)
  @test.assert_eq(
    try! image_lookup_for_test(figure, "/K"),
    PdfArray([PdfInteger(0)]),
  )
  @test.assert_eq(
    try! image_lookup_for_test(figure, "/P"),
    PdfIndirect(struct_root_number),
  )
  @test.assert_eq(
    try! image_lookup_for_test(figure, "/S"),
    PdfNameObject(image_name_for_test("/Figure")),
  )
  @test.assert_eq(
    try! image_lookup_for_test(figure, "/Alt"),
    PdfString(@utf8.encode("Figure alt")),
  )
}

///|
test "pdf_image_of_input builds document through cpdf object callback" {
  let document = try! @pdflite.pdf_image_of_input(
    image_jpeg_for_document_test(),
    fn(_, data) raise @pdflite.PdfError {
      @pdflite.pdf_image_obj_of_jpeg_data(data)
    },
    process_struct_tree=true,
    title=Some("Callback image"),
  )
  let pages = try! document.pages_of_pagetree()
  @test.assert_eq(pages.length(), 1)
  @test.assert_eq(
    pages[0].mediabox,
    PdfArray([PdfReal(0.0), PdfReal(0.0), PdfReal(400.0), PdfReal(300.0)]),
  )
  let xobjects = try! image_lookup_for_test(pages[0].resources, "/XObject")
  let (_, image_object) = try! image_lookup_indirect_object_for_test(
    document, xobjects, "/I0",
  )
  guard image_object is PdfStreamObject(image_stream) else {
    fail("expected page image stream")
  }
  @test.assert_eq(
    try! image_lookup_for_test(image_stream.dictionary, "/Filter"),
    PdfNameObject(image_name_for_test("/DCTDecode")),
  )
  let catalog = try! document.catalog()
  let (_, struct_root) = try! image_lookup_indirect_object_for_test(
    document, catalog, "/StructTreeRoot",
  )
  let root_k = try! image_lookup_for_test(struct_root, "/K")
  guard root_k is PdfArray([PdfIndirect(figure_number)]) else {
    fail("expected image figure in StructTreeRoot /K")
  }
  @test.assert_eq(
    try! image_lookup_for_test(
      document.lookup_object_or_null(figure_number),
      "/Alt",
    ),
    PdfString(@utf8.encode("Callback image")),
  )
}

///|
test "pdf_image_document_of_jpeg_data creates PDF/UA-2 document wrapper" {
  let document = try! @pdflite.pdf_image_document_of_jpeg_data(
    image_jpeg_for_document_test(),
    subformat=Some(PdfUA2),
    title=Some("UA image"),
  )
  @test.assert_eq(document.version(), (2, 0))
  let pages = try! document.pages_of_pagetree()
  @test.assert_eq(pages.length(), 1)
  @test.assert_eq(
    try! image_lookup_for_test(pages[0].rest, "/StructParents"),
    PdfInteger(1),
  )
  let catalog = try! document.catalog()
  let (struct_root_number, struct_root) = try! image_lookup_indirect_object_for_test(
    document, catalog, "/StructTreeRoot",
  )
  let namespaces = try! image_lookup_for_test(struct_root, "/Namespaces")
  guard namespaces is PdfArray([PdfIndirect(namespace_number)]) else {
    fail("expected PDF/UA-2 image namespace")
  }
  @test.assert_eq(
    try! image_lookup_for_test(
      document.lookup_object_or_null(namespace_number),
      "/NS",
    ),
    PdfString(@ascii.encode("http://iso.org/pdf2/ssn")),
  )
  let root_k = try! image_lookup_for_test(struct_root, "/K")
  guard root_k is PdfArray([PdfIndirect(document_number)]) else {
    fail("expected PDF/UA-2 image document element")
  }
  let document_node = document.lookup_object_or_null(document_number)
  @test.assert_eq(
    try! image_lookup_for_test(document_node, "/S"),
    PdfNameObject(image_name_for_test("/Document")),
  )
  @test.assert_eq(
    try! image_lookup_for_test(document_node, "/P"),
    PdfIndirect(struct_root_number),
  )
  @test.assert_eq(
    try! image_lookup_for_test(document_node, "/NS"),
    PdfIndirect(namespace_number),
  )
  guard (try! image_lookup_for_test(document_node, "/K"))
    is PdfArray([PdfIndirect(figure_number)]) else {
    fail("expected PDF/UA-2 image figure")
  }
  let figure = document.lookup_object_or_null(figure_number)
  @test.assert_eq(
    try! image_lookup_for_test(figure, "/P"),
    PdfIndirect(document_number),
  )
  @test.assert_eq(
    try! image_lookup_for_test(figure, "/Alt"),
    PdfString(@utf8.encode("UA image")),
  )
  let (_, metadata) = try! image_lookup_indirect_object_for_test(
    document, catalog, "/Metadata",
  )
  guard metadata is PdfStreamObject(metadata_stream) else {
    fail("expected PDF/UA metadata stream")
  }
  guard metadata_stream.data is StreamGot(metadata_bytes) else {
    fail("expected materialized PDF/UA metadata")
  }
  @test.assert_eq(
    image_find_bytes_for_test(
      metadata_bytes,
      @ascii.encode("<pdfuaid:part>2</pdfuaid:part>"),
    ) >=
    0,
    true,
  )
}

///|
test "pdf_image_document_of_jpeg_data requires title for PDF/UA subformat" {
  let result : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_image_document_of_jpeg_data(
    image_jpeg_for_document_test(),
    subformat=Some(PdfUA1),
  )
  guard result is Err(@pdflite.PdfError::TitleExpected) else {
    fail("expected missing PDF/UA image title to raise TitleExpected")
  }
}
