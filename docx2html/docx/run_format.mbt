// F0 — the lexical `w:rPr` engine and direct-property oracle for
// span-addressed formatting.
//
// Everything here operates on ONE run's raw byte slice, purely
// lexically: existing spellings are preserved byte-for-byte, edits are
// the smallest spans that state the requested absolute values, absent
// children are inserted at their CT_RPr schema positions without
// moving anything, and every ambiguity — duplicate `rPr`, duplicate
// targeted properties, an in-flight `rPrChange`, out-of-order ranked
// children, a namespace binding this walker cannot vouch for — is a
// typed refusal, never a normalization.

///|
/// The v1 absolute-set request: None = untouched, Some(false) = an
/// EXPLICIT off override (never "clear to inherited" — that waits for
/// effective-value provenance). Color is a canonical six-digit
/// uppercase RGB value; bold and italic couple their complex-script
/// twins (`w:bCs`/`w:iCs`) as an office.mbt guarantee. Fields are
/// private: the ONLY constructor is `docx_direct_format`, so an
/// unvalidated color can never reach a planner.
pub struct DocxDirectFormat {
  priv bold : Bool?
  priv italic : Bool?
  priv underline : Bool?
  priv color : String?
} derive(Debug, Eq)

///|
pub fn DocxDirectFormat::bold(self : DocxDirectFormat) -> Bool? {
  self.bold
}

///|
pub fn DocxDirectFormat::italic(self : DocxDirectFormat) -> Bool? {
  self.italic
}

///|
pub fn DocxDirectFormat::underline(self : DocxDirectFormat) -> Bool? {
  self.underline
}

///|
pub fn DocxDirectFormat::color(self : DocxDirectFormat) -> String? {
  self.color
}

///|
/// Validate and canonicalize a direct-format request. Color accepts
/// `RRGGBB` or `#RRGGBB` (either case) and canonicalizes to uppercase.
/// A request that touches nothing is refused — a formatting command
/// must state at least one property.
pub fn docx_direct_format(
  bold? : Bool,
  italic? : Bool,
  underline? : Bool,
  color? : String,
) -> DocxDirectFormat raise DocxError {
  let canonical_color : String? = match color {
    Some(raw) => {
      let hex = if raw.has_prefix("#") {
        raw.substring(start=1, end=raw.length()).to_string()
      } else {
        raw
      }
      guard hex.length() == 6 else {
        raise Unsupported(
          message="format color is a six-digit RGB value (RRGGBB or #RRGGBB)",
        )
      }
      let units = hex.code_units()
      let builder = StringBuilder(size_hint=6)
      for index in 0..<6 {
        let code = units[index].to_int()
        let upper = if code >= 'a'.to_int() && code <= 'f'.to_int() {
          code - 32
        } else {
          code
        }
        let is_hex = (upper >= '0'.to_int() && upper <= '9'.to_int()) ||
          (upper >= 'A'.to_int() && upper <= 'F'.to_int())
        guard is_hex else {
          raise Unsupported(
            message="format color is a six-digit RGB value (RRGGBB or #RRGGBB)",
          )
        }
        builder.write_char(upper.unsafe_to_char())
      }
      Some(builder.to_string())
    }
    None => None
  }
  guard bold is Some(_) ||
    italic is Some(_) ||
    underline is Some(_) ||
    canonical_color is Some(_) else {
    raise Unsupported(
      message="a format request states at least one property (bold, italic, underline, color)",
    )
  }
  { bold, italic, underline, color: canonical_color, }
}

///|
/// One slice-relative byte edit: replace [start, end) with the
/// replacement text (encoded as UTF-8 by the consumer).
pub struct RunFormatEdit {
  priv start : Int
  priv end : Int
  priv replacement : String
}

///|
pub fn RunFormatEdit::start(self : RunFormatEdit) -> Int {
  self.start
}

///|
pub fn RunFormatEdit::end(self : RunFormatEdit) -> Int {
  self.end
}

///|
pub fn RunFormatEdit::replacement(self : RunFormatEdit) -> String {
  self.replacement
}

///|
/// The planned edits for one run: slice-relative, non-overlapping, in
/// ascending order (stable — equal-offset insertions keep their
/// schema-rank order). `changed=false` means every requested property
/// already holds explicitly — nothing is rewritten.
pub struct RunFormatPlan {
  priv edits : Array[RunFormatEdit]
  priv changed : Bool
}

