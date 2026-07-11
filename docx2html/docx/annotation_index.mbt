// Phase-2 J1: the annotation index — comments (with threading and
// anchors) and note references, built OUTSIDE the frozen pub(all) AST per
// the reviewed plan: definitions come from the comments/commentsExtended
// parts, positions from the raw-byte story scanner, and everything is
// exposed through opaque readonly types so the surface can grow without
// MoonBit source breaks.
//
// Tolerant like the package reader: malformed stories or missing parts
// degrade to warnings; `docx validate` stays the strict gate.

///|
/// One anchor of a comment: a paired range (start+end), a dangling
/// half-range, or a point (references only). Paths are full agent paths
/// ("/body/p[2]"); `references` are the comment-reference positions
/// attached to this anchor, in document order.
pub struct AnnotationAnchor {
  story : String
  start : String?
  end : String?
  references : Array[String]
}

///|
/// The story this anchor lives in ("/body", "/header[1]", ...).
pub fn AnnotationAnchor::story(self : AnnotationAnchor) -> String {
  self.story
}

///|
/// The range start's containing projection path, when present.
pub fn AnnotationAnchor::start(self : AnnotationAnchor) -> String? {
  self.start
}

///|
/// The range end's containing projection path, when present.
pub fn AnnotationAnchor::end(self : AnnotationAnchor) -> String? {
  self.end
}

///|
/// Comment-reference positions attached to this anchor, in document order.
pub fn AnnotationAnchor::references(self : AnnotationAnchor) -> Array[String] {
  self.references
}

///|
/// One comment: identity and metadata from comments.xml (`defined` is
/// false for a dangling id that only appears in markers), threading from
/// commentsExtended when present, and anchors from the story scans in
/// the total order the plan fixes (story rank, then position).
pub struct CommentInfo {
  id : String
  defined : Bool
  author : String?
  initials : String?
  date : String?
  done : Bool?
  parent_id : String?
  body_paragraphs : Int
  anchors : Array[AnnotationAnchor]
}

///|
/// The comment id, as spelled in comments.xml.
pub fn CommentInfo::id(self : CommentInfo) -> String {
  self.id
}

///|
/// False when the id appears only in markers (no definition).
pub fn CommentInfo::defined(self : CommentInfo) -> Bool {
  self.defined
}

///|
/// The w:author attribute, when present.
pub fn CommentInfo::author(self : CommentInfo) -> String? {
  self.author
}

///|
/// The w:initials attribute, when present.
pub fn CommentInfo::initials(self : CommentInfo) -> String? {
  self.initials
}

///|
/// The w:date attribute, LEXICAL (never converted), when present.
pub fn CommentInfo::date(self : CommentInfo) -> String? {
  self.date
}

///|
/// w15 resolution state; None when commentsExtended is absent.
pub fn CommentInfo::done(self : CommentInfo) -> Bool? {
  self.done
}

///|
/// The parent comment id for replies (w15 paraIdParent, last-paragraph rule).
pub fn CommentInfo::parent_id(self : CommentInfo) -> String? {
  self.parent_id
}

///|
/// Number of body paragraphs in the comment definition.
pub fn CommentInfo::body_paragraphs(self : CommentInfo) -> Int {
  self.body_paragraphs
}

///|
/// Anchors in the plan's total order (story rank, then position).
pub fn CommentInfo::anchors(self : CommentInfo) -> Array[AnnotationAnchor] {
  self.anchors
}

///|
/// One footnote/endnote: its id and every body position referencing it
/// (multi-reference notes are representable per the plan).
pub struct NoteInfo {
  id : String
  references : Array[String]
}

///|
/// The note id, as spelled.
pub fn NoteInfo::id(self : NoteInfo) -> String {
  self.id
}

///|
/// Every body position referencing this note, in document order.
pub fn NoteInfo::references(self : NoteInfo) -> Array[String] {
  self.references
}

///|
/// A range anchor's seq interval, kept for coverage arithmetic.
priv struct AnchorSpan {
  comment_id : String
  story : String
  low : Int
  high : Int
}

///|
/// The annotation index. Opaque: fields stay private so the surface can
/// evolve additively.
pub struct AnnotationIndex {
  priv comments : Array[CommentInfo]
  priv footnotes : Array[NoteInfo]
  priv endnotes : Array[NoteInfo]
  priv warnings : Array[String]
  priv spans : Array[AnchorSpan]
  priv scans : Array[(String, StoryScan)]
}

