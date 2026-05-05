///|
async fn pdf_async_io_remove_if_exists_for_test(path : String) -> Unit {
  if @fs.exists(path) {
    @fs.remove(path)
  }
}

///|
fn pdf_async_io_test_path_for_test(name : String) -> String {
  let directory = match @env.current_dir() {
    Some(current_dir) => current_dir + "/_build/"
    None => "_build/"
  }
  directory + "pdflite_async_io_" + name + "_" + @env.now().to_string() + ".pdf"
}

///|
fn pdf_async_io_repo_path_for_test(path : String) -> String {
  match @env.current_dir() {
    Some(current_dir) => current_dir + "/" + path
    None => path
  }
}

///|
fn pdf_async_io_name_for_test(text : String) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn pdf_async_io_ascii_codepoints_for_test(text : String) -> Array[Int] {
  [
    for byte in @ascii.encode(text) => byte.to_int()
  ]
}

///|
fn pdf_async_io_codepoints_contain_for_test(
  haystack : ArrayView[Int],
  needle : ArrayView[Int],
) -> Bool {
  if needle.length() == 0 {
    true
  } else if needle.length() > haystack.length() {
    false
  } else {
    for start in 0..<=(haystack.length() - needle.length()) {
      let mut matched = true
      for offset in 0..<needle.length() {
        if haystack[start + offset] != needle[offset] {
          matched = false
        }
      }
      if matched {
        break true
      }
    } nobreak {
      false
    }
  }
}

///|
fn pdf_async_io_font_resource_for_test(
  doc : @pdflite.PdfDocument,
  resources : @pdflite.PdfObject,
  font_name : @pdflite.PdfName,
) -> @pdflite.PdfObject? {
  match doc.lookup_direct(pdf_async_io_name_for_test("/Font"), resources) {
    Some(fonts) => doc.lookup_direct(font_name, fonts)
    None => None
  }
}

///|
fn pdf_async_io_push_text_codepoints_for_test(
  output : Array[Int],
  extractor : @pdflite.PdfTextExtractor,
  text : @pdflite.PdfBytes,
) -> Unit raise {
  for codepoint in extractor.codepoints_of_text(text[:]) {
    output.push(codepoint)
  }
}

///|
fn pdf_async_io_first_page_text_codepoints_for_test(
  doc : @pdflite.PdfDocument,
) -> Array[Int] raise {
  let pages = doc.pages_of_pagetree()
  guard pages.length() > 0 else { fail("expected at least one page") }
  let output : Array[Int] = []
  let mut extractor : @pdflite.PdfTextExtractor? = None
  for
    op in doc.parse_content_ops_with_resources(
      pages[0].resources,
      pages[0].content,
    ) {
    match op {
      Op_Tf(font_name, _) =>
        match
          pdf_async_io_font_resource_for_test(
            doc,
            pages[0].resources,
            font_name,
          ) {
          Some(font) => extractor = Some(doc.text_extractor_of_font(font))
          None => extractor = None
        }
      Op_Tj(text) =>
        match extractor {
          Some(extractor) =>
            pdf_async_io_push_text_codepoints_for_test(output, extractor, text)
          None => ()
        }
      Op_TJ(PdfArray(items)) =>
        match extractor {
          Some(extractor) =>
            for item in items {
              match item {
                PdfString(text) =>
                  pdf_async_io_push_text_codepoints_for_test(
                    output, extractor, text,
                  )
                _ => ()
              }
            }
          None => ()
        }
      _ => ()
    }
  }
  output
}

///|
fn pdf_async_io_secret_object_for_test(text : String) -> @pdflite.PdfObject {
  PdfDictionary([
    (pdf_async_io_name_for_test("/Title"), PdfString(@ascii.encode(text))),
  ])
}

///|
fn pdf_async_io_secret_document_for_test(
  text : String,
) -> @pdflite.PdfDocument raise @pdflite.PdfError {
  let document = @pdflite.pdf_minimum_valid_pdf()
  document.add_object_given_number(
    41,
    pdf_async_io_secret_object_for_test(text),
  )
  document
}

///|
fn pdf_async_io_decryption_result_for_test(
  result : @pdflite.PdfDecryptionResult?,
) -> @pdflite.PdfDecryptionResult raise {
  match result {
    Some(result) => result
    None => fail("expected decrypted async file")
  }
}

