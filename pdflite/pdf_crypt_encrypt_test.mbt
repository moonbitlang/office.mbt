///|
fn crypt_encrypt_model_bytes_for_test(
  values : ArrayView[Int],
) -> @pdflite.PdfBytes {
  try! @pdflite.pdf_bytes_of_int_array(values)
}

///|
fn crypt_encrypt_aes_document_iv_for_test(
  object_number : Int,
  generation : Int,
  index : Int,
) -> @pdflite.PdfBytes {
  crypt_encrypt_model_bytes_for_test(
    [
      for offset in 0..<16 => {
        (object_number * 17 + generation * 5 + index * 31 + offset) % 256
      }
    ],
  )
}

///|
fn crypt_encrypt_aesv3_r5_file_key_for_test() -> @pdflite.PdfBytes {
  crypt_encrypt_model_bytes_for_test([ for value in 0..<32 => value ])
}

///|
fn crypt_encrypt_aesv3_r5_user_encryption_key_for_test() -> @pdflite.PdfBytes {
  crypt_encrypt_model_bytes_for_test([
    0xe4, 0x35, 0xfd, 0x1c, 0x68, 0x70, 0xfc, 0x3b, 0x50, 0x7f, 0x7c, 0x3d, 0x30,
    0xd0, 0x2e, 0x06, 0xb7, 0x60, 0x68, 0x50, 0x81, 0x95, 0xc1, 0x29, 0x87, 0x9c,
    0x23, 0xce, 0x43, 0xee, 0xda, 0x22,
  ])
}

///|
fn crypt_encrypt_aesv3_r5_owner_encryption_key_for_test() -> @pdflite.PdfBytes {
  crypt_encrypt_model_bytes_for_test([
    0x93, 0x8a, 0x69, 0x29, 0xac, 0xa0, 0x6a, 0x79, 0x47, 0xde, 0x9d, 0xc4, 0x68,
    0x29, 0x04, 0xca, 0xda, 0x26, 0xbf, 0x1b, 0xb2, 0x8e, 0xc9, 0xc8, 0x2b, 0x83,
    0x9d, 0x5b, 0x89, 0x4e, 0x6c, 0xec,
  ])
}

///|
fn crypt_encrypt_aesv3_r5_permissions_for_test() -> @pdflite.PdfBytes {
  crypt_encrypt_model_bytes_for_test([
    0xc1, 0x3b, 0x0f, 0x6a, 0xb2, 0xc5, 0x1a, 0x9e, 0x81, 0x15, 0xa5, 0xc3, 0xa3,
    0x96, 0xd7, 0x26,
  ])
}

///|
#warnings("-unused_error_type")
fn crypt_encrypt_aesv3_r5_random_for_test(
  field : @crypt_core.PdfAesV3RandomField,
  _length : Int,
) -> @pdflite.PdfBytes raise @pdflite.PdfError {
  match field {
    PdfAesV3FileKey => crypt_encrypt_aesv3_r5_file_key_for_test()
    PdfAesV3UserValidationSalt =>
      crypt_encrypt_model_bytes_for_test([
        0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08,
      ])
    PdfAesV3UserKeySalt =>
      crypt_encrypt_model_bytes_for_test([
        0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f, 0x10,
      ])
    PdfAesV3OwnerValidationSalt =>
      crypt_encrypt_model_bytes_for_test([
        0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18,
      ])
    PdfAesV3OwnerKeySalt =>
      crypt_encrypt_model_bytes_for_test([
        0x19, 0x1a, 0x1b, 0x1c, 0x1d, 0x1e, 0x1f, 0x20,
      ])
    PdfAesV3PermissionsPadding => Bytes::new(4)
  }
}

