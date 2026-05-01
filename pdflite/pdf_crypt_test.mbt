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
fn crypt_aesv2_encrypt_data_for_test(
  object_number : Int,
  generation : Int,
  file_key : BytesView,
  key_length_bits : Int,
  data : BytesView,
  iv : BytesView,
) -> @pdflite.PdfBytes {
  let object_key = @pdflite.pdf_encryption_object_key(
    PdfCryptAESV2,
    object_number,
    generation,
    file_key,
    key_length_bits,
  )
  try! @pdflite.pdf_aes_cbc_encrypt_with_iv(object_key[:], iv, data)
}

///|
fn crypt_aesv3_encrypt_data_for_test(
  file_key : BytesView,
  data : BytesView,
  iv : BytesView,
) -> @pdflite.PdfBytes {
  try! @pdflite.pdf_aes_cbc_encrypt_with_iv(file_key, iv, data)
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
  let block : Array[Byte] = []
  for shift in [0, 8, 16, 24] {
    block.push(((permissions >> shift) & 0xff).to_byte())
  }
  for _ in 0..<4 {
    block.push((255).to_byte())
  }
  block.push(if encrypt_metadata { b'T' } else { b'F' })
  block.push(b'a')
  block.push(b'd')
  block.push(b'b')
  for _ in 0..<4 {
    block.push(b'\x00')
  }
  let block_bytes = Bytes::from_array(block)
  try! @pdflite.pdf_aes_encrypt_block(
    crypt_aesv3_r5_file_key_for_test()[:],
    block_bytes[:],
  )
}

///|
fn crypt_name_for_test(text : String) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(@ascii.encode(text))
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
  let unsupported : Result[Bool, Error] = try? aesv3_values.authenticate_user_password(
    @ascii.encode("user")[:],
  )
  guard unsupported
    is Err(
      @pdflite.PdfError::EncryptionAuthenticationUnsupported(
        PdfCryptAESV3(true)
      )
    ) else {
    fail("expected unsupported AESV3 authentication")
  }
}

///|
test "PdfEncryptionValues authenticates passwords and derives file keys" {
  let file_id = @ascii.encode("doc-id")
  let owner_entry = try! @pdflite.pdf_make_owner_password_entry(
    3,
    @ascii.encode("owner")[:],
    @ascii.encode("user")[:],
    128,
  )
  let user_entry = try! @pdflite.pdf_make_user_password_entry(
    false,
    @ascii.encode("user")[:],
    3,
    owner_entry[:],
    -3904,
    file_id[:],
    128,
  )
  let doc = crypt_doc_with_encrypt_for_test(
    crypt_standard_encrypt_dictionary_values_for_test(
      [
        (crypt_name_for_test("/V"), PdfInteger(2)),
        (crypt_name_for_test("/Length"), PdfInteger(128)),
        (crypt_name_for_test("/R"), PdfInteger(3)),
      ],
      owner_entry,
      user_entry,
      -3904,
    ),
  )
  let values = try! doc.encryption_values()
  let expected_key = @pdflite.pdf_encryption_file_key(
    false,
    @ascii.encode("user")[:],
    3,
    owner_entry[:],
    -3904,
    file_id[:],
    128,
  )
  @test.assert_eq(
    try! values.authenticate_user_password(@ascii.encode("user")[:]),
    true,
  )
  @test.assert_eq(
    try! values.authenticate_user_password(@ascii.encode("bad")[:]),
    false,
  )
  @test.assert_eq(
    try! values.file_key_for_user_password(@ascii.encode("user")[:]),
    Some(expected_key),
  )
  @test.assert_eq(
    try! values.file_key_for_user_password(@ascii.encode("bad")[:]),
    None,
  )
  @test.assert_eq(
    try! values.authenticate_owner_password(@ascii.encode("owner")[:]),
    true,
  )
  @test.assert_eq(
    try! values.authenticate_owner_password(@ascii.encode("bad")[:]),
    false,
  )
  @test.assert_eq(
    try! values.file_key_for_owner_password(@ascii.encode("owner")[:]),
    Some(expected_key),
  )
  @test.assert_eq(
    try! values.file_key_for_owner_password(@ascii.encode("bad")[:]),
    None,
  )
}

