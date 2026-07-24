// White-box: the capability catalog is the single source of truth for the
// op vocabulary, so it must stay in lockstep with what `parse_op` actually
// accepts — bidirectionally and field-exactly.

///|
/// A minimal valid params object per op, using ONLY that op's required
/// params. Keyed by op name. Also the independent ground-truth op list: a
/// parser arm added without a `samples` entry here (and thus without a
/// catalog entry — see the parser→catalog check) fails this test.
fn required_samples() -> Map[String, String] {
  Map::from_array([
    ("set", "{\"sheet\":\"S\",\"cell\":\"A1\",\"value\":1}"),
    ("formula", "{\"sheet\":\"S\",\"cell\":\"A1\",\"formula\":\"=1\"}"),
    ("style", "{\"sheet\":\"S\",\"range\":\"A1\"}"),
    ("merge", "{\"sheet\":\"S\",\"range\":\"A1:B1\"}"),
    ("width", "{\"sheet\":\"S\",\"column\":\"A\",\"width\":10}"),
    ("freeze", "{\"sheet\":\"S\",\"cell\":\"A2\"}"),
    ("filter", "{\"sheet\":\"S\",\"range\":\"A1:B2\"}"),
    ("add-sheet", "{\"name\":\"S2\"}"),
    (
      "chart", "{\"sheet\":\"S\",\"anchor\":\"E2\",\"categories\":\"A1:A3\",\"values\":\"B1:B3\"}",
    ),
    ("table", "{\"sheet\":\"S\",\"range\":\"A1:B2\"}"),
    (
      "validate", "{\"sheet\":\"S\",\"range\":\"A1\",\"type\":\"list\",\"source\":\"Sheet2!A1:A2\"}",
    ),
    ("sheet", "{\"action\":\"delete\",\"name\":\"S\"}"),
    // `hide` needs no `height`, so this required sample stays applicable; the
    // catalog-built full sample (all params, action="S") only has to PARSE.
    ("row", "{\"sheet\":\"S\",\"action\":\"hide\",\"at\":2}"),
    ("col", "{\"sheet\":\"S\",\"action\":\"hide\",\"at\":\"B\"}"),
    ("cf", "{\"sheet\":\"S\",\"range\":\"A1\",\"type\":\"data_bar\"}"),
  ])
}

///|
fn one_op_script(
  name : String,
  params : String,
  schema? : String = @inspect.SCHEMA_BATCH,
) -> String {
  "{\"schema\":\"\{schema}\",\"ops\":[{\"op\":\"\{name}\",\"params\":\{params}}]}"
}

///|
fn assert_exact_keys(
  map : Map[String, Json],
  expected : Array[String],
  label : String,
) -> Unit raise {
  assert_eq(map.length(), expected.length(), msg="\{label} key count")
  for key in expected {
    assert_true(map.contains(key), msg="\{label} missing key '\{key}'")
  }
}

