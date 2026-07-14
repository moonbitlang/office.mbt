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
}

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
  // Monotonic ordinal assigned when the projection node opens. Close-order
  // storage alone cannot recover open order without sorting; this ordinal
  // lets the scanner rebuild it with one bounded array pass.
  open_order : Int
  open_seq : Int
  close_seq : Int
  byte_start : Int
  byte_end : Int
  // L0 insertion offsets: content_start is just past the open tag AND
  // past a leading pPr (the earliest schema-legal point for run-level
  // content); close_tag_start is the '<' of the close tag. Both -1 for
  // self-closing elements (no interior to insert into).
  content_start : Int
  close_tag_start : Int
}

///|
/// Precomputed fallback for a marker outside every projection node. When
/// `node_is_after` is true the marker is before `path`; otherwise it is after
/// the nearest preceding node.
priv struct StoryLevelMarkerPosition {
  path : String
  node_is_after : Bool
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
  story_level_positions : Map[Int, StoryLevelMarkerPosition]
  // The story's ROOT element span (kind = its local name, path = "").
  // L1 splices new definitions just before root.close_tag_start.
  root : ScannedNode?
  // Private structural accounting used by the complexity regression tests.
  // Every retraction step represents one checkpoint operation or one item
  // discarded; no retained prefix is inspected.
  work : AnnotationScanWork
}

///|
/// Structural work counters for the annotation scanner's adversarial paths.
/// Keep these counters in sync whenever those paths inspect another slot: the
/// white-box tests assert input-linear bounds rather than wall-clock timing.
priv struct AnnotationScanWork {
  mut projection_opens : Int
  mut emitted_nodes : Int
  mut emitted_markers : Int
  mut ordering_steps : Int
  mut story_position_steps : Int
  mut retraction_calls : Int
  mut retraction_steps : Int
}

