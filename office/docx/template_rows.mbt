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
        _ =>
          match decode_numeric_entity(entity) {
            Some(decoded) => out.write_string(decoded)
            None => return None
          }
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
/// WML attributes admitted on ONE element (per-element expanded-name
/// discipline — codex #213 round 1: a global list let inert-but-alien
/// attribute placements clone through). rsid* provenance passes on any
/// admitted element; xml:space belongs to w:t alone.
fn row_wml_attr_allowed(element_local : String, attr_local : String) -> Bool {
  if attr_local.has_prefix("rsid") {
    return true
  }
  match element_local {
    "trHeight" => attr_local == "val" || attr_local == "hRule"
    "jc"
    | "cantSplit"
    | "tblHeader"
    | "cnfStyle"
    | "gridSpan"
    | "vAlign"
    | "pStyle"
    | "keepNext"
    | "keepLines"
    | "widowControl"
    | "noProof"
    | "b"
    | "bCs"
    | "i"
    | "iCs"
    | "strike"
    | "caps"
    | "smallCaps"
    | "vertAlign"
    | "sz"
    | "szCs"
    | "highlight"
    | "rStyle" => attr_local == "val"
    "u" => attr_local == "val" || attr_local == "color"
    "tcW" => attr_local == "w" || attr_local == "type"
    "shd" =>
      attr_local == "val" ||
      attr_local == "fill" ||
      attr_local == "color" ||
      attr_local == "themeColor" ||
      attr_local == "themeFill" ||
      attr_local == "themeTint" ||
      attr_local == "themeShade"
    "top"
    | "bottom"
    | "left"
    | "right"
    | "start"
    | "end"
    | "insideH"
    | "insideV" =>
      attr_local == "val" ||
      attr_local == "sz" ||
      attr_local == "space" ||
      attr_local == "color" ||
      attr_local == "themeColor" ||
      attr_local == "w" ||
      attr_local == "type"
    "spacing" =>
      attr_local == "before" ||
      attr_local == "beforeLines" ||
      attr_local == "after" ||
      attr_local == "afterLines" ||
      attr_local == "line" ||
      attr_local == "lineRule"
    "ind" =>
      attr_local == "left" ||
      attr_local == "leftChars" ||
      attr_local == "right" ||
      attr_local == "rightChars" ||
      attr_local == "firstLine" ||
      attr_local == "firstLineChars" ||
      attr_local == "hanging" ||
      attr_local == "hangingChars" ||
      attr_local == "start" ||
      attr_local == "end"
    "tab" =>
      attr_local == "val" || attr_local == "pos" || attr_local == "leader"
    "lang" =>
      attr_local == "val" || attr_local == "eastAsia" || attr_local == "bidi"
    "color" =>
      attr_local == "val" ||
      attr_local == "themeColor" ||
      attr_local == "themeTint" ||
      attr_local == "themeShade"
    "rFonts" =>
      attr_local == "ascii" ||
      attr_local == "hAnsi" ||
      attr_local == "eastAsia" ||
      attr_local == "cs" ||
      attr_local == "hint"
    "br" => attr_local == "type" || attr_local == "clear"
    _ => false
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
      if attr_ns == wml_ns && row_wml_attr_allowed(element_local, attr_local) {
        continue
      }
      if attr_ns == xml_builtin_ns &&
        attr_local == "space" &&
        element_local == "t" {
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
/// Prefix bindings in scope at `offset`: a depth walk over every tag
/// before it, pushing binding frames on opens and popping on closes, so
/// declarations on ANY ancestor (the document root, an enclosing
/// w:tbl, ...) reach the row (codex #213 round 1: a tbl-level binding
/// was refused as unbound). None when the structure resists the walk.
fn part_bindings_at(part : BytesView, offset : Int) -> Map[String, String]? {
  let frames : Array[Map[String, String]] = []
  let mut index = 0
  while index < offset && index < part.length() {
    if part[index] != b'<' {
      index += 1
      continue
    }
    if index + 1 >= part.length() {
      return None
    }
    let marker = part[index + 1]
    if marker == b'?' {
      while index + 1 < part.length() &&
            !(part[index] == b'?' && part[index + 1] == b'>') {
        index += 1
      }
      index += 2
      continue
    }
    if marker == b'!' {
      // comments and other declarations: skip atomically
      if index + 3 < part.length() &&
        part[index + 2] == b'-' &&
        part[index + 3] == b'-' {
        while index + 2 < part.length() &&
              !(part[index] == b'-' &&
              part[index + 1] == b'-' &&
              part[index + 2] == b'>') {
          index += 1
        }
        index += 3
        continue
      }
      while index < part.length() && part[index] != b'>' {
        index += 1
      }
      index += 1
      continue
    }
    if marker == b'/' {
      while index < part.length() && part[index] != b'>' {
        index += 1
      }
      index += 1
      if frames.length() > 0 {
        ignore(frames.pop())
      }
      continue
    }
    // open or self-closing tag
    let mut tag_end = index + 1
    let mut quoted = false
    let mut quote = b'"'
    while tag_end < part.length() {
      let byte = part[tag_end]
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
    if tag_end >= part.length() {
      return None
    }
    let self_closing = part[tag_end - 1] == b'/'
    // exclude the self-closing slash from attribute scanning
    let attr_limit = if self_closing { tag_end - 1 } else { tag_end }
    let bindings : Map[String, String] = {}
    let mut cursor = index + 1
    while cursor < attr_limit &&
          (row_byte_is_name(part[cursor]) || part[cursor] == b':') {
      cursor += 1
    }
    while cursor < attr_limit {
      while cursor < attr_limit && row_byte_is_space(part[cursor]) {
        cursor += 1
      }
      if cursor >= attr_limit {
        break
      }
      let attr_start = cursor
      while cursor < attr_limit &&
            (row_byte_is_name(part[cursor]) || part[cursor] == b':') {
        cursor += 1
      }
      guard cursor < attr_limit && part[cursor] == b'=' else { return None }
      guard row_ascii(part, attr_start, cursor) is Some(attr_name) else {
        return None
      }
      cursor += 1
      guard cursor < attr_limit &&
        (part[cursor] == b'"' || part[cursor] == b'\'') else {
        return None
      }
      let value_quote = part[cursor]
      cursor += 1
      let value_start = cursor
      while cursor < attr_limit && part[cursor] != value_quote {
        cursor += 1
      }
      guard cursor < attr_limit else { return None }
      if attr_name == "xmlns" {
        match row_attr_value(part, value_start, cursor) {
          Some(uri) => bindings[""] = uri
          None => return None
        }
      } else if attr_name.has_prefix("xmlns:") {
        match row_attr_value(part, value_start, cursor) {
          Some(uri) =>
            bindings[attr_name.substring(start="xmlns:".length())] = uri
          None => return None
        }
      }
      cursor += 1
    }
    if !self_closing {
      frames.push(bindings)
    }
    index = tag_end + 1
  }
  let flattened : Map[String, String] = {}
  for frame in frames {
    for prefix, uri in frame {
      flattened[prefix] = uri
    }
  }
  Some(flattened)
}

///|
/// The published outcome of one repeated row after a successful merge.
pub(all) struct DocxRegionOutcome {
  name : String
  /// The region as addressed ("/docx/body/tbl[1]/tr[2]").
  source_location : String
  records : Int
  replaced : Int
  escapes_applied : Int
} derive(Eq, @debug.Debug)

///|
/// Result of one strict document-level DOCX template transaction.
pub struct DocxTemplateDocumentResult {
  report : DocxTemplateReport
  regions : Array[DocxRegionOutcome]
  scalar_paragraphs_skipped : Int
  transaction : @transaction.TransactionReport
}

///|
/// Total clone bytes one merge may materialize before the splice layer
/// even sees them (its own aggregate accounting remains authoritative
/// once queued).
let docx_clone_byte_guard : Int = 8 * 1024 * 1024

///|
priv struct DocxRegionPlan {
  name : String
  source_location : String
  tr_path : String
  span_start : Int
  span_end : Int
  strip_spans : Array[(Int, Int)]
  paragraphs : Array[(String, Array[@document.DocumentElement])]
  records : Array[Map[String, @template.TemplateValue]]
}

///|
/// One local byte edit inside a row clone.
priv struct CloneEdit {
  start : Int
  end : Int
  replacement : Bytes
}

///|
/// A conservative upper bound (saturating, never wrapping Int) on the
/// bytes one row clone materializes: the whole row region plus, for each
/// run rewrite, the escaped replacement wrapper — the replacement never
/// shrinks the bound below the region, so this over-counts and cannot
/// under-report.
fn docx_clone_upper_bound(
  span_start : Int,
  span_end : Int,
  record_edits : Array[DocxRunEdit],
) -> Int {
  fn saturating_add(a : Int, b : Int) -> Int {
    if a > 0x3FFFFFFF - b {
      0x3FFFFFFF
    } else {
      a + b
    }
  }

  let mut bound = span_end - span_start
  for edit in record_edits {
    // "<w:t xml:space=\"preserve\">" + escaped + "</w:t>"; each source
    // char escapes to at most 6 bytes ("&quot;"), UTF-8 to at most 4
    let escaped_max = saturating_add(
      edit.final_text.code_units().length() * 6,
      48,
    )
    bound = saturating_add(bound, escaped_max)
  }
  bound
}

///|
/// Merges a full template data document (scalar values plus repeating
/// table-row regions) into a DOCX package. Regions resolve against the
/// BODY story only in v1; every clone passes the row-safety gate, run
/// rewrites ride the same unified-stream scan and byte-fidelity checks
/// as the scalar pass, paraId/textId strip from every clone, and the
/// scalar pass never touches a claimed row. With no regions this
/// behaves exactly like `transact_docx_template`.
pub async fn transact_docx_template_document(
  options : @transaction.TransactionOptions,
  data : @template.TemplateData,
  allow_missing~ : Bool,
) -> DocxTemplateDocumentResult {
  let collected : Ref[DocxTemplateReport?] = Ref::new(None)
  let outcomes : Ref[Array[DocxRegionOutcome]] = Ref::new([])
  let skipped : Ref[Int] = Ref::new(0)
  let report = transact_docx(options, session => {
    let state : DocxMergeState = {
      report: {
        placeholders_found: 0,
        replaced: 0,
        escapes_applied: 0,
        distinct_keys_used: 0,
        missing: [],
        unused: [],
        malformed: [],
        unsupported: [],
        locations: [],
        locations_truncated: false,
        missing_total: 0,
        malformed_total: 0,
        unsupported_total: 0,
        unused_total: 0,
        stories_scanned: [],
        changed: false,
      },
      values: data.values,
      used_keys: Set::new(),
      budget: Ref::new(docx_template_scan_budget),
      edits: [],
      checks: [],
      allow_missing,
    }
    fn refuse(location : String, detail : String) {
      state.report.unsupported_total += 1
      if state.report.unsupported.length() < docx_template_finding_limit {
        state.report.unsupported.push({ location, detail })
      }
    }

    let annotated = session.annotated()
    let result = annotated.result()
    guard result.document is Document(children~, ..) else {
      raise docx_failure(
        "office.docx.template_internal", "the reader returned a non-document root",
      )
    }
    let body_part = annotated.main_story_source().part()
    let body_paragraphs : Array[(String, Array[@document.DocumentElement])] = []
    docx_collect_paragraphs(children, "", body_paragraphs)
    // ---- region resolution and the row-safety gate (all read-only) ----
    let plans : Array[DocxRegionPlan] = []
    let claimed_paths : Set[String] = Set::new()
    for region in data.regions {
      let location = "region \"" + region.name + "\""
      guard region.address is TableRow(story~, table~, row~) else {
        refuse(
          location, "sheet-row addressing applies to XLSX merges; this file is DOCX",
        )
        continue
      }
      guard story is BodyStory else {
        refuse(
          location, "header and footer table rows are beyond v1 repetition support",
        )
        continue
      }
      let tr_path = "tbl[\{table}]/tr[\{row}]"
      if claimed_paths.contains(tr_path) {
        refuse(location, "another region already claims " + tr_path)
        continue
      }
      guard annotated.story_row_span("/body", tr_path) is Some(span) else {
        refuse(
          location,
          "the body carries no table row at /docx/body/" + tr_path,
        )
        continue
      }
      claimed_paths.add(tr_path)
      guard session.archive.get(body_part) is Some(part_bytes) else {
        refuse(location, "the body part bytes are unavailable")
        continue
      }
      let gate = row_safety_gate(
        part_bytes[span.byte_start():span.byte_end()],
        match part_bindings_at(part_bytes, span.byte_start()) {
          Some(bindings) => bindings
          None => {
            refuse(location, "the body namespace bindings resist parsing")
            continue
          }
        },
      )
      match gate.refusal {
        Some(reason) =>
          refuse("/docx/body/" + tr_path, "the row carries " + reason)
        None => {
          let row_paragraphs : Array[(String, Array[@document.DocumentElement])] = []
          for paragraph in body_paragraphs {
            let (path, paragraph_children) = paragraph
            if path.has_prefix(tr_path + "/") {
              row_paragraphs.push((path, paragraph_children))
            }
          }
          plans.push({
            name: region.name,
            source_location: "/docx/body/" + tr_path,
            tr_path,
            span_start: span.byte_start(),
            span_end: span.byte_end(),
            strip_spans: gate.strip_spans,
            paragraphs: row_paragraphs,
            records: region.records,
          })
        }
      }
    }
    // ---- scalar pass over every story, skipping claimed rows ----
    let stories : Array[(String, String, Array[@document.DocumentElement])] = [
      ("/body", body_part, children),
    ]
    for index, source in annotated.header_story_sources() {
      if index < result.headers.length() {
        stories.push(
          ("/header[\{index + 1}]", source.part(), result.headers[index].body),
        )
      }
    }
    for index, source in annotated.footer_story_sources() {
      if index < result.footers.length() {
        stories.push(
          ("/footer[\{index + 1}]", source.part(), result.footers[index].body),
        )
      }
    }
    for entry in stories {
      let (story, part, story_children) = entry
      state.report.stories_scanned.push(story)
      let paragraphs : Array[(String, Array[@document.DocumentElement])] = []
      if story == "/body" {
        for paragraph in body_paragraphs {
          paragraphs.push(paragraph)
        }
      } else {
        docx_collect_paragraphs(story_children, "", paragraphs)
      }
      for paragraph in paragraphs {
        let (path, paragraph_children) = paragraph
        if story == "/body" {
          let mut owned = false
          for tr_path in claimed_paths {
            if path.has_prefix(tr_path + "/") {
              owned = true
              break
            }
          }
          if owned {
            skipped.val += 1
            continue
          }
        }
        state.scan_paragraph(story, part, path, paragraph_children) catch {
          @template.TemplateScanBudgetExceeded(_) =>
            raise docx_failure(
              "office.docx.resource_limit", "template scan work exceeds the configured ceiling",
            )
          error => raise error
        }
      }
    }
    // ---- region scans: one pass per record so missing accounting is
    // record-ordinal and final texts are per clone ----
    let region_edits : Array[Array[Array[DocxRunEdit]]] = []
    let region_used : Array[Array[Set[String]]] = []
    let region_counters : Array[(Int, Int)] = []
    for plan in plans {
      let per_record : Array[Array[DocxRunEdit]] = []
      let per_record_used : Array[Set[String]] = []
      let mut region_replaced = 0
      let mut region_escapes = 0
      let malformed_before = state.report.malformed_total
      let mut aborted = false
      for record_index, record in plan.records {
        if aborted {
          break
        }
        let merged : Map[String, @template.TemplateValue] = {}
        for key, value in data.values {
          merged[key] = value
        }
        for key, value in record {
          merged[key] = value
        }
        // each record scan tracks its OWN used keys so per-record unused
        // is exact (a key consumed by another region must not mask this
        // record's unused key — codex #213 round 1)
        let record_used : Set[String] = Set::new()
        let record_state : DocxMergeState = {
          report: state.report,
          values: merged,
          used_keys: record_used,
          budget: state.budget,
          edits: [],
          checks: state.checks,
          allow_missing,
        }
        let replaced_before = state.report.replaced
        let escapes_before = state.report.escapes_applied
        let missing_before = state.report.missing_total
        let missing_list_before = state.report.missing.length()
        for paragraph in plan.paragraphs {
          let (path, paragraph_children) = paragraph
          record_state.scan_paragraph(
            "/body", body_part, path, paragraph_children,
          ) catch {
            @template.TemplateScanBudgetExceeded(_) =>
              raise docx_failure(
                "office.docx.resource_limit", "template scan work exceeds the configured ceiling",
              )
            error => raise error
          }
        }
        if state.report.malformed_total > malformed_before {
          // the template row itself is malformed: identical in every
          // record, so one scan's findings suffice
          aborted = true
          break
        }
        if record_index == 0 &&
          state.report.replaced == replaced_before &&
          state.report.escapes_applied == escapes_before &&
          state.report.missing_total == missing_before &&
          record_state.edits.length() == 0 {
          refuse(
            plan.source_location,
            "the template row carries no placeholder",
          )
          aborted = true
          break
        }
        // missing findings gain their record ordinal so a consumer can
        // tell WHICH clone lacks the key
        let mut finding = missing_list_before
        while finding < state.report.missing.length() {
          let entry = state.report.missing[finding]
          state.report.missing[finding] = {
            location: entry.location,
            detail: "record \{record_index}: " + entry.detail,
          }
          finding += 1
        }
        ignore(missing_before)
        region_replaced += state.report.replaced - replaced_before
        region_escapes += state.report.escapes_applied - escapes_before
        // union this record's used keys into the global set (drives
        // distinct_keys_used and the values-key unused pass)
        for key in record_used {
          state.used_keys.add(key)
        }
        per_record.push(record_state.edits)
        per_record_used.push(record_used)
      }
      region_edits.push(per_record)
      region_used.push(per_record_used)
      region_counters.push((region_replaced, region_escapes))
    }
    // record-key hygiene: keys a record carries that no placeholder in
    // its region consumes are unused findings with ordinals
    for plan_index, plan in plans {
      if plan_index >= region_edits.length() {
        continue
      }
      guard plan_index < region_used.length() else { continue }
      let used_per_record = region_used[plan_index]
      for record_index, record in plan.records {
        if record_index >= used_per_record.length() {
          continue
        }
        let record_used = used_per_record[record_index]
        for key, _ in record {
          if !record_used.contains(key) {
            state.report.unused_total += 1
            if state.report.unused.length() < docx_template_finding_limit {
              state.report.unused.push(
                "region " + plan.name + " record \{record_index}: " + key,
              )
            }
          }
        }
      }
    }
    state.flag_out_of_scope("footnotes", annotated.footnote_bodies())
    state.flag_out_of_scope("endnotes", annotated.endnote_bodies())
    state.flag_out_of_scope("comments", annotated.comment_bodies())
    for key, _ in data.values {
      if !state.used_keys.contains(key) {
        state.report.unused_total += 1
        if state.report.unused.length() < docx_template_finding_limit {
          state.report.unused.push(key)
        }
      }
    }
    state.report.distinct_keys_used = state.used_keys.size()
    docx_run_fidelity_pass(state, session, annotated)
    // ---- clone materialization (exact accounting BEFORE building) ----
    let replacements : Array[(Int, Int, Bytes)] = []
    let clean = state.report.malformed_total == 0 &&
      state.report.unsupported_total == 0 &&
      (state.report.missing_total == 0 || allow_missing)
    if clean && plans.length() > 0 {
      guard session.archive.get(body_part) is Some(part_bytes) else {
        raise docx_failure(
          "office.docx.template_internal", "the body part vanished mid-merge",
        )
      }
      fn saturating_add(a : Int, b : Int) -> Int {
        if a > 0x3FFFFFFF - b {
          0x3FFFFFFF
        } else {
          a + b
        }
      }

      // PRE-ALLOCATION bound: the final body part is at most its current
      // size plus every clone's upper bound (each region's row region is
      // itself replaced, so this over-counts). Check it against BOTH the
      // configured guard and the session's real splice materialization
      // allowance BEFORE building anything (codex #213 round 1: the
      // splice layer charges the whole edited part, so post-build clone
      // bytes alone under-counted). queue_plan stays authoritative.
      let mut replacement_bound = 0
      for plan_index, plan in plans {
        if plan_index >= region_edits.length() {
          continue
        }
        let per_record = region_edits[plan_index]
        if per_record.length() != plan.records.length() {
          continue
        }
        for record_edits in per_record {
          replacement_bound = saturating_add(
            replacement_bound,
            docx_clone_upper_bound(plan.span_start, plan.span_end, record_edits),
          )
        }
      }
      let part_size_bound = saturating_add(
        part_bytes.length(),
        replacement_bound,
      )
      let session_allowance = session.construction_byte_allowance()
      let allowance = if docx_clone_byte_guard < session_allowance {
        docx_clone_byte_guard
      } else {
        session_allowance
      }
      if replacement_bound > allowance || part_size_bound > allowance {
        refuse(
          "package",
          "the repeated rows would materialize more than the \{allowance}-byte ceiling",
        )
      }
      let planned : Array[(DocxRegionPlan, Array[Bytes])] = []
      if state.report.unsupported_total == 0 {
        for plan_index, plan in plans {
          if plan_index >= region_edits.length() {
            continue
          }
          let per_record = region_edits[plan_index]
          if per_record.length() != plan.records.length() {
            continue
          }
          let clones : Array[Bytes] = []
          let mut ok = true
          for record_edits in per_record {
            match
              docx_build_row_clone(
                part_bytes,
                plan.span_start,
                plan.span_end,
                plan.strip_spans,
                record_edits,
                annotated,
              ) {
              Some(clone) => clones.push(clone)
              None => {
                refuse(
                  plan.source_location,
                  "a clone edit fell outside the row region",
                )
                ok = false
                break
              }
            }
          }
          if ok {
            planned.push((plan, clones))
          }
        }
      }
      if state.report.unsupported_total == 0 {
        for entry in planned {
          let (plan, clones) = entry
          let builder = @buffer.new()
          for clone in clones {
            builder.write_bytes(clone)
          }
          replacements.push(
            (plan.span_start, plan.span_end, builder.contents()),
          )
        }
      }
    }
    // ---- emission ----
    let still_clean = state.report.malformed_total == 0 &&
      state.report.unsupported_total == 0 &&
      (state.report.missing_total == 0 || allow_missing)
    if still_clean {
      docx_emit_scalar_edits(state, session, annotated)
      for replacement in replacements {
        let (start, end, bytes) = replacement
        session.queue_span_edit(body_part, start~, end~, bytes)
        state.report.changed = true
      }
      let built : Array[DocxRegionOutcome] = []
      for plan_index, plan in plans {
        if plan_index >= region_counters.length() {
          continue
        }
        let (replaced, escapes) = region_counters[plan_index]
        built.push({
          name: plan.name,
          source_location: plan.source_location,
          records: plan.records.length(),
          replaced,
          escapes_applied: escapes,
        })
      }
      outcomes.val = built
    }
    collected.val = Some(state.report)
    if !still_clean {
      raise docx_failure(
        "office.docx.template_refused", "strict template findings refuse publication",
      )
    }
  }) catch {
    error =>
      match collected.val {
        Some(merge) if merge.malformed_total > 0 ||
          merge.unsupported_total > 0 ||
          (merge.missing_total > 0 && !allow_missing) =>
          raise DocxTemplateRefused(merge)
        _ => raise error
      }
  }
  guard collected.val is Some(merge) else {
    raise docx_failure(
      "office.docx.template_internal", "the merge produced no report",
    )
  }
  {
    report: merge,
    regions: outcomes.val,
    scalar_paragraphs_skipped: skipped.val,
    transaction: report,
  }
}

///|
/// Builds one filled clone of the row: the source bytes with the
/// record's run rewrites and the paraId/textId strips applied as one
/// ascending, non-overlapping local edit set. None when any edit falls
/// outside the region (a planner inconsistency, surfaced as a refusal).
fn docx_build_row_clone(
  part_bytes : BytesView,
  span_start : Int,
  span_end : Int,
  strip_spans : Array[(Int, Int)],
  record_edits : Array[DocxRunEdit],
  annotated : @word.DocxAnnotatedResult,
) -> Bytes? {
  let edits : Array[CloneEdit] = []
  for strip in strip_spans {
    let (start, end) = strip
    edits.push({ start, end, replacement: b"" })
  }
  for edit in record_edits {
    guard annotated.story_run_span(edit.story, edit.run_path) is Some(span) else {
      return None
    }
    if edit.final_text == "" {
      let start = span.byte_start() - span_start
      let end = span.byte_end() - span_start
      if start < 0 || end > span_end - span_start || start > end {
        return None
      }
      edits.push({ start, end, replacement: b"" })
      continue
    }
    guard (span.content_start(), span.close_tag_start())
      is (Some(content_start), Some(close_tag_start)) else {
      // a self-closing run cannot receive content; the fidelity pass
      // already judged it, and an empty final is handled above
      continue
    }
    let start = content_start - span_start
    let end = close_tag_start - span_start
    if start < 0 || end > span_end - span_start || start > end {
      return None
    }
    let replacement = "<w:t xml:space=\"preserve\">" +
      docx_escape_text(edit.final_text) +
      "</w:t>"
    edits.push({ start, end, replacement: @utf8.encode(replacement) })
  }
  edits.sort_by((a, b) => a.start - b.start)
  let mut previous_end = 0
  for edit in edits {
    if edit.start < previous_end {
      return None
    }
    previous_end = edit.end
  }
  let row = part_bytes[span_start:span_end]
  let builder = @buffer.new()
  let mut cursor = 0
  for edit in edits {
    builder.write_bytesview(row[cursor:edit.start])
    builder.write_bytes(edit.replacement)
    cursor = edit.end
  }
  builder.write_bytesview(row[cursor:])
  Some(builder.contents())
}
