///|
let base64_table : Array[Char] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/".to_array()

///|
fn base64_encode(bytes : BytesView) -> String {
  let sb = StringBuilder::new()
  let len = bytes.length()
  let mut i = 0
  while i < len {
    let b0 = bytes[i].to_int()
    let b1 = if i + 1 < len { bytes[i + 1].to_int() } else { 0 }
    let b2 = if i + 2 < len { bytes[i + 2].to_int() } else { 0 }
    let triple = (b0 << 16) | (b1 << 8) | b2
    sb.write_char(base64_table[(triple >> 18) & 0x3f])
    sb.write_char(base64_table[(triple >> 12) & 0x3f])
    if i + 1 < len {
      sb.write_char(base64_table[(triple >> 6) & 0x3f])
    } else {
      sb.write_char('=')
    }
    if i + 2 < len {
      sb.write_char(base64_table[triple & 0x3f])
    } else {
      sb.write_char('=')
    }
    i = i + 3
  }
  sb.to_string()
}

///|
fn base64_decode(text : StringView) -> Bytes raise XlsxError {
  let decode_table : Array[Int] = Array::make(128, -1)
  for i, ch in base64_table {
    decode_table[ch.to_int()] = i
  }
  let buffer : Array[Int] = []
  let output : Array[Byte] = []
  let mut saw_pad = false
  let mut index = 0
  for ch in text.to_string().to_array() {
    if ch == '=' {
      saw_pad = true
      buffer.push(-2)
    } else {
      let code = ch.to_int()
      if code < 0 || code >= 128 {
        raise XlsxError::InvalidBase64(
          msg="invalid base64 character at index \{index}",
        )
      }
      let value = decode_table[code]
      if value < 0 || saw_pad {
        raise XlsxError::InvalidBase64(
          msg="invalid base64 character at index \{index}",
        )
      }
      buffer.push(value)
    }
    if buffer.length() == 4 {
      let b0 = buffer[0]
      let b1 = buffer[1]
      let b2 = buffer[2]
      let b3 = buffer[3]
      if b0 < 0 || b1 < 0 {
        raise XlsxError::InvalidBase64(msg="invalid base64 padding")
      }
      let triple = (b0 << 18) |
        (b1 << 12) |
        (if b2 < 0 { 0 } else { b2 << 6 }) |
        (if b3 < 0 { 0 } else { b3 })
      output.push(((triple >> 16) & 0xff).to_byte())
      if b2 >= 0 {
        output.push(((triple >> 8) & 0xff).to_byte())
      }
      if b3 >= 0 {
        output.push((triple & 0xff).to_byte())
      }
      buffer.clear()
      if b2 < 0 || b3 < 0 {
        saw_pad = true
      }
    }
    index = index + 1
  }
  if buffer.length() != 0 {
    raise XlsxError::InvalidBase64(msg="invalid base64 length")
  }
  Bytes::from_array(output)
}
