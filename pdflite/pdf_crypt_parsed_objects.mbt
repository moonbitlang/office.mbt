///|
/// Apply ARC4 crypt to all parsed objects in a copied document.
///
/// `skip_object_number` is used to leave the encryption dictionary itself
/// unencrypted. Deferred and object-stream placeholders are left untouched.
fn PdfDocument::arc4_crypt_parsed_objects(
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
fn PdfDocument::aesv2_encrypt_parsed_objects_with_iv_provider(
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
fn PdfDocument::aesv2_decrypt_parsed_objects(
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
fn PdfDocument::aesv3_encrypt_parsed_objects_with_iv_provider(
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
fn PdfDocument::aesv3_decrypt_parsed_objects(
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
