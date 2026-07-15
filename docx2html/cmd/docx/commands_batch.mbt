///|
/// `docx batch <output> <script.json> [--dry-run]` — authors a NEW document
/// from a `docx.batch/1` or `/2` op script (see docs/agent-json-schemas.md;
/// `/2` adds `comment` ops).
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
  @batch.check_script_text(script_text) catch {
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
  // Comment specs re-validate in the writer's constructor (notably the
  // lexical xsd:dateTime check); BatchComment::at() attributes any
  // failure to the exact script op.
  let batch_comments = script.build_comments() catch {
    BatchError(message) => raise @cli.CliError("error: \{message}")
  }
  let comments = []
  for comment in batch_comments {
    let spec = match
      (comment.reply_to(), comment.from_block(), comment.to_block()) {
      (Some(parent), _, _) =>
        @docx2html.comment_reply(
          author=comment.author(),
          initials?=comment.initials(),
          date?=comment.date(),
          reply_to=parent,
          done?=comment.done(),
          comment.body(),
        ) catch {
          err =>
            raise @cli.CliError(
              "error: \{comment.at()}: \{docx_error_message(err)}",
            )
        }
      (None, Some(from), Some(to)) =>
        @docx2html.comment_spec(
          author=comment.author(),
          initials?=comment.initials(),
          date?=comment.date(),
          from~,
          to~,
          done?=comment.done(),
          comment.body(),
        ) catch {
          err =>
            raise @cli.CliError(
              "error: \{comment.at()}: \{docx_error_message(err)}",
            )
        }
      _ =>
        // Unreachable: the parser always sets exactly one of the two.
        raise @cli.CliError(
          "docx: internal error — \{comment.at()} has neither anchor nor reply target",
        )
    }
    comments.push(spec)
  }
  let batch_footnotes = script.build_footnotes() catch {
    BatchError(message) => raise @cli.CliError("error: \{message}")
  }
  let batch_endnotes = script.build_endnotes() catch {
    BatchError(message) => raise @cli.CliError("error: \{message}")
  }
  let footnotes = []
  for note in batch_footnotes {
    footnotes.push(
      @docx2html.note_spec(note.body()) catch {
        err =>
          raise @cli.CliError("error: \{note.at()}: \{docx_error_message(err)}")
      },
    )
  }
  let endnotes = []
  for note in batch_endnotes {
    endnotes.push(
      @docx2html.note_spec(note.body()) catch {
        err =>
          raise @cli.CliError("error: \{note.at()}: \{docx_error_message(err)}")
      },
    )
  }
  let bytes = @docx2html.write_docx_with_annotations(
    body,
    comments~,
    footnotes~,
    endnotes~,
  ) catch {
    err => raise @cli.CliError(locate_writer_failure(script, body, err))
  }
  // Belt: the writer's output is dual-tier gated in tests, but re-check the
  // structural tier before anything touches disk.
  let findings = @opc.validate_docx_package(bytes)
  if findings.length() > 0 {
    raise @cli.CliError(
      "docx: internal error — the built package failed validation: \{findings[0]}",
    )
  }
  let mut ops_summary = "\{script.op_count()} op(s)"
  if script.comment_count() > 0 {
    ops_summary += ", \{script.comment_count()} comment(s)"
  }
  let (footnote_count, endnote_count) = script.note_counts()
  if footnote_count > 0 {
    ops_summary += ", \{footnote_count} footnote(s)"
  }
  if endnote_count > 0 {
    ops_summary += ", \{endnote_count} endnote(s)"
  }
  if matches.flags.get_or_default("dry-run", false) {
    println("ok (dry run): \{ops_summary}, nothing written")
    return
  }
  write_atomically(output, bytes)
  println("created \{output} (\{ops_summary})")
}

///|
fn docx_error_message(err : Error) -> String {
  match err {
    @docx2html.Unsupported(message~)
    | @docx2html.InvalidZip(message~)
    | @docx2html.InvalidXml(message~)
    | @docx2html.MissingPart(message~)
    | @docx2html.ResourceLimit(message~, ..) => message
    // The docx package's own error type (annotate planning is called
    // directly, not through the compat bridge).
    @core.Unsupported(message~)
    | @core.InvalidZip(message~)
    | @core.InvalidXml(message~)
    | @core.MissingPart(message~)
    | @core.ResourceLimit(message~, ..) => message
    other => repr(other)
  }
}

///|
/// Most script problems are rejected at parse time with an `ops[i]`
/// address; the writer only fails on DYNAMIC content (image bytes whose
/// header will not parse, table grid geometry). Every CONTENT op builds
/// exactly one body element — comment ops build none — so re-running the
/// writer over each element alone finds the failing BLOCK, and the
/// script's block->op mapping names the right op even when comment ops
/// are interleaved. Cheap, error-path-only, and it cannot diverge from
/// the writer's real rules because it IS the writer.
fn locate_writer_failure(
  script : @batch.BatchScript,
  body : Array[@docx2html.DocumentElement],
  err : Error,
) -> String {
  let message = docx_error_message(err)
  for index, element in body {
    let failed = try {
      let _ = @docx2html.write_docx([element])
      false
    } catch {
      _ => true
    }
    if failed {
      match script.block_op(index) {
        Some(op) => return "error: ops[\{op}]: \{message}"
        None => return "error: \{message}"
      }
    }
  }
  "error: \{message}"
}

///|
/// Atomic publication: a unique same-directory temp (CreateNew never
/// truncates an existing file or follows a symlink into other data) and a
/// no-replace rename (a destination created after the up-front existence
/// check fails the rename instead of being overwritten). Only the
/// EXCLUSIVE-CREATE step retries under another suffix — once a temp is
/// ours, any later failure (write, close, rename) cleans it up and
/// aborts; retrying those would leak partial files under 99 names.
async fn write_atomically(output : String, bytes : Bytes) -> Unit {
  for attempt in 0..<100 {
    let temp = "\{output}.tmp-\{attempt}"
    // sync=Data matches write_file's default: the data is durable before
    // the rename can publish it.
    let file = @afs.open(temp, mode=WriteOnly, create_mode=CreateNew, sync=Data) catch {
      // Only an existing name (leftover or concurrent temp) is worth the
      // next suffix; EACCES/ENOENT/etc. would fail identically 100 times.
      @os_error.OSError(_, ..) as os_error if os_error.is_EEXIST() => continue
      err =>
        raise @cli.CliError(
          "docx: could not create a temporary file '\{temp}': \{err}",
        )
    }
    file.write(bytes) catch {
      err => {
        file.close()
        @afs.remove(temp) catch {
          _ => ()
        }
        raise @cli.CliError("docx: could not write '\{temp}': \{err}")
      }
    }
    file.close()
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
    about="Author a NEW document from a docx.batch/1 or /2 op script",
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
        about="Path to the docx.batch/1 or /2 JSON script; image paths inside the script resolve relative to the current directory.",
        num_args=ValueRange(lower=1, upper=1),
      ),
    ],
  )
}
