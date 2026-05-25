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
/// Apply ARC4 to `data` with `key`.
///
/// ARC4 is symmetric, so the same function encrypts and decrypts. Empty keys
/// raise `@core.PdfError::CryptoKeyExpected`.
pub fn pdf_arc4_crypt(
  key : BytesView,
  data : BytesView,
) -> @core.PdfBytes raise @core.PdfError {
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
  let output = Array::make(data.length(), b'\x00')
  let mut i = 0
  j = 0
  let mut output_position = 0
  for byte in data {
    i = (i + 1) % 256
    j = (j + state[i]) % 256
    pdf_arc4_swap(state, i, j)
    let stream_byte = state[(state[i] + state[j]) % 256]
    output[output_position] = (byte.to_int() ^ stream_byte).to_byte()
    output_position += 1
  }
  Bytes::from_array(output)
}

///|
fn pdf_md5_rotate_left(value : UInt, bits : Int) -> UInt {
  (value << bits) | (value >> (32 - bits))
}

///|
fn pdf_md5_low_byte(value : UInt, shift : Int) -> Byte {
  ((value >> shift) & 0xff).reinterpret_as_int().to_byte()
}

///|
fn pdf_md5_word_from_message(message : ArrayView[Byte], offset : Int) -> UInt {
  message[offset].to_int().reinterpret_as_uint() |
  (message[offset + 1].to_int().reinterpret_as_uint() << 8) |
  (message[offset + 2].to_int().reinterpret_as_uint() << 16) |
  (message[offset + 3].to_int().reinterpret_as_uint() << 24)
}

///|
let pdf_md5_shifts : FixedArray[Int] = [
  7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22, 5, 9, 14, 20, 5, 9,
  14, 20, 5, 9, 14, 20, 5, 9, 14, 20, 4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23,
  4, 11, 16, 23, 6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21,
]

///|
let pdf_md5_constants : FixedArray[UInt] = [
  0xd76aa478, 0xe8c7b756, 0x242070db, 0xc1bdceee, 0xf57c0faf, 0x4787c62a, 0xa8304613,
  0xfd469501, 0x698098d8, 0x8b44f7af, 0xffff5bb1, 0x895cd7be, 0x6b901122, 0xfd987193,
  0xa679438e, 0x49b40821, 0xf61e2562, 0xc040b340, 0x265e5a51, 0xe9b6c7aa, 0xd62f105d,
  0x02441453, 0xd8a1e681, 0xe7d3fbc8, 0x21e1cde6, 0xc33707d6, 0xf4d50d87, 0x455a14ed,
  0xa9e3e905, 0xfcefa3f8, 0x676f02d9, 0x8d2a4c8a, 0xfffa3942, 0x8771f681, 0x6d9d6122,
  0xfde5380c, 0xa4beea44, 0x4bdecfa9, 0xf6bb4b60, 0xbebfbc70, 0x289b7ec6, 0xeaa127fa,
  0xd4ef3085, 0x04881d05, 0xd9d4d039, 0xe6db99e5, 0x1fa27cf8, 0xc4ac5665, 0xf4292244,
  0x432aff97, 0xab9423a7, 0xfc93a039, 0x655b59c3, 0x8f0ccc92, 0xffeff47d, 0x85845dd1,
  0x6fa87e4f, 0xfe2ce6e0, 0xa3014314, 0x4e0811a1, 0xf7537e82, 0xbd3af235, 0x2ad7d2bb,
  0xeb86d391,
]

