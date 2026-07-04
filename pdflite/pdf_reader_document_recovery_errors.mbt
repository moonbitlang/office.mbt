///|
fn pdf_read_reconstructed_after_stream_parse_error(
  data : BytesView,
  error : @core.PdfError,
) -> PdfDocument raise @core.PdfError {
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
fn pdf_read_reconstructed_after_xref_entry_error(
  data : BytesView,
) -> PdfDocument raise @core.PdfError {
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
}

///|
fn pdf_read_reconstructed_after_root_error(
  data : BytesView,
) -> PdfDocument raise @core.PdfError {
  if pdf_reader_startxref_uses_xref_stream_or_false(data) {
    pdf_read_reconstructed_or_raise(
      data,
      RootExpected,
      include_xref_stream_trailers=true,
    )
  } else {
    pdf_read_reconstructed_or_raise(data, RootExpected)
  }
}

///|
fn pdf_read_reconstructed_after_stream_data_error(
  data : BytesView,
) -> PdfDocument raise @core.PdfError {
  if pdf_reader_startxref_root_uses_object_stream_or_false(data) {
    pdf_read_reconstructed_or_raise(
      data,
      StreamDataExpected,
      include_xref_stream_trailers=true,
    )
  } else {
    raise StreamDataExpected
  }
}

///|
fn pdf_read_reconstructed_after_metadata_decode_error(
  data : BytesView,
  error : @core.PdfError,
) -> PdfDocument raise @core.PdfError {
  if pdf_reader_xref_metadata_error_allows_reconstruction(data, error) ||
    pdf_reader_object_stream_error_allows_reconstruction(data) {
    pdf_read_reconstructed_or_raise(
      data,
      error,
      include_xref_stream_trailers=true,
    )
  } else {
    raise error
  }
}
