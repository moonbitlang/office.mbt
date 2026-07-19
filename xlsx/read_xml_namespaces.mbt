///|
let xlsx_extension_namespace_x14 = "http://schemas.microsoft.com/office/spreadsheetml/2009/9/main"

///|
let xlsx_extension_namespace_x15 = "http://schemas.microsoft.com/office/spreadsheetml/2010/11/main"

///|
let xlsx_extension_namespace_xm = "http://schemas.microsoft.com/office/excel/2006/main"

///|
let transitional_spreadsheet_drawing_namespace = "http://schemas.openxmlformats.org/drawingml/2006/spreadsheetDrawing"

///|
let strict_spreadsheet_drawing_namespace = "http://purl.oclc.org/ooxml/drawingml/spreadsheetDrawing"

///|
let transitional_drawing_main_namespace = "http://schemas.openxmlformats.org/drawingml/2006/main"

///|
let strict_drawing_main_namespace = "http://purl.oclc.org/ooxml/drawingml/main"

///|
let transitional_drawing_chart_namespace = "http://schemas.openxmlformats.org/drawingml/2006/chart"

///|
let strict_drawing_chart_namespace = "http://purl.oclc.org/ooxml/drawingml/chart"

///|
let drawing_slicer_namespace = "http://schemas.microsoft.com/office/drawing/2010/slicer"

///|
let drawing_main_2010_namespace = "http://schemas.microsoft.com/office/drawing/2010/main"

///|
let drawing_slicer_2012_namespace = "http://schemas.microsoft.com/office/drawing/2012/slicer"

///|
let markup_compatibility_namespace = "http://schemas.openxmlformats.org/markup-compatibility/2006"

///|
let xlsx_mce_understood_namespaces : Array[String] = [
  transitional_spreadsheet_namespace, strict_spreadsheet_namespace, transitional_relationship_attribute_namespace,
  strict_relationship_attribute_namespace,
]

///|
let xlsx_mce_extension_elements : Array[(String, String)] = [
  (transitional_spreadsheet_namespace, "ext"),
  (strict_spreadsheet_namespace, "ext"),
]

///|
let xlsx_drawing_mce_understood_namespaces : Array[String] = [
  transitional_spreadsheet_drawing_namespace, strict_spreadsheet_drawing_namespace,
  transitional_drawing_main_namespace, strict_drawing_main_namespace, transitional_drawing_chart_namespace,
  strict_drawing_chart_namespace, drawing_slicer_namespace, transitional_relationship_attribute_namespace,
  strict_relationship_attribute_namespace, drawing_main_2010_namespace, drawing_slicer_2012_namespace,
]

///|
let xlsx_drawing_mce_extension_elements : Array[(String, String)] = [
  (transitional_drawing_main_namespace, "ext"),
  (strict_drawing_main_namespace, "ext"),
  (transitional_drawing_chart_namespace, "ext"),
  (strict_drawing_chart_namespace, "ext"),
  (drawing_slicer_namespace, "ext"),
]

///|
let xlsx_drawing_extension_list_namespaces : Array[String] = [
  transitional_spreadsheet_drawing_namespace, strict_spreadsheet_drawing_namespace,
  transitional_drawing_main_namespace, strict_drawing_main_namespace, transitional_drawing_chart_namespace,
  strict_drawing_chart_namespace, drawing_slicer_namespace, drawing_main_2010_namespace,
  drawing_slicer_2012_namespace,
]

///|
let xlsx_drawing_core_element_namespaces : Array[String] = [
  transitional_spreadsheet_drawing_namespace, strict_spreadsheet_drawing_namespace,
  transitional_drawing_main_namespace, strict_drawing_main_namespace, transitional_drawing_chart_namespace,
  strict_drawing_chart_namespace, drawing_slicer_namespace,
]

///|
fn xlsx_drawing_anchor_name(local_name : StringView) -> Bool {
  local_name == "oneCellAnchor" || local_name == "twoCellAnchor"
}

///|
fn xlsx_drawing_reader_object_name(local_name : StringView) -> Bool {
  local_name == "pic" || local_name == "sp" || local_name == "graphicFrame"
}

