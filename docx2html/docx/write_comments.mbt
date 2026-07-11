// K1 of the annotation writers: comments on freshly written documents.
// `write_docx_with_comments` is `write_docx` plus a set of comment specs
// anchored to top-level body paragraphs by block index. Anchors are
// emitted in the CANONICAL intra-paragraph shape the roadmap locked
// (pPr?, commentRangeStart, content, commentRangeEnd, reference run —
// each end immediately followed by its own reference run so read-back
// pairing is unambiguous), and comment definitions land in
// word/comments.xml wired as a relationship of the MAIN document part.
// Comment ids are dense: a spec's array index IS its w:id.

///|
/// One comment to attach to the written body: WHO (author, optional
/// initials and xsd:dateTime date), WHERE (an inclusive range of
/// top-level body block indexes, both endpoints paragraphs), and WHAT
/// (paragraph-only body content). Construct with `comment_spec`, which
/// fail-closes on everything a spec can get wrong in isolation.
pub struct CommentSpec {
  priv author : String
  priv initials : String?
  priv date : String?
  priv from_block : Int
  priv to_block : Int
  priv body : Array[DocumentElement]
}

///|
/// Validates and builds a `CommentSpec`. `from`/`to` are 0-based indexes
/// into the body array later passed to `write_docx_with_comments` (the
/// inclusive anchored range); bounds against that body are checked at
/// write time, everything spec-local is checked here so callers can
/// attribute the failure to the exact comment: non-empty
/// attribute-safe author, non-empty attribute-safe initials (when
/// given), a lexically valid xsd:dateTime date (when given), an ordered
/// non-negative range, and a non-empty paragraph-only body. Bodies are
/// PLAIN CONTENT by the roadmap's locked rule — hyperlinks and images
/// are rejected at write time because they would need relationships
/// this writer does not give the comments part.
pub fn comment_spec(
  author~ : String,
  initials? : String,
  date? : String,
  from~ : Int,
  to~ : Int,
  body : Array[DocumentElement],
) -> CommentSpec raise DocxError {
  if author == "" {
    raise Unsupported(message="a comment needs a non-empty author")
  }
  check_attribute_value("the comment author", author)
  match initials {
    Some("") =>
      raise Unsupported(
        message="comment initials must not be empty (omit them instead)",
      )
    Some(initials) => check_attribute_value("the comment initials", initials)
    None => ()
  }
  match date {
    Some(date) => check_comment_date(date)
    None => ()
  }
  if from < 0 {
    raise Unsupported(
      message="a comment anchor cannot start at block \{from}; block indexes are 0-based",
    )
  }
  if to < from {
    raise Unsupported(
      message="a comment anchor cannot end at block \{to}, before its start at block \{from}",
    )
  }
  if body.length() == 0 {
    raise Unsupported(
      message="a comment needs a non-empty body (at least one paragraph)",
    )
  }
  for block in body {
    guard block is Paragraph(..) else {
      raise Unsupported(
        message="comment bodies are paragraph-only in this writer (got \{block_kind_name(block)})",
      )
    }
  }
  { author, initials, date, from_block: from, to_block: to, body }
}

