// N0 — the per-physical-w:p projection→source TOKEN MAP, the one hard
// primitive of Phase 3 (preservation-safe content editing). This file is the
// lexical layer: it tokenizes a w:t element's raw content bytes into source
// tokens whose byte extents map projection characters back to document.xml, so
// surgery can splice on exact scalar boundaries and refuse where a raw edit
// would be wrong (CDATA, entity interiors). Everything here is
// package-private; N0 exposes only what N1/N2 need once the oracle is green.
//
// The reader's per-paragraph projection (DocumentElement::to_raw_text) is the
// authoritative ORACLE this map must reproduce byte-for-byte (modulo the
// paragraph separator). There is NO XML byte-offset tokenizer to reuse
// (docx2html/xml is tree-only, offsets discarded), so N0 does its own byte
// scan in the style of the annotation scanner.

///|
/// The lexical kind of a source token backing a stretch of w:t projection.
/// The kind decides where a mutation boundary may fall:
/// - `RawText`: any scalar (UTF-8 character) boundary is a valid split point;
/// - `EntityRef` / `NumericCharRef`: the token is atomic — a boundary may fall
///   only at its edges, never inside (splitting `&amp;` is corruption);
/// - `CData`: mutation is refused in v1 (escaped insertions inside CDATA are
///   wrong and splitting `]]>` is a trap).
priv enum SourceTokenKind {
  RawText
  EntityRef
  NumericCharRef
  CData
} derive(Eq, Show, @debug.Debug)

///|
/// One lexical source token inside a single w:t element's content.
/// `byte_start`/`byte_end` are absolute offsets into the story part bytes
/// ([byte_start, byte_end) is the token's exact source span, including any
/// `&`/`;`/`<![CDATA[`/`]]>` framing); `projection` is the decoded text this
/// token contributes to the paragraph projection.
priv struct SourceToken {
  kind : SourceTokenKind
  byte_start : Int
  byte_end : Int
  projection : String
} derive(Eq, Show, @debug.Debug)

///|
/// A refusal raised while building the N0 token map (malformed entity, CDATA,
/// or non-UTF-8 content). Kept distinct from DocxError so a token-map failure
/// is classified as a fail-closed refusal, never a silent skip.
priv suberror TokenMapError {
  TokenMapError(String)
} derive(Show)

///|
/// True when the ASCII `literal` occurs at `at` in `part`.
fn bytes_start_with(part : BytesView, at : Int, literal : String) -> Bool {
  let n = literal.length()
  if at + n > part.length() {
    return false
  }
  for i in 0..<n {
    if part[at + i].to_int() != literal.unsafe_charcode_at(i) {
      return false
    }
  }
  true
}