///|
/// Proves that every element consumed by a namespace-oblivious drawing reader
/// occurs on the schema path that reader assumes. Merely filtering namespaces
/// is insufficient: a supported-namespace decoy nested in `graphicData`, a
/// group, or another anchor would otherwise win the readers' first-match
/// lexical searches.
fn validate_xlsx_drawing_reader_structure(
  source : StringView,
  cancelled? : () -> Bool = () => false,
) -> Unit raise XlsxError {
  let scanner = @ooxml.XmlStartTagScanner::new(source, cancelled~)
  if !workbook_scanner_next(scanner) ||
    scanner.depth() != 1 ||
    scanner.local_name() != "wsDr" ||
    (
      scanner.namespace_uri() != transitional_spreadsheet_drawing_namespace &&
      scanner.namespace_uri() != strict_spreadsheet_drawing_namespace
    ) {
    raise InvalidXml(msg="drawing document element is invalid")
  }
  let drawing_namespace = scanner.namespace_uri().to_owned()
  let (main_namespace, chart_namespace) = if drawing_namespace ==
    transitional_spreadsheet_drawing_namespace {
    (transitional_drawing_main_namespace, transitional_drawing_chart_namespace)
  } else {
    (strict_drawing_main_namespace, strict_drawing_chart_namespace)
  }
  let mut in_reader_anchor = false
  let mut reader_object_seen = false
  let mut reader_payload_seen = false
  let mut graphic_data_uri : String? = None
  let mut extension_depth : Int? = None
  while workbook_scanner_next(scanner) {
    let depth = scanner.depth()
    let local_name = scanner.local_name()
    let namespace_uri = scanner.namespace_uri().to_owned()
    if depth <= 2 {
      in_reader_anchor = false
      reader_object_seen = false
      reader_payload_seen = false
    }
    if depth <= 5 {
      graphic_data_uri = None
    }
    match extension_depth {
      Some(extension_start) if depth > extension_start =>
        raise InvalidXml(msg="drawing extension payload is misplaced")
      Some(_) => extension_depth = None
      None => ()
    }
    if local_name == "ext" &&
      xlsx_drawing_extension_list_namespaces.any(candidate => {
        candidate == namespace_uri
      }) {
      extension_depth = Some(depth)
    }
    if namespace_uri == drawing_namespace &&
      xlsx_drawing_anchor_name(local_name) {
      if depth != 2 ||
        scanner.parent_local_name() != Some("wsDr") ||
        scanner.parent_namespace_uri() != Some(drawing_namespace) {
        raise InvalidXml(msg="drawing anchor is misplaced")
      }
      in_reader_anchor = true
      reader_object_seen = false
      reader_payload_seen = false
    } else if namespace_uri == drawing_namespace &&
      xlsx_drawing_reader_object_name(local_name) {
      if depth != 3 ||
        !in_reader_anchor ||
        !xlsx_drawing_anchor_name(scanner.parent_local_name().unwrap_or("")) ||
        scanner.parent_namespace_uri() != Some(drawing_namespace) {
        raise InvalidXml(msg="drawing reader object is misplaced")
      }
      if reader_object_seen {
        raise InvalidXml(msg="drawing anchor has multiple reader objects")
      }
      reader_object_seen = true
    } else if namespace_uri == main_namespace && local_name == "graphic" {
      if depth != 4 ||
        scanner.parent_local_name() != Some("graphicFrame") ||
        scanner.parent_namespace_uri() != Some(drawing_namespace) {
        raise InvalidXml(msg="drawing graphic element is misplaced")
      }
    } else if namespace_uri == main_namespace && local_name == "graphicData" {
      if depth != 5 ||
        scanner.parent_local_name() != Some("graphic") ||
        scanner.parent_namespace_uri() != Some(main_namespace) {
        raise InvalidXml(msg="drawing graphicData element is misplaced")
      }
      graphic_data_uri = workbook_scanner_attribute(scanner, "", "uri")
    } else if (
        namespace_uri == transitional_drawing_chart_namespace ||
        namespace_uri == strict_drawing_chart_namespace
      ) &&
      local_name == "chart" {
      if namespace_uri != chart_namespace ||
        depth != 6 ||
        scanner.parent_local_name() != Some("graphicData") ||
        scanner.parent_namespace_uri() != Some(main_namespace) {
        raise InvalidXml(msg="drawing chart payload is misplaced")
      }
      if graphic_data_uri != Some(chart_namespace) {
        raise InvalidXml(msg="drawing chart graphicData URI is invalid")
      }
      if reader_payload_seen {
        raise InvalidXml(msg="drawing anchor has multiple reader payloads")
      }
      reader_payload_seen = true
    } else if namespace_uri == drawing_slicer_namespace &&
      local_name == "slicer" {
      if depth != 6 ||
        scanner.parent_local_name() != Some("graphicData") ||
        scanner.parent_namespace_uri() != Some(main_namespace) {
        raise InvalidXml(msg="drawing slicer payload is misplaced")
      }
      if graphic_data_uri != Some(drawing_slicer_namespace) {
        raise InvalidXml(msg="drawing slicer graphicData URI is invalid")
      }
      if reader_payload_seen {
        raise InvalidXml(msg="drawing anchor has multiple reader payloads")
      }
      reader_payload_seen = true
    }
  }
}

