///|
pub type ZipArchive = @zip.ZipArchive

///|
pub fn open_zip(data : BytesView) -> ZipArchive raise DocxError {
  bridge_core_error(() => @zip.open_zip(data))
}

///|
pub fn split_zip_path(path : String) -> (String, String) {
  @zip.split_zip_path(path)
}

///|
pub fn join_zip_path(parts : Array[String]) -> String {
  @zip.join_zip_path(parts)
}