///|
pub fn RunFormatPlan::edits(self : RunFormatPlan) -> Array[RunFormatEdit] {
  self.edits
}

///|
pub fn RunFormatPlan::changed(self : RunFormatPlan) -> Bool {
  self.changed
}

// ---------------------------------------------------------------------------
// Names under a caller-vouched binding
// ---------------------------------------------------------------------------

///|
/// The qualified spelling of a WML name under the document's binding:
/// `prefix=""` is the default-namespace document (`<r>`, `<rPr>`), any
/// other prefix spells `prefix:local`. ATTRIBUTES in the WML namespace
/// are prefixed in prefixed documents and UNPREFIXED (no namespace,
/// per XML rules — Word writes them so) in default-namespace ones.
fn wml_name(prefix : String, local : String) -> String {
  if prefix == "" {
    local
  } else {
    "\{prefix}:\{local}"
  }
}

// ---------------------------------------------------------------------------
// Lexical scanning
// ---------------------------------------------------------------------------

///|
priv struct FormatAttribute {
  // as spelled, whitespace-trimmed
  name : String
  value : String
  // the FULL attribute span: first byte of the name through the
  // closing quote (inclusive end is exclusive here)
  name_start : Int
  attr_end : Int
  value_start : Int
  value_end : Int
}

///|
priv struct RunChildTag {
  name : String
  byte_start : Int
  byte_end : Int
  self_closing : Bool
  open_end : Int
  attributes : Array[FormatAttribute]
  // Direct element children found inside (non-leaf detection).
  has_element_children : Bool
}

///|
/// Scan one element's DIRECT children lexically. Children with
/// subtrees are consumed whole with close-NAME matching; only XML
/// whitespace may appear between children; comments, PIs, CDATA, and
/// any xmlns declaration in the region are refusals — a binding this
/// walker cannot vouch for must not be edited around.
fn scan_direct_children(
  bytes : BytesView,
  content_start : Int,
  content_end : Int,
) -> Array[RunChildTag] raise DocxError {
  let children : Array[RunChildTag] = []
  let mut at = content_start
  while at < content_end {
    let byte = bytes[at]
    if byte == b' ' || byte == b'\t' || byte == b'\n' || byte == b'\r' {
      at += 1
      continue
    }
    guard byte == b'<' else {
      raise Unsupported(
        message="run formatting refuses non-whitespace character data between properties",
      )
    }
    guard at + 1 < content_end else {
      raise Unsupported(message="run formatting found a truncated tag")
    }
    if bytes[at + 1] == b'!' || bytes[at + 1] == b'?' {
      raise Unsupported(
        message="run formatting does not edit regions containing comments, processing instructions, or CDATA",
      )
    }
    guard bytes[at + 1] != b'/' else {
      raise Unsupported(message="run formatting found an unmatched close tag")
    }
    let (name, attributes, self_closing, open_end) = scan_format_tag(
      bytes, at, content_end,
    )
    let mut byte_end = open_end
    let mut has_element_children = false
    if !self_closing {
      let close_at = consume_subtree(bytes, name, open_end, content_end)
      // Anything other than pure whitespace between the open tag and
      // the close tag means element or text content.
      let mut probe = open_end
      while probe < close_at.0 {
        let inner = bytes[probe]
        if inner == b'<' {
          has_element_children = true
          break
        }
        if inner != b' ' && inner != b'\t' && inner != b'\n' && inner != b'\r' {
          has_element_children = true
          break
        }
        probe += 1
      }
      byte_end = close_at.1
    }
    children.push({
      name,
      byte_start: at,
      byte_end,
      self_closing,
      open_end,
      attributes,
      has_element_children,
    })
    at = byte_end
  }
  children
}

