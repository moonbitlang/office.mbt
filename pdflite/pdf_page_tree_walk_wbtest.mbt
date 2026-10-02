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

///|
/// The error each extraction helper raises on `doc`'s page tree, or None
/// where it returns: tree nodes, unordered page references, parent fixup.
fn tree_walk_extract_errors(doc : PdfDocument) -> Array[@core.PdfError?] {
  let error = fn(body : () -> Unit raise @core.PdfError) -> @core.PdfError? {
    try body() catch {
      err => Some(err)
    } noraise {
      _ => None
    }
  }
  [
    error(() => ignore(doc.pdf_page_tree_nodes_not_pages())),
    error(() => ignore(doc.pdf_page_reference_numbers_unordered())),
    error(() => doc.pdf_page_fixup_parents()),
  ]
}

///|
fn tree_walk_wb_pages(kids : @syntax.PdfObject) -> @syntax.PdfObject {
  PdfDictionary([
    (pdf_page_type_key(), PdfNameObject(pdf_page_type_pages())),
    (pdf_page_kids_key(), kids),
  ])
}

///|
test "each extraction helper rejects a node that lists itself" {
  let doc = pdf_document_empty()
  let root = doc.add_object(PdfNull)
  doc.add_object_given_number(
    root,
    tree_walk_wb_pages(PdfArray([PdfIndirect(root)])),
  )
  ignore(doc.add_root(root, []))
  for error in tree_walk_extract_errors(doc) {
    assert_true(error is Some(PageTreeExpected))
  }
}

///|
test "each extraction helper rejects a tree deeper than 10,000 levels" {
  let doc = pdf_document_empty()
  let mut kid = doc.add_object(
    PdfDictionary([(pdf_page_type_key(), PdfNameObject(pdf_page_type_page()))]),
  )
  for _ in 0..<20000 {
    kid = doc.add_object(tree_walk_wb_pages(PdfArray([PdfIndirect(kid)])))
  }
  ignore(doc.add_root(kid, []))
  for error in tree_walk_extract_errors(doc) {
    assert_true(error is Some(PageTreeExpected))
  }
}

///|
test "each extraction helper rejects sharing that multiplies the tree" {
  let doc = pdf_document_empty()
  let mut kid = doc.add_object(
    PdfDictionary([(pdf_page_type_key(), PdfNameObject(pdf_page_type_page()))]),
  )
  for _ in 0..<60 {
    kid = doc.add_object(
      tree_walk_wb_pages(PdfArray([PdfIndirect(kid), PdfIndirect(kid)])),
    )
  }
  ignore(doc.add_root(kid, []))
  for error in tree_walk_extract_errors(doc) {
    assert_true(error is Some(PageTreeExpected))
  }
}

///|
test "the extraction helpers skip direct kids, so a self-listing array ends" {
  // 2 0 obj << /Type /Pages /Kids 3 0 R >>, 3 0 obj [<< /Kids 3 0 R >>]:
  // the direct node is skipped, so the walk ends at once
  let doc = pdf_document_empty()
  let root = doc.add_object(PdfNull)
  let kids = doc.add_object(PdfNull)
  doc.add_object_given_number(root, tree_walk_wb_pages(PdfIndirect(kids)))
  doc.add_object_given_number(
    kids,
    PdfArray([tree_walk_wb_pages(PdfIndirect(kids))]),
  )
  ignore(doc.add_root(root, []))
  for error in tree_walk_extract_errors(doc) {
    assert_true(error is None)
  }
  assert_eq(doc.pdf_page_tree_nodes_not_pages(), [root])
}