///|
/// `write_docx` plus comments. The body serializes exactly as
/// `write_docx` would (an empty `comments` array is byte-identical);
/// each comment then decorates its anchored paragraphs — range start
/// markers right after pPr in the `from` paragraph, range end plus the
/// id's reference run appended to the `to` paragraph — and its
/// definition is written to word/comments.xml. Both anchor endpoints
/// must be top-level paragraphs (tables cannot carry the canonical
/// intra-paragraph shape). Comment BODIES reuse the body writers, with
/// a fail-closed guard: content that allocates relationships or media
/// (hyperlinks, images) raises instead of emitting references that
/// would dangle in the comments part.
pub fn write_docx_with_comments(
  body : Array[DocumentElement],
  comments : Array[CommentSpec],
) -> Bytes raise DocxError {
  for index, comment in comments {
    if comment.from_block >= body.length() || comment.to_block >= body.length() {
      raise Unsupported(
        message="comments[\{index}] anchors blocks \{comment.from_block}..\{comment.to_block}, but the body has \{body.length()} block(s)",
      )
    }
    for endpoint in [comment.from_block, comment.to_block] {
      guard body[endpoint] is Paragraph(..) else {
        raise Unsupported(
          message="comments[\{index}] anchors block \{endpoint}, which is not a paragraph (comment anchors must be top-level paragraphs)",
        )
      }
    }
  }
  // Dense ids: the spec index is the w:id. Starts and ends are grouped
  // per block in ascending id order (array order), which the loops below
  // preserve.
  let starts_at : Map[Int, Array[Int]] = Map([])
  let ends_at : Map[Int, Array[Int]] = Map([])
  for id, comment in comments {
    match starts_at.get(comment.from_block) {
      Some(ids) => ids.push(id)
      None => starts_at[comment.from_block] = [id]
    }
    match ends_at.get(comment.to_block) {
      Some(ids) => ids.push(id)
      None => ends_at[comment.to_block] = [id]
    }
  }
  let blocks : Array[XmlNode] = []
  let ctx : WriteContext = {
    used_styles: Set([]),
    uses_lists: false,
    next_relationship: 3,
    document_relationships: [],
    media: [],
  }
  for index, element in body {
    let leading : Array[XmlNode] = []
    let trailing : Array[XmlNode] = []
    match starts_at.get(index) {
      Some(ids) =>
        for id in ids {
          leading.push(XmlElement(comment_range_start(id)))
        }
      None => ()
    }
    match ends_at.get(index) {
      Some(ids) =>
        // Each end is immediately followed by ITS reference run: when
        // several comments end on the same paragraph, interleaving keeps
        // every reference adjacent to its own range end (Word's shape).
        for id in ids {
          trailing.push(XmlElement(comment_range_end(id)))
          trailing.push(XmlElement(comment_reference_run(id)))
        }
      None => ()
    }
    if leading.length() > 0 || trailing.length() > 0 {
      guard body[index] is Paragraph(children~, properties~) else {
        // Unreachable: endpoints were verified to be paragraphs above.
        raise Unsupported(
          message="comment anchors must be top-level paragraphs",
        )
      }
      blocks.push(
        XmlElement(
          write_paragraph(children, properties, ctx, leading~, trailing~),
        ),
      )
    } else {
      blocks.push(XmlElement(write_block(element, ctx)))
    }
  }
  blocks.push(XmlElement(blank_section_properties()))
  // Comment bodies reuse the body writers and the same context (styles
  // and numbering are package-wide), but must not allocate document
  // relationships or media: those land in document.xml's rels part and
  // would dangle when referenced from comments.xml.
  let relationships_before = ctx.document_relationships.length()
  let media_before = ctx.media.length()
  let comment_elements : Array[XmlNode] = []
  for id, comment in comments {
    let children : Array[XmlNode] = []
    for paragraph in comment.body {
      children.push(XmlElement(write_block(paragraph, ctx)))
    }
    let attributes : Map[String, String] = {
      "w:id": id.to_string(),
      "w:author": comment.author,
    }
    match comment.initials {
      Some(initials) => attributes["w:initials"] = initials
      None => ()
    }
    match comment.date {
      Some(date) => attributes["w:date"] = date
      None => ()
    }
    comment_elements.push(
      XmlElement(@xml.xml_element("w:comment", attributes~, children~)),
    )
  }
  if ctx.document_relationships.length() > relationships_before ||
    ctx.media.length() > media_before {
    raise Unsupported(
      message="comment bodies are plain content: hyperlinks and images cannot be serialized into word/comments.xml (they would need relationships that part does not get)",
    )
  }
  // document.xml's extra namespaces depend on what the BODY used; the
  // comments relationship is allocated after this point on purpose —
  // it is an implicit relationship (found by type, never by r:id), so
  // it must not drag the r: declaration into an otherwise plain body.
  let namespaces : Map[String, String] = { "w": WORDPROCESSINGML_NAMESPACE }
  if ctx.document_relationships.length() > 0 {
    namespaces["r"] = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
  }
  if ctx.media.length() > 0 {
    namespaces["wp"] = "http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing"
    namespaces["a"] = "http://schemas.openxmlformats.org/drawingml/2006/main"
    namespaces["pic"] = "http://schemas.openxmlformats.org/drawingml/2006/picture"
  }
  let comments_xml : String? = if comments.length() > 0 {
    let _ = ctx.allocate_relationship(
      "http://schemas.openxmlformats.org/officeDocument/2006/relationships/comments",
      "comments.xml",
      external=false,
    )
    Some(
      @xml.write_xml_string(
        @xml.xml_element("w:comments", children=comment_elements),
        namespaces={ "w": WORDPROCESSINGML_NAMESPACE },
      ),
    )
  } else {
    None
  }
  let document = @xml.write_xml_string(
    @xml.xml_element("w:document", children=[
      XmlElement(@xml.xml_element("w:body", children=blocks)),
    ]),
    namespaces~,
  )
  let builder = @opc.PackageBuilder::new()
  build_docx_package(
    builder,
    document,
    styles_xml_for(ctx.used_styles),
    ctx,
    comments_xml~,
  ) catch {
    err =>
      raise Unsupported(
        message="could not assemble the document package: \{err}",
      )
  }
}

