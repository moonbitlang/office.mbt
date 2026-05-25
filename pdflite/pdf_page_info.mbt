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
  labels : ArrayView[PdfPageLabel],
) -> String raise PdfError {
  match pdf_page_label_text_of_page_number(page_number, labels) {
    Some(bytes) => pdf_util_string_from_utf8(pdf_utf8_of_pdfdocstring(bytes))
    None => ""
  }
}

///|
fn PdfDocument::pdf_page_info_entry(
  self : PdfDocument,
  page_number : Int,
  page : PdfPage,
  labels : ArrayView[PdfPageLabel],
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

///|
fn pdf_page_info_box_json(box : Array[Double]?) -> Json {
  match box {
    Some(values) => Json::array([ for value in values => Json::number(value) ])
    None => Json::null()
  }
}

///|
fn pdf_page_info_entry_json(entry : PdfPageInfoEntry) -> Json {
  Json::object(
    Map([
      ("Page", pdf_util_json_number(entry.page_number)),
      ("Label", Json::string(entry.label)),
      ("MediaBox", pdf_page_info_box_json(entry.mediabox)),
      ("CropBox", pdf_page_info_box_json(entry.cropbox)),
      ("BleedBox", pdf_page_info_box_json(entry.bleedbox)),
      ("TrimBox", pdf_page_info_box_json(entry.trimbox)),
      ("ArtBox", pdf_page_info_box_json(entry.artbox)),
      ("Rotation", pdf_util_json_number(entry.rotation)),
      ("Annotations", pdf_util_json_number(entry.annotations)),
    ]),
  )
}

///|
/// Return cpdf's page-info JSON array for selected 1-based page numbers.
pub fn PdfDocument::page_info_json(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  unit? : PdfUnit = PdfPoint,
) -> Json raise PdfError {
  Json::array(
    [
      for entry in self.pdf_page_info_entries(page_numbers, unit) => {
        pdf_page_info_entry_json(entry)
      }
    ],
  )
}

///|
/// Return cpdf's page-info JSON array as UTF-8 bytes.
pub fn PdfDocument::page_info_json_blob(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  unit? : PdfUnit = PdfPoint,
) -> PdfBytes raise PdfError {
  @utf8.encode(self.page_info_json(page_numbers, unit~).stringify())
}

///|
fn pdf_page_info_box_text(box : Array[Double]?) -> String {
  match box {
    Some(values) =>
      pdf_position_fixed_six(values[0]) +
      " " +
      pdf_position_fixed_six(values[1]) +
      " " +
      pdf_position_fixed_six(values[2]) +
      " " +
      pdf_position_fixed_six(values[3])
    None => ""
  }
}

///|
fn pdf_page_info_write_utf8(
  output : Array[Byte],
  position : Int,
  text : String,
) -> Int {
  let mut current = position
  for byte in @utf8.encode(text) {
    output[current] = byte
    current += 1
  }
  current
}

///|
fn pdf_page_info_write_line(
  output : Array[Byte],
  position : Int,
  key : String,
  value : String,
) -> Int {
  let mut current = pdf_page_info_write_utf8(output, position, key)
  current = pdf_page_info_write_utf8(output, current, value)
  output[current] = 10
  current + 1
}

///|
fn pdf_page_info_write_entry(
  output : Array[Byte],
  position : Int,
  entry : PdfPageInfoEntry,
) -> Int {
  let mut current = pdf_page_info_write_utf8(
    output,
    position,
    "Page " + entry.page_number.to_string() + ":\n",
  )
  current = pdf_page_info_write_line(output, current, "Label: ", entry.label)
  current = pdf_page_info_write_line(
    output,
    current,
    "MediaBox: ",
    pdf_page_info_box_text(entry.mediabox),
  )
  current = pdf_page_info_write_line(
    output,
    current,
    "CropBox: ",
    pdf_page_info_box_text(entry.cropbox),
  )
  current = pdf_page_info_write_line(
    output,
    current,
    "BleedBox: ",
    pdf_page_info_box_text(entry.bleedbox),
  )
  current = pdf_page_info_write_line(
    output,
    current,
    "TrimBox: ",
    pdf_page_info_box_text(entry.trimbox),
  )
  current = pdf_page_info_write_line(
    output,
    current,
    "ArtBox: ",
    pdf_page_info_box_text(entry.artbox),
  )
  current = pdf_page_info_write_line(
    output,
    current,
    "Rotation: ",
    entry.rotation.to_string(),
  )
  pdf_page_info_write_line(
    output,
    current,
    "Annotations: ",
    entry.annotations.to_string(),
  )
}

///|
fn pdf_page_info_utf8_length(text : String) -> Int {
  @utf8.encode(text).length()
}

///|
fn pdf_page_info_line_length(key : String, value : String) -> Int {
  pdf_page_info_utf8_length(key) + pdf_page_info_utf8_length(value) + 1
}

///|
fn pdf_page_info_entry_text_length(entry : PdfPageInfoEntry) -> Int {
  pdf_page_info_utf8_length("Page " + entry.page_number.to_string() + ":\n") +
  pdf_page_info_line_length("Label: ", entry.label) +
  pdf_page_info_line_length(
    "MediaBox: ",
    pdf_page_info_box_text(entry.mediabox),
  ) +
  pdf_page_info_line_length("CropBox: ", pdf_page_info_box_text(entry.cropbox)) +
  pdf_page_info_line_length(
    "BleedBox: ",
    pdf_page_info_box_text(entry.bleedbox),
  ) +
  pdf_page_info_line_length("TrimBox: ", pdf_page_info_box_text(entry.trimbox)) +
  pdf_page_info_line_length("ArtBox: ", pdf_page_info_box_text(entry.artbox)) +
  pdf_page_info_line_length("Rotation: ", entry.rotation.to_string()) +
  pdf_page_info_line_length("Annotations: ", entry.annotations.to_string())
}

///|
fn pdf_page_info_text_length(entries : ArrayView[PdfPageInfoEntry]) -> Int {
  let mut length = 0
  for entry in entries {
    length += pdf_page_info_entry_text_length(entry)
  }
  length
}

///|
/// Render cpdf's plain-text page-info report for selected pages.
pub fn PdfDocument::page_info_text(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  unit? : PdfUnit = PdfPoint,
) -> PdfBytes raise PdfError {
  let entries = self.pdf_page_info_entries(page_numbers, unit)
  let output = Array::make(pdf_page_info_text_length(entries), b'\x00')
  let mut position = 0
  for entry in entries {
    position = pdf_page_info_write_entry(output, position, entry)
  }
  Bytes::from_array(output)
}

///|
/// Compatibility wrapper for `PdfDocument::page_info_json`.
pub fn pdf_page_info_json(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
  unit? : PdfUnit = PdfPoint,
) -> Json raise PdfError {
  document.page_info_json(page_numbers, unit~)
}

///|
/// Compatibility wrapper matching cpdfpage's `json_page_info`.
pub fn pdf_json_page_info(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
  unit : PdfUnit,
) -> Json raise PdfError {
  document.page_info_json(page_numbers, unit~)
}

///|
/// Compatibility wrapper for `PdfDocument::page_info_json_blob`.
pub fn pdf_output_page_info_json_blob(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
  unit? : PdfUnit = PdfPoint,
) -> PdfBytes raise PdfError {
  document.page_info_json_blob(page_numbers, unit~)
}

///|
/// Return the bytes cpdfpage's `output_page_info` would print.
///
/// `raisejson` is accepted for source-shape compatibility with cpdf's internal
/// JSON exception path; this MoonBit wrapper returns JSON bytes directly when
/// `json=true`.
pub fn PdfDocument::output_page_info(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  unit? : PdfUnit = PdfPoint,
  json? : Bool = false,
  raisejson? : Bool = false,
) -> PdfBytes raise PdfError {
  ignore(raisejson)
  if json {
    self.page_info_json_blob(page_numbers, unit~)
  } else {
    self.page_info_text(page_numbers, unit~)
  }
}

///|
/// Compatibility wrapper matching cpdfpage's `output_page_info` argument order.
pub fn pdf_output_page_info(
  unit : PdfUnit,
  document : PdfDocument,
  page_numbers : ArrayView[Int],
  json? : Bool = false,
  raisejson? : Bool = false,
) -> PdfBytes raise PdfError {
  document.output_page_info(page_numbers, unit~, json~, raisejson~)
}

///|
/// Compatibility wrapper for `PdfDocument::page_info_text`.
pub fn pdf_output_page_info_text(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
  unit? : PdfUnit = PdfPoint,
) -> PdfBytes raise PdfError {
  document.page_info_text(page_numbers, unit~)
}
