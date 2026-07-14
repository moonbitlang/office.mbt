// L2 plan building: replies and resolution on EXISTING documents.
// Replies are anchorless (the locked K2 policy): a reply splices its
// definition into comments.xml and its linkage into
// word/commentsExtended.xml — creating and wiring that part when
// absent — keyed by LAST-body-paragraph w14:paraId values. Existing
// documents may predate w14, so the RETROFIT allocates a fresh 8-hex
// paraId (collision scope: every paraId in comments.xml and all
// reachable story parts) and splices the attribute into the parent's
// last body paragraph, declaring w14 (+ mc:Ignorable) on the comments
// root when absent. commentsExtended itself is rewritten WHOLE-PART:
// it holds pure linkage (no user content), so the canonical
// re-serialization is the declared edit span.

///|
/// One commentsExtended record, in part order.
priv struct CommentExEntry {
  para_id : String
  done : Bool
  parent_para_id : String?
}

///|
/// Builds the splice plan for `docx annotate reply`: the reply's
/// definition (paraId-stamped) into comments.xml plus the whole-part
/// commentsExtended update (parent retrofit included). Returns the
/// plan and the reply's new comment id.
pub fn plan_comment_reply(
  annotated : DocxAnnotatedResult,
  original : BytesView,
  parent_id~ : String,
  spec : CommentSpec,
  max_fragment_bytes? : Int = 8 * 1024 * 1024,
) -> (@splice.SplicePlan, String) raise DocxError {
  plan_comment_reply_zip(
    annotated,
    open_zip(original),
    parent_id~,
    spec,
    max_fragment_bytes,
  )
}

///|
/// Archive-backed reply planner for bounded preservation sessions.
pub fn plan_comment_reply_archive(
  annotated : DocxAnnotatedResult,
  archive : @mbtzip.Archive,
  parent_id~ : String,
  spec : CommentSpec,
  max_fragment_bytes? : Int = 8 * 1024 * 1024,
) -> (@splice.SplicePlan, String) raise DocxError {
  plan_comment_reply_zip(
    annotated,
    open_zip_archive(archive),
    parent_id~,
    spec,
    max_fragment_bytes,
  )
}

///|
fn plan_comment_reply_zip(
  annotated : DocxAnnotatedResult,
  zip : ZipArchive,
  parent_id~ : String,
  spec : CommentSpec,
  max_fragment_bytes : Int,
) -> (@splice.SplicePlan, String) raise DocxError {
  check_mutation_gates(annotated)
  let plan = @splice.SplicePlan::new()
  let parent = find_defined_comment(annotated, parent_id)
  if parent.body_paragraphs() == 0 {
    raise Unsupported(
      message="comment '\{parent_id}' has no body paragraph to key the thread on; refusing to reply",
    )
  }
  guard annotated.comments_part() is Some(comments_part) else {
    raise Unsupported(
      message="the document has no wired comments part; refusing to reply",
    )
  }
  guard zip.read_bytes(comments_part) is Some(comments_bytes) else {
    raise Unsupported(message="the comments part is unreadable")
  }
  // Fresh paraIds: collision scope is every paraId in the reachable
  // parts (duplicates there are unrepairable and fail closed).
  let used_para_ids = collect_para_ids(zip, annotated, comments_part)
  let mut next_para_seed = 1
  fn allocate_para_id() -> String {
    let mut candidate = format_para_id(next_para_seed)
    while used_para_ids.contains(canonical_para_id(candidate)) {
      next_para_seed += 1
      candidate = format_para_id(next_para_seed)
    }
    next_para_seed += 1
    used_para_ids.add(canonical_para_id(candidate))
    candidate
  }
  // The comments root: which prefix carries the w14 URI (or a root
  // retrofit that declares it).
  guard annotated.story_root_span("/comments") is Some(root_span) else {
    raise Unsupported(
      message="the comments part could not be scanned; refusing to reply",
    )
  }
  let w14_prefix = ensure_w14_on_root(
    plan, comments_part, comments_bytes, root_span,
  )
  // Parent retrofit: the parent's LAST body paragraph needs a paraId.
  let parent_para_id = match parent.last_para_id() {
    Some(existing) => existing
    None => {
      let fresh = allocate_para_id()
      let ordinal = comment_ordinal(annotated, parent_id)
      let last_paragraph = parent.body_paragraphs()
      guard annotated.story_paragraph_span(
          "/comments",
          "comment[\{ordinal}]/p[\{last_paragraph}]",
        )
        is Some(paragraph_span) else {
        raise Unsupported(
          message="comment '\{parent_id}' has no scannable last body paragraph; refusing to reply",
        )
      }
      insert_open_tag_attribute(
        plan,
        comments_part,
        comments_bytes,
        paragraph_span,
        " \{w14_prefix}:paraId=\"\{fresh}\"",
      )
      fresh
    }
  }
  // The reply definition: dense id, every body paragraph stamped, the
  // LAST stamp being the reply's commentEx key.
  check_comment_body_for_fragment(spec.body, max_fragment_bytes)
  let new_id = allocate_comment_id(annotated)
  let reply_para_ids : Array[String] = []
  for _ in 0..<spec_body_length(spec) {
    reply_para_ids.push(allocate_para_id())
  }
  let definition = comment_definition_fragment(
    spec,
    id=new_id,
    para_ids=reply_para_ids,
    max_output_bytes=max_fragment_bytes,
  )
  match root_span.close_tag_start() {
    Some(insert_at) =>
      plan.edit_part(
        comments_part,
        @splice.span_edit(
          start=insert_at,
          end=insert_at,
          @utf8.encode(definition),
        ),
      )
    None =>
      // A defined parent implies a populated, open-form root.
      raise Unsupported(
        message="the comments part has a self-closing root yet holds definitions; refusing to reply",
      )
  }
  guard reply_para_ids.last() is Some(reply_key) else {
    raise Unsupported(message="the reply body is empty")
  }
  // commentsExtended: ENTRY-LEVEL edits — a parent entry is created
  // only when missing (an existing one keeps its bytes, resolution
  // state included), and the reply's entry appends with paraIdParent
  // linking the thread.
  let additions : Array[CommentExEntry] = []
  let mut parent_seen = false
  match annotated.comments_extended_part() {
    Some(part) =>
      match zip.read_bytes(part) {
        Some(bytes) => {
          let (locations, _, _) = scan_comment_ex_part(bytes)
          for location in locations {
            if location.para_id == canonical_para_id(parent_para_id) {
              parent_seen = true
            }
          }
        }
        None =>
          raise Unsupported(message="the commentsExtended part is unreadable")
      }
    None => ()
  }
  if !parent_seen {
    additions.push({
      para_id: canonical_para_id(parent_para_id),
      done: false,
      parent_para_id: None,
    })
  }
  additions.push({
    para_id: canonical_para_id(reply_key),
    done: false,
    parent_para_id: Some(canonical_para_id(parent_para_id)),
  })
  queue_comments_extended_edits(plan, zip, annotated, None, additions)
  pin_splice_sources(plan, zip)
  (plan, new_id)
}

