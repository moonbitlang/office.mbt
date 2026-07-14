///|
/// In-memory ZIP archive used to read DOCX parts. OPC part-name comparison is
/// case-insensitive, while `canonical_names` retains the archive's exact
/// spelling so preservation edits always address the physical entry.
pub struct ZipArchive {
  priv entries : Map[String, BytesView]
  priv canonical_names : Map[String, String]
} derive(Debug, Eq)

///|
fn canonical_part_name(path : String) -> String {
  path.to_lower()
}

///|
/// Builds an owned part view and rejects case-equivalent aliases before they
/// can collapse into the canonical lookup index.
pub fn zip_archive(
  source : Map[String, BytesView],
) -> ZipArchive raise DocxError {
  let entries : Map[String, BytesView] = Map([])
  let canonical_names : Map[String, String] = Map([])
  for name, bytes in source {
    let key = canonical_part_name(name)
    match canonical_names.get(key) {
      Some(existing) if existing != name =>
        raise InvalidZip(
          message="duplicate ZIP entry names after case normalization: \{existing}, \{name}",
        )
      _ => ()
    }
    entries[name] = bytes
    canonical_names[key] = name
  }
  { entries, canonical_names }
}

///|
/// Builds the DOCX reader's immutable part view from an already materialized
/// archive. Entry names remain fail-closed: the map view must never silently
/// collapse duplicate ZIP records.
pub fn open_zip_archive(
  archive : @mbtzip.Archive,
) -> ZipArchive raise DocxError {
  let map : Map[String, BytesView] = Map([])
  for entry in archive.entries() {
    if map.contains(entry.name()) {
      raise InvalidZip(message="duplicate ZIP entry name: \{entry.name()}")
    }
    map[entry.name()] = entry.data()
  }
  zip_archive(map)
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
