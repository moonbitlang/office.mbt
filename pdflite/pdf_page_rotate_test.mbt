///|
fn rotate_page_for_test(
  rotate? : @pdflite.PdfPageRotation = Rotate0,
) -> @pdflite.PdfPage {
  { ..@pdflite.pdf_page_blank(@pdflite.paper_a4), rotate, }
}

///|
fn rotate_document_for_test(
  pages : ArrayView[@pdflite.PdfPage],
) -> @pdflite.PdfDocument raise @pdflite.PdfError {
  @pdflite.pdf_blank_document(100.0, 100.0, pages.length()).change_pages(pages)
}

///|
test "PdfDocument rotate_pages sets absolute page rotation" {
  let document = try! rotate_document_for_test([
    rotate_page_for_test(),
    rotate_page_for_test(rotate=Rotate90),
  ])
  let rotated = try! document.rotate_pages(-90, [1])
  let pages = try! rotated.pages_of_pagetree()
  @test.assert_eq(pages[0].rotate, Rotate270)
  @test.assert_eq(pages[1].rotate, Rotate90)
  let wrapped = try! @pdflite.pdf_rotate_pages(document, 180, [2])
  let wrapped_pages = try! wrapped.pages_of_pagetree()
  @test.assert_eq(wrapped_pages[0].rotate, Rotate0)
  @test.assert_eq(wrapped_pages[1].rotate, Rotate180)
}

///|
test "PdfDocument rotate_pages_by adds to existing page rotation" {
  let document = try! rotate_document_for_test([
    rotate_page_for_test(rotate=Rotate90),
    rotate_page_for_test(rotate=Rotate270),
  ])
  let rotated = try! @pdflite.pdf_rotate_pages_by(document, 90, [1, 2])
  let pages = try! rotated.pages_of_pagetree()
  @test.assert_eq(pages[0].rotate, Rotate180)
  @test.assert_eq(pages[1].rotate, Rotate0)
}

///|
test "PdfDocument rotate_pages validates rotation and page range" {
  let document = try! rotate_document_for_test([rotate_page_for_test()])
  let bad_rotation : Result[@pdflite.PdfDocument, Error] = try? document.rotate_pages(
    45,
    [1],
  )
  guard bad_rotation is Err(PdfError::PageRotationExpected(45)) else {
    fail("expected PageRotationExpected for non-right-angle rotation")
  }
  let bad_page : Result[@pdflite.PdfDocument, Error] = try? document.rotate_pages_by(
    90,
    [2],
  )
  guard bad_page
    is Err(
      PdfError::BadPageSpecification(
        "rotate_pages_by: range contains pages not present in pdf"
      )
    ) else {
    fail("expected rotate_pages_by to reject invalid pages")
  }
}
