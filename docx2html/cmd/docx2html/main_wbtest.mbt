///|
fn expect_cli_error(args : Array[String], prefix : String) -> Unit raise {
  try parse_cli_args(args) catch {
    @cli.CliError(message) =>
      inspect(message.has_prefix(prefix), content="true")
  } noraise {
    _ => fail("expected CLI error")
  }
}

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
test "CLI parser accepts help without input path" {
  debug_inspect(parse_cli_args(["docx2html", "--help"]), content="Help")
  debug_inspect(parse_cli_args(["docx2html", "-h"]), content="Help")
  debug_inspect(
    parse_cli_args(["docx2html", "input.docx", "--help"]),
    content="Help",
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
test "CLI parser accepts alternate option value forms" {
  debug_inspect(
    parse_cli_args([
      "docx2html", "--style-map=style-map", "--output-format", "markdown", "--output-dir=out",
      "input.docx",
    ]),
    content=(
      #|Run(
      #|  {
      #|    input_path: "input.docx",
      #|    output_path: None,
      #|    output_dir: Some("out"),
      #|    style_map_path: Some("style-map"),
      #|    output_format: Markdown,
      #|    pretty_print: false,
      #|  },
      #|)
    ),
  )
}

///|
test "CLI parser rejects malformed arguments" {
  expect_cli_error(["docx2html"], "error: 'input' requires at least 1 values")
  expect_cli_error(
    ["docx2html", "--style-map"],
    "error: a value is required for '--style-map'",
  )
  expect_cli_error(
    ["docx2html", "--style-map", "--help", "input.docx"],
    "error: a value is required for '--style-map'",
  )
  expect_cli_error(
    ["docx2html", "--output-dir"],
    "error: a value is required for '--output-dir'",
  )
  expect_cli_error(
    ["docx2html", "--output-format"],
    "error: a value is required for '--output-format'",
  )
  expect_cli_error(
    ["docx2html", "--output-format=pdf", "input.docx"],
    "Unsupported output format: pdf",
  )
  expect_cli_error(
    ["docx2html", "--wat", "input.docx"],
    "error: unexpected argument '--wat' found",
  )
  expect_cli_error(
    ["docx2html", "input.docx", "one.html", "two.html"],
    "error: unexpected value 'two.html' for '<output>' found",
  )
}

///|
test "CLI parser rejects output path with output dir" {
  try
    parse_cli_args([
      "docx2html", "--output-dir", "out", "input.docx", "output.html",
    ])
  catch {
    @cli.CliError(message) =>
      inspect(
        message.has_prefix(
          "error: output path and --output-dir are mutually exclusive",
        ),
        content="true",
      )
  } noraise {
    _ => fail("expected CLI error")
  }
}
