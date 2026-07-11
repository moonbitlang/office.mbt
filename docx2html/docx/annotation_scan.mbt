// Phase-2 J1: the raw-byte story scanner. The XML tree the reader builds
// retains no source offsets, so annotation positions (and, later, L0's
// byte-span surgery) come from scanning each story part's ORIGINAL bytes:
// a namespace-aware tokenizer walks the markup, mirrors the projection
// counting the path grammar uses (p/r/tbl/tr/tc/hyperlink ordinals among
// same-kind direct siblings), records each projection node's byte span
// and sequence interval, and locates annotation markers. J1 uses it
// read-only; L0 builds mutation on the same foundation.
//
// Deliberate limits (revisited at L0's go/no-go gate): DOCTYPE subsets
// are skipped naively (stories don't carry them); XML entities inside
// attribute VALUES are not decoded (annotation ids are NMTOKEN-ish;
// a `&#49;`-spelled id would mismatch — tolerated, ids are compared as
// spelled); only UTF-8 parts are scanned (UTF-16 parts raise).

///|
/// Transitional and Strict WML namespace URIs — the reader supports both.
fn is_wml_uri(uri : String) -> Bool {
  uri == "http://schemas.openxmlformats.org/wordprocessingml/2006/main" ||
  uri == "http://purl.oclc.org/ooxml/wordprocessingml/main"
}

///|
/// A marker the scanner can locate.
pub enum ScanMarkerKind {
  CommentStart
  CommentEnd
  CommentRef
  FootnoteRef
  EndnoteRef
} derive(Eq)

///|
pub impl Show for ScanMarkerKind with fn output(self, logger) {
  logger.write_string(
    match self {
      CommentStart => "commentRangeStart"
      CommentEnd => "commentRangeEnd"
      CommentRef => "commentReference"
      FootnoteRef => "footnoteReference"
      EndnoteRef => "endnoteReference"
    },
  )
}

///|
/// One located marker. `seq` is a total document order shared with node
/// intervals; `container_path` is the innermost open projection node
/// ("p[2]/r[1]", story-relative) or None at story level; `after_child`
/// is the last projection child closed inside that container before the
/// marker (for before/after boundary rendering).
pub struct ScannedMarker {
  kind : ScanMarkerKind
  id : String
  seq : Int
  container_path : String?
  after_child : String?
}

///|
/// The marker kind.
pub fn ScannedMarker::kind(self : ScannedMarker) -> ScanMarkerKind {
  self.kind
}

///|
/// The marker's w:id, as spelled.
pub fn ScannedMarker::id(self : ScannedMarker) -> String {
  self.id
}

///|
/// Position in the story's total document order.
pub fn ScannedMarker::seq(self : ScannedMarker) -> Int {
  self.seq
}

///|
/// The innermost open projection node, or None at story level.
pub fn ScannedMarker::container_path(self : ScannedMarker) -> String? {
  self.container_path
}

///|
/// The last projection child closed inside the container before this marker.
pub fn ScannedMarker::after_child(self : ScannedMarker) -> String? {
  self.after_child
}

///|
/// One projection node's identity and extent: path ("p[3]" or
/// "tbl[1]/tr[2]/tc[1]/p[1]", story-relative), the projection kind,
/// [open_seq, close_seq] for coverage arithmetic, and the byte span of
/// the whole element in the original part (open tag start .. close tag
/// end, exclusive) for L0.
pub struct ScannedNode {
  path : String
  kind : String
  open_seq : Int
  close_seq : Int
  byte_start : Int
  byte_end : Int
}

///|
/// The story-relative projection path ("p[3]", "tbl[1]/tr[1]/tc[1]").
pub fn ScannedNode::path(self : ScannedNode) -> String {
  self.path
}

///|
/// The projection kind (p, r, tbl, tr, tc, hyperlink).
pub fn ScannedNode::kind(self : ScannedNode) -> String {
  self.kind
}

///|
/// Sequence number of the node's open tag.
pub fn ScannedNode::open_seq(self : ScannedNode) -> Int {
  self.open_seq
}

///|
/// Sequence number of the node's close tag.
pub fn ScannedNode::close_seq(self : ScannedNode) -> Int {
  self.close_seq
}

///|
/// Byte offset of the open tag in the original part.
pub fn ScannedNode::byte_start(self : ScannedNode) -> Int {
  self.byte_start
}

