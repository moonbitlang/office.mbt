///|
fn pdf_reader_reconstruction_callbacks() -> @reader.PdfReaderReconstructionCallbacks {
  {
    read_classic_xref_section_at: pdf_cursor_read_reconstructed_classic_xref_section_at,
    read_xref_stream_section_at: pdf_cursor_read_reconstructed_xref_stream_section_at,
    read_object_xref_at_current: pdf_cursor_read_reconstructed_xref_at_current,
    read_trailer_at: pdf_cursor_read_reconstructed_trailer_at,
    read_xref_stream_trailer_at: pdf_cursor_read_reconstructed_xref_stream_trailer_at,
    verify_classic_xref_entry: pdf_reconstructed_classic_xref_entry_is_verified,
  }
}
