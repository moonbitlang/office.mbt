///|
fn id_name_for_test() -> @core.PdfName {
  @core.pdf_name_of_bytes(b"/ID")
}

///|
fn id_restore_env_for_test(previous : String?) -> Unit {
  match previous {
    Some(value) => @env.set_env_var("CAMLPDF_REPRODUCIBLE_IDS", value)
    None => @env.unset_env_var("CAMLPDF_REPRODUCIBLE_IDS")
  }
}

///|
fn id_bytes_for_test(values : ArrayView[Int]) -> @core.PdfBytes {
  try! @core.pdf_bytes_of_int_array(values)
}

///|
fn id_expected_for_test(seed : String) -> @syntax.PdfObject {
  let digest = match seed {
    "file.pdf0.5" =>
      id_bytes_for_test([
        0x23, 0xa2, 0xca, 0x4b, 0x49, 0xaf, 0x0d, 0x06, 0x12, 0xc5, 0x1e, 0x75, 0xe6,
        0x38, 0xd9, 0x8a,
      ])
    "whole2." =>
      id_bytes_for_test([
        0x56, 0x53, 0x92, 0x9e, 0xff, 0x6e, 0xe4, 0x12, 0x07, 0x14, 0xef, 0x5a, 0x76,
        0x6d, 0x71, 0x85,
      ])
    "nan-nan" =>
      id_bytes_for_test([
        0x36, 0x85, 0x46, 0x52, 0x92, 0x0e, 0x0c, 0x20, 0xc7, 0xce, 0x4f, 0x25, 0xc5,
        0xfd, 0x3c, 0x9d,
      ])
    "inf-inf" =>
      id_bytes_for_test([
        0x66, 0x19, 0x4d, 0xaa, 0x4d, 0x95, 0x39, 0x31, 0xb5, 0xe8, 0xaa, 0x33, 0x04,
        0xc9, 0xaa, 0x42,
      ])
    "neg--inf" =>
      id_bytes_for_test([
        0x15, 0x63, 0xb6, 0x5c, 0x80, 0x64, 0x0a, 0x5f, 0x73, 0xa6, 0xad, 0x85, 0xc0,
        0x9b, 0x18, 0x2a,
      ])
    "camlpdf" =>
      id_bytes_for_test([
        0xe1, 0x43, 0x6d, 0x66, 0xa1, 0x0b, 0xd6, 0x4e, 0xc8, 0xc8, 0xdc, 0x0a, 0xd7,
        0xc3, 0x83, 0x55,
      ])
    "out.pdf2." =>
      id_bytes_for_test([
        0x66, 0x90, 0xb4, 0x27, 0x84, 0x8a, 0x63, 0x1b, 0x55, 0x3f, 0xcf, 0x55, 0xe2,
        0x5a, 0x3d, 0xf4,
      ])
    _ => id_bytes_for_test([])
  }
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
  let key_info = @core.pdf_name_of_bytes(b"/Info")
  let doc = @pdflite.pdf_document_empty()
  doc.set_trailer_dict(
    PdfDictionary([(key_id, PdfInteger(1)), (key_info, PdfIndirect(7))]),
  )
  try! doc.change_id("out.pdf", fn() { 2 })
  let updated = doc.trailer_dict()
  let bad = @pdflite.pdf_document_empty()
  bad.set_trailer_dict(PdfNull)
  let bad_result : Result[Unit, Error] = try
    bad.change_id("bad", fn() { 0 })
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  id_restore_env_for_test(previous)
  @test.assert_eq(
    updated.lookup_immediate(key_id),
    Some(id_expected_for_test("out.pdf2.")),
  )
  @test.assert_eq(updated.lookup_immediate(key_info), Some(PdfIndirect(7)))
  guard bad_result is Err(@core.PdfError::DictionaryExpected) else {
    fail("expected @core.PdfError::DictionaryExpected")
  }
}
