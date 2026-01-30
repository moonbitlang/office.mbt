///|
fn img_read_u32_be(bytes : BytesView, offset : Int) -> Int? {
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
fn img_read_u32_le(bytes : BytesView, offset : Int) -> Int? {
  if offset < 0 || offset + 4 > bytes.length() {
    return None
  }
  let b0 = bytes[offset].to_int()
  let b1 = bytes[offset + 1].to_int()
  let b2 = bytes[offset + 2].to_int()
  let b3 = bytes[offset + 3].to_int()
  Some(b0 | (b1 << 8) | (b2 << 16) | (b3 << 24))
}

///|
fn img_read_u16_be(bytes : BytesView, offset : Int) -> Int? {
  if offset < 0 || offset + 2 > bytes.length() {
    return None
  }
  let b0 = bytes[offset].to_int()
  let b1 = bytes[offset + 1].to_int()
  Some((b0 << 8) | b1)
}

///|
fn img_read_u16_le(bytes : BytesView, offset : Int) -> Int? {
  if offset < 0 || offset + 2 > bytes.length() {
    return None
  }
  let b0 = bytes[offset].to_int()
  let b1 = bytes[offset + 1].to_int()
  Some(b0 | (b1 << 8))
}

///|
fn png_dimensions(bytes : BytesView) -> (Int, Int)? {
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
fn gif_dimensions(bytes : BytesView) -> (Int, Int)? {
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
fn jpeg_dimensions(bytes : BytesView) -> (Int, Int)? {
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
fn bmp_dimensions(bytes : BytesView) -> (Int, Int)? {
  // BMP file header is 14 bytes, followed by a DIB header.
  if bytes.length() < 26 {
    return None
  }
  if !(bytes[0].to_int() == 0x42 && bytes[1].to_int() == 0x4D) {
    return None
  }
  let dib_size_opt = img_read_u32_le(bytes, 14)
  let dib_size = match dib_size_opt {
    Some(v) => v
    None => return None
  }
  if dib_size == 12 {
    // BITMAPCOREHEADER: width/height are 16-bit at offsets 18/20.
    let w_opt = img_read_u16_le(bytes, 18)
    let h_opt = img_read_u16_le(bytes, 20)
    match (w_opt, h_opt) {
      (Some(w), Some(h)) if w > 0 && h > 0 => Some((w, h))
      _ => None
    }
  } else if dib_size >= 40 {
    // BITMAPINFOHEADER and later: width/height are signed 32-bit at offsets 18/22.
    let w_opt = img_read_u32_le(bytes, 18)
    let h_opt = img_read_u32_le(bytes, 22)
    match (w_opt, h_opt) {
      (Some(w_raw), Some(h_raw)) => {
        let w = w_raw
        let h = if h_raw < 0 { -h_raw } else { h_raw }
        if w > 0 && h > 0 {
          Some((w, h))
        } else {
          None
        }
      }
      _ => None
    }
  } else {
    None
  }
}

///|
fn ico_dimensions(bytes : BytesView) -> (Int, Int)? {
  // ICONDIR (6 bytes) + at least one ICONDIRENTRY (16 bytes).
  if bytes.length() < 22 {
    return None
  }
  let reserved = img_read_u16_le(bytes, 0)
  let typ = img_read_u16_le(bytes, 2)
  let count = img_read_u16_le(bytes, 4)
  match (reserved, typ, count) {
    (Some(0), Some(1), Some(c)) if c > 0 => {
      let w8 = bytes[6].to_int()
      let h8 = bytes[7].to_int()
      let w = if w8 == 0 { 256 } else { w8 }
      let h = if h8 == 0 { 256 } else { h8 }
      if w > 0 && h > 0 {
        Some((w, h))
      } else {
        None
      }
    }
    _ => None
  }
}

///|
fn tiff_dimensions(bytes : BytesView) -> (Int, Int)? {
  if bytes.length() < 8 {
    return None
  }
  let le = bytes[0].to_int() == 0x49 && bytes[1].to_int() == 0x49
  let be = bytes[0].to_int() == 0x4D && bytes[1].to_int() == 0x4D
  if !le && !be {
    return None
  }
  let read_u16 = fn(bytes : BytesView, offset : Int) -> Int? {
    if le {
      img_read_u16_le(bytes, offset)
    } else {
      img_read_u16_be(bytes, offset)
    }
  }
  let read_u32 = fn(bytes : BytesView, offset : Int) -> Int? {
    if le {
      img_read_u32_le(bytes, offset)
    } else {
      img_read_u32_be(bytes, offset)
    }
  }
  let magic = read_u16(bytes, 2)
  match magic {
    Some(42) => ()
    _ => return None
  }
  let ifd_offset = match read_u32(bytes, 4) {
    Some(v) => v
    None => return None
  }
  if ifd_offset < 0 || ifd_offset + 2 > bytes.length() {
    return None
  }
  let entry_count = match read_u16(bytes, ifd_offset) {
    Some(v) => v
    None => return None
  }
  let mut width : Int? = None
  let mut height : Int? = None
  let mut entry_off = ifd_offset + 2
  for _ in 0..<entry_count {
    if entry_off + 12 > bytes.length() {
      return None
    }
    let tag = match read_u16(bytes, entry_off) {
      Some(v) => v
      None => return None
    }
    let field_type = match read_u16(bytes, entry_off + 2) {
      Some(v) => v
      None => return None
    }
    let count = match read_u32(bytes, entry_off + 4) {
      Some(v) => v
      None => return None
    }
    let value_off = match read_u32(bytes, entry_off + 8) {
      Some(v) => v
      None => return None
    }
    if (tag == 256 || tag == 257) && count == 1 {
      let value = match field_type {
        3 => if le { value_off & 0xFFFF } else { (value_off >> 16) & 0xFFFF }
        4 => value_off
        _ => 0
      }
      if value > 0 {
        if tag == 256 {
          width = Some(value)
        } else {
          height = Some(value)
        }
      }
    }
    entry_off = entry_off + 12
  }
  match (width, height) {
    (Some(w), Some(h)) if w > 0 && h > 0 => Some((w, h))
    _ => None
  }
}

///|
fn svg_parse_length_px(text : StringView) -> Double? {
  let raw = text.to_string().trim().to_lower()
  if raw == "" {
    return None
  }
  let mut end = 0
  for i in 0..<raw.length() {
    let ch = raw[i]
    let ok = (ch >= '0' && ch <= '9') ||
      ch == '.' ||
      ch == '-' ||
      ch == '+' ||
      ch == 'e' ||
      ch == 'E'
    if ok {
      end = i + 1
    } else {
      break
    }
  }
  if end == 0 {
    return None
  }
  let number_text = raw[:end] catch { _ => return None }
  let value = @strconv.parse_double(number_text) catch { _ => return None }
  let unit_raw = raw[end:] catch { _ => "" }
  let unit = unit_raw.trim()
  match unit {
    "" | "px" => Some(value)
    "in" => Some(value * 96.0)
    "cm" => Some(value * (96.0 / 2.54))
    "mm" => Some(value * (96.0 / 25.4))
    "pt" => Some(value * (96.0 / 72.0))
    _ => Some(value)
  }
}

///|
fn svg_attr_value(tag : StringView, name : StringView) -> String? {
  let key = name.to_string()
  let dq = key + "=\""
  match tag.find(dq) {
    Some(pos) => {
      let rest = tag[pos + dq.length():] catch { _ => return None }
      let end = match rest.find("\"") {
        Some(v) => v
        None => return None
      }
      let value = rest[:end] catch { _ => return None }
      Some(value.to_string())
    }
    None => {
      let sq = key + "='"
      match tag.find(sq) {
        Some(pos) => {
          let rest = tag[pos + sq.length():] catch { _ => return None }
          let end = match rest.find("'") {
            Some(v) => v
            None => return None
          }
          let value = rest[:end] catch { _ => return None }
          Some(value.to_string())
        }
        None => None
      }
    }
  }
}

///|
fn svg_dimensions(bytes : BytesView) -> (Int, Int)? {
  let text = @encoding/utf8.decode(bytes) catch { _ => return None }
  let start = match text.find("<svg") {
    Some(v) => v
    None => return None
  }
  let rest = text[start:] catch { _ => return None }
  let end = match rest.find(">") {
    Some(v) => v
    None => return None
  }
  let tag = rest[:end] catch { _ => return None }
  let width_attr = svg_attr_value(tag, "width")
  let height_attr = svg_attr_value(tag, "height")
  match (width_attr, height_attr) {
    (Some(w), Some(h)) => {
      let w_px = svg_parse_length_px(w)
      let h_px = svg_parse_length_px(h)
      match (w_px, h_px) {
        (Some(wd), Some(hd)) => {
          let wi = Double::round(wd).to_int()
          let hi = Double::round(hd).to_int()
          if wi > 0 && hi > 0 {
            Some((wi, hi))
          } else {
            None
          }
        }
        _ => None
      }
    }
    _ => {
      let view_box = svg_attr_value(tag, "viewBox")
      match view_box {
        Some(vb) => {
          let cleaned = vb.replace_all(old=",", new=" ")
          let numbers : Array[Double] = []
          for part in cleaned.split(" ") {
            let trimmed = part.trim()
            if trimmed == "" {
              continue
            }
            let parsed = @strconv.parse_double(trimmed) catch { _ => continue }
            numbers.push(parsed)
            if numbers.length() >= 4 {
              break
            }
          }
          if numbers.length() >= 4 {
            let wi = Double::round(numbers[2]).to_int()
            let hi = Double::round(numbers[3]).to_int()
            if wi > 0 && hi > 0 {
              Some((wi, hi))
            } else {
              None
            }
          } else {
            None
          }
        }
        None => None
      }
    }
  }
}

///|
fn emf_dimensions(bytes : BytesView) -> (Int, Int)? {
  // ENHMETAHEADER: use rclFrame (in .01 millimeter) if present.
  // Offsets: iType(0), nSize(4), rclBounds(8), rclFrame(24), signature(40).
  if bytes.length() < 44 {
    return None
  }
  let i_type = img_read_u32_le(bytes, 0)
  match i_type {
    Some(1) => ()
    _ => return None
  }
  let sig = img_read_u32_le(bytes, 40)
  match sig {
    Some(0x464D4520) => ()
    _ => return None
  }
  let left = img_read_u32_le(bytes, 24)
  let top = img_read_u32_le(bytes, 28)
  let right = img_read_u32_le(bytes, 32)
  let bottom = img_read_u32_le(bytes, 36)
  match (left, top, right, bottom) {
    (Some(l), Some(t), Some(r), Some(b)) => {
      let w_01mm = r - l
      let h_01mm = b - t
      if w_01mm <= 0 || h_01mm <= 0 {
        return None
      }
      let w_in = Double::from_int(w_01mm) / 100.0 / 25.4
      let h_in = Double::from_int(h_01mm) / 100.0 / 25.4
      let w_px = Double::round(w_in * 96.0).to_int()
      let h_px = Double::round(h_in * 96.0).to_int()
      if w_px > 0 && h_px > 0 {
        Some((w_px, h_px))
      } else {
        None
      }
    }
    _ => None
  }
}

///|
fn wmf_dimensions(bytes : BytesView) -> (Int, Int)? {
  // Placeable metafile header (22 bytes): key + bbox + inch.
  if bytes.length() < 22 {
    return None
  }
  let key = img_read_u32_le(bytes, 0)
  match key {
    Some(v) if v == 0x9AC6CDD7 => ()
    _ => return None
  }
  let left = img_read_u16_le(bytes, 6)
  let top = img_read_u16_le(bytes, 8)
  let right = img_read_u16_le(bytes, 10)
  let bottom = img_read_u16_le(bytes, 12)
  let inch = img_read_u16_le(bytes, 14)
  match (left, top, right, bottom, inch) {
    (Some(l), Some(t), Some(r), Some(b), Some(i)) => {
      if i <= 0 {
        return None
      }
      let w_units = r - l
      let h_units = b - t
      if w_units <= 0 || h_units <= 0 {
        return None
      }
      let w_in = Double::from_int(w_units) / Double::from_int(i)
      let h_in = Double::from_int(h_units) / Double::from_int(i)
      let w_px = Double::round(w_in * 96.0).to_int()
      let h_px = Double::round(h_in * 96.0).to_int()
      if w_px > 0 && h_px > 0 {
        Some((w_px, h_px))
      } else {
        None
      }
    }
    _ => None
  }
}

///|
fn image_dimensions_px(
  data : BytesView,
  extension_lower : StringView,
) -> (Int, Int)? {
  match extension_lower.to_string() {
    "png" => png_dimensions(data)
    "gif" => gif_dimensions(data)
    "jpg" => jpeg_dimensions(data)
    "jpeg" => jpeg_dimensions(data)
    "bmp" => bmp_dimensions(data)
    "ico" => ico_dimensions(data)
    "tif" => tiff_dimensions(data)
    "tiff" => tiff_dimensions(data)
    "svg" => svg_dimensions(data)
    "emf" => emf_dimensions(data)
    "wmf" => wmf_dimensions(data)
    "emz" =>
      try @zip.gunzip(data) catch {
        _ => None
      } noraise {
        bytes => emf_dimensions(bytes[:])
      }
    "wmz" =>
      try @zip.gunzip(data) catch {
        _ => None
      } noraise {
        bytes => wmf_dimensions(bytes[:])
      }
    _ => None
  }
}
