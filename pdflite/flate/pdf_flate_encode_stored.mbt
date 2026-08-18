///|
fn pdf_flate_push_stored_block(
  output : @buffer.Buffer,
  data : BytesView,
  offset : Int,
  length : Int,
  final_block : Bool,
) -> Unit {
  output.write_byte(if final_block { 1 } else { 0 })
  output.write_uint16_le(length.to_uint16())
  output.write_uint16_le((0xFFFF - length).to_uint16())
  output.write_bytes(data[offset:offset + length])
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
  let output = @buffer.Buffer(size_hint=data.length() + block_count * 5 + 4)
  for byte in header {
    output.write_byte(byte)
  }
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
  pdf_flate_push_adler32_to_buffer(output, data)
  output.to_bytes()
}
