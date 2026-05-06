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
fn markdown_fixture_assert_contains_for_test(
  text : String,
  fragment : String,
) -> Unit raise {
  @test.assert_eq(text.contains(fragment), true)
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
