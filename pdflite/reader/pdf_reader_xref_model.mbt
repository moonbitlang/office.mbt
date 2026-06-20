///|
/// One classic or xref-stream object-table entry.
///
/// Entries are stored newest first by the document reader. `object_stream`
/// records compressed-object locations for xref-stream entries.
pub(all) struct PdfClassicXRefEntry {
  object_number : Int
  offset : Int
  generation : Int
  in_use : Bool
  object_stream : @xref_model.ObjectStreamReference?
} derive(Debug, Eq)

///|
/// Parsed xref section and associated trailer.
pub(all) struct PdfXRefSection {
  entries : Array[PdfClassicXRefEntry]
  trailer : @syntax.PdfObject
  stream_object_number : Int?
  stream_object_offset : Int?
}

///|
/// Object-number index over active classic xref entries.
pub(all) struct PdfClassicXRefIndex {
  entries : @hashmap.HashMap[Int, PdfClassicXRefEntry]
}

///|
/// Find the first active xref entry for `object_number`.
pub fn pdf_classic_xref_lookup(
  xrefs : ArrayView[PdfClassicXRefEntry],
  object_number : Int,
) -> PdfClassicXRefEntry? {
  for xref in xrefs {
    if xref.in_use && xref.object_number == object_number {
      break Some(xref)
    }
  } nobreak {
    None
  }
}

///|
/// Build an object-number lookup index over active xref entries.
pub fn pdf_classic_xref_index(
  xrefs : ArrayView[PdfClassicXRefEntry],
) -> PdfClassicXRefIndex {
  let entries : @hashmap.HashMap[Int, PdfClassicXRefEntry] = HashMap([])
  for xref in xrefs {
    if xref.in_use && !entries.contains(xref.object_number) {
      entries[xref.object_number] = xref
    }
  }
  { entries, }
}

///|
/// Return the active xref entry for `object_number`, if present.
pub fn PdfClassicXRefIndex::lookup(
  self : PdfClassicXRefIndex,
  object_number : Int,
) -> PdfClassicXRefEntry? {
  self.entries.get(object_number)
}

///|
/// Append entries to `target` while preserving newest-first uniqueness.
pub fn pdf_classic_xrefs_add_newer_first_with_seen(
  target : Array[PdfClassicXRefEntry],
  seen : @core.PdfNumberSet,
  entries : ArrayView[PdfClassicXRefEntry],
) -> Unit {
  for entry in entries {
    if !seen.contains(entry.object_number) {
      target.push(entry)
      seen.add(entry.object_number)
    }
  }
}
