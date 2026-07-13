///|
let raw_max_package_bytes : Int = 128 * 1024 * 1024

///|
let raw_max_archive_entries : Int = 8192

///|
let raw_max_entry_bytes : Int = 64 * 1024 * 1024

///|
let raw_max_total_uncompressed_bytes : Int = 256 * 1024 * 1024

///|
let raw_max_alias_length = 1024

///|
let raw_max_manifest_records = 16_384

///|
let raw_max_manifest_extension_length = 255

///|
let raw_max_part_name_length = 1024

///|
let raw_max_content_type_length = 1024

///|
let raw_max_relationship_records = 16_384

///|
let raw_max_relationship_id_length = 256

///|
let raw_max_relationship_type_length = 2048

///|
let raw_max_relationship_target_length = 4096

///|
let raw_max_inventory_serialization_bytes : Int = 16 * 1024 * 1024

///|
let raw_max_aliases_total = 16_384

///|
let raw_max_aliases_per_part = 4096

///|
let raw_max_alias_targets = 64

///|
let raw_max_alias_text_bytes : Int = 8 * 1024 * 1024

///|
let content_types_root = "{http://schemas.openxmlformats.org/package/2006/content-types}Types"

///|
let content_types_default = "{http://schemas.openxmlformats.org/package/2006/content-types}Default"

///|
let content_types_override = "{http://schemas.openxmlformats.org/package/2006/content-types}Override"

///|
let relationships_root = "{http://schemas.openxmlformats.org/package/2006/relationships}Relationships"

///|
let relationship_element = "{http://schemas.openxmlformats.org/package/2006/relationships}Relationship"

///|
let relationships_content_type = "application/vnd.openxmlformats-package.relationships+xml"

///|
let transitional_office_relationship_prefix = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/"

///|
let strict_office_relationship_prefix = "http://purl.oclc.org/ooxml/officeDocument/relationships/"

///|
let transitional_office_relationship_namespace = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"

///|
let strict_office_relationship_namespace = "http://purl.oclc.org/ooxml/officeDocument/relationships"

///|
let transitional_spreadsheet_namespace = "http://schemas.openxmlformats.org/spreadsheetml/2006/main"

///|
let strict_spreadsheet_namespace = "http://purl.oclc.org/ooxml/spreadsheetml/main"

///|
priv struct ContentTypeTable {
  defaults : Map[String, String]
  overrides : Map[String, String]
}

///|
priv struct RawRelationship {
  id : String
  kind : String
  target : String
  external : Bool
}

///|
priv struct RawPackage {
  format : @office.DocumentFormat
  archive : @zip.Archive
  names : Map[String, String]
  parts : Map[String, Bytes]
  content_types : ContentTypeTable
  aliases : Map[String, Array[String]]
  part_aliases : Map[String, Array[String]]
  alias_membership : Map[String, Set[String]]
  part_alias_membership : Map[String, Set[String]]
  mut alias_count : Int
  mut alias_text_bytes : Int
  mut main_part : String
  mut relationship_prefix : String
}

///|
fn canonical_part_key(value : StringView) -> String {
  value.to_owned().to_lower()
}

///|
fn xml_name_uri(value : String) -> String {
  if value.has_prefix("{") {
    match value.find("}") {
      Some(close) => value[1:close].to_owned()
      None => ""
    }
  } else {
    ""
  }
}

///|
fn decode_xml_bytes(name : String, bytes : BytesView) -> String raise RawError {
  let decoded = if bytes.length() >= 2 && bytes[0] == 0xff && bytes[1] == 0xfe {
    @utf16.decode(bytes, ignore_bom=true) catch {
      _ =>
        raise raw_error(
          "office.raw.invalid_xml_encoding",
          "part '/\{name}' is not valid UTF-8 or UTF-16 XML text",
        )
    }
  } else if bytes.length() >= 2 && bytes[0] == 0xfe && bytes[1] == 0xff {
    @utf16.decode(bytes, ignore_bom=true, endianness=Big) catch {
      _ =>
        raise raw_error(
          "office.raw.invalid_xml_encoding",
          "part '/\{name}' is not valid UTF-8 or UTF-16 XML text",
        )
    }
  } else if bytes.length() >= 2 && bytes[0] == b'<' && bytes[1] == 0x00 {
    @utf16.decode(bytes) catch {
      _ =>
        raise raw_error(
          "office.raw.invalid_xml_encoding",
          "part '/\{name}' is not valid UTF-8 or UTF-16 XML text",
        )
    }
  } else if bytes.length() >= 2 && bytes[0] == 0x00 && bytes[1] == b'<' {
    @utf16.decode(bytes, endianness=Big) catch {
      _ =>
        raise raw_error(
          "office.raw.invalid_xml_encoding",
          "part '/\{name}' is not valid UTF-8 or UTF-16 XML text",
        )
    }
  } else {
    @utf8.decode(bytes, ignore_bom=true) catch {
      _ =>
        raise raw_error(
          "office.raw.invalid_xml_encoding",
          "part '/\{name}' is not valid UTF-8 or UTF-16 XML text",
        )
    }
  }
  decoded
}

///|
fn checked_metadata_xml_text(
  name : String,
  bytes : BytesView,
) -> String raise RawError {
  if bytes.length() == 0 || bytes.length() > raw_metadata_max_bytes {
    raise raw_xml_resource_limit(
      name,
      "metadata_xml_bytes",
      raw_metadata_max_bytes,
      bytes.length(),
    )
  }
  let text = decode_xml_bytes(name, bytes)
  preflight_raw_metadata_xml(name, @utf8.encode(text))
  text
}

///|
fn parse_xml_bytes(
  name : String,
  bytes : BytesView,
) -> @xml.XmlElement raise RawError {
  let text = checked_metadata_xml_text(name, bytes)
  @xml.read_xml_string_strict(text) catch {
    _ =>
      raise raw_error(
        "office.raw.invalid_xml",
        "part '/\{name}' is not well-formed strict XML",
      )
  }
}

///|
fn raw_archive_index(
  archive : @zip.Archive,
) -> (Map[String, String], Map[String, Bytes]) raise RawError {
  let entry_names : Map[String, String] = Map([])
  let names : Map[String, String] = Map([])
  let parts : Map[String, Bytes] = Map([])
  for entry in archive.entries() {
    let name = entry.name()
    if name == "" ||
      !raw_text_within_scalar_limit(name, raw_max_part_name_length) {
      raise raw_error(
        "office.raw.invalid_package",
        "package entry names must contain 1 to \{raw_max_part_name_length} Unicode scalar values",
        details=Json::object({
          "part": Json::string(bounded_raw_text(name, 160)),
        }),
      )
    }
    let key = canonical_part_key(name)
    match entry_names.get(key) {
      Some(existing) =>
        raise raw_error(
          "office.raw.invalid_package",
          "package contains colliding entry names '/\{bounded_raw_text(existing, 120)}' and '/\{bounded_raw_text(name, 120)}'",
        )
      None => {
        entry_names[key] = name
        // ZIP directory markers are physical archive records, not OPC parts.
        // Keep them in `archive` for byte-preserving rewrites, but do not make
        // them addressable through the raw part inventory.
        if !name.has_suffix("/") {
          names[key] = name
          parts[key] = entry.data()
        }
      }
    }
  }
  (names, parts)
}

