///|
async fn pdf_async_io_remove_if_exists_for_test(path : String) -> Unit {
  if @fs.exists(path) {
    @fs.remove(path)
  }
}

///|
fn pdf_async_io_assert_generated_id_for_test(
  id : @syntax.PdfObject?,
) -> Unit raise {
  guard id is Some(PdfArray([PdfString(first), PdfString(second)])) else {
    fail("expected generated trailer ID")
  }
  @test.assert_eq(first.length(), 16)
  @test.assert_eq(second, first)
}

///|
async fn pdf_async_io_test_path_for_test(name : String) -> String {
  let directory = match @env.current_dir() {
    Some(current_dir) => current_dir + "/_build/"
    None => "_build/"
  }
  // In the `moon work` workspace the build directory lives at the workspace
  // root, so `_build` relative to the pdflite module cwd may not exist yet.
  if @fs.exists(directory) == false {
    @fs.mkdir(directory, recursive=true)
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
async fn pdf_async_io_build_dir_for_test() -> String {
  let dir = match @env.current_dir() {
    Some(current_dir) => current_dir + "/_build"
    None => "_build"
  }
  // See pdf_async_io_test_path_for_test: ensure the module-relative `_build`
  // directory exists under the workspace build layout.
  if @fs.exists(dir) == false {
    @fs.mkdir(dir, recursive=true)
  }
  dir
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
fn pdf_async_io_bytes_for_test(values : ArrayView[Int]) -> @core.PdfBytes {
  let output : Array[Byte] = []
  for value in values {
    output.push(try! @core.pdf_byte_of_int(value))
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
  output.push(try! @core.pdf_byte_of_int((value >> 24) & 0xFF))
  output.push(try! @core.pdf_byte_of_int((value >> 16) & 0xFF))
  output.push(try! @core.pdf_byte_of_int((value >> 8) & 0xFF))
  output.push(try! @core.pdf_byte_of_int(value & 0xFF))
}

///|
fn pdf_async_io_png_chunk_for_test(
  chunk_type : ArrayView[Int],
  data : BytesView,
) -> @core.PdfBytes {
  let output : Array[Byte] = []
  pdf_async_io_push_u32_for_test(output, data.length())
  for value in chunk_type {
    output.push(try! @core.pdf_byte_of_int(value))
  }
  pdf_async_io_append_bytes_for_test(output, data)
  pdf_async_io_push_u32_for_test(output, 0)
  Bytes::from_array(output)
}

///|
fn pdf_async_io_png_rgb_for_test() -> (@core.PdfBytes, @core.PdfBytes) {
  let header = pdf_async_io_bytes_for_test([
    0, 0, 0, 2, 0, 0, 0, 1, 8, 2, 0, 0, 0,
  ])
  let idat = @flate.pdf_flate_encode(
    pdf_async_io_bytes_for_test([0, 10, 20, 30, 40, 50, 60]),
  )
  let output : Array[Byte] = []
  for value in [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A] {
    output.push(try! @core.pdf_byte_of_int(value))
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
fn pdf_async_io_jpeg_for_test() -> @core.PdfBytes {
  pdf_async_io_bytes_for_test([
    0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x09, 0x4A, 0x46, 0x49, 0x46, 0x00, 0xAA, 0xBB,
    0xFF, 0xC0, 0x00, 0x09, 0x08, 0x01, 0x2C, 0x01, 0x90, 0x03, 0x01, 0xFF, 0xD9,
  ])
}

///|
fn pdf_async_io_progressive_jpeg_for_test() -> @core.PdfBytes {
  pdf_async_io_bytes_for_test([
    0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x09, 0x4A, 0x46, 0x49, 0x46, 0x00, 0xAA, 0xBB,
    0xFF, 0xC2, 0x00, 0x09, 0x08, 0x00, 0xF0, 0x01, 0x40, 0x03, 0x01, 0xFF, 0xD9,
  ])
}

///|
fn pdf_async_io_jpeg2000_for_test() -> @core.PdfBytes {
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
  bytes : @core.PdfBytes,
  marker_position : Int,
) -> @core.PdfBytes raise {
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
  bytes : @core.PdfBytes,
) -> @core.PdfBytes raise {
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
  bytes : @core.PdfBytes,
) -> @core.PdfBytes raise {
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
  bytes : @core.PdfBytes,
  object_number : Int,
) -> @core.PdfBytes raise {
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
  bytes : @core.PdfBytes,
  encrypt_object_number : Int,
) -> @core.PdfBytes raise {
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
  bytes : @core.PdfBytes,
) -> @core.PdfBytes raise {
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
  bytes : @core.PdfBytes,
) -> @core.PdfBytes raise {
  let marker = @ascii.encode("startxref")
  pdf_async_io_corrupt_startxref_pointer_at_for_test(
    bytes,
    pdf_async_io_find_bytes_for_test(bytes, marker),
  )
}

///|
fn pdf_async_io_corrupt_final_startxref_pointer_for_test(
  bytes : @core.PdfBytes,
) -> @core.PdfBytes raise {
  let marker = @ascii.encode("startxref")
  pdf_async_io_corrupt_startxref_pointer_at_for_test(
    bytes,
    pdf_async_io_find_last_bytes_for_test(bytes, marker),
  )
}

///|
fn pdf_async_io_insert_ascii_before_last_marker_for_test(
  bytes : @core.PdfBytes,
  marker : BytesView,
  insertion : String,
) -> @core.PdfBytes raise {
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
fn pdf_async_io_name_for_test(text : String) -> @core.PdfName {
  @core.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn pdf_async_io_ocg_catalog_for_test() -> @pdflite.PdfDocument {
  let key_root = pdf_async_io_name_for_test("/Root")
  let key_type = pdf_async_io_name_for_test("/Type")
  let type_catalog = pdf_async_io_name_for_test("/Catalog")
  let doc = @pdflite.pdf_document_empty()
  doc.set_root(1)
  doc.set_trailer_dict(PdfDictionary([(key_root, PdfIndirect(1))]))
  doc.add_object_given_number(
    1,
    PdfDictionary([(key_type, PdfNameObject(type_catalog))]),
  )
  doc
}

///|
fn pdf_async_io_ocg_content_for_test(
  number : Int,
  name : String,
) -> @ocg.PdfOptionalContent {
  let name_bytes = @ascii.encode(name)
  {
    ocgs: [
      (
        number,
        {
          name: name_bytes,
          intent: [pdf_async_io_name_for_test("/View")],
          usage: None,
        },
      ),
    ],
    default_config: {
      ..@ocg.pdf_ocg_default_config(),
      name: Some(@ascii.encode("Default")),
      on: [number],
      order: Some([(Some(name_bytes), [number])]),
    },
    configs: [],
  }
}

///|
fn pdf_async_io_resource_dictionary_for_test(
  entries : ArrayView[(String, @syntax.PdfObject)],
) -> @syntax.PdfObject {
  PdfDictionary(
    [
      for entry in entries => (pdf_async_io_name_for_test(entry.0), entry.1)
    ],
  )
}

///|
fn pdf_async_io_font_file_stream_for_test(data : String) -> @syntax.PdfObject {
  let bytes = @ascii.encode(data)
  @syntax.pdf_stream(
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
) -> @syntax.PdfObject {
  PdfDictionary([
    (pdf_async_io_name_for_test(font_file_key), PdfIndirect(font_file_number)),
    (pdf_async_io_name_for_test("/Flags"), PdfInteger(32)),
  ])
}

///|
fn pdf_async_io_font_for_test(
  subtype : String,
  basefont : String,
  descriptor : @syntax.PdfObject?,
) -> @syntax.PdfObject {
  let entries : Array[(@core.PdfName, @syntax.PdfObject)] = [
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
    ..@page.pdf_page_blank(@geometry.paper_a4),
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
  resources : @syntax.PdfObject,
  font_name : @core.PdfName,
) -> @syntax.PdfObject? {
  match doc.lookup_direct(pdf_async_io_name_for_test("/Font"), resources) {
    Some(fonts) => doc.lookup_direct(font_name, fonts)
    None => None
  }
}

///|
fn pdf_async_io_push_text_codepoints_for_test(
  output : Array[Int],
  extractor : @pdflite.PdfTextExtractor,
  text : @core.PdfBytes,
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
fn pdf_async_io_secret_object_for_test(text : String) -> @syntax.PdfObject {
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
) -> @core.PdfBytes {
  let output : Array[Byte] = []
  let row_count = (data.length() + columns - 1) / columns
  for row in 0..<row_count {
    let row_start = row * columns
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
  object : @syntax.PdfObject,
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
fn pdf_async_io_classic_catalog_object_for_test() -> @syntax.PdfObject {
  @syntax.pdf_dictionary([
    (
      pdf_async_io_name_for_test("/Type"),
      PdfNameObject(pdf_async_io_name_for_test("/Catalog")),
    ),
  ])
}

///|
fn pdf_async_io_catalog_with_payload_for_test(
  payload_number : Int,
) -> @syntax.PdfObject {
  @syntax.pdf_dictionary([
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
fn pdf_async_io_startxref_object_pdf_for_test(body : String) -> @core.PdfBytes {
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
) -> @core.PdfBytes {
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
fn pdf_async_io_linearized_classic_pdf_with_prev_xref_for_test() -> @core.PdfBytes {
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
) -> @core.PdfBytes {
  let output : Array[Byte] = []
  pdf_async_io_push_ascii_for_test(output, "%PDF-1.5\n")
  let catalog_offset = output.length()
  pdf_async_io_write_indirect_object_for_test(
    output,
    1,
    @syntax.pdf_dictionary([
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
) -> @core.PdfBytes {
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
    @flate.pdf_flate_encode(
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
fn pdf_async_io_xref_stream_pdf_with_short_entry_data_for_test() -> @core.PdfBytes {
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
fn pdf_async_io_malformed_pdf_without_startxref_for_test() -> @core.PdfBytes {
  let output : Array[Byte] = []
  pdf_async_io_push_ascii_for_test(output, "%PDF-1.4\n")
  pdf_async_io_write_indirect_object_for_test(
    output,
    1,
    @syntax.pdf_dictionary([
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
fn pdf_async_io_malformed_pdf_with_endobj_text_in_string_for_test() -> @core.PdfBytes {
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
fn pdf_async_io_malformed_pdf_with_glued_reconstruction_trailers_for_test() -> @core.PdfBytes {
  let output : Array[Byte] = []
  pdf_async_io_push_ascii_for_test(output, "%PDF-1.4\n")
  ignore(pdf_async_io_write_catalog_object_for_test(output))
  pdf_async_io_push_ascii_for_test(output, "trailer << /Size 2 >>\n")
  pdf_async_io_push_ascii_for_test(output, "trailer<< /Root 1 0 R /Size 2 >>\n")
  Bytes::from_array(output)
}

///|
fn pdf_async_io_classic_pdf_with_page_tree_missing_from_xref_for_test() -> @core.PdfBytes {
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
fn pdf_async_io_classic_pdf_with_catalog_missing_from_xref_for_test() -> @core.PdfBytes {
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
) -> @core.PdfBytes {
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
  bytes : @core.PdfBytes,
) -> @core.PdfBytes {
  let output : Array[Byte] = []
  for byte in bytes {
    let replacement = if byte.to_int() == 10 { (13).to_byte() } else { byte }
    output.push(replacement)
  }
  Bytes::from_array(output)
}

///|
fn pdf_async_io_classic_pdf_with_fixed_width_xref_for_test() -> @core.PdfBytes {
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
fn pdf_async_io_classic_pdf_with_unpadded_xref_for_test() -> @core.PdfBytes {
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
fn pdf_async_io_classic_pdf_with_inline_xref_header_for_test() -> @core.PdfBytes {
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
fn pdf_async_io_classic_pdf_with_glued_trailer_for_test() -> @core.PdfBytes {
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
fn pdf_async_io_classic_pdf_with_catalog_xref_for_test() -> @core.PdfBytes {
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
fn pdf_async_io_classic_pdf_with_trailing_startxref_junk_for_test() -> @core.PdfBytes {
  let output : Array[Byte] = []
  for byte in pdf_async_io_classic_pdf_with_catalog_xref_for_test()[:] {
    output.push(byte)
  }
  pdf_async_io_push_ascii_for_test(output, "\nstartxref\nnot-a-number\n")
  Bytes::from_array(output)
}

///|
fn pdf_async_io_classic_pdf_with_prefixed_startxref_for_test() -> @core.PdfBytes {
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
fn pdf_async_io_classic_pdf_with_inline_startxref_for_test() -> @core.PdfBytes {
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
fn pdf_async_io_classic_pdf_with_missing_endobj_catalog_for_test() -> @core.PdfBytes {
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
fn pdf_async_io_classic_pdf_with_missing_endobj_before_object_for_test() -> @core.PdfBytes {
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
fn pdf_async_io_classic_pdf_with_direct_stream_before_object_for_test() -> @core.PdfBytes {
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
  stream_body : @core.PdfBytes,
) -> @core.PdfBytes {
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
) -> @core.PdfBytes {
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
fn pdf_async_io_malformed_pdf_with_out_of_range_startxref_for_test() -> @core.PdfBytes {
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
fn pdf_async_io_malformed_pdf_with_bad_startxref_for_test() -> @core.PdfBytes {
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
) -> @core.PdfBytes {
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
) -> @core.PdfBytes {
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
fn pdf_async_io_classic_catalog_pdf_with_prev_xref_bad_startxref_for_test() -> @core.PdfBytes {
  let output : Array[Byte] = []
  pdf_async_io_push_ascii_for_test(output, "%PDF-1.4\n")
  let original_offset = output.length()
  pdf_async_io_write_indirect_object_for_test(
    output,
    1,
    @syntax.pdf_dictionary([
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
    @syntax.pdf_dictionary([
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
fn pdf_async_io_malformed_pdf_with_bad_xref_entry_for_test() -> @core.PdfBytes {
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
) -> @core.PdfBytes {
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
fn pdf_async_io_malformed_pdf_with_bad_xref_count_for_test() -> @core.PdfBytes {
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
fn pdf_async_io_malformed_pdf_with_bad_trailer_for_test() -> @core.PdfBytes {
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
fn pdf_async_io_malformed_pdf_with_missing_root_trailer_for_test() -> @core.PdfBytes {
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
) -> @core.PdfBytes {
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
fn pdf_async_io_malformed_pdf_with_bad_object_offset_for_test() -> @core.PdfBytes {
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
fn pdf_async_io_classic_pdf_without_trailer_after_xref_for_test() -> @core.PdfBytes {
  let output : Array[Byte] = []
  pdf_async_io_push_ascii_for_test(output, "%PDF-1.4\n")
  pdf_async_io_push_ascii_for_test(output, "startxref\n")
  let xref_digits_position = output.length()
  pdf_async_io_push_ascii_for_test(output, "0000000000\n%%EOF\n")
  let xref_offset = output.length()
  pdf_async_io_push_ascii_for_test(output, "xref\n0 1\n0000000000 65535 f \n")
  let digits = @ascii.encode(xref_offset.to_string())
  for i in 0..<digits.length() {
    output[xref_digits_position + 10 - digits.length() + i] = digits[i]
  }
  Bytes::from_array(output)
}

///|
fn pdf_async_io_classic_pdf_with_missing_indirect_stream_length_for_test() -> @core.PdfBytes {
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
fn pdf_async_io_classic_pdf_with_mismatched_object_xref_for_test() -> @core.PdfBytes {
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
fn pdf_async_io_classic_pdf_with_unparseable_xref_object_for_test() -> @core.PdfBytes {
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
fn pdf_async_io_classic_pdf_with_commented_indirect_stream_length_for_test() -> @core.PdfBytes {
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
fn pdf_async_io_classic_pdf_with_non_integer_stream_length_for_test() -> @core.PdfBytes {
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
fn pdf_async_io_classic_pdf_with_stream_length_object_for_test() -> @core.PdfBytes {
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
fn pdf_async_io_classic_pdf_with_negative_stream_length_for_test() -> @core.PdfBytes {
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
fn pdf_async_io_classic_pdf_with_unparseable_stream_length_for_test() -> @core.PdfBytes {
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
fn pdf_async_io_malformed_pdf_with_indirect_stream_length_for_test() -> @core.PdfBytes {
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
) -> @core.PdfBytes {
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
fn pdf_async_io_classic_pdf_with_truncated_stream_for_test() -> @core.PdfBytes {
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
fn pdf_async_io_malformed_pdf_with_object_header_inside_stream_for_test() -> @core.PdfBytes {
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
fn pdf_async_io_malformed_pdf_with_nested_object_header_for_test() -> @core.PdfBytes {
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
) -> @core.PdfBytes {
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
fn pdf_async_io_xref_stream_pdf_with_prev_update_for_test() -> @core.PdfBytes {
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
fn pdf_async_io_xref_stream_pdf_with_prev_deleted_for_test() -> @core.PdfBytes {
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
) -> @core.PdfBytes {
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
  let encoded = @flate.pdf_flate_encode(predicted)
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
fn pdf_async_io_compressed_xref_stream_pdf_with_prev_update_for_test() -> @core.PdfBytes {
  pdf_async_io_compressed_xref_stream_pdf_with_prev_update_startxref_for_test(
    None,
  )
}

///|
fn pdf_async_io_compressed_xref_stream_pdf_with_prev_update_bad_startxref_for_test() -> @core.PdfBytes {
  pdf_async_io_compressed_xref_stream_pdf_with_prev_update_startxref_for_test(
    Some(0),
  )
}

///|
fn pdf_async_io_classic_pdf_with_self_prev_xref_for_test() -> @core.PdfBytes {
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
fn pdf_async_io_classic_pdf_with_prev_xref_for_test() -> @core.PdfBytes {
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
fn pdf_async_io_bad_first_object_stream_physical_page_tree_pdf_for_test() -> @core.PdfBytes {
  let output : Array[Byte] = []
  pdf_async_io_push_ascii_for_test(output, "%PDF-1.5\n")
  let pages_offset = output.length()
  pdf_async_io_write_indirect_object_for_test(
    output,
    2,
    @syntax.pdf_dictionary([
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
    @syntax.pdf_dictionary([
      (
        pdf_async_io_name_for_test("/Type"),
        PdfNameObject(pdf_async_io_name_for_test("/Page")),
      ),
      (pdf_async_io_name_for_test("/Parent"), PdfIndirect(2)),
      (
        pdf_async_io_name_for_test("/MediaBox"),
        PdfArray([PdfInteger(0), PdfInteger(0), PdfInteger(10), PdfInteger(10)]),
      ),
      (pdf_async_io_name_for_test("/Resources"), @syntax.pdf_dictionary([])),
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
  let xref_stream = @syntax.pdf_stream(
    @syntax.pdf_dictionary([
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
    @syntax.pdf_dictionary([
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
fn pdf_async_io_mismatched_object_stream_root_physical_catalog_for_test() -> @core.PdfBytes {
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
  let xref_stream = @syntax.pdf_stream(
    @syntax.pdf_dictionary([
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
    @syntax.pdf_dictionary([
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
fn pdf_async_io_xref_stream_pdf_with_two_object_stream_entries_for_test() -> @core.PdfBytes {
  let output : Array[Byte] = []
  pdf_async_io_push_ascii_for_test(output, "%PDF-1.5\n")
  let catalog_offset = output.length()
  pdf_async_io_write_indirect_object_for_test(
    output,
    1,
    @syntax.pdf_dictionary([
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
  let xref_stream = @syntax.pdf_stream(
    @syntax.pdf_dictionary([
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
fn pdf_async_io_xref_stream_pdf_with_stream_object_in_object_stream_for_test() -> @core.PdfBytes {
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
  let xref_stream = @syntax.pdf_stream(
    @syntax.pdf_dictionary([
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
fn pdf_async_io_xref_stream_prev_update_with_object_stream_root_bad_startxref_for_test() -> @core.PdfBytes {
  let output : Array[Byte] = []
  pdf_async_io_push_ascii_for_test(output, "%PDF-1.5\n")
  let old_catalog_offset = output.length()
  pdf_async_io_write_indirect_object_for_test(
    output,
    1,
    @syntax.pdf_dictionary([
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
  let first_xref_stream = @syntax.pdf_stream(
    @syntax.pdf_dictionary([
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
  let second_xref_stream = @syntax.pdf_stream(
    @syntax.pdf_dictionary([
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
fn pdf_async_io_xref_stream_pdf_with_bad_filtered_object_stream_root_for_test() -> @core.PdfBytes {
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
  let xref_stream = @syntax.pdf_stream(
    @syntax.pdf_dictionary([
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
) -> @core.PdfBytes {
  let output : Array[Byte] = []
  pdf_async_io_push_ascii_for_test(output, "%PDF-1.5\n")
  let object_stream_data : Array[Byte] = []
  pdf_async_io_push_ascii_for_test(object_stream_data, "1 0 ")
  let first = object_stream_data.length()
  pdf_async_io_push_ascii_for_test(object_stream_data, "<< /Type /Catalog >>")
  let encoded_object_stream = @flate.pdf_flate_encode(
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
  let xref_stream = @syntax.pdf_stream(
    @syntax.pdf_dictionary([
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
fn pdf_async_io_xref_stream_pdf_with_bad_decodeparms_object_stream_root_for_test() -> @core.PdfBytes {
  pdf_async_io_xref_stream_pdf_with_decodeparms_object_stream_root_for_test(
    "/Bad",
  )
}

///|
fn pdf_async_io_xref_stream_pdf_with_unsupported_predictor_object_stream_root_for_test() -> @core.PdfBytes {
  pdf_async_io_xref_stream_pdf_with_decodeparms_object_stream_root_for_test(
    "<< /Predictor 9 >>",
  )
}

///|
fn pdf_async_io_bad_first_object_stream_payload_for_test() -> @core.PdfBytes {
  let output : Array[Byte] = []
  pdf_async_io_push_ascii_for_test(output, "%PDF-1.5\n")
  let catalog_offset = output.length()
  pdf_async_io_write_indirect_object_for_test(
    output,
    1,
    @syntax.pdf_dictionary([
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
  let xref_stream = @syntax.pdf_stream(
    @syntax.pdf_dictionary([
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
fn pdf_async_io_indirect_object_stream_bounds_bad_startxref_for_test() -> @core.PdfBytes {
  let output : Array[Byte] = []
  pdf_async_io_push_ascii_for_test(output, "%PDF-1.5\n")
  let catalog_offset = output.length()
  pdf_async_io_write_indirect_object_for_test(
    output,
    1,
    @syntax.pdf_dictionary([
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
  let xref_stream = @syntax.pdf_stream(
    @syntax.pdf_dictionary([
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
fn pdf_async_io_indirect_object_stream_filter_bad_startxref_for_test() -> @core.PdfBytes {
  let output : Array[Byte] = []
  pdf_async_io_push_ascii_for_test(output, "%PDF-1.5\n")
  let catalog_offset = output.length()
  pdf_async_io_write_indirect_object_for_test(
    output,
    1,
    @syntax.pdf_dictionary([
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
  let encoded_object_stream = @codec.pdf_ascii_hex_encode(
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
  let xref_stream = @syntax.pdf_stream(
    @syntax.pdf_dictionary([
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
  denied : ArrayView[@crypt_core.PdfPermission],
) -> @core.PdfBytes raise {
  let secret = pdf_async_io_secret_object_for_test(
    "async encrypted object stream",
  )
  let object_stream_data : Array[Byte] = []
  pdf_async_io_push_ascii_for_test(object_stream_data, "2 0 ")
  let first = object_stream_data.length()
  for byte in @pdflite.pdf_write_object(secret) {
    object_stream_data.push(byte)
  }
  let object_stream = @syntax.pdf_stream(
    @syntax.pdf_dictionary([
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
    @syntax.pdf_dictionary([
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
  let xref_stream = @syntax.pdf_stream(
    @syntax.pdf_dictionary([
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
fn pdf_async_io_encrypted_xref_stream_missing_object_stream_for_test() -> @core.PdfBytes {
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
  denied : Array[@crypt_core.PdfPermission],
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
) -> @pdflite.PdfDocument raise @core.PdfError {
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
  denied : Array[@crypt_core.PdfPermission],
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
