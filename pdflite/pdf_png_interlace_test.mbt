///|
// Adam7 fixtures.
//
// Each picture below was written twice by an encoder outside this
// repository — once sequentially, once interlaced — and the pair was
// cross-checked with macOS ImageIO, which decodes both members to
// identical pixels. So the expected rasters are ground truth about the
// format rather than a restatement of what this code does; a shared
// misreading of the pass geometry could not make these pass.

///|
fn png_interlace_bytes_for_test(values : ArrayView[Int]) -> @core.PdfBytes {
  try! @core.pdf_bytes_of_int_array(values)
}

///|
/// 4x4 RGBA. Passes 2 and 3 are empty at this size, so it also covers a
/// gap in the middle of the pass sequence.
fn png_interlace_rgba_for_test() -> (
  @core.PdfBytes,
  @core.PdfBytes,
  @core.PdfBytes,
) {
  let interlaced = png_interlace_bytes_for_test([
    137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 4, 0,
    0, 0, 4, 8, 6, 0, 0, 1, 222, 246, 174, 232, 0, 0, 0, 74, 73, 68, 65, 84, 120,
    218, 13, 200, 65, 1, 192, 48, 8, 3, 64, 44, 212, 66, 36, 20, 11, 177, 50, 102,
    165, 149, 80, 55, 21, 192, 3, 9, 72, 192, 1, 219, 61, 79, 6, 180, 68, 113, 66,
    134, 157, 82, 235, 16, 192, 146, 240, 43, 48, 79, 190, 243, 202, 160, 21, 120,
    82, 233, 65, 246, 31, 203, 11, 171, 83, 247, 12, 238, 231, 126, 250, 213, 31,
    60, 4, 236, 155, 84, 0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130,
  ])
  let sequential = png_interlace_bytes_for_test([
    137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 4, 0,
    0, 0, 4, 8, 6, 0, 0, 0, 169, 241, 158, 126, 0, 0, 0, 72, 73, 68, 65, 84, 120,
    218, 13, 200, 65, 1, 0, 33, 8, 4, 64, 43, 88, 97, 35, 72, 133, 173, 114, 92,
    21, 141, 64, 27, 3, 240, 32, 2, 17, 104, 160, 206, 115, 90, 135, 20, 160, 41,
    176, 32, 124, 183, 78, 45, 208, 82, 232, 65, 158, 23, 106, 5, 245, 20, 61, 193,
    127, 188, 152, 94, 152, 39, 101, 141, 224, 250, 246, 5, 219, 223, 31, 60, 157,
    19, 215, 123, 0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130,
  ])
  let raster = png_interlace_bytes_for_test([
    17, 34, 51, 240, 34, 34, 102, 224, 51, 34, 153, 208, 68, 34, 204, 192, 17, 68,
    102, 240, 34, 68, 153, 224, 51, 68, 204, 208, 68, 68, 255, 192, 17, 102, 153,
    240, 34, 102, 204, 224, 51, 102, 255, 208, 68, 103, 50, 192, 17, 136, 204, 240,
    34, 136, 255, 224, 51, 137, 50, 208, 68, 137, 101, 192,
  ])
  (interlaced, sequential, raster)
}

///|
/// 5x5 one-bit greyscale: samples are packed below a byte, and a pass
/// packs from the left edge of its own scanline, so source and target bit
/// offsets are unrelated.
fn png_interlace_grey_for_test() -> (
  @core.PdfBytes,
  @core.PdfBytes,
  @core.PdfBytes,
) {
  let interlaced = png_interlace_bytes_for_test([
    137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 5, 0,
    0, 0, 5, 1, 0, 0, 0, 1, 210, 19, 43, 222, 0, 0, 0, 17, 73, 68, 65, 84, 120, 218,
    99, 96, 64, 2, 7, 192, 112, 5, 195, 10, 0, 18, 118, 3, 145, 174, 207, 100, 1,
    0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130,
  ])
  let sequential = png_interlace_bytes_for_test([
    137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 5, 0,
    0, 0, 5, 1, 0, 0, 0, 0, 165, 20, 27, 72, 0, 0, 0, 14, 73, 68, 65, 84, 120, 218,
    99, 8, 96, 88, 193, 0, 198, 0, 11, 74, 2, 65, 208, 159, 68, 194, 0, 0, 0, 0,
    73, 69, 78, 68, 174, 66, 96, 130,
  ])
  let raster = png_interlace_bytes_for_test([80, 168, 80, 168, 80])
  (interlaced, sequential, raster)
}

