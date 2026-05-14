///|
/// Encryption method detected from or requested for a document.
///
/// AES entries carry the effective `EncryptMetadata` flag. The
/// `PdfEncryptionAlreadyEncrypted` value is used by writer paths that preserve
/// existing encrypted object data rather than decrypting and re-encrypting it.
pub(all) enum PdfEncryptionMethod {
  PdfEncryption40Bit
  PdfEncryption128Bit
  PdfEncryptionAES128(Bool)
  PdfEncryptionAES256(Bool)
  PdfEncryptionAES256ISO(Bool)
  PdfEncryptionAlreadyEncrypted
} derive(Debug, Eq, ToJson)

///|
/// Random material requested while constructing PDF 2.0 AESV3 encryption data.
///
/// Provider callbacks receive this field tag and a byte length, allowing tests
/// and reproducible builds to supply deterministic file keys, salts, and
/// permissions padding.
pub(all) enum PdfAesV3RandomField {
  PdfAesV3FileKey
  PdfAesV3UserValidationSalt
  PdfAesV3UserKeySalt
  PdfAesV3OwnerValidationSalt
  PdfAesV3OwnerKeySalt
  PdfAesV3PermissionsPadding
} derive(Debug, Eq, ToJson)

///|
/// Parsed standard-security-handler values from an encryption dictionary.
///
/// Password entries, permission masks, file IDs, and optional AESV3 wrapping
/// entries are stored as PDF bytes. `crypt_type` describes the actual object
/// encryption algorithm used for strings and streams.
pub(all) struct PdfEncryptionValues {
  crypt_type : PdfCryptType
  user_entry : PdfBytes
  owner_entry : PdfBytes
  permissions : Int
  file_id : PdfBytes
  encrypt_metadata : Bool
  permissions_entry : PdfBytes?
  user_encryption_key : PdfBytes?
  owner_encryption_key : PdfBytes?
} derive(Debug, Eq, ToJson)

///|
/// Saved encryption state retained on a decrypted document.
///
/// Recrypt helpers use this to put a previously encrypted document back into
/// its original security-handler shape after edits.
pub(all) struct PdfSavedEncryption {
  values : PdfEncryptionValues
} derive(Debug, Eq, ToJson)

///|
/// Result of successfully decrypting a document.
///
/// `document` is a decrypted copy with encryption removed from the trailer and
/// saved encryption state attached. `denied_permissions` is decoded from the
/// original `/P` permission mask.
pub(all) struct PdfDecryptionResult {
  document : PdfDocument
  denied_permissions : Array[PdfPermission]
} derive(Debug, Eq, ToJson)

///|
fn pdf_crypt_name(text : String) -> PdfName {
  pdf_name_of_bytes(@ascii.encode(text))
}

///|
let pdf_crypt_length_name : PdfName = pdf_crypt_name("/Length")

///|
let pdf_crypt_encrypt_name : PdfName = pdf_crypt_name("/Encrypt")

///|
let pdf_crypt_u_name : PdfName = pdf_crypt_name("/U")

///|
let pdf_crypt_o_name : PdfName = pdf_crypt_name("/O")

///|
let pdf_crypt_filter_name : PdfName = pdf_crypt_name("/Filter")

///|
let pdf_crypt_v_name : PdfName = pdf_crypt_name("/V")

///|
let pdf_crypt_standard_name : PdfName = pdf_crypt_name("/Standard")

///|
let pdf_crypt_r_name : PdfName = pdf_crypt_name("/R")

///|
let pdf_crypt_p_name : PdfName = pdf_crypt_name("/P")

///|
let pdf_crypt_std_cf_name : PdfName = pdf_crypt_name("/StdCF")

///|
let pdf_crypt_encrypt_metadata_name : PdfName = pdf_crypt_name(
  "/EncryptMetadata",
)

///|
let pdf_crypt_cfm_name : PdfName = pdf_crypt_name("/CFM")

///|
let pdf_crypt_cf_name : PdfName = pdf_crypt_name("/CF")

///|
let pdf_crypt_strf_name : PdfName = pdf_crypt_name("/StrF")

///|
let pdf_crypt_stmf_name : PdfName = pdf_crypt_name("/StmF")

///|
let pdf_crypt_doc_open_name : PdfName = pdf_crypt_name("/DocOpen")

///|
let pdf_crypt_auth_event_name : PdfName = pdf_crypt_name("/AuthEvent")

///|
let pdf_crypt_ue_name : PdfName = pdf_crypt_name("/UE")

///|
let pdf_crypt_oe_name : PdfName = pdf_crypt_name("/OE")

///|
let pdf_crypt_v2_name : PdfName = pdf_crypt_name("/V2")

///|
let pdf_crypt_id_name : PdfName = pdf_crypt_name("/ID")

///|
let pdf_crypt_aesv2_name : PdfName = pdf_crypt_name("/AESV2")

///|
let pdf_crypt_perms_name : PdfName = pdf_crypt_name("/Perms")

///|
let pdf_crypt_crypt_name : PdfName = pdf_crypt_name("/Crypt")

///|
let pdf_crypt_aesv3_name : PdfName = pdf_crypt_name("/AESV3")

///|
let pdf_crypt_user_validation_salt_name : PdfName = pdf_crypt_name(
  "/UserValidationSalt",
)

///|
let pdf_crypt_user_key_salt_name : PdfName = pdf_crypt_name("/UserKeySalt")

///|
let pdf_crypt_type_name : PdfName = pdf_crypt_name("/Type")

///|
let pdf_crypt_metadata_name : PdfName = pdf_crypt_name("/Metadata")

///|
let pdf_crypt_perms_padding_name : PdfName = pdf_crypt_name("/PermsPadding")

///|
let pdf_crypt_owner_validation_salt_name : PdfName = pdf_crypt_name(
  "/OwnerValidationSalt",
)

///|
let pdf_crypt_owner_key_salt_name : PdfName = pdf_crypt_name("/OwnerKeySalt")

///|
let pdf_crypt_name_key_name : PdfName = pdf_crypt_name("/Name")

///|
let pdf_crypt_identity_name : PdfName = pdf_crypt_name("/Identity")

///|
let pdf_crypt_iv_name : PdfName = pdf_crypt_name("/IV")

///|
let pdf_crypt_file_key_name : PdfName = pdf_crypt_name("/FileKey")

///|
let pdf_crypt_decodeparms_name : PdfName = pdf_crypt_name("/DecodeParms")

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
  pdf_crypt_chop_view(key, value, need)
}

///|
fn pdf_crypt_chop_view(
  key : PdfName,
  value : BytesView,
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
  match pdf_crypt_lookup_int(pdf, pdf_crypt_length_name, encrypt_dictionary) {
    Some(value) => Some(value)
    None => pdf_crypt_lookup_int(pdf, pdf_crypt_length_name, cf_dictionary)
  }
}

