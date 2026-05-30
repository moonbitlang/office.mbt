///|
fn pdf_decodeparms_value(dictionary : @syntax.PdfObject) -> @syntax.PdfObject? {
  match dictionary.lookup_immediate(pdf_decodeparms_key()) {
    Some(value) => Some(value)
    None => dictionary.lookup_immediate(pdf_short_decodeparms_key())
  }
}

///|
fn pdf_first_decodeparms(
  dictionary : @syntax.PdfObject,
) -> @syntax.PdfObject? raise @core.PdfError {
  match pdf_decodeparms_value(dictionary) {
    None | Some(PdfNull) | Some(PdfArray([])) => None
    Some(PdfDictionary(_) as value) => Some(value)
    Some(PdfArray([PdfNull, ..])) => None
    Some(PdfArray([PdfDictionary(_) as value, ..])) => Some(value)
    _ => raise PredictorExpected
  }
}

///|
fn PdfDocument::pdf_decodeparms_value_direct(
  self : PdfDocument,
  dictionary : @syntax.PdfObject,
) -> @syntax.PdfObject? {
  match self.pdf_decodeparms_entry_direct(dictionary) {
    Some((_, value)) => Some(value)
    None => None
  }
}

///|
fn PdfDocument::pdf_decodeparms_entry_direct(
  self : PdfDocument,
  dictionary : @syntax.PdfObject,
) -> (@core.PdfName, @syntax.PdfObject)? {
  match self.lookup_direct(pdf_decodeparms_key(), dictionary) {
    Some(value) => Some((pdf_decodeparms_key(), value))
    None =>
      match self.lookup_direct(pdf_short_decodeparms_key(), dictionary) {
        Some(value) => Some((pdf_short_decodeparms_key(), value))
        None => None
      }
  }
}

///|
fn PdfDocument::pdf_first_decodeparms_direct(
  self : PdfDocument,
  dictionary : @syntax.PdfObject,
) -> @syntax.PdfObject? raise @core.PdfError {
  match self.pdf_decodeparms_value_direct(dictionary) {
    None | Some(PdfNull) | Some(PdfArray([])) => None
    Some(PdfDictionary(_) as value) => Some(value)
    Some(PdfArray([first, ..])) =>
      match self.direct(first) {
        PdfNull => None
        PdfDictionary(_) as value => Some(value)
        _ => raise PredictorExpected
      }
    _ => raise PredictorExpected
  }
}

///|
fn pdf_decodeparms_int(
  dictionary : @syntax.PdfObject,
  key : @core.PdfName,
  default : Int,
) -> Int raise @core.PdfError {
  match dictionary.lookup_immediate(key) {
    None => default
    Some(PdfInteger(value)) => value
    _ => raise PredictorExpected
  }
}

///|
fn PdfDocument::pdf_decodeparms_int_direct(
  self : PdfDocument,
  dictionary : @syntax.PdfObject,
  key : @core.PdfName,
  default : Int,
) -> Int raise @core.PdfError {
  match self.lookup_direct(key, dictionary) {
    None => default
    Some(PdfInteger(value)) => value
    _ => raise PredictorExpected
  }
}
