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
test "PdfDocument read trees reject malformed key types" {
  let doc = @pdflite.pdf_document_empty()
  let malformed_name_tree : @pdflite.PdfObject = PdfDictionary([
    (tree_name_for_test("/Names"), PdfArray([PdfInteger(1), PdfInteger(2)])),
  ])
  @test.assert_eq(doc.read_name_tree(malformed_name_tree), [])
  let malformed_number_tree : @pdflite.PdfObject = PdfDictionary([
    (
      tree_name_for_test("/Nums"),
      PdfArray([PdfString(tree_bytes_for_test("bad")), PdfInteger(2)]),
    ),
  ])
  @test.assert_eq(doc.read_number_tree(malformed_number_tree), [])
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
test "PdfDocument build_name_tree creates nested child limits for large trees" {
  let doc = @pdflite.pdf_document_empty()
  let entries : Array[(@pdflite.PdfBytes, @pdflite.PdfObject)] = [
    for i in 0..<101 => {
      (tree_bytes_for_test("k" + i.to_string()), PdfInteger(i))
    }
  ]
  let tree = doc.build_name_tree(entries)
  @test.assert_eq(doc.read_name_tree(tree).length(), 101)
  guard tree.lookup_immediate(tree_name_for_test("/Kids"))
    is Some(PdfArray(kids)) else {
    fail("expected child name tree nodes")
  }
  @test.assert_eq(kids.length(), 10)
  guard kids[kids.length() - 1] is PdfIndirect(last_child_number) else {
    fail("expected indirect child")
  }
  let last_child = doc.lookup_object_or_null(last_child_number)
  guard last_child.lookup_immediate(tree_name_for_test("/Limits"))
    is Some(PdfArray([PdfString(_), PdfString(_)])) else {
    fail("expected child limits")
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
  let deduped = doc.read_number_tree(
    PdfDictionary([
      (
        tree_name_for_test("/Nums"),
        PdfArray([
          PdfInteger(2),
          PdfString(tree_bytes_for_test("old")),
          PdfInteger(1),
          PdfString(tree_bytes_for_test("one")),
          PdfInteger(2),
          PdfString(tree_bytes_for_test("new")),
        ]),
      ),
    ]),
  )
  @test.assert_eq(deduped, [
    (1, PdfString(tree_bytes_for_test("one"))),
    (2, PdfString(tree_bytes_for_test("new"))),
  ])
}

///|
test "PdfDocument build_number_tree creates child limits and nested kids" {
  let doc = @pdflite.pdf_document_empty()
  let entries : Array[(Int, @pdflite.PdfObject)] = [
    for i in 0..<101 => (i, PdfInteger(i))
  ]
  let tree = doc.build_number_tree(entries)
  @test.assert_eq(doc.read_number_tree(tree).length(), 101)
  guard tree.lookup_immediate(tree_name_for_test("/Kids"))
    is Some(PdfArray(kids)) else {
    fail("expected child number tree nodes")
  }
  @test.assert_eq(kids.length(), 10)
  guard kids[0] is PdfIndirect(first_child_number) else {
    fail("expected indirect child")
  }
  let first_child = doc.lookup_object_or_null(first_child_number)
  guard first_child.lookup_immediate(tree_name_for_test("/Limits"))
    is Some(PdfArray([PdfInteger(0), PdfInteger(9)])) else {
    fail("expected child limits")
  }
  guard kids[kids.length() - 1] is PdfIndirect(last_child_number) else {
    fail("expected indirect child")
  }
  let last_child = doc.lookup_object_or_null(last_child_number)
  guard last_child.lookup_immediate(tree_name_for_test("/Kids"))
    is Some(PdfArray(nested_kids)) else {
    fail("expected nested number-tree kids")
  }
  @test.assert_eq(nested_kids.length() > 0, true)
}

///|
test "PdfDocument build empty name and number trees" {
  let doc = @pdflite.pdf_document_empty()
  @test.assert_eq(doc.read_name_tree(doc.build_name_tree([])), [])
  @test.assert_eq(doc.read_number_tree(doc.build_number_tree([])), [])
}
