///|
pub(all) enum PdfCryptType {
  PdfCryptARC4(Int, Int)
  PdfCryptAESV2
  PdfCryptAESV3(Bool)
} derive(Debug, Eq, ToJson)

///|
fn pdf_crypto_low_byte(value : Int, shift : Int) -> Byte {
  ((value >> shift) & 0xff).to_byte()
}

///|
fn pdf_arc4_swap(state : Array[Int], left : Int, right : Int) -> Unit {
  let value = state[left]
  state[left] = state[right]
  state[right] = value
}

///|
pub fn pdf_arc4_crypt(
  key : BytesView,
  data : BytesView,
) -> PdfBytes raise PdfError {
  guard key.length() > 0 else { raise CryptoKeyExpected }
  let state : Array[Int] = []
  for value in 0..<256 {
    state.push(value)
  }
  let mut j = 0
  for i in 0..<256 {
    j = (j + state[i] + key[i % key.length()].to_int()) % 256
    pdf_arc4_swap(state, i, j)
  }
  let output : Array[Byte] = []
  let mut i = 0
  j = 0
  for byte in data {
    i = (i + 1) % 256
    j = (j + state[i]) % 256
    pdf_arc4_swap(state, i, j)
    let stream_byte = state[(state[i] + state[j]) % 256]
    output.push((byte.to_int() ^ stream_byte).to_byte())
  }
  Bytes::from_array(output)
}

///|
pub fn pdf_md5_digest(data : BytesView) -> PdfBytes {
  Bytes::from_array(@crypto.md5(data))
}

///|
pub fn pdf_sha256_digest(data : BytesView) -> PdfBytes {
  Bytes::from_array(@crypto.sha256(data))
}

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
fn pdf_aes_check_key(key : BytesView) -> Unit raise PdfError {
  guard pdf_aes_valid_key_length(key.length()) else { raise CryptoKeyExpected }
}

///|
fn pdf_aes_block(data : BytesView) -> FixedArray[Byte] raise PdfError {
  guard data.length() == 16 else {
    raise InvalidCryptoDataLength(data.length())
  }
  pdf_crypto_fixed_array(data)
}

///|
fn pdf_aes_encrypt_key(key : BytesView) -> FixedArray[Byte] raise PdfError {
  pdf_aes_check_key(key)
  let fixed_key = pdf_crypto_fixed_array(key)
  @rijndael.camlpdf_caml_aes_cook_encrypt_key(fixed_key, 0, fixed_key.length())
}

///|
fn pdf_aes_decrypt_key(key : BytesView) -> FixedArray[Byte] raise PdfError {
  pdf_aes_check_key(key)
  let fixed_key = pdf_crypto_fixed_array(key)
  @rijndael.camlpdf_caml_aes_cook_decrypt_key(fixed_key, 0, fixed_key.length())
}

///|
pub fn pdf_aes_encrypt_block(
  key : BytesView,
  block : BytesView,
) -> PdfBytes raise PdfError {
  let cooked_key = pdf_aes_encrypt_key(key)
  let src = pdf_aes_block(block)
  let dst = FixedArray::make(16, b'\x00')
  @rijndael.camlpdf_caml_aes_encrypt(cooked_key, 0, src, 0, dst, 0)
  Bytes::from_array(dst)
}

///|
pub fn pdf_aes_decrypt_block(
  key : BytesView,
  block : BytesView,
) -> PdfBytes raise PdfError {
  let cooked_key = pdf_aes_decrypt_key(key)
  let src = pdf_aes_block(block)
  let dst = FixedArray::make(16, b'\x00')
  @rijndael.camlpdf_caml_aes_decrypt(cooked_key, 0, src, 0, dst, 0)
  Bytes::from_array(dst)
}