///|
fn crypt_encrypt_name_for_test(text : String) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn crypt_encrypt_minimal_catalog_document_for_test(
  major : Int,
  minor : Int,
) -> @pdflite.PdfDocument {
  let key_type = crypt_encrypt_name_for_test("/Type")
  let key_catalog = crypt_encrypt_name_for_test("/Catalog")
  let key_pages = crypt_encrypt_name_for_test("/Pages")
  let key_kids = crypt_encrypt_name_for_test("/Kids")
  let key_count = crypt_encrypt_name_for_test("/Count")
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
fn crypt_encrypt_stream_for_test(
  entries : ArrayView[(@pdflite.PdfName, @syntax.PdfObject)],
  data : @pdflite.PdfBytes,
) -> @syntax.PdfObject {
  PdfStreamObject({
    dictionary: PdfDictionary([ for entry in entries => entry ]),
    data: StreamGot(data),
  })
}

///|
fn crypt_encrypt_stream_object_bytes_for_test(
  stream : @syntax.PdfStream,
) -> @pdflite.PdfBytes raise {
  @syntax.pdf_stream(stream.dictionary, stream.data).stream_bytes()
}

///|
fn crypt_encrypt_assert_equivalent_object_for_test(
  actual : @syntax.PdfObject,
  expected : @syntax.PdfObject,
) -> Unit raise {
  match (actual, expected) {
    (PdfStreamObject(actual), PdfStreamObject(expected)) => {
      @test.assert_eq(actual.dictionary, expected.dictionary)
      @test.assert_eq(
        crypt_encrypt_stream_object_bytes_for_test(actual),
        crypt_encrypt_stream_object_bytes_for_test(expected),
      )
    }
    _ => @test.assert_eq(actual, expected)
  }
}

///|
fn crypt_encrypt_unwrap_decryption_result_for_test(
  result : @pdflite.PdfDecryptionResult?,
) -> @pdflite.PdfDecryptionResult raise {
  match result {
    Some(value) => value
    None => fail("expected decrypted document")
  }
}

///|
test "PdfDocument encrypt_128bit encrypts parsed objects and writes length" {
  let key_title = crypt_encrypt_name_for_test("/Title")
  let key_encrypt = crypt_encrypt_name_for_test("/Encrypt")
  let key_v = crypt_encrypt_name_for_test("/V")
  let key_r = crypt_encrypt_name_for_test("/R")
  let key_length = crypt_encrypt_name_for_test("/Length")
  let key_p = crypt_encrypt_name_for_test("/P")
  let doc = @pdflite.pdf_document_empty()
  let plain_object : @syntax.PdfObject = PdfDictionary([
    (key_title, PdfString(@ascii.encode("hello"))),
  ])
  doc.add_object_given_number(1, plain_object)
  let encrypted = try! doc.encrypt_128bit(
    @ascii.encode("user"),
    @ascii.encode("owner"),
    [PdfNoPrint, PdfNoCopy],
    file_id=@ascii.encode("doc-id"),
  )
  let permissions = @crypt_core.pdf_p_of_permissions([PdfNoPrint, PdfNoCopy])
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
  @test.assert_eq(try! encrypted.what_encryption(), Some(PdfEncryption128Bit))
  let decrypted = crypt_encrypt_unwrap_decryption_result_for_test(
    try! encrypted.decrypt_with_user_password(@ascii.encode("user")),
  )
  @test.assert_eq(decrypted.document.lookup_object_or_null(1), plain_object)
  @test.assert_eq(decrypted.denied_permissions, [PdfNoCopy, PdfNoPrint])
  let owner_decrypted = crypt_encrypt_unwrap_decryption_result_for_test(
    try! encrypted.decrypt_with_owner_password(@ascii.encode("owner")),
  )
  @test.assert_eq(
    owner_decrypted.document.lookup_object_or_null(1),
    plain_object,
  )
}

///|
test "PdfDocument encrypt_128bit_r4 writes crypt filter and honors metadata flag" {
  let key_title = crypt_encrypt_name_for_test("/Title")
  let key_encrypt = crypt_encrypt_name_for_test("/Encrypt")
  let key_filter = crypt_encrypt_name_for_test("/Filter")
  let key_standard = crypt_encrypt_name_for_test("/Standard")
  let key_v = crypt_encrypt_name_for_test("/V")
  let key_r = crypt_encrypt_name_for_test("/R")
  let key_length = crypt_encrypt_name_for_test("/Length")
  let key_p = crypt_encrypt_name_for_test("/P")
  let key_cf = crypt_encrypt_name_for_test("/CF")
  let key_stdcf = crypt_encrypt_name_for_test("/StdCF")
  let key_auth_event = crypt_encrypt_name_for_test("/AuthEvent")
  let key_doc_open = crypt_encrypt_name_for_test("/DocOpen")
  let key_cfm = crypt_encrypt_name_for_test("/CFM")
  let key_v2 = crypt_encrypt_name_for_test("/V2")
  let key_encrypt_metadata = crypt_encrypt_name_for_test("/EncryptMetadata")
  let key_strf = crypt_encrypt_name_for_test("/StrF")
  let key_stmf = crypt_encrypt_name_for_test("/StmF")
  let key_type = crypt_encrypt_name_for_test("/Type")
  let key_metadata = crypt_encrypt_name_for_test("/Metadata")
  let doc = @pdflite.pdf_document_empty()
  let plain_object : @syntax.PdfObject = PdfDictionary([
    (key_title, PdfString(@ascii.encode("hello"))),
  ])
  let metadata_stream = crypt_encrypt_stream_for_test(
    [
      (crypt_encrypt_name_for_test("/Length"), PdfInteger(4)),
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
  let permissions = @crypt_core.pdf_p_of_permissions([PdfNoExtract])
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
  @test.assert_eq(try! encrypted.what_encryption(), Some(PdfEncryption128Bit))
  let decrypted = crypt_encrypt_unwrap_decryption_result_for_test(
    try! encrypted.decrypt_with_user_password(@ascii.encode("user")),
  )
  @test.assert_eq(decrypted.document.lookup_object_or_null(1), plain_object)
  @test.assert_eq(decrypted.document.lookup_object_or_null(3), metadata_stream)
  @test.assert_eq(
    decrypted.denied_permissions,
    @crypt_core.pdf_permissions_of_p(permissions),
  )
  let owner_decrypted = crypt_encrypt_unwrap_decryption_result_for_test(
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
  let key_catalog = crypt_encrypt_name_for_test("/Catalog")
  let key_pages = crypt_encrypt_name_for_test("/Pages")
  let key_kids = crypt_encrypt_name_for_test("/Kids")
  let key_count = crypt_encrypt_name_for_test("/Count")
  let key_title = crypt_encrypt_name_for_test("/Title")
  let key_encrypt = crypt_encrypt_name_for_test("/Encrypt")
  let key_filter = crypt_encrypt_name_for_test("/Filter")
  let key_standard = crypt_encrypt_name_for_test("/Standard")
  let key_cf = crypt_encrypt_name_for_test("/CF")
  let key_stdcf = crypt_encrypt_name_for_test("/StdCF")
  let key_cfm = crypt_encrypt_name_for_test("/CFM")
  let key_aesv2 = crypt_encrypt_name_for_test("/AESV2")
  let key_encrypt_metadata = crypt_encrypt_name_for_test("/EncryptMetadata")
  let key_type = crypt_encrypt_name_for_test("/Type")
  let key_metadata = crypt_encrypt_name_for_test("/Metadata")
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
    (key_title, PdfString(@ascii.encode("secret"))),
  ])
  let metadata_stream = crypt_encrypt_stream_for_test(
    [
      (crypt_encrypt_name_for_test("/Length"), PdfInteger(4)),
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
      crypt_encrypt_aes_document_iv_for_test(object_number, generation, index)
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
  @test.assert_eq(
    try! encrypted.what_encryption(),
    Some(PdfEncryptionAES128(false)),
  )
  let decrypted = crypt_encrypt_unwrap_decryption_result_for_test(
    try! encrypted.decrypt_with_user_password(@ascii.encode("user")),
  )
  @test.assert_eq(decrypted.document.lookup_object_or_null(5), secret_object)
  @test.assert_eq(decrypted.document.lookup_object_or_null(6), metadata_stream)
  @test.assert_eq(decrypted.denied_permissions, [PdfNoPrint])

  let rendered = try! @pdflite.pdf_write_document(encrypted)
  let parsed = try! @pdflite.pdf_read_document_from_bytes(rendered)
  let read_decrypted = crypt_encrypt_unwrap_decryption_result_for_test(
    try! parsed.decrypt_with_owner_password(@ascii.encode("owner")),
  )
  @test.assert_eq(
    read_decrypted.document.lookup_object_or_null(5),
    secret_object,
  )
  try! crypt_encrypt_assert_equivalent_object_for_test(
    read_decrypted.document.lookup_object_or_null(6),
    metadata_stream,
  )
}

///|
test "pdfencrypt-style AES128 blank-user owner-password output roundtrips" {
  let key_title = crypt_encrypt_name_for_test("/Title")
  let doc = crypt_encrypt_minimal_catalog_document_for_test(1, 4)
  let secret_object : @syntax.PdfObject = PdfDictionary([
    (key_title, PdfString(@ascii.encode("pdfencrypt-secret"))),
  ])
  doc.add_object_given_number(5, secret_object)
  let denied : Array[@crypt_core.PdfPermission] = [PdfNoEdit, PdfNoPrint]
  let encrypted = try! doc.encrypt_128bit_aesv2_with_iv_provider(
    @ascii.encode(""),
    @ascii.encode("owner-password"),
    denied,
    fn(object_number, generation, index) {
      crypt_encrypt_aes_document_iv_for_test(object_number, generation, index)
    },
    encrypt_metadata=false,
    file_id=@ascii.encode("pdfencrypt-doc-id"),
  )
  @test.assert_eq(try! encrypted.permissions(), denied)
  @test.assert_eq(encrypted.is_encrypted(), true)
  let rendered = try! @pdflite.pdf_write_document(encrypted)
  let parsed = try! @pdflite.pdf_read_document_from_bytes(rendered)
  @test.assert_eq(try! parsed.permissions(), denied)
  let user_decrypted = crypt_encrypt_unwrap_decryption_result_for_test(
    try! parsed.decrypt_with_user_password(@ascii.encode("")),
  )
  @test.assert_eq(user_decrypted.denied_permissions, denied)
  @test.assert_eq(
    user_decrypted.document.lookup_object_or_null(5),
    secret_object,
  )
  let owner_decrypted = crypt_encrypt_unwrap_decryption_result_for_test(
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
  let key_type = crypt_encrypt_name_for_test("/Type")
  let key_title = crypt_encrypt_name_for_test("/Title")
  let key_metadata = crypt_encrypt_name_for_test("/Metadata")
  let key_encrypt = crypt_encrypt_name_for_test("/Encrypt")
  let key_cf = crypt_encrypt_name_for_test("/CF")
  let key_stdcf = crypt_encrypt_name_for_test("/StdCF")
  let key_cfm = crypt_encrypt_name_for_test("/CFM")
  let key_aesv3 = crypt_encrypt_name_for_test("/AESV3")
  let key_encrypt_metadata = crypt_encrypt_name_for_test("/EncryptMetadata")
  let key_oe = crypt_encrypt_name_for_test("/OE")
  let key_ue = crypt_encrypt_name_for_test("/UE")
  let key_perms = crypt_encrypt_name_for_test("/Perms")
  let doc = crypt_encrypt_minimal_catalog_document_for_test(1, 7)
  let secret_object : @syntax.PdfObject = PdfDictionary([
    (key_title, PdfString(@ascii.encode("aes3-secret"))),
  ])
  let metadata_stream = crypt_encrypt_stream_for_test(
    [
      (crypt_encrypt_name_for_test("/Length"), PdfInteger(4)),
      (key_type, PdfNameObject(key_metadata)),
      (key_title, PdfString(@ascii.encode("meta"))),
    ],
    @ascii.encode("data"),
  )
  doc.add_object_given_number(5, secret_object)
  doc.add_object_given_number(6, metadata_stream)
  let denied_permissions = @crypt_core.pdf_permissions_of_p(-3904)
  let encrypted = try! doc.encrypt_256bit_aesv3_with_providers(
    @ascii.encode("user"),
    @ascii.encode("owner"),
    denied_permissions,
    crypt_encrypt_aesv3_r5_random_for_test,
    fn(object_number, generation, index) {
      crypt_encrypt_aes_document_iv_for_test(object_number, generation, index)
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
    Some(PdfString(crypt_encrypt_aesv3_r5_user_encryption_key_for_test())),
  )
  @test.assert_eq(
    encrypt_dictionary.lookup_immediate(key_oe),
    Some(PdfString(crypt_encrypt_aesv3_r5_owner_encryption_key_for_test())),
  )
  @test.assert_eq(
    encrypt_dictionary.lookup_immediate(key_perms),
    Some(PdfString(crypt_encrypt_aesv3_r5_permissions_for_test())),
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
  let decrypted = crypt_encrypt_unwrap_decryption_result_for_test(
    try! encrypted.decrypt_with_user_password(@ascii.encode("user")),
  )
  @test.assert_eq(decrypted.document.lookup_object_or_null(5), secret_object)
  @test.assert_eq(decrypted.document.lookup_object_or_null(6), metadata_stream)
  @test.assert_eq(decrypted.denied_permissions, denied_permissions)
  let owner_decrypted = crypt_encrypt_unwrap_decryption_result_for_test(
    try! encrypted.decrypt_with_owner_password(@ascii.encode("owner")),
  )
  @test.assert_eq(
    owner_decrypted.document.lookup_object_or_null(5),
    secret_object,
  )

  let rendered = try! @pdflite.pdf_write_document(encrypted)
  let parsed = try! @pdflite.pdf_read_document_from_bytes(rendered)
  let read_decrypted = crypt_encrypt_unwrap_decryption_result_for_test(
    try! parsed.decrypt_with_owner_password(@ascii.encode("owner")),
  )
  @test.assert_eq(
    read_decrypted.document.lookup_object_or_null(5),
    secret_object,
  )
  try! crypt_encrypt_assert_equivalent_object_for_test(
    read_decrypted.document.lookup_object_or_null(6),
    metadata_stream,
  )

  let bad_random = fn(
    field : @crypt_core.PdfAesV3RandomField,
    length : Int,
  ) -> @pdflite.PdfBytes raise @pdflite.PdfError {
    match field {
      PdfAesV3UserKeySalt => Bytes::new(7)
      _ => crypt_encrypt_aesv3_r5_random_for_test(field, length)
    }
  }
  let bad_provider : Result[@pdflite.PdfDocument, Error] = try? doc.encrypt_256bit_aesv3_with_providers(
    @ascii.encode("user"),
    @ascii.encode("owner"),
    denied_permissions,
    bad_random,
    fn(object_number, generation, index) {
      crypt_encrypt_aes_document_iv_for_test(object_number, generation, index)
    },
    file_id=@ascii.encode("doc-id"),
  )
  guard bad_provider
    is Err(@pdflite.PdfError::EncryptionDictionaryEntryTooShort(name)) &&
    name == crypt_encrypt_name_for_test("/UserKeySalt") else {
    fail("expected short AESV3 random field")
  }
}

///|
test "PdfDocument encrypted AESV3 output round trips through xref stream writers" {
  let key_type = crypt_encrypt_name_for_test("/Type")
  let key_title = crypt_encrypt_name_for_test("/Title")
  let key_metadata = crypt_encrypt_name_for_test("/Metadata")
  let key_encrypt = crypt_encrypt_name_for_test("/Encrypt")
  let doc = crypt_encrypt_minimal_catalog_document_for_test(1, 7)
  let secret_object : @syntax.PdfObject = PdfDictionary([
    (key_title, PdfString(@ascii.encode("secret-aes3-xref"))),
  ])
  let metadata_stream = crypt_encrypt_stream_for_test(
    [
      (crypt_encrypt_name_for_test("/Length"), PdfInteger(4)),
      (key_type, PdfNameObject(key_metadata)),
      (key_title, PdfString(@ascii.encode("meta"))),
    ],
    @ascii.encode("data"),
  )
  doc.add_object_given_number(5, secret_object)
  doc.add_object_given_number(6, metadata_stream)
  let denied_permissions = @crypt_core.pdf_permissions_of_p(-3904)
  let encrypted = try! doc.encrypt_256bit_aesv3_with_providers(
    @ascii.encode("user"),
    @ascii.encode("owner"),
    denied_permissions,
    crypt_encrypt_aesv3_r5_random_for_test,
    fn(object_number, generation, index) {
      crypt_encrypt_aes_document_iv_for_test(object_number, generation, index)
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
  let decrypted = crypt_encrypt_unwrap_decryption_result_for_test(
    try! parsed.decrypt_with_user_password(@ascii.encode("user")),
  )
  @test.assert_eq(decrypted.document.lookup_object_or_null(5), secret_object)
  try! crypt_encrypt_assert_equivalent_object_for_test(
    decrypted.document.lookup_object_or_null(6),
    metadata_stream,
  )
  @test.assert_eq(decrypted.denied_permissions, denied_permissions)

  let compressed = try! @pdflite.pdf_write_document_with_compressed_xref_stream(
    encrypted,
  )
  let compressed_decrypted = crypt_encrypt_unwrap_decryption_result_for_test(
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
  try! crypt_encrypt_assert_equivalent_object_for_test(
    compressed_decrypted.document.lookup_object_or_null(6),
    metadata_stream,
  )
  @test.assert_eq(compressed_decrypted.denied_permissions, denied_permissions)
}

///|
test "PdfDocument encrypted AESV2 output round trips through xref stream writers" {
  let key_type = crypt_encrypt_name_for_test("/Type")
  let key_title = crypt_encrypt_name_for_test("/Title")
  let key_metadata = crypt_encrypt_name_for_test("/Metadata")
  let key_encrypt = crypt_encrypt_name_for_test("/Encrypt")
  let doc = crypt_encrypt_minimal_catalog_document_for_test(1, 5)
  let secret_object : @syntax.PdfObject = PdfDictionary([
    (key_title, PdfString(@ascii.encode("secret-aes-xref"))),
  ])
  let metadata_stream = crypt_encrypt_stream_for_test(
    [
      (crypt_encrypt_name_for_test("/Length"), PdfInteger(4)),
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
      crypt_encrypt_aes_document_iv_for_test(object_number, generation, index)
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
  let decrypted = crypt_encrypt_unwrap_decryption_result_for_test(
    try! parsed.decrypt_with_user_password(@ascii.encode("user")),
  )
  @test.assert_eq(decrypted.document.lookup_object_or_null(5), secret_object)
  try! crypt_encrypt_assert_equivalent_object_for_test(
    decrypted.document.lookup_object_or_null(6),
    metadata_stream,
  )
  @test.assert_eq(decrypted.denied_permissions, [PdfNoCopy])

  let compressed = try! @pdflite.pdf_write_document_with_compressed_xref_stream(
    encrypted,
  )
  let compressed_decrypted = crypt_encrypt_unwrap_decryption_result_for_test(
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
  try! crypt_encrypt_assert_equivalent_object_for_test(
    compressed_decrypted.document.lookup_object_or_null(6),
    metadata_stream,
  )
  @test.assert_eq(compressed_decrypted.denied_permissions, [PdfNoCopy])
}

///|
test "PdfDocument encrypted ARC4 output round trips through writer and reader" {
  let key_type = crypt_encrypt_name_for_test("/Type")
  let key_catalog = crypt_encrypt_name_for_test("/Catalog")
  let key_pages = crypt_encrypt_name_for_test("/Pages")
  let key_kids = crypt_encrypt_name_for_test("/Kids")
  let key_count = crypt_encrypt_name_for_test("/Count")
  let key_title = crypt_encrypt_name_for_test("/Title")
  let key_metadata = crypt_encrypt_name_for_test("/Metadata")
  let key_encrypt = crypt_encrypt_name_for_test("/Encrypt")
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
    (key_title, PdfString(@ascii.encode("secret"))),
  ])
  let metadata_stream = crypt_encrypt_stream_for_test(
    [
      (crypt_encrypt_name_for_test("/Length"), PdfInteger(4)),
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
  let decrypted = crypt_encrypt_unwrap_decryption_result_for_test(
    try! parsed.decrypt_with_user_password(@ascii.encode("user")),
  )
  @test.assert_eq(decrypted.document.is_encrypted(), false)
  @test.assert_eq(decrypted.document.lookup_object_or_null(5), secret_object)
  try! crypt_encrypt_assert_equivalent_object_for_test(
    decrypted.document.lookup_object_or_null(6),
    metadata_stream,
  )
  @test.assert_eq(decrypted.denied_permissions, [PdfNoPrint])
  let read_owner_decrypted = crypt_encrypt_unwrap_decryption_result_for_test(
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
  try! crypt_encrypt_assert_equivalent_object_for_test(
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
  let key_type = crypt_encrypt_name_for_test("/Type")
  let key_catalog = crypt_encrypt_name_for_test("/Catalog")
  let key_pages = crypt_encrypt_name_for_test("/Pages")
  let key_kids = crypt_encrypt_name_for_test("/Kids")
  let key_count = crypt_encrypt_name_for_test("/Count")
  let key_title = crypt_encrypt_name_for_test("/Title")
  let key_metadata = crypt_encrypt_name_for_test("/Metadata")
  let key_encrypt = crypt_encrypt_name_for_test("/Encrypt")
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
  let secret_object : @syntax.PdfObject = PdfDictionary([
    (key_title, PdfString(@ascii.encode("secret-xref"))),
  ])
  let metadata_stream = crypt_encrypt_stream_for_test(
    [
      (crypt_encrypt_name_for_test("/Length"), PdfInteger(4)),
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
  let decrypted = crypt_encrypt_unwrap_decryption_result_for_test(
    try! parsed.decrypt_with_user_password(@ascii.encode("user")),
  )
  @test.assert_eq(decrypted.document.lookup_object_or_null(5), secret_object)
  try! crypt_encrypt_assert_equivalent_object_for_test(
    decrypted.document.lookup_object_or_null(6),
    metadata_stream,
  )
  @test.assert_eq(decrypted.denied_permissions, [PdfNoPrint])

  let compressed = try! @pdflite.pdf_write_document_with_compressed_xref_stream(
    encrypted,
  )
  let compressed_decrypted = crypt_encrypt_unwrap_decryption_result_for_test(
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
  try! crypt_encrypt_assert_equivalent_object_for_test(
    compressed_decrypted.document.lookup_object_or_null(6),
    metadata_stream,
  )
  @test.assert_eq(compressed_decrypted.denied_permissions, [PdfNoPrint])
}
