///|
/// Construct a PDF array from a read-only view of object values.
///
/// The outer array is newly allocated, but the contained `PdfObject` values are
/// copied by value rather than deep-copied.
pub fn pdf_array(values : ArrayView[PdfObject]) -> PdfObject {
  let output : Array[PdfObject] = Array::new(capacity=values.length())
  for value in values {
    output.push(value)
  }
  PdfArray(output)
}

///|
/// Construct a PDF dictionary from a read-only view of name/value entries.
///
/// Entry order is preserved exactly as supplied. Duplicate keys are not
/// normalized by this constructor; lookup helpers return the first matching
/// entry.
pub fn pdf_dictionary(
  entries : ArrayView[(@core.PdfName, PdfObject)],
) -> PdfObject {
  let output : Array[(@core.PdfName, PdfObject)] = Array::new(
    capacity=entries.length(),
  )
  for entry in entries {
    output.push(entry)
  }
  PdfDictionary(output)
}

///|
/// Apply a one-level transformation to array elements.
///
/// This helper does not recursively traverse nested dictionaries or arrays by
/// itself; callers provide a `transform` that decides how each child object is
/// rewritten.
pub fn pdf_recurse_array(
  transform : (PdfObject) -> PdfObject,
  values : ArrayView[PdfObject],
) -> PdfObject {
  let output : Array[PdfObject] = Array::new(capacity=values.length())
  for value in values {
    output.push(transform(value))
  }
  PdfArray(output)
}

///|
/// Apply a one-level transformation to dictionary values.
///
/// By default the resulting dictionary entries are reversed to match the
/// historical CamlPDF construction order. Pass `preserve_order=true` when the
/// incoming order must be retained.
pub fn pdf_recurse_dict(
  transform : (PdfObject) -> PdfObject,
  entries : ArrayView[(@core.PdfName, PdfObject)],
  preserve_order? : Bool = false,
) -> PdfObject {
  let transformed : Array[(@core.PdfName, PdfObject)] = Array::new(
    capacity=entries.length(),
  )
  for entry in entries {
    transformed.push((entry.0, transform(entry.1)))
  }
  if preserve_order {
    PdfDictionary(transformed)
  } else {
    PdfDictionary(transformed.rev())
  }
}

///|
/// Construct a PDF stream object from a dictionary object and stream data.
///
/// The dictionary is stored as supplied. It is normally a `PdfDictionary`, but
/// malformed inputs can carry other objects and will be reported by helpers that
/// require dictionary metadata.
pub fn pdf_stream(dictionary : PdfObject, data : PdfStreamData) -> PdfObject {
  PdfStreamObject({ dictionary, data })
}

///|
/// Construct a deferred stream-data descriptor without encryption.
///
/// The returned value references `input` and reads `length` bytes starting at
/// `position` when materialized.
pub fn stream_to_get(
  input : @core.ByteCursor,
  position : Int,
  length : Int,
) -> ToGet {
  { input, position, length, crypt: PdfStreamDataNoCrypt }
}
