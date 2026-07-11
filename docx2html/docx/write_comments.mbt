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
/// PLAIN CONTENT by the roadmap's locked rule — hyperlinks (even
/// relationship-free anchor-only ones) and images are rejected here,
/// and again at write time because the arrays stay caller-mutable.
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
  check_comment_body(body)
  { author, initials, date, from_block: from, to_block: to, body }
}

///|
/// The comment-body shape rules, applied at CONSTRUCTION for early
/// attributable errors and REPEATED at write time — the body array (and
/// the child arrays inside its elements) stay caller-mutable after
/// `comment_spec` returns, so construction-time validation alone can be
/// invalidated through an alias. Non-empty, paragraph-only, and PLAIN
/// CONTENT all the way down: hyperlinks are rejected even when they
/// would allocate no relationship (an anchor-only link is still a
/// hyperlink), so this cannot be left to the relationship-delta guard.
fn check_comment_body(body : Array[DocumentElement]) -> Unit raise DocxError {
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
    check_comment_content(block)
  }
}

///|
fn check_comment_content(element : DocumentElement) -> Unit raise DocxError {
  match element {
    Hyperlink(..) =>
      raise Unsupported(
        message="comment bodies are plain content: hyperlinks cannot be serialized into word/comments.xml",
      )
    Image(_) =>
      raise Unsupported(
        message="comment bodies are plain content: images cannot be serialized into word/comments.xml",
      )
    Document(children~, ..)
    | Paragraph(children~, ..)
    | Run(children~, ..)
    | Table(children~, ..)
    | TableRow(children~, ..)
    | TableCell(children~, ..) =>
      for child in children {
        check_comment_content(child)
      }
    _ => ()
  }
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
    // Re-validate the body: it is an aliased mutable array, so the
    // constructor's guarantees may no longer hold by write time.
    check_comment_body(comment.body) catch {
      Unsupported(message~) =>
        raise Unsupported(message="comments[\{index}]: \{message}")
      err => raise err
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
/// Lexical validation of `w:date` against the COMPLETE xsd:dateTime
/// (XSD 1.0) lexical space: optional leading `-`, a 4-or-more-digit
/// year (no leading zero once longer than four digits; `0000` does not
/// exist in XSD 1.0), a real calendar day (XSD 1.0 has no year zero,
/// so lexical `-N` is astronomical year `1-N` — `-0001` IS a leap
/// year), `24:00:00` allowed as end-of-day when minutes, seconds, and
/// every fractional digit are zero, optional fractional seconds,
/// optional `Z` or `±hh:mm` zone within ±14:00. The accepted value is
/// emitted VERBATIM (the roadmap's lexical-timestamp rule: this writer
/// never normalizes dates), so this check is the only defense.
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
  let mut cursor = 0
  let negative_year = expect(cursor, '-')
  if negative_year {
    cursor += 1
  }
  // The year can be arbitrarily long, so its value never lands in an
  // Int: the leap rule needs only year mod 400 (both %4 and %100 are
  // determined by it), folded digit by digit.
  let year_start = cursor
  let mut year_mod_400 = 0
  let mut year_is_zero = true
  while digit(cursor) is Some(d) {
    year_mod_400 = (year_mod_400 * 10 + d) % 400
    if d != 0 {
      year_is_zero = false
    }
    cursor += 1
  }
  if negative_year {
    // XSD 1.0 has no year zero: lexical -N is astronomical year 1-N,
    // so the leap residue shifts by one across the era boundary.
    year_mod_400 = ((1 - year_mod_400) % 400 + 400) % 400
  }
  let year_digits = cursor - year_start
  if year_digits < 4 {
    raise fail("needs a year of at least four digits")
  }
  if year_digits > 4 && expect(year_start, '0') {
    raise fail("has a leading zero in a year longer than four digits")
  }
  if year_is_zero {
    raise fail("uses year 0000, which xsd:dateTime (XSD 1.0) does not have")
  }
  guard expect(cursor, '-') &&
    number(cursor + 1, 2) is Some(month) &&
    expect(cursor + 3, '-') &&
    number(cursor + 4, 2) is Some(day) &&
    expect(cursor + 6, 'T') &&
    number(cursor + 7, 2) is Some(hour) &&
    expect(cursor + 9, ':') &&
    number(cursor + 10, 2) is Some(minute) &&
    expect(cursor + 12, ':') &&
    number(cursor + 13, 2) is Some(second) else {
    raise fail("is not shaped YYYY-MM-DDThh:mm:ss")
  }
  cursor += 15
  if month < 1 || month > 12 {
    raise fail("has month \{month}")
  }
  if day < 1 || day > days_in_month(year_mod_400, month) {
    raise fail(
      "has day \{day}, which that year's month \{month} does not reach",
    )
  }
  // XSD end-of-day: hour 24 demands zero minutes, seconds, and fraction.
  let end_of_day = hour == 24
  if hour > 24 {
    raise fail("has hour \{hour} (00-23, or 24:00:00 for end of day)")
  }
  if minute > 59 {
    raise fail("has minute \{minute}")
  }
  if second > 59 {
    raise fail("has second \{second}")
  }
  if end_of_day && (minute != 0 || second != 0) {
    raise fail("uses hour 24 with nonzero minutes or seconds")
  }
  if expect(cursor, '.') {
    cursor += 1
    guard digit(cursor) is Some(_) else {
      raise fail("has a fractional point with no digits")
    }
    while digit(cursor) is Some(fraction_digit) {
      if end_of_day && fraction_digit != 0 {
        raise fail("uses hour 24 with a nonzero fraction")
      }
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
/// Days per month given the year's residue mod 400 (which fixes the
/// Gregorian leap decision: %4 and %100 both divide 400).
fn days_in_month(year_mod_400 : Int, month : Int) -> Int {
  match month {
    1 | 3 | 5 | 7 | 8 | 10 | 12 => 31
    4 | 6 | 9 | 11 => 30
    _ =>
      if year_mod_400 % 4 == 0 && (year_mod_400 % 100 != 0 || year_mod_400 == 0) {
        29
      } else {
        28
      }
  }
}
