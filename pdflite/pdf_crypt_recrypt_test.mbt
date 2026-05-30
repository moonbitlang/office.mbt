///|
fn crypt_recrypt_model_bytes_for_test(
  values : ArrayView[Int],
) -> @core.PdfBytes {
  try! @core.pdf_bytes_of_int_array(values)
}

///|
fn crypt_recrypt_bytes_start_with_at(
  haystack : @core.PdfBytes,
  needle : @core.PdfBytes,
  start : Int,
) -> Bool {
  if start < 0 || start + needle.length() > haystack.length() {
    false
  } else {
    for index in 0..<needle.length() {
      if haystack[start + index] != needle[index] {
        break false
      }
    } nobreak {
      true
    }
  }
}

///|
fn crypt_recrypt_bytes_contain_for_test(
  haystack : @core.PdfBytes,
  needle : @core.PdfBytes,
) -> Bool {
  if needle.length() == 0 {
    true
  } else if needle.length() > haystack.length() {
    false
  } else {
    for start in 0..<=(haystack.length() - needle.length()) {
      if crypt_recrypt_bytes_start_with_at(haystack, needle, start) {
        break true
      }
    } nobreak {
      false
    }
  }
}

///|
fn crypt_recrypt_aes_document_iv_for_test(
  object_number : Int,
  generation : Int,
  index : Int,
) -> @core.PdfBytes {
  crypt_recrypt_model_bytes_for_test(
    [
      for offset in 0..<16 => {
        (object_number * 17 + generation * 5 + index * 31 + offset) % 256
      }
    ],
  )
}

///|
fn crypt_recrypt_aesv3_r5_file_key_for_test() -> @core.PdfBytes {
  crypt_recrypt_model_bytes_for_test([ for value in 0..<32 => value ])
}

///|
#warnings("-unused_error_type")
fn crypt_recrypt_aesv3_r5_random_for_test(
  field : @crypt_core.PdfAesV3RandomField,
  _length : Int,
) -> @core.PdfBytes raise @core.PdfError {
  match field {
    PdfAesV3FileKey => crypt_recrypt_aesv3_r5_file_key_for_test()
    PdfAesV3UserValidationSalt =>
      crypt_recrypt_model_bytes_for_test([
        0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08,
      ])
    PdfAesV3UserKeySalt =>
      crypt_recrypt_model_bytes_for_test([
        0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f, 0x10,
      ])
    PdfAesV3OwnerValidationSalt =>
      crypt_recrypt_model_bytes_for_test([
        0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18,
      ])
    PdfAesV3OwnerKeySalt =>
      crypt_recrypt_model_bytes_for_test([
        0x19, 0x1a, 0x1b, 0x1c, 0x1d, 0x1e, 0x1f, 0x20,
      ])
    PdfAesV3PermissionsPadding => Bytes::new(4)
  }
}

///|
fn crypt_recrypt_aesv3_r5_document_with_object_for_test(
  major : Int,
  minor : Int,
  object_number : Int,
  object : @syntax.PdfObject,
  encrypt_metadata? : Bool = true,
) -> @pdflite.PdfDocument raise {
  let doc = crypt_recrypt_minimal_catalog_document_for_test(major, minor)
  doc.add_object_given_number(object_number, object)
  let encrypted = try! doc.encrypt_256bit_aesv3_with_providers(
    @ascii.encode("user"),
    @ascii.encode("owner"),
    @crypt_core.pdf_permissions_of_p(-3904),
    crypt_recrypt_aesv3_r5_random_for_test,
    fn(encrypted_object_number, generation, index) {
      crypt_recrypt_aes_document_iv_for_test(
        encrypted_object_number, generation, index,
      )
    },
    encrypt_metadata~,
    file_id=@ascii.encode("doc-id"),
  )
  let key_encrypt = crypt_recrypt_name_for_test("/Encrypt")
  guard encrypted.trailer_dict().lookup_immediate(key_encrypt)
    is Some(PdfIndirect(encrypt_number)) else {
    fail("expected indirect AESV3 encryption dictionary")
  }
  if encrypt_number != 9 {
    let encrypt_dictionary = encrypted.lookup_object_or_null(encrypt_number)
    encrypted.add_object_given_number(9, encrypt_dictionary)
    encrypted.remove_object(encrypt_number)
    encrypted.set_trailer_dict(
      encrypted.trailer_dict().add_dict_entry(key_encrypt, PdfIndirect(9)),
    )
  }
  encrypted
}

///|
fn crypt_recrypt_aesv3_r6_document_with_object_for_test(
  major : Int,
  minor : Int,
  object_number : Int,
  object : @syntax.PdfObject,
) -> @pdflite.PdfDocument raise {
  let doc = crypt_recrypt_minimal_catalog_document_for_test(major, minor)
  doc.add_object_given_number(object_number, object)
  doc.encrypt_256bit_aesv3_with_providers(
    @ascii.encode("user"),
    @ascii.encode("owner"),
    @crypt_core.pdf_permissions_of_p(-3904),
    crypt_recrypt_aesv3_r5_random_for_test,
    fn(object_number, generation, index) {
      crypt_recrypt_aes_document_iv_for_test(object_number, generation, index)
    },
    iso=true,
    file_id=@ascii.encode("doc-id"),
  )
}

