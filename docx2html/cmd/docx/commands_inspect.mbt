// Agent-oriented structured reads: `outline` prints a versioned JSON
// document map built by the `docx2html/inspect` library package; see
// docs/agent-json-schemas.md for the normative payload spec.

///|
/// `docx outline <file>` — prints the `docx.outline/1` structure map.
async fn run_outline(matches : @argparse.Matches) -> Unit {
  let file = required_value(matches, "file")
  let data = @afs.read_file(file).binary()
  let annotated = @docx2html.read_docx_annotated(data)
  println(@inspect.annotated_outline(annotated, file~).stringify(indent=2))
}

///|
fn outline_command() -> @argparse.Command {
  Command("outline", about="Print a document structure map as JSON", positionals=[
    PositionArg(
      "file",
      about="Input .docx file.",
      num_args=ValueRange(lower=1, upper=1),
    ),
  ])
}

///|
/// `docx text <file>` — path-tagged plain text: one line per paragraph
/// (including table-cell paragraphs), prefixed with its `docx.element/1`
/// path so an agent can address what it reads.
async fn run_text(matches : @argparse.Matches) -> Unit {
  let file = required_value(matches, "file")
  let data = @afs.read_file(file).binary()
  let annotated = @docx2html.read_docx_annotated(data)
  for line in @inspect.annotated_text_lines(annotated) {
    println(line)
  }
}

///|
/// `docx get <file> <path>` — prints the element's raw text; with `--json`,
/// the full `docx.element/1` payload.
async fn run_get(matches : @argparse.Matches) -> Unit {
  let file = required_value(matches, "file")
  let path = required_value(matches, "path")
  let data = @afs.read_file(file).binary()
  let annotated = @docx2html.read_docx_annotated(data)
  // Path problems are usage errors, not document errors: agent-facing
  // messages already explain themselves, so give them the `error:` prefix.
  if matches.flags.get_or_default("json", false) {
    let payload = @inspect.annotated_element(annotated, file~, path~) catch {
      PathError(message) => raise @cli.CliError("error: " + message)
    }
    println(payload.stringify(indent=2))
  } else {
    let result = annotated.result()
    let parsed_root_is_annotation = path.has_prefix("/footnotes") ||
      path.has_prefix("/endnotes") ||
      path.has_prefix("/comments")
    let element = try {
      if parsed_root_is_annotation {
        @paths.resolve_annotation_path(
          path,
          footnotes=annotated.footnote_bodies(),
          endnotes=annotated.endnote_bodies(),
          comments=annotated.comment_bodies(),
        )
      } else {
        @inspect.resolve_path(
          result.document,
          path,
          headers=result.headers,
          footers=result.footers,
        )
      }
    } catch {
      PathError(message) => raise @cli.CliError("error: " + message)
    }
    println(element.to_raw_text().trim_end(chars="\n"))
  }
}

///|
fn required_value(
  matches : @argparse.Matches,
  name : String,
) -> String raise @cli.CliError {
  match first_value(matches, name) {
    Some(value) => value
    None =>
      raise CliError(
        "error: the following required argument was not provided: '\{name}'",
      )
  }
}

///|
fn text_command() -> @argparse.Command {
  Command(
    "text",
    about="Print path-tagged plain text, one paragraph per line",
    positionals=[
      PositionArg(
        "file",
        about="Input .docx file.",
        num_args=ValueRange(lower=1, upper=1),
      ),
    ],
  )
}

///|
fn get_command() -> @argparse.Command {
  Command(
    "get",
    about="Print one element by path (raw text, or JSON with --json)",
    flags=[
      FlagArg(
        "json",
        long="json",
        about="print the element as a structured JSON payload",
      ),
    ],
    positionals=[
      PositionArg(
        "file",
        about="Input .docx file.",
        num_args=ValueRange(lower=1, upper=1),
      ),
      PositionArg(
        "path",
        about="Element path, e.g. /body/p[3] (see 'docx text').",
        num_args=ValueRange(lower=1, upper=1),
      ),
    ],
  )
}
