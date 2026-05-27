///|
fn pdflite_cmd_repo_path_for_test(path : String) -> String {
  match @env.current_dir() {
    Some(current_dir) => current_dir + "/" + path
    None => path
  }
}

///|
fn pdflite_cmd_output_path_for_test(name : String) -> String {
  let directory = match @env.current_dir() {
    Some(current_dir) => current_dir + "/_build/"
    None => "_build/"
  }
  directory + "pdflite_cmd_" + name + "_" + @env.now().to_string() + ".pdf"
}

///|
async fn pdflite_cmd_remove_if_exists_for_test(path : String) -> Unit {
  if @fs.exists(path) {
    @fs.remove(path)
  }
}

///|
test "pdflite command renders argparse help" {
  inspect(
    pdflite_cmd_command().render_help(),
    content=(
      #|Usage: pdflite <command>
      #|
      #|Inspect and rewrite PDF files.
      #|
      #|Commands:
      #|  info     Print basic metadata for one PDF file.
      #|  rewrite  Parse and write a PDF file.
      #|
      #|Options:
      #|  -h, --help     Show help information.
      #|  -V, --version  Show version information.
      #|
    ),
  )
}

///|
test "pdflite command parses info subcommand" {
  let parsed = try! pdflite_cmd_parse_args(["info", "input.pdf"])
  guard parsed is PdfliteCmdInfo(input_path) else {
    fail("expected info subcommand")
  }
  @test.assert_eq(input_path, "input.pdf")
}

///|
test "pdflite command parses rewrite subcommand" {
  let parsed = try! pdflite_cmd_parse_args([
    "rewrite", "input.pdf", "output.pdf",
  ])
  guard parsed is PdfliteCmdRewrite(input_path, output_path) else {
    fail("expected rewrite subcommand")
  }
  @test.assert_eq(input_path, "input.pdf")
  @test.assert_eq(output_path, "output.pdf")
}

///|
test "pdflite command reports missing subcommand with argparse help" {
  try pdflite_cmd_parse_args([]) catch {
    err =>
      inspect(
        err.to_string(),
        content=(
          #|error: the following required argument was not provided: 'subcommand'
          #|
          #|Usage: pdflite <command>
          #|
          #|Inspect and rewrite PDF files.
          #|
          #|Commands:
          #|  info     Print basic metadata for one PDF file.
          #|  rewrite  Parse and write a PDF file.
          #|
          #|Options:
          #|  -h, --help     Show help information.
          #|  -V, --version  Show version information.
          #|
        ),
      )
  } noraise {
    _ => fail("expected argparse to require a subcommand")
  }
}

///|
#cfg(target="native")
async test "pdflite info reports fixture metadata" {
  let input = pdflite_cmd_repo_path_for_test("fixtures/camlpdf/logo.pdf")
  let document = try! @pdflite.pdf_read_document_from_bytes(
    @fs.read_file(input).binary(),
  )
  let text = pdflite_cmd_info_text(input, document, try! document.endpage())
  @test.assert_eq(text.contains("version: 1.4\n"), true)
  @test.assert_eq(text.contains("pages: 1\n"), true)
  @test.assert_eq(text.contains("encrypted: false\n"), true)
}

///|
#cfg(target="native")
async test "pdflite rewrite creates a readable PDF" {
  let input = pdflite_cmd_repo_path_for_test("fixtures/camlpdf/logo.pdf")
  let output = pdflite_cmd_output_path_for_test("rewrite")
  pdflite_cmd_remove_if_exists_for_test(output)
  let result = pdflite_cmd_rewrite_file(input, output)
  guard result is Ok(_) else { fail("expected rewrite to succeed") }
  let rewritten = try! @pdflite.pdf_read_document_from_bytes(
    @fs.read_file(output).binary(),
  )
  inspect(try! rewritten.endpage(), content="1")
  pdflite_cmd_remove_if_exists_for_test(output)
}
