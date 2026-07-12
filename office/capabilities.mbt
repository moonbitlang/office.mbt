///|
/// One declared input or output field in the Office capability registry.
pub(all) struct CapabilityField {
  name : String
  type_name : String
  required : Bool
  description : String
}

///|
/// One document format exposed by the canonical Office command.
pub(all) struct CapabilityFormat {
  name : String
  aliases : Array[String]
  description : String
}

///|
/// One implemented command exposed by the canonical Office command.
pub(all) struct CapabilityCommand {
  name : String
  summary : String
  usage : String
  formats : Array[String]
  aliases : Array[String]
  inputs : Array[CapabilityField]
  outputs : Array[CapabilityField]
  output_modes : Array[String]
}

///|
fn capability_field(
  name : String,
  type_name : String,
  required : Bool,
  description : String,
) -> CapabilityField {
  { name, type_name, required, description }
}

///|
/// Returns the canonical document-format declarations in stable order.
pub fn capability_formats() -> Array[CapabilityFormat] {
  [
    {
      name: "docx",
      aliases: ["word"],
      description: "WordprocessingML documents",
    },
    { name: "xlsx", aliases: ["excel"], description: "SpreadsheetML workbooks" },
  ]
}

///|
/// Returns implemented command declarations in stable order. An empty
/// `formats` array marks a format-neutral command.
pub fn capability_commands() -> Array[CapabilityCommand] {
  [
    {
      name: "help",
      summary: "Show the implemented Office capability registry",
      usage: "office help [all|docx|xlsx] [operation] [element] [--json|--jsonl]",
      formats: [],
      aliases: [],
      inputs: [
        capability_field(
          "topic", "string", false, "optional format, operation, or element help token",
        ),
        capability_field(
          "json", "boolean", false, "emit one office.output/1 JSON document",
        ),
        capability_field(
          "jsonl", "boolean", false, "emit one self-contained capability record per line",
        ),
      ],
      outputs: [
        capability_field(
          "fingerprint", "string", true, "deterministic registry fingerprint",
        ),
        capability_field(
          "records", "array", true, "truthful implemented formats, commands, and fields",
        ),
      ],
      output_modes: ["human", "json", "jsonl"],
    },
    {
      name: "identify",
      summary: "Identify a structurally valid XLSX or DOCX package",
      usage: "office identify <file> [--json]",
      formats: ["docx", "xlsx"],
      aliases: [],
      inputs: [
        capability_field(
          "file", "path", true, "path to an XLSX or DOCX package",
        ),
        capability_field(
          "json", "boolean", false, "emit one office.output/1 JSON document",
        ),
      ],
      outputs: [
        capability_field(
          "file", "path", true, "the input path exactly as supplied",
        ),
        capability_field(
          "format", "enum(docx|xlsx)", true, "the structurally verified package format",
        ),
      ],
      output_modes: ["human", "json"],
    },
  ]
}

///|
/// Resolves a canonical format name or supported alias. Matching is ASCII
/// case-insensitive; PowerPoint aliases are deliberately absent.
pub fn resolve_format_alias(value : StringView) -> DocumentFormat? {
  match value.to_owned().to_lower() {
    "docx" | "word" => Some(Docx)
    "xlsx" | "excel" => Some(Xlsx)
    _ => None
  }
}

///|
/// Finds an implemented command by canonical name or alias.
pub fn find_capability_command(value : StringView) -> CapabilityCommand? {
  let normalized = value.to_owned().to_lower()
  for command in capability_commands() {
    if command.name == normalized || command.aliases.contains(normalized) {
      return Some(command)
    }
  }
  None
}

///|
fn json_strings(values : Array[String]) -> Json {
  Json::array(values.map(value => Json::string(value)))
}

///|
fn capability_field_json(field : CapabilityField) -> Json {
  Json::object({
    "name": Json::string(field.name),
    "type": Json::string(field.type_name),
    "required": Json::boolean(field.required),
    "description": Json::string(field.description),
  })
}

///|
fn capability_format_json(
  format : CapabilityFormat,
  fingerprint : String,
) -> Json {
  Json::object({
    "schema": Json::string("office.capability/1"),
    "fingerprint": Json::string(fingerprint),
    "kind": Json::string("format"),
    "name": Json::string(format.name),
    "aliases": json_strings(format.aliases),
    "description": Json::string(format.description),
  })
}

///|
fn capability_command_json(
  command : CapabilityCommand,
  fingerprint : String,
) -> Json {
  Json::object({
    "schema": Json::string("office.capability/1"),
    "fingerprint": Json::string(fingerprint),
    "kind": Json::string("command"),
    "name": Json::string(command.name),
    "summary": Json::string(command.summary),
    "usage": Json::string(command.usage),
    "formats": json_strings(command.formats),
    "aliases": json_strings(command.aliases),
    "inputs": Json::array(command.inputs.map(capability_field_json)),
    "outputs": Json::array(command.outputs.map(capability_field_json)),
    "output_modes": json_strings(command.output_modes),
  })
}