///|
/// 1x1 RGBA: only the first pass has any extent, so the other six must
/// contribute nothing rather than a stray scanline.
fn png_interlace_tiny_for_test() -> (@core.PdfBytes, @core.PdfBytes) {
  let interlaced = png_interlace_bytes_for_test([
    137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 1, 0,
    0, 0, 1, 8, 6, 0, 0, 1, 104, 18, 244, 31, 0, 0, 0, 13, 73, 68, 65, 84, 120, 218,
    99, 16, 84, 250, 224, 0, 0, 2, 207, 1, 100, 219, 152, 126, 86, 0, 0, 0, 0, 73,
    69, 78, 68, 174, 66, 96, 130,
  ])
  let raster = png_interlace_bytes_for_test([17, 34, 240, 64])
  (interlaced, raster)
}

///|
/// The pixels an IDAT stream carries, read back the way the PDF predictor
/// would read it.
fn png_interlace_raster_of_test(
  png : @pdflite.PdfPNG,
  colors : Int,
) -> @core.PdfBytes {
  try! @pdflite.pdf_decode_predictor(
    15,
    colors,
    png.bit_depth,
    png.width,
    try! @flate.pdf_flate_decode(png.idat),
  )
}

///|
test "pdf_read_png de-interlaces an Adam7 RGBA image" {
  let (interlaced, sequential, raster) = png_interlace_rgba_for_test()
  let png = try! @pdflite.pdf_read_png(interlaced)
  @test.assert_eq(png.width, 4)
  @test.assert_eq(png.height, 4)
  @test.assert_eq(png.bit_depth, 8)
  @test.assert_eq(png.color_type, 6)
  @test.assert_eq(png_interlace_raster_of_test(png, 4), raster)
  // Reading the interlaced file must be indistinguishable from reading the
  // sequential one: same pixels behind the same sequential contract.
  let plain = try! @pdflite.pdf_read_png(sequential)
  @test.assert_eq(png_interlace_raster_of_test(plain, 4), raster)
}

///|
test "pdf_read_png de-interlaces an Adam7 one-bit greyscale image" {
  let (interlaced, sequential, raster) = png_interlace_grey_for_test()
  let png = try! @pdflite.pdf_read_png(interlaced)
  @test.assert_eq(png.width, 5)
  @test.assert_eq(png.height, 5)
  @test.assert_eq(png.bit_depth, 1)
  @test.assert_eq(png.color_type, 0)
  @test.assert_eq(png_interlace_raster_of_test(png, 1), raster)
  let plain = try! @pdflite.pdf_read_png(sequential)
  @test.assert_eq(png_interlace_raster_of_test(plain, 1), raster)
}

///|
test "pdf_read_png de-interlaces an Adam7 image with six empty passes" {
  let (interlaced, raster) = png_interlace_tiny_for_test()
  let png = try! @pdflite.pdf_read_png(interlaced)
  @test.assert_eq(png.width, 1)
  @test.assert_eq(png.height, 1)
  @test.assert_eq(png_interlace_raster_of_test(png, 4), raster)
}

