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
// self-consistent across targets is not a candidate at all. The miniz port
// that eventually replaces this encoder inherits the same corpus and the same
// layered shape.
//
// What these establish is bounded, and worth stating plainly: a fixed corpus
// pins the inputs it contains. It does not prove determinism for every input,
// and no finite set of vectors could. It is a tripwire on the cases most
// likely to move, not a proof.
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
/// The same window-boundary inputs, put through the two *match* encoders
/// directly.
///
/// Fingerprinting `pdf_flate_encode_view_with_level_pure` on these inputs
/// looked like it exercised the matcher and did not. The filler is
/// pseudorandom, so a match block never wins the shortest-of-five in
/// `pdf_flate_encode_shortest_view_with_header`, and every window vector came
/// out a stored block -- 32810, 32811 and 32812 bytes, which is the input plus
/// eleven bytes of overhead exactly. A wrong decision at distance 32768 would
/// have changed a candidate that was then thrown away, and nothing would have
/// failed.
///
/// Calling the match encoders directly removes the selector from the path, so
/// what is frozen here is the matcher's own output. That is the difference
/// between a vector that names a boundary and one that observes it.
test "the match encoders agree across backends at the window boundary" {
  let report = StringBuilder()
  for entry in determinism_corpus() {
    let (name, input) = entry
    let header = pdf_flate_default_header()
    let fixed = compressed_fingerprint(
      pdf_flate_encode_fixed_match_view_with_header(input, header, 64),
    ) catch {
      _ => "refused"
    }
    let dynamic = compressed_fingerprint(
      pdf_flate_encode_dynamic_match_view_with_header(input, header, 64),
    ) catch {
      _ => "refused"
    }
    report.write_string("\{name} -> fixed \{fixed}, dynamic \{dynamic}\n")
  }
  inspect(
    report.to_string(),
    content=(
      #|empty -> fixed 8/14824338622843246134, dynamic refused
      #|one byte -> fixed 9/13568697314492027819, dynamic 18/11047135761050842108
      #|run of one byte -> fixed 45/557724821224124885, dynamic 36/8612204165405055478
      #|two byte alternation -> fixed 46/16279519239315844423, dynamic 37/5618370571900035297
      #|short period -> fixed 47/6927378909121949868, dynamic 39/14678099569522409921
      #|ascii text -> fixed 95/15587916932111909485, dynamic 87/1543866814679470439
      #|incompressible -> fixed 4328/2917743237973570490, dynamic 4149/8194585243882375378
      #|match at min length -> fixed 12/2639939916108656735, dynamic 24/8431668463424152740
      #|match at max length -> fixed 4332/15730415509624980273, dynamic 4157/10313984095815335140
      #|match just over max length -> fixed 4333/15476286444731857204, dynamic 4158/13094449772697927971
      #|match inside the window -> fixed 34540/8188916071948798354, dynamic 32835/8485899633772460554
      #|match at the window edge -> fixed 34541/3625857351499066867, dynamic 32836/2305518650226659544
      #|match past the window -> fixed 34573/11816148757564220675, dynamic 32863/16625718742296044121
      #|
    ),
  )
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
      #|empty L1 -> 8/14824338622843246134
      #|empty L6 -> 8/6911146735378767749
      #|empty L9 -> 8/14759312151674839831
      #|one byte L1 -> 9/13568697314492027819
      #|one byte L6 -> 9/828246333215700918
      #|one byte L9 -> 9/17653723601550578860
      #|run of one byte L1 -> 45/557724821224124885
      #|run of one byte L6 -> 36/12572656134146150957
      #|run of one byte L9 -> 36/16552231566622930215
      #|two byte alternation L1 -> 46/16279519239315844423
      #|two byte alternation L6 -> 37/7418910060698619040
      #|two byte alternation L9 -> 37/9347609185736776178
      #|short period L1 -> 47/6927378909121949868
      #|short period L6 -> 39/2581812125755959212
      #|short period L9 -> 39/8876555857819478286
      #|ascii text L1 -> 95/15587916932111909485
      #|ascii text L6 -> 87/10489274318409934514
      #|ascii text L9 -> 87/17066630369213191672
      #|incompressible L1 -> 4107/1796056689918308922
      #|incompressible L6 -> 4107/18113870579437559803
      #|incompressible L9 -> 4107/2944213211331891961
      #|match at min length L1 -> 12/2639939916108656735
      #|match at min length L6 -> 12/2045780800923981600
      #|match at min length L9 -> 12/1413492088161137002
      #|match at max length L1 -> 4332/15730415509624980273
      #|match at max length L6 -> 4157/14761360415821845229
      #|match at max length L9 -> 4157/8024987876748244523
      #|match just over max length L1 -> 4333/15476286444731857204
      #|match just over max length L6 -> 4158/16666636091135287276
      #|match just over max length L9 -> 4158/7492761351085382806
      #|match inside the window L1 -> 32810/4572843696782456202
      #|match inside the window L6 -> 32810/17370746825549709153
      #|match inside the window L9 -> 32810/11078468105645183003
      #|match at the window edge L1 -> 32811/5486740597604588422
      #|match at the window edge L6 -> 32811/10651560261308354067
      #|match at the window edge L9 -> 32811/15331854772633486345
      #|match past the window L1 -> 32812/8735179885577524760
      #|match past the window L6 -> 32812/5094626065315791723
      #|match past the window L9 -> 32812/12392486578709101729
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