///|
/// Byte offset just past the close tag in the original part.
pub fn ScannedNode::byte_end(self : ScannedNode) -> Int {
  self.byte_end
}

///|
/// Scanner output for one story part: nodes in OPEN order, markers in
/// document order, and non-fatal diagnostics.
pub struct StoryScan {
  nodes : Array[ScannedNode]
  markers : Array[ScannedMarker]
  warnings : Array[String]
}

///|
/// Projection nodes, in open order.
pub fn StoryScan::nodes(self : StoryScan) -> Array[ScannedNode] {
  self.nodes
}

///|
/// Annotation markers, in document order.
pub fn StoryScan::markers(self : StoryScan) -> Array[ScannedMarker] {
  self.markers
}

///|
/// Non-fatal scan diagnostics.
pub fn StoryScan::warnings(self : StoryScan) -> Array[String] {
  self.warnings
}

///|
/// One open element during the walk.
priv struct ScanFrame {
  // Resolved local_name name (for the node's kind on close).
  local_name : String
  // Namespace prefixes THIS element declared (to pop on close).
  declared : Array[String]
  // Projection bookkeeping: Some(path) when this element is a projection
  // node; child ordinal counters per kind; last closed projection child.
  projection_path : String?
  counters : Map[String, Int]
  mut last_closed_child : String?
  open_seq : Int
  byte_start : Int
}

///|
fn projection_kind(uri : String, local_name : String) -> String? {
  if !is_wml_uri(uri) {
    return None
  }
  match local_name {
    "p" | "r" | "tbl" | "tr" | "tc" | "hyperlink" => Some(local_name)
    _ => None
  }
}

///|
fn marker_kind(uri : String, local_name : String) -> ScanMarkerKind? {
  if !is_wml_uri(uri) {
    return None
  }
  match local_name {
    "commentRangeStart" => Some(CommentStart)
    "commentRangeEnd" => Some(CommentEnd)
    "commentReference" => Some(CommentRef)
    "footnoteReference" => Some(FootnoteRef)
    "endnoteReference" => Some(EndnoteRef)
    _ => None
  }
}