///|
/// Comments: one entry per definition (comments.xml order), then marker-only ids.
pub fn AnnotationIndex::comments(self : AnnotationIndex) -> Array[CommentInfo] {
  self.comments
}

///|
/// Footnotes with their reference positions.
pub fn AnnotationIndex::footnotes(self : AnnotationIndex) -> Array[NoteInfo] {
  self.footnotes
}

///|
/// Endnotes with their reference positions.
pub fn AnnotationIndex::endnotes(self : AnnotationIndex) -> Array[NoteInfo] {
  self.endnotes
}

///|
/// Non-fatal diagnostics gathered while building the index.
pub fn AnnotationIndex::warnings(self : AnnotationIndex) -> Array[String] {
  self.warnings
}

///|
/// The ids of comments whose anchors INTERSECT the projection element at
/// `path` ("/body/p[2]" style), in definition order — the reverse link
/// J2's `comment_ids` exposes. Point anchors cover their reference's
/// paragraph.
pub fn AnnotationIndex::covering_comment_ids(
  self : AnnotationIndex,
  path : String,
) -> Array[String] {
  let (story, node_path) = split_story_path(path)
  let mut node_low = -1
  let mut node_high = -1
  for entry in self.scans {
    let (scan_story, scan) = entry
    if scan_story != story {
      continue
    }
    for node in scan.nodes() {
      if node.path() == node_path {
        node_low = node.open_seq()
        node_high = node.close_seq()
        break
      }
    }
  }
  let ids : Array[String] = []
  if node_low < 0 {
    return ids
  }
  let seen : Set[String] = Set([])
  for span in self.spans {
    if span.story == story &&
      span.low <= node_high &&
      node_low <= span.high &&
      !seen.contains(span.comment_id) {
      seen.add(span.comment_id)
      ids.push(span.comment_id)
    }
  }
  ids
}

///|
/// Splits "/body/p[2]/r[1]" into ("/body", "p[2]/r[1]"); the story
/// prefix is the first segment (with its index for header/footer).
fn split_story_path(path : String) -> (String, String) {
  if !path.has_prefix("/") {
    return ("", path)
  }
  let rest = path[1:].to_owned()
  match rest.find("/") {
    Some(slash) => (path[0:slash + 1].to_owned(), rest[slash + 1:].to_owned())
    None => (path, "")
  }
}

///|
/// The package read plus its annotation index. Opaque.
pub struct DocxAnnotatedResult {
  priv package_result : DocxPackageResult
  priv index : AnnotationIndex
}

///|
/// The package-level read (identical to read_docx_package).
pub fn DocxAnnotatedResult::result(
  self : DocxAnnotatedResult,
) -> DocxPackageResult {
  self.package_result
}

///|
/// The annotation index built from the same bytes.
pub fn DocxAnnotatedResult::annotations(
  self : DocxAnnotatedResult,
) -> AnnotationIndex {
  self.index
}

///|
/// A comment definition as parsed from comments.xml.
priv struct CommentDefinition {
  id : String
  author : String?
  initials : String?
  date : String?
  body_paragraphs : Int
  last_para_id : String?
}

///|
/// One commentsExtended record (keyed by the comment's LAST body
/// paragraph's w14:paraId — the CT_CommentEx rule; OfficeCLI keys on the
/// first paragraph, a divergence we deliberately do not copy).
priv struct CommentExRecord {
  done : Bool
  parent_para_id : String?
}

///|
/// Reads DOCX bytes into the package representation PLUS the annotation
/// index. The package half is identical to `read_docx_package`.
pub fn read_docx_annotated(
  docx : BytesView,
  external_file_access? : Bool = false,
  read_external_file? : (String) -> Bytes? = no_external_file_reader,
) -> DocxAnnotatedResult raise DocxError {
  let zip = open_zip(docx)
  let external_files = external_file_access_options(
    external_file_access, read_external_file,
  )
  let parts = DocumentParts::build(zip, external_files~)
  let document_result = parts.read_document()
  let collector = HeaderFooterCollector::new(parts)
  let sections = collect_sections(parts.root, collector)
  let messages : Array[Message] = []
  messages.append(parts.notes_result.messages)
  messages.append(parts.comments_result.messages)
  messages.append(document_result.messages)
  messages.append(collector.messages)
  let package_result : DocxPackageResult = {
    document: document_result.document,
    headers: collector.headers,
    footers: collector.footers,
    sections,
    messages: @core.dedupe_messages(messages),
  }
  let index = build_annotation_index(zip, parts, collector)
  { package_result, index }
}

