///|
let schema_input_contracts : String = @input_contract.SCHEMA_INVENTORY

///|
type InputContractCore = @input_contract.Core

///|
fn contract_strings(values : Array[String]) -> Json {
  @input_contract.contract_strings(values)
}

///|
fn contract_object(
  name : String,
  entries : Array[(String, String)],
  required? : Array[String] = [],
  constraints? : Array[String] = [],
) -> Json {
  @input_contract.contract_object(name, entries, required~, constraints~)
}

///|
fn contract_type(
  name : String,
  type_name : String,
  constraints? : Array[String] = [],
) -> Json {
  @input_contract.contract_type(name, type_name, constraints~)
}

///|
fn contract_envelope(
  entries : Array[(String, String)],
  required : Array[String],
) -> Json {
  @input_contract.contract_envelope(entries, required)
}

///|
fn copied_object_member(source : Json, key : String) -> Json {
  match source {
    Object(fields) =>
      match fields.get(key) {
        Some(Object(values)) => {
          let copied : Map[String, Json] = Map([])
          for name, value in values {
            copied[name] = value
          }
          Json::object(copied)
        }
        _ => Json::empty_object()
      }
    _ => Json::empty_object()
  }
}

///|
fn copied_array_member(source : Json, key : String) -> Array[Json] {
  match source {
    Object(fields) =>
      match fields.get(key) {
        Some(Array(values)) => values.copy()
        _ => []
      }
    _ => []
  }
}

///|
fn xlsx_input_contract() -> InputContractCore {
  let owner = @batch.capabilities()
  let limits = match copied_object_member(owner, "limits") {
    Object(values) => {
      values["max_number_token_chars"] = Json::number(
        @batch.MAX_BATCH_NUMBER_TOKEN_CHARS.to_double(),
      )
      values["max_enumerated_range_cells"] = Json::number(
        @inspect.MAX_RANGE_CELLS.to_double(),
      )
      Json::object(values)
    }
    other => other
  }
  {
    id: @inspect.SCHEMA_BATCH_V2,
    summary: "Strict transactional spreadsheet mutation script",
    consumed_by: ["office batch WORKBOOK.xlsx SCRIPT.json [--out OUTPUT.xlsx]"],
    envelope: contract_envelope(
      [("schema", "literal(xlsx.batch/2)"), ("ops", "array(xlsx_operation)")],
      ["schema", "ops"],
    ),
    definitions: [
      contract_object(
        "xlsx_operation",
        [
          ("op", "enum(operations[].op)"),
          ("params", "object(operations[op].params)"),
        ],
        required=["op", "params"],
      ),
      contract_type("value", "string|finite-number|boolean|null"),
      contract_type("cell", "single in-grid A1 cell"),
      contract_type("range", "in-grid cell or A1:B2 range"),
      contract_type("colon_range", "in-grid A1:B2 range"),
      contract_type(
        "table_range", "uncapped in-grid A1:B2 range; a one-row range on row 1048576 is forbidden",
      ),
      contract_type("sqref", "uncapped in-grid cell or A1:B2 range"),
      contract_type("column", "column letter or ascending column range"),
      contract_type(
        "series_range", "in-grid range with optional non-empty Sheet! qualifier",
      ),
    ],
    operations: copied_array_member(owner, "ops"),
    constraints: [
      "unknown envelope members, operations, and params are rejected", "JSON numbers must be finite and are stored as IEEE-754 doubles",
      "all references are validated before workbook I/O", "zero operations is a valid no-op",
      "application and publication are all-or-nothing", "xlsx.batch/2 is preferred; historical xlsx.batch/1 remains accepted with its exact v1 registry subset",
    ],
    limits,
    examples: [
      Json::object({
        "schema": Json::string(@inspect.SCHEMA_BATCH_V2),
        "ops": Json::array([
          Json::object({
            "op": Json::string("set"),
            "params": Json::object({
              "sheet": Json::string("Data"),
              "cell": Json::string("A1"),
              "value": Json::string("Hello"),
            }),
          }),
        ]),
      }),
    ],
  }
}

