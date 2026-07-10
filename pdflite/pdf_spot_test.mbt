///|
fn spot_name_for_test(text : String) -> @core.PdfName {
  @core.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn spot_document_for_test() -> @pdflite.PdfDocument {
  let document = @pdflite.pdf_document_empty()
  document.add_object_given_number(
    1,
    PdfArray([
      PdfNameObject(spot_name_for_test("/Separation")),
      PdfNameObject(spot_name_for_test("/Spot")),
      PdfNameObject(spot_name_for_test("/DeviceCMYK")),
      PdfNull,
    ]),
  )
  document.add_object_given_number(
    2,
    PdfNameObject(spot_name_for_test("/IndirectSpot")),
  )
  document.add_object_given_number(
    3,
    PdfArray([
      PdfNameObject(spot_name_for_test("/Separation")),
      PdfIndirect(2),
      PdfNameObject(spot_name_for_test("/DeviceGray")),
      PdfNull,
    ]),
  )
  document.add_object_given_number(
    4,
    PdfArray([
      PdfNameObject(spot_name_for_test("/DeviceN")),
      PdfArray([PdfNameObject(spot_name_for_test("/IgnoredDeviceNSpot"))]),
      PdfNameObject(spot_name_for_test("/DeviceCMYK")),
      PdfNull,
    ]),
  )
  document.add_object_given_number(
    5,
    PdfDictionary([
      (
        spot_name_for_test("/ColorSpace"),
        PdfArray([
          PdfNameObject(spot_name_for_test("/Separation")),
          PdfNameObject(spot_name_for_test("/NestedSpot")),
          PdfNameObject(spot_name_for_test("/DeviceCMYK")),
          PdfNull,
        ]),
      ),
    ]),
  )
  document.add_object_given_number(
    6,
    PdfArray([
      PdfNameObject(spot_name_for_test("/Separation")),
      PdfInteger(42),
      PdfNameObject(spot_name_for_test("/DeviceCMYK")),
      PdfNull,
    ]),
  )
  document.add_object_given_number(
    7,
    PdfArray([
      PdfNameObject(spot_name_for_test("/Separation")),
      PdfIndirect(99),
      PdfNameObject(spot_name_for_test("/DeviceCMYK")),
      PdfNull,
    ]),
  )
  document
}

///|
test "PdfDocument list_spot_colours follows cpdf top-level separation scan" {
  @test.assert_eq(spot_document_for_test().list_spot_colours(), [
    spot_name_for_test("/Spot"),
    spot_name_for_test("/IndirectSpot"),
  ])
}

///|
test "pdf_list_spot_colours wrapper returns spot colourant names" {
  @test.assert_eq(@pdflite.pdf_list_spot_colours(spot_document_for_test()), [
    spot_name_for_test("/Spot"),
    spot_name_for_test("/IndirectSpot"),
  ])
}

///|
test "pdf_list_spot_colours_blob returns cpdf stdout bytes" {
  let document = spot_document_for_test()
  let expected = b"/Spot\n/IndirectSpot\n"
  @test.assert_eq(document.list_spot_colours_blob(), expected)
  @test.assert_eq(@pdflite.pdf_list_spot_colours_blob(document), expected)
  @test.assert_eq(
    @pdflite.pdf_document_empty().list_spot_colours_blob(),
    Bytes::new(0),
  )
}
