///|
/// Read a PDF document from a borrowed byte view.
///
/// This is the high-level non-password reader. It first tries the strict classic
/// xref reader and probes the page tree; for selected structural errors it falls
/// back to reconstruction by scanning indirect objects.
pub fn pdf_read_document_from_view(
  data : BytesView,
) -> PdfDocument raise @core.PdfError {
  pdf_read_probe_page_tree_or_reconstruct(
    data,
    pdf_read_classic_document_from_view(data),
  ) catch {
    StartXRefExpected => pdf_read_reconstructed_document_from_view(data)
    XRefExpected =>
      pdf_read_reconstructed_or_raise(
        data,
        XRefExpected,
        include_xref_stream_trailers=true,
      )
    XRefEntryExpected => pdf_read_reconstructed_after_xref_entry_error(data)
    TrailerExpected => pdf_read_reconstructed_or_raise(data, TrailerExpected)
    RootExpected => pdf_read_reconstructed_after_root_error(data)
    NumberExpected => pdf_read_reconstructed_or_raise(data, NumberExpected)
    ParseIndirectObjectExpected =>
      pdf_read_reconstructed_or_raise(data, ParseIndirectObjectExpected)
    ParseStreamExpected =>
      pdf_read_reconstructed_after_stream_parse_error(data, ParseStreamExpected)
    ParseEndStreamExpected =>
      pdf_read_reconstructed_after_stream_parse_error(
        data,
        ParseEndStreamExpected,
      )
    ParseEndObjectExpected =>
      pdf_read_reconstructed_after_stream_parse_error(
        data,
        ParseEndObjectExpected,
      )
    EndOfInput => pdf_read_reconstructed_or_raise(data, EndOfInput)
    ParseObjectExpected =>
      pdf_read_reconstructed_or_raise(data, ParseObjectExpected)
    InvalidHexEscape => pdf_read_reconstructed_or_raise(data, InvalidHexEscape)
    StreamDataExpected => pdf_read_reconstructed_after_stream_data_error(data)
    InvalidCursorPosition(position) =>
      pdf_read_reconstructed_or_raise(
        data,
        InvalidCursorPosition(position),
        include_xref_stream_trailers=true,
      )
    FilterNotSupported(filter) =>
      pdf_read_reconstructed_after_metadata_decode_error(
        data,
        FilterNotSupported(filter),
      )
    PredictorExpected =>
      pdf_read_reconstructed_after_metadata_decode_error(
        data,
        PredictorExpected,
      )
    PredictorNotSupported(predictor) =>
      pdf_read_reconstructed_after_metadata_decode_error(
        data,
        PredictorNotSupported(predictor),
      )
    error => raise error
  }
}
