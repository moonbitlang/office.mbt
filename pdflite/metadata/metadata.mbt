///|
/// Encoding policy used when reading PDF information dictionary metadata.
#derive(Debug, Eq, ToJson)
pub(all) enum PdfMetadataEncoding {
  PdfMetadataRaw
  PdfMetadataUTF8
  PdfMetadataStripped
}
