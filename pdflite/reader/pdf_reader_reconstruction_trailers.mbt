///|
/// Scan a byte view for reconstructed trailer dictionaries.
///
/// The caller supplies parser callbacks because xref-stream trailer extraction
/// depends on higher-level indirect-object parsing outside this package.
pub fn pdf_reader_reconstruction_trailers(
  data : BytesView,
  include_xref_streams : Bool,
  read_trailer_at : (@core.ByteCursor, Int) -> @syntax.PdfObject raise @core.PdfError,
  read_xref_stream_trailer_at : (@core.ByteCursor, Int) -> @syntax.PdfObject raise @core.PdfError,
) -> Array[@syntax.PdfObject] {
  let trailers : Array[@syntax.PdfObject] = Array::new(capacity=1)
  let cursor = @core.byte_cursor_of_view(data)
  for position in 0..<data.length() {
    if @core.pdf_view_matches_ascii_at(data, position, [
        116, 114, 97, 105, 108, 101, 114,
      ]) {
      let trailer : Result[@syntax.PdfObject, Error] = try? read_trailer_at(
        cursor, position,
      )
      match trailer {
        Ok(object) => trailers.push(object)
        Err(_) => ()
      }
    } else if include_xref_streams &&
      pdf_reader_reconstruction_indirect_header_at(data, position) {
      let trailer : Result[@syntax.PdfObject, Error] = try? read_xref_stream_trailer_at(
        cursor, position,
      )
      match trailer {
        Ok(object) => trailers.push(object)
        Err(_) => ()
      }
    }
  }
  trailers
}
