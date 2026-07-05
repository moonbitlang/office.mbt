// Property and fuzz tests for the docx2html untrusted-input surface: the
// standalone XML parser (`read_xml_string`) and the DOCX pipeline
// (`convert_to_html` / `read_docx`, which unzip a container and parse its XML).
// Deterministic, seed-reproducible. A crash (abort/panic) inside a parser
// fails the test; parsers must only ever return a typed `DocxError` or a value.

///|
/// Reproducible RNG from a label of any length: fold length + every byte into
/// chacha8's 32-byte seed so distinct labels yield distinct seeds.
fn docx_fuzz_rng(label : Bytes) -> @random.Rand {
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
/// A string drawn from an XML-heavy alphabet so the tokenizer's tag,
/// attribute, entity, and comment paths are all exercised by malformed input.
fn docx_fuzz_xmlish(rng : @random.Rand, len : Int) -> String {
  let alphabet : Array[Char] = []
  for c in "<>/=\"'& ;\t\n?!-[]abcABC012xyz:" {
    alphabet.push(c)
  }
  let sb = StringBuilder::new()
  for _ in 0..<len {
    sb.write_char(alphabet[rng.int(limit=alphabet.length())])
  }
  sb.to_string()
}

///|
fn docx_fuzz_bytes(rng : @random.Rand, len : Int) -> Bytes {
  Bytes::from_array(Array::makei(len, fn(_) { rng.int(limit=256).to_byte() }))
}

// ---- Property: XML parse -> write is a stable fixpoint ---------------------

///|
test "property: read_xml_string then write_xml_string is stable" {
  // Re-serializing a parsed document, then re-parsing and re-serializing,
  // must reach the same string: the parser and serializer agree.
  let samples = [
    "<p><r><t>Hello world</t></r></p>", "<root a=\"1\" b='two'><child/><child>text &amp; more &lt;ok&gt;</child></root>",
    "<a><b><c>deep</c></b></a>", "<x><y/><y/><y>  spaced  </y></x>", "<note to=\"a\" from=\"b\"><body>quote &quot;q&quot; apos &apos;a&apos;</body></note>",
  ]
  for sample in samples {
    let first = @docx2html.write_xml_string(@docx2html.read_xml_string(sample))
    let second = @docx2html.write_xml_string(@docx2html.read_xml_string(first))
    guard first == second else {
      fail("xml parse/write not stable for: \{sample}")
    }
  }
}

// ---- Fuzz: parsers tolerate arbitrary input --------------------------------

///|
test "fuzz: read_xml_string tolerates arbitrary xml-ish strings" {
  let rng = docx_fuzz_rng(b"docx-xml-arbitrary")
  for _iter in 0..<15000 {
    let text = docx_fuzz_xmlish(rng, rng.int(limit=200))
    try @docx2html.read_xml_string(text) |> ignore catch {
      _ => ()
    }
  }
}

///|
test "fuzz: convert_to_html/read_docx tolerate arbitrary bytes" {
  let rng = docx_fuzz_rng(b"docx-bytes-arbitrary")
  for _iter in 0..<6000 {
    let bytes = docx_fuzz_bytes(rng, rng.int(limit=300))
    try @docx2html.convert_to_html(bytes) |> ignore catch {
      _ => ()
    }
    try @docx2html.read_docx(bytes) |> ignore catch {
      _ => ()
    }
  }
}

///|
test "fuzz: convert_to_html tolerates corrupted valid docx" {
  let rng = docx_fuzz_rng(b"docx-corrupted")
  let base_arr = single_paragraph_docx().to_array()
  for _iter in 0..<4000 {
    let arr = base_arr.copy()
    let flips = rng.int(limit=6) + 1
    for _f in 0..<flips {
      arr[rng.int(limit=arr.length())] = rng.int(limit=256).to_byte()
    }
    try @docx2html.convert_to_html(Bytes::from_array(arr)) |> ignore catch {
      _ => ()
    }
  }
}