///|
/// Builds the splice plan for `docx annotate resolve|unresolve`: the
/// comment's commentsExtended entry flips (or gains) its w15:done flag,
/// with the same paraId retrofit as replies when the definition is
/// unstamped.
pub fn plan_comment_resolution(
  annotated : DocxAnnotatedResult,
  original : BytesView,
  comment_id~ : String,
  done~ : Bool,
) -> @splice.SplicePlan raise DocxError {
  plan_comment_resolution_zip(annotated, open_zip(original), comment_id~, done~)
}

///|
/// Archive-backed resolution planner for bounded preservation sessions.
pub fn plan_comment_resolution_archive(
  annotated : DocxAnnotatedResult,
  archive : @mbtzip.Archive,
  comment_id~ : String,
  done~ : Bool,
) -> @splice.SplicePlan raise DocxError {
  plan_comment_resolution_zip(
    annotated,
    open_zip_archive(archive),
    comment_id~,
    done~,
  )
}

///|
fn plan_comment_resolution_zip(
  annotated : DocxAnnotatedResult,
  zip : ZipArchive,
  comment_id~ : String,
  done~ : Bool,
) -> @splice.SplicePlan raise DocxError {
  check_mutation_gates(annotated)
  let plan = @splice.SplicePlan::new()
  let comment = find_defined_comment(annotated, comment_id)
  if comment.body_paragraphs() == 0 {
    raise Unsupported(
      message="comment '\{comment_id}' has no body paragraph to key resolution on; refusing",
    )
  }
  guard annotated.comments_part() is Some(comments_part) else {
    raise Unsupported(
      message="the document has no wired comments part; refusing",
    )
  }
  guard zip.read_bytes(comments_part) is Some(comments_bytes) else {
    raise Unsupported(message="the comments part is unreadable")
  }
  // The duplicate-paraId gate runs UNCONDITIONALLY (review round 1):
  // resolving on an ambiguous key would mutate the wrong thread.
  let used_para_ids = collect_para_ids(zip, annotated, comments_part)
  let key = match comment.last_para_id() {
    Some(existing) => existing
    None => {
      let mut seed = 1
      let mut fresh = format_para_id(seed)
      while used_para_ids.contains(canonical_para_id(fresh)) {
        seed += 1
        fresh = format_para_id(seed)
      }
      guard annotated.story_root_span("/comments") is Some(root_span) else {
        raise Unsupported(
          message="the comments part could not be scanned; refusing",
        )
      }
      let w14_prefix = ensure_w14_on_root(
        plan, comments_part, comments_bytes, root_span,
      )
      let ordinal = comment_ordinal(annotated, comment_id)
      let last_paragraph = comment.body_paragraphs()
      guard annotated.story_paragraph_span(
          "/comments",
          "comment[\{ordinal}]/p[\{last_paragraph}]",
        )
        is Some(paragraph_span) else {
        raise Unsupported(
          message="comment '\{comment_id}' has no scannable last body paragraph; refusing",
        )
      }
      insert_open_tag_attribute(
        plan,
        comments_part,
        comments_bytes,
        paragraph_span,
        " \{w14_prefix}:paraId=\"\{fresh}\"",
      )
      fresh
    }
  }
  queue_comments_extended_edits(plan, zip, annotated, Some((key, done)), [])
  pin_splice_sources(plan, zip)
  plan
}

