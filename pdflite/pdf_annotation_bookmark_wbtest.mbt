// Whitebox tests for annotation and bookmark guard paths.
// Public annotation and bookmark behavior belongs in `_test.mbt` files.

///|
test "private annotation and bookmark guards report malformed roots" {
  let annotation_rest : Result[@syntax.PdfObject, Error] = try
    pdf_annotation_rest(PdfInteger(1))
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard annotation_rest is Err(@core.PdfError::DictionaryExpected) else {
    fail("expected @core.PdfError::DictionaryExpected")
  }
  let doc = pdf_document_empty()
  let outlines : Result[Bool, Error] = try
    doc.pdf_bookmark_has_outlines()
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard outlines is Err(@core.PdfError::RootExpected) else {
    fail("expected @core.PdfError::RootExpected")
  }
  let output : Array[@bookmark.PdfBookmark] = []
  let recursion : Result[Unit, Error] = try
    doc.pdf_bookmark_traverse_siblings(0, PdfNull, false, output, 10001)
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard recursion is Err(@core.PdfError::PageTreeExpected) else {
    fail("expected @core.PdfError::PageTreeExpected")
  }
}
