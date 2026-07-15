// RFC 3986 URI and RFC 3987 IRI grammar shared by relationship validation
// and package construction. Relationship Types are absolute URIs without a
// fragment; External Targets are IRI references. Microsoft Office also emits
// the documented legacy `file:///C:\\...` and UNC spellings, so those are
// accepted as a narrow compatibility extension for External Targets only.

///|
fn relationship_uri_pchar(character : Char) -> Bool {
  opc_uri_unreserved(character) ||
  opc_uri_sub_delimiter(character) ||
  character == ':' ||
  character == '@'
}

///|
fn relationship_uri_query_or_fragment_char(character : Char) -> Bool {
  relationship_uri_pchar(character) || character == '/' || character == '?'
}

///|
fn relationship_uri_userinfo_char(character : Char) -> Bool {
  opc_uri_unreserved(character) ||
  opc_uri_sub_delimiter(character) ||
  character == ':'
}

///|
fn relationship_uri_reg_name_char(character : Char) -> Bool {
  opc_uri_unreserved(character) || opc_uri_sub_delimiter(character)
}

///|
fn relationship_iri_private(character : Char) -> Bool {
  let value = character.to_int()
  (value >= 0xe000 && value <= 0xf8ff) ||
  (value >= 0xf0000 && value <= 0xffffd) ||
  (value >= 0x100000 && value <= 0x10fffd)
}

///|
fn relationship_iri_unreserved(character : Char) -> Bool {
  opc_uri_unreserved(character) || opc_iri_ucschar(character)
}

///|
fn relationship_iri_pchar(character : Char) -> Bool {
  relationship_iri_unreserved(character) ||
  opc_uri_sub_delimiter(character) ||
  character == ':' ||
  character == '@'
}

///|
fn relationship_iri_query_char(character : Char) -> Bool {
  relationship_iri_pchar(character) ||
  relationship_iri_private(character) ||
  character == '/' ||
  character == '?'
}

///|
fn relationship_iri_fragment_char(character : Char) -> Bool {
  relationship_iri_pchar(character) || character == '/' || character == '?'
}

///|
fn relationship_iri_userinfo_char(character : Char) -> Bool {
  relationship_iri_unreserved(character) ||
  opc_uri_sub_delimiter(character) ||
  character == ':'
}

///|
fn relationship_iri_reg_name_char(character : Char) -> Bool {
  relationship_iri_unreserved(character) || opc_uri_sub_delimiter(character)
}

///|
fn relationship_identifier_chars_valid(
  characters : ArrayView[Char],
  start : Int,
  end : Int,
  allowed : (Char) -> Bool,
) -> Bool {
  let mut index = start
  while index < end {
    if characters[index] == '%' {
      if index + 2 >= end ||
        !opc_ascii_hex_digit(characters[index + 1]) ||
        !opc_ascii_hex_digit(characters[index + 2]) {
        return false
      }
      index = index + 3
    } else {
      if !allowed(characters[index]) {
        return false
      }
      index = index + 1
    }
  }
  true
}

///|
fn relationship_ipv4_literal_valid(
  characters : ArrayView[Char],
  start : Int,
  end : Int,
) -> Bool {
  let mut index = start
  let mut components = 0
  while index < end {
    if components == 4 {
      return false
    }
    let component_start = index
    let mut value = 0
    while index < end && characters[index].is_ascii_digit() {
      value = value * 10 + characters[index].to_int() - '0'.to_int()
      index = index + 1
    }
    let digits = index - component_start
    if digits == 0 ||
      digits > 3 ||
      value > 255 ||
      (digits > 1 && characters[component_start] == '0') {
      return false
    }
    components = components + 1
    if index == end {
      break
    }
    if characters[index] != '.' {
      return false
    }
    index = index + 1
  }
  components == 4
}

///|
// RFC 3986 IP-literal validation. A compressed `::` must replace at least
// one 16-bit group; an IPv4 tail occupies the final two groups.
fn relationship_ipv6_literal_valid(
  characters : ArrayView[Char],
  start : Int,
  end : Int,
) -> Bool {
  if start >= end {
    return false
  }
  let mut index = start
  let mut groups = 0
  let mut compressed = false
  if characters[index] == ':' {
    if index + 1 >= end || characters[index + 1] != ':' {
      return false
    }
    compressed = true
    index = index + 2
    if index == end {
      return true
    }
  }
  while index < end {
    let group_start = index
    let mut has_dot = false
    while index < end && characters[index] != ':' {
      if characters[index] == '.' {
        has_dot = true
      }
      index = index + 1
    }
    if has_dot {
      if index != end ||
        !relationship_ipv4_literal_valid(characters, group_start, end) {
        return false
      }
      groups = groups + 2
    } else {
      let digits = index - group_start
      if digits == 0 || digits > 4 {
        return false
      }
      for digit_index = group_start
          digit_index < index
          digit_index = digit_index + 1 {
        if !opc_ascii_hex_digit(characters[digit_index]) {
          return false
        }
      }
      groups = groups + 1
    }
    if index == end {
      break
    }
    if index + 1 < end && characters[index + 1] == ':' {
      if compressed {
        return false
      }
      compressed = true
      index = index + 2
      if index == end {
        break
      }
    } else {
      index = index + 1
      if index == end {
        return false
      }
    }
  }
  if compressed {
    groups < 8
  } else {
    groups == 8
  }
}

