///|
/// Location of an object stored inside a PDF object stream.
///
/// `object_stream_number` is the containing object stream number, and `index`
/// is the zero-based entry index inside that stream.
pub(all) struct ObjectStreamReference {
  object_stream_number : Int
  index : Int
} derive(Debug, Eq, ToJson)

///|
/// Loading state for one entry in the document object table.
///
/// Parsed variants hold objects that are ready to use. `ObjectToParse` marks an
/// object that is known from an xref table but has not been read yet.
/// `ObjectToParseFromObjectStream` records the object-stream location needed to
/// load compressed objects lazily.
pub(all) enum PdfObjectData {
  ObjectParsed(PdfObject)
  ObjectParsedAlreadyDecrypted(PdfObject)
  ObjectToParse
  ObjectToParseFromObjectStream(ObjectStreamReference)
} derive(Debug, Eq, ToJson)

///|
/// One object-table entry together with its generation number.
///
/// The `data` field is mutable so parsers can replace deferred states with
/// parsed objects after lazy loading.
pub(all) struct PdfObjectEntry {
  mut data : PdfObjectData
  generation : Int
} derive(Debug, Eq, ToJson)

///|
/// Mutation event recorded for incremental-write style bookkeeping.
pub(all) enum PdfObjectEvent {
  ObjectAltered
  ObjectDeleted
} derive(Debug, Eq, ToJson)

///|
/// Sparse map from object number to object-table entry.
///
/// This is a thin wrapper around a hash map. It does not track maximum object
/// number or mutation events; use `PdfObjects` for document-level bookkeeping.
pub struct PdfObjectMap {
  entries : @hashmap.HashMap[Int, PdfObjectEntry]
} derive(Debug, Eq, ToJson)

///|
/// Document object table with allocation, object-stream, and mutation metadata.
///
/// `PdfObjects` owns the sparse object map, tracks the highest object number
/// allocated so far, records object-stream identifiers, and stores an alteration
/// log used by writers and tests.
pub struct PdfObjects {
  mut max_object_number : Int
  object_map : PdfObjectMap
  object_stream_ids : @hashmap.HashMap[Int, Int]
  log : Array[(Int, PdfObjectEvent)]
} derive(Debug, Eq, ToJson)

///|
/// In-memory representation of one PDF document.
///
/// A document stores the PDF version, catalog root number, object table,
/// trailer dictionary, linearization flag, saved encryption metadata, first xref
/// offset, and the revision count read from the input.
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
fn pdf_document_name(text : String) -> PdfName {
  pdf_name_of_bytes(@ascii.encode(text))
}

///|
let pdf_document_root_key_name : PdfName = pdf_document_name("/Root")

