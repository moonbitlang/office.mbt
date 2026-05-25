///|
fn pdf_crypt_concat_bytes(parts : ArrayView[BytesView]) -> PdfBytes {
  pdf_bytes_concat_views(parts)
}

///|
fn pdf_aesv3_cbc_encrypt_no_padding_with_iv(
  key : BytesView,
  iv : BytesView,
  data : BytesView,
) -> PdfBytes raise PdfError {
  guard data.length() % 16 == 0 else {
    raise InvalidCryptoDataLength(data.length())
  }
  let output = Array::make(data.length(), b'\x00')
  let mut previous = pdf_crypt_chop_view(pdf_crypt_iv_name, iv, 16)
  let mut position = 0
  let mut output_position = 0
  while position < data.length() {
    let block = Array::make(16, b'\x00')
    for index in 0..<16 {
      block[index] = (data[position + index].to_int() ^ previous[index].to_int()).to_byte()
    }
    previous = @crypt_core.pdf_aes_encrypt_block(key, Bytes::from_array(block))
    for byte in previous {
      output[output_position] = byte
      output_position += 1
    }
    position += 16
  }
  Bytes::from_array(output)
}

///|
fn pdf_aesv3_shamix_mod3(data : BytesView) -> Int {
  let mut total = 0
  for index in 0..<16 {
    total += data[index].to_int()
  }
  total % 3
}

///|
fn pdf_aesv3_shamix_repeat(data : BytesView, count : Int) -> PdfBytes {
  let output : Array[Byte] = Array::new(capacity=data.length() * count)
  for _ in 0..<count {
    for byte in data {
      output.push(byte)
    }
  }
  Bytes::from_array(output)
}

///|
fn pdf_aesv3_shamix_next_hash(data : BytesView) -> PdfBytes {
  match pdf_aesv3_shamix_mod3(data) {
    0 => @crypt_core.pdf_sha256_digest(data)
    1 => @crypt_core.pdf_sha384_digest(data)
    _ => @crypt_core.pdf_sha512_digest(data)
  }
}

///|
fn pdf_aesv3_shamix(
  password : BytesView,
  user_entry : BytesView?,
  input : BytesView,
) -> PdfBytes raise PdfError {
  let user_data = match user_entry {
    Some(value) => value
    None => []
  }
  let mut digest = @crypt_core.pdf_sha256_digest(input)
  let mut round = 0
  let mut last_encrypted_byte = 0
  while !(round >= 64 && last_encrypted_byte <= round - 32) {
    round += 1
    let repeated_input = pdf_crypt_concat_bytes([password, digest, user_data])
    let repeated = pdf_aesv3_shamix_repeat(repeated_input, 64)
    let encrypted = pdf_aesv3_cbc_encrypt_no_padding_with_iv(
      digest[:16],
      digest[16:32],
      repeated,
    )
    last_encrypted_byte = encrypted[encrypted.length() - 1].to_int()
    digest = pdf_aesv3_shamix_next_hash(encrypted)
  }
  digest[:32].to_owned()
}

///|
fn pdf_aesv3_password_hash(
  iso : Bool,
  password : BytesView,
  salt : BytesView,
  user_entry? : BytesView = [],
) -> PdfBytes raise PdfError {
  let input = pdf_crypt_concat_bytes([password, salt, user_entry])
  if iso {
    let user_data = if user_entry.length() == 0 {
      None
    } else {
      Some(user_entry)
    }
    pdf_aesv3_shamix(password, user_data, input)
  } else {
    @crypt_core.pdf_sha256_digest(input)
  }
}

///|
fn pdf_aesv3_random_field_key(field : PdfAesV3RandomField) -> PdfName {
  match field {
    PdfAesV3FileKey => pdf_crypt_file_key_name
    PdfAesV3UserValidationSalt => pdf_crypt_user_validation_salt_name
    PdfAesV3UserKeySalt => pdf_crypt_user_key_salt_name
    PdfAesV3OwnerValidationSalt => pdf_crypt_owner_validation_salt_name
    PdfAesV3OwnerKeySalt => pdf_crypt_owner_key_salt_name
    PdfAesV3PermissionsPadding => pdf_crypt_perms_padding_name
  }
}

