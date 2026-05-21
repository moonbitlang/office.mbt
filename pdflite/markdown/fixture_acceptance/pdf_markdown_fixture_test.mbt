///|
fn markdown_fixture_path_for_test(path : String) -> String {
  match @env.current_dir() {
    Some(current_dir) => current_dir + "/" + path
    None => path
  }
}

///|
async fn markdown_fixture_markdown_for_test(path : String) -> String {
  @markdown.pdf_bytes_to_markdown(
    @fs.read_file(markdown_fixture_path_for_test(path)).binary(),
  )
}

///|
async fn markdown_optional_fixture_markdown_for_test(path : String) -> String? {
  let read_result = try? @fs.read_file(markdown_fixture_path_for_test(path))
  match read_result {
    Ok(data) => Some(@markdown.pdf_bytes_to_markdown(data.binary()))
    Err(_) => None
  }
}

///|
async fn markdown_optional_fixture_bytes_for_test(path : String) -> Bytes? {
  let read_result = try? @fs.read_file(markdown_fixture_path_for_test(path))
  match read_result {
    Ok(data) => Some(data.binary())
    Err(_) => None
  }
}

///|
fn markdown_fixture_find_last_bytes_for_test(
  haystack : BytesView,
  needle : BytesView,
) -> Int {
  if needle.length() == 0 {
    haystack.length()
  } else if haystack.length() < needle.length() {
    -1
  } else {
    for start = haystack.length() - needle.length()
        start >= 0
        start = start - 1 {
      let mut matched = true
      for offset in 0..<needle.length() {
        if haystack[start + offset] != needle[offset] {
          matched = false
        }
      }
      if matched {
        break start
      }
    } nobreak {
      -1
    }
  }
}