///|
fn crypt_recrypt_name_for_test(text : String) -> @core.PdfName {
  @core.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn crypt_recrypt_minimal_catalog_document_for_test(
  major : Int,
  minor : Int,
) -> @pdflite.PdfDocument {
  let key_type = crypt_recrypt_name_for_test("/Type")
  let key_catalog = crypt_recrypt_name_for_test("/Catalog")
  let key_pages = crypt_recrypt_name_for_test("/Pages")
  let key_kids = crypt_recrypt_name_for_test("/Kids")
  let key_count = crypt_recrypt_name_for_test("/Count")
  let doc = @pdflite.pdf_document_empty()
  doc.set_version(major, minor)
  doc.set_root(1)
  doc.add_object_given_number(
    1,
    PdfDictionary([
      (key_type, PdfNameObject(key_catalog)),
      (key_pages, PdfIndirect(2)),
    ]),
  )
  doc.add_object_given_number(
    2,
    PdfDictionary([
      (key_type, PdfNameObject(key_pages)),
      (key_kids, PdfArray([])),
      (key_count, PdfInteger(0)),
    ]),
  )
  doc
}

///|
fn crypt_recrypt_stream_for_test(
  entries : ArrayView[(@core.PdfName, @syntax.PdfObject)],
  data : @core.PdfBytes,
) -> @syntax.PdfObject {
  PdfStreamObject({
    dictionary: PdfDictionary([ for entry in entries => entry ]),
    data: StreamGot(data),
  })
}

///|
fn crypt_recrypt_stream_object_bytes_for_test(
  stream : @syntax.PdfStream,
) -> @core.PdfBytes raise {
  @syntax.pdf_stream(stream.dictionary, stream.data).stream_bytes()
}

///|
fn crypt_recrypt_document_with_stream_for_test(
  major : Int,
  minor : Int,
  object_number : Int,
  data : @core.PdfBytes,
) -> @pdflite.PdfDocument {
  let doc = crypt_recrypt_minimal_catalog_document_for_test(major, minor)
  doc.add_object_given_number(
    object_number,
    crypt_recrypt_stream_for_test(
      [(crypt_recrypt_name_for_test("/Length"), PdfInteger(data.length()))],
      data,
    ),
  )
  doc
}

///|
fn crypt_recrypt_assert_deferred_stream_for_test(
  object : @syntax.PdfObject,
  expected_crypt : (@syntax.PdfStreamDataCrypt) -> Bool,
  expected_data : @core.PdfBytes,
) -> Unit raise {
  guard object is PdfStreamObject(stream) else {
    fail("expected stream object")
  }
  guard stream.data is StreamToGet(to_get) else {
    fail("expected deferred stream data")
  }
  if !expected_crypt(to_get.crypt()) {
    fail("unexpected deferred stream crypt state")
  }
  @test.assert_eq(
    @syntax.pdf_stream(stream.dictionary, stream.data).stream_bytes(),
    expected_data,
  )
  @test.assert_eq(
    crypt_recrypt_bytes_contain_for_test(
      @pdflite.pdf_write_object(
        @syntax.pdf_stream(stream.dictionary, stream.data),
      ),
      expected_data,
    ),
    true,
  )
  let forced = @syntax.pdf_stream(stream.dictionary, stream.data)
  forced.get_stream()
  guard forced is PdfStreamObject(forced_stream) else {
    fail("expected forced stream object")
  }
  guard forced_stream.data is StreamGot(forced_data) else {
    fail("expected materialized stream data")
  }
  @test.assert_eq(forced_data, expected_data)
  @test.assert_eq(
    forced_stream.dictionary.lookup_immediate(
      crypt_recrypt_name_for_test("/Length"),
    ),
    Some(PdfInteger(expected_data.length())),
  )
}

///|
fn crypt_recrypt_assert_equivalent_object_for_test(
  actual : @syntax.PdfObject,
  expected : @syntax.PdfObject,
) -> Unit raise {
  match (actual, expected) {
    (PdfStreamObject(actual), PdfStreamObject(expected)) => {
      @test.assert_eq(actual.dictionary, expected.dictionary)
      @test.assert_eq(
        crypt_recrypt_stream_object_bytes_for_test(actual),
        crypt_recrypt_stream_object_bytes_for_test(expected),
      )
    }
    _ => @test.assert_eq(actual, expected)
  }
}

///|
fn crypt_recrypt_unwrap_decryption_result_for_test(
  result : @pdflite.PdfDecryptionResult?,
) -> @pdflite.PdfDecryptionResult raise {
  match result {
    Some(value) => value
    None => fail("expected decrypted document")
  }
}

///|
test "PdfDocument recrypt_with_password restores saved ARC4 encryption" {
  let key_title = crypt_recrypt_name_for_test("/Title")
  let plain_object : @syntax.PdfObject = PdfDictionary([
    (key_title, PdfString(@ascii.encode("secret"))),
  ])
  let added_object : @syntax.PdfObject = PdfString(@ascii.encode("added"))
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(1, plain_object)
  let encrypted = try! doc.encrypt_128bit_r4(
    @ascii.encode("user"),
    @ascii.encode("owner"),
    [PdfNoPrint],
    encrypt_metadata=false,
    file_id=@ascii.encode("doc-id"),
  )
  let decrypted = crypt_recrypt_unwrap_decryption_result_for_test(
    try! encrypted.decrypt_with_user_password(@ascii.encode("user")),
  )
  decrypted.document.add_object_given_number(2, added_object)
  let recrypted = try! decrypted.document.recrypt_with_password(
    @ascii.encode("owner"),
  )
  @test.assert_eq(recrypted.is_encrypted(), true)
  let repeated_recrypt : Result[@pdflite.PdfDocument, Error] = try? recrypted.recrypt_with_password(
    @ascii.encode("owner"),
  )
  guard repeated_recrypt is Err(@core.PdfError::EncryptionSavedStateExpected) else {
    fail("expected consumed ARC4 saved encryption")
  }
  @test.assert_eq(try! recrypted.what_encryption(), Some(PdfEncryption128Bit))
  let roundtrip = crypt_recrypt_unwrap_decryption_result_for_test(
    try! recrypted.decrypt_with_user_password(@ascii.encode("user")),
  )
  @test.assert_eq(roundtrip.document.lookup_object_or_null(1), plain_object)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(2), added_object)
  @test.assert_eq(roundtrip.denied_permissions, [PdfNoPrint])

  let bad_password : Result[@pdflite.PdfDocument, Error] = try? decrypted.document.recrypt_with_password(
    @ascii.encode("bad"),
  )
  guard bad_password is Err(@core.PdfError::EncryptionRecryptFailed) else {
    fail("expected failed recrypt")
  }

  let no_saved : Result[@pdflite.PdfDocument, Error] = try? doc.recrypt_with_password(
    @ascii.encode("user"),
  )
  guard no_saved is Err(@core.PdfError::EncryptionSavedStateExpected) else {
    fail("expected missing saved encryption")
  }

  let aes_encrypted = try! doc.encrypt_128bit_aesv2_with_iv_provider(
    @ascii.encode("user"),
    @ascii.encode("owner"),
    [],
    fn(object_number, generation, index) {
      crypt_recrypt_aes_document_iv_for_test(object_number, generation, index)
    },
    file_id=@ascii.encode("doc-id"),
  )
  let aes_decrypted = crypt_recrypt_unwrap_decryption_result_for_test(
    try! aes_encrypted.decrypt_with_user_password(@ascii.encode("user")),
  )
  let unsupported : Result[@pdflite.PdfDocument, Error] = try? aes_decrypted.document.recrypt_with_password(
    @ascii.encode("user"),
  )
  guard unsupported is Err(@core.PdfError::EncryptionRecryptUnsupported(_)) else {
    fail("expected unsupported AES recrypt")
  }

  let arc4_128 = try! doc.encrypt_128bit(
    @ascii.encode("user"),
    @ascii.encode("owner"),
    [PdfNoCopy],
    file_id=@ascii.encode("doc-id"),
  )
  let arc4_128_decrypted = crypt_recrypt_unwrap_decryption_result_for_test(
    try! arc4_128.decrypt_with_user_password(@ascii.encode("user")),
  )
  let arc4_128_recrypted = try! arc4_128_decrypted.document.recrypt_with_password(
    @ascii.encode("user"),
  )
  @test.assert_eq(
    try! arc4_128_recrypted.what_encryption(),
    Some(PdfEncryption128Bit),
  )
  let arc4_128_roundtrip = crypt_recrypt_unwrap_decryption_result_for_test(
    try! arc4_128_recrypted.decrypt_with_user_password(@ascii.encode("user")),
  )
  @test.assert_eq(
    arc4_128_roundtrip.document.lookup_object_or_null(1),
    plain_object,
  )
  @test.assert_eq(arc4_128_roundtrip.denied_permissions, [PdfNoCopy])
}

