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
  let fixed = FixedArray::from_array(data.to_array())
  let unzipped = @fzip.unzip_sync(fixed) catch {
    FzipError(message~, ..) =>
      raise InvalidZip(message="invalid ZIP archive: " + message)
  }
  let entries : Array[ZipWriteEntry] = []
  for item in unzipped {
    let (path, content) = item
    entries.push({ path, content: Bytes::from_array(content) })
  }
  entries
}

///|
fn zip_archive_from_write_entries(entries : Array[ZipWriteEntry]) -> ZipArchive {
  let map : Map[String, Bytes] = {}
  for entry in entries {
    map[entry.path] = entry.content
  }
  { entries: map }
}

///|
fn replace_or_append_zip_entry(
  entries : Array[ZipWriteEntry],
  path : String,
  content : Bytes,
) -> Unit {
  for index in 0..<entries.length() {
    if entries[index].path == path {
      entries[index] = { path, content }
      return
    }
  }
  entries.push({ path, content })
}

///|
fn zip_write_entries(entries : Array[ZipWriteEntry]) -> Bytes {
  let files : Array[(String, FixedArray[Byte])] = []
  for entry in entries {
    files.push((entry.path, FixedArray::from_array(entry.content.to_array())))
  }
  Bytes::from_array(@fzip.zip_sync(files))
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
) -> Array[Relationship] {
  let updated : Array[Relationship] = []
  let mut found = false
  for relationship in relationships {
    if relationship.id == "rMammothStyleMap" {
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
  let builder = StringBuilder()
  builder.write_string(
    "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>",
  )
  builder.write_string(
    "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">",
  )
  for relationship in relationships {
    builder.write_string("<Relationship")
    write_xml_attribute(builder, "Id", relationship.id)
    write_xml_attribute(builder, "Type", relationship.relationship_type)
    write_xml_attribute(builder, "Target", relationship.target)
    match relationship.target_mode {
      Some(target_mode) =>
        write_xml_attribute(builder, "TargetMode", target_mode)
      None => ()
    }
    builder.write_string("/>")
  }
  builder.write_string("</Relationships>")
  builder.to_string()
}

///|
fn write_content_types_with_embedded_style_map(
  zip : ZipArchive,
) -> String raise DocxError {
  let path = "[Content_Types].xml"
  let root = read_xml_string(
    read_required_zip_text(zip, path),
    namespace_map=office_namespace_map(),
  )
  let entries = read_content_type_xml_entries(root)
  write_content_types_xml(upsert_embedded_style_map_content_type(entries))
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
          "Default" => {
            let extension = element.attributes.get_or_default("Extension", "")
            let content_type = element.attributes.get_or_default(
              "ContentType", "",
            )
            if extension != "" && content_type != "" {
              entries.push(DefaultContentType(extension~, content_type~))
            }
          }
          "Override" => {
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
) -> Array[ContentTypeXmlEntry] {
  let updated : Array[ContentTypeXmlEntry] = []
  let mut found = false
  for entry in entries {
    match entry {
      OverrideContentType(part_name="/mammoth/style-map", ..) => {
        updated.push(embedded_style_map_content_type())
        found = true
      }
      _ => updated.push(entry)
    }
  }
  if !found {
    updated.push(embedded_style_map_content_type())
  }
  updated
}

///|
fn embedded_style_map_content_type() -> ContentTypeXmlEntry {
  OverrideContentType(
    part_name="/mammoth/style-map",
    content_type="text/prs.mammoth.style-map",
  )
}

///|
fn write_content_types_xml(entries : Array[ContentTypeXmlEntry]) -> String {
  let builder = StringBuilder()
  builder.write_string(
    "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>",
  )
  builder.write_string(
    "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\">",
  )
  for entry in entries {
    match entry {
      DefaultContentType(extension~, content_type~) => {
        builder.write_string("<Default")
        write_xml_attribute(builder, "Extension", extension)
        write_xml_attribute(builder, "ContentType", content_type)
        builder.write_string("/>")
      }
      OverrideContentType(part_name~, content_type~) => {
        builder.write_string("<Override")
        write_xml_attribute(builder, "PartName", part_name)
        write_xml_attribute(builder, "ContentType", content_type)
        builder.write_string("/>")
      }
    }
  }
  builder.write_string("</Types>")
  builder.to_string()
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

///|
fn write_xml_attribute(
  builder : StringBuilder,
  name : String,
  value : String,
) -> Unit {
  builder.write_string(" ")
  builder.write_string(name)
  builder.write_string("=\"")
  builder.write_string(escape_html_attribute(value))
  builder.write_string("\"")
}
