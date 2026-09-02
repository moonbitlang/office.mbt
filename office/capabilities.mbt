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
pub const SCHEMA_TRANSACTION : String = "office.transaction/2"

///|
pub const SCHEMA_DOCX_OUTLINE : String = "office.docx.outline/1"

///|
pub const SCHEMA_DOCX_ELEMENT : String = "office.docx.element/1"

///|
pub const SCHEMA_DOCX_TEXT : String = "office.docx.text/1"

///|
pub const SCHEMA_DOCX_QUERY : String = "office.docx.query/1"

///|
/// The `office find` result. The roadmap's N2a note calls this
/// `docx.matches/1`; the id follows this file's `office.<format>.<name>`
/// convention instead, so it sits with the other twenty output schemas
/// rather than beside the `docx.edit/N` INPUT contracts.
pub const SCHEMA_DOCX_MATCHES : String = "office.docx.matches/1"

///|
pub const SCHEMA_XLSX_OUTLINE : String = "office.xlsx.outline/1"

///|
pub const SCHEMA_XLSX_ELEMENT : String = "office.xlsx.element/1"

///|
pub const SCHEMA_XLSX_TEXT : String = "office.xlsx.text/1"

///|
pub const SCHEMA_XLSX_QUERY : String = "office.xlsx.query/1"

///|
pub const SCHEMA_XLSX_CREATE_RESULT : String = "office.xlsx.create/1"

///|
pub const SCHEMA_DOCX_CREATE_RESULT : String = "office.docx.create/1"

///|
pub const SCHEMA_DOCX_BATCH_RESULT : String = "office.docx.batch/1"

///|
/// Versioned result schema emitted by `office validate`.
pub const SCHEMA_VALIDATE_RESULT : String = "office.validate/1"

///|
/// Versioned result schema emitted by `office issues`.
pub const SCHEMA_ISSUES_RESULT : String = "office.issues/1"

///|
/// Versioned finding record carried by validate/issues results.
pub const SCHEMA_FINDING_RECORD : String = "office.finding/1"

///|
/// Versioned result schema emitted by `office preview`.
pub const SCHEMA_PREVIEW_RESULT : String = "office.preview/1"

///|
/// Versioned replayable dump schema emitted by `office dump`.
pub const SCHEMA_DUMP_RESULT : String = "office.dump/1"

///|
/// Versioned result schema emitted by `office replay`.
pub const SCHEMA_REPLAY_RESULT : String = "office.replay/1"

///|
pub const SCHEMA_TEMPLATE_RESULT : String = "office.template/1"

///|
pub const SCHEMA_XLSX_BATCH_RESULT : String = "office.xlsx.batch/1"

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
  registry : Json?
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
  { name, type_name, required, description, }
}

///|
fn capability_action(
  name : String,
  requires : Array[String],
  forbids : Array[String],
  restrictions? : Array[String] = [],
) -> CapabilityAction {
  { name, requires, forbids, restrictions, }
}

///|
fn capability_variant(
  name : String,
  usage : String,
  result_schema : String,
  constraints : Array[String],
) -> CapabilityVariant {
  {
    name,
    usage,
    result_schema,
    registry: None,
    inputs: [],
    outputs: [],
    constraints,
    actions: [],
    output_modes: ["human", "json"],
  }
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
        status: "read-resolved",
        examples: [
          "/docx/body/p[1]/r[2]", "/docx/body/p[id=\"1A2B3C4D\"]", "/docx/comments/comment[id=\"7\"]",
        ],
        description: "bounded canonical resolution for outline, get, text, and declared query predicates",
      },
    },
    {
      name: "xlsx",
      aliases: ["excel"],
      description: "SpreadsheetML workbooks",
      selector: {
        schema: "office.selector/1",
        root: "/xlsx",
        status: "read-resolved",
        examples: [
          "/xlsx/sheet[name=\"Data\"]/cell[A1]", "/xlsx/sheet[name=\"Data\"]/range[A1:C12]",
        ],
        description: "bounded canonical resolution for workbook, sheet, cell, and range selectors across outline, get, text, and cell queries",
      },
    },
  ]
}

