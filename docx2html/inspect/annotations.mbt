// Phase-2 J2: the annotation read surface — `docx.element/1` payloads for
// comments/footnotes/endnotes, the outline comments inventory, the
// annotation stories in `docx text`, and `comment_ids` reverse links —
// all projected from the AnnotationIndex (docx package), consumed through
// its accessors only.

///|
/// Builds the `docx.element/1` payload for ANY path, annotation roots
/// included, and augments covered body elements with `comment_ids`.
/// This is the CLI's entry; the body-only `element` stays for callers
/// without an index.
pub fn annotated_element(
  annotated : @docx_impl.DocxAnnotatedResult,
  file~ : String,
  path~ : String,
) -> Json raise PathError {
  let parsed = @paths.parse_path(path)
  let result = annotated.result()
  match parsed.root {
    Footnotes | Endnotes | Comments =>
      annotation_story_element(annotated, parsed, file~, path~)
    _ => {
      let payload = element(
        result.document,
        file~,
        path~,
        headers=result.headers,
        footers=result.footers,
      )
      // Reverse link: which comments' anchors intersect this element.
      let covering = annotated
        .annotations()
        .covering_comment_ids(rendered_path(parsed))
      if covering.length() > 0 {
        match payload {
          Object(map) => {
            let ids : Array[Json] = []
            for id in covering {
              ids.push(Json::string(id))
            }
            map["comment_ids"] = Json::array(ids)
          }
          _ => ()
        }
      }
      payload
    }
  }
}

///|
/// The normalized ORDINAL rendering of a parsed path (coverage lookups
/// key on the scanner's ordinal paths).
fn rendered_path(parsed : @paths.ParsedPath) -> String {
  let prefix = match parsed.root {
    Body => "/body"
    Header(index) => "/header[\{index}]"
    Footer(index) => "/footer[\{index}]"
    Footnotes => "/footnotes"
    Endnotes => "/endnotes"
    Comments => "/comments"
  }
  normalized_path(prefix, parsed.steps)
}

