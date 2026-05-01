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
