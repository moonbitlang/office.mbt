///|
fn PdfDocument::pdf_metadata_box_array_json(
  self : PdfDocument,
  box : @syntax.PdfObject,
  unit : @geometry.PdfUnit,
) -> Json? {
  match self.direct(box) {
    PdfArray(values) if values.length() == 4 => {
      let output : Array[Json] = []
      for value in values {
        let number = self.get_number(value) catch { _ => return None }
        output.push(Json::number(pdf_metadata_unit_number(number, unit)))
      }
      Some(Json::array(output))
    }
    _ => None
  }
}

///|
fn PdfDocument::pdf_metadata_page_box_json(
  self : PdfDocument,
  boxes : ArrayView[@syntax.PdfObject?],
  unit : @geometry.PdfUnit,
) -> Json {
  if boxes.length() == 0 {
    return Json::null()
  }
  let first = boxes[0]
  for index in 1..<boxes.length() {
    if boxes[index] != first {
      return Json::string("various")
    }
  }
  match first {
    Some(box) =>
      match self.pdf_metadata_box_array_json(box, unit) {
        Some(json) => json
        None => Json::null()
      }
    None => Json::null()
  }
}
