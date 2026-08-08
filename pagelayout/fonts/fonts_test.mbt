///|
test "family resolution maps metric-compatible and CJK names" {
  inspect(@fonts.resolve_family("Calibri"), content="Carlito")
  inspect(@fonts.resolve_family("ARIAL"), content="Liberation Sans")
  inspect(@fonts.resolve_family("Times New Roman"), content="Liberation Serif")
  inspect(@fonts.resolve_family("Courier New"), content="Liberation Mono")
  inspect(@fonts.resolve_family("SimSun"), content="Noto Sans SC")
  inspect(@fonts.resolve_family("MS Mincho"), content="Noto Sans SC")
  // unknown families fall back to the Word default
  inspect(@fonts.resolve_family("Comic Sans MS"), content="Carlito")
}

///|
test "bundled families" {
  debug_inspect(
    @fonts.bundled_families(),
    content=(
      #|[
      #|  "Carlito",
      #|  "Liberation Sans",
      #|  "Liberation Serif",
      #|  "Liberation Mono",
      #|  "Noto Sans SC",
      #|]
    ),
  )
}

///|
test "carlito advances are calibri-compatible" {
  let carlito = @fonts.face("Carlito")
  // 'H' (U+0048) and space (U+0020) at 12pt, from real hmtx data
  inspect(
    carlito.advance_pt(0x48, 12),
    content=(
      #|7.4765625
    ),
  )
  inspect(
    carlito.advance_pt(0x20, 12),
    content=(
      #|2.712890625
    ),
  )
  // bold face is a distinct face with its own advances
  let bold = @fonts.face("Carlito", bold=true)
  inspect(
    bold.advance_pt(0x48, 12),
    content=(
      #|7.5703125
    ),
  )
}

///|
test "liberation mono is monospaced" {
  let mono = @fonts.face("Liberation Mono")
  let w_i = mono.advance_pt('i', 12)
  let w_m = mono.advance_pt('m', 12)
  assert_eq(w_i, w_m)
}

///|
test "cjk fallback covers han and kana at fullwidth" {
  let cjk = @fonts.cjk_fallback()
  // 中 (U+4E2D) and あ (U+3042) are fullwidth: advance == size
  inspect(
    cjk.advance_pt(0x4E2D, 12),
    content=(
      #|12
    ),
  )
  inspect(
    cjk.advance_pt(0x3042, 12),
    content=(
      #|12
    ),
  )
  assert_true(cjk.has_char(0x4E2D))
  assert_true(cjk.has_char(0x3042))
  // the latin faces do not cover them
  assert_false(@fonts.face("Carlito").has_char(0x4E2D))
}

///|
test "noto bold falls back to the regular face" {
  let regular = @fonts.face("Noto Sans SC")
  let bold = @fonts.face("Noto Sans SC", bold=true)
  assert_eq(bold.ascender, regular.ascender)
  assert_eq(bold.advance_pt(0x4E2D, 12), regular.advance_pt(0x4E2D, 12))
}

///|
test "vertical metrics scale with size" {
  let carlito = @fonts.face("Carlito")
  inspect(
    carlito.ascent_pt(12),
    content=(
      #|11.42578125
    ),
  )
  inspect(
    carlito.descent_pt(12),
    content=(
      #|-3.22265625
    ),
  )
  inspect(
    carlito.line_height_pt(12),
    content=(
      #|14.6484375
    ),
  )
  assert_eq(carlito.line_height_pt(24), carlito.line_height_pt(12) * 2)
}

///|
test "missing codepoints use the notdef advance" {
  let carlito = @fonts.face("Carlito")
  assert_false(carlito.has_char(0x10FFF0))
  assert_true(carlito.advance_pt(0x10FFF0, 12) > 0)
}

///|
test "Noto Sans SC is measured at the regular weight" {
  // NotoSansSC-VF's fvar default is wght=100 (Thin), so a bundle built
  // from the default master measures hairline text. The generator
  // instances at 400 instead — the weight the PDF backend embeds
  // outlines for. fonttools reports 608 font units for 'A' at wght=400
  // against 574 at the Thin default.
  let noto = @fonts.face("Noto Sans SC")
  inspect(noto.advance_pt(0x0041, 1000), content="608")
  // ideographs are full-width at every weight, which is why the wrong
  // weight went unnoticed: the CJK advances never differed.
  inspect(noto.advance_pt(0x4E2D, 1000), content="1000")
}
