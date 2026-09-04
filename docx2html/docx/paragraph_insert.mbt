// `office insert-paragraph` — the N3a planner, with R3's minting rule:
// a NEW physical paragraph is the only thing that ever receives a new
// `w14:paraId`. The fragment is synthesized namespace-self-contained,
// stamped BEFORE any report is built, spliced at a direct body
// paragraph boundary, and everything else in the package stays
// byte-identical.

///|
/// One resource-free run of insertion content: text with direct
/// formatting only. Hyperlinks, images, notes, and list bullets are
/// v1 refusals — they need relationship, media, or numbering surgery.
pub(all) struct DocxInsertRun {
  text : String
  bold : Bool
  italic : Bool
  underline : Bool
} derive(Debug, Eq)

///|
/// The dedicated `docx.paragraph/1` content payload: an optional
/// paragraph style reference (verified against the TARGET's styles
/// part) and resource-free runs.
pub(all) struct DocxInsertContent {
  style : String?
  runs : Array[DocxInsertRun]
} derive(Debug, Eq)

///|
/// What one planned insertion did: the minted id (canonical uppercase,
/// allocated fresh against the whole document's inventory) and the
/// ordinal path the new paragraph will answer to after publication.
pub struct DocxInsertReceipt {
  priv para_id : String
  priv planned_path : String
}

///|
/// The minted paragraph id (canonical uppercase) this insertion received.
pub fn DocxInsertReceipt::para_id(self : DocxInsertReceipt) -> String {
  self.para_id
}

///|
/// The ordinal path the new paragraph will answer to after publication.
pub fn DocxInsertReceipt::planned_path(self : DocxInsertReceipt) -> String {
  self.planned_path
}

///|
/// Mint a fresh paraId: the smallest canonical value not in `used`.
/// Deterministic by design — tests assert validity and freshness,
/// never an allocator sequence — and conservative: `used` should carry
/// every id seen anywhere in the package, buried and invalid spellings
/// included, so a mint can never collide with anything a future repair
/// might surface.
pub fn mint_para_id(used : Array[String]) -> String raise DocxError {
  let taken : StableStringSet = SortedSet([])
  for value in used {
    // Case-insensitive occupancy: canonicalize what validates, keep
    // raw spellings too so even invalid occupants block their exact
    // spelling.
    match validated_para_id(value) {
      Some(canonical) => taken.add(canonical)
      None => taken.add(value)
    }
  }
  // Int is 32-bit: the valid ceiling is 0x7FFFFFFF itself, and the
  // loop guards positivity so the final increment cannot wrap into an
  // endless negative walk.
  let mut candidate = 1
  while candidate >= 1 && candidate <= 0x7FFFFFFF {
    let rendered = render_para_id(candidate)
    if !taken.contains(rendered) {
      return rendered
    }
    candidate += 1
  }
  raise Unsupported(
    message="cannot mint a w14:paraId: the document exhausts the identifier space",
  )
}

///|
fn render_para_id(value : Int) -> String {
  let digits = "0123456789ABCDEF"
  let units = digits.code_units()
  let builder = StringBuilder(size_hint=8)
  for shift in [28, 24, 20, 16, 12, 8, 4, 0] {
    let nibble = (value >> shift) & 0xF
    builder.write_char(units[nibble].to_int().unsafe_to_char())
  }
  builder.to_string()
}

