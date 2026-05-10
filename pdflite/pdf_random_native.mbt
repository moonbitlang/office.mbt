///|
#borrow(output)
extern "C" fn pdf_secure_random_bytes_ffi(
  output : FixedArray[Byte],
  length : Int,
) -> Int = "pdflite_secure_random_bytes"

///|
fn pdf_secure_random_bytes_with_provider(
  length : Int,
  fill : (FixedArray[Byte], Int) -> Int,
) -> PdfBytes raise PdfError {
  if length < 0 {
    raise InvalidReadLength(length)
  }
  let output = FixedArray::make(length, b'\x00')
  if fill(output, length) != 1 {
    raise RandomBytesUnavailable
  }
  output.unsafe_reinterpret_as_bytes()
}

///|
/// Return cryptographically secure random bytes on the native target.
///
/// The native stub uses the platform RNG (`BCryptGenRandom` on Windows and
/// `/dev/urandom` on Unix-like systems). Negative lengths raise
/// `InvalidReadLength`; RNG failures raise `RandomBytesUnavailable`.
pub fn pdf_secure_random_bytes(length : Int) -> PdfBytes raise PdfError {
  pdf_secure_random_bytes_with_provider(length, pdf_secure_random_bytes_ffi)
}

///|
fn pdf_secure_aes_iv_provider(
  _object_number : Int,
  _generation : Int,
  _index : Int,
) -> PdfBytes raise PdfError {
  pdf_secure_random_bytes(16)
}

///|
fn pdf_secure_aesv3_random_provider(
  _field : PdfAesV3RandomField,
  length : Int,
) -> PdfBytes raise PdfError {
  pdf_secure_random_bytes(length)
}

///|
/// Encrypt a copy of the document with revision-4 AESV2 using native randomness.
///
/// Fresh random IVs are generated for encrypted strings and streams. When
/// `file_id` is empty, a random 16-byte first trailer ID is generated before
/// deriving the encryption key.
pub fn PdfDocument::encrypt_128bit_aesv2(
  self : PdfDocument,
  user_password : BytesView,
  owner_password : BytesView,
  denied_permissions : ArrayView[PdfPermission],
  encrypt_metadata? : Bool = true,
  file_id? : BytesView = [],
) -> PdfDocument raise PdfError {
  let resolved_file_id = if file_id.length() > 0 {
    file_id.to_owned()
  } else {
    pdf_secure_random_bytes(16)
  }
  self.encrypt_128bit_aesv2_with_iv_provider(
    user_password,
    owner_password,
    denied_permissions,
    pdf_secure_aes_iv_provider,
    encrypt_metadata~,
    file_id=resolved_file_id,
  )
}

///|
/// Re-encrypt a decrypted AESV2 document using native random IVs.
///
/// The document must carry saved encryption state from a previous decrypt
/// operation; `password` is used to recover the file key for re-encryption.
pub fn PdfDocument::recrypt_with_password_aesv2(
  self : PdfDocument,
  password : BytesView,
) -> PdfDocument raise PdfError {
  self.recrypt_with_password_aesv2_with_iv_provider(
    password, pdf_secure_aes_iv_provider,
  )
}

///|
/// Encrypt a copy of the document with AESV3/AES-256 using native randomness.
///
/// Native random bytes supply the file key, salts, permissions padding, and
/// per-object IVs. Set `iso=true` for the ISO/PDF 2.0 AESV3 hash variant.
pub fn PdfDocument::encrypt_256bit_aesv3(
  self : PdfDocument,
  user_password : BytesView,
  owner_password : BytesView,
  denied_permissions : ArrayView[PdfPermission],
  iso? : Bool = false,
  encrypt_metadata? : Bool = true,
  file_id? : BytesView = [],
) -> PdfDocument raise PdfError {
  self.encrypt_256bit_aesv3_with_providers(
    user_password,
    owner_password,
    denied_permissions,
    pdf_secure_aesv3_random_provider,
    pdf_secure_aes_iv_provider,
    iso~,
    encrypt_metadata~,
    file_id~,
  )
}

///|
/// Encrypt a copy of the document with the ISO AESV3/AES-256 variant.
///
/// This is the native-random convenience wrapper for
/// `encrypt_256bit_aesv3` with `iso=true`.
pub fn PdfDocument::encrypt_256bit_aesv3_iso(
  self : PdfDocument,
  user_password : BytesView,
  owner_password : BytesView,
  denied_permissions : ArrayView[PdfPermission],
  encrypt_metadata? : Bool = true,
  file_id? : BytesView = [],
) -> PdfDocument raise PdfError {
  self.encrypt_256bit_aesv3(
    user_password,
    owner_password,
    denied_permissions,
    iso=true,
    encrypt_metadata~,
    file_id~,
  )
}

