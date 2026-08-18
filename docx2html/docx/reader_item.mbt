// PR 2.0 of the reader unification (#434): the output carrier.
//
// The body reader's recursive component is one strongly connected component
// through `read_children`'s return type: no semantic migration can happen
// piecemeal while every branch returns `Array[DocumentElement]` directly.
// `ReaderItem` is the temporary bridge that breaks the deadlock. In this
// step EVERYTHING is wrapped `Legacy` and unwrapped at the erase boundary,
// so behaviour is identical by construction; 2a converts the structural
// producers, 2b the atoms, 2c the transforms, and then `Legacy` is deleted
// with a search guard.

///|
/// One item of reader output while the migration is in flight.
priv enum ReaderItem {
  /// A fully built legacy element. Every producer starts here; each
  /// migration step moves producers off it, and the variant's deletion is
  /// the signal that PR 2 is complete.
  Legacy(DocumentElement)
}

///|
/// The erase boundary: collapse carrier items into the public tree shape.
/// Callers outside the recursive component -- package assembly, notes and
/// comment bodies, and the whitebox tests -- see exactly what they always
/// saw.
fn reader_items_to_elements(
  items : Array[ReaderItem],
) -> Array[DocumentElement] {
  items.map(item => {
    match item {
      Legacy(element) => element
    }
  })
}

///|
/// Wrap legacy output while producers migrate.
fn reader_legacy_items(elements : Array[DocumentElement]) -> Array[ReaderItem] {
  elements.map(element => Legacy(element))
}