///|
fn markdown_fixture_bytes_start_with_at_for_test(
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
fn markdown_fixture_find_bytes_for_test(
  haystack : BytesView,
  needle : BytesView,
) -> Int {
  if needle.length() == 0 {
    0
  } else if haystack.length() < needle.length() {
    -1
  } else {
    for start in 0..<=(haystack.length() - needle.length()) {
      if markdown_fixture_bytes_start_with_at_for_test(haystack, needle, start) {
        break start
      }
    } nobreak {
      -1
    }
  }
}

///|
fn markdown_fixture_find_bytes_after_for_test(
  haystack : BytesView,
  needle : BytesView,
  start : Int,
) -> Int {
  if needle.length() == 0 {
    start
  } else if start < 0 || haystack.length() < needle.length() {
    -1
  } else {
    for position in start..<=(haystack.length() - needle.length()) {
      if markdown_fixture_bytes_start_with_at_for_test(
          haystack, needle, position,
        ) {
        break position
      }
    } nobreak {
      -1
    }
  }
}

///|
fn markdown_fixture_push_ascii_for_test(
  output : Array[Byte],
  text : String,
) -> Unit {
  for byte in @ascii.encode(text) {
    output.push(byte)
  }
}

///|
fn markdown_fixture_corrupt_startxref_pointer_for_test(
  bytes : Bytes,
) -> Bytes raise {
  let marker = @ascii.encode("startxref")
  let marker_position = markdown_fixture_find_last_bytes_for_test(bytes, marker)
  if marker_position < 0 {
    fail("expected startxref marker")
  }
  let mut number_start = marker_position + marker.length()
  while number_start < bytes.length() &&
        (
          bytes[number_start] == b'\n' ||
          bytes[number_start] == b'\r' ||
          bytes[number_start] == b' ' ||
          bytes[number_start] == b'\t'
        ) {
    number_start += 1
  }
  let mut number_end = number_start
  while number_end < bytes.length() &&
        bytes[number_end] >= b'0' &&
        bytes[number_end] <= b'9' {
    number_end += 1
  }
  let output : Array[Byte] = []
  for index in 0..<number_start {
    output.push(bytes[index])
  }
  markdown_fixture_push_ascii_for_test(
    output,
    (bytes.length() + 4096).to_string(),
  )
  for index in number_end..<bytes.length() {
    output.push(bytes[index])
  }
  Bytes::from_array(output)
}

///|
fn markdown_fixture_startxref_offset_for_test(bytes : Bytes) -> Int raise {
  let marker = @ascii.encode("startxref")
  let marker_position = markdown_fixture_find_last_bytes_for_test(bytes, marker)
  if marker_position < 0 {
    fail("expected startxref marker")
  }
  let mut number_start = marker_position + marker.length()
  while number_start < bytes.length() &&
        (
          bytes[number_start] == b'\n' ||
          bytes[number_start] == b'\r' ||
          bytes[number_start] == b' ' ||
          bytes[number_start] == b'\t'
        ) {
    number_start += 1
  }
  let mut number = 0
  let mut current = number_start
  while current < bytes.length() &&
        bytes[current] >= b'0' &&
        bytes[current] <= b'9' {
    number = number * 10 + bytes[current].to_int() - b'0'.to_int()
    current += 1
  }
  if current == number_start {
    fail("expected startxref number")
  }
  number
}

///|
fn markdown_fixture_corrupt_startxref_xref_header_for_test(
  bytes : Bytes,
) -> Bytes raise {
  let xref_offset = markdown_fixture_startxref_offset_for_test(bytes)
  guard markdown_fixture_bytes_start_with_at_for_test(
    bytes,
    @ascii.encode("xref"),
    xref_offset,
  ) else {
    fail("expected startxref to point at a classic xref table")
  }
  let output : Array[Byte] = []
  for byte in bytes {
    output.push(byte)
  }
  output[xref_offset] = b'y'
  Bytes::from_array(output)
}

///|
fn markdown_fixture_corrupt_startxref_trailer_keyword_for_test(
  bytes : Bytes,
) -> Bytes raise {
  let xref_offset = markdown_fixture_startxref_offset_for_test(bytes)
  let trailer_position = markdown_fixture_find_bytes_after_for_test(
    bytes,
    @ascii.encode("trailer"),
    xref_offset,
  )
  if trailer_position < 0 {
    fail("expected classic xref trailer keyword after startxref target")
  }
  let output : Array[Byte] = []
  for byte in bytes {
    output.push(byte)
  }
  output[trailer_position] = b'u'
  Bytes::from_array(output)
}

///|
fn markdown_fixture_corrupt_startxref_xref_stream_token_for_test(
  bytes : Bytes,
  target : BytesView,
  replacement : BytesView,
  description : String,
) -> Bytes raise {
  let xref_offset = markdown_fixture_startxref_offset_for_test(bytes)
  let position = markdown_fixture_find_bytes_after_for_test(
    bytes, target, xref_offset,
  )
  if position < 0 {
    fail("expected xref stream " + description + " at startxref target")
  }
  let output : Array[Byte] = []
  for byte in bytes {
    output.push(byte)
  }
  for index in 0..<replacement.length() {
    output[position + index] = replacement[index]
  }
  Bytes::from_array(output)
}

///|
fn markdown_fixture_replace_bytes_after_with_padded_ascii_for_test(
  bytes : Bytes,
  anchor : BytesView,
  target : BytesView,
  replacement_text : String,
) -> Bytes raise {
  let replacement = @ascii.encode(replacement_text)
  if replacement.length() > target.length() {
    fail("replacement must fit target byte span")
  }
  let anchor_position = markdown_fixture_find_bytes_for_test(bytes, anchor)
  if anchor_position < 0 {
    fail("expected replacement anchor")
  }
  let position = markdown_fixture_find_bytes_after_for_test(
    bytes,
    target,
    anchor_position + anchor.length(),
  )
  if position < 0 {
    fail("expected replacement target after anchor")
  }
  let output : Array[Byte] = []
  for byte in bytes {
    output.push(byte)
  }
  for index in 0..<target.length() {
    output[position + index] = if index < replacement.length() {
      replacement[index]
    } else {
      b' '
    }
  }
  Bytes::from_array(output)
}

///|
fn markdown_fixture_corrupt_startxref_xref_stream_type_for_test(
  bytes : Bytes,
) -> Bytes raise {
  markdown_fixture_corrupt_startxref_xref_stream_token_for_test(
    bytes,
    @ascii.encode("/Type /XRef"),
    @ascii.encode("/Type /Bad"),
    "type",
  )
}

///|
fn markdown_fixture_corrupt_startxref_xref_stream_marker_for_test(
  bytes : Bytes,
) -> Bytes raise {
  markdown_fixture_corrupt_startxref_xref_stream_token_for_test(
    bytes,
    @ascii.encode("stream"),
    @ascii.encode("stramx"),
    "stream marker",
  )
}

///|
fn markdown_fixture_corrupt_startxref_xref_stream_endstream_for_test(
  bytes : Bytes,
) -> Bytes raise {
  markdown_fixture_corrupt_startxref_xref_stream_token_for_test(
    bytes,
    @ascii.encode("endstream"),
    @ascii.encode("endstreax"),
    "endstream marker",
  )
}

///|
fn markdown_fixture_corrupt_startxref_xref_stream_endobj_for_test(
  bytes : Bytes,
) -> Bytes raise {
  markdown_fixture_corrupt_startxref_xref_stream_token_for_test(
    bytes,
    @ascii.encode("endobj"),
    @ascii.encode("endobx"),
    "endobj marker",
  )
}

///|
fn markdown_fixture_corrupt_xref_stream_root_entry_for_test(
  bytes : Bytes,
  root_entry : BytesView,
) -> Bytes raise {
  markdown_fixture_replace_bytes_after_with_padded_ascii_for_test(
    bytes,
    @ascii.encode("/Type /XRef"),
    root_entry,
    "/Root /Bad",
  )
}

///|
fn markdown_fixture_corrupt_xref_stream_decodeparms_entry_for_test(
  bytes : Bytes,
  metadata_entry : BytesView,
  replacement_text : String,
) -> Bytes raise {
  markdown_fixture_replace_bytes_after_with_padded_ascii_for_test(
    bytes,
    @ascii.encode("/Type /XRef"),
    metadata_entry,
    replacement_text,
  )
}

///|
fn markdown_fixture_corrupt_xref_stream_filter_for_test(
  bytes : Bytes,
) -> Bytes raise {
  markdown_fixture_corrupt_startxref_xref_stream_token_for_test(
    bytes,
    @ascii.encode("/Filter /FlateDecode"),
    @ascii.encode("/Filter /NoSuchThing"),
    "filter",
  )
}

///|
fn markdown_fixture_first_in_use_xref_row_start_for_test(
  bytes : Bytes,
) -> Int raise {
  let free_row = @ascii.encode("0000000000 65535 f")
  let free_row_position = markdown_fixture_find_bytes_for_test(bytes, free_row)
  if free_row_position < 0 {
    fail("expected classic xref free row")
  }
  let mut row_start = free_row_position + free_row.length()
  while row_start < bytes.length() &&
        bytes[row_start] != b'\n' &&
        bytes[row_start] != b'\r' {
    row_start += 1
  }
  while row_start < bytes.length() &&
        (bytes[row_start] == b'\n' || bytes[row_start] == b'\r') {
    row_start += 1
  }
  if row_start + 10 > bytes.length() {
    fail("expected first in-use xref row")
  }
  row_start
}

///|
fn markdown_fixture_corrupt_first_in_use_xref_marker_for_test(
  bytes : Bytes,
) -> Bytes raise {
  let row_start = markdown_fixture_first_in_use_xref_row_start_for_test(bytes)
  let marker_position = row_start + 17
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
fn markdown_fixture_corrupt_first_in_use_xref_offset_for_test(
  bytes : Bytes,
) -> Bytes raise {
  let row_start = markdown_fixture_first_in_use_xref_row_start_for_test(bytes)
  let output : Array[Byte] = []
  for byte in bytes {
    output.push(byte)
  }
  for index in row_start..<(row_start + 10) {
    output[index] = b'9'
  }
  Bytes::from_array(output)
}

///|
fn markdown_fixture_corrupt_first_in_use_xref_generation_for_test(
  bytes : Bytes,
) -> Bytes raise {
  let row_start = markdown_fixture_first_in_use_xref_row_start_for_test(bytes)
  if row_start + 16 > bytes.length() {
    fail("expected first in-use xref generation")
  }
  let output : Array[Byte] = []
  for byte in bytes {
    output.push(byte)
  }
  for index in (row_start + 11)..<(row_start + 16) {
    output[index] = b'x'
  }
  Bytes::from_array(output)
}

///|
fn markdown_fixture_first_xref_subsection_spans_for_test(
  bytes : Bytes,
) -> (Int, Int, Int, Int) raise {
  let header = @ascii.encode("xref")
  let header_position = markdown_fixture_find_bytes_for_test(bytes, header)
  if header_position < 0 {
    fail("expected first classic xref header")
  }
  let mut first_start = header_position + header.length()
  while first_start < bytes.length() &&
        (
          bytes[first_start] == b'\n' ||
          bytes[first_start] == b'\r' ||
          bytes[first_start] == b' ' ||
          bytes[first_start] == b'\t'
        ) {
    first_start += 1
  }
  let mut first_end = first_start
  while first_end < bytes.length() &&
        bytes[first_end] >= b'0' &&
        bytes[first_end] <= b'9' {
    first_end += 1
  }
  if first_end == first_start {
    fail("expected first classic xref subsection object number")
  }
  let mut count_start = first_end
  while count_start < bytes.length() &&
        (
          bytes[count_start] == b'\n' ||
          bytes[count_start] == b'\r' ||
          bytes[count_start] == b' ' ||
          bytes[count_start] == b'\t'
        ) {
    count_start += 1
  }
  let mut count_end = count_start
  while count_end < bytes.length() &&
        bytes[count_end] >= b'0' &&
        bytes[count_end] <= b'9' {
    count_end += 1
  }
  if count_end == count_start {
    fail("expected first classic xref subsection count")
  }
  (first_start, first_end, count_start, count_end)
}

///|
fn markdown_fixture_corrupt_first_xref_subsection_object_for_test(
  bytes : Bytes,
) -> Bytes raise {
  let (object_start, object_end, _, _) = markdown_fixture_first_xref_subsection_spans_for_test(
    bytes,
  )
  let output : Array[Byte] = []
  for index in 0..<object_start {
    output.push(bytes[index])
  }
  markdown_fixture_push_ascii_for_test(output, "/Bad")
  for index in object_end..<bytes.length() {
    output.push(bytes[index])
  }
  Bytes::from_array(output)
}

///|
fn markdown_fixture_corrupt_first_xref_subsection_count_for_test(
  bytes : Bytes,
) -> Bytes raise {
  let (_, _, count_start, count_end) = markdown_fixture_first_xref_subsection_spans_for_test(
    bytes,
  )
  let output : Array[Byte] = []
  for index in 0..<count_start {
    output.push(bytes[index])
  }
  markdown_fixture_push_ascii_for_test(output, "/Bad")
  for index in count_end..<bytes.length() {
    output.push(bytes[index])
  }
  Bytes::from_array(output)
}

///|
fn markdown_fixture_assert_contains_for_test(
  text : String,
  fragment : String,
) -> Unit raise {
  @test.assert_eq(text.contains(fragment), true)
}

///|
fn markdown_fixture_replacement_count_for_test(text : String) -> Int {
  let mut count = 0
  for char in text {
    if char.to_int() == 0xFFFD {
      count += 1
    }
  }
  count
}

///|
fn markdown_fixture_raw_control_count_for_test(text : String) -> Int {
  let mut count = 0
  for char in text {
    let codepoint = char.to_int()
    if (
        codepoint < 0x20 &&
        codepoint != 0x0A &&
        codepoint != 0x09 &&
        codepoint != 0x0C
      ) ||
      (codepoint >= 0x7F && codepoint <= 0x9F) {
      count += 1
    }
  }
  count
}

///|
fn markdown_fixture_unique_cjk_unified_count_for_test(text : String) -> Int {
  let lower = 0x4E00
  let upper = 0x9FFF
  let seen = Array::make(upper - lower + 1, false)
  let mut count = 0
  for char in text {
    let codepoint = char.to_int()
    if codepoint >= lower && codepoint <= upper {
      let index = codepoint - lower
      if !seen[index] {
        seen[index] = true
        count += 1
      }
    }
  }
  count
}

///|
fn markdown_cpdf_source_top_level_classic_pdf_paths_for_test() -> Array[String] {
  [".repos/cpdf-source/hello.pdf", ".repos/cpdf-source/logo.pdf"]
}

///|
fn markdown_cpdf_source_manual_image_pdf_paths_for_test() -> Array[String] {
  [
    ".repos/cpdf-source/manualimages/bez.pdf", ".repos/cpdf-source/manualimages/capjoins.pdf",
    ".repos/cpdf-source/manualimages/clip.pdf", ".repos/cpdf-source/manualimages/colfill.pdf",
    ".repos/cpdf-source/manualimages/dash.pdf", ".repos/cpdf-source/manualimages/fill.pdf",
    ".repos/cpdf-source/manualimages/fontparams.pdf", ".repos/cpdf-source/manualimages/fonts.pdf",
    ".repos/cpdf-source/manualimages/h1.pdf", ".repos/cpdf-source/manualimages/line.pdf",
    ".repos/cpdf-source/manualimages/lines.pdf", ".repos/cpdf-source/manualimages/matrix.pdf",
    ".repos/cpdf-source/manualimages/para.pdf", ".repos/cpdf-source/manualimages/paras.pdf",
    ".repos/cpdf-source/manualimages/png.pdf", ".repos/cpdf-source/manualimages/pop.pdf",
    ".repos/cpdf-source/manualimages/stext.pdf", ".repos/cpdf-source/manualimages/text.pdf",
    ".repos/cpdf-source/manualimages/textclip.pdf", ".repos/cpdf-source/manualimages/trans.pdf",
    ".repos/cpdf-source/manualimages/xobj.pdf",
  ]
}

///|
fn markdown_fixture_assert_cpdf_top_level_classic_markdown_for_test(
  markdown : String,
  path : String,
) -> Unit raise {
  markdown_fixture_assert_contains_for_test(markdown, "# Page 1")
  match path {
    ".repos/cpdf-source/hello.pdf" =>
      markdown_fixture_assert_contains_for_test(markdown, "Hello, World!")
    ".repos/cpdf-source/logo.pdf" =>
      @test.assert_eq(markdown, "# Page 1\n\n\n", msg=path)
    _ => fail("unexpected cpdf top-level classic PDF path: " + path)
  }
  @test.assert_eq(
    markdown_fixture_raw_control_count_for_test(markdown),
    0,
    msg=path,
  )
  @test.assert_eq(
    markdown_fixture_replacement_count_for_test(markdown),
    0,
    msg=path,
  )
}

///|
fn markdown_fixture_assert_cpdf_manual_image_markdown_for_test(
  markdown : String,
  path : String,
) -> Unit raise {
  markdown_fixture_assert_contains_for_test(markdown, "# Page 1")
  @test.assert_eq(
    markdown_fixture_raw_control_count_for_test(markdown),
    0,
    msg=path,
  )
  @test.assert_eq(
    markdown_fixture_replacement_count_for_test(markdown),
    0,
    msg=path,
  )
}

///|
async test "pdf_bytes_to_markdown extracts Pandoc Latin fixture" {
  let markdown = markdown_fixture_markdown_for_test(
    "markdown/fixtures/pandoc_latin.pdf",
  )
  markdown_fixture_assert_contains_for_test(markdown, "# Page 1")
  markdown_fixture_assert_contains_for_test(markdown, "# Page 2")
  markdown_fixture_assert_contains_for_test(markdown, "Pandoc Latin Fixture")
  markdown_fixture_assert_contains_for_test(markdown, "Hello from Pandoc.")
  markdown_fixture_assert_contains_for_test(
    markdown, "stable marker: alpha beta 123.",
  )
}

///|
async test "pdf_bytes_to_markdown extracts Pandoc CJK fixture" {
  let markdown = markdown_fixture_markdown_for_test(
    "markdown/fixtures/pandoc_cjk.pdf",
  )
  markdown_fixture_assert_contains_for_test(markdown, "# Page 1")
  markdown_fixture_assert_contains_for_test(markdown, "Pandoc CJK Fixture")
  markdown_fixture_assert_contains_for_test(markdown, "中文测试")
  markdown_fixture_assert_contains_for_test(markdown, "日本語テスト")
  markdown_fixture_assert_contains_for_test(markdown, "한국어 테스트")
}

///|
async test "pdf_bytes_to_markdown extracts checked-in CamlPDF introduction fixture" {
  let markdown = markdown_fixture_markdown_for_test(
    "fixtures/camlpdf/introduction_to_camlpdf.pdf",
  )
  markdown_fixture_assert_contains_for_test(markdown, "# Page 1")
  markdown_fixture_assert_contains_for_test(
    markdown, "An Introduction to PDF with CamlPDF",
  )
  markdown_fixture_assert_contains_for_test(markdown, "A First Program")
  markdown_fixture_assert_contains_for_test(markdown, "Pdfread.pdf_of_file")
  markdown_fixture_assert_contains_for_test(markdown, "Pdfwrite.pdf_to_file")
  markdown_fixture_assert_contains_for_test(markdown, "PDF is a directed graph")
  @test.assert_eq(markdown_fixture_raw_control_count_for_test(markdown), 0)
  @test.assert_eq(markdown_fixture_replacement_count_for_test(markdown), 0)
}

///|
async test "pdf_bytes_to_markdown reconstructs checked-in CamlPDF introduction fixture with bad startxref" {
  let bytes = @fs.read_file(
    markdown_fixture_path_for_test(
      "fixtures/camlpdf/introduction_to_camlpdf.pdf",
    ),
  ).binary()
  let markdown = @markdown.pdf_bytes_to_markdown(
    markdown_fixture_corrupt_startxref_pointer_for_test(bytes),
  )
  markdown_fixture_assert_contains_for_test(
    markdown, "An Introduction to PDF with CamlPDF",
  )
  markdown_fixture_assert_contains_for_test(markdown, "Pdfread.pdf_of_file")
  markdown_fixture_assert_contains_for_test(markdown, "PDF is a directed graph")
  @test.assert_eq(markdown_fixture_raw_control_count_for_test(markdown), 0)
  @test.assert_eq(markdown_fixture_replacement_count_for_test(markdown), 0)
}

///|
async test "pdf_bytes_to_markdown tolerates checked-in CamlPDF logo fixture" {
  let markdown = markdown_fixture_markdown_for_test("fixtures/camlpdf/logo.pdf")
  @test.assert_eq(markdown, "# Page 1\n\n\n")
  @test.assert_eq(markdown_fixture_raw_control_count_for_test(markdown), 0)
  @test.assert_eq(markdown_fixture_replacement_count_for_test(markdown), 0)
}

///|
async test "pdf_bytes_to_markdown extracts optional cpdf source hello fixture" {
  match
    markdown_optional_fixture_markdown_for_test(".repos/cpdf-source/hello.pdf") {
    None => ()
    Some(markdown) => {
      markdown_fixture_assert_contains_for_test(markdown, "# Page 1")
      markdown_fixture_assert_contains_for_test(markdown, "Hello, World!")
      @test.assert_eq(markdown_fixture_raw_control_count_for_test(markdown), 0)
      @test.assert_eq(markdown_fixture_replacement_count_for_test(markdown), 0)
    }
  }
}

///|
async test "pdf_bytes_to_markdown reconstructs optional cpdf source hello fixture with bad startxref" {
  match
    markdown_optional_fixture_bytes_for_test(".repos/cpdf-source/hello.pdf") {
    None => ()
    Some(bytes) => {
      let markdown = @markdown.pdf_bytes_to_markdown(
        markdown_fixture_corrupt_startxref_pointer_for_test(bytes),
      )
      markdown_fixture_assert_contains_for_test(markdown, "# Page 1")
      markdown_fixture_assert_contains_for_test(markdown, "Hello, World!")
      @test.assert_eq(markdown_fixture_raw_control_count_for_test(markdown), 0)
      @test.assert_eq(markdown_fixture_replacement_count_for_test(markdown), 0)
    }
  }
}

///|
async test "pdf_bytes_to_markdown extracts optional cpdf source top-level classic PDF corpus" {
  let mut checked = 0
  let mut textful = 0
  for path in markdown_cpdf_source_top_level_classic_pdf_paths_for_test() {
    match markdown_optional_fixture_bytes_for_test(path) {
      None => ()
      Some(bytes) => {
        checked += 1
        let markdown = @markdown.pdf_bytes_to_markdown(bytes)
        markdown_fixture_assert_cpdf_top_level_classic_markdown_for_test(
          markdown, path,
        )
        if markdown != "# Page 1\n\n\n" {
          textful += 1
        }
      }
    }
  }
  if checked > 0 {
    @test.assert_eq(
      checked,
      markdown_cpdf_source_top_level_classic_pdf_paths_for_test().length(),
    )
    @test.assert_eq(textful > 0, true)
  }
}

///|
async test "pdf_bytes_to_markdown reconstructs optional cpdf source top-level classic PDF corpus with malformed xref metadata and rows" {
  let mut checked = 0
  let mut textful = 0
  for path in markdown_cpdf_source_top_level_classic_pdf_paths_for_test() {
    match markdown_optional_fixture_bytes_for_test(path) {
      None => ()
      Some(bytes) => {
        checked += 1
        let markdown = @markdown.pdf_bytes_to_markdown(bytes)
        markdown_fixture_assert_cpdf_top_level_classic_markdown_for_test(
          markdown, path,
        )
        if markdown != "# Page 1\n\n\n" {
          textful += 1
        }
        for
          corrupted in [
            markdown_fixture_corrupt_startxref_pointer_for_test(bytes),
            markdown_fixture_corrupt_startxref_xref_header_for_test(bytes),
            markdown_fixture_corrupt_startxref_trailer_keyword_for_test(bytes),
            markdown_fixture_corrupt_first_in_use_xref_marker_for_test(bytes),
            markdown_fixture_corrupt_first_in_use_xref_offset_for_test(bytes),
            markdown_fixture_corrupt_first_in_use_xref_generation_for_test(
              bytes,
            ),
            markdown_fixture_corrupt_first_xref_subsection_object_for_test(
              bytes,
            ),
            markdown_fixture_corrupt_first_xref_subsection_count_for_test(bytes),
          ] {
          let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
            corrupted,
          )
          guard strict is Err(_) else {
            fail(
              "expected malformed classic xref data to require malformed reconstruction for " +
              path,
            )
          }
          let reconstructed = @markdown.pdf_bytes_to_markdown(corrupted)
          markdown_fixture_assert_cpdf_top_level_classic_markdown_for_test(
            reconstructed, path,
          )
          @test.assert_eq(reconstructed, markdown, msg=path)
        }
      }
    }
  }
  if checked > 0 {
    @test.assert_eq(
      checked,
      markdown_cpdf_source_top_level_classic_pdf_paths_for_test().length(),
    )
    @test.assert_eq(textful > 0, true)
  }
}

///|
async test "pdf_bytes_to_markdown extracts optional cpdf source manual image PDF corpus" {
  let mut checked = 0
  let mut textful = 0
  for path in markdown_cpdf_source_manual_image_pdf_paths_for_test() {
    match markdown_optional_fixture_bytes_for_test(path) {
      None => ()
      Some(bytes) => {
        checked += 1
        let markdown = @markdown.pdf_bytes_to_markdown(bytes)
        markdown_fixture_assert_cpdf_manual_image_markdown_for_test(
          markdown, path,
        )
        if markdown != "# Page 1\n\n\n" {
          textful += 1
        }
        let reconstructed = @markdown.pdf_bytes_to_markdown(
          markdown_fixture_corrupt_startxref_pointer_for_test(bytes),
        )
        markdown_fixture_assert_cpdf_manual_image_markdown_for_test(
          reconstructed, path,
        )
        @test.assert_eq(reconstructed, markdown, msg=path)
      }
    }
  }
  if checked > 0 {
    @test.assert_eq(
      checked,
      markdown_cpdf_source_manual_image_pdf_paths_for_test().length(),
    )
    @test.assert_eq(textful > 0, true)
  }
}

///|
async test "pdf_bytes_to_markdown reconstructs optional cpdf source manual image PDF corpus with damaged classic xref metadata" {
  let mut checked = 0
  let mut textful = 0
  for path in markdown_cpdf_source_manual_image_pdf_paths_for_test() {
    match markdown_optional_fixture_bytes_for_test(path) {
      None => ()
      Some(bytes) => {
        checked += 1
        let markdown = @markdown.pdf_bytes_to_markdown(bytes)
        markdown_fixture_assert_cpdf_manual_image_markdown_for_test(
          markdown, path,
        )
        if markdown != "# Page 1\n\n\n" {
          textful += 1
        }
        for
          corrupted in [
            markdown_fixture_corrupt_startxref_xref_header_for_test(bytes),
            markdown_fixture_corrupt_startxref_trailer_keyword_for_test(bytes),
          ] {
          let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
            corrupted,
          )
          guard strict is Err(_) else {
            fail(
              "expected damaged classic xref metadata to require malformed reconstruction for " +
              path,
            )
          }
          let reconstructed = @markdown.pdf_bytes_to_markdown(corrupted)
          markdown_fixture_assert_cpdf_manual_image_markdown_for_test(
            reconstructed, path,
          )
          @test.assert_eq(reconstructed, markdown, msg=path)
        }
      }
    }
  }
  if checked > 0 {
    @test.assert_eq(
      checked,
      markdown_cpdf_source_manual_image_pdf_paths_for_test().length(),
    )
    @test.assert_eq(textful > 0, true)
  }
}

