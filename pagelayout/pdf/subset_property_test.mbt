///|
// Properties of font subsetting, checked over generated character sets
// rather than over hand-picked strings.
//
// These deliberately measure the *subset program*, never the rendered
// file length. pdflite compresses through miniz on native and through its
// own deflate elsewhere, so file length is a property of the backend as
// much as of the document; the program the subsetter returns is not.
//
// They run against the Latin face, not the CJK one. Every property here
// is face-independent, and subsetting a 31,036-glyph face eighty times in
// an unoptimized test build costs minutes rather than seconds. The one
// claim that is specifically about the large face — that a CJK document
// embeds a subset rather than the whole program — is asserted end to end
// in `pdf_test.mbt` instead.

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
fn printable(seeds : ArrayView[Int]) -> Array[Int] {
  let seen : Map[Int, Unit] = Map([])
  let unique : Array[Int] = []
  for seed in seeds {
    let codepoint = 0x21 + (seed & 0x5D)
    if !seen.contains(codepoint) {
      seen[codepoint] = ()
      unique.push(codepoint)
    }
  }
  unique
}

///|
test "a subset never exceeds the program it came from" {
  let program = latin_program()
  @quickcheck.check(
    (seeds : Array[Int]) => {
      let subset = @pdflite.pdf_truetype_subset_font(program, printable(seeds))
      subset.length() <= program.length()
    },
    filter=seeds => seeds.length() > 0,
    count=8,
    seed=0x70616765_6C61796FUL,
  )
}

///|
test "adding a character never shrinks the subset" {
  let program = latin_program()
  @quickcheck.check(
    (seeds : Array[Int]) => {
      let unique = printable(seeds)
      // the prefix is a strict subset of the whole set by construction,
      // so a subsetter that keeps only what it is asked for is monotone
      let smaller = @pdflite.pdf_truetype_subset_font(
        program,
        unique[0:unique.length() - 1],
      )
      let larger = @pdflite.pdf_truetype_subset_font(program, unique)
      larger.length() >= smaller.length()
    },
    filter=seeds => printable(seeds).length() >= 2,
    count=8,
    seed=0x70616765_6C61796FUL,
  )
}

///|
test "the same character set always subsets to the same bytes" {
  let program = latin_program()
  @quickcheck.check(
    (seeds : Array[Int]) => {
      let unique = printable(seeds)
      let first = @pdflite.pdf_truetype_subset_font(program, unique)
      let second = @pdflite.pdf_truetype_subset_font(program, unique)
      first == second
    },
    filter=seeds => seeds.length() > 0,
    count=8,
    seed=0x70616765_6C61796FUL,
  )
}
