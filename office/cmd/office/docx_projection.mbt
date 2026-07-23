///|
let docx_cli_max_xml_source_units : Int = 64 * 1024 * 1024

///|
let docx_cli_max_xml_tokens : Int = 1024 * 1024

///|
let docx_cli_max_xml_materialized_chars : Int = 32 * 1024 * 1024

///|
let docx_cli_max_xml_token_chars : Int = 1024 * 1024

///|
let docx_cli_default_max_elements : Int = 50_000

///|
let docx_cli_hard_max_elements : Int = 200_000

///|
let docx_cli_max_warnings : Int = 128

///|
let docx_cli_projection_yield_elements : Int = 256

///|
enum DocxProjectionRole {
  StoryRoot
  AnnotationCollection
  AnnotationItem
  ElementNode
}

///|
struct DocxProjectionEntry {
  path : String
  parent : String?
  kind : String
  stability : @lib.SelectorStability
  stable_id : String?
  role : DocxProjectionRole
  element : @document.DocumentElement?
  children : Array[String]
  properties : Map[String, String]
  metadata : Json
  source : Json
}

///|
struct DocxProjection {
  file : String
  annotated : @docx.DocxAnnotatedResult
  entries : Array[DocxProjectionEntry]
  entry_index : @sorted_map.SortedMap[String, Int]
  warnings : Array[@lib.ProtocolWarning]
  cancelled : () -> Bool
  mut work_since_yield : Int
}

///|
struct AnnotationDetails {
  metadata : Json
  properties : Map[String, String]
}

///|
struct AnnotationStoryPlan {
  story : String
  kind : String
  pairs : Array[(String, Array[@document.DocumentElement])]
  paths : Array[String]
  missing_ids : Int
  duplicate_ids : Int
  unrepresentable_ids : Int
}

///|
struct AnnotationProjectionIndex {
  comments : Array[@docx.CommentInfo]
  comment_anchors : @sorted_map.SortedMap[String, Json]
  footnote_references : @sorted_map.SortedMap[String, Json]
  endnote_references : @sorted_map.SortedMap[String, Json]
}

///|
struct DocxProjectionBuilder {
  max_elements : Int
  entries : Array[DocxProjectionEntry]
  entry_index : @sorted_map.SortedMap[String, Int]
  warnings : Array[@lib.ProtocolWarning]
  warning_keys : Set[String]
  mut warnings_truncated : Bool
  cancelled : () -> Bool
  mut work_since_yield : Int
}

///|
fn docx_cli_failure(
  code : String,
  message : String,
  details? : Json,
) -> CliFailure {
  CliFailure(@lib.protocol_error(code, message, details?))
}

///|
fn docx_resource_failure(
  resource : String,
  limit : Int,
  actual? : Int,
) -> CliFailure {
  format_resource_failure("docx", resource, limit, actual?)
}

///|
fn docx_reader_failure(
  error : @docx_core.DocxError,
  file : String,
) -> CliFailure {
  let (category, message, resource_limit) = match error {
    InvalidZip(message~) => ("zip", message, None)
    InvalidXml(message~) => ("xml", message, None)
    MissingPart(message~) => ("missing-part", message, None)
    Unsupported(message~) => ("unsupported", message, None)
    ResourceLimit(limit~, message~) => ("xml", message, Some(limit))
    // A write-side ceiling never arises on the read path, but the match
    // must stay exhaustive.
    WriteResourceLimit(message~, ..) => ("write-limit", message, None)
  }
  let normalized = bounded_text(message, 320)
  let code = if resource_limit is Some(_) {
    "office.docx.resource_limit"
  } else {
    "office.docx.read_failed"
  }
  let details : Map[String, Json] = {
    "file": Json::string(bounded_text(file, 160)),
    "category": Json::string(category),
  }
  match resource_limit {
    Some(limit) =>
      details["resource"] = Json::string(docx_xml_resource_name(limit))
    None => ()
  }
  docx_cli_failure(
    code,
    "could not read DOCX \{category}: \{normalized}",
    details=Json::object(details),
  )
}

