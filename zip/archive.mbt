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
/// Provenance attached only by `read_limited`. Keeping it inside the opaque
/// archive makes the bounded-read claim non-forgeable by callers. Any
/// payload/entry mutation clears the claim; a shallow fork preserves it until
/// that fork is changed.
priv struct BoundedSource {
  package_bytes : Int
  max_entries : Int
  max_entry_uncompressed_bytes : Int
  max_total_uncompressed_bytes : Int
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
  mut bounded_source : BoundedSource?
}

///|
pub fn Archive::new() -> Archive {
  { entries: [], comment: b"", zip64_trailer: None, bounded_source: None }
}

///|
/// Returns an independently mutable archive snapshot whose immutable strings
/// and byte buffers remain shared. Replacing or adding an entry on the fork
/// cannot change `self`; this avoids reinflating an already validated archive
/// when a caller needs a working copy.
pub fn Archive::fork(self : Archive) -> Archive {
  {
    entries: self.entries.copy(),
    comment: self.comment,
    zip64_trailer: self.zip64_trailer,
    bounded_source: self.bounded_source,
  }
}

///|
/// Returns the exact serialized source size only when this pristine archive
/// came from `read_limited` with limits at least as strict as those requested.
/// This is a capability query: archives built with `new`/`read`, or changed
/// after a bounded read, return `None`.
pub fn Archive::bounded_source_package_size(
  self : Archive,
  max_entries~ : Int,
  max_entry_uncompressed_bytes~ : Int,
  max_total_uncompressed_bytes~ : Int,
) -> Int? {
  match self.bounded_source {
    Some(source) if source.max_entries <= max_entries &&
      source.max_entry_uncompressed_bytes <= max_entry_uncompressed_bytes &&
      source.max_total_uncompressed_bytes <= max_total_uncompressed_bytes =>
      Some(source.package_bytes)
    _ => None
  }
}

///|
/// Conservatively estimates bytes retained by this materialized archive.
/// Payloads and preserved source records are counted exactly; decoded names
/// and per-entry/runtime bookkeeping include an explicit reserve. The source
/// package buffer from which the archive was read is not included.
pub fn Archive::retained_size_estimate(self : Archive) -> Int64 {
  let mut total = self.comment.length().to_int64()
  match self.zip64_trailer {
    Some(trailer) => {
      total = total + trailer.end_record.length().to_int64()
      total = total + trailer.locator.length().to_int64()
      total = total + trailer.classic_end_record.length().to_int64()
    }
    None => ()
  }
  if self.bounded_source is Some(_) {
    total = total + 64L
  }
  for entry in self.entries {
    total = total + entry.data.length().to_int64()
    total = total + entry.name.length().to_int64() * 2L
    // Entry/array slots, references, option wrappers, and allocator metadata.
    total = total + 512L
    match entry.source {
      Some(source) => {
        total = total + source.local_record.length().to_int64()
        total = total + source.central_record.length().to_int64()
        total = total + 128L
      }
      None => ()
    }
  }
  total
}

///|
fn archive_from_source(
  comment : Bytes,
  zip64_trailer : Zip64TrailerTemplate?,
  bounded_source : BoundedSource?,
) -> Archive {
  { entries: [], comment, zip64_trailer, bounded_source }
}

///|
pub fn Archive::add(
  self : Archive,
  name : String,
  data : Bytes,
  compression? : Compression = Store,
  data_descriptor? : Bool = false,
) -> Unit {
  self.bounded_source = None
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
      self.bounded_source = None
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
