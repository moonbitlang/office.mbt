///|
fn decode_cli_fixture(encoded : String) -> Bytes {
  try! @base64.decode(encoded, ignore_whitespace=true)
}

///|
fn cli_single_paragraph_docx() -> Bytes {
  decode_cli_fixture(
    "UEsDBBQAAAAIANUFwVzXeYTq8QAAALgBAAATAAAAW0NvbnRlbnRfVHlwZXNdLnhtbH2QzU7DMBCE730Ky9cqccoBIZSkB36OwKE8wMreJFb9J69b2rdn00KREOVozXwz62nXB+/EHjPZGDq5qhspMOhobBg7+b55ru6koALBgIsBO3lEkut+0W6OCUkwHKiTUynpXinSE3qgOiYMrAwxeyj8zKNKoLcworppmlulYygYSlXmDNkvhGgfcYCdK+LpwMr5loyOpHg4e+e6TkJKzmoorKt9ML+Kqq+SmsmThyabaMkGqa6VzOL1jh/0lSfK1qB4g1xewLNRfcRslIl65xmu/0/649o4DFbjhZ/TUo4aiXh77+qL4sGG71+06jR8/wlQSwMEFAAAAAgA1QXBXCAbhuqyAAAALgEAAAsAAABfcmVscy8ucmVsc43Puw6CMBQG4J2naM4uBQdjDIXFmLAafICmPZRGeklbL7y9HRzEODie23fyN93TzOSOIWpnGdRlBQStcFJbxeAynDZ7IDFxK/nsLDJYMELXFs0ZZ57yTZy0jyQjNjKYUvIHSqOY0PBYOo82T0YXDE+5DIp6Lq5cId1W1Y6GTwPagpAVS3rJIPSyBjIsHv/h3ThqgUcnbgZt+vHlayPLPChMDB4uSCrf7TKzQHNKuorZvgBQSwMEFAAAAAgA1QXBXEhRSH2qAAAA5QAAABEAAAB3b3JkL2RvY3VtZW50LnhtbDWOMQ7CMAxF957Cyg4pDAhVbdg4AYg5NAYiGjtyAoXbk1Riebb1rWf3h0+Y4I2SPNOgNutWAdLIztN9UOfTcbVXkLIlZycmHNQXkzqYpp87x+MrIGUoBkrdPKhHzrHTOo0PDDatOSKV7MYSbC6j3PXM4qLwiCmVA2HS27bd6WA9KdMAFOuV3deUGiukIpuLnZ5lHZjAh8iS0YH10usaVsrCuHARNLX7P2h+UEsBAhQDFAAAAAgA1QXBXNd5hOrxAAAAuAEAABMAAAAAAAAAAAAAAIABAAAAAFtDb250ZW50X1R5cGVzXS54bWxQSwECFAMUAAAACADVBcFcIBuG6rIAAAAuAQAACwAAAAAAAAAAAAAAgAEiAQAAX3JlbHMvLnJlbHNQSwECFAMUAAAACADVBcFcSFFIfaoAAADlAAAAEQAAAAAAAAAAAAAAgAH9AQAAd29yZC9kb2N1bWVudC54bWxQSwUGAAAAAAMAAwC5AAAA1gIAAAAA",
  )
}

