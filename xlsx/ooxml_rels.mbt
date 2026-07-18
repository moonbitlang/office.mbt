///|
let transitional_office_relationship_prefix = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/"

///|
let strict_office_relationship_prefix = "http://purl.oclc.org/ooxml/officeDocument/relationships/"

///|
let max_relationship_part_path_chars : Int = 64 * 1024

///|
let max_relationship_part_path_segments = 4096

///|
fn parse_internal_relationship_targets_exact(
  xml : StringView,
  rel_type : StringView,
  cancelled? : () -> Bool = () => false,
) -> Map[String, String] raise XlsxError {
  @ooxml.parse_internal_relationship_targets(xml, rel_type, cancelled~) catch {
    InvalidXml(msg~) => raise InvalidXml(msg~)
    ReadCancelled => raise ReadCancelled
  }
}

///|
fn parse_internal_relationship_targets_exact_types(
  xml : StringView,
  rel_types : ArrayView[String],
  cancelled? : () -> Bool = () => false,
) -> Map[String, String] raise XlsxError {
  @ooxml.parse_internal_relationship_targets_by_types(
    xml,
    rel_types,
    cancelled~,
  ) catch {
    InvalidXml(msg~) => raise InvalidXml(msg~)
    ReadCancelled => raise ReadCancelled
  }
}

///|
fn parse_external_relationship_targets_exact(
  xml : StringView,
  rel_type : StringView,
  cancelled? : () -> Bool = () => false,
) -> Map[String, String] raise XlsxError {
  @ooxml.parse_external_relationship_targets(xml, rel_type, cancelled~) catch {
    InvalidXml(msg~) => raise InvalidXml(msg~)
    ReadCancelled => raise ReadCancelled
  }
}

///|
fn parse_external_relationship_targets_exact_types(
  xml : StringView,
  rel_types : ArrayView[String],
  cancelled? : () -> Bool = () => false,
) -> Map[String, String] raise XlsxError {
  @ooxml.parse_external_relationship_targets_by_types(
    xml,
    rel_types,
    cancelled~,
  ) catch {
    InvalidXml(msg~) => raise InvalidXml(msg~)
    ReadCancelled => raise ReadCancelled
  }
}

///|
/// Reads both ISO Strict and ECMA Transitional aliases for relationship types
/// from the Office relationship family. Microsoft extension relationships use
/// their own namespaces and therefore remain exact matches.
fn parse_internal_relationship_targets(
  xml : StringView,
  rel_type : StringView,
  budget? : ReadBudget,
  cancelled? : () -> Bool = () => false,
) -> Map[String, String] raise XlsxError {
  match budget {
    Some(value) => {
      value.checkpoint()
      value.charge_work(xml.length())
    }
    None => check_read_cancelled(cancelled)
  }
  let requested = rel_type.to_owned()
  match requested.strip_prefix(transitional_office_relationship_prefix) {
    Some(suffix) => {
      let strict_type = strict_office_relationship_prefix + suffix.to_owned()
      parse_internal_relationship_targets_exact_types(
        xml,
        [requested, strict_type],
        cancelled~,
      )
    }
    None =>
      parse_internal_relationship_targets_exact(xml, requested, cancelled~)
  }
}

///|
/// Reads only explicitly external targets, accepting the same Strict aliases
/// as internal Office relationships.
fn parse_external_relationship_targets(
  xml : StringView,
  rel_type : StringView,
  budget? : ReadBudget,
  cancelled? : () -> Bool = () => false,
) -> Map[String, String] raise XlsxError {
  match budget {
    Some(value) => {
      value.checkpoint()
      value.charge_work(xml.length())
    }
    None => check_read_cancelled(cancelled)
  }
  let requested = rel_type.to_owned()
  match requested.strip_prefix(transitional_office_relationship_prefix) {
    Some(suffix) => {
      let strict_type = strict_office_relationship_prefix + suffix.to_owned()
      parse_external_relationship_targets_exact_types(
        xml,
        [requested, strict_type],
        cancelled~,
      )
    }
    None =>
      parse_external_relationship_targets_exact(xml, requested, cancelled~)
  }
}

