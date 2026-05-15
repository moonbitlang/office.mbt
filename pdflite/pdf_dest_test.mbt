///|
fn dest_name_for_test(text : String) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn dest_bytes_for_test(text : String) -> @pdflite.PdfBytes {
  @ascii.encode(text)
}

///|
test "PdfDocument read_destination parses direct destination arrays" {
  let doc = @pdflite.pdf_document_empty()
  @test.assert_eq(
    try! doc.read_destination(
      PdfArray([
        PdfIndirect(7),
        PdfNameObject(dest_name_for_test("/XYZ")),
        PdfReal(10.0),
        PdfNull,
        PdfInteger(2),
      ]),
    ),
    DestXYZ(TargetPageObject(7), Some(10.0), None, Some(2.0)),
  )
  @test.assert_eq(
    try! doc.read_destination(
      PdfArray([
        PdfInteger(3),
        PdfNameObject(dest_name_for_test("/FitR")),
        PdfInteger(1),
        PdfInteger(2),
        PdfInteger(3),
        PdfInteger(4),
      ]),
    ),
    DestFitR(TargetOtherDocPageNumber(3), 1.0, 2.0, 3.0, 4.0),
  )
  @test.assert_eq(
    try! doc.read_destination(
      PdfArray([
        PdfIndirect(9),
        PdfNameObject(dest_name_for_test("/FitH")),
        PdfNull,
      ]),
    ),
    DestFitH(TargetPageObject(9), None),
  )
  @test.assert_eq(
    try! doc.read_destination(
      PdfArray([
        PdfIndirect(10),
        PdfNameObject(dest_name_for_test("/XYZ")),
        PdfInteger(1),
        PdfInteger(2),
      ]),
    ),
    DestXYZ(TargetPageObject(10), Some(1.0), Some(2.0), None),
  )
  @test.assert_eq(
    try! doc.read_destination(
      PdfArray([
        PdfIndirect(11),
        PdfNameObject(dest_name_for_test("/XYZ")),
        PdfInteger(3),
      ]),
    ),
    DestXYZ(TargetPageObject(11), Some(3.0), None, None),
  )
  @test.assert_eq(
    try! doc.read_destination(
      PdfArray([
        PdfIndirect(12),
        PdfNameObject(dest_name_for_test("/FitV")),
        PdfInteger(5),
      ]),
    ),
    DestFitV(TargetPageObject(12), Some(5.0)),
  )
  @test.assert_eq(
    try! doc.read_destination(
      PdfArray([
        PdfIndirect(13),
        PdfNameObject(dest_name_for_test("/FitBH")),
        PdfInteger(6),
      ]),
    ),
    DestFitBH(TargetPageObject(13), Some(6.0)),
  )
  @test.assert_eq(
    try! doc.read_destination(
      PdfArray([
        PdfIndirect(14),
        PdfNameObject(dest_name_for_test("/FitBV")),
        PdfInteger(7),
      ]),
    ),
    DestFitBV(TargetPageObject(14), Some(7.0)),
  )
  @test.assert_eq(
    try! doc.read_destination(
      PdfArray([PdfIndirect(15), PdfNameObject(dest_name_for_test("/FitB"))]),
    ),
    DestFitB(TargetPageObject(15)),
  )
  @test.assert_eq(
    try! doc.read_destination(
      PdfArray([PdfNull, PdfNameObject(dest_name_for_test("/Fit"))]),
    ),
    DestNull,
  )
  @test.assert_eq(try! doc.read_destination(PdfDictionary([])), DestNull)
  @test.assert_eq(try! doc.read_destination(PdfInteger(1)), DestNull)
}

///|
test "standalone destination helpers delegate to document methods" {
  let doc = @pdflite.pdf_document_empty()
  let destination_object : @pdflite.PdfObject = PdfArray([
    PdfIndirect(7),
    PdfNameObject(dest_name_for_test("/XYZ")),
    PdfReal(10.0),
    PdfNull,
    PdfInteger(2),
  ])
  @test.assert_eq(
    try! @pdflite.pdf_read_destination(doc, destination_object),
    try! doc.read_destination(destination_object),
  )
  @test.assert_eq(
    try! @pdflite.pdf_read_destination(doc, destination_object, shallow=true),
    try! doc.read_destination(destination_object, shallow=true),
  )
  let matrix = @pdflite.transform_translate(10.0, 20.0)
  let destination : @pdflite.PdfDestination = DestXYZ(
    TargetPageObject(7),
    Some(1.0),
    Some(2.0),
    None,
  )
  @test.assert_eq(
    try! @pdflite.pdf_transform_destination(doc, matrix, destination),
    try! doc.transform_destination(matrix, destination),
  )
}