///|
/// The story's root-element span, when the part had one.
fn StoryScan::root(self : StoryScan) -> ScannedNode? {
  self.root
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
fn StoryScan::story_level_position(
  self : StoryScan,
  marker_seq : Int,
) -> StoryLevelMarkerPosition? {
  self.story_level_positions.get(marker_seq)
}

///|
/// White-box complexity counters. Kept as one private tuple so production
/// callers cannot depend on instrumentation details.
fn StoryScan::complexity_counters(
  self : StoryScan,
) -> (Int, Int, Int, Int, Int, Int, Int) {
  let work = self.work
  (
    work.projection_opens,
    work.emitted_nodes,
    work.emitted_markers,
    work.ordering_steps,
    work.story_position_steps,
    work.retraction_calls,
    work.retraction_steps,
  )
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
  projection_open_order : Int
  open_seq : Int
  byte_start : Int
  // Earliest interior insertion offset (just past the open tag, moved
  // past a leading pPr when one closes directly inside this element).
  mut content_start : Int
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
  // Exact output checkpoints at element open. Late tcPr/trPr decisions can
  // discard the subtree with tail truncation instead of rescanning/copying
  // everything accumulated earlier in the story.
  node_checkpoint : Int
  marker_checkpoint : Int
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
fn scan_story(part : BytesView) -> StoryScan raise DocxError {
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
  let warnings = AnnotationWarningCollector::new(
    MAX_STORY_SCAN_WARNINGS,
    MAX_ANNOTATION_WARNING_CHARS,
  )
  let mut root : ScannedNode? = None
  let frames : Array[ScanFrame] = []
  let root_counters : Map[String, Int] = Map([])
  // Prefix -> stack of URIs (innermost last). "" is the default namespace.
  let namespaces : Map[String, Array[String]] = Map([])
  let mut seq = 0
  let mut projection_open_count = 0
  let work : AnnotationScanWork = {
    projection_opens: 0,
    emitted_nodes: 0,
    emitted_markers: 0,
    ordering_steps: 0,
    story_position_steps: 0,
    retraction_calls: 0,
    retraction_steps: 0,
  }
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
          // A pPr closing directly inside a paragraph (or an rPr
          // inside a run) moves the parent's earliest insertion offset
          // past itself: CT_P and CT_R are SEQUENCES with the property
          // container first, so content must land after it.
          if frame.is_wml && frame.local_name == "pPr" {
            match frames.last() {
              Some(parent) if parent.is_wml && parent.local_name == "p" =>
                parent.content_start = close_end
              _ => ()
            }
          }
          if frame.is_wml && frame.local_name == "rPr" {
            match frames.last() {
              Some(parent) if parent.is_wml && parent.local_name == "r" =>
                parent.content_start = close_end
              _ => ()
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
                  retract_cell(cell, nodes, markers, work)
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
                    work,
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
          finish_frame(frame, seq, index, close_end, nodes, frames, work)
          if frames.length() == 0 && root is None {
            root = Some({
              path: "",
              kind: frame.local_name,
              open_order: -1,
              open_seq: frame.open_seq,
              close_seq: seq,
              byte_start: frame.byte_start,
              byte_end: close_end,
              content_start: frame.content_start,
              close_tag_start: index,
            })
          }
        }
        None => warnings.add("annotation scanner: unbalanced closing tag")
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
          work.emitted_markers += 1
          if id is None {
            warnings.add(
              "annotation scanner: a \{kind} marker has no w:id attribute",
            )
          }
        }
        None => ()
      }
    }
    let mut counter_owner : Map[String, Int]? = None
    let mut projection_kind_value : String? = None
    let mut projection_open_order = -1
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
          projection_open_order = projection_open_count
          projection_open_count += 1
          work.projection_opens += 1
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
          warnings.add("annotation scanner: a vMerge outside any table cell")
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
            open_order: projection_open_order,
            open_seq: seq - 1,
            close_seq: seq,
            byte_start: index,
            byte_end: tag_end,
            content_start: -1,
            close_tag_start: -1,
          })
          work.emitted_nodes += 1
          record_closed_child(frames, path)
        }
        None => ()
      }
      // A self-closing element at DEPTH ZERO is the story's (empty)
      // root: record it so L1 can rewrite it by its own extent.
      if frames.length() == 0 && root is None {
        root = Some({
          path: "",
          kind: local_name,
          open_order: -1,
          open_seq: seq - 1,
          close_seq: seq,
          byte_start: index,
          byte_end: tag_end,
          content_start: -1,
          close_tag_start: -1,
        })
      }
      // A self-closing <w:pPr/> (or <w:rPr/>) still pins its parent's
      // content start past itself (pPr/rPr lead their sequences).
      if is_wml_uri(uri) && local_name == "pPr" {
        match frames.last() {
          Some(parent) if parent.is_wml && parent.local_name == "p" =>
            parent.content_start = tag_end
          _ => ()
        }
      }
      if is_wml_uri(uri) && local_name == "rPr" {
        match frames.last() {
          Some(parent) if parent.is_wml && parent.local_name == "r" =>
            parent.content_start = tag_end
          _ => ()
        }
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
        projection_open_order,
        open_seq: seq,
        byte_start: index,
        content_start: tag_end,
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
        node_checkpoint: nodes.length(),
        marker_checkpoint: markers.length(),
      })
    }
    index = tag_end
  }
  if frames.length() > 0 {
    warnings.add("annotation scanner: unbalanced open tags at end of part")
  }
  let nodes_by_open = nodes_in_open_order(nodes, projection_open_count, work)
  {
    nodes,
    markers,
    warnings: warnings.finish(),
    story_level_positions: build_story_level_positions(
      nodes, nodes_by_open, markers, work,
    ),
    root,
    work,
  }
}

///|
/// Reconstructs surviving nodes in open order without sorting. Retractions can
/// leave holes in the scan-time ordinals, so fill exact slots and compact them
/// with a second monotonic pass. The slot array is bounded by projection opens.
fn nodes_in_open_order(
  nodes : Array[ScannedNode],
  projection_open_count : Int,
  work : AnnotationScanWork,
) -> Array[ScannedNode] {
  let slots : Array[ScannedNode?] = Array::make(projection_open_count, None)
  work.ordering_steps += projection_open_count
  for node in nodes {
    work.ordering_steps += 1
    if node.open_order >= 0 && node.open_order < slots.length() {
      slots[node.open_order] = Some(node)
    }
  }
  let ordered : Array[ScannedNode] = []
  for slot in slots {
    match slot {
      Some(node) => ordered.push(node)
      None => ()
    }
  }
  ordered
}

