///|
/// PDF byte strings and byte streams.
///
/// This is an alias for MoonBit `Bytes` because PDF strings and streams are
/// byte sequences, not Unicode text. Use `String` only after an explicit PDF
/// text decoding step.
pub type PdfBytes = Bytes

///|
/// Converts an integer to a byte.
///
/// Raises `PdfError::InvalidByte` when `value` is outside `0..=255`.
pub fn pdf_byte_of_int(value : Int) -> Byte raise PdfError {
  if value < 0 || value > 255 {
    raise InvalidByte(value)
  }
  value.to_byte()
}

///|
/// Copies an array view of bytes into owned PDF bytes.
pub fn pdf_bytes_of_array_view(values : ArrayView[Byte]) -> PdfBytes {
  Bytes::from_array(values)
}

///|
/// Copies a byte view into owned PDF bytes.
pub fn pdf_bytes_of_view(values : BytesView) -> PdfBytes {
  values.to_owned()
}

///|
/// Copies a byte view into owned PDF bytes using indexed construction.
///
/// This is useful when the input may alias data that will be mutated elsewhere.
pub fn pdf_bytes_copy(values : BytesView) -> PdfBytes {
  Bytes::makei(values.length(), i => values[i])
}

///|
/// Creates owned PDF bytes of `length` filled with `value`.
///
/// The default value is zero. Raises `PdfError::InvalidReadLength` for negative
/// lengths and `PdfError::InvalidByte` for values outside `0..=255`.
pub fn pdf_bytes_make(
  length : Int,
  value? : Int = 0,
) -> PdfBytes raise PdfError {
  if length < 0 {
    raise InvalidReadLength(length)
  }
  let byte = pdf_byte_of_int(value)
  Bytes::makei(length, _ => byte)
}

///|
/// Concatenates byte views into one owned PDF byte sequence.
pub fn pdf_bytes_concat_views(parts : ArrayView[BytesView]) -> PdfBytes {
  let mut length = 0
  for part in parts {
    length += part.length()
  }
  if length == 0 {
    return Bytes::new(0)
  }
  let output = Array::make(length, b' ')
  let mut position = 0
  for part in parts {
    for byte in part {
      output[position] = byte
      position += 1
    }
  }
  Bytes::from_array(output)
}

///|
/// Converts integer byte values to owned PDF bytes.
///
/// Raises `PdfError::InvalidByte` if any value is outside `0..=255`.
pub fn pdf_bytes_of_int_array(
  values : ArrayView[Int],
) -> PdfBytes raise PdfError {
  Bytes::makei(values.length(), i => pdf_byte_of_int(values[i]))
}

///|
/// Flattens arrays of integer byte values into owned PDF bytes.
///
/// Raises `PdfError::InvalidByte` if any value is outside `0..=255`.
pub fn pdf_bytes_of_int_arrays(
  values : ArrayView[ArrayView[Int]],
) -> PdfBytes raise PdfError {
  let mut length = 0
  for array in values {
    length += array.length()
  }
  let output = Array::make(length, b'\x00')
  let mut position = 0
  for array in values {
    for value in array {
      output[position] = pdf_byte_of_int(value)
      position += 1
    }
  }
  Bytes::from_array(output)
}

///|
/// Maps every byte through an integer transformation and returns owned bytes.
///
/// The callback receives each input byte as an `Int`. Raises
/// `PdfError::InvalidByte` if a mapped value is outside `0..=255`.
pub fn pdf_bytes_map_int(
  bytes : BytesView,
  f : (Int) -> Int,
) -> PdfBytes raise PdfError {
  let output = Array::make(bytes.length(), b'\x00')
  for index in 0..<bytes.length() {
    output[index] = pdf_byte_of_int(f(bytes[index].to_int()))
  }
  Bytes::from_array(output)
}

///|
/// Converts bytes to an array of integer byte values.
pub fn pdf_int_array_of_bytes(bytes : BytesView) -> Array[Int] {
  [
    for byte in bytes => byte.to_int()
  ]
}

///|
/// Compatibility alias for `pdf_bytes_of_int_arrays`.
///
/// CamlPDF models many byte strings as integer lists; this helper preserves
/// that shape for callers ported from OCaml.
pub fn pdf_string_of_int_arrays(
  values : ArrayView[ArrayView[Int]],
) -> PdfBytes raise PdfError {
  pdf_bytes_of_int_arrays(values)
}

///|
/// Compatibility alias for converting one integer byte array to PDF bytes.
pub fn pdf_string_of_int_array(
  values : ArrayView[Int],
) -> PdfBytes raise PdfError {
  pdf_bytes_of_int_arrays([values])
}

///|
/// Returns the length of a PDF byte sequence.
pub fn pdf_bytes_length(bytes : PdfBytes) -> Int {
  bytes.length()
}

///|
/// Returns the byte at `index`, or `None` when the index is out of bounds.
pub fn pdf_bytes_get(bytes : PdfBytes, index : Int) -> Byte? {
  bytes.get(index)
}

///|
/// Copies PDF bytes into a resizable `Array[Byte]`.
pub fn pdf_bytes_to_array(bytes : PdfBytes) -> Array[Byte] {
  bytes.to_array()
}

///|
/// Copies PDF bytes into a fixed-size byte array.
pub fn pdf_bytes_to_fixed_array(bytes : PdfBytes) -> FixedArray[Byte] {
  bytes.to_fixedarray()
}