///|
/// Field-exact snapshot of the emitted catalog: `op: pname:ptype[!][=values]`
/// per op (`!` = required). Any param name, type, requiredness, allowed-value
/// grammar, or op change surfaces here — not just count changes.
test "capabilities payload is field-exact" {
  let obj = match capabilities() {
    Object(map) => map
    _ => fail("capabilities must be a JSON object")
  }
  assert_exact_keys(
    obj,
    ["schema", "preferred_schema", "accepted_schemas", "limits", "ops"],
    "root",
  )
  match (obj.get("schema"), obj.get("preferred_schema")) {
    (Some(String("xlsx.capabilities/2")), Some(String("xlsx.batch/2"))) => ()
    _ => fail("unexpected capabilities envelope")
  }
  assert_eq(
    obj.get("accepted_schemas"),
    Some(
      Json::array([
        Json::string(@inspect.SCHEMA_BATCH),
        Json::string(@inspect.SCHEMA_BATCH_V2),
      ]),
    ),
  )
  let lines = []
  let constraint_lines = []
  let ops = match obj.get("ops") {
    Some(Array(items)) => items
    _ => fail("ops")
  }
  for op in ops {
    let op_obj = match op {
      Object(map) => map
      _ => fail("op")
    }
    assert_exact_keys(
      op_obj,
      ["op", "introduced_in", "params", "constraints"],
      "op",
    )
    let name = match op_obj.get("op") {
      Some(String(s)) => s
      _ => fail("op name")
    }
    assert_eq(
      op_obj.get("introduced_in"),
      Some(Json::string(@inspect.SCHEMA_BATCH)),
      msg="introduction schema for \{name}",
    )
    let params = match op_obj.get("params") {
      Some(Array(ps)) => ps
      _ => fail("params")
    }
    let constraints = match op_obj.get("constraints") {
      Some(Array(rules)) => rules
      _ => fail("constraints")
    }
    let parts = []
    for p in params {
      let pm = match p {
        Object(map) => map
        _ => fail("param")
      }
      assert_exact_keys(
        pm,
        [
          "name", "type", "introduced_in", "required", "allowed_values", "accepts_empty_string",
          "default_when_omitted",
        ],
        "param",
      )
      let pn = match pm.get("name") {
        Some(String(s)) => s
        _ => fail("param name")
      }
      assert_eq(
        pm.get("introduced_in"),
        Some(Json::string(@inspect.SCHEMA_BATCH)),
        msg="introduction schema for \{name}.\{pn}",
      )
      let pt = match pm.get("type") {
        Some(String(s)) => s
        _ => fail("param type")
      }
      let req = match pm.get("required") {
        Some(True) => true
        Some(False) => false
        _ => fail("required must be an explicit boolean")
      }
      let choices = match pm.get("allowed_values") {
        Some(Array(values)) => {
          let names = []
          for value in values {
            match value {
              String(name) => names.push(name)
              _ => fail("allowed value")
            }
          }
          names
        }
        _ => fail("allowed_values")
      }
      let accepts_empty = match pm.get("accepts_empty_string") {
        Some(True) => true
        Some(False) => false
        _ => fail("accepts_empty_string must be an explicit boolean")
      }
      let expected_empty = pt == "value" ||
        (
          pt == "string" &&
          !(req && !choices.is_empty()) &&
          !(name == "chart" && pn == "type")
        )
      assert_eq(
        accepts_empty,
        expected_empty,
        msg="empty-string semantics for \{name}.\{pn}",
      )
      let omitted = pm.get("default_when_omitted").unwrap()
      let expected_omitted = if req {
        Json::null()
      } else {
        match pt {
          "string" =>
            if name == "chart" && pn == "type" {
              Json::string("col")
            } else {
              Json::string("")
            }
          "bool" =>
            Json::boolean(
              (name == "table" && pn is ("header_row" | "row_stripes")) ||
              (name == "validate" && pn == "allow_blank"),
            )
          "string_array" => Json::array([])
          "number" =>
            if pn == "count" {
              Json::number(1.0)
            } else {
              Json::null()
            }
          _ => Json::null()
        }
      }
      assert_eq(
        omitted,
        expected_omitted,
        msg="omitted default for \{name}.\{pn}",
      )
      let choice_text = if choices.is_empty() {
        ""
      } else {
        "=\{choices.join("|")}"
      }
      parts.push("\{pn}:\{pt}\{if req { "!" } else { "" }}\{choice_text}")
    }
    lines.push("\{name}: \{parts.join(" ")}")
    for rule in constraints {
      match rule {
        String(text) => constraint_lines.push("\{name}: \{text}")
        _ => fail("constraint")
      }
    }
  }
  inspect(
    lines.join("\n"),
    content=(
      #|set: sheet:string! cell:cell! value:value!
      #|formula: sheet:string! cell:cell! formula:string!
      #|style: sheet:string! range:range! bold:bool italic:bool number_format:string fill:string font_color:string align:string border:string=thin|medium|thick|dashed|dotted|double|hair border_top:string=thin|medium|thick|dashed|dotted|double|hair border_bottom:string=thin|medium|thick|dashed|dotted|double|hair border_left:string=thin|medium|thick|dashed|dotted|double|hair border_right:string=thin|medium|thick|dashed|dotted|double|hair border_color:string
      #|merge: sheet:string! range:colon_range!
      #|width: sheet:string! column:column! width:number!
      #|freeze: sheet:string! cell:cell!
      #|filter: sheet:string! range:colon_range!
      #|add-sheet: name:string!
      #|chart: sheet:string! anchor:cell! categories:series_range! values:series_range! type:string=col|column|bar|line|pie|area|scatter|doughnut|donut|radar name:string title:string
      #|table: sheet:string! range:table_range! name:string style:string header_row:bool row_stripes:bool first_column:bool last_column:bool column_stripes:bool
      #|validate: sheet:string! range:sqref! type:string!=list|whole|decimal|date|time|textLength|custom operator:string=between|notBetween|equal|notEqual|greaterThan|greaterThanOrEqual|lessThan|lessThanOrEqual formula1:string formula2:string values:string_array source:string allow_blank:bool input_title:string input_message:string error_title:string error_message:string error_style:string=stop|warning|information
      #|sheet: action:string!=rename|delete|hide|show|very-hide name:string! to:string
      #|row: sheet:string! action:string!=hide|show|height at:number! count:number height:number
      #|col: sheet:string! action:string!=hide|show at:column! count:number
      #|cf: sheet:string! range:sqref! type:string!=cell|formula|2_color_scale|3_color_scale|data_bar|icon_set criteria:string value:string min_value:string max_value:string formula:string fill:string font_color:string bold:bool italic:bool min_type:string=num|min|max|percent|percentile|formula mid_type:string=num|min|max|percent|percentile|formula max_type:string=num|min|max|percent|percentile|formula mid_value:string min_color:string mid_color:string max_color:string bar_color:string bar_solid:bool bar_direction:string=leftToRight|rightToLeft bar_border_color:string icon_style:string=3Arrows|3ArrowsGray|3Flags|3Signs|3Symbols|3Symbols2|3TrafficLights1|3TrafficLights2|4Arrows|4ArrowsGray|4Rating|4RedToBlack|4TrafficLights|5Arrows|5ArrowsGray|5Quarters|5Rating reverse_icons:bool stop_if_true:bool
    ),
  )
  inspect(
    constraint_lines.join("\n"),
    content=(
      #|style: border_color, when nonempty, is exactly 6 hex RGB digits with an optional leading '#'
      #|table: range must not be one row on grid row 1048576
      #|validate: type=list: require nonempty values or source; operator,formula1,formula2 must be empty or omitted; nonempty values take precedence when both values and source are present
      #|validate: type=list values: no item may contain a comma and the first item must not start with '='
      #|validate: type=list values: the comma-joined list is at most 255 UTF-16 code units
      #|validate: type=custom: require nonempty formula1; operator,formula2,source must be empty or omitted and values must be empty or omitted
      #|validate: type=whole|decimal|date|time|textLength: require operator,formula1; source must be empty or omitted and values must be empty or omitted
      #|validate: operator=between|notBetween: require nonempty formula2; every other comparison operator requires formula2 to be empty or omitted
      #|sheet: action=rename: require nonempty to
      #|sheet: action=delete|hide|show|very-hide: forbid nonempty to
      #|row: action=height: require height
      #|row: action=hide|show: forbid height
      #|cf: type=cell: allow criteria,value,min_value,max_value,fill,font_color,bold,italic,stop_if_true; require criteria and a highlight (fill, font_color, bold=true, or italic=true)
      #|cf: type=cell criteria are case-insensitively exactly one of >|>=|<|<=|=|==|!=|<>|between|not between|notbetween; simple comparisons require value and forbid min_value,max_value; between forms require min_value,max_value and forbid value
      #|cf: type=formula: allow formula,fill,font_color,bold,italic,stop_if_true; require formula and a highlight (fill, font_color, bold=true, or italic=true)
      #|cf: type=2_color_scale: allow min_type,min_value,min_color,max_type,max_value,max_color; require min_color,max_color
      #|cf: type=3_color_scale: allow min_type,min_value,min_color,mid_type,mid_value,mid_color,max_type,max_value,max_color; require min_color,mid_color,max_color
      #|cf: type=data_bar: allow bar_color,min_type,min_value,max_type,max_value,bar_solid,bar_direction,bar_border_color
      #|cf: type=icon_set: allow icon_style,reverse_icons; require icon_style
      #|cf: parameters not allowed for the selected type are permitted only when string-valued and empty or omitted; disallowed booleans are permitted only when omitted; every nonempty color is exactly 6 hex RGB with an optional leading '#'
    ),
  )
}

