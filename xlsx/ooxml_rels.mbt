///|
let transitional_office_relationship_prefix = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/"

///|
let strict_office_relationship_prefix = "http://purl.oclc.org/ooxml/officeDocument/relationships/"

///|
fn parse_relationship_targets_exact(
  xml : StringView,
  rel_type : StringView,
) -> Map[String, String] raise XlsxError {
  @ooxml.parse_relationship_targets(xml, rel_type) catch {
    InvalidXml(msg~) => raise InvalidXml(msg~)
  }
}

///|
/// Reads both ISO Strict and ECMA Transitional aliases for relationship types
/// from the Office relationship family. Microsoft extension relationships use
/// their own namespaces and therefore remain exact matches.
fn parse_relationship_targets(
  xml : StringView,
  rel_type : StringView,
) -> Map[String, String] raise XlsxError {
  let requested = rel_type.to_owned()
  let targets = parse_relationship_targets_exact(xml, requested)
  guard requested.strip_prefix(transitional_office_relationship_prefix)
    is Some(suffix) else {
    return targets
  }
  let strict_type = strict_office_relationship_prefix + suffix.to_owned()
  let strict_targets = parse_relationship_targets_exact(xml, strict_type)
  for id, target in strict_targets {
    if targets.contains(id) {
      raise InvalidXml(msg="relationship id has conflicting dialect aliases")
    }
    targets[id] = target
  }
  targets
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
fn normalize_rel_part_path(path : StringView) -> String raise XlsxError {
  let segments : Array[String] = []
  for chunk in path.split("/") {
    let segment = chunk.to_owned()
    if segment == "" || segment == "." {
      continue
    }
    if segment == ".." {
      if segments.length() == 0 {
        raise InvalidXml(msg="relationship target invalid")
      }
      ignore(segments.pop())
      continue
    }
    segments.push(segment)
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
) -> String raise XlsxError {
  let source = source_part.to_owned()
  let target_str = target.to_owned()
  if source == "" || source.has_prefix("/") || target_str == "" {
    raise InvalidXml(msg="relationship target invalid")
  }
  let normalized_source = normalize_rel_part_path(source)
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
  normalize_rel_part_path(raw)
}

///|
fn resolve_rel_target(
  target : StringView,
  base_folder : StringView,
) -> String raise XlsxError {
  let target_str = target.to_owned()
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
  let normalized = normalize_rel_part_path(raw)
  if !normalized.has_prefix("xl/") {
    raise InvalidXml(msg="relationship target invalid")
  }
  normalized
}

///|
fn resolve_workbook_rel_target(target : StringView) -> String raise XlsxError {
  resolve_part_rel_target(workbook_part_path, target)
}

///|
test "ooxml_rels: parse_relationship_targets filters by Type and maps Id->Target" {
  let xml =
    #|<?xml version="1.0" encoding="UTF-8"?>
    #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
    #|  <Relationship Id="rId1" Type="t1" Target="a.xml"/>
    #|  <Relationship Id="rId2" Type="t2" Target="b.xml"/>
    #|  <Relationship Id="rId3" Type="t1" Target="c.xml"/>
    #|</Relationships>
    #|
  let targets = parse_relationship_targets(xml, "t1")
  debug_inspect(
    targets,
    content=(
      #|{ "rId1": "a.xml", "rId3": "c.xml" }
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
  let targets = parse_relationship_targets(xml, transitional)
  assert_eq(targets.get("strict"), Some("worksheets/strict.xml"))
  assert_eq(targets.get("transitional"), Some("worksheets/transitional.xml"))
  // Asking for an already-Strict URI remains exact and does not broaden to
  // the Transitional family in the opposite direction.
  let strict_only = parse_relationship_targets(xml, strict)
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
