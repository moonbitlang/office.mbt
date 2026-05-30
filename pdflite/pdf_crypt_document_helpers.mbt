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
  @crypt_core.pdf_sha256_digest(
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
  field : @crypt_core.PdfAesV3RandomField,
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
) -> (@crypt_core.PdfAesV3RandomField, Int) -> PdfBytes raise PdfError {
  let owned_seed = seed.to_owned()
  fn(field, length) raise PdfError {
    pdf_deterministic_aesv3_random_for_seed(owned_seed, field, length)
  }
}
