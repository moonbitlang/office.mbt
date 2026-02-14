///|
async fn[R : @async/io.Reader] read_all_bytes(
  reader : R,
) -> Bytes raise XlsxError {
  let data = reader.read_all() catch {
    err => raise InvalidSheetOperation(msg="reader failed: \{err}")
  }
  data.binary()
}

///|
async fn read_file_bytes(path : String) -> Bytes raise XlsxError {
  let data = @async/fs.read_file(path) catch {
    err => raise InvalidSheetOperation(msg="read file failed: \{err}")
  }
  data.binary()
}

///|
fn resolve_write_options(workbook : Workbook, options : Options?) -> Options {
  match options {
    Some(value) => value
    None => workbook.options
  }
}

///|
fn resolve_write_io_context(
  workbook : Workbook,
  file_path_override : String?,
) -> WorkbookIOContext {
  let io_context = workbook_io_context(workbook)
  match file_path_override {
    Some(value) => workbook_io_context_with_file_path(io_context, Some(value))
    None => io_context
  }
}

///|
fn write_bytes_with_io(
  workbook : Workbook,
  options : Options?,
  file_path_override : String?,
) -> Bytes raise XlsxError {
  let resolved = resolve_write_options(workbook, options)
  let io_context = resolve_write_io_context(workbook, file_path_override)
  if resolved.password == "" {
    write_with_io(workbook, io_context)
  } else {
    let raw = write_with_io(workbook, io_context)
    if resolved.password.length() == 0 {
      raw
    } else {
      encrypt_package(raw, resolved.password)
    }
  }
}

///|
fn write_bytes(
  workbook : Workbook,
  options : Options?,
) -> Bytes raise XlsxError {
  write_bytes_with_io(workbook, options, None)
}

///|
fn read_io_context(
  transcoder : ((String, Bytes) -> String raise XlsxError)?,
) -> WorkbookIOContext {
  workbook_io_context_with_transcoder(empty_workbook_io_context(), transcoder)
}

///|
fn read_workbook_from_bytes(
  bytes : Bytes,
  password : String,
  options : Options,
  io_context : WorkbookIOContext,
) -> Workbook raise XlsxError {
  let resolved_password = if password == "" {
    options.password
  } else {
    password
  }
  let resolved_options = options_with_password(options, resolved_password)
  if resolved_password == "" {
    match io_context.charset_transcoder {
      Some(value) =>
        read_zip_bytes(bytes, options=resolved_options, transcoder=value)
      None => read_zip_bytes(bytes, options=resolved_options)
    }
  } else {
    match io_context.charset_transcoder {
      Some(value) =>
        read_with_password(
          bytes,
          resolved_password,
          options=resolved_options,
          transcoder=value,
        )
      None =>
        read_with_password(bytes, resolved_password, options=resolved_options)
    }
  }
}

///|
pub async fn[R : @async/io.Reader] open_reader(
  reader : R,
  password? : String = "",
  options? : Options = Options::new(),
  transcoder? : (String, Bytes) -> String raise XlsxError,
) -> Workbook raise XlsxError {
  let bytes = read_all_bytes(reader)
  let io_context = read_io_context(transcoder)
  let workbook = read_workbook_from_bytes(bytes, password, options, io_context)
  workbook.set_io_context(io_context)
  workbook
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
  let base_io_context = workbook_io_context(self)
  let resolved_transcoder = match transcoder {
    Some(value) => Some(value)
    None => base_io_context.charset_transcoder
  }
  let io_context = read_io_context(resolved_transcoder)
  let bytes = read_all_bytes(reader)
  let workbook = read_workbook_from_bytes(
    bytes, password, resolved_options, io_context,
  )
  workbook.set_io_context(io_context)
  workbook
}

///|
pub async fn open_file(
  path : String,
  password? : String = "",
  options? : Options = Options::new(),
  transcoder? : (String, Bytes) -> String raise XlsxError,
) -> Workbook raise XlsxError {
  let bytes = read_file_bytes(path)
  let io_context = workbook_io_context_with_file_path(
    read_io_context(transcoder),
    Some(path),
  )
  let workbook = read_workbook_from_bytes(bytes, password, options, io_context)
  workbook.set_io_context(io_context)
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
    None => raise InvalidSheetBackground(msg="image extension missing")
  }
  let bytes = read_file_bytes(path)
  self.set_sheet_background(sheet_name, bytes, extension)
}

///|
pub async fn Workbook::save(
  self : Workbook,
  options? : Options,
) -> Unit raise XlsxError {
  match workbook_io_context(self).file_path {
    Some(path) =>
      match options {
        Some(value) => self.save_as(path, options=value)
        None => self.save_as(path)
      }
    None => raise InvalidSheetOperation(msg="workbook path not set")
  }
}

///|
pub async fn Workbook::save_as(
  self : Workbook,
  path : String,
  options? : Options,
) -> Unit raise XlsxError {
  let extension = match extension_from_path(path) {
    Some(value) => value
    None => raise InvalidSheetOperation(msg="workbook file extension missing")
  }
  if extension != "xlsx" &&
    extension != "xlsm" &&
    extension != "xlam" &&
    extension != "xltm" &&
    extension != "xltx" {
    raise InvalidSheetOperation(msg="unsupported workbook file format")
  }
  let bytes = write_bytes_with_io(self, options, Some(path))
  @async/fs.write_file(path, bytes, create=0o644) catch {
    err => raise InvalidSheetOperation(msg="write file failed: \{err}")
  }
  self.set_io_context(
    workbook_io_context_with_file_path(workbook_io_context(self), Some(path)),
  )
}

///|
pub fn Workbook::write_to_buffer(
  self : Workbook,
  options? : Options,
) -> Bytes raise XlsxError {
  write_bytes(self, options)
}

///|
pub async fn[W : @async/io.Writer] Workbook::write(
  self : Workbook,
  writer : W,
  options? : Options,
) -> Unit raise XlsxError {
  match options {
    Some(value) => ignore(self.write_to(writer, options=value))
    None => ignore(self.write_to(writer))
  }
}

///|
pub async fn[W : @async/io.Writer] Workbook::write_to(
  self : Workbook,
  writer : W,
  options? : Options,
) -> Int raise XlsxError {
  let bytes = write_bytes(self, options)
  writer.write(bytes) catch {
    err => raise InvalidSheetOperation(msg="writer failed: \{err}")
  }
  bytes.length()
}
