// `office insert-paragraph` — the N3a structural verb. The CLI half
// owns REQUEST policy: the anchor flags, the `docx.paragraph/1`
// payload parse, and the output contract. Minting, planning, and the
// identity readback live in the engine and the transaction.

///|
fn insert_paragraph_command() -> @argparse.Command {
  let summary = match @lib.find_capability_command("insert-paragraph") {
    Some(command) => command.summary
    None =>
      "Insert one resource-free paragraph beside a direct body paragraph, minting its stable identity"
  }
  Command(
    "insert-paragraph",
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
        "before",
        long="before",
        about="insert before this DIRECT body paragraph (p[3]); exclusive with --after",
      ),
      OptionArg(
        "after",
        long="after",
        about="insert after this DIRECT body paragraph (p[3]); exclusive with --before",
      ),
      OptionArg(
        "content",
        long="content",
        about="docx.paragraph/1 JSON: {\"style\"?: \"StyleId\", \"runs\": [{\"text\": \"…\", \"bold\"?, \"italic\"?, \"underline\"?}]} — resource-free only; style ids must exist in the target",
      ),
    ],
    flags=[
      FlagArg(
        "dry-run",
        long="dry-run",
        about="run the identical mint/plan/validate pipeline, exit as the real run would, write nothing",
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
/// Parse the dedicated `docx.paragraph/1` payload. Strict: unknown
/// keys, wrong types, and non-boolean flags refuse naming the field —
/// a typo must fail loudly, not silently drop formatting.
fn parse_insert_paragraph_content(
  payload : String,
) -> @docx.DocxInsertContent raise CliFailure {
  fn refuse(reason : String) -> CliFailure {
    docx_cli_failure(
      "office.invalid_arguments",
      "--content is a docx.paragraph/1 payload: " + reason,
    )
  }
  // Duplicate members collapse last-wins in a parsed object, so the
  // RAW text is scanned first: two spellings of the same key in the
  // same object refuse before any value is trusted.
  match insert_payload_duplicate_key(payload) {
    Some(key) => raise refuse("duplicate member \"" + key + "\"")
    None => ()
  }
  let parsed : Json = @json.parse(payload) catch {
    _ => raise refuse("the value is not valid JSON")
  }
  guard parsed is Object(fields) else {
    raise refuse("the payload is a JSON object")
  }
  let mut style : String? = None
  let runs : Array[@docx.DocxInsertRun] = []
  for key, value in fields {
    match key {
      "style" =>
        match value {
          String(name) => style = Some(name)
          _ => raise refuse("\"style\" is a string style id")
        }
      "runs" => {
        guard value is Array(entries) else {
          raise refuse("\"runs\" is an array of run objects")
        }
        for entry in entries {
          guard entry is Object(run_fields) else {
            raise refuse("each run is an object")
          }
          let mut text : String? = None
          let mut bold = false
          let mut italic = false
          let mut underline = false
          for run_key, run_value in run_fields {
            match run_key {
              "text" =>
                match run_value {
                  String(content) => text = Some(content)
                  _ => raise refuse("\"text\" is a string")
                }
              "bold" =>
                match run_value {
                  True => bold = true
                  False => bold = false
                  _ => raise refuse("\"bold\" is a boolean")
                }
              "italic" =>
                match run_value {
                  True => italic = true
                  False => italic = false
                  _ => raise refuse("\"italic\" is a boolean")
                }
              "underline" =>
                match run_value {
                  True => underline = true
                  False => underline = false
                  _ => raise refuse("\"underline\" is a boolean")
                }
              other => raise refuse("unknown run key \"" + other + "\"")
            }
          }
          guard text is Some(content) else {
            raise refuse("each run carries \"text\"")
          }
          runs.push({ text: content, bold, italic, underline, })
        }
      }
      other => raise refuse("unknown key \"" + other + "\"")
    }
  }
  { style, runs, }
}

///|
async fn run_insert_paragraph(matches : @argparse.Matches) -> Unit {
  let file = required_value(matches, "file")
  let output = required_value(matches, "out")
  let mode = office_validate_output_mode(matches)
  guard file.to_lower().has_suffix(".docx") else {
    raise CliFailure(
      @lib.protocol_error(
        "office.invalid_arguments", "insert-paragraph requires a .docx document",
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
  let before_anchor = optional_value(matches, "before")
  let after_anchor = optional_value(matches, "after")
  let (at, before) = match (before_anchor, after_anchor) {
    (Some(_), Some(_)) =>
      raise CliFailure(
        @lib.protocol_error(
          "office.invalid_arguments", "--before and --after are exclusive; an insertion has one side",
        ),
      )
    (Some(anchor), None) => (anchor, true)
    (None, Some(anchor)) => (anchor, false)
    (None, None) =>
      raise CliFailure(
        @lib.protocol_error(
          "office.invalid_arguments", "insert-paragraph requires --before or --after with a direct body paragraph path (p[3])",
        ),
      )
  }
  let payload = match optional_value(matches, "content") {
    Some(value) => value
    None =>
      raise CliFailure(
        @lib.protocol_error(
          "office.invalid_arguments", "insert-paragraph requires --content with a docx.paragraph/1 JSON payload",
        ),
      )
  }
  let content = parse_insert_paragraph_content(payload)
  let dry_run = matches.flags.get_or_default("dry-run", false)
  let options = @transaction.transaction_options(
    file,
    output_path=output,
    dry_run~,
    overwrite=matches.flags.get_or_default("overwrite", false),
  ) catch {
    error => raise transaction_failure(error)
  }
  let result = @office_docx.transact_docx_insert_paragraph(
    options,
    at~,
    before~,
    content~,
  ) catch {
    error => raise map_insert_paragraph_failure(error)
  }
  match mode {
    // The record is FIXED-SIZE (one path, one eight-hex id, the
    // bounded transaction report) — it cannot approach the output
    // ceiling, so no in-transaction preflight is needed; the bounded
    // emission is still the shared exit for JSON.
    JsonDocument | JsonLines => {
      let record = Json::object({
        "schema": Json::string("office.docx.insert-paragraph/1"),
        "file": Json::string(file),
        "format": Json::string("docx"),
        "output": Json::string(output),
        "at": Json::string(at),
        "side": Json::string(if before { "before" } else { "after" }),
        "dry_run": Json::boolean(dry_run),
        "path": Json::string(result.report().path()),
        "para_id": Json::string(result.report().para_id()),
        "changed": Json::boolean(result.transaction().changed),
        "transaction": result.transaction().to_json(),
      })
      let payload = bounded_docx_payload(
        record,
        [],
        docx_cli_default_max_output_chars,
      )
      println(checked_office_json_output(payload))
    }
    Human => {
      let verb = if dry_run { "would insert" } else { "inserted" }
      println(
        "insert-paragraph: " +
        verb +
        " \{result.report().path()} (w14:paraId \{result.report().para_id()}) -> " +
        human_text(output, 160),
      )
    }
  }
}

///|
/// Map a transaction-layer failure to the CLI contract, preserving the
/// typed codes the transaction raises.
fn map_insert_paragraph_failure(error : Error) -> CliFailure {
  match error {
    CliFailure(_) as failure => failure
    @transaction.TransactionError(_) as failure => transaction_failure(failure)
    _ =>
      unexpected_cli_failure(
        "office.insert_paragraph.failed", "insert-paragraph", error,
      )
  }
}

///|
/// A string-aware, frame-aware scan for duplicate object members in
/// the raw payload text. Frames get identities on '{'; a key seen
/// twice in ONE frame is the duplicate — the same key in two sibling
/// run objects is fine. Malformed text returns None and lets the JSON
/// parser produce its own refusal.
fn insert_payload_duplicate_key(text : String) -> String? {
  let units = text.code_units()
  let seen : Map[String, Bool] = Map([])
  let frames : Array[Int] = []
  let mut next_frame = 0
  let mut expecting_key = false
  let mut index = 0
  while index < units.length() {
    let unit = units[index].to_int()
    if unit == '"'.to_int() {
      // Read the string verbatim, honouring escapes.
      let start = index + 1
      let mut end = start
      let mut escaped = false
      while end < units.length() {
        let inner = units[end].to_int()
        if escaped {
          escaped = false
        } else if inner == '\\'.to_int() {
          escaped = true
        } else if inner == '"'.to_int() {
          break
        }
        end += 1
      }
      if expecting_key && frames.length() > 0 {
        let builder = StringBuilder()
        for at in start..<end {
          match units[at].to_int().to_char() {
            Some(character) => builder.write_char(character)
            None => ()
          }
        }
        let key = "\{frames[frames.length() - 1]}:" + builder.to_string()
        if seen.contains(key) {
          return Some(builder.to_string())
        }
        seen[key] = true
        expecting_key = false
      }
      index = end + 1
      continue
    }
    if unit == '{'.to_int() {
      frames.push(next_frame)
      next_frame += 1
      expecting_key = true
    } else if unit == '}'.to_int() {
      if frames.length() > 0 {
        ignore(frames.pop())
      }
      expecting_key = false
    } else if unit == ','.to_int() {
      expecting_key = frames.length() > 0
    } else if unit == ':'.to_int() || unit == '['.to_int() {
      expecting_key = false
    }
    index += 1
  }
  None
}
