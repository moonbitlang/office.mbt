///|
/// DOCX bounded row repetition (#207 R3), part 1: the row-safety gate.
/// Cloning a table row duplicates every id and anchor inside it, so the
/// gate is an expanded-name WHITELIST over the row's raw bytes — checked
/// per element and per attribute — that makes id duplication
/// unrepresentable instead of enumerating hazards. `{w14}paraId` and
/// `{w14}textId` are admitted but STRIPPED from clones (optional in the
/// schema; the D1 validator enforces global uniqueness when present);
/// everything outside the lists refuses. The tokenizer runs in BYTE
/// coordinates so strip spans compose directly with the scanner's run
/// spans; XML structural delimiters are ASCII, so multibyte content
/// passes through untouched inside values and text.

///|
let wml_ns : String = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"

///|
let w14_ns : String = "http://schemas.microsoft.com/office/word/2010/wordml"

///|
let xml_builtin_ns : String = "http://www.w3.org/XML/1998/namespace"

///|
/// One attribute token: expanded name plus the byte span of the WHOLE
/// token including its leading whitespace run (deleting the span leaves
/// well-formed remaining whitespace).
priv struct RowAttrToken {
  name : String
  token_start : Int
  token_end : Int
}

///|
/// The gate's outcome over one row region: spans to strip from every
/// clone (paraId/textId attribute tokens, ascending), or the first
/// refusal (byte offset + reason).
priv struct RowGateOutcome {
  strip_spans : Array[(Int, Int)]
  refusal : String?
}

///|
fn row_gate_refuse(reason : String) -> RowGateOutcome {
  { strip_spans: [], refusal: Some(reason) }
}

///|
fn row_byte_is_space(byte : Byte) -> Bool {
  byte == b' ' || byte == b'\t' || byte == b'\r' || byte == b'\n'
}

///|
fn row_byte_is_name(byte : Byte) -> Bool {
  (byte >= b'a' && byte <= b'z') ||
  (byte >= b'A' && byte <= b'Z') ||
  (byte >= b'0' && byte <= b'9') ||
  byte == b'_' ||
  byte == b'-' ||
  byte == b'.'
}

///|
/// ASCII slice to String; None when any byte is outside printable ASCII
/// (names and namespace URIs in OOXML are ASCII — anything else refuses
/// upstream).
fn row_ascii(bytes : BytesView, start : Int, end : Int) -> String? {
  let out = StringBuilder::new()
  for index in start..<end {
    let byte = bytes[index]
    if byte < 0x20 || byte > 0x7E {
      return None
    }
    out.write_char(byte.to_char())
  }
  Some(out.to_string())
}

///|
/// Decodes the five predefined entities inside an ASCII attribute value
/// (namespace URIs bound through entity spellings still resolve — the
/// round-4 plan note); None on anything unknown or non-ASCII.
fn row_attr_value(bytes : BytesView, start : Int, end : Int) -> String? {
  let out = StringBuilder::new()
  let mut index = start
  while index < end {
    let byte = bytes[index]
    if byte == b'&' {
      let mut semi = index
      while semi < end && bytes[semi] != b';' {
        semi += 1
      }
      if semi >= end {
        return None
      }
      guard row_ascii(bytes, index, semi + 1) is Some(entity) else {
        return None
      }
      match entity {
        "&amp;" => out.write_char('&')
        "&lt;" => out.write_char('<')
        "&gt;" => out.write_char('>')
        "&quot;" => out.write_char('"')
        "&apos;" => out.write_char('\'')
        _ => return None
      }
      index = semi + 1
      continue
    }
    if byte < 0x20 || byte > 0x7E {
      return None
    }
    out.write_char(byte.to_char())
    index += 1
  }
  Some(out.to_string())
}

