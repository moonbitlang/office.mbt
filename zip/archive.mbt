///|
pub struct Entry {
  name : String
  data : Bytes
  compression : Compression
}

///|
pub struct Archive {
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
  compression? : Compression = Compression::Store,
) -> Unit {
  self.entries.push({ name, data, compression })
}

///|
pub fn Archive::names(self : Archive) -> Array[String] {
  self.entries.map(entry => entry.name)
}

///|
pub fn Archive::get(self : Archive, name : StringView) -> Bytes? {
  let needle = name.to_string()
  for entry in self.entries {
    if entry.name == needle {
      return Some(entry.data)
    }
  }
  None
}

///|
pub fn Archive::entries(self : Archive) -> ArrayView[Entry] {
  self.entries[:]
}
