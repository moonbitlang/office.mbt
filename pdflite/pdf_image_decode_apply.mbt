///|
fn pdf_image_require_size(
  data : BytesView,
  required : Int,
) -> Unit raise PdfError {
  if data.length() < required {
    raise EndOfInput
  }
}

///|
fn pdf_image_decode_is_identity(
  values : ArrayView[Double],
) -> Bool raise PdfError {
  if values.length() == 0 {
    true
  } else if values.length() % 2 != 0 {
    raise FilterExpected
  } else {
    let mut identity = true
    for index in 0..<(values.length() / 2) {
      if values[index * 2] != 0.0 || values[index * 2 + 1] != 1.0 {
        identity = false
      }
    }
    identity
  }
}

///|
fn pdf_image_decode_interpolate(
  dmin : Double,
  dmax : Double,
  value : Int,
  bpc : Int,
) -> Int {
  let denominator = match bpc {
    1 => 1.0
    2 => 3.0
    4 => 15.0
    8 => 255.0
    16 => 65535.0
    _ => 1.0
  }
  (dmin + value.to_double() * (dmax - dmin) / denominator).to_int()
}

///|
fn pdf_image_apply_1bpp_decode(data : BytesView) -> PdfBytes {
  let output = Array::make(data.length(), b'\x00')
  for index, value in data {
    output[index] = (value.to_int() ^ 0xFF).to_byte()
  }
  Bytes::from_array(output)
}

///|
fn pdf_image_apply_8bpp_decode(
  data : BytesView,
  values : ArrayView[Double],
) -> PdfBytes raise PdfError {
  let components = values.length() / 2
  let output = Array::make(data.length(), b'\x00')
  for index in 0..<data.length() {
    let component = index % components
    output[index] = pdf_byte_of_int(
      pdf_image_decode_interpolate(
        values[component * 2],
        values[component * 2 + 1],
        data[index].to_int(),
        8,
      ),
    )
  }
  Bytes::from_array(output)
}

///|
fn pdf_image_apply_decode_borrowed(
  data : BytesView,
  bpc : Int?,
  decode_values : Array[Double]?,
) -> PdfBytes raise PdfError {
  match decode_values {
    None => data.to_owned()
    Some(values) =>
      if pdf_image_decode_is_identity(values) {
        data.to_owned()
      } else {
        match bpc {
          Some(1) => pdf_image_apply_1bpp_decode(data)
          Some(2) | Some(4) | Some(16) => data.to_owned()
          Some(8) => pdf_image_apply_8bpp_decode(data, values)
          _ => raise FilterExpected
        }
      }
  }
}

///|
fn pdf_image_apply_decode(
  data : PdfBytes,
  bpc : Int?,
  decode_values : Array[Double]?,
) -> PdfBytes raise PdfError {
  match decode_values {
    None => data
    Some(values) =>
      if pdf_image_decode_is_identity(values) {
        data
      } else {
        match bpc {
          Some(1) => pdf_image_apply_decode_borrowed(data, bpc, Some(values))
          Some(2) | Some(4) | Some(16) => data
          Some(8) => pdf_image_apply_decode_borrowed(data, bpc, Some(values))
          _ => raise FilterExpected
        }
      }
  }
}
