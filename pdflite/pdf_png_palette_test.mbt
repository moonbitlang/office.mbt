///|
// Palette (colour type 3) fixtures.
//
// Each picture was written twice by an encoder outside this repository —
// sequentially and Adam7-interlaced — and each pair cross-checked with
// macOS CoreGraphics, which decodes both members to identical pixels
// (and, for the 8-bit fixture, to exactly the palette entries at the
// expected indices). The expected index rasters are therefore ground
// truth about the format, not a restatement of what this code does.

///|
fn png_palette_bytes_for_test(values : ArrayView[Int]) -> @core.PdfBytes {
  try! @core.pdf_bytes_of_int_array(values)
}

///|
/// Assemble a PNG from explicit chunks, so tests can order PLTE, tRNS
/// and IDAT freely.
fn png_palette_file_for_test(
  width : Int,
  height : Int,
  bit_depth : Int,
  interlace : Int,
  chunks : ArrayView[(ArrayView[Int], @core.PdfBytes)],
) -> @core.PdfBytes {
  let output : Array[Byte] = []
  for value in [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A] {
    image_push_byte_for_test(output, value)
  }
  image_append_bytes_for_test(
    output,
    image_png_chunk_for_test(
      [0x49, 0x48, 0x44, 0x52],
      image_png_header_for_test(width, height, bit_depth, 3, interlace),
    ),
  )
  for pair in chunks {
    image_append_bytes_for_test(
      output,
      image_png_chunk_for_test(pair.0, pair.1),
    )
  }
  image_append_bytes_for_test(
    output,
    image_png_chunk_for_test([0x49, 0x45, 0x4E, 0x44], []),
  )
  Bytes::from_array(output)
}

///|
/// 4x2, 8-bit, five palette entries.
fn png_palette_p8_for_test() -> (
  @core.PdfBytes, // sequential file
  @core.PdfBytes, // interlaced file
  @core.PdfBytes, // PLTE payload
  @core.PdfBytes, // expected index raster
) {
  let sequential = png_palette_bytes_for_test([
    137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 4, 0,
    0, 0, 2, 8, 3, 0, 0, 0, 72, 118, 141, 81, 0, 0, 0, 15, 80, 76, 84, 69, 255, 0,
    0, 0, 255, 0, 0, 0, 255, 17, 34, 51, 200, 150, 100, 184, 61, 98, 173, 0, 0, 0,
    16, 73, 68, 65, 84, 120, 218, 99, 96, 96, 100, 98, 102, 96, 1, 146, 0, 0, 70,
    0, 14, 120, 179, 122, 228, 0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130,
  ])
  let interlaced = png_palette_bytes_for_test([
    137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 4, 0,
    0, 0, 2, 8, 3, 0, 0, 1, 63, 113, 189, 199, 0, 0, 0, 15, 80, 76, 84, 69, 255,
    0, 0, 0, 255, 0, 0, 0, 255, 17, 34, 51, 200, 150, 100, 184, 61, 98, 173, 0, 0,
    0, 20, 73, 68, 65, 84, 120, 218, 99, 96, 96, 96, 98, 96, 100, 102, 96, 97, 96,
    100, 2, 0, 0, 75, 0, 14, 94, 158, 243, 251, 0, 0, 0, 0, 73, 69, 78, 68, 174,
    66, 96, 130,
  ])
  let palette = png_palette_bytes_for_test([
    255, 0, 0, 0, 255, 0, 0, 0, 255, 17, 34, 51, 200, 150, 100,
  ])
  let raster = png_palette_bytes_for_test([0, 1, 2, 3, 4, 0, 1, 2])
  (sequential, interlaced, palette, raster)
}