///|
test "every advertised constraint has production parser witnesses" {
  for schema in accepted_batch_schemas() {
    for op in accepted_op_names(schema) {
      for spec in op_constraint_specs(op) {
        assert_true(
          !spec.accepted_params.is_empty(),
          msg="constraint has no accepted witness: \{schema}: \{op}: \{spec.text}",
        )
        assert_true(
          !spec.rejected_params.is_empty(),
          msg="constraint has no rejected witness: \{schema}: \{op}: \{spec.text}",
        )
        for params in spec.accepted_params {
          let parsed = parse_script(
            @json.parse(one_op_script(op, params, schema~)),
          )
          assert_eq(
            parsed.length(),
            1,
            msg="accepted witness: \{schema}: \{op}: \{spec.text}",
          )
        }
        for params in spec.rejected_params {
          let document = @json.parse(one_op_script(op, params, schema~))
          try ignore(parse_script(document)) catch {
            BatchError(_) => ()
          } noraise {
            _ =>
              fail(
                "rejected witness parsed: \{schema}: \{op}: \{spec.text}: \{params}",
              )
          }
        }
      }
    }
  }
}

///|
test "list values precedence is proven by application" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("S"))
  let parsed = parse_script(
    @json.parse(
      one_op_script(
        "validate", "{\"sheet\":\"S\",\"range\":\"A1\",\"type\":\"list\",\"values\":[\"a\",\"b\"],\"source\":\"S!Z1:Z2\"}",
      ),
    ),
  )
  apply_op(workbook, parsed[0])
  let validations = workbook.get_data_validations("S")
  assert_eq(validations.length(), 1)
  inspect(validations[0].formula1, content="\"a,b\"")
}

