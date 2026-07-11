// L0 — the byte-span preservation layer. The XML layer is canonicalizing
// (write(parse(x)) != x), so annotation surgery on EXISTING documents
// never reserializes: it splices well-formed fragments into the original
// part bytes at scanner-derived offsets and repacks the zip, keeping
// every untouched byte. Guarantees (the L0 contract):
//
// - Mutated parts are byte-identical OUTSIDE the declared edit spans.
// - Untouched entries keep UNCOMPRESSED-PAYLOAD equality plus their
//   original entry order, names, and compression method. Raw member
//   identity is impossible — the zip layer recompresses — and is
//   documented as such.
// - Fail-closed, all-or-nothing: duplicate zip entries, missing or
//   already-existing parts, overlapping or out-of-range spans, non-UTF-8
//   story encodings, and edits that leave a part XML-malformed all raise
//   BEFORE any output exists. This function is pure — publication
//   (atomic temp + no-replace rename) is the caller's contract.

///|
/// One byte-range replacement inside a part: the bytes at
/// `[start, end)` are replaced by `replacement`. A pure insertion has
/// `start == end`; a pure deletion has empty `replacement`.
pub struct SpanEdit {
  priv start : Int
  priv end : Int
  priv replacement : Bytes
}

///|
/// Validates and builds a `SpanEdit` (0 <= start <= end; range bounds
/// against the part are checked at splice time).
pub fn span_edit(
  start~ : Int,
  end~ : Int,
  replacement : Bytes,
) -> SpanEdit raise @core.DocxError {
  if start < 0 {
    raise Unsupported(message="a span edit cannot start at \{start}")
  }
  if end < start {
    raise Unsupported(
      message="a span edit cannot end at \{end}, before its start at \{start}",
    )
  }
  { start, end, replacement }
}

///|
/// The full mutation plan for one splice: per-part span edits plus
/// whole new parts. Build with `edit_part`/`add_part`, apply with
/// `splice_docx`.
pub struct SplicePlan {
  priv part_edits : Map[String, Array[SpanEdit]]
  priv new_parts : Array[(String, Bytes)]
}

///|
/// An empty plan.
pub fn SplicePlan::new() -> SplicePlan {
  { part_edits: Map([]), new_parts: [] }
}

///|
/// Adds one span edit to an EXISTING part (zip entry name, e.g.
/// "word/document.xml"). Edits on one part may arrive in any order;
/// they are sorted and checked for overlap at splice time.
pub fn SplicePlan::edit_part(
  self : SplicePlan,
  name : String,
  edit : SpanEdit,
) -> Unit {
  match self.part_edits.get(name) {
    Some(edits) => edits.push(edit)
    None => self.part_edits[name] = [edit]
  }
}

///|
/// Adds a whole NEW part. The name must not exist in the original
/// package (checked at splice time) nor be added twice.
pub fn SplicePlan::add_part(
  self : SplicePlan,
  name : String,
  bytes : Bytes,
) -> Unit raise @core.DocxError {
  for entry in self.new_parts {
    let (existing, _) = entry
    if existing == name {
      raise Unsupported(
        message="the splice plan already adds a part named '\{name}'",
      )
    }
  }
  self.new_parts.push((name, bytes))
}

///|
/// Applies the plan to the original package bytes and returns the new
/// package. All-or-nothing: every failure raises before any output is
/// produced (see the module header for the full fail-closed list).
pub fn splice_docx(
  original : BytesView,
  plan : SplicePlan,
) -> Bytes raise @core.DocxError {
  let archive = @mbtzip.read(original) catch {
    err =>
      raise InvalidZip(
        message="could not read the original package: \{to_repr(err)}",
      )
  }
  // Duplicate entry NAMES are crafted-file territory: which one a
  // consumer sees is implementation-defined, so surgery refuses them.
  let seen : Set[String] = Set([])
  for entry in archive.entries() {
    if seen.contains(entry.name()) {
      raise InvalidZip(
        message="the package holds duplicate zip entries named '\{entry.name()}'; refusing to splice",
      )
    }
    seen.add(entry.name())
  }
  for name, _ in plan.part_edits {
    if !seen.contains(name) {
      raise Unsupported(
        message="the splice plan edits '\{name}', which the package does not contain",
      )
    }
  }
  for entry in plan.new_parts {
    let (name, _) = entry
    if seen.contains(name) {
      raise Unsupported(
        message="the splice plan adds '\{name}', which already exists in the package",
      )
    }
  }
  // Apply per-part edits up front (fail before building anything).
  let edited : Map[String, Bytes] = Map([])
  for name, edits in plan.part_edits {
    match archive.get(name) {
      Some(bytes) => edited[name] = apply_span_edits(name, bytes, edits)
      None =>
        raise Unsupported(
          message="the splice plan edits '\{name}', which the package does not contain",
        )
    }
  }
  let output = @mbtzip.Archive::new()
  for entry in archive.entries() {
    let data = match edited.get(entry.name()) {
      Some(bytes) => bytes
      None => entry.data()
    }
    output.add(
      entry.name(),
      data,
      compression=entry.compression(),
      data_descriptor=entry.data_descriptor(),
    )
  }
  for entry in plan.new_parts {
    let (name, bytes) = entry
    output.add(name, bytes)
  }
  @mbtzip.write(output) catch {
    err =>
      raise InvalidZip(message="could not repack the package: \{to_repr(err)}")
  }
}