///|
/// Plan one paragraph insertion beside a DIRECT body paragraph.
///
/// `at` is the direct body ordinal path ("p[3]" — nested paragraphs
/// are not insertion anchors); `before` picks which side of it the new
/// paragraph lands on. `used_para_ids` is the caller's complete
/// inventory (the transaction already holds it for the delta gate).
/// The returned plan splices ONLY the insertion; the receipt carries
/// the minted id and the path the paragraph will answer to.
pub fn plan_docx_paragraph_insertion(
  annotated : DocxAnnotatedResult,
  at~ : String,
  before~ : Bool,
  content~ : DocxInsertContent,
  used_para_ids~ : Array[String],
) -> (@splice.SplicePlan, DocxInsertReceipt) raise DocxError {
  // Direct body children only: exactly p[N].
  guard insert_anchor_ordinal(at) is Some(ordinal) else {
    raise Unsupported(
      message="insert-paragraph anchors at a direct body paragraph (p[N]); '\{at}' is not one",
    )
  }
  guard content.runs.length() > 0 else {
    raise Unsupported(
      message="insert-paragraph requires at least one run; an empty paragraph is not a v1 payload",
    )
  }
  for run in content.runs {
    validate_insert_text(run.text, "run text")
  }
  match content.style {
    Some(style) => validate_insert_text(style, "style reference")
    None => ()
  }
  match content.style {
    Some(style) =>
      if !annotated.paragraph_style_ids().contains(style) {
        raise Unsupported(
          message="insert-paragraph references paragraph style '\{style}', which the target's styles part does not define",
        )
      }
    None => ()
  }
  guard annotated.body_paragraph_span(at) is Some(span) else {
    raise Unsupported(
      message="insert-paragraph anchor '\{at}' does not resolve in this document",
    )
  }
  let part = annotated.main_story_part()
  guard annotated.reader_projection_sources.get(part) is Some(bytes) else {
    raise Unsupported(
      message="insert-paragraph requires a mutation-safe read with retained source bytes",
    )
  }
  // The path grammar flattens transparent containers (w:sdt, w:ins,
  // mc:Fallback…), so "p[1]" can name a paragraph INSIDE a wrapper —
  // and an insertion beside it would land inside that wrapper. The
  // anchor must be a PHYSICAL child of w:body, proven on the element
  // tree, not inferred from the path.
  guard annotated.reader_projections.get(part) is Some(projection) else {
    raise Unsupported(
      message="insert-paragraph requires a mutation-safe read with a retained projection",
    )
  }
  let elements = projection.scan.elements()
  let mut anchor_is_direct = false
  for element in elements {
    if element.byte_start == span.byte_start() &&
      element.local_name == "p" &&
      is_wml_uri(element.uri) {
      let parent = element.parent_index
      if parent >= 0 && parent < elements.length() {
        let holder = elements[parent]
        if holder.local_name == "body" && is_wml_uri(holder.uri) {
          anchor_is_direct = true
        }
      }
      break
    }
  }
  guard anchor_is_direct else {
    raise Unsupported(
      message="insert-paragraph anchor '\{at}' is not a DIRECT child of the body — paragraphs inside content controls, revisions, or compatibility wrappers are not insertion anchors",
    )
  }
  // The neighbour's own tag names the WML prefix this document binds —
  // the fragment reuses it rather than assuming `w`.
  let prefix = paragraph_tag_prefix(bytes, span.byte_start())
  // The fragment hard-declares xmlns:w14 and xmlns:mc; a document whose
  // WML prefix IS one of those would make the fragment declare the same
  // prefix twice with conflicting URIs — malformed. Refuse the exotic
  // case rather than emit it.
  guard prefix != "w14" && prefix != "mc" else {
    raise Unsupported(
      message="insert-paragraph cannot synthesize a fragment when the document's WML prefix is the reserved '\{prefix}'",
    )
  }
  guard projection.scan.root_namespace_uri() is Some(wml_uri) else {
    raise Unsupported(
      message="insert-paragraph could not determine the document's WML namespace",
    )
  }
  let minted = mint_para_id(used_para_ids)
  let fragment = render_insert_fragment(prefix, wml_uri, minted, content)
  let offset = if before { span.byte_start() } else { span.byte_end() }
  let plan = @splice.SplicePlan::new()
  plan.pin_part(part, bytes)
  plan.edit_part(
    part,
    @splice.span_edit(start=offset, end=offset, @utf8.encode(fragment)),
  )
  let planned_path = if before { "p[\{ordinal}]" } else { "p[\{ordinal + 1}]" }
  (plan, { para_id: minted, planned_path, })
}

///|
/// The exact direct-body anchor grammar: `p[N]`, N >= 1.
fn insert_anchor_ordinal(at : String) -> Int? {
  guard at.has_prefix("p[") && at.has_suffix("]") && at.length() >= 4 else {
    return None
  }
  let units = at.code_units()
  let mut ordinal = 0
  for index in 2..<(at.length() - 1) {
    let code = units[index].to_int()
    guard code >= '0'.to_int() && code <= '9'.to_int() else { return None }
    // Ordinals are CANONICAL as the reader spells them: `p[007]` is
    // not a path any surface emits, and accepting it here would make
    // the library seam admit addresses the CLI grammar refuses.
    if index == 2 && code == '0'.to_int() {
      return None
    }
    ordinal = ordinal * 10 + (code - '0'.to_int())
    if ordinal > 1_000_000 {
      return None
    }
  }
  if ordinal < 1 {
    return None
  }
  Some(ordinal)
}

///|
/// The WML prefix of the paragraph tag at `offset` ("<w:p ..." -> "w").
fn paragraph_tag_prefix(
  bytes : BytesView,
  offset : Int,
) -> String raise DocxError {
  guard offset >= 0 && offset < bytes.length() && bytes[offset] == b'<' else {
    raise Unsupported(
      message="insert-paragraph anchor span does not begin at an element",
    )
  }
  let builder = StringBuilder()
  let mut at = offset + 1
  while at < bytes.length() && bytes[at] != b':' {
    let byte = bytes[at]
    guard byte < b'\x80' else {
      // A non-ASCII prefix would be byte-mangled by this walk; refuse
      // rather than synthesize a corrupt fragment.
      raise Unsupported(
        message="insert-paragraph requires an ASCII namespace prefix at the anchor",
      )
    }
    guard byte != b'>' && byte != b' ' && byte != b'/' else {
      // An unprefixed paragraph element: legal XML, but this reader's
      // WML documents always carry a prefix — refuse rather than
      // synthesize an unbound fragment.
      raise Unsupported(
        message="insert-paragraph requires a prefixed paragraph element at the anchor",
      )
    }
    builder.write_char(byte.to_int().unsafe_to_char())
    at += 1
  }
  guard at < bytes.length() else {
    raise Unsupported(
      message="insert-paragraph anchor span ends inside its own tag",
    )
  }
  builder.to_string()
}

