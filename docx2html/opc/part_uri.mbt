///|
fn opc_ascii_hex_digit(character : Char) -> Bool {
  (character >= '0' && character <= '9') ||
  (character >= 'A' && character <= 'F') ||
  (character >= 'a' && character <= 'f')
}

///|
fn opc_ascii_hex_value(character : Char) -> Int {
  if character >= '0' && character <= '9' {
    character.to_int() - '0'.to_int()
  } else if character >= 'A' && character <= 'F' {
    character.to_int() - 'A'.to_int() + 10
  } else {
    character.to_int() - 'a'.to_int() + 10
  }
}

///|
fn opc_percent_byte(characters : ArrayView[Char], index : Int) -> Int? {
  if index + 2 >= characters.length() ||
    characters[index] != '%' ||
    !opc_ascii_hex_digit(characters[index + 1]) ||
    !opc_ascii_hex_digit(characters[index + 2]) {
    None
  } else {
    Some(
      opc_ascii_hex_value(characters[index + 1]) * 16 +
      opc_ascii_hex_value(characters[index + 2]),
    )
  }
}

///|
fn opc_uri_unreserved(character : Char) -> Bool {
  character.is_ascii_alphabetic() ||
  character.is_ascii_digit() ||
  character == '-' ||
  character == '.' ||
  character == '_' ||
  character == '~'
}

///|
fn opc_uri_unreserved_byte(value : Int) -> Bool {
  (value >= 'A'.to_int() && value <= 'Z'.to_int()) ||
  (value >= 'a'.to_int() && value <= 'z'.to_int()) ||
  (value >= '0'.to_int() && value <= '9'.to_int()) ||
  value == '-'.to_int() ||
  value == '.'.to_int() ||
  value == '_'.to_int() ||
  value == '~'.to_int()
}

///|
fn opc_uri_sub_delimiter(character : Char) -> Bool {
  character == '!' ||
  character == '$' ||
  character == '&' ||
  character.to_int() == 0x27 ||
  character == '(' ||
  character == ')' ||
  character == '*' ||
  character == '+' ||
  character == ',' ||
  character == ';' ||
  character == '='
}

///|
/// RFC 3987 `ucschar`. Private-use characters are deliberately absent: the
/// IRI path grammar permits `ucschar`, while `iprivate` is query-only.
fn opc_iri_ucschar(character : Char) -> Bool {
  let value = character.to_int()
  (value >= 0x00a0 && value <= 0xd7ff) ||
  (value >= 0xf900 && value <= 0xfdcf) ||
  (value >= 0xfdf0 && value <= 0xffef) ||
  (value >= 0x10000 && value <= 0x1fffd) ||
  (value >= 0x20000 && value <= 0x2fffd) ||
  (value >= 0x30000 && value <= 0x3fffd) ||
  (value >= 0x40000 && value <= 0x4fffd) ||
  (value >= 0x50000 && value <= 0x5fffd) ||
  (value >= 0x60000 && value <= 0x6fffd) ||
  (value >= 0x70000 && value <= 0x7fffd) ||
  (value >= 0x80000 && value <= 0x8fffd) ||
  (value >= 0x90000 && value <= 0x9fffd) ||
  (value >= 0xa0000 && value <= 0xafffd) ||
  (value >= 0xb0000 && value <= 0xbfffd) ||
  (value >= 0xc0000 && value <= 0xcfffd) ||
  (value >= 0xd0000 && value <= 0xdfffd) ||
  (value >= 0xe1000 && value <= 0xefffd)
}

///|
fn opc_utf8_percent_length(first : Int) -> Int? {
  if first >= 0xc2 && first <= 0xdf {
    Some(2)
  } else if first >= 0xe0 && first <= 0xef {
    Some(3)
  } else if first >= 0xf0 && first <= 0xf4 {
    Some(4)
  } else {
    None
  }
}

///|
/// Decodes exactly one non-ASCII scalar represented as adjacent `%HH` UTF-8
/// octets. Strict UTF-8 decoding rejects overlong encodings, surrogates, and
/// out-of-range scalars before they reach path normalization.
fn opc_decode_percent_scalar(
  characters : ArrayView[Char],
  index : Int,
) -> (String, Char, Int)? {
  guard opc_percent_byte(characters, index) is Some(first) && first >= 0x80 else {
    return None
  }
  guard opc_utf8_percent_length(first) is Some(length) else { return None }
  let bytes : Array[Byte] = []
  for ordinal in 0..<length {
    guard opc_percent_byte(characters, index + ordinal * 3) is Some(value) else {
      return None
    }
    bytes.push(value.to_byte())
  }
  let decoded = @utf8.decode(Bytes::from_array(bytes)) catch {
    _ => return None
  }
  let decoded_characters = decoded.to_array()
  guard decoded_characters.length() == 1 else { return None }
  Some((decoded, decoded_characters[0], index + length * 3))
}