///|
test "PdfDocument recrypt_with_password_aesv2_with_iv_provider restores saved AESV2 encryption" {
  let key_type = crypt_recrypt_name_for_test("/Type")
  let key_catalog = crypt_recrypt_name_for_test("/Catalog")
  let key_pages = crypt_recrypt_name_for_test("/Pages")
  let key_kids = crypt_recrypt_name_for_test("/Kids")
  let key_count = crypt_recrypt_name_for_test("/Count")
  let key_title = crypt_recrypt_name_for_test("/Title")
  let key_metadata = crypt_recrypt_name_for_test("/Metadata")
  let doc = @pdflite.pdf_document_empty()
  doc.set_version(1, 4)
  doc.set_root(1)
  doc.add_object_given_number(
    1,
    PdfDictionary([
      (key_type, PdfNameObject(key_catalog)),
      (key_pages, PdfIndirect(2)),
    ]),
  )
  doc.add_object_given_number(
    2,
    PdfDictionary([
      (key_type, PdfNameObject(key_pages)),
      (key_kids, PdfArray([])),
      (key_count, PdfInteger(0)),
    ]),
  )
  let secret_object : @syntax.PdfObject = PdfDictionary([
    (key_title, PdfString(@ascii.encode("aes-secret"))),
  ])
  let added_object : @syntax.PdfObject = PdfString(@ascii.encode("aes-added"))
  let metadata_stream = crypt_recrypt_stream_for_test(
    [
      (crypt_recrypt_name_for_test("/Length"), PdfInteger(4)),
      (key_type, PdfNameObject(key_metadata)),
      (key_title, PdfString(@ascii.encode("meta"))),
    ],
    @ascii.encode("data"),
  )
  doc.add_object_given_number(5, secret_object)
  doc.add_object_given_number(6, metadata_stream)
  let encrypted = try! doc.encrypt_128bit_aesv2_with_iv_provider(
    @ascii.encode("user"),
    @ascii.encode("owner"),
    [PdfNoPrint],
    fn(object_number, generation, index) {
      crypt_recrypt_aes_document_iv_for_test(object_number, generation, index)
    },
    encrypt_metadata=false,
    file_id=@ascii.encode("doc-id"),
  )
  let decrypted = crypt_recrypt_unwrap_decryption_result_for_test(
    try! encrypted.decrypt_with_user_password(@ascii.encode("user")),
  )
  decrypted.document.add_object_given_number(7, added_object)
  let recrypted = try! decrypted.document.recrypt_with_password_aesv2_with_iv_provider(
    @ascii.encode("owner"),
    fn(object_number, generation, index) {
      crypt_recrypt_aes_document_iv_for_test(
        object_number,
        generation,
        index + 4,
      )
    },
  )
  @test.assert_eq(recrypted.is_encrypted(), true)
  let repeated_recrypt : Result[@pdflite.PdfDocument, Error] = try? recrypted.recrypt_with_password_aesv2_with_iv_provider(
    @ascii.encode("owner"),
    fn(object_number, generation, index) {
      crypt_recrypt_aes_document_iv_for_test(
        object_number,
        generation,
        index + 8,
      )
    },
  )
  guard repeated_recrypt is Err(@core.PdfError::EncryptionSavedStateExpected) else {
    fail("expected consumed AESV2 saved encryption")
  }
  @test.assert_eq(
    try! recrypted.what_encryption(),
    Some(PdfEncryptionAES128(false)),
  )
  let roundtrip = crypt_recrypt_unwrap_decryption_result_for_test(
    try! recrypted.decrypt_with_user_password(@ascii.encode("user")),
  )
  @test.assert_eq(roundtrip.document.lookup_object_or_null(5), secret_object)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(6), metadata_stream)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(7), added_object)
  @test.assert_eq(roundtrip.denied_permissions, [PdfNoPrint])

  let rendered = try! @pdflite.pdf_write_document(recrypted)
  let parsed = try! @pdflite.pdf_read_document_from_bytes(rendered)
  let read_decrypted = crypt_recrypt_unwrap_decryption_result_for_test(
    try! parsed.decrypt_with_owner_password(@ascii.encode("owner")),
  )
  @test.assert_eq(
    read_decrypted.document.lookup_object_or_null(5),
    secret_object,
  )
  try! crypt_recrypt_assert_equivalent_object_for_test(
    read_decrypted.document.lookup_object_or_null(6),
    metadata_stream,
  )
  @test.assert_eq(
    read_decrypted.document.lookup_object_or_null(7),
    added_object,
  )

  let bad_password : Result[@pdflite.PdfDocument, Error] = try? decrypted.document.recrypt_with_password_aesv2_with_iv_provider(
    @ascii.encode("bad"),
    fn(object_number, generation, index) {
      crypt_recrypt_aes_document_iv_for_test(object_number, generation, index)
    },
  )
  guard bad_password is Err(@core.PdfError::EncryptionRecryptFailed) else {
    fail("expected failed AESV2 recrypt")
  }

  let no_saved : Result[@pdflite.PdfDocument, Error] = try? doc.recrypt_with_password_aesv2_with_iv_provider(
    @ascii.encode("user"),
    fn(object_number, generation, index) {
      crypt_recrypt_aes_document_iv_for_test(object_number, generation, index)
    },
  )
  guard no_saved is Err(@core.PdfError::EncryptionSavedStateExpected) else {
    fail("expected missing saved encryption")
  }

  let arc4 = try! doc.encrypt_40bit(
    @ascii.encode("user"),
    @ascii.encode("owner"),
    [],
    file_id=@ascii.encode("doc-id"),
  )
  let arc4_decrypted = crypt_recrypt_unwrap_decryption_result_for_test(
    try! arc4.decrypt_with_user_password(@ascii.encode("user")),
  )
  let unsupported : Result[@pdflite.PdfDocument, Error] = try? arc4_decrypted.document.recrypt_with_password_aesv2_with_iv_provider(
    @ascii.encode("user"),
    fn(object_number, generation, index) {
      crypt_recrypt_aes_document_iv_for_test(object_number, generation, index)
    },
  )
  guard unsupported is Err(@core.PdfError::EncryptionRecryptUnsupported(_)) else {
    fail("expected unsupported non-AESV2 recrypt")
  }
}