///|
/// Consume a subtree opened by `name` starting just past its open tag;
/// returns (close_tag_start, one-past-close-'>'). Close tags must
/// MATCH their open names — a mismatched pair is a refusal, never a
/// guess.
fn consume_subtree(
  bytes : BytesView,
  name : String,
  open_end : Int,
  limit : Int,
) -> (Int, Int) raise DocxError {
  let stack : Array[String] = [name]
  let mut at = open_end
  while at < limit && stack.length() > 0 {
    if bytes[at] != b'<' {
      at += 1
      continue
    }
    guard at + 1 < limit else {
      raise Unsupported(message="run formatting found a truncated tag")
    }
    if bytes[at + 1] == b'!' || bytes[at + 1] == b'?' {
      raise Unsupported(
        message="run formatting does not edit regions containing comments, processing instructions, or CDATA",
      )
    }
    if bytes[at + 1] == b'/' {
      let close_start = at
      let name_start = at + 2
      let mut cursor = name_start
      while cursor < limit && bytes[cursor] != b'>' {
        cursor += 1
      }
      guard cursor < limit else {
        raise Unsupported(message="run formatting found a truncated close tag")
      }
      let close_name = ascii_slice(bytes, name_start, cursor)
        .trim(chars=" \t\n\r")
        .to_string()
      guard stack.length() > 0 && stack[stack.length() - 1] == close_name else {
        raise Unsupported(
          message="run formatting found a close tag that does not match its element",
        )
      }
      ignore(stack.pop())
      at = cursor + 1
      if stack.length() == 0 {
        return (close_start, at)
      }
    } else {
      let (inner_name, _, inner_self_closing, inner_open_end) = scan_format_tag(
        bytes, at, limit,
      )
      if !inner_self_closing {
        stack.push(inner_name)
      }
      at = inner_open_end
    }
  }
  raise Unsupported(message="run formatting found an unclosed element")
}

///|
/// Scan one open tag: (qname, attributes with FULL spans, self_closing,
/// one-past-'>'). Whitespace around `=` is valid XML and accepted; an
/// xmlns declaration anywhere in the tag is a refusal (a local
/// rebinding would silently change what every name in this slice
/// means).
fn scan_format_tag(
  bytes : BytesView,
  start : Int,
  limit : Int,
) -> (String, Array[FormatAttribute], Bool, Int) raise DocxError {
  let mut at = start + 1
  let name_start = at
  while at < limit &&
        bytes[at] != b' ' &&
        bytes[at] != b'>' &&
        bytes[at] != b'/' &&
        bytes[at] != b'\t' &&
        bytes[at] != b'\n' &&
        bytes[at] != b'\r' {
    guard bytes[at] < b'\x80' else {
      raise Unsupported(
        message="run formatting requires ASCII element names at the edit site",
      )
    }
    at += 1
  }
  let name = ascii_slice(bytes, name_start, at)
  let attributes : Array[FormatAttribute] = []
  let mut self_closing = false
  while at < limit {
    while at < limit &&
          (
            bytes[at] == b' ' ||
            bytes[at] == b'\t' ||
            bytes[at] == b'\n' ||
            bytes[at] == b'\r'
          ) {
      at += 1
    }
    guard at < limit else {
      raise Unsupported(message="run formatting found a truncated tag")
    }
    if bytes[at] == b'>' {
      at += 1
      break
    }
    if bytes[at] == b'/' {
      guard at + 1 < limit && bytes[at + 1] == b'>' else {
        raise Unsupported(message="run formatting found a malformed tag")
      }
      self_closing = true
      at += 2
      break
    }
    // Attribute: name [ws] = [ws] quoted-value. The FULL span from the
    // name's first byte through the closing quote is recorded so a
    // whole-attribute removal never leaves a dangling name.
    let attr_name_start = at
    while at < limit &&
          bytes[at] != b'=' &&
          bytes[at] != b' ' &&
          bytes[at] != b'\t' &&
          bytes[at] != b'\n' &&
          bytes[at] != b'\r' {
      guard bytes[at] < b'\x80' else {
        raise Unsupported(
          message="run formatting requires ASCII attribute names at the edit site",
        )
      }
      guard bytes[at] != b'>' && bytes[at] != b'/' else {
        raise Unsupported(
          message="run formatting found an attribute without a value",
        )
      }
      at += 1
    }
    let attr_name = ascii_slice(bytes, attr_name_start, at)
    while at < limit &&
          (
            bytes[at] == b' ' ||
            bytes[at] == b'\t' ||
            bytes[at] == b'\n' ||
            bytes[at] == b'\r'
          ) {
      at += 1
    }
    guard at < limit && bytes[at] == b'=' else {
      raise Unsupported(
        message="run formatting found an attribute without a value",
      )
    }
    at += 1
    while at < limit &&
          (
            bytes[at] == b' ' ||
            bytes[at] == b'\t' ||
            bytes[at] == b'\n' ||
            bytes[at] == b'\r'
          ) {
      at += 1
    }
    guard at < limit && (bytes[at] == b'"' || bytes[at] == b'\'') else {
      raise Unsupported(
        message="run formatting found an unquoted attribute value",
      )
    }
    let quote = bytes[at]
    at += 1
    let value_start = at
    while at < limit && bytes[at] != quote {
      at += 1
    }
    guard at < limit else {
      raise Unsupported(
        message="run formatting found an unterminated attribute",
      )
    }
    if attr_name == "xmlns" || attr_name.has_prefix("xmlns:") {
      raise Unsupported(
        message="run formatting refuses a local namespace declaration at the edit site",
      )
    }
    attributes.push({
      name: attr_name,
      value: ascii_lossy_slice(bytes, value_start, at),
      name_start: attr_name_start,
      attr_end: at + 1,
      value_start,
      value_end: at,
    })
    at += 1
  }
  (name, attributes, self_closing, at)
}

