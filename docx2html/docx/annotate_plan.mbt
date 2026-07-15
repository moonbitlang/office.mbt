// L1 plan building: everything between "a validated CommentSpec plus
// two anchor paragraphs" and "a SplicePlan ready to splice" lives HERE,
// in a testable package, so the SDK gates exercise the exact wiring the
// CLI ships (review round 1). Fail-closed throughout; the caller owns
// file IO, the two validation belts, and atomic publication.

///|
/// Builds the splice plan that adds one comment to the ORIGINAL
/// package: anchor markers into the main part at scanner offsets
/// (self-closing paragraphs rewritten by their own extent), the
/// definition into the existing comments part (self-closing roots
/// rewritten too) or a fresh part derived from the MAIN part's
/// directory, wired with a parsed-not-guessed relationship id and a
/// content-type Override located at the BYTE level. Returns the plan
/// and the allocated comment id.
pub fn plan_comment_addition(
  annotated : DocxAnnotatedResult,
  original : BytesView,
  at_relative~ : String,
  to_relative~ : String,
  spec : CommentSpec,
  max_fragment_bytes? : Int = 8 * 1024 * 1024,
) -> (@splice.SplicePlan, String) raise DocxError {
  let xml_budget = default_annotation_planner_xml_budget()
  plan_comment_addition_zip(
    annotated,
    open_zip(original),
    at_relative~,
    to_relative~,
    spec,
    max_fragment_bytes,
    xml_budget,
  )
}

///|
/// Archive-backed form used by preservation-safe edit sessions. It reuses the
/// caller's already bounded, materialized package and never inflates the DOCX
/// a second time.
pub fn plan_comment_addition_archive(
  annotated : DocxAnnotatedResult,
  archive : @mbtzip.Archive,
  at_relative~ : String,
  to_relative~ : String,
  spec : CommentSpec,
  xml_budget? : @xml.XmlReadBudget,
  max_fragment_bytes? : Int = 8 * 1024 * 1024,
) -> (@splice.SplicePlan, String) raise DocxError {
  let xml_budget = match xml_budget {
    Some(value) => value
    None => default_annotation_planner_xml_budget()
  }
  plan_comment_addition_zip(
    annotated,
    open_zip_archive(archive),
    at_relative~,
    to_relative~,
    spec,
    max_fragment_bytes,
    xml_budget,
  )
}