///|
/// Scans one story part. `part` is the ORIGINAL part bytes (UTF-8).
pub fn scan_story(part : Bytes) -> StoryScan raise DocxError {
  // A UTF-16 BOM means byte-level markup scanning would be wrong.
  if part.length() >= 2 &&
    (
      (part[0] == 0xFF && part[1] == 0xFE) ||
      (part[0] == 0xFE && part[1] == 0xFF)
    ) {
    raise Unsupported(
      message="the annotation scanner supports UTF-8 story parts only (found a UTF-16 byte-order mark)",
    )
  }
  let nodes : Array[ScannedNode] = []
  let markers : Array[ScannedMarker] = []
  let warnings : Array[String] = []
  let frames : Array[ScanFrame] = []
  let root_counters : Map[String, Int] = Map([])
  // Prefix -> stack of URIs (innermost last). "" is the default namespace.
  let namespaces : Map[String, Array[String]] = Map([])
  let mut seq = 0
  let length = part.length()
  let mut index = 0
  fn resolve(prefix : String) -> String {
    match namespaces.get(prefix) {
      Some(stack) if stack.length() > 0 => stack[stack.length() - 1]
      _ => ""
    }
  }
  fn current_projection() -> ScanFrame? {
    for at = frames.length() - 1; at >= 0; at = at - 1 {
      if frames[at].projection_path is Some(_) {
        return Some(frames[at])
      }
    }
    None
  }
  fn skip_until(pattern : Bytes, from : Int) -> Int raise DocxError {
    let mut at = from
    while at + pattern.length() <= length {
      let mut matched = true
      for offset in 0..<pattern.length() {
        if part[at + offset] != pattern[offset] {
          matched = false
          break
        }
      }
      if matched {
        return at + pattern.length()
      }
      at += 1
    }
    raise Unsupported(
      message="the annotation scanner found an unterminated construct in a story part",
    )
  }
  while index < length {
    if part[index] != b'<' {
      index += 1
      continue
    }
    if index + 1 >= length {
      break
    }
    let next = part[index + 1]
    if next == b'?' {
      index = skip_until(b"?>", index + 2)
      continue
    }
    if next == b'!' {
      if index + 3 < length &&
        part[index + 2] == b'-' &&
        part[index + 3] == b'-' {
        index = skip_until(b"-->", index + 4)
      } else if index + 8 < length &&
        part[index + 2] == b'[' &&
        part[index + 3] == b'C' {
        index = skip_until(b"]]>", index + 9)
      } else {
        // DOCTYPE and friends: skip to the next '>' (stories don't carry
        // internal subsets; L0's gate revisits).
        index = skip_until(b">", index + 2)
      }
      continue
    }
    if next == b'/' {
      // Closing tag.
      let close_end = skip_until(b">", index + 2)
      match frames.pop() {
        Some(frame) => {
          seq += 1
          for prefix in frame.declared {
            match namespaces.get(prefix) {
              Some(stack) => {
                let _ = stack.pop()
              }
              None => ()
            }
          }
          finish_frame(frame, seq, close_end, nodes, frames)
        }
        None => warnings.push("annotation scanner: unbalanced closing tag")
      }
      index = close_end
      continue
    }
    // Opening (or empty) element.
    let (name, attributes, self_closing, tag_end) = scan_tag(
      part, index, length,
    )
    // Namespace declarations bind before resolving this element's name.
    let declared : Array[String] = []
    for pair in attributes {
      let (attr_name, attr_value) = pair
      let bound_prefix = if attr_name == "xmlns" {
        Some("")
      } else if attr_name.has_prefix("xmlns:") {
        Some(attr_name[6:].to_owned())
      } else {
        None
      }
      match bound_prefix {
        Some(prefix) => {
          match namespaces.get(prefix) {
            Some(stack) => stack.push(attr_value)
            None => namespaces[prefix] = [attr_value]
          }
          declared.push(prefix)
        }
        None => ()
      }
    }
    let (prefix, local_name) = match name.find(":") {
      Some(colon) => (name[0:colon].to_owned(), name[colon + 1:].to_owned())
      None => ("", name)
    }
    let uri = resolve(prefix)
    match marker_kind(uri, local_name) {
      Some(kind) => {
        // Markers are recorded whether self-closing or not (Word emits
        // them self-closing; a non-empty form still marks its position).
        seq += 1
        let id = attribute_value(attributes, "id", namespaces)
        let (container_path, after_child) = match current_projection() {
          Some(frame) => (frame.projection_path, frame.last_closed_child)
          // Story level: no container; ordering comes from seq, and J2's
          // before/after attachment uses the neighbouring node intervals.
          None => (None, None)
        }
        markers.push({
          kind,
          id: id.unwrap_or(""),
          seq,
          container_path,
          after_child,
        })
        if id is None {
          warnings.push(
            "annotation scanner: a \{kind} marker has no w:id attribute",
          )
        }
      }
      None => ()
    }
    seq += 1
    let projection = match projection_kind(uri, local_name) {
      Some(kind) => {
        // Real stories root at w:document/w:hdr/w:ftr (never a projection
        // kind), so a parent frame always exists for projection nodes;
        // root_counters only backs a degenerate projection-at-root part.
        let ordinal = bump_counter(
          match frames.last() {
            Some(parent) => parent.counters
            None => root_counters
          },
          kind,
        )
        let parent_path = match current_projection() {
          Some(frame) => frame.projection_path
          None => None
        }
        let path = match parent_path {
          Some(base) => "\{base}/\{kind}[\{ordinal}]"
          None => "\{kind}[\{ordinal}]"
        }
        Some(path)
      }
      None => None
    }
    if self_closing {
      // Open+close in place; only projection nodes matter for spans.
      seq += 1
      match projection {
        Some(path) => {
          let kind = local_name
          nodes.push({
            path,
            kind,
            open_seq: seq - 1,
            close_seq: seq,
            byte_start: index,
            byte_end: tag_end,
          })
          record_closed_child(frames, path)
        }
        None => ()
      }
      for prefix in declared {
        match namespaces.get(prefix) {
          Some(stack) => {
            let _ = stack.pop()
          }
          None => ()
        }
      }
    } else {
      frames.push({
        local_name,
        declared,
        projection_path: projection,
        counters: Map([]),
        last_closed_child: None,
        open_seq: seq,
        byte_start: index,
      })
    }
    index = tag_end
  }
  if frames.length() > 0 {
    warnings.push("annotation scanner: unbalanced open tags at end of part")
  }
  { nodes, markers, warnings }
}

///|
fn bump_counter(counters : Map[String, Int], kind : String) -> Int {
  let next = counters.get_or_default(kind, 0) + 1
  counters[kind] = next
  next
}

