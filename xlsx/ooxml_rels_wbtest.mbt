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
  let targets = parse_relationship_targets(xml[:], "t1")
  inspect(
    targets,
    content=(
      #|{"rId1": "a.xml", "rId3": "c.xml"}
    ),
  )
}

///|
test "ooxml_rels: first_relationship_target returns first map entry" {
  let targets : Map[String, String] = { "rId9": "x", "rId10": "y" }
  // Map iteration order is insertion-order; this should be stable.
  inspect(first_relationship_target(targets), content="Some(\"x\")")
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
  let rel_result = try? resolve_rel_target("../../../sheet1.xml", "worksheets")
  match rel_result {
    Err(XlsxError::InvalidXml(msg~)) =>
      inspect(msg, content="relationship target invalid")
    _ => fail("expected InvalidXml for relative escape in resolve_rel_target")
  }
  let workbook_result = try? resolve_workbook_rel_target("../../sheet1.xml")
  match workbook_result {
    Err(XlsxError::InvalidXml(msg~)) =>
      inspect(msg, content="relationship target invalid")
    _ =>
      fail(
        "expected InvalidXml for relative escape in resolve_workbook_rel_target",
      )
  }
}

///|
test "ooxml_rels: normalize and resolve invalid-path guards" {
  let normalize_result = try? normalize_rel_part_path("./")
  match normalize_result {
    Err(XlsxError::InvalidXml(msg~)) =>
      inspect(msg, content="relationship target invalid")
    _ => fail("expected InvalidXml for normalize_rel_part_path(\"./\")")
  }

  let rel_result = try? resolve_rel_target("/docProps/core.xml", "worksheets")
  match rel_result {
    Err(XlsxError::InvalidXml(msg~)) =>
      inspect(msg, content="relationship target invalid")
    _ => fail("expected InvalidXml for non-xl absolute resolve_rel_target")
  }
}