///|
async fn pdf_async_io_assert_encrypted_file_secret_for_test(
  path : String,
  owner_password : String,
  denied : Array[@pdflite.PdfPermission],
  text : String,
) -> Unit {
  let decrypted = pdf_async_io_decryption_result_for_test(
    pdf_read_document_from_file_with_passwords(
      path,
      owner_password=Some(@ascii.encode(owner_password)[:]),
    ),
  )
  @test.assert_eq(try! decrypted.document.endpage(), 1)
  @test.assert_eq(decrypted.denied_permissions, denied)
  @test.assert_eq(
    decrypted.document.lookup_object_or_null(41),
    pdf_async_io_secret_object_for_test(text),
  )
}

///|
async test "async file wrappers write and read PDF documents" {
  let path = pdf_async_io_test_path_for_test("roundtrip")
  pdf_async_io_remove_if_exists_for_test(path)
  let original = try! @pdflite.pdf_minimum_valid_pdf()
  pdf_write_document_to_file(original, path)
  let loaded = pdf_read_document_from_file(path)
  pdf_async_io_remove_if_exists_for_test(path)
  @test.assert_eq(try! loaded.endpage(), 1)
  @test.assert_eq(loaded.version(), original.version())
}

///|
async test "async file wrappers read checked-in CamlPDF fixture PDFs" {
  let logo_path = pdf_async_io_repo_path_for_test(".repos/logo.pdf")
  let intro_path = pdf_async_io_repo_path_for_test(
    ".repos/introduction_to_camlpdf.pdf",
  )
  let logo_roundtrip = pdf_async_io_test_path_for_test("logo_fixture")
  let intro_roundtrip = pdf_async_io_test_path_for_test("intro_fixture")
  let intro_decompressed_roundtrip = pdf_async_io_test_path_for_test(
    "intro_decompressed_fixture",
  )
  pdf_async_io_remove_if_exists_for_test(logo_roundtrip)
  pdf_async_io_remove_if_exists_for_test(intro_roundtrip)
  pdf_async_io_remove_if_exists_for_test(intro_decompressed_roundtrip)

  let logo = pdf_read_document_from_file(logo_path)
  @test.assert_eq(logo.version(), (1, 4))
  @test.assert_eq(try! logo.endpage(), 1)
  pdf_write_document_to_file_with_compressed_xref_stream(logo, logo_roundtrip)
  let logo_reparsed = pdf_read_document_from_file(logo_roundtrip)
  @test.assert_eq(try! logo_reparsed.endpage(), 1)

  let intro = pdf_read_document_from_file(intro_path)
  @test.assert_eq(intro.version(), (1, 5))
  @test.assert_eq(try! intro.endpage(), 10)
  let first_page_text = pdf_async_io_first_page_text_codepoints_for_test(intro)
  @test.assert_eq(
    pdf_async_io_codepoints_contain_for_test(
      first_page_text[:],
      pdf_async_io_ascii_codepoints_for_test("CamlPDF")[:],
    ),
    true,
  )
  @test.assert_eq(
    pdf_async_io_codepoints_contain_for_test(
      first_page_text[:],
      pdf_async_io_ascii_codepoints_for_test("Introduction")[:],
    ),
    true,
  )
  pdf_write_document_to_file_with_compressed_xref_stream(intro, intro_roundtrip)
  let intro_reparsed = pdf_read_document_from_file(intro_roundtrip)
  @test.assert_eq(try! intro_reparsed.endpage(), 10)

  let intro_decompressed = intro.copy()
  intro_decompressed.pdf_decode_streams_until_unknown()
  pdf_write_document_to_file_with_compressed_xref_stream(
    intro_decompressed, intro_decompressed_roundtrip,
  )
  let intro_decompressed_reparsed = pdf_read_document_from_file(
    intro_decompressed_roundtrip,
  )
  @test.assert_eq(try! intro_decompressed_reparsed.endpage(), 10)

  pdf_async_io_remove_if_exists_for_test(logo_roundtrip)
  pdf_async_io_remove_if_exists_for_test(intro_roundtrip)
  pdf_async_io_remove_if_exists_for_test(intro_decompressed_roundtrip)
}