///|
fn plan_comment_addition_zip(
  annotated : DocxAnnotatedResult,
  zip : ZipArchive,
  at_relative~ : String,
  to_relative~ : String,
  spec : CommentSpec,
  max_fragment_bytes : Int,
  xml_budget : @xml.XmlReadBudget,
) -> (@splice.SplicePlan, String) raise DocxError {
  check_mutation_gates(annotated)
  // Anchor spans — misses report the sibling count so agents can
  // correct the ordinal, matching the paths-layer error shape.
  guard annotated.body_paragraph_span(at_relative) is Some(at_span) else {
    raise Unsupported(
      message="'/body/\{at_relative}' does not name a body paragraph (\{describe_paragraph_siblings(annotated, at_relative)})",
    )
  }
  guard annotated.body_paragraph_span(to_relative) is Some(to_span) else {
    raise Unsupported(
      message="'/body/\{to_relative}' does not name a body paragraph (\{describe_paragraph_siblings(annotated, to_relative)})",
    )
  }
  if to_span.byte_start() < at_span.byte_start() {
    raise Unsupported(
      message="the range end precedes its start in the document (the range is inclusive and must be ordered)",
    )
  }
  // Dense id allocation with NUMERIC identity: ST_DecimalNumber makes
  // "0000000000" and "0" the same id, so literal spellings alone are
  // not collision-safe. Numeric ids canonicalize (leading zeros
  // stripped); a canonical id beyond nine digits is outside the range
  // this allocator reasons about and fails closed.
  let used_numeric : Set[Int] = Set([])
  let mut max_numeric = -1
  for comment in annotated.annotations().comments() {
    match canonical_comment_id(comment.id()) {
      CanonicalNumeric(value) => {
        used_numeric.add(value)
        if value > max_numeric {
          max_numeric = value
        }
      }
      NonNumeric => ()
      OutOfRange =>
        raise Unsupported(
          message="the document holds comment id '\{comment.id()}', outside the supported numeric range; refusing to annotate",
        )
    }
  }
  let mut candidate = max_numeric + 1
  while used_numeric.contains(candidate) {
    candidate += 1
  }
  // Never publish an id the allocator itself refuses to read back
  // (nine decimal digits is the supported range).
  if candidate > 999_999_999 {
    raise Unsupported(
      message="cannot allocate a comment id: the document already uses the maximum supported id",
    )
  }
  let new_id = candidate.to_string()
  // Fragments (namespace-self-contained per the L0 locked rule).
  let main_wordprocessing_namespace = annotated.main_wordprocessing_namespace()
  let definition_namespace = annotated.comment_definition_namespace()
  let (start_fragment, end_fragment) = comment_anchor_fragments(
    id=new_id,
    wordprocessing_namespace=main_wordprocessing_namespace,
  )
  let definition = comment_definition_fragment(
    spec,
    id=new_id,
    max_output_bytes=max_fragment_bytes,
    wordprocessing_namespace=definition_namespace,
  )
  let main_part = annotated.main_story_part()
  guard zip.read_bytes(main_part) is Some(main_bytes) else {
    raise Unsupported(message="the package is missing its main part")
  }
  let plan = @splice.SplicePlan::new()
  if at_relative == to_relative {
    queue_paragraph_edits(
      plan,
      main_part,
      main_bytes,
      at_span,
      Some(start_fragment),
      Some(end_fragment),
    )
  } else {
    queue_paragraph_edits(
      plan,
      main_part,
      main_bytes,
      at_span,
      Some(start_fragment),
      None,
    )
    queue_paragraph_edits(
      plan,
      main_part,
      main_bytes,
      to_span,
      None,
      Some(end_fragment),
    )
  }
  match annotated.comments_part() {
    Some(comments_part) => {
      guard annotated.story_root_span("/comments") is Some(root) else {
        raise Unsupported(
          message="the comments part could not be scanned; refusing to annotate",
        )
      }
      match root.close_tag_start() {
        Some(insert_at) =>
          plan.edit_part(
            comments_part,
            @splice.span_edit(
              start=insert_at,
              end=insert_at,
              @utf8.encode(definition),
            ),
          )
        None => {
          // A self-closing (empty but wired) comments root: rewrite it
          // by its own extent, like a self-closing paragraph.
          guard zip.read_bytes(comments_part) is Some(comments_bytes) else {
            raise Unsupported(message="the comments part is unreadable")
          }
          plan.edit_part(
            comments_part,
            self_closing_rewrite(comments_bytes, root, definition),
          )
        }
      }
    }
    None => {
      // Create the part NEXT TO the main part. OPC relationship and
      // [Content_Types] names are logical IRIs, while SplicePlan additions are
      // physical ASCII ZIP item names; keep both identities explicit.
      let comments_path = main_sibling_mutation_part_path(
        annotated, zip, "comments.xml",
      )
      // An entry with that name but NO comments relationship is an
      // ORPHAN part: splicing definitions into it would leave them
      // disconnected, and overwriting it would destroy data.
      if zip.exists(comments_path.logical) {
        raise Unsupported(
          message="'\{comments_path.logical}' exists but is not wired as the comments part (an orphan); refusing to annotate",
        )
      }
      let part_text = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>" +
        "<w:comments xmlns:w=\"\{main_wordprocessing_namespace}\">" +
        definition +
        "</w:comments>"
      plan.add_part(comments_path.physical, @utf8.encode(part_text))
      let rels_path = main_relationships_mutation_part_path(annotated, zip)
      let relationship_type = annotated.new_comments_relationship_type()
      match zip.resolve_path(rels_path.logical) {
        Some(actual_rels_part) => {
          guard zip.read_bytes(actual_rels_part) is Some(rels_bytes) else {
            raise Unsupported(
              message="the package index lost '\{actual_rels_part}'; refusing to annotate",
            )
          }
          // Allocate the id by PARSING the rels part — quoting and
          // whitespace variants make substring probes unsound. Parse
          // bytes directly under the caller's cumulative mutation budget.
          let rels_root = read_mutation_relationships(
            actual_rels_part, rels_bytes, xml_budget,
          )
          let existing_ids : StableStringSet = SortedSet([])
          collect_relationship_ids(rels_root, existing_ids)
          let mut ordinal = 1
          while existing_ids.contains("rIdAnnotate\{ordinal}") {
            ordinal += 1
          }
          let rels_span = scan_xml_root_span(actual_rels_part, rels_bytes)
          let relationship_name = qualified_child_name(
            rels_span.name,
            "Relationship",
          )
          let relationship = "<\{relationship_name} Id=\"rIdAnnotate\{ordinal}\" Type=\"\{relationship_type}\" Target=\"comments.xml\"/>"
          plan.edit_part(
            actual_rels_part,
            xml_root_child_edit(rels_bytes, rels_span, relationship),
          )
        }
        None =>
          // A main part with no relationships part is legal; create it.
          plan.add_part(
            rels_path.physical,
            @utf8.encode(
              "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>" +
              "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">" +
              "<Relationship Id=\"rIdAnnotate1\" Type=\"\{relationship_type}\" Target=\"comments.xml\"/>" +
              "</Relationships>",
            ),
          )
      }
      guard zip.resolve_path("[Content_Types].xml") is Some(types_part) else {
        raise Unsupported(message="the package is missing [Content_Types].xml")
      }
      guard zip.read_bytes(types_part) is Some(types_bytes) else {
        raise Unsupported(message="the package index lost '\{types_part}'")
      }
      read_mutation_xml_root(
        types_part,
        types_bytes,
        xml_budget,
        expected_root="content-types:Types",
      )
      |> ignore
      let types_span = scan_xml_root_span(types_part, types_bytes)
      let override_name = qualified_child_name(types_span.name, "Override")
      plan.edit_part(
        types_part,
        xml_root_child_edit(
          types_bytes,
          types_span,
          opc_content_type_override_fragment(
            override_name,
            comments_path.logical,
            "application/vnd.openxmlformats-officedocument.wordprocessingml.comments+xml",
          ),
        ),
      )
    }
  }
  pin_splice_sources(plan, zip)
  (plan, new_id)
}