///|
/// 5x5, 2-bit, four palette entries: indices pack below a byte.
fn png_palette_p2_for_test() -> (
  @core.PdfBytes,
  @core.PdfBytes,
  @core.PdfBytes,
  @core.PdfBytes,
) {
  let sequential = png_palette_bytes_for_test([
    137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 5, 0,
    0, 0, 5, 2, 3, 0, 0, 0, 240, 1, 206, 118, 0, 0, 0, 12, 80, 76, 84, 69, 0, 0,
    0, 255, 255, 255, 255, 0, 255, 0, 128, 64, 191, 69, 3, 237, 0, 0, 0, 23, 73,
    68, 65, 84, 120, 218, 99, 144, 102, 96, 200, 113, 96, 216, 216, 192, 112, 236,
    0, 131, 52, 3, 0, 24, 201, 3, 154, 9, 238, 10, 64, 0, 0, 0, 0, 73, 69, 78, 68,
    174, 66, 96, 130,
  ])
  let interlaced = png_palette_bytes_for_test([
    137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 5, 0,
    0, 0, 5, 2, 3, 0, 0, 1, 135, 6, 254, 224, 0, 0, 0, 12, 80, 76, 84, 69, 0, 0,
    0, 255, 255, 255, 255, 0, 255, 0, 128, 64, 191, 69, 3, 237, 0, 0, 0, 26, 73,
    68, 65, 84, 120, 218, 99, 96, 0, 131, 6, 32, 236, 96, 40, 96, 184, 0, 196, 57,
    14, 12, 199, 14, 0, 0, 43, 152, 5, 107, 6, 58, 148, 89, 0, 0, 0, 0, 73, 69, 78,
    68, 174, 66, 96, 130,
  ])
  let palette = png_palette_bytes_for_test([
    0, 0, 0, 255, 255, 255, 255, 0, 255, 0, 128, 64,
  ])
  let raster = png_palette_bytes_for_test([
    27, 0, 108, 64, 177, 128, 198, 192, 27, 0,
  ])
  (sequential, interlaced, palette, raster)
}

///|
test "pdf_read_png reads an 8-bit palette image, sequential and interlaced" {
  let (sequential, interlaced, palette, raster) = png_palette_p8_for_test()
  for file in [sequential, interlaced] {
    let png = try! @pdflite.pdf_read_png(file)
    @test.assert_eq(png.width, 4)
    @test.assert_eq(png.height, 2)
    @test.assert_eq(png.bit_depth, 8)
    @test.assert_eq(png.color_type, 3)
    @test.assert_eq(png.palette, Some(palette))
    // The IDAT decodes — under the same predictor contract the PDF will
    // declare — to the index raster, whichever way it arrived.
    @test.assert_eq(png_interlace_raster_of_test(png, 1), raster)
  }
}

///|
test "pdf_read_png reads a 2-bit palette image, sequential and interlaced" {
  let (sequential, interlaced, palette, raster) = png_palette_p2_for_test()
  for file in [sequential, interlaced] {
    let png = try! @pdflite.pdf_read_png(file)
    @test.assert_eq(png.width, 5)
    @test.assert_eq(png.height, 5)
    @test.assert_eq(png.bit_depth, 2)
    @test.assert_eq(png.color_type, 3)
    @test.assert_eq(png.palette, Some(palette))
    @test.assert_eq(png_interlace_raster_of_test(png, 1), raster)
  }
}