///|
async test "pdf_bytes_to_markdown reconstructs optional cpdf source manual image PDF corpus with malformed classic xref rows" {
  let mut checked = 0
  let mut textful = 0
  for path in markdown_cpdf_source_manual_image_pdf_paths_for_test() {
    match markdown_optional_fixture_bytes_for_test(path) {
      None => ()
      Some(bytes) => {
        checked += 1
        let markdown = @markdown.pdf_bytes_to_markdown(bytes)
        markdown_fixture_assert_cpdf_manual_image_markdown_for_test(
          markdown, path,
        )
        if markdown != "# Page 1\n\n\n" {
          textful += 1
        }
        for
          corrupted in [
            markdown_fixture_corrupt_first_in_use_xref_marker_for_test(bytes),
            markdown_fixture_corrupt_first_in_use_xref_offset_for_test(bytes),
            markdown_fixture_corrupt_first_in_use_xref_generation_for_test(
              bytes,
            ),
            markdown_fixture_corrupt_first_xref_subsection_object_for_test(
              bytes,
            ),
            markdown_fixture_corrupt_first_xref_subsection_count_for_test(bytes),
          ] {
          let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
            corrupted,
          )
          guard strict is Err(_) else {
            fail(
              "expected malformed classic xref row to require malformed reconstruction for " +
              path,
            )
          }
          let reconstructed = @markdown.pdf_bytes_to_markdown(corrupted)
          markdown_fixture_assert_cpdf_manual_image_markdown_for_test(
            reconstructed, path,
          )
          @test.assert_eq(reconstructed, markdown, msg=path)
        }
      }
    }
  }
  if checked > 0 {
    @test.assert_eq(
      checked,
      markdown_cpdf_source_manual_image_pdf_paths_for_test().length(),
    )
    @test.assert_eq(textful > 0, true)
  }
}

