///|
/// Loading state for one entry in the document object table.
///
/// Parsed variants hold objects that are ready to use. `ObjectToParse` marks an
/// object that is known from an xref table but has not been read yet.
/// `ObjectToParseFromObjectStream` records the object-stream location needed to
/// load compressed objects lazily.
#derive(Debug, Eq)
pub(all) enum PdfObjectData {
  ObjectParsed(@syntax.PdfObject)
  ObjectParsedAlreadyDecrypted(@syntax.PdfObject)
  ObjectToParse
  ObjectToParseFromObjectStream(@xref_model.ObjectStreamReference)
}

///|
/// One object-table entry together with its generation number.
///
/// The `data` field is mutable so parsers can replace deferred states with
/// parsed objects after lazy loading.
#derive(Debug, Eq)
pub(all) struct PdfObjectEntry {
  mut data : PdfObjectData
  generation : Int32
}

///|
/// Mutation event recorded for incremental-write style bookkeeping.
#derive(Debug, Eq)
pub(all) enum PdfObjectEvent {
  ObjectAltered
  ObjectDeleted
}

///|
/// Sparse map from object number to object-table entry.
///
/// This is a thin wrapper around a hash map. It does not track maximum object
/// number or mutation events; use `PdfObjects` for document-level bookkeeping.
#derive(Debug, Eq)
pub struct PdfObjectMap {
  entries : @hashmap.HashMap[Int32, PdfObjectEntry]
}

///|
/// Document object table with allocation, object-stream, and mutation metadata.
///
/// `PdfObjects` owns the sparse object map, tracks the highest object number
/// allocated so far, records object-stream identifiers, and stores an alteration
/// log used by writers and tests.
#derive(Debug, Eq)
pub struct PdfObjects {
  mut max_object_number : Int32
  object_map : PdfObjectMap
  object_stream_ids : @hashmap.HashMap[Int32, Int32]
  log : Array[(Int32, PdfObjectEvent)]
}

///|
/// In-memory representation of one PDF document.
///
/// A document stores the PDF version, catalog root number, object table,
/// trailer dictionary, linearization flag, saved encryption metadata, first xref
/// offset, and the revision count read from the input.
#derive(Debug, Eq)
pub struct PdfDocument {
  mut major : Int32
  mut minor : Int32
  mut root : Int32
  objects : PdfObjects
  mut trailer_dict : @syntax.PdfObject
  mut was_linearized : Bool
  mut saved_encryption : @crypt_core.PdfSavedEncryption?
  mut first_xref : Int32
  mut revision_read : Int32
}
