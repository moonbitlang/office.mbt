///|
fn pdf_image_copy_view(
  output : Array[Byte],
  position : Int,
  bytes : BytesView,
) -> Int {
  let mut next = position
  for byte in bytes {
    output[next] = byte
    next += 1
  }
  next
}

///|
fn pdf_image_pnm_24bpp_bytes(
  width : Int,
  height : Int,
  data : @core.PdfBytes,
) -> @core.PdfBytes {
  let width_bytes = @ascii.encode(width.to_string())
  let height_bytes = @ascii.encode(height.to_string())
  let output = Array::make(
    3 + width_bytes.length() + 1 + height_bytes.length() + 5 + data.length(),
    b'\x00',
  )
  let mut position = pdf_image_copy_view(output, 0, b"P6 ")
  position = pdf_image_copy_view(output, position, width_bytes)
  position = pdf_image_copy_view(output, position, b" ")
  position = pdf_image_copy_view(output, position, height_bytes)
  position = pdf_image_copy_view(output, position, b" 255\n")
  let _ = pdf_image_copy_view(output, position, data)
  Bytes::from_array(output)
}
