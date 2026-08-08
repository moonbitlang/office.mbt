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
/// A composite font addresses glyphs with two-byte codes, so its ToUnicode
/// CMap has to declare a two-byte codespace. A reader that finds `<00><FF>`
/// here reads the high byte of every CID as a whole character and extracts
/// nothing usable.
fn pdf_text_tounicode_cid_preamble() -> String {
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
  "<0000><FFFF>\n" +
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
  entries : ArrayView[(Int, @core.PdfBytes)],
) -> Array[(Int, @core.PdfBytes)] {
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
/// Four hex digits, the width a two-byte codespace requires. Every code in
/// a CMap must be written at its codespace's width, so a CID below 0x1000
/// still needs its leading zeros.
fn pdf_text_hex_int4(value : Int) -> String {
  let text = value.to_string(radix=16)
  match text.length() {
    1 => "000" + text
    2 => "00" + text
    3 => "0" + text
    _ => text
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
/// Assemble a ToUnicode CMap from a preamble and one already-formatted
/// charcode per entry. The two callers differ only in those: a simple font
/// numbers its codes sequentially in a one-byte codespace, a composite font
/// uses the CID itself in a two-byte one.
fn pdf_text_tounicode_bytes_with(
  sorted : ArrayView[(Int, @core.PdfBytes)],
  preamble : String,
  charcode_texts : ArrayView[String],
) -> @core.PdfBytes {
  let count_text = sorted.length().to_string()
  let mut length = pdf_text_ascii_length(preamble) +
    pdf_text_ascii_length(count_text) +
    pdf_text_ascii_length(" beginbfrange\n") +
    pdf_text_ascii_length(pdf_text_tounicode_postamble())
  for index, entry in sorted {
    length += pdf_text_tounicode_bfrange_length(charcode_texts[index], entry.1)
  }
  let output = Array::make(length, b'\x00')
  let mut position = pdf_text_write_ascii(output, 0, preamble)
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
fn pdf_text_tounicode_bytes(
  sorted : ArrayView[(Int, @core.PdfBytes)],
) -> @core.PdfBytes {
  // the simple-font embedder assigns charcodes in subset order from 33,
  // so the entry keys name codepoints rather than codes
  let charcode_texts : Array[String] = Array::new(capacity=sorted.length())
  let mut charcode = 33
  for _ in sorted {
    charcode_texts.push(pdf_text_hex_int_min2(charcode))
    charcode += 1
  }
  pdf_text_tounicode_bytes_with(
    sorted,
    pdf_text_tounicode_preamble(),
    charcode_texts,
  )
}

///|
fn pdf_text_tounicode_cid_bytes(
  sorted : ArrayView[(Int, @core.PdfBytes)],
) -> @core.PdfBytes {
  // a composite font's entry key *is* the code the content stream writes
  let charcode_texts : Array[String] = Array::new(capacity=sorted.length())
  for entry in sorted {
    charcode_texts.push(pdf_text_hex_int4(entry.0))
  }
  pdf_text_tounicode_bytes_with(
    sorted,
    pdf_text_tounicode_cid_preamble(),
    charcode_texts,
  )
}

///|
fn PdfDocument::pdf_text_write_tounicode(
  self : PdfDocument,
  entries : ArrayView[(Int, @core.PdfBytes)],
) -> Int {
  self.pdf_text_add_tounicode_stream(
    pdf_text_tounicode_bytes(pdf_text_tounicode_sorted(entries)),
  )
}

///|
/// Write a ToUnicode CMap for a composite font, keyed by the CIDs the
/// content stream actually writes.
fn PdfDocument::pdf_text_write_tounicode_cid(
  self : PdfDocument,
  entries : ArrayView[(Int, @core.PdfBytes)],
) -> Int {
  self.pdf_text_add_tounicode_stream(
    pdf_text_tounicode_cid_bytes(pdf_text_tounicode_sorted(entries)),
  )
}

///|
fn PdfDocument::pdf_text_add_tounicode_stream(
  self : PdfDocument,
  bytes : @core.PdfBytes,
) -> Int {
  self.add_object(
    @syntax.pdf_stream(
      PdfDictionary([(pdf_text_length_key_name, PdfInteger(bytes.length()))]),
      StreamGot(bytes),
    ),
  )
}
