///|
async fn[R : @async/io.Reader] read_all_bytes(
  reader : R,
) -> Bytes raise XlsxError {
  let out : Array[Byte] = []
  while true {
    let chunk = reader.read_some() catch {
      err => raise XlsxError::InvalidSheetOperation(msg="reader failed: \{err}")
    }
    match chunk {
      Some(bytes) =>
        for value in bytes {
          out.push(value)
        }
      None => break
    }
  }
  Bytes::from_array(out)
}

///|
async fn read_file_bytes(path : String) -> Bytes raise XlsxError {
  let file = @async/fs.open(path, mode=@async/fs.Mode::ReadOnly) catch {
    err =>
      raise XlsxError::InvalidSheetOperation(msg="open file failed: \{err}")
  }
  let bytes = read_all_bytes(file) catch {
    err => {
      file.close()
      raise err
    }
  }
  file.close()
  bytes
}

///|
pub async fn[R : @async/io.Reader] open_reader(
  reader : R,
  transcoder? : (String, Bytes) -> String raise XlsxError,
) -> Workbook raise XlsxError {
  let bytes = read_all_bytes(reader)
  match transcoder {
    Some(value) => read_zip_bytes(bytes, transcoder=value)
    None => read_zip_bytes(bytes)
  }
}

///|
pub async fn[R : @async/io.Reader] read_zip_reader(
  reader : R,
  transcoder? : (String, Bytes) -> String raise XlsxError,
) -> Workbook raise XlsxError {
  match transcoder {
    Some(value) => open_reader(reader, transcoder=value)
    None => open_reader(reader)
  }
}

///|
pub async fn open_file(
  path : String,
  transcoder? : (String, Bytes) -> String raise XlsxError,
) -> Workbook raise XlsxError {
  let bytes = read_file_bytes(path)
  let workbook = match transcoder {
    Some(value) => read_zip_bytes(bytes, transcoder=value)
    None => read_zip_bytes(bytes)
  }
  workbook.file_path = Some(path)
  workbook
}

///|
pub async fn Workbook::save(self : Workbook) -> Unit raise XlsxError {
  match self.file_path {
    Some(path) => self.save_as(path)
    None => raise XlsxError::InvalidSheetOperation(msg="workbook path not set")
  }
}

///|
pub async fn Workbook::save_as(
  self : Workbook,
  path : String,
) -> Unit raise XlsxError {
  let bytes = write(self)
  @async/fs.write_file(path, bytes, create=0o644) catch {
    err =>
      raise XlsxError::InvalidSheetOperation(msg="write file failed: \{err}")
  }
  self.file_path = Some(path)
}

///|
pub fn Workbook::write_to_buffer(self : Workbook) -> Bytes raise XlsxError {
  write(self)
}

///|
pub async fn[W : @async/io.Writer] Workbook::write_to(
  self : Workbook,
  writer : W,
) -> Int raise XlsxError {
  let bytes = write(self)
  writer.write(bytes) catch {
    err => raise XlsxError::InvalidSheetOperation(msg="writer failed: \{err}")
  }
  bytes.length()
}

///|
pub fn Workbook::close(_self : Workbook) -> Unit {
  ()
}
