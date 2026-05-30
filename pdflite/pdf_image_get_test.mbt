///|
fn image_get_name_for_test(text : String) -> @core.PdfName {
  @core.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn image_get_bytes_for_test(values : ArrayView[Int]) -> @core.PdfBytes {
  try! @core.pdf_bytes_of_int_array(values)
}

///|
test "PdfDocument image_colour_space resolves direct and resource colour spaces" {
  let doc = @pdflite.pdf_document_empty()
  let resources = @syntax.pdf_dictionary([
    (
      image_get_name_for_test("/ColorSpace"),
      @syntax.pdf_dictionary([
        (
          image_get_name_for_test("/CS1"),
          PdfNameObject(image_get_name_for_test("/DeviceRGB")),
        ),
      ]),
    ),
  ])
  @test.assert_eq(
    try! doc.image_colour_space(
      @syntax.pdf_dictionary([
        (
          image_get_name_for_test("/ColorSpace"),
          PdfNameObject(image_get_name_for_test("/DeviceCMYK")),
        ),
      ]),
      resources,
    ),
    PdfDeviceCMYK,
  )
  @test.assert_eq(
    try! doc.colspace(
      @syntax.pdf_dictionary([
        (
          image_get_name_for_test("/ColorSpace"),
          PdfNameObject(image_get_name_for_test("/DeviceCMYK")),
        ),
      ]),
      resources,
    ),
    PdfDeviceCMYK,
  )
  @test.assert_eq(
    try! @pdflite.pdf_image_colspace(
      doc,
      @syntax.pdf_dictionary([
        (
          image_get_name_for_test("/ColorSpace"),
          PdfNameObject(image_get_name_for_test("/DeviceCMYK")),
        ),
      ]),
      resources,
    ),
    PdfDeviceCMYK,
  )
  @test.assert_eq(
    try! doc.image_colour_space(
      @syntax.pdf_dictionary([
        (
          image_get_name_for_test("/CS"),
          PdfNameObject(image_get_name_for_test("/CS1")),
        ),
      ]),
      resources,
    ),
    PdfDeviceRGB,
  )
}

///|
test "PdfDocument get_image_24bpp returns encoded JPEG images" {
  let doc = @pdflite.pdf_document_empty()
  let image = @syntax.pdf_stream(
    @syntax.pdf_dictionary([
      (image_get_name_for_test("/Width"), PdfInteger(1)),
      (image_get_name_for_test("/Height"), PdfInteger(1)),
      (
        image_get_name_for_test("/Filter"),
        PdfNameObject(image_get_name_for_test("/DCTDecode")),
      ),
      (
        image_get_name_for_test("/Decode"),
        PdfArray([PdfInteger(0), PdfInteger(1)]),
      ),
    ]),
    StreamGot(@ascii.encode("jpg")),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(@syntax.pdf_dictionary([]), image),
    PdfJPEG(@ascii.encode("jpg"), Some([0.0, 1.0])),
  )
  @test.assert_eq(
    try! @pdflite.pdf_get_image_24bpp(doc, @syntax.pdf_dictionary([]), image),
    PdfJPEG(@ascii.encode("jpg"), Some([0.0, 1.0])),
  )
  let gray_jpeg = @syntax.pdf_stream(
    @syntax.pdf_dictionary([
      (image_get_name_for_test("/Width"), PdfInteger(1)),
      (image_get_name_for_test("/Height"), PdfInteger(1)),
      (
        image_get_name_for_test("/Filter"),
        PdfNameObject(image_get_name_for_test("/DCTDecode")),
      ),
      (
        image_get_name_for_test("/ColorSpace"),
        PdfNameObject(image_get_name_for_test("/DeviceGray")),
      ),
    ]),
    StreamGot(@ascii.encode("gray-jpg")),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(@syntax.pdf_dictionary([]), gray_jpeg),
    PdfJPEG(@ascii.encode("gray-jpg"), Some([0.0, 1.0])),
  )
  let array_jpeg = @syntax.pdf_stream(
    @syntax.pdf_dictionary([
      (image_get_name_for_test("/Width"), PdfInteger(1)),
      (image_get_name_for_test("/Height"), PdfInteger(1)),
      (
        image_get_name_for_test("/Filter"),
        PdfArray([PdfNameObject(image_get_name_for_test("/DCTDecode"))]),
      ),
    ]),
    StreamGot(@ascii.encode("array-jpg")),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(@syntax.pdf_dictionary([]), array_jpeg),
    PdfJPEG(@ascii.encode("array-jpg"), None),
  )
  let short_alias_jpeg = @syntax.pdf_stream(
    @syntax.pdf_dictionary([
      (image_get_name_for_test("/W"), PdfInteger(1)),
      (image_get_name_for_test("/H"), PdfInteger(1)),
      (
        image_get_name_for_test("/F"),
        PdfArray([PdfNameObject(image_get_name_for_test("/DCT"))]),
      ),
    ]),
    StreamGot(@ascii.encode("short-alias-jpg")),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(@syntax.pdf_dictionary([]), short_alias_jpeg),
    PdfJPEG(@ascii.encode("short-alias-jpg"), None),
  )
  doc.add_object_given_number(
    8,
    PdfNameObject(image_get_name_for_test("/DCTDecode")),
  )
  let indirect_array_jpeg = @syntax.pdf_stream(
    @syntax.pdf_dictionary([
      (image_get_name_for_test("/Width"), PdfInteger(1)),
      (image_get_name_for_test("/Height"), PdfInteger(1)),
      (image_get_name_for_test("/Filter"), PdfArray([PdfIndirect(8)])),
    ]),
    StreamGot(@ascii.encode("indirect-array-jpg")),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(@syntax.pdf_dictionary([]), indirect_array_jpeg),
    PdfJPEG(@ascii.encode("indirect-array-jpg"), None),
  )
}

///|
test "PdfDocument get_image_24bpp returns encoded JPX and JBIG2 images" {
  let doc = @pdflite.pdf_document_empty()
  let jpx = @syntax.pdf_stream(
    @syntax.pdf_dictionary([
      (image_get_name_for_test("/W"), PdfInteger(1)),
      (image_get_name_for_test("/H"), PdfInteger(1)),
      (
        image_get_name_for_test("/F"),
        PdfNameObject(image_get_name_for_test("/JPXDecode")),
      ),
    ]),
    StreamGot(@ascii.encode("jpx")),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(@syntax.pdf_dictionary([]), jpx),
    PdfJPEG2000(@ascii.encode("jpx"), None),
  )
  let jbig2 = @syntax.pdf_stream(
    @syntax.pdf_dictionary([
      (image_get_name_for_test("/Width"), PdfInteger(1)),
      (image_get_name_for_test("/Height"), PdfInteger(1)),
      (
        image_get_name_for_test("/Filter"),
        PdfNameObject(image_get_name_for_test("/JBIG2Decode")),
      ),
      (
        image_get_name_for_test("/DecodeParms"),
        @syntax.pdf_dictionary([
          (image_get_name_for_test("/JBIG2Globals"), PdfIndirect(99)),
        ]),
      ),
    ]),
    StreamGot(@ascii.encode("jbig")),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(@syntax.pdf_dictionary([]), jbig2),
    PdfJBIG2(@ascii.encode("jbig"), None, Some(99)),
  )
  let jbig2_short_decodeparms = @syntax.pdf_stream(
    @syntax.pdf_dictionary([
      (image_get_name_for_test("/Width"), PdfInteger(1)),
      (image_get_name_for_test("/Height"), PdfInteger(1)),
      (
        image_get_name_for_test("/Filter"),
        PdfNameObject(image_get_name_for_test("/JBIG2Decode")),
      ),
      (
        image_get_name_for_test("/DP"),
        @syntax.pdf_dictionary([
          (image_get_name_for_test("/JBIG2Globals"), PdfIndirect(77)),
        ]),
      ),
    ]),
    StreamGot(@ascii.encode("short-jbig")),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(
      @syntax.pdf_dictionary([]),
      jbig2_short_decodeparms,
    ),
    PdfJBIG2(@ascii.encode("short-jbig"), None, Some(77)),
  )
  let jbig2_array_decodeparms = @syntax.pdf_stream(
    @syntax.pdf_dictionary([
      (image_get_name_for_test("/Width"), PdfInteger(1)),
      (image_get_name_for_test("/Height"), PdfInteger(1)),
      (
        image_get_name_for_test("/Filter"),
        PdfArray([PdfNameObject(image_get_name_for_test("/JBIG2Decode"))]),
      ),
      (
        image_get_name_for_test("/DecodeParms"),
        PdfArray([
          @syntax.pdf_dictionary([
            (image_get_name_for_test("/JBIG2Globals"), PdfIndirect(42)),
          ]),
        ]),
      ),
    ]),
    StreamGot(@ascii.encode("array-jbig")),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(
      @syntax.pdf_dictionary([]),
      jbig2_array_decodeparms,
    ),
    PdfJBIG2(@ascii.encode("array-jbig"), None, Some(42)),
  )
  let jbig2_empty_decodeparms = @syntax.pdf_stream(
    @syntax.pdf_dictionary([
      (image_get_name_for_test("/Width"), PdfInteger(1)),
      (image_get_name_for_test("/Height"), PdfInteger(1)),
      (
        image_get_name_for_test("/Filter"),
        PdfNameObject(image_get_name_for_test("/JBIG2Decode")),
      ),
      (image_get_name_for_test("/DecodeParms"), @syntax.pdf_dictionary([])),
    ]),
    StreamGot(@ascii.encode("empty-dp-jbig")),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(
      @syntax.pdf_dictionary([]),
      jbig2_empty_decodeparms,
    ),
    PdfJBIG2(@ascii.encode("empty-dp-jbig"), None, None),
  )
  let jbig2_bad_array_decodeparms = @syntax.pdf_stream(
    @syntax.pdf_dictionary([
      (image_get_name_for_test("/Width"), PdfInteger(1)),
      (image_get_name_for_test("/Height"), PdfInteger(1)),
      (
        image_get_name_for_test("/Filter"),
        PdfArray([PdfNameObject(image_get_name_for_test("/JBIG2Decode"))]),
      ),
      (image_get_name_for_test("/DecodeParms"), PdfArray([PdfInteger(1)])),
    ]),
    StreamGot(@ascii.encode("bad-array-jbig")),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(
      @syntax.pdf_dictionary([]),
      jbig2_bad_array_decodeparms,
    ),
    PdfJBIG2(@ascii.encode("bad-array-jbig"), None, None),
  )
  let jbig2_without_globals = @syntax.pdf_stream(
    @syntax.pdf_dictionary([
      (image_get_name_for_test("/Width"), PdfInteger(1)),
      (image_get_name_for_test("/Height"), PdfInteger(1)),
      (
        image_get_name_for_test("/Filter"),
        PdfNameObject(image_get_name_for_test("/JBIG2Decode")),
      ),
    ]),
    StreamGot(@ascii.encode("plain-jbig")),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(@syntax.pdf_dictionary([]), jbig2_without_globals),
    PdfJBIG2(@ascii.encode("plain-jbig"), None, None),
  )
  let jbig2_bad_decodeparms = @syntax.pdf_stream(
    @syntax.pdf_dictionary([
      (image_get_name_for_test("/Width"), PdfInteger(1)),
      (image_get_name_for_test("/Height"), PdfInteger(1)),
      (
        image_get_name_for_test("/Filter"),
        PdfNameObject(image_get_name_for_test("/JBIG2Decode")),
      ),
      (image_get_name_for_test("/DecodeParms"), PdfInteger(1)),
    ]),
    StreamGot(@ascii.encode("bad-jbig")),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(@syntax.pdf_dictionary([]), jbig2_bad_decodeparms),
    PdfJBIG2(@ascii.encode("bad-jbig"), None, None),
  )
}

///|
test "PdfDocument get_image_24bpp decodes filter stages before image extraction" {
  let doc = @pdflite.pdf_document_empty()
  let raw_data = image_get_bytes_for_test([1, 2, 3, 4, 5, 6])
  let flate_raw_data = @flate.pdf_flate_encode(raw_data)
  let flate_raw = @syntax.pdf_stream(
    @syntax.pdf_dictionary([
      (image_get_name_for_test("/Length"), PdfInteger(flate_raw_data.length())),
      (image_get_name_for_test("/Width"), PdfInteger(2)),
      (image_get_name_for_test("/Height"), PdfInteger(1)),
      (
        image_get_name_for_test("/ColorSpace"),
        PdfNameObject(image_get_name_for_test("/DeviceRGB")),
      ),
      (image_get_name_for_test("/BitsPerComponent"), PdfInteger(8)),
      (
        image_get_name_for_test("/Filter"),
        PdfNameObject(image_get_name_for_test("/FlateDecode")),
      ),
    ]),
    StreamGot(flate_raw_data),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(@syntax.pdf_dictionary([]), flate_raw),
    PdfRawImage(2, 1, PdfBPP24, raw_data),
  )
  let flate_jpeg_data = @flate.pdf_flate_encode(@ascii.encode("jpg"))
  let encoded_jpeg = @syntax.pdf_stream(
    @syntax.pdf_dictionary([
      (image_get_name_for_test("/Length"), PdfInteger(flate_jpeg_data.length())),
      (image_get_name_for_test("/Width"), PdfInteger(1)),
      (image_get_name_for_test("/Height"), PdfInteger(1)),
      (
        image_get_name_for_test("/Filter"),
        PdfArray([
          PdfNameObject(image_get_name_for_test("/FlateDecode")),
          PdfNameObject(image_get_name_for_test("/DCTDecode")),
        ]),
      ),
    ]),
    StreamGot(flate_jpeg_data),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(@syntax.pdf_dictionary([]), encoded_jpeg),
    PdfJPEG(@ascii.encode("jpg"), None),
  )
  let flate_jbig2_data = @flate.pdf_flate_encode(@ascii.encode("jbig-stage"))
  let encoded_jbig2 = @syntax.pdf_stream(
    @syntax.pdf_dictionary([
      (
        image_get_name_for_test("/Length"),
        PdfInteger(flate_jbig2_data.length()),
      ),
      (image_get_name_for_test("/Width"), PdfInteger(1)),
      (image_get_name_for_test("/Height"), PdfInteger(1)),
      (
        image_get_name_for_test("/Filter"),
        PdfArray([
          PdfNameObject(image_get_name_for_test("/FlateDecode")),
          PdfNameObject(image_get_name_for_test("/JBIG2Decode")),
        ]),
      ),
      (
        image_get_name_for_test("/DecodeParms"),
        PdfArray([
          PdfNull,
          @syntax.pdf_dictionary([
            (image_get_name_for_test("/JBIG2Globals"), PdfIndirect(123)),
          ]),
        ]),
      ),
    ]),
    StreamGot(flate_jbig2_data),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(@syntax.pdf_dictionary([]), encoded_jbig2),
    PdfJBIG2(@ascii.encode("jbig-stage"), None, Some(123)),
  )
}

///|
test "PdfDocument get_image_24bpp extracts image XObjects after PDF roundtrip" {
  let doc = @pdflite.pdf_document_empty()
  doc.set_version(1, 4)
  let image_name = image_get_name_for_test("/Im0")
  let raw_data = image_get_bytes_for_test([1, 2, 3, 4, 5, 6])
  let flate_data = @flate.pdf_flate_encode(raw_data)
  let image_number = doc.add_object(
    @syntax.pdf_stream(
      @syntax.pdf_dictionary([
        (
          image_get_name_for_test("/Subtype"),
          PdfNameObject(image_get_name_for_test("/Image")),
        ),
        (image_get_name_for_test("/Width"), PdfInteger(2)),
        (image_get_name_for_test("/Height"), PdfInteger(1)),
        (
          image_get_name_for_test("/ColorSpace"),
          PdfNameObject(image_get_name_for_test("/DeviceRGB")),
        ),
        (image_get_name_for_test("/BitsPerComponent"), PdfInteger(8)),
        (
          image_get_name_for_test("/Filter"),
          PdfNameObject(image_get_name_for_test("/FlateDecode")),
        ),
      ]),
      StreamGot(flate_data),
    ),
  )
  let placement = { ..@geometry.transform_identity_matrix, a: 2.0, d: 1.0 }
  let page = {
    ..@page.pdf_page_blank(@geometry.paper_a4),
    content: [
      try! @pdflite.pdf_content_stream_of_ops([
        Op_q,
        Op_cm(placement),
        Op_Do(image_name),
        Op_Q,
      ]),
    ],
    resources: @syntax.pdf_dictionary([
      (
        image_get_name_for_test("/XObject"),
        @syntax.pdf_dictionary([(image_name, PdfIndirect(image_number))]),
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
    parsed.lookup_direct(
      image_get_name_for_test("/XObject"),
      pages[0].resources,
    ) {
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
  let empty_resources = @syntax.pdf_dictionary([])
  let empty_filter_raw = @syntax.pdf_stream(
    @syntax.pdf_dictionary([
      (image_get_name_for_test("/Width"), PdfInteger(1)),
      (image_get_name_for_test("/Height"), PdfInteger(1)),
      (
        image_get_name_for_test("/ColorSpace"),
        PdfNameObject(image_get_name_for_test("/DeviceRGB")),
      ),
      (image_get_name_for_test("/BitsPerComponent"), PdfInteger(8)),
      (image_get_name_for_test("/Filter"), PdfArray([])),
    ]),
    StreamGot(image_get_bytes_for_test([10, 20, 30])),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(empty_resources, empty_filter_raw),
    PdfRawImage(1, 1, PdfBPP24, image_get_bytes_for_test([10, 20, 30])),
  )
  let malformed_filter = @syntax.pdf_stream(
    @syntax.pdf_dictionary([
      (image_get_name_for_test("/Width"), PdfInteger(1)),
      (image_get_name_for_test("/Height"), PdfInteger(1)),
      (
        image_get_name_for_test("/ColorSpace"),
        PdfNameObject(image_get_name_for_test("/DeviceRGB")),
      ),
      (image_get_name_for_test("/BitsPerComponent"), PdfInteger(8)),
      (image_get_name_for_test("/Filter"), PdfInteger(1)),
    ]),
    StreamGot(image_get_bytes_for_test([10, 20, 30])),
  )
  let malformed : Result[@pdflite.PdfImage, Error] = try? doc.get_image_24bpp(
    empty_resources, malformed_filter,
  )
  guard malformed is Err(@core.PdfError::FilterExpected) else {
    fail("expected malformed filter")
  }
  let cursor = @core.byte_cursor_of_bytes(image_get_bytes_for_test([1, 2, 3]))
  let deferred_raw = @syntax.pdf_stream(
    @syntax.pdf_dictionary([
      (image_get_name_for_test("/Width"), PdfInteger(1)),
      (image_get_name_for_test("/Height"), PdfInteger(1)),
      (
        image_get_name_for_test("/ColorSpace"),
        PdfNameObject(image_get_name_for_test("/DeviceRGB")),
      ),
      (image_get_name_for_test("/BitsPerComponent"), PdfInteger(8)),
    ]),
    StreamToGet(@syntax.stream_to_get(cursor, 0, 3)),
  )
  @test.assert_eq(
    try! doc.get_image_24bpp(empty_resources, deferred_raw),
    PdfRawImage(1, 1, PdfBPP24, image_get_bytes_for_test([1, 2, 3])),
  )
}

///|
test "PdfDocument image_colour_space treats image masks as DeviceGray" {
  let doc = @pdflite.pdf_document_empty()
  @test.assert_eq(
    try! doc.image_colour_space(
      @syntax.pdf_dictionary([
        (image_get_name_for_test("/ImageMask"), PdfBoolean(true)),
      ]),
      @syntax.pdf_dictionary([]),
    ),
    PdfDeviceGray,
  )
  @test.assert_eq(
    try! doc.image_colour_space(
      @syntax.pdf_dictionary([
        (image_get_name_for_test("/IM"), PdfBoolean(true)),
      ]),
      @syntax.pdf_dictionary([]),
    ),
    PdfDeviceGray,
  )
}

///|
test "PdfDocument image_colour_space reports missing colour spaces" {
  let doc = @pdflite.pdf_document_empty()
  let missing : Result[@pdflite.PdfColourSpace, Error] = try? doc.image_colour_space(
    @syntax.pdf_dictionary([]),
    @syntax.pdf_dictionary([]),
  )
  guard missing is Err(@core.PdfError::DictionaryKeyNotFound(name)) &&
    name == image_get_name_for_test("/ColorSpace") else {
    fail("expected missing image colour space")
  }
  let unknown : Result[@pdflite.PdfColourSpace, Error] = try? doc.image_colour_space(
    @syntax.pdf_dictionary([
      (
        image_get_name_for_test("/ColorSpace"),
        PdfNameObject(image_get_name_for_test("/CS1")),
      ),
    ]),
    @syntax.pdf_dictionary([]),
  )
  guard unknown is Err(@core.PdfError::DictionaryKeyNotFound(name)) &&
    name == image_get_name_for_test("/ColorSpace") else {
    fail("expected unknown image colour space")
  }
}

///|
test "PdfDocument image_bits_per_component reads long and abbreviated keys" {
  let doc = @pdflite.pdf_document_empty()
  @test.assert_eq(
    doc.image_bits_per_component(
      @syntax.pdf_dictionary([
        (image_get_name_for_test("/BitsPerComponent"), PdfInteger(8)),
      ]),
    ),
    Some(PdfInteger(8)),
  )
  @test.assert_eq(
    doc.image_bits_per_component(
      @syntax.pdf_dictionary([(image_get_name_for_test("/BPC"), PdfInteger(4))]),
    ),
    Some(PdfInteger(4)),
  )
  @test.assert_eq(
    doc.bpc(
      @syntax.pdf_dictionary([(image_get_name_for_test("/BPC"), PdfInteger(4))]),
    ),
    Some(PdfInteger(4)),
  )
  @test.assert_eq(
    @pdflite.pdf_image_bpc(
      doc,
      @syntax.pdf_dictionary([(image_get_name_for_test("/BPC"), PdfInteger(4))]),
    ),
    Some(PdfInteger(4)),
  )
}

///|
test "PdfDocument image_bits_per_component defaults masks to one bit" {
  let doc = @pdflite.pdf_document_empty()
  @test.assert_eq(
    doc.image_bits_per_component(
      @syntax.pdf_dictionary([
        (image_get_name_for_test("/ImageMask"), PdfBoolean(true)),
      ]),
    ),
    Some(PdfInteger(1)),
  )
  @test.assert_eq(
    doc.image_bits_per_component(
      @syntax.pdf_dictionary([
        (image_get_name_for_test("/IM"), PdfBoolean(true)),
      ]),
    ),
    Some(PdfInteger(1)),
  )
  @test.assert_eq(
    doc.image_bits_per_component(@syntax.pdf_dictionary([])),
    None,
  )
}