///|
/// Render the fully self-contained fragment: the WML prefix binding,
/// the w14 binding, AND the MCE declaration all ride the new paragraph
/// locally — no ancestor binding is relied on (an anchor-locally-bound
/// prefix is not inherited by a new SIBLING), and a consumer without
/// w14 support sees mc:Ignorable resolve against OUR binding. The
/// document root is never rewritten.
fn render_insert_fragment(
  prefix : String,
  wml_uri : String,
  para_id : String,
  content : DocxInsertContent,
) -> String {
  let builder = StringBuilder()
  builder.write_string(
    "<\{prefix}:p xmlns:\{prefix}=\"\{wml_uri}\" xmlns:w14=\"http://schemas.microsoft.com/office/word/2010/wordml\" xmlns:mc=\"http://schemas.openxmlformats.org/markup-compatibility/2006\" mc:Ignorable=\"w14\" w14:paraId=\"\{para_id}\">",
  )
  match content.style {
    Some(style) =>
      builder.write_string(
        "<\{prefix}:pPr><\{prefix}:pStyle \{prefix}:val=\"\{escape_insert_attribute(style)}\"/></\{prefix}:pPr>",
      )
    None => ()
  }
  for run in content.runs {
    builder.write_string("<\{prefix}:r>")
    if run.bold || run.italic || run.underline {
      builder.write_string("<\{prefix}:rPr>")
      if run.bold {
        builder.write_string("<\{prefix}:b/>")
      }
      if run.italic {
        builder.write_string("<\{prefix}:i/>")
      }
      if run.underline {
        builder.write_string("<\{prefix}:u \{prefix}:val=\"single\"/>")
      }
      builder.write_string("</\{prefix}:rPr>")
    }
    let preserve = run.text.has_prefix(" ") || run.text.has_suffix(" ")
    if preserve {
      builder.write_string("<\{prefix}:t xml:space=\"preserve\">")
    } else {
      builder.write_string("<\{prefix}:t>")
    }
    builder.write_string(escape_insert_text(run.text))
    builder.write_string("</\{prefix}:t></\{prefix}:r>")
  }
  builder.write_string("</\{prefix}:p>")
  builder.to_string()
}

///|
fn escape_insert_text(text : String) -> String {
  let builder = StringBuilder()
  for character in text {
    match character {
      '&' => builder.write_string("&amp;")
      '<' => builder.write_string("&lt;")
      '>' => builder.write_string("&gt;")
      _ => builder.write_char(character)
    }
  }
  builder.to_string()
}

///|
fn escape_insert_attribute(text : String) -> String {
  let builder = StringBuilder()
  for character in text {
    match character {
      '&' => builder.write_string("&amp;")
      '<' => builder.write_string("&lt;")
      '"' => builder.write_string("&quot;")
      // Literal whitespace in an attribute value is NORMALIZED by XML
      // parsers — a style id that passed existence checking must not
      // change spelling on emission, so these become numeric refs.
      '\t' => builder.write_string("&#x9;")
      '\n' => builder.write_string("&#xA;")
      '\r' => builder.write_string("&#xD;")
      _ => builder.write_char(character)
    }
  }
  builder.to_string()
}

///|
/// Every code unit of insertion text must be XML-representable: no
/// controls (v1 makes no structural breaks from text), no unpaired
/// surrogates (the UTF-8 encoder would panic), and no U+FFFE/U+FFFF
/// (never legal XML characters).
fn validate_insert_text(text : String, what : String) -> Unit raise DocxError {
  let units = text.code_units()
  let mut index = 0
  while index < units.length() {
    let unit = units[index].to_int()
    if unit < 0x20 {
      raise Unsupported(
        message="insert-paragraph \{what} must not contain control characters; v1 makes no structural breaks or tabs from text",
      )
    }
    if unit == 0xFFFE || unit == 0xFFFF {
      raise Unsupported(
        message="insert-paragraph \{what} contains a code point XML cannot represent",
      )
    }
    if unit >= 0xD800 && unit <= 0xDBFF {
      guard index + 1 < units.length() &&
        units[index + 1].to_int() >= 0xDC00 &&
        units[index + 1].to_int() <= 0xDFFF else {
        raise Unsupported(
          message="insert-paragraph \{what} contains an unpaired surrogate",
        )
      }
      index += 2
      continue
    }
    if unit >= 0xDC00 && unit <= 0xDFFF {
      raise Unsupported(
        message="insert-paragraph \{what} contains an unpaired surrogate",
      )
    }
    index += 1
  }
}
