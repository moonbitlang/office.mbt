///|
/// Return the number of entries in the document object table.
pub fn PdfDocument::object_count(self : PdfDocument) -> Int {
  self.objects.length()
}

///|
/// Return document object numbers in ascending order.
pub fn PdfDocument::object_numbers(self : PdfDocument) -> Array[Int] {
  self.objects.object_numbers()
}

///|
/// Return parsed object numbers whose objects satisfy `predicate`.
///
/// Deferred objects are not loaded by this helper. Results follow ascending
/// object-number order.
pub fn PdfDocument::select_object_numbers(
  self : PdfDocument,
  predicate : (PdfObject) -> Bool,
) -> Array[Int] {
  let selected : Array[Int] = Array::new(capacity=self.object_count())
  for entry in self.parsed_object_entries() {
    if predicate(entry.2) {
      selected.push(entry.0)
    }
  }
  selected
}

///|
/// Transform every parsed document object in place.
///
/// Deferred entries remain deferred and are not passed to `transform`.
pub fn PdfDocument::map_objects_in_place(
  self : PdfDocument,
  transform : (PdfObject) -> PdfObject,
) -> Unit {
  self.objects.map_objects_in_place(transform)
}

///|
/// Return parsed document objects as sorted `(number, generation, object)` triples.
pub fn PdfDocument::parsed_object_entries(
  self : PdfDocument,
) -> Array[(Int, Int, PdfObject)] {
  self.objects.parsed_entries()
}

///|
/// Iterate over parsed objects in object-number order.
///
/// The callback receives `(number, object)`. Errors raised by the callback
/// propagate to the caller.
pub fn PdfDocument::iter_objects(
  self : PdfDocument,
  callback : (Int, PdfObject) -> Unit raise,
) -> Unit raise {
  self.iter_objects_in_order(callback)
}

///|
/// Iterate over parsed objects in object-number order.
///
/// This is the explicit-order variant used by `iter_objects`.
pub fn PdfDocument::iter_objects_in_order(
  self : PdfDocument,
  callback : (Int, PdfObject) -> Unit raise,
) -> Unit raise {
  for entry in self.parsed_object_entries() {
    callback(entry.0, entry.2)
  }
}

///|
/// Iterate over parsed objects with their generation numbers.
///
/// The callback receives `(number, generation, object)` in object-number order,
/// and any callback error is propagated.
pub fn PdfDocument::iter_objects_with_generation(
  self : PdfDocument,
  callback : (Int, Int, PdfObject) -> Unit raise,
) -> Unit raise {
  for entry in self.parsed_object_entries() {
    callback(entry.0, entry.1, entry.2)
  }
}

///|
/// Return parsed stream-object entries in object-number order.
pub fn PdfDocument::stream_object_entries(
  self : PdfDocument,
) -> Array[(Int, Int, PdfStream)] {
  self.objects.stream_entries()
}

///|
/// Iterate over parsed stream objects in object-number order.
///
/// The callback receives the stream as a `PdfObject` so callers can use the same
/// object-level helpers as for values read from arrays or dictionaries.
pub fn PdfDocument::iter_stream(
  self : PdfDocument,
  callback : (PdfObject) -> Unit raise,
) -> Unit raise {
  for entry in self.parsed_object_entries() {
    match entry.2 {
      PdfStreamObject(_) as stream => callback(stream)
      _ => ()
    }
  }
}
