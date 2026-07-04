///|
fn pdf_flate_push_u16_le(output : Array[Byte], value : Int) -> Unit {
  output.push((value & 0xFF).to_byte())
  output.push(((value >> 8) & 0xFF).to_byte())
}

///|
fn pdf_flate_push_stored_block(
  output : Array[Byte],
  data : BytesView,
  offset : Int,
  length : Int,
  final_block : Bool,
) -> Unit {
  output.push(if final_block { 1 } else { 0 })
  pdf_flate_push_u16_le(output, length)
  pdf_flate_push_u16_le(output, 0xFFFF - length)
  for i in 0..<length {
    output.push(data[offset + i])
  }
}

///|
fn pdf_flate_encode_stored_view_with_header(
  data : BytesView,
  header : ArrayView[Byte],
) -> @core.PdfBytes {
  let block_count = if data.length() == 0 {
    1
  } else {
    (data.length() + 65534) / 65535
  }
  let output = pdf_flate_output_with_header(
    header,
    data.length() + block_count * 5 + 4,
  )
  if data.length() == 0 {
    pdf_flate_push_stored_block(output, data, 0, 0, true)
  } else {
    let mut offset = 0
    while offset < data.length() {
      let remaining = data.length() - offset
      let length = if remaining > 65535 { 65535 } else { remaining }
      pdf_flate_push_stored_block(
        output,
        data,
        offset,
        length,
        offset + length == data.length(),
      )
      offset += length
    }
  }
  pdf_flate_push_adler32(output, data)
  Bytes::from_array(output)
}