///|
fn extension_of_part(name : String) -> String? {
  match name.rev_find(".") {
    Some(dot) =>
      match name.rev_find("/") {
        Some(slash) if slash > dot => None
        _ if dot + 1 < name.length() =>
          Some(name[dot + 1:].to_owned().to_lower())
        _ => None
      }
    None => None
  }
}

///|
fn normalize_manifest_part(value : String) -> String? {
  if !value.has_prefix("/") || value.length() <= 1 || value.contains("\\") {
    return None
  }
  let output : Array[String] = []
  for segment in value[1:].split("/") {
    if segment == "" || segment == "." || segment == ".." {
      return None
    }
    output.push(segment.to_owned())
  }
  Some(output.join("/"))
}

///|
fn raw_unexpected_xml_attribute(
  element : @xml.XmlElement,
  allowed : ArrayView[String],
) -> String? {
  for name, _ in element.attributes {
    let mut accepted = false
    for expected in allowed {
      if name == expected {
        accepted = true
        break
      }
    }
    if !accepted {
      return Some(name)
    }
  }
  None
}

///|
fn parse_content_types(
  names : Map[String, String],
  parts : Map[String, Bytes],
) -> ContentTypeTable raise RawError {
  let manifest_key = canonical_part_key("[Content_Types].xml")
  let actual_name = match names.get(manifest_key) {
    Some(value) => value
    None =>
      raise raw_error(
        "office.raw.invalid_package", "package is missing /[Content_Types].xml",
      )
  }
  let bytes = match parts.get(manifest_key) {
    Some(value) => value
    None =>
      raise raw_error(
        "office.raw.invalid_package", "package index lost /[Content_Types].xml",
      )
  }
  let root = parse_xml_bytes(actual_name, bytes)
  if root.name != content_types_root {
    raise raw_error(
      "office.raw.invalid_package", "/[Content_Types].xml must use the exact OPC content-types namespace",
    )
  }
  match raw_unexpected_xml_attribute(root, []) {
    Some(name) =>
      raise raw_error(
        "office.raw.invalid_package",
        "/[Content_Types].xml root has undeclared attribute '\{bounded_raw_text(name, 120)}'",
      )
    None => ()
  }
  let defaults : Map[String, String] = Map([])
  let overrides : Map[String, String] = Map([])
  let mut records = 0
  for child in root.children {
    match child {
      XmlText(text) =>
        if !text.trim().is_empty() {
          raise raw_error(
            "office.raw.invalid_package", "/[Content_Types].xml contains unexpected text",
          )
        }
      XmlElement(element) =>
        match element.name {
          name if name == content_types_default => {
            match
              raw_unexpected_xml_attribute(element, ["Extension", "ContentType"]) {
              Some(attribute) =>
                raise raw_error(
                  "office.raw.invalid_package",
                  "content-type Default has undeclared attribute '\{bounded_raw_text(attribute, 120)}'",
                )
              None => ()
            }
            if raw_xml_element_has_content(element) {
              raise raw_error(
                "office.raw.invalid_package", "content-type Default must be an empty element",
              )
            }
            records = records + 1
            if records > raw_max_manifest_records {
              raise raw_xml_resource_limit(
                actual_name, "content_type_records", raw_max_manifest_records, records,
              )
            }
            let extension = element.attributes.get("Extension")
            let content_type = element.attributes.get("ContentType")
            match (extension, content_type) {
              (Some(ext), Some(kind)) if ext != "" && kind != "" => {
                if ext.length() > raw_max_manifest_extension_length {
                  raise raw_xml_resource_limit(
                    actual_name,
                    "manifest_extension_length",
                    raw_max_manifest_extension_length,
                    ext.length(),
                  )
                }
                if kind.length() > raw_max_content_type_length {
                  raise raw_xml_resource_limit(
                    actual_name,
                    "content_type_length",
                    raw_max_content_type_length,
                    kind.length(),
                  )
                }
                let key = ext.to_lower()
                if defaults.contains(key) {
                  raise raw_error(
                    "office.raw.invalid_package",
                    "content-type manifest contains duplicate default extension '\{bounded_raw_text(ext, 120)}'",
                  )
                }
                defaults[key] = kind
              }
              _ =>
                raise raw_error(
                  "office.raw.invalid_package", "content-type Default must declare non-empty Extension and ContentType attributes",
                )
            }
          }
          name if name == content_types_override => {
            match
              raw_unexpected_xml_attribute(element, ["PartName", "ContentType"]) {
              Some(attribute) =>
                raise raw_error(
                  "office.raw.invalid_package",
                  "content-type Override has undeclared attribute '\{bounded_raw_text(attribute, 120)}'",
                )
              None => ()
            }
            if raw_xml_element_has_content(element) {
              raise raw_error(
                "office.raw.invalid_package", "content-type Override must be an empty element",
              )
            }
            records = records + 1
            if records > raw_max_manifest_records {
              raise raw_xml_resource_limit(
                actual_name, "content_type_records", raw_max_manifest_records, records,
              )
            }
            let part = element.attributes.get("PartName")
            let content_type = element.attributes.get("ContentType")
            match (part, content_type) {
              (Some(name), Some(kind)) if name != "" && kind != "" => {
                // OPC PartName includes its required leading slash; the
                // supported archive/transaction name limit does not.
                if !raw_text_within_scalar_limit(
                    name,
                    raw_max_part_name_length + 1,
                  ) {
                  raise raw_xml_resource_limit(
                    actual_name,
                    "manifest_part_name_length",
                    raw_max_part_name_length + 1,
                    name.length(),
                  )
                }
                if kind.length() > raw_max_content_type_length {
                  raise raw_xml_resource_limit(
                    actual_name,
                    "content_type_length",
                    raw_max_content_type_length,
                    kind.length(),
                  )
                }
                match normalize_manifest_part(name) {
                  Some(normalized) => {
                    let key = canonical_part_key(normalized)
                    if overrides.contains(key) {
                      raise raw_error(
                        "office.raw.invalid_package",
                        "content-type manifest contains duplicate override '/\{bounded_raw_text(normalized, 120)}'",
                      )
                    }
                    overrides[key] = kind
                  }
                  None =>
                    raise raw_error(
                      "office.raw.invalid_package",
                      "content-type Override has invalid PartName '\{bounded_raw_text(name, 120)}'",
                    )
                }
              }
              _ =>
                raise raw_error(
                  "office.raw.invalid_package", "content-type Override must declare non-empty PartName and ContentType attributes",
                )
            }
          }
          _ =>
            raise raw_error(
              "office.raw.invalid_package", "/[Content_Types].xml contains an unexpected element",
            )
        }
    }
  }
  { defaults, overrides }
}

