///|
fn pdf_ocg_name_array_object(names : ArrayView[PdfName]) -> PdfObject {
  PdfArray([ for name in names => PdfNameObject(name) ])
}

///|
fn pdf_ocg_indirect_array_object(numbers : ArrayView[Int]) -> PdfObject {
  PdfArray([ for number in numbers => PdfIndirect(number) ])
}

///|
fn pdf_ocg_string_array_object(strings : ArrayView[PdfBytes]) -> PdfObject {
  PdfArray([ for string in strings => PdfString(string) ])
}

///|
fn pdf_ocg_write_appdict(appdict : @ocg.PdfOcgAppDict) -> PdfObject {
  let event_name = match appdict.event {
    OcgView => pdf_ocg_view_name()
    OcgPrint => pdf_ocg_print_name()
    OcgExport => pdf_ocg_export_name()
  }
  PdfDictionary([
    (pdf_ocg_event_key(), PdfNameObject(event_name)),
    (pdf_ocg_ocgs_key(), pdf_ocg_indirect_array_object(appdict.ocgs)),
    (pdf_ocg_category_key(), pdf_ocg_name_array_object(appdict.category)),
  ])
}