///|
/// Pins every offset-bearing edit to the exact payload from which its spans
/// were derived. This turns annotation plans into safe inputs for D1 edit
/// sessions while leaving the lower-level unpinned splice API available.
fn pin_splice_sources(
  plan : @splice.SplicePlan,
  zip : ZipArchive,
) -> Unit raise DocxError {
  for part in plan.unpinned_edited_parts() {
    guard zip.resolve_path(part) is Some(actual) && actual == part else {
      raise Unsupported(
        message="the splice plan does not preserve the source spelling of '\{part}'",
      )
    }
    guard zip.read_bytes(actual) is Some(source) else {
      raise Unsupported(message="the package index lost '\{actual}'")
    }
    plan.pin_part(part, source)
  }
}

///|
/// The shared mutation gates: sidecars (relationship AND content type)
/// and structurally unrepairable annotation identity state.
fn check_mutation_gates(
  annotated : DocxAnnotatedResult,
) -> Unit raise DocxError {
  let sidecars = annotated.annotation_sidecars()
  if sidecars.length() > 0 {
    raise Unsupported(
      message="the document carries annotation sidecar parts this tool cannot keep consistent (\{sidecars.join(", ")}); refusing to annotate",
    )
  }
  check_annotation_identity_state(annotated)
}

///|
fn check_annotation_identity_state(
  annotated : DocxAnnotatedResult,
) -> Unit raise DocxError {
  match
    (annotated.main_relationship_dialect, annotated.main_wordprocessing_dialect) {
    (Some(TransitionalOoxml), Some(StrictOoxml))
    | (Some(StrictOoxml), Some(TransitionalOoxml)) =>
      raise Unsupported(
        message="the officeDocument relationship dialect does not match the main WordprocessingML namespace; refusing to annotate",
      )
    _ => ()
  }
  match annotated.main_wordprocessing_dialect {
    Some(main_dialect) =>
      for identity in annotated.index.dialect_identities {
        if !same_ooxml_dialect(
            identity.relationship_dialect,
            identity.root_dialect,
          ) {
          raise Unsupported(
            message="the \{identity.kind} relationship dialect does not match the target WordprocessingML namespace at '\{identity.path}'; refusing to annotate",
          )
        }
        if !same_ooxml_dialect(identity.root_dialect, main_dialect) {
          raise Unsupported(
            message="the \{identity.kind} annotation story at '\{identity.path}' does not match the main WordprocessingML dialect; refusing to annotate",
          )
        }
      }
    None =>
      if !annotated.index.dialect_identities.is_empty() {
        raise Unsupported(
          message="the main story's WordprocessingML dialect could not be determined; refusing to annotate",
        )
      }
  }
  for orphan in annotated.orphan_annotation_parts {
    let (path, role) = orphan
    raise Unsupported(
      message="'\{path}' exists but is not wired as the \{role} part (an orphan); refusing to annotate",
    )
  }
  let index = annotated.annotations()
  if !index.identity_source_complete {
    raise Unsupported(
      message="the document's annotation identity sources could not be parsed and scanned completely; refusing to annotate",
    )
  }
  let definition_spellings : StableStringMap[String] = SortedMap([])
  let last_para_ids : StableStringSet = SortedSet([])
  for comment in index.comments {
    if !comment.defined {
      continue
    }
    let canonical_id = match canonical_comment_id(comment.id) {
      CanonicalNumeric(value) => value.to_string()
      NonNumeric =>
        raise Unsupported(
          message="the document holds a comment definition whose w:id is not a supported ST_DecimalNumber; refusing to annotate",
        )
      OutOfRange =>
        raise Unsupported(
          message="the document holds a comment definition whose w:id is outside the supported numeric range; refusing to annotate",
        )
    }
    match definition_spellings.get(canonical_id) {
      Some(_) =>
        raise Unsupported(
          message="the document holds multiple comment definitions for numeric id \{canonical_id}; refusing to annotate",
        )
      None => definition_spellings[canonical_id] = comment.id
    }
    match comment.last_para_id {
      Some(raw_para_id) => {
        guard canonical_para_identity(raw_para_id) is Some(para_id) else {
          raise Unsupported(
            message="the document holds a comment whose last paragraph has an invalid w14:paraId; refusing to annotate",
          )
        }
        if last_para_ids.contains(para_id) {
          raise Unsupported(
            message="the document holds multiple comments with last-paragraph paraId \{para_id}; refusing to annotate",
          )
        }
        last_para_ids.add(para_id)
      }
      None => ()
    }
  }
  fn check_story_markers(scan : StoryScan) -> Unit raise DocxError {
    for marker in scan.markers {
      match marker.kind {
        CommentStart | CommentEnd | CommentRef => ()
        FootnoteRef | EndnoteRef => continue
      }
      let canonical_id = match canonical_comment_id(marker.id) {
        CanonicalNumeric(value) => value.to_string()
        NonNumeric =>
          raise Unsupported(
            message="the document holds a comment marker whose w:id is not a supported ST_DecimalNumber; refusing to annotate",
          )
        OutOfRange =>
          raise Unsupported(
            message="the document holds a comment marker whose w:id is outside the supported numeric range; refusing to annotate",
          )
      }
      match definition_spellings.get(canonical_id) {
        None =>
          raise Unsupported(
            message="the document holds a marker for comment id \{canonical_id} without a definition; refusing to annotate",
          )
        Some(definition_spelling) if definition_spelling != marker.id =>
          raise Unsupported(
            message="the document uses multiple lexical spellings for numeric comment id \{canonical_id}; refusing to annotate",
          )
        Some(_) => ()
      }
    }
  }
  for story_entry in index.scans {
    let (_, scan) = story_entry
    check_story_markers(scan)
  }
  for scan in index.identity_only_scans {
    check_story_markers(scan)
  }
  let comment_ex_para_ids : StableStringSet = SortedSet([])
  for identity in index.comment_ex_identities {
    guard identity.para_id is Some(raw_para_id) else {
      raise Unsupported(
        message="the document holds a commentsExtended record without w15:paraId; refusing to annotate",
      )
    }
    guard canonical_para_identity(raw_para_id) is Some(para_id) else {
      raise Unsupported(
        message="the document holds a commentsExtended record with an invalid w15:paraId; refusing to annotate",
      )
    }
    if comment_ex_para_ids.contains(para_id) {
      raise Unsupported(
        message="the document holds multiple commentsExtended records for paraId \{para_id}; refusing to annotate",
      )
    }
    comment_ex_para_ids.add(para_id)
    if !last_para_ids.contains(para_id) {
      raise Unsupported(
        message="the document holds a commentsExtended record for unknown paraId \{para_id}; refusing to annotate",
      )
    }
    match identity.parent_para_id {
      Some(raw_parent) => {
        guard canonical_para_identity(raw_parent) is Some(parent) else {
          raise Unsupported(
            message="the document holds a commentsExtended record with an invalid parent paraId; refusing to annotate",
          )
        }
        if parent == para_id || !last_para_ids.contains(parent) {
          raise Unsupported(
            message="the document holds a commentsExtended record with an unknown or self-referential parent paraId; refusing to annotate",
          )
        }
      }
      None => ()
    }
  }
}