///|
fn annotation_story_element(
  annotated : @docx_impl.DocxAnnotatedResult,
  parsed : @paths.ParsedPath,
  file~ : String,
  path~ : String,
) -> Json raise PathError {
  let (pairs, container_kind, story, payload_kind) = match parsed.root {
    Footnotes => (annotated.footnote_bodies(), "note", "/footnotes", "footnote")
    Endnotes => (annotated.endnote_bodies(), "note", "/endnotes", "endnote")
    _ => (annotated.comment_bodies(), "comment", "/comments", "comment")
  }
  guard parsed.steps.length() > 0 else {
    raise PathError(
      "path '\{path}' addresses the whole \{story} story; select a \{container_kind} (e.g. \{story}/\{container_kind}[1])",
    )
  }
  // Resolve the target element through the shared annotation resolver
  // (it owns ordinal/id selection and the locked ambiguity error).
  let target = match parsed.root {
    Footnotes => @paths.resolve_annotation_path(path, footnotes=pairs)
    Endnotes => @paths.resolve_annotation_path(path, endnotes=pairs)
    _ => @paths.resolve_annotation_path(path, comments=pairs)
  }
  // Container ordinal for metadata + the normalized path rendering.
  let head = parsed.steps[0]
  let ordinal = match head.selector {
    Ordinal(index) => index
    ById(token) => {
      let mut found = 0
      for at, pair in pairs {
        let (id, _) = pair
        if id == token {
          found = at + 1
          break
        }
      }
      found
    }
  }
  let (head_rendered, _) = render_container_segment(
    pairs, container_kind, ordinal,
  )
  let normalized = normalized_path(
    "\{story}/\{head_rendered}",
    parsed.steps[1:].to_array(),
  )
  if parsed.steps.length() > 1 {
    // A body element inside the annotation: the ordinary element payload
    // shape, with the annotation-story path echo — including comment_ids
    // (J1 supports anchors in annotation stories; coverage keys on the
    // ORDINAL rendering, so the id-form head converts back).
    let out : Map[String, Json] = {
      "schema": Json::string(SCHEMA_ELEMENT),
      "file": Json::string(file),
      "path": Json::string(normalized),
      "kind": Json::string(element_kind_name(target, parsed.root)),
    }
    element_attributes(target, out)
    let coverage_key = normalized_path(
      "\{story}/\{container_kind}[\{ordinal}]",
      parsed.steps[1:].to_array(),
    )
    let covering = annotated.annotations().covering_comment_ids(coverage_key)
    if covering.length() > 0 {
      let ids : Array[Json] = []
      for id in covering {
        ids.push(Json::string(id))
      }
      out["comment_ids"] = Json::array(ids)
    }
    out["children"] = children_json(target, normalized)
    return Json::object(out)
  }
  // The container itself: annotation metadata from the index.
  let out : Map[String, Json] = {
    "schema": Json::string(SCHEMA_ELEMENT),
    "file": Json::string(file),
    "path": Json::string(normalized),
    "kind": Json::string(payload_kind),
  }
  let (id, _) = pairs[ordinal - 1]
  out["id"] = Json::string(id)
  match parsed.root {
    Comments => {
      // Definition entries precede marker-only entries and share the
      // comments.xml order, so ordinal k maps to comments()[k-1].
      let comments = annotated.annotations().comments()
      if ordinal - 1 < comments.length() {
        let info = comments[ordinal - 1]
        set_optional(out, "author", info.author())
        set_optional(out, "initials", info.initials())
        set_optional(out, "date", info.date())
        match info.done() {
          Some(done) => out["done"] = Json::boolean(done)
          None => ()
        }
        set_optional(out, "parent_id", info.parent_id())
        let anchors : Array[Json] = []
        for anchor in info.anchors() {
          anchors.push(anchor_json(annotated, anchor))
        }
        out["anchors"] = Json::array(anchors)
        match first_anchor_path(info) {
          Some(anchored) =>
            out["anchored_to"] = Json::string(id_form_path(annotated, anchored))
          None => ()
        }
      }
    }
    _ => {
      let notes = if parsed.root is Footnotes {
        annotated.annotations().footnotes()
      } else {
        annotated.annotations().endnotes()
      }
      for note in notes {
        if note.id() == id {
          let references : Array[Json] = []
          for reference in note.references() {
            references.push(Json::string(id_form_path(annotated, reference)))
          }
          out["references"] = Json::array(references)
          break
        }
      }
    }
  }
  out["children"] = children_json(target, normalized)
  Json::object(out)
}

///|
/// Renders a container segment: the id form when the id is UNIQUE in the
/// story (the agent-stable handle), else the ordinal (the plan's
/// uniqueness rule).
fn render_container_segment(
  pairs : Array[(String, Array[@document.DocumentElement])],
  container_kind : String,
  ordinal : Int,
) -> (String, Bool) {
  let (id, _) = pairs[ordinal - 1]
  let mut occurrences = 0
  for pair in pairs {
    let (candidate, _) = pair
    if candidate == id {
      occurrences += 1
    }
  }
  // The id form requires a UNIQUE id spelled with representable
  // characters (']' and '=' break the grammar; '/' breaks segmentation).
  if occurrences == 1 &&
    id != "" &&
    id.find("]").is_empty() &&
    id.find("=").is_empty() &&
    id.find("/").is_empty() {
    ("\{container_kind}[@id=\{id}]", false)
  } else {
    ("\{container_kind}[\{ordinal}]", true)
  }
}

///|
/// Rewrites an ordinal container segment inside a path to the id form
/// when the id is unique (emitted paths use the agent-stable handle;
/// the index keeps ordinal keys internally).
fn id_form_path(
  annotated : @docx_impl.DocxAnnotatedResult,
  path : String,
) -> String {
  let (story, pairs, container_kind) = if path.has_prefix("/comments/") {
    ("/comments", annotated.comment_bodies(), "comment")
  } else if path.has_prefix("/footnotes/") {
    ("/footnotes", annotated.footnote_bodies(), "note")
  } else if path.has_prefix("/endnotes/") {
    ("/endnotes", annotated.endnote_bodies(), "note")
  } else {
    return path
  }
  let rest = path["\{story}/".length():].to_owned()
  let head_end = match rest.find("/") {
    Some(slash) => slash
    None => rest.length()
  }
  let head = rest[:head_end].to_owned()
  let expected_prefix = "\{container_kind}["
  guard head.has_prefix(expected_prefix) && head.has_suffix("]") else {
    return path
  }
  let inner = head[expected_prefix.length():head.length() - 1].to_owned()
  let mut ordinal = 0
  for ch in inner {
    if ch is ('0'..='9') {
      ordinal = ordinal * 10 + (ch.to_int() - '0'.to_int())
    } else {
      return path
    }
  }
  if ordinal < 1 || ordinal > pairs.length() {
    return path
  }
  let (segment, _) = render_container_segment(pairs, container_kind, ordinal)
  "\{story}/\{segment}\{rest[head_end:].to_owned()}"
}

