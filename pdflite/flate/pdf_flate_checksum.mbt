///|
fn pdf_flate_adler32(data : BytesView) -> (Int, Int) {
  let mod_adler = 65521
  let mut s1 = 1
  let mut s2 = 0
  for byte in data {
    s1 = (s1 + byte.to_int()) % mod_adler
    s2 = (s2 + s1) % mod_adler
  }
  (s1, s2)
}

///|
fn pdf_flate_check_adler32(
  compressed : BytesView,
  decoded : BytesView,
) -> Unit raise @core.PdfError {
  let offset = compressed.length() - 4
  let (s1, s2) = pdf_flate_adler32(decoded)
  if compressed[offset].to_int() != ((s2 >> 8) & 0xFF) ||
    compressed[offset + 1].to_int() != (s2 & 0xFF) ||
    compressed[offset + 2].to_int() != ((s1 >> 8) & 0xFF) ||
    compressed[offset + 3].to_int() != (s1 & 0xFF) {
    raise InvalidFlateData
  }
}

///|
fn pdf_flate_push_adler32(output : Array[Byte], data : BytesView) -> Unit {
  let (s1, s2) = pdf_flate_adler32(data)
  output.push(((s2 >> 8) & 0xFF).to_byte())
  output.push((s2 & 0xFF).to_byte())
  output.push(((s1 >> 8) & 0xFF).to_byte())
  output.push((s1 & 0xFF).to_byte())
}