///|
test "PdfDocument read_destination rejects malformed destination targets" {
  let doc = @pdflite.pdf_document_empty()
  @test.assert_eq(
    try! doc.read_destination(
      PdfArray([
        PdfNull,
        PdfNameObject(dest_name_for_test("/XYZ")),
        PdfInteger(1),
        PdfInteger(2),
        PdfInteger(3),
      ]),
    ),
    DestNull,
  )
  @test.assert_eq(
    try! doc.read_destination(
      PdfArray([
        PdfNull,
        PdfNameObject(dest_name_for_test("/XYZ")),
        PdfInteger(1),
        PdfInteger(2),
      ]),
    ),
    DestNull,
  )
  @test.assert_eq(
    try! doc.read_destination(
      PdfArray([
        PdfNull,
        PdfNameObject(dest_name_for_test("/XYZ")),
        PdfInteger(1),
      ]),
    ),
    DestNull,
  )
  @test.assert_eq(
    try! doc.read_destination(
      PdfArray([
        PdfNull,
        PdfNameObject(dest_name_for_test("/FitH")),
        PdfInteger(1),
      ]),
    ),
    DestNull,
  )
  @test.assert_eq(
    try! doc.read_destination(
      PdfArray([
        PdfNull,
        PdfNameObject(dest_name_for_test("/FitV")),
        PdfInteger(1),
      ]),
    ),
    DestNull,
  )
  @test.assert_eq(
    try! doc.read_destination(
      PdfArray([
        PdfNull,
        PdfNameObject(dest_name_for_test("/FitR")),
        PdfInteger(1),
        PdfInteger(2),
        PdfInteger(3),
        PdfInteger(4),
      ]),
    ),
    DestNull,
  )
  @test.assert_eq(
    try! doc.read_destination(
      PdfArray([PdfNull, PdfNameObject(dest_name_for_test("/FitB"))]),
    ),
    DestNull,
  )
  @test.assert_eq(
    try! doc.read_destination(
      PdfArray([
        PdfNull,
        PdfNameObject(dest_name_for_test("/FitBH")),
        PdfInteger(1),
      ]),
    ),
    DestNull,
  )
  @test.assert_eq(
    try! doc.read_destination(
      PdfArray([
        PdfNull,
        PdfNameObject(dest_name_for_test("/FitBV")),
        PdfInteger(1),
      ]),
    ),
    DestNull,
  )
}