///|
async test "async file wrappers write xref streams and read encrypted documents" {
  let xref_path = pdf_async_io_test_path_for_test("xref")
  let encrypted_path = pdf_async_io_test_path_for_test("encrypted_xref")
  pdf_async_io_remove_if_exists_for_test(xref_path)
  pdf_async_io_remove_if_exists_for_test(encrypted_path)
  let original = try! @pdflite.pdf_minimum_valid_pdf()
  pdf_write_document_to_file_with_xref_stream(original, xref_path)
  let loaded = pdf_read_document_from_file(xref_path)
  @test.assert_eq(loaded.version(), (1, 5))
  @test.assert_eq(try! loaded.endpage(), 1)

  let encrypted = try! original.encrypt_128bit_r4(
    @ascii.encode("user")[:],
    @ascii.encode("owner")[:],
    [PdfNoPrint],
    encrypt_metadata=true,
    file_id=@ascii.encode("async-doc-id")[:],
  )
  pdf_write_document_to_file_with_compressed_xref_stream(
    encrypted, encrypted_path,
  )
  guard pdf_read_document_from_file_with_passwords(
      encrypted_path,
      user_password=Some(@ascii.encode("bad")[:]),
      owner_password=Some(@ascii.encode("owner")[:]),
    )
    is Some(decrypted) else {
    fail("expected decrypted async file")
  }
  pdf_async_io_remove_if_exists_for_test(xref_path)
  pdf_async_io_remove_if_exists_for_test(encrypted_path)
  @test.assert_eq(try! decrypted.document.endpage(), 1)
  @test.assert_eq(decrypted.denied_permissions, [PdfNoPrint])
}

