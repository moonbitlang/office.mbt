///|
fn presentation_name_for_test(text : String) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn presentation_lookup_for_test(
  object : @pdflite.PdfObject,
  key : @pdflite.PdfName,
) -> @pdflite.PdfObject? {
  object.lookup_immediate(key)
}

///|
fn presentation_document_for_test() -> @pdflite.PdfDocument {
  let key_dur = presentation_name_for_test("/Dur")
  let key_old = presentation_name_for_test("/Old")
  let first = {
    ..@page.pdf_page_blank(@pdflite.paper_a4),
    rest: PdfDictionary([(key_dur, PdfReal(99.0)), (key_old, PdfInteger(1))]),
  }
  let second = @page.pdf_page_blank(@pdflite.paper_a4)
  let document = @pdflite.pdf_document_empty()
  let root = try! document.add_pagetree([first, second])
  ignore(try! document.add_root(root, []))
  document
}

///|
fn presentation_transition_for_test(
  page : @page.PdfPage,
) -> @pdflite.PdfObject? {
  presentation_lookup_for_test(page.rest, presentation_name_for_test("/Trans"))
}

///|
test "PdfDocument presentation adds Split transition to selected pages" {
  let updated = try! presentation_document_for_test().presentation(
    [1],
    Some("Split"),
    Some(2.5),
    false,
    true,
    90,
    0.75,
  )
  let pages = try! updated.pages_of_pagetree()
  let key_trans = presentation_name_for_test("/Trans")
  let key_dur = presentation_name_for_test("/Dur")
  guard presentation_lookup_for_test(pages[0].rest, key_trans)
    is Some(PdfDictionary(trans_entries)) else {
    fail("expected transition dictionary")
  }
  let trans : @pdflite.PdfObject = PdfDictionary(trans_entries)
  @test.assert_eq(
    presentation_lookup_for_test(trans, presentation_name_for_test("/S")),
    Some(PdfNameObject(presentation_name_for_test("/Split"))),
  )
  @test.assert_eq(
    presentation_lookup_for_test(trans, presentation_name_for_test("/D")),
    Some(PdfReal(0.75)),
  )
  @test.assert_eq(
    presentation_lookup_for_test(trans, presentation_name_for_test("/Dm")),
    Some(PdfNameObject(presentation_name_for_test("/V"))),
  )
  @test.assert_eq(
    presentation_lookup_for_test(trans, presentation_name_for_test("/M")),
    Some(PdfNameObject(presentation_name_for_test("/I"))),
  )
  @test.assert_eq(
    presentation_lookup_for_test(trans, presentation_name_for_test("/Di")),
    None,
  )
  @test.assert_eq(
    presentation_lookup_for_test(pages[0].rest, key_dur),
    Some(PdfReal(2.5)),
  )
  @test.assert_eq(presentation_lookup_for_test(pages[1].rest, key_trans), None)
}

///|
test "PdfDocument presentation writes transition-specific entries" {
  let blinds_doc = try! presentation_document_for_test().presentation(
    [1],
    Some("Blinds"),
    None,
    true,
    false,
    0,
    1.0,
  )
  let blinds_pages = try! blinds_doc.pages_of_pagetree()
  guard presentation_transition_for_test(blinds_pages[0])
    is Some(PdfDictionary(blinds_entries)) else {
    fail("expected Blinds transition dictionary")
  }
  let blinds_trans : @pdflite.PdfObject = PdfDictionary(blinds_entries)
  @test.assert_eq(
    presentation_lookup_for_test(
      blinds_trans,
      presentation_name_for_test("/Dm"),
    ),
    Some(PdfNameObject(presentation_name_for_test("/H"))),
  )
  @test.assert_eq(
    presentation_lookup_for_test(blinds_trans, presentation_name_for_test("/M")),
    None,
  )
  @test.assert_eq(
    presentation_lookup_for_test(
      blinds_trans,
      presentation_name_for_test("/Di"),
    ),
    None,
  )
  let box_doc = try! presentation_document_for_test().presentation(
    [1],
    Some("Box"),
    None,
    false,
    false,
    0,
    1.0,
  )
  let box_pages = try! box_doc.pages_of_pagetree()
  guard presentation_transition_for_test(box_pages[0])
    is Some(PdfDictionary(box_entries)) else {
    fail("expected Box transition dictionary")
  }
  let box_trans : @pdflite.PdfObject = PdfDictionary(box_entries)
  @test.assert_eq(
    presentation_lookup_for_test(box_trans, presentation_name_for_test("/Dm")),
    None,
  )
  @test.assert_eq(
    presentation_lookup_for_test(box_trans, presentation_name_for_test("/M")),
    Some(PdfNameObject(presentation_name_for_test("/O"))),
  )
  @test.assert_eq(
    presentation_lookup_for_test(box_trans, presentation_name_for_test("/Di")),
    None,
  )
  let wipe_doc = try! presentation_document_for_test().presentation(
    [1],
    Some("Wipe"),
    None,
    false,
    true,
    180,
    1.0,
  )
  let wipe_pages = try! wipe_doc.pages_of_pagetree()
  guard presentation_transition_for_test(wipe_pages[0])
    is Some(PdfDictionary(wipe_entries)) else {
    fail("expected Wipe transition dictionary")
  }
  let wipe_trans : @pdflite.PdfObject = PdfDictionary(wipe_entries)
  @test.assert_eq(
    presentation_lookup_for_test(wipe_trans, presentation_name_for_test("/Dm")),
    None,
  )
  @test.assert_eq(
    presentation_lookup_for_test(wipe_trans, presentation_name_for_test("/M")),
    None,
  )
  @test.assert_eq(
    presentation_lookup_for_test(wipe_trans, presentation_name_for_test("/Di")),
    Some(PdfInteger(180)),
  )
  let dissolve_doc = try! presentation_document_for_test().presentation(
    [1],
    Some("Dissolve"),
    None,
    false,
    false,
    0,
    1.0,
  )
  let dissolve_pages = try! dissolve_doc.pages_of_pagetree()
  guard presentation_transition_for_test(dissolve_pages[0])
    is Some(PdfDictionary(dissolve_entries)) else {
    fail("expected Dissolve transition dictionary")
  }
  let dissolve_trans : @pdflite.PdfObject = PdfDictionary(dissolve_entries)
  @test.assert_eq(
    presentation_lookup_for_test(
      dissolve_trans,
      presentation_name_for_test("/S"),
    ),
    Some(PdfNameObject(presentation_name_for_test("/Dissolve"))),
  )
  @test.assert_eq(
    presentation_lookup_for_test(
      dissolve_trans,
      presentation_name_for_test("/Dm"),
    ),
    None,
  )
  @test.assert_eq(
    presentation_lookup_for_test(
      dissolve_trans,
      presentation_name_for_test("/M"),
    ),
    None,
  )
  @test.assert_eq(
    presentation_lookup_for_test(
      dissolve_trans,
      presentation_name_for_test("/Di"),
    ),
    None,
  )
}

