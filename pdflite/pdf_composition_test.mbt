///|
fn composition_name_for_test(text : String) -> @core.PdfName {
  @core.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn composition_dictionary_for_test(
  entries : ArrayView[(@core.PdfName, @syntax.PdfObject)],
) -> @syntax.PdfObject {
  @syntax.pdf_dictionary(entries)
}

///|
fn composition_stream_for_test(
  dictionary_entries : ArrayView[(@core.PdfName, @syntax.PdfObject)],
  data : String,
) -> @syntax.PdfObject {
  @syntax.pdf_stream(
    composition_dictionary_for_test(dictionary_entries),
    StreamGot(@ascii.encode(data)),
  )
}

///|
fn composition_minimal_document_for_test() -> @pdflite.PdfDocument {
  let doc = @pdflite.pdf_document_empty()
  let key_type = composition_name_for_test("/Type")
  let key_pages = composition_name_for_test("/Pages")
  let key_kids = composition_name_for_test("/Kids")
  let key_count = composition_name_for_test("/Count")
  doc.add_object_given_number(
    1,
    composition_dictionary_for_test([
      (key_type, PdfNameObject(composition_name_for_test("/Catalog"))),
      (key_pages, PdfIndirect(2)),
    ]),
  )
  doc.add_object_given_number(
    2,
    composition_dictionary_for_test([
      (key_type, PdfNameObject(composition_name_for_test("/Pages"))),
      (key_kids, PdfArray([])),
      (key_count, PdfInteger(0)),
    ]),
  )
  doc.set_root(1)
  doc
}

///|
fn composition_sample_document_for_test() -> @pdflite.PdfDocument {
  let doc = @pdflite.pdf_document_empty()
  let key_type = composition_name_for_test("/Type")
  let key_pages = composition_name_for_test("/Pages")
  let key_kids = composition_name_for_test("/Kids")
  let key_count = composition_name_for_test("/Count")
  let key_parent = composition_name_for_test("/Parent")
  let key_contents = composition_name_for_test("/Contents")
  let key_subtype = composition_name_for_test("/Subtype")
  let key_font_descriptor = composition_name_for_test("/FontDescriptor")
  let key_struct_tree_root = composition_name_for_test("/StructTreeRoot")
  let key_pg = composition_name_for_test("/Pg")
  let key_child = composition_name_for_test("/Child")
  let key_piece_info = composition_name_for_test("/PieceInfo")
  let key_private = composition_name_for_test("/Private")
  doc.add_object_given_number(
    1,
    composition_dictionary_for_test([
      (key_type, PdfNameObject(composition_name_for_test("/Catalog"))),
      (key_pages, PdfIndirect(2)),
      (key_struct_tree_root, PdfIndirect(50)),
    ]),
  )
  doc.add_object_given_number(
    2,
    composition_dictionary_for_test([
      (key_type, PdfNameObject(composition_name_for_test("/Pages"))),
      (key_kids, PdfArray([PdfIndirect(3)])),
      (key_count, PdfInteger(1)),
    ]),
  )
  doc.add_object_given_number(
    3,
    composition_dictionary_for_test([
      (key_type, PdfNameObject(composition_name_for_test("/Page"))),
      (key_parent, PdfIndirect(2)),
      (key_contents, PdfArray([PdfIndirect(20)])),
    ]),
  )
  doc.add_object_given_number(20, composition_stream_for_test([], "BT ET"))
  doc.add_object_given_number(
    30,
    composition_stream_for_test(
      [(key_subtype, PdfNameObject(composition_name_for_test("/Image")))],
      "IMG",
    ),
  )
  doc.add_object_given_number(
    40,
    composition_dictionary_for_test([
      (key_type, PdfNameObject(composition_name_for_test("/Font"))),
      (key_font_descriptor, PdfIndirect(41)),
    ]),
  )
  doc.add_object_given_number(41, composition_dictionary_for_test([]))
  doc.add_object_given_number(
    50,
    composition_dictionary_for_test([
      (key_pg, PdfIndirect(3)),
      (key_child, PdfIndirect(51)),
    ]),
  )
  doc.add_object_given_number(51, PdfString(@ascii.encode("structure")))
  doc.add_object_given_number(
    60,
    composition_stream_for_test(
      [(key_subtype, PdfNameObject(composition_name_for_test("/Form")))],
      "q Q",
    ),
  )
  doc.add_object_given_number(61, PdfString(@ascii.encode("piece")))
  doc.add_object_given_number(
    70,
    composition_dictionary_for_test([
      (
        key_piece_info,
        composition_dictionary_for_test([(key_private, PdfIndirect(61))]),
      ),
    ]),
  )
  doc.set_root(1)
  doc
}

///|
fn composition_object_size_for_test(
  document : @pdflite.PdfDocument,
  number : Int,
) -> Int {
  (try! @pdflite.pdf_write_object(document.lookup_object_or_null(number))).length()
}

///|
fn composition_entry_bytes_for_test(
  entries : ArrayView[@composition.PdfCompositionEntry],
  label : String,
) -> Int raise {
  for entry in entries {
    if entry.label == label {
      break entry.bytes
    }
  } nobreak {
    fail("missing composition entry " + label)
    0
  }
}

///|
test "PdfDocument composition classifies cpdf object buckets" {
  let doc = composition_sample_document_for_test()
  let images = composition_object_size_for_test(doc, 30)
  let fonts = composition_object_size_for_test(doc, 40) +
    composition_object_size_for_test(doc, 41)
  let content_streams = composition_object_size_for_test(doc, 20) +
    composition_object_size_for_test(doc, 60)
  let structure_info = composition_object_size_for_test(doc, 50) +
    composition_object_size_for_test(doc, 51)
  let piece_info = composition_object_size_for_test(doc, 61)
  let xref_table = 20 * doc.object_count()
  let classified = images +
    fonts +
    content_streams +
    structure_info +
    piece_info +
    xref_table
  let file_size = classified + 123
  let entries = try! doc.composition(file_size)
  @test.assert_eq(entries.length(), 8)
  @test.assert_eq(entries[0].label, "Images")
  @test.assert_eq(
    try! composition_entry_bytes_for_test(entries, "Images"),
    images,
  )
  @test.assert_eq(
    try! composition_entry_bytes_for_test(entries, "Fonts"),
    fonts,
  )
  @test.assert_eq(
    try! composition_entry_bytes_for_test(entries, "Content streams"),
    content_streams,
  )
  @test.assert_eq(
    try! composition_entry_bytes_for_test(entries, "Structure Info"),
    structure_info,
  )
  @test.assert_eq(
    try! composition_entry_bytes_for_test(entries, "Attached Files"),
    0,
  )
  @test.assert_eq(
    try! composition_entry_bytes_for_test(entries, "XRef Table"),
    xref_table,
  )
  @test.assert_eq(
    try! composition_entry_bytes_for_test(entries, "Piece Info"),
    piece_info,
  )
  @test.assert_eq(
    try! composition_entry_bytes_for_test(entries, "Unclassified"),
    123,
  )
}

///|
test "PdfDocument composition_json_blob uses cpdf row shape" {
  let doc = composition_minimal_document_for_test()
  let expected : Json = [
    ["Images", 0, 0],
    ["Fonts", 0, 0],
    ["Content streams", 0, 0],
    ["Structure Info", 0, 0],
    ["Attached Files", 0, 0],
    ["XRef Table", 40, 40],
    ["Piece Info", 0, 0],
    ["Unclassified", 60, 60],
  ]
  @test.assert_eq(
    try! doc.composition_json_blob(100),
    @utf8.encode(expected.stringify()),
  )
  @test.assert_eq(
    try! @pdflite.pdf_show_composition_json_blob(100, doc),
    @utf8.encode(expected.stringify()),
  )
  @test.assert_eq(
    try! doc.composition_text(100),
    @ascii.encode(
      "Images: 0 bytes (0.00%)\n" +
      "Fonts: 0 bytes (0.00%)\n" +
      "Content streams: 0 bytes (0.00%)\n" +
      "Structure Info: 0 bytes (0.00%)\n" +
      "Attached Files: 0 bytes (0.00%)\n" +
      "XRef Table: 40 bytes (40.00%)\n" +
      "Piece Info: 0 bytes (0.00%)\n" +
      "Unclassified: 60 bytes (60.00%)\n",
    ),
  )
  @test.assert_eq(
    try! @pdflite.pdf_show_composition(100, false, doc),
    try! doc.composition_text(100),
  )
  @test.assert_eq(
    try! @pdflite.pdf_show_composition(100, true, doc),
    @utf8.encode(expected.stringify() + "\n"),
  )
}

///|
test "PdfDocument composition rejects non-positive file sizes" {
  let doc = composition_minimal_document_for_test()
  let result : Result[Array[@composition.PdfCompositionEntry], Error] = try
    doc.composition(0)
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard result is Err(@core.PdfError::BadNumberArgument(_)) else {
    fail("expected BadNumberArgument for zero file size")
  }
}