///|
test "empty values and omitted defaults match parse and apply" {
  let accepted_empty_choices : Array[(String, String)] = [
    ("set", "{\"sheet\":\"S\",\"cell\":\"A1\",\"value\":\"\"}"),
    ("style", "{\"sheet\":\"S\",\"range\":\"A1\",\"border\":\"\"}"),
    (
      "validate", "{\"sheet\":\"S\",\"range\":\"A1\",\"type\":\"list\",\"source\":\"S!A1\",\"error_style\":\"\"}",
    ),
    (
      "cf", "{\"sheet\":\"S\",\"range\":\"A1\",\"type\":\"3_color_scale\",\"min_type\":\"\",\"mid_type\":\"\",\"max_type\":\"\",\"min_color\":\"FF0000\",\"mid_color\":\"FFFF00\",\"max_color\":\"00FF00\"}",
    ),
    (
      "cf", "{\"sheet\":\"S\",\"range\":\"A1\",\"type\":\"data_bar\",\"bar_direction\":\"\"}",
    ),
  ]
  for entry in accepted_empty_choices {
    let (op_name, params) = entry
    let parsed = parse_script(@json.parse(one_op_script(op_name, params)))
    let workbook = @xlsx.Workbook::new()
    ignore(workbook.add_sheet("S"))
    apply_op(workbook, parsed[0])
  }
  try
    ignore(
      parse_script(
        @json.parse(
          one_op_script(
            "chart", "{\"sheet\":\"S\",\"anchor\":\"E2\",\"categories\":\"A1:A2\",\"values\":\"B1:B2\",\"type\":\"\"}",
          ),
        ),
      ),
    )
  catch {
    BatchError(message) => assert_true(message.contains("unknown chart type"))
    _ => fail("unexpected error for an explicit empty chart type")
  } noraise {
    _ =>
      fail(
        "an explicit empty chart type must not use the omitted 'col' default",
      )
  }

  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("S"))
  for
    entry in [
      ("table", "{\"sheet\":\"S\",\"range\":\"A1:B2\"}"),
      (
        "validate", "{\"sheet\":\"S\",\"range\":\"C1\",\"type\":\"list\",\"source\":\"S!A1\"}",
      ),
      (
        "chart", "{\"sheet\":\"S\",\"anchor\":\"E2\",\"categories\":\"A1:A2\",\"values\":\"B1:B2\"}",
      ),
      ("row", "{\"sheet\":\"S\",\"action\":\"hide\",\"at\":2}"),
      ("col", "{\"sheet\":\"S\",\"action\":\"hide\",\"at\":\"B\"}"),
    ] {
    let (op_name, params) = entry
    let parsed = parse_script(@json.parse(one_op_script(op_name, params)))
    apply_op(workbook, parsed[0])
  }
  let tables = workbook.sheets()[0].tables()
  assert_eq(tables.length(), 1)
  assert_true(tables[0].show_header_row)
  assert_true(tables[0].show_row_stripes)
  assert_false(tables[0].show_first_column)
  let validations = workbook.get_data_validations("S")
  assert_eq(validations.length(), 1)
  assert_true(validations[0].allow_blank)
  let charts = workbook.sheets()[0].charts()
  assert_eq(charts.length(), 1)
  assert_true(charts[0].xml.contains("<c:barChart>"))
  assert_true(charts[0].xml.contains("barDir val=\"col\""))
  assert_false(workbook.row_visible("S", 2))
  assert_true(workbook.row_visible("S", 3))
  assert_false(workbook.col_visible("S", 2))
  assert_true(workbook.col_visible("S", 3))
}

