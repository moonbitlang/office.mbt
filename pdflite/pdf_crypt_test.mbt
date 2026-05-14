///|
fn crypt_model_bytes_for_test(values : ArrayView[Int]) -> @pdflite.PdfBytes {
  try! @pdflite.pdf_bytes_of_int_array(values)
}

///|
fn crypt_concat_bytes_for_test(
  parts : ArrayView[BytesView],
) -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  for part in parts {
    for byte in part {
      output.push(byte)
    }
  }
  Bytes::from_array(output)
}

///|
fn crypt_restore_env_for_test(previous : String?) -> Unit {
  match previous {
    Some(value) => @env.set_env_var("CAMLPDF_REPRODUCIBLE_IDS", value)
    None => @env.unset_env_var("CAMLPDF_REPRODUCIBLE_IDS")
  }
}

///|
fn crypt_bytes_start_with_at(
  haystack : @pdflite.PdfBytes,
  needle : @pdflite.PdfBytes,
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
fn crypt_bytes_contain_for_test(
  haystack : @pdflite.PdfBytes,
  needle : @pdflite.PdfBytes,
) -> Bool {
  if needle.length() == 0 {
    true
  } else if needle.length() > haystack.length() {
    false
  } else {
    for start in 0..<=(haystack.length() - needle.length()) {
      if crypt_bytes_start_with_at(haystack, needle, start) {
        break true
      }
    } nobreak {
      false
    }
  }
}

///|
fn crypt_aesv3_encrypt_data_for_test(
  file_key : BytesView,
  data : BytesView,
  iv : BytesView,
) -> @pdflite.PdfBytes raise {
  guard file_key == crypt_aesv3_r5_file_key_for_test() else {
    fail("expected AESV3 R5 file key fixture")
  }
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(1, PdfString(data.to_owned()))
  let encrypted_doc = try! doc.encrypt_256bit_aesv3_with_providers(
    @ascii.encode("user"),
    @ascii.encode("owner"),
    [],
    crypt_aesv3_r5_random_for_test,
    fn(_, _, _) { iv.to_owned() },
    file_id=@ascii.encode("doc-id"),
  )
  match encrypted_doc.lookup_object_or_null(1) {
    PdfString(bytes) => bytes
    _ => fail("expected encrypted AESV3 string")
  }
}

///|
fn crypt_aes_document_iv_for_test(
  object_number : Int,
  generation : Int,
  index : Int,
) -> @pdflite.PdfBytes {
  crypt_model_bytes_for_test(
    [
      for offset in 0..<16 => {
        (object_number * 17 + generation * 5 + index * 31 + offset) % 256
      }
    ],
  )
}

///|
fn crypt_aesv3_r5_user_entry_for_test() -> @pdflite.PdfBytes {
  crypt_model_bytes_for_test([
    0xad, 0x7c, 0x98, 0xe2, 0x51, 0xcb, 0x1c, 0x7b, 0x3e, 0x28, 0x30, 0xb6, 0xf0,
    0xbe, 0xcb, 0xd8, 0x35, 0x2a, 0x6a, 0xb7, 0x12, 0x23, 0x2d, 0x6e, 0x82, 0xf2,
    0xfc, 0xa4, 0x5f, 0x30, 0x4d, 0xcc, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
    0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f, 0x10,
  ])
}

///|
fn crypt_aesv3_r5_owner_entry_for_test() -> @pdflite.PdfBytes {
  crypt_model_bytes_for_test([
    0xf9, 0x90, 0x4f, 0x90, 0x02, 0x10, 0x0b, 0x3e, 0xba, 0x57, 0x69, 0x0b, 0x67,
    0x32, 0x30, 0xde, 0xfc, 0xcd, 0x12, 0x39, 0x9f, 0x8d, 0xa1, 0xa8, 0x73, 0x41,
    0x48, 0x36, 0x93, 0x7e, 0xbf, 0xf7, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17,
    0x18, 0x19, 0x1a, 0x1b, 0x1c, 0x1d, 0x1e, 0x1f, 0x20,
  ])
}

///|
fn crypt_aesv3_values_for_test(
  user_entry : BytesView,
  owner_entry : BytesView,
  iso? : Bool = false,
) -> @pdflite.PdfEncryptionValues {
  {
    crypt_type: PdfCryptAESV3(iso),
    user_entry: user_entry.to_owned(),
    owner_entry: owner_entry.to_owned(),
    permissions: -3904,
    file_id: @ascii.encode("doc-id"),
    encrypt_metadata: true,
    permissions_entry: None,
    user_encryption_key: None,
    owner_encryption_key: None,
  }
}

///|
fn crypt_aesv3_r5_file_key_for_test() -> @pdflite.PdfBytes {
  crypt_model_bytes_for_test([ for value in 0..<32 => value ])
}

///|
fn crypt_aesv3_r5_user_encryption_key_for_test() -> @pdflite.PdfBytes {
  crypt_model_bytes_for_test([
    0xe4, 0x35, 0xfd, 0x1c, 0x68, 0x70, 0xfc, 0x3b, 0x50, 0x7f, 0x7c, 0x3d, 0x30,
    0xd0, 0x2e, 0x06, 0xb7, 0x60, 0x68, 0x50, 0x81, 0x95, 0xc1, 0x29, 0x87, 0x9c,
    0x23, 0xce, 0x43, 0xee, 0xda, 0x22,
  ])
}

///|
fn crypt_aesv3_r5_owner_encryption_key_for_test() -> @pdflite.PdfBytes {
  crypt_model_bytes_for_test([
    0x93, 0x8a, 0x69, 0x29, 0xac, 0xa0, 0x6a, 0x79, 0x47, 0xde, 0x9d, 0xc4, 0x68,
    0x29, 0x04, 0xca, 0xda, 0x26, 0xbf, 0x1b, 0xb2, 0x8e, 0xc9, 0xc8, 0x2b, 0x83,
    0x9d, 0x5b, 0x89, 0x4e, 0x6c, 0xec,
  ])
}

///|
fn crypt_aesv3_r5_permissions_for_test(
  permissions? : Int = -3904,
  encrypt_metadata? : Bool = true,
) -> @pdflite.PdfBytes {
  match (permissions, encrypt_metadata) {
    (-3904, true) =>
      crypt_model_bytes_for_test([
        0x61, 0x58, 0xb9, 0xdd, 0xf6, 0x26, 0xa8, 0xfa, 0x36, 0x68, 0x20, 0xad, 0x7e,
        0xd7, 0xde, 0x4d,
      ])
    (-4, true) =>
      crypt_model_bytes_for_test([
        0x90, 0x96, 0xe4, 0x75, 0x19, 0xec, 0x03, 0x12, 0x27, 0x76, 0x55, 0xae, 0xd4,
        0x41, 0x52, 0x20,
      ])
    (-3904, false) =>
      crypt_model_bytes_for_test([
        0xc1, 0x3b, 0x0f, 0x6a, 0xb2, 0xc5, 0x1a, 0x9e, 0x81, 0x15, 0xa5, 0xc3, 0xa3,
        0x96, 0xd7, 0x26,
      ])
    _ => crypt_model_bytes_for_test([])
  }
}

///|
#warnings("-unused_error_type")
fn crypt_aesv3_r5_random_for_test(
  field : @pdflite.PdfAesV3RandomField,
  _length : Int,
) -> @pdflite.PdfBytes raise @pdflite.PdfError {
  match field {
    PdfAesV3FileKey => crypt_aesv3_r5_file_key_for_test()
    PdfAesV3UserValidationSalt =>
      crypt_model_bytes_for_test([
        0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08,
      ])
    PdfAesV3UserKeySalt =>
      crypt_model_bytes_for_test([
        0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f, 0x10,
      ])
    PdfAesV3OwnerValidationSalt =>
      crypt_model_bytes_for_test([
        0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18,
      ])
    PdfAesV3OwnerKeySalt =>
      crypt_model_bytes_for_test([
        0x19, 0x1a, 0x1b, 0x1c, 0x1d, 0x1e, 0x1f, 0x20,
      ])
    PdfAesV3PermissionsPadding => Bytes::new(4)
  }
}

///|
test "deterministic AES providers derive stable bytes from seed and callsite" {
  let seed = @ascii.encode("fixture-seed")
  let iv_provider = @pdflite.pdf_deterministic_aes_iv_provider_from_seed(seed)
  let same_iv_provider = @pdflite.pdf_deterministic_aes_iv_provider_from_seed(
    seed,
  )
  let other_iv_provider = @pdflite.pdf_deterministic_aes_iv_provider_from_seed(
    @ascii.encode("other-seed"),
  )
  let iv = iv_provider(5, 0, 1)
  @test.assert_eq(iv.length(), 16)
  @test.assert_eq(iv, same_iv_provider(5, 0, 1))
  @test.assert_eq(iv == iv_provider(5, 0, 2), false)
  @test.assert_eq(iv == other_iv_provider(5, 0, 1), false)
  let boundary_iv_provider = @pdflite.pdf_deterministic_aes_iv_provider_from_seed(
    @ascii.encode("async encrypted revision iv"),
  )
  @test.assert_eq(boundary_iv_provider(30, 0, 0).length(), 16)
  let random_provider = @pdflite.pdf_deterministic_aesv3_random_provider_from_seed(
    seed,
  )
  let same_random_provider = @pdflite.pdf_deterministic_aesv3_random_provider_from_seed(
    seed,
  )
  let file_key = random_provider(PdfAesV3FileKey, 32)
  @test.assert_eq(file_key.length(), 32)
  @test.assert_eq(file_key, same_random_provider(PdfAesV3FileKey, 32))
  @test.assert_eq(
    file_key == random_provider(PdfAesV3UserValidationSalt, 8),
    false,
  )
  @test.assert_eq(random_provider(PdfAesV3PermissionsPadding, 4).length(), 4)
  @test.assert_eq(random_provider(PdfAesV3PermissionsPadding, 0), Bytes::new(0))
}

///|
fn crypt_aesv3_r5_document_with_object_for_test(
  major : Int,
  minor : Int,
  object_number : Int,
  object : @pdflite.PdfObject,
  permissions? : Int = -3904,
  encrypt_metadata? : Bool = true,
) -> @pdflite.PdfDocument raise {
  let doc = crypt_minimal_catalog_document_for_test(major, minor)
  doc.add_object_given_number(object_number, object)
  let encrypted = try! doc.encrypt_256bit_aesv3_with_providers(
    @ascii.encode("user"),
    @ascii.encode("owner"),
    @pdflite.pdf_permissions_of_p(permissions),
    crypt_aesv3_r5_random_for_test,
    fn(encrypted_object_number, generation, index) {
      crypt_aes_document_iv_for_test(encrypted_object_number, generation, index)
    },
    encrypt_metadata~,
    file_id=@ascii.encode("doc-id"),
  )
  let key_encrypt = crypt_name_for_test("/Encrypt")
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
fn crypt_aesv3_r6_document_with_object_for_test(
  major : Int,
  minor : Int,
  object_number : Int,
  object : @pdflite.PdfObject,
  encrypt_metadata? : Bool = true,
) -> @pdflite.PdfDocument raise {
  let doc = crypt_minimal_catalog_document_for_test(major, minor)
  doc.add_object_given_number(object_number, object)
  doc.encrypt_256bit_aesv3_with_providers(
    @ascii.encode("user"),
    @ascii.encode("owner"),
    @pdflite.pdf_permissions_of_p(-3904),
    crypt_aesv3_r5_random_for_test,
    fn(object_number, generation, index) {
      crypt_aes_document_iv_for_test(object_number, generation, index)
    },
    iso=true,
    encrypt_metadata~,
    file_id=@ascii.encode("doc-id"),
  )
}

///|
fn crypt_name_for_test(text : String) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn crypt_minimal_catalog_document_for_test(
  major : Int,
  minor : Int,
) -> @pdflite.PdfDocument {
  let key_type = crypt_name_for_test("/Type")
  let key_catalog = crypt_name_for_test("/Catalog")
  let key_pages = crypt_name_for_test("/Pages")
  let key_kids = crypt_name_for_test("/Kids")
  let key_count = crypt_name_for_test("/Count")
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
fn crypt_stream_for_test(
  entries : ArrayView[(@pdflite.PdfName, @pdflite.PdfObject)],
  data : @pdflite.PdfBytes,
) -> @pdflite.PdfObject {
  PdfStreamObject({
    dictionary: PdfDictionary([ for entry in entries => entry ]),
    data: StreamGot(data),
  })
}

///|
fn crypt_stream_object_bytes_for_test(
  stream : @pdflite.PdfStream,
) -> @pdflite.PdfBytes raise {
  @pdflite.pdf_stream(stream.dictionary, stream.data).stream_bytes()
}

///|
fn crypt_document_with_stream_for_test(
  major : Int,
  minor : Int,
  object_number : Int,
  data : @pdflite.PdfBytes,
) -> @pdflite.PdfDocument {
  let doc = crypt_minimal_catalog_document_for_test(major, minor)
  doc.add_object_given_number(
    object_number,
    crypt_stream_for_test(
      [(crypt_name_for_test("/Length"), PdfInteger(data.length()))],
      data,
    ),
  )
  doc
}

///|
fn crypt_assert_deferred_stream_for_test(
  object : @pdflite.PdfObject,
  expected_crypt : (@pdflite.PdfStreamDataCrypt) -> Bool,
  expected_data : @pdflite.PdfBytes,
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
    @pdflite.pdf_stream(stream.dictionary, stream.data).stream_bytes(),
    expected_data,
  )
  @test.assert_eq(
    crypt_bytes_contain_for_test(
      @pdflite.pdf_write_object(
        @pdflite.pdf_stream(stream.dictionary, stream.data),
      ),
      expected_data,
    ),
    true,
  )
  let forced = @pdflite.pdf_stream(stream.dictionary, stream.data)
  forced.get_stream()
  guard forced is PdfStreamObject(forced_stream) else {
    fail("expected forced stream object")
  }
  guard forced_stream.data is StreamGot(forced_data) else {
    fail("expected materialized stream data")
  }
  @test.assert_eq(forced_data, expected_data)
  @test.assert_eq(
    forced_stream.dictionary.lookup_immediate(crypt_name_for_test("/Length")),
    Some(PdfInteger(expected_data.length())),
  )
}

///|
fn crypt_assert_equivalent_object_for_test(
  actual : @pdflite.PdfObject,
  expected : @pdflite.PdfObject,
) -> Unit raise {
  match (actual, expected) {
    (PdfStreamObject(actual), PdfStreamObject(expected)) => {
      @test.assert_eq(actual.dictionary, expected.dictionary)
      @test.assert_eq(
        crypt_stream_object_bytes_for_test(actual),
        crypt_stream_object_bytes_for_test(expected),
      )
    }
    _ => @test.assert_eq(actual, expected)
  }
}

///|
fn crypt_repeated_bytes_for_test(
  value : Int,
  length : Int,
) -> @pdflite.PdfBytes {
  crypt_model_bytes_for_test([ for _ in 0..<length => value ])
}

///|
fn crypt_standard_encrypt_dictionary_for_test(
  entries : ArrayView[(@pdflite.PdfName, @pdflite.PdfObject)],
  owner_length? : Int = 40,
  user_length? : Int = 40,
) -> @pdflite.PdfObject {
  crypt_standard_encrypt_dictionary_values_for_test(
    entries,
    crypt_repeated_bytes_for_test(0x4f, owner_length),
    crypt_repeated_bytes_for_test(0x55, user_length),
    -4,
  )
}

///|
fn crypt_standard_encrypt_dictionary_values_for_test(
  entries : ArrayView[(@pdflite.PdfName, @pdflite.PdfObject)],
  owner_entry : @pdflite.PdfBytes,
  user_entry : @pdflite.PdfBytes,
  permissions : Int,
) -> @pdflite.PdfObject {
  let output : Array[(@pdflite.PdfName, @pdflite.PdfObject)] = [
    (
      crypt_name_for_test("/Filter"),
      PdfNameObject(crypt_name_for_test("/Standard")),
    ),
    (crypt_name_for_test("/O"), PdfString(owner_entry)),
    (crypt_name_for_test("/U"), PdfString(user_entry)),
    (crypt_name_for_test("/P"), PdfInteger(permissions)),
  ]
  for entry in entries {
    output.push(entry)
  }
  PdfDictionary(output)
}

///|
fn crypt_doc_with_encrypt_for_test(
  encrypt_dictionary : @pdflite.PdfObject,
) -> @pdflite.PdfDocument {
  let doc = @pdflite.pdf_document_empty()
  doc.set_trailer_dict(
    PdfDictionary([
      (crypt_name_for_test("/Encrypt"), encrypt_dictionary),
      (
        crypt_name_for_test("/ID"),
        PdfArray([
          PdfString(@ascii.encode("doc-id")),
          PdfString(@ascii.encode("ignored")),
        ]),
      ),
    ]),
  )
  doc
}

///|
fn crypt_expect_encryption_method_error_for_test(
  encrypt_dictionary : @pdflite.PdfObject,
) -> Unit raise {
  let doc = crypt_doc_with_encrypt_for_test(encrypt_dictionary)
  let result : Result[@pdflite.PdfEncryptionValues, Error] = try? doc.encryption_values()
  guard result is Err(@pdflite.PdfError::EncryptionMethodExpected) else {
    fail("expected EncryptionMethodExpected")
  }
}

///|
fn crypt_unwrap_decryption_result_for_test(
  result : @pdflite.PdfDecryptionResult?,
) -> @pdflite.PdfDecryptionResult raise {
  match result {
    Some(value) => value
    None => fail("expected decrypted document")
  }
}

///|
test "PdfDocument is_encrypted follows direct encryption dictionary" {
  let key_encrypt = crypt_name_for_test("/Encrypt")
  let encrypt_dictionary = crypt_standard_encrypt_dictionary_for_test([
    (crypt_name_for_test("/V"), PdfInteger(1)),
    (crypt_name_for_test("/R"), PdfInteger(2)),
  ])
  let plain_doc = @pdflite.pdf_document_empty()
  @test.assert_eq(plain_doc.is_encrypted(), false)

  let direct_doc = @pdflite.pdf_document_empty()
  direct_doc.set_trailer_dict(
    PdfDictionary([(key_encrypt, encrypt_dictionary)]),
  )
  @test.assert_eq(direct_doc.is_encrypted(), true)

  let indirect_doc = @pdflite.pdf_document_empty()
  indirect_doc.add_object_given_number(7, encrypt_dictionary)
  indirect_doc.set_trailer_dict(PdfDictionary([(key_encrypt, PdfIndirect(7))]))
  @test.assert_eq(indirect_doc.is_encrypted(), true)

  let missing_indirect_doc = @pdflite.pdf_document_empty()
  missing_indirect_doc.set_trailer_dict(
    PdfDictionary([(key_encrypt, PdfIndirect(99))]),
  )
  @test.assert_eq(missing_indirect_doc.is_encrypted(), false)
}

///|
test "PdfDocument reports encryption method and permissions" {
  let plain_doc = @pdflite.pdf_document_empty()
  @test.assert_eq(try! plain_doc.what_encryption(), None)
  @test.assert_eq(try! plain_doc.permissions(), [])

  let denied : Array[@pdflite.PdfPermission] = [PdfNoPrint, PdfNoCopy]
  let permissions = @pdflite.pdf_p_of_permissions(denied)
  let arc4_40 = crypt_doc_with_encrypt_for_test(
    crypt_standard_encrypt_dictionary_values_for_test(
      [
        (crypt_name_for_test("/V"), PdfInteger(1)),
        (crypt_name_for_test("/R"), PdfInteger(2)),
      ],
      crypt_repeated_bytes_for_test(0x4f, 32),
      crypt_repeated_bytes_for_test(0x55, 32),
      permissions,
    ),
  )
  @test.assert_eq(try! arc4_40.what_encryption(), Some(PdfEncryption40Bit))
  @test.assert_eq(try! arc4_40.permissions(), [PdfNoCopy, PdfNoPrint])

  let arc4_128 = crypt_doc_with_encrypt_for_test(
    crypt_standard_encrypt_dictionary_for_test([
      (crypt_name_for_test("/V"), PdfInteger(2)),
      (crypt_name_for_test("/Length"), PdfInteger(128)),
      (crypt_name_for_test("/R"), PdfInteger(3)),
    ]),
  )
  @test.assert_eq(try! arc4_128.what_encryption(), Some(PdfEncryption128Bit))

  let arc4_96 = crypt_doc_with_encrypt_for_test(
    crypt_standard_encrypt_dictionary_for_test([
      (crypt_name_for_test("/V"), PdfInteger(4)),
      (crypt_name_for_test("/R"), PdfInteger(4)),
      (
        crypt_name_for_test("/CF"),
        PdfDictionary([
          (crypt_name_for_test("/Length"), PdfInteger(96)),
          (
            crypt_name_for_test("/StdCF"),
            PdfDictionary([
              (
                crypt_name_for_test("/CFM"),
                PdfNameObject(crypt_name_for_test("/V2")),
              ),
            ]),
          ),
        ]),
      ),
    ]),
  )
  @test.assert_eq(try! arc4_96.what_encryption(), None)

  let aesv2 = crypt_doc_with_encrypt_for_test(
    crypt_standard_encrypt_dictionary_for_test([
      (crypt_name_for_test("/V"), PdfInteger(4)),
      (crypt_name_for_test("/R"), PdfInteger(4)),
      (crypt_name_for_test("/EncryptMetadata"), PdfBoolean(false)),
      (
        crypt_name_for_test("/CF"),
        PdfDictionary([
          (
            crypt_name_for_test("/StdCF"),
            PdfDictionary([
              (
                crypt_name_for_test("/CFM"),
                PdfNameObject(crypt_name_for_test("/AESV2")),
              ),
            ]),
          ),
        ]),
      ),
    ]),
  )
  @test.assert_eq(
    try! aesv2.what_encryption(),
    Some(PdfEncryptionAES128(false)),
  )

  let aesv3 = crypt_doc_with_encrypt_for_test(
    crypt_standard_encrypt_dictionary_for_test(
      [
        (crypt_name_for_test("/V"), PdfInteger(5)),
        (crypt_name_for_test("/R"), PdfInteger(5)),
        (
          crypt_name_for_test("/CF"),
          PdfDictionary([
            (
              crypt_name_for_test("/StdCF"),
              PdfDictionary([
                (
                  crypt_name_for_test("/CFM"),
                  PdfNameObject(crypt_name_for_test("/AESV3")),
                ),
              ]),
            ),
          ]),
        ),
      ],
      owner_length=56,
      user_length=56,
    ),
  )
  @test.assert_eq(try! aesv3.what_encryption(), Some(PdfEncryptionAES256(true)))

  let aesv3_iso = crypt_doc_with_encrypt_for_test(
    crypt_standard_encrypt_dictionary_for_test(
      [
        (crypt_name_for_test("/V"), PdfInteger(5)),
        (crypt_name_for_test("/R"), PdfInteger(6)),
        (crypt_name_for_test("/EncryptMetadata"), PdfBoolean(false)),
        (
          crypt_name_for_test("/CF"),
          PdfDictionary([
            (
              crypt_name_for_test("/StdCF"),
              PdfDictionary([
                (
                  crypt_name_for_test("/CFM"),
                  PdfNameObject(crypt_name_for_test("/AESV3")),
                ),
              ]),
            ),
          ]),
        ),
      ],
      owner_length=56,
      user_length=56,
    ),
  )
  @test.assert_eq(
    try! aesv3_iso.what_encryption(),
    Some(PdfEncryptionAES256ISO(false)),
  )
}

///|
test "PdfDocument encryption_values parses legacy ARC4 dictionary values" {
  let doc = crypt_doc_with_encrypt_for_test(
    crypt_standard_encrypt_dictionary_for_test([
      (crypt_name_for_test("/V"), PdfInteger(1)),
      (crypt_name_for_test("/R"), PdfInteger(2)),
    ]),
  )
  let values = try! doc.encryption_values()
  @test.assert_eq(values.crypt_type, PdfCryptARC4(40, 2))
  @test.assert_eq(values.owner_entry, crypt_repeated_bytes_for_test(0x4f, 32))
  @test.assert_eq(values.user_entry, crypt_repeated_bytes_for_test(0x55, 32))
  @test.assert_eq(values.permissions, -4)
  @test.assert_eq(values.file_id, @ascii.encode("doc-id"))
  @test.assert_eq(values.encrypt_metadata, true)
  @test.assert_eq(values.user_encryption_key, None)
  @test.assert_eq(values.owner_encryption_key, None)

  let r3_doc = crypt_doc_with_encrypt_for_test(
    crypt_standard_encrypt_dictionary_for_test([
      (crypt_name_for_test("/V"), PdfInteger(2)),
      (crypt_name_for_test("/R"), PdfInteger(3)),
    ]),
  )
  @test.assert_eq(
    (try! r3_doc.encryption_values()).crypt_type,
    PdfCryptARC4(40, 3),
  )

  let r3_length_doc = crypt_doc_with_encrypt_for_test(
    crypt_standard_encrypt_dictionary_for_test([
      (crypt_name_for_test("/V"), PdfInteger(2)),
      (crypt_name_for_test("/Length"), PdfInteger(128)),
      (crypt_name_for_test("/R"), PdfInteger(3)),
    ]),
  )
  let r3_values = try! r3_length_doc.encryption_values()
  @test.assert_eq(r3_values.crypt_type, PdfCryptARC4(128, 3))
  @test.assert_eq(r3_values.owner_entry.length(), 32)
  @test.assert_eq(r3_values.user_entry.length(), 32)
}

///|
test "PdfDocument encryption_values parses crypt filter methods" {
  let arc4_doc = crypt_doc_with_encrypt_for_test(
    crypt_standard_encrypt_dictionary_for_test([
      (crypt_name_for_test("/V"), PdfInteger(4)),
      (crypt_name_for_test("/R"), PdfInteger(4)),
      (
        crypt_name_for_test("/CF"),
        PdfDictionary([
          (crypt_name_for_test("/Length"), PdfInteger(96)),
          (
            crypt_name_for_test("/StdCF"),
            PdfDictionary([
              (
                crypt_name_for_test("/CFM"),
                PdfNameObject(crypt_name_for_test("/V2")),
              ),
            ]),
          ),
        ]),
      ),
    ]),
  )
  @test.assert_eq(
    (try! arc4_doc.encryption_values()).crypt_type,
    PdfCryptARC4(96, 4),
  )

  let arc4_length_doc = crypt_doc_with_encrypt_for_test(
    crypt_standard_encrypt_dictionary_for_test([
      (crypt_name_for_test("/V"), PdfInteger(4)),
      (crypt_name_for_test("/R"), PdfInteger(4)),
      (crypt_name_for_test("/Length"), PdfInteger(128)),
      (
        crypt_name_for_test("/CF"),
        PdfDictionary([
          (
            crypt_name_for_test("/StdCF"),
            PdfDictionary([
              (
                crypt_name_for_test("/CFM"),
                PdfNameObject(crypt_name_for_test("/V2")),
              ),
            ]),
          ),
        ]),
      ),
    ]),
  )
  @test.assert_eq(
    (try! arc4_length_doc.encryption_values()).crypt_type,
    PdfCryptARC4(128, 4),
  )

  let aesv2_doc = crypt_doc_with_encrypt_for_test(
    crypt_standard_encrypt_dictionary_for_test([
      (crypt_name_for_test("/V"), PdfInteger(4)),
      (crypt_name_for_test("/R"), PdfInteger(4)),
      (
        crypt_name_for_test("/CF"),
        PdfDictionary([
          (
            crypt_name_for_test("/StdCF"),
            PdfDictionary([
              (
                crypt_name_for_test("/CFM"),
                PdfNameObject(crypt_name_for_test("/AESV2")),
              ),
            ]),
          ),
        ]),
      ),
    ]),
  )
  @test.assert_eq(
    (try! aesv2_doc.encryption_values()).crypt_type,
    PdfCryptAESV2,
  )
  let no_metadata_doc = crypt_doc_with_encrypt_for_test(
    crypt_standard_encrypt_dictionary_for_test([
      (crypt_name_for_test("/V"), PdfInteger(4)),
      (crypt_name_for_test("/R"), PdfInteger(4)),
      (crypt_name_for_test("/EncryptMetadata"), PdfBoolean(false)),
      (
        crypt_name_for_test("/CF"),
        PdfDictionary([
          (
            crypt_name_for_test("/StdCF"),
            PdfDictionary([
              (
                crypt_name_for_test("/CFM"),
                PdfNameObject(crypt_name_for_test("/AESV2")),
              ),
            ]),
          ),
        ]),
      ),
    ]),
  )
  let no_metadata_values = try! no_metadata_doc.encryption_values()
  @test.assert_eq(no_metadata_values.crypt_type, PdfCryptAESV2)
  @test.assert_eq(no_metadata_values.encrypt_metadata, false)

  let aesv3_doc = crypt_doc_with_encrypt_for_test(
    crypt_standard_encrypt_dictionary_for_test(
      [
        (crypt_name_for_test("/V"), PdfInteger(5)),
        (crypt_name_for_test("/R"), PdfInteger(6)),
        (
          crypt_name_for_test("/CF"),
          PdfDictionary([
            (
              crypt_name_for_test("/StdCF"),
              PdfDictionary([
                (
                  crypt_name_for_test("/CFM"),
                  PdfNameObject(crypt_name_for_test("/AESV3")),
                ),
              ]),
            ),
          ]),
        ),
        (
          crypt_name_for_test("/UE"),
          PdfString(crypt_aesv3_r5_user_encryption_key_for_test()),
        ),
        (
          crypt_name_for_test("/OE"),
          PdfString(crypt_aesv3_r5_owner_encryption_key_for_test()),
        ),
      ],
      owner_length=56,
      user_length=56,
    ),
  )
  let aesv3_values = try! aesv3_doc.encryption_values()
  @test.assert_eq(aesv3_values.crypt_type, PdfCryptAESV3(true))
  @test.assert_eq(aesv3_values.owner_entry.length(), 48)
  @test.assert_eq(aesv3_values.user_entry.length(), 48)
  @test.assert_eq(
    aesv3_values.user_encryption_key,
    Some(crypt_aesv3_r5_user_encryption_key_for_test()),
  )
  @test.assert_eq(
    aesv3_values.owner_encryption_key,
    Some(crypt_aesv3_r5_owner_encryption_key_for_test()),
  )
  @test.assert_eq(
    try! aesv3_values.authenticate_user_password(@ascii.encode("user")),
    false,
  )
}

///|
test "PdfEncryptionValues authenticates passwords and derives file keys" {
  let doc = try! @pdflite.pdf_document_empty().encrypt_128bit(
    @ascii.encode("user"),
    @ascii.encode("owner"),
    @pdflite.pdf_permissions_of_p(-3904),
    file_id=@ascii.encode("doc-id"),
  )
  let values = try! doc.encryption_values()
  let expected_key = try! values.file_key_for_user_password(
    @ascii.encode("user"),
  )
  guard expected_key is Some(_) else { fail("expected user file key") }
  @test.assert_eq(
    try! values.authenticate_user_password(@ascii.encode("user")),
    true,
  )
  @test.assert_eq(
    try! values.authenticate_user_password(@ascii.encode("bad")),
    false,
  )
  @test.assert_eq(
    try! values.file_key_for_user_password(@ascii.encode("user")),
    expected_key,
  )
  @test.assert_eq(
    try! values.file_key_for_user_password(@ascii.encode("bad")),
    None,
  )
  @test.assert_eq(
    try! values.authenticate_owner_password(@ascii.encode("owner")),
    true,
  )
  @test.assert_eq(
    try! values.authenticate_owner_password(@ascii.encode("bad")),
    false,
  )
  @test.assert_eq(
    try! values.file_key_for_owner_password(@ascii.encode("owner")),
    expected_key,
  )
  @test.assert_eq(
    try! values.file_key_for_owner_password(@ascii.encode("bad")),
    None,
  )
}

///|
test "PdfEncryptionValues treats AESV2 as revision 4 with 128-bit keys" {
  let doc = try! @pdflite.pdf_document_empty().encrypt_128bit_aesv2_with_iv_provider(
    @ascii.encode("user"),
    @ascii.encode("owner"),
    @pdflite.pdf_permissions_of_p(-3904),
    fn(_, _, _) { Bytes::new(16) },
    file_id=@ascii.encode("doc-id"),
  )
  let values = try! doc.encryption_values()
  let expected_key = try! values.file_key_for_user_password(
    @ascii.encode("user"),
  )
  guard expected_key is Some(_) else { fail("expected AESV2 user file key") }
  @test.assert_eq(values.crypt_type, PdfCryptAESV2)
  @test.assert_eq(
    try! values.authenticate_user_password(@ascii.encode("user")),
    true,
  )
  @test.assert_eq(
    try! values.file_key_for_user_password(@ascii.encode("user")),
    expected_key,
  )
}

///|
test "PdfEncryptionValues authenticates AESV3 revision 5 passwords" {
  let user_entry = crypt_aesv3_r5_user_entry_for_test()
  let owner_entry = crypt_aesv3_r5_owner_entry_for_test()
  let doc = crypt_doc_with_encrypt_for_test(
    crypt_standard_encrypt_dictionary_values_for_test(
      [
        (crypt_name_for_test("/V"), PdfInteger(5)),
        (crypt_name_for_test("/R"), PdfInteger(5)),
        (
          crypt_name_for_test("/CF"),
          PdfDictionary([
            (
              crypt_name_for_test("/StdCF"),
              PdfDictionary([
                (
                  crypt_name_for_test("/CFM"),
                  PdfNameObject(crypt_name_for_test("/AESV3")),
                ),
              ]),
            ),
          ]),
        ),
        (
          crypt_name_for_test("/UE"),
          PdfString(crypt_aesv3_r5_user_encryption_key_for_test()),
        ),
        (
          crypt_name_for_test("/OE"),
          PdfString(crypt_aesv3_r5_owner_encryption_key_for_test()),
        ),
        (
          crypt_name_for_test("/Perms"),
          PdfString(crypt_aesv3_r5_permissions_for_test()),
        ),
      ],
      owner_entry,
      user_entry,
      -3904,
    ),
  )
  let values = try! doc.encryption_values()
  @test.assert_eq(values.crypt_type, PdfCryptAESV3(false))
  @test.assert_eq(
    try! values.authenticate_user_password(@ascii.encode("user")),
    true,
  )
  @test.assert_eq(
    try! values.authenticate_user_password(@ascii.encode("bad")),
    false,
  )
  @test.assert_eq(
    try! values.authenticate_owner_password(@ascii.encode("owner")),
    true,
  )
  @test.assert_eq(
    try! values.authenticate_owner_password(@ascii.encode("bad")),
    false,
  )
  @test.assert_eq(
    try! values.file_key_for_user_password(@ascii.encode("user")),
    Some(crypt_aesv3_r5_file_key_for_test()),
  )
  @test.assert_eq(
    try! values.file_key_for_user_password(@ascii.encode("bad")),
    None,
  )
  @test.assert_eq(
    try! values.file_key_for_owner_password(@ascii.encode("owner")),
    Some(crypt_aesv3_r5_file_key_for_test()),
  )
  @test.assert_eq(
    try! values.file_key_for_owner_password(@ascii.encode("bad")),
    None,
  )

  let missing_perms_doc = crypt_doc_with_encrypt_for_test(
    crypt_standard_encrypt_dictionary_values_for_test(
      [
        (crypt_name_for_test("/V"), PdfInteger(5)),
        (crypt_name_for_test("/R"), PdfInteger(5)),
        (
          crypt_name_for_test("/CF"),
          PdfDictionary([
            (
              crypt_name_for_test("/StdCF"),
              PdfDictionary([
                (
                  crypt_name_for_test("/CFM"),
                  PdfNameObject(crypt_name_for_test("/AESV3")),
                ),
              ]),
            ),
          ]),
        ),
        (
          crypt_name_for_test("/UE"),
          PdfString(crypt_aesv3_r5_user_encryption_key_for_test()),
        ),
        (
          crypt_name_for_test("/OE"),
          PdfString(crypt_aesv3_r5_owner_encryption_key_for_test()),
        ),
      ],
      owner_entry,
      user_entry,
      -3904,
    ),
  )
  let missing_perms = try! missing_perms_doc.encryption_values()
  let missing_perms_result : Result[@pdflite.PdfBytes?, Error] = try? missing_perms.file_key_for_user_password(
    @ascii.encode("user"),
  )
  guard missing_perms_result
    is Err(@pdflite.PdfError::EncryptionDictionaryEntryExpected(name)) &&
    name == crypt_name_for_test("/Perms") else {
    fail("expected missing AESV3 /Perms")
  }

  let short_perms_doc = crypt_doc_with_encrypt_for_test(
    crypt_standard_encrypt_dictionary_values_for_test(
      [
        (crypt_name_for_test("/V"), PdfInteger(5)),
        (crypt_name_for_test("/R"), PdfInteger(5)),
        (
          crypt_name_for_test("/CF"),
          PdfDictionary([
            (
              crypt_name_for_test("/StdCF"),
              PdfDictionary([
                (
                  crypt_name_for_test("/CFM"),
                  PdfNameObject(crypt_name_for_test("/AESV3")),
                ),
              ]),
            ),
          ]),
        ),
        (
          crypt_name_for_test("/UE"),
          PdfString(crypt_aesv3_r5_user_encryption_key_for_test()),
        ),
        (
          crypt_name_for_test("/OE"),
          PdfString(crypt_aesv3_r5_owner_encryption_key_for_test()),
        ),
        (crypt_name_for_test("/Perms"), PdfString(Bytes::new(15))),
      ],
      owner_entry,
      user_entry,
      -3904,
    ),
  )
  let short_perms = try! short_perms_doc.encryption_values()
  let short_perms_result : Result[@pdflite.PdfBytes?, Error] = try? short_perms.file_key_for_user_password(
    @ascii.encode("user"),
  )
  guard short_perms_result
    is Err(@pdflite.PdfError::EncryptionDictionaryEntryTooShort(name)) &&
    name == crypt_name_for_test("/Perms") else {
    fail("expected short AESV3 /Perms")
  }

  let corrupt_perms_doc = crypt_doc_with_encrypt_for_test(
    crypt_standard_encrypt_dictionary_values_for_test(
      [
        (crypt_name_for_test("/V"), PdfInteger(5)),
        (crypt_name_for_test("/R"), PdfInteger(5)),
        (
          crypt_name_for_test("/CF"),
          PdfDictionary([
            (
              crypt_name_for_test("/StdCF"),
              PdfDictionary([
                (
                  crypt_name_for_test("/CFM"),
                  PdfNameObject(crypt_name_for_test("/AESV3")),
                ),
              ]),
            ),
          ]),
        ),
        (
          crypt_name_for_test("/UE"),
          PdfString(crypt_aesv3_r5_user_encryption_key_for_test()),
        ),
        (
          crypt_name_for_test("/OE"),
          PdfString(crypt_aesv3_r5_owner_encryption_key_for_test()),
        ),
        (crypt_name_for_test("/Perms"), PdfString(Bytes::new(16))),
      ],
      owner_entry,
      user_entry,
      -3904,
    ),
  )
  let corrupt_perms = try! corrupt_perms_doc.encryption_values()
  let corrupt_perms_result : Result[@pdflite.PdfBytes?, Error] = try? corrupt_perms.file_key_for_user_password(
    @ascii.encode("user"),
  )
  guard corrupt_perms_result
    is Err(@pdflite.PdfError::EncryptionPermissionsCorrupt) else {
    fail("expected corrupt AESV3 /Perms")
  }

  let mismatched_perms_doc = crypt_doc_with_encrypt_for_test(
    crypt_standard_encrypt_dictionary_values_for_test(
      [
        (crypt_name_for_test("/V"), PdfInteger(5)),
        (crypt_name_for_test("/R"), PdfInteger(5)),
        (
          crypt_name_for_test("/CF"),
          PdfDictionary([
            (
              crypt_name_for_test("/StdCF"),
              PdfDictionary([
                (
                  crypt_name_for_test("/CFM"),
                  PdfNameObject(crypt_name_for_test("/AESV3")),
                ),
              ]),
            ),
          ]),
        ),
        (
          crypt_name_for_test("/UE"),
          PdfString(crypt_aesv3_r5_user_encryption_key_for_test()),
        ),
        (
          crypt_name_for_test("/OE"),
          PdfString(crypt_aesv3_r5_owner_encryption_key_for_test()),
        ),
        (
          crypt_name_for_test("/Perms"),
          PdfString(crypt_aesv3_r5_permissions_for_test(permissions=-4)),
        ),
      ],
      owner_entry,
      user_entry,
      -3904,
    ),
  )
  let mismatched_perms = try! mismatched_perms_doc.encryption_values()
  let mismatched_perms_result : Result[@pdflite.PdfBytes?, Error] = try? mismatched_perms.file_key_for_owner_password(
    @ascii.encode("owner"),
  )
  guard mismatched_perms_result
    is Err(@pdflite.PdfError::EncryptionPermissionsMismatch(-4, -3904)) else {
    fail("expected mismatched AESV3 /Perms")
  }

  let missing_ue_doc = crypt_doc_with_encrypt_for_test(
    crypt_standard_encrypt_dictionary_values_for_test(
      [
        (crypt_name_for_test("/V"), PdfInteger(5)),
        (crypt_name_for_test("/R"), PdfInteger(5)),
        (
          crypt_name_for_test("/CF"),
          PdfDictionary([
            (
              crypt_name_for_test("/StdCF"),
              PdfDictionary([
                (
                  crypt_name_for_test("/CFM"),
                  PdfNameObject(crypt_name_for_test("/AESV3")),
                ),
              ]),
            ),
          ]),
        ),
        (
          crypt_name_for_test("/OE"),
          PdfString(crypt_aesv3_r5_owner_encryption_key_for_test()),
        ),
      ],
      owner_entry,
      user_entry,
      -3904,
    ),
  )
  let missing_ue = try! missing_ue_doc.encryption_values()
  let missing_ue_result : Result[@pdflite.PdfBytes?, Error] = try? missing_ue.file_key_for_user_password(
    @ascii.encode("user"),
  )
  guard missing_ue_result
    is Err(@pdflite.PdfError::EncryptionDictionaryEntryExpected(name)) &&
    name == crypt_name_for_test("/UE") else {
    fail("expected missing AESV3 /UE")
  }

  let short_oe_doc = crypt_doc_with_encrypt_for_test(
    crypt_standard_encrypt_dictionary_values_for_test(
      [
        (crypt_name_for_test("/V"), PdfInteger(5)),
        (crypt_name_for_test("/R"), PdfInteger(5)),
        (
          crypt_name_for_test("/CF"),
          PdfDictionary([
            (
              crypt_name_for_test("/StdCF"),
              PdfDictionary([
                (
                  crypt_name_for_test("/CFM"),
                  PdfNameObject(crypt_name_for_test("/AESV3")),
                ),
              ]),
            ),
          ]),
        ),
        (
          crypt_name_for_test("/UE"),
          PdfString(crypt_aesv3_r5_user_encryption_key_for_test()),
        ),
        (
          crypt_name_for_test("/OE"),
          PdfString(crypt_repeated_bytes_for_test(0x22, 31)),
        ),
      ],
      owner_entry,
      user_entry,
      -3904,
    ),
  )
  let short_oe = try! short_oe_doc.encryption_values()
  let short_oe_result : Result[@pdflite.PdfBytes?, Error] = try? short_oe.file_key_for_owner_password(
    @ascii.encode("owner"),
  )
  guard short_oe_result
    is Err(@pdflite.PdfError::EncryptionDictionaryEntryTooShort(name)) &&
    name == crypt_name_for_test("/OE") else {
    fail("expected short AESV3 /OE")
  }

  let decrypted = crypt_unwrap_decryption_result_for_test(
    try! doc.decrypt_with_user_password(@ascii.encode("user")),
  )
  @test.assert_eq(
    decrypted.document
    .trailer_dict()
    .lookup_immediate(crypt_name_for_test("/Encrypt")),
    None,
  )
  @test.assert_eq(
    decrypted.denied_permissions,
    @pdflite.pdf_permissions_of_p(-3904),
  )
  let owner_decrypted = crypt_unwrap_decryption_result_for_test(
    try! doc.decrypt_with_owner_password(@ascii.encode("owner")),
  )
  @test.assert_eq(
    owner_decrypted.document
    .trailer_dict()
    .lookup_immediate(crypt_name_for_test("/Encrypt")),
    None,
  )
}

///|
test "PdfDocument decrypt_with_user_password decrypts parsed ARC4 objects in a copy" {
  let file_id = @ascii.encode("doc-id")
  let plain_object : @pdflite.PdfObject = PdfDictionary([
    (crypt_name_for_test("/Title"), PdfString(@ascii.encode("hello"))),
  ])
  let source = @pdflite.pdf_document_empty()
  source.add_object_given_number(1, plain_object)
  let template = try! source.encrypt_128bit(
    @ascii.encode("user"),
    @ascii.encode("owner"),
    @pdflite.pdf_permissions_of_p(-3904),
    file_id~,
  )
  let values = try! template.encryption_values()
  let owner_entry = values.owner_entry
  let user_entry = values.user_entry
  let encrypt_dictionary = crypt_standard_encrypt_dictionary_values_for_test(
    [
      (crypt_name_for_test("/V"), PdfInteger(2)),
      (crypt_name_for_test("/Length"), PdfInteger(128)),
      (crypt_name_for_test("/R"), PdfInteger(3)),
    ],
    owner_entry,
    user_entry,
    -3904,
  )
  let encrypted_object = template.lookup_object_or_null(1)
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(1, encrypted_object)
  doc.add_object_given_number(2, encrypt_dictionary)
  doc.set_trailer_dict(
    PdfDictionary([
      (crypt_name_for_test("/Encrypt"), PdfIndirect(2)),
      (
        crypt_name_for_test("/ID"),
        PdfArray([
          PdfString(@ascii.encode("doc-id")),
          PdfString(@ascii.encode("ignored")),
        ]),
      ),
    ]),
  )

  let decrypted = crypt_unwrap_decryption_result_for_test(
    try! doc.decrypt_with_user_password(@ascii.encode("user")),
  )
  @test.assert_eq(decrypted.document.lookup_object_or_null(1), plain_object)
  @test.assert_eq(
    decrypted.document.lookup_object_or_null(2),
    encrypt_dictionary,
  )
  @test.assert_eq(
    decrypted.document
    .trailer_dict()
    .lookup_immediate(crypt_name_for_test("/Encrypt")),
    None,
  )
  @test.assert_eq(
    decrypted.denied_permissions,
    @pdflite.pdf_permissions_of_p(-3904),
  )
  @test.assert_eq(doc.lookup_object_or_null(1), encrypted_object)
  @test.assert_eq(
    doc.trailer_dict().lookup_immediate(crypt_name_for_test("/Encrypt")),
    Some(PdfIndirect(2)),
  )
  @test.assert_eq(
    try! doc.decrypt_with_user_password(@ascii.encode("bad")),
    None,
  )

  let direct_doc = @pdflite.pdf_document_empty()
  direct_doc.add_object_given_number(1, encrypted_object)
  direct_doc.set_trailer_dict(
    PdfDictionary([
      (crypt_name_for_test("/Encrypt"), encrypt_dictionary),
      (
        crypt_name_for_test("/ID"),
        PdfArray([
          PdfString(@ascii.encode("doc-id")),
          PdfString(@ascii.encode("ignored")),
        ]),
      ),
    ]),
  )
  let direct_decrypted = crypt_unwrap_decryption_result_for_test(
    try! direct_doc.decrypt_with_user_password(@ascii.encode("user")),
  )
  @test.assert_eq(
    direct_decrypted.document.lookup_object_or_null(1),
    plain_object,
  )
  @test.assert_eq(
    direct_decrypted.document
    .trailer_dict()
    .lookup_immediate(crypt_name_for_test("/Encrypt")),
    None,
  )

  let plain_doc = @pdflite.pdf_document_empty()
  plain_doc.add_object_given_number(1, PdfString(@ascii.encode("plain")))
  let no_encryption = crypt_unwrap_decryption_result_for_test(
    try! plain_doc.decrypt_with_user_password(@ascii.encode("anything")),
  )
  @test.assert_eq(
    no_encryption.document.lookup_object_or_null(1),
    PdfString(@ascii.encode("plain")),
  )
  @test.assert_eq(no_encryption.denied_permissions, [])
}

///|
test "PdfDocument decrypt_with_owner_password decrypts parsed ARC4 objects in a copy" {
  let file_id = @ascii.encode("doc-id")
  let plain_object : @pdflite.PdfObject = PdfDictionary([
    (crypt_name_for_test("/Title"), PdfString(@ascii.encode("owner"))),
  ])
  let source = @pdflite.pdf_document_empty()
  source.add_object_given_number(1, plain_object)
  let template = try! source.encrypt_128bit(
    @ascii.encode("user"),
    @ascii.encode("owner"),
    @pdflite.pdf_permissions_of_p(-3904),
    file_id~,
  )
  let values = try! template.encryption_values()
  let owner_entry = values.owner_entry
  let user_entry = values.user_entry
  let encrypt_dictionary = crypt_standard_encrypt_dictionary_values_for_test(
    [
      (crypt_name_for_test("/V"), PdfInteger(2)),
      (crypt_name_for_test("/Length"), PdfInteger(128)),
      (crypt_name_for_test("/R"), PdfInteger(3)),
    ],
    owner_entry,
    user_entry,
    -3904,
  )
  let encrypted_object = template.lookup_object_or_null(1)
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(1, encrypted_object)
  doc.add_object_given_number(2, encrypt_dictionary)
  doc.set_trailer_dict(
    PdfDictionary([
      (crypt_name_for_test("/Encrypt"), PdfIndirect(2)),
      (
        crypt_name_for_test("/ID"),
        PdfArray([
          PdfString(@ascii.encode("doc-id")),
          PdfString(@ascii.encode("ignored")),
        ]),
      ),
    ]),
  )

  let decrypted = crypt_unwrap_decryption_result_for_test(
    try! doc.decrypt_with_owner_password(@ascii.encode("owner")),
  )
  @test.assert_eq(decrypted.document.lookup_object_or_null(1), plain_object)
  @test.assert_eq(
    decrypted.document.lookup_object_or_null(2),
    encrypt_dictionary,
  )
  @test.assert_eq(
    decrypted.document
    .trailer_dict()
    .lookup_immediate(crypt_name_for_test("/Encrypt")),
    None,
  )
  @test.assert_eq(
    decrypted.denied_permissions,
    @pdflite.pdf_permissions_of_p(-3904),
  )
  @test.assert_eq(doc.lookup_object_or_null(1), encrypted_object)
  @test.assert_eq(
    try! doc.decrypt_with_owner_password(@ascii.encode("bad")),
    None,
  )

  let plain_doc = @pdflite.pdf_document_empty()
  plain_doc.add_object_given_number(1, PdfString(@ascii.encode("plain")))
  let no_encryption = crypt_unwrap_decryption_result_for_test(
    try! plain_doc.decrypt_with_owner_password(@ascii.encode("anything")),
  )
  @test.assert_eq(
    no_encryption.document.lookup_object_or_null(1),
    PdfString(@ascii.encode("plain")),
  )
  @test.assert_eq(no_encryption.denied_permissions, [])
}

///|
test "PdfDocument encrypt_40bit encrypts parsed objects and installs dictionary" {
  let key_title = crypt_name_for_test("/Title")
  let key_id = crypt_name_for_test("/ID")
  let key_encrypt = crypt_name_for_test("/Encrypt")
  let key_filter = crypt_name_for_test("/Filter")
  let key_standard = crypt_name_for_test("/Standard")
  let key_v = crypt_name_for_test("/V")
  let key_r = crypt_name_for_test("/R")
  let key_p = crypt_name_for_test("/P")
  let key_o = crypt_name_for_test("/O")
  let key_u = crypt_name_for_test("/U")
  let doc = @pdflite.pdf_document_empty()
  let plain_object : @pdflite.PdfObject = PdfDictionary([
    (key_title, PdfString(@ascii.encode("hello"))),
  ])
  doc.add_object_given_number(1, plain_object)
  doc.set_trailer_dict(
    PdfDictionary([
      (
        key_id,
        PdfArray([
          PdfString(@ascii.encode("doc-id")),
          PdfString(@ascii.encode("ignored")),
        ]),
      ),
    ]),
  )
  let encrypted = try! doc.encrypt_40bit(
    @ascii.encode("user"),
    @ascii.encode("owner"),
    [PdfNoPrint],
  )
  let permissions = @pdflite.pdf_p_of_permissions([PdfNoPrint])
  let values = try! encrypted.encryption_values()
  let owner_entry = values.owner_entry
  let user_entry = values.user_entry
  guard encrypted.lookup_object_or_null(1).lookup_immediate(key_title)
    is Some(PdfString(encrypted_title)) else {
    fail("expected encrypted title")
  }
  @test.assert_eq(encrypted_title == @ascii.encode("hello"), false)
  guard encrypted.trailer_dict().lookup_immediate(key_encrypt)
    is Some(PdfIndirect(encrypt_number)) else {
    fail("expected indirect encryption dictionary")
  }
  let encrypt_dictionary = encrypted.lookup_object_or_null(encrypt_number)
  @test.assert_eq(
    encrypt_dictionary.lookup_immediate(key_filter),
    Some(PdfNameObject(key_standard)),
  )
  @test.assert_eq(
    encrypt_dictionary.lookup_immediate(key_v),
    Some(PdfInteger(1)),
  )
  @test.assert_eq(
    encrypt_dictionary.lookup_immediate(key_r),
    Some(PdfInteger(2)),
  )
  @test.assert_eq(
    encrypt_dictionary.lookup_immediate(key_p),
    Some(PdfInteger(permissions)),
  )
  @test.assert_eq(
    encrypt_dictionary.lookup_immediate(key_o),
    Some(PdfString(owner_entry)),
  )
  guard encrypt_dictionary.lookup_immediate(key_u)
    is Some(PdfString(found_user_entry)) else {
    fail("expected user entry")
  }
  @test.assert_eq(found_user_entry, user_entry)
  @test.assert_eq(user_entry.length(), 32)
  @test.assert_eq(values.crypt_type, PdfCryptARC4(40, 2))
  @test.assert_eq(values.permissions, permissions)
  @test.assert_eq(values.file_id, @ascii.encode("doc-id"))
  let decrypted = crypt_unwrap_decryption_result_for_test(
    try! encrypted.decrypt_with_user_password(@ascii.encode("user")),
  )
  @test.assert_eq(decrypted.document.lookup_object_or_null(1), plain_object)
  @test.assert_eq(decrypted.denied_permissions, [PdfNoPrint])
  @test.assert_eq(
    decrypted.document.trailer_dict().lookup_immediate(key_encrypt),
    None,
  )
  guard decrypted.document.saved_encryption() is Some(saved) else {
    fail("expected saved encryption")
  }
  @test.assert_eq(saved.values.crypt_type, PdfCryptARC4(40, 2))
  @test.assert_eq(saved.values.permissions, permissions)
  @test.assert_eq(saved.values.file_id, @ascii.encode("doc-id"))
  @test.assert_eq(decrypted.document.copy().saved_encryption(), Some(saved))
  let owner_decrypted = crypt_unwrap_decryption_result_for_test(
    try! encrypted.decrypt_with_owner_password(@ascii.encode("owner")),
  )
  @test.assert_eq(
    owner_decrypted.document.lookup_object_or_null(1),
    plain_object,
  )
  @test.assert_eq(doc.lookup_object_or_null(1), plain_object)
  @test.assert_eq(doc.trailer_dict().lookup_immediate(key_encrypt), None)
}

///|
test "PdfDocument encrypt_40bit adds a file id when missing" {
  let key_id = crypt_name_for_test("/ID")
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(1, PdfString(@ascii.encode("plain")))
  let previous = @env.get_env_var("CAMLPDF_REPRODUCIBLE_IDS")
  @env.set_env_var("CAMLPDF_REPRODUCIBLE_IDS", "true")
  let generated = try! doc.encrypt_40bit(
    @ascii.encode("user"),
    @ascii.encode("owner"),
    [],
  )
  crypt_restore_env_for_test(previous)
  let generated_id = crypt_model_bytes_for_test([
    0xe1, 0x43, 0x6d, 0x66, 0xa1, 0x0b, 0xd6, 0x4e, 0xc8, 0xc8, 0xdc, 0x0a, 0xd7,
    0xc3, 0x83, 0x55,
  ])
  @test.assert_eq(
    generated.trailer_dict().lookup_immediate(key_id),
    Some(PdfArray([PdfString(generated_id), PdfString(generated_id)])),
  )

  let encrypted = try! doc.encrypt_40bit(
    @ascii.encode("user"),
    @ascii.encode("owner"),
    [],
    file_id=@ascii.encode("chosen-id"),
  )
  @test.assert_eq(
    encrypted.trailer_dict().lookup_immediate(key_id),
    Some(
      PdfArray([
        PdfString(@ascii.encode("chosen-id")),
        PdfString(@ascii.encode("chosen-id")),
      ]),
    ),
  )
  @test.assert_eq(
    (try! encrypted.encryption_values()).file_id,
    @ascii.encode("chosen-id"),
  )
  @test.assert_eq(doc.trailer_dict().lookup_immediate(key_id), None)
}

///|
test "PdfDocument recrypt_with_password restores saved ARC4 encryption" {
  let key_title = crypt_name_for_test("/Title")
  let plain_object : @pdflite.PdfObject = PdfDictionary([
    (key_title, PdfString(@ascii.encode("secret"))),
  ])
  let added_object : @pdflite.PdfObject = PdfString(@ascii.encode("added"))
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(1, plain_object)
  let encrypted = try! doc.encrypt_128bit_r4(
    @ascii.encode("user"),
    @ascii.encode("owner"),
    [PdfNoPrint],
    encrypt_metadata=false,
    file_id=@ascii.encode("doc-id"),
  )
  let decrypted = crypt_unwrap_decryption_result_for_test(
    try! encrypted.decrypt_with_user_password(@ascii.encode("user")),
  )
  decrypted.document.add_object_given_number(2, added_object)
  let recrypted = try! decrypted.document.recrypt_with_password(
    @ascii.encode("owner"),
  )
  @test.assert_eq(recrypted.is_encrypted(), true)
  @test.assert_eq(recrypted.saved_encryption(), None)
  @test.assert_eq(try! recrypted.what_encryption(), Some(PdfEncryption128Bit))
  let roundtrip = crypt_unwrap_decryption_result_for_test(
    try! recrypted.decrypt_with_user_password(@ascii.encode("user")),
  )
  @test.assert_eq(roundtrip.document.lookup_object_or_null(1), plain_object)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(2), added_object)
  @test.assert_eq(roundtrip.denied_permissions, [PdfNoPrint])

  let bad_password : Result[@pdflite.PdfDocument, Error] = try? decrypted.document.recrypt_with_password(
    @ascii.encode("bad"),
  )
  guard bad_password is Err(@pdflite.PdfError::EncryptionRecryptFailed) else {
    fail("expected failed recrypt")
  }

  let no_saved : Result[@pdflite.PdfDocument, Error] = try? doc.recrypt_with_password(
    @ascii.encode("user"),
  )
  guard no_saved is Err(@pdflite.PdfError::EncryptionSavedStateExpected) else {
    fail("expected missing saved encryption")
  }

  let aes_encrypted = try! doc.encrypt_128bit_aesv2_with_iv_provider(
    @ascii.encode("user"),
    @ascii.encode("owner"),
    [],
    fn(object_number, generation, index) {
      crypt_aes_document_iv_for_test(object_number, generation, index)
    },
    file_id=@ascii.encode("doc-id"),
  )
  let aes_decrypted = crypt_unwrap_decryption_result_for_test(
    try! aes_encrypted.decrypt_with_user_password(@ascii.encode("user")),
  )
  let unsupported : Result[@pdflite.PdfDocument, Error] = try? aes_decrypted.document.recrypt_with_password(
    @ascii.encode("user"),
  )
  guard unsupported
    is Err(@pdflite.PdfError::EncryptionRecryptUnsupported(PdfCryptAESV2)) else {
    fail("expected unsupported AES recrypt")
  }

  let arc4_128 = try! doc.encrypt_128bit(
    @ascii.encode("user"),
    @ascii.encode("owner"),
    [PdfNoCopy],
    file_id=@ascii.encode("doc-id"),
  )
  let arc4_128_decrypted = crypt_unwrap_decryption_result_for_test(
    try! arc4_128.decrypt_with_user_password(@ascii.encode("user")),
  )
  let arc4_128_recrypted = try! arc4_128_decrypted.document.recrypt_with_password(
    @ascii.encode("user"),
  )
  @test.assert_eq(
    try! arc4_128_recrypted.what_encryption(),
    Some(PdfEncryption128Bit),
  )
  let arc4_128_roundtrip = crypt_unwrap_decryption_result_for_test(
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
  let key_type = crypt_name_for_test("/Type")
  let key_catalog = crypt_name_for_test("/Catalog")
  let key_pages = crypt_name_for_test("/Pages")
  let key_kids = crypt_name_for_test("/Kids")
  let key_count = crypt_name_for_test("/Count")
  let key_title = crypt_name_for_test("/Title")
  let key_metadata = crypt_name_for_test("/Metadata")
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
  let secret_object : @pdflite.PdfObject = PdfDictionary([
    (key_title, PdfString(@ascii.encode("aes-secret"))),
  ])
  let added_object : @pdflite.PdfObject = PdfString(@ascii.encode("aes-added"))
  let metadata_stream = crypt_stream_for_test(
    [
      (crypt_name_for_test("/Length"), PdfInteger(4)),
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
      crypt_aes_document_iv_for_test(object_number, generation, index)
    },
    encrypt_metadata=false,
    file_id=@ascii.encode("doc-id"),
  )
  let decrypted = crypt_unwrap_decryption_result_for_test(
    try! encrypted.decrypt_with_user_password(@ascii.encode("user")),
  )
  decrypted.document.add_object_given_number(7, added_object)
  let recrypted = try! decrypted.document.recrypt_with_password_aesv2_with_iv_provider(
    @ascii.encode("owner"),
    fn(object_number, generation, index) {
      crypt_aes_document_iv_for_test(object_number, generation, index + 4)
    },
  )
  @test.assert_eq(recrypted.is_encrypted(), true)
  @test.assert_eq(recrypted.saved_encryption(), None)
  @test.assert_eq(
    try! recrypted.what_encryption(),
    Some(PdfEncryptionAES128(false)),
  )
  let roundtrip = crypt_unwrap_decryption_result_for_test(
    try! recrypted.decrypt_with_user_password(@ascii.encode("user")),
  )
  @test.assert_eq(roundtrip.document.lookup_object_or_null(5), secret_object)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(6), metadata_stream)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(7), added_object)
  @test.assert_eq(roundtrip.denied_permissions, [PdfNoPrint])

  let rendered = try! @pdflite.pdf_write_document(recrypted)
  let parsed = try! @pdflite.pdf_read_document_from_bytes(rendered)
  let read_decrypted = crypt_unwrap_decryption_result_for_test(
    try! parsed.decrypt_with_owner_password(@ascii.encode("owner")),
  )
  @test.assert_eq(
    read_decrypted.document.lookup_object_or_null(5),
    secret_object,
  )
  try! crypt_assert_equivalent_object_for_test(
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
      crypt_aes_document_iv_for_test(object_number, generation, index)
    },
  )
  guard bad_password is Err(@pdflite.PdfError::EncryptionRecryptFailed) else {
    fail("expected failed AESV2 recrypt")
  }

  let no_saved : Result[@pdflite.PdfDocument, Error] = try? doc.recrypt_with_password_aesv2_with_iv_provider(
    @ascii.encode("user"),
    fn(object_number, generation, index) {
      crypt_aes_document_iv_for_test(object_number, generation, index)
    },
  )
  guard no_saved is Err(@pdflite.PdfError::EncryptionSavedStateExpected) else {
    fail("expected missing saved encryption")
  }

  let arc4 = try! doc.encrypt_40bit(
    @ascii.encode("user"),
    @ascii.encode("owner"),
    [],
    file_id=@ascii.encode("doc-id"),
  )
  let arc4_decrypted = crypt_unwrap_decryption_result_for_test(
    try! arc4.decrypt_with_user_password(@ascii.encode("user")),
  )
  let unsupported : Result[@pdflite.PdfDocument, Error] = try? arc4_decrypted.document.recrypt_with_password_aesv2_with_iv_provider(
    @ascii.encode("user"),
    fn(object_number, generation, index) {
      crypt_aes_document_iv_for_test(object_number, generation, index)
    },
  )
  guard unsupported
    is Err(@pdflite.PdfError::EncryptionRecryptUnsupported(PdfCryptARC4(40, 2))) else {
    fail("expected unsupported non-AESV2 recrypt")
  }
}

