///|
fn bounded_actual_above_limit(limit : Int) -> Int {
  if limit < 0x7fff_ffff {
    limit + 1
  } else {
    limit
  }
}

///|
fn bounded_int64_actual(value : Int64, limit : Int) -> Int {
  if value < 0L {
    bounded_actual_above_limit(limit)
  } else if value > 0x7fff_ffffL {
    0x7fff_ffff
  } else {
    value.to_int()
  }
}

///|
test "bounded file-size telemetry saturates instead of truncating" {
  inspect(
    bounded_int64_actual(2_147_483_648L, 128 * 1024 * 1024),
    content="2147483647",
  )
  inspect(bounded_actual_above_limit(0x7fff_ffff), content="2147483647")
}

///|
async fn[R : @async/io.Reader] read_all_bytes(
  reader : R,
  maximum? : Int = default_max_package_bytes,
  resource? : String = "file_bytes",
) -> Bytes {
  let output : Array[Byte] = []
  while true {
    // Keep one fixed bounded read window so a pipe producer can complete its
    // current write before a limit error tears down the surrounding task group.
    let chunk = reader.read_some(max_len=64 * 1024) catch {
      error if @async.is_being_cancelled() => raise error
      error =>
        raise InvalidSheetOperation(
          msg="reader failed: \{bounded_xlsx_error_text(error.to_string())}",
        )
    }
    match chunk {
      Some(bytes) => {
        if bytes.length() == 0 {
          raise InvalidSheetOperation(
            msg="reader returned an empty non-EOF chunk",
          )
        }
        if bytes.length() > maximum - output.length() {
          raise ResourceLimitExceeded(
            kind=resource,
            limit=maximum,
            actual=bounded_actual_above_limit(maximum),
          )
        }
        for byte in bytes {
          output.push(byte)
        }
      }
      None => break
    }
  }
  Bytes::from_array(output)
}

///|
#cfg(any(target="native", target="wasm"))
async fn read_bounded_package_file(
  path : String,
  maximum? : Int = default_max_package_bytes,
  resource? : String = "file_bytes",
) -> Bytes {
  let kind = @async/fs.kind(path) catch {
    error if @async.is_being_cancelled() => raise error
    error =>
      raise InvalidSheetOperation(
        msg="inspect file failed: \{bounded_xlsx_error_text(error.to_string())}",
      )
  }
  if !(kind is Regular) {
    raise InvalidSheetOperation(msg="input must be a regular file")
  }
  let file = @async/fs.open(
    path,
    mode=ReadOnly,
    create_mode=OpenExisting,
    sync=NoSync,
  ) catch {
    error if @async.is_being_cancelled() => raise error
    error =>
      raise InvalidSheetOperation(
        msg="open file failed: \{bounded_xlsx_error_text(error.to_string())}",
      )
  }
  defer file.close()
  if !(file.kind() is Regular) {
    raise InvalidSheetOperation(msg="input must remain a regular file")
  }
  let size = file.size() catch {
    error if @async.is_being_cancelled() => raise error
    error =>
      raise InvalidSheetOperation(
        msg="size file failed: \{bounded_xlsx_error_text(error.to_string())}",
      )
  }
  if size < 0L || size > maximum.to_int64() {
    raise ResourceLimitExceeded(
      kind=resource,
      limit=maximum,
      actual=bounded_int64_actual(size, maximum),
    )
  }
  let length = size.to_int()
  let buffer = FixedArray::make(length, b'\x00')
  let mut offset = 0
  while offset < length {
    let count = file.read_at(
      buffer,
      position=offset.to_int64(),
      offset~,
      len=length - offset,
    ) catch {
      error if @async.is_being_cancelled() => raise error
      error =>
        raise InvalidSheetOperation(
          msg="read file failed: \{bounded_xlsx_error_text(error.to_string())}",
        )
    }
    if count <= 0 || count > length - offset {
      raise InvalidSheetOperation(msg="file changed while being read")
    }
    offset += count
  }
  let final_size = file.size() catch {
    error if @async.is_being_cancelled() => raise error
    error =>
      raise InvalidSheetOperation(
        msg="size file failed: \{bounded_xlsx_error_text(error.to_string())}",
      )
  }
  if final_size != size {
    raise InvalidSheetOperation(msg="file changed while being read")
  }
  @async.pause()
  buffer.unsafe_reinterpret_as_bytes()
}

///|
#cfg(target="native")
async fn read_file_bytes(path : String) -> Bytes raise XlsxError {
  let data = @async/fs.read_file(path) catch {
    error =>
      raise InvalidSheetOperation(
        msg="read file failed: \{bounded_xlsx_error_text(error.to_string())}",
      )
  }
  data.binary()
}

