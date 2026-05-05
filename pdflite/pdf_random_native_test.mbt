///|
fn random_native_ascii_for_test(text : String) -> @pdflite.PdfBytes {
  @ascii.encode(text)
}

///|
fn random_native_name_for_test(text : String) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(random_native_ascii_for_test(text))
}

///|
fn random_native_secret_for_test(text : String) -> @pdflite.PdfObject {
  PdfDictionary([
    (
      random_native_name_for_test("/Title"),
      PdfString(random_native_ascii_for_test(text)),
    ),
  ])
}

///|
fn random_native_document_for_test(
  text : String,
) -> @pdflite.PdfDocument raise @pdflite.PdfError {
  let document = @pdflite.pdf_minimum_valid_pdf()
  document.add_object_given_number(50, random_native_secret_for_test(text))
  document
}

///|
fn random_native_unwrap_decryption_for_test(
  result : @pdflite.PdfDecryptionResult?,
) -> @pdflite.PdfDecryptionResult raise {
  match result {
    Some(value) => value
    None => fail("expected native encrypted output to decrypt")
  }
}

///|
test "native secure random AESV2 writer decrypts and varies output" {
  let first_random = @pdflite.pdf_secure_random_bytes(16)
  let second_random = @pdflite.pdf_secure_random_bytes(16)
  @test.assert_eq(first_random.length(), 16)
  @test.assert_eq(second_random.length(), 16)
  @test.assert_eq(first_random == second_random, false)

  let denied : Array[@pdflite.PdfPermission] = [PdfNoPrint]
  let user_password = random_native_ascii_for_test("user")
  let owner_password = random_native_ascii_for_test("owner")
  let file_id = random_native_ascii_for_test("native-random-aes-id")
  let first = @pdflite.pdf_write_encrypted_aesv2_document(
    random_native_document_for_test("native random aes"),
    user_password[:],
    owner_password[:],
    denied,
    encrypt_metadata=false,
    file_id=file_id[:],
  )
  let second = @pdflite.pdf_write_encrypted_aesv2_document(
    random_native_document_for_test("native random aes"),
    user_password[:],
    owner_password[:],
    denied,
    encrypt_metadata=false,
    file_id=file_id[:],
  )
  @test.assert_eq(first == second, false)

  let decrypted = random_native_unwrap_decryption_for_test(
    @pdflite.pdf_read_document_from_bytes_with_passwords(
      first,
      owner_password=Some(owner_password[:]),
    ),
  )
  @test.assert_eq(decrypted.denied_permissions, denied)
  @test.assert_eq(
    decrypted.document.lookup_object_or_null(50),
    random_native_secret_for_test("native random aes"),
  )
}
