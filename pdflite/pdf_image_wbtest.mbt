// Whitebox tests for image decode internals.
// Public image behavior belongs in `_test.mbt` files.

///|
test "private image decode helpers cover scalar edge behavior" {
  @test.assert_eq(pdf_image_decode_is_identity([]), true)
  let odd_decode : Result[Bool, Error] = try
    pdf_image_decode_is_identity([0.0])
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard odd_decode is Err(@core.PdfError::FilterExpected) else {
    fail("expected malformed decode values")
  }

  @test.assert_eq(pdf_image_decode_interpolate(0.0, 1.0, 1, 1), 1)
  @test.assert_eq(pdf_image_decode_interpolate(0.0, 3.0, 3, 2), 3)
  @test.assert_eq(pdf_image_decode_interpolate(0.0, 15.0, 15, 4), 15)
  @test.assert_eq(pdf_image_decode_interpolate(0.0, 1.0, 65535, 16), 1)
  @test.assert_eq(pdf_image_decode_interpolate(0.0, 2.0, 1, 7), 2)

  let sample = try! @core.pdf_bytes_of_int_array([7])
  @test.assert_eq(
    try! pdf_image_apply_decode(sample, Some(16), Some([1.0, 0.0])),
    sample,
  )
  let missing_bpc : Result[@core.PdfBytes, Error] = try
    pdf_image_apply_decode(sample, None, Some([1.0, 0.0]))
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard missing_bpc is Err(@core.PdfError::FilterExpected) else {
    fail("expected missing bpc for non-identity decode")
  }

  let wrapped = try! @core.pdf_bytes_of_int_array([153, 170, 0, 255, 136])
  @test.assert_eq(
    try! pdf_image_apply_decode_borrowed(
      wrapped[1:2],
      Some(1),
      Some([1.0, 0.0]),
    ),
    try! @core.pdf_bytes_of_int_array([85]),
  )
  @test.assert_eq(
    try! pdf_image_apply_decode_borrowed(
      wrapped[2:4],
      Some(8),
      Some([1.0, 0.0]),
    ),
    try! @core.pdf_bytes_of_int_array([1, 0]),
  )
  @test.assert_eq(
    try! pdf_image_apply_decode_borrowed(
      wrapped[2:4],
      Some(2),
      Some([1.0, 0.0]),
    ),
    try! @core.pdf_bytes_of_int_array([0, 255]),
  )
  @test.assert_eq(
    try! pdf_image_apply_decode_borrowed(wrapped[2:4], Some(8), None),
    try! @core.pdf_bytes_of_int_array([0, 255]),
  )
  @test.assert_eq(
    try! pdf_image_apply_decode_borrowed(
      wrapped[2:4],
      Some(8),
      Some([0.0, 1.0]),
    ),
    try! @core.pdf_bytes_of_int_array([0, 255]),
  )
  let borrowed_missing_bpc : Result[@core.PdfBytes, Error] = try
    pdf_image_apply_decode_borrowed(wrapped[2:4], None, Some([1.0, 0.0]))
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard borrowed_missing_bpc is Err(@core.PdfError::FilterExpected) else {
    fail("expected borrowed missing bpc for non-identity decode")
  }

  let doc = pdf_document_empty()
  let rgb_wrapped = try! @core.pdf_bytes_of_int_array([9, 1, 2, 3, 4, 5, 6, 9])
  @test.assert_eq(
    doc.pdf_image_raw_colour_space_as_rgb24(
      2,
      1,
      PdfDeviceRGB,
      Some(8),
      rgb_wrapped[1:7],
    ),
    try! @core.pdf_bytes_of_int_array([1, 2, 3, 4, 5, 6]),
  )
  let unsupported_indexed = PdfIndexed(PdfDeviceGray, [(0, [7])])
  let unsupported8 : Result[@core.PdfBytes, Error] = try
    doc.pdf_image_raw_colour_space_as_rgb24(
      1,
      1,
      unsupported_indexed,
      Some(8),
      sample,
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard unsupported8 is Err(@core.PdfError::FilterExpected) else {
    fail("expected unsupported indexed 8bpp base")
  }
  let unsupported4 : Result[@core.PdfBytes, Error] = try
    doc.pdf_image_raw_colour_space_as_rgb24(
      1,
      1,
      unsupported_indexed,
      Some(4),
      sample,
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard unsupported4 is Err(@core.PdfError::FilterExpected) else {
    fail("expected unsupported indexed 4bpp base")
  }
  let unsupported2 : Result[@core.PdfBytes, Error] = try
    doc.pdf_image_raw_colour_space_as_rgb24(
      1,
      1,
      unsupported_indexed,
      Some(2),
      sample,
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard unsupported2 is Err(@core.PdfError::FilterExpected) else {
    fail("expected unsupported indexed 2bpp base")
  }
  let unsupported1 : Result[@core.PdfBytes, Error] = try
    doc.pdf_image_raw_colour_space_as_rgb24(
      1,
      1,
      unsupported_indexed,
      Some(1),
      sample,
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard unsupported1 is Err(@core.PdfError::FilterExpected) else {
    fail("expected unsupported indexed 1bpp base")
  }

  let filters : Array[@syntax.PdfObject] = []
  for _ in 0..<1025 {
    filters.push(PdfNameObject(@core.pdf_name_of_bytes(b"/Crypt")))
  }
  let too_many_stages = @syntax.pdf_stream(
    @syntax.pdf_dictionary([
      (@core.pdf_name_of_bytes(b"/Length"), PdfInteger(sample.length())),
      (@core.pdf_name_of_bytes(b"/Filter"), PdfArray(filters)),
    ]),
    StreamGot(sample),
  )
  let stage_limit : Result[PdfImageDecodedStream, Error] = try
    doc.pdf_image_decode_to_image(too_many_stages)
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard stage_limit is Err(@core.PdfError::FilterExpected) else {
    fail("expected image decode stage limit")
  }

  @test.assert_eq(pdf_image_clamp_unit(2.0), 1.0)
  @test.assert_eq(pdf_image_clamp_unit(-1.0), 0.0)
  @test.assert_eq(pdf_image_lab_g(1.0), 1.0)
}
