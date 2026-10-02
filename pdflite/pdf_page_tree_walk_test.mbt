///|
fn tree_walk_name(text : String) -> @core.PdfName {
  @core.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn tree_walk_dict(
  entries : Array[(String, @syntax.PdfObject)],
) -> @syntax.PdfObject {
  PdfDictionary(entries.map(entry => (tree_walk_name(entry.0), entry.1)))
}

///|
fn tree_walk_pages(kids : @syntax.PdfObject) -> @syntax.PdfObject {
  tree_walk_dict([
    ("/Type", PdfNameObject(tree_walk_name("/Pages"))),
    ("/Kids", kids),
    ("/Count", PdfInteger(1)),
  ])
}

///|
/// The error `body` raises, or None when it returns.
fn[T] tree_walk_error(body : () -> T raise @core.PdfError) -> @core.PdfError? {
  try body() catch {
    error => Some(error)
  } noraise {
    _ => None
  }
}

///|
/// Every page tree walk of `doc` raises `PageTreeExpected`; with
/// `direct_kids_skipped`, `page_reference_numbers` (which skips kids that
/// are not references) just ends.
fn tree_walk_all_rejected(
  doc : @pdflite.PdfDocument,
  direct_kids_skipped? : Bool = false,
) -> Unit raise {
  assert_true(tree_walk_error(() => doc.endpage()) is Some(PageTreeExpected))
  assert_true(
    tree_walk_error(() => doc.pages_of_pagetree()) is Some(PageTreeExpected),
  )
  let references = tree_walk_error(() => doc.page_reference_numbers())
  if direct_kids_skipped {
    assert_true(references is (None | Some(PageTreeExpected)))
  } else {
    assert_true(references is Some(PageTreeExpected))
  }
  assert_true(tree_walk_error(() => doc.pdf_of_pages([1])) is Some(_))
}

///|
/// A file with a classic xref table whose page tree's root holds its
/// `/Kids` array by reference, and that array holds a direct node listing
/// the same array:
///   2 0 obj << /Type /Pages /Kids 3 0 R /Count 1 >> endobj
///   3 0 obj [<< /Type /Pages /Kids 3 0 R /Count 1 >>] endobj
fn tree_walk_self_listing_pdf() -> Bytes {
  let output : Array[Byte] = []
  reader_push_ascii(output, "%PDF-1.4\n")
  let offsets = [
    reader_push_indirect_object(
      output, 1, 0, "<< /Type /Catalog /Pages 2 0 R >>",
    ),
    reader_push_indirect_object(
      output, 2, 0, "<< /Type /Pages /Kids 3 0 R /Count 1 >>",
    ),
    reader_push_indirect_object(
      output, 3, 0, "[<< /Type /Pages /Kids 3 0 R /Count 1 >>]",
    ),
  ]
  let xref = output.length()
  reader_push_ascii(output, "xref\n0 4\n0000000000 65535 f \n")
  for offset in offsets {
    reader_push_padded_decimal(output, offset, 10)
    reader_push_ascii(output, " 00000 n \n")
  }
  reader_push_ascii(
    output,
    "trailer\n<< /Size 4 /Root 1 0 R >>\nstartxref\n\{xref}\n%%EOF\n",
  )
  Bytes::from_array(output)
}

///|
test "a /Kids array that lists a node holding the same array is rejected" {
  // read from bytes: the reader counts pages while loading
  match
    tree_walk_error(() => {
      @pdflite.pdf_read_document_from_bytes(tree_walk_self_listing_pdf())
    }) {
    Some(_) => ()
    None => {
      let doc = @pdflite.pdf_read_document_from_bytes(
        tree_walk_self_listing_pdf(),
      )
      tree_walk_all_rejected(doc, direct_kids_skipped=true)
    }
  }
  // and built in memory
  let doc = @pdflite.pdf_document_empty()
  let root = doc.add_object(PdfNull)
  let kids = doc.add_object(PdfNull)
  doc.add_object_given_number(root, tree_walk_pages(PdfIndirect(kids)))
  doc.add_object_given_number(
    kids,
    PdfArray([tree_walk_pages(PdfIndirect(kids))]),
  )
  ignore(doc.add_root(root, []))
  tree_walk_all_rejected(doc, direct_kids_skipped=true)
}

///|
test "a /Pages node that lists itself is rejected" {
  let doc = @pdflite.pdf_document_empty()
  let root = doc.add_object(PdfNull)
  doc.add_object_given_number(
    root,
    tree_walk_pages(PdfArray([PdfIndirect(root)])),
  )
  ignore(doc.add_root(root, []))
  tree_walk_all_rejected(doc)
}

///|
/// A page tree `levels` deep over one page, the root carrying the media
/// box the page inherits.
fn tree_walk_deep_doc(levels : Int) -> @pdflite.PdfDocument raise {
  let doc = @pdflite.pdf_document_empty()
  let page = doc.add_object(
    tree_walk_dict([("/Type", PdfNameObject(tree_walk_name("/Page")))]),
  )
  let mut kid = page
  for _ in 0..<levels {
    kid = doc.add_object(tree_walk_pages(PdfArray([PdfIndirect(kid)])))
  }
  doc.add_object_given_number(
    kid,
    tree_walk_dict([
      ("/Type", PdfNameObject(tree_walk_name("/Pages"))),
      ("/Kids", PdfArray([PdfIndirect(kid - 1)])),
      ("/Count", PdfInteger(1)),
      (
        "/MediaBox",
        PdfArray([PdfInteger(0), PdfInteger(0), PdfInteger(10), PdfInteger(20)]),
      ),
    ]),
  )
  ignore(doc.add_root(kid, []))
  doc
}

///|
test "a page tree 9,000 levels deep is walked without recursion" {
  let doc = tree_walk_deep_doc(9000)
  assert_eq(doc.endpage(), 1)
  assert_eq(doc.page_reference_numbers(), [1])
  let pages = doc.pages_of_pagetree()
  assert_eq(pages.length(), 1)
  assert_eq(
    pages[0].mediabox,
    PdfArray([PdfInteger(0), PdfInteger(0), PdfInteger(10), PdfInteger(20)]),
  )
}

///|
test "a page tree deeper than 10,000 levels is an error, not a crash" {
  let doc = tree_walk_deep_doc(20000)
  tree_walk_all_rejected(doc)
}

///|
test "a page shared by two parents is still counted twice" {
  let doc = @pdflite.pdf_document_empty()
  let page = doc.add_object(
    tree_walk_dict([("/Type", PdfNameObject(tree_walk_name("/Page")))]),
  )
  let root = doc.add_object(
    tree_walk_pages(PdfArray([PdfIndirect(page), PdfIndirect(page)])),
  )
  ignore(doc.add_root(root, []))
  assert_eq(doc.endpage(), 2)
  assert_eq(doc.page_reference_numbers(), [page, page])
  assert_eq(doc.pages_of_pagetree().length(), 2)
}

///|
test "sharing that multiplies the page tree is an error, not a hang" {
  // each level lists the level below twice: 2^60 leaves
  let doc = @pdflite.pdf_document_empty()
  let mut kid = doc.add_object(
    tree_walk_dict([("/Type", PdfNameObject(tree_walk_name("/Page")))]),
  )
  for _ in 0..<60 {
    kid = doc.add_object(
      tree_walk_pages(PdfArray([PdfIndirect(kid), PdfIndirect(kid)])),
    )
  }
  ignore(doc.add_root(kid, []))
  tree_walk_all_rejected(doc)
}
