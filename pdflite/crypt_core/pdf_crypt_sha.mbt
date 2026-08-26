///|
/// Return the SHA-256 digest of `data`.
pub fn pdf_sha256_digest(data : BytesView) -> @core.PdfBytes {
  Bytes::from_array(@crypto.sha256(data))
}

///|
/// Return the SHA-384 digest of `data`.
pub fn pdf_sha384_digest(data : BytesView) -> @core.PdfBytes {
  Bytes::from_array(@crypto.sha384(data))
}

///|
/// Return the SHA-512 digest of `data`.
pub fn pdf_sha512_digest(data : BytesView) -> @core.PdfBytes {
  Bytes::from_array(@crypto.sha512(data))
}
