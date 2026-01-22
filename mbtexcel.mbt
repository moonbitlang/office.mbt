///|
pub fn new_workbook() -> @xlsx.Workbook {
  @xlsx.Workbook::new()
}

///|
pub fn read(bytes : BytesView) -> @xlsx.Workbook raise @xlsx.XlsxError {
  @xlsx.read(bytes)
}

///|
pub fn read_with_password(
  bytes : BytesView,
  password : String,
) -> @xlsx.Workbook raise @xlsx.XlsxError {
  @xlsx.read_with_password(bytes, password)
}

///|
pub fn write(workbook : @xlsx.Workbook) -> Bytes raise @xlsx.XlsxError {
  @xlsx.write(workbook)
}

///|
pub fn write_with_password(
  workbook : @xlsx.Workbook,
  password : String,
) -> Bytes raise @xlsx.XlsxError {
  @xlsx.write_with_password(workbook, password)
}

///|
pub async fn open_file(path : String) -> @xlsx.Workbook raise @xlsx.XlsxError {
  @xlsx.open_file(path)
}

///|
pub async fn[R : @async/io.Reader] open_reader(
  reader : R,
) -> @xlsx.Workbook raise @xlsx.XlsxError {
  @xlsx.open_reader(reader)
}

///|
pub async fn[R : @async/io.Reader] read_zip_reader(
  reader : R,
) -> @xlsx.Workbook raise @xlsx.XlsxError {
  @xlsx.read_zip_reader(reader)
}
