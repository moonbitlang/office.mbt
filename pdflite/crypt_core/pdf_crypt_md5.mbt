///|
/// Return the MD5 digest of `data`.
pub fn pdf_md5_digest(data : BytesView) -> @core.PdfBytes {
  Bytes::from_array(@crypto.md5(data))
}