///|
fn ContentTypeTable::for_part(self : ContentTypeTable, name : String) -> String {
  if canonical_part_key(name) == canonical_part_key("[Content_Types].xml") {
    return "application/vnd.openxmlformats-package.content-types+xml"
  }
  match self.overrides.get(canonical_part_key(name)) {
    Some(value) => value
    None =>
      match extension_of_part(name) {
        Some(extension) => self.defaults.get(extension).unwrap_or("")
        None => ""
      }
  }
}

///|
fn content_type_is_xml(value : String) -> Bool {
  let media_type = match value.find(";") {
    Some(at) => value[:at].to_owned().trim().to_lower()
    None => value.trim().to_lower()
  }
  media_type == "application/xml" ||
  media_type == "text/xml" ||
  media_type.has_suffix("+xml")
}

///|
fn format_for_main_content_type(value : String) -> @office.DocumentFormat? {
  let normalized = value.trim().to_lower()
  match normalized {
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml" =>
      Some(Docx)
    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml" =>
      Some(Xlsx)
    _ => None
  }
}

///|
fn relationships_part_for(source : String) -> String {
  if source == "" {
    return "_rels/.rels"
  }
  match source.rev_find("/") {
    Some(slash) =>
      source[:slash].to_owned() +
      "/_rels/" +
      source[slash + 1:].to_owned() +
      ".rels"
    None => "_rels/" + source + ".rels"
  }
}

///|
fn relationship_source_for_part(part : String) -> String? {
  let lower = part.to_lower()
  if lower == "_rels/.rels" {
    return Some("")
  }
  if !lower.has_suffix(".rels") {
    return None
  }
  if lower.has_prefix("_rels/") {
    let basename = part[6:part.length() - 5].to_owned()
    return if basename == "" { None } else { Some(basename) }
  }
  match lower.rev_find("/_rels/") {
    Some(marker) => {
      let basename = part[marker + 7:part.length() - 5].to_owned()
      if basename == "" {
        None
      } else {
        Some(part[:marker].to_owned() + "/" + basename)
      }
    }
    None => None
  }
}

///|
fn office_relationship_role(kind : String) -> String? {
  let prefix = if kind.has_prefix(transitional_office_relationship_prefix) {
    transitional_office_relationship_prefix
  } else if kind.has_prefix(strict_office_relationship_prefix) {
    strict_office_relationship_prefix
  } else {
    return None
  }
  if kind.length() == prefix.length() {
    None
  } else {
    Some(kind[prefix.length():].to_owned())
  }
}

///|
fn office_relationship_role_for_prefix(
  kind : String,
  prefix : String,
) -> String? {
  if !kind.has_prefix(prefix) || kind.length() == prefix.length() {
    None
  } else {
    Some(kind[prefix.length():].to_owned())
  }
}

///|
fn normalize_relationship_target(base : String, target : String) -> String? {
  if target == "" ||
    target.contains("\\") ||
    target.contains("?") ||
    target.contains("#") ||
    target.has_prefix("//") {
    return None
  }
  let joined = if target.has_prefix("/") {
    target[1:].to_owned()
  } else {
    base + target
  }
  let output : Array[String] = []
  for segment in joined.split("/") {
    match segment {
      "" => return None
      "." => ()
      ".." => if output.is_empty() { return None } else { ignore(output.pop()) }
      _ => output.push(segment.to_owned())
    }
  }
  if output.is_empty() {
    None
  } else {
    Some(output.join("/"))
  }
}

///|
fn source_base(source : String) -> String {
  match source.rev_find("/") {
    Some(slash) => source[:slash + 1].to_owned()
    None => ""
  }
}

///|
fn raw_xml_element_has_content(element : @xml.XmlElement) -> Bool {
  for child in element.children {
    match child {
      XmlElement(_) => return true
      XmlText(text) => if !text.trim().is_empty() { return true }
    }
  }
  false
}

///|
fn raw_is_ascii_hex_unit(unit : UInt16) -> Bool {
  (unit >= b'0'.to_uint16() && unit <= b'9'.to_uint16()) ||
  (unit >= b'a'.to_uint16() && unit <= b'f'.to_uint16()) ||
  (unit >= b'A'.to_uint16() && unit <= b'F'.to_uint16())
}

///|
fn raw_uri_text_is_sane(value : String, allow_fragment : Bool) -> Bool {
  if value == "" {
    return false
  }
  for character in value {
    let code = character.to_int()
    if code <= 0x20 ||
      code == 0x7f ||
      character == '<' ||
      character == '>' ||
      character == '"' ||
      character == '{' ||
      character == '}' ||
      character == '|' ||
      character == '^' ||
      character == '`' ||
      (!allow_fragment && character == '#') {
      return false
    }
  }
  let mut offset = 0
  while offset < value.length() {
    if value[offset] == '%' {
      if offset + 2 >= value.length() ||
        !raw_is_ascii_hex_unit(value[offset + 1]) ||
        !raw_is_ascii_hex_unit(value[offset + 2]) {
        return false
      }
      offset = offset + 3
    } else {
      offset = offset + 1
    }
  }
  true
}

///|
fn raw_relationship_type_is_absolute(value : String) -> Bool {
  guard value.find(":") is Some(colon) && colon > 0 else { return false }
  for index, character in value[:colon] {
    let valid = if index == 0 {
      character.is_ascii_alphabetic()
    } else {
      character.is_ascii_alphabetic() ||
      character.is_ascii_digit() ||
      character == '+' ||
      character == '-' ||
      character == '.'
    }
    if !valid {
      return false
    }
  }
  raw_uri_text_is_sane(value, false)
}