///|
fn pdf_document_root_key() -> PdfName {
  pdf_document_root_key_name
}

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
) -> PdfObject {
  match self.get_entry(number) {
    Some({ data: ObjectParsed(object), .. }) => object
    Some({ data: ObjectParsedAlreadyDecrypted(object), .. }) => object
    _ => PdfNull
  }
}

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
/// Return parsed object entries as `(number, generation, object)` triples.
///
/// Results are sorted by object number and exclude deferred entries.
pub fn PdfObjects::parsed_entries(
  self : PdfObjects,
) -> Array[(Int, Int, PdfObject)] {
  let numbers = self.object_numbers()
  let entries : Array[(Int, Int, PdfObject)] = Array::new(
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
) -> Array[(Int, Int, PdfStream)] {
  let numbers = self.object_numbers()
  let entries : Array[(Int, Int, PdfStream)] = Array::new(
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
  generation : Int,
) -> Unit {
  self.set_entry(number, pdf_object_entry(ObjectParsed(object), generation~))
}

///|
fn PdfObjects::load_object_given_number_already_decrypted(
  self : PdfObjects,
  number : Int,
  object : PdfObject,
) -> Unit {
  self.set_entry(number, pdf_object_entry(ObjectParsedAlreadyDecrypted(object)))
}

///|
/// Add a parsed object using the next available object number.
///
/// Returns the allocated object number and records an `ObjectAltered` event.
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
) -> PdfObject {
  self.object_map.lookup_parsed_or_null(number)
}

///|
/// Construct an empty PDF document with CamlPDF-compatible defaults.
///
/// The default version is `1.0`, the root object number is `0`, the trailer is
/// an empty dictionary, and `revision_read` starts at `1`.
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
/// Deep-copy the document object table and trailer.
///
/// Parsed object containers and stream data are copied so mutations to the copy
/// do not alter the original document's object graph.
pub fn PdfDocument::copy(self : PdfDocument) -> PdfDocument {
  {
    major: self.major,
    minor: self.minor,
    root: self.root,
    objects: self.objects.copy(),
    trailer_dict: self.trailer_dict.deep_copy(),
    was_linearized: self.was_linearized,
    saved_encryption: self.saved_encryption,
    first_xref: self.first_xref,
    revision_read: self.revision_read,
  }
}

///|
/// Return the PDF version as `(major, minor)`.
pub fn PdfDocument::version(self : PdfDocument) -> (Int, Int) {
  (self.major, self.minor)
}

///|
/// Set the PDF version stored on the document.
pub fn PdfDocument::set_version(
  self : PdfDocument,
  major : Int,
  minor : Int,
) -> Unit {
  self.major = major
  self.minor = minor
}

///|
/// Return the catalog root object number tracked on the document.
pub fn PdfDocument::root(self : PdfDocument) -> Int {
  self.root
}

///|
/// Return the resolved document catalog object.
///
/// A `/Root` entry in the trailer dictionary is preferred over the stored root
/// number. The selected reference is resolved through `direct`; if it resolves
/// to `PdfNull`, this raises `PdfError::RootExpected`.
pub fn PdfDocument::catalog(self : PdfDocument) -> PdfObject raise PdfError {
  let object = match
    self.trailer_dict.lookup_immediate(pdf_document_root_key()) {
    Some(root) => self.direct(root)
    None => self.lookup_object_or_null(self.root)
  }
  match object {
    PdfNull => raise RootExpected
    catalog => catalog
  }
}

///|
/// Set the catalog root object number.
pub fn PdfDocument::set_root(self : PdfDocument, root : Int) -> Unit {
  self.root = root
}

///|
/// Return the current trailer dictionary object.
///
/// The returned object may share mutable container state with the document.
pub fn PdfDocument::trailer_dict(self : PdfDocument) -> PdfObject {
  self.trailer_dict
}

///|
/// Replace the document trailer dictionary object.
pub fn PdfDocument::set_trailer_dict(
  self : PdfDocument,
  trailer_dict : PdfObject,
) -> Unit {
  self.trailer_dict = trailer_dict
}

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

///|
/// Add a parsed object using the next available object number.
///
/// Returns the allocated object number and records an object-altered event.
pub fn PdfDocument::add_object(
  self : PdfDocument,
  object : PdfObject,
  generation? : Int = 0,
) -> Int {
  self.objects.add_object(object, generation~)
}

///|
/// Add or replace a parsed object at an explicit object number.
///
/// This records an object-altered event and updates the maximum object number if
/// needed.
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
  self.objects.load_object_given_number(number, object, generation)
}

///|
fn PdfDocument::load_object_given_number_already_decrypted(
  self : PdfDocument,
  number : Int,
  object : PdfObject,
) -> Unit {
  self.objects.load_object_given_number_already_decrypted(number, object)
}

///|
/// Remove an object from the document and record a deletion event.
pub fn PdfDocument::remove_object(self : PdfDocument, number : Int) -> Unit {
  self.objects.remove_object(number)
}

///|
/// Return a parsed object by number, or `PdfNull` if it is absent or deferred.
pub fn PdfDocument::lookup_object_or_null(
  self : PdfDocument,
  number : Int,
) -> PdfObject {
  self.objects.lookup_object_or_null(number)
}

///|
/// Return a copy of the document object mutation log.
pub fn PdfDocument::event_log(
  self : PdfDocument,
) -> Array[(Int, PdfObjectEvent)] {
  self.objects.log()
}

///|
/// Return whether the source PDF was marked as linearized.
pub fn PdfDocument::was_linearized(self : PdfDocument) -> Bool {
  self.was_linearized
}

///|
/// Set whether the source PDF was marked as linearized.
pub fn PdfDocument::set_was_linearized(
  self : PdfDocument,
  was_linearized : Bool,
) -> Unit {
  self.was_linearized = was_linearized
}

///|
/// Return saved encryption metadata, if the document is encrypted.
fn PdfDocument::saved_encryption(self : PdfDocument) -> PdfSavedEncryption? {
  self.saved_encryption
}

///|
/// Set saved encryption metadata for the document.
fn PdfDocument::set_saved_encryption(
  self : PdfDocument,
  saved_encryption : PdfSavedEncryption?,
) -> Unit {
  self.saved_encryption = saved_encryption
}

///|
/// Return the byte offset of the first xref section read from the input.
pub fn PdfDocument::first_xref(self : PdfDocument) -> Int {
  self.first_xref
}

///|
/// Set the byte offset of the first xref section read from the input.
pub fn PdfDocument::set_first_xref(
  self : PdfDocument,
  first_xref : Int,
) -> Unit {
  self.first_xref = first_xref
}

///|
/// Return the number of document revisions read from the input.
pub fn PdfDocument::revision_read(self : PdfDocument) -> Int {
  self.revision_read
}

///|
/// Set the number of document revisions read from the input.
pub fn PdfDocument::set_revision_read(
  self : PdfDocument,
  revision_read : Int,
) -> Unit {
  self.revision_read = revision_read
}
