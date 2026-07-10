// A small scanner over retained chart XML. The reader keeps a chart's
// `c:chart` markup verbatim (there is no structured chart read-back), so the
// outline extracts just enough metadata for an agent to know what the chart
// is: its plot kinds and the cell ranges each series draws from.
//
// Scope: the scanner matches the conventional `c:` namespace prefix (what
// the library writes and what Office emits); a file bound to a different
// prefix yields empty metadata, never an error. Tags are matched with
// proper delimiters, comments are ignored, CDATA text participates as
// text, quoted attribute values may contain `>`, and `<c:f>` text is
// XML-entity-decoded.

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
  let cleaned = preprocess_chart_xml(xml)
  for tag in chart_kind_tags {
    if find_tag_open(cleaned[:], "c:" + tag, 0) is Some(_) {
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
  let cleaned = preprocess_chart_xml(xml)
  let view = cleaned[:]
  let tag = "c:ser"
  for from = 0 {
    let open_pos = match find_tag_open(view, tag, from) {
      Some(pos) => pos
      None => break
    }
    match tag_end(view, open_pos + tag.length() + 1) {
      // Unterminated opening tag: nothing scannable remains.
      None => break
      Some((content_start, self_closing)) => {
        if self_closing {
          // `<c:ser/>` is a valid, empty series — record it and keep
          // scanning; it must not swallow the series after it.
          series.push({ name: None, categories: None, values: None })
          continue content_start
        }
        let end = match find_tag_close(view, tag, content_start) {
          Some(close_pos) => close_pos
          // Unclosed block in malformed XML: scan to the end, then stop.
          None => view.length()
        }
        let block = view[content_start:end]
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
/// The index just past the `>` that ends an opening tag whose name ends at
/// `from`, plus whether the tag is self-closing. Quoted attribute values
/// may contain `>` or `/` without ending the tag. `None` when the tag is
/// never closed.
fn tag_end(view : StringView, from : Int) -> (Int, Bool)? {
  let mut quote : Int = 0
  let mut prev_slash = false
  for i in from..<view.length() {
    let c = view[i].to_int()
    if quote != 0 {
      if c == quote {
        quote = 0
      }
    } else if c == '"'.to_int() || c == '\''.to_int() {
      quote = c
      prev_slash = false
    } else if c == '>'.to_int() {
      return Some((i + 1, prev_slash))
    } else {
      prev_slash = c == '/'.to_int()
    }
  }
  None
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
  match tag_end(view, open_pos + tag.length() + 1) {
    None => None
    Some((_, true)) => None
    Some((content_start, false)) =>
      match find_tag_close(view, tag, content_start) {
        Some(close_pos) => Some((content_start, close_pos))
        None => None
      }
  }
}

///|
/// Strips XML comments and unwraps CDATA sections (re-escaping their text
/// so it participates as ordinary character data). This keeps the tag
/// scanner honest: markup inside a comment or CDATA block is data, not
/// structure. Unterminated constructs consume the rest of the input.
fn preprocess_chart_xml(xml : String) -> String {
  if !xml.contains("<!--") && !xml.contains("<![CDATA[") {
    return xml
  }
  let view = xml[:]
  let out = StringBuilder()
  for pos = 0 {
    if pos >= view.length() {
      break
    }
    let rest = view[pos:]
    let comment = rest.find("<!--")
    let cdata = rest.find("<![CDATA[")
    let (offset, is_comment) = match (comment, cdata) {
      (None, None) => {
        out.write_string(rest.to_owned())
        break
      }
      (Some(c), None) => (c, true)
      (None, Some(d)) => (d, false)
      (Some(c), Some(d)) => if c < d { (c, true) } else { (d, false) }
    }
    out.write_string(view[pos:pos + offset].to_owned())
    if is_comment {
      let body_start = pos + offset + "<!--".length()
      match view[body_start:].find("-->") {
        Some(close) => continue body_start + close + "-->".length()
        None => break
      }
    } else {
      let body_start = pos + offset + "<![CDATA[".length()
      match view[body_start:].find("]]>") {
        Some(close) => {
          write_xml_escaped(out, view[body_start:body_start + close])
          continue body_start + close + "]]>".length()
        }
        None => {
          write_xml_escaped(out, view[body_start:])
          break
        }
      }
    }
  }
  out.to_string()
}

///|
/// Writes `text` with `&`, `<`, and `>` escaped, in surrogate-safe chunks.
fn write_xml_escaped(out : StringBuilder, text : StringView) -> Unit {
  let mut start = 0
  for i in 0..<text.length() {
    let replacement = match text[i] {
      '&' => "&amp;"
      '<' => "&lt;"
      '>' => "&gt;"
      _ => continue
    }
    out.write_string(text[start:i].to_owned())
    out.write_string(replacement)
    start = i + 1
  }
  out.write_string(text[start:].to_owned())
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
  if digits.length() == 0 {
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
    // Beyond the Unicode range: reject early, which also makes arbitrary
    // zero-padding safe from overflow.
    if code > 0x10FFFF {
      return None
    }
  }
  code.to_char()
}