///|
/// Reports whether one logical OPC part-name segment is a canonical IRI
/// segment. Literal RFC 3987 `ucschar` values are valid. Percent escapes must
/// be complete, must not encode `/` or `\\`, and must not encode an
/// `iunreserved` character, including a non-ASCII scalar such as `é`.
/// OPC also forbids a segment whose final character is `.`.
pub fn is_valid_part_segment(segment : StringView) -> Bool {
  if segment == "" || segment.has_suffix(".") {
    return false
  }
  let characters = segment.to_array()
  let mut index = 0
  while index < characters.length() {
    let character = characters[index]
    if character == '%' {
      guard opc_percent_byte(characters, index) is Some(decoded) else {
        return false
      }
      if decoded == 0x2f || decoded == 0x5c || opc_uri_unreserved_byte(decoded) {
        return false
      }
      if decoded >= 0x80 {
        match opc_decode_percent_scalar(characters, index) {
          Some((_, scalar, next)) => {
            if opc_iri_ucschar(scalar) {
              return false
            }
            index = next
          }
          // A percent-encoded octet need not itself be UTF-8. It remains a
          // legal IRI `pct-encoded` token, but cannot alias a literal scalar.
          None => index = index + 3
        }
      } else {
        index = index + 3
      }
    } else {
      if !opc_uri_unreserved(character) &&
        !opc_iri_ucschar(character) &&
        !opc_uri_sub_delimiter(character) &&
        character != ':' &&
        character != '@' {
        return false
      }
      index = index + 1
    }
  }
  true
}

///|
/// Returns the OPC logical-identity key. Part and logical-item equivalence is
/// ASCII-case-insensitive only; non-ASCII scalars remain case-sensitive.
pub fn part_name_key(name : StringView) -> String {
  let output = StringBuilder::new(size_hint=name.length())
  for character in name {
    output.write_char(character.to_ascii_lowercase())
  }
  output.to_string()
}

///|
priv struct PartNameTrieNode {
  mut terminal : String?
  mut first_part : String?
  children : StableStringMap[Int]
}

///|
fn new_part_name_trie_node() -> PartNameTrieNode {
  { terminal: None, first_part: None, children: SortedMap([]) }
}

///|
/// The collision reported while registering a logical OPC PartName.
pub(all) enum PartNameConflict {
  Equivalent(String)
  Derivable(String)
}

///|
/// A segment trie for OPC PartName identity and non-derivability checks.
/// Storage and work are linear in aggregate PartName length; in particular,
/// a deeply segmented ZIP name never materializes every growing prefix.
pub struct PartNameRegistry {
  priv nodes : Array[PartNameTrieNode]
}

///|
/// Creates an empty PartName registry.
pub fn PartNameRegistry::new() -> PartNameRegistry {
  { nodes: [new_part_name_trie_node()] }
}

///|
/// Registers `name`, using `display` in any returned conflict. Identity is
/// ASCII-case-insensitive and a name conflicts when either side is derivable
/// from the other by appending one or more path segments.
pub fn PartNameRegistry::register(
  self : PartNameRegistry,
  name : StringView,
  display : String,
) -> PartNameConflict? {
  let key = part_name_key(name)
  let segments = key.split("/").collect()
  let mut node_index = 0
  let mut complete_path = true
  for segment_view in segments {
    match self.nodes[node_index].terminal {
      Some(existing) => return Some(Derivable(existing))
      None => ()
    }
    let segment = segment_view.to_owned()
    match self.nodes[node_index].children.get(segment) {
      Some(child) => node_index = child
      None => {
        complete_path = false
        break
      }
    }
  }
  if complete_path {
    match self.nodes[node_index].terminal {
      Some(existing) => return Some(Equivalent(existing))
      None => ()
    }
    match self.nodes[node_index].first_part {
      Some(existing) => return Some(Derivable(existing))
      None => ()
    }
  }
  // The preflight above is mutation-free, so a conflict can never leave a
  // partial path that poisons later validation findings.
  node_index = 0
  if self.nodes[node_index].first_part is None {
    self.nodes[node_index].first_part = Some(display)
  }
  for segment_view in segments {
    let segment = segment_view.to_owned()
    let child = match self.nodes[node_index].children.get(segment) {
      Some(existing) => existing
      None => {
        let fresh = self.nodes.length()
        self.nodes.push(new_part_name_trie_node())
        self.nodes[node_index].children[segment] = fresh
        fresh
      }
    }
    node_index = child
    if self.nodes[node_index].first_part is None {
      self.nodes[node_index].first_part = Some(display)
    }
  }
  self.nodes[node_index].terminal = Some(display)
  None
}

///|
/// Returns the logical Relationships-part name for a package-root or part
/// source. Earlier `_rels` path segments remain ordinary source-name segments.
pub fn relationships_part_name_for_source(source : String) -> String {
  if source == "" {
    "_rels/.rels"
  } else {
    match source.rev_find("/") {
      Some(slash) => "\{source[:slash]}/_rels/\{source[slash + 1:]}.rels"
      None => "_rels/\{source}.rels"
    }
  }
}

