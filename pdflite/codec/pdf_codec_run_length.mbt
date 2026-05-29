///|
fn pdf_run_length_flush_literal(
  output : Array[Byte],
  position : Int,
  data : BytesView,
  start : Int,
  length : Int,
) -> Int {
  let mut current = position
  if length > 0 {
    output[current] = (length - 1).to_byte()
    current += 1
    for i in 0..<length {
      output[current] = data[start + i]
      current += 1
    }
  }
  current
}

///|
/// Encode bytes with PDF RunLengthDecode syntax.
///
/// Literal runs and repeated-byte runs are emitted with the standard `128`
/// end-of-data marker.
pub fn pdf_run_length_encode_view(data : BytesView) -> @core.PdfBytes {
  let output = Array::make(
    data.length() + (data.length() + 127) / 128 + 1,
    b'\x00',
  )
  let mut position = 0
  let mut literal_start = 0
  let mut literal_length = 0
  let mut index = 0
  while index < data.length() {
    let value = data[index]
    let mut run_length = 1
    while index + run_length < data.length() &&
          data[index + run_length] == value &&
          run_length < 128 {
      run_length += 1
    }
    if run_length >= 3 {
      position = pdf_run_length_flush_literal(
        output, position, data, literal_start, literal_length,
      )
      literal_length = 0
      output[position] = (257 - run_length).to_byte()
      output[position + 1] = value
      position += 2
      index += run_length
    } else {
      if literal_length == 0 {
        literal_start = index
      }
      if literal_length + run_length > 128 {
        position = pdf_run_length_flush_literal(
          output, position, data, literal_start, literal_length,
        )
        literal_start = index
        literal_length = 0
      }
      literal_length += run_length
      index += run_length
    }
  }
  position = pdf_run_length_flush_literal(
    output, position, data, literal_start, literal_length,
  )
  output[position] = 128
  Bytes::from_array(output[:position + 1])
}

///|
/// Owned-byte wrapper for `pdf_run_length_encode_view`.
pub fn pdf_run_length_encode(data : @core.PdfBytes) -> @core.PdfBytes {
  pdf_run_length_encode_view(data)
}

///|
fn pdf_run_length_decoded_length(data : BytesView) -> Int {
  let mut length = 0
  let mut index = 0
  let mut done = false
  while !done && index < data.length() {
    let control = data[index].to_int()
    index += 1
    if control < 128 {
      let wanted = control + 1
      let available = if index + wanted > data.length() {
        data.length() - index
      } else {
        wanted
      }
      length += available
      index += available
    } else if control > 128 {
      if index < data.length() {
        length += 257 - control
        index += 1
      } else {
        done = true
      }
    } else {
      done = true
    }
  }
  length
}

///|
/// Decode PDF RunLengthDecode data.
///
/// Decoding stops at the `128` end marker or end of input. Truncated trailing
/// runs are decoded as far as bytes are available, matching the tolerant reader
/// behavior used by CamlPDF.
pub fn pdf_run_length_decode_view(data : BytesView) -> @core.PdfBytes {
  let output = Array::make(pdf_run_length_decoded_length(data), b'\x00')
  let mut position = 0
  let mut index = 0
  let mut done = false
  while !done && index < data.length() {
    let control = data[index].to_int()
    index += 1
    if control < 128 {
      let wanted = control + 1
      let available = if index + wanted > data.length() {
        data.length() - index
      } else {
        wanted
      }
      for i in 0..<available {
        output[position] = data[index + i]
        position += 1
      }
      index += available
    } else if control > 128 {
      if index < data.length() {
        let value = data[index]
        index += 1
        for _ in 0..<(257 - control) {
          output[position] = value
          position += 1
        }
      } else {
        done = true
      }
    } else {
      done = true
    }
  }
  Bytes::from_array(output[:position])
}

///|
/// Owned-byte wrapper for `pdf_run_length_decode_view`.
pub fn pdf_run_length_decode(data : @core.PdfBytes) -> @core.PdfBytes {
  pdf_run_length_decode_view(data)
}
