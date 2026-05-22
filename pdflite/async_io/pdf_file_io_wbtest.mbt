///|
async fn pdf_async_io_remove_if_exists_for_test(path : String) -> Unit {
  if @fs.exists(path) {
    @fs.remove(path)
  }
}

///|
fn pdf_async_io_assert_generated_id_for_test(
  id : @pdflite.PdfObject?,
) -> Unit raise {
  guard id is Some(PdfArray([PdfString(first), PdfString(second)])) else {
    fail("expected generated trailer ID")
  }
  @test.assert_eq(first.length(), 16)
  @test.assert_eq(second, first)
}

///|
fn pdf_async_io_test_path_for_test(name : String) -> String {
  let directory = match @env.current_dir() {
    Some(current_dir) => current_dir + "/_build/"
    None => "_build/"
  }
  directory + "pdflite_async_io_" + name + "_" + @env.now().to_string() + ".pdf"
}

///|
fn pdf_async_io_repo_path_for_test(path : String) -> String {
  match @env.current_dir() {
    Some(current_dir) => current_dir + "/" + path
    None => path
  }
}

///|
fn pdf_async_io_build_dir_for_test() -> String {
  match @env.current_dir() {
    Some(current_dir) => current_dir + "/_build"
    None => "_build"
  }
}

///|
fn pdf_async_io_basename_for_test(path : String) -> String {
  let mut start = 0
  for index in 0..<path.length() {
    let value = path.at(index).to_int()
    if value == 47 || value == 92 {
      start = index + 1
    }
  }
  path[start:].to_owned()
}

///|
fn pdf_async_io_bytes_for_test(values : ArrayView[Int]) -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  for value in values {
    output.push(try! @pdflite.pdf_byte_of_int(value))
  }
  Bytes::from_array(output)
}

///|
fn pdf_async_io_append_bytes_for_test(
  output : Array[Byte],
  bytes : BytesView,
) -> Unit {
  for byte in bytes {
    output.push(byte)
  }
}

///|
fn pdf_async_io_push_u32_for_test(output : Array[Byte], value : Int) -> Unit {
  output.push(try! @pdflite.pdf_byte_of_int((value >> 24) & 0xFF))
  output.push(try! @pdflite.pdf_byte_of_int((value >> 16) & 0xFF))
  output.push(try! @pdflite.pdf_byte_of_int((value >> 8) & 0xFF))
  output.push(try! @pdflite.pdf_byte_of_int(value & 0xFF))
}

///|
fn pdf_async_io_png_chunk_for_test(
  chunk_type : ArrayView[Int],
  data : BytesView,
) -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  pdf_async_io_push_u32_for_test(output, data.length())
  for value in chunk_type {
    output.push(try! @pdflite.pdf_byte_of_int(value))
  }
  pdf_async_io_append_bytes_for_test(output, data)
  pdf_async_io_push_u32_for_test(output, 0)
  Bytes::from_array(output)
}

///|
fn pdf_async_io_png_rgb_for_test() -> (@pdflite.PdfBytes, @pdflite.PdfBytes) {
  let header = pdf_async_io_bytes_for_test([
    0, 0, 0, 2, 0, 0, 0, 1, 8, 2, 0, 0, 0,
  ])
  let idat = @pdflite.pdf_flate_encode(
    pdf_async_io_bytes_for_test([0, 10, 20, 30, 40, 50, 60]),
  )
  let output : Array[Byte] = []
  for value in [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A] {
    output.push(try! @pdflite.pdf_byte_of_int(value))
  }
  pdf_async_io_append_bytes_for_test(
    output,
    pdf_async_io_png_chunk_for_test([0x49, 0x48, 0x44, 0x52], header),
  )
  pdf_async_io_append_bytes_for_test(
    output,
    pdf_async_io_png_chunk_for_test([0x49, 0x44, 0x41, 0x54], idat),
  )
  pdf_async_io_append_bytes_for_test(
    output,
    pdf_async_io_png_chunk_for_test([0x49, 0x45, 0x4E, 0x44], []),
  )
  (Bytes::from_array(output), idat)
}

///|
fn pdf_async_io_jpeg_for_test() -> @pdflite.PdfBytes {
  pdf_async_io_bytes_for_test([
    0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x09, 0x4A, 0x46, 0x49, 0x46, 0x00, 0xAA, 0xBB,
    0xFF, 0xC0, 0x00, 0x0B, 0x08, 0x01, 0x2C, 0x01, 0x90, 0x03, 0x01, 0xFF, 0xD9,
  ])
}

///|
fn pdf_async_io_jpeg2000_for_test() -> @pdflite.PdfBytes {
  pdf_async_io_bytes_for_test([
    0x00, 0x00, 0x00, 0x0C, 0x6A, 0x50, 0x20, 0x20, 0x0D, 0x0A, 0x87, 0x0A, 0x69,
    0x68, 0x64, 0x72, 0x00, 0x00, 0x01, 0x2C, 0x00, 0x00, 0x01, 0x90,
  ])
}

///|
fn pdf_async_io_bytes_start_with_at_for_test(
  haystack : BytesView,
  needle : BytesView,
  start : Int,
) -> Bool {
  if start < 0 || start + needle.length() > haystack.length() {
    false
  } else {
    for index in 0..<needle.length() {
      if haystack[start + index] != needle[index] {
        break false
      }
    } nobreak {
      true
    }
  }
}

///|
fn pdf_async_io_find_bytes_for_test(
  haystack : BytesView,
  needle : BytesView,
) -> Int {
  if needle.length() == 0 {
    0
  } else if haystack.length() < needle.length() {
    -1
  } else {
    for start in 0..<=(haystack.length() - needle.length()) {
      if pdf_async_io_bytes_start_with_at_for_test(haystack, needle, start) {
        break start
      }
    } nobreak {
      -1
    }
  }
}

///|
fn pdf_async_io_find_last_bytes_for_test(
  haystack : BytesView,
  needle : BytesView,
) -> Int {
  if needle.length() == 0 {
    0
  } else if haystack.length() < needle.length() {
    -1
  } else {
    let mut found = -1
    for start in 0..<=(haystack.length() - needle.length()) {
      if pdf_async_io_bytes_start_with_at_for_test(haystack, needle, start) {
        found = start
      }
    }
    found
  }
}

///|
fn pdf_async_io_push_ascii_for_test(
  output : Array[Byte],
  text : String,
) -> Unit {
  for byte in @ascii.encode(text) {
    output.push(byte)
  }
}

///|
fn pdf_async_io_push_padded_decimal_for_test(
  output : Array[Byte],
  value : Int,
  width : Int,
) -> Unit {
  let text = value.to_string()
  if text.length() < width {
    for _ in 0..<(width - text.length()) {
      output.push(b'0')
    }
  }
  pdf_async_io_push_ascii_for_test(output, text)
}

///|
fn pdf_async_io_is_pdf_whitespace_for_test(byte : Byte) -> Bool {
  match byte.to_int() {
    0 | 9 | 10 | 12 | 13 | 32 => true
    _ => false
  }
}

///|
fn pdf_async_io_corrupt_startxref_pointer_at_for_test(
  bytes : @pdflite.PdfBytes,
  marker_position : Int,
) -> @pdflite.PdfBytes raise {
  let marker = @ascii.encode("startxref")
  if marker_position < 0 {
    fail("expected startxref marker")
  }
  let mut number_start = marker_position + marker.length()
  while number_start < bytes.length() &&
        pdf_async_io_is_pdf_whitespace_for_test(bytes[number_start]) {
    number_start += 1
  }
  let mut number_end = number_start
  while number_end < bytes.length() &&
        !pdf_async_io_is_pdf_whitespace_for_test(bytes[number_end]) {
    number_end += 1
  }
  let output : Array[Byte] = []
  for index in 0..<number_start {
    output.push(bytes[index])
  }
  pdf_async_io_push_ascii_for_test(output, (bytes.length() + 4096).to_string())
  for index in number_end..<bytes.length() {
    output.push(bytes[index])
  }
  Bytes::from_array(output)
}

///|
fn pdf_async_io_corrupt_first_in_use_xref_offset_for_test(
  bytes : @pdflite.PdfBytes,
) -> @pdflite.PdfBytes raise {
  let free_row = @ascii.encode("0000000000 65535 f \n")
  let free_row_position = pdf_async_io_find_bytes_for_test(bytes, free_row)
  if free_row_position < 0 {
    fail("expected classic xref free row")
  }
  let row_start = free_row_position + free_row.length()
  if row_start + 10 > bytes.length() {
    fail("expected first in-use xref row")
  }
  let output : Array[Byte] = []
  for byte in bytes {
    output.push(byte)
  }
  for index in row_start..<(row_start + 10) {
    output[index] = (57).to_byte()
  }
  Bytes::from_array(output)
}

///|
fn pdf_async_io_corrupt_first_in_use_xref_marker_for_test(
  bytes : @pdflite.PdfBytes,
) -> @pdflite.PdfBytes raise {
  let free_row = @ascii.encode("0000000000 65535 f \n")
  let free_row_position = pdf_async_io_find_bytes_for_test(bytes, free_row)
  if free_row_position < 0 {
    fail("expected classic xref free row")
  }
  let marker_position = free_row_position + free_row.length() + 17
  if marker_position >= bytes.length() {
    fail("expected first in-use xref marker")
  }
  let output : Array[Byte] = []
  for byte in bytes {
    output.push(byte)
  }
  output[marker_position] = b'x'
  Bytes::from_array(output)
}

///|
fn pdf_async_io_mark_classic_xref_entry_free_for_test(
  bytes : @pdflite.PdfBytes,
  object_number : Int,
) -> @pdflite.PdfBytes raise {
  if object_number < 0 {
    fail("expected non-negative classic xref object number")
  }
  let header = @ascii.encode("xref\n0 ")
  let header_position = pdf_async_io_find_bytes_for_test(bytes, header)
  if header_position < 0 {
    fail("expected first classic xref subsection header")
  }
  let mut header_end = header_position + header.length()
  while header_end < bytes.length() && bytes[header_end] != b'\n' {
    header_end += 1
  }
  let row_start = header_end + 1 + object_number * 20
  let marker_position = row_start + 17
  if marker_position >= bytes.length() || bytes[marker_position] != b'n' {
    fail("expected in-use classic xref entry")
  }
  let output : Array[Byte] = []
  for byte in bytes {
    output.push(byte)
  }
  output[marker_position] = b'f'
  Bytes::from_array(output)
}

///|
fn pdf_async_io_parse_positive_decimal_for_test(
  bytes : BytesView,
  start : Int,
  end : Int,
) -> Int raise {
  if start >= end {
    fail("expected decimal digits")
  }
  let mut value = 0
  for index in start..<end {
    let byte = bytes[index].to_int()
    if byte < 48 || byte > 57 {
      fail("expected decimal digit")
    }
    value = value * 10 + byte - 48
  }
  value
}

///|
fn pdf_async_io_keep_catalog_and_encrypt_xref_entries_for_test(
  bytes : @pdflite.PdfBytes,
  encrypt_object_number : Int,
) -> @pdflite.PdfBytes raise {
  let header = @ascii.encode("xref\n0 ")
  let header_position = pdf_async_io_find_bytes_for_test(bytes, header)
  if header_position < 0 {
    fail("expected first classic xref subsection header")
  }
  if encrypt_object_number <= 1 {
    fail("expected encryption object after catalog")
  }
  let count_start = header_position + header.length()
  let mut count_end = count_start
  while count_end < bytes.length() && bytes[count_end] != b'\n' {
    count_end += 1
  }
  let original_count = pdf_async_io_parse_positive_decimal_for_test(
    bytes, count_start, count_end,
  )
  if encrypt_object_number >= original_count {
    fail("expected encryption object xref row")
  }
  let rows_start = count_end + 1
  let rows_end = rows_start + original_count * 20
  let encrypt_row_start = rows_start + encrypt_object_number * 20
  let encrypt_row_end = encrypt_row_start + 20
  if rows_end > bytes.length() || encrypt_row_end > rows_end {
    fail("expected complete classic xref rows")
  }
  let output : Array[Byte] = []
  for index in 0..<(header_position + 5) {
    output.push(bytes[index])
  }
  pdf_async_io_push_ascii_for_test(output, "0 2\n")
  for index in rows_start..<(rows_start + 40) {
    output.push(bytes[index])
  }
  pdf_async_io_push_ascii_for_test(output, encrypt_object_number.to_string())
  pdf_async_io_push_ascii_for_test(output, " 1\n")
  for index in encrypt_row_start..<encrypt_row_end {
    output.push(bytes[index])
  }
  for index in rows_end..<bytes.length() {
    output.push(bytes[index])
  }
  Bytes::from_array(output)
}

///|
fn pdf_async_io_corrupt_first_xref_subsection_count_for_test(
  bytes : @pdflite.PdfBytes,
) -> @pdflite.PdfBytes raise {
  let header = @ascii.encode("xref\n0 ")
  let header_position = pdf_async_io_find_bytes_for_test(bytes, header)
  if header_position < 0 {
    fail("expected first classic xref subsection header")
  }
  let count_start = header_position + header.length()
  let mut count_end = count_start
  while count_end < bytes.length() &&
        !pdf_async_io_is_pdf_whitespace_for_test(bytes[count_end]) {
    count_end += 1
  }
  if count_end == count_start {
    fail("expected first classic xref subsection count")
  }
  let output : Array[Byte] = []
  for index in 0..<count_start {
    output.push(bytes[index])
  }
  pdf_async_io_push_ascii_for_test(output, "/Bad")
  for index in count_end..<bytes.length() {
    output.push(bytes[index])
  }
  Bytes::from_array(output)
}

///|
fn pdf_async_io_corrupt_startxref_pointer_for_test(
  bytes : @pdflite.PdfBytes,
) -> @pdflite.PdfBytes raise {
  let marker = @ascii.encode("startxref")
  pdf_async_io_corrupt_startxref_pointer_at_for_test(
    bytes,
    pdf_async_io_find_bytes_for_test(bytes, marker),
  )
}

///|
fn pdf_async_io_corrupt_final_startxref_pointer_for_test(
  bytes : @pdflite.PdfBytes,
) -> @pdflite.PdfBytes raise {
  let marker = @ascii.encode("startxref")
  pdf_async_io_corrupt_startxref_pointer_at_for_test(
    bytes,
    pdf_async_io_find_last_bytes_for_test(bytes, marker),
  )
}

///|
fn pdf_async_io_insert_ascii_before_last_marker_for_test(
  bytes : @pdflite.PdfBytes,
  marker : BytesView,
  insertion : String,
) -> @pdflite.PdfBytes raise {
  let marker_position = pdf_async_io_find_last_bytes_for_test(bytes, marker)
  if marker_position < 0 {
    fail("expected insertion marker")
  }
  let output : Array[Byte] = []
  for index in 0..<marker_position {
    output.push(bytes[index])
  }
  pdf_async_io_push_ascii_for_test(output, insertion)
  for index in marker_position..<bytes.length() {
    output.push(bytes[index])
  }
  Bytes::from_array(output)
}

///|
fn pdf_async_io_name_for_test(text : String) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn pdf_async_io_resource_dictionary_for_test(
  entries : ArrayView[(String, @pdflite.PdfObject)],
) -> @pdflite.PdfObject {
  PdfDictionary(
    [
      for entry in entries => (pdf_async_io_name_for_test(entry.0), entry.1)
    ],
  )
}

///|
fn pdf_async_io_font_file_stream_for_test(data : String) -> @pdflite.PdfObject {
  let bytes = @ascii.encode(data)
  @pdflite.pdf_stream(
    PdfDictionary([
      (pdf_async_io_name_for_test("/Length"), PdfInteger(bytes.length())),
    ]),
    StreamGot(bytes),
  )
}

///|
fn pdf_async_io_font_descriptor_with_file_for_test(
  font_file_key : String,
  font_file_number : Int,
) -> @pdflite.PdfObject {
  PdfDictionary([
    (pdf_async_io_name_for_test(font_file_key), PdfIndirect(font_file_number)),
    (pdf_async_io_name_for_test("/Flags"), PdfInteger(32)),
  ])
}

///|
fn pdf_async_io_font_for_test(
  subtype : String,
  basefont : String,
  descriptor : @pdflite.PdfObject?,
) -> @pdflite.PdfObject {
  let entries : Array[(@pdflite.PdfName, @pdflite.PdfObject)] = [
    (
      pdf_async_io_name_for_test("/Type"),
      PdfNameObject(pdf_async_io_name_for_test("/Font")),
    ),
    (
      pdf_async_io_name_for_test("/Subtype"),
      PdfNameObject(pdf_async_io_name_for_test(subtype)),
    ),
    (
      pdf_async_io_name_for_test("/BaseFont"),
      PdfNameObject(pdf_async_io_name_for_test(basefont)),
    ),
  ]
  match descriptor {
    Some(value) =>
      entries.push((pdf_async_io_name_for_test("/FontDescriptor"), value))
    None => ()
  }
  PdfDictionary(entries)
}

///|
fn pdf_async_io_font_extraction_document_for_test() -> @pdflite.PdfDocument {
  let document = @pdflite.pdf_document_empty()
  document.add_object_given_number(
    80,
    pdf_async_io_font_file_stream_for_test("embedded-font"),
  )
  document.add_object_given_number(
    81,
    pdf_async_io_font_descriptor_with_file_for_test("/FontFile2", 80),
  )
  document.add_object_given_number(
    82,
    pdf_async_io_font_for_test(
      "/TrueType",
      "/AsyncEmbedded",
      Some(PdfIndirect(81)),
    ),
  )
  document.add_object_given_number(
    83,
    pdf_async_io_font_for_test("/Type1", "/NoEmbeddedFile", None),
  )
  let page = {
    ..@pdflite.pdf_page_blank(@pdflite.paper_a4),
    resources: PdfDictionary([
      (
        pdf_async_io_name_for_test("/Font"),
        pdf_async_io_resource_dictionary_for_test([
          ("/F1", PdfIndirect(82)),
          ("/FNo", PdfIndirect(83)),
        ]),
      ),
    ]),
  }
  let page_root = try! document.add_pagetree([page])
  ignore(try! document.add_root(page_root, []))
  document
}

///|
fn pdf_async_io_ascii_codepoints_for_test(text : String) -> Array[Int] {
  [
    for byte in @ascii.encode(text) => byte.to_int()
  ]
}

///|
fn pdf_async_io_codepoints_contain_for_test(
  haystack : ArrayView[Int],
  needle : ArrayView[Int],
) -> Bool {
  if needle.length() == 0 {
    true
  } else if needle.length() > haystack.length() {
    false
  } else {
    for start in 0..<=(haystack.length() - needle.length()) {
      let mut matched = true
      for offset in 0..<needle.length() {
        if haystack[start + offset] != needle[offset] {
          matched = false
        }
      }
      if matched {
        break true
      }
    } nobreak {
      false
    }
  }
}

///|
fn pdf_async_io_font_resource_for_test(
  doc : @pdflite.PdfDocument,
  resources : @pdflite.PdfObject,
  font_name : @pdflite.PdfName,
) -> @pdflite.PdfObject? {
  match doc.lookup_direct(pdf_async_io_name_for_test("/Font"), resources) {
    Some(fonts) => doc.lookup_direct(font_name, fonts)
    None => None
  }
}

///|
fn pdf_async_io_push_text_codepoints_for_test(
  output : Array[Int],
  extractor : @pdflite.PdfTextExtractor,
  text : @pdflite.PdfBytes,
) -> Unit raise {
  for codepoint in extractor.codepoints_of_text(text) {
    output.push(codepoint)
  }
}

///|
fn pdf_async_io_page_text_codepoints_for_test(
  doc : @pdflite.PdfDocument,
  page_index : Int,
) -> Array[Int] raise {
  let pages = doc.pages_of_pagetree()
  guard page_index >= 0 && page_index < pages.length() else {
    fail("expected page index inside document")
  }
  let page = pages[page_index]
  let output : Array[Int] = []
  let mut extractor : @pdflite.PdfTextExtractor? = None
  for op in doc.parse_content_ops_with_resources(page.resources, page.content) {
    match op {
      Op_Tf(font_name, _) =>
        match
          pdf_async_io_font_resource_for_test(doc, page.resources, font_name) {
          Some(font) => extractor = Some(doc.text_extractor_of_font(font))
          None => extractor = None
        }
      Op_Tj(text) =>
        match extractor {
          Some(extractor) =>
            pdf_async_io_push_text_codepoints_for_test(output, extractor, text)
          None => ()
        }
      Op_TJ(PdfArray(items)) =>
        match extractor {
          Some(extractor) =>
            for item in items {
              match item {
                PdfString(text) =>
                  pdf_async_io_push_text_codepoints_for_test(
                    output, extractor, text,
                  )
                _ => ()
              }
            }
          None => ()
        }
      Op_quote(text) =>
        match extractor {
          Some(extractor) =>
            pdf_async_io_push_text_codepoints_for_test(output, extractor, text)
          None => ()
        }
      Op_double_quote(_, _, text) =>
        match extractor {
          Some(extractor) =>
            pdf_async_io_push_text_codepoints_for_test(output, extractor, text)
          None => ()
        }
      _ => ()
    }
  }
  output
}

///|
fn pdf_async_io_assert_page_text_contains_for_test(
  doc : @pdflite.PdfDocument,
  page_index : Int,
  fragments : ArrayView[String],
) -> Unit raise {
  let text = pdf_async_io_page_text_codepoints_for_test(doc, page_index)
  for fragment in fragments {
    let matched = pdf_async_io_codepoints_contain_for_test(
      text,
      pdf_async_io_ascii_codepoints_for_test(fragment),
    )
    @test.assert_eq(
      matched,
      true,
      msg="page " + page_index.to_string() + " missing " + fragment,
    )
  }
}

///|
fn pdf_async_io_assert_intro_fixture_text_for_test(
  doc : @pdflite.PdfDocument,
) -> Unit raise {
  @test.assert_eq(doc.endpage(), 10)
  pdf_async_io_assert_page_text_contains_for_test(doc, 0, [
    "CamlPDF", "Introduction",
  ])
  pdf_async_io_assert_page_text_contains_for_test(doc, 2, [
    "AFirstProgram", "ocamlfind", "opaminstall",
  ])
  pdf_async_io_assert_page_text_contains_for_test(doc, 5, [
    "NextSteps", "pdfobject", "Indirect",
  ])
  pdf_async_io_assert_page_text_contains_for_test(doc, 7, [
    "GraphicsandText", "Pdfops", "Hello,World!",
  ])
  pdf_async_io_assert_page_text_contains_for_test(doc, 9, [
    "pdfencrypt.ml", "FurtherReading",
  ])
}

///|
fn pdf_async_io_secret_object_for_test(text : String) -> @pdflite.PdfObject {
  PdfDictionary([
    (pdf_async_io_name_for_test("/Title"), PdfString(@ascii.encode(text))),
  ])
}

///|
fn pdf_async_io_push_big_endian_for_test(
  output : Array[Byte],
  value : Int,
  width : Int,
) -> Unit {
  let mut divisor = 1
  if width > 1 {
    for _ in 1..<width {
      divisor *= 256
    }
  }
  let mut remaining_divisor = divisor
  while remaining_divisor > 0 {
    output.push((value / remaining_divisor % 256).to_byte())
    remaining_divisor /= 256
  }
}

///|
fn pdf_async_io_push_xref_stream_entry_for_test(
  output : Array[Byte],
  kind : Int,
  field2 : Int,
  field3 : Int,
) -> Unit {
  output.push(kind.to_byte())
  pdf_async_io_push_big_endian_for_test(output, field2, 4)
  pdf_async_io_push_big_endian_for_test(output, field3, 2)
}

///|
fn pdf_async_io_png_none_predictor_rows_for_test(
  data : ArrayView[Byte],
  columns : Int,
) -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  for row_start = 0; row_start < data.length(); row_start = row_start + columns {
    output.push(0)
    let row_end = if row_start + columns > data.length() {
      data.length()
    } else {
      row_start + columns
    }
    for index in row_start..<row_end {
      output.push(data[index])
    }
  }
  Bytes::from_array(output)
}

///|
fn pdf_async_io_push_classic_xref_entry_for_test(
  output : Array[Byte],
  offset : Int,
  generation : Int,
) -> Unit {
  pdf_async_io_push_padded_decimal_for_test(output, offset, 10)
  output.push(b' ')
  pdf_async_io_push_padded_decimal_for_test(output, generation, 5)
  pdf_async_io_push_ascii_for_test(output, " n \n")
}

///|
fn pdf_async_io_write_indirect_object_for_test(
  output : Array[Byte],
  number : Int,
  object : @pdflite.PdfObject,
) -> Unit {
  for
    byte in (try! @pdflite.pdf_write_indirect_object({
      number,
      generation: 0,
      object,
    })) {
    output.push(byte)
  }
  output.push((10).to_byte())
}

///|
fn pdf_async_io_push_raw_indirect_object_for_test(
  output : Array[Byte],
  number : Int,
  generation : Int,
  body : String,
) -> Int {
  let offset = output.length()
  pdf_async_io_push_ascii_for_test(output, number.to_string())
  output.push(b' ')
  pdf_async_io_push_ascii_for_test(output, generation.to_string())
  pdf_async_io_push_ascii_for_test(output, " obj\n")
  pdf_async_io_push_ascii_for_test(output, body)
  pdf_async_io_push_ascii_for_test(output, "\nendobj\n")
  offset
}

///|
fn pdf_async_io_classic_catalog_object_for_test() -> @pdflite.PdfObject {
  @pdflite.pdf_dictionary([
    (
      pdf_async_io_name_for_test("/Type"),
      PdfNameObject(pdf_async_io_name_for_test("/Catalog")),
    ),
  ])
}

///|
fn pdf_async_io_catalog_with_payload_for_test(
  payload_number : Int,
) -> @pdflite.PdfObject {
  @pdflite.pdf_dictionary([
    (
      pdf_async_io_name_for_test("/Type"),
      PdfNameObject(pdf_async_io_name_for_test("/Catalog")),
    ),
    (pdf_async_io_name_for_test("/Payload"), PdfIndirect(payload_number)),
  ])
}

///|
fn pdf_async_io_write_catalog_object_for_test(output : Array[Byte]) -> Int {
  let offset = output.length()
  pdf_async_io_write_indirect_object_for_test(
    output,
    1,
    pdf_async_io_classic_catalog_object_for_test(),
  )
  offset
}

///|
fn pdf_async_io_startxref_object_pdf_for_test(
  body : String,
) -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  pdf_async_io_push_ascii_for_test(output, "%PDF-1.5\n")
  let offset = output.length()
  pdf_async_io_push_ascii_for_test(output, "2 0 obj\n")
  pdf_async_io_push_ascii_for_test(output, body)
  pdf_async_io_push_ascii_for_test(output, "\nendobj\nstartxref\n")
  pdf_async_io_push_ascii_for_test(output, offset.to_string())
  pdf_async_io_push_ascii_for_test(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
fn pdf_async_io_linearized_classic_pdf_for_test(
  value : String,
) -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  pdf_async_io_push_ascii_for_test(output, "%PDF-1.5\n")
  let linearized_offset = pdf_async_io_push_raw_indirect_object_for_test(
    output,
    1,
    0,
    "<< /Linearized " + value + " /L 0 >>",
  )
  let catalog_offset = pdf_async_io_push_raw_indirect_object_for_test(
    output, 2, 0, "<< /Type /Catalog >>",
  )
  let xref_offset = output.length()
  pdf_async_io_push_ascii_for_test(output, "xref\n0 3\n0000000000 65535 f \n")
  pdf_async_io_push_classic_xref_entry_for_test(output, linearized_offset, 0)
  pdf_async_io_push_classic_xref_entry_for_test(output, catalog_offset, 0)
  pdf_async_io_push_ascii_for_test(
    output, "trailer\n<< /Root 2 0 R /Size 3 >>\nstartxref\n",
  )
  pdf_async_io_push_ascii_for_test(output, xref_offset.to_string())
  pdf_async_io_push_ascii_for_test(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
fn pdf_async_io_linearized_classic_pdf_with_prev_xref_for_test() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  pdf_async_io_push_ascii_for_test(output, "%PDF-1.5\n")
  let linearized_offset = pdf_async_io_push_raw_indirect_object_for_test(
    output, 1, 0, "<< /Linearized 1 /L 0 >>",
  )
  let catalog_offset = pdf_async_io_push_raw_indirect_object_for_test(
    output, 2, 0, "<< /Type /Catalog >>",
  )
  let base_xref = output.length()
  pdf_async_io_push_ascii_for_test(output, "xref\n0 3\n0000000000 65535 f \n")
  pdf_async_io_push_classic_xref_entry_for_test(output, linearized_offset, 0)
  pdf_async_io_push_classic_xref_entry_for_test(output, catalog_offset, 0)
  pdf_async_io_push_ascii_for_test(
    output, "trailer\n<< /Root 2 0 R /Size 3 >>\nstartxref\n",
  )
  pdf_async_io_push_ascii_for_test(output, base_xref.to_string())
  pdf_async_io_push_ascii_for_test(output, "\n%%EOF\n")
  let update_offset = pdf_async_io_push_raw_indirect_object_for_test(
    output, 3, 0, "3",
  )
  let final_xref = output.length()
  pdf_async_io_push_ascii_for_test(output, "xref\n3 1\n")
  pdf_async_io_push_classic_xref_entry_for_test(output, update_offset, 0)
  pdf_async_io_push_ascii_for_test(
    output, "trailer\n<< /Root 2 0 R /Size 4 /Prev ",
  )
  pdf_async_io_push_ascii_for_test(output, base_xref.to_string())
  pdf_async_io_push_ascii_for_test(output, " >>\nstartxref\n")
  pdf_async_io_push_ascii_for_test(output, final_xref.to_string())
  pdf_async_io_push_ascii_for_test(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
fn pdf_async_io_xref_stream_with_type_for_test(
  type_entry : String,
) -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  pdf_async_io_push_ascii_for_test(output, "%PDF-1.5\n")
  let catalog_offset = output.length()
  pdf_async_io_write_indirect_object_for_test(
    output,
    1,
    @pdflite.pdf_dictionary([
      (
        pdf_async_io_name_for_test("/Type"),
        PdfNameObject(pdf_async_io_name_for_test("/Catalog")),
      ),
    ]),
  )
  let xref_offset = output.length()
  let xref_data : Array[Byte] = []
  pdf_async_io_push_xref_stream_entry_for_test(xref_data, 0, 0, 65535)
  pdf_async_io_push_xref_stream_entry_for_test(xref_data, 1, catalog_offset, 0)
  pdf_async_io_push_xref_stream_entry_for_test(xref_data, 1, xref_offset, 0)
  pdf_async_io_push_ascii_for_test(output, "2 0 obj\n")
  pdf_async_io_push_ascii_for_test(output, "<< /Type ")
  pdf_async_io_push_ascii_for_test(output, type_entry)
  pdf_async_io_push_ascii_for_test(output, " /Length ")
  pdf_async_io_push_ascii_for_test(output, xref_data.length().to_string())
  pdf_async_io_push_ascii_for_test(
    output, " /Size 3 /Root 1 0 R /W [1 4 2] >>\nstream\n",
  )
  for byte in xref_data {
    output.push(byte)
  }
  pdf_async_io_push_ascii_for_test(output, "\nendstream\nendobj\nstartxref\n")
  pdf_async_io_push_ascii_for_test(output, xref_offset.to_string())
  pdf_async_io_push_ascii_for_test(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
fn pdf_async_io_hybrid_xref_stream_pdf_for_test(
  startxref_override : Int?,
  compressed : Bool,
) -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  pdf_async_io_push_ascii_for_test(output, "%PDF-1.5\n")
  let catalog_offset = pdf_async_io_push_raw_indirect_object_for_test(
    output, 1, 0, "<< /Type /Catalog >>",
  )
  let value_offset = pdf_async_io_push_raw_indirect_object_for_test(
    output, 2, 0, "7",
  )
  let xref_stream_offset = output.length()
  let stream_data : Array[Byte] = []
  pdf_async_io_push_xref_stream_entry_for_test(stream_data, 0, 0, 65535)
  pdf_async_io_push_xref_stream_entry_for_test(stream_data, 1, value_offset, 0)
  pdf_async_io_push_xref_stream_entry_for_test(
    stream_data, 1, xref_stream_offset, 0,
  )
  let data = if compressed {
    @pdflite.pdf_flate_encode(
      pdf_async_io_png_none_predictor_rows_for_test(stream_data, 7),
    )
  } else {
    Bytes::from_array(stream_data)
  }
  pdf_async_io_push_ascii_for_test(output, "3 0 obj\n")
  pdf_async_io_push_ascii_for_test(output, "<< /Type /XRef /Length ")
  pdf_async_io_push_ascii_for_test(output, data.length().to_string())
  pdf_async_io_push_ascii_for_test(
    output, " /Size 4 /W [1 4 2] /Index [0 1 2 2]",
  )
  if compressed {
    pdf_async_io_push_ascii_for_test(
      output, " /Filter /FlateDecode /DecodeParms << /Predictor 12 /Columns 7 >>",
    )
  }
  pdf_async_io_push_ascii_for_test(output, " >>\nstream\n")
  for byte in data {
    output.push(byte)
  }
  pdf_async_io_push_ascii_for_test(output, "\nendstream\nendobj\n")
  let classic_xref_offset = output.length()
  pdf_async_io_push_ascii_for_test(output, "xref\n0 2\n0000000000 65535 f \n")
  pdf_async_io_push_classic_xref_entry_for_test(output, catalog_offset, 0)
  pdf_async_io_push_ascii_for_test(
    output, "trailer\n<< /Root 1 0 R /Size 4 /XRefStm ",
  )
  pdf_async_io_push_ascii_for_test(output, xref_stream_offset.to_string())
  pdf_async_io_push_ascii_for_test(output, " >>\nstartxref\n")
  let startxref = match startxref_override {
    Some(offset) => offset
    None => classic_xref_offset
  }
  pdf_async_io_push_ascii_for_test(output, startxref.to_string())
  pdf_async_io_push_ascii_for_test(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
fn pdf_async_io_xref_stream_pdf_with_short_entry_data_for_test() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  pdf_async_io_push_ascii_for_test(output, "%PDF-1.5\n")
  let xref_offset = output.length()
  pdf_async_io_push_ascii_for_test(output, "2 0 obj\n")
  pdf_async_io_push_ascii_for_test(
    output, "<< /Type /XRef /Length 1 /Size 2 /Root 1 0 R /W [1 4 2] >>\nstream\n",
  )
  output.push(0)
  pdf_async_io_push_ascii_for_test(output, "\nendstream\nendobj\nstartxref\n")
  pdf_async_io_push_ascii_for_test(output, xref_offset.to_string())
  pdf_async_io_push_ascii_for_test(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
fn pdf_async_io_malformed_pdf_without_startxref_for_test() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  pdf_async_io_push_ascii_for_test(output, "%PDF-1.4\n")
  pdf_async_io_write_indirect_object_for_test(
    output,
    1,
    @pdflite.pdf_dictionary([
      (
        pdf_async_io_name_for_test("/Type"),
        PdfNameObject(pdf_async_io_name_for_test("/Catalog")),
      ),
    ]),
  )
  pdf_async_io_write_indirect_object_for_test(output, 2, PdfInteger(7))
  pdf_async_io_push_ascii_for_test(output, "trailer\nnotdict\n")
  pdf_async_io_push_ascii_for_test(
    output, "trailer\n<< /Root 1 0 R /Size 99 /Prev 4 >>\n",
  )
  pdf_async_io_push_ascii_for_test(output, "trailer\n<< /Size 99 >>\n")
  pdf_async_io_push_ascii_for_test(
    output, "trailer\n<< /Root 2 0 R /Size 99 >>\n",
  )
  Bytes::from_array(output)
}

///|
fn pdf_async_io_malformed_pdf_with_endobj_text_in_string_for_test() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  pdf_async_io_push_ascii_for_test(output, "%PDF-1.4\n")
  ignore(
    pdf_async_io_push_raw_indirect_object_for_test(
      output, 1, 0, "<< /Type /Catalog /Title (literal endobj marker) >>",
    ),
  )
  pdf_async_io_push_ascii_for_test(
    output, "trailer\n<< /Root 1 0 R /Size 2 >>\n",
  )
  Bytes::from_array(output)
}

///|
fn pdf_async_io_malformed_pdf_with_glued_reconstruction_trailers_for_test() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  pdf_async_io_push_ascii_for_test(output, "%PDF-1.4\n")
  ignore(pdf_async_io_write_catalog_object_for_test(output))
  pdf_async_io_push_ascii_for_test(output, "trailer << /Size 2 >>\n")
  pdf_async_io_push_ascii_for_test(output, "trailer<< /Root 1 0 R /Size 2 >>\n")
  Bytes::from_array(output)
}

///|
fn pdf_async_io_classic_pdf_with_page_tree_missing_from_xref_for_test() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  pdf_async_io_push_ascii_for_test(output, "%PDF-1.4\n")
  let catalog_offset = pdf_async_io_push_raw_indirect_object_for_test(
    output, 1, 0, "<< /Type /Catalog /Pages 2 0 R >>",
  )
  ignore(
    pdf_async_io_push_raw_indirect_object_for_test(
      output, 2, 0, "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
    ),
  )
  ignore(
    pdf_async_io_push_raw_indirect_object_for_test(
      output, 3, 0, "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 10 10] >>",
    ),
  )
  let xref_offset = output.length()
  pdf_async_io_push_ascii_for_test(output, "xref\n0 2\n0000000000 65535 f \n")
  pdf_async_io_push_classic_xref_entry_for_test(output, catalog_offset, 0)
  pdf_async_io_push_ascii_for_test(
    output, "trailer\n<< /Root 1 0 R /Size 4 >>\nstartxref\n",
  )
  pdf_async_io_push_ascii_for_test(output, xref_offset.to_string())
  pdf_async_io_push_ascii_for_test(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
fn pdf_async_io_classic_pdf_with_catalog_missing_from_xref_for_test() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  pdf_async_io_push_ascii_for_test(output, "%PDF-1.4\n")
  ignore(
    pdf_async_io_push_raw_indirect_object_for_test(
      output, 1, 0, "<< /Type /Catalog /Pages 2 0 R >>",
    ),
  )
  ignore(
    pdf_async_io_push_raw_indirect_object_for_test(
      output, 2, 0, "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
    ),
  )
  ignore(
    pdf_async_io_push_raw_indirect_object_for_test(
      output, 3, 0, "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 10 10] >>",
    ),
  )
  let xref_offset = output.length()
  pdf_async_io_push_ascii_for_test(output, "xref\n0 1\n0000000000 65535 f \n")
  pdf_async_io_push_ascii_for_test(
    output, "trailer\n<< /Root 1 0 R /Size 4 >>\nstartxref\n",
  )
  pdf_async_io_push_ascii_for_test(output, xref_offset.to_string())
  pdf_async_io_push_ascii_for_test(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
fn pdf_async_io_classic_pdf_with_xref_body_for_test(
  xref_body : String,
  trailer_body : String,
) -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  pdf_async_io_push_ascii_for_test(output, "%PDF-1.4\n")
  let xref_offset = output.length()
  pdf_async_io_push_ascii_for_test(output, "xref\n")
  pdf_async_io_push_ascii_for_test(output, xref_body)
  pdf_async_io_push_ascii_for_test(output, "trailer\n")
  pdf_async_io_push_ascii_for_test(output, trailer_body)
  pdf_async_io_push_ascii_for_test(output, "\nstartxref\n")
  pdf_async_io_push_ascii_for_test(output, xref_offset.to_string())
  pdf_async_io_push_ascii_for_test(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
fn pdf_async_io_push_classic_trailer_for_test(
  output : Array[Byte],
  xref_offset : Int,
  size : Int,
) -> Unit {
  pdf_async_io_push_ascii_for_test(output, "trailer\n<< /Root 1 0 R /Size ")
  pdf_async_io_push_ascii_for_test(output, size.to_string())
  pdf_async_io_push_ascii_for_test(output, " >>\nstartxref\n")
  pdf_async_io_push_ascii_for_test(output, xref_offset.to_string())
  pdf_async_io_push_ascii_for_test(output, "\n%%EOF\n")
}

///|
fn pdf_async_io_cr_line_endings_for_test(
  bytes : @pdflite.PdfBytes,
) -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  for byte in bytes {
    let replacement = if byte.to_int() == 10 { (13).to_byte() } else { byte }
    output.push(replacement)
  }
  Bytes::from_array(output)
}

///|
fn pdf_async_io_classic_pdf_with_fixed_width_xref_for_test() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  pdf_async_io_push_ascii_for_test(output, "%PDF-1.4\n")
  let catalog_offset = pdf_async_io_write_catalog_object_for_test(output)
  let xref_offset = output.length()
  pdf_async_io_push_ascii_for_test(output, "xref\n0 2\n")
  pdf_async_io_push_padded_decimal_for_test(output, 0, 10)
  pdf_async_io_push_ascii_for_test(output, "_65535_f \n")
  pdf_async_io_push_padded_decimal_for_test(output, catalog_offset, 10)
  pdf_async_io_push_ascii_for_test(output, "_00000_n \n")
  pdf_async_io_push_classic_trailer_for_test(output, xref_offset, 2)
  Bytes::from_array(output)
}

///|
fn pdf_async_io_classic_pdf_with_unpadded_xref_for_test() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  pdf_async_io_push_ascii_for_test(output, "%PDF-1.4\n")
  let catalog_offset = pdf_async_io_write_catalog_object_for_test(output)
  let xref_offset = output.length()
  pdf_async_io_push_ascii_for_test(output, "xref\n1 1\n")
  pdf_async_io_push_ascii_for_test(output, catalog_offset.to_string())
  pdf_async_io_push_ascii_for_test(output, " 0 n\n")
  pdf_async_io_push_classic_trailer_for_test(output, xref_offset, 2)
  Bytes::from_array(output)
}

///|
fn pdf_async_io_classic_pdf_with_inline_xref_header_for_test() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  pdf_async_io_push_ascii_for_test(output, "%PDF-1.4\n")
  let catalog_offset = pdf_async_io_write_catalog_object_for_test(output)
  let xref_offset = output.length()
  pdf_async_io_push_ascii_for_test(output, "xref 1 1\n")
  pdf_async_io_push_classic_xref_entry_for_test(output, catalog_offset, 0)
  pdf_async_io_push_classic_trailer_for_test(output, xref_offset, 2)
  Bytes::from_array(output)
}

///|
fn pdf_async_io_classic_pdf_with_glued_trailer_for_test() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  pdf_async_io_push_ascii_for_test(output, "%PDF-1.4\n")
  let catalog_offset = pdf_async_io_write_catalog_object_for_test(output)
  let xref_offset = output.length()
  pdf_async_io_push_ascii_for_test(output, "xref\n0 2\n0000000000 65535 f \n")
  pdf_async_io_push_classic_xref_entry_for_test(output, catalog_offset, 0)
  pdf_async_io_push_ascii_for_test(
    output, "trailer<< /Root 1 0 R /Size 2 >>\nstartxref\n",
  )
  pdf_async_io_push_ascii_for_test(output, xref_offset.to_string())
  pdf_async_io_push_ascii_for_test(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
fn pdf_async_io_classic_pdf_with_catalog_xref_for_test() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  pdf_async_io_push_ascii_for_test(output, "%PDF-1.4\n")
  let catalog_offset = pdf_async_io_write_catalog_object_for_test(output)
  let xref_offset = output.length()
  pdf_async_io_push_ascii_for_test(output, "xref\n0 2\n0000000000 65535 f \n")
  pdf_async_io_push_classic_xref_entry_for_test(output, catalog_offset, 0)
  pdf_async_io_push_classic_trailer_for_test(output, xref_offset, 2)
  Bytes::from_array(output)
}

///|
fn pdf_async_io_classic_pdf_with_trailing_startxref_junk_for_test() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  for byte in pdf_async_io_classic_pdf_with_catalog_xref_for_test()[:] {
    output.push(byte)
  }
  pdf_async_io_push_ascii_for_test(output, "\nstartxref\nnot-a-number\n")
  Bytes::from_array(output)
}

///|
fn pdf_async_io_classic_pdf_with_prefixed_startxref_for_test() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  pdf_async_io_push_ascii_for_test(output, "%PDF-1.4\n")
  let catalog_offset = pdf_async_io_write_catalog_object_for_test(output)
  let xref_offset = output.length()
  pdf_async_io_push_ascii_for_test(output, "xref\n0 2\n0000000000 65535 f \n")
  pdf_async_io_push_classic_xref_entry_for_test(output, catalog_offset, 0)
  pdf_async_io_push_ascii_for_test(
    output, "trailer\n<< /Root 1 0 R /Size 2 >>\n",
  )
  pdf_async_io_push_ascii_for_test(output, "startxref junk=")
  pdf_async_io_push_ascii_for_test(output, xref_offset.to_string())
  pdf_async_io_push_ascii_for_test(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
fn pdf_async_io_classic_pdf_with_inline_startxref_for_test() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  pdf_async_io_push_ascii_for_test(output, "%PDF-1.4\n")
  let catalog_offset = pdf_async_io_write_catalog_object_for_test(output)
  let xref_offset = output.length()
  pdf_async_io_push_ascii_for_test(output, "xref\n0 2\n0000000000 65535 f \n")
  pdf_async_io_push_classic_xref_entry_for_test(output, catalog_offset, 0)
  pdf_async_io_push_ascii_for_test(
    output, "trailer\n<< /Root 1 0 R /Size 2 >>\n",
  )
  pdf_async_io_push_ascii_for_test(output, "startxref ")
  pdf_async_io_push_ascii_for_test(output, xref_offset.to_string())
  pdf_async_io_push_ascii_for_test(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
fn pdf_async_io_classic_pdf_with_missing_endobj_catalog_for_test() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  pdf_async_io_push_ascii_for_test(output, "%PDF-1.4\n")
  let catalog_offset = output.length()
  pdf_async_io_push_ascii_for_test(output, "1 0 obj\n<< /Type /Catalog >>\n")
  let xref_offset = output.length()
  pdf_async_io_push_ascii_for_test(output, "xref\n0 2\n0000000000 65535 f \n")
  pdf_async_io_push_classic_xref_entry_for_test(output, catalog_offset, 0)
  pdf_async_io_push_classic_trailer_for_test(output, xref_offset, 2)
  Bytes::from_array(output)
}

///|
fn pdf_async_io_classic_pdf_with_missing_endobj_before_object_for_test() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  pdf_async_io_push_ascii_for_test(output, "%PDF-1.4\n")
  let catalog_offset = output.length()
  pdf_async_io_push_ascii_for_test(
    output, "1 0 obj\n<< /Type /Catalog /Payload 2 0 R >>\n",
  )
  let payload_offset = output.length()
  pdf_async_io_write_indirect_object_for_test(output, 2, PdfInteger(43))
  let xref_offset = output.length()
  pdf_async_io_push_ascii_for_test(output, "xref\n0 3\n0000000000 65535 f \n")
  pdf_async_io_push_classic_xref_entry_for_test(output, catalog_offset, 0)
  pdf_async_io_push_classic_xref_entry_for_test(output, payload_offset, 0)
  pdf_async_io_push_classic_trailer_for_test(output, xref_offset, 3)
  Bytes::from_array(output)
}

///|
fn pdf_async_io_classic_pdf_with_direct_stream_before_object_for_test() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  pdf_async_io_push_ascii_for_test(output, "%PDF-1.4\n")
  let catalog_offset = pdf_async_io_push_raw_indirect_object_for_test(
    output, 1, 0, "<< /Type /Catalog /Payload 2 0 R >>",
  )
  let stream_offset = pdf_async_io_push_raw_indirect_object_for_test(
    output, 2, 0, "<< /Length 5 >>\nstream\nHello\nendstream",
  )
  let null_offset = pdf_async_io_push_raw_indirect_object_for_test(
    output, 3, 0, "null",
  )
  let xref_offset = output.length()
  pdf_async_io_push_ascii_for_test(output, "xref\n0 4\n0000000000 65535 f \n")
  pdf_async_io_push_classic_xref_entry_for_test(output, catalog_offset, 0)
  pdf_async_io_push_classic_xref_entry_for_test(output, stream_offset, 0)
  pdf_async_io_push_classic_xref_entry_for_test(output, null_offset, 0)
  pdf_async_io_push_classic_trailer_for_test(output, xref_offset, 4)
  Bytes::from_array(output)
}

///|
fn pdf_async_io_classic_pdf_with_stream_body_for_test(
  stream_body : @pdflite.PdfBytes,
) -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  pdf_async_io_push_ascii_for_test(output, "%PDF-1.4\n")
  let catalog_offset = pdf_async_io_push_raw_indirect_object_for_test(
    output, 1, 0, "<< /Type /Catalog /Payload 2 0 R >>",
  )
  let stream_offset = output.length()
  pdf_async_io_push_ascii_for_test(output, "2 0 obj\n")
  for byte in stream_body {
    output.push(byte)
  }
  pdf_async_io_push_ascii_for_test(output, "\nendobj\n")
  let xref_offset = output.length()
  pdf_async_io_push_ascii_for_test(output, "xref\n0 3\n0000000000 65535 f \n")
  pdf_async_io_push_classic_xref_entry_for_test(output, catalog_offset, 0)
  pdf_async_io_push_classic_xref_entry_for_test(output, stream_offset, 0)
  pdf_async_io_push_classic_trailer_for_test(output, xref_offset, 3)
  Bytes::from_array(output)
}

///|
fn pdf_async_io_padded_stream_body_for_test(
  payload : String,
  line_break : Bool,
) -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  pdf_async_io_push_ascii_for_test(output, "<< /Length 5 >>\nstream")
  output.push(b' ')
  output.push((9).to_byte())
  if line_break {
    output.push((0).to_byte())
    output.push((12).to_byte())
    output.push((10).to_byte())
  }
  pdf_async_io_push_ascii_for_test(output, payload)
  pdf_async_io_push_ascii_for_test(output, "endstream")
  Bytes::from_array(output)
}

///|
fn pdf_async_io_malformed_pdf_with_out_of_range_startxref_for_test() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  pdf_async_io_push_ascii_for_test(output, "%PDF-1.4\n")
  ignore(pdf_async_io_write_catalog_object_for_test(output))
  pdf_async_io_push_ascii_for_test(
    output, "trailer\n<< /Root 1 0 R /Size 2 >>\n",
  )
  pdf_async_io_push_ascii_for_test(output, "startxref\n999999\n%%EOF\n")
  Bytes::from_array(output)
}

///|
fn pdf_async_io_malformed_pdf_with_bad_startxref_for_test() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  pdf_async_io_push_ascii_for_test(output, "%PDF-1.4\n")
  ignore(pdf_async_io_write_catalog_object_for_test(output))
  pdf_async_io_push_ascii_for_test(
    output, "trailer\n<< /Root 1 0 R /Size 2 >>\n",
  )
  pdf_async_io_push_ascii_for_test(output, "startxref\n9\n%%EOF\n")
  Bytes::from_array(output)
}

///|
fn pdf_async_io_malformed_pdf_with_startxref_number_for_test(
  number : String,
) -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  pdf_async_io_push_ascii_for_test(output, "%PDF-1.4\n")
  ignore(pdf_async_io_write_catalog_object_for_test(output))
  pdf_async_io_push_ascii_for_test(
    output, "trailer\n<< /Root 1 0 R /Size 2 >>\nstartxref\n",
  )
  pdf_async_io_push_ascii_for_test(output, number)
  pdf_async_io_push_ascii_for_test(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
fn pdf_async_io_classic_xref_deleted_payload_bad_startxref_for_test(
  later_update : Bool,
) -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  pdf_async_io_push_ascii_for_test(output, "%PDF-1.4\n")
  let catalog_offset = output.length()
  pdf_async_io_write_indirect_object_for_test(
    output,
    1,
    pdf_async_io_catalog_with_payload_for_test(2),
  )
  pdf_async_io_write_indirect_object_for_test(output, 2, PdfInteger(13))
  pdf_async_io_push_ascii_for_test(output, "xref\n0 3\n0000000000 65535 f \n")
  pdf_async_io_push_classic_xref_entry_for_test(output, catalog_offset, 0)
  pdf_async_io_push_ascii_for_test(output, "0000000000 00000 f \n")
  pdf_async_io_push_ascii_for_test(
    output, "trailer\n<< /Root 1 0 R /Size 3 >>\nstartxref\n0\n%%EOF\n",
  )
  if later_update {
    pdf_async_io_write_indirect_object_for_test(output, 2, PdfInteger(99))
  }
  Bytes::from_array(output)
}

///|
fn pdf_async_io_classic_catalog_pdf_with_prev_xref_bad_startxref_for_test() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  pdf_async_io_push_ascii_for_test(output, "%PDF-1.4\n")
  let original_offset = output.length()
  pdf_async_io_write_indirect_object_for_test(
    output,
    1,
    @pdflite.pdf_dictionary([
      (
        pdf_async_io_name_for_test("/Type"),
        PdfNameObject(pdf_async_io_name_for_test("/Catalog")),
      ),
      (pdf_async_io_name_for_test("/Revision"), PdfInteger(1)),
    ]),
  )
  let base_xref = output.length()
  pdf_async_io_push_ascii_for_test(output, "xref\n0 2\n0000000000 65535 f \n")
  pdf_async_io_push_classic_xref_entry_for_test(output, original_offset, 0)
  pdf_async_io_push_classic_trailer_for_test(output, base_xref, 2)
  let updated_offset = output.length()
  pdf_async_io_write_indirect_object_for_test(
    output,
    1,
    @pdflite.pdf_dictionary([
      (
        pdf_async_io_name_for_test("/Type"),
        PdfNameObject(pdf_async_io_name_for_test("/Catalog")),
      ),
      (pdf_async_io_name_for_test("/Revision"), PdfInteger(2)),
    ]),
  )
  let second_offset = output.length()
  pdf_async_io_write_indirect_object_for_test(output, 2, PdfInteger(3))
  pdf_async_io_push_ascii_for_test(output, "xref\n1 2\n")
  pdf_async_io_push_classic_xref_entry_for_test(output, updated_offset, 0)
  pdf_async_io_push_classic_xref_entry_for_test(output, second_offset, 0)
  pdf_async_io_push_ascii_for_test(
    output, "trailer\n<< /Root 1 0 R /Size 3 /Prev ",
  )
  pdf_async_io_push_ascii_for_test(output, base_xref.to_string())
  pdf_async_io_push_ascii_for_test(output, " >>\nstartxref\n0\n%%EOF\n")
  Bytes::from_array(output)
}

///|
fn pdf_async_io_malformed_pdf_with_bad_xref_entry_for_test() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  pdf_async_io_push_ascii_for_test(output, "%PDF-1.4\n")
  ignore(pdf_async_io_write_catalog_object_for_test(output))
  let xref_offset = output.length()
  pdf_async_io_push_ascii_for_test(
    output, "xref\n0 2\n0000000000 65535 f \nnot-a-row\n",
  )
  pdf_async_io_push_classic_trailer_for_test(output, xref_offset, 2)
  Bytes::from_array(output)
}

///|
fn pdf_async_io_classic_pdf_with_malformed_xref_row_for_test(
  xref_body : String,
) -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  pdf_async_io_push_ascii_for_test(output, "%PDF-1.4\n")
  ignore(pdf_async_io_write_catalog_object_for_test(output))
  let xref_offset = output.length()
  pdf_async_io_push_ascii_for_test(output, "xref\n")
  pdf_async_io_push_ascii_for_test(output, xref_body)
  pdf_async_io_push_ascii_for_test(
    output, "trailer\n<< /Root 1 0 R /Size 2 >>\nstartxref\n",
  )
  pdf_async_io_push_ascii_for_test(output, xref_offset.to_string())
  pdf_async_io_push_ascii_for_test(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
fn pdf_async_io_malformed_pdf_with_bad_xref_count_for_test() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  pdf_async_io_push_ascii_for_test(output, "%PDF-1.4\n")
  ignore(pdf_async_io_write_catalog_object_for_test(output))
  let xref_offset = output.length()
  pdf_async_io_push_ascii_for_test(
    output, "xref\n0 /Bad\n0000000000 65535 f \n",
  )
  pdf_async_io_push_classic_trailer_for_test(output, xref_offset, 2)
  Bytes::from_array(output)
}

///|
fn pdf_async_io_malformed_pdf_with_bad_trailer_for_test() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  pdf_async_io_push_ascii_for_test(output, "%PDF-1.4\n")
  let catalog_offset = pdf_async_io_write_catalog_object_for_test(output)
  let xref_offset = output.length()
  pdf_async_io_push_ascii_for_test(output, "xref\n0 2\n0000000000 65535 f \n")
  pdf_async_io_push_classic_xref_entry_for_test(output, catalog_offset, 0)
  pdf_async_io_push_ascii_for_test(output, "trailer\n1\n")
  pdf_async_io_push_classic_trailer_for_test(output, xref_offset, 2)
  Bytes::from_array(output)
}

///|
fn pdf_async_io_malformed_pdf_with_missing_root_trailer_for_test() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  pdf_async_io_push_ascii_for_test(output, "%PDF-1.4\n")
  let catalog_offset = pdf_async_io_write_catalog_object_for_test(output)
  let xref_offset = output.length()
  pdf_async_io_push_ascii_for_test(output, "xref\n0 2\n0000000000 65535 f \n")
  pdf_async_io_push_classic_xref_entry_for_test(output, catalog_offset, 0)
  pdf_async_io_push_ascii_for_test(output, "trailer\n<< /Size 2 >>\n")
  pdf_async_io_push_classic_trailer_for_test(output, xref_offset, 2)
  Bytes::from_array(output)
}

///|
fn pdf_async_io_malformed_pdf_with_bad_prev_trailer_for_test(
  prev : String,
) -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  pdf_async_io_push_ascii_for_test(output, "%PDF-1.4\n")
  let catalog_offset = pdf_async_io_write_catalog_object_for_test(output)
  let xref_offset = output.length()
  pdf_async_io_push_ascii_for_test(output, "xref\n0 2\n0000000000 65535 f \n")
  pdf_async_io_push_classic_xref_entry_for_test(output, catalog_offset, 0)
  pdf_async_io_push_ascii_for_test(
    output, "trailer\n<< /Root 1 0 R /Size 2 /Prev ",
  )
  pdf_async_io_push_ascii_for_test(output, prev)
  pdf_async_io_push_ascii_for_test(output, " >>\nstartxref\n")
  pdf_async_io_push_ascii_for_test(output, xref_offset.to_string())
  pdf_async_io_push_ascii_for_test(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
fn pdf_async_io_malformed_pdf_with_bad_object_offset_for_test() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  pdf_async_io_push_ascii_for_test(output, "%PDF-1.4\n")
  let junk_offset = output.length()
  pdf_async_io_push_ascii_for_test(output, "notobject\n")
  ignore(pdf_async_io_write_catalog_object_for_test(output))
  let xref_offset = output.length()
  pdf_async_io_push_ascii_for_test(output, "xref\n0 2\n0000000000 65535 f \n")
  pdf_async_io_push_classic_xref_entry_for_test(output, junk_offset, 0)
  pdf_async_io_push_classic_trailer_for_test(output, xref_offset, 2)
  Bytes::from_array(output)
}

///|
fn pdf_async_io_classic_pdf_without_trailer_after_xref_for_test() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  pdf_async_io_push_ascii_for_test(output, "%PDF-1.4\n")
  pdf_async_io_push_ascii_for_test(output, "startxref\n")
  let xref_digits_position = output.length()
  pdf_async_io_push_ascii_for_test(output, "0000000000\n%%EOF\n")
  let xref_offset = output.length()
  pdf_async_io_push_ascii_for_test(output, "xref\n0 1\n0000000000 65535 f \n")
  let digits = @ascii.encode(xref_offset.to_string())
  for i = 0; i < digits.length(); i = i + 1 {
    output[xref_digits_position + 10 - digits.length() + i] = digits[i]
  }
  Bytes::from_array(output)
}

///|
fn pdf_async_io_classic_pdf_with_missing_indirect_stream_length_for_test() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  pdf_async_io_push_ascii_for_test(output, "%PDF-1.4\n")
  let stream_offset = pdf_async_io_push_raw_indirect_object_for_test(
    output, 1, 0, "<< /Length 9 0 R >>\nstream\nHello\nendstream",
  )
  let xref_offset = output.length()
  pdf_async_io_push_ascii_for_test(output, "xref\n0 2\n0000000000 65535 f \n")
  pdf_async_io_push_classic_xref_entry_for_test(output, stream_offset, 0)
  pdf_async_io_push_classic_trailer_for_test(output, xref_offset, 2)
  Bytes::from_array(output)
}

///|
fn pdf_async_io_classic_pdf_with_mismatched_object_xref_for_test() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  pdf_async_io_push_ascii_for_test(output, "%PDF-1.4\n")
  let object_offset = pdf_async_io_push_raw_indirect_object_for_test(
    output, 2, 0, "2",
  )
  let xref_offset = output.length()
  pdf_async_io_push_ascii_for_test(output, "xref\n1 1\n")
  pdf_async_io_push_classic_xref_entry_for_test(output, object_offset, 0)
  pdf_async_io_push_classic_trailer_for_test(output, xref_offset, 2)
  Bytes::from_array(output)
}

///|
fn pdf_async_io_classic_pdf_with_unparseable_xref_object_for_test() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  pdf_async_io_push_ascii_for_test(output, "%PDF-1.4\n")
  let object_offset = output.length()
  pdf_async_io_push_ascii_for_test(output, "notobject\n")
  let xref_offset = output.length()
  pdf_async_io_push_ascii_for_test(output, "xref\n1 1\n")
  pdf_async_io_push_classic_xref_entry_for_test(output, object_offset, 0)
  pdf_async_io_push_classic_trailer_for_test(output, xref_offset, 2)
  Bytes::from_array(output)
}

///|
fn pdf_async_io_classic_pdf_with_commented_indirect_stream_length_for_test() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  pdf_async_io_push_ascii_for_test(output, "%PDF-1.4\n")
  let stream_offset = pdf_async_io_push_raw_indirect_object_for_test(
    output, 1, 0, "<< /Length 2 0 R >>\nstream\nHello\nendstream",
  )
  let length_offset = pdf_async_io_push_raw_indirect_object_for_test(
    output, 2, 0, "5 % stream appears only in this comment",
  )
  let xref_offset = output.length()
  pdf_async_io_push_ascii_for_test(output, "xref\n0 3\n0000000000 65535 f \n")
  pdf_async_io_push_classic_xref_entry_for_test(output, stream_offset, 0)
  pdf_async_io_push_classic_xref_entry_for_test(output, length_offset, 0)
  pdf_async_io_push_classic_trailer_for_test(output, xref_offset, 3)
  Bytes::from_array(output)
}

///|
fn pdf_async_io_classic_pdf_with_non_integer_stream_length_for_test() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  pdf_async_io_push_ascii_for_test(output, "%PDF-1.4\n")
  let stream_offset = pdf_async_io_push_raw_indirect_object_for_test(
    output, 1, 0, "<< /Length 2 0 R >>\nstream\nHello\nendstream",
  )
  let length_offset = pdf_async_io_push_raw_indirect_object_for_test(
    output, 2, 0, "/Name",
  )
  let xref_offset = output.length()
  pdf_async_io_push_ascii_for_test(output, "xref\n0 3\n0000000000 65535 f \n")
  pdf_async_io_push_classic_xref_entry_for_test(output, stream_offset, 0)
  pdf_async_io_push_classic_xref_entry_for_test(output, length_offset, 0)
  pdf_async_io_push_classic_trailer_for_test(output, xref_offset, 3)
  Bytes::from_array(output)
}

///|
fn pdf_async_io_classic_pdf_with_stream_length_object_for_test() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  pdf_async_io_push_ascii_for_test(output, "%PDF-1.4\n")
  let stream_offset = pdf_async_io_push_raw_indirect_object_for_test(
    output, 1, 0, "<< /Length 2 0 R >>\nstream\nHello\nendstream",
  )
  let length_offset = pdf_async_io_push_raw_indirect_object_for_test(
    output, 2, 0, "<< /Length 1 >>\nstream\nA\nendstream",
  )
  let xref_offset = output.length()
  pdf_async_io_push_ascii_for_test(output, "xref\n0 3\n0000000000 65535 f \n")
  pdf_async_io_push_classic_xref_entry_for_test(output, stream_offset, 0)
  pdf_async_io_push_classic_xref_entry_for_test(output, length_offset, 0)
  pdf_async_io_push_classic_trailer_for_test(output, xref_offset, 3)
  Bytes::from_array(output)
}

///|
fn pdf_async_io_classic_pdf_with_negative_stream_length_for_test() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  pdf_async_io_push_ascii_for_test(output, "%PDF-1.4\n")
  let stream_offset = pdf_async_io_push_raw_indirect_object_for_test(
    output, 1, 0, "<< /Length -1 >>\nstream\nHello\nendstream",
  )
  let xref_offset = output.length()
  pdf_async_io_push_ascii_for_test(output, "xref\n0 2\n0000000000 65535 f \n")
  pdf_async_io_push_classic_xref_entry_for_test(output, stream_offset, 0)
  pdf_async_io_push_classic_trailer_for_test(output, xref_offset, 2)
  Bytes::from_array(output)
}

///|
fn pdf_async_io_classic_pdf_with_unparseable_stream_length_for_test() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  pdf_async_io_push_ascii_for_test(output, "%PDF-1.4\n")
  let stream_offset = pdf_async_io_push_raw_indirect_object_for_test(
    output, 1, 0, "<< /Length 2 0 R >>\nstream\nHello\nendstream",
  )
  let length_offset = pdf_async_io_push_raw_indirect_object_for_test(
    output, 2, 0, "]",
  )
  let catalog_offset = pdf_async_io_push_raw_indirect_object_for_test(
    output, 3, 0, "<< /Type /Catalog /Payload 1 0 R >>",
  )
  let xref_offset = output.length()
  pdf_async_io_push_ascii_for_test(output, "xref\n0 4\n0000000000 65535 f \n")
  pdf_async_io_push_classic_xref_entry_for_test(output, stream_offset, 0)
  pdf_async_io_push_classic_xref_entry_for_test(output, length_offset, 0)
  pdf_async_io_push_classic_xref_entry_for_test(output, catalog_offset, 0)
  pdf_async_io_push_ascii_for_test(
    output, "trailer\n<< /Root 3 0 R /Size 4 >>\nstartxref\n",
  )
  pdf_async_io_push_ascii_for_test(output, xref_offset.to_string())
  pdf_async_io_push_ascii_for_test(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
fn pdf_async_io_malformed_pdf_with_indirect_stream_length_for_test() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  pdf_async_io_push_ascii_for_test(output, "%PDF-1.4\n")
  ignore(
    pdf_async_io_push_raw_indirect_object_for_test(
      output, 1, 0, "<< /Length 2 0 R >>\nstream\nHello\nendstream",
    ),
  )
  ignore(pdf_async_io_push_raw_indirect_object_for_test(output, 2, 0, "5"))
  ignore(
    pdf_async_io_push_raw_indirect_object_for_test(
      output, 3, 0, "<< /Type /Catalog /Payload 1 0 R >>",
    ),
  )
  ignore(
    pdf_async_io_push_raw_indirect_object_for_test(
      output, 4, 0, "<< /Length 9 0 R >>\nstream\nIgnored\nendstream",
    ),
  )
  pdf_async_io_push_ascii_for_test(
    output, "trailer\n<< /Root 3 0 R /Size 5 >>\n",
  )
  Bytes::from_array(output)
}

///|
fn pdf_async_io_assert_recovered_hello_stream_for_test(
  document : @pdflite.PdfDocument,
) -> Unit raise {
  guard document.lookup_object_or_null(1) is PdfStreamObject(stream) else {
    fail("expected recovered stream")
  }
  @test.assert_eq(
    stream.dictionary.lookup_immediate(pdf_async_io_name_for_test("/Length")),
    Some(PdfInteger(5)),
  )
  @test.assert_eq(stream.data, StreamGot(@ascii.encode("Hello")))
}

///|
fn pdf_async_io_classic_pdf_with_malformed_stream_for_test(
  stream_body : String,
) -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  pdf_async_io_push_ascii_for_test(output, "%PDF-1.4\n")
  let stream_offset = pdf_async_io_push_raw_indirect_object_for_test(
    output, 1, 0, stream_body,
  )
  let catalog_offset = pdf_async_io_push_raw_indirect_object_for_test(
    output, 2, 0, "<< /Type /Catalog /Payload 1 0 R >>",
  )
  let xref_offset = output.length()
  pdf_async_io_push_ascii_for_test(output, "xref\n0 3\n0000000000 65535 f \n")
  pdf_async_io_push_classic_xref_entry_for_test(output, stream_offset, 0)
  pdf_async_io_push_classic_xref_entry_for_test(output, catalog_offset, 0)
  pdf_async_io_push_ascii_for_test(
    output, "trailer\n<< /Root 2 0 R /Size 3 >>\nstartxref\n",
  )
  pdf_async_io_push_ascii_for_test(output, xref_offset.to_string())
  pdf_async_io_push_ascii_for_test(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
fn pdf_async_io_classic_pdf_with_truncated_stream_for_test() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  pdf_async_io_push_ascii_for_test(output, "%PDF-1.4\n")
  let catalog_offset = pdf_async_io_push_raw_indirect_object_for_test(
    output, 1, 0, "<< /Type /Catalog /Payload 2 0 R >>",
  )
  let stream_offset = output.length()
  pdf_async_io_push_ascii_for_test(
    output, "2 0 obj\n<< /Length 1000 >>\nstream\nHi\n",
  )
  let xref_offset = output.length()
  pdf_async_io_push_ascii_for_test(output, "xref\n0 1\n0000000000 65535 f \n")
  pdf_async_io_push_ascii_for_test(output, "2 1\n")
  pdf_async_io_push_classic_xref_entry_for_test(output, stream_offset, 0)
  pdf_async_io_push_ascii_for_test(output, "1 1\n")
  pdf_async_io_push_classic_xref_entry_for_test(output, catalog_offset, 0)
  pdf_async_io_push_classic_trailer_for_test(output, xref_offset, 3)
  Bytes::from_array(output)
}

///|
fn pdf_async_io_malformed_pdf_with_object_header_inside_stream_for_test() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  pdf_async_io_push_ascii_for_test(output, "%PDF-1.4\n")
  ignore(
    pdf_async_io_push_raw_indirect_object_for_test(
      output, 1, 0, "<< /Type /Catalog /Payload 2 0 R >>",
    ),
  )
  pdf_async_io_push_ascii_for_test(
    output, "2 0 obj\n<< /Length 35 >>\nstream\n",
  )
  pdf_async_io_push_ascii_for_test(
    output, "9 0 obj\n<< /Type /Catalog >>\nendobj",
  )
  pdf_async_io_push_ascii_for_test(output, "\nendstream\nendobj\n")
  pdf_async_io_push_ascii_for_test(
    output, "trailer\n<< /Root 1 0 R /Size 3 >>\n",
  )
  Bytes::from_array(output)
}

///|
fn pdf_async_io_malformed_pdf_with_nested_object_header_for_test() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  pdf_async_io_push_ascii_for_test(output, "%PDF-1.4\n")
  pdf_async_io_push_ascii_for_test(output, "1 0 obj\n]\n")
  pdf_async_io_push_ascii_for_test(
    output, "2 0 obj\n<< /Type /Catalog >>\nendobj\n",
  )
  pdf_async_io_push_ascii_for_test(
    output, "3 0 obj\n<< /Type /Catalog >>\nendobj\n",
  )
  pdf_async_io_push_ascii_for_test(
    output, "trailer\n<< /Root 3 0 R /Size 4 >>\n",
  )
  Bytes::from_array(output)
}

///|
fn pdf_async_io_classic_pdf_with_malformed_object_for_test(
  bad_body : String,
) -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  pdf_async_io_push_ascii_for_test(output, "%PDF-1.4\n")
  let catalog_offset = pdf_async_io_push_raw_indirect_object_for_test(
    output, 1, 0, "<< /Type /Catalog /Payload 2 0 R >>",
  )
  let bad_offset = pdf_async_io_push_raw_indirect_object_for_test(
    output, 2, 0, bad_body,
  )
  let xref_offset = output.length()
  pdf_async_io_push_ascii_for_test(output, "xref\n0 1\n0000000000 65535 f \n")
  pdf_async_io_push_ascii_for_test(output, "2 1\n")
  pdf_async_io_push_classic_xref_entry_for_test(output, bad_offset, 0)
  pdf_async_io_push_ascii_for_test(output, "1 1\n")
  pdf_async_io_push_classic_xref_entry_for_test(output, catalog_offset, 0)
  pdf_async_io_push_classic_trailer_for_test(output, xref_offset, 3)
  Bytes::from_array(output)
}

///|
fn pdf_async_io_xref_stream_pdf_with_prev_update_for_test() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  pdf_async_io_push_ascii_for_test(output, "%PDF-1.5\n")
  let original_offset = pdf_async_io_push_raw_indirect_object_for_test(
    output, 1, 0, "1",
  )
  let base_xref = output.length()
  pdf_async_io_push_ascii_for_test(output, "xref\n0 2\n0000000000 65535 f \n")
  pdf_async_io_push_classic_xref_entry_for_test(output, original_offset, 0)
  pdf_async_io_push_classic_trailer_for_test(output, base_xref, 2)
  let updated_offset = pdf_async_io_push_raw_indirect_object_for_test(
    output, 1, 0, "2",
  )
  let xref_stream_offset = output.length()
  let stream_data : Array[Byte] = []
  pdf_async_io_push_xref_stream_entry_for_test(stream_data, 0, 0, 65535)
  pdf_async_io_push_xref_stream_entry_for_test(
    stream_data, 1, updated_offset, 0,
  )
  pdf_async_io_push_xref_stream_entry_for_test(
    stream_data, 1, xref_stream_offset, 0,
  )
  pdf_async_io_push_ascii_for_test(output, "2 0 obj\n")
  pdf_async_io_push_ascii_for_test(output, "<< /Type /XRef /Length ")
  pdf_async_io_push_ascii_for_test(output, stream_data.length().to_string())
  pdf_async_io_push_ascii_for_test(output, " /Size 3 /Root 1 0 R /Prev ")
  pdf_async_io_push_ascii_for_test(output, base_xref.to_string())
  pdf_async_io_push_ascii_for_test(output, " /W [1 4 2] >>\nstream\n")
  for byte in stream_data {
    output.push(byte)
  }
  pdf_async_io_push_ascii_for_test(output, "\nendstream\nendobj\nstartxref\n")
  pdf_async_io_push_ascii_for_test(output, xref_stream_offset.to_string())
  pdf_async_io_push_ascii_for_test(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
fn pdf_async_io_xref_stream_pdf_with_prev_deleted_for_test() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  pdf_async_io_push_ascii_for_test(output, "%PDF-1.5\n")
  let original_offset = pdf_async_io_push_raw_indirect_object_for_test(
    output, 1, 0, "1",
  )
  let base_xref = output.length()
  pdf_async_io_push_ascii_for_test(output, "xref\n0 2\n0000000000 65535 f \n")
  pdf_async_io_push_classic_xref_entry_for_test(output, original_offset, 0)
  pdf_async_io_push_classic_trailer_for_test(output, base_xref, 2)
  let xref_stream_offset = output.length()
  let stream_data : Array[Byte] = []
  pdf_async_io_push_xref_stream_entry_for_test(stream_data, 0, 0, 65535)
  pdf_async_io_push_xref_stream_entry_for_test(stream_data, 0, 0, 0)
  pdf_async_io_push_xref_stream_entry_for_test(
    stream_data, 1, xref_stream_offset, 0,
  )
  pdf_async_io_push_ascii_for_test(output, "2 0 obj\n")
  pdf_async_io_push_ascii_for_test(output, "<< /Type /XRef /Length ")
  pdf_async_io_push_ascii_for_test(output, stream_data.length().to_string())
  pdf_async_io_push_ascii_for_test(output, " /Size 3 /Root 1 0 R /Prev ")
  pdf_async_io_push_ascii_for_test(output, base_xref.to_string())
  pdf_async_io_push_ascii_for_test(output, " /W [1 4 2] >>\nstream\n")
  for byte in stream_data {
    output.push(byte)
  }
  pdf_async_io_push_ascii_for_test(output, "\nendstream\nendobj\nstartxref\n")
  pdf_async_io_push_ascii_for_test(output, xref_stream_offset.to_string())
  pdf_async_io_push_ascii_for_test(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
fn pdf_async_io_compressed_xref_stream_pdf_with_prev_update_startxref_for_test(
  startxref_override : Int?,
) -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  pdf_async_io_push_ascii_for_test(output, "%PDF-1.5\n")
  let original_offset = pdf_async_io_push_raw_indirect_object_for_test(
    output, 1, 0, "1",
  )
  let catalog_offset = output.length()
  pdf_async_io_write_indirect_object_for_test(
    output,
    2,
    pdf_async_io_catalog_with_payload_for_test(1),
  )
  let base_xref = output.length()
  pdf_async_io_push_ascii_for_test(output, "xref\n0 3\n0000000000 65535 f \n")
  pdf_async_io_push_classic_xref_entry_for_test(output, original_offset, 0)
  pdf_async_io_push_classic_xref_entry_for_test(output, catalog_offset, 0)
  pdf_async_io_push_ascii_for_test(
    output, "trailer\n<< /Root 2 0 R /Size 3 >>\nstartxref\n",
  )
  pdf_async_io_push_ascii_for_test(output, base_xref.to_string())
  pdf_async_io_push_ascii_for_test(output, "\n%%EOF\n")
  let updated_offset = pdf_async_io_push_raw_indirect_object_for_test(
    output, 1, 0, "2",
  )
  let xref_stream_offset = output.length()
  let stream_data : Array[Byte] = []
  pdf_async_io_push_xref_stream_entry_for_test(stream_data, 0, 0, 65535)
  pdf_async_io_push_xref_stream_entry_for_test(
    stream_data, 1, updated_offset, 0,
  )
  pdf_async_io_push_xref_stream_entry_for_test(
    stream_data, 1, catalog_offset, 0,
  )
  pdf_async_io_push_xref_stream_entry_for_test(
    stream_data, 1, xref_stream_offset, 0,
  )
  let predicted = pdf_async_io_png_none_predictor_rows_for_test(stream_data, 7)
  let encoded = @pdflite.pdf_flate_encode(predicted)
  pdf_async_io_push_ascii_for_test(output, "3 0 obj\n")
  pdf_async_io_push_ascii_for_test(output, "<< /Type /XRef /Length ")
  pdf_async_io_push_ascii_for_test(output, encoded.length().to_string())
  pdf_async_io_push_ascii_for_test(output, " /Size 4 /Root 2 0 R /Prev ")
  pdf_async_io_push_ascii_for_test(output, base_xref.to_string())
  pdf_async_io_push_ascii_for_test(
    output, " /W [1 4 2] /Filter /FlateDecode /DecodeParms << /Predictor 12 /Columns 7 >> >>\nstream\n",
  )
  for byte in encoded {
    output.push(byte)
  }
  pdf_async_io_push_ascii_for_test(output, "\nendstream\nendobj\nstartxref\n")
  let startxref = match startxref_override {
    Some(offset) => offset
    None => xref_stream_offset
  }
  pdf_async_io_push_ascii_for_test(output, startxref.to_string())
  pdf_async_io_push_ascii_for_test(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
fn pdf_async_io_compressed_xref_stream_pdf_with_prev_update_for_test() -> @pdflite.PdfBytes {
  pdf_async_io_compressed_xref_stream_pdf_with_prev_update_startxref_for_test(
    None,
  )
}

///|
fn pdf_async_io_compressed_xref_stream_pdf_with_prev_update_bad_startxref_for_test() -> @pdflite.PdfBytes {
  pdf_async_io_compressed_xref_stream_pdf_with_prev_update_startxref_for_test(
    Some(0),
  )
}

///|
fn pdf_async_io_classic_pdf_with_self_prev_xref_for_test() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  pdf_async_io_push_ascii_for_test(output, "%PDF-1.4\n")
  let xref_offset = output.length()
  pdf_async_io_push_ascii_for_test(output, "xref\n0 1\n0000000000 65535 f \n")
  pdf_async_io_push_ascii_for_test(
    output, "trailer\n<< /Root 1 0 R /Size 1 /Prev ",
  )
  pdf_async_io_push_ascii_for_test(output, xref_offset.to_string())
  pdf_async_io_push_ascii_for_test(output, " >>\nstartxref\n")
  pdf_async_io_push_ascii_for_test(output, xref_offset.to_string())
  pdf_async_io_push_ascii_for_test(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
fn pdf_async_io_classic_pdf_with_prev_xref_for_test() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  pdf_async_io_push_ascii_for_test(output, "%PDF-1.4\n")
  let original_offset = output.length()
  pdf_async_io_write_indirect_object_for_test(output, 1, PdfInteger(1))
  let base_xref = output.length()
  pdf_async_io_push_ascii_for_test(output, "xref\n0 2\n0000000000 65535 f \n")
  pdf_async_io_push_classic_xref_entry_for_test(output, original_offset, 0)
  pdf_async_io_push_ascii_for_test(
    output, "trailer\n<< /Root 1 0 R /Size 2 >>\nstartxref\n",
  )
  pdf_async_io_push_ascii_for_test(output, base_xref.to_string())
  pdf_async_io_push_ascii_for_test(output, "\n%%EOF\n")

  let updated_offset = output.length()
  pdf_async_io_write_indirect_object_for_test(output, 1, PdfInteger(2))
  let second_offset = output.length()
  pdf_async_io_write_indirect_object_for_test(output, 2, PdfInteger(3))
  let final_xref = output.length()
  pdf_async_io_push_ascii_for_test(output, "xref\n1 2\n")
  pdf_async_io_push_classic_xref_entry_for_test(output, updated_offset, 0)
  pdf_async_io_push_classic_xref_entry_for_test(output, second_offset, 0)
  pdf_async_io_push_ascii_for_test(
    output, "trailer\n<< /Root 1 0 R /Size 3 /Prev ",
  )
  pdf_async_io_push_ascii_for_test(output, base_xref.to_string())
  pdf_async_io_push_ascii_for_test(output, " >>\nstartxref\n")
  pdf_async_io_push_ascii_for_test(output, final_xref.to_string())
  pdf_async_io_push_ascii_for_test(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
fn pdf_async_io_bad_first_object_stream_physical_page_tree_pdf_for_test() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  pdf_async_io_push_ascii_for_test(output, "%PDF-1.5\n")
  let pages_offset = output.length()
  pdf_async_io_write_indirect_object_for_test(
    output,
    2,
    @pdflite.pdf_dictionary([
      (
        pdf_async_io_name_for_test("/Type"),
        PdfNameObject(pdf_async_io_name_for_test("/Pages")),
      ),
      (pdf_async_io_name_for_test("/Kids"), PdfArray([PdfIndirect(5)])),
      (pdf_async_io_name_for_test("/Count"), PdfInteger(1)),
    ]),
  )
  let page_offset = output.length()
  pdf_async_io_write_indirect_object_for_test(
    output,
    5,
    @pdflite.pdf_dictionary([
      (
        pdf_async_io_name_for_test("/Type"),
        PdfNameObject(pdf_async_io_name_for_test("/Page")),
      ),
      (pdf_async_io_name_for_test("/Parent"), PdfIndirect(2)),
      (
        pdf_async_io_name_for_test("/MediaBox"),
        PdfArray([PdfInteger(0), PdfInteger(0), PdfInteger(10), PdfInteger(10)]),
      ),
      (pdf_async_io_name_for_test("/Resources"), @pdflite.pdf_dictionary([])),
    ]),
  )
  let object_stream_data : Array[Byte] = []
  pdf_async_io_push_ascii_for_test(object_stream_data, "1 0 ")
  pdf_async_io_push_ascii_for_test(
    object_stream_data, "<< /Type /Catalog /Pages 2 0 R >>",
  )
  let bad_first = object_stream_data.length() + 4
  let object_stream_offset = output.length()
  pdf_async_io_push_ascii_for_test(output, "3 0 obj\n")
  pdf_async_io_push_ascii_for_test(output, "<< /Type /ObjStm /N 1 /First ")
  pdf_async_io_push_ascii_for_test(output, bad_first.to_string())
  pdf_async_io_push_ascii_for_test(output, " /Length ")
  pdf_async_io_push_ascii_for_test(
    output,
    object_stream_data.length().to_string(),
  )
  pdf_async_io_push_ascii_for_test(output, " >>\nstream\n")
  for byte in object_stream_data {
    output.push(byte)
  }
  pdf_async_io_push_ascii_for_test(output, "\nendstream\nendobj\n")
  let xref_offset = output.length()
  let xref_data : Array[Byte] = []
  pdf_async_io_push_xref_stream_entry_for_test(xref_data, 0, 0, 65535)
  pdf_async_io_push_xref_stream_entry_for_test(xref_data, 2, 3, 0)
  pdf_async_io_push_xref_stream_entry_for_test(xref_data, 1, pages_offset, 0)
  pdf_async_io_push_xref_stream_entry_for_test(
    xref_data, 1, object_stream_offset, 0,
  )
  pdf_async_io_push_xref_stream_entry_for_test(xref_data, 1, xref_offset, 0)
  pdf_async_io_push_xref_stream_entry_for_test(xref_data, 1, page_offset, 0)
  let xref_stream = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (
        pdf_async_io_name_for_test("/Type"),
        PdfNameObject(pdf_async_io_name_for_test("/XRef")),
      ),
      (pdf_async_io_name_for_test("/Size"), PdfInteger(6)),
      (pdf_async_io_name_for_test("/Root"), PdfIndirect(1)),
      (
        pdf_async_io_name_for_test("/W"),
        PdfArray([PdfInteger(1), PdfInteger(4), PdfInteger(2)]),
      ),
      (pdf_async_io_name_for_test("/Length"), PdfInteger(xref_data.length())),
    ]),
    StreamGot(Bytes::from_array(xref_data)),
  )
  pdf_async_io_write_indirect_object_for_test(output, 4, xref_stream)
  pdf_async_io_write_indirect_object_for_test(
    output,
    1,
    @pdflite.pdf_dictionary([
      (
        pdf_async_io_name_for_test("/Type"),
        PdfNameObject(pdf_async_io_name_for_test("/Catalog")),
      ),
      (pdf_async_io_name_for_test("/Pages"), PdfIndirect(2)),
    ]),
  )
  pdf_async_io_push_ascii_for_test(output, "startxref\n")
  pdf_async_io_push_ascii_for_test(output, xref_offset.to_string())
  pdf_async_io_push_ascii_for_test(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
fn pdf_async_io_mismatched_object_stream_root_physical_catalog_for_test() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  pdf_async_io_push_ascii_for_test(output, "%PDF-1.5\n")
  let object_stream_data : Array[Byte] = []
  pdf_async_io_push_ascii_for_test(object_stream_data, "2 0 ")
  let first = object_stream_data.length()
  pdf_async_io_push_ascii_for_test(object_stream_data, "<< /Type /Catalog >>")
  let object_stream_offset = output.length()
  pdf_async_io_push_ascii_for_test(output, "3 0 obj\n")
  pdf_async_io_push_ascii_for_test(output, "<< /Type /ObjStm /N 1 /First ")
  pdf_async_io_push_ascii_for_test(output, first.to_string())
  pdf_async_io_push_ascii_for_test(output, " /Length ")
  pdf_async_io_push_ascii_for_test(
    output,
    object_stream_data.length().to_string(),
  )
  pdf_async_io_push_ascii_for_test(output, " >>\nstream\n")
  for byte in object_stream_data {
    output.push(byte)
  }
  pdf_async_io_push_ascii_for_test(output, "\nendstream\nendobj\n")
  let xref_offset = output.length()
  let xref_data : Array[Byte] = []
  pdf_async_io_push_xref_stream_entry_for_test(xref_data, 0, 0, 65535)
  pdf_async_io_push_xref_stream_entry_for_test(xref_data, 2, 3, 0)
  pdf_async_io_push_xref_stream_entry_for_test(xref_data, 0, 0, 0)
  pdf_async_io_push_xref_stream_entry_for_test(
    xref_data, 1, object_stream_offset, 0,
  )
  pdf_async_io_push_xref_stream_entry_for_test(xref_data, 1, xref_offset, 0)
  let xref_stream = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (
        pdf_async_io_name_for_test("/Type"),
        PdfNameObject(pdf_async_io_name_for_test("/XRef")),
      ),
      (pdf_async_io_name_for_test("/Size"), PdfInteger(5)),
      (pdf_async_io_name_for_test("/Root"), PdfIndirect(1)),
      (
        pdf_async_io_name_for_test("/W"),
        PdfArray([PdfInteger(1), PdfInteger(4), PdfInteger(2)]),
      ),
      (pdf_async_io_name_for_test("/Length"), PdfInteger(xref_data.length())),
    ]),
    StreamGot(Bytes::from_array(xref_data)),
  )
  pdf_async_io_write_indirect_object_for_test(output, 4, xref_stream)
  pdf_async_io_write_indirect_object_for_test(
    output,
    1,
    @pdflite.pdf_dictionary([
      (
        pdf_async_io_name_for_test("/Type"),
        PdfNameObject(pdf_async_io_name_for_test("/Catalog")),
      ),
    ]),
  )
  pdf_async_io_push_ascii_for_test(
    output, "trailer\n<< /Root 1 0 R /Size 5 >>\nstartxref\n",
  )
  pdf_async_io_push_ascii_for_test(output, xref_offset.to_string())
  pdf_async_io_push_ascii_for_test(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
fn pdf_async_io_xref_stream_pdf_with_two_object_stream_entries_for_test() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  pdf_async_io_push_ascii_for_test(output, "%PDF-1.5\n")
  let catalog_offset = output.length()
  pdf_async_io_write_indirect_object_for_test(
    output,
    1,
    @pdflite.pdf_dictionary([
      (
        pdf_async_io_name_for_test("/Type"),
        PdfNameObject(pdf_async_io_name_for_test("/Catalog")),
      ),
      (pdf_async_io_name_for_test("/Payload"), PdfIndirect(2)),
      (pdf_async_io_name_for_test("/Other"), PdfIndirect(5)),
    ]),
  )
  let first_object = @ascii.encode("<< /Answer 42 >>")
  let second_object = @ascii.encode("[1 2 3]")
  let object_stream_data : Array[Byte] = []
  pdf_async_io_push_ascii_for_test(object_stream_data, "2 0 5 ")
  pdf_async_io_push_ascii_for_test(
    object_stream_data,
    first_object.length().to_string(),
  )
  object_stream_data.push(b' ')
  let first = object_stream_data.length()
  for byte in first_object {
    object_stream_data.push(byte)
  }
  for byte in second_object {
    object_stream_data.push(byte)
  }
  let object_stream_offset = output.length()
  pdf_async_io_push_ascii_for_test(output, "3 0 obj\n")
  pdf_async_io_push_ascii_for_test(output, "<< /Type /ObjStm /N 2 /First ")
  pdf_async_io_push_ascii_for_test(output, first.to_string())
  pdf_async_io_push_ascii_for_test(output, " /Length ")
  pdf_async_io_push_ascii_for_test(
    output,
    object_stream_data.length().to_string(),
  )
  pdf_async_io_push_ascii_for_test(output, " >>\nstream\n")
  for byte in object_stream_data {
    output.push(byte)
  }
  pdf_async_io_push_ascii_for_test(output, "\nendstream\nendobj\n")
  let xref_offset = output.length()
  let xref_data : Array[Byte] = []
  pdf_async_io_push_xref_stream_entry_for_test(xref_data, 0, 0, 65535)
  pdf_async_io_push_xref_stream_entry_for_test(xref_data, 1, catalog_offset, 0)
  pdf_async_io_push_xref_stream_entry_for_test(xref_data, 2, 3, 0)
  pdf_async_io_push_xref_stream_entry_for_test(
    xref_data, 1, object_stream_offset, 0,
  )
  pdf_async_io_push_xref_stream_entry_for_test(xref_data, 1, xref_offset, 0)
  pdf_async_io_push_xref_stream_entry_for_test(xref_data, 2, 3, 1)
  let xref_stream = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (
        pdf_async_io_name_for_test("/Type"),
        PdfNameObject(pdf_async_io_name_for_test("/XRef")),
      ),
      (pdf_async_io_name_for_test("/Size"), PdfInteger(6)),
      (pdf_async_io_name_for_test("/Root"), PdfIndirect(1)),
      (
        pdf_async_io_name_for_test("/W"),
        PdfArray([PdfInteger(1), PdfInteger(4), PdfInteger(2)]),
      ),
      (pdf_async_io_name_for_test("/Length"), PdfInteger(xref_data.length())),
    ]),
    StreamGot(Bytes::from_array(xref_data)),
  )
  pdf_async_io_write_indirect_object_for_test(output, 4, xref_stream)
  pdf_async_io_push_ascii_for_test(output, "startxref\n")
  pdf_async_io_push_ascii_for_test(output, xref_offset.to_string())
  pdf_async_io_push_ascii_for_test(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
fn pdf_async_io_xref_stream_pdf_with_stream_object_in_object_stream_for_test() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  pdf_async_io_push_ascii_for_test(output, "%PDF-1.5\n")
  let catalog_offset = output.length()
  pdf_async_io_write_indirect_object_for_test(
    output,
    1,
    pdf_async_io_catalog_with_payload_for_test(2),
  )
  let stream_object = @ascii.encode("<< /Length 99 >>\nstream\nHi\nendstream")
  let object_stream_data : Array[Byte] = []
  pdf_async_io_push_ascii_for_test(object_stream_data, "2 0 ")
  let first = object_stream_data.length()
  for byte in stream_object {
    object_stream_data.push(byte)
  }
  let object_stream_offset = output.length()
  pdf_async_io_push_ascii_for_test(output, "3 0 obj\n")
  pdf_async_io_push_ascii_for_test(output, "<< /Type /ObjStm /N 1 /First ")
  pdf_async_io_push_ascii_for_test(output, first.to_string())
  pdf_async_io_push_ascii_for_test(output, " /Length ")
  pdf_async_io_push_ascii_for_test(
    output,
    object_stream_data.length().to_string(),
  )
  pdf_async_io_push_ascii_for_test(output, " >>\nstream\n")
  for byte in object_stream_data {
    output.push(byte)
  }
  pdf_async_io_push_ascii_for_test(output, "\nendstream\nendobj\n")
  let xref_offset = output.length()
  let xref_data : Array[Byte] = []
  pdf_async_io_push_xref_stream_entry_for_test(xref_data, 0, 0, 65535)
  pdf_async_io_push_xref_stream_entry_for_test(xref_data, 1, catalog_offset, 0)
  pdf_async_io_push_xref_stream_entry_for_test(xref_data, 2, 3, 0)
  pdf_async_io_push_xref_stream_entry_for_test(
    xref_data, 1, object_stream_offset, 0,
  )
  pdf_async_io_push_xref_stream_entry_for_test(xref_data, 1, xref_offset, 0)
  let xref_stream = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (
        pdf_async_io_name_for_test("/Type"),
        PdfNameObject(pdf_async_io_name_for_test("/XRef")),
      ),
      (pdf_async_io_name_for_test("/Size"), PdfInteger(5)),
      (pdf_async_io_name_for_test("/Root"), PdfIndirect(1)),
      (
        pdf_async_io_name_for_test("/W"),
        PdfArray([PdfInteger(1), PdfInteger(4), PdfInteger(2)]),
      ),
      (pdf_async_io_name_for_test("/Length"), PdfInteger(xref_data.length())),
    ]),
    StreamGot(Bytes::from_array(xref_data)),
  )
  pdf_async_io_write_indirect_object_for_test(output, 4, xref_stream)
  pdf_async_io_push_ascii_for_test(output, "startxref\n")
  pdf_async_io_push_ascii_for_test(output, xref_offset.to_string())
  pdf_async_io_push_ascii_for_test(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
fn pdf_async_io_xref_stream_prev_update_with_object_stream_root_bad_startxref_for_test() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  pdf_async_io_push_ascii_for_test(output, "%PDF-1.5\n")
  let old_catalog_offset = output.length()
  pdf_async_io_write_indirect_object_for_test(
    output,
    1,
    @pdflite.pdf_dictionary([
      (
        pdf_async_io_name_for_test("/Type"),
        PdfNameObject(pdf_async_io_name_for_test("/Catalog")),
      ),
      (pdf_async_io_name_for_test("/Old"), PdfBoolean(true)),
    ]),
  )
  let first_xref_offset = output.length()
  let first_xref_data : Array[Byte] = []
  pdf_async_io_push_xref_stream_entry_for_test(first_xref_data, 0, 0, 65535)
  pdf_async_io_push_xref_stream_entry_for_test(
    first_xref_data, 1, old_catalog_offset, 0,
  )
  pdf_async_io_push_xref_stream_entry_for_test(
    first_xref_data, 1, first_xref_offset, 0,
  )
  let first_xref_stream = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (
        pdf_async_io_name_for_test("/Type"),
        PdfNameObject(pdf_async_io_name_for_test("/XRef")),
      ),
      (pdf_async_io_name_for_test("/Size"), PdfInteger(3)),
      (pdf_async_io_name_for_test("/Root"), PdfIndirect(1)),
      (
        pdf_async_io_name_for_test("/W"),
        PdfArray([PdfInteger(1), PdfInteger(4), PdfInteger(2)]),
      ),
      (
        pdf_async_io_name_for_test("/Length"),
        PdfInteger(first_xref_data.length()),
      ),
    ]),
    StreamGot(Bytes::from_array(first_xref_data)),
  )
  pdf_async_io_write_indirect_object_for_test(output, 2, first_xref_stream)
  pdf_async_io_push_ascii_for_test(output, "startxref\n")
  pdf_async_io_push_ascii_for_test(output, first_xref_offset.to_string())
  pdf_async_io_push_ascii_for_test(output, "\n%%EOF\n")

  let object_stream_data : Array[Byte] = []
  pdf_async_io_push_ascii_for_test(object_stream_data, "1 0 ")
  let first = object_stream_data.length()
  pdf_async_io_push_ascii_for_test(
    object_stream_data, "<< /Type /Catalog /New true >>",
  )
  let object_stream_offset = output.length()
  pdf_async_io_push_ascii_for_test(output, "3 0 obj\n")
  pdf_async_io_push_ascii_for_test(output, "<< /Type /ObjStm /N 1 /First ")
  pdf_async_io_push_ascii_for_test(output, first.to_string())
  pdf_async_io_push_ascii_for_test(output, " /Length ")
  pdf_async_io_push_ascii_for_test(
    output,
    object_stream_data.length().to_string(),
  )
  pdf_async_io_push_ascii_for_test(output, " >>\nstream\n")
  for byte in object_stream_data {
    output.push(byte)
  }
  pdf_async_io_push_ascii_for_test(output, "\nendstream\nendobj\n")
  let second_xref_offset = output.length()
  let second_xref_data : Array[Byte] = []
  pdf_async_io_push_xref_stream_entry_for_test(second_xref_data, 0, 0, 65535)
  pdf_async_io_push_xref_stream_entry_for_test(second_xref_data, 2, 3, 0)
  pdf_async_io_push_xref_stream_entry_for_test(second_xref_data, 0, 0, 0)
  pdf_async_io_push_xref_stream_entry_for_test(
    second_xref_data, 1, object_stream_offset, 0,
  )
  pdf_async_io_push_xref_stream_entry_for_test(
    second_xref_data, 1, second_xref_offset, 0,
  )
  let second_xref_stream = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (
        pdf_async_io_name_for_test("/Type"),
        PdfNameObject(pdf_async_io_name_for_test("/XRef")),
      ),
      (pdf_async_io_name_for_test("/Size"), PdfInteger(5)),
      (pdf_async_io_name_for_test("/Root"), PdfIndirect(1)),
      (pdf_async_io_name_for_test("/Prev"), PdfInteger(first_xref_offset)),
      (
        pdf_async_io_name_for_test("/W"),
        PdfArray([PdfInteger(1), PdfInteger(4), PdfInteger(2)]),
      ),
      (
        pdf_async_io_name_for_test("/Length"),
        PdfInteger(second_xref_data.length()),
      ),
    ]),
    StreamGot(Bytes::from_array(second_xref_data)),
  )
  pdf_async_io_write_indirect_object_for_test(output, 4, second_xref_stream)
  pdf_async_io_push_ascii_for_test(output, "startxref\n0\n%%EOF\n")
  Bytes::from_array(output)
}

///|
fn pdf_async_io_xref_stream_pdf_with_bad_filtered_object_stream_root_for_test() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  pdf_async_io_push_ascii_for_test(output, "%PDF-1.5\n")
  let object_stream_data : Array[Byte] = []
  pdf_async_io_push_ascii_for_test(object_stream_data, "1 0 ")
  let first = object_stream_data.length()
  pdf_async_io_push_ascii_for_test(object_stream_data, "<< /Type /Catalog >>")
  let object_stream_offset = output.length()
  pdf_async_io_push_ascii_for_test(output, "3 0 obj\n")
  pdf_async_io_push_ascii_for_test(output, "<< /Type /ObjStm /N 1 /First ")
  pdf_async_io_push_ascii_for_test(output, first.to_string())
  pdf_async_io_push_ascii_for_test(output, " /Length ")
  pdf_async_io_push_ascii_for_test(
    output,
    object_stream_data.length().to_string(),
  )
  pdf_async_io_push_ascii_for_test(
    output, " /Filter /BadObjectStreamFilter >>\nstream\n",
  )
  for byte in object_stream_data {
    output.push(byte)
  }
  pdf_async_io_push_ascii_for_test(output, "\nendstream\nendobj\n")
  let xref_offset = output.length()
  let xref_data : Array[Byte] = []
  pdf_async_io_push_xref_stream_entry_for_test(xref_data, 0, 0, 65535)
  pdf_async_io_push_xref_stream_entry_for_test(xref_data, 2, 3, 0)
  pdf_async_io_push_xref_stream_entry_for_test(xref_data, 0, 0, 65535)
  pdf_async_io_push_xref_stream_entry_for_test(
    xref_data, 1, object_stream_offset, 0,
  )
  pdf_async_io_push_xref_stream_entry_for_test(xref_data, 1, xref_offset, 0)
  let xref_stream = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (
        pdf_async_io_name_for_test("/Type"),
        PdfNameObject(pdf_async_io_name_for_test("/XRef")),
      ),
      (pdf_async_io_name_for_test("/Size"), PdfInteger(5)),
      (pdf_async_io_name_for_test("/Root"), PdfIndirect(1)),
      (
        pdf_async_io_name_for_test("/W"),
        PdfArray([PdfInteger(1), PdfInteger(4), PdfInteger(2)]),
      ),
      (pdf_async_io_name_for_test("/Length"), PdfInteger(xref_data.length())),
    ]),
    StreamGot(Bytes::from_array(xref_data)),
  )
  pdf_async_io_write_indirect_object_for_test(output, 4, xref_stream)
  pdf_async_io_push_ascii_for_test(output, "startxref\n")
  pdf_async_io_push_ascii_for_test(output, xref_offset.to_string())
  pdf_async_io_push_ascii_for_test(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
fn pdf_async_io_xref_stream_pdf_with_decodeparms_object_stream_root_for_test(
  decodeparms : String,
) -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  pdf_async_io_push_ascii_for_test(output, "%PDF-1.5\n")
  let object_stream_data : Array[Byte] = []
  pdf_async_io_push_ascii_for_test(object_stream_data, "1 0 ")
  let first = object_stream_data.length()
  pdf_async_io_push_ascii_for_test(object_stream_data, "<< /Type /Catalog >>")
  let encoded_object_stream = @pdflite.pdf_flate_encode(
    Bytes::from_array(object_stream_data),
  )
  let object_stream_offset = output.length()
  pdf_async_io_push_ascii_for_test(output, "3 0 obj\n")
  pdf_async_io_push_ascii_for_test(output, "<< /Type /ObjStm /N 1 /First ")
  pdf_async_io_push_ascii_for_test(output, first.to_string())
  pdf_async_io_push_ascii_for_test(output, " /Length ")
  pdf_async_io_push_ascii_for_test(
    output,
    encoded_object_stream.length().to_string(),
  )
  pdf_async_io_push_ascii_for_test(
    output, " /Filter /FlateDecode /DecodeParms ",
  )
  pdf_async_io_push_ascii_for_test(output, decodeparms)
  pdf_async_io_push_ascii_for_test(output, " >>\nstream\n")
  for byte in encoded_object_stream {
    output.push(byte)
  }
  pdf_async_io_push_ascii_for_test(output, "\nendstream\nendobj\n")
  let xref_offset = output.length()
  let xref_data : Array[Byte] = []
  pdf_async_io_push_xref_stream_entry_for_test(xref_data, 0, 0, 65535)
  pdf_async_io_push_xref_stream_entry_for_test(xref_data, 2, 3, 0)
  pdf_async_io_push_xref_stream_entry_for_test(xref_data, 0, 0, 65535)
  pdf_async_io_push_xref_stream_entry_for_test(
    xref_data, 1, object_stream_offset, 0,
  )
  pdf_async_io_push_xref_stream_entry_for_test(xref_data, 1, xref_offset, 0)
  let xref_stream = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (
        pdf_async_io_name_for_test("/Type"),
        PdfNameObject(pdf_async_io_name_for_test("/XRef")),
      ),
      (pdf_async_io_name_for_test("/Size"), PdfInteger(5)),
      (pdf_async_io_name_for_test("/Root"), PdfIndirect(1)),
      (
        pdf_async_io_name_for_test("/W"),
        PdfArray([PdfInteger(1), PdfInteger(4), PdfInteger(2)]),
      ),
      (pdf_async_io_name_for_test("/Length"), PdfInteger(xref_data.length())),
    ]),
    StreamGot(Bytes::from_array(xref_data)),
  )
  pdf_async_io_write_indirect_object_for_test(output, 4, xref_stream)
  pdf_async_io_push_ascii_for_test(output, "startxref\n")
  pdf_async_io_push_ascii_for_test(output, xref_offset.to_string())
  pdf_async_io_push_ascii_for_test(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
fn pdf_async_io_xref_stream_pdf_with_bad_decodeparms_object_stream_root_for_test() -> @pdflite.PdfBytes {
  pdf_async_io_xref_stream_pdf_with_decodeparms_object_stream_root_for_test(
    "/Bad",
  )
}

///|
fn pdf_async_io_xref_stream_pdf_with_unsupported_predictor_object_stream_root_for_test() -> @pdflite.PdfBytes {
  pdf_async_io_xref_stream_pdf_with_decodeparms_object_stream_root_for_test(
    "<< /Predictor 9 >>",
  )
}

///|
fn pdf_async_io_bad_first_object_stream_payload_for_test() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  pdf_async_io_push_ascii_for_test(output, "%PDF-1.5\n")
  let catalog_offset = output.length()
  pdf_async_io_write_indirect_object_for_test(
    output,
    1,
    @pdflite.pdf_dictionary([
      (
        pdf_async_io_name_for_test("/Type"),
        PdfNameObject(pdf_async_io_name_for_test("/Catalog")),
      ),
      (pdf_async_io_name_for_test("/Payload"), PdfIndirect(2)),
    ]),
  )
  let object_stream_data : Array[Byte] = []
  pdf_async_io_push_ascii_for_test(object_stream_data, "2 0 ")
  let bad_first = object_stream_data.length() + 32
  pdf_async_io_push_ascii_for_test(object_stream_data, "<< /Answer 42 >>")
  let object_stream_offset = output.length()
  pdf_async_io_push_ascii_for_test(output, "3 0 obj\n")
  pdf_async_io_push_ascii_for_test(output, "<< /Type /ObjStm /N 1 /First ")
  pdf_async_io_push_ascii_for_test(output, bad_first.to_string())
  pdf_async_io_push_ascii_for_test(output, " /Length ")
  pdf_async_io_push_ascii_for_test(
    output,
    object_stream_data.length().to_string(),
  )
  pdf_async_io_push_ascii_for_test(output, " >>\nstream\n")
  for byte in object_stream_data {
    output.push(byte)
  }
  pdf_async_io_push_ascii_for_test(output, "\nendstream\nendobj\n")
  let xref_offset = output.length()
  let xref_data : Array[Byte] = []
  pdf_async_io_push_xref_stream_entry_for_test(xref_data, 0, 0, 65535)
  pdf_async_io_push_xref_stream_entry_for_test(xref_data, 1, catalog_offset, 0)
  pdf_async_io_push_xref_stream_entry_for_test(xref_data, 2, 3, 0)
  pdf_async_io_push_xref_stream_entry_for_test(
    xref_data, 1, object_stream_offset, 0,
  )
  pdf_async_io_push_xref_stream_entry_for_test(xref_data, 1, xref_offset, 0)
  let xref_stream = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (
        pdf_async_io_name_for_test("/Type"),
        PdfNameObject(pdf_async_io_name_for_test("/XRef")),
      ),
      (pdf_async_io_name_for_test("/Size"), PdfInteger(5)),
      (pdf_async_io_name_for_test("/Root"), PdfIndirect(1)),
      (
        pdf_async_io_name_for_test("/W"),
        PdfArray([PdfInteger(1), PdfInteger(4), PdfInteger(2)]),
      ),
      (pdf_async_io_name_for_test("/Length"), PdfInteger(xref_data.length())),
    ]),
    StreamGot(Bytes::from_array(xref_data)),
  )
  pdf_async_io_write_indirect_object_for_test(output, 4, xref_stream)
  pdf_async_io_push_ascii_for_test(output, "startxref\n")
  pdf_async_io_push_ascii_for_test(output, xref_offset.to_string())
  pdf_async_io_push_ascii_for_test(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
fn pdf_async_io_indirect_object_stream_bounds_bad_startxref_for_test() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  pdf_async_io_push_ascii_for_test(output, "%PDF-1.5\n")
  let catalog_offset = output.length()
  pdf_async_io_write_indirect_object_for_test(
    output,
    1,
    @pdflite.pdf_dictionary([
      (
        pdf_async_io_name_for_test("/Type"),
        PdfNameObject(pdf_async_io_name_for_test("/Catalog")),
      ),
    ]),
  )
  let count_offset = output.length()
  pdf_async_io_write_indirect_object_for_test(output, 2, PdfInteger(1))
  let object_stream_data : Array[Byte] = []
  pdf_async_io_push_ascii_for_test(object_stream_data, "7 0 ")
  let first = object_stream_data.length()
  pdf_async_io_push_ascii_for_test(object_stream_data, "<< /Answer 42 >>")
  let object_stream_offset = output.length()
  pdf_async_io_push_ascii_for_test(output, "3 0 obj\n")
  pdf_async_io_push_ascii_for_test(
    output, "<< /Type /ObjStm /N 2 0 R /First 5 0 R /Length ",
  )
  pdf_async_io_push_ascii_for_test(
    output,
    object_stream_data.length().to_string(),
  )
  pdf_async_io_push_ascii_for_test(output, " >>\nstream\n")
  for byte in object_stream_data {
    output.push(byte)
  }
  pdf_async_io_push_ascii_for_test(output, "\nendstream\nendobj\n")
  let first_offset = output.length()
  pdf_async_io_write_indirect_object_for_test(output, 5, PdfInteger(first))
  let xref_offset = output.length()
  let xref_data : Array[Byte] = []
  pdf_async_io_push_xref_stream_entry_for_test(xref_data, 0, 0, 65535)
  pdf_async_io_push_xref_stream_entry_for_test(xref_data, 1, catalog_offset, 0)
  pdf_async_io_push_xref_stream_entry_for_test(xref_data, 1, count_offset, 0)
  pdf_async_io_push_xref_stream_entry_for_test(
    xref_data, 1, object_stream_offset, 0,
  )
  pdf_async_io_push_xref_stream_entry_for_test(xref_data, 0, 0, 0)
  pdf_async_io_push_xref_stream_entry_for_test(xref_data, 1, first_offset, 0)
  pdf_async_io_push_xref_stream_entry_for_test(xref_data, 1, xref_offset, 0)
  pdf_async_io_push_xref_stream_entry_for_test(xref_data, 2, 3, 0)
  let xref_stream = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (
        pdf_async_io_name_for_test("/Type"),
        PdfNameObject(pdf_async_io_name_for_test("/XRef")),
      ),
      (pdf_async_io_name_for_test("/Size"), PdfInteger(8)),
      (pdf_async_io_name_for_test("/Root"), PdfIndirect(1)),
      (
        pdf_async_io_name_for_test("/W"),
        PdfArray([PdfInteger(1), PdfInteger(4), PdfInteger(2)]),
      ),
      (pdf_async_io_name_for_test("/Length"), PdfInteger(xref_data.length())),
    ]),
    StreamGot(Bytes::from_array(xref_data)),
  )
  pdf_async_io_write_indirect_object_for_test(output, 6, xref_stream)
  pdf_async_io_push_ascii_for_test(output, "startxref\n0\n%%EOF\n")
  Bytes::from_array(output)
}

///|
fn pdf_async_io_indirect_object_stream_filter_bad_startxref_for_test() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  pdf_async_io_push_ascii_for_test(output, "%PDF-1.5\n")
  let catalog_offset = output.length()
  pdf_async_io_write_indirect_object_for_test(
    output,
    1,
    @pdflite.pdf_dictionary([
      (
        pdf_async_io_name_for_test("/Type"),
        PdfNameObject(pdf_async_io_name_for_test("/Catalog")),
      ),
    ]),
  )
  let filter_offset = output.length()
  pdf_async_io_write_indirect_object_for_test(
    output,
    2,
    PdfNameObject(pdf_async_io_name_for_test("/ASCIIHexDecode")),
  )
  let object_stream_data : Array[Byte] = []
  pdf_async_io_push_ascii_for_test(object_stream_data, "5 0 ")
  let first = object_stream_data.length()
  pdf_async_io_push_ascii_for_test(object_stream_data, "<< /Answer 42 >>")
  let encoded_object_stream = @pdflite.pdf_ascii_hex_encode(
    Bytes::from_array(object_stream_data),
  )
  let object_stream_offset = output.length()
  pdf_async_io_push_ascii_for_test(output, "3 0 obj\n")
  pdf_async_io_push_ascii_for_test(output, "<< /Type /ObjStm /N 1 /First ")
  pdf_async_io_push_ascii_for_test(output, first.to_string())
  pdf_async_io_push_ascii_for_test(output, " /Filter 2 0 R /Length ")
  pdf_async_io_push_ascii_for_test(
    output,
    encoded_object_stream.length().to_string(),
  )
  pdf_async_io_push_ascii_for_test(output, " >>\nstream\n")
  for byte in encoded_object_stream {
    output.push(byte)
  }
  pdf_async_io_push_ascii_for_test(output, "\nendstream\nendobj\n")
  let xref_offset = output.length()
  let xref_data : Array[Byte] = []
  pdf_async_io_push_xref_stream_entry_for_test(xref_data, 0, 0, 65535)
  pdf_async_io_push_xref_stream_entry_for_test(xref_data, 1, catalog_offset, 0)
  pdf_async_io_push_xref_stream_entry_for_test(xref_data, 1, filter_offset, 0)
  pdf_async_io_push_xref_stream_entry_for_test(
    xref_data, 1, object_stream_offset, 0,
  )
  pdf_async_io_push_xref_stream_entry_for_test(xref_data, 1, xref_offset, 0)
  pdf_async_io_push_xref_stream_entry_for_test(xref_data, 2, 3, 0)
  let xref_stream = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (
        pdf_async_io_name_for_test("/Type"),
        PdfNameObject(pdf_async_io_name_for_test("/XRef")),
      ),
      (pdf_async_io_name_for_test("/Size"), PdfInteger(6)),
      (pdf_async_io_name_for_test("/Root"), PdfIndirect(1)),
      (
        pdf_async_io_name_for_test("/W"),
        PdfArray([PdfInteger(1), PdfInteger(4), PdfInteger(2)]),
      ),
      (pdf_async_io_name_for_test("/Length"), PdfInteger(xref_data.length())),
    ]),
    StreamGot(Bytes::from_array(xref_data)),
  )
  pdf_async_io_write_indirect_object_for_test(output, 4, xref_stream)
  pdf_async_io_push_ascii_for_test(output, "startxref\n0\n%%EOF\n")
  Bytes::from_array(output)
}

///|
fn pdf_async_io_encrypted_object_stream_pdf_for_test(
  user_password : BytesView,
  owner_password : BytesView,
  denied : ArrayView[@pdflite.PdfPermission],
) -> @pdflite.PdfBytes raise {
  let secret = pdf_async_io_secret_object_for_test(
    "async encrypted object stream",
  )
  let object_stream_data : Array[Byte] = []
  pdf_async_io_push_ascii_for_test(object_stream_data, "2 0 ")
  let first = object_stream_data.length()
  for byte in @pdflite.pdf_write_object(secret) {
    object_stream_data.push(byte)
  }
  let object_stream = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (
        pdf_async_io_name_for_test("/Type"),
        PdfNameObject(pdf_async_io_name_for_test("/ObjStm")),
      ),
      (pdf_async_io_name_for_test("/N"), PdfInteger(1)),
      (pdf_async_io_name_for_test("/First"), PdfInteger(first)),
      (
        pdf_async_io_name_for_test("/Length"),
        PdfInteger(object_stream_data.length()),
      ),
    ]),
    StreamGot(Bytes::from_array(object_stream_data)),
  )
  let doc = @pdflite.pdf_document_empty()
  doc.set_version(1, 5)
  doc.set_root(1)
  doc.add_object_given_number(
    1,
    @pdflite.pdf_dictionary([
      (
        pdf_async_io_name_for_test("/Type"),
        PdfNameObject(pdf_async_io_name_for_test("/Catalog")),
      ),
      (pdf_async_io_name_for_test("/Payload"), PdfIndirect(2)),
    ]),
  )
  doc.add_object_given_number(3, object_stream)
  let encrypted = try! doc.encrypt_128bit_aesv2_with_iv_provider(
    user_password,
    owner_password,
    denied,
    @pdflite.pdf_deterministic_aes_iv_provider_from_seed(
      @ascii.encode("async-object-stream-reader"),
    ),
    encrypt_metadata=false,
    file_id=@ascii.encode("async-objstm-id"),
  )
  let encrypt_number = match
    encrypted
    .trailer_dict()
    .lookup_immediate(pdf_async_io_name_for_test("/Encrypt")) {
    Some(PdfIndirect(number)) => number
    _ => fail("expected encrypted object reference")
  }
  let trailer_id = match
    encrypted.trailer_dict().lookup_immediate(pdf_async_io_name_for_test("/ID")) {
    Some(id) => id
    None => fail("expected encrypted trailer ID")
  }

  let output : Array[Byte] = []
  pdf_async_io_push_ascii_for_test(output, "%PDF-1.5\n")
  let catalog_offset = output.length()
  for
    byte in @pdflite.pdf_write_indirect_object({
      number: 1,
      generation: 0,
      object: encrypted.lookup_object_or_null(1),
    }) {
    output.push(byte)
  }
  output.push((10).to_byte())
  let object_stream_offset = output.length()
  for
    byte in @pdflite.pdf_write_indirect_object({
      number: 3,
      generation: 0,
      object: encrypted.lookup_object_or_null(3),
    }) {
    output.push(byte)
  }
  output.push((10).to_byte())
  let encrypt_offset = output.length()
  for
    byte in @pdflite.pdf_write_indirect_object({
      number: encrypt_number,
      generation: 0,
      object: encrypted.lookup_object_or_null(encrypt_number),
    }) {
    output.push(byte)
  }
  output.push((10).to_byte())

  let xref_stream_number = 5
  let xref_offset = output.length()
  let xref_data : Array[Byte] = []
  pdf_async_io_push_xref_stream_entry_for_test(xref_data, 0, 0, 65535)
  pdf_async_io_push_xref_stream_entry_for_test(xref_data, 1, catalog_offset, 0)
  pdf_async_io_push_xref_stream_entry_for_test(xref_data, 2, 3, 0)
  pdf_async_io_push_xref_stream_entry_for_test(
    xref_data, 1, object_stream_offset, 0,
  )
  pdf_async_io_push_xref_stream_entry_for_test(xref_data, 1, encrypt_offset, 0)
  pdf_async_io_push_xref_stream_entry_for_test(xref_data, 1, xref_offset, 0)
  let xref_stream = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (
        pdf_async_io_name_for_test("/Type"),
        PdfNameObject(pdf_async_io_name_for_test("/XRef")),
      ),
      (pdf_async_io_name_for_test("/Size"), PdfInteger(6)),
      (pdf_async_io_name_for_test("/Root"), PdfIndirect(1)),
      (pdf_async_io_name_for_test("/Encrypt"), PdfIndirect(encrypt_number)),
      (pdf_async_io_name_for_test("/ID"), trailer_id),
      (
        pdf_async_io_name_for_test("/W"),
        PdfArray([PdfInteger(1), PdfInteger(4), PdfInteger(2)]),
      ),
      (pdf_async_io_name_for_test("/Length"), PdfInteger(xref_data.length())),
    ]),
    StreamGot(Bytes::from_array(xref_data)),
  )
  for
    byte in @pdflite.pdf_write_indirect_object({
      number: xref_stream_number,
      generation: 0,
      object: xref_stream,
    }) {
    output.push(byte)
  }
  pdf_async_io_push_ascii_for_test(output, "\nstartxref\n")
  pdf_async_io_push_ascii_for_test(output, xref_offset.to_string())
  pdf_async_io_push_ascii_for_test(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
fn pdf_async_io_encrypted_xref_stream_missing_object_stream_for_test() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  pdf_async_io_push_ascii_for_test(output, "%PDF-1.5\n")
  let catalog_offset = output.length()
  pdf_async_io_push_ascii_for_test(
    output, "1 0 obj\n<< /Type /Catalog /Payload 2 0 R >>\nendobj\n",
  )
  let xref_offset = output.length()
  let xref_data : Array[Byte] = []
  pdf_async_io_push_xref_stream_entry_for_test(xref_data, 0, 0, 65535)
  pdf_async_io_push_xref_stream_entry_for_test(xref_data, 1, catalog_offset, 0)
  pdf_async_io_push_xref_stream_entry_for_test(xref_data, 2, 7, 0)
  pdf_async_io_push_xref_stream_entry_for_test(xref_data, 1, xref_offset, 0)
  pdf_async_io_push_ascii_for_test(output, "3 0 obj\n")
  pdf_async_io_push_ascii_for_test(output, "<< /Type /XRef /Length ")
  pdf_async_io_push_ascii_for_test(output, xref_data.length().to_string())
  pdf_async_io_push_ascii_for_test(
    output, " /Size 4 /Root 1 0 R /Encrypt << /Filter /Standard >> /W [1 4 2] >>\nstream\n",
  )
  for byte in xref_data {
    output.push(byte)
  }
  pdf_async_io_push_ascii_for_test(output, "\nendstream\nendobj\nstartxref\n")
  pdf_async_io_push_ascii_for_test(output, xref_offset.to_string())
  pdf_async_io_push_ascii_for_test(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
fn pdf_async_io_assert_decrypted_object_stream_for_test(
  decrypted : @pdflite.PdfDecryptionResult,
  denied : Array[@pdflite.PdfPermission],
) -> Unit raise {
  @test.assert_eq(decrypted.denied_permissions, denied)
  @test.assert_eq(
    decrypted.document
    .catalog()
    .lookup_immediate(pdf_async_io_name_for_test("/Payload")),
    Some(PdfIndirect(2)),
  )
  @test.assert_eq(
    decrypted.document.lookup_object_or_null(2),
    pdf_async_io_secret_object_for_test("async encrypted object stream"),
  )
}

///|
fn pdf_async_io_secret_document_for_test(
  text : String,
) -> @pdflite.PdfDocument raise @pdflite.PdfError {
  let document = @pdflite.pdf_minimum_valid_pdf()
  document.add_object_given_number(
    41,
    pdf_async_io_secret_object_for_test(text),
  )
  document
}

///|
fn pdf_async_io_decryption_result_for_test(
  result : @pdflite.PdfDecryptionResult?,
) -> @pdflite.PdfDecryptionResult raise {
  match result {
    Some(result) => result
    None => fail("expected decrypted async file")
  }
}

///|
async fn pdf_async_io_assert_encrypted_file_secret_for_test(
  path : String,
  owner_password : String,
  denied : Array[@pdflite.PdfPermission],
  text : String,
) -> Unit {
  let decrypted = pdf_async_io_decryption_result_for_test(
    pdf_read_document_from_file_with_passwords(
      path,
      owner_password=Some(@ascii.encode(owner_password)),
    ),
  )
  @test.assert_eq(try! decrypted.document.endpage(), 1)
  @test.assert_eq(decrypted.denied_permissions, denied)
  @test.assert_eq(
    decrypted.document.lookup_object_or_null(41),
    pdf_async_io_secret_object_for_test(text),
  )
}

///|
async test "async file wrappers write and read PDF documents" {
  let path = pdf_async_io_test_path_for_test("roundtrip")
  pdf_async_io_remove_if_exists_for_test(path)
  let original = try! @pdflite.pdf_minimum_valid_pdf()
  pdf_write_document_to_file(original, path)
  let loaded = pdf_read_document_from_file(path)
  @test.assert_eq(pdf_read_header_from_file(path), { major: 1, minor: 0 })
  @test.assert_eq(pdf_is_linearized_file(path), false)
  pdf_async_io_remove_if_exists_for_test(path)
  @test.assert_eq(try! loaded.endpage(), 1)
  @test.assert_eq(loaded.version(), original.version())
}

///|
async test "async draw control image file wrappers read path specs" {
  let jpeg_path = pdf_async_io_test_path_for_test("draw_jpeg")
  let png_path = pdf_async_io_test_path_for_test("draw_png")
  let jpeg2000_path = pdf_async_io_test_path_for_test("draw_jpeg2000")
  pdf_async_io_remove_if_exists_for_test(jpeg_path)
  pdf_async_io_remove_if_exists_for_test(png_path)
  pdf_async_io_remove_if_exists_for_test(jpeg2000_path)
  let jpeg = pdf_async_io_jpeg_for_test()
  let (png, png_idat) = pdf_async_io_png_rgb_for_test()
  let jpeg2000 = pdf_async_io_jpeg2000_for_test()
  @fs.write_file(jpeg_path, jpeg, create=0o644)
  @fs.write_file(png_path, png, create=0o644)
  @fs.write_file(jpeg2000_path, jpeg2000, create=0o644)

  let document = @pdflite.pdf_document_empty()
  let control = @pdflite.pdf_draw_control_new()
  try! pdf_draw_control_add_jpeg_file(control, "J0=" + jpeg_path)
  try! pdf_draw_control_add_png_file(control, document, "P0=" + png_path)
  try! pdf_draw_control_add_jpeg2000_file(control, "JP0=" + jpeg2000_path)
  pdf_async_io_remove_if_exists_for_test(jpeg_path)
  pdf_async_io_remove_if_exists_for_test(png_path)
  pdf_async_io_remove_if_exists_for_test(jpeg2000_path)

  let ops = control.ops()
  @test.assert_eq(ops.length(), 3)
  guard ops[0] is PdfDrawImageXObject("J0", PdfStreamObject(jpeg_stream)) else {
    fail("expected JPEG image XObject op")
  }
  @test.assert_eq(
    jpeg_stream.dictionary.lookup_immediate(
      pdf_async_io_name_for_test("/Filter"),
    ),
    Some(PdfNameObject(pdf_async_io_name_for_test("/DCTDecode"))),
  )
  @test.assert_eq(
    jpeg_stream.dictionary.lookup_immediate(
      pdf_async_io_name_for_test("/Width"),
    ),
    Some(PdfInteger(400)),
  )
  @test.assert_eq(jpeg_stream.data, StreamGot(jpeg))

  guard ops[1] is PdfDrawImageXObject("P0", PdfStreamObject(png_stream)) else {
    fail("expected PNG image XObject op")
  }
  @test.assert_eq(
    png_stream.dictionary.lookup_immediate(
      pdf_async_io_name_for_test("/Filter"),
    ),
    Some(PdfNameObject(pdf_async_io_name_for_test("/FlateDecode"))),
  )
  @test.assert_eq(
    png_stream.dictionary.lookup_immediate(
      pdf_async_io_name_for_test("/Height"),
    ),
    Some(PdfInteger(1)),
  )
  @test.assert_eq(png_stream.data, StreamGot(png_idat))

  guard ops[2] is PdfDrawImageXObject("JP0", PdfStreamObject(jp2_stream)) else {
    fail("expected JPEG2000 image XObject op")
  }
  @test.assert_eq(
    jp2_stream.dictionary.lookup_immediate(
      pdf_async_io_name_for_test("/Filter"),
    ),
    Some(PdfNameObject(pdf_async_io_name_for_test("/JPXDecode"))),
  )
  @test.assert_eq(
    jp2_stream.dictionary.lookup_immediate(
      pdf_async_io_name_for_test("/Height"),
    ),
    Some(PdfInteger(300)),
  )
  @test.assert_eq(jp2_stream.data, StreamGot(jpeg2000))
}

///|
async test "async file wrappers load Standard 14 substitute font files" {
  let directory = pdf_async_io_build_dir_for_test()
  let helvetica_path = directory + "/NimbusSans-Regular.ttf"
  let times_path = directory + "/NimbusRoman-Bold.ttf"
  pdf_async_io_remove_if_exists_for_test(helvetica_path)
  pdf_async_io_remove_if_exists_for_test(times_path)
  let helvetica_bytes = @ascii.encode("fake helvetica substitute")
  let times_bytes = @ascii.encode("fake times substitute")
  @fs.write_file(helvetica_path, helvetica_bytes, create=0o644)
  @fs.write_file(times_path, times_bytes, create=0o644)
  let (loaded_helvetica, helvetica_name) = pdf_load_standard_font_substitute_file(
    directory,
    PdfHelvetica,
  )
  let (loaded_times, times_name) = pdf_load_standard_font_substitute_file(
    directory + "/",
    PdfTimesBold,
  )
  let (loaded_alias, alias_name) = pdf_load_substitute(directory, PdfHelvetica)
  pdf_async_io_remove_if_exists_for_test(helvetica_path)
  pdf_async_io_remove_if_exists_for_test(times_path)
  @test.assert_eq(loaded_helvetica, helvetica_bytes)
  @test.assert_eq(helvetica_name, "NimbusSans-Regular")
  @test.assert_eq(loaded_times, times_bytes)
  @test.assert_eq(times_name, "NimbusRoman-Bold")
  @test.assert_eq(loaded_alias, helvetica_bytes)
  @test.assert_eq(alias_name, "NimbusSans-Regular")
}

///|
async test "async file wrappers extract embedded font files" {
  let document = pdf_async_io_font_extraction_document_for_test()
  let output_path = pdf_async_io_test_path_for_test("fontfile")
  let missing_path = pdf_async_io_test_path_for_test("fontfile_missing")
  pdf_async_io_remove_if_exists_for_test(output_path)
  pdf_async_io_remove_if_exists_for_test(missing_path)

  try! pdf_extract_fontfile_to_file(document, 1, "/F1", output_path)
  @test.assert_eq(
    @fs.read_file(output_path).binary(),
    @ascii.encode("embedded-font"),
  )
  let missing : Result[Unit, Error] = try? pdf_extract_fontfile_to_file(
    document, 1, "/FNo", missing_path,
  )
  guard missing
    is Err(
      @pdflite.PdfError::SoftError(
        "extract_fontfile: unsupported or unfound font"
      )
    ) else {
    fail("expected unsupported or unfound font")
  }
  @test.assert_eq(@fs.exists(missing_path), false)

  pdf_async_io_remove_if_exists_for_test(output_path)
  pdf_async_io_remove_if_exists_for_test(missing_path)
}

///|
async test "async draw control image file wrappers reject malformed specs" {
  let document = @pdflite.pdf_document_empty()
  let control = @pdflite.pdf_draw_control_new()
  let bad_jpeg : Result[Unit, Error] = try? pdf_draw_control_add_jpeg_file(
    control, "bad",
  )
  guard bad_jpeg
    is Err(@pdflite.PdfError::SoftError("addjpeg: bad file specification")) else {
    fail("expected bad JPEG file spec")
  }
  let bad_png : Result[Unit, Error] = try? pdf_draw_control_add_png_file(
    control, document, "name=one=two",
  )
  guard bad_png
    is Err(@pdflite.PdfError::SoftError("addpng: bad file specification")) else {
    fail("expected bad PNG file spec")
  }
  let bad_jpeg2000 : Result[Unit, Error] = try? pdf_draw_control_add_jpeg2000_file(
    control, "bad",
  )
  guard bad_jpeg2000
    is Err(@pdflite.PdfError::SoftError("addjpeg2000: bad file specification")) else {
    fail("expected bad JPEG2000 file spec")
  }
}

///|
async test "async file wrappers build portfolios from file paths" {
  let first_path = pdf_async_io_test_path_for_test("portfolio_first")
  let second_path = pdf_async_io_test_path_for_test("portfolio_second")
  pdf_async_io_remove_if_exists_for_test(first_path)
  pdf_async_io_remove_if_exists_for_test(second_path)
  @fs.write_file(first_path, @ascii.encode("alpha"), create=0o644)
  @fs.write_file(second_path, @ascii.encode("beta"), create=0o644)
  let portfolio = try! pdf_portfolio_from_files(
    try! @pdflite.pdf_minimum_valid_pdf(),
    [
      pdf_portfolio_file_entry(
        first_path,
        relationship=Some("Data"),
        description=Some("Alpha file"),
      ),
      pdf_portfolio_file_entry(second_path),
    ],
    mod_date=Some(@ascii.encode("D:20240102030405")),
  )
  pdf_async_io_remove_if_exists_for_test(first_path)
  pdf_async_io_remove_if_exists_for_test(second_path)
  let catalog = try! portfolio.catalog()
  guard portfolio.lookup_direct(pdf_async_io_name_for_test("/Names"), catalog)
    is Some(names) else {
    fail("expected root Names dictionary")
  }
  guard portfolio.lookup_direct(
      pdf_async_io_name_for_test("/EmbeddedFiles"),
      names,
    )
    is Some(tree) else {
    fail("expected EmbeddedFiles name tree")
  }
  let entries = portfolio.read_name_tree(tree)
  @test.assert_eq(entries.length(), 2)
  @test.assert_eq(entries[0].0, @ascii.encode("0/" + first_path))
  @test.assert_eq(entries[1].0, @ascii.encode("1/" + second_path))
  let first_spec = portfolio.direct(entries[0].1)
  @test.assert_eq(
    portfolio.lookup_direct(pdf_async_io_name_for_test("/Desc"), first_spec),
    Some(PdfString(@ascii.encode("Alpha file"))),
  )
  @test.assert_eq(
    portfolio.lookup_direct(
      pdf_async_io_name_for_test("/AFRelationship"),
      first_spec,
    ),
    Some(PdfNameObject(pdf_async_io_name_for_test("/Data"))),
  )
  guard portfolio.lookup_direct(pdf_async_io_name_for_test("/EF"), first_spec)
    is Some(ef) else {
    fail("expected EF dictionary")
  }
  guard portfolio.lookup_direct(pdf_async_io_name_for_test("/F"), ef)
    is Some(stream) else {
    fail("expected embedded file stream")
  }
  @test.assert_eq(try! stream.stream_bytes(), @ascii.encode("alpha"))
  guard portfolio.lookup_direct(
      pdf_async_io_name_for_test("/Collection"),
      catalog,
    )
    is Some(collection) else {
    fail("expected portfolio collection")
  }
  @test.assert_eq(
    portfolio.lookup_direct(pdf_async_io_name_for_test("/View"), collection),
    Some(PdfNameObject(pdf_async_io_name_for_test("/T"))),
  )
}

///|
async test "async file wrappers attach files from paths" {
  let path = pdf_async_io_test_path_for_test("attached_source")
  pdf_async_io_remove_if_exists_for_test(path)
  @fs.write_file(path, @ascii.encode("attached bytes"), create=0o644)
  let document = try! pdf_attach_file_from_path(
    try! @pdflite.pdf_minimum_valid_pdf(),
    path,
    relationship=Some("Data"),
    description=Some("Path attachment"),
  )
  pdf_async_io_remove_if_exists_for_test(path)
  @test.assert_eq(document.version(), (1, 4))
  @test.assert_eq(try! document.list_attached_files(), [
    {
      name: pdf_async_io_basename_for_test(path),
      pagenumber: 0,
      data: Some(@ascii.encode("attached bytes")),
      description: Some("Path attachment"),
      relationship: Some("/Data"),
    },
  ])
}

///|
fn pdf_async_io_assert_cpdf_source_attachment_for_test(
  document : @pdflite.PdfDocument,
  payload : @pdflite.PdfBytes,
  version : (Int, Int),
) -> Unit raise {
  @test.assert_eq(document.endpage(), 1)
  @test.assert_eq(document.version(), version)
  @test.assert_eq(try! document.list_attached_files(), [
    {
      name: "README.md",
      pagenumber: 0,
      data: Some(payload),
      description: Some("cpdf source README"),
      relationship: Some("/Source"),
    },
  ])
  @test.assert_eq(try! document.size_attached_files(), payload.length())
}

///|
fn pdf_async_io_assert_cpdf_source_portfolio_entry_for_test(
  document : @pdflite.PdfDocument,
  file_spec : @pdflite.PdfObject,
  basename : String,
  payload : @pdflite.PdfBytes,
  mod_date : @pdflite.PdfBytes,
) -> Unit raise {
  @test.assert_eq(
    document.lookup_direct(pdf_async_io_name_for_test("/F"), file_spec),
    Some(PdfString(@ascii.encode(basename))),
  )
  @test.assert_eq(
    document.lookup_direct(pdf_async_io_name_for_test("/UF"), file_spec),
    Some(PdfString(@ascii.encode(basename))),
  )
  guard document.lookup_direct(pdf_async_io_name_for_test("/EF"), file_spec)
    is Some(ef) else {
    fail("expected cpdf source portfolio EF dictionary")
  }
  guard document.lookup_direct(pdf_async_io_name_for_test("/F"), ef)
    is Some(stream) else {
    fail("expected cpdf source portfolio embedded file stream")
  }
  @test.assert_eq(try! stream.stream_bytes(), payload)
  guard stream is PdfStreamObject(stream_object) else {
    fail("expected cpdf source portfolio stream object")
  }
  guard document.lookup_direct(
      pdf_async_io_name_for_test("/Params"),
      stream_object.dictionary,
    )
    is Some(params) else {
    fail("expected cpdf source portfolio stream params")
  }
  @test.assert_eq(
    document.lookup_direct(pdf_async_io_name_for_test("/ModDate"), params),
    Some(PdfString(mod_date)),
  )
  @test.assert_eq(
    document.lookup_direct(pdf_async_io_name_for_test("/Size"), params),
    Some(PdfInteger(payload.length())),
  )
}

///|
fn pdf_async_io_assert_cpdf_source_portfolio_for_test(
  document : @pdflite.PdfDocument,
  readme_path : String,
  readme_payload : @pdflite.PdfBytes,
  changes_path : String,
  changes_payload : @pdflite.PdfBytes,
  mod_date : @pdflite.PdfBytes,
) -> Unit raise {
  @test.assert_eq(document.endpage(), 1)
  let catalog = document.catalog()
  guard document.lookup_direct(pdf_async_io_name_for_test("/Names"), catalog)
    is Some(names) else {
    fail("expected cpdf source portfolio Names dictionary")
  }
  guard document.lookup_direct(
      pdf_async_io_name_for_test("/EmbeddedFiles"),
      names,
    )
    is Some(tree) else {
    fail("expected cpdf source portfolio EmbeddedFiles name tree")
  }
  let entries = document.read_name_tree(tree)
  @test.assert_eq(entries.length(), 2)
  @test.assert_eq(entries[0].0, @ascii.encode("0/" + readme_path))
  @test.assert_eq(entries[1].0, @ascii.encode("1/" + changes_path))
  let readme_spec = document.direct(entries[0].1)
  @test.assert_eq(
    document.lookup_direct(pdf_async_io_name_for_test("/Desc"), readme_spec),
    Some(PdfString(@ascii.encode("cpdf source README"))),
  )
  @test.assert_eq(
    document.lookup_direct(
      pdf_async_io_name_for_test("/AFRelationship"),
      readme_spec,
    ),
    Some(PdfNameObject(pdf_async_io_name_for_test("/Source"))),
  )
  pdf_async_io_assert_cpdf_source_portfolio_entry_for_test(
    document, readme_spec, "README.md", readme_payload, mod_date,
  )
  let changes_spec = document.direct(entries[1].1)
  pdf_async_io_assert_cpdf_source_portfolio_entry_for_test(
    document, changes_spec, "Changes.txt", changes_payload, mod_date,
  )
  guard document.lookup_direct(
      pdf_async_io_name_for_test("/Collection"),
      catalog,
    )
    is Some(collection) else {
    fail("expected cpdf source portfolio collection")
  }
  @test.assert_eq(
    document.lookup_direct(pdf_async_io_name_for_test("/View"), collection),
    Some(PdfNameObject(pdf_async_io_name_for_test("/T"))),
  )
}

///|
async test "async file wrappers attach and portfolio cpdf source files" {
  let hello_path = pdf_async_io_repo_path_for_test(
    ".repos/cpdf-source/hello.pdf",
  )
  let readme_path = pdf_async_io_repo_path_for_test(
    ".repos/cpdf-source/README.md",
  )
  let changes_path = pdf_async_io_repo_path_for_test(
    ".repos/cpdf-source/Changes.txt",
  )
  if @fs.exists(hello_path) &&
    @fs.exists(readme_path) &&
    @fs.exists(changes_path) {
    let readme_payload = @fs.read_file(readme_path).binary()
    let changes_payload = @fs.read_file(changes_path).binary()
    let base = pdf_read_document_from_file(hello_path)
    @test.assert_eq(try! base.endpage(), 1)
    @test.assert_eq(
      @ascii.decode_lossy(try! base.test_extract_text([1])).contains(
        "Hello, World!",
      ),
      true,
    )

    let attached = try! pdf_attach_file_from_path(
      base,
      readme_path,
      relationship=Some("Source"),
      description=Some("cpdf source README"),
    )
    pdf_async_io_assert_cpdf_source_attachment_for_test(
      attached,
      readme_payload,
      (1, 4),
    )
    let attached_path = pdf_async_io_test_path_for_test(
      "cpdf_source_attachment",
    )
    pdf_async_io_remove_if_exists_for_test(attached_path)
    pdf_write_document_to_file_with_compressed_xref_stream(
      attached, attached_path,
    )
    let attached_reparsed = pdf_read_document_from_file(attached_path)
    pdf_async_io_remove_if_exists_for_test(attached_path)
    pdf_async_io_assert_cpdf_source_attachment_for_test(
      attached_reparsed,
      readme_payload,
      (1, 5),
    )

    let dumped_path = pdf_async_io_build_dir_for_test() + "/README.md"
    pdf_async_io_remove_if_exists_for_test(dumped_path)
    pdf_dump_attached_files_to_directory(
      attached_reparsed,
      pdf_async_io_build_dir_for_test(),
    )
    @test.assert_eq(@fs.read_file(dumped_path).binary(), readme_payload)
    pdf_async_io_remove_if_exists_for_test(dumped_path)

    let mod_date = @ascii.encode("D:20240102030405")
    let portfolio = try! pdf_portfolio_from_files(
      base,
      [
        pdf_portfolio_file_entry(
          readme_path,
          relationship=Some("Source"),
          description=Some("cpdf source README"),
        ),
        pdf_portfolio_file_entry(changes_path),
      ],
      mod_date=Some(mod_date),
    )
    pdf_async_io_assert_cpdf_source_portfolio_for_test(
      portfolio, readme_path, readme_payload, changes_path, changes_payload, mod_date,
    )
    let portfolio_path = pdf_async_io_test_path_for_test(
      "cpdf_source_portfolio",
    )
    let recovered_path = pdf_async_io_test_path_for_test(
      "cpdf_source_portfolio_recovered",
    )
    pdf_async_io_remove_if_exists_for_test(portfolio_path)
    pdf_async_io_remove_if_exists_for_test(recovered_path)
    pdf_write_document_to_file_with_compressed_xref_stream(
      portfolio, portfolio_path,
    )
    let portfolio_reparsed = pdf_read_document_from_file(portfolio_path)
    pdf_async_io_assert_cpdf_source_portfolio_for_test(
      portfolio_reparsed, readme_path, readme_payload, changes_path, changes_payload,
      mod_date,
    )
    @fs.write_file(
      recovered_path,
      pdf_async_io_corrupt_final_startxref_pointer_for_test(
        @fs.read_file(portfolio_path).binary(),
      ),
      create=0o644,
    )
    let recovered = pdf_read_document_from_file(recovered_path)
    @test.assert_eq(recovered.first_xref(), 0)
    pdf_async_io_assert_cpdf_source_portfolio_for_test(
      recovered, readme_path, readme_payload, changes_path, changes_payload, mod_date,
    )
    pdf_async_io_remove_if_exists_for_test(portfolio_path)
    pdf_async_io_remove_if_exists_for_test(recovered_path)
  }
}

///|
async test "async file wrappers dump attached files to a directory" {
  let directory = pdf_async_io_build_dir_for_test()
  let document_output = directory + "/doc.txt"
  let page_output = directory + "/pagenote.bin"
  pdf_async_io_remove_if_exists_for_test(document_output)
  pdf_async_io_remove_if_exists_for_test(page_output)
  let base = try! @pdflite.pdf_minimum_valid_pdf()
  let with_document = try! base.attach_file(
    "doc?.txt",
    @ascii.encode("document attachment"),
  )
  let with_both = try! with_document.attach_file(
    "page:note.bin",
    @ascii.encode("page attachment"),
    page_number=Some(1),
  )
  pdf_dump_attached_files_to_directory(with_both, directory)
  @test.assert_eq(
    @fs.read_file(document_output).binary(),
    @ascii.encode("document attachment"),
  )
  @test.assert_eq(
    @fs.read_file(page_output).binary(),
    @ascii.encode("page attachment"),
  )
  pdf_async_io_remove_if_exists_for_test(document_output)
  pdf_async_io_remove_if_exists_for_test(page_output)
}

///|
async test "async metadata file wrappers set write and extract XML metadata" {
  let directory = pdf_async_io_build_dir_for_test()
  let input_path = directory + "/pdflite_metadata_input.xml"
  let output_path = directory + "/pdflite_metadata_output.xml"
  let main_path = directory + "/main.xml"
  let payload = @ascii.encode("<xmp>catalog metadata</xmp>")
  let stray_payload = @ascii.encode("<xmp>stray metadata</xmp>")
  pdf_async_io_remove_if_exists_for_test(input_path)
  pdf_async_io_remove_if_exists_for_test(output_path)
  pdf_async_io_remove_if_exists_for_test(main_path)
  @fs.write_file(input_path, payload, create=0o644)
  let document = try! pdf_set_metadata_from_file(
    false,
    input_path,
    try! @pdflite.pdf_minimum_valid_pdf(),
  )
  @test.assert_eq(try! document.metadata(), Some(payload))
  @test.assert_eq(document.version(), (1, 4))
  pdf_write_metadata_to_file(document, output_path)
  @test.assert_eq(@fs.read_file(output_path).binary(), payload)

  let with_stray = document.copy()
  let encoded = @pdflite.pdf_flate_encode(stray_payload)
  let stray_number = with_stray.add_object(
    @pdflite.pdf_stream(
      @pdflite.pdf_dictionary([
        (
          pdf_async_io_name_for_test("/Type"),
          PdfNameObject(pdf_async_io_name_for_test("/Metadata")),
        ),
        (
          pdf_async_io_name_for_test("/Filter"),
          PdfNameObject(pdf_async_io_name_for_test("/FlateDecode")),
        ),
        (pdf_async_io_name_for_test("/Length"), PdfInteger(encoded.length())),
      ]),
      StreamGot(encoded),
    ),
  )
  let stray_path = directory + "/obj" + stray_number.to_string() + ".xml"
  pdf_async_io_remove_if_exists_for_test(stray_path)
  pdf_extract_all_metadata_to_directory(with_stray, directory)
  @test.assert_eq(@fs.read_file(main_path).binary(), payload)
  @test.assert_eq(@fs.read_file(stray_path).binary(), stray_payload)
  pdf_async_io_remove_if_exists_for_test(input_path)
  pdf_async_io_remove_if_exists_for_test(output_path)
  pdf_async_io_remove_if_exists_for_test(main_path)
  pdf_async_io_remove_if_exists_for_test(stray_path)
}

///|
async test "async file wrappers fail dumping malformed attachment data" {
  let file_spec : @pdflite.PdfObject = PdfDictionary([
    (
      pdf_async_io_name_for_test("/Type"),
      PdfNameObject(pdf_async_io_name_for_test("/Filespec")),
    ),
    (pdf_async_io_name_for_test("/F"), PdfString(@ascii.encode("missing.bin"))),
  ])
  let annotation : @pdflite.PdfObject = PdfDictionary([
    (
      pdf_async_io_name_for_test("/Subtype"),
      PdfNameObject(pdf_async_io_name_for_test("/FileAttachment")),
    ),
    (
      pdf_async_io_name_for_test("/Contents"),
      PdfString(@ascii.encode("missing.bin")),
    ),
    (pdf_async_io_name_for_test("/FS"), file_spec),
  ])
  let page = {
    ..@pdflite.pdf_page_blank(@pdflite.paper_a4),
    rest: PdfDictionary([
      (pdf_async_io_name_for_test("/Annots"), PdfArray([annotation])),
    ]),
  }
  let document = try! @pdflite.pdf_minimum_valid_pdf().change_pages([page])
  let result : Result[Unit, Error] = try? pdf_dump_attached_files_to_directory(
    document,
    pdf_async_io_build_dir_for_test(),
  )
  guard result is Err(@pdflite.PdfError::DictionaryKeyNotFound(_)) else {
    fail("expected malformed attachment data to fail dumping")
  }
}

///|
async test "async file wrappers can write generated trailer IDs" {
  let path = pdf_async_io_test_path_for_test("generated_id")
  pdf_async_io_remove_if_exists_for_test(path)
  let original = try! @pdflite.pdf_minimum_valid_pdf()
  pdf_write_document_to_file_with_generated_id(
    original,
    path,
    mode=PdfWriteCompressedXRefStream,
  )
  let loaded = pdf_read_document_from_file(path)
  pdf_async_io_remove_if_exists_for_test(path)
  pdf_async_io_assert_generated_id_for_test(
    loaded.trailer_dict().lookup_immediate(pdf_async_io_name_for_test("/ID")),
  )
  @test.assert_eq(
    original.trailer_dict().lookup_immediate(pdf_async_io_name_for_test("/ID")),
    None,
  )
  @test.assert_eq(try! loaded.endpage(), 1)
}

///|
async test "async file wrappers can incrementally write generated trailer IDs" {
  let original_path = pdf_async_io_test_path_for_test("generated_id_original")
  let path = pdf_async_io_test_path_for_test("generated_id_update")
  pdf_async_io_remove_if_exists_for_test(original_path)
  pdf_async_io_remove_if_exists_for_test(path)
  let original = try! @pdflite.pdf_minimum_valid_pdf()
  pdf_write_document_to_file(original, original_path)
  pdf_write_document_incremental_update_to_file_with_generated_id(
    original_path,
    original,
    path,
    mode=PdfWriteCompressedXRefStream,
  )
  let rendered = @fs.read_file(path).binary()
  let loaded = pdf_read_document_from_file(path)
  pdf_async_io_remove_if_exists_for_test(original_path)
  pdf_async_io_remove_if_exists_for_test(path)
  @test.assert_eq(try! @pdflite.pdf_revisions_from_bytes(rendered), 2)
  pdf_async_io_assert_generated_id_for_test(
    loaded.trailer_dict().lookup_immediate(pdf_async_io_name_for_test("/ID")),
  )
  @test.assert_eq(
    original.trailer_dict().lookup_immediate(pdf_async_io_name_for_test("/ID")),
    None,
  )
  @test.assert_eq(try! loaded.endpage(), 1)
}

///|
async test "async file wrappers read checked-in CamlPDF fixture PDFs" {
  let logo_path = pdf_async_io_repo_path_for_test("fixtures/camlpdf/logo.pdf")
  let intro_path = pdf_async_io_repo_path_for_test(
    "fixtures/camlpdf/introduction_to_camlpdf.pdf",
  )
  let logo_roundtrip = pdf_async_io_test_path_for_test("logo_fixture")
  let intro_roundtrip = pdf_async_io_test_path_for_test("intro_fixture")
  let intro_decompressed_roundtrip = pdf_async_io_test_path_for_test(
    "intro_decompressed_fixture",
  )
  pdf_async_io_remove_if_exists_for_test(logo_roundtrip)
  pdf_async_io_remove_if_exists_for_test(intro_roundtrip)
  pdf_async_io_remove_if_exists_for_test(intro_decompressed_roundtrip)

  let logo = pdf_read_document_from_file(logo_path)
  @test.assert_eq(pdf_read_header_from_file(logo_path), { major: 1, minor: 4 })
  @test.assert_eq(pdf_is_linearized_file(logo_path), true)
  @test.assert_eq(logo.version(), (1, 4))
  @test.assert_eq(try! logo.endpage(), 1)
  pdf_write_document_to_file_with_compressed_xref_stream(logo, logo_roundtrip)
  let logo_reparsed = pdf_read_document_from_file(logo_roundtrip)
  @test.assert_eq(try! logo_reparsed.endpage(), 1)

  let intro = pdf_read_document_from_file(intro_path)
  @test.assert_eq(pdf_read_header_from_file(intro_path), { major: 1, minor: 5 })
  @test.assert_eq(intro.version(), (1, 5))
  pdf_async_io_assert_intro_fixture_text_for_test(intro)
  pdf_write_document_to_file_with_compressed_xref_stream(intro, intro_roundtrip)
  let intro_reparsed = pdf_read_document_from_file(intro_roundtrip)
  pdf_async_io_assert_intro_fixture_text_for_test(intro_reparsed)

  let intro_decompressed = intro.copy()
  intro_decompressed.pdf_decode_streams_until_unknown()
  pdf_write_document_to_file_with_compressed_xref_stream(
    intro_decompressed, intro_decompressed_roundtrip,
  )
  let intro_decompressed_reparsed = pdf_read_document_from_file(
    intro_decompressed_roundtrip,
  )
  pdf_async_io_assert_intro_fixture_text_for_test(intro_decompressed_reparsed)

  pdf_async_io_remove_if_exists_for_test(logo_roundtrip)
  pdf_async_io_remove_if_exists_for_test(intro_roundtrip)
  pdf_async_io_remove_if_exists_for_test(intro_decompressed_roundtrip)
}

///|
async test "async file wrappers incrementally update checked-in CamlPDF intro fixture" {
  let intro_path = pdf_async_io_repo_path_for_test(
    "fixtures/camlpdf/introduction_to_camlpdf.pdf",
  )
  let updated_path = pdf_async_io_test_path_for_test(
    "intro_fixture_incremental",
  )
  pdf_async_io_remove_if_exists_for_test(updated_path)

  let updated = pdf_read_document_from_file(intro_path)
  let added_object : @pdflite.PdfObject = PdfDictionary([
    (
      pdf_async_io_name_for_test("/Title"),
      PdfString(@ascii.encode("intro fixture incremental")),
    ),
  ])
  let added_number = updated.add_object(added_object)
  pdf_write_document_incremental_update_with_compressed_xref_stream_to_file(
    intro_path, updated, updated_path,
  )
  let revision_count = pdf_revisions_from_file(updated_path)
  let newest = pdf_read_document_revision_from_file(updated_path, 1)
  let older = pdf_read_document_revision_from_file(updated_path, 2)
  pdf_async_io_remove_if_exists_for_test(updated_path)

  @test.assert_eq(revision_count, 2)
  @test.assert_eq(newest.lookup_object_or_null(added_number), added_object)
  @test.assert_eq(older.lookup_object_or_null(added_number), PdfNull)
  pdf_async_io_assert_intro_fixture_text_for_test(newest)
  pdf_async_io_assert_intro_fixture_text_for_test(older)
}

///|
async test "async file wrappers reconstruct malformed incremental CamlPDF intro fixture" {
  let intro_path = pdf_async_io_repo_path_for_test(
    "fixtures/camlpdf/introduction_to_camlpdf.pdf",
  )
  let updated_path = pdf_async_io_test_path_for_test(
    "intro_incremental_bad_startxref_source",
  )
  let corrupted_path = pdf_async_io_test_path_for_test(
    "intro_incremental_bad_startxref_fixture",
  )
  let repaired_path = pdf_async_io_test_path_for_test(
    "intro_incremental_bad_startxref_repaired",
  )
  pdf_async_io_remove_if_exists_for_test(updated_path)
  pdf_async_io_remove_if_exists_for_test(corrupted_path)
  pdf_async_io_remove_if_exists_for_test(repaired_path)

  let updated = pdf_read_document_from_file(intro_path)
  let key_root = pdf_async_io_name_for_test("/Root")
  let key_payload = pdf_async_io_name_for_test("/Payload")
  let added_object : @pdflite.PdfObject = PdfDictionary([
    (
      pdf_async_io_name_for_test("/Title"),
      PdfString(@ascii.encode("intro fixture malformed incremental")),
    ),
  ])
  let added_number = updated.add_object(added_object)
  let new_root_number = updated.add_object(
    updated.catalog().add_dict_entry(key_payload, PdfIndirect(added_number)),
  )
  updated.set_root(new_root_number)
  updated.set_trailer_dict(
    updated
    .trailer_dict()
    .add_dict_entry(key_root, PdfIndirect(new_root_number)),
  )
  pdf_write_document_incremental_update_with_compressed_xref_stream_to_file(
    intro_path, updated, updated_path,
  )
  @test.assert_eq(pdf_revisions_from_file(updated_path), 2)
  let newest = pdf_read_document_revision_from_file(updated_path, 1)
  @test.assert_eq(newest.lookup_object_or_null(added_number), added_object)
  @test.assert_eq(
    newest.lookup_object_or_null(new_root_number),
    updated.catalog(),
  )
  @test.assert_eq(
    newest.catalog().lookup_immediate(key_payload),
    Some(PdfIndirect(added_number)),
  )
  let older = pdf_read_document_revision_from_file(updated_path, 2)
  @test.assert_eq(older.lookup_object_or_null(added_number), PdfNull)
  @test.assert_eq(older.lookup_object_or_null(new_root_number), PdfNull)
  pdf_async_io_assert_intro_fixture_text_for_test(older)

  let corrupted = pdf_async_io_corrupt_final_startxref_pointer_for_test(
    @fs.read_file(updated_path).binary(),
  )
  @fs.write_file(corrupted_path, corrupted, create=0o644)
  let recovered = pdf_read_document_from_file(corrupted_path)
  @test.assert_eq(recovered.first_xref(), 0)
  @test.assert_eq(recovered.lookup_object_or_null(added_number), added_object)
  @test.assert_eq(
    recovered.catalog().lookup_immediate(key_payload),
    Some(PdfIndirect(added_number)),
  )
  pdf_async_io_assert_intro_fixture_text_for_test(recovered)

  pdf_write_document_to_file_with_compressed_xref_stream(
    recovered, repaired_path,
  )
  let reparsed = pdf_read_document_from_file(repaired_path)
  @test.assert_eq(reparsed.first_xref() > 0, true)
  @test.assert_eq(reparsed.lookup_object_or_null(added_number), added_object)
  @test.assert_eq(
    reparsed.catalog().lookup_immediate(key_payload),
    Some(PdfIndirect(added_number)),
  )
  pdf_async_io_assert_intro_fixture_text_for_test(reparsed)

  pdf_async_io_remove_if_exists_for_test(updated_path)
  pdf_async_io_remove_if_exists_for_test(corrupted_path)
  pdf_async_io_remove_if_exists_for_test(repaired_path)
}

///|
async test "async file wrappers reconstruct checked-in CamlPDF logo fixture with bad startxref" {
  let logo_path = pdf_async_io_repo_path_for_test("fixtures/camlpdf/logo.pdf")
  let corrupted_path = pdf_async_io_test_path_for_test(
    "logo_bad_startxref_fixture",
  )
  let repaired_path = pdf_async_io_test_path_for_test(
    "logo_bad_startxref_repaired",
  )
  pdf_async_io_remove_if_exists_for_test(corrupted_path)
  pdf_async_io_remove_if_exists_for_test(repaired_path)

  let corrupted = pdf_async_io_corrupt_startxref_pointer_for_test(
    @fs.read_file(logo_path).binary(),
  )
  @fs.write_file(corrupted_path, corrupted, create=0o644)
  let recovered = pdf_read_document_from_file(corrupted_path)
  @test.assert_eq(recovered.version(), (1, 4))
  @test.assert_eq(recovered.first_xref(), 0)
  @test.assert_eq(recovered.endpage(), 1)

  pdf_write_document_to_file_with_compressed_xref_stream(
    recovered, repaired_path,
  )
  let reparsed = pdf_read_document_from_file(repaired_path)
  @test.assert_eq(reparsed.first_xref() > 0, true)
  @test.assert_eq(reparsed.endpage(), 1)

  pdf_async_io_remove_if_exists_for_test(corrupted_path)
  pdf_async_io_remove_if_exists_for_test(repaired_path)
}

///|
async test "async file wrappers reconstruct checked-in CamlPDF intro fixture with bad startxref" {
  let intro_path = pdf_async_io_repo_path_for_test(
    "fixtures/camlpdf/introduction_to_camlpdf.pdf",
  )
  let corrupted_path = pdf_async_io_test_path_for_test(
    "intro_bad_startxref_fixture",
  )
  let repaired_path = pdf_async_io_test_path_for_test(
    "intro_bad_startxref_repaired",
  )
  pdf_async_io_remove_if_exists_for_test(corrupted_path)
  pdf_async_io_remove_if_exists_for_test(repaired_path)

  let corrupted = pdf_async_io_corrupt_startxref_pointer_for_test(
    @fs.read_file(intro_path).binary(),
  )
  @fs.write_file(corrupted_path, corrupted, create=0o644)
  let recovered = pdf_read_document_from_file(corrupted_path)
  @test.assert_eq(recovered.version(), (1, 5))
  @test.assert_eq(recovered.first_xref(), 0)
  pdf_async_io_assert_intro_fixture_text_for_test(recovered)

  pdf_write_document_to_file_with_compressed_xref_stream(
    recovered, repaired_path,
  )
  let reparsed = pdf_read_document_from_file(repaired_path)
  @test.assert_eq(reparsed.first_xref() > 0, true)
  pdf_async_io_assert_intro_fixture_text_for_test(reparsed)

  pdf_async_io_remove_if_exists_for_test(corrupted_path)
  pdf_async_io_remove_if_exists_for_test(repaired_path)
}

///|
async test "async file wrappers write xref streams and read encrypted documents" {
  let xref_path = pdf_async_io_test_path_for_test("xref")
  let encrypted_path = pdf_async_io_test_path_for_test("encrypted_xref")
  pdf_async_io_remove_if_exists_for_test(xref_path)
  pdf_async_io_remove_if_exists_for_test(encrypted_path)
  let original = try! @pdflite.pdf_minimum_valid_pdf()
  pdf_write_document_to_file_with_xref_stream(original, xref_path)
  let loaded = pdf_read_document_from_file(xref_path)
  @test.assert_eq(loaded.version(), (1, 5))
  @test.assert_eq(try! loaded.endpage(), 1)

  let encrypted = try! original.encrypt_128bit_r4(
    @ascii.encode("user"),
    @ascii.encode("owner"),
    [PdfNoPrint],
    encrypt_metadata=true,
    file_id=@ascii.encode("async-doc-id"),
  )
  pdf_write_document_to_file_with_compressed_xref_stream(
    encrypted, encrypted_path,
  )
  guard pdf_read_document_from_file_with_passwords(
      encrypted_path,
      user_password=Some(@ascii.encode("bad")),
      owner_password=Some(@ascii.encode("owner")),
    )
    is Some(decrypted) else {
    fail("expected decrypted async file")
  }
  pdf_async_io_remove_if_exists_for_test(xref_path)
  pdf_async_io_remove_if_exists_for_test(encrypted_path)
  @test.assert_eq(try! decrypted.document.endpage(), 1)
  @test.assert_eq(decrypted.denied_permissions, [PdfNoPrint])
}

///|
async test "async file wrappers reconstruct physical page trees when object-stream bounds are malformed" {
  let malformed_path = pdf_async_io_test_path_for_test(
    "bad_object_stream_first_physical_pages",
  )
  pdf_async_io_remove_if_exists_for_test(malformed_path)
  let malformed = pdf_async_io_bad_first_object_stream_physical_page_tree_pdf_for_test()
  @fs.write_file(malformed_path, malformed, create=0o644)
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    @fs.read_file(malformed_path).binary(),
  )
  guard strict is Err(@pdflite.PdfError::StreamDataExpected) else {
    fail("expected malformed object-stream bounds to require reconstruction")
  }
  let recovered = pdf_read_document_from_file(malformed_path)
  pdf_async_io_remove_if_exists_for_test(malformed_path)
  @test.assert_eq(recovered.first_xref(), 0)
  @test.assert_eq(recovered.object_numbers(), [1, 2, 3, 5])
  @test.assert_eq(try! recovered.endpage(), 1)
  @test.assert_eq(try! recovered.page_reference_numbers(), [5])
}

///|
async test "async file wrappers do not reconstruct mismatched object-stream roots" {
  let path = pdf_async_io_test_path_for_test(
    "mismatched_objstm_root_physical_catalog",
  )
  pdf_async_io_remove_if_exists_for_test(path)
  @fs.write_file(
    path,
    pdf_async_io_mismatched_object_stream_root_physical_catalog_for_test(),
    create=0o644,
  )
  @test.assert_eq(pdf_read_header_from_file(path), { major: 1, minor: 5 })
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    @fs.read_file(path).binary(),
  )
  guard strict is Err(@pdflite.PdfError::XRefEntryExpected) else {
    fail("expected strict object-stream mismatch failure")
  }
  let public : Result[@pdflite.PdfDocument, Error] = try? pdf_read_document_from_file(
    path,
  )
  pdf_async_io_remove_if_exists_for_test(path)
  guard public is Err(@pdflite.PdfError::XRefEntryExpected) else {
    fail("expected object-stream mismatch to remain unrecoverable")
  }
}

///|
async test "async file wrappers reject invalid object-stream data slices" {
  let path = pdf_async_io_test_path_for_test("bad_objstm_first_payload")
  pdf_async_io_remove_if_exists_for_test(path)
  @fs.write_file(
    path,
    pdf_async_io_bad_first_object_stream_payload_for_test(),
    create=0o644,
  )
  @test.assert_eq(pdf_read_header_from_file(path), { major: 1, minor: 5 })
  let result : Result[@pdflite.PdfDocument, Error] = try? pdf_read_document_from_file(
    path,
  )
  pdf_async_io_remove_if_exists_for_test(path)
  guard result is Err(@pdflite.PdfError::StreamDataExpected) else {
    fail("expected invalid object-stream slice to remain unrecoverable")
  }
}

///|
async test "async file wrappers reject non-xref startxref objects" {
  let non_stream_path = pdf_async_io_test_path_for_test("startxref_non_stream")
  let wrong_stream_type_path = pdf_async_io_test_path_for_test(
    "startxref_wrong_stream_type",
  )
  let explicit_wrong_type_path = pdf_async_io_test_path_for_test(
    "startxref_explicit_wrong_xref_type",
  )
  let non_name_type_path = pdf_async_io_test_path_for_test(
    "startxref_non_name_xref_type",
  )
  pdf_async_io_remove_if_exists_for_test(non_stream_path)
  pdf_async_io_remove_if_exists_for_test(wrong_stream_type_path)
  pdf_async_io_remove_if_exists_for_test(explicit_wrong_type_path)
  pdf_async_io_remove_if_exists_for_test(non_name_type_path)

  @fs.write_file(
    non_stream_path,
    pdf_async_io_startxref_object_pdf_for_test("7"),
    create=0o644,
  )
  @fs.write_file(
    wrong_stream_type_path,
    pdf_async_io_startxref_object_pdf_for_test(
      "<< /Length 0 >>\nstream\n\nendstream",
    ),
    create=0o644,
  )
  @fs.write_file(
    explicit_wrong_type_path,
    pdf_async_io_xref_stream_with_type_for_test("/Catalog"),
    create=0o644,
  )
  @fs.write_file(
    non_name_type_path,
    pdf_async_io_xref_stream_with_type_for_test("99"),
    create=0o644,
  )

  let non_stream : Result[@pdflite.PdfDocument, Error] = try? pdf_read_document_from_file(
    non_stream_path,
  )
  let wrong_stream_type : Result[@pdflite.PdfDocument, Error] = try? pdf_read_document_from_file(
    wrong_stream_type_path,
  )
  let explicit_wrong_type : Result[@pdflite.PdfDocument, Error] = try? pdf_read_document_from_file(
    explicit_wrong_type_path,
  )
  let non_name_type : Result[@pdflite.PdfDocument, Error] = try? pdf_read_document_from_file(
    non_name_type_path,
  )
  pdf_async_io_remove_if_exists_for_test(non_stream_path)
  pdf_async_io_remove_if_exists_for_test(wrong_stream_type_path)
  pdf_async_io_remove_if_exists_for_test(explicit_wrong_type_path)
  pdf_async_io_remove_if_exists_for_test(non_name_type_path)

  guard non_stream is Err(@pdflite.PdfError::XRefExpected) else {
    fail("expected non-stream startxref object rejection")
  }
  guard wrong_stream_type is Err(@pdflite.PdfError::XRefExpected) else {
    fail("expected non-xref stream startxref object rejection")
  }
  guard explicit_wrong_type is Err(@pdflite.PdfError::XRefExpected) else {
    fail("expected explicit non-xref stream type rejection")
  }
  guard non_name_type is Err(@pdflite.PdfError::XRefExpected) else {
    fail("expected non-name xref stream type rejection")
  }
}

///|
async test "async file wrappers preserve linearized first-object markers" {
  let integer_path = pdf_async_io_test_path_for_test(
    "linearized_integer_marker",
  )
  let real_path = pdf_async_io_test_path_for_test("linearized_real_marker")
  let non_numeric_path = pdf_async_io_test_path_for_test(
    "linearized_non_numeric_marker",
  )
  let prev_path = pdf_async_io_test_path_for_test("linearized_prev_xref")
  pdf_async_io_remove_if_exists_for_test(integer_path)
  pdf_async_io_remove_if_exists_for_test(real_path)
  pdf_async_io_remove_if_exists_for_test(non_numeric_path)
  pdf_async_io_remove_if_exists_for_test(prev_path)
  @fs.write_file(
    integer_path,
    pdf_async_io_linearized_classic_pdf_for_test("1"),
    create=0o644,
  )
  @fs.write_file(
    real_path,
    pdf_async_io_linearized_classic_pdf_for_test("1.0"),
    create=0o644,
  )
  @fs.write_file(
    non_numeric_path,
    pdf_async_io_linearized_classic_pdf_for_test("/Name"),
    create=0o644,
  )
  @fs.write_file(
    prev_path,
    pdf_async_io_linearized_classic_pdf_with_prev_xref_for_test(),
    create=0o644,
  )
  let integer_doc = pdf_read_document_from_file(integer_path)
  let real_doc = pdf_read_document_from_file(real_path)
  let non_numeric_doc = pdf_read_document_from_file(non_numeric_path)
  @test.assert_eq(pdf_is_linearized_file(integer_path), true)
  @test.assert_eq(pdf_is_linearized_file(non_numeric_path), false)
  @test.assert_eq(pdf_revisions_from_file(integer_path), 1)
  @test.assert_eq(pdf_revisions_from_file(prev_path), 1)
  pdf_async_io_remove_if_exists_for_test(integer_path)
  pdf_async_io_remove_if_exists_for_test(real_path)
  pdf_async_io_remove_if_exists_for_test(non_numeric_path)
  pdf_async_io_remove_if_exists_for_test(prev_path)
  @test.assert_eq(integer_doc.was_linearized(), true)
  @test.assert_eq(integer_doc.root(), 2)
  @test.assert_eq(real_doc.was_linearized(), true)
  @test.assert_eq(non_numeric_doc.was_linearized(), false)
}

///|
async test "async file wrappers reconstruct hybrid XRefStm trailers" {
  let valid_path = pdf_async_io_test_path_for_test("hybrid_xrefstm")
  let bad_path = pdf_async_io_test_path_for_test("hybrid_xrefstm_bad_startxref")
  let compressed_path = pdf_async_io_test_path_for_test(
    "hybrid_compressed_xrefstm",
  )
  let compressed_bad_path = pdf_async_io_test_path_for_test(
    "hybrid_compressed_xrefstm_bad_startxref",
  )
  pdf_async_io_remove_if_exists_for_test(valid_path)
  pdf_async_io_remove_if_exists_for_test(bad_path)
  pdf_async_io_remove_if_exists_for_test(compressed_path)
  pdf_async_io_remove_if_exists_for_test(compressed_bad_path)
  @fs.write_file(
    valid_path,
    pdf_async_io_hybrid_xref_stream_pdf_for_test(None, false),
    create=0o644,
  )
  @fs.write_file(
    bad_path,
    pdf_async_io_hybrid_xref_stream_pdf_for_test(Some(0), false),
    create=0o644,
  )
  @fs.write_file(
    compressed_path,
    pdf_async_io_hybrid_xref_stream_pdf_for_test(None, true),
    create=0o644,
  )
  @fs.write_file(
    compressed_bad_path,
    pdf_async_io_hybrid_xref_stream_pdf_for_test(Some(0), true),
    create=0o644,
  )
  let valid = pdf_read_document_from_file(valid_path)
  let compressed = pdf_read_document_from_file(compressed_path)
  let strict_bad : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    @fs.read_file(bad_path).binary(),
  )
  let strict_compressed_bad : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    @fs.read_file(compressed_bad_path).binary(),
  )
  guard strict_bad is Err(_) else {
    fail("expected strict hybrid bad-startxref read to fail")
  }
  guard strict_compressed_bad is Err(_) else {
    fail("expected strict compressed hybrid bad-startxref read to fail")
  }
  let recovered = pdf_read_document_from_file(bad_path)
  let compressed_recovered = pdf_read_document_from_file(compressed_bad_path)
  pdf_async_io_remove_if_exists_for_test(valid_path)
  pdf_async_io_remove_if_exists_for_test(bad_path)
  pdf_async_io_remove_if_exists_for_test(compressed_path)
  pdf_async_io_remove_if_exists_for_test(compressed_bad_path)
  for parsed in [valid, compressed, recovered, compressed_recovered] {
    @test.assert_eq(parsed.version(), (1, 5))
    @test.assert_eq(parsed.root(), 1)
    @test.assert_eq(parsed.object_numbers(), [1, 2])
    @test.assert_eq(parsed.lookup_object_or_null(2), PdfInteger(7))
    @test.assert_eq(
      parsed
      .trailer_dict()
      .lookup_immediate(pdf_async_io_name_for_test("/XRefStm")),
      None,
    )
  }
  for parsed in [recovered, compressed_recovered] {
    @test.assert_eq(parsed.first_xref(), 0)
    @test.assert_eq(
      parsed
      .trailer_dict()
      .lookup_immediate(pdf_async_io_name_for_test("/Size")),
      Some(PdfInteger(3)),
    )
  }
  @test.assert_eq(
    compressed
    .trailer_dict()
    .lookup_immediate(pdf_async_io_name_for_test("/DecodeParms")),
    None,
  )
  @test.assert_eq(
    compressed_recovered
    .trailer_dict()
    .lookup_immediate(pdf_async_io_name_for_test("/DecodeParms")),
    None,
  )
}

///|
async test "async file wrappers reject truncated xref stream data" {
  let path = pdf_async_io_test_path_for_test("truncated_xref_stream_data")
  pdf_async_io_remove_if_exists_for_test(path)
  @fs.write_file(
    path,
    pdf_async_io_xref_stream_pdf_with_short_entry_data_for_test(),
    create=0o644,
  )
  @test.assert_eq(pdf_read_header_from_file(path), { major: 1, minor: 5 })
  let result : Result[@pdflite.PdfDocument, Error] = try? pdf_read_document_from_file(
    path,
  )
  pdf_async_io_remove_if_exists_for_test(path)
  guard result is Err(@pdflite.PdfError::XRefEntryExpected) else {
    fail("expected truncated xref stream data rejection")
  }
}

///|
async test "async file wrappers reconstruct missing startxref PDFs" {
  let path = pdf_async_io_test_path_for_test("missing_startxref")
  let repaired_path = pdf_async_io_test_path_for_test(
    "missing_startxref_repaired",
  )
  pdf_async_io_remove_if_exists_for_test(path)
  pdf_async_io_remove_if_exists_for_test(repaired_path)
  @fs.write_file(
    path,
    pdf_async_io_malformed_pdf_without_startxref_for_test(),
    create=0o644,
  )
  @test.assert_eq(pdf_read_header_from_file(path), { major: 1, minor: 4 })
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    @fs.read_file(path).binary(),
  )
  guard strict is Err(@pdflite.PdfError::StartXRefExpected) else {
    fail("expected strict missing-startxref failure")
  }
  let recovered = pdf_read_document_from_file(path)
  @test.assert_eq(recovered.version(), (1, 4))
  @test.assert_eq(recovered.first_xref(), 0)
  @test.assert_eq(recovered.root(), 1)
  @test.assert_eq(recovered.object_numbers(), [1, 2])
  @test.assert_eq(
    recovered.lookup_object_or_null(1),
    PdfDictionary([
      (
        pdf_async_io_name_for_test("/Type"),
        PdfNameObject(pdf_async_io_name_for_test("/Catalog")),
      ),
    ]),
  )
  @test.assert_eq(
    recovered
    .trailer_dict()
    .lookup_immediate(pdf_async_io_name_for_test("/Prev")),
    None,
  )
  @test.assert_eq(
    recovered
    .trailer_dict()
    .lookup_immediate(pdf_async_io_name_for_test("/Size")),
    Some(PdfInteger(3)),
  )
  pdf_write_document_to_file_with_compressed_xref_stream(
    recovered, repaired_path,
  )
  let reparsed = pdf_read_document_from_file(repaired_path)
  pdf_async_io_remove_if_exists_for_test(path)
  pdf_async_io_remove_if_exists_for_test(repaired_path)
  @test.assert_eq(reparsed.first_xref() > 0, true)
  @test.assert_eq(reparsed.root(), 1)
  @test.assert_eq(reparsed.object_numbers(), [1, 2])
}

///|
async test "async file wrappers reconstruct literal endobj text in strings" {
  let path = pdf_async_io_test_path_for_test("literal_endobj_text")
  pdf_async_io_remove_if_exists_for_test(path)
  @fs.write_file(
    path,
    pdf_async_io_malformed_pdf_with_endobj_text_in_string_for_test(),
    create=0o644,
  )
  @test.assert_eq(pdf_read_header_from_file(path), { major: 1, minor: 4 })
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    @fs.read_file(path).binary(),
  )
  guard strict is Err(@pdflite.PdfError::StartXRefExpected) else {
    fail("expected strict literal-endobj missing-startxref failure")
  }
  let recovered = pdf_read_document_from_file(path)
  pdf_async_io_remove_if_exists_for_test(path)
  @test.assert_eq(recovered.first_xref(), 0)
  @test.assert_eq(recovered.root(), 1)
  @test.assert_eq(recovered.object_numbers(), [1])
  @test.assert_eq(
    recovered
    .lookup_object_or_null(1)
    .lookup_immediate(pdf_async_io_name_for_test("/Title")),
    Some(PdfString(@ascii.encode("literal endobj marker"))),
  )
}

///|
async test "async file wrappers reconstruct glued trailer markers" {
  let path = pdf_async_io_test_path_for_test("glued_reconstruction_trailers")
  pdf_async_io_remove_if_exists_for_test(path)
  @fs.write_file(
    path,
    pdf_async_io_malformed_pdf_with_glued_reconstruction_trailers_for_test(),
    create=0o644,
  )
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    @fs.read_file(path).binary(),
  )
  guard strict is Err(@pdflite.PdfError::StartXRefExpected) else {
    fail("expected strict glued-trailer missing-startxref failure")
  }
  let recovered = pdf_read_document_from_file(path)
  pdf_async_io_remove_if_exists_for_test(path)
  @test.assert_eq(recovered.first_xref(), 0)
  @test.assert_eq(recovered.root(), 1)
  @test.assert_eq(recovered.object_numbers(), [1])
  @test.assert_eq(
    recovered.lookup_object_or_null(1),
    pdf_async_io_classic_catalog_object_for_test(),
  )
}

///|
async test "async file wrappers reconstruct classic objects missing from xref" {
  let pages_path = pdf_async_io_test_path_for_test("classic_pages_missing_xref")
  let catalog_path = pdf_async_io_test_path_for_test(
    "classic_catalog_missing_xref",
  )
  pdf_async_io_remove_if_exists_for_test(pages_path)
  pdf_async_io_remove_if_exists_for_test(catalog_path)
  @fs.write_file(
    pages_path,
    pdf_async_io_classic_pdf_with_page_tree_missing_from_xref_for_test(),
    create=0o644,
  )
  @fs.write_file(
    catalog_path,
    pdf_async_io_classic_pdf_with_catalog_missing_from_xref_for_test(),
    create=0o644,
  )
  let strict_pages = @pdflite.pdf_read_classic_document_from_bytes(
    @fs.read_file(pages_path).binary(),
  )
  @test.assert_eq(strict_pages.root(), 1)
  @test.assert_eq(strict_pages.object_numbers(), [1])
  let strict_page_count : Result[Int, Error] = try? strict_pages.endpage()
  guard strict_page_count is Err(@pdflite.PdfError::PageTreeExpected) else {
    fail("expected strict missing page tree to fail")
  }
  let strict_catalog = @pdflite.pdf_read_classic_document_from_bytes(
    @fs.read_file(catalog_path).binary(),
  )
  @test.assert_eq(strict_catalog.root(), 1)
  @test.assert_eq(strict_catalog.object_numbers(), [])
  let strict_catalog_object : Result[@pdflite.PdfObject, Error] = try? strict_catalog.catalog()
  guard strict_catalog_object is Err(@pdflite.PdfError::RootExpected) else {
    fail("expected strict missing catalog to fail")
  }
  let pages = pdf_read_document_from_file(pages_path)
  let catalog = pdf_read_document_from_file(catalog_path)
  pdf_async_io_remove_if_exists_for_test(pages_path)
  pdf_async_io_remove_if_exists_for_test(catalog_path)
  for recovered in [pages, catalog] {
    @test.assert_eq(recovered.first_xref(), 0)
    @test.assert_eq(recovered.root(), 1)
    @test.assert_eq(recovered.object_numbers(), [1, 2, 3])
    @test.assert_eq(try! recovered.endpage(), 1)
  }
}

///|
async test "async file wrappers report malformed revision metadata" {
  let missing_startxref_path = pdf_async_io_test_path_for_test(
    "revisions_missing_startxref",
  )
  let malformed_prev_path = pdf_async_io_test_path_for_test(
    "revisions_malformed_prev",
  )
  let cyclic_prev_path = pdf_async_io_test_path_for_test(
    "revisions_cyclic_prev",
  )
  pdf_async_io_remove_if_exists_for_test(missing_startxref_path)
  pdf_async_io_remove_if_exists_for_test(malformed_prev_path)
  pdf_async_io_remove_if_exists_for_test(cyclic_prev_path)

  @fs.write_file(
    missing_startxref_path,
    @ascii.encode("%PDF-1.4\nxref\n0 1\n0000000000 65535 f \n%%EOF\n"),
    create=0o644,
  )
  @fs.write_file(
    malformed_prev_path,
    pdf_async_io_classic_pdf_with_xref_body_for_test(
      "0 1\n0000000000 65535 f \n", "<< /Root 1 0 R /Size 1 /Prev /Bad >>",
    ),
    create=0o644,
  )
  @fs.write_file(
    cyclic_prev_path,
    pdf_async_io_classic_pdf_with_self_prev_xref_for_test(),
    create=0o644,
  )

  let missing_startxref : Result[Int, Error] = try? pdf_revisions_from_file(
    missing_startxref_path,
  )
  let malformed_prev : Result[Int, Error] = try? pdf_revisions_from_file(
    malformed_prev_path,
  )
  let cyclic_prev : Result[Int, Error] = try? pdf_revisions_from_file(
    cyclic_prev_path,
  )
  pdf_async_io_remove_if_exists_for_test(missing_startxref_path)
  pdf_async_io_remove_if_exists_for_test(malformed_prev_path)
  pdf_async_io_remove_if_exists_for_test(cyclic_prev_path)

  guard missing_startxref is Err(@pdflite.PdfError::StartXRefExpected) else {
    fail("expected missing-startxref revision metadata failure")
  }
  guard malformed_prev is Err(@pdflite.PdfError::TrailerExpected) else {
    fail("expected malformed Prev revision metadata failure")
  }
  guard cyclic_prev is Err(@pdflite.PdfError::XRefExpected) else {
    fail("expected cyclic Prev revision metadata failure")
  }
}

///|
async test "async file wrappers stop cyclic Prev chains" {
  let path = pdf_async_io_test_path_for_test("cyclic_prev")
  pdf_async_io_remove_if_exists_for_test(path)
  @fs.write_file(
    path,
    pdf_async_io_classic_pdf_with_self_prev_xref_for_test(),
    create=0o644,
  )
  @test.assert_eq(pdf_read_header_from_file(path), { major: 1, minor: 4 })
  let result : Result[@pdflite.PdfDocument, Error] = try? pdf_read_document_from_file(
    path,
  )
  pdf_async_io_remove_if_exists_for_test(path)
  guard result is Err(@pdflite.PdfError::XRefExpected) else {
    fail("expected cyclic Prev document read failure")
  }
}

///|
async test "async file wrappers read classic Prev revisions" {
  let path = pdf_async_io_test_path_for_test("classic_prev_revisions")
  pdf_async_io_remove_if_exists_for_test(path)
  @fs.write_file(
    path,
    pdf_async_io_classic_pdf_with_prev_xref_for_test(),
    create=0o644,
  )
  @test.assert_eq(pdf_read_header_from_file(path), { major: 1, minor: 4 })
  @test.assert_eq(pdf_revisions_from_file(path), 2)
  let full = pdf_read_document_from_file(path)
  let latest = pdf_read_document_revision_from_file(path, 1)
  let older = pdf_read_document_revision_from_file(path, 2)
  guard pdf_read_document_revision_from_file_with_passwords(path, 2)
    is Some(older_password_result) else {
    fail("expected older revision password wrapper result")
  }
  pdf_async_io_remove_if_exists_for_test(path)

  @test.assert_eq(full.object_numbers(), [1, 2])
  @test.assert_eq(full.lookup_object_or_null(1), PdfInteger(2))
  @test.assert_eq(full.lookup_object_or_null(2), PdfInteger(3))
  @test.assert_eq(
    full.trailer_dict().lookup_immediate(pdf_async_io_name_for_test("/Prev")),
    None,
  )
  @test.assert_eq(latest.revision_read(), 1)
  @test.assert_eq(latest.object_numbers(), [1, 2])
  @test.assert_eq(latest.lookup_object_or_null(1), PdfInteger(2))
  @test.assert_eq(latest.lookup_object_or_null(2), PdfInteger(3))
  @test.assert_eq(older.revision_read(), 2)
  @test.assert_eq(older.object_numbers(), [1])
  @test.assert_eq(older.lookup_object_or_null(1), PdfInteger(1))
  @test.assert_eq(older.lookup_object_or_null(2), PdfNull)
  @test.assert_eq(older.first_xref() > 0, true)
  @test.assert_eq(older_password_result.document.revision_read(), 2)
  @test.assert_eq(older_password_result.document.object_numbers(), [1])
  @test.assert_eq(
    older_password_result.document.lookup_object_or_null(1),
    PdfInteger(1),
  )
  @test.assert_eq(older_password_result.denied_permissions, [])
}

///|
async test "async file wrappers read xref stream Prev revisions" {
  let updated_path = pdf_async_io_test_path_for_test("xref_stream_prev_update")
  let deleted_path = pdf_async_io_test_path_for_test("xref_stream_prev_deleted")
  pdf_async_io_remove_if_exists_for_test(updated_path)
  pdf_async_io_remove_if_exists_for_test(deleted_path)
  @fs.write_file(
    updated_path,
    pdf_async_io_xref_stream_pdf_with_prev_update_for_test(),
    create=0o644,
  )
  @fs.write_file(
    deleted_path,
    pdf_async_io_xref_stream_pdf_with_prev_deleted_for_test(),
    create=0o644,
  )
  @test.assert_eq(pdf_read_header_from_file(updated_path), {
    major: 1,
    minor: 5,
  })
  @test.assert_eq(pdf_revisions_from_file(updated_path), 2)
  @test.assert_eq(pdf_revisions_from_file(deleted_path), 2)
  let updated = pdf_read_document_from_file(updated_path)
  let updated_older = pdf_read_document_revision_from_file(updated_path, 2)
  let deleted = pdf_read_document_from_file(deleted_path)
  let deleted_older = pdf_read_document_revision_from_file(deleted_path, 2)
  pdf_async_io_remove_if_exists_for_test(updated_path)
  pdf_async_io_remove_if_exists_for_test(deleted_path)

  @test.assert_eq(updated.object_numbers(), [1])
  @test.assert_eq(updated.lookup_object_or_null(1), PdfInteger(2))
  @test.assert_eq(
    updated.trailer_dict().lookup_immediate(pdf_async_io_name_for_test("/Prev")),
    None,
  )
  @test.assert_eq(updated_older.revision_read(), 2)
  @test.assert_eq(updated_older.object_numbers(), [1])
  @test.assert_eq(updated_older.lookup_object_or_null(1), PdfInteger(1))
  @test.assert_eq(deleted.object_numbers(), [])
  @test.assert_eq(deleted.lookup_object_or_null(1), PdfNull)
  @test.assert_eq(deleted_older.revision_read(), 2)
  @test.assert_eq(deleted_older.object_numbers(), [1])
  @test.assert_eq(deleted_older.lookup_object_or_null(1), PdfInteger(1))
}

///|
async test "async file wrappers read compressed xref stream Prev revisions" {
  let path = pdf_async_io_test_path_for_test("compressed_xref_stream_prev")
  let bad_startxref_path = pdf_async_io_test_path_for_test(
    "compressed_xref_stream_prev_bad_startxref",
  )
  pdf_async_io_remove_if_exists_for_test(path)
  pdf_async_io_remove_if_exists_for_test(bad_startxref_path)
  @fs.write_file(
    path,
    pdf_async_io_compressed_xref_stream_pdf_with_prev_update_for_test(),
    create=0o644,
  )
  @fs.write_file(
    bad_startxref_path,
    pdf_async_io_compressed_xref_stream_pdf_with_prev_update_bad_startxref_for_test(),
    create=0o644,
  )
  @test.assert_eq(pdf_read_header_from_file(path), { major: 1, minor: 5 })
  @test.assert_eq(pdf_revisions_from_file(path), 2)
  let updated = pdf_read_document_from_file(path)
  let older = pdf_read_document_revision_from_file(path, 2)
  let strict_bad_startxref : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    @fs.read_file(bad_startxref_path).binary(),
  )
  guard strict_bad_startxref is Err(@pdflite.PdfError::XRefExpected) else {
    fail("expected strict compressed xref-stream Prev failure")
  }
  let recovered = pdf_read_document_from_file(bad_startxref_path)
  pdf_async_io_remove_if_exists_for_test(path)
  pdf_async_io_remove_if_exists_for_test(bad_startxref_path)

  @test.assert_eq(updated.root(), 2)
  @test.assert_eq(updated.object_numbers(), [1, 2])
  @test.assert_eq(updated.lookup_object_or_null(1), PdfInteger(2))
  @test.assert_eq(
    updated.trailer_dict().lookup_immediate(pdf_async_io_name_for_test("/Prev")),
    None,
  )
  @test.assert_eq(
    updated
    .trailer_dict()
    .lookup_immediate(pdf_async_io_name_for_test("/DecodeParms")),
    None,
  )
  @test.assert_eq(older.revision_read(), 2)
  @test.assert_eq(older.root(), 2)
  @test.assert_eq(older.object_numbers(), [1, 2])
  @test.assert_eq(older.lookup_object_or_null(1), PdfInteger(1))
  @test.assert_eq(recovered.first_xref(), 0)
  @test.assert_eq(recovered.root(), 2)
  @test.assert_eq(recovered.object_numbers(), [1, 2])
  @test.assert_eq(recovered.lookup_object_or_null(1), PdfInteger(2))
  @test.assert_eq(
    recovered
    .trailer_dict()
    .lookup_immediate(pdf_async_io_name_for_test("/Prev")),
    None,
  )
}

///|
async test "async file wrappers report bad revision numbers" {
  let path = pdf_async_io_test_path_for_test("classic_prev_bad_revisions")
  pdf_async_io_remove_if_exists_for_test(path)
  @fs.write_file(
    path,
    pdf_async_io_classic_pdf_with_prev_xref_for_test(),
    create=0o644,
  )
  @test.assert_eq(pdf_revisions_from_file(path), 2)
  let invalid : Result[@pdflite.PdfDocument, Error] = try? pdf_read_document_revision_from_file(
    path, 0,
  )
  let missing : Result[@pdflite.PdfDocument, Error] = try? pdf_read_document_revision_from_file(
    path, 3,
  )
  let invalid_password : Result[@pdflite.PdfDecryptionResult?, Error] = try? pdf_read_document_revision_from_file_with_passwords(
    path, 0,
  )
  let missing_password : Result[@pdflite.PdfDecryptionResult?, Error] = try? pdf_read_document_revision_from_file_with_passwords(
    path, 3,
  )
  pdf_async_io_remove_if_exists_for_test(path)
  guard invalid is Err(@pdflite.PdfError::BadRevision) else {
    fail("expected invalid revision failure")
  }
  guard missing is Err(@pdflite.PdfError::BadRevision) else {
    fail("expected missing revision failure")
  }
  guard invalid_password is Err(@pdflite.PdfError::BadRevision) else {
    fail("expected invalid password-wrapper revision failure")
  }
  guard missing_password is Err(@pdflite.PdfError::BadRevision) else {
    fail("expected missing password-wrapper revision failure")
  }
}

///|
async test "async file wrappers accept classic xref row variants" {
  let blank_path = pdf_async_io_test_path_for_test("classic_xref_blank_rows")
  let zero_offset_path = pdf_async_io_test_path_for_test(
    "classic_xref_zero_offset",
  )
  let marker_suffix_path = pdf_async_io_test_path_for_test(
    "classic_xref_zero_offset_suffix",
  )
  let repeated_marker_path = pdf_async_io_test_path_for_test(
    "classic_xref_repeated_markers",
  )
  pdf_async_io_remove_if_exists_for_test(blank_path)
  pdf_async_io_remove_if_exists_for_test(zero_offset_path)
  pdf_async_io_remove_if_exists_for_test(marker_suffix_path)
  pdf_async_io_remove_if_exists_for_test(repeated_marker_path)
  @fs.write_file(
    blank_path,
    pdf_async_io_classic_pdf_with_xref_body_for_test(
      "0 1\n\n0000000000 65535 f \n", "<< /Root 1 0 R /Size 1 >>",
    ),
    create=0o644,
  )
  @fs.write_file(
    zero_offset_path,
    pdf_async_io_classic_pdf_with_xref_body_for_test(
      "0 1\n0000000000 abcde n \n", "<< /Root 1 0 R /Size 1 >>",
    ),
    create=0o644,
  )
  @fs.write_file(
    marker_suffix_path,
    pdf_async_io_classic_pdf_with_xref_body_for_test(
      "0 1\n0000000000 abcde nJunk\n", "<< /Root 1 0 R /Size 1 >>",
    ),
    create=0o644,
  )
  @fs.write_file(
    repeated_marker_path,
    pdf_async_io_classic_pdf_with_xref_body_for_test(
      "xref\nxref 0 1\n0000000000 65535 f \n", "<< /Root 1 0 R /Size 1 >>",
    ),
    create=0o644,
  )
  let blank = pdf_read_document_from_file(blank_path)
  let zero_offset = pdf_read_document_from_file(zero_offset_path)
  let marker_suffix = pdf_read_document_from_file(marker_suffix_path)
  let repeated_marker = pdf_read_document_from_file(repeated_marker_path)
  pdf_async_io_remove_if_exists_for_test(blank_path)
  pdf_async_io_remove_if_exists_for_test(zero_offset_path)
  pdf_async_io_remove_if_exists_for_test(marker_suffix_path)
  pdf_async_io_remove_if_exists_for_test(repeated_marker_path)
  for parsed in [blank, zero_offset, marker_suffix, repeated_marker] {
    @test.assert_eq(parsed.first_xref() > 0, true)
    @test.assert_eq(parsed.root(), 1)
    @test.assert_eq(parsed.object_numbers(), [])
  }
}

///|
async test "async file wrappers accept classic xref layout variants" {
  let fixed_path = pdf_async_io_test_path_for_test("classic_xref_fixed_width")
  let cr_only_path = pdf_async_io_test_path_for_test("classic_xref_cr_only")
  let mixed_first_path = pdf_async_io_test_path_for_test(
    "classic_xref_mixed_first_separator",
  )
  let mixed_second_path = pdf_async_io_test_path_for_test(
    "classic_xref_mixed_second_separator",
  )
  let tokenized_path = pdf_async_io_test_path_for_test("classic_xref_tokenized")
  let tokenized_free_path = pdf_async_io_test_path_for_test(
    "classic_xref_tokenized_free",
  )
  let inline_header_path = pdf_async_io_test_path_for_test(
    "classic_xref_inline_header",
  )
  let glued_trailer_path = pdf_async_io_test_path_for_test(
    "classic_xref_glued_trailer",
  )
  pdf_async_io_remove_if_exists_for_test(fixed_path)
  pdf_async_io_remove_if_exists_for_test(cr_only_path)
  pdf_async_io_remove_if_exists_for_test(mixed_first_path)
  pdf_async_io_remove_if_exists_for_test(mixed_second_path)
  pdf_async_io_remove_if_exists_for_test(tokenized_path)
  pdf_async_io_remove_if_exists_for_test(tokenized_free_path)
  pdf_async_io_remove_if_exists_for_test(inline_header_path)
  pdf_async_io_remove_if_exists_for_test(glued_trailer_path)
  @fs.write_file(
    fixed_path,
    pdf_async_io_classic_pdf_with_fixed_width_xref_for_test(),
    create=0o644,
  )
  @fs.write_file(
    cr_only_path,
    pdf_async_io_cr_line_endings_for_test(
      pdf_async_io_classic_pdf_with_fixed_width_xref_for_test(),
    ),
    create=0o644,
  )
  @fs.write_file(
    mixed_first_path,
    pdf_async_io_classic_pdf_with_xref_body_for_test(
      "0 1\n0000000000_65535 f \n", "<< /Root 1 0 R /Size 1 >>",
    ),
    create=0o644,
  )
  @fs.write_file(
    mixed_second_path,
    pdf_async_io_classic_pdf_with_xref_body_for_test(
      "0 1\n0000000000 65535_f \n", "<< /Root 1 0 R /Size 1 >>",
    ),
    create=0o644,
  )
  @fs.write_file(
    tokenized_path,
    pdf_async_io_classic_pdf_with_unpadded_xref_for_test(),
    create=0o644,
  )
  @fs.write_file(
    tokenized_free_path,
    pdf_async_io_classic_pdf_with_xref_body_for_test(
      "0 1\n0 0 f\n", "<< /Root 1 0 R /Size 1 >>",
    ),
    create=0o644,
  )
  @fs.write_file(
    inline_header_path,
    pdf_async_io_classic_pdf_with_inline_xref_header_for_test(),
    create=0o644,
  )
  @fs.write_file(
    glued_trailer_path,
    pdf_async_io_classic_pdf_with_glued_trailer_for_test(),
    create=0o644,
  )
  let fixed = pdf_read_document_from_file(fixed_path)
  let cr_only = pdf_read_document_from_file(cr_only_path)
  let mixed_first = pdf_read_document_from_file(mixed_first_path)
  let mixed_second = pdf_read_document_from_file(mixed_second_path)
  let tokenized = pdf_read_document_from_file(tokenized_path)
  let tokenized_free = pdf_read_document_from_file(tokenized_free_path)
  let inline_header = pdf_read_document_from_file(inline_header_path)
  let glued_trailer = pdf_read_document_from_file(glued_trailer_path)
  pdf_async_io_remove_if_exists_for_test(fixed_path)
  pdf_async_io_remove_if_exists_for_test(cr_only_path)
  pdf_async_io_remove_if_exists_for_test(mixed_first_path)
  pdf_async_io_remove_if_exists_for_test(mixed_second_path)
  pdf_async_io_remove_if_exists_for_test(tokenized_path)
  pdf_async_io_remove_if_exists_for_test(tokenized_free_path)
  pdf_async_io_remove_if_exists_for_test(inline_header_path)
  pdf_async_io_remove_if_exists_for_test(glued_trailer_path)
  for parsed in [fixed, cr_only, tokenized, inline_header, glued_trailer] {
    @test.assert_eq(parsed.first_xref() > 0, true)
    @test.assert_eq(parsed.root(), 1)
    @test.assert_eq(parsed.object_numbers(), [1])
    @test.assert_eq(
      parsed.lookup_object_or_null(1),
      pdf_async_io_classic_catalog_object_for_test(),
    )
  }
  for parsed in [mixed_first, mixed_second, tokenized_free] {
    @test.assert_eq(parsed.first_xref() > 0, true)
    @test.assert_eq(parsed.root(), 1)
    @test.assert_eq(parsed.object_numbers(), [])
  }
}

///|
async test "async file wrappers accept missing plain endobj" {
  let path = pdf_async_io_test_path_for_test("classic_missing_plain_endobj")
  pdf_async_io_remove_if_exists_for_test(path)
  @fs.write_file(
    path,
    pdf_async_io_classic_pdf_with_missing_endobj_catalog_for_test(),
    create=0o644,
  )
  let strict = try! @pdflite.pdf_read_classic_document_from_bytes(
    @fs.read_file(path).binary(),
  )
  let parsed = pdf_read_document_from_file(path)
  pdf_async_io_remove_if_exists_for_test(path)
  for document in [strict, parsed] {
    @test.assert_eq(document.first_xref() > 0, true)
    @test.assert_eq(document.root(), 1)
    @test.assert_eq(document.object_numbers(), [1])
    @test.assert_eq(
      document.lookup_object_or_null(1),
      pdf_async_io_classic_catalog_object_for_test(),
    )
  }
}

///|
async test "async file wrappers continue after missing plain endobj" {
  let path = pdf_async_io_test_path_for_test(
    "classic_missing_plain_endobj_continuation",
  )
  pdf_async_io_remove_if_exists_for_test(path)
  @fs.write_file(
    path,
    pdf_async_io_classic_pdf_with_missing_endobj_before_object_for_test(),
    create=0o644,
  )
  let strict = try! @pdflite.pdf_read_classic_document_from_bytes(
    @fs.read_file(path).binary(),
  )
  let parsed = pdf_read_document_from_file(path)
  pdf_async_io_remove_if_exists_for_test(path)
  for document in [strict, parsed] {
    @test.assert_eq(document.first_xref() > 0, true)
    @test.assert_eq(document.root(), 1)
    @test.assert_eq(document.object_numbers(), [1, 2])
    @test.assert_eq(
      document.lookup_object_or_null(1),
      pdf_async_io_catalog_with_payload_for_test(2),
    )
    @test.assert_eq(document.lookup_object_or_null(2), PdfInteger(43))
  }
}

///|
async test "async file wrappers keep direct streams from swallowing following objects" {
  let path = pdf_async_io_test_path_for_test(
    "classic_direct_stream_before_object",
  )
  pdf_async_io_remove_if_exists_for_test(path)
  @fs.write_file(
    path,
    pdf_async_io_classic_pdf_with_direct_stream_before_object_for_test(),
    create=0o644,
  )
  let strict = try! @pdflite.pdf_read_classic_document_from_bytes(
    @fs.read_file(path).binary(),
  )
  let parsed = pdf_read_document_from_file(path)
  pdf_async_io_remove_if_exists_for_test(path)
  for document in [strict, parsed] {
    @test.assert_eq(document.first_xref() > 0, true)
    @test.assert_eq(document.root(), 1)
    @test.assert_eq(document.object_numbers(), [1, 2, 3])
    @test.assert_eq(
      document.lookup_object_or_null(1),
      pdf_async_io_catalog_with_payload_for_test(2),
    )
    guard document.lookup_object_or_null(2) is PdfStreamObject(stream) else {
      fail("expected direct stream object")
    }
    @test.assert_eq(
      stream.dictionary.lookup_immediate(pdf_async_io_name_for_test("/Length")),
      Some(PdfInteger(5)),
    )
    @test.assert_eq(
      try! @pdflite.pdf_stream(stream.dictionary, stream.data).stream_bytes(),
      @ascii.encode("Hello"),
    )
    @test.assert_eq(document.lookup_object_or_null(3), PdfNull)
  }
}

///|
async test "async file wrappers accept direct stream line breaks and padding" {
  let cr_path = pdf_async_io_test_path_for_test("classic_stream_cr_break")
  let crlf_path = pdf_async_io_test_path_for_test("classic_stream_crlf_break")
  let padded_path = pdf_async_io_test_path_for_test("classic_stream_padding")
  let inline_padding_path = pdf_async_io_test_path_for_test(
    "classic_stream_inline_padding",
  )
  pdf_async_io_remove_if_exists_for_test(cr_path)
  pdf_async_io_remove_if_exists_for_test(crlf_path)
  pdf_async_io_remove_if_exists_for_test(padded_path)
  pdf_async_io_remove_if_exists_for_test(inline_padding_path)
  @fs.write_file(
    cr_path,
    pdf_async_io_classic_pdf_with_stream_body_for_test(
      @ascii.encode("<< /Length 5 >>\nstream\rHello\rendstream"),
    ),
    create=0o644,
  )
  @fs.write_file(
    crlf_path,
    pdf_async_io_classic_pdf_with_stream_body_for_test(
      @ascii.encode("<< /Length 5 >>\nstream\r\nWorld\r\nendstream"),
    ),
    create=0o644,
  )
  @fs.write_file(
    padded_path,
    pdf_async_io_classic_pdf_with_stream_body_for_test(
      pdf_async_io_padded_stream_body_for_test("Space\n", true),
    ),
    create=0o644,
  )
  @fs.write_file(
    inline_padding_path,
    pdf_async_io_classic_pdf_with_stream_body_for_test(
      pdf_async_io_padded_stream_body_for_test("Hello", false),
    ),
    create=0o644,
  )
  let strict_cr = try! @pdflite.pdf_read_classic_document_from_bytes(
    @fs.read_file(cr_path).binary(),
  )
  let strict_crlf = try! @pdflite.pdf_read_classic_document_from_bytes(
    @fs.read_file(crlf_path).binary(),
  )
  let strict_padded = try! @pdflite.pdf_read_classic_document_from_bytes(
    @fs.read_file(padded_path).binary(),
  )
  let strict_inline_padding = try! @pdflite.pdf_read_classic_document_from_bytes(
    @fs.read_file(inline_padding_path).binary(),
  )
  let cr = pdf_read_document_from_file(cr_path)
  let crlf = pdf_read_document_from_file(crlf_path)
  let padded = pdf_read_document_from_file(padded_path)
  let inline_padding = pdf_read_document_from_file(inline_padding_path)
  pdf_async_io_remove_if_exists_for_test(cr_path)
  pdf_async_io_remove_if_exists_for_test(crlf_path)
  pdf_async_io_remove_if_exists_for_test(padded_path)
  pdf_async_io_remove_if_exists_for_test(inline_padding_path)
  for
    document in [
      strict_cr, strict_crlf, strict_padded, strict_inline_padding, cr, crlf, padded,
      inline_padding,
    ] {
    @test.assert_eq(document.first_xref() > 0, true)
    @test.assert_eq(document.root(), 1)
    @test.assert_eq(document.object_numbers(), [1, 2])
    @test.assert_eq(
      document.lookup_object_or_null(1),
      pdf_async_io_catalog_with_payload_for_test(2),
    )
  }
  for document in [strict_cr, cr] {
    guard document.lookup_object_or_null(2) is PdfStreamObject(stream) else {
      fail("expected CR stream object")
    }
    @test.assert_eq(
      try! @pdflite.pdf_stream(stream.dictionary, stream.data).stream_bytes(),
      @ascii.encode("Hello"),
    )
  }
  for document in [strict_crlf, crlf] {
    guard document.lookup_object_or_null(2) is PdfStreamObject(stream) else {
      fail("expected CRLF stream object")
    }
    @test.assert_eq(
      try! @pdflite.pdf_stream(stream.dictionary, stream.data).stream_bytes(),
      @ascii.encode("World"),
    )
  }
  for document in [strict_padded, padded] {
    guard document.lookup_object_or_null(2) is PdfStreamObject(stream) else {
      fail("expected padded stream object")
    }
    @test.assert_eq(
      try! @pdflite.pdf_stream(stream.dictionary, stream.data).stream_bytes(),
      @ascii.encode("Space"),
    )
  }
  for document in [strict_inline_padding, inline_padding] {
    guard document.lookup_object_or_null(2) is PdfStreamObject(stream) else {
      fail("expected inline-padded stream object")
    }
    @test.assert_eq(
      try! @pdflite.pdf_stream(stream.dictionary, stream.data).stream_bytes(),
      @ascii.encode("Hello"),
    )
  }
}

///|
async test "async file wrappers accept classic startxref pointer variants" {
  let trailing_path = pdf_async_io_test_path_for_test("startxref_trailing_junk")
  let prefixed_path = pdf_async_io_test_path_for_test("startxref_prefixed")
  let inline_path = pdf_async_io_test_path_for_test("startxref_inline")
  pdf_async_io_remove_if_exists_for_test(trailing_path)
  pdf_async_io_remove_if_exists_for_test(prefixed_path)
  pdf_async_io_remove_if_exists_for_test(inline_path)
  @fs.write_file(
    trailing_path,
    pdf_async_io_classic_pdf_with_trailing_startxref_junk_for_test(),
    create=0o644,
  )
  @fs.write_file(
    prefixed_path,
    pdf_async_io_classic_pdf_with_prefixed_startxref_for_test(),
    create=0o644,
  )
  @fs.write_file(
    inline_path,
    pdf_async_io_classic_pdf_with_inline_startxref_for_test(),
    create=0o644,
  )
  let trailing_revisions = pdf_revisions_from_file(trailing_path)
  let prefixed_revisions = pdf_revisions_from_file(prefixed_path)
  let inline_revisions = pdf_revisions_from_file(inline_path)
  let trailing = pdf_read_document_from_file(trailing_path)
  let prefixed = pdf_read_document_from_file(prefixed_path)
  let inline = pdf_read_document_from_file(inline_path)
  pdf_async_io_remove_if_exists_for_test(trailing_path)
  pdf_async_io_remove_if_exists_for_test(prefixed_path)
  pdf_async_io_remove_if_exists_for_test(inline_path)
  @test.assert_eq(trailing_revisions, 1)
  @test.assert_eq(prefixed_revisions, 1)
  @test.assert_eq(inline_revisions, 1)
  for parsed in [trailing, prefixed, inline] {
    @test.assert_eq(parsed.first_xref() > 0, true)
    @test.assert_eq(parsed.root(), 1)
    @test.assert_eq(parsed.object_numbers(), [1])
    @test.assert_eq(
      parsed.lookup_object_or_null(1),
      pdf_async_io_classic_catalog_object_for_test(),
    )
  }
}

///|
async test "async file wrappers reconstruct out-of-range startxref PDFs" {
  let path = pdf_async_io_test_path_for_test("out_of_range_startxref")
  pdf_async_io_remove_if_exists_for_test(path)
  @fs.write_file(
    path,
    pdf_async_io_malformed_pdf_with_out_of_range_startxref_for_test(),
    create=0o644,
  )
  @test.assert_eq(pdf_read_header_from_file(path), { major: 1, minor: 4 })
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    @fs.read_file(path).binary(),
  )
  guard strict is Err(@pdflite.PdfError::InvalidCursorPosition(999999)) else {
    fail("expected strict out-of-range startxref failure")
  }
  let recovered = pdf_read_document_from_file(path)
  pdf_async_io_remove_if_exists_for_test(path)
  @test.assert_eq(recovered.first_xref(), 0)
  @test.assert_eq(recovered.root(), 1)
  @test.assert_eq(recovered.object_numbers(), [1])
  @test.assert_eq(
    recovered.lookup_object_or_null(1),
    pdf_async_io_classic_catalog_object_for_test(),
  )
}

///|
async test "async file wrappers reconstruct in-range bad startxref PDFs" {
  let path = pdf_async_io_test_path_for_test("bad_startxref")
  pdf_async_io_remove_if_exists_for_test(path)
  @fs.write_file(
    path,
    pdf_async_io_malformed_pdf_with_bad_startxref_for_test(),
    create=0o644,
  )
  @test.assert_eq(pdf_read_header_from_file(path), { major: 1, minor: 4 })
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    @fs.read_file(path).binary(),
  )
  guard strict is Err(@pdflite.PdfError::XRefExpected) else {
    fail("expected strict in-range bad-startxref failure")
  }
  let recovered = pdf_read_document_from_file(path)
  pdf_async_io_remove_if_exists_for_test(path)
  @test.assert_eq(recovered.first_xref(), 0)
  @test.assert_eq(recovered.root(), 1)
  @test.assert_eq(recovered.object_numbers(), [1])
  @test.assert_eq(
    recovered.lookup_object_or_null(1),
    pdf_async_io_classic_catalog_object_for_test(),
  )
}

///|
async test "async file wrappers reconstruct malformed startxref numbers" {
  let malformed_path = pdf_async_io_test_path_for_test(
    "malformed_startxref_number",
  )
  let overflow_path = pdf_async_io_test_path_for_test(
    "overflow_startxref_number",
  )
  pdf_async_io_remove_if_exists_for_test(malformed_path)
  pdf_async_io_remove_if_exists_for_test(overflow_path)
  @fs.write_file(
    malformed_path,
    pdf_async_io_malformed_pdf_with_startxref_number_for_test("abc"),
    create=0o644,
  )
  @fs.write_file(
    overflow_path,
    pdf_async_io_malformed_pdf_with_startxref_number_for_test("2147483648"),
    create=0o644,
  )
  let strict_malformed : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    @fs.read_file(malformed_path).binary(),
  )
  let strict_overflow : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    @fs.read_file(overflow_path).binary(),
  )
  guard strict_malformed is Err(@pdflite.PdfError::NumberExpected) else {
    fail("expected malformed startxref number failure")
  }
  guard strict_overflow is Err(@pdflite.PdfError::NumberExpected) else {
    fail("expected overflow startxref number failure")
  }
  let malformed = pdf_read_document_from_file(malformed_path)
  let overflow = pdf_read_document_from_file(overflow_path)
  pdf_async_io_remove_if_exists_for_test(malformed_path)
  pdf_async_io_remove_if_exists_for_test(overflow_path)
  for recovered in [malformed, overflow] {
    @test.assert_eq(recovered.first_xref(), 0)
    @test.assert_eq(recovered.root(), 1)
    @test.assert_eq(recovered.object_numbers(), [1])
    @test.assert_eq(
      recovered.lookup_object_or_null(1),
      pdf_async_io_classic_catalog_object_for_test(),
    )
  }
}

///|
async test "async file wrappers preserve classic free entries during reconstruction" {
  let deleted_path = pdf_async_io_test_path_for_test(
    "classic_free_entry_bad_startxref",
  )
  let later_path = pdf_async_io_test_path_for_test(
    "classic_free_entry_later_update",
  )
  pdf_async_io_remove_if_exists_for_test(deleted_path)
  pdf_async_io_remove_if_exists_for_test(later_path)
  @fs.write_file(
    deleted_path,
    pdf_async_io_classic_xref_deleted_payload_bad_startxref_for_test(false),
    create=0o644,
  )
  @fs.write_file(
    later_path,
    pdf_async_io_classic_xref_deleted_payload_bad_startxref_for_test(true),
    create=0o644,
  )
  let strict_deleted : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    @fs.read_file(deleted_path).binary(),
  )
  guard strict_deleted is Err(_) else {
    fail("expected strict bad-startxref free-entry failure")
  }
  let deleted = pdf_read_document_from_file(deleted_path)
  let later = pdf_read_document_from_file(later_path)
  pdf_async_io_remove_if_exists_for_test(deleted_path)
  pdf_async_io_remove_if_exists_for_test(later_path)

  @test.assert_eq(deleted.first_xref(), 0)
  @test.assert_eq(deleted.root(), 1)
  @test.assert_eq(deleted.object_numbers(), [1])
  @test.assert_eq(deleted.lookup_object_or_null(2), PdfNull)
  @test.assert_eq(later.first_xref(), 0)
  @test.assert_eq(later.root(), 1)
  @test.assert_eq(later.object_numbers(), [1, 2])
  @test.assert_eq(later.lookup_object_or_null(2), PdfInteger(99))
}

///|
async test "async file wrappers reconstruct classic Prev chains with bad startxref" {
  let path = pdf_async_io_test_path_for_test("classic_prev_bad_startxref")
  pdf_async_io_remove_if_exists_for_test(path)
  @fs.write_file(
    path,
    pdf_async_io_classic_catalog_pdf_with_prev_xref_bad_startxref_for_test(),
    create=0o644,
  )
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    @fs.read_file(path).binary(),
  )
  guard strict is Err(_) else {
    fail("expected strict classic Prev bad-startxref failure")
  }
  let recovered = pdf_read_document_from_file(path)
  pdf_async_io_remove_if_exists_for_test(path)
  @test.assert_eq(recovered.version(), (1, 4))
  @test.assert_eq(recovered.first_xref(), 0)
  @test.assert_eq(recovered.root(), 1)
  @test.assert_eq(recovered.object_numbers(), [1, 2])
  @test.assert_eq(
    recovered
    .lookup_object_or_null(1)
    .lookup_immediate(pdf_async_io_name_for_test("/Revision")),
    Some(PdfInteger(2)),
  )
  @test.assert_eq(recovered.lookup_object_or_null(2), PdfInteger(3))
  @test.assert_eq(
    recovered
    .trailer_dict()
    .lookup_immediate(pdf_async_io_name_for_test("/Prev")),
    None,
  )
}

///|
async test "async file wrappers reconstruct malformed classic xref metadata" {
  let bad_entry_path = pdf_async_io_test_path_for_test(
    "malformed_classic_bad_xref_entry",
  )
  let bad_count_path = pdf_async_io_test_path_for_test(
    "malformed_classic_bad_xref_count",
  )
  let bad_trailer_path = pdf_async_io_test_path_for_test(
    "malformed_classic_bad_trailer",
  )
  let missing_root_path = pdf_async_io_test_path_for_test(
    "malformed_classic_missing_root",
  )
  let bad_offset_path = pdf_async_io_test_path_for_test(
    "malformed_classic_bad_offset",
  )
  pdf_async_io_remove_if_exists_for_test(bad_entry_path)
  pdf_async_io_remove_if_exists_for_test(bad_count_path)
  pdf_async_io_remove_if_exists_for_test(bad_trailer_path)
  pdf_async_io_remove_if_exists_for_test(missing_root_path)
  pdf_async_io_remove_if_exists_for_test(bad_offset_path)
  @fs.write_file(
    bad_entry_path,
    pdf_async_io_malformed_pdf_with_bad_xref_entry_for_test(),
    create=0o644,
  )
  @fs.write_file(
    bad_count_path,
    pdf_async_io_malformed_pdf_with_bad_xref_count_for_test(),
    create=0o644,
  )
  @fs.write_file(
    bad_trailer_path,
    pdf_async_io_malformed_pdf_with_bad_trailer_for_test(),
    create=0o644,
  )
  @fs.write_file(
    missing_root_path,
    pdf_async_io_malformed_pdf_with_missing_root_trailer_for_test(),
    create=0o644,
  )
  @fs.write_file(
    bad_offset_path,
    pdf_async_io_malformed_pdf_with_bad_object_offset_for_test(),
    create=0o644,
  )
  let strict_bad_entry : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    @fs.read_file(bad_entry_path).binary(),
  )
  let strict_bad_count : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    @fs.read_file(bad_count_path).binary(),
  )
  let strict_bad_trailer : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    @fs.read_file(bad_trailer_path).binary(),
  )
  let strict_missing_root : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    @fs.read_file(missing_root_path).binary(),
  )
  let strict_bad_offset : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    @fs.read_file(bad_offset_path).binary(),
  )
  let bad_entry = pdf_read_document_from_file(bad_entry_path)
  let bad_count = pdf_read_document_from_file(bad_count_path)
  let bad_trailer = pdf_read_document_from_file(bad_trailer_path)
  let missing_root = pdf_read_document_from_file(missing_root_path)
  let bad_offset = pdf_read_document_from_file(bad_offset_path)
  pdf_async_io_remove_if_exists_for_test(bad_entry_path)
  pdf_async_io_remove_if_exists_for_test(bad_count_path)
  pdf_async_io_remove_if_exists_for_test(bad_trailer_path)
  pdf_async_io_remove_if_exists_for_test(missing_root_path)
  pdf_async_io_remove_if_exists_for_test(bad_offset_path)
  guard strict_bad_entry is Err(@pdflite.PdfError::XRefEntryExpected) else {
    fail("expected strict malformed xref-entry failure")
  }
  guard strict_bad_count is Err(@pdflite.PdfError::NumberExpected) else {
    fail("expected strict malformed xref-count failure")
  }
  guard strict_bad_trailer is Err(@pdflite.PdfError::TrailerExpected) else {
    fail("expected strict malformed trailer failure")
  }
  guard strict_missing_root is Err(@pdflite.PdfError::RootExpected) else {
    fail("expected strict missing-root trailer failure")
  }
  guard strict_bad_offset is Err(@pdflite.PdfError::ParseIndirectObjectExpected) else {
    fail("expected strict bad-object-offset failure")
  }
  for parsed in [bad_entry, bad_count, bad_trailer, missing_root, bad_offset] {
    @test.assert_eq(parsed.first_xref(), 0)
    @test.assert_eq(parsed.root(), 1)
    @test.assert_eq(parsed.object_numbers(), [1])
    @test.assert_eq(
      parsed.lookup_object_or_null(1),
      pdf_async_io_classic_catalog_object_for_test(),
    )
  }
}

///|
async test "async file wrappers preserve strict malformed Prev trailer errors" {
  let negative_path = pdf_async_io_test_path_for_test("classic_prev_negative")
  let named_path = pdf_async_io_test_path_for_test("classic_prev_named")
  pdf_async_io_remove_if_exists_for_test(negative_path)
  pdf_async_io_remove_if_exists_for_test(named_path)
  @fs.write_file(
    negative_path,
    pdf_async_io_malformed_pdf_with_bad_prev_trailer_for_test("-1"),
    create=0o644,
  )
  @fs.write_file(
    named_path,
    pdf_async_io_malformed_pdf_with_bad_prev_trailer_for_test("/Bad"),
    create=0o644,
  )
  let negative_strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    @fs.read_file(negative_path).binary(),
  )
  let named_strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    @fs.read_file(named_path).binary(),
  )
  let negative = pdf_read_document_from_file(negative_path)
  let named = pdf_read_document_from_file(named_path)
  pdf_async_io_remove_if_exists_for_test(negative_path)
  pdf_async_io_remove_if_exists_for_test(named_path)
  guard negative_strict is Err(@pdflite.PdfError::TrailerExpected) else {
    fail("expected strict negative Prev trailer failure")
  }
  guard named_strict is Err(@pdflite.PdfError::TrailerExpected) else {
    fail("expected strict named Prev trailer failure")
  }
  for parsed in [negative, named] {
    @test.assert_eq(parsed.first_xref(), 0)
    @test.assert_eq(parsed.root(), 1)
    @test.assert_eq(parsed.object_numbers(), [1])
    @test.assert_eq(
      parsed.lookup_object_or_null(1),
      pdf_async_io_classic_catalog_object_for_test(),
    )
  }
}

///|
async test "async file wrappers preserve strict malformed xref row variants" {
  let bad_token_path = pdf_async_io_test_path_for_test(
    "classic_xref_bad_row_token",
  )
  let short_row_path = pdf_async_io_test_path_for_test("classic_xref_short_row")
  let bad_digit_path = pdf_async_io_test_path_for_test(
    "classic_xref_bad_fixed_digit",
  )
  let bad_marker_path = pdf_async_io_test_path_for_test(
    "classic_xref_bad_fixed_marker",
  )
  pdf_async_io_remove_if_exists_for_test(bad_token_path)
  pdf_async_io_remove_if_exists_for_test(short_row_path)
  pdf_async_io_remove_if_exists_for_test(bad_digit_path)
  pdf_async_io_remove_if_exists_for_test(bad_marker_path)
  @fs.write_file(
    bad_token_path,
    pdf_async_io_classic_pdf_with_malformed_xref_row_for_test(
      "0 1\n0000000000 00000 q \n",
    ),
    create=0o644,
  )
  @fs.write_file(
    short_row_path,
    pdf_async_io_classic_pdf_with_malformed_xref_row_for_test("0\n"),
    create=0o644,
  )
  @fs.write_file(
    bad_digit_path,
    pdf_async_io_classic_pdf_with_malformed_xref_row_for_test(
      "0 1\n0000000000_65x35_f \n",
    ),
    create=0o644,
  )
  @fs.write_file(
    bad_marker_path,
    pdf_async_io_classic_pdf_with_malformed_xref_row_for_test(
      "0 1\n0000000000_65535_q \n",
    ),
    create=0o644,
  )
  let bad_token : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    @fs.read_file(bad_token_path).binary(),
  )
  let short_row : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    @fs.read_file(short_row_path).binary(),
  )
  let bad_digit : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    @fs.read_file(bad_digit_path).binary(),
  )
  let bad_marker : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    @fs.read_file(bad_marker_path).binary(),
  )
  let recovered_bad_token = pdf_read_document_from_file(bad_token_path)
  let recovered_short_row = pdf_read_document_from_file(short_row_path)
  let recovered_bad_digit = pdf_read_document_from_file(bad_digit_path)
  let recovered_bad_marker = pdf_read_document_from_file(bad_marker_path)
  pdf_async_io_remove_if_exists_for_test(bad_token_path)
  pdf_async_io_remove_if_exists_for_test(short_row_path)
  pdf_async_io_remove_if_exists_for_test(bad_digit_path)
  pdf_async_io_remove_if_exists_for_test(bad_marker_path)
  guard bad_token is Err(@pdflite.PdfError::XRefEntryExpected) else {
    fail("expected malformed xref row-token failure")
  }
  guard short_row is Err(@pdflite.PdfError::XRefEntryExpected) else {
    fail("expected malformed xref short-row failure")
  }
  guard bad_digit is Err(@pdflite.PdfError::XRefEntryExpected) else {
    fail("expected malformed xref fixed-digit failure")
  }
  guard bad_marker is Err(@pdflite.PdfError::XRefEntryExpected) else {
    fail("expected malformed xref fixed-marker failure")
  }
  for
    parsed in [
      recovered_bad_token, recovered_short_row, recovered_bad_digit, recovered_bad_marker,
    ] {
    @test.assert_eq(parsed.first_xref(), 0)
    @test.assert_eq(parsed.root(), 1)
    @test.assert_eq(parsed.object_numbers(), [1])
    @test.assert_eq(
      parsed.lookup_object_or_null(1),
      pdf_async_io_classic_catalog_object_for_test(),
    )
  }
}

///|
async test "async file wrappers preserve strict xref object mismatch errors" {
  let mismatched_path = pdf_async_io_test_path_for_test(
    "classic_xref_mismatched_object",
  )
  let unparseable_path = pdf_async_io_test_path_for_test(
    "classic_xref_unparseable_object",
  )
  pdf_async_io_remove_if_exists_for_test(mismatched_path)
  pdf_async_io_remove_if_exists_for_test(unparseable_path)
  @fs.write_file(
    mismatched_path,
    pdf_async_io_classic_pdf_with_mismatched_object_xref_for_test(),
    create=0o644,
  )
  @fs.write_file(
    unparseable_path,
    pdf_async_io_classic_pdf_with_unparseable_xref_object_for_test(),
    create=0o644,
  )
  let mismatched : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    @fs.read_file(mismatched_path).binary(),
  )
  let unparseable : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    @fs.read_file(unparseable_path).binary(),
  )
  pdf_async_io_remove_if_exists_for_test(mismatched_path)
  pdf_async_io_remove_if_exists_for_test(unparseable_path)
  guard mismatched is Err(@pdflite.PdfError::XRefEntryExpected) else {
    fail("expected strict mismatched xref object failure")
  }
  guard unparseable is Err(@pdflite.PdfError::ParseIndirectObjectExpected) else {
    fail("expected strict unparseable xref object failure")
  }
}

///|
async test "async file wrappers preserve strict missing xref and trailer errors" {
  let missing_xref_path = pdf_async_io_test_path_for_test(
    "classic_missing_xref_marker",
  )
  let trailerless_path = pdf_async_io_test_path_for_test(
    "classic_trailerless_xref",
  )
  pdf_async_io_remove_if_exists_for_test(missing_xref_path)
  pdf_async_io_remove_if_exists_for_test(trailerless_path)
  @fs.write_file(
    missing_xref_path,
    @ascii.encode("%PDF-1.4\nstartxref\n9\n%%EOF\n"),
    create=0o644,
  )
  @fs.write_file(
    trailerless_path,
    pdf_async_io_classic_pdf_without_trailer_after_xref_for_test(),
    create=0o644,
  )
  let missing_xref : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    @fs.read_file(missing_xref_path).binary(),
  )
  let trailerless : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    @fs.read_file(trailerless_path).binary(),
  )
  pdf_async_io_remove_if_exists_for_test(missing_xref_path)
  pdf_async_io_remove_if_exists_for_test(trailerless_path)
  guard missing_xref is Err(@pdflite.PdfError::XRefExpected) else {
    fail("expected strict missing xref marker failure")
  }
  guard trailerless is Err(@pdflite.PdfError::TrailerExpected) else {
    fail("expected strict trailerless xref failure")
  }
}

///|
async test "async file wrappers recover unreadable stream lengths" {
  let missing_path = pdf_async_io_test_path_for_test(
    "stream_length_missing_indirect",
  )
  let non_integer_path = pdf_async_io_test_path_for_test(
    "stream_length_non_integer",
  )
  let stream_object_path = pdf_async_io_test_path_for_test(
    "stream_length_stream_object",
  )
  let negative_path = pdf_async_io_test_path_for_test("stream_length_negative")
  let unparseable_path = pdf_async_io_test_path_for_test(
    "stream_length_unparseable",
  )
  pdf_async_io_remove_if_exists_for_test(missing_path)
  pdf_async_io_remove_if_exists_for_test(non_integer_path)
  pdf_async_io_remove_if_exists_for_test(stream_object_path)
  pdf_async_io_remove_if_exists_for_test(negative_path)
  pdf_async_io_remove_if_exists_for_test(unparseable_path)
  @fs.write_file(
    missing_path,
    pdf_async_io_classic_pdf_with_missing_indirect_stream_length_for_test(),
    create=0o644,
  )
  @fs.write_file(
    non_integer_path,
    pdf_async_io_classic_pdf_with_non_integer_stream_length_for_test(),
    create=0o644,
  )
  @fs.write_file(
    stream_object_path,
    pdf_async_io_classic_pdf_with_stream_length_object_for_test(),
    create=0o644,
  )
  @fs.write_file(
    negative_path,
    pdf_async_io_classic_pdf_with_negative_stream_length_for_test(),
    create=0o644,
  )
  @fs.write_file(
    unparseable_path,
    pdf_async_io_classic_pdf_with_unparseable_stream_length_for_test(),
    create=0o644,
  )
  let missing = pdf_read_document_from_file(missing_path)
  let non_integer = pdf_read_document_from_file(non_integer_path)
  let stream_object = pdf_read_document_from_file(stream_object_path)
  let negative = pdf_read_document_from_file(negative_path)
  let unparseable = pdf_read_document_from_file(unparseable_path)
  pdf_async_io_remove_if_exists_for_test(missing_path)
  pdf_async_io_remove_if_exists_for_test(non_integer_path)
  pdf_async_io_remove_if_exists_for_test(stream_object_path)
  pdf_async_io_remove_if_exists_for_test(negative_path)
  pdf_async_io_remove_if_exists_for_test(unparseable_path)
  for parsed in [missing, non_integer, stream_object, negative] {
    @test.assert_eq(parsed.first_xref() > 0, true)
    @test.assert_eq(parsed.root(), 1)
    pdf_async_io_assert_recovered_hello_stream_for_test(parsed)
  }
  @test.assert_eq(unparseable.first_xref(), 0)
  @test.assert_eq(unparseable.root(), 3)
  @test.assert_eq(unparseable.object_numbers(), [1, 3])
  @test.assert_eq(
    unparseable.lookup_object_or_null(3),
    @pdflite.pdf_dictionary([
      (
        pdf_async_io_name_for_test("/Type"),
        PdfNameObject(pdf_async_io_name_for_test("/Catalog")),
      ),
      (pdf_async_io_name_for_test("/Payload"), PdfIndirect(1)),
    ]),
  )
  pdf_async_io_assert_recovered_hello_stream_for_test(unparseable)
}

///|
async test "async file wrappers resolve commented indirect stream lengths" {
  let path = pdf_async_io_test_path_for_test("commented_indirect_stream_length")
  pdf_async_io_remove_if_exists_for_test(path)
  @fs.write_file(
    path,
    pdf_async_io_classic_pdf_with_commented_indirect_stream_length_for_test(),
    create=0o644,
  )
  let parsed = pdf_read_document_from_file(path)
  pdf_async_io_remove_if_exists_for_test(path)
  @test.assert_eq(parsed.first_xref() > 0, true)
  @test.assert_eq(parsed.object_numbers(), [1, 2])
  guard parsed.lookup_object_or_null(1) is PdfStreamObject(stream) else {
    fail("expected stream object")
  }
  @test.assert_eq(
    stream.dictionary.lookup_immediate(pdf_async_io_name_for_test("/Length")),
    Some(PdfIndirect(2)),
  )
  guard stream.data is StreamToGet(_) else {
    fail("expected commented stream length data to stay deferred")
  }
  @test.assert_eq(
    @pdflite.pdf_stream(stream.dictionary, stream.data).stream_bytes(),
    @ascii.encode("Hello"),
  )
  @test.assert_eq(parsed.lookup_object_or_null(2), PdfInteger(5))
}

///|
async test "async file wrappers reconstruct indirect stream lengths" {
  let path = pdf_async_io_test_path_for_test("indirect_stream_lengths")
  pdf_async_io_remove_if_exists_for_test(path)
  @fs.write_file(
    path,
    pdf_async_io_malformed_pdf_with_indirect_stream_length_for_test(),
    create=0o644,
  )
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    @fs.read_file(path).binary(),
  )
  guard strict is Err(@pdflite.PdfError::StartXRefExpected) else {
    fail("expected strict indirect-stream-length missing-startxref failure")
  }
  let recovered = pdf_read_document_from_file(path)
  pdf_async_io_remove_if_exists_for_test(path)
  @test.assert_eq(recovered.first_xref(), 0)
  @test.assert_eq(recovered.root(), 3)
  @test.assert_eq(recovered.object_numbers(), [1, 2, 3, 4])
  let first_object = recovered.lookup_object_or_null(1)
  guard first_object is PdfStreamObject(first_stream) else {
    fail("expected first recovered stream")
  }
  @test.assert_eq(
    first_stream.dictionary.lookup_immediate(
      pdf_async_io_name_for_test("/Length"),
    ),
    Some(PdfIndirect(2)),
  )
  guard first_stream.data is StreamToGet(_) else {
    fail("expected first stream data to stay deferred")
  }
  @test.assert_eq(first_object.stream_bytes(), @ascii.encode("Hello"))
  guard recovered.lookup_object_or_null(4) is PdfStreamObject(reconstructed) else {
    fail("expected reconstructed missing-length stream")
  }
  @test.assert_eq(
    reconstructed.dictionary.lookup_immediate(
      pdf_async_io_name_for_test("/Length"),
    ),
    Some(PdfInteger(7)),
  )
  @test.assert_eq(reconstructed.data, StreamGot(@ascii.encode("Ignored")))
}

///|
async test "async file wrappers reconstruct malformed stream markers" {
  let bad_stream_path = pdf_async_io_test_path_for_test(
    "malformed_stream_keyword",
  )
  let bad_endstream_path = pdf_async_io_test_path_for_test(
    "malformed_endstream",
  )
  let bad_endobj_path = pdf_async_io_test_path_for_test("malformed_endobj")
  let truncated_path = pdf_async_io_test_path_for_test("truncated_stream_data")
  pdf_async_io_remove_if_exists_for_test(bad_stream_path)
  pdf_async_io_remove_if_exists_for_test(bad_endstream_path)
  pdf_async_io_remove_if_exists_for_test(bad_endobj_path)
  pdf_async_io_remove_if_exists_for_test(truncated_path)
  @fs.write_file(
    bad_stream_path,
    pdf_async_io_classic_pdf_with_malformed_stream_for_test(
      "<< /Length 5 >>\nstram\nHello\nendstream",
    ),
    create=0o644,
  )
  @fs.write_file(
    bad_endstream_path,
    pdf_async_io_classic_pdf_with_malformed_stream_for_test(
      "<< /Length 5 >>\nstream\nHello\nnot_a_stream_end",
    ),
    create=0o644,
  )
  @fs.write_file(
    bad_endobj_path,
    pdf_async_io_classic_pdf_with_malformed_stream_for_test(
      "<< /Length 5 >>\nstream\nHello\nendstream\nnotendobj",
    ),
    create=0o644,
  )
  @fs.write_file(
    truncated_path,
    pdf_async_io_classic_pdf_with_truncated_stream_for_test(),
    create=0o644,
  )
  let strict_bad_stream : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    @fs.read_file(bad_stream_path).binary(),
  )
  let strict_bad_endstream : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    @fs.read_file(bad_endstream_path).binary(),
  )
  let strict_bad_endobj : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    @fs.read_file(bad_endobj_path).binary(),
  )
  let strict_truncated : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    @fs.read_file(truncated_path).binary(),
  )
  let bad_stream = pdf_read_document_from_file(bad_stream_path)
  let bad_endstream = pdf_read_document_from_file(bad_endstream_path)
  let bad_endobj = pdf_read_document_from_file(bad_endobj_path)
  let truncated = pdf_read_document_from_file(truncated_path)
  pdf_async_io_remove_if_exists_for_test(bad_stream_path)
  pdf_async_io_remove_if_exists_for_test(bad_endstream_path)
  pdf_async_io_remove_if_exists_for_test(bad_endobj_path)
  pdf_async_io_remove_if_exists_for_test(truncated_path)
  guard strict_bad_stream is Err(@pdflite.PdfError::ParseStreamExpected) else {
    fail("expected strict malformed stream keyword failure")
  }
  guard strict_bad_endstream is Err(@pdflite.PdfError::ParseEndStreamExpected) else {
    fail("expected strict malformed endstream failure")
  }
  guard strict_bad_endobj is Err(@pdflite.PdfError::ParseEndObjectExpected) else {
    fail("expected strict malformed endobj failure")
  }
  guard strict_truncated is Err(@pdflite.PdfError::EndOfInput) else {
    fail("expected strict truncated stream failure")
  }
  for parsed in [bad_stream, bad_endstream, bad_endobj] {
    @test.assert_eq(parsed.first_xref(), 0)
    @test.assert_eq(parsed.root(), 2)
    @test.assert_eq(parsed.object_numbers(), [2])
    @test.assert_eq(
      parsed.lookup_object_or_null(2),
      pdf_async_io_catalog_with_payload_for_test(1),
    )
  }
  @test.assert_eq(truncated.first_xref(), 0)
  @test.assert_eq(truncated.root(), 1)
  @test.assert_eq(truncated.object_numbers(), [1])
  @test.assert_eq(
    truncated.lookup_object_or_null(1),
    pdf_async_io_catalog_with_payload_for_test(2),
  )
}

///|
async test "async file wrappers reconstruct malformed objects" {
  let object_in_stream_path = pdf_async_io_test_path_for_test(
    "object_header_inside_stream",
  )
  let nested_object_path = pdf_async_io_test_path_for_test(
    "nested_object_header",
  )
  let bad_object_path = pdf_async_io_test_path_for_test("malformed_object_body")
  let bad_name_path = pdf_async_io_test_path_for_test("malformed_object_name")
  pdf_async_io_remove_if_exists_for_test(object_in_stream_path)
  pdf_async_io_remove_if_exists_for_test(nested_object_path)
  pdf_async_io_remove_if_exists_for_test(bad_object_path)
  pdf_async_io_remove_if_exists_for_test(bad_name_path)
  @fs.write_file(
    object_in_stream_path,
    pdf_async_io_malformed_pdf_with_object_header_inside_stream_for_test(),
    create=0o644,
  )
  @fs.write_file(
    nested_object_path,
    pdf_async_io_malformed_pdf_with_nested_object_header_for_test(),
    create=0o644,
  )
  @fs.write_file(
    bad_object_path,
    pdf_async_io_classic_pdf_with_malformed_object_for_test("]"),
    create=0o644,
  )
  @fs.write_file(
    bad_name_path,
    pdf_async_io_classic_pdf_with_malformed_object_for_test("/Bad#zz"),
    create=0o644,
  )
  let strict_bad_object : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    @fs.read_file(bad_object_path).binary(),
  )
  let strict_bad_name : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    @fs.read_file(bad_name_path).binary(),
  )
  let object_in_stream = pdf_read_document_from_file(object_in_stream_path)
  let nested_object = pdf_read_document_from_file(nested_object_path)
  let bad_object = pdf_read_document_from_file(bad_object_path)
  let bad_name = pdf_read_document_from_file(bad_name_path)
  pdf_async_io_remove_if_exists_for_test(object_in_stream_path)
  pdf_async_io_remove_if_exists_for_test(nested_object_path)
  pdf_async_io_remove_if_exists_for_test(bad_object_path)
  pdf_async_io_remove_if_exists_for_test(bad_name_path)
  guard strict_bad_object is Err(@pdflite.PdfError::ParseObjectExpected) else {
    fail("expected strict malformed object failure")
  }
  guard strict_bad_name is Err(@pdflite.PdfError::InvalidHexEscape) else {
    fail("expected strict malformed name failure")
  }
  @test.assert_eq(object_in_stream.first_xref(), 0)
  @test.assert_eq(object_in_stream.root(), 1)
  @test.assert_eq(object_in_stream.object_numbers(), [1, 2])
  @test.assert_eq(
    object_in_stream.lookup_object_or_null(1),
    pdf_async_io_catalog_with_payload_for_test(2),
  )
  guard object_in_stream.lookup_object_or_null(2) is PdfStreamObject(stream) else {
    fail("expected recovered stream object")
  }
  guard stream.data is StreamToGet(_) else {
    fail("expected deferred recovered stream object")
  }
  @test.assert_eq(
    try! @pdflite.pdf_stream(stream.dictionary, stream.data).stream_bytes(),
    @ascii.encode("9 0 obj\n<< /Type /Catalog >>\nendobj"),
  )
  @test.assert_eq(nested_object.first_xref(), 0)
  @test.assert_eq(nested_object.root(), 3)
  @test.assert_eq(nested_object.object_numbers(), [3])
  @test.assert_eq(
    nested_object.lookup_object_or_null(3),
    pdf_async_io_classic_catalog_object_for_test(),
  )
  for parsed in [bad_object, bad_name] {
    @test.assert_eq(parsed.first_xref(), 0)
    @test.assert_eq(parsed.root(), 1)
    @test.assert_eq(parsed.object_numbers(), [1])
    @test.assert_eq(
      parsed.lookup_object_or_null(1),
      pdf_async_io_catalog_with_payload_for_test(2),
    )
  }
}

///|
async test "async file wrappers preserve unreconstructable malformed read errors" {
  let rootless_path = pdf_async_io_test_path_for_test(
    "unreconstructable_missing_root",
  )
  let malformed_startxref_path = pdf_async_io_test_path_for_test(
    "unreconstructable_malformed_startxref",
  )
  pdf_async_io_remove_if_exists_for_test(rootless_path)
  pdf_async_io_remove_if_exists_for_test(malformed_startxref_path)
  @fs.write_file(
    rootless_path,
    @ascii.encode("%PDF-1.4\n1 0 obj\n1\nendobj\n"),
    create=0o644,
  )
  @fs.write_file(
    malformed_startxref_path,
    @ascii.encode("%PDF-1.4\nstartxref\nabc\n%%EOF\n"),
    create=0o644,
  )
  let rootless : Result[@pdflite.PdfDocument, Error] = try? pdf_read_document_from_file(
    rootless_path,
  )
  let malformed_startxref : Result[@pdflite.PdfDocument, Error] = try? pdf_read_document_from_file(
    malformed_startxref_path,
  )
  pdf_async_io_remove_if_exists_for_test(rootless_path)
  pdf_async_io_remove_if_exists_for_test(malformed_startxref_path)
  guard rootless is Err(@pdflite.PdfError::RootExpected) else {
    fail("expected unreconstructable rootless PDF to stay RootExpected")
  }
  guard malformed_startxref is Err(@pdflite.PdfError::NumberExpected) else {
    fail(
      "expected unreconstructable malformed startxref to stay NumberExpected",
    )
  }
}

///|
async test "async file wrappers load object-stream entries from disk" {
  let entries_path = pdf_async_io_test_path_for_test("objstm_entries")
  let entries_roundtrip_path = pdf_async_io_test_path_for_test(
    "objstm_entries_roundtrip",
  )
  let stream_path = pdf_async_io_test_path_for_test("objstm_stream_object")
  let stream_roundtrip_path = pdf_async_io_test_path_for_test(
    "objstm_stream_object_roundtrip",
  )
  pdf_async_io_remove_if_exists_for_test(entries_path)
  pdf_async_io_remove_if_exists_for_test(entries_roundtrip_path)
  pdf_async_io_remove_if_exists_for_test(stream_path)
  pdf_async_io_remove_if_exists_for_test(stream_roundtrip_path)
  @fs.write_file(
    entries_path,
    pdf_async_io_xref_stream_pdf_with_two_object_stream_entries_for_test(),
    create=0o644,
  )
  @fs.write_file(
    stream_path,
    pdf_async_io_xref_stream_pdf_with_stream_object_in_object_stream_for_test(),
    create=0o644,
  )
  @test.assert_eq(pdf_read_header_from_file(entries_path), {
    major: 1,
    minor: 5,
  })
  @test.assert_eq(pdf_read_header_from_file(stream_path), { major: 1, minor: 5 })
  let entries = pdf_read_document_from_file(entries_path)
  let embedded_stream_doc = pdf_read_document_from_file(stream_path)
  pdf_write_document_to_file_with_compressed_xref_stream(
    entries, entries_roundtrip_path,
  )
  pdf_write_document_to_file_with_compressed_xref_stream(
    embedded_stream_doc, stream_roundtrip_path,
  )
  let entries_reparsed = pdf_read_document_from_file(entries_roundtrip_path)
  let embedded_stream_reparsed = pdf_read_document_from_file(
    stream_roundtrip_path,
  )
  guard embedded_stream_doc.lookup_object_or_null(2)
    is PdfStreamObject(embedded_stream) else {
    fail("expected embedded stream object")
  }
  let embedded_stream_length = embedded_stream.dictionary.lookup_immediate(
    pdf_async_io_name_for_test("/Length"),
  )
  let embedded_stream_bytes = try! @pdflite.pdf_stream(
    embedded_stream.dictionary,
    embedded_stream.data,
  ).stream_bytes()
  guard embedded_stream_reparsed.lookup_object_or_null(2)
    is PdfStreamObject(reparsed_stream) else {
    fail("expected reparsed embedded stream object")
  }
  let reparsed_stream_length = reparsed_stream.dictionary.lookup_immediate(
    pdf_async_io_name_for_test("/Length"),
  )
  let reparsed_stream_bytes = try! @pdflite.pdf_stream(
    reparsed_stream.dictionary,
    reparsed_stream.data,
  ).stream_bytes()
  pdf_async_io_remove_if_exists_for_test(entries_path)
  pdf_async_io_remove_if_exists_for_test(entries_roundtrip_path)
  pdf_async_io_remove_if_exists_for_test(stream_path)
  pdf_async_io_remove_if_exists_for_test(stream_roundtrip_path)

  @test.assert_eq(entries.first_xref() > 0, true)
  @test.assert_eq(entries.root(), 1)
  @test.assert_eq(entries.object_numbers(), [1, 2, 3, 5])
  @test.assert_eq(
    entries.lookup_object_or_null(2),
    PdfDictionary([(pdf_async_io_name_for_test("/Answer"), PdfInteger(42))]),
  )
  @test.assert_eq(
    entries.lookup_object_or_null(5),
    PdfArray([PdfInteger(1), PdfInteger(2), PdfInteger(3)]),
  )
  guard entries.lookup_object_or_null(3) is PdfStreamObject(object_stream) else {
    fail("expected retained object stream")
  }
  @test.assert_eq(
    object_stream.dictionary.lookup_immediate(
      pdf_async_io_name_for_test("/Type"),
    ),
    Some(PdfNameObject(pdf_async_io_name_for_test("/ObjStm"))),
  )
  @test.assert_eq(entries_reparsed.first_xref() > 0, true)
  @test.assert_eq(
    entries_reparsed.lookup_object_or_null(2),
    PdfDictionary([(pdf_async_io_name_for_test("/Answer"), PdfInteger(42))]),
  )
  @test.assert_eq(
    entries_reparsed.lookup_object_or_null(5),
    PdfArray([PdfInteger(1), PdfInteger(2), PdfInteger(3)]),
  )
  @test.assert_eq(embedded_stream_doc.object_numbers(), [1, 2, 3])
  @test.assert_eq(
    embedded_stream_doc.lookup_object_or_null(1),
    pdf_async_io_catalog_with_payload_for_test(2),
  )
  @test.assert_eq(embedded_stream_length, Some(PdfInteger(2)))
  @test.assert_eq(embedded_stream_bytes, @ascii.encode("Hi"))
  @test.assert_eq(
    embedded_stream_reparsed.lookup_object_or_null(1),
    pdf_async_io_catalog_with_payload_for_test(2),
  )
  @test.assert_eq(reparsed_stream_length, Some(PdfInteger(2)))
  @test.assert_eq(reparsed_stream_bytes, @ascii.encode("Hi"))
}

///|
async test "async file wrappers reconstruct multi-revision object-stream roots" {
  let path = pdf_async_io_test_path_for_test("objstm_root_prev_bad_startxref")
  let repaired_path = pdf_async_io_test_path_for_test(
    "objstm_root_prev_bad_startxref_repaired",
  )
  pdf_async_io_remove_if_exists_for_test(path)
  pdf_async_io_remove_if_exists_for_test(repaired_path)
  @fs.write_file(
    path,
    pdf_async_io_xref_stream_prev_update_with_object_stream_root_bad_startxref_for_test(),
    create=0o644,
  )
  @test.assert_eq(pdf_read_header_from_file(path), { major: 1, minor: 5 })
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    @fs.read_file(path).binary(),
  )
  guard strict is Err(@pdflite.PdfError::XRefExpected) else {
    fail("expected strict object-stream root reconstruction failure")
  }
  let recovered = pdf_read_document_from_file(path)
  pdf_write_document_to_file_with_compressed_xref_stream(
    recovered, repaired_path,
  )
  let reparsed = pdf_read_document_from_file(repaired_path)
  pdf_async_io_remove_if_exists_for_test(path)
  pdf_async_io_remove_if_exists_for_test(repaired_path)

  @test.assert_eq(recovered.first_xref(), 0)
  @test.assert_eq(recovered.root(), 1)
  @test.assert_eq(recovered.object_numbers(), [1, 3])
  @test.assert_eq(
    recovered
    .trailer_dict()
    .lookup_immediate(pdf_async_io_name_for_test("/Prev")),
    None,
  )
  @test.assert_eq(
    recovered
    .lookup_object_or_null(1)
    .lookup_immediate(pdf_async_io_name_for_test("/New")),
    Some(PdfBoolean(true)),
  )
  @test.assert_eq(
    recovered
    .lookup_object_or_null(1)
    .lookup_immediate(pdf_async_io_name_for_test("/Old")),
    None,
  )
  guard recovered.lookup_object_or_null(3) is PdfStreamObject(object_stream) else {
    fail("expected retained object stream")
  }
  @test.assert_eq(
    object_stream.dictionary.lookup_immediate(
      pdf_async_io_name_for_test("/Type"),
    ),
    Some(PdfNameObject(pdf_async_io_name_for_test("/ObjStm"))),
  )
  @test.assert_eq(reparsed.first_xref() > 0, true)
  @test.assert_eq(
    reparsed
    .lookup_object_or_null(1)
    .lookup_immediate(pdf_async_io_name_for_test("/New")),
    Some(PdfBoolean(true)),
  )
  @test.assert_eq(
    reparsed
    .lookup_object_or_null(1)
    .lookup_immediate(pdf_async_io_name_for_test("/Old")),
    None,
  )
}

///|
async test "async file wrappers do not reconstruct object-stream decode failures" {
  let filter_path = pdf_async_io_test_path_for_test("bad_objstm_filter")
  let decodeparms_path = pdf_async_io_test_path_for_test(
    "bad_objstm_decodeparms",
  )
  let predictor_path = pdf_async_io_test_path_for_test("bad_objstm_predictor")
  pdf_async_io_remove_if_exists_for_test(filter_path)
  pdf_async_io_remove_if_exists_for_test(decodeparms_path)
  pdf_async_io_remove_if_exists_for_test(predictor_path)
  @fs.write_file(
    filter_path,
    pdf_async_io_xref_stream_pdf_with_bad_filtered_object_stream_root_for_test(),
    create=0o644,
  )
  @fs.write_file(
    decodeparms_path,
    pdf_async_io_xref_stream_pdf_with_bad_decodeparms_object_stream_root_for_test(),
    create=0o644,
  )
  @fs.write_file(
    predictor_path,
    pdf_async_io_xref_stream_pdf_with_unsupported_predictor_object_stream_root_for_test(),
    create=0o644,
  )
  @test.assert_eq(pdf_read_header_from_file(filter_path), { major: 1, minor: 5 })
  let filter_result : Result[@pdflite.PdfDocument, Error] = try? pdf_read_document_from_file(
    filter_path,
  )
  let decodeparms_result : Result[@pdflite.PdfDocument, Error] = try? pdf_read_document_from_file(
    decodeparms_path,
  )
  let predictor_result : Result[@pdflite.PdfDocument, Error] = try? pdf_read_document_from_file(
    predictor_path,
  )
  pdf_async_io_remove_if_exists_for_test(filter_path)
  pdf_async_io_remove_if_exists_for_test(decodeparms_path)
  pdf_async_io_remove_if_exists_for_test(predictor_path)

  guard filter_result is Err(@pdflite.PdfError::FilterNotSupported(filter)) else {
    fail("expected unsupported object-stream filter")
  }
  @test.assert_eq(filter, pdf_async_io_name_for_test("/BadObjectStreamFilter"))
  guard decodeparms_result is Err(@pdflite.PdfError::PredictorExpected) else {
    fail("expected malformed object-stream DecodeParms")
  }
  guard predictor_result
    is Err(@pdflite.PdfError::PredictorNotSupported(predictor)) else {
    fail("expected unsupported object-stream predictor")
  }
  @test.assert_eq(predictor, 9)
}

///|
async test "async file wrappers reconstruct indirect object-stream bounds" {
  let path = pdf_async_io_test_path_for_test("indirect_objstm_bounds")
  let repaired_path = pdf_async_io_test_path_for_test(
    "indirect_objstm_bounds_repaired",
  )
  pdf_async_io_remove_if_exists_for_test(path)
  pdf_async_io_remove_if_exists_for_test(repaired_path)
  @fs.write_file(
    path,
    pdf_async_io_indirect_object_stream_bounds_bad_startxref_for_test(),
    create=0o644,
  )
  @test.assert_eq(pdf_read_header_from_file(path), { major: 1, minor: 5 })
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    @fs.read_file(path).binary(),
  )
  guard strict is Err(@pdflite.PdfError::XRefExpected) else {
    fail("expected strict XRefExpected")
  }
  let recovered = pdf_read_document_from_file(path)
  @test.assert_eq(recovered.first_xref(), 0)
  @test.assert_eq(recovered.object_numbers(), [1, 2, 3, 5, 7])
  @test.assert_eq(
    recovered.lookup_object_or_null(7),
    PdfDictionary([(pdf_async_io_name_for_test("/Answer"), PdfInteger(42))]),
  )
  pdf_write_document_to_file_with_compressed_xref_stream(
    recovered, repaired_path,
  )
  let reparsed = pdf_read_document_from_file(repaired_path)
  pdf_async_io_remove_if_exists_for_test(path)
  pdf_async_io_remove_if_exists_for_test(repaired_path)
  @test.assert_eq(reparsed.first_xref() > 0, true)
  @test.assert_eq(
    reparsed.lookup_object_or_null(7),
    PdfDictionary([(pdf_async_io_name_for_test("/Answer"), PdfInteger(42))]),
  )
}

///|
async test "async file wrappers reconstruct object streams with indirect filters" {
  let path = pdf_async_io_test_path_for_test("indirect_objstm_filter")
  let repaired_path = pdf_async_io_test_path_for_test(
    "indirect_objstm_filter_repaired",
  )
  pdf_async_io_remove_if_exists_for_test(path)
  pdf_async_io_remove_if_exists_for_test(repaired_path)
  @fs.write_file(
    path,
    pdf_async_io_indirect_object_stream_filter_bad_startxref_for_test(),
    create=0o644,
  )
  @test.assert_eq(pdf_read_header_from_file(path), { major: 1, minor: 5 })
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    @fs.read_file(path).binary(),
  )
  guard strict is Err(@pdflite.PdfError::XRefExpected) else {
    fail("expected strict XRefExpected")
  }
  let recovered = pdf_read_document_from_file(path)
  @test.assert_eq(recovered.first_xref(), 0)
  @test.assert_eq(recovered.object_numbers(), [1, 2, 3, 5])
  @test.assert_eq(
    recovered.lookup_object_or_null(5),
    PdfDictionary([(pdf_async_io_name_for_test("/Answer"), PdfInteger(42))]),
  )
  guard recovered.lookup_object_or_null(3) is PdfStreamObject(object_stream) else {
    fail("expected object stream")
  }
  @test.assert_eq(
    object_stream.dictionary.lookup_immediate(
      pdf_async_io_name_for_test("/Filter"),
    ),
    Some(PdfIndirect(2)),
  )
  pdf_write_document_to_file_with_compressed_xref_stream(
    recovered, repaired_path,
  )
  let reparsed = pdf_read_document_from_file(repaired_path)
  pdf_async_io_remove_if_exists_for_test(path)
  pdf_async_io_remove_if_exists_for_test(repaired_path)
  @test.assert_eq(reparsed.first_xref() > 0, true)
  @test.assert_eq(
    reparsed.lookup_object_or_null(5),
    PdfDictionary([(pdf_async_io_name_for_test("/Answer"), PdfInteger(42))]),
  )
}

///|
async test "async file wrappers read encrypted object streams and recover bad startxref" {
  let encrypted_path = pdf_async_io_test_path_for_test("encrypted_objstm")
  let corrupted_path = pdf_async_io_test_path_for_test(
    "encrypted_objstm_bad_startxref",
  )
  let blank_path = pdf_async_io_test_path_for_test("encrypted_objstm_blank")
  pdf_async_io_remove_if_exists_for_test(encrypted_path)
  pdf_async_io_remove_if_exists_for_test(corrupted_path)
  pdf_async_io_remove_if_exists_for_test(blank_path)
  let denied : Array[@pdflite.PdfPermission] = [PdfNoCopy]
  let encrypted = try! pdf_async_io_encrypted_object_stream_pdf_for_test(
    @ascii.encode("user"),
    @ascii.encode("owner"),
    denied,
  )
  @fs.write_file(encrypted_path, encrypted, create=0o644)
  let decrypted = pdf_async_io_decryption_result_for_test(
    pdf_read_document_from_file_with_passwords(
      encrypted_path,
      owner_password=Some(@ascii.encode("owner")),
    ),
  )
  pdf_async_io_assert_decrypted_object_stream_for_test(decrypted, denied)

  let corrupted = pdf_async_io_corrupt_final_startxref_pointer_for_test(
    encrypted,
  )
  @fs.write_file(corrupted_path, corrupted, create=0o644)
  let partial = pdf_read_document_from_file(corrupted_path)
  @test.assert_eq(partial.first_xref(), 0)
  @test.assert_eq(partial.lookup_object_or_null(2), PdfNull)
  let recovered = pdf_async_io_decryption_result_for_test(
    pdf_read_document_from_file_with_passwords(
      corrupted_path,
      owner_password=Some(@ascii.encode("owner")),
    ),
  )
  @test.assert_eq(recovered.document.first_xref(), 0)
  pdf_async_io_assert_decrypted_object_stream_for_test(recovered, denied)

  let blank = try! pdf_async_io_encrypted_object_stream_pdf_for_test(
    @ascii.encode(""),
    @ascii.encode("owner"),
    denied,
  )
  @fs.write_file(blank_path, blank, create=0o644)
  let blank_decrypted = pdf_async_io_decryption_result_for_test(
    pdf_read_document_from_file_with_passwords(blank_path),
  )
  pdf_async_io_remove_if_exists_for_test(encrypted_path)
  pdf_async_io_remove_if_exists_for_test(corrupted_path)
  pdf_async_io_remove_if_exists_for_test(blank_path)
  pdf_async_io_assert_decrypted_object_stream_for_test(blank_decrypted, denied)
}

///|
async test "async file wrappers reject encrypted xref streams with missing object streams" {
  let path = pdf_async_io_test_path_for_test(
    "encrypted_xref_stream_missing_objstm",
  )
  pdf_async_io_remove_if_exists_for_test(path)
  @fs.write_file(
    path,
    pdf_async_io_encrypted_xref_stream_missing_object_stream_for_test(),
    create=0o644,
  )
  @test.assert_eq(pdf_read_header_from_file(path), { major: 1, minor: 5 })
  let result : Result[@pdflite.PdfDecryptionResult?, Error] = try? pdf_read_document_from_file_with_passwords(
    path,
  )
  pdf_async_io_remove_if_exists_for_test(path)
  guard result is Err(@pdflite.PdfError::XRefEntryExpected) else {
    fail("expected missing encrypted object stream to remain unrecoverable")
  }
}

///|
async test "async file wrappers recrypt encrypted object-stream payloads" {
  let source_path = pdf_async_io_test_path_for_test("encrypted_objstm_recrypt")
  let roundtrip_path = pdf_async_io_test_path_for_test(
    "encrypted_objstm_recrypt_roundtrip",
  )
  pdf_async_io_remove_if_exists_for_test(source_path)
  pdf_async_io_remove_if_exists_for_test(roundtrip_path)
  let denied : Array[@pdflite.PdfPermission] = [PdfNoCopy]
  let user_password = @ascii.encode("user")
  let owner_password = @ascii.encode("owner")
  let encrypted = try! pdf_async_io_encrypted_object_stream_pdf_for_test(
    user_password, owner_password, denied,
  )
  @fs.write_file(source_path, encrypted, create=0o644)
  let decrypted = pdf_async_io_decryption_result_for_test(
    pdf_read_document_from_file_with_passwords(
      source_path,
      owner_password=Some(owner_password),
    ),
  )
  pdf_async_io_assert_decrypted_object_stream_for_test(decrypted, denied)
  let added_object : @pdflite.PdfObject = PdfString(
    @ascii.encode("async object-stream recrypt added"),
  )
  decrypted.document.add_object_given_number(6, added_object)
  let recrypted = try! decrypted.document.recrypt_with_password_aesv2_with_iv_provider(
    owner_password,
    @pdflite.pdf_deterministic_aes_iv_provider_from_seed(
      @ascii.encode("async object-stream recrypt iv"),
    ),
  )
  pdf_write_document_to_file_with_compressed_xref_stream(
    recrypted, roundtrip_path,
  )
  @test.assert_eq(
    pdf_async_io_find_bytes_for_test(
      @fs.read_file(roundtrip_path).binary(),
      @ascii.encode("async encrypted object stream"),
    ) <
    0,
    true,
  )
  let roundtrip = pdf_async_io_decryption_result_for_test(
    pdf_read_document_from_file_with_passwords(
      roundtrip_path,
      user_password=Some(user_password),
    ),
  )
  pdf_async_io_remove_if_exists_for_test(source_path)
  pdf_async_io_remove_if_exists_for_test(roundtrip_path)
  pdf_async_io_assert_decrypted_object_stream_for_test(roundtrip, denied)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(6), added_object)
}

///|
async test "async file wrappers write mode-dispatched encrypted documents" {
  let mode_path = pdf_async_io_test_path_for_test("mode_dispatch")
  let arc4_40_path = pdf_async_io_test_path_for_test("encrypt_40")
  let arc4_128_path = pdf_async_io_test_path_for_test("encrypt_128")
  let arc4_r4_path = pdf_async_io_test_path_for_test("encrypt_r4")
  let aesv2_path = pdf_async_io_test_path_for_test("encrypt_aesv2")
  let aesv2_default_path = pdf_async_io_test_path_for_test(
    "encrypt_aesv2_default",
  )
  let aesv3_path = pdf_async_io_test_path_for_test("encrypt_aesv3")
  let aesv3_default_path = pdf_async_io_test_path_for_test(
    "encrypt_aesv3_default",
  )
  let aesv3_iso_path = pdf_async_io_test_path_for_test("encrypt_aesv3_iso")
  let aesv3_iso_default_path = pdf_async_io_test_path_for_test(
    "encrypt_aesv3_iso_default",
  )
  pdf_async_io_remove_if_exists_for_test(mode_path)
  pdf_async_io_remove_if_exists_for_test(arc4_40_path)
  pdf_async_io_remove_if_exists_for_test(arc4_128_path)
  pdf_async_io_remove_if_exists_for_test(arc4_r4_path)
  pdf_async_io_remove_if_exists_for_test(aesv2_path)
  pdf_async_io_remove_if_exists_for_test(aesv2_default_path)
  pdf_async_io_remove_if_exists_for_test(aesv3_path)
  pdf_async_io_remove_if_exists_for_test(aesv3_default_path)
  pdf_async_io_remove_if_exists_for_test(aesv3_iso_path)
  pdf_async_io_remove_if_exists_for_test(aesv3_iso_default_path)
  let user = @ascii.encode("user")
  let owner = @ascii.encode("owner")
  let denied : Array[@pdflite.PdfPermission] = [PdfNoEdit, PdfNoPrint]
  pdf_write_document_to_file_with_mode(
    try! @pdflite.pdf_minimum_valid_pdf(),
    mode_path,
    PdfWriteCompressedXRefStream,
  )
  @test.assert_eq(pdf_read_document_from_file(mode_path).version(), (1, 5))
  pdf_write_encrypted_40bit_document_to_file(
    try! pdf_async_io_secret_document_for_test("async-40"),
    arc4_40_path,
    user,
    owner,
    denied,
    file_id=@ascii.encode("async-40-id"),
  )
  pdf_async_io_assert_encrypted_file_secret_for_test(
    arc4_40_path, "owner", denied, "async-40",
  )
  pdf_write_encrypted_128bit_document_to_file(
    try! pdf_async_io_secret_document_for_test("async-128"),
    arc4_128_path,
    user,
    owner,
    denied,
    mode=PdfWriteXRefStream,
    file_id=@ascii.encode("async-128-id"),
  )
  pdf_async_io_assert_encrypted_file_secret_for_test(
    arc4_128_path, "owner", denied, "async-128",
  )
  pdf_write_encrypted_128bit_r4_document_to_file(
    try! pdf_async_io_secret_document_for_test("async-r4"),
    arc4_r4_path,
    user,
    owner,
    denied,
    encrypt_metadata=false,
    mode=PdfWriteCompressedXRefStream,
    file_id=@ascii.encode("async-r4-id"),
  )
  pdf_async_io_assert_encrypted_file_secret_for_test(
    arc4_r4_path, "owner", denied, "async-r4",
  )
  pdf_write_encrypted_aesv2_document_to_file_with_iv_provider(
    try! pdf_async_io_secret_document_for_test("async-aesv2"),
    aesv2_path,
    user,
    owner,
    [PdfNoCopy],
    @pdflite.pdf_deterministic_aes_iv_provider_from_seed(
      @ascii.encode("async-aesv2-iv"),
    ),
    encrypt_metadata=false,
    mode=PdfWriteCompressedXRefStream,
    file_id=@ascii.encode("async-aesv2-id"),
  )
  pdf_async_io_assert_encrypted_file_secret_for_test(
    aesv2_path,
    "owner",
    [PdfNoCopy],
    "async-aesv2",
  )
  pdf_write_encrypted_aesv2_document_to_file(
    try! pdf_async_io_secret_document_for_test("async-aesv2-default"),
    aesv2_default_path,
    user,
    owner,
    [PdfNoPrint],
    encrypt_metadata=false,
    mode=PdfWriteCompressedXRefStream,
    file_id=@ascii.encode("async-aesv2-default-id"),
  )
  pdf_async_io_assert_encrypted_file_secret_for_test(
    aesv2_default_path,
    "owner",
    [PdfNoPrint],
    "async-aesv2-default",
  )
  pdf_write_encrypted_aesv3_document_to_file_with_providers(
    try! pdf_async_io_secret_document_for_test("async-aesv3"),
    aesv3_path,
    user,
    owner,
    [PdfNoExtract],
    @pdflite.pdf_deterministic_aesv3_random_provider_from_seed(
      @ascii.encode("async-aesv3-random"),
    ),
    @pdflite.pdf_deterministic_aes_iv_provider_from_seed(
      @ascii.encode("async-aesv3-iv"),
    ),
    mode=PdfWriteXRefStream,
    file_id=@ascii.encode("async-aesv3-id"),
  )
  pdf_async_io_assert_encrypted_file_secret_for_test(
    aesv3_path,
    "owner",
    [PdfNoExtract],
    "async-aesv3",
  )
  pdf_write_encrypted_aesv3_document_to_file(
    try! pdf_async_io_secret_document_for_test("async-aesv3-default"),
    aesv3_default_path,
    user,
    owner,
    [PdfNoExtract],
    encrypt_metadata=false,
    mode=PdfWriteCompressedXRefStream,
    file_id=@ascii.encode("async-aesv3-default-id"),
  )
  pdf_async_io_assert_encrypted_file_secret_for_test(
    aesv3_default_path,
    "owner",
    [PdfNoExtract],
    "async-aesv3-default",
  )
  pdf_write_encrypted_aesv3_iso_document_to_file_with_providers(
    try! pdf_async_io_secret_document_for_test("async-aesv3-iso"),
    aesv3_iso_path,
    user,
    owner,
    [PdfNoAssemble],
    @pdflite.pdf_deterministic_aesv3_random_provider_from_seed(
      @ascii.encode("async-aesv3-iso-random"),
    ),
    @pdflite.pdf_deterministic_aes_iv_provider_from_seed(
      @ascii.encode("async-aesv3-iso-iv"),
    ),
    encrypt_metadata=false,
    file_id=@ascii.encode("async-aesv3-iso-id"),
  )
  pdf_async_io_assert_encrypted_file_secret_for_test(
    aesv3_iso_path,
    "owner",
    [PdfNoAssemble],
    "async-aesv3-iso",
  )
  pdf_write_encrypted_aesv3_iso_document_to_file(
    try! pdf_async_io_secret_document_for_test("async-aesv3-iso-default"),
    aesv3_iso_default_path,
    user,
    owner,
    [PdfNoAssemble],
    encrypt_metadata=false,
    file_id=@ascii.encode("async-aesv3-iso-default-id"),
  )
  pdf_async_io_assert_encrypted_file_secret_for_test(
    aesv3_iso_default_path,
    "owner",
    [PdfNoAssemble],
    "async-aesv3-iso-default",
  )
  pdf_async_io_remove_if_exists_for_test(mode_path)
  pdf_async_io_remove_if_exists_for_test(arc4_40_path)
  pdf_async_io_remove_if_exists_for_test(arc4_128_path)
  pdf_async_io_remove_if_exists_for_test(arc4_r4_path)
  pdf_async_io_remove_if_exists_for_test(aesv2_path)
  pdf_async_io_remove_if_exists_for_test(aesv2_default_path)
  pdf_async_io_remove_if_exists_for_test(aesv3_path)
  pdf_async_io_remove_if_exists_for_test(aesv3_default_path)
  pdf_async_io_remove_if_exists_for_test(aesv3_iso_path)
  pdf_async_io_remove_if_exists_for_test(aesv3_iso_default_path)
}

///|
async test "async file wrappers reconstruct compressed ARC4 encrypted documents with bad startxref" {
  let encrypted_path = pdf_async_io_test_path_for_test(
    "compressed_arc4_bad_startxref",
  )
  let corrupted_path = pdf_async_io_test_path_for_test(
    "compressed_arc4_bad_startxref_corrupted",
  )
  let repaired_path = pdf_async_io_test_path_for_test(
    "compressed_arc4_bad_startxref_repaired",
  )
  pdf_async_io_remove_if_exists_for_test(encrypted_path)
  pdf_async_io_remove_if_exists_for_test(corrupted_path)
  pdf_async_io_remove_if_exists_for_test(repaired_path)
  let secret = pdf_async_io_secret_object_for_test(
    "async compressed arc4 secret",
  )
  let doc = try! @pdflite.pdf_minimum_valid_pdf()
  doc.add_object_given_number(30, secret)
  let user = @ascii.encode("user")
  let owner = @ascii.encode("owner")
  let denied : Array[@pdflite.PdfPermission] = [PdfNoPrint]
  pdf_write_encrypted_128bit_r4_document_to_file(
    doc,
    encrypted_path,
    user,
    owner,
    denied,
    encrypt_metadata=false,
    mode=PdfWriteCompressedXRefStream,
    file_id=@ascii.encode("async-arc4-id"),
  )
  @test.assert_eq(
    pdf_async_io_find_bytes_for_test(
      @fs.read_file(encrypted_path).binary(),
      @ascii.encode("async compressed arc4 secret"),
    ) <
    0,
    true,
  )
  let corrupted = pdf_async_io_corrupt_final_startxref_pointer_for_test(
    @fs.read_file(encrypted_path).binary(),
  )
  @fs.write_file(corrupted_path, corrupted, create=0o644)
  let recovered = pdf_async_io_decryption_result_for_test(
    pdf_read_document_from_file_with_passwords(
      corrupted_path,
      owner_password=Some(owner),
    ),
  )
  @test.assert_eq(recovered.document.first_xref(), 0)
  @test.assert_eq(recovered.denied_permissions, denied)
  @test.assert_eq(recovered.document.lookup_object_or_null(30), secret)
  let added_secret = pdf_async_io_secret_object_for_test(
    "async compressed arc4 repaired",
  )
  recovered.document.add_object_given_number(31, added_secret)
  let recrypted = try! recovered.document.recrypt_with_password(owner)
  @test.assert_eq(try! recrypted.what_encryption(), Some(PdfEncryption128Bit))
  pdf_write_document_to_file_with_compressed_xref_stream(
    recrypted, repaired_path,
  )
  let roundtrip = pdf_async_io_decryption_result_for_test(
    pdf_read_document_from_file_with_passwords(
      repaired_path,
      user_password=Some(user),
    ),
  )
  pdf_async_io_remove_if_exists_for_test(encrypted_path)
  pdf_async_io_remove_if_exists_for_test(corrupted_path)
  pdf_async_io_remove_if_exists_for_test(repaired_path)
  @test.assert_eq(roundtrip.denied_permissions, denied)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(30), secret)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(31), added_secret)
}

///|
async fn pdf_async_io_assert_legacy_arc4_recovery_for_test(
  label : String,
  key_length_bits : Int,
  expected_encryption : @pdflite.PdfEncryptionMethod,
) -> Unit {
  let encrypted_path = pdf_async_io_test_path_for_test(
    "compressed_arc4_" + label + "_bad_startxref",
  )
  let corrupted_path = pdf_async_io_test_path_for_test(
    "compressed_arc4_" + label + "_bad_startxref_corrupted",
  )
  let repaired_path = pdf_async_io_test_path_for_test(
    "compressed_arc4_" + label + "_bad_startxref_repaired",
  )
  pdf_async_io_remove_if_exists_for_test(encrypted_path)
  pdf_async_io_remove_if_exists_for_test(corrupted_path)
  pdf_async_io_remove_if_exists_for_test(repaired_path)
  let secret_text = "async compressed arc4 " + label + " secret"
  let secret = pdf_async_io_secret_object_for_test(secret_text)
  let doc = try! @pdflite.pdf_minimum_valid_pdf()
  doc.add_object_given_number(30, secret)
  let user = @ascii.encode("user")
  let owner = @ascii.encode("owner")
  let denied : Array[@pdflite.PdfPermission] = [PdfNoPrint]
  if key_length_bits == 40 {
    pdf_write_encrypted_40bit_document_to_file(
      doc,
      encrypted_path,
      user,
      owner,
      denied,
      mode=PdfWriteCompressedXRefStream,
      file_id=@ascii.encode("a40-id"),
    )
  } else {
    pdf_write_encrypted_128bit_document_to_file(
      doc,
      encrypted_path,
      user,
      owner,
      denied,
      mode=PdfWriteCompressedXRefStream,
      file_id=@ascii.encode("a128-id"),
    )
  }
  @test.assert_eq(
    pdf_async_io_find_bytes_for_test(
      @fs.read_file(encrypted_path).binary(),
      @ascii.encode(secret_text),
    ) <
    0,
    true,
  )
  let corrupted = pdf_async_io_corrupt_final_startxref_pointer_for_test(
    @fs.read_file(encrypted_path).binary(),
  )
  @fs.write_file(corrupted_path, corrupted, create=0o644)
  let recovered = pdf_async_io_decryption_result_for_test(
    pdf_read_document_from_file_with_passwords(
      corrupted_path,
      owner_password=Some(owner),
    ),
  )
  @test.assert_eq(recovered.document.first_xref(), 0)
  @test.assert_eq(recovered.denied_permissions, denied)
  @test.assert_eq(recovered.document.lookup_object_or_null(30), secret)
  let added_secret = pdf_async_io_secret_object_for_test(
    "async compressed arc4 " + label + " repaired",
  )
  recovered.document.add_object_given_number(31, added_secret)
  let recrypted = try! recovered.document.recrypt_with_password(owner)
  @test.assert_eq(try! recrypted.what_encryption(), Some(expected_encryption))
  pdf_write_document_to_file_with_compressed_xref_stream(
    recrypted, repaired_path,
  )
  let roundtrip = pdf_async_io_decryption_result_for_test(
    pdf_read_document_from_file_with_passwords(
      repaired_path,
      user_password=Some(user),
    ),
  )
  pdf_async_io_remove_if_exists_for_test(encrypted_path)
  pdf_async_io_remove_if_exists_for_test(corrupted_path)
  pdf_async_io_remove_if_exists_for_test(repaired_path)
  @test.assert_eq(roundtrip.denied_permissions, denied)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(30), secret)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(31), added_secret)
}

///|
async test "async file wrappers reconstruct compressed legacy ARC4 encrypted documents with bad startxref" {
  pdf_async_io_assert_legacy_arc4_recovery_for_test(
    "40",
    40,
    PdfEncryption40Bit,
  )
  pdf_async_io_assert_legacy_arc4_recovery_for_test(
    "128",
    128,
    PdfEncryption128Bit,
  )
}

///|
async test "async file wrappers reconstruct compressed encrypted documents with bad startxref" {
  let encrypted_path = pdf_async_io_test_path_for_test(
    "compressed_encrypted_bad_startxref",
  )
  let corrupted_path = pdf_async_io_test_path_for_test(
    "compressed_encrypted_bad_startxref_corrupted",
  )
  let repaired_path = pdf_async_io_test_path_for_test(
    "compressed_encrypted_bad_startxref_repaired",
  )
  pdf_async_io_remove_if_exists_for_test(encrypted_path)
  pdf_async_io_remove_if_exists_for_test(corrupted_path)
  pdf_async_io_remove_if_exists_for_test(repaired_path)
  let secret = pdf_async_io_secret_object_for_test(
    "async compressed encrypted secret",
  )
  let doc = try! @pdflite.pdf_minimum_valid_pdf()
  doc.add_object_given_number(30, secret)
  let user = @ascii.encode("user")
  let owner = @ascii.encode("owner")
  let denied : Array[@pdflite.PdfPermission] = [PdfNoCopy, PdfNoPrint]
  pdf_write_encrypted_aesv2_document_to_file_with_iv_provider(
    doc,
    encrypted_path,
    user,
    owner,
    denied,
    @pdflite.pdf_deterministic_aes_iv_provider_from_seed(
      @ascii.encode("async compressed encrypted iv"),
    ),
    encrypt_metadata=false,
    mode=PdfWriteCompressedXRefStream,
    file_id=@ascii.encode("async-compressed-encrypted-id"),
  )
  @test.assert_eq(
    pdf_async_io_find_bytes_for_test(
      @fs.read_file(encrypted_path).binary(),
      @ascii.encode("async compressed encrypted secret"),
    ) <
    0,
    true,
  )
  let corrupted = pdf_async_io_corrupt_final_startxref_pointer_for_test(
    @fs.read_file(encrypted_path).binary(),
  )
  @fs.write_file(corrupted_path, corrupted, create=0o644)
  let recovered = pdf_async_io_decryption_result_for_test(
    pdf_read_document_from_file_with_passwords(
      corrupted_path,
      owner_password=Some(owner),
    ),
  )
  @test.assert_eq(recovered.document.first_xref(), 0)
  @test.assert_eq(recovered.denied_permissions, denied)
  @test.assert_eq(recovered.document.lookup_object_or_null(30), secret)
  let added_secret = pdf_async_io_secret_object_for_test(
    "async compressed encrypted repaired",
  )
  recovered.document.add_object_given_number(31, added_secret)
  let recrypted = try! recovered.document.recrypt_with_password_aesv2_with_iv_provider(
    owner,
    @pdflite.pdf_deterministic_aes_iv_provider_from_seed(
      @ascii.encode("async compressed encrypted repair iv"),
    ),
  )
  pdf_write_document_to_file_with_compressed_xref_stream(
    recrypted, repaired_path,
  )
  let roundtrip = pdf_async_io_decryption_result_for_test(
    pdf_read_document_from_file_with_passwords(
      repaired_path,
      user_password=Some(user),
    ),
  )
  pdf_async_io_remove_if_exists_for_test(encrypted_path)
  pdf_async_io_remove_if_exists_for_test(corrupted_path)
  pdf_async_io_remove_if_exists_for_test(repaired_path)
  @test.assert_eq(roundtrip.denied_permissions, denied)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(30), secret)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(31), added_secret)
}

///|
async test "async file wrappers reconstruct encrypted malformed classic xref offsets" {
  let encrypted_path = pdf_async_io_test_path_for_test(
    "encrypted_bad_classic_xref_offset",
  )
  let malformed_path = pdf_async_io_test_path_for_test(
    "encrypted_bad_classic_xref_offset_malformed",
  )
  let repaired_path = pdf_async_io_test_path_for_test(
    "encrypted_bad_classic_xref_offset_repaired",
  )
  pdf_async_io_remove_if_exists_for_test(encrypted_path)
  pdf_async_io_remove_if_exists_for_test(malformed_path)
  pdf_async_io_remove_if_exists_for_test(repaired_path)
  let secret = pdf_async_io_secret_object_for_test(
    "async classic xref offset secret",
  )
  let doc = try! @pdflite.pdf_minimum_valid_pdf()
  doc.add_object_given_number(30, secret)
  let user = @ascii.encode("user")
  let owner = @ascii.encode("owner")
  let denied : Array[@pdflite.PdfPermission] = [PdfNoCopy]
  pdf_write_encrypted_aesv2_document_to_file_with_iv_provider(
    doc,
    encrypted_path,
    user,
    owner,
    denied,
    @pdflite.pdf_deterministic_aes_iv_provider_from_seed(
      @ascii.encode("async classic xref offset iv"),
    ),
    encrypt_metadata=false,
    file_id=@ascii.encode("async-classic-xref-offset-id"),
  )
  @test.assert_eq(
    pdf_async_io_find_bytes_for_test(
      @fs.read_file(encrypted_path).binary(),
      @ascii.encode("async classic xref offset secret"),
    ) <
    0,
    true,
  )
  let malformed = pdf_async_io_corrupt_first_in_use_xref_offset_for_test(
    @fs.read_file(encrypted_path).binary(),
  )
  @fs.write_file(malformed_path, malformed, create=0o644)
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    @fs.read_file(malformed_path).binary(),
  )
  guard strict is Err(_) else {
    fail("expected malformed classic xref offset to require reconstruction")
  }
  let recovered = pdf_async_io_decryption_result_for_test(
    pdf_read_document_from_file_with_passwords(
      malformed_path,
      owner_password=Some(owner),
    ),
  )
  @test.assert_eq(recovered.document.first_xref(), 0)
  @test.assert_eq(recovered.denied_permissions, denied)
  @test.assert_eq(try! recovered.document.endpage(), 1)
  @test.assert_eq(recovered.document.lookup_object_or_null(30), secret)
  let added_secret = pdf_async_io_secret_object_for_test(
    "async classic xref offset repaired",
  )
  recovered.document.add_object_given_number(31, added_secret)
  let recrypted = try! recovered.document.recrypt_with_password_aesv2_with_iv_provider(
    owner,
    @pdflite.pdf_deterministic_aes_iv_provider_from_seed(
      @ascii.encode("async classic xref offset repair iv"),
    ),
  )
  pdf_write_document_to_file_with_compressed_xref_stream(
    recrypted, repaired_path,
  )
  @test.assert_eq(
    pdf_async_io_find_bytes_for_test(
      @fs.read_file(repaired_path).binary(),
      @ascii.encode("async classic xref offset secret"),
    ) <
    0,
    true,
  )
  let roundtrip = pdf_async_io_decryption_result_for_test(
    pdf_read_document_from_file_with_passwords(
      repaired_path,
      user_password=Some(user),
    ),
  )
  pdf_async_io_remove_if_exists_for_test(encrypted_path)
  pdf_async_io_remove_if_exists_for_test(malformed_path)
  pdf_async_io_remove_if_exists_for_test(repaired_path)
  @test.assert_eq(roundtrip.denied_permissions, denied)
  @test.assert_eq(try! roundtrip.document.endpage(), 1)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(30), secret)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(31), added_secret)
}

///|
async test "async file wrappers reconstruct encrypted malformed classic xref markers" {
  let encrypted_path = pdf_async_io_test_path_for_test(
    "encrypted_bad_classic_xref_marker",
  )
  let malformed_path = pdf_async_io_test_path_for_test(
    "encrypted_bad_classic_xref_marker_malformed",
  )
  let repaired_path = pdf_async_io_test_path_for_test(
    "encrypted_bad_classic_xref_marker_repaired",
  )
  pdf_async_io_remove_if_exists_for_test(encrypted_path)
  pdf_async_io_remove_if_exists_for_test(malformed_path)
  pdf_async_io_remove_if_exists_for_test(repaired_path)
  let secret = pdf_async_io_secret_object_for_test(
    "async classic xref marker secret",
  )
  let doc = try! @pdflite.pdf_minimum_valid_pdf()
  doc.add_object_given_number(30, secret)
  let user = @ascii.encode("user")
  let owner = @ascii.encode("owner")
  let denied : Array[@pdflite.PdfPermission] = [PdfNoCopy]
  pdf_write_encrypted_aesv2_document_to_file_with_iv_provider(
    doc,
    encrypted_path,
    user,
    owner,
    denied,
    @pdflite.pdf_deterministic_aes_iv_provider_from_seed(
      @ascii.encode("async classic xref marker iv"),
    ),
    encrypt_metadata=false,
    file_id=@ascii.encode("async-classic-xref-marker-id"),
  )
  @test.assert_eq(
    pdf_async_io_find_bytes_for_test(
      @fs.read_file(encrypted_path).binary(),
      @ascii.encode("async classic xref marker secret"),
    ) <
    0,
    true,
  )
  let malformed = pdf_async_io_corrupt_first_in_use_xref_marker_for_test(
    @fs.read_file(encrypted_path).binary(),
  )
  @fs.write_file(malformed_path, malformed, create=0o644)
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    @fs.read_file(malformed_path).binary(),
  )
  guard strict is Err(@pdflite.PdfError::XRefEntryExpected) else {
    fail("expected malformed classic xref marker to require reconstruction")
  }
  let recovered = pdf_async_io_decryption_result_for_test(
    pdf_read_document_from_file_with_passwords(
      malformed_path,
      owner_password=Some(owner),
    ),
  )
  @test.assert_eq(recovered.document.first_xref(), 0)
  @test.assert_eq(recovered.denied_permissions, denied)
  @test.assert_eq(try! recovered.document.endpage(), 1)
  @test.assert_eq(recovered.document.lookup_object_or_null(30), secret)
  let added_secret = pdf_async_io_secret_object_for_test(
    "async classic xref marker repaired",
  )
  recovered.document.add_object_given_number(31, added_secret)
  let recrypted = try! recovered.document.recrypt_with_password_aesv2_with_iv_provider(
    owner,
    @pdflite.pdf_deterministic_aes_iv_provider_from_seed(
      @ascii.encode("async classic xref marker repair iv"),
    ),
  )
  pdf_write_document_to_file_with_compressed_xref_stream(
    recrypted, repaired_path,
  )
  @test.assert_eq(
    pdf_async_io_find_bytes_for_test(
      @fs.read_file(repaired_path).binary(),
      @ascii.encode("async classic xref marker secret"),
    ) <
    0,
    true,
  )
  let roundtrip = pdf_async_io_decryption_result_for_test(
    pdf_read_document_from_file_with_passwords(
      repaired_path,
      user_password=Some(user),
    ),
  )
  pdf_async_io_remove_if_exists_for_test(encrypted_path)
  pdf_async_io_remove_if_exists_for_test(malformed_path)
  pdf_async_io_remove_if_exists_for_test(repaired_path)
  @test.assert_eq(roundtrip.denied_permissions, denied)
  @test.assert_eq(try! roundtrip.document.endpage(), 1)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(30), secret)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(31), added_secret)
}

///|
async test "async file wrappers reconstruct encrypted malformed classic xref subsections" {
  let encrypted_path = pdf_async_io_test_path_for_test(
    "encrypted_bad_classic_xref_subsection",
  )
  let malformed_path = pdf_async_io_test_path_for_test(
    "encrypted_bad_classic_xref_subsection_malformed",
  )
  let repaired_path = pdf_async_io_test_path_for_test(
    "encrypted_bad_classic_xref_subsection_repaired",
  )
  pdf_async_io_remove_if_exists_for_test(encrypted_path)
  pdf_async_io_remove_if_exists_for_test(malformed_path)
  pdf_async_io_remove_if_exists_for_test(repaired_path)
  let secret = pdf_async_io_secret_object_for_test(
    "async classic xref subsection secret",
  )
  let doc = try! @pdflite.pdf_minimum_valid_pdf()
  doc.add_object_given_number(30, secret)
  let user = @ascii.encode("user")
  let owner = @ascii.encode("owner")
  let denied : Array[@pdflite.PdfPermission] = [PdfNoCopy]
  pdf_write_encrypted_aesv2_document_to_file_with_iv_provider(
    doc,
    encrypted_path,
    user,
    owner,
    denied,
    @pdflite.pdf_deterministic_aes_iv_provider_from_seed(
      @ascii.encode("async classic xref subsection iv"),
    ),
    encrypt_metadata=false,
    file_id=@ascii.encode("async-classic-xref-subsection-id"),
  )
  @test.assert_eq(
    pdf_async_io_find_bytes_for_test(
      @fs.read_file(encrypted_path).binary(),
      @ascii.encode("async classic xref subsection secret"),
    ) <
    0,
    true,
  )
  let malformed = pdf_async_io_corrupt_first_xref_subsection_count_for_test(
    @fs.read_file(encrypted_path).binary(),
  )
  @fs.write_file(malformed_path, malformed, create=0o644)
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    @fs.read_file(malformed_path).binary(),
  )
  guard strict is Err(@pdflite.PdfError::NumberExpected) else {
    fail("expected malformed classic xref subsection to require reconstruction")
  }
  let recovered = pdf_async_io_decryption_result_for_test(
    pdf_read_document_from_file_with_passwords(
      malformed_path,
      owner_password=Some(owner),
    ),
  )
  @test.assert_eq(recovered.document.first_xref(), 0)
  @test.assert_eq(recovered.denied_permissions, denied)
  @test.assert_eq(try! recovered.document.endpage(), 1)
  @test.assert_eq(recovered.document.lookup_object_or_null(30), secret)
  let added_secret = pdf_async_io_secret_object_for_test(
    "async classic xref subsection repaired",
  )
  recovered.document.add_object_given_number(31, added_secret)
  let recrypted = try! recovered.document.recrypt_with_password_aesv2_with_iv_provider(
    owner,
    @pdflite.pdf_deterministic_aes_iv_provider_from_seed(
      @ascii.encode("async classic xref subsection repair iv"),
    ),
  )
  pdf_write_document_to_file_with_compressed_xref_stream(
    recrypted, repaired_path,
  )
  @test.assert_eq(
    pdf_async_io_find_bytes_for_test(
      @fs.read_file(repaired_path).binary(),
      @ascii.encode("async classic xref subsection secret"),
    ) <
    0,
    true,
  )
  let roundtrip = pdf_async_io_decryption_result_for_test(
    pdf_read_document_from_file_with_passwords(
      repaired_path,
      user_password=Some(user),
    ),
  )
  pdf_async_io_remove_if_exists_for_test(encrypted_path)
  pdf_async_io_remove_if_exists_for_test(malformed_path)
  pdf_async_io_remove_if_exists_for_test(repaired_path)
  @test.assert_eq(roundtrip.denied_permissions, denied)
  @test.assert_eq(try! roundtrip.document.endpage(), 1)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(30), secret)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(31), added_secret)
}

///|
async test "async file wrappers reconstruct encrypted malformed classic trailers" {
  let encrypted_path = pdf_async_io_test_path_for_test(
    "encrypted_bad_classic_trailer",
  )
  let malformed_path = pdf_async_io_test_path_for_test(
    "encrypted_bad_classic_trailer_malformed",
  )
  let repaired_path = pdf_async_io_test_path_for_test(
    "encrypted_bad_classic_trailer_repaired",
  )
  pdf_async_io_remove_if_exists_for_test(encrypted_path)
  pdf_async_io_remove_if_exists_for_test(malformed_path)
  pdf_async_io_remove_if_exists_for_test(repaired_path)
  let secret = pdf_async_io_secret_object_for_test(
    "async classic trailer secret",
  )
  let doc = try! @pdflite.pdf_minimum_valid_pdf()
  doc.add_object_given_number(30, secret)
  let user = @ascii.encode("user")
  let owner = @ascii.encode("owner")
  let denied : Array[@pdflite.PdfPermission] = [PdfNoCopy]
  pdf_write_encrypted_aesv2_document_to_file_with_iv_provider(
    doc,
    encrypted_path,
    user,
    owner,
    denied,
    @pdflite.pdf_deterministic_aes_iv_provider_from_seed(
      @ascii.encode("async classic trailer iv"),
    ),
    encrypt_metadata=false,
    file_id=@ascii.encode("async-classic-trailer-id"),
  )
  @test.assert_eq(
    pdf_async_io_find_bytes_for_test(
      @fs.read_file(encrypted_path).binary(),
      @ascii.encode("async classic trailer secret"),
    ) <
    0,
    true,
  )
  let malformed = pdf_async_io_insert_ascii_before_last_marker_for_test(
    @fs.read_file(encrypted_path).binary(),
    @ascii.encode("trailer\n"),
    "trailer\n1\n",
  )
  @fs.write_file(malformed_path, malformed, create=0o644)
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    @fs.read_file(malformed_path).binary(),
  )
  guard strict is Err(@pdflite.PdfError::TrailerExpected) else {
    fail("expected malformed classic trailer to require reconstruction")
  }
  let recovered = pdf_async_io_decryption_result_for_test(
    pdf_read_document_from_file_with_passwords(
      malformed_path,
      owner_password=Some(owner),
    ),
  )
  @test.assert_eq(recovered.document.first_xref(), 0)
  @test.assert_eq(recovered.denied_permissions, denied)
  @test.assert_eq(try! recovered.document.endpage(), 1)
  @test.assert_eq(recovered.document.lookup_object_or_null(30), secret)
  let added_secret = pdf_async_io_secret_object_for_test(
    "async classic trailer repaired",
  )
  recovered.document.add_object_given_number(31, added_secret)
  let recrypted = try! recovered.document.recrypt_with_password_aesv2_with_iv_provider(
    owner,
    @pdflite.pdf_deterministic_aes_iv_provider_from_seed(
      @ascii.encode("async classic trailer repair iv"),
    ),
  )
  pdf_write_document_to_file_with_compressed_xref_stream(
    recrypted, repaired_path,
  )
  @test.assert_eq(
    pdf_async_io_find_bytes_for_test(
      @fs.read_file(repaired_path).binary(),
      @ascii.encode("async classic trailer secret"),
    ) <
    0,
    true,
  )
  let roundtrip = pdf_async_io_decryption_result_for_test(
    pdf_read_document_from_file_with_passwords(
      repaired_path,
      user_password=Some(user),
    ),
  )
  pdf_async_io_remove_if_exists_for_test(encrypted_path)
  pdf_async_io_remove_if_exists_for_test(malformed_path)
  pdf_async_io_remove_if_exists_for_test(repaired_path)
  @test.assert_eq(roundtrip.denied_permissions, denied)
  @test.assert_eq(try! roundtrip.document.endpage(), 1)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(30), secret)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(31), added_secret)
}

///|
async test "async file wrappers reconstruct encrypted missing-root classic trailers" {
  let encrypted_path = pdf_async_io_test_path_for_test(
    "encrypted_missing_root_classic_trailer",
  )
  let malformed_path = pdf_async_io_test_path_for_test(
    "encrypted_missing_root_classic_trailer_malformed",
  )
  let repaired_path = pdf_async_io_test_path_for_test(
    "encrypted_missing_root_classic_trailer_repaired",
  )
  pdf_async_io_remove_if_exists_for_test(encrypted_path)
  pdf_async_io_remove_if_exists_for_test(malformed_path)
  pdf_async_io_remove_if_exists_for_test(repaired_path)
  let secret = pdf_async_io_secret_object_for_test(
    "async missing-root trailer secret",
  )
  let doc = try! @pdflite.pdf_minimum_valid_pdf()
  doc.add_object_given_number(30, secret)
  let user = @ascii.encode("user")
  let owner = @ascii.encode("owner")
  let denied : Array[@pdflite.PdfPermission] = [PdfNoCopy]
  pdf_write_encrypted_aesv2_document_to_file_with_iv_provider(
    doc,
    encrypted_path,
    user,
    owner,
    denied,
    @pdflite.pdf_deterministic_aes_iv_provider_from_seed(
      @ascii.encode("async missing-root trailer iv"),
    ),
    encrypt_metadata=false,
    file_id=@ascii.encode("async-missing-root-trailer-id"),
  )
  @test.assert_eq(
    pdf_async_io_find_bytes_for_test(
      @fs.read_file(encrypted_path).binary(),
      @ascii.encode("async missing-root trailer secret"),
    ) <
    0,
    true,
  )
  let malformed = pdf_async_io_insert_ascii_before_last_marker_for_test(
    @fs.read_file(encrypted_path).binary(),
    @ascii.encode("trailer\n"),
    "trailer\n<< /Size 999 >>\n",
  )
  @fs.write_file(malformed_path, malformed, create=0o644)
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    @fs.read_file(malformed_path).binary(),
  )
  guard strict is Err(@pdflite.PdfError::RootExpected) else {
    fail("expected missing-root classic trailer to require reconstruction")
  }
  let recovered = pdf_async_io_decryption_result_for_test(
    pdf_read_document_from_file_with_passwords(
      malformed_path,
      owner_password=Some(owner),
    ),
  )
  @test.assert_eq(recovered.document.first_xref(), 0)
  @test.assert_eq(recovered.denied_permissions, denied)
  @test.assert_eq(try! recovered.document.endpage(), 1)
  @test.assert_eq(recovered.document.lookup_object_or_null(30), secret)
  let added_secret = pdf_async_io_secret_object_for_test(
    "async missing-root trailer repaired",
  )
  recovered.document.add_object_given_number(31, added_secret)
  let recrypted = try! recovered.document.recrypt_with_password_aesv2_with_iv_provider(
    owner,
    @pdflite.pdf_deterministic_aes_iv_provider_from_seed(
      @ascii.encode("async missing-root trailer repair iv"),
    ),
  )
  pdf_write_document_to_file_with_compressed_xref_stream(
    recrypted, repaired_path,
  )
  @test.assert_eq(
    pdf_async_io_find_bytes_for_test(
      @fs.read_file(repaired_path).binary(),
      @ascii.encode("async missing-root trailer secret"),
    ) <
    0,
    true,
  )
  let roundtrip = pdf_async_io_decryption_result_for_test(
    pdf_read_document_from_file_with_passwords(
      repaired_path,
      user_password=Some(user),
    ),
  )
  pdf_async_io_remove_if_exists_for_test(encrypted_path)
  pdf_async_io_remove_if_exists_for_test(malformed_path)
  pdf_async_io_remove_if_exists_for_test(repaired_path)
  @test.assert_eq(roundtrip.denied_permissions, denied)
  @test.assert_eq(try! roundtrip.document.endpage(), 1)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(30), secret)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(31), added_secret)
}

///|
async test "async file wrappers reconstruct encrypted catalogs missing from classic xref" {
  let encrypted_path = pdf_async_io_test_path_for_test(
    "encrypted_catalog_missing_classic_xref",
  )
  let malformed_path = pdf_async_io_test_path_for_test(
    "encrypted_catalog_missing_classic_xref_malformed",
  )
  let repaired_path = pdf_async_io_test_path_for_test(
    "encrypted_catalog_missing_classic_xref_repaired",
  )
  pdf_async_io_remove_if_exists_for_test(encrypted_path)
  pdf_async_io_remove_if_exists_for_test(malformed_path)
  pdf_async_io_remove_if_exists_for_test(repaired_path)
  let secret = pdf_async_io_secret_object_for_test(
    "async catalog missing xref secret",
  )
  let doc = try! @pdflite.pdf_minimum_valid_pdf()
  let root_number = doc.root()
  doc.add_object_given_number(30, secret)
  let user = @ascii.encode("user")
  let owner = @ascii.encode("owner")
  let denied : Array[@pdflite.PdfPermission] = [PdfNoCopy]
  pdf_write_encrypted_aesv2_document_to_file_with_iv_provider(
    doc,
    encrypted_path,
    user,
    owner,
    denied,
    @pdflite.pdf_deterministic_aes_iv_provider_from_seed(
      @ascii.encode("async catalog missing xref iv"),
    ),
    encrypt_metadata=false,
    file_id=@ascii.encode("async-catalog-missing-xref-id"),
  )
  @test.assert_eq(
    pdf_async_io_find_bytes_for_test(
      @fs.read_file(encrypted_path).binary(),
      @ascii.encode("async catalog missing xref secret"),
    ) <
    0,
    true,
  )
  let malformed = pdf_async_io_mark_classic_xref_entry_free_for_test(
    @fs.read_file(encrypted_path).binary(),
    root_number,
  )
  @fs.write_file(malformed_path, malformed, create=0o644)
  let strict = @pdflite.pdf_read_classic_document_from_bytes(
    @fs.read_file(malformed_path).binary(),
  )
  @test.assert_eq(strict.root(), root_number)
  let strict_catalog : Result[@pdflite.PdfObject, Error] = try? strict.catalog()
  guard strict_catalog is Err(@pdflite.PdfError::RootExpected) else {
    fail("expected missing root object to require reconstruction")
  }
  @test.assert_eq(
    pdf_read_document_from_file_with_passwords(
      malformed_path,
      user_password=Some(@ascii.encode("bad-user")),
    ),
    None,
  )
  let recovered = pdf_async_io_decryption_result_for_test(
    pdf_read_document_from_file_with_passwords(
      malformed_path,
      owner_password=Some(owner),
    ),
  )
  @test.assert_eq(recovered.document.first_xref(), 0)
  @test.assert_eq(recovered.denied_permissions, denied)
  @test.assert_eq(try! recovered.document.endpage(), 1)
  @test.assert_eq(recovered.document.lookup_object_or_null(30), secret)
  let added_secret = pdf_async_io_secret_object_for_test(
    "async catalog missing xref repaired",
  )
  recovered.document.add_object_given_number(31, added_secret)
  let recrypted = try! recovered.document.recrypt_with_password_aesv2_with_iv_provider(
    owner,
    @pdflite.pdf_deterministic_aes_iv_provider_from_seed(
      @ascii.encode("async catalog missing xref repair iv"),
    ),
  )
  pdf_write_document_to_file_with_compressed_xref_stream(
    recrypted, repaired_path,
  )
  @test.assert_eq(
    pdf_async_io_find_bytes_for_test(
      @fs.read_file(repaired_path).binary(),
      @ascii.encode("async catalog missing xref secret"),
    ) <
    0,
    true,
  )
  let roundtrip = pdf_async_io_decryption_result_for_test(
    pdf_read_document_from_file_with_passwords(
      repaired_path,
      user_password=Some(user),
    ),
  )
  pdf_async_io_remove_if_exists_for_test(encrypted_path)
  pdf_async_io_remove_if_exists_for_test(malformed_path)
  pdf_async_io_remove_if_exists_for_test(repaired_path)
  @test.assert_eq(roundtrip.denied_permissions, denied)
  @test.assert_eq(try! roundtrip.document.endpage(), 1)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(30), secret)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(31), added_secret)
}

///|
async test "async file wrappers reconstruct encrypted page trees missing from classic xref" {
  let encrypted_path = pdf_async_io_test_path_for_test(
    "encrypted_page_tree_missing_classic_xref",
  )
  let malformed_path = pdf_async_io_test_path_for_test(
    "encrypted_page_tree_missing_classic_xref_malformed",
  )
  let repaired_path = pdf_async_io_test_path_for_test(
    "encrypted_page_tree_missing_classic_xref_repaired",
  )
  pdf_async_io_remove_if_exists_for_test(encrypted_path)
  pdf_async_io_remove_if_exists_for_test(malformed_path)
  pdf_async_io_remove_if_exists_for_test(repaired_path)
  let doc = @pdflite.pdf_document_empty()
  doc.set_version(1, 4)
  doc.set_root(1)
  doc.set_trailer_dict(
    PdfDictionary([(pdf_async_io_name_for_test("/Root"), PdfIndirect(1))]),
  )
  doc.add_object_given_number(
    1,
    PdfDictionary([
      (
        pdf_async_io_name_for_test("/Type"),
        PdfNameObject(pdf_async_io_name_for_test("/Catalog")),
      ),
      (pdf_async_io_name_for_test("/Pages"), PdfIndirect(2)),
    ]),
  )
  doc.add_object_given_number(
    2,
    PdfDictionary([
      (
        pdf_async_io_name_for_test("/Type"),
        PdfNameObject(pdf_async_io_name_for_test("/Pages")),
      ),
      (pdf_async_io_name_for_test("/Kids"), PdfArray([PdfIndirect(3)])),
      (pdf_async_io_name_for_test("/Count"), PdfInteger(1)),
    ]),
  )
  doc.add_object_given_number(
    3,
    PdfDictionary([
      (
        pdf_async_io_name_for_test("/Type"),
        PdfNameObject(pdf_async_io_name_for_test("/Page")),
      ),
      (pdf_async_io_name_for_test("/Parent"), PdfIndirect(2)),
      (
        pdf_async_io_name_for_test("/MediaBox"),
        PdfArray([PdfInteger(0), PdfInteger(0), PdfInteger(10), PdfInteger(10)]),
      ),
    ]),
  )
  let secret = pdf_async_io_secret_object_for_test(
    "async page-tree missing xref secret",
  )
  doc.add_object_given_number(60, secret)
  let user = @ascii.encode("user")
  let owner = @ascii.encode("owner")
  let denied : Array[@pdflite.PdfPermission] = [PdfNoCopy]
  let encrypted = try! doc.encrypt_128bit_aesv2_with_iv_provider(
    user,
    owner,
    denied,
    @pdflite.pdf_deterministic_aes_iv_provider_from_seed(
      @ascii.encode("async page-tree missing xref iv"),
    ),
    encrypt_metadata=false,
    file_id=@ascii.encode("async-page-tree-missing-xref-id"),
  )
  let encrypt_object_number = match
    encrypted
    .trailer_dict()
    .lookup_immediate(pdf_async_io_name_for_test("/Encrypt")) {
    Some(PdfIndirect(number)) => number
    _ => fail("expected encryption object reference")
  }
  pdf_write_document_to_file(encrypted, encrypted_path)
  @test.assert_eq(
    pdf_async_io_find_bytes_for_test(
      @fs.read_file(encrypted_path).binary(),
      @ascii.encode("async page-tree missing xref secret"),
    ) <
    0,
    true,
  )
  let malformed = pdf_async_io_keep_catalog_and_encrypt_xref_entries_for_test(
    @fs.read_file(encrypted_path).binary(),
    encrypt_object_number,
  )
  @fs.write_file(malformed_path, malformed, create=0o644)
  let strict = @pdflite.pdf_read_classic_document_from_bytes(
    @fs.read_file(malformed_path).binary(),
  )
  @test.assert_eq(strict.root(), 1)
  @test.assert_eq(strict.object_numbers(), [1, encrypt_object_number])
  let strict_pages : Result[Int, Error] = try? strict.endpage()
  guard strict_pages is Err(@pdflite.PdfError::PageTreeExpected) else {
    fail("expected missing page tree to require reconstruction")
  }
  @test.assert_eq(
    pdf_read_document_from_file_with_passwords(
      malformed_path,
      user_password=Some(@ascii.encode("bad-user")),
    ),
    None,
  )
  let recovered = pdf_async_io_decryption_result_for_test(
    pdf_read_document_from_file_with_passwords(
      malformed_path,
      owner_password=Some(owner),
    ),
  )
  @test.assert_eq(recovered.document.first_xref(), 0)
  @test.assert_eq(recovered.denied_permissions, denied)
  @test.assert_eq(recovered.document.root(), 1)
  @test.assert_eq(try! recovered.document.endpage(), 1)
  @test.assert_eq(recovered.document.lookup_object_or_null(60), secret)
  let added_secret = pdf_async_io_secret_object_for_test(
    "async page-tree missing xref repaired",
  )
  recovered.document.add_object_given_number(61, added_secret)
  let recrypted = try! recovered.document.recrypt_with_password_aesv2_with_iv_provider(
    owner,
    @pdflite.pdf_deterministic_aes_iv_provider_from_seed(
      @ascii.encode("async page-tree missing xref repair iv"),
    ),
  )
  pdf_write_document_to_file_with_compressed_xref_stream(
    recrypted, repaired_path,
  )
  @test.assert_eq(
    pdf_async_io_find_bytes_for_test(
      @fs.read_file(repaired_path).binary(),
      @ascii.encode("async page-tree missing xref secret"),
    ) <
    0,
    true,
  )
  let roundtrip = pdf_async_io_decryption_result_for_test(
    pdf_read_document_from_file_with_passwords(
      repaired_path,
      user_password=Some(user),
    ),
  )
  pdf_async_io_remove_if_exists_for_test(encrypted_path)
  pdf_async_io_remove_if_exists_for_test(malformed_path)
  pdf_async_io_remove_if_exists_for_test(repaired_path)
  @test.assert_eq(roundtrip.denied_permissions, denied)
  @test.assert_eq(roundtrip.document.root(), 1)
  @test.assert_eq(try! roundtrip.document.endpage(), 1)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(60), secret)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(61), added_secret)
}

///|
async test "async file wrappers reconstruct encrypted malformed xref-stream metadata" {
  let encrypted_path = pdf_async_io_test_path_for_test(
    "encrypted_bad_xref_stream_metadata",
  )
  let malformed_path = pdf_async_io_test_path_for_test(
    "encrypted_bad_xref_stream_metadata_malformed",
  )
  let repaired_path = pdf_async_io_test_path_for_test(
    "encrypted_bad_xref_stream_metadata_repaired",
  )
  pdf_async_io_remove_if_exists_for_test(encrypted_path)
  pdf_async_io_remove_if_exists_for_test(malformed_path)
  pdf_async_io_remove_if_exists_for_test(repaired_path)
  let secret = pdf_async_io_secret_object_for_test(
    "async xref-stream metadata secret",
  )
  let doc = try! @pdflite.pdf_minimum_valid_pdf()
  doc.add_object_given_number(30, secret)
  let user = @ascii.encode("user")
  let owner = @ascii.encode("owner")
  let denied : Array[@pdflite.PdfPermission] = [PdfNoCopy]
  pdf_write_encrypted_aesv2_document_to_file_with_iv_provider(
    doc,
    encrypted_path,
    user,
    owner,
    denied,
    @pdflite.pdf_deterministic_aes_iv_provider_from_seed(
      @ascii.encode("async xref-stream metadata iv"),
    ),
    encrypt_metadata=false,
    mode=PdfWriteCompressedXRefStream,
    file_id=@ascii.encode("async-bad-xref-stream-metadata-id"),
  )
  let malformed = pdf_async_io_insert_ascii_before_last_marker_for_test(
    @fs.read_file(encrypted_path).binary(),
    @ascii.encode("/W ["),
    "/Index [0] ",
  )
  @fs.write_file(malformed_path, malformed, create=0o644)
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    @fs.read_file(malformed_path).binary(),
  )
  guard strict is Err(@pdflite.PdfError::XRefEntryExpected) else {
    fail("expected malformed xref stream metadata to require reconstruction")
  }
  let recovered = pdf_async_io_decryption_result_for_test(
    pdf_read_document_from_file_with_passwords(
      malformed_path,
      owner_password=Some(owner),
    ),
  )
  @test.assert_eq(recovered.document.first_xref(), 0)
  @test.assert_eq(recovered.denied_permissions, denied)
  @test.assert_eq(recovered.document.lookup_object_or_null(30), secret)
  let added_secret = pdf_async_io_secret_object_for_test(
    "async xref-stream metadata repaired",
  )
  recovered.document.add_object_given_number(31, added_secret)
  let recrypted = try! recovered.document.recrypt_with_password_aesv2_with_iv_provider(
    owner,
    @pdflite.pdf_deterministic_aes_iv_provider_from_seed(
      @ascii.encode("async xref-stream metadata repair iv"),
    ),
  )
  pdf_write_document_to_file_with_compressed_xref_stream(
    recrypted, repaired_path,
  )
  @test.assert_eq(
    pdf_async_io_find_bytes_for_test(
      @fs.read_file(repaired_path).binary(),
      @ascii.encode("async xref-stream metadata secret"),
    ) <
    0,
    true,
  )
  let roundtrip = pdf_async_io_decryption_result_for_test(
    pdf_read_document_from_file_with_passwords(
      repaired_path,
      user_password=Some(user),
    ),
  )
  pdf_async_io_remove_if_exists_for_test(encrypted_path)
  pdf_async_io_remove_if_exists_for_test(malformed_path)
  pdf_async_io_remove_if_exists_for_test(repaired_path)
  @test.assert_eq(roundtrip.denied_permissions, denied)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(30), secret)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(31), added_secret)
}

///|
async test "async file wrappers reconstruct encrypted malformed xref-stream widths" {
  let encrypted_path = pdf_async_io_test_path_for_test(
    "encrypted_bad_xref_stream_widths",
  )
  let malformed_path = pdf_async_io_test_path_for_test(
    "encrypted_bad_xref_stream_widths_malformed",
  )
  let repaired_path = pdf_async_io_test_path_for_test(
    "encrypted_bad_xref_stream_widths_repaired",
  )
  pdf_async_io_remove_if_exists_for_test(encrypted_path)
  pdf_async_io_remove_if_exists_for_test(malformed_path)
  pdf_async_io_remove_if_exists_for_test(repaired_path)
  let secret = pdf_async_io_secret_object_for_test(
    "async xref-stream widths secret",
  )
  let doc = try! @pdflite.pdf_minimum_valid_pdf()
  doc.add_object_given_number(30, secret)
  let user = @ascii.encode("user")
  let owner = @ascii.encode("owner")
  let denied : Array[@pdflite.PdfPermission] = [PdfNoCopy]
  pdf_write_encrypted_aesv2_document_to_file_with_iv_provider(
    doc,
    encrypted_path,
    user,
    owner,
    denied,
    @pdflite.pdf_deterministic_aes_iv_provider_from_seed(
      @ascii.encode("async xref-stream widths iv"),
    ),
    encrypt_metadata=false,
    mode=PdfWriteCompressedXRefStream,
    file_id=@ascii.encode("async-bad-xref-stream-widths-id"),
  )
  let malformed = pdf_async_io_insert_ascii_before_last_marker_for_test(
    @fs.read_file(encrypted_path).binary(),
    @ascii.encode("/W ["),
    "/W [1 4] ",
  )
  @fs.write_file(malformed_path, malformed, create=0o644)
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    @fs.read_file(malformed_path).binary(),
  )
  guard strict is Err(@pdflite.PdfError::XRefEntryExpected) else {
    fail("expected malformed xref stream widths to require reconstruction")
  }
  let recovered = pdf_async_io_decryption_result_for_test(
    pdf_read_document_from_file_with_passwords(
      malformed_path,
      owner_password=Some(owner),
    ),
  )
  @test.assert_eq(recovered.document.first_xref(), 0)
  @test.assert_eq(recovered.denied_permissions, denied)
  @test.assert_eq(recovered.document.lookup_object_or_null(30), secret)
  let added_secret = pdf_async_io_secret_object_for_test(
    "async xref-stream widths repaired",
  )
  recovered.document.add_object_given_number(31, added_secret)
  let recrypted = try! recovered.document.recrypt_with_password_aesv2_with_iv_provider(
    owner,
    @pdflite.pdf_deterministic_aes_iv_provider_from_seed(
      @ascii.encode("async xref-stream widths repair iv"),
    ),
  )
  pdf_write_document_to_file_with_compressed_xref_stream(
    recrypted, repaired_path,
  )
  @test.assert_eq(
    pdf_async_io_find_bytes_for_test(
      @fs.read_file(repaired_path).binary(),
      @ascii.encode("async xref-stream widths secret"),
    ) <
    0,
    true,
  )
  let roundtrip = pdf_async_io_decryption_result_for_test(
    pdf_read_document_from_file_with_passwords(
      repaired_path,
      user_password=Some(user),
    ),
  )
  pdf_async_io_remove_if_exists_for_test(encrypted_path)
  pdf_async_io_remove_if_exists_for_test(malformed_path)
  pdf_async_io_remove_if_exists_for_test(repaired_path)
  @test.assert_eq(roundtrip.denied_permissions, denied)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(30), secret)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(31), added_secret)
}

///|
async test "async file wrappers reconstruct encrypted malformed xref-stream size" {
  let encrypted_path = pdf_async_io_test_path_for_test(
    "encrypted_bad_xref_stream_size",
  )
  let malformed_path = pdf_async_io_test_path_for_test(
    "encrypted_bad_xref_stream_size_malformed",
  )
  let repaired_path = pdf_async_io_test_path_for_test(
    "encrypted_bad_xref_stream_size_repaired",
  )
  pdf_async_io_remove_if_exists_for_test(encrypted_path)
  pdf_async_io_remove_if_exists_for_test(malformed_path)
  pdf_async_io_remove_if_exists_for_test(repaired_path)
  let secret = pdf_async_io_secret_object_for_test(
    "async xref-stream size secret",
  )
  let doc = try! @pdflite.pdf_minimum_valid_pdf()
  doc.add_object_given_number(30, secret)
  let user = @ascii.encode("user")
  let owner = @ascii.encode("owner")
  let denied : Array[@pdflite.PdfPermission] = [PdfNoCopy]
  pdf_write_encrypted_aesv2_document_to_file_with_iv_provider(
    doc,
    encrypted_path,
    user,
    owner,
    denied,
    @pdflite.pdf_deterministic_aes_iv_provider_from_seed(
      @ascii.encode("async xref-stream size iv"),
    ),
    encrypt_metadata=false,
    mode=PdfWriteCompressedXRefStream,
    file_id=@ascii.encode("async-bad-xref-stream-size-id"),
  )
  let malformed = pdf_async_io_insert_ascii_before_last_marker_for_test(
    @fs.read_file(encrypted_path).binary(),
    @ascii.encode("/Size "),
    "/Size /Bad ",
  )
  @fs.write_file(malformed_path, malformed, create=0o644)
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    @fs.read_file(malformed_path).binary(),
  )
  guard strict is Err(@pdflite.PdfError::XRefEntryExpected) else {
    fail("expected malformed xref stream size to require reconstruction")
  }
  let recovered = pdf_async_io_decryption_result_for_test(
    pdf_read_document_from_file_with_passwords(
      malformed_path,
      owner_password=Some(owner),
    ),
  )
  @test.assert_eq(recovered.document.first_xref(), 0)
  @test.assert_eq(recovered.denied_permissions, denied)
  @test.assert_eq(recovered.document.lookup_object_or_null(30), secret)
  let added_secret = pdf_async_io_secret_object_for_test(
    "async xref-stream size repaired",
  )
  recovered.document.add_object_given_number(31, added_secret)
  let recrypted = try! recovered.document.recrypt_with_password_aesv2_with_iv_provider(
    owner,
    @pdflite.pdf_deterministic_aes_iv_provider_from_seed(
      @ascii.encode("async xref-stream size repair iv"),
    ),
  )
  pdf_write_document_to_file_with_compressed_xref_stream(
    recrypted, repaired_path,
  )
  @test.assert_eq(
    pdf_async_io_find_bytes_for_test(
      @fs.read_file(repaired_path).binary(),
      @ascii.encode("async xref-stream size secret"),
    ) <
    0,
    true,
  )
  let roundtrip = pdf_async_io_decryption_result_for_test(
    pdf_read_document_from_file_with_passwords(
      repaired_path,
      user_password=Some(user),
    ),
  )
  pdf_async_io_remove_if_exists_for_test(encrypted_path)
  pdf_async_io_remove_if_exists_for_test(malformed_path)
  pdf_async_io_remove_if_exists_for_test(repaired_path)
  @test.assert_eq(roundtrip.denied_permissions, denied)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(30), secret)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(31), added_secret)
}

///|
async test "async file wrappers reconstruct encrypted malformed xref-stream filters" {
  let encrypted_path = pdf_async_io_test_path_for_test(
    "encrypted_bad_xref_stream_filter",
  )
  let malformed_path = pdf_async_io_test_path_for_test(
    "encrypted_bad_xref_stream_filter_malformed",
  )
  let repaired_path = pdf_async_io_test_path_for_test(
    "encrypted_bad_xref_stream_filter_repaired",
  )
  pdf_async_io_remove_if_exists_for_test(encrypted_path)
  pdf_async_io_remove_if_exists_for_test(malformed_path)
  pdf_async_io_remove_if_exists_for_test(repaired_path)
  let secret = pdf_async_io_secret_object_for_test(
    "async xref-stream filter secret",
  )
  let doc = try! @pdflite.pdf_minimum_valid_pdf()
  doc.add_object_given_number(30, secret)
  let user = @ascii.encode("user")
  let owner = @ascii.encode("owner")
  let denied : Array[@pdflite.PdfPermission] = [PdfNoCopy]
  pdf_write_encrypted_aesv2_document_to_file_with_iv_provider(
    doc,
    encrypted_path,
    user,
    owner,
    denied,
    @pdflite.pdf_deterministic_aes_iv_provider_from_seed(
      @ascii.encode("async xref-stream filter iv"),
    ),
    encrypt_metadata=false,
    mode=PdfWriteCompressedXRefStream,
    file_id=@ascii.encode("async-bad-xref-stream-filter-id"),
  )
  let malformed = pdf_async_io_insert_ascii_before_last_marker_for_test(
    @fs.read_file(encrypted_path).binary(),
    @ascii.encode("/Filter "),
    "/Filter /BadXRefFilter ",
  )
  @fs.write_file(malformed_path, malformed, create=0o644)
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    @fs.read_file(malformed_path).binary(),
  )
  guard strict is Err(@pdflite.PdfError::FilterNotSupported(filter)) else {
    fail("expected malformed xref stream filter to require reconstruction")
  }
  @test.assert_eq(filter, pdf_async_io_name_for_test("/BadXRefFilter"))
  let recovered = pdf_async_io_decryption_result_for_test(
    pdf_read_document_from_file_with_passwords(
      malformed_path,
      owner_password=Some(owner),
    ),
  )
  @test.assert_eq(recovered.document.first_xref(), 0)
  @test.assert_eq(recovered.denied_permissions, denied)
  @test.assert_eq(recovered.document.lookup_object_or_null(30), secret)
  let added_secret = pdf_async_io_secret_object_for_test(
    "async xref-stream filter repaired",
  )
  recovered.document.add_object_given_number(31, added_secret)
  let recrypted = try! recovered.document.recrypt_with_password_aesv2_with_iv_provider(
    owner,
    @pdflite.pdf_deterministic_aes_iv_provider_from_seed(
      @ascii.encode("async xref-stream filter repair iv"),
    ),
  )
  pdf_write_document_to_file_with_compressed_xref_stream(
    recrypted, repaired_path,
  )
  @test.assert_eq(
    pdf_async_io_find_bytes_for_test(
      @fs.read_file(repaired_path).binary(),
      @ascii.encode("async xref-stream filter secret"),
    ) <
    0,
    true,
  )
  let roundtrip = pdf_async_io_decryption_result_for_test(
    pdf_read_document_from_file_with_passwords(
      repaired_path,
      user_password=Some(user),
    ),
  )
  pdf_async_io_remove_if_exists_for_test(encrypted_path)
  pdf_async_io_remove_if_exists_for_test(malformed_path)
  pdf_async_io_remove_if_exists_for_test(repaired_path)
  @test.assert_eq(roundtrip.denied_permissions, denied)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(30), secret)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(31), added_secret)
}

///|
async test "async file wrappers reconstruct encrypted malformed xref-stream decodeparms" {
  let encrypted_path = pdf_async_io_test_path_for_test(
    "encrypted_bad_xref_stream_decodeparms",
  )
  let malformed_path = pdf_async_io_test_path_for_test(
    "encrypted_bad_xref_stream_decodeparms_malformed",
  )
  let repaired_path = pdf_async_io_test_path_for_test(
    "encrypted_bad_xref_stream_decodeparms_repaired",
  )
  pdf_async_io_remove_if_exists_for_test(encrypted_path)
  pdf_async_io_remove_if_exists_for_test(malformed_path)
  pdf_async_io_remove_if_exists_for_test(repaired_path)
  let secret = pdf_async_io_secret_object_for_test(
    "async xref-stream decodeparms secret",
  )
  let doc = try! @pdflite.pdf_minimum_valid_pdf()
  doc.add_object_given_number(30, secret)
  let user = @ascii.encode("user")
  let owner = @ascii.encode("owner")
  let denied : Array[@pdflite.PdfPermission] = [PdfNoCopy]
  pdf_write_encrypted_aesv2_document_to_file_with_iv_provider(
    doc,
    encrypted_path,
    user,
    owner,
    denied,
    @pdflite.pdf_deterministic_aes_iv_provider_from_seed(
      @ascii.encode("async xref-stream decodeparms iv"),
    ),
    encrypt_metadata=false,
    mode=PdfWriteCompressedXRefStream,
    file_id=@ascii.encode("async-bad-xref-decodeparms-id"),
  )
  let malformed = pdf_async_io_insert_ascii_before_last_marker_for_test(
    @fs.read_file(encrypted_path).binary(),
    @ascii.encode("/Filter "),
    "/DecodeParms /Bad ",
  )
  @fs.write_file(malformed_path, malformed, create=0o644)
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    @fs.read_file(malformed_path).binary(),
  )
  guard strict is Err(@pdflite.PdfError::PredictorExpected) else {
    fail("expected malformed xref stream DecodeParms to require reconstruction")
  }
  let recovered = pdf_async_io_decryption_result_for_test(
    pdf_read_document_from_file_with_passwords(
      malformed_path,
      owner_password=Some(owner),
    ),
  )
  @test.assert_eq(recovered.document.first_xref(), 0)
  @test.assert_eq(recovered.denied_permissions, denied)
  @test.assert_eq(recovered.document.lookup_object_or_null(30), secret)
  let added_secret = pdf_async_io_secret_object_for_test(
    "async xref-stream decodeparms repaired",
  )
  recovered.document.add_object_given_number(31, added_secret)
  let recrypted = try! recovered.document.recrypt_with_password_aesv2_with_iv_provider(
    owner,
    @pdflite.pdf_deterministic_aes_iv_provider_from_seed(
      @ascii.encode("async xref-stream decodeparms repair iv"),
    ),
  )
  pdf_write_document_to_file_with_compressed_xref_stream(
    recrypted, repaired_path,
  )
  @test.assert_eq(
    pdf_async_io_find_bytes_for_test(
      @fs.read_file(repaired_path).binary(),
      @ascii.encode("async xref-stream decodeparms secret"),
    ) <
    0,
    true,
  )
  let roundtrip = pdf_async_io_decryption_result_for_test(
    pdf_read_document_from_file_with_passwords(
      repaired_path,
      user_password=Some(user),
    ),
  )
  pdf_async_io_remove_if_exists_for_test(encrypted_path)
  pdf_async_io_remove_if_exists_for_test(malformed_path)
  pdf_async_io_remove_if_exists_for_test(repaired_path)
  @test.assert_eq(roundtrip.denied_permissions, denied)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(30), secret)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(31), added_secret)
}

///|
async test "async file wrappers reconstruct compressed AESV3 encrypted documents with bad startxref" {
  let encrypted_path = pdf_async_io_test_path_for_test(
    "compressed_aesv3_bad_startxref",
  )
  let corrupted_path = pdf_async_io_test_path_for_test(
    "compressed_aesv3_bad_startxref_corrupted",
  )
  let repaired_path = pdf_async_io_test_path_for_test(
    "compressed_aesv3_bad_startxref_repaired",
  )
  pdf_async_io_remove_if_exists_for_test(encrypted_path)
  pdf_async_io_remove_if_exists_for_test(corrupted_path)
  pdf_async_io_remove_if_exists_for_test(repaired_path)
  let secret = pdf_async_io_secret_object_for_test(
    "async compressed aesv3 secret",
  )
  let doc = try! @pdflite.pdf_minimum_valid_pdf()
  doc.add_object_given_number(30, secret)
  let user = @ascii.encode("user")
  let owner = @ascii.encode("owner")
  let denied : Array[@pdflite.PdfPermission] = [PdfNoAssemble, PdfNoExtract]
  pdf_write_encrypted_aesv3_document_to_file_with_providers(
    doc,
    encrypted_path,
    user,
    owner,
    denied,
    @pdflite.pdf_deterministic_aesv3_random_provider_from_seed(
      @ascii.encode("async compressed aesv3 random"),
    ),
    @pdflite.pdf_deterministic_aes_iv_provider_from_seed(
      @ascii.encode("async compressed aesv3 iv"),
    ),
    encrypt_metadata=false,
    mode=PdfWriteCompressedXRefStream,
    file_id=@ascii.encode("async-compressed-aesv3-id"),
  )
  @test.assert_eq(
    pdf_async_io_find_bytes_for_test(
      @fs.read_file(encrypted_path).binary(),
      @ascii.encode("async compressed aesv3 secret"),
    ) <
    0,
    true,
  )
  let corrupted = pdf_async_io_corrupt_final_startxref_pointer_for_test(
    @fs.read_file(encrypted_path).binary(),
  )
  @fs.write_file(corrupted_path, corrupted, create=0o644)
  let recovered = pdf_async_io_decryption_result_for_test(
    pdf_read_document_from_file_with_passwords(
      corrupted_path,
      owner_password=Some(owner),
    ),
  )
  @test.assert_eq(recovered.document.first_xref(), 0)
  @test.assert_eq(recovered.denied_permissions, denied)
  @test.assert_eq(recovered.document.lookup_object_or_null(30), secret)
  let added_secret = pdf_async_io_secret_object_for_test(
    "async compressed aesv3 repaired",
  )
  recovered.document.add_object_given_number(31, added_secret)
  let recrypted = try! recovered.document.recrypt_with_password_aesv3_with_iv_provider(
    owner,
    @pdflite.pdf_deterministic_aes_iv_provider_from_seed(
      @ascii.encode("async compressed aesv3 repair iv"),
    ),
  )
  pdf_write_document_to_file_with_compressed_xref_stream(
    recrypted, repaired_path,
  )
  let roundtrip = pdf_async_io_decryption_result_for_test(
    pdf_read_document_from_file_with_passwords(
      repaired_path,
      user_password=Some(user),
    ),
  )
  pdf_async_io_remove_if_exists_for_test(encrypted_path)
  pdf_async_io_remove_if_exists_for_test(corrupted_path)
  pdf_async_io_remove_if_exists_for_test(repaired_path)
  @test.assert_eq(roundtrip.denied_permissions, denied)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(30), secret)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(31), added_secret)
}

///|
async test "async file wrappers reconstruct compressed AESV3 ISO encrypted documents with bad startxref" {
  let encrypted_path = pdf_async_io_test_path_for_test(
    "compressed_aesv3_iso_bad_startxref",
  )
  let corrupted_path = pdf_async_io_test_path_for_test(
    "compressed_aesv3_iso_bad_startxref_corrupted",
  )
  let repaired_path = pdf_async_io_test_path_for_test(
    "compressed_aesv3_iso_bad_startxref_repaired",
  )
  pdf_async_io_remove_if_exists_for_test(encrypted_path)
  pdf_async_io_remove_if_exists_for_test(corrupted_path)
  pdf_async_io_remove_if_exists_for_test(repaired_path)
  let secret = pdf_async_io_secret_object_for_test(
    "async compressed aesv3 iso secret",
  )
  let doc = try! @pdflite.pdf_minimum_valid_pdf()
  doc.add_object_given_number(30, secret)
  let user = @ascii.encode("user")
  let owner = @ascii.encode("owner")
  let denied : Array[@pdflite.PdfPermission] = [PdfNoAssemble]
  pdf_write_encrypted_aesv3_iso_document_to_file_with_providers(
    doc,
    encrypted_path,
    user,
    owner,
    denied,
    @pdflite.pdf_deterministic_aesv3_random_provider_from_seed(
      @ascii.encode("async compressed aesv3 iso random"),
    ),
    @pdflite.pdf_deterministic_aes_iv_provider_from_seed(
      @ascii.encode("async compressed aesv3 iso iv"),
    ),
    encrypt_metadata=false,
    mode=PdfWriteCompressedXRefStream,
    file_id=@ascii.encode("async-compressed-aesv3-iso-id"),
  )
  @test.assert_eq(
    pdf_async_io_find_bytes_for_test(
      @fs.read_file(encrypted_path).binary(),
      @ascii.encode("async compressed aesv3 iso secret"),
    ) <
    0,
    true,
  )
  let corrupted = pdf_async_io_corrupt_final_startxref_pointer_for_test(
    @fs.read_file(encrypted_path).binary(),
  )
  @fs.write_file(corrupted_path, corrupted, create=0o644)
  let recovered = pdf_async_io_decryption_result_for_test(
    pdf_read_document_from_file_with_passwords(
      corrupted_path,
      owner_password=Some(owner),
    ),
  )
  @test.assert_eq(recovered.document.first_xref(), 0)
  @test.assert_eq(recovered.denied_permissions, denied)
  @test.assert_eq(recovered.document.lookup_object_or_null(30), secret)
  let added_secret = pdf_async_io_secret_object_for_test(
    "async compressed aesv3 iso repaired",
  )
  recovered.document.add_object_given_number(31, added_secret)
  let recrypted = try! recovered.document.recrypt_with_password_aesv3_with_iv_provider(
    owner,
    @pdflite.pdf_deterministic_aes_iv_provider_from_seed(
      @ascii.encode("async compressed aesv3 iso repair iv"),
    ),
  )
  @test.assert_eq(
    try! recrypted.what_encryption(),
    Some(PdfEncryptionAES256ISO(false)),
  )
  pdf_write_document_to_file_with_compressed_xref_stream(
    recrypted, repaired_path,
  )
  let roundtrip = pdf_async_io_decryption_result_for_test(
    pdf_read_document_from_file_with_passwords(
      repaired_path,
      user_password=Some(user),
    ),
  )
  pdf_async_io_remove_if_exists_for_test(encrypted_path)
  pdf_async_io_remove_if_exists_for_test(corrupted_path)
  pdf_async_io_remove_if_exists_for_test(repaired_path)
  @test.assert_eq(roundtrip.denied_permissions, denied)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(30), secret)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(31), added_secret)
}

///|
async test "async file wrappers write incremental updates" {
  let original_path = pdf_async_io_test_path_for_test("original")
  let updated_path = pdf_async_io_test_path_for_test("incremental")
  pdf_async_io_remove_if_exists_for_test(original_path)
  pdf_async_io_remove_if_exists_for_test(updated_path)
  let original = try! @pdflite.pdf_minimum_valid_pdf()
  pdf_write_document_to_file(original, original_path)
  let updated = pdf_read_document_from_file(original_path)
  let key_title = pdf_async_io_name_for_test("/Title")
  let added_object : @pdflite.PdfObject = PdfDictionary([
    (key_title, PdfString(@ascii.encode("async incremental"))),
  ])
  updated.add_object_given_number(20, added_object)
  pdf_write_document_incremental_update_to_file(
    original_path, updated, updated_path,
  )
  let reparsed = pdf_read_document_from_file(updated_path)
  pdf_async_io_remove_if_exists_for_test(original_path)
  pdf_async_io_remove_if_exists_for_test(updated_path)
  @test.assert_eq(try! reparsed.endpage(), 1)
  @test.assert_eq(reparsed.lookup_object_or_null(20), added_object)
}

///|
async test "async file wrappers read incremental revisions" {
  let original_path = pdf_async_io_test_path_for_test("revision_original")
  let updated_path = pdf_async_io_test_path_for_test("revision_incremental")
  pdf_async_io_remove_if_exists_for_test(original_path)
  pdf_async_io_remove_if_exists_for_test(updated_path)
  let original = try! @pdflite.pdf_minimum_valid_pdf()
  pdf_write_document_to_file(original, original_path)
  let updated = pdf_read_document_from_file(original_path)
  let key_title = pdf_async_io_name_for_test("/Title")
  let added_object : @pdflite.PdfObject = PdfDictionary([
    (key_title, PdfString(@ascii.encode("async revision"))),
  ])
  updated.add_object_given_number(22, added_object)
  pdf_write_document_incremental_update_to_file(
    original_path, updated, updated_path,
  )
  let revision_count = pdf_revisions_from_file(updated_path)
  let latest = pdf_read_document_revision_from_file(updated_path, 1)
  let older = pdf_read_document_revision_from_file(updated_path, 2)
  guard pdf_read_document_revision_from_file_with_passwords(updated_path, 2)
    is Some(older_password_result) else {
    fail("expected revision decryption result")
  }
  pdf_async_io_remove_if_exists_for_test(original_path)
  pdf_async_io_remove_if_exists_for_test(updated_path)
  @test.assert_eq(revision_count, 2)
  @test.assert_eq(latest.lookup_object_or_null(22), added_object)
  @test.assert_eq(older.lookup_object_or_null(22), PdfNull)
  @test.assert_eq(
    older_password_result.document.lookup_object_or_null(22),
    PdfNull,
  )
  @test.assert_eq(older_password_result.denied_permissions, [])
}

///|
async test "async file wrappers write xref stream incremental updates" {
  let original_path = pdf_async_io_test_path_for_test("xref_original")
  let updated_path = pdf_async_io_test_path_for_test("xref_incremental")
  let compressed_path = pdf_async_io_test_path_for_test(
    "xref_incremental_compressed",
  )
  let mode_path = pdf_async_io_test_path_for_test("xref_incremental_mode")
  pdf_async_io_remove_if_exists_for_test(original_path)
  pdf_async_io_remove_if_exists_for_test(updated_path)
  pdf_async_io_remove_if_exists_for_test(compressed_path)
  pdf_async_io_remove_if_exists_for_test(mode_path)
  let original = try! @pdflite.pdf_minimum_valid_pdf()
  pdf_write_document_to_file_with_xref_stream(original, original_path)
  let updated = pdf_read_document_from_file(original_path)
  let key_title = pdf_async_io_name_for_test("/Title")
  let added_object : @pdflite.PdfObject = PdfDictionary([
    (key_title, PdfString(@ascii.encode("async xref incremental"))),
  ])
  updated.add_object_given_number(21, added_object)
  pdf_write_document_incremental_update_with_xref_stream_to_file(
    original_path, updated, updated_path,
  )
  pdf_write_document_incremental_update_with_compressed_xref_stream_to_file(
    original_path, updated, compressed_path,
  )
  pdf_write_document_incremental_update_to_file_with_mode(
    original_path,
    updated,
    mode_path,
    PdfWriteCompressedXRefStream,
  )
  let reparsed = pdf_read_document_from_file(updated_path)
  let compressed_reparsed = pdf_read_document_from_file(compressed_path)
  let mode_reparsed = pdf_read_document_from_file(mode_path)
  pdf_async_io_remove_if_exists_for_test(original_path)
  pdf_async_io_remove_if_exists_for_test(updated_path)
  pdf_async_io_remove_if_exists_for_test(compressed_path)
  pdf_async_io_remove_if_exists_for_test(mode_path)
  @test.assert_eq(reparsed.lookup_object_or_null(21), added_object)
  @test.assert_eq(compressed_reparsed.lookup_object_or_null(21), added_object)
  @test.assert_eq(mode_reparsed.lookup_object_or_null(21), added_object)
}

///|
async test "async file wrappers read encrypted incremental revisions" {
  let original_path = pdf_async_io_test_path_for_test(
    "encrypted_revision_original",
  )
  let updated_path = pdf_async_io_test_path_for_test(
    "encrypted_revision_incremental",
  )
  pdf_async_io_remove_if_exists_for_test(original_path)
  pdf_async_io_remove_if_exists_for_test(updated_path)
  let original_secret = pdf_async_io_secret_object_for_test(
    "async encrypted original",
  )
  let updated_secret = pdf_async_io_secret_object_for_test(
    "async encrypted updated",
  )
  let doc = try! @pdflite.pdf_minimum_valid_pdf()
  doc.add_object_given_number(30, original_secret)
  let denied : Array[@pdflite.PdfPermission] = [PdfNoCopy]
  let encrypted = try! doc.encrypt_128bit_aesv2_with_iv_provider(
    @ascii.encode("user"),
    @ascii.encode("owner"),
    denied,
    @pdflite.pdf_deterministic_aes_iv_provider_from_seed(
      @ascii.encode("async encrypted revision iv"),
    ),
    encrypt_metadata=false,
    file_id=@ascii.encode("async-encrypted-revision-id"),
  )
  pdf_write_document_to_file(encrypted, original_path)
  let decrypted = pdf_async_io_decryption_result_for_test(
    pdf_read_document_from_file_with_passwords(
      original_path,
      user_password=Some(@ascii.encode("user")),
    ),
  )
  decrypted.document.add_object_given_number(30, updated_secret)
  let recrypted = try! decrypted.document.recrypt_with_password_aesv2_with_iv_provider(
    @ascii.encode("owner"),
    @pdflite.pdf_deterministic_aes_iv_provider_from_seed(
      @ascii.encode("async encrypted revision recrypt iv"),
    ),
  )
  pdf_write_document_incremental_update_with_compressed_xref_stream_to_file(
    original_path, recrypted, updated_path,
  )
  let revision_count = pdf_revisions_from_file(updated_path)
  let newest = pdf_async_io_decryption_result_for_test(
    pdf_read_document_revision_from_file_with_passwords(
      updated_path,
      1,
      owner_password=Some(@ascii.encode("owner")),
    ),
  )
  let older = pdf_async_io_decryption_result_for_test(
    pdf_read_document_revision_from_file_with_passwords(
      updated_path,
      2,
      owner_password=Some(@ascii.encode("owner")),
    ),
  )
  pdf_async_io_remove_if_exists_for_test(original_path)
  pdf_async_io_remove_if_exists_for_test(updated_path)
  @test.assert_eq(revision_count, 2)
  @test.assert_eq(newest.denied_permissions, denied)
  @test.assert_eq(newest.document.lookup_object_or_null(30), updated_secret)
  @test.assert_eq(older.denied_permissions, denied)
  @test.assert_eq(older.document.lookup_object_or_null(30), original_secret)
}

///|
async test "async file wrappers reconstruct encrypted incremental revisions with bad startxref" {
  let original_path = pdf_async_io_test_path_for_test(
    "encrypted_bad_startxref_original",
  )
  let updated_path = pdf_async_io_test_path_for_test(
    "encrypted_bad_startxref_incremental",
  )
  let corrupted_path = pdf_async_io_test_path_for_test(
    "encrypted_bad_startxref_corrupted",
  )
  let repaired_path = pdf_async_io_test_path_for_test(
    "encrypted_bad_startxref_repaired",
  )
  pdf_async_io_remove_if_exists_for_test(original_path)
  pdf_async_io_remove_if_exists_for_test(updated_path)
  pdf_async_io_remove_if_exists_for_test(corrupted_path)
  pdf_async_io_remove_if_exists_for_test(repaired_path)
  let original_secret = pdf_async_io_secret_object_for_test(
    "async malformed encrypted original",
  )
  let updated_secret = pdf_async_io_secret_object_for_test(
    "async malformed encrypted updated",
  )
  let doc = try! @pdflite.pdf_minimum_valid_pdf()
  doc.add_object_given_number(30, original_secret)
  let denied : Array[@pdflite.PdfPermission] = [PdfNoCopy, PdfNoEdit]
  let encrypted = try! doc.encrypt_128bit_aesv2_with_iv_provider(
    @ascii.encode("user"),
    @ascii.encode("owner"),
    denied,
    @pdflite.pdf_deterministic_aes_iv_provider_from_seed(
      @ascii.encode("async encrypted bad startxref iv"),
    ),
    encrypt_metadata=false,
    file_id=@ascii.encode("async-encrypted-bad-startxref-id"),
  )
  pdf_write_document_to_file(encrypted, original_path)
  let decrypted = pdf_async_io_decryption_result_for_test(
    pdf_read_document_from_file_with_passwords(
      original_path,
      user_password=Some(@ascii.encode("user")),
    ),
  )
  decrypted.document.add_object_given_number(30, updated_secret)
  let recrypted = try! decrypted.document.recrypt_with_password_aesv2_with_iv_provider(
    @ascii.encode("owner"),
    @pdflite.pdf_deterministic_aes_iv_provider_from_seed(
      @ascii.encode("async encrypted bad startxref recrypt iv"),
    ),
  )
  pdf_write_document_incremental_update_with_compressed_xref_stream_to_file(
    original_path, recrypted, updated_path,
  )
  @test.assert_eq(pdf_revisions_from_file(updated_path), 2)
  let corrupted = pdf_async_io_corrupt_final_startxref_pointer_for_test(
    @fs.read_file(updated_path).binary(),
  )
  @fs.write_file(corrupted_path, corrupted, create=0o644)
  let recovered = pdf_async_io_decryption_result_for_test(
    pdf_read_document_from_file_with_passwords(
      corrupted_path,
      owner_password=Some(@ascii.encode("owner")),
    ),
  )
  @test.assert_eq(recovered.document.first_xref(), 0)
  @test.assert_eq(recovered.denied_permissions, denied)
  @test.assert_eq(recovered.document.lookup_object_or_null(30), updated_secret)
  let added_secret = pdf_async_io_secret_object_for_test(
    "async malformed encrypted repaired",
  )
  recovered.document.add_object_given_number(31, added_secret)
  let recovered_recrypted = try! recovered.document.recrypt_with_password_aesv2_with_iv_provider(
    @ascii.encode("owner"),
    @pdflite.pdf_deterministic_aes_iv_provider_from_seed(
      @ascii.encode("async encrypted bad startxref repair iv"),
    ),
  )
  pdf_write_document_to_file_with_compressed_xref_stream(
    recovered_recrypted, repaired_path,
  )
  let roundtrip = pdf_async_io_decryption_result_for_test(
    pdf_read_document_from_file_with_passwords(
      repaired_path,
      user_password=Some(@ascii.encode("user")),
    ),
  )
  pdf_async_io_remove_if_exists_for_test(original_path)
  pdf_async_io_remove_if_exists_for_test(updated_path)
  pdf_async_io_remove_if_exists_for_test(corrupted_path)
  pdf_async_io_remove_if_exists_for_test(repaired_path)
  @test.assert_eq(roundtrip.denied_permissions, denied)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(30), updated_secret)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(31), added_secret)
}
