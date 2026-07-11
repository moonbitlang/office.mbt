///|
/// `docx batch <output> <script.json> [--dry-run]` — authors a NEW document
/// from a `docx.batch/1` op script (see docs/agent-json-schemas.md).
/// Fresh-document-only, fail-closed: the output path must not exist (the
/// batch writer creates documents; it cannot preserve the parts of an
/// existing file the reader does not model). The built package is checked
/// with the structural validator, then written atomically: a unique
/// same-directory temp file created with CreateNew, published with a
/// no-replace rename so a file that appears after the up-front check is
/// never clobbered.
async fn run_batch(matches : @argparse.Matches) -> Unit {
  let output = required_value(matches, "output")
  let script_path = required_value(matches, "script")
  if @afs.exists(output) {
    raise @cli.CliError(
      "docx: refusing to write '\{output}': it already exists (batch creates NEW documents only; it cannot preserve parts of an existing file)",
    )
  }
  let script_text = @afs.read_file(script_path).text()
  @batch.check_duplicate_keys(script_text) catch {
    BatchError(message) => raise @cli.CliError("error: \{message}")
  }
  let script_json = @json.parse(script_text) catch {
    err =>
      raise @cli.CliError("error: the script is not valid JSON: \{repr(err)}")
  }
  let script = @batch.parse_batch(script_json) catch {
    BatchError(message) => raise @cli.CliError("error: \{message}")
  }
  // Image paths resolve relative to the current directory.
  let images : Map[String, Bytes] = Map([])
  for path in script.image_paths() {
    images[path] = @afs.read_file(path).binary() catch {
      err => {
        let at = match script.image_reference(path) {
          Some(at) => " (referenced at \{at})"
          None => ""
        }
        raise @cli.CliError(
          "docx: could not read image file '\{path}'\{at}: \{err}",
        )
      }
    }
  }
  let body = script.build_body(images) catch {
    BatchError(message) => raise @cli.CliError("error: \{message}")
  }
  let bytes = @docx2html.write_docx(body) catch {
    err => raise @cli.CliError(locate_writer_failure(body, err))
  }
  // Belt: the writer's output is dual-tier gated in tests, but re-check the
  // structural tier before anything touches disk.
  let findings = @opc.validate_docx_package(bytes)
  if findings.length() > 0 {
    raise @cli.CliError(
      "docx: internal error — the built package failed validation: \{findings[0]}",
    )
  }
  if matches.flags.get_or_default("dry-run", false) {
    println("ok (dry run): \{script.op_count()} op(s), nothing written")
    return
  }
  write_atomically(output, bytes)
  println("created \{output} (\{script.op_count()} op(s))")
}

///|
/// Most script problems are rejected at parse time with an `ops[i]`
/// address; the writer only fails on DYNAMIC content (image bytes whose
/// header will not parse, table grid geometry). Each op builds exactly one
/// body element, so re-running the writer over each element alone
/// attributes the failure — cheap, error-path-only, and it cannot diverge
/// from the writer's real rules because it IS the writer.
fn locate_writer_failure(
  body : Array[@docx2html.DocumentElement],
  err : Error,
) -> String {
  let message = match err {
    @docx2html.Unsupported(message~)
    | @docx2html.InvalidZip(message~)
    | @docx2html.InvalidXml(message~)
    | @docx2html.MissingPart(message~) => message
    other => repr(other)
  }
  for index, element in body {
    let failed = try {
      let _ = @docx2html.write_docx([element])
      false
    } catch {
      _ => true
    }
    if failed {
      return "error: ops[\{index}]: \{message}"
    }
  }
  "error: \{message}"
}

///|
/// Atomic publication: a unique same-directory temp (CreateNew never
/// truncates an existing file or follows a symlink into other data) and a
/// no-replace rename (a destination created after the up-front existence
/// check fails the rename instead of being overwritten). The temp is
/// removed on any failure after creation.
async fn write_atomically(output : String, bytes : Bytes) -> Unit {
  for attempt in 0..<100 {
    let temp = "\{output}.tmp-\{attempt}"
    let created = try {
      @afs.write_file(temp, bytes, create_mode=CreateNew)
      true
    } catch {
      _ => false
    }
    if !created {
      // Likely EEXIST from a leftover or concurrent temp — leave that
      // file alone and try the next suffix.
      continue
    }
    @afs.rename(temp, output, replace=false) catch {
      err => {
        @afs.remove(temp) catch {
          _ => ()
        }
        raise @cli.CliError(
          "docx: could not write '\{output}' (did it appear concurrently?): \{err}",
        )
      }
    }
    return
  }
  raise @cli.CliError(
    "docx: could not create a temporary file next to '\{output}' (100 attempts); remove stale .tmp-* files",
  )
}

///|
fn batch_command() -> @argparse.Command {
  Command(
    "batch",
    about="Author a NEW document from a docx.batch/1 op script",
    flags=[
      FlagArg(
        "dry-run",
        long="dry-run",
        about="Parse, build, and validate without writing anything.",
      ),
    ],
    positionals=[
      PositionArg(
        "output",
        about="Output .docx path (must not exist).",
        num_args=ValueRange(lower=1, upper=1),
      ),
      PositionArg(
        "script",
        about="Path to the docx.batch/1 JSON script; image paths inside the script resolve relative to the current directory.",
        num_args=ValueRange(lower=1, upper=1),
      ),
    ],
  )
}