///|
test "PdfDocument recrypt_with_password_aesv3_with_iv_provider restores saved AESV3 revision 5 encryption" {
  let key_title = crypt_name_for_test("/Title")
  let key_metadata = crypt_name_for_test("/Metadata")
  let original_secret : @pdflite.PdfObject = PdfDictionary([
    (key_title, PdfString(@ascii.encode("aes3-original"))),
  ])
  let updated_secret : @pdflite.PdfObject = PdfDictionary([
    (key_title, PdfString(@ascii.encode("aes3-updated"))),
  ])
  let added_object : @pdflite.PdfObject = PdfString(@ascii.encode("aes3-added"))
  let metadata_stream = crypt_stream_for_test(
    [
      (crypt_name_for_test("/Length"), PdfInteger(4)),
      (crypt_name_for_test("/Type"), PdfNameObject(key_metadata)),
      (key_title, PdfString(@ascii.encode("meta"))),
    ],
    @ascii.encode("data"),
  )
  let doc = try! crypt_aesv3_r5_document_with_object_for_test(
    1,
    7,
    5,
    original_secret,
    encrypt_metadata=false,
  )
  doc.add_object_given_number(6, metadata_stream)

  let decrypted = crypt_unwrap_decryption_result_for_test(
    try! doc.decrypt_with_user_password(@ascii.encode("user")),
  )
  @test.assert_eq(decrypted.document.lookup_object_or_null(5), original_secret)
  @test.assert_eq(decrypted.document.lookup_object_or_null(6), metadata_stream)
  decrypted.document.add_object_given_number(5, updated_secret)
  decrypted.document.add_object_given_number(7, added_object)
  let recrypted = try! decrypted.document.recrypt_with_password_aesv3_with_iv_provider(
    @ascii.encode("owner"),
    fn(object_number, generation, index) {
      crypt_aes_document_iv_for_test(object_number, generation, index + 2)
    },
  )
  @test.assert_eq(recrypted.is_encrypted(), true)
  @test.assert_eq(recrypted.saved_encryption(), None)
  @test.assert_eq(
    try! recrypted.what_encryption(),
    Some(PdfEncryptionAES256(false)),
  )
  let roundtrip = crypt_unwrap_decryption_result_for_test(
    try! recrypted.decrypt_with_user_password(@ascii.encode("user")),
  )
  @test.assert_eq(roundtrip.document.lookup_object_or_null(5), updated_secret)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(6), metadata_stream)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(7), added_object)
  @test.assert_eq(
    roundtrip.denied_permissions,
    @pdflite.pdf_permissions_of_p(-3904),
  )

  let rendered = try! @pdflite.pdf_write_document(recrypted)
  let parsed = try! @pdflite.pdf_read_document_from_bytes(rendered)
  let read_decrypted = crypt_unwrap_decryption_result_for_test(
    try! parsed.decrypt_with_owner_password(@ascii.encode("owner")),
  )
  @test.assert_eq(
    read_decrypted.document.lookup_object_or_null(5),
    updated_secret,
  )
  try! crypt_assert_equivalent_object_for_test(
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
      crypt_aes_document_iv_for_test(object_number, generation, index)
    },
  )
  guard bad_password is Err(@pdflite.PdfError::EncryptionRecryptFailed) else {
    fail("expected failed AESV3 recrypt")
  }

  let no_saved : Result[@pdflite.PdfDocument, Error] = try? crypt_minimal_catalog_document_for_test(
    1, 7,
  ).recrypt_with_password_aesv3_with_iv_provider(@ascii.encode("user"), fn(
    object_number,
    generation,
    index,
  ) {
    crypt_aes_document_iv_for_test(object_number, generation, index)
  })
  guard no_saved is Err(@pdflite.PdfError::EncryptionSavedStateExpected) else {
    fail("expected missing AESV3 saved encryption")
  }

  let wrong_plain = crypt_minimal_catalog_document_for_test(1, 7)
  let wrong_encrypted = try! wrong_plain.encrypt_128bit_aesv2_with_iv_provider(
    @ascii.encode("user"),
    @ascii.encode("owner"),
    [],
    fn(object_number, generation, index) {
      crypt_aes_document_iv_for_test(object_number, generation, index)
    },
    file_id=@ascii.encode("doc-id"),
  )
  let wrong_decrypted = crypt_unwrap_decryption_result_for_test(
    try! wrong_encrypted.decrypt_with_user_password(@ascii.encode("user")),
  )
  let wrong_method : Result[@pdflite.PdfDocument, Error] = try? wrong_decrypted.document.recrypt_with_password_aesv3_with_iv_provider(
    @ascii.encode("user"),
    fn(object_number, generation, index) {
      crypt_aes_document_iv_for_test(object_number, generation, index)
    },
  )
  guard wrong_method
    is Err(@pdflite.PdfError::EncryptionRecryptUnsupported(PdfCryptAESV2)) else {
    fail("expected non-AESV3 saved encryption rejection")
  }
}