///|
/// WML elements a repeatable row may contain, by local name (all in the
/// W namespace). Everything else — bookmarks, comment and note
/// constructs, proofErr range markers, drawings, pictures, fields,
/// content controls, vertical merges, nested tables, unknown
/// namespaces — refuses.
fn row_element_allowed(local : String) -> Bool {
  match local {
    "tr"
    | "trPr"
    | "trHeight"
    | "jc"
    | "cantSplit"
    | "tblHeader"
    | "cnfStyle"
    | "tblPrEx"
    | "tc"
    | "tcPr"
    | "tcW"
    | "gridSpan"
    | "shd"
    | "vAlign"
    | "tcBorders"
    | "tcMar"
    | "top"
    | "bottom"
    | "left"
    | "right"
    | "start"
    | "end"
    | "insideH"
    | "insideV"
    | "p"
    | "pPr"
    | "pStyle"
    | "spacing"
    | "ind"
    | "tabs"
    | "tab"
    | "keepNext"
    | "keepLines"
    | "widowControl"
    | "noProof"
    | "lang"
    | "r"
    | "rPr"
    | "t"
    | "br"
    | "b"
    | "bCs"
    | "i"
    | "iCs"
    | "u"
    | "strike"
    | "caps"
    | "smallCaps"
    | "vertAlign"
    | "sz"
    | "szCs"
    | "color"
    | "highlight"
    | "rFonts"
    | "rStyle" => true
    _ => false
  }
}

///|
/// WML attributes admitted anywhere inside the row (value-carrying
/// formatting attributes plus inert revision-save provenance). Keyed by
/// local name within the W namespace.
fn row_wml_attr_allowed(local : String) -> Bool {
  match local {
    "val"
    | "w"
    | "type"
    | "fill"
    | "color"
    | "themeColor"
    | "themeFill"
    | "themeTint"
    | "themeShade"
    | "ascii"
    | "hAnsi"
    | "eastAsia"
    | "cs"
    | "hint"
    | "sz"
    | "space"
    | "before"
    | "beforeLines"
    | "after"
    | "afterLines"
    | "line"
    | "lineRule"
    | "firstLine"
    | "firstLineChars"
    | "hangingChars"
    | "leftChars"
    | "rightChars"
    | "hanging"
    | "pos"
    | "leader"
    | "hRule"
    | "clear" => true
    _ => local.has_prefix("rsid")
  }
}