///|
fn first_relationship_target(targets : Map[String, String]) -> String? {
  for _, target in targets {
    return Some(target)
  }
  None
}

///|
fn rels_path_for(path : StringView, folder : StringView) -> String {
  let path_str = path.to_owned()
  let prefix = "xl/\{folder.to_owned()}/"
  if path_str.has_prefix(prefix) {
    path_str.replace_all(old=prefix, new="xl/\{folder.to_owned()}/_rels/") +
    ".rels"
  } else {
    "xl/\{folder.to_owned()}/_rels/" + path_str + ".rels"
  }
}

///|
fn parse_id_from_path(path : StringView, prefix : StringView) -> Int {
  let path_str = path.to_owned()
  let num = match path_str.strip_prefix(prefix) {
    Some(rest) =>
      match rest.to_owned().strip_suffix(".xml") {
        Some(n) => n
        None => return 0
      }
    None => return 0
  }
  @string.parse_int(num.to_owned(), base=10) catch {
    _ => 0
  }
}

///|
fn drop_first_path_segment(path : StringView) -> String {
  match path.to_owned().after("/") {
    Some(rest) => rest.to_owned()
    None => path.to_owned()
  }
}

///|
fn relationship_target_has_ambiguous_first_segment_colon(
  target : StringView,
) -> Bool {
  if target.has_prefix("/") {
    return false
  }
  for character in target {
    if character == '/' {
      return false
    }
    if character == ':' {
      return true
    }
  }
  false
}

///|
fn validate_relationship_target_uri(
  target : StringView,
  cancelled? : () -> Bool = () => false,
) -> Unit raise XlsxError {
  check_read_cancelled(cancelled)
  if target == "" ||
    target.length() > max_relationship_part_path_chars ||
    target.has_prefix("//") ||
    target.contains("\\") ||
    target.contains("?") ||
    target.contains("#") ||
    relationship_target_has_ambiguous_first_segment_colon(target) {
    raise InvalidXml(msg="relationship target invalid")
  }
}

///|
fn normalize_rel_part_path(
  path : StringView,
  cancelled? : () -> Bool = () => false,
) -> String raise XlsxError {
  check_read_cancelled(cancelled)
  if path == "" || path.length() > max_relationship_part_path_chars {
    raise InvalidXml(msg="relationship target invalid")
  }
  let segments : Array[String] = []
  let mut segment_start = 0
  let mut segment_count = 0
  let mut index = 0
  while index <= path.length() {
    if index < path.length() && path[index] != ('/' : UInt16) {
      index = index + 1
      continue
    }
    segment_count = segment_count + 1
    if segment_count > max_relationship_part_path_segments {
      raise InvalidXml(msg="relationship target segment limit exceeded")
    }
    if (segment_count & 127) == 1 {
      check_read_cancelled(cancelled)
    }
    let segment = path[segment_start:index]
    let terminal = index == path.length()
    if segment == "" {
      // Empty URI path segments are significant. Silently removing them lets
      // malformed targets such as `xl//workbook.xml` alias valid package parts.
      raise InvalidXml(msg="relationship target invalid")
    }
    if segment == "." {
      // A terminal dot segment resolves to a directory URI, not an OPC part.
      if terminal {
        raise InvalidXml(msg="relationship target invalid")
      }
    } else if segment == ".." {
      if segments.length() == 0 || terminal {
        raise InvalidXml(msg="relationship target invalid")
      }
      ignore(segments.pop())
    } else {
      let valid = @ooxml.is_valid_opc_part_segment_cancellable(
        segment,
        cancelled~,
      ) catch {
        ReadCancelled => raise ReadCancelled
        InvalidXml(msg~) => raise InvalidXml(msg~)
      }
      if !valid {
        raise InvalidXml(msg="relationship target invalid")
      }
      segments.push(segment.to_owned())
    }
    segment_start = index + 1
    index = index + 1
  }
  if segments.length() == 0 {
    raise InvalidXml(msg="relationship target invalid")
  }
  segments.join("/")
}