///|
fn anchor_json(
  annotated : @docx_impl.DocxAnnotatedResult,
  anchor : @docx_impl.AnnotationAnchor,
) -> Json {
  let out : Map[String, Json] = { "story": Json::string(anchor.story()) }
  match anchor.start() {
    Some(start) => out["start"] = Json::string(id_form_path(annotated, start))
    None => ()
  }
  match anchor.start_boundary() {
    Some(boundary) => out["start_boundary"] = Json::string("\{boundary}")
    None => ()
  }
  match anchor.end() {
    Some(end) => out["end"] = Json::string(id_form_path(annotated, end))
    None => ()
  }
  match anchor.end_boundary() {
    Some(boundary) => out["end_boundary"] = Json::string("\{boundary}")
    None => ()
  }
  let references : Array[Json] = []
  for reference in anchor.references() {
    references.push(Json::string(id_form_path(annotated, reference)))
  }
  out["references"] = Json::array(references)
  Json::object(out)
}

///|
/// The first anchor's start-else-first-reference path (the plan's
/// `anchored_to` convenience).
fn first_anchor_path(info : @docx_impl.CommentInfo) -> String? {
  let anchors = info.anchors()
  if anchors.length() == 0 {
    return None
  }
  let first = anchors[0]
  // Locked: start-else-first-reference; a dangling END is not an anchor
  // the agent should jump to.
  match first.start() {
    Some(start) => Some(start)
    None => {
      let references = first.references()
      if references.length() > 0 {
        Some(references[0])
      } else {
        None
      }
    }
  }
}

///|
/// The outline payload plus the `comments` inventory (id, author, done,
/// anchored_to, reply_to — metadata-priced, no bodies).
pub fn annotated_outline(
  annotated : @docx_impl.DocxAnnotatedResult,
  file~ : String,
) -> Json {
  let result = annotated.result()
  let payload = outline(
    result.document,
    file~,
    messages=result.messages,
    headers=result.headers,
    footers=result.footers,
    sections=result.sections,
  )
  match payload {
    Object(map) => {
      let inventory : Array[Json] = []
      for info in annotated.annotations().comments() {
        let entry : Map[String, Json] = { "id": Json::string(info.id()) }
        set_optional(entry, "author", info.author())
        match info.done() {
          Some(done) => entry["done"] = Json::boolean(done)
          None => ()
        }
        set_optional(entry, "parent_id", info.parent_id())
        match first_anchor_path(info) {
          Some(anchored) =>
            entry["anchored_to"] = Json::string(
              id_form_path(annotated, anchored),
            )
          None => ()
        }
        inventory.push(Json::object(entry))
      }
      map["comments"] = Json::array(inventory)
      Json::object(map)
    }
    other => other
  }
}

///|
/// Path-tagged text including the annotation stories, emitted after
/// headers/footers in story-rank order. Container segments use the id
/// form when unique (else ordinal).
pub fn annotated_text_lines(
  annotated : @docx_impl.DocxAnnotatedResult,
) -> Array[String] {
  let result = annotated.result()
  let lines = text_lines(
    result.document,
    headers=result.headers,
    footers=result.footers,
  )
  for
    story_entry in [
      ("/footnotes", "note", annotated.footnote_bodies()),
      ("/endnotes", "note", annotated.endnote_bodies()),
      ("/comments", "comment", annotated.comment_bodies()),
    ] {
    let (story, container_kind, pairs) = story_entry
    for at, pair in pairs {
      let (_, body) = pair
      let (segment, _) = render_container_segment(pairs, container_kind, at + 1)
      let container = @document.document(body)
      collect_text_lines(
        @paths.element_children(container),
        "\{story}/\{segment}",
        lines,
      )
    }
  }
  lines
}
