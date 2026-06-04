///|
fn pad_name_for_test(text : String) -> @core.PdfName {
  @core.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn pad_rect_for_test(width : Double) -> @syntax.PdfObject {
  PdfArray([PdfReal(0.0), PdfReal(0.0), PdfReal(width), PdfReal(10.0)])
}

///|
fn pad_page_for_test(width : Double) -> @page.PdfPage {
  @page.pdf_page_custom(pad_rect_for_test(width))
}

///|
fn pad_doc_for_test(widths : ArrayView[Double]) -> @pdflite.PdfDocument {
  let document = try! @pdflite.pdf_blank_document(10.0, 10.0, 0)
  try! document.change_pages(
    [
      for width in widths => pad_page_for_test(width)
    ],
  )
}

///|
fn pad_widths_for_test(document : @pdflite.PdfDocument) -> Array[Double] {
  let pages = try! document.pages_of_pagetree()
  [
    for page in pages => {
      match page.mediabox {
        PdfArray([_, _, PdfReal(width), _]) => width
        _ => -1.0
      }
    }
  ]
}

///|
test "PdfDocument pad_after inserts blank pages after selected pages" {
  let key_annots = pad_name_for_test("/Annots")
  let document = pad_doc_for_test([10.0, 20.0, 30.0])
  let pages = try! document.pages_of_pagetree()
  let first_with_annots = {
    ..pages[0],
    rest: PdfDictionary([(key_annots, PdfArray([PdfInteger(1)]))]),
  }
  let document = try! document.change_pages([
    first_with_annots,
    pages[1],
    pages[2],
  ])
  let padded = try! document.pad_after([1, 3])
  @test.assert_eq(pad_widths_for_test(padded), [10.0, 10.0, 20.0, 30.0, 30.0])
  let padded_pages = try! padded.pages_of_pagetree()
  @test.assert_eq(padded_pages[1].content, [])
  @test.assert_eq(padded_pages[1].rest.lookup_immediate(key_annots), None)
}

///|
test "PdfDocument pad_before inserts blank pages before selected pages" {
  let document = pad_doc_for_test([10.0, 20.0, 30.0])
  let padded = try! document.pad_before([1, 3])
  @test.assert_eq(pad_widths_for_test(padded), [10.0, 10.0, 20.0, 30.0, 30.0])
  let pages = try! padded.pages_of_pagetree()
  @test.assert_eq(pages[0].content, [])
  @test.assert_eq(pages[3].content, [])
}

///|
test "blank padding preserves duplicate selected pages" {
  let document = pad_doc_for_test([10.0, 20.0])
  let after = try! document.pad_after([1, 1])
  @test.assert_eq(pad_widths_for_test(after), [10.0, 10.0, 10.0, 20.0])
  let before = try! document.pad_before([2, 2])
  @test.assert_eq(pad_widths_for_test(before), [10.0, 20.0, 20.0, 20.0])
}

///|
test "PdfDocument pad_after can insert another document once per selected page" {
  let document = pad_doc_for_test([10.0, 20.0])
  let pad_with = pad_doc_for_test([100.0, 200.0])
  let padded = try! document.pad_after([1], pad_with=Some(pad_with))
  @test.assert_eq(pad_widths_for_test(padded), [10.0, 100.0, 200.0, 20.0])
  let source_wrapper = try! @pdflite.pdf_padafter(
    [1],
    document,
    pad_with=Some(pad_with),
  )
  @test.assert_eq(
    pad_widths_for_test(source_wrapper),
    pad_widths_for_test(padded),
  )
}

///|
test "PdfDocument pad_before can insert another document before each unique selected page" {
  let document = pad_doc_for_test([10.0, 20.0, 30.0])
  let pad_with = pad_doc_for_test([100.0, 200.0])
  let padded = try! document.pad_before([2, 2], pad_with=Some(pad_with))
  @test.assert_eq(pad_widths_for_test(padded), [10.0, 100.0, 200.0, 20.0, 30.0])
  let wrapper = try! @pdflite.pdf_pad_before(
    document,
    [2, 2],
    pad_with=Some(pad_with),
  )
  @test.assert_eq(pad_widths_for_test(wrapper), pad_widths_for_test(padded))
  let source_wrapper = try! @pdflite.pdf_padbefore(
    [2, 2],
    document,
    pad_with=Some(pad_with),
  )
  @test.assert_eq(
    pad_widths_for_test(source_wrapper),
    pad_widths_for_test(padded),
  )
}

///|
test "PdfDocument pad_before rejects missing pages" {
  let document = pad_doc_for_test([10.0, 20.0])
  let result : Result[@pdflite.PdfDocument, Error] = try
    document.pad_before([0, 3])
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard result
    is Err(
      @core.PdfError::BadPageSpecification(
        "padbefore: range contains pages not present in pdf"
      )
    ) else {
    fail("expected padbefore range error")
  }
}

///|
test "PdfDocument pad_to_multiple appends or prepends blanks" {
  let document = pad_doc_for_test([10.0, 20.0, 30.0])
  let appended = try! document.pad_to_multiple(4)
  @test.assert_eq(pad_widths_for_test(appended), [10.0, 20.0, 30.0, 30.0])
  let prepended = try! document.pad_to_multiple(-4)
  @test.assert_eq(pad_widths_for_test(prepended), [30.0, 10.0, 20.0, 30.0])
  let source_appended = try! @pdflite.pdf_padmultiple(4, document)
  @test.assert_eq(
    pad_widths_for_test(source_appended),
    pad_widths_for_test(appended),
  )
}

///|
test "pdf_pad_to_multiple rejects zero" {
  let document = pad_doc_for_test([10.0])
  let result : Result[@pdflite.PdfDocument, Error] = try
    @pdflite.pdf_pad_to_multiple(document, 0)
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard result
    is Err(@core.PdfError::BadNumberArgument("pad_to_multiple: zero multiple")) else {
    fail("expected zero multiple error")
  }
}
