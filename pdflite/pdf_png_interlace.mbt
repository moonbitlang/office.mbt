///|
// Adam7 de-interlacing.
//
// `PdfPNG` hands its IDAT bytes straight to a PDF `FlateDecode` stream
// with a PNG predictor, and that predictor only understands sequential
// scanlines — which is precisely why an interlaced image cannot take the
// passthrough. So an interlaced source is rebuilt into the datastream the
// same image would have carried with `interlace = 0`: inflate, de-filter
// each of the seven passes independently, compose the flat raster, then
// re-filter and re-deflate. Every downstream path (the predictor
// passthrough and the alpha split) then works unchanged.

///|
/// Adam7 pass geometry, indexed by pass: first row and column each pass
/// contributes, then the row and column strides between its samples.
let pdf_png_adam7_start_row : Array[Int] = [0, 0, 4, 0, 2, 0, 1]

///|
let pdf_png_adam7_start_col : Array[Int] = [0, 4, 0, 2, 0, 1, 0]

///|
let pdf_png_adam7_row_step : Array[Int] = [8, 8, 8, 4, 4, 2, 2]

///|
let pdf_png_adam7_col_step : Array[Int] = [8, 8, 4, 4, 2, 2, 1]

///|
/// Samples per pixel, counting alpha. Distinct from
/// `pdf_image_png_components`, which reports the *colour* components a PDF
/// colour space names and so omits the alpha channel.
fn pdf_png_channels(color_type : Int) -> Int raise @core.PdfError {
  match color_type {
    0 => 1
    2 => 3
    4 => 2
    6 => 4
    _ => raise BadPNG("read_png: unknown colour type")
  }
}

///|
/// Reject bit depths the colour type does not allow. Only the interlaced
/// path needs this: it computes pass geometry from the depth, where a
/// bogus value would silently produce a mis-shaped raster rather than an
/// error.
fn pdf_png_check_bit_depth(
  color_type : Int,
  bit_depth : Int,
) -> Unit raise @core.PdfError {
  let allowed = match bit_depth {
    8 | 16 => true
    // Only greyscale without alpha packs samples below a byte; every other
    // colour type starts at 8 bits per sample.
    1 | 2 | 4 => color_type == 0
    _ => false
  }
  if !allowed {
    raise BadPNG(
      "read_png: bit depth " +
      bit_depth.to_string() +
      " invalid for colour type " +
      color_type.to_string(),
    )
  }
}

///|
/// How many rows (or columns) a pass covers, given the full extent, the
/// offset of its first sample, and its stride.
fn pdf_png_adam7_extent(full : Int, start : Int, step : Int) -> Int {
  if full > start {
    (full - start + step - 1) / step
  } else {
    0
  }
}

///|
/// Bytes one scanline of `columns` pixels occupies, computed in 64-bit so a
/// hostile IHDR overflows into an error rather than a small positive size.
fn pdf_png_stride(
  columns : Int,
  bits_per_pixel : Int,
) -> Int raise @core.PdfError {
  let bits = columns.to_int64() * bits_per_pixel.to_int64()
  let bytes = (bits + 7L) / 8L
  if bytes > pdf_png_max_int64 {
    raise BadPNG("read_png: interlaced scanline too wide")
  }
  bytes.to_int()
}

///|
/// Scatter one de-filtered pass into the flat raster.
fn pdf_png_place_pass(
  raster : Array[Byte],
  full_stride : Int,
  bits_per_pixel : Int,
  pass : @core.PdfBytes,
  pass_stride : Int,
  pass_width : Int,
  pass_height : Int,
  start_row : Int,
  start_col : Int,
  row_step : Int,
  col_step : Int,
) -> Unit {
  if bits_per_pixel % 8 == 0 {
    let pixel_bytes = bits_per_pixel / 8
    for row in 0..<pass_height {
      let source_row = row * pass_stride
      let target_row = (start_row + row * row_step) * full_stride
      for column in 0..<pass_width {
        let source = source_row + column * pixel_bytes
        let target = target_row + (start_col + column * col_step) * pixel_bytes
        for offset in 0..<pixel_bytes {
          raster[target + offset] = pass[source + offset]
        }
      }
    }
  } else {
    // Sub-byte depths: each pass packs its own samples from the left edge
    // of its own scanline, so source and target bit offsets are unrelated.
    let per_byte = 8 / bits_per_pixel
    let mask = (1 << bits_per_pixel) - 1
    for row in 0..<pass_height {
      let source_row = row * pass_stride
      let target_row = (start_row + row * row_step) * full_stride
      for column in 0..<pass_width {
        let source_shift = 8 - bits_per_pixel * (column % per_byte + 1)
        let sample = (
            pass[source_row + column / per_byte].to_int() >> source_shift
          ) &
          mask
        let target_column = start_col + column * col_step
        let target_shift = 8 - bits_per_pixel * (target_column % per_byte + 1)
        let target = target_row + target_column / per_byte
        raster[target] = (raster[target].to_int() | (sample << target_shift)).to_byte()
      }
    }
  }
}

