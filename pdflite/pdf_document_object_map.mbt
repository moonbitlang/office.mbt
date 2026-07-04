///|
/// Construct an object-table entry.
///
/// The generation defaults to `0`, matching newly created PDF objects.
pub fn pdf_object_entry(
  data : PdfObjectData,
  generation? : Int = 0,
) -> PdfObjectEntry {
  { data, generation }
}

///|
/// Construct an empty object-number map.
pub fn pdf_object_map_empty() -> PdfObjectMap {
  { entries: HashMap([]) }
}

///|
/// Return the number of entries in the object map.
pub fn PdfObjectMap::length(self : PdfObjectMap) -> Int {
  self.entries.length()
}

///|
/// Return whether `number` has an entry in the object map.
pub fn PdfObjectMap::contains(self : PdfObjectMap, number : Int) -> Bool {
  self.entries.contains(number)
}

///|
/// Return the object-table entry for `number`, if present.
pub fn PdfObjectMap::get_entry(
  self : PdfObjectMap,
  number : Int,
) -> PdfObjectEntry? {
  self.entries.get(number)
}

///|
/// Set or replace the entry for an object number.
///
/// This low-level map operation does not update any mutation log.
pub fn PdfObjectMap::set_entry(
  self : PdfObjectMap,
  number : Int,
  entry : PdfObjectEntry,
) -> Unit {
  self.entries[number] = entry
}

///|
/// Remove an object-number entry from the map.
///
/// Missing numbers are ignored.
pub fn PdfObjectMap::remove(self : PdfObjectMap, number : Int) -> Unit {
  self.entries.remove(number)
}

///|
/// Return all object numbers in ascending order.
pub fn PdfObjectMap::object_numbers(self : PdfObjectMap) -> Array[Int] {
  let numbers = self.entries.keys().to_array()
  numbers.sort()
  numbers
}

///|
fn PdfObjectMap::copy(self : PdfObjectMap) -> PdfObjectMap {
  let output = pdf_object_map_empty()
  for number in self.object_numbers() {
    let entry = self.get_entry(number).unwrap()
    let data = match entry.data {
      ObjectParsed(object) => ObjectParsed(object.deep_copy())
      ObjectParsedAlreadyDecrypted(object) =>
        ObjectParsedAlreadyDecrypted(object.deep_copy())
      ObjectToParse => ObjectToParse
      ObjectToParseFromObjectStream(reference) =>
        ObjectToParseFromObjectStream(reference)
    }
    output.set_entry(number, { data, generation: entry.generation })
  }
  output
}

///|
/// Return a parsed object or `PdfNull` for missing/deferred entries.
///
/// Both normal parsed objects and already-decrypted parsed objects are returned.
/// Deferred states such as `ObjectToParse` are treated as absent by this helper.
pub fn PdfObjectMap::lookup_parsed_or_null(
  self : PdfObjectMap,
  number : Int,
) -> @syntax.PdfObject {
  match self.get_entry(number) {
    Some({ data: ObjectParsed(object), .. }) => object
    Some({ data: ObjectParsedAlreadyDecrypted(object), .. }) => object
    _ => PdfNull
  }
}
