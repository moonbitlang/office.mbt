///|
fn pdf_crypto_fixed_array(data : BytesView) -> FixedArray[Byte] {
  let output = FixedArray::make(data.length(), b'\x00')
  for index, byte in data {
    output[index] = byte
  }
  output
}

///|
fn pdf_aes_valid_key_length(length : Int) -> Bool {
  length == 16 || length == 24 || length == 32
}

///|
fn pdf_aes_check_key(key : BytesView) -> Unit raise @core.PdfError {
  guard pdf_aes_valid_key_length(key.length()) else { raise CryptoKeyExpected }
}

///|
fn pdf_aes_block(data : BytesView) -> FixedArray[Byte] raise @core.PdfError {
  guard data.length() == 16 else {
    raise InvalidCryptoDataLength(data.length())
  }
  pdf_crypto_fixed_array(data)
}

///|
fn pdf_aes_encrypt_key(
  key : BytesView,
) -> FixedArray[Byte] raise @core.PdfError {
  pdf_aes_check_key(key)
  let fixed_key = pdf_crypto_fixed_array(key)
  @rijndael.camlpdf_caml_aes_cook_encrypt_key(fixed_key, 0, fixed_key.length())
}

///|
fn pdf_aes_decrypt_key(
  key : BytesView,
) -> FixedArray[Byte] raise @core.PdfError {
  pdf_aes_check_key(key)
  let fixed_key = pdf_crypto_fixed_array(key)
  @rijndael.camlpdf_caml_aes_cook_decrypt_key(fixed_key, 0, fixed_key.length())
}

///|
/// Encrypt one 16-byte AES block with a 128-, 192-, or 256-bit key.
pub fn pdf_aes_encrypt_block(
  key : BytesView,
  block : BytesView,
) -> @core.PdfBytes raise @core.PdfError {
  let cooked_key = pdf_aes_encrypt_key(key)
  let src = pdf_aes_block(block)
  let dst = FixedArray::make(16, b'\x00')
  @rijndael.camlpdf_caml_aes_encrypt(cooked_key, 0, src, 0, dst, 0)
  Bytes::from_array(dst)
}

///|
/// Decrypt one 16-byte AES block with a 128-, 192-, or 256-bit key.
#warnings("-unused_value")
pub fn pdf_aes_decrypt_block(
  key : BytesView,
  block : BytesView,
) -> @core.PdfBytes raise @core.PdfError {
  let cooked_key = pdf_aes_decrypt_key(key)
  let src = pdf_aes_block(block)
  let dst = FixedArray::make(16, b'\x00')
  @rijndael.camlpdf_caml_aes_decrypt(cooked_key, 0, src, 0, dst, 0)
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
  let cooked_key = pdf_aes_decrypt_key(key)
  let output = Array::make(data.length() - 16, b'\x00')
  let mut previous_ciphertext = pdf_aes_block(data[:16])
  let mut position = 16
  let mut output_position = 0
  while position < data.length() {
    let ciphertext = pdf_aes_block(data[position:position + 16])
    let plaintext = FixedArray::make(16, b'\x00')
    @rijndael.camlpdf_caml_aes_decrypt(
      cooked_key, 0, ciphertext, 0, plaintext, 0,
    )
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
  let cooked_key = pdf_aes_encrypt_key(key)
  let mut previous_ciphertext = pdf_aes_block(iv)
  let full_blocks = data.length() / 16
  let overflow = data.length() % 16
  let output = Array::make((full_blocks + 2) * 16, b'\x00')
  for index in 0..<16 {
    output[index] = previous_ciphertext[index]
  }
  let mut output_position = 16
  for block_index in 0..<full_blocks {
    let block_start = block_index * 16
    let plaintext = FixedArray::make(16, b'\x00')
    for index in 0..<16 {
      plaintext[index] = (data[block_start + index].to_int() ^
      previous_ciphertext[index].to_int()).to_byte()
    }
    let ciphertext = FixedArray::make(16, b'\x00')
    @rijndael.camlpdf_caml_aes_encrypt(
      cooked_key, 0, plaintext, 0, ciphertext, 0,
    )
    for index in 0..<16 {
      output[output_position + index] = ciphertext[index]
    }
    output_position += 16
    previous_ciphertext = ciphertext
  }
  let padding = 16 - overflow
  let final_start = full_blocks * 16
  let plaintext = FixedArray::make(16, b'\x00')
  for index in 0..<16 {
    let value = if index < overflow {
      data[final_start + index]
    } else {
      padding.to_byte()
    }
    plaintext[index] = (value.to_int() ^ previous_ciphertext[index].to_int()).to_byte()
  }
  let ciphertext = FixedArray::make(16, b'\x00')
  @rijndael.camlpdf_caml_aes_encrypt(cooked_key, 0, plaintext, 0, ciphertext, 0)
  for index in 0..<16 {
    output[output_position + index] = ciphertext[index]
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
  let cooked_key = pdf_aes_decrypt_key(key)
  let output = Array::make(data.length(), b'\x00')
  let mut position = 0
  while position < data.length() {
    let ciphertext = pdf_aes_block(data[position:position + 16])
    let plaintext = FixedArray::make(16, b'\x00')
    @rijndael.camlpdf_caml_aes_decrypt(
      cooked_key, 0, ciphertext, 0, plaintext, 0,
    )
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
#warnings("-unused_value")
pub fn pdf_aes_ecb_encrypt(
  key : BytesView,
  data : BytesView,
) -> @core.PdfBytes raise @core.PdfError {
  guard data.length() % 16 == 0 else {
    raise InvalidCryptoDataLength(data.length())
  }
  guard data.length() > 0 else { return Bytes::new(0) }
  let cooked_key = pdf_aes_encrypt_key(key)
  let output = Array::make(data.length(), b'\x00')
  let mut position = 0
  while position < data.length() {
    let plaintext = pdf_aes_block(data[position:position + 16])
    let ciphertext = FixedArray::make(16, b'\x00')
    @rijndael.camlpdf_caml_aes_encrypt(
      cooked_key, 0, plaintext, 0, ciphertext, 0,
    )
    for index in 0..<16 {
      output[position + index] = ciphertext[index]
    }
    position += 16
  }
  Bytes::from_array(output)
}
