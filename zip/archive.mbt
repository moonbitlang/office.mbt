///|

///|
priv struct SourceEntryTemplate {
  local_record : Bytes
  local_header_length : Int
  central_record : Bytes
  local_zip64_uncompressed_position : Int?
  local_zip64_compressed_position : Int?
  central_zip64_uncompressed_position : Int?
  central_zip64_compressed_position : Int?
  central_zip64_offset_position : Int?
  descriptor_signed : Bool
  descriptor_zip64 : Bool
}

///|
priv struct Zip64TrailerTemplate {
  end_record : Bytes
  locator : Bytes
  classic_end_record : Bytes
}

///|
struct Entry {
  name : String
  data : Bytes
  compression : Compression
  data_descriptor : Bool
  // CRC-32 of `data`: the central-directory value for entries read from an
  // archive, or computed at add time for entries created in memory.
  crc32 : UInt
  source_local_offset : Int?
  source : SourceEntryTemplate?
  source_unchanged : Bool
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
  comment : Bytes
  zip64_trailer : Zip64TrailerTemplate?
}

///|
pub fn Archive::new() -> Archive {
  { entries: [], comment: b"", zip64_trailer: None }
}

///|
fn archive_from_source(
  comment : Bytes,
  zip64_trailer : Zip64TrailerTemplate?,
) -> Archive {
  { entries: [], comment, zip64_trailer }
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
    source_local_offset: None,
    source: None,
    source_unchanged: false,
  })
}

///|
/// Replaces an exact entry while retaining its compression policy and source
/// position. The next write preserves every other source entry byte-for-byte.
pub fn Archive::replace(
  self : Archive,
  name : StringView,
  data : Bytes,
) -> Bool {
  for index in 0..<self.entries.length() {
    let entry = self.entries[index]
    if entry.name[:] == name {
      if entry.data == data {
        return true
      }
      self.entries[index] = {
        name: entry.name,
        data,
        compression: entry.compression,
        data_descriptor: entry.data_descriptor,
        crc32: crc32(data),
        source_local_offset: entry.source_local_offset,
        source: entry.source,
        source_unchanged: false,
      }
      return true
    }
  }
  false
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
