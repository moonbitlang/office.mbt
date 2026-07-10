///|
struct Entry {
  name : String
  data : Bytes
  compression : Compression
  data_descriptor : Bool
  // CRC-32 of `data`: the central-directory value for entries read from an
  // archive, or computed at add time for entries created in memory.
  crc32 : UInt
}

///|
pub fn Entry::name(self : Entry) -> String {
  self.name
}

///|
pub fn Entry::data(self : Entry) -> Bytes {
  self.data
}

///|
pub fn Entry::compression(self : Entry) -> Compression {
  self.compression
}

///|
pub fn Entry::data_descriptor(self : Entry) -> Bool {
  self.data_descriptor
}

///|
/// The entry's CRC-32: as stored in the central directory for entries read
/// from an archive (compare with `crc32(entry.data())` to detect
/// corruption the inflater tolerates), or computed from the data for
/// entries created via `Archive::add`.
pub fn Entry::crc32(self : Entry) -> UInt {
  self.crc32
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
  self.entries.push({
    name,
    data,
    compression,
    data_descriptor,
    crc32: crc32(data),
  })
}

///|
pub fn Archive::get(self : Archive, name : StringView) -> Bytes? {
  for entry in self.entries {
    if entry.name()[:] == name {
      return Some(entry.data())
    }
  }
  None
}

///|
pub fn Archive::entries(self : Archive) -> ArrayView[Entry] {
  self.entries
}