///|
test "PdfDocument recrypt_with_password_aesv3_with_iv_provider supports AESV3 revision 6" {
  let key_title = crypt_name_for_test("/Title")
  let original_secret : @pdflite.PdfObject = PdfDictionary([
    (key_title, PdfString(@ascii.encode("aes3-r6-original"))),
  ])
  let updated_secret : @pdflite.PdfObject = PdfDictionary([
    (key_title, PdfString(@ascii.encode("aes3-r6-updated"))),
  ])
  let doc = crypt_minimal_catalog_document_for_test(1, 7)
  doc.add_object_given_number(5, original_secret)
  let encrypted = try! doc.encrypt_256bit_aesv3_with_providers(
    @ascii.encode("user"),
    @ascii.encode("owner"),
    @pdflite.pdf_permissions_of_p(-3904),
    crypt_aesv3_r5_random_for_test,
    fn(object_number, generation, index) {
      crypt_aes_document_iv_for_test(object_number, generation, index)
    },
    iso=true,
    encrypt_metadata=false,
    file_id=@ascii.encode("doc-id"),
  )
  @test.assert_eq(
    try! encrypted.what_encryption(),
    Some(PdfEncryptionAES256ISO(false)),
  )
  let decrypted = crypt_unwrap_decryption_result_for_test(
    try! encrypted.decrypt_with_owner_password(@ascii.encode("owner")),
  )
  @test.assert_eq(decrypted.document.lookup_object_or_null(5), original_secret)
  decrypted.document.add_object_given_number(5, updated_secret)
  let recrypted = try! decrypted.document.recrypt_with_password_aesv3_with_iv_provider(
    @ascii.encode("user"),
    fn(object_number, generation, index) {
      crypt_aes_document_iv_for_test(object_number, generation, index + 3)
    },
  )
  @test.assert_eq(
    try! recrypted.what_encryption(),
    Some(PdfEncryptionAES256ISO(false)),
  )
  let roundtrip = crypt_unwrap_decryption_result_for_test(
    try! recrypted.decrypt_with_user_password(@ascii.encode("user")),
  )
  @test.assert_eq(roundtrip.document.lookup_object_or_null(5), updated_secret)
  let rendered = try! @pdflite.pdf_write_document(recrypted)
  let parsed = try! @pdflite.pdf_read_document_from_bytes(rendered)
  let read_decrypted = crypt_unwrap_decryption_result_for_test(
    try! parsed.decrypt_with_owner_password(@ascii.encode("owner")),
  )
  @test.assert_eq(
    read_decrypted.document.lookup_object_or_null(5),
    updated_secret,
  )
}

