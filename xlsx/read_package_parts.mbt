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
) -> String raise XlsxError {
  let root_rels_path = actual_archive_part_path(part_names, root_rels_part_path)
  let root_rels_xml = match archive.get(root_rels_path) {
    Some(bytes) => decode(bytes)
    None => raise MissingPart(path=root_rels_path)
  }
  let office_document_type = transitional_office_relationship_prefix +
    "officeDocument"
  let targets = parse_internal_relationship_targets(
    root_rels_xml, office_document_type,
  )
  if targets.length() > 1 {
    raise InvalidXml(msg="root relationships contain multiple workbook targets")
  }
  match first_relationship_target(targets) {
    Some(target) => {
      let part_name = archive_path_from_part_name(target)
      normalize_rel_part_path(part_name)
    }
    None => raise InvalidXml(msg="root workbook relationship missing")
  }
}

///|
fn workbook_content_type_is_supported(value : StringView) -> Bool {
  for candidate in workbook_content_type_candidates() {
    if value == candidate {
      return true
    }
  }
  false
}

///|
fn resolve_workbook_xml_part_path(
  archive : @zip.Archive,
  part_names : Map[String, String],
  decode : (BytesView) -> String raise XlsxError,
) -> String raise XlsxError {
  let workbook_part = workbook_part_from_root_relationships(
    archive, part_names, decode,
  )
  let content_types_path = actual_archive_part_path(
    part_names, content_types_part_path,
  )
  let content_types_xml = match archive.get(content_types_path) {
    Some(content_types_bytes) => decode(content_types_bytes)
    None => raise MissingPart(path=content_types_path)
  }
  let content_type = @ooxml.find_part_content_type(
    content_types_xml, workbook_part,
  ) catch {
    InvalidXml(msg~) => raise InvalidXml(msg~)
  }
  match content_type {
    Some(value) if workbook_content_type_is_supported(value) => workbook_part
    Some(_) => raise InvalidXml(msg="root workbook content type is invalid")
    None => raise InvalidXml(msg="root workbook content type is missing")
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
test "read package parts: root relationship is required" {
  let archive = @zip.Archive::new()
  try resolve_workbook_xml_part_path_for_test(archive) catch {
    MissingPart(path~) => inspect(path, content="_rels/.rels")
    _ => fail("unexpected missing-root error")
  } noraise {
    _ => fail("expected missing root relationships")
  }
}

///|
test "read package parts: workbook path follows the root relationship" {
  let archive = @zip.Archive::new()
  let content_types =
    #|<?xml version="1.0" encoding="UTF-8"?>
    #|<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
    #|  <Override PartName="/xl/workbook2.xml" ContentType="application/vnd.ms-excel.sheet.macroEnabled.main+xml"/>
    #|</Types>
    #|
  archive.add(content_types_part_path, @encoding/utf8.encode(content_types))
  let root_relationships =
    #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
    #|  <Relationship Id="main" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook2.xml"/>
    #|</Relationships>
  archive.add(root_rels_part_path, @encoding/utf8.encode(root_relationships))
  inspect(
    resolve_workbook_xml_part_path_for_test(archive),
    content="xl/workbook2.xml",
  )
}

///|
test "read package parts: external workbook relationship is never resolved as a part" {
  let archive = @zip.Archive::new()
  let content_types =
    #|<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
    #|  <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
    #|</Types>
  let root_relationships =
    #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
    #|  <Relationship Id="main" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml" TargetMode="External"/>
    #|</Relationships>
  archive.add(content_types_part_path, @encoding/utf8.encode(content_types))
  archive.add(root_rels_part_path, @encoding/utf8.encode(root_relationships))
  try resolve_workbook_xml_part_path_for_test(archive) catch {
    InvalidXml(msg~) =>
      inspect(msg, content="root workbook relationship missing")
    _ => fail("unexpected external-root error")
  } noraise {
    _ => fail("expected external root relationship rejection")
  }
}

///|
test "read package parts: root target must have a workbook content type" {
  let archive = @zip.Archive::new()
  let content_types =
    #|<?xml version="1.0" encoding="UTF-8"?>
    #|<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
    #|  <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
    #|</Types>
    #|
  archive.add(content_types_part_path, @encoding/utf8.encode(content_types))
  let root_relationships =
    #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
    #|  <Relationship Id="main" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
    #|</Relationships>
  archive.add(root_rels_part_path, @encoding/utf8.encode(root_relationships))
  try resolve_workbook_xml_part_path_for_test(archive) catch {
    InvalidXml(msg~) =>
      inspect(msg, content="root workbook content type is missing")
    _ => fail("unexpected workbook content-type error")
  } noraise {
    _ => fail("expected missing workbook content type")
  }
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
  let root_relationships =
    #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
    #|  <Relationship Id="main" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
    #|</Relationships>
  archive.add(root_rels_part_path, @encoding/utf8.encode(root_relationships))
  let result = Ok(resolve_workbook_xml_part_path_for_test(archive)) catch {
    e => Err(e)
  }
  match result {
    Err(InvalidXml(msg~)) => inspect(msg, content="XML start tag is not closed")
    _ => fail("expected content type override tag not closed")
  }
}

///|
test "read package parts: invalid root workbook target raises InvalidXml" {
  let archive = @zip.Archive::new()
  let invalid_part_name =
    #|<?xml version="1.0" encoding="UTF-8"?>
    #|<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
    #|  <Override PartName="/" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
    #|</Types>
    #|
  archive.add(content_types_part_path, @encoding/utf8.encode(invalid_part_name))
  let root_relationships =
    #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
    #|  <Relationship Id="main" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="/"/>
    #|</Relationships>
  archive.add(root_rels_part_path, @encoding/utf8.encode(root_relationships))
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
test "read package parts: stale workbook override cannot redirect the root relationship" {
  let archive = @zip.Archive::new()
  let content_types =
    #|<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
    #|  <Override PartName="/decoy/book.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
    #|  <Override PartName="/actual/book.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
    #|</Types>
  let root_relationships =
    #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
    #|  <Relationship Id="main" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="actual/book.xml"/>
    #|</Relationships>
  archive.add(content_types_part_path, @encoding/utf8.encode(content_types))
  archive.add(root_rels_part_path, @encoding/utf8.encode(root_relationships))
  inspect(
    resolve_workbook_xml_part_path_for_test(archive),
    content="actual/book.xml",
  )
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