///|
/// Return the MD5 digest of `data`.
pub fn pdf_md5_digest(data : BytesView) -> @core.PdfBytes {
  let message : Array[Byte] = []
  for byte in data {
    message.push(byte)
  }
  let bit_length_low = data.length().reinterpret_as_uint() << 3
  let bit_length_high = data.length().reinterpret_as_uint() >> 29
  message.push(0x80)
  while message.length() % 64 != 56 {
    message.push(0)
  }
  for shift in [0, 8, 16, 24] {
    message.push(pdf_md5_low_byte(bit_length_low, shift))
  }
  for shift in [0, 8, 16, 24] {
    message.push(pdf_md5_low_byte(bit_length_high, shift))
  }
  let mut a0 : UInt = 0x67452301
  let mut b0 : UInt = 0xefcdab89
  let mut c0 : UInt = 0x98badcfe
  let mut d0 : UInt = 0x10325476
  for offset = 0; offset < message.length(); offset = offset + 64 {
    let words = FixedArray::make(16, 0U)
    for index in 0..<16 {
      words[index] = pdf_md5_word_from_message(message, offset + index * 4)
    }
    let mut a = a0
    let mut b = b0
    let mut c = c0
    let mut d = d0
    for index in 0..<64 {
      let (f, word_index) = if index < 16 {
        ((b & c) | (b.lnot() & d), index)
      } else if index < 32 {
        ((d & b) | (d.lnot() & c), (5 * index + 1) % 16)
      } else if index < 48 {
        (b ^ c ^ d, (3 * index + 5) % 16)
      } else {
        (c ^ (b | d.lnot()), 7 * index % 16)
      }
      let previous_d = d
      d = c
      c = b
      b += pdf_md5_rotate_left(
        a + f + pdf_md5_constants[index] + words[word_index],
        pdf_md5_shifts[index],
      )
      a = previous_d
    }
    a0 += a
    b0 += b
    c0 += c
    d0 += d
  }
  let output = Array::make(16, b'\x00')
  let mut output_position = 0
  for value in [a0, b0, c0, d0] {
    output[output_position] = pdf_md5_low_byte(value, 0)
    output[output_position + 1] = pdf_md5_low_byte(value, 8)
    output[output_position + 2] = pdf_md5_low_byte(value, 16)
    output[output_position + 3] = pdf_md5_low_byte(value, 24)
    output_position += 4
  }
  Bytes::from_array(output)
}

///|
/// Return the SHA-256 digest of `data`.
pub fn pdf_sha256_digest(data : BytesView) -> @core.PdfBytes {
  Bytes::from_array(@crypto.sha256(data))
}

///|
let pdf_sha512_k : Array[UInt64] = [
  0x428a2f98d728ae22, 0x7137449123ef65cd, 0xb5c0fbcfec4d3b2f, 0xe9b5dba58189dbbc,
  0x3956c25bf348b538, 0x59f111f1b605d019, 0x923f82a4af194f9b, 0xab1c5ed5da6d8118,
  0xd807aa98a3030242, 0x12835b0145706fbe, 0x243185be4ee4b28c, 0x550c7dc3d5ffb4e2,
  0x72be5d74f27b896f, 0x80deb1fe3b1696b1, 0x9bdc06a725c71235, 0xc19bf174cf692694,
  0xe49b69c19ef14ad2, 0xefbe4786384f25e3, 0x0fc19dc68b8cd5b5, 0x240ca1cc77ac9c65,
  0x2de92c6f592b0275, 0x4a7484aa6ea6e483, 0x5cb0a9dcbd41fbd4, 0x76f988da831153b5,
  0x983e5152ee66dfab, 0xa831c66d2db43210, 0xb00327c898fb213f, 0xbf597fc7beef0ee4,
  0xc6e00bf33da88fc2, 0xd5a79147930aa725, 0x06ca6351e003826f, 0x142929670a0e6e70,
  0x27b70a8546d22ffc, 0x2e1b21385c26c926, 0x4d2c6dfc5ac42aed, 0x53380d139d95b3df,
  0x650a73548baf63de, 0x766a0abb3c77b2a8, 0x81c2c92e47edaee6, 0x92722c851482353b,
  0xa2bfe8a14cf10364, 0xa81a664bbc423001, 0xc24b8b70d0f89791, 0xc76c51a30654be30,
  0xd192e819d6ef5218, 0xd69906245565a910, 0xf40e35855771202a, 0x106aa07032bbd1b8,
  0x19a4c116b8d2d0c8, 0x1e376c085141ab53, 0x2748774cdf8eeb99, 0x34b0bcb5e19b48a8,
  0x391c0cb3c5c95a63, 0x4ed8aa4ae3418acb, 0x5b9cca4f7763e373, 0x682e6ff3d6b2b8a3,
  0x748f82ee5defb2fc, 0x78a5636f43172f60, 0x84c87814a1f0ab72, 0x8cc702081a6439ec,
  0x90befffa23631e28, 0xa4506cebde82bde9, 0xbef9a3f7b2c67915, 0xc67178f2e372532b,
  0xca273eceea26619c, 0xd186b8c721c0c207, 0xeada7dd6cde0eb1e, 0xf57d4f7fee6ed178,
  0x06f067aa72176fba, 0x0a637dc5a2c898a6, 0x113f9804bef90dae, 0x1b710b35131c471b,
  0x28db77f523047d84, 0x32caab7b40c72493, 0x3c9ebe0a15c9bebc, 0x431d67c49c100d4c,
  0x4cc5d4becb3e42b6, 0x597f299cfc657e2a, 0x5fcb6fab3ad6faec, 0x6c44198c4a475817,
]