///|
test "PdfEncryptionValues treats AESV2 as revision 4 with 128-bit keys" {
  let file_id = @ascii.encode("doc-id")
  let owner_entry = try! @pdflite.pdf_make_owner_password_entry(
    4,
    @ascii.encode("owner")[:],
    @ascii.encode("user")[:],
    128,
  )
  let user_entry = try! @pdflite.pdf_make_user_password_entry(
    false,
    @ascii.encode("user")[:],
    4,
    owner_entry[:],
    -3904,
    file_id[:],
    128,
  )
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
  let doc = crypt_doc_with_encrypt_for_test(encrypt_dictionary)
  let values = try! doc.encryption_values()
  @test.assert_eq(values.crypt_type, PdfCryptAESV2)
  @test.assert_eq(
    try! values.authenticate_user_password(@ascii.encode("user")[:]),
    true,
  )
  @test.assert_eq(
    try! values.file_key_for_user_password(@ascii.encode("user")[:]),
    Some(
      @pdflite.pdf_encryption_file_key(
        false,
        @ascii.encode("user")[:],
        4,
        owner_entry[:],
        -3904,
        file_id[:],
        128,
      ),
    ),
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
    try! values.authenticate_user_password(@ascii.encode("user")[:]),
    true,
  )
  @test.assert_eq(
    try! values.authenticate_user_password(@ascii.encode("bad")[:]),
    false,
  )
  @test.assert_eq(
    try! values.authenticate_owner_password(@ascii.encode("owner")[:]),
    true,
  )
  @test.assert_eq(
    try! values.authenticate_owner_password(@ascii.encode("bad")[:]),
    false,
  )
  @test.assert_eq(
    try! values.file_key_for_user_password(@ascii.encode("user")[:]),
    Some(crypt_aesv3_r5_file_key_for_test()),
  )
  @test.assert_eq(
    try! values.file_key_for_user_password(@ascii.encode("bad")[:]),
    None,
  )
  @test.assert_eq(
    try! values.file_key_for_owner_password(@ascii.encode("owner")[:]),
    Some(crypt_aesv3_r5_file_key_for_test()),
  )
  @test.assert_eq(
    try! values.file_key_for_owner_password(@ascii.encode("bad")[:]),
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
    @ascii.encode("user")[:],
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
    @ascii.encode("user")[:],
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
    @ascii.encode("user")[:],
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
    @ascii.encode("owner")[:],
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
    @ascii.encode("user")[:],
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
    @ascii.encode("owner")[:],
  )
  guard short_oe_result
    is Err(@pdflite.PdfError::EncryptionDictionaryEntryTooShort(name)) &&
    name == crypt_name_for_test("/OE") else {
    fail("expected short AESV3 /OE")
  }

  let decrypted = crypt_unwrap_decryption_result_for_test(
    try! doc.decrypt_with_user_password(@ascii.encode("user")[:]),
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
    try! doc.decrypt_with_owner_password(@ascii.encode("owner")[:]),
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
  let owner_entry = try! @pdflite.pdf_make_owner_password_entry(
    3,
    @ascii.encode("owner")[:],
    @ascii.encode("user")[:],
    128,
  )
  let user_entry = try! @pdflite.pdf_make_user_password_entry(
    false,
    @ascii.encode("user")[:],
    3,
    owner_entry[:],
    -3904,
    file_id[:],
    128,
  )
  let file_key = @pdflite.pdf_encryption_file_key(
    false,
    @ascii.encode("user")[:],
    3,
    owner_entry[:],
    -3904,
    file_id[:],
    128,
  )
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
  let plain_object : @pdflite.PdfObject = PdfDictionary([
    (crypt_name_for_test("/Title"), PdfString(@ascii.encode("hello"))),
  ])
  let encrypted_object = try! @pdflite.pdf_arc4_crypt_pdf_object(
    1,
    0,
    file_key[:],
    128,
    plain_object,
  )
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
    try! doc.decrypt_with_user_password(@ascii.encode("user")[:]),
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
    try! doc.decrypt_with_user_password(@ascii.encode("bad")[:]),
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
    try! direct_doc.decrypt_with_user_password(@ascii.encode("user")[:]),
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
    try! plain_doc.decrypt_with_user_password(@ascii.encode("anything")[:]),
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
  let owner_entry = try! @pdflite.pdf_make_owner_password_entry(
    3,
    @ascii.encode("owner")[:],
    @ascii.encode("user")[:],
    128,
  )
  let user_entry = try! @pdflite.pdf_make_user_password_entry(
    false,
    @ascii.encode("user")[:],
    3,
    owner_entry[:],
    -3904,
    file_id[:],
    128,
  )
  let file_key = @pdflite.pdf_encryption_file_key(
    false,
    @ascii.encode("user")[:],
    3,
    owner_entry[:],
    -3904,
    file_id[:],
    128,
  )
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
  let plain_object : @pdflite.PdfObject = PdfDictionary([
    (crypt_name_for_test("/Title"), PdfString(@ascii.encode("owner"))),
  ])
  let encrypted_object = try! @pdflite.pdf_arc4_crypt_pdf_object(
    1,
    0,
    file_key[:],
    128,
    plain_object,
  )
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
    try! doc.decrypt_with_owner_password(@ascii.encode("owner")[:]),
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
    try! doc.decrypt_with_owner_password(@ascii.encode("bad")[:]),
    None,
  )

  let plain_doc = @pdflite.pdf_document_empty()
  plain_doc.add_object_given_number(1, PdfString(@ascii.encode("plain")))
  let no_encryption = crypt_unwrap_decryption_result_for_test(
    try! plain_doc.decrypt_with_owner_password(@ascii.encode("anything")[:]),
  )
  @test.assert_eq(
    no_encryption.document.lookup_object_or_null(1),
    PdfString(@ascii.encode("plain")),
  )
  @test.assert_eq(no_encryption.denied_permissions, [])
}

///|
test "PdfDocument decrypt_with_user_password decrypts parsed AESV2 objects in a copy" {
  let file_id = @ascii.encode("doc-id")
  let owner_entry = try! @pdflite.pdf_make_owner_password_entry(
    4,
    @ascii.encode("owner")[:],
    @ascii.encode("user")[:],
    128,
  )
  let user_entry = try! @pdflite.pdf_make_user_password_entry(
    false,
    @ascii.encode("user")[:],
    4,
    owner_entry[:],
    -3904,
    file_id[:],
    128,
  )
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
  let file_key = @pdflite.pdf_encryption_file_key(
    false,
    @ascii.encode("user")[:],
    4,
    owner_entry[:],
    -3904,
    file_id[:],
    128,
  )
  let iv = crypt_model_bytes_for_test([
    0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19, 0x1a, 0x1b, 0x1c,
    0x1d, 0x1e, 0x1f,
  ])
  let key_title = crypt_name_for_test("/Title")
  let plain_object : @pdflite.PdfObject = PdfDictionary([
    (key_title, PdfString(@ascii.encode("aes"))),
  ])
  let encrypted_object : @pdflite.PdfObject = PdfDictionary([
    (
      key_title,
      PdfString(
        crypt_aesv2_encrypt_data_for_test(
          1,
          0,
          file_key[:],
          128,
          @ascii.encode("aes")[:],
          iv[:],
        ),
      ),
    ),
  ])
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
    try! doc.decrypt_with_user_password(@ascii.encode("user")[:]),
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
    try! doc.decrypt_with_owner_password(@ascii.encode("owner")[:]),
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
    try! doc.decrypt_with_user_password(@ascii.encode("bad")[:]),
    None,
  )
  @test.assert_eq(
    try! doc.decrypt_with_owner_password(@ascii.encode("bad")[:]),
    None,
  )
}

