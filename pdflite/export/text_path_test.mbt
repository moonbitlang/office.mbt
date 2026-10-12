// Black-box tests of the text path: what a run of text writes into its
// content stream, for the cases that the writers of `text.mbt` tell apart.
// The expectations were recorded with the exporter of pdflite 0.3.9, which
// built the items of a `TJ` array as objects before it wrote them.

///|
/// The lines of a content stream that show text or position it.
fn shown(content : String) -> String {
  let sb = StringBuilder()
  for line in content.split("\n") {
    let line = line.to_owned()
    if line.has_suffix(" TJ") ||
      line.has_suffix(" Tj") ||
      line.has_suffix(" Tm") ||
      line.has_suffix(" Tf") {
      sb.write_string(line)
      sb.write_char('\n')
    }
  }
  sb.to_string()
}

///|
test "Type 3 codes are shown as literal strings if all of them are printable" {
  let font = test_font()
  font.set_color_glyphs({ is_color: _ => true, draw: (_, _, _) => false, })
  // Every context color gives the five glyphs five new codes: run `k`
  // shows the codes `5 k` to `5 k + 4`, so the runs go through the
  // unprintable codes, the printable ones with `(`, `)` and `\`, and DEL.
  let p = parse(
    one_page(s => {
      for k in 0..<27 {
        s.set_fill(Some({ ..@export.Fill::default(), paint: solid(k, 0, 0), }))
        s.draw_glyphs(
          @export.Point::from_xy(10.0, 50.0),
          [
            glyph(1, 0, 1),
            glyph(2, 1, 2),
            glyph(3, 2, 3),
            glyph(4, 3, 4),
            glyph(5, 4, 5),
          ],
          font,
          "ABCDE",
          10.0,
        )
      }
      // One code alone, printable and not.
      s.set_fill(Some({ ..@export.Fill::default(), paint: solid(8, 0, 0), }))
      s.draw_glyphs(
        @export.Point::from_xy(10.0, 70.0),
        [glyph(1, 0, 1)],
        font,
        "A",
        10.0,
      )
      s.set_fill(Some({ ..@export.Fill::default(), paint: solid(0, 0, 0), }))
      s.draw_glyphs(
        @export.Point::from_xy(10.0, 70.0),
        [glyph(1, 0, 1)],
        font,
        "A",
        10.0,
      )
    }),
  )
  inspect(
    shown(p.content(p.page(0))),
    content=(
      #|/f0 10 Tf
      #|1 0 0 -1 10 50 Tm
      #|[<0001020304>] TJ
      #|/f0 10 Tf
      #|1 0 0 -1 10 50 Tm
      #|[<0506070809>] TJ
      #|/f0 10 Tf
      #|1 0 0 -1 10 50 Tm
      #|[<0A0B0C0D0E>] TJ
      #|/f0 10 Tf
      #|1 0 0 -1 10 50 Tm
      #|[<0F10111213>] TJ
      #|/f0 10 Tf
      #|1 0 0 -1 10 50 Tm
      #|[<1415161718>] TJ
      #|/f0 10 Tf
      #|1 0 0 -1 10 50 Tm
      #|[<191A1B1C1D>] TJ
      #|/f0 10 Tf
      #|1 0 0 -1 10 50 Tm
      #|[<1E1F202122>] TJ
      #|/f0 10 Tf
      #|1 0 0 -1 10 50 Tm
      #|[(#$%&')] TJ
      #|/f0 10 Tf
      #|1 0 0 -1 10 50 Tm
      #|[(\(\)*+,)] TJ
      #|/f0 10 Tf
      #|1 0 0 -1 10 50 Tm
      #|[(-./01)] TJ
      #|/f0 10 Tf
      #|1 0 0 -1 10 50 Tm
      #|[(23456)] TJ
      #|/f0 10 Tf
      #|1 0 0 -1 10 50 Tm
      #|[(789:;)] TJ
      #|/f0 10 Tf
      #|1 0 0 -1 10 50 Tm
      #|[(<=>?@)] TJ
      #|/f0 10 Tf
      #|1 0 0 -1 10 50 Tm
      #|[(ABCDE)] TJ
      #|/f0 10 Tf
      #|1 0 0 -1 10 50 Tm
      #|[(FGHIJ)] TJ
      #|/f0 10 Tf
      #|1 0 0 -1 10 50 Tm
      #|[(KLMNO)] TJ
      #|/f0 10 Tf
      #|1 0 0 -1 10 50 Tm
      #|[(PQRST)] TJ
      #|/f0 10 Tf
      #|1 0 0 -1 10 50 Tm
      #|[(UVWXY)] TJ
      #|/f0 10 Tf
      #|1 0 0 -1 10 50 Tm
      #|[(Z[\\]^)] TJ
      #|/f0 10 Tf
      #|1 0 0 -1 10 50 Tm
      #|[(_`abc)] TJ
      #|/f0 10 Tf
      #|1 0 0 -1 10 50 Tm
      #|[(defgh)] TJ
      #|/f0 10 Tf
      #|1 0 0 -1 10 50 Tm
      #|[(ijklm)] TJ
      #|/f0 10 Tf
      #|1 0 0 -1 10 50 Tm
      #|[(nopqr)] TJ
      #|/f0 10 Tf
      #|1 0 0 -1 10 50 Tm
      #|[(stuvw)] TJ
      #|/f0 10 Tf
      #|1 0 0 -1 10 50 Tm
      #|[(xyz{|)] TJ
      #|/f0 10 Tf
      #|1 0 0 -1 10 50 Tm
      #|[<7D7E7F8081>] TJ
      #|/f0 10 Tf
      #|1 0 0 -1 10 50 Tm
      #|[<8283848586>] TJ
      #|/f0 10 Tf
      #|1 0 0 -1 10 70 Tm
      #|(\() Tj
      #|/f0 10 Tf
      #|1 0 0 -1 10 70 Tm
      #|<00> Tj
      #|
    ),
  )
}

