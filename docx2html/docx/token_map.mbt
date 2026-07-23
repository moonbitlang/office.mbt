// N0 — lexical foundation for the per-physical-w:p projection→source token
// map used by preservation-safe DOCX content editing. This increment maps one
// w:t content range; the paragraph/story walker and edit commands deliberately
// remain for later increments.
//
// Public DOCX reads use the tolerant XML projection, so literal CR/LF bytes are
// retained here. Mutation planning still runs the existing strict identity
// gate first: this scanner therefore refuses constructs that strict XML would
// reject instead of inventing a writable projection for them.

///|
/// Lexical source context for one contiguous slice of w:t projection.
priv enum SourceTokenKind {
  RawText
  EntityRef
  NumericCharRef
  CData
}

///|
/// One source token and the projection interval it produces. Entity tokens are
/// atomic. Raw-text scalar boundaries are resolved lazily from the retained
/// source view so hostile text cannot force one heap object per scalar. CDATA
/// keeps no internal boundary because mutation inside it is refused in v1.
#warnings("-unused_field")
priv struct SourceToken {
  kind : SourceTokenKind
  projection_start : Int
  projection_end : Int
  byte_start : Int
  byte_end : Int
}

///|
/// The lexical map for a single w:t content range.
#warnings("-unused_field")
priv struct WtContentMap {
  source : BytesView
  byte_start : Int
  byte_end : Int
  projection : String
  tokens : Array[SourceToken]
  contains_cdata : Bool
}

///|
/// Caller-owned cumulative retention budget. The future paragraph/story
/// walker passes one budget across every w:t in the source part; keeping it
/// mutable here prevents a per-node reset from multiplying the transaction's
/// memory allowance.
priv struct TokenMapBudget {
  mut source_bytes_left : Int
  mut tokens_left : Int
}

///|
/// A fail-closed refusal while building or consuming a lexical token map.
priv suberror TokenMapError {
  TokenMapError(String)
}

///|
#warnings("-unused_value")
fn token_map_budget(
  max_source_bytes : Int,
  max_tokens : Int,
) -> TokenMapBudget raise TokenMapError {
  guard max_source_bytes >= 0 && max_tokens >= 0 else {
    raise TokenMapError("token-map budget limits must be non-negative")
  }
  { source_bytes_left: max_source_bytes, tokens_left: max_tokens }
}

///|
fn TokenMapBudget::charge_source(
  self : TokenMapBudget,
  bytes : Int,
) -> Unit raise TokenMapError {
  guard bytes >= 0 && bytes <= self.source_bytes_left else {
    raise TokenMapError("w:t source byte budget exceeded")
  }
  self.source_bytes_left -= bytes
}

///|
fn TokenMapBudget::charge_token(
  self : TokenMapBudget,
) -> Unit raise TokenMapError {
  guard self.tokens_left > 0 else {
    raise TokenMapError("w:t token budget exceeded")
  }
  self.tokens_left -= 1
}

///|
/// Resolves one scalar boundary inside a validated raw UTF-8 token without
/// allocating a decoded prefix or retaining a boundary table.
fn raw_byte_offset_at(
  source : BytesView,
  token : SourceToken,
  projection_offset : Int,
) -> Int? {
  let mut at = token.byte_start
  let mut projected = token.projection_start
  while at < token.byte_end {
    if projected == projection_offset {
      return Some(at)
    }
    let lead = source[at].to_int()
    let (byte_width, utf16_width) = if lead <= 0x7F {
      (1, 1)
    } else if lead <= 0xDF {
      (2, 1)
    } else if lead <= 0xEF {
      (3, 1)
    } else {
      (4, 2)
    }
    if projected + utf16_width > projection_offset {
      return None
    }
    at += byte_width
    projected += utf16_width
  }
  if projected == projection_offset {
    Some(at)
  } else {
    None
  }
}

///|
/// Returns the unique source byte offset for a legal projection boundary.
/// Empty source constructs can give one projection offset two byte positions;
/// those ambiguous positions deliberately return None.
#warnings("-unused_value")
fn WtContentMap::byte_offset_at(
  self : WtContentMap,
  projection_offset : Int,
) -> Int? {
  if projection_offset < 0 || projection_offset > self.projection.length() {
    return None
  }
  if self.tokens.length() == 0 {
    return if projection_offset == 0 { Some(self.byte_start) } else { None }
  }
  let length = self.tokens.length()
  let mut low = 0
  let mut high = length
  while low < high {
    let middle = low + (high - low) / 2
    if self.tokens[middle].projection_end < projection_offset {
      low = middle + 1
    } else {
      high = middle
    }
  }
  if low >= length {
    return None
  }
  let token = self.tokens[low]
  if projection_offset < token.projection_start {
    return None
  }
  if token.projection_start == token.projection_end {
    // Empty CDATA contributes no projection but has distinct before/after
    // source positions, so its only projection boundary is ambiguous.
    return None
  }
  if projection_offset == token.projection_start {
    return Some(token.byte_start)
  }
  if projection_offset == token.projection_end {
    return Some(token.byte_end)
  }
  match token.kind {
    RawText => raw_byte_offset_at(self.source, token, projection_offset)
    EntityRef | NumericCharRef | CData => None
  }
}

