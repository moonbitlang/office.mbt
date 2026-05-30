///|
fn crypt_parsed_bytes_for_test(values : ArrayView[Int]) -> PdfBytes {
  try! pdf_bytes_of_int_array(values)
}

///|
fn crypt_parsed_name_for_test(text : String) -> PdfName {
  pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn crypt_parsed_stream_for_test(
  entries : ArrayView[(PdfName, @syntax.PdfObject)],
  data : PdfBytes,
) -> @syntax.PdfObject {
  PdfStreamObject({
    dictionary: PdfDictionary([ for entry in entries => entry ]),
    data: StreamGot(data),
  })
}

///|
fn crypt_parsed_arc4_crypt_object_for_test(
  object_number : Int,
  generation : Int,
  file_key : BytesView,
  key_length_bits : Int,
  object : @syntax.PdfObject,
  no_encrypt_metadata? : Bool = false,
) -> @syntax.PdfObject raise {
  let doc = pdf_document_empty()
  doc.add_object_given_number(object_number, object, generation~)
  let crypted = doc.arc4_crypt_parsed_objects(
    file_key, key_length_bits, no_encrypt_metadata, 0,
  )
  crypted.lookup_object_or_null(object_number)
}

///|
fn crypt_parsed_aes_iv_for_test(index : Int) -> PdfBytes {
  crypt_parsed_bytes_for_test(
    [
      for offset in 0..<16 => 0x40 + index * 16 + offset
    ],
  )
}

///|
fn crypt_parsed_aesv2_encrypt_data_for_test(
  object_number : Int,
  generation : Int,
  file_key : BytesView,
  key_length_bits : Int,
  data : BytesView,
  iv : BytesView,
) -> PdfBytes raise {
  @crypt_core.pdf_aesv2_encrypt_object_data(
    object_number, generation, file_key, key_length_bits, data, iv,
  )
}

///|
fn crypt_parsed_aesv3_r5_file_key_for_test() -> PdfBytes {
  crypt_parsed_bytes_for_test([ for value in 0..<32 => value ])
}

///|
fn crypt_parsed_aesv3_encrypt_data_for_test(
  file_key : BytesView,
  data : BytesView,
  iv : BytesView,
) -> PdfBytes raise {
  @crypt_core.pdf_aesv3_encrypt_object_data(file_key, data, iv)
}

///|
test "PdfDocument ARC4 parsed-object crypt recurses through dictionaries" {
  let key = crypt_parsed_bytes_for_test([1, 2, 3, 4, 5])
  let encrypted_hello = crypt_parsed_bytes_for_test([
    0x7d, 0x1c, 0x38, 0x4c, 0xca,
  ])
  let key_s = pdf_name_of_bytes(@ascii.encode("/S"))
  let key_a = pdf_name_of_bytes(@ascii.encode("/A"))
  let key_n = pdf_name_of_bytes(@ascii.encode("/N"))
  let object : @syntax.PdfObject = PdfDictionary([
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
  let encrypted = try! crypt_parsed_arc4_crypt_object_for_test(
    12, 0, key, 40, object,
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
    try! crypt_parsed_arc4_crypt_object_for_test(12, 0, key, 40, encrypted),
    object,
  )
}

///|
test "PdfDocument ARC4 parsed-object crypt encrypts stream dictionaries and data" {
  let key = crypt_parsed_bytes_for_test([1, 2, 3, 4, 5])
  let encrypted_hello = crypt_parsed_bytes_for_test([
    0x7d, 0x1c, 0x38, 0x4c, 0xca,
  ])
  let key_length = pdf_name_of_bytes(@ascii.encode("/Length"))
  let key_title = pdf_name_of_bytes(@ascii.encode("/Title"))
  let object : @syntax.PdfObject = PdfStreamObject({
    dictionary: PdfDictionary([
      (key_length, PdfInteger(5)),
      (key_title, PdfString(@ascii.encode("hello"))),
    ]),
    data: StreamGot(@ascii.encode("hello")),
  })
  let encrypted = try! crypt_parsed_arc4_crypt_object_for_test(
    12, 0, key, 40, object,
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
    try! crypt_parsed_arc4_crypt_object_for_test(12, 0, key, 40, encrypted),
    object,
  )
}

///|
test "PdfDocument ARC4 parsed-object crypt skips metadata and identity Crypt streams" {
  let key = crypt_parsed_bytes_for_test([1, 2, 3, 4, 5])
  let hello = @ascii.encode("hello")
  let encrypted_hello = crypt_parsed_bytes_for_test([
    0x7d, 0x1c, 0x38, 0x4c, 0xca,
  ])
  let key_length = crypt_parsed_name_for_test("/Length")
  let key_title = crypt_parsed_name_for_test("/Title")
  let key_type = crypt_parsed_name_for_test("/Type")
  let key_filter = crypt_parsed_name_for_test("/Filter")
  let key_decodeparms = crypt_parsed_name_for_test("/DecodeParms")
  let key_name = crypt_parsed_name_for_test("/Name")
  let name_metadata = crypt_parsed_name_for_test("/Metadata")
  let name_crypt = crypt_parsed_name_for_test("/Crypt")
  let name_identity = crypt_parsed_name_for_test("/Identity")
  let name_stdcf = crypt_parsed_name_for_test("/StdCF")
  let metadata_stream = crypt_parsed_stream_for_test(
    [
      (key_length, PdfInteger(5)),
      (key_type, PdfNameObject(name_metadata)),
      (key_title, PdfString(hello)),
    ],
    hello,
  )
  @test.assert_eq(
    try! crypt_parsed_arc4_crypt_object_for_test(
      12,
      0,
      key,
      40,
      metadata_stream,
      no_encrypt_metadata=true,
    ),
    metadata_stream,
  )
  @test.assert_eq(
    try! crypt_parsed_arc4_crypt_object_for_test(
      12, 0, key, 40, metadata_stream,
    ),
    crypt_parsed_stream_for_test(
      [
        (key_length, PdfInteger(5)),
        (key_type, PdfNameObject(name_metadata)),
        (key_title, PdfString(encrypted_hello)),
      ],
      encrypted_hello,
    ),
  )
  let ordinary_stream = crypt_parsed_stream_for_test(
    [(key_length, PdfInteger(5)), (key_title, PdfString(hello))],
    hello,
  )
  @test.assert_eq(
    try! crypt_parsed_arc4_crypt_object_for_test(
      12,
      0,
      key,
      40,
      ordinary_stream,
      no_encrypt_metadata=true,
    ),
    crypt_parsed_stream_for_test(
      [(key_length, PdfInteger(5)), (key_title, PdfString(encrypted_hello))],
      encrypted_hello,
    ),
  )

  let crypt_stream = crypt_parsed_stream_for_test(
    [
      (key_length, PdfInteger(5)),
      (key_filter, PdfNameObject(name_crypt)),
      (key_title, PdfString(hello)),
    ],
    hello,
  )
  @test.assert_eq(
    try! crypt_parsed_arc4_crypt_object_for_test(12, 0, key, 40, crypt_stream),
    crypt_stream,
  )

  let identity_dict_stream = crypt_parsed_stream_for_test(
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
    try! crypt_parsed_arc4_crypt_object_for_test(
      12, 0, key, 40, identity_dict_stream,
    ),
    identity_dict_stream,
  )

  let identity_array_stream = crypt_parsed_stream_for_test(
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
    try! crypt_parsed_arc4_crypt_object_for_test(
      12, 0, key, 40, identity_array_stream,
    ),
    identity_array_stream,
  )

  let unnamed_crypt_stream = crypt_parsed_stream_for_test(
    [
      (key_length, PdfInteger(5)),
      (key_filter, PdfNameObject(name_crypt)),
      (key_decodeparms, PdfDictionary([])),
      (key_title, PdfString(hello)),
    ],
    hello,
  )
  @test.assert_eq(
    try! crypt_parsed_arc4_crypt_object_for_test(
      12, 0, key, 40, unnamed_crypt_stream,
    ),
    unnamed_crypt_stream,
  )

  let named_crypt_stream = crypt_parsed_stream_for_test(
    [
      (key_length, PdfInteger(5)),
      (key_filter, PdfNameObject(name_crypt)),
      (key_decodeparms, PdfDictionary([(key_name, PdfNameObject(name_stdcf))])),
      (key_title, PdfString(hello)),
    ],
    hello,
  )
  @test.assert_eq(
    try! crypt_parsed_arc4_crypt_object_for_test(
      12, 0, key, 40, named_crypt_stream,
    ),
    crypt_parsed_stream_for_test(
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

  let malformed_crypt_stream = crypt_parsed_stream_for_test(
    [
      (key_length, PdfInteger(5)),
      (key_filter, PdfNameObject(name_crypt)),
      (key_decodeparms, PdfDictionary([(key_name, PdfInteger(1))])),
      (key_title, PdfString(hello)),
    ],
    hello,
  )
  @test.assert_eq(
    try! crypt_parsed_arc4_crypt_object_for_test(
      12, 0, key, 40, malformed_crypt_stream,
    ),
    crypt_parsed_stream_for_test(
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
test "PdfDocument AESV2 parsed-object encryption recurses through object data" {
  let file_key = crypt_parsed_bytes_for_test([ for value in 0..<16 => value ])
  let key_s = crypt_parsed_name_for_test("/S")
  let key_a = crypt_parsed_name_for_test("/A")
  let key_n = crypt_parsed_name_for_test("/N")
  let key_stream = crypt_parsed_name_for_test("/Stream")
  let key_length = crypt_parsed_name_for_test("/Length")
  let key_title = crypt_parsed_name_for_test("/Title")
  let object : @syntax.PdfObject = PdfDictionary([
    (key_s, PdfString(@ascii.encode("hello"))),
    (
      key_a,
      PdfArray([
        PdfString(@ascii.encode("bye")),
        PdfNameObject(key_n),
        PdfIndirect(9),
      ]),
    ),
    (
      key_stream,
      crypt_parsed_stream_for_test(
        [
          (key_length, PdfInteger(4)),
          (key_title, PdfString(@ascii.encode("meta"))),
        ],
        @ascii.encode("data"),
      ),
    ),
  ])
  let encrypted_s = try! crypt_parsed_aesv2_encrypt_data_for_test(
    12,
    0,
    file_key,
    128,
    @ascii.encode("hello"),
    crypt_parsed_aes_iv_for_test(0),
  )
  let encrypted_a = try! crypt_parsed_aesv2_encrypt_data_for_test(
    12,
    0,
    file_key,
    128,
    @ascii.encode("bye"),
    crypt_parsed_aes_iv_for_test(1),
  )
  let encrypted_title = try! crypt_parsed_aesv2_encrypt_data_for_test(
    12,
    0,
    file_key,
    128,
    @ascii.encode("meta"),
    crypt_parsed_aes_iv_for_test(2),
  )
  let encrypted_data = try! crypt_parsed_aesv2_encrypt_data_for_test(
    12,
    0,
    file_key,
    128,
    @ascii.encode("data"),
    crypt_parsed_aes_iv_for_test(3),
  )
  let doc = pdf_document_empty()
  doc.add_object_given_number(12, object)
  let encrypted_doc = try! doc.aesv2_encrypt_parsed_objects_with_iv_provider(
    file_key,
    128,
    fn(_, _, index) { crypt_parsed_aes_iv_for_test(index) },
    false,
  )
  let encrypted = encrypted_doc.lookup_object_or_null(12)
  @test.assert_eq(
    encrypted,
    PdfDictionary([
      (key_s, PdfString(encrypted_s)),
      (
        key_a,
        PdfArray([PdfString(encrypted_a), PdfNameObject(key_n), PdfIndirect(9)]),
      ),
      (
        key_stream,
        crypt_parsed_stream_for_test(
          [
            (key_length, PdfInteger(encrypted_data.length())),
            (key_title, PdfString(encrypted_title)),
          ],
          encrypted_data,
        ),
      ),
    ]),
  )
  let decrypted_doc = try! encrypted_doc.aesv2_decrypt_parsed_objects(
    file_key, 128, false, 0,
  )
  @test.assert_eq(decrypted_doc.lookup_object_or_null(12), object)
}

///|
test "PdfDocument AESV2 parsed-object encryption skips metadata streams" {
  let file_key = crypt_parsed_bytes_for_test([ for value in 0..<16 => value ])
  let key_length = crypt_parsed_name_for_test("/Length")
  let key_type = crypt_parsed_name_for_test("/Type")
  let key_metadata = crypt_parsed_name_for_test("/Metadata")
  let key_title = crypt_parsed_name_for_test("/Title")
  let metadata_stream = crypt_parsed_stream_for_test(
    [
      (key_length, PdfInteger(4)),
      (key_type, PdfNameObject(key_metadata)),
      (key_title, PdfString(@ascii.encode("meta"))),
    ],
    @ascii.encode("data"),
  )
  let calls : Ref[Int] = { val: 0 }
  let doc = pdf_document_empty()
  doc.add_object_given_number(12, metadata_stream)
  let encrypted_doc = try! doc.aesv2_encrypt_parsed_objects_with_iv_provider(
    file_key,
    128,
    fn(_, _, index) {
      calls.val += 1
      crypt_parsed_aes_iv_for_test(index)
    },
    true,
  )
  @test.assert_eq(encrypted_doc.lookup_object_or_null(12), metadata_stream)
  @test.assert_eq(calls.val, 0)
}

///|
test "PdfDocument AESV2 parsed-object decrypt recurses through object data" {
  let file_key = crypt_parsed_bytes_for_test([ for value in 0..<16 => value ])
  let iv = crypt_parsed_bytes_for_test([
    0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19, 0x1a, 0x1b, 0x1c,
    0x1d, 0x1e, 0x1f,
  ])
  let key_s = pdf_name_of_bytes(@ascii.encode("/S"))
  let key_a = pdf_name_of_bytes(@ascii.encode("/A"))
  let key_n = pdf_name_of_bytes(@ascii.encode("/N"))
  let encrypted_hello = try! crypt_parsed_aesv2_encrypt_data_for_test(
    12,
    0,
    file_key,
    128,
    @ascii.encode("hello"),
    iv,
  )
  let object : @syntax.PdfObject = PdfDictionary([
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
  let encrypted : @syntax.PdfObject = PdfDictionary([
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
  let doc = pdf_document_empty()
  doc.add_object_given_number(12, encrypted)
  let decrypted = try! doc.aesv2_decrypt_parsed_objects(file_key, 128, false, 0)
  @test.assert_eq(decrypted.lookup_object_or_null(12), object)

  let key_length = pdf_name_of_bytes(@ascii.encode("/Length"))
  let key_title = pdf_name_of_bytes(@ascii.encode("/Title"))
  let encrypted_stream : @syntax.PdfObject = PdfStreamObject({
    dictionary: PdfDictionary([
      (key_length, PdfInteger(encrypted_hello.length())),
      (key_title, PdfString(encrypted_hello)),
    ]),
    data: StreamGot(encrypted_hello),
  })
  let plain_stream : @syntax.PdfObject = PdfStreamObject({
    dictionary: PdfDictionary([
      (key_length, PdfInteger(5)),
      (key_title, PdfString(@ascii.encode("hello"))),
    ]),
    data: StreamGot(@ascii.encode("hello")),
  })
  let stream_doc = pdf_document_empty()
  stream_doc.add_object_given_number(12, encrypted_stream)
  let decrypted_stream_doc = try! stream_doc.aesv2_decrypt_parsed_objects(
    file_key, 128, false, 0,
  )
  @test.assert_eq(decrypted_stream_doc.lookup_object_or_null(12), plain_stream)
  let key_type = crypt_parsed_name_for_test("/Type")
  let key_filter = crypt_parsed_name_for_test("/Filter")
  let metadata_stream = crypt_parsed_stream_for_test(
    [
      (key_length, PdfInteger(encrypted_hello.length())),
      (key_type, PdfNameObject(crypt_parsed_name_for_test("/Metadata"))),
      (key_title, PdfString(encrypted_hello)),
    ],
    encrypted_hello,
  )
  let metadata_doc = pdf_document_empty()
  metadata_doc.add_object_given_number(12, metadata_stream)
  let decrypted_metadata_doc = try! metadata_doc.aesv2_decrypt_parsed_objects(
    file_key, 128, true, 0,
  )
  @test.assert_eq(
    decrypted_metadata_doc.lookup_object_or_null(12),
    metadata_stream,
  )
  let crypt_stream = crypt_parsed_stream_for_test(
    [
      (key_length, PdfInteger(encrypted_hello.length())),
      (key_filter, PdfNameObject(crypt_parsed_name_for_test("/Crypt"))),
      (key_title, PdfString(encrypted_hello)),
    ],
    encrypted_hello,
  )
  let crypt_doc = pdf_document_empty()
  crypt_doc.add_object_given_number(12, crypt_stream)
  let decrypted_crypt_doc = try! crypt_doc.aesv2_decrypt_parsed_objects(
    file_key, 128, false, 0,
  )
  @test.assert_eq(decrypted_crypt_doc.lookup_object_or_null(12), crypt_stream)
}

///|
test "PdfDocument AESV3 parsed-object encryption round trips object data" {
  let file_key = crypt_parsed_aesv3_r5_file_key_for_test()
  let key_s = crypt_parsed_name_for_test("/S")
  let key_stream = crypt_parsed_name_for_test("/Stream")
  let key_length = crypt_parsed_name_for_test("/Length")
  let object : @syntax.PdfObject = PdfDictionary([
    (key_s, PdfString(@ascii.encode("secret"))),
    (
      key_stream,
      crypt_parsed_stream_for_test(
        [(key_length, PdfInteger(7))],
        @ascii.encode("payload"),
      ),
    ),
  ])
  let doc = pdf_document_empty()
  doc.add_object_given_number(12, object)
  let encrypted = try! doc.aesv3_encrypt_parsed_objects_with_iv_provider(
    file_key,
    fn(_, _, index) { crypt_parsed_aes_iv_for_test(index) },
    false,
  )
  let decrypted = try! encrypted.aesv3_decrypt_parsed_objects(
    file_key, false, 0,
  )
  @test.assert_eq(decrypted.lookup_object_or_null(12), object)
}

///|
test "PdfDocument AESV3 parsed-object decrypt recurses through object data" {
  let file_key = crypt_parsed_aesv3_r5_file_key_for_test()
  let iv = crypt_parsed_bytes_for_test([
    0x20, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27, 0x28, 0x29, 0x2a, 0x2b, 0x2c,
    0x2d, 0x2e, 0x2f,
  ])
  let key_s = pdf_name_of_bytes(@ascii.encode("/S"))
  let key_a = pdf_name_of_bytes(@ascii.encode("/A"))
  let key_n = pdf_name_of_bytes(@ascii.encode("/N"))
  let encrypted_hello = try! crypt_parsed_aesv3_encrypt_data_for_test(
    file_key,
    @ascii.encode("hello"),
    iv,
  )
  let object : @syntax.PdfObject = PdfDictionary([
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
  let encrypted : @syntax.PdfObject = PdfDictionary([
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
  let doc = pdf_document_empty()
  doc.add_object_given_number(12, encrypted)
  let decrypted = try! doc.aesv3_decrypt_parsed_objects(file_key, false, 0)
  @test.assert_eq(decrypted.lookup_object_or_null(12), object)

  let key_length = pdf_name_of_bytes(@ascii.encode("/Length"))
  let key_title = pdf_name_of_bytes(@ascii.encode("/Title"))
  let encrypted_stream : @syntax.PdfObject = PdfStreamObject({
    dictionary: PdfDictionary([
      (key_length, PdfInteger(encrypted_hello.length())),
      (key_title, PdfString(encrypted_hello)),
    ]),
    data: StreamGot(encrypted_hello),
  })
  let plain_stream : @syntax.PdfObject = PdfStreamObject({
    dictionary: PdfDictionary([
      (key_length, PdfInteger(5)),
      (key_title, PdfString(@ascii.encode("hello"))),
    ]),
    data: StreamGot(@ascii.encode("hello")),
  })
  let stream_doc = pdf_document_empty()
  stream_doc.add_object_given_number(13, encrypted_stream)
  let decrypted_stream_doc = try! stream_doc.aesv3_decrypt_parsed_objects(
    file_key, false, 0,
  )
  @test.assert_eq(decrypted_stream_doc.lookup_object_or_null(13), plain_stream)
  let metadata_stream = crypt_parsed_stream_for_test(
    [
      (key_length, PdfInteger(encrypted_hello.length())),
      (
        crypt_parsed_name_for_test("/Type"),
        PdfNameObject(crypt_parsed_name_for_test("/Metadata")),
      ),
      (key_title, PdfString(encrypted_hello)),
    ],
    encrypted_hello,
  )
  let metadata_doc = pdf_document_empty()
  metadata_doc.add_object_given_number(14, metadata_stream)
  let decrypted_metadata_doc = try! metadata_doc.aesv3_decrypt_parsed_objects(
    file_key, true, 0,
  )
  @test.assert_eq(
    decrypted_metadata_doc.lookup_object_or_null(14),
    metadata_stream,
  )
}

///|
test "PdfDocument arc4_crypt_parsed_objects encrypts parsed objects in a copy" {
  let key = crypt_parsed_bytes_for_test([1, 2, 3, 4, 5])
  let doc = pdf_document_empty()
  doc.add_object_given_number(1, PdfString(@ascii.encode("hello")))
  doc.add_object_given_number(2, PdfString(@ascii.encode("skip")))
  doc.add_object_given_number(
    3,
    PdfString(@ascii.encode("hello")),
    generation=1,
  )
  let encrypted = try! doc.arc4_crypt_parsed_objects(key, 40, false, 2)
  @test.assert_eq(
    encrypted.lookup_object_or_null(1),
    try! crypt_parsed_arc4_crypt_object_for_test(
      1,
      0,
      key,
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
    try! crypt_parsed_arc4_crypt_object_for_test(
      3,
      1,
      key,
      40,
      PdfString(@ascii.encode("hello")),
    ),
  )
  @test.assert_eq(
    doc.lookup_object_or_null(1),
    PdfString(@ascii.encode("hello")),
  )
  @test.assert_eq(
    (try! encrypted.arc4_crypt_parsed_objects(key, 40, false, 2)).lookup_object_or_null(
      1,
    ),
    PdfString(@ascii.encode("hello")),
  )
}
