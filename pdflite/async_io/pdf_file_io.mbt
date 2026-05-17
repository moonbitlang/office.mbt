///|
/// Read and parse a PDF document from a file.
///
/// File bytes are loaded asynchronously and then passed to the byte reader.
pub async fn pdf_read_document_from_file(
  path : StringView,
) -> @pdflite.PdfDocument {
  @pdflite.pdf_read_document_from_bytes(@fs.read_file(path).binary())
}

///|
/// Read a specific PDF revision from a file.
///
/// Revision numbering follows the core reader: revision `1` is the newest
/// revision and larger numbers walk backward through `/Prev`.
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
/// Count revisions in a PDF file.
pub async fn pdf_revisions_from_file(path : StringView) -> Int {
  @pdflite.pdf_revisions_from_bytes(@fs.read_file(path).binary())
}

///|
/// Read only the PDF header version from a file.
///
/// The same header-probe rules as `pdf_read_header_from_bytes` apply.
pub async fn pdf_read_header_from_file(
  path : StringView,
) -> @pdflite.PdfVersion {
  @pdflite.pdf_read_header_from_bytes(@fs.read_file(path).binary())
}

///|
/// Return true if a file appears to be linearized.
pub async fn pdf_is_linearized_file(path : StringView) -> Bool {
  @pdflite.pdf_is_linearized(@fs.read_file(path).binary())
}

///|
/// Read a file and decrypt it with optional user and owner passwords.
///
/// Returns `None` when the file is encrypted and no supplied password
/// authenticates. Unencrypted files return a successful decryption result with
/// empty denied permissions.
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
/// Read a specific revision from a file and decrypt it with optional passwords.
///
/// Returns `None` when the revision is encrypted and no supplied password
/// authenticates.
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
/// Encrypt with 40-bit ARC4, serialize, and write to a file.
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
/// One filesystem path to embed in a PDF portfolio.
///
/// `filename` is both the path read from disk and the source name used for the
/// generated portfolio entry.
pub(all) struct PdfPortfolioFileEntry {
  filename : String
  relationship : String?
  description : String?
} derive(Debug, Eq, ToJson)

///|
/// Construct a filesystem-backed portfolio entry.
pub fn pdf_portfolio_file_entry(
  filename : String,
  relationship? : String? = None,
  description? : String? = None,
) -> PdfPortfolioFileEntry {
  { filename, relationship, description }
}

///|
/// Read files from disk and build a PDF portfolio.
///
/// PDF object construction is delegated to the core `PdfDocument::portfolio`
/// API; this package only owns the native filesystem reads.
pub async fn pdf_portfolio_from_files(
  document : @pdflite.PdfDocument,
  entries : ArrayView[PdfPortfolioFileEntry],
  mod_date? : @pdflite.PdfBytes? = None,
) -> @pdflite.PdfDocument {
  let loaded : Array[@pdflite.PdfPortfolioEntry] = []
  for entry in entries {
    loaded.push(
      @pdflite.pdf_portfolio_entry(
        entry.filename,
        @fs.read_file(entry.filename).binary(),
        relationship=entry.relationship,
        description=entry.description,
      ),
    )
  }
  @pdflite.pdf_portfolio(document, loaded, mod_date~)
}

///|
/// Encrypt with 128-bit ARC4 revision 3, serialize, and write to a file.
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
/// Encrypt with revision-4 ARC4 crypt filters, serialize, and write to a file.
///
/// `encrypt_metadata=false` preserves the PDF no-metadata encryption behavior.
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
/// Encrypt with AESV2 using caller-supplied IVs, serialize, and write to a file.
pub async fn pdf_write_encrypted_aesv2_document_to_file_with_iv_provider(
  document : @pdflite.PdfDocument,
  path : StringView,
  user_password : BytesView,
  owner_password : BytesView,
  denied_permissions : ArrayView[@pdflite.PdfPermission],
  iv_provider : (Int, Int, Int) -> @pdflite.PdfBytes raise @pdflite.PdfError,
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
/// Encrypt with AESV2 using the native random IV provider and write to a file.
///
/// This convenience helper is intended for the native async target.
pub async fn pdf_write_encrypted_aesv2_document_to_file(
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
    @pdflite.pdf_write_encrypted_aesv2_document(
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
/// Encrypt with AESV3/AES-256 using caller-supplied providers and write to a file.
///
/// `random_provider` supplies file key and salts; `iv_provider` supplies object
/// IVs. `iso=true` selects the ISO/PDF 2.0 hash variant.
pub async fn pdf_write_encrypted_aesv3_document_to_file_with_providers(
  document : @pdflite.PdfDocument,
  path : StringView,
  user_password : BytesView,
  owner_password : BytesView,
  denied_permissions : ArrayView[@pdflite.PdfPermission],
  random_provider : (@pdflite.PdfAesV3RandomField, Int) -> @pdflite.PdfBytes raise @pdflite.PdfError,
  iv_provider : (Int, Int, Int) -> @pdflite.PdfBytes raise @pdflite.PdfError,
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
/// Encrypt with AESV3/AES-256 using native random providers and write to a file.
///
/// `iso=true` selects the ISO/PDF 2.0 hash variant.
pub async fn pdf_write_encrypted_aesv3_document_to_file(
  document : @pdflite.PdfDocument,
  path : StringView,
  user_password : BytesView,
  owner_password : BytesView,
  denied_permissions : ArrayView[@pdflite.PdfPermission],
  iso? : Bool = false,
  encrypt_metadata? : Bool = true,
  mode? : @pdflite.PdfWriteMode = PdfWriteClassic,
  file_id? : BytesView = [],
  permission? : Int = 0o644,
) -> Unit {
  @fs.write_file(
    path,
    @pdflite.pdf_write_encrypted_aesv3_document(
      document,
      user_password,
      owner_password,
      denied_permissions,
      iso~,
      encrypt_metadata~,
      mode~,
      file_id~,
    ),
    create=permission,
  )
}

///|
/// Encrypt with the ISO AESV3/AES-256 variant using supplied providers.
pub async fn pdf_write_encrypted_aesv3_iso_document_to_file_with_providers(
  document : @pdflite.PdfDocument,
  path : StringView,
  user_password : BytesView,
  owner_password : BytesView,
  denied_permissions : ArrayView[@pdflite.PdfPermission],
  random_provider : (@pdflite.PdfAesV3RandomField, Int) -> @pdflite.PdfBytes raise @pdflite.PdfError,
  iv_provider : (Int, Int, Int) -> @pdflite.PdfBytes raise @pdflite.PdfError,
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
/// Encrypt with the ISO AESV3/AES-256 variant using native random providers.
pub async fn pdf_write_encrypted_aesv3_iso_document_to_file(
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
    @pdflite.pdf_write_encrypted_aesv3_iso_document(
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