///|
fn build_annotation_index(
  zip : ZipArchive,
  parts : DocumentParts,
  collector : HeaderFooterCollector,
) -> AnnotationIndex {
  let warnings : Array[String] = []
  // Story list in the plan's fixed rank order: body, header[1..],
  // footer[1..], footnotes, endnotes. Header/footer paths come from the
  // collector's dedup maps (index -> path).
  let stories : Array[(String, String)] = [("/body", main_story_path(zip))]
  for pair in inverted_part_paths(collector.header_index_by_path) {
    let (index, path) = pair
    stories.push(("/header[\{index + 1}]", path))
  }
  for pair in inverted_part_paths(collector.footer_index_by_path) {
    let (index, path) = pair
    stories.push(("/footer[\{index + 1}]", path))
  }
  for note_kind in ["footnotes", "endnotes"] {
    let path = find_part_path(
      zip,
      parts.relationships,
      relationship_type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/\{note_kind}",
      base_path=parts.base_path,
      fallback_path="word/\{note_kind}.xml",
    )
    if zip.exists(path) {
      stories.push(("/\{note_kind}", path))
    }
  }
  let scans : Array[(String, StoryScan)] = []
  for story in stories {
    let (story_key, path) = story
    match zip.read_bytes(path) {
      Some(bytes) => {
        let scan = scan_story(bytes) catch {
          Unsupported(message~) => {
            warnings.push(
              "annotation index: could not scan \{story_key} (\{message})",
            )
            continue
          }
          _ => {
            warnings.push("annotation index: could not scan \{story_key}")
            continue
          }
        }
        for warning in scan.warnings() {
          warnings.push(warning)
        }
        scans.push((story_key, scan))
      }
      None => ()
    }
  }
  let definitions = read_comment_definitions(zip, parts, warnings)
  let extended = read_comments_extended(zip, parts, warnings)
  let (comments, spans) = build_comments(definitions, extended, scans, warnings)
  let (footnotes, endnotes) = build_notes(parts, scans)
  { comments, footnotes, endnotes, warnings, spans, scans }
}

///|
fn main_story_path(zip : ZipArchive) -> String {
  find_main_document_path(zip) catch {
    _ => "word/document.xml"
  }
}

///|
fn inverted_part_paths(
  index_by_path : Map[String, Int],
) -> Array[(Int, String)] {
  let pairs : Array[(Int, String)] = []
  for path, index in index_by_path {
    pairs.push((index, path))
  }
  pairs.sort_by_key(pair => pair.0)
  pairs
}

///|
fn read_comment_definitions(
  zip : ZipArchive,
  parts : DocumentParts,
  warnings : Array[String],
) -> Array[CommentDefinition] {
  let definitions : Array[CommentDefinition] = []
  let path = find_part_path(
    zip,
    parts.relationships,
    relationship_type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/comments",
    base_path=parts.base_path,
    fallback_path="word/comments.xml",
  )
  if !zip.exists(path) {
    return definitions
  }
  let root = read_xml_part(zip, path) catch {
    _ => {
      warnings.push("annotation index: could not parse the comments part")
      return definitions
    }
  }
  for comment_element in root.elements_by_tag_name("w:comment") {
    let id = comment_element.attributes.get("w:id").unwrap_or("")
    // Comments legally contain tables and block SDTs; CT_CommentEx keys
    // the ACTUAL last paragraph, so walk descendants in document order.
    let mut body_paragraphs = 0
    let mut last_para_id : String? = None
    for element in comment_element.descendants_by_tag_name("w:p") {
      body_paragraphs += 1
      last_para_id = element.attributes.get("w14:paraId")
    }
    definitions.push({
      id,
      author: comment_element.attributes.get("w:author"),
      initials: comment_element.attributes.get("w:initials"),
      date: comment_element.attributes.get("w:date"),
      body_paragraphs,
      last_para_id,
    })
  }
  definitions
}

