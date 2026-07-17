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
fn one_op_script(name : String, params : String) -> String {
  "{\"schema\":\"xlsx.batch/1\",\"ops\":[{\"op\":\"\{name}\",\"params\":\{params}}]}"
}

///|

///|
/// Field-exact snapshot of the emitted catalog: `op: pname:ptype[!][=values]`
/// per op (`!` = required). Any param name, type, requiredness, allowed-value
/// grammar, or op change surfaces here — not just count changes.
test "capabilities payload is field-exact" {
  let obj = match capabilities() {
    Object(map) => map
    _ => fail("capabilities must be a JSON object")
  }
  match (obj.get("schema"), obj.get("batch_schema")) {
    (Some(String("xlsx.capabilities/1")), Some(String("xlsx.batch/1"))) => ()
    _ => fail("unexpected capabilities envelope")
  }
  let lines = []
  let ops = match obj.get("ops") {
    Some(Array(items)) => items
    _ => fail("ops")
  }
  for op in ops {
    let op_obj = match op {
      Object(map) => map
      _ => fail("op")
    }
    let name = match op_obj.get("op") {
      Some(String(s)) => s
      _ => fail("op name")
    }
    let params = match op_obj.get("params") {
      Some(Array(ps)) => ps
      _ => fail("params")
    }
    let parts = []
    for p in params {
      let pm = match p {
        Object(map) => map
        _ => fail("param")
      }
      let pn = match pm.get("name") {
        Some(String(s)) => s
        _ => fail("param name")
      }
      let pt = match pm.get("type") {
        Some(String(s)) => s
        _ => fail("param type")
      }
      let req = pm.get("required") is Some(True)
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
      let choice_text = if choices.is_empty() {
        ""
      } else {
        "=\{choices.join("|")}"
      }
      parts.push("\{pn}:\{pt}\{if req { "!" } else { "" }}\{choice_text}")
    }
    lines.push("\{name}: \{parts.join(" ")}")
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
}

///|
test "capabilities expose every command-wide batch resource ceiling" {
  guard capabilities() is Object(root) &&
    root.get("limits") is Some(Object(limits)) else {
    fail("capabilities limits must be an object")
  }
  assert_eq(limits.length(), 7)
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
test "catalog and parser agree in both directions" {
  let samples = required_samples()
  let catalog = accepted_op_names()
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
    let ops = parse_script(@json.parse(one_op_script(name, params)))
    assert_eq(ops.length(), 1)
    assert_eq(ops[0].name(), name)
    // Same op with one param outside the catalog must fail unknown-param.
    // Parse the (valid) JSON outside the `try` so the catch handles only
    // parse_script's BatchError, not @json.parse's ParseError.
    let bogus = params[:params.length() - 1].to_owned() +
      ",\"__not_a_real_param__\":1}"
    let doc = @json.parse(one_op_script(name, bogus))
    try ignore(parse_script(doc)) catch {
      BatchError(msg) => assert_true(msg.contains("unknown param"))
    } noraise {
      _ => fail("op '\{name}' accepted a param outside its catalog spec")
    }
  }
}
