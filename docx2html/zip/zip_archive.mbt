///|
/// In-memory ZIP archive used to read DOCX parts.
pub(all) struct ZipArchive {
  entries : Map[String, BytesView]
} derive(Debug, Eq)

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
  { entries: map }
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
  self.entries.contains(path)
}

///|
/// Reads a ZIP entry as bytes.
pub fn ZipArchive::read_bytes(self : ZipArchive, path : String) -> BytesView? {
  self.entries.get(path)
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
