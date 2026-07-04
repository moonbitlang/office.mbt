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
