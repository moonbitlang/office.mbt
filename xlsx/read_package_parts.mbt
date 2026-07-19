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
  content_types : @ooxml.PackageContentTypes,
  decode : (BytesView) -> String raise XlsxError,
  budget? : ReadBudget,
  cancelled? : () -> Bool = () => false,
) -> String raise XlsxError {
  let root_rels_path = actual_archive_part_path(part_names, root_rels_part_path)
  let root_rels_xml = decode(
    load_relationship_part(
      archive,
      content_types,
      root_rels_path,
      "root relationships",
      cancelled~,
    ),
  )
  let office_document_type = transitional_office_relationship_prefix +
    "officeDocument"
  let targets = parse_internal_relationship_targets(
    root_rels_xml,
    office_document_type,
    budget?,
    cancelled~,
  )
  if targets.length() > 1 {
    raise InvalidXml(msg="root relationships contain multiple workbook targets")
  }
  match first_relationship_target(targets) {
    Some(target) => {
      validate_relationship_target_uri(target, cancelled~)
      let part_name = archive_path_from_part_name(target)
      normalize_rel_part_path(part_name, cancelled~)
    }
    None => raise InvalidXml(msg="root workbook relationship missing")
  }
}

///|
fn workbook_content_type_is_supported(value : StringView) -> Bool {
  let normalized = value.to_owned().to_lower()
  for candidate in workbook_content_type_candidates() {
    if normalized == candidate.to_lower() {
      return true
    }
  }
  false
}

///|
fn require_part_content_type(
  content_types : @ooxml.PackageContentTypes,
  part_name : StringView,
  expected : ArrayView[String],
  role : StringView,
  cancelled? : () -> Bool = () => false,
) -> Unit raise XlsxError {
  let declared = declared_part_content_type(
    content_types,
    part_name,
    role,
    cancelled~,
  )
  let normalized = declared.to_lower()
  for candidate in expected {
    if normalized == candidate.to_lower() {
      return
    }
  }
  raise InvalidXml(msg="\{role.to_owned()} content type is invalid")
}

///|
/// Returns the manifest identity for a package part. This is the single place
/// where missing content declarations become XLSX package errors.
fn declared_part_content_type(
  content_types : @ooxml.PackageContentTypes,
  part_name : StringView,
  role : StringView,
  cancelled? : () -> Bool = () => false,
) -> String raise XlsxError {
  let declared = content_types.content_type_for(part_name, cancelled~) catch {
    InvalidXml(msg~) => raise InvalidXml(msg~)
    ReadCancelled => raise ReadCancelled
  }
  match declared {
    Some(value) => value
    None => raise InvalidXml(msg="\{role.to_owned()} content type is missing")
  }
}

///|
/// Loads a relationship-selected package part before validating its semantic
/// media type. Missing targets remain `MissingPart`; an existing part whose
/// manifest identity does not match `expected` is rejected as invalid XML.
fn load_typed_part(
  archive : @zip.Archive,
  content_types : @ooxml.PackageContentTypes,
  path : StringView,
  expected : ArrayView[String],
  role : StringView,
  cancelled? : () -> Bool = () => false,
) -> BytesView raise XlsxError {
  let bytes = match archive.get(path) {
    Some(value) => value
    None => raise MissingPart(path=path.to_owned())
  }
  require_part_content_type(
    content_types,
    logical_archive_part_path(path),
    expected,
    role,
    cancelled~,
  )
  bytes
}

///|
/// Loads and authenticates an OPC relationship part. Relationship XML has one
/// fixed media type regardless of the source part that owns it.
fn load_relationship_part(
  archive : @zip.Archive,
  content_types : @ooxml.PackageContentTypes,
  path : StringView,
  role : StringView,
  cancelled? : () -> Bool = () => false,
) -> BytesView raise XlsxError {
  load_typed_part(
    archive,
    content_types,
    path,
    [ct_relationships],
    role,
    cancelled~,
  )
}

///|
/// Optional relationship parts remain optional, but an existing part is never
/// consumed unless its manifest identity is the fixed OPC relationships type.
fn load_optional_relationship_part(
  archive : @zip.Archive,
  content_types : @ooxml.PackageContentTypes,
  path : StringView,
  role : StringView,
  cancelled? : () -> Bool = () => false,
) -> BytesView? raise XlsxError {
  match archive.get(path) {
    Some(_) =>
      Some(
        load_relationship_part(archive, content_types, path, role, cancelled~),
      )
    None => None
  }
}

