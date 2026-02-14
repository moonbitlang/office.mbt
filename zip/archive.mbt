///|
pub(all) struct Entry {
  name : String
  data : Bytes
  compression : Compression
  data_descriptor : Bool
}

///|
struct Archive {
  entries : Array[Entry]
}

///|
pub fn Archive::new() -> Archive {
  { entries: [] }
}

///|
pub fn Archive::add(
  self : Archive,
  name : String,
  data : Bytes,
  compression? : Compression = Store,
  data_descriptor? : Bool = false,
) -> Unit {
  self.entries.push({ name, data, compression, data_descriptor })
}

///|
pub fn Archive::get(self : Archive, name : StringView) -> Bytes? {
  for entry in self.entries {
    if entry.name[:] == name {
      return Some(entry.data)
    }
  }
  None
}

///|
pub fn Archive::entries(self : Archive) -> ArrayView[Entry] {
  self.entries[:]
}