///|
test "pdf_object_of_destination writes destination arrays" {
  @test.assert_eq(
    @pdflite.pdf_object_of_destination(
      DestXYZ(TargetPageObject(7), Some(10.0), None, Some(2.0)),
    ),
    PdfArray([
      PdfIndirect(7),
      PdfNameObject(dest_name_for_test("/XYZ")),
      PdfReal(10.0),
      PdfNull,
      PdfReal(2.0),
    ]),
  )
  @test.assert_eq(
    @pdflite.pdf_object_of_destination(DestFitB(TargetOtherDocPageNumber(3))),
    PdfArray([PdfInteger(3), PdfNameObject(dest_name_for_test("/FitB"))]),
  )
  @test.assert_eq(
    @pdflite.pdf_object_of_destination(DestNamed(dest_name_for_test("/Named"))),
    PdfNameObject(dest_name_for_test("/Named")),
  )
  @test.assert_eq(
    @pdflite.pdf_object_of_destination(DestString(dest_bytes_for_test("named"))),
    PdfString(dest_bytes_for_test("named")),
  )
  @test.assert_eq(
    @pdflite.pdf_object_of_destination(DestFitH(TargetPageObject(1), Some(2.0))),
    PdfArray([
      PdfIndirect(1),
      PdfNameObject(dest_name_for_test("/FitH")),
      PdfReal(2.0),
    ]),
  )
  @test.assert_eq(
    @pdflite.pdf_object_of_destination(DestFitV(TargetPageObject(1), Some(3.0))),
    PdfArray([
      PdfIndirect(1),
      PdfNameObject(dest_name_for_test("/FitV")),
      PdfReal(3.0),
    ]),
  )
  @test.assert_eq(
    @pdflite.pdf_object_of_destination(
      DestFitR(TargetPageObject(1), 2.0, 3.0, 4.0, 5.0),
    ),
    PdfArray([
      PdfIndirect(1),
      PdfNameObject(dest_name_for_test("/FitR")),
      PdfReal(2.0),
      PdfReal(3.0),
      PdfReal(4.0),
      PdfReal(5.0),
    ]),
  )
  @test.assert_eq(
    @pdflite.pdf_object_of_destination(
      DestFitBH(TargetPageObject(1), Some(6.0)),
    ),
    PdfArray([
      PdfIndirect(1),
      PdfNameObject(dest_name_for_test("/FitBH")),
      PdfReal(6.0),
    ]),
  )
  @test.assert_eq(
    @pdflite.pdf_object_of_destination(
      DestFitBV(TargetPageObject(1), Some(7.0)),
    ),
    PdfArray([
      PdfIndirect(1),
      PdfNameObject(dest_name_for_test("/FitBV")),
      PdfReal(7.0),
    ]),
  )
}

///|
test "PdfDocument read_destination follows dictionary D entry" {
  let doc = @pdflite.pdf_document_empty()
  let destination : @pdflite.PdfObject = PdfDictionary([
    (
      dest_name_for_test("/D"),
      PdfArray([PdfIndirect(7), PdfNameObject(dest_name_for_test("/Fit"))]),
    ),
  ])
  @test.assert_eq(
    try! doc.read_destination(destination),
    DestFit(TargetPageObject(7)),
  )
}

///|
test "PdfDocument read_destination resolves named catalog destinations" {
  let key_type = dest_name_for_test("/Type")
  let key_root = dest_name_for_test("/Root")
  let key_dests = dest_name_for_test("/Dests")
  let name_chapter = dest_name_for_test("/Chapter")
  let doc = @pdflite.pdf_document_empty()
  doc.set_root(1)
  doc.add_object_given_number(
    1,
    PdfDictionary([
      (key_type, PdfNameObject(dest_name_for_test("/Catalog"))),
      (
        key_dests,
        PdfDictionary([
          (
            name_chapter,
            PdfArray([PdfIndirect(8), PdfNameObject(dest_name_for_test("/Fit"))]),
          ),
        ]),
      ),
    ]),
  )
  doc.set_trailer_dict(PdfDictionary([(key_root, PdfIndirect(1))]))
  @test.assert_eq(
    try! doc.read_destination(PdfNameObject(name_chapter)),
    DestFit(TargetPageObject(8)),
  )
  @test.assert_eq(
    try! doc.read_destination(PdfNameObject(name_chapter), shallow=true),
    DestNamed(name_chapter),
  )
  @test.assert_eq(
    try! doc.read_destination(PdfNameObject(dest_name_for_test("/Missing"))),
    DestNamed(dest_name_for_test("/Missing")),
  )
  let no_root = @pdflite.pdf_document_empty()
  let result : Result[@pdflite.PdfDestination, Error] = try? no_root.read_destination(
    PdfNameObject(name_chapter),
  )
  guard result is Err(@pdflite.PdfError::RootExpected) else {
    fail("expected PdfError::RootExpected")
  }
}