///|
test "PdfDocument recrypt_with_password_aesv3_with_iv_provider restores saved AESV3 revision 5 encryption" {
  let key_title = crypt_recrypt_name_for_test("/Title")
  let key_metadata = crypt_recrypt_name_for_test("/Metadata")
  let original_secret : @syntax.PdfObject = PdfDictionary([
    (key_title, PdfString(@ascii.encode("aes3-original"))),
  ])
  let updated_secret : @syntax.PdfObject = PdfDictionary([
    (key_title, PdfString(@ascii.encode("aes3-updated"))),
  ])
  let added_object : @syntax.PdfObject = PdfString(@ascii.encode("aes3-added"))
  let metadata_stream = crypt_recrypt_stream_for_test(
    [
      (crypt_recrypt_name_for_test("/Length"), PdfInteger(4)),
      (crypt_recrypt_name_for_test("/Type"), PdfNameObject(key_metadata)),
      (key_title, PdfString(@ascii.encode("meta"))),
    ],
    @ascii.encode("data"),
  )
  let doc = try! crypt_recrypt_aesv3_r5_document_with_object_for_test(
    1,
    7,
    5,
    original_secret,
    encrypt_metadata=false,
  )
  doc.add_object_given_number(6, metadata_stream)

  let decrypted = crypt_recrypt_unwrap_decryption_result_for_test(
    try! doc.decrypt_with_user_password(@ascii.encode("user")),
  )
  @test.assert_eq(decrypted.document.lookup_object_or_null(5), original_secret)
  @test.assert_eq(decrypted.document.lookup_object_or_null(6), metadata_stream)
  decrypted.document.add_object_given_number(5, updated_secret)
  decrypted.document.add_object_given_number(7, added_object)
  let recrypted = try! decrypted.document.recrypt_with_password_aesv3_with_iv_provider(
    @ascii.encode("owner"),
    fn(object_number, generation, index) {
      crypt_recrypt_aes_document_iv_for_test(
        object_number,
        generation,
        index + 2,
      )
    },
  )
  @test.assert_eq(recrypted.is_encrypted(), true)
  let repeated_recrypt : Result[@pdflite.PdfDocument, Error] = try? recrypted.recrypt_with_password_aesv3_with_iv_provider(
    @ascii.encode("owner"),
    fn(object_number, generation, index) {
      crypt_recrypt_aes_document_iv_for_test(
        object_number,
        generation,
        index + 6,
      )
    },
  )
  guard repeated_recrypt is Err(@core.PdfError::EncryptionSavedStateExpected) else {
    fail("expected consumed AESV3 saved encryption")
  }
  @test.assert_eq(
    try! recrypted.what_encryption(),
    Some(PdfEncryptionAES256(false)),
  )
  let roundtrip = crypt_recrypt_unwrap_decryption_result_for_test(
    try! recrypted.decrypt_with_user_password(@ascii.encode("user")),
  )
  @test.assert_eq(roundtrip.document.lookup_object_or_null(5), updated_secret)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(6), metadata_stream)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(7), added_object)
  @test.assert_eq(
    roundtrip.denied_permissions,
    @crypt_core.pdf_permissions_of_p(-3904),
  )

  let rendered = try! @pdflite.pdf_write_document(recrypted)
  let parsed = try! @pdflite.pdf_read_document_from_bytes(rendered)
  let read_decrypted = crypt_recrypt_unwrap_decryption_result_for_test(
    try! parsed.decrypt_with_owner_password(@ascii.encode("owner")),
  )
  @test.assert_eq(
    read_decrypted.document.lookup_object_or_null(5),
    updated_secret,
  )
  try! crypt_recrypt_assert_equivalent_object_for_test(
    read_decrypted.document.lookup_object_or_null(6),
    metadata_stream,
  )
  @test.assert_eq(
    read_decrypted.document.lookup_object_or_null(7),
    added_object,
  )

  let bad_password : Result[@pdflite.PdfDocument, Error] = try? decrypted.document.recrypt_with_password_aesv3_with_iv_provider(
    @ascii.encode("bad"),
    fn(object_number, generation, index) {
      crypt_recrypt_aes_document_iv_for_test(object_number, generation, index)
    },
  )
  guard bad_password is Err(@core.PdfError::EncryptionRecryptFailed) else {
    fail("expected failed AESV3 recrypt")
  }

  let no_saved : Result[@pdflite.PdfDocument, Error] = try? crypt_recrypt_minimal_catalog_document_for_test(
    1, 7,
  ).recrypt_with_password_aesv3_with_iv_provider(@ascii.encode("user"), fn(
    object_number,
    generation,
    index,
  ) {
    crypt_recrypt_aes_document_iv_for_test(object_number, generation, index)
  })
  guard no_saved is Err(@core.PdfError::EncryptionSavedStateExpected) else {
    fail("expected missing AESV3 saved encryption")
  }

  let wrong_plain = crypt_recrypt_minimal_catalog_document_for_test(1, 7)
  let wrong_encrypted = try! wrong_plain.encrypt_128bit_aesv2_with_iv_provider(
    @ascii.encode("user"),
    @ascii.encode("owner"),
    [],
    fn(object_number, generation, index) {
      crypt_recrypt_aes_document_iv_for_test(object_number, generation, index)
    },
    file_id=@ascii.encode("doc-id"),
  )
  let wrong_decrypted = crypt_recrypt_unwrap_decryption_result_for_test(
    try! wrong_encrypted.decrypt_with_user_password(@ascii.encode("user")),
  )
  let wrong_method : Result[@pdflite.PdfDocument, Error] = try? wrong_decrypted.document.recrypt_with_password_aesv3_with_iv_provider(
    @ascii.encode("user"),
    fn(object_number, generation, index) {
      crypt_recrypt_aes_document_iv_for_test(object_number, generation, index)
    },
  )
  guard wrong_method is Err(@core.PdfError::EncryptionRecryptUnsupported(_)) else {
    fail("expected non-AESV3 saved encryption rejection")
  }
}

///|
test "PdfDocument recrypt_with_password_aesv3_with_iv_provider supports AESV3 revision 6" {
  let key_title = crypt_recrypt_name_for_test("/Title")
  let original_secret : @syntax.PdfObject = PdfDictionary([
    (key_title, PdfString(@ascii.encode("aes3-r6-original"))),
  ])
  let updated_secret : @syntax.PdfObject = PdfDictionary([
    (key_title, PdfString(@ascii.encode("aes3-r6-updated"))),
  ])
  let doc = crypt_recrypt_minimal_catalog_document_for_test(1, 7)
  doc.add_object_given_number(5, original_secret)
  let encrypted = try! doc.encrypt_256bit_aesv3_with_providers(
    @ascii.encode("user"),
    @ascii.encode("owner"),
    @crypt_core.pdf_permissions_of_p(-3904),
    crypt_recrypt_aesv3_r5_random_for_test,
    fn(object_number, generation, index) {
      crypt_recrypt_aes_document_iv_for_test(object_number, generation, index)
    },
    iso=true,
    encrypt_metadata=false,
    file_id=@ascii.encode("doc-id"),
  )
  @test.assert_eq(
    try! encrypted.what_encryption(),
    Some(PdfEncryptionAES256ISO(false)),
  )
  let decrypted = crypt_recrypt_unwrap_decryption_result_for_test(
    try! encrypted.decrypt_with_owner_password(@ascii.encode("owner")),
  )
  @test.assert_eq(decrypted.document.lookup_object_or_null(5), original_secret)
  decrypted.document.add_object_given_number(5, updated_secret)
  let recrypted = try! decrypted.document.recrypt_with_password_aesv3_with_iv_provider(
    @ascii.encode("user"),
    fn(object_number, generation, index) {
      crypt_recrypt_aes_document_iv_for_test(
        object_number,
        generation,
        index + 3,
      )
    },
  )
  @test.assert_eq(
    try! recrypted.what_encryption(),
    Some(PdfEncryptionAES256ISO(false)),
  )
  let roundtrip = crypt_recrypt_unwrap_decryption_result_for_test(
    try! recrypted.decrypt_with_user_password(@ascii.encode("user")),
  )
  @test.assert_eq(roundtrip.document.lookup_object_or_null(5), updated_secret)
  let rendered = try! @pdflite.pdf_write_document(recrypted)
  let parsed = try! @pdflite.pdf_read_document_from_bytes(rendered)
  let read_decrypted = crypt_recrypt_unwrap_decryption_result_for_test(
    try! parsed.decrypt_with_owner_password(@ascii.encode("owner")),
  )
  @test.assert_eq(
    read_decrypted.document.lookup_object_or_null(5),
    updated_secret,
  )
}