///|
fn docx_operation(name : String, params : String) -> Json {
  Json::object({
    "op": Json::string(name),
    "params": Json::string(params),
    "schema_versions": contract_strings(
      if name == "comment" {
        [@docx_batch.SCHEMA_BATCH_V2]
      } else {
        [@docx_batch.SCHEMA_BATCH, @docx_batch.SCHEMA_BATCH_V2]
      },
    ),
  })
}

///|
fn docx_input_contract() -> InputContractCore {
  let operations : Array[Json] = []
  for name in @docx_batch.operation_names() {
    let params = match name {
      "paragraph" => "paragraph"
      "table" => "table"
      "comment" => "comment"
      _ => "unknown"
    }
    operations.push(docx_operation(name, params))
  }
  {
    id: @docx_batch.SCHEMA_BATCH_V2,
    summary: "Strict fresh-DOCX authoring script with comments and notes",
    consumed_by: ["office batch --format docx OUTPUT.docx SCRIPT.json"],
    envelope: contract_envelope(
      [("schema", "literal(docx.batch/2)"), ("ops", "array(docx_operation)")],
      ["schema", "ops"],
    ),
    definitions: [
      contract_type("docx_text", "string", constraints=[
        "XML 1.0 characters only", "C0 controls are forbidden except tab", "raw CR and LF are forbidden; paragraphs are the hard-break unit",
        "unpaired surrogates and U+FFFE/U+FFFF are forbidden",
      ]),
      contract_type("xml_attribute_string", "nonempty-string", constraints=[
        "XML 1.0 characters only", "all C0 controls, including tab, CR, and LF, are forbidden",
        "unpaired surrogates and U+FFFE/U+FFFF are forbidden",
      ]),
      contract_object(
        "docx_operation",
        [("op", "enum(operations[].op)"), ("params", "operation.params")],
        required=["op"],
        constraints=["params defaults to an empty object when omitted"],
      ),
      contract_object(
        "paragraph",
        [
          ("text", "docx_text"),
          ("runs", "nonempty-array(run)"),
          ("style", "enum(Normal|Heading1..Heading6)"),
          ("align", "enum(left|center|right|both|start|end|distribute)"),
          ("list", "list"),
        ],
        constraints=["exactly-one(text,runs)"],
      ),
      contract_object(
        "list",
        [("ordered", "boolean"), ("level", "integer(1..9,default=1)")],
        required=["ordered"],
      ),
      contract_object(
        "text_run",
        [
          ("text", "docx_text"),
          ("bold", "boolean"),
          ("italic", "boolean"),
          ("underline", "boolean"),
          ("strike", "boolean"),
          ("all_caps", "boolean"),
          ("small_caps", "boolean"),
          ("vertical", "enum(superscript|subscript)"),
          ("font", "xml_attribute_string"),
          ("size", "integer(1..1638)"),
          ("highlight", "ST_HighlightColor except none"),
        ],
        required=["text"],
      ),
      contract_object(
        "link",
        [
          ("href", "xml_attribute_string"),
          ("anchor", "xml_attribute_string"),
          ("target_frame", "xml_attribute_string"),
          ("text", "docx_text"),
          ("runs", "nonempty-array(text_run|{image:image})"),
        ],
        constraints=[
          "exactly-one(href,anchor)", "exactly-one(text,runs)", "links cannot nest",
        ],
      ),
      contract_object(
        "image",
        [
          ("path", "string"),
          ("content_type", "enum(image/png|image/jpeg|image/gif)"),
          ("alt", "xml_attribute_string"),
        ],
        required=["path"],
        constraints=[
          "alt, when present, must contain a non-space non-tab character",
        ],
      ),
      contract_object(
        "note_body",
        [("text", "docx_text"), ("paragraphs", "nonempty-array(paragraph)")],
        constraints=["exactly-one(text,paragraphs)", "plain content only"],
      ),
      contract_type(
        "run",
        "one-of(text_run|{link:link}|{image:image}|{footnote:note_body}|{endnote:note_body})",
        constraints=["notes require docx.batch/2 and cannot nest"],
      ),
      contract_object(
        "table_cell",
        [
          ("text", "docx_text"),
          ("paragraphs", "nonempty-array(paragraph)"),
          ("col_span", "integer(1..63,default=1)"),
          ("row_span", "integer(1..remaining-rows,default=1)"),
        ],
        constraints=["exactly-one(text,paragraphs)"],
      ),
      contract_object(
        "table",
        [
          ("rows", "nonempty-array(nonempty-array(table_cell))"),
          ("header_rows", "integer(0..row-count,default=0)"),
        ],
        required=["rows"],
        constraints=["rows tile one equal-width grid of at most 63 columns"],
      ),
      contract_object(
        "comment",
        [
          ("on", "earlier-paragraph-op-index|{from:integer,to:integer}"),
          ("reply_to", "earlier-comment-op-index"),
          ("text", "docx_text"),
          ("paragraphs", "nonempty-array(paragraph)"),
          ("author", "xml_attribute_string"),
          ("initials", "xml_attribute_string"),
          ("date", "xsd:dateTime-string"),
          ("done", "boolean"),
        ],
        required=["author"],
        constraints=[
          "exactly-one(on,reply_to)", "exactly-one(text,paragraphs)", "body is plain content",
        ],
      ),
    ],
    operations,
    constraints: [
      "docx.batch/1 is accepted as the paragraph/table-only subset", "unknown and duplicate members are rejected",
      "all numeric lexemes are plain decimal integers", "document text must be XML-serializable",
      "the destination is fresh; existing documents are not mutated",
    ],
    limits: Json::object({
      "max_script_bytes": Json::number(
        office_docx_author_max_script_bytes.to_double(),
      ),
      "max_ops": Json::number(@docx_batch.MAX_BATCH_OPS.to_double()),
      "max_font_size_points": Json::number(
        @docx_batch.MAX_FONT_SIZE_POINTS.to_double(),
      ),
      "max_table_columns": Json::number(
        @docx_batch.MAX_GRID_COLUMNS.to_double(),
      ),
      "max_image_bytes": Json::number(
        office_docx_author_max_image_bytes.to_double(),
      ),
      "max_total_image_bytes": Json::number(
        office_docx_author_max_total_image_bytes.to_double(),
      ),
      "max_emitted_media_parts": Json::number(
        @docx.MAX_AUTHORED_MEDIA_PARTS.to_double(),
      ),
      "max_emitted_media_bytes": Json::number(
        @docx.MAX_AUTHORED_MEDIA_BYTES.to_double(),
      ),
    }),
    examples: [
      Json::object({
        "schema": Json::string(@docx_batch.SCHEMA_BATCH_V2),
        "ops": Json::array([
          Json::object({
            "op": Json::string("paragraph"),
            "params": Json::object({
              "text": Json::string("Quarterly findings"),
              "style": Json::string("Heading1"),
            }),
          }),
          Json::object({
            "op": Json::string("comment"),
            "params": Json::object({
              "on": Json::number(0.0),
              "author": Json::string("Reviewer"),
              "text": Json::string("Add a source."),
            }),
          }),
        ]),
      }),
    ],
  }
}

