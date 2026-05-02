///|
fn id_name_for_test() -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(@ascii.encode("/ID"))
}

///|
fn id_restore_env_for_test(previous : String?) -> Unit {
  match previous {
    Some(value) => @env.set_env_var("CAMLPDF_REPRODUCIBLE_IDS", value)
    None => @env.unset_env_var("CAMLPDF_REPRODUCIBLE_IDS")
  }
}

///|
fn id_expected_for_test(seed : String) -> @pdflite.PdfObject {
  let digest = @pdflite.pdf_md5_digest(@ascii.encode(seed)[:])
  PdfArray([PdfString(digest), PdfString(digest)])
}

///|
test "pdf_generate_id hashes path and time or reproducible seed" {
  let previous = @env.get_env_var("CAMLPDF_REPRODUCIBLE_IDS")
  @env.unset_env_var("CAMLPDF_REPRODUCIBLE_IDS")
  let ordinary = @pdflite.pdf_generate_id("file.pdf", fn() { 0.5 })
  let whole = @pdflite.pdf_generate_id("whole", fn() { 2 })
  let nan_id = @pdflite.pdf_generate_id("nan-", fn() { 0.0 / 0.0 })
  let inf_id = @pdflite.pdf_generate_id("inf-", fn() { 1.0 / 0.0 })
  let neg_inf_id = @pdflite.pdf_generate_id("neg-", fn() { -1.0 / 0.0 })
  @env.set_env_var("CAMLPDF_REPRODUCIBLE_IDS", "true")
  let called = Ref::{ val: false }
  let reproducible = @pdflite.pdf_generate_id("ignored", fn() {
    called.val = true
    99
  })
  id_restore_env_for_test(previous)
  @test.assert_eq(ordinary, id_expected_for_test("file.pdf0.5"))
  @test.assert_eq(whole, id_expected_for_test("whole2."))
  @test.assert_eq(nan_id, id_expected_for_test("nan-nan"))
  @test.assert_eq(inf_id, id_expected_for_test("inf-inf"))
  @test.assert_eq(neg_inf_id, id_expected_for_test("neg--inf"))
  @test.assert_eq(reproducible, id_expected_for_test("camlpdf"))
  @test.assert_eq(called.val, false)
}

///|
test "PdfDocument change_id installs trailer ID" {
  let previous = @env.get_env_var("CAMLPDF_REPRODUCIBLE_IDS")
  @env.unset_env_var("CAMLPDF_REPRODUCIBLE_IDS")
  let key_id = id_name_for_test()
  let key_info = @pdflite.pdf_name_of_bytes(@ascii.encode("/Info"))
  let doc = @pdflite.pdf_document_empty()
  doc.set_trailer_dict(
    PdfDictionary([(key_id, PdfInteger(1)), (key_info, PdfIndirect(7))]),
  )
  try! doc.change_id("out.pdf", fn() { 2 })
  let updated = doc.trailer_dict()
  let bad = @pdflite.pdf_document_empty()
  bad.set_trailer_dict(PdfNull)
  let bad_result : Result[Unit, Error] = try? bad.change_id("bad", fn() { 0 })
  id_restore_env_for_test(previous)
  @test.assert_eq(
    updated.lookup_immediate(key_id),
    Some(id_expected_for_test("out.pdf2.")),
  )
  @test.assert_eq(updated.lookup_immediate(key_info), Some(PdfIndirect(7)))
  guard bad_result is Err(@pdflite.PdfError::DictionaryExpected) else {
    fail("expected DictionaryExpected")
  }
}
