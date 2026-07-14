// L0 — the byte-span preservation layer. The XML layer is canonicalizing
// (write(parse(x)) != x), so annotation surgery on EXISTING documents
// never reserializes: it splices well-formed fragments into the original
// part bytes at scanner-derived offsets and repacks the zip, keeping
// every untouched source record byte-for-byte. Guarantees (the L0 contract):
//
// - Mutated parts are byte-identical OUTSIDE the declared edit spans.
// - Untouched source entries retain their raw local/central records, order,
//   names, compression payloads, descriptors, and archive metadata. Rewritten
//   entries retain their source header policy while replacing only payload-
//   dependent fields. Fresh in-memory archives have no source records to keep.
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
  // Exact immutable source payloads for offset-bearing edits. Keeping the
  // bytes makes stale detection collision-free while sharing the archive's
  // existing immutable buffers.
  priv source_parts : Map[String, Bytes]
}

///|
/// An empty plan.
pub fn SplicePlan::new() -> SplicePlan {
  { part_edits: Map([]), new_parts: [], source_parts: Map([]) }
}

///|
/// Returns an independently mutable plan snapshot while sharing immutable
/// source and replacement byte buffers.
pub fn SplicePlan::copy(self : SplicePlan) -> SplicePlan {
  let part_edits : Map[String, Array[SpanEdit]] = Map([])
  for name, edits in self.part_edits {
    part_edits[name] = edits.copy()
  }
  let source_parts : Map[String, Bytes] = Map([])
  for name, source in self.source_parts {
    source_parts[name] = source
  }
  { part_edits, new_parts: self.new_parts.copy(), source_parts }
}

///|
/// True when the plan changes no existing part and adds no new part.
pub fn SplicePlan::is_empty(self : SplicePlan) -> Bool {
  self.part_edits.is_empty() && self.new_parts.is_empty()
}

///|
/// Pins an exact source payload for later stale-plan detection. Repeated pins
/// are allowed only when their bytes are identical.
pub fn SplicePlan::pin_part(
  self : SplicePlan,
  name : String,
  source : Bytes,
) -> Unit raise @core.DocxError {
  check_plan_part_name(name)
  match self.source_parts.get(name) {
    Some(existing) if existing != source =>
      raise Unsupported(
        message="the splice plan has conflicting source bytes for '\{name}'",
      )
    Some(_) => ()
    None => self.source_parts[name] = source
  }
}

///|
/// Returns the canonical, sorted union of edited and added package parts.
pub fn SplicePlan::declared_parts(self : SplicePlan) -> Array[String] {
  let names : Set[String] = Set([])
  for name, _ in self.part_edits {
    names.add(name)
  }
  for entry in self.new_parts {
    let (name, _) = entry
    names.add(name)
  }
  let result = names.to_array()
  result.sort()
  result
}

///|
/// Returns edited parts that do not carry exact source bytes, sorted by name.
/// Preservation-safe edit sessions reject such plans before adopting them.
pub fn SplicePlan::unpinned_edited_parts(self : SplicePlan) -> Array[String] {
  let result : Array[String] = []
  for name, _ in self.part_edits {
    if !self.source_parts.contains(name) {
      result.push(name)
    }
  }
  result.sort()
  result
}

