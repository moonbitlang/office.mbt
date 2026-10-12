// Runs of glyphs made by a random number generator, with every kind of
// cluster, offset, advance, fill, stroke and color glyph in one document.
// The hashes of the documents and the validation errors were recorded with
// the exporter of pdflite 0.3.9 (`moon test --update` on that release), so
// that the writers of the text path that came after it are held to its
// bytes for inputs that nobody chose.

///|
/// A linear congruential generator: the same numbers on every target.
priv struct Lcg {
  mut state : UInt
}

///|
/// A number in `0..n`.
fn Lcg::below(self : Lcg, n : Int) -> Int {
  self.state = self.state * 1664525U + 1013904223U
  ((self.state >> 8) % n.reinterpret_as_uint()).reinterpret_as_int()
}

///|
/// The 32-bit FNV-1a hash of some bytes, in hex.
fn fnv1a(bytes : Bytes) -> String {
  let mut hash = 0x811C9DC5U
  for b in bytes {
    hash = (hash ^ b.to_uint()) * 0x01000193U
  }
  let sb = StringBuilder()
  for shift in [28, 24, 20, 16, 12, 8, 4, 0] {
    sb.write_char(
      "0123456789abcdef"
      .unsafe_get((hash >> shift).reinterpret_as_int() & 0xF)
      .unsafe_to_char(),
    )
  }
  sb.to_string()
}

///|
/// A run of 1 to 12 glyphs of the test font for a text of `len` code
/// units.
fn random_run(rng : Lcg, len : Int) -> Array[@export.Glyph] {
  let advances : ReadOnlyArray[Double] = [0.5, 0.6, 0.55, 0.6, 0.25, 0.7]
  let count = 1 + rng.below(12)
  // How the clusters go: forwards, backwards, in pairs, or anywhere, also
  // outside the text.
  let order = rng.below(6)
  let glyphs = []
  for i in 0..<count {
    let id = if rng.below(8) == 0 { 0 } else { 1 + rng.below(5) }
    let (start, end) = match order {
      0 | 1 => (i, i + 1)
      2 => (count - 1 - i, count - i)
      3 => (i / 2, i / 2 + 1)
      4 => {
        let start = rng.below(len + 4) - 2
        (start, start + rng.below(4) - 1)
      }
      _ => (i % len.max(1), i % len.max(1) + 1 + rng.below(2))
    }
    let x_advance = match rng.below(6) {
      0 => advances[id] + rng.below(64).to_double() / 64.0
      1 => advances[id] + (rng.below(2000) - 1000).to_double() / 7919.0
      2 => advances[id] + 0.0000004
      _ => advances[id]
    }
    let x_offset = match rng.below(9) {
      0 => (rng.below(33) - 16).to_double() / 32.0
      1 => (rng.below(2000) - 1000).to_double() / 1000003.0
      _ => 0.0
    }
    let y_offset = if rng.below(10) == 0 { 0.25 } else { 0.0 }
    let y_advance = if rng.below(14) == 0 { 0.125 } else { 0.0 }
    glyphs.push(@export.Glyph::{
      glyph_id: id,
      text_start: start,
      text_end: end,
      x_advance,
      x_offset,
      y_advance,
      y_offset,
      location: if rng.below(2) == 0 {
        None
      } else {
        Some(rng.below(1000).to_uint64())
      },
    })
  }
  glyphs
}

///|
/// A color glyph hook for the glyphs `a` and `b`.
fn color_hook(a : Int, b : Int) -> @export.ColorGlyphs {
  {
    is_color: g => g == a || g == b,
    draw: (g, _, s) => {
      s.draw_path(rect_path(0.0, 0.0, 100.0 * g.to_double(), 700.0))
      true
    },
  }
}