///|
/// Produces the effective SpreadsheetML view before namespace filtering or
/// lexical feature parsing. In particular, core content promoted from an MCE
/// Fallback must be selected while its namespace context is still available.
fn project_xlsx_markup_compatibility(
  source : StringView,
  max_output_chars : Int,
  cancelled? : () -> Bool = () => false,
) -> String raise XlsxError {
  @ooxml.project_xml_markup_compatibility(
    source,
    xlsx_mce_understood_namespaces,
    max_output_chars~,
    cancelled~,
    extension_elements=xlsx_mce_extension_elements,
  ) catch {
    InvalidXml(msg~) => raise InvalidXml(msg~)
    ReadCancelled => raise ReadCancelled
  }
}

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
/// Produces the extension-aware worksheet view used by known feature parsers.
/// Core SpreadsheetML plus the explicitly supported x14/x15/xm namespaces are
/// retained; every other namespace subtree is removed before lexical parsing,
/// including a foreign default namespace that reuses a core local name.
fn canonicalize_xlsx_worksheet_features(
  source : StringView,
  max_output_chars : Int,
  cancelled? : () -> Bool = () => false,
) -> String raise XlsxError {
  let scanner = @ooxml.XmlStartTagScanner::new(source, cancelled~)
  if !workbook_scanner_next(scanner) ||
    scanner.depth() != 1 ||
    scanner.local_name() != "worksheet" ||
    (
      scanner.namespace_uri() != transitional_spreadsheet_namespace &&
      scanner.namespace_uri() != strict_spreadsheet_namespace
    ) {
    raise InvalidXml(msg="worksheet document element is invalid")
  }
  let dialect = scanner.namespace_uri().to_owned()
  let filtered = @ooxml.remove_xml_foreign_namespace_subtrees(
    source,
    [
      dialect, xlsx_extension_namespace_x14, xlsx_extension_namespace_x15, xlsx_extension_namespace_xm,
    ],
    cancelled~,
  ) catch {
    InvalidXml(msg~) => raise InvalidXml(msg~)
    ReadCancelled => raise ReadCancelled
  }
  canonicalize_xlsx_xml(
    filtered.unwrap_or(source.to_owned()),
    max_output_chars~,
    cancelled~,
  )
}

