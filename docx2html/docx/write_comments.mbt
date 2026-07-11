// K1+K2 of the annotation writers: comments on freshly written
// documents. `write_docx_with_comments` is `write_docx` plus a set of
// comment specs — ANCHORED ones (a range of top-level body paragraphs
// by block index) and REPLIES (anchorless per the locked policy: a
// reply emits its definition and its commentsExtended linkage, and NO
// range or reference markers of its own). Anchors are emitted in the
// CANONICAL intra-paragraph shape the roadmap locked (pPr?,
// commentRangeStart, content, commentRangeEnd, reference run — each end
// immediately followed by its own reference run so read-back pairing is
// unambiguous), and comment definitions land in word/comments.xml wired
// as a relationship of the MAIN document part. Comment ids are dense: a
// spec's array index IS its w:id. When any spec threads (`reply_to`) or
// resolves (`done`), every comment body paragraph is stamped with a
// w14:paraId and word/commentsExtended.xml records one w15:commentEx
// per comment, keyed by the LAST body paragraph's paraId (the
// spec-backed choice; see the roadmap's locked decision) with
// w15:paraIdParent linking replies; without threading or resolution the
// output is byte-identical to the K1 writer.

///|
priv enum CommentTarget {
  Anchored(from~ : Int, to~ : Int)
  ReplyTo(Int)
}

///|
/// One comment to attach to the written body: WHO (author, optional
/// initials and xsd:dateTime date), WHERE (an inclusive range of
/// top-level body block indexes with both endpoints paragraphs — or,
/// for a reply, the earlier comment it answers), optionally a `done`
/// resolution flag, and WHAT (paragraph-only body content). Construct
/// with `comment_spec` (anchored) or `comment_reply` (anchorless),
/// which fail-close on everything a spec can get wrong in isolation.
pub struct CommentSpec {
  priv author : String
  priv initials : String?
  priv date : String?
  priv target : CommentTarget
  priv done : Bool?
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
  done? : Bool,
  body : Array[DocumentElement],
) -> CommentSpec raise DocxError {
  check_comment_who(author~, initials~, date~)
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
  { author, initials, date, target: Anchored(from~, to~), done, body }
}

///|
/// Validates and builds an anchorless REPLY: `reply_to` is the 0-based
/// index of an EARLIER spec in the array passed to
/// `write_docx_with_comments` (checked against the array there; chains
/// are allowed — a reply may answer another reply). Per the locked
/// policy a reply emits NO range or reference markers: its parent's
/// anchor is logically its own, and the thread linkage lives in
/// word/commentsExtended.xml (`w15:paraIdParent`). Everything else —
/// author/initials/date rules, the plain-content paragraph-only body —
/// matches `comment_spec`.
pub fn comment_reply(
  author~ : String,
  initials? : String,
  date? : String,
  reply_to~ : Int,
  done? : Bool,
  body : Array[DocumentElement],
) -> CommentSpec raise DocxError {
  check_comment_who(author~, initials~, date~)
  if reply_to < 0 {
    raise Unsupported(
      message="a reply cannot answer comment \{reply_to}; comment indexes are 0-based",
    )
  }
  check_comment_body(body)
  { author, initials, date, target: ReplyTo(reply_to), done, body }
}

///|
fn check_comment_who(
  author~ : String,
  initials~ : String?,
  date~ : String?,
) -> Unit raise DocxError {
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
  check_annotation_body(body, what="comment")
}

///|
/// Shared body-shape rules for every annotation kind (comments,
/// footnotes, endnotes): non-empty, paragraph-only, plain content all
/// the way down — and NO note references, which can neither nest in
/// notes nor appear in comments.
fn check_annotation_body(
  body : Array[DocumentElement],
  what~ : String,
) -> Unit raise DocxError {
  if body.length() == 0 {
    raise Unsupported(
      message="a \{what} needs a non-empty body (at least one paragraph)",
    )
  }
  for block in body {
    guard block is Paragraph(..) else {
      raise Unsupported(
        message="\{what} bodies are paragraph-only in this writer (got \{block_kind_name(block)})",
      )
    }
    check_annotation_content(block, what~)
  }
}

