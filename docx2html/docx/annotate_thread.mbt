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
) -> (@splice.SplicePlan, String) raise DocxError {
  check_mutation_gates(annotated)
  let zip = open_zip(original)
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
    while used_para_ids.contains(candidate) {
      next_para_seed += 1
      candidate = format_para_id(next_para_seed)
    }
    next_para_seed += 1
    used_para_ids.add(candidate)
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
  let new_id = allocate_comment_id(annotated)
  let reply_para_ids : Array[String] = []
  for _ in 0..<spec_body_length(spec) {
    reply_para_ids.push(allocate_para_id())
  }
  let definition = comment_definition_fragment(
    spec,
    id=new_id,
    para_ids=reply_para_ids,
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
  // commentsExtended: whole-part update — the parent's entry created
  // when missing (done=false), the reply's entry appended with
  // paraIdParent linking the thread.
  let entries = read_comment_ex_entries(zip, annotated)
  let mut parent_seen = false
  for entry in entries {
    if entry.para_id == parent_para_id {
      parent_seen = true
    }
  }
  if !parent_seen {
    entries.push({ para_id: parent_para_id, done: false, parent_para_id: None })
  }
  entries.push({
    para_id: reply_key,
    done: false,
    parent_para_id: Some(parent_para_id),
  })
  queue_comments_extended(plan, zip, annotated, entries)
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
  check_mutation_gates(annotated)
  let zip = open_zip(original)
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
  let key = match comment.last_para_id() {
    Some(existing) => existing
    None => {
      let used_para_ids = collect_para_ids(zip, annotated, comments_part)
      let mut seed = 1
      let mut fresh = format_para_id(seed)
      while used_para_ids.contains(fresh) {
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
  let entries = read_comment_ex_entries(zip, annotated)
  let mut found = false
  for entry in entries {
    if entry.para_id == key {
      // Struct fields are immutable here; rebuild below.
      found = true
    }
  }
  let updated : Array[CommentExEntry] = []
  for entry in entries {
    if entry.para_id == key {
      updated.push({
        para_id: entry.para_id,
        done,
        parent_para_id: entry.parent_para_id,
      })
    } else {
      updated.push(entry)
    }
  }
  if !found {
    updated.push({ para_id: key, done, parent_para_id: None })
  }
  queue_comments_extended(plan, zip, annotated, updated)
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
  let story_types = [
    "http://schemas.openxmlformats.org/officeDocument/2006/relationships/header",
    "http://schemas.openxmlformats.org/officeDocument/2006/relationships/footer",
    "http://schemas.openxmlformats.org/officeDocument/2006/relationships/footnotes",
    "http://schemas.openxmlformats.org/officeDocument/2006/relationships/endnotes",
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
        let resolved = if target.has_prefix("/") {
          target.view(start_offset=1).to_owned()
        } else if main_dir == "" {
          target
        } else {
          "\{main_dir}/\{target}"
        }
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
      if para_ids.contains(para_id) {
        raise Unsupported(
          message="duplicate w14:paraId '\{para_id}'; the document's paraId state is not repairable",
        )
      }
      para_ids.add(para_id)
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
/// Ensures the w14 URI is bound on the comments ROOT and returns the
/// prefix to stamp attributes with: an existing binding is reused; an
/// absent one is retrofitted onto the root open tag together with the
/// markup-compatibility declaration (mc:Ignorable gains "w14").
fn ensure_w14_on_root(
  plan : @splice.SplicePlan,
  part : String,
  part_bytes : Bytes,
  root_span : NodeSpan,
) -> String raise DocxError {
  let attributes = scan_open_tag_attributes(part_bytes, root_span.byte_start())
  let mut w14_prefix : String? = None
  let mut mc_prefix : String? = None
  let mut ignorable : (String, Int, Int)? = None
  for attribute in attributes.entries {
    let (name, value, value_start, value_end) = attribute
    if value == W14_NAMESPACE && name.has_prefix("xmlns:") {
      w14_prefix = Some(name.view(start_offset=6).to_owned())
    }
    if value == MC_NAMESPACE && name.has_prefix("xmlns:") {
      mc_prefix = Some(name.view(start_offset=6).to_owned())
    }
    match mc_prefix {
      Some(prefix) =>
        if name == "\{prefix}:Ignorable" {
          ignorable = Some((value, value_start, value_end))
        }
      None => ()
    }
  }
  match w14_prefix {
    Some(prefix) => prefix
    None => {
      // Retrofit: declare w14 (and mc when absent) and extend
      // mc:Ignorable — all attribute splices on the root open tag.
      let mut addition = " xmlns:w14=\"\{W14_NAMESPACE}\""
      match (mc_prefix, ignorable) {
        (Some(_), Some((value, value_start, value_end))) => {
          // Append w14 to the EXISTING Ignorable value.
          ignore(value)
          plan.edit_part(
            part,
            @splice.span_edit(
              start=value_end,
              end=value_end,
              @utf8.encode(" w14"),
            ),
          )
          ignore(value_start)
        }
        (Some(prefix), None) => addition += " \{prefix}:Ignorable=\"w14\""
        (None, _) => {
          addition += " xmlns:mc=\"\{MC_NAMESPACE}\""
          addition += " mc:Ignorable=\"w14\""
        }
      }
      plan.edit_part(
        part,
        @splice.span_edit(
          start=attributes.tag_gt -
            (if attributes.self_closing { 1 } else { 0 }),
          end=attributes.tag_gt - (if attributes.self_closing { 1 } else { 0 }),
          @utf8.encode(addition),
        ),
      )
      "w14"
    }
  }
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
/// Reads the commentsExtended entries (empty when the part is absent);
/// duplicate paraId keys are unrepairable and fail closed here (the
/// tolerant READER'S first-wins policy is for reading, not mutating).
fn read_comment_ex_entries(
  zip : ZipArchive,
  annotated : DocxAnnotatedResult,
) -> Array[CommentExEntry] raise DocxError {
  let entries : Array[CommentExEntry] = []
  guard annotated.comments_extended_part() is Some(part) else { return entries }
  let part_read : String? = zip.read_text(part) catch { _ => None }
  guard part_read is Some(text) else {
    raise Unsupported(message="the commentsExtended part is unreadable")
  }
  let root = read_xml_string(text, namespace_map=office_namespace_map()) catch {
    _ =>
      raise Unsupported(
        message="the commentsExtended part is not well-formed XML; refusing",
      )
  }
  let seen : Set[String] = Set([])
  for record in root.elements_by_tag_name("w15:commentEx") {
    match record.attributes.get("w15:paraId") {
      Some(para_id) => {
        if seen.contains(para_id) {
          raise Unsupported(
            message="duplicate commentsExtended records for paraId '\{para_id}'; the thread state is not repairable",
          )
        }
        seen.add(para_id)
        entries.push({
          para_id,
          done: record.attributes.get("w15:done") is Some("1") ||
          record.attributes.get("w15:done") is Some("true"),
          parent_para_id: record.attributes.get("w15:paraIdParent"),
        })
      }
      None =>
        raise Unsupported(
          message="a commentsExtended record has no paraId; the thread state is not repairable",
        )
    }
  }
  entries
}

///|
/// Queues the commentsExtended WHOLE-PART update: rewrite when the part
/// exists, create and wire it when absent (relationship + Override
/// located structurally, exactly like the comments part in
/// plan_comment_addition).
fn queue_comments_extended(
  plan : @splice.SplicePlan,
  zip : ZipArchive,
  annotated : DocxAnnotatedResult,
  entries : Array[CommentExEntry],
) -> Unit raise DocxError {
  let records : Array[XmlNode] = []
  for entry in entries {
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
  match annotated.comments_extended_part() {
    Some(part) => {
      guard zip.read_bytes(part) is Some(old_bytes) else {
        raise Unsupported(message="the commentsExtended part is unreadable")
      }
      // Whole-part rewrite: the part holds pure linkage, so the
      // canonical serialization IS the declared edit span.
      plan.edit_part(
        part,
        @splice.span_edit(
          start=0,
          end=old_bytes.length(),
          @utf8.encode(part_text),
        ),
      )
    }
    None => {
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
        // A document with a wired comments part always has this rels
        // part; its absence here is unrepairable.
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