///|
/// Computes every story-level marker's nearest following/preceding projection
/// node with two monotonic sweeps. This replaces one full node scan per marker.
fn build_story_level_positions(
  nodes_by_close : Array[ScannedNode],
  nodes_by_open : Array[ScannedNode],
  markers : Array[ScannedMarker],
  work : AnnotationScanWork,
) -> Map[Int, StoryLevelMarkerPosition] {
  let positions : Map[Int, StoryLevelMarkerPosition] = Map([])
  let mut open_at = 0
  let mut close_at = 0
  let mut nearest_before : ScannedNode? = None
  // `markers` is emitted in document order, `nodes_by_open` follows the
  // scan-time ordinal, and `nodes_by_close` is the scanner's native order.
  // Each cursor only advances: no copies and no attacker-sized sort.
  for marker in markers {
    work.story_position_steps += 1
    if marker.container_path is Some(_) {
      continue
    }
    while open_at < nodes_by_open.length() &&
          nodes_by_open[open_at].open_seq <= marker.seq {
      open_at += 1
      work.story_position_steps += 1
    }
    while close_at < nodes_by_close.length() &&
          nodes_by_close[close_at].close_seq < marker.seq {
      nearest_before = Some(nodes_by_close[close_at])
      close_at += 1
      work.story_position_steps += 1
    }
    if open_at < nodes_by_open.length() {
      positions[marker.seq] = {
        path: nodes_by_open[open_at].path,
        node_is_after: true,
      }
    } else {
      match nearest_before {
        Some(node) =>
          positions[marker.seq] = { path: node.path, node_is_after: false }
        None => ()
      }
    }
  }
  positions
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
  work : AnnotationScanWork,
) -> Unit {
  work.retraction_calls += 1
  work.retraction_steps += 1 +
    (nodes.length() - frame.node_checkpoint) +
    (markers.length() - frame.marker_checkpoint)
  nodes.truncate(frame.node_checkpoint)
  markers.truncate(frame.marker_checkpoint)
}

