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