///|
fn template_input_contract() -> InputContractCore {
  {
    id: @template.SCHEMA_TEMPLATE_DATA,
    summary: "Strict non-executable scalar and repeating-region template data",
    consumed_by: ["office template TEMPLATE DATA.json --out OUTPUT"],
    envelope: contract_envelope(
      [
        ("schema", "literal(office.template.data/1)"),
        ("values", "object<template_key,scalar>"),
        ("regions", "nonempty-object<template_key,region>"),
      ],
      ["schema", "values"],
    ),
    definitions: [
      contract_type("template_key", "[A-Za-z_][A-Za-z0-9_.-]{0,63}"),
      contract_type("scalar", "XML-safe-string|finite-number|boolean"),
      contract_object(
        "region",
        [
          ("sheet", "nonempty-string"),
          ("row", "plain-integer(1..1048576)"),
          ("path", "table-row-selector"),
          ("records", "nonempty-array(object<template_key,scalar>)"),
        ],
        required=["records"],
        constraints=[
          "exactly-one(sheet+row,path)", "sheet+row is accepted only for an XLSX template",
          "path is accepted only for a DOCX template and must address a body table row",
        ],
      ),
      contract_type(
        "table-row-selector", "/docx/body/tbl[N]/tr[M]; N and M are 1..7 digits, positive, without a leading zero",
      ),
    ],
    operations: [],
    constraints: [
      "unknown and duplicate members are rejected", "null, arrays, and nested values are rejected",
      "values keys and every region-record key set are disjoint", "region names and scalar keys use template_key",
      "regions is optional, but when present it must contain 1..max_regions named members",
      "XLSX regions require sheet+row and reject path; DOCX regions require a body-table path and reject sheet+row",
    ],
    limits: Json::object({
      "max_data_bytes": Json::number(office_template_max_data_bytes.to_double()),
      "max_keys_per_values_or_record": Json::number(
        @template.MAX_TEMPLATE_KEYS.to_double(),
      ),
      "max_string_utf16_units": Json::number(
        @template.MAX_TEMPLATE_VALUE_UNITS.to_double(),
      ),
      "max_regions": Json::number(@template.MAX_TEMPLATE_REGIONS.to_double()),
      "max_records_per_region": Json::number(
        @template.MAX_TEMPLATE_REGION_RECORDS.to_double(),
      ),
      "max_total_region_rows": Json::number(
        @template.MAX_TEMPLATE_TOTAL_REGION_ROWS.to_double(),
      ),
      "max_sheet_row": Json::number(
        @template.MAX_TEMPLATE_SHEET_ROW.to_double(),
      ),
      "max_docx_path_ordinal_digits": Json::number(
        @template.MAX_TEMPLATE_PATH_ORDINAL_DIGITS.to_double(),
      ),
    }),
    examples: [
      Json::object({
        "schema": Json::string(@template.SCHEMA_TEMPLATE_DATA),
        "values": Json::object({
          "company": Json::string("Acme"),
          "approved": Json::boolean(true),
        }),
        "regions": Json::object({
          "items": Json::object({
            "sheet": Json::string("Data"),
            "row": Json::number(2.0),
            "records": Json::array([
              Json::object({
                "item": Json::string("Widget"),
                "amount": Json::number(3.0),
              }),
            ]),
          }),
        }),
      }),
    ],
  }
}