///|
fn ascii_slice(
  bytes : BytesView,
  start : Int,
  end : Int,
) -> String raise DocxError {
  let builder = StringBuilder()
  for index in start..<end {
    guard bytes[index] < b'\x80' else {
      raise Unsupported(
        message="run formatting requires ASCII names at the edit site",
      )
    }
    builder.write_char(bytes[index].to_int().unsafe_to_char())
  }
  builder.to_string()
}

///|
/// Attribute VALUES may carry non-ASCII; the comparisons this engine
/// makes are against ASCII vocabularies, so non-ASCII values simply
/// never match (and are preserved untouched).
fn ascii_lossy_slice(bytes : BytesView, start : Int, end : Int) -> String {
  let builder = StringBuilder()
  for index in start..<end {
    if bytes[index] < b'\x80' {
      builder.write_char(bytes[index].to_int().unsafe_to_char())
    } else {
      builder.write_char('\u{FFFD}')
    }
  }
  builder.to_string()
}

// ---------------------------------------------------------------------------
// CT_RPr schema order
// ---------------------------------------------------------------------------

///|
/// The ECMA-376 CT_RPr child order, by LOCAL name.
fn rpr_rank(local : String) -> Int? {
  let order = [
    "rStyle", "rFonts", "b", "bCs", "i", "iCs", "caps", "smallCaps", "strike", "dstrike",
    "outline", "shadow", "emboss", "imprint", "noProof", "snapToGrid", "vanish",
    "webHidden", "color", "spacing", "w", "kern", "position", "sz", "szCs", "highlight",
    "u", "effect", "bdr", "shd", "fitText", "vertAlign", "rtl", "cs", "em", "lang",
    "eastAsianLayout", "specVanish", "oMath",
  ]
  for index, name in order {
    if name == local {
      return Some(index)
    }
  }
  None
}

///|
/// The boolean on/off vocabulary of ST_OnOff.
fn on_off_value(children_value : String?) -> Bool? {
  match children_value {
    None => Some(true)
    Some("1") | Some("true") | Some("on") => Some(true)
    Some("0") | Some("false") | Some("off") => Some(false)
    Some(_) => None
  }
}

// ---------------------------------------------------------------------------
// Planning
// ---------------------------------------------------------------------------

///|
priv struct PendingEdit {
  start : Int
  end : Int
  replacement : String
  // schema rank for stable equal-offset ordering
  order : Int
}