///|
test "pdf_presentation supports direction effects and delay removal" {
  let updated = try! @pdflite.pdf_presentation(
    [1, 3],
    Some("Glitter"),
    None,
    true,
    false,
    270,
    1.25,
    presentation_document_for_test(),
  )
  let pages = try! updated.pages_of_pagetree()
  let key_trans = presentation_name_for_test("/Trans")
  let key_dur = presentation_name_for_test("/Dur")
  guard presentation_lookup_for_test(pages[0].rest, key_trans)
    is Some(PdfDictionary(trans_entries)) else {
    fail("expected transition dictionary")
  }
  let trans : @pdflite.PdfObject = PdfDictionary(trans_entries)
  @test.assert_eq(
    presentation_lookup_for_test(trans, presentation_name_for_test("/S")),
    Some(PdfNameObject(presentation_name_for_test("/Glitter"))),
  )
  @test.assert_eq(
    presentation_lookup_for_test(trans, presentation_name_for_test("/Di")),
    Some(PdfInteger(270)),
  )
  @test.assert_eq(
    presentation_lookup_for_test(trans, presentation_name_for_test("/Dm")),
    None,
  )
  @test.assert_eq(presentation_lookup_for_test(pages[0].rest, key_dur), None)
  @test.assert_eq(pages.length(), 2)
}

///|
test "pdf_presentation wrapper preserves source document" {
  let document = presentation_document_for_test()
  let updated = try! @pdflite.pdf_presentation(
    [1],
    Some("Box"),
    Some(1.5),
    true,
    false,
    0,
    0.5,
    document,
  )
  let key_trans = presentation_name_for_test("/Trans")
  let key_dur = presentation_name_for_test("/Dur")
  let updated_pages = try! updated.pages_of_pagetree()
  @test.assert_eq(
    presentation_lookup_for_test(updated_pages[0].rest, key_trans) != None,
    true,
  )
  @test.assert_eq(
    presentation_lookup_for_test(updated_pages[0].rest, key_dur),
    Some(PdfReal(1.5)),
  )
  let original_pages = try! document.pages_of_pagetree()
  @test.assert_eq(
    presentation_lookup_for_test(original_pages[0].rest, key_trans),
    None,
  )
  @test.assert_eq(
    presentation_lookup_for_test(original_pages[0].rest, key_dur),
    Some(PdfReal(99.0)),
  )
}

///|
test "PdfDocument presentation supports no transition name" {
  let updated = try! presentation_document_for_test().presentation(
    [2],
    None,
    Some(5.0),
    true,
    false,
    0,
    3.0,
  )
  let pages = try! updated.pages_of_pagetree()
  guard presentation_lookup_for_test(
      pages[1].rest,
      presentation_name_for_test("/Trans"),
    )
    is Some(PdfDictionary(trans_entries)) else {
    fail("expected transition dictionary")
  }
  let trans : @pdflite.PdfObject = PdfDictionary(trans_entries)
  @test.assert_eq(
    presentation_lookup_for_test(trans, presentation_name_for_test("/D")),
    Some(PdfReal(3.0)),
  )
  @test.assert_eq(
    presentation_lookup_for_test(trans, presentation_name_for_test("/S")),
    None,
  )
}

///|
test "PdfDocument presentation rejects unknown transition names" {
  let result : Result[@pdflite.PdfDocument, Error] = try? presentation_document_for_test().presentation(
    [1],
    Some("Zoom"),
    None,
    true,
    true,
    0,
    1.0,
  )
  guard result is Err(@pdflite.PdfError::SoftError("Unknown presentation type")) else {
    fail("expected Unknown presentation type SoftError")
  }
}
