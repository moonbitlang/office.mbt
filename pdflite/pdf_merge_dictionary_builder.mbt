///|
priv struct PdfMergeDictionaryBuilder {
  entries : Array[(PdfName, PdfObject)]
  indexes : @hashmap.HashMap[Bytes, Int]
}

///|
fn pdf_merge_dictionary_builder() -> PdfMergeDictionaryBuilder {
  { entries: [], indexes: HashMap([]) }
}

///|
fn PdfMergeDictionaryBuilder::add_entry(
  self : PdfMergeDictionaryBuilder,
  key : PdfName,
  value : PdfObject,
) -> Unit {
  let index_key = key.bytes()
  match self.indexes.get(index_key) {
    Some(index) => self.entries[index] = (key, value)
    None => {
      self.indexes[index_key] = self.entries.length()
      self.entries.push((key, value))
    }
  }
}
