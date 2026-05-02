///|
pub(all) struct ObjectStreamReference {
  object_stream_number : Int
  index : Int
} derive(Debug, Eq, ToJson)

///|
pub(all) enum PdfObjectData {
  ObjectParsed(PdfObject)
  ObjectParsedAlreadyDecrypted(PdfObject)
  ObjectToParse
  ObjectToParseFromObjectStream(ObjectStreamReference)
} derive(Debug, Eq, ToJson)

///|
pub(all) struct PdfObjectEntry {
  mut data : PdfObjectData
  generation : Int
} derive(Debug, Eq, ToJson)

///|
pub(all) enum PdfObjectEvent {
  ObjectAltered
  ObjectDeleted
} derive(Debug, Eq, ToJson)

///|
pub struct PdfObjectMap {
  entries : @hashmap.HashMap[Int, PdfObjectEntry]
} derive(Debug, Eq, ToJson)

///|
pub struct PdfObjects {
  mut max_object_number : Int
  object_map : PdfObjectMap
  object_stream_ids : @hashmap.HashMap[Int, Int]
  log : Array[(Int, PdfObjectEvent)]
} derive(Debug, Eq, ToJson)

///|
pub struct PdfDocument {
  mut major : Int
  mut minor : Int
  mut root : Int
  objects : PdfObjects
  mut trailer_dict : PdfObject
  mut was_linearized : Bool
  mut saved_encryption : PdfSavedEncryption?
  mut first_xref : Int
  mut revision_read : Int
} derive(Debug, Eq, ToJson)

///|
pub fn pdf_object_entry(
  data : PdfObjectData,
  generation? : Int = 0,
) -> PdfObjectEntry {
  { data, generation }
}

///|
pub fn pdf_object_map_empty() -> PdfObjectMap {
  { entries: @hashmap.HashMap::new() }
}

///|
pub fn PdfObjectMap::length(self : PdfObjectMap) -> Int {
  self.entries.length()
}

///|
pub fn PdfObjectMap::contains(self : PdfObjectMap, number : Int) -> Bool {
  self.entries.contains(number)
}

///|
pub fn PdfObjectMap::get_entry(
  self : PdfObjectMap,
  number : Int,
) -> PdfObjectEntry? {
  self.entries.get(number)
}

///|
pub fn PdfObjectMap::set_entry(
  self : PdfObjectMap,
  number : Int,
  entry : PdfObjectEntry,
) -> Unit {
  self.entries[number] = entry
}

///|
pub fn PdfObjectMap::remove(self : PdfObjectMap, number : Int) -> Unit {
  self.entries.remove(number)
}

///|
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
    output.set_entry(number, { data: entry.data, generation: entry.generation })
  }
  output
}

///|
pub fn PdfObjectMap::lookup_parsed_or_null(
  self : PdfObjectMap,
  number : Int,
) -> PdfObject {
  match self.get_entry(number) {
    Some({ data: ObjectParsed(object), .. }) => object
    Some({ data: ObjectParsedAlreadyDecrypted(object), .. }) => object
    _ => PdfNull
  }
}

///|
pub fn pdf_objects_empty() -> PdfObjects {
  {
    max_object_number: 0,
    object_map: pdf_object_map_empty(),
    object_stream_ids: @hashmap.HashMap::new(),
    log: [],
  }
}

///|
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
pub fn PdfObjects::length(self : PdfObjects) -> Int {
  self.object_map.length()
}

///|
pub fn PdfObjects::object_numbers(self : PdfObjects) -> Array[Int] {
  self.object_map.object_numbers()
}