///|
async test "pdf_bytes_to_markdown extracts optional cpdf source manual fixture" {
  match
    markdown_optional_fixture_markdown_for_test(
      ".repos/cpdf-source/cpdfmanual.pdf",
    ) {
    None => ()
    Some(markdown) => {
      markdown_fixture_assert_contains_for_test(markdown, "# Page 1")
      markdown_fixture_assert_contains_for_test(markdown, "Coherent PDF")
      markdown_fixture_assert_contains_for_test(markdown, "Command Line Tools")
      markdown_fixture_assert_contains_for_test(
        markdown, "Chapter 15: PDF and JSON",
      )
      markdown_fixture_assert_contains_for_test(
        markdown, "cpdf -extract-images",
      )
      markdown_fixture_assert_contains_for_test(
        markdown, "Accessible PDFs with PDF/UA",
      )
      @test.assert_eq(markdown.length() > 200000, true)
      @test.assert_eq(markdown_fixture_replacement_count_for_test(markdown), 0)
    }
  }
}

///|
async test "pdf_bytes_to_markdown reconstructs optional cpdf source manual fixture with bad startxref" {
  match
    markdown_optional_fixture_bytes_for_test(
      ".repos/cpdf-source/cpdfmanual.pdf",
    ) {
    None => ()
    Some(bytes) => {
      let markdown = @markdown.pdf_bytes_to_markdown(
        markdown_fixture_corrupt_startxref_pointer_for_test(bytes),
      )
      markdown_fixture_assert_contains_for_test(markdown, "Coherent PDF")
      markdown_fixture_assert_contains_for_test(markdown, "Command Line Tools")
      markdown_fixture_assert_contains_for_test(
        markdown, "Chapter 15: PDF and JSON",
      )
      markdown_fixture_assert_contains_for_test(
        markdown, "Accessible PDFs with PDF/UA",
      )
      @test.assert_eq(markdown.length() > 200000, true)
      @test.assert_eq(markdown_fixture_replacement_count_for_test(markdown), 0)
    }
  }
}