///|
fn pdf_sha512_rotr(value : UInt64, bits : Int) -> UInt64 {
  (value >> bits) | (value << (64 - bits))
}

///|
fn pdf_sha512_small_sigma0(value : UInt64) -> UInt64 {
  pdf_sha512_rotr(value, 1) ^ pdf_sha512_rotr(value, 8) ^ (value >> 7)
}

///|
fn pdf_sha512_small_sigma1(value : UInt64) -> UInt64 {
  pdf_sha512_rotr(value, 19) ^ pdf_sha512_rotr(value, 61) ^ (value >> 6)
}

///|
fn pdf_sha512_big_sigma0(value : UInt64) -> UInt64 {
  pdf_sha512_rotr(value, 28) ^
  pdf_sha512_rotr(value, 34) ^
  pdf_sha512_rotr(value, 39)
}

///|
fn pdf_sha512_big_sigma1(value : UInt64) -> UInt64 {
  pdf_sha512_rotr(value, 14) ^
  pdf_sha512_rotr(value, 18) ^
  pdf_sha512_rotr(value, 41)
}

///|
fn pdf_sha512_u64_from_be(data : BytesView, offset : Int) -> UInt64 {
  let mut value : UInt64 = 0
  for index in 0..<8 {
    value = (value << 8) | data[offset + index].to_uint64()
  }
  value
}

///|
fn pdf_sha512_write_u64_be(
  output : Array[Byte],
  position : Int,
  value : UInt64,
) -> Unit {
  let mut offset = position
  for shift in [56, 48, 40, 32, 24, 16, 8, 0] {
    output[offset] = ((value >> shift) & 0xff).to_byte()
    offset += 1
  }
}

///|
fn pdf_sha512_padded(data : BytesView) -> @core.PdfBytes {
  let bit_length = data.length().to_uint64() * 8
  let padded_length = (data.length() + 1 + 16 + 127) / 128 * 128
  let output = Array::make(padded_length, b'\x00')
  for index in 0..<data.length() {
    output[index] = data[index]
  }
  output[data.length()] = 0x80
  pdf_sha512_write_u64_be(output, padded_length - 8, bit_length)
  Bytes::from_array(output)
}

///|
fn pdf_sha512_process_block(block : BytesView, state : Array[UInt64]) -> Unit {
  let words : Array[UInt64] = Array::make(80, 0)
  for index in 0..<16 {
    words[index] = pdf_sha512_u64_from_be(block, index * 8)
  }
  for index in 16..<80 {
    words[index] = pdf_sha512_small_sigma1(words[index - 2]) +
      words[index - 7] +
      pdf_sha512_small_sigma0(words[index - 15]) +
      words[index - 16]
  }
  let mut a = state[0]
  let mut b = state[1]
  let mut c = state[2]
  let mut d = state[3]
  let mut e = state[4]
  let mut f = state[5]
  let mut g = state[6]
  let mut h = state[7]
  for index in 0..<80 {
    let choice = (e & f) ^ (e.lnot() & g)
    let majority = (a & b) ^ (a & c) ^ (b & c)
    let temp1 = h +
      pdf_sha512_big_sigma1(e) +
      choice +
      pdf_sha512_k[index] +
      words[index]
    let temp2 = pdf_sha512_big_sigma0(a) + majority
    h = g
    g = f
    f = e
    e = d + temp1
    d = c
    c = b
    b = a
    a = temp1 + temp2
  }
  state[0] = state[0] + a
  state[1] = state[1] + b
  state[2] = state[2] + c
  state[3] = state[3] + d
  state[4] = state[4] + e
  state[5] = state[5] + f
  state[6] = state[6] + g
  state[7] = state[7] + h
}

