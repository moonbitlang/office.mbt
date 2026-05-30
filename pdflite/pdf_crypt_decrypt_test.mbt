///|
fn crypt_decrypt_model_bytes_for_test(
  values : ArrayView[Int],
) -> @pdflite.PdfBytes {
  try! @pdflite.pdf_bytes_of_int_array(values)
}

///|
fn crypt_decrypt_aesv3_encrypt_data_for_test(
  file_key : BytesView,
  data : BytesView,
  iv : BytesView,
) -> @pdflite.PdfBytes raise {
  guard file_key == crypt_decrypt_aesv3_r5_file_key_for_test() else {
    fail("expected AESV3 R5 file key fixture")
  }
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(1, PdfString(data.to_owned()))
  let encrypted_doc = try! doc.encrypt_256bit_aesv3_with_providers(
    @ascii.encode("user"),
    @ascii.encode("owner"),
    [],
    crypt_decrypt_aesv3_r5_random_for_test,
    fn(_, _, _) { iv.to_owned() },
    file_id=@ascii.encode("doc-id"),
  )
  match encrypted_doc.lookup_object_or_null(1) {
    PdfString(bytes) => bytes
    _ => fail("expected encrypted AESV3 string")
  }
}

///|
fn crypt_decrypt_aesv3_r5_user_entry_for_test() -> @pdflite.PdfBytes {
  crypt_decrypt_model_bytes_for_test([
    0xad, 0x7c, 0x98, 0xe2, 0x51, 0xcb, 0x1c, 0x7b, 0x3e, 0x28, 0x30, 0xb6, 0xf0,
    0xbe, 0xcb, 0xd8, 0x35, 0x2a, 0x6a, 0xb7, 0x12, 0x23, 0x2d, 0x6e, 0x82, 0xf2,
    0xfc, 0xa4, 0x5f, 0x30, 0x4d, 0xcc, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
    0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f, 0x10,
  ])
}

///|
fn crypt_decrypt_aesv3_r5_owner_entry_for_test() -> @pdflite.PdfBytes {
  crypt_decrypt_model_bytes_for_test([
    0xf9, 0x90, 0x4f, 0x90, 0x02, 0x10, 0x0b, 0x3e, 0xba, 0x57, 0x69, 0x0b, 0x67,
    0x32, 0x30, 0xde, 0xfc, 0xcd, 0x12, 0x39, 0x9f, 0x8d, 0xa1, 0xa8, 0x73, 0x41,
    0x48, 0x36, 0x93, 0x7e, 0xbf, 0xf7, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17,
    0x18, 0x19, 0x1a, 0x1b, 0x1c, 0x1d, 0x1e, 0x1f, 0x20,
  ])
}

///|
fn crypt_decrypt_aesv3_r5_file_key_for_test() -> @pdflite.PdfBytes {
  crypt_decrypt_model_bytes_for_test([ for value in 0..<32 => value ])
}

///|
fn crypt_decrypt_aesv3_r5_user_encryption_key_for_test() -> @pdflite.PdfBytes {
  crypt_decrypt_model_bytes_for_test([
    0xe4, 0x35, 0xfd, 0x1c, 0x68, 0x70, 0xfc, 0x3b, 0x50, 0x7f, 0x7c, 0x3d, 0x30,
    0xd0, 0x2e, 0x06, 0xb7, 0x60, 0x68, 0x50, 0x81, 0x95, 0xc1, 0x29, 0x87, 0x9c,
    0x23, 0xce, 0x43, 0xee, 0xda, 0x22,
  ])
}

///|
fn crypt_decrypt_aesv3_r5_owner_encryption_key_for_test() -> @pdflite.PdfBytes {
  crypt_decrypt_model_bytes_for_test([
    0x93, 0x8a, 0x69, 0x29, 0xac, 0xa0, 0x6a, 0x79, 0x47, 0xde, 0x9d, 0xc4, 0x68,
    0x29, 0x04, 0xca, 0xda, 0x26, 0xbf, 0x1b, 0xb2, 0x8e, 0xc9, 0xc8, 0x2b, 0x83,
    0x9d, 0x5b, 0x89, 0x4e, 0x6c, 0xec,
  ])
}

