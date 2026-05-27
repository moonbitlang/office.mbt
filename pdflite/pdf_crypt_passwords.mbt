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
/// revisions use their respective standard-security algorithms.
#warnings("-unused_value")
fn PdfEncryptionValues::authenticate_user_password(
  self : PdfEncryptionValues,
  password : BytesView,
) -> Bool raise PdfError {
  let no_encrypt_metadata = self.effective_no_encrypt_metadata(false)
  match self.crypt_type {
    PdfCryptAESV3(iso) =>
      pdf_authenticate_user_password_aesv3(iso, password, self.user_entry)
    _ => {
      let (revision, key_length_bits) = self.password_settings()
      @crypt_core.pdf_authenticate_user_password(
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
fn PdfEncryptionValues::file_key_for_user_password(
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
      if @crypt_core.pdf_authenticate_user_password(
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
          @crypt_core.pdf_encryption_file_key(
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
#warnings("-unused_value")
fn PdfEncryptionValues::authenticate_owner_password(
  self : PdfEncryptionValues,
  password : BytesView,
) -> Bool raise PdfError {
  let no_encrypt_metadata = self.effective_no_encrypt_metadata(false)
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
      @crypt_core.pdf_authenticate_owner_password(
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
fn PdfEncryptionValues::file_key_for_owner_password(
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
      let user_password = @crypt_core.pdf_user_password_from_owner_password(
        revision,
        password,
        self.owner_entry,
        key_length_bits,
      )
      if @crypt_core.pdf_authenticate_user_password(
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
          @crypt_core.pdf_encryption_file_key(
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