///|
fn docx_xml_resource_name(limit : @docx_core.DocxXmlResourceLimit) -> String {
  match limit {
    DocxXmlSourceUnits => "xml-source-units"
    DocxXmlTokens => "xml-tokens"
    DocxXmlTokenLength => "xml-token-length"
    DocxXmlMaterializedCharacters => "xml-materialized-characters"
    DocxXmlNestingDepth => "xml-nesting-depth"
  }
}

///|
fn DocxProjectionBuilder::new(
  max_elements : Int,
  cancelled? : () -> Bool = () => false,
) -> DocxProjectionBuilder {
  {
    max_elements,
    entries: [],
    entry_index: SortedMap([]),
    warnings: [],
    warning_keys: Set([]),
    warnings_truncated: false,
    cancelled,
    work_since_yield: 0,
  }
}

///|
fn DocxProjectionBuilder::check_cancelled(
  self : DocxProjectionBuilder,
) -> Unit raise CliFailure {
  check_office_read_cancelled(self.cancelled)
}

///|
async fn DocxProjectionBuilder::cooperate(
  self : DocxProjectionBuilder,
  work? : Int = 1,
) -> Unit {
  self.check_cancelled()
  self.work_since_yield += work.max(0)
  if self.work_since_yield >= docx_cli_projection_yield_elements {
    self.work_since_yield = 0
    @async.pause()
    self.check_cancelled()
  }
}

///|
fn DocxProjection::check_cancelled(
  self : DocxProjection,
) -> Unit raise CliFailure {
  check_office_read_cancelled(self.cancelled)
}

///|
async fn DocxProjection::cooperate(
  self : DocxProjection,
  work? : Int = 1,
) -> Unit {
  self.check_cancelled()
  self.work_since_yield += work.max(0)
  if self.work_since_yield >= docx_cli_projection_yield_elements {
    self.work_since_yield = 0
    @async.pause()
    self.check_cancelled()
  }
}

///|
fn DocxProjectionBuilder::warn(
  self : DocxProjectionBuilder,
  code : String,
  message : String,
) -> Unit {
  let bounded = bounded_text(message, 512)
  let key = code + "\u{0}" + bounded
  if self.warning_keys.contains(key) {
    return
  }
  if self.warnings.length() < docx_cli_max_warnings - 1 {
    self.warning_keys.add(key)
    self.warnings.push(@lib.protocol_warning(code, bounded))
  } else if !self.warnings_truncated {
    self.warnings_truncated = true
    self.warnings.push(
      @lib.protocol_warning(
        "office.docx.warnings_truncated",
        "additional DOCX diagnostics were omitted after \{docx_cli_max_warnings - 1} unique warnings",
      ),
    )
  }
}

///|
fn selector_stability_text(stability : @lib.SelectorStability) -> String {
  match stability {
    Stable => "stable"
    SnapshotRelative => "snapshot-relative"
  }
}

///|
fn DocxProjectionBuilder::require_entry_capacity(
  self : DocxProjectionBuilder,
) -> Unit raise CliFailure {
  self.check_cancelled()
  if self.entries.length() >= self.max_elements {
    raise docx_resource_failure(
      "projection elements",
      self.max_elements,
      actual=self.entries.length() + 1,
    )
  }
}

