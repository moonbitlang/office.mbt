// L0 — the byte-span preservation layer. The XML layer is canonicalizing
// (write(parse(x)) != x), so annotation surgery on EXISTING documents
// never reserializes: it splices well-formed fragments into the original
// part bytes at scanner-derived offsets and repacks the zip, preserving
// untouched source records under the ZIP format's offset rules. Guarantees
// (the L0 contract):
//
// - Mutated parts are byte-identical OUTSIDE the declared edit spans.
// - Untouched source entries retain their raw local records, order, names,
//   compression payloads, descriptors, and producer metadata. Central records
//   retain all metadata except the required local-offset field when preceding
//   sizes move. Rewritten entries retain their source header policy while
//   replacing payload-dependent fields. Fresh archives have no source records.
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
  priv source_parts : Map[String, BytesView]
}

///|
/// Transaction-grade limits applied before a splice allocates edited payloads
/// or serialized package bytes. The type is opaque so callers must construct a
/// complete, internally consistent limit set.
pub struct SpliceLimits {
  priv max_archive_entries : Int
  priv max_changed_parts : Int
  priv max_part_name_chars : Int
  priv max_entry_uncompressed_bytes : Int
  priv max_total_uncompressed_bytes : Int
  priv max_materialized_bytes : Int
  priv max_xml_tokens : Int
}

///|
/// Builds the fail-closed resource contract for a preservation splice.
pub fn splice_limits(
  max_archive_entries~ : Int,
  max_changed_parts~ : Int,
  max_part_name_chars~ : Int,
  max_entry_uncompressed_bytes~ : Int,
  max_total_uncompressed_bytes~ : Int,
  max_materialized_bytes~ : Int,
  max_xml_tokens~ : Int,
) -> SpliceLimits raise @core.DocxError {
  if max_archive_entries <= 0 ||
    max_changed_parts <= 0 ||
    max_part_name_chars <= 0 ||
    max_entry_uncompressed_bytes <= 0 ||
    max_total_uncompressed_bytes <= 0 ||
    max_materialized_bytes < 0 ||
    max_xml_tokens <= 0 {
    raise Unsupported(
      message="splice limits must be positive (materialized bytes may be zero)",
    )
  }
  if max_entry_uncompressed_bytes > max_total_uncompressed_bytes {
    raise Unsupported(
      message="the splice entry limit cannot exceed its aggregate uncompressed limit",
    )
  }
  {
    max_archive_entries,
    max_changed_parts,
    max_part_name_chars,
    max_entry_uncompressed_bytes,
    max_total_uncompressed_bytes,
    max_materialized_bytes,
    max_xml_tokens,
  }
}

///|
/// An empty plan.
pub fn SplicePlan::new() -> SplicePlan {
  { part_edits: Map([]), new_parts: [], source_parts: Map([]) }
}

///|
/// Returns an independently mutable plan snapshot. Every map and edit array is
/// copied; replacement/addition `Bytes` and source `BytesView` values may be
/// shared because MoonBit exposes both as immutable byte sequences.
pub fn SplicePlan::copy(self : SplicePlan) -> SplicePlan {
  let part_edits : Map[String, Array[SpanEdit]] = Map([])
  for name, edits in self.part_edits {
    part_edits[name] = edits.copy()
  }
  let source_parts : Map[String, BytesView] = Map([])
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
  source : BytesView,
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
  self.add_checked_part(name, bytes)
}

///|
/// Adds a whole new part after applying the transaction-grade name and entry
/// ceilings. The Unicode-scalar/UTF-16 check deliberately runs before path
/// splitting or diagnostics can copy an attacker-controlled name.
pub fn SplicePlan::add_part_limited(
  self : SplicePlan,
  name : String,
  bytes : Bytes,
  limits : SpliceLimits,
) -> Unit raise @core.DocxError {
  check_plan_part_name_limit(name, limits.max_part_name_chars)
  if bytes.length() > limits.max_entry_uncompressed_bytes {
    raise Unsupported(
      message="the splice entry uncompressed limit is \{limits.max_entry_uncompressed_bytes} bytes",
    )
  }
  check_plan_part_name(name)
  self.add_checked_part(name, bytes)
}

