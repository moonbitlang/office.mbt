///|
priv struct WorkbookIOContext {
  file_path : String?
  zip_writer : ((@zip.Archive) -> Bytes raise)?
  charset_transcoder : ((String, Bytes) -> String raise XlsxError)?
}

///|
fn empty_workbook_io_context() -> WorkbookIOContext {
  { file_path: None, zip_writer: None, charset_transcoder: None }
}

///|
fn workbook_io_context(workbook : Workbook) -> WorkbookIOContext {
  {
    file_path: workbook.file_path,
    zip_writer: workbook.zip_writer,
    charset_transcoder: workbook.charset_transcoder,
  }
}

///|
fn workbook_io_context_with_file_path(
  io_context : WorkbookIOContext,
  file_path : String?,
) -> WorkbookIOContext {
  {
    file_path,
    zip_writer: io_context.zip_writer,
    charset_transcoder: io_context.charset_transcoder,
  }
}

///|
fn workbook_io_context_with_transcoder(
  io_context : WorkbookIOContext,
  transcoder : ((String, Bytes) -> String raise XlsxError)?,
) -> WorkbookIOContext {
  {
    file_path: io_context.file_path,
    zip_writer: io_context.zip_writer,
    charset_transcoder: transcoder,
  }
}

///|
fn Workbook::set_io_context(
  self : Workbook,
  io_context : WorkbookIOContext,
) -> Unit {
  self.file_path = io_context.file_path
  self.zip_writer = io_context.zip_writer
  self.charset_transcoder = io_context.charset_transcoder
}
