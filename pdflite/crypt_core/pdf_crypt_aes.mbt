///|
fn pdf_aes_valid_key_length(length : Int) -> Bool {
  length == 16 || length == 24 || length == 32
}

///|
/// Expand `key` into an AES schedule (the in-repo cipher shared with the
/// xlsx encryption code), mapping the crypto error onto the PDF one. The
/// same schedule serves both encryption and decryption.
fn pdf_aes_key(key : BytesView) -> @aes.AesSchedule raise @core.PdfError {
  guard pdf_aes_valid_key_length(key.length()) else { raise CryptoKeyExpected }
  @aes.aes_key_schedule(key) catch {
    _ => raise CryptoKeyExpected
  }
}

///|
fn pdf_aes_block_length(data : BytesView) -> Unit raise @core.PdfError {
  guard data.length() == 16 else {
    raise InvalidCryptoDataLength(data.length())
  }
}

///|
/// Decrypt one 16-byte block with a prepared schedule. The caller guarantees
/// the slice is exactly 16 bytes, so the cipher's own length error is mapped
/// defensively onto the PDF error type.
fn pdf_aes_decrypt16(
  schedule : @aes.AesSchedule,
  block : BytesView,
) -> Array[Byte] raise @core.PdfError {
  schedule.decrypt_block(block) catch {
    _ => raise InvalidCryptoDataLength(block.length())
  }
}

///|
/// Encrypt a 16-byte state in place with a prepared schedule; same defensive
/// error mapping as `pdf_aes_decrypt16`.
fn pdf_aes_encrypt_state(
  schedule : @aes.AesSchedule,
  state : Array[Byte],
) -> Unit raise @core.PdfError {
  schedule.encrypt_block_in_place(state) catch {
    _ => raise InvalidCryptoDataLength(state.length())
  }
}

///|
/// Encrypt one 16-byte AES block with a 128-, 192-, or 256-bit key.
pub fn pdf_aes_encrypt_block(
  key : BytesView,
  block : BytesView,
) -> @core.PdfBytes raise @core.PdfError {
  let schedule = pdf_aes_key(key)
  pdf_aes_block_length(block)
  let dst = schedule.encrypt_block(block) catch {
    _ => raise InvalidCryptoDataLength(block.length())
  }
  Bytes::from_array(dst)
}

///|
/// Decrypt one 16-byte AES block with a 128-, 192-, or 256-bit key.
pub fn pdf_aes_decrypt_block(
  key : BytesView,
  block : BytesView,
) -> @core.PdfBytes raise @core.PdfError {
  let schedule = pdf_aes_key(key)
  pdf_aes_block_length(block)
  let dst = schedule.decrypt_block(block) catch {
    _ => raise InvalidCryptoDataLength(block.length())
  }
  Bytes::from_array(dst)
}

///|
fn pdf_aes_remove_padding(data : BytesView) -> @core.PdfBytes {
  let length = data.length()
  let padding = data[length - 1].to_int()
  guard padding >= 1 && padding <= 16 else { return data.to_owned() }
  for index in (length - padding)..<length {
    if data[index].to_int() != padding {
      break data.to_owned()
    }
  } nobreak {
    data[:length - padding].to_owned()
  }
}

///|
/// Decrypt AES-CBC data whose first block is the IV.
///
/// Data shorter than or equal to one block decrypts to empty bytes. Block
/// lengths that are not multiples of 16 raise `@core.PdfError::InvalidCryptoDataLength`.
pub fn pdf_aes_cbc_decrypt(
  key : BytesView,
  data : BytesView,
  remove_padding? : Bool = true,
) -> @core.PdfBytes raise @core.PdfError {
  guard data.length() > 16 else { return Bytes::new(0) }
  guard data.length() % 16 == 0 else {
    raise InvalidCryptoDataLength(data.length())
  }
  let schedule = pdf_aes_key(key)
  let output = Array::make(data.length() - 16, b'\x00')
  let mut previous_ciphertext = data[:16]
  let mut position = 16
  let mut output_position = 0
  while position < data.length() {
    let ciphertext = data[position:position + 16]
    let plaintext = pdf_aes_decrypt16(schedule, ciphertext)
    for index in 0..<16 {
      output[output_position + index] = (plaintext[index].to_int() ^
      previous_ciphertext[index].to_int()).to_byte()
    }
    previous_ciphertext = ciphertext
    position += 16
    output_position += 16
  }
  let decrypted = Bytes::from_array(output)
  if remove_padding {
    pdf_aes_remove_padding(decrypted)
  } else {
    decrypted
  }
}

