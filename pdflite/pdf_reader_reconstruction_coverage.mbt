///|
fn pdf_reconstructed_classic_xref_entry_is_verified(
  data : BytesView,
  entries : ArrayView[@reader.PdfClassicXRefEntry],
  xref_index : @reader.PdfClassicXRefIndex,
  xref : @reader.PdfClassicXRefEntry,
) -> Bool {
  if !xref.in_use {
    true
  } else {
    let cursor = @core.byte_cursor_of_view(data)
    try {
      cursor.seek_absolute(xref.offset)
      let parsed = pdf_cursor_read_first_indirect_object_at_current(
        cursor,
        entries,
        xref_index=Some(xref_index),
      )
      parsed.number == xref.object_number &&
      parsed.generation == xref.generation
    } catch {
      _ => false
    }
  }
}
