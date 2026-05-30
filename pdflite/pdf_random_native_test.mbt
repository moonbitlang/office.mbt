///|
fn random_native_ascii_for_test(text : String) -> @pdflite.PdfBytes {
  @ascii.encode(text)
}

///|
fn random_native_name_for_test(text : String) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(random_native_ascii_for_test(text))
}

///|
fn random_native_secret_for_test(text : String) -> @syntax.PdfObject {
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
fn random_native_decrypt_owner_for_test(
  rendered : @pdflite.PdfBytes,
  owner_password : @pdflite.PdfBytes,
) -> @pdflite.PdfDecryptionResult raise {
  random_native_unwrap_decryption_for_test(
    @pdflite.pdf_read_document_from_bytes_with_passwords(
      rendered,
      owner_password=Some(owner_password),
    ),
  )
}

///|
test "native secure random AESV2 writer decrypts and varies output" {
  let first_random = @pdflite.pdf_secure_random_bytes(16)
  let second_random = @pdflite.pdf_secure_random_bytes(16)
  @test.assert_eq(first_random.length(), 16)
  @test.assert_eq(second_random.length(), 16)
  @test.assert_eq(first_random == second_random, false)

  let denied : Array[@crypt_core.PdfPermission] = [PdfNoPrint]
  let user_password = random_native_ascii_for_test("user")
  let owner_password = random_native_ascii_for_test("owner")
  let file_id = random_native_ascii_for_test("native-random-aes-id")
  let first = @pdflite.pdf_write_encrypted_aesv2_document(
    random_native_document_for_test("native random aes"),
    user_password,
    owner_password,
    denied,
    encrypt_metadata=false,
    file_id~,
  )
  let second = @pdflite.pdf_write_encrypted_aesv2_document(
    random_native_document_for_test("native random aes"),
    user_password,
    owner_password,
    denied,
    encrypt_metadata=false,
    file_id~,
  )
  @test.assert_eq(first == second, false)

  let decrypted = random_native_unwrap_decryption_for_test(
    @pdflite.pdf_read_document_from_bytes_with_passwords(
      first,
      owner_password=Some(owner_password),
    ),
  )
  @test.assert_eq(decrypted.denied_permissions, denied)
  @test.assert_eq(
    decrypted.document.lookup_object_or_null(50),
    random_native_secret_for_test("native random aes"),
  )
}

///|
test "native secure random AESV3 writers decrypt and recrypt" {
  let user_password = random_native_ascii_for_test("user")
  let owner_password = random_native_ascii_for_test("owner")
  let file_id = random_native_ascii_for_test("native-random-aesv3-id")
  let denied : Array[@crypt_core.PdfPermission] = [PdfNoExtract]
  let first = @pdflite.pdf_write_encrypted_aesv3_document(
    random_native_document_for_test("native random aesv3"),
    user_password,
    owner_password,
    denied,
    encrypt_metadata=false,
    mode=PdfWriteCompressedXRefStream,
    file_id~,
  )
  let second = @pdflite.pdf_write_encrypted_aesv3_document(
    random_native_document_for_test("native random aesv3"),
    user_password,
    owner_password,
    denied,
    encrypt_metadata=false,
    mode=PdfWriteCompressedXRefStream,
    file_id~,
  )
  @test.assert_eq(first == second, false)
  let decrypted = random_native_decrypt_owner_for_test(first, owner_password)
  @test.assert_eq(decrypted.denied_permissions, denied)
  @test.assert_eq(
    decrypted.document.lookup_object_or_null(50),
    random_native_secret_for_test("native random aesv3"),
  )

  decrypted.document.add_object_given_number(
    50,
    random_native_secret_for_test("native random aesv3 updated"),
  )
  let recrypted = decrypted.document.recrypt_with_password_aesv3(owner_password)
  let recrypted_decrypted = random_native_decrypt_owner_for_test(
    @pdflite.pdf_write_document(recrypted),
    owner_password,
  )
  @test.assert_eq(
    recrypted_decrypted.document.lookup_object_or_null(50),
    random_native_secret_for_test("native random aesv3 updated"),
  )

  let iso = @pdflite.pdf_write_encrypted_aesv3_iso_document(
    random_native_document_for_test("native random aesv3 iso"),
    user_password,
    owner_password,
    [PdfNoAssemble],
    encrypt_metadata=false,
    mode=PdfWriteXRefStream,
    file_id=random_native_ascii_for_test("native-random-aesv3-iso-id"),
  )
  let iso_decrypted = random_native_decrypt_owner_for_test(iso, owner_password)
  @test.assert_eq(iso_decrypted.denied_permissions, [PdfNoAssemble])
  @test.assert_eq(
    iso_decrypted.document.lookup_object_or_null(50),
    random_native_secret_for_test("native random aesv3 iso"),
  )
}

///|
test "native AES encrypt methods use secure random" {
  let user_password = random_native_ascii_for_test("user")
  let owner_password = random_native_ascii_for_test("owner")
  let denied : Array[@crypt_core.PdfPermission] = [PdfNoForms]
  let aesv2 = random_native_document_for_test("native wrapper aesv2").encrypt_128bit_aesv2(
    user_password,
    owner_password,
    denied,
    encrypt_metadata=false,
    file_id=random_native_ascii_for_test("native-wrapper-aesv2-id"),
  )
  @test.assert_eq(aesv2.what_encryption(), Some(PdfEncryptionAES128(false)))
  let aesv2_decrypted = random_native_unwrap_decryption_for_test(
    aesv2.decrypt_with_owner_password(owner_password),
  )
  @test.assert_eq(aesv2_decrypted.denied_permissions, denied)
  @test.assert_eq(
    aesv2_decrypted.document.lookup_object_or_null(50),
    random_native_secret_for_test("native wrapper aesv2"),
  )

  let aesv3 = random_native_document_for_test("native wrapper aesv3").encrypt_256bit_aesv3(
    user_password,
    owner_password,
    [],
    encrypt_metadata=true,
    file_id=random_native_ascii_for_test("native-wrapper-aesv3-id"),
  )
  @test.assert_eq(aesv3.what_encryption(), Some(PdfEncryptionAES256(true)))
  let aesv3_iso = random_native_document_for_test("native wrapper aesv3 iso").encrypt_256bit_aesv3_iso(
    user_password,
    owner_password,
    [],
    encrypt_metadata=false,
    file_id=random_native_ascii_for_test("native-wrapper-aesv3-iso-id"),
  )
  @test.assert_eq(
    aesv3_iso.what_encryption(),
    Some(PdfEncryptionAES256ISO(false)),
  )
}
