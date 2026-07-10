// A small scanner over retained chart XML. The reader keeps a chart's
// `c:chart` markup verbatim (there is no structured chart read-back), so the
// outline extracts just enough metadata for an agent to know what the chart
// is: its plot kinds and the cell ranges each series draws from.
//
// Scope: the scanner matches the conventional `c:` namespace prefix (what
// the library writes and what Office emits); a file bound to a different
// prefix yields empty metadata, never an error. Tags are matched with
// proper delimiters, so attributes, whitespace, and self-closing forms are
// handled; `<c:f>` text is XML-entity-decoded.

///|
/// The closed set of DrawingML plot-kind element names the scanner looks
/// for. One `c:plotArea` may hold several (a combo chart).
let chart_kind_tags : Array[String] = [
  "areaChart", "area3DChart", "barChart", "bar3DChart", "bubbleChart", "doughnutChart",
  "lineChart", "line3DChart", "ofPieChart", "pieChart", "pie3DChart", "radarChart",
  "scatterChart", "stockChart", "surfaceChart", "surface3DChart",
]

///|
/// Series metadata scanned from one `c:ser` block: the `c:f` cell-range
/// references of its name, categories, and values, when present.
pub struct ChartSeriesMeta {
  name : String?
  categories : String?
  values : String?
} derive(Eq, @debug.Debug)

///|
/// The plot-kind element names present in the chart XML (e.g. `barChart`),
/// in `chart_kind_tags` order, each at most once.
pub fn chart_kinds(xml : String) -> Array[String] {
  let kinds = []
  for tag in chart_kind_tags {
    if find_tag_open(xml[:], "c:" + tag, 0) is Some(_) {
      kinds.push(tag)
    }
  }
  kinds
}

///|
/// The per-series range references scanned from every `c:ser` block, in
/// document order. Category/value roles follow the classic chart layout
/// (`c:cat`/`c:val`); scatter and bubble charts use `c:xVal`/`c:yVal`,
/// which map to categories/values respectively.
pub fn chart_series(xml : String) -> Array[ChartSeriesMeta] {
  let series : Array[ChartSeriesMeta] = []
  let view = xml[:]
  for from = 0 {
    match element_content(view, "c:ser", from) {
      None => break
      Some((start, end)) => {
        let block = view[start:end]
        series.push({
          name: element_ref(block, "c:tx"),
          categories: first_present(block, "c:cat", "c:xVal"),
          values: first_present(block, "c:val", "c:yVal"),
        })
        continue end
      }
    }
  }
  series
}

///|
/// Whether `c` may directly follow a tag name inside its markup: `>`,
/// whitespace (attributes follow), or `/` (self-closing).
fn is_tag_delimiter(c : UInt16) -> Bool {
  c is ('>' | ' ' | '\t' | '\r' | '\n' | '/')
}

///|
/// Position of the next `<tag` occurrence at or after `from` whose tag name
/// ends at a proper delimiter (so `c:ser` does not match `<c:serAx`).
fn find_tag_open(view : StringView, tag : String, from : Int) -> Int? {
  let open = "<" + tag
  for pos = from {
    if pos >= view.length() {
      break None
    }
    match view[pos:].find(open[:]) {
      None => break None
      Some(offset) => {
        let start = pos + offset
        let after = start + open.length()
        if after >= view.length() || is_tag_delimiter(view[after]) {
          break Some(start)
        }
        continue start + 1
      }
    }
  }
}

///|
/// Position of the next `</tag` closing occurrence at or after `from`.
fn find_tag_close(view : StringView, tag : String, from : Int) -> Int? {
  find_tag_open(view, "/" + tag, from)
}

