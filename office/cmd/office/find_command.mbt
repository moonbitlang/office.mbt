// `office find` — the read-only hit lister (N2a).
//
// This is the surface an agent uses BEFORE writing. It answers "where is
// this text, and would an edit there be allowed?" in one read, which
// matters because an agent cannot look at a rendered document to check
// its own work afterwards.

///|
/// Hard ceiling on returned candidates, so a needle matching everything
/// cannot produce an unbounded document.
const DOCX_FIND_HARD_LIMIT : Int = 1000

///|
/// Default ceiling, chosen to be generous for real edits while still
/// bounding an accidental single-character needle.
const DOCX_FIND_DEFAULT_LIMIT : Int = 100

///|
fn docx_find_command() -> @argparse.Command {
  Command(
    "find",
    about="List every literal text candidate in a DOCX, with whether an edit there is allowed",
    positionals=[PositionArg("file", num_args=@argparse.ValueRange::single())],
    options=[
      OptionArg(
        "text",
        long="text",
        about="literal text to find — never a regular expression or wildcard",
      ),
      OptionArg(
        "in",
        long="in",
        about="restrict to a body-relative subtree, e.g. p[3] or tbl[1]",
      ),
      OptionArg(
        "limit",
        long="limit",
        about="maximum returned candidates (default \{DOCX_FIND_DEFAULT_LIMIT}, hard limit \{DOCX_FIND_HARD_LIMIT})",
      ),
      OptionArg(
        "context",
        long="context",
        about="projection characters of context on each side (default 24, maximum 200)",
      ),
    ],
    flags=[docx_json_flag()],
  )
}

///|
/// One candidate as `office.docx.matches/1` JSON.
fn docx_find_entry_json(hit : @docx.DocxMatch) -> Json {
  Json::object({
    "ordinal": Json::number(hit.ordinal().to_double()),
    "story": Json::string(hit.story()),
    "path": Json::string(hit.path()),
    "range": Json::object({
      "start": Json::number(hit.start().to_double()),
      "end": Json::number(hit.end().to_double()),
      "unit": Json::string("utf16"),
    }),
    "text": Json::string(hit.text()),
    "context_before": Json::string(hit.context_before()),
    "context_after": Json::string(hit.context_after()),
    "runs": Json::array(hit.runs().map(path => Json::string(path))),
    "source_kinds": Json::array(hit.run_kinds().map(k => Json::string(k))),
    "actionable": Json::boolean(hit.actionable()),
    // Null rather than "" when actionable: an agent testing the field
    // for presence should not have to know that empty means allowed.
    "reason": if hit.actionable() {
      Json::null()
    } else {
      Json::string(hit.reason())
    },
  })
}

///|
/// The `office.docx.matches/1` payload.
fn docx_find_payload(
  file : String,
  needle : String,
  within : String?,
  hits : Array[@docx.DocxMatch],
  limit : Int,
) -> BoundedOfficePayload raise CliFailure {
  let shown = if hits.length() > limit { limit } else { hits.length() }
  let entries : Array[Json] = []
  for index in 0..<shown {
    entries.push(docx_find_entry_json(hits[index]))
  }
  let mut actionable = 0
  for hit in hits {
    if hit.actionable() {
      actionable = actionable + 1
    }
  }
  let data = Json::object({
    "schema": Json::string(@lib.SCHEMA_DOCX_MATCHES),
    "file": Json::string(file),
    "format": Json::string("docx"),
    "text": Json::string(needle),
    "in": match within {
      Some(prefix) => Json::string(prefix)
      None => Json::null()
    },
    "stories_scanned": Json::array([Json::string("/body")]),
    "matches": Json::array(entries),
    // Totals are of ALL candidates, not of the returned page, so a
    // truncated read still reports the true shape of the document.
    "matches_total": Json::number(hits.length().to_double()),
    "actionable_total": Json::number(actionable.to_double()),
    "unactionable_total": Json::number((hits.length() - actionable).to_double()),
    "truncated": Json::boolean(hits.length() > shown),
  })
  bounded_docx_payload(data, [], docx_cli_default_max_output_chars)
}

///|
/// Human output. One line per candidate, refusals marked, because the
/// first thing a person wants is which hits they cannot act on.
fn docx_find_human(
  needle : String,
  hits : Array[@docx.DocxMatch],
  limit : Int,
) -> String {
  // Lines are JOINED rather than each terminated: the success emitter
  // supplies the final newline, and terminating here too prints a blank
  // line that the other read commands do not.
  let lines : Array[String] = []
  if hits.length() == 0 {
    lines.push("no candidates for '\{needle}'")
  } else {
    let shown = if hits.length() > limit { limit } else { hits.length() }
    for index in 0..<shown {
      let hit = hits[index]
      let head = "\{hit.ordinal()}. \{hit.path()} [\{hit.start()},\{hit.end()}) \{hit.text()}"
      lines.push(
        if hit.actionable() {
          head
        } else {
          head + "  -- NOT EDITABLE: " + hit.reason()
        },
      )
    }
    if hits.length() > shown {
      lines.push(
        "... \{hits.length() - shown} more (raise --limit to see them)",
      )
    }
  }
  lines.join("\n")
}

///|
/// `office find FILE --text NEEDLE`.
///
/// A read: zero candidates is success with an empty list, because the
/// absence of a match is a fact about the document rather than a failure
/// of the request. What refuses is a malformed request — no `--text`, an
/// empty needle — or a document that cannot be read safely.
async fn run_docx_find(matches : @argparse.Matches) -> Unit {
  let file = required_value(matches, "file")
  // Both shapes of a missing needle are REQUEST errors, and both report
  // as one. Letting the empty case fall through to the library made it
  // surface as a document read failure, which tells an agent to distrust
  // the file when the fault is in the call.
  let needle = match optional_value(matches, "text") {
    Some(value) if value != "" => value
    Some(_) =>
      raise docx_cli_failure(
        "office.invalid_arguments",
        "find requires a non-empty --text; an empty needle matches every position",
        details=Json::object({ "argument": Json::string("text") }),
      )
    None =>
      raise docx_cli_failure(
        "office.invalid_arguments",
        "find requires --text with the literal text to look for",
        details=Json::object({ "argument": Json::string("text") }),
      )
  }
  let within = optional_value(matches, "in")
  let limit = bounded_decimal_argument(
    matches,
    "limit",
    DOCX_FIND_DEFAULT_LIMIT,
    0,
    DOCX_FIND_HARD_LIMIT,
  )
  let context = bounded_decimal_argument(matches, "context", 24, 0, 200)
  let source = read_office_package(file, cancelled=() => {
    @async.is_being_cancelled()
  })
  match source.format {
    Docx => {
      let annotated = open_docx_mutation_annotated_archive(
        file,
        source.archive,
        cancelled=office_async_cancelled,
      )
      let hits = @docx.find_docx_matches(
        annotated,
        annotated.main_story_source(),
        needle~,
        within?,
        context~,
        limit~,
      ) catch {
        error => raise docx_reader_failure(error, file)
      }
      if matches.flags.get_or_default("json", false) {
        emit_docx_success(
          checked_docx_json_output(
            docx_find_payload(file, needle, within, hits, limit),
          ),
        )
      } else {
        emit_docx_success(
          checked_docx_human_output(
            docx_find_human(needle, hits, limit),
            docx_cli_default_max_output_chars,
          ),
        )
      }
    }
    _ =>
      raise docx_cli_failure(
        "office.unsupported_format", "find reads .docx packages; use `office query` for .xlsx",
      )
  }
}