///|
async test "async file wrappers write mode-dispatched encrypted documents" {
  let mode_path = pdf_async_io_test_path_for_test("mode_dispatch")
  let arc4_40_path = pdf_async_io_test_path_for_test("encrypt_40")
  let arc4_128_path = pdf_async_io_test_path_for_test("encrypt_128")
  let arc4_r4_path = pdf_async_io_test_path_for_test("encrypt_r4")
  let aesv2_path = pdf_async_io_test_path_for_test("encrypt_aesv2")
  let aesv2_default_path = pdf_async_io_test_path_for_test(
    "encrypt_aesv2_default",
  )
  let aesv3_path = pdf_async_io_test_path_for_test("encrypt_aesv3")
  let aesv3_default_path = pdf_async_io_test_path_for_test(
    "encrypt_aesv3_default",
  )
  let aesv3_iso_path = pdf_async_io_test_path_for_test("encrypt_aesv3_iso")
  let aesv3_iso_default_path = pdf_async_io_test_path_for_test(
    "encrypt_aesv3_iso_default",
  )
  pdf_async_io_remove_if_exists_for_test(mode_path)
  pdf_async_io_remove_if_exists_for_test(arc4_40_path)
  pdf_async_io_remove_if_exists_for_test(arc4_128_path)
  pdf_async_io_remove_if_exists_for_test(arc4_r4_path)
  pdf_async_io_remove_if_exists_for_test(aesv2_path)
  pdf_async_io_remove_if_exists_for_test(aesv2_default_path)
  pdf_async_io_remove_if_exists_for_test(aesv3_path)
  pdf_async_io_remove_if_exists_for_test(aesv3_default_path)
  pdf_async_io_remove_if_exists_for_test(aesv3_iso_path)
  pdf_async_io_remove_if_exists_for_test(aesv3_iso_default_path)
  let user = @ascii.encode("user")
  let owner = @ascii.encode("owner")
  let denied : Array[@pdflite.PdfPermission] = [PdfNoEdit, PdfNoPrint]
  pdf_write_document_to_file_with_mode(
    try! @pdflite.pdf_minimum_valid_pdf(),
    mode_path,
    PdfWriteCompressedXRefStream,
  )
  @test.assert_eq(pdf_read_document_from_file(mode_path).version(), (1, 5))
  pdf_write_encrypted_40bit_document_to_file(
    try! pdf_async_io_secret_document_for_test("async-40"),
    arc4_40_path,
    user[:],
    owner[:],
    denied,
    file_id=@ascii.encode("async-40-id")[:],
  )
  pdf_async_io_assert_encrypted_file_secret_for_test(
    arc4_40_path, "owner", denied, "async-40",
  )
  pdf_write_encrypted_128bit_document_to_file(
    try! pdf_async_io_secret_document_for_test("async-128"),
    arc4_128_path,
    user[:],
    owner[:],
    denied,
    mode=PdfWriteXRefStream,
    file_id=@ascii.encode("async-128-id")[:],
  )
  pdf_async_io_assert_encrypted_file_secret_for_test(
    arc4_128_path, "owner", denied, "async-128",
  )
  pdf_write_encrypted_128bit_r4_document_to_file(
    try! pdf_async_io_secret_document_for_test("async-r4"),
    arc4_r4_path,
    user[:],
    owner[:],
    denied,
    encrypt_metadata=false,
    mode=PdfWriteCompressedXRefStream,
    file_id=@ascii.encode("async-r4-id")[:],
  )
  pdf_async_io_assert_encrypted_file_secret_for_test(
    arc4_r4_path, "owner", denied, "async-r4",
  )
  pdf_write_encrypted_aesv2_document_to_file_with_iv_provider(
    try! pdf_async_io_secret_document_for_test("async-aesv2"),
    aesv2_path,
    user[:],
    owner[:],
    [PdfNoCopy],
    @pdflite.pdf_deterministic_aes_iv_provider_from_seed(
      @ascii.encode("async-aesv2-iv")[:],
    ),
    encrypt_metadata=false,
    mode=PdfWriteCompressedXRefStream,
    file_id=@ascii.encode("async-aesv2-id")[:],
  )
  pdf_async_io_assert_encrypted_file_secret_for_test(
    aesv2_path,
    "owner",
    [PdfNoCopy],
    "async-aesv2",
  )
  pdf_write_encrypted_aesv2_document_to_file(
    try! pdf_async_io_secret_document_for_test("async-aesv2-default"),
    aesv2_default_path,
    user[:],
    owner[:],
    [PdfNoPrint],
    encrypt_metadata=false,
    mode=PdfWriteCompressedXRefStream,
    file_id=@ascii.encode("async-aesv2-default-id")[:],
  )
  pdf_async_io_assert_encrypted_file_secret_for_test(
    aesv2_default_path,
    "owner",
    [PdfNoPrint],
    "async-aesv2-default",
  )
  pdf_write_encrypted_aesv3_document_to_file_with_providers(
    try! pdf_async_io_secret_document_for_test("async-aesv3"),
    aesv3_path,
    user[:],
    owner[:],
    [PdfNoExtract],
    @pdflite.pdf_deterministic_aesv3_random_provider_from_seed(
      @ascii.encode("async-aesv3-random")[:],
    ),
    @pdflite.pdf_deterministic_aes_iv_provider_from_seed(
      @ascii.encode("async-aesv3-iv")[:],
    ),
    mode=PdfWriteXRefStream,
    file_id=@ascii.encode("async-aesv3-id")[:],
  )
  pdf_async_io_assert_encrypted_file_secret_for_test(
    aesv3_path,
    "owner",
    [PdfNoExtract],
    "async-aesv3",
  )
  pdf_write_encrypted_aesv3_document_to_file(
    try! pdf_async_io_secret_document_for_test("async-aesv3-default"),
    aesv3_default_path,
    user[:],
    owner[:],
    [PdfNoExtract],
    encrypt_metadata=false,
    mode=PdfWriteCompressedXRefStream,
    file_id=@ascii.encode("async-aesv3-default-id")[:],
  )
  pdf_async_io_assert_encrypted_file_secret_for_test(
    aesv3_default_path,
    "owner",
    [PdfNoExtract],
    "async-aesv3-default",
  )
  pdf_write_encrypted_aesv3_iso_document_to_file_with_providers(
    try! pdf_async_io_secret_document_for_test("async-aesv3-iso"),
    aesv3_iso_path,
    user[:],
    owner[:],
    [PdfNoAssemble],
    @pdflite.pdf_deterministic_aesv3_random_provider_from_seed(
      @ascii.encode("async-aesv3-iso-random")[:],
    ),
    @pdflite.pdf_deterministic_aes_iv_provider_from_seed(
      @ascii.encode("async-aesv3-iso-iv")[:],
    ),
    encrypt_metadata=false,
    file_id=@ascii.encode("async-aesv3-iso-id")[:],
  )
  pdf_async_io_assert_encrypted_file_secret_for_test(
    aesv3_iso_path,
    "owner",
    [PdfNoAssemble],
    "async-aesv3-iso",
  )
  pdf_write_encrypted_aesv3_iso_document_to_file(
    try! pdf_async_io_secret_document_for_test("async-aesv3-iso-default"),
    aesv3_iso_default_path,
    user[:],
    owner[:],
    [PdfNoAssemble],
    encrypt_metadata=false,
    file_id=@ascii.encode("async-aesv3-iso-default-id")[:],
  )
  pdf_async_io_assert_encrypted_file_secret_for_test(
    aesv3_iso_default_path,
    "owner",
    [PdfNoAssemble],
    "async-aesv3-iso-default",
  )
  pdf_async_io_remove_if_exists_for_test(mode_path)
  pdf_async_io_remove_if_exists_for_test(arc4_40_path)
  pdf_async_io_remove_if_exists_for_test(arc4_128_path)
  pdf_async_io_remove_if_exists_for_test(arc4_r4_path)
  pdf_async_io_remove_if_exists_for_test(aesv2_path)
  pdf_async_io_remove_if_exists_for_test(aesv2_default_path)
  pdf_async_io_remove_if_exists_for_test(aesv3_path)
  pdf_async_io_remove_if_exists_for_test(aesv3_default_path)
  pdf_async_io_remove_if_exists_for_test(aesv3_iso_path)
  pdf_async_io_remove_if_exists_for_test(aesv3_iso_default_path)
}