///|
fn SplicePlan::add_checked_part(
  self : SplicePlan,
  name : String,
  bytes : Bytes,
) -> Unit raise @core.DocxError {
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
  limits? : SpliceLimits,
) -> Unit raise @core.DocxError {
  let _ = build_spliced_archive(archive, self, require_pins, limits)
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
  let output = build_spliced_archive(archive, plan, false, None)
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
  limits? : SpliceLimits,
) -> Bytes raise @core.DocxError {
  if max_output_bytes < 0 {
    raise Unsupported(message="the splice output limit cannot be negative")
  }
  let output = build_spliced_archive(original, plan, require_pins, limits)
  @mbtzip.write_limited(output, max_output_bytes~) catch {
    OutputLimitExceeded(limit~) =>
      raise Unsupported(
        message="the spliced package exceeds the output limit of \{limit} bytes",
      )
    err =>
      raise InvalidZip(message="could not repack the package: \{to_repr(err)}")
  }
}

///|
/// One checked existing-part splice. Preparation sorts and validates the
/// ranges and computes the exact result size/token count without allocating
/// the edited payload.
priv struct PreparedPartSplice {
  name : String
  source : BytesView
  edits : Array[SpanEdit]
  result_length : Int
  replacement_bytes : Int64
}

///|
fn checked_splice_size_add(
  current : Int64,
  additional : Int64,
  what : String,
) -> Int64 raise @core.DocxError {
  if current < 0L ||
    additional < 0L ||
    current > 9223372036854775807L - additional {
    raise Unsupported(message="the splice \{what} size overflows Int64")
  }
  current + additional
}