///|
fn DocxProjectionBuilder::add_entry(
  self : DocxProjectionBuilder,
  path : String,
  parent : String?,
  kind : String,
  stable_id : String?,
  role : DocxProjectionRole,
  element : @document.DocumentElement?,
  properties : Map[String, String],
  metadata : Json,
  source : Json,
) -> DocxProjectionEntry raise CliFailure {
  self.require_entry_capacity()
  let selector = @lib.parse_selector(path) catch {
    SelectorError(code="office.selector.depth_limit", ..) =>
      raise docx_resource_failure(
        "selector path segments",
        @lib.SELECTOR_MAX_DEPTH,
      )
    SelectorError(code~, message~, ..) =>
      raise docx_cli_failure(
        "office.docx.invalid_projection",
        "DOCX reader produced an unaddressable path",
        details=Json::object({
          "path": Json::string(bounded_text(path, 240)),
          "selector_code": Json::string(code),
          "selector_message": Json::string(bounded_text(message, 240)),
        }),
      )
  }
  if selector.render() != path {
    raise docx_cli_failure(
      "office.docx.invalid_projection",
      "DOCX reader produced a non-canonical path",
      details=Json::object({
        "path": Json::string(bounded_text(path, 240)),
        "canonical": Json::string(bounded_text(selector.render(), 240)),
      }),
    )
  }
  if self.entry_index.contains(path) {
    raise docx_cli_failure(
      "office.docx.invalid_projection",
      "DOCX reader produced a duplicate canonical path",
      details=Json::object({ "path": Json::string(bounded_text(path, 240)) }),
    )
  }
  let entry = {
    path,
    parent,
    kind,
    stability: selector.stability(),
    stable_id,
    role,
    element,
    children: [],
    properties,
    metadata,
    source,
  }
  let index = self.entries.length()
  self.entries.push(entry)
  self.entry_index[path] = index
  entry
}

///|
fn optional_property(
  output : Map[String, String],
  name : String,
  value : String?,
) -> Unit {
  match value {
    Some(text) => output[name] = text
    None => ()
  }
}

///|
fn element_query_properties(
  element : @document.DocumentElement,
) -> Map[String, String] {
  let output : Map[String, String] = Map([])
  match element {
    Paragraph(properties~, ..) => {
      optional_property(output, "style_id", properties.style_id)
      optional_property(output, "style_name", properties.style_name)
      optional_property(output, "alignment", properties.alignment)
    }
    Run(properties~, ..) => {
      optional_property(output, "style_id", properties.style_id)
      optional_property(output, "style_name", properties.style_name)
      output["bold"] = properties.is_bold.to_string()
      output["italic"] = properties.is_italic.to_string()
      output["underline"] = properties.is_underline.to_string()
    }
    Table(properties~, ..) => {
      optional_property(output, "style_id", properties.style_id)
      optional_property(output, "style_name", properties.style_name)
    }
    Hyperlink(href~, ..) => optional_property(output, "href", href)
    Image(image) => output["content_type"] = image.content_type
    _ => ()
  }
  output
}

///|
fn annotation_item_root(path : String) -> (String, String)? {
  if !(path.has_prefix("/comments/comment[") ||
    path.has_prefix("/footnotes/note[") ||
    path.has_prefix("/endnotes/note[")) {
    return None
  }
  let rest = path[1:]
  guard rest.find("/") is Some(story_end) else { return None }
  let item_start = story_end + 2
  if item_start >= path.length() {
    return None
  }
  match path[item_start:].find("/") {
    Some(relative) => {
      let suffix_start = item_start + relative
      Some((path[:suffix_start].to_owned(), path[suffix_start:].to_owned()))
    }
    None => Some((path, ""))
  }
}

///|
fn canonical_index_path(
  path : String,
  path_roots : @sorted_map.SortedMap[String, String],
) -> String? {
  match annotation_item_root(path) {
    Some((root, suffix)) => {
      guard path_roots.get(root) is Some(emitted_root) else { return None }
      let candidate = emitted_root + suffix
      try @lib.parse_selector(candidate) catch {
        _ => None
      } noraise {
        selector => Some(selector.render())
      }
    }
    None =>
      try @lib.selector_from_docx_projection_path(path) catch {
        _ => None
      } noraise {
        selector => Some(selector.render())
      }
  }
}

///|
async fn canonical_index_paths(
  paths : Array[String],
  path_roots : @sorted_map.SortedMap[String, String],
  builder : DocxProjectionBuilder,
) -> Json {
  let values : Array[Json] = []
  for path in paths {
    builder.cooperate()
    match canonical_index_path(path, path_roots) {
      Some(canonical) => values.push(Json::string(canonical))
      None => ()
    }
  }
  Json::array(values)
}