///|
test "PdfDocument encrypt_256bit_aesv3_iso_with_providers mirrors ISO AESV3 option" {
  let key_title = crypt_name_for_test("/Title")
  let doc = crypt_minimal_catalog_document_for_test(1, 7)
  let secret_object : @pdflite.PdfObject = PdfDictionary([
    (key_title, PdfString(@ascii.encode("aes3-iso-secret"))),
  ])
  doc.add_object_given_number(5, secret_object)
  let denied_permissions = @pdflite.pdf_permissions_of_p(-3904)
  let encrypted = try! doc.encrypt_256bit_aesv3_iso_with_providers(
    @ascii.encode("user"),
    @ascii.encode("owner"),
    denied_permissions,
    crypt_aesv3_r5_random_for_test,
    fn(object_number, generation, index) {
      crypt_aes_document_iv_for_test(object_number, generation, index)
    },
    encrypt_metadata=false,
    file_id=@ascii.encode("doc-id"),
  )
  @test.assert_eq(
    try! encrypted.what_encryption(),
    Some(PdfEncryptionAES256ISO(false)),
  )
  let values = try! encrypted.encryption_values()
  @test.assert_eq(values.crypt_type, PdfCryptAESV3(true))
  let decrypted = crypt_unwrap_decryption_result_for_test(
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
  let arc4_doc = crypt_document_with_stream_for_test(
    1, 4, object_number, arc4_plain,
  )
  let arc4_encrypted = arc4_doc.encrypt_40bit(
    @ascii.encode("user"),
    @ascii.encode("owner"),
    [PdfNoPrint],
    file_id=@ascii.encode("arc4-id"),
  )
  let arc4_rendered = @pdflite.pdf_write_document(arc4_encrypted)
  let arc4_decrypted = crypt_unwrap_decryption_result_for_test(
    @pdflite.pdf_read_document_from_bytes_with_passwords(
      arc4_rendered,
      user_password=Some(@ascii.encode("user")),
    ),
  )
  crypt_assert_deferred_stream_for_test(
    arc4_decrypted.document.lookup_object_or_null(object_number),
    fn(crypt) { crypt is PdfStreamDataArc4Decrypt(_, _, _, _) },
    arc4_plain,
  )
  let arc4_copy = arc4_decrypted.document.copy()
  crypt_assert_deferred_stream_for_test(
    arc4_copy.lookup_object_or_null(object_number),
    fn(crypt) { crypt is PdfStreamDataArc4Decrypt(_, _, _, _) },
    arc4_plain,
  )

  let aesv2_plain = @ascii.encode("lazy aesv2 stream")
  let aesv2_doc = crypt_document_with_stream_for_test(
    1, 5, object_number, aesv2_plain,
  )
  let aesv2_encrypted = aesv2_doc.encrypt_128bit_aesv2_with_iv_provider(
    @ascii.encode("user"),
    @ascii.encode("owner"),
    [PdfNoExtract],
    fn(object_number, generation, index) {
      crypt_aes_document_iv_for_test(object_number, generation, index)
    },
    file_id=@ascii.encode("aesv2-id"),
  )
  let aesv2_rendered = @pdflite.pdf_write_document(aesv2_encrypted)
  let aesv2_decrypted = crypt_unwrap_decryption_result_for_test(
    @pdflite.pdf_read_document_from_bytes_with_passwords(
      aesv2_rendered,
      user_password=Some(@ascii.encode("user")),
    ),
  )
  crypt_assert_deferred_stream_for_test(
    aesv2_decrypted.document.lookup_object_or_null(object_number),
    fn(crypt) { crypt is PdfStreamDataAesV2Decrypt(_, _, _, _) },
    aesv2_plain,
  )

  let aesv3_plain = @ascii.encode("lazy aesv3 stream")
  let aesv3_doc = crypt_document_with_stream_for_test(
    1, 7, object_number, aesv3_plain,
  )
  let aesv3_encrypted = aesv3_doc.encrypt_256bit_aesv3_with_providers(
    @ascii.encode("user"),
    @ascii.encode("owner"),
    [PdfNoCopy],
    crypt_aesv3_r5_random_for_test,
    fn(object_number, generation, index) {
      crypt_aes_document_iv_for_test(object_number, generation, index)
    },
    file_id=@ascii.encode("aesv3-id"),
  )
  let aesv3_rendered = @pdflite.pdf_write_document(aesv3_encrypted)
  let aesv3_decrypted = crypt_unwrap_decryption_result_for_test(
    @pdflite.pdf_read_document_from_bytes_with_passwords(
      aesv3_rendered,
      user_password=Some(@ascii.encode("user")),
    ),
  )
  crypt_assert_deferred_stream_for_test(
    aesv3_decrypted.document.lookup_object_or_null(object_number),
    fn(crypt) { crypt is PdfStreamDataAesV3Decrypt(_) },
    aesv3_plain,
  )
}

///|
test "PdfDocument AESV3 revision 6 recrypt supports incremental updates" {
  let key_title = crypt_name_for_test("/Title")
  let original_secret : @pdflite.PdfObject = PdfDictionary([
    (key_title, PdfString(@ascii.encode("aes3-r6-inc-original"))),
  ])
  let updated_secret : @pdflite.PdfObject = PdfDictionary([
    (key_title, PdfString(@ascii.encode("aes3-r6-inc-updated"))),
  ])
  let added_object : @pdflite.PdfObject = PdfString(
    @ascii.encode("aes3-r6-inc-added"),
  )
  let doc = try! crypt_aesv3_r6_document_with_object_for_test(
    1, 7, 5, original_secret,
  )
  let original = try! @pdflite.pdf_write_document(doc)
  let decrypted = crypt_unwrap_decryption_result_for_test(
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
      crypt_aes_document_iv_for_test(object_number, generation, index + 9)
    },
  )
  let classic = try! @pdflite.pdf_write_document_incremental_update(
    original, recrypted,
  )
  let classic_roundtrip = crypt_unwrap_decryption_result_for_test(
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
  let xref_decrypted = crypt_unwrap_decryption_result_for_test(
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
      crypt_aes_document_iv_for_test(object_number, generation, index + 10)
    },
  )
  let xref = try! @pdflite.pdf_write_document_incremental_update_with_xref_stream(
    xref_original, xref_recrypted,
  )
  @test.assert_eq(crypt_bytes_start_with_at(xref, xref_original, 0), true)
  let xref_roundtrip = crypt_unwrap_decryption_result_for_test(
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
  @test.assert_eq(crypt_bytes_start_with_at(compressed, xref_original, 0), true)
  let compressed_roundtrip = crypt_unwrap_decryption_result_for_test(
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
  let key_title = crypt_name_for_test("/Title")
  let original_secret : @pdflite.PdfObject = PdfDictionary([
    (key_title, PdfString(@ascii.encode("aes3-xref-original"))),
  ])
  let updated_secret : @pdflite.PdfObject = PdfDictionary([
    (key_title, PdfString(@ascii.encode("aes3-xref-updated"))),
  ])
  let added_object : @pdflite.PdfObject = PdfString(
    @ascii.encode("aes3-xref-added"),
  )
  let doc = try! crypt_aesv3_r5_document_with_object_for_test(
    1, 7, 5, original_secret,
  )
  let original = try! @pdflite.pdf_write_document_with_xref_stream(doc)
  let decrypted = crypt_unwrap_decryption_result_for_test(
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
      crypt_aes_document_iv_for_test(object_number, generation, index + 7)
    },
  )

  let rendered = try! @pdflite.pdf_write_document_incremental_update_with_xref_stream(
    original, recrypted,
  )
  @test.assert_eq(crypt_bytes_start_with_at(rendered, original, 0), true)
  let roundtrip = crypt_unwrap_decryption_result_for_test(
    try! @pdflite.pdf_read_document_from_bytes_with_passwords(
      rendered,
      user_password=Some(@ascii.encode("user")),
    ),
  )
  @test.assert_eq(roundtrip.document.lookup_object_or_null(5), updated_secret)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(8), added_object)
  @test.assert_eq(
    roundtrip.denied_permissions,
    @pdflite.pdf_permissions_of_p(-3904),
  )

  let compressed = try! @pdflite.pdf_write_document_incremental_update_with_compressed_xref_stream(
    original, recrypted,
  )
  @test.assert_eq(crypt_bytes_start_with_at(compressed, original, 0), true)
  let compressed_roundtrip = crypt_unwrap_decryption_result_for_test(
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
    @pdflite.pdf_permissions_of_p(-3904),
  )
}

///|
test "PdfDocument AESV3 recrypt supports classic incremental update" {
  let key_title = crypt_name_for_test("/Title")
  let original_secret : @pdflite.PdfObject = PdfDictionary([
    (key_title, PdfString(@ascii.encode("aes3-classic-original"))),
  ])
  let updated_secret : @pdflite.PdfObject = PdfDictionary([
    (key_title, PdfString(@ascii.encode("aes3-classic-updated"))),
  ])
  let added_object : @pdflite.PdfObject = PdfString(
    @ascii.encode("aes3-classic-added"),
  )
  let doc = try! crypt_aesv3_r5_document_with_object_for_test(
    1, 7, 5, original_secret,
  )
  let original = try! @pdflite.pdf_write_document(doc)
  let decrypted = crypt_unwrap_decryption_result_for_test(
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
      crypt_aes_document_iv_for_test(object_number, generation, index + 8)
    },
  )

  let rendered = try! @pdflite.pdf_write_document_incremental_update(
    original, recrypted,
  )
  @test.assert_eq(crypt_bytes_start_with_at(rendered, original, 0), true)
  let roundtrip = crypt_unwrap_decryption_result_for_test(
    try! @pdflite.pdf_read_document_from_bytes_with_passwords(
      rendered,
      owner_password=Some(@ascii.encode("owner")),
    ),
  )
  @test.assert_eq(roundtrip.document.lookup_object_or_null(5), updated_secret)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(8), added_object)
  @test.assert_eq(
    roundtrip.denied_permissions,
    @pdflite.pdf_permissions_of_p(-3904),
  )
}

