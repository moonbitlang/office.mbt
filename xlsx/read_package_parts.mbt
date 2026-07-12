///|
fn workbook_content_type_candidates() -> Array[String] {
  [
    ct_workbook, ct_workbook_macro, ct_workbook_addin_macro, ct_workbook_template,
    ct_workbook_template_macro,
  ]
}

///|
fn resolve_workbook_xml_part_path(
  archive : @zip.Archive,
  decode : (Bytes) -> String raise XlsxError,
) -> String raise XlsxError {
  match archive.get(content_types_part_path) {
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
        None => workbook_part_path
      }
    }
    None => workbook_part_path
  }
}

///|
fn decode_utf8_or_invalid_xml(bytes : Bytes) -> String raise XlsxError {
  @encoding/utf8.decode(bytes) catch {
    _ => raise InvalidXml(msg="invalid utf8")
  }
}

///|
test "read package parts: default workbook path when [Content_Types] missing" {
  let archive = @zip.Archive::new()
  inspect(
    resolve_workbook_xml_part_path(archive, decode_utf8_or_invalid_xml),
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
    resolve_workbook_xml_part_path(archive, decode_utf8_or_invalid_xml),
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
    resolve_workbook_xml_part_path(archive, decode_utf8_or_invalid_xml),
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
  let result = Ok(
    resolve_workbook_xml_part_path(archive, decode_utf8_or_invalid_xml),
  ) catch {
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
  let result = Ok(
    resolve_workbook_xml_part_path(archive, decode_utf8_or_invalid_xml),
  ) catch {
    e => Err(e)
  }
  match result {
    Err(InvalidXml(msg~)) =>
      inspect(msg, content="content type part name empty")
    _ => fail("expected content type part name empty")
  }
}