///|
fn parse_relationships(
  pkg : RawPackage,
  source : String,
) -> Array[RawRelationship] raise RawError {
  let relationship_part = relationships_part_for(source)
  let canonical = match pkg.names.get(canonical_part_key(relationship_part)) {
    Some(value) => value
    None => return []
  }
  let bytes = match pkg.parts.get(canonical_part_key(canonical)) {
    Some(value) => value
    None =>
      raise raw_error(
        "office.raw.invalid_package",
        "package index lost relationship part '/\{canonical}'",
      )
  }
  let root = parse_xml_bytes(canonical, bytes)
  if root.name != relationships_root {
    raise raw_error(
      "office.raw.invalid_relationship",
      "relationship part '/\{canonical}' must use the exact OPC relationships namespace",
    )
  }
  match raw_unexpected_xml_attribute(root, []) {
    Some(name) =>
      raise raw_error(
        "office.raw.invalid_relationship",
        "relationship part '/\{canonical}' root has undeclared attribute '\{bounded_raw_text(name, 120)}'",
      )
    None => ()
  }
  let output : Array[RawRelationship] = []
  let ids : Set[String] = Set([])
  let mut records = 0
  for child in root.children {
    match child {
      XmlText(text) =>
        if !text.trim().is_empty() {
          raise raw_error(
            "office.raw.invalid_relationship",
            "relationship part '/\{canonical}' contains unexpected text",
          )
        }
      XmlElement(element) => {
        if element.name != relationship_element {
          raise raw_error(
            "office.raw.invalid_relationship",
            "relationship part '/\{canonical}' contains an unexpected element",
          )
        }
        match
          raw_unexpected_xml_attribute(element, [
            "Id", "Type", "Target", "TargetMode",
          ]) {
          Some(name) =>
            raise raw_error(
              "office.raw.invalid_relationship",
              "relationship in '/\{canonical}' has undeclared attribute '\{bounded_raw_text(name, 120)}'",
            )
          None => ()
        }
        if raw_xml_element_has_content(element) {
          raise raw_error(
            "office.raw.invalid_relationship",
            "relationship in '/\{canonical}' must be an empty element",
          )
        }
        records = records + 1
        if records > raw_max_relationship_records {
          raise raw_xml_resource_limit(
            canonical, "relationship_records", raw_max_relationship_records, records,
          )
        }
        match
          (
            element.attributes.get("Id"),
            element.attributes.get("Type"),
            element.attributes.get("Target"),
          ) {
          (Some(id), Some(kind), Some(target)) if id != "" &&
            kind != "" &&
            target != "" => {
            if id.length() > raw_max_relationship_id_length {
              raise raw_xml_resource_limit(
                canonical,
                "relationship_id_length",
                raw_max_relationship_id_length,
                id.length(),
              )
            }
            if kind.length() > raw_max_relationship_type_length {
              raise raw_xml_resource_limit(
                canonical,
                "relationship_type_length",
                raw_max_relationship_type_length,
                kind.length(),
              )
            }
            if target.length() > raw_max_relationship_target_length {
              raise raw_xml_resource_limit(
                canonical,
                "relationship_target_length",
                raw_max_relationship_target_length,
                target.length(),
              )
            }
            if !is_raw_ncname(id) {
              raise raw_error(
                "office.raw.invalid_relationship",
                "relationship Id '\{bounded_raw_text(id, 120)}' in '/\{canonical}' is not a valid NCName",
              )
            }
            if !raw_relationship_type_is_absolute(kind) {
              raise raw_error(
                "office.raw.invalid_relationship",
                "relationship '\{bounded_raw_text(id, 120)}' in '/\{canonical}' has an invalid absolute Type URI",
              )
            }
            if ids.contains(id) {
              raise raw_error(
                "office.raw.invalid_relationship",
                "relationship part '/\{canonical}' contains duplicate Id '\{bounded_raw_text(id, 120)}'",
              )
            }
            ids.add(id)
            let external = match element.attributes.get("TargetMode") {
              None | Some("Internal") => false
              Some("External") => true
              Some(_) =>
                raise raw_error(
                  "office.raw.invalid_relationship",
                  "relationship '\{bounded_raw_text(id, 120)}' in '/\{canonical}' has an invalid TargetMode",
                )
            }
            if external {
              if !raw_uri_text_is_sane(target, true) {
                raise raw_error(
                  "office.raw.invalid_relationship",
                  "relationship '\{bounded_raw_text(id, 120)}' in '/\{canonical}' has an invalid external target",
                )
              }
              output.push({ id, kind, target, external: true })
            } else {
              match normalize_relationship_target(source_base(source), target) {
                Some(resolved) =>
                  match pkg.names.get(canonical_part_key(resolved)) {
                    Some(actual) =>
                      output.push({ id, kind, target: actual, external: false })
                    None =>
                      raise raw_error(
                        "office.raw.invalid_relationship",
                        "relationship '\{id}' in '/\{canonical}' targets missing part '/\{resolved}'",
                      )
                  }
                None =>
                  raise raw_error(
                    "office.raw.invalid_relationship",
                    "relationship '\{id}' in '/\{canonical}' has an invalid target",
                  )
              }
            }
          }
          _ =>
            raise raw_error(
              "office.raw.invalid_relationship",
              "relationship in '/\{canonical}' must declare non-empty Id, Type, and Target attributes",
            )
        }
      }
    }
  }
  output
}

///|
fn add_alias(
  pkg : RawPackage,
  alias_name : String,
  part : String,
) -> Unit raise RawError {
  if alias_name.length() == 0 || alias_name.length() > raw_max_alias_length {
    return
  }
  let key = alias_name.to_lower()
  if !key.has_prefix("/") {
    return
  }
  let actual_part = match pkg.names.get(canonical_part_key(part)) {
    Some(value) => value
    None => return
  }
  let targets = match pkg.alias_membership.get(key) {
    Some(values) => values
    None => {
      let values : Set[String] = Set([])
      pkg.alias_membership[key] = values
      values
    }
  }
  if targets.contains(actual_part) {
    return
  }
  if targets.length() >= raw_max_alias_targets {
    raise raw_error(
      "office.raw.resource_limit",
      "semantic alias '\{bounded_raw_text(alias_name, 120)}' exceeds \{raw_max_alias_targets} targets",
    )
  }
  let part_key = canonical_part_key(actual_part)
  let reverse = match pkg.part_alias_membership.get(part_key) {
    Some(values) => values
    None => {
      let values : Set[String] = Set([])
      pkg.part_alias_membership[part_key] = values
      values
    }
  }
  if !reverse.contains(alias_name) {
    if reverse.length() >= raw_max_aliases_per_part ||
      pkg.alias_count >= raw_max_aliases_total ||
      alias_name.length() > raw_max_alias_text_bytes - pkg.alias_text_bytes {
      raise raw_error(
        "office.raw.resource_limit",
        "semantic alias graph exceeds its bounded construction budget",
        details=Json::object({
          "kind": Json::string("semantic_aliases"),
          "limit": Json::number(raw_max_aliases_total.to_double()),
          "actual": Json::number((pkg.alias_count + 1).to_double()),
        }),
      )
    }
    reverse.add(alias_name)
    match pkg.part_aliases.get(part_key) {
      Some(aliases) => aliases.push(alias_name)
      None => pkg.part_aliases[part_key] = [alias_name]
    }
    pkg.alias_count = pkg.alias_count + 1
    pkg.alias_text_bytes = pkg.alias_text_bytes + alias_name.length()
  }
  targets.add(actual_part)
  match pkg.aliases.get(key) {
    Some(parts) => parts.push(actual_part)
    None => pkg.aliases[key] = [actual_part]
  }
}

///|
fn find_main_part(pkg : RawPackage) -> String raise RawError {
  let relationships = parse_relationships(pkg, "")
  let found : Array[String] = []
  for relationship in relationships {
    if !relationship.external &&
      office_relationship_role(relationship.kind) == Some("officeDocument") {
      found.push(relationship.target)
    }
  }
  match found {
    [part] => part
    [] =>
      raise raw_error(
        "office.raw.invalid_package", "root relationships do not identify an Office document part",
      )
    _ =>
      raise raw_error(
        "office.raw.invalid_package", "root relationships identify multiple Office document parts",
      )
  }
}