///|
async fn comment_anchor_metadata(
  anchor : @docx.AnnotationAnchor,
  path_roots : @sorted_map.SortedMap[String, String],
  builder : DocxProjectionBuilder,
) -> Json {
  let fields : Map[String, Json] = {
    "references": canonical_index_paths(
      anchor.references(),
      path_roots,
      builder,
    ),
  }
  match canonical_index_path(anchor.story(), path_roots) {
    Some(canonical) => fields["story"] = Json::string(canonical)
    None => ()
  }
  match anchor.start() {
    Some(path) =>
      match canonical_index_path(path, path_roots) {
        Some(canonical) => fields["start"] = Json::string(canonical)
        None => ()
      }
    None => ()
  }
  match anchor.end() {
    Some(path) =>
      match canonical_index_path(path, path_roots) {
        Some(canonical) => fields["end"] = Json::string(canonical)
        None => ()
      }
    None => ()
  }
  match anchor.start_boundary() {
    Some(boundary) => fields["start_boundary"] = Json::string("\{boundary}")
    None => ()
  }
  match anchor.end_boundary() {
    Some(boundary) => fields["end_boundary"] = Json::string("\{boundary}")
    None => ()
  }
  Json::object(fields)
}

///|
fn comment_details(
  comments : Array[@docx.CommentInfo],
  ordinal : Int,
  anchors_by_id : @sorted_map.SortedMap[String, Json],
) -> AnnotationDetails {
  let fields : Map[String, Json] = Map([])
  let properties : Map[String, String] = Map([])
  if ordinal > 0 && ordinal <= comments.length() {
    let info = comments[ordinal - 1]
    fields["defined"] = Json::boolean(info.defined())
    fields["body_paragraphs"] = Json::number(info.body_paragraphs().to_double())
    match info.author() {
      Some(value) => {
        fields["author"] = Json::string(value)
        properties["author"] = value
      }
      None => ()
    }
    match info.initials() {
      Some(value) => fields["initials"] = Json::string(value)
      None => ()
    }
    match info.date() {
      Some(value) => fields["date"] = Json::string(value)
      None => ()
    }
    match info.done() {
      Some(value) => {
        fields["done"] = Json::boolean(value)
        properties["done"] = value.to_string()
      }
      None => ()
    }
    match info.parent_id() {
      Some(value) => fields["parent_id"] = Json::string(value)
      None => ()
    }
    fields["anchors"] = anchors_by_id.get(info.id()).unwrap_or(Json::array([]))
  }
  { metadata: Json::object(fields), properties }
}

///|
fn note_details(
  references_by_id : @sorted_map.SortedMap[String, Json],
  id : String,
) -> AnnotationDetails {
  let fields : Map[String, Json] = Map([])
  match references_by_id.get(id) {
    Some(references) => fields["references"] = references
    None => ()
  }
  { metadata: Json::object(fields), properties: Map([]) }
}

///|
fn has_at_most_chars(value : String, maximum : Int) -> Bool {
  let mut count = 0
  for _ in value {
    count += 1
    if count > maximum {
      return false
    }
  }
  true
}

///|
fn stable_annotation_path(
  story : String,
  kind : String,
  id : String,
) -> String? {
  if id == "" || !has_at_most_chars(id, @lib.SELECTOR_MAX_VALUE_LENGTH) {
    return None
  }
  let candidate = "/docx/\{story}/\{kind}[id=\{Json::string(id).stringify()}]"
  try @lib.parse_selector(candidate) catch {
    _ => None
  } noraise {
    selector =>
      if selector.render() == candidate {
        Some(candidate)
      } else {
        None
      }
  }
}

///|
async fn annotation_id_counts(
  pairs : Array[(String, Array[@document.DocumentElement])],
  builder : DocxProjectionBuilder,
) -> @sorted_map.SortedMap[String, Int] {
  let counts : @sorted_map.SortedMap[String, Int] = SortedMap([])
  for pair in pairs {
    builder.cooperate()
    let (id, _) = pair
    counts[id] = counts.get(id).unwrap_or(0) + 1
  }
  counts
}