///|
/// Encrypt bytes with AES-CBC and an explicit IV.
///
/// PKCS-style padding is added and the returned bytes include the IV as the
/// first block, matching PDF AES string and stream data layout.
pub fn pdf_aes_cbc_encrypt_with_iv(
  key : BytesView,
  iv : BytesView,
  data : BytesView,
) -> @core.PdfBytes raise @core.PdfError {
  let schedule = pdf_aes_key(key)
  pdf_aes_block_length(iv)
  let mut previous_ciphertext = iv.to_array()
  let full_blocks = data.length() / 16
  let overflow = data.length() % 16
  let output = Array::make((full_blocks + 2) * 16, b'\x00')
  for index in 0..<16 {
    output[index] = previous_ciphertext[index]
  }
  let mut output_position = 16
  for block_index in 0..<full_blocks {
    let block_start = block_index * 16
    let state = Array::make(16, b'\x00')
    for index in 0..<16 {
      state[index] = (data[block_start + index].to_int() ^
      previous_ciphertext[index].to_int()).to_byte()
    }
    pdf_aes_encrypt_state(schedule, state)
    for index in 0..<16 {
      output[output_position + index] = state[index]
    }
    output_position += 16
    previous_ciphertext = state
  }
  let padding = 16 - overflow
  let final_start = full_blocks * 16
  let state = Array::make(16, b'\x00')
  for index in 0..<16 {
    let value = if index < overflow {
      data[final_start + index]
    } else {
      padding.to_byte()
    }
    state[index] = (value.to_int() ^ previous_ciphertext[index].to_int()).to_byte()
  }
  pdf_aes_encrypt_state(schedule, state)
  for index in 0..<16 {
    output[output_position + index] = state[index]
  }
  Bytes::from_array(output)
}

///|
/// Decrypt AES-ECB data.
///
/// The input length must be a non-zero multiple of 16 unless it is empty.
/// Padding is removed by default.
pub fn pdf_aes_ecb_decrypt(
  key : BytesView,
  data : BytesView,
  remove_padding? : Bool = true,
) -> @core.PdfBytes raise @core.PdfError {
  guard data.length() > 0 else { return Bytes::new(0) }
  guard data.length() % 16 == 0 else {
    raise InvalidCryptoDataLength(data.length())
  }
  let schedule = pdf_aes_key(key)
  let output = Array::make(data.length(), b'\x00')
  let mut position = 0
  while position < data.length() {
    let plaintext = pdf_aes_decrypt16(schedule, data[position:position + 16])
    for index in 0..<16 {
      output[position + index] = plaintext[index]
    }
    position += 16
  }
  let decrypted = Bytes::from_array(output)
  if remove_padding {
    pdf_aes_remove_padding(decrypted)
  } else {
    decrypted
  }
}

///|
/// Encrypt AES-ECB data without adding padding.
///
/// The input length must be a non-zero multiple of 16 unless it is empty.
pub fn pdf_aes_ecb_encrypt(
  key : BytesView,
  data : BytesView,
) -> @core.PdfBytes raise @core.PdfError {
  guard data.length() % 16 == 0 else {
    raise InvalidCryptoDataLength(data.length())
  }
  guard data.length() > 0 else { return Bytes::new(0) }
  let schedule = pdf_aes_key(key)
  let output = Array::make(data.length(), b'\x00')
  let mut position = 0
  while position < data.length() {
    let state = data[position:position + 16].to_array()
    pdf_aes_encrypt_state(schedule, state)
    for index in 0..<16 {
      output[position + index] = state[index]
    }
    position += 16
  }
  Bytes::from_array(output)
}
