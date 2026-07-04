///|
/// Lookup set for object-number and offset pairs claimed by xref streams.
pub struct PdfReaderXRefStreamRefSet {
  values : @hashmap.HashMap[Int, @core.PdfNumberSet]
}

///|
/// Build a lookup set for xref-stream object references.
pub fn pdf_reader_xref_stream_ref_set(
  refs : ArrayView[(Int, Int)],
) -> PdfReaderXRefStreamRefSet {
  let values : @hashmap.HashMap[Int, @core.PdfNumberSet] = HashMap([])
  for item in refs {
    let (object_number, offset) = item
    match values.get(object_number) {
      Some(offsets) => offsets.add(offset)
      None => {
        let offsets = @core.pdf_number_set([])
        offsets.add(offset)
        values[object_number] = offsets
      }
    }
  }
  { values, }
}

///|
/// Return whether the set contains an object-number and offset pair.
pub fn PdfReaderXRefStreamRefSet::contains(
  self : PdfReaderXRefStreamRefSet,
  object_number : Int,
  offset : Int,
) -> Bool {
  match self.values.get(object_number) {
    Some(offsets) => offsets.contains(offset)
    None => false
  }
}
