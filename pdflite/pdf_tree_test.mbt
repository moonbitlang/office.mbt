///|
fn tree_name_for_test(text : String) -> @core.PdfName {
  @core.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn tree_bytes_for_test(text : String) -> @core.PdfBytes {
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
  let tree : @syntax.PdfObject = PdfDictionary([
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
  let tree : @syntax.PdfObject = PdfDictionary([
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
  let malformed_name_tree : @syntax.PdfObject = PdfDictionary([
    (tree_name_for_test("/Names"), PdfArray([PdfInteger(1), PdfInteger(2)])),
  ])
  @test.assert_eq(doc.read_name_tree(malformed_name_tree), [])
  let malformed_number_tree : @syntax.PdfObject = PdfDictionary([
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
  let entries : Array[(@core.PdfBytes, @syntax.PdfObject)] = [
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
  let entries : Array[(@core.PdfBytes, @syntax.PdfObject)] = [
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
test "PdfDocument name_tree_lookup finds nested name entries by limits" {
  let doc = @pdflite.pdf_document_empty()
  let entries : Array[(@core.PdfBytes, @syntax.PdfObject)] = [
    for i in 0..<12 => (tree_bytes_for_test("k" + i.to_string()), PdfInteger(i))
  ]
  let tree = doc.build_name_tree(entries)
  @test.assert_eq(
    doc.name_tree_lookup(tree_bytes_for_test("k0"), tree),
    Some(PdfInteger(0)),
  )
  @test.assert_eq(
    doc.name_tree_lookup(tree_bytes_for_test("k11"), tree),
    Some(PdfInteger(11)),
  )
  @test.assert_eq(
    doc.name_tree_lookup(tree_bytes_for_test("missing"), tree),
    None,
  )
  @test.assert_eq(
    doc.name_tree_lookup_object(PdfString(tree_bytes_for_test("k5")), tree),
    Some(PdfInteger(5)),
  )
}

///|
test "PdfDocument name_tree_lookup handles leaf misses and malformed trees" {
  let doc = @pdflite.pdf_document_empty()
  let leaf : @syntax.PdfObject = PdfDictionary([
    (
      tree_name_for_test("/Names"),
      PdfArray([PdfString(tree_bytes_for_test("a")), PdfInteger(1)]),
    ),
  ])
  @test.assert_eq(doc.name_tree_lookup(tree_bytes_for_test("z"), leaf), None)
  let mismatched_limits : @syntax.PdfObject = PdfDictionary([
    (
      tree_name_for_test("/Limits"),
      PdfArray([
        PdfString(tree_bytes_for_test("a")),
        PdfString(tree_bytes_for_test("z")),
      ]),
    ),
    (
      tree_name_for_test("/Names"),
      PdfArray([PdfString(tree_bytes_for_test("a")), PdfInteger(1)]),
    ),
  ])
  @test.assert_eq(
    doc.name_tree_lookup_object(PdfInteger(1), mismatched_limits),
    None,
  )
  @test.assert_eq(
    doc.name_tree_lookup_object(
      PdfString(tree_bytes_for_test("a")),
      PdfDictionary([(tree_name_for_test("/Limits"), PdfInteger(1))]),
    ),
    None,
  )
  @test.assert_eq(
    doc.name_tree_lookup_object(
      PdfString(tree_bytes_for_test("a")),
      PdfDictionary([(tree_name_for_test("/Kids"), PdfInteger(1))]),
    ),
    None,
  )
  @test.assert_eq(
    doc.name_tree_lookup_object(
      PdfString(tree_bytes_for_test("a")),
      PdfDictionary([]),
    ),
    None,
  )
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
test "PdfDocument number_tree_lookup finds nested number entries by limits" {
  let doc = @pdflite.pdf_document_empty()
  let tree = doc.build_number_tree(
    [
      for i in 0..<21 => (i * 2, PdfInteger(i))
    ],
  )
  @test.assert_eq(doc.number_tree_lookup(0, tree), Some(PdfInteger(0)))
  @test.assert_eq(doc.number_tree_lookup(40, tree), Some(PdfInteger(20)))
  @test.assert_eq(doc.number_tree_lookup(41, tree), None)
  @test.assert_eq(
    doc.name_tree_lookup_object(PdfInteger(18), tree),
    Some(PdfInteger(9)),
  )
}

///|
test "PdfDocument build_number_tree creates child limits and nested kids" {
  let doc = @pdflite.pdf_document_empty()
  let entries : Array[(Int, @syntax.PdfObject)] = [
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

///|
test "PdfDocument contents_of_name_tree returns raw name and number tree pairs" {
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(
    5,
    PdfDictionary([
      (
        tree_name_for_test("/Nums"),
        PdfArray([PdfInteger(2), PdfString(tree_bytes_for_test("two"))]),
      ),
    ]),
  )
  let tree : @syntax.PdfObject = PdfDictionary([
    (
      tree_name_for_test("/Nums"),
      PdfArray([
        PdfInteger(1),
        PdfString(tree_bytes_for_test("one")),
        PdfInteger(99),
      ]),
    ),
    (tree_name_for_test("/Kids"), PdfArray([PdfIndirect(5)])),
  ])
  @test.assert_eq(doc.contents_of_name_tree(tree), [
    (PdfInteger(1), PdfString(tree_bytes_for_test("one"))),
  ])
  @test.assert_eq(
    doc.contents_of_name_tree(
      PdfDictionary([(tree_name_for_test("/Kids"), PdfArray([PdfIndirect(5)]))]),
    ),
    [(PdfInteger(2), PdfString(tree_bytes_for_test("two")))],
  )
  @test.assert_eq(doc.contents_of_name_tree(PdfDictionary([])), [])
}

///|
test "PdfDocument merges no-clash name trees" {
  let doc = @pdflite.pdf_document_empty()
  let left = doc.build_name_tree([
    (tree_bytes_for_test("b"), PdfInteger(2)),
    (tree_bytes_for_test("a"), PdfInteger(1)),
  ])
  let right = doc.build_name_tree([
    (tree_bytes_for_test("d"), PdfInteger(4)),
    (tree_bytes_for_test("c"), PdfInteger(3)),
  ])
  let merged = doc.merge_name_trees_no_clash([left, right])
  @test.assert_eq(doc.read_name_tree(merged), [
    (tree_bytes_for_test("a"), PdfInteger(1)),
    (tree_bytes_for_test("b"), PdfInteger(2)),
    (tree_bytes_for_test("c"), PdfInteger(3)),
    (tree_bytes_for_test("d"), PdfInteger(4)),
  ])
}

///|
test "PdfDocument merges no-clash number trees" {
  let doc = @pdflite.pdf_document_empty()
  let left = doc.build_number_tree([
    (3, PdfString(tree_bytes_for_test("three"))),
    (1, PdfString(tree_bytes_for_test("one"))),
  ])
  let right = doc.build_number_tree([
    (4, PdfString(tree_bytes_for_test("four"))),
    (2, PdfString(tree_bytes_for_test("two"))),
  ])
  let merged = doc.merge_number_trees_no_clash([left, right])
  @test.assert_eq(doc.read_number_tree(merged), [
    (1, PdfString(tree_bytes_for_test("one"))),
    (2, PdfString(tree_bytes_for_test("two"))),
    (3, PdfString(tree_bytes_for_test("three"))),
    (4, PdfString(tree_bytes_for_test("four"))),
  ])
}

///|
test "pdftree top-level wrappers expose CamlPDF tree API shape" {
  let doc = @pdflite.pdf_document_empty()
  let name_tree = try! @pdflite.pdf_build_name_tree(false, doc, [
    (tree_bytes_for_test("b"), PdfInteger(2)),
    (tree_bytes_for_test("a"), PdfInteger(1)),
  ])
  @test.assert_eq(@pdflite.pdf_read_name_tree(doc, name_tree), [
    (tree_bytes_for_test("a"), PdfInteger(1)),
    (tree_bytes_for_test("b"), PdfInteger(2)),
  ])

  let number_tree = try! @pdflite.pdf_build_name_tree(true, doc, [
    (tree_bytes_for_test("10"), PdfString(tree_bytes_for_test("ten"))),
    (tree_bytes_for_test("-2"), PdfString(tree_bytes_for_test("minus-two"))),
  ])
  @test.assert_eq(@pdflite.pdf_read_number_tree(doc, number_tree), [
    (tree_bytes_for_test("-2"), PdfString(tree_bytes_for_test("minus-two"))),
    (tree_bytes_for_test("10"), PdfString(tree_bytes_for_test("ten"))),
  ])
  @test.assert_eq(doc.read_number_tree(number_tree), [
    (-2, PdfString(tree_bytes_for_test("minus-two"))),
    (10, PdfString(tree_bytes_for_test("ten"))),
  ])
  let plus_number_tree = try! @pdflite.pdf_build_name_tree(true, doc, [
    (tree_bytes_for_test("+4"), PdfInteger(4)),
  ])
  @test.assert_eq(doc.read_number_tree(plus_number_tree), [(4, PdfInteger(4))])

  let bad_number_keys : Array[String] = ["", "+", "2147483648", "not-number"]
  for key in bad_number_keys {
    let malformed_number_key = try? @pdflite.pdf_build_name_tree(true, doc, [
      (tree_bytes_for_test(key), PdfNull),
    ])
    guard malformed_number_key is Err(_) else {
      fail("expected malformed number-tree key to raise")
    }
  }
}

///|
test "pdftree top-level wrappers merge no-clash trees" {
  let doc = @pdflite.pdf_document_empty()
  let left_name = try! @pdflite.pdf_build_name_tree(false, doc, [
    (tree_bytes_for_test("a"), PdfInteger(1)),
  ])
  let right_name = try! @pdflite.pdf_build_name_tree(false, doc, [
    (tree_bytes_for_test("b"), PdfInteger(2)),
  ])
  let merged_name = @pdflite.pdf_merge_name_trees_no_clash(doc, [
    left_name, right_name,
  ])
  @test.assert_eq(@pdflite.pdf_read_name_tree(doc, merged_name), [
    (tree_bytes_for_test("a"), PdfInteger(1)),
    (tree_bytes_for_test("b"), PdfInteger(2)),
  ])

  let left_number = try! @pdflite.pdf_build_name_tree(true, doc, [
    (tree_bytes_for_test("1"), PdfString(tree_bytes_for_test("one"))),
  ])
  let right_number = try! @pdflite.pdf_build_name_tree(true, doc, [
    (tree_bytes_for_test("2"), PdfString(tree_bytes_for_test("two"))),
  ])
  let merged_number = @pdflite.pdf_merge_number_trees_no_clash(doc, [
    left_number, right_number,
  ])
  @test.assert_eq(@pdflite.pdf_read_number_tree(doc, merged_number), [
    (tree_bytes_for_test("1"), PdfString(tree_bytes_for_test("one"))),
    (tree_bytes_for_test("2"), PdfString(tree_bytes_for_test("two"))),
  ])
}
