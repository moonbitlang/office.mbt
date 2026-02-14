///|
pub(all) struct RichTextFont {
  bold : Bool
  italic : Bool
  strike : Bool
  outline : Bool
  shadow : Bool
  condense : Bool
  extend : Bool
  underline : String?
  size : Double?
  color : String?
  color_theme : Int?
  color_indexed : Int?
  color_tint : Double?
  charset : Int?
  family_number : Int?
  scheme : String?
  vert_align : String?
  family : String?
} derive(Show)

///|
pub(all) struct RichTextRun {
  text : String
  font : RichTextFont?
} derive(Show)

///|
let max_cell_chars = 32767

///|
fn count_utf16_units(text : StringView) -> Int {
  let mut count = 0
  for c in text {
    let units = if c.to_int() > 0xffff { 2 } else { 1 }
    count = count + units
  }
  count
}

///|
fn truncate_utf16_units(text : StringView, limit : Int) -> String {
  if limit <= 0 {
    return ""
  }
  let sb = StringBuilder::new()
  let mut count = 0
  for c in text {
    let units = if c.to_int() > 0xffff { 2 } else { 1 }
    if count + units > limit {
      break
    }
    sb.write_char(c)
    count = count + units
  }
  sb.to_string()
}

///|
fn rich_text_plain_text(runs : ArrayView[RichTextRun]) -> String {
  let sb = StringBuilder::new()
  for run in runs {
    sb.write_view(run.text)
  }
  sb.to_string()
}

///|
fn rich_text_total_units(runs : ArrayView[RichTextRun]) -> Int {
  let mut total = 0
  for run in runs {
    total = total + count_utf16_units(run.text)
  }
  total
}

///|
fn rich_text_truncate_runs(
  runs : ArrayView[RichTextRun],
  limit : Int,
) -> Array[RichTextRun] {
  let truncated : Array[RichTextRun] = []
  let mut remaining = limit
  for run in runs {
    if remaining <= 0 {
      break
    }
    let units = count_utf16_units(run.text)
    if units <= remaining {
      truncated.push(run)
      remaining = remaining - units
    } else {
      let text = truncate_utf16_units(run.text, remaining)
      truncated.push({ text, font: run.font })
      break
    }
  }
  truncated
}
