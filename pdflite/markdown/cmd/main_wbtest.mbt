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
async test "markdown command converts generated Latin fixture to UTF-8 file" {
  let input_path = markdown_cmd_repo_path_for_test(
    "markdown/fixtures/pandoc_latin.pdf",
  )
  let output_path = markdown_cmd_output_path_for_test("pandoc_latin")
  markdown_cmd_remove_if_exists_for_test(output_path)
  markdown_cmd_convert_file(input_path, output_path)
  let output = @utf8.decode_lossy(@fs.read_file(output_path).binary()[:])
  @test.assert_eq(output.contains("# Page 1"), true)
  @test.assert_eq(output.contains("Pandoc Latin Fixture"), true)
  @test.assert_eq(output.contains("stable marker: alpha beta 123."), true)
  markdown_cmd_remove_if_exists_for_test(output_path)
}
