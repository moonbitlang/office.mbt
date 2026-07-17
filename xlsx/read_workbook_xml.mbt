///|
priv struct WorkbookSheetInfo {
  name : String
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
  }
}

///|
fn parse_workbook_sheets(
  xml : StringView,
  max_sheets : Int,
) -> Array[WorkbookSheetInfo] raise XlsxError {
  let sheets : Array[WorkbookSheetInfo] = []
  let scanner = @ooxml.XmlStartTagScanner::new(xml)
  while workbook_scanner_next(scanner) {
    let namespace_uri = scanner.namespace_uri()
    if (
        namespace_uri != transitional_spreadsheet_namespace &&
        namespace_uri != strict_spreadsheet_namespace
      ) ||
      scanner.local_name() != "sheet" {
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
        match value.to_lower() {
          "hidden" => Hidden
          "veryhidden" => VeryHidden
          _ => Visible
        }
      None => Visible
    }
    sheets.push({ name, state, rel_id })
  }
  sheets
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