///|
fn canonical_para_identity(value : String) -> String? {
  if value.length() != 8 {
    return None
  }
  let builder = StringBuilder::new()
  for unit in value {
    let code = unit.to_int()
    if code >= '0'.to_int() && code <= '9'.to_int() {
      builder.write_char(unit)
    } else if code >= 'a'.to_int() && code <= 'f'.to_int() {
      builder.write_char((code - 32).to_char().unwrap_or('?'))
    } else if code >= 'A'.to_int() && code <= 'F'.to_int() {
      builder.write_char(unit)
    } else {
      return None
    }
  }
  Some(builder.to_string())
}

///|
/// Rejects annotation state that cannot safely serve as the result of a
/// comment mutation. This is the candidate-side counterpart to the planners'
/// source gate and catches duplicate or ambiguous identities introduced by a
/// caller-supplied generic splice plan.
pub fn validate_annotation_identity_state(
  annotated : DocxAnnotatedResult,
) -> Unit raise DocxError {
  check_annotation_identity_state(annotated)
}

///|
priv enum CommentIdClass {
  CanonicalNumeric(Int)
  NonNumeric
  OutOfRange
}

///|
/// ST_DecimalNumber identity: all-digit ids canonicalize by stripping
/// leading zeros; canonical forms beyond nine digits are out of range.
fn canonical_comment_id(id : String) -> CommentIdClass {
  if id.length() == 0 {
    return NonNumeric
  }
  for unit in id {
    let code = unit.to_int()
    if code < '0'.to_int() || code > '9'.to_int() {
      return NonNumeric
    }
  }
  let mut start = 0
  let units = id.code_units()
  while start < units.length() - 1 && units[start].to_int() == '0'.to_int() {
    start += 1
  }
  let canonical_digits = units.length() - start
  if canonical_digits > 9 {
    return OutOfRange
  }
  let mut value = 0
  for at in start..<units.length() {
    value = value * 10 + (units[at].to_int() - '0'.to_int())
  }
  CanonicalNumeric(value)
}