///|
async test "async file wrappers write incremental updates" {
  let original_path = pdf_async_io_test_path_for_test("original")
  let updated_path = pdf_async_io_test_path_for_test("incremental")
  pdf_async_io_remove_if_exists_for_test(original_path)
  pdf_async_io_remove_if_exists_for_test(updated_path)
  let original = try! @pdflite.pdf_minimum_valid_pdf()
  pdf_write_document_to_file(original, original_path)
  let updated = pdf_read_document_from_file(original_path)
  let key_title = pdf_async_io_name_for_test("/Title")
  let added_object : @pdflite.PdfObject = PdfDictionary([
    (key_title, PdfString(@ascii.encode("async incremental"))),
  ])
  updated.add_object_given_number(20, added_object)
  pdf_write_document_incremental_update_to_file(
    original_path, updated, updated_path,
  )
  let reparsed = pdf_read_document_from_file(updated_path)
  pdf_async_io_remove_if_exists_for_test(original_path)
  pdf_async_io_remove_if_exists_for_test(updated_path)
  @test.assert_eq(try! reparsed.endpage(), 1)
  @test.assert_eq(reparsed.lookup_object_or_null(20), added_object)
}

///|
async test "async file wrappers read incremental revisions" {
  let original_path = pdf_async_io_test_path_for_test("revision_original")
  let updated_path = pdf_async_io_test_path_for_test("revision_incremental")
  pdf_async_io_remove_if_exists_for_test(original_path)
  pdf_async_io_remove_if_exists_for_test(updated_path)
  let original = try! @pdflite.pdf_minimum_valid_pdf()
  pdf_write_document_to_file(original, original_path)
  let updated = pdf_read_document_from_file(original_path)
  let key_title = pdf_async_io_name_for_test("/Title")
  let added_object : @pdflite.PdfObject = PdfDictionary([
    (key_title, PdfString(@ascii.encode("async revision"))),
  ])
  updated.add_object_given_number(22, added_object)
  pdf_write_document_incremental_update_to_file(
    original_path, updated, updated_path,
  )
  let revision_count = pdf_revisions_from_file(updated_path)
  let latest = pdf_read_document_revision_from_file(updated_path, 1)
  let older = pdf_read_document_revision_from_file(updated_path, 2)
  guard pdf_read_document_revision_from_file_with_passwords(updated_path, 2)
    is Some(older_password_result) else {
    fail("expected revision decryption result")
  }
  pdf_async_io_remove_if_exists_for_test(original_path)
  pdf_async_io_remove_if_exists_for_test(updated_path)
  @test.assert_eq(revision_count, 2)
  @test.assert_eq(latest.lookup_object_or_null(22), added_object)
  @test.assert_eq(older.lookup_object_or_null(22), PdfNull)
  @test.assert_eq(
    older_password_result.document.lookup_object_or_null(22),
    PdfNull,
  )
  @test.assert_eq(older_password_result.denied_permissions, [])
}