///|
fn crypt_decrypt_aesv3_r5_permissions_for_test() -> @pdflite.PdfBytes {
  crypt_decrypt_model_bytes_for_test([
    0x61, 0x58, 0xb9, 0xdd, 0xf6, 0x26, 0xa8, 0xfa, 0x36, 0x68, 0x20, 0xad, 0x7e,
    0xd7, 0xde, 0x4d,
  ])
}

///|
#warnings("-unused_error_type")
fn crypt_decrypt_aesv3_r5_random_for_test(
  field : @crypt_core.PdfAesV3RandomField,
  _length : Int,
) -> @pdflite.PdfBytes raise @pdflite.PdfError {
  match field {
    PdfAesV3FileKey => crypt_decrypt_aesv3_r5_file_key_for_test()
    PdfAesV3UserValidationSalt =>
      crypt_decrypt_model_bytes_for_test([
        0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08,
      ])
    PdfAesV3UserKeySalt =>
      crypt_decrypt_model_bytes_for_test([
        0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f, 0x10,
      ])
    PdfAesV3OwnerValidationSalt =>
      crypt_decrypt_model_bytes_for_test([
        0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18,
      ])
    PdfAesV3OwnerKeySalt =>
      crypt_decrypt_model_bytes_for_test([
        0x19, 0x1a, 0x1b, 0x1c, 0x1d, 0x1e, 0x1f, 0x20,
      ])
    PdfAesV3PermissionsPadding => Bytes::new(4)
  }
}

///|
fn crypt_decrypt_name_for_test(text : String) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn crypt_decrypt_stream_for_test(
  entries : ArrayView[(@pdflite.PdfName, @pdflite.PdfObject)],
  data : @pdflite.PdfBytes,
) -> @pdflite.PdfObject {
  PdfStreamObject({
    dictionary: PdfDictionary([ for entry in entries => entry ]),
    data: StreamGot(data),
  })
}

///|
fn crypt_decrypt_standard_encrypt_dictionary_values_for_test(
  entries : ArrayView[(@pdflite.PdfName, @pdflite.PdfObject)],
  owner_entry : @pdflite.PdfBytes,
  user_entry : @pdflite.PdfBytes,
  permissions : Int,
) -> @pdflite.PdfObject {
  let output : Array[(@pdflite.PdfName, @pdflite.PdfObject)] = [
    (
      crypt_decrypt_name_for_test("/Filter"),
      PdfNameObject(crypt_decrypt_name_for_test("/Standard")),
    ),
    (crypt_decrypt_name_for_test("/O"), PdfString(owner_entry)),
    (crypt_decrypt_name_for_test("/U"), PdfString(user_entry)),
    (crypt_decrypt_name_for_test("/P"), PdfInteger(permissions)),
  ]
  for entry in entries {
    output.push(entry)
  }
  PdfDictionary(output)
}

///|
fn crypt_decrypt_encrypt_dictionary_from_doc_for_test(
  doc : @pdflite.PdfDocument,
) -> @pdflite.PdfObject raise {
  match
    doc.trailer_dict().lookup_immediate(crypt_decrypt_name_for_test("/Encrypt")) {
    Some(PdfIndirect(number)) => doc.lookup_object_or_null(number)
    Some(value) => value
    None => fail("expected encryption dictionary")
  }
}

///|
fn crypt_decrypt_unwrap_decryption_result_for_test(
  result : @pdflite.PdfDecryptionResult?,
) -> @pdflite.PdfDecryptionResult raise {
  match result {
    Some(value) => value
    None => fail("expected decrypted document")
  }
}