///|
test "PdfDocument read_destination uses trailer root for named catalog destinations" {
  let key_type = dest_name_for_test("/Type")
  let key_root = dest_name_for_test("/Root")
  let key_dests = dest_name_for_test("/Dests")
  let name_chapter = dest_name_for_test("/Chapter")
  let doc = @pdflite.pdf_document_empty()
  doc.set_root(1)
  doc.add_object_given_number(
    1,
    PdfDictionary([
      (key_type, PdfNameObject(dest_name_for_test("/Catalog"))),
      (
        key_dests,
        PdfDictionary([
          (
            name_chapter,
            PdfArray([PdfIndirect(8), PdfNameObject(dest_name_for_test("/Fit"))]),
          ),
        ]),
      ),
    ]),
  )
  doc.add_object_given_number(
    10,
    PdfDictionary([
      (key_type, PdfNameObject(dest_name_for_test("/Catalog"))),
      (
        key_dests,
        PdfDictionary([
          (
            name_chapter,
            PdfArray([
              PdfIndirect(22),
              PdfNameObject(dest_name_for_test("/Fit")),
            ]),
          ),
        ]),
      ),
    ]),
  )
  doc.set_trailer_dict(PdfDictionary([(key_root, PdfIndirect(10))]))
  @test.assert_eq(
    try! doc.read_destination(PdfNameObject(name_chapter)),
    DestFit(TargetPageObject(22)),
  )
}

///|
test "PdfDocument read_destination falls back to document root for synthetic named destinations" {
  let key_type = dest_name_for_test("/Type")
  let key_dests = dest_name_for_test("/Dests")
  let name_chapter = dest_name_for_test("/Chapter")
  let doc = @pdflite.pdf_document_empty()
  doc.set_root(1)
  doc.add_object_given_number(
    1,
    PdfDictionary([
      (key_type, PdfNameObject(dest_name_for_test("/Catalog"))),
      (
        key_dests,
        PdfDictionary([
          (
            name_chapter,
            PdfArray([PdfIndirect(8), PdfNameObject(dest_name_for_test("/Fit"))]),
          ),
        ]),
      ),
    ]),
  )
  @test.assert_eq(
    try! doc.read_destination(PdfNameObject(name_chapter)),
    DestFit(TargetPageObject(8)),
  )
}

///|
test "PdfDocument read_destination rejects unresolved trailer root for named destinations" {
  let key_type = dest_name_for_test("/Type")
  let key_root = dest_name_for_test("/Root")
  let key_dests = dest_name_for_test("/Dests")
  let name_chapter = dest_name_for_test("/Chapter")
  let doc = @pdflite.pdf_document_empty()
  doc.set_root(1)
  doc.add_object_given_number(
    1,
    PdfDictionary([
      (key_type, PdfNameObject(dest_name_for_test("/Catalog"))),
      (
        key_dests,
        PdfDictionary([
          (
            name_chapter,
            PdfArray([PdfIndirect(8), PdfNameObject(dest_name_for_test("/Fit"))]),
          ),
        ]),
      ),
    ]),
  )
  doc.set_trailer_dict(PdfDictionary([(key_root, PdfIndirect(99))]))
  let result : Result[@pdflite.PdfDestination, Error] = try? doc.read_destination(
    PdfNameObject(name_chapter),
  )
  guard result is Err(@pdflite.PdfError::RootExpected) else {
    fail("expected PdfError::RootExpected")
  }
}

///|
test "PdfDocument read_destination resolves string name-tree destinations" {
  let key_type = dest_name_for_test("/Type")
  let key_names = dest_name_for_test("/Names")
  let key_dests = dest_name_for_test("/Dests")
  let doc = @pdflite.pdf_document_empty()
  let dest_tree = doc.build_name_tree([
    (
      dest_bytes_for_test("intro"),
      PdfArray([PdfIndirect(8), PdfNameObject(dest_name_for_test("/Fit"))]),
    ),
  ])
  doc.set_root(1)
  doc.add_object_given_number(
    1,
    PdfDictionary([
      (key_type, PdfNameObject(dest_name_for_test("/Catalog"))),
      (key_names, PdfDictionary([(key_dests, dest_tree)])),
    ]),
  )
  @test.assert_eq(
    try! doc.read_destination(PdfString(dest_bytes_for_test("intro"))),
    DestFit(TargetPageObject(8)),
  )
  @test.assert_eq(
    try! doc.read_destination(PdfString(dest_bytes_for_test("missing"))),
    DestString(dest_bytes_for_test("missing")),
  )
  @test.assert_eq(
    try! doc.read_destination(PdfString(dest_bytes_for_test("intry"))),
    DestString(dest_bytes_for_test("intry")),
  )
  @test.assert_eq(
    try! doc.read_destination(
      PdfString(dest_bytes_for_test("intro")),
      shallow=true,
    ),
    DestString(dest_bytes_for_test("intro")),
  )
  let doc = @pdflite.pdf_document_empty()
  doc.set_root(1)
  doc.add_object_given_number(
    1,
    PdfDictionary([
      (key_type, PdfNameObject(dest_name_for_test("/Catalog"))),
      (key_names, PdfDictionary([])),
    ]),
  )
  @test.assert_eq(
    try! doc.read_destination(PdfString(dest_bytes_for_test("intro"))),
    DestString(dest_bytes_for_test("intro")),
  )
}