///|
/// Walks one row region and applies the gate. `bindings` seeds the
/// prefix -> namespace map from the part's ancestors (the document root
/// declares w/w14); same-tag xmlns declarations are applied BEFORE the
/// tag's own names resolve. Comments, CDATA, and processing
/// instructions refuse — the reader's canonical store does not produce
/// them inside rows, so encountering one means the region is not what
/// the gate understands.
fn row_safety_gate(
  row : BytesView,
  bindings : Map[String, String],
) -> RowGateOutcome {
  let strip_spans : Array[(Int, Int)] = []
  let frames : Array[Map[String, String]] = [bindings]
  fn resolve(prefix : String) -> String? {
    let mut index = frames.length() - 1
    while index >= 0 {
      match frames[index].get(prefix) {
        Some(uri) => return Some(uri)
        None => index -= 1
      }
    }
    if prefix == "xml" {
      Some(xml_builtin_ns)
    } else {
      None
    }
  }

  let mut index = 0
  while index < row.length() {
    if row[index] != b'<' {
      index += 1
      continue
    }
    if index + 1 >= row.length() {
      return row_gate_refuse("unterminated markup at the region edge")
    }
    let marker = row[index + 1]
    if marker == b'!' || marker == b'?' {
      return row_gate_refuse(
        "markup constructs the row gate does not model (comments, CDATA, processing instructions)",
      )
    }
    if marker == b'/' {
      // closing tag: pop the binding frame
      let mut close = index + 2
      while close < row.length() && row[close] != b'>' {
        close += 1
      }
      if close >= row.length() {
        return row_gate_refuse("unterminated closing tag")
      }
      if frames.length() > 1 {
        ignore(frames.pop())
      }
      index = close + 1
      continue
    }
    // open or self-closing tag: bounds first
    let mut tag_end = index + 1
    let mut quoted = false
    let mut quote = b'"'
    while tag_end < row.length() {
      let byte = row[tag_end]
      if quoted {
        if byte == quote {
          quoted = false
        }
      } else if byte == b'"' || byte == b'\'' {
        quoted = true
        quote = byte
      } else if byte == b'>' {
        break
      }
      tag_end += 1
    }
    if tag_end >= row.length() {
      return row_gate_refuse("unterminated start tag")
    }
    let self_closing = row[tag_end - 1] == b'/'
    let inner_end = if self_closing { tag_end - 1 } else { tag_end }
    // element name token
    let name_start = index + 1
    let mut name_end = name_start
    while name_end < inner_end &&
          (row_byte_is_name(row[name_end]) || row[name_end] == b':') {
      name_end += 1
    }
    guard row_ascii(row, name_start, name_end) is Some(raw_name) else {
      return row_gate_refuse("an element name outside ASCII")
    }
    // first pass: attribute tokens (with leading-whitespace ownership)
    // and same-tag namespace declarations
    let attrs : Array[(String, Int, Int, Int, Int)] = []
    // (raw name, token_start, token_end, value_start, value_end)
    let tag_bindings : Map[String, String] = {}
    let mut cursor = name_end
    while cursor < inner_end {
      let ws_start = cursor
      while cursor < inner_end && row_byte_is_space(row[cursor]) {
        cursor += 1
      }
      if cursor >= inner_end {
        break
      }
      if cursor == ws_start {
        return row_gate_refuse("attributes must be whitespace separated")
      }
      let attr_start = cursor
      while cursor < inner_end &&
            (row_byte_is_name(row[cursor]) || row[cursor] == b':') {
        cursor += 1
      }
      guard cursor < inner_end && row[cursor] == b'=' else {
        return row_gate_refuse("an attribute without a value")
      }
      guard row_ascii(row, attr_start, cursor) is Some(attr_name) else {
        return row_gate_refuse("an attribute name outside ASCII")
      }
      cursor += 1
      guard cursor < inner_end && (row[cursor] == b'"' || row[cursor] == b'\'') else {
        return row_gate_refuse("an unquoted attribute value")
      }
      let value_quote = row[cursor]
      cursor += 1
      let value_start = cursor
      while cursor < inner_end && row[cursor] != value_quote {
        cursor += 1
      }
      guard cursor < inner_end else {
        return row_gate_refuse("an unterminated attribute value")
      }
      let value_end = cursor
      cursor += 1
      attrs.push((attr_name, ws_start, cursor, value_start, value_end))
      if attr_name == "xmlns" || attr_name.has_prefix("xmlns:") {
        guard row_attr_value(row, value_start, value_end) is Some(uri) else {
          return row_gate_refuse("a namespace binding the gate cannot decode")
        }
        let prefix = if attr_name == "xmlns" {
          ""
        } else {
          attr_name.substring(start="xmlns:".length())
        }
        tag_bindings[prefix] = uri
      }
    }
    frames.push(tag_bindings)
    // resolve and judge the element
    let (element_prefix, element_local) = match raw_name.find(":") {
      Some(pos) =>
        (
          raw_name.substring(start=0, end=pos),
          raw_name.substring(start=pos + 1),
        )
      None => ("", raw_name)
    }
    let element_ns = match resolve(element_prefix) {
      Some(uri) => uri
      None =>
        if element_prefix == "" {
          ""
        } else {
          return row_gate_refuse("an element prefix with no namespace binding")
        }
    }
    if element_ns != wml_ns || !row_element_allowed(element_local) {
      return row_gate_refuse(
        "element {" +
        element_ns +
        "}" +
        element_local +
        " is outside the repeatable-row whitelist",
      )
    }
    // judge each attribute
    for attr in attrs {
      let (attr_name, token_start, token_end, _, _) = attr
      if attr_name == "xmlns" || attr_name.has_prefix("xmlns:") {
        continue
      }
      let (attr_prefix, attr_local) = match attr_name.find(":") {
        Some(pos) =>
          (
            attr_name.substring(start=0, end=pos),
            attr_name.substring(start=pos + 1),
          )
        None => ("", attr_name)
      }
      // default namespaces never apply to attributes
      let attr_ns = if attr_prefix == "" {
        ""
      } else {
        match resolve(attr_prefix) {
          Some(uri) => uri
          None =>
            return row_gate_refuse(
              "an attribute prefix with no namespace binding",
            )
        }
      }
      if attr_ns == w14_ns && (attr_local == "paraId" || attr_local == "textId") {
        strip_spans.push((token_start, token_end))
        continue
      }
      if attr_ns == wml_ns && row_wml_attr_allowed(attr_local) {
        continue
      }
      if attr_ns == xml_builtin_ns && attr_local == "space" {
        continue
      }
      return row_gate_refuse(
        "attribute {" +
        attr_ns +
        "}" +
        attr_local +
        " is outside the repeatable-row whitelist",
      )
    }
    if self_closing {
      ignore(frames.pop())
    }
    index = tag_end + 1
  }
  strip_spans.sort_by((a, b) => a.0 - b.0)
  { strip_spans, refusal: None }
}

