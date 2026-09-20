///|
async fn pdf2md_remove_if_exists_for_test(path : String) -> Unit {
  if @fs.exists(path) {
    @fs.remove(path)
  }
}

///|
fn pdf2md_repo_path_for_test(path : String) -> String {
  match @env.current_dir() {
    Some(current_dir) => current_dir + "/" + path
    None => path
  }
}

///|
fn pdf2md_output_path_for_test(name : String) -> String {
  let directory = match @env.current_dir() {
    Some(current_dir) => current_dir + "/_build/"
    None => "_build/"
  }
  directory + "pdf2md_" + name + "_" + @env.now().to_string() + ".md"
}

///|
async fn pdf2md_ensure_output_dir_for_test() -> Unit {
  let directory = match @env.current_dir() {
    Some(current_dir) => current_dir + "/_build/"
    None => "_build/"
  }
  @fs.mkdir(directory, permission=0o755, recursive=true) catch {
    _ => ()
  }
}

///|
fn pdf2md_assert_contains_for_test(
  text : String,
  fragment : String,
) -> Unit raise {
  @test.assert_eq(text.contains(fragment), true)
}

///|
test "pdf2md renders argparse help" {
  inspect(
    pdf2md_command().render_help(),
    content=(
      #|Usage: pdf2md <input> <output>
      #|
      #|Extract Markdown text from a PDF file.
      #|
      #|Arguments:
      #|  input   Input PDF path.
      #|  output  Output Markdown path.
      #|
      #|Options:
      #|  -h, --help  Show help information.
      #|
    ),
  )
}

///|
test "pdf2md parses required input and output paths" {
  let (input_path, output_path) = try! pdf2md_parse_args([
    "input.pdf", "output.md",
  ])
  @test.assert_eq(input_path, "input.pdf")
  @test.assert_eq(output_path, "output.md")
}

///|
test "pdf2md reports missing positional arguments with argparse help" {
  try pdf2md_parse_args([]) catch {
    err =>
      inspect(
        err.to_string(),
        content=(
          #|error: 'input' requires at least 1 values but only 0 were provided
          #|
          #|Usage: pdf2md <input> <output>
          #|
          #|Extract Markdown text from a PDF file.
          #|
          #|Arguments:
          #|  input   Input PDF path.
          #|  output  Output Markdown path.
          #|
          #|Options:
          #|  -h, --help  Show help information.
          #|
        ),
      )
  } noraise {
    _ => fail("expected argparse to reject missing paths")
  }
}

///|
test "pdf2md rejects extra positional arguments" {
  try pdf2md_parse_args(["input.pdf", "output.md", "extra"]) catch {
    err => {
      let message = err.to_string()
      pdf2md_assert_contains_for_test(message, "unexpected value 'extra'")
      pdf2md_assert_contains_for_test(message, "Usage: pdf2md <input> <output>")
    }
  } noraise {
    _ => fail("expected argparse to reject extra paths")
  }
}

///|
async test "pdf2md converts a checked-in PDF fixture to a Markdown file" {
  let input = pdf2md_repo_path_for_test(
    "../pdflite/markdown/fixtures/pandoc_latin.pdf",
  )
  let output = pdf2md_output_path_for_test("latin")
  pdf2md_ensure_output_dir_for_test()
  pdf2md_remove_if_exists_for_test(output)
  pdf2md_convert_file(input, output)
  let text = @utf8.decode_lossy(@fs.read_file(output).binary())
  pdf2md_assert_contains_for_test(text, "Hello from Pandoc.")
  pdf2md_remove_if_exists_for_test(output)
}
