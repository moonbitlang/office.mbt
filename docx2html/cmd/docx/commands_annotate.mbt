///|
/// `docx annotate add <input> <output> --at <path> [--to <path>]
/// (--text <t> --author <a> [--initials i] [--date iso] | --json <file>)`
/// — adds one comment to an EXISTING document by L0 byte-span surgery:
/// anchor markers splice into the original main-part bytes at
/// scanner-derived offsets, the definition into the comments part
/// (created and wired when absent), and every untouched byte stays.
/// Metadata ownership is BRANCH-EXCLUSIVE: with `--text` the flags own
/// it; with `--json` the docx.annotate/1 envelope owns ALL of it and
/// the metadata flags are rejected. Publication follows the batch
/// contract: the output must not exist, the write is atomic, and every
/// failure leaves ZERO output.
async fn run_annotate_add(matches : @argparse.Matches) -> Unit {
  let input = required_value(matches, "input")
  let output = required_value(matches, "output")
  // in==out is rejected STRUCTURALLY, not by string comparison: the
  // output must not exist while the input must — one path naming both
  // (including case-folded aliases on case-insensitive filesystems)
  // trips the existence check below before anything is read.
  if @afs.exists(output) {
    raise @cli.CliError(
      "docx: refusing to write '\{output}': it already exists (annotate writes a NEW file; it never edits in place)",
    )
  }
  let at_flag = required_value(matches, "at")
  let to_flag = first_value(matches, "to")
  // Branch-exclusive comment source.
  let spec = comment_spec_from_flags(matches)
  let original = @afs.read_file(input).binary()
  let annotated = @docx2html.read_docx_annotated(original) catch {
    err =>
      raise @cli.CliError(
        "docx: could not read '\{input}': \{docx_error_message(err)}",
      )
  }
  // Anchors: BODY-story paragraph paths, ordinal-only.
  let at_relative = body_paragraph_relative_path(at_flag)
  let to_relative = match to_flag {
    Some(to_path) => body_paragraph_relative_path(to_path)
    None => at_relative
  }
  // Everything between the validated spec and a ready splice plan —
  // sidecar/unrepairable gates, span resolution, id allocation,
  // fragments, part placement, wiring — lives in the docx package so
  // the SDK gates exercise the exact same code.
  let (plan, new_id) = @docx_impl.plan_comment_addition(
    annotated,
    original,
    at_relative~,
    to_relative~,
    spec,
  ) catch {
    err => raise @cli.CliError("error: \{docx_error_message(err)}")
  }
  let spliced = @splice.splice_docx(original, plan) catch {
    err => raise @cli.CliError("error: \{docx_error_message(err)}")
  }
  // Belt 1: the structural validator.
  let findings = @opc.validate_docx_package(spliced)
  if findings.length() > 0 {
    raise @cli.CliError(
      "docx: internal error — the annotated package failed validation: \{findings[0]}",
    )
  }
  // Belt 2: the mutation must READ BACK — the new comment, anchored at
  // the requested paragraph, with no new unrepairable state.
  let verify = @docx2html.read_docx_annotated(spliced) catch {
    err =>
      raise @cli.CliError(
        "docx: internal error — the annotated package does not read back: \{docx_error_message(err)}",
      )
  }
  let mut verified = false
  for comment in verify.annotations().comments() {
    if comment.id() == new_id && comment.defined() {
      for anchor in comment.anchors() {
        if anchor.start() is Some(start_path) &&
          start_path == "/body/" + at_relative {
          verified = true
        }
      }
    }
  }
  if !verified {
    raise @cli.CliError(
      "docx: internal error — the new comment did not read back anchored at '/body/\{at_relative}'; nothing was written",
    )
  }
  write_atomically(output, spliced)
  println("annotated \{output} (comment \{new_id} on /body/\{at_relative})")
}

