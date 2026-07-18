///|
let xlsx_extension_namespace_x14 = "http://schemas.microsoft.com/office/spreadsheetml/2009/9/main"

///|
let xlsx_extension_namespace_x15 = "http://schemas.microsoft.com/office/spreadsheetml/2010/11/main"

///|
let xlsx_extension_namespace_xm = "http://schemas.microsoft.com/office/excel/2006/main"

///|
/// Converts namespace-qualified OOXML element names into the lexical form used
/// by the existing bounded feature parsers. The source is fully namespace- and
/// structure-validated before rewriting; only names change, never values.
fn canonicalize_xlsx_xml(
  xml : StringView,
  max_output_chars? : Int = default_max_xml_part_bytes,
  cancelled? : () -> Bool = () => false,
) -> String raise XlsxError {
  let root_scanner = @ooxml.XmlStartTagScanner::new(xml, cancelled~)
  if !workbook_scanner_next(root_scanner) || root_scanner.depth() != 1 {
    raise InvalidXml(msg="XLSX XML document element is missing")
  }
  let root_namespace = root_scanner.namespace_uri().to_owned()
  let unprefixed_namespaces = [
    transitional_spreadsheet_namespace, strict_spreadsheet_namespace,
  ]
  let extension_prefixes : Array[(String, String)] = []
  for
    namespace_and_prefix in [
      (xlsx_extension_namespace_x14, "x14"),
      (xlsx_extension_namespace_x15, "x15"),
      (xlsx_extension_namespace_xm, "xm"),
    ] {
    let (namespace_uri, prefix) = namespace_and_prefix
    if namespace_uri == root_namespace {
      unprefixed_namespaces.push(namespace_uri)
    } else {
      extension_prefixes.push((namespace_uri, prefix))
    }
  }
  @ooxml.canonicalize_xml_expanded_names(
    xml,
    unprefixed_namespaces,
    [
      (transitional_relationship_attribute_namespace, "r"),
      (strict_relationship_attribute_namespace, "r"),
    ],
    max_output_chars~,
    cancelled~,
    element_prefixes=extension_prefixes,
  ) catch {
    InvalidXml(msg~) => raise InvalidXml(msg~)
    ReadCancelled => raise ReadCancelled
  }
}

///|
/// Validates the SpreadsheetML document element and removes foreign-namespace
/// descendant subtrees from the namespace-oblivious core view. The original
/// canonical view remains available to extension-specific readers.
fn xlsx_core_source_without_foreign(
  source : StringView,
  root_local_name : StringView,
  cancelled? : () -> Bool = () => false,
) -> String? raise XlsxError {
  let scanner = @ooxml.XmlStartTagScanner::new(source, cancelled~)
  if !workbook_scanner_next(scanner) ||
    scanner.depth() != 1 ||
    scanner.local_name() != root_local_name ||
    (
      scanner.namespace_uri() != transitional_spreadsheet_namespace &&
      scanner.namespace_uri() != strict_spreadsheet_namespace
    ) {
    raise InvalidXml(
      msg="\{root_local_name.to_owned()} document element is invalid",
    )
  }
  let dialect = scanner.namespace_uri().to_owned()
  @ooxml.remove_xml_foreign_namespace_subtrees(source, [dialect], cancelled~) catch {
    InvalidXml(msg~) => raise InvalidXml(msg~)
    ReadCancelled => raise ReadCancelled
  }
}

///|
fn validate_xlsx_worksheet_core(
  xml : StringView,
  cancelled? : () -> Bool = () => false,
) -> Unit raise XlsxError {
  let scanner = @ooxml.XmlStartTagScanner::new(xml, cancelled~)
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
  cancelled? : () -> Bool = () => false,
) -> String raise XlsxError {
  let without_extensions = @ooxml.remove_xml_expanded_name_subtrees(
    source,
    [transitional_spreadsheet_namespace, strict_spreadsheet_namespace],
    "extLst",
    cancelled~,
  ) catch {
    InvalidXml(msg~) => raise InvalidXml(msg~)
    ReadCancelled => raise ReadCancelled
  }
  match without_extensions {
    Some(core_source) =>
      match
        xlsx_core_source_without_foreign(core_source, "worksheet", cancelled~) {
        Some(filtered) => {
          validate_xlsx_worksheet_core(filtered, cancelled~)
          canonicalize_xlsx_xml(filtered, max_output_chars~, cancelled~)
        }
        None => {
          validate_xlsx_worksheet_core(core_source, cancelled~)
          canonicalize_xlsx_xml(core_source, max_output_chars~, cancelled~)
        }
      }
    None =>
      match xlsx_core_source_without_foreign(source, "worksheet", cancelled~) {
        Some(filtered) => {
          validate_xlsx_worksheet_core(filtered, cancelled~)
          canonicalize_xlsx_xml(filtered, max_output_chars~, cancelled~)
        }
        None => {
          validate_xlsx_worksheet_core(source, cancelled~)
          full_canonical
        }
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

///|
test "XLSX XML canonicalization follows extension namespace identity" {
  let source =
    #|<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:validation="http://schemas.microsoft.com/office/spreadsheetml/2009/9/main" xmlns:formula="http://schemas.microsoft.com/office/excel/2006/main" xmlns:x14="urn:foreign"><extLst><ext><validation:dataValidations><validation:dataValidation><formula:sqref>A1</formula:sqref></validation:dataValidation></validation:dataValidations><x14:dataValidations/></ext></extLst></worksheet>
  let canonical = canonicalize_xlsx_xml(source)
  assert_true(canonical.contains("<x14:dataValidations>"))
  assert_true(canonical.contains("<xm:sqref>A1</xm:sqref>"))
  assert_true(canonical.contains("<_foreign_x14_dataValidations/>"))
}

///|
test "XLSX XML canonicalization propagates cancellation from a long pass" {
  let checks = [0]
  let source = "<worksheet xmlns=\"" +
    transitional_spreadsheet_namespace +
    "\"><sheetData>" +
    "x".repeat(32 * 1024) +
    "</sheetData></worksheet>"
  try
    canonicalize_xlsx_xml(source, cancelled=() => {
      checks[0] += 1
      checks[0] >= 12
    })
  catch {
    ReadCancelled => assert_true(checks[0] >= 12)
    _ => fail("expected XLSX canonicalization cancellation")
  } noraise {
    _ => fail("expected XLSX canonicalization cancellation")
  }
}