///|
fn read_comments_extended(
  zip : ZipArchive,
  parts : DocumentParts,
  warnings : Array[String],
) -> Map[String, CommentExRecord] {
  let records : Map[String, CommentExRecord] = Map([])
  let path = find_part_path(
    zip,
    parts.relationships,
    relationship_type="http://schemas.microsoft.com/office/2011/relationships/commentsExtended",
    base_path=parts.base_path,
    fallback_path="word/commentsExtended.xml",
  )
  if !zip.exists(path) {
    return records
  }
  let root = read_xml_part(zip, path) catch {
    _ => {
      warnings.push(
        "annotation index: could not parse the commentsExtended part",
      )
      return records
    }
  }
  for record in root.elements_by_tag_name("w15:commentEx") {
    match record.attributes.get("w15:paraId") {
      Some(para_id) => {
        if records.contains(para_id) {
          // First wins, deterministically (plan-locked policy).
          warnings.push(
            "annotation index: duplicate commentsExtended record for paraId \{para_id} ignored (first wins)",
          )
          continue
        }
        // ST_OnOff: 1/true/on are true; 0/false/off (and absence) false.
        let done = record.attributes.get("w15:done")
          is (Some("1") | Some("true") | Some("on"))
        records[para_id] = {
          done,
          parent_para_id: record.attributes.get("w15:paraIdParent"),
        }
      }
      None =>
        warnings.push(
          "annotation index: a commentsExtended record has no paraId",
        )
    }
  }
  records
}