///|
async test "pdf_bytes_to_markdown reconstructs optional cpdf source manual fixture with malformed xref stream metadata" {
  match
    markdown_optional_fixture_bytes_for_test(
      ".repos/cpdf-source/cpdfmanual.pdf",
    ) {
    None => ()
    Some(bytes) => {
      let markdown = @markdown.pdf_bytes_to_markdown(bytes)
      markdown_fixture_assert_contains_for_test(markdown, "Coherent PDF")
      markdown_fixture_assert_contains_for_test(markdown, "Command Line Tools")
      markdown_fixture_assert_contains_for_test(
        markdown, "Chapter 15: PDF and JSON",
      )
      markdown_fixture_assert_contains_for_test(
        markdown, "Accessible PDFs with PDF/UA",
      )
      @test.assert_eq(markdown.length() > 200000, true)
      @test.assert_eq(markdown_fixture_replacement_count_for_test(markdown), 0)
      for
        corrupted in [
          markdown_fixture_corrupt_startxref_xref_stream_type_for_test(bytes),
          markdown_fixture_corrupt_startxref_xref_stream_marker_for_test(bytes),
        ] {
        let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
          corrupted,
        )
        guard strict is Err(_) else {
          fail(
            "expected malformed xref stream metadata to require reconstruction",
          )
        }
        let reconstructed = @markdown.pdf_bytes_to_markdown(corrupted)
        markdown_fixture_assert_contains_for_test(reconstructed, "Coherent PDF")
        markdown_fixture_assert_contains_for_test(
          reconstructed, "Command Line Tools",
        )
        markdown_fixture_assert_contains_for_test(
          reconstructed, "Chapter 15: PDF and JSON",
        )
        markdown_fixture_assert_contains_for_test(
          reconstructed, "Accessible PDFs with PDF/UA",
        )
        @test.assert_eq(reconstructed, markdown)
        @test.assert_eq(
          markdown_fixture_replacement_count_for_test(reconstructed),
          0,
        )
      }
    }
  }
}

