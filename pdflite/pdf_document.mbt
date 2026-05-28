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