///|
/// Decodes one entity/character reference beginning at `&` (index `at`).
/// Returns (projected text, kind, byte index just past the closing `;`).
/// Named refs are limited to the five XML built-ins; numeric refs are decimal
/// or hex. Malformed or unknown references refuse.
fn decode_entity_token(
  part : BytesView,
  at : Int,
  content_end : Int,
) -> (String, SourceTokenKind, Int) raise TokenMapError {
  // Find the terminating ';' within a bounded window (named) or the digit run
  // (numeric can be zero-padded, but stays bounded by content_end).
  let numeric = at + 1 < content_end && part[at + 1].to_int() == '#'.to_int()
  let mut semi = -1
  let mut probe = at + 1
  let limit = if numeric { content_end } else { min_int(content_end, at + 12) }
  while probe < limit {
    if part[probe].to_int() == ';'.to_int() {
      semi = probe
      break
    }
    probe += 1
  }
  guard semi >= 0 else {
    raise TokenMapError("unterminated entity reference in w:t content")
  }
  let end = semi + 1
  if numeric {
    let mut base = 10
    let mut digits_start = at + 2
    if digits_start < semi &&
      (
        part[digits_start].to_int() == 'x'.to_int() ||
        part[digits_start].to_int() == 'X'.to_int()
      ) {
      base = 16
      digits_start += 1
    }
    guard digits_start < semi else {
      raise TokenMapError("empty numeric character reference in w:t content")
    }
    let mut value = 0
    for i in digits_start..<semi {
      let c = part[i].to_int()
      let digit = if c >= '0'.to_int() && c <= '9'.to_int() {
        c - '0'.to_int()
      } else if base == 16 && c >= 'a'.to_int() && c <= 'f'.to_int() {
        c - 'a'.to_int() + 10
      } else if base == 16 && c >= 'A'.to_int() && c <= 'F'.to_int() {
        c - 'A'.to_int() + 10
      } else {
        raise TokenMapError("invalid digit in numeric character reference")
      }
      value = value * base + digit
      if value > 0x10FFFF {
        raise TokenMapError("numeric character reference out of range")
      }
    }
    guard value.to_char() is Some(ch) else {
      raise TokenMapError("numeric character reference is not a valid scalar")
    }
    return (ch.to_string(), NumericCharRef, end)
  }
  // Named: exactly the five XML built-ins.
  let name = @utf8.decode(part[at + 1:semi]) catch {
    _ => raise TokenMapError("entity reference is not valid UTF-8")
  }
  let decoded = match name {
    "amp" => "&"
    "lt" => "<"
    "gt" => ">"
    "quot" => "\""
    "apos" => "'"
    _ => raise TokenMapError("unsupported named entity '&\{name};'")
  }
  (decoded, EntityRef, end)
}

///|
fn min_int(a : Int, b : Int) -> Int {
  if a < b {
    a
  } else {
    b
  }
}

///|
/// Tokenizes the raw content of one w:t element — the bytes of `part` in
/// [content_start, content_end) — into lexical source tokens whose
/// concatenated projection equals what the reader projects for that w:t.
/// Refuses on malformed entities, malformed CDATA, an unexpected child element
/// (`<` that is not a CDATA section — w:t carries only text), or non-UTF-8.
fn tokenize_wt_content(
  part : BytesView,
  content_start : Int,
  content_end : Int,
) -> Array[SourceToken] raise TokenMapError {
  let tokens : Array[SourceToken] = []
  let mut at = content_start
  let mut raw_start = content_start
  fn flush_raw(upto : Int) -> Unit raise TokenMapError {
    if upto > raw_start {
      let text = @utf8.decode(part[raw_start:upto]) catch {
        _ => raise TokenMapError("w:t content is not valid UTF-8")
      }
      tokens.push({
        kind: RawText,
        byte_start: raw_start,
        byte_end: upto,
        projection: text,
      })
    }
  }

  while at < content_end {
    let byte = part[at].to_int()
    if byte == '&'.to_int() {
      flush_raw(at)
      let (projection, kind, end) = decode_entity_token(part, at, content_end)
      tokens.push({ kind, byte_start: at, byte_end: end, projection })
      at = end
      raw_start = at
    } else if byte == '<'.to_int() {
      guard bytes_start_with(part, at, "<![CDATA[") else {
        raise TokenMapError(
          "unexpected '<' in w:t content (only text and CDATA are allowed)",
        )
      }
      flush_raw(at)
      let inner_start = at + 9
      // Find the terminating ]]> at or after inner_start.
      let mut probe = inner_start
      let mut close = -1
      while probe + 3 <= content_end {
        if part[probe].to_int() == ']'.to_int() &&
          part[probe + 1].to_int() == ']'.to_int() &&
          part[probe + 2].to_int() == '>'.to_int() {
          close = probe
          break
        }
        probe += 1
      }
      guard close >= 0 else {
        raise TokenMapError("unterminated CDATA section in w:t content")
      }
      let inner = @utf8.decode(part[inner_start:close]) catch {
        _ => raise TokenMapError("CDATA content is not valid UTF-8")
      }
      tokens.push({
        kind: CData,
        byte_start: at,
        byte_end: close + 3,
        projection: inner,
      })
      at = close + 3
      raw_start = at
    } else {
      at += 1
    }
  }
  flush_raw(content_end)
  tokens
}