///|
test "PdfDocument read_destination uses trailer root for string name-tree destinations" {
  let key_type = dest_name_for_test("/Type")
  let key_root = dest_name_for_test("/Root")
  let key_names = dest_name_for_test("/Names")
  let key_dests = dest_name_for_test("/Dests")
  let doc = @pdflite.pdf_document_empty()
  let stale_tree = doc.build_name_tree([
    (
      dest_bytes_for_test("intro"),
      PdfArray([PdfIndirect(8), PdfNameObject(dest_name_for_test("/Fit"))]),
    ),
  ])
  let active_tree = doc.build_name_tree([
    (
      dest_bytes_for_test("intro"),
      PdfArray([PdfIndirect(22), PdfNameObject(dest_name_for_test("/Fit"))]),
    ),
  ])
  doc.set_root(1)
  doc.add_object_given_number(
    1,
    PdfDictionary([
      (key_type, PdfNameObject(dest_name_for_test("/Catalog"))),
      (key_names, PdfDictionary([(key_dests, stale_tree)])),
    ]),
  )
  doc.add_object_given_number(
    10,
    PdfDictionary([
      (key_type, PdfNameObject(dest_name_for_test("/Catalog"))),
      (key_names, PdfDictionary([(key_dests, active_tree)])),
    ]),
  )
  doc.set_trailer_dict(PdfDictionary([(key_root, PdfIndirect(10))]))
  @test.assert_eq(
    try! doc.read_destination(PdfString(dest_bytes_for_test("intro"))),
    DestFit(TargetPageObject(22)),
  )
}

///|
test "PdfDocument read_destination rejects unresolved trailer root for string destinations" {
  let key_type = dest_name_for_test("/Type")
  let key_root = dest_name_for_test("/Root")
  let key_names = dest_name_for_test("/Names")
  let key_dests = dest_name_for_test("/Dests")
  let doc = @pdflite.pdf_document_empty()
  let dest_tree = doc.build_name_tree([
    (
      dest_bytes_for_test("intro"),
      PdfArray([PdfIndirect(8), PdfNameObject(dest_name_for_test("/Fit"))]),
    ),
  ])
  doc.set_root(1)
  doc.add_object_given_number(
    1,
    PdfDictionary([
      (key_type, PdfNameObject(dest_name_for_test("/Catalog"))),
      (key_names, PdfDictionary([(key_dests, dest_tree)])),
    ]),
  )
  doc.set_trailer_dict(PdfDictionary([(key_root, PdfIndirect(99))]))
  let result : Result[@pdflite.PdfDestination, Error] = try? doc.read_destination(
    PdfString(dest_bytes_for_test("intro")),
  )
  guard result is Err(@pdflite.PdfError::RootExpected) else {
    fail("expected PdfError::RootExpected")
  }
}

