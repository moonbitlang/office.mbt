///|
// Text measurement: per-code-unit advances from the bundled font metrics,
// with per-character CJK fallback. The trail half of a surrogate pair
// carries advance 0, matching the page-model GlyphRun contract.

///|
/// Measurement of one string in one face/size: `advances_pt[i]` pairs with
/// UTF-16 code unit `i`; `fallback[i]` records that the CJK fallback face
/// (not the requested face) supplied that character's metrics, so run
/// splitting can reference the face that will actually render it.
pub(all) struct Measured {
  advances_pt : Array[Double]
  fallback : Array[Bool]
} derive(Eq, Debug, ToJson)

///|
/// Measure `text` in `face` at `size_pt`. Characters the face lacks are
/// measured in `fallback_face` (default: the bundled CJK face) when that
/// face has them; characters neither face covers use the requested face's
/// `.notdef` advance.
pub fn measure(
  text : String,
  face : @fonts.FaceMetrics,
  size_pt : Double,
  fallback_face? : @fonts.FaceMetrics,
) -> Measured {
  let cjk = match fallback_face {
    Some(f) => f
    None => @fonts.cjk_fallback()
  }
  let advances_pt : Array[Double] = Array::new(capacity=text.length())
  let fallback : Array[Bool] = Array::new(capacity=text.length())
  let mut i = 0
  while i < text.length() {
    let cp = codepoint_at(text, i)
    let pair = cp > 0xFFFF
    let (advance, used_fallback) = if face.has_char(cp) {
      (face.advance_pt(cp, size_pt), false)
    } else if cjk.has_char(cp) {
      (cjk.advance_pt(cp, size_pt), true)
    } else {
      (face.advance_pt(cp, size_pt), false)
    }
    advances_pt.push(advance)
    fallback.push(used_fallback)
    if pair {
      advances_pt.push(0)
      fallback.push(used_fallback)
      i += 2
    } else {
      i += 1
    }
  }
  { advances_pt, fallback }
}
