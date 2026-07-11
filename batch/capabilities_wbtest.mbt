// White-box: the capability catalog is the single source of truth for the
// op vocabulary, so it must stay in lockstep with what `parse_op` accepts.

///|
/// Every op the catalog advertises must actually parse (with a minimal
/// valid params object), and every catalog op name must be unique. If a
/// new op is added to `parse_op` without a catalog entry (or vice versa),
/// this test — and the `capabilities` payload agents rely on — drifts.
test "capability catalog matches the parser's accepted ops" {
  // A minimal valid params object per op type, keyed by op name.
  let sample : Map[String, String] = Map::from_array([
    ("set", "{\"sheet\":\"S\",\"cell\":\"A1\",\"value\":1}"),
    ("formula", "{\"sheet\":\"S\",\"cell\":\"A1\",\"formula\":\"=1\"}"),
    ("style", "{\"sheet\":\"S\",\"range\":\"A1\",\"bold\":true}"),
    ("merge", "{\"sheet\":\"S\",\"range\":\"A1:B1\"}"),
    ("width", "{\"sheet\":\"S\",\"column\":\"A\",\"width\":10}"),
    ("freeze", "{\"sheet\":\"S\",\"cell\":\"A2\"}"),
    ("filter", "{\"sheet\":\"S\",\"range\":\"A1:B2\"}"),
    ("add-sheet", "{\"name\":\"S2\"}"),
    (
      "chart", "{\"sheet\":\"S\",\"anchor\":\"E2\",\"categories\":\"A1:A3\",\"values\":\"B1:B3\"}",
    ),
  ])
  let names = accepted_op_names()
  // Names are unique.
  let seen : Map[String, Unit] = Map([])
  for name in names {
    assert_false(seen.contains(name))
    seen[name] = ()
  }
  // Every advertised op parses with its sample; a catalog op the parser
  // rejects as "unknown op" would be a drift.
  for name in names {
    let params = match sample.get(name) {
      Some(p) => p
      None =>
        fail("catalog op '\{name}' has no sample; add one when adding the op")
    }
    let script = "{\"schema\":\"xlsx.batch/1\",\"ops\":[{\"op\":\"\{name}\",\"params\":\{params}}]}"
    let ops = parse_script(@json.parse(script))
    assert_eq(ops.length(), 1)
    assert_eq(ops[0].name(), name)
  }
}

///|
/// A compact structural pin of the capability payload — envelope keys and,
/// per op, `name(required-count/total-count)` — so any op/param addition
/// or removal surfaces here without a 200-line JSON blob.
test "capabilities payload structure" {
  let payload = capabilities()
  let obj = match payload {
    Object(map) => map
    _ => fail("capabilities must be a JSON object")
  }
  let envelope = [
    match obj.get("schema") {
      Some(String(s)) => s
      _ => fail("schema")
    },
    match obj.get("batch_schema") {
      Some(String(s)) => s
      _ => fail("batch_schema")
    },
  ]
  inspect(envelope.join(" "), content="xlsx.capabilities/1 xlsx.batch/1")
  let shape = []
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
    let mut required = 0
    for p in params {
      match p {
        Object(pm) => if pm.get("required") is Some(True) { required += 1 }
        _ => ()
      }
    }
    shape.push("\{name}(\{required}/\{params.length()})")
  }
  inspect(
    shape.join(" "),
    content="set(3/3) formula(3/3) style(2/8) merge(2/2) width(3/3) freeze(2/2) filter(2/2) add-sheet(1/1) chart(4/7)",
  )
}