///|
fn resolve_part_rel_target(
  source_part : StringView,
  target : StringView,
  cancelled? : () -> Bool = () => false,
) -> String raise XlsxError {
  let source = source_part.to_owned()
  let target_str = target.to_owned()
  if source == "" || source.has_prefix("/") || target_str == "" {
    raise InvalidXml(msg="relationship target invalid")
  }
  validate_relationship_target_uri(target_str, cancelled~)
  let normalized_source = normalize_rel_part_path(source, cancelled~)
  if normalized_source != source {
    raise InvalidXml(msg="relationship target invalid")
  }
  let raw = if target_str.has_prefix("/") {
    drop_first_path_segment(target_str)
  } else {
    match source.rev_find("/") {
      Some(pos) => source[:pos + 1].to_owned() + target_str
      None => target_str
    }
  }
  normalize_rel_part_path(raw, cancelled~)
}

///|
fn resolve_rel_target(
  target : StringView,
  base_folder : StringView,
  cancelled? : () -> Bool = () => false,
) -> String raise XlsxError {
  let target_str = target.to_owned()
  validate_relationship_target_uri(target_str, cancelled~)
  let raw = if target_str.has_prefix("/") {
    drop_first_path_segment(target_str)
  } else if target_str.has_prefix("../") {
    "xl/" + base_folder.to_owned() + "/" + target_str
  } else if target_str.has_prefix("xl/") {
    target_str
  } else {
    let base = base_folder.to_owned()
    if base.has_suffix("/") {
      "xl/" + base + target_str
    } else {
      "xl/" + base + "/" + target_str
    }
  }
  let normalized = normalize_rel_part_path(raw, cancelled~)
  if !normalized.has_prefix("xl/") {
    raise InvalidXml(msg="relationship target invalid")
  }
  normalized
}

///|
fn resolve_workbook_rel_target(
  target : StringView,
  cancelled? : () -> Bool = () => false,
) -> String raise XlsxError {
  resolve_part_rel_target(workbook_part_path, target, cancelled~)
}

///|
test "ooxml_rels: internal targets filter by Type and map Id->Target" {
  let xml =
    #|<?xml version="1.0" encoding="UTF-8"?>
    #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
    #|  <Relationship Id="rId1" Type="urn:t1" Target="a.xml"/>
    #|  <Relationship Id="rId2" Type="urn:t2" Target="b.xml"/>
    #|  <Relationship Id="rId3" Type="urn:t1" Target="c.xml"/>
    #|</Relationships>
    #|
  let targets = parse_internal_relationship_targets(xml, "urn:t1")
  debug_inspect(
    targets,
    content=(
      #|{ "rId1": "a.xml", "rId3": "c.xml" }
    ),
  )
}

///|
test "ooxml_rels: target modes separate package parts from external resources" {
  let xml =
    #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
    #|  <Relationship Id="inside" Type="urn:t1" Target="worksheets/sheet1.xml"/>
    #|  <Relationship Id="outside" Type="urn:t1" Target="https://example.invalid/sheet.xml" TargetMode="External"/>
    #|</Relationships>
  debug_inspect(
    parse_internal_relationship_targets(xml, "urn:t1"),
    content=(
      #|{ "inside": "worksheets/sheet1.xml" }
    ),
  )
  debug_inspect(
    parse_external_relationship_targets(xml, "urn:t1"),
    content=(
      #|{ "outside": "https://example.invalid/sheet.xml" }
    ),
  )
}

