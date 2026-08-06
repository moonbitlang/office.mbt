// Element-order conformance for `xl/workbook.xml`.
//
// `CT_Workbook` (ECMA-376 Part 1, §18.2.27) is an `xsd:sequence`, not a choice,
// so the relative order of its children is normative. Excel treats a workbook
// whose children are out of order as corrupt and declines to repair it, so a
// misordering here loses the whole file rather than one feature.

///|
/// Position of `name` in the `CT_Workbook` child sequence, or `None` when the
/// element is not a `CT_Workbook` child at all.
fn ct_workbook_sequence_position(name : String) -> Int? {
  [
    "fileVersion", "fileSharing", "workbookPr", "workbookProtection", "bookViews",
    "sheets", "functionGroups", "externalReferences", "definedNames", "calcPr", "oleSize",
    "customWorkbookViews", "pivotCaches", "smartTagPr", "smartTagTypes", "webPublishing",
    "fileRecoveryPr", "webPublishObjects", "extLst",
  ].search(name)
}

///|
/// The direct children of `<workbook>`, in document order.
///
/// The writer indents `CT_Workbook` children by exactly two spaces and their
/// descendants by four or more, so scanning for lines that begin with `"  <"`
/// recovers the child sequence without a full XML parse.
fn ct_workbook_children(xml : String) -> Array[String] {
  let names = []
  for line in xml.split("\n") {
    guard line is [.. "  <", .. rest] else { continue }
    guard !(rest is [.. "/", ..]) else { continue }
    let name = StringBuilder::new()
    for ch in rest {
      match ch {
        ' ' | '/' | '>' => break
        _ => name.write_char(ch)
      }
    }
    names.push(name.to_string())
  }
  names
}

///|
/// Check every `<workbook>` child against its `CT_Workbook` sequence position
/// and return the observed order so callers can snapshot it.
fn ct_workbook_child_order(xml : String) -> String raise {
  let children = ct_workbook_children(xml)
  let order = children.join(", ")
  let mut previous = -1
  for name in children {
    let position = match ct_workbook_sequence_position(name) {
      Some(position) => position
      None => fail("<\{name}> is not a CT_Workbook child:\n\{xml}")
    }
    if position <= previous {
      fail("CT_Workbook children out of schema order at <\{name}>: \{order}")
    }
    previous = position
  }
  order
}

///|
/// Serialize `workbook` and return its `xl/workbook.xml`.
fn written_workbook_xml(workbook : @xlsx.Workbook) -> String raise {
  let archive = @zip.read(@xlsx.write(workbook))
  match archive.get("xl/workbook.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing xl/workbook.xml")
  }
}

///|
/// Byte offset of `needle` in `xml`.
fn workbook_xml_offset(xml : String, needle : String) -> Int raise {
  match xml.find(needle) {
    Some(offset) => offset
    None => fail("expected \{needle} in:\n\{xml}")
  }
}

///|
/// The `<workbookProtection .../>` element of `xml`, attributes included.
fn workbook_protection_element(xml : String) -> String raise {
  let start = workbook_xml_offset(xml, "<workbookProtection")
  let rest = xml[start:]
  match rest.find(">") {
    Some(end) => rest[:end + 1].to_owned()
    None => fail("unterminated <workbookProtection> in:\n\{xml}")
  }
}

///|
/// Regression test for issue #291: `<workbookProtection>` used to be emitted
/// after `<sheets>`, which violates the `CT_Workbook` sequence.
test "workbook.xml: workbookProtection precedes bookViews and sheets (#291)" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.protect_workbook(
    options=@xlsx.WorkbookProtectionOptions::with_values(lock_structure=true),
  )
  let xml = written_workbook_xml(workbook)
  inspect(
    ct_workbook_child_order(xml),
    content="workbookProtection, bookViews, sheets",
  )
  let protection = workbook_xml_offset(xml, "<workbookProtection")
  let book_views = workbook_xml_offset(xml, "<bookViews>")
  let sheets = workbook_xml_offset(xml, "<sheets>")
  inspect(protection < book_views, content="true")
  inspect(book_views < sheets, content="true")
}

///|
test "workbook.xml: workbookProtection stays first when bookViews is absent" {
  // `<bookViews>` is only emitted for a non-empty sheet list, so this covers
  // protection against the immediately following element instead.
  let workbook = @xlsx.Workbook::new()
  workbook.protect_workbook(
    options=@xlsx.WorkbookProtectionOptions::with_values(lock_windows=true),
  )
  let xml = written_workbook_xml(workbook)
  inspect(ct_workbook_child_order(xml), content="workbookProtection, sheets")
  inspect(xml.contains("<bookViews>"), content="false")
  let protection = workbook_xml_offset(xml, "<workbookProtection")
  let sheets = workbook_xml_offset(xml, "<sheets>")
  inspect(protection < sheets, content="true")
}