///|
/// Parses a `--at`/`--to` flag: a BODY-story paragraph path
/// ("/body/p[2]", "/body/tbl[1]/tr[2]/tc[1]/p[1]"), ordinal selectors
/// only, and returns the scanner-relative form.
fn body_paragraph_relative_path(path : String) -> String raise @cli.CliError {
  let parsed = @paths.parse_path(path) catch {
    err => raise CliError("error: \{path}: \{err}")
  }
  guard parsed.root is Body else {
    raise CliError(
      "error: '\{path}' is not a body path (annotate anchors to BODY-story paragraphs only)",
    )
  }
  if parsed.steps.length() == 0 {
    raise CliError("error: '\{path}' names the body, not a paragraph")
  }
  let mut relative = ""
  for index, step in parsed.steps {
    guard step.selector is Ordinal(ordinal) else {
      raise CliError(
        "error: '\{path}': body paragraphs address by ordinal ([n]), not [@id=...]",
      )
    }
    if index == parsed.steps.length() - 1 && step.kind != "p" {
      raise CliError(
        "error: '\{path}' must end at a paragraph (p[n]); got '\{step.kind}'",
      )
    }
    if relative != "" {
      relative += "/"
    }
    relative += "\{step.kind}[\{ordinal}]"
  }
  relative
}

///|
fn annotate_command() -> @argparse.Command {
  Command(
    "annotate",
    about="Annotate an EXISTING document by byte-preserving surgery",
    subcommand_required=true,
    subcommands=[
      Command(
        "add",
        about="Add one comment anchored to body paragraph(s)",
        options=[
          OptionArg(
            "at",
            long="at",
            about="Anchor paragraph path (/body/p[2] or a table-cell paragraph path). Required.",
          ),
          OptionArg(
            "to",
            long="to",
            about="Range end paragraph path (same story, not before --at).",
          ),
          OptionArg(
            "text",
            long="text",
            about="Plain comment text (one paragraph); metadata comes from the flags.",
          ),
          OptionArg(
            "json",
            long="json",
            about="Path to a docx.annotate/1 envelope FILE owning ALL metadata; the metadata flags are rejected.",
          ),
          OptionArg(
            "author",
            long="author",
            about="Comment author (required with --text).",
          ),
          OptionArg(
            "initials",
            long="initials",
            about="Author initials (optional, --text branch only).",
          ),
          OptionArg(
            "date",
            long="date",
            about="xsd:dateTime timestamp (optional, --text branch only).",
          ),
        ],
        positionals=[
          PositionArg(
            "input",
            about="Existing .docx to annotate (never modified).",
            num_args=ValueRange(lower=1, upper=1),
          ),
          PositionArg(
            "output",
            about="Output .docx path (must not exist).",
            num_args=ValueRange(lower=1, upper=1),
          ),
        ],
      ),
      Command(
        "reply",
        about="Reply to an existing comment (anchorless; threads via commentsExtended)",
        options=[
          OptionArg(
            "comment",
            long="comment",
            about="The parent comment's id (as outline shows). Required.",
          ),
          OptionArg(
            "text",
            long="text",
            about="Plain reply text (one paragraph); metadata comes from the flags.",
          ),
          OptionArg(
            "json",
            long="json",
            about="Path to a docx.annotate/1 envelope FILE owning ALL metadata; the metadata flags are rejected.",
          ),
          OptionArg(
            "author",
            long="author",
            about="Reply author (required with --text).",
          ),
          OptionArg(
            "initials",
            long="initials",
            about="Author initials (optional, --text branch only).",
          ),
          OptionArg(
            "date",
            long="date",
            about="xsd:dateTime timestamp (optional, --text branch only).",
          ),
        ],
        positionals=[
          PositionArg(
            "input",
            about="Existing .docx (never modified).",
            num_args=ValueRange(lower=1, upper=1),
          ),
          PositionArg(
            "output",
            about="Output .docx path (must not exist).",
            num_args=ValueRange(lower=1, upper=1),
          ),
        ],
      ),
      Command(
        "resolve",
        about="Mark a comment resolved (w15:done=1)",
        options=[
          OptionArg(
            "comment",
            long="comment",
            about="The comment's id. Required.",
          ),
        ],
        positionals=[
          PositionArg(
            "input",
            about="Existing .docx (never modified).",
            num_args=ValueRange(lower=1, upper=1),
          ),
          PositionArg(
            "output",
            about="Output .docx path (must not exist).",
            num_args=ValueRange(lower=1, upper=1),
          ),
        ],
      ),
      Command(
        "unresolve",
        about="Mark a comment unresolved (w15:done=0)",
        options=[
          OptionArg(
            "comment",
            long="comment",
            about="The comment's id. Required.",
          ),
        ],
        positionals=[
          PositionArg(
            "input",
            about="Existing .docx (never modified).",
            num_args=ValueRange(lower=1, upper=1),
          ),
          PositionArg(
            "output",
            about="Output .docx path (must not exist).",
            num_args=ValueRange(lower=1, upper=1),
          ),
        ],
      ),
    ],
  )
}

