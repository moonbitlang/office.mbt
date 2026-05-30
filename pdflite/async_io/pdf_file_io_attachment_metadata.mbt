///|
fn pdf_async_io_name(text : String) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn pdf_async_io_join_path(directory : StringView, filename : String) -> String {
  let dir = directory.to_owned()
  if dir == "" {
    filename
  } else {
    dir + "/" + filename
  }
}

///|
fn pdf_async_io_attachment_data(
  attachment : @attachment.PdfAttachment,
) -> @pdflite.PdfBytes raise @pdflite.PdfError {
  match attachment.data {
    Some(data) => data
    None => raise DictionaryKeyNotFound(pdf_async_io_name("/EF"))
  }
}

///|
/// Read a filesystem path and attach its bytes to the document.
///
/// PDF object construction is delegated to the core in-memory attachment API;
/// this wrapper only owns the native filesystem read. `path` is also used as
/// the source filename, so the core API stores its basename in the file spec.
pub async fn pdf_attach_file_from_path(
  document : @pdflite.PdfDocument,
  path : StringView,
  keep_version? : Bool = false,
  page_number? : Int? = None,
  relationship? : String? = None,
  description? : String? = None,
) -> @pdflite.PdfDocument {
  @pdflite.pdf_attach_file(
    document,
    path.to_owned(),
    @fs.read_file(path).binary(),
    keep_version~,
    page_number~,
    relationship~,
    description~,
  )
}

///|
fn pdf_async_io_catalog_metadata_number(
  document : @pdflite.PdfDocument,
) -> Int? raise @pdflite.PdfError {
  let root = match
    document.lookup_direct(pdf_async_io_name("/Root"), document.trailer_dict()) {
    Some(root) => root
    None => raise SoftError("malformed file")
  }
  root.find_indirect(pdf_async_io_name("/Metadata"))
}

///|
fn pdf_async_io_is_metadata_object(
  document : @pdflite.PdfDocument,
  object : @syntax.PdfObject,
) -> Bool {
  match document.lookup_direct(pdf_async_io_name("/Type"), object) {
    Some(PdfNameObject(name)) => name == pdf_async_io_name("/Metadata")
    _ => false
  }
}

///|
fn pdf_async_io_metadata_stream_bytes(
  document : @pdflite.PdfDocument,
  object : @syntax.PdfObject,
) -> @pdflite.PdfBytes raise @pdflite.PdfError {
  document.pdf_decode_stream(object).stream_bytes()
}

///|
/// Set the catalog metadata XML stream from a file.
///
/// This is the native filesystem counterpart of cpdfmetadata's
/// `set_metadata`: the file is read as bytes and delegated to the portable
/// in-memory metadata setter.
pub async fn pdf_set_metadata_from_file(
  keep_version : Bool,
  path : StringView,
  document : @pdflite.PdfDocument,
) -> @pdflite.PdfDocument {
  document.set_metadata_from_bytes(@fs.read_file(path).binary(), keep_version~)
}

///|
/// Source-spelled alias matching cpdfmetadata's `set_metadata`.
pub async fn pdf_set_metadata(
  keep_version : Bool,
  path : StringView,
  document : @pdflite.PdfDocument,
) -> @pdflite.PdfDocument {
  pdf_set_metadata_from_file(keep_version, path, document)
}

///|
/// Write the catalog metadata XML stream to a file when one is present.
///
/// A document without catalog metadata is a no-op, matching cpdfmetadata's
/// `print_metadata` behavior of emitting nothing when metadata is absent.
pub async fn pdf_write_metadata_to_file(
  document : @pdflite.PdfDocument,
  path : StringView,
  permission? : Int = 0o644,
) -> Unit {
  match document.metadata() {
    Some(metadata) => @fs.write_file(path, metadata, create=permission)
    None => ()
  }
}

///|
/// Extract every metadata stream to `directory`.
///
/// The catalog metadata object is written as `main.xml`, and other parsed
/// `/Type /Metadata` stream objects are written as `obj<num>.xml`, matching
/// cpdfmetadata's `extract_all_metadata` naming scheme.
pub async fn pdf_extract_all_metadata_to_directory(
  document : @pdflite.PdfDocument,
  directory : StringView,
  permission? : Int = 0o644,
) -> Unit {
  let main_number = pdf_async_io_catalog_metadata_number(document)
  match main_number {
    Some(number) =>
      @fs.write_file(
        pdf_async_io_join_path(directory, "main.xml"),
        pdf_async_io_metadata_stream_bytes(
          document,
          document.lookup_object_or_null(number),
        ),
        create=permission,
      )
    None => ()
  }
  for entry in document.parsed_object_entries() {
    if Some(entry.0) != main_number &&
      pdf_async_io_is_metadata_object(document, entry.2) {
      @fs.write_file(
        pdf_async_io_join_path(directory, "obj" + entry.0.to_string() + ".xml"),
        pdf_async_io_metadata_stream_bytes(document, entry.2),
        create=permission,
      )
    }
  }
}

///|
/// Source-spelled alias matching cpdfmetadata's `extract_all_metadata`.
pub async fn pdf_extract_all_metadata(
  document : @pdflite.PdfDocument,
  directory : StringView,
  permission? : Int = 0o644,
) -> Unit {
  pdf_extract_all_metadata_to_directory(document, directory, permission~)
}

///|
/// Dump all listed attachments into `directory`.
///
/// Attachment names are sanitized with the core cpdf-compatible filename
/// filter. Existing files with the same sanitized name are overwritten by
/// `@fs.write_file`, matching cpdf's simple filename-based dump behavior.
pub async fn pdf_dump_attached_files_to_directory(
  document : @pdflite.PdfDocument,
  directory : StringView,
  permission? : Int = 0o644,
) -> Unit {
  for attachment in document.list_attached_files() {
    let filename = @pdflite.pdf_attachment_remove_unsafe_characters(
      attachment.name,
    )
    @fs.write_file(
      pdf_async_io_join_path(directory, filename),
      pdf_async_io_attachment_data(attachment),
      create=permission,
    )
  }
}

///|
/// Compatibility wrapper matching cpdfattach's `dump_attached_files` name.
pub async fn pdf_dump_attached_files(
  document : @pdflite.PdfDocument,
  directory : StringView,
  permission? : Int = 0o644,
) -> Unit {
  pdf_dump_attached_files_to_directory(document, directory, permission~)
}
