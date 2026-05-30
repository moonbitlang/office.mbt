///|
fn image_extract_name_for_test(text : String) -> @core.PdfName {
  @core.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn image_extract_bytes_for_test(values : ArrayView[Int]) -> @core.PdfBytes {
  try! @core.pdf_bytes_of_int_array(values)
}

///|
fn image_extract_append_bytes_for_test(
  output : Array[Byte],
  bytes : BytesView,
) -> Unit {
  for index in 0..<bytes.length() {
    output.push(bytes[index])
  }
}

///|
test "PdfDocument extract_single_image_files emits cpdf payload names" {
  let doc = @pdflite.pdf_document_empty()
  let mask_data = image_extract_bytes_for_test([128])
  doc.add_object_given_number(
    11,
    @syntax.pdf_stream(
      @syntax.pdf_dictionary([
        (image_extract_name_for_test("/Width"), PdfInteger(1)),
        (image_extract_name_for_test("/Height"), PdfInteger(1)),
        (
          image_extract_name_for_test("/ColorSpace"),
          PdfNameObject(image_extract_name_for_test("/DeviceGray")),
        ),
        (image_extract_name_for_test("/BitsPerComponent"), PdfInteger(8)),
      ]),
      StreamGot(mask_data),
    ),
  )
  let image_data = image_extract_bytes_for_test([1, 2, 3, 4, 5, 6])
  doc.add_object_given_number(
    10,
    @syntax.pdf_stream(
      @syntax.pdf_dictionary([
        (image_extract_name_for_test("/Width"), PdfInteger(2)),
        (image_extract_name_for_test("/Height"), PdfInteger(1)),
        (
          image_extract_name_for_test("/ColorSpace"),
          PdfNameObject(image_extract_name_for_test("/DeviceRGB")),
        ),
        (image_extract_name_for_test("/BitsPerComponent"), PdfInteger(8)),
        (image_extract_name_for_test("/SMask"), PdfIndirect(11)),
      ]),
      StreamGot(image_data),
    ),
  )
  let files = try! doc.extract_single_image_files(10, "extract/out")
  @test.assert_eq(
    try! @pdflite.pdf_image_extract_single_image_files(doc, 10, "extract/out"),
    files,
  )
  @test.assert_eq(files.length(), 2)
  @test.assert_eq(files[0].path, "extract/out.pnm")
  let expected_image : Array[Byte] = []
  image_extract_append_bytes_for_test(
    expected_image,
    @ascii.encode("P6 2 1 255\n"),
  )
  image_extract_append_bytes_for_test(expected_image, image_data)
  @test.assert_eq(files[0].data, Bytes::from_array(expected_image))
  @test.assert_eq(files[1].path, "extract/out-smask.pnm")
  let expected_mask : Array[Byte] = []
  image_extract_append_bytes_for_test(
    expected_mask,
    @ascii.encode("P6 1 1 255\n"),
  )
  image_extract_append_bytes_for_test(
    expected_mask,
    image_extract_bytes_for_test([128, 128, 128]),
  )
  @test.assert_eq(files[1].data, Bytes::from_array(expected_mask))
}

///|
test "PdfDocument extract_single_image_files preserves encoded image streams" {
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(
    20,
    @syntax.pdf_stream(
      @syntax.pdf_dictionary([
        (image_extract_name_for_test("/Width"), PdfInteger(1)),
        (image_extract_name_for_test("/Height"), PdfInteger(1)),
        (
          image_extract_name_for_test("/Filter"),
          PdfNameObject(image_extract_name_for_test("/DCTDecode")),
        ),
      ]),
      StreamGot(@ascii.encode("jpg")),
    ),
  )
  @test.assert_eq(try! doc.extract_single_image_files(20, "one"), [
    { path: "one.jpg", data: @ascii.encode("jpg") },
  ])

  doc.add_object_given_number(
    30,
    @syntax.pdf_stream(
      @syntax.pdf_dictionary([
        (image_extract_name_for_test("/Length"), PdfInteger(7)),
      ]),
      StreamGot(@ascii.encode("globals")),
    ),
  )
  doc.add_object_given_number(
    31,
    @syntax.pdf_stream(
      @syntax.pdf_dictionary([
        (image_extract_name_for_test("/Width"), PdfInteger(1)),
        (image_extract_name_for_test("/Height"), PdfInteger(1)),
        (
          image_extract_name_for_test("/Filter"),
          PdfNameObject(image_extract_name_for_test("/JBIG2Decode")),
        ),
        (
          image_extract_name_for_test("/DecodeParms"),
          @syntax.pdf_dictionary([
            (image_extract_name_for_test("/JBIG2Globals"), PdfIndirect(30)),
          ]),
        ),
      ]),
      StreamGot(@ascii.encode("jbig")),
    ),
  )
  @test.assert_eq(try! doc.extract_single_image_files(31, "dir/image"), [
    { path: "dir/1.jbig2global", data: @ascii.encode("globals") },
    { path: "dir/image.jbig2__1", data: @ascii.encode("jbig") },
  ])
}

///|
test "PdfDocument extract_images_files walks page images masks and form images in cpdf order" {
  let doc = @pdflite.pdf_document_empty()
  let mask_data = image_extract_bytes_for_test([128])
  doc.add_object_given_number(
    11,
    @syntax.pdf_stream(
      @syntax.pdf_dictionary([
        (
          image_extract_name_for_test("/Subtype"),
          PdfNameObject(image_extract_name_for_test("/Image")),
        ),
        (image_extract_name_for_test("/Width"), PdfInteger(1)),
        (image_extract_name_for_test("/Height"), PdfInteger(1)),
        (
          image_extract_name_for_test("/ColorSpace"),
          PdfNameObject(image_extract_name_for_test("/DeviceGray")),
        ),
        (image_extract_name_for_test("/BitsPerComponent"), PdfInteger(8)),
        (image_extract_name_for_test("/Length"), PdfInteger(mask_data.length())),
      ]),
      StreamGot(mask_data),
    ),
  )
  let image_data = image_extract_bytes_for_test([1, 2, 3])
  doc.add_object_given_number(
    10,
    @syntax.pdf_stream(
      @syntax.pdf_dictionary([
        (
          image_extract_name_for_test("/Subtype"),
          PdfNameObject(image_extract_name_for_test("/Image")),
        ),
        (image_extract_name_for_test("/Width"), PdfInteger(1)),
        (image_extract_name_for_test("/Height"), PdfInteger(1)),
        (
          image_extract_name_for_test("/ColorSpace"),
          PdfNameObject(image_extract_name_for_test("/DeviceRGB")),
        ),
        (image_extract_name_for_test("/BitsPerComponent"), PdfInteger(8)),
        (image_extract_name_for_test("/SMask"), PdfIndirect(11)),
        (
          image_extract_name_for_test("/Length"),
          PdfInteger(image_data.length()),
        ),
      ]),
      StreamGot(image_data),
    ),
  )
  let second_mask_data = image_extract_bytes_for_test([64])
  doc.add_object_given_number(
    14,
    @syntax.pdf_stream(
      @syntax.pdf_dictionary([
        (
          image_extract_name_for_test("/Subtype"),
          PdfNameObject(image_extract_name_for_test("/Image")),
        ),
        (image_extract_name_for_test("/Width"), PdfInteger(1)),
        (image_extract_name_for_test("/Height"), PdfInteger(1)),
        (
          image_extract_name_for_test("/ColorSpace"),
          PdfNameObject(image_extract_name_for_test("/DeviceGray")),
        ),
        (image_extract_name_for_test("/BitsPerComponent"), PdfInteger(8)),
        (
          image_extract_name_for_test("/Length"),
          PdfInteger(second_mask_data.length()),
        ),
      ]),
      StreamGot(second_mask_data),
    ),
  )
  let second_jpeg_data = @ascii.encode("jpg2")
  doc.add_object_given_number(
    13,
    @syntax.pdf_stream(
      @syntax.pdf_dictionary([
        (
          image_extract_name_for_test("/Subtype"),
          PdfNameObject(image_extract_name_for_test("/Image")),
        ),
        (image_extract_name_for_test("/Width"), PdfInteger(1)),
        (image_extract_name_for_test("/Height"), PdfInteger(1)),
        (
          image_extract_name_for_test("/Filter"),
          PdfNameObject(image_extract_name_for_test("/DCTDecode")),
        ),
        (image_extract_name_for_test("/SMask"), PdfIndirect(14)),
        (
          image_extract_name_for_test("/Length"),
          PdfInteger(second_jpeg_data.length()),
        ),
      ]),
      StreamGot(second_jpeg_data),
    ),
  )
  let jpeg_data = @ascii.encode("jpg")
  doc.add_object_given_number(
    12,
    @syntax.pdf_stream(
      @syntax.pdf_dictionary([
        (
          image_extract_name_for_test("/Subtype"),
          PdfNameObject(image_extract_name_for_test("/Image")),
        ),
        (image_extract_name_for_test("/Width"), PdfInteger(1)),
        (image_extract_name_for_test("/Height"), PdfInteger(1)),
        (
          image_extract_name_for_test("/Filter"),
          PdfNameObject(image_extract_name_for_test("/DCTDecode")),
        ),
        (image_extract_name_for_test("/Length"), PdfInteger(jpeg_data.length())),
      ]),
      StreamGot(jpeg_data),
    ),
  )
  doc.add_object_given_number(
    20,
    @syntax.pdf_stream(
      @syntax.pdf_dictionary([
        (
          image_extract_name_for_test("/Subtype"),
          PdfNameObject(image_extract_name_for_test("/Form")),
        ),
        (
          image_extract_name_for_test("/Resources"),
          @syntax.pdf_dictionary([
            (
              image_extract_name_for_test("/XObject"),
              @syntax.pdf_dictionary([
                (image_extract_name_for_test("/FmIm"), PdfIndirect(12)),
              ]),
            ),
          ]),
        ),
        (image_extract_name_for_test("/Length"), PdfInteger(0)),
      ]),
      StreamGot([]),
    ),
  )
  let page = {
    ..@page.pdf_page_blank(@geometry.paper_a4),
    resources: @syntax.pdf_dictionary([
      (
        image_extract_name_for_test("/XObject"),
        @syntax.pdf_dictionary([
          (image_extract_name_for_test("/ImA"), PdfIndirect(10)),
          (image_extract_name_for_test("/ImB"), PdfIndirect(13)),
          (image_extract_name_for_test("/Fm"), PdfIndirect(20)),
        ]),
      ),
    ]),
  }
  let page_root = try! doc.add_pagetree([page])
  ignore(try! doc.add_root(page_root, []))

  let files = try! doc.extract_images_files([1], "img-%%")
  @test.assert_eq(
    try! @pdflite.pdf_image_extract_images_files(
      false,
      PdfMetadataUTF8,
      false,
      false,
      doc,
      [1],
      "img-%%",
    ),
    files,
  )
  let expected_image : Array[Byte] = []
  image_extract_append_bytes_for_test(
    expected_image,
    @ascii.encode("P6 1 1 255\n"),
  )
  image_extract_append_bytes_for_test(expected_image, image_data)
  let expected_mask : Array[Byte] = []
  image_extract_append_bytes_for_test(
    expected_mask,
    @ascii.encode("P6 1 1 255\n"),
  )
  image_extract_append_bytes_for_test(
    expected_mask,
    image_extract_bytes_for_test([128, 128, 128]),
  )
  let expected_second_mask : Array[Byte] = []
  image_extract_append_bytes_for_test(
    expected_second_mask,
    @ascii.encode("P6 1 1 255\n"),
  )
  image_extract_append_bytes_for_test(
    expected_second_mask,
    image_extract_bytes_for_test([64, 64, 64]),
  )
  @test.assert_eq(files, [
    { path: "img-00-p1.pnm", data: Bytes::from_array(expected_image) },
    { path: "img-01-p1.jpg", data: second_jpeg_data },
    {
      path: "img-02-smask-p1.pnm",
      data: Bytes::from_array(expected_second_mask),
    },
    { path: "img-03-smask-p1.pnm", data: Bytes::from_array(expected_mask) },
    { path: "img-04-p1.jpg", data: jpeg_data },
  ])
}

///|
test "PdfDocument extract_images_files honors global and per-page dedup" {
  let doc = @pdflite.pdf_document_empty()
  let jpeg_data = @ascii.encode("jpg")
  doc.add_object_given_number(
    10,
    @syntax.pdf_stream(
      @syntax.pdf_dictionary([
        (
          image_extract_name_for_test("/Subtype"),
          PdfNameObject(image_extract_name_for_test("/Image")),
        ),
        (image_extract_name_for_test("/Width"), PdfInteger(1)),
        (image_extract_name_for_test("/Height"), PdfInteger(1)),
        (
          image_extract_name_for_test("/Filter"),
          PdfNameObject(image_extract_name_for_test("/DCTDecode")),
        ),
        (image_extract_name_for_test("/Length"), PdfInteger(jpeg_data.length())),
      ]),
      StreamGot(jpeg_data),
    ),
  )
  let page_one = {
    ..@page.pdf_page_blank(@geometry.paper_a4),
    resources: @syntax.pdf_dictionary([
      (
        image_extract_name_for_test("/XObject"),
        @syntax.pdf_dictionary([
          (image_extract_name_for_test("/A"), PdfIndirect(10)),
          (image_extract_name_for_test("/B"), PdfIndirect(10)),
        ]),
      ),
    ]),
  }
  let page_two = {
    ..@page.pdf_page_blank(@geometry.paper_a4),
    resources: @syntax.pdf_dictionary([
      (
        image_extract_name_for_test("/XObject"),
        @syntax.pdf_dictionary([
          (image_extract_name_for_test("/A"), PdfIndirect(10)),
        ]),
      ),
    ]),
  }
  let page_root = try! doc.add_pagetree([page_one, page_two])
  ignore(try! doc.add_root(page_root, []))

  @test.assert_eq(try! doc.extract_images_files([1, 2], "dup-%"), [
    { path: "dup-0-p1.jpg", data: jpeg_data },
    { path: "dup-1-p1.jpg", data: jpeg_data },
    { path: "dup-2-p2.jpg", data: jpeg_data },
  ])
  @test.assert_eq(try! doc.extract_images_files([1, 2], "dup-%", dedup=true), [
    { path: "dup-0-p1.jpg", data: jpeg_data },
  ])
  @test.assert_eq(
    try! doc.extract_images_files([1, 2], "dup-%", dedup_per_page=true),
    [
      { path: "dup-0-p1.jpg", data: jpeg_data },
      { path: "dup-1-p2.jpg", data: jpeg_data },
    ],
  )
  @test.assert_eq(try! doc.extract_images_files([2], "sel-%"), [
    { path: "sel-0-p1.jpg", data: jpeg_data },
  ])
}

///|
test "PdfDocument extract_images_files expands object number stem marker" {
  let doc = @pdflite.pdf_document_empty()
  let jpeg_data = @ascii.encode("jpg")
  doc.add_object_given_number(
    10,
    @syntax.pdf_stream(
      @syntax.pdf_dictionary([
        (
          image_extract_name_for_test("/Subtype"),
          PdfNameObject(image_extract_name_for_test("/Image")),
        ),
        (image_extract_name_for_test("/Width"), PdfInteger(1)),
        (image_extract_name_for_test("/Height"), PdfInteger(1)),
        (
          image_extract_name_for_test("/Filter"),
          PdfNameObject(image_extract_name_for_test("/DCTDecode")),
        ),
        (image_extract_name_for_test("/Length"), PdfInteger(jpeg_data.length())),
      ]),
      StreamGot(jpeg_data),
    ),
  )
  let page = {
    ..@page.pdf_page_blank(@geometry.paper_a4),
    resources: @syntax.pdf_dictionary([
      (
        image_extract_name_for_test("/XObject"),
        @syntax.pdf_dictionary([
          (image_extract_name_for_test("/A"), PdfIndirect(10)),
        ]),
      ),
    ]),
  }
  let page_root = try! doc.add_pagetree([page])
  ignore(try! doc.add_root(page_root, []))
  @test.assert_eq(try! doc.extract_images_files([1], "obj-%objnum@-%"), [
    { path: "obj-10-0-p1.jpg", data: jpeg_data },
  ])
}

///|
test "PdfDocument extract_images_files optionally emits inline images" {
  let doc = @pdflite.pdf_document_empty()
  let inline_dict = @syntax.pdf_dictionary([
    (image_extract_name_for_test("/W"), PdfInteger(1)),
    (image_extract_name_for_test("/H"), PdfInteger(1)),
    (image_extract_name_for_test("/BPC"), PdfInteger(8)),
    (
      image_extract_name_for_test("/CS"),
      PdfNameObject(image_extract_name_for_test("/RGB")),
    ),
  ])
  let inline_data = image_extract_bytes_for_test([7, 8, 9])
  let page = {
    ..@page.pdf_page_blank(@geometry.paper_a4),
    content: [
      try! @pdflite.pdf_content_stream_of_ops([
        Op_InlineImage(inline_dict, None, inline_data),
      ]),
    ],
  }
  let page_root = try! doc.add_pagetree([page])
  ignore(try! doc.add_root(page_root, []))

  @test.assert_eq(try! doc.extract_images_files([1], "ii-%"), [])
  let expected : Array[Byte] = []
  image_extract_append_bytes_for_test(expected, @ascii.encode("P6 1 1 255\n"))
  image_extract_append_bytes_for_test(expected, inline_data)
  @test.assert_eq(try! doc.extract_images_files([1], "ii-%", inline=true), [
    { path: "ii-0-p1-inline.pnm", data: Bytes::from_array(expected) },
  ])
}
