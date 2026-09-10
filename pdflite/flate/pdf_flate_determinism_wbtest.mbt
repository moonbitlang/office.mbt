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
/// The levels worth pinning. 1, 6 and 9 cover fast, default and high
/// compression. Stored blocks at level 0 are covered by the round-trip tests.
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
/// Round-tripping the shipping encoder over generated input, across *every*
/// level rather than the three the fingerprints pin.
///
/// This covers a different axis from the corpus above, which is why both
/// exist: the corpus is hand-aimed at window boundaries at three levels, and
/// this is unaimed input at all ten. Level 0 in particular is a different mode
/// -- every block stored -- that no fixed corpus entry visits.
///
/// The driver is `samples` rather than `check` because `@quickcheck.check`
/// does not exist in the moonc the CI matrix pins. `samples` seeds
/// `@splitmix.new()` at its default 37, so a failure reproduces exactly.
/// Shrinking would be worth having here and is worth revisiting when the pin
/// moves.
test "the shipping encoder round trips generated input at every level" {
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
/// The frozen cross-backend fingerprints.
///
/// If this fails on one backend and passes on another, the shipping encoder
/// is not deterministic across targets and the whole idea of byte-identical output
/// rests on nothing. If it fails on all backends at once, the encoder simply
/// changed -- check the round-trip test above still passes, then re-freeze.
test "the shipping encoder produces identical bytes on every backend" {
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
      #|empty L6 -> 8/14824338622843246134
      #|empty L9 -> 8/14824338622843246134
      #|one byte L1 -> 9/13568697314492027819
      #|one byte L6 -> 9/13568697314492027819
      #|one byte L9 -> 9/13568697314492027819
      #|run of one byte L1 -> 27/7422571855894930489
      #|run of one byte L6 -> 27/7422571855894930489
      #|run of one byte L9 -> 27/7422571855894930489
      #|two byte alternation L1 -> 28/17371897846531197899
      #|two byte alternation L6 -> 28/17371897846531197899
      #|two byte alternation L9 -> 28/17371897846531197899
      #|short period L1 -> 29/4206590865824530627
      #|short period L6 -> 29/4206590865824530627
      #|short period L9 -> 29/4206590865824530627
      #|ascii text L1 -> 78/4818767968346529930
      #|ascii text L6 -> 75/1093528484905272696
      #|ascii text L9 -> 75/1093528484905272696
      #|incompressible L1 -> 4107/1796056689918308922
      #|incompressible L6 -> 4107/1796056689918308922
      #|incompressible L9 -> 4107/1796056689918308922
      #|match at min length L1 -> 12/2639939916108656735
      #|match at min length L6 -> 12/2639939916108656735
      #|match at min length L9 -> 12/2639939916108656735
      #|match at max length L1 -> 4157/14542821839357302632
      #|match at max length L6 -> 4157/14542821839357302632
      #|match at max length L9 -> 4157/14542821839357302632
      #|match just over max length L1 -> 4158/3383875242522992994
      #|match just over max length L6 -> 4158/3383875242522992994
      #|match just over max length L9 -> 4158/3383875242522992994
      #|match inside the window L1 -> 32817/16382763202028659272
      #|match inside the window L6 -> 32817/16382763202028659272
      #|match inside the window L9 -> 32817/16382763202028659272
      #|match at the window edge L1 -> 32789/45508829365105148
      #|match at the window edge L6 -> 32789/45508829365105148
      #|match at the window edge L9 -> 32789/45508829365105148
      #|match past the window L1 -> 32821/173356275775370549
      #|match past the window L6 -> 32821/173356275775370549
      #|match past the window L9 -> 32821/173356275775370549
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
  // Captured from the former vendored miniz encoder and verified with zlib.
  let encoded = b"\x78\x9c\x01\x30\x00\xcf\xff\x01\x12\x23\x34\x45\x56\x67\x78\x89\x9a\xab\xbc\xcd\xde\xef\x05\x16\x27\x38\x49\x5a\x6b\x7c\x8d\x9e\xaf\xc0\xd1\xe2\xf3\x09\x1a\x2b\x3c\x4d\x5e\x6f\x80\x91\xa2\xb3\xc4\xd5\xe6\xf7\x0d\x1e\x2f\xf8\xb9\x16\x27"
  let decoded = pdf_flate_decode_view(encoded)
  assert_eq(decoded, input)
}
