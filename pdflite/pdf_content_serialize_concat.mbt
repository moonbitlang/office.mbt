///|
/// Concatenate already-decoded content stream views with a single space between them.
pub fn pdf_content_concat_stream_views(
  streams : ArrayView[BytesView],
) -> PdfBytes {
  let mut length = 0
  let mut has_output = false
  for stream in streams {
    if has_output {
      length += 1
    }
    length += stream.length()
    if stream.length() > 0 {
      has_output = true
    }
  }
  if length == 0 {
    return Bytes::new(0)
  }
  let output = Array::make(length, b' ')
  let mut position = 0
  has_output = false
  for stream in streams {
    if has_output {
      output[position] = b' '
      position += 1
    }
    for byte in stream {
      output[position] = byte
      position += 1
    }
    if stream.length() > 0 {
      has_output = true
    }
  }
  Bytes::from_array(output)
}

///|
/// Concatenate already-decoded content streams with a single space between them.
pub fn pdf_content_concat_streams(streams : ArrayView[PdfBytes]) -> PdfBytes {
  let mut length = 0
  let mut has_output = false
  for stream in streams {
    if has_output {
      length += 1
    }
    length += stream.length()
    if stream.length() > 0 {
      has_output = true
    }
  }
  if length == 0 {
    return Bytes::new(0)
  }
  let output = Array::make(length, b' ')
  let mut position = 0
  has_output = false
  for stream in streams {
    if has_output {
      output[position] = b' '
      position += 1
    }
    for byte in stream {
      output[position] = byte
      position += 1
    }
    if stream.length() > 0 {
      has_output = true
    }
  }
  Bytes::from_array(output)
}