///|
/// The `(content_start, content_end)` of the first `<tag …>…</tag>` element
/// at or after `from`. `None` when the element is absent, self-closing, or
/// unclosed (malformed XML degrades to "no metadata", never an error).
fn element_content(view : StringView, tag : String, from : Int) -> (Int, Int)? {
  let open_pos = match find_tag_open(view, tag, from) {
    Some(pos) => pos
    None => return None
  }
  // Find the '>' that ends the opening tag; reject a self-closing `…/>`.
  let mut i = open_pos + tag.length() + 1
  while i < view.length() && view[i] != '>' {
    i += 1
  }
  if i >= view.length() || view[i - 1] == '/' {
    return None
  }
  let content_start = i + 1
  match find_tag_close(view, tag, content_start) {
    Some(close_pos) => Some((content_start, close_pos))
    None => None
  }
}

///|
/// The first of two element names that yields a `c:f` reference.
fn first_present(block : StringView, tag : String, alt : String) -> String? {
  match element_ref(block, tag) {
    Some(reference) => Some(reference)
    None => element_ref(block, alt)
  }
}

///|
/// The decoded text of the first `<c:f>…</c:f>` inside the first
/// `<tag>…</tag>` element of `block`, or `None` when either is absent or
/// empty.
fn element_ref(block : StringView, tag : String) -> String? {
  let (start, end) = match element_content(block, tag, 0) {
    Some(bounds) => bounds
    None => return None
  }
  let element = block[start:end]
  let (ref_start, ref_end) = match element_content(element, "c:f", 0) {
    Some(bounds) => bounds
    None => return None
  }
  let reference = unescape_xml(element[ref_start:ref_end])
  if reference == "" {
    None
  } else {
    Some(reference)
  }
}

///|
/// Decodes the XML character entities the chart writer emits (`&amp;`,
/// `&lt;`, `&gt;`, `&quot;`, `&apos;`) plus decimal/hex numeric references.
/// An unrecognized or unterminated `&…` sequence is kept verbatim.
fn unescape_xml(view : StringView) -> String {
  if !view.contains("&") {
    return view.to_owned()
  }
  let out = StringBuilder()
  for pos = 0 {
    if pos >= view.length() {
      break
    }
    let amp = match view[pos:].find("&") {
      // No more entities: copy the tail verbatim (chunk copies keep
      // surrogate pairs intact).
      None => {
        out.write_string(view[pos:].to_owned())
        break
      }
      Some(offset) => pos + offset
    }
    out.write_string(view[pos:amp].to_owned())
    match view[amp:].find(";") {
      // Unterminated entity: keep the rest verbatim.
      None => {
        out.write_string(view[amp:].to_owned())
        break
      }
      Some(semi_offset) => {
        match decode_entity(view[amp + 1:amp + semi_offset]) {
          Some(c) => out.write_char(c)
          None => out.write_string(view[amp:amp + semi_offset + 1].to_owned())
        }
        continue amp + semi_offset + 1
      }
    }
  }
  out.to_string()
}

///|
fn decode_entity(entity : StringView) -> Char? {
  match entity {
    "amp" => Some('&')
    "lt" => Some('<')
    "gt" => Some('>')
    "quot" => Some('"')
    "apos" => Some('\'')
    [.. "#x", .. hex] | [.. "#X", .. hex] => decode_char_code(hex, 16)
    ['#', .. digits] => decode_char_code(digits, 10)
    _ => None
  }
}

///|
fn decode_char_code(digits : StringView, base : Int) -> Char? {
  if digits.length() == 0 || digits.length() > 6 {
    return None
  }
  let mut code = 0
  for i in 0..<digits.length() {
    let c = digits[i].to_int()
    let digit = if c >= '0'.to_int() && c <= '9'.to_int() {
      c - '0'.to_int()
    } else if base == 16 && c >= 'a'.to_int() && c <= 'f'.to_int() {
      c - 'a'.to_int() + 10
    } else if base == 16 && c >= 'A'.to_int() && c <= 'F'.to_int() {
      c - 'A'.to_int() + 10
    } else {
      return None
    }
    code = code * base + digit
  }
  code.to_char()
}
