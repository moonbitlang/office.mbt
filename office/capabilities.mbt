///|
/// Versioned schemas shared by capability declarations and result emitters.
pub const SCHEMA_CAPABILITIES : String = "office.capabilities/2"

///|
pub const SCHEMA_CAPABILITY : String = "office.capability/2"

///|
pub const SCHEMA_RAW_INVENTORY : String = "office.raw.inventory/1"

///|
pub const SCHEMA_RAW_PART : String = "office.raw.part/1"

///|
pub const SCHEMA_RAW_CHANGE : String = "office.raw.change/1"

///|
pub const SCHEMA_RAW_RESULT : String = "office.raw.result/1"

///|
pub const SCHEMA_TRANSACTION : String = "office.transaction/1"

///|
/// One declared input or output field in the Office capability registry.
pub(all) struct CapabilityField {
  name : String
  type_name : String
  required : Bool
  description : String
}

///|
/// The accepted argument shape and path restriction for one action value.
pub(all) struct CapabilityAction {
  name : String
  requires : Array[String]
  forbids : Array[String]
  restrictions : Array[String]
}

///|
/// One conditionally invokable subcommand schema within a command family.
pub(all) struct CapabilityVariant {
  name : String
  usage : String
  result_schema : String
  inputs : Array[CapabilityField]
  outputs : Array[CapabilityField]
  constraints : Array[String]
  actions : Array[CapabilityAction]
  output_modes : Array[String]
}

///|
/// The selector syntax declared for one document format. `status` describes
/// the strongest implemented behavior and must not imply document access.
pub(all) struct CapabilitySelector {
  schema : String
  root : String
  status : String
  examples : Array[String]
  description : String
}

