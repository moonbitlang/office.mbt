///|
priv struct ZipWriteEntry {
  path : String
  content : Bytes
}

///|
priv enum ContentTypeXmlEntry {
  DefaultContentType(extension~ : String, content_type~ : String)
  OverrideContentType(part_name~ : String, content_type~ : String)
}

///|
/// Embeds or replaces the DOCX style map part.
pub fn embed_style_map(
  docx : BytesView,
  style_map : String,
) -> Bytes raise DocxError {
  let entries = unzip_write_entries(docx)
  let zip = zip_archive_from_write_entries(entries)
  let relationships = write_relationships_with_embedded_style_map(zip)
  let content_types = write_content_types_with_embedded_style_map(zip)
  replace_or_append_zip_entry(
    entries,
    "mammoth/style-map",
    @utf8.encode(style_map),
  )
  replace_or_append_zip_entry(
    entries,
    "word/_rels/document.xml.rels",
    @utf8.encode(relationships),
  )
  replace_or_append_zip_entry(
    entries,
    "[Content_Types].xml",
    @utf8.encode(content_types),
  )
  zip_write_entries(entries)
}

///|
fn unzip_write_entries(
  data : BytesView,
) -> Array[ZipWriteEntry] raise DocxError {
  let archive = @mbtzip.read(data) catch {
    err => raise InvalidZip(message="invalid ZIP archive: \{repr(err)}")
  }
  let entries : Array[ZipWriteEntry] = []
  for entry in archive.entries() {
    entries.push({ path: entry.name(), content: entry.data().to_owned() })
  }
  entries
}

///|
fn zip_archive_from_write_entries(
  entries : Array[ZipWriteEntry],
) -> ZipArchive raise DocxError {
  let map : StableStringMap[BytesView] = SortedMap([])
  let physical_names : StableStringMap[String] = SortedMap([])
  for entry in entries {
    let canonical_name = entry.path.to_lower()
    match physical_names.get(canonical_name) {
      Some(existing) if existing == entry.path =>
        raise InvalidZip(message="duplicate ZIP entry name: \{entry.path}")
      Some(existing) =>
        raise InvalidZip(
          message="duplicate ZIP entry names after case normalization: \{existing}, \{entry.path}",
        )
      None => ()
    }
    physical_names[canonical_name] = entry.path
    map[entry.path] = entry.content
  }
  @zip.zip_archive_entries(map.iter())
}

///|
fn replace_or_append_zip_entry(
  entries : Array[ZipWriteEntry],
  path : String,
  content : Bytes,
) -> Unit {
  let canonical_path = path.to_lower()
  for index in 0..<entries.length() {
    if entries[index].path.to_lower() == canonical_path {
      entries[index] = { path: entries[index].path, content }
      return
    }
  }
  entries.push({ path, content })
}

///|
fn zip_write_entries(entries : Array[ZipWriteEntry]) -> Bytes raise DocxError {
  let archive = @mbtzip.Archive::new()
  for entry in entries {
    archive.add(entry.path, entry.content, compression=Deflate)
  }
  @mbtzip.write(archive) catch {
    err => raise InvalidZip(message="failed to write ZIP archive: \{repr(err)}")
  }
}

///|
fn write_relationships_with_embedded_style_map(
  zip : ZipArchive,
) -> String raise DocxError {
  let path = "word/_rels/document.xml.rels"
  let root = read_xml_string(
    read_required_zip_text(zip, path),
    namespace_map=office_namespace_map(),
  )
  let relationships = read_relationships_xml(root).relationships
  write_relationships_xml(upsert_embedded_style_map_relationship(relationships))
}

///|
fn upsert_embedded_style_map_relationship(
  relationships : Array[Relationship],
) -> Array[Relationship] raise DocxError {
  let updated : Array[Relationship] = []
  let mut found = false
  for relationship in relationships {
    if relationship.id == "rMammothStyleMap" {
      if found {
        raise InvalidXml(
          message="duplicate embedded style-map relationship Id: rMammothStyleMap",
        )
      }
      updated.push(embedded_style_map_relationship())
      found = true
    } else {
      updated.push(relationship)
    }
  }
  if !found {
    updated.push(embedded_style_map_relationship())
  }
  updated
}

///|
fn embedded_style_map_relationship() -> Relationship {
  {
    id: "rMammothStyleMap",
    relationship_type: "http://schemas.zwobble.org/mammoth/style-map",
    target: "/mammoth/style-map",
    target_mode: None,
  }
}