///|
fn find_defined_comment(
  annotated : DocxAnnotatedResult,
  id : String,
) -> CommentInfo raise DocxError {
  for comment in annotated.annotations().comments() {
    if comment.id() == id {
      if !comment.defined() {
        raise Unsupported(
          message="comment '\{id}' has markers but no definition; refusing",
        )
      }
      return comment
    }
  }
  raise Unsupported(message="the document has no comment with id '\{id}'")
}

///|
/// The parent's 1-based ordinal among DEFINITIONS in part order (the
/// scanner's comment[k] paths follow the same order).
fn comment_ordinal(
  annotated : DocxAnnotatedResult,
  id : String,
) -> Int raise DocxError {
  for index, pair in annotated.comment_bodies() {
    let (comment_id, _) = pair
    if comment_id == id {
      return index + 1
    }
  }
  raise Unsupported(message="the document has no comment with id '\{id}'")
}

///|
fn spec_body_length(spec : CommentSpec) -> Int {
  spec.body.length()
}

///|
/// Dense comment-id allocation (shared semantics with
/// plan_comment_addition, including the numeric-identity rules).
fn allocate_comment_id(
  annotated : DocxAnnotatedResult,
) -> String raise DocxError {
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
          message="the document holds comment id '\{comment.id()}', outside the supported numeric range; refusing",
        )
    }
  }
  let mut candidate = max_numeric + 1
  while used_numeric.contains(candidate) {
    candidate += 1
  }
  if candidate > 999_999_999 {
    raise Unsupported(
      message="cannot allocate a comment id: the document already uses the maximum supported id",
    )
  }
  candidate.to_string()
}

///|
/// Every w14:paraId value in the reachable parts (main story, comments,
/// footnotes/endnotes, headers/footers). DUPLICATES anywhere are
/// unrepairable and fail closed — the retrofit's collision scope must
/// be trustworthy.
fn collect_para_ids(
  zip : ZipArchive,
  annotated : DocxAnnotatedResult,
  comments_part : String,
) -> Set[String] raise DocxError {
  let para_ids : Set[String] = Set([])
  let parts : Array[String] = [annotated.main_story_part(), comments_part]
  // Sibling story parts named through the MAIN part's relationships.
  let (main_dir, main_base) = split_part_path(annotated.main_story_part())
  let rels_part = if main_dir == "" {
    "_rels/\{main_base}.rels"
  } else {
    "\{main_dir}/_rels/\{main_base}.rels"
  }
  let rels_read : String? = zip.read_text(rels_part) catch { _ => None }
  match rels_read {
    Some(rels_text) => {
      let parsed : XmlElement? = Some(@xml.read_xml_string(rels_text)) catch {
        _ => None
      }
      match parsed {
        Some(root) => collect_story_targets(root, main_dir, parts)
        None => ()
      }
    }
    _ => ()
  }
  for part in parts {
    let part_read : String? = zip.read_text(part) catch { _ => None }
    match part_read {
      Some(text) => {
        let parsed : XmlElement? = Some(
          read_xml_string(text, namespace_map=office_namespace_map()),
        ) catch {
          _ => None
        }
        match parsed {
          Some(root) =>
            collect_para_id_attributes(root, para_ids) catch {
              Unsupported(message~) =>
                raise Unsupported(message="\{message} (in '\{part}')")
              err => raise err
            }
          None => ()
        }
      }
      _ => ()
    }
  }
  para_ids
}