///|
/// Returns whether the last two path segments have the reserved OPC
/// Relationships-part shape. A `.rels` suffix elsewhere is an ordinary part.
pub fn is_relationship_part_name(name : String) -> Bool {
  let segments = name.split("/").collect()
  segments.length() >= 2 &&
  part_name_key(segments[segments.length() - 2]) == "_rels" &&
  part_name_key(segments[segments.length() - 1]).has_suffix(".rels")
}

///|
/// Derives the package-root or part source represented by a Relationships-part
/// name. Only the final `_rels/<filename>.rels` pair is structural; earlier
/// `_rels` segments belong to the source PartName.
pub fn relationship_source_part_name(name : String) -> String? {
  if part_name_key(name) == "_rels/.rels" {
    return Some("")
  }
  if !is_relationship_part_name(name) {
    return None
  }
  let segments = name.split("/").collect()
  let filename = segments[segments.length() - 1]
  if filename.length() <= ".rels".length() {
    return None
  }
  let source_name = filename[:filename.length() - ".rels".length()].to_owned()
  let output = StringBuilder::new(size_hint=name.length())
  for index in 0..<(segments.length() - 2) {
    if index > 0 {
      output.write_char('/') |> ignore
    }
    output.write_string(segments[index].to_owned()) |> ignore
  }
  if segments.length() > 2 {
    output.write_char('/') |> ignore
  }
  output.write_string(source_name) |> ignore
  Some(output.to_string())
}

///|
/// Maps an ASCII ZIP item name to its logical OPC part name (without the
/// leading slash used by the abstract syntax). Physical ZIP names percent-
/// encode non-ASCII scalars; logical part names contain those scalars
/// literally. Returns `None` for directory records, reserved metadata, and
/// physical names that do not map to a canonical part name.
pub fn logical_part_name_from_zip_item_name(name : StringView) -> String? {
  if name == "" || name.has_prefix("/") || name.has_suffix("/") {
    return None
  }
  let characters = name.to_array()
  let output = StringBuilder::new(size_hint=name.length())
  let mut index = 0
  while index < characters.length() {
    let character = characters[index]
    if !character.is_ascii() {
      // ECMA-376 Part 2, 7.3.3 requires ASCII ZIP item names.
      return None
    }
    if character == '%' {
      guard opc_percent_byte(characters, index) is Some(decoded) else {
        return None
      }
      if decoded >= 0x80 {
        match opc_decode_percent_scalar(characters, index) {
          Some((scalar_text, scalar, next)) if opc_iri_ucschar(scalar) => {
            // Literal IRI path scalars are percent-encoded only by the
            // physical ZIP projection, so restore their logical spelling.
            output.write_string(scalar_text)
            index = next
          }
          _ => {
            // A legal pct-encoded token need not be UTF-8 (for example %FF),
            // and valid UTF-8 may represent a scalar that is not legal
            // literally in an IRI path (for example U+0080). Such escapes are
            // part of the logical name itself and must round-trip unchanged.
            output.write_char(characters[index])
            output.write_char(characters[index + 1])
            output.write_char(characters[index + 2])
            index = index + 3
          }
        }
      } else {
        output.write_char(characters[index])
        output.write_char(characters[index + 1])
        output.write_char(characters[index + 2])
        index = index + 3
      }
    } else {
      output.write_char(character)
      index = index + 1
    }
  }
  let logical = output.to_string()
  for segment in logical.split("/") {
    if !is_valid_part_segment(segment) {
      return None
    }
  }
  Some(logical)
}

///|
/// Maps a canonical logical OPC part name (without its leading slash) to the
/// ASCII ZIP item spelling required by ECMA-376. Existing legal percent
/// escapes remain intact; every literal non-ASCII scalar is UTF-8 percent-
/// encoded with uppercase hexadecimal digits.
pub fn zip_item_name_from_logical_part_name(name : StringView) -> String? {
  if name == "" || name.has_prefix("/") || name.has_suffix("/") {
    return None
  }
  for segment in name.split("/") {
    if !is_valid_part_segment(segment) {
      return None
    }
  }
  let digits = "0123456789ABCDEF".to_array()
  let output = StringBuilder::new(size_hint=name.length())
  for character in name {
    if character.is_ascii() {
      output.write_char(character)
    } else {
      for byte in @utf8.encode(character.to_string()) {
        let value = byte.to_int()
        output.write_char('%')
        output.write_char(digits[value / 16])
        output.write_char(digits[value % 16])
      }
    }
  }
  Some(output.to_string())
}

///|
/// Resolves an internal OPC relationship target and rejects any result that
/// is not a canonical logical PartName. This boundary deliberately operates
/// on IRIs, not physical ZIP item names.
pub fn resolve_part_target(base : String, target : StringView) -> String? {
  guard resolve_target(base, target.to_owned()) is Some(normalized) else {
    return None
  }
  for segment in normalized.split("/") {
    if !is_valid_part_segment(segment) {
      return None
    }
  }
  Some(normalized)
}