///|
test "PdfDocument transform_destination adjusts page-object coordinates" {
  let doc = @pdflite.pdf_document_empty()
  let matrix = @pdflite.transform_translate(10.0, 20.0)
  @test.assert_eq(
    try! doc.transform_destination(
      matrix,
      DestXYZ(TargetPageObject(7), Some(1.0), Some(2.0), Some(3.0)),
    ),
    DestXYZ(TargetPageObject(7), Some(11.0), Some(22.0), Some(3.0)),
  )
  @test.assert_eq(
    try! doc.transform_destination(
      matrix,
      DestXYZ(TargetPageObject(7), None, Some(2.0), Some(3.0)),
    ),
    DestXYZ(TargetPageObject(7), None, Some(22.0), Some(3.0)),
  )
  @test.assert_eq(
    try! doc.transform_destination(
      matrix,
      DestFitV(TargetPageObject(7), Some(5.0)),
    ),
    DestFitV(TargetPageObject(7), Some(15.0)),
  )
  @test.assert_eq(
    try! doc.transform_destination(
      matrix,
      DestFitH(TargetPageObject(7), Some(6.0)),
    ),
    DestFitH(TargetPageObject(7), Some(26.0)),
  )
  @test.assert_eq(
    try! doc.transform_destination(
      matrix,
      DestFitR(TargetPageObject(7), 1.0, 2.0, 3.0, 4.0),
    ),
    DestFitR(TargetPageObject(7), 11.0, 22.0, 13.0, 24.0),
  )
  @test.assert_eq(
    try! doc.transform_destination(
      matrix,
      DestFitBH(TargetPageObject(7), Some(6.0)),
    ),
    DestFitBH(TargetPageObject(7), Some(26.0)),
  )
  @test.assert_eq(
    try! doc.transform_destination(
      matrix,
      DestFitBV(TargetPageObject(7), Some(5.0)),
    ),
    DestFitBV(TargetPageObject(7), Some(15.0)),
  )
  @test.assert_eq(
    try! doc.transform_destination(
      matrix,
      DestXYZ(TargetPageObject(7), Some(5.0), None, Some(3.0)),
    ),
    DestXYZ(TargetPageObject(7), Some(15.0), None, Some(3.0)),
  )
}

///|
test "PdfDocument transform_destination clips coordinates and skips external targets" {
  let doc = @pdflite.pdf_document_empty()
  let matrix = @pdflite.transform_translate(40000.0, -40000.0)
  @test.assert_eq(
    try! doc.transform_destination(
      matrix,
      DestXYZ(TargetPageObject(7), Some(1.0), Some(2.0), None),
    ),
    DestXYZ(TargetPageObject(7), Some(32768.0), Some(-32768.0), None),
  )
  @test.assert_eq(
    try! doc.transform_destination(
      matrix,
      DestFitH(TargetOtherDocPageNumber(3), Some(6.0)),
    ),
    DestFitH(TargetOtherDocPageNumber(3), Some(6.0)),
  )
  let action : @pdflite.PdfObject = PdfDictionary([
    (dest_name_for_test("/S"), PdfNameObject(dest_name_for_test("/URI"))),
  ])
  @test.assert_eq(
    try! doc.transform_destination(matrix, DestAction(action)),
    DestAction(action),
  )
}

///|
test "PdfDocument transform_destination rewrites GoTo action D entry" {
  let doc = @pdflite.pdf_document_empty()
  let matrix = @pdflite.transform_translate(10.0, 20.0)
  let action : @pdflite.PdfObject = PdfDictionary([
    (dest_name_for_test("/S"), PdfNameObject(dest_name_for_test("/GoTo"))),
    (
      dest_name_for_test("/D"),
      PdfArray([
        PdfIndirect(7),
        PdfNameObject(dest_name_for_test("/XYZ")),
        PdfInteger(1),
        PdfInteger(2),
        PdfNull,
      ]),
    ),
  ])
  @test.assert_eq(
    try! doc.transform_destination(matrix, DestAction(action)),
    DestAction(
      try! action.add_dict_entry(
        dest_name_for_test("/D"),
        PdfArray([
          PdfIndirect(7),
          PdfNameObject(dest_name_for_test("/XYZ")),
          PdfReal(11.0),
          PdfReal(22.0),
          PdfNull,
        ]),
      ),
    ),
  )
}

///|
test "PdfDocument page_number_of_target handles destination target variants" {
  let doc = try! @pdflite.pdf_minimum_valid_pdf()
  let page_refs = try! doc.page_reference_numbers()
  @test.assert_eq(
    try! doc.page_number_of_target(DestFit(TargetOtherDocPageNumber(2))),
    3,
  )
  @test.assert_eq(
    try! doc.page_number_of_target(DestFit(TargetPageObject(999))),
    0,
  )
  let action : @pdflite.PdfObject = PdfDictionary([
    (dest_name_for_test("/S"), PdfNameObject(dest_name_for_test("/URI"))),
  ])
  @test.assert_eq(try! doc.page_number_of_target(DestAction(action)), 0)
  @test.assert_eq(
    try! doc.page_number_of_target(DestFit(TargetPageObject(page_refs[0]))),
    1,
  )
}