///|
/// Whether a projection range has scalar/atomic endpoints and does not touch
/// CDATA. This is a lexical precondition only; ancestry restrictions and hard
/// barriers belong to the later paragraph/story walker.
#warnings("-unused_value")
fn WtContentMap::range_is_lexically_mutable(
  self : WtContentMap,
  start : Int,
  end : Int,
) -> Bool {
  if start < 0 ||
    start > end ||
    end > self.projection.length() ||
    self.contains_cdata ||
    self.byte_offset_at(start) is None ||
    self.byte_offset_at(end) is None {
    return false
  }
  true
}

///|
fn is_xml_character_for_token_map(character : Char) -> Bool {
  let code = character.to_int()
  code == 0x9 ||
  code == 0xA ||
  code == 0xD ||
  (code >= 0x20 && code <= 0xD7FF) ||
  (code >= 0xE000 && code <= 0xFFFD) ||
  (code >= 0x10000 && code <= 0x10FFFF)
}

///|
fn utf8_scalar_length(character : Char) -> Int {
  let code = character.to_int()
  if code <= 0x7F {
    1
  } else if code <= 0x7FF {
    2
  } else if code <= 0xFFFF {
    3
  } else {
    4
  }
}

///|
fn bytes_start_with(part : BytesView, at : Int, literal : String) -> Bool {
  let length = literal.length()
  if at < 0 || at + length > part.length() {
    return false
  }
  for offset in 0..<length {
    if part[at + offset].to_int() != literal.unsafe_get(offset).to_int() {
      return false
    }
  }
  true
}

///|
fn token_map_error(message : String) -> TokenMapError {
  TokenMapError(message)
}

///|
/// Decodes one mutation-safe XML reference beginning at `&`. This mirrors the
/// strict gate: only lowercase `x` introduces hexadecimal character refs, and
/// numeric values must be XML 1.0 characters.
fn decode_entity_token(
  part : BytesView,
  at : Int,
  content_end : Int,
) -> (Char, SourceTokenKind, Int) raise TokenMapError {
  let mut semicolon = at + 1
  while semicolon < content_end && part[semicolon] != b';' {
    semicolon += 1
  }
  guard semicolon < content_end else {
    raise token_map_error("unterminated entity reference in w:t content")
  }
  let end = semicolon + 1
  if at + 1 < semicolon && part[at + 1] == b'#' {
    let (base, digits_start) = if at + 2 < semicolon && part[at + 2] == b'x' {
      (16, at + 3)
    } else {
      (10, at + 2)
    }
    guard digits_start < semicolon else {
      raise token_map_error("empty numeric character reference in w:t content")
    }
    let mut value = 0
    for index in digits_start..<semicolon {
      let code = part[index].to_int()
      let digit = if code >= '0'.to_int() && code <= '9'.to_int() {
        code - '0'.to_int()
      } else if base == 16 && code >= 'a'.to_int() && code <= 'f'.to_int() {
        code - 'a'.to_int() + 10
      } else if base == 16 && code >= 'A'.to_int() && code <= 'F'.to_int() {
        code - 'A'.to_int() + 10
      } else {
        raise token_map_error("invalid digit in numeric character reference")
      }
      if value > (0x10FFFF - digit) / base {
        raise token_map_error("numeric character reference out of range")
      }
      value = value * base + digit
    }
    guard value.to_char() is Some(character) &&
      is_xml_character_for_token_map(character) else {
      raise token_map_error(
        "numeric character reference is not an XML character",
      )
    }
    return (character, NumericCharRef, end)
  }
  let name = @utf8.decode(part[at + 1:semicolon]) catch {
    _ => raise token_map_error("entity reference is not valid UTF-8")
  }
  let character = match name {
    "amp" => '&'
    "lt" => '<'
    "gt" => '>'
    "quot" => '"'
    "apos" => '\''
    _ => raise token_map_error("unsupported named entity '&\{name};'")
  }
  (character, EntityRef, end)
}

