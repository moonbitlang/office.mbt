// `office format` — the transactional direct-formatting verb (F3).
//
// The CLI half owns REQUEST policy: flag validation, the on/off
// property grammar, the selector shapes, and the output contract.
// Selection, the rPr engine, and every refusal live in the planning
// engine; the shared mutation preflight, the three-check readback, and
// atomic publication live in the transaction. Nothing here decides what
// is formattable.

///|
fn format_command() -> @argparse.Command {
  let summary = match @lib.find_capability_command("format") {
    Some(command) => command.summary
    None =>
      "Apply direct character formatting to selected text in a DOCX, refusing wherever the result could differ from the request"
  }
  Command(
    "format",
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
        action=Append,
        about="literal text to format — never a regular expression; matched over the reader PROJECTION, so it spans run boundaries. Every occurrence is selected unless --nth narrows it",
      ),
      OptionArg(
        "in",
        long="in",
        action=Append,
        about="restrict to a body-relative subtree (p[3], tbl[1]) or a stable p[id=\"…\"]; required by --range, which needs ONE paragraph",
      ),
      OptionArg(
        "range",
        long="range",
        action=Append,
        about="format a paragraph-local unit range START:END (the units `office find` and `office get` report), instead of --text; requires --in naming one paragraph",
      ),
      OptionArg(
        "nth",
        long="nth",
        action=Append,
        about="select ONE text occurrence by ordinal (1-based, counted over all occurrences)",
      ),
      OptionArg(
        "bold",
        long="bold",
        action=Append,
        about="on|off — set or clear bold explicitly; omitted properties are left untouched",
      ),
      OptionArg(
        "italic",
        long="italic",
        action=Append,
        about="on|off — set or clear italic",
      ),
      OptionArg(
        "underline",
        long="underline",
        action=Append,
        about="on|off — set or clear single underline",
      ),
      OptionArg(
        "color",
        long="color",
        action=Append,
        about="RRGGBB or #RRGGBB — set an absolute text colour (theme linkage is removed; the engine refuses if it cannot)",
      ),
      OptionArg(
        "expect",
        long="expect",
        action=Append,
        about="assert exactly N spans are selected; a mismatch refuses before anything is written",
      ),
    ],
    flags=[
      FlagArg(
        "allow-zero",
        long="allow-zero",
        about="treat zero selected spans as success instead of refusing; contradicts --expect",
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
/// A scalar option given twice is a CONTRADICTION, not a preference for
/// the later spelling: `--bold on --bold off` must refuse, and so must
/// a duplicated selector or scope that would silently change targets.
fn format_reject_duplicates(
  matches : @argparse.Matches,
) -> Unit raise CliFailure {
  for
    name in [
      "text", "in", "range", "nth", "bold", "italic", "underline", "color", "expect",
    ] {
    match matches.values.get(name) {
      Some(values) if values.length() > 1 =>
        raise CliFailure(
          @lib.protocol_error(
            "office.invalid_arguments",
            "--\{name} was given \{values.length()} times; pass each option once",
          ),
        )
      _ => ()
    }
  }
}

///|
/// One explicit on/off property. Omission means UNTOUCHED, so the
/// grammar demands the caller say which of the three states they mean —
/// there is no bare `--bold` that could read as either set or toggle.
fn format_on_off_option(
  matches : @argparse.Matches,
  name : String,
) -> Bool? raise CliFailure {
  match optional_value(matches, name) {
    Some("on") => Some(true)
    Some("off") => Some(false)
    Some(other) =>
      raise CliFailure(
        @lib.protocol_error(
          "office.invalid_arguments",
          "--\{name} takes `on` or `off` (got '\{bounded_text(other, 40)}'); omit the flag to leave the property untouched",
        ),
      )
    None => None
  }
}

///|
/// `START:END` in paragraph-local units, half-open, as the read
/// surfaces report them.
fn format_range_option(
  matches : @argparse.Matches,
) -> (Int, Int)? raise CliFailure {
  guard optional_value(matches, "range") is Some(value) else { return None }
  guard value.find(":") is Some(colon) &&
    colon > 0 &&
    colon + 1 < value.length() else {
    raise CliFailure(
      @lib.protocol_error(
        "office.invalid_arguments", "--range takes START:END in paragraph-local units, half-open, e.g. 0:5",
      ),
    )
  }
  let start = decimal_prefix_value(
    value.substring(start=0, end=colon).to_string(),
  )
  let end = decimal_prefix_value(
    value.substring(start=colon + 1, end=value.length()).to_string(),
  )
  guard start is Some(from) && end is Some(to) && from >= 0 && to > from else {
    raise CliFailure(
      @lib.protocol_error(
        "office.invalid_arguments", "--range takes START:END with 0 <= START < END, e.g. 0:5",
      ),
    )
  }
  Some((from, to))
}

///|
fn decimal_prefix_value(text : String) -> Int? {
  if text == "" || text.length() > 7 {
    return None
  }
  let mut value = 0
  for ch in text {
    guard ch is ('0'..='9') else { return None }
    value = value * 10 + (ch.to_int() - '0'.to_int())
  }
  Some(value)
}

///|
/// `--in` must be CANONICAL before it may act as a prefix: the engine's
/// prefix test is safe exactly because scanner ordinals are bracketed
/// (`p[1]` is not a prefix of `p[10]`), and a truncated or noncanonical
/// scope would silently widen the selection. A stable `p[id="…"]`
/// passes through — the engine resolves and validates it with its own
/// typed refusals.
fn format_validate_scope(scope : String) -> Unit raise CliFailure {
  if scope == "" {
    raise CliFailure(
      @lib.protocol_error(
        "office.invalid_arguments", "--in must name a body-relative subtree (p[3], tbl[1]) or a stable p[id=\"…\"]; an empty scope would match everything",
      ),
    )
  }
  if scope.has_prefix("p[id=") {
    // Only the EXACT single-segment stable shape goes to the engine's
    // semantic validation; every other stable-looking spelling is
    // malformed grammar and refuses here, before any file is read.
    guard scope.has_prefix("p[id=\"") &&
      scope.has_suffix("\"]") &&
      scope.length() > 8 else {
      raise CliFailure(
        @lib.protocol_error(
          "office.invalid_arguments",
          "--in '\{bounded_text(scope, 80)}' is not the stable shape p[id=\"…\"]; pass the exact para_id spelling the read surfaces report",
        ),
      )
    }
    // `p[id="` is six characters; the payload starts right after it.
    let inner = scope.substring(start=6, end=scope.length() - 2)
    for ch in inner {
      guard ch != '"' && ch != ']' else {
        raise CliFailure(
          @lib.protocol_error(
            "office.invalid_arguments",
            "--in '\{bounded_text(scope, 80)}' is not the stable shape p[id=\"…\"]; pass the exact para_id spelling the read surfaces report",
          ),
        )
      }
    }
    return
  }
  // Only the PATHS the DOCX scanner emits, as a state machine, not a
  // segment list: `tr[1]` cannot start a path, `p[1]/p[1]` and
  // `tbl[1]/tc[1]` order segments no document carries, and `--expect 0`
  // would bless any such typo as a successful no-op. Body level admits
  // a paragraph or a table; a table admits rows; a row admits cells; a
  // cell admits paragraphs or nested tables; a paragraph ends the path.
  let mut valid = true
  let mut state = "body"
  let mut cursor = 0
  while valid && cursor < scope.length() {
    let mut close = cursor
    while close < scope.length() && scope[close] != '/' {
      close += 1
    }
    let segment = scope.substring(start=cursor, end=close).to_string()
    match format_scope_segment_kind(segment) {
      Some(kind) =>
        state = match (state, kind) {
          ("body", "p") | ("cell", "p") => "terminal"
          ("body", "tbl") | ("cell", "tbl") => "table"
          ("table", "tr") => "row"
          ("row", "tc") => "cell"
          _ => {
            valid = false
            state
          }
        }
      None => valid = false
    }
    cursor = close + 1
  }
  if scope.has_suffix("/") {
    valid = false
  }
  guard valid else {
    raise CliFailure(
      @lib.protocol_error(
        "office.invalid_arguments",
        "--in '\{bounded_text(scope, 80)}' is not a body-relative path the reader emits; pass the exact spelling the read surfaces report (p[3], tbl[1]/tr[1]/tc[1]/p[1]) or a stable p[id=\"…\"]",
      ),
    )
  }
}

///|
/// One scope segment: `kind[N]` with a canonical 1-based ordinal.
/// Returns the kind for the caller's state machine, or None when the
/// segment is not of that shape at all.
fn format_scope_segment_kind(segment : String) -> String? {
  guard segment.find("[") is Some(open) &&
    segment.has_suffix("]") &&
    open > 0 &&
    open + 1 < segment.length() - 1 else {
    return None
  }
  let kind = segment.substring(start=0, end=open).to_string()
  guard kind is ("p" | "tbl" | "tr" | "tc") else { return None }
  let ordinal = segment
    .substring(start=open + 1, end=segment.length() - 1)
    .to_string()
  guard ordinal[0] is ('1'..='9') else { return None }
  for ch in ordinal {
    guard ch is ('0'..='9') else { return None }
  }
  if ordinal.length() <= 6 {
    Some(kind)
  } else {
    None
  }
}

///|
fn format_property_json(value : Bool?) -> Json {
  match value {
    Some(state) => Json::boolean(state)
    None => Json::null()
  }
}

///|
fn format_report_json(
  file : String,
  output : String,
  text : String?,
  within : String?,
  range : (Int, Int)?,
  nth : Int?,
  bold : Bool?,
  italic : Bool?,
  underline : Bool?,
  color : String?,
  expect : Int?,
  allow_zero : Bool,
  dry_run : Bool,
  report : @office_docx.DocxFormatReport,
  changed : Bool,
  transaction~ : Json,
) -> Json {
  Json::object({
    "schema": Json::string("office.docx.format/1"),
    "file": Json::string(file),
    "format": Json::string("docx"),
    "output": Json::string(output),
    "mode": Json::string(report.mode()),
    "text": match text {
      Some(value) => Json::string(bounded_text(value, 160))
      None => Json::null()
    },
    "in": match within {
      Some(prefix) => Json::string(prefix)
      None => Json::null()
    },
    // When the scope was a stable p[id="…"], the scan path it resolved
    // to in THIS snapshot — both spellings, so the caller can re-anchor.
    "resolved_in": match report.resolved_within() {
      Some(path) => Json::string(path)
      None => Json::null()
    },
    "range": match range {
      Some((from, to)) => Json::string("\{from}:\{to}")
      None => Json::null()
    },
    "nth": match nth {
      Some(ordinal) => Json::number(ordinal.to_double())
      None => Json::null()
    },
    // The REQUEST, echoed as three-state properties: true set, false
    // cleared, null untouched.
    "bold": format_property_json(bold),
    "italic": format_property_json(italic),
    "underline": format_property_json(underline),
    "color": match color {
      Some(value) => Json::string(value)
      None => Json::null()
    },
    "expect": match expect {
      Some(count) => Json::number(count.to_double())
      None => Json::null()
    },
    "allow_zero": Json::boolean(allow_zero),
    "dry_run": Json::boolean(dry_run),
    // From the TRANSACTION, which knows whether bytes changed: a span
    // already carrying the request selects and plans nothing.
    "changed": Json::boolean(changed),
    "selected": Json::array(
      report.selected().map(ordinal => Json::number(ordinal.to_double())),
    ),
    "spans": Json::array(
      report
      .spans()
      .map(span => {
        Json::object({
          "path": Json::string(span.path()),
          "para_id": match span.para_id() {
            Some(id) => Json::string(id)
            None => Json::null()
          },
          "paragraph_anchor_status": Json::string(span.anchor_status()),
          "start": Json::number(span.start().to_double()),
          "end": Json::number(span.end().to_double()),
          "text": Json::string(bounded_text(span.text(), 160)),
        })
      }),
    ),
    "affected": Json::array(
      report.affected_paths().map(path => Json::string(path)),
    ),
    // The same paragraphs with their anchor judgments: after this
    // publish, the ordinal path may be the LAST time these paragraphs
    // are addressable by position, so the receipt hands the caller the
    // stable identity to re-anchor on.
    "affected_paragraphs": Json::array(
      report
      .affected()
      .map(entry => {
        Json::object({
          "path": Json::string(entry.path()),
          "para_id": match entry.para_id() {
            Some(id) => Json::string(id)
            None => Json::null()
          },
          "paragraph_anchor_status": Json::string(entry.anchor_status()),
        })
      }),
    ),
    "runs_changed": Json::number(report.runs_changed().to_double()),
    "runs_already_satisfied": Json::number(
      report.runs_already_satisfied().to_double(),
    ),
    "splits": Json::number(report.splits().to_double()),
    "byte_edits": Json::number(report.byte_edits().to_double()),
    "stories_scanned": Json::array([Json::string("/body")]),
    "transaction": transaction,
  })
}

///|
/// The reserve for what the preflight cannot measure yet — the
/// transaction record and the envelope's warnings — computed by
/// MEASURING a schema-accurate stub of the `office.transaction/2`
/// record this verb's transaction actually emits: the fixed fields with
/// the real paths, a validator-summary allowance, the one changed part
/// a format writes plus a small added/removed allowance, preservation's
/// unchanged COUNT (the record never lists the unchanged names), and an
/// allowance for the fixed publication warnings. A blanket constant
/// refused reports that would in fact have fit.
fn format_report_transaction_reserve(file : String, output : String) -> Int {
  let validator_entries : Array[Json] = []
  for _ in 0..<6 {
    validator_entries.push(
      Json::object({
        "name": Json::string("office-docx-format-readback-and-longer"),
        "passed": Json::boolean(true),
        "finding_count": Json::number(0),
      }),
    )
  }
  let stub : Json = Json::object({
    "schema": Json::string("office.transaction/2"),
    "format": Json::string("docx"),
    "input": Json::string(file),
    "output": Json::string(output),
    "mode": Json::string("path-based-atomic-replace"),
    "dry_run": Json::boolean(false),
    "changed": Json::boolean(true),
    "committed": Json::boolean(true),
    "original_size": Json::number(9007199254740991.0),
    "result_size": Json::number(9007199254740991.0),
    "replaced_existing": Json::boolean(true),
    "overwritten_size": Json::number(9007199254740991.0),
    "validations": Json::array(validator_entries),
    "preservation": Json::object({
      "whole_file_identical": Json::boolean(false),
      "manifest_enforced": Json::boolean(true),
      "changed": Json::array([Json::string("word/document.xml")]),
      "added": Json::array([
        Json::string("word/an-added-part-allowance.xml"),
        Json::string("word/another-added-part-allowance.xml"),
      ]),
      "removed": Json::array([
        Json::string("word/a-removed-part-allowance.xml"),
        Json::string("word/another-removed-part-allowance.xml"),
      ]),
      "unchanged_count": Json::number(9007199254740991.0),
      "zip_metadata_policy": Json::string("preserve-required-normalize-rest"),
    }),
  })
  let warnings_stub : Json = Json::array([
    Json::object({
      "code": Json::string("office.transaction.path_based_commit_semantics"),
      "message": Json::string(
        "publication uses path-based commit semantics on this platform: " +
        output,
      ),
    }),
    Json::object({
      "code": Json::string("office.transaction.path_based_commit_semantics"),
      "message": Json::string(
        "a second allowance entry for a platform publication warning: " + output,
      ),
    }),
  ])
  stub.stringify().length() + warnings_stub.stringify().length() + 2048
}

///|
fn ensure_format_report_budget(
  record : Json,
  maximum : Int,
) -> Unit raise @transaction.TransactionError {
  ignore(bounded_docx_payload(record, [], maximum)) catch {
    _ =>
      raise @transaction.transaction_failure(
        "office.format.report_too_large", "the JSON report for this format would exceed the output ceiling, so nothing was written; re-run without --json for the human summary, or narrow the selection with --in, --nth, or --range",
      )
  }
}

///|
async fn run_format(matches : @argparse.Matches) -> Unit {
  format_reject_duplicates(matches)
  let file = required_value(matches, "file")
  let output = required_value(matches, "out")
  let mode = office_validate_output_mode(matches)
  guard file.to_lower().has_suffix(".docx") else {
    raise CliFailure(
      @lib.protocol_error(
        "office.invalid_arguments", "office format requires a .docx document",
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
  let bold = format_on_off_option(matches, "bold")
  let italic = format_on_off_option(matches, "italic")
  let underline = format_on_off_option(matches, "underline")
  let color = optional_value(matches, "color")
  guard bold is Some(_) ||
    italic is Some(_) ||
    underline is Some(_) ||
    color is Some(_) else {
    raise CliFailure(
      @lib.protocol_error(
        "office.invalid_arguments", "format requires at least one property: --bold, --italic, --underline (on|off), or --color RRGGBB",
      ),
    )
  }
  let text = match optional_value(matches, "text") {
    Some("") =>
      raise CliFailure(
        @lib.protocol_error(
          "office.invalid_arguments", "--text must be non-empty; an empty needle matches every position",
        ),
      )
    other => other
  }
  let within = optional_value(matches, "in")
  match within {
    Some(scope) => format_validate_scope(scope)
    None => ()
  }
  let range = format_range_option(matches)
  // Exactly ONE selector: text finds occurrences, range names units.
  match (text, range) {
    (Some(_), Some(_)) =>
      raise CliFailure(
        @lib.protocol_error(
          "office.invalid_arguments", "--text and --range are different selectors; pass exactly one",
        ),
      )
    (None, None) =>
      raise CliFailure(
        @lib.protocol_error(
          "office.invalid_arguments", "format requires a selector: --text TEXT, or --range START:END with --in naming one paragraph",
        ),
      )
    _ => ()
  }
  match (range, within) {
    (Some(_), None) =>
      raise CliFailure(
        @lib.protocol_error(
          "office.invalid_arguments", "--range needs --in naming the ONE paragraph its units index into",
        ),
      )
    (Some(_), Some(scope)) => {
      // The scope must NAME A PARAGRAPH: a subtree like tbl[1] has no
      // unit axis for the range to index into, and the contradiction
      // refuses before any file is read.
      let last_segment = match scope.rev_find("/") {
        Some(slash) =>
          scope.substring(start=slash + 1, end=scope.length()).to_string()
        None => scope
      }
      guard last_segment.has_prefix("p[") else {
        raise CliFailure(
          @lib.protocol_error(
            "office.invalid_arguments",
            "--range needs --in ending at a paragraph (p[3], tbl[1]/tr[1]/tc[1]/p[1], or p[id=\"…\"]); '\{bounded_text(scope, 80)}' names no paragraph",
          ),
        )
      }
    }
    _ => ()
  }
  if range is Some(_) && optional_value(matches, "nth") is Some(_) {
    raise CliFailure(
      @lib.protocol_error(
        "office.invalid_arguments", "--nth orders TEXT occurrences; a --range names its units directly, so the two cannot combine",
      ),
    )
  }
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
  if expect is Some(_) && allow_zero {
    raise CliFailure(
      @lib.protocol_error(
        "office.invalid_arguments", "--expect and --allow-zero contradict each other; --expect 0 asserts zero on its own",
      ),
    )
  }
  // The property grammar is validated by the ENGINE (colour shape, the
  // nothing-touched refusal): the CLI passes the request through and
  // maps the typed refusal.
  let format = @docx.docx_direct_format(bold?, italic?, underline?, color?) catch {
    Unsupported(message~) =>
      raise CliFailure(
        @lib.protocol_error(
          "office.invalid_arguments",
          "invalid format request: \{message}",
        ),
      )
    _ =>
      raise CliFailure(
        @lib.protocol_error(
          "office.invalid_arguments", "invalid format request",
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
  // In JSON modes the report IS the deliverable, so its budget is part
  // of the transaction: refuse BEFORE publication if it cannot fit.
  let preflight : ((@office_docx.DocxFormatReport) -> Unit raise)? = match
    mode {
    Human => None
    JsonDocument | JsonLines =>
      Some((report : @office_docx.DocxFormatReport) => {
        ensure_format_report_budget(
          format_report_json(
            file,
            output,
            text,
            within,
            range,
            nth,
            bold,
            italic,
            underline,
            color,
            expect,
            allow_zero,
            dry_run,
            report,
            true,
            transaction=Json::null(),
          ),
          docx_cli_default_max_output_chars -
          format_report_transaction_reserve(file, output),
        )
      })
  }
  let result = @office_docx.transact_docx_format(
    options,
    format~,
    text?,
    within?,
    nth?,
    range?,
    expect?,
    allow_zero~,
    preflight?,
  ) catch {
    error => raise map_format_failure(error)
  }
  let record = format_report_json(
    file,
    output,
    text,
    within,
    range,
    nth,
    bold,
    italic,
    underline,
    color,
    expect,
    allow_zero,
    dry_run,
    result.report(),
    result.transaction().changed,
    transaction=result.transaction().to_json(),
  )
  match mode {
    JsonDocument | JsonLines => {
      let warnings = []
      for warning in result.transaction().warning_records() {
        warnings.push(warning)
      }
      let payload = bounded_docx_payload(
        record, warnings, docx_cli_default_max_output_chars,
      ) catch {
        _ =>
          raise CliFailure(
            @lib.protocol_error(
              "office.format.report_internal",
              "internal: the format report exceeded the output ceiling despite the preflight; the edit itself completed and \{output} is valid",
            ),
          )
      }
      println(checked_office_json_output(payload))
    }
    Human => {
      let verb = if dry_run { "would format" } else { "formatted" }
      println(
        "format: " +
        verb +
        " \{result.report().spans().length()} span(s) across \{result.report().affected_paths().length()} paragraph(s) -> " +
        human_text(output, 160),
      )
      for warning in result.transaction().warning_records() {
        println(
          "warning [\{human_text(warning.code, 160)}]: \{human_text(warning.message, 320)}",
        )
      }
    }
  }
}

///|
/// Map a transaction-layer failure to the CLI contract, preserving the
/// typed codes the transaction raises (`office.format.no_match`,
/// `office.format.expect_mismatch`, the planner's refusal slugs, and
/// the shared preflight's protection codes).
fn map_format_failure(error : Error) -> CliFailure {
  match error {
    CliFailure(_) as failure => failure
    @transaction.TransactionError(_) as failure => transaction_failure(failure)
    _ => unexpected_cli_failure("office.format.failed", "format", error)
  }
}