///|
/// The BRANCH-EXCLUSIVE comment source shared by `annotate add` and
/// `annotate reply`: `--text` with flag-owned metadata (`--author`
/// required), or `--json <file>` with the docx.annotate/1 envelope
/// owning ALL metadata (the metadata flags rejected).
async fn comment_spec_from_flags(
  matches : @argparse.Matches,
) -> @docx_impl.CommentSpec {
  let text_flag = first_value(matches, "text")
  let json_flag = first_value(matches, "json")
  let author_flag = first_value(matches, "author")
  let initials_flag = first_value(matches, "initials")
  let date_flag = first_value(matches, "date")
  match (text_flag, json_flag) {
    (Some(_), Some(_)) =>
      raise @cli.CliError(
        "error: --text and --json are mutually exclusive (exactly one is required)",
      )
    (None, None) =>
      raise @cli.CliError("error: exactly one of --text or --json is required")
    (Some(text), None) => {
      let author = match author_flag {
        Some(author) => author
        None =>
          raise @cli.CliError(
            "error: --author is required with --text (the flags own the metadata on this branch)",
          )
      }
      @docx2html.comment_spec(
        author~,
        initials?=initials_flag,
        date?=date_flag,
        from=0,
        to=0,
        [@docx2html.paragraph([@docx2html.run([@docx2html.text(text)])])],
      ) catch {
        err => raise @cli.CliError("error: \{docx_error_message(err)}")
      }
    }
    (None, Some(envelope_path)) => {
      if author_flag is Some(_) ||
        initials_flag is Some(_) ||
        date_flag is Some(_) {
        raise @cli.CliError(
          "error: --author/--initials/--date are rejected with --json (the envelope owns all metadata)",
        )
      }
      let envelope_text = @afs.read_file(envelope_path).text()
      @batch.check_script_text(envelope_text) catch {
        BatchError(message) => raise @cli.CliError("error: \{message}")
      }
      let envelope_json = @json.parse(envelope_text) catch {
        err =>
          raise @cli.CliError(
            "error: the envelope is not valid JSON: \{repr(err)}",
          )
      }
      let envelope = @batch.parse_annotate(envelope_json) catch {
        BatchError(message) => raise @cli.CliError("error: \{message}")
      }
      let body = envelope.build_body() catch {
        BatchError(message) => raise @cli.CliError("error: \{message}")
      }
      @docx2html.comment_spec(
        author=envelope.author(),
        initials?=envelope.initials(),
        date?=envelope.date(),
        from=0,
        to=0,
        body,
      ) catch {
        err => raise @cli.CliError("error: \{docx_error_message(err)}")
      }
    }
  }
}

