///|
test "CLI parser accepts default stdout HTML conversion" {
  debug_inspect(
    parse_cli_args(["docx2html", "input.docx"]),
    content=(
      #|Run(
      #|  {
      #|    input_path: "input.docx",
      #|    output_path: None,
      #|    output_dir: None,
      #|    style_map_path: None,
      #|    output_format: Html,
      #|    pretty_print: false,
      #|  },
      #|)
    ),
  )
}

///|
test "CLI parser accepts Mammoth-style options" {
  debug_inspect(
    parse_cli_args([
      "docx2html", "--style-map", "style-map", "--output-format=markdown", "--pretty-print",
      "input.docx", "output.md",
    ]),
    content=(
      #|Run(
      #|  {
      #|    input_path: "input.docx",
      #|    output_path: Some("output.md"),
      #|    output_dir: None,
      #|    style_map_path: Some("style-map"),
      #|    output_format: Markdown,
      #|    pretty_print: true,
      #|  },
      #|)
    ),
  )
}

///|
test "CLI parser rejects output path with output dir" {
  try
    parse_cli_args([
      "docx2html", "--output-dir", "out", "input.docx", "output.html",
    ])
  catch {
    CliError(message) =>
      inspect(
        message.has_prefix(
          "output path and --output-dir are mutually exclusive",
        ),
        content="true",
      )
  } noraise {
    _ => fail("expected CLI error")
  }
}

///|
test "CLI output-dir helpers match Mammoth naming" {
  let options = CliOptions::{
    input_path: "fixtures/single-paragraph.docx",
    output_path: None,
    output_dir: Some("out"),
    style_map_path: None,
    output_format: Html,
    pretty_print: false,
  }
  debug_inspect(
    output_path(options),
    content="Some(\"out/single-paragraph.html\")",
  )
  inspect(image_extension("image/png"), content="png")
  inspect(input_basename_without_docx("C:\\tmp\\sample.docx"), content="sample")
}