///|
fn cli_tiny_picture_docx() -> Bytes {
  decode_cli_fixture(
    (
      #|UEsDBBQAAAAIAMsKwVyY9I3b6wAAAM4BAAATABwAW0NvbnRlbnRfVHlwZXNdLnhtbFVUCQADTW4c
      #|ak1uHGp1eAsAAQT1AQAABBQAAAB9kc1OwzAQhF/F8hXFGzgghJL0wM8ROJQHsJxNYtV/8rqlvD3r
      #|FnqoWo7emdlP4+1We+/EDjPZGHp5q1opMJg42jD38nP92jzI1dCtvxOSYGugXi6lpEcAMgt6TSom
      #|DKxMMXtd+JlnSNps9Ixw17b3YGIoGEpT6g45dM846a0r4mXP4yM2oyMpno7GyuqlTslZowvrsAvj
      #|GaX5JShOHjy02EQ3bJBwkVCV64DruRTms5z1tVmdc+Kdfy7bEcWHzuVNe9bhK+YRxmi2njPqf/CF
      #|ZnGarMFTvm5LORok4pN4p06K1zb8NYbDgYYfUEsDBAoAAAAAAMsKwVwAAAAAAAAAAAAAAAAGABwA
      #|X3JlbHMvVVQJAANNbhxqTW4canV4CwABBPUBAAAEFAAAAFBLAwQUAAAACADLCsFcNlfe3KIAAAAY
      #|AQAACwAcAF9yZWxzLy5yZWxzVVQJAANNbhxqTW4canV4CwABBPUBAAAEFAAAAI3POw7CMAwG4KtE
      #|3qkLA0KoaReE1BWVA0SJm0Y0DyXhdXsyMFDEwGj792e56R52ZjeKyXjHYV3VwMhJr4zTHM7DcbWD
      #|rm1ONItcEmkyIbGy4hKHKeewR0xyIitS5QO5Mhl9tCKXMmoMQl6EJtzU9RbjpwFLk/WKQ+zVGtjw
      #|DPSP7cfRSDp4ebXk8o8TX4kii6gpc7j7qFC921VhAdsGFy+2L1BLAwQKAAAAAADLCsFcAAAAAAAA
      #|AAAAAAAABQAcAHdvcmQvVVQJAANNbhxqTW4canV4CwABBPUBAAAEFAAAAFBLAwQUAAAACADLCsFc
      #|RcaE0wUBAACAAgAAEQAcAHdvcmQvZG9jdW1lbnQueG1sVVQJAANNbhxqTW4canV4CwABBPUBAAAE
      #|FAAAAJ2SzW7DIAyAXyXivjrrYZqiJL1ElXbfHoCAkyDxJ0OX7e1HkmajO1W9gJHNx2egPn0ZXXwi
      #|BeVsw54PJSvQCieVHRv28X5+emWntp4r6cTFoI1Fqrehmhs2xegrgCAmNDwcnEebcoMjw2Na0giz
      #|I+nJCQwh4YyGY1m+gOHKsiuG7sG4YVACu6vABiHUPCblMCkfdtrs78FJ4nOmcyvZbcmdyB8A5v15
      #|JR4gpF3xQsiWe++d/F5mvwy0vsRWnEJfKauVxbbm1UjcT0pkYccjb+vEWiy2oNfKn5XWS9USF1Sh
      #|6VE2jN4MH5FBW8NtIfwC4B8ZskMhc4FMEVZnWPVhbwb+flP7A1BLAwQKAAAAAADLCsFcAAAAAAAA
      #|AAAAAAAACwAcAHdvcmQvX3JlbHMvVVQJAANNbhxqTW4canV4CwABBPUBAAAEFAAAAFBLAwQUAAAA
      #|CADLCsFc0L0iWaMAAAAQAQAAHAAcAHdvcmQvX3JlbHMvZG9jdW1lbnQueG1sLnJlbHNVVAkAA01u
      #|HGpNbhxqdXgLAAEE9QEAAAQUAAAAjY/LCsIwEEV/JczeTOtCRJp2I0K3Uj8gpNM02DxIoujfG9CF
      #|BRcuZ+bcM9yme9iF3Skm452AmlfAyCk/GqcFXIbTZg9d25xpkbkQaTYhsRJxScCcczggJjWTlYn7
      #|QK5cJh+tzGWMGoNUV6kJt1W1w/jtgLWT9aOA2NsCAxuegf6x+2kyio5e3Sy5/OMJmo9QRk1ZgKXR
      #|yPey5sFpwLbBVbX2BVBLAwQKAAAAAADLCsFcAAAAAAAAAAAAAAAACwAcAHdvcmQvbWVkaWEvVVQJ
      #|AANNbhxqTW4canV4CwABBPUBAAAEFAAAAFBLAwQUAAAACADLCsFc8eIJrWUAAABuAAAAFQAcAHdv
      #|cmQvbWVkaWEvaW1hZ2UxLnBuZ1VUCQADTW4cak1uHGp1eAsAAQT1AQAABBQAAADrDPBz5+WS4mJg
      #|YOD19HAJAtIgNhcHE5BkCoh4BaQYi4PcnRjWnZN5CeRwFnhEFjMw8O0DYcZXThsPAAWFPV0cQzSC
      #|k/+cb+A3eDg1VWLlJQZHHUbho3bxvUBpBk9XP5d1TglNAFBLAQIeAxQAAAAIAMsKwVyY9I3b6wAA
      #|AM4BAAATABgAAAAAAAEAAACkgQAAAABbQ29udGVudF9UeXBlc10ueG1sVVQFAANNbhxqdXgLAAEE
      #|9QEAAAQUAAAAUEsBAh4DCgAAAAAAywrBXAAAAAAAAAAAAAAAAAYAGAAAAAAAAAAQAO1BOAEAAF9y
      #|ZWxzL1VUBQADTW4canV4CwABBPUBAAAEFAAAAFBLAQIeAxQAAAAIAMsKwVw2V97cogAAABgBAAAL
      #|ABgAAAAAAAEAAACkgXgBAABfcmVscy8ucmVsc1VUBQADTW4canV4CwABBPUBAAAEFAAAAFBLAQIe
      #|AwoAAAAAAMsKwVwAAAAAAAAAAAAAAAAFABgAAAAAAAAAEADtQV8CAAB3b3JkL1VUBQADTW4canV4
      #|CwABBPUBAAAEFAAAAFBLAQIeAxQAAAAIAMsKwVxFxoTTBQEAAIACAAARABgAAAAAAAEAAACkgZ4C
      #|AAB3b3JkL2RvY3VtZW50LnhtbFVUBQADTW4canV4CwABBPUBAAAEFAAAAFBLAQIeAwoAAAAAAMsK
      #|wVwAAAAAAAAAAAAAAAALABgAAAAAAAAAEADtQe4DAAB3b3JkL19yZWxzL1VUBQADTW4canV4CwAB
      #|BPUBAAAEFAAAAFBLAQIeAxQAAAAIAMsKwVzQvSJZowAAABABAAAcABgAAAAAAAEAAACkgTMEAAB3
      #|b3JkL19yZWxzL2RvY3VtZW50LnhtbC5yZWxzVVQFAANNbhxqdXgLAAEE9QEAAAQUAAAAUEsBAh4D
      #|CgAAAAAAywrBXAAAAAAAAAAAAAAAAAsAGAAAAAAAAAAQAO1BLAUAAHdvcmQvbWVkaWEvVVQFAANN
      #|bhxqdXgLAAEE9QEAAAQUAAAAUEsBAh4DFAAAAAgAywrBXPHiCa1lAAAAbgAAABUAGAAAAAAAAAAA
      #|AKSBcQUAAHdvcmQvbWVkaWEvaW1hZ2UxLnBuZ1VUBQADTW4canV4CwABBPUBAAAEFAAAAFBLBQYA
      #|AAAACQAJAPcCAAAlBgAAAAA=
    ),
  )
}

