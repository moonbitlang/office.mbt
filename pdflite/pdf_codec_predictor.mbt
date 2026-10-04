///|
fn pdf_predictor_scanline_width(
  colors : Int,
  bits_per_component : Int,
  columns : Int,
) -> Int raise @core.PdfError {
  if colors <= 0 || bits_per_component <= 0 || columns <= 0 {
    raise PredictorExpected
  }
  // counted wide, a factor at a time: a row of 2^31 bits or more is
  // refused, not wrapped
  let pixel = colors.to_int64() * bits_per_component.to_int64()
  if pixel > 0x7FFFFFFFL {
    raise PredictorExpected
  }
  let bits = pixel * columns.to_int64() + 7L
  if bits > 0x7FFFFFFFL {
    raise PredictorExpected
  }
  (bits / 8L).to_int()
}

///|
fn pdf_predictor_bytes_per_pixel(
  colors : Int,
  bits_per_component : Int,
) -> Int raise @core.PdfError {
  if colors <= 0 || bits_per_component <= 0 {
    raise PredictorExpected
  }
  let bits = colors.to_int64() * bits_per_component.to_int64() + 7L
  if bits > 0x7FFFFFFFL {
    raise PredictorExpected
  }
  (bits / 8L).to_int()
}

///|
fn pdf_predictor_get0(values : ArrayView[Int], index : Int) -> Int {
  if index < 0 {
    0
  } else {
    values[index]
  }
}

///|
fn pdf_predictor_wrapping_byte(value : Int) -> Byte {
  let remainder = value % 256
  if remainder < 0 {
    (remainder + 256).to_byte()
  } else {
    remainder.to_byte()
  }
}

///|
fn pdf_paeth_predictor(a : Int, b : Int, c : Int) -> Int {
  let p = a + b - c
  let pa = (p - a).abs()
  let pb = (p - b).abs()
  let pc = (p - c).abs()
  if pa <= pb && pa <= pc {
    a
  } else if pb <= pc {
    b
  } else {
    c
  }
}