///|
fn write_relationships_xml(relationships : Array[Relationship]) -> String {
  let children : Array[XmlNode] = []
  for relationship in relationships {
    let attributes : Map[String, String] = {
      "Id": relationship.id,
      "Type": relationship.relationship_type,
      "Target": relationship.target,
    }
    match relationship.target_mode {
      Some(target_mode) => attributes["TargetMode"] = target_mode
      None => ()
    }
    children.push(XmlElement(xml_element("Relationship", attributes~)))
  }
  write_xml_string(xml_element("Relationships", children~), namespaces={
    "": "http://schemas.openxmlformats.org/package/2006/relationships",
  })
}

///|
fn write_content_types_with_embedded_style_map(
  zip : ZipArchive,
) -> String raise DocxError {
  let path = "[Content_Types].xml"
  let style_map_part_name = match zip.resolve_path("mammoth/style-map") {
    Some(physical_path) => "/" + physical_path
    None => "/mammoth/style-map"
  }
  let root = read_xml_string(
    read_required_zip_text(zip, path),
    namespace_map=office_namespace_map(),
  )
  let entries = read_content_type_xml_entries(root)
  write_content_types_xml(
    upsert_embedded_style_map_content_type(entries, style_map_part_name),
  )
}

///|
fn read_content_type_xml_entries(
  root : XmlElement,
) -> Array[ContentTypeXmlEntry] {
  let entries : Array[ContentTypeXmlEntry] = []
  for node in root.children {
    match node {
      XmlElement(element) =>
        match element.name {
          "content-types:Default" => {
            let extension = element.attributes.get_or_default("Extension", "")
            let content_type = element.attributes.get_or_default(
              "ContentType", "",
            )
            if extension != "" && content_type != "" {
              entries.push(DefaultContentType(extension~, content_type~))
            }
          }
          "content-types:Override" => {
            let part_name = element.attributes.get_or_default("PartName", "")
            let content_type = element.attributes.get_or_default(
              "ContentType", "",
            )
            if part_name != "" && content_type != "" {
              entries.push(OverrideContentType(part_name~, content_type~))
            }
          }
          _ => ()
        }
      _ => ()
    }
  }
  entries
}

///|
fn upsert_embedded_style_map_content_type(
  entries : Array[ContentTypeXmlEntry],
  style_map_part_name : String,
) -> Array[ContentTypeXmlEntry] raise DocxError {
  let updated : Array[ContentTypeXmlEntry] = []
  let mut found = false
  for entry in entries {
    match entry {
      OverrideContentType(part_name~, content_type~) =>
        if is_embedded_style_map_part_name(part_name) {
          if found {
            raise InvalidXml(
              message="duplicate embedded style-map content-type override after OPC path normalization",
            )
          }
          updated.push(embedded_style_map_content_type(style_map_part_name))
          found = true
        } else {
          updated.push(OverrideContentType(part_name~, content_type~))
        }
      _ => updated.push(entry)
    }
  }
  if !found {
    updated.push(embedded_style_map_content_type(style_map_part_name))
  }
  updated
}

///|
fn is_embedded_style_map_part_name(part_name : String) -> Bool {
  if !part_name.has_prefix("/") {
    return false
  }
  match @opc.resolve_part_target("", part_name) {
    Some(path) =>
      @opc.part_name_key(path) == @opc.part_name_key("mammoth/style-map")
    None => false
  }
}

///|
fn embedded_style_map_content_type(part_name : String) -> ContentTypeXmlEntry {
  OverrideContentType(part_name~, content_type="text/prs.mammoth.style-map")
}

///|
fn write_content_types_xml(entries : Array[ContentTypeXmlEntry]) -> String {
  let children : Array[XmlNode] = []
  for entry in entries {
    match entry {
      DefaultContentType(extension~, content_type~) =>
        children.push(
          XmlElement(
            xml_element("Default", attributes={
              "Extension": extension,
              "ContentType": content_type,
            }),
          ),
        )
      OverrideContentType(part_name~, content_type~) =>
        children.push(
          XmlElement(
            xml_element("Override", attributes={
              "PartName": part_name,
              "ContentType": content_type,
            }),
          ),
        )
    }
  }
  write_xml_string(xml_element("Types", children~), namespaces={
    "": "http://schemas.openxmlformats.org/package/2006/content-types",
  })
}

///|
fn read_required_zip_text(
  zip : ZipArchive,
  path : String,
) -> String raise DocxError {
  match zip.read_text(path) {
    Some(text) => text
    None => raise MissingPart(message="missing DOCX part: " + path)
  }
}
