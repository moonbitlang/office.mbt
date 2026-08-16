///|
// Cross-backend determinism of the encoder that ships.
//
// These used to pin `pdf_flate_encode_view_with_level_pure`, back when
// encoding was target-split: miniz through a C stub on native, that pure
// encoder everywhere else. The split is gone -- one MoonBit port of miniz now
// serves every backend -- and these vectors follow it, because a suite that
// pins a retired implementation cannot detect a divergence in the live one.
//
// That matters more here than it looks. The differential against the C can
// only run on native, since native is where miniz exists. So these vectors are
// the *only* thing standing between a backend-specific fault in the port --
// an Int shift, a wraparound lowered differently under wasm codegen -- and
// silently different PDFs. If they were still measuring the old encoder,
// nothing at all would be watching that.
//
// Two layers, because they fail for different reasons:
//
//   * the round trip says the output is *valid* deflate, and holds on every
//     backend independently. It cannot see a backend producing different but
//     equally valid bytes.
//   * the frozen fingerprints say the output is *the same* on every backend.
//     They are engine output rather than a value derived from the input, which
//     normally makes a snapshot worthless -- see the warning in
//     docs/page-layout-engine.md about `moon test --update` freezing wrong
//     answers three times. It is legitimate here precisely because the round
//     trip establishes correctness independently, leaving the snapshot one
//     question the input cannot answer: do the backends agree.
//
// The corpus targets the matcher rather than the entropy coder. Random bytes
// are the weakest input here -- incompressible, so they exercise the stored
// and literal paths and almost nothing else. What finds real bugs is
// structure: runs, periodic repeats at chosen distances, and matches placed
// against the boundaries the LZ77 window is built around.
//
// What these establish is bounded, and worth stating plainly: a fixed corpus
// pins the inputs it contains. It does not prove determinism for every input,
// and no finite set of vectors could. It is a tripwire on the cases most
// likely to move, not a proof.

///|
/// A compact printable fingerprint: byte length and FNV-1a 64.
///
/// A full hex dump of 32KB of compressed output would make the snapshot
/// unreadable, so this has to be a digest -- but it must not be Adler-32,
/// which was the first choice and is unfit for exactly this job. Adler is a
/// pair of linear sums, so deltas that cancel leave it unchanged: shifting
/// four equally spaced bytes by (+8, -8, -8, +8) preserves both halves and
/// both lengths. That is not a contrived shape. It is what a bit-writer or
/// stored-block padding divergence looks like, which is precisely the
/// divergence these vectors exist to catch.
///
/// FNV-1a multiplies by a prime at every step, so a cancelling pattern in the
/// input does not cancel in the digest. It is not cryptographic and does not
/// need to be: nothing here is adversarial, it only has to not be linear.
fn compressed_fingerprint(data : BytesView) -> String {
  let mut hash = 0xCBF29CE484222325UL
  for byte in data {
    hash = (hash ^ byte.to_int().to_uint64()) * 0x100000001B3UL
  }
  "\{data.length()}/\{hash}"
}

///|
/// `count` bytes of the repeating pattern `unit`.
fn repeating(unit : Bytes, count : Int) -> Bytes {
  let out = Array::make(count, b'\x00')
  for i in 0..<count {
    out[i] = unit[i % unit.length()]
  }
  Bytes::from_array(out)
}

///|
/// A deterministic byte stream with no exploitable structure, as a stand-in
/// for incompressible input. A linear congruential generator is enough: the
/// point is that the matcher finds nothing, not that the bytes are good
/// randomness.
fn incompressible(count : Int) -> Bytes {
  let out = Array::make(count, b'\x00')
  let mut state = 0x2545F491
  for i in 0..<count {
    state = (state * 1103515245 + 12345) & 0x7FFFFFFF
    out[i] = ((state >> 16) & 0xFF).to_byte()
  }
  Bytes::from_array(out)
}

///|
/// `prefix` bytes of filler, then a copy of the opening `match_len` bytes, so
/// a match of exactly `match_len` is available at exactly distance `prefix`.
/// This is how a specific window distance gets exercised on purpose rather
/// than by chance.
///
/// It places that match deliberately; it does not make it the only one. The
/// filler is pseudorandom, and incidental three-byte matches do occur inside
/// it.
fn match_at_distance(prefix : Int, match_len : Int) -> Bytes {
  let head = incompressible(prefix)
  let out = Array::make(prefix + match_len, b'\x00')
  for i in 0..<prefix {
    out[i] = head[i]
  }
  for i in 0..<match_len {
    out[prefix + i] = head[i]
  }
  Bytes::from_array(out)
}

