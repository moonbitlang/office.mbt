///|
/// `docx batch <output> <script.json> [--dry-run]` — authors a NEW document
/// from a `docx.batch/1` op script (see docs/agent-json-schemas.md).
/// Fresh-document-only, fail-closed: the output path must not exist (the
/// batch writer creates documents; it cannot preserve the parts of an
/// existing file the reader does not model). The built package is checked
/// with the structural validator, then written atomically (temp + rename).
async fn run_batch(matches : @argparse.Matches) -> Unit {
  let output = required_value(matches, "output")
  let script_path = required_value(matches, "script")
  if @afs.exists(output) {
    raise @cli.CliError(
      "docx: refusing to write '\{output}': it already exists (batch creates NEW documents only; it cannot preserve parts of an existing file)",
    )
  }
  let script_text = @afs.read_file(script_path).text()
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
      err =>
        raise @cli.CliError("docx: could not read image file '\{path}': \{err}")
    }
  }
  let body = script.build_body(images) catch {
    BatchError(message) => raise @cli.CliError("error: \{message}")
  }
  let bytes = @docx2html.write_docx(body)
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
  let temp = output + ".tmp"
  @afs.write_file(temp, bytes, create_mode=CreateOrTruncate)
  @afs.rename(temp, output) catch {
    err => {
      @afs.remove(temp) catch {
        _ => ()
      }
      raise @cli.CliError("docx: could not write '\{output}': \{err}")
    }
  }
  println("created \{output} (\{script.op_count()} op(s))")
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
        about="Path to the docx.batch/1 JSON script.",
        num_args=ValueRange(lower=1, upper=1),
      ),
    ],
  )
}