///|
/// `docx annotate reply <in> <out> --comment <id> (--text ... --author
/// ... | --json <file>)` — an anchorless reply threaded under the
/// parent (its anchor is logically the parent's), with the paraId
/// retrofit and commentsExtended wiring handled by the plan layer.
async fn run_annotate_reply(matches : @argparse.Matches) -> Unit {
  let input = required_value(matches, "input")
  let output = required_value(matches, "output")
  if @afs.exists(output) {
    raise @cli.CliError(
      "docx: refusing to write '\{output}': it already exists (annotate writes a NEW file; it never edits in place)",
    )
  }
  let parent_id = required_value(matches, "comment")
  let spec = comment_spec_from_flags(matches)
  let original = @afs.read_file(input).binary()
  let annotated = @docx2html.read_docx_annotated(original) catch {
    err =>
      raise @cli.CliError(
        "docx: could not read '\{input}': \{docx_error_message(err)}",
      )
  }
  let (plan, new_id) = @docx_impl.plan_comment_reply(
    annotated,
    original,
    parent_id~,
    spec,
  ) catch {
    err => raise @cli.CliError("error: \{docx_error_message(err)}")
  }
  let spliced = @splice.splice_docx(original, plan) catch {
    err => raise @cli.CliError("error: \{docx_error_message(err)}")
  }
  let findings = @opc.validate_docx_package(spliced)
  if findings.length() > 0 {
    raise @cli.CliError(
      "docx: internal error — the annotated package failed validation: \{findings[0]}",
    )
  }
  let verify = @docx2html.read_docx_annotated(spliced) catch {
    err =>
      raise @cli.CliError(
        "docx: internal error — the annotated package does not read back: \{docx_error_message(err)}",
      )
  }
  let mut verified = false
  for comment in verify.annotations().comments() {
    if comment.id() == new_id &&
      comment.defined() &&
      comment.parent_id() is Some(threaded) &&
      threaded == parent_id {
      verified = true
    }
  }
  if !verified {
    raise @cli.CliError(
      "docx: internal error — the reply did not read back threaded under comment '\{parent_id}'; nothing was written",
    )
  }
  write_atomically(output, spliced)
  println("annotated \{output} (comment \{new_id} replying to \{parent_id})")
}

///|
/// `docx annotate resolve|unresolve <in> <out> --comment <id>` — flips
/// the w15:done flag, creating the commentsExtended part (and the
/// paraId key) when the document predates them.
async fn run_annotate_resolution(
  matches : @argparse.Matches,
  done : Bool,
) -> Unit {
  let input = required_value(matches, "input")
  let output = required_value(matches, "output")
  if @afs.exists(output) {
    raise @cli.CliError(
      "docx: refusing to write '\{output}': it already exists (annotate writes a NEW file; it never edits in place)",
    )
  }
  let comment_id = required_value(matches, "comment")
  let original = @afs.read_file(input).binary()
  let annotated = @docx2html.read_docx_annotated(original) catch {
    err =>
      raise @cli.CliError(
        "docx: could not read '\{input}': \{docx_error_message(err)}",
      )
  }
  let plan = @docx_impl.plan_comment_resolution(
    annotated,
    original,
    comment_id~,
    done~,
  ) catch {
    err => raise @cli.CliError("error: \{docx_error_message(err)}")
  }
  let spliced = @splice.splice_docx(original, plan) catch {
    err => raise @cli.CliError("error: \{docx_error_message(err)}")
  }
  let findings = @opc.validate_docx_package(spliced)
  if findings.length() > 0 {
    raise @cli.CliError(
      "docx: internal error — the package failed validation: \{findings[0]}",
    )
  }
  let verify = @docx2html.read_docx_annotated(spliced) catch {
    err =>
      raise @cli.CliError(
        "docx: internal error — the package does not read back: \{docx_error_message(err)}",
      )
  }
  let mut verified = false
  for comment in verify.annotations().comments() {
    if comment.id() == comment_id &&
      comment.done() is Some(flag) &&
      flag == done {
      verified = true
    }
  }
  if !verified {
    raise @cli.CliError(
      "docx: internal error — comment '\{comment_id}' did not read back with done=\{done}; nothing was written",
    )
  }
  write_atomically(output, spliced)
  println("annotated \{output} (comment \{comment_id} done=\{done})")
}