///|
fn pdf_sha512_digest_with_state(
  data : BytesView,
  state : Array[UInt64],
  output_words : Int,
) -> @core.PdfBytes {
  let padded = pdf_sha512_padded(data)
  let mut offset = 0
  while offset < padded.length() {
    pdf_sha512_process_block(padded[offset:offset + 128], state)
    offset += 128
  }
  let output = Array::make(output_words * 8, b'\x00')
  for index in 0..<output_words {
    pdf_sha512_write_u64_be(output, index * 8, state[index])
  }
  Bytes::from_array(output)
}

///|
/// Return the SHA-384 digest of `data`.
pub fn pdf_sha384_digest(data : BytesView) -> @core.PdfBytes {
  pdf_sha512_digest_with_state(
    data,
    [
      0xcbbb9d5dc1059ed8, 0x629a292a367cd507, 0x9159015a3070dd17, 0x152fecd8f70e5939,
      0x67332667ffc00b31, 0x8eb44a8768581511, 0xdb0c2e0d64f98fa7, 0x47b5481dbefa4fa4,
    ],
    6,
  )
}

///|
/// Return the SHA-512 digest of `data`.
pub fn pdf_sha512_digest(data : BytesView) -> @core.PdfBytes {
  pdf_sha512_digest_with_state(
    data,
    [
      0x6a09e667f3bcc908, 0xbb67ae8584caa73b, 0x3c6ef372fe94f82b, 0xa54ff53a5f1d36f1,
      0x510e527fade682d1, 0x9b05688c2b3e6c1f, 0x1f83d9abfb41bd6b, 0x5be0cd19137e2179,
    ],
    8,
  )
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
fn pdf_aes_append_block(output : Array[Byte], block : FixedArray[Byte]) -> Unit {
  for byte in block {
    output.push(byte)
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
  let output : Array[Byte] = []
  let mut position = 0
  while position < data.length() {
    let plaintext = pdf_aes_block(data[position:position + 16])
    let ciphertext = FixedArray::make(16, b'\x00')
    @rijndael.camlpdf_caml_aes_encrypt(
      cooked_key, 0, plaintext, 0, ciphertext, 0,
    )
    pdf_aes_append_block(output, ciphertext)
    position += 16
  }
  Bytes::from_array(output)
}

///|
/// Derive the per-object encryption key for a PDF object.
///
/// The object number, generation, file key, key length, and AESV2 salt are
/// hashed according to the PDF standard-security object-key algorithm.
pub fn pdf_encryption_object_key(
  crypt_type : @core.PdfCryptType,
  object_number : Int,
  generation : Int,
  file_key : BytesView,
  key_length_bits : Int,
) -> @core.PdfBytes {
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
  let output = Array::make(length, b'\x00')
  for index in 0..<length {
    output[index] = digest[index]
  }
  Bytes::from_array(output)
}

///|
/// ARC4-encrypt or decrypt data for one object using a file key.
///
/// The per-object key is derived from object number and generation before ARC4
/// is applied.
pub fn pdf_arc4_crypt_object(
  object_number : Int,
  generation : Int,
  file_key : BytesView,
  key_length_bits : Int,
  data : BytesView,
) -> @core.PdfBytes raise @core.PdfError {
  let object_key = pdf_encryption_object_key(
    PdfCryptARC4(key_length_bits, 0),
    object_number,
    generation,
    file_key,
    key_length_bits,
  )
  pdf_arc4_crypt(object_key, data)
}