///|
/// A document of 40 random runs on one page. `hooks` says what the font is
/// told about color glyphs: 0 nothing, 1 a hook from the start, 2 a hook
/// from the twentieth run on, 3 a hook from the start that is replaced
/// after 15 runs and again, by one without color glyphs, after 30.
fn random_document(
  seed : UInt,
  hooks : Int,
  settings : @export.SerializeSettings,
) -> Bytes raise {
  let rng = Lcg::{ state: seed, }
  let font = test_font()
  if hooks == 1 || hooks == 3 {
    font.set_color_glyphs(color_hook(3, 5))
  }
  let linear = @export.LinearGradient::{
    x1: 0.0,
    y1: 0.0,
    x2: 40.0,
    y2: 10.0,
    transform: @export.Transform::identity(),
    spread_method: Pad,
    stops: stops2(@export.Color::rgb(255, 0, 0), @export.Color::rgb(0, 0, 255)),
    anti_alias: false,
  }
  let one_stop = @export.LinearGradient::{
    ..linear,
    stops: [{ offset: 0.0, color: Regular(Luma(64)), opacity: 0.75, }],
  }
  let translucent = @export.LinearGradient::{
    ..linear,
    stops: stops2(
      @export.Color::rgb(0, 255, 0),
      @export.Color::rgb(0, 0, 255),
      opacity_b=0.5,
    ),
  }
  let texts : ReadOnlyArray[String] = [
    "ABCDEFGH", "a b c d", "é😀x y", "", "x", "fi ffl \u{E000}",
  ]
  let sizes : ReadOnlyArray[Double] = [10.0, 12.5, 7.3, 100.0]
  one_page(
    s => {
      let tile = s.stream_surface()
      tile.draw_path(rect_path(0.0, 0.0, 2.0, 2.0))
      let pattern = @export.Pattern::{
        stream: tile.finish_stream(),
        transform: @export.Transform::from_scale(2.0, 2.0),
        width: 4.0,
        height: 4.0,
      }
      for run in 0..<40 {
        if hooks == 2 && run == 20 {
          font.set_color_glyphs(color_hook(3, 5))
        }
        if hooks == 3 && run == 15 {
          font.set_color_glyphs(color_hook(1, 3))
        }
        if hooks == 3 && run == 30 {
          font.set_color_glyphs(color_hook(-1, -1))
        }
        let text = texts[rng.below(texts.length())]
        let glyphs = random_run(rng, text.length())
        let fill : @export.Fill? = match rng.below(12) {
          0 | 1 => None
          2 => Some(fill_of(LinearGradient(linear)))
          3 => Some(fill_of(LinearGradient(one_stop)))
          4 => Some(fill_of(LinearGradient(translucent)))
          5 => Some({ ..fill_of(Pattern(pattern)), opacity: 0.5, })
          6 | 7 =>
            Some({
              ..@export.Fill::default(),
              paint: solid(rng.below(3), 0, 0),
              opacity: 0.5,
            })
          _ =>
            Some({
              ..@export.Fill::default(),
              paint: solid(rng.below(3), 0, 0),
            })
        }
        let stroke : @export.Stroke? = match rng.below(8) {
          0 => Some(stroke_of(solid(0, 0, rng.below(3)), 1.5))
          1 => Some({ ..stroke_of(solid(0, 255, 0), 0.25), opacity: 0.25, })
          2 => Some(stroke_of(LinearGradient(translucent), 0.5))
          3 => Some(stroke_of(Pattern(pattern), 2.0))
          _ => None
        }
        s.set_fill(fill)
        s.set_stroke(stroke)
        s.set_location(rng.below(100).to_uint64())
        s.draw_glyphs(
          @export.Point::from_xy(
            rng.below(150).to_double(),
            10.0 + rng.below(80).to_double() + 0.5,
          ),
          glyphs,
          font,
          text,
          sizes[rng.below(sizes.length())],
        )
      }
    },
    settings~,
  )
}