///|
/// Plan the minimal edits that make `format` hold explicitly on one
/// run, given the run's complete byte slice and the document's WML
/// binding (`prefix=""` for a default-namespace document).
pub fn plan_run_format(
  run_slice : BytesView,
  prefix~ : String,
  format~ : DocxDirectFormat,
) -> RunFormatPlan raise DocxError {
  guard run_slice.length() > 0 && run_slice[0] == b'<' else {
    raise Unsupported(message="run formatting requires the run's element slice")
  }
  let run_qname = wml_name(prefix, "r")
  let (run_name, _, run_self_closing, run_open_end) = scan_format_tag(
    run_slice,
    0,
    run_slice.length(),
  )
  guard run_name == run_qname else {
    raise Unsupported(
      message="run formatting expected a <\{run_qname}> element at the slice head",
    )
  }
  if run_self_closing {
    guard run_open_end == run_slice.length() else {
      raise Unsupported(
        message="run formatting requires the slice to end at the run",
      )
    }
    // Expand only the closing "/>" — the open tag's own attributes and
    // spacing are preserved untouched.
    let rendered = render_rpr_children(prefix, format)
    let insert_at = run_slice.length() - 2
    guard run_slice[insert_at] == b'/' && run_slice[insert_at + 1] == b'>' else {
      raise Unsupported(
        message="run formatting found a malformed self-closing run",
      )
    }
    let rpr_qname = wml_name(prefix, "rPr")
    return {
      edits: [
        {
          start: insert_at,
          end: run_slice.length(),
          replacement: "><\{rpr_qname}>" +
          rendered +
          "</\{rpr_qname}></\{run_qname}>",
        },
      ],
      changed: true,
    }
  }
  // The slice must end with this run's own close tag — checked, not
  // assumed, because this is a public planner.
  let close = "</\{run_qname}>"
  let close_length = close.length()
  guard run_slice.length() >= run_open_end + close_length else {
    raise Unsupported(message="run formatting found a truncated run")
  }
  let content_end = run_slice.length() - close_length
  let close_units = close.code_units()
  for index in 0..<close_length {
    guard run_slice[content_end + index].to_int() == close_units[index].to_int() else {
      raise Unsupported(
        message="run formatting requires the slice to end at the run's close tag",
      )
    }
  }
  let children = scan_direct_children(run_slice, run_open_end, content_end)
  let rpr_qname = wml_name(prefix, "rPr")
  let mut rpr : RunChildTag? = None
  for index, child in children {
    if child.name == rpr_qname {
      guard rpr is None else {
        raise Unsupported(
          message="run formatting refuses a run with duplicate rPr elements",
        )
      }
      // CT_R: rPr, when present, is the FIRST child.
      guard index == 0 else {
        raise Unsupported(
          message="run formatting refuses a run whose rPr is not its first element",
        )
      }
      rpr = Some(child)
    }
  }
  match rpr {
    None => {
      let rendered = render_rpr_children(prefix, format)
      {
        edits: [
          {
            start: run_open_end,
            end: run_open_end,
            replacement: "<\{rpr_qname}>" + rendered + "</\{rpr_qname}>",
          },
        ],
        changed: true,
      }
    }
    Some(container) => plan_within_rpr(run_slice, prefix, format, container)
  }
}