///|
fn pdf_aes_remove_padding(data : BytesView) -> PdfBytes {
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
fn pdf_aes_append_block(output : Array[Byte], block : FixedArray[Byte]) -> Unit {
  for byte in block {
    output.push(byte)
  }
}

///|
pub fn pdf_aes_cbc_decrypt(
  key : BytesView,
  data : BytesView,
  remove_padding? : Bool = true,
) -> PdfBytes raise PdfError {
  guard data.length() > 16 else { return Bytes::new(0) }
  guard data.length() % 16 == 0 else {
    raise InvalidCryptoDataLength(data.length())
  }
  let cooked_key = pdf_aes_decrypt_key(key)
  let output : Array[Byte] = []
  let mut previous_ciphertext = pdf_aes_block(data[:16])
  let mut position = 16
  while position < data.length() {
    let ciphertext = pdf_aes_block(data[position:position + 16])
    let plaintext = FixedArray::make(16, b'\x00')
    @rijndael.camlpdf_caml_aes_decrypt(
      cooked_key, 0, ciphertext, 0, plaintext, 0,
    )
    for index in 0..<16 {
      output.push(
        (plaintext[index].to_int() ^ previous_ciphertext[index].to_int()).to_byte(),
      )
    }
    previous_ciphertext = ciphertext
    position += 16
  }
  let decrypted = Bytes::from_array(output)
  if remove_padding {
    pdf_aes_remove_padding(decrypted[:])
  } else {
    decrypted
  }
}

///|
fn pdf_aes_padded_blocks(data : BytesView) -> Array[FixedArray[Byte]] {
  let blocks : Array[FixedArray[Byte]] = []
  let full_blocks = data.length() / 16
  for block_index in 0..<full_blocks {
    blocks.push(
      pdf_crypto_fixed_array(data[block_index * 16:(block_index + 1) * 16]),
    )
  }
  let overflow = data.length() % 16
  let padding = 16 - overflow
  let last = FixedArray::make(16, padding.to_byte())
  let start = full_blocks * 16
  for index in 0..<overflow {
    last[index] = data[start + index]
  }
  blocks.push(last)
  blocks
}

///|
pub fn pdf_aes_cbc_encrypt_with_iv(
  key : BytesView,
  iv : BytesView,
  data : BytesView,
) -> PdfBytes raise PdfError {
  let cooked_key = pdf_aes_encrypt_key(key)
  let mut previous_ciphertext = pdf_aes_block(iv)
  let output : Array[Byte] = []
  pdf_aes_append_block(output, previous_ciphertext)
  for block in pdf_aes_padded_blocks(data) {
    let plaintext = FixedArray::make(16, b'\x00')
    for index in 0..<16 {
      plaintext[index] = (block[index].to_int() ^
      previous_ciphertext[index].to_int()).to_byte()
    }
    let ciphertext = FixedArray::make(16, b'\x00')
    @rijndael.camlpdf_caml_aes_encrypt(
      cooked_key, 0, plaintext, 0, ciphertext, 0,
    )
    pdf_aes_append_block(output, ciphertext)
    previous_ciphertext = ciphertext
  }
  Bytes::from_array(output)
}

///|
pub fn pdf_aes_ecb_decrypt(
  key : BytesView,
  data : BytesView,
  remove_padding? : Bool = true,
) -> PdfBytes raise PdfError {
  guard data.length() > 0 else { return Bytes::new(0) }
  guard data.length() % 16 == 0 else {
    raise InvalidCryptoDataLength(data.length())
  }
  let cooked_key = pdf_aes_decrypt_key(key)
  let output : Array[Byte] = []
  let mut position = 0
  while position < data.length() {
    let ciphertext = pdf_aes_block(data[position:position + 16])
    let plaintext = FixedArray::make(16, b'\x00')
    @rijndael.camlpdf_caml_aes_decrypt(
      cooked_key, 0, ciphertext, 0, plaintext, 0,
    )
    pdf_aes_append_block(output, plaintext)
    position += 16
  }
  let decrypted = Bytes::from_array(output)
  if remove_padding {
    pdf_aes_remove_padding(decrypted[:])
  } else {
    decrypted
  }
}

///|
pub fn pdf_encryption_object_key(
  crypt_type : PdfCryptType,
  object_number : Int,
  generation : Int,
  file_key : BytesView,
  key_length_bits : Int,
) -> PdfBytes {
  let md5 = @crypto.MD5::new()
  md5.update(file_key)
  let object_bytes : FixedArray[Byte] = [
    pdf_crypto_low_byte(object_number, 0),
    pdf_crypto_low_byte(object_number, 8),
    pdf_crypto_low_byte(object_number, 16),
  ]
  md5.update(object_bytes)
  let generation_bytes : FixedArray[Byte] = [
    pdf_crypto_low_byte(generation, 0),
    pdf_crypto_low_byte(generation, 8),
  ]
  md5.update(generation_bytes)
  if crypt_type == PdfCryptAESV2 {
    let aes_salt : FixedArray[Byte] = [0x73, 0x41, 0x6c, 0x54]
    md5.update(aes_salt)
  }
  let digest = md5.finalize()
  let requested_length = key_length_bits / 8 + 5
  let length = if requested_length < 16 { requested_length } else { 16 }
  let output : Array[Byte] = []
  for index in 0..<length {
    output.push(digest[index])
  }
  Bytes::from_array(output)
}

///|
pub fn pdf_arc4_crypt_object(
  object_number : Int,
  generation : Int,
  file_key : BytesView,
  key_length_bits : Int,
  data : BytesView,
) -> PdfBytes raise PdfError {
  let object_key = pdf_encryption_object_key(
    PdfCryptARC4(key_length_bits, 0),
    object_number,
    generation,
    file_key,
    key_length_bits,
  )
  pdf_arc4_crypt(object_key[:], data)
}