///|
/// Rebuild an Adam7-interlaced IDAT stream as the non-interlaced IDAT
/// stream for the same image.
fn pdf_png_deinterlace(
  width : Int,
  height : Int,
  bit_depth : Int,
  color_type : Int,
  idat : @core.PdfBytes,
) -> @core.PdfBytes raise @core.PdfError {
  if width <= 0 || height <= 0 {
    raise BadPNG("read_png: interlaced image has no pixels")
  }
  pdf_png_check_bit_depth(color_type, bit_depth)
  let channels = pdf_png_channels(color_type)
  let bits_per_pixel = channels * bit_depth
  let full_stride = pdf_png_stride(width, bits_per_pixel)
  let raster_length = full_stride.to_int64() * height.to_int64()
  if raster_length > pdf_png_max_int64 {
    raise BadPNG("read_png: interlaced image too large")
  }

  // Pass geometry first, so the filtered length is known before anything
  // is allocated from it.
  let pass_widths = Array::make(7, 0)
  let pass_heights = Array::make(7, 0)
  let pass_strides = Array::make(7, 0)
  let mut filtered_length = 0L
  for pass in 0..<7 {
    let pass_width = pdf_png_adam7_extent(
      width,
      pdf_png_adam7_start_col[pass],
      pdf_png_adam7_col_step[pass],
    )
    let pass_height = pdf_png_adam7_extent(
      height,
      pdf_png_adam7_start_row[pass],
      pdf_png_adam7_row_step[pass],
    )
    pass_widths[pass] = pass_width
    pass_heights[pass] = pass_height
    if pass_width == 0 || pass_height == 0 {
      continue
    }
    let pass_stride = pdf_png_stride(pass_width, bits_per_pixel)
    pass_strides[pass] = pass_stride
    filtered_length += pass_height.to_int64() * (pass_stride.to_int64() + 1L)
    if filtered_length > pdf_png_max_int64 {
      raise BadPNG("read_png: interlaced image too large")
    }
  }
  let filtered = @flate.pdf_flate_decode(idat)
  if filtered.length().to_int64() < filtered_length {
    raise BadPNG("read_png: truncated interlaced image data")
  }
  let raster = Array::make(raster_length.to_int(), b'\x00')
  let mut offset = 0
  for pass in 0..<7 {
    let pass_width = pass_widths[pass]
    let pass_height = pass_heights[pass]
    if pass_width == 0 || pass_height == 0 {
      continue
    }
    let pass_stride = pass_strides[pass]
    let pass_length = pass_height * (pass_stride + 1)
    // Filter state resets at every pass boundary: each pass is its own
    // image as far as the filters are concerned.
    let decoded = pdf_decode_png_predictor(
      channels,
      bit_depth,
      pass_width,
      filtered[offset:offset + pass_length],
    )
    offset += pass_length
    pdf_png_place_pass(
      raster,
      full_stride,
      bits_per_pixel,
      decoded,
      pass_stride,
      pass_width,
      pass_height,
      pdf_png_adam7_start_row[pass],
      pdf_png_adam7_start_col[pass],
      pdf_png_adam7_row_step[pass],
      pdf_png_adam7_col_step[pass],
    )
  }
  // Paeth for every row rather than the per-row optimum: one pass over the
  // raster instead of six, and it is the filter these images (screenshots
  // and photographs) would have been given anyway.
  let refiltered = pdf_encode_png_tagged_predictor(
    4,
    channels,
    bit_depth,
    width,
    Bytes::from_array(raster),
  )
  @flate.pdf_flate_encode(refiltered)
}