///|
test "PdfDocument decrypt_with_user_password decrypts parsed ARC4 objects in a copy" {
  let file_id = @ascii.encode("doc-id")
  let plain_object : @pdflite.PdfObject = PdfDictionary([
    (crypt_decrypt_name_for_test("/Title"), PdfString(@ascii.encode("hello"))),
  ])
  let source = @pdflite.pdf_document_empty()
  source.add_object_given_number(1, plain_object)
  let template = try! source.encrypt_128bit(
    @ascii.encode("user"),
    @ascii.encode("owner"),
    @crypt_core.pdf_permissions_of_p(-3904),
    file_id~,
  )
  let encrypt_dictionary = try! crypt_decrypt_encrypt_dictionary_from_doc_for_test(
    template,
  )
  let encrypted_object = template.lookup_object_or_null(1)
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(1, encrypted_object)
  doc.add_object_given_number(2, encrypt_dictionary)
  doc.set_trailer_dict(
    PdfDictionary([
      (crypt_decrypt_name_for_test("/Encrypt"), PdfIndirect(2)),
      (
        crypt_decrypt_name_for_test("/ID"),
        PdfArray([
          PdfString(@ascii.encode("doc-id")),
          PdfString(@ascii.encode("ignored")),
        ]),
      ),
    ]),
  )

  let decrypted = crypt_decrypt_unwrap_decryption_result_for_test(
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
    .lookup_immediate(crypt_decrypt_name_for_test("/Encrypt")),
    None,
  )
  @test.assert_eq(
    decrypted.denied_permissions,
    @crypt_core.pdf_permissions_of_p(-3904),
  )
  @test.assert_eq(doc.lookup_object_or_null(1), encrypted_object)
  @test.assert_eq(
    doc.trailer_dict().lookup_immediate(crypt_decrypt_name_for_test("/Encrypt")),
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
      (crypt_decrypt_name_for_test("/Encrypt"), encrypt_dictionary),
      (
        crypt_decrypt_name_for_test("/ID"),
        PdfArray([
          PdfString(@ascii.encode("doc-id")),
          PdfString(@ascii.encode("ignored")),
        ]),
      ),
    ]),
  )
  let direct_decrypted = crypt_decrypt_unwrap_decryption_result_for_test(
    try! direct_doc.decrypt_with_user_password(@ascii.encode("user")),
  )
  @test.assert_eq(
    direct_decrypted.document.lookup_object_or_null(1),
    plain_object,
  )
  @test.assert_eq(
    direct_decrypted.document
    .trailer_dict()
    .lookup_immediate(crypt_decrypt_name_for_test("/Encrypt")),
    None,
  )

  let plain_doc = @pdflite.pdf_document_empty()
  plain_doc.add_object_given_number(1, PdfString(@ascii.encode("plain")))
  let no_encryption = crypt_decrypt_unwrap_decryption_result_for_test(
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
    (crypt_decrypt_name_for_test("/Title"), PdfString(@ascii.encode("owner"))),
  ])
  let source = @pdflite.pdf_document_empty()
  source.add_object_given_number(1, plain_object)
  let template = try! source.encrypt_128bit(
    @ascii.encode("user"),
    @ascii.encode("owner"),
    @crypt_core.pdf_permissions_of_p(-3904),
    file_id~,
  )
  let encrypt_dictionary = try! crypt_decrypt_encrypt_dictionary_from_doc_for_test(
    template,
  )
  let encrypted_object = template.lookup_object_or_null(1)
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(1, encrypted_object)
  doc.add_object_given_number(2, encrypt_dictionary)
  doc.set_trailer_dict(
    PdfDictionary([
      (crypt_decrypt_name_for_test("/Encrypt"), PdfIndirect(2)),
      (
        crypt_decrypt_name_for_test("/ID"),
        PdfArray([
          PdfString(@ascii.encode("doc-id")),
          PdfString(@ascii.encode("ignored")),
        ]),
      ),
    ]),
  )

  let decrypted = crypt_decrypt_unwrap_decryption_result_for_test(
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
    .lookup_immediate(crypt_decrypt_name_for_test("/Encrypt")),
    None,
  )
  @test.assert_eq(
    decrypted.denied_permissions,
    @crypt_core.pdf_permissions_of_p(-3904),
  )
  @test.assert_eq(doc.lookup_object_or_null(1), encrypted_object)
  @test.assert_eq(
    try! doc.decrypt_with_owner_password(@ascii.encode("bad")),
    None,
  )

  let plain_doc = @pdflite.pdf_document_empty()
  plain_doc.add_object_given_number(1, PdfString(@ascii.encode("plain")))
  let no_encryption = crypt_decrypt_unwrap_decryption_result_for_test(
    try! plain_doc.decrypt_with_owner_password(@ascii.encode("anything")),
  )
  @test.assert_eq(
    no_encryption.document.lookup_object_or_null(1),
    PdfString(@ascii.encode("plain")),
  )
  @test.assert_eq(no_encryption.denied_permissions, [])
}

