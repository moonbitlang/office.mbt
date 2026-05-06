///|
fn markdown_cmd_usage() -> Unit raise {
  fail("usage: moon run --target native markdown/cmd <input.pdf> <output.md>")
}

///|
async fn main {
  let args = @env.args()
  guard args.length() == 3 else { markdown_cmd_usage() }
  let input_path = args[1]
  let output_path = args[2]
  let markdown = @markdown.pdf_bytes_to_markdown(
    @fs.read_file(input_path).binary(),
  )
  @fs.write_file(output_path, @utf8.encode(markdown), create=0o644)
}