///|
fn expected_relationship_content_type(
  format : @office.DocumentFormat,
  role : String,
) -> String? {
  match (format, role) {
    (Docx, "styles") =>
      Some(
        "application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml",
      )
    (Docx, "settings") =>
      Some(
        "application/vnd.openxmlformats-officedocument.wordprocessingml.settings+xml",
      )
    (Docx, "numbering") =>
      Some(
        "application/vnd.openxmlformats-officedocument.wordprocessingml.numbering+xml",
      )
    (Docx, "comments") =>
      Some(
        "application/vnd.openxmlformats-officedocument.wordprocessingml.comments+xml",
      )
    (Docx, "footnotes") =>
      Some(
        "application/vnd.openxmlformats-officedocument.wordprocessingml.footnotes+xml",
      )
    (Docx, "endnotes") =>
      Some(
        "application/vnd.openxmlformats-officedocument.wordprocessingml.endnotes+xml",
      )
    (Docx, "header") =>
      Some(
        "application/vnd.openxmlformats-officedocument.wordprocessingml.header+xml",
      )
    (Docx, "footer") =>
      Some(
        "application/vnd.openxmlformats-officedocument.wordprocessingml.footer+xml",
      )
    (Xlsx, "styles") =>
      Some(
        "application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml",
      )
    (Xlsx, "sharedStrings") =>
      Some(
        "application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml",
      )
    (Xlsx, "worksheet") =>
      Some(
        "application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml",
      )
    (_, "theme") =>
      Some("application/vnd.openxmlformats-officedocument.theme+xml")
    _ => None
  }
}

///|
fn relationship_matches_role(
  pkg : RawPackage,
  relationship : RawRelationship,
  role : String,
) -> Bool {
  if relationship.external ||
    office_relationship_role_for_prefix(
      relationship.kind,
      pkg.relationship_prefix,
    ) !=
    Some(role) {
    return false
  }
  match expected_relationship_content_type(pkg.format, role) {
    Some(expected) =>
      pkg.content_types.for_part(relationship.target).trim().to_lower() ==
      expected.to_lower()
    None => true
  }
}

///|
fn relationship_target_by_id(
  pkg : RawPackage,
  relationships_by_id : Map[String, RawRelationship],
  id : String,
  role : String,
) -> String? {
  match relationships_by_id.get(id) {
    Some(relationship) if relationship_matches_role(pkg, relationship, role) =>
      Some(relationship.target)
    _ => None
  }
}

///|
fn relationship_index_by_id(
  relationships : ArrayView[RawRelationship],
) -> Map[String, RawRelationship] {
  let index : Map[String, RawRelationship] = Map([])
  for relationship in relationships {
    // `parse_relationships` rejects duplicate IDs before this index is built.
    index[relationship.id] = relationship
  }
  index
}

///|
fn spreadsheet_relationship_id(
  element : @xml.XmlElement,
  relationship_prefix : String,
) -> String? raise RawError {
  let transitional = element.attributes.get(
    "{\{transitional_office_relationship_namespace}}id",
  )
  let strict = element.attributes.get(
    "{\{strict_office_relationship_namespace}}id",
  )
  let expected_strict = relationship_prefix == strict_office_relationship_prefix
  match (transitional, strict, expected_strict) {
    (None, Some(id), true) | (Some(id), None, false) => Some(id)
    (None, None, _) => None
    (Some(_), Some(_), _) =>
      raise raw_error(
        "office.raw.invalid_relationship", "worksheet declaration contains both Transitional and Strict relationship ids",
      )
    _ =>
      raise raw_error(
        "office.raw.invalid_relationship", "worksheet declaration uses a relationship-id namespace from the wrong OOXML dialect",
      )
  }
}

///|
fn add_singleton_relationship_aliases(
  pkg : RawPackage,
  relationships : ArrayView[RawRelationship],
  aliases : Map[String, String],
) -> Unit raise RawError {
  for relationship in relationships {
    match
      office_relationship_role_for_prefix(
        relationship.kind,
        pkg.relationship_prefix,
      ) {
      Some(role) if relationship_matches_role(pkg, relationship, role) =>
        match aliases.get(role) {
          Some(alias_name) => add_alias(pkg, alias_name, relationship.target)
          None => ()
        }
      _ => ()
    }
  }
}

///|
fn add_docx_aliases(pkg : RawPackage) -> Unit raise RawError {
  add_alias(pkg, "/document", pkg.main_part)
  let main_relationships_part = relationships_part_for(pkg.main_part)
  add_alias(pkg, "/document/relationships", main_relationships_part)
  let relationships = parse_relationships(pkg, pkg.main_part)
  add_singleton_relationship_aliases(pkg, relationships, {
    "styles": "/styles",
    "settings": "/settings",
    "numbering": "/numbering",
    "comments": "/comments",
    "footnotes": "/footnotes",
    "endnotes": "/endnotes",
    "theme": "/theme",
  })
  let mut header = 0
  let mut footer = 0
  for relationship in relationships {
    match
      office_relationship_role_for_prefix(
        relationship.kind,
        pkg.relationship_prefix,
      ) {
      Some("header") if relationship_matches_role(pkg, relationship, "header") => {
        header = header + 1
        add_alias(pkg, "/header[\{header}]", relationship.target)
      }
      Some("footer") if relationship_matches_role(pkg, relationship, "footer") => {
        footer = footer + 1
        add_alias(pkg, "/footer[\{footer}]", relationship.target)
      }
      _ => ()
    }
  }
}

///|
fn add_xlsx_aliases(pkg : RawPackage) -> Unit raise RawError {
  add_alias(pkg, "/workbook", pkg.main_part)
  let main_relationships_part = relationships_part_for(pkg.main_part)
  add_alias(pkg, "/workbook/relationships", main_relationships_part)
  let relationships = parse_relationships(pkg, pkg.main_part)
  let relationships_by_id = relationship_index_by_id(relationships)
  add_singleton_relationship_aliases(pkg, relationships, {
    "styles": "/styles",
    "sharedStrings": "/shared-strings",
    "theme": "/theme",
  })
  let workbook_bytes = match pkg.archive.get(pkg.main_part) {
    Some(value) => value
    None =>
      raise raw_error(
        "office.raw.invalid_package",
        "package is missing workbook part '/\{pkg.main_part}'",
      )
  }
  let workbook = parse_xml_bytes(pkg.main_part, workbook_bytes)
  let workbook_namespace = xml_name_uri(workbook.name)
  if workbook_namespace != transitional_spreadsheet_namespace &&
    workbook_namespace != strict_spreadsheet_namespace {
    raise raw_error(
      "office.raw.invalid_package",
      "workbook part '/\{pkg.main_part}' has an unsupported namespace",
    )
  }
  let sheets_element_name = "{\{workbook_namespace}}sheets"
  let sheet_element_name = "{\{workbook_namespace}}sheet"
  let mut sheet_records = 0
  for sheets_child in workbook.children {
    match sheets_child {
      XmlElement(sheets) if sheets.name == sheets_element_name =>
        for child in sheets.children {
          match child {
            XmlElement(sheet) if sheet.name == sheet_element_name => {
              sheet_records = sheet_records + 1
              if sheet_records > raw_max_archive_entries {
                raise raw_xml_resource_limit(
                  pkg.main_part,
                  "worksheet_records",
                  raw_max_archive_entries,
                  sheet_records,
                )
              }
              let name = sheet.attributes.get("name")
              let relationship_id = spreadsheet_relationship_id(
                sheet,
                pkg.relationship_prefix,
              )
              match (name, relationship_id) {
                (Some(name), Some(id)) =>
                  match
                    relationship_target_by_id(
                      pkg, relationships_by_id, id, "worksheet",
                    ) {
                    Some(part) => {
                      add_alias(pkg, "/sheet[\{sheet_records}]", part)
                      add_alias(pkg, "/" + name, part)
                      let rels = relationships_part_for(part)
                      add_alias(
                        pkg,
                        "/sheet[\{sheet_records}]/relationships",
                        rels,
                      )
                      add_alias(pkg, "/" + name + "/relationships", rels)
                    }
                    None => ()
                  }
                _ => ()
              }
            }
            _ => ()
          }
        }
      _ => ()
    }
  }
}

