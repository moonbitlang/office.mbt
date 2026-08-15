///|
// Cross-backend determinism of the pure deflate encoder.
//
// `pdf_flate_encode_view_with_level` is not one implementation. On native it
// calls the vendored miniz through a C stub; everywhere else it calls
// `pdf_flate_encode_view_with_level_pure`. So a PDF written on native and the
// same PDF written on wasm are semantically identical and byte-different, and
// nothing until now checked what the pure half does from one backend to the
// next.
//
// That gap matters more than it looks. The pure encoder is the only compressor
// that exists on every target, so it is the one candidate for making output
// byte-identical everywhere -- and a candidate nobody has shown to be
// self-consistent across targets is not a candidate at all. These vectors
// establish the property, and the miniz port that eventually replaces this
// encoder inherits the same corpus and the same two-layer shape.
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
//     trip already establishes correctness independently: the snapshot is
//     asked only whether every backend agrees, which is not a question the
//     input can answer.
//
// The corpus targets the matcher rather than the entropy coder. Random bytes
// are the weakest input here -- they are incompressible, so they exercise the
// stored and literal paths and almost nothing else. What finds real bugs is
// structure: runs, periodic repeats at chosen distances, and matches placed
// against the boundaries the LZ77 window is built around.

///|
/// A compact printable fingerprint: byte length and both Adler-32 halves.
///
/// Length alone would miss a same-size reordering, and a full hex dump of 70KB
/// of compressed output would make the snapshot unreadable and unreviewable.
fn compressed_fingerprint(data : BytesView) -> String {
  let (s1, s2) = pdf_flate_adler32(data)
  "\{data.length()}/\{s2}:\{s1}"
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
/// the encoder has exactly one match to find at exactly the distance
/// `prefix`. This is how a specific window distance gets exercised on purpose
/// rather than by chance.
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
    ("match at min distance", match_at_distance(3, 3)),
    ("match at max length", match_at_distance(4096, 258)),
    ("match just over max length", match_at_distance(4096, 259)),
    ("match inside the window", match_at_distance(32767, 32)),
    ("match at the window edge", match_at_distance(32768, 32)),
    ("match past the window", match_at_distance(32769, 32)),
  ]
}

///|
/// The levels worth pinning. The pure encoder takes two different paths by
/// level -- `pdf_flate_encode_fast_view_with_header` at 1..3 and
/// `pdf_flate_encode_shortest_view_with_header` above -- and the probe budget
/// varies within each, so 1, 6 and 9 cover both shapes and both ends of the
/// budget without pinning all ten.
fn determinism_levels() -> Array[Int] {
  [1, 6, 9]
}

///|
test "the pure encoder round trips every corpus input at every level" {
  for entry in determinism_corpus() {
    let (name, input) = entry
    for level in determinism_levels() {
      let encoded = pdf_flate_encode_view_with_level_pure(input, level)
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
      let encoded = pdf_flate_encode_view_with_level_pure(input, level)
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
      let encoded = pdf_flate_encode_view_with_level_pure(input, level)
      report.write_string(
        "\{name} L\{level} -> \{compressed_fingerprint(encoded)}\n",
      )
    }
  }
  inspect(
    report.to_string(),
    content=(
      #|empty L1 -> 8/994:126
      #|empty L6 -> 8/2079:281
      #|empty L9 -> 8/2513:343
      #|one byte L1 -> 9/2778:535
      #|one byte L6 -> 9/4018:690
      #|one byte L9 -> 9/4514:752
      #|run of one byte L1 -> 45/48034:4893
      #|run of one byte L6 -> 36/27722:5281
      #|run of one byte L9 -> 36/29892:5343
      #|two byte alternation L1 -> 46/59607:5253
      #|two byte alternation L6 -> 37/31857:5390
      #|two byte alternation L9 -> 37/34089:5452
      #|short period L1 -> 47/5071:5698
      #|short period L6 -> 39/37805:5410
      #|short period L9 -> 39/40161:5472
      #|ascii text L1 -> 95/56428:11185
      #|ascii text L6 -> 87/60005:12540
      #|ascii text L9 -> 87/65337:12602
      #|incompressible L1 -> 4107/50057:1408
      #|incompressible L6 -> 4107/31277:1563
      #|incompressible L9 -> 4107/23765:1625
      #|match at min distance L1 -> 12/5738:837
      #|match at min distance L6 -> 12/7443:992
      #|match at min distance L9 -> 12/8125:1054
      #|match at max length L1 -> 4332/37773:27762
      #|match at max length L6 -> 4157/56049:9847
      #|match at max length L9 -> 4157/51637:9909
      #|match just over max length L1 -> 4333/1586:28133
      #|match just over max length L6 -> 4158/1172:10148
      #|match just over max length L9 -> 4158/62343:10210
      #|match inside the window L1 -> 32810/33526:30483
      #|match inside the window L6 -> 32810/8283:30638
      #|match inside the window L9 -> 32810/11290:30700
      #|match at the window edge L1 -> 32811/1050:30679
      #|match at the window edge L6 -> 32811/41483:30834
      #|match at the window edge L9 -> 32811/44552:30896
      #|match past the window L1 -> 32812/34147:30833
      #|match past the window L6 -> 32812/9214:30988
      #|match past the window L9 -> 32812/12345:31050
      #|
    ),
  )
}
