///|
fn pdf_write_required_aes_iv_provider(
  provider : ((Int, Int, Int) -> @core.PdfBytes raise @core.PdfError)?,
) -> ((Int, Int, Int) -> @core.PdfBytes raise @core.PdfError) raise @core.PdfError {
  match provider {
    Some(provider) => provider
    None => raise RandomBytesUnavailable
  }
}

///|
fn pdf_write_required_aesv3_random_provider(
  provider : ((@crypt_core.PdfAesV3RandomField, Int) -> @core.PdfBytes raise @core.PdfError)?,
) -> ((@crypt_core.PdfAesV3RandomField, Int) -> @core.PdfBytes raise @core.PdfError) raise @core.PdfError {
  match provider {
    Some(provider) => provider
    None => raise RandomBytesUnavailable
  }
}

///|
fn pdf_write_apply_options_encryption(
  document : PdfDocument,
  encryption : @writer.PdfWriteEncryption,
  file_id : BytesView,
  aes_iv_provider : ((Int, Int, Int) -> @core.PdfBytes raise @core.PdfError)?,
  aesv3_random_provider : ((@crypt_core.PdfAesV3RandomField, Int) -> @core.PdfBytes raise @core.PdfError)?,
) -> PdfDocument raise @core.PdfError {
  match encryption.encryption_method {
    PdfEncryption40Bit =>
      document.encrypt_40bit(
        encryption.user_password,
        encryption.owner_password,
        encryption.denied_permissions,
        file_id~,
      )
    PdfEncryption128Bit =>
      document.encrypt_128bit(
        encryption.user_password,
        encryption.owner_password,
        encryption.denied_permissions,
        file_id~,
      )
    PdfEncryptionAES128(encrypt_metadata) => {
      let iv_provider = pdf_write_required_aes_iv_provider(aes_iv_provider)
      document.encrypt_128bit_aesv2_with_iv_provider(
        encryption.user_password,
        encryption.owner_password,
        encryption.denied_permissions,
        iv_provider,
        encrypt_metadata~,
        file_id~,
      )
    }
    PdfEncryptionAES256(encrypt_metadata) => {
      let random_provider = pdf_write_required_aesv3_random_provider(
        aesv3_random_provider,
      )
      let iv_provider = pdf_write_required_aes_iv_provider(aes_iv_provider)
      document.encrypt_256bit_aesv3_with_providers(
        encryption.user_password,
        encryption.owner_password,
        encryption.denied_permissions,
        random_provider,
        iv_provider,
        encrypt_metadata~,
        file_id~,
      )
    }
    PdfEncryptionAES256ISO(encrypt_metadata) => {
      let random_provider = pdf_write_required_aesv3_random_provider(
        aesv3_random_provider,
      )
      let iv_provider = pdf_write_required_aes_iv_provider(aes_iv_provider)
      document.encrypt_256bit_aesv3_iso_with_providers(
        encryption.user_password,
        encryption.owner_password,
        encryption.denied_permissions,
        random_provider,
        iv_provider,
        encrypt_metadata~,
        file_id~,
      )
    }
    PdfEncryptionAlreadyEncrypted => document.copy()
  }
}

///|
/// One-call writer with optional encryption, IDs, incremental update, and mode.
///
/// The input document is copied before IDs or encryption are applied.
/// `update_from` selects incremental output. `make_id` controls generated
/// trailer IDs for unencrypted writes; encrypted writes always use the provided
/// `file_id` or generate one through the encryption helper. AES modes require
/// the corresponding IV and random providers.
pub fn pdf_write_document_options(
  document : PdfDocument,
  encryption? : @writer.PdfWriteEncryption? = None,
  update_from? : @core.PdfBytes? = None,
  make_id? : Bool = true,
  id_path? : String = "",
  mode? : @writer.PdfWriteMode = PdfWriteClassic,
  file_id? : BytesView = [],
  aes_iv_provider? : ((Int, Int, Int) -> @core.PdfBytes raise @core.PdfError)? = None,
  aesv3_random_provider? : ((@crypt_core.PdfAesV3RandomField, Int) -> @core.PdfBytes raise @core.PdfError)? = None,
) -> @core.PdfBytes raise @core.PdfError {
  let prepared = match encryption {
    Some(encryption) =>
      pdf_write_apply_options_encryption(
        document, encryption, file_id, aes_iv_provider, aesv3_random_provider,
      )
    None =>
      if make_id {
        document.copy_with_current_id(id_path)
      } else {
        document.copy()
      }
  }
  match update_from {
    Some(original) =>
      pdf_write_document_incremental_update_with_mode(original, prepared, mode)
    None => pdf_write_document_with_mode(prepared, mode)
  }
}