///|
fn raw_path_for_format(format : @office.DocumentFormat) -> String {
  match format {
    Docx => "raw.docx"
    Xlsx => "raw.xlsx"
  }
}

///|
fn relationship_prefix_for_main(pkg : RawPackage) -> String raise RawError {
  let bytes = match pkg.archive.get(pkg.main_part) {
    Some(value) => value
    None =>
      raise raw_error(
        "office.raw.invalid_package",
        "package is missing main part '/\{pkg.main_part}'",
      )
  }
  let root = parse_xml_bytes(pkg.main_part, bytes)
  let root_uri = xml_name_uri(root.name)
  match (pkg.format, root_uri) {
    (Docx, "http://schemas.openxmlformats.org/wordprocessingml/2006/main")
    | (Xlsx, "http://schemas.openxmlformats.org/spreadsheetml/2006/main") =>
      transitional_office_relationship_prefix
    (Docx, "http://purl.oclc.org/ooxml/wordprocessingml/main")
    | (Xlsx, "http://purl.oclc.org/ooxml/spreadsheetml/main") =>
      strict_office_relationship_prefix
    _ =>
      raise raw_error(
        "office.raw.invalid_package",
        "main part '/\{pkg.main_part}' uses an unsupported OOXML namespace",
      )
  }
}

///|
fn validate_main_relationship_dialect(pkg : RawPackage) -> Unit raise RawError {
  let matches = []
  for relationship in parse_relationships(pkg, "") {
    if !relationship.external &&
      office_relationship_role_for_prefix(
        relationship.kind,
        pkg.relationship_prefix,
      ) ==
      Some("officeDocument") {
      matches.push(relationship.target)
    }
  }
  match matches {
    [part] if canonical_part_key(part) == canonical_part_key(pkg.main_part) =>
      ()
    _ =>
      raise raw_error(
        "office.raw.invalid_relationship", "officeDocument relationship dialect does not match the main OOXML namespace",
      )
  }
}

///|
fn validate_all_relationship_parts(pkg : RawPackage) -> Unit raise RawError {
  for entry in pkg.archive.entries() {
    let part = entry.name()
    let declared_type = pkg.content_types.for_part(part).trim().to_lower()
    let relationship_name = canonical_part_key(part).has_suffix(".rels")
    if relationship_name {
      if declared_type != relationships_content_type {
        raise raw_error(
          "office.raw.invalid_relationship",
          "relationship part '/\{bounded_raw_text(part, 160)}' must declare the exact OPC relationships content type",
        )
      }
      match relationship_source_for_part(part) {
        Some(source) => ignore(parse_relationships(pkg, source))
        None =>
          raise raw_error(
            "office.raw.invalid_relationship",
            "relationship part '/\{bounded_raw_text(part, 160)}' is not stored at a valid OPC relationship-part name",
          )
      }
    } else if declared_type == relationships_content_type {
      raise raw_error(
        "office.raw.invalid_relationship",
        "part '/\{bounded_raw_text(part, 160)}' declares the OPC relationships content type but is not a canonical relationship-part name",
      )
    }
  }
}

///|
fn raw_package_shell(
  format : @office.DocumentFormat,
  archive : @zip.Archive,
  names : Map[String, String],
  parts : Map[String, Bytes],
  content_types : ContentTypeTable,
) -> RawPackage {
  {
    format,
    archive,
    names,
    parts,
    content_types,
    aliases: Map([]),
    part_aliases: Map([]),
    alias_membership: Map([]),
    part_alias_membership: Map([]),
    alias_count: 0,
    alias_text_bytes: 0,
    main_part: "",
    relationship_prefix: "",
  }
}

///|
fn package_from_archive(archive : @zip.Archive) -> RawPackage raise RawError {
  let (names, parts) = raw_archive_index(archive)
  let content_types = parse_content_types(names, parts)
  // Root relationships are format-neutral, so use a short-lived shell to
  // resolve the exact main part before trusting a content-type declaration.
  let main_part = find_main_part(
    raw_package_shell(Docx, archive, names, parts, content_types),
  )
  let format = match
    format_for_main_content_type(content_types.for_part(main_part)) {
    Some(value) => value
    None =>
      raise raw_error(
        "office.raw.invalid_package",
        "officeDocument relationship target '/\{bounded_raw_text(main_part, 160)}' is not a supported DOCX or XLSX main part",
      )
  }
  let pkg = raw_package_shell(format, archive, names, parts, content_types)
  pkg.main_part = main_part
  pkg.relationship_prefix = relationship_prefix_for_main(pkg)
  validate_main_relationship_dialect(pkg)
  validate_all_relationship_parts(pkg)
  add_alias(pkg, "/content-types", "[Content_Types].xml")
  add_alias(pkg, "/relationships", "_rels/.rels")
  match format {
    Docx => add_docx_aliases(pkg)
    Xlsx => add_xlsx_aliases(pkg)
  }
  let inventory_parts : Array[RawPartInfo] = []
  for _, name in pkg.names {
    inventory_parts.push(pkg.part_info(name))
  }
  check_inventory_serialization_budget(inventory_parts)
  pkg
}

///|
fn read_bounded_archive(data : BytesView) -> @zip.Archive raise RawError {
  if data.length() > raw_max_package_bytes {
    raise raw_error(
      "office.raw.resource_limit",
      "package exceeds the \{raw_max_package_bytes}-byte raw OOXML limit",
      details=Json::object({
        "kind": Json::string("package_bytes"),
        "limit": Json::number(raw_max_package_bytes.to_double()),
        "actual": Json::number(data.length().to_double()),
      }),
    )
  }
  @zip.read_limited(
    data,
    max_entries=raw_max_archive_entries,
    max_entry_uncompressed_bytes=raw_max_entry_bytes,
    max_total_uncompressed_bytes=raw_max_total_uncompressed_bytes,
  ) catch {
    ResourceLimitExceeded(kind~, limit~, actual~) =>
      raise raw_error(
        "office.raw.resource_limit",
        "ZIP package exceeds the bounded \{kind} limit",
        details=Json::object({
          "kind": Json::string(kind),
          "limit": Json::number(limit.to_double()),
          "actual": Json::number(actual.to_double()),
        }),
      )
    _ =>
      raise raw_error(
        "office.raw.invalid_package", "package is not a bounded readable ZIP archive",
      )
  }
}

