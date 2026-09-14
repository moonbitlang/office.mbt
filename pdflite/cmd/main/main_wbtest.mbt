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
      #|  extract   Extract selected pages into a new PDF file.
      #|  info      Print basic metadata for one PDF file.
      #|  merge     Merge PDF files in the supplied order.
      #|  rewrite   Parse, write, and verify a PDF file.
      #|  validate  Parse and round-trip a PDF without writing a file.
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
  guard parsed is PdfliteCmdInfo(input_path, json) else {
    fail("expected info subcommand")
  }
  @test.assert_eq(input_path, "input.pdf")
  @test.assert_eq(json, false)
}

///|
test "pdflite command parses info json flag" {
  let parsed = try! pdflite_cmd_parse_args(["info", "--json", "input.pdf"])
  guard parsed is PdfliteCmdInfo(input_path, json) else {
    fail("expected info subcommand")
  }
  @test.assert_eq(input_path, "input.pdf")
  @test.assert_eq(json, true)
}

///|
test "pdflite command parses merge subcommand in input order" {
  let parsed = try! pdflite_cmd_parse_args([
    "merge", "output.pdf", "first.pdf", "second.pdf", "third.pdf",
  ])
  guard parsed is PdfliteCmdMerge(output_path, input_paths) else {
    fail("expected merge subcommand")
  }
  @test.assert_eq(output_path, "output.pdf")
  @test.assert_eq(input_paths, ["first.pdf", "second.pdf", "third.pdf"])
}

///|
test "pdflite command requires at least two merge inputs" {
  @test.assert_raise(() => {
    ignore(pdflite_cmd_parse_args(["merge", "output.pdf", "input.pdf"]))
  })
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
test "pdflite command parses validate subcommand" {
  let parsed = try! pdflite_cmd_parse_args(["validate", "input.pdf"])
  guard parsed is PdfliteCmdValidate(input_path) else {
    fail("expected validate subcommand")
  }
  @test.assert_eq(input_path, "input.pdf")
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
          #|  extract   Extract selected pages into a new PDF file.
          #|  info      Print basic metadata for one PDF file.
          #|  merge     Merge PDF files in the supplied order.
          #|  rewrite   Parse, write, and verify a PDF file.
          #|  validate  Parse and round-trip a PDF without writing a file.
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
  let report = match pdflite_cmd_info_report(input, document) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let text = pdflite_cmd_info_text(report)
  @test.assert_eq(text.contains("version: 1.4\n"), true)
  @test.assert_eq(text.contains("pages: 1\n"), true)
  @test.assert_eq(text.contains("encrypted: false\n"), true)
}

///|
#cfg(target="native")
async test "pdflite info json reports fixture metadata" {
  let input = pdflite_cmd_repo_path_for_test("fixtures/camlpdf/logo.pdf")
  let document = try! @pdflite.pdf_read_document_from_bytes(
    @fs.read_file(input).binary(),
  )
  let report = match pdflite_cmd_info_report(input, document) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let text = pdflite_cmd_info_json_text(report)
  let json = try! @json.parse(text)
  guard json is Object(entries) else { fail("expected JSON object") }
  @test.assert_eq(entries.get("version"), Some(Json::string("1.4")))
  @test.assert_eq(entries.get("pages"), Some(Json::number(1, repr="1")))
  @test.assert_eq(entries.get("encrypted"), Some(Json::boolean(false)))
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

///|
#cfg(target="native")
async test "pdflite merge preserves input page order" {
  let first_path = pdflite_cmd_output_path_for_test("merge_first")
  let second_path = pdflite_cmd_output_path_for_test("merge_second")
  let output_path = pdflite_cmd_output_path_for_test("merge_output")
  pdflite_cmd_remove_if_exists_for_test(first_path)
  pdflite_cmd_remove_if_exists_for_test(second_path)
  pdflite_cmd_remove_if_exists_for_test(output_path)
  let first = try! @pdflite.pdf_blank_document(100.0, 200.0, 1)
  let second = try! @pdflite.pdf_blank_document(300.0, 400.0, 2)
  @fs.write_file(
    first_path,
    try! @pdflite.pdf_write_document(first),
    create_mode=CreateOrTruncate,
    permission=0o644,
  )
  @fs.write_file(
    second_path,
    try! @pdflite.pdf_write_document(second),
    create_mode=CreateOrTruncate,
    permission=0o644,
  )
  let first_pages = try! (try! @pdflite.pdf_read_document_from_bytes(
    @fs.read_file(first_path).binary(),
  )).pages_of_pagetree()
  let second_pages = try! (try! @pdflite.pdf_read_document_from_bytes(
    @fs.read_file(second_path).binary(),
  )).pages_of_pagetree()
  let result = pdflite_cmd_merge_files(output_path, [second_path, first_path])
  guard result is Ok(_) else { fail("expected merge to succeed") }
  let merged = try! @pdflite.pdf_read_document_from_bytes(
    @fs.read_file(output_path).binary(),
  )
  let merged_pages = try! merged.pages_of_pagetree()
  @test.assert_eq(merged_pages.length(), 3)
  @test.assert_eq(merged_pages[0].mediabox, second_pages[0].mediabox)
  @test.assert_eq(merged_pages[1].mediabox, second_pages[1].mediabox)
  @test.assert_eq(merged_pages[2].mediabox, first_pages[0].mediabox)
  pdflite_cmd_remove_if_exists_for_test(first_path)
  pdflite_cmd_remove_if_exists_for_test(second_path)
  pdflite_cmd_remove_if_exists_for_test(output_path)
}

///|
#cfg(target="native")
async test "pdflite validate checks rewrite bytes" {
  let input = pdflite_cmd_repo_path_for_test("fixtures/camlpdf/logo.pdf")
  let document = match pdflite_cmd_read_document(input) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let output = match pdflite_cmd_write_document_bytes(document, input) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let result = pdflite_cmd_verify_rewritten_bytes(output, input)
  guard result is Ok(_) else { fail("expected rewritten bytes to validate") }
}
