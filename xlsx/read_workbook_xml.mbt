///|
priv struct WorkbookSheetInfo {
  name : String
  sheet_id : UInt
  state : SheetState
  rel_id : String
}

///|
let transitional_spreadsheet_namespace = "http://schemas.openxmlformats.org/spreadsheetml/2006/main"

///|
let strict_spreadsheet_namespace = "http://purl.oclc.org/ooxml/spreadsheetml/main"

///|
let transitional_relationship_attribute_namespace = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"

///|
let strict_relationship_attribute_namespace = "http://purl.oclc.org/ooxml/officeDocument/relationships"

///|
fn workbook_scanner_next(
  scanner : @ooxml.XmlStartTagScanner,
) -> Bool raise XlsxError {
  scanner.next() catch {
    InvalidXml(msg~) => raise InvalidXml(msg~)
    ReadCancelled => raise ReadCancelled
  }
}

///|
fn workbook_scanner_attribute(
  scanner : @ooxml.XmlStartTagScanner,
  namespace_uri : StringView,
  local_name : StringView,
) -> String? raise XlsxError {
  scanner.attribute(namespace_uri, local_name) catch {
    InvalidXml(msg~) => raise InvalidXml(msg~)
    ReadCancelled => raise ReadCancelled
  }
}

///|
fn workbook_scanner_has_exact_attributes(
  scanner : @ooxml.XmlStartTagScanner,
  expected : ArrayView[(String, String, String)],
) -> Bool raise XlsxError {
  scanner.has_exact_attributes(expected) catch {
    InvalidXml(msg~) => raise InvalidXml(msg~)
    ReadCancelled => raise ReadCancelled
  }
}

///|
fn parse_workbook_sheets(
  xml : StringView,
  max_sheets : Int,
  cancelled? : () -> Bool = () => false,
) -> Array[WorkbookSheetInfo] raise XlsxError {
  let sheets : Array[WorkbookSheetInfo] = []
  let sheet_names : Map[String, Bool] = Map([])
  let sheet_ids : Map[UInt, Bool] = Map([])
  let scanner = @ooxml.XmlStartTagScanner::new(xml, cancelled~)
  let mut workbook_namespace : String? = None
  while workbook_scanner_next(scanner) {
    let namespace_uri = scanner.namespace_uri()
    if scanner.depth() == 1 {
      if scanner.local_name() != "workbook" ||
        (
          namespace_uri != transitional_spreadsheet_namespace &&
          namespace_uri != strict_spreadsheet_namespace
        ) {
        raise InvalidXml(msg="workbook document element is invalid")
      }
      workbook_namespace = Some(namespace_uri.to_owned())
      continue
    }
    if (
        namespace_uri != transitional_spreadsheet_namespace &&
        namespace_uri != strict_spreadsheet_namespace
      ) ||
      scanner.local_name() != "sheet" {
      continue
    }
    let correct_parent = scanner.parent_local_name() is Some("sheets") &&
      scanner.parent_namespace_uri() == workbook_namespace
    if scanner.depth() != 3 ||
      namespace_uri.to_owned() != workbook_namespace.unwrap_or("") ||
      !correct_parent {
      // SpreadsheetML elements outside the schema-defined sheet collection
      // are extension payload, not logical workbook tabs.
      continue
    }
    if sheets.length() >= max_sheets {
      raise ResourceLimitExceeded(
        kind="workbook_sheets",
        limit=max_sheets,
        actual=max_sheets + 1,
      )
    }
    let name = match workbook_scanner_attribute(scanner, "", "name") {
      Some(value) => value
      None => raise InvalidXml(msg="sheet name missing")
    }
    check_sheet_name(name) catch {
      InvalidSheetName(msg~) => raise InvalidXml(msg~)
      error => raise error
    }
    let normalized_name = normalize_sheet_name(name)
    if sheet_names.contains(normalized_name) {
      raise InvalidXml(msg="duplicate sheet name")
    }
    sheet_names[normalized_name] = true
    let sheet_id = match workbook_scanner_attribute(scanner, "", "sheetId") {
      Some(value) =>
        @string.parse_uint(value, base=10) catch {
          _ => raise InvalidXml(msg="sheetId invalid")
        }
      None => raise InvalidXml(msg="sheetId missing")
    }
    if sheet_ids.contains(sheet_id) {
      raise InvalidXml(msg="duplicate sheetId")
    }
    sheet_ids[sheet_id] = true
    let relationship_namespace = if namespace_uri ==
      strict_spreadsheet_namespace {
      strict_relationship_attribute_namespace
    } else {
      transitional_relationship_attribute_namespace
    }
    let rel_id = match
      workbook_scanner_attribute(scanner, relationship_namespace, "id") {
      Some(value) => value
      None => raise InvalidXml(msg="sheet relationship missing")
    }
    let state = match workbook_scanner_attribute(scanner, "", "state") {
      Some(value) =>
        match value {
          "visible" => Visible
          "hidden" => Hidden
          "veryHidden" => VeryHidden
          _ => raise InvalidXml(msg="sheet state invalid")
        }
      None => Visible
    }
    sheets.push({ name, sheet_id, state, rel_id })
  }
  sheets
}