///|
fn check_raw_archive_materialization_limits(
  archive : @zip.Archive,
  max_entries : Int,
  max_entry_bytes : Int,
  max_total_bytes : Int,
) -> Unit raise RawError {
  let entries = archive.entries()
  if entries.length() > max_entries {
    raise raw_error(
      "office.raw.resource_limit",
      "ZIP package exceeds the bounded entry_count limit",
      details=Json::object({
        "kind": Json::string("entry_count"),
        "limit": Json::number(max_entries.to_double()),
        "actual": Json::number(entries.length().to_double()),
      }),
    )
  }
  let mut total = 0L
  for entry in entries {
    let size = entry.data().length()
    if size > max_entry_bytes {
      raise raw_error(
        "office.raw.resource_limit",
        "ZIP package exceeds the bounded entry_uncompressed_bytes limit",
        details=Json::object({
          "kind": Json::string("entry_uncompressed_bytes"),
          "limit": Json::number(max_entry_bytes.to_double()),
          "actual": Json::number(size.to_double()),
        }),
      )
    }
    total = total + size.to_int64()
    if total > max_total_bytes.to_int64() {
      raise raw_error(
        "office.raw.resource_limit",
        "ZIP package exceeds the bounded total_uncompressed_bytes limit",
        details=Json::object({
          "kind": Json::string("total_uncompressed_bytes"),
          "limit": Json::number(max_total_bytes.to_double()),
          "actual": Json::number(total.to_double()),
        }),
      )
    }
  }
}

///|
fn check_raw_archive_materialization(
  archive : @zip.Archive,
) -> Unit raise RawError {
  check_raw_archive_materialization_limits(
    archive, raw_max_archive_entries, raw_max_entry_bytes, raw_max_total_uncompressed_bytes,
  )
}

///|
fn check_bounded_raw_archive_limits(
  archive : @zip.Archive,
  max_package_bytes : Int,
  max_entries : Int,
  max_entry_bytes : Int,
  max_total_bytes : Int,
) -> Unit raise RawError {
  check_raw_archive_materialization_limits(
    archive, max_entries, max_entry_bytes, max_total_bytes,
  )
  match
    archive.bounded_source_package_size(
      max_entries~,
      max_entry_uncompressed_bytes=max_entry_bytes,
      max_total_uncompressed_bytes=max_total_bytes,
    ) {
    Some(size) if size <= max_package_bytes => ()
    Some(size) =>
      raise raw_error(
        "office.raw.resource_limit",
        "source package exceeds the \{max_package_bytes}-byte raw OOXML limit",
        details=Json::object({
          "kind": Json::string("package_bytes"),
          "limit": Json::number(max_package_bytes.to_double()),
          "actual": Json::number(size.to_double()),
        }),
      )
    None =>
      raise raw_error(
        "office.raw.resource_limit",
        "archive-backed raw APIs require a pristine archive produced by a sufficiently strict bounded ZIP read",
        details=Json::object({
          "kind": Json::string("bounded_archive_source"),
          "limit": Json::number(max_package_bytes.to_double()),
          "actual": Json::number((max_package_bytes + 1).to_double()),
        }),
      )
  }
}

///|
fn check_bounded_raw_archive(archive : @zip.Archive) -> Unit raise RawError {
  check_bounded_raw_archive_limits(
    archive, raw_max_package_bytes, raw_max_archive_entries, raw_max_entry_bytes,
    raw_max_total_uncompressed_bytes,
  )
}

///|
fn open_raw_package(
  path : StringView,
  data : BytesView,
) -> RawPackage raise RawError {
  let archive = read_bounded_archive(data)
  open_raw_archive(path, archive)
}

///|
fn open_raw_archive(
  path : StringView,
  archive : @zip.Archive,
) -> RawPackage raise RawError {
  check_bounded_raw_archive(archive)
  // Complete the collision-rejecting, namespace-exact, bounded raw resolver
  // before the generic Office detector can materialize any DOM.
  let pkg = package_from_archive(archive)
  let format = @office.detect_archive_format(path, archive) catch {
    error =>
      raise raw_error(
        "office.raw.invalid_package",
        "package failed portable Office validation: \{error}",
      )
  }
  if format != pkg.format {
    raise raw_error(
      "office.raw.invalid_package", "portable Office format does not match the bounded raw main-part resolver",
    )
  }
  pkg
}

///|
fn open_raw_package_for_format(
  format : @office.DocumentFormat,
  data : BytesView,
) -> RawPackage raise RawError {
  let archive = read_bounded_archive(data)
  open_raw_archive_for_format(format, archive)
}

///|
fn open_raw_archive_for_format(
  format : @office.DocumentFormat,
  archive : @zip.Archive,
) -> RawPackage raise RawError {
  check_bounded_raw_archive(archive)
  open_raw_materialized_archive_for_format(format, archive)
}

///|
fn open_raw_materialized_archive_for_format(
  format : @office.DocumentFormat,
  archive : @zip.Archive,
) -> RawPackage raise RawError {
  check_raw_archive_materialization(archive)
  let pkg = package_from_archive(archive)
  if pkg.format != format {
    raise raw_error(
      "office.raw.invalid_package", "raw candidate changed its bounded main-part format",
    )
  }
  let detected = @office.detect_archive_format(
    raw_path_for_format(format),
    archive,
  ) catch {
    error =>
      raise raw_error(
        "office.raw.invalid_package",
        "package failed portable Office validation: \{error}",
      )
  }
  if detected != format {
    raise raw_error(
      "office.raw.invalid_package", "portable Office format does not match the expected raw candidate format",
    )
  }
  pkg
}

///|
fn validate_part_selector(value : String) -> Unit raise RawError {
  if value == "" ||
    !raw_text_within_scalar_limit(value, raw_max_alias_length + 6) ||
    value.contains("\\") ||
    value.contains("\u{0}") {
    raise raw_error(
      "office.raw.invalid_part",
      "part selectors must be bounded absolute package names or semantic aliases",
      details=Json::object({
        "part": Json::string(bounded_raw_text(value, 160)),
      }),
    )
  }
}

