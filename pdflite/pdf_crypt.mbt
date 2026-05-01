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
pub(all) struct PdfEncryptionValues {
  crypt_type : PdfCryptType
  user_entry : PdfBytes
  owner_entry : PdfBytes
  permissions : Int
  file_id : PdfBytes
  user_encryption_key : PdfBytes?
  owner_encryption_key : PdfBytes?
} derive(Debug, Eq, ToJson)

///|
pub(all) struct PdfDecryptionResult {
  document : PdfDocument
  denied_permissions : Array[PdfPermission]
} derive(Debug, Eq, ToJson)

///|
fn pdf_crypt_name(text : String) -> PdfName {
  pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn pdf_crypt_lookup_name(
  pdf : PdfDocument,
  key : PdfName,
  dictionary : PdfObject,
) -> PdfName? {
  match pdf.lookup_direct(key, dictionary) {
    Some(PdfNameObject(name)) => Some(name)
    _ => None
  }
}

///|
fn pdf_crypt_lookup_int(
  pdf : PdfDocument,
  key : PdfName,
  dictionary : PdfObject,
) -> Int? {
  match pdf.lookup_direct(key, dictionary) {
    Some(PdfInteger(value)) => Some(value)
    _ => None
  }
}

///|
fn pdf_crypt_lookup_string(
  pdf : PdfDocument,
  key : PdfName,
  dictionary : PdfObject,
) -> PdfBytes? {
  match pdf.lookup_direct(key, dictionary) {
    Some(PdfString(value)) => Some(value)
    _ => None
  }
}

///|
fn pdf_crypt_required_string(
  pdf : PdfDocument,
  key : PdfName,
  dictionary : PdfObject,
) -> PdfBytes raise PdfError {
  match pdf_crypt_lookup_string(pdf, key, dictionary) {
    Some(value) => value
    None => raise EncryptionDictionaryEntryExpected(key)
  }
}

///|
fn pdf_crypt_required_int(
  pdf : PdfDocument,
  key : PdfName,
  dictionary : PdfObject,
) -> Int raise PdfError {
  match pdf_crypt_lookup_int(pdf, key, dictionary) {
    Some(value) => value
    None => raise EncryptionDictionaryEntryExpected(key)
  }
}

///|
fn pdf_crypt_chop_string(
  key : PdfName,
  value : PdfBytes,
  need : Int,
) -> PdfBytes raise PdfError {
  if value.length() < need {
    raise EncryptionDictionaryEntryTooShort(key)
  }
  value[:need].to_owned()
}

///|
fn pdf_crypt_arc4_v4_length(
  pdf : PdfDocument,
  encrypt_dictionary : PdfObject,
  cf_dictionary : PdfObject,
) -> Int? {
  match
    pdf_crypt_lookup_int(pdf, pdf_crypt_name("/Length"), encrypt_dictionary) {
    Some(value) => Some(value)
    None => pdf_crypt_lookup_int(pdf, pdf_crypt_name("/Length"), cf_dictionary)
  }
}

///|
fn pdf_crypt_type_from_encrypt_dictionary(
  pdf : PdfDocument,
  encrypt_dictionary : PdfObject,
) -> PdfCryptType? {
  let standard = pdf_crypt_name("/Standard")
  let filter = pdf_crypt_lookup_name(
    pdf,
    pdf_crypt_name("/Filter"),
    encrypt_dictionary,
  )
  let version = pdf_crypt_lookup_int(
    pdf,
    pdf_crypt_name("/V"),
    encrypt_dictionary,
  )
  let length = pdf_crypt_lookup_int(
    pdf,
    pdf_crypt_name("/Length"),
    encrypt_dictionary,
  )
  let revision = pdf_crypt_lookup_int(
    pdf,
    pdf_crypt_name("/R"),
    encrypt_dictionary,
  )
  match (filter, version, length, revision) {
    (Some(name), Some(1), _, Some(revision)) if name == standard =>
      Some(PdfCryptARC4(40, revision))
    (Some(name), Some(2), None, Some(revision)) if name == standard =>
      Some(PdfCryptARC4(40, revision))
    (Some(name), Some(2), Some(length), _) if name == standard &&
      length % 8 == 0 &&
      length >= 40 &&
      length <= 128 => Some(PdfCryptARC4(length, 3))
    (Some(name), Some(version), _, Some(revision)) if name == standard &&
      (version == 4 || version == 5) =>
      match pdf.lookup_direct(pdf_crypt_name("/CF"), encrypt_dictionary) {
        Some(cf_dictionary) =>
          match pdf.lookup_direct(pdf_crypt_name("/StdCF"), cf_dictionary) {
            Some(std_cf_dictionary) =>
              match
                pdf_crypt_lookup_name(
                  pdf,
                  pdf_crypt_name("/CFM"),
                  std_cf_dictionary,
                ) {
                Some(cfm) if cfm == pdf_crypt_name("/V2") =>
                  match
                    pdf_crypt_arc4_v4_length(
                      pdf, encrypt_dictionary, cf_dictionary,
                    ) {
                    Some(length) => Some(PdfCryptARC4(length, 4))
                    None => None
                  }
                Some(cfm) if cfm == pdf_crypt_name("/AESV2") =>
                  Some(PdfCryptAESV2)
                Some(cfm) if cfm == pdf_crypt_name("/AESV3") =>
                  Some(PdfCryptAESV3(revision == 6))
                _ => None
              }
            None => None
          }
        None => None
      }
    _ => None
  }
}

///|
pub fn PdfDocument::encryption_values(
  self : PdfDocument,
) -> PdfEncryptionValues raise PdfError {
  let encrypt_key = pdf_crypt_name("/Encrypt")
  let encrypt_dictionary = match
    self.lookup_direct(encrypt_key, self.trailer_dict()) {
    Some(value) => value
    None => raise EncryptionExpected
  }
  let crypt_type = match
    pdf_crypt_type_from_encrypt_dictionary(self, encrypt_dictionary) {
    Some(value) => value
    None => raise EncryptionMethodExpected
  }
  let user_owner_length = match crypt_type {
    PdfCryptAESV3(_) => 48
    _ => 32
  }
  let owner_key = pdf_crypt_name("/O")
  let user_key = pdf_crypt_name("/U")
  let id_key = pdf_crypt_name("/ID")
  let owner_entry = pdf_crypt_chop_string(
    owner_key,
    pdf_crypt_required_string(self, owner_key, encrypt_dictionary),
    user_owner_length,
  )
  let user_entry = pdf_crypt_chop_string(
    user_key,
    pdf_crypt_required_string(self, user_key, encrypt_dictionary),
    user_owner_length,
  )
  let permissions = pdf_crypt_required_int(
    self,
    pdf_crypt_name("/P"),
    encrypt_dictionary,
  )
  let file_id = match self.lookup_direct(id_key, self.trailer_dict()) {
    Some(PdfArray([PdfString(file_id), _])) => file_id
    _ => raise EncryptionIDExpected
  }
  {
    crypt_type,
    user_entry,
    owner_entry,
    permissions,
    file_id,
    user_encryption_key: pdf_crypt_lookup_string(
      self,
      pdf_crypt_name("/UE"),
      encrypt_dictionary,
    ),
    owner_encryption_key: pdf_crypt_lookup_string(
      self,
      pdf_crypt_name("/OE"),
      encrypt_dictionary,
    ),
  }
}

///|
fn PdfEncryptionValues::password_settings(
  self : PdfEncryptionValues,
) -> (Int, Int) raise PdfError {
  match self.crypt_type {
    PdfCryptARC4(key_length_bits, revision) => (revision, key_length_bits)
    PdfCryptAESV2 => (4, 128)
    PdfCryptAESV3(_) =>
      raise EncryptionAuthenticationUnsupported(self.crypt_type)
  }
}

///|
pub fn PdfEncryptionValues::authenticate_user_password(
  self : PdfEncryptionValues,
  password : BytesView,
  no_encrypt_metadata? : Bool = false,
) -> Bool raise PdfError {
  match self.crypt_type {
    PdfCryptAESV3(iso) =>
      pdf_authenticate_user_password_aesv3(iso, password, self.user_entry[:])
    _ => {
      let (revision, key_length_bits) = self.password_settings()
      pdf_authenticate_user_password(
        no_encrypt_metadata,
        password,
        revision,
        self.user_entry[:],
        self.owner_entry[:],
        self.permissions,
        self.file_id[:],
        key_length_bits,
      )
    }
  }
}

///|
pub fn PdfEncryptionValues::file_key_for_user_password(
  self : PdfEncryptionValues,
  password : BytesView,
  no_encrypt_metadata? : Bool = false,
) -> PdfBytes? raise PdfError {
  match self.crypt_type {
    PdfCryptAESV3(iso) =>
      pdf_file_key_for_user_password_aesv3(
        iso,
        password,
        self.user_entry[:],
        self.user_encryption_key,
      )
    _ => {
      let (revision, key_length_bits) = self.password_settings()
      if pdf_authenticate_user_password(
          no_encrypt_metadata,
          password,
          revision,
          self.user_entry[:],
          self.owner_entry[:],
          self.permissions,
          self.file_id[:],
          key_length_bits,
        ) {
        Some(
          pdf_encryption_file_key(
            no_encrypt_metadata,
            password,
            revision,
            self.owner_entry[:],
            self.permissions,
            self.file_id[:],
            key_length_bits,
          ),
        )
      } else {
        None
      }
    }
  }
}

///|
pub fn PdfEncryptionValues::authenticate_owner_password(
  self : PdfEncryptionValues,
  password : BytesView,
  no_encrypt_metadata? : Bool = false,
) -> Bool raise PdfError {
  match self.crypt_type {
    PdfCryptAESV3(iso) =>
      pdf_authenticate_owner_password_aesv3(
        iso,
        password,
        self.user_entry[:],
        self.owner_entry[:],
      )
    _ => {
      let (revision, key_length_bits) = self.password_settings()
      pdf_authenticate_owner_password(
        no_encrypt_metadata,
        password,
        revision,
        self.user_entry[:],
        self.owner_entry[:],
        self.permissions,
        self.file_id[:],
        key_length_bits,
      )
    }
  }
}

///|
pub fn PdfEncryptionValues::file_key_for_owner_password(
  self : PdfEncryptionValues,
  password : BytesView,
  no_encrypt_metadata? : Bool = false,
) -> PdfBytes? raise PdfError {
  match self.crypt_type {
    PdfCryptAESV3(iso) =>
      pdf_file_key_for_owner_password_aesv3(
        iso,
        password,
        self.user_entry[:],
        self.owner_entry[:],
        self.owner_encryption_key,
      )
    _ => {
      let (revision, key_length_bits) = self.password_settings()
      let user_password = pdf_user_password_from_owner_password(
        revision,
        password,
        self.owner_entry[:],
        key_length_bits,
      )
      if pdf_authenticate_user_password(
          no_encrypt_metadata,
          user_password[:],
          revision,
          self.user_entry[:],
          self.owner_entry[:],
          self.permissions,
          self.file_id[:],
          key_length_bits,
        ) {
        Some(
          pdf_encryption_file_key(
            no_encrypt_metadata,
            user_password[:],
            revision,
            self.owner_entry[:],
            self.permissions,
            self.file_id[:],
            key_length_bits,
          ),
        )
      } else {
        None
      }
    }
  }
}

///|
fn PdfDocument::encryption_object_number(self : PdfDocument) -> Int {
  match self.trailer_dict().lookup_immediate(pdf_crypt_name("/Encrypt")) {
    Some(PdfIndirect(number)) => number
    _ => 0
  }
}

///|
fn PdfDocument::decrypt_with_file_key(
  self : PdfDocument,
  values : PdfEncryptionValues,
  file_key : PdfBytes,
  no_encrypt_metadata? : Bool = false,
) -> PdfDecryptionResult raise PdfError {
  match values.crypt_type {
    PdfCryptARC4(key_length_bits, _) => {
      let output = self.arc4_crypt_parsed_objects(
        file_key[:],
        key_length_bits,
        no_encrypt_metadata~,
        skip_object_number=self.encryption_object_number(),
      )
      output.set_trailer_dict(
        output.trailer_dict().remove_dict_entry(pdf_crypt_name("/Encrypt")),
      )
      {
        document: output,
        denied_permissions: pdf_permissions_of_p(values.permissions),
      }
    }
    PdfCryptAESV2 => {
      let output = self.aesv2_decrypt_parsed_objects(
        file_key[:],
        128,
        no_encrypt_metadata~,
        skip_object_number=self.encryption_object_number(),
      )
      output.set_trailer_dict(
        output.trailer_dict().remove_dict_entry(pdf_crypt_name("/Encrypt")),
      )
      {
        document: output,
        denied_permissions: pdf_permissions_of_p(values.permissions),
      }
    }
    PdfCryptAESV3(false) => {
      let output = self.aesv3_decrypt_parsed_objects(
        file_key[:],
        no_encrypt_metadata~,
        skip_object_number=self.encryption_object_number(),
      )
      output.set_trailer_dict(
        output.trailer_dict().remove_dict_entry(pdf_crypt_name("/Encrypt")),
      )
      {
        document: output,
        denied_permissions: pdf_permissions_of_p(values.permissions),
      }
    }
    PdfCryptAESV3(true) =>
      raise EncryptionObjectCryptUnsupported(values.crypt_type)
  }
}

///|
pub fn PdfDocument::decrypt_with_user_password(
  self : PdfDocument,
  password : BytesView,
  no_encrypt_metadata? : Bool = false,
) -> PdfDecryptionResult? raise PdfError {
  match self.trailer_dict().lookup_immediate(pdf_crypt_name("/Encrypt")) {
    None => Some({ document: self.copy(), denied_permissions: [] })
    Some(_) => {
      let values = self.encryption_values()
      let file_key = match
        values.file_key_for_user_password(password, no_encrypt_metadata~) {
        Some(key) => key
        None => return None
      }
      Some(self.decrypt_with_file_key(values, file_key, no_encrypt_metadata~))
    }
  }
}

///|
pub fn PdfDocument::decrypt_with_owner_password(
  self : PdfDocument,
  password : BytesView,
  no_encrypt_metadata? : Bool = false,
) -> PdfDecryptionResult? raise PdfError {
  match self.trailer_dict().lookup_immediate(pdf_crypt_name("/Encrypt")) {
    None => Some({ document: self.copy(), denied_permissions: [] })
    Some(_) => {
      let values = self.encryption_values()
      let file_key = match
        values.file_key_for_owner_password(password, no_encrypt_metadata~) {
        Some(key) => key
        None => return None
      }
      Some(self.decrypt_with_file_key(values, file_key, no_encrypt_metadata~))
    }
  }
}

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
fn pdf_crypt_concat_bytes(parts : ArrayView[BytesView]) -> PdfBytes {
  let output : Array[Byte] = []
  for part in parts {
    for byte in part {
      output.push(byte)
    }
  }
  Bytes::from_array(output)
}

///|
fn pdf_aesv3_password_hash(
  iso : Bool,
  password_data : BytesView,
) -> PdfBytes raise PdfError {
  if iso {
    raise EncryptionAuthenticationUnsupported(PdfCryptAESV3(iso))
  }
  pdf_sha256_digest(password_data)
}

///|
pub fn pdf_authenticate_user_password_aesv3(
  iso : Bool,
  password : BytesView,
  user_entry : BytesView,
) -> Bool raise PdfError {
  if user_entry.length() < 48 {
    raise EncryptionDictionaryEntryTooShort(pdf_crypt_name("/U"))
  }
  let input = pdf_crypt_concat_bytes([password, user_entry[32:40]])
  let expected = pdf_aesv3_password_hash(iso, input[:])
  pdf_bytes_prefix_equal(user_entry, expected[:], 32)
}

///|
pub fn pdf_authenticate_owner_password_aesv3(
  iso : Bool,
  password : BytesView,
  user_entry : BytesView,
  owner_entry : BytesView,
) -> Bool raise PdfError {
  if owner_entry.length() < 48 {
    raise EncryptionDictionaryEntryTooShort(pdf_crypt_name("/O"))
  }
  if user_entry.length() < 48 {
    raise EncryptionDictionaryEntryTooShort(pdf_crypt_name("/U"))
  }
  let input = pdf_crypt_concat_bytes([
    password,
    owner_entry[32:40],
    user_entry[:48],
  ])
  let expected = pdf_aesv3_password_hash(iso, input[:])
  pdf_bytes_prefix_equal(owner_entry, expected[:], 32)
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
  let data = pdf_crypt_concat_bytes([zero_iv[:], encrypted_key[:]])
  pdf_aes_cbc_decrypt(digest[:], data[:], remove_padding=false)
}

///|
fn pdf_file_key_for_user_password_aesv3(
  iso : Bool,
  password : BytesView,
  user_entry : BytesView,
  user_encryption_key : PdfBytes?,
) -> PdfBytes? raise PdfError {
  if pdf_authenticate_user_password_aesv3(iso, password, user_entry) {
    let input = pdf_crypt_concat_bytes([password, user_entry[40:48]])
    let digest = pdf_aesv3_password_hash(iso, input[:])
    let encrypted_key = pdf_aesv3_crypt_entry(
      pdf_crypt_name("/UE"),
      user_encryption_key,
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
    let input = pdf_crypt_concat_bytes([
      password,
      owner_entry[40:48],
      user_entry[:48],
    ])
    let digest = pdf_aesv3_password_hash(iso, input[:])
    let encrypted_key = pdf_aesv3_crypt_entry(
      pdf_crypt_name("/OE"),
      owner_encryption_key,
    )
    Some(pdf_aesv3_unwrap_file_key(digest, encrypted_key))
  } else {
    None
  }
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
fn pdf_crypt_stream_length_key() -> PdfName {
  pdf_name_of_bytes(@ascii.encode("/Length"))
}

///|
fn pdf_crypt_stream_filter_key() -> PdfName {
  pdf_crypt_name("/Filter")
}

///|
fn pdf_crypt_stream_decodeparms_key() -> PdfName {
  pdf_crypt_name("/DecodeParms")
}

///|
fn pdf_crypt_stream_name_key() -> PdfName {
  pdf_crypt_name("/Name")
}

///|
fn pdf_crypt_stream_type_key() -> PdfName {
  pdf_crypt_name("/Type")
}

///|
fn pdf_crypt_object_is_name(object : PdfObject?, text : String) -> Bool {
  match object {
    Some(PdfNameObject(name)) => name == pdf_crypt_name(text)
    _ => false
  }
}

///|
fn pdf_crypt_first_filter_is_crypt(dictionary : PdfObject) -> Bool {
  match dictionary.lookup_immediate(pdf_crypt_stream_filter_key()) {
    Some(PdfNameObject(name)) => name == pdf_crypt_name("/Crypt")
    Some(PdfArray([PdfNameObject(name), ..])) =>
      name == pdf_crypt_name("/Crypt")
    _ => false
  }
}

///|
fn pdf_crypt_decodeparms_is_identity(dictionary : PdfObject) -> Bool {
  match dictionary.lookup_immediate(pdf_crypt_stream_decodeparms_key()) {
    Some(PdfDictionary(_) as decodeparms)
    | Some(PdfArray([PdfDictionary(_) as decodeparms, ..])) =>
      match decodeparms.lookup_immediate(pdf_crypt_stream_name_key()) {
        Some(PdfNameObject(name)) => name == pdf_crypt_name("/Identity")
        None => true
        _ => false
      }
    _ => true
  }
}

///|
fn pdf_crypt_stream_is_identity(
  no_encrypt_metadata : Bool,
  dictionary : PdfObject,
) -> Bool {
  if no_encrypt_metadata &&
    pdf_crypt_object_is_name(
      dictionary.lookup_immediate(pdf_crypt_stream_type_key()),
      "/Metadata",
    ) {
    true
  } else {
    pdf_crypt_first_filter_is_crypt(dictionary) &&
    pdf_crypt_decodeparms_is_identity(dictionary)
  }
}

///|
pub fn pdf_arc4_crypt_pdf_object(
  object_number : Int,
  generation : Int,
  file_key : BytesView,
  key_length_bits : Int,
  object : PdfObject,
  no_encrypt_metadata? : Bool = false,
) -> PdfObject raise PdfError {
  match object {
    PdfString(bytes) =>
      PdfString(
        pdf_arc4_crypt_object(
          object_number,
          generation,
          file_key,
          key_length_bits,
          bytes[:],
        ),
      )
    PdfArray(values) => {
      let output : Array[PdfObject] = []
      for value in values {
        output.push(
          pdf_arc4_crypt_pdf_object(
            object_number,
            generation,
            file_key,
            key_length_bits,
            value,
            no_encrypt_metadata~,
          ),
        )
      }
      PdfArray(output)
    }
    PdfDictionary(entries) => {
      let output : Array[(PdfName, PdfObject)] = []
      for entry in entries {
        let (name, value) = entry
        output.push(
          (
            name,
            pdf_arc4_crypt_pdf_object(
              object_number,
              generation,
              file_key,
              key_length_bits,
              value,
              no_encrypt_metadata~,
            ),
          ),
        )
      }
      PdfDictionary(output)
    }
    PdfStreamObject(stream) =>
      if pdf_crypt_stream_is_identity(no_encrypt_metadata, stream.dictionary) {
        object
      } else {
        let dictionary = pdf_arc4_crypt_pdf_object(
          object_number,
          generation,
          file_key,
          key_length_bits,
          stream.dictionary,
          no_encrypt_metadata~,
        )
        let data = pdf_stream_data_bytes(stream.data)
        let encrypted_data = pdf_arc4_crypt_object(
          object_number,
          generation,
          file_key,
          key_length_bits,
          data[:],
        )
        PdfStreamObject({
          dictionary: dictionary.add_dict_entry(
            pdf_crypt_stream_length_key(),
            PdfInteger(encrypted_data.length()),
          ),
          data: StreamGot(encrypted_data),
        })
      }
    _ => object
  }
}

///|
pub fn pdf_aesv2_decrypt_object_data(
  object_number : Int,
  generation : Int,
  file_key : BytesView,
  key_length_bits : Int,
  data : BytesView,
) -> PdfBytes raise PdfError {
  let object_key = pdf_encryption_object_key(
    PdfCryptAESV2,
    object_number,
    generation,
    file_key,
    key_length_bits,
  )
  pdf_aes_cbc_decrypt(object_key[:], data)
}

///|
fn pdf_aes_decrypt_pdf_object_with_key(
  key : BytesView,
  object : PdfObject,
  no_encrypt_metadata? : Bool = false,
) -> PdfObject raise PdfError {
  match object {
    PdfString(bytes) => PdfString(pdf_aes_cbc_decrypt(key, bytes[:]))
    PdfArray(values) => {
      let output : Array[PdfObject] = []
      for value in values {
        output.push(
          pdf_aes_decrypt_pdf_object_with_key(key, value, no_encrypt_metadata~),
        )
      }
      PdfArray(output)
    }
    PdfDictionary(entries) => {
      let output : Array[(PdfName, PdfObject)] = []
      for entry in entries {
        let (name, value) = entry
        output.push(
          (
            name,
            pdf_aes_decrypt_pdf_object_with_key(
              key,
              value,
              no_encrypt_metadata~,
            ),
          ),
        )
      }
      PdfDictionary(output)
    }
    PdfStreamObject(stream) =>
      if pdf_crypt_stream_is_identity(no_encrypt_metadata, stream.dictionary) {
        object
      } else {
        let dictionary = pdf_aes_decrypt_pdf_object_with_key(
          key,
          stream.dictionary,
          no_encrypt_metadata~,
        )
        let data = pdf_stream_data_bytes(stream.data)
        let decrypted_data = pdf_aes_cbc_decrypt(key, data[:])
        PdfStreamObject({
          dictionary: dictionary.add_dict_entry(
            pdf_crypt_stream_length_key(),
            PdfInteger(decrypted_data.length()),
          ),
          data: StreamGot(decrypted_data),
        })
      }
    _ => object
  }
}

///|
pub fn pdf_aesv2_decrypt_pdf_object(
  object_number : Int,
  generation : Int,
  file_key : BytesView,
  key_length_bits : Int,
  object : PdfObject,
  no_encrypt_metadata? : Bool = false,
) -> PdfObject raise PdfError {
  let object_key = pdf_encryption_object_key(
    PdfCryptAESV2,
    object_number,
    generation,
    file_key,
    key_length_bits,
  )
  pdf_aes_decrypt_pdf_object_with_key(
    object_key[:],
    object,
    no_encrypt_metadata~,
  )
}

///|
pub fn pdf_aesv3_decrypt_pdf_object(
  file_key : BytesView,
  object : PdfObject,
  no_encrypt_metadata? : Bool = false,
) -> PdfObject raise PdfError {
  pdf_aes_decrypt_pdf_object_with_key(file_key, object, no_encrypt_metadata~)
}

///|
pub fn PdfDocument::arc4_crypt_parsed_objects(
  self : PdfDocument,
  file_key : BytesView,
  key_length_bits : Int,
  no_encrypt_metadata? : Bool = false,
  skip_object_number? : Int = 0,
) -> PdfDocument raise PdfError {
  let output = self.copy()
  for number in output.object_numbers() {
    if number != skip_object_number {
      let entry = output.objects.get_entry(number).unwrap()
      match entry.data {
        ObjectParsed(object) =>
          output.objects.set_entry(number, {
            data: ObjectParsed(
              pdf_arc4_crypt_pdf_object(
                number,
                entry.generation,
                file_key,
                key_length_bits,
                object,
                no_encrypt_metadata~,
              ),
            ),
            generation: entry.generation,
          })
        ObjectParsedAlreadyDecrypted(_)
        | ObjectToParse
        | ObjectToParseFromObjectStream(_) => ()
      }
    }
  }
  output
}

///|
pub fn PdfDocument::aesv2_decrypt_parsed_objects(
  self : PdfDocument,
  file_key : BytesView,
  key_length_bits : Int,
  no_encrypt_metadata? : Bool = false,
  skip_object_number? : Int = 0,
) -> PdfDocument raise PdfError {
  let output = self.copy()
  for number in output.object_numbers() {
    if number != skip_object_number {
      let entry = output.objects.get_entry(number).unwrap()
      match entry.data {
        ObjectParsed(object) =>
          output.objects.set_entry(number, {
            data: ObjectParsed(
              pdf_aesv2_decrypt_pdf_object(
                number,
                entry.generation,
                file_key,
                key_length_bits,
                object,
                no_encrypt_metadata~,
              ),
            ),
            generation: entry.generation,
          })
        ObjectParsedAlreadyDecrypted(_)
        | ObjectToParse
        | ObjectToParseFromObjectStream(_) => ()
      }
    }
  }
  output
}

///|
pub fn PdfDocument::aesv3_decrypt_parsed_objects(
  self : PdfDocument,
  file_key : BytesView,
  no_encrypt_metadata? : Bool = false,
  skip_object_number? : Int = 0,
) -> PdfDocument raise PdfError {
  let output = self.copy()
  for number in output.object_numbers() {
    if number != skip_object_number {
      let entry = output.objects.get_entry(number).unwrap()
      match entry.data {
        ObjectParsed(object) =>
          output.objects.set_entry(number, {
            data: ObjectParsed(
              pdf_aesv3_decrypt_pdf_object(
                file_key,
                object,
                no_encrypt_metadata~,
              ),
            ),
            generation: entry.generation,
          })
        ObjectParsedAlreadyDecrypted(_)
        | ObjectToParse
        | ObjectToParseFromObjectStream(_) => ()
      }
    }
  }
  output
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