///|
fn annotation_operation(name : String) -> Json {
  let (entries, required, constraints) = match name {
    "comment_add" =>
      (
        [
          ("op", "literal(comment_add)"),
          ("anchor", "comment_anchor"),
          ("author", "xml_attribute_string"),
          ("initials", "xml_attribute_string"),
          ("date", "xsd:dateTime-string"),
          ("body", "comment_body"),
          ("label", "template_key"),
        ],
        ["op", "anchor", "author", "body"],
        [],
      )
    "comment_reply" =>
      (
        [
          ("op", "literal(comment_reply)"),
          ("parent", "comment_ref"),
          ("author", "xml_attribute_string"),
          ("initials", "xml_attribute_string"),
          ("date", "xsd:dateTime-string"),
          ("body", "comment_body"),
          ("label", "template_key"),
        ],
        ["op", "parent", "author", "body"],
        ["label references resolve only to earlier operations"],
      )
    "comment_resolve" | "comment_unresolve" =>
      (
        [("op", "literal(\{name})"), ("target", "comment_ref")],
        ["op", "target"],
        [],
      )
    _ => ([], [], ["unknown parser operation"])
  }
  contract_object(name, entries, required~, constraints~)
}

///|
fn annotation_input_contract() -> InputContractCore {
  let operations : Array[Json] = []
  for name in @office_docx.annotation_batch_operation_names() {
    operations.push(annotation_operation(name))
  }
  {
    id: @office_docx.SCHEMA_ANNOTATION_BATCH,
    summary: "Strict preservation-safe comment mutation script for an existing DOCX",
    consumed_by: ["office annotate INPUT.docx SCRIPT.json --out OUTPUT.docx"],
    envelope: contract_envelope(
      [
        ("schema", "literal(docx.annotation-batch/1)"),
        ("ops", "array(annotation_operation)"),
      ],
      ["schema", "ops"],
    ),
    definitions: [
      contract_object(
        "comment_anchor",
        [
          (
            "at", "canonical-/docx/body/p[K]-selector(K=1..max_annotation_anchor_ordinal,no-leading-zero)",
          ),
          (
            "to", "canonical-/docx/body/p[M]-selector(M=1..max_annotation_anchor_ordinal,no-leading-zero)",
          ),
        ],
        required=["at"],
      ),
      contract_type(
        "comment_ref", "exactly-one({comment_id:nonempty-string}|{label:template_key})",
      ),
      contract_type("docx_text", "string", constraints=[
        "XML 1.0 characters only", "C0 controls are forbidden except tab", "raw CR and LF are forbidden; paragraphs are the hard-break unit",
        "unpaired surrogates and U+FFFE/U+FFFF are forbidden",
      ]),
      contract_type("xml_attribute_string", "nonempty-string", constraints=[
        "XML 1.0 characters only", "all C0 controls, including tab, CR, and LF, are forbidden",
        "unpaired surrogates and U+FFFE/U+FFFF are forbidden",
      ]),
      contract_type("comment_body", "nonempty-array(docx_text)", constraints=[
        "every paragraph string is nonempty",
      ]),
      contract_type("template_key", "[A-Za-z_][A-Za-z0-9_.-]{0,63}"),
    ],
    operations,
    constraints: [
      "unknown members and operation names are rejected", "labels are unique and references may name only earlier labels",
      "anchors address body paragraphs and ranges are ordered", "operations fold over fresh snapshots and publish atomically",
      "each complete serialized <w:comment> fragment (metadata, namespaces, reply paraIds, and body) is at most max_comment_fragment_bytes UTF-8 XML bytes; the effective transaction-derived ceiling may be lower",
    ],
    limits: Json::object({
      "max_script_bytes": Json::number(
        office_annotation_max_script_bytes.to_double(),
      ),
      "max_ops": Json::number(@office_docx.MAX_ANNOTATION_OPS.to_double()),
      "max_total_growth_bytes": Json::number(
        @office_docx.MAX_ANNOTATION_TOTAL_GROWTH.to_double(),
      ),
      "max_comment_fragment_bytes": Json::number(
        @office_docx.MAX_COMMENT_FRAGMENT_BYTES.to_double(),
      ),
      "max_annotation_anchor_ordinal": Json::number(
        @office_docx.MAX_ANNOTATION_ANCHOR_ORDINAL.to_double(),
      ),
    }),
    examples: [
      Json::object({
        "schema": Json::string(@office_docx.SCHEMA_ANNOTATION_BATCH),
        "ops": Json::array([
          Json::object({
            "op": Json::string("comment_add"),
            "anchor": Json::object({ "at": Json::string("/docx/body/p[1]") }),
            "author": Json::string("Reviewer"),
            "body": Json::array([Json::string("Check this figure.")]),
            "label": Json::string("review"),
          }),
          Json::object({
            "op": Json::string("comment_reply"),
            "parent": Json::object({ "label": Json::string("review") }),
            "author": Json::string("Author"),
            "body": Json::array([Json::string("Verified.")]),
            "label": Json::string("answer"),
          }),
          Json::object({
            "op": Json::string("comment_resolve"),
            "target": Json::object({ "label": Json::string("answer") }),
          }),
          Json::object({
            "op": Json::string("comment_unresolve"),
            "target": Json::object({ "label": Json::string("answer") }),
          }),
        ]),
      }),
    ],
  }
}

///|
fn input_contract_cores() -> Array[InputContractCore] {
  [
    xlsx_input_contract(),
    docx_input_contract(),
    template_input_contract(),
    annotation_input_contract(),
  ]
}

///|
fn input_contract_record(core : InputContractCore) -> Json {
  @input_contract.record(core)
}

///|
fn input_contract_ids() -> Array[String] {
  input_contract_cores().map(core => core.id)
}

///|
fn find_input_contract(id : String) -> Json? {
  for core in input_contract_cores() {
    if core.id == id {
      return Some(input_contract_record(core))
    }
  }
  None
}

///|
fn input_contract_inventory() -> Json {
  @input_contract.inventory(input_contract_cores())
}

///|
fn render_input_contract_inventory() -> String {
  let lines : Array[String] = [
    "Consumed input contracts",
    "  Schema: \{schema_input_contracts}",
  ]
  for core in input_contract_cores() {
    lines.push("  \{core.id} — \{core.summary}")
  }
  lines.push("Use 'office help schema <id> --json' for the exact contract.")
  lines.join("\n")
}