///|
/// The v6 anchor-construction algorithm: per id, per story, FIFO-match
/// range markers; attach references to the first containing pair; point
/// anchors otherwise; order anchors (story rank, position).
fn build_comments(
  definitions : Array[CommentDefinition],
  extended : Map[String, CommentExRecord],
  scans : Array[(String, StoryScan)],
  warnings : Array[String],
) -> (Array[CommentInfo], Array[AnchorSpan]) {
  // One CommentInfo PER DEFINITION in comments.xml order (duplicate ids
  // are each exposed ordinally per the plan; id addressing over them is
  // J2's "ambiguous" error), then marker-only ids in first-marker order.
  let entries : Array[(String, CommentDefinition?)] = []
  let known : Set[String] = Set([])
  let duplicate_ids : Set[String] = Set([])
  for definition in definitions {
    if known.contains(definition.id) {
      duplicate_ids.add(definition.id)
      warnings.push(
        "annotation index: duplicate comment definition id '\{definition.id}' (each is exposed; id addressing will be ambiguous)",
      )
    }
    known.add(definition.id)
    entries.push((definition.id, Some(definition)))
  }
  for entry in scans {
    let (_, scan) = entry
    for marker in scan.markers() {
      match marker.kind() {
        CommentStart | CommentEnd | CommentRef =>
          if !known.contains(marker.id()) {
            known.add(marker.id())
            entries.push((marker.id(), None))
            warnings.push(
              "annotation index: markers reference comment id '\{marker.id()}' which has no definition",
            )
          }
        _ => ()
      }
    }
  }
  // last paraId -> comment id, for reply-parent resolution.
  let id_by_last_para : Map[String, String] = Map([])
  let ambiguous_para_ids : Set[String] = Set([])
  for definition in definitions {
    match definition.last_para_id {
      Some(para_id) =>
        if id_by_last_para.contains(para_id) {
          // Two comments claiming one last paraId: parent resolution
          // through it would be a guess — refuse, with a diagnostic.
          if !ambiguous_para_ids.contains(para_id) {
            ambiguous_para_ids.add(para_id)
            warnings.push(
              "annotation index: paraId \{para_id} is the last paragraph of multiple comments; replies through it cannot be resolved",
            )
          }
        } else {
          id_by_last_para[para_id] = definition.id
        }
      None => ()
    }
  }
  let comments : Array[CommentInfo] = []
  let spans : Array[AnchorSpan] = []
  // Anchors are keyed by id; with duplicate definitions they attach to
  // the FIRST entry of that id only (documented by the duplicate warning).
  let anchors_assigned : Set[String] = Set([])
  for entry in entries {
    let (id, definition) = entry
    let anchors : Array[AnnotationAnchor] = []
    let assign_anchors = !anchors_assigned.contains(id)
    anchors_assigned.add(id)
    for story_entry in scans {
      if !assign_anchors {
        break
      }
      let (story, scan) = story_entry
      // FIFO pairing within this story.
      let story_anchors : Array[(Int, AnnotationAnchor)] = []
      let open_starts : Array[ScannedMarker] = []
      let pairs : Array[(ScannedMarker, ScannedMarker)] = []
      for marker in scan.markers() {
        if marker.id() != id {
          continue
        }
        match marker.kind() {
          CommentStart => open_starts.push(marker)
          CommentEnd =>
            if open_starts.length() > 0 {
              let start = open_starts[0]
              let _ = open_starts.remove(0)
              pairs.push((start, marker))
            } else {
              warnings.push(
                "annotation index: dangling commentRangeEnd for id '\{id}' in \{story}",
              )
              story_anchors.push(
                (
                  marker.seq(),
                  {
                    story,
                    start: None,
                    end: Some(marker_path(story, marker, scan)),
                    references: [],
                  },
                ),
              )
            }
          _ => ()
        }
      }
      for dangling in open_starts {
        warnings.push(
          "annotation index: dangling commentRangeStart for id '\{id}' in \{story}",
        )
        story_anchors.push(
          (
            dangling.seq(),
            {
              story,
              start: Some(marker_path(story, dangling, scan)),
              end: None,
              references: [],
            },
          ),
        )
      }
      // Range anchors + reference attachment. Containment first; else the
      // nearest range whose END precedes the reference (Word's canonical
      // emission puts the reference run right AFTER commentRangeEnd, so
      // strict containment alone would orphan every normal reference —
      // implementation-discovered refinement, reflected in the plan);
      // only a reference with no containing and no preceding range forms
      // a point anchor.
      let pair_references : Array[Array[String]] = []
      for _ in pairs {
        pair_references.push([])
      }
      for marker in scan.markers() {
        if marker.id() != id || marker.kind() != CommentRef {
          continue
        }
        let mut attached = false
        for pair_index, pair in pairs {
          let (start, end) = pair
          if start.seq() <= marker.seq() && marker.seq() <= end.seq() {
            pair_references[pair_index].push(marker_path(story, marker, scan))
            attached = true
            break
          }
        }
        if !attached {
          let mut best_index = -1
          let mut best_end = -1
          for pair_index, pair in pairs {
            let (_, end) = pair
            if end.seq() < marker.seq() && end.seq() > best_end {
              best_end = end.seq()
              best_index = pair_index
            }
          }
          if best_index >= 0 {
            pair_references[best_index].push(marker_path(story, marker, scan))
            attached = true
          }
        }
        if !attached {
          story_anchors.push(
            (
              marker.seq(),
              {
                story,
                start: None,
                end: None,
                references: [marker_path(story, marker, scan)],
              },
            ),
          )
          spans.push(point_span(id, story, marker, scan))
        }
      }
      for pair_index, pair in pairs {
        let (start, end) = pair
        story_anchors.push(
          (
            start.seq(),
            {
              story,
              start: Some(marker_path(story, start, scan)),
              end: Some(marker_path(story, end, scan)),
              references: pair_references[pair_index],
            },
          ),
        )
        spans.push({ comment_id: id, story, low: start.seq(), high: end.seq() })
      }
      // Total anchor order within the story: start-else-end-else-first-
      // reference position (v6); stories are already in rank order.
      story_anchors.sort_by_key(pair => pair.0)
      for pair in story_anchors {
        anchors.push(pair.1)
      }
    }
    let (done, parent_id) = match definition {
      Some(def) =>
        match def.last_para_id {
          Some(para_id) =>
            match extended.get(para_id) {
              Some(record) =>
                (
                  Some(record.done),
                  match record.parent_para_id {
                    Some(parent_para) =>
                      match
                        (if ambiguous_para_ids.contains(parent_para) {
                          None
                        } else {
                          id_by_last_para.get(parent_para)
                        }) {
                        Some(parent) => Some(parent)
                        None => {
                          warnings.push(
                            "annotation index: comment '\{id}' replies to unknown paraId \{parent_para}",
                          )
                          None
                        }
                      }
                    None => None
                  },
                )
              None => (None, None)
            }
          None => (None, None)
        }
      None => (None, None)
    }
    comments.push({
      id,
      defined: definition is Some(_),
      author: match definition {
        Some(def) => def.author
        None => None
      },
      initials: match definition {
        Some(def) => def.initials
        None => None
      },
      date: match definition {
        Some(def) => def.date
        None => None
      },
      done,
      parent_id,
      body_paragraphs: match definition {
        Some(def) => def.body_paragraphs
        None => 0
      },
      anchors,
    })
    // Orphan = a definition that OWNED the anchor search, found nothing,
    // and is not a reply (anchorless replies are normal — they live via
    // their parent's thread; plan-locked). Non-first duplicates never
    // own the search, and the duplicate warning already covers them.
    if definition is Some(_) &&
      assign_anchors &&
      anchors.length() == 0 &&
      parent_id is None {
      warnings.push(
        "annotation index: comment '\{id}' has no anchors in any story (orphan definition; content still exposed)",
      )
    }
  }
  (comments, spans)
}