///|
test "the items of a TJ array: strings and adjustments in every order" {
  let font = test_font()
  // The font's advances are 0.5, 0.6, 0.55, 0.6, 0.25 and 0.7 em.
  let run = (glyphs : Array[@export.Glyph]) => {
    let text = "ABCDEFGH"
    let p = parse(text_page(font, glyphs, text))
    shown(p.content(p.page(0)))
  }
  // No adjustment at all; one before the first glyph; one after every
  // glyph but the last; one that is not written because it is too small,
  // and what it leaves for the next one.
  inspect(
    run([glyph(1, 0, 1), glyph(2, 1, 2), glyph(3, 2, 3)]),
    content=(
      #|/f0 10 Tf
      #|1 0 0 -1 10 50 Tm
      #|[<000100020003>] TJ
      #|
    ),
  )
  inspect(
    run([glyph(1, 0, 1, x_offset=0.1), glyph(2, 1, 2), glyph(3, 2, 3)]),
    content=(
      #|/f0 10 Tf
      #|1 0 0 -1 10 50 Tm
      #|[-100 <0001> 100 <00020003>] TJ
      #|
    ),
  )
  inspect(
    run([
      glyph(1, 0, 1, x_advance=0.7),
      glyph(2, 1, 2, x_advance=0.55),
      glyph(3, 2, 3, x_advance=0.9),
    ]),
    content=(
      #|/f0 10 Tf
      #|1 0 0 -1 10 50 Tm
      #|[<0001> -100 <00020003>] TJ
      #|
    ),
  )
  inspect(
    run([
      glyph(1, 0, 1, x_advance=0.6000004),
      glyph(2, 1, 2, x_advance=0.5500004),
      glyph(3, 2, 3, x_advance=0.6000004),
      glyph(4, 3, 4),
    ]),
    content=(
      #|/f0 10 Tf
      #|1 0 0 -1 10 50 Tm
      #|[<000100020003> -0.0012 <0004>] TJ
      #|
    ),
  )
  // Offsets that follow each other, an offset and an advance on one glyph,
  // negative ones, and values with many digits.
  inspect(
    run([
      glyph(1, 0, 1, x_offset=-0.05),
      glyph(2, 1, 2, x_offset=0.05),
      glyph(3, 2, 3, x_advance=0.123456789, x_offset=0.333333333),
      glyph(4, 3, 4, x_advance=1.0e-5),
      glyph(5, 4, 5, x_advance=12345.678),
      glyph(1, 5, 6),
    ]),
    content=(
      #|/f0 10 Tf
      #|1 0 0 -1 10 50 Tm
      #|[50 <0001> -100 <0002> -283.33334 <0003> 809.8765 <0004> 249.99 <0005>] TJ
      #|/f0 10 Tf
      #|1 0 0 -1 123479.516 50 Tm
      #|<0001> Tj
      #|
    ),
  )
  // A single glyph: `Tj` without an offset, `TJ` with one.
  inspect(
    run([glyph(2, 0, 1)]),
    content=(
      #|/f0 10 Tf
      #|1 0 0 -1 10 50 Tm
      #|<0001> Tj
      #|
    ),
  )
  inspect(
    run([glyph(2, 0, 1, x_offset=0.0005)]),
    content=(
      #|/f0 10 Tf
      #|1 0 0 -1 10 50 Tm
      #|<0001> Tj
      #|
    ),
  )
  inspect(
    run([glyph(2, 0, 1, x_offset=0.25)]),
    content=(
      #|/f0 10 Tf
      #|1 0 0 -1 10 50 Tm
      #|[-250 <0001>] TJ
      #|
    ),
  )
  // Groups: a glyph with a y offset between two without.
  inspect(
    run([
      glyph(1, 0, 1),
      glyph(2, 1, 2, y_offset=0.3),
      glyph(3, 2, 3, y_offset=0.3, x_advance=0.75),
      glyph(4, 3, 4),
    ]),
    content=(
      #|/f0 10 Tf
      #|1 0 0 -1 10 50 Tm
      #|<0001> Tj
      #|/f0 10 Tf
      #|1 0 0 -1 16 47 Tm
      #|[<00020003>] TJ
      #|/f0 10 Tf
      #|1 0 0 -1 29 50 Tm
      #|<0004> Tj
      #|
    ),
  )
}

