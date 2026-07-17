///|
pub struct Slicer {
  name : String
  cache : String
  source_name : String
  cell : String
  table_sheet : String
  table_name : String
  caption : String
  macro_name : String
  width : Int
  height : Int
  display_header : Bool?
  item_desc : Bool
  format : GraphicOptions
  priv drawing_offset_x_emu : Int?
  priv drawing_offset_y_emu : Int?
  priv drawing_width_emu : Int?
  priv drawing_height_emu : Int?
  priv drawing_order : Int?
} derive(Debug)

///|
pub fn Slicer::new(name : String) -> Slicer raise XlsxError {
  if name == "" {
    raise InvalidSheetOperation(msg="slicer name empty")
  }
  fn sanitize_cache_stub(value : StringView) -> String {
    let name = value.to_owned()
    let sb = StringBuilder::new()
    for i, ch in name {
      let code = ch.to_int()
      let is_letter = (code >= 65 && code <= 90) || (code >= 97 && code <= 122)
      let is_digit = code >= 48 && code <= 57
      if is_letter {
        sb.write_view(ch.to_string())
      } else if i > 0 && (is_digit || ch == '.') {
        sb.write_view(ch.to_string())
      } else {
        sb.write_view("_")
      }
    }
    sb.to_string()
  }

  let cache = "Slicer_" + sanitize_cache_stub(name)
  {
    name,
    cache,
    source_name: name,
    cell: "",
    table_sheet: "",
    table_name: "",
    caption: "",
    macro_name: "",
    width: 200,
    height: 200,
    display_header: None,
    item_desc: false,
    format: GraphicOptions::new(),
    drawing_offset_x_emu: None,
    drawing_offset_y_emu: None,
    drawing_width_emu: None,
    drawing_height_emu: None,
    drawing_order: None,
  }
}

///|
let slicer_ns_main = "http://schemas.microsoft.com/office/spreadsheetml/2009/9/main"

///|
let slicer_ns_x = "http://schemas.openxmlformats.org/spreadsheetml/2006/main"

///|
let slicer_ns_x15 = "http://schemas.microsoft.com/office/spreadsheetml/2010/11/main"

///|
let slicer_ns_x14 = "http://schemas.microsoft.com/office/spreadsheetml/2009/9/main"

///|
let slicer_ns_xr10 = "http://schemas.microsoft.com/office/spreadsheetml/2016/revision10"

///|
let slicer_ext_uri_pivot_cache_definition = "{725AE2AE-9491-48be-B2B4-4EB974FC3084}"

///|
fn write_slicers_part_xml(
  slicers : ArrayView[Slicer],
  budget? : WritePartBudget,
) -> String raise XlsxError {
  let sb = LimitedXmlBuilder::new(budget)
  sb.write_view("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n")
  sb.write_view(
    "<slicers xmlns=\"\{slicer_ns_main}\" xmlns:mc=\"http://schemas.openxmlformats.org/markup-compatibility/2006\" xmlns:x=\"\{slicer_ns_x}\" xmlns:xr10=\"\{slicer_ns_xr10}\">\n",
  )
  for slicer in slicers {
    sb.write_view("  <slicer name=\"")
    sb.write_xml_attr(slicer.name)
    sb.write_view("\" cache=\"")
    sb.write_xml_attr(slicer.cache)
    sb.write_view("\"")
    if slicer.caption != "" {
      sb.write_view(" caption=\"")
      sb.write_xml_attr(slicer.caption)
      sb.write_view("\"")
    }
    match slicer.display_header {
      Some(value) => sb.write_view(" showCaption=\"\{bool_attr(value)}\"")
      None => ()
    }
    sb.write_view(" rowHeight=\"251883\"/>\n")
  }
  sb.write_view("</slicers>")
  sb.to_string()
}

///|
fn slicer_sort_order_attr(item_desc : Bool) -> String {
  if item_desc {
    " sortOrder=\"descending\""
  } else {
    ""
  }
}

///|
fn write_slicer_cache_xml_pivot(
  cache_name : StringView,
  source_name : StringView,
  table_sheet_id : Int,
  pivot_table_name : StringView,
  pivot_cache_id : Int,
  item_desc : Bool,
  budget? : WritePartBudget,
) -> String raise XlsxError {
  let sb = LimitedXmlBuilder::new(budget)
  sb.write_view("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n")
  sb.write_view(
    "<slicerCacheDefinition xmlns=\"\{slicer_ns_main}\" xmlns:mc=\"http://schemas.openxmlformats.org/markup-compatibility/2006\" xmlns:x=\"\{slicer_ns_x}\" xmlns:x15=\"\{slicer_ns_x15}\" xmlns:xr10=\"\{slicer_ns_xr10}\" name=\"",
  )
  sb.write_xml_attr(cache_name)
  sb.write_view("\" sourceName=\"")
  sb.write_xml_attr(source_name)
  sb.write_view("\">\n")
  sb.write_view("  <pivotTables>\n")
  sb.write_view("    <pivotTable tabId=\"\{table_sheet_id}\" name=\"")
  sb.write_xml_attr(pivot_table_name)
  sb.write_view("\"/>\n")
  sb.write_view("  </pivotTables>\n")
  sb.write_view("  <data>\n")
  sb.write_view("    <tabular pivotCacheId=\"\{pivot_cache_id}\"")
  sb.write_view(slicer_sort_order_attr(item_desc))
  sb.write_view(" showMissing=\"0\">\n")
  sb.write_view("      <items count=\"1\"><i x=\"0\" s=\"1\"/></items>\n")
  sb.write_view("    </tabular>\n")
  sb.write_view("  </data>\n")
  sb.write_view("</slicerCacheDefinition>")
  sb.to_string()
}