///|
fn collect_story_targets(
  element : XmlElement,
  main_dir : String,
  parts : Array[String],
) -> Unit {
  // Transitional AND Strict relationship types (review round 1), with
  // OPC-normalized target resolution ('../' forms included).
  let story_types = [
    "http://schemas.openxmlformats.org/officeDocument/2006/relationships/header",
    "http://schemas.openxmlformats.org/officeDocument/2006/relationships/footer",
    "http://schemas.openxmlformats.org/officeDocument/2006/relationships/footnotes",
    "http://schemas.openxmlformats.org/officeDocument/2006/relationships/endnotes",
    "http://purl.oclc.org/ooxml/officeDocument/relationships/header", "http://purl.oclc.org/ooxml/officeDocument/relationships/footer",
    "http://purl.oclc.org/ooxml/officeDocument/relationships/footnotes", "http://purl.oclc.org/ooxml/officeDocument/relationships/endnotes",
  ]
  match
    (
      element.attributes.get("Type"),
      element.attributes.get("Target"),
      element.attributes.get("TargetMode"),
    ) {
    (Some(relationship_type), Some(target), mode) =>
      if !(mode is Some("External")) &&
        story_types.search(relationship_type) is Some(_) {
        let resolved = @opc.resolve_target(main_dir, target)
        if parts.search(resolved) is None {
          parts.push(resolved)
        }
      }
    _ => ()
  }
  for child in element.children {
    match child {
      XmlElement(inner) => collect_story_targets(inner, main_dir, parts)
      _ => ()
    }
  }
}

///|
fn collect_para_id_attributes(
  element : XmlElement,
  para_ids : Set[String],
) -> Unit raise DocxError {
  match element.attributes.get("w14:paraId") {
    Some(para_id) => {
      let canonical = canonical_para_id(para_id)
      if para_ids.contains(canonical) {
        raise Unsupported(
          message="duplicate w14:paraId '\{para_id}'; the document's paraId state is not repairable",
        )
      }
      para_ids.add(canonical)
    }
    None => ()
  }
  for child in element.children {
    match child {
      XmlElement(inner) => collect_para_id_attributes(inner, para_ids)
      _ => ()
    }
  }
}

///|
/// Ensures the w14 URI is bound on the comments ROOT and that the
/// chosen prefix is listed in mc:Ignorable, returning that prefix.
/// TWO-PASS over the root's attributes (declarations first, then
/// mc:Ignorable through the completed map — attribute ORDER must not
/// matter), and the Ignorable token is ensured even when the URI was
/// already bound (review round 1).
fn ensure_w14_on_root(
  plan : @splice.SplicePlan,
  part : String,
  part_bytes : Bytes,
  root_span : NodeSpan,
) -> String raise DocxError {
  let attributes = scan_open_tag_attributes(part_bytes, root_span.byte_start())
  // Pass 1: every namespace declaration.
  let mut w14_prefix : String? = None
  let mut mc_prefix : String? = None
  for attribute in attributes.entries {
    let (name, value, _, _) = attribute
    if name.has_prefix("xmlns:") {
      let prefix = name.view(start_offset=6).to_owned()
      if value == W14_NAMESPACE && w14_prefix is None {
        w14_prefix = Some(prefix)
      }
      if value == MC_NAMESPACE && mc_prefix is None {
        mc_prefix = Some(prefix)
      }
    }
  }
  // Pass 2: mc:Ignorable through the resolved mc prefix.
  let mut ignorable : (String, Int)? = None
  match mc_prefix {
    Some(prefix) =>
      for attribute in attributes.entries {
        let (name, value, _, value_end) = attribute
        if name == "\{prefix}:Ignorable" {
          ignorable = Some((value, value_end))
        }
      }
    None => ()
  }
  let insert_at = attributes.tag_gt -
    (if attributes.self_closing { 1 } else { 0 })
  let chosen = match w14_prefix {
    Some(prefix) => prefix
    None => {
      plan.edit_part(
        part,
        @splice.span_edit(
          start=insert_at,
          end=insert_at,
          @utf8.encode(" xmlns:w14=\"\{W14_NAMESPACE}\""),
        ),
      )
      "w14"
    }
  }
  // The Ignorable token, ensured in every configuration.
  match (mc_prefix, ignorable) {
    (Some(_), Some((value, value_end))) => {
      let mut listed = false
      for token in value.split(" ") {
        if token.to_owned() == chosen {
          listed = true
        }
      }
      if !listed {
        plan.edit_part(
          part,
          @splice.span_edit(
            start=value_end,
            end=value_end,
            @utf8.encode(" \{chosen}"),
          ),
        )
      }
    }
    (Some(prefix), None) =>
      plan.edit_part(
        part,
        @splice.span_edit(
          start=insert_at,
          end=insert_at,
          @utf8.encode(" \{prefix}:Ignorable=\"\{chosen}\""),
        ),
      )
    (None, _) =>
      plan.edit_part(
        part,
        @splice.span_edit(
          start=insert_at,
          end=insert_at,
          @utf8.encode(
            " xmlns:mc=\"\{MC_NAMESPACE}\" mc:Ignorable=\"\{chosen}\"",
          ),
        ),
      )
  }
  chosen
}