///|
test "many runs with one font: codes, cmap and widths" {
  let font = test_font()
  // The glyphs in an order other than their IDs, used again in later runs
  // and on a second surface call with other text for one of them.
  let p = parse(
    one_page(s => {
      for round in 0..<3 {
        s.draw_glyphs(
          @export.Point::from_xy(10.0, 20.0 + 10.0 * round.to_double()),
          [glyph(4, 0, 1), glyph(2, 1, 2), glyph(5, 2, 3), glyph(2, 3, 4)],
          font,
          "abcb",
          10.0,
        )
      }
      s.draw_glyphs(
        @export.Point::from_xy(10.0, 60.0),
        [glyph(1, 0, 1), glyph(4, 1, 2), glyph(2, 2, 3)],
        font,
        "xay",
        10.0,
      )
    }),
  )
  inspect(
    shown(p.content(p.page(0))),
    content=(
      #|/f0 10 Tf
      #|1 0 0 -1 10 20 Tm
      #|[<0001000200030002>] TJ
      #|/f0 10 Tf
      #|1 0 0 -1 10 30 Tm
      #|[<0001000200030002>] TJ
      #|/f0 10 Tf
      #|1 0 0 -1 10 40 Tm
      #|[<0001000200030002>] TJ
      #|/f0 10 Tf
      #|1 0 0 -1 10 60 Tm
      #|[<00040001>] TJ
      #|/f0 10 Tf
      #|1 0 0 -1 18.5 60 Tm
      #|<0002> Tj
      #|
    ),
  )
  let f0 = p.font0()
  let cmap = latin1(p.stream_data(p.get(f0, "ToUnicode")))
  inspect(
    cmap_body(cmap),
    content=(
      #|4 beginbfchar
      #|<0001> <0061>
      #|<0002> <0062>
      #|<0003> <0063>
      #|<0004> <0078>
      #|endbfchar
      #|
    ),
  )
  let cid = p.path(f0, ["DescendantFonts"])
  inspect(
    p.show(cid),
    content=(
      #|[R]
    ),
  )
}