///|
/// Prefix bindings declared on the part's ROOT element, seeding the row
/// gate with the ancestor namespace context (document.xml binds w and
/// w14 at the root). None when the root tag itself resists parsing.
fn part_root_bindings(part : Bytes) -> Map[String, String]? {
  let view = part[:]
  let mut index = 0
  // skip the XML declaration and whitespace
  while index < view.length() {
    if view[index] == b'<' {
      if index + 1 < view.length() && view[index + 1] == b'?' {
        while index < view.length() && view[index] != b'>' {
          index += 1
        }
        index += 1
        continue
      }
      break
    }
    index += 1
  }
  guard index < view.length() && view[index] == b'<' else { return None }
  let mut tag_end = index + 1
  let mut quoted = false
  let mut quote = b'"'
  while tag_end < view.length() {
    let byte = view[tag_end]
    if quoted {
      if byte == quote {
        quoted = false
      }
    } else if byte == b'"' || byte == b'\'' {
      quoted = true
      quote = byte
    } else if byte == b'>' {
      break
    }
    tag_end += 1
  }
  guard tag_end < view.length() else { return None }
  let bindings : Map[String, String] = {}
  let mut cursor = index + 1
  // skip the element name
  while cursor < tag_end &&
        (row_byte_is_name(view[cursor]) || view[cursor] == b':') {
    cursor += 1
  }
  while cursor < tag_end {
    while cursor < tag_end && row_byte_is_space(view[cursor]) {
      cursor += 1
    }
    if cursor >= tag_end {
      break
    }
    let attr_start = cursor
    while cursor < tag_end &&
          (row_byte_is_name(view[cursor]) || view[cursor] == b':') {
      cursor += 1
    }
    guard cursor < tag_end && view[cursor] == b'=' else { return None }
    guard row_ascii(view, attr_start, cursor) is Some(attr_name) else {
      return None
    }
    cursor += 1
    guard cursor < tag_end && (view[cursor] == b'"' || view[cursor] == b'\'') else {
      return None
    }
    let value_quote = view[cursor]
    cursor += 1
    let value_start = cursor
    while cursor < tag_end && view[cursor] != value_quote {
      cursor += 1
    }
    guard cursor < tag_end else { return None }
    if attr_name == "xmlns" {
      match row_attr_value(view, value_start, cursor) {
        Some(uri) => bindings[""] = uri
        None => return None
      }
    } else if attr_name.has_prefix("xmlns:") {
      match row_attr_value(view, value_start, cursor) {
        Some(uri) =>
          bindings[attr_name.substring(start="xmlns:".length())] = uri
        None => return None
      }
    }
    cursor += 1
  }
  Some(bindings)
}
