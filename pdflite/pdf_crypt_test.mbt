///|
fn crypt_model_bytes_for_test(values : ArrayView[Int]) -> @pdflite.PdfBytes {
  try! @pdflite.pdf_bytes_of_int_array(values)
}

///|
fn crypt_restore_env_for_test(previous : String?) -> Unit {
  match previous {
    Some(value) => @env.set_env_var("CAMLPDF_REPRODUCIBLE_IDS", value)
    None => @env.unset_env_var("CAMLPDF_REPRODUCIBLE_IDS")
  }
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
) -> @pdflite.PdfBytes {
  match permissions {
    -3904 =>
      crypt_model_bytes_for_test([
        0x61, 0x58, 0xb9, 0xdd, 0xf6, 0x26, 0xa8, 0xfa, 0x36, 0x68, 0x20, 0xad, 0x7e,
        0xd7, 0xde, 0x4d,
      ])
    -4 =>
      crypt_model_bytes_for_test([
        0x90, 0x96, 0xe4, 0x75, 0x19, 0xec, 0x03, 0x12, 0x27, 0x76, 0x55, 0xae, 0xd4,
        0x41, 0x52, 0x20,
      ])
    _ => crypt_model_bytes_for_test([])
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
fn crypt_first_file_id_for_test(
  doc : @pdflite.PdfDocument,
) -> @pdflite.PdfBytes raise {
  match doc.trailer_dict().lookup_immediate(crypt_name_for_test("/ID")) {
    Some(PdfArray([PdfString(file_id), _])) => file_id
    _ => fail("expected first trailer file ID")
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

  let denied : Array[@crypt_core.PdfPermission] = [PdfNoPrint, PdfNoCopy]
  let permissions = @crypt_core.pdf_p_of_permissions(denied)
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
test "PdfDocument decrypt_with_password authenticates user and owner passwords" {
  let doc = try! @pdflite.pdf_document_empty().encrypt_128bit(
    @ascii.encode("user"),
    @ascii.encode("owner"),
    @crypt_core.pdf_permissions_of_p(-3904),
    file_id=@ascii.encode("doc-id"),
  )
  guard (try! doc.decrypt_with_user_password(@ascii.encode("user"))) is Some(_) else {
    fail("expected user password to decrypt")
  }
  @test.assert_eq(
    try! doc.decrypt_with_user_password(@ascii.encode("bad")),
    None,
  )
  guard (try! doc.decrypt_with_owner_password(@ascii.encode("owner")))
    is Some(_) else {
    fail("expected owner password to decrypt")
  }
  @test.assert_eq(
    try! doc.decrypt_with_owner_password(@ascii.encode("bad")),
    None,
  )
}

///|
test "PdfDocument AESV2 passwords use revision 4 keys" {
  let doc = try! @pdflite.pdf_document_empty().encrypt_128bit_aesv2_with_iv_provider(
    @ascii.encode("user"),
    @ascii.encode("owner"),
    @crypt_core.pdf_permissions_of_p(-3904),
    fn(_, _, _) { Bytes::new(16) },
    file_id=@ascii.encode("doc-id"),
  )
  @test.assert_eq(try! doc.what_encryption(), Some(PdfEncryptionAES128(true)))
  guard (try! doc.decrypt_with_user_password(@ascii.encode("user"))) is Some(_) else {
    fail("expected AESV2 user password to decrypt")
  }
}

///|
test "PdfDocument decrypt_with_password authenticates AESV3 revision 5 passwords" {
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
  @test.assert_eq(try! doc.what_encryption(), Some(PdfEncryptionAES256(true)))
  guard (try! doc.decrypt_with_user_password(@ascii.encode("user"))) is Some(_) else {
    fail("expected AESV3 user password to decrypt")
  }
  @test.assert_eq(
    try! doc.decrypt_with_user_password(@ascii.encode("bad")),
    None,
  )
  guard (try! doc.decrypt_with_owner_password(@ascii.encode("owner")))
    is Some(_) else {
    fail("expected AESV3 owner password to decrypt")
  }
  @test.assert_eq(
    try! doc.decrypt_with_owner_password(@ascii.encode("bad")),
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
  let missing_perms_result : Result[@pdflite.PdfDecryptionResult?, Error] = try? missing_perms_doc.decrypt_with_user_password(
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
  let short_perms_result : Result[@pdflite.PdfDecryptionResult?, Error] = try? short_perms_doc.decrypt_with_user_password(
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
  let corrupt_perms_result : Result[@pdflite.PdfDecryptionResult?, Error] = try? corrupt_perms_doc.decrypt_with_user_password(
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
  let mismatched_perms_result : Result[@pdflite.PdfDecryptionResult?, Error] = try? mismatched_perms_doc.decrypt_with_owner_password(
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
  let missing_ue_result : Result[@pdflite.PdfDecryptionResult?, Error] = try? missing_ue_doc.decrypt_with_user_password(
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
  let short_oe_result : Result[@pdflite.PdfDecryptionResult?, Error] = try? short_oe_doc.decrypt_with_owner_password(
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
    @crypt_core.pdf_permissions_of_p(-3904),
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
  let permissions = @crypt_core.pdf_p_of_permissions([PdfNoPrint])
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
  guard encrypt_dictionary.lookup_immediate(key_o)
    is Some(PdfString(owner_entry)) else {
    fail("expected owner entry")
  }
  @test.assert_eq(owner_entry.length(), 32)
  guard encrypt_dictionary.lookup_immediate(key_u)
    is Some(PdfString(found_user_entry)) else {
    fail("expected user entry")
  }
  @test.assert_eq(found_user_entry.length(), 32)
  @test.assert_eq(try! encrypted.what_encryption(), Some(PdfEncryption40Bit))
  @test.assert_eq(try! encrypted.permissions(), [PdfNoPrint])
  @test.assert_eq(
    try! crypt_first_file_id_for_test(encrypted),
    @ascii.encode("doc-id"),
  )
  let decrypted = crypt_unwrap_decryption_result_for_test(
    try! encrypted.decrypt_with_user_password(@ascii.encode("user")),
  )
  @test.assert_eq(decrypted.document.lookup_object_or_null(1), plain_object)
  @test.assert_eq(decrypted.denied_permissions, [PdfNoPrint])
  @test.assert_eq(
    decrypted.document.trailer_dict().lookup_immediate(key_encrypt),
    None,
  )
  let copied_recrypted = try! decrypted.document
    .copy()
    .recrypt_with_password(@ascii.encode("user"))
  @test.assert_eq(copied_recrypted.is_encrypted(), true)
  @test.assert_eq(
    try! copied_recrypted.what_encryption(),
    Some(PdfEncryption40Bit),
  )
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
    try! crypt_first_file_id_for_test(encrypted),
    @ascii.encode("chosen-id"),
  )
  @test.assert_eq(doc.trailer_dict().lookup_immediate(key_id), None)
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

  let denied : Array[@crypt_core.PdfPermission] = [PdfNoPrint]
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
  let denied : Array[@crypt_core.PdfPermission] = [PdfNoCopy]
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
test "@crypt_core.pdf_permissions_of_p parses CamlPDF denied permission bits" {
  @test.assert_eq(@crypt_core.pdf_permissions_of_p(-4), [])
  @test.assert_eq(@crypt_core.pdf_permissions_of_p(-8), [PdfNoPrint])
  @test.assert_eq(@crypt_core.pdf_permissions_of_p(-3904), [
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
test "@crypt_core.pdf_p_of_permissions writes signed CamlPDF permission masks" {
  @test.assert_eq(@crypt_core.pdf_p_of_permissions([]), -4)
  @test.assert_eq(@crypt_core.pdf_p_of_permissions([PdfNoPrint]), -8)
  @test.assert_eq(
    @crypt_core.pdf_p_of_permissions([
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
  let denied : Array[@crypt_core.PdfPermission] = [
    PdfNoCopy,
    PdfNoExtract,
    PdfNoHqPrint,
  ]
  @test.assert_eq(
    @crypt_core.pdf_permissions_of_p(@crypt_core.pdf_p_of_permissions(denied)),
    [PdfNoHqPrint, PdfNoExtract, PdfNoCopy],
  )
}