///|
test "PdfDocument encrypt_256bit_aesv3_iso_with_providers mirrors ISO AESV3 option" {
  let key_title = crypt_recrypt_name_for_test("/Title")
  let doc = crypt_recrypt_minimal_catalog_document_for_test(1, 7)
  let secret_object : @syntax.PdfObject = PdfDictionary([
    (key_title, PdfString(@ascii.encode("aes3-iso-secret"))),
  ])
  doc.add_object_given_number(5, secret_object)
  let denied_permissions = @crypt_core.pdf_permissions_of_p(-3904)
  let encrypted = try! doc.encrypt_256bit_aesv3_iso_with_providers(
    @ascii.encode("user"),
    @ascii.encode("owner"),
    denied_permissions,
    crypt_recrypt_aesv3_r5_random_for_test,
    fn(object_number, generation, index) {
      crypt_recrypt_aes_document_iv_for_test(object_number, generation, index)
    },
    encrypt_metadata=false,
    file_id=@ascii.encode("doc-id"),
  )
  @test.assert_eq(
    try! encrypted.what_encryption(),
    Some(PdfEncryptionAES256ISO(false)),
  )
  let decrypted = crypt_recrypt_unwrap_decryption_result_for_test(
    try! encrypted.decrypt_with_user_password(@ascii.encode("user")),
  )
  @test.assert_eq(decrypted.document.lookup_object_or_null(5), secret_object)
  @test.assert_eq(decrypted.denied_permissions, denied_permissions)

  let encrypted_stream = encrypted.lookup_object_or_null(5)
  let single_stream = try! encrypted.decrypt_single_stream(
    5,
    0,
    encrypted_stream,
    owner_password=Some(@ascii.encode("owner")),
  )
  @test.assert_eq(single_stream, Some(secret_object))
}

///|
test "PdfDocument password reader keeps parsed encrypted streams deferred" {
  let object_number = 5

  let arc4_plain = @ascii.encode("lazy arc4 stream")
  let arc4_doc = crypt_recrypt_document_with_stream_for_test(
    1, 4, object_number, arc4_plain,
  )
  let arc4_encrypted = arc4_doc.encrypt_40bit(
    @ascii.encode("user"),
    @ascii.encode("owner"),
    [PdfNoPrint],
    file_id=@ascii.encode("arc4-id"),
  )
  let arc4_rendered = @pdflite.pdf_write_document(arc4_encrypted)
  let arc4_decrypted = crypt_recrypt_unwrap_decryption_result_for_test(
    @pdflite.pdf_read_document_from_bytes_with_passwords(
      arc4_rendered,
      user_password=Some(@ascii.encode("user")),
    ),
  )
  crypt_recrypt_assert_deferred_stream_for_test(
    arc4_decrypted.document.lookup_object_or_null(object_number),
    fn(crypt) { crypt is PdfStreamDataArc4Decrypt(_, _, _, _) },
    arc4_plain,
  )
  let arc4_copy = arc4_decrypted.document.copy()
  crypt_recrypt_assert_deferred_stream_for_test(
    arc4_copy.lookup_object_or_null(object_number),
    fn(crypt) { crypt is PdfStreamDataArc4Decrypt(_, _, _, _) },
    arc4_plain,
  )

  let aesv2_plain = @ascii.encode("lazy aesv2 stream")
  let aesv2_doc = crypt_recrypt_document_with_stream_for_test(
    1, 5, object_number, aesv2_plain,
  )
  let aesv2_encrypted = aesv2_doc.encrypt_128bit_aesv2_with_iv_provider(
    @ascii.encode("user"),
    @ascii.encode("owner"),
    [PdfNoExtract],
    fn(object_number, generation, index) {
      crypt_recrypt_aes_document_iv_for_test(object_number, generation, index)
    },
    file_id=@ascii.encode("aesv2-id"),
  )
  let aesv2_rendered = @pdflite.pdf_write_document(aesv2_encrypted)
  let aesv2_decrypted = crypt_recrypt_unwrap_decryption_result_for_test(
    @pdflite.pdf_read_document_from_bytes_with_passwords(
      aesv2_rendered,
      user_password=Some(@ascii.encode("user")),
    ),
  )
  crypt_recrypt_assert_deferred_stream_for_test(
    aesv2_decrypted.document.lookup_object_or_null(object_number),
    fn(crypt) { crypt is PdfStreamDataAesV2Decrypt(_, _, _, _) },
    aesv2_plain,
  )

  let aesv3_plain = @ascii.encode("lazy aesv3 stream")
  let aesv3_doc = crypt_recrypt_document_with_stream_for_test(
    1, 7, object_number, aesv3_plain,
  )
  let aesv3_encrypted = aesv3_doc.encrypt_256bit_aesv3_with_providers(
    @ascii.encode("user"),
    @ascii.encode("owner"),
    [PdfNoCopy],
    crypt_recrypt_aesv3_r5_random_for_test,
    fn(object_number, generation, index) {
      crypt_recrypt_aes_document_iv_for_test(object_number, generation, index)
    },
    file_id=@ascii.encode("aesv3-id"),
  )
  let aesv3_rendered = @pdflite.pdf_write_document(aesv3_encrypted)
  let aesv3_decrypted = crypt_recrypt_unwrap_decryption_result_for_test(
    @pdflite.pdf_read_document_from_bytes_with_passwords(
      aesv3_rendered,
      user_password=Some(@ascii.encode("user")),
    ),
  )
  crypt_recrypt_assert_deferred_stream_for_test(
    aesv3_decrypted.document.lookup_object_or_null(object_number),
    fn(crypt) { crypt is PdfStreamDataAesV3Decrypt(_) },
    aesv3_plain,
  )
}

