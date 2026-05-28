///|
fn pdf_read_reconstructed_after_stream_parse_error(
  data : BytesView,
  error : PdfError,
) -> PdfDocument raise PdfError {
  if pdf_reader_startxref_has_xref_stream_prefix_or_false(data) {
    pdf_read_reconstructed_or_raise(
      data,
      error,
      include_xref_stream_trailers=true,
    )
  } else {
    pdf_read_reconstructed_or_raise(data, error)
  }
}

///|
/// Read a PDF document from a borrowed byte view.
///
/// This is the high-level non-password reader. It first tries the strict classic
/// xref reader and probes the page tree; for selected structural errors it falls
/// back to reconstruction by scanning indirect objects.
pub fn pdf_read_document_from_view(
  data : BytesView,
) -> PdfDocument raise PdfError {
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
    XRefEntryExpected =>
      if pdf_reader_xref_entry_error_from_metadata(data) {
        pdf_read_reconstructed_or_raise(
          data,
          XRefEntryExpected,
          include_xref_stream_trailers=true,
        )
      } else if pdf_reader_startxref_root_uses_object_stream_or_false(data) {
        if pdf_reader_startxref_object_stream_root_unusable_or_true(data) {
          raise XRefEntryExpected
        } else {
          pdf_read_reconstructed_or_raise(
            data,
            XRefEntryExpected,
            include_xref_stream_trailers=true,
          )
        }
      } else {
        pdf_read_reconstructed_or_raise(data, XRefEntryExpected)
      }
    TrailerExpected => pdf_read_reconstructed_or_raise(data, TrailerExpected)
    RootExpected =>
      if pdf_reader_startxref_uses_xref_stream_or_false(data) {
        pdf_read_reconstructed_or_raise(
          data,
          RootExpected,
          include_xref_stream_trailers=true,
        )
      } else {
        pdf_read_reconstructed_or_raise(data, RootExpected)
      }
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
    StreamDataExpected =>
      if pdf_reader_startxref_root_uses_object_stream_or_false(data) {
        pdf_read_reconstructed_or_raise(
          data,
          StreamDataExpected,
          include_xref_stream_trailers=true,
        )
      } else {
        raise StreamDataExpected
      }
    InvalidCursorPosition(position) =>
      pdf_read_reconstructed_or_raise(
        data,
        InvalidCursorPosition(position),
        include_xref_stream_trailers=true,
      )
    FilterNotSupported(filter) =>
      if pdf_reader_xref_metadata_error_allows_reconstruction(
          data,
          FilterNotSupported(filter),
        ) {
        pdf_read_reconstructed_or_raise(
          data,
          FilterNotSupported(filter),
          include_xref_stream_trailers=true,
        )
      } else if pdf_reader_object_stream_error_allows_reconstruction(data) {
        pdf_read_reconstructed_or_raise(
          data,
          FilterNotSupported(filter),
          include_xref_stream_trailers=true,
        )
      } else {
        raise FilterNotSupported(filter)
      }
    PredictorExpected =>
      if pdf_reader_xref_metadata_error_allows_reconstruction(
          data,
          PredictorExpected,
        ) {
        pdf_read_reconstructed_or_raise(
          data,
          PredictorExpected,
          include_xref_stream_trailers=true,
        )
      } else if pdf_reader_object_stream_error_allows_reconstruction(data) {
        pdf_read_reconstructed_or_raise(
          data,
          PredictorExpected,
          include_xref_stream_trailers=true,
        )
      } else {
        raise PredictorExpected
      }
    PredictorNotSupported(predictor) =>
      if pdf_reader_xref_metadata_error_allows_reconstruction(
          data,
          PredictorNotSupported(predictor),
        ) {
        pdf_read_reconstructed_or_raise(
          data,
          PredictorNotSupported(predictor),
          include_xref_stream_trailers=true,
        )
      } else if pdf_reader_object_stream_error_allows_reconstruction(data) {
        pdf_read_reconstructed_or_raise(
          data,
          PredictorNotSupported(predictor),
          include_xref_stream_trailers=true,
        )
      } else {
        raise PredictorNotSupported(predictor)
      }
    error => raise error
  }
}
