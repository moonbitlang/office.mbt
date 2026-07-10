// Seeded fuzz over the batch script parser (zip/fuzz_test.mbt pattern).
// Oracle: for ANY input the parser either returns ops or raises a typed
// `BatchError` — never a panic. Structured mutations of a valid script
// may legitimately still parse; only the no-panic/typed-error invariant
// is asserted, plus a known-invalid corpus with pinned messages in
// batch_test.mbt.

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
let valid_script : String =
  #|{"schema": "xlsx.batch/1", "ops": [
  #|  {"op": "set", "params": {"sheet": "Data", "cell": "A1", "value": "x"}},
  #|  {"op": "style", "params": {"sheet": "Data", "range": "A1:B2", "bold": true}},
  #|  {"op": "chart", "params": {"sheet": "Data", "anchor": "E2", "categories": "A1:A3", "values": "B1:B3"}}
  #|]}

///|
/// The tokens mutation swaps in: JSON punctuation, keywords, type
/// changers, and key-corrupters.
let mutation_tokens : Array[String] = [
  "null", "true", "false", "0", "-1", "1e309", "[]", "{}", "\"\"", "\"nope\"", "}",
  "{", "[", "]", ",", ":", "\\", "\"op\"", "\"params\"", "\"schema\"",
]

///|
fn mutate_script(rng : @random.Rand, source : String) -> String {
  let out = StringBuilder()
  let mutations = rng.int(limit=4) + 1
  // Pick byte offsets to corrupt; splice a token or delete a span there.
  let mut next = 0
  for _round in 0..<mutations {
    let pos = rng.int(limit=source.length())
    if pos < next {
      continue
    }
    out.write_string(try! source[next:pos].to_owned())
    if rng.boolean() {
      out.write_string(mutation_tokens[rng.int(limit=mutation_tokens.length())])
      next = pos
    } else {
      // Delete a short span.
      next = pos + rng.int(limit=8)
      if next > source.length() {
        next = source.length()
      }
    }
  }
  if next < source.length() {
    out.write_string(try! source[next:].to_owned())
  }
  out.to_string()
}

///|
test "fuzz: mutated scripts parse or fail typed, never panic" {
  let rng = fuzz_rng(b"batch-structured-mutations")
  let mut parsed = 0
  let mut rejected = 0
  for _round in 0..<400 {
    let script = mutate_script(rng, valid_script)
    let document = @json.parse(script) catch {
      _ => {
        // Not JSON at all: the CLI reports the parse error; fine.
        rejected += 1
        continue
      }
    }
    // `parse_script` raises only `BatchError` — the compiler enforces the
    // typed-error half of the oracle; the run enforces no-panic.
    match (try? parse_script(document)) {
      Ok(_) => parsed += 1
      Err(BatchError(_)) => rejected += 1
    }
  }
  // Sanity: the mutator must produce a healthy mix, or it isn't testing
  // anything. (Counts are deterministic thanks to the seeded RNG.)
  assert_true(parsed > 0)
  assert_true(rejected > 200)
}

///|
test "fuzz: random garbage never panics the parser" {
  let rng = fuzz_rng(b"batch-random-garbage")
  for _round in 0..<400 {
    let len = rng.int(limit=200)
    let bytes = Array::makei(len, _ => rng.int(limit=128).to_byte())
    let text = StringBuilder()
    for b in bytes {
      text.write_char(b.to_int().to_char().unwrap_or(' '))
    }
    let document = @json.parse(text.to_string()) catch { _ => continue }
    match (try? parse_script(document)) {
      Ok(_) => ()
      Err(BatchError(_)) => ()
    }
  }
}
