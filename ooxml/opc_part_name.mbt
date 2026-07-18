///|
fn opc_ascii_hex_digit(character : UInt16) -> Bool {
  (character >= '0' && character <= '9') ||
  (character >= 'A' && character <= 'F') ||
  (character >= 'a' && character <= 'f')
}

///|
fn opc_ascii_hex_value(character : UInt16) -> Int {
  if character >= '0' && character <= '9' {
    character.to_int() - ('0' : UInt16).to_int()
  } else if character >= 'A' && character <= 'F' {
    character.to_int() - ('A' : UInt16).to_int() + 10
  } else {
    character.to_int() - ('a' : UInt16).to_int() + 10
  }
}

///|
fn opc_percent_byte(text : StringView, index : Int) -> Int? {
  if index + 2 >= text.length() ||
    text[index] != ('%' : UInt16) ||
    !opc_ascii_hex_digit(text[index + 1]) ||
    !opc_ascii_hex_digit(text[index + 2]) {
    None
  } else {
    Some(
      opc_ascii_hex_value(text[index + 1]) * 16 +
      opc_ascii_hex_value(text[index + 2]),
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
fn opc_decode_percent_scalar(
  text : StringView,
  index : Int,
) -> (String, Char, Int)? {
  guard opc_percent_byte(text, index) is Some(first) && first >= 0x80 else {
    return None
  }
  guard opc_utf8_percent_length(first) is Some(length) else { return None }
  let bytes : Array[Byte] = []
  for ordinal in 0..<length {
    guard opc_percent_byte(text, index + ordinal * 3) is Some(value) else {
      return None
    }
    bytes.push(value.to_byte())
  }
  let decoded = @utf8.decode(Bytes::from_array(bytes)) catch {
    _ => return None
  }
  guard decoded.get_char(0) is Some(decoded_character) else { return None }
  let decoded_width = if decoded_character.to_int() > 0xffff { 2 } else { 1 }
  guard decoded_width == decoded.length() else { return None }
  Some((decoded, decoded_character, index + length * 3))
}

///|
fn is_valid_opc_part_segment_cancellable_impl(
  segment : StringView,
  cancelled : () -> Bool,
) -> Bool raise ParseXmlError {
  if segment == "" || segment.has_suffix(".") {
    return false
  }
  let mut index = 0
  let mut next_checkpoint = 0
  while index < segment.length() {
    if index >= next_checkpoint {
      if cancelled() {
        raise ReadCancelled
      }
      next_checkpoint = index + 4096
    }
    guard segment.get_char(index) is Some(character) else { return false }
    if character == '%' {
      guard opc_percent_byte(segment, index) is Some(decoded) else {
        return false
      }
      if decoded == 0x2f || decoded == 0x5c || opc_uri_unreserved_byte(decoded) {
        return false
      }
      if decoded >= 0x80 {
        match opc_decode_percent_scalar(segment, index) {
          Some((_, scalar, next)) => {
            if opc_iri_ucschar(scalar) {
              return false
            }
            index = next
          }
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
      index = index + (if character.to_int() > 0xffff { 2 } else { 1 })
    }
  }
  true
}

///|
/// Reports whether one logical OPC PartName segment is canonical under the
/// RFC 3987 mapping required by ECMA-376 Part 2.
pub fn is_valid_opc_part_segment(segment : StringView) -> Bool {
  try! is_valid_opc_part_segment_cancellable_impl(segment, () => false)
}

///|
/// Maps an ASCII physical ZIP item name to its logical OPC PartName. Literal
/// non-ASCII IRI scalars are restored from their canonical UTF-8 `%HH`
/// projection; opaque legal percent escapes remain unchanged.
pub fn logical_opc_part_name_from_zip_item_name(name : StringView) -> String? {
  try! logical_opc_part_name_from_zip_item_name_cancellable(name)
}

///|
/// Cancellation-aware form of `logical_opc_part_name_from_zip_item_name`.
/// It scans directly over the input view and does not copy the whole physical
/// name into an intermediate character array.
pub fn logical_opc_part_name_from_zip_item_name_cancellable(
  name : StringView,
  cancelled? : () -> Bool = () => false,
) -> String? raise ParseXmlError {
  if name == "" || name.has_prefix("/") || name.has_suffix("/") {
    return None
  }
  if cancelled() {
    raise ReadCancelled
  }
  let output = StringBuilder::new(size_hint=name.length())
  let mut index = 0
  let mut next_checkpoint = 0
  while index < name.length() {
    if index >= next_checkpoint {
      if cancelled() {
        raise ReadCancelled
      }
      next_checkpoint = index + 4096
    }
    let unit = name[index]
    guard unit.to_char() is Some(character) && character.is_ascii() else {
      return None
    }
    if character == '%' {
      guard opc_percent_byte(name, index) is Some(decoded) else { return None }
      if decoded >= 0x80 {
        match opc_decode_percent_scalar(name, index) {
          Some((scalar_text, scalar, next)) if opc_iri_ucschar(scalar) => {
            output.write_string(scalar_text)
            index = next
          }
          _ => {
            output.write_char(character)
            output.write_char(name[index + 1].to_char().unwrap())
            output.write_char(name[index + 2].to_char().unwrap())
            index = index + 3
          }
        }
      } else {
        output.write_char(character)
        output.write_char(name[index + 1].to_char().unwrap())
        output.write_char(name[index + 2].to_char().unwrap())
        index = index + 3
      }
    } else {
      output.write_char(character)
      index = index + 1
    }
  }
  let logical = output.to_string()
  for segment in logical.split("/") {
    if !is_valid_opc_part_segment_cancellable_impl(segment, cancelled) {
      return None
    }
  }
  Some(logical)
}

///|
fn opc_part_name_identity_unit(unit : UInt16) -> UInt16 {
  if unit >= ('A' : UInt16) && unit <= ('Z' : UInt16) {
    (unit.to_int() + 32).to_uint16()
  } else {
    unit
  }
}

///|
type OpcPartNameChildren = @sorted_map.SortedMap[UInt16, Int]

///|
priv struct OpcPartNameTrieNode {
  mut terminal : String?
  mut first_part : String?
  children : OpcPartNameChildren
}

///|
fn new_opc_part_name_trie_node() -> OpcPartNameTrieNode {
  { terminal: None, first_part: None, children: SortedMap([]) }
}

///|
/// The collision reported while registering a logical OPC PartName.
pub(all) enum OpcPartNameConflict {
  Equivalent(String)
  Derivable(String)
}

///|
/// A UTF-16 code-unit trie for OPC PartName identity and non-derivability checks.
/// Work and storage are linear in aggregate PartName length, while ordered
/// scalar child indexes avoid repeated comparisons of attacker-controlled
/// string prefixes and keep hostile names independent of string-hash behavior.
pub struct OpcPartNameRegistry {
  priv nodes : Array[OpcPartNameTrieNode]
}

///|
/// Creates an empty OPC PartName registry.
pub fn OpcPartNameRegistry::new() -> OpcPartNameRegistry {
  { nodes: [new_opc_part_name_trie_node()] }
}

///|
/// Registers `name`, using `display` in any returned conflict. Identity is
/// ASCII-case-insensitive and a name conflicts when either side is derivable
/// from the other by appending one or more path segments.
pub fn OpcPartNameRegistry::register(
  self : OpcPartNameRegistry,
  name : StringView,
  display : String,
) -> OpcPartNameConflict? {
  try! self.register_cancellable(name, display)
}

///|
/// Cancellation-aware form of `register`. Rejected or cancelled registrations
/// never link a partial path into the registry.
pub fn OpcPartNameRegistry::register_cancellable(
  self : OpcPartNameRegistry,
  name : StringView,
  display : String,
  cancelled? : () -> Bool = () => false,
) -> OpcPartNameConflict? raise ParseXmlError {
  if cancelled() {
    raise ReadCancelled
  }
  let mut node_index = 0
  let mut index = 0
  let mut missing_index : Int? = None
  while index < name.length() {
    if index % 4096 == 0 && cancelled() {
      raise ReadCancelled
    }
    let unit = opc_part_name_identity_unit(name[index])
    if unit == ('/' : UInt16) {
      match self.nodes[node_index].terminal {
        Some(existing) => return Some(Derivable(existing))
        None => ()
      }
    }
    match self.nodes[node_index].children.get(unit) {
      Some(child) => node_index = child
      None => {
        missing_index = Some(index)
        break
      }
    }
    index = index + 1
  }
  if missing_index is None {
    match self.nodes[node_index].terminal {
      Some(existing) => return Some(Equivalent(existing))
      None => ()
    }
    match
      self.nodes[node_index].children
      .get('/')
      .map(child => self.nodes[child].first_part) {
      Some(Some(existing)) => return Some(Derivable(existing))
      _ => ()
    }
  }

  match missing_index {
    None => {
      if cancelled() {
        raise ReadCancelled
      }
      self.nodes[node_index].terminal = Some(display)
    }
    Some(start) => {
      // Construct the missing suffix off-registry. Only after every allocation
      // and cancellation point succeeds do we append and link it once.
      let base = self.nodes.length()
      let detached : Array[OpcPartNameTrieNode] = []
      for offset in start..<name.length() {
        if offset % 4096 == 0 && cancelled() {
          raise ReadCancelled
        }
        let fresh = new_opc_part_name_trie_node()
        fresh.first_part = Some(display)
        if offset + 1 < name.length() {
          fresh.children[opc_part_name_identity_unit(name[offset + 1])] = base +
            offset -
            start +
            1
        } else {
          fresh.terminal = Some(display)
        }
        detached.push(fresh)
      }
      if cancelled() {
        raise ReadCancelled
      }
      for node in detached {
        self.nodes.push(node)
      }
      self.nodes[node_index].children[opc_part_name_identity_unit(name[start])] = base
    }
  }
  if self.nodes[0].first_part is None {
    self.nodes[0].first_part = Some(display)
  }
  None
}

///|
test "OPC physical names restore Unicode logical identity" {
  debug_inspect(
    logical_opc_part_name_from_zip_item_name("custom/%E6%96%87.xml"),
    content="Some(\"custom/文.xml\")",
  )
  debug_inspect(
    logical_opc_part_name_from_zip_item_name("custom/文.xml"),
    content="None",
  )
}

///|
test "OPC PartName registry rejects equivalent and derivable identities" {
  let registry = OpcPartNameRegistry::new()
  assert_true(registry.register("custom/a.xml", "custom/a.xml") is None)
  match registry.register("CUSTOM/A.XML", "CUSTOM/A.XML") {
    Some(Equivalent(existing)) => inspect(existing, content="custom/a.xml")
    _ => fail("expected equivalent OPC PartName")
  }
  match registry.register("custom/a.xml/child.xml", "custom/a.xml/child.xml") {
    Some(Derivable(existing)) => inspect(existing, content="custom/a.xml")
    _ => fail("expected descendant OPC PartName conflict")
  }

  let descendant_first = OpcPartNameRegistry::new()
  assert_true(
    descendant_first.register(
      "custom/a.xml/child.xml", "custom/a.xml/child.xml",
    )
    is None,
  )
  match descendant_first.register("custom/a.xml", "custom/a.xml") {
    Some(Derivable(existing)) =>
      inspect(existing, content="custom/a.xml/child.xml")
    _ => fail("expected ancestor OPC PartName conflict")
  }

  let sibling = OpcPartNameRegistry::new()
  assert_true(sibling.register("custom/a.xmlx", "custom/a.xmlx") is None)
  assert_true(sibling.register("custom/a.xml", "custom/a.xml") is None)
}

///|
test "cancelled OPC PartName registration does not link a partial path" {
  let registry = OpcPartNameRegistry::new()
  let checks = [0]
  let long_name = "custom/a.xml/" + "child/".repeat(2000) + "part.xml"
  try
    registry.register_cancellable(long_name, long_name, cancelled=() => {
      checks[0] = checks[0] + 1
      checks[0] >= 3
    })
  catch {
    ReadCancelled => assert_true(checks[0] >= 3)
    _ => fail("unexpected OPC PartName registration error")
  } noraise {
    _ => fail("expected OPC PartName registration cancellation")
  }
  assert_true(registry.register("custom/a.xml", "custom/a.xml") is None)
}
