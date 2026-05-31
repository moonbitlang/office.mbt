///|
fn decode_cli_fixture(encoded : String) -> Bytes {
  try! @base64.decode(encoded)
}

///|
fn cli_single_paragraph_docx() -> Bytes {
  decode_cli_fixture(
    "UEsDBBQAAAAIANUFwVzXeYTq8QAAALgBAAATAAAAW0NvbnRlbnRfVHlwZXNdLnhtbH2QzU7DMBCE730Ky9cqccoBIZSkB36OwKE8wMreJFb9J69b2rdn00KREOVozXwz62nXB+/EHjPZGDq5qhspMOhobBg7+b55ru6koALBgIsBO3lEkut+0W6OCUkwHKiTUynpXinSE3qgOiYMrAwxeyj8zKNKoLcworppmlulYygYSlXmDNkvhGgfcYCdK+LpwMr5loyOpHg4e+e6TkJKzmoorKt9ML+Kqq+SmsmThyabaMkGqa6VzOL1jh/0lSfK1qB4g1xewLNRfcRslIl65xmu/0/649o4DFbjhZ/TUo4aiXh77+qL4sGG71+06jR8/wlQSwMEFAAAAAgA1QXBXCAbhuqyAAAALgEAAAsAAABfcmVscy8ucmVsc43Puw6CMBQG4J2naM4uBQdjDIXFmLAafICmPZRGeklbL7y9HRzEODie23fyN93TzOSOIWpnGdRlBQStcFJbxeAynDZ7IDFxK/nsLDJYMELXFs0ZZ57yTZy0jyQjNjKYUvIHSqOY0PBYOo82T0YXDE+5DIp6Lq5cId1W1Y6GTwPagpAVS3rJIPSyBjIsHv/h3ThqgUcnbgZt+vHlayPLPChMDB4uSCrf7TKzQHNKuorZvgBQSwMEFAAAAAgA1QXBXEhRSH2qAAAA5QAAABEAAAB3b3JkL2RvY3VtZW50LnhtbDWOMQ7CMAxF957Cyg4pDAhVbdg4AYg5NAYiGjtyAoXbk1Riebb1rWf3h0+Y4I2SPNOgNutWAdLIztN9UOfTcbVXkLIlZycmHNQXkzqYpp87x+MrIGUoBkrdPKhHzrHTOo0PDDatOSKV7MYSbC6j3PXM4qLwiCmVA2HS27bd6WA9KdMAFOuV3deUGiukIpuLnZ5lHZjAh8iS0YH10usaVsrCuHARNLX7P2h+UEsBAhQDFAAAAAgA1QXBXNd5hOrxAAAAuAEAABMAAAAAAAAAAAAAAIABAAAAAFtDb250ZW50X1R5cGVzXS54bWxQSwECFAMUAAAACADVBcFcIBuG6rIAAAAuAQAACwAAAAAAAAAAAAAAgAEiAQAAX3JlbHMvLnJlbHNQSwECFAMUAAAACADVBcFcSFFIfaoAAADlAAAAEQAAAAAAAAAAAAAAgAH9AQAAd29yZC9kb2N1bWVudC54bWxQSwUGAAAAAAMAAwC5AAAA1gIAAAAA",
  )
}

///|
fn ensure_test_dir(path : String) -> Unit {
  @fs.create_dir(path) catch {
    IOError(_) => ()
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

///|
test "CLI conversion writes output file and applies style map" {
  let dir = "_build/cli-main-output-file"
  ensure_test_dir(dir)
  let input_path = join_path(dir, "input.docx")
  let style_map_path = join_path(dir, "style-map")
  let output_file = join_path(dir, "output.html")
  @fs.write_bytes_to_file(input_path, cli_single_paragraph_docx())
  @fs.write_string_to_file(style_map_path, "p => span:fresh")
  run_conversion({
    input_path,
    output_path: Some(output_file),
    output_dir: None,
    style_map_path: Some(style_map_path),
    output_format: Html,
    pretty_print: false,
  })
  inspect(
    @fs.read_file_to_string(output_file),
    content="<span>Walking on imported air</span>",
  )
}

///|
test "CLI conversion writes markdown output inside output dir" {
  let dir = "_build/cli-main-output-dir-markdown"
  ensure_test_dir(dir)
  let input_path = join_path(dir, "input.docx")
  @fs.write_bytes_to_file(input_path, cli_single_paragraph_docx())
  run_conversion({
    input_path,
    output_path: None,
    output_dir: Some(dir),
    style_map_path: None,
    output_format: Markdown,
    pretty_print: false,
  })
  inspect(
    @fs.read_file_to_string(join_path(dir, "input.md")),
    content="Walking on imported air\n\n",
  )
}
