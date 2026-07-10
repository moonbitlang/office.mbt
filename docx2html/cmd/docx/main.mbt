///|
/// The agent-facing docx CLI, structured like `cmd/xlsx`: one binary, one
/// subcommand per operation. Subcommands:
///
///   docx create <output>                    create a blank document
///   docx batch <output> <script.json>       author a document from ops
///   docx convert <input> [output] [flags]   convert to HTML or Markdown
///   docx outline <file>                     print a document map as JSON
///   docx text <file>                        print path-tagged plain text
///   docx get <file> <path> [--json]         print one element by path
///   docx validate <file>                    check package structure
///
/// The `convert` subcommand is the same operation as the published
/// `docx2html` binary (both call the shared runner in `internal/cli`); this
/// binary is where the structured read/validate/authoring surface grows.
/// Subcommand handlers live in `commands_convert.mbt` (one file per command
/// family, so later commands don't collide in review).
async fn main {
  run_cli() catch {
    // A `CliError` is already a formatted, user-facing message. Reader errors
    // get the `docx:` program prefix; anything else keeps argparse's own
    // `error:` prefix or gains `docx:`. The error escapes `main`, which
    // prints the message once and exits non-zero on both native and wasm
    // (wasm has no public exit() and no stderr, so diagnostics go to stdout).
    @cli.CliError(_) as err => raise err
    @docx2html.InvalidZip(message~)
    | @docx2html.InvalidXml(message~)
    | @docx2html.MissingPart(message~)
    | @docx2html.Unsupported(message~) =>
      raise @cli.CliError("docx: " + message)
    err => {
      let msg = err.to_string()
      raise @cli.CliError(
        if msg.has_prefix("error:") {
          msg
        } else {
          "docx: " + msg
        },
      )
    }
  }
}

///|
/// Parses arguments and dispatches to the selected subcommand. Argument
/// errors from `parse` propagate to `main`.
async fn run_cli() -> Unit {
  let argv = @env.args()
  let args = if argv.length() > 0 { argv[1:].to_owned() } else { [] }
  let command = build_command()
  let matches = command.parse(argv=args, env=Map([]))
  match matches.subcommand {
    Some(("create", m)) => run_create(m)
    Some(("batch", m)) => run_batch(m)
    Some(("convert", m)) => run_convert(m)
    Some(("outline", m)) => run_outline(m)
    Some(("text", m)) => run_text(m)
    Some(("get", m)) => run_get(m)
    Some(("validate", m)) => run_validate(m)
    _ => println(command.render_help())
  }
}

///|
/// Builds the argparse command tree.
fn build_command() -> @argparse.Command {
  Command(
    "docx",
    about="Read, inspect, and convert docx documents",
    subcommand_required=true,
    subcommands=[
      create_command(),
      batch_command(),
      convert_command(),
      outline_command(),
      text_command(),
      get_command(),
      validate_command(),
    ],
  )
}
