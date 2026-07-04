///|
/// In-memory ZIP archive used to read DOCX parts.
pub type ZipArchive = @zip.ZipArchive

///|
/// Opens ZIP bytes into an in-memory archive.
pub fn open_zip(data : BytesView) -> ZipArchive raise DocxError {
  bridge_core_error(() => @zip.open_zip(data))
}

///|
/// Splits a ZIP path into directory and filename.
pub fn split_zip_path(path : String) -> (String, String) {
  @zip.split_zip_path(path)
}

///|
/// Joins ZIP path components with normalized separators.
pub fn join_zip_path(parts : Array[String]) -> String {
  @zip.join_zip_path(parts)
}
