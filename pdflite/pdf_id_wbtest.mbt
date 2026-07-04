///|
fn id_wb_restore_env_for_test(previous : String?) -> Unit {
  match previous {
    Some(value) => @env.set_env_var("CAMLPDF_REPRODUCIBLE_IDS", value)
    None => @env.unset_env_var("CAMLPDF_REPRODUCIBLE_IDS")
  }
}

///|
test "private current ID generation honors env and time source" {
  let previous = @env.get_env_var("CAMLPDF_REPRODUCIBLE_IDS")
  @env.unset_env_var("CAMLPDF_REPRODUCIBLE_IDS")
  let ordinary = pdf_generate_id_bytes_from_text("", fn() { "12345" })
  let current = pdf_generate_current_id_bytes("")
  @env.set_env_var("CAMLPDF_REPRODUCIBLE_IDS", "true")
  let called = Ref::{ val: false }
  let reproducible = pdf_generate_id_bytes_from_text("ignored", fn() {
    called.val = true
    "unreached"
  })
  id_wb_restore_env_for_test(previous)
  @test.assert_eq(ordinary, @crypt_core.pdf_md5_digest(@ascii.encode("12345")))
  @test.assert_eq(current.length(), 16)
  @test.assert_eq(
    reproducible,
    @crypt_core.pdf_md5_digest(@ascii.encode("camlpdf")),
  )
  @test.assert_eq(called.val, false)
}

///|
test "private current ID copy rejects malformed trailer dictionaries" {
  let bad = pdf_document_empty()
  bad.set_trailer_dict(PdfNull)
  let result : Result[PdfDocument, Error] = try
    bad.copy_with_current_id("bad.pdf")
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard result is Err(@core.PdfError::DictionaryExpected) else {
    fail("expected @core.PdfError::DictionaryExpected")
  }
}
