///|
fn merge_one_page_doc_for_test(
  major : Int,
  minor : Int,
) -> @pdflite.PdfDocument {
  let doc = try! @pdflite.pdf_minimum_valid_pdf()
  doc.set_version(major, minor)
  doc
}

///|
fn merge_bookmarked_doc_for_test(label : String) -> @pdflite.PdfDocument {
  let doc = merge_one_page_doc_for_test(1, 4)
  let page_refs = try! doc.page_reference_numbers()
  try! doc.add_bookmarks([
    {
      level: 0,
      text: @ascii.encode(label),
      target: DestFit(TargetPageObject(page_refs[0])),
      is_open: false,
      colour: @pdflite.pdf_bookmark_black,
      flags: 0,
    },
  ])
}

///|
test "pdf_merge_documents concatenates selected pages from renumbered inputs" {
  let first = merge_one_page_doc_for_test(1, 4)
  let second = merge_one_page_doc_for_test(1, 7)
  let merged = try! @pdflite.pdf_merge_documents([first, second], [[1], [1]])
  @test.assert_eq(merged.version(), (1, 7))
  @test.assert_eq(try! merged.endpage(), 2)
  let rendered = try! @pdflite.pdf_write_document(merged)
  let parsed = try! @pdflite.pdf_read_document_from_bytes(rendered)
  @test.assert_eq(parsed.version(), (1, 7))
  @test.assert_eq(try! parsed.endpage(), 2)
}

///|
test "pdf_merge_documents optionally retains merged page labels" {
  let first = try! merge_one_page_doc_for_test(1, 4).write_page_labels([
    {
      label_style: PageLabelDecimalArabic,
      label_prefix: Some(@ascii.encode("A-")),
      start_page: 1,
      start_value: 1,
    },
  ])
  let second = try! merge_one_page_doc_for_test(1, 4).write_page_labels([
    {
      label_style: PageLabelLowercaseRoman,
      label_prefix: Some(@ascii.encode("B-")),
      start_page: 1,
      start_value: 4,
    },
  ])
  let without_labels = try! @pdflite.pdf_merge_documents([first, second], [
    [1],
    [1],
  ])
  @test.assert_eq(try! without_labels.read_page_labels(), [])
  let retained = try! @pdflite.pdf_merge_documents(
    [first, second],
    [[1], [1]],
    retain_numbering=true,
  )
  @test.assert_eq(
    try! retained.read_page_labels(),
    try! @pdflite.pdf_page_label_merge([first, second], [[1], [1]]),
  )
}

///|
test "pdf_merge_documents retargets retained bookmarks to merged pages" {
  let first = merge_bookmarked_doc_for_test("A")
  let second = merge_bookmarked_doc_for_test("B")
  let merged = try! @pdflite.pdf_merge_documents([first, second], [[1], [1]])
  let bookmarks = try! merged.read_bookmarks()
  @test.assert_eq([ for bookmark in bookmarks => bookmark.text ], [
    @ascii.encode("A"),
    @ascii.encode("B"),
  ])
  @test.assert_eq(try! merged.page_number_of_target(bookmarks[0].target), 1)
  @test.assert_eq(try! merged.page_number_of_target(bookmarks[1].target), 2)
  let without_bookmarks = try! @pdflite.pdf_merge_documents(
    [first, second],
    [[1], [1]],
    retain_bookmarks=false,
  )
  @test.assert_eq(try! without_bookmarks.read_bookmarks(), [])
}

///|
test "pdf_merge_documents rejects empty and mismatched inputs" {
  let doc = merge_one_page_doc_for_test(1, 4)
  let empty : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_merge_documents(
    [],
    [],
  )
  guard empty is Err(@pdflite.PdfError::PageTreeExpected) else {
    fail("expected PageTreeExpected for empty merge")
  }
  let mismatched : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_merge_documents(
    [doc],
    [],
  )
  guard mismatched is Err(@pdflite.PdfError::PageTreeExpected) else {
    fail("expected PageTreeExpected for mismatched merge")
  }
}
