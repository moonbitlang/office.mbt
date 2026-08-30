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
      if name is ("comment" | "header" | "footer") {
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
      "header" | "footer" => "story"
      _ => "unknown"
    }
    operations.push(docx_operation(name, params))
  }
  {
    id: @docx_batch.SCHEMA_BATCH_V2,
    summary: "Strict fresh-DOCX authoring script with comments, notes, header/footer stories, and page fields",
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
      contract_object(
        "field",
        [("type", "enum(PAGE|NUMPAGES)")],
        required=["type"],
        constraints=[
          "emitted as a live w:fldChar begin/instrText/separate/end run sequence, never as static text",
          "not allowed in comment or note bodies",
        ],
      ),
      contract_type(
        "run",
        "one-of(text_run|{link:link}|{image:image}|{footnote:note_body}|{endnote:note_body}|{field:field})",
        constraints=[
          "notes require docx.batch/2 and cannot nest", "fields require docx.batch/2",
        ],
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
      contract_object(
        "story",
        [
          ("variant", "enum(default|first|even,default=default)"),
          ("text", "docx_text"),
          ("paragraphs", "nonempty-array(paragraph)"),
        ],
        constraints=[
          "exactly-one(text,paragraphs)", "body is plain content plus fields; hyperlinks, images and notes are rejected",
          "each variant may be declared at most once per kind", "a first variant also emits w:titlePg; an even variant also emits word/settings.xml with w:evenAndOddHeaders",
        ],
      ),
    ],
    operations,
    constraints: [
      "docx.batch/1 is accepted as the paragraph/table-only subset", "unknown and duplicate members are rejected",
      "all numeric lexemes are plain decimal integers", "document text must be XML-serializable",
      "the destination is fresh; existing documents are not mutated", "header and footer ops attach to the document's single section; they produce no body block and cannot be commented on",
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
      // A paginated report: a running header plus a footer whose page number
      // is a LIVE field, not the static text a reader would have to correct.
      Json::object({
        "schema": Json::string(@docx_batch.SCHEMA_BATCH_V2),
        "ops": Json::array([
          Json::object({
            "op": Json::string("paragraph"),
            "params": Json::object({ "text": Json::string("Body text") }),
          }),
          Json::object({
            "op": Json::string("header"),
            "params": Json::object({
              "variant": Json::string("default"),
              "text": Json::string("Quarterly findings"),
            }),
          }),
          Json::object({
            "op": Json::string("footer"),
            "params": Json::object({
              "paragraphs": Json::array([
                Json::object({
                  "align": Json::string("center"),
                  "runs": Json::array([
                    Json::object({ "text": Json::string("Page ") }),
                    Json::object({
                      "field": Json::object({ "type": Json::string("PAGE") }),
                    }),
                    Json::object({ "text": Json::string(" of ") }),
                    Json::object({
                      "field": Json::object({ "type": Json::string("NUMPAGES") }),
                    }),
                  ]),
                }),
              ]),
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
fn edit_operation(name : String) -> Json {
  let (entries, required, constraints) = match name {
    "replace_text" =>
      (
        [
          ("find", "literal_text"),
          ("replace", "literal_text_or_empty"),
          ("occurrence", "plain-integer(1..max_occurrence)"),
        ],
        ["find", "replace"],
        [
          "find is LITERAL: no regular expressions, no wildcards, no escaping", "occurrence omitted replaces EVERY occurrence in document order",
          "occurrence N replaces only the Nth occurrence and leaves the rest untouched",
          "an empty replace deletes the matched text",
        ],
      )
    "accept_revision" | "reject_revision" =>
      (
        [
          ("id", "revision_selector_text"),
          ("author", "revision_selector_text"),
          ("type", "enum(ins,del)"),
          ("all", "literal(true)"),
        ],
        [],
        [
          "spelled selector fields are CONJUNCTIVE: {\"author\":\"Reviewer\",\"type\":\"del\"} selects only Reviewer's deletions",
          "id is the w:id attribute AS SPELLED — the stable handle; ordinal position is never a selector",
          "all: true selects every tracked change and cannot be combined with id, author, or type",
          "at least one of id, author, type, or all is required; all: false is rejected",
          if name == "accept_revision" {
            "accepting w:ins unwraps it and keeps its runs; accepting w:del removes it and its content"
          } else {
            "rejecting w:ins removes it and its content; rejecting w:del unwraps it and renames each w:delText back to w:t"
          },
        ],
      )
    "set_run_text" =>
      (
        [
          ("at", "run_path"),
          ("expect", "literal_text_or_empty"),
          ("text", "literal_text_or_empty"),
        ],
        ["at", "expect", "text"],
        [
          "requires \"schema\": \"docx.edit/2\"", "at names ONE run: the office query path (/docx/body/p[3]/r[2]), its body-relative form (p[3]/r[2]), or a stable head p[id=\"1A2B3C4D\"]/r[2] resolved by identity at transaction time — the result then records resolved_at",
          "expect must equal the run's CURRENT full reader-visible text; addresses are snapshot-relative, so a stale expectation refuses without publishing",
          "text replaces the run's WHOLE text; text equal to expect validates the address and changes nothing",
          "--allow-unmatched has no effect: an unresolved address always refuses",
        ],
      )
    _ => ([], [], ["unknown parser operation"])
  }
  Json::object({
    "op": Json::string(name),
    "params": contract_object(
      name + "_params",
      entries,
      required~,
      constraints~,
    ),
  })
}

///|
fn edit_input_contract() -> InputContractCore {
  edit_input_contract_versioned(2)
}

///|
fn edit_v1_input_contract() -> InputContractCore {
  edit_input_contract_versioned(1)
}

///|
fn edit_input_contract_versioned(version : Int) -> InputContractCore {
  let operations : Array[Json] = []
  for name in @office_docx.docx_edit_operation_names_list() {
    if version == 1 && name == "set_run_text" {
      continue
    }
    operations.push(edit_operation(name))
  }
  {
    id: if version == 1 {
      @office_docx.SCHEMA_DOCX_EDIT
    } else {
      @office_docx.SCHEMA_DOCX_EDIT_V2
    },
    summary: if version == 1 {
      "Strict preservation-safe literal find & replace, or tracked-change accept/reject, script for an existing DOCX"
    } else {
      "Everything docx.edit/1 accepts plus the addressed set_run_text whole-run replacement"
    },
    consumed_by: ["office edit INPUT.docx SCRIPT.json --out OUTPUT.docx"],
    envelope: contract_envelope(
      [
        (
          "schema",
          if version == 1 {
            "literal(docx.edit/1)"
          } else {
            "literal(docx.edit/2)"
          },
        ),
        ("ops", "nonempty-array(edit_operation)"),
      ],
      ["schema", "ops"],
    ),
    definitions: [
      contract_object(
        "edit_operation",
        [("op", "enum(operations[].op)"), ("params", "operation.params")],
        required=["op", "params"],
      ),
      contract_type("literal_text", "nonempty-string", constraints=[
        "matched verbatim, across run boundaries; never interpreted as a pattern",
        "all C0 controls (tab included), DEL, CR, and LF are forbidden", "unpaired surrogates and U+FFFE/U+FFFF are forbidden",
      ]),
      contract_type("literal_text_or_empty", "string", constraints=[
        "the empty string deletes the matched text", "same character restrictions as literal_text",
      ]),
      contract_type("revision_selector_text", "nonempty-string", constraints=[
        "compared verbatim against the attribute the source spelled; never a pattern",
        "a revision whose attribute is absent is never selected by that field",
      ]),
    ] +
    (if version == 1 {
      []
    } else {
      [
        contract_type("run_path", "nonempty-string", constraints=[
          "the office query path (/docx/body/p[3]/r[2]) or its body-relative form (p[3]/r[2])",
          "segments are kind[ordinal] with kind in {p, r, tbl, tr, tc} and 1-based ordinals; the path ends in a run segment",
          "validated at parse time; a well-formed path that names nothing refuses at plan time with the addressable-run count",
        ]),
      ]
    }),
    operations,
    constraints: [
      "unknown envelope members, operations, and params are rejected",
      if version == 1 {
        "one script is entirely replace_text or entirely accept_revision/reject_revision; mixing the two families is rejected"
      } else {
        "one script is entirely replace_text, entirely accept_revision/reject_revision, or entirely set_run_text; mixing families is rejected"
      },
      "every operation matches the ORIGINAL document snapshot; operations never see each other's output",
      "two operations whose matches overlap refuse; matches that merely touch both apply",
      "the body, header, and footer stories are edited; a needle or tracked change found in a footnote, endnote, or comment story refuses",
      "a match reaching content a byte-span run rewrite cannot own, or crossing a hyperlink boundary, refuses",
      "an operation that finds fewer occurrences than it requires, or a selector that matches no tracked change, refuses unless --allow-unmatched",
      "the replacement inherits the formatting of the run the match started in",
      "resolvable tracked changes are content w:ins and w:del inside a paragraph or hyperlink; a selection reaching a property revision (w:rPr/w:ins paragraph marks, w:trPr/w:del rows), a move (w:moveFrom/w:moveTo), any *PrChange, or a revision wrapping rows or block content refuses",
      "a selected revision that contains another revision refuses; resolve the inner one first",
      "accept_revision and reject_revision selecting the same revision refuses",
    ],
    limits: Json::object(
      {
        "max_script_bytes": Json::number(
          office_edit_max_script_bytes.to_double(),
        ),
        "max_ops": Json::number(@office_docx.MAX_EDIT_OPS.to_double()),
        "max_find_utf16_units": Json::number(
          @office_docx.MAX_EDIT_FIND_UNITS.to_double(),
        ),
        "max_replace_utf16_units": Json::number(
          @office_docx.MAX_EDIT_REPLACE_UNITS.to_double(),
        ),
        "max_occurrence": Json::number(
          @office_docx.MAX_EDIT_OCCURRENCE.to_double(),
        ),
        "max_scan_units": Json::number(
          @office_docx.MAX_EDIT_SCAN_UNITS.to_double(),
        ),
        "max_revision_selector_utf16_units": Json::number(
          @office_docx.MAX_REVISION_SELECTOR_UNITS.to_double(),
        ),
      }
      |> limits => {
        if version != 1 {
          limits["max_run_path_utf16_units"] = Json::number(
            @office_docx.MAX_EDIT_RUN_PATH_UNITS.to_double(),
          )
        }
        limits
      },
    ),
    examples: [
      Json::object({
        "schema": Json::string(
          if version == 1 {
            @office_docx.SCHEMA_DOCX_EDIT
          } else {
            @office_docx.SCHEMA_DOCX_EDIT_V2
          },
        ),
        "ops": Json::array([
          Json::object({
            "op": Json::string("replace_text"),
            "params": Json::object({
              "find": Json::string("draft"),
              "replace": Json::string("final"),
            }),
          }),
          Json::object({
            "op": Json::string("replace_text"),
            "params": Json::object({
              "find": Json::string("Q3"),
              "replace": Json::string("Q4"),
              "occurrence": Json::number(1.0),
            }),
          }),
        ]),
      }),
      // Accept everything one reviewer proposed. `office outline` lists the
      // ids and authors this selector matches.
      Json::object({
        "schema": Json::string(
          if version == 1 {
            @office_docx.SCHEMA_DOCX_EDIT
          } else {
            @office_docx.SCHEMA_DOCX_EDIT_V2
          },
        ),
        "ops": Json::array([
          Json::object({
            "op": Json::string("accept_revision"),
            "params": Json::object({ "author": Json::string("Reviewer") }),
          }),
        ]),
      }),
      // Reject one specific tracked change by its stable w:id.
      Json::object({
        "schema": Json::string(
          if version == 1 {
            @office_docx.SCHEMA_DOCX_EDIT
          } else {
            @office_docx.SCHEMA_DOCX_EDIT_V2
          },
        ),
        "ops": Json::array([
          Json::object({
            "op": Json::string("reject_revision"),
            "params": Json::object({ "id": Json::string("7") }),
          }),
        ]),
      }),
      // Accept every tracked change in the document.
      Json::object({
        "schema": Json::string(
          if version == 1 {
            @office_docx.SCHEMA_DOCX_EDIT
          } else {
            @office_docx.SCHEMA_DOCX_EDIT_V2
          },
        ),
        "ops": Json::array([
          Json::object({
            "op": Json::string("accept_revision"),
            "params": Json::object({ "all": Json::boolean(true) }),
          }),
        ]),
      }),
    ] +
    (if version == 1 {
      []
    } else {
      // Set one addressed run's whole text, guarded by its current text.
      [
        Json::object({
          "schema": Json::string(@office_docx.SCHEMA_DOCX_EDIT_V2),
          "ops": Json::array([
            Json::object({
              "op": Json::string("set_run_text"),
              "params": Json::object({
                "at": Json::string("p[3]/r[2]"),
                "expect": Json::string("Q3 revenue"),
                "text": Json::string("Q4 revenue"),
              }),
            }),
          ]),
        }),
      ]
    }),
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
    edit_v1_input_contract(),
    edit_input_contract(),
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