///|
/// Applies one part's edits: encoding gate, sort, overlap/range checks,
/// slice-splice, and the well-formedness belt on the result.
fn apply_span_edits(
  name : String,
  bytes : Bytes,
  edits : Array[SpanEdit],
) -> Bytes raise @core.DocxError {
  check_part_encoding(name, bytes)
  // Deterministic application order: by start; at EQUAL starts,
  // zero-width insertions land before a consuming edit, and edits that
  // still tie keep their PLAN order (Array::sort_by is unstable, so the
  // plan ordinal is part of the key) — two markers inserted at the same
  // offset of an empty paragraph must splice in the order planned.
  let decorated : Array[(Int, Int, Int, SpanEdit)] = []
  for ordinal, edit in edits {
    let consuming = if edit.end > edit.start { 1 } else { 0 }
    decorated.push((edit.start, consuming, ordinal, edit))
  }
  decorated.sort_by((a, b) => {
    let (a_start, a_consuming, a_ordinal, _) = a
    let (b_start, b_consuming, b_ordinal, _) = b
    if a_start != b_start {
      a_start - b_start
    } else if a_consuming != b_consuming {
      a_consuming - b_consuming
    } else {
      a_ordinal - b_ordinal
    }
  })
  let sorted : Array[SpanEdit] = []
  for entry in decorated {
    let (_, _, _, edit) = entry
    sorted.push(edit)
  }
  let mut previous_end = 0
  for edit in sorted {
    if edit.start < previous_end {
      raise Unsupported(
        message="the splice plan's edits on '\{name}' overlap (an edit starts at \{edit.start}, before the previous edit's end at \{previous_end})",
      )
    }
    if edit.end > bytes.length() {
      raise Unsupported(
        message="a splice edit on '\{name}' ends at \{edit.end}, past the part's \{bytes.length()} bytes",
      )
    }
    previous_end = edit.end
  }
  let builder = Buffer()
  let mut cursor = 0
  for edit in sorted {
    builder.write_bytesview(bytes[cursor:edit.start])
    builder.write_bytes(edit.replacement)
    cursor = edit.end
  }
  builder.write_bytesview(bytes[cursor:])
  let result = builder.contents()
  // Well-formedness belt: a spliced part must still parse as XML. This
  // cannot vouch for schema validity or namespace WISDOM of a fragment
  // (that is the fragment author's contract, gated by the dual
  // validators downstream) — it catches structural breakage at the
  // exact part.
  let text = @utf8.decode(result, ignore_bom=true) catch {
    _ =>
      raise Unsupported(
        message="splicing '\{name}' produced bytes that are not valid UTF-8",
      )
  }
  let _ = @xml.read_xml_string(text) catch {
    err =>
      raise Unsupported(
        message="splicing '\{name}' produced malformed XML (\{to_repr(err)}); refusing to emit",
      )
  }
  result
}