///|
fn append_fingerprint_token(buffer : StringBuilder, value : String) -> Unit {
  buffer.write_string(value.length().to_string()) |> ignore
  buffer.write_char(':') |> ignore
  buffer.write_string(value) |> ignore
  buffer.write_char(';') |> ignore
}

///|
fn append_fingerprint_field(
  buffer : StringBuilder,
  field : CapabilityField,
) -> Unit {
  append_fingerprint_token(buffer, field.name)
  append_fingerprint_token(buffer, field.type_name)
  append_fingerprint_token(buffer, if field.required { "1" } else { "0" })
  append_fingerprint_token(buffer, field.description)
}

///|
fn capability_fingerprint_source() -> String {
  let buffer = StringBuilder::new()
  append_fingerprint_token(buffer, "office.capabilities/1")
  for format in capability_formats() {
    append_fingerprint_token(buffer, "format")
    append_fingerprint_token(buffer, format.name)
    for alternate in format.aliases {
      append_fingerprint_token(buffer, alternate)
    }
    append_fingerprint_token(buffer, format.description)
  }
  for command in capability_commands() {
    append_fingerprint_token(buffer, "command")
    append_fingerprint_token(buffer, command.name)
    append_fingerprint_token(buffer, command.summary)
    append_fingerprint_token(buffer, command.usage)
    for format in command.formats {
      append_fingerprint_token(buffer, format)
    }
    for alternate in command.aliases {
      append_fingerprint_token(buffer, alternate)
    }
    for input in command.inputs {
      append_fingerprint_field(buffer, input)
    }
    for output in command.outputs {
      append_fingerprint_field(buffer, output)
    }
    for mode in command.output_modes {
      append_fingerprint_token(buffer, mode)
    }
  }
  buffer.to_string()
}

///|
/// Returns the deterministic CRC-32 fingerprint of every registry declaration.
pub fn capability_fingerprint() -> String {
  let raw = @zip.crc32(@utf8.encode(capability_fingerprint_source())).to_string(
    radix=16,
  )
  "crc32:" + "0".repeat(8 - raw.length()) + raw
}

///|
fn command_supports_format(
  command : CapabilityCommand,
  format : DocumentFormat,
) -> Bool {
  command.formats.contains(format.name())
}

///|
/// Returns self-contained registry records in stable order. With a format
/// filter, format-neutral commands are omitted and only commands that operate
/// on that document format remain.
pub fn capability_records(
  format? : DocumentFormat,
  operation? : String,
) -> Array[Json] {
  let fingerprint = capability_fingerprint()
  let records : Array[Json] = []
  match operation {
    Some(name) => {
      let normalized = name.to_lower()
      for command in capability_commands() {
        let format_matches = match format {
          Some(selected) => command_supports_format(command, selected)
          None => true
        }
        if format_matches &&
          (command.name == normalized || command.aliases.contains(normalized)) {
          records.push(capability_command_json(command, fingerprint))
        }
      }
      return records
    }
    None => ()
  }
  match format {
    Some(selected) => {
      for declared in capability_formats() {
        if declared.name == selected.name() {
          records.push(capability_format_json(declared, fingerprint))
        }
      }
      for command in capability_commands() {
        if command_supports_format(command, selected) {
          records.push(capability_command_json(command, fingerprint))
        }
      }
    }
    None => {
      for declared in capability_formats() {
        records.push(capability_format_json(declared, fingerprint))
      }
      for command in capability_commands() {
        records.push(capability_command_json(command, fingerprint))
      }
    }
  }
  records
}

///|
/// Returns the versioned capability inventory used by JSON help output.
pub fn capabilities_data(format? : DocumentFormat, operation? : String) -> Json {
  let records = match (format, operation) {
    (Some(selected), Some(name)) =>
      capability_records(format=selected, operation=name)
    (Some(selected), None) => capability_records(format=selected)
    (None, Some(name)) => capability_records(operation=name)
    (None, None) => capability_records()
  }
  let fields : Map[String, Json] = {
    "schema": Json::string("office.capabilities/1"),
    "fingerprint": Json::string(capability_fingerprint()),
    "records": Json::array(records),
  }
  match format {
    Some(selected) => fields["format"] = Json::string(selected.name())
    None => ()
  }
  match operation {
    Some(name) => fields["operation"] = Json::string(name.to_lower())
    None => ()
  }
  Json::object(fields)
}