///|
/// Produces the effective DrawingML view and canonicalizes it by expanded
/// namespace identity. MCE selection must run first, while `Choice.Requires`
/// prefixes still have their original namespace bindings; otherwise a lexical
/// feature reader could consume an unsupported branch ahead of its fallback.
/// Prefix aliases and default namespaces are then normalized to the names used
/// by the drawing readers, while a foreign namespace borrowing `xdr`, `a`,
/// `c`, `sle`, or `mc` is defanged by the bounded XML canonicalizer.
fn canonicalize_xlsx_drawing_xml(
  source : StringView,
  max_output_chars : Int,
  cancelled? : () -> Bool = () => false,
) -> String raise XlsxError {
  let scanner = @ooxml.XmlStartTagScanner::new(source, cancelled~)
  if !workbook_scanner_next(scanner) ||
    scanner.depth() != 1 ||
    scanner.local_name() != "wsDr" ||
    (
      scanner.namespace_uri() != transitional_spreadsheet_drawing_namespace &&
      scanner.namespace_uri() != strict_spreadsheet_drawing_namespace
    ) {
    raise InvalidXml(msg="drawing document element is invalid")
  }
  // Application extension payload is deliberately absent from the lexical
  // reader view. Removing its structural container before MCE projection also
  // prevents directives inside opaque payload from affecting core selection.
  let without_extension_lists = @ooxml.remove_xml_expanded_name_subtrees(
    source,
    xlsx_drawing_extension_list_namespaces,
    "extLst",
    cancelled~,
  ) catch {
    InvalidXml(msg~) => raise InvalidXml(msg~)
    ReadCancelled => raise ReadCancelled
  }
  let projected = @ooxml.project_xml_markup_compatibility(
    without_extension_lists.unwrap_or(source.to_owned()),
    xlsx_drawing_mce_understood_namespaces,
    max_output_chars~,
    cancelled~,
    extension_elements=xlsx_drawing_mce_extension_elements,
  ) catch {
    InvalidXml(msg~) => raise InvalidXml(msg~)
    ReadCancelled => raise ReadCancelled
  }
  // Foreign wrappers are removed with their descendants. Merely renaming a
  // wrapper would leave nested core-looking tags visible to lexical readers.
  let core_projected = @ooxml.remove_xml_foreign_namespace_subtrees(
    projected,
    xlsx_drawing_core_element_namespaces,
    cancelled~,
  ) catch {
    InvalidXml(msg~) => raise InvalidXml(msg~)
    ReadCancelled => raise ReadCancelled
  }
  let reader_source = core_projected.unwrap_or(projected)
  validate_xlsx_drawing_reader_structure(reader_source, cancelled~)
  @ooxml.canonicalize_xml_expanded_names(
    reader_source,
    [],
    [
      (transitional_relationship_attribute_namespace, "r"),
      (strict_relationship_attribute_namespace, "r"),
    ],
    max_output_chars~,
    cancelled~,
    element_prefixes=[
      (transitional_spreadsheet_drawing_namespace, "xdr"),
      (strict_spreadsheet_drawing_namespace, "xdr"),
      (transitional_drawing_main_namespace, "a"),
      (strict_drawing_main_namespace, "a"),
      (transitional_drawing_chart_namespace, "c"),
      (strict_drawing_chart_namespace, "c"),
      (drawing_slicer_namespace, "sle"),
      (markup_compatibility_namespace, "mc"),
    ],
  ) catch {
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
test "SpreadsheetML MCE fallback is projected before core filtering" {
  let workbook_source =
    #|<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006" xmlns:x="urn:vendor" mc:Ignorable="x"><mc:AlternateContent><mc:Choice Requires="x"><x:futureSheets/></mc:Choice><mc:Fallback><sheets><sheet name="Data" sheetId="1" r:id="rId1"/></sheets></mc:Fallback></mc:AlternateContent></workbook>
  let workbook_projected = project_xlsx_markup_compatibility(
    workbook_source, default_max_xml_part_bytes,
  )
  let sheets = parse_workbook_sheets(workbook_projected, 10)
  assert_eq(sheets.length(), 1)
  assert_eq(sheets[0].name, "Data")
  assert_eq(sheets[0].rel_id, "rId1")
  let worksheet_source =
    #|<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006" xmlns:x="urn:vendor" mc:Ignorable="x"><mc:AlternateContent><mc:Choice Requires="x"><x:futureData/></mc:Choice><mc:Fallback><sheetData><row r="1"><c r="A1" t="str"><v>kept</v></c></row></sheetData></mc:Fallback></mc:AlternateContent></worksheet>
  let worksheet_projected = project_xlsx_markup_compatibility(
    worksheet_source, default_max_xml_part_bytes,
  )
  let worksheet_full = canonicalize_xlsx_xml(worksheet_projected)
  let worksheet_core = canonicalize_xlsx_worksheet_core(
    worksheet_projected, worksheet_full, default_max_xml_part_bytes,
  )
  assert_true(worksheet_core.contains("<sheetData>"))
  assert_true(worksheet_core.contains("<v>kept</v>"))
  assert_false(worksheet_core.contains("futureData"))
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
test "DrawingML canonicalization follows aliases and removes foreign subtrees" {
  let valid =
    #|<wsDr xmlns="http://schemas.openxmlformats.org/drawingml/2006/spreadsheetDrawing" xmlns:d="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:q="http://schemas.openxmlformats.org/drawingml/2006/chart" xmlns:rel="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:compat="http://schemas.openxmlformats.org/markup-compatibility/2006"><oneCellAnchor><compat:AlternateContent><compat:Choice Requires="q"><graphicFrame><d:graphic><d:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/chart"><q:chart rel:id="chart"/></d:graphicData></d:graphic></graphicFrame></compat:Choice></compat:AlternateContent></oneCellAnchor></wsDr>
  let canonical = canonicalize_xlsx_drawing_xml(
    valid, default_max_xml_part_bytes,
  )
  assert_true(canonical.contains("<xdr:wsDr"))
  assert_true(canonical.contains("<xdr:oneCellAnchor>"))
  assert_true(canonical.contains("<xdr:graphicFrame>"))
  assert_true(canonical.contains("<a:graphic>"))
  assert_true(canonical.contains("<c:chart r:id=\"chart\"/>"))
  assert_false(canonical.contains("<mc:AlternateContent"))
  assert_false(canonical.contains("<mc:Choice"))
  let spoofed =
    #|<xdr:wsDr xmlns:xdr="http://schemas.openxmlformats.org/drawingml/2006/spreadsheetDrawing" xmlns:mc="urn:foreign"><xdr:oneCellAnchor xmlns:xdr="urn:foreign"><mc:AlternateContent/></xdr:oneCellAnchor></xdr:wsDr>
  let spoofed_canonical = canonicalize_xlsx_drawing_xml(
    spoofed, default_max_xml_part_bytes,
  )
  assert_false(spoofed_canonical.contains("oneCellAnchor"))
  assert_false(spoofed_canonical.contains("AlternateContent"))
  assert_false(spoofed_canonical.contains("<mc:AlternateContent"))
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
