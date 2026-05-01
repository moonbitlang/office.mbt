///|
async fn pdf_async_io_remove_if_exists_for_test(path : String) -> Unit {
  if @fs.exists(path) {
    @fs.remove(path)
  }
}

///|
fn pdf_async_io_name_for_test(text : String) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(@ascii.encode(text))
}

///|
async test "async file wrappers write and read PDF documents" {
  let path = "_build/pdflite_async_io_roundtrip.pdf"
  pdf_async_io_remove_if_exists_for_test(path)
  let original = try! @pdflite.pdf_minimum_valid_pdf()
  pdf_write_document_to_file(original, path)
  let loaded = pdf_read_document_from_file(path)
  pdf_async_io_remove_if_exists_for_test(path)
  @test.assert_eq(try! loaded.endpage(), 1)
  @test.assert_eq(loaded.version(), original.version())
}

///|
async test "async file wrappers write xref streams and read encrypted documents" {
  let xref_path = "_build/pdflite_async_io_xref.pdf"
  let encrypted_path = "_build/pdflite_async_io_encrypted_xref.pdf"
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
async test "async file wrappers write incremental updates" {
  let original_path = "_build/pdflite_async_io_original.pdf"
  let updated_path = "_build/pdflite_async_io_incremental.pdf"
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
async test "async file wrappers write xref stream incremental updates" {
  let original_path = "_build/pdflite_async_io_xref_original.pdf"
  let updated_path = "_build/pdflite_async_io_xref_incremental.pdf"
  let compressed_path = "_build/pdflite_async_io_xref_incremental_compressed.pdf"
  pdf_async_io_remove_if_exists_for_test(original_path)
  pdf_async_io_remove_if_exists_for_test(updated_path)
  pdf_async_io_remove_if_exists_for_test(compressed_path)
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
  let reparsed = pdf_read_document_from_file(updated_path)
  let compressed_reparsed = pdf_read_document_from_file(compressed_path)
  pdf_async_io_remove_if_exists_for_test(original_path)
  pdf_async_io_remove_if_exists_for_test(updated_path)
  pdf_async_io_remove_if_exists_for_test(compressed_path)
  @test.assert_eq(reparsed.lookup_object_or_null(21), added_object)
  @test.assert_eq(compressed_reparsed.lookup_object_or_null(21), added_object)
}
