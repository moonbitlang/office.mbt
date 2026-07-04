///|
fn reference_name_for_test(text : String) -> @core.PdfName {
  @core.pdf_name_of_bytes(@ascii.encode(text))
}

///|
test "PdfDocument referenced_object_numbers follows arrays dictionaries and streams" {
  let doc = @pdflite.pdf_document_empty()
  let key_child = reference_name_for_test("/Child")
  let key_stream_child = reference_name_for_test("/StreamChild")
  let key_missing = reference_name_for_test("/Missing")
  doc.add_object_given_number(
    1,
    @syntax.pdf_dictionary([(key_child, PdfIndirect(2))]),
  )
  doc.add_object_given_number(
    2,
    @syntax.pdf_stream(
      @syntax.pdf_dictionary([(key_stream_child, PdfIndirect(3))]),
      StreamGot(try! @core.pdf_bytes_of_int_array([65])),
    ),
  )
  doc.add_object_given_number(3, PdfInteger(30))
  let start = @syntax.pdf_dictionary([
    (key_child, PdfIndirect(1)),
    (key_missing, PdfIndirect(99)),
  ])
  @test.assert_eq(doc.referenced_object_numbers(start), [1, 2, 3, 99])
}

///|
test "PdfDocument referenced_object_numbers skips requested dictionary entries" {
  let doc = @pdflite.pdf_document_empty()
  let key_keep = reference_name_for_test("/Keep")
  let key_skip = reference_name_for_test("/Skip")
  doc.add_object_given_number(1, PdfInteger(1))
  doc.add_object_given_number(2, PdfInteger(2))
  let start = @syntax.pdf_dictionary([
    (key_keep, PdfIndirect(1)),
    (key_skip, PdfIndirect(2)),
  ])
  @test.assert_eq(
    doc.referenced_object_numbers(start, no_follow_entries=[key_skip]),
    [1],
  )
}

///|
test "PdfDocument referenced_object_numbers skips indirect marker dictionaries" {
  let doc = @pdflite.pdf_document_empty()
  let key_type = reference_name_for_test("/Type")
  let key_child = reference_name_for_test("/Child")
  let type_page = reference_name_for_test("/Page")
  let type_keep = reference_name_for_test("/Keep")
  doc.add_object_given_number(
    1,
    @syntax.pdf_dictionary([
      (key_type, PdfNameObject(type_page)),
      (key_child, PdfIndirect(3)),
    ]),
  )
  doc.add_object_given_number(
    2,
    @syntax.pdf_dictionary([
      (key_type, PdfNameObject(type_keep)),
      (key_child, PdfIndirect(4)),
    ]),
  )
  doc.add_object_given_number(3, PdfInteger(3))
  doc.add_object_given_number(4, PdfInteger(4))
  @test.assert_eq(
    doc.referenced_object_numbers(PdfArray([PdfIndirect(1), PdfIndirect(2)]), no_follow_contains=[
      (key_type, PdfNameObject(type_page)),
    ]),
    [2, 4],
  )
}

///|
test "PdfDocument referenced_object_numbers handles cycles" {
  let doc = @pdflite.pdf_document_empty()
  let key_next = reference_name_for_test("/Next")
  doc.add_object_given_number(
    1,
    @syntax.pdf_dictionary([(key_next, PdfIndirect(2))]),
  )
  doc.add_object_given_number(
    2,
    @syntax.pdf_dictionary([(key_next, PdfIndirect(1))]),
  )
  @test.assert_eq(doc.referenced_object_numbers(PdfIndirect(1)), [1, 2])
}
