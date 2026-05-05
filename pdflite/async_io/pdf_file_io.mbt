///|
pub async fn pdf_read_document_from_file(
  path : StringView,
) -> @pdflite.PdfDocument {
  @pdflite.pdf_read_document_from_bytes(@fs.read_file(path).binary())
}

///|
pub async fn pdf_read_document_revision_from_file(
  path : StringView,
  revision : Int,
) -> @pdflite.PdfDocument {
  @pdflite.pdf_read_document_revision_from_bytes(
    @fs.read_file(path).binary(),
    revision,
  )
}

///|
pub async fn pdf_revisions_from_file(path : StringView) -> Int {
  @pdflite.pdf_revisions_from_bytes(@fs.read_file(path).binary())
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
pub async fn pdf_read_document_revision_from_file_with_passwords(
  path : StringView,
  revision : Int,
  user_password? : BytesView? = None,
  owner_password? : BytesView? = None,
) -> @pdflite.PdfDecryptionResult? {
  @pdflite.pdf_read_document_revision_from_bytes_with_passwords(
    @fs.read_file(path).binary(),
    revision,
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
pub async fn pdf_write_encrypted_40bit_document_to_file(
  document : @pdflite.PdfDocument,
  path : StringView,
  user_password : BytesView,
  owner_password : BytesView,
  denied_permissions : ArrayView[@pdflite.PdfPermission],
  mode? : @pdflite.PdfWriteMode = PdfWriteClassic,
  file_id? : BytesView = [],
  permission? : Int = 0o644,
) -> Unit {
  @fs.write_file(
    path,
    @pdflite.pdf_write_encrypted_40bit_document(
      document,
      user_password,
      owner_password,
      denied_permissions,
      mode~,
      file_id~,
    ),
    create=permission,
  )
}

///|
pub async fn pdf_write_encrypted_128bit_document_to_file(
  document : @pdflite.PdfDocument,
  path : StringView,
  user_password : BytesView,
  owner_password : BytesView,
  denied_permissions : ArrayView[@pdflite.PdfPermission],
  mode? : @pdflite.PdfWriteMode = PdfWriteClassic,
  file_id? : BytesView = [],
  permission? : Int = 0o644,
) -> Unit {
  @fs.write_file(
    path,
    @pdflite.pdf_write_encrypted_128bit_document(
      document,
      user_password,
      owner_password,
      denied_permissions,
      mode~,
      file_id~,
    ),
    create=permission,
  )
}

///|
pub async fn pdf_write_encrypted_128bit_r4_document_to_file(
  document : @pdflite.PdfDocument,
  path : StringView,
  user_password : BytesView,
  owner_password : BytesView,
  denied_permissions : ArrayView[@pdflite.PdfPermission],
  encrypt_metadata? : Bool = true,
  mode? : @pdflite.PdfWriteMode = PdfWriteClassic,
  file_id? : BytesView = [],
  permission? : Int = 0o644,
) -> Unit {
  @fs.write_file(
    path,
    @pdflite.pdf_write_encrypted_128bit_r4_document(
      document,
      user_password,
      owner_password,
      denied_permissions,
      encrypt_metadata~,
      mode~,
      file_id~,
    ),
    create=permission,
  )
}

///|
pub async fn pdf_write_encrypted_aesv2_document_to_file_with_iv_provider(
  document : @pdflite.PdfDocument,
  path : StringView,
  user_password : BytesView,
  owner_password : BytesView,
  denied_permissions : ArrayView[@pdflite.PdfPermission],
  iv_provider : (Int, Int, Int) -> @pdflite.PdfBytes,
  encrypt_metadata? : Bool = true,
  mode? : @pdflite.PdfWriteMode = PdfWriteClassic,
  file_id? : BytesView = [],
  permission? : Int = 0o644,
) -> Unit {
  @fs.write_file(
    path,
    @pdflite.pdf_write_encrypted_aesv2_document_with_iv_provider(
      document,
      user_password,
      owner_password,
      denied_permissions,
      iv_provider,
      encrypt_metadata~,
      mode~,
      file_id~,
    ),
    create=permission,
  )
}

///|
pub async fn pdf_write_encrypted_aesv3_document_to_file_with_providers(
  document : @pdflite.PdfDocument,
  path : StringView,
  user_password : BytesView,
  owner_password : BytesView,
  denied_permissions : ArrayView[@pdflite.PdfPermission],
  random_provider : (@pdflite.PdfAesV3RandomField, Int) -> @pdflite.PdfBytes,
  iv_provider : (Int, Int, Int) -> @pdflite.PdfBytes,
  iso? : Bool = false,
  encrypt_metadata? : Bool = true,
  mode? : @pdflite.PdfWriteMode = PdfWriteClassic,
  file_id? : BytesView = [],
  permission? : Int = 0o644,
) -> Unit {
  @fs.write_file(
    path,
    @pdflite.pdf_write_encrypted_aesv3_document_with_providers(
      document,
      user_password,
      owner_password,
      denied_permissions,
      random_provider,
      iv_provider,
      iso~,
      encrypt_metadata~,
      mode~,
      file_id~,
    ),
    create=permission,
  )
}

///|
pub async fn pdf_write_encrypted_aesv3_iso_document_to_file_with_providers(
  document : @pdflite.PdfDocument,
  path : StringView,
  user_password : BytesView,
  owner_password : BytesView,
  denied_permissions : ArrayView[@pdflite.PdfPermission],
  random_provider : (@pdflite.PdfAesV3RandomField, Int) -> @pdflite.PdfBytes,
  iv_provider : (Int, Int, Int) -> @pdflite.PdfBytes,
  encrypt_metadata? : Bool = true,
  mode? : @pdflite.PdfWriteMode = PdfWriteClassic,
  file_id? : BytesView = [],
  permission? : Int = 0o644,
) -> Unit {
  @fs.write_file(
    path,
    @pdflite.pdf_write_encrypted_aesv3_iso_document_with_providers(
      document,
      user_password,
      owner_password,
      denied_permissions,
      random_provider,
      iv_provider,
      encrypt_metadata~,
      mode~,
      file_id~,
    ),
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

///|
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
