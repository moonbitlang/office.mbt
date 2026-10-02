///|
test "an inherited attribute lookup up a /Parent cycle ends with an error" {
  let doc = pdf_document_empty()
  let node = doc.add_object(PdfNull)
  doc.add_object_given_number(
    node,
    PdfDictionary([(pdf_page_parent_key(), PdfIndirect(node))]),
  )
  let result : Result[@syntax.PdfObject?, Error] = try
    doc.pdf_page_find_inherited_attribute(
      doc.lookup_object_or_null(node),
      pdf_page_mediabox_key(),
      0,
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard result is Err(@core.PdfError::PageTreeExpected) else {
    fail("expected the /Parent cycle to raise")
  }
}

///|
test "fixing up parents walks a page tree that lists itself without looping" {
  let doc = pdf_document_empty()
  let root = doc.add_object(PdfNull)
  doc.add_object_given_number(
    root,
    PdfDictionary([
      (pdf_page_type_key(), PdfNameObject(pdf_page_type_pages())),
      (pdf_page_kids_key(), PdfArray([PdfIndirect(root)])),
    ]),
  )
  ignore(doc.add_root(root, []))
  let result : Result[Unit, Error] = try doc.pdf_page_fixup_parents() catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard result is Err(@core.PdfError::PageTreeExpected) else {
    fail("expected the cycle to raise")
  }
}