///|
fn is_mutation_xml_resource_error(message : String) -> Bool {
  message == "XML source budget exceeded" ||
  message == "XML token budget exceeded" ||
  message == "XML token length budget exceeded" ||
  message == "XML materialized character budget exceeded" ||
  message == "XML nesting too deep"
}

///|
/// Strictly parses a relationship part under the one cumulative budget owned
/// by the annotation operation. Resource failures retain their typed XML
/// error so transaction callers can report `office.docx.resource_limit`;
/// malformed input keeps the planner's fail-closed relationship diagnostic.
fn read_mutation_relationships(
  part : String,
  bytes : BytesView,
  xml_budget : @xml.XmlReadBudget,
) -> XmlElement raise DocxError {
  read_mutation_xml_root(
    part,
    bytes,
    xml_budget,
    expected_root="relationships:Relationships",
  )
}

///|
/// Parses mutation-owned OPC metadata under the caller's cumulative budget and
/// verifies the expanded root QName. Prefix spelling is intentionally free;
/// the byte-level insertion helper below preserves the spelling it finds.
fn read_mutation_xml_root(
  part : String,
  bytes : BytesView,
  xml_budget : @xml.XmlReadBudget,
  expected_root~ : String,
) -> XmlElement raise DocxError {
  let root = @xml.read_xml_bytes_strict_limited(
    bytes,
    xml_budget,
    namespace_map=office_namespace_map(),
  ) catch {
    InvalidXml(message~) => {
      if is_mutation_xml_resource_error(message) {
        raise InvalidXml(message~)
      }
      if message == "XML source is not valid UTF-8" {
        raise Unsupported(message="'\{part}' is not UTF-8; refusing")
      }
      raise Unsupported(message="'\{part}' is not well-formed XML; refusing")
    }
    _ => raise Unsupported(message="'\{part}' is not well-formed XML; refusing")
  }
  if root.name != expected_root {
    raise Unsupported(
      message="'\{part}' has root '\{root.name}', expected '\{expected_root}'; refusing",
    )
  }
  root
}

