///|
/// In-memory ZIP archive used to read DOCX parts. OPC part-name comparison is
/// case-insensitive, while `canonical_names` retains the archive's exact
/// spelling so preservation edits always address the physical entry.
pub struct ZipArchive {
  priv entries : StableStringMap[BytesView]
  priv canonical_names : StableStringMap[String]
  priv logical_names : StableStringMap[String]
} derive(Debug, Eq)

///|
const MAX_ZIP_ENTRY_NAME_CHARS : Int = 65_535

///|
const MAX_ZIP_TOTAL_ENTRY_NAME_CHARS : Int = 4 * 1024 * 1024

///|
fn canonical_part_name(path : String) -> String {
  @opc.part_name_key(path)
}

///|
fn checked_zip_entry_name_total(
  total : Int,
  name : String,
) -> Int raise DocxError {
  let length = name.length()
  if length > MAX_ZIP_ENTRY_NAME_CHARS {
    raise InvalidZip(
      message="ZIP entry name exceeds \{MAX_ZIP_ENTRY_NAME_CHARS} characters",
    )
  }
  if length > MAX_ZIP_TOTAL_ENTRY_NAME_CHARS - total {
    raise InvalidZip(
      message="ZIP entry names exceed \{MAX_ZIP_TOTAL_ENTRY_NAME_CHARS} aggregate characters",
    )
  }
  total + length
}

///|
/// Builds an owned part view and rejects case-equivalent aliases before they
/// can collapse into the canonical lookup index.
pub fn zip_archive(
  source : Map[String, BytesView],
) -> ZipArchive raise DocxError {
  zip_archive_entries(source.iter())
}

///|
/// Builds an archive view from a collision-independent iterator. This is the
/// preferred entry point for already validated or adversarial entry streams;
/// the map overload remains a convenience for programmatic callers.
pub fn zip_archive_entries(
  source : Iter[(String, BytesView)],
) -> ZipArchive raise DocxError {
  let entries : StableStringMap[BytesView] = SortedMap([])
  let canonical_names : StableStringMap[String] = SortedMap([])
  let logical_names : StableStringMap[String] = SortedMap([])
  let part_names = @opc.PartNameRegistry::new()
  let mut name_chars = 0
  for pair in source {
    let (name, bytes) = pair
    name_chars = checked_zip_entry_name_total(name_chars, name)
    insert_zip_entry(
      entries, canonical_names, logical_names, part_names, name, bytes,
    )
  }
  { entries, canonical_names, logical_names }
}

///|
fn insert_zip_entry(
  entries : StableStringMap[BytesView],
  canonical_names : StableStringMap[String],
  logical_names : StableStringMap[String],
  part_names : @opc.PartNameRegistry,
  name : String,
  bytes : BytesView,
) -> Unit raise DocxError {
  // Explicit ZIP directory records are package metadata, not OPC parts. The
  // structural validator applies the same rule, so case-equivalent directory
  // spellings cannot make validation and reader construction disagree.
  if name.has_suffix("/") {
    return
  }
  if entries.contains(name) {
    raise InvalidZip(message="duplicate ZIP entry name: \{name}")
  }
  let logical_name = if name == "[Content_Types].xml" {
    "[Content_Types].xml"
  } else if canonical_part_name(name) ==
    canonical_part_name("[Content_Types].xml") {
    raise InvalidZip(
      message="the reserved content-types entry must use exact spelling '[Content_Types].xml': \{name}",
    )
  } else {
    match @opc.logical_part_name_from_zip_item_name(name) {
      Some(value) => value
      None =>
        raise InvalidZip(
          message="ZIP entry does not map to a canonical OPC part name: \{name}",
        )
    }
  }
  let key = canonical_part_name(logical_name)
  if logical_name != "[Content_Types].xml" {
    match part_names.register(logical_name, name) {
      Some(Equivalent(existing)) =>
        raise InvalidZip(
          message="duplicate ZIP entry names after case normalization: \{existing}, \{name}",
        )
      Some(Derivable(existing)) =>
        raise InvalidZip(
          message="OPC part names must not be derivable from one another: \{existing}, \{name}",
        )
      None => ()
    }
  }
  entries[name] = bytes
  canonical_names[key] = name
  logical_names[name] = logical_name
}

///|
/// Builds the DOCX reader's immutable part view from an already materialized
/// archive. Entry names remain fail-closed: the map view must never silently
/// collapse duplicate ZIP records.
pub fn open_zip_archive(
  archive : @mbtzip.Archive,
) -> ZipArchive raise DocxError {
  let entries : StableStringMap[BytesView] = SortedMap([])
  let canonical_names : StableStringMap[String] = SortedMap([])
  let logical_names : StableStringMap[String] = SortedMap([])
  let part_names = @opc.PartNameRegistry::new()
  let mut name_chars = 0
  for entry in archive.entries() {
    name_chars = checked_zip_entry_name_total(name_chars, entry.name())
    insert_zip_entry(
      entries,
      canonical_names,
      logical_names,
      part_names,
      entry.name(),
      entry.data(),
    )
  }
  { entries, canonical_names, logical_names }
}

///|
/// Opens ZIP bytes into an in-memory archive.
pub fn open_zip(data : BytesView) -> ZipArchive raise DocxError {
  let archive = @mbtzip.read(data) catch {
    err => raise InvalidZip(message="invalid ZIP archive: \{repr(err)}")
  }
  open_zip_archive(archive)
}

///|
/// Returns whether a ZIP entry exists.
pub fn ZipArchive::exists(self : ZipArchive, path : String) -> Bool {
  self.resolve_path(path) is Some(_)
}

///|
/// Resolves an OPC path to the archive's exact entry spelling.
pub fn ZipArchive::resolve_path(self : ZipArchive, path : String) -> String? {
  if self.entries.contains(path) {
    Some(path)
  } else {
    self.canonical_names.get(canonical_part_name(path))
  }
}

///|
/// Resolves either an exact physical ZIP spelling or a logical OPC name to
/// the canonical logical part name carried by this archive.
pub fn ZipArchive::logical_path(self : ZipArchive, path : String) -> String? {
  match self.logical_names.get(path) {
    Some(logical) => Some(logical)
    None =>
      match self.canonical_names.get(canonical_part_name(path)) {
        Some(physical) => self.logical_names.get(physical)
        None => None
      }
  }
}

///|
/// Reads a ZIP entry as bytes.
pub fn ZipArchive::read_bytes(self : ZipArchive, path : String) -> BytesView? {
  match self.resolve_path(path) {
    Some(actual) => self.entries.get(actual)
    None => None
  }
}

///|
/// Reads a ZIP entry as UTF-8 text.
pub fn ZipArchive::read_text(
  self : ZipArchive,
  path : String,
) -> String? raise DocxError {
  match self.read_bytes(path) {
    Some(bytes) =>
      Some(
        @utf8.decode(bytes, ignore_bom=true) catch {
          _ => raise InvalidXml(message="part is not valid UTF-8: " + path)
        },
      )
    None => None
  }
}

///|
/// Splits a ZIP path into directory and filename.
pub fn split_zip_path(path : String) -> (String, String) {
  match path.rev_find("/") {
    Some(index) => (path[:index].to_owned(), path[index + 1:].to_owned())
    None => ("", path)
  }
}

///|
/// Joins ZIP path components with normalized separators.
pub fn join_zip_path(parts : Array[String]) -> String {
  let relevant : Array[String] = []
  for part in parts {
    if part != "" {
      if part.has_prefix("/") {
        relevant.clear()
      }
      relevant.push(part)
    }
  }
  relevant.join("/")
}