///|
test "PdfDocument AESV2 recrypt supports xref stream incremental updates" {
  let key_title = crypt_name_for_test("/Title")
  let doc = crypt_minimal_catalog_document_for_test(1, 5)
  let original_secret : @pdflite.PdfObject = PdfDictionary([
    (key_title, PdfString(@ascii.encode("aes-original"))),
  ])
  let updated_secret : @pdflite.PdfObject = PdfDictionary([
    (key_title, PdfString(@ascii.encode("aes-updated"))),
  ])
  let added_object : @pdflite.PdfObject = PdfString(
    @ascii.encode("aes-added-incremental"),
  )
  doc.add_object_given_number(5, original_secret)
  let encrypted = try! doc.encrypt_128bit_aesv2_with_iv_provider(
    @ascii.encode("user"),
    @ascii.encode("owner"),
    [PdfNoExtract],
    fn(object_number, generation, index) {
      crypt_aes_document_iv_for_test(object_number, generation, index)
    },
    encrypt_metadata=true,
    file_id=@ascii.encode("doc-id"),
  )
  let original = try! @pdflite.pdf_write_document_with_xref_stream(encrypted)
  let decrypted = crypt_unwrap_decryption_result_for_test(
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
      crypt_aes_document_iv_for_test(object_number, generation, index + 6)
    },
  )

  let rendered = try! @pdflite.pdf_write_document_incremental_update_with_xref_stream(
    original, recrypted,
  )
  @test.assert_eq(crypt_bytes_start_with_at(rendered, original, 0), true)
  let roundtrip = crypt_unwrap_decryption_result_for_test(
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
  @test.assert_eq(crypt_bytes_start_with_at(compressed, original, 0), true)
  let compressed_roundtrip = crypt_unwrap_decryption_result_for_test(
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
  let key_title = crypt_name_for_test("/Title")
  let doc = crypt_minimal_catalog_document_for_test(1, 4)
  let original_secret : @pdflite.PdfObject = PdfDictionary([
    (key_title, PdfString(@ascii.encode("aes-classic-original"))),
  ])
  let updated_secret : @pdflite.PdfObject = PdfDictionary([
    (key_title, PdfString(@ascii.encode("aes-classic-updated"))),
  ])
  let added_object : @pdflite.PdfObject = PdfString(
    @ascii.encode("aes-classic-added"),
  )
  doc.add_object_given_number(5, original_secret)
  let encrypted = try! doc.encrypt_128bit_aesv2_with_iv_provider(
    @ascii.encode("user"),
    @ascii.encode("owner"),
    [PdfNoForms],
    fn(object_number, generation, index) {
      crypt_aes_document_iv_for_test(object_number, generation, index)
    },
    encrypt_metadata=true,
    file_id=@ascii.encode("doc-id"),
  )
  let original = try! @pdflite.pdf_write_document(encrypted)
  let decrypted = crypt_unwrap_decryption_result_for_test(
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
      crypt_aes_document_iv_for_test(object_number, generation, index + 9)
    },
  )
  let rendered = try! @pdflite.pdf_write_document_incremental_update(
    original, recrypted,
  )
  @test.assert_eq(crypt_bytes_start_with_at(rendered, original, 0), true)
  let roundtrip = crypt_unwrap_decryption_result_for_test(
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
  let key_type = crypt_name_for_test("/Type")
  let key_catalog = crypt_name_for_test("/Catalog")
  let key_pages = crypt_name_for_test("/Pages")
  let key_kids = crypt_name_for_test("/Kids")
  let key_count = crypt_name_for_test("/Count")
  let key_title = crypt_name_for_test("/Title")
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
  let original_secret : @pdflite.PdfObject = PdfDictionary([
    (key_title, PdfString(@ascii.encode("original"))),
  ])
  let updated_secret : @pdflite.PdfObject = PdfDictionary([
    (key_title, PdfString(@ascii.encode("updated"))),
  ])
  let added_object : @pdflite.PdfObject = PdfString(@ascii.encode("added"))
  doc.add_object_given_number(5, original_secret)
  let encrypted = try! doc.encrypt_128bit_r4(
    @ascii.encode("user"),
    @ascii.encode("owner"),
    [PdfNoPrint],
    encrypt_metadata=true,
    file_id=@ascii.encode("doc-id"),
  )
  let original = try! @pdflite.pdf_write_document(encrypted)
  let decrypted = crypt_unwrap_decryption_result_for_test(
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
  @test.assert_eq(crypt_bytes_start_with_at(rendered, original, 0), true)
  let roundtrip = crypt_unwrap_decryption_result_for_test(
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
  let key_type = crypt_name_for_test("/Type")
  let key_catalog = crypt_name_for_test("/Catalog")
  let key_pages = crypt_name_for_test("/Pages")
  let key_kids = crypt_name_for_test("/Kids")
  let key_count = crypt_name_for_test("/Count")
  let key_title = crypt_name_for_test("/Title")
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
  let original_secret : @pdflite.PdfObject = PdfDictionary([
    (key_title, PdfString(@ascii.encode("original-xref"))),
  ])
  let updated_secret : @pdflite.PdfObject = PdfDictionary([
    (key_title, PdfString(@ascii.encode("updated-xref"))),
  ])
  let added_object : @pdflite.PdfObject = PdfString(@ascii.encode("xref-added"))
  doc.add_object_given_number(5, original_secret)
  let encrypted = try! doc.encrypt_128bit_r4(
    @ascii.encode("user"),
    @ascii.encode("owner"),
    [PdfNoCopy],
    encrypt_metadata=true,
    file_id=@ascii.encode("doc-id"),
  )
  let original = try! @pdflite.pdf_write_document_with_xref_stream(encrypted)
  let decrypted = crypt_unwrap_decryption_result_for_test(
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
  @test.assert_eq(crypt_bytes_start_with_at(rendered, original, 0), true)
  let roundtrip = crypt_unwrap_decryption_result_for_test(
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
  @test.assert_eq(crypt_bytes_start_with_at(compressed, original, 0), true)
  let compressed_roundtrip = crypt_unwrap_decryption_result_for_test(
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

///|
test "PdfDocument encrypt_128bit encrypts parsed objects and writes length" {
  let key_title = crypt_name_for_test("/Title")
  let key_encrypt = crypt_name_for_test("/Encrypt")
  let key_v = crypt_name_for_test("/V")
  let key_r = crypt_name_for_test("/R")
  let key_length = crypt_name_for_test("/Length")
  let key_p = crypt_name_for_test("/P")
  let doc = @pdflite.pdf_document_empty()
  let plain_object : @pdflite.PdfObject = PdfDictionary([
    (key_title, PdfString(@ascii.encode("hello"))),
  ])
  doc.add_object_given_number(1, plain_object)
  let encrypted = try! doc.encrypt_128bit(
    @ascii.encode("user"),
    @ascii.encode("owner"),
    [PdfNoPrint, PdfNoCopy],
    file_id=@ascii.encode("doc-id"),
  )
  let permissions = @pdflite.pdf_p_of_permissions([PdfNoPrint, PdfNoCopy])
  let values = try! encrypted.encryption_values()
  guard encrypted.lookup_object_or_null(1).lookup_immediate(key_title)
    is Some(PdfString(encrypted_title)) else {
    fail("expected encrypted title")
  }
  @test.assert_eq(encrypted_title == @ascii.encode("hello"), false)
  guard encrypted.trailer_dict().lookup_immediate(key_encrypt)
    is Some(PdfIndirect(encrypt_number)) else {
    fail("expected indirect encryption dictionary")
  }
  let encrypt_dictionary = encrypted.lookup_object_or_null(encrypt_number)
  @test.assert_eq(
    encrypt_dictionary.lookup_immediate(key_v),
    Some(PdfInteger(2)),
  )
  @test.assert_eq(
    encrypt_dictionary.lookup_immediate(key_r),
    Some(PdfInteger(3)),
  )
  @test.assert_eq(
    encrypt_dictionary.lookup_immediate(key_length),
    Some(PdfInteger(128)),
  )
  @test.assert_eq(
    encrypt_dictionary.lookup_immediate(key_p),
    Some(PdfInteger(permissions)),
  )
  @test.assert_eq(values.crypt_type, PdfCryptARC4(128, 3))
  let decrypted = crypt_unwrap_decryption_result_for_test(
    try! encrypted.decrypt_with_user_password(@ascii.encode("user")),
  )
  @test.assert_eq(decrypted.document.lookup_object_or_null(1), plain_object)
  @test.assert_eq(decrypted.denied_permissions, [PdfNoCopy, PdfNoPrint])
  let owner_decrypted = crypt_unwrap_decryption_result_for_test(
    try! encrypted.decrypt_with_owner_password(@ascii.encode("owner")),
  )
  @test.assert_eq(
    owner_decrypted.document.lookup_object_or_null(1),
    plain_object,
  )
}

///|
test "PdfDocument encrypt_128bit_r4 writes crypt filter and honors metadata flag" {
  let key_title = crypt_name_for_test("/Title")
  let key_encrypt = crypt_name_for_test("/Encrypt")
  let key_filter = crypt_name_for_test("/Filter")
  let key_standard = crypt_name_for_test("/Standard")
  let key_v = crypt_name_for_test("/V")
  let key_r = crypt_name_for_test("/R")
  let key_length = crypt_name_for_test("/Length")
  let key_p = crypt_name_for_test("/P")
  let key_cf = crypt_name_for_test("/CF")
  let key_stdcf = crypt_name_for_test("/StdCF")
  let key_auth_event = crypt_name_for_test("/AuthEvent")
  let key_doc_open = crypt_name_for_test("/DocOpen")
  let key_cfm = crypt_name_for_test("/CFM")
  let key_v2 = crypt_name_for_test("/V2")
  let key_encrypt_metadata = crypt_name_for_test("/EncryptMetadata")
  let key_strf = crypt_name_for_test("/StrF")
  let key_stmf = crypt_name_for_test("/StmF")
  let key_type = crypt_name_for_test("/Type")
  let key_metadata = crypt_name_for_test("/Metadata")
  let doc = @pdflite.pdf_document_empty()
  let plain_object : @pdflite.PdfObject = PdfDictionary([
    (key_title, PdfString(@ascii.encode("hello"))),
  ])
  let metadata_stream = crypt_stream_for_test(
    [
      (crypt_name_for_test("/Length"), PdfInteger(4)),
      (key_type, PdfNameObject(key_metadata)),
      (key_title, PdfString(@ascii.encode("meta"))),
    ],
    @ascii.encode("data"),
  )
  doc.add_object_given_number(1, plain_object)
  doc.add_object_given_number(3, metadata_stream)
  let encrypted = try! doc.encrypt_128bit_r4(
    @ascii.encode("user"),
    @ascii.encode("owner"),
    [PdfNoExtract],
    encrypt_metadata=false,
    file_id=@ascii.encode("doc-id"),
  )
  let permissions = @pdflite.pdf_p_of_permissions([PdfNoExtract])
  guard encrypted.lookup_object_or_null(1).lookup_immediate(key_title)
    is Some(PdfString(encrypted_title)) else {
    fail("expected encrypted title")
  }
  @test.assert_eq(encrypted_title == @ascii.encode("hello"), false)
  @test.assert_eq(encrypted.lookup_object_or_null(3), metadata_stream)
  guard encrypted.trailer_dict().lookup_immediate(key_encrypt)
    is Some(PdfIndirect(encrypt_number)) else {
    fail("expected indirect encryption dictionary")
  }
  let encrypt_dictionary = encrypted.lookup_object_or_null(encrypt_number)
  @test.assert_eq(
    encrypt_dictionary.lookup_immediate(key_filter),
    Some(PdfNameObject(key_standard)),
  )
  @test.assert_eq(
    encrypt_dictionary.lookup_immediate(key_v),
    Some(PdfInteger(4)),
  )
  @test.assert_eq(
    encrypt_dictionary.lookup_immediate(key_r),
    Some(PdfInteger(4)),
  )
  @test.assert_eq(
    encrypt_dictionary.lookup_immediate(key_length),
    Some(PdfInteger(128)),
  )
  @test.assert_eq(
    encrypt_dictionary.lookup_immediate(key_p),
    Some(PdfInteger(permissions)),
  )
  @test.assert_eq(
    encrypt_dictionary.lookup_immediate(key_encrypt_metadata),
    Some(PdfBoolean(false)),
  )
  @test.assert_eq(
    encrypt_dictionary.lookup_immediate(key_strf),
    Some(PdfNameObject(key_stdcf)),
  )
  @test.assert_eq(
    encrypt_dictionary.lookup_immediate(key_stmf),
    Some(PdfNameObject(key_stdcf)),
  )
  guard encrypt_dictionary.lookup_immediate(key_cf) is Some(cf_dictionary) else {
    fail("expected crypt filter dictionary")
  }
  guard cf_dictionary.lookup_immediate(key_stdcf) is Some(std_cf_dictionary) else {
    fail("expected standard crypt filter")
  }
  @test.assert_eq(
    std_cf_dictionary.lookup_immediate(key_length),
    Some(PdfInteger(16)),
  )
  @test.assert_eq(
    std_cf_dictionary.lookup_immediate(key_auth_event),
    Some(PdfNameObject(key_doc_open)),
  )
  @test.assert_eq(
    std_cf_dictionary.lookup_immediate(key_cfm),
    Some(PdfNameObject(key_v2)),
  )
  let values = try! encrypted.encryption_values()
  @test.assert_eq(values.crypt_type, PdfCryptARC4(128, 4))
  @test.assert_eq(values.encrypt_metadata, false)
  let decrypted = crypt_unwrap_decryption_result_for_test(
    try! encrypted.decrypt_with_user_password(@ascii.encode("user")),
  )
  @test.assert_eq(decrypted.document.lookup_object_or_null(1), plain_object)
  @test.assert_eq(decrypted.document.lookup_object_or_null(3), metadata_stream)
  @test.assert_eq(
    decrypted.denied_permissions,
    @pdflite.pdf_permissions_of_p(permissions),
  )
  let owner_decrypted = crypt_unwrap_decryption_result_for_test(
    try! encrypted.decrypt_with_owner_password(@ascii.encode("owner")),
  )
  @test.assert_eq(
    owner_decrypted.document.lookup_object_or_null(1),
    plain_object,
  )
  @test.assert_eq(doc.lookup_object_or_null(1), plain_object)
  @test.assert_eq(doc.lookup_object_or_null(3), metadata_stream)
}

///|
test "PdfDocument encrypt_128bit_aesv2_with_iv_provider writes AES crypt filter" {
  let key_catalog = crypt_name_for_test("/Catalog")
  let key_pages = crypt_name_for_test("/Pages")
  let key_kids = crypt_name_for_test("/Kids")
  let key_count = crypt_name_for_test("/Count")
  let key_title = crypt_name_for_test("/Title")
  let key_encrypt = crypt_name_for_test("/Encrypt")
  let key_filter = crypt_name_for_test("/Filter")
  let key_standard = crypt_name_for_test("/Standard")
  let key_cf = crypt_name_for_test("/CF")
  let key_stdcf = crypt_name_for_test("/StdCF")
  let key_cfm = crypt_name_for_test("/CFM")
  let key_aesv2 = crypt_name_for_test("/AESV2")
  let key_encrypt_metadata = crypt_name_for_test("/EncryptMetadata")
  let key_type = crypt_name_for_test("/Type")
  let key_metadata = crypt_name_for_test("/Metadata")
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
  let secret_object : @pdflite.PdfObject = PdfDictionary([
    (key_title, PdfString(@ascii.encode("secret"))),
  ])
  let metadata_stream = crypt_stream_for_test(
    [
      (crypt_name_for_test("/Length"), PdfInteger(4)),
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
      crypt_aes_document_iv_for_test(object_number, generation, index)
    },
    encrypt_metadata=false,
    file_id=@ascii.encode("doc-id"),
  )
  @test.assert_eq(encrypted.lookup_object_or_null(6), metadata_stream)
  guard encrypted.trailer_dict().lookup_immediate(key_encrypt)
    is Some(PdfIndirect(encrypt_number)) else {
    fail("expected indirect AES encryption dictionary")
  }
  let encrypt_dictionary = encrypted.lookup_object_or_null(encrypt_number)
  @test.assert_eq(
    encrypt_dictionary.lookup_immediate(key_filter),
    Some(PdfNameObject(key_standard)),
  )
  @test.assert_eq(
    encrypt_dictionary.lookup_immediate(key_encrypt_metadata),
    Some(PdfBoolean(false)),
  )
  guard encrypt_dictionary.lookup_immediate(key_cf) is Some(cf_dictionary) else {
    fail("expected AES crypt filter dictionary")
  }
  guard cf_dictionary.lookup_immediate(key_stdcf) is Some(std_cf_dictionary) else {
    fail("expected standard AES crypt filter")
  }
  @test.assert_eq(
    std_cf_dictionary.lookup_immediate(key_cfm),
    Some(PdfNameObject(key_aesv2)),
  )
  let values = try! encrypted.encryption_values()
  @test.assert_eq(values.crypt_type, PdfCryptAESV2)
  @test.assert_eq(values.encrypt_metadata, false)
  let decrypted = crypt_unwrap_decryption_result_for_test(
    try! encrypted.decrypt_with_user_password(@ascii.encode("user")),
  )
  @test.assert_eq(decrypted.document.lookup_object_or_null(5), secret_object)
  @test.assert_eq(decrypted.document.lookup_object_or_null(6), metadata_stream)
  @test.assert_eq(decrypted.denied_permissions, [PdfNoPrint])

  let rendered = try! @pdflite.pdf_write_document(encrypted)
  let parsed = try! @pdflite.pdf_read_document_from_bytes(rendered)
  let read_decrypted = crypt_unwrap_decryption_result_for_test(
    try! parsed.decrypt_with_owner_password(@ascii.encode("owner")),
  )
  @test.assert_eq(
    read_decrypted.document.lookup_object_or_null(5),
    secret_object,
  )
  try! crypt_assert_equivalent_object_for_test(
    read_decrypted.document.lookup_object_or_null(6),
    metadata_stream,
  )
}

///|
test "pdfencrypt-style AES128 blank-user owner-password output roundtrips" {
  let key_title = crypt_name_for_test("/Title")
  let doc = crypt_minimal_catalog_document_for_test(1, 4)
  let secret_object : @pdflite.PdfObject = PdfDictionary([
    (key_title, PdfString(@ascii.encode("pdfencrypt-secret"))),
  ])
  doc.add_object_given_number(5, secret_object)
  let denied : Array[@pdflite.PdfPermission] = [PdfNoEdit, PdfNoPrint]
  let encrypted = try! doc.encrypt_128bit_aesv2_with_iv_provider(
    @ascii.encode(""),
    @ascii.encode("owner-password"),
    denied,
    fn(object_number, generation, index) {
      crypt_aes_document_iv_for_test(object_number, generation, index)
    },
    encrypt_metadata=false,
    file_id=@ascii.encode("pdfencrypt-doc-id"),
  )
  @test.assert_eq(try! encrypted.permissions(), denied)
  @test.assert_eq(encrypted.is_encrypted(), true)
  let rendered = try! @pdflite.pdf_write_document(encrypted)
  let parsed = try! @pdflite.pdf_read_document_from_bytes(rendered)
  @test.assert_eq(try! parsed.permissions(), denied)
  let user_decrypted = crypt_unwrap_decryption_result_for_test(
    try! parsed.decrypt_with_user_password(@ascii.encode("")),
  )
  @test.assert_eq(user_decrypted.denied_permissions, denied)
  @test.assert_eq(
    user_decrypted.document.lookup_object_or_null(5),
    secret_object,
  )
  let owner_decrypted = crypt_unwrap_decryption_result_for_test(
    try! parsed.decrypt_with_owner_password(@ascii.encode("owner-password")),
  )
  @test.assert_eq(owner_decrypted.denied_permissions, denied)
  @test.assert_eq(
    owner_decrypted.document.lookup_object_or_null(5),
    secret_object,
  )
}

///|
test "PdfDocument encrypt_256bit_aesv3_with_providers writes AESV3 revision 5 encryption" {
  let key_type = crypt_name_for_test("/Type")
  let key_title = crypt_name_for_test("/Title")
  let key_metadata = crypt_name_for_test("/Metadata")
  let key_encrypt = crypt_name_for_test("/Encrypt")
  let key_cf = crypt_name_for_test("/CF")
  let key_stdcf = crypt_name_for_test("/StdCF")
  let key_cfm = crypt_name_for_test("/CFM")
  let key_aesv3 = crypt_name_for_test("/AESV3")
  let key_encrypt_metadata = crypt_name_for_test("/EncryptMetadata")
  let key_oe = crypt_name_for_test("/OE")
  let key_ue = crypt_name_for_test("/UE")
  let key_perms = crypt_name_for_test("/Perms")
  let doc = crypt_minimal_catalog_document_for_test(1, 7)
  let secret_object : @pdflite.PdfObject = PdfDictionary([
    (key_title, PdfString(@ascii.encode("aes3-secret"))),
  ])
  let metadata_stream = crypt_stream_for_test(
    [
      (crypt_name_for_test("/Length"), PdfInteger(4)),
      (key_type, PdfNameObject(key_metadata)),
      (key_title, PdfString(@ascii.encode("meta"))),
    ],
    @ascii.encode("data"),
  )
  doc.add_object_given_number(5, secret_object)
  doc.add_object_given_number(6, metadata_stream)
  let denied_permissions = @pdflite.pdf_permissions_of_p(-3904)
  let encrypted = try! doc.encrypt_256bit_aesv3_with_providers(
    @ascii.encode("user"),
    @ascii.encode("owner"),
    denied_permissions,
    crypt_aesv3_r5_random_for_test,
    fn(object_number, generation, index) {
      crypt_aes_document_iv_for_test(object_number, generation, index)
    },
    encrypt_metadata=false,
    file_id=@ascii.encode("doc-id"),
  )
  @test.assert_eq(encrypted.lookup_object_or_null(6), metadata_stream)
  @test.assert_eq(
    try! encrypted.what_encryption(),
    Some(PdfEncryptionAES256(false)),
  )
  guard encrypted.trailer_dict().lookup_immediate(key_encrypt)
    is Some(PdfIndirect(encrypt_number)) else {
    fail("expected indirect AESV3 encryption dictionary")
  }
  let encrypt_dictionary = encrypted.lookup_object_or_null(encrypt_number)
  @test.assert_eq(
    encrypt_dictionary.lookup_immediate(key_encrypt_metadata),
    Some(PdfBoolean(false)),
  )
  @test.assert_eq(
    encrypt_dictionary.lookup_immediate(key_ue),
    Some(PdfString(crypt_aesv3_r5_user_encryption_key_for_test())),
  )
  @test.assert_eq(
    encrypt_dictionary.lookup_immediate(key_oe),
    Some(PdfString(crypt_aesv3_r5_owner_encryption_key_for_test())),
  )
  @test.assert_eq(
    encrypt_dictionary.lookup_immediate(key_perms),
    Some(PdfString(crypt_aesv3_r5_permissions_for_test(encrypt_metadata=false))),
  )
  guard encrypt_dictionary.lookup_immediate(key_cf) is Some(cf_dictionary) else {
    fail("expected AESV3 crypt filter dictionary")
  }
  guard cf_dictionary.lookup_immediate(key_stdcf) is Some(std_cf_dictionary) else {
    fail("expected standard AESV3 crypt filter")
  }
  @test.assert_eq(
    std_cf_dictionary.lookup_immediate(key_cfm),
    Some(PdfNameObject(key_aesv3)),
  )
  let values = try! encrypted.encryption_values()
  @test.assert_eq(values.crypt_type, PdfCryptAESV3(false))
  @test.assert_eq(values.user_entry, crypt_aesv3_r5_user_entry_for_test())
  @test.assert_eq(values.owner_entry, crypt_aesv3_r5_owner_entry_for_test())
  @test.assert_eq(
    values.user_encryption_key,
    Some(crypt_aesv3_r5_user_encryption_key_for_test()),
  )
  @test.assert_eq(
    values.owner_encryption_key,
    Some(crypt_aesv3_r5_owner_encryption_key_for_test()),
  )
  @test.assert_eq(
    values.permissions_entry,
    Some(crypt_aesv3_r5_permissions_for_test(encrypt_metadata=false)),
  )
  let decrypted = crypt_unwrap_decryption_result_for_test(
    try! encrypted.decrypt_with_user_password(@ascii.encode("user")),
  )
  @test.assert_eq(decrypted.document.lookup_object_or_null(5), secret_object)
  @test.assert_eq(decrypted.document.lookup_object_or_null(6), metadata_stream)
  @test.assert_eq(decrypted.denied_permissions, denied_permissions)
  let owner_decrypted = crypt_unwrap_decryption_result_for_test(
    try! encrypted.decrypt_with_owner_password(@ascii.encode("owner")),
  )
  @test.assert_eq(
    owner_decrypted.document.lookup_object_or_null(5),
    secret_object,
  )

  let rendered = try! @pdflite.pdf_write_document(encrypted)
  let parsed = try! @pdflite.pdf_read_document_from_bytes(rendered)
  let read_decrypted = crypt_unwrap_decryption_result_for_test(
    try! parsed.decrypt_with_owner_password(@ascii.encode("owner")),
  )
  @test.assert_eq(
    read_decrypted.document.lookup_object_or_null(5),
    secret_object,
  )
  try! crypt_assert_equivalent_object_for_test(
    read_decrypted.document.lookup_object_or_null(6),
    metadata_stream,
  )

  let bad_random = fn(
    field : @pdflite.PdfAesV3RandomField,
    length : Int,
  ) -> @pdflite.PdfBytes raise @pdflite.PdfError {
    match field {
      PdfAesV3UserKeySalt => Bytes::new(7)
      _ => crypt_aesv3_r5_random_for_test(field, length)
    }
  }
  let bad_provider : Result[@pdflite.PdfDocument, Error] = try? doc.encrypt_256bit_aesv3_with_providers(
    @ascii.encode("user"),
    @ascii.encode("owner"),
    denied_permissions,
    bad_random,
    fn(object_number, generation, index) {
      crypt_aes_document_iv_for_test(object_number, generation, index)
    },
    file_id=@ascii.encode("doc-id"),
  )
  guard bad_provider
    is Err(@pdflite.PdfError::EncryptionDictionaryEntryTooShort(name)) &&
    name == crypt_name_for_test("/UserKeySalt") else {
    fail("expected short AESV3 random field")
  }
}

///|
test "PdfDocument encrypted AESV3 output round trips through xref stream writers" {
  let key_type = crypt_name_for_test("/Type")
  let key_title = crypt_name_for_test("/Title")
  let key_metadata = crypt_name_for_test("/Metadata")
  let key_encrypt = crypt_name_for_test("/Encrypt")
  let doc = crypt_minimal_catalog_document_for_test(1, 7)
  let secret_object : @pdflite.PdfObject = PdfDictionary([
    (key_title, PdfString(@ascii.encode("secret-aes3-xref"))),
  ])
  let metadata_stream = crypt_stream_for_test(
    [
      (crypt_name_for_test("/Length"), PdfInteger(4)),
      (key_type, PdfNameObject(key_metadata)),
      (key_title, PdfString(@ascii.encode("meta"))),
    ],
    @ascii.encode("data"),
  )
  doc.add_object_given_number(5, secret_object)
  doc.add_object_given_number(6, metadata_stream)
  let denied_permissions = @pdflite.pdf_permissions_of_p(-3904)
  let encrypted = try! doc.encrypt_256bit_aesv3_with_providers(
    @ascii.encode("user"),
    @ascii.encode("owner"),
    denied_permissions,
    crypt_aesv3_r5_random_for_test,
    fn(object_number, generation, index) {
      crypt_aes_document_iv_for_test(object_number, generation, index)
    },
    encrypt_metadata=false,
    file_id=@ascii.encode("doc-id"),
  )

  let rendered = try! @pdflite.pdf_write_document_with_xref_stream(encrypted)
  let parsed = try! @pdflite.pdf_read_document_from_bytes(rendered)
  @test.assert_eq(parsed.is_encrypted(), true)
  @test.assert_eq(
    parsed.trailer_dict().lookup_immediate(key_encrypt) is Some(PdfIndirect(_)),
    true,
  )
  let decrypted = crypt_unwrap_decryption_result_for_test(
    try! parsed.decrypt_with_user_password(@ascii.encode("user")),
  )
  @test.assert_eq(decrypted.document.lookup_object_or_null(5), secret_object)
  try! crypt_assert_equivalent_object_for_test(
    decrypted.document.lookup_object_or_null(6),
    metadata_stream,
  )
  @test.assert_eq(decrypted.denied_permissions, denied_permissions)

  let compressed = try! @pdflite.pdf_write_document_with_compressed_xref_stream(
    encrypted,
  )
  let compressed_decrypted = crypt_unwrap_decryption_result_for_test(
    try! @pdflite.pdf_read_document_from_bytes_with_passwords(
      compressed,
      user_password=Some(@ascii.encode("bad")),
      owner_password=Some(@ascii.encode("owner")),
    ),
  )
  @test.assert_eq(
    compressed_decrypted.document.lookup_object_or_null(5),
    secret_object,
  )
  try! crypt_assert_equivalent_object_for_test(
    compressed_decrypted.document.lookup_object_or_null(6),
    metadata_stream,
  )
  @test.assert_eq(compressed_decrypted.denied_permissions, denied_permissions)
}

///|
test "PdfDocument encrypted AESV2 output round trips through xref stream writers" {
  let key_type = crypt_name_for_test("/Type")
  let key_title = crypt_name_for_test("/Title")
  let key_metadata = crypt_name_for_test("/Metadata")
  let key_encrypt = crypt_name_for_test("/Encrypt")
  let doc = crypt_minimal_catalog_document_for_test(1, 5)
  let secret_object : @pdflite.PdfObject = PdfDictionary([
    (key_title, PdfString(@ascii.encode("secret-aes-xref"))),
  ])
  let metadata_stream = crypt_stream_for_test(
    [
      (crypt_name_for_test("/Length"), PdfInteger(4)),
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
    [PdfNoCopy],
    fn(object_number, generation, index) {
      crypt_aes_document_iv_for_test(object_number, generation, index)
    },
    encrypt_metadata=false,
    file_id=@ascii.encode("doc-id"),
  )

  let rendered = try! @pdflite.pdf_write_document_with_xref_stream(encrypted)
  let parsed = try! @pdflite.pdf_read_document_from_bytes(rendered)
  @test.assert_eq(parsed.is_encrypted(), true)
  @test.assert_eq(
    parsed.trailer_dict().lookup_immediate(key_encrypt) is Some(PdfIndirect(_)),
    true,
  )
  let decrypted = crypt_unwrap_decryption_result_for_test(
    try! parsed.decrypt_with_user_password(@ascii.encode("user")),
  )
  @test.assert_eq(decrypted.document.lookup_object_or_null(5), secret_object)
  try! crypt_assert_equivalent_object_for_test(
    decrypted.document.lookup_object_or_null(6),
    metadata_stream,
  )
  @test.assert_eq(decrypted.denied_permissions, [PdfNoCopy])

  let compressed = try! @pdflite.pdf_write_document_with_compressed_xref_stream(
    encrypted,
  )
  let compressed_decrypted = crypt_unwrap_decryption_result_for_test(
    try! @pdflite.pdf_read_document_from_bytes_with_passwords(
      compressed,
      user_password=Some(@ascii.encode("bad")),
      owner_password=Some(@ascii.encode("owner")),
    ),
  )
  @test.assert_eq(
    compressed_decrypted.document.lookup_object_or_null(5),
    secret_object,
  )
  try! crypt_assert_equivalent_object_for_test(
    compressed_decrypted.document.lookup_object_or_null(6),
    metadata_stream,
  )
  @test.assert_eq(compressed_decrypted.denied_permissions, [PdfNoCopy])
}

///|
test "PdfDocument encrypted ARC4 output round trips through writer and reader" {
  let key_type = crypt_name_for_test("/Type")
  let key_catalog = crypt_name_for_test("/Catalog")
  let key_pages = crypt_name_for_test("/Pages")
  let key_kids = crypt_name_for_test("/Kids")
  let key_count = crypt_name_for_test("/Count")
  let key_title = crypt_name_for_test("/Title")
  let key_metadata = crypt_name_for_test("/Metadata")
  let key_encrypt = crypt_name_for_test("/Encrypt")
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
  let secret_object : @pdflite.PdfObject = PdfDictionary([
    (key_title, PdfString(@ascii.encode("secret"))),
  ])
  let metadata_stream = crypt_stream_for_test(
    [
      (crypt_name_for_test("/Length"), PdfInteger(4)),
      (key_type, PdfNameObject(key_metadata)),
      (key_title, PdfString(@ascii.encode("meta"))),
    ],
    @ascii.encode("data"),
  )
  doc.add_object_given_number(5, secret_object)
  doc.add_object_given_number(6, metadata_stream)
  let encrypted = try! doc.encrypt_128bit_r4(
    @ascii.encode("user"),
    @ascii.encode("owner"),
    [PdfNoPrint],
    encrypt_metadata=false,
    file_id=@ascii.encode("doc-id"),
  )
  let rendered = try! @pdflite.pdf_write_document(encrypted)
  let parsed = try! @pdflite.pdf_read_document_from_bytes(rendered)
  @test.assert_eq(parsed.is_encrypted(), true)
  @test.assert_eq(
    parsed.trailer_dict().lookup_immediate(key_encrypt) is Some(PdfIndirect(_)),
    true,
  )
  let decrypted = crypt_unwrap_decryption_result_for_test(
    try! parsed.decrypt_with_user_password(@ascii.encode("user")),
  )
  @test.assert_eq(decrypted.document.is_encrypted(), false)
  @test.assert_eq(decrypted.document.lookup_object_or_null(5), secret_object)
  try! crypt_assert_equivalent_object_for_test(
    decrypted.document.lookup_object_or_null(6),
    metadata_stream,
  )
  @test.assert_eq(decrypted.denied_permissions, [PdfNoPrint])
  let read_owner_decrypted = crypt_unwrap_decryption_result_for_test(
    try! @pdflite.pdf_read_document_from_bytes_with_passwords(
      rendered,
      user_password=Some(@ascii.encode("bad")),
      owner_password=Some(@ascii.encode("owner")),
    ),
  )
  @test.assert_eq(
    read_owner_decrypted.document.lookup_object_or_null(5),
    secret_object,
  )
  try! crypt_assert_equivalent_object_for_test(
    read_owner_decrypted.document.lookup_object_or_null(6),
    metadata_stream,
  )
  @test.assert_eq(read_owner_decrypted.denied_permissions, [PdfNoPrint])
  @test.assert_eq(
    try! @pdflite.pdf_read_document_from_bytes_with_passwords(
      rendered,
      user_password=Some(@ascii.encode("bad")),
    ),
    None,
  )
}

///|
test "PdfDocument encrypted ARC4 output round trips through xref stream writers" {
  let key_type = crypt_name_for_test("/Type")
  let key_catalog = crypt_name_for_test("/Catalog")
  let key_pages = crypt_name_for_test("/Pages")
  let key_kids = crypt_name_for_test("/Kids")
  let key_count = crypt_name_for_test("/Count")
  let key_title = crypt_name_for_test("/Title")
  let key_metadata = crypt_name_for_test("/Metadata")
  let key_encrypt = crypt_name_for_test("/Encrypt")
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
  let secret_object : @pdflite.PdfObject = PdfDictionary([
    (key_title, PdfString(@ascii.encode("secret-xref"))),
  ])
  let metadata_stream = crypt_stream_for_test(
    [
      (crypt_name_for_test("/Length"), PdfInteger(4)),
      (key_type, PdfNameObject(key_metadata)),
      (key_title, PdfString(@ascii.encode("meta"))),
    ],
    @ascii.encode("data"),
  )
  doc.add_object_given_number(5, secret_object)
  doc.add_object_given_number(6, metadata_stream)
  let encrypted = try! doc.encrypt_128bit_r4(
    @ascii.encode("user"),
    @ascii.encode("owner"),
    [PdfNoPrint],
    encrypt_metadata=false,
    file_id=@ascii.encode("doc-id"),
  )

  let rendered = try! @pdflite.pdf_write_document_with_xref_stream(encrypted)
  let parsed = try! @pdflite.pdf_read_document_from_bytes(rendered)
  @test.assert_eq(parsed.is_encrypted(), true)
  @test.assert_eq(
    parsed.trailer_dict().lookup_immediate(key_encrypt) is Some(PdfIndirect(_)),
    true,
  )
  let decrypted = crypt_unwrap_decryption_result_for_test(
    try! parsed.decrypt_with_user_password(@ascii.encode("user")),
  )
  @test.assert_eq(decrypted.document.lookup_object_or_null(5), secret_object)
  try! crypt_assert_equivalent_object_for_test(
    decrypted.document.lookup_object_or_null(6),
    metadata_stream,
  )
  @test.assert_eq(decrypted.denied_permissions, [PdfNoPrint])

  let compressed = try! @pdflite.pdf_write_document_with_compressed_xref_stream(
    encrypted,
  )
  let compressed_decrypted = crypt_unwrap_decryption_result_for_test(
    try! @pdflite.pdf_read_document_from_bytes_with_passwords(
      compressed,
      user_password=Some(@ascii.encode("bad")),
      owner_password=Some(@ascii.encode("owner")),
    ),
  )
  @test.assert_eq(
    compressed_decrypted.document.lookup_object_or_null(5),
    secret_object,
  )
  try! crypt_assert_equivalent_object_for_test(
    compressed_decrypted.document.lookup_object_or_null(6),
    metadata_stream,
  )
  @test.assert_eq(compressed_decrypted.denied_permissions, [PdfNoPrint])
}

///|
test "PdfDocument decrypt_with_passwords handles unencrypted, blank, user, and owner passwords" {
  let key_title = crypt_name_for_test("/Title")
  let plain_object : @pdflite.PdfObject = PdfDictionary([
    (key_title, PdfString(@ascii.encode("secret"))),
  ])
  let plain_doc = @pdflite.pdf_document_empty()
  plain_doc.add_object_given_number(1, plain_object)
  let plain_result = crypt_unwrap_decryption_result_for_test(
    try! plain_doc.decrypt_with_passwords(),
  )
  @test.assert_eq(plain_result.document.lookup_object_or_null(1), plain_object)
  @test.assert_eq(plain_result.denied_permissions, [])

  let blank_doc = @pdflite.pdf_document_empty()
  blank_doc.add_object_given_number(1, plain_object)
  let blank_encrypted = try! blank_doc.encrypt_40bit(
    @ascii.encode(""),
    @ascii.encode("owner"),
    [PdfNoCopy],
    file_id=@ascii.encode("doc-id"),
  )
  let blank_decrypted = crypt_unwrap_decryption_result_for_test(
    try! blank_encrypted.decrypt_with_passwords(),
  )
  @test.assert_eq(
    blank_decrypted.document.lookup_object_or_null(1),
    plain_object,
  )
  @test.assert_eq(blank_decrypted.denied_permissions, [PdfNoCopy])
  @test.assert_eq(
    try! blank_encrypted.decrypt_with_passwords(
      user_password=Some(@ascii.encode("bad")),
    ),
    None,
  )

  let encrypted = try! plain_doc.encrypt_128bit(
    @ascii.encode("user"),
    @ascii.encode("owner"),
    [PdfNoPrint],
    file_id=@ascii.encode("doc-id"),
  )
  let user_decrypted = crypt_unwrap_decryption_result_for_test(
    try! encrypted.decrypt_with_passwords(
      user_password=Some(@ascii.encode("user")),
    ),
  )
  @test.assert_eq(
    user_decrypted.document.lookup_object_or_null(1),
    plain_object,
  )
  @test.assert_eq(user_decrypted.denied_permissions, [PdfNoPrint])
  let owner_decrypted = crypt_unwrap_decryption_result_for_test(
    try! encrypted.decrypt_with_passwords(
      user_password=Some(@ascii.encode("bad")),
      owner_password=Some(@ascii.encode("owner")),
    ),
  )
  @test.assert_eq(
    owner_decrypted.document.lookup_object_or_null(1),
    plain_object,
  )
  @test.assert_eq(owner_decrypted.denied_permissions, [PdfNoPrint])
  @test.assert_eq(
    try! encrypted.decrypt_with_passwords(
      user_password=Some(@ascii.encode("bad")),
    ),
    None,
  )
}

///|
test "PdfDocument crypt methods cover standalone workflows" {
  let key_title = crypt_name_for_test("/Title")
  let plain_object : @pdflite.PdfObject = PdfDictionary([
    (key_title, PdfString(@ascii.encode("standalone-secret"))),
  ])
  let plain_doc = @pdflite.pdf_document_empty()
  plain_doc.add_object_given_number(1, plain_object)
  @test.assert_eq(plain_doc.is_encrypted(), false)
  @test.assert_eq(plain_doc.what_encryption(), None)
  @test.assert_eq(plain_doc.permissions(), [])

  let denied : Array[@pdflite.PdfPermission] = [PdfNoPrint]
  let encrypted_40 = plain_doc.encrypt_40bit(
    @ascii.encode("user"),
    @ascii.encode("owner"),
    denied,
    file_id=@ascii.encode("standalone-40-id"),
  )
  @test.assert_eq(encrypted_40.what_encryption(), Some(PdfEncryption40Bit))
  let encrypted = plain_doc.encrypt_128bit(
    @ascii.encode("user"),
    @ascii.encode("owner"),
    denied,
    file_id=@ascii.encode("standalone-id"),
  )
  @test.assert_eq(encrypted.is_encrypted(), true)
  @test.assert_eq(encrypted.what_encryption(), Some(PdfEncryption128Bit))
  @test.assert_eq(encrypted.permissions(), denied)
  let values = encrypted.encryption_values()
  @test.assert_eq(values.crypt_type, PdfCryptARC4(128, 3))
  @test.assert_eq(@pdflite.pdf_permissions_of_p(values.permissions), denied)

  let bad_decryption = encrypted.decrypt_with_passwords(
    user_password=Some(@ascii.encode("bad")),
  )
  @test.assert_eq(bad_decryption, None)
  @test.assert_eq(encrypted.permissions(), denied)

  let decrypted_result = encrypted.decrypt_with_passwords(
    user_password=Some(@ascii.encode("user")),
  )
  guard decrypted_result is Some(decrypted_result) else {
    fail("expected user password decryption")
  }
  let decrypted = decrypted_result.document
  @test.assert_eq(decrypted_result.denied_permissions, denied)
  @test.assert_eq(decrypted.lookup_object_or_null(1), plain_object)
  let owner_decrypted = encrypted.decrypt_with_owner_password(
    @ascii.encode("owner"),
  )
  @test.assert_eq(
    owner_decrypted.map(fn(result) { result.document.lookup_object_or_null(1) }),
    Some(plain_object),
  )
  @test.assert_eq(
    encrypted.decrypt_with_owner_password(@ascii.encode("bad")),
    None,
  )

  let key_length = crypt_name_for_test("/Length")
  let plain_stream = crypt_stream_for_test(
    [(key_length, PdfInteger(6))],
    @ascii.encode("stream"),
  )
  let stream_doc = @pdflite.pdf_document_empty()
  stream_doc.add_object_given_number(1, plain_stream)
  let encrypted_stream_doc = stream_doc.encrypt_40bit(
    @ascii.encode(""),
    @ascii.encode("owner"),
    [],
    file_id=@ascii.encode("standalone-stream-id"),
  )
  @test.assert_eq(
    encrypted_stream_doc.decrypt_single_stream(
      1,
      0,
      encrypted_stream_doc.lookup_object_or_null(1),
    ),
    Some(plain_stream),
  )

  decrypted.add_object_given_number(
    1,
    PdfDictionary([(key_title, PdfString(@ascii.encode("updated")))]),
  )
  let recrypted_with_default_renumber = decrypted
    .renumber_objects_compact()
    .recrypt_with_password(@ascii.encode("user"))
  @test.assert_eq(
    recrypted_with_default_renumber
    .decrypt_with_passwords(user_password=Some(@ascii.encode("user")))
    .map(fn(result) { result.document.lookup_object_or_null(1) }),
    Some(PdfDictionary([(key_title, PdfString(@ascii.encode("updated")))])),
  )
  let recrypted = decrypted.recrypt_with_password(@ascii.encode("user"))
  let roundtrip_result = recrypted.decrypt_with_passwords(
    user_password=Some(@ascii.encode("user")),
  )
  guard roundtrip_result is Some(roundtrip_result) else {
    fail("expected recrypted document to decrypt")
  }
  let roundtrip = roundtrip_result.document
  @test.assert_eq(roundtrip_result.denied_permissions, denied)
  @test.assert_eq(
    roundtrip.lookup_object_or_null(1),
    PdfDictionary([(key_title, PdfString(@ascii.encode("updated")))]),
  )
}

///|
test "PdfDocument provider methods cover AES encrypt and recrypt" {
  let key_title = crypt_name_for_test("/Title")
  let original_object : @pdflite.PdfObject = PdfDictionary([
    (key_title, PdfString(@ascii.encode("aes-wrapper-original"))),
  ])
  let updated_object : @pdflite.PdfObject = PdfDictionary([
    (key_title, PdfString(@ascii.encode("aes-wrapper-updated"))),
  ])
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(1, original_object)
  let denied : Array[@pdflite.PdfPermission] = [PdfNoCopy]
  let no_saved : Result[@pdflite.PdfDocument, Error] = try? doc.recrypt_with_password_aesv2_with_iv_provider(
    @ascii.encode("user"),
    @pdflite.pdf_deterministic_aes_iv_provider_from_seed(
      @ascii.encode("aes-wrapper-missing-saved"),
    ),
  )
  guard no_saved is Err(_) else {
    fail("expected missing saved encryption to raise")
  }
  let encrypted = doc.encrypt_128bit_aesv2_with_iv_provider(
    @ascii.encode("user"),
    @ascii.encode("owner"),
    denied,
    @pdflite.pdf_deterministic_aes_iv_provider_from_seed(
      @ascii.encode("aes-wrapper-iv"),
    ),
    encrypt_metadata=false,
    file_id=@ascii.encode("aes-wrapper-id"),
  )
  @test.assert_eq(encrypted.what_encryption(), Some(PdfEncryptionAES128(false)))
  let decrypted_result = encrypted.decrypt_with_passwords(
    user_password=Some(@ascii.encode("user")),
  )
  guard decrypted_result is Some(decrypted_result) else {
    fail("expected AES wrapper decryption")
  }
  let decrypted = decrypted_result.document
  @test.assert_eq(decrypted_result.denied_permissions, denied)
  @test.assert_eq(decrypted.lookup_object_or_null(1), original_object)
  decrypted.add_object_given_number(1, updated_object)
  let recrypted_default = decrypted
    .renumber_objects_compact()
    .recrypt_with_password_aesv2_with_iv_provider(
      @ascii.encode("user"),
      @pdflite.pdf_deterministic_aes_iv_provider_from_seed(
        @ascii.encode("aes-wrapper-default-recrypt-iv"),
      ),
    )
  @test.assert_eq(
    recrypted_default
    .decrypt_with_owner_password(@ascii.encode("owner"))
    .map(fn(result) { result.document.lookup_object_or_null(1) }),
    Some(updated_object),
  )
  let recrypted = decrypted.recrypt_with_password_aesv2_with_iv_provider(
    @ascii.encode("user"),
    @pdflite.pdf_deterministic_aes_iv_provider_from_seed(
      @ascii.encode("aes-wrapper-recrypt-iv"),
    ),
  )
  let owner_roundtrip = recrypted.decrypt_with_owner_password(
    @ascii.encode("owner"),
  )
  @test.assert_eq(
    owner_roundtrip.map(fn(result) { result.document.lookup_object_or_null(1) }),
    Some(updated_object),
  )

  let aesv3 = doc.encrypt_256bit_aesv3_with_providers(
    @ascii.encode("user"),
    @ascii.encode("owner"),
    [],
    @pdflite.pdf_deterministic_aesv3_random_provider_from_seed(
      @ascii.encode("aesv3-wrapper-random"),
    ),
    @pdflite.pdf_deterministic_aes_iv_provider_from_seed(
      @ascii.encode("aesv3-wrapper-iv"),
    ),
    encrypt_metadata=true,
    file_id=@ascii.encode("aesv3-wrapper-id"),
  )
  @test.assert_eq(aesv3.what_encryption(), Some(PdfEncryptionAES256(true)))
  let aesv3_decrypted = aesv3.decrypt_with_owner_password(
    @ascii.encode("owner"),
  )
  guard aesv3_decrypted is Some(aesv3_decrypted) else {
    fail("expected AESV3 wrapper decryption")
  }
  let aesv3_plain = aesv3_decrypted.document
  let aesv3_recrypted = aesv3_plain.recrypt_with_password_aesv3_with_iv_provider(
    @ascii.encode("owner"),
    @pdflite.pdf_deterministic_aes_iv_provider_from_seed(
      @ascii.encode("aesv3-wrapper-recrypt-iv"),
    ),
  )
  @test.assert_eq(
    aesv3_recrypted.what_encryption(),
    Some(PdfEncryptionAES256(true)),
  )
  let aesv3_iso = doc.encrypt_256bit_aesv3_iso_with_providers(
    @ascii.encode("user"),
    @ascii.encode("owner"),
    [],
    @pdflite.pdf_deterministic_aesv3_random_provider_from_seed(
      @ascii.encode("aesv3iso-wrapper-random"),
    ),
    @pdflite.pdf_deterministic_aes_iv_provider_from_seed(
      @ascii.encode("aesv3iso-wrapper-iv"),
    ),
    encrypt_metadata=false,
    file_id=@ascii.encode("aesv3iso-wrapper-id"),
  )
  @test.assert_eq(
    aesv3_iso.what_encryption(),
    Some(PdfEncryptionAES256ISO(false)),
  )
}

///|
test "PdfDocument decrypt_single_stream handles unencrypted and ARC4 streams" {
  let key_length = crypt_name_for_test("/Length")
  let key_title = crypt_name_for_test("/Title")
  let plain_stream = crypt_stream_for_test(
    [(key_length, PdfInteger(4)), (key_title, PdfString(@ascii.encode("info")))],
    @ascii.encode("data"),
  )
  let plain_doc = @pdflite.pdf_document_empty()
  @test.assert_eq(
    try! plain_doc.decrypt_single_stream(1, 0, plain_stream),
    Some(plain_stream),
  )

  let blank_password_doc = @pdflite.pdf_document_empty()
  blank_password_doc.add_object_given_number(1, plain_stream)
  let blank_password_encrypted = try! blank_password_doc.encrypt_40bit(
    @ascii.encode(""),
    @ascii.encode("owner"),
    [],
    file_id=@ascii.encode("doc-id"),
  )
  let blank_password_stream = blank_password_encrypted.lookup_object_or_null(1)
  @test.assert_eq(
    try! blank_password_encrypted.decrypt_single_stream(
      1, 0, blank_password_stream,
    ),
    Some(plain_stream),
  )
  @test.assert_eq(
    try! blank_password_encrypted.decrypt_single_stream(
      1,
      0,
      blank_password_stream,
      user_password=Some(@ascii.encode("bad")),
    ),
    None,
  )

  let owner_password_doc = @pdflite.pdf_document_empty()
  owner_password_doc.add_object_given_number(1, plain_stream)
  let owner_password_encrypted = try! owner_password_doc.encrypt_128bit(
    @ascii.encode("user"),
    @ascii.encode("owner"),
    [],
    file_id=@ascii.encode("doc-id"),
  )
  let owner_password_stream = owner_password_encrypted.lookup_object_or_null(1)
  @test.assert_eq(
    try! owner_password_encrypted.decrypt_single_stream(
      1,
      0,
      owner_password_stream,
      user_password=Some(@ascii.encode("bad")),
      owner_password=Some(@ascii.encode("owner")),
    ),
    Some(plain_stream),
  )
  @test.assert_eq(
    try! owner_password_encrypted.decrypt_single_stream(
      1,
      0,
      owner_password_stream,
      user_password=Some(@ascii.encode("bad")),
    ),
    None,
  )
}

///|
test "PdfDocument decrypt_single_stream handles AESV2 and AESV3 streams" {
  let key_length = crypt_name_for_test("/Length")
  let key_title = crypt_name_for_test("/Title")
  let plain_stream = crypt_stream_for_test(
    [(key_length, PdfInteger(3)), (key_title, PdfString(@ascii.encode("aes")))],
    @ascii.encode("raw"),
  )

  let aesv2_file_id = @ascii.encode("doc-id")
  let aesv2_iv = crypt_model_bytes_for_test([
    0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19, 0x1a, 0x1b, 0x1c,
    0x1d, 0x1e, 0x1f,
  ])
  let aesv2_source = @pdflite.pdf_document_empty()
  aesv2_source.add_object_given_number(1, plain_stream)
  let aesv2_doc = try! aesv2_source.encrypt_128bit_aesv2_with_iv_provider(
    @ascii.encode("user"),
    @ascii.encode("owner"),
    @pdflite.pdf_permissions_of_p(-3904),
    fn(_, _, _) { aesv2_iv },
    file_id=aesv2_file_id,
  )
  let aesv2_encrypted_stream = aesv2_doc.lookup_object_or_null(1)
  @test.assert_eq(
    try! aesv2_doc.decrypt_single_stream(
      1,
      0,
      aesv2_encrypted_stream,
      user_password=Some(@ascii.encode("user")),
    ),
    Some(plain_stream),
  )

  let aesv3_user_entry = crypt_aesv3_r5_user_entry_for_test()
  let aesv3_owner_entry = crypt_aesv3_r5_owner_entry_for_test()
  let aesv3_file_key = crypt_aesv3_r5_file_key_for_test()
  let aesv3_encrypt_dictionary = crypt_standard_encrypt_dictionary_values_for_test(
    [
      (crypt_name_for_test("/V"), PdfInteger(5)),
      (crypt_name_for_test("/R"), PdfInteger(5)),
      (
        crypt_name_for_test("/CF"),
        PdfDictionary([
          (
            crypt_name_for_test("/StdCF"),
            PdfDictionary([
              (
                crypt_name_for_test("/CFM"),
                PdfNameObject(crypt_name_for_test("/AESV3")),
              ),
            ]),
          ),
        ]),
      ),
      (
        crypt_name_for_test("/UE"),
        PdfString(crypt_aesv3_r5_user_encryption_key_for_test()),
      ),
      (
        crypt_name_for_test("/OE"),
        PdfString(crypt_aesv3_r5_owner_encryption_key_for_test()),
      ),
      (
        crypt_name_for_test("/Perms"),
        PdfString(crypt_aesv3_r5_permissions_for_test()),
      ),
    ],
    aesv3_owner_entry,
    aesv3_user_entry,
    -3904,
  )
  let aesv3_iv = crypt_model_bytes_for_test([
    0x20, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27, 0x28, 0x29, 0x2a, 0x2b, 0x2c,
    0x2d, 0x2e, 0x2f,
  ])
  let aesv3_encrypted_title = try! crypt_aesv3_encrypt_data_for_test(
    aesv3_file_key,
    @ascii.encode("aes"),
    aesv3_iv,
  )
  let aesv3_encrypted_data = try! crypt_aesv3_encrypt_data_for_test(
    aesv3_file_key,
    @ascii.encode("raw"),
    aesv3_iv,
  )
  let aesv3_encrypted_stream = crypt_stream_for_test(
    [
      (key_length, PdfInteger(aesv3_encrypted_data.length())),
      (key_title, PdfString(aesv3_encrypted_title)),
    ],
    aesv3_encrypted_data,
  )
  let aesv3_doc = @pdflite.pdf_document_empty()
  aesv3_doc.add_object_given_number(2, aesv3_encrypt_dictionary)
  aesv3_doc.set_trailer_dict(
    PdfDictionary([
      (crypt_name_for_test("/Encrypt"), PdfIndirect(2)),
      (
        crypt_name_for_test("/ID"),
        PdfArray([
          PdfString(@ascii.encode("doc-id")),
          PdfString(@ascii.encode("ignored")),
        ]),
      ),
    ]),
  )
  @test.assert_eq(
    try! aesv3_doc.decrypt_single_stream(
      1,
      0,
      aesv3_encrypted_stream,
      owner_password=Some(@ascii.encode("owner")),
    ),
    Some(plain_stream),
  )
}

///|
test "PdfDocument decrypt_with_user_password decrypts parsed AESV2 objects in a copy" {
  let file_id = @ascii.encode("doc-id")
  let iv = crypt_model_bytes_for_test([
    0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19, 0x1a, 0x1b, 0x1c,
    0x1d, 0x1e, 0x1f,
  ])
  let key_title = crypt_name_for_test("/Title")
  let plain_object : @pdflite.PdfObject = PdfDictionary([
    (key_title, PdfString(@ascii.encode("aes"))),
  ])
  let source = @pdflite.pdf_document_empty()
  source.add_object_given_number(1, plain_object)
  let template = try! source.encrypt_128bit_aesv2_with_iv_provider(
    @ascii.encode("user"),
    @ascii.encode("owner"),
    @pdflite.pdf_permissions_of_p(-3904),
    fn(_, _, _) { iv },
    file_id~,
  )
  let values = try! template.encryption_values()
  let owner_entry = values.owner_entry
  let user_entry = values.user_entry
  let encrypt_dictionary = crypt_standard_encrypt_dictionary_values_for_test(
    [
      (crypt_name_for_test("/V"), PdfInteger(4)),
      (crypt_name_for_test("/R"), PdfInteger(4)),
      (
        crypt_name_for_test("/CF"),
        PdfDictionary([
          (
            crypt_name_for_test("/StdCF"),
            PdfDictionary([
              (
                crypt_name_for_test("/CFM"),
                PdfNameObject(crypt_name_for_test("/AESV2")),
              ),
            ]),
          ),
        ]),
      ),
    ],
    owner_entry,
    user_entry,
    -3904,
  )
  let doc = @pdflite.pdf_document_empty()
  let encrypted_object = template.lookup_object_or_null(1)
  doc.add_object_given_number(1, encrypted_object)
  doc.add_object_given_number(2, encrypt_dictionary)
  doc.set_trailer_dict(
    PdfDictionary([
      (crypt_name_for_test("/Encrypt"), PdfIndirect(2)),
      (
        crypt_name_for_test("/ID"),
        PdfArray([
          PdfString(@ascii.encode("doc-id")),
          PdfString(@ascii.encode("ignored")),
        ]),
      ),
    ]),
  )

  let decrypted = crypt_unwrap_decryption_result_for_test(
    try! doc.decrypt_with_user_password(@ascii.encode("user")),
  )
  @test.assert_eq(decrypted.document.lookup_object_or_null(1), plain_object)
  @test.assert_eq(
    decrypted.document.lookup_object_or_null(2),
    encrypt_dictionary,
  )
  @test.assert_eq(
    decrypted.document
    .trailer_dict()
    .lookup_immediate(crypt_name_for_test("/Encrypt")),
    None,
  )
  @test.assert_eq(
    decrypted.denied_permissions,
    @pdflite.pdf_permissions_of_p(-3904),
  )
  let owner_decrypted = crypt_unwrap_decryption_result_for_test(
    try! doc.decrypt_with_owner_password(@ascii.encode("owner")),
  )
  @test.assert_eq(
    owner_decrypted.document.lookup_object_or_null(1),
    plain_object,
  )
  @test.assert_eq(
    owner_decrypted.document
    .trailer_dict()
    .lookup_immediate(crypt_name_for_test("/Encrypt")),
    None,
  )
  @test.assert_eq(doc.lookup_object_or_null(1), encrypted_object)
  @test.assert_eq(
    try! doc.decrypt_with_user_password(@ascii.encode("bad")),
    None,
  )
  @test.assert_eq(
    try! doc.decrypt_with_owner_password(@ascii.encode("bad")),
    None,
  )
}

///|
test "PdfDocument decrypt_with_user_password honors EncryptMetadata false" {
  let file_id = @ascii.encode("doc-id")
  let iv = crypt_model_bytes_for_test([
    0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19, 0x1a, 0x1b, 0x1c, 0x1d,
    0x1e, 0x1f, 0x20,
  ])
  let key_title = crypt_name_for_test("/Title")
  let plain_object : @pdflite.PdfObject = PdfDictionary([
    (key_title, PdfString(@ascii.encode("aes"))),
  ])
  let metadata_stream = crypt_stream_for_test(
    [
      (crypt_name_for_test("/Length"), PdfInteger(4)),
      (
        crypt_name_for_test("/Type"),
        PdfNameObject(crypt_name_for_test("/Metadata")),
      ),
      (key_title, PdfString(@ascii.encode("meta"))),
    ],
    @ascii.encode("meta"),
  )
  let source = @pdflite.pdf_document_empty()
  source.add_object_given_number(1, plain_object)
  let template = try! source.encrypt_128bit_aesv2_with_iv_provider(
    @ascii.encode("user"),
    @ascii.encode("owner"),
    @pdflite.pdf_permissions_of_p(-3904),
    fn(_, _, _) { iv },
    encrypt_metadata=false,
    file_id~,
  )
  let values = try! template.encryption_values()
  let owner_entry = values.owner_entry
  let user_entry = values.user_entry
  let encrypt_dictionary = crypt_standard_encrypt_dictionary_values_for_test(
    [
      (crypt_name_for_test("/V"), PdfInteger(4)),
      (crypt_name_for_test("/R"), PdfInteger(4)),
      (crypt_name_for_test("/EncryptMetadata"), PdfBoolean(false)),
      (
        crypt_name_for_test("/CF"),
        PdfDictionary([
          (
            crypt_name_for_test("/StdCF"),
            PdfDictionary([
              (
                crypt_name_for_test("/CFM"),
                PdfNameObject(crypt_name_for_test("/AESV2")),
              ),
            ]),
          ),
        ]),
      ),
    ],
    owner_entry,
    user_entry,
    -3904,
  )
  let encrypted_object = template.lookup_object_or_null(1)
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(1, encrypted_object)
  doc.add_object_given_number(2, encrypt_dictionary)
  doc.add_object_given_number(3, metadata_stream)
  doc.set_trailer_dict(
    PdfDictionary([
      (crypt_name_for_test("/Encrypt"), PdfIndirect(2)),
      (
        crypt_name_for_test("/ID"),
        PdfArray([
          PdfString(@ascii.encode("doc-id")),
          PdfString(@ascii.encode("ignored")),
        ]),
      ),
    ]),
  )

  let decrypted = crypt_unwrap_decryption_result_for_test(
    try! doc.decrypt_with_user_password(@ascii.encode("user")),
  )
  @test.assert_eq(decrypted.document.lookup_object_or_null(1), plain_object)
  @test.assert_eq(decrypted.document.lookup_object_or_null(3), metadata_stream)
  let owner_decrypted = crypt_unwrap_decryption_result_for_test(
    try! doc.decrypt_with_owner_password(@ascii.encode("owner")),
  )
  @test.assert_eq(
    owner_decrypted.document.lookup_object_or_null(1),
    plain_object,
  )
  @test.assert_eq(
    owner_decrypted.document.lookup_object_or_null(3),
    metadata_stream,
  )
}

///|
test "PdfDocument decrypt_with_user_password decrypts parsed AESV3 revision 5 objects in a copy" {
  let user_entry = crypt_aesv3_r5_user_entry_for_test()
  let owner_entry = crypt_aesv3_r5_owner_entry_for_test()
  let file_key = crypt_aesv3_r5_file_key_for_test()
  let encrypt_dictionary = crypt_standard_encrypt_dictionary_values_for_test(
    [
      (crypt_name_for_test("/V"), PdfInteger(5)),
      (crypt_name_for_test("/R"), PdfInteger(5)),
      (
        crypt_name_for_test("/CF"),
        PdfDictionary([
          (
            crypt_name_for_test("/StdCF"),
            PdfDictionary([
              (
                crypt_name_for_test("/CFM"),
                PdfNameObject(crypt_name_for_test("/AESV3")),
              ),
            ]),
          ),
        ]),
      ),
      (
        crypt_name_for_test("/UE"),
        PdfString(crypt_aesv3_r5_user_encryption_key_for_test()),
      ),
      (
        crypt_name_for_test("/OE"),
        PdfString(crypt_aesv3_r5_owner_encryption_key_for_test()),
      ),
      (
        crypt_name_for_test("/Perms"),
        PdfString(crypt_aesv3_r5_permissions_for_test()),
      ),
    ],
    owner_entry,
    user_entry,
    -3904,
  )
  let iv = crypt_model_bytes_for_test([
    0x20, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27, 0x28, 0x29, 0x2a, 0x2b, 0x2c,
    0x2d, 0x2e, 0x2f,
  ])
  let key_title = crypt_name_for_test("/Title")
  let plain_object : @pdflite.PdfObject = PdfDictionary([
    (key_title, PdfString(@ascii.encode("aes3"))),
  ])
  let encrypted_object : @pdflite.PdfObject = PdfDictionary([
    (
      key_title,
      PdfString(
        try! crypt_aesv3_encrypt_data_for_test(
          file_key,
          @ascii.encode("aes3"),
          iv,
        ),
      ),
    ),
  ])
  let encrypted_metadata = try! crypt_aesv3_encrypt_data_for_test(
    file_key,
    @ascii.encode("meta"),
    iv,
  )
  let encrypted_metadata_stream = crypt_stream_for_test(
    [
      (crypt_name_for_test("/Length"), PdfInteger(encrypted_metadata.length())),
      (
        crypt_name_for_test("/Type"),
        PdfNameObject(crypt_name_for_test("/Metadata")),
      ),
      (key_title, PdfString(encrypted_metadata)),
    ],
    encrypted_metadata,
  )
  let plain_metadata_stream = crypt_stream_for_test(
    [
      (crypt_name_for_test("/Length"), PdfInteger(4)),
      (
        crypt_name_for_test("/Type"),
        PdfNameObject(crypt_name_for_test("/Metadata")),
      ),
      (key_title, PdfString(@ascii.encode("meta"))),
    ],
    @ascii.encode("meta"),
  )
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(1, encrypted_object)
  doc.add_object_given_number(2, encrypt_dictionary)
  doc.add_object_given_number(3, encrypted_metadata_stream)
  doc.set_trailer_dict(
    PdfDictionary([
      (crypt_name_for_test("/Encrypt"), PdfIndirect(2)),
      (
        crypt_name_for_test("/ID"),
        PdfArray([
          PdfString(@ascii.encode("doc-id")),
          PdfString(@ascii.encode("ignored")),
        ]),
      ),
    ]),
  )

  let decrypted = crypt_unwrap_decryption_result_for_test(
    try! doc.decrypt_with_user_password(@ascii.encode("user")),
  )
  @test.assert_eq(decrypted.document.lookup_object_or_null(1), plain_object)
  @test.assert_eq(
    decrypted.document.lookup_object_or_null(3),
    plain_metadata_stream,
  )
  @test.assert_eq(
    decrypted.document.lookup_object_or_null(2),
    encrypt_dictionary,
  )
  @test.assert_eq(
    decrypted.document
    .trailer_dict()
    .lookup_immediate(crypt_name_for_test("/Encrypt")),
    None,
  )
  @test.assert_eq(
    decrypted.denied_permissions,
    @pdflite.pdf_permissions_of_p(-3904),
  )
  let owner_decrypted = crypt_unwrap_decryption_result_for_test(
    try! doc.decrypt_with_owner_password(@ascii.encode("owner")),
  )
  @test.assert_eq(
    owner_decrypted.document.lookup_object_or_null(1),
    plain_object,
  )
  let metadata_skipped = crypt_unwrap_decryption_result_for_test(
    try! doc.decrypt_with_user_password(
      @ascii.encode("user"),
      no_encrypt_metadata=true,
    ),
  )
  @test.assert_eq(
    metadata_skipped.document.lookup_object_or_null(1),
    plain_object,
  )
  @test.assert_eq(
    metadata_skipped.document.lookup_object_or_null(3),
    encrypted_metadata_stream,
  )
  @test.assert_eq(doc.lookup_object_or_null(1), encrypted_object)
  @test.assert_eq(
    try! doc.decrypt_with_user_password(@ascii.encode("bad")),
    None,
  )
  @test.assert_eq(
    try! doc.decrypt_with_owner_password(@ascii.encode("bad")),
    None,
  )
}

///|
test "PdfDocument encryption_values reports malformed encryption dictionaries" {
  let no_encrypt : Result[@pdflite.PdfEncryptionValues, Error] = try? @pdflite.pdf_document_empty().encryption_values()
  guard no_encrypt is Err(@pdflite.PdfError::EncryptionExpected) else {
    fail("expected EncryptionExpected")
  }

  crypt_expect_encryption_method_error_for_test(
    crypt_standard_encrypt_dictionary_for_test([
      (crypt_name_for_test("/V"), PdfInteger(99)),
      (crypt_name_for_test("/R"), PdfInteger(4)),
    ]),
  )

  crypt_expect_encryption_method_error_for_test(
    PdfDictionary([
      (crypt_name_for_test("/Filter"), PdfInteger(1)),
      (crypt_name_for_test("/V"), PdfInteger(1)),
      (crypt_name_for_test("/R"), PdfInteger(2)),
      (
        crypt_name_for_test("/O"),
        PdfString(crypt_repeated_bytes_for_test(0x4f, 32)),
      ),
      (
        crypt_name_for_test("/U"),
        PdfString(crypt_repeated_bytes_for_test(0x55, 32)),
      ),
      (crypt_name_for_test("/P"), PdfInteger(-4)),
    ]),
  )

  crypt_expect_encryption_method_error_for_test(
    crypt_standard_encrypt_dictionary_for_test([
      (crypt_name_for_test("/V"), PdfInteger(4)),
      (crypt_name_for_test("/R"), PdfInteger(4)),
    ]),
  )

  crypt_expect_encryption_method_error_for_test(
    crypt_standard_encrypt_dictionary_for_test([
      (crypt_name_for_test("/V"), PdfInteger(4)),
      (crypt_name_for_test("/R"), PdfInteger(4)),
      (crypt_name_for_test("/CF"), PdfDictionary([])),
    ]),
  )

  crypt_expect_encryption_method_error_for_test(
    crypt_standard_encrypt_dictionary_for_test([
      (crypt_name_for_test("/V"), PdfInteger(4)),
      (crypt_name_for_test("/R"), PdfInteger(4)),
      (
        crypt_name_for_test("/CF"),
        PdfDictionary([
          (
            crypt_name_for_test("/StdCF"),
            PdfDictionary([
              (
                crypt_name_for_test("/CFM"),
                PdfNameObject(crypt_name_for_test("/Unknown")),
              ),
            ]),
          ),
        ]),
      ),
    ]),
  )

  crypt_expect_encryption_method_error_for_test(
    crypt_standard_encrypt_dictionary_for_test([
      (crypt_name_for_test("/V"), PdfInteger(4)),
      (crypt_name_for_test("/R"), PdfInteger(4)),
      (
        crypt_name_for_test("/CF"),
        PdfDictionary([
          (
            crypt_name_for_test("/StdCF"),
            PdfDictionary([
              (
                crypt_name_for_test("/CFM"),
                PdfNameObject(crypt_name_for_test("/V2")),
              ),
            ]),
          ),
        ]),
      ),
    ]),
  )

  let missing_o = crypt_doc_with_encrypt_for_test(
    PdfDictionary([
      (
        crypt_name_for_test("/Filter"),
        PdfNameObject(crypt_name_for_test("/Standard")),
      ),
      (crypt_name_for_test("/V"), PdfInteger(1)),
      (crypt_name_for_test("/R"), PdfInteger(2)),
      (
        crypt_name_for_test("/U"),
        PdfString(crypt_repeated_bytes_for_test(0x55, 32)),
      ),
      (crypt_name_for_test("/P"), PdfInteger(-4)),
    ]),
  )
  let missing_o_result : Result[@pdflite.PdfEncryptionValues, Error] = try? missing_o.encryption_values()
  guard missing_o_result
    is Err(@pdflite.PdfError::EncryptionDictionaryEntryExpected(name)) &&
    name == crypt_name_for_test("/O") else {
    fail("expected missing /O")
  }

  let missing_p = crypt_doc_with_encrypt_for_test(
    PdfDictionary([
      (
        crypt_name_for_test("/Filter"),
        PdfNameObject(crypt_name_for_test("/Standard")),
      ),
      (crypt_name_for_test("/V"), PdfInteger(1)),
      (crypt_name_for_test("/R"), PdfInteger(2)),
      (
        crypt_name_for_test("/O"),
        PdfString(crypt_repeated_bytes_for_test(0x4f, 32)),
      ),
      (
        crypt_name_for_test("/U"),
        PdfString(crypt_repeated_bytes_for_test(0x55, 32)),
      ),
    ]),
  )
  let missing_p_result : Result[@pdflite.PdfEncryptionValues, Error] = try? missing_p.encryption_values()
  guard missing_p_result
    is Err(@pdflite.PdfError::EncryptionDictionaryEntryExpected(name)) &&
    name == crypt_name_for_test("/P") else {
    fail("expected missing /P")
  }

  let short_u = crypt_doc_with_encrypt_for_test(
    crypt_standard_encrypt_dictionary_for_test(
      [
        (crypt_name_for_test("/V"), PdfInteger(1)),
        (crypt_name_for_test("/R"), PdfInteger(2)),
      ],
      user_length=31,
    ),
  )
  let short_u_result : Result[@pdflite.PdfEncryptionValues, Error] = try? short_u.encryption_values()
  guard short_u_result
    is Err(@pdflite.PdfError::EncryptionDictionaryEntryTooShort(name)) &&
    name == crypt_name_for_test("/U") else {
    fail("expected short /U")
  }

  let bad_id = @pdflite.pdf_document_empty()
  bad_id.set_trailer_dict(
    PdfDictionary([
      (
        crypt_name_for_test("/Encrypt"),
        crypt_standard_encrypt_dictionary_for_test([
          (crypt_name_for_test("/V"), PdfInteger(1)),
          (crypt_name_for_test("/R"), PdfInteger(2)),
        ]),
      ),
    ]),
  )
  let bad_id_result : Result[@pdflite.PdfEncryptionValues, Error] = try? bad_id.encryption_values()
  guard bad_id_result is Err(@pdflite.PdfError::EncryptionIDExpected) else {
    fail("expected EncryptionIDExpected")
  }
}

///|
test "PdfEncryptionValues authenticate_user_password validates R2 and R3 user entries" {
  let r2_values = try! (try! @pdflite.pdf_document_empty().encrypt_40bit(
    @ascii.encode("user"),
    @ascii.encode("owner"),
    [],
    file_id=@ascii.encode("doc-id"),
  )).encryption_values()
  @test.assert_eq(
    try! r2_values.authenticate_user_password(@ascii.encode("user")),
    true,
  )
  @test.assert_eq(
    try! r2_values.authenticate_user_password(@ascii.encode("bad")),
    false,
  )
  let r3_values = try! (try! @pdflite.pdf_document_empty().encrypt_128bit(
    Bytes::new(0),
    @ascii.encode("owner"),
    @pdflite.pdf_permissions_of_p(-3904),
    file_id=@ascii.encode("doc-id"),
  )).encryption_values()
  let r3_entry = r3_values.user_entry
  let r3_values_with_entry_prefix : @pdflite.PdfEncryptionValues = {
    crypt_type: PdfCryptARC4(128, 3),
    user_entry: r3_entry[:16].to_owned(),
    owner_entry: r3_values.owner_entry,
    permissions: r3_values.permissions,
    file_id: r3_values.file_id,
    encrypt_metadata: r3_values.encrypt_metadata,
    permissions_entry: None,
    user_encryption_key: None,
    owner_encryption_key: None,
  }
  @test.assert_eq(
    try! r3_values_with_entry_prefix.authenticate_user_password(Bytes::new(0)),
    true,
  )
  let r3_values_with_short_entry : @pdflite.PdfEncryptionValues = {
    crypt_type: PdfCryptARC4(128, 3),
    user_entry: r3_entry[:8].to_owned(),
    owner_entry: r3_values.owner_entry,
    permissions: r3_values.permissions,
    file_id: r3_values.file_id,
    encrypt_metadata: r3_values.encrypt_metadata,
    permissions_entry: None,
    user_encryption_key: None,
    owner_encryption_key: None,
  }
  @test.assert_eq(
    try! r3_values_with_short_entry.authenticate_user_password(Bytes::new(0)),
    false,
  )
}

///|
test "pdf_authenticate_aesv3_password validates R5 SHA-256 entries" {
  let user_entry = crypt_aesv3_r5_user_entry_for_test()
  let owner_entry = crypt_aesv3_r5_owner_entry_for_test()
  let values = crypt_aesv3_values_for_test(user_entry, owner_entry)
  @test.assert_eq(
    try! values.authenticate_user_password(@ascii.encode("user")),
    true,
  )
  @test.assert_eq(
    try! values.authenticate_user_password(@ascii.encode("bad")),
    false,
  )
  @test.assert_eq(
    try! values.authenticate_owner_password(@ascii.encode("owner")),
    true,
  )
  @test.assert_eq(
    try! values.authenticate_owner_password(@ascii.encode("bad")),
    false,
  )

  let short_user = crypt_repeated_bytes_for_test(0, 47)
  let short_user_values = crypt_aesv3_values_for_test(short_user, owner_entry)
  let short_user_result : Result[Bool, Error] = try? short_user_values.authenticate_user_password(
    @ascii.encode("user"),
  )
  guard short_user_result
    is Err(@pdflite.PdfError::EncryptionDictionaryEntryTooShort(name)) &&
    name == crypt_name_for_test("/U") else {
    fail("expected short AESV3 /U")
  }

  let short_owner = crypt_repeated_bytes_for_test(0, 47)
  let short_owner_values = crypt_aesv3_values_for_test(user_entry, short_owner)
  let short_owner_result : Result[Bool, Error] = try? short_owner_values.authenticate_owner_password(
    @ascii.encode("owner"),
  )
  guard short_owner_result
    is Err(@pdflite.PdfError::EncryptionDictionaryEntryTooShort(name)) &&
    name == crypt_name_for_test("/O") else {
    fail("expected short AESV3 /O")
  }

  let short_owner_user_values = crypt_aesv3_values_for_test(
    short_user, owner_entry,
  )
  let short_owner_user_result : Result[Bool, Error] = try? short_owner_user_values.authenticate_owner_password(
    @ascii.encode("owner"),
  )
  guard short_owner_user_result
    is Err(@pdflite.PdfError::EncryptionDictionaryEntryTooShort(name)) &&
    name == crypt_name_for_test("/U") else {
    fail("expected short AESV3 owner /U")
  }

  let iso_doc = crypt_minimal_catalog_document_for_test(1, 7)
  let iso_encrypted = try! iso_doc.encrypt_256bit_aesv3_with_providers(
    @ascii.encode("user"),
    @ascii.encode("owner"),
    @pdflite.pdf_permissions_of_p(-3904),
    crypt_aesv3_r5_random_for_test,
    fn(object_number, generation, index) {
      crypt_aes_document_iv_for_test(object_number, generation, index)
    },
    iso=true,
    file_id=@ascii.encode("doc-id"),
  )
  let iso_values = try! iso_encrypted.encryption_values()
  @test.assert_eq(iso_values.crypt_type, PdfCryptAESV3(true))
  @test.assert_eq(
    try! iso_values.authenticate_user_password(@ascii.encode("user")),
    true,
  )
  @test.assert_eq(
    try! iso_values.authenticate_user_password(@ascii.encode("bad")),
    false,
  )
  @test.assert_eq(
    try! iso_values.authenticate_owner_password(@ascii.encode("owner")),
    true,
  )
  @test.assert_eq(
    try! iso_values.authenticate_owner_password(@ascii.encode("bad")),
    false,
  )

  @test.assert_eq(
    crypt_concat_bytes_for_test([@ascii.encode("user"), user_entry[32:40]]),
    crypt_model_bytes_for_test([
      0x75, 0x73, 0x65, 0x72, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08,
    ]),
  )
}

///|
test "PdfEncryptionValues authenticate_owner_password validates through recovered user password" {
  let values = try! (try! @pdflite.pdf_document_empty().encrypt_128bit(
    Bytes::new(0),
    @ascii.encode("owner"),
    @pdflite.pdf_permissions_of_p(-3904),
    file_id=@ascii.encode("doc-id"),
  )).encryption_values()
  @test.assert_eq(
    try! values.authenticate_owner_password(@ascii.encode("owner")),
    true,
  )
  @test.assert_eq(
    try! values.authenticate_owner_password(@ascii.encode("bad")),
    false,
  )
}

///|
test "pdf_permissions_of_p parses CamlPDF denied permission bits" {
  @test.assert_eq(@pdflite.pdf_permissions_of_p(-4), [])
  @test.assert_eq(@pdflite.pdf_permissions_of_p(-8), [PdfNoPrint])
  @test.assert_eq(@pdflite.pdf_permissions_of_p(-3904), [
    PdfNoHqPrint,
    PdfNoAssemble,
    PdfNoExtract,
    PdfNoForms,
    PdfNoAnnot,
    PdfNoCopy,
    PdfNoEdit,
    PdfNoPrint,
  ])
}

///|
test "pdf_p_of_permissions writes signed CamlPDF permission masks" {
  @test.assert_eq(@pdflite.pdf_p_of_permissions([]), -4)
  @test.assert_eq(@pdflite.pdf_p_of_permissions([PdfNoPrint]), -8)
  @test.assert_eq(
    @pdflite.pdf_p_of_permissions([
      PdfNoEdit,
      PdfNoPrint,
      PdfNoCopy,
      PdfNoAnnot,
      PdfNoForms,
      PdfNoExtract,
      PdfNoAssemble,
      PdfNoHqPrint,
    ]),
    -3904,
  )
}

///|
test "permission masks roundtrip denied permissions" {
  let denied : Array[@pdflite.PdfPermission] = [
    PdfNoCopy,
    PdfNoExtract,
    PdfNoHqPrint,
  ]
  @test.assert_eq(
    @pdflite.pdf_permissions_of_p(@pdflite.pdf_p_of_permissions(denied)),
    [PdfNoHqPrint, PdfNoExtract, PdfNoCopy],
  )
}
