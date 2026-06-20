///|
/// Location of an object stored inside a PDF object stream.
///
/// `object_stream_number` is the containing object stream number, and `index`
/// is the zero-based entry index inside that stream.
///
/// This is a shared cross-cutting model type: it is produced by the xref reader
/// and stored in the document object table, so it lives in its own low-level
/// package that both `reader` and the document core can depend on without a
/// cycle.
pub(all) struct ObjectStreamReference {
  object_stream_number : Int
  index : Int
} derive(Debug, Eq)