///|
/// Splices one attribute into a paragraph's OPEN TAG (just before its
/// '>' — quote-aware, so a '>' inside an attribute value cannot fool
/// the scan).
fn insert_open_tag_attribute(
  plan : @splice.SplicePlan,
  part : String,
  part_bytes : Bytes,
  span : NodeSpan,
  attribute_text : String,
) -> Unit raise DocxError {
  let attributes = scan_open_tag_attributes(part_bytes, span.byte_start())
  let insert_at = attributes.tag_gt -
    (if attributes.self_closing { 1 } else { 0 })
  plan.edit_part(
    part,
    @splice.span_edit(
      start=insert_at,
      end=insert_at,
      @utf8.encode(attribute_text),
    ),
  )
}

///|
priv struct OpenTagScan {
  // (name, value, value_start, value_end) per attribute, byte offsets.
  entries : Array[(String, String, Int, Int)]
  // Offset of the closing '>' of the open tag.
  tag_gt : Int
  self_closing : Bool
}

///|
/// Scans one open tag's attributes from raw UTF-8 bytes, quote-aware.
fn scan_open_tag_attributes(
  bytes : Bytes,
  tag_start : Int,
) -> OpenTagScan raise DocxError {
  let entries : Array[(String, String, Int, Int)] = []
  let limit = bytes.length()
  let mut at = tag_start + 1
  fn is_space(byte : Byte) -> Bool {
    byte == b' ' || byte == b'\t' || byte == b'\r' || byte == b'\n'
  }
  // Skip the element name.
  while at < limit &&
        !is_space(bytes[at]) &&
        bytes[at] != b'>' &&
        bytes[at] != b'/' {
    at += 1
  }
  for ;; {
    while at < limit && is_space(bytes[at]) {
      at += 1
    }
    if at >= limit {
      raise Unsupported(message="an unterminated open tag; refusing")
    }
    if bytes[at] == b'>' {
      return { entries, tag_gt: at, self_closing: false }
    }
    if bytes[at] == b'/' && at + 1 < limit && bytes[at + 1] == b'>' {
      return { entries, tag_gt: at + 1, self_closing: true }
    }
    let name_start = at
    while at < limit &&
          !is_space(bytes[at]) &&
          bytes[at] != b'=' &&
          bytes[at] != b'>' {
      at += 1
    }
    let name = ascii_slice(bytes, name_start, at)
    while at < limit && is_space(bytes[at]) {
      at += 1
    }
    if at >= limit || bytes[at] != b'=' {
      raise Unsupported(message="a malformed open tag; refusing")
    }
    at += 1
    while at < limit && is_space(bytes[at]) {
      at += 1
    }
    if at >= limit || !(bytes[at] == b'"' || bytes[at] == b'\'') {
      raise Unsupported(message="a malformed open tag; refusing")
    }
    let quote = bytes[at]
    at += 1
    let value_start = at
    while at < limit && bytes[at] != quote {
      at += 1
    }
    if at >= limit {
      raise Unsupported(message="an unterminated attribute value; refusing")
    }
    entries.push((name, ascii_slice(bytes, value_start, at), value_start, at))
    at += 1
  }
}

///|
/// A located commentEx entry in the EXISTING part: canonical paraId,
/// current done state, the byte span of the done attribute VALUE (when
/// present), and the open tag's insertion offset.
priv struct CommentExLocation {
  para_id : String
  done_value_span : (Int, Int)?
  insert_at : Int
  done_prefix : String
}

///|
/// Canonical paraId identity: ST_LongHexNumber is eight hex digits, so
/// conforming values compare case-insensitively (uppercased); anything
/// else compares verbatim.
fn canonical_para_id(value : String) -> String {
  if value.length() != 8 {
    return value
  }
  let builder = StringBuilder::new()
  for unit in value {
    let code = unit.to_int()
    if code >= '0'.to_int() && code <= '9'.to_int() {
      builder.write_char(code.to_char().unwrap_or('?'))
    } else if code >= 'a'.to_int() && code <= 'f'.to_int() {
      builder.write_char((code - 32).to_char().unwrap_or('?'))
    } else if code >= 'A'.to_int() && code <= 'F'.to_int() {
      builder.write_char(code.to_char().unwrap_or('?'))
    } else {
      return value
    }
  }
  builder.to_string()
}

