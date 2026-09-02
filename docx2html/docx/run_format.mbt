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
/// The requested bold state: `Some(true)`/`Some(false)` forces it,
/// `None` leaves it untouched.
pub fn DocxDirectFormat::bold(self : DocxDirectFormat) -> Bool? {
  self.bold
}

///|
/// The requested italic state: `Some(true)`/`Some(false)` forces it,
/// `None` leaves it untouched.
pub fn DocxDirectFormat::italic(self : DocxDirectFormat) -> Bool? {
  self.italic
}

///|
/// The requested underline state: `Some(true)`/`Some(false)` forces it,
/// `None` leaves it untouched.
pub fn DocxDirectFormat::underline(self : DocxDirectFormat) -> Bool? {
  self.underline
}

///|
/// The requested color as canonical uppercase `RRGGBB`, or `None` when
/// no color was requested.
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
        raw[1:].to_owned()
      } else {
        raw
      }
      guard hex.length() == 6 else {
        raise Unsupported(
          message="format color is a six-digit RGB value (RRGGBB or #RRGGBB)",
        )
      }
      let builder = StringBuilder(size_hint=6)
      for ch in hex {
        let upper = if ch is ('a'..='f') {
          (ch.to_int() - 32).unsafe_to_char()
        } else {
          ch
        }
        guard upper is ('0'..='9' | 'A'..='F') else {
          raise Unsupported(
            message="format color is a six-digit RGB value (RRGGBB or #RRGGBB)",
          )
        }
        builder.write_char(upper)
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
/// The byte offset where the edit's replacement begins (slice-relative).
pub fn RunFormatEdit::start(self : RunFormatEdit) -> Int {
  self.start
}

///|
/// The byte offset just past the text the edit replaces (slice-relative).
pub fn RunFormatEdit::end(self : RunFormatEdit) -> Int {
  self.end
}

///|
/// The replacement text (encoded as UTF-8 by the consumer).
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
/// A defensive copy — the plan's sorted/non-overlapping invariant
/// cannot be mutated away by a caller.
pub fn RunFormatPlan::edits(self : RunFormatPlan) -> Array[RunFormatEdit] {
  self.edits.copy()
}

///|
/// Whether the plan rewrites anything: `false` means every requested
/// property already holds explicitly.
pub fn RunFormatPlan::changed(self : RunFormatPlan) -> Bool {
  self.changed
}

// ---------------------------------------------------------------------------
// Names under a caller-vouched binding
// ---------------------------------------------------------------------------

///|
/// The caller-vouched namespace binding this lexical engine edits
/// under. XML default namespaces apply to ELEMENTS only, so `element`
/// may be "" (a default-namespace document spells `<r>`, `<rPr>`), but
/// an unprefixed attribute has NO namespace — WML's schema qualifies
/// its attributes, so `attribute` is never "". `extensions` lists the
/// prefixes the caller warrants are bound to recognized rPr extension
/// namespaces (w14 and friends) — and NOT to WML or to
/// markup-compatibility.
priv struct WmlBinding {
  element : String
  attribute : String
  extensions : Array[String]
}

///|
fn make_binding(
  prefix : String,
  attr_prefix : String?,
  extension_prefixes : Array[String]?,
) -> WmlBinding raise DocxError {
  if prefix != "" {
    validate_ns_prefix(prefix)
  }
  let attribute = attr_prefix.unwrap_or(prefix)
  guard attribute != "" else {
    raise Unsupported(
      message="run formatting requires an attribute prefix: XML default namespaces do not apply to attributes, so WML attributes are always qualified",
    )
  }
  validate_ns_prefix(attribute)
  // `xml` and `xmlns` are bound by the XML specs themselves — they can
  // never be the WML binding.
  guard prefix != "xmlns" &&
    prefix != "xml" &&
    attribute != "xmlns" &&
    attribute != "xml" else {
    raise Unsupported(
      message="run formatting refuses a reserved namespace prefix",
    )
  }
  let extensions = extension_prefixes.unwrap_or([])
  for entry in extensions {
    guard entry != "" &&
      entry != prefix &&
      entry != attribute &&
      entry != "mc" &&
      entry != "xml" &&
      entry != "xmlns" else {
      raise Unsupported(
        message="run formatting refuses the extension prefix \{entry}: extension prefixes must be distinct from the WML and reserved bindings",
      )
    }
    validate_ns_prefix(entry)
  }
  { element: prefix, attribute, extensions, }
}

///|
/// A namespace prefix must be an NCName — in this engine's ASCII
/// subset: a letter or underscore, then letters, digits, '_', '-',
/// '.'. NO colon: `x:y` as a "prefix" would spell malformed names
/// like `x:y:val`.
fn validate_ns_prefix(prefix : String) -> Unit raise DocxError {
  validate_ncname_part(prefix) catch {
    _ =>
      raise Unsupported(
        message="run formatting requires namespace prefixes to be NCNames",
      )
  }
}

///|
/// The qualified spelling of a WML ELEMENT under the binding:
/// `element=""` is the default-namespace document (`<r>`, `<rPr>`),
/// any other prefix spells `prefix:local`.
fn wml_name(binding : WmlBinding, local_name : String) -> String {
  if binding.element == "" {
    local_name
  } else {
    "\{binding.element}:\{local_name}"
  }
}

///|
/// Split a child's qname into (prefix, local) — prefix "" when the
/// name carries no colon.
fn split_qname(name : String) -> (String, String) {
  let units = name.code_units()
  for index in 0..<units.length() {
    if units[index].to_int() == ':'.to_int() {
      return (
        name[:index].to_owned(),
        name[index + 1:].to_owned(),
      )
    }
  }
  ("", name)
}

// ---------------------------------------------------------------------------
// Lexical scanning
// ---------------------------------------------------------------------------

///|
fn is_xml_ws(byte : Byte) -> Bool {
  byte is (b' ' | b'\t' | b'\n' | b'\r')
}

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
  // Where the close tag STARTS (equals byte_end for a self-closing
  // tag) — recorded, never reconstructed, because `</w:rPr >` is
  // legal XML and longer than the canonical spelling.
  close_start : Int
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
    if is_xml_ws(byte) {
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
    let mut close_start = open_end
    let mut has_element_children = false
    if !self_closing {
      let close_at = consume_subtree(bytes, name, open_end, content_end)
      // Anything other than pure whitespace between the open tag and
      // the close tag means element or text content.
      let mut probe = open_end
      while probe < close_at.0 {
        if !is_xml_ws(bytes[probe]) {
          has_element_children = true
          break
        }
        probe += 1
      }
      close_start = close_at.0
      byte_end = close_at.1
    }
    children.push({
      name,
      byte_start: at,
      byte_end,
      self_closing,
      open_end,
      close_start,
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
      // XML permits whitespace AFTER the end-tag name, never before it:
      // the name starts immediately at "</".
      let close_start = at
      let name_start = at + 2
      let mut cursor = name_start
      while cursor < limit && bytes[cursor] != b'>' && !is_xml_ws(bytes[cursor]) {
        cursor += 1
      }
      let close_name = ascii_slice(bytes, name_start, cursor)
      validate_xml_name(close_name)
      let mut probe = cursor
      while probe < limit && is_xml_ws(bytes[probe]) {
        probe += 1
      }
      guard probe < limit && bytes[probe] == b'>' else {
        raise Unsupported(message="run formatting found a malformed close tag")
      }
      guard stack.length() > 0 && stack[stack.length() - 1] == close_name else {
        raise Unsupported(
          message="run formatting found a close tag that does not match its element",
        )
      }
      ignore(stack.pop())
      at = probe + 1
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
        bytes[at] != b'>' &&
        bytes[at] != b'/' &&
        !is_xml_ws(bytes[at]) {
    guard bytes[at] < b'\x80' else {
      raise Unsupported(
        message="run formatting requires ASCII element names at the edit site",
      )
    }
    at += 1
  }
  let name = ascii_slice(bytes, name_start, at)
  validate_xml_name(name)
  let attributes : Array[FormatAttribute] = []
  let mut self_closing = false
  while at < limit {
    while at < limit && is_xml_ws(bytes[at]) {
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
    while at < limit && bytes[at] != b'=' && !is_xml_ws(bytes[at]) {
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
    validate_xml_name(attr_name)
    while at < limit && is_xml_ws(bytes[at]) {
      at += 1
    }
    guard at < limit && bytes[at] == b'=' else {
      raise Unsupported(
        message="run formatting found an attribute without a value",
      )
    }
    at += 1
    while at < limit && is_xml_ws(bytes[at]) {
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
/// The ASCII subset of XML QNAMES this engine will edit around: at
/// most ONE colon, each side a nonempty NCName. Anything else — an
/// empty name (so `</ w:b>` can never pass as `w:b`), `w:`, `x:y:z` —
/// is a refusal: a multi-colon spelling would let split_qname's
/// first-colon split evade the alias guards.
fn validate_xml_name(name : String) -> Unit raise DocxError {
  let units = name.code_units()
  let mut colon = -1
  for index in 0..<units.length() {
    if units[index].to_int() == ':'.to_int() {
      guard colon < 0 else {
        raise Unsupported(message="run formatting found a malformed XML name")
      }
      colon = index
    }
  }
  if colon < 0 {
    validate_ncname_part(name)
  } else {
    validate_ncname_part(name[:colon].to_owned())
    validate_ncname_part(
      name[colon + 1:].to_owned(),
    )
  }
}

///|
fn validate_ncname_part(part : String) -> Unit raise DocxError {
  guard part.length() > 0 else {
    raise Unsupported(message="run formatting found a malformed XML name")
  }
  let mut first = true
  for ch in part {
    let valid = if first {
      ch is ('A'..='Z' | 'a'..='z' | '_')
    } else {
      ch is ('A'..='Z' | 'a'..='z' | '0'..='9' | '_' | '-' | '.')
    }
    guard valid else {
      raise Unsupported(message="run formatting found a malformed XML name")
    }
    first = false
  }
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
fn rpr_rank(local_name : String) -> Int? {
  let order = [
    "rStyle", "rFonts", "b", "bCs", "i", "iCs", "caps", "smallCaps", "strike", "dstrike",
    "outline", "shadow", "emboss", "imprint", "noProof", "snapToGrid", "vanish",
    "webHidden", "color", "spacing", "w", "kern", "position", "sz", "szCs", "highlight",
    "u", "effect", "bdr", "shd", "fitText", "vertAlign", "rtl", "cs", "em", "lang",
    "eastAsianLayout", "specVanish", "oMath",
  ]
  for index, name in order {
    if name == local_name {
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
/// The scanned structure of one run slice: where its open tag ends,
/// whether it is self-closing, and its (unique, first-child) `rPr` if
/// present. Shared by the planner and the verifier — this is lexer
/// truth, not edit generation.
priv struct RunShape {
  open_end : Int
  self_closing : Bool
  rpr : RunChildTag?
}

///|
/// Markup-compatibility directive attributes are refused wherever
/// they could redirect what this engine is editing around.
fn refuse_mce_attributes(
  owner : String,
  attributes : Array[FormatAttribute],
) -> Unit raise DocxError {
  for attribute in attributes {
    let (_, attr_local) = split_qname(attribute.name)
    if attr_local == "Ignorable" ||
      attr_local == "ProcessContent" ||
      attr_local == "MustUnderstand" {
      raise Unsupported(
        message="run formatting refuses a markup-compatibility attribute on \{owner}",
      )
    }
  }
}

///|
fn scan_run_shape(
  run_slice : BytesView,
  binding : WmlBinding,
) -> RunShape raise DocxError {
  guard run_slice.length() > 0 && run_slice[0] == b'<' else {
    raise Unsupported(message="run formatting requires the run's element slice")
  }
  let run_qname = wml_name(binding, "r")
  let (run_name, run_attributes, run_self_closing, run_open_end) = scan_format_tag(
    run_slice,
    0,
    run_slice.length(),
  )
  guard run_name == run_qname else {
    raise Unsupported(
      message="run formatting expected a <\{run_qname}> element at the slice head",
    )
  }
  // Markup-compatibility DIRECTIVES on the run itself (and they are
  // inherited from ancestors this slice cannot see — the wrapper
  // refusals below are the real guard) are refused on sight.
  refuse_mce_attributes(run_qname, run_attributes)
  if run_self_closing {
    guard run_open_end == run_slice.length() else {
      raise Unsupported(
        message="run formatting requires the slice to end at the run",
      )
    }
    return { open_end: run_open_end, self_closing: true, rpr: None, }
  }
  // The slice must end with this run's own close tag — checked, not
  // assumed, because this is a public planner. Parsed, not compared
  // to a canonical spelling: `</w:r >` is legal XML. A '<' inside
  // content would be a well-formedness error anyway, so the LAST '<'
  // opens the run's close tag.
  let mut close_start = run_slice.length() - 1
  while close_start >= run_open_end && run_slice[close_start] != b'<' {
    close_start -= 1
  }
  guard close_start >= run_open_end &&
    close_start + 1 < run_slice.length() &&
    run_slice[close_start + 1] == b'/' else {
    raise Unsupported(
      message="run formatting requires the slice to end at the run's close tag",
    )
  }
  let mut cursor = close_start + 2
  while cursor < run_slice.length() &&
        run_slice[cursor] != b'>' &&
        !is_xml_ws(run_slice[cursor]) {
    cursor += 1
  }
  let close_name = ascii_slice(run_slice, close_start + 2, cursor)
  while cursor < run_slice.length() && is_xml_ws(run_slice[cursor]) {
    cursor += 1
  }
  guard close_name == run_qname &&
    cursor == run_slice.length() - 1 &&
    run_slice[cursor] == b'>' else {
    raise Unsupported(
      message="run formatting requires the slice to end at the run's close tag",
    )
  }
  let content_end = close_start
  let children = scan_direct_children(run_slice, run_open_end, content_end)
  let rpr_qname = wml_name(binding, "rPr")
  let mut rpr : RunChildTag? = None
  for index, child in children {
    // The alias family stops HERE too: an rPr under any other prefix
    // may be a WML alias (editing around it would plan a duplicate or
    // false-verify), and a markup-compatibility container could
    // supply one after content selection.
    let (child_prefix, child_local) = split_qname(child.name)
    if child_local == "rPr" && child.name != rpr_qname {
      raise Unsupported(
        message="run formatting refuses the run child \{child.name}: an rPr under another prefix may be a WML alias",
      )
    }
    if child_local == "AlternateContent" ||
      child_local == "Choice" ||
      child_local == "Fallback" ||
      child_local == "ProcessContent" {
      raise Unsupported(
        message="run formatting refuses markup-compatibility content inside a run",
      )
    }
    // ANY foreign-prefixed run child could be a wrapper that an
    // inherited mc:ProcessContent directive splices away — its
    // effective contents (a hidden rPr, say) cannot be established
    // from this slice, so it refuses.
    if child_prefix != binding.element {
      raise Unsupported(
        message="run formatting refuses the run child \{child.name}: a foreign-prefixed run child may be a markup-compatibility wrapper whose effective contents this engine cannot establish",
      )
    }
    if child.name == rpr_qname {
      refuse_mce_attributes(child.name, child.attributes)
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
  { open_end: run_open_end, self_closing: false, rpr, }
}

///|
/// Plan the minimal edits that make `format` hold explicitly on one
/// run, given the run's complete byte slice and the document's WML
/// binding: `prefix` is the ELEMENT prefix ("" for a default-namespace
/// document), `attr_prefix` (default: `prefix`) is the prefix WML
/// attributes carry — never empty, because default namespaces do not
/// apply to attributes — and `extension_prefixes` lists the prefixes
/// the caller warrants are bound to recognized rPr extension
/// namespaces.
pub fn plan_run_format(
  run_slice : BytesView,
  prefix~ : String,
  attr_prefix? : String,
  extension_prefixes? : Array[String],
  format~ : DocxDirectFormat,
) -> RunFormatPlan raise DocxError {
  let binding = make_binding(prefix, attr_prefix, extension_prefixes)
  let shape = scan_run_shape(run_slice, binding)
  let run_qname = wml_name(binding, "r")
  let rpr_qname = wml_name(binding, "rPr")
  if shape.self_closing {
    // Expand only the closing "/>" — the open tag's own attributes and
    // spacing are preserved untouched.
    let rendered = render_rpr_children(binding, format)
    let insert_at = run_slice.length() - 2
    guard run_slice[insert_at] == b'/' && run_slice[insert_at + 1] == b'>' else {
      raise Unsupported(
        message="run formatting found a malformed self-closing run",
      )
    }
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
  match shape.rpr {
    None => {
      let rendered = render_rpr_children(binding, format)
      {
        edits: [
          {
            start: shape.open_end,
            end: shape.open_end,
            replacement: "<\{rpr_qname}>" + rendered + "</\{rpr_qname}>",
          },
        ],
        changed: true,
      }
    }
    Some(container) => plan_within_rpr(run_slice, binding, format, container)
  }
}

///|
/// The classified inventory of one non-self-closing rPr: targeted
/// properties recorded (duplicates refused), ranked children proven
/// monotonic, extension children admitted ONLY under a caller-vouched
/// prefix — and never when their local name collides with a ranked
/// WML property (a possible alias) or spells markup-compatibility
/// content this lexical engine cannot resolve.
priv struct RprInventory {
  bold : RunChildTag?
  bold_cs : RunChildTag?
  italic : RunChildTag?
  italic_cs : RunChildTag?
  underline : RunChildTag?
  color : RunChildTag?
  children : Array[RunChildTag]
  insertion_limit : Int
}

///|
fn empty_inventory() -> RprInventory {
  {
    bold: None,
    bold_cs: None,
    italic: None,
    italic_cs: None,
    underline: None,
    color: None,
    children: [],
    insertion_limit: 0,
  }
}

///|
fn classify_rpr_children(
  run_slice : BytesView,
  binding : WmlBinding,
  container : RunChildTag,
) -> RprInventory raise DocxError {
  // The interior ends where the scanner RECORDED the close tag —
  // never reconstructed from the canonical spelling, which `</w:rPr >`
  // would exceed.
  let interior_end = container.close_start
  let children = scan_direct_children(
    run_slice,
    container.open_end,
    interior_end,
  )
  let mut seen_b : RunChildTag? = None
  let mut seen_bcs : RunChildTag? = None
  let mut seen_i : RunChildTag? = None
  let mut seen_ics : RunChildTag? = None
  let mut seen_u : RunChildTag? = None
  let mut seen_color : RunChildTag? = None
  let mut last_rank = -1
  let mut extension_block_start : Int? = None
  for child in children {
    let (child_prefix, local_name) = split_qname(child.name)
    if child_prefix != binding.element {
      // A foreign-prefixed child is legal ONLY as part of the trailing
      // extension block, under a prefix the caller vouched for — and
      // even then never under a ranked property's name (a possible
      // WML alias) or a markup-compatibility name (content selection
      // this lexical engine cannot resolve).
      guard binding.extensions.contains(child_prefix) else {
        raise Unsupported(
          message="run formatting refuses the rPr child \{child.name}: its prefix is outside the caller-vouched extension prefixes",
        )
      }
      guard rpr_rank(local_name) is None else {
        raise Unsupported(
          message="run formatting refuses \{child.name}: a ranked property name under a foreign prefix may be a WML alias",
        )
      }
      // The unranked WML structural names are alias-suspect too: an
      // aliased tracked change (or nested rPr) must never ride in as
      // an "extension".
      guard local_name != "rPrChange" && local_name != "rPr" else {
        raise Unsupported(
          message="run formatting refuses \{child.name}: \{local_name} under a foreign prefix may be a WML alias",
        )
      }
      guard local_name != "AlternateContent" &&
        local_name != "Choice" &&
        local_name != "Fallback" &&
        local_name != "ProcessContent" else {
        raise Unsupported(
          message="run formatting refuses markup-compatibility content inside rPr",
        )
      }
      // The wrapper's SUBTREE must not conceal WML either: an
      // inherited mc:ProcessContent directive could splice its
      // children into rPr after the fact.
      if !child.self_closing {
        scan_extension_interior(
          run_slice,
          binding,
          child.open_end,
          child.close_start,
        )
      }
      if extension_block_start is None {
        extension_block_start = Some(child.byte_start)
      }
      continue
    }
    if local_name == "rPrChange" {
      raise Unsupported(
        message="run formatting refuses a run with an in-flight tracked property change (rPrChange)",
      )
    }
    match rpr_rank(local_name) {
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
        // EVERY ranked CT_RPr property is an empty element in the
        // schema — the attribute-only ones (rFonts, sz, lang, bdr, …)
        // just as much as the on/off ones. A child inside one is
        // content this engine cannot account for, and the reader would
        // not walk into it either.
        guard !child.has_element_children else {
          raise Unsupported(
            message="run formatting refuses a non-leaf \{child.name} property",
          )
        }
        last_rank = rank
      }
      None =>
        raise Unsupported(
          message="run formatting does not recognize the rPr child \{child.name}",
        )
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
    if local_name == "b" {
      seen_b = record(seen_b, child)
    } else if local_name == "bCs" {
      seen_bcs = record(seen_bcs, child)
    } else if local_name == "i" {
      seen_i = record(seen_i, child)
    } else if local_name == "iCs" {
      seen_ics = record(seen_ics, child)
    } else if local_name == "u" {
      seen_u = record(seen_u, child)
    } else if local_name == "color" {
      seen_color = record(seen_color, child)
    }
  }
  {
    bold: seen_b,
    bold_cs: seen_bcs,
    italic: seen_i,
    italic_cs: seen_ics,
    underline: seen_u,
    color: seen_color,
    children,
    // The unique legal insertion boundary for NEW children is before
    // the trailing extension block (or the interior end).
    insertion_limit: extension_block_start.unwrap_or(interior_end),
  }
}

///|
/// An admitted extension wrapper's DESCENDANTS must not conceal WML:
/// an inherited mc:ProcessContent directive can splice a wrapper's
/// children into rPr after the fact, so anything that could then
/// contradict this engine's absolute set — an element under the WML
/// binding, a ranked or structural local under ANY prefix, or nested
/// markup-compatibility content — refuses now, while it is still
/// hidden. Genuine extension content (w14:glow's theme colours, say)
/// passes untouched.
fn scan_extension_interior(
  bytes : BytesView,
  binding : WmlBinding,
  start : Int,
  end : Int,
) -> Unit raise DocxError {
  let children = scan_direct_children(bytes, start, end)
  for child in children {
    let (child_prefix, local_name) = split_qname(child.name)
    guard child_prefix != binding.element else {
      raise Unsupported(
        message="run formatting refuses WML content (\{child.name}) inside an extension wrapper",
      )
    }
    guard rpr_rank(local_name) is None && local_name != "rPr" && local_name != "rPrChange" else {
      raise Unsupported(
        message="run formatting refuses \{child.name} inside an extension wrapper: it may be a WML alias",
      )
    }
    guard local_name != "AlternateContent" &&
      local_name != "Choice" &&
      local_name != "Fallback" &&
      local_name != "ProcessContent" else {
      raise Unsupported(
        message="run formatting refuses markup-compatibility content inside an extension wrapper",
      )
    }
    if !child.self_closing {
      scan_extension_interior(bytes, binding, child.open_end, child.close_start)
    }
  }
}

///|
fn plan_within_rpr(
  run_slice : BytesView,
  binding : WmlBinding,
  format : DocxDirectFormat,
  container : RunChildTag,
) -> RunFormatPlan raise DocxError {
  let rpr_qname = wml_name(binding, "rPr")
  if container.self_closing {
    // Expand only the closing "/>": the open tag with every attribute
    // and spacing survives byte-for-byte.
    let rendered = render_rpr_children(binding, format)
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
  let inventory = classify_rpr_children(run_slice, binding, container)
  let pending : Array[PendingEdit] = []
  match format.bold {
    Some(value) => {
      plan_on_off(
        binding,
        "b",
        value,
        inventory.bold,
        inventory,
        container,
        pending,
      )
      plan_on_off(
        binding,
        "bCs",
        value,
        inventory.bold_cs,
        inventory,
        container,
        pending,
      )
    }
    None => ()
  }
  match format.italic {
    Some(value) => {
      plan_on_off(
        binding,
        "i",
        value,
        inventory.italic,
        inventory,
        container,
        pending,
      )
      plan_on_off(
        binding,
        "iCs",
        value,
        inventory.italic_cs,
        inventory,
        container,
        pending,
      )
    }
    None => ()
  }
  match format.underline {
    Some(value) =>
      plan_underline(
        binding,
        value,
        inventory.underline,
        inventory,
        container,
        pending,
      )
    None => ()
  }
  match format.color {
    Some(value) =>
      plan_color(
        run_slice,
        binding,
        value,
        inventory.color,
        inventory,
        container,
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
/// child of lower rank, never past the trailing extension block.
/// Ranked children are already proven monotonic, so this point is
/// unique and legal by construction.
fn rpr_insertion_offset(
  binding : WmlBinding,
  local_name : String,
  inventory : RprInventory,
  container : RunChildTag,
) -> (Int, Int) raise DocxError {
  guard rpr_rank(local_name) is Some(rank) else {
    raise Unsupported(message="run formatting has no rank for \{local_name}")
  }
  let mut offset = container.open_end
  for child in inventory.children {
    if child.byte_start >= inventory.insertion_limit {
      break
    }
    let (child_prefix, child_local) = split_qname(child.name)
    if child_prefix != binding.element {
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
/// The attribute name a WML-namespaced attribute carries — ALWAYS
/// qualified, because XML default namespaces do not apply to
/// attributes.
fn wml_attr(binding : WmlBinding, local_name : String) -> String {
  "\{binding.attribute}:\{local_name}"
}

///|
fn find_val(
  binding : WmlBinding,
  tag : RunChildTag,
) -> FormatAttribute? raise DocxError {
  let val_name = wml_attr(binding, "val")
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
/// On properties that keep their other attributes (u, color), any
/// attribute whose LOCAL name is one this engine asserts about but
/// whose prefix is not the bound one — a bare `val` (no namespace), a
/// foreign `x:val`, an aliased `x:themeColor` — is refused rather
/// than read past: under an aliased WML binding it may be the very
/// value this engine is about to contradict or leave behind.
fn refuse_wml_attr_alias(
  binding : WmlBinding,
  tag : RunChildTag,
  locals : Array[String],
) -> Unit raise DocxError {
  for attribute in tag.attributes {
    let (attr_prefix, local_name) = split_qname(attribute.name)
    if locals.contains(local_name) && attr_prefix != binding.attribute {
      raise Unsupported(
        message="run formatting refuses the attribute \{attribute.name} on \{tag.name}",
      )
    }
  }
}

///|
fn plan_on_off(
  binding : WmlBinding,
  local_name : String,
  requested : Bool,
  existing : RunChildTag?,
  inventory : RprInventory,
  container : RunChildTag,
  pending : Array[PendingEdit],
) -> Unit raise DocxError {
  match existing {
    Some(tag) => {
      // ST_OnOff properties carry ONLY the val attribute; anything
      // else — a bare `val` with no namespace, a foreign-prefixed
      // val — would change what this planner is reading, so it
      // refuses rather than misreads the property as val-less.
      let val_name = wml_attr(binding, "val")
      for attribute in tag.attributes {
        guard attribute.name == val_name else {
          raise Unsupported(
            message="run formatting refuses the attribute \{attribute.name} on \{tag.name}",
          )
        }
      }
      let val = find_val(binding, tag)
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
                  replacement: " \{wml_attr(binding, "val")}=\"0\"",
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
        binding, local_name, inventory, container,
      )
      let qname = wml_name(binding, local_name)
      let rendered = if requested {
        "<\{qname}/>"
      } else {
        "<\{qname} \{wml_attr(binding, "val")}=\"0\"/>"
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
  binding : WmlBinding,
  requested : Bool,
  existing : RunChildTag?,
  inventory : RprInventory,
  container : RunChildTag,
  pending : Array[PendingEdit],
) -> Unit raise DocxError {
  let wanted = if requested { "single" } else { "none" }
  match existing {
    Some(tag) => {
      refuse_wml_attr_alias(binding, tag, ["val"])
      match find_val(binding, tag) {
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
    }
    None => {
      let (offset, rank) = rpr_insertion_offset(
        binding, "u", inventory, container,
      )
      pending.push({
        start: offset,
        end: offset,
        replacement: "<\{wml_name(binding, "u")} \{wml_attr(binding, "val")}=\"\{wanted}\"/>",
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
    let a = left[index].to_int().unsafe_to_char()
    let folded = if a is ('a'..='f') {
      (a.to_int() - 32).unsafe_to_char()
    } else {
      a
    }
    if folded.to_int() != right[index].to_int() {
      return false
    }
  }
  true
}

///|
fn plan_color(
  run_slice : BytesView,
  binding : WmlBinding,
  requested : String,
  existing : RunChildTag?,
  inventory : RprInventory,
  container : RunChildTag,
  pending : Array[PendingEdit],
) -> Unit raise DocxError {
  match existing {
    Some(tag) => {
      refuse_wml_attr_alias(binding, tag, [
        "val", "themeColor", "themeTint", "themeShade",
      ])
      let val = find_val(binding, tag)
      let theme_names = [
        wml_attr(binding, "themeColor"),
        wml_attr(binding, "themeTint"),
        wml_attr(binding, "themeShade"),
      ]
      for attribute in tag.attributes {
        if theme_names.contains(attribute.name) {
          // The removal span covers the whitespace BEFORE the name
          // through the closing quote — spans come from the scanner,
          // never reconstructed.
          let mut span_start = attribute.name_start
          while span_start > 0 && is_xml_ws(run_slice[span_start - 1]) {
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
        binding, "color", inventory, container,
      )
      pending.push({
        start: offset,
        end: offset,
        replacement: "<\{wml_name(binding, "color")} \{wml_attr(binding, "val")}=\"\{requested}\"/>",
        order: rank,
      })
    }
  }
}

///|
/// Render the CHILDREN of a fresh `rPr` in schema order.
fn render_rpr_children(
  binding : WmlBinding,
  format : DocxDirectFormat,
) -> String {
  let builder = StringBuilder()
  let val = wml_attr(binding, "val")
  match format.bold {
    Some(true) =>
      builder.write_string(
        "<\{wml_name(binding, "b")}/><\{wml_name(binding, "bCs")}/>",
      )
    Some(false) =>
      builder.write_string(
        "<\{wml_name(binding, "b")} \{val}=\"0\"/><\{wml_name(binding, "bCs")} \{val}=\"0\"/>",
      )
    None => ()
  }
  match format.italic {
    Some(true) =>
      builder.write_string(
        "<\{wml_name(binding, "i")}/><\{wml_name(binding, "iCs")}/>",
      )
    Some(false) =>
      builder.write_string(
        "<\{wml_name(binding, "i")} \{val}=\"0\"/><\{wml_name(binding, "iCs")} \{val}=\"0\"/>",
      )
    None => ()
  }
  match format.color {
    Some(value) =>
      builder.write_string(
        "<\{wml_name(binding, "color")} \{val}=\"\{value}\"/>",
      )
    None => ()
  }
  match format.underline {
    Some(value) => {
      let wanted = if value { "single" } else { "none" }
      builder.write_string("<\{wml_name(binding, "u")} \{val}=\"\{wanted}\"/>")
    }
    None => ()
  }
  builder.to_string()
}

// ---------------------------------------------------------------------------
// The direct-property oracle
// ---------------------------------------------------------------------------

///|
/// Read one ST_OnOff property strictly for VERIFICATION and compare
/// it to the requested value — written against the vocabulary, not
/// against the planner's edit generation.
fn verify_on_off(
  binding : WmlBinding,
  existing : RunChildTag?,
  requested : Bool,
  label : String,
) -> String? raise DocxError {
  match existing {
    None => Some("\{label} is not stated explicitly")
    Some(tag) => {
      let val_name = wml_attr(binding, "val")
      let mut spelled : String? = None
      let mut has_val = false
      for attribute in tag.attributes {
        guard attribute.name == val_name else {
          raise Unsupported(
            message="run formatting refuses the attribute \{attribute.name} on \{tag.name}",
          )
        }
        guard !has_val else {
          raise Unsupported(
            message="run formatting refuses duplicate val attributes on \{tag.name}",
          )
        }
        has_val = true
        spelled = Some(attribute.value)
      }
      match on_off_value(spelled) {
        Some(observed) =>
          if observed == requested {
            None
          } else {
            let observed_text = if observed { "on" } else { "off" }
            let requested_text = if requested { "on" } else { "off" }
            Some(
              "\{tag.name} states \{observed_text} where \{label} \{requested_text} was requested",
            )
          }
        None =>
          raise Unsupported(
            message="run formatting found an unrecognized on/off value on \{tag.name}",
          )
      }
    }
  }
}

///|
/// Verify that every requested property holds EXPLICITLY on the run
/// slice by EXTRACTING each property's observed value and comparing
/// it semantically — independent of the planner's edit generation
/// (the two share only the lexical scanner and the rPr
/// classification). Returns None when satisfied, or the FIRST
/// discrepancy in property order (b, bCs, i, iCs, u, color). As a
/// final cross-check the planner must also consider a satisfied slice
/// a fixed point; a disagreement between the two readings is itself
/// reported.
pub fn verify_run_format(
  run_slice : BytesView,
  prefix~ : String,
  attr_prefix? : String,
  extension_prefixes? : Array[String],
  format~ : DocxDirectFormat,
) -> String? raise DocxError {
  let binding = make_binding(prefix, attr_prefix, extension_prefixes)
  let shape = scan_run_shape(run_slice, binding)
  let inventory : RprInventory = match shape.rpr {
    Some(container) =>
      if container.self_closing {
        empty_inventory()
      } else {
        classify_rpr_children(run_slice, binding, container)
      }
    None => empty_inventory()
  }
  match format.bold {
    Some(requested) => {
      match verify_on_off(binding, inventory.bold, requested, "bold") {
        Some(discrepancy) => return Some(discrepancy)
        None => ()
      }
      match
        verify_on_off(
          binding,
          inventory.bold_cs,
          requested,
          "complex-script bold",
        ) {
        Some(discrepancy) => return Some(discrepancy)
        None => ()
      }
    }
    None => ()
  }
  match format.italic {
    Some(requested) => {
      match verify_on_off(binding, inventory.italic, requested, "italic") {
        Some(discrepancy) => return Some(discrepancy)
        None => ()
      }
      match
        verify_on_off(
          binding,
          inventory.italic_cs,
          requested,
          "complex-script italic",
        ) {
        Some(discrepancy) => return Some(discrepancy)
        None => ()
      }
    }
    None => ()
  }
  match format.underline {
    Some(requested) => {
      let wanted = if requested { "single" } else { "none" }
      match inventory.underline {
        None => return Some("underline is not stated explicitly")
        Some(tag) => {
          refuse_wml_attr_alias(binding, tag, ["val"])
          match find_val(binding, tag) {
            Some(attribute) =>
              if attribute.value != wanted {
                return Some(
                  "\{tag.name} states \{attribute.value} where \{wanted} was requested",
                )
              }
            None =>
              raise Unsupported(
                message="run formatting found an underline without a val attribute",
              )
          }
        }
      }
    }
    None => ()
  }
  match format.color {
    Some(requested) =>
      match inventory.color {
        None => return Some("color is not stated explicitly")
        Some(tag) => {
          refuse_wml_attr_alias(binding, tag, [
            "val", "themeColor", "themeTint", "themeShade",
          ])
          let theme_names = [
            wml_attr(binding, "themeColor"),
            wml_attr(binding, "themeTint"),
            wml_attr(binding, "themeShade"),
          ]
          for attribute in tag.attributes {
            if theme_names.contains(attribute.name) {
              return Some(
                "\{tag.name} keeps theme linkage (\{attribute.name}) where an absolute color was requested",
              )
            }
          }
          match find_val(binding, tag) {
            Some(attribute) =>
              if !rgb_equal(attribute.value, requested) {
                return Some(
                  "\{tag.name} states \{attribute.value} where \{requested} was requested",
                )
              }
            None =>
              raise Unsupported(
                message="run formatting found a color without a val attribute",
              )
          }
        }
      }
    None => ()
  }
  let plan = plan_run_format(
    run_slice,
    prefix~,
    attr_prefix?,
    extension_prefixes?,
    format~,
  )
  if plan.changed {
    Some(
      "the planner would still edit a slice whose extracted properties satisfy the request",
    )
  } else {
    None
  }
}
