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
  let marker = @ascii.encode("startxref\n")
  let marker_position = markdown_fixture_find_last_bytes_for_test(bytes, marker)
  if marker_position < 0 {
    fail("expected startxref marker")
  }
  let number_start = marker_position + marker.length()
  let mut number_end = number_start
  while number_end < bytes.length() && bytes[number_end] != b'\n' {
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