///|
fn relationship_ipv_future_literal_valid(
  characters : ArrayView[Char],
  start : Int,
  end : Int,
) -> Bool {
  if start >= end || (characters[start] != 'v' && characters[start] != 'V') {
    return false
  }
  let mut index = start + 1
  let version_start = index
  while index < end && opc_ascii_hex_digit(characters[index]) {
    index = index + 1
  }
  if index == version_start || index >= end || characters[index] != '.' {
    return false
  }
  index = index + 1
  let address_start = index
  while index < end &&
        (
          opc_uri_unreserved(characters[index]) ||
          opc_uri_sub_delimiter(characters[index]) ||
          characters[index] == ':'
        ) {
    index = index + 1
  }
  index == end && index > address_start
}

///|
fn relationship_uri_authority_valid(
  characters : ArrayView[Char],
  start : Int,
  end : Int,
  allow_iri_characters : Bool,
) -> Bool {
  let mut host_start = start
  let mut userinfo_at = -1
  for index = start; index < end; index = index + 1 {
    if characters[index] == '@' {
      if userinfo_at >= 0 {
        return false
      }
      userinfo_at = index
    }
  }
  if userinfo_at >= 0 {
    let valid_userinfo = if allow_iri_characters {
      relationship_identifier_chars_valid(
        characters, start, userinfo_at, relationship_iri_userinfo_char,
      )
    } else {
      relationship_identifier_chars_valid(
        characters, start, userinfo_at, relationship_uri_userinfo_char,
      )
    }
    if !valid_userinfo {
      return false
    }
    host_start = userinfo_at + 1
  }
  if host_start < end && characters[host_start] == '[' {
    let mut close = -1
    for index = host_start + 1; index < end; index = index + 1 {
      if characters[index] == ']' {
        close = index
        break
      }
    }
    if close < 0 ||
      (
        !relationship_ipv6_literal_valid(characters, host_start + 1, close) &&
        !relationship_ipv_future_literal_valid(
          characters,
          host_start + 1,
          close,
        )
      ) {
      return false
    }
    if close + 1 == end {
      return true
    }
    if characters[close + 1] != ':' {
      return false
    }
    for index = close + 2; index < end; index = index + 1 {
      if !characters[index].is_ascii_digit() {
        return false
      }
    }
    return true
  }
  let mut port_at = -1
  for index = host_start; index < end; index = index + 1 {
    if characters[index] == ':' {
      if port_at >= 0 {
        return false
      }
      port_at = index
    } else if characters[index] == '[' || characters[index] == ']' {
      return false
    }
  }
  let host_end = if port_at >= 0 { port_at } else { end }
  let valid_reg_name = if allow_iri_characters {
    relationship_identifier_chars_valid(
      characters, host_start, host_end, relationship_iri_reg_name_char,
    )
  } else {
    relationship_identifier_chars_valid(
      characters, host_start, host_end, relationship_uri_reg_name_char,
    )
  }
  if !valid_reg_name {
    return false
  }
  if port_at >= 0 {
    for index = port_at + 1; index < end; index = index + 1 {
      if !characters[index].is_ascii_digit() {
        return false
      }
    }
  }
  true
}

///|
fn relationship_uri_scheme_valid(
  characters : ArrayView[Char],
  start : Int,
  end : Int,
) -> Bool {
  if start >= end || !characters[start].is_ascii_alphabetic() {
    return false
  }
  for index = start + 1; index < end; index = index + 1 {
    let character = characters[index]
    if !character.is_ascii_alphabetic() &&
      !character.is_ascii_digit() &&
      character != '+' &&
      character != '-' &&
      character != '.' {
      return false
    }
  }
  true
}

