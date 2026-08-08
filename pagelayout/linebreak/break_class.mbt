///|
// Break-opportunity classification: Latin breaks after spaces and hyphens,
// CJK breaks between ideographs/kana/hangul subject to kinsoku rules
// (characters forbidden from starting or ending a line).

///|
/// Characters that must not START a line (closing punctuation, small kana,
/// prolonged-sound and iteration marks; both fullwidth and halfwidth forms).
let kinsoku_no_start : String = "、。，．：；！？）」』】〉》〕％’”ゝゞヽヾ々ーぁぃぅぇぉっゃゅょゎァィゥェォッャュョヮヵヶ・…‥,.;:!?)]}%›»"

///|
/// Characters that must not END a line (opening punctuation).
let kinsoku_no_end : String = "（「『【〈《〔‘“([{‹«"

///|
let no_start_set : Map[Int, Unit] = Map([])

///|
let no_end_set : Map[Int, Unit] = Map([])

///|
fn kinsoku_sets() -> (Map[Int, Unit], Map[Int, Unit]) {
  if no_start_set.is_empty() {
    for c in kinsoku_no_start {
      no_start_set[c.to_int()] = ()
    }
    for c in kinsoku_no_end {
      no_end_set[c.to_int()] = ()
    }
  }
  (no_start_set, no_end_set)
}

///|
/// Whether `codepoint` belongs to a script that permits breaking between
/// adjacent characters (CJK ideographs, kana, hangul, fullwidth forms).
pub fn is_cjk(codepoint : Int) -> Bool {
  (codepoint >= 0x2E80 && codepoint <= 0x9FFF) || // radicals … kana … han
  (codepoint >= 0xAC00 && codepoint <= 0xD7AF) || // hangul syllables
  (codepoint >= 0xF900 && codepoint <= 0xFAFF) || // compat ideographs
  (codepoint >= 0xFE30 && codepoint <= 0xFE4F) || // compat forms
  (codepoint >= 0xFF00 && codepoint <= 0xFFEF) || // full/half-width forms
  (codepoint >= 0x20000 && codepoint <= 0x3FFFF) // SIP/TIP ideographs
}

///|
fn is_space(code_unit : Int) -> Bool {
  code_unit == 0x20 || code_unit == 0x09
}

///|
/// The codepoint at UTF-16 index `i` (combining a surrogate pair when `i`
/// is its lead), or the raw code unit for an unpaired surrogate.
fn codepoint_at(text : String, i : Int) -> Int {
  let unit = text[i].to_int()
  if unit >= 0xD800 && unit <= 0xDBFF && i + 1 < text.length() {
    let low = text[i + 1].to_int()
    if low >= 0xDC00 && low <= 0xDFFF {
      return 0x10000 + ((unit - 0xD800) << 10) + (low - 0xDC00)
    }
  }
  unit
}

///|
/// The codepoint ENDING at UTF-16 index `i` inclusive (looking back across
/// a surrogate pair).
fn codepoint_before(text : String, i : Int) -> Int {
  let unit = text[i].to_int()
  if unit >= 0xDC00 && unit <= 0xDFFF && i > 0 {
    let high = text[i - 1].to_int()
    if high >= 0xD800 && high <= 0xDBFF {
      return 0x10000 + ((high - 0xD800) << 10) + (unit - 0xDC00)
    }
  }
  unit
}

///|
/// Whether the line may break between code units `i - 1` and `i`:
/// after a space, after a hyphen-minus, or at a CJK boundary — unless a
/// kinsoku rule forbids the surrounding characters from ending/starting a
/// line. Index 0 (and the trail half of a surrogate pair) never breaks.
pub fn can_break_at(text : String, i : Int) -> Bool {
  if i <= 0 || i >= text.length() {
    return false
  }
  let next_unit = text[i].to_int()
  // never split a surrogate pair
  if next_unit >= 0xDC00 && next_unit <= 0xDFFF {
    return false
  }
  let prev = codepoint_before(text, i - 1)
  let next = codepoint_at(text, i)
  let (no_start, no_end) = kinsoku_sets()
  if no_start.contains(next) || no_end.contains(prev) {
    return false
  }
  if is_space(prev) && !is_space(next) {
    return true
  }
  if prev == '-'.to_int() && next != '-'.to_int() && !is_space(next) {
    return true
  }
  is_cjk(prev) || is_cjk(next)
}
