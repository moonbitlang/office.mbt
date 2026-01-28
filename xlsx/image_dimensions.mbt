///|
fn img_read_u32_be(bytes : BytesView, offset : Int) -> Int? raise XlsxError {
  if offset < 0 || offset + 4 > bytes.length() {
    return None
  }
  let b0 = bytes[offset].to_int()
  let b1 = bytes[offset + 1].to_int()
  let b2 = bytes[offset + 2].to_int()
  let b3 = bytes[offset + 3].to_int()
  Some((b0 << 24) | (b1 << 16) | (b2 << 8) | b3)
}

///|
fn img_read_u16_be(bytes : BytesView, offset : Int) -> Int? raise XlsxError {
  if offset < 0 || offset + 2 > bytes.length() {
    return None
  }
  let b0 = bytes[offset].to_int()
  let b1 = bytes[offset + 1].to_int()
  Some((b0 << 8) | b1)
}

///|
fn img_read_u16_le(bytes : BytesView, offset : Int) -> Int? raise XlsxError {
  if offset < 0 || offset + 2 > bytes.length() {
    return None
  }
  let b0 = bytes[offset].to_int()
  let b1 = bytes[offset + 1].to_int()
  Some(b0 | (b1 << 8))
}

///|
fn png_dimensions(bytes : BytesView) -> (Int, Int)? raise XlsxError {
  // PNG signature: 89 50 4E 47 0D 0A 1A 0A
  if bytes.length() < 24 {
    return None
  }
  let sig : Array[Int] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
  for i in 0..<8 {
    if bytes[i].to_int() != sig[i] {
      return None
    }
  }
  // First chunk should be IHDR; width/height are big-endian at offset 16/20.
  let is_ihdr = bytes[12].to_int() == 0x49 &&
    bytes[13].to_int() == 0x48 &&
    bytes[14].to_int() == 0x44 &&
    bytes[15].to_int() == 0x52
  if !is_ihdr {
    return None
  }
  let w_opt = img_read_u32_be(bytes, 16)
  let h_opt = img_read_u32_be(bytes, 20)
  match (w_opt, h_opt) {
    (Some(w), Some(h)) if w > 0 && h > 0 => Some((w, h))
    _ => None
  }
}

///|
fn gif_dimensions(bytes : BytesView) -> (Int, Int)? raise XlsxError {
  if bytes.length() < 10 {
    return None
  }
  let is_gif = bytes[0].to_int() == 0x47 &&
    bytes[1].to_int() == 0x49 &&
    bytes[2].to_int() == 0x46 &&
    bytes[3].to_int() == 0x38 &&
    (bytes[4].to_int() == 0x37 || bytes[4].to_int() == 0x39) &&
    bytes[5].to_int() == 0x61
  if !is_gif {
    return None
  }
  let w_opt = img_read_u16_le(bytes, 6)
  let h_opt = img_read_u16_le(bytes, 8)
  match (w_opt, h_opt) {
    (Some(w), Some(h)) if w > 0 && h > 0 => Some((w, h))
    _ => None
  }
}

///|
fn jpeg_dimensions(bytes : BytesView) -> (Int, Int)? raise XlsxError {
  if bytes.length() < 4 {
    return None
  }
  if !(bytes[0].to_int() == 0xFF && bytes[1].to_int() == 0xD8) {
    return None
  }
  let mut i = 2
  // Scan segments until we find a SOF marker with dimensions.
  while i + 4 <= bytes.length() {
    // Find the next marker (0xFF ...), skipping fill bytes.
    if bytes[i].to_int() != 0xFF {
      i = i + 1
      continue
    }
    while i < bytes.length() && bytes[i].to_int() == 0xFF {
      i = i + 1
    }
    if i >= bytes.length() {
      return None
    }
    let marker = bytes[i].to_int()
    i = i + 1
    // Standalone markers.
    if marker == 0xD9 || marker == 0xDA {
      return None
    }
    let len = match img_read_u16_be(bytes, i) {
      Some(v) => v
      None => return None
    }
    if len < 2 {
      return None
    }
    // Segment payload starts after length.
    let seg_start = i + 2
    let seg_end = i + len
    if seg_end > bytes.length() {
      return None
    }
    let is_sof = (marker >= 0xC0 && marker <= 0xC3) ||
      (marker >= 0xC5 && marker <= 0xC7) ||
      (marker >= 0xC9 && marker <= 0xCB) ||
      (marker >= 0xCD && marker <= 0xCF)
    if is_sof {
      // SOF payload: [precision:1][height:2][width:2]...
      if seg_start + 5 > seg_end {
        return None
      }
      let h = match img_read_u16_be(bytes, seg_start + 1) {
        Some(v) => v
        None => return None
      }
      let w = match img_read_u16_be(bytes, seg_start + 3) {
        Some(v) => v
        None => return None
      }
      if w > 0 && h > 0 {
        return Some((w, h))
      }
      return None
    }
    i = seg_end
  }
  None
}

///|
fn image_dimensions_px(
  data : BytesView,
  extension_lower : StringView,
) -> (Int, Int)? raise XlsxError {
  match extension_lower.to_string() {
    "png" => png_dimensions(data)
    "gif" => gif_dimensions(data)
    "jpg" => jpeg_dimensions(data)
    "jpeg" => jpeg_dimensions(data)
    _ => None
  }
}