///|
fn pdf_crypt_type_from_encrypt_dictionary(
  pdf : PdfDocument,
  encrypt_dictionary : PdfObject,
) -> PdfCryptType? {
  let standard = pdf_crypt_standard_name
  let filter = pdf_crypt_lookup_name(
    pdf, pdf_crypt_filter_name, encrypt_dictionary,
  )
  let version = pdf_crypt_lookup_int(pdf, pdf_crypt_v_name, encrypt_dictionary)
  let length = pdf_crypt_lookup_int(
    pdf, pdf_crypt_length_name, encrypt_dictionary,
  )
  let revision = pdf_crypt_lookup_int(pdf, pdf_crypt_r_name, encrypt_dictionary)
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
      match pdf.lookup_direct(pdf_crypt_cf_name, encrypt_dictionary) {
        Some(cf_dictionary) =>
          match pdf.lookup_direct(pdf_crypt_std_cf_name, cf_dictionary) {
            Some(std_cf_dictionary) =>
              match
                pdf_crypt_lookup_name(
                  pdf, pdf_crypt_cfm_name, std_cf_dictionary,
                ) {
                Some(cfm) if cfm == pdf_crypt_v2_name =>
                  match
                    pdf_crypt_arc4_v4_length(
                      pdf, encrypt_dictionary, cf_dictionary,
                    ) {
                    Some(length) => Some(PdfCryptARC4(length, 4))
                    None => None
                  }
                Some(cfm) if cfm == pdf_crypt_aesv2_name => Some(PdfCryptAESV2)
                Some(cfm) if cfm == pdf_crypt_aesv3_name =>
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
/// Parse the document trailer's `/Encrypt` dictionary.
///
/// The returned value contains the normalized security-handler parameters
/// needed for authentication and object crypt. Missing encryption dictionaries,
/// unsupported handlers, malformed `/O` or `/U` entries, and missing trailer
/// `/ID` values raise `PdfError`.
pub fn PdfDocument::encryption_values(
  self : PdfDocument,
) -> PdfEncryptionValues raise PdfError {
  let encrypt_key = pdf_crypt_encrypt_name
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
  let owner_key = pdf_crypt_o_name
  let user_key = pdf_crypt_u_name
  let id_key = pdf_crypt_id_name
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
    self, pdf_crypt_p_name, encrypt_dictionary,
  )
  let file_id = match self.lookup_direct(id_key, self.trailer_dict()) {
    Some(PdfArray([PdfString(file_id), _])) => file_id
    _ => raise EncryptionIDExpected
  }
  let encrypt_metadata = match
    self.lookup_direct(pdf_crypt_encrypt_metadata_name, encrypt_dictionary) {
    Some(PdfBoolean(false)) => false
    _ => true
  }
  {
    crypt_type,
    user_entry,
    owner_entry,
    permissions,
    file_id,
    encrypt_metadata,
    permissions_entry: pdf_crypt_lookup_string(
      self, pdf_crypt_perms_name, encrypt_dictionary,
    ),
    user_encryption_key: pdf_crypt_lookup_string(
      self, pdf_crypt_ue_name, encrypt_dictionary,
    ),
    owner_encryption_key: pdf_crypt_lookup_string(
      self, pdf_crypt_oe_name, encrypt_dictionary,
    ),
  }
}

///|
/// Return true when the trailer contains an `/Encrypt` entry.
pub fn PdfDocument::is_encrypted(self : PdfDocument) -> Bool {
  self.lookup_direct(pdf_crypt_encrypt_name, self.trailer_dict()) != None
}

///|
/// Return the document encryption method, or `None` for unencrypted documents.
///
/// Unknown or unsupported encryption dictionaries may also return `None` after
/// the dictionary has been parsed.
pub fn PdfDocument::what_encryption(
  self : PdfDocument,
) -> PdfEncryptionMethod? raise PdfError {
  if self.is_encrypted() {
    let values = self.encryption_values()
    match values.crypt_type {
      PdfCryptARC4(40, _) => Some(PdfEncryption40Bit)
      PdfCryptARC4(128, _) => Some(PdfEncryption128Bit)
      PdfCryptAESV2 => Some(PdfEncryptionAES128(values.encrypt_metadata))
      PdfCryptAESV3(false) => Some(PdfEncryptionAES256(values.encrypt_metadata))
      PdfCryptAESV3(true) =>
        Some(PdfEncryptionAES256ISO(values.encrypt_metadata))
      _ => None
    }
  } else {
    None
  }
}

///|
/// Decode the denied permissions from the document encryption dictionary.
///
/// Unencrypted documents return an empty array. Encrypted documents parse
/// `/Encrypt` and may raise if the encryption dictionary is malformed.
pub fn PdfDocument::permissions(
  self : PdfDocument,
) -> Array[PdfPermission] raise PdfError {
  if self.is_encrypted() {
    pdf_permissions_of_p(self.encryption_values().permissions)
  } else {
    []
  }
}

///|
fn PdfEncryptionValues::effective_no_encrypt_metadata(
  self : PdfEncryptionValues,
  no_encrypt_metadata : Bool,
) -> Bool {
  no_encrypt_metadata || !self.encrypt_metadata
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
/// Authenticate a user password against parsed encryption values.
///
/// `password` is the raw PDF password byte sequence. AESV3 and earlier
/// revisions use their respective standard-security algorithms. The optional
/// metadata flag can force the revision-4 no-metadata key derivation path.
pub fn PdfEncryptionValues::authenticate_user_password(
  self : PdfEncryptionValues,
  password : BytesView,
  no_encrypt_metadata? : Bool = false,
) -> Bool raise PdfError {
  let no_encrypt_metadata = self.effective_no_encrypt_metadata(
    no_encrypt_metadata,
  )
  match self.crypt_type {
    PdfCryptAESV3(iso) =>
      pdf_authenticate_user_password_aesv3(iso, password, self.user_entry)
    _ => {
      let (revision, key_length_bits) = self.password_settings()
      pdf_authenticate_user_password(
        no_encrypt_metadata,
        password,
        revision,
        self.user_entry,
        self.owner_entry,
        self.permissions,
        self.file_id,
        key_length_bits,
      )
    }
  }
}

///|
/// Return the file key for a valid user password.
///
/// A wrong password returns `None`; malformed encryption values or corrupt
/// AESV3 permission entries raise `PdfError`.
pub fn PdfEncryptionValues::file_key_for_user_password(
  self : PdfEncryptionValues,
  password : BytesView,
  no_encrypt_metadata? : Bool = false,
) -> PdfBytes? raise PdfError {
  let no_encrypt_metadata = self.effective_no_encrypt_metadata(
    no_encrypt_metadata,
  )
  match self.crypt_type {
    PdfCryptAESV3(iso) =>
      match
        pdf_file_key_for_user_password_aesv3(
          iso,
          password,
          self.user_entry,
          self.user_encryption_key,
        ) {
        Some(key) => {
          self.validate_aesv3_permissions(key)
          Some(key)
        }
        None => None
      }
    _ => {
      let (revision, key_length_bits) = self.password_settings()
      if pdf_authenticate_user_password(
          no_encrypt_metadata,
          password,
          revision,
          self.user_entry,
          self.owner_entry,
          self.permissions,
          self.file_id,
          key_length_bits,
        ) {
        Some(
          pdf_encryption_file_key(
            no_encrypt_metadata,
            password,
            revision,
            self.owner_entry,
            self.permissions,
            self.file_id,
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
/// Authenticate an owner password against parsed encryption values.
///
/// For pre-AESV3 handlers this first recovers the padded user password from
/// the owner entry, then authenticates it as a user password.
pub fn PdfEncryptionValues::authenticate_owner_password(
  self : PdfEncryptionValues,
  password : BytesView,
  no_encrypt_metadata? : Bool = false,
) -> Bool raise PdfError {
  let no_encrypt_metadata = self.effective_no_encrypt_metadata(
    no_encrypt_metadata,
  )
  match self.crypt_type {
    PdfCryptAESV3(iso) =>
      pdf_authenticate_owner_password_aesv3(
        iso,
        password,
        self.user_entry,
        self.owner_entry,
      )
    _ => {
      let (revision, key_length_bits) = self.password_settings()
      pdf_authenticate_owner_password(
        no_encrypt_metadata,
        password,
        revision,
        self.user_entry,
        self.owner_entry,
        self.permissions,
        self.file_id,
        key_length_bits,
      )
    }
  }
}

///|
/// Return the file key for a valid owner password.
///
/// A wrong password returns `None`; malformed encryption values or corrupt
/// AESV3 permission entries raise `PdfError`.
pub fn PdfEncryptionValues::file_key_for_owner_password(
  self : PdfEncryptionValues,
  password : BytesView,
  no_encrypt_metadata? : Bool = false,
) -> PdfBytes? raise PdfError {
  let no_encrypt_metadata = self.effective_no_encrypt_metadata(
    no_encrypt_metadata,
  )
  match self.crypt_type {
    PdfCryptAESV3(iso) =>
      match
        pdf_file_key_for_owner_password_aesv3(
          iso,
          password,
          self.user_entry,
          self.owner_entry,
          self.owner_encryption_key,
        ) {
        Some(key) => {
          self.validate_aesv3_permissions(key)
          Some(key)
        }
        None => None
      }
    _ => {
      let (revision, key_length_bits) = self.password_settings()
      let user_password = pdf_user_password_from_owner_password(
        revision,
        password,
        self.owner_entry,
        key_length_bits,
      )
      if pdf_authenticate_user_password(
          no_encrypt_metadata,
          user_password,
          revision,
          self.user_entry,
          self.owner_entry,
          self.permissions,
          self.file_id,
          key_length_bits,
        ) {
        Some(
          pdf_encryption_file_key(
            no_encrypt_metadata,
            user_password,
            revision,
            self.owner_entry,
            self.permissions,
            self.file_id,
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
  match self.trailer_dict().lookup_immediate(pdf_crypt_encrypt_name) {
    Some(PdfIndirect(number)) => number
    _ => 0
  }
}

///|
fn pdf_crypt_file_id_object(file_id : BytesView) -> PdfObject {
  let owned = file_id.to_owned()
  PdfArray([PdfString(owned), PdfString(owned)])
}

///|
fn PdfDocument::with_file_id(
  self : PdfDocument,
  file_id? : BytesView = [],
) -> (PdfDocument, PdfBytes) raise PdfError {
  match self.lookup_direct(pdf_crypt_id_name, self.trailer_dict()) {
    Some(PdfArray([PdfString(existing), _])) => (self.copy(), existing)
    _ => {
      let id = if file_id.length() > 0 {
        file_id.to_owned()
      } else {
        pdf_generate_current_id_bytes("")
      }
      let output = self.copy()
      output.set_trailer_dict(
        output
        .trailer_dict()
        .add_dict_entry(pdf_crypt_id_name, pdf_crypt_file_id_object(id)),
      )
      (output, id)
    }
  }
}

///|
fn pdf_crypt_deterministic_seed32(
  seed : BytesView,
  purpose : BytesView,
) -> PdfBytes {
  pdf_sha256_digest(
    pdf_crypt_concat_bytes([
      @ascii.encode("pdflite-deterministic-aes-provider"),
      seed,
      purpose,
    ]),
  )
}

///|
fn pdf_crypt_deterministic_bytes(
  seed : BytesView,
  purpose : BytesView,
  length : Int,
) -> PdfBytes {
  if length <= 0 {
    Bytes::new(0)
  } else {
    let rand = @random.Rand::chacha8(
      seed=pdf_crypt_deterministic_seed32(seed, purpose),
    )
    Bytes::makei(length, _ => rand.uint(limit=256U).to_byte())
  }
}

///|
#warnings("-unused_error_type")
fn pdf_deterministic_aes_iv_for_seed(
  seed : BytesView,
  object_number : Int,
  generation : Int,
  index : Int,
) -> PdfBytes raise PdfError {
  let purpose = @ascii.encode(
    "aes-iv:" +
    object_number.to_string() +
    ":" +
    generation.to_string() +
    ":" +
    index.to_string(),
  )
  pdf_crypt_deterministic_bytes(seed, purpose, 16)
}

///|
/// Build a deterministic AES IV provider from a seed.
///
/// The returned callback derives 16-byte IVs from the seed, object number,
/// generation, and per-object IV index. It is intended for reproducible tests
/// and fixtures; production encryption should use a cryptographically secure
/// random provider.
pub fn pdf_deterministic_aes_iv_provider_from_seed(
  seed : BytesView,
) -> (Int, Int, Int) -> PdfBytes raise PdfError {
  let owned_seed = seed.to_owned()
  fn(object_number, generation, index) raise PdfError {
    pdf_deterministic_aes_iv_for_seed(
      owned_seed, object_number, generation, index,
    )
  }
}

///|
#warnings("-unused_error_type")
fn pdf_deterministic_aesv3_random_for_seed(
  seed : BytesView,
  field : PdfAesV3RandomField,
  length : Int,
) -> PdfBytes raise PdfError {
  pdf_crypt_deterministic_bytes(
    seed,
    pdf_aesv3_random_field_key(field).view(),
    length,
  )
}

///|
/// Build a deterministic AESV3 random-field provider from a seed.
///
/// The provider derives field-specific bytes for file keys, salts, and
/// permissions padding. It is useful for stable test fixtures, not for
/// production encryption.
pub fn pdf_deterministic_aesv3_random_provider_from_seed(
  seed : BytesView,
) -> (PdfAesV3RandomField, Int) -> PdfBytes raise PdfError {
  let owned_seed = seed.to_owned()
  fn(field, length) raise PdfError {
    pdf_deterministic_aesv3_random_for_seed(owned_seed, field, length)
  }
}

///|
fn PdfDocument::finish_decrypted_copy(
  self : PdfDocument,
  values : PdfEncryptionValues,
) -> Unit raise PdfError {
  self.set_trailer_dict(
    self.trailer_dict().remove_dict_entry(pdf_crypt_encrypt_name),
  )
  self.set_saved_encryption(Some({ values, }))
}

///|
fn PdfDocument::decrypt_with_file_key(
  self : PdfDocument,
  values : PdfEncryptionValues,
  file_key : PdfBytes,
  no_encrypt_metadata? : Bool = false,
) -> PdfDecryptionResult raise PdfError {
  let no_encrypt_metadata = values.effective_no_encrypt_metadata(
    no_encrypt_metadata,
  )
  match values.crypt_type {
    PdfCryptARC4(key_length_bits, _) => {
      let output = self.arc4_crypt_parsed_objects(
        file_key,
        key_length_bits,
        no_encrypt_metadata~,
        skip_object_number=self.encryption_object_number(),
      )
      output.finish_decrypted_copy(values)
      {
        document: output,
        denied_permissions: pdf_permissions_of_p(values.permissions),
      }
    }
    PdfCryptAESV2 => {
      let output = self.aesv2_decrypt_parsed_objects(
        file_key,
        128,
        no_encrypt_metadata~,
        skip_object_number=self.encryption_object_number(),
      )
      output.finish_decrypted_copy(values)
      {
        document: output,
        denied_permissions: pdf_permissions_of_p(values.permissions),
      }
    }
    PdfCryptAESV3(_) => {
      let output = self.aesv3_decrypt_parsed_objects(
        file_key,
        no_encrypt_metadata~,
        skip_object_number=self.encryption_object_number(),
      )
      output.finish_decrypted_copy(values)
      {
        document: output,
        denied_permissions: pdf_permissions_of_p(values.permissions),
      }
    }
  }
}

///|
fn PdfEncryptionValues::file_key_for_available_password(
  self : PdfEncryptionValues,
  user_password : BytesView?,
  owner_password : BytesView?,
  no_encrypt_metadata? : Bool = false,
) -> PdfBytes? raise PdfError {
  match user_password {
    Some(password) =>
      match self.file_key_for_user_password(password, no_encrypt_metadata~) {
        Some(key) => return Some(key)
        None =>
          match owner_password {
            Some(password) =>
              self.file_key_for_owner_password(password, no_encrypt_metadata~)
            None => None
          }
      }
    None =>
      match owner_password {
        Some(password) =>
          self.file_key_for_owner_password(password, no_encrypt_metadata~)
        None => self.file_key_for_user_password([], no_encrypt_metadata~)
      }
  }
}

///|
fn PdfEncryptionValues::decrypt_single_stream_with_file_key(
  self : PdfEncryptionValues,
  object_number : Int,
  generation : Int,
  stream : PdfObject,
  file_key : BytesView,
  no_encrypt_metadata? : Bool = false,
) -> PdfObject raise PdfError {
  let no_encrypt_metadata = self.effective_no_encrypt_metadata(
    no_encrypt_metadata,
  )
  match self.crypt_type {
    PdfCryptARC4(key_length_bits, _) =>
      pdf_arc4_crypt_pdf_object(
        object_number,
        generation,
        file_key,
        key_length_bits,
        stream,
        no_encrypt_metadata~,
      )
    PdfCryptAESV2 =>
      pdf_aesv2_decrypt_pdf_object(
        object_number,
        generation,
        file_key,
        128,
        stream,
        no_encrypt_metadata~,
      )
    PdfCryptAESV3(_) =>
      pdf_aesv3_decrypt_pdf_object(file_key, stream, no_encrypt_metadata~)
  }
}

///|
/// Decrypt one encrypted stream object with available passwords.
///
/// Unencrypted documents return `stream` unchanged. Encrypted documents return
/// `None` when no supplied password authenticates. The caller supplies the
/// stream object's number and generation because object keys depend on them.
pub fn PdfDocument::decrypt_single_stream(
  self : PdfDocument,
  object_number : Int,
  generation : Int,
  stream : PdfObject,
  user_password? : BytesView? = None,
  owner_password? : BytesView? = None,
  no_encrypt_metadata? : Bool = false,
) -> PdfObject? raise PdfError {
  if !self.is_encrypted() {
    Some(stream)
  } else {
    let values = self.encryption_values()
    match
      values.file_key_for_available_password(
        user_password,
        owner_password,
        no_encrypt_metadata~,
      ) {
      Some(file_key) =>
        Some(
          values.decrypt_single_stream_with_file_key(
            object_number,
            generation,
            stream,
            file_key,
            no_encrypt_metadata~,
          ),
        )
      None => None
    }
  }
}

///|
/// Decrypt this document using optional user and owner passwords.
///
/// If the document is not encrypted, a copied document and empty permissions
/// list are returned. If it is encrypted and no password works, the result is
/// `None`; malformed encryption data still raises `PdfError`.
pub fn PdfDocument::decrypt_with_passwords(
  self : PdfDocument,
  user_password? : BytesView? = None,
  owner_password? : BytesView? = None,
  no_encrypt_metadata? : Bool = false,
) -> PdfDecryptionResult? raise PdfError {
  if !self.is_encrypted() {
    Some({ document: self.copy(), denied_permissions: [] })
  } else {
    let values = self.encryption_values()
    match
      values.file_key_for_available_password(
        user_password,
        owner_password,
        no_encrypt_metadata~,
      ) {
      Some(file_key) =>
        Some(self.decrypt_with_file_key(values, file_key, no_encrypt_metadata~))
      None => None
    }
  }
}

///|
/// Encrypt a copy of the document with the revision-2 40-bit ARC4 handler.
///
/// `denied_permissions` is converted to the PDF `/P` mask. `file_id` can be
/// supplied for deterministic output; when omitted, the document gets a
/// CamlPDF-style generated file ID.
pub fn PdfDocument::encrypt_40bit(
  self : PdfDocument,
  user_password : BytesView,
  owner_password : BytesView,
  denied_permissions : ArrayView[PdfPermission],
  file_id? : BytesView = [],
) -> PdfDocument raise PdfError {
  self.encrypt_arc4_standard(
    user_password,
    owner_password,
    denied_permissions,
    1,
    2,
    40,
    false,
    file_id~,
  )
}

///|
/// Encrypt a copy of the document with the revision-3 128-bit ARC4 handler.
///
/// `denied_permissions` is converted to the PDF `/P` mask. `file_id` can be
/// supplied for deterministic output; when omitted, a generated file ID is
/// added as needed.
pub fn PdfDocument::encrypt_128bit(
  self : PdfDocument,
  user_password : BytesView,
  owner_password : BytesView,
  denied_permissions : ArrayView[PdfPermission],
  file_id? : BytesView = [],
) -> PdfDocument raise PdfError {
  self.encrypt_arc4_standard(
    user_password,
    owner_password,
    denied_permissions,
    2,
    3,
    128,
    true,
    file_id~,
  )
}

///|
/// Encrypt a copy of the document with revision-4 128-bit ARC4.
///
/// This writes a crypt-filter dictionary using `/V2`. `encrypt_metadata=false`
/// follows the revision-4 no-metadata key derivation and stream policy.
pub fn PdfDocument::encrypt_128bit_r4(
  self : PdfDocument,
  user_password : BytesView,
  owner_password : BytesView,
  denied_permissions : ArrayView[PdfPermission],
  encrypt_metadata? : Bool = true,
  file_id? : BytesView = [],
) -> PdfDocument raise PdfError {
  let no_encrypt_metadata = !encrypt_metadata
  let (document, id) = self.with_file_id(file_id~)
  let permissions = pdf_p_of_permissions(denied_permissions)
  let owner_entry = pdf_make_owner_password_entry(
    4, owner_password, user_password, 128,
  )
  let user_entry = pdf_make_user_password_entry(
    no_encrypt_metadata, user_password, 4, owner_entry, permissions, id, 128,
  )
  let file_key = pdf_encryption_file_key(
    no_encrypt_metadata, user_password, 4, owner_entry, permissions, id, 128,
  )
  let encrypted = document.arc4_crypt_parsed_objects(
    file_key,
    128,
    no_encrypt_metadata~,
  )
  let std_cf = pdf_crypt_std_cf_name
  let encrypt_dictionary : PdfObject = PdfDictionary([
    (pdf_crypt_filter_name, PdfNameObject(pdf_crypt_standard_name)),
    (pdf_crypt_v_name, PdfInteger(4)),
    (
      pdf_crypt_cf_name,
      PdfDictionary([
        (
          std_cf,
          PdfDictionary([
            (pdf_crypt_length_name, PdfInteger(16)),
            (pdf_crypt_auth_event_name, PdfNameObject(pdf_crypt_doc_open_name)),
            (pdf_crypt_cfm_name, PdfNameObject(pdf_crypt_v2_name)),
          ]),
        ),
      ]),
    ),
    (pdf_crypt_encrypt_metadata_name, PdfBoolean(encrypt_metadata)),
    (pdf_crypt_length_name, PdfInteger(128)),
    (pdf_crypt_r_name, PdfInteger(4)),
    (pdf_crypt_o_name, PdfString(owner_entry)),
    (pdf_crypt_u_name, PdfString(user_entry)),
    (pdf_crypt_p_name, PdfInteger(permissions)),
    (pdf_crypt_strf_name, PdfNameObject(std_cf)),
    (pdf_crypt_stmf_name, PdfNameObject(std_cf)),
  ])
  let encrypt_number = encrypted.add_object(encrypt_dictionary)
  encrypted.set_trailer_dict(
    encrypted
    .trailer_dict()
    .add_dict_entry(pdf_crypt_encrypt_name, PdfIndirect(encrypt_number)),
  )
  encrypted
}

///|
/// Encrypt a copy of the document with revision-4 AESV2.
///
/// `iv_provider` supplies per-object 16-byte CBC IVs by object number,
/// generation, and IV index. This makes tests reproducible while allowing
/// production callers to provide secure random IVs.
pub fn PdfDocument::encrypt_128bit_aesv2_with_iv_provider(
  self : PdfDocument,
  user_password : BytesView,
  owner_password : BytesView,
  denied_permissions : ArrayView[PdfPermission],
  iv_provider : (Int, Int, Int) -> PdfBytes raise PdfError,
  encrypt_metadata? : Bool = true,
  file_id? : BytesView = [],
) -> PdfDocument raise PdfError {
  let no_encrypt_metadata = !encrypt_metadata
  let (document, id) = self.with_file_id(file_id~)
  let permissions = pdf_p_of_permissions(denied_permissions)
  let owner_entry = pdf_make_owner_password_entry(
    4, owner_password, user_password, 128,
  )
  let user_entry = pdf_make_user_password_entry(
    no_encrypt_metadata, user_password, 4, owner_entry, permissions, id, 128,
  )
  let file_key = pdf_encryption_file_key(
    no_encrypt_metadata, user_password, 4, owner_entry, permissions, id, 128,
  )
  let encrypted = document.aesv2_encrypt_parsed_objects_with_iv_provider(
    file_key,
    128,
    iv_provider,
    no_encrypt_metadata~,
  )
  let std_cf = pdf_crypt_std_cf_name
  let encrypt_dictionary : PdfObject = PdfDictionary([
    (pdf_crypt_filter_name, PdfNameObject(pdf_crypt_standard_name)),
    (pdf_crypt_v_name, PdfInteger(4)),
    (
      pdf_crypt_cf_name,
      PdfDictionary([
        (
          std_cf,
          PdfDictionary([
            (pdf_crypt_length_name, PdfInteger(16)),
            (pdf_crypt_auth_event_name, PdfNameObject(pdf_crypt_doc_open_name)),
            (pdf_crypt_cfm_name, PdfNameObject(pdf_crypt_aesv2_name)),
          ]),
        ),
      ]),
    ),
    (pdf_crypt_encrypt_metadata_name, PdfBoolean(encrypt_metadata)),
    (pdf_crypt_length_name, PdfInteger(128)),
    (pdf_crypt_r_name, PdfInteger(4)),
    (pdf_crypt_o_name, PdfString(owner_entry)),
    (pdf_crypt_u_name, PdfString(user_entry)),
    (pdf_crypt_p_name, PdfInteger(permissions)),
    (pdf_crypt_strf_name, PdfNameObject(std_cf)),
    (pdf_crypt_stmf_name, PdfNameObject(std_cf)),
  ])
  let encrypt_number = encrypted.add_object(encrypt_dictionary)
  encrypted.set_trailer_dict(
    encrypted
    .trailer_dict()
    .add_dict_entry(pdf_crypt_encrypt_name, PdfIndirect(encrypt_number)),
  )
  encrypted
}

///|
/// Encrypt a copy of the document with AESV3/AES-256 security.
///
/// `random_provider` supplies the file key, salts, and permissions padding;
/// `iv_provider` supplies CBC IVs for encrypted strings and streams. `iso=true`
/// selects the ISO/PDF 2.0 hash variant.
pub fn PdfDocument::encrypt_256bit_aesv3_with_providers(
  self : PdfDocument,
  user_password : BytesView,
  owner_password : BytesView,
  denied_permissions : ArrayView[PdfPermission],
  random_provider : (PdfAesV3RandomField, Int) -> PdfBytes raise PdfError,
  iv_provider : (Int, Int, Int) -> PdfBytes raise PdfError,
  iso? : Bool = false,
  encrypt_metadata? : Bool = true,
  file_id? : BytesView = [],
) -> PdfDocument raise PdfError {
  let no_encrypt_metadata = !encrypt_metadata
  let (document, id) = self.with_file_id(file_id~)
  let permissions = pdf_p_of_permissions(denied_permissions)
  let file_key = pdf_aesv3_random_bytes(random_provider, PdfAesV3FileKey, 32)
  let user_validation_salt = pdf_aesv3_random_bytes(
    random_provider,
    PdfAesV3UserValidationSalt,
    8,
  )
  let user_key_salt = pdf_aesv3_random_bytes(
    random_provider,
    PdfAesV3UserKeySalt,
    8,
  )
  let owner_validation_salt = pdf_aesv3_random_bytes(
    random_provider,
    PdfAesV3OwnerValidationSalt,
    8,
  )
  let owner_key_salt = pdf_aesv3_random_bytes(
    random_provider,
    PdfAesV3OwnerKeySalt,
    8,
  )
  let permissions_padding = pdf_aesv3_random_bytes(
    random_provider,
    PdfAesV3PermissionsPadding,
    4,
  )
  let user_entry = pdf_aesv3_entry(
    iso, user_password, user_validation_salt, user_key_salt,
  )
  let owner_entry = pdf_aesv3_entry(
    iso,
    owner_password,
    owner_validation_salt,
    owner_key_salt,
    user_entry~,
  )
  let user_encryption_key = pdf_aesv3_wrap_file_key(
    iso, user_password, user_key_salt, file_key,
  )
  let owner_encryption_key = pdf_aesv3_wrap_file_key(
    iso,
    owner_password,
    owner_key_salt,
    file_key,
    user_entry~,
  )
  let permissions_entry = pdf_aesv3_permissions_entry(
    file_key, permissions, encrypt_metadata, permissions_padding,
  )
  let encrypted = document.aesv3_encrypt_parsed_objects_with_iv_provider(
    file_key,
    iv_provider,
    no_encrypt_metadata~,
  )
  let encrypt_dictionary = pdf_crypt_saved_aesv3_dictionary({
    crypt_type: PdfCryptAESV3(iso),
    user_entry,
    owner_entry,
    permissions,
    file_id: id,
    encrypt_metadata,
    permissions_entry: Some(permissions_entry),
    user_encryption_key: Some(user_encryption_key),
    owner_encryption_key: Some(owner_encryption_key),
  })
  let encrypt_number = encrypted.add_object(encrypt_dictionary)
  encrypted.set_trailer_dict(
    encrypted
    .trailer_dict()
    .add_dict_entry(pdf_crypt_encrypt_name, PdfIndirect(encrypt_number)),
  )
  encrypted
}

///|
/// Encrypt a copy of the document with the ISO AESV3/AES-256 variant.
///
/// This is a convenience wrapper around
/// `encrypt_256bit_aesv3_with_providers` with `iso=true`.
pub fn PdfDocument::encrypt_256bit_aesv3_iso_with_providers(
  self : PdfDocument,
  user_password : BytesView,
  owner_password : BytesView,
  denied_permissions : ArrayView[PdfPermission],
  random_provider : (PdfAesV3RandomField, Int) -> PdfBytes raise PdfError,
  iv_provider : (Int, Int, Int) -> PdfBytes raise PdfError,
  encrypt_metadata? : Bool = true,
  file_id? : BytesView = [],
) -> PdfDocument raise PdfError {
  self.encrypt_256bit_aesv3_with_providers(
    user_password,
    owner_password,
    denied_permissions,
    random_provider,
    iv_provider,
    iso=true,
    encrypt_metadata~,
    file_id~,
  )
}

///|
fn PdfDocument::encrypt_arc4_standard(
  self : PdfDocument,
  user_password : BytesView,
  owner_password : BytesView,
  denied_permissions : ArrayView[PdfPermission],
  version : Int,
  revision : Int,
  key_length_bits : Int,
  write_length : Bool,
  file_id? : BytesView = [],
) -> PdfDocument raise PdfError {
  let (document, id) = self.with_file_id(file_id~)
  let permissions = pdf_p_of_permissions(denied_permissions)
  let owner_entry = pdf_make_owner_password_entry(
    revision, owner_password, user_password, key_length_bits,
  )
  let user_entry = pdf_make_user_password_entry(
    false, user_password, revision, owner_entry, permissions, id, key_length_bits,
  )
  let file_key = pdf_encryption_file_key(
    false, user_password, revision, owner_entry, permissions, id, key_length_bits,
  )
  let encrypted = document.arc4_crypt_parsed_objects(file_key, key_length_bits)
  let entries : Array[(PdfName, PdfObject)] = [
    (pdf_crypt_filter_name, PdfNameObject(pdf_crypt_standard_name)),
    (pdf_crypt_v_name, PdfInteger(version)),
    (pdf_crypt_r_name, PdfInteger(revision)),
    (pdf_crypt_o_name, PdfString(owner_entry)),
    (pdf_crypt_u_name, PdfString(user_entry)),
    (pdf_crypt_p_name, PdfInteger(permissions)),
  ]
  if write_length {
    entries.push((pdf_crypt_length_name, PdfInteger(key_length_bits)))
  }
  let encrypt_dictionary : PdfObject = PdfDictionary(entries)
  let encrypt_number = encrypted.add_object(encrypt_dictionary)
  encrypted.set_trailer_dict(
    encrypted
    .trailer_dict()
    .add_dict_entry(pdf_crypt_encrypt_name, PdfIndirect(encrypt_number)),
  )
  encrypted
}

///|
fn pdf_crypt_saved_arc4_dictionary(
  values : PdfEncryptionValues,
  key_length_bits : Int,
  revision : Int,
) -> PdfObject {
  if revision == 4 {
    let std_cf = pdf_crypt_std_cf_name
    PdfDictionary([
      (pdf_crypt_filter_name, PdfNameObject(pdf_crypt_standard_name)),
      (pdf_crypt_v_name, PdfInteger(4)),
      (
        pdf_crypt_cf_name,
        PdfDictionary([
          (
            std_cf,
            PdfDictionary([
              (pdf_crypt_length_name, PdfInteger(key_length_bits / 8)),
              (
                pdf_crypt_auth_event_name,
                PdfNameObject(pdf_crypt_doc_open_name),
              ),
              (pdf_crypt_cfm_name, PdfNameObject(pdf_crypt_v2_name)),
            ]),
          ),
        ]),
      ),
      (pdf_crypt_encrypt_metadata_name, PdfBoolean(values.encrypt_metadata)),
      (pdf_crypt_length_name, PdfInteger(key_length_bits)),
      (pdf_crypt_r_name, PdfInteger(4)),
      (pdf_crypt_o_name, PdfString(values.owner_entry)),
      (pdf_crypt_u_name, PdfString(values.user_entry)),
      (pdf_crypt_p_name, PdfInteger(values.permissions)),
      (pdf_crypt_strf_name, PdfNameObject(std_cf)),
      (pdf_crypt_stmf_name, PdfNameObject(std_cf)),
    ])
  } else {
    let entries : Array[(PdfName, PdfObject)] = [
      (pdf_crypt_filter_name, PdfNameObject(pdf_crypt_standard_name)),
      (
        pdf_crypt_v_name,
        PdfInteger(if revision == 2 && key_length_bits == 40 { 1 } else { 2 }),
      ),
      (pdf_crypt_r_name, PdfInteger(revision)),
      (pdf_crypt_o_name, PdfString(values.owner_entry)),
      (pdf_crypt_u_name, PdfString(values.user_entry)),
      (pdf_crypt_p_name, PdfInteger(values.permissions)),
    ]
    if key_length_bits != 40 {
      entries.push((pdf_crypt_length_name, PdfInteger(key_length_bits)))
    }
    PdfDictionary(entries)
  }
}

///|
fn pdf_crypt_saved_aesv2_dictionary(values : PdfEncryptionValues) -> PdfObject {
  let std_cf = pdf_crypt_std_cf_name
  PdfDictionary([
    (pdf_crypt_filter_name, PdfNameObject(pdf_crypt_standard_name)),
    (pdf_crypt_v_name, PdfInteger(4)),
    (
      pdf_crypt_cf_name,
      PdfDictionary([
        (
          std_cf,
          PdfDictionary([
            (pdf_crypt_length_name, PdfInteger(16)),
            (pdf_crypt_auth_event_name, PdfNameObject(pdf_crypt_doc_open_name)),
            (pdf_crypt_cfm_name, PdfNameObject(pdf_crypt_aesv2_name)),
          ]),
        ),
      ]),
    ),
    (pdf_crypt_encrypt_metadata_name, PdfBoolean(values.encrypt_metadata)),
    (pdf_crypt_length_name, PdfInteger(128)),
    (pdf_crypt_r_name, PdfInteger(4)),
    (pdf_crypt_o_name, PdfString(values.owner_entry)),
    (pdf_crypt_u_name, PdfString(values.user_entry)),
    (pdf_crypt_p_name, PdfInteger(values.permissions)),
    (pdf_crypt_strf_name, PdfNameObject(std_cf)),
    (pdf_crypt_stmf_name, PdfNameObject(std_cf)),
  ])
}

///|
fn pdf_crypt_saved_aesv3_dictionary(
  values : PdfEncryptionValues,
) -> PdfObject raise PdfError {
  let std_cf = pdf_crypt_std_cf_name
  let revision = match values.crypt_type {
    PdfCryptAESV3(true) => 6
    _ => 5
  }
  PdfDictionary([
    (pdf_crypt_filter_name, PdfNameObject(pdf_crypt_standard_name)),
    (pdf_crypt_v_name, PdfInteger(5)),
    (
      pdf_crypt_cf_name,
      PdfDictionary([
        (
          std_cf,
          PdfDictionary([
            (pdf_crypt_length_name, PdfInteger(32)),
            (pdf_crypt_auth_event_name, PdfNameObject(pdf_crypt_doc_open_name)),
            (pdf_crypt_cfm_name, PdfNameObject(pdf_crypt_aesv3_name)),
          ]),
        ),
      ]),
    ),
    (pdf_crypt_encrypt_metadata_name, PdfBoolean(values.encrypt_metadata)),
    (pdf_crypt_length_name, PdfInteger(256)),
    (pdf_crypt_r_name, PdfInteger(revision)),
    (pdf_crypt_o_name, PdfString(values.owner_entry)),
    (pdf_crypt_u_name, PdfString(values.user_entry)),
    (
      pdf_crypt_oe_name,
      PdfString(
        pdf_aesv3_crypt_entry(pdf_crypt_oe_name, values.owner_encryption_key),
      ),
    ),
    (
      pdf_crypt_ue_name,
      PdfString(
        pdf_aesv3_crypt_entry(pdf_crypt_ue_name, values.user_encryption_key),
      ),
    ),
    (
      pdf_aesv3_permissions_key(),
      PdfString(
        pdf_crypt_chop_string(
          pdf_aesv3_permissions_key(),
          match values.permissions_entry {
            Some(value) => value
            None =>
              raise EncryptionDictionaryEntryExpected(
                pdf_aesv3_permissions_key(),
              )
          },
          16,
        ),
      ),
    ),
    (pdf_crypt_p_name, PdfInteger(values.permissions)),
    (pdf_crypt_strf_name, PdfNameObject(std_cf)),
    (pdf_crypt_stmf_name, PdfNameObject(std_cf)),
  ])
}

///|
fn PdfEncryptionValues::file_key_for_recrypt_password(
  self : PdfEncryptionValues,
  password : BytesView,
) -> PdfBytes raise PdfError {
  match self.file_key_for_user_password(password) {
    Some(key) => key
    None =>
      match self.file_key_for_owner_password(password) {
        Some(key) => key
        None => raise EncryptionRecryptFailed
      }
  }
}

///|
fn PdfDocument::pdf_crypt_prepare_plaintext_for_recrypt(
  self : PdfDocument,
) -> Unit {
  for number in self.object_numbers() {
    match self.objects.get_entry(number) {
      Some({ data: ObjectParsedAlreadyDecrypted(object), generation }) =>
        self.objects.set_entry(number, {
          data: ObjectParsed(object),
          generation,
        })
      _ => ()
    }
  }
}

///|
fn PdfDocument::recrypt_arc4_with_file_key(
  self : PdfDocument,
  values : PdfEncryptionValues,
  file_key : BytesView,
  key_length_bits : Int,
  revision : Int,
) -> PdfDocument raise PdfError {
  let (document, _) = self.with_file_id(file_id=values.file_id)
  document.pdf_crypt_prepare_plaintext_for_recrypt()
  document.set_saved_encryption(None)
  let encrypted = document.arc4_crypt_parsed_objects(
    file_key,
    key_length_bits,
    no_encrypt_metadata=!values.encrypt_metadata,
  )
  encrypted.set_saved_encryption(None)
  let encrypt_dictionary = pdf_crypt_saved_arc4_dictionary(
    values, key_length_bits, revision,
  )
  let encrypt_number = encrypted.add_object(encrypt_dictionary)
  encrypted.set_trailer_dict(
    encrypted
    .trailer_dict()
    .add_dict_entry(pdf_crypt_encrypt_name, PdfIndirect(encrypt_number)),
  )
  encrypted
}

///|
fn PdfDocument::recrypt_aesv2_with_file_key(
  self : PdfDocument,
  values : PdfEncryptionValues,
  file_key : BytesView,
  iv_provider : (Int, Int, Int) -> PdfBytes raise PdfError,
) -> PdfDocument raise PdfError {
  let (document, _) = self.with_file_id(file_id=values.file_id)
  document.pdf_crypt_prepare_plaintext_for_recrypt()
  document.set_saved_encryption(None)
  let encrypted = document.aesv2_encrypt_parsed_objects_with_iv_provider(
    file_key,
    128,
    iv_provider,
    no_encrypt_metadata=!values.encrypt_metadata,
  )
  encrypted.set_saved_encryption(None)
  let encrypt_dictionary = pdf_crypt_saved_aesv2_dictionary(values)
  let encrypt_number = encrypted.add_object(encrypt_dictionary)
  encrypted.set_trailer_dict(
    encrypted
    .trailer_dict()
    .add_dict_entry(pdf_crypt_encrypt_name, PdfIndirect(encrypt_number)),
  )
  encrypted
}

///|
fn PdfDocument::recrypt_aesv3_with_file_key(
  self : PdfDocument,
  values : PdfEncryptionValues,
  file_key : BytesView,
  iv_provider : (Int, Int, Int) -> PdfBytes raise PdfError,
) -> PdfDocument raise PdfError {
  let (document, _) = self.with_file_id(file_id=values.file_id)
  document.pdf_crypt_prepare_plaintext_for_recrypt()
  document.set_saved_encryption(None)
  let encrypted = document.aesv3_encrypt_parsed_objects_with_iv_provider(
    file_key,
    iv_provider,
    no_encrypt_metadata=!values.encrypt_metadata,
  )
  encrypted.set_saved_encryption(None)
  let encrypt_dictionary = pdf_crypt_saved_aesv3_dictionary(values)
  let encrypt_number = encrypted.add_object(encrypt_dictionary)
  encrypted.set_trailer_dict(
    encrypted
    .trailer_dict()
    .add_dict_entry(pdf_crypt_encrypt_name, PdfIndirect(encrypt_number)),
  )
  encrypted
}

///|
/// Re-encrypt a previously decrypted document using its saved ARC4 settings.
///
/// The document must have saved encryption state from a successful decrypt.
/// The supplied password is authenticated against that state before the
/// original encryption dictionary shape is restored.
pub fn PdfDocument::recrypt_with_password(
  self : PdfDocument,
  password : BytesView,
) -> PdfDocument raise PdfError {
  let saved = match self.saved_encryption() {
    Some(saved) => saved
    None => raise EncryptionSavedStateExpected
  }
  let values = saved.values
  match values.crypt_type {
    PdfCryptARC4(key_length_bits, revision) if (
        key_length_bits == 40 || key_length_bits == 128
      ) &&
      (revision == 2 || revision == 3 || revision == 4) => {
      let file_key = values.file_key_for_recrypt_password(password)
      self.recrypt_arc4_with_file_key(
        values, file_key, key_length_bits, revision,
      )
    }
    _ => raise EncryptionRecryptUnsupported(values.crypt_type)
  }
}

///|
/// Re-encrypt a decrypted AESV2 document using its saved encryption settings.
///
/// `iv_provider` supplies fresh IVs for encrypted object data. The saved
/// encryption state determines passwords, permissions, and crypt-filter shape.
pub fn PdfDocument::recrypt_with_password_aesv2_with_iv_provider(
  self : PdfDocument,
  password : BytesView,
  iv_provider : (Int, Int, Int) -> PdfBytes raise PdfError,
) -> PdfDocument raise PdfError {
  let saved = match self.saved_encryption() {
    Some(saved) => saved
    None => raise EncryptionSavedStateExpected
  }
  let values = saved.values
  match values.crypt_type {
    PdfCryptAESV2 => {
      let file_key = values.file_key_for_recrypt_password(password)
      self.recrypt_aesv2_with_file_key(values, file_key, iv_provider)
    }
    _ => raise EncryptionRecryptUnsupported(values.crypt_type)
  }
}

///|
/// Re-encrypt a decrypted AESV3 document using its saved encryption settings.
///
/// `iv_provider` supplies fresh IVs for encrypted object data. The saved
/// encryption state supplies the existing AESV3 password entries and file key
/// wrapping metadata.
pub fn PdfDocument::recrypt_with_password_aesv3_with_iv_provider(
  self : PdfDocument,
  password : BytesView,
  iv_provider : (Int, Int, Int) -> PdfBytes raise PdfError,
) -> PdfDocument raise PdfError {
  let saved = match self.saved_encryption() {
    Some(saved) => saved
    None => raise EncryptionSavedStateExpected
  }
  let values = saved.values
  match values.crypt_type {
    PdfCryptAESV3(_) => {
      let file_key = values.file_key_for_recrypt_password(password)
      self.recrypt_aesv3_with_file_key(values, file_key, iv_provider)
    }
    _ => raise EncryptionRecryptUnsupported(values.crypt_type)
  }
}

///|
/// Decrypt with a user password only.
///
/// Unencrypted documents return a copied document and empty denied permissions.
/// Encrypted documents return `None` when the user password does not
/// authenticate.
pub fn PdfDocument::decrypt_with_user_password(
  self : PdfDocument,
  password : BytesView,
  no_encrypt_metadata? : Bool = false,
) -> PdfDecryptionResult? raise PdfError {
  match self.trailer_dict().lookup_immediate(pdf_crypt_encrypt_name) {
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
/// Decrypt with an owner password only.
///
/// Unencrypted documents return a copied document and empty denied permissions.
/// Encrypted documents return `None` when the owner password does not
/// authenticate.
pub fn PdfDocument::decrypt_with_owner_password(
  self : PdfDocument,
  password : BytesView,
  no_encrypt_metadata? : Bool = false,
) -> PdfDecryptionResult? raise PdfError {
  match self.trailer_dict().lookup_immediate(pdf_crypt_encrypt_name) {
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
/// CamlPDF-shaped decrypt helper returning document and denied permissions.
///
/// A failed authentication returns `(None, current_permissions)`, while
/// malformed encryption dictionaries raise `PdfError`.
pub fn pdf_decrypt_pdf(
  document : PdfDocument,
  user_password : BytesView,
  owner_password? : BytesView? = None,
  no_encrypt_metadata? : Bool = false,
) -> (PdfDocument?, Array[PdfPermission]) raise PdfError {
  match
    document.decrypt_with_passwords(
      user_password=Some(user_password),
      owner_password~,
      no_encrypt_metadata~,
    ) {
    Some(result) => (Some(result.document), result.denied_permissions)
    None => (None, document.permissions())
  }
}

///|
/// CamlPDF-shaped owner-password decrypt helper.
pub fn pdf_decrypt_pdf_owner(
  document : PdfDocument,
  owner_password : BytesView,
  no_encrypt_metadata? : Bool = false,
) -> PdfDocument? raise PdfError {
  match
    document.decrypt_with_owner_password(owner_password, no_encrypt_metadata~) {
    Some(result) => Some(result.document)
    None => None
  }
}

///|
/// Compatibility wrapper for `PdfDocument::is_encrypted`.
pub fn pdf_is_encrypted(document : PdfDocument) -> Bool {
  document.is_encrypted()
}

///|
/// Compatibility wrapper for `PdfDocument::what_encryption`.
pub fn pdf_what_encryption(
  document : PdfDocument,
) -> PdfEncryptionMethod? raise PdfError {
  document.what_encryption()
}

///|
/// Compatibility wrapper for `PdfDocument::permissions`.
pub fn pdf_permissions(
  document : PdfDocument,
) -> Array[PdfPermission] raise PdfError {
  document.permissions()
}

///|
/// Compatibility wrapper for `PdfDocument::encryption_values`.
pub fn pdf_get_encryption_values(
  document : PdfDocument,
) -> PdfEncryptionValues raise PdfError {
  document.encryption_values()
}

///|
/// Compatibility wrapper for `PdfDocument::decrypt_single_stream`.
pub fn pdf_decrypt_single_stream(
  document : PdfDocument,
  object_number : Int,
  generation : Int,
  stream : PdfObject,
  user_password? : BytesView? = None,
  owner_password? : BytesView? = None,
  no_encrypt_metadata? : Bool = false,
) -> PdfObject? raise PdfError {
  document.decrypt_single_stream(
    object_number,
    generation,
    stream,
    user_password~,
    owner_password~,
    no_encrypt_metadata~,
  )
}

///|
/// Compatibility wrapper for `PdfDocument::encrypt_40bit`.
pub fn pdf_encrypt_pdf_40bit(
  document : PdfDocument,
  user_password : BytesView,
  owner_password : BytesView,
  denied_permissions : ArrayView[PdfPermission],
  file_id? : BytesView = [],
) -> PdfDocument raise PdfError {
  document.encrypt_40bit(
    user_password,
    owner_password,
    denied_permissions,
    file_id~,
  )
}

///|
/// Compatibility wrapper for `PdfDocument::encrypt_128bit`.
pub fn pdf_encrypt_pdf_128bit(
  document : PdfDocument,
  user_password : BytesView,
  owner_password : BytesView,
  denied_permissions : ArrayView[PdfPermission],
  file_id? : BytesView = [],
) -> PdfDocument raise PdfError {
  document.encrypt_128bit(
    user_password,
    owner_password,
    denied_permissions,
    file_id~,
  )
}

///|
/// Compatibility wrapper for AESV2 encryption with caller-supplied IVs.
pub fn pdf_encrypt_pdf_AES_with_iv_provider(
  document : PdfDocument,
  encrypt_metadata : Bool,
  user_password : BytesView,
  owner_password : BytesView,
  denied_permissions : ArrayView[PdfPermission],
  iv_provider : (Int, Int, Int) -> PdfBytes raise PdfError,
  file_id? : BytesView = [],
) -> PdfDocument raise PdfError {
  document.encrypt_128bit_aesv2_with_iv_provider(
    user_password,
    owner_password,
    denied_permissions,
    iv_provider,
    encrypt_metadata~,
    file_id~,
  )
}

///|
/// Compatibility wrapper for AESV3 encryption with caller-supplied providers.
pub fn pdf_encrypt_pdf_AES256_with_providers(
  document : PdfDocument,
  encrypt_metadata : Bool,
  user_password : BytesView,
  owner_password : BytesView,
  denied_permissions : ArrayView[PdfPermission],
  random_provider : (PdfAesV3RandomField, Int) -> PdfBytes raise PdfError,
  iv_provider : (Int, Int, Int) -> PdfBytes raise PdfError,
  file_id? : BytesView = [],
) -> PdfDocument raise PdfError {
  document.encrypt_256bit_aesv3_with_providers(
    user_password,
    owner_password,
    denied_permissions,
    random_provider,
    iv_provider,
    encrypt_metadata~,
    file_id~,
  )
}

///|
/// Compatibility wrapper for ISO AESV3 encryption with caller-supplied providers.
pub fn pdf_encrypt_pdf_AES256ISO_with_providers(
  document : PdfDocument,
  encrypt_metadata : Bool,
  user_password : BytesView,
  owner_password : BytesView,
  denied_permissions : ArrayView[PdfPermission],
  random_provider : (PdfAesV3RandomField, Int) -> PdfBytes raise PdfError,
  iv_provider : (Int, Int, Int) -> PdfBytes raise PdfError,
  file_id? : BytesView = [],
) -> PdfDocument raise PdfError {
  document.encrypt_256bit_aesv3_iso_with_providers(
    user_password,
    owner_password,
    denied_permissions,
    random_provider,
    iv_provider,
    encrypt_metadata~,
    file_id~,
  )
}

///|
/// Re-encrypt a decrypted document, optionally compact-renumbering first.
///
/// AES documents use `iv_provider`; ARC4 documents ignore it. The input must
/// carry saved encryption state from a previous decrypt.
pub fn pdf_recrypt_pdf_with_iv_provider(
  document : PdfDocument,
  password : BytesView,
  iv_provider : (Int, Int, Int) -> PdfBytes raise PdfError,
  renumber? : Bool = true,
) -> PdfDocument raise PdfError {
  let input = if renumber {
    document.renumber_objects_compact()
  } else {
    document.copy()
  }
  let saved = match input.saved_encryption() {
    Some(saved) => saved
    None => raise EncryptionSavedStateExpected
  }
  match saved.values.crypt_type {
    PdfCryptAESV2 =>
      input.recrypt_with_password_aesv2_with_iv_provider(password, iv_provider)
    PdfCryptAESV3(_) =>
      input.recrypt_with_password_aesv3_with_iv_provider(password, iv_provider)
    PdfCryptARC4(_, _) => input.recrypt_with_password(password)
  }
}

///|
/// Re-encrypt a decrypted ARC4 document, optionally compact-renumbering first.
///
/// AES documents require `pdf_recrypt_pdf_with_iv_provider` so fresh IVs can be
/// supplied.
pub fn pdf_recrypt_pdf(
  document : PdfDocument,
  password : BytesView,
  renumber? : Bool = true,
) -> PdfDocument raise PdfError {
  let input = if renumber {
    document.renumber_objects_compact()
  } else {
    document.copy()
  }
  input.recrypt_with_password(password)
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
/// Return the standard 32-byte PDF password padding sequence.
pub fn pdf_password_padding() -> PdfBytes {
  Bytes::from_array(pdf_password_padding_fixed())
}

///|
/// Pad or truncate a raw PDF password to 32 bytes.
///
/// Passwords are byte sequences. Inputs longer than 32 bytes are truncated;
/// shorter inputs are filled with the standard PDF padding sequence.
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
fn pdf_aesv3_cbc_encrypt_no_padding_with_iv(
  key : BytesView,
  iv : BytesView,
  data : BytesView,
) -> PdfBytes raise PdfError {
  guard data.length() % 16 == 0 else {
    raise InvalidCryptoDataLength(data.length())
  }
  let output : Array[Byte] = []
  let mut previous = pdf_crypt_chop_view(pdf_crypt_iv_name, iv, 16)
  let mut position = 0
  while position < data.length() {
    let block : Array[Byte] = []
    for index in 0..<16 {
      block.push(
        (data[position + index].to_int() ^ previous[index].to_int()).to_byte(),
      )
    }
    previous = pdf_aes_encrypt_block(key, Bytes::from_array(block))
    for byte in previous {
      output.push(byte)
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
    0 => pdf_sha256_digest(data)
    1 => pdf_sha384_digest(data)
    _ => pdf_sha512_digest(data)
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
  let mut digest = pdf_sha256_digest(input)
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
    pdf_sha256_digest(input)
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
  let block : Array[Byte] = []
  for shift in [0, 8, 16, 24] {
    block.push(pdf_crypt_low_byte(permissions, shift))
  }
  for _ in 0..<4 {
    block.push((255).to_byte())
  }
  block.push(if encrypt_metadata { b'T' } else { b'F' })
  block.push(b'a')
  block.push(b'd')
  block.push(b'b')
  for
    byte in pdf_crypt_chop_view(
      pdf_aesv3_random_field_key(PdfAesV3PermissionsPadding),
      padding,
      4,
    ) {
    block.push(byte)
  }
  pdf_aes_encrypt_block(file_key, Bytes::from_array(block))
}

///|
/// Authenticate an AESV3 user password entry.
///
/// `iso` selects the ISO/PDF 2.0 hash variant. Short `/U` entries raise
/// `EncryptionDictionaryEntryTooShort`.
pub fn pdf_authenticate_user_password_aesv3(
  iso : Bool,
  password : BytesView,
  user_entry : BytesView,
) -> Bool raise PdfError {
  if user_entry.length() < 48 {
    raise EncryptionDictionaryEntryTooShort(pdf_crypt_u_name)
  }
  let expected = pdf_aesv3_password_hash(iso, password, user_entry[32:40])
  pdf_bytes_prefix_equal(user_entry, expected, 32)
}

///|
/// Authenticate an AESV3 owner password entry.
///
/// Owner authentication incorporates the 48-byte user entry as required by the
/// AESV3 security algorithm. Short `/O` or `/U` entries raise `PdfError`.
pub fn pdf_authenticate_owner_password_aesv3(
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
  pdf_bytes_prefix_equal(owner_entry, expected, 32)
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
  pdf_aes_cbc_decrypt(digest, data, remove_padding=false)
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
  let decrypted = pdf_aes_ecb_decrypt(
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

///|
fn pdf_crypt_low_byte(value : Int, shift : Int) -> Byte {
  ((value >> shift) & 0xff).to_byte()
}

///|
fn pdf_crypt_push_view(output : Array[Byte], data : BytesView) -> Unit {
  for byte in data {
    output.push(byte)
  }
}

///|
/// Derive the standard-security file key from a user password.
///
/// This implements revisions 2-4 key derivation. AESV3 uses wrapped file keys
/// instead and should go through the `PdfEncryptionValues` helpers.
pub fn pdf_encryption_file_key(
  no_encrypt_metadata : Bool,
  password : BytesView,
  revision : Int,
  owner_entry : BytesView,
  permissions : Int,
  file_id : BytesView,
  key_length_bits : Int,
) -> PdfBytes {
  let padded_password = pdf_pad_password(password)
  let digest_input : Array[Byte] = []
  pdf_crypt_push_view(digest_input, padded_password)
  pdf_crypt_push_view(digest_input, owner_entry)
  let permissions_bytes : FixedArray[Byte] = [
    pdf_crypt_low_byte(permissions, 0),
    pdf_crypt_low_byte(permissions, 8),
    pdf_crypt_low_byte(permissions, 16),
    pdf_crypt_low_byte(permissions, 24),
  ]
  for byte in permissions_bytes {
    digest_input.push(byte)
  }
  pdf_crypt_push_view(digest_input, file_id)
  if revision >= 4 && no_encrypt_metadata {
    let no_metadata_marker : FixedArray[Byte] = [0xff, 0xff, 0xff, 0xff]
    for byte in no_metadata_marker {
      digest_input.push(byte)
    }
  }
  let key_length = key_length_bits / 8
  let mut hashed = pdf_md5_digest(Bytes::from_array(digest_input))
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
/// Build the `/U` user-password entry for revisions 2-4.
///
/// The entry is derived from the user password, owner entry, permission mask,
/// file ID, key length, and metadata-encryption flag.
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
    pdf_arc4_crypt(key, pdf_password_padding())
  } else {
    let digest_input : Array[Byte] = []
    pdf_crypt_push_view(digest_input, pdf_password_padding())
    pdf_crypt_push_view(digest_input, file_id)
    let digest = pdf_md5_digest(Bytes::from_array(digest_input))
    let mut encrypted = pdf_arc4_crypt(key, digest)
    for iteration in 1..<20 {
      let iteration_key = pdf_key_xor_iteration(key, iteration)
      encrypted = pdf_arc4_crypt(iteration_key, encrypted)
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
/// Authenticate a revision 2-4 user password against a `/U` entry.
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
    pdf_bytes_prefix_equal(user_entry, expected, 16)
  } else {
    pdf_bytes_prefix_equal(user_entry, expected, expected.length()) &&
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
  let mut digest = pdf_md5_digest(padded_owner)
  if revision >= 3 {
    for _ in 0..<50 {
      digest = pdf_md5_digest(digest)
    }
  }
  digest[:key_length_bits / 8].to_owned()
}

///|
/// Build the `/O` owner-password entry for revisions 2-4.
///
/// A blank owner password follows PDF behavior by using the user password as
/// the owner-password source.
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
    pdf_arc4_crypt(key, padded_user)
  } else {
    let mut encrypted = pdf_arc4_crypt(key, padded_user)
    for iteration in 1..<20 {
      let iteration_key = pdf_key_xor_iteration(key, iteration)
      encrypted = pdf_arc4_crypt(iteration_key, encrypted)
    }
    encrypted
  }
}

///|
/// Recover the padded user-password bytes from a revision 2-4 owner password.
///
/// The returned bytes are the padded/truncated internal password form, not a
/// decoded MoonBit string.
pub fn pdf_user_password_from_owner_password(
  revision : Int,
  owner_password : BytesView,
  owner_entry : BytesView,
  key_length_bits : Int,
) -> PdfBytes raise PdfError {
  let key = pdf_owner_password_key(owner_password, revision, key_length_bits)
  if revision == 2 {
    pdf_arc4_crypt(key, owner_entry)
  } else {
    let mut decrypted = owner_entry.to_owned()
    let mut iteration = 19
    while iteration >= 0 {
      let iteration_key = pdf_key_xor_iteration(key, iteration)
      decrypted = pdf_arc4_crypt(iteration_key, decrypted)
      iteration -= 1
    }
    decrypted
  }
}

///|
/// Authenticate a revision 2-4 owner password.
///
/// This decrypts the owner entry to recover the padded user password and then
/// validates that recovered password against the user entry.
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
    no_encrypt_metadata, user_password, revision, user_entry, owner_entry, permissions,
    file_id, key_length_bits,
  )
}

///|
fn pdf_crypt_stream_length_key() -> PdfName {
  pdf_name_of_bytes(@ascii.encode("/Length"))
}

///|
fn pdf_crypt_stream_filter_key() -> PdfName {
  pdf_crypt_filter_name
}

///|
fn pdf_crypt_stream_decodeparms_key() -> PdfName {
  pdf_crypt_decodeparms_name
}

///|
fn pdf_crypt_stream_name_key() -> PdfName {
  pdf_crypt_name_key_name
}

///|
fn pdf_crypt_stream_type_key() -> PdfName {
  pdf_crypt_type_name
}

///|
fn pdf_crypt_object_is_name(object : PdfObject?, expected : PdfName) -> Bool {
  match object {
    Some(PdfNameObject(name)) => name == expected
    _ => false
  }
}

///|
fn pdf_crypt_first_filter_is_crypt(dictionary : PdfObject) -> Bool {
  match dictionary.lookup_immediate(pdf_crypt_stream_filter_key()) {
    Some(PdfNameObject(name)) => name == pdf_crypt_crypt_name
    Some(PdfArray([PdfNameObject(name), ..])) => name == pdf_crypt_crypt_name
    _ => false
  }
}

///|
fn pdf_crypt_decodeparms_is_identity(dictionary : PdfObject) -> Bool {
  match dictionary.lookup_immediate(pdf_crypt_stream_decodeparms_key()) {
    Some(PdfDictionary(_) as decodeparms)
    | Some(PdfArray([PdfDictionary(_) as decodeparms, ..])) =>
      match decodeparms.lookup_immediate(pdf_crypt_stream_name_key()) {
        Some(PdfNameObject(name)) => name == pdf_crypt_identity_name
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
      pdf_crypt_metadata_name,
    ) {
    true
  } else {
    pdf_crypt_first_filter_is_crypt(dictionary) &&
    pdf_crypt_decodeparms_is_identity(dictionary)
  }
}

///|
fn pdf_arc4_crypt_pdf_object_with_stream_policy(
  object_number : Int,
  generation : Int,
  file_key : BytesView,
  key_length_bits : Int,
  object : PdfObject,
  no_encrypt_metadata : Bool,
  defer_stream_decryption : Bool,
) -> PdfObject raise PdfError {
  match object {
    PdfString(bytes) =>
      PdfString(
        pdf_arc4_crypt_object(
          object_number, generation, file_key, key_length_bits, bytes,
        ),
      )
    PdfArray(values) => {
      let output : Array[PdfObject] = []
      for value in values {
        output.push(
          pdf_arc4_crypt_pdf_object_with_stream_policy(
            object_number, generation, file_key, key_length_bits, value, no_encrypt_metadata,
            defer_stream_decryption,
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
            pdf_arc4_crypt_pdf_object_with_stream_policy(
              object_number, generation, file_key, key_length_bits, value, no_encrypt_metadata,
              defer_stream_decryption,
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
        let dictionary = pdf_arc4_crypt_pdf_object_with_stream_policy(
          object_number,
          generation,
          file_key,
          key_length_bits,
          stream.dictionary,
          no_encrypt_metadata,
          defer_stream_decryption,
        )
        match stream.data {
          StreamToGet(to_get) if defer_stream_decryption &&
            to_get.crypt().is_identity() =>
            PdfStreamObject({
              dictionary,
              data: StreamToGet({
                input: to_get.input,
                position: to_get.position,
                length: to_get.length,
                crypt: PdfStreamDataArc4Decrypt(
                  object_number,
                  generation,
                  file_key.to_owned(),
                  key_length_bits,
                ),
              }),
            })
          _ => {
            let data = pdf_stream_data_bytes(stream.data)
            let encrypted_data = pdf_arc4_crypt_object(
              object_number, generation, file_key, key_length_bits, data,
            )
            PdfStreamObject({
              dictionary: dictionary.add_dict_entry(
                pdf_crypt_stream_length_key(),
                PdfInteger(encrypted_data.length()),
              ),
              data: StreamGot(encrypted_data),
            })
          }
        }
      }
    _ => object
  }
}

///|
/// Apply ARC4 object encryption or decryption to a PDF object.
///
/// ARC4 is symmetric. The object key is derived from object number,
/// generation, file key, and key length. Streams using identity crypt filters,
/// and metadata streams when `no_encrypt_metadata=true`, are left unchanged.
pub fn pdf_arc4_crypt_pdf_object(
  object_number : Int,
  generation : Int,
  file_key : BytesView,
  key_length_bits : Int,
  object : PdfObject,
  no_encrypt_metadata? : Bool = false,
) -> PdfObject raise PdfError {
  pdf_arc4_crypt_pdf_object_with_stream_policy(
    object_number, generation, file_key, key_length_bits, object, no_encrypt_metadata,
    false,
  )
}

///|
/// Decrypt AESV2 object data bytes with the derived object key.
///
/// `data` must include the leading CBC IV as stored in encrypted PDF strings
/// and streams.
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
  pdf_aes_cbc_decrypt(object_key, data)
}

///|
/// Encrypt bytes as AESV2 object data with an explicit CBC IV.
///
/// The returned bytes include the IV prefix expected by PDF AESV2 strings and
/// streams.
pub fn pdf_aesv2_encrypt_object_data(
  object_number : Int,
  generation : Int,
  file_key : BytesView,
  key_length_bits : Int,
  data : BytesView,
  iv : BytesView,
) -> PdfBytes raise PdfError {
  let object_key = pdf_encryption_object_key(
    PdfCryptAESV2,
    object_number,
    generation,
    file_key,
    key_length_bits,
  )
  pdf_aes_cbc_encrypt_with_iv(object_key, iv, data)
}

///|
/// Decrypt AESV3 object data bytes with the document file key.
///
/// `data` must include the leading CBC IV.
pub fn pdf_aesv3_decrypt_object_data(
  file_key : BytesView,
  data : BytesView,
) -> PdfBytes raise PdfError {
  pdf_aes_cbc_decrypt(file_key, data)
}

///|
/// Encrypt bytes as AESV3 object data with an explicit CBC IV.
///
/// The returned bytes include the IV prefix expected by PDF AES strings and
/// streams.
pub fn pdf_aesv3_encrypt_object_data(
  file_key : BytesView,
  data : BytesView,
  iv : BytesView,
) -> PdfBytes raise PdfError {
  pdf_aes_cbc_encrypt_with_iv(file_key, iv, data)
}

///|
fn pdf_aes_next_iv(
  iv_provider : (Int) -> PdfBytes raise PdfError,
  iv_index : Ref[Int],
) -> PdfBytes raise PdfError {
  let iv = iv_provider(iv_index.val)
  iv_index.val += 1
  iv
}

///|
fn pdf_aes_encrypt_pdf_object_with_key(
  key : BytesView,
  object : PdfObject,
  iv_provider : (Int) -> PdfBytes raise PdfError,
  iv_index : Ref[Int],
  no_encrypt_metadata? : Bool = false,
) -> PdfObject raise PdfError {
  match object {
    PdfString(bytes) => {
      let iv = pdf_aes_next_iv(iv_provider, iv_index)
      PdfString(pdf_aes_cbc_encrypt_with_iv(key, iv, bytes))
    }
    PdfArray(values) => {
      let output : Array[PdfObject] = []
      for value in values {
        output.push(
          pdf_aes_encrypt_pdf_object_with_key(
            key,
            value,
            iv_provider,
            iv_index,
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
            pdf_aes_encrypt_pdf_object_with_key(
              key,
              value,
              iv_provider,
              iv_index,
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
        let dictionary = pdf_aes_encrypt_pdf_object_with_key(
          key,
          stream.dictionary,
          iv_provider,
          iv_index,
          no_encrypt_metadata~,
        )
        let data = pdf_stream_data_bytes(stream.data)
        let iv = pdf_aes_next_iv(iv_provider, iv_index)
        let encrypted_data = pdf_aes_cbc_encrypt_with_iv(key, iv, data)
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
/// Encrypt a PDF object using AESV2 with per-object derived keys.
///
/// The IV provider is called with a zero-based index for each encrypted string
/// or stream inside the object. Identity crypt-filter streams are preserved.
pub fn pdf_aesv2_encrypt_pdf_object_with_iv_provider(
  object_number : Int,
  generation : Int,
  file_key : BytesView,
  key_length_bits : Int,
  object : PdfObject,
  iv_provider : (Int) -> PdfBytes raise PdfError,
  no_encrypt_metadata? : Bool = false,
) -> PdfObject raise PdfError {
  let object_key = pdf_encryption_object_key(
    PdfCryptAESV2,
    object_number,
    generation,
    file_key,
    key_length_bits,
  )
  let iv_index : Ref[Int] = { val: 0 }
  pdf_aes_encrypt_pdf_object_with_key(
    object_key,
    object,
    iv_provider,
    iv_index,
    no_encrypt_metadata~,
  )
}

///|
/// Encrypt a PDF object using AESV3 with the file key directly.
///
/// The IV provider is called with a zero-based index for each encrypted string
/// or stream inside the object. Identity crypt-filter streams are preserved.
pub fn pdf_aesv3_encrypt_pdf_object_with_iv_provider(
  file_key : BytesView,
  object : PdfObject,
  iv_provider : (Int) -> PdfBytes raise PdfError,
  no_encrypt_metadata? : Bool = false,
) -> PdfObject raise PdfError {
  let iv_index : Ref[Int] = { val: 0 }
  pdf_aes_encrypt_pdf_object_with_key(
    file_key,
    object,
    iv_provider,
    iv_index,
    no_encrypt_metadata~,
  )
}

///|
fn pdf_aes_decrypt_pdf_object_with_key(
  key : BytesView,
  object : PdfObject,
  no_encrypt_metadata? : Bool = false,
  deferred_stream_crypt? : PdfStreamDataCrypt = PdfStreamDataNoCrypt,
) -> PdfObject raise PdfError {
  match object {
    PdfString(bytes) => PdfString(pdf_aes_cbc_decrypt(key, bytes))
    PdfArray(values) => {
      let output : Array[PdfObject] = []
      for value in values {
        output.push(
          pdf_aes_decrypt_pdf_object_with_key(
            key,
            value,
            no_encrypt_metadata~,
            deferred_stream_crypt~,
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
            pdf_aes_decrypt_pdf_object_with_key(
              key,
              value,
              no_encrypt_metadata~,
              deferred_stream_crypt~,
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
          deferred_stream_crypt~,
        )
        match stream.data {
          StreamToGet(to_get) if to_get.crypt().is_identity() &&
            !deferred_stream_crypt.is_identity() =>
            PdfStreamObject({
              dictionary,
              data: StreamToGet({
                input: to_get.input,
                position: to_get.position,
                length: to_get.length,
                crypt: deferred_stream_crypt.deep_copy(),
              }),
            })
          _ => {
            let data = pdf_stream_data_bytes(stream.data)
            let decrypted_data = pdf_aes_cbc_decrypt(key, data)
            PdfStreamObject({
              dictionary: dictionary.add_dict_entry(
                pdf_crypt_stream_length_key(),
                PdfInteger(decrypted_data.length()),
              ),
              data: StreamGot(decrypted_data),
            })
          }
        }
      }
    _ => object
  }
}

///|
/// Decrypt a PDF object using AESV2 with per-object derived keys.
///
/// Deferred stream data is annotated with AESV2 crypt state so it can be
/// decrypted lazily when the stream bytes are loaded.
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
    object_key,
    object,
    no_encrypt_metadata~,
    deferred_stream_crypt=PdfStreamDataAesV2Decrypt(
      object_number,
      generation,
      file_key.to_owned(),
      key_length_bits,
    ),
  )
}

///|
/// Decrypt a PDF object using AESV3 with the file key directly.
///
/// Deferred stream data is annotated with AESV3 crypt state so it can be
/// decrypted lazily when the stream bytes are loaded.
pub fn pdf_aesv3_decrypt_pdf_object(
  file_key : BytesView,
  object : PdfObject,
  no_encrypt_metadata? : Bool = false,
) -> PdfObject raise PdfError {
  pdf_aes_decrypt_pdf_object_with_key(
    file_key,
    object,
    no_encrypt_metadata~,
    deferred_stream_crypt=PdfStreamDataAesV3Decrypt(file_key.to_owned()),
  )
}

///|
/// Apply ARC4 crypt to all parsed objects in a copied document.
///
/// `skip_object_number` is used to leave the encryption dictionary itself
/// unencrypted. Deferred and object-stream placeholders are left untouched.
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
              pdf_arc4_crypt_pdf_object_with_stream_policy(
                number,
                entry.generation,
                file_key,
                key_length_bits,
                object,
                no_encrypt_metadata,
                true,
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
/// AESV2-encrypt all parsed objects in a copied document.
///
/// The IV provider receives object number, generation, and per-object IV index.
/// `skip_object_number` leaves the encryption dictionary unencrypted.
pub fn PdfDocument::aesv2_encrypt_parsed_objects_with_iv_provider(
  self : PdfDocument,
  file_key : BytesView,
  key_length_bits : Int,
  iv_provider : (Int, Int, Int) -> PdfBytes raise PdfError,
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
              pdf_aesv2_encrypt_pdf_object_with_iv_provider(
                number,
                entry.generation,
                file_key,
                key_length_bits,
                object,
                fn(index) raise PdfError {
                  iv_provider(number, entry.generation, index)
                },
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
/// AESV2-decrypt all parsed objects in a copied document.
///
/// Parsed streams may retain deferred crypt metadata so stream bytes can be
/// decrypted lazily. `skip_object_number` leaves the encryption dictionary
/// untouched.
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
/// AESV3-encrypt all parsed objects in a copied document.
///
/// The IV provider receives object number, generation, and per-object IV index.
/// `skip_object_number` leaves the encryption dictionary unencrypted.
pub fn PdfDocument::aesv3_encrypt_parsed_objects_with_iv_provider(
  self : PdfDocument,
  file_key : BytesView,
  iv_provider : (Int, Int, Int) -> PdfBytes raise PdfError,
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
              pdf_aesv3_encrypt_pdf_object_with_iv_provider(
                file_key,
                object,
                fn(index) raise PdfError {
                  iv_provider(number, entry.generation, index)
                },
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
/// AESV3-decrypt all parsed objects in a copied document.
///
/// Parsed streams may retain deferred crypt metadata so stream bytes can be
/// decrypted lazily. `skip_object_number` leaves the encryption dictionary
/// untouched.
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