///|
fn plan_within_rpr(
  run_slice : BytesView,
  prefix : String,
  format : DocxDirectFormat,
  container : RunChildTag,
) -> RunFormatPlan raise DocxError {
  let rpr_qname = wml_name(prefix, "rPr")
  if container.self_closing {
    // Expand only the closing "/>": the open tag with every attribute
    // and spacing survives byte-for-byte.
    let rendered = render_rpr_children(prefix, format)
    let slash_at = container.open_end - 2
    guard run_slice[slash_at] == b'/' && run_slice[slash_at + 1] == b'>' else {
      raise Unsupported(
        message="run formatting found a malformed self-closing rPr",
      )
    }
    return {
      edits: [
        {
          start: slash_at,
          end: container.open_end,
          replacement: ">" + rendered + "</\{rpr_qname}>",
        },
      ],
      changed: true,
    }
  }
  let close = "</\{rpr_qname}>"
  let interior_end = container.byte_end - close.length()
  let children = scan_direct_children(
    run_slice,
    container.open_end,
    interior_end,
  )
  // One classification pass: targeted properties recorded (duplicates
  // refused), ranked children checked for monotonic schema order,
  // unranked children legal ONLY as a trailing extension block.
  let mut seen_b : RunChildTag? = None
  let mut seen_bcs : RunChildTag? = None
  let mut seen_i : RunChildTag? = None
  let mut seen_ics : RunChildTag? = None
  let mut seen_u : RunChildTag? = None
  let mut seen_color : RunChildTag? = None
  let mut last_rank = -1
  let mut extension_block_start : Int? = None
  for child in children {
    if child.name == wml_name(prefix, "rPrChange") {
      raise Unsupported(
        message="run formatting refuses a run with an in-flight tracked property change (rPrChange)",
      )
    }
    let local = if prefix == "" {
      child.name
    } else if child.name.has_prefix("\{prefix}:") {
      child.name
      .substring(start=prefix.length() + 1, end=child.name.length())
      .to_string()
    } else {
      // Foreign prefix: only legal inside the trailing extension block.
      match extension_block_start {
        None => extension_block_start = Some(child.byte_start)
        Some(_) => ()
      }
      continue
    }
    match rpr_rank(local) {
      Some(rank) => {
        guard extension_block_start is None else {
          raise Unsupported(
            message="run formatting refuses a ranked property after the trailing extension block",
          )
        }
        guard rank >= last_rank else {
          raise Unsupported(
            message="run formatting refuses an rPr whose children are out of schema order",
          )
        }
        last_rank = rank
      }
      None =>
        match extension_block_start {
          None => extension_block_start = Some(child.byte_start)
          Some(_) => ()
        }
    }
    fn record(
      slot : RunChildTag?,
      tag : RunChildTag,
    ) -> RunChildTag? raise DocxError {
      guard slot is None else {
        raise Unsupported(
          message="run formatting refuses duplicate \{tag.name} properties",
        )
      }
      // A targeted property with element content is not the leaf this
      // engine understands.
      guard !tag.has_element_children else {
        raise Unsupported(
          message="run formatting refuses a non-leaf \{tag.name} property",
        )
      }
      Some(tag)
    }
    if local == "b" {
      seen_b = record(seen_b, child)
    } else if local == "bCs" {
      seen_bcs = record(seen_bcs, child)
    } else if local == "i" {
      seen_i = record(seen_i, child)
    } else if local == "iCs" {
      seen_ics = record(seen_ics, child)
    } else if local == "u" {
      seen_u = record(seen_u, child)
    } else if local == "color" {
      seen_color = record(seen_color, child)
    }
  }
  // The unique legal insertion boundary for NEW children is before the
  // trailing extension block (or the interior end).
  let insertion_limit = extension_block_start.unwrap_or(interior_end)
  let pending : Array[PendingEdit] = []
  match format.bold {
    Some(value) => {
      plan_on_off(
        prefix, "b", value, seen_b, children, container, insertion_limit, pending,
      )
      plan_on_off(
        prefix, "bCs", value, seen_bcs, children, container, insertion_limit, pending,
      )
    }
    None => ()
  }
  match format.italic {
    Some(value) => {
      plan_on_off(
        prefix, "i", value, seen_i, children, container, insertion_limit, pending,
      )
      plan_on_off(
        prefix, "iCs", value, seen_ics, children, container, insertion_limit, pending,
      )
    }
    None => ()
  }
  match format.underline {
    Some(value) =>
      plan_underline(
        prefix, value, seen_u, children, container, insertion_limit, pending,
      )
    None => ()
  }
  match format.color {
    Some(value) =>
      plan_color(
        run_slice, prefix, value, seen_color, children, container, insertion_limit,
        pending,
      )
    None => ()
  }
  // Stable order: ascending start; equal offsets keep schema-rank
  // order (the tie-break that an unstable sort would lose).
  pending.sort_by((left, right) => {
    if left.start != right.start {
      left.start - right.start
    } else {
      left.order - right.order
    }
  })
  let edits : Array[RunFormatEdit] = []
  for entry in pending {
    edits.push({
      start: entry.start,
      end: entry.end,
      replacement: entry.replacement,
    })
  }
  { edits, changed: edits.length() > 0, }
}

///|
/// The insertion offset for a new `local` child: after the last ranked
/// child of lower-or-equal rank, never past the trailing extension
/// block. Ranked children are already proven monotonic, so this point
/// is unique and legal by construction.
fn rpr_insertion_offset(
  prefix : String,
  local : String,
  children : Array[RunChildTag],
  container : RunChildTag,
  insertion_limit : Int,
) -> (Int, Int) raise DocxError {
  guard rpr_rank(local) is Some(rank) else {
    raise Unsupported(message="run formatting has no rank for \{local}")
  }
  let mut offset = container.open_end
  for child in children {
    if child.byte_start >= insertion_limit {
      break
    }
    let child_local = if prefix == "" {
      child.name
    } else if child.name.has_prefix("\{prefix}:") {
      child.name
      .substring(start=prefix.length() + 1, end=child.name.length())
      .to_string()
    } else {
      break
    }
    match rpr_rank(child_local) {
      Some(child_rank) => if child_rank < rank { offset = child.byte_end }
      None => break
    }
  }
  (offset, rank)
}

