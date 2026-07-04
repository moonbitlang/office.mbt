///|
/// Append an incremental update using the selected xref representation.
pub fn pdf_write_document_incremental_update_with_mode(
  original : @core.PdfBytes,
  document : PdfDocument,
  mode : @writer.PdfWriteMode,
) -> @core.PdfBytes raise @core.PdfError {
  match mode {
    PdfWriteClassic => pdf_write_document_incremental_update(original, document)
    PdfWriteXRefStream =>
      pdf_write_document_incremental_update_with_xref_stream(original, document)
    PdfWriteCompressedXRefStream =>
      pdf_write_document_incremental_update_with_compressed_xref_stream(
        original, document,
      )
  }
}

///|
/// Append an incremental update after generating a current trailer ID.
///
/// The generated ID is based on `path` and current document state and is
/// applied to a copy of the document before writing.
pub fn pdf_write_document_incremental_update_with_generated_id(
  original : @core.PdfBytes,
  document : PdfDocument,
  path : String,
  mode? : @writer.PdfWriteMode = PdfWriteClassic,
) -> @core.PdfBytes raise @core.PdfError {
  pdf_write_document_incremental_update_with_mode(
    original,
    document.copy_with_current_id(path),
    mode,
  )
}

///|
/// Serialize a complete document using the selected xref representation.
pub fn pdf_write_document_with_mode(
  document : PdfDocument,
  mode : @writer.PdfWriteMode,
) -> @core.PdfBytes raise @core.PdfError {
  match mode {
    PdfWriteClassic => pdf_write_document(document)
    PdfWriteXRefStream => pdf_write_document_with_xref_stream(document)
    PdfWriteCompressedXRefStream =>
      pdf_write_document_with_compressed_xref_stream(document)
  }
}

///|
/// Serialize a complete document after generating a current trailer ID.
///
/// The source document is copied before its ID is generated.
pub fn pdf_write_document_with_generated_id(
  document : PdfDocument,
  path : String,
  mode? : @writer.PdfWriteMode = PdfWriteClassic,
) -> @core.PdfBytes raise @core.PdfError {
  pdf_write_document_with_mode(document.copy_with_current_id(path), mode)
}