///|
test "read package parts: relationship parts require their fixed manifest identity" {
  let archive = @zip.Archive::new()
  archive.add("custom/_rels/source.xml.rels", b"<Relationships/>")
  let missing = try! @ooxml.parse_package_content_types(
    "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\"><Default Extension=\"xml\" ContentType=\"application/xml\"/></Types>",
  )
  let wrong = try! @ooxml.parse_package_content_types(
    "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\"><Default Extension=\"rels\" ContentType=\"application/xml\"/></Types>",
  )
  let valid = try! @ooxml.parse_package_content_types(
    "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\"><Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/></Types>",
  )
  for
    entry in [
      (missing, "test relationships content type is missing"),
      (wrong, "test relationships content type is invalid"),
    ] {
    let (content_types, expected) = entry
    try
      load_relationship_part(
        archive, content_types, "custom/_rels/source.xml.rels", "test relationships",
      )
    catch {
      InvalidXml(msg~) => assert_eq(msg, expected)
      _ => fail("unexpected relationship content-type error")
    } noraise {
      _ => fail("expected relationship content-type rejection")
    }
  }
  assert_eq(
    load_relationship_part(
      archive, valid, "custom/_rels/source.xml.rels", "test relationships",
    ),
    b"<Relationships/>",
  )
}

///|
test "read package parts: workbook media types are case-insensitive" {
  assert_true(
    workbook_content_type_is_supported(
      "Application/Vnd.Openxmlformats-Officedocument.Spreadsheetml.Sheet.Main+Xml",
    ),
  )
  assert_true(
    workbook_content_type_is_supported(
      "APPLICATION/VND.MS-EXCEL.SHEET.MACROENABLED.MAIN+XML",
    ),
  )
}

///|
fn resolve_workbook_xml_part_path(
  archive : @zip.Archive,
  part_names : Map[String, String],
  decode : (BytesView) -> String raise XlsxError,
  budget? : ReadBudget,
  cancelled? : () -> Bool = () => false,
) -> (String, @ooxml.PackageContentTypes) raise XlsxError {
  // The content-type manifest authenticates every consumed package part,
  // including the root relationship part, so it must be parsed first.
  let content_types_path = actual_archive_part_path(
    part_names, content_types_part_path,
  )
  let content_types_xml = match archive.get(content_types_path) {
    Some(content_types_bytes) => decode(content_types_bytes)
    None => raise MissingPart(path=content_types_path)
  }
  match budget {
    Some(value) => {
      value.checkpoint()
      value.charge_work(content_types_xml.length())
    }
    None => check_read_cancelled(cancelled)
  }
  let content_types = @ooxml.parse_package_content_types(
    content_types_xml,
    cancelled~,
  ) catch {
    InvalidXml(msg~) => raise InvalidXml(msg~)
    ReadCancelled => raise ReadCancelled
  }
  let workbook_part = workbook_part_from_root_relationships(
    archive,
    part_names,
    content_types,
    decode,
    budget?,
    cancelled~,
  )
  require_part_content_type(
    content_types,
    workbook_part,
    workbook_content_type_candidates(),
    "root workbook",
    cancelled~,
  )
  (workbook_part, content_types)
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
  let (path, _) = resolve_workbook_xml_part_path(
    archive,
    archive_part_name_index(archive),
    decode_utf8_or_invalid_xml,
  )
  path
}

///|
test "read package parts: root relationship is required" {
  let archive = @zip.Archive::new()
  archive.add(
    content_types_part_path,
    @encoding/utf8.encode(
      "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\"><Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/></Types>",
    ),
  )
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
    #|  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
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
fn workbook_part_from_root_target_for_test(
  target : StringView,
) -> String raise XlsxError {
  let archive = @zip.Archive::new()
  let root_relationships = "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">" +
    "<Relationship Id=\"main\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"" +
    target.to_owned() +
    "\"/></Relationships>"
  archive.add(root_rels_part_path, @encoding/utf8.encode(root_relationships))
  let content_types = @ooxml.parse_package_content_types(
    "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\"><Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/></Types>",
  ) catch {
    InvalidXml(msg~) => raise InvalidXml(msg~)
    ReadCancelled => raise ReadCancelled
  }
  workbook_part_from_root_relationships(
    archive,
    archive_part_name_index(archive),
    content_types,
    decode_utf8_or_invalid_xml,
  )
}

///|
test "read package parts: root target rejects absolute URI syntax" {
  for target in ["urn:book.xml", "a:b/c"] {
    try workbook_part_from_root_target_for_test(target) catch {
      InvalidXml(msg~) => inspect(msg, content="relationship target invalid")
      _ => fail("unexpected absolute root-target error")
    } noraise {
      _ => fail("expected absolute root-target rejection")
    }
  }
}

///|
test "read package parts: explicit relative and package-absolute root targets remain valid" {
  for target in ["./urn:book.xml", "/urn:book.xml"] {
    inspect(
      workbook_part_from_root_target_for_test(target),
      content="urn:book.xml",
    )
  }
}

///|
test "read package parts: external workbook relationship is never resolved as a part" {
  let archive = @zip.Archive::new()
  let content_types =
    #|<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
    #|  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
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
    #|  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
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
      inspect(msg, content="content type override part name is invalid")
    _ => fail("expected content type part name empty")
  }
}

///|
test "read package parts: stale workbook override cannot redirect the root relationship" {
  let archive = @zip.Archive::new()
  let content_types =
    #|<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
    #|  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
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
    #|  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
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
