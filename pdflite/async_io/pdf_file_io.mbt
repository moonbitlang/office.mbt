///|
pub async fn pdf_read_document_from_file(
  path : StringView,
) -> @pdflite.PdfDocument {
  @pdflite.pdf_read_document_from_bytes(@fs.read_file(path).binary())
}

///|
pub async fn pdf_read_document_from_file_with_passwords(
  path : StringView,
  user_password? : BytesView? = None,
  owner_password? : BytesView? = None,
) -> @pdflite.PdfDecryptionResult? {
  @pdflite.pdf_read_document_from_bytes_with_passwords(
    @fs.read_file(path).binary(),
    user_password~,
    owner_password~,
  )
}

///|
pub async fn pdf_write_document_to_file(
  document : @pdflite.PdfDocument,
  path : StringView,
  permission? : Int = 0o644,
) -> Unit {
  @fs.write_file(path, @pdflite.pdf_write_document(document), create=permission)
}

///|
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
