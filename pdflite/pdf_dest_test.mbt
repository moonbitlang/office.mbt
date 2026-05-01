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
}