///|
test "PdfDocument AESV3 revision 6 recrypt supports incremental updates" {
  let key_title = crypt_recrypt_name_for_test("/Title")
  let original_secret : @syntax.PdfObject = PdfDictionary([
    (key_title, PdfString(@ascii.encode("aes3-r6-inc-original"))),
  ])
  let updated_secret : @syntax.PdfObject = PdfDictionary([
    (key_title, PdfString(@ascii.encode("aes3-r6-inc-updated"))),
  ])
  let added_object : @syntax.PdfObject = PdfString(
    @ascii.encode("aes3-r6-inc-added"),
  )
  let doc = try! crypt_recrypt_aesv3_r6_document_with_object_for_test(
    1, 7, 5, original_secret,
  )
  let original = try! @pdflite.pdf_write_document(doc)
  let decrypted = crypt_recrypt_unwrap_decryption_result_for_test(
    try! @pdflite.pdf_read_document_from_bytes_with_passwords(
      original,
      user_password=Some(@ascii.encode("user")),
    ),
  )
  @test.assert_eq(decrypted.document.lookup_object_or_null(5), original_secret)
  decrypted.document.add_object_given_number(5, updated_secret)
  decrypted.document.add_object_given_number(8, added_object)
  let recrypted = try! decrypted.document.recrypt_with_password_aesv3_with_iv_provider(
    @ascii.encode("owner"),
    fn(object_number, generation, index) {
      crypt_recrypt_aes_document_iv_for_test(
        object_number,
        generation,
        index + 9,
      )
    },
  )
  let classic = try! @pdflite.pdf_write_document_incremental_update(
    original, recrypted,
  )
  let classic_roundtrip = crypt_recrypt_unwrap_decryption_result_for_test(
    try! @pdflite.pdf_read_document_from_bytes_with_passwords(
      classic,
      owner_password=Some(@ascii.encode("owner")),
    ),
  )
  @test.assert_eq(
    classic_roundtrip.document.lookup_object_or_null(5),
    updated_secret,
  )
  @test.assert_eq(
    classic_roundtrip.document.lookup_object_or_null(8),
    added_object,
  )

  let xref_original = try! @pdflite.pdf_write_document_with_xref_stream(doc)
  let xref_decrypted = crypt_recrypt_unwrap_decryption_result_for_test(
    try! @pdflite.pdf_read_document_from_bytes_with_passwords(
      xref_original,
      user_password=Some(@ascii.encode("user")),
    ),
  )
  xref_decrypted.document.add_object_given_number(5, updated_secret)
  xref_decrypted.document.add_object_given_number(8, added_object)
  let xref_recrypted = try! xref_decrypted.document.recrypt_with_password_aesv3_with_iv_provider(
    @ascii.encode("owner"),
    fn(object_number, generation, index) {
      crypt_recrypt_aes_document_iv_for_test(
        object_number,
        generation,
        index + 10,
      )
    },
  )
  let xref = try! @pdflite.pdf_write_document_incremental_update_with_xref_stream(
    xref_original, xref_recrypted,
  )
  @test.assert_eq(
    crypt_recrypt_bytes_start_with_at(xref, xref_original, 0),
    true,
  )
  let xref_roundtrip = crypt_recrypt_unwrap_decryption_result_for_test(
    try! @pdflite.pdf_read_document_from_bytes_with_passwords(
      xref,
      user_password=Some(@ascii.encode("user")),
    ),
  )
  @test.assert_eq(
    xref_roundtrip.document.lookup_object_or_null(5),
    updated_secret,
  )
  @test.assert_eq(
    xref_roundtrip.document.lookup_object_or_null(8),
    added_object,
  )

  let compressed = try! @pdflite.pdf_write_document_incremental_update_with_compressed_xref_stream(
    xref_original, xref_recrypted,
  )
  @test.assert_eq(
    crypt_recrypt_bytes_start_with_at(compressed, xref_original, 0),
    true,
  )
  let compressed_roundtrip = crypt_recrypt_unwrap_decryption_result_for_test(
    try! @pdflite.pdf_read_document_from_bytes_with_passwords(
      compressed,
      owner_password=Some(@ascii.encode("owner")),
    ),
  )
  @test.assert_eq(
    compressed_roundtrip.document.lookup_object_or_null(5),
    updated_secret,
  )
  @test.assert_eq(
    compressed_roundtrip.document.lookup_object_or_null(8),
    added_object,
  )
}

///|
test "PdfDocument AESV3 recrypt supports xref stream incremental updates" {
  let key_title = crypt_recrypt_name_for_test("/Title")
  let original_secret : @syntax.PdfObject = PdfDictionary([
    (key_title, PdfString(@ascii.encode("aes3-xref-original"))),
  ])
  let updated_secret : @syntax.PdfObject = PdfDictionary([
    (key_title, PdfString(@ascii.encode("aes3-xref-updated"))),
  ])
  let added_object : @syntax.PdfObject = PdfString(
    @ascii.encode("aes3-xref-added"),
  )
  let doc = try! crypt_recrypt_aesv3_r5_document_with_object_for_test(
    1, 7, 5, original_secret,
  )
  let original = try! @pdflite.pdf_write_document_with_xref_stream(doc)
  let decrypted = crypt_recrypt_unwrap_decryption_result_for_test(
    try! @pdflite.pdf_read_document_from_bytes_with_passwords(
      original,
      user_password=Some(@ascii.encode("user")),
    ),
  )
  @test.assert_eq(decrypted.document.lookup_object_or_null(5), original_secret)
  decrypted.document.add_object_given_number(5, updated_secret)
  decrypted.document.add_object_given_number(8, added_object)
  let recrypted = try! decrypted.document.recrypt_with_password_aesv3_with_iv_provider(
    @ascii.encode("owner"),
    fn(object_number, generation, index) {
      crypt_recrypt_aes_document_iv_for_test(
        object_number,
        generation,
        index + 7,
      )
    },
  )

  let rendered = try! @pdflite.pdf_write_document_incremental_update_with_xref_stream(
    original, recrypted,
  )
  @test.assert_eq(
    crypt_recrypt_bytes_start_with_at(rendered, original, 0),
    true,
  )
  let roundtrip = crypt_recrypt_unwrap_decryption_result_for_test(
    try! @pdflite.pdf_read_document_from_bytes_with_passwords(
      rendered,
      user_password=Some(@ascii.encode("user")),
    ),
  )
  @test.assert_eq(roundtrip.document.lookup_object_or_null(5), updated_secret)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(8), added_object)
  @test.assert_eq(
    roundtrip.denied_permissions,
    @crypt_core.pdf_permissions_of_p(-3904),
  )

  let compressed = try! @pdflite.pdf_write_document_incremental_update_with_compressed_xref_stream(
    original, recrypted,
  )
  @test.assert_eq(
    crypt_recrypt_bytes_start_with_at(compressed, original, 0),
    true,
  )
  let compressed_roundtrip = crypt_recrypt_unwrap_decryption_result_for_test(
    try! @pdflite.pdf_read_document_from_bytes_with_passwords(
      compressed,
      owner_password=Some(@ascii.encode("owner")),
    ),
  )
  @test.assert_eq(
    compressed_roundtrip.document.lookup_object_or_null(5),
    updated_secret,
  )
  @test.assert_eq(
    compressed_roundtrip.document.lookup_object_or_null(8),
    added_object,
  )
  @test.assert_eq(
    compressed_roundtrip.denied_permissions,
    @crypt_core.pdf_permissions_of_p(-3904),
  )
}

