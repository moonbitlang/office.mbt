// Seeded fuzz over the batch script parser (zip/fuzz_test.mbt pattern).
// Oracle: for ANY input, `parse_script` either returns ops or raises a
// typed `BatchError` — the error type is enforced by the compiler, so the
// run enforces no-panic; the generators guarantee the parser is actually
// reached every round (a text mutator would mostly die in the JSON lexer
// and test nothing).

///|
/// Build a reproducible RNG from a label (32-byte chacha8 seed folded
/// from the label bytes, like zip/fuzz_test.mbt).
fn fuzz_rng(label : Bytes) -> @random.Rand {
  let seed = Array::make(32, (0x5A).to_byte())
  seed[0] = label.length().to_byte()
  seed[1] = (label.length() >> 8).to_byte()
  for i in 0..<label.length() {
    let j = 2 + i % 30
    seed[j] = (seed[j].to_int() * 31 + label[i].to_int()).to_byte()
  }
  @random.Rand::chacha8(seed=Bytes::from_array(seed))
}

///|
let op_names : Array[String] = [
  "set", "formula", "style", "merge", "width", "freeze", "filter", "add-sheet", "chart",
  "nop", "", "SET",
]

///|
let param_keys : Array[String] = [
  "sheet", "cell", "value", "formula", "range", "column", "width", "name", "anchor",
  "categories", "values", "type", "title", "bold", "italic", "fill", "font_color",
  "number_format", "align", "colour", "extra",
]

///|
/// A random JSON scalar-or-shallow value, weighted toward the types batch
/// params use so both accept and reject paths are exercised.
fn random_value(rng : @random.Rand) -> Json {
  match rng.int(limit=8) {
    0 => Json::string("A1")
    1 => Json::string("Data")
    2 => Json::number(rng.int(limit=100).to_double())
    3 => Json::boolean(rng.boolean())
    4 => Json::null()
    5 => Json::number(rng.double() * 1000.0)
    6 => Json::array([Json::number(1.0)])
    _ => Json::string("A1:B\{rng.int(limit=9) + 1}")
  }
}

///|
/// Known-valid ops (against a workbook holding sheet "Data"), mixed into
/// the stream so the apply path is genuinely exercised alongside the
/// reject paths.
fn valid_op(rng : @random.Rand) -> Json {
  match rng.int(limit=4) {
    0 =>
      Json::object({
        "op": Json::string("set"),
        "params": Json::object({
          "sheet": Json::string("Data"),
          "cell": Json::string("A\{rng.int(limit=9) + 1}"),
          "value": Json::number(rng.int(limit=100).to_double()),
        }),
      })
    1 =>
      Json::object({
        "op": Json::string("merge"),
        "params": Json::object({
          "sheet": Json::string("Data"),
          "range": Json::string("A10:B10"),
        }),
      })
    2 =>
      Json::object({
        "op": Json::string("freeze"),
        "params": Json::object({
          "sheet": Json::string("Data"),
          "cell": Json::string("A2"),
        }),
      })
    _ =>
      Json::object({
        "op": Json::string("width"),
        "params": Json::object({
          "sheet": Json::string("Data"),
          "column": Json::string("A"),
          "width": Json::number((rng.int(limit=30) + 1).to_double()),
        }),
      })
  }
}

///|
fn random_op(rng : @random.Rand) -> Json {
  if rng.int(limit=3) == 0 {
    return valid_op(rng)
  }
  let params : Map[String, Json] = {}
  let param_count = rng.int(limit=6)
  for _i in 0..<param_count {
    params[param_keys[rng.int(limit=param_keys.length())]] = random_value(rng)
  }
  let entry : Map[String, Json] = {
    "op": Json::string(op_names[rng.int(limit=op_names.length())]),
  }
  if rng.int(limit=10) != 0 {
    entry["params"] = Json::object(params)
  }
  if rng.int(limit=12) == 0 {
    entry["extra_key"] = Json::boolean(true)
  }
  Json::object(entry)
}

///|
/// A random full document: usually a well-formed envelope holding random
/// ops, sometimes a corrupted envelope (wrong schema, wrong shapes).
fn random_document(rng : @random.Rand) -> Json {
  let ops = []
  for _i in 0..<rng.int(limit=5) {
    ops.push(random_op(rng))
  }
  let root : Map[String, Json] = {}
  match rng.int(limit=8) {
    0 => root["schema"] = Json::string("xlsx.batch/2")
    1 => root["schema"] = Json::number(1.0)
    2 => () // missing schema
    _ => root["schema"] = Json::string("xlsx.batch/1")
  }
  match rng.int(limit=8) {
    0 => root["ops"] = Json::string("not-an-array")
    1 => () // missing ops
    _ => root["ops"] = Json::array(ops)
  }
  if rng.int(limit=10) == 0 {
    root["unexpected"] = Json::null()
  }
  match rng.int(limit=12) {
    0 => Json::array([Json::object(root)])
    1 => Json::string("scalar")
    _ => Json::object(root)
  }
}

///|
test "fuzz: generated documents parse or fail typed, never panic" {
  let rng = fuzz_rng(b"batch-generated-documents")
  let mut parsed = 0
  let mut rejected = 0
  for _round in 0..<600 {
    // `parse_script` raises only `BatchError` — the compiler enforces the
    // typed-error half of the oracle; the run enforces no-panic. Every
    // round reaches the parser (the document is already valid JSON).
    match (try? parse_script(random_document(rng))) {
      Ok(_) => parsed += 1
      Err(BatchError(_)) => rejected += 1
    }
  }
  assert_eq(parsed + rejected, 600)
  // The generator must exercise both outcomes to test anything.
  assert_true(parsed > 20)
  assert_true(rejected > 100)
}

///|
test "fuzz: parsed scripts apply or fail typed on a live workbook" {
  let rng = fuzz_rng(b"batch-generated-apply")
  let mut applied = 0
  let mut errored = 0
  for _round in 0..<200 {
    // Parseable by construction: a valid envelope holding valid ops and,
    // sometimes, apply-poisoned ops (parse-valid but failing at apply,
    // e.g. a missing sheet or an out-of-grid range).
    let ops_json = []
    for _i in 0..<(rng.int(limit=4) + 1) {
      if rng.int(limit=3) == 0 {
        ops_json.push(
          Json::object({
            "op": Json::string("merge"),
            "params": Json::object({
              "sheet": Json::string("Missing"),
              "range": Json::string("A1:B1"),
            }),
          }),
        )
      } else {
        ops_json.push(valid_op(rng))
      }
    }
    let document = Json::object({
      "schema": Json::string("xlsx.batch/1"),
      "ops": Json::array(ops_json),
    })
    let ops = parse_script(document)
    let workbook = @xlsx.Workbook::new()
    ignore(workbook.add_sheet("Data"))
    for op in ops {
      // Application may fail (missing sheet) but must fail with an error,
      // never a panic; the workbook stays usable either way.
      try apply_op(workbook, op) catch {
        _ => {
          errored += 1
          break
        }
      } noraise {
        _ => applied += 1
      }
    }
    ignore(workbook.get_sheet_list())
  }
  assert_true(applied > 50)
  assert_true(errored > 20)
}
