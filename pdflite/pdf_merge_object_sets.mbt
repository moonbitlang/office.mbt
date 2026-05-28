///|
fn PdfDocument::pdf_merge_copy_objects_from(
  self : PdfDocument,
  source : PdfDocument,
) -> Unit {
  for number in source.object_numbers() {
    let entry = source.objects.get_entry(number).unwrap()
    self.objects.set_entry(number, {
      data: entry.data,
      generation: entry.generation,
    })
  }
}

///|
priv struct PdfMergeNameSet {
  values : @hashmap.HashMap[Bytes, Bool]
}

///|
fn pdf_merge_name_set() -> PdfMergeNameSet {
  { values: HashMap([]) }
}

///|
fn PdfMergeNameSet::contains(self : PdfMergeNameSet, name : PdfName) -> Bool {
  self.values.contains(name.bytes())
}

///|
fn PdfMergeNameSet::add(self : PdfMergeNameSet, name : PdfName) -> Unit {
  self.values[name.bytes()] = true
}

///|
priv struct PdfMergeBytesSet {
  values : @hashmap.HashMap[Bytes, Bool]
}

///|
fn pdf_merge_bytes_set() -> PdfMergeBytesSet {
  { values: HashMap([]) }
}

///|
fn PdfMergeBytesSet::contains(
  self : PdfMergeBytesSet,
  bytes : PdfBytes,
) -> Bool {
  self.values.contains(bytes)
}

///|
fn PdfMergeBytesSet::add(self : PdfMergeBytesSet, bytes : PdfBytes) -> Unit {
  self.values[bytes] = true
}