///|
/// Walks the EXISTING commentsExtended part at the byte level,
/// namespace-aware (root declarations plus each entry's own), and
/// returns the located entries, the offset of the root's close tag
/// (None for a self-closing root), and the root's byte span. Duplicate
/// canonical paraIds fail closed — mutating on ambiguous keys is the
/// unrepairable state the contract names.
fn scan_comment_ex_part(
  bytes : Bytes,
) -> (Array[CommentExLocation], Int?, (Int, Int)) raise DocxError {
  // The root open tag: the first '<' that is not a declaration,
  // comment, or PI.
  let limit = bytes.length()
  let mut at = 0
  let mut root_start = -1
  while at < limit {
    if bytes[at] == b'<' {
      if at + 1 < limit && (bytes[at + 1] == b'?' || bytes[at + 1] == b'!') {
        // Skip the declaration/PI/comment wholesale.
        let close = if at + 3 < limit &&
          bytes[at + 1] == b'!' &&
          bytes[at + 2] == b'-' &&
          bytes[at + 3] == b'-' {
          "-->"
        } else {
          ">"
        }
        let mut scan = at + 1
        let terminator = close.code_units()
        while scan <= limit - terminator.length() {
          let mut matched = true
          for offset, unit in terminator {
            if bytes[scan + offset].to_int() != unit.to_int() {
              matched = false
              break
            }
          }
          if matched {
            break
          }
          scan += 1
        }
        at = scan + close.length()
        continue
      }
      root_start = at
      break
    }
    at += 1
  }
  if root_start < 0 {
    raise Unsupported(message="the commentsExtended part has no root element")
  }
  let root_scan = scan_open_tag_attributes(bytes, root_start)
  // Root-level namespace declarations.
  let root_declarations : Map[String, String] = Map([])
  for attribute in root_scan.entries {
    let (name, value, _, _) = attribute
    if name.has_prefix("xmlns:") {
      root_declarations[name.view(start_offset=6).to_owned()] = value
    }
  }
  if root_scan.self_closing {
    return ([], None, (root_start, root_scan.tag_gt + 1))
  }
  // Walk depth-1 children.
  let locations : Array[CommentExLocation] = []
  let seen : Set[String] = Set([])
  let mut cursor = root_scan.tag_gt + 1
  let mut depth = 1
  let mut root_close = -1
  while cursor < limit {
    if bytes[cursor] != b'<' {
      cursor += 1
      continue
    }
    if cursor + 3 < limit &&
      bytes[cursor + 1] == b'!' &&
      bytes[cursor + 2] == b'-' &&
      bytes[cursor + 3] == b'-' {
      let mut scan = cursor + 4
      while scan + 2 < limit {
        if bytes[scan] == b'-' &&
          bytes[scan + 1] == b'-' &&
          bytes[scan + 2] == b'>' {
          break
        }
        scan += 1
      }
      cursor = scan + 3
      continue
    }
    if cursor + 1 < limit && bytes[cursor + 1] == b'?' {
      let mut scan = cursor + 2
      while scan + 1 < limit {
        if bytes[scan] == b'?' && bytes[scan + 1] == b'>' {
          break
        }
        scan += 1
      }
      cursor = scan + 2
      continue
    }
    // CDATA sections (valid between or inside entries) are skipped
    // wholesale — review round 2.
    if cursor + 8 < limit &&
      bytes[cursor + 1] == b'!' &&
      bytes[cursor + 2] == b'[' &&
      bytes[cursor + 3] == b'C' &&
      bytes[cursor + 4] == b'D' &&
      bytes[cursor + 5] == b'A' &&
      bytes[cursor + 6] == b'T' &&
      bytes[cursor + 7] == b'A' &&
      bytes[cursor + 8] == b'[' {
      let mut scan = cursor + 9
      while scan + 2 < limit {
        if bytes[scan] == b']' &&
          bytes[scan + 1] == b']' &&
          bytes[scan + 2] == b'>' {
          break
        }
        scan += 1
      }
      cursor = scan + 3
      continue
    }
    if cursor + 1 < limit && bytes[cursor + 1] == b'/' {
      depth -= 1
      if depth == 0 {
        root_close = cursor
        break
      }
      while cursor < limit && bytes[cursor] != b'>' {
        cursor += 1
      }
      cursor += 1
      continue
    }
    let tag = scan_open_tag_attributes(bytes, cursor)
    if depth == 1 {
      // Resolve this tag against root + its own declarations.
      let own_declarations : Map[String, String] = Map([])
      for attribute in tag.entries {
        let (name, value, _, _) = attribute
        if name.has_prefix("xmlns:") {
          own_declarations[name.view(start_offset=6).to_owned()] = value
        }
      }
      fn prefix_uri(prefix : String) -> String? {
        match own_declarations.get(prefix) {
          Some(uri) => Some(uri)
          None => root_declarations.get(prefix)
        }
      }
      let tag_name = ascii_slice(
        bytes,
        cursor + 1,
        cursor + 1 + tag_name_length(bytes, cursor + 1),
      )
      let (tag_prefix, tag_local) = split_qualified(tag_name)
      if prefix_uri(tag_prefix) is Some(uri) &&
        uri == W15_NAMESPACE &&
        tag_local == "commentEx" {
        let mut para_id : String? = None
        let mut done_span : (Int, Int)? = None
        let mut done_prefix = tag_prefix
        for attribute in tag.entries {
          let (name, value, value_start, value_end) = attribute
          let (attr_prefix, attr_local) = split_qualified(name)
          if attr_prefix == "" {
            continue
          }
          if prefix_uri(attr_prefix) is Some(attr_uri) &&
            attr_uri == W15_NAMESPACE {
            if attr_local == "paraId" {
              para_id = Some(canonical_para_id(value))
            }
            if attr_local == "done" {
              done_span = Some((value_start, value_end))
              done_prefix = attr_prefix
            }
          }
        }
        match para_id {
          Some(key) => {
            if seen.contains(key) {
              raise Unsupported(
                message="duplicate commentsExtended records for paraId '\{key}'; the thread state is not repairable",
              )
            }
            seen.add(key)
            locations.push({
              para_id: key,
              done_value_span: done_span,
              insert_at: tag.tag_gt - (if tag.self_closing { 1 } else { 0 }),
              done_prefix,
            })
          }
          None =>
            raise Unsupported(
              message="a commentsExtended record has no paraId; the thread state is not repairable",
            )
        }
      }
    }
    if !tag.self_closing {
      depth += 1
    }
    cursor = tag.tag_gt + 1
  }
  if root_close < 0 {
    raise Unsupported(
      message="the commentsExtended part's root never closes; refusing",
    )
  }
  (locations, Some(root_close), (root_start, root_scan.tag_gt + 1))
}

