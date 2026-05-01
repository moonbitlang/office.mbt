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