///|
fn collect_relationship_ids(
  element : XmlElement,
  ids : StableStringSet,
) -> Unit {
  match element.attributes.get("Id") {
    Some(id) => ids.add(id)
    None => ()
  }
  for child in element.children {
    match child {
      XmlElement(inner) => collect_relationship_ids(inner, ids)
      _ => ()
    }
  }
}

///|
priv struct RawXmlRootSpan {
  name : String
  start : Int
  end : Int
  close_start : Int?
}

///|
fn ascii_bytes_start_with(bytes : BytesView, at : Int, text : String) -> Bool {
  if at < 0 || at + text.length() > bytes.length() {
    return false
  }
  for offset, unit in text.code_units() {
    if bytes[at + offset].to_int() != unit.to_int() {
      return false
    }
  }
  true
}

///|
fn scan_past_ascii_terminator(
  bytes : BytesView,
  from : Int,
  terminator : String,
) -> Int raise DocxError {
  let mut at = from
  while at + terminator.length() <= bytes.length() {
    if ascii_bytes_start_with(bytes, at, terminator) {
      return at + terminator.length()
    }
    at += 1
  }
  raise Unsupported(message="unterminated XML markup while locating a root")
}

///|
/// Locates the document element and its matching close at the byte level after
/// strict XML parsing has established well-formedness. The walk is quote-aware
/// for open tags and skips comments, CDATA, and PIs, so prefixed roots and
/// self-closing empty OPC metadata are safe mutation targets.
fn scan_xml_root_span(
  part : String,
  bytes : BytesView,
) -> RawXmlRootSpan raise DocxError {
  let limit = bytes.length()
  let mut root_start = -1
  let mut cursor = 0
  while cursor < limit {
    if bytes[cursor] != b'<' {
      cursor += 1
      continue
    }
    if ascii_bytes_start_with(bytes, cursor, "<?") {
      cursor = scan_past_ascii_terminator(bytes, cursor + 2, "?>")
      continue
    }
    if ascii_bytes_start_with(bytes, cursor, "<!--") {
      cursor = scan_past_ascii_terminator(bytes, cursor + 4, "-->")
      continue
    }
    if ascii_bytes_start_with(bytes, cursor, "<!") ||
      ascii_bytes_start_with(bytes, cursor, "</") {
      raise Unsupported(
        message="could not locate the root of '\{part}'; refusing",
      )
    }
    root_start = cursor
    break
  }
  if root_start < 0 {
    raise Unsupported(
      message="could not locate the root of '\{part}'; refusing",
    )
  }
  let root_tag = scan_open_tag_attributes(bytes, root_start)
  let name_start = root_start + 1
  let name_end = name_start + tag_name_length(bytes, name_start)
  let name = @utf8.decode(bytes[name_start:name_end], ignore_bom=true) catch {
    _ =>
      raise Unsupported(
        message="the root name of '\{part}' is not UTF-8; refusing",
      )
  }
  if root_tag.self_closing {
    return {
      name,
      start: root_start,
      end: root_tag.tag_gt + 1,
      close_start: None,
    }
  }
  let mut depth = 1
  cursor = root_tag.tag_gt + 1
  while cursor < limit {
    if bytes[cursor] != b'<' {
      cursor += 1
      continue
    }
    if ascii_bytes_start_with(bytes, cursor, "<!--") {
      cursor = scan_past_ascii_terminator(bytes, cursor + 4, "-->")
      continue
    }
    if ascii_bytes_start_with(bytes, cursor, "<?") {
      cursor = scan_past_ascii_terminator(bytes, cursor + 2, "?>")
      continue
    }
    if ascii_bytes_start_with(bytes, cursor, "<![CDATA[") {
      cursor = scan_past_ascii_terminator(bytes, cursor + 9, "]]>")
      continue
    }
    if ascii_bytes_start_with(bytes, cursor, "</") {
      let close_start = cursor
      while cursor < limit && bytes[cursor] != b'>' {
        cursor += 1
      }
      if cursor >= limit {
        raise Unsupported(
          message="could not locate the close of '\{part}'; refusing",
        )
      }
      depth -= 1
      cursor += 1
      if depth == 0 {
        return {
          name,
          start: root_start,
          end: cursor,
          close_start: Some(close_start),
        }
      }
      continue
    }
    if ascii_bytes_start_with(bytes, cursor, "<!") {
      raise Unsupported(message="unsupported XML markup in '\{part}'; refusing")
    }
    let tag = scan_open_tag_attributes(bytes, cursor)
    if !tag.self_closing {
      depth += 1
    }
    cursor = tag.tag_gt + 1
  }
  raise Unsupported(message="could not locate the close of '\{part}'; refusing")
}

