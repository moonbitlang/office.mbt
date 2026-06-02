///|
pub(all) struct ZipArchive {
  entries : Map[String, Bytes]
} derive(Debug, Eq)

///|
pub fn open_zip(data : BytesView) -> ZipArchive raise DocxError {
  let fixed = FixedArray::from_array(data.to_array())
  let entries = @fzip.unzip_sync(fixed) catch {
    FzipError(message~, ..) =>
      raise InvalidZip(message="invalid ZIP archive: " + message)
  }
  let map : Map[String, Bytes] = {}
  for entry in entries {
    let (name, content) = entry
    map[name] = Bytes::from_array(content)
  }
  { entries: map }
}

///|
pub fn ZipArchive::exists(self : ZipArchive, path : String) -> Bool {
  self.entries.contains(path)
}

///|
pub fn ZipArchive::read_bytes(self : ZipArchive, path : String) -> Bytes? {
  self.entries.get(path)
}

///|
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
pub fn split_zip_path(path : String) -> (String, String) {
  let mut index = path.length() - 1
  while index >= 0 {
    if path[index] == '/' {
      return (path[:index].to_owned(), path[index + 1:].to_owned())
    }
    index = index - 1
  }
  ("", path)
}

///|
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
