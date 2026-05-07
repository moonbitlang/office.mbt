///|
fn markdown_cmd_usage() -> Unit raise {
  fail("usage: moon run --target native markdown/cmd <input.pdf> <output.md>")
}

///|
async fn main {
  let args = @env.args()
  guard args.length() == 3 else { markdown_cmd_usage() }
  markdown_cmd_convert_file(args[1], args[2])
}

///|
async fn markdown_cmd_convert_file(
  input_path : String,
  output_path : String,
) -> Unit {
  let markdown = @markdown.pdf_bytes_to_markdown(
    @fs.read_file(input_path).binary(),
  )
  @fs.write_file(output_path, @utf8.encode(markdown), create=0o644)
}
