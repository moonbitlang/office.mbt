// Whitebox tests for annotation and bookmark guard paths.
// Public annotation and bookmark behavior belongs in `_test.mbt` files.

///|
test "private annotation and bookmark guards report malformed roots" {
  let annotation_rest : Result[PdfObject, Error] = try? pdf_annotation_rest(
    PdfInteger(1),
  )
  guard annotation_rest is Err(PdfError::DictionaryExpected) else {
    fail("expected PdfError::DictionaryExpected")
  }
  let doc = pdf_document_empty()
  let outlines : Result[Bool, Error] = try? doc.pdf_bookmark_has_outlines()
  guard outlines is Err(PdfError::RootExpected) else {
    fail("expected PdfError::RootExpected")
  }
  let output : Array[@bookmark.PdfBookmark] = []
  let recursion : Result[Unit, Error] = try? doc.pdf_bookmark_traverse_siblings(
    0,
    PdfNull,
    false,
    output,
    10001,
  )
  guard recursion is Err(PdfError::PageTreeExpected) else {
    fail("expected PdfError::PageTreeExpected")
  }
}
