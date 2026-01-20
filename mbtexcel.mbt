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
