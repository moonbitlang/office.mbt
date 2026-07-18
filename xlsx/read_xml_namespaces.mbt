///|
/// Converts namespace-qualified OOXML element names into the lexical form used
/// by the existing bounded feature parsers. The source is fully namespace- and
/// structure-validated before rewriting; only names change, never values.
fn canonicalize_xlsx_xml(
  xml : StringView,
  max_output_chars? : Int = default_max_xml_part_bytes,
) -> String raise XlsxError {
  @ooxml.canonicalize_xml_expanded_names(
    xml,
    [transitional_spreadsheet_namespace, strict_spreadsheet_namespace],
    [
      (transitional_relationship_attribute_namespace, "r"),
      (strict_relationship_attribute_namespace, "r"),
    ],
    max_output_chars~,
  ) catch {
    InvalidXml(msg~) => raise InvalidXml(msg~)
  }
}

///|
fn validate_xlsx_worksheet_core(xml : StringView) -> Unit raise XlsxError {
  let scanner = @ooxml.XmlStartTagScanner::new(xml)
  let mut worksheet_namespace : String? = None
  let mut sheet_data_seen = false
  let mut cell_formula_seen = false
  let mut cell_value_seen = false
  let mut cell_inline_string_seen = false
  while workbook_scanner_next(scanner) {
    let local_name = scanner.local_name()
    let namespace_uri = scanner.namespace_uri()
    if scanner.depth() == 1 {
      if local_name != "worksheet" ||
        (
          namespace_uri != transitional_spreadsheet_namespace &&
          namespace_uri != strict_spreadsheet_namespace
        ) {
        raise InvalidXml(msg="worksheet document element is invalid")
      }
      worksheet_namespace = Some(namespace_uri.to_owned())
      continue
    }
    let dialect = worksheet_namespace.unwrap_or("")
    if local_name == "sheetData" {
      if namespace_uri != dialect ||
        scanner.depth() != 2 ||
        scanner.parent_local_name() != Some("worksheet") ||
        scanner.parent_namespace_uri() != worksheet_namespace {
        raise InvalidXml(msg="worksheet sheetData element is misplaced")
      }
      if sheet_data_seen {
        raise InvalidXml(msg="worksheet has multiple sheetData elements")
      }
      sheet_data_seen = true
    } else if local_name == "row" {
      if namespace_uri != dialect ||
        scanner.depth() != 3 ||
        scanner.parent_local_name() != Some("sheetData") ||
        scanner.parent_namespace_uri() != worksheet_namespace {
        raise InvalidXml(msg="worksheet row element is misplaced")
      }
    } else if local_name == "c" {
      if namespace_uri != dialect ||
        scanner.depth() != 4 ||
        scanner.parent_local_name() != Some("row") ||
        scanner.parent_namespace_uri() != worksheet_namespace {
        raise InvalidXml(msg="worksheet cell element is misplaced")
      }
      cell_formula_seen = false
      cell_value_seen = false
      cell_inline_string_seen = false
    } else if local_name == "f" || local_name == "v" || local_name == "is" {
      if namespace_uri != dialect ||
        scanner.depth() != 5 ||
        scanner.parent_local_name() != Some("c") ||
        scanner.parent_namespace_uri() != worksheet_namespace {
        raise InvalidXml(msg="worksheet cell payload element is misplaced")
      }
      if local_name == "f" {
        if cell_formula_seen {
          raise InvalidXml(msg="worksheet cell has multiple formula elements")
        }
        cell_formula_seen = true
      } else if local_name == "v" {
        if cell_value_seen {
          raise InvalidXml(msg="worksheet cell has multiple value elements")
        }
        cell_value_seen = true
      } else {
        if cell_inline_string_seen {
          raise InvalidXml(
            msg="worksheet cell has multiple inline string elements",
          )
        }
        cell_inline_string_seen = true
      }
    } else if local_name == "r" {
      if namespace_uri != dialect ||
        scanner.depth() != 6 ||
        scanner.parent_local_name() != Some("is") ||
        scanner.parent_namespace_uri() != worksheet_namespace {
        raise InvalidXml(msg="worksheet inline string run is misplaced")
      }
    } else if local_name == "t" {
      let valid_parent = scanner.parent_local_name() == Some("is") ||
        scanner.parent_local_name() == Some("r") ||
        scanner.parent_local_name() == Some("rPh")
      if namespace_uri != dialect ||
        !valid_parent ||
        scanner.parent_namespace_uri() != worksheet_namespace ||
        (scanner.depth() != 6 && scanner.depth() != 7) {
        raise InvalidXml(msg="worksheet inline string text is misplaced")
      }
    } else if local_name == "cols" {
      if namespace_uri != dialect ||
        scanner.depth() != 2 ||
        scanner.parent_local_name() != Some("worksheet") ||
        scanner.parent_namespace_uri() != worksheet_namespace {
        raise InvalidXml(msg="worksheet cols element is misplaced")
      }
    } else if local_name == "col" {
      if namespace_uri != dialect ||
        scanner.depth() != 3 ||
        scanner.parent_local_name() != Some("cols") ||
        scanner.parent_namespace_uri() != worksheet_namespace {
        raise InvalidXml(msg="worksheet col element is misplaced")
      }
    }
  }
}

///|
/// Produces the namespace-oblivious view used by core worksheet parsers.
/// Extension payload stays available in the full canonical view, but is
/// removed before core elements are validated and flattened.
fn canonicalize_xlsx_worksheet_core(
  source : StringView,
  full_canonical : String,
  max_output_chars : Int,
) -> String raise XlsxError {
  let without_extensions = @ooxml.remove_xml_expanded_name_subtrees(
    source,
    [transitional_spreadsheet_namespace, strict_spreadsheet_namespace],
    "extLst",
  ) catch {
    InvalidXml(msg~) => raise InvalidXml(msg~)
  }
  match without_extensions {
    Some(core_source) => {
      validate_xlsx_worksheet_core(core_source)
      canonicalize_xlsx_xml(core_source, max_output_chars~)
    }
    None => {
      validate_xlsx_worksheet_core(source)
      full_canonical
    }
  }
}

///|
test "XLSX XML canonicalization handles Strict elements and relationship attributes" {
  let source =
    #|<s:worksheet xmlns:s="http://purl.oclc.org/ooxml/spreadsheetml/main" xmlns:q="http://purl.oclc.org/ooxml/officeDocument/relationships"><s:drawing q:id="d1"/><s:sheetData><s:row r="1"><s:c r="A1" t="str"><s:v>ok</s:v></s:c></s:row></s:sheetData></s:worksheet>
  inspect(
    canonicalize_xlsx_xml(source),
    content=(
      #|<worksheet xmlns:s="http://purl.oclc.org/ooxml/spreadsheetml/main" xmlns:q="http://purl.oclc.org/ooxml/officeDocument/relationships"><drawing r:id="d1"/><sheetData><row r="1"><c r="A1" t="str"><v>ok</v></c></row></sheetData></worksheet>
    ),
  )
}