///|
fn qualified_child_name(root_name : String, local_name : String) -> String {
  let (prefix, _) = split_qualified(root_name)
  if prefix == "" {
    local_name
  } else {
    "\{prefix}:\{local_name}"
  }
}

///|
fn xml_root_child_edit(
  bytes : BytesView,
  root : RawXmlRootSpan,
  child : String,
) -> @splice.SpanEdit raise DocxError {
  match root.close_start {
    Some(insert_at) =>
      @splice.span_edit(start=insert_at, end=insert_at, @utf8.encode(child))
    None => self_closing_rewrite_range(bytes, root.start, root.end, child)
  }
}

///|
/// One self-closing node ("<name attrs/>") rewritten to the open form
/// with `inner` inside, attributes and prefix preserved VERBATIM from
/// the original bytes.
fn self_closing_rewrite(
  part_bytes : BytesView,
  span : NodeSpan,
  inner : String,
) -> @splice.SpanEdit raise DocxError {
  let slice = part_bytes[span.byte_start():span.byte_end()]
  let mut name_end = 1
  while name_end < slice.length() &&
        slice[name_end] != b' ' &&
        slice[name_end] != b'/' &&
        slice[name_end] != b'>' &&
        slice[name_end] != b'\t' &&
        slice[name_end] != b'\r' &&
        slice[name_end] != b'\n' {
    name_end += 1
  }
  let replacement = Buffer()
  replacement.write_bytesview(slice[0:slice.length() - 2])
  replacement.write_bytes(b">")
  replacement.write_bytes(@utf8.encode(inner))
  replacement.write_bytes(b"</")
  replacement.write_bytesview(slice[1:name_end])
  replacement.write_bytes(b">")
  @splice.span_edit(
    start=span.byte_start(),
    end=span.byte_end(),
    replacement.contents(),
  )
}

///|
/// Queues one anchored paragraph's marker edits (self-closing
/// paragraphs rewritten by their own extent).
fn queue_paragraph_edits(
  plan : @splice.SplicePlan,
  part : String,
  part_bytes : BytesView,
  span : NodeSpan,
  leading : String?,
  trailing : String?,
) -> Unit raise DocxError {
  if span.self_closing() {
    let inner = leading.unwrap_or("") + trailing.unwrap_or("")
    plan.edit_part(part, self_closing_rewrite(part_bytes, span, inner))
    return
  }
  guard span.content_start() is Some(content_start) else {
    raise Unsupported(message="an open paragraph without insertion offsets")
  }
  guard span.close_tag_start() is Some(close_start) else {
    raise Unsupported(message="an open paragraph without insertion offsets")
  }
  match leading {
    Some(fragment) =>
      plan.edit_part(
        part,
        @splice.span_edit(
          start=content_start,
          end=content_start,
          @utf8.encode(fragment),
        ),
      )
    None => ()
  }
  match trailing {
    Some(fragment) =>
      plan.edit_part(
        part,
        @splice.span_edit(
          start=close_start,
          end=close_start,
          @utf8.encode(fragment),
        ),
      )
    None => ()
  }
}