///|
test "random runs of glyphs: the documents of pdflite 0.3.9" {
  let hashes = StringBuilder()
  for seed in 1U..<25U {
    let hooks = (seed % 4U).reinterpret_as_int()
    let bytes = random_document(seed, hooks, plain_settings())
    hashes.write_string("\{seed} \{bytes.length()} \{fnv1a(bytes)}\n")
    // The same document again: nothing is kept from one to the next.
    assert_eq(random_document(seed, hooks, plain_settings()), bytes)
  }
  inspect(
    hashes.to_string(),
    content=(
      #|1 51498 de8dd5d1
      #|2 46964 2cb3364a
      #|3 48403 010ad91b
      #|4 39006 f9dbdc0d
      #|5 43204 095b6624
      #|6 43488 9645a4fe
      #|7 43437 ecbc1392
      #|8 44479 b9b2f5e3
      #|9 48764 3cecb174
      #|10 43585 0d5e8756
      #|11 40425 c8aa4c38
      #|12 35175 42e1fe62
      #|13 49064 4a3134b3
      #|14 39420 f89294e9
      #|15 43373 d4332ad4
      #|16 37539 8b9ce462
      #|17 44262 253ee7f3
      #|18 46034 8025156d
      #|19 39200 e5fbbc1f
      #|20 37148 a23aa3ef
      #|21 45967 af52dbfe
      #|22 47564 325c035e
      #|23 44737 519bb01a
      #|24 42252 c2241275
      #|
    ),
  )
}

///|
test "random runs of glyphs: tagged, compressed and with metadata" {
  let hashes = StringBuilder()
  for seed in 100U..<110U {
    let bytes = random_document(
      seed,
      (seed % 4U).reinterpret_as_int(),
      @export.SerializeSettings::default(),
    )
    hashes.write_string("\{seed} \{bytes.length()} \{fnv1a(bytes)}\n")
  }
  inspect(
    hashes.to_string(),
    content=(
      #|100 17694 551f1eba
      #|101 25139 d77d638e
      #|102 19394 731e291a
      #|103 30225 42ca85a7
      #|104 17274 b7116b3a
      #|105 28187 717f3b3c
      #|106 31951 60882c8d
      #|107 23316 0f0fa2c3
      #|108 22618 8f555ab0
      #|109 24211 0ab7bf91
      #|
    ),
  )
}