///|
fn record_closed_child(frames : Array[ScanFrame], path : String) -> Unit {
  match frames.last() {
    Some(parent) => parent.last_closed_child = Some(path)
    None => ()
  }
}

///|
fn finish_frame(
  frame : ScanFrame,
  close_seq : Int,
  byte_end : Int,
  nodes : Array[ScannedNode],
  frames : Array[ScanFrame],
) -> Unit {
  match frame.projection_path {
    Some(path) => {
      nodes.push({
        path,
        kind: frame.local_name,
        open_seq: frame.open_seq,
        close_seq,
        byte_start: frame.byte_start,
        byte_end,
      })
      record_closed_child(frames, path)
    }
    None => ()
  }
}

///|
/// Reads the qualified name and attributes of the tag opening at `start`
/// (which points at '<'). Returns (name, attributes, self_closing,
/// index-just-past '>').
fn scan_tag(
  part : Bytes,
  start : Int,
  length : Int,
) -> (String, Array[(String, String)], Bool, Int) raise DocxError {
  let mut at = start + 1
  let name_start = at
  while at < length && !is_name_end(part[at]) {
    at += 1
  }
  let name = ascii_slice(part, name_start, at)
  let attributes : Array[(String, String)] = []
  let mut self_closing = false
  while at < length {
    // Skip whitespace.
    while at < length && is_xml_space(part[at]) {
      at += 1
    }
    if at >= length {
      break
    }
    if part[at] == b'>' {
      at += 1
      return (name, attributes, self_closing, at)
    }
    if part[at] == b'/' {
      self_closing = true
      at += 1
      continue
    }
    // Attribute name.
    let attr_start = at
    while at < length &&
          part[at] != b'=' &&
          !is_xml_space(part[at]) &&
          part[at] != b'>' {
      at += 1
    }
    let attr_name = ascii_slice(part, attr_start, at)
    while at < length && is_xml_space(part[at]) {
      at += 1
    }
    if at >= length || part[at] != b'=' {
      // Valueless attribute (not well-formed XML; tolerate and continue).
      continue
    }
    at += 1
    while at < length && is_xml_space(part[at]) {
      at += 1
    }
    if at >= length || (part[at] != b'"' && part[at] != b'\'') {
      raise Unsupported(
        message="the annotation scanner found an unquoted attribute value",
      )
    }
    let quote = part[at]
    at += 1
    let value_start = at
    while at < length && part[at] != quote {
      at += 1
    }
    if at >= length {
      raise Unsupported(
        message="the annotation scanner found an unterminated attribute value",
      )
    }
    let value = @utf8.decode(part[value_start:at]) catch {
      _ =>
        raise Unsupported(
          message="the annotation scanner found a non-UTF-8 attribute value",
        )
    }
    attributes.push((attr_name, value))
    at += 1
  }
  raise Unsupported(message="the annotation scanner found an unterminated tag")
}

///|
fn is_xml_space(byte : Byte) -> Bool {
  byte == b' ' || byte == b'\t' || byte == b'\r' || byte == b'\n'
}

///|
fn is_name_end(byte : Byte) -> Bool {
  is_xml_space(byte) || byte == b'>' || byte == b'/'
}

///|
fn ascii_slice(part : Bytes, start : Int, end : Int) -> String {
  let builder = StringBuilder::new()
  for at in start..<end {
    builder.write_char(part[at].to_int().to_char().unwrap_or('?'))
  }
  builder.to_string()
}

///|
/// The marker's id attribute is namespace-qualified (`w:id`); accept any
/// prefix bound to the WML URI, or an unprefixed `id`.
fn attribute_value(
  attributes : Array[(String, String)],
  local_name : String,
  namespaces : Map[String, Array[String]],
) -> String? {
  for pair in attributes {
    let (name, value) = pair
    match name.find(":") {
      Some(colon) => {
        let prefix = name[0:colon].to_owned()
        let attr_local = name[colon + 1:].to_owned()
        if attr_local == local_name {
          match namespaces.get(prefix) {
            Some(stack) if stack.length() > 0 &&
              is_wml_uri(stack[stack.length() - 1]) => return Some(value)
            _ => ()
          }
        }
      }
      // Unprefixed attributes are in NO namespace (default xmlns does not
      // apply to attributes) — they never match a w: attribute.
      None => ()
    }
  }
  None
}