///|
fn raw_text_token(
  part : BytesView,
  byte_start : Int,
  byte_end : Int,
  projection_start : Int,
) -> (SourceToken, String) raise TokenMapError {
  let projection = @utf8.decode(part[byte_start:byte_end]) catch {
    _ => raise token_map_error("w:t content is not valid UTF-8")
  }
  let mut projection_offset = projection_start
  let mut byte_offset = byte_start
  for character in projection {
    guard is_xml_character_for_token_map(character) else {
      raise token_map_error("w:t content contains an illegal XML character")
    }
    projection_offset += character.utf16_len()
    byte_offset += utf8_scalar_length(character)
  }
  guard byte_offset == byte_end else {
    raise token_map_error("w:t UTF-8 boundary accounting failed")
  }
  (
    {
      kind: RawText,
      projection_start,
      projection_end: projection_offset,
      byte_start,
      byte_end,
    },
    projection,
  )
}

///|
fn append_token(
  tokens : Array[SourceToken],
  projection : StringBuilder,
  token : SourceToken,
  token_projection : String,
) -> Unit {
  tokens.push(token)
  projection.write_string(token_projection)
}

///|
/// Builds the lexical map for raw bytes in [content_start, content_end).
/// Offsets in the result remain absolute in `part`.
#warnings("-unused_value")
fn map_wt_content(
  part : BytesView,
  content_start : Int,
  content_end : Int,
  budget : TokenMapBudget,
) -> WtContentMap raise TokenMapError {
  guard content_start >= 0 &&
    content_end >= content_start &&
    content_end <= part.length() else {
    raise token_map_error("invalid w:t content byte range")
  }
  budget.charge_source(content_end - content_start)
  let tokens : Array[SourceToken] = []
  let projection = StringBuilder()
  let mut projection_offset = 0
  let mut contains_cdata = false
  let mut at = content_start
  let mut raw_start = content_start
  fn flush_raw(upto : Int) -> Unit raise TokenMapError {
    if upto > raw_start {
      budget.charge_token()
      let (token, decoded) = raw_text_token(
        part, raw_start, upto, projection_offset,
      )
      append_token(tokens, projection, token, decoded)
      projection_offset = token.projection_end
    }
  }
  while at < content_end {
    if part[at] == b'&' {
      flush_raw(at)
      budget.charge_token()
      let (character, kind, end) = decode_entity_token(part, at, content_end)
      let token_end = projection_offset + character.utf16_len()
      let token = SourceToken::{
        kind,
        projection_start: projection_offset,
        projection_end: token_end,
        byte_start: at,
        byte_end: end,
      }
      append_token(tokens, projection, token, character.to_string())
      projection_offset = token_end
      at = end
      raw_start = at
    } else if part[at] == b'<' {
      guard bytes_start_with(part, at, "<![CDATA[") else {
        raise token_map_error(
          "unexpected '<' in w:t content (only text and CDATA are allowed)",
        )
      }
      flush_raw(at)
      budget.charge_token()
      let inner_start = at + 9
      let mut close = inner_start
      while close + 3 <= content_end && !bytes_start_with(part, close, "]]>") {
        close += 1
      }
      guard close + 3 <= content_end else {
        raise token_map_error("unterminated CDATA section in w:t content")
      }
      let cdata = @utf8.decode(part[inner_start:close]) catch {
        _ => raise token_map_error("CDATA content is not valid UTF-8")
      }
      for character in cdata {
        guard is_xml_character_for_token_map(character) else {
          raise token_map_error("CDATA contains an illegal XML character")
        }
      }
      let end = close + 3
      let token_end = projection_offset + cdata.length()
      let token = SourceToken::{
        kind: CData,
        projection_start: projection_offset,
        projection_end: token_end,
        byte_start: at,
        byte_end: end,
      }
      append_token(tokens, projection, token, cdata)
      // Any edit in a w:t containing CDATA would either split the CDATA token
      // or create mixed XmlText children that the current reader cannot
      // project. The whole map is therefore immutable, including its edges.
      contains_cdata = true
      projection_offset = token_end
      at = end
      raw_start = at
    } else if part[at] == b']' && bytes_start_with(part, at, "]]>") {
      raise token_map_error("']]>' is not allowed in w:t character data")
    } else {
      at += 1
    }
  }
  flush_raw(content_end)
  let mut cdata_tokens = 0
  for token in tokens {
    if token.kind is CData {
      cdata_tokens += 1
    }
  }
  if cdata_tokens > 0 && tokens.length() > 1 {
    // XmlElement::text (and therefore the current w:t reader) accepts one
    // simple-text child only. Raw/CDATA mixtures or adjacent CDATA sections
    // become multiple XmlText nodes, so there is no canonical read projection.
    raise token_map_error(
      "mixed CDATA/text w:t content has no simple-text reader projection",
    )
  }
  {
    source: part,
    byte_start: content_start,
    byte_end: content_end,
    projection: projection.to_string(),
    tokens,
    contains_cdata,
  }
}
