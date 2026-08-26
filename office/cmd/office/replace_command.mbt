// `office replace` — the transactional find-and-replace verb (N2b).
//
// The CLI half owns REQUEST policy: flag validation, the contradictory
// flag pair, the control-character rejection on new text, and the
// output contract. Selection and refusal semantics live in the engine;
// publication and readback live in the transaction. Nothing here
// decides what is editable.

///|
fn replace_command() -> @argparse.Command {
  let summary = match @lib.find_capability_command("replace") {
    Some(command) => command.summary
    None =>
      "Replace literal text in a DOCX, refusing wherever an edit would not survive"
  }
  Command(
    "replace",
    about=summary,
    positionals=[
      PositionArg(
        "file",
        about="existing .docx package (never modified in place)",
        num_args=@argparse.ValueRange::single(),
      ),
      PositionArg(
        "out",
        about="destination .docx; created atomically, nothing written on refusal",
        num_args=@argparse.ValueRange::single(),
      ),
    ],
    options=[
      OptionArg(
        "text",
        long="text",
        about="literal text to replace — never a regular expression or wildcard; matched over the reader PROJECTION, so it spans run boundaries",
      ),
      OptionArg(
        "with",
        long="with",
        about="replacement text; empty deletes the match. Control characters including \\t and \\n are rejected — no silent break or tab synthesis",
      ),
      OptionArg(
        "in",
        long="in",
        about="restrict to a body-relative subtree, e.g. p[3] or tbl[1]",
      ),
      OptionArg(
        "nth",
        long="nth",
        about="select ONE candidate by the ordinal `office find` reports (1-based, counted over ALL candidates including restricted ones)",
      ),
      OptionArg(
        "expect",
        long="expect",
        about="assert exactly N replacements are selected; a mismatch refuses before anything is written",
      ),
    ],
    flags=[
      FlagArg(
        "allow-zero",
        long="allow-zero",
        about="treat zero matches as success instead of refusing; contradicts --expect",
      ),
      FlagArg(
        "dry-run",
        long="dry-run",
        about="run the identical selection and preflight pipeline, exit as the real run would, write nothing",
      ),
      FlagArg(
        "overwrite",
        long="overwrite",
        about="replace an existing destination",
      ),
      docx_json_flag(),
    ],
  )
}

///|
/// Reject control characters in replacement text at the REQUEST
/// boundary. v1 makes no structural text: a `\t` or `\n` in `--with`
/// would either be entity-escaped into literal control characters or
/// silently become break/tab elements, and both are surprises. The
/// engine itself permits XML-valid tab/LF/CR — this is verb policy, the
/// same split `set_run_text` uses.
fn replace_reject_control_text(text : String) -> Unit raise CliFailure {
  for character in text {
    let code = character.to_int()
    if code < 0x20 {
      raise CliFailure(
        @lib.protocol_error(
          "office.invalid_arguments",
          "--with must not contain control characters (found U+\{code}); v1 makes no breaks or tabs from text",
        ),
      )
    }
  }
}

///|
fn replace_report_json(
  file : String,
  output : String,
  needle : String,
  replacement : String,
  within : String?,
  nth : Int?,
  expect : Int?,
  allow_zero : Bool,
  dry_run : Bool,
  report : @office_docx.DocxFindReplaceReport,
  transaction~ : Json,
) -> Json {
  Json::object({
    "schema": Json::string("office.docx.replace/1"),
    "file": Json::string(file),
    "format": Json::string("docx"),
    "output": Json::string(output),
    "text": Json::string(bounded_text(needle, 160)),
    "with": Json::string(bounded_text(replacement, 160)),
    "in": match within {
      Some(prefix) => Json::string(prefix)
      None => Json::null()
    },
    "nth": match nth {
      Some(ordinal) => Json::number(ordinal.to_double())
      None => Json::null()
    },
    "expect": match expect {
      Some(count) => Json::number(count.to_double())
      None => Json::null()
    },
    "allow_zero": Json::boolean(allow_zero),
    "dry_run": Json::boolean(dry_run),
    "selected": Json::array(
      report.selected().map(ordinal => Json::number(ordinal.to_double())),
    ),
    "replaced": Json::number(report.replaced().to_double()),
    "affected": Json::array(
      report.affected_paths().map(path => Json::string(path)),
    ),
    "changed": Json::boolean(report.changed()),
    "stories_scanned": Json::array([Json::string("/body")]),
    "transaction": transaction,
  })
}

