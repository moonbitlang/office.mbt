///|
/// Decrypt AESV2 object data bytes with the derived object key.
///
/// `data` must include the leading CBC IV as stored in encrypted PDF strings
/// and streams.
pub fn pdf_aesv2_decrypt_object_data(
  object_number : Int,
  generation : Int,
  file_key : BytesView,
  key_length_bits : Int,
  data : BytesView,
) -> @core.PdfBytes raise @core.PdfError {
  let object_key = pdf_encryption_object_key(
    PdfCryptAESV2,
    object_number,
    generation,
    file_key,
    key_length_bits,
  )
  pdf_aes_cbc_decrypt(object_key, data)
}

///|
/// Encrypt bytes as AESV2 object data with an explicit CBC IV.
///
/// The returned bytes include the IV prefix expected by PDF AESV2 strings and
/// streams.
pub fn pdf_aesv2_encrypt_object_data(
  object_number : Int,
  generation : Int,
  file_key : BytesView,
  key_length_bits : Int,
  data : BytesView,
  iv : BytesView,
) -> @core.PdfBytes raise @core.PdfError {
  let object_key = pdf_encryption_object_key(
    PdfCryptAESV2,
    object_number,
    generation,
    file_key,
    key_length_bits,
  )
  pdf_aes_cbc_encrypt_with_iv(object_key, iv, data)
}

///|
/// Decrypt AESV3 object data bytes with the document file key.
///
/// `data` must include the leading CBC IV.
pub fn pdf_aesv3_decrypt_object_data(
  file_key : BytesView,
  data : BytesView,
) -> @core.PdfBytes raise @core.PdfError {
  pdf_aes_cbc_decrypt(file_key, data)
}

///|
/// Encrypt bytes as AESV3 object data with an explicit CBC IV.
///
/// The returned bytes include the IV prefix expected by PDF AES strings and
/// streams.
pub fn pdf_aesv3_encrypt_object_data(
  file_key : BytesView,
  data : BytesView,
  iv : BytesView,
) -> @core.PdfBytes raise @core.PdfError {
  pdf_aes_cbc_encrypt_with_iv(file_key, iv, data)
}
