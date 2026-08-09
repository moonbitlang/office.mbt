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

///|
test "characters no bundled face can draw are reported" {
  // U+2A01 is the GRADE certainty symbol; a systematic review table uses
  // dozens of them, and no bundled face has it, so every one is dropped.
  debug_inspect(
    @fonts.uncovered("⨁⨁⨁◯ High", "Calibri"),
    content=(
      #|[(10753, 3)]
    ),
  )
  // U+25EF is covered by Noto Sans SC, which is the fallback layout
  // actually uses, so it renders and is not reported
  inspect(@fonts.uncovered("◯", "Calibri").length(), content="0")
  // ordinary text reports nothing
  inspect(
    @fonts.uncovered("Hello, world! 中文", "Calibri").length(),
    content="0",
  )
  // astral characters report one codepoint, not two surrogate halves
  debug_inspect(
    @fonts.uncovered("𝑝", "Calibri"),
    content=(
      #|[(119901, 1)]
    ),
  )
  // The answer depends on the face, because layout falls back only to the
  // CJK face and never to a third family. U+05D0 is in Liberation but not
  // in Carlito or Noto Sans SC, so Hebrew set in Calibri is dropped —
  // asking the whole bundle would call this covered and say nothing while
  // the renderer silently lost it.
  debug_inspect(
    @fonts.uncovered("א", "Calibri"),
    content=(
      #|[(1488, 1)]
    ),
  )
  inspect(@fonts.uncovered("א", "Arial").length(), content="0")
}