///|
test "ooxml_rels: Office relationship types accept Strict aliases" {
  let transitional = transitional_office_relationship_prefix + "worksheet"
  let strict = strict_office_relationship_prefix + "worksheet"
  let xml =
    #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
    #|  <Relationship Id="strict" Type="http://purl.oclc.org/ooxml/officeDocument/relationships/worksheet" Target="worksheets/strict.xml"/>
    #|  <Relationship Id="transitional" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/transitional.xml"/>
    #|</Relationships>
  let targets = parse_internal_relationship_targets(xml, transitional)
  assert_eq(targets.get("strict"), Some("worksheets/strict.xml"))
  assert_eq(targets.get("transitional"), Some("worksheets/transitional.xml"))
  // Asking for an already-Strict URI remains exact and does not broaden to
  // the Transitional family in the opposite direction.
  let strict_only = parse_internal_relationship_targets(xml, strict)
  assert_eq(strict_only.length(), 1)
  assert_eq(strict_only.get("strict"), Some("worksheets/strict.xml"))
}

///|
test "ooxml_rels: first_relationship_target returns first map entry" {
  let targets : Map[String, String] = { "rId9": "x", "rId10": "y" }
  // Map iteration order is insertion-order; this should be stable.
  debug_inspect(first_relationship_target(targets), content="Some(\"x\")")
}

///|
test "ooxml_rels: rels_path_for converts worksheets path to rels path" {
  inspect(
    rels_path_for("xl/worksheets/sheet1.xml", "worksheets"),
    content="xl/worksheets/_rels/sheet1.xml.rels",
  )
  inspect(
    rels_path_for("sheet1.xml", "worksheets"),
    content="xl/worksheets/_rels/sheet1.xml.rels",
  )
}

///|
test "ooxml_rels: parse_id_from_path extracts numeric suffix" {
  inspect(
    parse_id_from_path(
      "xl/pivotTables/pivotTable12.xml", "xl/pivotTables/pivotTable",
    ),
    content="12",
  )
  inspect(
    parse_id_from_path(
      "xl/pivotTables/pivotTable.xml", "xl/pivotTables/pivotTable",
    ),
    content="0",
  )
  inspect(
    parse_id_from_path(
      "xl/pivotTables/pivotTable12.bin", "xl/pivotTables/pivotTable",
    ),
    content="0",
  )
  inspect(parse_id_from_path("a.xml", "a.x"), content="0")
}

///|
test "ooxml_rels: resolve_rel_target handles absolute, parent, and relative targets" {
  inspect(resolve_rel_target("/xl/a.xml", "worksheets"), content="xl/a.xml")
  inspect(
    resolve_rel_target("../drawings/d1.xml", "worksheets"),
    content="xl/drawings/d1.xml",
  )
  inspect(
    resolve_rel_target("xl/charts/c1.xml", "worksheets"),
    content="xl/charts/c1.xml",
  )
  inspect(
    resolve_rel_target("sheet1.xml", "worksheets"),
    content="xl/worksheets/sheet1.xml",
  )
  inspect(
    resolve_rel_target("rels/abc.xml", "worksheets/"),
    content="xl/worksheets/rels/abc.xml",
  )
}

///|
test "ooxml_rels: resolve_workbook_rel_target treats relative as under xl/" {
  inspect(
    resolve_workbook_rel_target("worksheets/sheet1.xml"),
    content="xl/worksheets/sheet1.xml",
  )
}

///|
test "ooxml_rels: part relationships resolve from the actual source part" {
  inspect(
    resolve_part_rel_target("custom/book.xml", "../data/first.xml"),
    content="data/first.xml",
  )
  inspect(
    resolve_part_rel_target("custom/book.xml", "/data/first.xml"),
    content="data/first.xml",
  )
  inspect(
    resolve_part_rel_target("book.xml", "data/first.xml"),
    content="data/first.xml",
  )
}

