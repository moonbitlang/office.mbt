///|
/// Construct an empty document object table.
///
/// The next allocated object number will be `1`; the mutation log starts empty.
pub fn pdf_objects_empty() -> PdfObjects {
  {
    max_object_number: 0,
    object_map: pdf_object_map_empty(),
    object_stream_ids: HashMap([]),
    log: [],
  }
}

///|
/// Build a document object table from explicit numbered entries.
///
/// Entries are installed without recording alteration events. The maximum
/// object number is derived from the supplied numbers.
pub fn pdf_objects_of_entries(
  entries : ArrayView[(Int, PdfObjectEntry)],
) -> PdfObjects {
  let objects = pdf_objects_empty()
  for entry in entries {
    objects.set_entry(entry.0, entry.1)
  }
  objects
}

///|
/// Return the number of object entries currently stored.
pub fn PdfObjects::length(self : PdfObjects) -> Int {
  self.object_map.length()
}

///|
/// Return stored object numbers in ascending order.
pub fn PdfObjects::object_numbers(self : PdfObjects) -> Array[Int] {
  self.object_map.object_numbers()
}

///|
/// Transform every parsed object in place.
///
/// Parsed and already-decrypted entries keep their state tags after the object
/// value is transformed. Deferred entries are left unchanged.
pub fn PdfObjects::map_objects_in_place(
  self : PdfObjects,
  transform : (@syntax.PdfObject) -> @syntax.PdfObject,
) -> Unit {
  for number in self.object_numbers() {
    let entry = self.get_entry(number).unwrap()
    let data = match entry.data {
      ObjectParsed(object) => ObjectParsed(transform(object))
      ObjectParsedAlreadyDecrypted(object) =>
        ObjectParsedAlreadyDecrypted(transform(object))
      _ => entry.data
    }
    self.set_entry(number, { data, generation: entry.generation })
  }
}

///|
/// Return parsed object entries as `(number, generation, object)` triples.
///
/// Results are sorted by object number and exclude deferred entries.
pub fn PdfObjects::parsed_entries(
  self : PdfObjects,
) -> Array[(Int, Int, @syntax.PdfObject)] {
  let numbers = self.object_numbers()
  let entries : Array[(Int, Int, @syntax.PdfObject)] = Array::new(
    capacity=numbers.length(),
  )
  for number in numbers {
    let entry = self.get_entry(number).unwrap()
    match entry.data {
      ObjectParsed(object) => entries.push((number, entry.generation, object))
      ObjectParsedAlreadyDecrypted(object) =>
        entries.push((number, entry.generation, object))
      _ => ()
    }
  }
  entries
}

///|
/// Return parsed stream objects as `(number, generation, stream)` triples.
///
/// Results are sorted by object number and exclude non-stream or deferred
/// entries.
pub fn PdfObjects::stream_entries(
  self : PdfObjects,
) -> Array[(Int, Int, @syntax.PdfStream)] {
  let numbers = self.object_numbers()
  let entries : Array[(Int, Int, @syntax.PdfStream)] = Array::new(
    capacity=numbers.length(),
  )
  for number in numbers {
    let entry = self.get_entry(number).unwrap()
    match entry.data {
      ObjectParsed(PdfStreamObject(stream))
      | ObjectParsedAlreadyDecrypted(PdfStreamObject(stream)) =>
        entries.push((number, entry.generation, stream))
      _ => ()
    }
  }
  entries
}

///|
fn PdfObjects::copy(self : PdfObjects) -> PdfObjects {
  let object_stream_ids : @hashmap.HashMap[Int, Int] = HashMap([])
  for number in self.object_stream_ids.keys() {
    object_stream_ids[number] = self.object_stream_ids.get(number).unwrap()
  }
  {
    max_object_number: self.max_object_number,
    object_map: self.object_map.copy(),
    object_stream_ids,
    log: self.log.copy(),
  }
}

///|
/// Return the highest object number allocated or loaded so far.
pub fn PdfObjects::max_object_number(self : PdfObjects) -> Int {
  self.max_object_number
}

///|
/// Return a copy of the object mutation log.
pub fn PdfObjects::log(self : PdfObjects) -> Array[(Int, PdfObjectEvent)] {
  self.log.copy()
}

///|
/// Return the object-table entry for `number`, if present.
pub fn PdfObjects::get_entry(
  self : PdfObjects,
  number : Int,
) -> PdfObjectEntry? {
  self.object_map.get_entry(number)
}

///|
/// Set or replace an object-table entry without logging an alteration.
///
/// The tracked maximum object number is raised when `number` exceeds the
/// previous maximum.
pub fn PdfObjects::set_entry(
  self : PdfObjects,
  number : Int,
  entry : PdfObjectEntry,
) -> Unit {
  if number > self.max_object_number {
    self.max_object_number = number
  }
  self.object_map.set_entry(number, entry)
}

///|
/// Add or replace a parsed object at an explicit object number.
///
/// This updates the maximum object number, stores an `ObjectParsed` entry, and
/// appends `ObjectAltered` to the mutation log.
pub fn PdfObjects::add_object_given_number(
  self : PdfObjects,
  number : Int,
  object : @syntax.PdfObject,
  generation? : Int = 0,
) -> Unit {
  self.set_entry(number, pdf_object_entry(ObjectParsed(object), generation~))
  self.log.push((number, ObjectAltered))
}

///|
fn PdfObjects::load_object_given_number(
  self : PdfObjects,
  number : Int,
  object : @syntax.PdfObject,
  generation : Int,
) -> Unit {
  self.set_entry(number, pdf_object_entry(ObjectParsed(object), generation~))
}

///|
fn PdfObjects::load_object_given_number_already_decrypted(
  self : PdfObjects,
  number : Int,
  object : @syntax.PdfObject,
) -> Unit {
  self.set_entry(number, pdf_object_entry(ObjectParsedAlreadyDecrypted(object)))
}

///|
/// Add a parsed object using the next available object number.
///
/// Returns the allocated object number and records an `ObjectAltered` event.
pub fn PdfObjects::add_object(
  self : PdfObjects,
  object : @syntax.PdfObject,
  generation? : Int = 0,
) -> Int {
  let number = self.max_object_number + 1
  self.add_object_given_number(number, object, generation~)
  number
}

///|
/// Remove an object entry and record a deletion event.
///
/// The deletion is logged even if the object number was not present.
pub fn PdfObjects::remove_object(self : PdfObjects, number : Int) -> Unit {
  self.object_map.remove(number)
  self.log.push((number, ObjectDeleted))
}

///|
/// Return a parsed object by number, or `PdfNull` if it is absent or deferred.
pub fn PdfObjects::lookup_object_or_null(
  self : PdfObjects,
  number : Int,
) -> @syntax.PdfObject {
  self.object_map.lookup_parsed_or_null(number)
}
