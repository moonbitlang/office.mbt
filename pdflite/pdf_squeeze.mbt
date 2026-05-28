///|
/// Compress uncompressed streams, and streams using older lossless filters, with
/// `/FlateDecode`.
///
/// Metadata streams and encrypted documents are left unchanged. The source
/// document is copied before mutation, matching the rest of the high-level
/// pdflite editing APIs.
pub fn PdfDocument::recompress(
  self : PdfDocument,
) -> PdfDocument raise PdfError {
  let document = self.copy()
  if !document.is_encrypted() {
    document.pdf_squeeze_update_stream_objects(stream => {
      document.pdf_squeeze_recompress_stream(stream)
    })
  }
  document
}

///|
/// Compatibility wrapper for `PdfDocument::recompress`.
pub fn recompress_pdf(document : PdfDocument) -> PdfDocument raise PdfError {
  document.recompress()
}

///|
/// `pdf_`-prefixed compatibility alias for cpdfsqueeze's `recompress_pdf`.
pub fn pdf_recompress_pdf(document : PdfDocument) -> PdfDocument raise PdfError {
  recompress_pdf(document)
}

///|
/// Decode supported filter stages from every parsed stream in the document.
///
/// Encrypted documents are left unchanged. Unsupported filters are preserved
/// with their remaining encoded bytes, matching `pdf_decode_stream_until_unknown`.
pub fn PdfDocument::decompress(
  self : PdfDocument,
) -> PdfDocument raise PdfError {
  let document = self.copy()
  if !document.is_encrypted() {
    document.pdf_decode_streams_until_unknown()
  }
  document
}

///|
/// Compatibility wrapper for `PdfDocument::decompress`.
pub fn decompress_pdf(document : PdfDocument) -> PdfDocument raise PdfError {
  document.decompress()
}

///|
/// `pdf_`-prefixed compatibility alias for cpdfsqueeze's `decompress_pdf`.
pub fn pdf_decompress_pdf(document : PdfDocument) -> PdfDocument raise PdfError {
  decompress_pdf(document)
}

///|
/// Remove duplicate non-page, non-annotation objects, rewrite references to the
/// first matching object, and recompress eligible streams.
///
/// When `page_data` is true, page content streams and referenced Form XObjects
/// are parsed and serialized into normalized uncompressed streams when doing so
/// will not rewrite shared page content streams.
pub fn PdfDocument::squeeze(
  self : PdfDocument,
  page_data? : Bool = true,
) -> PdfDocument raise PdfError {
  let document = self.copy()
  let mut previous_count = -1
  while previous_count != document.object_count() {
    previous_count = document.object_count()
    document.pdf_squeeze_prune_duplicate_objects_once()
  }
  if page_data {
    document.pdf_squeeze_page_data()
  }
  document.recompress()
}

///|
/// Compatibility wrapper for `PdfDocument::squeeze`.
pub fn squeeze(
  document : PdfDocument,
  page_data? : Bool = true,
) -> PdfDocument raise PdfError {
  document.squeeze(page_data~)
}

///|
/// `pdf_`-prefixed compatibility alias for cpdfsqueeze's `squeeze`.
pub fn pdf_squeeze(
  document : PdfDocument,
  page_data? : Bool = true,
) -> PdfDocument raise PdfError {
  squeeze(document, page_data~)
}
