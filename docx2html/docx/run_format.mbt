// F0 — the lexical `w:rPr` engine and direct-property oracle for
// span-addressed formatting.
//
// Everything here operates on ONE run's raw byte slice, purely
// lexically: existing spellings are preserved byte-for-byte, edits are
// the smallest spans that state the requested absolute values, absent
// children are inserted at their CT_RPr schema positions without
// moving anything, and every ambiguity — duplicate `rPr`, duplicate
// targeted properties, an in-flight `rPrChange`, a prefix this walker
// cannot vouch for — is a typed refusal, never a normalization.

///|
/// The v1 absolute-set request: None = untouched, Some(false) = an
/// EXPLICIT off override (never "clear to inherited" — that waits for
/// effective-value provenance). Color is a canonical six-digit
/// uppercase RGB value; bold and italic couple their complex-script
/// twins (`w:bCs`/`w:iCs`) as an office.mbt guarantee.
pub(all) struct DocxDirectFormat {
  bold : Bool?
  italic : Bool?
  underline : Bool?
  color : String?
} derive(Debug, Eq)

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
/// The planned edits for one run: slice-relative, non-overlapping,
/// in ascending order. `changed=false` means every requested property
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
// Lexical child scanning
// ---------------------------------------------------------------------------

///|
priv struct RunChildTag {
  // qname as spelled ("w:b")
  name : String
  byte_start : Int
  // one past the closing '>' of the WHOLE element (subtree included)
  byte_end : Int
  self_closing : Bool
  // one past the '>' of the open tag
  open_end : Int
  // raw attribute text between the qname and the tag close, as spelled
  attributes : Array[(String, String, Int, Int)] // name, value, value_start, value_end
}

