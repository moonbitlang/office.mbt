///|
pub(all) enum PdfPermission {
  PdfNoEdit
  PdfNoPrint
  PdfNoCopy
  PdfNoAnnot
  PdfNoForms
  PdfNoExtract
  PdfNoAssemble
  PdfNoHqPrint
} derive(Debug, Eq, ToJson)

///|
fn pdf_password_padding_fixed() -> FixedArray[Byte] {
  [
    0x28, 0xbf, 0x4e, 0x5e, 0x4e, 0x75, 0x8a, 0x41, 0x64, 0x00, 0x4e, 0x56, 0xff,
    0xfa, 0x01, 0x08, 0x2e, 0x2e, 0x00, 0xb6, 0xd0, 0x68, 0x3e, 0x80, 0x2f, 0x0c,
    0xa9, 0xfe, 0x64, 0x53, 0x69, 0x7a,
  ]
}

///|
pub fn pdf_password_padding() -> PdfBytes {
  Bytes::from_array(pdf_password_padding_fixed())
}

///|
pub fn pdf_pad_password(password : BytesView) -> PdfBytes {
  let padding = pdf_password_padding_fixed()
  let output : Array[Byte] = []
  let copied = if password.length() < 32 { password.length() } else { 32 }
  for index in 0..<copied {
    output.push(password[index])
  }
  for index in copied..<32 {
    output.push(padding[index - copied])
  }
  Bytes::from_array(output)
}

///|
fn pdf_crypt_low_byte(value : Int, shift : Int) -> Byte {
  ((value >> shift) & 0xff).to_byte()
}

///|
pub fn pdf_encryption_file_key(
  no_encrypt_metadata : Bool,
  password : BytesView,
  revision : Int,
  owner_entry : BytesView,
  permissions : Int,
  file_id : BytesView,
  key_length_bits : Int,
) -> PdfBytes {
  let md5 = @crypto.MD5::new()
  let padded_password = pdf_pad_password(password)
  md5.update(padded_password[:])
  md5.update(owner_entry)
  let permissions_bytes : FixedArray[Byte] = [
    pdf_crypt_low_byte(permissions, 0),
    pdf_crypt_low_byte(permissions, 8),
    pdf_crypt_low_byte(permissions, 16),
    pdf_crypt_low_byte(permissions, 24),
  ]
  md5.update(permissions_bytes)
  md5.update(file_id)
  if revision >= 4 && no_encrypt_metadata {
    let no_metadata_marker : FixedArray[Byte] = [0xff, 0xff, 0xff, 0xff]
    md5.update(no_metadata_marker)
  }
  let key_length = key_length_bits / 8
  let mut hashed = Bytes::from_array(md5.finalize())
  if revision >= 3 {
    for _ in 0..<50 {
      hashed = pdf_md5_digest(hashed[:key_length])
    }
  }
  hashed[:key_length].to_owned()
}

///|
fn pdf_key_xor_iteration(key : BytesView, iteration : Int) -> PdfBytes {
  Bytes::makei(key.length(), index => {
    (key[index].to_int() ^ iteration).to_byte()
  })
}

///|
pub fn pdf_make_user_password_entry(
  no_encrypt_metadata : Bool,
  user_password : BytesView,
  revision : Int,
  owner_entry : BytesView,
  permissions : Int,
  file_id : BytesView,
  key_length_bits : Int,
) -> PdfBytes raise PdfError {
  let key = pdf_encryption_file_key(
    no_encrypt_metadata, user_password, revision, owner_entry, permissions, file_id,
    key_length_bits,
  )
  if revision == 2 {
    pdf_arc4_crypt(key[:], pdf_password_padding()[:])
  } else {
    let md5 = @crypto.MD5::new()
    md5.update(pdf_password_padding()[:])
    md5.update(file_id)
    let digest = Bytes::from_array(md5.finalize())
    let mut encrypted = pdf_arc4_crypt(key[:], digest[:])
    for iteration in 1..<20 {
      let iteration_key = pdf_key_xor_iteration(key[:], iteration)
      encrypted = pdf_arc4_crypt(iteration_key[:], encrypted[:])
    }
    let output : Array[Byte] = [ for byte in encrypted => byte ]
    for _ in 0..<16 {
      output.push(0)
    }
    Bytes::from_array(output)
  }
}

///|
fn pdf_bytes_prefix_equal(
  left : BytesView,
  right : BytesView,
  length : Int,
) -> Bool {
  guard left.length() >= length && right.length() >= length else {
    return false
  }
  for index in 0..<length {
    if left[index] != right[index] {
      break false
    }
  } nobreak {
    true
  }
}

///|
pub fn pdf_authenticate_user_password(
  no_encrypt_metadata : Bool,
  user_password : BytesView,
  revision : Int,
  user_entry : BytesView,
  owner_entry : BytesView,
  permissions : Int,
  file_id : BytesView,
  key_length_bits : Int,
) -> Bool raise PdfError {
  let expected = pdf_make_user_password_entry(
    no_encrypt_metadata, user_password, revision, owner_entry, permissions, file_id,
    key_length_bits,
  )
  if revision >= 3 {
    pdf_bytes_prefix_equal(user_entry, expected[:], 16)
  } else {
    pdf_bytes_prefix_equal(user_entry, expected[:], expected.length()) &&
    user_entry.length() == expected.length()
  }
}

