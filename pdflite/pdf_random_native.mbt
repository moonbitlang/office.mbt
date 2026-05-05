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
    file_id=resolved_file_id[:],
  )
}

///|
pub fn PdfDocument::recrypt_with_password_aesv2(
  self : PdfDocument,
  password : BytesView,
) -> PdfDocument raise PdfError {
  self.recrypt_with_password_aesv2_with_iv_provider(
    password, pdf_secure_aes_iv_provider,
  )
}

///|
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