///|
fn tag_name_length(bytes : Bytes, name_start : Int) -> Int {
  let mut at = name_start
  while at < bytes.length() &&
        bytes[at] != b' ' &&
        bytes[at] != b'\t' &&
        bytes[at] != b'\r' &&
        bytes[at] != b'\n' &&
        bytes[at] != b'/' &&
        bytes[at] != b'>' {
    at += 1
  }
  at - name_start
}

///|
fn split_qualified(name : String) -> (String, String) {
  match name.find(":") {
    Some(colon) =>
      (
        name.view(end_offset=colon).to_owned(),
        name.view(start_offset=colon + 1).to_owned(),
      )
    None => ("", name)
  }
}

///|
/// A self-contained commentEx fragment (its own xmlns:w15).
fn comment_ex_fragment(entry : CommentExEntry) -> String {
  let attributes : Map[String, String] = {
    "w15:paraId": entry.para_id,
    "w15:done": if entry.done {
      "1"
    } else {
      "0"
    },
  }
  match entry.parent_para_id {
    Some(parent) => attributes["w15:paraIdParent"] = parent
    None => ()
  }
  @xml.write_xml_fragment(@xml.xml_element("w15:commentEx", attributes~), namespaces={
    "w15": W15_NAMESPACE,
  })
}