///|
/// One document format exposed by the canonical Office command.
pub(all) struct CapabilityFormat {
  name : String
  aliases : Array[String]
  description : String
  selector : CapabilitySelector
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
  variants : Array[CapabilityVariant]
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
fn capability_action(
  name : String,
  requires : Array[String],
  forbids : Array[String],
  restrictions? : Array[String] = [],
) -> CapabilityAction {
  { name, requires, forbids, restrictions }
}

///|
/// Returns the canonical document-format declarations in stable order.
pub fn capability_formats() -> Array[CapabilityFormat] {
  [
    {
      name: "docx",
      aliases: ["word"],
      description: "WordprocessingML documents",
      selector: {
        schema: "office.selector/1",
        root: "/docx",
        status: "syntax-only",
        examples: ["/docx/body/p[1]/r[2]", "/docx/comments/comment[id=\"7\"]"],
        description: "bounded parse/render only; package resolution is not implemented",
      },
    },
    {
      name: "xlsx",
      aliases: ["excel"],
      description: "SpreadsheetML workbooks",
      selector: {
        schema: "office.selector/1",
        root: "/xlsx",
        status: "syntax-only",
        examples: [
          "/xlsx/sheet[name=\"Data\"]/cell[A1]", "/xlsx/sheet[name=\"Data\"]/range[A1:C12]",
        ],
        description: "bounded parse/render only; workbook resolution is not implemented",
      },
    },
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
      usage: "office help [all|<format>|<operation>|<format> <operation>] [--json|--jsonl]",
      formats: [],
      aliases: [],
      inputs: [
        capability_field(
          "query", "enum(all)|format|operation|format+operation", false, "optional all, format, operation, or format-operation query",
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
      variants: [],
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
      variants: [],
    },
    {
      name: "raw",
      summary: "Inventory, read, and atomically edit validated OOXML parts",
      usage: "office raw <list|read|replace|edit> ...",
      formats: ["docx", "xlsx"],
      aliases: [],
      inputs: [
        capability_field(
          "operation", "enum(list|read|replace|edit)", true, "bounded raw OOXML operation",
        ),
      ],
      outputs: [
      // Raw operations have no common data-object fields. Each variant
      // declares its complete result schema and its fields below.
      ],
      output_modes: ["human", "json", "base64", "file"],
      variants: [
        {
          name: "list",
          usage: "office raw list FILE [--json]",
          result_schema: SCHEMA_RAW_INVENTORY,
          inputs: [
            capability_field(
              "file", "path", true, "existing XLSX or DOCX package",
            ),
            capability_field(
              "json", "boolean", false, "emit office.output/1 JSON",
            ),
          ],
          outputs: [
            capability_field(
              "format", "enum(docx|xlsx)", true, "structurally verified package format",
            ),
            capability_field(
              "part_count", "integer", true, "number of inventoried package parts",
            ),
            capability_field(
              "parts", "array(object{name:path,content_type:string,kind:enum(xml|binary),size:integer,aliases:array(string)})",
              true, "bounded canonical part inventory records",
            ),
          ],
          constraints: [],
          actions: [],
          output_modes: ["human", "json"],
        },
        {
          name: "read",
          usage: "office raw read FILE PART [--json] [--base64 | --output FILE]",
          result_schema: SCHEMA_RAW_PART,
          inputs: [
            capability_field(
              "file", "path", true, "existing XLSX or DOCX package",
            ),
            capability_field(
              "part", "part-selector", true, "/name when unambiguous, alias:/name, or part:/name",
            ),
            capability_field(
              "json", "boolean", false, "emit office.output/1 JSON",
            ),
            capability_field(
              "base64", "boolean", false, "emit exact payload as base64",
            ),
            capability_field(
              "output", "path", false, "create a file with the exact payload",
            ),
          ],
          outputs: [
            capability_field(
              "format", "enum(docx|xlsx)", true, "structurally verified package format",
            ),
            capability_field(
              "part", "object{name:path,content_type:string,kind:enum(xml|binary),size:integer,aliases:array(string)}",
              true, "resolved package-part metadata",
            ),
            capability_field(
              "encoding", "enum(xml|base64|binary)", true, "selected payload representation",
            ),
            capability_field(
              "content", "string", false, "decoded XML text or base64 payload",
            ),
            capability_field(
              "output", "path", false, "created payload destination",
            ),
          ],
          constraints: [
            "mutually-exclusive(base64,output)", "binary-requires(base64|output)",
            "output-create-mode(create-new)",
          ],
          actions: [],
          output_modes: ["human", "json", "base64", "file"],
        },
        {
          name: "replace",
          usage: "office raw replace FILE PART (--xml XML | --xml-file FILE) [--out FILE] [--dry-run] [--overwrite] [--json]",
          result_schema: SCHEMA_RAW_RESULT,
          inputs: [
            capability_field(
              "file", "path", true, "existing XLSX or DOCX package",
            ),
            capability_field(
              "part", "part-selector", true, "existing XML part selector",
            ),
            capability_field(
              "xml", "utf8-xml", false, "complete replacement XML document",
            ),
            capability_field(
              "xml-file", "path", false, "bounded UTF-8 replacement XML file",
            ),
            capability_field(
              "out", "path", false, "separate transaction destination",
            ),
            capability_field(
              "dry-run", "boolean", false, "validate without publishing",
            ),
            capability_field(
              "overwrite", "boolean", false, "replace an existing separate destination",
            ),
            capability_field(
              "json", "boolean", false, "emit office.output/1 JSON",
            ),
          ],
          outputs: [
            capability_field(
              "change",
              SCHEMA_RAW_CHANGE,
              true,
              "validated raw mutation summary",
            ),
            capability_field(
              "transaction",
              SCHEMA_TRANSACTION,
              true,
              "transaction validation and publication report",
            ),
          ],
          constraints: [
            "exactly-one(xml,xml-file)", "overwrite-requires(out)", "transactional-publication",
          ],
          actions: [],
          output_modes: ["human", "json"],
        },
        {
          name: "edit",
          usage: "office raw edit FILE PART --path PATH --action ACTION [action arguments] [--namespace PREFIX=URI]... [--all] [--out FILE] [--dry-run] [--overwrite] [--json]",
          result_schema: SCHEMA_RAW_RESULT,
          inputs: [
            capability_field(
              "file", "path", true, "existing XLSX or DOCX package",
            ),
            capability_field(
              "part", "part-selector", true, "existing XML part selector",
            ),
            capability_field(
              "path", "office.raw.path/1", true, "bounded namespace-aware element selector",
            ),
            capability_field(
              "action", "enum(append|prepend|insert-before|insert-after|replace|remove|set-attribute)",
              true, "bounded edit action",
            ),
            capability_field(
              "xml", "utf8-xml-element", false, "one self-contained XML element",
            ),
            capability_field(
              "xml-file", "path", false, "bounded UTF-8 XML element file",
            ),
            capability_field(
              "attribute", "qname", false, "set-attribute target name",
            ),
            capability_field(
              "value", "string", false, "set-attribute exact decoded value",
            ),
            capability_field(
              "namespace", "array(PREFIX=URI)", false, "repeatable selector namespace overrides",
            ),
            capability_field(
              "all", "boolean", false, "allow multiple bounded matches",
            ),
            capability_field(
              "out", "path", false, "separate transaction destination",
            ),
            capability_field(
              "dry-run", "boolean", false, "validate without publishing",
            ),
            capability_field(
              "overwrite", "boolean", false, "replace an existing separate destination",
            ),
            capability_field(
              "json", "boolean", false, "emit office.output/1 JSON",
            ),
          ],
          outputs: [
            capability_field(
              "change",
              SCHEMA_RAW_CHANGE,
              true,
              "validated raw mutation summary",
            ),
            capability_field(
              "transaction",
              SCHEMA_TRANSACTION,
              true,
              "transaction validation and publication report",
            ),
          ],
          constraints: [
            "mutually-exclusive(xml,xml-file)", "element-actions-require(exactly-one(xml,xml-file))",
            "set-attribute-requires(attribute,value)", "remove-forbids(xml,xml-file,attribute,value)",
            "overwrite-requires(out)", "flag-looking-values-require-attached-syntax",
            "transactional-publication",
          ],
          actions: [
            capability_action("append", ["exactly-one(xml,xml-file)"], [
              "attribute", "value",
            ]),
            capability_action("prepend", ["exactly-one(xml,xml-file)"], [
              "attribute", "value",
            ]),
            capability_action(
              "insert-before",
              ["exactly-one(xml,xml-file)"],
              ["attribute", "value"],
              restrictions=["path-must-not-select-document-element"],
            ),
            capability_action(
              "insert-after",
              ["exactly-one(xml,xml-file)"],
              ["attribute", "value"],
              restrictions=["path-must-not-select-document-element"],
            ),
            capability_action("replace", ["exactly-one(xml,xml-file)"], [
              "attribute", "value",
            ]),
            capability_action(
              "remove",
              [],
              ["xml", "xml-file", "attribute", "value"],
              restrictions=["path-must-not-select-document-element"],
            ),
            capability_action("set-attribute", ["attribute", "value"], [
              "xml", "xml-file",
            ]),
          ],
          output_modes: ["human", "json"],
        },
      ],
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
fn capability_action_json(action : CapabilityAction) -> Json {
  Json::object({
    "name": Json::string(action.name),
    "requires": json_strings(action.requires),
    "forbids": json_strings(action.forbids),
    "restrictions": json_strings(action.restrictions),
  })
}

///|
fn capability_variant_json(variant : CapabilityVariant) -> Json {
  Json::object({
    "name": Json::string(variant.name),
    "usage": Json::string(variant.usage),
    "result_schema": Json::string(variant.result_schema),
    "inputs": Json::array(variant.inputs.map(capability_field_json)),
    "outputs": Json::array(variant.outputs.map(capability_field_json)),
    "constraints": json_strings(variant.constraints),
    "actions": Json::array(variant.actions.map(capability_action_json)),
    "output_modes": json_strings(variant.output_modes),
  })
}

///|
fn capability_format_json(
  format : CapabilityFormat,
  fingerprint : String,
) -> Json {
  Json::object({
    "schema": Json::string(SCHEMA_CAPABILITY),
    "fingerprint": Json::string(fingerprint),
    "kind": Json::string("format"),
    "name": Json::string(format.name),
    "aliases": json_strings(format.aliases),
    "description": Json::string(format.description),
    "selector": Json::object({
      "schema": Json::string(format.selector.schema),
      "root": Json::string(format.selector.root),
      "status": Json::string(format.selector.status),
      "examples": json_strings(format.selector.examples),
      "description": Json::string(format.selector.description),
    }),
  })
}

///|
fn capability_command_json(
  command : CapabilityCommand,
  fingerprint : String,
) -> Json {
  Json::object({
    "schema": Json::string(SCHEMA_CAPABILITY),
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
    "variants": Json::array(command.variants.map(capability_variant_json)),
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
fn append_fingerprint_section(
  buffer : StringBuilder,
  name : String,
  length : Int,
) -> Unit {
  append_fingerprint_token(buffer, name)
  append_fingerprint_token(buffer, length.to_string())
}

///|
fn append_fingerprint_format(
  buffer : StringBuilder,
  format : CapabilityFormat,
) -> Unit {
  append_fingerprint_token(buffer, "format")
  append_fingerprint_token(buffer, format.name)
  append_fingerprint_section(buffer, "aliases", format.aliases.length())
  for alternate in format.aliases {
    append_fingerprint_token(buffer, alternate)
  }
  append_fingerprint_token(buffer, format.description)
  append_fingerprint_token(buffer, "selector")
  append_fingerprint_token(buffer, format.selector.schema)
  append_fingerprint_token(buffer, format.selector.root)
  append_fingerprint_token(buffer, format.selector.status)
  append_fingerprint_section(
    buffer,
    "selector_examples",
    format.selector.examples.length(),
  )
  for example in format.selector.examples {
    append_fingerprint_token(buffer, example)
  }
  append_fingerprint_token(buffer, format.selector.description)
}

///|
fn append_fingerprint_command(
  buffer : StringBuilder,
  command : CapabilityCommand,
) -> Unit {
  append_fingerprint_token(buffer, "command")
  append_fingerprint_token(buffer, command.name)
  append_fingerprint_token(buffer, command.summary)
  append_fingerprint_token(buffer, command.usage)
  append_fingerprint_section(buffer, "formats", command.formats.length())
  for format in command.formats {
    append_fingerprint_token(buffer, format)
  }
  append_fingerprint_section(buffer, "aliases", command.aliases.length())
  for alternate in command.aliases {
    append_fingerprint_token(buffer, alternate)
  }
  append_fingerprint_section(buffer, "inputs", command.inputs.length())
  for input in command.inputs {
    append_fingerprint_field(buffer, input)
  }
  append_fingerprint_section(buffer, "outputs", command.outputs.length())
  for output in command.outputs {
    append_fingerprint_field(buffer, output)
  }
  append_fingerprint_section(
    buffer,
    "output_modes",
    command.output_modes.length(),
  )
  for mode in command.output_modes {
    append_fingerprint_token(buffer, mode)
  }
  append_fingerprint_section(buffer, "variants", command.variants.length())
  for variant in command.variants {
    append_fingerprint_token(buffer, variant.name)
    append_fingerprint_token(buffer, variant.usage)
    append_fingerprint_token(buffer, variant.result_schema)
    append_fingerprint_section(
      buffer,
      "variant_inputs",
      variant.inputs.length(),
    )
    for input in variant.inputs {
      append_fingerprint_field(buffer, input)
    }
    append_fingerprint_section(
      buffer,
      "variant_outputs",
      variant.outputs.length(),
    )
    for output in variant.outputs {
      append_fingerprint_field(buffer, output)
    }
    append_fingerprint_section(
      buffer,
      "variant_constraints",
      variant.constraints.length(),
    )
    for constraint in variant.constraints {
      append_fingerprint_token(buffer, constraint)
    }
    append_fingerprint_section(
      buffer,
      "variant_actions",
      variant.actions.length(),
    )
    for action in variant.actions {
      append_fingerprint_token(buffer, action.name)
      append_fingerprint_section(
        buffer,
        "action_requires",
        action.requires.length(),
      )
      for requirement in action.requires {
        append_fingerprint_token(buffer, requirement)
      }
      append_fingerprint_section(
        buffer,
        "action_forbids",
        action.forbids.length(),
      )
      for forbidden in action.forbids {
        append_fingerprint_token(buffer, forbidden)
      }
      append_fingerprint_section(
        buffer,
        "action_restrictions",
        action.restrictions.length(),
      )
      for restriction in action.restrictions {
        append_fingerprint_token(buffer, restriction)
      }
    }
    append_fingerprint_section(
      buffer,
      "variant_output_modes",
      variant.output_modes.length(),
    )
    for mode in variant.output_modes {
      append_fingerprint_token(buffer, mode)
    }
  }
}

///|
fn capability_fingerprint_source() -> String {
  let buffer = StringBuilder::new()
  append_fingerprint_token(buffer, SCHEMA_CAPABILITIES)
  let formats = capability_formats()
  append_fingerprint_section(buffer, "formats", formats.length())
  for format in formats {
    append_fingerprint_format(buffer, format)
  }
  let commands = capability_commands()
  append_fingerprint_section(buffer, "commands", commands.length())
  for command in commands {
    append_fingerprint_command(buffer, command)
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
    "schema": Json::string(SCHEMA_CAPABILITIES),
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
