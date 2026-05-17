///|
fn create_name_for_test(text : String) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn create_lookup_for_test(
  object : @pdflite.PdfObject,
  key : @pdflite.PdfName,
) -> @pdflite.PdfObject? {
  object.lookup_immediate(key)
}

///|
fn create_trailer_id_for_test(
  document : @pdflite.PdfDocument,
) -> (Bytes, Bytes)? {
  match
    create_lookup_for_test(document.trailer_dict(), create_name_for_test("/ID")) {
    Some(PdfArray([PdfString(first), PdfString(second)])) =>
      Some((first, second))
    _ => None
  }
}

///|
test "pdf_blank_document creates requested point-sized pages" {
  let document = try! @pdflite.pdf_blank_document(200.0, 100.0, 2)
  let pages = try! document.pages_of_pagetree()
  @test.assert_eq(pages.length(), 2)
  @test.assert_eq(
    pages[0].mediabox,
    PdfArray([PdfReal(0.0), PdfReal(0.0), PdfReal(200.0), PdfReal(100.0)]),
  )
  @test.assert_eq(pages[0].mediabox, pages[1].mediabox)
  guard create_trailer_id_for_test(document) is Some((first_id, second_id)) else {
    fail("expected trailer /ID array")
  }
  @test.assert_eq(first_id.length(), 16)
  @test.assert_eq(first_id, second_id)
}

///|
test "pdf_blank_document_paper creates pages from named paper size" {
  let document = try! @pdflite.pdf_blank_document_paper(@pdflite.paper_a4, 1)
  let pages = try! document.pages_of_pagetree()
  @test.assert_eq(pages.length(), 1)
  @test.assert_eq(
    pages[0].mediabox,
    @pdflite.pdf_page_blank(@pdflite.paper_a4).mediabox,
  )
  guard create_trailer_id_for_test(document) is Some((first_id, second_id)) else {
    fail("expected trailer /ID array")
  }
  @test.assert_eq(first_id.length(), 16)
  @test.assert_eq(first_id, second_id)
}

///|
test "pdf_blank_document accepts zero pages" {
  let document = try! @pdflite.pdf_blank_document(10.0, 20.0, 0)
  let pages = try! document.pages_of_pagetree()
  @test.assert_eq(pages.length(), 0)
  guard create_trailer_id_for_test(document) is Some((first_id, second_id)) else {
    fail("expected trailer /ID array")
  }
  @test.assert_eq(first_id.length(), 16)
  @test.assert_eq(first_id, second_id)
}
