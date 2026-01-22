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
  transcoder? : (String, Bytes) -> String raise @xlsx.XlsxError,
) -> @xlsx.Workbook raise @xlsx.XlsxError {
  match transcoder {
    Some(value) => @xlsx.read_with_password(bytes, password, transcoder=value)
    None => @xlsx.read_with_password(bytes, password)
  }
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
pub async fn open_file(
  path : String,
  password? : String = "",
  transcoder? : (String, Bytes) -> String raise @xlsx.XlsxError,
) -> @xlsx.Workbook raise @xlsx.XlsxError {
  match transcoder {
    Some(value) => @xlsx.open_file(path, password~, transcoder=value)
    None => @xlsx.open_file(path, password~)
  }
}

///|
pub async fn[R : @async/io.Reader] open_reader(
  reader : R,
  password? : String = "",
  transcoder? : (String, Bytes) -> String raise @xlsx.XlsxError,
) -> @xlsx.Workbook raise @xlsx.XlsxError {
  match transcoder {
    Some(value) => @xlsx.open_reader(reader, password~, transcoder=value)
    None => @xlsx.open_reader(reader, password~)
  }
}

///|
pub async fn[R : @async/io.Reader] read_zip_reader(
  reader : R,
  password? : String = "",
  transcoder? : (String, Bytes) -> String raise @xlsx.XlsxError,
) -> @xlsx.Workbook raise @xlsx.XlsxError {
  match transcoder {
    Some(value) => @xlsx.read_zip_reader(reader, password~, transcoder=value)
    None => @xlsx.read_zip_reader(reader, password~)
  }
}