///|
// RFC 3986 URI references and RFC 3987 IRI references share a component
// structure. IRI mode additionally permits `ucschar` in the specified
// components and `iprivate` in the query only.
fn relationship_identifier_reference_valid(
  value : StringView,
  allow_iri_characters : Bool,
) -> Bool {
  if value == "" {
    return false
  }
  let characters = value.to_array()
  let mut query_at = characters.length()
  let mut fragment_at = characters.length()
  for index, character in characters {
    if character == '#' {
      if fragment_at < characters.length() {
        return false
      }
      fragment_at = index
    } else if character == '?' &&
      query_at == characters.length() &&
      fragment_at == characters.length() {
      query_at = index
    }
  }
  let hierarchy_end = if query_at < fragment_at {
    query_at
  } else {
    fragment_at
  }
  let mut scheme_at = -1
  for index = 0; index < hierarchy_end; index = index + 1 {
    if characters[index] == ':' {
      scheme_at = index
      break
    }
    if characters[index] == '/' {
      break
    }
  }
  let mut path_start = 0
  if scheme_at >= 0 {
    if !relationship_uri_scheme_valid(characters, 0, scheme_at) {
      return false
    }
    path_start = scheme_at + 1
  }
  if path_start + 1 < hierarchy_end &&
    characters[path_start] == '/' &&
    characters[path_start + 1] == '/' {
    let authority_start = path_start + 2
    let mut authority_end = authority_start
    while authority_end < hierarchy_end && characters[authority_end] != '/' {
      authority_end = authority_end + 1
    }
    if !relationship_uri_authority_valid(
        characters, authority_start, authority_end, allow_iri_characters,
      ) {
      return false
    }
    path_start = authority_end
  }
  let valid_path = if allow_iri_characters {
    relationship_identifier_chars_valid(characters, path_start, hierarchy_end, fn(
      character,
    ) {
      relationship_iri_pchar(character) || character == '/'
    })
  } else {
    relationship_identifier_chars_valid(characters, path_start, hierarchy_end, fn(
      character,
    ) {
      relationship_uri_pchar(character) || character == '/'
    })
  }
  if !valid_path {
    return false
  }
  if query_at < characters.length() {
    let valid_query = if allow_iri_characters {
      relationship_identifier_chars_valid(
        characters,
        query_at + 1,
        fragment_at,
        relationship_iri_query_char,
      )
    } else {
      relationship_identifier_chars_valid(
        characters,
        query_at + 1,
        fragment_at,
        relationship_uri_query_or_fragment_char,
      )
    }
    if !valid_query {
      return false
    }
  }
  if fragment_at < characters.length() {
    let valid_fragment = if allow_iri_characters {
      relationship_identifier_chars_valid(
        characters,
        fragment_at + 1,
        characters.length(),
        relationship_iri_fragment_char,
      )
    } else {
      relationship_identifier_chars_valid(
        characters,
        fragment_at + 1,
        characters.length(),
        relationship_uri_query_or_fragment_char,
      )
    }
    if !valid_fragment {
      return false
    }
  }
  true
}

///|
fn relationship_has_uri_scheme(value : StringView) -> Bool {
  let characters = value.to_array()
  for index, character in characters {
    if character == ':' {
      return relationship_uri_scheme_valid(characters, 0, index)
    }
    if character == '/' || character == '?' || character == '#' {
      return false
    }
  }
  false
}

///|
fn office_file_path_characters_valid(
  characters : ArrayView[Char],
  start : Int,
  end : Int,
) -> Bool {
  relationship_identifier_chars_valid(characters, start, end, fn(character) {
    relationship_iri_pchar(character) || character == '/' || character == '\\'
  })
}

///|
fn office_unc_path_valid(characters : ArrayView[Char]) -> Bool {
  if characters.length() < 5 || characters[0] != '\\' || characters[1] != '\\' {
    return false
  }
  let mut server_end = 2
  while server_end < characters.length() &&
        characters[server_end] != '\\' &&
        characters[server_end] != '/' {
    server_end = server_end + 1
  }
  if server_end == 2 ||
    server_end == characters.length() ||
    !relationship_identifier_chars_valid(
      characters, 2, server_end, relationship_iri_reg_name_char,
    ) {
    return false
  }
  let share_start = server_end + 1
  let mut share_end = share_start
  while share_end < characters.length() &&
        characters[share_end] != '\\' &&
        characters[share_end] != '/' {
    share_end = share_end + 1
  }
  share_end > share_start &&
  relationship_identifier_chars_valid(
    characters, share_start, share_end, relationship_iri_pchar,
  ) &&
  office_file_path_characters_valid(characters, share_end, characters.length())
}

///|
fn office_windows_file_iri_valid(value : StringView) -> Bool {
  let owned = value.to_owned()
  if !owned.to_lower().has_prefix("file:///") {
    return false
  }
  let characters = owned["file:///".length():].to_array()
  if characters.length() >= 3 &&
    characters[0].is_ascii_alphabetic() &&
    characters[1] == ':' &&
    (characters[2] == '\\' || characters[2] == '/') {
    return office_file_path_characters_valid(characters, 2, characters.length())
  }
  office_unc_path_valid(characters)
}

///|
fn is_absolute_relationship_type(value : StringView) -> Bool {
  relationship_has_uri_scheme(value) &&
  relationship_identifier_reference_valid(value, false) &&
  !value.contains("#")
}

///|
fn is_valid_external_relationship_target(value : StringView) -> Bool {
  relationship_identifier_reference_valid(value, true) ||
  office_windows_file_iri_valid(value)
}
