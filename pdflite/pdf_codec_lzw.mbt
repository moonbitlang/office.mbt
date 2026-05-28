///|
fn pdf_lzw_next_code(
  bits : BitStream,
  code_length : Int,
) -> Int? raise PdfError {
  try bits.get_value_int(code_length) catch {
    EndOfInput => None
    _ => raise InvalidLZWData
  } noraise {
    value => Some(value)
  }
}

///|
fn pdf_lzw_decode_code(
  code : Int,
  prefix_code : Array[Int],
  append_character : Array[Int],
  next_code : Int,
) -> Array[Int] raise PdfError {
  if code < 0 || code >= next_code || code >= prefix_code.length() {
    raise InvalidLZWData
  }
  let stack : Array[Int] = Array::new(capacity=16)
  let mut current = code
  let mut depth = 0
  while current > 255 {
    if current >= next_code || current >= prefix_code.length() || depth > 8192 {
      raise InvalidLZWData
    }
    stack.push(append_character[current])
    current = prefix_code[current]
    depth += 1
  }
  if current < 0 || current > 255 {
    raise InvalidLZWData
  }
  let output : Array[Int] = Array::new(capacity=stack.length() + 1)
  output.push(current)
  if stack.length() > 0 {
    for offset in 0..<stack.length() {
      let i = stack.length() - 1 - offset
      output.push(stack[i])
    }
  }
  output
}

///|
fn pdf_lzw_read_non_clear_code(
  bits : BitStream,
  code_length : Int,
) -> Int? raise PdfError {
  let mut code = 256
  while code == 256 {
    match pdf_lzw_next_code(bits, code_length) {
      None => break None
      Some(value) => code = value
    }
  } nobreak {
    Some(code)
  }
}

///|
fn pdf_lzw_output_literal(
  output : Array[Byte],
  code : Int,
) -> Unit raise PdfError {
  if code < 0 || code > 255 {
    raise InvalidLZWData
  }
  output.push(code.to_byte())
}

///|
fn pdf_lzw_consumed_bytes(bits : BitStream) -> Int {
  let count = bits.bits_read()
  if count % 8 == 0 {
    count / 8
  } else {
    count / 8 + 1
  }
}

///|
fn pdf_lzw_decode_view_prefix(
  data : BytesView,
  early_change? : Int = 1,
) -> (PdfBytes, Int) raise PdfError {
  let prefix_code = Array::make(8192, 0)
  let append_character = Array::make(8192, 0)
  let bits = bitstream_of_view(data)
  let output : Array[Byte] = Array::new(capacity=data.length())
  let mut code_length = 9
  let mut next_code = 258
  let mut old_code = 256
  let mut character = 0
  match pdf_lzw_read_non_clear_code(bits, code_length) {
    None => raise InvalidLZWData
    Some(257) => (Bytes::from_array(output), pdf_lzw_consumed_bytes(bits))
    Some(first_code) => {
      pdf_lzw_output_literal(output, first_code)
      old_code = first_code
      character = first_code
      let mut consumed = 0
      let mut finished = false
      while !finished {
        match pdf_lzw_next_code(bits, code_length) {
          None => raise InvalidLZWData
          Some(257) => {
            consumed = pdf_lzw_consumed_bytes(bits)
            finished = true
          }
          Some(256) => {
            code_length = 9
            next_code = 258
            old_code = 256
            match pdf_lzw_read_non_clear_code(bits, code_length) {
              None => raise InvalidLZWData
              Some(257) => {
                consumed = pdf_lzw_consumed_bytes(bits)
                finished = true
              }
              Some(code) => {
                pdf_lzw_output_literal(output, code)
                old_code = code
                character = code
              }
            }
          }
          Some(new_code) => {
            let chars = if new_code == next_code {
              let expanded = pdf_lzw_decode_code(
                old_code, prefix_code, append_character, next_code,
              )
              expanded.push(character)
              expanded
            } else if new_code < next_code {
              pdf_lzw_decode_code(
                new_code, prefix_code, append_character, next_code,
              )
            } else {
              raise InvalidLZWData
            }
            character = chars[0]
            for value in chars {
              pdf_lzw_output_literal(output, value)
            }
            if next_code < prefix_code.length() {
              prefix_code[next_code] = old_code
              append_character[next_code] = character
              next_code += 1
              match next_code + early_change {
                512 | 1024 | 2048 => code_length += 1
                _ => ()
              }
            }
            old_code = new_code
          }
        }
      }
      (Bytes::from_array(output), consumed)
    }
  }
}

///|
/// Decode PDF LZW data from a byte view.
///
/// `early_change` controls when code width grows; PDF streams default to `1`.
/// Malformed codes or bitstream errors raise `PdfError::InvalidLZWData`.
pub fn pdf_lzw_decode_view(
  data : BytesView,
  early_change? : Int = 1,
) -> PdfBytes raise PdfError {
  let prefix_code = Array::make(8192, 0)
  let append_character = Array::make(8192, 0)
  let bits = bitstream_of_view(data)
  let output : Array[Byte] = Array::new(capacity=data.length())
  let mut code_length = 9
  let mut next_code = 258
  let mut old_code = 256
  let mut character = 0
  match pdf_lzw_read_non_clear_code(bits, code_length) {
    None | Some(257) => Bytes::from_array(output)
    Some(first_code) => {
      pdf_lzw_output_literal(output, first_code)
      old_code = first_code
      character = first_code
      let mut finished = false
      while !finished {
        match pdf_lzw_next_code(bits, code_length) {
          None => finished = true
          Some(257) => finished = true
          Some(256) => {
            code_length = 9
            next_code = 258
            old_code = 256
            match pdf_lzw_read_non_clear_code(bits, code_length) {
              None | Some(257) => finished = true
              Some(code) => {
                pdf_lzw_output_literal(output, code)
                old_code = code
                character = code
              }
            }
          }
          Some(new_code) => {
            let chars = if new_code == next_code {
              let expanded = pdf_lzw_decode_code(
                old_code, prefix_code, append_character, next_code,
              )
              expanded.push(character)
              expanded
            } else if new_code < next_code {
              pdf_lzw_decode_code(
                new_code, prefix_code, append_character, next_code,
              )
            } else {
              raise InvalidLZWData
            }
            character = chars[0]
            for value in chars {
              pdf_lzw_output_literal(output, value)
            }
            if next_code < prefix_code.length() {
              prefix_code[next_code] = old_code
              append_character[next_code] = character
              next_code += 1
              match next_code + early_change {
                512 | 1024 | 2048 => code_length += 1
                _ => ()
              }
            }
            old_code = new_code
          }
        }
      }
      Bytes::from_array(output)
    }
  }
}

///|
/// Owned-byte wrapper for `pdf_lzw_decode_view`.
pub fn pdf_lzw_decode(
  data : PdfBytes,
  early_change? : Int = 1,
) -> PdfBytes raise PdfError {
  pdf_lzw_decode_view(data, early_change~)
}