///|
fn check_annotation_content(
  element : DocumentElement,
  what~ : String,
) -> Unit raise DocxError {
  match element {
    Hyperlink(..) =>
      raise Unsupported(
        message="\{what} bodies are plain content: hyperlinks cannot be serialized into annotation parts",
      )
    Image(_) =>
      raise Unsupported(
        message="\{what} bodies are plain content: images cannot be serialized into annotation parts",
      )
    NoteReference(..) =>
      raise Unsupported(
        message="\{what} bodies cannot carry note references (notes nest in neither comments nor other notes)",
      )
    Document(children~, ..)
    | Paragraph(children~, ..)
    | Run(children~, ..)
    | Table(children~, ..)
    | TableRow(children~, ..)
    | TableCell(children~, ..) =>
      for child in children {
        check_annotation_content(child, what~)
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
/// intra-paragraph shape). REPLIES (`comment_reply`) must answer an
/// EARLIER spec in this array and emit no markers at all. Comment
/// BODIES reuse the body writers, with a fail-closed guard: content
/// that allocates relationships or media (hyperlinks, images) raises
/// instead of emitting references that would dangle in the comments
/// part. Threading or resolution anywhere adds w14:paraId stamps and
/// word/commentsExtended.xml; otherwise output is byte-identical to
/// the threading-free writer.
pub fn write_docx_with_comments(
  body : Array[DocumentElement],
  comments : Array[CommentSpec],
) -> Bytes raise DocxError {
  write_docx_with_annotations(body, comments~)
}

///|
/// The full annotation writer: `write_docx` plus comments (see
/// `write_docx_with_comments`) plus footnotes and endnotes. Notes are
/// referenced from body runs by `note_reference(kind, index)` where
/// `index` is the 0-based position in the matching array here — each
/// supplied note must be referenced EXACTLY ONCE (the canonical shape;
/// unreferenced notes would be invisible orphans, duplicate references
/// are not what Word produces). Note bodies are plain-content
/// paragraph-only, may not carry note references themselves, and land
/// in word/footnotes.xml / word/endnotes.xml as MAIN-part
/// relationships, complete with the separator/continuationSeparator
/// plumbing notes and the in-note footnoteRef/endnoteRef mark run.
pub fn write_docx_with_annotations(
  body : Array[DocumentElement],
  comments? : Array[CommentSpec] = [],
  footnotes? : Array[NoteSpec] = [],
  endnotes? : Array[NoteSpec] = [],
) -> Bytes raise DocxError {
  for index, note in footnotes {
    check_annotation_body(note.body, what="footnote") catch {
      Unsupported(message~) =>
        raise Unsupported(message="footnotes[\{index}]: \{message}")
      err => raise err
    }
  }
  for index, note in endnotes {
    check_annotation_body(note.body, what="endnote") catch {
      Unsupported(message~) =>
        raise Unsupported(message="endnotes[\{index}]: \{message}")
      err => raise err
    }
  }
  check_note_references(body, footnotes.length(), endnotes.length())
  for index, comment in comments {
    match comment.target {
      Anchored(from~, to~) => {
        if from >= body.length() || to >= body.length() {
          raise Unsupported(
            message="comments[\{index}] anchors blocks \{from}..\{to}, but the body has \{body.length()} block(s)",
          )
        }
        for endpoint in [from, to] {
          guard body[endpoint] is Paragraph(..) else {
            raise Unsupported(
              message="comments[\{index}] anchors block \{endpoint}, which is not a paragraph (comment anchors must be top-level paragraphs)",
            )
          }
        }
      }
      ReplyTo(parent) =>
        // Strictly earlier: chains are acyclic by construction.
        if parent >= index {
          raise Unsupported(
            message="comments[\{index}] replies to comment \{parent}, which is not an EARLIER comment (replies answer comments that already exist)",
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
    guard comment.target is Anchored(from~, to~) else {
      // Replies are anchorless: no markers anywhere in document.xml.
      continue
    }
    match starts_at.get(from) {
      Some(ids) => ids.push(id)
      None => starts_at[from] = [id]
    }
    match ends_at.get(to) {
      Some(ids) => ids.push(id)
      None => ends_at[to] = [id]
    }
  }
  let blocks : Array[XmlNode] = []
  let ctx : WriteContext = {
    used_styles: Set([]),
    uses_lists: false,
    next_relationship: 3,
    document_relationships: [],
    media: [],
    footnote_count: footnotes.length(),
    endnote_count: endnotes.length(),
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
  // Threading (a reply) or resolution (`done`) anywhere brings in the
  // w14/w15 machinery; without either, output stays byte-identical to
  // the threading-free writer.
  let mut needs_extended = false
  for comment in comments {
    if comment.done is Some(_) || comment.target is ReplyTo(_) {
      needs_extended = true
    }
  }
  // paraIds are stamped ONLY on comment body paragraphs (the locked
  // rule), allocated densely from a nonzero counter — ST_LongHexNumber
  // in Word's accepted window (below 0x80000000), collision-free by
  // construction. The commentEx KEY is the LAST body paragraph's id.
  let mut next_para_id = 1
  let last_para_ids : Array[String] = []
  let comment_elements : Array[XmlNode] = []
  for id, comment in comments {
    let children : Array[XmlNode] = []
    let mut last_para_id = ""
    for paragraph in comment.body {
      let element = write_block(paragraph, ctx)
      if needs_extended && element.name == "w:p" {
        let para_id = format_para_id(next_para_id)
        next_para_id += 1
        element.attributes["w14:paraId"] = para_id
        last_para_id = para_id
      }
      children.push(XmlElement(element))
    }
    last_para_ids.push(last_para_id)
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
    let comments_namespaces : Map[String, String] = {
      "w": WORDPROCESSINGML_NAMESPACE,
    }
    let root_attributes : Map[String, String] = Map([])
    if needs_extended {
      // w14:paraId is a Word-2010 extension: declare it plus markup
      // compatibility, and tell strict consumers it is ignorable.
      comments_namespaces["w14"] = W14_NAMESPACE
      comments_namespaces["mc"] = MC_NAMESPACE
      root_attributes["mc:Ignorable"] = "w14"
    }
    Some(
      @xml.write_xml_string(
        @xml.xml_element(
          "w:comments",
          attributes=root_attributes,
          children=comment_elements,
        ),
        namespaces=comments_namespaces,
      ),
    )
  } else {
    None
  }
  let footnotes_xml : String? = if footnotes.length() > 0 {
    let _ = ctx.allocate_relationship(
      "http://schemas.openxmlformats.org/officeDocument/2006/relationships/footnotes",
      "footnotes.xml",
      external=false,
    )
    Some(notes_part_xml("footnote", footnotes, ctx))
  } else {
    None
  }
  let endnotes_xml : String? = if endnotes.length() > 0 {
    let _ = ctx.allocate_relationship(
      "http://schemas.openxmlformats.org/officeDocument/2006/relationships/endnotes",
      "endnotes.xml",
      external=false,
    )
    Some(notes_part_xml("endnote", endnotes, ctx))
  } else {
    None
  }
  let comments_extended_xml : String? = if needs_extended {
    let _ = ctx.allocate_relationship(
      "http://schemas.microsoft.com/office/2011/relationships/commentsExtended",
      "commentsExtended.xml",
      external=false,
    )
    let entries : Array[XmlNode] = []
    for id, comment in comments {
      let attributes : Map[String, String] = {
        "w15:paraId": last_para_ids[id],
        "w15:done": if comment.done is Some(true) {
          "1"
        } else {
          "0"
        },
      }
      match comment.target {
        ReplyTo(parent) =>
          attributes["w15:paraIdParent"] = last_para_ids[parent]
        Anchored(..) => ()
      }
      entries.push(XmlElement(@xml.xml_element("w15:commentEx", attributes~)))
    }
    Some(
      @xml.write_xml_string(
        @xml.xml_element(
          "w15:commentsEx",
          attributes={ "mc:Ignorable": "w15" },
          children=entries,
        ),
        namespaces={ "w15": W15_NAMESPACE, "mc": MC_NAMESPACE },
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
    comments_extended_xml~,
    footnotes_xml~,
    endnotes_xml~,
  ) catch {
    err =>
      raise Unsupported(
        message="could not assemble the document package: \{err}",
      )
  }
}

///|
const W14_NAMESPACE : String = "http://schemas.microsoft.com/office/word/2010/wordml"

///|
const W15_NAMESPACE : String = "http://schemas.microsoft.com/office/word/2012/wordml"

///|
const MC_NAMESPACE : String = "http://schemas.openxmlformats.org/markup-compatibility/2006"

///|
/// Eight uppercase hex digits (ST_LongHexNumber). Callers keep the
/// counter positive and far below Word's 0x80000000 ceiling.
fn format_para_id(value : Int) -> String {
  let digits = "0123456789ABCDEF"
  let builder = StringBuilder::new()
  for shift in [28, 24, 20, 16, 12, 8, 4, 0] {
    let nibble = (value >> shift) & 0xF
    match digits.get_char(nibble) {
      Some(ch) => builder.write_char(ch)
      None => ()
    }
  }
  builder.to_string()
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