///|
test "pdf_image_object_of_png_data embeds an Adam7 image" {
  let (interlaced, _, raster) = png_interlace_rgba_for_test()
  let document = @pdflite.pdf_document_empty()
  let object = try! @pdflite.pdf_image_object_of_png_data(document, interlaced)
  guard object is PdfStreamObject(stream) else {
    fail("expected PNG stream object")
  }
  // Colour type 6 splits into colour and alpha, and that split runs over
  // the de-interlaced stream, so both halves must carry de-interlaced
  // pixels rather than pass-ordered ones.
  let colors : Array[Byte] = []
  let alpha : Array[Byte] = []
  for index in 0..<raster.length() {
    if index % 4 == 3 {
      alpha.push(raster[index])
    } else {
      colors.push(raster[index])
    }
  }
  guard stream.data is StreamGot(image_data) else {
    fail("expected materialized colour image data")
  }
  @test.assert_eq(
    try! @flate.pdf_flate_decode(image_data),
    Bytes::from_array(colors),
  )
  let smask_reference = try! image_lookup_for_test(stream.dictionary, "/SMask")
  guard smask_reference is PdfIndirect(smask_number) else {
    fail("expected alpha SMask reference")
  }
  let smask = document.lookup_object_or_null(smask_number)
  guard smask is PdfStreamObject(smask_stream) else {
    fail("expected SMask stream object")
  }
  guard smask_stream.data is StreamGot(mask_data) else {
    fail("expected materialized mask data")
  }
  @test.assert_eq(
    try! @flate.pdf_flate_decode(mask_data),
    Bytes::from_array(alpha),
  )
}

///|
test "pdf_read_png rejects a truncated Adam7 stream" {
  // An interlaced header with no image data at all: the pass geometry says
  // bytes are owed, and none arrive.
  let truncated : Result[@pdflite.PdfPNG, Error] = try
    @pdflite.pdf_read_png(image_png_for_test(4, 4, 8, 6, 1, []))
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard truncated is Err(@core.PdfError::BadPNG(_)) else {
    fail("expected truncated interlaced PNG to raise BadPNG")
  }
}

///|
test "pdf_read_png rejects an interlaced image too tall to size" {
  // 1 x (2^31 - 1) in a 33-byte file. Rounding each pass extent up by
  // adding the step first would wrap here, and every later guard would
  // then read a tiny image and go on to ask for a two-gigabyte raster.
  let huge : Result[@pdflite.PdfPNG, Error] = try
    @pdflite.pdf_read_png(image_png_for_test(1, 2147483647, 1, 0, 1, []))
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  // The message matters: any malformed PNG raises BadPNG somewhere, so
  // only naming the guard proves this one stopped it.
  guard huge is Err(@core.PdfError::BadPNG(message)) else {
    fail("expected an oversized interlaced PNG to raise BadPNG")
  }
  @test.assert_eq(message, "read_png: interlaced image too large")
}

///|
test "pdf_read_png rejects an interlaced image too wide to filter" {
  // 50,000,000 x 1 at 16-bit RGB: the byte count fits, but the bit
  // product the shared predictor helpers recompute in `Int` does not, and
  // a negative scanline width there yields an empty stream rather than an
  // error.
  let wide : Result[@pdflite.PdfPNG, Error] = try
    @pdflite.pdf_read_png(image_png_for_test(50000000, 1, 16, 2, 1, []))
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard wide is Err(@core.PdfError::BadPNG(message)) else {
    fail("expected an over-wide interlaced PNG to raise BadPNG")
  }
  @test.assert_eq(message, "read_png: interlaced scanline too wide")
}

///|
test "pdf_read_png rejects a bit depth its colour type forbids" {
  // Four-bit RGBA is not a PNG the format allows; only greyscale packs
  // samples below a byte.
  let bad : Result[@pdflite.PdfPNG, Error] = try
    @pdflite.pdf_read_png(image_png_for_test(4, 4, 4, 6, 1, []))
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard bad is Err(@core.PdfError::BadPNG(_)) else {
    fail("expected an invalid bit depth to raise BadPNG")
  }
}
