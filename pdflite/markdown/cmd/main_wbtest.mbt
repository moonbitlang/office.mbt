///|
async fn markdown_cmd_remove_if_exists_for_test(path : String) -> Unit {
  if @fs.exists(path) {
    @fs.remove(path)
  }
}

///|
fn markdown_cmd_repo_path_for_test(path : String) -> String {
  match @env.current_dir() {
    Some(current_dir) => current_dir + "/" + path
    None => path
  }
}

///|
fn markdown_cmd_output_path_for_test(name : String) -> String {
  let directory = match @env.current_dir() {
    Some(current_dir) => current_dir + "/_build/"
    None => "_build/"
  }
  directory +
  "pdflite_markdown_cmd_" +
  name +
  "_" +
  @env.now().to_string() +
  ".md"
}

///|
fn markdown_cmd_assert_contains_for_test(
  text : String,
  fragment : String,
) -> Unit raise {
  @test.assert_eq(text.contains(fragment), true)
}

///|
fn markdown_cmd_raw_control_count_for_test(text : String) -> Int {
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
async test "markdown command converts generated Latin fixture to UTF-8 file" {
  let input_path = markdown_cmd_repo_path_for_test(
    "markdown/fixtures/pandoc_latin.pdf",
  )
  let output_path = markdown_cmd_output_path_for_test("pandoc_latin")
  markdown_cmd_remove_if_exists_for_test(output_path)
  markdown_cmd_convert_file(input_path, output_path)
  let output = @utf8.decode_lossy(@fs.read_file(output_path).binary()[:])
  markdown_cmd_assert_contains_for_test(output, "# Page 1")
  markdown_cmd_assert_contains_for_test(output, "Pandoc Latin Fixture")
  markdown_cmd_assert_contains_for_test(
    output, "stable marker: alpha beta 123.",
  )
  markdown_cmd_remove_if_exists_for_test(output_path)
}

///|
async test "markdown command converts optional external Adobe supplement fixture" {
  let input_path = markdown_cmd_repo_path_for_test(
    "markdown/external_fixtures/downloads/adobe_supplement_iso32000_1.pdf",
  )
  if @fs.exists(input_path) {
    let output_path = markdown_cmd_output_path_for_test("adobe_supplement")
    markdown_cmd_remove_if_exists_for_test(output_path)
    markdown_cmd_convert_file(input_path, output_path)
    let output = @utf8.decode_lossy(@fs.read_file(output_path).binary()[:])
    markdown_cmd_assert_contains_for_test(output, "Adobe® Supplement to")
    markdown_cmd_assert_contains_for_test(output, "ISO 32000-1")
    markdown_cmd_assert_contains_for_test(output, "ExtensionLevel: 5")
    @test.assert_eq(markdown_cmd_raw_control_count_for_test(output), 0)
    markdown_cmd_remove_if_exists_for_test(output_path)
  }
}
