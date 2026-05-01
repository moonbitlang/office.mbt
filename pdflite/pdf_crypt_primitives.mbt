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
