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
    Map::of([
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
fn image_lookup_for_test(
  object : @pdflite.PdfObject,
  key : String,
) -> @pdflite.PdfObject raise {
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
  object : @pdflite.PdfObject,
  key : String,
) -> (Int, @pdflite.PdfObject) raise {
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
  let idat = @pdflite.pdf_flate_encode(raw)
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
    image_png_split_idat_for_test(@pdflite.pdf_flate_encode(raw)),
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
    for start = 0
        start <= haystack.length() - needle.length()
        start = start + 1 {
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
    @pdflite.pdf_stream(
      @pdflite.pdf_dictionary([
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
    @pdflite.pdf_stream(
      @pdflite.pdf_dictionary([
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
    ..@pdflite.pdf_page_blank(@pdflite.paper_a4),
    resources: @pdflite.pdf_dictionary([
      (
        image_name_for_test("/XObject"),
        @pdflite.pdf_dictionary([(image_name_for_test("/Im1"), PdfIndirect(20))]),
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
  let inline_dict = @pdflite.pdf_dictionary([
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
      @pdflite.pdf_dictionary([]),
    )
  doc.add_object_given_number(30, form)
  let page = {
    ..@pdflite.pdf_page_blank(@pdflite.paper_a4),
    resources: @pdflite.pdf_dictionary([
      (
        image_name_for_test("/XObject"),
        @pdflite.pdf_dictionary([(image_name_for_test("/Fm1"), PdfIndirect(30))]),
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
test "pdf_read_png reads IHDR and concatenated IDAT chunks" {
  let (png_bytes, idat) = image_png_rgb_for_test()
  let png = try! @pdflite.pdf_read_png(png_bytes)
  @test.assert_eq(png.width, 2)
  @test.assert_eq(png.height, 1)
  @test.assert_eq(png.bit_depth, 8)
  @test.assert_eq(png.color_type, 2)
  @test.assert_eq(png.idat, idat)
  @test.assert_eq(
    try! @pdflite.pdf_flate_decode(png.idat),
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
    try! @pdflite.pdf_flate_decode(image_data),
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
    try! @pdflite.pdf_flate_decode(mask_data),
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
  let result : Result[@pdflite.PdfObject, Error] = try? @pdflite.pdf_image_object_of_png_data(
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
    (@pdflite.PdfObject, Array[(Int, @pdflite.PdfObject)]),
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
  let placement = { ..@pdflite.transform_identity_matrix, a: 400.0, d: 300.0 }
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
    try! @pdflite.pdf_image_colspace(
      doc,
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
  @test.assert_eq(
    try! @pdflite.pdf_get_image_24bpp(doc, @pdflite.pdf_dictionary([]), image),
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
  let short_alias_jpeg = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (image_name_for_test("/W"), PdfInteger(1)),
      (image_name_for_test("/H"), PdfInteger(1)),
      (
        image_name_for_test("/F"),
        PdfArray([PdfNameObject(image_name_for_test("/DCT"))]),
      ),
    ]),
    StreamGot(@ascii.encode("short-alias-jpg")),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(@pdflite.pdf_dictionary([]), short_alias_jpeg),
    PdfJPEG(@ascii.encode("short-alias-jpg"), None),
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
test "PdfDocument get_image_24bpp extracts image XObjects after PDF roundtrip" {
  let doc = @pdflite.pdf_document_empty()
  doc.set_version(1, 4)
  let image_name = image_name_for_test("/Im0")
  let raw_data = image_bytes_for_test([1, 2, 3, 4, 5, 6])
  let flate_data = @pdflite.pdf_flate_encode(raw_data)
  let image_number = doc.add_object(
    @pdflite.pdf_stream(
      @pdflite.pdf_dictionary([
        (
          image_name_for_test("/Subtype"),
          PdfNameObject(image_name_for_test("/Image")),
        ),
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
      StreamGot(flate_data),
    ),
  )
  let placement = { ..@pdflite.transform_identity_matrix, a: 2.0, d: 1.0 }
  let page = {
    ..@pdflite.pdf_page_blank(@pdflite.paper_a4),
    content: [
      try! @pdflite.pdf_content_stream_of_ops([
        Op_q,
        Op_cm(placement),
        Op_Do(image_name),
        Op_Q,
      ]),
    ],
    resources: @pdflite.pdf_dictionary([
      (
        image_name_for_test("/XObject"),
        @pdflite.pdf_dictionary([(image_name, PdfIndirect(image_number))]),
      ),
    ]),
  }
  let page_root = try! doc.add_pagetree([page])
  ignore(try! doc.add_root(page_root, []))
  let parsed = try! @pdflite.pdf_read_document_from_bytes(
    try! @pdflite.pdf_write_document(doc),
  )
  let pages = try! parsed.pages_of_pagetree()
  @test.assert_eq(pages.length(), 1)
  @test.assert_eq(try! parsed.parse_content_ops(pages[0].content), [
    Op_q,
    Op_cm(placement),
    Op_Do(image_name),
    Op_Q,
  ])
  let xobjects = match
    parsed.lookup_direct(image_name_for_test("/XObject"), pages[0].resources) {
    Some(value) => value
    None => fail("expected page XObject resources")
  }
  let image = match parsed.lookup_direct(image_name, xobjects) {
    Some(value) => value
    None => fail("expected image XObject")
  }
  @test.assert_eq(
    try! parsed.get_image_24bpp(pages[0].resources, image),
    PdfRawImage(2, 1, PdfBPP24, raw_data),
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
    PdfJPEG(@ascii.encode("indexed"), Some([0.0, 1.0])),
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
  let rgb_data = image_bytes_for_test([1, 2, 3, 4, 5, 6])
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
    StreamGot(rgb_data),
  )
  let rgb_result = doc.get_image_24bpp(empty_resources, rgb)
  @test.assert_eq(
    rgb_result,
    PdfRawImage(2, 1, PdfBPP24, image_bytes_for_test([1, 2, 3, 4, 5, 6])),
  )
  match rgb_result {
    PdfRawImage(_, _, _, data) =>
      @test.assert_eq(physical_equal(rgb_data, data), true)
    _ => fail("expected raw RGB image")
  }
  let rgb_extra_data = image_bytes_for_test([1, 2, 3, 4, 5, 6, 7])
  let rgb_extra = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (image_name_for_test("/Width"), PdfInteger(2)),
      (image_name_for_test("/Height"), PdfInteger(1)),
      (
        image_name_for_test("/ColorSpace"),
        PdfNameObject(image_name_for_test("/DeviceRGB")),
      ),
      (image_name_for_test("/BitsPerComponent"), PdfInteger(8)),
    ]),
    StreamGot(rgb_extra_data),
  )
  let rgb_extra_result = doc.get_image_24bpp(empty_resources, rgb_extra)
  @test.assert_eq(
    rgb_extra_result,
    PdfRawImage(2, 1, PdfBPP24, image_bytes_for_test([1, 2, 3, 4, 5, 6])),
  )
  match rgb_extra_result {
    PdfRawImage(_, _, _, data) =>
      @test.assert_eq(physical_equal(rgb_extra_data, data), false)
    _ => fail("expected raw RGB image")
  }
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
  let rgb8_with_decode = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (image_name_for_test("/Width"), PdfInteger(1)),
      (image_name_for_test("/Height"), PdfInteger(1)),
      (image_name_for_test("/ColorSpace"), indexed_rgb),
      (image_name_for_test("/BitsPerComponent"), PdfInteger(8)),
      (image_name_for_test("/Decode"), PdfArray([PdfInteger(1), PdfInteger(0)])),
    ]),
    StreamGot(image_bytes_for_test([0])),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(empty_resources, rgb8_with_decode),
    PdfRawImage(1, 1, PdfBPP24, image_bytes_for_test([10, 20, 30])),
  )
  let rgb1 = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (image_name_for_test("/Width"), PdfInteger(3)),
      (image_name_for_test("/Height"), PdfInteger(1)),
      (image_name_for_test("/ColorSpace"), indexed_rgb),
      (image_name_for_test("/BitsPerComponent"), PdfInteger(1)),
    ]),
    StreamGot(image_bytes_for_test([0b0100_0000])),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(empty_resources, rgb1),
    PdfRawImage(
      3,
      1,
      PdfBPP24,
      image_bytes_for_test([10, 20, 30, 40, 50, 60, 10, 20, 30]),
    ),
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
  let cmyk1 = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (image_name_for_test("/Width"), PdfInteger(2)),
      (image_name_for_test("/Height"), PdfInteger(1)),
      (image_name_for_test("/ColorSpace"), indexed_cmyk),
      (image_name_for_test("/BitsPerComponent"), PdfInteger(1)),
    ]),
    StreamGot(image_bytes_for_test([0b0100_0000])),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(empty_resources, cmyk1),
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
  let image1 = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (image_name_for_test("/Width"), PdfInteger(2)),
      (image_name_for_test("/Height"), PdfInteger(1)),
      (image_name_for_test("/ColorSpace"), indexed_lab),
      (image_name_for_test("/BitsPerComponent"), PdfInteger(1)),
    ]),
    StreamGot(image_bytes_for_test([0b0100_0000])),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(@pdflite.pdf_dictionary([]), image1),
    PdfRawImage(2, 1, PdfBPP24, image_bytes_for_test([0, 0, 0, 141, 141, 141])),
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
    fail("expected @pdflite.PdfError::EndOfInput for short raw image")
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
  @test.assert_eq(
    @pdflite.pdf_image_bpc(
      doc,
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