///|
test "ooxml_rels: resolve target normalizes dot segments" {
  inspect(
    resolve_rel_target(".././drawings/../drawings/d1.xml", "worksheets"),
    content="xl/drawings/d1.xml",
  )
  inspect(
    resolve_rel_target("./tables/table1.xml", "worksheets"),
    content="xl/worksheets/tables/table1.xml",
  )
  inspect(
    resolve_workbook_rel_target("./worksheets/./sheet1.xml"),
    content="xl/worksheets/sheet1.xml",
  )
  inspect(
    resolve_workbook_rel_target("worksheets/../worksheets/sheet1.xml"),
    content="xl/worksheets/sheet1.xml",
  )
}

///|
test "ooxml_rels: resolve target rejects escaping root via dot segments" {
  let rel_result = Ok(resolve_rel_target("../../../sheet1.xml", "worksheets")) catch {
    e => Err(e)
  }
  match rel_result {
    Err(InvalidXml(msg~)) => inspect(msg, content="relationship target invalid")
    _ => fail("expected InvalidXml for relative escape in resolve_rel_target")
  }
  let workbook_result = Ok(resolve_workbook_rel_target("../../sheet1.xml")) catch {
    e => Err(e)
  }
  match workbook_result {
    Err(InvalidXml(msg~)) => inspect(msg, content="relationship target invalid")
    _ =>
      fail(
        "expected InvalidXml for relative escape in resolve_workbook_rel_target",
      )
  }

  let relocated_result = Ok(
    resolve_part_rel_target("custom/book.xml", "../../sheet1.xml"),
  ) catch {
    e => Err(e)
  }
  match relocated_result {
    Err(InvalidXml(msg~)) => inspect(msg, content="relationship target invalid")
    _ => fail("expected relocated relationship target to reject a root escape")
  }
}

///|
test "ooxml_rels: normalize and resolve invalid-path guards" {
  let normalize_result = Ok(normalize_rel_part_path("./")) catch { e => Err(e) }
  match normalize_result {
    Err(InvalidXml(msg~)) => inspect(msg, content="relationship target invalid")
    _ => fail("expected InvalidXml for normalize_rel_part_path(\"./\")")
  }

  let rel_result = Ok(resolve_rel_target("/docProps/core.xml", "worksheets")) catch {
    e => Err(e)
  }
  match rel_result {
    Err(InvalidXml(msg~)) => inspect(msg, content="relationship target invalid")
    _ => fail("expected InvalidXml for non-xl absolute resolve_rel_target")
  }
}

///|
test "ooxml_rels: invalid empty and terminal path segments never alias parts" {
  for
    target in [
      "worksheets//sheet1.xml", "worksheets/sheet1.xml/.", "worksheets/sheet1.xml/",
      "https://example.invalid/sheet1.xml", "worksheets\\sheet1.xml", "worksheets/sheet1.xml?query",
      "worksheets/sheet1.xml#fragment",
    ] {
    try resolve_workbook_rel_target(target) catch {
      InvalidXml(msg~) => assert_eq(msg, "relationship target invalid")
      _ => fail("unexpected relationship target error")
    } noraise {
      _ => fail("malformed relationship target was accepted: \{target}")
    }
  }
}

///|
test "ooxml_rels: normalization bounds segments and polls cancellation" {
  let many_segments = "a/".repeat(max_relationship_part_path_segments) + "z"
  try normalize_rel_part_path(many_segments) catch {
    InvalidXml(msg~) =>
      inspect(msg, content="relationship target segment limit exceeded")
    _ => fail("unexpected relationship segment-limit error")
  } noraise {
    _ => fail("expected relationship segment-limit rejection")
  }

  let checks = [0]
  try
    normalize_rel_part_path("a".repeat(60 * 1024), cancelled=() => {
      checks[0] = checks[0] + 1
      checks[0] >= 4
    })
  catch {
    ReadCancelled => assert_true(checks[0] >= 4)
    _ => fail("unexpected relationship normalization cancellation error")
  } noraise {
    _ => fail("expected relationship normalization cancellation")
  }
}