///|
/// Returns implemented command declarations in stable order. An empty
/// `formats` array marks a format-neutral command.
pub fn capability_commands() -> Array[CapabilityCommand] {
  let commands : Array[CapabilityCommand] = [
    {
      name: "help",
      summary: "Show implemented capabilities or consumed input contracts",
      usage: "office help [all|schemas|schema <id>|<format>|<operation>|<format> <operation>] [--json|--jsonl]",
      formats: [],
      aliases: [],
      inputs: [
        capability_field(
          "query", "enum(all|schemas)|schema+id|format|operation|format+operation",
          false, "optional capability or consumed-input-contract query",
        ),
        capability_field(
          "json", "boolean", false, "emit one office.output/1 JSON document",
        ),
        capability_field(
          "jsonl", "boolean", false, "emit one self-contained help record per line",
        ),
      ],
      outputs: [],
      output_modes: ["human", "json", "jsonl"],
      variants: [
        {
          name: "capabilities",
          usage: "office help [all|<format>|<operation>|<format> <operation>] [--json]",
          result_schema: SCHEMA_CAPABILITIES,
          registry: None,
          inputs: [
            capability_field(
              "query", "enum(all)|format|operation|format+operation", false, "optional capability query",
            ),
            capability_field(
              "json", "boolean", false, "emit one office.output/1 JSON document",
            ),
          ],
          outputs: [
            capability_field(
              "schema", "literal(office.capabilities/2)", true, "registry schema",
            ),
            capability_field(
              "fingerprint", "string", true, "deterministic registry fingerprint",
            ),
            capability_field(
              "records", "array", true, "truthful implemented formats, commands, and fields",
            ),
            capability_field(
              "format", "enum(docx|xlsx)", false, "normalized format filter when requested",
            ),
            capability_field(
              "operation", "string", false, "normalized operation filter when requested",
            ),
          ],
          constraints: ["json-data-schema=office.capabilities/2"],
          actions: [],
          output_modes: ["human", "json"],
        },
        {
          name: "capability-records",
          usage: "office help [all|<format>|<operation>|<format> <operation>] --jsonl",
          result_schema: SCHEMA_CAPABILITY,
          registry: None,
          inputs: [
            capability_field(
              "query", "enum(all)|format|operation|format+operation", false, "optional capability query",
            ),
            capability_field(
              "jsonl", "literal(true)", true, "emit one capability record per line",
            ),
          ],
          outputs: [
            capability_field(
              "schema", "literal(office.capability/2)", true, "record schema",
            ),
            capability_field(
              "fingerprint", "string", true, "deterministic registry fingerprint",
            ),
            capability_field(
              "kind", "enum(format|command)", true, "capability record kind",
            ),
            capability_field("name", "string", true, "capability name"),
            capability_field(
              "aliases", "array(string)", true, "accepted aliases in stable order",
            ),
            capability_field(
              "description", "string", false, "format record description",
            ),
            capability_field(
              "selector", "object{schema,root,status,examples,description}", false,
              "format record selector contract",
            ),
            capability_field(
              "summary", "string", false, "command record summary",
            ),
            capability_field("usage", "string", false, "command record usage"),
            capability_field(
              "formats", "array(string)", false, "command record formats",
            ),
            capability_field(
              "inputs", "array(capability-field)", false, "command record inputs",
            ),
            capability_field(
              "outputs", "array(capability-field)", false, "command record outputs",
            ),
            capability_field(
              "output_modes", "array(string)", false, "command record output modes",
            ),
            capability_field(
              "variants", "array(capability-variant)", false, "command record variants",
            ),
          ],
          constraints: [
            "one-self-contained-record-per-line", "kind=format requires(description,selector) and forbids(summary,usage,formats,inputs,outputs,output_modes,variants)",
            "kind=command requires(summary,usage,formats,inputs,outputs,output_modes,variants) and forbids(description,selector)",
          ],
          actions: [],
          output_modes: ["jsonl"],
        },
        {
          name: "schemas",
          usage: "office help schemas [--json|--jsonl]",
          result_schema: "office.input-contracts/1",
          registry: None,
          inputs: [
            capability_field(
              "json", "boolean", false, "emit one office.output/1 JSON document",
            ),
            capability_field(
              "jsonl", "boolean", false, "emit the inventory as one compact line",
            ),
          ],
          outputs: [
            capability_field(
              "schema", "literal(office.input-contracts/1)", true, "inventory schema",
            ),
            capability_field(
              "fingerprint", "sha256", true, "aggregate canonical inventory fingerprint",
            ),
            capability_field(
              "contracts", "array", true, "ordered installed input-contract summaries",
            ),
          ],
          constraints: ["exactly-four-consumed-contracts"],
          actions: [],
          output_modes: ["human", "json", "jsonl"],
        },
        {
          name: "schema",
          usage: "office help schema <id> [--json|--jsonl]",
          result_schema: "office.input-contract/1",
          registry: None,
          inputs: [
            capability_field(
              "id", "enum(installed-input-contract-id)", true, "exact contract id",
            ),
            capability_field(
              "json", "boolean", false, "emit one office.output/1 JSON document",
            ),
            capability_field(
              "jsonl", "boolean", false, "emit one compact contract record",
            ),
          ],
          outputs: [
            capability_field(
              "schema", "literal(office.input-contract/1)", true, "record schema",
            ),
            capability_field(
              "id", "string", true, "versioned input-contract id",
            ),
            capability_field(
              "fingerprint", "sha256", true, "canonical contract fingerprint",
            ),
            capability_field("summary", "string", true, "contract purpose"),
            capability_field(
              "consumed_by", "array(string)", true, "installed command consumers",
            ),
            capability_field(
              "envelope", "object", true, "closed top-level shape",
            ),
            capability_field(
              "definitions", "array", true, "reusable strict input definitions",
            ),
            capability_field(
              "operations", "array", true, "ordered parser-owned operations",
            ),
            capability_field(
              "constraints", "array(string)", true, "cross-field and application rules",
            ),
            capability_field(
              "limits", "object", true, "numeric resource ceilings",
            ),
            capability_field(
              "examples", "array", true, "production-parser-verified examples",
            ),
          ],
          constraints: ["unknown-id-is-a-typed-nonzero-failure"],
          actions: [],
          output_modes: ["human", "json", "jsonl"],
        },
      ],
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
      name: "outline",
      summary: "Summarize bounded XLSX or DOCX structure using canonical selectors",
      usage: "office outline FILE [--max-elements N] [--max-output-chars N] [--json]",
      formats: ["docx", "xlsx"],
      aliases: [],
      inputs: [
        capability_field("file", "path", true, "existing XLSX or DOCX package"),
        capability_field(
          "max-elements", "integer(1..200000)", false, "DOCX projection-node or XLSX cell scan ceiling; default 50000; XLSX effective hard ceiling 100000",
        ),
        capability_field(
          "max-output-chars", "integer(1..4194304)", false, "successful stdout ceiling including trailing LF; failure envelopes are separate; default 1048576",
        ),
        capability_field("json", "boolean", false, "emit office.output/1 JSON"),
      ],
      outputs: [
        capability_field(
          "schema", "enum(office.docx.outline/1|office.xlsx.outline/1)", true, "format-specific versioned result schema",
        ),
        capability_field(
          "file", "path", true, "the input path exactly as supplied",
        ),
        capability_field(
          "format", "enum(docx|xlsx)", true, "resolved document format",
        ),
        capability_field(
          "scanned_elements", "integer", false, "DOCX only: number of elements in the bounded projection",
        ),
        capability_field(
          "counts", "object", false, "DOCX only: deterministic structural counts across every story",
        ),
        capability_field("stories", "array", false, "DOCX only: story roots"),
        capability_field(
          "headings", "array", false, "DOCX only: bounded heading previews; each carries the paragraph anchor fields (para_id, paragraph_anchor_status, physical_para_ids)",
        ),
        capability_field(
          "comments", "array", false, "DOCX only: comment threads with author, resolved state, parent, and anchor paragraph; done and parent_id appear only when the document records them",
        ),
        capability_field(
          "revisions", "array", false, "DOCX only: unaccepted tracked changes with type (ins|del) and the containing paragraph; author, date, and id appear only when the document records them",
        ),
        capability_field(
          "styles_in_use", "array", false, "DOCX only: deduplicated referenced styles",
        ),
        capability_field("images", "array", false, "DOCX only: image metadata"),
        capability_field(
          "sections", "array", false, "DOCX only: section boundaries and header/footer references",
        ),
        capability_field(
          "diagnostics", "array", false, "DOCX only: reader and source diagnostics",
        ),
        capability_field(
          "path", "literal(/xlsx/workbook)", false, "XLSX only: canonical workbook selector",
        ),
        capability_field(
          "sheet_count", "integer", false, "XLSX only: workbook tab count",
        ),
        capability_field(
          "active_sheet", "object", false, "XLSX only: canonical active-sheet summary when the workbook has tabs",
        ),
        capability_field(
          "sheets", "array", false, "XLSX only: bounded tab-order sheet summaries with canonical paths and used ranges",
        ),
        capability_field(
          "defined_names", "array", false, "XLSX only: bounded workbook defined-name inventory",
        ),
        capability_field(
          "limits", "object", false, "XLSX only: effective scan and metadata limits",
        ),
      ],
      output_modes: ["human", "json"],
      variants: [
        capability_variant("docx", "office outline FILE", SCHEMA_DOCX_OUTLINE, [
          "format=docx",
        ]),
        capability_variant("xlsx", "office outline FILE", SCHEMA_XLSX_OUTLINE, [
          "format=xlsx",
        ]),
      ],
    },
    {
      name: "get",
      summary: "Resolve one canonical XLSX or DOCX selector",
      usage: "office get FILE SELECTOR [--max-elements N] [--max-output-chars N] [--json]",
      formats: ["docx", "xlsx"],
      aliases: [],
      inputs: [
        capability_field("file", "path", true, "existing XLSX or DOCX package"),
        capability_field(
          "selector", "office.selector/1", true, "canonical selector matching the validated package format",
        ),
        capability_field(
          "max-elements", "integer(1..200000)", false, "DOCX projection-node or XLSX cell scan ceiling; default 50000; XLSX effective hard ceiling 100000",
        ),
        capability_field(
          "max-output-chars", "integer(1..4194304)", false, "successful stdout ceiling including trailing LF; failure envelopes are separate; default 1048576",
        ),
        capability_field("json", "boolean", false, "emit office.output/1 JSON"),
      ],
      outputs: [
        capability_field(
          "schema", "enum(office.docx.element/1|office.xlsx.element/1)", true, "format-specific versioned result schema",
        ),
        capability_field(
          "file", "path", true, "the input path exactly as supplied",
        ),
        capability_field(
          "format", "enum(docx|xlsx)", true, "resolved document format",
        ),
        capability_field(
          "path", "office.selector/1", true, "resolved canonical path",
        ),
        capability_field(
          "kind", "string", true, "resolved workbook, sheet, coordinate, story, annotation, or element kind",
        ),
        capability_field(
          "role", "enum(story-root|annotation-collection|annotation-item|element)",
          false, "DOCX only: projection role",
        ),
        capability_field(
          "stability", "enum(stable|snapshot-relative)", true, "selector stability classification",
        ),
        capability_field(
          "source", "object", false, "DOCX only: physical story source metadata",
        ),
        capability_field(
          "parent", "office.selector/1", false, "canonical parent path; absent for projection roots",
        ),
        capability_field(
          "id", "string", false, "the entry's stable id: an annotation id, or a soundly-joined UNIQUE paragraph's canonical w14:paraId — resolvable back via p[id=\"…\"]; duplicates never earn one",
        ),
        capability_field(
          "para_id", "string", false, "DOCX paragraph entries only: canonical w14:paraId, null unless the paragraph carries a valid one",
        ),
        capability_field(
          "paragraph_anchor_status", "string", false, "DOCX paragraph entries only: unique|missing|invalid|duplicate|multi_physical|unjoined — unjoined means no sound tree/projection correspondence exists, so no identity is claimed",
        ),
        capability_field(
          "physical_para_ids", "array", false, "DOCX paragraph entries only: non-null only for multi_physical — the participating paragraphs' valid ids, bounded",
        ),
        capability_field(
          "children", "array", false, "DOCX only: addressable direct children (paragraph child references carry the anchor fields too)",
        ),
        capability_field(
          "properties", "object", false, "DOCX only: declared formatting and element summary",
        ),
        capability_field(
          "metadata", "object", false, "DOCX only: role-specific metadata",
        ),
        capability_field(
          "text", "string", false, "DOCX only: bounded raw text projection",
        ),
        capability_field(
          "sheet_count", "integer", false, "XLSX workbook selectors only: workbook tab count",
        ),
        capability_field(
          "sheets", "array", false, "XLSX workbook selectors only: bounded tab-order sheet summaries",
        ),
        capability_field(
          "defined_names", "array", false, "XLSX workbook selectors only: bounded defined-name inventory",
        ),
        capability_field(
          "sheet", "object", false, "XLSX sheet selectors only: bounded sheet summary",
        ),
        capability_field(
          "cell", "object", false, "XLSX cell selectors only: typed value, formula, style, and canonical path",
        ),
        capability_field(
          "cells", "array", false, "XLSX range selectors only: populated cells in row-major order",
        ),
        capability_field(
          "reference", "a1-range", false, "XLSX range selectors only: normalized A1 rectangle",
        ),
        capability_field(
          "styles", "object", false, "XLSX coordinate selectors only: deduplicated referenced style definitions",
        ),
        capability_field(
          "scanned_cells", "integer", false, "XLSX coordinate selectors only: exact rectangle scan count",
        ),
        capability_field(
          "returned", "integer", false, "XLSX range selectors only: populated cell count",
        ),
      ],
      output_modes: ["human", "json"],
      variants: [
        capability_variant(
          "docx",
          "office get FILE /docx/...",
          SCHEMA_DOCX_ELEMENT,
          ["format=docx"],
        ),
        capability_variant(
          "xlsx",
          "office get FILE /xlsx/...",
          SCHEMA_XLSX_ELEMENT,
          ["format=xlsx"],
        ),
      ],
    },
    {
      name: "text",
      summary: "Extract bounded path-tagged XLSX cell or DOCX paragraph text",
      usage: "office text FILE [--under SELECTOR] [--offset N] [--limit N] [--max-elements N] [--max-output-chars N] [--json]",
      formats: ["docx", "xlsx"],
      aliases: [],
      inputs: [
        capability_field("file", "path", true, "existing XLSX or DOCX package"),
        capability_field(
          "under", "office.selector/1", false, "optional canonical DOCX subtree or XLSX workbook/sheet/range/cell scope",
        ),
        capability_field(
          "offset", "integer(0..200000)", false, "zero-based matching paragraph or cell offset; default 0",
        ),
        capability_field(
          "limit", "integer(0..10000)", false, "maximum returned paragraphs or cells; default 2000",
        ),
        capability_field(
          "max-elements", "integer(1..200000)", false, "DOCX projection-node or XLSX cell scan ceiling; default 50000; XLSX effective hard ceiling 100000",
        ),
        capability_field(
          "max-output-chars", "integer(1..4194304)", false, "successful stdout ceiling including trailing LF; failure envelopes are separate; default 1048576",
        ),
        capability_field("json", "boolean", false, "emit office.output/1 JSON"),
      ],
      outputs: [
        capability_field(
          "schema", "enum(office.docx.text/1|office.xlsx.text/1)", true, "format-specific versioned result schema",
        ),
        capability_field(
          "file", "path", true, "the input path exactly as supplied",
        ),
        capability_field(
          "format", "enum(docx|xlsx)", true, "resolved document format",
        ),
        capability_field(
          "entries", "array(object{path,text,stability})", true, "paragraphs in document order or cells in sheet/row-major order. DOCX paragraph records also carry para_id (canonical w14:paraId or null), paragraph_anchor_status (unique|missing|invalid|duplicate|multi_physical|unjoined — unjoined means no sound tree/projection correspondence, e.g. nested paragraphs or a document the strict reader refuses), and physical_para_ids (non-null only for multi_physical)",
        ),
        capability_field(
          "matched_total", "integer", true, "complete bounded-scan matching paragraph or cell count",
        ),
        capability_field(
          "returned", "integer", true, "number of returned entries",
        ),
        capability_field(
          "truncated", "boolean", true, "whether pagination omitted later matches",
        ),
        capability_field(
          "offset", "integer", true, "applied zero-based match offset",
        ),
        capability_field("limit", "integer", true, "applied page-size ceiling"),
        capability_field(
          "scanned_elements", "integer", false, "DOCX only: projected element count",
        ),
        capability_field(
          "scanned_cells", "integer", false, "XLSX only: exact bounded cell scan count",
        ),
        capability_field(
          "under", "office.selector/1", false, "resolved canonical scope when one was requested",
        ),
      ],
      output_modes: ["human", "json"],
      variants: [
        capability_variant(
          "docx",
          "office text FILE [--under /docx/...]",
          SCHEMA_DOCX_TEXT,
          ["format=docx"],
        ),
        capability_variant(
          "xlsx",
          "office text FILE [--under /xlsx/...]",
          SCHEMA_XLSX_TEXT,
          ["format=xlsx"],
        ),
      ],
    },
    {
      name: "query",
      summary: "Run bounded deterministic predicates over XLSX cells or DOCX elements",
      usage: "office query FILE [CELL_SELECTOR] [--under SELECTOR] [--kind KIND] [--text TEXT] [--id ID] [--property NAME=VALUE]... [--ignore-case] [--offset N] [--limit N] [--max-elements N] [--max-output-chars N] [--json]",
      formats: ["docx", "xlsx"],
      aliases: [],
      inputs: [
        capability_field("file", "path", true, "existing XLSX or DOCX package"),
        capability_field(
          "selector", "xlsx-cell-selector", false, "XLSX only: cell followed by up to 16 bounded type, value, formula, or exact-whitespace text predicates with optional JSON-string escaping; default cell",
        ),
        capability_field(
          "under", "office.selector/1", false, "optional canonical DOCX subtree or XLSX workbook/sheet/range/cell scope",
        ),
        capability_field(
          "kind", "enum(body|header|footer|footnotes|endnotes|comments|note|comment|p|r|tbl|tr|tc|hyperlink|image)",
          false, "DOCX only: exact kind; documented aliases normalize before matching",
        ),
        capability_field(
          "text", "literal-string(1..1048576 chars)", false, "DOCX only: literal substring predicate; regular expressions are not accepted",
        ),
        capability_field(
          "id", "string(1..1048576 chars)", false, "DOCX only: exact annotation id predicate",
        ),
        capability_field(
          "property", "array(NAME=VALUE)", false, "DOCX only: up to 16 exact declared-property predicates",
        ),
        capability_field(
          "ignore-case", "boolean", false, "DOCX only: locale-independent Unicode simple-case --text matching",
        ),
        capability_field(
          "offset", "integer(0..200000)", false, "zero-based match offset; default 0",
        ),
        capability_field(
          "limit", "integer(0..1000)", false, "maximum returned matches; default 100",
        ),
        capability_field(
          "max-elements", "integer(1..200000)", false, "DOCX projection-node or XLSX cell scan ceiling; default 50000; XLSX effective hard ceiling 100000",
        ),
        capability_field(
          "max-output-chars", "integer(1..4194304)", false, "successful stdout ceiling including trailing LF; failure envelopes are separate; default 1048576",
        ),
        capability_field("json", "boolean", false, "emit office.output/1 JSON"),
      ],
      outputs: [
        capability_field(
          "schema", "enum(office.docx.query/1|office.xlsx.query/1)", true, "format-specific versioned result schema",
        ),
        capability_field(
          "file", "path", true, "the input path exactly as supplied",
        ),
        capability_field(
          "format", "enum(docx|xlsx)", true, "resolved document format",
        ),
        capability_field(
          "filters", "object", false, "DOCX only: normalized predicates applied by this query",
        ),
        capability_field(
          "matches", "array", true, "deterministic document-order or sheet/row-major match records; DOCX paragraph matches carry para_id, paragraph_anchor_status, and physical_para_ids",
        ),
        capability_field(
          "matched_total", "integer", true, "complete bounded-scan match count",
        ),
        capability_field(
          "returned", "integer", true, "number of returned matches",
        ),
        capability_field(
          "truncated", "boolean", true, "whether pagination omitted later matches",
        ),
        capability_field(
          "offset", "integer", true, "applied zero-based match offset",
        ),
        capability_field("limit", "integer", true, "applied page-size ceiling"),
        capability_field(
          "scanned_elements", "integer", false, "DOCX only: projected element count",
        ),
        capability_field(
          "selector", "xlsx-cell-selector", false, "XLSX only: supplied bounded cell selector",
        ),
        capability_field(
          "styles", "object", false, "XLSX only: deduplicated styles referenced by returned matches",
        ),
        capability_field(
          "scanned_cells", "integer", false, "XLSX only: exact bounded cell scan count",
        ),
        capability_field(
          "under", "office.selector/1", false, "resolved canonical scope when one was requested",
        ),
      ],
      output_modes: ["human", "json"],
      variants: [
        capability_variant(
          "docx",
          "office query FILE [DOCX predicates]",
          SCHEMA_DOCX_QUERY,
          ["format=docx"],
        ),
        capability_variant(
          "xlsx",
          "office query FILE [cell[predicate]...]",
          SCHEMA_XLSX_QUERY,
          ["format=xlsx"],
        ),
      ],
    },
    {
      name: "find",
      summary: "List every literal text candidate in a DOCX, with whether an edit there is allowed",
      usage: "office find FILE --text TEXT [--in PATH] [--limit N] [--context N] [--json]",
      formats: ["docx"],
      aliases: [],
      inputs: [
        capability_field(
          "file", "path", true, "existing .docx package (never modified)",
        ),
        capability_field(
          "text", "string", true, "literal text to find — never a regular expression or wildcard; matched over the reader PROJECTION, so it spans run boundaries",
        ),
        capability_field(
          "in", "string", false, "restrict to a body-relative subtree by path prefix (p[3], tbl[1]) or by stable identity: p[id=\"1A2B3C4D\"] resolves through the anchor judge and refuses ambiguous, buried, absent, or invalid ids — never first-wins",
        ),
        capability_field(
          "limit", "integer", false, "maximum returned candidates (default 100, hard limit 1000)",
        ),
        capability_field(
          "context", "integer", false, "projection characters of context each side (default 24, maximum 200)",
        ),
        capability_field(
          "json", "boolean", false, "emit one office.output/1 JSON document",
        ),
      ],
      outputs: [
        capability_field(
          "schema", "literal(office.docx.matches/1)", true, "match result schema",
        ),
        capability_field("file", "string", true, "the searched path"),
        capability_field(
          "format", "literal(docx)", true, "searched document format",
        ),
        capability_field(
          "text", "string", true, "the literal that was searched for",
        ),
        capability_field(
          "in", "string", false, "the subtree restriction, null when unrestricted",
        ),
        capability_field(
          "stories_scanned", "array(string)", true, "the stories searched; /body in v1",
        ),
        capability_field(
          "matches", "array(object)", true, "per candidate: ordinal, story, path, range {start, end, unit=utf16} paragraph-relative over the PROJECTION, text, context_before, context_after, runs (affected run paths), source_kinds (text|tab|no-break-hyphen|soft-hyphen|symbol), actionable, reason (null when actionable), para_id (canonical uppercase w14:paraId, null unless the paragraph carries a valid one), paragraph_anchor_status (unique|missing|invalid|duplicate|multi_physical — anchor health is a separate dimension from actionable; multi_physical means NO one-to-one logical/physical mapping, whether revision-joined from several w:p or sharing one w:p with another logical paragraph), and physical_para_ids (non-null only for multi_physical: the participating paragraphs' valid ids, bounded). `actionable` reports whether the RANGE is structurally editable — regions, ancestry, boundaries, carriers — NOT that any given replacement will be accepted; validity of the new text belongs to the write, so a replacement carrying a control character is still refused over an actionable range",
        ),
        capability_field(
          "matches_total", "integer", true, "candidates that EXIST in the searched stories, counted whether or not --limit examined them",
        ),
        capability_field(
          "actionable_returned", "integer", true, "of the RETURNED entries, how many a partial edit would be permitted over. Counted over the returned page rather than the document, because a candidate past --limit is never offered to the planner and so has no verdict",
        ),
        capability_field(
          "unactionable_returned", "integer", true, "of the RETURNED entries, how many exist but must not be rewritten",
        ),
        capability_field(
          "truncated", "boolean", true, "whether --limit omitted later candidates",
        ),
      ],
      output_modes: ["human", "json"],
      variants: [
        capability_variant(
          "docx",
          "office find FILE --text TEXT [--in PATH]",
          SCHEMA_DOCX_MATCHES,
          ["format=docx"],
        ),
      ],
    },
    {
      name: "replace",
      summary: "Replace literal text in a DOCX, refusing wherever an edit would not survive",
      usage: "office replace FILE OUT.docx --text TEXT --with TEXT [--in PATH] [--nth K] [--expect N] [--allow-zero] [--dry-run] [--overwrite] [--json]",
      formats: ["docx"],
      aliases: [],
      inputs: [
        capability_field(
          "file", "path", true, "existing .docx package (never modified in place)",
        ),
        capability_field(
          "out", "path", true, "destination .docx; created atomically, nothing written on any refusal",
        ),
        capability_field(
          "text", "string", true, "literal text to replace — never a regular expression or wildcard; matched over the reader PROJECTION, so it spans run boundaries",
        ),
        capability_field(
          "with", "string", true, "replacement text; empty deletes the match. Control characters including tab and newline are rejected — v1 makes no breaks or tabs from text",
        ),
        capability_field(
          "in", "string", false, "restrict to a body-relative subtree by path prefix (p[3], tbl[1]) or by stable identity: p[id=\"1A2B3C4D\"] resolves against the transaction snapshot with the typed para_id refusals; the report then records resolved_in",
        ),
        capability_field(
          "nth", "integer", false, "select ONE candidate by the ordinal `office find` reports (1-based, counted over ALL candidates including restricted ones); selecting a restricted candidate refuses naming its reason",
        ),
        capability_field(
          "expect", "integer", false, "assert exactly N replacements are selected; a mismatch refuses with nothing written. Contradicts --allow-zero",
        ),
        capability_field(
          "allow-zero", "boolean", false, "treat zero matches as success instead of refusing",
        ),
        capability_field(
          "dry-run", "boolean", false, "run the identical selection and preflight pipeline, exit as the real run would, write nothing",
        ),
        capability_field(
          "overwrite", "boolean", false, "replace an existing destination",
        ),
        capability_field(
          "json", "boolean", false, "emit one office.output/1 JSON document",
        ),
      ],
      outputs: [
        capability_field(
          "schema", "literal(office.docx.replace/1)", true, "replace result schema",
        ),
        capability_field("file", "string", true, "the edited source path"),
        capability_field(
          "format", "literal(docx)", true, "edited document format",
        ),
        capability_field(
          "output", "string", true, "the publication destination",
        ),
        capability_field(
          "text", "string", true, "the literal that was replaced (bounded)",
        ),
        capability_field(
          "with", "string", true, "the replacement text (bounded)",
        ),
        capability_field(
          "in", "string", false, "the subtree restriction, null when unrestricted",
        ),
        capability_field(
          "nth", "integer", false, "the selected ordinal, null when all candidates were selected",
        ),
        capability_field(
          "expect", "integer", false, "the asserted count, null when not asserted",
        ),
        capability_field(
          "allow_zero", "boolean", true, "whether zero matches was permitted",
        ),
        capability_field(
          "resolved_in", "string", false, "the scan path a stable p[id=\"…\"] scope resolved to; null when the scope was ordinal or absent",
        ),
        capability_field(
          "dry_run", "boolean", true, "whether this run validated without publishing",
        ),
        capability_field(
          "selected", "array(integer)", true, "the replaced candidates' ordinals — the same ordinals `office find` reports",
        ),
        capability_field(
          "replaced", "integer", true, "how many occurrences were replaced",
        ),
        capability_field(
          "affected", "array(string)", true, "the affected paragraphs' body-relative paths; each was read back after the splice and its FULL projection compared against the plan-time expectation",
        ),
        capability_field(
          "affected_paragraphs", "array(object)", true, "the same paragraphs with stable identity: path, para_id (canonical w14:paraId or null), and paragraph_anchor_status — the anchors to re-address by once ordinal paths go stale",
        ),
        capability_field(
          "matches", "array(object)", true, "the SELECTED candidates in find's entry shape (ordinal, path, range, text, context, runs, source_kinds, actionable, reason, para_id, paragraph_anchor_status, physical_para_ids) — the matches payload a dry-run prints, emitted on every run; at most 100 entries",
        ),
        capability_field(
          "matches_truncated", "boolean", true, "whether the matches array omitted selected candidates beyond the 100-entry bound; selected and replaced still count them all",
        ),
        capability_field("changed", "boolean", true, "whether any byte changed"),
        capability_field(
          "stories_scanned", "array(string)", true, "the stories searched; /body in v1",
        ),
        capability_field(
          "transaction", "object", true, "office.transaction/2 report; preservation is authoritative, candidates are validated strictly, and the replace readback re-reads every affected paragraph before publication. Nothing is published on any refusal",
        ),
      ],
      output_modes: ["human", "json"],
      variants: [
        capability_variant(
          "docx",
          "office replace FILE OUT.docx --text TEXT --with TEXT",
          "office.docx.replace/1",
          ["format=docx"],
        ),
      ],
    },
    {
      name: "format",
      summary: "Apply direct character formatting to selected text in a DOCX, refusing wherever the result could differ from the request",
      usage: "office format FILE OUT.docx (--text TEXT [--in PATH] [--nth K] | --range START:END --in P) [--bold on|off] [--italic on|off] [--underline on|off] [--color RRGGBB] [--expect N] [--allow-zero] [--dry-run] [--overwrite] [--json]  (at least one property flag)",
      formats: ["docx"],
      aliases: [],
      inputs: [
        capability_field(
          "file", "path", true, "existing .docx package (never modified in place)",
        ),
        capability_field(
          "out", "path", true, "destination .docx; created atomically, nothing written on any refusal",
        ),
        capability_field(
          "text", "string", false, "literal text to format — never a regular expression; matched over the reader PROJECTION, so it spans run boundaries. Every occurrence is selected unless --nth narrows it. Exactly one of --text / --range",
        ),
        capability_field(
          "range", "string", false, "paragraph-local unit range START:END (half-open, the units the read surfaces report); requires --in naming ONE paragraph. Exactly one of --text / --range",
        ),
        capability_field(
          "in", "string", false, "restrict to a body-relative subtree (p[3], tbl[1]) or a stable p[id=\"…\"] resolved against the transaction snapshot; the report then records resolved_in",
        ),
        capability_field(
          "nth", "integer", false, "select ONE text occurrence by ordinal (1-based)",
        ),
        capability_field(
          "bold", "string", false, "on|off — set or clear bold explicitly; an omitted property is left untouched, everywhere",
        ),
        capability_field(
          "italic", "string", false, "on|off — set or clear italic",
        ),
        capability_field(
          "underline", "string", false, "on|off — set or clear single underline",
        ),
        capability_field(
          "color", "string", false, "RRGGBB or #RRGGBB — absolute text colour; the engine refuses where theme linkage cannot be removed faithfully",
        ),
        capability_field(
          "expect", "integer", false, "assert exactly N spans are selected; a mismatch refuses with nothing written. Contradicts --allow-zero",
        ),
        capability_field(
          "allow-zero", "boolean", false, "treat zero selected spans as success instead of refusing",
        ),
        capability_field(
          "dry-run", "boolean", false, "run the identical selection and preflight pipeline, exit as the real run would, write nothing",
        ),
        capability_field(
          "overwrite", "boolean", false, "replace an existing destination",
        ),
        capability_field(
          "json", "boolean", false, "emit one office.output/1 JSON document",
        ),
      ],
      outputs: [
        capability_field(
          "schema", "literal(office.docx.format/1)", true, "format result schema",
        ),
        capability_field("file", "string", true, "the edited source path"),
        capability_field(
          "format", "literal(docx)", true, "edited document format",
        ),
        capability_field(
          "output", "string", true, "the publication destination",
        ),
        capability_field(
          "mode", "string", true, "which selector produced the spans: text or range",
        ),
        capability_field(
          "text", "string", false, "the literal that was formatted (bounded), null in range mode",
        ),
        capability_field(
          "in", "string", false, "the subtree restriction, null when unrestricted",
        ),
        capability_field(
          "resolved_in", "string", false, "the scan path a stable p[id=\"…\"] scope resolved to; null when the scope was ordinal or absent",
        ),
        capability_field(
          "range", "string", false, "the requested unit range START:END, null in text mode",
        ),
        capability_field(
          "nth", "integer", false, "the selected ordinal, null when all occurrences were selected",
        ),
        capability_field(
          "bold", "boolean", false, "the request's bold state: true set, false cleared, null untouched",
        ),
        capability_field(
          "italic", "boolean", false, "the request's italic state, three-state as bold",
        ),
        capability_field(
          "underline", "boolean", false, "the request's underline state, three-state as bold",
        ),
        capability_field(
          "color", "string", false, "the requested absolute colour, null when untouched",
        ),
        capability_field(
          "expect", "integer", false, "the asserted span count, null when not asserted",
        ),
        capability_field(
          "allow_zero", "boolean", true, "whether zero selected spans was permitted",
        ),
        capability_field(
          "dry_run", "boolean", true, "whether this run validated without publishing",
        ),
        capability_field(
          "changed", "boolean", true, "whether any byte changed — a span already carrying the request selects and plans nothing",
        ),
        capability_field(
          "selected", "array(integer)", true, "the selected occurrences' ordinals in text mode; empty in range mode",
        ),
        capability_field(
          "spans", "array(object)", true, "every formatted span: path, para_id, paragraph_anchor_status, start, end (half-open units), and the span's text (bounded)",
        ),
        capability_field(
          "affected", "array(string)", true, "the affected paragraphs' body-relative paths; each was read back after the splice with the three-check readback — projection unchanged, request carried explicitly, nothing else moved",
        ),
        capability_field(
          "affected_paragraphs", "array(object)", true, "the same paragraphs with stable identity: path, para_id (canonical w14:paraId or null), and paragraph_anchor_status",
        ),
        capability_field(
          "runs_changed", "integer", true, "runs whose properties the plan rewrote",
        ),
        capability_field(
          "runs_already_satisfied", "integer", true, "runs that already carried the request explicitly and were left untouched",
        ),
        capability_field(
          "splits", "integer", true, "runs the plan clone-split so formatting landed only on the selected units",
        ),
        capability_field(
          "byte_edits", "integer", true, "byte edits the splice plan declared",
        ),
        capability_field(
          "stories_scanned", "array(string)", true, "the stories searched; /body in v1",
        ),
        capability_field(
          "transaction", "object", true, "office.transaction/2 report; the shared mutation preflight (signature, enforced protection, trackRevisions, the compatibility contract) refuses before planning, and nothing is published on any refusal",
        ),
      ],
      output_modes: ["human", "json"],
      variants: [
        capability_variant(
          "docx",
          "office format FILE OUT.docx --text TEXT --bold on",
          "office.docx.format/1",
          ["format=docx"],
        ),
      ],
    },
    {
      name: "insert-paragraph",
      summary: "Insert one resource-free paragraph beside a direct body paragraph, minting its stable identity",
      usage: "office insert-paragraph FILE OUT.docx (--before P|--after P) --content JSON [--dry-run] [--overwrite] [--json]",
      formats: ["docx"],
      aliases: [],
      inputs: [
        capability_field(
          "file", "path", true, "existing .docx package (never modified in place)",
        ),
        capability_field(
          "out", "path", true, "destination .docx; created atomically, nothing written on refusal",
        ),
        capability_field(
          "before", "string", false, "insert before this DIRECT body paragraph (p[3]); exclusive with --after",
        ),
        capability_field(
          "after", "string", false, "insert after this DIRECT body paragraph (p[3]); exclusive with --before",
        ),
        capability_field(
          "content", "docx.paragraph/1", true, "the dedicated payload: optional \"style\" (a paragraph style id the TARGET's styles part must define, else refuse naming it) and \"runs\" of {text, bold?, italic?, underline?} — resource-free only. Hyperlinks, images, notes, and list bullets are v1 refusals; run text rejects control characters",
        ),
        capability_field(
          "dry-run", "boolean", false, "run the identical mint/plan/validate pipeline, exit as the real run would, write nothing",
        ),
        capability_field(
          "overwrite", "boolean", false, "replace an existing destination",
        ),
        capability_field(
          "json", "boolean", false, "emit one office.output/1 JSON document",
        ),
      ],
      outputs: [
        capability_field(
          "schema", "literal(office.docx.insert-paragraph/1)", true, "result schema",
        ),
        capability_field(
          "file", "path", true, "the input path exactly as supplied",
        ),
        capability_field("format", "literal(docx)", true, "the edited format"),
        capability_field("output", "path", true, "the destination path"),
        capability_field("at", "string", true, "the anchor as requested"),
        capability_field(
          "side", "enum(before|after)", true, "which side of the anchor",
        ),
        capability_field(
          "dry_run", "boolean", true, "whether this was a dry run",
        ),
        capability_field(
          "path", "string", true, "the ordinal path the new paragraph answers to — READBACK-VERIFIED before publication",
        ),
        capability_field(
          "para_id", "string", true, "the MINTED w14:paraId (canonical uppercase, allocated fresh against the whole package's inventory, stamped into the fragment before planning) — the stable address to re-anchor by; a new physical paragraph is the only thing that ever receives a new id",
        ),
        capability_field("changed", "boolean", true, "whether any byte changed"),
        capability_field(
          "transaction", "object", true, "office.transaction/2 report; the insert readback verifies the minted identity reads back UNIQUE at the reported path before publication. Nothing is published on any refusal",
        ),
      ],
      output_modes: ["human", "json"],
      variants: [
        capability_variant(
          "docx",
          "office insert-paragraph FILE OUT.docx --after 'p[2]' --content '{\"runs\":[{\"text\":\"…\"}]}'",
          "office.docx.insert-paragraph/1",
          ["format=docx"],
        ),
      ],
    },
    {
      name: "validate",
      summary: "Validate an XLSX or DOCX package with the shared mutation gate",
      usage: "office validate FILE [--json|--jsonl]",
      formats: ["docx", "xlsx"],
      aliases: [],
      inputs: [
        capability_field("file", "path", true, "existing XLSX or DOCX package"),
        capability_field(
          "json", "boolean", false, "emit one office.output/1 JSON document",
        ),
        capability_field(
          "jsonl", "boolean", false, "emit one office.output/1 line",
        ),
      ],
      outputs: [
        capability_field(
          "schema", "literal(office.validate/1)", true, "versioned validate result schema",
        ),
        capability_field("file", "path", true, "the input path, bounded"),
        capability_field(
          "format", "enum(docx|xlsx)", true, "the structurally verified package format",
        ),
        capability_field(
          "valid", "boolean", true, "true when the shared package gate reported no errors",
        ),
        capability_field(
          "findings", "array(office.finding/1)", true, "bounded office.finding/1 records with severity, code, and message",
        ),
        capability_field(
          "error_count", "integer", true, "number of error findings",
        ),
        capability_field(
          "warning_count", "integer", true, "number of warning findings",
        ),
      ],
      output_modes: ["human", "json", "jsonl"],
      variants: [],
    },
    {
      name: "dump",
      summary: "Dump an XLSX or DOCX package as a replayable office.dump/1 op stream",
      usage: "office dump FILE [--json|--jsonl]",
      formats: ["xlsx", "docx"],
      aliases: [],
      inputs: [
        capability_field("file", "path", true, "existing XLSX or DOCX package"),
        capability_field(
          "json", "boolean", false, "emit the office.dump/1 JSON document",
        ),
        capability_field(
          "jsonl", "boolean", false, "emit the streaming office.dump/1 JSONL form",
        ),
      ],
      outputs: [
        capability_field(
          "schema", "literal(office.dump/1)", true, "versioned replayable dump schema",
        ),
        capability_field(
          "format", "enum(xlsx|docx)", true, "the structurally verified package format",
        ),
        capability_field(
          "source", "object", true, "bounded input path, byte count, and sha256 digest (excluded from fixpoint comparison)",
        ),
        capability_field(
          "replay", "object", true, "batch schema, create parameters, and engine limits for replay",
        ),
        capability_field(
          "ops", "array", true, "ordered canonical versioned batch ops in engine JSON shapes",
        ),
        capability_field(
          "assets", "object", true, "content-addressed binaries: sha256-<hex> id to {content_type, size, data} inline base64 under per-asset and total allowances",
        ),
        capability_field(
          "residual", "array", true, "ordered machine-readable records of content not expressible as ops",
        ),
        capability_field("warnings", "array", true, "bounded dump diagnostics"),
        capability_field(
          "stats", "object", true, "op/asset/residual/warning counts",
        ),
      ],
      output_modes: ["human", "json", "jsonl"],
      variants: [],
    },
    {
      name: "replay",
      summary: "Replay an office.dump/1 document into an XLSX or DOCX package",
      usage: "office replay FILE --output OUT [--overwrite] [--json|--jsonl]",
      formats: ["xlsx", "docx"],
      aliases: [],
      inputs: [
        capability_field(
          "file", "path", true, "existing office.dump/1 JSON document",
        ),
        capability_field(
          "output", "path", true, "destination file matching the dump format (.xlsx or .docx); created atomically, refused when present unless --overwrite",
        ),
        capability_field(
          "overwrite", "boolean", false, "replace an existing destination (remove-then-stage; not a single atomic swap)",
        ),
        capability_field(
          "json", "boolean", false, "emit one office.output/1 JSON document",
        ),
        capability_field(
          "jsonl", "boolean", false, "emit one office.output/1 line",
        ),
      ],
      outputs: [
        capability_field(
          "schema", "literal(office.replay/1)", true, "versioned replay result schema",
        ),
        capability_field(
          "format", "enum(xlsx|docx)", true, "the replayed package format",
        ),
        capability_field(
          "output", "path", true, "the published workbook path, bounded",
        ),
        capability_field(
          "bytes_written", "integer", true, "exact published byte count",
        ),
        capability_field(
          "ops_applied", "integer", true, "number of dump ops replayed",
        ),
      ],
      output_modes: ["human", "json", "jsonl"],
      variants: [],
    },
    {
      name: "issues",
      summary: "Report bounded actionable findings for an XLSX or DOCX package",
      usage: "office issues FILE [--json|--jsonl]",
      formats: ["docx", "xlsx"],
      aliases: [],
      inputs: [
        capability_field("file", "path", true, "existing XLSX or DOCX package"),
        capability_field(
          "json", "boolean", false, "emit one office.output/1 JSON document",
        ),
        capability_field(
          "jsonl", "boolean", false, "emit one office.output/1 line",
        ),
      ],
      outputs: [
        capability_field(
          "schema", "literal(office.issues/1)", true, "versioned issues result schema",
        ),
        capability_field("file", "path", true, "the input path, bounded"),
        capability_field(
          "format", "enum(docx|xlsx)", true, "the structurally verified package format",
        ),
        capability_field(
          "valid", "boolean", true, "true when the shared package gate reported no errors",
        ),
        capability_field(
          "findings", "array(office.finding/1)", true, "bounded office.finding/1 records; XLSX cached formula errors and DOCX reader diagnostics are warnings",
        ),
        capability_field(
          "error_count", "integer", true, "number of error findings",
        ),
        capability_field(
          "warning_count", "integer", true, "number of warning findings",
        ),
      ],
      output_modes: ["human", "json", "jsonl"],
      variants: [],
    },
    {
      name: "preview",
      summary: "Render a deterministic offline HTML preview with inline assets",
      usage: "office preview FILE --output OUT.html [--overwrite] [--json|--jsonl]",
      formats: ["docx", "xlsx"],
      aliases: [],
      inputs: [
        capability_field("file", "path", true, "existing XLSX or DOCX package"),
        capability_field(
          "output", "path", true, "destination .html file; created atomically, refused when present unless --overwrite",
        ),
        capability_field(
          "overwrite", "boolean", false, "replace an existing destination (remove-then-stage; not a single atomic swap)",
        ),
        capability_field(
          "json", "boolean", false, "emit one office.output/1 JSON document",
        ),
        capability_field(
          "jsonl", "boolean", false, "emit one office.output/1 line",
        ),
      ],
      outputs: [
        capability_field(
          "schema", "literal(office.preview/1)", true, "versioned preview result schema",
        ),
        capability_field("file", "path", true, "the input path, bounded"),
        capability_field(
          "format", "enum(docx|xlsx)", true, "the structurally verified package format",
        ),
        capability_field(
          "output", "path", true, "the published preview path, bounded",
        ),
        capability_field(
          "bytes_written", "integer", true, "exact published byte count",
        ),
        capability_field(
          "charts_rendered", "integer", true, "charts rendered as inline SVG",
        ),
        capability_field(
          "charts_placeholder", "integer", true, "charts kept as labeled placeholders",
        ),
        capability_field(
          "images_embedded", "integer", true, "images embedded as data URIs",
        ),
        capability_field(
          "truncation", "object", true, "row/column caps, truncated sheet names, and omitted image count",
        ),
        capability_field(
          "warnings", "array", false, "bounded converter warnings",
        ),
      ],
      output_modes: ["human", "json", "jsonl"],
      variants: [],
    },
    {
      name: "render",
      summary: "Lay out a DOCX and draw it as paginated PDF or SVG",
      usage: "office render FILE --output OUT.(pdf|svg) [--pages RANGE] [--overwrite] [--json|--jsonl]",
      formats: ["docx"],
      aliases: [],
      inputs: [
        capability_field("file", "path", true, "existing DOCX package"),
        capability_field(
          "output", "path", true, "destination path; the extension selects the backend (.pdf or .svg). Created atomically, refused when present unless --overwrite. A multi-page SVG render writes <stem>-<n>.svg per page and publishes each file individually. Destinations are checked before any page is drawn, so an occupied path normally refuses with nothing written -- but that is a check and not a lock, and --overwrite skips it, so a later failure can still leave earlier pages published. Publication across the set does not roll back; when anything has landed the refusal is office.render.partial_publication and lists those paths under details.published",
        ),
        capability_field(
          "pages", "string", false, "pages to render: 1-based numbers and N-M ranges separated by commas, e.g. `3`, `2-5`, `1,4-6`. Normalized to ascending order with duplicates removed, so a page is never published twice. Omitted renders every page, subject to the same 2048-page ceiling",
        ),
        capability_field(
          "overwrite", "boolean", false, "replace an existing destination (remove-then-stage; not a single atomic swap)",
        ),
        capability_field(
          "json", "boolean", false, "emit one office.output/1 JSON document",
        ),
        capability_field(
          "jsonl", "boolean", false, "emit one office.output/1 line",
        ),
      ],
      outputs: [
        capability_field(
          "schema", "literal(office.render/1)", true, "versioned render result schema",
        ),
        capability_field("file", "path", true, "the input path, bounded"),
        capability_field(
          "format", "literal(docx)", true, "the structurally verified package format",
        ),
        capability_field(
          "backend", "enum(pdf|svg)", true, "the emitter selected by the output extension",
        ),
        capability_field(
          "outputs", "array(object{path:path,bytes_written:integer})", true, "every published artifact in page order; one entry for PDF, one per rendered page for multi-page SVG",
        ),
        capability_field(
          "bytes_written", "integer", true, "total bytes published across every artifact, accumulated in 64-bit. One artifact may not exceed 64 MiB and the set may not exceed 256 MiB; either ceiling refuses with office.docx.resource_limit",
        ),
        capability_field(
          "pages_rendered", "integer", true, "pages actually drawn, after --pages selection",
        ),
        capability_field(
          "pages_total", "integer", true, "pages the whole document laid out to, before selection",
        ),
        capability_field(
          "page_width_pt", "number", true, "first rendered page width in points",
        ),
        capability_field(
          "page_height_pt", "number", true, "first rendered page height in points",
        ),
        capability_field(
          "fonts_used", "integer", true, "distinct faces the rendered pages actually reference, counted over the selected pages rather than over the document. PDF embeds a subset of each; SVG only names them in font-family and embeds nothing, so this is a usage count and not an embedding count",
        ),
        capability_field(
          "images_dropped", "integer", true, "image occurrences the PDF backend could not embed, summed across reasons rather than counted as distinct reasons. Always 0 for SVG, which embeds every image as a data URI and therefore drops none -- not because it carries no image data",
        ),
        capability_field(
          "unsupported", "array(string)", true, "bounded notices the layout frontend recorded for content it could not represent, each truncated to 512 characters. This is what the frontend chose to record, not a proof of completeness: some drops are still silent, floating drawings whose relationship does not resolve among them",
        ),
        capability_field(
          "unsupported_total", "integer", true, "notices before bounding",
        ),
        capability_field(
          "byte_determinism", "enum(per-runtime|cross-runtime)", true, "PDF is per-runtime: identical on one runtime, not across native and wasm, because the deflate implementation differs by backend. The document is identical either way -- same pages, same glyph positions, same embedded font subset. SVG is cross-runtime, being uncompressed",
        ),
      ],
      output_modes: ["human", "json", "jsonl"],
      variants: [],
    },
    {
      name: "create",
      summary: "Create a validated Office document atomically",
      usage: "office create (xlsx OUTPUT [--sheet NAME] | docx OUTPUT) [--dry-run] [--overwrite] [--json]",
      formats: ["xlsx", "docx"],
      aliases: [],
      inputs: [
        capability_field(
          "format", "literal(xlsx|docx)", true, "document format subcommand",
        ),
      ],
      outputs: [],
      output_modes: ["human", "json"],
      variants: [
        {
          name: "xlsx",
          usage: "office create xlsx OUTPUT [--sheet NAME] [--dry-run] [--overwrite] [--json]",
          result_schema: SCHEMA_XLSX_CREATE_RESULT,
          registry: None,
          inputs: [
            capability_field("output", "path", true, "new .xlsx destination"),
            capability_field(
              "sheet", "xlsx-sheet-name", false, "first worksheet name; default Sheet1",
            ),
            capability_field(
              "dry-run", "boolean", false, "validate without publishing",
            ),
            capability_field(
              "overwrite", "boolean", false, "atomically replace an existing regular-file destination",
            ),
            capability_field(
              "json", "boolean", false, "emit office.output/1 JSON",
            ),
          ],
          outputs: [
            capability_field(
              "sheet", "xlsx-sheet-name", true, "created worksheet name",
            ),
            capability_field(
              "transaction",
              SCHEMA_TRANSACTION,
              true,
              "validation, preservation, and publication report",
            ),
          ],
          constraints: [
            "format=xlsx",
            "output-extension=.xlsx",
            "create-new-by-default",
            "transactional-publication",
            "bounded-candidate-package",
            "candidate-max-entry-bytes=\{XLSX_TRANSACTION_MAX_CANDIDATE_ENTRY_BYTES}",
            "candidate-max-uncompressed-bytes=\{XLSX_TRANSACTION_MAX_CANDIDATE_ARCHIVE_BYTES}",
          ],
          actions: [],
          output_modes: ["human", "json"],
        },
        {
          name: "docx",
          usage: "office create docx OUTPUT [--dry-run] [--overwrite] [--json]",
          result_schema: SCHEMA_DOCX_CREATE_RESULT,
          registry: None,
          inputs: [
            capability_field("output", "path", true, "new .docx destination"),
            capability_field(
              "dry-run", "boolean", false, "validate without publishing",
            ),
            capability_field(
              "overwrite", "boolean", false, "atomically replace an existing regular-file destination",
            ),
            capability_field(
              "json", "boolean", false, "emit office.output/1 JSON",
            ),
          ],
          outputs: [
            capability_field(
              "transaction",
              SCHEMA_TRANSACTION,
              true,
              "validation, preservation, and publication report",
            ),
          ],
          constraints: [
            "format=docx", "output-extension=.docx", "create-new-by-default", "transactional-publication",
            "bounded-candidate-package", "blank-document-only",
          ],
          actions: [],
          output_modes: ["human", "json"],
        },
      ],
    },
    {
      name: "template",
      summary: "Merge strict {{key}} template data into an XLSX or DOCX document",
      usage: "office template FILE DATA.json --out OUT [--dry-run] [--overwrite] [--allow-missing] [--json|--jsonl]",
      formats: ["xlsx", "docx"],
      aliases: [],
      inputs: [
        capability_field(
          "file", "path", true, "existing XLSX or DOCX template package (never modified)",
        ),
        capability_field(
          "data", "path", true, "office.template.data/1 JSON document. Template text uses {{key}}, where key matches [A-Za-z_][A-Za-z0-9_.-]{0,63}; \\{{ emits a literal {{. Examples: XLSX cell `Invoice for {{customer}}`; DOCX text `Prepared for {{customer}}`. Data contains flat `values` (string/number/bool) plus an optional `regions` map cloning a marked template row once per record; XLSX accepts {sheet,row}, while DOCX accepts only a body-table {path}",
        ),
        capability_field(
          "out", "path", true, "destination matching the template format; created atomically, refused when present unless --overwrite",
        ),
        capability_field(
          "dry-run", "boolean", false, "run the full merge and validation without publishing",
        ),
        capability_field(
          "overwrite", "boolean", false, "replace an existing destination",
        ),
        capability_field(
          "allow-missing", "boolean", false, "keep unresolved placeholders as literals instead of failing",
        ),
        capability_field(
          "json", "boolean", false, "emit one office.output/1 JSON document",
        ),
        capability_field(
          "jsonl", "boolean", false, "emit one office.output/1 line",
        ),
      ],
      outputs: [
        capability_field(
          "schema", "literal(office.template/1)", true, "versioned template merge result schema",
        ),
        capability_field("replaced", "number", true, "placeholders substituted"),
        capability_field(
          "missing", "array(finding)", true, "unresolved keys with canonical locations (Sheet1!B2 or /docx/body/p[3]; bounded)",
        ),
        capability_field(
          "unused", "array(string)", true, "data keys the template never used (bounded)",
        ),
        capability_field(
          "regions", "array(object)", true, "per repeated region: name, source_location, records, replaced (bounded). XLSX clones a marked row through the atomic grid-bounded insert and refuses any formula-bearing workbook; DOCX clones a marked table row through a fail-closed element/attribute whitelist, stripping w14 paragraph ids. Empty when the data document declares no regions",
        ),
        capability_field(
          "transaction", "object", true, "office.transaction/2 report; preservation is authoritative. XLSX: values land through literal cell setters (a leading = can never become a formula), formula and rich-text cells are refused contexts, whole-cell placeholders keep the data value's type. DOCX: byte-span run rewrites preserve all unrelated OOXML; values inherit the starting run's formatting; body, header, and footer stories are scanned",
        ),
      ],
      output_modes: ["human", "json", "jsonl"],
      variants: [],
    },
    {
      name: "edit",
      summary: "Replace literal text or accept/reject tracked changes in an existing DOCX through a strict edit script",
      usage: "office edit FILE SCRIPT.json --out OUT.docx [--dry-run] [--overwrite] [--allow-unmatched] [--json|--jsonl]",
      formats: ["docx"],
      aliases: [],
      inputs: [
        capability_field(
          "file", "path", true, "existing .docx package (never modified in place)",
        ),
        capability_field(
          "script", "docx.edit/1-or-2-file", true, "strict replace_text OR accept_revision/reject_revision OR (schema docx.edit/2) set_run_text script; a script never mixes operation families. set_run_text: `at` is the body-relative run path from `office query` (`p[3]/r[2]`) or a stable head (`p[id=\"1A2B3C4D\"]/r[2]`, identity-judged at transaction time), `expect` must equal the run's current full text (stale expectations refuse; addresses are snapshot-relative), `text` replaces the run's whole text; setting a run's text to itself validates and changes nothing. replace_text: `find` is LITERAL text — never a regular expression or wildcard — matched across run boundaries; `replace` may be empty to delete the matched text; `occurrence` omitted replaces every occurrence in document order, `occurrence: N` replaces only the Nth. accept_revision/reject_revision select tracked changes by `id` (the stable w:id handle), `author`, `type` (ins|del), or `all: true`; spelled selector fields are conjunctive",
        ),
        capability_field(
          "out", "path", true, "destination .docx; created atomically, refused when present unless --overwrite",
        ),
        capability_field(
          "dry-run", "boolean", false, "run the full edit and validation without publishing",
        ),
        capability_field(
          "overwrite", "boolean", false, "replace an existing destination",
        ),
        capability_field(
          "allow-unmatched", "boolean", false, "report operations that found too few occurrences instead of refusing",
        ),
        capability_field(
          "json", "boolean", false, "emit one office.output/1 JSON document",
        ),
        capability_field(
          "jsonl", "boolean", false, "emit one office.output/1 line",
        ),
      ],
      outputs: [
        capability_field(
          "schema", "literal(office.docx.edit/1) | literal(office.docx.edit/2)",
          true, "versioned edit result schema, matching the script's schema version",
        ),
        capability_field("file", "string", true, "the edited source path"),
        capability_field(
          "format", "literal(docx)", true, "edited document format",
        ),
        capability_field(
          "script_file", "string", true, "the consumed script path",
        ),
        capability_field(
          "output", "string", true, "the publication destination",
        ),
        capability_field(
          "ops_applied", "number", true, "operations in the script",
        ),
        capability_field(
          "replacements", "number", true, "text spans rewritten across every operation; always 0 for a revision script",
        ),
        capability_field(
          "revisions_resolved", "number", true, "distinct tracked changes accepted or rejected; always 0 for a replace_text script",
        ),
        capability_field(
          "results", "array(object)", true, "per op: op, find, replace, occurrence, selector, matched, replacements, resolved — all bounded, with one fixed key set per schema version; docx.edit/2 results additionally carry at, expect, and text on EVERY entry (null when inapplicable), plus resolved_at ONLY on a set_run_text entry whose stable head resolved — the one conditional key. A replace_text entry nulls selector; a revision entry nulls find, replace, and occurrence and carries selector {id, author, type, all}; a set_run_text entry nulls find, replace, occurrence, and selector and carries at/expect/text with matched (address resolved) and replacements (spans rewritten)",
        ),
        capability_field(
          "unmatched", "array(finding)", true, "operations that found fewer occurrences than they require, or revision selectors that matched no tracked change (bounded); refuses unless --allow-unmatched",
        ),
        capability_field(
          "unmatched_total", "number", true, "unmatched operations before bounding",
        ),
        capability_field(
          "unsupported", "array(finding)", true, "matches the edit cannot rewrite safely — content a byte-span run rewrite cannot own, matches crossing a hyperlink boundary, and matches in footnote, endnote, or comment stories — and selected tracked changes outside the resolvable set: property revisions (w:rPr/w:ins paragraph marks, w:trPr/w:del rows), moves, every *PrChange, revisions wrapping rows or block content, and revisions in footnote, endnote, or comment stories (bounded)",
        ),
        capability_field(
          "unsupported_total", "number", true, "unsupported matches before bounding",
        ),
        capability_field(
          "conflicts", "array(finding)", true, "paragraph locations where two operations match overlapping text, where accept_revision and reject_revision both select one tracked change, or where a selected revision contains another revision (bounded)",
        ),
        capability_field(
          "conflicts_total", "number", true, "overlapping match sites before bounding",
        ),
        capability_field(
          "locations", "array(finding)", true, "canonical paragraph location and needle for each rewritten span, or the accepted/rejected revision for each resolved tracked change (bounded)",
        ),
        capability_field(
          "locations_truncated", "boolean", true, "whether locations omitted later sites",
        ),
        capability_field(
          "stories_scanned", "array(string)", true, "the stories the edit scanned: /body, then /header[K] and /footer[K]",
        ),
        capability_field(
          "transaction", "object", true, "office.transaction/2 report; preservation is authoritative. Matches and revisions are resolved against the ORIGINAL snapshot — operations never see each other's output — and applied as byte-span edits, so all unrelated OOXML survives; a replacement inherits the formatting of the run the match started in; accepting an insertion or rejecting a deletion unwraps the element and keeps its runs (each w:delText is renamed back to w:t in place), while rejecting an insertion or accepting a deletion removes the element and its content; nothing is published on any refusal, and a zero-change run reuses the exact input bytes",
        ),
      ],
      output_modes: ["human", "json", "jsonl"],
      variants: [],
    },
    {
      name: "annotate",
      summary: "Mutate DOCX comments through a strict annotation script",
      usage: "office annotate FILE SCRIPT.json --out OUT.docx [--dry-run] [--overwrite] [--json|--jsonl]",
      formats: ["docx"],
      aliases: [],
      inputs: [
        capability_field(
          "file", "path", true, "existing .docx package (never modified in place)",
        ),
        capability_field(
          "script", "docx.annotation-batch/1-file", true, "strict comment add/reply/resolve/unresolve script; body is plain paragraphs, anchors are /docx/body/p[K], references are tagged {label} or {comment_id}",
        ),
        capability_field(
          "out", "path", true, "destination .docx; created atomically, refused when present unless --overwrite",
        ),
        capability_field(
          "dry-run", "boolean", false, "run the full fold and validation without publishing",
        ),
        capability_field(
          "overwrite", "boolean", false, "replace an existing destination",
        ),
        capability_field(
          "json", "boolean", false, "emit one office.output/1 JSON document",
        ),
        capability_field(
          "jsonl", "boolean", false, "emit one office.output/1 line",
        ),
      ],
      outputs: [
        capability_field(
          "schema", "literal(office.docx.annotation-batch/1)", true, "versioned annotation-batch result schema",
        ),
        capability_field("ops_applied", "number", true, "comment ops folded"),
        capability_field(
          "results", "array(object)", true, "per op: op, comment_id, done, anchor + anchor_to (comment_add; anchor_to only on a paragraph range), target (reply/resolve/unresolve) — all bounded",
        ),
        capability_field(
          "labels", "array(object)", true, "same-script label -> minted comment_id map",
        ),
        capability_field(
          "changed_parts", "array(string)", true, "the union changed-part manifest across every op",
        ),
        capability_field(
          "transaction", "object", true, "office.transaction/2 report; preservation is authoritative. Comment ops fold over the source-pinned D1 edit session one snapshot at a time; the document part gains only the narrow comment-anchor markers (the body text is never wholesale-rewritten), while the comment, content-type, and relationship parts are added or updated as the comments require; nothing is published on any refusal",
        ),
      ],
      output_modes: ["human", "json", "jsonl"],
      variants: [],
    },
    {
      name: "batch",
      summary: "Apply a strict operation script transactionally (XLSX mutate, DOCX fresh author)",
      usage: "office batch TARGET SCRIPT [--format xlsx|docx] [--out FILE] [--dry-run] [--overwrite] [--json]",
      formats: ["xlsx", "docx"],
      aliases: [],
      inputs: [],
      outputs: [],
      output_modes: ["human", "json"],
      variants: [
        {
          name: "xlsx",
          usage: "office batch TARGET SCRIPT [--out FILE] [--dry-run] [--overwrite] [--json]",
          result_schema: SCHEMA_XLSX_BATCH_RESULT,
          registry: Some(@batch.capabilities()),
          inputs: [
            capability_field("file", "path", true, "existing .xlsx package"),
            capability_field(
              "script", "xlsx.batch/2-file", true, "preferred strict bounded UTF-8 JSON operation script; historical xlsx.batch/1 is also accepted",
            ),
            capability_field(
              "out", "path", false, "separate .xlsx publication destination",
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
              "stats", "object{operation_count,touched_cells,style_cells,row_column_lines,new_style_records}",
              true, "bounded parsed-plan resource accounting",
            ),
            capability_field(
              "transaction",
              SCHEMA_TRANSACTION,
              true,
              "validation, preservation, and publication report",
            ),
          ],
          constraints: [
            "format=xlsx",
            "preferred-schema=xlsx.batch/2",
            "accepted-schemas=xlsx.batch/1|xlsx.batch/2",
            "overwrite-requires(out)",
            "out-extension-must-match-input-format",
            "transactional-publication",
            "full-workbook-rewrite-on-change",
            "zero-op-reuses-original",
            "transaction-max-materialized-cells=\{XLSX_TRANSACTION_MAX_MATERIALIZED_CELLS}",
            "transaction-max-row-column-lines=\{XLSX_TRANSACTION_MAX_ROW_COLUMN_LINES}",
            "read-max-decoded-xml-bytes=\{XLSX_TRANSACTION_MAX_DECODED_XML_BYTES}",
            "read-max-markup-tokens=\{XLSX_TRANSACTION_MAX_XML_MARKUP_TOKENS}",
            "read-max-materialized-row-column-dimensions=\{XLSX_TRANSACTION_MAX_ROW_COLUMN_LINES}",
            "read-max-row-column-dimension-work=\{XLSX_TRANSACTION_MAX_ROW_COLUMN_LINES}",
            "candidate-max-entry-bytes=\{XLSX_TRANSACTION_MAX_CANDIDATE_ENTRY_BYTES}",
            "candidate-max-uncompressed-bytes=\{XLSX_TRANSACTION_MAX_CANDIDATE_ARCHIVE_BYTES}",
          ],
          actions: [],
          output_modes: ["human", "json"],
        },
        {
          name: "docx",
          usage: "office batch --format docx TARGET SCRIPT [--dry-run] [--overwrite] [--json]",
          result_schema: SCHEMA_DOCX_BATCH_RESULT,
          registry: None,
          inputs: [
            capability_field(
              "target", "path", true, "new .docx destination (fresh authoring; never mutates an existing file)",
            ),
            capability_field(
              "script", "docx.batch/2-file", true, "strict bounded UTF-8 authoring script",
            ),
            capability_field(
              "dry-run", "boolean", false, "validate without publishing",
            ),
            capability_field(
              "overwrite", "boolean", false, "replace an existing destination",
            ),
            capability_field(
              "json", "boolean", false, "emit office.output/1 JSON",
            ),
          ],
          outputs: [
            capability_field("ops", "number", true, "authoring ops applied"),
            capability_field("comments", "number", true, "comment ops applied"),
            capability_field(
              "footnotes", "number", true, "footnote refs authored",
            ),
            capability_field(
              "endnotes", "number", true, "endnote refs authored",
            ),
            capability_field(
              "headers", "number", true, "header stories authored",
            ),
            capability_field(
              "footers", "number", true, "footer stories authored",
            ),
            capability_field(
              "transaction",
              SCHEMA_TRANSACTION,
              true,
              "validation, preservation, and publication report",
            ),
          ],
          constraints: [
            "format=docx",
            "preferred-schema=docx.batch/2",
            "accepts-schema=docx.batch/1",
            "output-extension=.docx",
            "fresh-authoring-only",
            "create-new-by-default",
            "out-not-accepted",
            "transactional-publication",
            "bounded-candidate-package",
            "comments-and-notes-require=docx.batch/2",
            "headers-footers-require=docx.batch/2",
            "header-footer-variants=default|first|even",
            "header-footer-content=plain-blocks-and-fields",
            "fields=PAGE|NUMPAGES",
            "max-image-bytes=\{8 * 1024 * 1024}",
            "max-total-image-bytes=\{32 * 1024 * 1024}",
          ],
          actions: [],
          output_modes: ["human", "json"],
        },
      ],
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
          registry: None,
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
          registry: None,
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
          registry: None,
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
              "out", "path", false, "separate destination with the same .docx or .xlsx extension as the input",
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
            "exactly-one(xml,xml-file)", "overwrite-requires(out)", "out-extension-must-match-input-format",
            "transactional-publication",
          ],
          actions: [],
          output_modes: ["human", "json"],
        },
        {
          name: "edit",
          usage: "office raw edit FILE PART --path PATH --action ACTION [action arguments] [--namespace PREFIX=URI]... [--all] [--out FILE] [--dry-run] [--overwrite] [--json]",
          result_schema: SCHEMA_RAW_RESULT,
          registry: None,
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
              "out", "path", false, "separate destination with the same .docx or .xlsx extension as the input",
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
            "out-extension-must-match-input-format", "transactional-publication",
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
  commands.map(hydrate_capability_command_variants)
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
  let fields : Map[String, Json] = {
    "name": Json::string(variant.name),
    "usage": Json::string(variant.usage),
    "result_schema": Json::string(variant.result_schema),
    "inputs": Json::array(variant.inputs.map(capability_field_json)),
    "outputs": Json::array(variant.outputs.map(capability_field_json)),
    "constraints": json_strings(variant.constraints),
    "actions": Json::array(variant.actions.map(capability_action_json)),
    "output_modes": json_strings(variant.output_modes),
  }
  match variant.registry {
    Some(registry) => fields["registry"] = registry
    None => ()
  }
  Json::object(fields)
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
    match variant.registry {
      Some(registry) => append_fingerprint_token(buffer, registry.stringify())
      None => append_fingerprint_token(buffer, "")
    }
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
  let buffer = StringBuilder()
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
  let raw = @flate_checksum.crc32(@utf8.encode(capability_fingerprint_source())).to_string(
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
fn capability_variant_document_format(
  variant : CapabilityVariant,
) -> DocumentFormat? {
  for constraint in variant.constraints {
    match constraint {
      "format=docx" => return Some(Docx)
      "format=xlsx" => return Some(Xlsx)
      _ => ()
    }
  }
  None
}

///|
fn capability_field_applies_to_format(
  command_name : String,
  field_name : String,
  output : Bool,
  format : DocumentFormat,
) -> Bool {
  let docx_only : Array[String] = if output {
    match command_name {
      "outline" =>
        [
          "scanned_elements", "counts", "stories", "headings", "comments", "revisions",
          "styles_in_use", "images", "sections", "diagnostics",
        ]
      "get" =>
        ["role", "source", "id", "children", "properties", "metadata", "text"]
      "text" => ["scanned_elements"]
      "query" => ["filters", "scanned_elements"]
      _ => []
    }
  } else {
    match command_name {
      "query" => ["kind", "text", "id", "property", "ignore-case"]
      _ => []
    }
  }
  let xlsx_only : Array[String] = if output {
    match command_name {
      "outline" =>
        [
          "path", "sheet_count", "active_sheet", "sheets", "defined_names", "limits",
        ]
      "get" =>
        [
          "sheet_count", "sheets", "defined_names", "sheet", "cell", "cells", "reference",
          "styles", "scanned_cells", "returned",
        ]
      "text" => ["scanned_cells"]
      "query" => ["selector", "styles", "scanned_cells"]
      _ => []
    }
  } else {
    match command_name {
      "query" => ["selector"]
      _ => []
    }
  }
  if docx_only.contains(field_name) {
    return format is Docx
  }
  if xlsx_only.contains(field_name) {
    return format is Xlsx
  }
  true
}

///|
fn exact_capability_field(
  field : CapabilityField,
  format : DocumentFormat,
  result_schema : String?,
) -> CapabilityField {
  let type_name = if field.name == "schema" {
    match result_schema {
      Some(schema) => "literal(\{schema})"
      None => field.type_name
    }
  } else if field.name == "format" {
    "literal(\{format.name()})"
  } else {
    field.type_name
  }
  {
    name: field.name,
    type_name,
    required: field.required,
    description: field.description,
  }
}

///|
fn exact_capability_fields(
  command_name : String,
  fields : Array[CapabilityField],
  output : Bool,
  format : DocumentFormat,
  result_schema : String?,
) -> Array[CapabilityField] {
  let exact : Array[CapabilityField] = []
  for field in fields {
    if capability_field_applies_to_format(
        command_name,
        field.name,
        output,
        format,
      ) {
      exact.push(exact_capability_field(field, format, result_schema))
    }
  }
  exact
}

///|
fn hydrate_capability_command_variants(
  command : CapabilityCommand,
) -> CapabilityCommand {
  let variants : Array[CapabilityVariant] = []
  for variant in command.variants {
    match capability_variant_document_format(variant) {
      Some(format) =>
        variants.push({
          name: variant.name,
          usage: variant.usage,
          result_schema: variant.result_schema,
          registry: variant.registry,
          inputs: if variant.inputs.is_empty() {
            exact_capability_fields(
              command.name,
              command.inputs,
              false,
              format,
              Some(variant.result_schema),
            )
          } else {
            variant.inputs
          },
          outputs: if variant.outputs.is_empty() {
            exact_capability_fields(
              command.name,
              command.outputs,
              true,
              format,
              Some(variant.result_schema),
            )
          } else {
            variant.outputs
          },
          constraints: variant.constraints,
          actions: variant.actions,
          output_modes: variant.output_modes,
        })
      None => variants.push(variant)
    }
  }
  {
    name: command.name,
    summary: command.summary,
    usage: command.usage,
    formats: command.formats,
    aliases: command.aliases,
    inputs: command.inputs,
    outputs: command.outputs,
    output_modes: command.output_modes,
    variants,
  }
}

///|
fn capability_command_for_format(
  command : CapabilityCommand,
  format : DocumentFormat,
) -> CapabilityCommand {
  let mut result_schema : String? = None
  for variant in command.variants {
    match capability_variant_document_format(variant) {
      Some(candidate) if candidate.name() == format.name() =>
        result_schema = Some(variant.result_schema)
      _ => ()
    }
  }
  let variants : Array[CapabilityVariant] = []
  for variant in command.variants {
    let should_include = match capability_variant_document_format(variant) {
      Some(candidate) => candidate.name() == format.name()
      None => true
    }
    if should_include {
      variants.push({
        name: variant.name,
        usage: variant.usage,
        result_schema: variant.result_schema,
        registry: variant.registry,
        inputs: exact_capability_fields(
          command.name,
          variant.inputs,
          false,
          format,
          Some(variant.result_schema),
        ),
        outputs: exact_capability_fields(
          command.name,
          variant.outputs,
          true,
          format,
          Some(variant.result_schema),
        ),
        constraints: variant.constraints,
        actions: variant.actions,
        output_modes: variant.output_modes,
      })
    }
  }
  {
    name: command.name,
    summary: command.summary,
    usage: command.usage,
    formats: [format.name()],
    aliases: command.aliases,
    inputs: exact_capability_fields(
      command.name,
      command.inputs,
      false,
      format,
      result_schema,
    ),
    outputs: exact_capability_fields(
      command.name,
      command.outputs,
      true,
      format,
      result_schema,
    ),
    output_modes: command.output_modes,
    variants,
  }
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
          let exact_command = match format {
            Some(selected) => capability_command_for_format(command, selected)
            None => command
          }
          records.push(capability_command_json(exact_command, fingerprint))
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
          records.push(
            capability_command_json(
              capability_command_for_format(command, selected),
              fingerprint,
            ),
          )
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