///|
/// The encoding gate: parts are spliced as UTF-8 bytes, so only UTF-8
/// (with or without BOM) is accepted — a UTF-16 BOM or a non-UTF-8
/// declared encoding fails closed, matching the annotation scanner's
/// own UTF-8-only rule (offsets from the scanner index UTF-8 bytes and
/// would be meaningless in any other encoding).
fn check_part_encoding(
  name : String,
  bytes : Bytes,
) -> Unit raise @core.DocxError {
  if bytes.length() >= 2 {
    let first = bytes[0].to_int()
    let second = bytes[1].to_int()
    if (first == 0xFF && second == 0xFE) || (first == 0xFE && second == 0xFF) {
      raise Unsupported(
        message="'\{name}' is UTF-16 encoded; byte-span splicing supports UTF-8 parts only",
      )
    }
  }
  // A declared encoding other than UTF-8 fails closed even when the
  // bytes would decode: offsets and fragments assume UTF-8. A
  // MALFORMED declaration (e.g. an unquoted encoding value) also fails
  // closed — the XML belt skips declarations, so nothing downstream
  // would catch it.
  match declared_encoding(bytes) {
    Declared(encoding) =>
      if !is_utf8_name(encoding) {
        raise Unsupported(
          message="'\{name}' declares encoding '\{encoding}'; byte-span splicing supports UTF-8 parts only",
        )
      }
    MalformedDeclaration =>
      raise Unsupported(
        message="'\{name}' has a malformed XML declaration (unparseable encoding value); refusing to splice",
      )
    NoDeclaration => ()
  }
}

///|
priv enum EncodingDeclaration {
  NoDeclaration
  Declared(String)
  MalformedDeclaration
}

///|
/// The encoding pseudo-attribute of the XML declaration, when the part
/// starts with one (BOM tolerated).
fn declared_encoding(bytes : Bytes) -> EncodingDeclaration {
  let mut at = 0
  // Skip a UTF-8 BOM.
  if bytes.length() >= 3 &&
    bytes[0].to_int() == 0xEF &&
    bytes[1].to_int() == 0xBB &&
    bytes[2].to_int() == 0xBF {
    at = 3
  }
  if at + 5 > bytes.length() {
    return NoDeclaration
  }
  if !(bytes[at] == b'<' &&
    bytes[at + 1] == b'?' &&
    bytes[at + 2] == b'x' &&
    bytes[at + 3] == b'm' &&
    bytes[at + 4] == b'l') {
    return NoDeclaration
  }
  // Scan the declaration (up to '?>') for encoding="..." | '...'.
  let mut cursor = at + 5
  let limit = bytes.length()
  while cursor + 1 < limit &&
        !(bytes[cursor] == b'?' && bytes[cursor + 1] == b'>') {
    if bytes[cursor] == b'e' && matches_at(bytes, cursor, "encoding") {
      let mut value_at = cursor + 8
      while value_at < limit && is_decl_space(bytes[value_at]) {
        value_at += 1
      }
      if value_at < limit && bytes[value_at] == b'=' {
        value_at += 1
        while value_at < limit && is_decl_space(bytes[value_at]) {
          value_at += 1
        }
        if value_at < limit &&
          (bytes[value_at] == b'"' || bytes[value_at] == b'\'') {
          let quote = bytes[value_at]
          let start = value_at + 1
          let mut end = start
          while end < limit && bytes[end] != quote {
            end += 1
          }
          if end < limit {
            let builder = StringBuilder::new()
            for offset in start..<end {
              builder.write_char(
                bytes[offset].to_int().to_char().unwrap_or('?'),
              )
            }
            return Declared(builder.to_string())
          }
        }
        // "encoding" seen but its value is unquoted or unterminated.
        return MalformedDeclaration
      }
      // "encoding" not followed by '=': also malformed as a
      // pseudo-attribute (XML declarations have a fixed grammar).
      return MalformedDeclaration
    }
    cursor += 1
  }
  NoDeclaration
}

///|
fn matches_at(bytes : Bytes, at : Int, needle : String) -> Bool {
  if at + needle.length() > bytes.length() {
    return false
  }
  for offset, unit in needle.code_units() {
    if bytes[at + offset].to_int() != unit.to_int() {
      return false
    }
  }
  true
}

///|
fn is_decl_space(byte : Byte) -> Bool {
  byte == b' ' || byte == b'\t' || byte == b'\r' || byte == b'\n'
}

///|
fn is_utf8_name(encoding : String) -> Bool {
  let mut lowered = ""
  for unit in encoding {
    let code = unit.to_int()
    let folded = if code >= 'A'.to_int() && code <= 'Z'.to_int() {
      code + 32
    } else {
      code
    }
    match folded.to_char() {
      Some(ch) => lowered = lowered + ch.to_string()
      None => return false
    }
  }
  lowered == "utf-8" || lowered == "utf8"
}
