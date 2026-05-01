///|
fn tree_name_for_test(text : String) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn tree_bytes_for_test(text : String) -> @pdflite.PdfBytes {
  @ascii.encode(text)
}

///|
test "PdfDocument read_name_tree sorts and deduplicates entries" {
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(
    5,
    PdfDictionary([
      (
        tree_name_for_test("/Names"),
        PdfArray([PdfString(tree_bytes_for_test("c")), PdfInteger(4)]),
      ),
    ]),
  )
  let tree : @pdflite.PdfObject = PdfDictionary([
    (
      tree_name_for_test("/Names"),
      PdfArray([
        PdfString(tree_bytes_for_test("b")),
        PdfInteger(1),
        PdfString(tree_bytes_for_test("a")),
        PdfInteger(2),
        PdfString(tree_bytes_for_test("a")),
        PdfInteger(3),
      ]),
    ),
    (tree_name_for_test("/Kids"), PdfArray([PdfIndirect(5)])),
  ])
  @test.assert_eq(doc.read_name_tree(tree), [
    (tree_bytes_for_test("a"), PdfInteger(3)),
    (tree_bytes_for_test("b"), PdfInteger(1)),
    (tree_bytes_for_test("c"), PdfInteger(4)),
  ])
}

///|
test "PdfDocument read_name_tree ignores malformed odd name arrays" {
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(
    5,
    PdfDictionary([
      (
        tree_name_for_test("/Names"),
        PdfArray([PdfString(tree_bytes_for_test("child")), PdfInteger(9)]),
      ),
    ]),
  )
  let tree : @pdflite.PdfObject = PdfDictionary([
    (
      tree_name_for_test("/Names"),
      PdfArray([PdfString(tree_bytes_for_test("dangling"))]),
    ),
    (tree_name_for_test("/Kids"), PdfArray([PdfIndirect(5)])),
  ])
  @test.assert_eq(doc.read_name_tree(tree), [
    (tree_bytes_for_test("child"), PdfInteger(9)),
  ])
}

///|
test "PdfDocument build_name_tree creates readable child nodes" {
  let doc = @pdflite.pdf_document_empty()
  let entries : Array[(@pdflite.PdfBytes, @pdflite.PdfObject)] = [
    for i in 0..<12 => (tree_bytes_for_test("k" + i.to_string()), PdfInteger(i))
  ]
  let tree = doc.build_name_tree(entries)
  @test.assert_eq(doc.read_name_tree(tree).length(), 12)
  @test.assert_eq(
    doc.read_name_tree(tree)[0],
    (tree_bytes_for_test("k0"), PdfInteger(0)),
  )
  match tree.lookup_immediate(tree_name_for_test("/Kids")) {
    Some(PdfArray(kids)) => @test.assert_eq(kids.length(), 2)
    _ => fail("expected child name tree nodes")
  }
}

///|
test "PdfDocument build_number_tree sorts and round trips entries" {
  let doc = @pdflite.pdf_document_empty()
  let tree = doc.build_number_tree([
    (5, PdfString(tree_bytes_for_test("five"))),
    (1, PdfString(tree_bytes_for_test("one"))),
    (3, PdfString(tree_bytes_for_test("three"))),
  ])
  @test.assert_eq(doc.read_number_tree(tree), [
    (1, PdfString(tree_bytes_for_test("one"))),
    (3, PdfString(tree_bytes_for_test("three"))),
    (5, PdfString(tree_bytes_for_test("five"))),
  ])
}

///|
test "PdfDocument build empty name and number trees" {
  let doc = @pdflite.pdf_document_empty()
  @test.assert_eq(doc.read_name_tree(doc.build_name_tree([])), [])
  @test.assert_eq(doc.read_number_tree(doc.build_number_tree([])), [])
}