///|
test "PdfDocument decrypt_with_passwords handles unencrypted, blank, user, and owner passwords" {
  let key_title = crypt_decrypt_name_for_test("/Title")
  let plain_object : @pdflite.PdfObject = PdfDictionary([
    (key_title, PdfString(@ascii.encode("secret"))),
  ])
  let plain_doc = @pdflite.pdf_document_empty()
  plain_doc.add_object_given_number(1, plain_object)
  let plain_result = crypt_decrypt_unwrap_decryption_result_for_test(
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
  let blank_decrypted = crypt_decrypt_unwrap_decryption_result_for_test(
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
  let user_decrypted = crypt_decrypt_unwrap_decryption_result_for_test(
    try! encrypted.decrypt_with_passwords(
      user_password=Some(@ascii.encode("user")),
    ),
  )
  @test.assert_eq(
    user_decrypted.document.lookup_object_or_null(1),
    plain_object,
  )
  @test.assert_eq(user_decrypted.denied_permissions, [PdfNoPrint])
  let owner_decrypted = crypt_decrypt_unwrap_decryption_result_for_test(
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
test "PdfDocument decrypt_single_stream handles unencrypted and ARC4 streams" {
  let key_length = crypt_decrypt_name_for_test("/Length")
  let key_title = crypt_decrypt_name_for_test("/Title")
  let plain_stream = crypt_decrypt_stream_for_test(
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
  let key_length = crypt_decrypt_name_for_test("/Length")
  let key_title = crypt_decrypt_name_for_test("/Title")
  let plain_stream = crypt_decrypt_stream_for_test(
    [(key_length, PdfInteger(3)), (key_title, PdfString(@ascii.encode("aes")))],
    @ascii.encode("raw"),
  )

  let aesv2_file_id = @ascii.encode("doc-id")
  let aesv2_iv = crypt_decrypt_model_bytes_for_test([
    0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19, 0x1a, 0x1b, 0x1c,
    0x1d, 0x1e, 0x1f,
  ])
  let aesv2_source = @pdflite.pdf_document_empty()
  aesv2_source.add_object_given_number(1, plain_stream)
  let aesv2_doc = try! aesv2_source.encrypt_128bit_aesv2_with_iv_provider(
    @ascii.encode("user"),
    @ascii.encode("owner"),
    @crypt_core.pdf_permissions_of_p(-3904),
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

  let aesv3_user_entry = crypt_decrypt_aesv3_r5_user_entry_for_test()
  let aesv3_owner_entry = crypt_decrypt_aesv3_r5_owner_entry_for_test()
  let aesv3_file_key = crypt_decrypt_aesv3_r5_file_key_for_test()
  let aesv3_encrypt_dictionary = crypt_decrypt_standard_encrypt_dictionary_values_for_test(
    [
      (crypt_decrypt_name_for_test("/V"), PdfInteger(5)),
      (crypt_decrypt_name_for_test("/R"), PdfInteger(5)),
      (
        crypt_decrypt_name_for_test("/CF"),
        PdfDictionary([
          (
            crypt_decrypt_name_for_test("/StdCF"),
            PdfDictionary([
              (
                crypt_decrypt_name_for_test("/CFM"),
                PdfNameObject(crypt_decrypt_name_for_test("/AESV3")),
              ),
            ]),
          ),
        ]),
      ),
      (
        crypt_decrypt_name_for_test("/UE"),
        PdfString(crypt_decrypt_aesv3_r5_user_encryption_key_for_test()),
      ),
      (
        crypt_decrypt_name_for_test("/OE"),
        PdfString(crypt_decrypt_aesv3_r5_owner_encryption_key_for_test()),
      ),
      (
        crypt_decrypt_name_for_test("/Perms"),
        PdfString(crypt_decrypt_aesv3_r5_permissions_for_test()),
      ),
    ],
    aesv3_owner_entry,
    aesv3_user_entry,
    -3904,
  )
  let aesv3_iv = crypt_decrypt_model_bytes_for_test([
    0x20, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27, 0x28, 0x29, 0x2a, 0x2b, 0x2c,
    0x2d, 0x2e, 0x2f,
  ])
  let aesv3_encrypted_title = try! crypt_decrypt_aesv3_encrypt_data_for_test(
    aesv3_file_key,
    @ascii.encode("aes"),
    aesv3_iv,
  )
  let aesv3_encrypted_data = try! crypt_decrypt_aesv3_encrypt_data_for_test(
    aesv3_file_key,
    @ascii.encode("raw"),
    aesv3_iv,
  )
  let aesv3_encrypted_stream = crypt_decrypt_stream_for_test(
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
      (crypt_decrypt_name_for_test("/Encrypt"), PdfIndirect(2)),
      (
        crypt_decrypt_name_for_test("/ID"),
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
  let iv = crypt_decrypt_model_bytes_for_test([
    0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19, 0x1a, 0x1b, 0x1c,
    0x1d, 0x1e, 0x1f,
  ])
  let key_title = crypt_decrypt_name_for_test("/Title")
  let plain_object : @pdflite.PdfObject = PdfDictionary([
    (key_title, PdfString(@ascii.encode("aes"))),
  ])
  let source = @pdflite.pdf_document_empty()
  source.add_object_given_number(1, plain_object)
  let template = try! source.encrypt_128bit_aesv2_with_iv_provider(
    @ascii.encode("user"),
    @ascii.encode("owner"),
    @crypt_core.pdf_permissions_of_p(-3904),
    fn(_, _, _) { iv },
    file_id~,
  )
  let encrypt_dictionary = try! crypt_decrypt_encrypt_dictionary_from_doc_for_test(
    template,
  )
  let doc = @pdflite.pdf_document_empty()
  let encrypted_object = template.lookup_object_or_null(1)
  doc.add_object_given_number(1, encrypted_object)
  doc.add_object_given_number(2, encrypt_dictionary)
  doc.set_trailer_dict(
    PdfDictionary([
      (crypt_decrypt_name_for_test("/Encrypt"), PdfIndirect(2)),
      (
        crypt_decrypt_name_for_test("/ID"),
        PdfArray([
          PdfString(@ascii.encode("doc-id")),
          PdfString(@ascii.encode("ignored")),
        ]),
      ),
    ]),
  )

  let decrypted = crypt_decrypt_unwrap_decryption_result_for_test(
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
    .lookup_immediate(crypt_decrypt_name_for_test("/Encrypt")),
    None,
  )
  @test.assert_eq(
    decrypted.denied_permissions,
    @crypt_core.pdf_permissions_of_p(-3904),
  )
  let owner_decrypted = crypt_decrypt_unwrap_decryption_result_for_test(
    try! doc.decrypt_with_owner_password(@ascii.encode("owner")),
  )
  @test.assert_eq(
    owner_decrypted.document.lookup_object_or_null(1),
    plain_object,
  )
  @test.assert_eq(
    owner_decrypted.document
    .trailer_dict()
    .lookup_immediate(crypt_decrypt_name_for_test("/Encrypt")),
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
  let iv = crypt_decrypt_model_bytes_for_test([
    0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19, 0x1a, 0x1b, 0x1c, 0x1d,
    0x1e, 0x1f, 0x20,
  ])
  let key_title = crypt_decrypt_name_for_test("/Title")
  let plain_object : @pdflite.PdfObject = PdfDictionary([
    (key_title, PdfString(@ascii.encode("aes"))),
  ])
  let metadata_stream = crypt_decrypt_stream_for_test(
    [
      (crypt_decrypt_name_for_test("/Length"), PdfInteger(4)),
      (
        crypt_decrypt_name_for_test("/Type"),
        PdfNameObject(crypt_decrypt_name_for_test("/Metadata")),
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
    @crypt_core.pdf_permissions_of_p(-3904),
    fn(_, _, _) { iv },
    encrypt_metadata=false,
    file_id~,
  )
  let encrypt_dictionary = try! crypt_decrypt_encrypt_dictionary_from_doc_for_test(
    template,
  )
  let encrypted_object = template.lookup_object_or_null(1)
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(1, encrypted_object)
  doc.add_object_given_number(2, encrypt_dictionary)
  doc.add_object_given_number(3, metadata_stream)
  doc.set_trailer_dict(
    PdfDictionary([
      (crypt_decrypt_name_for_test("/Encrypt"), PdfIndirect(2)),
      (
        crypt_decrypt_name_for_test("/ID"),
        PdfArray([
          PdfString(@ascii.encode("doc-id")),
          PdfString(@ascii.encode("ignored")),
        ]),
      ),
    ]),
  )

  let decrypted = crypt_decrypt_unwrap_decryption_result_for_test(
    try! doc.decrypt_with_user_password(@ascii.encode("user")),
  )
  @test.assert_eq(decrypted.document.lookup_object_or_null(1), plain_object)
  @test.assert_eq(decrypted.document.lookup_object_or_null(3), metadata_stream)
  let owner_decrypted = crypt_decrypt_unwrap_decryption_result_for_test(
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
  let user_entry = crypt_decrypt_aesv3_r5_user_entry_for_test()
  let owner_entry = crypt_decrypt_aesv3_r5_owner_entry_for_test()
  let file_key = crypt_decrypt_aesv3_r5_file_key_for_test()
  let encrypt_dictionary = crypt_decrypt_standard_encrypt_dictionary_values_for_test(
    [
      (crypt_decrypt_name_for_test("/V"), PdfInteger(5)),
      (crypt_decrypt_name_for_test("/R"), PdfInteger(5)),
      (
        crypt_decrypt_name_for_test("/CF"),
        PdfDictionary([
          (
            crypt_decrypt_name_for_test("/StdCF"),
            PdfDictionary([
              (
                crypt_decrypt_name_for_test("/CFM"),
                PdfNameObject(crypt_decrypt_name_for_test("/AESV3")),
              ),
            ]),
          ),
        ]),
      ),
      (
        crypt_decrypt_name_for_test("/UE"),
        PdfString(crypt_decrypt_aesv3_r5_user_encryption_key_for_test()),
      ),
      (
        crypt_decrypt_name_for_test("/OE"),
        PdfString(crypt_decrypt_aesv3_r5_owner_encryption_key_for_test()),
      ),
      (
        crypt_decrypt_name_for_test("/Perms"),
        PdfString(crypt_decrypt_aesv3_r5_permissions_for_test()),
      ),
    ],
    owner_entry,
    user_entry,
    -3904,
  )
  let iv = crypt_decrypt_model_bytes_for_test([
    0x20, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27, 0x28, 0x29, 0x2a, 0x2b, 0x2c,
    0x2d, 0x2e, 0x2f,
  ])
  let key_title = crypt_decrypt_name_for_test("/Title")
  let plain_object : @pdflite.PdfObject = PdfDictionary([
    (key_title, PdfString(@ascii.encode("aes3"))),
  ])
  let encrypted_object : @pdflite.PdfObject = PdfDictionary([
    (
      key_title,
      PdfString(
        try! crypt_decrypt_aesv3_encrypt_data_for_test(
          file_key,
          @ascii.encode("aes3"),
          iv,
        ),
      ),
    ),
  ])
  let encrypted_metadata = try! crypt_decrypt_aesv3_encrypt_data_for_test(
    file_key,
    @ascii.encode("meta"),
    iv,
  )
  let encrypted_metadata_stream = crypt_decrypt_stream_for_test(
    [
      (
        crypt_decrypt_name_for_test("/Length"),
        PdfInteger(encrypted_metadata.length()),
      ),
      (
        crypt_decrypt_name_for_test("/Type"),
        PdfNameObject(crypt_decrypt_name_for_test("/Metadata")),
      ),
      (key_title, PdfString(encrypted_metadata)),
    ],
    encrypted_metadata,
  )
  let plain_metadata_stream = crypt_decrypt_stream_for_test(
    [
      (crypt_decrypt_name_for_test("/Length"), PdfInteger(4)),
      (
        crypt_decrypt_name_for_test("/Type"),
        PdfNameObject(crypt_decrypt_name_for_test("/Metadata")),
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
      (crypt_decrypt_name_for_test("/Encrypt"), PdfIndirect(2)),
      (
        crypt_decrypt_name_for_test("/ID"),
        PdfArray([
          PdfString(@ascii.encode("doc-id")),
          PdfString(@ascii.encode("ignored")),
        ]),
      ),
    ]),
  )

  let decrypted = crypt_decrypt_unwrap_decryption_result_for_test(
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
    .lookup_immediate(crypt_decrypt_name_for_test("/Encrypt")),
    None,
  )
  @test.assert_eq(
    decrypted.denied_permissions,
    @crypt_core.pdf_permissions_of_p(-3904),
  )
  let owner_decrypted = crypt_decrypt_unwrap_decryption_result_for_test(
    try! doc.decrypt_with_owner_password(@ascii.encode("owner")),
  )
  @test.assert_eq(
    owner_decrypted.document.lookup_object_or_null(1),
    plain_object,
  )
  let metadata_skipped = crypt_decrypt_unwrap_decryption_result_for_test(
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