///|
test "pdf_image_object_of_png_data embeds a palette image as /Indexed" {
  let (sequential, _, palette, raster) = png_palette_p8_for_test()
  let document = @pdflite.pdf_document_empty()
  let object = try! @pdflite.pdf_image_object_of_png_data(document, sequential)
  guard object is PdfStreamObject(stream) else {
    fail("expected PNG stream object")
  }
  // The palette maps onto PDF's native indexed colour space; hival is
  // entries - 1.
  @test.assert_eq(
    try! image_lookup_for_test(stream.dictionary, "/ColorSpace"),
    PdfArray([
      PdfNameObject(image_name_for_test("/Indexed")),
      PdfNameObject(image_name_for_test("/DeviceRGB")),
      PdfInteger(4),
      PdfString(palette),
    ]),
  )
  @test.assert_eq(
    try! image_lookup_for_test(stream.dictionary, "/BitsPerComponent"),
    PdfInteger(8),
  )
  // The predictor runs over the index stream: one component.
  let parms = try! image_lookup_for_test(stream.dictionary, "/DecodeParms")
  @test.assert_eq(try! image_lookup_for_test(parms, "/Colors"), PdfInteger(1))
  // No alpha channel, so no /SMask.
  @test.assert_eq(
    stream.dictionary.lookup_immediate(image_name_for_test("/SMask")),
    None,
  )
  // And the passthrough is intact: the embedded stream is the source's
  // own compressed IDAT, still decoding to the index raster.
  guard stream.data is StreamGot(payload) else {
    fail("expected materialized image data")
  }
  let png = try! @pdflite.pdf_read_png(sequential)
  @test.assert_eq(payload, png.idat)
  @test.assert_eq(
    try! @pdflite.pdf_decode_predictor(
      15,
      1,
      8,
      4,
      try! @flate.pdf_flate_decode(payload),
    ),
    raster,
  )
}

///|
test "pdf_read_png rejects palette transparency rather than dropping it" {
  // tRNS on a palette image names per-entry alpha. Embedding without it
  // would draw the image opaque — quietly wrong — so the reader refuses
  // and the caller reports the image unreadable.
  let (_, _, palette, _) = png_palette_p8_for_test()
  let file = png_palette_file_for_test(4, 2, 8, 0, [
    ([0x50, 0x4C, 0x54, 0x45], palette),
    ([0x74, 0x52, 0x4E, 0x53], png_palette_bytes_for_test([128])),
    ([0x49, 0x44, 0x41, 0x54], @flate.pdf_flate_encode(b"\x00\x00\x00\x00\x00")),
  ])
  let refused : Result[@pdflite.PdfPNG, Error] = try
    @pdflite.pdf_read_png(file)
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard refused is Err(@core.PdfError::BadPNG(message)) else {
    fail("expected palette transparency to raise BadPNG")
  }
  @test.assert_eq(message, "read_png: palette transparency not supported")
}

///|
test "pdf_read_png rejects a malformed or oversized PLTE" {
  // Four bytes is not a whole number of RGB triples.
  let ragged = png_palette_file_for_test(1, 1, 8, 0, [
    ([0x50, 0x4C, 0x54, 0x45], png_palette_bytes_for_test([1, 2, 3, 4])),
    ([0x49, 0x44, 0x41, 0x54], @flate.pdf_flate_encode(b"\x00\x00")),
  ])
  let bad : Result[@pdflite.PdfPNG, Error] = try
    @pdflite.pdf_read_png(ragged)
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard bad is Err(@core.PdfError::BadPNG(message)) else {
    fail("expected a ragged PLTE to raise BadPNG")
  }
  @test.assert_eq(message, "read_png: malformed palette of 4 bytes")
}

///|
test "pdf_read_png rejects a 16-bit palette image" {
  // Indices cap at one byte in PNG, and /Indexed caps at 8 bits in PDF.
  // Without this check the sequential passthrough — which historically
  // validates no depths — would emit a PDF the format forbids.
  let (_, _, palette, _) = png_palette_p8_for_test()
  let deep = png_palette_file_for_test(1, 1, 16, 0, [
    ([0x50, 0x4C, 0x54, 0x45], palette),
    ([0x49, 0x44, 0x41, 0x54], @flate.pdf_flate_encode(b"\x00\x00\x00")),
  ])
  let bad : Result[@pdflite.PdfPNG, Error] = try
    @pdflite.pdf_read_png(deep)
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard bad is Err(@core.PdfError::BadPNG(message)) else {
    fail("expected a 16-bit palette image to raise BadPNG")
  }
  @test.assert_eq(message, "read_png: bit depth 16 invalid for a palette image")
}
