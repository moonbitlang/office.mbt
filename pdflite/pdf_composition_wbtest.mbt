///|
fn pdf_composition_wb_name(text : String) -> PdfName {
  pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn pdf_composition_wb_minimal_document() -> PdfDocument {
  let doc = pdf_document_empty()
  let key_type = pdf_composition_wb_name("/Type")
  let key_pages = pdf_composition_wb_name("/Pages")
  let key_kids = pdf_composition_wb_name("/Kids")
  let key_count = pdf_composition_wb_name("/Count")
  doc.add_object_given_number(
    1,
    pdf_dictionary([
      (key_type, PdfNameObject(pdf_composition_wb_name("/Catalog"))),
      (key_pages, PdfIndirect(2)),
    ]),
  )
  doc.add_object_given_number(
    2,
    pdf_dictionary([
      (key_type, PdfNameObject(pdf_composition_wb_name("/Pages"))),
      (key_kids, PdfArray([])),
      (key_count, PdfInteger(0)),
    ]),
  )
  doc.set_root(1)
  doc
}

///|
fn pdf_composition_wb_entry_bytes(
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
test "PdfDocument composition accounts xref object streams" {
  let doc = pdf_composition_wb_minimal_document()
  doc.objects.object_stream_ids[2] = 9
  let expected_xref = pdf_flate_encode(
    try! pdf_write_object(doc.lookup_object_or_null(2)),
  ).length()
  let entries = try! doc.composition(1000)
  @test.assert_eq(
    try! pdf_composition_wb_entry_bytes(entries, "XRef Table"),
    expected_xref,
  )
  @test.assert_eq(
    try! pdf_composition_wb_entry_bytes(entries, "Unclassified"),
    1000 - expected_xref,
  )
}