///|
async test "pdf_bytes_to_markdown reconstructs optional cpdf source manual fixture with malformed xref stream terminators" {
  match
    markdown_optional_fixture_bytes_for_test(
      ".repos/cpdf-source/cpdfmanual.pdf",
    ) {
    None => ()
    Some(bytes) => {
      let markdown = @markdown.pdf_bytes_to_markdown(bytes)
      markdown_fixture_assert_contains_for_test(markdown, "Coherent PDF")
      markdown_fixture_assert_contains_for_test(markdown, "Command Line Tools")
      markdown_fixture_assert_contains_for_test(
        markdown, "Chapter 15: PDF and JSON",
      )
      markdown_fixture_assert_contains_for_test(
        markdown, "Accessible PDFs with PDF/UA",
      )
      @test.assert_eq(markdown.length() > 200000, true)
      @test.assert_eq(markdown_fixture_replacement_count_for_test(markdown), 0)
      for
        corrupted in [
          markdown_fixture_corrupt_startxref_xref_stream_endstream_for_test(
            bytes,
          ),
          markdown_fixture_corrupt_startxref_xref_stream_endobj_for_test(bytes),
        ] {
        let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
          corrupted,
        )
        guard strict is Err(_) else {
          fail(
            "expected malformed xref stream terminator to require reconstruction",
          )
        }
        let reconstructed = @markdown.pdf_bytes_to_markdown(corrupted)
        markdown_fixture_assert_contains_for_test(reconstructed, "Coherent PDF")
        markdown_fixture_assert_contains_for_test(
          reconstructed, "Command Line Tools",
        )
        markdown_fixture_assert_contains_for_test(
          reconstructed, "Chapter 15: PDF and JSON",
        )
        markdown_fixture_assert_contains_for_test(
          reconstructed, "Accessible PDFs with PDF/UA",
        )
        @test.assert_eq(reconstructed, markdown)
        @test.assert_eq(
          markdown_fixture_replacement_count_for_test(reconstructed),
          0,
        )
      }
    }
  }
}