///|
/// The attribute name a WML-namespaced attribute carries in this
/// document: prefixed documents spell `w:val`; default-namespace
/// documents spell it `val` (attributes take no default namespace).
fn wml_attr(prefix : String, local : String) -> String {
  if prefix == "" {
    local
  } else {
    "\{prefix}:\{local}"
  }
}

///|
fn find_val(
  prefix : String,
  tag : RunChildTag,
) -> FormatAttribute? raise DocxError {
  let val_name = wml_attr(prefix, "val")
  let mut found : FormatAttribute? = None
  for attribute in tag.attributes {
    if attribute.name == val_name {
      guard found is None else {
        raise Unsupported(
          message="run formatting refuses duplicate val attributes on \{tag.name}",
        )
      }
      found = Some(attribute)
    }
  }
  found
}

///|
fn plan_on_off(
  prefix : String,
  local : String,
  requested : Bool,
  existing : RunChildTag?,
  children : Array[RunChildTag],
  container : RunChildTag,
  insertion_limit : Int,
  pending : Array[PendingEdit],
) -> Unit raise DocxError {
  match existing {
    Some(tag) => {
      let val = find_val(prefix, tag)
      match on_off_value(val.map(entry => entry.value)) {
        Some(current) =>
          if current != requested {
            match val {
              Some(attribute) =>
                pending.push({
                  start: attribute.value_start,
                  end: attribute.value_end,
                  replacement: if requested {
                    "1"
                  } else {
                    "0"
                  },
                  order: 0,
                })
              None => {
                let insert_at = if tag.self_closing {
                  tag.open_end - 2
                } else {
                  tag.open_end - 1
                }
                pending.push({
                  start: insert_at,
                  end: insert_at,
                  replacement: " \{wml_attr(prefix, "val")}=\"0\"",
                  order: 0,
                })
              }
            }
          }
        None =>
          raise Unsupported(
            message="run formatting found an unrecognized on/off value on \{tag.name}",
          )
      }
    }
    None => {
      let (offset, rank) = rpr_insertion_offset(
        prefix, local, children, container, insertion_limit,
      )
      let qname = wml_name(prefix, local)
      let rendered = if requested {
        "<\{qname}/>"
      } else {
        "<\{qname} \{wml_attr(prefix, "val")}=\"0\"/>"
      }
      pending.push({
        start: offset,
        end: offset,
        replacement: rendered,
        order: rank,
      })
    }
  }
}

///|
fn plan_underline(
  prefix : String,
  requested : Bool,
  existing : RunChildTag?,
  children : Array[RunChildTag],
  container : RunChildTag,
  insertion_limit : Int,
  pending : Array[PendingEdit],
) -> Unit raise DocxError {
  let wanted = if requested { "single" } else { "none" }
  match existing {
    Some(tag) =>
      match find_val(prefix, tag) {
        Some(attribute) =>
          if attribute.value != wanted {
            pending.push({
              start: attribute.value_start,
              end: attribute.value_end,
              replacement: wanted,
              order: 0,
            })
          }
        None =>
          raise Unsupported(
            message="run formatting found an underline without a val attribute",
          )
      }
    None => {
      let (offset, rank) = rpr_insertion_offset(
        prefix, "u", children, container, insertion_limit,
      )
      pending.push({
        start: offset,
        end: offset,
        replacement: "<\{wml_name(prefix, "u")} \{wml_attr(prefix, "val")}=\"\{wanted}\"/>",
        order: rank,
      })
    }
  }
}

///|
/// Case-insensitive RGB equality: `ff0000` IS the requested `FF0000`,
/// and a semantic no-op must not rewrite the existing spelling.
fn rgb_equal(existing : String, requested : String) -> Bool {
  if existing.length() != 6 {
    return false
  }
  let left = existing.code_units()
  let right = requested.code_units()
  for index in 0..<6 {
    let mut a = left[index].to_int()
    let b = right[index].to_int()
    if a >= 'a'.to_int() && a <= 'f'.to_int() {
      a -= 32
    }
    if a != b {
      return false
    }
  }
  true
}