///|
fn pdf_owner_password_key(
  owner_password : BytesView,
  revision : Int,
  key_length_bits : Int,
) -> PdfBytes {
  let padded_owner = pdf_pad_password(owner_password)
  let mut digest = pdf_md5_digest(padded_owner[:])
  if revision >= 3 {
    for _ in 0..<50 {
      digest = pdf_md5_digest(digest[:])
    }
  }
  digest[:key_length_bits / 8].to_owned()
}

///|
pub fn pdf_make_owner_password_entry(
  revision : Int,
  owner_password : BytesView,
  user_password : BytesView,
  key_length_bits : Int,
) -> PdfBytes raise PdfError {
  let source_password = if owner_password.length() == 0 {
    user_password
  } else {
    owner_password
  }
  let key = pdf_owner_password_key(source_password, revision, key_length_bits)
  let padded_user = pdf_pad_password(user_password)
  if revision == 2 {
    pdf_arc4_crypt(key[:], padded_user[:])
  } else {
    let mut encrypted = pdf_arc4_crypt(key[:], padded_user[:])
    for iteration in 1..<20 {
      let iteration_key = pdf_key_xor_iteration(key[:], iteration)
      encrypted = pdf_arc4_crypt(iteration_key[:], encrypted[:])
    }
    encrypted
  }
}

///|
pub fn pdf_user_password_from_owner_password(
  revision : Int,
  owner_password : BytesView,
  owner_entry : BytesView,
  key_length_bits : Int,
) -> PdfBytes raise PdfError {
  let key = pdf_owner_password_key(owner_password, revision, key_length_bits)
  if revision == 2 {
    pdf_arc4_crypt(key[:], owner_entry)
  } else {
    let mut decrypted = owner_entry.to_owned()
    let mut iteration = 19
    while iteration >= 0 {
      let iteration_key = pdf_key_xor_iteration(key[:], iteration)
      decrypted = pdf_arc4_crypt(iteration_key[:], decrypted[:])
      iteration -= 1
    }
    decrypted
  }
}

///|
pub fn pdf_authenticate_owner_password(
  no_encrypt_metadata : Bool,
  owner_password : BytesView,
  revision : Int,
  user_entry : BytesView,
  owner_entry : BytesView,
  permissions : Int,
  file_id : BytesView,
  key_length_bits : Int,
) -> Bool raise PdfError {
  let user_password = pdf_user_password_from_owner_password(
    revision, owner_password, owner_entry, key_length_bits,
  )
  pdf_authenticate_user_password(
    no_encrypt_metadata,
    user_password[:],
    revision,
    user_entry,
    owner_entry,
    permissions,
    file_id,
    key_length_bits,
  )
}

///|
fn pdf_permission_denied(
  permissions : ArrayView[PdfPermission],
  target : PdfPermission,
) -> Bool {
  for permission in permissions {
    if permission == target {
      break true
    }
  } nobreak {
    false
  }
}

///|
fn pdf_permission_set_bit(mask : Int, bit : Int, value : Bool) -> Int {
  if value {
    mask | (1 << (bit - 1))
  } else {
    mask
  }
}

///|
pub fn pdf_p_of_permissions(permissions : ArrayView[PdfPermission]) -> Int {
  let mut mask = 0
  mask = pdf_permission_set_bit(
    mask,
    3,
    !pdf_permission_denied(permissions, PdfNoPrint),
  )
  mask = pdf_permission_set_bit(
    mask,
    4,
    !pdf_permission_denied(permissions, PdfNoEdit),
  )
  mask = pdf_permission_set_bit(
    mask,
    5,
    !pdf_permission_denied(permissions, PdfNoCopy),
  )
  mask = pdf_permission_set_bit(
    mask,
    6,
    !pdf_permission_denied(permissions, PdfNoAnnot),
  )
  mask = pdf_permission_set_bit(mask, 7, true)
  mask = pdf_permission_set_bit(mask, 8, true)
  mask = pdf_permission_set_bit(
    mask,
    9,
    !pdf_permission_denied(permissions, PdfNoForms),
  )
  mask = pdf_permission_set_bit(
    mask,
    10,
    !pdf_permission_denied(permissions, PdfNoExtract),
  )
  mask = pdf_permission_set_bit(
    mask,
    11,
    !pdf_permission_denied(permissions, PdfNoAssemble),
  )
  mask = pdf_permission_set_bit(
    mask,
    12,
    !pdf_permission_denied(permissions, PdfNoHqPrint),
  )
  for bit in 13..<=32 {
    mask = pdf_permission_set_bit(mask, bit, true)
  }
  mask
}

///|
fn pdf_permission_bit_denied(mask : Int, bit : Int) -> Bool {
  ((mask >> (bit - 1)) & 1) == 0
}

///|
pub fn pdf_permissions_of_p(mask : Int) -> Array[PdfPermission] {
  let permissions : Array[PdfPermission] = []
  if pdf_permission_bit_denied(mask, 12) {
    permissions.push(PdfNoHqPrint)
  }
  if pdf_permission_bit_denied(mask, 11) {
    permissions.push(PdfNoAssemble)
  }
  if pdf_permission_bit_denied(mask, 10) {
    permissions.push(PdfNoExtract)
  }
  if pdf_permission_bit_denied(mask, 9) {
    permissions.push(PdfNoForms)
  }
  if pdf_permission_bit_denied(mask, 6) {
    permissions.push(PdfNoAnnot)
  }
  if pdf_permission_bit_denied(mask, 5) {
    permissions.push(PdfNoCopy)
  }
  if pdf_permission_bit_denied(mask, 4) {
    permissions.push(PdfNoEdit)
  }
  if pdf_permission_bit_denied(mask, 3) {
    permissions.push(PdfNoPrint)
  }
  permissions
}