///|
fn pdf_aesv3_random_bytes(
  random_provider : (PdfAesV3RandomField, Int) -> PdfBytes raise PdfError,
  field : PdfAesV3RandomField,
  length : Int,
) -> PdfBytes raise PdfError {
  pdf_crypt_chop_string(
    pdf_aesv3_random_field_key(field),
    random_provider(field, length),
    length,
  )
}

///|
fn pdf_aesv3_entry(
  iso : Bool,
  password : BytesView,
  validation_salt : BytesView,
  key_salt : BytesView,
  user_entry? : BytesView = [],
) -> PdfBytes raise PdfError {
  let digest = pdf_aesv3_password_hash(
    iso,
    password,
    validation_salt,
    user_entry~,
  )
  pdf_crypt_concat_bytes([digest[:32], validation_salt, key_salt])
}

///|
fn pdf_aesv3_cbc_encrypt_no_padding(
  key : BytesView,
  data : BytesView,
) -> PdfBytes raise PdfError {
  pdf_aesv3_cbc_encrypt_no_padding_with_iv(key, Bytes::new(16), data)
}

///|
fn pdf_aesv3_wrap_file_key(
  iso : Bool,
  password : BytesView,
  key_salt : BytesView,
  file_key : BytesView,
  user_entry? : BytesView = [],
) -> PdfBytes raise PdfError {
  let digest = pdf_aesv3_password_hash(iso, password, key_salt, user_entry~)
  pdf_aesv3_cbc_encrypt_no_padding(digest, file_key)
}

///|
fn pdf_aesv3_permissions_entry(
  file_key : BytesView,
  permissions : Int,
  encrypt_metadata : Bool,
  padding : BytesView,
) -> PdfBytes raise PdfError {
  let block = Array::make(16, b'\x00')
  let mut position = 0
  for shift in [0, 8, 16, 24] {
    block[position] = @crypt_core.pdf_crypt_low_byte(permissions, shift)
    position += 1
  }
  for _ in 0..<4 {
    block[position] = (255).to_byte()
    position += 1
  }
  block[position] = if encrypt_metadata { b'T' } else { b'F' }
  block[position + 1] = b'a'
  block[position + 2] = b'd'
  block[position + 3] = b'b'
  position += 4
  for
    byte in pdf_crypt_chop_view(
      pdf_aesv3_random_field_key(PdfAesV3PermissionsPadding),
      padding,
      4,
    ) {
    block[position] = byte
    position += 1
  }
  @crypt_core.pdf_aes_encrypt_block(file_key, Bytes::from_array(block))
}

///|
/// Authenticate an AESV3 user password entry.
///
/// `iso` selects the ISO/PDF 2.0 hash variant. Short `/U` entries raise
/// `PdfError::EncryptionDictionaryEntryTooShort`.
fn pdf_authenticate_user_password_aesv3(
  iso : Bool,
  password : BytesView,
  user_entry : BytesView,
) -> Bool raise PdfError {
  if user_entry.length() < 48 {
    raise EncryptionDictionaryEntryTooShort(pdf_crypt_u_name)
  }
  let expected = pdf_aesv3_password_hash(iso, password, user_entry[32:40])
  @crypt_core.pdf_bytes_prefix_equal(user_entry, expected, 32)
}

///|
/// Authenticate an AESV3 owner password entry.
///
/// Owner authentication incorporates the 48-byte user entry as required by the
/// AESV3 security algorithm. Short `/O` or `/U` entries raise `PdfError`.
fn pdf_authenticate_owner_password_aesv3(
  iso : Bool,
  password : BytesView,
  user_entry : BytesView,
  owner_entry : BytesView,
) -> Bool raise PdfError {
  if owner_entry.length() < 48 {
    raise EncryptionDictionaryEntryTooShort(pdf_crypt_o_name)
  }
  if user_entry.length() < 48 {
    raise EncryptionDictionaryEntryTooShort(pdf_crypt_u_name)
  }
  let expected = pdf_aesv3_password_hash(
    iso,
    password,
    owner_entry[32:40],
    user_entry=user_entry[:48],
  )
  @crypt_core.pdf_bytes_prefix_equal(owner_entry, expected, 32)
}

