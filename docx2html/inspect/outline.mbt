// Builds the `docx.outline/1` payload: a document structure map an agent can
// read before deciding what to extract or convert — element counts, the
// heading tree, styles in use, an image inventory, and reader diagnostics.
// Everything here is metadata-priced: no document text is emitted beyond
// heading lines.
//
// Counts and headings cover the MAIN BODY story only; footnotes, endnotes,
// and comments are counted as units (their body paragraphs are not folded
// into `paragraphs`). Nested body content (paragraphs inside table cells)
// IS included.

///|
/// Builds the `docx.outline/1` JSON payload for a parsed document. `file~`
/// is echoed into the payload so an agent can correlate output with input.
/// `messages~` carries the reader's diagnostics (from
/// `read_docx_with_messages`).
pub fn outline(
  document : @document.DocumentElement,
  file~ : String,
  messages? : Array[@core.Message] = [],
  headers? : Array[@document.HeaderFooterPart] = [],
  footers? : Array[@document.HeaderFooterPart] = [],
  sections? : Array[@document.DocumentSection] = [],
) -> Json {
  let walk = Walk::new()
  let (children, notes, comments) = match document {
    Document(children~, notes~, comments~) => (children, notes, comments)
    // A non-Document root (e.g. a bare paragraph from the builder DSL) is
    // treated as a one-element body so the payload shape stays uniform.
    other => ([other], [], [])
  }
  for child in children {
    walk.visit(child)
  }
  let counts : Map[String, Json] = {
    "paragraphs": count_json(walk.paragraphs),
    "tables": count_json(walk.tables),
    "images": count_json(walk.images.length()),
    "hyperlinks": count_json(walk.hyperlinks),
    "bookmarks": count_json(walk.bookmarks),
    "footnotes": count_json(count_notes(notes, "footnote")),
    "endnotes": count_json(count_notes(notes, "endnote")),
    "comments": count_json(comments.length()),
    "headers": count_json(headers.length()),
    "footers": count_json(footers.length()),
    "sections": count_json(sections.length()),
  }
  let images = []
  for image in walk.images {
    images.push(
      Json::object({
        "content_type": Json::string(image.content_type),
        "bytes": count_json(image.data.length()),
      }),
    )
  }
  let message_entries = []
  for message in messages {
    let (severity, text) = match message {
      Warning(text) => ("warning", text)
      Error(text) => ("error", text)
    }
    message_entries.push(
      Json::object({
        "severity": Json::string(severity),
        "text": Json::string(text),
      }),
    )
  }
  Json::object({
    "schema": Json::string(SCHEMA_OUTLINE),
    "file": Json::string(file),
    "counts": Json::object(counts),
    "headings": Json::array(walk.headings),
    "styles_in_use": Json::array(walk.styles),
    "images": Json::array(images),
    "sections": Json::array(sections.map(section_json)),
    "messages": Json::array(message_entries),
  })
}

///|
/// One section entry: which body paragraph it ends after (absent = runs to
/// the body end) and its header/footer references (`part` indexes the
/// 1-based `/header[n]` / `/footer[n]` path space).
fn section_json(section : @document.DocumentSection) -> Json {
  let out : Map[String, Json] = Map([])
  match section.ends_after_paragraph {
    Some(index) => out["ends_after_paragraph"] = count_json(index)
    None => ()
  }
  out["headers"] = Json::array(section.headers.map(section_ref_json))
  out["footers"] = Json::array(section.footers.map(section_ref_json))
  Json::object(out)
}

///|
fn section_ref_json(section_ref : @document.SectionRef) -> Json {
  Json::object({
    "variant": Json::string(section_ref.variant),
    "part": count_json(section_ref.part + 1),
  })
}

///|
fn count_json(n : Int) -> Json {
  Json::number(n.to_double())
}

///|
fn count_notes(notes : Array[@document.Note], note_type : String) -> Int {
  let mut count = 0
  for note in notes {
    if note.note_type == note_type {
      count += 1
    }
  }
  count
}

///|
/// Accumulator for one pass over the body tree.
priv struct Walk {
  mut paragraphs : Int
  mut tables : Int
  mut hyperlinks : Int
  mut bookmarks : Int
  images : Array[@document.Image]
  headings : Array[Json]
  styles : Array[Json]
  seen_styles : Set[String]
}

///|
fn Walk::new() -> Walk {
  {
    paragraphs: 0,
    tables: 0,
    hyperlinks: 0,
    bookmarks: 0,
    images: [],
    headings: [],
    styles: [],
    seen_styles: Set([]),
  }
}

