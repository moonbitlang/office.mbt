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
    ("validate", "{\"sheet\":\"S\",\"range\":\"A1\",\"type\":\"list\"}"),
  ])
}

///|
fn one_op_script(name : String, params : String) -> String {
  "{\"schema\":\"xlsx.batch/1\",\"ops\":[{\"op\":\"\{name}\",\"params\":\{params}}]}"
}

///|
/// A valid JSON value for a catalog param `type` label.
fn value_for_type(kind : String) -> Json {
  match kind {
    "cell" => Json::string("A1")
    "range" => Json::string("A1")
    "colon_range" => Json::string("A1:B2")
    "table_range" => Json::string("A1:B2")
    "sqref" => Json::string("A1")
    "column" => Json::string("A")
    "series_range" => Json::string("A1:A3")
    "number" => Json::number(10)
    "bool" => Json::boolean(true)
    "value" => Json::number(1)
    "string_array" => Json::array([Json::string("a")])
    _ => Json::string("S") // "string" and any future scalar label
  }
}

///|
/// A params object providing EVERY catalog param of `op` (required and
/// optional) with a type-valid value, read from the emitted catalog so it
/// cannot drift from what `capabilities` advertises.
fn full_sample(op : String) -> String {
  let ops = match capabilities() {
    Object(m) =>
      match m.get("ops") {
        Some(Array(items)) => items
        _ => abort("no ops")
      }
    _ => abort("bad payload")
  }
  let params : Map[String, Json] = Map([])
  for entry in ops {
    match entry {
      Object(o) =>
        if o.get("op") is Some(String(n)) && n == op {
          match o.get("params") {
            Some(Array(ps)) =>
              for p in ps {
                match p {
                  Object(pm) =>
                    match (pm.get("name"), pm.get("type")) {
                      (Some(String(pn)), Some(String(pt))) =>
                        params[pn] = value_for_type(pt)
                      _ => ()
                    }
                  _ => ()
                }
              }
            _ => ()
          }
        }
      _ => ()
    }
  }
  Json::object(params).stringify()
}

///|
/// Field-exact snapshot of the emitted catalog: `op: pname:ptype[!] …` per
/// op (`!` = required). Any param name, type, requiredness, or op change
/// surfaces here — not just count changes.
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
      parts.push("\{pn}:\{pt}\{if req { "!" } else { "" }}")
    }
    lines.push("\{name}: \{parts.join(" ")}")
  }
  inspect(
    lines.join("\n"),
    content=(
      #|set: sheet:string! cell:cell! value:value!
      #|formula: sheet:string! cell:cell! formula:string!
      #|style: sheet:string! range:range! bold:bool italic:bool number_format:string fill:string font_color:string align:string
      #|merge: sheet:string! range:colon_range!
      #|width: sheet:string! column:column! width:number!
      #|freeze: sheet:string! cell:cell!
      #|filter: sheet:string! range:colon_range!
      #|add-sheet: name:string!
      #|chart: sheet:string! anchor:cell! categories:series_range! values:series_range! type:string name:string title:string
      #|table: sheet:string! range:table_range! name:string style:string header_row:bool row_stripes:bool first_column:bool last_column:bool column_stripes:bool
      #|validate: sheet:string! range:sqref! type:string! operator:string formula1:string formula2:string values:string_array source:string allow_blank:bool input_title:string input_message:string error_title:string error_message:string error_style:string
    ),
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
/// - **param set exactness**: every catalog param is accepted by the
///   parser (full-param sample parses), and a param NOT in the catalog is
///   rejected — together with the `ParamReader` `declared` guard (which
///   aborts if a parser arm reads an undeclared param), the catalog's param
///   set is exactly the parser's.
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
    // Every catalog param (required AND optional) is accepted — a full
    // sample built from the catalog itself must parse. This exercises the
    // `declared` guard for the optional params too (it aborts if the
    // parser reads a param the catalog omits).
    let full = full_sample(name)
    let full_ops = parse_script(@json.parse(one_op_script(name, full)))
    assert_eq(full_ops.length(), 1)
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
