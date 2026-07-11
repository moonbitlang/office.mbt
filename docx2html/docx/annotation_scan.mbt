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
// are skipped naively (stories don't carry them); attribute values ARE
// entity-decoded (predefined + numeric references); only UTF-8 parts
// are scanned (UTF-16 parts raise); legacy VML content is not modeled
// (the index's verification pass degrades positions inside it).

///|
/// Transitional and Strict WML namespace URIs — the reader supports both.
fn is_wml_uri(uri : String) -> Bool {
  uri == "http://schemas.openxmlformats.org/wordprocessingml/2006/main" ||
  uri == "http://purl.oclc.org/ooxml/wordprocessingml/main"
}

///|
/// A marker the scanner can locate.
priv enum ScanMarkerKind {
  CommentStart
  CommentEnd
  CommentRef
  FootnoteRef
  EndnoteRef
} derive(Eq)

///|
impl Show for ScanMarkerKind with fn output(self, logger) {
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
priv struct ScannedMarker {
  kind : ScanMarkerKind
  id : String
  seq : Int
  container_path : String?
  after_child : String?
}

///|
/// The marker kind.
fn ScannedMarker::kind(self : ScannedMarker) -> ScanMarkerKind {
  self.kind
}

///|
/// The marker's w:id, as spelled.
fn ScannedMarker::id(self : ScannedMarker) -> String {
  self.id
}

///|
/// Position in the story's total document order.
fn ScannedMarker::seq(self : ScannedMarker) -> Int {
  self.seq
}

///|
/// The innermost open projection node, or None at story level.
fn ScannedMarker::container_path(self : ScannedMarker) -> String? {
  self.container_path
}

///|
/// The last projection child closed inside the container before this marker.
fn ScannedMarker::after_child(self : ScannedMarker) -> String? {
  self.after_child
}

///|
/// One projection node's identity and extent: path ("p[3]" or
/// "tbl[1]/tr[2]/tc[1]/p[1]", story-relative), the projection kind,
/// [open_seq, close_seq] for coverage arithmetic, and the byte span of
/// the whole element in the original part (open tag start .. close tag
/// end, exclusive) for L0.
priv struct ScannedNode {
  path : String
  kind : String
  open_seq : Int
  close_seq : Int
  byte_start : Int
  byte_end : Int
}

///|
/// The story-relative projection path ("p[3]", "tbl[1]/tr[1]/tc[1]").
fn ScannedNode::path(self : ScannedNode) -> String {
  self.path
}

///|
/// Sequence number of the node's open tag.
fn ScannedNode::open_seq(self : ScannedNode) -> Int {
  self.open_seq
}

///|
/// Sequence number of the node's close tag.
fn ScannedNode::close_seq(self : ScannedNode) -> Int {
  self.close_seq
}

///|
/// Scanner output for one story part: nodes in CLOSE order (a node is
/// complete only at its close tag), markers in
/// document order, and non-fatal diagnostics.
priv struct StoryScan {
  nodes : Array[ScannedNode]
  markers : Array[ScannedMarker]
  warnings : Array[String]
}

///|
/// Projection nodes, in close order (see the struct doc).
fn StoryScan::nodes(self : StoryScan) -> Array[ScannedNode] {
  self.nodes
}

///|
/// Annotation markers, in document order.
fn StoryScan::markers(self : StoryScan) -> Array[ScannedMarker] {
  self.markers
}

///|
/// Non-fatal scan diagnostics.
fn StoryScan::warnings(self : StoryScan) -> Array[String] {
  self.warnings
}

///|
/// One open element during the walk.
priv struct ScanFrame {
  // Resolved local name (for the node's kind on close) + WML-ness.
  local_name : String
  is_wml : Bool
  // Namespace prefixes THIS element declared (to pop on close).
  declared : Array[String]
  // Projection bookkeeping: Some(path) when this element is a projection
  // node (kind = the PROJECTION kind, e.g. "note" for w:footnote — not
  // the local name); child ordinal counters; last closed child.
  mut projection_path : String?
  projection_kind : String?
  counters : Map[String, Int]
  mut last_closed_child : String?
  open_seq : Int
  byte_start : Int
  // TRANSPARENT containers (sdt/sdtContent/smartTag/ins) are flattened by
  // the reader: their children count in the nearest non-transparent
  // ancestor's counters, so projection ordinals mirror the parsed AST.
  transparent : Bool
  // SUPPRESSED subtrees (w:del content, plumbing notes) do not exist in
  // the parsed AST: nothing inside gets a projection path. Mutable for
  // vMerge retraction (tcPr precedes cell content, so flipping before
  // any child opens is safe).
  mut suppressed : Bool
  // Where this frame's own ordinal was bumped, for vMerge retraction.
  mut counter_owner : Map[String, Int]?
  // Property containers (tcPr/pPr/rPr/...): the reader never surfaces
  // markers from inside them.
  in_properties : Bool
  // Grid tracking mirroring the reader's calculate_typed_table_row_spans
  // EXACTLY: origins are keyed by a cell's STARTING column only; every
  // kept cell registers itself as the origin at its column; an unmatched
  // continuation becomes an origin (fail-open); origins are never
  // removed. tbl frames: the origin-column set. tr frames: the next
  // cell's column (plus trPr/w:del row deletion, like read_table_row).
  // tc frames: column/span (FIRST gridSpan via the reader's
  // parse_grid_span) and the FIRST vMerge declaration; keep-or-retract
  // decided at tcPr close.
  origin_columns : Set[Int]
  mut column_cursor : Int
  grid_column : Int
  mut grid_span : Int
  mut grid_span_seen : Bool
  mut vmerge_seen : Bool
  mut vmerge_continue : Bool
  mut row_deleted : Bool
  // The reader honors only the FIRST tcPr/trPr (first_or_empty): a tc/tr
  // frame records having seen one; a tcPr/trPr frame records whether it
  // IS that first one (declarations from later ones are ignored).
  mut properties_seen : Bool
  first_properties : Bool
  // Origin columns THIS row newly registered (absent before), so a
  // late-deleted row can roll back exactly its own contributions —
  // the reader excludes deleted rows BEFORE span calculation.
  registered_columns : Array[Int]
}

///|
fn is_property_container(uri : String, local_name : String) -> Bool {
  is_wml_uri(uri) &&
  local_name
  is ("tcPr" | "pPr" | "rPr" | "tblPr" | "trPr" | "sectPr" | "tblGrid")
}

///|
fn projection_kind(uri : String, local_name : String) -> String? {
  // DELIBERATE LIMIT (J1): image nodes are NOT projected. The reader
  // emits zero..many Images per drawing (blip resolution needs the
  // relationship graph) and wraps them in Hyperlink when a:hlinkClick is
  // present — faithful mirroring is L0-scope work. Consequences, pinned:
  // image-path coverage queries return empty, image byte spans arrive
  // with L0, and markers inside drawings resolve to their RUN (correct).
  if !is_wml_uri(uri) {
    return None
  }
  match local_name {
    "p" | "r" | "tbl" | "tr" | "tc" | "hyperlink" => Some(local_name)
    // Container identity inside the notes/comments stories (these
    // elements never occur in body/header/footer stories).
    "footnote" | "endnote" => Some("note")
    "comment" => Some("comment")
    _ => None
  }
}

///|
/// Containers the reader flattens into their parent flow.
fn is_transparent_container(uri : String, local_name : String) -> Bool {
  (
    is_wml_uri(uri) &&
    local_name
    is ("sdt" | "sdtContent" | "smartTag" | "ins" | "drawing" | "object")
  ) ||
  (uri == MC_URI && local_name is ("AlternateContent" | "Fallback"))
}

///|
const MC_URI : String = "http://schemas.openxmlformats.org/markup-compatibility/2006"

///|
fn is_wp_uri(uri : String) -> Bool {
  uri ==
  "http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" ||
  uri == "http://purl.oclc.org/ooxml/drawingml/wordprocessingDrawing"
}

///|
/// Subtrees the reader removes entirely.
fn is_suppressed_container(uri : String, local_name : String) -> Bool {
  (is_wml_uri(uri) && local_name == "del") ||
  (uri == MC_URI && local_name == "Choice")
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
fn scan_story(part : Bytes) -> StoryScan raise DocxError {
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
          // vMerge DECISION at tcPr close (declarations final, before any
          // cell content): reader-exact — a continuation whose STARTING
          // column has a registered origin is merged away (retracted);
          // an unmatched continuation is KEPT and becomes the origin.
          if frame.is_wml &&
            frame.local_name == "tcPr" &&
            frame.first_properties {
            match
              (
                nearest_frame_by_kind(frames, "tc"),
                nearest_frame_by_kind(frames, "tbl"),
              ) {
              (Some(cell), Some(table)) =>
                if cell.vmerge_continue &&
                  table.origin_columns.contains(cell.grid_column) {
                  retract_cell(cell, nodes, markers)
                }
              _ => ()
            }
          }
          // trPr/w:del deletes the whole row, reader-exact.
          if frame.is_wml &&
            frame.local_name == "trPr" &&
            frame.first_properties {
            match nearest_frame_by_kind(frames, "tr") {
              Some(row) =>
                if row.row_deleted {
                  retract_row(
                    row,
                    nearest_frame_by_kind(frames, "tbl"),
                    nodes,
                    markers,
                  )
                }
              None => ()
            }
          }
          // Close bookkeeping at tc close: EVERY kept cell registers as
          // the origin at its starting column (origins are never
          // removed — a later continuation merges into whatever cell is
          // above it, exactly like the reader); the row cursor advances
          // by the span (the reader's parse can yield zero or negative
          // spans, mirrored verbatim).
          if frame.is_wml && frame.local_name == "tc" {
            match
              (
                nearest_frame_by_kind(frames, "tr"),
                nearest_frame_by_kind(frames, "tbl"),
              ) {
              (Some(row), Some(table)) => {
                if !frame.suppressed &&
                  !table.origin_columns.contains(frame.grid_column) {
                  table.origin_columns.add(frame.grid_column)
                  row.registered_columns.push(frame.grid_column)
                }
                row.column_cursor = frame.grid_column + frame.grid_span
              }
              _ => ()
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
    seq += 1
    let transparent = is_transparent_container(uri, local_name)
    // A subtree is suppressed if the reader drops it: w:del content,
    // plumbing notes (separator/continuationSeparator/continuationNotice
    // never surface as user notes), or anything inside an already
    // suppressed ancestor.
    let inherited_suppression = match frames.last() {
      Some(parent) => parent.suppressed
      None => false
    }
    let plumbing_note = is_wml_uri(uri) &&
      local_name is ("footnote" | "endnote") &&
      attribute_value(attributes, "type", namespaces)
      is (Some("separator")
      | Some("continuationSeparator")
      | Some("continuationNotice"))
    let suppressed = inherited_suppression ||
      is_suppressed_container(uri, local_name) ||
      plumbing_note
    // Markers respect suppression: the reader drops w:del content,
    // mc:Choice branches, and plumbing notes wholesale — markers
    // included. (A parent's suppression may have been set after its
    // open — vMerge retraction — which this naturally observes.)
    let inside_properties = match frames.last() {
      Some(parent) => parent.in_properties
      None => false
    }
    if !suppressed && !inside_properties {
      match marker_kind(uri, local_name) {
        Some(kind) => {
          // Recorded whether self-closing or not (Word emits them
          // self-closing; a non-empty form still marks its position).
          seq += 1
          let id = attribute_value(attributes, "id", namespaces)
          let (container_path, after_child) = match current_projection() {
            Some(frame) => (frame.projection_path, frame.last_closed_child)
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
    }
    let mut counter_owner : Map[String, Int]? = None
    let mut projection_kind_value : String? = None
    let projection = if suppressed {
      None
    } else {
      match projection_kind(uri, local_name) {
        Some(kind) => {
          // Ordinals live on the nearest NON-transparent frame, mirroring
          // the reader's flattening; root_counters backs the degenerate
          // projection-at-root case.
          let counters = nearest_counters(frames, root_counters)
          let ordinal = bump_counter(counters, kind)
          counter_owner = Some(counters)
          projection_kind_value = Some(kind)
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
    }
    // Grid declarations, DIRECT tcPr children only, mirroring the
    // reader: FIRST vMerge wins (continue iff val absent or "continue");
    // FIRST gridSpan wins, parsed with the reader's own parse_grid_span.
    let parent_is = fn(name : String) -> Bool {
      match frames.last() {
        Some(parent) =>
          parent.is_wml && parent.local_name == name && parent.first_properties
        None => false
      }
    }
    if is_wml_uri(uri) && local_name == "vMerge" && parent_is("tcPr") {
      match nearest_frame_by_kind(frames, "tc") {
        Some(cell) =>
          if !cell.vmerge_seen {
            cell.vmerge_seen = true
            cell.vmerge_continue = attribute_value(
                attributes, "val", namespaces,
              )
              is (None | Some("continue"))
          }
        None =>
          warnings.push("annotation scanner: a vMerge outside any table cell")
      }
    }
    if is_wml_uri(uri) && local_name == "gridSpan" && parent_is("tcPr") {
      match nearest_frame_by_kind(frames, "tc") {
        Some(cell) =>
          if !cell.grid_span_seen {
            cell.grid_span_seen = true
            cell.grid_span = parse_grid_span(
              attribute_value(attributes, "val", namespaces).unwrap_or("1"),
            )
          }
        None => ()
      }
    }
    // trPr/w:del deletes the WHOLE ROW (reader's read_table_row).
    if is_wml_uri(uri) && local_name == "del" && parent_is("trPr") {
      match nearest_frame_by_kind(frames, "tr") {
        Some(row) => row.row_deleted = true
        None => ()
      }
    }
    if self_closing {
      // Open+close in place; only projection nodes matter for spans.
      seq += 1
      // A self-closing <w:tcPr/> or <w:trPr/> still claims FIRST-
      // properties status (the reader's first_or_empty picks it, so a
      // later framed tcPr/trPr must be ignored). Its own declarations
      // are vacuously empty and its close-decision is a no-op.
      if is_wml_uri(uri) && local_name is ("tcPr" | "trPr") {
        let owner_kind = if local_name == "tcPr" { "tc" } else { "tr" }
        match nearest_frame_by_kind(frames, owner_kind) {
          Some(owner) => owner.properties_seen = true
          None => ()
        }
      }
      // A self-closing <w:tc/> is a normal span-1 cell to the reader:
      // register its origin column and advance the row cursor.
      if projection_kind_value is Some("tc") {
        match
          (
            nearest_frame_by_kind(frames, "tr"),
            nearest_frame_by_kind(frames, "tbl"),
          ) {
          (Some(row), Some(table)) => {
            if !table.origin_columns.contains(row.column_cursor) {
              table.origin_columns.add(row.column_cursor)
              row.registered_columns.push(row.column_cursor)
            }
            row.column_cursor = row.column_cursor + 1
          }
          _ => ()
        }
      }
      match projection {
        Some(path) => {
          let kind = projection_kind_value.unwrap_or(local_name)
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
      let in_properties = is_property_container(uri, local_name) ||
        (match frames.last() {
          Some(parent) => parent.in_properties
          None => false
        })
      let grid_column = if projection_kind_value is Some("tc") {
        // Claim this cell's grid column from the enclosing row.
        match nearest_frame_by_kind(frames, "tr") {
          Some(row) => row.column_cursor
          None => -1
        }
      } else {
        -1
      }
      // Is THIS element the first tcPr/trPr of its cell/row?
      let first_properties = if is_wml_uri(uri) &&
        local_name is ("tcPr" | "trPr") {
        let owner_kind = if local_name == "tcPr" { "tc" } else { "tr" }
        match nearest_frame_by_kind(frames, owner_kind) {
          Some(owner) =>
            if owner.properties_seen {
              false
            } else {
              owner.properties_seen = true
              true
            }
          None => false
        }
      } else {
        false
      }
      frames.push({
        local_name,
        is_wml: is_wml_uri(uri),
        declared,
        projection_path: projection,
        projection_kind: projection_kind_value,
        counters: Map([]),
        last_closed_child: None,
        open_seq: seq,
        byte_start: index,
        transparent,
        suppressed,
        counter_owner,
        in_properties,
        origin_columns: Set([]),
        column_cursor: 0,
        grid_column,
        grid_span: 1,
        grid_span_seen: false,
        vmerge_seen: false,
        vmerge_continue: false,
        row_deleted: false,
        properties_seen: false,
        first_properties,
        registered_columns: [],
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
/// The counters of the nearest non-transparent open frame (the reader
/// flattens transparent containers into their parent flow).
fn nearest_counters(
  frames : Array[ScanFrame],
  root_counters : Map[String, Int],
) -> Map[String, Int] {
  for at = frames.length() - 1; at >= 0; at = at - 1 {
    if !frames[at].transparent {
      return frames[at].counters
    }
  }
  root_counters
}

///|
/// The innermost open frame whose PROJECTION kind matches.
fn nearest_frame_by_kind(
  frames : Array[ScanFrame],
  kind : String,
) -> ScanFrame? {
  for at = frames.length() - 1; at >= 0; at = at - 1 {
    if frames[at].projection_kind is Some(k) && k == kind {
      return Some(frames[at])
    }
    // Also match retracted cells (projection cleared but still the
    // structural tc frame).
    if frames[at].is_wml && frames[at].local_name == kind {
      return Some(frames[at])
    }
  }
  None
}

///|
/// Removes already-emitted nodes/markers from inside a retracted frame:
/// the reader drops the WHOLE subtree even when properties arrive after
/// content (tolerated malformed input), so anything recorded since the
/// frame opened must go.
fn purge_subtree(
  frame : ScanFrame,
  nodes : Array[ScannedNode],
  markers : Array[ScannedMarker],
) -> Unit {
  let kept_nodes : Array[ScannedNode] = []
  for node in nodes {
    if node.open_seq <= frame.open_seq {
      kept_nodes.push(node)
    }
  }
  if kept_nodes.length() != nodes.length() {
    nodes.clear()
    for node in kept_nodes {
      nodes.push(node)
    }
  }
  let kept_markers : Array[ScannedMarker] = []
  for marker in markers {
    if marker.seq <= frame.open_seq {
      kept_markers.push(marker)
    }
  }
  if kept_markers.length() != markers.length() {
    markers.clear()
    for marker in kept_markers {
      markers.push(marker)
    }
  }
}

///|
/// Retracts a deleted row (trPr/w:del): un-counts its ordinal and
/// suppresses the whole subtree, like the reader's read_table_row.
fn retract_row(
  row : ScanFrame,
  table : ScanFrame?,
  nodes : Array[ScannedNode],
  markers : Array[ScannedMarker],
) -> Unit {
  match (row.projection_path, row.counter_owner) {
    (Some(_), Some(counters)) => {
      let current = counters.get_or_default("tr", 0)
      if current > 0 {
        counters["tr"] = current - 1
      }
      row.projection_path = None
      row.counter_owner = None
      row.suppressed = true
      purge_subtree(row, nodes, markers)
      // Roll back exactly the origins this row's cells introduced —
      // the reader never lets a deleted row participate in merging.
      match table {
        Some(owner) =>
          for column in row.registered_columns {
            owner.origin_columns.remove(column)
          }
        None => ()
      }
      row.registered_columns.clear()
    }
    _ => ()
  }
}

///|
/// Retracts a continuation cell the reader strips: un-counts its
/// ordinal and suppresses the whole subtree.
fn retract_cell(
  cell : ScanFrame,
  nodes : Array[ScannedNode],
  markers : Array[ScannedMarker],
) -> Unit {
  match (cell.projection_path, cell.counter_owner) {
    (Some(_), Some(counters)) => {
      let current = counters.get_or_default("tc", 0)
      if current > 0 {
        counters["tc"] = current - 1
      }
      cell.projection_path = None
      cell.counter_owner = None
      cell.suppressed = true
      purge_subtree(cell, nodes, markers)
    }
    _ => ()
  }
}

///|
fn bump_counter(counters : Map[String, Int], kind : String) -> Int {
  let next = counters.get_or_default(kind, 0) + 1
  counters[kind] = next
  next
}

///|
fn record_closed_child(frames : Array[ScanFrame], path : String) -> Unit {
  // Boundary bookkeeping follows the FLATTENED structure too.
  for at = frames.length() - 1; at >= 0; at = at - 1 {
    if !frames[at].transparent {
      frames[at].last_closed_child = Some(path)
      return
    }
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
        kind: frame.projection_kind.unwrap_or(frame.local_name),
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
    let raw_value = @utf8.decode(part[value_start:at]) catch {
      _ =>
        raise Unsupported(
          message="the annotation scanner found a non-UTF-8 attribute value",
        )
    }
    // Attribute values must be entity-decoded: w:id="&#49;" IS id "1"
    // (and namespace URIs may legally carry &amp;).
    attributes.push((attr_name, decode_entities(raw_value)))
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
/// The marker's id attribute is namespace-qualified (`w:id`): any prefix
/// bound to a WML URI matches; unprefixed attributes never do (default
/// namespaces do not apply to attributes).
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

///|
/// Decodes the five XML predefined entities and numeric character
/// references. Malformed references are kept verbatim — @json-style
/// tolerance; the XML parser is the strict gate.
fn decode_entities(value : String) -> String {
  if value.find("&") is None {
    return value
  }
  let units = value.code_units()
  let builder = StringBuilder::new()
  let length = units.length()
  let mut at = 0
  while at < length {
    let unit = units[at].to_int()
    if unit != '&'.to_int() {
      match unit.to_char() {
        Some(ch) => builder.write_char(ch)
        None =>
          // Keep lone surrogates as-is via a paired write when possible.
          match
            (if at + 1 < length {
              (unit, units[at + 1].to_int())
            } else {
              (unit, 0)
            }) {
            (high, low) if high >= 0xD800 &&
              high <= 0xDBFF &&
              low >= 0xDC00 &&
              low <= 0xDFFF => {
              match
                (0x10000 + ((high - 0xD800) << 10) + (low - 0xDC00)).to_char() {
                Some(ch) => builder.write_char(ch)
                None => ()
              }
              at += 1
            }
            _ => ()
          }
      }
      at += 1
      continue
    }
    // Find the terminating ';' within a sane distance.
    let mut semi = -1
    let mut probe = at + 1
    while probe < length && probe <= at + 24 {
      if units[probe].to_int() == ';'.to_int() {
        semi = probe
        break
      }
      probe += 1
    }
    if semi < 0 {
      builder.write_char('&')
      at += 1
      continue
    }
    let name_builder = StringBuilder::new()
    for i in (at + 1)..<semi {
      match units[i].to_int().to_char() {
        Some(ch) => name_builder.write_char(ch)
        None => ()
      }
    }
    let entity = name_builder.to_string()
    let decoded : Char? = match entity {
      "amp" => Some('&')
      "lt" => Some('<')
      "gt" => Some('>')
      "quot" => Some('"')
      "apos" => Some('\'')
      _ =>
        if entity.has_prefix("#x") || entity.has_prefix("#X") {
          parse_char_reference(entity[2:].to_owned(), 16)
        } else if entity.has_prefix("#") {
          parse_char_reference(entity[1:].to_owned(), 10)
        } else {
          None
        }
    }
    match decoded {
      Some(ch) => {
        builder.write_char(ch)
        at = semi + 1
      }
      None => {
        builder.write_char('&')
        at += 1
      }
    }
  }
  builder.to_string()
}

///|
fn parse_char_reference(digits : String, base : Int) -> Char? {
  // Value-based, overflow-aware: leading-zero padding is valid XML
  // (&#00000049; is "1"); anything past U+10FFFF is invalid however it
  // is spelled.
  if digits.length() == 0 {
    return None
  }
  let mut value = 0
  for ch in digits {
    let digit = if ch is ('0'..='9') {
      ch.to_int() - '0'.to_int()
    } else if base == 16 && ch is ('a'..='f') {
      ch.to_int() - 'a'.to_int() + 10
    } else if base == 16 && ch is ('A'..='F') {
      ch.to_int() - 'A'.to_int() + 10
    } else {
      return None
    }
    value = value * base + digit
    if value > 0x10FFFF {
      return None
    }
  }
  value.to_char()
}
