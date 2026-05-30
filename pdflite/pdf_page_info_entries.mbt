///|
priv struct PdfPageInfoEntry {
  page_number : Int
  label : String
  mediabox : Array[Double]?
  cropbox : Array[Double]?
  bleedbox : Array[Double]?
  trimbox : Array[Double]?
  artbox : Array[Double]?
  rotation : Int
  annotations : Int
}

///|
fn pdf_page_info_unit_number(value : Double, unit : PdfUnit) -> Double {
  match unit {
    PdfPoint => value
    Inch => unit_inches(value, PdfPoint)
    Centimetre => unit_centimetres(value, PdfPoint)
    Millimetre => unit_millimetres(value, PdfPoint)
  }
}

///|
fn PdfDocument::pdf_page_info_box_numbers(
  self : PdfDocument,
  page : PdfPage,
  box_name : PdfName,
  unit : PdfUnit,
) -> Array[Double]? raise PdfError {
  let object = if box_name == pdf_page_mediabox_key() {
    Some(page.mediabox)
  } else {
    self.lookup_direct(box_name, page.rest)
  }
  match object {
    Some(PdfArray([a, b, c, d])) =>
      Some([
        pdf_page_info_unit_number(self.get_number(a), unit),
        pdf_page_info_unit_number(self.get_number(b), unit),
        pdf_page_info_unit_number(self.get_number(c), unit),
        pdf_page_info_unit_number(self.get_number(d), unit),
      ])
    _ => None
  }
}

///|
fn PdfDocument::pdf_page_info_annotation_count(
  self : PdfDocument,
  page : PdfPage,
) -> Int {
  match self.lookup_direct(pdf_page_annots_key(), page.rest) {
    Some(PdfArray(annotations)) => annotations.length()
    _ => 0
  }
}

///|
fn pdf_page_info_label_text(
  page_number : Int,
  labels : ArrayView[@label.PdfPageLabel],
) -> String raise PdfError {
  match @label.pdf_page_label_text_of_page_number(page_number, labels) {
    Some(bytes) => pdf_util_string_from_utf8(pdf_utf8_of_pdfdocstring(bytes))
    None => ""
  }
}

///|
fn PdfDocument::pdf_page_info_entry(
  self : PdfDocument,
  page_number : Int,
  page : PdfPage,
  labels : ArrayView[@label.PdfPageLabel],
  unit : PdfUnit,
) -> PdfPageInfoEntry raise PdfError {
  {
    page_number,
    label: pdf_page_info_label_text(page_number, labels),
    mediabox: self.pdf_page_info_box_numbers(
      page,
      pdf_page_mediabox_key(),
      unit,
    ),
    cropbox: self.pdf_page_info_box_numbers(page, pdf_page_cropbox_key(), unit),
    bleedbox: self.pdf_page_info_box_numbers(
      page,
      pdf_page_bleedbox_key(),
      unit,
    ),
    trimbox: self.pdf_page_info_box_numbers(page, pdf_page_trimbox_key(), unit),
    artbox: self.pdf_page_info_box_numbers(page, pdf_page_artbox_key(), unit),
    rotation: pdf_page_int_of_rotation(page.rotate),
    annotations: self.pdf_page_info_annotation_count(page),
  }
}

///|
fn PdfDocument::pdf_page_info_entries(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  unit : PdfUnit,
) -> Array[PdfPageInfoEntry] raise PdfError {
  let pages = self.pages_of_pagetree()
  pdf_page_box_validate_page_numbers(page_numbers, pages.length(), "page_info")
  let labels = self.read_page_labels()
  let entries : Array[PdfPageInfoEntry] = []
  for page_number in page_numbers {
    entries.push(
      self.pdf_page_info_entry(
        page_number,
        pages[page_number - 1],
        labels,
        unit,
      ),
    )
  }
  entries
}
