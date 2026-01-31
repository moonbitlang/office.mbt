///|
let base64_table : Array[Char] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/".to_array()

///|
let base64_decode_table : Array[Int] = {
  let out : Array[Int] = Array::make(128, -1)
  for i, ch in base64_table {
    out[ch.to_int()] = i
  }
  out
}

///|
pub fn encode(bytes : BytesView) -> String {
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
pub fn decode(text : StringView) -> Bytes raise Base64Error {
  let output : Array[Byte] = Array::new(capacity=text.length() / 4 * 3)
  let mut saw_pad = false
  let mut q0 = 0
  let mut q1 = 0
  let mut q2 = 0
  let mut q3 = 0
  let mut qlen = 0
  let mut index = 0
  for ch in text {
    let value = if ch == '=' {
      saw_pad = true
      -2
    } else {
      let code = ch.to_int()
      if code < 0 || code >= 128 {
        raise InvalidBase64(msg="invalid base64 character at index \{index}")
      }
      let value = base64_decode_table[code]
      if value < 0 || saw_pad {
        raise InvalidBase64(msg="invalid base64 character at index \{index}")
      }
      value
    }
    match qlen {
      0 => q0 = value
      1 => q1 = value
      2 => q2 = value
      _ => q3 = value
    }
    qlen = qlen + 1
    if qlen == 4 {
      let b0 = q0
      let b1 = q1
      let b2 = q2
      let b3 = q3
      if b0 < 0 || b1 < 0 {
        raise InvalidBase64(msg="invalid base64 padding")
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
      if b2 < 0 || b3 < 0 {
        saw_pad = true
      }
      qlen = 0
    }
    index = index + 1
  }
  if qlen != 0 {
    raise InvalidBase64(msg="invalid base64 length")
  }
  Bytes::from_array(output)
}
