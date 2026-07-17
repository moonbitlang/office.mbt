///|
fn workbook_content_type_candidates() -> Array[String] {
  [
    ct_workbook, ct_workbook_macro, ct_workbook_addin_macro, ct_workbook_template,
    ct_workbook_template_macro,
  ]
}

///|
fn workbook_part_from_root_relationships(
  archive : @zip.Archive,
  part_names : Map[String, String],
  decode : (BytesView) -> String raise XlsxError,
) -> String? raise XlsxError {
  let root_rels_path = actual_archive_part_path(part_names, root_rels_part_path)
  let root_rels_xml = match archive.get(root_rels_path) {
    Some(bytes) => decode(bytes)
    None => return None
  }
  let office_document_type = transitional_office_relationship_prefix +
    "officeDocument"
  let targets = parse_relationship_targets(root_rels_xml, office_document_type)
  if targets.length() > 1 {
    raise InvalidXml(msg="root relationships contain multiple workbook targets")
  }
  match first_relationship_target(targets) {
    Some(target) => {
      let part_name = archive_path_from_part_name(unescape_xml_text(target))
      Some(normalize_rel_part_path(part_name))
    }
    None => None
  }
}

///|
fn resolve_workbook_xml_part_path(
  archive : @zip.Archive,
  part_names : Map[String, String],
  decode : (BytesView) -> String raise XlsxError,
) -> String raise XlsxError {
  let content_types_path = actual_archive_part_path(
    part_names, content_types_part_path,
  )
  match archive.get(content_types_path) {
    Some(content_types_bytes) => {
      let content_types_xml = decode(content_types_bytes)
      let workbook_part_name = @ooxml.find_override_part_by_content_types(
        content_types_xml,
        workbook_content_type_candidates(),
      ) catch {
        InvalidXml(msg~) => raise InvalidXml(msg~)
      }
      match workbook_part_name {
        Some(part_name) => archive_path_from_part_name(part_name)
        None =>
          workbook_part_from_root_relationships(archive, part_names, decode).unwrap_or(
            workbook_part_path,
          )
      }
    }
    None =>
      workbook_part_from_root_relationships(archive, part_names, decode).unwrap_or(
        workbook_part_path,
      )
  }
}

///|
fn decode_utf8_or_invalid_xml(bytes : BytesView) -> String raise XlsxError {
  @encoding/utf8.decode(bytes) catch {
    _ => raise InvalidXml(msg="invalid utf8")
  }
}

///|
fn resolve_workbook_xml_part_path_for_test(
  archive : @zip.Archive,
) -> String raise XlsxError {
  resolve_workbook_xml_part_path(
    archive,
    archive_part_name_index(archive),
    decode_utf8_or_invalid_xml,
  )
}

///|
test "read package parts: default workbook path when [Content_Types] missing" {
  let archive = @zip.Archive::new()
  inspect(
    resolve_workbook_xml_part_path_for_test(archive),
    content="xl/workbook.xml",
  )
}

///|
test "read package parts: workbook path resolved from [Content_Types] override" {
  let archive = @zip.Archive::new()
  let content_types =
    #|<?xml version="1.0" encoding="UTF-8"?>
    #|<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
    #|  <Override PartName="/xl/workbook2.xml" ContentType="application/vnd.ms-excel.sheet.macroEnabled.main+xml"/>
    #|</Types>
    #|
  archive.add(content_types_part_path, @encoding/utf8.encode(content_types))
  inspect(
    resolve_workbook_xml_part_path_for_test(archive),
    content="xl/workbook2.xml",
  )
}

///|
test "read package parts: fallback to default when workbook content type absent" {
  let archive = @zip.Archive::new()
  let content_types =
    #|<?xml version="1.0" encoding="UTF-8"?>
    #|<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
    #|  <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
    #|</Types>
    #|
  archive.add(content_types_part_path, @encoding/utf8.encode(content_types))
  inspect(
    resolve_workbook_xml_part_path_for_test(archive),
    content="xl/workbook.xml",
  )
}

///|
test "read package parts: malformed [Content_Types] raises InvalidXml" {
  let archive = @zip.Archive::new()
  let malformed =
    #|<?xml version="1.0" encoding="UTF-8"?>
    #|<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
    #|  <Override PartName="/xl/workbook.xml" 
    #|</Types>
    #|
  archive.add(content_types_part_path, @encoding/utf8.encode(malformed))
  let result = Ok(resolve_workbook_xml_part_path_for_test(archive)) catch {
    e => Err(e)
  }
  match result {
    Err(InvalidXml(msg~)) =>
      inspect(msg, content="content type override tag not closed")
    _ => fail("expected content type override tag not closed")
  }
}

///|
test "read package parts: invalid workbook part name raises InvalidXml" {
  let archive = @zip.Archive::new()
  let invalid_part_name =
    #|<?xml version="1.0" encoding="UTF-8"?>
    #|<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
    #|  <Override PartName="/" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
    #|</Types>
    #|
  archive.add(content_types_part_path, @encoding/utf8.encode(invalid_part_name))
  let result = Ok(resolve_workbook_xml_part_path_for_test(archive)) catch {
    e => Err(e)
  }
  match result {
    Err(InvalidXml(msg~)) =>
      inspect(msg, content="content type part name empty")
    _ => fail("expected content type part name empty")
  }
}

///|
test "read package parts: default-declared workbook follows the root relationship" {
  let archive = @zip.Archive::new()
  let content_types =
    #|<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
    #|  <Default Extension="xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
    #|</Types>
  let root_relationships =
    #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
    #|  <Relationship Id="main" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="custom/book.xml"/>
    #|</Relationships>
  archive.add(content_types_part_path, @encoding/utf8.encode(content_types))
  archive.add(root_rels_part_path, @encoding/utf8.encode(root_relationships))
  inspect(
    resolve_workbook_xml_part_path_for_test(archive),
    content="custom/book.xml",
  )
}