///|
async fn annotation_story_plan(
  story : String,
  kind : String,
  pairs : Array[(String, Array[@document.DocumentElement])],
  builder : DocxProjectionBuilder,
) -> AnnotationStoryPlan {
  let collection_path = "/docx/\{story}"
  let counts = annotation_id_counts(pairs, builder)
  let paths : Array[String] = []
  let mut duplicate_ids = 0
  let mut missing_ids = 0
  let mut unrepresentable_ids = 0
  for index, pair in pairs {
    builder.cooperate()
    let ordinal = index + 1
    let (id, _) = pair
    let occurrence_count = counts.get(id).unwrap_or(0)
    let stable_path = if occurrence_count == 1 {
      stable_annotation_path(story, kind, id)
    } else {
      None
    }
    paths.push(
      match stable_path {
        Some(value) => value
        None => "\{collection_path}/\{kind}[\{ordinal}]"
      },
    )
    if id == "" {
      missing_ids += 1
    } else if occurrence_count > 1 {
      duplicate_ids += 1
    } else if stable_path is None {
      unrepresentable_ids += 1
    }
  }
  { story, kind, pairs, paths, missing_ids, duplicate_ids, unrepresentable_ids }
}

///|
async fn add_annotation_path_roots(
  output : @sorted_map.SortedMap[String, String],
  plan : AnnotationStoryPlan,
  builder : DocxProjectionBuilder,
) -> Unit {
  for index, path in plan.paths {
    builder.cooperate()
    output["/\{plan.story}/\{plan.kind}[\{index + 1}]"] = path
  }
}

///|
async fn index_notes(
  notes : Array[@docx.NoteInfo],
  builder : DocxProjectionBuilder,
) -> @sorted_map.SortedMap[String, @docx.NoteInfo] {
  let output : @sorted_map.SortedMap[String, @docx.NoteInfo] = SortedMap([])
  for note in notes {
    builder.cooperate()
    let id = note.id()
    if !output.contains(id) {
      output[id] = note
    }
  }
  output
}

///|
async fn index_comment_anchors(
  comments : Array[@docx.CommentInfo],
  path_roots : @sorted_map.SortedMap[String, String],
  builder : DocxProjectionBuilder,
) -> @sorted_map.SortedMap[String, Json] {
  let output : @sorted_map.SortedMap[String, Json] = SortedMap([])
  for info in comments {
    builder.cooperate()
    let id = info.id()
    if output.contains(id) {
      continue
    }
    let anchors : Array[Json] = []
    for anchor in info.anchors() {
      builder.cooperate()
      anchors.push(comment_anchor_metadata(anchor, path_roots, builder))
    }
    output[id] = Json::array(anchors)
  }
  output
}

///|
async fn index_note_references(
  notes : @sorted_map.SortedMap[String, @docx.NoteInfo],
  path_roots : @sorted_map.SortedMap[String, String],
  builder : DocxProjectionBuilder,
) -> @sorted_map.SortedMap[String, Json] {
  let output : @sorted_map.SortedMap[String, Json] = SortedMap([])
  for id, note in notes {
    builder.cooperate()
    output[id] = canonical_index_paths(note.references(), path_roots, builder)
  }
  output
}

///|
async fn annotation_projection_index(
  annotated : @docx.DocxAnnotatedResult,
  footnotes : AnnotationStoryPlan,
  endnotes : AnnotationStoryPlan,
  comments : AnnotationStoryPlan,
  builder : DocxProjectionBuilder,
) -> AnnotationProjectionIndex {
  let path_roots : @sorted_map.SortedMap[String, String] = SortedMap([])
  add_annotation_path_roots(path_roots, footnotes, builder)
  add_annotation_path_roots(path_roots, endnotes, builder)
  add_annotation_path_roots(path_roots, comments, builder)
  let annotations = annotated.annotations()
  let comment_infos = annotations.comments()
  let footnote_infos = index_notes(annotations.footnotes(), builder)
  let endnote_infos = index_notes(annotations.endnotes(), builder)
  {
    comments: comment_infos,
    comment_anchors: index_comment_anchors(comment_infos, path_roots, builder),
    footnote_references: index_note_references(
      footnote_infos, path_roots, builder,
    ),
    endnote_references: index_note_references(
      endnote_infos, path_roots, builder,
    ),
  }
}