///|
test "PdfDocument AESV3 recrypt supports classic incremental update" {
  let key_title = crypt_recrypt_name_for_test("/Title")
  let original_secret : @syntax.PdfObject = PdfDictionary([
    (key_title, PdfString(@ascii.encode("aes3-classic-original"))),
  ])
  let updated_secret : @syntax.PdfObject = PdfDictionary([
    (key_title, PdfString(@ascii.encode("aes3-classic-updated"))),
  ])
  let added_object : @syntax.PdfObject = PdfString(
    @ascii.encode("aes3-classic-added"),
  )
  let doc = try! crypt_recrypt_aesv3_r5_document_with_object_for_test(
    1, 7, 5, original_secret,
  )
  let original = try! @pdflite.pdf_write_document(doc)
  let decrypted = crypt_recrypt_unwrap_decryption_result_for_test(
    try! @pdflite.pdf_read_document_from_bytes_with_passwords(
      original,
      user_password=Some(@ascii.encode("user")),
    ),
  )
  @test.assert_eq(decrypted.document.lookup_object_or_null(5), original_secret)
  decrypted.document.add_object_given_number(5, updated_secret)
  decrypted.document.add_object_given_number(8, added_object)
  let recrypted = try! decrypted.document.recrypt_with_password_aesv3_with_iv_provider(
    @ascii.encode("user"),
    fn(object_number, generation, index) {
      crypt_recrypt_aes_document_iv_for_test(
        object_number,
        generation,
        index + 8,
      )
    },
  )

  let rendered = try! @pdflite.pdf_write_document_incremental_update(
    original, recrypted,
  )
  @test.assert_eq(
    crypt_recrypt_bytes_start_with_at(rendered, original, 0),
    true,
  )
  let roundtrip = crypt_recrypt_unwrap_decryption_result_for_test(
    try! @pdflite.pdf_read_document_from_bytes_with_passwords(
      rendered,
      owner_password=Some(@ascii.encode("owner")),
    ),
  )
  @test.assert_eq(roundtrip.document.lookup_object_or_null(5), updated_secret)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(8), added_object)
  @test.assert_eq(
    roundtrip.denied_permissions,
    @crypt_core.pdf_permissions_of_p(-3904),
  )
}

///|
test "PdfDocument AESV2 recrypt supports xref stream incremental updates" {
  let key_title = crypt_recrypt_name_for_test("/Title")
  let doc = crypt_recrypt_minimal_catalog_document_for_test(1, 5)
  let original_secret : @syntax.PdfObject = PdfDictionary([
    (key_title, PdfString(@ascii.encode("aes-original"))),
  ])
  let updated_secret : @syntax.PdfObject = PdfDictionary([
    (key_title, PdfString(@ascii.encode("aes-updated"))),
  ])
  let added_object : @syntax.PdfObject = PdfString(
    @ascii.encode("aes-added-incremental"),
  )
  doc.add_object_given_number(5, original_secret)
  let encrypted = try! doc.encrypt_128bit_aesv2_with_iv_provider(
    @ascii.encode("user"),
    @ascii.encode("owner"),
    [PdfNoExtract],
    fn(object_number, generation, index) {
      crypt_recrypt_aes_document_iv_for_test(object_number, generation, index)
    },
    encrypt_metadata=true,
    file_id=@ascii.encode("doc-id"),
  )
  let original = try! @pdflite.pdf_write_document_with_xref_stream(encrypted)
  let decrypted = crypt_recrypt_unwrap_decryption_result_for_test(
    try! @pdflite.pdf_read_document_from_bytes_with_passwords(
      original,
      user_password=Some(@ascii.encode("user")),
    ),
  )
  @test.assert_eq(decrypted.document.lookup_object_or_null(5), original_secret)
  decrypted.document.add_object_given_number(5, updated_secret)
  decrypted.document.add_object_given_number(8, added_object)
  let recrypted = try! decrypted.document.recrypt_with_password_aesv2_with_iv_provider(
    @ascii.encode("owner"),
    fn(object_number, generation, index) {
      crypt_recrypt_aes_document_iv_for_test(
        object_number,
        generation,
        index + 6,
      )
    },
  )

  let rendered = try! @pdflite.pdf_write_document_incremental_update_with_xref_stream(
    original, recrypted,
  )
  @test.assert_eq(
    crypt_recrypt_bytes_start_with_at(rendered, original, 0),
    true,
  )
  let roundtrip = crypt_recrypt_unwrap_decryption_result_for_test(
    try! @pdflite.pdf_read_document_from_bytes_with_passwords(
      rendered,
      user_password=Some(@ascii.encode("user")),
    ),
  )
  @test.assert_eq(roundtrip.document.lookup_object_or_null(5), updated_secret)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(8), added_object)
  @test.assert_eq(roundtrip.denied_permissions, [PdfNoExtract])

  let compressed = try! @pdflite.pdf_write_document_incremental_update_with_compressed_xref_stream(
    original, recrypted,
  )
  @test.assert_eq(
    crypt_recrypt_bytes_start_with_at(compressed, original, 0),
    true,
  )
  let compressed_roundtrip = crypt_recrypt_unwrap_decryption_result_for_test(
    try! @pdflite.pdf_read_document_from_bytes_with_passwords(
      compressed,
      owner_password=Some(@ascii.encode("owner")),
    ),
  )
  @test.assert_eq(
    compressed_roundtrip.document.lookup_object_or_null(5),
    updated_secret,
  )
  @test.assert_eq(
    compressed_roundtrip.document.lookup_object_or_null(8),
    added_object,
  )
  @test.assert_eq(compressed_roundtrip.denied_permissions, [PdfNoExtract])
}

///|
test "PdfDocument AESV2 recrypt supports classic incremental update" {
  let key_title = crypt_recrypt_name_for_test("/Title")
  let doc = crypt_recrypt_minimal_catalog_document_for_test(1, 4)
  let original_secret : @syntax.PdfObject = PdfDictionary([
    (key_title, PdfString(@ascii.encode("aes-classic-original"))),
  ])
  let updated_secret : @syntax.PdfObject = PdfDictionary([
    (key_title, PdfString(@ascii.encode("aes-classic-updated"))),
  ])
  let added_object : @syntax.PdfObject = PdfString(
    @ascii.encode("aes-classic-added"),
  )
  doc.add_object_given_number(5, original_secret)
  let encrypted = try! doc.encrypt_128bit_aesv2_with_iv_provider(
    @ascii.encode("user"),
    @ascii.encode("owner"),
    [PdfNoForms],
    fn(object_number, generation, index) {
      crypt_recrypt_aes_document_iv_for_test(object_number, generation, index)
    },
    encrypt_metadata=true,
    file_id=@ascii.encode("doc-id"),
  )
  let original = try! @pdflite.pdf_write_document(encrypted)
  let decrypted = crypt_recrypt_unwrap_decryption_result_for_test(
    try! @pdflite.pdf_read_document_from_bytes_with_passwords(
      original,
      owner_password=Some(@ascii.encode("owner")),
    ),
  )
  @test.assert_eq(decrypted.document.lookup_object_or_null(5), original_secret)
  decrypted.document.add_object_given_number(5, updated_secret)
  decrypted.document.add_object_given_number(8, added_object)
  let recrypted = try! decrypted.document.recrypt_with_password_aesv2_with_iv_provider(
    @ascii.encode("user"),
    fn(object_number, generation, index) {
      crypt_recrypt_aes_document_iv_for_test(
        object_number,
        generation,
        index + 9,
      )
    },
  )
  let rendered = try! @pdflite.pdf_write_document_incremental_update(
    original, recrypted,
  )
  @test.assert_eq(
    crypt_recrypt_bytes_start_with_at(rendered, original, 0),
    true,
  )
  let roundtrip = crypt_recrypt_unwrap_decryption_result_for_test(
    try! @pdflite.pdf_read_document_from_bytes_with_passwords(
      rendered,
      user_password=Some(@ascii.encode("user")),
    ),
  )
  @test.assert_eq(roundtrip.document.lookup_object_or_null(5), updated_secret)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(8), added_object)
  @test.assert_eq(roundtrip.denied_permissions, [PdfNoForms])
  @test.assert_eq(
    try! @pdflite.pdf_read_document_from_bytes_with_passwords(
      rendered,
      user_password=Some(@ascii.encode("bad")),
    ),
    None,
  )
}