///|
fn bounded_xlsx_error_text(value : String) -> String {
  let output = StringBuilder::new()
  let mut count = 0
  for character in value {
    if character == '\n' || character == '\r' {
      break
    }
    if count >= 240 {
      output.write_char('…') |> ignore
      break
    }
    output.write_char(character) |> ignore
    count += 1
  }
  output.to_string()
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
  limits : ReadLimits,
  io_context : WorkbookIOContext,
  cancelled : () -> Bool,
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
        read_zip_bytes(
          bytes,
          options=resolved_options,
          limits~,
          cancelled~,
          transcoder=value,
        )
      None =>
        read_zip_bytes(bytes, options=resolved_options, limits~, cancelled~)
    }
  } else {
    match io_context.charset_transcoder {
      Some(value) =>
        read_with_password(
          bytes,
          resolved_password,
          options=resolved_options,
          limits~,
          cancelled~,
          transcoder=value,
        )
      None =>
        read_with_password(
          bytes,
          resolved_password,
          options=resolved_options,
          limits~,
          cancelled~,
        )
    }
  }
}

///|
/// Reads an XLSX package asynchronously from a reader, stopping before the
/// configured compressed package limit is exceeded. Cancellation is preserved.
pub async fn[R : @async/io.Reader] open_reader(
  reader : R,
  password? : String = "",
  options? : Options = Options::new(),
  limits? : ReadLimits = ReadLimits::new(),
  transcoder? : (String, Bytes) -> String raise XlsxError,
) -> Workbook {
  let bytes = read_all_bytes(
    reader,
    maximum=limits.max_package_bytes,
    resource="package_bytes",
  )
  let io_context = read_io_context(transcoder)
  let workbook = read_workbook_from_bytes(
    bytes,
    password,
    options,
    limits,
    io_context,
    () => @async.is_being_cancelled(),
  )
  workbook.set_io_context(io_context)
  workbook
}

///|
/// Alias for `open_reader`, retained as the streaming XLSX read entry point.
pub async fn[R : @async/io.Reader] read_zip_reader(
  reader : R,
  password? : String = "",
  options? : Options = Options::new(),
  limits? : ReadLimits = ReadLimits::new(),
  transcoder? : (String, Bytes) -> String raise XlsxError,
) -> Workbook {
  match transcoder {
    Some(value) =>
      open_reader(reader, password~, options~, limits~, transcoder=value)
    None => open_reader(reader, password~, options~, limits~)
  }
}

///|
/// Replaces this workbook with one read asynchronously from a reader while
/// preserving its read options and transcoder when no overrides are supplied.
pub async fn[R : @async/io.Reader] Workbook::read_zip_reader(
  self : Workbook,
  reader : R,
  password? : String = "",
  options? : Options,
  limits? : ReadLimits = ReadLimits::new(),
  transcoder? : (String, Bytes) -> String raise XlsxError,
) -> Workbook {
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
  let bytes = read_all_bytes(
    reader,
    maximum=limits.max_package_bytes,
    resource="package_bytes",
  )
  let workbook = read_workbook_from_bytes(
    bytes,
    password,
    resolved_options,
    limits,
    io_context,
    () => @async.is_being_cancelled(),
  )
  workbook.set_io_context(io_context)
  workbook
}

///|
#cfg(any(target="native", target="wasm"))
/// Opens an XLSX package asynchronously after checking its regular-file type
/// and compressed size before allocation. A file that changes during the read
/// is rejected.
pub async fn open_file(
  path : String,
  password? : String = "",
  options? : Options = Options::new(),
  limits? : ReadLimits = ReadLimits::new(),
  transcoder? : (String, Bytes) -> String raise XlsxError,
) -> Workbook {
  let bytes = read_bounded_package_file(
    path,
    maximum=limits.max_package_bytes,
    resource="package_bytes",
  )
  let io_context = workbook_io_context_with_file_path(
    read_io_context(transcoder),
    Some(path),
  )
  let workbook = read_workbook_from_bytes(
    bytes,
    password,
    options,
    limits,
    io_context,
    () => @async.is_being_cancelled(),
  )
  workbook.set_io_context(io_context)
  workbook
}

///|
#cfg(target="native")
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
#cfg(target="native")
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
#cfg(target="native")
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
  @async/fs.write_file(
    path,
    bytes,
    create_mode=CreateOrTruncate,
    permission=0o644,
  ) catch {
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
