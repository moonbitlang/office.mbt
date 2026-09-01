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
        about="literal text to format — never a regular expression; matched over the reader PROJECTION, so it spans run boundaries. Every occurrence is selected unless --nth narrows it",
      ),
      OptionArg(
        "in",
        long="in",
        about="restrict to a body-relative subtree (p[3], tbl[1]) or a stable p[id=\"…\"]; required by --range, which needs ONE paragraph",
      ),
      OptionArg(
        "range",
        long="range",
        about="format a paragraph-local unit range START:END (the units `office find` and `office get` report), instead of --text; requires --in naming one paragraph",
      ),
      OptionArg(
        "nth",
        long="nth",
        about="select ONE text occurrence by ordinal (1-based, counted over all occurrences)",
      ),
      OptionArg(
        "bold",
        long="bold",
        about="on|off — set or clear bold explicitly; omitted properties are left untouched",
      ),
      OptionArg("italic", long="italic", about="on|off — set or clear italic"),
      OptionArg(
        "underline",
        long="underline",
        about="on|off — set or clear single underline",
      ),
      OptionArg(
        "color",
        long="color",
        about="RRGGBB or #RRGGBB — set an absolute text colour (theme linkage is removed; the engine refuses if it cannot)",
      ),
      OptionArg(
        "expect",
        long="expect",
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
/// Slack reserved for the transaction fields the preflight measures as
/// null — the same bound the replace verb reserves, for the same shape.
let format_report_transaction_slack : Int = 64 * 1024

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
  if range is Some(_) && within is None {
    raise CliFailure(
      @lib.protocol_error(
        "office.invalid_arguments", "--range needs --in naming the ONE paragraph its units index into",
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
          docx_cli_default_max_output_chars - format_report_transaction_slack,
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
      let payload = bounded_docx_payload(
        record,
        [],
        docx_cli_default_max_output_chars,
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
