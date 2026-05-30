///|
fn pdf_stream_dictionary_length(
  dictionary : @syntax.PdfObject,
) -> Unit raise PdfError {
  match dictionary.lookup_immediate(pdf_codec_length_key()) {
    Some(PdfInteger(_)) => ()
    _ => raise StreamLengthExpected
  }
}

///|
fn pdf_stream_filter_value(
  dictionary : @syntax.PdfObject,
) -> @syntax.PdfObject? {
  match dictionary.lookup_immediate(pdf_filter_key()) {
    Some(value) => Some(value)
    None => dictionary.lookup_immediate(pdf_short_filter_key())
  }
}

///|
fn pdf_stream_first_filter(
  dictionary : @syntax.PdfObject,
) -> PdfName? raise PdfError {
  match pdf_stream_filter_value(dictionary) {
    None => None
    Some(PdfNameObject(name)) => Some(name)
    Some(PdfArray([])) => None
    Some(PdfArray([PdfNameObject(name), ..])) => Some(name)
    _ => raise FilterExpected
  }
}

///|
fn PdfDocument::pdf_stream_filter_entry_direct(
  self : PdfDocument,
  dictionary : @syntax.PdfObject,
) -> (PdfName, @syntax.PdfObject)? {
  match self.lookup_direct(pdf_filter_key(), dictionary) {
    Some(value) => Some((pdf_filter_key(), value))
    None =>
      match self.lookup_direct(pdf_short_filter_key(), dictionary) {
        Some(value) => Some((pdf_short_filter_key(), value))
        None => None
      }
  }
}

///|
fn PdfDocument::pdf_stream_first_filter_direct(
  self : PdfDocument,
  dictionary : @syntax.PdfObject,
) -> PdfName? raise PdfError {
  match self.pdf_stream_first_filter_entry_direct(dictionary) {
    Some((_, _, name)) => Some(name)
    None => None
  }
}

///|
fn PdfDocument::pdf_stream_first_filter_entry_direct(
  self : PdfDocument,
  dictionary : @syntax.PdfObject,
) -> (PdfName, @syntax.PdfObject, PdfName)? raise PdfError {
  match self.pdf_stream_filter_entry_direct(dictionary) {
    None => None
    Some((key, PdfNameObject(name) as value)) => Some((key, value, name))
    Some((_, PdfArray([]))) => None
    Some((key, PdfArray([first, ..]) as value)) =>
      match self.direct(first) {
        PdfNameObject(name) => Some((key, value, name))
        _ => raise FilterExpected
      }
    _ => raise FilterExpected
  }
}