///|
test "capability calls do not share mutable default JSON" {
  let baseline = capabilities().stringify()
  guard capabilities() is Object(root) && root.get("ops") is Some(Array(ops)) else {
    fail("capability ops must be an array")
  }
  let mut mutated = false
  for op in ops {
    guard op is Object(op_fields) &&
      op_fields.get("op") is Some(String("validate")) &&
      op_fields.get("params") is Some(Array(params)) else {
      continue
    }
    for param in params {
      guard param is Object(fields) &&
        fields.get("name") is Some(String("values")) &&
        fields.get("default_when_omitted") is Some(Array(values)) else {
        continue
      }
      values.push(Json::string("poison"))
      mutated = true
    }
  }
  assert_true(mutated)
  assert_eq(capabilities().stringify(), baseline)
}

///|
test "capabilities expose every command-wide batch resource ceiling" {
  guard capabilities() is Object(root) &&
    root.get("limits") is Some(Object(limits)) else {
    fail("capabilities limits must be an object")
  }
  assert_eq(limits.length(), 8)
  assert_eq(
    limits.get("max_script_bytes"),
    Some(Json::number(MAX_BATCH_SCRIPT_BYTES.to_double())),
  )
  assert_eq(
    limits.get("max_ops"),
    Some(Json::number(MAX_BATCH_OPS.to_double())),
  )
  assert_eq(
    limits.get("max_touched_cells"),
    Some(Json::number(MAX_TOTAL_TOUCHED_CELLS.to_double())),
  )
  assert_eq(
    limits.get("max_style_cells"),
    Some(Json::number(MAX_TOTAL_STYLE_CELLS.to_double())),
  )
  assert_eq(
    limits.get("max_new_styles"),
    Some(Json::number(MAX_TOTAL_NEW_STYLES.to_double())),
  )
  assert_eq(
    limits.get("max_row_column_band"),
    Some(Json::number(MAX_ROW_COLUMN_BAND.to_double())),
  )
  assert_eq(
    limits.get("max_row_column_lines"),
    Some(Json::number(MAX_TOTAL_ROW_COLUMN_LINES.to_double())),
  )
  assert_eq(
    limits.get("max_inline_validation_list_utf16_units"),
    Some(Json::number(max_inline_validation_list_utf16_units.to_double())),
  )
}