///|
async test "pdf_bytes_to_markdown reconstructs optional cpdf source manual fixture with malformed xref stream dictionary entries" {
  match
    markdown_optional_fixture_bytes_for_test(
      ".repos/cpdf-source/cpdfmanual.pdf",
    ) {
    None => ()
    Some(bytes) => {
      let markdown = @markdown.pdf_bytes_to_markdown(bytes)
      markdown_fixture_assert_contains_for_test(markdown, "Coherent PDF")
      markdown_fixture_assert_contains_for_test(markdown, "Command Line Tools")
      markdown_fixture_assert_contains_for_test(
        markdown, "Chapter 15: PDF and JSON",
      )
      markdown_fixture_assert_contains_for_test(
        markdown, "Accessible PDFs with PDF/UA",
      )
      @test.assert_eq(markdown.length() > 200000, true)
      @test.assert_eq(markdown_fixture_replacement_count_for_test(markdown), 0)
      let manual_root_entry = @ascii.encode("/Root 1841 0 R")
      let manual_id_entry = @ascii.encode(
        "/ID [<CA2FED47397E566603B0A9A8E7328C79> <CA2FED47397E566603B0A9A8E7328C79>]",
      )
      for
        corrupted in [
          markdown_fixture_corrupt_xref_stream_root_entry_for_test(
            bytes, manual_root_entry,
          ),
          markdown_fixture_corrupt_xref_stream_decodeparms_entry_for_test(
            bytes, manual_id_entry, "/DecodeParms /Bad",
          ),
          markdown_fixture_corrupt_xref_stream_decodeparms_entry_for_test(
            bytes, manual_id_entry, "/DecodeParms << /Predictor 9 >>",
          ),
          markdown_fixture_corrupt_xref_stream_filter_for_test(bytes),
        ] {
        let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
          corrupted,
        )
        guard strict is Err(_) else {
          fail(
            "expected malformed xref stream dictionary entry to require reconstruction",
          )
        }
        let reconstructed = @markdown.pdf_bytes_to_markdown(corrupted)
        markdown_fixture_assert_contains_for_test(reconstructed, "Coherent PDF")
        markdown_fixture_assert_contains_for_test(
          reconstructed, "Command Line Tools",
        )
        markdown_fixture_assert_contains_for_test(
          reconstructed, "Chapter 15: PDF and JSON",
        )
        markdown_fixture_assert_contains_for_test(
          reconstructed, "Accessible PDFs with PDF/UA",
        )
        @test.assert_eq(reconstructed, markdown)
        @test.assert_eq(
          markdown_fixture_replacement_count_for_test(reconstructed),
          0,
        )
      }
    }
  }
}