///|
/// A point anchor covers its reference's PARAGRAPH (plan-locked). The
/// span is the containing paragraph's interval; a story-level reference
/// degrades to the marker's own seq.
fn point_span(
  id : String,
  story : String,
  marker : ScannedMarker,
  scan : StoryScan,
) -> AnchorSpan {
  match paragraph_prefix(marker.container_path()) {
    Some(paragraph) => {
      for node in scan.nodes() {
        if node.path() == paragraph {
          return {
            comment_id: id,
            story,
            low: node.open_seq(),
            high: node.close_seq(),
          }
        }
      }
      { comment_id: id, story, low: marker.seq(), high: marker.seq() }
    }
    None => { comment_id: id, story, low: marker.seq(), high: marker.seq() }
  }
}

///|
/// "tbl[1]/tr[1]/tc[1]/p[1]/r[1]" -> the longest prefix ending in a `p`
/// segment ("tbl[1]/tr[1]/tc[1]/p[1]").
fn paragraph_prefix(container : String?) -> String? {
  match container {
    Some(path) => {
      let segments : Array[String] = path
        .split("/")
        .map(v => v[:].to_owned())
        .collect()
      for at = segments.length() - 1; at >= 0; at = at - 1 {
        if segments[at].has_prefix("p[") {
          let builder = StringBuilder::new()
          for i in 0..<=at {
            if i > 0 {
              builder.write_string("/")
            }
            builder.write_string(segments[i])
          }
          return Some(builder.to_string())
        }
      }
      None
    }
    None => None
  }
}

///|
/// A marker's exposed path: its containing projection node, story-
/// qualified; a story-level marker attaches to the nearest node after it
/// (else before it), per the plan's post-pass.
fn marker_path(
  story : String,
  marker : ScannedMarker,
  scan : StoryScan,
) -> String {
  match marker.container_path() {
    Some(container) => "\{story}/\{container}"
    None => {
      let mut best_after : ScannedNode? = None
      let mut best_before : ScannedNode? = None
      for node in scan.nodes() {
        if node.open_seq() > marker.seq() {
          match best_after {
            Some(current) =>
              if node.open_seq() < current.open_seq() {
                best_after = Some(node)
              }
            None => best_after = Some(node)
          }
        } else if node.close_seq() < marker.seq() {
          match best_before {
            Some(current) =>
              if node.close_seq() > current.close_seq() {
                best_before = Some(node)
              }
            None => best_before = Some(node)
          }
        }
      }
      match best_after {
        Some(node) => "\{story}/\{node.path()}"
        None =>
          match best_before {
            Some(node) => "\{story}/\{node.path()}"
            None => story
          }
      }
    }
  }
}

///|
fn build_notes(
  parts : DocumentParts,
  scans : Array[(String, StoryScan)],
) -> (Array[NoteInfo], Array[NoteInfo]) {
  let footnotes : Array[NoteInfo] = []
  let endnotes : Array[NoteInfo] = []
  let footnote_refs : Map[String, Array[String]] = Map([])
  let endnote_refs : Map[String, Array[String]] = Map([])
  for entry in scans {
    let (story, scan) = entry
    for marker in scan.markers() {
      let target = match marker.kind() {
        FootnoteRef => Some(footnote_refs)
        EndnoteRef => Some(endnote_refs)
        _ => None
      }
      match target {
        Some(refs) => {
          let path = marker_path(story, marker, scan)
          match refs.get(marker.id()) {
            Some(existing) => existing.push(path)
            None => refs[marker.id()] = [path]
          }
        }
        None => ()
      }
    }
  }
  for note in parts.notes_result.notes {
    let refs = match note.note_type {
      "footnote" => footnote_refs.get(note.note_id).unwrap_or([])
      _ => endnote_refs.get(note.note_id).unwrap_or([])
    }
    let info : NoteInfo = { id: note.note_id, references: refs }
    if note.note_type == "footnote" {
      footnotes.push(info)
    } else {
      endnotes.push(info)
    }
  }
  (footnotes, endnotes)
}