///|
/// The corpus, as (name, bytes). Names appear in the snapshot so a failure
/// says which input diverged rather than only that something did.
///
/// The distances are chosen, not arbitrary. 3 and 258 are the shortest and
/// longest match deflate can encode; 32768 is the LZ77 window size, so a match
/// at 32767 is reachable and one at 32769 is not, and an encoder that is
/// wrong at the boundary is wrong at exactly one of them.
fn determinism_corpus() -> Array[(String, Bytes)] {
  [
    ("empty", b""),
    ("one byte", b"x"),
    ("run of one byte", repeating(b"a", 4096)),
    ("two byte alternation", repeating(b"ab", 4096)),
    ("short period", repeating(b"abc", 4096)),
    (
      "ascii text",
      repeating(b"the quick brown fox jumps over the lazy dog. ", 4096),
    ),
    ("incompressible", incompressible(4096)),
    ("match at min length", match_at_distance(3, 3)),
    ("match at max length", match_at_distance(4096, 258)),
    ("match just over max length", match_at_distance(4096, 259)),
    ("match inside the window", match_at_distance(32767, 32)),
    ("match at the window edge", match_at_distance(32768, 32)),
    ("match past the window", match_at_distance(32769, 32)),
  ]
}

///|
/// The levels worth pinning. tdefl derives its probe budget from the level and
/// parses greedily at or below 3, so 1, 6 and 9 cover both parsing modes and
/// both ends of the budget without pinning all ten. Level 0 is a third mode
/// entirely -- every block stored -- and is covered by the differential.
fn determinism_levels() -> Array[Int] {
  [1, 6, 9]
}

///|
test "the shipping encoder round trips every corpus input at every level" {
  for entry in determinism_corpus() {
    let (name, input) = entry
    for level in determinism_levels() {
      let encoded = pdf_flate_encode_view_with_level(input, level)
      let decoded = pdf_flate_decode_view(encoded)
      assert_eq(decoded, input, msg="\{name} at level \{level}")
    }
  }
}

///|
/// Round-tripping over generated input, across *every* level rather than the
/// three the fingerprints pin.
///
/// This covers a different axis from the corpus above, which is why both
/// exist: the corpus is hand-aimed at window boundaries at three levels, and
/// this is unaimed input at all ten. Levels 0 and 4 in particular reach
/// encoder paths -- stored-only, and the shortest-of-five search at its
/// smallest probe budget -- that no fixed corpus entry visits.
///
/// The driver is `samples` rather than `check` because `@quickcheck.check`
/// does not exist in the moonc the CI matrix pins. `samples` seeds
/// `@splitmix.new()` at its default 37, so a failure reproduces exactly.
/// Shrinking would be worth having here and is worth revisiting when the pin
/// moves.
test "the pure encoder round trips generated input at every level" {
  let cases : Array[Array[Int]] = @quickcheck.samples(24)
  let mut checked = 0
  for case in cases {
    let bytes = Array::make(case.length(), b'\x00')
    for i, value in case {
      bytes[i] = (value & 0xFF).to_byte()
    }
    let input = Bytes::from_array(bytes)
    for level in 0..<=9 {
      let encoded = pdf_flate_encode_view_with_level(input, level)
      let decoded = pdf_flate_decode_view(encoded)
      assert_eq(decoded, input, msg="generated case at level \{level}")
      checked = checked + 1
    }
  }
  // a generator that produced nothing would let this pass without encoding a
  // single byte
  assert_true(checked >= 200)
}

///|
/// The superseded pure encoder, kept exercised until it is removed.
///
/// It no longer compresses anything this library ships -- the tdefl port does
/// that on every backend now -- so this is not production behaviour under
/// test. It is here so the code is exercised rather than merely present,
/// because deleting it also takes several whitebox tests with it and that
/// deserves to be reviewed as its own change rather than buried in this one.
test "the superseded pure encoder still round trips" {
  for entry in determinism_corpus() {
    let (name, input) = entry
    for level in determinism_levels() {
      let encoded = pdf_flate_encode_view_with_level_pure(input, level)
      let decoded = pdf_flate_decode_view(encoded)
      assert_eq(decoded, input, msg="\{name} at level \{level}")
    }
  }
  let encoded = pdf_flate_encode_view_pure(b"the superseded default path")
  assert_eq(pdf_flate_decode_view(encoded), b"the superseded default path")
}

