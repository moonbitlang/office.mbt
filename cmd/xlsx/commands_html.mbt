// The `html` subcommand: render a workbook (or one sheet) to a
// self-contained HTML document — the "eyes" half of the agent loop. The
// document goes to stdout by default (wasm-safe) or to `--out`.

///|
async fn run_html(m : @argparse.Matches) -> Unit {
  let file = arg(m, "file")
  let workbook = @lib.open_file(file)
  let max_rows = parse_positive_int(m, "max-rows", 1000)
  let max_cols = parse_positive_int(m, "max-cols", 256)
  let document = @xlsx2html.render_workbook(
    workbook,
    title=file,
    sheet=arg(m, "sheet"),
    max_rows~,
    max_cols~,
    include_images=!flag(m, "no-images"),
    calc=flag(m, "calc"),
  )
  let out = arg(m, "out")
  if out == "" {
    println(document)
  } else {
    write_file(out, @encoding/utf8.encode(document[:]))
    println("wrote \{out}")
  }
}

///|
fn parse_positive_int(
  m : @argparse.Matches,
  name : String,
  default : Int,
) -> Int raise CliError {
  let text = arg(m, name)
  if text == "" {
    return default
  }
  let value = @string.parse_int(text) catch {
    _ =>
      raise CliError("error: invalid --\{name} '\{text}' (expected a number)")
  }
  if value < 1 {
    raise CliError("error: --\{name} must be at least 1")
  }
  value
}
