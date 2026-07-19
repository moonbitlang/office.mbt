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
  local_name == "oneCellAnchor" ||
  local_name == "twoCellAnchor" ||
  local_name == "absoluteAnchor"
}

///|
fn xlsx_drawing_reader_object_name(local_name : StringView) -> Bool {
  local_name == "pic" || local_name == "sp" || local_name == "graphicFrame"
}

///|
fn drawing_reader_relationship_attribute(
  scanner : @ooxml.XmlStartTagScanner,
  relationship_namespace : StringView,
  other_relationship_namespace : StringView,
  local_name : StringView,
  required : Bool,
) -> String? raise XlsxError {
  if workbook_scanner_attribute(
      scanner, other_relationship_namespace, local_name,
    )
    is Some(_) {
    raise InvalidXml(msg="drawing relationship attribute dialect is invalid")
  }
  match
    workbook_scanner_attribute(scanner, relationship_namespace, local_name) {
    Some(value) if value != "" => Some(value)
    _ if required =>
      raise InvalidXml(msg="drawing relationship attribute is missing")
    _ => None
  }
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
  let (
    main_namespace,
    chart_namespace,
    other_drawing_namespace,
    other_main_namespace,
    other_chart_namespace,
    relationship_namespace,
    other_relationship_namespace,
  ) = if drawing_namespace == transitional_spreadsheet_drawing_namespace {
    (
      transitional_drawing_main_namespace, transitional_drawing_chart_namespace,
      strict_spreadsheet_drawing_namespace, strict_drawing_main_namespace, strict_drawing_chart_namespace,
      transitional_relationship_attribute_namespace, strict_relationship_attribute_namespace,
    )
  } else {
    (
      strict_drawing_main_namespace, strict_drawing_chart_namespace, transitional_spreadsheet_drawing_namespace,
      transitional_drawing_main_namespace, transitional_drawing_chart_namespace,
      strict_relationship_attribute_namespace, transitional_relationship_attribute_namespace,
    )
  }
  let mut in_reader_anchor = false
  let mut anchor_name = ""
  let mut reader_object_seen = false
  let mut current_reader_object = ""
  let mut reader_payload_seen = false
  let mut graphic_data_uri : String? = None
  let mut extension_depth : Int? = None
  let mut text_body_depth : Int? = None
  let mut solid_fill_depth : Int? = None
  let mut color_depth : Int? = None
  let mut marker_parent = ""
  let mut marker_col_seen = false
  let mut marker_col_off_seen = false
  let mut marker_row_seen = false
  let mut marker_row_off_seen = false
  let mut from_seen = false
  let mut to_seen = false
  let mut anchor_ext_seen = false
  let mut client_data_seen = false
  let mut non_visual_container_seen = false
  let mut c_nv_pr_seen = false
  let mut c_nv_pic_pr_seen = false
  let mut blip_fill_seen = false
  let mut blip_seen = false
  let mut hyperlink_seen = false
  let mut pic_locks_seen = false
  let mut sp_pr_seen = false
  let mut xfrm_seen = false
  let mut xfrm_ext_seen = false
  let mut geometry_seen = false
  let mut shape_fill_seen = false
  let mut line_seen = false
  let mut line_fill_seen = false
  let mut color_seen = false
  let mut alpha_seen = false
  let mut text_body_seen = false
  let mut graphic_seen = false
  let mut graphic_data_seen = false
  while workbook_scanner_next(scanner) {
    let depth = scanner.depth()
    let local_name = scanner.local_name()
    let namespace_uri = scanner.namespace_uri().to_owned()
    match text_body_depth {
      Some(start) if depth <= start => text_body_depth = None
      _ => ()
    }
    match solid_fill_depth {
      Some(start) if depth <= start => solid_fill_depth = None
      _ => ()
    }
    match color_depth {
      Some(start) if depth <= start => color_depth = None
      _ => ()
    }
    if depth <= 2 {
      in_reader_anchor = false
      anchor_name = ""
      reader_object_seen = false
      current_reader_object = ""
      reader_payload_seen = false
      from_seen = false
      to_seen = false
      anchor_ext_seen = false
      client_data_seen = false
    } else if depth <= 3 {
      current_reader_object = ""
      marker_parent = ""
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
    if namespace_uri == other_drawing_namespace ||
      namespace_uri == other_main_namespace ||
      namespace_uri == other_chart_namespace {
      raise InvalidXml(msg="drawing reader target dialect is mixed")
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
      anchor_name = local_name.to_owned()
      reader_object_seen = false
      current_reader_object = ""
      reader_payload_seen = false
      from_seen = false
      to_seen = false
      anchor_ext_seen = false
      client_data_seen = false
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
      current_reader_object = local_name.to_owned()
      non_visual_container_seen = false
      c_nv_pr_seen = false
      c_nv_pic_pr_seen = false
      blip_fill_seen = false
      blip_seen = false
      hyperlink_seen = false
      pic_locks_seen = false
      sp_pr_seen = false
      xfrm_seen = false
      xfrm_ext_seen = false
      geometry_seen = false
      shape_fill_seen = false
      line_seen = false
      line_fill_seen = false
      color_seen = false
      alpha_seen = false
      text_body_seen = false
      graphic_seen = false
      graphic_data_seen = false
    } else if namespace_uri == drawing_namespace &&
      (
        local_name == "from" ||
        local_name == "to" ||
        local_name == "ext" ||
        local_name == "clientData"
      ) {
      if depth != 3 ||
        !in_reader_anchor ||
        scanner.parent_local_name() != Some(anchor_name) ||
        scanner.parent_namespace_uri() != Some(drawing_namespace) {
        raise InvalidXml(msg="drawing anchor reader target is misplaced")
      }
      if local_name == "from" {
        if from_seen {
          raise InvalidXml(msg="drawing anchor from target is duplicated")
        }
        from_seen = true
        marker_parent = "from"
        marker_col_seen = false
        marker_col_off_seen = false
        marker_row_seen = false
        marker_row_off_seen = false
      } else if local_name == "to" {
        if to_seen {
          raise InvalidXml(msg="drawing anchor to target is duplicated")
        }
        to_seen = true
        marker_parent = "to"
        marker_col_seen = false
        marker_col_off_seen = false
        marker_row_seen = false
        marker_row_off_seen = false
      } else if local_name == "ext" {
        if anchor_ext_seen {
          raise InvalidXml(msg="drawing anchor ext target is duplicated")
        }
        anchor_ext_seen = true
      } else {
        if client_data_seen {
          raise InvalidXml(msg="drawing clientData target is duplicated")
        }
        client_data_seen = true
      }
    } else if namespace_uri == drawing_namespace &&
      (
        local_name == "col" ||
        local_name == "colOff" ||
        local_name == "row" ||
        local_name == "rowOff"
      ) {
      if depth != 4 ||
        (marker_parent != "from" && marker_parent != "to") ||
        scanner.parent_local_name() != Some(marker_parent) ||
        scanner.parent_namespace_uri() != Some(drawing_namespace) {
        raise InvalidXml(msg="drawing marker target is misplaced")
      }
      if local_name == "col" {
        if marker_col_seen {
          raise InvalidXml(msg="drawing marker col target is duplicated")
        }
        marker_col_seen = true
      } else if local_name == "colOff" {
        if marker_col_off_seen {
          raise InvalidXml(msg="drawing marker colOff target is duplicated")
        }
        marker_col_off_seen = true
      } else if local_name == "row" {
        if marker_row_seen {
          raise InvalidXml(msg="drawing marker row target is duplicated")
        }
        marker_row_seen = true
      } else {
        if marker_row_off_seen {
          raise InvalidXml(msg="drawing marker rowOff target is duplicated")
        }
        marker_row_off_seen = true
      }
    } else if namespace_uri == drawing_namespace &&
      (
        local_name == "nvPicPr" ||
        local_name == "nvSpPr" ||
        local_name == "nvGraphicFramePr"
      ) {
      let expected = if current_reader_object == "pic" {
        "nvPicPr"
      } else if current_reader_object == "sp" {
        "nvSpPr"
      } else {
        "nvGraphicFramePr"
      }
      if current_reader_object == "" ||
        local_name != expected ||
        depth != 4 ||
        scanner.parent_local_name() != Some(current_reader_object) ||
        scanner.parent_namespace_uri() != Some(drawing_namespace) {
        raise InvalidXml(msg="drawing nonvisual target is misplaced")
      }
      if non_visual_container_seen {
        raise InvalidXml(msg="drawing nonvisual target is duplicated")
      }
      non_visual_container_seen = true
    } else if namespace_uri == drawing_namespace && local_name == "cNvPr" {
      let expected_parent = if current_reader_object == "pic" {
        "nvPicPr"
      } else if current_reader_object == "sp" {
        "nvSpPr"
      } else {
        "nvGraphicFramePr"
      }
      if current_reader_object == "" ||
        depth != 5 ||
        scanner.parent_local_name() != Some(expected_parent) ||
        scanner.parent_namespace_uri() != Some(drawing_namespace) {
        raise InvalidXml(msg="drawing cNvPr target is misplaced")
      }
      if c_nv_pr_seen {
        raise InvalidXml(msg="drawing cNvPr target is duplicated")
      }
      c_nv_pr_seen = true
    } else if namespace_uri == drawing_namespace && local_name == "cNvPicPr" {
      if current_reader_object != "pic" ||
        depth != 5 ||
        scanner.parent_local_name() != Some("nvPicPr") ||
        scanner.parent_namespace_uri() != Some(drawing_namespace) {
        raise InvalidXml(msg="drawing cNvPicPr target is misplaced")
      }
      if c_nv_pic_pr_seen {
        raise InvalidXml(msg="drawing cNvPicPr target is duplicated")
      }
      c_nv_pic_pr_seen = true
    } else if namespace_uri == drawing_namespace && local_name == "blipFill" {
      if current_reader_object != "pic" ||
        depth != 4 ||
        scanner.parent_local_name() != Some("pic") ||
        scanner.parent_namespace_uri() != Some(drawing_namespace) {
        raise InvalidXml(msg="drawing blipFill target is misplaced")
      }
      if blip_fill_seen {
        raise InvalidXml(msg="drawing blipFill target is duplicated")
      }
      blip_fill_seen = true
    } else if namespace_uri == drawing_namespace && local_name == "spPr" {
      if (current_reader_object != "sp" && current_reader_object != "pic") ||
        depth != 4 ||
        scanner.parent_local_name() != Some(current_reader_object) ||
        scanner.parent_namespace_uri() != Some(drawing_namespace) {
        raise InvalidXml(msg="drawing spPr target is misplaced")
      }
      if sp_pr_seen {
        raise InvalidXml(msg="drawing spPr target is duplicated")
      }
      sp_pr_seen = true
    } else if namespace_uri == drawing_namespace && local_name == "txBody" {
      if current_reader_object != "sp" ||
        depth != 4 ||
        scanner.parent_local_name() != Some("sp") ||
        scanner.parent_namespace_uri() != Some(drawing_namespace) {
        raise InvalidXml(msg="drawing txBody target is misplaced")
      }
      if text_body_seen {
        raise InvalidXml(msg="drawing txBody target is duplicated")
      }
      text_body_seen = true
      text_body_depth = Some(depth)
    } else if namespace_uri == main_namespace && local_name == "graphic" {
      if depth != 4 ||
        current_reader_object != "graphicFrame" ||
        scanner.parent_local_name() != Some("graphicFrame") ||
        scanner.parent_namespace_uri() != Some(drawing_namespace) {
        raise InvalidXml(msg="drawing graphic element is misplaced")
      }
      if graphic_seen {
        raise InvalidXml(msg="drawing graphic element is duplicated")
      }
      graphic_seen = true
    } else if namespace_uri == main_namespace && local_name == "graphicData" {
      if depth != 5 ||
        current_reader_object != "graphicFrame" ||
        scanner.parent_local_name() != Some("graphic") ||
        scanner.parent_namespace_uri() != Some(main_namespace) {
        raise InvalidXml(msg="drawing graphicData element is misplaced")
      }
      if graphic_data_seen {
        raise InvalidXml(msg="drawing graphicData element is duplicated")
      }
      graphic_data_seen = true
      graphic_data_uri = workbook_scanner_attribute(scanner, "", "uri")
    } else if namespace_uri == main_namespace &&
      local_name == "blip" &&
      current_reader_object == "pic" {
      if depth != 5 ||
        scanner.parent_local_name() != Some("blipFill") ||
        scanner.parent_namespace_uri() != Some(drawing_namespace) {
        raise InvalidXml(msg="drawing blip target is misplaced")
      }
      if blip_seen {
        raise InvalidXml(msg="drawing blip target is duplicated")
      }
      blip_seen = true
      ignore(
        drawing_reader_relationship_attribute(
          scanner, relationship_namespace, other_relationship_namespace, "embed",
          true,
        ),
      )
    } else if namespace_uri == main_namespace &&
      local_name == "hlinkClick" &&
      current_reader_object == "pic" {
      if depth != 6 ||
        scanner.parent_local_name() != Some("cNvPr") ||
        scanner.parent_namespace_uri() != Some(drawing_namespace) {
        raise InvalidXml(msg="drawing hyperlink target is misplaced")
      }
      if hyperlink_seen {
        raise InvalidXml(msg="drawing hyperlink target is duplicated")
      }
      hyperlink_seen = true
      ignore(
        drawing_reader_relationship_attribute(
          scanner, relationship_namespace, other_relationship_namespace, "id", false,
        ),
      )
    } else if namespace_uri == main_namespace && local_name == "picLocks" {
      if current_reader_object != "pic" ||
        depth != 6 ||
        scanner.parent_local_name() != Some("cNvPicPr") ||
        scanner.parent_namespace_uri() != Some(drawing_namespace) {
        raise InvalidXml(msg="drawing picLocks target is misplaced")
      }
      if pic_locks_seen {
        raise InvalidXml(msg="drawing picLocks target is duplicated")
      }
      pic_locks_seen = true
    } else if namespace_uri == main_namespace &&
      local_name == "xfrm" &&
      current_reader_object == "sp" {
      if depth != 5 ||
        scanner.parent_local_name() != Some("spPr") ||
        scanner.parent_namespace_uri() != Some(drawing_namespace) {
        raise InvalidXml(msg="drawing xfrm target is misplaced")
      }
      if xfrm_seen {
        raise InvalidXml(msg="drawing xfrm target is duplicated")
      }
      xfrm_seen = true
    } else if namespace_uri == main_namespace &&
      local_name == "ext" &&
      current_reader_object == "sp" {
      if depth != 6 ||
        scanner.parent_local_name() != Some("xfrm") ||
        scanner.parent_namespace_uri() != Some(main_namespace) {
        raise InvalidXml(msg="drawing shape ext target is misplaced")
      }
      if xfrm_ext_seen {
        raise InvalidXml(msg="drawing shape ext target is duplicated")
      }
      xfrm_ext_seen = true
    } else if namespace_uri == main_namespace &&
      local_name == "prstGeom" &&
      current_reader_object == "sp" {
      if depth != 5 ||
        scanner.parent_local_name() != Some("spPr") ||
        scanner.parent_namespace_uri() != Some(drawing_namespace) {
        raise InvalidXml(msg="drawing geometry target is misplaced")
      }
      if geometry_seen {
        raise InvalidXml(msg="drawing geometry target is duplicated")
      }
      geometry_seen = true
    } else if namespace_uri == main_namespace &&
      local_name == "solidFill" &&
      current_reader_object == "sp" {
      let shape_fill = depth == 5 &&
        scanner.parent_local_name() == Some("spPr") &&
        scanner.parent_namespace_uri() == Some(drawing_namespace)
      let line_fill = depth == 6 &&
        scanner.parent_local_name() == Some("ln") &&
        scanner.parent_namespace_uri() == Some(main_namespace)
      if !shape_fill && !line_fill {
        raise InvalidXml(msg="drawing solidFill target is misplaced")
      }
      if shape_fill {
        if shape_fill_seen {
          raise InvalidXml(msg="drawing shape fill target is duplicated")
        }
        shape_fill_seen = true
      } else {
        if line_fill_seen {
          raise InvalidXml(msg="drawing line fill target is duplicated")
        }
        line_fill_seen = true
      }
      solid_fill_depth = Some(depth)
      color_seen = false
      alpha_seen = false
    } else if namespace_uri == main_namespace &&
      local_name == "srgbClr" &&
      current_reader_object == "sp" {
      let fill_depth = solid_fill_depth.unwrap_or(-1)
      if depth != fill_depth + 1 ||
        scanner.parent_local_name() != Some("solidFill") ||
        scanner.parent_namespace_uri() != Some(main_namespace) {
        raise InvalidXml(msg="drawing color target is misplaced")
      }
      if color_seen {
        raise InvalidXml(msg="drawing color target is duplicated")
      }
      color_seen = true
      alpha_seen = false
      color_depth = Some(depth)
    } else if namespace_uri == main_namespace &&
      local_name == "alpha" &&
      current_reader_object == "sp" {
      let parent_depth = color_depth.unwrap_or(-1)
      if depth != parent_depth + 1 ||
        scanner.parent_local_name() != Some("srgbClr") ||
        scanner.parent_namespace_uri() != Some(main_namespace) {
        raise InvalidXml(msg="drawing alpha target is misplaced")
      }
      if alpha_seen {
        raise InvalidXml(msg="drawing alpha target is duplicated")
      }
      alpha_seen = true
    } else if namespace_uri == main_namespace &&
      local_name == "ln" &&
      current_reader_object == "sp" {
      if depth != 5 ||
        scanner.parent_local_name() != Some("spPr") ||
        scanner.parent_namespace_uri() != Some(drawing_namespace) {
        raise InvalidXml(msg="drawing line target is misplaced")
      }
      if line_seen {
        raise InvalidXml(msg="drawing line target is duplicated")
      }
      line_seen = true
    } else if namespace_uri == main_namespace &&
      local_name == "t" &&
      current_reader_object == "sp" {
      match text_body_depth {
        Some(body_depth) if depth > body_depth => ()
        _ => raise InvalidXml(msg="drawing text target is misplaced")
      }
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
      ignore(
        drawing_reader_relationship_attribute(
          scanner, relationship_namespace, other_relationship_namespace, "id", true,
        ),
      )
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
fn charge_xlsx_drawing_xml_pass(
  budget : ReadBudget?,
  xml : StringView,
) -> Unit raise XlsxError {
  match budget {
    Some(value) => {
      value.checkpoint()
      value.charge_work(xml.length())
    }
    None => ()
  }
}

///|
fn charge_xlsx_drawing_xml_materialization(
  budget : ReadBudget?,
  xml : StringView,
) -> Unit raise XlsxError {
  match budget {
    Some(value) => {
      value.checkpoint()
      value.charge_work(xml.length())
    }
    None => ()
  }
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
  budget? : ReadBudget,
  cancelled? : () -> Bool = () => false,
) -> String raise XlsxError {
  charge_xlsx_drawing_xml_pass(budget, source)
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
  charge_xlsx_drawing_xml_pass(budget, source)
  let without_extension_lists = @ooxml.remove_xml_expanded_name_subtrees(
    source,
    xlsx_drawing_extension_list_namespaces,
    "extLst",
    cancelled~,
  ) catch {
    InvalidXml(msg~) => raise InvalidXml(msg~)
    ReadCancelled => raise ReadCancelled
  }
  match without_extension_lists {
    Some(value) => charge_xlsx_drawing_xml_materialization(budget, value)
    None => ()
  }
  let projected = match without_extension_lists {
    Some(extension_free) => {
      charge_xlsx_drawing_xml_pass(budget, extension_free)
      @ooxml.project_xml_markup_compatibility(
        extension_free,
        xlsx_drawing_mce_understood_namespaces,
        max_output_chars~,
        cancelled~,
        extension_elements=xlsx_drawing_mce_extension_elements,
      ) catch {
        InvalidXml(msg~) => raise InvalidXml(msg~)
        ReadCancelled => raise ReadCancelled
      }
    }
    None => {
      charge_xlsx_drawing_xml_pass(budget, source)
      @ooxml.project_xml_markup_compatibility(
        source,
        xlsx_drawing_mce_understood_namespaces,
        max_output_chars~,
        cancelled~,
        extension_elements=xlsx_drawing_mce_extension_elements,
      ) catch {
        InvalidXml(msg~) => raise InvalidXml(msg~)
        ReadCancelled => raise ReadCancelled
      }
    }
  }
  charge_xlsx_drawing_xml_materialization(budget, projected)
  // Foreign wrappers are removed with their descendants. Merely renaming a
  // wrapper would leave nested core-looking tags visible to lexical readers.
  charge_xlsx_drawing_xml_pass(budget, projected)
  let core_projected = @ooxml.remove_xml_foreign_namespace_subtrees(
    projected,
    xlsx_drawing_core_element_namespaces,
    cancelled~,
  ) catch {
    InvalidXml(msg~) => raise InvalidXml(msg~)
    ReadCancelled => raise ReadCancelled
  }
  match core_projected {
    Some(value) => charge_xlsx_drawing_xml_materialization(budget, value)
    None => ()
  }
  let reader_source = match core_projected {
    Some(value) => value
    None => projected
  }
  charge_xlsx_drawing_xml_pass(budget, reader_source)
  validate_xlsx_drawing_reader_structure(reader_source, cancelled~)
  charge_xlsx_drawing_xml_pass(budget, reader_source)
  let canonical = @ooxml.canonicalize_xml_expanded_names(
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
  charge_xlsx_drawing_xml_materialization(budget, canonical)
  canonical
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
