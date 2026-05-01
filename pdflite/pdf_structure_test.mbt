///|
fn structure_name_for_test(text : String) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(@ascii.encode(text))
}

///|
test "PdfDocument trim_structure_tree removes parents whose kids target deleted objects" {
  let key_k = structure_name_for_test("/K")
  let key_obj = structure_name_for_test("/Obj")
  let doc = @pdflite.pdf_document_empty()
  let page_root = try! doc.add_pagetree([
    @pdflite.pdf_page_blank(@pdflite.paper_a4),
    @pdflite.pdf_page_blank(@pdflite.paper_a4),
  ])
  ignore(try! doc.add_root(page_root, []))
  let page_numbers = try! doc.page_reference_numbers()
  doc.add_object_given_number(
    30,
    @pdflite.pdf_dictionary([(key_k, PdfArray([PdfIndirect(31)]))]),
  )
  doc.add_object_given_number(
    31,
    @pdflite.pdf_dictionary([
      (key_obj, PdfIndirect(page_numbers[1])),
      (key_k, PdfInteger(0)),
    ]),
  )
  try! doc.trim_structure_tree([1])
  @test.assert_eq(doc.lookup_object_or_null(30), PdfNull)
  @test.assert_eq(
    doc.lookup_object_or_null(31).lookup_immediate(key_obj),
    Some(PdfIndirect(page_numbers[1])),
  )
}