///|
/// Bidirectional catalog ↔ parser agreement, behaviorally:
/// - **parser → catalog**: `required_samples` is the independent list of
///   ops we support; every one must be advertised by the catalog. A parser
///   arm added without updating the catalog leaves it here but missing from
///   `accepted_op_names`, failing the membership check.
/// - **catalog → parser**: every advertised op parses with its required
///   params, and its parsed `name()` round-trips.
/// - **param set exactness**: a param NOT in the catalog is rejected; together
///   with the `ParamReader` `declared` guard (which aborts if a parser arm reads
///   an undeclared param), the catalog cannot omit a parameter consumed by the
///   parser. Mode-specific tests cover conditionally accepted optional params.
test "catalog and parser agree in both directions under every schema" {
  let samples = required_samples()
  for schema in accepted_batch_schemas() {
    let catalog = accepted_op_names(schema)
    let catalog_set : Map[String, Unit] = Map([])
    for name in catalog {
      assert_false(catalog_set.contains(name)) // names unique
      catalog_set[name] = ()
    }
    // parser → catalog: our ground-truth op list is fully advertised.
    for name, _ in samples {
      assert_true(catalog_set.contains(name))
    }
    // catalog → parser: advertised ops parse; and a bogus param is rejected.
    for name in catalog {
      let params = match samples.get(name) {
        Some(p) => p
        None => fail("op '\{name}' advertised but has no ground-truth sample")
      }
      let ops = parse_script(@json.parse(one_op_script(name, params, schema~)))
      assert_eq(ops.length(), 1)
      assert_eq(ops[0].name(), name)
      // Same op with one param outside the catalog must fail unknown-param.
      // Parse the (valid) JSON outside the `try` so the catch handles only
      // parse_script's BatchError, not @json.parse's ParseError.
      let bogus = params[:params.length() - 1].to_owned() +
        ",\"__not_a_real_param__\":1}"
      let doc = @json.parse(one_op_script(name, bogus, schema~))
      try ignore(parse_script(doc)) catch {
        BatchError(msg) => assert_true(msg.contains("unknown param"))
      } noraise {
        _ =>
          fail(
            "op '\{name}' accepted a param outside its \{schema} catalog spec",
          )
      }
    }
  }
}

///|
test "schema gate excludes synthetic v2-only operations and parameters from v1" {
  let synthetic : Array[OpSpec] = [
    {
      op: "legacy",
      introduced_in: @inspect.SCHEMA_BATCH,
      params: [
        req("legacy", "string"),
        opt("future", "string", introduced_in=@inspect.SCHEMA_BATCH_V2),
      ],
    },
    {
      op: "future",
      introduced_in: @inspect.SCHEMA_BATCH_V2,
      params: [req("value", "string", introduced_in=@inspect.SCHEMA_BATCH_V2)],
    },
  ]
  assert_eq(accepted_op_names_in(synthetic, @inspect.SCHEMA_BATCH), ["legacy"])
  assert_false(is_known_op_in(synthetic, @inspect.SCHEMA_BATCH, "future"))
  assert_eq(op_param_names_in(synthetic, @inspect.SCHEMA_BATCH, "legacy"), [
    "legacy",
  ])
  assert_eq(accepted_op_names_in(synthetic, @inspect.SCHEMA_BATCH_V2), [
    "legacy", "future",
  ])
  assert_eq(op_param_names_in(synthetic, @inspect.SCHEMA_BATCH_V2, "legacy"), [
    "legacy", "future",
  ])
}
