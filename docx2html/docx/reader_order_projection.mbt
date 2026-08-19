// Canonical physical-coordinate machinery shared by the reader-native
// projection: byte spans, the field-carrier event stream, and the span
// helpers. The legacy walker's own DTO types live with the walker in
// `reader_order_legacy_wbtest.mbt` (#434 PR 6d) until PR 7 deletes them;
// renaming what remains to Reader* spellings is PR 7 cleanup.

///|
#warnings("-unused_field")
priv struct ReaderOrderSourceSpan {
  byte_start : Int
  byte_end : Int
}

///|
/// One direct physical paragraph child observed at the same point where
/// BodyReader begins interpreting that carrier. Keeping this event stream on
/// the N0b2 walk preserves recursive block order for N0b3 without reconstructing
/// it from the completed paragraph segments. Each event follows a charged N0b2
/// node visit, so the reader-order visit budget also bounds retained events.
priv struct ReaderOrderFieldCarrierEvent {
  paragraph_identity : Int
  carrier_identity : Int
}

///|
fn reader_order_element_span(element : ScannedElement) -> ReaderOrderSourceSpan {
  { byte_start: element.byte_start, byte_end: element.byte_end }
}

///|
fn reader_order_atom_span(element : ScannedElement) -> ReaderOrderSourceSpan {
  if is_wml_uri(element.uri) &&
    element.local_name == "t" &&
    element.text_map is Some(_) {
    { byte_start: element.content_start, byte_end: element.content_end }
  } else {
    reader_order_element_span(element)
  }
}
