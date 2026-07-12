///|
enum HelpQuery {
  Overview
  All
  Format(@lib.DocumentFormat)
  Operation(@lib.DocumentFormat?, @lib.CapabilityCommand)
}

///|
fn optional_value(matches : @argparse.Matches, name : String) -> String? {
  match matches.values.get(name) {
    Some([value, ..]) => Some(value)
    _ => None
  }
}

///|
fn edit_distance(left : String, right : String) -> Int {
  let left_chars = left.to_array()
  let right_chars = right.to_array()
  let mut previous = Array::make(right_chars.length() + 1, 0)
  for index = 0; index <= right_chars.length(); index = index + 1 {
    previous[index] = index
  }
  for left_index = 0; left_index < left_chars.length(); left_index = left_index + 1 {
    let current = Array::make(right_chars.length() + 1, 0)
    current[0] = left_index + 1
    for right_index = 0; right_index < right_chars.length(); right_index = right_index + 1 {
      let cost = if left_chars[left_index] == right_chars[right_index] {
        0
      } else {
        1
      }
      let substitution = previous[right_index] + cost
      let insertion = current[right_index] + 1
      let deletion = previous[right_index + 1] + 1
      current[right_index + 1] = substitution.min(insertion).min(deletion)
    }
    previous = current
  }
  previous[right_chars.length()]
}

///|
fn nearest_suggestion(value : String, candidates : Array[String]) -> String? {
  let bounded = bounded_text(value.to_lower(), 64)
  let mut nearest : String? = None
  let mut best = 1_000_000
  for candidate in candidates {
    let distance = edit_distance(bounded, candidate)
    if distance < best {
      best = distance
      nearest = Some(candidate)
    }
  }
  if best <= 2 { nearest } else { None }
}

///|
fn unknown_help_token(
  kind : String,
  value : String,
  candidates : Array[String],
) -> @lib.ProtocolError {
  let bounded = bounded_text(value, 80)
  let suggestion = nearest_suggestion(bounded, candidates)
  let message = match (suggestion, candidates) {
    (Some(candidate), _) =>
      "unknown \{kind} '\{bounded}'; did you mean '\{candidate}'?"
    (None, []) =>
      "unknown \{kind} '\{bounded}'; no \{kind} capabilities are implemented for this operation"
    (None, _) =>
      "unknown \{kind} '\{bounded}'; expected one of: " + candidates.join(", ")
  }
  let suggestions = match suggestion {
    Some(candidate) => [Json::string(candidate)]
    None => candidates.map(candidate => Json::string(candidate))
  }
  @lib.protocol_error(
    "office.unknown_\{kind}",
    message,
    details=Json::object({
      "kind": Json::string(kind),
      "token": Json::string(bounded),
      "suggestions": Json::array(suggestions),
    }),
  )
}

///|
fn command_supports_format(
  command : @lib.CapabilityCommand,
  format : @lib.DocumentFormat,
) -> Bool {
  command.formats.contains(format.name())
}

///|
fn resolve_help_query(
  first : String?,
  second : String?,
  third : String?,
) -> HelpQuery raise CliFailure {
  guard first is Some(first) else { return Overview }
  let normalized = first.to_lower()
  if normalized == "all" {
    if second is Some(value) {
      raise CliFailure(
        unknown_help_token("operation", value, ["help", "identify"]),
      )
    }
    return All
  }
  match @lib.resolve_format_alias(normalized) {
    Some(format) => {
      guard second is Some(operation) else { return Format(format) }
      let command = match @lib.find_capability_command(operation) {
        Some(command) if command_supports_format(command, format) => command
        _ =>
          raise CliFailure(
            unknown_help_token("operation", operation, ["identify"]),
          )
      }
      if third is Some(element) {
        raise CliFailure(unknown_help_token("element", element, []))
      }
      Operation(Some(format), command)
    }
    None =>
      match @lib.find_capability_command(normalized) {
        Some(command) => {
          if second is Some(element) {
            raise CliFailure(unknown_help_token("element", element, []))
          }
          Operation(None, command)
        }
        None =>
          raise CliFailure(
            unknown_help_token(
              "format",
              first,
              ["all", "docx", "word", "xlsx", "excel"],
            ),
          )
      }
  }
}

///|
fn render_field(field : @lib.CapabilityField) -> String {
  let required = if field.required { "required" } else { "optional" }
  "    \{field.name} (\{field.type_name}, \{required}) — \{field.description}"
}