///|
test "PdfDocument decrypt_with_user_password honors EncryptMetadata false" {
  let file_id = @ascii.encode("doc-id")
  let owner_entry = try! @pdflite.pdf_make_owner_password_entry(
    4,
    @ascii.encode("owner")[:],
    @ascii.encode("user")[:],
    128,
  )
  let user_entry = try! @pdflite.pdf_make_user_password_entry(
    true,
    @ascii.encode("user")[:],
    4,
    owner_entry[:],
    -3904,
    file_id[:],
    128,
  )
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
  let file_key = @pdflite.pdf_encryption_file_key(
    true,
    @ascii.encode("user")[:],
    4,
    owner_entry[:],
    -3904,
    file_id[:],
    128,
  )
  let iv = crypt_model_bytes_for_test([
    0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19, 0x1a, 0x1b, 0x1c, 0x1d,
    0x1e, 0x1f, 0x20,
  ])
  let key_title = crypt_name_for_test("/Title")
  let plain_object : @pdflite.PdfObject = PdfDictionary([
    (key_title, PdfString(@ascii.encode("aes"))),
  ])
  let encrypted_object : @pdflite.PdfObject = PdfDictionary([
    (
      key_title,
      PdfString(
        crypt_aesv2_encrypt_data_for_test(
          1,
          0,
          file_key[:],
          128,
          @ascii.encode("aes")[:],
          iv[:],
        ),
      ),
    ),
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
    try! doc.decrypt_with_user_password(@ascii.encode("user")[:]),
  )
  @test.assert_eq(decrypted.document.lookup_object_or_null(1), plain_object)
  @test.assert_eq(decrypted.document.lookup_object_or_null(3), metadata_stream)
  let owner_decrypted = crypt_unwrap_decryption_result_for_test(
    try! doc.decrypt_with_owner_password(@ascii.encode("owner")[:]),
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
        crypt_aesv3_encrypt_data_for_test(
          file_key[:],
          @ascii.encode("aes3")[:],
          iv[:],
        ),
      ),
    ),
  ])
  let encrypted_metadata = crypt_aesv3_encrypt_data_for_test(
    file_key[:],
    @ascii.encode("meta")[:],
    iv[:],
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
    try! doc.decrypt_with_user_password(@ascii.encode("user")[:]),
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
    try! doc.decrypt_with_owner_password(@ascii.encode("owner")[:]),
  )
  @test.assert_eq(
    owner_decrypted.document.lookup_object_or_null(1),
    plain_object,
  )
  let metadata_skipped = crypt_unwrap_decryption_result_for_test(
    try! doc.decrypt_with_user_password(
      @ascii.encode("user")[:],
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
    try! doc.decrypt_with_user_password(@ascii.encode("bad")[:]),
    None,
  )
  @test.assert_eq(
    try! doc.decrypt_with_owner_password(@ascii.encode("bad")[:]),
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
test "pdf_pad_password truncates or pads with PDF password padding" {
  @test.assert_eq(@pdflite.pdf_password_padding().length(), 32)
  @test.assert_eq(@pdflite.pdf_password_padding()[0].to_int(), 0x28)
  @test.assert_eq(
    @pdflite.pdf_pad_password(@ascii.encode("abc")[:]),
    crypt_model_bytes_for_test([
      0x61, 0x62, 0x63, 0x28, 0xbf, 0x4e, 0x5e, 0x4e, 0x75, 0x8a, 0x41, 0x64, 0x00,
      0x4e, 0x56, 0xff, 0xfa, 0x01, 0x08, 0x2e, 0x2e, 0x00, 0xb6, 0xd0, 0x68, 0x3e,
      0x80, 0x2f, 0x0c, 0xa9, 0xfe, 0x64,
    ]),
  )
  @test.assert_eq(
    @pdflite.pdf_pad_password(
      @ascii.encode("012345678901234567890123456789012345")[:],
    ),
    @ascii.encode("01234567890123456789012345678901"),
  )
}

///|
test "pdf_sha256_digest matches SHA-256 known vector" {
  @test.assert_eq(
    @pdflite.pdf_sha256_digest(@ascii.encode("abc")[:]),
    crypt_model_bytes_for_test([
      0xba, 0x78, 0x16, 0xbf, 0x8f, 0x01, 0xcf, 0xea, 0x41, 0x41, 0x40, 0xde, 0x5d,
      0xae, 0x22, 0x23, 0xb0, 0x03, 0x61, 0xa3, 0x96, 0x17, 0x7a, 0x9c, 0xb4, 0x10,
      0xff, 0x61, 0xf2, 0x00, 0x15, 0xad,
    ]),
  )
}

///|
test "pdf_encryption_file_key matches CamlPDF R2 through R4 derivation" {
  let owner = crypt_model_bytes_for_test([ for value in 0..<32 => value ])
  @test.assert_eq(
    @pdflite.pdf_encryption_file_key(
      false,
      @ascii.encode("user")[:],
      2,
      owner[:],
      -4,
      @ascii.encode("doc-id")[:],
      40,
    ),
    crypt_model_bytes_for_test([0x09, 0xf0, 0x7c, 0x27, 0xf0]),
  )
  @test.assert_eq(
    @pdflite.pdf_encryption_file_key(
      false,
      Bytes::new(0)[:],
      3,
      owner[:],
      -3904,
      @ascii.encode("doc-id")[:],
      128,
    ),
    crypt_model_bytes_for_test([
      0x48, 0xd9, 0x52, 0xab, 0x8e, 0xdc, 0x9b, 0x82, 0xa0, 0x3a, 0xf2, 0x1c, 0xb1,
      0x6b, 0x61, 0x94,
    ]),
  )
  @test.assert_eq(
    @pdflite.pdf_encryption_file_key(
      true,
      Bytes::new(0)[:],
      4,
      owner[:],
      -3904,
      @ascii.encode("doc-id")[:],
      128,
    ),
    crypt_model_bytes_for_test([
      0x78, 0xcf, 0xeb, 0x72, 0x67, 0x35, 0x0d, 0x09, 0x98, 0xf4, 0xd4, 0xd5, 0x23,
      0x75, 0x5c, 0x12,
    ]),
  )
}

///|
test "pdf_make_user_password_entry matches CamlPDF U values" {
  let owner = crypt_model_bytes_for_test([ for value in 0..<32 => value ])
  @test.assert_eq(
    try! @pdflite.pdf_make_user_password_entry(
      false,
      @ascii.encode("user")[:],
      2,
      owner[:],
      -4,
      @ascii.encode("doc-id")[:],
      40,
    ),
    crypt_model_bytes_for_test([
      0x20, 0x54, 0x2f, 0x95, 0x6b, 0x5f, 0x5d, 0x84, 0x77, 0x36, 0x04, 0xf4, 0x9c,
      0x46, 0xfb, 0xdf, 0x57, 0x65, 0xe3, 0xa2, 0x96, 0x6c, 0xd3, 0x82, 0xb4, 0x96,
      0x0b, 0xd3, 0x77, 0xa3, 0x03, 0x41,
    ]),
  )
  @test.assert_eq(
    try! @pdflite.pdf_make_user_password_entry(
      false,
      Bytes::new(0)[:],
      3,
      owner[:],
      -3904,
      @ascii.encode("doc-id")[:],
      128,
    ),
    crypt_model_bytes_for_test([
      0x3d, 0xae, 0x18, 0x1a, 0x3c, 0x13, 0x8f, 0x79, 0xa6, 0xe2, 0xfa, 0x16, 0x86,
      0x96, 0x32, 0x9f, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
      0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    ]),
  )
  @test.assert_eq(
    try! @pdflite.pdf_make_user_password_entry(
      true,
      Bytes::new(0)[:],
      4,
      owner[:],
      -3904,
      @ascii.encode("doc-id")[:],
      128,
    ),
    crypt_model_bytes_for_test([
      0x93, 0x47, 0x7f, 0x4b, 0x13, 0x20, 0xa8, 0x08, 0x4f, 0x6a, 0x03, 0x20, 0xdc,
      0x1f, 0xd2, 0x9f, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
      0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    ]),
  )
}

///|
test "pdf_authenticate_user_password validates R2 and R3 user entries" {
  let owner = crypt_model_bytes_for_test([ for value in 0..<32 => value ])
  let r2_entry = try! @pdflite.pdf_make_user_password_entry(
    false,
    @ascii.encode("user")[:],
    2,
    owner[:],
    -4,
    @ascii.encode("doc-id")[:],
    40,
  )
  @test.assert_eq(
    try! @pdflite.pdf_authenticate_user_password(
      false,
      @ascii.encode("user")[:],
      2,
      r2_entry[:],
      owner[:],
      -4,
      @ascii.encode("doc-id")[:],
      40,
    ),
    true,
  )
  @test.assert_eq(
    try! @pdflite.pdf_authenticate_user_password(
      false,
      @ascii.encode("bad")[:],
      2,
      r2_entry[:],
      owner[:],
      -4,
      @ascii.encode("doc-id")[:],
      40,
    ),
    false,
  )
  let r3_entry = try! @pdflite.pdf_make_user_password_entry(
    false,
    Bytes::new(0)[:],
    3,
    owner[:],
    -3904,
    @ascii.encode("doc-id")[:],
    128,
  )
  @test.assert_eq(
    try! @pdflite.pdf_authenticate_user_password(
      false,
      Bytes::new(0)[:],
      3,
      r3_entry[:16],
      owner[:],
      -3904,
      @ascii.encode("doc-id")[:],
      128,
    ),
    true,
  )
  @test.assert_eq(
    try! @pdflite.pdf_authenticate_user_password(
      false,
      Bytes::new(0)[:],
      3,
      r3_entry[:8],
      owner[:],
      -3904,
      @ascii.encode("doc-id")[:],
      128,
    ),
    false,
  )
}

///|
test "pdf_authenticate_aesv3_password validates R5 SHA-256 entries" {
  let user_entry = crypt_aesv3_r5_user_entry_for_test()
  let owner_entry = crypt_aesv3_r5_owner_entry_for_test()
  @test.assert_eq(
    try! @pdflite.pdf_authenticate_user_password_aesv3(
      false,
      @ascii.encode("user")[:],
      user_entry[:],
    ),
    true,
  )
  @test.assert_eq(
    try! @pdflite.pdf_authenticate_user_password_aesv3(
      false,
      @ascii.encode("bad")[:],
      user_entry[:],
    ),
    false,
  )
  @test.assert_eq(
    try! @pdflite.pdf_authenticate_owner_password_aesv3(
      false,
      @ascii.encode("owner")[:],
      user_entry[:],
      owner_entry[:],
    ),
    true,
  )
  @test.assert_eq(
    try! @pdflite.pdf_authenticate_owner_password_aesv3(
      false,
      @ascii.encode("bad")[:],
      user_entry[:],
      owner_entry[:],
    ),
    false,
  )

  let short_user = crypt_repeated_bytes_for_test(0, 47)
  let short_user_result : Result[Bool, Error] = try? @pdflite.pdf_authenticate_user_password_aesv3(
    false,
    @ascii.encode("user")[:],
    short_user[:],
  )
  guard short_user_result
    is Err(@pdflite.PdfError::EncryptionDictionaryEntryTooShort(name)) &&
    name == crypt_name_for_test("/U") else {
    fail("expected short AESV3 /U")
  }

  let short_owner = crypt_repeated_bytes_for_test(0, 47)
  let short_owner_result : Result[Bool, Error] = try? @pdflite.pdf_authenticate_owner_password_aesv3(
    false,
    @ascii.encode("owner")[:],
    user_entry[:],
    short_owner[:],
  )
  guard short_owner_result
    is Err(@pdflite.PdfError::EncryptionDictionaryEntryTooShort(name)) &&
    name == crypt_name_for_test("/O") else {
    fail("expected short AESV3 /O")
  }

  let short_owner_user_result : Result[Bool, Error] = try? @pdflite.pdf_authenticate_owner_password_aesv3(
    false,
    @ascii.encode("owner")[:],
    short_user[:],
    owner_entry[:],
  )
  guard short_owner_user_result
    is Err(@pdflite.PdfError::EncryptionDictionaryEntryTooShort(name)) &&
    name == crypt_name_for_test("/U") else {
    fail("expected short AESV3 owner /U")
  }

  let iso_user_result : Result[Bool, Error] = try? @pdflite.pdf_authenticate_user_password_aesv3(
    true,
    @ascii.encode("user")[:],
    user_entry[:],
  )
  guard iso_user_result
    is Err(
      @pdflite.PdfError::EncryptionAuthenticationUnsupported(
        PdfCryptAESV3(true)
      )
    ) else {
    fail("expected unsupported ISO AESV3 user authentication")
  }

  let iso_owner_result : Result[Bool, Error] = try? @pdflite.pdf_authenticate_owner_password_aesv3(
    true,
    @ascii.encode("owner")[:],
    user_entry[:],
    owner_entry[:],
  )
  guard iso_owner_result
    is Err(
      @pdflite.PdfError::EncryptionAuthenticationUnsupported(
        PdfCryptAESV3(true)
      )
    ) else {
    fail("expected unsupported ISO AESV3 owner authentication")
  }

  @test.assert_eq(
    crypt_concat_bytes_for_test([@ascii.encode("user")[:], user_entry[32:40]]),
    crypt_model_bytes_for_test([
      0x75, 0x73, 0x65, 0x72, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08,
    ]),
  )
}

///|
test "pdf_make_owner_password_entry matches CamlPDF O values" {
  @test.assert_eq(
    try! @pdflite.pdf_make_owner_password_entry(
      2,
      @ascii.encode("owner")[:],
      @ascii.encode("user")[:],
      40,
    ),
    crypt_model_bytes_for_test([
      0x94, 0xe8, 0x09, 0x44, 0x19, 0x66, 0x2a, 0x77, 0x44, 0x42, 0xfb, 0x07, 0x2e,
      0x3d, 0x9f, 0x19, 0xe9, 0xd1, 0x30, 0xec, 0x09, 0xa4, 0xd0, 0x06, 0x1e, 0x78,
      0xfe, 0x92, 0x0f, 0x7a, 0xb6, 0x2f,
    ]),
  )
  @test.assert_eq(
    try! @pdflite.pdf_make_owner_password_entry(
      3,
      @ascii.encode("owner")[:],
      Bytes::new(0)[:],
      128,
    ),
    crypt_model_bytes_for_test([
      0x56, 0x6f, 0xa8, 0x73, 0xee, 0x33, 0xc7, 0x97, 0xcd, 0x3b, 0x90, 0x4f, 0xda,
      0xdf, 0x81, 0x4a, 0xfa, 0x34, 0xdf, 0x9a, 0x38, 0xf6, 0xed, 0x41, 0xb9, 0x84,
      0xe2, 0xc6, 0xda, 0x2a, 0xa6, 0xf5,
    ]),
  )
  @test.assert_eq(
    try! @pdflite.pdf_make_owner_password_entry(
      2,
      Bytes::new(0)[:],
      @ascii.encode("user")[:],
      40,
    ),
    crypt_model_bytes_for_test([
      0x8e, 0xc9, 0x9e, 0x00, 0xc3, 0xd1, 0x84, 0x91, 0x0a, 0x40, 0x64, 0xdf, 0x0f,
      0x95, 0x16, 0xb0, 0x41, 0x36, 0x2b, 0x9b, 0xf1, 0xdc, 0x3f, 0x68, 0xd1, 0x5b,
      0xf7, 0x1f, 0xb1, 0x6d, 0xc5, 0xf3,
    ]),
  )
}

///|
test "pdf_user_password_from_owner_password recovers padded user password" {
  let owner_entry = try! @pdflite.pdf_make_owner_password_entry(
    2,
    @ascii.encode("owner")[:],
    @ascii.encode("user")[:],
    40,
  )
  @test.assert_eq(
    try! @pdflite.pdf_user_password_from_owner_password(
      2,
      @ascii.encode("owner")[:],
      owner_entry[:],
      40,
    ),
    @pdflite.pdf_pad_password(@ascii.encode("user")[:]),
  )
  let owner_entry_r3 = try! @pdflite.pdf_make_owner_password_entry(
    3,
    @ascii.encode("owner")[:],
    Bytes::new(0)[:],
    128,
  )
  @test.assert_eq(
    try! @pdflite.pdf_user_password_from_owner_password(
      3,
      @ascii.encode("owner")[:],
      owner_entry_r3[:],
      128,
    ),
    @pdflite.pdf_password_padding(),
  )
}

///|
test "pdf_authenticate_owner_password validates through recovered user password" {
  let owner_entry = try! @pdflite.pdf_make_owner_password_entry(
    3,
    @ascii.encode("owner")[:],
    Bytes::new(0)[:],
    128,
  )
  let user_entry = try! @pdflite.pdf_make_user_password_entry(
    false,
    Bytes::new(0)[:],
    3,
    owner_entry[:],
    -3904,
    @ascii.encode("doc-id")[:],
    128,
  )
  @test.assert_eq(
    try! @pdflite.pdf_authenticate_owner_password(
      false,
      @ascii.encode("owner")[:],
      3,
      user_entry[:],
      owner_entry[:],
      -3904,
      @ascii.encode("doc-id")[:],
      128,
    ),
    true,
  )
  @test.assert_eq(
    try! @pdflite.pdf_authenticate_owner_password(
      false,
      @ascii.encode("bad")[:],
      3,
      user_entry[:],
      owner_entry[:],
      -3904,
      @ascii.encode("doc-id")[:],
      128,
    ),
    false,
  )
}

///|
test "pdf_arc4_crypt_pdf_object recurses through strings arrays and dictionaries" {
  let key = crypt_model_bytes_for_test([1, 2, 3, 4, 5])
  let encrypted_hello = crypt_model_bytes_for_test([
    0x7d, 0x1c, 0x38, 0x4c, 0xca,
  ])
  let key_s = @pdflite.pdf_name_of_bytes(@ascii.encode("/S"))
  let key_a = @pdflite.pdf_name_of_bytes(@ascii.encode("/A"))
  let key_n = @pdflite.pdf_name_of_bytes(@ascii.encode("/N"))
  let object : @pdflite.PdfObject = PdfDictionary([
    (key_s, PdfString(@ascii.encode("hello"))),
    (
      key_a,
      PdfArray([
        PdfString(@ascii.encode("hello")),
        PdfNameObject(key_n),
        PdfIndirect(9),
      ]),
    ),
  ])
  let encrypted = try! @pdflite.pdf_arc4_crypt_pdf_object(
    12,
    0,
    key[:],
    40,
    object,
  )
  @test.assert_eq(
    encrypted,
    PdfDictionary([
      (key_s, PdfString(encrypted_hello)),
      (
        key_a,
        PdfArray([
          PdfString(encrypted_hello),
          PdfNameObject(key_n),
          PdfIndirect(9),
        ]),
      ),
    ]),
  )
  @test.assert_eq(
    try! @pdflite.pdf_arc4_crypt_pdf_object(12, 0, key[:], 40, encrypted),
    object,
  )
}

///|
test "pdf_arc4_crypt_pdf_object encrypts stream dictionaries and data" {
  let key = crypt_model_bytes_for_test([1, 2, 3, 4, 5])
  let encrypted_hello = crypt_model_bytes_for_test([
    0x7d, 0x1c, 0x38, 0x4c, 0xca,
  ])
  let key_length = @pdflite.pdf_name_of_bytes(@ascii.encode("/Length"))
  let key_title = @pdflite.pdf_name_of_bytes(@ascii.encode("/Title"))
  let object : @pdflite.PdfObject = PdfStreamObject({
    dictionary: PdfDictionary([
      (key_length, PdfInteger(5)),
      (key_title, PdfString(@ascii.encode("hello"))),
    ]),
    data: StreamGot(@ascii.encode("hello")),
  })
  let encrypted = try! @pdflite.pdf_arc4_crypt_pdf_object(
    12,
    0,
    key[:],
    40,
    object,
  )
  @test.assert_eq(
    encrypted,
    PdfStreamObject({
      dictionary: PdfDictionary([
        (key_length, PdfInteger(5)),
        (key_title, PdfString(encrypted_hello)),
      ]),
      data: StreamGot(encrypted_hello),
    }),
  )
  @test.assert_eq(
    try! @pdflite.pdf_arc4_crypt_pdf_object(12, 0, key[:], 40, encrypted),
    object,
  )
}

///|
test "pdf_arc4_crypt_pdf_object skips metadata and identity Crypt streams" {
  let key = crypt_model_bytes_for_test([1, 2, 3, 4, 5])
  let hello = @ascii.encode("hello")
  let encrypted_hello = crypt_model_bytes_for_test([
    0x7d, 0x1c, 0x38, 0x4c, 0xca,
  ])
  let key_length = crypt_name_for_test("/Length")
  let key_title = crypt_name_for_test("/Title")
  let key_type = crypt_name_for_test("/Type")
  let key_filter = crypt_name_for_test("/Filter")
  let key_decodeparms = crypt_name_for_test("/DecodeParms")
  let key_name = crypt_name_for_test("/Name")
  let name_metadata = crypt_name_for_test("/Metadata")
  let name_crypt = crypt_name_for_test("/Crypt")
  let name_identity = crypt_name_for_test("/Identity")
  let name_stdcf = crypt_name_for_test("/StdCF")
  let metadata_stream = crypt_stream_for_test(
    [
      (key_length, PdfInteger(5)),
      (key_type, PdfNameObject(name_metadata)),
      (key_title, PdfString(hello)),
    ],
    hello,
  )
  @test.assert_eq(
    try! @pdflite.pdf_arc4_crypt_pdf_object(
      12,
      0,
      key[:],
      40,
      metadata_stream,
      no_encrypt_metadata=true,
    ),
    metadata_stream,
  )
  @test.assert_eq(
    try! @pdflite.pdf_arc4_crypt_pdf_object(12, 0, key[:], 40, metadata_stream),
    crypt_stream_for_test(
      [
        (key_length, PdfInteger(5)),
        (key_type, PdfNameObject(name_metadata)),
        (key_title, PdfString(encrypted_hello)),
      ],
      encrypted_hello,
    ),
  )
  let ordinary_stream = crypt_stream_for_test(
    [(key_length, PdfInteger(5)), (key_title, PdfString(hello))],
    hello,
  )
  @test.assert_eq(
    try! @pdflite.pdf_arc4_crypt_pdf_object(
      12,
      0,
      key[:],
      40,
      ordinary_stream,
      no_encrypt_metadata=true,
    ),
    crypt_stream_for_test(
      [(key_length, PdfInteger(5)), (key_title, PdfString(encrypted_hello))],
      encrypted_hello,
    ),
  )

  let crypt_stream = crypt_stream_for_test(
    [
      (key_length, PdfInteger(5)),
      (key_filter, PdfNameObject(name_crypt)),
      (key_title, PdfString(hello)),
    ],
    hello,
  )
  @test.assert_eq(
    try! @pdflite.pdf_arc4_crypt_pdf_object(12, 0, key[:], 40, crypt_stream),
    crypt_stream,
  )

  let identity_dict_stream = crypt_stream_for_test(
    [
      (key_length, PdfInteger(5)),
      (key_filter, PdfArray([PdfNameObject(name_crypt)])),
      (
        key_decodeparms,
        PdfDictionary([(key_name, PdfNameObject(name_identity))]),
      ),
      (key_title, PdfString(hello)),
    ],
    hello,
  )
  @test.assert_eq(
    try! @pdflite.pdf_arc4_crypt_pdf_object(
      12,
      0,
      key[:],
      40,
      identity_dict_stream,
    ),
    identity_dict_stream,
  )

  let identity_array_stream = crypt_stream_for_test(
    [
      (key_length, PdfInteger(5)),
      (key_filter, PdfNameObject(name_crypt)),
      (
        key_decodeparms,
        PdfArray([PdfDictionary([(key_name, PdfNameObject(name_identity))])]),
      ),
      (key_title, PdfString(hello)),
    ],
    hello,
  )
  @test.assert_eq(
    try! @pdflite.pdf_arc4_crypt_pdf_object(
      12,
      0,
      key[:],
      40,
      identity_array_stream,
    ),
    identity_array_stream,
  )

  let unnamed_crypt_stream = crypt_stream_for_test(
    [
      (key_length, PdfInteger(5)),
      (key_filter, PdfNameObject(name_crypt)),
      (key_decodeparms, PdfDictionary([])),
      (key_title, PdfString(hello)),
    ],
    hello,
  )
  @test.assert_eq(
    try! @pdflite.pdf_arc4_crypt_pdf_object(
      12,
      0,
      key[:],
      40,
      unnamed_crypt_stream,
    ),
    unnamed_crypt_stream,
  )

  let named_crypt_stream = crypt_stream_for_test(
    [
      (key_length, PdfInteger(5)),
      (key_filter, PdfNameObject(name_crypt)),
      (key_decodeparms, PdfDictionary([(key_name, PdfNameObject(name_stdcf))])),
      (key_title, PdfString(hello)),
    ],
    hello,
  )
  @test.assert_eq(
    try! @pdflite.pdf_arc4_crypt_pdf_object(
      12,
      0,
      key[:],
      40,
      named_crypt_stream,
    ),
    crypt_stream_for_test(
      [
        (key_length, PdfInteger(5)),
        (key_filter, PdfNameObject(name_crypt)),
        (
          key_decodeparms,
          PdfDictionary([(key_name, PdfNameObject(name_stdcf))]),
        ),
        (key_title, PdfString(encrypted_hello)),
      ],
      encrypted_hello,
    ),
  )

  let malformed_crypt_stream = crypt_stream_for_test(
    [
      (key_length, PdfInteger(5)),
      (key_filter, PdfNameObject(name_crypt)),
      (key_decodeparms, PdfDictionary([(key_name, PdfInteger(1))])),
      (key_title, PdfString(hello)),
    ],
    hello,
  )
  @test.assert_eq(
    try! @pdflite.pdf_arc4_crypt_pdf_object(
      12,
      0,
      key[:],
      40,
      malformed_crypt_stream,
    ),
    crypt_stream_for_test(
      [
        (key_length, PdfInteger(5)),
        (key_filter, PdfNameObject(name_crypt)),
        (key_decodeparms, PdfDictionary([(key_name, PdfInteger(1))])),
        (key_title, PdfString(encrypted_hello)),
      ],
      encrypted_hello,
    ),
  )
}

///|
test "pdf_aesv2_decrypt_pdf_object recurses through strings arrays dictionaries and streams" {
  let file_key = crypt_model_bytes_for_test([ for value in 0..<16 => value ])
  let iv = crypt_model_bytes_for_test([
    0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19, 0x1a, 0x1b, 0x1c,
    0x1d, 0x1e, 0x1f,
  ])
  let key_s = @pdflite.pdf_name_of_bytes(@ascii.encode("/S"))
  let key_a = @pdflite.pdf_name_of_bytes(@ascii.encode("/A"))
  let key_n = @pdflite.pdf_name_of_bytes(@ascii.encode("/N"))
  let encrypted_hello = crypt_aesv2_encrypt_data_for_test(
    12,
    0,
    file_key[:],
    128,
    @ascii.encode("hello")[:],
    iv[:],
  )
  @test.assert_eq(
    try! @pdflite.pdf_aesv2_decrypt_object_data(
      12,
      0,
      file_key[:],
      128,
      encrypted_hello[:],
    ),
    @ascii.encode("hello"),
  )
  let object : @pdflite.PdfObject = PdfDictionary([
    (key_s, PdfString(@ascii.encode("hello"))),
    (
      key_a,
      PdfArray([
        PdfString(@ascii.encode("hello")),
        PdfNameObject(key_n),
        PdfIndirect(9),
      ]),
    ),
  ])
  let encrypted : @pdflite.PdfObject = PdfDictionary([
    (key_s, PdfString(encrypted_hello)),
    (
      key_a,
      PdfArray([
        PdfString(encrypted_hello),
        PdfNameObject(key_n),
        PdfIndirect(9),
      ]),
    ),
  ])
  @test.assert_eq(
    try! @pdflite.pdf_aesv2_decrypt_pdf_object(
      12,
      0,
      file_key[:],
      128,
      encrypted,
    ),
    object,
  )

  let key_length = @pdflite.pdf_name_of_bytes(@ascii.encode("/Length"))
  let key_title = @pdflite.pdf_name_of_bytes(@ascii.encode("/Title"))
  let encrypted_stream : @pdflite.PdfObject = PdfStreamObject({
    dictionary: PdfDictionary([
      (key_length, PdfInteger(encrypted_hello.length())),
      (key_title, PdfString(encrypted_hello)),
    ]),
    data: StreamGot(encrypted_hello),
  })
  let plain_stream : @pdflite.PdfObject = PdfStreamObject({
    dictionary: PdfDictionary([
      (key_length, PdfInteger(5)),
      (key_title, PdfString(@ascii.encode("hello"))),
    ]),
    data: StreamGot(@ascii.encode("hello")),
  })
  @test.assert_eq(
    try! @pdflite.pdf_aesv2_decrypt_pdf_object(
      12,
      0,
      file_key[:],
      128,
      encrypted_stream,
    ),
    plain_stream,
  )
  let key_type = crypt_name_for_test("/Type")
  let key_filter = crypt_name_for_test("/Filter")
  let metadata_stream = crypt_stream_for_test(
    [
      (key_length, PdfInteger(encrypted_hello.length())),
      (key_type, PdfNameObject(crypt_name_for_test("/Metadata"))),
      (key_title, PdfString(encrypted_hello)),
    ],
    encrypted_hello,
  )
  @test.assert_eq(
    try! @pdflite.pdf_aesv2_decrypt_pdf_object(
      12,
      0,
      file_key[:],
      128,
      metadata_stream,
      no_encrypt_metadata=true,
    ),
    metadata_stream,
  )
  let crypt_stream = crypt_stream_for_test(
    [
      (key_length, PdfInteger(encrypted_hello.length())),
      (key_filter, PdfNameObject(crypt_name_for_test("/Crypt"))),
      (key_title, PdfString(encrypted_hello)),
    ],
    encrypted_hello,
  )
  @test.assert_eq(
    try! @pdflite.pdf_aesv2_decrypt_pdf_object(
      12,
      0,
      file_key[:],
      128,
      crypt_stream,
    ),
    crypt_stream,
  )
}

///|
test "pdf_aesv3_decrypt_pdf_object recurses through strings arrays dictionaries and streams" {
  let file_key = crypt_aesv3_r5_file_key_for_test()
  let iv = crypt_model_bytes_for_test([
    0x20, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27, 0x28, 0x29, 0x2a, 0x2b, 0x2c,
    0x2d, 0x2e, 0x2f,
  ])
  let key_s = @pdflite.pdf_name_of_bytes(@ascii.encode("/S"))
  let key_a = @pdflite.pdf_name_of_bytes(@ascii.encode("/A"))
  let key_n = @pdflite.pdf_name_of_bytes(@ascii.encode("/N"))
  let encrypted_hello = crypt_aesv3_encrypt_data_for_test(
    file_key[:],
    @ascii.encode("hello")[:],
    iv[:],
  )
  let object : @pdflite.PdfObject = PdfDictionary([
    (key_s, PdfString(@ascii.encode("hello"))),
    (
      key_a,
      PdfArray([
        PdfString(@ascii.encode("hello")),
        PdfNameObject(key_n),
        PdfIndirect(9),
      ]),
    ),
  ])
  let encrypted : @pdflite.PdfObject = PdfDictionary([
    (key_s, PdfString(encrypted_hello)),
    (
      key_a,
      PdfArray([
        PdfString(encrypted_hello),
        PdfNameObject(key_n),
        PdfIndirect(9),
      ]),
    ),
  ])
  @test.assert_eq(
    try! @pdflite.pdf_aesv3_decrypt_pdf_object(file_key[:], encrypted),
    object,
  )

  let key_length = @pdflite.pdf_name_of_bytes(@ascii.encode("/Length"))
  let key_title = @pdflite.pdf_name_of_bytes(@ascii.encode("/Title"))
  let encrypted_stream : @pdflite.PdfObject = PdfStreamObject({
    dictionary: PdfDictionary([
      (key_length, PdfInteger(encrypted_hello.length())),
      (key_title, PdfString(encrypted_hello)),
    ]),
    data: StreamGot(encrypted_hello),
  })
  let plain_stream : @pdflite.PdfObject = PdfStreamObject({
    dictionary: PdfDictionary([
      (key_length, PdfInteger(5)),
      (key_title, PdfString(@ascii.encode("hello"))),
    ]),
    data: StreamGot(@ascii.encode("hello")),
  })
  @test.assert_eq(
    try! @pdflite.pdf_aesv3_decrypt_pdf_object(file_key[:], encrypted_stream),
    plain_stream,
  )
  let metadata_stream = crypt_stream_for_test(
    [
      (key_length, PdfInteger(encrypted_hello.length())),
      (
        crypt_name_for_test("/Type"),
        PdfNameObject(crypt_name_for_test("/Metadata")),
      ),
      (key_title, PdfString(encrypted_hello)),
    ],
    encrypted_hello,
  )
  @test.assert_eq(
    try! @pdflite.pdf_aesv3_decrypt_pdf_object(
      file_key[:],
      metadata_stream,
      no_encrypt_metadata=true,
    ),
    metadata_stream,
  )
}

///|
test "PdfDocument arc4_crypt_parsed_objects encrypts parsed objects in a copy" {
  let key = crypt_model_bytes_for_test([1, 2, 3, 4, 5])
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(1, PdfString(@ascii.encode("hello")))
  doc.add_object_given_number(2, PdfString(@ascii.encode("skip")))
  doc.add_object_given_number(
    3,
    PdfString(@ascii.encode("hello")),
    generation=1,
  )
  let encrypted = try! doc.arc4_crypt_parsed_objects(
    key[:],
    40,
    skip_object_number=2,
  )
  @test.assert_eq(
    encrypted.lookup_object_or_null(1),
    try! @pdflite.pdf_arc4_crypt_pdf_object(
      1,
      0,
      key[:],
      40,
      PdfString(@ascii.encode("hello")),
    ),
  )
  @test.assert_eq(
    encrypted.lookup_object_or_null(2),
    PdfString(@ascii.encode("skip")),
  )
  @test.assert_eq(
    encrypted.lookup_object_or_null(3),
    try! @pdflite.pdf_arc4_crypt_pdf_object(
      3,
      1,
      key[:],
      40,
      PdfString(@ascii.encode("hello")),
    ),
  )
  @test.assert_eq(
    doc.lookup_object_or_null(1),
    PdfString(@ascii.encode("hello")),
  )
  @test.assert_eq(
    (try! encrypted.arc4_crypt_parsed_objects(key[:], 40, skip_object_number=2)).lookup_object_or_null(
      1,
    ),
    PdfString(@ascii.encode("hello")),
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