///|
fn plan_color(
  run_slice : BytesView,
  prefix : String,
  requested : String,
  existing : RunChildTag?,
  children : Array[RunChildTag],
  container : RunChildTag,
  insertion_limit : Int,
  pending : Array[PendingEdit],
) -> Unit raise DocxError {
  match existing {
    Some(tag) => {
      let val = find_val(prefix, tag)
      let theme_names = [
        wml_attr(prefix, "themeColor"),
        wml_attr(prefix, "themeTint"),
        wml_attr(prefix, "themeShade"),
      ]
      for attribute in tag.attributes {
        if theme_names.contains(attribute.name) {
          // The removal span covers the whitespace BEFORE the name
          // through the closing quote — spans come from the scanner,
          // never reconstructed.
          let mut span_start = attribute.name_start
          while span_start > 0 &&
                (
                  run_slice[span_start - 1] == b' ' ||
                  run_slice[span_start - 1] == b'\t' ||
                  run_slice[span_start - 1] == b'\n' ||
                  run_slice[span_start - 1] == b'\r'
                ) {
            span_start -= 1
          }
          pending.push({
            start: span_start,
            end: attribute.attr_end,
            replacement: "",
            order: 0,
          })
        }
      }
      match val {
        Some(attribute) =>
          if !rgb_equal(attribute.value, requested) {
            pending.push({
              start: attribute.value_start,
              end: attribute.value_end,
              replacement: requested,
              order: 0,
            })
          }
        None =>
          raise Unsupported(
            message="run formatting found a color without a val attribute",
          )
      }
    }
    None => {
      let (offset, rank) = rpr_insertion_offset(
        prefix, "color", children, container, insertion_limit,
      )
      pending.push({
        start: offset,
        end: offset,
        replacement: "<\{wml_name(prefix, "color")} \{wml_attr(prefix, "val")}=\"\{requested}\"/>",
        order: rank,
      })
    }
  }
}

///|
/// Render the CHILDREN of a fresh `rPr` in schema order.
fn render_rpr_children(prefix : String, format : DocxDirectFormat) -> String {
  let builder = StringBuilder()
  let val = wml_attr(prefix, "val")
  match format.bold {
    Some(true) =>
      builder.write_string(
        "<\{wml_name(prefix, "b")}/><\{wml_name(prefix, "bCs")}/>",
      )
    Some(false) =>
      builder.write_string(
        "<\{wml_name(prefix, "b")} \{val}=\"0\"/><\{wml_name(prefix, "bCs")} \{val}=\"0\"/>",
      )
    None => ()
  }
  match format.italic {
    Some(true) =>
      builder.write_string(
        "<\{wml_name(prefix, "i")}/><\{wml_name(prefix, "iCs")}/>",
      )
    Some(false) =>
      builder.write_string(
        "<\{wml_name(prefix, "i")} \{val}=\"0\"/><\{wml_name(prefix, "iCs")} \{val}=\"0\"/>",
      )
    None => ()
  }
  match format.color {
    Some(value) =>
      builder.write_string(
        "<\{wml_name(prefix, "color")} \{val}=\"\{value}\"/>",
      )
    None => ()
  }
  match format.underline {
    Some(value) => {
      let wanted = if value { "single" } else { "none" }
      builder.write_string("<\{wml_name(prefix, "u")} \{val}=\"\{wanted}\"/>")
    }
    None => ()
  }
  builder.to_string()
}

// ---------------------------------------------------------------------------
// The direct-property oracle
// ---------------------------------------------------------------------------

///|
/// Verify that every requested property holds EXPLICITLY on the run
/// slice — the readback's judgment, sharing the planner's lexical
/// reading so the two can never disagree about a spelling. Returns
/// None when satisfied, or the first discrepancy's description.
pub fn verify_run_format(
  run_slice : BytesView,
  prefix~ : String,
  format~ : DocxDirectFormat,
) -> String? raise DocxError {
  let plan = plan_run_format(run_slice, prefix~, format~)
  if plan.changed {
    Some("the run does not carry every requested property explicitly")
  } else {
    None
  }
}
