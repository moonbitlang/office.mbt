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
const MAX_ANNOTATION_WARNINGS : Int = 256

///|
const MAX_ANNOTATION_WARNING_CHARS : Int = 512

///|
const MAX_STORY_SCAN_WARNINGS : Int = 64

///|
const DEFAULT_MAX_READER_DIAGNOSTICS : Int = 256

///|
const DEFAULT_MAX_READER_DIAGNOSTIC_CHARS : Int = 512

///|
priv struct AnnotationWarningCollector {
  messages : Array[String]
  seen : StableStringSet
  max_messages : Int
  max_chars : Int
  mut truncated : Bool
}

///|
fn AnnotationWarningCollector::new(
  max_messages : Int,
  max_chars : Int,
) -> AnnotationWarningCollector {
  {
    messages: [],
    seen: SortedSet([]),
    max_messages,
    max_chars,
    truncated: false,
  }
}

///|
fn AnnotationWarningCollector::text(
  self : AnnotationWarningCollector,
  value : String,
) -> String {
  if self.max_chars <= 0 {
    return ""
  }
  let output = StringBuilder::new()
  let mut count = 0
  let content_limit = if self.max_chars > 1 { self.max_chars - 1 } else { 0 }
  for character in value {
    if count == content_limit {
      output.write_string("…") |> ignore
      break
    }
    output.write_char(character) |> ignore
    count += 1
  }
  if count < content_limit {
    value
  } else {
    output.to_string()
  }
}

///|
fn AnnotationWarningCollector::full(self : AnnotationWarningCollector) -> Bool {
  let at_capacity = self.max_messages <= 0 ||
    self.messages.length() >= self.max_messages - 1
  if at_capacity {
    // Callers use this predicate before constructing potentially large
    // diagnostics. Record the omission here so `finish` still emits the
    // reserved truncation notice.
    self.truncated = true
  }
  at_capacity
}

///|
fn AnnotationWarningCollector::add(
  self : AnnotationWarningCollector,
  message : String,
) -> Unit {
  let bounded = self.text(message)
  if self.seen.contains(bounded) {
    return
  }
  if self.full() {
    self.truncated = true
    return
  }
  self.seen.add(bounded)
  self.messages.push(bounded)
}

///|
fn AnnotationWarningCollector::finish(
  self : AnnotationWarningCollector,
) -> Array[String] {
  if self.truncated && self.messages.length() < self.max_messages {
    self.messages.push(
      self.text("annotation index: additional diagnostics were omitted"),
    )
  }
  self.messages
}

///|
/// Where a marker sits relative to its rendered projection node — the
/// plan's boundary distinction, preserved so "before p[3]" and "after
/// p[2]" do not collapse into the same position.
pub enum AnnotationBoundary {
  Before
  InsideStart
  InsideEnd
  After
} derive(Eq)

///|
pub impl Show for AnnotationBoundary with fn output(self, logger) {
  logger.write_string(
    match self {
      Before => "before"
      InsideStart => "inside_start"
      InsideEnd => "inside_end"
      After => "after"
    },
  )
}

///|
/// One anchor of a comment: a paired range (start+end), a dangling
/// half-range, or a point (references only). Paths are full agent paths
/// ("/body/p[2]"); `references` are the comment-reference positions
/// attached to this anchor, in document order.
pub struct AnnotationAnchor {
  priv story : String
  priv start : String?
  priv start_boundary : AnnotationBoundary?
  priv end : String?
  priv end_boundary : AnnotationBoundary?
  priv references : Array[String]
}

///|
/// The start marker's boundary relative to `start`, when present.
pub fn AnnotationAnchor::start_boundary(
  self : AnnotationAnchor,
) -> AnnotationBoundary? {
  self.start_boundary
}

///|
/// The end marker's boundary relative to `end`, when present.
pub fn AnnotationAnchor::end_boundary(
  self : AnnotationAnchor,
) -> AnnotationBoundary? {
  self.end_boundary
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
  // Defensive copy: internal state must not be mutable through the API.
  self.references.copy()
}

///|
/// One comment: identity and metadata from comments.xml (`defined` is
/// false for a dangling id that only appears in markers), threading from
/// commentsExtended when present, and anchors from the story scans in
/// the total order the plan fixes (story rank, then position).
pub struct CommentInfo {
  priv id : String
  priv defined : Bool
  priv author : String?
  priv initials : String?
  priv date : String?
  priv done : Bool?
  priv parent_id : String?
  priv body_paragraphs : Int
  priv anchors : Array[AnnotationAnchor]
  // The definition's LAST body paragraph w14:paraId (the commentEx
  // key), None when unstamped — L2's retrofit trigger.
  priv last_para_id : String?
}

///|
/// The definition's LAST body paragraph w14:paraId (the commentsExtended
/// key), or None when the paragraph is unstamped.
pub fn CommentInfo::last_para_id(self : CommentInfo) -> String? {
  self.last_para_id
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
  // Defensive copy: internal state must not be mutable through the API.
  self.anchors.copy()
}

///|
/// One footnote/endnote: its id and every body position referencing it
/// (multi-reference notes are representable per the plan).
pub struct NoteInfo {
  priv id : String
  priv references : Array[String]
}

///|
/// The note id, as spelled.
pub fn NoteInfo::id(self : NoteInfo) -> String {
  self.id
}

