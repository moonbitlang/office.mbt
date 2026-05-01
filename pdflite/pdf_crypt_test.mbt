///|
test "pdf_permissions_of_p parses CamlPDF denied permission bits" {
  @test.assert_eq(@pdflite.pdf_permissions_of_p(-4), [])
  @test.assert_eq(@pdflite.pdf_permissions_of_p(-8), [PdfNoPrint])
  @test.assert_eq(@pdflite.pdf_permissions_of_p(-3904), [
    PdfNoHqPrint,
    PdfNoAssemble,
    PdfNoExtract,
    PdfNoForms,
    PdfNoAnnot,
    PdfNoCopy,
    PdfNoEdit,
    PdfNoPrint,
  ])
}

///|
test "pdf_p_of_permissions writes signed CamlPDF permission masks" {
  @test.assert_eq(@pdflite.pdf_p_of_permissions([]), -4)
  @test.assert_eq(@pdflite.pdf_p_of_permissions([PdfNoPrint]), -8)
  @test.assert_eq(
    @pdflite.pdf_p_of_permissions([
      PdfNoEdit,
      PdfNoPrint,
      PdfNoCopy,
      PdfNoAnnot,
      PdfNoForms,
      PdfNoExtract,
      PdfNoAssemble,
      PdfNoHqPrint,
    ]),
    -3904,
  )
}

///|
test "permission masks roundtrip denied permissions" {
  let denied : Array[@pdflite.PdfPermission] = [
    PdfNoCopy,
    PdfNoExtract,
    PdfNoHqPrint,
  ]
  @test.assert_eq(
    @pdflite.pdf_permissions_of_p(@pdflite.pdf_p_of_permissions(denied)),
    [PdfNoHqPrint, PdfNoExtract, PdfNoCopy],
  )
}