///|
test "read workbook sheets rejects invalid and case-duplicate names" {
  let prefix = "<workbook xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\"><sheets>"
  let suffix = "</sheets></workbook>"
  let invalid = prefix +
    "<sheet name=\"Bad:Name\" sheetId=\"1\" r:id=\"rId1\"/>" +
    suffix
  try parse_workbook_sheets(invalid, 10) catch {
    InvalidXml(msg~) =>
      inspect(msg, content="sheet name contains invalid characters")
    _ => fail("unexpected invalid sheet-name error")
  } noraise {
    _ => fail("expected invalid sheet-name rejection")
  }

  let duplicate = prefix +
    "<sheet name=\"Data\" sheetId=\"1\" r:id=\"rId1\"/>" +
    "<sheet name=\"data\" sheetId=\"2\" r:id=\"rId2\"/>" +
    suffix
  try parse_workbook_sheets(duplicate, 10) catch {
    InvalidXml(msg~) => inspect(msg, content="duplicate sheet name")
    _ => fail("unexpected duplicate sheet-name error")
  } noraise {
    _ => fail("expected duplicate sheet-name rejection")
  }
}

///|
test "read workbook sheets requires unique unsigned sheet ids" {
  let prefix = "<workbook xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\"><sheets>"
  let suffix = "</sheets></workbook>"
  let invalid : Array[(String, String)] = [
    ("<sheet name=\"Missing\" r:id=\"rId1\"/>", "sheetId missing"),
    ("<sheet name=\"Text\" sheetId=\"one\" r:id=\"rId1\"/>", "sheetId invalid"),
    (
      "<sheet name=\"Overflow\" sheetId=\"4294967296\" r:id=\"rId1\"/>", "sheetId invalid",
    ),
    (
      "<sheet name=\"First\" sheetId=\"7\" r:id=\"rId1\"/><sheet name=\"Second\" sheetId=\"7\" r:id=\"rId2\"/>",
      "duplicate sheetId",
    ),
  ]
  for entry in invalid {
    let (body, expected) = entry
    try parse_workbook_sheets(prefix + body + suffix, 10) catch {
      InvalidXml(msg~) => assert_eq(msg, expected)
      _ => fail("unexpected sheetId error")
    } noraise {
      _ => fail("expected invalid sheetId rejection")
    }
  }

  let maximum = parse_workbook_sheets(
    prefix +
    "<sheet name=\"Maximum\" sheetId=\"4294967295\" r:id=\"rId1\"/>" +
    suffix,
    10,
  )
  assert_eq(maximum.length(), 1)
  assert_eq(maximum[0].sheet_id, 4294967295U)
}