///|
/// Retracts a deleted row (trPr/w:del): un-counts its ordinal and
/// suppresses the whole subtree, like the reader's read_table_row.
fn retract_row(
  row : ScanFrame,
  table : ScanFrame?,
  nodes : Array[ScannedNode],
  markers : Array[ScannedMarker],
  work : AnnotationScanWork,
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
      purge_subtree(row, nodes, markers, work)
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
  work : AnnotationScanWork,
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
      purge_subtree(cell, nodes, markers, work)
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
  close_tag_start : Int,
  byte_end : Int,
  nodes : Array[ScannedNode],
  frames : Array[ScanFrame],
  work : AnnotationScanWork,
) -> Unit {
  match frame.projection_path {
    Some(path) => {
      nodes.push({
        path,
        kind: frame.projection_kind.unwrap_or(frame.local_name),
        open_order: frame.projection_open_order,
        open_seq: frame.open_seq,
        close_seq,
        byte_start: frame.byte_start,
        byte_end,
        content_start: frame.content_start,
        close_tag_start,
      })
      work.emitted_nodes += 1
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
  part : BytesView,
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
fn ascii_slice(part : BytesView, start : Int, end : Int) -> String {
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

///|
fn scan_text(xml : String) -> StoryScan raise DocxError {
  scan_story(@utf8.encode(xml))
}

///|
test "scanner: projection paths, marker containment, and document order" {
  let scan = scan_text(
    (
      #|<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
      #|<w:body>
      #|<w:p><w:r><w:t>plain</w:t></w:r></w:p>
      #|<w:p>
      #|<w:commentRangeStart w:id="1"/>
      #|<w:r><w:t>annotated</w:t></w:r>
      #|<w:commentRangeEnd w:id="1"/>
      #|<w:r><w:commentReference w:id="1"/></w:r>
      #|</w:p>
      #|<w:tbl><w:tr><w:tc><w:p><w:r><w:t>cell</w:t></w:r></w:p></w:tc></w:tr></w:tbl>
      #|<w:p><w:hyperlink><w:r><w:t>link</w:t><w:footnoteReference w:id="2"/></w:r></w:hyperlink></w:p>
      #|</w:body>
      #|</w:document>
    ),
  )
  debug_inspect(scan.warnings().length(), content="0")
  let paths : Array[String] = []
  for node in scan.nodes() {
    paths.push("\{node.kind} \{node.path()}")
  }
  paths.sort()
  debug_inspect(
    paths,
    content=(
      #|[
      #|  "p p[1]",
      #|  "p p[2]",
      #|  "p p[3]",
      #|  "tbl tbl[1]",
      #|  "r p[1]/r[1]",
      #|  "r p[2]/r[1]",
      #|  "r p[2]/r[2]",
      #|  "tr tbl[1]/tr[1]",
      #|  "tc tbl[1]/tr[1]/tc[1]",
      #|  "r p[3]/hyperlink[1]/r[1]",
      #|  "p tbl[1]/tr[1]/tc[1]/p[1]",
      #|  "hyperlink p[3]/hyperlink[1]",
      #|  "r tbl[1]/tr[1]/tc[1]/p[1]/r[1]",
      #|]
    ),
  )
  let marks : Array[String] = []
  for marker in scan.markers() {
    marks.push(
      "\{marker.kind()} id=\{marker.id()} in=\{marker.container_path().unwrap_or("<story>")} after=\{marker.after_child().unwrap_or("-")}",
    )
  }
  debug_inspect(
    marks,
    content=(
      #|[
      #|  "commentRangeStart id=1 in=p[2] after=-",
      #|  "commentRangeEnd id=1 in=p[2] after=p[2]/r[1]",
      #|  "commentReference id=1 in=p[2]/r[2] after=-",
      #|  "footnoteReference id=2 in=p[3]/hyperlink[1]/r[1] after=-",
      #|]
    ),
  )
  // Document order and interval sanity: the range start precedes r[1]'s
  // open; the end follows r[1]'s close; the covered run's interval nests
  // inside [start.seq, end.seq].
  let markers = scan.markers()
  let mut covered_open = 0
  let mut covered_close = 0
  for node in scan.nodes() {
    if node.path() == "p[2]/r[1]" {
      covered_open = node.open_seq()
      covered_close = node.close_seq()
    }
  }
  debug_inspect(markers[0].seq() < covered_open, content="true")
  debug_inspect(covered_close < markers[1].seq(), content="true")
}

///|
test "scanner: alternate namespace prefixes and non-WML lookalikes" {
  // The WML URI bound to prefix `x`; a DIFFERENT namespace binds `w` —
  // its commentRangeStart lookalike and its `w:id` must be ignored.
  let scan = scan_text(
    (
      #|<x:document xmlns:x="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:w="http://example.com/not-wml">
      #|<x:body>
      #|<x:p>
      #|<w:commentRangeStart w:id="9"/>
      #|<x:commentRangeStart x:id="3"/>
      #|<x:r><x:t>hi</x:t></x:r>
      #|<x:commentRangeEnd x:id="3"/>
      #|</x:p>
      #|</x:body>
      #|</x:document>
    ),
  )
  let marks : Array[String] = []
  for marker in scan.markers() {
    marks.push("\{marker.kind()} id=\{marker.id()}")
  }
  debug_inspect(
    marks,
    content=(
      #|["commentRangeStart id=3", "commentRangeEnd id=3"]
    ),
  )
  debug_inspect(scan.nodes().length(), content="2")
}

///|
test "scanner: comments story counts each comment body separately" {
  // w:comment is a projection CONTAINER (kind "comment") in the comments
  // story, so paragraph paths carry the container identity and each
  // comment's paragraphs count independently — review round 1 finding 3.
  let scan = scan_text(
    (
      #|<w:comments xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
      #|<w:comment w:id="0"><w:p><w:r><w:t>a</w:t></w:r></w:p><w:p><w:r><w:t>b</w:t></w:r></w:p></w:comment>
      #|<w:comment w:id="1"><w:p><w:r><w:t>c</w:t></w:r></w:p></w:comment>
      #|</w:comments>
    ),
  )
  let paragraph_paths : Array[String] = []
  for node in scan.nodes() {
    if node.kind == "p" {
      paragraph_paths.push(node.path())
    }
  }
  paragraph_paths.sort()
  debug_inspect(
    paragraph_paths,
    content=(
      #|["comment[1]/p[1]", "comment[1]/p[2]", "comment[2]/p[1]"]
    ),
  )
}

///|
test "scanner: unterminated tag and UTF-16 parts fail closed" {
  try {
    let _ = scan_text(
      "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:p",
    )
  } catch {
    Unsupported(message~) =>
      inspect(
        message.has_prefix("the annotation scanner found an unterminated"),
        content="true",
      )
    err => fail("unexpected error: \{repr(err)}")
  } noraise {
    _ => fail("expected the scan to fail")
  }
  let utf16 : Bytes = b"\xFF\xFE<\x00a\x00>\x00"
  try {
    let _ = scan_story(utf16)
  } catch {
    Unsupported(message~) =>
      inspect(
        message.has_prefix("the annotation scanner supports UTF-8"),
        content="true",
      )
    err => fail("unexpected error: \{repr(err)}")
  } noraise {
    _ => fail("expected the scan to fail")
  }
}

///|
test "scanner review round 1: flattening parity — sdt, ins, del, vMerge" {
  // The reader flattens sdt/sdtContent/smartTag/ins and drops w:del and
  // vMerge continuation cells; scanner ordinals must mirror that.
  let scan = scan_text(
    (
      #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
      #|<w:body>
      #|<w:p><w:r><w:t>a</w:t></w:r></w:p>
      #|<w:sdt><w:sdtPr/><w:sdtContent><w:p><w:ins><w:r><w:t>inserted</w:t></w:r></w:ins><w:del><w:r><w:t>gone</w:t></w:r></w:del></w:p></w:sdtContent></w:sdt>
      #|<w:tbl>
      #|<w:tr><w:tc><w:tcPr><w:vMerge w:val="restart"/></w:tcPr><w:p><w:r><w:t>tall</w:t></w:r></w:p></w:tc><w:tc><w:p><w:r><w:t>b</w:t></w:r></w:p></w:tc></w:tr>
      #|<w:tr><w:tc><w:tcPr><w:vMerge/></w:tcPr><w:p><w:r><w:t/></w:r></w:p></w:tc><w:tc><w:p><w:r><w:t>b2</w:t></w:r></w:p></w:tc></w:tr>
      #|</w:tbl>
      #|</w:body>
      #|</w:document>
    ),
  )
  let paths : Array[String] = []
  for node in scan.nodes() {
    paths.push(node.path())
  }
  paths.sort()
  // The sdt-wrapped paragraph is p[2] (NOT a nested p[1]); the inserted
  // run is p[2]/r[1]; the deleted run has no path at all. Row 2's
  // continuation cell is stripped, so its sibling is tc[1] in the AST —
  // and the continuation cell's paragraph/run get no paths.
  debug_inspect(
    paths,
    content=(
      #|[
      #|  "p[1]",
      #|  "p[2]",
      #|  "tbl[1]",
      #|  "p[1]/r[1]",
      #|  "p[2]/r[1]",
      #|  "tbl[1]/tr[1]",
      #|  "tbl[1]/tr[2]",
      #|  "tbl[1]/tr[1]/tc[1]",
      #|  "tbl[1]/tr[1]/tc[2]",
      #|  "tbl[1]/tr[2]/tc[1]",
      #|  "tbl[1]/tr[1]/tc[1]/p[1]",
      #|  "tbl[1]/tr[1]/tc[2]/p[1]",
      #|  "tbl[1]/tr[2]/tc[1]/p[1]",
      #|  "tbl[1]/tr[1]/tc[1]/p[1]/r[1]",
      #|  "tbl[1]/tr[1]/tc[2]/p[1]/r[1]",
      #|  "tbl[1]/tr[2]/tc[1]/p[1]/r[1]",
      #|]
    ),
  )
}

///|
test "scanner review round 1: entity-decoded ids, Strict WML, CDATA immunity" {
  // &#49; IS id "1"; the Strict namespace URI is recognized; marker
  // lookalikes inside CDATA are never counted.
  let scan = scan_text(
    (
      #|<w:document xmlns:w="http://purl.oclc.org/ooxml/wordprocessingml/main">
      #|<w:body>
      #|<w:p><w:commentRangeStart w:id="&#00000049;"/><w:r><w:t><![CDATA[<w:commentRangeEnd w:id="1"/>]]></w:t></w:r><w:commentRangeEnd w:id="&#x31;"/><w:r><w:commentReference w:id="1"/></w:r></w:p>
      #|</w:body>
      #|</w:document>
    ),
  )
  let marks : Array[String] = []
  for marker in scan.markers() {
    marks.push("\{marker.kind()} id=\{marker.id()}")
  }
  debug_inspect(
    marks,
    content=(
      #|[
      #|  "commentRangeStart id=1",
      #|  "commentRangeEnd id=1",
      #|  "commentReference id=1",
      #|]
    ),
  )
}

///|
test "scanner review round 1: plumbing notes are suppressed, user notes counted" {
  let scan = scan_text(
    (
      #|<w:footnotes xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
      #|<w:footnote w:type="separator" w:id="-1"><w:p><w:r><w:t/></w:r></w:p></w:footnote>
      #|<w:footnote w:type="continuationSeparator" w:id="0"><w:p/></w:footnote>
      #|<w:footnote w:type="continuationNotice" w:id="1"><w:p/></w:footnote>
      #|<w:footnote w:id="2"><w:p><w:r><w:t>real</w:t></w:r></w:p></w:footnote>
      #|</w:footnotes>
    ),
  )
  let paths : Array[String] = []
  for node in scan.nodes() {
    paths.push(node.path())
  }
  paths.sort()
  debug_inspect(
    paths,
    content=(
      #|["note[1]", "note[1]/p[1]", "note[1]/p[1]/r[1]"]
    ),
  )
}

///|
test "scanner review round 3: vMerge fail-open, property-container markers, projection kinds" {
  // A continuation in the FIRST row has no merge to continue — the
  // reader keeps the cell (fail-open) and so must the scanner. A marker
  // inside tcPr never surfaces (the reader ignores property-container
  // content). Note containers report the PROJECTION kind "note".
  let scan = scan_text(
    (
      #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
      #|<w:body>
      #|<w:tbl>
      #|<w:tr><w:tc><w:tcPr><w:vMerge/><w:commentRangeStart w:id="9"/></w:tcPr><w:p><w:r><w:t>orphan continuation, kept</w:t></w:r></w:p></w:tc></w:tr>
      #|<w:tr><w:tc><w:tcPr><w:vMerge w:val="restart"/></w:tcPr><w:p><w:r><w:t>tall</w:t></w:r></w:p></w:tc></w:tr>
      #|<w:tr><w:tc><w:tcPr><w:vMerge/></w:tcPr><w:p><w:r><w:t/></w:r></w:p></w:tc></w:tr>
      #|</w:tbl>
      #|</w:body>
      #|</w:document>
    ),
  )
  debug_inspect(scan.markers().length(), content="0")
  let cells : Array[String] = []
  for node in scan.nodes() {
    if node.kind == "tc" {
      cells.push(node.path())
    }
  }
  cells.sort()
  // Row 1's orphan continuation kept; row 3's true continuation gone.
  debug_inspect(
    cells,
    content=(
      #|["tbl[1]/tr[1]/tc[1]", "tbl[1]/tr[2]/tc[1]"]
    ),
  )
  let note_scan = scan_text(
    (
      #|<w:footnotes xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
      #|<w:footnote w:id="2"><w:p><w:r><w:t>real</w:t></w:r></w:p></w:footnote>
      #|</w:footnotes>
    ),
  )
  let mut container_kind = ""
  for node in note_scan.nodes() {
    if node.path() == "note[1]" {
      container_kind = node.kind
    }
  }
  debug_inspect(
    container_kind,
    content=(
      #|"note"
    ),
  )
}

///|
test "scanner review round 4: reader-exact merge origins, spans, and row deletion" {
  let scan = scan_text(
    (
      #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
      #|<w:body>
      #|<w:tbl>
      #|<w:tr><w:tc><w:tcPr><w:vMerge/></w:tcPr><w:p><w:r><w:t>orphan kept, becomes origin</w:t></w:r></w:p></w:tc></w:tr>
      #|<w:tr><w:tc><w:tcPr><w:vMerge/></w:tcPr><w:p><w:r><w:t>second orphan merges away</w:t></w:r></w:p></w:tc></w:tr>
      #|<w:tr><w:tc><w:tcPr><w:gridSpan w:val="2"/><w:vMerge w:val="restart"/></w:tcPr><w:p><w:r><w:t>span2 restart at col0</w:t></w:r></w:p></w:tc></w:tr>
      #|<w:tr><w:tc><w:p><w:r><w:t>plain col0</w:t></w:r></w:p></w:tc><w:tc><w:tcPr><w:vMerge/></w:tcPr><w:p><w:r><w:t>misaligned col1 continuation KEPT (origins key on start column)</w:t></w:r></w:p></w:tc></w:tr>
      #|<w:tr><w:trPr><w:del/></w:trPr><w:tc><w:p><w:r><w:t>deleted row</w:t></w:r></w:p></w:tc></w:tr>
      #|<w:tr><w:tc><w:tcPr><w:vMerge/><w:vMerge w:val="restart"/></w:tcPr><w:p><w:r><w:t>first vMerge wins: continuation, merges into col0 origin above</w:t></w:r></w:p></w:tc></w:tr>
      #|<w:tr><w:tc/><w:tc><w:p><w:r><w:t>after self-closing cell</w:t></w:r></w:p></w:tc></w:tr>
      #|</w:tbl>
      #|</w:body>
      #|</w:document>
    ),
  )
  let cells : Array[String] = []
  for node in scan.nodes() {
    if node.kind is ("tc" | "tr") {
      cells.push("\{node.kind} \{node.path()}")
    }
  }
  cells.sort()
  // Rows: r1 orphan kept (tr[1]/tc[1]); r2 second orphan MERGED (tr[2]
  // has no tc); r3 span-2 restart kept; r4 plain col0 + misaligned col1
  // continuation BOTH kept; r5 deleted (no tr — later rows renumber);
  // r6 (now tr[5]) first-vMerge-wins continuation MERGED into the col0
  // origin (the r4 plain cell); r7 (tr[6]) self-closing tc + sibling.
  debug_inspect(
    cells,
    content=(
      #|[
      #|  "tr tbl[1]/tr[1]",
      #|  "tr tbl[1]/tr[2]",
      #|  "tr tbl[1]/tr[3]",
      #|  "tr tbl[1]/tr[4]",
      #|  "tr tbl[1]/tr[5]",
      #|  "tr tbl[1]/tr[6]",
      #|  "tc tbl[1]/tr[1]/tc[1]",
      #|  "tc tbl[1]/tr[3]/tc[1]",
      #|  "tc tbl[1]/tr[4]/tc[1]",
      #|  "tc tbl[1]/tr[4]/tc[2]",
      #|  "tc tbl[1]/tr[6]/tc[1]",
      #|  "tc tbl[1]/tr[6]/tc[2]",
      #|]
    ),
  )
  // gridSpan parse parity with the reader (parse_grid_span): the span-2
  // restart advanced the cursor so r3's would-be second cell (none) —
  // pinned indirectly by r4's col assignments above.
}

///|
test "scanner review round 5: span-sensitive merging, first-tcPr-only, retraction purges" {
  // Row 1: a span-"2abc" cell (reader's parse_grid_span -> 2) then a
  // plain sibling — the sibling lands at column 2 ONLY if the span
  // parsed as 2. Row 2: continuations at columns 0 and 2 — BOTH merge
  // away iff the row-1 columns were registered at 0 and 2 (a span-1
  // misparse would register the sibling at column 1 and leave the
  // column-2 continuation kept). Row 3: a SECOND tcPr carrying vMerge
  // must be ignored (reader honors only the first), so the cell is
  // KEPT. Row 4: a first-tcPr continuation arriving AFTER content —
  // the retraction purges the already-emitted paragraph and marker.
  let scan = scan_text(
    (
      #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
      #|<w:body>
      #|<w:tbl>
      #|<w:tr><w:tc><w:tcPr><w:gridSpan w:val="2abc"/></w:tcPr><w:p><w:r><w:t>span two</w:t></w:r></w:p></w:tc><w:tc><w:p><w:r><w:t>at col 2</w:t></w:r></w:p></w:tc></w:tr>
      #|<w:tr><w:tc><w:tcPr><w:vMerge/></w:tcPr><w:p/></w:tc><w:tc><w:tcPr><w:vMerge/></w:tcPr><w:p/></w:tc></w:tr>
      #|<w:tr><w:tc><w:tcPr/><w:tcPr><w:vMerge/></w:tcPr><w:p><w:r><w:t>second tcPr ignored, kept</w:t></w:r></w:p></w:tc></w:tr>
      #|<w:tr><w:tc><w:p><w:r><w:t>emitted then purged</w:t></w:r><w:commentReference w:id="5"/></w:p><w:tcPr><w:vMerge/></w:tcPr></w:tc></w:tr>
      #|</w:tbl>
      #|</w:body>
      #|</w:document>
    ),
  )
  // Wait — row 2's second continuation sits at column 1 (cursor), not 2.
  // The cursor claims columns in document order: cell 1 at col 0
  // (span 1 default? no: vMerge only) then cell 2 at col 1. Column 1
  // has NO origin (row 1 registered 0 and 2), so cell 2 is KEPT.
  let cells : Array[String] = []
  for node in scan.nodes() {
    if node.kind == "tc" {
      cells.push(node.path())
    }
  }
  cells.sort()
  debug_inspect(
    cells,
    content=(
      #|[
      #|  "tbl[1]/tr[1]/tc[1]",
      #|  "tbl[1]/tr[1]/tc[2]",
      #|  "tbl[1]/tr[2]/tc[1]",
      #|  "tbl[1]/tr[3]/tc[1]",
      #|]
    ),
  )
  // The purged row-4 cell left no paragraph, run, or marker behind.
  // The row node itself survives (only the CELL was retracted), so the
  // no-leak check targets the row's CHILDREN — round-6 review caught the
  // earlier prefix matching the row and the pin asserting a tautology.
  let mut leaked = false
  for node in scan.nodes() {
    if node.path().has_prefix("tbl[1]/tr[4]/") {
      leaked = true
    }
  }
  debug_inspect(leaked, content="false")
  debug_inspect(scan.markers().length(), content="0")
}

///|
test "scanner review round 6: a deleted row rolls back its origin registrations" {
  // Row 1 is deleted AFTER its cell closed (late first trPr/w:del) —
  // its origin at column 0 must be rolled back, so row 2's orphan
  // continuation is KEPT (the reader excludes deleted rows before span
  // calculation). Row 3's continuation then merges into ROW 2's cell.
  let scan = scan_text(
    (
      #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
      #|<w:body>
      #|<w:tbl>
      #|<w:tr><w:tc><w:p><w:r><w:t>closes before the row is deleted</w:t></w:r></w:p></w:tc><w:trPr><w:del/></w:trPr></w:tr>
      #|<w:tr><w:tc><w:tcPr><w:vMerge/></w:tcPr><w:p><w:r><w:t>orphan kept</w:t></w:r></w:p></w:tc></w:tr>
      #|<w:tr><w:tc><w:tcPr><w:vMerge/></w:tcPr><w:p/></w:tc></w:tr>
      #|</w:tbl>
      #|</w:body>
      #|</w:document>
    ),
  )
  let rows_and_cells : Array[String] = []
  for node in scan.nodes() {
    if node.kind is ("tr" | "tc") {
      rows_and_cells.push("\{node.kind} \{node.path()}")
    }
  }
  rows_and_cells.sort()
  debug_inspect(
    rows_and_cells,
    content=(
      #|["tr tbl[1]/tr[1]", "tr tbl[1]/tr[2]", "tc tbl[1]/tr[1]/tc[1]"]
    ),
  )
}

///|
test "scanner complexity: alternating late row and cell retractions stay linear" {
  let count = 128
  let xml = StringBuilder()
  xml.write_string(
    "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:body><w:tbl>",
  )
  // Establish the column-zero origin required for each late vMerge
  // continuation below to be retracted.
  xml.write_string("<w:tr><w:tc><w:p><w:r/></w:p></w:tc></w:tr>")
  for index in 0..<count {
    // The first properties element arrives after content, so two completed
    // projection nodes and a marker must be truncated from this cell.
    xml.write_string(
      "<w:tr><w:tc><w:p><w:r><w:commentReference w:id=\"c\{index}\"/></w:r></w:p><w:tcPr><w:vMerge/></w:tcPr></w:tc></w:tr>",
    )
    // The first row-properties element likewise arrives after a completed
    // cell and retracts the entire row subtree.
    xml.write_string(
      "<w:tr><w:tc><w:p><w:r><w:commentReference w:id=\"r\{index}\"/></w:r></w:p></w:tc><w:trPr><w:del/></w:trPr></w:tr>",
    )
  }
  xml.write_string("</w:tbl>")
  // Retained story-level markers exercise both monotonic nearest-node sweeps.
  for index in 0..<count {
    xml.write_string("<w:commentReference w:id=\"s\{index}\"/><w:p/>")
  }
  xml.write_string("</w:body></w:document>")
  let scan = scan_text(xml.to_string())
  assert_eq(scan.markers().length(), count)
  let retained = scan.markers()
  match scan.story_level_position(retained[0].seq()) {
    Some(position) => assert_eq(position.path, "p[1]")
    None => fail("expected a position for the first story-level marker")
  }
  match scan.story_level_position(retained[count - 1].seq()) {
    Some(position) => assert_eq(position.path, "p[128]")
    None => fail("expected a position for the last story-level marker")
  }
  let (
    projection_opens,
    emitted_nodes,
    emitted_markers,
    ordering_steps,
    story_position_steps,
    retraction_calls,
    retraction_steps,
  ) = scan.complexity_counters()
  assert_eq(retraction_calls, count * 2)
  // Checkpoint truncation can discard each emitted item at most once. Any
  // retained-prefix scan would violate this structural work bound.
  assert_true(
    retraction_steps <= retraction_calls + emitted_nodes + emitted_markers,
  )
  // Open-order reconstruction visits one slot per projection open and each
  // surviving node once; story fallback visits every retained marker and
  // advances each node cursor at most once.
  assert_eq(ordering_steps, projection_opens + scan.nodes().length())
  assert_true(
    story_position_steps <= scan.markers().length() + scan.nodes().length() * 2,
  )
}