///|
async fn run_replace(matches : @argparse.Matches) -> Unit {
  let file = required_value(matches, "file")
  let output = required_value(matches, "out")
  let mode = office_validate_output_mode(matches)
  guard file.to_lower().has_suffix(".docx") else {
    raise CliFailure(
      @lib.protocol_error(
        "office.invalid_arguments", "office replace requires a .docx document",
      ),
    )
  }
  guard output.to_lower().has_suffix(".docx") else {
    raise CliFailure(
      @lib.protocol_error(
        "office.invalid_arguments", "the destination must end in .docx to match the edited format",
      ),
    )
  }
  let needle = match optional_value(matches, "text") {
    Some(value) if value != "" => value
    Some(_) =>
      raise CliFailure(
        @lib.protocol_error(
          "office.invalid_arguments", "replace requires a non-empty --text; an empty needle matches every position",
        ),
      )
    None =>
      raise CliFailure(
        @lib.protocol_error(
          "office.invalid_arguments", "replace requires --text with the literal text to look for",
        ),
      )
  }
  let replacement = match optional_value(matches, "with") {
    Some(value) => value
    None =>
      raise CliFailure(
        @lib.protocol_error(
          "office.invalid_arguments", "replace requires --with (pass an empty value to delete the match)",
        ),
      )
  }
  replace_reject_control_text(replacement)
  let within = optional_value(matches, "in")
  let allow_zero = matches.flags.get_or_default("allow-zero", false)
  let dry_run = matches.flags.get_or_default("dry-run", false)
  let nth = match optional_value(matches, "nth") {
    Some(_) => Some(bounded_decimal_argument(matches, "nth", 1, 1, 1000))
    None => None
  }
  let expect = match optional_value(matches, "expect") {
    Some(_) => Some(bounded_decimal_argument(matches, "expect", 0, 0, 1000))
    None => None
  }
  // The contradiction is rejected HERE, before any file is read:
  // `--expect N` demands exactly N replacements while `--allow-zero`
  // permits none, so together they only agree when N is zero, which
  // `--expect 0` already says on its own.
  if expect is Some(_) && allow_zero {
    raise CliFailure(
      @lib.protocol_error(
        "office.invalid_arguments", "--expect and --allow-zero contradict each other; --expect 0 asserts zero on its own",
      ),
    )
  }
  let options = @transaction.transaction_options(
    file,
    output_path=output,
    dry_run~,
    overwrite=matches.flags.get_or_default("overwrite", false),
  ) catch {
    error => raise transaction_failure(error)
  }
  let result = @office_docx.transact_docx_find_replace(
    options,
    needle~,
    replacement~,
    within?,
    nth?,
    expect?,
    allow_zero~,
  ) catch {
    error => raise map_replace_failure(error)
  }
  let record = replace_report_json(
    file,
    output,
    needle,
    replacement,
    within,
    nth,
    expect,
    allow_zero,
    dry_run,
    result.report(),
    transaction=result.transaction().to_json(),
  )
  match mode {
    JsonDocument => println(@lib.output_success(record).stringify(indent=2))
    JsonLines => println(@lib.output_success(record).stringify())
    Human => {
      let verb = if dry_run { "would replace" } else { "replaced" }
      println(
        "replace: " +
        verb +
        " \{result.report().replaced()} occurrence(s) across \{result.report().affected_paths().length()} paragraph(s) -> " +
        human_text(output, 160),
      )
    }
  }
}

///|
/// Map a transaction-layer failure to the CLI contract, preserving the
/// typed codes the transaction raises (`office.replace.no_match`,
/// `office.replace.expect_mismatch`, refusal reasons from the engine).
fn map_replace_failure(error : Error) -> CliFailure {
  match error {
    CliFailure(_) as failure => failure
    @transaction.TransactionError(_) as failure => transaction_failure(failure)
    _ => unexpected_cli_failure("office.replace.failed", "replace", error)
  }
}