///|
async fn DocxProjectionBuilder::walk_element_children(
  self : DocxProjectionBuilder,
  parent : DocxProjectionEntry,
  element : @document.DocumentElement,
) -> Unit {
  let counters : Map[String, Int] = Map([])
  for child in @docx_paths.element_children(element) {
    self.cooperate()
    match @docx_paths.segment_kind(child) {
      Some(kind) => {
        let ordinal = counters.get(kind).unwrap_or(0) + 1
        counters[kind] = ordinal
        let path = "\{parent.path}/\{kind}[\{ordinal}]"
        let entry = self.add_entry(
          path,
          Some(parent.path),
          kind,
          None,
          ElementNode,
          Some(child),
          element_query_properties(child),
          Json::empty_object(),
          parent.source,
        )
        parent.children.push(path)
        self.walk_element_children(entry, child)
      }
      None => ()
    }
  }
}

///|
async fn DocxProjectionBuilder::add_story(
  self : DocxProjectionBuilder,
  path : String,
  kind : String,
  body : Array[@document.DocumentElement],
  source : Json,
) -> Unit {
  let document = @document.document(body)
  let root = self.add_entry(
    path,
    None,
    kind,
    None,
    StoryRoot,
    Some(document),
    Map([]),
    Json::empty_object(),
    source,
  )
  self.walk_element_children(root, document)
}

///|
fn docx_story_source_fields(
  story : String,
  source : @docx.DocxStoryPartSource?,
) -> Map[String, Json] {
  let fields : Map[String, Json] = { "story": Json::string(story) }
  match source {
    Some(value) => {
      fields["part"] = Json::string(value.part())
      fields["authority"] = Json::string(value.authority().name())
    }
    None => fields["authority"] = Json::string("absent")
  }
  fields
}

///|
async fn DocxProjectionBuilder::add_annotation_story(
  self : DocxProjectionBuilder,
  annotation_index : AnnotationProjectionIndex,
  plan : AnnotationStoryPlan,
  source : @docx.DocxStoryPartSource?,
) -> Unit {
  let story = plan.story
  let kind = plan.kind
  let pairs = plan.pairs
  let collection_path = "/docx/\{story}"
  let combined_body : Array[@document.DocumentElement] = []
  for pair in pairs {
    let (_, body) = pair
    for element in body {
      self.cooperate()
      combined_body.push(element)
    }
  }
  let collection_source = docx_story_source_fields(story, source)
  let collection = self.add_entry(
    collection_path,
    None,
    story,
    None,
    AnnotationCollection,
    Some(@document.document(combined_body)),
    Map([]),
    Json::object({ "items": Json::number(pairs.length().to_double()) }),
    Json::object(collection_source),
  )
  for item_index, pair in pairs {
    self.cooperate()
    self.require_entry_capacity()
    let ordinal = item_index + 1
    let (id, body) = pair
    let path = plan.paths[item_index]
    let details = if story == "comments" {
      comment_details(
        annotation_index.comments,
        ordinal,
        annotation_index.comment_anchors,
      )
    } else if story == "footnotes" {
      note_details(annotation_index.footnote_references, id)
    } else {
      note_details(annotation_index.endnote_references, id)
    }
    let metadata_fields : Map[String, Json] = {
      "id": Json::string(id),
      "ordinal": Json::number(ordinal.to_double()),
    }
    match details.metadata {
      Object(values) =>
        for key, value in values {
          metadata_fields[key] = value
        }
      _ => ()
    }
    let item_source = docx_story_source_fields(story, source)
    item_source["ordinal"] = Json::number(ordinal.to_double())
    let item = self.add_entry(
      path,
      Some(collection_path),
      kind,
      if id == "" {
        None
      } else {
        Some(id)
      },
      AnnotationItem,
      Some(@document.document(body)),
      details.properties,
      Json::object(metadata_fields),
      Json::object(item_source),
    )
    collection.children.push(path)
    self.walk_element_children(item, @document.document(body))
  }
  if plan.missing_ids > 0 {
    self.warn(
      "office.docx.missing_annotation_id",
      "\{plan.missing_ids} \{story} item(s) have an empty id and therefore use snapshot-relative positional paths",
    )
  }
  if plan.duplicate_ids > 0 {
    self.warn(
      "office.docx.duplicate_annotation_id",
      "\{plan.duplicate_ids} \{story} item(s) share duplicate ids and therefore use snapshot-relative positional paths",
    )
  }
  if plan.unrepresentable_ids > 0 {
    self.warn(
      "office.docx.unrepresentable_annotation_id",
      "\{plan.unrepresentable_ids} \{story} item(s) have ids outside office.selector/1 limits and therefore use snapshot-relative positional paths",
    )
  }
}