///|
pub fn PdfObjects::map_objects_in_place(
  self : PdfObjects,
  transform : (PdfObject) -> PdfObject,
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
pub fn PdfObjects::parsed_entries(
  self : PdfObjects,
) -> Array[(Int, Int, PdfObject)] {
  let entries : Array[(Int, Int, PdfObject)] = []
  for number in self.object_numbers() {
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
pub fn PdfObjects::stream_entries(
  self : PdfObjects,
) -> Array[(Int, Int, PdfStream)] {
  let entries : Array[(Int, Int, PdfStream)] = []
  for entry in self.parsed_entries() {
    match entry.2 {
      PdfStreamObject(stream) => entries.push((entry.0, entry.1, stream))
      _ => ()
    }
  }
  entries
}

///|
fn PdfObjects::copy(self : PdfObjects) -> PdfObjects {
  let object_stream_ids : @hashmap.HashMap[Int, Int] = @hashmap.HashMap::new()
  for number in self.object_stream_ids.keys().to_array() {
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
pub fn PdfObjects::max_object_number(self : PdfObjects) -> Int {
  self.max_object_number
}

///|
pub fn PdfObjects::log(self : PdfObjects) -> Array[(Int, PdfObjectEvent)] {
  self.log.copy()
}

///|
pub fn PdfObjects::get_entry(
  self : PdfObjects,
  number : Int,
) -> PdfObjectEntry? {
  self.object_map.get_entry(number)
}

///|
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
pub fn PdfObjects::add_object_given_number(
  self : PdfObjects,
  number : Int,
  object : PdfObject,
  generation? : Int = 0,
) -> Unit {
  self.set_entry(number, pdf_object_entry(ObjectParsed(object), generation~))
  self.log.push((number, ObjectAltered))
}

///|
fn PdfObjects::load_object_given_number(
  self : PdfObjects,
  number : Int,
  object : PdfObject,
  generation? : Int = 0,
) -> Unit {
  self.set_entry(number, pdf_object_entry(ObjectParsed(object), generation~))
}

///|
pub fn PdfObjects::add_object(
  self : PdfObjects,
  object : PdfObject,
  generation? : Int = 0,
) -> Int {
  let number = self.max_object_number + 1
  self.add_object_given_number(number, object, generation~)
  number
}

///|
pub fn PdfObjects::remove_object(self : PdfObjects, number : Int) -> Unit {
  self.object_map.remove(number)
  self.log.push((number, ObjectDeleted))
}

///|
pub fn PdfObjects::lookup_object_or_null(
  self : PdfObjects,
  number : Int,
) -> PdfObject {
  self.object_map.lookup_parsed_or_null(number)
}

///|
pub fn pdf_document_empty() -> PdfDocument {
  {
    major: 1,
    minor: 0,
    root: 0,
    objects: pdf_objects_empty(),
    trailer_dict: PdfDictionary([]),
    was_linearized: false,
    saved_encryption: None,
    first_xref: 0,
    revision_read: 1,
  }
}

///|
pub fn PdfDocument::copy(self : PdfDocument) -> PdfDocument {
  {
    major: self.major,
    minor: self.minor,
    root: self.root,
    objects: self.objects.copy(),
    trailer_dict: self.trailer_dict,
    was_linearized: self.was_linearized,
    saved_encryption: self.saved_encryption,
    first_xref: self.first_xref,
    revision_read: self.revision_read,
  }
}

///|
pub fn PdfDocument::version(self : PdfDocument) -> (Int, Int) {
  (self.major, self.minor)
}

///|
pub fn PdfDocument::set_version(
  self : PdfDocument,
  major : Int,
  minor : Int,
) -> Unit {
  self.major = major
  self.minor = minor
}

///|
pub fn PdfDocument::root(self : PdfDocument) -> Int {
  self.root
}

///|
pub fn PdfDocument::catalog(self : PdfDocument) -> PdfObject raise PdfError {
  let object = self.lookup_object_or_null(self.root)
  if object == PdfNull {
    raise RootExpected
  }
  object
}

///|
pub fn PdfDocument::set_root(self : PdfDocument, root : Int) -> Unit {
  self.root = root
}

///|
pub fn PdfDocument::trailer_dict(self : PdfDocument) -> PdfObject {
  self.trailer_dict
}

///|
pub fn PdfDocument::set_trailer_dict(
  self : PdfDocument,
  trailer_dict : PdfObject,
) -> Unit {
  self.trailer_dict = trailer_dict
}

///|
pub fn PdfDocument::object_count(self : PdfDocument) -> Int {
  self.objects.length()
}

///|
pub fn PdfDocument::object_numbers(self : PdfDocument) -> Array[Int] {
  self.objects.object_numbers()
}

///|
pub fn PdfDocument::select_object_numbers(
  self : PdfDocument,
  predicate : (PdfObject) -> Bool,
) -> Array[Int] {
  let selected : Array[Int] = []
  for number in self.object_numbers() {
    let object = self.lookup_object_or_null(number)
    if predicate(object) {
      selected.push(number)
    }
  }
  selected
}

///|
pub fn PdfDocument::map_objects_in_place(
  self : PdfDocument,
  transform : (PdfObject) -> PdfObject,
) -> Unit {
  self.objects.map_objects_in_place(transform)
}

///|
pub fn PdfDocument::parsed_object_entries(
  self : PdfDocument,
) -> Array[(Int, Int, PdfObject)] {
  self.objects.parsed_entries()
}

///|
pub fn PdfDocument::stream_object_entries(
  self : PdfDocument,
) -> Array[(Int, Int, PdfStream)] {
  self.objects.stream_entries()
}

///|
pub fn PdfDocument::add_object(
  self : PdfDocument,
  object : PdfObject,
  generation? : Int = 0,
) -> Int {
  self.objects.add_object(object, generation~)
}

///|
pub fn PdfDocument::add_object_given_number(
  self : PdfDocument,
  number : Int,
  object : PdfObject,
  generation? : Int = 0,
) -> Unit {
  self.objects.add_object_given_number(number, object, generation~)
}

///|
fn PdfDocument::load_object_given_number(
  self : PdfDocument,
  number : Int,
  object : PdfObject,
  generation? : Int = 0,
) -> Unit {
  self.objects.load_object_given_number(number, object, generation~)
}

///|
pub fn PdfDocument::remove_object(self : PdfDocument, number : Int) -> Unit {
  self.objects.remove_object(number)
}

///|
pub fn PdfDocument::lookup_object_or_null(
  self : PdfDocument,
  number : Int,
) -> PdfObject {
  self.objects.lookup_object_or_null(number)
}

///|
pub fn PdfDocument::event_log(
  self : PdfDocument,
) -> Array[(Int, PdfObjectEvent)] {
  self.objects.log()
}

///|
pub fn PdfDocument::was_linearized(self : PdfDocument) -> Bool {
  self.was_linearized
}

///|
pub fn PdfDocument::set_was_linearized(
  self : PdfDocument,
  was_linearized : Bool,
) -> Unit {
  self.was_linearized = was_linearized
}

///|
pub fn PdfDocument::saved_encryption(self : PdfDocument) -> PdfSavedEncryption? {
  self.saved_encryption
}

///|
pub fn PdfDocument::set_saved_encryption(
  self : PdfDocument,
  saved_encryption : PdfSavedEncryption?,
) -> Unit {
  self.saved_encryption = saved_encryption
}

///|
pub fn PdfDocument::first_xref(self : PdfDocument) -> Int {
  self.first_xref
}

///|
pub fn PdfDocument::set_first_xref(
  self : PdfDocument,
  first_xref : Int,
) -> Unit {
  self.first_xref = first_xref
}

///|
pub fn PdfDocument::revision_read(self : PdfDocument) -> Int {
  self.revision_read
}

///|
pub fn PdfDocument::set_revision_read(
  self : PdfDocument,
  revision_read : Int,
) -> Unit {
  self.revision_read = revision_read
}
