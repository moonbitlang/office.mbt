///|
fn pdf_aes_valid_key_length(length : Int) -> Bool {
  length == 16 || length == 24 || length == 32
}

///|
/// Validate the key length, mapping an invalid key onto the PDF error
/// type. The official `x/crypto` AES routines raise a shared
/// `CryptoError` for both key and data length problems, so the length
/// checks happen here before delegating.
fn pdf_aes_check_key(key : BytesView) -> Unit raise @core.PdfError {
  guard pdf_aes_valid_key_length(key.length()) else { raise CryptoKeyExpected }
}

///|
fn pdf_aes_block_length(data : BytesView) -> Unit raise @core.PdfError {
  guard data.length() == 16 else {
    raise InvalidCryptoDataLength(data.length())
  }
}

///|
/// Map the official AES error onto the PDF error type defensively. The
/// caller has already checked key and block lengths, so any remaining
/// `CryptoError` is treated as a data-length failure.
fn pdf_aes_map_crypto_error(
  action : () -> Bytes raise @crypto.CryptoError,
  actual : Int,
) -> @core.PdfBytes raise @core.PdfError {
  action() catch {
    _ => raise InvalidCryptoDataLength(actual)
  }
}

///|
/// Encrypt one 16-byte AES block with a 128-, 192-, or 256-bit key.
pub fn pdf_aes_encrypt_block(
  key : BytesView,
  block : BytesView,
) -> @core.PdfBytes raise @core.PdfError {
  pdf_aes_check_key(key)
  pdf_aes_block_length(block)
  pdf_aes_map_crypto_error(
    () => @crypto.aes_ecb_encrypt(key, block),
    block.length(),
  )
}

///|
/// Decrypt one 16-byte AES block with a 128-, 192-, or 256-bit key.
pub fn pdf_aes_decrypt_block(
  key : BytesView,
  block : BytesView,
) -> @core.PdfBytes raise @core.PdfError {
  pdf_aes_check_key(key)
  pdf_aes_block_length(block)
  pdf_aes_map_crypto_error(
    () => @crypto.aes_ecb_decrypt(key, block),
    block.length(),
  )
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
  pdf_aes_check_key(key)
  let decrypted = pdf_aes_map_crypto_error(
    () => @crypto.aes_cbc_decrypt(key, data[:16], data[16:]),
    data.length() - 16,
  )
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
  pdf_aes_check_key(key)
  pdf_aes_block_length(iv)
  let overflow = data.length() % 16
  let padding = 16 - overflow
  let padded : Array[Byte] = data.to_array()
  for _ in 0..<padding {
    padded.push(padding.to_byte())
  }
  let encrypted = pdf_aes_map_crypto_error(
    () => @crypto.aes_cbc_encrypt(key, iv, Bytes::from_array(padded)),
    data.length() + padding,
  )
  let output = Array::make(16 + encrypted.length(), b'\x00')
  for index in 0..<16 {
    output[index] = iv[index]
  }
  for index in 0..<encrypted.length() {
    output[16 + index] = encrypted[index]
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
  pdf_aes_check_key(key)
  let decrypted = pdf_aes_map_crypto_error(
    () => @crypto.aes_ecb_decrypt(key, data),
    data.length(),
  )
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
  pdf_aes_check_key(key)
  pdf_aes_map_crypto_error(
    () => @crypto.aes_ecb_encrypt(key, data),
    data.length(),
  )
}
