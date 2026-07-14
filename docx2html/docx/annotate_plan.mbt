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
  plan_comment_addition_zip(
    annotated,
    open_zip(original),
    at_relative~,
    to_relative~,
    spec,
    max_fragment_bytes,
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
  max_fragment_bytes? : Int = 8 * 1024 * 1024,
) -> (@splice.SplicePlan, String) raise DocxError {
  plan_comment_addition_zip(
    annotated,
    open_zip_archive(archive),
    at_relative~,
    to_relative~,
    spec,
    max_fragment_bytes,
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
  let (start_fragment, end_fragment) = comment_anchor_fragments(id=new_id)
  let definition = comment_definition_fragment(
    spec,
    id=new_id,
    max_output_bytes=max_fragment_bytes,
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
      // Create the part NEXT TO the main part (a main part at
      // custom/main.xml gets custom/comments.xml, matching the
      // relative Target below).
      let (main_dir, main_base) = split_part_path(main_part)
      let comments_part_name = if main_dir == "" {
        "comments.xml"
      } else {
        "\{main_dir}/comments.xml"
      }
      // An entry with that name but NO comments relationship is an
      // ORPHAN part: splicing definitions into it would leave them
      // disconnected, and overwriting it would destroy data.
      if zip.exists(comments_part_name) {
        raise Unsupported(
          message="'\{comments_part_name}' exists but is not wired as the comments part (an orphan); refusing to annotate",
        )
      }
      let part_text = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>" +
        "<w:comments xmlns:w=\"\{WORDPROCESSINGML_NAMESPACE}\">" +
        definition +
        "</w:comments>"
      plan.add_part(comments_part_name, @utf8.encode(part_text))
      let rels_part = if main_dir == "" {
        "_rels/\{main_base}.rels"
      } else {
        "\{main_dir}/_rels/\{main_base}.rels"
      }
      let relationship_type = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/comments"
      match zip.read_bytes(rels_part) {
        Some(rels_bytes) => {
          // Allocate the id by PARSING the rels part — quoting and
          // whitespace variants make substring probes unsound.
          let rels_text = @utf8.decode(rels_bytes, ignore_bom=true) catch {
            _ =>
              raise Unsupported(
                message="'\{rels_part}' is not UTF-8; refusing to annotate",
              )
          }
          let rels_root = @xml.read_xml_string(rels_text) catch {
            _ =>
              raise Unsupported(
                message="'\{rels_part}' is not well-formed XML; refusing to annotate",
              )
          }
          let existing_ids : Set[String] = Set([])
          collect_relationship_ids(rels_root, existing_ids)
          let mut ordinal = 1
          while existing_ids.contains("rIdAnnotate\{ordinal}") {
            ordinal += 1
          }
          // The close tag is located in the BYTES ('<' is illegal in
          // attribute values, so this match is always real markup).
          guard find_ascii_bytes(rels_bytes, "</Relationships>")
            is Some(rels_at) else {
            raise Unsupported(
              message="could not locate the close of '\{rels_part}' (self-closing or unconventional relationships markup); refusing to annotate",
            )
          }
          plan.edit_part(
            rels_part,
            @splice.span_edit(
              start=rels_at,
              end=rels_at,
              @utf8.encode(
                "<Relationship Id=\"rIdAnnotate\{ordinal}\" Type=\"\{relationship_type}\" Target=\"comments.xml\"/>",
              ),
            ),
          )
        }
        None =>
          // A main part with no relationships part is legal; create it.
          plan.add_part(
            rels_part,
            @utf8.encode(
              "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>" +
              "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">" +
              "<Relationship Id=\"rIdAnnotate1\" Type=\"\{relationship_type}\" Target=\"comments.xml\"/>" +
              "</Relationships>",
            ),
          )
      }
      guard zip.read_bytes("[Content_Types].xml") is Some(types_bytes) else {
        raise Unsupported(message="the package is missing [Content_Types].xml")
      }
      guard find_ascii_bytes(types_bytes, "</Types>") is Some(types_at) else {
        raise Unsupported(
          message="could not locate the close of [Content_Types].xml; refusing to annotate",
        )
      }
      plan.edit_part(
        "[Content_Types].xml",
        @splice.span_edit(
          start=types_at,
          end=types_at,
          @utf8.encode(
            "<Override PartName=\"/\{comments_part_name}\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.comments+xml\"/>",
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
    guard zip.read_bytes(part) is Some(source) else {
      raise Unsupported(
        message="the splice plan edits '\{part}', which the source package does not contain",
      )
    }
    plan.pin_part(part, source)
  }
}

///|
/// The shared mutation gates: sidecars (relationship AND content type)
/// and unrepairable annotation state (diagnostic classes plus the
/// structural empty-id check a wording drift cannot evade).
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
  for warning in annotated.annotations().warnings() {
    if warning.find("ambiguous") is Some(_) ||
      warning.find("duplicate") is Some(_) ||
      warning.find("has no w:id") is Some(_) {
      raise Unsupported(
        message="the document's annotation state is not repairable (\{warning}); refusing to annotate",
      )
    }
  }
  for comment in annotated.annotations().comments() {
    if comment.id() == "" {
      raise Unsupported(
        message="the document holds a comment with an EMPTY id; refusing to annotate",
      )
    }
  }
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
fn collect_relationship_ids(element : XmlElement, ids : Set[String]) -> Unit {
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
/// First occurrence of an ASCII needle in raw bytes as REAL MARKUP:
/// XML comments and CDATA sections are skipped ('<' is illegal inside
/// attribute values, so those three region kinds are the only places a
/// '<'-led needle could match without being markup).
fn find_ascii_bytes(bytes : Bytes, needle : String) -> Int? {
  let needle_units = needle.code_units()
  let limit = bytes.length() - needle_units.length()
  fn starts_with(at : Int, text : String) -> Bool {
    if at + text.length() > bytes.length() {
      return false
    }
    for offset, unit in text.code_units() {
      if bytes[at + offset].to_int() != unit.to_int() {
        return false
      }
    }
    true
  }
  fn skip_past(from : Int, terminator : String) -> Int {
    let mut at = from
    while at <= bytes.length() - terminator.length() {
      if starts_with(at, terminator) {
        return at + terminator.length()
      }
      at += 1
    }
    bytes.length()
  }
  let mut at = 0
  while at <= limit {
    if starts_with(at, "<!--") {
      at = skip_past(at + 4, "-->")
      continue
    }
    if starts_with(at, "<![CDATA[") {
      at = skip_past(at + 9, "]]>")
      continue
    }
    // Processing instructions (and the XML declaration) may legally
    // hold the needle's text too.
    if starts_with(at, "<?") {
      at = skip_past(at + 2, "?>")
      continue
    }
    if starts_with(at, needle) {
      return Some(at)
    }
    at += 1
  }
  None
}

///|
/// One self-closing node ("<name attrs/>") rewritten to the open form
/// with `inner` inside, attributes and prefix preserved VERBATIM from
/// the original bytes.
fn self_closing_rewrite(
  part_bytes : Bytes,
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
  part_bytes : Bytes,
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
