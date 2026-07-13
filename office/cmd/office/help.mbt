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
  for left_index = 0
      left_index < left_chars.length()
      left_index = left_index + 1 {
    let current = Array::make(right_chars.length() + 1, 0)
    current[0] = left_index + 1
    for right_index = 0
        right_index < right_chars.length()
        right_index = right_index + 1 {
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
fn nearest_suggestion_with_distance(
  value : String,
  candidates : Array[String],
) -> (String, Int)? {
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
  if best <= 2 {
    nearest.map(candidate => (candidate, best))
  } else {
    None
  }
}

///|
fn nearest_suggestion(value : String, candidates : Array[String]) -> String? {
  nearest_suggestion_with_distance(value, candidates).map(result => result.0)
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
fn format_help_tokens() -> Array[String] {
  let tokens = ["all"]
  for format in @lib.capability_formats() {
    tokens.push(format.name)
    for alternate in format.aliases {
      tokens.push(alternate)
    }
  }
  tokens
}

///|
fn operation_help_tokens(format? : @lib.DocumentFormat) -> Array[String] {
  let tokens : Array[String] = []
  for command in @lib.capability_commands() {
    let supported = match format {
      Some(selected) => command_supports_format(command, selected)
      None => true
    }
    if supported {
      tokens.push(command.name)
      for alternate in command.aliases {
        tokens.push(alternate)
      }
    }
  }
  tokens
}

///|
fn unknown_first_help_token(value : String) -> @lib.ProtocolError {
  let formats = format_help_tokens()
  let operations = operation_help_tokens()
  let format_match = nearest_suggestion_with_distance(value, formats)
  let operation_match = nearest_suggestion_with_distance(value, operations)
  match (format_match, operation_match) {
    (Some((_, format_distance)), Some((_, operation_distance))) =>
      if operation_distance < format_distance {
        unknown_help_token("operation", value, operations)
      } else {
        unknown_help_token("format", value, formats)
      }
    (Some(_), None) => unknown_help_token("format", value, formats)
    (None, Some(_)) => unknown_help_token("operation", value, operations)
    (None, None) => {
      let topics = formats.copy()
      for operation in operations {
        topics.push(operation)
      }
      unknown_help_token("topic", value, topics)
    }
  }
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
      raise CliFailure(unknown_help_token("element", value, []))
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
            unknown_help_token(
              "operation",
              operation,
              operation_help_tokens(format~),
            ),
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
        None => raise CliFailure(unknown_first_help_token(first))
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
  if !command.variants.is_empty() {
    lines.push("  Variants:")
    for variant in command.variants {
      lines.push("    \{variant.name}: \{variant.usage}")
      for field in variant.inputs {
        lines.push("  " + render_field(field))
      }
      if !variant.constraints.is_empty() {
        lines.push("      constraints: " + variant.constraints.join(", "))
      }
    }
  }
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
  let (aliases, description, selector) = match declaration {
    Some(declared) =>
      (declared.aliases, declared.description, Some(declared.selector))
    None => ([], "", None)
  }
  let heading = if aliases.is_empty() {
    "Format: \{format.name()}"
  } else {
    "Format: \{format.name()} (aliases: \{aliases.join(", ")})"
  }
  let lines : Array[String] = [heading, "  \{description}"]
  match selector {
    Some(syntax) => {
      lines.push(
        "  Selector: \{syntax.schema} \{syntax.root} (\{syntax.status})",
      )
      lines.push("    \{syntax.description}")
      for example in syntax.examples {
        lines.push("    \{example}")
      }
    }
    None => ()
  }
  lines.push("  Implemented commands:")
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
    "  Schema: " + @lib.SCHEMA_CAPABILITIES,
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
      for variant in command.variants {
        lines.push("    \{variant.usage}")
      }
    }
  }
  lines.push(
    "Use 'office help <format>' or 'office help <format> <operation>'.",
  )
  lines.join("\n")
}

///|
fn records_for_query(query : HelpQuery) -> Array[Json] {
  match query {
    Overview | All => @lib.capability_records()
    Format(format) => @lib.capability_records(format~)
    Operation(Some(format), command) =>
      @lib.capability_records(format~, operation=command.name)
    Operation(None, command) => @lib.capability_records(operation=command.name)
  }
}

///|
fn data_for_query(query : HelpQuery) -> Json {
  match query {
    Overview | All => @lib.capabilities_data()
    Format(format) => @lib.capabilities_data(format~)
    Operation(Some(format), command) =>
      @lib.capabilities_data(format~, operation=command.name)
    Operation(None, command) => @lib.capabilities_data(operation=command.name)
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
        "office.output_mode_conflict", "--json and --jsonl are mutually exclusive",
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
