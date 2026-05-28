///|
fn pdf_composition_write_utf8(
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
fn pdf_composition_percent_text(percent : Double) -> String {
  let rounded = (percent * 100.0).round().to_int()
  let negative = rounded < 0
  let magnitude = if negative { -rounded } else { rounded }
  let whole = magnitude / 100
  let fraction = magnitude % 100
  let fraction_text = if fraction < 10 {
    "0" + fraction.to_string()
  } else {
    fraction.to_string()
  }
  (if negative { "-" } else { "" }) + whole.to_string() + "." + fraction_text
}

///|
fn pdf_composition_write_text_entry(
  output : Array[Byte],
  position : Int,
  entry : PdfCompositionEntry,
) -> Int {
  let mut current = pdf_composition_write_utf8(output, position, entry.label)
  current = pdf_composition_write_utf8(output, current, ": ")
  current = pdf_composition_write_utf8(output, current, entry.bytes.to_string())
  current = pdf_composition_write_utf8(output, current, " bytes (")
  current = pdf_composition_write_utf8(
    output,
    current,
    pdf_composition_percent_text(entry.percent),
  )
  pdf_composition_write_utf8(output, current, "%)\n")
}

///|
fn pdf_composition_utf8_length(text : String) -> Int {
  @utf8.encode(text).length()
}

///|
fn pdf_composition_text_entry_length(entry : PdfCompositionEntry) -> Int {
  pdf_composition_utf8_length(entry.label) +
  pdf_composition_utf8_length(": ") +
  pdf_composition_utf8_length(entry.bytes.to_string()) +
  pdf_composition_utf8_length(" bytes (") +
  pdf_composition_utf8_length(pdf_composition_percent_text(entry.percent)) +
  pdf_composition_utf8_length("%)\n")
}

///|
fn pdf_composition_text_length(entries : ArrayView[PdfCompositionEntry]) -> Int {
  let mut length = 0
  for entry in entries {
    length += pdf_composition_text_entry_length(entry)
  }
  length
}

///|
/// Return the text that cpdf's `show_composition` prints when `json=false`.
pub fn PdfDocument::composition_text(
  self : PdfDocument,
  file_size : Int,
) -> PdfBytes raise PdfError {
  let entries = self.composition(file_size)
  let output = Array::make(pdf_composition_text_length(entries), b'\x00')
  let mut position = 0
  for entry in entries {
    position = pdf_composition_write_text_entry(output, position, entry)
  }
  Bytes::from_array(output)
}

///|
fn pdf_composition_bytes_with_newline(bytes : BytesView) -> PdfBytes {
  let output = Array::make(bytes.length() + 1, b'\n')
  for i in 0..<bytes.length() {
    output[i] = bytes[i]
  }
  Bytes::from_array(output)
}