///|
test "read workbook sheets accepts only exact visibility states" {
  let prefix = "<workbook xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\"><sheets>"
  let suffix = "</sheets></workbook>"
  let valid = parse_workbook_sheets(
    prefix +
    "<sheet name=\"Default\" sheetId=\"1\" r:id=\"rId1\"/>" +
    "<sheet name=\"Visible\" sheetId=\"2\" state=\"visible\" r:id=\"rId2\"/>" +
    "<sheet name=\"Hidden\" sheetId=\"3\" state=\"hidden\" r:id=\"rId3\"/>" +
    "<sheet name=\"VeryHidden\" sheetId=\"4\" state=\"veryHidden\" r:id=\"rId4\"/>" +
    suffix,
    10,
  )
  assert_true(valid[0].state is Visible)
  assert_true(valid[1].state is Visible)
  assert_true(valid[2].state is Hidden)
  assert_true(valid[3].state is VeryHidden)

  for state in ["Visible", "Hidden", "veryhidden", "unknown", ""] {
    let xml = prefix +
      "<sheet name=\"Invalid\" sheetId=\"1\" state=\"\{state}\" r:id=\"rId1\"/>" +
      suffix
    try parse_workbook_sheets(xml, 10) catch {
      InvalidXml(msg~) => assert_eq(msg, "sheet state invalid")
      _ => fail("unexpected sheet-state error")
    } noraise {
      _ => fail("expected invalid sheet-state rejection")
    }
  }
}

///|
fn parse_active_sheet_index(xml : StringView) -> Int? raise XlsxError {
  let xml_str = xml.to_owned()
  let marker = "<workbookView"
  match xml_str.find(marker) {
    None => None
    Some(start) => {
      let rest = xml_str[start + marker.length():]
      let end = match rest.find(">") {
        Some(pos) => pos
        None => raise InvalidXml(msg="workbookView tag not closed")
      }
      let tag = rest[:end]
      match attr_value(tag, "activeTab") {
        Some(value) =>
          Some(
            @string.parse_int(value, base=10) catch {
              _ => raise InvalidXml(msg="activeTab invalid")
            },
          )
        None => None
      }
    }
  }
}

///|
fn parse_workbook_props(
  xml : StringView,
) -> WorkbookPropsOptions raise XlsxError {
  let xml_str = xml.to_owned()
  let marker = "<workbookPr"
  match xml_str.find(marker) {
    None => WorkbookPropsOptions::new()
    Some(start) => {
      let rest = xml_str[start + marker.length():]
      let end = match rest.find(">") {
        Some(pos) => pos
        None => raise InvalidXml(msg="workbookPr tag not closed")
      }
      let tag = rest[:end]
      let props = WorkbookPropsOptions::new()
      match attr_value(tag, "date1904") {
        Some(value) => props.date_1904 = Some(parse_cell_bool(value))
        None => ()
      }
      match attr_value(tag, "filterPrivacy") {
        Some(value) => props.filter_privacy = Some(parse_cell_bool(value))
        None => ()
      }
      match attr_value(tag, "codeName") {
        Some(value) => props.code_name = Some(unescape_xml_text(value))
        None => ()
      }
      props
    }
  }
}