///|
fn Walk::visit(self : Walk, element : @document.DocumentElement) -> Unit {
  match element {
    Paragraph(children~, properties~) => {
      self.paragraphs += 1
      self.record_style("paragraph", properties.style_id, properties.style_name)
      match heading_level(properties) {
        Some(level) => self.record_heading(element, level, properties)
        None => ()
      }
      self.visit_all(children)
    }
    Run(children~, properties~) => {
      self.record_style("run", properties.style_id, properties.style_name)
      self.visit_all(children)
    }
    Table(children~, properties~) => {
      self.tables += 1
      self.record_style("table", properties.style_id, properties.style_name)
      self.visit_all(children)
    }
    TableRow(children~, ..) | TableCell(children~, ..) =>
      self.visit_all(children)
    Hyperlink(children~, ..) => {
      self.hyperlinks += 1
      self.visit_all(children)
    }
    Image(image) => self.images.push(image)
    BookmarkStart(_) => self.bookmarks += 1
    Document(children~, ..) =>
      // Nested Document nodes do not occur in reader output; visit
      // defensively so builder-constructed trees never lose content.
      self.visit_all(children)
    Text(_)
    | Tab
    | Checkbox(_)
    | NoteReference(_)
    | CommentReference(_)
    | Break(_) => ()
  }
}

///|
fn Walk::visit_all(
  self : Walk,
  elements : Array[@document.DocumentElement],
) -> Unit {
  for element in elements {
    self.visit(element)
  }
}

///|
fn Walk::record_style(
  self : Walk,
  kind : String,
  style_id : String?,
  style_name : String?,
) -> Unit {
  if style_id is None && style_name is None {
    return
  }
  let key = "\{kind}\u{0}\{style_id.unwrap_or("")}\u{0}\{style_name.unwrap_or("")}"
  if self.seen_styles.contains(key) {
    return
  }
  self.seen_styles.add(key)
  let entry : Map[String, Json] = { "kind": Json::string(kind) }
  match style_id {
    Some(id) => entry["id"] = Json::string(id)
    None => ()
  }
  match style_name {
    Some(name) => entry["name"] = Json::string(name)
    None => ()
  }
  self.styles.push(Json::object(entry))
}

///|
fn Walk::record_heading(
  self : Walk,
  paragraph : @document.DocumentElement,
  level : Int,
  properties : @document.ParagraphProperties,
) -> Unit {
  // Raw text of a paragraph ends with Mammoth's "\n\n" separator; a heading
  // line should be just the line. A heading with no text (e.g. a
  // bookmark-only paragraph) is omitted — an empty entry orients nobody, and
  // the converter typically elides such paragraphs too.
  let text = paragraph.to_raw_text().trim_end(chars="\n").to_owned()
  if text == "" {
    return
  }
  let entry : Map[String, Json] = {
    "level": count_json(level),
    "text": Json::string(text),
  }
  match properties.style_id {
    Some(id) => entry["style_id"] = Json::string(id)
    None => ()
  }
  match properties.style_name {
    Some(name) => entry["style_name"] = Json::string(name)
    None => ()
  }
  self.headings.push(Json::object(entry))
}

///|
/// Resolves a paragraph's heading level using the same convention as the
/// Mammoth default style map (style_map.mbt), with the default map's rule
/// order and matching semantics: style IDS compare exactly, style NAMES
/// compare case-insensitively. In order: id `Heading1`..`Heading6`; name
/// equal (ignoring case) to `heading 1`..`heading 6`; bare id `Heading` or
/// bare name `heading` (level 1). Anything else — `Heading7`+, `Heading10`,
/// names without the space — is not a heading.
fn heading_level(properties : @document.ParagraphProperties) -> Int? {
  match digit_id_heading_level(properties.style_id) {
    Some(level) => Some(level)
    None =>
      match digit_name_heading_level(properties.style_name) {
        Some(level) => Some(level)
        None =>
          // The bare rules come last: a paragraph with id `Heading` but name
          // `Heading 3` is level 3, matching the default map's rule order.
          if properties.style_id is Some("Heading") ||
            lowercased(properties.style_name) is Some("heading") {
            Some(1)
          } else {
            None
          }
      }
  }
}

///|
fn digit_id_heading_level(style_id : String?) -> Int? {
  match style_id {
    Some(id) =>
      if id.has_prefix("Heading") && id.length() == 8 {
        digit_level(id[7])
      } else {
        None
      }
    None => None
  }
}

///|
fn digit_name_heading_level(style_name : String?) -> Int? {
  match lowercased(style_name) {
    Some(name) =>
      if name.has_prefix("heading ") && name.length() == 9 {
        digit_level(name[8])
      } else {
        None
      }
    None => None
  }
}

///|
fn lowercased(value : String?) -> String? {
  match value {
    Some(text) => Some(text.to_lower())
    None => None
  }
}

///|
fn digit_level(unit : UInt16) -> Int? {
  if unit is ('1'..='6') {
    Some(unit.to_int() - 0x30)
  } else {
    None
  }
}
