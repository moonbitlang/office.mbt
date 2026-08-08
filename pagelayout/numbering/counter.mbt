///|
// Counter state and label formatting. A list's numbers depend on every
// numbered paragraph before it, so this is a small state machine the
// document walk drives in order: `advance` bumps one level, resets the
// deeper ones, and returns the label to print.

///|
fn to_roman(value : Int, upper : Bool) -> String {
  if value <= 0 {
    // Word prints nothing sensible below 1; keep the digits visible
    return value.to_string()
  }
  let numerals = [
    (1000, "m"),
    (900, "cm"),
    (500, "d"),
    (400, "cd"),
    (100, "c"),
    (90, "xc"),
    (50, "l"),
    (40, "xl"),
    (10, "x"),
    (9, "ix"),
    (5, "v"),
    (4, "iv"),
    (1, "i"),
  ]
  let sb = StringBuilder()
  let mut left = value
  for pair in numerals {
    let (amount, glyph) = pair
    while left >= amount {
      sb.write_string(glyph)
      left -= amount
    }
  }
  let text = sb.to_string()
  if upper {
    text.to_upper()
  } else {
    text
  }
}

///|
/// Word's spreadsheet-style letters: 1→a … 26→z, 27→aa, 28→ab.
fn to_letters(value : Int, upper : Bool) -> String {
  if value <= 0 {
    return value.to_string()
  }
  // OOXML repeats the letter rather than carrying: 27 is "aa", 53 "aaa"
  let index = (value - 1) % 26
  let repeat = (value - 1) / 26 + 1
  let alphabet = if upper {
    "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
  } else {
    "abcdefghijklmnopqrstuvwxyz"
  }
  let letter = alphabet.get_char(index).unwrap()
  let sb = StringBuilder()
  for _ in 0..<repeat {
    sb.write_char(letter)
  }
  sb.to_string()
}

///|
/// Render one counter in `format`.
pub fn format_counter(value : Int, format : NumberFormat) -> String {
  match format {
    Decimal => value.to_string()
    LowerLetter => to_letters(value, false)
    UpperLetter => to_letters(value, true)
    LowerRoman => to_roman(value, false)
    UpperRoman => to_roman(value, true)
    // a bullet's glyph comes from lvlText, not from the counter
    Bullet | NoNumber => ""
  }
}

///|
/// Counter state for one document: current value per (numId, depth).
pub struct Counters {
  values : Map[String, Int]
  /// Levels that have been started, so a first use takes `w:start`.
  started : Map[String, Unit]
}

///|
/// Fresh counters: every level starts unused.
pub fn Counters::new() -> Counters {
  { values: Map([]), started: Map([]) }
}

///|
fn key(num_id : Int, depth : Int) -> String {
  "\{num_id}|\{depth}"
}

///|
/// Substitute `%1..%9` in a level's `lvlText` with the counters of
/// levels 0..8. `is_legal` renders every substituted level as decimal,
/// which is what `w:isLgl` means.
fn expand(
  text : String,
  counters : Array[Int],
  formats : Array[NumberFormat],
  is_legal : Bool,
) -> String {
  let sb = StringBuilder()
  let mut i = 0
  while i < text.length() {
    let c = text[i].to_int()
    if c == '%'.to_int() && i + 1 < text.length() {
      let digit = text[i + 1].to_int() - 0x30
      if digit >= 1 && digit <= 9 {
        let depth = digit - 1
        if depth < counters.length() {
          let format = if is_legal {
            Decimal
          } else if depth < formats.length() {
            formats[depth]
          } else {
            Decimal
          }
          sb.write_string(format_counter(counters[depth], format))
        }
        i += 2
        continue
      }
    }
    sb.write_char(text.get_char(i).unwrap())
    i += 1
  }
  sb.to_string()
}

///|
/// Advance the counter for `(num_id, depth)` and return the label to
/// print, or None when the level shows no label (`w:numFmt="none"`).
///
/// Deeper levels reset, so a new top-level item restarts its sublists —
/// unless the level's `w:lvlRestart` says otherwise, or is 0 (never
/// restart). `w:startOverride` forces the level to its override value the
/// first time it is used.
pub fn Counters::advance(
  self : Counters,
  numbering : Numbering,
  num_id : Int,
  depth : Int,
) -> String? {
  let depth = if depth < 0 { 0 } else if depth > 8 { 8 } else { depth }
  let level = numbering.level(num_id, depth)
  let self_key = key(num_id, depth)
  // 1. bump this level
  let start = match numbering.start_override(num_id, depth) {
    Some(v) => v
    None => level.start
  }
  let next = if self.started.contains(self_key) {
    self.values.get(self_key).unwrap_or(start) + 1
  } else {
    self.started[self_key] = ()
    start
  }
  self.values[self_key] = next

  // 2. reset deeper levels whose lvlRestart allows it
  for deeper in (depth + 1)..<9 {
    let deeper_key = key(num_id, deeper)
    if !self.started.contains(deeper_key) {
      continue
    }
    let deeper_level = numbering.level(num_id, deeper)
    let restarts = match deeper_level.restart {
      // 0 means never restart
      Some(0) => false
      // restart only when a level at least this shallow advances
      Some(n) => depth + 1 <= n
      None => true
    }
    if restarts {
      self.started.remove(deeper_key)
      self.values.remove(deeper_key)
    }
  }

  // 3. build the label from every level up to this one
  if level.format is NoNumber {
    return None
  }
  if level.format is Bullet {
    return Some(level.text)
  }
  let counters : Array[Int] = []
  let formats : Array[NumberFormat] = []
  for d = 0; d <= depth; d = d + 1 {
    let d_level = numbering.level(num_id, d)
    let d_key = key(num_id, d)
    let value = match self.values.get(d_key) {
      Some(v) => v
      // a level never used yet still contributes its start value, which
      // is how "1.1" reads when only the sublevel has been numbered
      None => d_level.start
    }
    counters.push(value)
    formats.push(d_level.format)
  }
  Some(expand(level.text, counters, formats, level.is_legal))
}