///|
/// Encrypt with 40-bit ARC4 and serialize in the selected write mode.
pub fn pdf_write_encrypted_40bit_document(
  document : PdfDocument,
  user_password : BytesView,
  owner_password : BytesView,
  denied_permissions : ArrayView[@crypt_core.PdfPermission],
  mode? : @writer.PdfWriteMode = PdfWriteClassic,
  file_id? : BytesView = [],
) -> @core.PdfBytes raise @core.PdfError {
  pdf_write_document_with_mode(
    document.encrypt_40bit(
      user_password,
      owner_password,
      denied_permissions,
      file_id~,
    ),
    mode,
  )
}

///|
/// Encrypt with 128-bit ARC4 revision 3 and serialize in the selected mode.
pub fn pdf_write_encrypted_128bit_document(
  document : PdfDocument,
  user_password : BytesView,
  owner_password : BytesView,
  denied_permissions : ArrayView[@crypt_core.PdfPermission],
  mode? : @writer.PdfWriteMode = PdfWriteClassic,
  file_id? : BytesView = [],
) -> @core.PdfBytes raise @core.PdfError {
  pdf_write_document_with_mode(
    document.encrypt_128bit(
      user_password,
      owner_password,
      denied_permissions,
      file_id~,
    ),
    mode,
  )
}

///|
/// Encrypt with revision-4 ARC4 crypt filters and serialize.
///
/// `encrypt_metadata=false` follows the PDF revision-4 no-metadata behavior.
pub fn pdf_write_encrypted_128bit_r4_document(
  document : PdfDocument,
  user_password : BytesView,
  owner_password : BytesView,
  denied_permissions : ArrayView[@crypt_core.PdfPermission],
  encrypt_metadata? : Bool = true,
  mode? : @writer.PdfWriteMode = PdfWriteClassic,
  file_id? : BytesView = [],
) -> @core.PdfBytes raise @core.PdfError {
  pdf_write_document_with_mode(
    document.encrypt_128bit_r4(
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
/// Encrypt with AESV2 and serialize.
///
/// `iv_provider` supplies IVs by object number, generation, and per-object
/// index. This allows deterministic fixtures or secure caller-provided IVs.
pub fn pdf_write_encrypted_aesv2_document_with_iv_provider(
  document : PdfDocument,
  user_password : BytesView,
  owner_password : BytesView,
  denied_permissions : ArrayView[@crypt_core.PdfPermission],
  iv_provider : (Int, Int, Int) -> @core.PdfBytes raise @core.PdfError,
  encrypt_metadata? : Bool = true,
  mode? : @writer.PdfWriteMode = PdfWriteClassic,
  file_id? : BytesView = [],
) -> @core.PdfBytes raise @core.PdfError {
  pdf_write_document_with_mode(
    document.encrypt_128bit_aesv2_with_iv_provider(
      user_password,
      owner_password,
      denied_permissions,
      iv_provider,
      encrypt_metadata~,
      file_id~,
    ),
    mode,
  )
}

///|
/// Encrypt with AESV3/AES-256 and serialize.
///
/// `random_provider` supplies file keys, salts, and permissions padding;
/// `iv_provider` supplies object-data IVs. `iso=true` selects the ISO/PDF 2.0
/// AESV3 hash variant.
pub fn pdf_write_encrypted_aesv3_document_with_providers(
  document : PdfDocument,
  user_password : BytesView,
  owner_password : BytesView,
  denied_permissions : ArrayView[@crypt_core.PdfPermission],
  random_provider : (@crypt_core.PdfAesV3RandomField, Int) -> @core.PdfBytes raise @core.PdfError,
  iv_provider : (Int, Int, Int) -> @core.PdfBytes raise @core.PdfError,
  iso? : Bool = false,
  encrypt_metadata? : Bool = true,
  mode? : @writer.PdfWriteMode = PdfWriteClassic,
  file_id? : BytesView = [],
) -> @core.PdfBytes raise @core.PdfError {
  pdf_write_document_with_mode(
    document.encrypt_256bit_aesv3_with_providers(
      user_password,
      owner_password,
      denied_permissions,
      random_provider,
      iv_provider,
      iso~,
      encrypt_metadata~,
      file_id~,
    ),
    mode,
  )
}

///|
/// Encrypt with the ISO AESV3/AES-256 variant and serialize.
pub fn pdf_write_encrypted_aesv3_iso_document_with_providers(
  document : PdfDocument,
  user_password : BytesView,
  owner_password : BytesView,
  denied_permissions : ArrayView[@crypt_core.PdfPermission],
  random_provider : (@crypt_core.PdfAesV3RandomField, Int) -> @core.PdfBytes raise @core.PdfError,
  iv_provider : (Int, Int, Int) -> @core.PdfBytes raise @core.PdfError,
  encrypt_metadata? : Bool = true,
  mode? : @writer.PdfWriteMode = PdfWriteClassic,
  file_id? : BytesView = [],
) -> @core.PdfBytes raise @core.PdfError {
  pdf_write_encrypted_aesv3_document_with_providers(
    document,
    user_password,
    owner_password,
    denied_permissions,
    random_provider,
    iv_provider,
    iso=true,
    encrypt_metadata~,
    mode~,
    file_id~,
  )
}
