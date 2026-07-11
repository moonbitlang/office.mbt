// The machine-readable capability descriptor for `xlsx.batch/1`: the ops
// this build accepts and their params. An agent generating a script can
// query it (`xlsx capabilities`) and adapt, instead of guessing whether a
// given CLI supports a given op. This is the forward-compatibility escape
// hatch — new ops appear here on newer builds; the JSON script contract
// itself stays backward-compatible.

///|
/// Schema id of the `capabilities` payload (see docs/agent-json-schemas.md).
pub const SCHEMA_CAPABILITIES : String = "xlsx.capabilities/1"

///|
/// A single param of a batch op, for the capability descriptor.
priv struct ParamSpec {
  name : String
  kind : String
  required : Bool
}

///|
/// One op in the capability descriptor: its name and its params. This is
/// the single source of truth for the op vocabulary — `op_names()` (used by
/// the unknown-op error) derives from it, and a wbtest asserts it stays in
/// sync with the parser.
priv struct OpSpec {
  op : String
  params : Array[ParamSpec]
}

///|
fn req(name : String, kind : String) -> ParamSpec {
  { name, kind, required: true }
}

///|
fn opt(name : String, kind : String) -> ParamSpec {
  { name, kind, required: false }
}

///|
/// The op catalog. Adding an op = add an entry here plus a `parse_op` arm
/// plus an `apply_op` arm; the drift wbtest keeps the three aligned.
let op_specs : Array[OpSpec] = [
  {
    op: "set",
    params: [req("sheet", "string"), req("cell", "cell"), req("value", "value")],
  },
  {
    op: "formula",
    params: [
      req("sheet", "string"),
      req("cell", "cell"),
      req("formula", "string"),
    ],
  },
  {
    op: "style",
    params: [
      req("sheet", "string"),
      req("range", "range"),
      opt("bold", "bool"),
      opt("italic", "bool"),
      opt("number_format", "string"),
      opt("fill", "string"),
      opt("font_color", "string"),
      opt("align", "string"),
    ],
  },
  { op: "merge", params: [req("sheet", "string"), req("range", "colon_range")] },
  {
    op: "width",
    params: [
      req("sheet", "string"),
      req("column", "column"),
      req("width", "number"),
    ],
  },
  { op: "freeze", params: [req("sheet", "string"), req("cell", "cell")] },
  {
    op: "filter",
    params: [req("sheet", "string"), req("range", "colon_range")],
  },
  { op: "add-sheet", params: [req("name", "string")] },
  {
    op: "chart",
    params: [
      req("sheet", "string"),
      req("anchor", "cell"),
      req("categories", "series_range"),
      req("values", "series_range"),
      opt("type", "string"),
      opt("name", "string"),
      opt("title", "string"),
    ],
  },
  {
    op: "table",
    params: [
      req("sheet", "string"),
      req("range", "colon_range"),
      opt("name", "string"),
      opt("style", "string"),
      opt("header_row", "bool"),
      opt("row_stripes", "bool"),
      opt("first_column", "bool"),
      opt("last_column", "bool"),
      opt("column_stripes", "bool"),
    ],
  },
]

///|
/// The accepted op names, derived from the catalog (single source of truth
/// for the unknown-op error text).
fn accepted_op_names() -> Array[String] {
  op_specs.map(spec => spec.op)
}

///|
/// Whether `name` is an op this build accepts. The parser gates on this
/// before dispatching, so an op is parseable **iff** it has a catalog
/// entry — a `parse_op` arm added without an `op_specs` entry is
/// unreachable, which structurally prevents the parser and the advertised
/// `capabilities` from drifting apart.
fn is_known_op(name : String) -> Bool {
  for spec in op_specs {
    if spec.op == name {
      return true
    }
  }
  false
}

///|
/// The advertised param names for `op` (empty for an unknown op — callers
/// gate on `is_known_op` first). The parser's `ParamReader` uses this to
/// refuse reading any param outside the catalog.
fn op_param_names(op : String) -> Array[String] {
  for spec in op_specs {
    if spec.op == op {
      return spec.params.map(p => p.name)
    }
  }
  []
}

///|
/// The `xlsx.capabilities/1` JSON payload: the batch schema this build
/// speaks, its limits, and every op + param it accepts.
pub fn capabilities() -> Json {
  let ops = []
  for spec in op_specs {
    let params = []
    for p in spec.params {
      params.push(
        Json::object({
          "name": Json::string(p.name),
          "type": Json::string(p.kind),
          "required": Json::boolean(p.required),
        }),
      )
    }
    ops.push(
      Json::object({
        "op": Json::string(spec.op),
        "params": Json::array(params),
      }),
    )
  }
  Json::object({
    "schema": Json::string(SCHEMA_CAPABILITIES),
    "batch_schema": Json::string(@inspect.SCHEMA_BATCH),
    "limits": Json::object({
      "max_ops": Json::number(MAX_BATCH_OPS.to_double()),
      "max_style_cells": Json::number(MAX_TOTAL_STYLE_CELLS.to_double()),
    }),
    "ops": Json::array(ops),
  })
}
