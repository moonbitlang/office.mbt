///|
/// Serialize a document with a classic xref table and write it to a file.
///
/// `permission` is passed as the creation mode when the file is created.
pub async fn pdf_write_document_to_file(
  document : @pdflite.PdfDocument,
  path : StringView,
  permission? : Int = 0o644,
) -> Unit {
  @fs.write_file(path, @pdflite.pdf_write_document(document), create=permission)
}

///|
/// Serialize a document with an uncompressed xref stream and write it to a file.
pub async fn pdf_write_document_to_file_with_xref_stream(
  document : @pdflite.PdfDocument,
  path : StringView,
  permission? : Int = 0o644,
) -> Unit {
  @fs.write_file(
    path,
    @pdflite.pdf_write_document_with_xref_stream(document),
    create=permission,
  )
}

///|
/// Serialize a document with a Flate-compressed xref stream and write it to a file.
pub async fn pdf_write_document_to_file_with_compressed_xref_stream(
  document : @pdflite.PdfDocument,
  path : StringView,
  permission? : Int = 0o644,
) -> Unit {
  @fs.write_file(
    path,
    @pdflite.pdf_write_document_with_compressed_xref_stream(document),
    create=permission,
  )
}

///|
/// Serialize a document using the selected write mode and write it to a file.
pub async fn pdf_write_document_to_file_with_mode(
  document : @pdflite.PdfDocument,
  path : StringView,
  mode : @pdflite.PdfWriteMode,
  permission? : Int = 0o644,
) -> Unit {
  @fs.write_file(
    path,
    @pdflite.pdf_write_document_with_mode(document, mode),
    create=permission,
  )
}

///|
/// Generate a current trailer ID, serialize, and write the document to a file.
///
/// The output path is used as the ID-generation path input.
pub async fn pdf_write_document_to_file_with_generated_id(
  document : @pdflite.PdfDocument,
  path : StringView,
  mode? : @pdflite.PdfWriteMode = PdfWriteClassic,
  permission? : Int = 0o644,
) -> Unit {
  @fs.write_file(
    path,
    @pdflite.pdf_write_document_with_generated_id(
      document,
      path.to_owned(),
      mode~,
    ),
    create=permission,
  )
}

///|
/// Append a classic incremental update to `original_path` and write `path`.
pub async fn pdf_write_document_incremental_update_to_file(
  original_path : StringView,
  document : @pdflite.PdfDocument,
  path : StringView,
  permission? : Int = 0o644,
) -> Unit {
  @fs.write_file(
    path,
    @pdflite.pdf_write_document_incremental_update(
      @fs.read_file(original_path).binary(),
      document,
    ),
    create=permission,
  )
}

///|
/// Append an incremental update with an uncompressed xref stream.
pub async fn pdf_write_document_incremental_update_with_xref_stream_to_file(
  original_path : StringView,
  document : @pdflite.PdfDocument,
  path : StringView,
  permission? : Int = 0o644,
) -> Unit {
  @fs.write_file(
    path,
    @pdflite.pdf_write_document_incremental_update_with_xref_stream(
      @fs.read_file(original_path).binary(),
      document,
    ),
    create=permission,
  )
}

///|
/// Append an incremental update with a Flate-compressed xref stream.
pub async fn pdf_write_document_incremental_update_with_compressed_xref_stream_to_file(
  original_path : StringView,
  document : @pdflite.PdfDocument,
  path : StringView,
  permission? : Int = 0o644,
) -> Unit {
  @fs.write_file(
    path,
    @pdflite.pdf_write_document_incremental_update_with_compressed_xref_stream(
      @fs.read_file(original_path).binary(),
      document,
    ),
    create=permission,
  )
}

///|
/// Append an incremental update using the selected write mode.
pub async fn pdf_write_document_incremental_update_to_file_with_mode(
  original_path : StringView,
  document : @pdflite.PdfDocument,
  path : StringView,
  mode : @pdflite.PdfWriteMode,
  permission? : Int = 0o644,
) -> Unit {
  @fs.write_file(
    path,
    @pdflite.pdf_write_document_incremental_update_with_mode(
      @fs.read_file(original_path).binary(),
      document,
      mode,
    ),
    create=permission,
  )
}

///|
/// Generate a current trailer ID and append an incremental update to a file.
///
/// The output path is used as the ID-generation path input.
pub async fn pdf_write_document_incremental_update_to_file_with_generated_id(
  original_path : StringView,
  document : @pdflite.PdfDocument,
  path : StringView,
  mode? : @pdflite.PdfWriteMode = PdfWriteClassic,
  permission? : Int = 0o644,
) -> Unit {
  @fs.write_file(
    path,
    @pdflite.pdf_write_document_incremental_update_with_generated_id(
      @fs.read_file(original_path).binary(),
      document,
      path.to_owned(),
      mode~,
    ),
    create=permission,
  )
}
