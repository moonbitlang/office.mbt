// Property and fuzz tests for the PDF reader — the primary untrusted-input
// surface (opening an arbitrary .pdf). Deterministic seeds make any failure
// reproducible. A crash (abort/panic) inside the reader fails the test; the
// reader must only ever return a typed `PdfError` or a value.

///|
/// Reproducible RNG from a label of any length: fold the label's length and
/// every byte into chacha8's required 32-byte seed so distinct labels yield
/// distinct seeds.
fn pdf_fuzz_rng(label : Bytes) -> @random.Rand {
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
fn pdf_fuzz_bytes(rng : @random.Rand, len : Int) -> Bytes {
  Bytes::from_array(Array::makei(len, fn(_) { rng.int(limit=256).to_byte() }))
}

// ---- Property: a valid document survives write/read cycles ----------------

///|
test "property: valid pdf survives repeated write/read cycles" {
  let doc = @pdflite.pdf_blank_document(200.0, 200.0, 3)
  let bytes1 = @pdflite.pdf_write_document(doc)
  let doc2 = @pdflite.pdf_read_document_from_bytes(bytes1)
  guard @pdflite.pdf_pages_of_pagetree(doc2).length() == 3 else {
    fail("page count changed after first round-trip")
  }
  // Re-serialize the re-parsed document and read it again: the pipeline must
  // be stable, not degrade a valid document into an unreadable one.
  let bytes2 = @pdflite.pdf_write_document(doc2)
  let doc3 = @pdflite.pdf_read_document_from_bytes(bytes2)
  guard @pdflite.pdf_pages_of_pagetree(doc3).length() == 3 else {
    fail("page count changed after second round-trip")
  }
}

// ---- Fuzz: readers tolerate arbitrary and corrupted input -----------------

///|
test "fuzz: pdf reader tolerates arbitrary bytes" {
  let rng = pdf_fuzz_rng(b"pdf-read-arbitrary")
  for _iter in 0..<2000 {
    let bytes = pdf_fuzz_bytes(rng, rng.int(limit=400))
    try @pdflite.pdf_read_document_from_bytes(bytes) |> ignore catch {
      _ => ()
    }
  }
}

///|
test "fuzz: pdf reader tolerates corrupted valid documents" {
  let rng = pdf_fuzz_rng(b"pdf-read-corrupted")
  let base = @pdflite.pdf_write_document(
    @pdflite.pdf_blank_document(200.0, 200.0, 2),
  )
  let base_arr = base.to_array()
  for _iter in 0..<1500 {
    let arr = base_arr.copy()
    let flips = rng.int(limit=6) + 1
    for _f in 0..<flips {
      arr[rng.int(limit=arr.length())] = rng.int(limit=256).to_byte()
    }
    try
      @pdflite.pdf_read_document_from_bytes(Bytes::from_array(arr)) |> ignore
    catch {
      _ => ()
    }
  }
}

///|
test "fuzz: pdf content-stream parser tolerates arbitrary bytes" {
  let rng = pdf_fuzz_rng(b"pdf-content-ops")
  for _iter in 0..<3000 {
    let bytes = pdf_fuzz_bytes(rng, rng.int(limit=300))
    try @pdflite.pdf_parse_content_ops_from_bytes(bytes) |> ignore catch {
      _ => ()
    }
  }
}

///|
/// Regression: a content stream consisting of a stray closing delimiter lexes
/// to an empty operator token that consumes no input. Before the parser's
/// advance-guard this spun forever, growing the op array until memory was
/// exhausted (found by the fuzz test above). It must now terminate with a
/// typed error.
test "regression: content parser rejects stray delimiters (no infinite loop)" {
  for stray in [b")", b"]", b">", b"}", b")))", b"] >"] {
    try @pdflite.pdf_parse_content_ops_from_bytes(stray) |> ignore catch {
      _ => ()
    } noraise {
      _ => fail("stray delimiter must raise, not parse into ops")
    }
  }
}