///|
/// Every body position referencing this note, in document order.
pub fn NoteInfo::references(self : NoteInfo) -> Array[String] {
  // Defensive copy: internal state must not be mutable through the API.
  self.references.copy()
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
/// One publicly addressable annotation-bearing story and the semantic kind
/// its OPC part is allowed to represent. Keeping `kind` beside the path is
/// essential: a physical part must never become both body/header/footer/etc.
priv struct PublicAnnotationStory {
  public_path : String
  kind : String
  part_path : String
}

///|
fn annotation_story_root_local_name(kind : String) -> String {
  match kind {
    "body" => "document"
    "header" => "hdr"
    "footer" => "ftr"
    "footnotes" => "footnotes"
    "endnotes" => "endnotes"
    "comments" => "comments"
    _ => kind
  }
}

///|
/// Relationship types establish a semantic story kind; the target's expanded
/// root QName must agree before markers or mutation spans are trusted.
fn validate_annotation_story_root(
  path : String,
  kind : String,
  scan : StoryScan,
) -> OoxmlDialect raise DocxError {
  let expected = annotation_story_root_local_name(kind)
  guard scan.root() is Some(root) &&
    scan.root_namespace_uri() is Some(uri) &&
    wordprocessing_dialect(uri) is Some(dialect) &&
    root.kind == expected else {
    raise InvalidXml(
      message="the \{kind} annotation story part '\{path}' must have a WordprocessingML '\{expected}' root",
    )
  }
  dialect
}

///|
/// Dialect evidence for one annotation-bearing main-part relationship and
/// its exact target root. Mutation validation compares both sides with the
/// main document before a plan can be adopted or published.
priv struct AnnotationStoryDialectIdentity {
  kind : String
  path : String
  relationship_dialect : OoxmlDialect
  root_dialect : OoxmlDialect
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
  // Publicly addressable stories only (body, rendered header/footer stories,
  // notes, comments). Relationship-reachable but unrendered stories are kept
  // separately so mutation identity gates see them without inventing paths.
  priv scans : Array[(String, StoryScan)]
  priv identity_only_scans : Array[StoryScan]
  // Raw records retained for structural identity validation. Security gates
  // inspect these values directly instead of inferring state from warnings.
  priv comment_ex_identities : Array[CommentExIdentity]
  priv identity_source_complete : Bool
  priv dialect_identities : Array[AnnotationStoryDialectIdentity]
}

///|
/// Comments: one entry per definition (comments.xml order), then marker-only ids.
pub fn AnnotationIndex::comments(self : AnnotationIndex) -> Array[CommentInfo] {
  // Defensive copy: internal state must not be mutable through the API.
  self.comments.copy()
}

///|
/// Footnotes with their reference positions.
pub fn AnnotationIndex::footnotes(self : AnnotationIndex) -> Array[NoteInfo] {
  // Defensive copy: internal state must not be mutable through the API.
  self.footnotes.copy()
}

///|
/// Endnotes with their reference positions.
pub fn AnnotationIndex::endnotes(self : AnnotationIndex) -> Array[NoteInfo] {
  // Defensive copy: internal state must not be mutable through the API.
  self.endnotes.copy()
}

///|
/// Non-fatal diagnostics gathered while building the index.
pub fn AnnotationIndex::warnings(self : AnnotationIndex) -> Array[String] {
  // Defensive copy: internal state must not be mutable through the API.
  self.warnings.copy()
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
  let seen : StableStringSet = SortedSet([])
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
/// How the reader selected a physical story part.
pub enum DocxStoryPartAuthority {
  /// Selected by an OPC relationship.
  RelationshipBacked
  /// Selected by the conventional `word/*.xml` compatibility fallback.
  LegacyFilenameFallback
}

///|
/// Stable protocol spelling for story-part authority.
pub fn DocxStoryPartAuthority::name(self : DocxStoryPartAuthority) -> String {
  match self {
    RelationshipBacked => "relationship"
    LegacyFilenameFallback => "legacy-fallback"
  }
}

///|
/// The physical ZIP entry used for one logical DOCX story and how it was
/// selected. The type is opaque so more provenance can be added later without
/// exposing mutable reader internals.
pub struct DocxStoryPartSource {
  priv part : String
  priv authority : DocxStoryPartAuthority
}

///|
/// The exact physical ZIP entry read for this story.
pub fn DocxStoryPartSource::part(self : DocxStoryPartSource) -> String {
  self.part
}

///|
/// Whether this part was relationship-backed or a legacy filename fallback.
pub fn DocxStoryPartSource::authority(
  self : DocxStoryPartSource,
) -> DocxStoryPartAuthority {
  self.authority
}

///|
fn docx_story_part_source(
  part : String,
  authority : DocxStoryPartAuthority,
) -> DocxStoryPartSource {
  { part, authority }
}

///|
fn optional_annotation_story_source(
  zip : ZipArchive,
  authoritative : String?,
  fallback : String,
) -> DocxStoryPartSource? {
  match authoritative {
    Some(part) => Some(docx_story_part_source(part, RelationshipBacked))
    None =>
      match zip.resolve_path(fallback) {
        Some(part) => Some(docx_story_part_source(part, LegacyFilenameFallback))
        None => None
      }
  }
}

///|
/// The package read plus its annotation index. Opaque. Carries the
/// annotation BODIES as (id, body) pairs in reader order — exactly the
/// shape `@paths.resolve_annotation_path` consumes (J2's read surface).
pub struct DocxAnnotatedResult {
  priv package_result : DocxPackageResult
  priv index : AnnotationIndex
  priv footnote_bodies : Array[(String, Array[DocumentElement])]
  priv endnote_bodies : Array[(String, Array[DocumentElement])]
  priv comment_bodies : Array[(String, Array[DocumentElement])]
  // The zip entry the body-story spans index into (L0), resolved via
  // the officeDocument relationship.
  priv main_part : String
  priv main_story_source : DocxStoryPartSource
  priv header_story_sources : Array[DocxStoryPartSource]
  priv footer_story_sources : Array[DocxStoryPartSource]
  priv footnotes_story_source : DocxStoryPartSource?
  priv endnotes_story_source : DocxStoryPartSource?
  priv comments_story_source : DocxStoryPartSource?
  // The comments part's zip entry when the package has one (resolved
  // by relationship type), for L1's splice-into-existing path.
  priv comments_part_name : String?
  // Conventional annotation parts may remain readable for legacy inspection
  // without being usable annotation state. Candidate validation must reject
  // these orphans instead of treating filename fallbacks as relationship
  // wiring. Each pair is (physical path, relationship role).
  priv orphan_annotation_parts : Array[(String, String)]
  // Relationship types of known annotation sidecars present on the
  // main part that mutating commands cannot keep consistent.
  priv sidecar_types : Array[String]
  // The commentsExtended part when wired (by relationship type), for
  // L2's reply/resolve path.
  priv comments_extended_part_name : String?
  // Dialects come from the namespace-expanded root QNames of the exact source
  // story parts. The reader DOM canonicalizes both dialects to `w`, so this
  // information must be retained explicitly for preservation-safe mutation.
  priv main_wordprocessing_dialect : OoxmlDialect?
  priv comments_wordprocessing_dialect : OoxmlDialect?
  priv main_relationship_dialect : OoxmlDialect?
  // Tolerant projections deliberately omit hidden relationship-reachable
  // stories and broken section references. They are useful for inspection but
  // can never be a sound source for an annotation mutation plan.
  priv read_policy : AnnotationReadPolicy
}

///|
/// Footnote (id, body) pairs in reader order.
pub fn DocxAnnotatedResult::footnote_bodies(
  self : DocxAnnotatedResult,
) -> Array[(String, Array[DocumentElement])] {
  self.footnote_bodies.copy()
}

///|
/// Endnote (id, body) pairs in reader order.
pub fn DocxAnnotatedResult::endnote_bodies(
  self : DocxAnnotatedResult,
) -> Array[(String, Array[DocumentElement])] {
  self.endnote_bodies.copy()
}

///|
/// Comment (id, body) pairs in comments.xml order.
pub fn DocxAnnotatedResult::comment_bodies(
  self : DocxAnnotatedResult,
) -> Array[(String, Array[DocumentElement])] {
  self.comment_bodies.copy()
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
/// Physical source and authority for the body story.
pub fn DocxAnnotatedResult::main_story_source(
  self : DocxAnnotatedResult,
) -> DocxStoryPartSource {
  self.main_story_source
}

///|
/// Physical sources for rendered header stories in package-result order.
pub fn DocxAnnotatedResult::header_story_sources(
  self : DocxAnnotatedResult,
) -> Array[DocxStoryPartSource] {
  self.header_story_sources.copy()
}

///|
/// Physical sources for rendered footer stories in package-result order.
pub fn DocxAnnotatedResult::footer_story_sources(
  self : DocxAnnotatedResult,
) -> Array[DocxStoryPartSource] {
  self.footer_story_sources.copy()
}

///|
/// Physical source for the footnotes story, when one was read.
pub fn DocxAnnotatedResult::footnotes_story_source(
  self : DocxAnnotatedResult,
) -> DocxStoryPartSource? {
  self.footnotes_story_source
}

///|
/// Physical source for the endnotes story, when one was read.
pub fn DocxAnnotatedResult::endnotes_story_source(
  self : DocxAnnotatedResult,
) -> DocxStoryPartSource? {
  self.endnotes_story_source
}

///|
/// Physical source for the comments story, when one was read.
pub fn DocxAnnotatedResult::comments_story_source(
  self : DocxAnnotatedResult,
) -> DocxStoryPartSource? {
  self.comments_story_source
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
priv struct CommentExIdentity {
  para_id : String?
  parent_para_id : String?
}

///|
priv struct CommentStoryMarkers {
  story : String
  scan : StoryScan
  markers : Array[ScannedMarker]
  node_spans : StableStringMap[(Int, Int)]
}

///|
/// Reads DOCX bytes into the package representation PLUS the annotation
/// index. The package half is identical to `read_docx_package`.
pub fn read_docx_annotated(
  docx : BytesView,
  external_file_access? : Bool = false,
  read_external_file? : (String) -> Bytes? = no_external_file_reader,
) -> DocxAnnotatedResult raise DocxError {
  read_docx_annotated_zip(
    open_zip(docx),
    external_file_access,
    read_external_file,
    None,
    None,
    None,
    MutationSafe,
  )
}

///|
/// Builds the same package and annotation indexes from a caller-owned archive
/// snapshot. Payload buffers are shared; the DOCX reader does not inflate the
/// package a second time. Duplicate entry names fail before the map-backed view
/// is constructed.
pub fn read_docx_annotated_archive(
  archive : @mbtzip.Archive,
  external_file_access? : Bool = false,
  read_external_file? : (String) -> Bytes? = no_external_file_reader,
) -> DocxAnnotatedResult raise DocxError {
  read_docx_annotated_zip(
    open_zip_archive(archive),
    external_file_access,
    read_external_file,
    None,
    None,
    None,
    MutationSafe,
  )
}

///|
/// Builds package and annotation indexes from an existing archive while every
/// XML part shares one cumulative parser budget. Source bytes are charged
/// before UTF-8 decoding and parser tokens before DOM allocation. Reader
/// diagnostics are deduplicated in first-seen order and bounded during
/// production by `max_diagnostics` and `max_diagnostic_chars`.
pub fn read_docx_annotated_archive_limited(
  archive : @mbtzip.Archive,
  xml_budget : @xml.XmlReadBudget,
  external_file_access? : Bool = false,
  read_external_file? : (String) -> Bytes? = no_external_file_reader,
  max_diagnostics? : Int = DEFAULT_MAX_READER_DIAGNOSTICS,
  max_diagnostic_chars? : Int = DEFAULT_MAX_READER_DIAGNOSTIC_CHARS,
  expected_main_document_path? : String,
) -> DocxAnnotatedResult raise DocxError {
  read_docx_annotated_archive_with_policy_limited(
    archive,
    xml_budget,
    external_file_access,
    read_external_file,
    max_diagnostics,
    max_diagnostic_chars,
    expected_main_document_path,
    MutationSafe,
  )
}

///|
/// Builds the bounded annotation-aware projection used by tolerant read-only
/// commands. Broken section header/footer references are already warned and
/// omitted by `DocxPackageResult`; they do not activate mutation-only identity
/// gates. Edit transactions continue to use
/// `read_docx_annotated_archive_limited` and fail closed on the same input.
pub fn read_docx_annotated_archive_tolerant_limited(
  archive : @mbtzip.Archive,
  xml_budget : @xml.XmlReadBudget,
  external_file_access? : Bool = false,
  read_external_file? : (String) -> Bytes? = no_external_file_reader,
  max_diagnostics? : Int = DEFAULT_MAX_READER_DIAGNOSTICS,
  max_diagnostic_chars? : Int = DEFAULT_MAX_READER_DIAGNOSTIC_CHARS,
  expected_main_document_path? : String,
) -> DocxAnnotatedResult raise DocxError {
  read_docx_annotated_archive_with_policy_limited(
    archive,
    xml_budget,
    external_file_access,
    read_external_file,
    max_diagnostics,
    max_diagnostic_chars,
    expected_main_document_path,
    TolerantProjection,
  )
}

///|
priv enum AnnotationReadPolicy {
  MutationSafe
  TolerantProjection
}

///|
fn read_docx_annotated_archive_with_policy_limited(
  archive : @mbtzip.Archive,
  xml_budget : @xml.XmlReadBudget,
  external_file_access : Bool,
  read_external_file : (String) -> Bytes?,
  max_diagnostics : Int,
  max_diagnostic_chars : Int,
  expected_main_document_path : String?,
  policy : AnnotationReadPolicy,
) -> DocxAnnotatedResult raise DocxError {
  let diagnostics = ReaderDiagnosticCollector::new(
    max_diagnostics, max_diagnostic_chars,
  )
  read_docx_annotated_zip(
    open_zip_archive(archive),
    external_file_access,
    read_external_file,
    Some(xml_budget),
    Some(diagnostics),
    expected_main_document_path,
    policy,
  )
}

///|
fn read_docx_annotated_zip(
  zip : ZipArchive,
  external_file_access : Bool,
  read_external_file : (String) -> Bytes?,
  xml_budget : @xml.XmlReadBudget?,
  diagnostics : ReaderDiagnosticCollector?,
  expected_main_document_path : String?,
  policy : AnnotationReadPolicy,
) -> DocxAnnotatedResult raise DocxError {
  let external_files = external_file_access_options(
    external_file_access, read_external_file,
  )
  let parts = DocumentParts::build(
    zip,
    external_files~,
    xml_budget?,
    diagnostics?,
    expected_main_document_path?,
    missing_annotation_id_mode=if policy is TolerantProjection {
      EmptyMissingAnnotationId
    } else {
      LegacyUndefinedAnnotationId
    },
  )
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
  let footnote_bodies : Array[Array[DocumentElement]] = []
  let endnote_bodies : Array[Array[DocumentElement]] = []
  let footnote_pairs : Array[(String, Array[DocumentElement])] = []
  let endnote_pairs : Array[(String, Array[DocumentElement])] = []
  for note in parts.notes_result.notes {
    if note.note_type == "footnote" {
      footnote_bodies.push(note.body)
      footnote_pairs.push((note.note_id, note.body))
    } else {
      endnote_bodies.push(note.body)
      endnote_pairs.push((note.note_id, note.body))
    }
  }
  let comment_bodies : Array[Array[DocumentElement]] = []
  let comment_pairs : Array[(String, Array[DocumentElement])] = []
  for comment in parts.comments_result.comments {
    comment_bodies.push(comment.body)
    comment_pairs.push((comment.comment_id, comment.body))
  }
  let path_budget = AnnotationPathBudget::new(parts.xml_budget)
  let verify_ctx = build_verify_context(
    document_result.document,
    collector.headers,
    collector.footers,
    footnote_bodies,
    endnote_bodies,
    comment_bodies,
    path_budget,
  )
  let (annotation_max_warnings, annotation_max_warning_chars) = match
    diagnostics {
    Some(value) => (value.max_messages, value.max_chars)
    None => (MAX_ANNOTATION_WARNINGS, MAX_ANNOTATION_WARNING_CHARS)
  }
  let index = build_annotation_index(
    zip, parts, collector, verify_ctx, path_budget, annotation_max_warnings, annotation_max_warning_chars,
    policy,
  )
  let main_wordprocessing_dialect = annotation_story_dialect(index, "/body")
  let comments_wordprocessing_dialect = annotation_story_dialect(
    index, "/comments",
  )
  // The index's diagnostics are part of the document's message stream —
  // orphans, dangling markers, degradations, and unrepresentable ids
  // must reach `outline`'s messages (J2 review round 1). Dedupe AFTER
  // combining (three definitions sharing one id would otherwise emit
  // the duplicate-id warning three times), reader-first order kept.
  for warning in index.warnings() {
    push_reader_message(package_result.messages, diagnostics, Warning(warning))
  }
  let combined = match diagnostics {
    Some(value) => value.finish()
    None => @core.dedupe_messages(package_result.messages)
  }
  package_result.messages.clear()
  package_result.messages.append(combined)
  // REAL relationship matches only — reader filename fallbacks must not make
  // conventional annotation parts look wired. A conventional part is safe
  // only when it is the exact physical entry selected by the authoritative
  // relationship; alongside a relocated relationship target it is a decoy.
  // Generic mutation plans could otherwise preserve split-view comment
  // metadata or note stories.
  let comments_part_resolved = parts.comments_part_path
  let comments_extended_resolved = parts.comments_extended_part_path
  let orphan_annotation_parts : Array[(String, String)] = []
  for
    candidate in [
      (comments_part_resolved, "word/comments.xml", "comments"),
      (
        comments_extended_resolved, "word/commentsExtended.xml", "commentsExtended",
      ),
      (parts.footnotes_part_path, "word/footnotes.xml", "footnotes"),
      (parts.endnotes_part_path, "word/endnotes.xml", "endnotes"),
    ] {
    let (resolved, conventional_path, role) = candidate
    match zip.resolve_path(conventional_path) {
      Some(physical_path) =>
        match resolved {
          Some(authoritative_path) if authoritative_path == physical_path => ()
          _ => orphan_annotation_parts.push((physical_path, role))
        }
      None => ()
    }
  }
  let sidecar_types : Array[String] = []
  for
    sidecar_type in (
      [
        "http://schemas.microsoft.com/office/2016/09/relationships/commentsIds",
        "http://schemas.microsoft.com/office/2011/relationships/people", "http://schemas.microsoft.com/office/2018/08/relationships/commentsExtensible",
      ] : ReadOnlyArray[String]) {
    if parts.relationships.find_targets_by_type(sidecar_type).length() > 0 {
      sidecar_types.push(sidecar_type)
    }
  }
  // The locked rule detects sidecars by relationship type AND content
  // type: an Override (or Default) can identify one even when no
  // main-part relationship names it. PARSED comparison — substring
  // scans false-positive on comments and miss character-reference
  // spellings the parser normalizes.
  if zip.exists("[Content_Types].xml") {
    let declared_types : StableStringSet = SortedSet([])
    for _, content_type in parts.content_types.defaults {
      declared_types.add(content_type)
    }
    for _, content_type in parts.content_types.overrides {
      declared_types.add(content_type)
    }
    for
      sidecar_content_type in (
        [
          "application/vnd.openxmlformats-officedocument.wordprocessingml.commentsIds+xml",
          "application/vnd.openxmlformats-officedocument.wordprocessingml.people+xml",
          "application/vnd.openxmlformats-officedocument.wordprocessingml.commentsExtensible+xml",
        ] : ReadOnlyArray[String]) {
      if declared_types.contains(sidecar_content_type) &&
        sidecar_types.search(sidecar_content_type) is None {
        sidecar_types.push(sidecar_content_type)
      }
    }
  }
  let main_story_source = docx_story_part_source(
    parts.main_document_path,
    match parts.main_relationship_dialect {
      Some(_) => RelationshipBacked
      None => LegacyFilenameFallback
    },
  )
  let header_story_sources : Array[DocxStoryPartSource] = []
  for pair in inverted_part_paths(collector.header_index_by_path) {
    let (_, path) = pair
    header_story_sources.push(docx_story_part_source(path, RelationshipBacked))
  }
  let footer_story_sources : Array[DocxStoryPartSource] = []
  for pair in inverted_part_paths(collector.footer_index_by_path) {
    let (_, path) = pair
    footer_story_sources.push(docx_story_part_source(path, RelationshipBacked))
  }
  {
    package_result,
    index,
    main_part: parts.main_document_path,
    main_story_source,
    header_story_sources,
    footer_story_sources,
    footnotes_story_source: optional_annotation_story_source(
      zip,
      parts.footnotes_part_path,
      "word/footnotes.xml",
    ),
    endnotes_story_source: optional_annotation_story_source(
      zip,
      parts.endnotes_part_path,
      "word/endnotes.xml",
    ),
    comments_story_source: optional_annotation_story_source(
      zip,
      parts.comments_part_path,
      "word/comments.xml",
    ),
    comments_part_name: comments_part_resolved,
    orphan_annotation_parts,
    sidecar_types,
    comments_extended_part_name: comments_extended_resolved,
    main_wordprocessing_dialect,
    comments_wordprocessing_dialect,
    main_relationship_dialect: parts.main_relationship_dialect,
    read_policy: policy,
    footnote_bodies: footnote_pairs,
    endnote_bodies: endnote_pairs,
    comment_bodies: comment_pairs,
  }
}

///|
fn annotation_story_dialect(
  index : AnnotationIndex,
  public_path : String,
) -> OoxmlDialect? {
  for entry in index.scans {
    let (path, scan) = entry
    if path == public_path {
      return match scan.root_namespace_uri() {
        Some(uri) => wordprocessing_dialect(uri)
        None => None
      }
    }
  }
  None
}

///|
fn DocxAnnotatedResult::main_wordprocessing_namespace(
  self : DocxAnnotatedResult,
) -> String raise DocxError {
  match self.main_wordprocessing_dialect {
    Some(dialect) => dialect.namespace_uri()
    None =>
      raise Unsupported(
        message="the main story's WordprocessingML dialect could not be determined; refusing to annotate",
      )
  }
}

///|
fn DocxAnnotatedResult::comment_definition_namespace(
  self : DocxAnnotatedResult,
) -> String raise DocxError {
  match self.comments_part_name {
    Some(_) =>
      match self.comments_wordprocessing_dialect {
        Some(dialect) => dialect.namespace_uri()
        None =>
          raise Unsupported(
            message="the comments story's WordprocessingML dialect could not be determined; refusing to annotate",
          )
      }
    None => self.main_wordprocessing_namespace()
  }
}

///|
fn DocxAnnotatedResult::new_comments_relationship_type(
  self : DocxAnnotatedResult,
) -> String raise DocxError {
  match self.main_relationship_dialect {
    Some(dialect) => dialect.comments_relationship_type()
    None =>
      match self.main_wordprocessing_dialect {
        Some(dialect) => dialect.comments_relationship_type()
        None =>
          raise Unsupported(
            message="the package's OOXML relationship dialect could not be determined; refusing to annotate",
          )
      }
  }
}

///|
/// AST-side context for position verification: scanner paths are checked
/// against the PARSED projection, and unverifiable positions degrade to
/// their nearest resolvable ancestor with a diagnostic — the guarantee
/// that anchors never point at nodes the AST does not have.
priv struct VerifyContext {
  positions : StableStringSet
}

///|
/// Indexes the parsed projection once. Scanner paths can then be verified in
/// O(1) per candidate rather than resolving every ordinal from the beginning
/// of its sibling list.
fn build_verify_context(
  document : DocumentElement,
  headers : Array[@document.HeaderFooterPart],
  footers : Array[@document.HeaderFooterPart],
  footnote_bodies : Array[Array[DocumentElement]],
  endnote_bodies : Array[Array[DocumentElement]],
  comment_bodies : Array[Array[DocumentElement]],
  path_budget : AnnotationPathBudget,
) -> VerifyContext raise DocxError {
  let positions : StableStringSet = SortedSet([])
  fn index_children(
    element : DocumentElement,
    prefix : String,
  ) -> Unit raise DocxError {
    let ordinals : StableStringMap[Int] = SortedMap([])
    for child in @paths.element_children(element) {
      match @paths.segment_kind(child) {
        Some(kind) => {
          let ordinal = ordinals.get(kind).unwrap_or(0) + 1
          ordinals[kind] = ordinal
          path_budget.charge_descendant(Some(prefix), kind, ordinal)
          let path = "\{prefix}/\{kind}[\{ordinal}]"
          positions.add(path)
          index_children(child, path)
        }
        None => ()
      }
    }
  }
  fn index_story(
    root : String,
    body : Array[DocumentElement],
  ) -> Unit raise DocxError {
    path_budget.charge(root.length())
    positions.add(root)
    index_children(@document.document(body), root)
  }
  positions.add("/body")
  index_children(document, "/body")
  for index, header in headers {
    index_story("/header[\{index + 1}]", header.body)
  }
  for index, footer in footers {
    index_story("/footer[\{index + 1}]", footer.body)
  }
  for index, body in footnote_bodies {
    index_story("/footnotes/note[\{index + 1}]", body)
  }
  for index, body in endnote_bodies {
    index_story("/endnotes/note[\{index + 1}]", body)
  }
  for index, body in comment_bodies {
    index_story("/comments/comment[\{index + 1}]", body)
  }
  { positions, }
}

///|
/// Verifies a story-qualified position path; on failure, trims trailing
/// segments until resolution succeeds (worst case: the story root),
/// warning once per distinct degradation.
fn verify_position(
  ctx : VerifyContext,
  path : String,
  warnings : AnnotationWarningCollector,
  degraded : StableStringSet,
  path_budget : AnnotationPathBudget,
) -> String raise DocxError {
  // The scanner and parsed projection agree in the ordinary case. Reuse the
  // already charged story-qualified string instead of materializing a second
  // identical path for verification.
  if ctx.positions.contains(path) {
    return path
  }
  let (story, node_path) = split_story_path_charged(path, path_budget)
  let mut candidate = node_path
  let mut verified = story
  while true {
    if candidate == "" {
      break
    }
    path_budget.charge(story.length() + 1 + candidate.length())
    let full = "\{story}/\{candidate}"
    if ctx.positions.contains(full) {
      verified = full
      break
    }
    // Trim the last segment (no rfind on String: scan code units).
    let units = candidate.code_units()
    let mut last_slash = -1
    for at in 0..<units.length() {
      if units[at].to_int() == '/'.to_int() {
        last_slash = at
      }
    }
    if last_slash >= 0 {
      path_budget.charge(last_slash)
      candidate = candidate[0:last_slash].to_owned()
    } else {
      candidate = ""
      break
    }
  }
  if verified != path && !degraded.contains(path) && !warnings.full() {
    degraded.add(path)
    warnings.add(
      "annotation index: position '\{warnings.text(path)}' could not be verified against the parsed document; using '\{warnings.text(verified)}'",
    )
  }
  verified
}

///|
/// Budgeted variant used by verification's degradation path. Valid positions
/// bypass this split entirely; malformed paths cannot allocate uncharged story
/// and descendant copies on every marker.
fn split_story_path_charged(
  path : String,
  path_budget : AnnotationPathBudget,
) -> (String, String) raise DocxError {
  if !path.has_prefix("/") {
    return ("", path)
  }
  let mut second_slash = -1
  for at in 1..<path.length() {
    if path[at] == '/' {
      second_slash = at
      break
    }
  }
  if second_slash < 0 {
    return (path, "")
  }
  let node_start = second_slash + 1
  path_budget.charge(second_slash + path.length() - node_start)
  (path[0:second_slash].to_owned(), path[node_start:].to_owned())
}

///|
fn build_annotation_index(
  zip : ZipArchive,
  parts : DocumentParts,
  collector : HeaderFooterCollector,
  ctx : VerifyContext,
  path_budget : AnnotationPathBudget,
  max_warnings : Int,
  max_warning_chars : Int,
  policy : AnnotationReadPolicy,
) -> AnnotationIndex raise DocxError {
  let warnings = AnnotationWarningCollector::new(
    max_warnings.max(0),
    max_warning_chars.max(0),
  )
  if policy is MutationSafe {
    validate_section_story_references(parts)
  }
  // Relationship-reachable but unrendered stories exist only to prove that a
  // mutation has a complete, unambiguous annotation identity graph. Read-only
  // projection already walked every valid section-referenced story through the
  // collector; rerunning the fail-closed identity traversal here would turn a
  // tolerated external/dangling header into a whole-document read failure.
  let reachable_story_parts : Array[ReachableAnnotationStoryPart] = if policy
    is MutationSafe {
    resolve_reachable_annotation_story_parts(
      zip,
      parts.relationships,
      parts.base_path,
    )
  } else {
    []
  }
  // Story list in the plan's fixed rank order: body, header[1..],
  // footer[1..], footnotes, endnotes. Header/footer paths come from the
  // collector's dedup maps (index -> path).
  let stories : Array[PublicAnnotationStory] = [
    { public_path: "/body", kind: "body", part_path: parts.main_document_path },
  ]
  for pair in inverted_part_paths(collector.header_index_by_path) {
    let (index, path) = pair
    stories.push({
      public_path: "/header[\{index + 1}]",
      kind: "header",
      part_path: path,
    })
  }
  for pair in inverted_part_paths(collector.footer_index_by_path) {
    let (index, path) = pair
    stories.push({
      public_path: "/footer[\{index + 1}]",
      kind: "footer",
      part_path: path,
    })
  }
  for
    note_part in [
      ("footnotes", parts.footnotes_part_path),
      ("endnotes", parts.endnotes_part_path),
    ] {
    let (note_kind, authoritative_path) = note_part
    let path = authoritative_path.unwrap_or("word/\{note_kind}.xml")
    if zip.exists(path) {
      stories.push({
        public_path: "/\{note_kind}",
        kind: note_kind,
        part_path: path,
      })
    }
  }
  // The comments story ranks LAST (plan-fixed order); markers are legal
  // inside comment bodies.
  let comments_path = parts.comments_part_path.unwrap_or("word/comments.xml")
  if zip.exists(comments_path) {
    stories.push({
      public_path: "/comments",
      kind: "comments",
      part_path: comments_path,
    })
  }
  let scans : Array[(String, StoryScan)] = []
  let identity_only_scans : Array[StoryScan] = []
  let kind_by_scanned_path : StableStringMap[String] = SortedMap([])
  let root_dialect_by_scanned_path : StableStringMap[OoxmlDialect] = SortedMap([])
  let dialect_identities : Array[AnnotationStoryDialectIdentity] = []
  let mut identity_source_complete = true
  for story in stories {
    let story_key = story.public_path
    let path = story.part_path
    match kind_by_scanned_path.get(path) {
      Some(existing_kind) if existing_kind != story.kind =>
        raise Unsupported(
          message="annotation story part '\{path}' is targeted as both \{existing_kind} and \{story.kind}",
        )
      Some(_) =>
        raise Unsupported(
          message="annotation story part '\{path}' has multiple public story identities",
        )
      None => ()
    }
    kind_by_scanned_path[path] = story.kind
    parts.content_types.require_annotation_part(
      parts.zip,
      Some(path),
      story.kind,
    )
    match zip.read_bytes(path) {
      Some(bytes) => {
        // Every byte offset a mutation-safe result exposes must come from
        // well-formed XML. The package reader is intentionally tolerant, so
        // establish strict well-formedness under the same cumulative budget
        // before the raw span scanner is allowed to derive edit locations.
        if policy is MutationSafe {
          read_identity_story_xml_strict(bytes, parts.xml_budget) |> ignore
        }
        let scan = scan_story(bytes, path_budget~, warning_collector=warnings) catch {
          InvalidXml(message~) => {
            if is_mutation_xml_resource_error(message) {
              raise InvalidXml(message~)
            }
            identity_source_complete = false
            warnings.add("annotation index: could not scan \{story_key}")
            continue
          }
          Unsupported(message~) => {
            identity_source_complete = false
            warnings.add(
              "annotation index: could not scan \{story_key} (\{warnings.text(message)})",
            )
            continue
          }
          _ => {
            identity_source_complete = false
            warnings.add("annotation index: could not scan \{story_key}")
            continue
          }
        }
        let root_dialect = validate_annotation_story_root(
          path,
          story.kind,
          scan,
        )
        root_dialect_by_scanned_path[path] = root_dialect
        scans.push((story_key, scan))
      }
      None => identity_source_complete = false
    }
  }
  // Section collection deliberately exposes only rendered header/footer
  // stories. Identity validation must additionally scan every normalized
  // relationship target, including unreferenced header/footer parts. These
  // scans receive no public path and therefore never create visible anchors.
  for reachable in reachable_story_parts {
    match kind_by_scanned_path.get(reachable.path) {
      Some(existing_kind) if existing_kind != reachable.kind =>
        raise Unsupported(
          message="annotation story part '\{reachable.path}' is targeted as both \{existing_kind} and \{reachable.kind}",
        )
      Some(_) => {
        match root_dialect_by_scanned_path.get(reachable.path) {
          Some(root_dialect) =>
            dialect_identities.push({
              kind: reachable.kind,
              path: reachable.path,
              relationship_dialect: reachable.relationship_dialect,
              root_dialect,
            })
          None => identity_source_complete = false
        }
        continue
      }
      None => ()
    }
    kind_by_scanned_path[reachable.path] = reachable.kind
    parts.content_types.require_annotation_part(
      parts.zip,
      Some(reachable.path),
      reachable.kind,
    )
    guard zip.read_bytes(reachable.path) is Some(bytes) else {
      // The resolver has already checked this; retain an explicit fail-closed
      // guard if the archive abstraction ever becomes mutable during a read.
      raise MissingPart(
        message="the \{reachable.kind} relationship targets missing part '\{reachable.path}'",
      )
    }
    read_identity_story_xml_strict(bytes, parts.xml_budget) |> ignore
    let scan = scan_story(bytes, path_budget~, warning_collector=warnings) catch {
      InvalidXml(message~) => {
        if is_mutation_xml_resource_error(message) {
          raise InvalidXml(message~)
        }
        identity_source_complete = false
        warnings.add(
          "annotation index: could not scan relationship-reachable \{reachable.kind} part '\{warnings.text(reachable.path)}'",
        )
        continue
      }
      Unsupported(message~) => {
        identity_source_complete = false
        warnings.add(
          "annotation index: could not scan relationship-reachable \{reachable.kind} part '\{warnings.text(reachable.path)}' (\{warnings.text(message)})",
        )
        continue
      }
      _ => {
        identity_source_complete = false
        warnings.add(
          "annotation index: could not scan relationship-reachable \{reachable.kind} part '\{warnings.text(reachable.path)}'",
        )
        continue
      }
    }
    let root_dialect = validate_annotation_story_root(
      reachable.path,
      reachable.kind,
      scan,
    )
    dialect_identities.push({
      kind: reachable.kind,
      path: reachable.path,
      relationship_dialect: reachable.relationship_dialect,
      root_dialect,
    })
    identity_only_scans.push(scan)
  }
  let (definitions, definitions_complete) = read_comment_definitions(
    zip, parts, warnings,
  )
  let (extended, comment_ex_identities, extended_complete) = read_comments_extended(
    zip, parts, warnings,
  )
  identity_source_complete = identity_source_complete &&
    definitions_complete &&
    extended_complete
  let identity_only_comment_ids : StableStringSet = SortedSet([])
  for scan in identity_only_scans {
    for marker in scan.markers {
      match marker.kind {
        CommentStart | CommentEnd | CommentRef =>
          identity_only_comment_ids.add(marker.id)
        FootnoteRef | EndnoteRef => ()
      }
    }
  }
  let degraded : StableStringSet = SortedSet([])
  let (comments, spans) = build_comments(
    definitions, extended, scans, identity_only_comment_ids, warnings, ctx, degraded,
    path_budget,
  )
  let (footnotes, endnotes) = build_notes(
    parts, scans, warnings, ctx, degraded, path_budget,
  )
  {
    comments,
    footnotes,
    endnotes,
    warnings: warnings.finish(),
    spans,
    scans,
    identity_only_scans,
    comment_ex_identities,
    identity_source_complete,
    dialect_identities,
  }
}

///|
/// Section references are part of annotation story identity, even though the
/// package projection tolerantly omits broken references. Mutation/indexing
/// must resolve every reference through the matching typed internal
/// relationship and reject missing ids, wrong kinds, external targets, and
/// missing parts.
fn validate_section_story_references(
  parts : DocumentParts,
) -> Unit raise DocxError {
  fn walk(element : XmlElement, parts : DocumentParts) -> Unit raise DocxError {
    let is_header = element.name == "w:headerReference"
    let is_footer = element.name == "w:footerReference"
    if is_header || is_footer {
      guard element.attributes.get("r:id") is Some(id) else {
        let kind = if is_header { "header" } else { "footer" }
        raise Unsupported(message="the \{kind} reference has no r:id")
      }
      resolve_header_footer_reference_part(
        parts.zip,
        parts.relationship_index,
        parts.base_path,
        id,
        is_header,
      )
      |> ignore
    }
    for child in element.children {
      match child {
        XmlElement(inner) => walk(inner, parts)
        XmlText(_) => ()
      }
    }
  }
  walk(parts.root, parts)
}

///|
/// Strictly parses an identity-only story before the raw span scanner touches
/// it. Transaction reads share their caller-owned cumulative budget; unbounded
/// library reads receive an input-linear local budget rather than an unlimited
/// parser path.
fn read_identity_story_xml_strict(
  bytes : BytesView,
  shared_budget : @xml.XmlReadBudget?,
) -> XmlElement raise DocxError {
  let budget = match shared_budget {
    Some(value) => value
    None => {
      // Raw tokens plus namespace-prefix copies and mapped expanded names are
      // input-linear for ordinary OOXML namespace vocabularies but can exceed
      // the byte count substantially when a compact prefix expands to the
      // standard WordprocessingML URI on every element and attribute.
      // Keep the fallback bounded while leaving room for those charged
      // derived allocations.
      let scaled = bytes.length().to_int64() * 32L
      let allowance = if scaled <= 0L {
        1
      } else if scaled > 2147483647L {
        2147483647
      } else {
        scaled.to_int()
      }
      @xml.xml_read_budget(
        max_source_units=bytes.length(),
        max_tokens=allowance,
        max_materialized_chars=allowance,
        max_token_chars=if bytes.length() > 0 { bytes.length() } else { 1 },
      )
    }
  }
  @xml.read_xml_bytes_strict_limited(
    bytes,
    budget,
    namespace_map=office_namespace_map(),
  )
}

///|
/// Every ContentType attribute value declared in [Content_Types].xml
/// (Override and Default alike), parsed — character references decoded.
fn inverted_part_paths(
  index_by_path : StableStringMap[Int],
) -> Array[(Int, String)] {
  // Collector indices are assigned densely in first-reference order. Place
  // paths directly into those slots so even attacker-sized section lists do
  // not require an O(n log n) sort.
  let slots : Array[String?] = Array::make(index_by_path.length(), None)
  for path, index in index_by_path {
    if index >= 0 && index < slots.length() {
      slots[index] = Some(path)
    }
  }
  let pairs : Array[(Int, String)] = []
  for index, path in slots {
    match path {
      Some(value) => pairs.push((index, value))
      None => ()
    }
  }
  pairs
}

///|
fn read_comment_definitions(
  zip : ZipArchive,
  parts : DocumentParts,
  warnings : AnnotationWarningCollector,
) -> (Array[CommentDefinition], Bool) raise DocxError {
  let definitions : Array[CommentDefinition] = []
  // The reader has already resolved a unique Transitional/Strict target.
  // A filename fallback is permitted only when no relationship was declared.
  let path = parts.comments_part_path.unwrap_or("word/comments.xml")
  if !zip.exists(path) {
    return (definitions, true)
  }
  let root = read_xml_part(zip, path, xml_budget?=parts.xml_budget) catch {
    InvalidXml(message~) => {
      if is_mutation_xml_resource_error(message) {
        raise InvalidXml(message~)
      }
      warnings.add("annotation index: could not parse the comments part")
      return (definitions, false)
    }
    _ => {
      warnings.add("annotation index: could not parse the comments part")
      return (definitions, false)
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
  (definitions, true)
}

///|
fn read_comments_extended(
  zip : ZipArchive,
  parts : DocumentParts,
  warnings : AnnotationWarningCollector,
) -> (StableStringMap[CommentExRecord], Array[CommentExIdentity], Bool) raise DocxError {
  let records : StableStringMap[CommentExRecord] = SortedMap([])
  let identities : Array[CommentExIdentity] = []
  let path = parts.comments_extended_part_path.unwrap_or(
    "word/commentsExtended.xml",
  )
  if !zip.exists(path) {
    return (records, identities, true)
  }
  guard zip.read_bytes(path) is Some(bytes) else {
    raise MissingPart(message="missing DOCX part: " + path)
  }
  let root = read_identity_story_xml_strict(bytes, parts.xml_budget)
  if root.name != "w15:commentsEx" {
    raise InvalidXml(
      message="the commentsExtended part has an unexpected root element",
    )
  }
  for record in root.elements_by_tag_name("w15:commentEx") {
    let raw_para_id = record.attributes.get("w15:paraId")
    let raw_parent_para_id = record.attributes.get("w15:paraIdParent")
    identities.push({ para_id: raw_para_id, parent_para_id: raw_parent_para_id })
    match raw_para_id {
      Some(raw_para_id) => {
        let para_id = canonical_para_id(raw_para_id)
        if records.contains(para_id) {
          // First wins, deterministically (plan-locked policy).
          if !warnings.full() {
            warnings.add(
              "annotation index: duplicate commentsExtended record for paraId \{warnings.text(para_id)} ignored (first wins)",
            )
          }
          continue
        }
        // ST_OnOff: 1/true/on are true; 0/false/off (and absence) false.
        let done = record.attributes.get("w15:done")
          is (Some("1") | Some("true") | Some("on"))
        records[para_id] = {
          done,
          parent_para_id: match raw_parent_para_id {
            Some(parent) => Some(canonical_para_id(parent))
            None => None
          },
        }
      }
      None =>
        warnings.add(
          "annotation index: a commentsExtended record has no paraId",
        )
    }
  }
  (records, identities, true)
}

///|
/// Appends four already ordered anchor streams in total sequence order. Four
/// is fixed by the v6 construction cases (dangling end, dangling start,
/// unpaired reference, paired range), so the constant-width merge is O(n).
fn append_ordered_story_anchors(
  output : Array[AnnotationAnchor],
  dangling_ends : Array[(Int, AnnotationAnchor)],
  dangling_starts : Array[(Int, AnnotationAnchor)],
  point_references : Array[(Int, AnnotationAnchor)],
  paired_ranges : Array[(Int, AnnotationAnchor)],
) -> Unit {
  let streams : ReadOnlyArray[Array[(Int, AnnotationAnchor)]] = [
    dangling_ends, dangling_starts, point_references, paired_ranges,
  ]
  let positions : FixedArray[Int] = FixedArray::make(4, 0)
  while true {
    let mut selected = -1
    let mut selected_seq = 0
    for stream_index in 0..<4 {
      let position = positions[stream_index]
      let stream = streams[stream_index]
      if position < stream.length() {
        let candidate_seq = stream[position].0
        if selected < 0 || candidate_seq < selected_seq {
          selected = stream_index
          selected_seq = candidate_seq
        }
      }
    }
    if selected < 0 {
      break
    }
    let position = positions[selected]
    output.push(streams[selected][position].1)
    positions[selected] = position + 1
  }
}

///|
/// The v6 anchor-construction algorithm: per id, per story, FIFO-match
/// range markers; attach references to the first containing pair; point
/// anchors otherwise; order anchors (story rank, position).
fn build_comments(
  definitions : Array[CommentDefinition],
  extended : StableStringMap[CommentExRecord],
  scans : Array[(String, StoryScan)],
  identity_only_comment_ids : StableStringSet,
  warnings : AnnotationWarningCollector,
  ctx : VerifyContext,
  degraded : StableStringSet,
  path_budget : AnnotationPathBudget,
) -> (Array[CommentInfo], Array[AnchorSpan]) raise DocxError {
  // One CommentInfo PER DEFINITION in comments.xml order (duplicate ids
  // are each exposed ordinally per the plan; id addressing over them is
  // J2's "ambiguous" error), then marker-only ids in first-marker order.
  let entries : Array[(String, CommentDefinition?)] = []
  let known : StableStringSet = SortedSet([])
  for definition in definitions {
    if known.contains(definition.id) && !warnings.full() {
      warnings.add(
        "annotation index: duplicate comment definition id '\{warnings.text(definition.id)}' (each is exposed; id addressing will be ambiguous)",
      )
    }
    known.add(definition.id)
    entries.push((definition.id, Some(definition)))
  }
  let marker_stories_by_id : StableStringMap[Array[CommentStoryMarkers]] = SortedMap([],
  )
  for entry in scans {
    let (story, scan) = entry
    let story_markers : StableStringMap[Array[ScannedMarker]] = SortedMap([])
    let story_ids : Array[String] = []
    let node_spans : StableStringMap[(Int, Int)] = SortedMap([])
    for node in scan.nodes {
      node_spans[node.path] = (node.open_seq, node.close_seq)
    }
    for marker in scan.markers() {
      match marker.kind() {
        CommentStart | CommentEnd | CommentRef => {
          match story_markers.get(marker.id()) {
            Some(markers) => markers.push(marker)
            None => {
              story_markers[marker.id()] = [marker]
              story_ids.push(marker.id())
            }
          }
          if !known.contains(marker.id()) {
            known.add(marker.id())
            entries.push((marker.id(), None))
            if !warnings.full() {
              warnings.add(
                "annotation index: markers reference comment id '\{warnings.text(marker.id())}' which has no definition",
              )
            }
          }
        }
        _ => ()
      }
    }
    for id in story_ids {
      let bucket : CommentStoryMarkers = {
        story,
        scan,
        markers: story_markers.get(id).unwrap_or([]),
        node_spans,
      }
      match marker_stories_by_id.get(id) {
        Some(stories) => stories.push(bucket)
        None => marker_stories_by_id[id] = [bucket]
      }
    }
  }
  // last paraId -> comment id, for reply-parent resolution.
  let id_by_last_para : StableStringMap[String] = SortedMap([])
  let ambiguous_para_ids : StableStringSet = SortedSet([])
  for definition in definitions {
    match definition.last_para_id {
      Some(raw_para_id) => {
        let para_id = canonical_para_id(raw_para_id)
        if id_by_last_para.contains(para_id) {
          // Two comments claiming one last paraId: parent resolution
          // through it would be a guess — refuse, with a diagnostic.
          if !ambiguous_para_ids.contains(para_id) {
            ambiguous_para_ids.add(para_id)
            if !warnings.full() {
              warnings.add(
                "annotation index: paraId \{warnings.text(para_id)} is the last paragraph of multiple comments; replies through it cannot be resolved",
              )
            }
          }
        } else {
          id_by_last_para[para_id] = definition.id
        }
      }
      None => ()
    }
  }
  let comments : Array[CommentInfo] = []
  let spans : Array[AnchorSpan] = []
  // Anchors are computed ONCE per id and shared by every entry of that
  // id (duplicate definitions each report the id's real anchors — the
  // review rejected assigning them to one ordinal arbitrarily).
  let anchors_by_id : StableStringMap[Array[AnnotationAnchor]] = SortedMap([])
  for entry in entries {
    let (id, definition) = entry
    let anchors : Array[AnnotationAnchor] = match anchors_by_id.get(id) {
      Some(existing) => {
        comments.push(
          comment_entry(
            id, definition, existing, extended, id_by_last_para, ambiguous_para_ids,
            warnings,
          ),
        )
        continue
      }
      None => []
    }
    match marker_stories_by_id.get(id) {
      Some(story_buckets) =>
        for bucket in story_buckets {
          let story = bucket.story
          let scan = bucket.scan
          // FIFO pairing within this story. An index-based queue avoids the
          // quadratic front-removal cost of adversarial start/end runs.
          let dangling_end_anchors : Array[(Int, AnnotationAnchor)] = []
          let dangling_start_anchors : Array[(Int, AnnotationAnchor)] = []
          let point_reference_anchors : Array[(Int, AnnotationAnchor)] = []
          let paired_range_anchors : Array[(Int, AnnotationAnchor)] = []
          let open_starts : Array[ScannedMarker] = []
          let references : Array[ScannedMarker] = []
          let pairs : Array[(ScannedMarker, ScannedMarker)] = []
          let mut next_start = 0
          for marker in bucket.markers {
            match marker.kind() {
              CommentStart => open_starts.push(marker)
              CommentEnd =>
                if next_start < open_starts.length() {
                  pairs.push((open_starts[next_start], marker))
                  next_start += 1
                } else {
                  if !warnings.full() {
                    warnings.add(
                      "annotation index: dangling commentRangeEnd for id '\{warnings.text(id)}' in \{story}",
                    )
                  }
                  let (raw_end, end_boundary) = marker_position(
                    story, marker, scan, path_budget,
                  )
                  let end_path = verify_position(
                    ctx, raw_end, warnings, degraded, path_budget,
                  )
                  dangling_end_anchors.push(
                    (
                      marker.seq(),
                      {
                        story,
                        start: None,
                        start_boundary: None,
                        end: Some(end_path),
                        end_boundary: Some(end_boundary),
                        references: [],
                      },
                    ),
                  )
                }
              CommentRef => references.push(marker)
              FootnoteRef | EndnoteRef => ()
            }
          }
          for index in next_start..<open_starts.length() {
            let dangling = open_starts[index]
            if !warnings.full() {
              warnings.add(
                "annotation index: dangling commentRangeStart for id '\{warnings.text(id)}' in \{story}",
              )
            }
            let (raw_start, start_boundary) = marker_position(
              story, dangling, scan, path_budget,
            )
            let start_path = verify_position(
              ctx, raw_start, warnings, degraded, path_budget,
            )
            dangling_start_anchors.push(
              (
                dangling.seq(),
                {
                  story,
                  start: Some(start_path),
                  start_boundary: Some(start_boundary),
                  end: None,
                  end_boundary: None,
                  references: [],
                },
              ),
            )
          }
          // Pair starts and ends are both monotonic under FIFO matching. Walk
          // references and pair ends once: the first live pair contains the
          // reference when its start precedes it; otherwise the immediately
          // preceding pair is the nearest preceding range.
          let pair_references : Array[Array[String]] = []
          for _ in pairs {
            pair_references.push([])
          }
          let mut first_live_pair = 0
          for marker in references {
            while first_live_pair < pairs.length() {
              let (_, end) = pairs[first_live_pair]
              if end.seq() < marker.seq() {
                first_live_pair += 1
              } else {
                break
              }
            }
            let mut pair_index = -1
            if first_live_pair < pairs.length() {
              let (start, _) = pairs[first_live_pair]
              if start.seq() <= marker.seq() {
                pair_index = first_live_pair
              }
            }
            if pair_index < 0 && first_live_pair > 0 {
              pair_index = first_live_pair - 1
            }
            let reference_path = verify_position(
              ctx,
              marker_path(story, marker, scan, path_budget),
              warnings,
              degraded,
              path_budget,
            )
            if pair_index >= 0 {
              pair_references[pair_index].push(reference_path)
            } else {
              point_reference_anchors.push(
                (
                  marker.seq(),
                  {
                    story,
                    start: None,
                    start_boundary: None,
                    end: None,
                    end_boundary: None,
                    references: [reference_path],
                  },
                ),
              )
              spans.push(
                point_span(id, story, marker, bucket.node_spans, path_budget),
              )
            }
          }
          for pair_index, pair in pairs {
            let (start, end) = pair
            let (raw_start, start_boundary) = marker_position(
              story, start, scan, path_budget,
            )
            let (raw_end, end_boundary) = marker_position(
              story, end, scan, path_budget,
            )
            let start_path = verify_position(
              ctx, raw_start, warnings, degraded, path_budget,
            )
            let end_path = verify_position(
              ctx, raw_end, warnings, degraded, path_budget,
            )
            paired_range_anchors.push(
              (
                start.seq(),
                {
                  story,
                  start: Some(start_path),
                  start_boundary: Some(start_boundary),
                  end: Some(end_path),
                  end_boundary: Some(end_boundary),
                  references: pair_references[pair_index],
                },
              ),
            )
            spans.push({
              comment_id: id,
              story,
              low: start.seq(),
              high: end.seq(),
            })
          }
          // Each case stream is already monotonic; merge them at fixed width
          // instead of sorting attacker-sized marker arrays.
          append_ordered_story_anchors(
            anchors, dangling_end_anchors, dangling_start_anchors, point_reference_anchors,
            paired_range_anchors,
          )
        }
      None => ()
    }
    anchors_by_id[id] = anchors
    let info = comment_entry(
      id, definition, anchors, extended, id_by_last_para, ambiguous_para_ids, warnings,
    )
    comments.push(info)
  }
  // Orphan = an id with no anchors anywhere whose entries include at
  // least one defined NON-REPLY (anchorless replies are normal — they
  // live via their parent's thread; plan-locked). A post-pass over ALL
  // entries so duplicate ordering cannot mask it; warned once per id.
  let orphan_warned : StableStringSet = SortedSet([])
  for info in comments {
    if info.defined &&
      info.anchors.length() == 0 &&
      info.parent_id is None &&
      !orphan_warned.contains(info.id) &&
      !warnings.full() {
      orphan_warned.add(info.id)
      if identity_only_comment_ids.contains(info.id) {
        warnings.add(
          "annotation index: comment '\{warnings.text(info.id)}' has no public anchors (referenced only in relationship-reachable hidden stories; content still exposed)",
        )
      } else {
        warnings.add(
          "annotation index: comment '\{warnings.text(info.id)}' has no anchors in any story (orphan definition; content still exposed)",
        )
      }
    }
  }
  (comments, spans)
}

///|
/// Metadata assembly for one comments() entry: threading resolved via
/// the definition's LAST-paragraph paraId (CT_CommentEx), sharing the
/// id's anchors.
fn comment_entry(
  id : String,
  definition : CommentDefinition?,
  anchors : Array[AnnotationAnchor],
  extended : StableStringMap[CommentExRecord],
  id_by_last_para : StableStringMap[String],
  ambiguous_para_ids : StableStringSet,
  warnings : AnnotationWarningCollector,
) -> CommentInfo {
  let (done, parent_id) = match definition {
    Some(def) =>
      match def.last_para_id {
        Some(para_id) =>
          match extended.get(canonical_para_id(para_id)) {
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
                        if !warnings.full() {
                          warnings.add(
                            "annotation index: comment '\{warnings.text(id)}' replies to unknown paraId \{warnings.text(parent_para)}",
                          )
                        }
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
  {
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
    last_para_id: match definition {
      Some(def) => def.last_para_id
      None => None
    },
  }
}

///|
/// A point anchor covers its reference's PARAGRAPH (plan-locked). The
/// span is the containing paragraph's interval; a story-level reference
/// degrades to the marker's own seq.
fn point_span(
  id : String,
  story : String,
  marker : ScannedMarker,
  node_spans : StableStringMap[(Int, Int)],
  path_budget : AnnotationPathBudget,
) -> AnchorSpan raise DocxError {
  match paragraph_prefix(marker.container_path(), path_budget) {
    Some(paragraph) =>
      match node_spans.get(paragraph) {
        Some((low, high)) => { comment_id: id, story, low, high }
        None => { comment_id: id, story, low: marker.seq(), high: marker.seq() }
      }
    None => { comment_id: id, story, low: marker.seq(), high: marker.seq() }
  }
}

///|
/// "tbl[1]/tr[1]/tc[1]/p[1]/r[1]" -> the longest prefix ending in a `p`
/// segment ("tbl[1]/tr[1]/tc[1]/p[1]").
fn paragraph_prefix(
  container : String?,
  path_budget : AnnotationPathBudget,
) -> String? raise DocxError {
  match container {
    Some(path) => {
      let mut segment_start = 0
      let mut paragraph_end = -1
      for at in 0..<=path.length() {
        if at == path.length() || path[at] == '/' {
          if at >= segment_start + 2 &&
            path[segment_start] == 'p' &&
            path[segment_start + 1] == '[' {
            paragraph_end = at
          }
          segment_start = at + 1
        }
      }
      if paragraph_end < 0 {
        None
      } else {
        path_budget.charge(paragraph_end)
        Some(path[0:paragraph_end].to_owned())
      }
    }
    None => None
  }
}

///|
/// A marker's exposed path: its containing projection node, story-
/// qualified; a story-level marker attaches to the nearest node after it
/// (else before it), per the plan's post-pass.
fn marker_position(
  story : String,
  marker : ScannedMarker,
  scan : StoryScan,
  path_budget : AnnotationPathBudget,
) -> (String, AnnotationBoundary) raise DocxError {
  match marker.container_path() {
    Some(container) => {
      let boundary = match marker.after_child() {
        Some(_) => InsideEnd
        None => InsideStart
      }
      path_budget.charge(story.length() + 1 + container.length())
      ("\{story}/\{container}", boundary)
    }
    None =>
      match scan.story_level_position(marker.seq()) {
        Some(position) => {
          path_budget.charge(story.length() + 1 + position.path.length())
          (
            "\{story}/\{position.path}",
            if position.node_is_after {
              Before
            } else {
              After
            },
          )
        }
        None => (story, InsideStart)
      }
  }
}

///|
fn marker_path(
  story : String,
  marker : ScannedMarker,
  scan : StoryScan,
  path_budget : AnnotationPathBudget,
) -> String raise DocxError {
  marker_position(story, marker, scan, path_budget).0
}

///|
fn build_notes(
  parts : DocumentParts,
  scans : Array[(String, StoryScan)],
  warnings : AnnotationWarningCollector,
  ctx : VerifyContext,
  degraded : StableStringSet,
  path_budget : AnnotationPathBudget,
) -> (Array[NoteInfo], Array[NoteInfo]) raise DocxError {
  let footnotes : Array[NoteInfo] = []
  let endnotes : Array[NoteInfo] = []
  let footnote_refs : StableStringMap[Array[String]] = SortedMap([])
  let endnote_refs : StableStringMap[Array[String]] = SortedMap([])
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
          let path = verify_position(
            ctx,
            marker_path(story, marker, scan, path_budget),
            warnings,
            degraded,
            path_budget,
          )
          match refs.get(marker.id()) {
            Some(existing) => existing.push(path)
            None => refs[marker.id()] = [path]
          }
        }
        None => ()
      }
    }
  }
  let seen_footnotes : StableStringSet = SortedSet([])
  let seen_endnotes : StableStringSet = SortedSet([])
  for note in parts.notes_result.notes {
    let refs = match note.note_type {
      "footnote" => footnote_refs.get(note.note_id).unwrap_or([])
      _ => endnote_refs.get(note.note_id).unwrap_or([])
    }
    let info : NoteInfo = { id: note.note_id, references: refs }
    if note.note_type == "footnote" {
      // Duplicate ids make [@id=...] ambiguous — the plan-locked
      // diagnostic (comments get theirs at definition parse).
      if seen_footnotes.contains(note.note_id) && !warnings.full() {
        warnings.add(
          "annotation index: duplicate footnote id '\{warnings.text(note.note_id)}' (each is exposed; id addressing will be ambiguous)",
        )
      }
      seen_footnotes.add(note.note_id)
      footnotes.push(info)
    } else {
      if seen_endnotes.contains(note.note_id) && !warnings.full() {
        warnings.add(
          "annotation index: duplicate endnote id '\{warnings.text(note.note_id)}' (each is exposed; id addressing will be ambiguous)",
        )
      }
      seen_endnotes.add(note.note_id)
      endnotes.push(info)
    }
  }
  // Reference-only ids (no definition) surface too — dangling references
  // are review content an agent must see (plan: surface, don't skip).
  for id, refs in footnote_refs {
    if !seen_footnotes.contains(id) {
      if !warnings.full() {
        warnings.add(
          "annotation index: footnote references target id '\{warnings.text(id)}' which has no definition",
        )
      }
      footnotes.push({ id, references: refs })
    }
  }
  for id, refs in endnote_refs {
    if !seen_endnotes.contains(id) {
      if !warnings.full() {
        warnings.add(
          "annotation index: endnote references target id '\{warnings.text(id)}' which has no definition",
        )
      }
      endnotes.push({ id, references: refs })
    }
  }
  (footnotes, endnotes)
}