///|
test "PdfDocument recrypt_with_password supports classic incremental update" {
  let key_type = crypt_recrypt_name_for_test("/Type")
  let key_catalog = crypt_recrypt_name_for_test("/Catalog")
  let key_pages = crypt_recrypt_name_for_test("/Pages")
  let key_kids = crypt_recrypt_name_for_test("/Kids")
  let key_count = crypt_recrypt_name_for_test("/Count")
  let key_title = crypt_recrypt_name_for_test("/Title")
  let doc = @pdflite.pdf_document_empty()
  doc.set_version(1, 4)
  doc.set_root(1)
  doc.add_object_given_number(
    1,
    PdfDictionary([
      (key_type, PdfNameObject(key_catalog)),
      (key_pages, PdfIndirect(2)),
    ]),
  )
  doc.add_object_given_number(
    2,
    PdfDictionary([
      (key_type, PdfNameObject(key_pages)),
      (key_kids, PdfArray([])),
      (key_count, PdfInteger(0)),
    ]),
  )
  let original_secret : @syntax.PdfObject = PdfDictionary([
    (key_title, PdfString(@ascii.encode("original"))),
  ])
  let updated_secret : @syntax.PdfObject = PdfDictionary([
    (key_title, PdfString(@ascii.encode("updated"))),
  ])
  let added_object : @syntax.PdfObject = PdfString(@ascii.encode("added"))
  doc.add_object_given_number(5, original_secret)
  let encrypted = try! doc.encrypt_128bit_r4(
    @ascii.encode("user"),
    @ascii.encode("owner"),
    [PdfNoPrint],
    encrypt_metadata=true,
    file_id=@ascii.encode("doc-id"),
  )
  let original = try! @pdflite.pdf_write_document(encrypted)
  let decrypted = crypt_recrypt_unwrap_decryption_result_for_test(
    try! @pdflite.pdf_read_document_from_bytes_with_passwords(
      original,
      user_password=Some(@ascii.encode("user")),
    ),
  )
  @test.assert_eq(decrypted.document.event_log(), [])
  @test.assert_eq(decrypted.document.lookup_object_or_null(5), original_secret)

  decrypted.document.add_object_given_number(5, updated_secret)
  decrypted.document.add_object_given_number(8, added_object)
  let recrypted = try! decrypted.document.recrypt_with_password(
    @ascii.encode("owner"),
  )
  let rendered = try! @pdflite.pdf_write_document_incremental_update(
    original, recrypted,
  )
  @test.assert_eq(
    crypt_recrypt_bytes_start_with_at(rendered, original, 0),
    true,
  )
  let roundtrip = crypt_recrypt_unwrap_decryption_result_for_test(
    try! @pdflite.pdf_read_document_from_bytes_with_passwords(
      rendered,
      user_password=Some(@ascii.encode("user")),
    ),
  )
  @test.assert_eq(roundtrip.document.root(), 1)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(5), updated_secret)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(8), added_object)
  @test.assert_eq(roundtrip.denied_permissions, [PdfNoPrint])
  @test.assert_eq(
    try! @pdflite.pdf_read_document_from_bytes_with_passwords(
      rendered,
      user_password=Some(@ascii.encode("bad")),
    ),
    None,
  )
}

///|
test "PdfDocument recrypt_with_password supports xref stream incremental updates" {
  let key_type = crypt_recrypt_name_for_test("/Type")
  let key_catalog = crypt_recrypt_name_for_test("/Catalog")
  let key_pages = crypt_recrypt_name_for_test("/Pages")
  let key_kids = crypt_recrypt_name_for_test("/Kids")
  let key_count = crypt_recrypt_name_for_test("/Count")
  let key_title = crypt_recrypt_name_for_test("/Title")
  let doc = @pdflite.pdf_document_empty()
  doc.set_version(1, 5)
  doc.set_root(1)
  doc.add_object_given_number(
    1,
    PdfDictionary([
      (key_type, PdfNameObject(key_catalog)),
      (key_pages, PdfIndirect(2)),
    ]),
  )
  doc.add_object_given_number(
    2,
    PdfDictionary([
      (key_type, PdfNameObject(key_pages)),
      (key_kids, PdfArray([])),
      (key_count, PdfInteger(0)),
    ]),
  )
  let original_secret : @syntax.PdfObject = PdfDictionary([
    (key_title, PdfString(@ascii.encode("original-xref"))),
  ])
  let updated_secret : @syntax.PdfObject = PdfDictionary([
    (key_title, PdfString(@ascii.encode("updated-xref"))),
  ])
  let added_object : @syntax.PdfObject = PdfString(@ascii.encode("xref-added"))
  doc.add_object_given_number(5, original_secret)
  let encrypted = try! doc.encrypt_128bit_r4(
    @ascii.encode("user"),
    @ascii.encode("owner"),
    [PdfNoCopy],
    encrypt_metadata=true,
    file_id=@ascii.encode("doc-id"),
  )
  let original = try! @pdflite.pdf_write_document_with_xref_stream(encrypted)
  let decrypted = crypt_recrypt_unwrap_decryption_result_for_test(
    try! @pdflite.pdf_read_document_from_bytes_with_passwords(
      original,
      owner_password=Some(@ascii.encode("owner")),
    ),
  )
  @test.assert_eq(decrypted.document.event_log(), [])
  @test.assert_eq(decrypted.document.lookup_object_or_null(5), original_secret)

  decrypted.document.add_object_given_number(5, updated_secret)
  decrypted.document.add_object_given_number(8, added_object)
  let recrypted = try! decrypted.document.recrypt_with_password(
    @ascii.encode("user"),
  )
  let rendered = try! @pdflite.pdf_write_document_incremental_update_with_xref_stream(
    original, recrypted,
  )
  @test.assert_eq(
    crypt_recrypt_bytes_start_with_at(rendered, original, 0),
    true,
  )
  let roundtrip = crypt_recrypt_unwrap_decryption_result_for_test(
    try! @pdflite.pdf_read_document_from_bytes_with_passwords(
      rendered,
      user_password=Some(@ascii.encode("user")),
    ),
  )
  @test.assert_eq(roundtrip.document.lookup_object_or_null(5), updated_secret)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(8), added_object)
  @test.assert_eq(roundtrip.denied_permissions, [PdfNoCopy])

  let compressed = try! @pdflite.pdf_write_document_incremental_update_with_compressed_xref_stream(
    original, recrypted,
  )
  @test.assert_eq(
    crypt_recrypt_bytes_start_with_at(compressed, original, 0),
    true,
  )
  let compressed_roundtrip = crypt_recrypt_unwrap_decryption_result_for_test(
    try! @pdflite.pdf_read_document_from_bytes_with_passwords(
      compressed,
      user_password=Some(@ascii.encode("bad")),
      owner_password=Some(@ascii.encode("owner")),
    ),
  )
  @test.assert_eq(
    compressed_roundtrip.document.lookup_object_or_null(5),
    updated_secret,
  )
  @test.assert_eq(
    compressed_roundtrip.document.lookup_object_or_null(8),
    added_object,
  )
  @test.assert_eq(compressed_roundtrip.denied_permissions, [PdfNoCopy])
}