///|
fn pdf_aesv3_crypt_entry(
  key : PdfName,
  entry : PdfBytes?,
) -> PdfBytes raise PdfError {
  match entry {
    Some(value) => pdf_crypt_chop_string(key, value, 32)
    None => raise EncryptionDictionaryEntryExpected(key)
  }
}

///|
fn pdf_aesv3_unwrap_file_key(
  digest : PdfBytes,
  encrypted_key : PdfBytes,
) -> PdfBytes raise PdfError {
  let zero_iv = Bytes::new(16)
  let data = pdf_crypt_concat_bytes([zero_iv, encrypted_key])
  @crypt_core.pdf_aes_cbc_decrypt(digest, data, remove_padding=false)
}

///|
fn pdf_aesv3_permissions_key() -> PdfName {
  pdf_crypt_perms_name
}

///|
fn pdf_aesv3_permissions_from_entry(
  file_key : BytesView,
  permissions_entry : BytesView,
) -> Int raise PdfError {
  if permissions_entry.length() < 16 {
    raise EncryptionDictionaryEntryTooShort(pdf_aesv3_permissions_key())
  }
  let decrypted = @crypt_core.pdf_aes_ecb_decrypt(
    file_key,
    permissions_entry[:16],
    remove_padding=false,
  )
  guard decrypted[9] == b'a' && decrypted[10] == b'd' && decrypted[11] == b'b' else {
    raise EncryptionPermissionsCorrupt
  }
  decrypted[0].to_int() |
  (decrypted[1].to_int() << 8) |
  (decrypted[2].to_int() << 16) |
  (decrypted[3].to_int() << 24)
}

///|
fn PdfEncryptionValues::validate_aesv3_permissions(
  self : PdfEncryptionValues,
  file_key : BytesView,
) -> Unit raise PdfError {
  let permissions_entry = match self.permissions_entry {
    Some(value) => value
    None => raise EncryptionDictionaryEntryExpected(pdf_aesv3_permissions_key())
  }
  let permissions = pdf_aesv3_permissions_from_entry(
    file_key, permissions_entry,
  )
  if permissions != self.permissions {
    raise EncryptionPermissionsMismatch(permissions, self.permissions)
  }
}

///|
fn pdf_file_key_for_user_password_aesv3(
  iso : Bool,
  password : BytesView,
  user_entry : BytesView,
  user_encryption_key : PdfBytes?,
) -> PdfBytes? raise PdfError {
  if pdf_authenticate_user_password_aesv3(iso, password, user_entry) {
    let digest = pdf_aesv3_password_hash(iso, password, user_entry[40:48])
    let encrypted_key = pdf_aesv3_crypt_entry(
      pdf_crypt_ue_name, user_encryption_key,
    )
    Some(pdf_aesv3_unwrap_file_key(digest, encrypted_key))
  } else {
    None
  }
}

///|
fn pdf_file_key_for_owner_password_aesv3(
  iso : Bool,
  password : BytesView,
  user_entry : BytesView,
  owner_entry : BytesView,
  owner_encryption_key : PdfBytes?,
) -> PdfBytes? raise PdfError {
  if pdf_authenticate_owner_password_aesv3(
      iso, password, user_entry, owner_entry,
    ) {
    let digest = pdf_aesv3_password_hash(
      iso,
      password,
      owner_entry[40:48],
      user_entry=user_entry[:48],
    )
    let encrypted_key = pdf_aesv3_crypt_entry(
      pdf_crypt_oe_name, owner_encryption_key,
    )
    Some(pdf_aesv3_unwrap_file_key(digest, encrypted_key))
  } else {
    None
  }
}
