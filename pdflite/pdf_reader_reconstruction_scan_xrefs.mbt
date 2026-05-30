///|
fn pdf_cursor_read_reconstructed_xref_at_current(
  cursor : ByteCursor,
  position : Int,
  xrefs : ArrayView[@reader.PdfClassicXRefEntry],
  xref_index : @reader.PdfClassicXRefIndex,
) -> (@reader.PdfClassicXRefEntry?, Int?) raise PdfError {
  let (object, next_position) = pdf_cursor_read_reconstructed_indirect_scan_candidate_at_current(
    cursor,
    xrefs,
    xref_index=Some(xref_index),
  )
  if object.number > 0 {
    (
      Some({
        object_number: object.number,
        offset: position,
        generation: object.generation,
        in_use: true,
        object_stream: None,
      }),
      next_position,
    )
  } else {
    (None, next_position)
  }
}