///|
/// Scan one element's DIRECT children lexically. `content` bounds are
/// the element's interior. Children with subtrees are consumed whole
/// (depth tracking); text between elements is ignored. Refuses
/// comments, PIs, and CDATA inside the region — an `rPr` carrying
/// those is an ambiguity this engine does not edit.
fn scan_direct_children(
  bytes : BytesView,
  content_start : Int,
  content_end : Int,
) -> Array[RunChildTag] raise DocxError {
  let children : Array[RunChildTag] = []
  let mut at = content_start
  while at < content_end {
    if bytes[at] != b'<' {
      at += 1
      continue
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
    if !self_closing {
      // Consume the subtree to the matching close tag.
      let mut depth = 1
      let mut cursor = open_end
      while cursor < content_end && depth > 0 {
        if bytes[cursor] != b'<' {
          cursor += 1
          continue
        }
        guard cursor + 1 < content_end else {
          raise Unsupported(message="run formatting found a truncated tag")
        }
        if bytes[cursor + 1] == b'!' || bytes[cursor + 1] == b'?' {
          raise Unsupported(
            message="run formatting does not edit regions containing comments, processing instructions, or CDATA",
          )
        }
        if bytes[cursor + 1] == b'/' {
          depth -= 1
          while cursor < content_end && bytes[cursor] != b'>' {
            cursor += 1
          }
          guard cursor < content_end else {
            raise Unsupported(message="run formatting found a truncated tag")
          }
          cursor += 1
        } else {
          let (_, _, inner_self_closing, inner_open_end) = scan_format_tag(
            bytes, cursor, content_end,
          )
          if !inner_self_closing {
            depth += 1
          }
          cursor = inner_open_end
        }
      }
      guard depth == 0 else {
        raise Unsupported(message="run formatting found an unclosed element")
      }
      byte_end = cursor
    }
    children.push({
      name,
      byte_start: at,
      byte_end,
      self_closing,
      open_end,
      attributes,
    })
    at = byte_end
  }
  children
}

///|
/// Scan one open tag: returns (qname, attributes, self_closing,
/// one-past-'>'). Attribute values record their byte spans so a val
/// patch can replace exactly the value.
fn scan_format_tag(
  bytes : BytesView,
  start : Int,
  limit : Int,
) -> (String, Array[(String, String, Int, Int)], Bool, Int) raise DocxError {
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
  let attributes : Array[(String, String, Int, Int)] = []
  let mut self_closing = false
  while at < limit {
    // skip whitespace
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
    // attribute
    let attr_start = at
    while at < limit && bytes[at] != b'=' {
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
    let attr_name = ascii_slice(bytes, attr_start, at)
      .trim(chars=" \t\n\r")
      .to_string()
    at += 1 // '='
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
    let value = ascii_lossy_slice(bytes, value_start, at)
    attributes.push((attr_name, value, value_start, at))
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
/// The ECMA-376 CT_RPr child order, by LOCAL name. Insertion of an
/// absent property finds the last present child whose rank is lower
/// and inserts after it (or at the front). An unknown child makes the
/// insertion point ambiguous only when it sits exactly where the new
/// property belongs — then this engine refuses rather than guesses.
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
/// Plan the minimal edits that make `format` hold explicitly on one
/// run, given the run's complete byte slice and its WML prefix.
///
/// Refusals (all typed through DocxError): duplicate `rPr`, duplicate
/// targeted properties, any `rPrChange`, non-`rPr` first-position
/// surprises this walker cannot vouch for, ambiguous insertion points,
/// and non-ASCII names at the edit site.
pub fn plan_run_format(
  run_slice : BytesView,
  prefix~ : String,
  format~ : DocxDirectFormat,
) -> RunFormatPlan raise DocxError {
  guard run_slice.length() > 0 && run_slice[0] == b'<' else {
    raise Unsupported(message="run formatting requires the run's element slice")
  }
  let (run_name, _, run_self_closing, run_open_end) = scan_format_tag(
    run_slice,
    0,
    run_slice.length(),
  )
  guard run_name == "\{prefix}:r" else {
    raise Unsupported(
      message="run formatting expected a <\{prefix}:r> element at the slice head",
    )
  }
  if run_self_closing {
    // A self-closing run has no interior: synthesize a fresh rPr as
    // its only content by expanding the tag.
    let rendered = render_rpr(prefix, format)
    let insert_at = run_slice.length() - 2 // before "/>"
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
          replacement: ">" + rendered + "</\{prefix}:r>",
        },
      ],
      changed: true,
    }
  }
  // interior = [run_open_end, close_tag_start)
  let close = "</\{prefix}:r>"
  let close_length = close.length()
  guard run_slice.length() >= run_open_end + close_length else {
    raise Unsupported(message="run formatting found a truncated run")
  }
  let content_end = run_slice.length() - close_length
  let children = scan_direct_children(run_slice, run_open_end, content_end)
  let mut rpr : RunChildTag? = None
  for child in children {
    if child.name == "\{prefix}:rPr" {
      guard rpr is None else {
        raise Unsupported(
          message="run formatting refuses a run with duplicate rPr elements",
        )
      }
      rpr = Some(child)
    }
  }
  match rpr {
    None => {
      // No rPr: insert a complete one as the first child.
      let rendered = render_rpr(prefix, format)
      {
        edits: [
          { start: run_open_end, end: run_open_end, replacement: rendered, },
        ],
        changed: true,
      }
    }
    Some(container) => {
      guard children.length() == 0 ||
        children[0].byte_start != container.byte_start ||
        children[0].name == "\{prefix}:rPr" else {
        raise Unsupported(
          message="run formatting expects rPr as the run's first element",
        )
      }
      plan_within_rpr(run_slice, prefix, format, container)
    }
  }
}

///|
fn plan_within_rpr(
  run_slice : BytesView,
  prefix : String,
  format : DocxDirectFormat,
  container : RunChildTag,
) -> RunFormatPlan raise DocxError {
  // A self-closing rPr has no interior — replace it with a rendered one.
  if container.self_closing {
    let rendered = render_rpr(prefix, format)
    return {
      edits: [
        {
          start: container.byte_start,
          end: container.byte_end,
          replacement: rendered,
        },
      ],
      changed: true,
    }
  }
  let close = "</\{prefix}:rPr>"
  let interior_end = container.byte_end - close.length()
  let children = scan_direct_children(
    run_slice,
    container.open_end,
    interior_end,
  )
  // Refusals over the existing children.
  let mut seen_b : RunChildTag? = None
  let mut seen_bcs : RunChildTag? = None
  let mut seen_i : RunChildTag? = None
  let mut seen_ics : RunChildTag? = None
  let mut seen_u : RunChildTag? = None
  let mut seen_color : RunChildTag? = None
  for child in children {
    if child.name == "\{prefix}:rPrChange" {
      raise Unsupported(
        message="run formatting refuses a run with an in-flight tracked property change (rPrChange)",
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
      Some(tag)
    }
    if child.name == "\{prefix}:b" {
      seen_b = record(seen_b, child)
    } else if child.name == "\{prefix}:bCs" {
      seen_bcs = record(seen_bcs, child)
    } else if child.name == "\{prefix}:i" {
      seen_i = record(seen_i, child)
    } else if child.name == "\{prefix}:iCs" {
      seen_ics = record(seen_ics, child)
    } else if child.name == "\{prefix}:u" {
      seen_u = record(seen_u, child)
    } else if child.name == "\{prefix}:color" {
      seen_color = record(seen_color, child)
    }
  }
  let edits : Array[RunFormatEdit] = []
  match format.bold {
    Some(value) => {
      plan_on_off(
        run_slice, prefix, "b", value, seen_b, children, container, edits,
      )
      plan_on_off(
        run_slice, prefix, "bCs", value, seen_bcs, children, container, edits,
      )
    }
    None => ()
  }
  match format.italic {
    Some(value) => {
      plan_on_off(
        run_slice, prefix, "i", value, seen_i, children, container, edits,
      )
      plan_on_off(
        run_slice, prefix, "iCs", value, seen_ics, children, container, edits,
      )
    }
    None => ()
  }
  match format.underline {
    Some(value) =>
      plan_underline(
        run_slice, prefix, value, seen_u, children, container, edits,
      )
    None => ()
  }
  match format.color {
    Some(value) =>
      plan_color(
        run_slice, prefix, value, seen_color, children, container, edits,
      )
    None => ()
  }
  // Ascending, non-overlapping by construction; sort defensively.
  edits.sort_by((left, right) => left.start - right.start)
  { edits: edits.copy(), changed: edits.length() > 0, }
}

///|
/// The insertion offset for a new `local` child: after the last
/// present child of LOWER rank. An unknown-name child at the exact
/// boundary makes the point ambiguous — refuse.
fn rpr_insertion_offset(
  prefix : String,
  local : String,
  children : Array[RunChildTag],
  container : RunChildTag,
) -> Int raise DocxError {
  guard rpr_rank(local) is Some(rank) else {
    raise Unsupported(message="run formatting has no rank for \{local}")
  }
  let mut offset = container.open_end
  for child in children {
    let child_local = if child.name.has_prefix("\{prefix}:") {
      child.name
      .substring(start=prefix.length() + 1, end=child.name.length())
      .to_string()
    } else {
      // A child in another namespace: only blocking when it sits at
      // the boundary we would insert at — since we cannot rank it, any
      // insertion before it is a guess.
      raise Unsupported(
        message="run formatting cannot place a property beside the foreign-prefixed \{child.name}",
      )
    }
    match rpr_rank(child_local) {
      Some(child_rank) => if child_rank < rank { offset = child.byte_end }
      None =>
        // Unknown local name under the WML prefix (extension or newer
        // schema): treat like the foreign case — refuse rather than
        // rank-guess around it.
        raise Unsupported(
          message="run formatting cannot place a property beside the unranked \{child.name}",
        )
    }
  }
  offset
}

///|
fn plan_on_off(
  run_slice : BytesView,
  prefix : String,
  local : String,
  requested : Bool,
  existing : RunChildTag?,
  children : Array[RunChildTag],
  container : RunChildTag,
  edits : Array[RunFormatEdit],
) -> Unit raise DocxError {
  match existing {
    Some(tag) => {
      let mut val : (String, Int, Int)? = None
      for attribute in tag.attributes {
        let (name, value, value_start, value_end) = attribute
        if name == "\{prefix}:val" {
          guard val is None else {
            raise Unsupported(
              message="run formatting refuses duplicate val attributes on \{tag.name}",
            )
          }
          val = Some((value, value_start, value_end))
        }
      }
      match on_off_value(val.map(entry => entry.0)) {
        Some(current) =>
          if current != requested {
            match val {
              // Patch exactly the value.
              Some((_, value_start, value_end)) =>
                edits.push({
                  start: value_start,
                  end: value_end,
                  replacement: if requested {
                    "1"
                  } else {
                    "0"
                  },
                })
              // Absent val means ON; flipping to off appends a val
              // attribute inside the tag.
              None => {
                let insert_at = if tag.self_closing {
                  tag.open_end - 2
                } else {
                  tag.open_end - 1
                }
                edits.push({
                  start: insert_at,
                  end: insert_at,
                  replacement: " \{prefix}:val=\"0\"",
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
      // Only an explicit statement is needed; "off" must still be
      // stated explicitly (absolute set, not clear).
      let offset = rpr_insertion_offset(prefix, local, children, container)
      let rendered = if requested {
        "<\{prefix}:\{local}/>"
      } else {
        "<\{prefix}:\{local} \{prefix}:val=\"0\"/>"
      }
      edits.push({ start: offset, end: offset, replacement: rendered, })
    }
  }
}

///|
fn plan_underline(
  run_slice : BytesView,
  prefix : String,
  requested : Bool,
  existing : RunChildTag?,
  children : Array[RunChildTag],
  container : RunChildTag,
  edits : Array[RunFormatEdit],
) -> Unit raise DocxError {
  let wanted = if requested { "single" } else { "none" }
  match existing {
    Some(tag) => {
      let mut val : (String, Int, Int)? = None
      for attribute in tag.attributes {
        let (name, value, value_start, value_end) = attribute
        if name == "\{prefix}:val" {
          guard val is None else {
            raise Unsupported(
              message="run formatting refuses duplicate val attributes on \{tag.name}",
            )
          }
          val = Some((value, value_start, value_end))
        }
      }
      match val {
        Some((value, value_start, value_end)) =>
          if value != wanted {
            edits.push({
              start: value_start,
              end: value_end,
              replacement: wanted,
            })
          }
        None =>
          // `w:u` without val is not a defined spelling — refuse
          // rather than infer a style.
          raise Unsupported(
            message="run formatting found an underline without a val attribute",
          )
      }
    }
    None => {
      let offset = rpr_insertion_offset(prefix, "u", children, container)
      edits.push({
        start: offset,
        end: offset,
        replacement: "<\{prefix}:u \{prefix}:val=\"\{wanted}\"/>",
      })
    }
  }
}

///|
fn plan_color(
  run_slice : BytesView,
  prefix : String,
  requested : String,
  existing : RunChildTag?,
  children : Array[RunChildTag],
  container : RunChildTag,
  edits : Array[RunFormatEdit],
) -> Unit raise DocxError {
  match existing {
    Some(tag) => {
      // An absolute RGB set: the val becomes the requested color and
      // any theme linkage is removed (leaving it would not be an
      // absolute set); unrelated attributes stay.
      let mut val : (String, Int, Int)? = None
      let theme_spans : Array[(Int, Int)] = []
      for attribute in tag.attributes {
        let (name, value, value_start, value_end) = attribute
        if name == "\{prefix}:val" {
          guard val is None else {
            raise Unsupported(
              message="run formatting refuses duplicate val attributes on \{tag.name}",
            )
          }
          val = Some((value, value_start, value_end))
        } else if name == "\{prefix}:themeColor" ||
          name == "\{prefix}:themeTint" ||
          name == "\{prefix}:themeShade" {
          // Remove the whole attribute: from the space before its name
          // through its closing quote. The name starts after the
          // preceding whitespace; value_end is the closing-quote
          // index. Walk back from value_start to the attribute name's
          // first byte, then to the whitespace before it.
          let mut name_start = value_start - 2 // before ="
          while name_start > 0 &&
                run_slice[name_start - 1] != b' ' &&
                run_slice[name_start - 1] != b'\t' &&
                run_slice[name_start - 1] != b'\n' &&
                run_slice[name_start - 1] != b'\r' {
            name_start -= 1
          }
          theme_spans.push((name_start - 1, value_end + 1))
        }
      }
      match val {
        Some((value, value_start, value_end)) =>
          if value != requested {
            edits.push({
              start: value_start,
              end: value_end,
              replacement: requested,
            })
          }
        None =>
          raise Unsupported(
            message="run formatting found a color without a val attribute",
          )
      }
      for span in theme_spans {
        let (start, end) = span
        edits.push({ start, end, replacement: "", })
      }
    }
    None => {
      let offset = rpr_insertion_offset(prefix, "color", children, container)
      edits.push({
        start: offset,
        end: offset,
        replacement: "<\{prefix}:color \{prefix}:val=\"\{requested}\"/>",
      })
    }
  }
}

///|
/// Render a complete fresh `rPr` for the requested properties, in
/// schema order.
fn render_rpr(prefix : String, format : DocxDirectFormat) -> String {
  let builder = StringBuilder()
  builder.write_string("<\{prefix}:rPr>")
  match format.bold {
    Some(true) => builder.write_string("<\{prefix}:b/><\{prefix}:bCs/>")
    Some(false) =>
      builder.write_string(
        "<\{prefix}:b \{prefix}:val=\"0\"/><\{prefix}:bCs \{prefix}:val=\"0\"/>",
      )
    None => ()
  }
  match format.italic {
    Some(true) => builder.write_string("<\{prefix}:i/><\{prefix}:iCs/>")
    Some(false) =>
      builder.write_string(
        "<\{prefix}:i \{prefix}:val=\"0\"/><\{prefix}:iCs \{prefix}:val=\"0\"/>",
      )
    None => ()
  }
  match format.color {
    Some(value) =>
      builder.write_string("<\{prefix}:color \{prefix}:val=\"\{value}\"/>")
    None => ()
  }
  match format.underline {
    Some(value) => {
      let wanted = if value { "single" } else { "none" }
      builder.write_string("<\{prefix}:u \{prefix}:val=\"\{wanted}\"/>")
    }
    None => ()
  }
  builder.write_string("</\{prefix}:rPr>")
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