///|
fn write_slicer_cache_xml_table(
  cache_name : StringView,
  source_name : StringView,
  table_id : Int,
  column : Int,
  item_desc : Bool,
  budget? : WritePartBudget,
) -> String raise XlsxError {
  let sb = LimitedXmlBuilder::new(budget)
  sb.write_view("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n")
  sb.write_view(
    "<slicerCacheDefinition xmlns=\"\{slicer_ns_main}\" xmlns:mc=\"http://schemas.openxmlformats.org/markup-compatibility/2006\" xmlns:x=\"\{slicer_ns_x}\" xmlns:x15=\"\{slicer_ns_x15}\" xmlns:xr10=\"\{slicer_ns_xr10}\" name=\"",
  )
  sb.write_xml_attr(cache_name)
  sb.write_view("\" sourceName=\"")
  sb.write_xml_attr(source_name)
  sb.write_view("\">\n")
  sb.write_view("  <extLst>\n")
  sb.write_view("    <ext uri=\"{2F2917AC-EB37-4324-AD4E-5DD8C200BD13}\">\n")
  sb.write_view(
    "      <x15:tableSlicerCache tableId=\"\{table_id}\" column=\"\{column}\"",
  )
  sb.write_view(slicer_sort_order_attr(item_desc))
  sb.write_view("/>\n")
  sb.write_view("    </ext>\n")
  sb.write_view("  </extLst>\n")
  sb.write_view("</slicerCacheDefinition>")
  sb.to_string()
}

///|
fn parse_pivot_cache_slicer_id(cache_xml : StringView) -> Int? raise XlsxError {
  match tag_attributes_in(cache_xml, "x14:pivotCacheDefinition") {
    Some(tag) =>
      match attr_value(tag, "pivotCacheId") {
        Some(raw) =>
          try @string.parse_int(raw, base=10) catch {
            _ => None
          } noraise {
            value => Some(value)
          }
        None => None
      }
    None => None
  }
}

///|
fn ensure_pivot_cache_slicer_id(
  cache_xml : String,
  pivot_cache_id : Int,
  budget? : WritePartBudget,
) -> String raise XlsxError {
  if parse_pivot_cache_slicer_id(cache_xml) is Some(_) {
    return cache_xml
  }
  let namespace_at = if !cache_xml.contains("xmlns:x14=\"\{slicer_ns_x14}\"") {
    let needle = "<pivotCacheDefinition"
    match cache_xml.find(needle) {
      Some(start) => {
        let rest = cache_xml[start:]
        match rest.find(">") {
          Some(end_rel) => Some(start + end_rel)
          None => None
        }
      }
      None => None
    }
  } else {
    None
  }
  let extension_insertion : (Int, String)? = if cache_xml.contains(
      "uri=\"\{slicer_ext_uri_pivot_cache_definition}\"",
    ) {
    None
  } else {
    let ext_entry = "    <ext uri=\"\{slicer_ext_uri_pivot_cache_definition}\">\n      <x14:pivotCacheDefinition pivotCacheId=\"\{pivot_cache_id}\"/>\n    </ext>\n"
    match cache_xml.find("</extLst>") {
      Some(pos) => Some((pos, ext_entry))
      None =>
        match cache_xml.find("</pivotCacheDefinition>") {
          Some(pos) => Some((pos, "  <extLst>\n\{ext_entry}  </extLst>\n"))
          None => None
        }
    }
  }
  if namespace_at is None && extension_insertion is None {
    return cache_xml
  }
  let sb = LimitedXmlBuilder::new(budget)
  let mut cursor = 0
  match namespace_at {
    Some(pos) => {
      sb.write_view(cache_xml[cursor:pos])
      sb.write_view(" xmlns:x14=\"\{slicer_ns_x14}\"")
      cursor = pos
    }
    None => ()
  }
  match extension_insertion {
    Some((pos, fragment)) => {
      sb.write_view(cache_xml[cursor:pos])
      sb.write_view(fragment)
      cursor = pos
    }
    None => ()
  }
  sb.write_view(cache_xml[cursor:])
  sb.to_string()
}
