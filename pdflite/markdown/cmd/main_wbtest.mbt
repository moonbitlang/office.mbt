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
test "markdown command renders argparse help" {
  inspect(
    markdown_cmd_command().render_help(),
    content=(
      #|Usage: pdflite-markdown <input> <output>
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
test "markdown command parses required input and output paths" {
  let (input_path, output_path) = try! markdown_cmd_parse_args(argv=[
    "input.pdf", "output.md",
  ])
  @test.assert_eq(input_path, "input.pdf")
  @test.assert_eq(output_path, "output.md")
}

///|
test "markdown command reports missing positional arguments with argparse help" {
  try markdown_cmd_parse_args(argv=[]) catch {
    err =>
      inspect(
        err.to_string(),
        content=(
          #|error: 'input' requires at least 1 values but only 0 were provided
          #|
          #|Usage: pdflite-markdown <input> <output>
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
test "markdown command rejects extra positional arguments" {
  try markdown_cmd_parse_args(argv=["input.pdf", "output.md", "extra"]) catch {
    err => {
      let message = err.to_string()
      markdown_cmd_assert_contains_for_test(message, "unexpected value 'extra'")
      markdown_cmd_assert_contains_for_test(
        message, "Usage: pdflite-markdown <input> <output>",
      )
    }
  } noraise {
    _ => fail("expected argparse to reject extra paths")
  }
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
fn markdown_cmd_replacement_count_for_test(text : String) -> Int {
  let mut count = 0
  for char in text {
    if char.to_int() == 0xFFFD {
      count += 1
    }
  }
  count
}

///|
fn markdown_cmd_unique_cjk_unified_count_for_test(text : String) -> Int {
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
fn markdown_cmd_cpdf_source_manual_image_pdf_paths_for_test() -> Array[String] {
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
async test "markdown command converts generated Latin fixture to UTF-8 file" {
  let input_path = markdown_cmd_repo_path_for_test(
    "markdown/fixtures/pandoc_latin.pdf",
  )
  let output_path = markdown_cmd_output_path_for_test("pandoc_latin")
  markdown_cmd_remove_if_exists_for_test(output_path)
  markdown_cmd_convert_file(input_path, output_path)
  let output = @utf8.decode_lossy(@fs.read_file(output_path).binary())
  markdown_cmd_assert_contains_for_test(output, "# Page 1")
  markdown_cmd_assert_contains_for_test(output, "Pandoc Latin Fixture")
  markdown_cmd_assert_contains_for_test(
    output, "stable marker: alpha beta 123.",
  )
  markdown_cmd_remove_if_exists_for_test(output_path)
}

///|
async test "markdown command converts checked-in CamlPDF introduction fixture" {
  let input_path = markdown_cmd_repo_path_for_test(
    "fixtures/camlpdf/introduction_to_camlpdf.pdf",
  )
  let output_path = markdown_cmd_output_path_for_test("camlpdf_introduction")
  markdown_cmd_remove_if_exists_for_test(output_path)
  markdown_cmd_convert_file(input_path, output_path)
  let output = @utf8.decode_lossy(@fs.read_file(output_path).binary())
  markdown_cmd_assert_contains_for_test(
    output, "An Introduction to PDF with CamlPDF",
  )
  markdown_cmd_assert_contains_for_test(output, "Pdfread.pdf_of_file")
  markdown_cmd_assert_contains_for_test(output, "PDF is a directed graph")
  @test.assert_eq(markdown_cmd_raw_control_count_for_test(output), 0)
  @test.assert_eq(markdown_cmd_replacement_count_for_test(output), 0)
  markdown_cmd_remove_if_exists_for_test(output_path)
}

///|
async test "markdown command converts optional cpdf source manual fixture" {
  let input_path = markdown_cmd_repo_path_for_test(
    ".repos/cpdf-source/cpdfmanual.pdf",
  )
  if @fs.exists(input_path) {
    let output_path = markdown_cmd_output_path_for_test("cpdf_source_manual")
    markdown_cmd_remove_if_exists_for_test(output_path)
    markdown_cmd_convert_file(input_path, output_path)
    let output = @utf8.decode_lossy(@fs.read_file(output_path).binary())
    markdown_cmd_assert_contains_for_test(output, "Coherent PDF")
    markdown_cmd_assert_contains_for_test(output, "Command Line Tools")
    markdown_cmd_assert_contains_for_test(output, "Chapter 15: PDF and JSON")
    markdown_cmd_assert_contains_for_test(output, "Accessible PDFs with PDF/UA")
    @test.assert_eq(output.length() > 200000, true)
    @test.assert_eq(markdown_cmd_replacement_count_for_test(output), 0)
    markdown_cmd_remove_if_exists_for_test(output_path)
  }
}

///|
async test "markdown command converts optional cpdf source manual image PDF corpus" {
  let mut checked = 0
  let mut textful = 0
  for path in markdown_cmd_cpdf_source_manual_image_pdf_paths_for_test() {
    let input_path = markdown_cmd_repo_path_for_test(path)
    if @fs.exists(input_path) {
      checked += 1
      let output_path = markdown_cmd_output_path_for_test(
        "cpdf_source_manual_image_" + checked.to_string(),
      )
      markdown_cmd_remove_if_exists_for_test(output_path)
      markdown_cmd_convert_file(input_path, output_path)
      let output = @utf8.decode_lossy(@fs.read_file(output_path).binary())
      markdown_cmd_assert_contains_for_test(output, "# Page 1")
      @test.assert_eq(
        markdown_cmd_raw_control_count_for_test(output),
        0,
        msg=path,
      )
      @test.assert_eq(
        markdown_cmd_replacement_count_for_test(output),
        0,
        msg=path,
      )
      if output != "# Page 1\n\n\n" {
        textful += 1
      }
      markdown_cmd_remove_if_exists_for_test(output_path)
    }
  }
  if checked > 0 {
    @test.assert_eq(
      checked,
      markdown_cmd_cpdf_source_manual_image_pdf_paths_for_test().length(),
    )
    @test.assert_eq(textful > 0, true)
  }
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
    let output = @utf8.decode_lossy(@fs.read_file(output_path).binary())
    markdown_cmd_assert_contains_for_test(output, "Adobe® Supplement to")
    markdown_cmd_assert_contains_for_test(output, "ISO 32000-1")
    markdown_cmd_assert_contains_for_test(output, "ExtensionLevel: 5")
    @test.assert_eq(markdown_cmd_raw_control_count_for_test(output), 0)
    markdown_cmd_remove_if_exists_for_test(output_path)
  }
}

///|
async test "markdown command converts optional external Unicode CJK chart fixture" {
  let input_path = markdown_cmd_repo_path_for_test(
    "markdown/external_fixtures/downloads/unicode_cjk_unified_ideographs_u4e00.pdf",
  )
  if @fs.exists(input_path) {
    let output_path = markdown_cmd_output_path_for_test("unicode_cjk_chart")
    markdown_cmd_remove_if_exists_for_test(output_path)
    markdown_cmd_convert_file(input_path, output_path)
    let output = @utf8.decode_lossy(@fs.read_file(output_path).binary())
    markdown_cmd_assert_contains_for_test(output, "CJK Unified Ideographs")
    markdown_cmd_assert_contains_for_test(output, "Range: 4E00")
    markdown_cmd_assert_contains_for_test(output, "9FFF")
    markdown_cmd_assert_contains_for_test(output, "一")
    markdown_cmd_assert_contains_for_test(output, "鿿")
    @test.assert_eq(markdown_cmd_raw_control_count_for_test(output), 0)
    @test.assert_eq(markdown_cmd_replacement_count_for_test(output), 0)
    @test.assert_eq(
      markdown_cmd_unique_cjk_unified_count_for_test(output),
      20963,
    )
    markdown_cmd_remove_if_exists_for_test(output_path)
  }
}
