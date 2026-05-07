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
    ".repos/introduction_to_camlpdf.pdf",
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
async test "pdf_bytes_to_markdown tolerates checked-in CamlPDF logo fixture" {
  let markdown = markdown_fixture_markdown_for_test(".repos/logo.pdf")
  @test.assert_eq(markdown, "# Page 1\n\n\n")
  @test.assert_eq(markdown_fixture_raw_control_count_for_test(markdown), 0)
  @test.assert_eq(markdown_fixture_replacement_count_for_test(markdown), 0)
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