///|
fn cli_tiny_picture_base64() -> String {
  "iVBORw0KGgoAAAANSUhEUgAAAAoAAAAKCAIAAAACUFjqAAAAAXNSR0IArs4c6QAAAAlwSFlzAAAOvgAADr4B6kKxwAAAABNJREFUKFNj/M+ADzDhlWUYqdIAQSwBE8U+X40AAAAASUVORK5CYII="
}

///|
fn ensure_test_dir(path : String) -> Unit {
  @fs.create_dir(path) catch {
    IOError(_) => ()
  }
}

///|
fn expect_cli_error(args : Array[String], prefix : String) -> Unit raise {
  try parse_cli_args(args) catch {
    CliError(message) => inspect(message.has_prefix(prefix), content="true")
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
  expect_cli_error(["docx2html"], "Usage: docx2html")
  expect_cli_error(
    ["docx2html", "--style-map"],
    "Missing value for --style-map",
  )
  expect_cli_error(
    ["docx2html", "--output-dir"],
    "Missing value for --output-dir",
  )
  expect_cli_error(
    ["docx2html", "--output-format"],
    "Missing value for --output-format",
  )
  expect_cli_error(
    ["docx2html", "--output-format=pdf", "input.docx"],
    "Unsupported output format: pdf",
  )
  expect_cli_error(
    ["docx2html", "--wat", "input.docx"],
    "Unknown option: --wat",
  )
  expect_cli_error(
    ["docx2html", "input.docx", "one.html", "two.html"],
    "Too many positional arguments",
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
  let markdown_options = CliOptions::{ ..options, output_format: Markdown }
  debug_inspect(
    output_path(markdown_options),
    content="Some(\"out/single-paragraph.html\")",
  )
  inspect(image_extension("image/png"), content="png")
  inspect(input_basename_without_docx("C:\\tmp\\sample.docx"), content="sample")
}

///|
test "CLI conversion writes default HTML output file" {
  let dir = "_build/cli-main-default-output-file"
  ensure_test_dir(dir)
  let input_path = join_path(dir, "input.docx")
  let output_file = join_path(dir, "output.html")
  @fs.write_bytes_to_file(input_path, cli_single_paragraph_docx())
  run_conversion({
    input_path,
    output_path: Some(output_file),
    output_dir: None,
    style_map_path: None,
    output_format: Html,
    pretty_print: false,
  })
  inspect(
    @fs.read_file_to_string(output_file),
    content="<p>Walking on imported air</p>",
  )
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
test "CLI conversion writes markdown output file" {
  let dir = "_build/cli-main-markdown-output-file"
  ensure_test_dir(dir)
  let input_path = join_path(dir, "input.docx")
  let output_file = join_path(dir, "output.md")
  @fs.write_bytes_to_file(input_path, cli_single_paragraph_docx())
  run_conversion({
    input_path,
    output_path: Some(output_file),
    output_dir: None,
    style_map_path: None,
    output_format: Markdown,
    pretty_print: false,
  })
  inspect(
    @fs.read_file_to_string(output_file),
    content="Walking on imported air\n\n",
  )
}

///|
test "CLI conversion threads pretty print to HTML output" {
  let dir = "_build/cli-main-pretty-print"
  ensure_test_dir(dir)
  let input_path = join_path(dir, "input.docx")
  let output_file = join_path(dir, "output.html")
  @fs.write_bytes_to_file(input_path, cli_single_paragraph_docx())
  run_conversion({
    input_path,
    output_path: Some(output_file),
    output_dir: None,
    style_map_path: None,
    output_format: Html,
    pretty_print: true,
  })
  inspect(
    @fs.read_file_to_string(output_file),
    content="<p>\n  Walking on imported air\n</p>",
  )
}

///|
test "CLI conversion keeps inline images in single-file output" {
  let dir = "_build/cli-main-single-file-images"
  ensure_test_dir(dir)
  let input_path = join_path(dir, "tiny-picture.docx")
  let output_file = join_path(dir, "tiny-picture.html")
  @fs.write_bytes_to_file(input_path, cli_tiny_picture_docx())
  run_conversion({
    input_path,
    output_path: Some(output_file),
    output_dir: None,
    style_map_path: None,
    output_format: Html,
    pretty_print: false,
  })
  inspect(
    @fs.read_file_to_string(output_file),
    content="<p><img src=\"data:image/png;base64,\{cli_tiny_picture_base64()}\" /></p>",
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
    @fs.read_file_to_string(join_path(dir, "input.html")),
    content="Walking on imported air\n\n",
  )
}

///|
test "CLI conversion writes markdown image output inside output dir" {
  let dir = "_build/cli-main-output-dir-markdown-images"
  ensure_test_dir(dir)
  let input_path = join_path(dir, "tiny-picture.docx")
  @fs.write_bytes_to_file(input_path, cli_tiny_picture_docx())
  run_conversion({
    input_path,
    output_path: None,
    output_dir: Some(dir),
    style_map_path: None,
    output_format: Markdown,
    pretty_print: false,
  })
  inspect(
    @fs.read_file_to_string(join_path(dir, "tiny-picture.html")),
    content="![](1.png)\n\n",
  )
  inspect(
    @base64.encode(@fs.read_file_to_bytes(join_path(dir, "1.png"))[:]),
    content=cli_tiny_picture_base64(),
  )
}

///|
test "CLI conversion writes images inside output dir" {
  let dir = "_build/cli-main-output-dir-images"
  ensure_test_dir(dir)
  let input_path = join_path(dir, "tiny-picture.docx")
  @fs.write_bytes_to_file(input_path, cli_tiny_picture_docx())
  run_conversion({
    input_path,
    output_path: None,
    output_dir: Some(dir),
    style_map_path: None,
    output_format: Html,
    pretty_print: false,
  })
  inspect(
    @fs.read_file_to_string(join_path(dir, "tiny-picture.html")),
    content="<p><img src=\"1.png\" /></p>",
  )
  inspect(
    @base64.encode(@fs.read_file_to_bytes(join_path(dir, "1.png"))[:]),
    content=cli_tiny_picture_base64(),
  )
}