///|
/// Checks and applies a plan to an isolated shallow fork. When limits are
/// supplied, every count and exact output size is accepted before the first
/// edited payload is allocated. No package serialization happens here.
fn build_spliced_archive(
  archive : @mbtzip.Archive,
  plan : SplicePlan,
  require_pins : Bool,
  limits : SpliceLimits?,
) -> @mbtzip.Archive raise @core.DocxError {
  // Duplicate entry NAMES are crafted-file territory: which one a
  // consumer sees is implementation-defined, so surgery refuses them.
  let seen : Set[String] = Set([])
  let mut source_entry_count = 0
  let mut source_uncompressed_bytes = 0L
  for entry in archive.entries() {
    if seen.contains(entry.name()) {
      raise InvalidZip(
        message="the package holds duplicate zip entries named '\{entry.name()}'; refusing to splice",
      )
    }
    seen.add(entry.name())
    source_entry_count = source_entry_count + 1
    let entry_length = entry.data().length()
    source_uncompressed_bytes = checked_splice_size_add(
      source_uncompressed_bytes,
      entry_length.to_int64(),
      "source aggregate",
    )
    match limits {
      Some(value) => {
        if source_entry_count > value.max_archive_entries {
          raise Unsupported(
            message="the splice archive entry limit is \{value.max_archive_entries}, but the source has at least \{source_entry_count} entries",
          )
        }
        if entry_length > value.max_entry_uncompressed_bytes {
          raise Unsupported(
            message="the splice entry uncompressed limit is \{value.max_entry_uncompressed_bytes} bytes, but '\{entry.name()}' has \{entry_length} bytes",
          )
        }
        if source_uncompressed_bytes >
          value.max_total_uncompressed_bytes.to_int64() {
          raise Unsupported(
            message="the splice aggregate uncompressed limit is \{value.max_total_uncompressed_bytes} bytes, but the source exceeds it",
          )
        }
      }
      None => ()
    }
  }
  let mut changed_part_count = plan.new_parts.length().to_int64()
  let mut span_edit_count = 0L
  for _, edits in plan.part_edits {
    changed_part_count = checked_splice_size_add(
      changed_part_count, 1L, "preservation manifest",
    )
    span_edit_count = checked_splice_size_add(
      span_edit_count,
      edits.length().to_int64(),
      "span edit count",
    )
  }
  match limits {
    Some(value) => {
      if changed_part_count > value.max_changed_parts.to_int64() {
        raise Unsupported(
          message="the splice preservation manifest limit is \{value.max_changed_parts} parts, but the plan declares \{changed_part_count}",
        )
      }
      if plan.new_parts.length() >
        value.max_archive_entries - source_entry_count {
        raise Unsupported(
          message="the splice archive entry limit is \{value.max_archive_entries}, but the result would contain too many entries",
        )
      }
      if span_edit_count > value.max_xml_tokens.to_int64() {
        raise Unsupported(
          message="the splice span edit limit is \{value.max_xml_tokens}, but the plan declares \{span_edit_count}",
        )
      }
    }
    None => ()
  }
  for name, _ in plan.part_edits {
    match limits {
      Some(value) => check_plan_part_name_limit(name, value.max_part_name_chars)
      None => ()
    }
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
    let (name, bytes) = entry
    match limits {
      Some(value) => {
        check_plan_part_name_limit(name, value.max_part_name_chars)
        if bytes.length() > value.max_entry_uncompressed_bytes {
          raise Unsupported(
            message="the splice entry uncompressed limit is \{value.max_entry_uncompressed_bytes} bytes, but added part '\{name}' has \{bytes.length()} bytes",
          )
        }
      }
      None => ()
    }
    check_plan_part_name(name)
    if seen.contains(name) {
      raise Unsupported(
        message="the splice plan adds '\{name}', which already exists in the package",
      )
    }
  }
  for name, expected in plan.source_parts {
    match limits {
      Some(value) => check_plan_part_name_limit(name, value.max_part_name_chars)
      None => ()
    }
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
  // Prepare every existing-part edit and compute the exact result/archive
  // sizes before allocating any replacement payload.
  let prepared : Array[PreparedPartSplice] = []
  let mut result_uncompressed_bytes = source_uncompressed_bytes
  let mut materialized_bytes = 0L
  let edited : Map[String, Bytes] = Map([])
  for name, edits in plan.part_edits {
    match archive.get(name) {
      Some(bytes) => {
        let part = prepare_span_edits(name, bytes, edits, limits)
        result_uncompressed_bytes = checked_splice_size_add(
          result_uncompressed_bytes - bytes.length().to_int64(),
          part.result_length.to_int64(),
          "result aggregate",
        )
        materialized_bytes = checked_splice_size_add(
          checked_splice_size_add(
            materialized_bytes,
            part.replacement_bytes,
            "materialization",
          ),
          part.result_length.to_int64(),
          "materialization",
        )
        prepared.push(part)
      }
      None =>
        raise Unsupported(
          message="the splice plan edits '\{name}', which the package does not contain",
        )
    }
  }
  for entry in plan.new_parts {
    let (_, bytes) = entry
    result_uncompressed_bytes = checked_splice_size_add(
      result_uncompressed_bytes,
      bytes.length().to_int64(),
      "result aggregate",
    )
    materialized_bytes = checked_splice_size_add(
      materialized_bytes,
      bytes.length().to_int64(),
      "materialization",
    )
  }
  match limits {
    Some(value) => {
      if result_uncompressed_bytes >
        value.max_total_uncompressed_bytes.to_int64() {
        raise Unsupported(
          message="the splice aggregate uncompressed limit is \{value.max_total_uncompressed_bytes} bytes, but the result requires \{result_uncompressed_bytes}",
        )
      }
      if materialized_bytes > value.max_materialized_bytes.to_int64() {
        raise Unsupported(
          message="the splice materialization limit is \{value.max_materialized_bytes} bytes, but replacements, added parts, and edited payloads require \{materialized_bytes}",
        )
      }
    }
    None => ()
  }
  // Only after the whole plan passes the global preflight may edited payloads
  // and their temporary strict-XML validation trees be materialized.
  for part in prepared {
    edited[part.name] = apply_prepared_span_edits(part)
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
/// Applies the transaction's Unicode-scalar ceiling to a plan-controlled name
/// and rejects malformed UTF-16 before any diagnostic copies the name.
fn check_plan_part_name_limit(
  name : String,
  max_chars : Int,
) -> Unit raise @core.DocxError {
  let mut offset = 0
  let mut scalars = 0
  while offset < name.length() {
    let unit = name[offset]
    if unit.is_leading_surrogate() {
      if offset + 1 >= name.length() ||
        !name[offset + 1].is_trailing_surrogate() {
        raise Unsupported(
          message="the splice part name limit requires valid UTF-16 names",
        )
      }
      offset = offset + 2
    } else if unit.is_trailing_surrogate() {
      raise Unsupported(
        message="the splice part name limit requires valid UTF-16 names",
      )
    } else {
      offset = offset + 1
    }
    scalars = scalars + 1
    if scalars > max_chars {
      raise Unsupported(
        message="the splice part name limit is \{max_chars} Unicode scalars",
      )
    }
  }
}

///|
/// Conservative strict-parser cardinality proxy counted directly over the
/// future result segments: element starts plus attribute assignments.
fn xml_markup_tokens(bytes : BytesView) -> Int64 {
  let mut count = 0L
  for byte in bytes {
    if byte == b'<' || byte == b'=' {
      count = count + 1L
    }
  }
  count
}

///|
/// Performs the encoding, ordering, overlap, range, exact-size, and XML-token
/// preflight for one part without allocating its edited payload.
fn prepare_span_edits(
  name : String,
  bytes : BytesView,
  edits : Array[SpanEdit],
  limits : SpliceLimits?,
) -> PreparedPartSplice raise @core.DocxError {
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
  let mut result_length = bytes.length().to_int64()
  let mut replacement_bytes = 0L
  let mut markup_tokens = 0L
  let mut cursor = 0
  for edit in sorted {
    result_length = checked_splice_size_add(
      result_length - (edit.end - edit.start).to_int64(),
      edit.replacement.length().to_int64(),
      "edited part",
    )
    replacement_bytes = checked_splice_size_add(
      replacement_bytes,
      edit.replacement.length().to_int64(),
      "replacement aggregate",
    )
    markup_tokens = checked_splice_size_add(
      checked_splice_size_add(
        markup_tokens,
        xml_markup_tokens(bytes[cursor:edit.start]),
        "XML token",
      ),
      xml_markup_tokens(edit.replacement),
      "XML token",
    )
    cursor = edit.end
  }
  markup_tokens = checked_splice_size_add(
    markup_tokens,
    xml_markup_tokens(bytes[cursor:]),
    "XML token",
  )
  if result_length > 2147483647L {
    raise Unsupported(
      message="splicing '\{name}' exceeds the maximum addressable part size",
    )
  }
  match limits {
    Some(value) => {
      if result_length > value.max_entry_uncompressed_bytes.to_int64() {
        raise Unsupported(
          message="the splice entry uncompressed limit is \{value.max_entry_uncompressed_bytes} bytes, but edited part '\{name}' requires \{result_length}",
        )
      }
      if markup_tokens > value.max_xml_tokens.to_int64() {
        raise Unsupported(
          message="the splice XML token limit is \{value.max_xml_tokens}, but edited part '\{name}' requires \{markup_tokens}",
        )
      }
    }
    None => ()
  }
  {
    name,
    source: bytes,
    edits: sorted,
    result_length: result_length.to_int(),
    replacement_bytes,
  }
}

///|
fn apply_prepared_span_edits(
  prepared : PreparedPartSplice,
) -> Bytes raise @core.DocxError {
  // Build a view-only segment table, then let Bytes::makei allocate and fill
  // exactly one immutable result buffer. This avoids Buffer growth/copy peaks
  // after the exact materialization preflight.
  let segments : Array[BytesView] = []
  let mut source_at = 0
  for edit in prepared.edits {
    let source_segment = prepared.source[source_at:edit.start]
    if !source_segment.is_empty() {
      segments.push(source_segment)
    }
    if !edit.replacement.is_empty() {
      segments.push(edit.replacement)
    }
    source_at = edit.end
  }
  let tail = prepared.source[source_at:]
  if !tail.is_empty() {
    segments.push(tail)
  }
  let mut segment_total = 0L
  for segment in segments {
    segment_total = checked_splice_size_add(
      segment_total,
      segment.length().to_int64(),
      "materialization segment",
    )
  }
  if segment_total != prepared.result_length.to_int64() {
    raise Unsupported(
      message="the splice size preflight disagreed with materialization",
    )
  }
  let segment_index = Ref(0)
  let segment_start = Ref(0)
  let result = Bytes::makei(prepared.result_length, output_index => {
    while segment_index.val < segments.length() &&
          output_index - segment_start.val >=
          segments[segment_index.val].length() {
      segment_start.val = segment_start.val +
        segments[segment_index.val].length()
      segment_index.val = segment_index.val + 1
    }
    if segment_index.val >= segments.length() {
      b'\x00'
    } else {
      segments[segment_index.val][output_index - segment_start.val]
    }
  })
  // Well-formedness belt: a spliced part must still parse as strict, DTD-free
  // XML. This cannot vouch for schema validity or namespace WISDOM of a
  // fragment (that is the fragment author's contract, gated by the dual
  // validators downstream) — it catches structural breakage at the
  // exact part.
  let text = @utf8.decode(result, ignore_bom=true) catch {
    _ =>
      raise Unsupported(
        message="splicing '\{prepared.name}' produced bytes that are not valid UTF-8",
      )
  }
  let _ = @xml.read_xml_string_strict(text) catch {
    err =>
      raise Unsupported(
        message="splicing '\{prepared.name}' produced malformed XML (\{to_repr(err)}); refusing to emit",
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
  bytes : BytesView,
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
fn declared_encoding(bytes : BytesView) -> EncodingDeclaration {
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