///|
/// Splits "word/document.xml" into ("word", "document.xml").
fn split_part_path(part : String) -> (String, String) {
  match part.rev_find("/") {
    Some(slash) =>
      (
        part.view(end_offset=slash).to_owned(),
        part.view(start_offset=slash + 1).to_owned(),
      )
    None => ("", part)
  }
}

///|
/// One OPC part's logical IRI identity and exact/canonical physical ZIP item
/// spelling. Existing entries retain their exact producer spelling; new parts
/// use the canonical ASCII projection of the logical name.
priv struct MutationOpcPartPath {
  logical : String
  physical : String
}

///|
fn mutation_part_path_from_logical(
  zip : ZipArchive,
  logical : String,
  role : String,
) -> MutationOpcPartPath raise DocxError {
  guard @opc.zip_item_name_from_logical_part_name(logical) is Some(canonical) else {
    raise Unsupported(
      message="the logical \{role} part name '\{logical}' cannot be represented as a ZIP item",
    )
  }
  { logical, physical: zip.resolve_path(logical).unwrap_or(canonical) }
}

///|
fn main_story_logical_part(
  annotated : DocxAnnotatedResult,
  zip : ZipArchive,
) -> String raise DocxError {
  let physical = annotated.main_story_part()
  guard zip.logical_path(physical) is Some(logical) else {
    raise Unsupported(
      message="the main story part '\{physical}' has no logical OPC identity",
    )
  }
  logical
}

///|
fn main_sibling_mutation_part_path(
  annotated : DocxAnnotatedResult,
  zip : ZipArchive,
  basename : String,
) -> MutationOpcPartPath raise DocxError {
  let logical_main = main_story_logical_part(annotated, zip)
  let (main_dir, _) = split_part_path(logical_main)
  let logical = if main_dir == "" {
    basename
  } else {
    "\{main_dir}/\{basename}"
  }
  mutation_part_path_from_logical(zip, logical, basename)
}

///|
fn main_relationships_mutation_part_path(
  annotated : DocxAnnotatedResult,
  zip : ZipArchive,
) -> MutationOpcPartPath raise DocxError {
  let logical_main = main_story_logical_part(annotated, zip)
  let (main_dir, main_base) = split_part_path(logical_main)
  let logical = if main_dir == "" {
    "_rels/\{main_base}.rels"
  } else {
    "\{main_dir}/_rels/\{main_base}.rels"
  }
  mutation_part_path_from_logical(zip, logical, "relationships")
}

///|
fn opc_content_type_override_fragment(
  element_name : String,
  logical_part : String,
  content_type : String,
) -> String {
  @xml.write_xml_fragment(
    @xml.xml_element(element_name, attributes={
      "PartName": "/" + logical_part,
      "ContentType": content_type,
    }),
  )
}

///|
/// "the level has N paragraphs" for a missed ordinal — the sibling
/// count that lets an agent correct its path (probe M, gap 2).
fn describe_paragraph_siblings(
  annotated : DocxAnnotatedResult,
  relative_path : String,
) -> String {
  let prefix = match relative_path.rev_find("/") {
    Some(slash) => relative_path.view(end_offset=slash + 1).to_owned()
    None => ""
  }
  // A MISSING ancestor must be named as such — "holds 0 paragraphs"
  // for a container that does not exist would be dishonest (probe M
  // review round 1). Walk the prefix segments, verifying each.
  if prefix != "" {
    let mut checked = ""
    for segment in prefix.split("/") {
      let piece = segment.to_owned()
      if piece == "" {
        continue
      }
      let candidate = if checked == "" { piece } else { "\{checked}/\{piece}" }
      let kind = match piece.find("[") {
        Some(bracket) => piece.view(end_offset=bracket).to_owned()
        None => piece
      }
      if body_node_span_of_kind(annotated, candidate, kind) is None {
        return "'/body/\{candidate}' does not exist"
      }
      checked = candidate
    }
  }
  let mut count = 0
  let mut probe = 1
  while annotated.body_paragraph_span("\{prefix}p[\{probe}]") is Some(_) {
    count += 1
    probe += 1
  }
  if prefix == "" {
    "the body has \{count} top-level paragraph(s)"
  } else {
    "'\{prefix}' holds \{count} paragraph(s)"
  }
}
