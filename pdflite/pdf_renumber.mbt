///|
pub fn PdfDocument::renumber_objects_by_offset(
  self : PdfDocument,
  offset : Int,
) -> PdfDocument raise PdfError {
  if offset < 0 {
    raise InvalidObjectNumber(offset)
  }
  let pdf = self.copy()
  if offset == 0 {
    pdf
  } else {
    let old_numbers = pdf.object_numbers()
    let changes : Array[(Int, Int)] = [
      for number in old_numbers => (number, number + offset)
    ]
    let updates : Array[(Int, PdfObjectEntry)] = []
    for number in old_numbers {
      match pdf.objects.get_entry(number) {
        Some(entry) =>
          updates.push(
            (number + offset, pdf_page_renumber_entry(entry, changes)),
          )
        None => ()
      }
    }
    for number in old_numbers {
      pdf.objects.object_map.remove(number)
    }
    for update in updates {
      let (number, entry) = update
      pdf.objects.set_entry(number, entry)
    }
    pdf.set_root(pdf_page_changed_reference(changes, pdf.root()))
    pdf.set_trailer_dict(pdf_page_renumber_object(pdf.trailer_dict(), changes))
    pdf
  }
}
