///|
/// Encoding policy used when reading PDF information dictionary metadata.
pub(all) enum PdfMetadataEncoding {
  PdfMetadataRaw
  PdfMetadataUTF8
  PdfMetadataStripped
} derive(Debug, Eq, ToJson)