///|
/// Merges another plan without consuming it. Source-pin disagreement,
/// duplicate additions, and edit/add conflicts fail before `self` changes.
pub fn SplicePlan::merge(
  self : SplicePlan,
  other : SplicePlan,
) -> Unit raise @core.DocxError {
  for name, expected in other.source_parts {
    match self.source_parts.get(name) {
      Some(existing) if existing != expected =>
        raise Unsupported(
          message="cannot merge splice plans with different source bytes for '\{name}'",
        )
      _ => ()
    }
  }
  for entry in other.new_parts {
    let (name, _) = entry
    if self.part_edits.contains(name) {
      raise Unsupported(
        message="cannot merge a splice plan that both edits and adds '\{name}'",
      )
    }
    for existing in self.new_parts {
      let (existing_name, _) = existing
      if existing_name == name {
        raise Unsupported(
          message="cannot merge splice plans that both add '\{name}'",
        )
      }
    }
  }
  for name, _ in other.part_edits {
    for existing in self.new_parts {
      let (existing_name, _) = existing
      if existing_name == name {
        raise Unsupported(
          message="cannot merge a splice plan that both adds and edits '\{name}'",
        )
      }
    }
  }
  for name, expected in other.source_parts {
    if !self.source_parts.contains(name) {
      self.source_parts[name] = expected
    }
  }
  for name, edits in other.part_edits {
    match self.part_edits.get(name) {
      Some(existing) => existing.append(edits)
      None => self.part_edits[name] = edits.copy()
    }
  }
  for entry in other.new_parts {
    self.new_parts.push(entry)
  }
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
  check_plan_part_name(name)
  if self.part_edits.contains(name) {
    raise Unsupported(
      message="the splice plan cannot both edit and add a part named '\{name}'",
    )
  }
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
/// Validates the complete plan against an already materialized archive without
/// mutating the archive or serializing a candidate. With `require_pins=true`,
/// every edited part must carry exact source bytes.
pub fn SplicePlan::check_against(
  self : SplicePlan,
  archive : @mbtzip.Archive,
  require_pins? : Bool = false,
) -> Unit raise @core.DocxError {
  let _ = build_spliced_archive(archive, self, require_pins)
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
  let output = build_spliced_archive(archive, plan, false)
  // The byte API can preserve a true no-op exactly, including archive bytes
  // the writer need not understand. Validation above still rejects ambiguous
  // duplicate names and stale pins before this fast path.
  if plan.is_empty() {
    return original.to_owned()
  }
  @mbtzip.write(output) catch {
    err =>
      raise InvalidZip(message="could not repack the package: \{to_repr(err)}")
  }
}

///|
/// Applies a plan to an already materialized archive and serializes through a
/// hard output ceiling. The caller's archive is never mutated; untouched
/// source records remain available to the ZIP writer for byte preservation.
pub fn splice_docx_archive(
  original : @mbtzip.Archive,
  plan : SplicePlan,
  max_output_bytes~ : Int,
  require_pins? : Bool = false,
) -> Bytes raise @core.DocxError {
  if max_output_bytes < 0 {
    raise Unsupported(message="the splice output limit cannot be negative")
  }
  let output = build_spliced_archive(original, plan, require_pins)
  @mbtzip.write_limited(output, max_output_bytes~) catch {
    err =>
      raise InvalidZip(message="could not repack the package: \{to_repr(err)}")
  }
}

///|
/// Checks and applies a plan to an isolated shallow fork. No serialization
/// happens here, so all logical failures precede candidate allocation.
fn build_spliced_archive(
  archive : @mbtzip.Archive,
  plan : SplicePlan,
  require_pins : Bool,
) -> @mbtzip.Archive raise @core.DocxError {
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
    check_plan_part_name(name)
    if !seen.contains(name) {
      raise Unsupported(
        message="the splice plan edits '\{name}', which the package does not contain",
      )
    }
    if require_pins && !plan.source_parts.contains(name) {
      raise Unsupported(
        message="the splice plan edits '\{name}' without pinned source bytes",
      )
    }
  }
  for entry in plan.new_parts {
    let (name, _) = entry
    check_plan_part_name(name)
    if seen.contains(name) {
      raise Unsupported(
        message="the splice plan adds '\{name}', which already exists in the package",
      )
    }
  }
  for name, expected in plan.source_parts {
    match archive.get(name) {
      Some(actual) if actual != expected =>
        raise Unsupported(
          message="the splice plan is stale: source part '\{name}' changed after the plan was built",
        )
      Some(_) => ()
      None =>
        raise Unsupported(
          message="the splice plan is stale: source part '\{name}' is no longer present",
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
  let output = archive.fork()
  for name, bytes in edited {
    if !output.replace(name, bytes) {
      raise Unsupported(
        message="the splice plan edits '\{name}', which the package does not contain",
      )
    }
  }
  for entry in plan.new_parts {
    let (name, bytes) = entry
    output.add(name, bytes)
  }
  output
}

///|
/// Plan-controlled names are stricter than arbitrary legacy ZIP names: every
/// edit/add manifest must be a canonical relative entry path.
fn check_plan_part_name(name : String) -> Unit raise @core.DocxError {
  if name.length() == 0 || name.has_prefix("/") || name.contains("\\") {
    raise Unsupported(
      message="splice plan part names must be canonical relative ZIP entry names ('\{name}')",
    )
  }
  for component in name.split("/") {
    if component.length() == 0 || component == "." || component == ".." {
      raise Unsupported(
        message="splice plan part names must not contain empty, '.', or '..' components ('\{name}')",
      )
    }
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
  // Well-formedness belt: a spliced part must still parse as strict, DTD-free
  // XML. This cannot vouch for schema validity or namespace WISDOM of a
  // fragment (that is the fragment author's contract, gated by the dual
  // validators downstream) — it catches structural breakage at the
  // exact part.
  let text = @utf8.decode(result, ignore_bom=true) catch {
    _ =>
      raise Unsupported(
        message="splicing '\{name}' produced bytes that are not valid UTF-8",
      )
  }
  let _ = @xml.read_xml_string_strict(text) catch {
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
  // Walk the declaration as PSEUDO-ATTRIBUTES (name = "value" | 'value'),
  // never scanning inside quoted values — "encoding" appearing inside a
  // VALUE is just text (review round 2). Any structural deviation is a
  // malformed declaration and fails closed. The XML grammar demands
  // WHITESPACE after '<?xml' and between pseudo-attributes, and at
  // least one pseudo-attribute (VersionInfo) — '<?xmlversion...',
  // '<?xml?>', and 'value"name' runs are all malformed (round 3).
  let limit = bytes.length()
  let mut cursor = at + 5
  if cursor >= limit || !is_decl_space(bytes[cursor]) {
    return MalformedDeclaration
  }
  let mut found : EncodingDeclaration = NoDeclaration
  // The declaration grammar is POSITIONAL: VersionInfo first
  // (required), then EncodingDecl?, then SDDecl?, nothing else —
  // '<?xml encoding=...?>' without version is malformed (round 4).
  // 0 = expect version; 1 = expect encoding|standalone|end;
  // 2 = expect standalone|end; 3 = expect end.
  let mut state = 0
  for ;; {
    while cursor < limit && is_decl_space(bytes[cursor]) {
      cursor += 1
    }
    if cursor + 1 < limit && bytes[cursor] == b'?' && bytes[cursor + 1] == b'>' {
      if state == 0 {
        return MalformedDeclaration
      }
      return found
    }
    // Pseudo-attribute name: ASCII letters only (version/encoding/
    // standalone).
    let name_start = cursor
    while cursor < limit && is_decl_name_byte(bytes[cursor]) {
      cursor += 1
    }
    if cursor == name_start {
      return MalformedDeclaration
    }
    let name_builder = StringBuilder::new()
    for offset in name_start..<cursor {
      name_builder.write_char(bytes[offset].to_int().to_char().unwrap_or('?'))
    }
    let name = name_builder.to_string()
    while cursor < limit && is_decl_space(bytes[cursor]) {
      cursor += 1
    }
    if cursor >= limit || bytes[cursor] != b'=' {
      return MalformedDeclaration
    }
    cursor += 1
    while cursor < limit && is_decl_space(bytes[cursor]) {
      cursor += 1
    }
    if cursor >= limit || !(bytes[cursor] == b'"' || bytes[cursor] == b'\'') {
      return MalformedDeclaration
    }
    let quote = bytes[cursor]
    cursor += 1
    let value_start = cursor
    while cursor < limit && bytes[cursor] != quote {
      cursor += 1
    }
    if cursor >= limit {
      return MalformedDeclaration
    }
    match (state, name) {
      (0, "version") => state = 1
      (1, "encoding") => {
        let value_builder = StringBuilder::new()
        for offset in value_start..<cursor {
          value_builder.write_char(
            bytes[offset].to_int().to_char().unwrap_or('?'),
          )
        }
        found = Declared(value_builder.to_string())
        state = 2
      }
      (1, "standalone") | (2, "standalone") => state = 3
      // Unknown names, duplicates, and out-of-order pseudo-attributes
      // are all grammar violations.
      _ => return MalformedDeclaration
    }
    cursor += 1
    // The next thing after a value must be whitespace or the end of
    // the declaration — 'value"name' runs are malformed.
    if cursor < limit && !is_decl_space(bytes[cursor]) && bytes[cursor] != b'?' {
      return MalformedDeclaration
    }
  }
}

///|
fn is_decl_name_byte(byte : Byte) -> Bool {
  (byte >= b'a' && byte <= b'z') || (byte >= b'A' && byte <= b'Z')
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