///|
fn document_body_elements(
  document : @document.DocumentElement,
) -> Array[@document.DocumentElement] {
  match document {
    Document(children~, ..) => children
    other => [other]
  }
}

///|
async fn projection_from_annotated(
  file : String,
  annotated : @docx.DocxAnnotatedResult,
  max_elements : Int,
  cancelled? : () -> Bool = () => false,
) -> DocxProjection {
  let builder = DocxProjectionBuilder::new(max_elements, cancelled~)
  builder.cooperate(work=docx_cli_projection_yield_elements)
  let result = annotated.result()
  let footnotes = annotation_story_plan(
    "footnotes",
    "note",
    annotated.footnote_bodies(),
    builder,
  )
  let endnotes = annotation_story_plan(
    "endnotes",
    "note",
    annotated.endnote_bodies(),
    builder,
  )
  let comments = annotation_story_plan(
    "comments",
    "comment",
    annotated.comment_bodies(),
    builder,
  )
  let annotations = annotation_projection_index(
    annotated, footnotes, endnotes, comments, builder,
  )
  let header_sources = annotated.header_story_sources()
  let footer_sources = annotated.footer_story_sources()
  builder.add_story(
    "/docx/body",
    "body",
    document_body_elements(result.document),
    Json::object(
      docx_story_source_fields("body", Some(annotated.main_story_source())),
    ),
  )
  for index, header in result.headers {
    builder.cooperate()
    let source = docx_story_source_fields("header", header_sources.get(index))
    source["part_index"] = Json::number((index + 1).to_double())
    builder.add_story(
      "/docx/header[\{index + 1}]",
      "header",
      header.body,
      Json::object(source),
    )
  }
  for index, footer in result.footers {
    builder.cooperate()
    let source = docx_story_source_fields("footer", footer_sources.get(index))
    source["part_index"] = Json::number((index + 1).to_double())
    builder.add_story(
      "/docx/footer[\{index + 1}]",
      "footer",
      footer.body,
      Json::object(source),
    )
  }
  builder.add_annotation_story(
    annotations,
    footnotes,
    annotated.footnotes_story_source(),
  )
  builder.add_annotation_story(
    annotations,
    endnotes,
    annotated.endnotes_story_source(),
  )
  builder.add_annotation_story(
    annotations,
    comments,
    annotated.comments_story_source(),
  )
  for message in result.messages {
    builder.cooperate()
    match message {
      Warning(text) => builder.warn("office.docx.reader_warning", text)
      Error(text) => builder.warn("office.docx.reader_error", text)
    }
  }
  {
    file,
    annotated,
    entries: builder.entries,
    entry_index: builder.entry_index,
    warnings: builder.warnings,
    cancelled,
    work_since_yield: 0,
  }
}