///|
/// Queues the commentsExtended mutation as ENTRY-LEVEL byte splices —
/// foreign producer content anywhere else in the part stays verbatim
/// (review round 1). `flip` updates one existing entry's done state;
/// `additions` append before the root close (a self-closing root is
/// rewritten by its own extent). When the part does not exist, it is
/// created fresh and wired.
fn queue_comments_extended_edits(
  plan : @splice.SplicePlan,
  zip : ZipArchive,
  annotated : DocxAnnotatedResult,
  flip : (String, Bool)?,
  additions : Array[CommentExEntry],
) -> Unit raise DocxError {
  match annotated.comments_extended_part() {
    Some(part) => {
      guard zip.read_bytes(part) is Some(bytes) else {
        raise Unsupported(message="the commentsExtended part is unreadable")
      }
      let (locations, root_close, root_span) = scan_comment_ex_part(bytes)
      match flip {
        Some((key, done)) => {
          let mut flipped = false
          for location in locations {
            if location.para_id == canonical_para_id(key) {
              flipped = true
              match location.done_value_span {
                Some((value_start, value_end)) =>
                  plan.edit_part(
                    part,
                    @splice.span_edit(
                      start=value_start,
                      end=value_end,
                      @utf8.encode(if done { "1" } else { "0" }),
                    ),
                  )
                None =>
                  plan.edit_part(
                    part,
                    @splice.span_edit(
                      start=location.insert_at,
                      end=location.insert_at,
                      @utf8.encode(
                        " \{location.done_prefix}:done=\"\{if done { "1" } else { "0" }}\"",
                      ),
                    ),
                  )
              }
            }
          }
          if !flipped {
            // No entry yet: the flip becomes an addition.
            additions.push({
              para_id: canonical_para_id(key),
              done,
              parent_para_id: None,
            })
          }
        }
        None => ()
      }
      if additions.length() > 0 {
        let mut fragment = ""
        for entry in additions {
          fragment += comment_ex_fragment(entry)
        }
        match root_close {
          Some(insert_at) =>
            plan.edit_part(
              part,
              @splice.span_edit(
                start=insert_at,
                end=insert_at,
                @utf8.encode(fragment),
              ),
            )
          None => {
            let (root_start, root_end) = root_span
            plan.edit_part(
              part,
              self_closing_rewrite_range(bytes, root_start, root_end, fragment),
            )
          }
        }
      }
    }
    None => {
      // Create the part fresh (fully ours) and wire it.
      let all_entries : Array[CommentExEntry] = []
      match flip {
        Some((key, done)) =>
          all_entries.push({
            para_id: canonical_para_id(key),
            done,
            parent_para_id: None,
          })
        None => ()
      }
      for entry in additions {
        all_entries.push(entry)
      }
      let records : Array[XmlNode] = []
      for entry in all_entries {
        let attributes : Map[String, String] = {
          "w15:paraId": entry.para_id,
          "w15:done": if entry.done {
            "1"
          } else {
            "0"
          },
        }
        match entry.parent_para_id {
          Some(parent) => attributes["w15:paraIdParent"] = parent
          None => ()
        }
        records.push(XmlElement(@xml.xml_element("w15:commentEx", attributes~)))
      }
      let part_text = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>" +
        @xml.write_xml_fragment(
          @xml.xml_element(
            "w15:commentsEx",
            attributes={ "mc:Ignorable": "w15" },
            children=records,
          ),
          namespaces={ "w15": W15_NAMESPACE, "mc": MC_NAMESPACE },
        )
      let (main_dir, main_base) = split_part_path(annotated.main_story_part())
      let part_name = if main_dir == "" {
        "commentsExtended.xml"
      } else {
        "\{main_dir}/commentsExtended.xml"
      }
      if zip.exists(part_name) {
        raise Unsupported(
          message="'\{part_name}' exists but is not wired as the commentsExtended part (an orphan); refusing",
        )
      }
      plan.add_part(part_name, @utf8.encode(part_text))
      let rels_part = if main_dir == "" {
        "_rels/\{main_base}.rels"
      } else {
        "\{main_dir}/_rels/\{main_base}.rels"
      }
      let relationship_type = "http://schemas.microsoft.com/office/2011/relationships/commentsExtended"
      guard zip.read_bytes(rels_part) is Some(rels_bytes) else {
        raise Unsupported(
          message="the main part has no relationships part; refusing",
        )
      }
      let rels_text = @utf8.decode(rels_bytes, ignore_bom=true) catch {
        _ => raise Unsupported(message="'\{rels_part}' is not UTF-8; refusing")
      }
      let rels_root = @xml.read_xml_string(rels_text) catch {
        _ =>
          raise Unsupported(
            message="'\{rels_part}' is not well-formed XML; refusing",
          )
      }
      let existing_ids : Set[String] = Set([])
      collect_relationship_ids(rels_root, existing_ids)
      let mut ordinal = 1
      while existing_ids.contains("rIdAnnotate\{ordinal}") {
        ordinal += 1
      }
      guard find_ascii_bytes(rels_bytes, "</Relationships>") is Some(rels_at) else {
        raise Unsupported(
          message="could not locate the close of '\{rels_part}'; refusing",
        )
      }
      plan.edit_part(
        rels_part,
        @splice.span_edit(
          start=rels_at,
          end=rels_at,
          @utf8.encode(
            "<Relationship Id=\"rIdAnnotate\{ordinal}\" Type=\"\{relationship_type}\" Target=\"commentsExtended.xml\"/>",
          ),
        ),
      )
      guard zip.read_bytes("[Content_Types].xml") is Some(types_bytes) else {
        raise Unsupported(message="the package is missing [Content_Types].xml")
      }
      guard find_ascii_bytes(types_bytes, "</Types>") is Some(types_at) else {
        raise Unsupported(
          message="could not locate the close of [Content_Types].xml; refusing",
        )
      }
      plan.edit_part(
        "[Content_Types].xml",
        @splice.span_edit(
          start=types_at,
          end=types_at,
          @utf8.encode(
            "<Override PartName=\"/\{part_name}\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.commentsExtended+xml\"/>",
          ),
        ),
      )
    }
  }
}

///|
/// A self-closing element (raw byte range) rewritten to open form with
/// `inner` inside — the range variant of self_closing_rewrite.
fn self_closing_rewrite_range(
  part_bytes : Bytes,
  start : Int,
  end : Int,
  inner : String,
) -> @splice.SpanEdit raise DocxError {
  let slice = part_bytes[start:end]
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
  @splice.span_edit(start~, end~, replacement.contents())
}