///|
test "workbook.xml: full child sequence with props, sheets, names and calcPr" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  ignore(workbook.add_sheet("Sheet2"))
  ignore(workbook.add_sheet("Sheet3"))
  workbook.set_active_sheet(1)
  workbook.set_workbook_props(
    Some(
      @xlsx.WorkbookPropsOptions::with_values(
        date_1904=true,
        code_name="ThisWorkbook",
      ),
    ),
  )
  workbook.set_calc_props(
    Some(
      @xlsx.CalcPropsOptions::with_values(
        calc_id=191029,
        full_calc_on_load=true,
      ),
    ),
  )
  workbook.set_defined_name(
    @xlsx.DefinedName::new("GlobalRange", "Sheet1!$A$1:$B$2"),
  )
  workbook.set_defined_name(
    @xlsx.DefinedName::new("LocalRange", "Sheet2!$C$1", scope="Sheet2"),
  )
  workbook.protect_workbook(
    options=@xlsx.WorkbookProtectionOptions::with_values(
      password="secret",
      lock_structure=true,
      lock_windows=true,
    ),
  )
  let xml = written_workbook_xml(workbook)
  inspect(
    ct_workbook_child_order(xml),
    content="workbookPr, workbookProtection, bookViews, sheets, definedNames, calcPr",
  )
  let props = workbook_xml_offset(xml, "<workbookPr")
  let protection = workbook_xml_offset(xml, "<workbookProtection")
  let book_views = workbook_xml_offset(xml, "<bookViews>")
  inspect(props < protection, content="true")
  inspect(protection < book_views, content="true")
}

///|
test "workbook.xml: protection ordering holds with pivotCaches and extLst" {
  let workbook = @xlsx.Workbook::new()
  let data = workbook.add_sheet("Data")
  let dash = workbook.add_sheet("Dash")
  data.set_cell_value("A1", String("Region"))
  data.set_cell_value("A2", String("North"))
  dash.set_cell_value("A1", String("Dashboard"))
  ignore(
    workbook.add_pivot_table_xml(
      "Data",
      "<pivotTableDefinition name=\"PivotData\"/>",
      "<pivotCacheDefinition><cacheFields count=\"1\"><cacheField name=\"Region\"/></cacheFields></pivotCacheDefinition>",
      name="PivotData",
    ),
  )
  workbook.add_slicer(
    "Dash",
    @xlsx.SlicerOptions::new("Region", "A1", "Data", "PivotData"),
  )
  workbook.protect_workbook(
    options=@xlsx.WorkbookProtectionOptions::with_values(lock_structure=true),
  )
  let xml = written_workbook_xml(workbook)
  inspect(
    ct_workbook_child_order(xml),
    content="workbookProtection, bookViews, sheets, definedNames, pivotCaches, extLst",
  )
}

///|
test "workbook.xml: protection survives a round trip and is rewritten in order" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.protect_workbook(
    options=@xlsx.WorkbookProtectionOptions::with_values(
      password="secret",
      algorithm_name="SHA-512",
      lock_structure=true,
      lock_windows=true,
    ),
  )
  let bytes = @xlsx.write(workbook)
  let parsed = @xlsx.read(bytes)
  inspect(parsed.workbook_protection is Some(_), content="true")
  let mismatch : Result[Unit, Error] = Ok(
    parsed.unprotect_workbook(password="bad"),
  ) catch {
    err => Err(err)
  }
  inspect(
    mismatch is Err(@xlsx.XlsxError::InvalidWorkbookProtection(_)),
    content="true",
  )
  // Re-read (the failed unprotect above leaves protection in place) and check
  // the settings the writer emitted came back intact.
  let reread = @xlsx.read(bytes)
  let rewritten = written_workbook_xml(reread)
  // Every attribute — including the generated salt, hash and spin count —
  // survives the round trip byte for byte.
  inspect(
    workbook_protection_element(rewritten) ==
    workbook_protection_element(written_workbook_xml(workbook)),
    content="true",
  )
  inspect(rewritten.contains("lockStructure=\"1\""), content="true")
  inspect(rewritten.contains("lockWindows=\"1\""), content="true")
  inspect(
    rewritten.contains("workbookAlgorithmName=\"SHA-512\""),
    content="true",
  )
  inspect(rewritten.contains("workbookSaltValue=\""), content="true")
  inspect(rewritten.contains("workbookHashValue=\""), content="true")
  inspect(rewritten.contains("workbookSpinCount=\""), content="true")
  inspect(
    ct_workbook_child_order(rewritten),
    content="workbookProtection, bookViews, sheets",
  )
  let ok : Result[Unit, Error] = Ok(
    reread.unprotect_workbook(password="secret"),
  ) catch {
    err => Err(err)
  }
  debug_inspect(ok, content="Ok(())")
  inspect(reread.workbook_protection is None, content="true")
}
