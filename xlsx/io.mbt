///|
async fn[R : @async/io.Reader] read_all_bytes(
  reader : R,
) -> Bytes raise XlsxError {
  let data = reader.read_all() catch {
    err => raise XlsxError::InvalidSheetOperation(msg="reader failed: \{err}")
  }
  data.binary()
}

///|
async fn read_file_bytes(path : String) -> Bytes raise XlsxError {
  let data = @async/fs.read_file(path) catch {
    err =>
      raise XlsxError::InvalidSheetOperation(msg="read file failed: \{err}")
  }
  data.binary()
}

///|
pub async fn[R : @async/io.Reader] open_reader(
  reader : R,
  password? : String = "",
  options? : Options = Options::new(),
  transcoder? : (String, Bytes) -> String raise XlsxError,
) -> Workbook raise XlsxError {
  let bytes = read_all_bytes(reader)
  let resolved_password = if password == "" {
    options.password
  } else {
    password
  }
  if resolved_password == "" {
    match transcoder {
      Some(value) => read_zip_bytes(bytes, options~, transcoder=value)
      None => read_zip_bytes(bytes, options~)
    }
  } else {
    match transcoder {
      Some(value) =>
        read_with_password(bytes, resolved_password, options~, transcoder=value)
      None => read_with_password(bytes, resolved_password, options~)
    }
  }
}

///|
pub async fn[R : @async/io.Reader] read_zip_reader(
  reader : R,
  password? : String = "",
  options? : Options = Options::new(),
  transcoder? : (String, Bytes) -> String raise XlsxError,
) -> Workbook raise XlsxError {
  match transcoder {
    Some(value) => open_reader(reader, password~, options~, transcoder=value)
    None => open_reader(reader, password~, options~)
  }
}

///|
pub async fn[R : @async/io.Reader] Workbook::read_zip_reader(
  self : Workbook,
  reader : R,
  password? : String = "",
  options? : Options,
  transcoder? : (String, Bytes) -> String raise XlsxError,
) -> Workbook raise XlsxError {
  let resolved_options = match options {
    Some(value) => value
    None => self.options
  }
  let resolved_transcoder = match transcoder {
    Some(value) => Some(value)
    None => self.charset_transcoder
  }
  match resolved_transcoder {
    Some(value) =>
      open_reader(reader, password~, options=resolved_options, transcoder=value)
    None => open_reader(reader, password~, options=resolved_options)
  }
}

///|
pub async fn open_file(
  path : String,
  password? : String = "",
  options? : Options = Options::new(),
  transcoder? : (String, Bytes) -> String raise XlsxError,
) -> Workbook raise XlsxError {
  let bytes = read_file_bytes(path)
  let resolved_password = if password == "" {
    options.password
  } else {
    password
  }
  let workbook = if resolved_password == "" {
    match transcoder {
      Some(value) => read_zip_bytes(bytes, options~, transcoder=value)
      None => read_zip_bytes(bytes, options~)
    }
  } else {
    match transcoder {
      Some(value) =>
        read_with_password(bytes, resolved_password, options~, transcoder=value)
      None => read_with_password(bytes, resolved_password, options~)
    }
  }
  workbook.file_path = Some(path)
  workbook
}

///|
pub async fn Workbook::set_sheet_background_from_file(
  self : Workbook,
  sheet_name : StringView,
  path : String,
) -> Unit raise XlsxError {
  let extension = match extension_from_path(path) {
    Some(value) => value
    None =>
      raise XlsxError::InvalidSheetBackground(msg="image extension missing")
  }
  let bytes = read_file_bytes(path)
  self.set_sheet_background(sheet_name, bytes, extension)
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
pub async fn[W : @async/io.Writer] Workbook::write(
  self : Workbook,
  writer : W,
) -> Unit raise XlsxError {
  ignore(self.write_to(writer))
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
