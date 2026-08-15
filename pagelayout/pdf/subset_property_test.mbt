///|
// Properties of font subsetting, checked over generated character sets
// rather than over hand-picked strings.
//
// These deliberately measure the *subset program*, never the rendered
// file length. pdflite compresses through the vendored miniz on native
// and through its own deflate elsewhere, so file length is a property of
// the backend as much as of the document; the program the subsetter
// returns is not.
//
// They run against the Latin face, not the CJK one. Every property here
// is face-independent, and subsetting a 31,036-glyph face eighty times in
// an unoptimized test build costs minutes rather than seconds. The one
// claim that is specifically about the large face — that a CJK document
// embeds a subset rather than the whole program — is asserted end to end
// in `pdf_test.mbt` instead.
//
// The driver is `@quickcheck.samples` rather than `@quickcheck.check`.
// `check` shrinks a counterexample, which is worth having, but it does
// not exist in the moonc the CI matrix pins (0.10.5); `samples` is the
// long-standing entry point and is deterministic — `@splitmix.new()`
// defaults to seed 37 — so a failure here reproduces exactly. Move to
// `check` once the pinned toolchain carries it.

///|
/// The bundled Latin program.
fn latin_program() -> Bytes raise {
  match @fontoutlines.outline_sfnt(@fonts.resolve_family("Calibri")) {
    Some(program) => program
    None => fail("no bundled program for the Latin family")
  }
}

///|
/// Distinct codepoints, in first-use order — the shape
/// `collect_codepoints` hands the subsetter.
///
/// The generated integers are only a source of randomness. Each is folded
/// into printable ASCII, because a codepoint the face lacks would make
/// every property below vacuous: it contributes no glyph, so the subset
/// is right not to grow for it.
///
/// The fold is a remainder, not a bitmask. Masking with the range's width
/// looks equivalent and is not: `& 0x5D` reaches 32 of these 94
/// characters and never produces an uppercase letter.
fn printable(seeds : ArrayView[Int]) -> Array[Int] {
  let seen : Map[Int, Unit] = Map([])
  let unique : Array[Int] = []
  for seed in seeds {
    // '!' through '~'; the mask only clears the sign so the remainder
    // cannot be negative
    let codepoint = 0x21 + (seed & 0x7FFFFFFF) % 94
    if !seen.contains(codepoint) {
      seen[codepoint] = ()
      unique.push(codepoint)
    }
  }
  unique
}

///|
/// The generated character sets every property below runs over.
fn generated_character_sets() -> Array[Array[Int]] raise {
  let cases : Array[Array[Int]] = @quickcheck.samples(16)
  let sets : Array[Array[Int]] = []
  for case in cases {
    let unique = printable(case)
    // one codepoint cannot exercise a prefix relation, and zero cannot
    // exercise anything
    if unique.length() >= 2 {
      sets.push(unique)
    }
  }
  // a generator that stopped producing usable input would otherwise let
  // every property below pass without testing anything
  assert_true(sets.length() >= 4)
  sets
}

///|
test "a subset never exceeds the program it came from" {
  let program = latin_program()
  for codepoints in generated_character_sets() {
    let subset = @pdflite.pdf_truetype_subset_font(program, codepoints)
    assert_true(subset.length() <= program.length())
  }
}

///|
test "adding a character never shrinks the subset" {
  let program = latin_program()
  for codepoints in generated_character_sets() {
    // the prefix is a strict subset of the whole set by construction, so
    // a subsetter that keeps only what it is asked for is monotone here
    let smaller = @pdflite.pdf_truetype_subset_font(
      program,
      codepoints[0:codepoints.length() - 1],
    )
    let larger = @pdflite.pdf_truetype_subset_font(program, codepoints)
    assert_true(larger.length() >= smaller.length())
  }
}

///|
test "the same character set always subsets to the same bytes" {
  let program = latin_program()
  for codepoints in generated_character_sets() {
    let first = @pdflite.pdf_truetype_subset_font(program, codepoints)
    let second = @pdflite.pdf_truetype_subset_font(program, codepoints)
    assert_eq(first, second)
  }
}