///|
/// CamlPDF-compatible AESV2 encryption wrapper using native randomness.
pub fn pdf_encrypt_pdf_AES(
  document : PdfDocument,
  encrypt_metadata : Bool,
  user_password : BytesView,
  owner_password : BytesView,
  denied_permissions : ArrayView[PdfPermission],
  file_id? : BytesView = [],
) -> PdfDocument raise PdfError {
  document.encrypt_128bit_aesv2(
    user_password,
    owner_password,
    denied_permissions,
    encrypt_metadata~,
    file_id~,
  )
}

///|
/// CamlPDF-compatible AESV3/AES-256 encryption wrapper using native randomness.
pub fn pdf_encrypt_pdf_AES256(
  document : PdfDocument,
  encrypt_metadata : Bool,
  user_password : BytesView,
  owner_password : BytesView,
  denied_permissions : ArrayView[PdfPermission],
  file_id? : BytesView = [],
) -> PdfDocument raise PdfError {
  document.encrypt_256bit_aesv3(
    user_password,
    owner_password,
    denied_permissions,
    encrypt_metadata~,
    file_id~,
  )
}

///|
/// CamlPDF-compatible ISO AESV3/AES-256 encryption wrapper using native randomness.
pub fn pdf_encrypt_pdf_AES256ISO(
  document : PdfDocument,
  encrypt_metadata : Bool,
  user_password : BytesView,
  owner_password : BytesView,
  denied_permissions : ArrayView[PdfPermission],
  file_id? : BytesView = [],
) -> PdfDocument raise PdfError {
  document.encrypt_256bit_aesv3_iso(
    user_password,
    owner_password,
    denied_permissions,
    encrypt_metadata~,
    file_id~,
  )
}

///|
/// Re-encrypt a decrypted AESV3 document using native random IVs.
///
/// The document must carry saved encryption state from a previous decrypt
/// operation; `password` is used to recover the file key for re-encryption.
pub fn PdfDocument::recrypt_with_password_aesv3(
  self : PdfDocument,
  password : BytesView,
) -> PdfDocument raise PdfError {
  self.recrypt_with_password_aesv3_with_iv_provider(
    password, pdf_secure_aes_iv_provider,
  )
}

///|
/// Encrypt and serialize a document with AESV2 using native randomness.
///
/// The encrypted document is written with the requested write mode. Supplying a
/// `file_id` controls the trailer ID used for key derivation; IVs remain random.
pub fn pdf_write_encrypted_aesv2_document(
  document : PdfDocument,
  user_password : BytesView,
  owner_password : BytesView,
  denied_permissions : ArrayView[PdfPermission],
  encrypt_metadata? : Bool = true,
  mode? : PdfWriteMode = PdfWriteClassic,
  file_id? : BytesView = [],
) -> PdfBytes raise PdfError {
  pdf_write_document_with_mode(
    document.encrypt_128bit_aesv2(
      user_password,
      owner_password,
      denied_permissions,
      encrypt_metadata~,
      file_id~,
    ),
    mode,
  )
}

///|
/// Encrypt and serialize a document with AESV3/AES-256 using native randomness.
///
/// Set `iso=true` for the ISO/PDF 2.0 hash variant. The requested write mode is
/// applied after encryption.
pub fn pdf_write_encrypted_aesv3_document(
  document : PdfDocument,
  user_password : BytesView,
  owner_password : BytesView,
  denied_permissions : ArrayView[PdfPermission],
  iso? : Bool = false,
  encrypt_metadata? : Bool = true,
  mode? : PdfWriteMode = PdfWriteClassic,
  file_id? : BytesView = [],
) -> PdfBytes raise PdfError {
  pdf_write_document_with_mode(
    document.encrypt_256bit_aesv3(
      user_password,
      owner_password,
      denied_permissions,
      iso~,
      encrypt_metadata~,
      file_id~,
    ),
    mode,
  )
}

///|
/// Encrypt and serialize a document with the ISO AESV3/AES-256 variant.
pub fn pdf_write_encrypted_aesv3_iso_document(
  document : PdfDocument,
  user_password : BytesView,
  owner_password : BytesView,
  denied_permissions : ArrayView[PdfPermission],
  encrypt_metadata? : Bool = true,
  mode? : PdfWriteMode = PdfWriteClassic,
  file_id? : BytesView = [],
) -> PdfBytes raise PdfError {
  pdf_write_encrypted_aesv3_document(
    document,
    user_password,
    owner_password,
    denied_permissions,
    iso=true,
    encrypt_metadata~,
    mode~,
    file_id~,
  )
}