///|
async test "async file wrappers write xref stream incremental updates" {
  let original_path = pdf_async_io_test_path_for_test("xref_original")
  let updated_path = pdf_async_io_test_path_for_test("xref_incremental")
  let compressed_path = pdf_async_io_test_path_for_test(
    "xref_incremental_compressed",
  )
  let mode_path = pdf_async_io_test_path_for_test("xref_incremental_mode")
  pdf_async_io_remove_if_exists_for_test(original_path)
  pdf_async_io_remove_if_exists_for_test(updated_path)
  pdf_async_io_remove_if_exists_for_test(compressed_path)
  pdf_async_io_remove_if_exists_for_test(mode_path)
  let original = try! @pdflite.pdf_minimum_valid_pdf()
  pdf_write_document_to_file_with_xref_stream(original, original_path)
  let updated = pdf_read_document_from_file(original_path)
  let key_title = pdf_async_io_name_for_test("/Title")
  let added_object : @pdflite.PdfObject = PdfDictionary([
    (key_title, PdfString(@ascii.encode("async xref incremental"))),
  ])
  updated.add_object_given_number(21, added_object)
  pdf_write_document_incremental_update_with_xref_stream_to_file(
    original_path, updated, updated_path,
  )
  pdf_write_document_incremental_update_with_compressed_xref_stream_to_file(
    original_path, updated, compressed_path,
  )
  pdf_write_document_incremental_update_to_file_with_mode(
    original_path,
    updated,
    mode_path,
    PdfWriteCompressedXRefStream,
  )
  let reparsed = pdf_read_document_from_file(updated_path)
  let compressed_reparsed = pdf_read_document_from_file(compressed_path)
  let mode_reparsed = pdf_read_document_from_file(mode_path)
  pdf_async_io_remove_if_exists_for_test(original_path)
  pdf_async_io_remove_if_exists_for_test(updated_path)
  pdf_async_io_remove_if_exists_for_test(compressed_path)
  pdf_async_io_remove_if_exists_for_test(mode_path)
  @test.assert_eq(reparsed.lookup_object_or_null(21), added_object)
  @test.assert_eq(compressed_reparsed.lookup_object_or_null(21), added_object)
  @test.assert_eq(mode_reparsed.lookup_object_or_null(21), added_object)
}

///|
async test "async file wrappers read encrypted incremental revisions" {
  let original_path = pdf_async_io_test_path_for_test(
    "encrypted_revision_original",
  )
  let updated_path = pdf_async_io_test_path_for_test(
    "encrypted_revision_incremental",
  )
  pdf_async_io_remove_if_exists_for_test(original_path)
  pdf_async_io_remove_if_exists_for_test(updated_path)
  let original_secret = pdf_async_io_secret_object_for_test(
    "async encrypted original",
  )
  let updated_secret = pdf_async_io_secret_object_for_test(
    "async encrypted updated",
  )
  let doc = try! @pdflite.pdf_minimum_valid_pdf()
  doc.add_object_given_number(30, original_secret)
  let denied : Array[@pdflite.PdfPermission] = [PdfNoCopy]
  let encrypted = try! doc.encrypt_128bit_aesv2_with_iv_provider(
    @ascii.encode("user")[:],
    @ascii.encode("owner")[:],
    denied,
    @pdflite.pdf_deterministic_aes_iv_provider_from_seed(
      @ascii.encode("async encrypted revision iv")[:],
    ),
    encrypt_metadata=false,
    file_id=@ascii.encode("async-encrypted-revision-id")[:],
  )
  pdf_write_document_to_file(encrypted, original_path)
  let decrypted = pdf_async_io_decryption_result_for_test(
    pdf_read_document_from_file_with_passwords(
      original_path,
      user_password=Some(@ascii.encode("user")[:]),
    ),
  )
  decrypted.document.add_object_given_number(30, updated_secret)
  let recrypted = try! decrypted.document.recrypt_with_password_aesv2_with_iv_provider(
    @ascii.encode("owner")[:],
    @pdflite.pdf_deterministic_aes_iv_provider_from_seed(
      @ascii.encode("async encrypted revision recrypt iv")[:],
    ),
  )
  pdf_write_document_incremental_update_with_compressed_xref_stream_to_file(
    original_path, recrypted, updated_path,
  )
  let revision_count = pdf_revisions_from_file(updated_path)
  let newest = pdf_async_io_decryption_result_for_test(
    pdf_read_document_revision_from_file_with_passwords(
      updated_path,
      1,
      owner_password=Some(@ascii.encode("owner")[:]),
    ),
  )
  let older = pdf_async_io_decryption_result_for_test(
    pdf_read_document_revision_from_file_with_passwords(
      updated_path,
      2,
      owner_password=Some(@ascii.encode("owner")[:]),
    ),
  )
  pdf_async_io_remove_if_exists_for_test(original_path)
  pdf_async_io_remove_if_exists_for_test(updated_path)
  @test.assert_eq(revision_count, 2)
  @test.assert_eq(newest.denied_permissions, denied)
  @test.assert_eq(newest.document.lookup_object_or_null(30), updated_secret)
  @test.assert_eq(older.denied_permissions, denied)
  @test.assert_eq(older.document.lookup_object_or_null(30), original_secret)
}
