///|
fn pdf_text_tounicode_preamble() -> String {
  "/CIDInit /ProcSet findresource begin\n" +
  "12 dict begin\n" +
  "begincmap\n" +
  "/CIDSystemInfo <<\n" +
  "  /Registry (Adobe)\n" +
  "  /Ordering (UCS)\n" +
  "  /Supplement 0\n" +
  ">> def\n" +
  "/CMapName /Adobe-Identity-UCS def\n" +
  "/CMapType 2 def\n" +
  "1 begincodespacerange\n" +
  "<00><FF>\n" +
  "endcodespacerange\n"
}

///|
fn pdf_text_tounicode_postamble() -> String {
  "endbfrange\n" +
  "endcmap\n" +
  "CMapName currentdict /CMap defineresource pop\n" +
  "end\n" +
  "end\n"
}

///|
fn pdf_text_tounicode_sorted(
  entries : ArrayView[(Int, PdfBytes)],
) -> Array[(Int, PdfBytes)] {
  let sorted = [ for entry in entries => entry ]
  sorted.sort_by(fn(left, right) { left.0.compare(right.0) })
  sorted
}

///|
fn pdf_text_hex_int_min2(value : Int) -> String {
  let text = value.to_string(radix=16)
  if text.length() == 1 {
    "0" + text
  } else {
    text
  }
}

///|
fn pdf_text_ascii_length(text : String) -> Int {
  @ascii.encode(text).length()
}

///|
fn pdf_text_write_ascii(
  output : Array[Byte],
  position : Int,
  text : String,
) -> Int {
  let mut current = position
  for byte in @ascii.encode(text) {
    output[current] = byte
    current += 1
  }
  current
}

///|
fn pdf_text_hex_bytes_length(bytes : BytesView) -> Int {
  bytes.length() * 2
}

///|
fn pdf_text_write_hex_bytes(
  output : Array[Byte],
  position : Int,
  bytes : BytesView,
) -> Int {
  let mut current = position
  for byte in bytes {
    let value = byte.to_int()
    output[current] = pdf_writer_hex_digit(value / 16)
    output[current + 1] = pdf_writer_hex_digit(value % 16)
    current += 2
  }
  current
}

///|
fn pdf_text_tounicode_bfrange_length(
  charcode_text : String,
  bytes : BytesView,
) -> Int {
  pdf_text_ascii_length("<") +
  pdf_text_ascii_length(charcode_text) +
  pdf_text_ascii_length("><") +
  pdf_text_ascii_length(charcode_text) +
  pdf_text_ascii_length("><") +
  pdf_text_hex_bytes_length(bytes) +
  pdf_text_ascii_length(">\n")
}

///|
fn pdf_text_write_tounicode_bfrange(
  output : Array[Byte],
  position : Int,
  charcode_text : String,
  bytes : BytesView,
) -> Int {
  let mut current = pdf_text_write_ascii(output, position, "<")
  current = pdf_text_write_ascii(output, current, charcode_text)
  current = pdf_text_write_ascii(output, current, "><")
  current = pdf_text_write_ascii(output, current, charcode_text)
  current = pdf_text_write_ascii(output, current, "><")
  current = pdf_text_write_hex_bytes(output, current, bytes)
  pdf_text_write_ascii(output, current, ">\n")
}

///|
fn pdf_text_tounicode_bytes(sorted : ArrayView[(Int, PdfBytes)]) -> PdfBytes {
  let count_text = sorted.length().to_string()
  let mut length = pdf_text_ascii_length(pdf_text_tounicode_preamble()) +
    pdf_text_ascii_length(count_text) +
    pdf_text_ascii_length(" beginbfrange\n") +
    pdf_text_ascii_length(pdf_text_tounicode_postamble())
  let mut charcode = 33
  let charcode_texts : Array[String] = Array::new(capacity=sorted.length())
  for entry in sorted {
    let charcode_text = pdf_text_hex_int_min2(charcode)
    length += pdf_text_tounicode_bfrange_length(charcode_text, entry.1)
    charcode_texts.push(charcode_text)
    charcode += 1
  }
  let output = Array::make(length, b'\x00')
  let mut position = pdf_text_write_ascii(
    output,
    0,
    pdf_text_tounicode_preamble(),
  )
  position = pdf_text_write_ascii(output, position, count_text)
  position = pdf_text_write_ascii(output, position, " beginbfrange\n")
  for index, entry in sorted {
    position = pdf_text_write_tounicode_bfrange(
      output,
      position,
      charcode_texts[index],
      entry.1,
    )
  }
  let _ = pdf_text_write_ascii(output, position, pdf_text_tounicode_postamble())
  Bytes::from_array(output)
}

///|
fn PdfDocument::pdf_text_write_tounicode(
  self : PdfDocument,
  entries : ArrayView[(Int, PdfBytes)],
) -> Int {
  let sorted = pdf_text_tounicode_sorted(entries)
  let bytes = pdf_text_tounicode_bytes(sorted)
  self.add_object(
    @syntax.pdf_stream(
      PdfDictionary([(pdf_text_length_key_name, PdfInteger(bytes.length()))]),
      StreamGot(bytes),
    ),
  )
}