///|
/// The frozen cross-backend fingerprints.
///
/// If this fails on one backend and passes on another, the pure encoder is not
/// deterministic across targets and the whole idea of byte-identical output
/// rests on nothing. If it fails on all backends at once, the encoder simply
/// changed -- check the round-trip test above still passes, then re-freeze.
test "the pure encoder produces identical bytes on every backend" {
  let report = StringBuilder()
  for entry in determinism_corpus() {
    let (name, input) = entry
    for level in determinism_levels() {
      let encoded = pdf_flate_encode_view_with_level(input, level)
      report.write_string(
        "\{name} L\{level} -> \{compressed_fingerprint(encoded)}\n",
      )
    }
  }
  inspect(
    report.to_string(),
    content=(
      #|empty L1 -> 8/14824338622843246134
      #|empty L6 -> 8/6911146735378767749
      #|empty L9 -> 8/14759312151674839831
      #|one byte L1 -> 12/15334653992341479941
      #|one byte L6 -> 12/9103512613188771834
      #|one byte L9 -> 12/1477187045979222560
      #|run of one byte L1 -> 27/16909317384082252037
      #|run of one byte L6 -> 27/5342862714225513024
      #|run of one byte L9 -> 27/6320673573973985542
      #|two byte alternation L1 -> 28/1790555792005547381
      #|two byte alternation L6 -> 28/6206358874910773078
      #|two byte alternation L9 -> 28/13925073964433396032
      #|short period L1 -> 30/16622481287708767414
      #|short period L6 -> 30/3861212437799193461
      #|short period L9 -> 30/6639653733228650603
      #|ascii text L1 -> 81/13065414424299247187
      #|ascii text L6 -> 78/16076638798301380115
      #|ascii text L9 -> 78/9897020229401360809
      #|incompressible L1 -> 4107/1796056689918308922
      #|incompressible L6 -> 4107/18113870579437559803
      #|incompressible L9 -> 4107/2944213211331891961
      #|match at min length L1 -> 17/12796437208713877008
      #|match at min length L6 -> 17/9642731722754445741
      #|match at min length L9 -> 17/17534497681747351687
      #|match at max length L1 -> 4158/3812646275254487814
      #|match at max length L6 -> 4158/2917575848151996797
      #|match at max length L9 -> 4158/11049122108143090391
      #|match just over max length L1 -> 4158/18415994867377575201
      #|match just over max length L6 -> 4158/3129149196627366818
      #|match just over max length L9 -> 4158/8047443120060652380
      #|match inside the window L1 -> 32815/3700220301623607302
      #|match inside the window L6 -> 32815/5777192330433584179
      #|match inside the window L9 -> 32815/12682421586913109777
      #|match at the window edge L1 -> 32816/15156081953735415434
      #|match at the window edge L6 -> 32816/10589444655346571849
      #|match at the window edge L9 -> 32816/910985093074615347
      #|match past the window L1 -> 32817/16392211436829005332
      #|match past the window L6 -> 32817/6146692398123617537
      #|match past the window L9 -> 32817/17816882447211310851
      #|
    ),
  )
}

///|
/// A dynamic block that declares a distance tree and uses none of it.
///
/// This decoder used to reject that as malformed, which made it unable to read
/// streams the vendored miniz produces -- and therefore unable to read real
/// PDFs, on any backend without the C decoder to fall back to. It went
/// unnoticed because native decoded through the FFI and the old pure encoder
/// never emitted the shape.
///
/// The input is 48 bytes with almost no repetition, which is what drives the
/// compressor to encode literals only and leave the distance tree empty.
test "a block with no matches decodes despite its empty distance tree" {
  let bytes = []
  // ascending-ish values with no repeats long enough to match
  for i in 0..<48 {
    bytes.push((i * 17 % 251 + 1).to_byte())
  }
  let input = Bytes::from_array(bytes)
  let encoded = pdf_flate_encode_view_with_level(input, 6)
  let decoded = pdf_flate_decode_view(encoded)
  assert_eq(decoded, input)
}
