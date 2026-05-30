///|
fn PdfDocument::pdf_metadata_box_text(
  self : PdfDocument,
  box : @syntax.PdfObject,
  unit : @geometry.PdfUnit,
) -> String {
  match self.direct(box) {
    PdfArray(values) if values.length() == 4 => {
      let a = self.get_number(values[0]) catch { _ => return "" }
      let b = self.get_number(values[1]) catch { _ => return "" }
      let c = self.get_number(values[2]) catch { _ => return "" }
      let d = self.get_number(values[3]) catch { _ => return "" }
      pdf_position_fixed_six(pdf_metadata_unit_number(a, unit)) +
      " " +
      pdf_position_fixed_six(pdf_metadata_unit_number(b, unit)) +
      " " +
      pdf_position_fixed_six(pdf_metadata_unit_number(c, unit)) +
      " " +
      pdf_position_fixed_six(pdf_metadata_unit_number(d, unit))
    }
    _ => ""
  }
}

///|
fn PdfDocument::pdf_metadata_info_box_text(
  self : PdfDocument,
  boxes : ArrayView[@syntax.PdfObject?],
  unit : @geometry.PdfUnit,
) -> String {
  if boxes.length() == 0 {
    return ""
  }
  let first = boxes[0]
  for index in 1..<boxes.length() {
    if boxes[index] != first {
      return "various"
    }
  }
  match first {
    Some(box) => self.pdf_metadata_box_text(box, unit)
    None => ""
  }
}

///|
fn PdfDocument::pdf_metadata_info_json_boxes(
  self : PdfDocument,
  pages : ArrayView[@page.PdfPage],
  unit : @geometry.PdfUnit,
  output : Map[String, Json],
) -> Unit {
  let mediaboxes : Array[@syntax.PdfObject?] = []
  let cropboxes : Array[@syntax.PdfObject?] = []
  let bleedboxes : Array[@syntax.PdfObject?] = []
  let trimboxes : Array[@syntax.PdfObject?] = []
  let artboxes : Array[@syntax.PdfObject?] = []
  for page in pages {
    mediaboxes.push(Some(page.mediabox))
    cropboxes.push(self.lookup_direct(pdf_metadata_cropbox(), page.rest))
    bleedboxes.push(self.lookup_direct(pdf_metadata_bleedbox(), page.rest))
    trimboxes.push(self.lookup_direct(pdf_metadata_trimbox(), page.rest))
    artboxes.push(self.lookup_direct(pdf_metadata_artbox(), page.rest))
  }
  output.set("MediaBox", self.pdf_metadata_page_box_json(mediaboxes, unit))
  output.set("CropBox", self.pdf_metadata_page_box_json(cropboxes, unit))
  output.set("BleedBox", self.pdf_metadata_page_box_json(bleedboxes, unit))
  output.set("TrimBox", self.pdf_metadata_page_box_json(trimboxes, unit))
  output.set("ArtBox", self.pdf_metadata_page_box_json(artboxes, unit))
}