///|
fn parse_calc_props(xml : StringView) -> CalcPropsOptions raise XlsxError {
  let xml_str = xml.to_owned()
  let marker = "<calcPr"
  match xml_str.find(marker) {
    None => CalcPropsOptions::new()
    Some(start) => {
      let rest = xml_str[start + marker.length():]
      let end = match rest.find(">") {
        Some(pos) => pos
        None => raise InvalidXml(msg="calcPr tag not closed")
      }
      let tag = rest[:end]
      let props = CalcPropsOptions::new()
      match attr_value(tag, "calcId") {
        Some(value) =>
          props.calc_id = Some(
            @string.parse_uint(value, base=10) catch {
              _ => raise InvalidXml(msg="calcId invalid")
            },
          )
        None => ()
      }
      match attr_value(tag, "calcMode") {
        Some(value) =>
          match normalize_calc_mode(value) {
            Some(mode) => props.calc_mode = Some(mode)
            None => raise InvalidXml(msg="calcMode invalid")
          }
        None => ()
      }
      match attr_value(tag, "fullCalcOnLoad") {
        Some(value) => props.full_calc_on_load = Some(parse_cell_bool(value))
        None => ()
      }
      match attr_value(tag, "refMode") {
        Some(value) =>
          match normalize_ref_mode(value) {
            Some(mode) => props.ref_mode = Some(mode)
            None => raise InvalidXml(msg="refMode invalid")
          }
        None => ()
      }
      match attr_value(tag, "iterate") {
        Some(value) => props.iterate = Some(parse_cell_bool(value))
        None => ()
      }
      match attr_value(tag, "iterateCount") {
        Some(value) =>
          props.iterate_count = Some(
            @string.parse_uint(value, base=10) catch {
              _ => raise InvalidXml(msg="iterateCount invalid")
            },
          )
        None => ()
      }
      match attr_value(tag, "iterateDelta") {
        Some(value) =>
          props.iterate_delta = Some(
            @string.parse_double(value) catch {
              _ => raise InvalidXml(msg="iterateDelta invalid")
            },
          )
        None => ()
      }
      match attr_value(tag, "fullPrecision") {
        Some(value) => props.full_precision = Some(parse_cell_bool(value))
        None => ()
      }
      match attr_value(tag, "calcCompleted") {
        Some(value) => props.calc_completed = Some(parse_cell_bool(value))
        None => ()
      }
      match attr_value(tag, "calcOnSave") {
        Some(value) => props.calc_on_save = Some(parse_cell_bool(value))
        None => ()
      }
      match attr_value(tag, "concurrentCalc") {
        Some(value) => props.concurrent_calc = Some(parse_cell_bool(value))
        None => ()
      }
      match attr_value(tag, "concurrentManualCount") {
        Some(value) =>
          props.concurrent_manual_count = Some(
            @string.parse_uint(value, base=10) catch {
              _ => raise InvalidXml(msg="concurrentManualCount invalid")
            },
          )
        None => ()
      }
      match attr_value(tag, "forceFullCalc") {
        Some(value) => props.force_full_calc = Some(parse_cell_bool(value))
        None => ()
      }
      props
    }
  }
}

///|
fn parse_workbook_protection(
  xml : StringView,
) -> WorkbookProtection? raise XlsxError {
  let xml_str = xml.to_owned()
  let marker = "<workbookProtection"
  match xml_str.find(marker) {
    None => None
    Some(start) => {
      let rest = xml_str[start + marker.length():]
      let end = match rest.find(">") {
        Some(pos) => pos
        None => raise InvalidXml(msg="workbookProtection tag not closed")
      }
      let tag = rest[:end]
      let protection : WorkbookProtection = {
        lock_structure: false,
        lock_windows: false,
        algorithm_name: "",
        hash_value: "",
        salt_value: "",
        spin_count: 0,
      }
      match attr_value(tag, "lockStructure") {
        Some(value) => protection.lock_structure = parse_cell_bool(value)
        None => ()
      }
      match attr_value(tag, "lockWindows") {
        Some(value) => protection.lock_windows = parse_cell_bool(value)
        None => ()
      }
      match attr_value(tag, "workbookAlgorithmName") {
        Some(value) => protection.algorithm_name = value.to_string()
        None => ()
      }
      match attr_value(tag, "workbookHashValue") {
        Some(value) => protection.hash_value = value.to_string()
        None => ()
      }
      match attr_value(tag, "workbookSaltValue") {
        Some(value) => protection.salt_value = value.to_string()
        None => ()
      }
      match attr_value(tag, "workbookSpinCount") {
        Some(value) =>
          protection.spin_count = @string.parse_int(value, base=10) catch {
            _ => raise InvalidXml(msg="workbookSpinCount invalid")
          }
        None => ()
      }
      Some(protection)
    }
  }
}
