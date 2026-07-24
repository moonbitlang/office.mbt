// The machine-readable capability descriptor for `xlsx.batch/1`: the ops and
// parameters accepted by this exact build. Agents query it (`xlsx
// capabilities`) instead of assuming a vocabulary or limit set. Before the
// schema is declared stable, newer builds may intentionally revise the
// contract without compatibility aliases.

///|
/// Schema id of the `capabilities` payload (see docs/agent-json-schemas.md).
pub const SCHEMA_CAPABILITIES : String = "xlsx.capabilities/1"

///|
/// A single param of a batch op, for the capability descriptor.
priv struct ParamSpec {
  name : String
  kind : String
  required : Bool
  allowed_values : Array[String]
  accepts_empty_string : Bool
  default_when_omitted : Json
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
/// One advertised conditional rule plus executable parser examples. Capability
/// serialization and the behavioral lockstep wbtest consume the same value, so
/// changing a rule cannot leave an unexercised prose-only promise behind.
#warnings("-unused_field")
priv struct ConstraintSpec {
  text : String
  accepted_params : Array[String]
  rejected_params : Array[String]
}

///|
fn constraint(
  text : String,
  accepted_params : Array[String],
  rejected_params : Array[String],
) -> ConstraintSpec {
  { text, accepted_params, rejected_params }
}

///|
fn req(name : String, kind : String) -> ParamSpec {
  {
    name,
    kind,
    required: true,
    allowed_values: [],
    accepts_empty_string: kind == "string" || kind == "value",
    default_when_omitted: Json::null(),
  }
}

///|
fn opt(name : String, kind : String) -> ParamSpec {
  let default_when_omitted = match kind {
    "string" => Json::string("")
    "bool" => Json::boolean(false)
    "string_array" => Json::array([])
    _ => Json::null()
  }
  {
    name,
    kind,
    required: false,
    allowed_values: [],
    accepts_empty_string: kind == "string",
    default_when_omitted,
  }
}

///|
fn req_choice(name : String, allowed_values : Array[String]) -> ParamSpec {
  {
    name,
    kind: "string",
    required: true,
    allowed_values,
    accepts_empty_string: false,
    default_when_omitted: Json::null(),
  }
}

///|
fn opt_choice(name : String, allowed_values : Array[String]) -> ParamSpec {
  {
    name,
    kind: "string",
    required: false,
    allowed_values,
    accepts_empty_string: true,
    default_when_omitted: Json::string(""),
  }
}

///|
fn opt_choice_default(
  name : String,
  allowed_values : Array[String],
  default : String,
) -> ParamSpec {
  {
    name,
    kind: "string",
    required: false,
    allowed_values,
    accepts_empty_string: false,
    default_when_omitted: Json::string(default),
  }
}

///|
fn opt_bool_default(name : String, default : Bool) -> ParamSpec {
  {
    name,
    kind: "bool",
    required: false,
    allowed_values: [],
    accepts_empty_string: false,
    default_when_omitted: Json::boolean(default),
  }
}

///|
fn opt_number_default(name : String, default : Int) -> ParamSpec {
  {
    name,
    kind: "number",
    required: false,
    allowed_values: [],
    accepts_empty_string: false,
    default_when_omitted: Json::number(default.to_double()),
  }
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
      opt_choice("border", border_style_values),
      opt_choice("border_top", border_style_values),
      opt_choice("border_bottom", border_style_values),
      opt_choice("border_left", border_style_values),
      opt_choice("border_right", border_style_values),
      opt("border_color", "string"),
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
      opt_choice_default("type", chart_type_values, "col"),
      opt("name", "string"),
      opt("title", "string"),
    ],
  },
  {
    op: "table",
    params: [
      req("sheet", "string"),
      req("range", "table_range"),
      opt("name", "string"),
      opt("style", "string"),
      opt_bool_default("header_row", true),
      opt_bool_default("row_stripes", true),
      opt("first_column", "bool"),
      opt("last_column", "bool"),
      opt("column_stripes", "bool"),
    ],
  },
  {
    op: "validate",
    params: [
      req("sheet", "string"),
      req("range", "sqref"),
      req_choice("type", validation_type_values),
      opt_choice("operator", validation_operator_values),
      opt("formula1", "string"),
      opt("formula2", "string"),
      opt("values", "string_array"),
      opt("source", "string"),
      opt_bool_default("allow_blank", true),
      opt("input_title", "string"),
      opt("input_message", "string"),
      opt("error_title", "string"),
      opt("error_message", "string"),
      opt_choice("error_style", validation_error_style_values),
    ],
  },
  {
    op: "sheet",
    params: [
      req_choice("action", sheet_action_values),
      req("name", "string"),
      opt("to", "string"),
    ],
  },
  {
    op: "row",
    params: [
      req("sheet", "string"),
      req_choice("action", row_action_values),
      req("at", "number"),
      opt_number_default("count", 1),
      opt("height", "number"),
    ],
  },
  {
    op: "col",
    params: [
      req("sheet", "string"),
      req_choice("action", column_action_values),
      req("at", "column"),
      opt_number_default("count", 1),
    ],
  },
  {
    op: "cf",
    params: [
      req("sheet", "string"),
      req("range", "sqref"),
      req_choice("type", cf_supported_types),
      opt("criteria", "string"),
      opt("value", "string"),
      opt("min_value", "string"),
      opt("max_value", "string"),
      opt("formula", "string"),
      opt("fill", "string"),
      opt("font_color", "string"),
      opt("bold", "bool"),
      opt("italic", "bool"),
      opt_choice("min_type", cf_stop_type_values),
      opt_choice("mid_type", cf_stop_type_values),
      opt_choice("max_type", cf_stop_type_values),
      opt("mid_value", "string"),
      opt("min_color", "string"),
      opt("mid_color", "string"),
      opt("max_color", "string"),
      opt("bar_color", "string"),
      opt("bar_solid", "bool"),
      opt_choice("bar_direction", cf_bar_direction_values),
      opt("bar_border_color", "string"),
      opt_choice("icon_style", cf_classic_icon_styles),
      opt("reverse_icons", "bool"),
      opt("stop_if_true", "bool"),
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
/// Discriminator-dependent grammar enforced by `validate_parsed_op_contract`.
/// Each rule carries accepted and rejected parser examples, exercised by the
/// wbtest rather than being a snapshot-only restatement of production behavior.
fn op_constraint_specs(op : String) -> Array[ConstraintSpec] {
  match op {
    "style" =>
      [
        constraint(
          "border_color, when nonempty, is exactly 6 hex RGB digits with an optional leading '#'",
          ["{\"sheet\":\"S\",\"range\":\"A1\",\"border_color\":\"#00ffAA\"}"],
          ["{\"sheet\":\"S\",\"range\":\"A1\",\"border_color\":\"red\"}"],
        ),
      ]
    "table" =>
      [
        constraint(
          "range must not be one row on grid row 1048576",
          ["{\"sheet\":\"S\",\"range\":\"A1048575:B1048575\"}"],
          ["{\"sheet\":\"S\",\"range\":\"A1048576:B1048576\"}"],
        ),
      ]
    "validate" =>
      [
        constraint(
          "type=list: require nonempty values or source; operator,formula1,formula2 must be empty or omitted; nonempty values take precedence when both values and source are present",
          [
            "{\"sheet\":\"S\",\"range\":\"A1\",\"type\":\"list\",\"values\":[\"a\"],\"source\":\"S!A1\"}",
          ],
          [
            "{\"sheet\":\"S\",\"range\":\"A1\",\"type\":\"list\"}", "{\"sheet\":\"S\",\"range\":\"A1\",\"type\":\"list\",\"source\":\"S!A1\",\"operator\":\"equal\"}",
            "{\"sheet\":\"S\",\"range\":\"A1\",\"type\":\"list\",\"source\":\"S!A1\",\"formula1\":\"1\"}",
            "{\"sheet\":\"S\",\"range\":\"A1\",\"type\":\"list\",\"source\":\"S!A1\",\"formula2\":\"2\"}",
          ],
        ),
        constraint(
          "type=list values: no item may contain a comma and the first item must not start with '='",
          [
            "{\"sheet\":\"S\",\"range\":\"A1\",\"type\":\"list\",\"values\":[\"a\",\"b\"]}",
          ],
          [
            "{\"sheet\":\"S\",\"range\":\"A1\",\"type\":\"list\",\"values\":[\"a,b\"]}",
            "{\"sheet\":\"S\",\"range\":\"A1\",\"type\":\"list\",\"values\":[\"=A1\"]}",
          ],
        ),
        constraint(
          "type=list values: the comma-joined list is at most 255 UTF-16 code units",
          [
            "{\"sheet\":\"S\",\"range\":\"A1\",\"type\":\"list\",\"values\":[\"" +
            "a".repeat(255) +
            "\"]}",
            "{\"sheet\":\"S\",\"range\":\"A1\",\"type\":\"list\",\"values\":[\"" +
            "😀".repeat(127) +
            "a\"]}",
            "{\"sheet\":\"S\",\"range\":\"A1\",\"type\":\"list\",\"values\":[\"" +
            "a".repeat(253) +
            "\",\"b\"]}",
          ],
          [
            "{\"sheet\":\"S\",\"range\":\"A1\",\"type\":\"list\",\"values\":[\"" +
            "a".repeat(256) +
            "\"]}",
            "{\"sheet\":\"S\",\"range\":\"A1\",\"type\":\"list\",\"values\":[\"" +
            "😀".repeat(128) +
            "\"]}",
            "{\"sheet\":\"S\",\"range\":\"A1\",\"type\":\"list\",\"values\":[\"" +
            "a".repeat(254) +
            "\",\"b\"]}",
          ],
        ),
        constraint(
          "type=custom: require nonempty formula1; operator,formula2,source must be empty or omitted and values must be empty or omitted",
          [
            "{\"sheet\":\"S\",\"range\":\"A1\",\"type\":\"custom\",\"formula1\":\"A1>0\"}",
          ],
          [
            "{\"sheet\":\"S\",\"range\":\"A1\",\"type\":\"custom\"}", "{\"sheet\":\"S\",\"range\":\"A1\",\"type\":\"custom\",\"formula1\":\"A1>0\",\"operator\":\"equal\"}",
            "{\"sheet\":\"S\",\"range\":\"A1\",\"type\":\"custom\",\"formula1\":\"A1>0\",\"formula2\":\"2\"}",
            "{\"sheet\":\"S\",\"range\":\"A1\",\"type\":\"custom\",\"formula1\":\"A1>0\",\"source\":\"S!A1\"}",
            "{\"sheet\":\"S\",\"range\":\"A1\",\"type\":\"custom\",\"formula1\":\"A1>0\",\"values\":[\"a\"]}",
          ],
        ),
        constraint(
          "type=whole|decimal|date|time|textLength: require operator,formula1; source must be empty or omitted and values must be empty or omitted",
          [
            "{\"sheet\":\"S\",\"range\":\"A1\",\"type\":\"whole\",\"operator\":\"greaterThan\",\"formula1\":\"0\"}",
          ],
          [
            "{\"sheet\":\"S\",\"range\":\"A1\",\"type\":\"whole\",\"formula1\":\"0\"}",
            "{\"sheet\":\"S\",\"range\":\"A1\",\"type\":\"whole\",\"operator\":\"greaterThan\"}",
            "{\"sheet\":\"S\",\"range\":\"A1\",\"type\":\"whole\",\"operator\":\"greaterThan\",\"formula1\":\"0\",\"source\":\"S!A1\"}",
            "{\"sheet\":\"S\",\"range\":\"A1\",\"type\":\"whole\",\"operator\":\"greaterThan\",\"formula1\":\"0\",\"values\":[\"1\"]}",
          ],
        ),
        constraint(
          "operator=between|notBetween: require nonempty formula2; every other comparison operator requires formula2 to be empty or omitted",
          [
            "{\"sheet\":\"S\",\"range\":\"A1\",\"type\":\"whole\",\"operator\":\"between\",\"formula1\":\"0\",\"formula2\":\"10\"}",
            "{\"sheet\":\"S\",\"range\":\"A1\",\"type\":\"whole\",\"operator\":\"greaterThan\",\"formula1\":\"0\"}",
          ],
          [
            "{\"sheet\":\"S\",\"range\":\"A1\",\"type\":\"whole\",\"operator\":\"between\",\"formula1\":\"0\"}",
            "{\"sheet\":\"S\",\"range\":\"A1\",\"type\":\"whole\",\"operator\":\"greaterThan\",\"formula1\":\"0\",\"formula2\":\"10\"}",
          ],
        ),
      ]
    "sheet" =>
      [
        constraint(
          "action=rename: require nonempty to",
          ["{\"action\":\"rename\",\"name\":\"S\",\"to\":\"S2\"}"],
          ["{\"action\":\"rename\",\"name\":\"S\"}"],
        ),
        constraint(
          "action=delete|hide|show|very-hide: forbid nonempty to",
          ["{\"action\":\"delete\",\"name\":\"S\"}"],
          ["{\"action\":\"delete\",\"name\":\"S\",\"to\":\"S2\"}"],
        ),
      ]
    "row" =>
      [
        constraint(
          "action=height: require height",
          ["{\"sheet\":\"S\",\"action\":\"height\",\"at\":1,\"height\":20}"],
          ["{\"sheet\":\"S\",\"action\":\"height\",\"at\":1}"],
        ),
        constraint(
          "action=hide|show: forbid height",
          ["{\"sheet\":\"S\",\"action\":\"hide\",\"at\":1}"],
          ["{\"sheet\":\"S\",\"action\":\"show\",\"at\":1,\"height\":20}"],
        ),
      ]
    "cf" =>
      [
        constraint(
          "type=cell: allow criteria,value,min_value,max_value,fill,font_color,bold,italic,stop_if_true; require criteria and a highlight (fill, font_color, bold=true, or italic=true)",
          [
            "{\"sheet\":\"S\",\"range\":\"A1\",\"type\":\"cell\",\"criteria\":\">\",\"value\":\"0\",\"fill\":\"FF0000\"}",
          ],
          [
            "{\"sheet\":\"S\",\"range\":\"A1\",\"type\":\"cell\",\"value\":\"0\",\"fill\":\"FF0000\"}",
            "{\"sheet\":\"S\",\"range\":\"A1\",\"type\":\"cell\",\"criteria\":\">\",\"value\":\"0\",\"bold\":false}",
          ],
        ),
        constraint(
          "type=cell criteria are case-insensitively exactly one of >|>=|<|<=|=|==|!=|<>|between|not between|notbetween; simple comparisons require value and forbid min_value,max_value; between forms require min_value,max_value and forbid value",
          [
            "{\"sheet\":\"S\",\"range\":\"A1\",\"type\":\"cell\",\"criteria\":\"BETWEEN\",\"min_value\":\"0\",\"max_value\":\"10\",\"fill\":\"FF0000\"}",
          ],
          [
            "{\"sheet\":\"S\",\"range\":\"A1\",\"type\":\"cell\",\"criteria\":\"contains\",\"value\":\"x\",\"fill\":\"FF0000\"}",
            "{\"sheet\":\"S\",\"range\":\"A1\",\"type\":\"cell\",\"criteria\":\"between\",\"min_value\":\"0\",\"fill\":\"FF0000\"}",
            "{\"sheet\":\"S\",\"range\":\"A1\",\"type\":\"cell\",\"criteria\":\">\",\"fill\":\"FF0000\"}",
            "{\"sheet\":\"S\",\"range\":\"A1\",\"type\":\"cell\",\"criteria\":\">\",\"value\":\"0\",\"min_value\":\"0\",\"fill\":\"FF0000\"}",
          ],
        ),
        constraint(
          "type=formula: allow formula,fill,font_color,bold,italic,stop_if_true; require formula and a highlight (fill, font_color, bold=true, or italic=true)",
          [
            "{\"sheet\":\"S\",\"range\":\"A1\",\"type\":\"formula\",\"formula\":\"A1>0\",\"fill\":\"FF0000\"}",
          ],
          [
            "{\"sheet\":\"S\",\"range\":\"A1\",\"type\":\"formula\",\"fill\":\"FF0000\"}",
            "{\"sheet\":\"S\",\"range\":\"A1\",\"type\":\"formula\",\"formula\":\"A1>0\"}",
          ],
        ),
        constraint(
          "type=2_color_scale: allow min_type,min_value,min_color,max_type,max_value,max_color; require min_color,max_color",
          [
            "{\"sheet\":\"S\",\"range\":\"A1\",\"type\":\"2_color_scale\",\"min_color\":\"FF0000\",\"max_color\":\"00FF00\"}",
          ],
          [
            "{\"sheet\":\"S\",\"range\":\"A1\",\"type\":\"2_color_scale\",\"min_color\":\"FF0000\"}",
          ],
        ),
        constraint(
          "type=3_color_scale: allow min_type,min_value,min_color,mid_type,mid_value,mid_color,max_type,max_value,max_color; require min_color,mid_color,max_color",
          [
            "{\"sheet\":\"S\",\"range\":\"A1\",\"type\":\"3_color_scale\",\"min_color\":\"FF0000\",\"mid_color\":\"FFFF00\",\"max_color\":\"00FF00\"}",
          ],
          [
            "{\"sheet\":\"S\",\"range\":\"A1\",\"type\":\"3_color_scale\",\"min_color\":\"FF0000\",\"max_color\":\"00FF00\"}",
          ],
        ),
        constraint(
          "type=data_bar: allow bar_color,min_type,min_value,max_type,max_value,bar_solid,bar_direction,bar_border_color",
          [
            "{\"sheet\":\"S\",\"range\":\"A1\",\"type\":\"data_bar\",\"bar_color\":\"00FF00\",\"bar_solid\":false}",
          ],
          [
            "{\"sheet\":\"S\",\"range\":\"A1\",\"type\":\"data_bar\",\"formula\":\"A1>0\"}",
          ],
        ),
        constraint(
          "type=icon_set: allow icon_style,reverse_icons; require icon_style",
          [
            "{\"sheet\":\"S\",\"range\":\"A1\",\"type\":\"icon_set\",\"icon_style\":\"3Arrows\",\"reverse_icons\":false}",
          ],
          ["{\"sheet\":\"S\",\"range\":\"A1\",\"type\":\"icon_set\"}"],
        ),
        constraint(
          "parameters not allowed for the selected type are permitted only when string-valued and empty or omitted; disallowed booleans are permitted only when omitted; every nonempty color is exactly 6 hex RGB with an optional leading '#'",
          [
            "{\"sheet\":\"S\",\"range\":\"A1\",\"type\":\"data_bar\",\"formula\":\"\",\"bar_color\":\"#00ff00\"}",
          ],
          [
            "{\"sheet\":\"S\",\"range\":\"A1\",\"type\":\"data_bar\",\"stop_if_true\":false}",
            "{\"sheet\":\"S\",\"range\":\"A1\",\"type\":\"data_bar\",\"bar_color\":\"green\"}",
          ],
        ),
      ]
    _ => []
  }
}

///|
fn op_constraints(op : String) -> Array[String] {
  op_constraint_specs(op).map(spec => spec.text)
}

///|
/// Capability declarations are module globals, while Json arrays and objects
/// are mutable. Never return their storage directly to a caller.
fn copy_capability_json(value : Json) -> Json {
  match value {
    Null => Json::null()
    True => Json::boolean(true)
    False => Json::boolean(false)
    Number(number, ..) => Json::number(number)
    String(text) => Json::string(text)
    Array(values) => Json::array(values.map(copy_capability_json))
    Object(fields) => {
      let copied : Map[String, Json] = Map([])
      for key, field in fields {
        copied[key] = copy_capability_json(field)
      }
      Json::object(copied)
    }
  }
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
          "allowed_values": Json::array(
            p.allowed_values.map(value => Json::string(value)),
          ),
          "accepts_empty_string": Json::boolean(p.accepts_empty_string),
          "default_when_omitted": copy_capability_json(p.default_when_omitted),
        }),
      )
    }
    ops.push(
      Json::object({
        "op": Json::string(spec.op),
        "params": Json::array(params),
        "constraints": Json::array(
          op_constraints(spec.op).map(rule => Json::string(rule)),
        ),
      }),
    )
  }
  Json::object({
    "schema": Json::string(SCHEMA_CAPABILITIES),
    "batch_schema": Json::string(@inspect.SCHEMA_BATCH),
    "limits": Json::object({
      "max_script_bytes": Json::number(MAX_BATCH_SCRIPT_BYTES.to_double()),
      "max_ops": Json::number(MAX_BATCH_OPS.to_double()),
      "max_touched_cells": Json::number(MAX_TOTAL_TOUCHED_CELLS.to_double()),
      "max_style_cells": Json::number(MAX_TOTAL_STYLE_CELLS.to_double()),
      "max_new_styles": Json::number(MAX_TOTAL_NEW_STYLES.to_double()),
      "max_row_column_band": Json::number(MAX_ROW_COLUMN_BAND.to_double()),
      "max_row_column_lines": Json::number(
        MAX_TOTAL_ROW_COLUMN_LINES.to_double(),
      ),
      "max_inline_validation_list_utf16_units": Json::number(
        max_inline_validation_list_utf16_units.to_double(),
      ),
    }),
    "ops": Json::array(ops),
  })
}