///|
fn validate_docx_read_archive(
  file : String,
  archive : @zip.Archive,
  cancelled? : () -> Bool = () => false,
) -> String raise CliFailure {
  check_office_read_cancelled(cancelled)
  let lower = file.to_lower()
  if lower.has_suffix(".xlsx") {
    raise docx_cli_failure(
      "office.unsupported_operation",
      "DOCX structured reads are not available for XLSX packages",
      details=Json::object({
        "format": Json::string("xlsx"),
        "supported_format": Json::string("docx"),
      }),
    )
  }
  if !lower.has_suffix(".docx") {
    raise docx_cli_failure(
      "office.unsupported_extension",
      "unsupported file extension for '\{bounded_text(file, 160)}' (expected .docx)",
      details=Json::object({
        "file": Json::string(bounded_text(file, 160)),
        "expected_extensions": Json::array([Json::string("docx")]),
      }),
    )
  }
  let report = @opc.validate_docx_archive_report_limited(
    archive,
    max_findings=docx_cli_max_warnings,
    max_message_chars=512,
    max_xml_source_units=docx_cli_max_xml_source_units,
    max_xml_tokens=docx_cli_max_xml_tokens,
    max_xml_materialized_chars=docx_cli_max_xml_materialized_chars,
    max_xml_token_chars=docx_cli_max_xml_token_chars,
    cancelled~,
  )
  check_office_read_cancelled(cancelled)
  match report.resource_limit() {
    Some(limit) =>
      raise docx_cli_failure(
        "office.docx.resource_limit",
        "DOCX package validation exceeded configured XML parser limits",
        details=Json::object({
          "file": Json::string(bounded_text(file, 160)),
          "resource": Json::string(limit.name()),
        }),
      )
    None => ()
  }
  let findings = report.findings()
  let truncated = report.findings_truncated()
  if truncated || findings.length() > 0 {
    let details : Map[String, Json] = {
      "file": Json::string(bounded_text(file, 160)),
      "findings_truncated": Json::boolean(truncated),
    }
    if findings.length() > 0 {
      details["finding"] = Json::string(findings[0])
    }
    raise docx_cli_failure(
      "office.invalid_package",
      "invalid DOCX package: structural validation failed",
      details=Json::object(details),
    )
  }
  match report.main_document_part() {
    Some(part) => part
    None =>
      raise docx_cli_failure(
        "office.invalid_package",
        "invalid DOCX package: validation did not identify a main document part",
        details=Json::object({ "file": Json::string(bounded_text(file, 160)) }),
      )
  }
}

///|
async fn open_docx_projection_archive(
  file : String,
  archive : @zip.Archive,
  max_elements : Int,
  cancelled? : () -> Bool = () => false,
) -> DocxProjection {
  check_office_read_cancelled(cancelled)
  if max_elements < 1 || max_elements > docx_cli_hard_max_elements {
    raise docx_cli_failure(
      "office.invalid_arguments",
      "--max-elements must be between 1 and \{docx_cli_hard_max_elements}",
      details=Json::object({
        "argument": Json::string("max-elements"),
        "minimum": Json::number(1),
        "maximum": Json::number(docx_cli_hard_max_elements.to_double()),
      }),
    )
  }
  @async.pause()
  check_office_read_cancelled(cancelled)
  let main_document_part = validate_docx_read_archive(file, archive, cancelled~)
  @async.pause()
  check_office_read_cancelled(cancelled)
  let xml_budget = @xml.xml_read_budget(
    max_source_units=docx_cli_max_xml_source_units,
    max_tokens=docx_cli_max_xml_tokens,
    max_materialized_chars=docx_cli_max_xml_materialized_chars,
    max_token_chars=docx_cli_max_xml_token_chars,
    cancelled~,
  )
  let annotated = @docx.read_docx_annotated_archive_tolerant_limited(
    archive,
    xml_budget,
    max_diagnostics=docx_cli_max_warnings,
    max_diagnostic_chars=512,
    expected_main_document_path=main_document_part,
  ) catch {
    error => {
      check_office_read_cancelled(cancelled)
      raise docx_reader_failure(error, file)
    }
  }
  check_office_read_cancelled(cancelled)
  @async.pause()
  projection_from_annotated(file, annotated, max_elements, cancelled~)
}