///|
fn comment_range_start(id : Int) -> XmlElement {
  @xml.xml_element("w:commentRangeStart", attributes={ "w:id": id.to_string() })
}

///|
fn comment_range_end(id : Int) -> XmlElement {
  @xml.xml_element("w:commentRangeEnd", attributes={ "w:id": id.to_string() })
}

///|
fn comment_reference_run(id : Int) -> XmlElement {
  @xml.xml_element("w:r", children=[
    XmlElement(
      @xml.xml_element("w:commentReference", attributes={
        "w:id": id.to_string(),
      }),
    ),
  ])
}

///|
/// Lexical validation of `w:date` — the practical xsd:dateTime subset
/// Word emits: `YYYY-MM-DDThh:mm:ss`, optional fractional seconds,
/// optional `Z` or `±hh:mm` zone. The accepted value is emitted
/// VERBATIM (the roadmap's lexical-timestamp rule: this writer never
/// normalizes dates), so validation is the only defense: 4-digit
/// non-zero year, a real calendar day (leap years included), hours
/// 00-23, minutes/seconds 00-59, zone offsets within ±14:00.
fn check_comment_date(date : String) -> Unit raise DocxError {
  let units = date.code_units()
  let length = units.length()
  fn digit(at : Int) -> Int? {
    if at < length {
      let code = units[at].to_int()
      if code >= '0'.to_int() && code <= '9'.to_int() {
        return Some(code - '0'.to_int())
      }
    }
    None
  }
  fn number(at : Int, digits : Int) -> Int? {
    let mut value = 0
    for offset in 0..<digits {
      match digit(at + offset) {
        Some(d) => value = value * 10 + d
        None => return None
      }
    }
    Some(value)
  }
  fn expect(at : Int, ch : Char) -> Bool {
    at < length && units[at].to_int() == ch.to_int()
  }
  fn fail(reason : String) -> DocxError {
    Unsupported(
      message="the comment date '\{date}' \{reason} (expected an xsd:dateTime like 2026-07-11T09:30:00Z)",
    )
  }
  guard number(0, 4) is Some(year) &&
    expect(4, '-') &&
    number(5, 2) is Some(month) &&
    expect(7, '-') &&
    number(8, 2) is Some(day) &&
    expect(10, 'T') &&
    number(11, 2) is Some(hour) &&
    expect(13, ':') &&
    number(14, 2) is Some(minute) &&
    expect(16, ':') &&
    number(17, 2) is Some(second) else {
    raise fail("is not shaped YYYY-MM-DDThh:mm:ss")
  }
  if year == 0 {
    raise fail("uses year 0000, which xsd:dateTime does not have")
  }
  if month < 1 || month > 12 {
    raise fail("has month \{month}")
  }
  if day < 1 || day > days_in_month(year, month) {
    raise fail("has day \{day}, which \{year}-\{month} does not reach")
  }
  if hour > 23 {
    raise fail("has hour \{hour} (00-23)")
  }
  if minute > 59 {
    raise fail("has minute \{minute}")
  }
  if second > 59 {
    raise fail("has second \{second}")
  }
  let mut cursor = 19
  if expect(cursor, '.') {
    cursor += 1
    guard digit(cursor) is Some(_) else {
      raise fail("has a fractional point with no digits")
    }
    while digit(cursor) is Some(_) {
      cursor += 1
    }
  }
  if cursor == length {
    return
  }
  if expect(cursor, 'Z') {
    cursor += 1
  } else if expect(cursor, '+') || expect(cursor, '-') {
    guard number(cursor + 1, 2) is Some(zone_hour) &&
      expect(cursor + 3, ':') &&
      number(cursor + 4, 2) is Some(zone_minute) else {
      raise fail("has a malformed zone offset (use ±hh:mm)")
    }
    if zone_hour > 14 ||
      zone_minute > 59 ||
      (zone_hour == 14 && zone_minute > 0) {
      raise fail("has a zone offset beyond ±14:00")
    }
    cursor += 6
  } else {
    raise fail("has trailing characters after the time")
  }
  if cursor != length {
    raise fail("has trailing characters after the zone")
  }
}

///|
fn days_in_month(year : Int, month : Int) -> Int {
  match month {
    1 | 3 | 5 | 7 | 8 | 10 | 12 => 31
    4 | 6 | 9 | 11 => 30
    _ =>
      if year % 4 == 0 && (year % 100 != 0 || year % 400 == 0) {
        29
      } else {
        28
      }
  }
}