///|
fn render_command(command : @lib.CapabilityCommand) -> String {
  let lines : Array[String] = [
    "Command: \{command.name}",
    "  \{command.summary}",
    "  Usage: \{command.usage}",
  ]
  if !command.formats.is_empty() {
    lines.push("  Formats: " + command.formats.join(", "))
  }
  lines.push("  Inputs:")
  for field in command.inputs {
    lines.push(render_field(field))
  }
  lines.push("  Outputs:")
  for field in command.outputs {
    lines.push(render_field(field))
  }
  lines.push("  Output modes: " + command.output_modes.join(", "))
  lines.join("\n")
}

///|
fn render_format(format : @lib.DocumentFormat) -> String {
  let mut declaration : @lib.CapabilityFormat? = None
  for declared in @lib.capability_formats() {
    if declared.name == format.name() {
      declaration = Some(declared)
      break
    }
  }
  let (aliases, description) = match declaration {
    Some(declared) => (declared.aliases, declared.description)
    None => ([], "")
  }
  let heading = if aliases.is_empty() {
    "Format: \{format.name()}"
  } else {
    "Format: \{format.name()} (aliases: \{aliases.join(", ")})"
  }
  let lines : Array[String] = [
    heading,
    "  \{description}",
    "  Implemented commands:",
  ]
  for command in @lib.capability_commands() {
    if command_supports_format(command, format) {
      lines.push("    \{command.name} — \{command.summary}")
    }
  }
  lines.push("  Run: office help \{format.name()} identify")
  lines.join("\n")
}

///|
fn render_overview(verbose : Bool) -> String {
  let lines : Array[String] = [
    "Office capability registry",
    "  Schema: office.capabilities/1",
    "  Fingerprint: \{@lib.capability_fingerprint()}",
    "Formats:",
  ]
  for format in @lib.capability_formats() {
    let aliases = if format.aliases.is_empty() {
      ""
    } else {
      " (aliases: \{format.aliases.join(", ")})"
    }
    lines.push("  \{format.name}\{aliases} — \{format.description}")
  }
  lines.push("Commands:")
  for command in @lib.capability_commands() {
    lines.push("  \{command.name} — \{command.summary}")
    if verbose {
      lines.push("    \{command.usage}")
      lines.push("    output modes: \{command.output_modes.join(", ")}")
    }
  }
  lines.push("Use 'office help <format>' or 'office help <format> <operation>'.")
  lines.join("\n")
}

///|
fn records_for_query(query : HelpQuery) -> Array[Json] {
  match query {
    Overview | All => @lib.capability_records()
    Format(format) => @lib.capability_records(format~)
    Operation(Some(format), _) => @lib.capability_records(format~)
    Operation(None, _) => @lib.capability_records()
  }
}

///|
fn data_for_query(query : HelpQuery) -> Json {
  match query {
    Overview | All | Operation(None, _) => @lib.capabilities_data()
    Format(format) | Operation(Some(format), _) => @lib.capabilities_data(format~)
  }
}

///|
fn render_human_query(query : HelpQuery) -> String {
  match query {
    Overview => render_overview(false)
    All => render_overview(true)
    Format(format) => render_format(format)
    Operation(_, command) => render_command(command)
  }
}

///|
fn run_help(matches : @argparse.Matches) -> Unit raise CliFailure {
  let query = resolve_help_query(
    optional_value(matches, "first"),
    optional_value(matches, "second"),
    optional_value(matches, "third"),
  )
  let json = matches.flags.get_or_default("json", false)
  let jsonl = matches.flags.get_or_default("jsonl", false)
  if json && jsonl {
    raise CliFailure(
      @lib.protocol_error(
        "office.output_mode_conflict",
        "--json and --jsonl are mutually exclusive",
      ),
    )
  }
  if json {
    println(@lib.output_success(data_for_query(query)).stringify(indent=2))
  } else if jsonl {
    for record in records_for_query(query) {
      println(record.stringify())
    }
  } else {
    println(render_human_query(query))
  }
}

///|
fn help_command() -> @argparse.Command {
  let summary = match @lib.find_capability_command("help") {
    Some(command) => command.summary
    None => "Show the implemented Office capability registry"
  }
  Command(
    "help",
    about=summary,
    positionals=[
      PositionArg("first", num_args=ValueRange(lower=0, upper=1)),
      PositionArg("second", num_args=ValueRange(lower=0, upper=1)),
      PositionArg("third", num_args=ValueRange(lower=0, upper=1)),
    ],
    flags=[
      FlagArg("json", long="json", about="print office.output/1 JSON"),
      FlagArg("jsonl", long="jsonl", about="print one JSON record per line"),
    ],
  )
}