///|
test "random runs of glyphs: the validation errors of pdflite 0.3.9" {
  let errors = StringBuilder()
  for seed in 200U..<206U {
    for a in [@export.Archival::A2_U, A1_B] {
      let result = export_result(() => {
        random_document(
          seed,
          (seed % 4U).reinterpret_as_int(),
          settings_with(a=Some(a)),
        )
      })
      // (By code unit: a cluster can end inside a surrogate pair.)
      errors.write_string("\{seed}: ")
      for i in 0..<result.length() {
        let unit = result.unsafe_get(i).to_int()
        if unit >= 0x20 && unit < 0x7F {
          errors.write_char(unit.unsafe_to_char())
        } else {
          errors.write_string("<\{unit}>")
        }
      }
      errors.write_char('\n')
    }
  }
  inspect(
    errors.to_string(),
    content=(
      #|200: Validation: ContainsNotDefGlyph(i) by PDF/A-2u; ContainsNotDefGlyph(G) by PDF/A-2u; ContainsNotDefGlyph(<56832>) by PDF/A-2u; ContainsNotDefGlyph(x) by PDF/A-2u; ContainsNotDefGlyph( ) by PDF/A-2u; ContainsNotDefGlyph(f) by PDF/A-2u; ContainsNotDefGlyph() by PDF/A-2u; ContainsNotDefGlyph( ) by PDF/A-2u; ContainsNotDefGlyph() by PDF/A-2u; ContainsNotDefGlyph(<56832>) by PDF/A-2u; ContainsNotDefGlyph(f) by PDF/A-2u; ContainsNotDefGlyph(D) by PDF/A-2u; ContainsNotDefGlyph(a ) by PDF/A-2u; ContainsNotDefGlyph(A) by PDF/A-2u; ContainsNotDefGlyph(x) by PDF/A-2u; ContainsNotDefGlyph() by PDF/A-2u; ContainsNotDefGlyph() by PDF/A-2u; ContainsNotDefGlyph(D) by PDF/A-2u; ContainsNotDefGlyph(B) by PDF/A-2u; ContainsNotDefGlyph() by PDF/A-2u; ContainsNotDefGlyph(AB) by PDF/A-2u; ContainsNotDefGlyph(CD) by PDF/A-2u; ContainsNotDefGlyph() by PDF/A-2u; ContainsNotDefGlyph() by PDF/A-2u; ContainsNotDefGlyph(B) by PDF/A-2u; ContainsNotDefGlyph(D) by PDF/A-2u; ContainsNotDefGlyph(E) by PDF/A-2u; ContainsNotDefGlyph(f) by PDF/A-2u; ContainsNotDefGlyph( ) by PDF/A-2u; ContainsNotDefGlyph() by PDF/A-2u; ContainsNotDefGlyph( ) by PDF/A-2u; ContainsNotDefGlyph(G) by PDF/A-2u
      #|200: Validation: Transparency by PDF/A-1b; Transparency by PDF/A-1b; Transparency by PDF/A-1b; Transparency by PDF/A-1b; Transparency by PDF/A-1b; Transparency by PDF/A-1b; Transparency by PDF/A-1b; Transparency by PDF/A-1b; Transparency by PDF/A-1b; Transparency by PDF/A-1b; Transparency by PDF/A-1b; Transparency by PDF/A-1b; Transparency by PDF/A-1b; Transparency by PDF/A-1b; Transparency by PDF/A-1b
      #|201: Validation: ContainsNotDefGlyph() by PDF/A-2u; ContainsNotDefGlyph(a ) by PDF/A-2u; ContainsNotDefGlyph(<233><55357>) by PDF/A-2u; ContainsNotDefGlyph() by PDF/A-2u; ContainsNotDefGlyph( y) by PDF/A-2u; ContainsNotDefGlyph() by PDF/A-2u; ContainsNotDefGlyph() by PDF/A-2u; ContainsNotDefGlyph() by PDF/A-2u; ContainsNotDefGlyph() by PDF/A-2u; ContainsNotDefGlyph() by PDF/A-2u; ContainsNotDefGlyph(i) by PDF/A-2u; ContainsNotDefGlyph() by PDF/A-2u; ContainsNotDefGlyph( ) by PDF/A-2u; ContainsNotDefGlyph(<57344>) by PDF/A-2u; ContainsNotDefGlyph(f) by PDF/A-2u; ContainsNotDefGlyph(c) by PDF/A-2u; ContainsNotDefGlyph() by PDF/A-2u; ContainsNotDefGlyph(i) by PDF/A-2u; ContainsNotDefGlyph() by PDF/A-2u; ContainsNotDefGlyph() by PDF/A-2u; ContainsNotDefGlyph() by PDF/A-2u; ContainsNotDefGlyph(i) by PDF/A-2u; ContainsNotDefGlyph( ) by PDF/A-2u; ContainsNotDefGlyph(x) by PDF/A-2u; ContainsNotDefGlyph() by PDF/A-2u; NoCodepointMapping(0) by PDF/A-2u; NoCodepointMapping(2) by PDF/A-2u; NoCodepointMapping(3) by PDF/A-2u; NoCodepointMapping(4) by PDF/A-2u; NoCodepointMapping(7) by PDF/A-2u; NoCodepointMapping(8) by PDF/A-2u; NoCodepointMapping(9) by PDF/A-2u; NoCodepointMapping(1) by PDF/A-2u; NoCodepointMapping(2) by PDF/A-2u; NoCodepointMapping(3) by PDF/A-2u
      #|201: Validation: Transparency by PDF/A-1b; Transparency by PDF/A-1b; Transparency by PDF/A-1b; Transparency by PDF/A-1b; Transparency by PDF/A-1b; Transparency by PDF/A-1b; Transparency by PDF/A-1b; Transparency by PDF/A-1b; Transparency by PDF/A-1b; Transparency by PDF/A-1b; Transparency by PDF/A-1b; Transparency by PDF/A-1b; Transparency by PDF/A-1b; Transparency by PDF/A-1b; Transparency by PDF/A-1b; Transparency by PDF/A-1b; Transparency by PDF/A-1b; Transparency by PDF/A-1b
      #|202: Validation: ContainsNotDefGlyph( ) by PDF/A-2u; ContainsNotDefGlyph(x) by PDF/A-2u; ContainsNotDefGlyph(c) by PDF/A-2u; ContainsNotDefGlyph() by PDF/A-2u; ContainsNotDefGlyph(f) by PDF/A-2u; ContainsNotDefGlyph() by PDF/A-2u; ContainsNotDefGlyph() by PDF/A-2u; ContainsNotDefGlyph() by PDF/A-2u; ContainsNotDefGlyph(<233>) by PDF/A-2u; ContainsNotDefGlyph(H) by PDF/A-2u; ContainsNotDefGlyph(a) by PDF/A-2u; ContainsNotDefGlyph( ) by PDF/A-2u; ContainsNotDefGlyph(d) by PDF/A-2u; ContainsNotDefGlyph(BC) by PDF/A-2u; ContainsNotDefGlyph() by PDF/A-2u; ContainsNotDefGlyph(<55357>) by PDF/A-2u; ContainsNotDefGlyph(B) by PDF/A-2u; ContainsNotDefGlyph() by PDF/A-2u; ContainsNotDefGlyph() by PDF/A-2u; ContainsNotDefGlyph(<56832>) by PDF/A-2u; NoCodepointMapping(1) by PDF/A-2u; NoCodepointMapping(2) by PDF/A-2u; NoCodepointMapping(3) by PDF/A-2u; NoCodepointMapping(5) by PDF/A-2u
      #|202: Validation: Transparency by PDF/A-1b; Transparency by PDF/A-1b; Transparency by PDF/A-1b; Transparency by PDF/A-1b; Transparency by PDF/A-1b; Transparency by PDF/A-1b; Transparency by PDF/A-1b; Transparency by PDF/A-1b; Transparency by PDF/A-1b; Transparency by PDF/A-1b; Transparency by PDF/A-1b; Transparency by PDF/A-1b; Transparency by PDF/A-1b
      #|203: Validation: ContainsNotDefGlyph(f) by PDF/A-2u; ContainsNotDefGlyph( ) by PDF/A-2u; ContainsNotDefGlyph(l) by PDF/A-2u; ContainsNotDefGlyph() by PDF/A-2u; ContainsNotDefGlyph() by PDF/A-2u; ContainsNotDefGlyph(<55357>) by PDF/A-2u; ContainsNotDefGlyph( ) by PDF/A-2u; ContainsNotDefGlyph(<233>) by PDF/A-2u; ContainsNotDefGlyph() by PDF/A-2u; ContainsNotDefGlyph( ) by PDF/A-2u; ContainsNotDefGlyph( ) by PDF/A-2u; ContainsNotDefGlyph() by PDF/A-2u; ContainsNotDefGlyph() by PDF/A-2u; ContainsNotDefGlyph(F) by PDF/A-2u; ContainsNotDefGlyph(G) by PDF/A-2u; ContainsNotDefGlyph(<57344>) by PDF/A-2u; ContainsNotDefGlyph(B) by PDF/A-2u; ContainsNotDefGlyph(<56832>x) by PDF/A-2u; ContainsNotDefGlyph(y) by PDF/A-2u; ContainsNotDefGlyph(G) by PDF/A-2u; NoCodepointMapping(5) by PDF/A-2u; NoCodepointMapping(6) by PDF/A-2u; NoCodepointMapping(9) by PDF/A-2u; NoCodepointMapping(10) by PDF/A-2u; NoCodepointMapping(4) by PDF/A-2u
      #|203: Validation: Transparency by PDF/A-1b; Transparency by PDF/A-1b; Transparency by PDF/A-1b; Transparency by PDF/A-1b; Transparency by PDF/A-1b; Transparency by PDF/A-1b; Transparency by PDF/A-1b; Transparency by PDF/A-1b; Transparency by PDF/A-1b; Transparency by PDF/A-1b; Transparency by PDF/A-1b; Transparency by PDF/A-1b; Transparency by PDF/A-1b
      #|204: Validation: ContainsNotDefGlyph() by PDF/A-2u; ContainsNotDefGlyph() by PDF/A-2u; ContainsNotDefGlyph() by PDF/A-2u; ContainsNotDefGlyph() by PDF/A-2u; ContainsNotDefGlyph(l) by PDF/A-2u; ContainsNotDefGlyph(i) by PDF/A-2u; ContainsNotDefGlyph( ) by PDF/A-2u; ContainsNotDefGlyph(c) by PDF/A-2u; ContainsNotDefGlyph() by PDF/A-2u; ContainsNotDefGlyph( c) by PDF/A-2u; ContainsNotDefGlyph(x) by PDF/A-2u; ContainsNotDefGlyph() by PDF/A-2u; ContainsNotDefGlyph(B) by PDF/A-2u; ContainsNotDefGlyph(B) by PDF/A-2u; ContainsNotDefGlyph(D) by PDF/A-2u; ContainsNotDefGlyph(x) by PDF/A-2u; ContainsNotDefGlyph(f) by PDF/A-2u; ContainsNotDefGlyph(<55357><56832>) by PDF/A-2u; ContainsNotDefGlyph(<56832>) by PDF/A-2u; ContainsNotDefGlyph(i) by PDF/A-2u; ContainsNotDefGlyph( ) by PDF/A-2u; ContainsNotDefGlyph(<56832>) by PDF/A-2u; ContainsNotDefGlyph(x ) by PDF/A-2u; ContainsNotDefGlyph(x) by PDF/A-2u; ContainsNotDefGlyph(C) by PDF/A-2u; ContainsNotDefGlyph(D) by PDF/A-2u; ContainsNotDefGlyph(E) by PDF/A-2u; ContainsNotDefGlyph() by PDF/A-2u; ContainsNotDefGlyph() by PDF/A-2u; NoCodepointMapping(1) by PDF/A-2u; NoCodepointMapping(2) by PDF/A-2u; NoCodepointMapping(3) by PDF/A-2u; NoCodepointMapping(4) by PDF/A-2u
      #|204: Validation: Transparency by PDF/A-1b; Transparency by PDF/A-1b; Transparency by PDF/A-1b; Transparency by PDF/A-1b; Transparency by PDF/A-1b; Transparency by PDF/A-1b; Transparency by PDF/A-1b; Transparency by PDF/A-1b; Transparency by PDF/A-1b; Transparency by PDF/A-1b
      #|205: Validation: ContainsNotDefGlyph(i) by PDF/A-2u; ContainsNotDefGlyph() by PDF/A-2u; ContainsNotDefGlyph() by PDF/A-2u; ContainsNotDefGlyph(y) by PDF/A-2u; ContainsNotDefGlyph() by PDF/A-2u; ContainsNotDefGlyph(E) by PDF/A-2u; ContainsNotDefGlyph(H) by PDF/A-2u; ContainsNotDefGlyph() by PDF/A-2u; ContainsNotDefGlyph(l ) by PDF/A-2u; ContainsNotDefGlyph(x) by PDF/A-2u; ContainsNotDefGlyph() by PDF/A-2u; ContainsNotDefGlyph() by PDF/A-2u; ContainsNotDefGlyph(GH) by PDF/A-2u; ContainsNotDefGlyph(<233>) by PDF/A-2u; ContainsNotDefGlyph(C) by PDF/A-2u; ContainsNotDefGlyph() by PDF/A-2u; ContainsNotDefGlyph() by PDF/A-2u; ContainsNotDefGlyph() by PDF/A-2u; ContainsNotDefGlyph(B) by PDF/A-2u; ContainsNotDefGlyph(<55357><56832>) by PDF/A-2u; ContainsNotDefGlyph(a) by PDF/A-2u; ContainsNotDefGlyph( ) by PDF/A-2u; NoCodepointMapping(2) by PDF/A-2u
      #|205: Validation: Transparency by PDF/A-1b; Transparency by PDF/A-1b; Transparency by PDF/A-1b; Transparency by PDF/A-1b; Transparency by PDF/A-1b; Transparency by PDF/A-1b; Transparency by PDF/A-1b; Transparency by PDF/A-1b; Transparency by PDF/A-1b; Transparency by PDF/A-1b; Transparency by PDF/A-1b; Transparency by PDF/A-1b
      #|
    ),
  )
}