///|
fn RawPackage::resolve_part(
  self : RawPackage,
  selector : String,
) -> String raise RawError {
  validate_part_selector(selector)
  let (mode, selected) = if selector.has_prefix("part:") {
    ("part", selector[5:].to_owned())
  } else if selector.has_prefix("alias:") {
    ("alias", selector[6:].to_owned())
  } else {
    ("auto", selector)
  }
  let selected_limit = if mode == "alias" {
    raw_max_alias_length
  } else {
    raw_max_part_name_length + 1
  }
  if !selected.has_prefix("/") ||
    !raw_text_within_scalar_limit(selected, selected_limit) {
    raise raw_error(
      "office.raw.invalid_part",
      "part selectors must use /name, part:/name, or alias:/name syntax",
      details=Json::object({
        "part": Json::string(bounded_raw_text(selector, 160)),
      }),
    )
  }
  let literal = selected[1:].to_owned()
  if literal == "" {
    raise raw_error(
      "office.raw.unknown_part", "part selector '/' does not name a package part",
    )
  }
  for component in literal.split("/") {
    if component == "" || component == "." || component == ".." {
      raise raw_error(
        "office.raw.invalid_part", "literal package part names must not contain empty, '.', or '..' components",
      )
    }
  }
  let literal_match = self.names.get(canonical_part_key(literal))
  let alias_matches = self.aliases.get(selected.to_lower())
  if mode == "part" {
    return match literal_match {
      Some(name) => name
      None =>
        raise raw_error(
          "office.raw.unknown_part",
          "package does not contain literal part '\{bounded_raw_text(selected, 160)}'",
          details=Json::object({
            "part": Json::string(bounded_raw_text(selector, 160)),
            "mode": Json::string("part"),
          }),
        )
    }
  }
  if mode == "alias" {
    return match alias_matches {
      Some([part]) => part
      Some(_) =>
        raise raw_error(
          "office.raw.ambiguous_part",
          "semantic alias '\{selected}' resolves to multiple package parts",
          details=Json::object({
            "part": Json::string(bounded_raw_text(selector, 160)),
            "mode": Json::string("alias"),
          }),
        )
      None =>
        raise raw_error(
          "office.raw.unknown_part",
          "package does not define semantic alias '\{bounded_raw_text(selected, 160)}'",
          details=Json::object({
            "part": Json::string(bounded_raw_text(selector, 160)),
            "mode": Json::string("alias"),
          }),
        )
    }
  }
  match (alias_matches, literal_match) {
    (Some([part]), Some(literal_part)) =>
      if canonical_part_key(part) == canonical_part_key(literal_part) {
        literal_part
      } else {
        raise raw_error(
          "office.raw.ambiguous_part",
          "selector '\{selected}' names both a semantic alias and a different literal package part; use alias: or part:",
          details=Json::object({
            "part": Json::string(bounded_raw_text(selector, 160)),
            "alias_selector": Json::string("alias:" + selected),
            "literal_selector": Json::string("part:" + selected),
          }),
        )
      }
    (Some([part]), None) => part
    (Some(_), _) =>
      raise raw_error(
        "office.raw.ambiguous_part",
        "semantic alias '\{selected}' resolves to multiple package parts",
        details=Json::object({
          "part": Json::string(bounded_raw_text(selector, 160)),
          "alias_selector": Json::string("alias:" + selected),
        }),
      )
    (None, Some(name)) => name
    (None, None) =>
      raise raw_error(
        "office.raw.unknown_part",
        "package does not contain part or alias '\{bounded_raw_text(selected, 160)}'",
        details=Json::object({
          "part": Json::string(bounded_raw_text(selector, 160)),
        }),
      )
  }
}

///|
fn RawPackage::part_bytes(
  self : RawPackage,
  name : String,
) -> Bytes raise RawError {
  match self.parts.get(canonical_part_key(name)) {
    Some(bytes) => bytes
    None =>
      raise raw_error(
        "office.raw.invalid_package",
        "package index lost part '/\{bounded_raw_text(name, 160)}'",
      )
  }
}

///|
fn RawPackage::part_info(
  self : RawPackage,
  name : String,
) -> RawPartInfo raise RawError {
  let aliases = self.part_aliases
    .get(canonical_part_key(name))
    .unwrap_or([])
    .copy()
  aliases.sort()
  let content_type = self.content_types.for_part(name)
  let bytes = self.part_bytes(name)
  {
    name,
    content_type,
    xml: content_type_is_xml(content_type),
    size: bytes.length(),
    aliases: ReadOnlyArray::from_array(aliases),
  }
}

///|
fn raw_json_string_size_bound(value : String) -> Int {
  let mut size = 2
  for character in value {
    let code = character.to_int()
    let encoded = if character == '"' || character == '\\' || code < 0x20 {
      6
    } else if code <= 0x7f {
      1
    } else if code <= 0x7ff {
      2
    } else if code <= 0xffff {
      3
    } else {
      4
    }
    if encoded > raw_max_inventory_serialization_bytes - size {
      return raw_max_inventory_serialization_bytes + 1
    }
    size = size + encoded
  }
  size
}

///|
fn check_inventory_serialization_budget(
  parts : ArrayView[RawPartInfo],
) -> Unit raise RawError {
  let mut estimated = 128
  for part in parts {
    let mut record = 96 +
      raw_json_string_size_bound(part.name) +
      raw_json_string_size_bound(part.content_type)
    for alias_name in part.aliases {
      let alias_size = raw_json_string_size_bound(alias_name) + 1
      if alias_size > raw_max_inventory_serialization_bytes - record {
        record = raw_max_inventory_serialization_bytes + 1
        break
      }
      record = record + alias_size
    }
    if record > raw_max_inventory_serialization_bytes - estimated {
      raise raw_error(
        "office.raw.resource_limit",
        "raw inventory exceeds the \{raw_max_inventory_serialization_bytes}-byte serialization budget",
        details=Json::object({
          "kind": Json::string("inventory_serialization_bytes"),
          "limit": Json::number(
            raw_max_inventory_serialization_bytes.to_double(),
          ),
          "actual": Json::number(
            (raw_max_inventory_serialization_bytes + 1).to_double(),
          ),
        }),
      )
    }
    estimated = estimated + record
  }
}

///|
/// Inventories all validated package parts in canonical name order.
pub fn raw_inventory(
  path : StringView,
  data : BytesView,
) -> RawInventory raise RawError {
  let pkg = open_raw_package(path, data)
  let parts : Array[RawPartInfo] = []
  for _, name in pkg.names {
    parts.push(pkg.part_info(name))
  }
  parts.sort_by(fn(left, right) { left.name.compare(right.name) })
  { format: pkg.format, parts: ReadOnlyArray::from_array(parts) }
}

///|
/// Identifies a package through the complete bounded raw-package boundary.
/// This byte-backed convenience API performs its own bounded ZIP read;
/// transaction identifiers should use `raw_identify_archive` instead.
pub fn raw_identify(
  path : StringView,
  data : BytesView,
) -> @office.DocumentFormat raise RawError {
  open_raw_package(path, data).format
}

///|
/// Identifies an already bounded, materialized archive without inflating its
/// package bytes again. It independently rechecks raw archive limits before
/// indexing. Transaction identifiers use this path so one input or candidate
/// has exactly one ZIP materialization.
pub fn raw_identify_archive(
  path : StringView,
  archive : @zip.Archive,
) -> @office.DocumentFormat raise RawError {
  open_raw_archive(path, archive).format
}

///|
/// Resolves and reads one validated package part.
pub fn raw_read(
  path : StringView,
  data : BytesView,
  part : String,
) -> RawPartData raise RawError {
  let pkg = open_raw_package(path, data)
  let name = pkg.resolve_part(part)
  let bytes = pkg.part_bytes(name)
  { format: pkg.format, info: pkg.part_info(name), bytes }
}