///|
async test "pdf_bytes_to_markdown extracts external Adobe supplement fixture" {
  match
    markdown_optional_fixture_markdown_for_test(
      "markdown/external_fixtures/downloads/adobe_supplement_iso32000_1.pdf",
    ) {
    None => ()
    Some(markdown) => {
      markdown_fixture_assert_contains_for_test(
        markdown, "Adobe® Supplement to",
      )
      markdown_fixture_assert_contains_for_test(markdown, "ISO 32000-1")
      markdown_fixture_assert_contains_for_test(markdown, "BaseVersion: 1.7")
      markdown_fixture_assert_contains_for_test(markdown, "ExtensionLevel: 5")
      @test.assert_eq(markdown_fixture_raw_control_count_for_test(markdown), 0)
      @test.assert_eq(markdown_fixture_replacement_count_for_test(markdown), 6)
    }
  }
}

///|
async test "pdf_bytes_to_markdown reconstructs external Adobe supplement fixture with bad startxref" {
  match
    markdown_optional_fixture_bytes_for_test(
      "markdown/external_fixtures/downloads/adobe_supplement_iso32000_1.pdf",
    ) {
    None => ()
    Some(bytes) => {
      let markdown = @markdown.pdf_bytes_to_markdown(
        markdown_fixture_corrupt_startxref_pointer_for_test(bytes),
      )
      markdown_fixture_assert_contains_for_test(
        markdown, "Adobe® Supplement to",
      )
      markdown_fixture_assert_contains_for_test(markdown, "ISO 32000-1")
      markdown_fixture_assert_contains_for_test(markdown, "ExtensionLevel: 5")
      @test.assert_eq(markdown_fixture_raw_control_count_for_test(markdown), 0)
      @test.assert_eq(markdown_fixture_replacement_count_for_test(markdown), 6)
    }
  }
}

///|
async test "pdf_bytes_to_markdown extracts external full PDF reference fixture" {
  match
    markdown_optional_fixture_markdown_for_test(
      "markdown/external_fixtures/downloads/pdf_reference_iso32000_1_2008.pdf",
    ) {
    None => ()
    Some(markdown) => {
      markdown_fixture_assert_contains_for_test(markdown, "PDF 32000-1:2008")
      markdown_fixture_assert_contains_for_test(markdown, "Document management")
      markdown_fixture_assert_contains_for_test(
        markdown, "Portable document format",
      )
      markdown_fixture_assert_contains_for_test(markdown, "ISO 32000-1")
      markdown_fixture_assert_contains_for_test(markdown, "7 Syntax")
      markdown_fixture_assert_contains_for_test(markdown, "8 Graphics")
      markdown_fixture_assert_contains_for_test(markdown, "9 Text")
      markdown_fixture_assert_contains_for_test(
        markdown, "12 Interactive Features",
      )
      @test.assert_eq(markdown.length() > 2000000, true)
      @test.assert_eq(markdown_fixture_raw_control_count_for_test(markdown), 0)
      @test.assert_eq(markdown_fixture_replacement_count_for_test(markdown), 0)
    }
  }
}

///|
async test "pdf_bytes_to_markdown extracts external Unicode CJK chart fixture" {
  match
    markdown_optional_fixture_markdown_for_test(
      "markdown/external_fixtures/downloads/unicode_cjk_unified_ideographs_u4e00.pdf",
    ) {
    None => ()
    Some(markdown) => {
      markdown_fixture_assert_contains_for_test(
        markdown, "CJK Unified Ideographs",
      )
      markdown_fixture_assert_contains_for_test(markdown, "Range: 4E00")
      markdown_fixture_assert_contains_for_test(markdown, "9FFF")
      markdown_fixture_assert_contains_for_test(markdown, "一")
      markdown_fixture_assert_contains_for_test(markdown, "鿿")
      @test.assert_eq(markdown_fixture_raw_control_count_for_test(markdown), 0)
      @test.assert_eq(markdown_fixture_replacement_count_for_test(markdown), 0)
      @test.assert_eq(
        markdown_fixture_unique_cjk_unified_count_for_test(markdown),
        20963,
      )
    }
  }
}
