///|
/// A PDF name token stored as its raw bytes without the leading slash.
///
/// Names are byte-oriented in the PDF file format. Keeping the original bytes
/// avoids accidental UTF-16 or UTF-8 interpretation while still allowing
/// explicit views and owned-byte access.
pub(all) struct PdfName(Bytes) derive(Debug, Eq, ToJson)

///|
/// Wraps owned bytes as a PDF name without copying.
///
/// The bytes are expected to be the name payload without the leading slash.
pub fn pdf_name_of_bytes(bytes : PdfBytes) -> PdfName {
  PdfName(bytes)
}

///|
/// Copies a byte view and wraps it as a PDF name.
///
/// The bytes are expected to be the name payload without the leading slash.
pub fn pdf_name_of_view(bytes : BytesView) -> PdfName {
  PdfName(bytes.to_owned())
}

///|
/// Returns the owned bytes backing this PDF name.
pub fn PdfName::bytes(self : PdfName) -> PdfBytes {
  self.0
}

///|
/// Returns a read-only view of the bytes backing this PDF name.
pub fn PdfName::view(self : PdfName) -> BytesView {
  self.0
}

///|
/// Returns the byte length of this PDF name.
pub fn PdfName::byte_length(self : PdfName) -> Int {
  self.0.length()
}
