///|
/// Encrypt with 40-bit ARC4, serialize, and write to a file.
pub async fn pdf_write_encrypted_40bit_document_to_file(
  document : @pdflite.PdfDocument,
  path : StringView,
  user_password : BytesView,
  owner_password : BytesView,
  denied_permissions : ArrayView[@crypt_core.PdfPermission],
  mode? : @writer.PdfWriteMode = PdfWriteClassic,
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
/// Encrypt with 128-bit ARC4 revision 3, serialize, and write to a file.
pub async fn pdf_write_encrypted_128bit_document_to_file(
  document : @pdflite.PdfDocument,
  path : StringView,
  user_password : BytesView,
  owner_password : BytesView,
  denied_permissions : ArrayView[@crypt_core.PdfPermission],
  mode? : @writer.PdfWriteMode = PdfWriteClassic,
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
  denied_permissions : ArrayView[@crypt_core.PdfPermission],
  encrypt_metadata? : Bool = true,
  mode? : @writer.PdfWriteMode = PdfWriteClassic,
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
  denied_permissions : ArrayView[@crypt_core.PdfPermission],
  iv_provider : (Int, Int, Int) -> @pdflite.PdfBytes raise @pdflite.PdfError,
  encrypt_metadata? : Bool = true,
  mode? : @writer.PdfWriteMode = PdfWriteClassic,
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
  denied_permissions : ArrayView[@crypt_core.PdfPermission],
  encrypt_metadata? : Bool = true,
  mode? : @writer.PdfWriteMode = PdfWriteClassic,
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
  denied_permissions : ArrayView[@crypt_core.PdfPermission],
  random_provider : (@crypt_core.PdfAesV3RandomField, Int) -> @pdflite.PdfBytes raise @pdflite.PdfError,
  iv_provider : (Int, Int, Int) -> @pdflite.PdfBytes raise @pdflite.PdfError,
  iso? : Bool = false,
  encrypt_metadata? : Bool = true,
  mode? : @writer.PdfWriteMode = PdfWriteClassic,
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
  denied_permissions : ArrayView[@crypt_core.PdfPermission],
  iso? : Bool = false,
  encrypt_metadata? : Bool = true,
  mode? : @writer.PdfWriteMode = PdfWriteClassic,
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
  denied_permissions : ArrayView[@crypt_core.PdfPermission],
  random_provider : (@crypt_core.PdfAesV3RandomField, Int) -> @pdflite.PdfBytes raise @pdflite.PdfError,
  iv_provider : (Int, Int, Int) -> @pdflite.PdfBytes raise @pdflite.PdfError,
  encrypt_metadata? : Bool = true,
  mode? : @writer.PdfWriteMode = PdfWriteClassic,
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
  denied_permissions : ArrayView[@crypt_core.PdfPermission],
  encrypt_metadata? : Bool = true,
  mode? : @writer.PdfWriteMode = PdfWriteClassic,
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
