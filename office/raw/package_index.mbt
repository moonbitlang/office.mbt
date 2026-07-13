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
  content_types : ContentTypeTable
  aliases : Map[String, Array[String]]
  part_aliases : Map[String, Array[String]]
  mut main_part : String
}

///|
fn canonical_part_key(value : StringView) -> String {
  value.to_owned().to_lower()
}

///|
fn xml_name_local(value : String) -> String {
  if value.has_prefix("{") {
    match value.find("}") {
      Some(close) if close + 1 < value.length() => value[close + 1:].to_owned()
      _ => value
    }
  } else {
    value
  }
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
fn xml_attribute_by_local(
  element : @xml.XmlElement,
  local_name : String,
  namespaced? : Bool = false,
) -> String? {
  for name, value in element.attributes {
    if xml_name_local(name) == local_name &&
      (!namespaced || xml_name_uri(name) != "") {
      return Some(value)
    }
  }
  None
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
fn parse_xml_bytes(
  name : String,
  bytes : BytesView,
) -> @xml.XmlElement raise RawError {
  let text = decode_xml_bytes(name, bytes)
  @xml.read_xml_string_strict(text) catch {
    _ =>
      raise raw_error(
        "office.raw.invalid_xml",
        "part '/\{name}' is not well-formed strict XML",
      )
  }
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
fn parse_content_types(
  archive : @zip.Archive,
) -> ContentTypeTable raise RawError {
  let bytes = match archive.get("[Content_Types].xml") {
    Some(value) => value
    None =>
      raise raw_error(
        "office.raw.invalid_package", "package is missing /[Content_Types].xml",
      )
  }
  let root = parse_xml_bytes("[Content_Types].xml", bytes)
  let defaults : Map[String, String] = Map([])
  let overrides : Map[String, String] = Map([])
  for child in root.children {
    match child {
      XmlElement(element) =>
        match xml_name_local(element.name) {
          "Default" => {
            let extension = element.attributes.get("Extension")
            let content_type = element.attributes.get("ContentType")
            match (extension, content_type) {
              (Some(ext), Some(kind)) => defaults[ext.to_lower()] = kind
              _ => ()
            }
          }
          "Override" => {
            let part = element.attributes.get("PartName")
            let content_type = element.attributes.get("ContentType")
            match (part, content_type) {
              (Some(name), Some(kind)) =>
                match normalize_manifest_part(name) {
                  Some(normalized) =>
                    overrides[canonical_part_key(normalized)] = kind
                  None => ()
                }
              _ => ()
            }
          }
          _ => ()
        }
      _ => ()
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
fn relationship_role(kind : String) -> String {
  match kind.rev_find("/") {
    Some(slash) if slash + 1 < kind.length() => kind[slash + 1:].to_owned()
    _ => kind
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
fn parse_relationships(
  pkg : RawPackage,
  source : String,
) -> Array[RawRelationship] raise RawError {
  let relationship_part = relationships_part_for(source)
  let canonical = match pkg.names.get(canonical_part_key(relationship_part)) {
    Some(value) => value
    None => return []
  }
  let bytes = pkg.archive.get(canonical).unwrap()
  let root = parse_xml_bytes(canonical, bytes)
  let output : Array[RawRelationship] = []
  for child in root.children {
    match child {
      XmlElement(element) if xml_name_local(element.name) == "Relationship" => {
        let id = element.attributes.get("Id")
        let kind = element.attributes.get("Type")
        let target = element.attributes.get("Target")
        match (id, kind, target) {
          (Some(id), Some(kind), Some(target)) => {
            let external = element.attributes.get("TargetMode")
              is Some("External")
            if external {
              output.push({ id, kind, target, external: true })
            } else {
              match normalize_relationship_target(source_base(source), target) {
                Some(resolved) =>
                  output.push({ id, kind, target: resolved, external: false })
                None =>
                  raise raw_error(
                    "office.raw.invalid_relationship",
                    "relationship '\{id}' in '/\{canonical}' has an invalid target",
                  )
              }
            }
          }
          _ => ()
        }
      }
      _ => ()
    }
  }
  output
}

///|
fn add_alias(pkg : RawPackage, alias_name : String, part : String) -> Unit {
  if alias_name.length() == 0 || alias_name.length() > raw_max_alias_length {
    return
  }
  let key = alias_name.to_lower()
  if !key.has_prefix("/") || !pkg.names.contains(canonical_part_key(part)) {
    return
  }
  match pkg.aliases.get(key) {
    Some(parts) => if !parts.contains(part) { parts.push(part) }
    None => pkg.aliases[key] = [part]
  }
  match pkg.part_aliases.get(canonical_part_key(part)) {
    Some(aliases) =>
      if !aliases.contains(alias_name) {
        aliases.push(alias_name)
      }
    None => pkg.part_aliases[canonical_part_key(part)] = [alias_name]
  }
}

///|
fn find_main_part(pkg : RawPackage) -> String raise RawError {
  let relationships = parse_relationships(pkg, "")
  let found : Array[String] = []
  for relationship in relationships {
    if !relationship.external &&
      relationship_role(relationship.kind) == "officeDocument" {
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
fn relationship_target_by_id(
  relationships : ArrayView[RawRelationship],
  id : String,
) -> String? {
  for relationship in relationships {
    if relationship.id == id && !relationship.external {
      return Some(relationship.target)
    }
  }
  None
}

///|
fn add_singleton_relationship_aliases(
  pkg : RawPackage,
  relationships : ArrayView[RawRelationship],
  aliases : Map[String, String],
) -> Unit {
  for relationship in relationships {
    if !relationship.external {
      match aliases.get(relationship_role(relationship.kind)) {
        Some(alias_name) => add_alias(pkg, alias_name, relationship.target)
        None => ()
      }
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
    if relationship.external {
      continue
    }
    match relationship_role(relationship.kind) {
      "header" => {
        header = header + 1
        add_alias(pkg, "/header[\{header}]", relationship.target)
      }
      "footer" => {
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
  let mut sheet_index = 0
  for sheets_child in workbook.children {
    match sheets_child {
      XmlElement(sheets) if xml_name_local(sheets.name) == "sheets" =>
        for child in sheets.children {
          match child {
            XmlElement(sheet) if xml_name_local(sheet.name) == "sheet" => {
              let name = sheet.attributes.get("name")
              let relationship_id = xml_attribute_by_local(
                sheet,
                "id",
                namespaced=true,
              )
              match (name, relationship_id) {
                (Some(name), Some(id)) =>
                  match relationship_target_by_id(relationships, id) {
                    Some(part) => {
                      sheet_index = sheet_index + 1
                      add_alias(pkg, "/sheet[\{sheet_index}]", part)
                      add_alias(pkg, "/" + name, part)
                      let rels = relationships_part_for(part)
                      add_alias(
                        pkg,
                        "/sheet[\{sheet_index}]/relationships",
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
fn package_from_archive(
  format : @office.DocumentFormat,
  archive : @zip.Archive,
) -> RawPackage raise RawError {
  let names : Map[String, String] = Map([])
  for entry in archive.entries() {
    names[canonical_part_key(entry.name())] = entry.name()
  }
  let content_types = parse_content_types(archive)
  let pkg = RawPackage::{
    format,
    archive,
    names,
    content_types,
    aliases: Map([]),
    part_aliases: Map([]),
    main_part: "",
  }
  pkg.main_part = find_main_part(pkg)
  add_alias(pkg, "/content-types", "[Content_Types].xml")
  add_alias(pkg, "/relationships", "_rels/.rels")
  match format {
    Docx => add_docx_aliases(pkg)
    Xlsx => add_xlsx_aliases(pkg)
  }
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
    _ =>
      raise raw_error(
        "office.raw.invalid_package", "package is not a bounded readable ZIP archive",
      )
  }
}

///|
fn open_raw_package(
  path : StringView,
  data : BytesView,
) -> RawPackage raise RawError {
  let archive = read_bounded_archive(data)
  let format = @office.detect_archive_format(path, archive) catch {
    error =>
      raise raw_error(
        "office.raw.invalid_package",
        "package failed portable Office validation: \{error}",
      )
  }
  package_from_archive(format, archive)
}

///|
fn open_raw_package_for_format(
  format : @office.DocumentFormat,
  data : BytesView,
) -> RawPackage raise RawError {
  let archive = read_bounded_archive(data)
  let _ = @office.detect_archive_format(raw_path_for_format(format), archive) catch {
    error =>
      raise raw_error(
        "office.raw.invalid_package",
        "package failed portable Office validation: \{error}",
      )
  }
  package_from_archive(format, archive)
}

///|
fn validate_part_selector(value : String) -> Unit raise RawError {
  if value.length() == 0 ||
    value.length() > raw_max_alias_length ||
    !value.has_prefix("/") ||
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
  let alias_matches = self.aliases.get(selector.to_lower())
  match alias_matches {
    Some([part]) => return part
    Some(parts) if parts.length() > 1 =>
      raise raw_error(
        "office.raw.ambiguous_part",
        "part alias '\{selector}' resolves to multiple package parts",
        details=Json::object({ "part": Json::string(selector) }),
      )
    _ => ()
  }
  let literal = selector[1:].to_owned()
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
  match self.names.get(canonical_part_key(literal)) {
    Some(name) => name
    None =>
      raise raw_error(
        "office.raw.unknown_part",
        "package does not contain part '\{bounded_raw_text(selector, 160)}'",
        details=Json::object({
          "part": Json::string(bounded_raw_text(selector, 160)),
        }),
      )
  }
}

///|
fn RawPackage::part_info(self : RawPackage, name : String) -> RawPartInfo {
  let aliases = self.part_aliases
    .get(canonical_part_key(name))
    .unwrap_or([])
    .copy()
  aliases.sort()
  let content_type = self.content_types.for_part(name)
  let bytes = self.archive.get(name).unwrap()
  {
    name,
    content_type,
    xml: content_type_is_xml(content_type),
    size: bytes.length(),
    aliases: ReadOnlyArray::from_array(aliases),
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
  for entry in pkg.archive.entries() {
    parts.push(pkg.part_info(entry.name()))
  }
  parts.sort_by(fn(left, right) { left.name.compare(right.name) })
  { format: pkg.format, parts: ReadOnlyArray::from_array(parts) }
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
  let bytes = pkg.archive.get(name).unwrap()
  { format: pkg.format, info: pkg.part_info(name), bytes }
}
