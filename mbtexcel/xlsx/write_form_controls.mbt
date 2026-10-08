///|
fn write_form_control_properties(
  control : FormControl,
  budget? : WritePartBudget,
) -> String raise XlsxError {
  let (_, vml_type) = normalize_form_control_type(control.control_type)
  let object_type = if vml_type == "Checkbox" { "CheckBox" } else { vml_type }
  let sb = LimitedXmlBuilder::new(budget)
  sb.write_view("<?xml version=\"1.0\" encoding=\"UTF-8\"?>")
  sb.write_view(
    "<formControlPr xmlns=\"http://schemas.microsoft.com/office/spreadsheetml/2009/9/main\" objectType=\"\{object_type}\"",
  )
  match control.cell_link {
    Some(link) => {
      let attribute = match object_type {
        "GBox" => "fmlaGroup"
        "Label" => "fmlaTxbx"
        _ => "fmlaLink"
      }
      sb.write_view(" \{attribute}=\"")
      sb.write_xml_attr(link)
      sb.write_view("\"")
    }
    None => ()
  }
  if object_type == "CheckBox" || object_type == "Radio" {
    match control.checked {
      Some(value) => {
        let checked = if value { "Checked" } else { "Unchecked" }
        sb.write_view(" checked=\"\{checked}\"")
      }
      None => ()
    }
  }
  if object_type == "Scroll" || object_type == "Spin" {
    for
      (name, value) in [
        ("val", control.current_val),
        ("min", control.min_val),
        ("max", control.max_val),
        ("inc", control.inc_change),
        ("page", control.page_change),
      ] {
      match value {
        Some(value) => sb.write_view(" \{name}=\"\{value}\"")
        None => ()
      }
    }
  }
  if object_type == "Scroll" {
    match control.horizontally {
      Some(value) => sb.write_view(" horiz=\"\{if value { 1 } else { 0 }}\"")
      None => ()
    }
  }
  match form_control_vml_preset(control.control_type) {
    Some(preset) => {
      if preset.no_three_d {
        sb.write_view(" noThreeD=\"1\"")
      }
      if preset.first_button {
        sb.write_view(" firstButton=\"1\"")
      }
    }
    None => ()
  }
  sb.write_view("/>")
  sb.to_string()
}

///|
fn write_worksheet_controls(
  sb : LimitedXmlBuilder,
  sheet : Worksheet,
  shape_id_start : Int,
  rel_id_start : Int,
) -> Unit raise XlsxError {
  // Office 2010 controls keep a VML fallback for older consumers.
  sb.write_view(
    "<mc:AlternateContent xmlns:mc=\"http://schemas.openxmlformats.org/markup-compatibility/2006\" xmlns:x14=\"http://schemas.microsoft.com/office/spreadsheetml/2009/9/main\"><mc:Choice Requires=\"x14\"><controls>",
  )
  for index, control in sheet.form_controls() {
    let shape_id = shape_id_start + index
    let rel_id = rel_id_start + index
    let (row, col) = cell_ref_to_rc(control.cell)
    let (end_col, end_x, end_row, end_y) = form_control_end_anchor(
      sheet, control,
    )
    sb.write_view(
      "<control shapeId=\"\{shape_id}\" r:id=\"rId\{rel_id}\" name=\"Control \{shape_id}\"><controlPr defaultSize=\"0\" autoFill=\"0\" autoLine=\"0\" autoPict=\"0\"",
    )
    match control.macro_name {
      Some(value) => {
        sb.write_view(" macro=\"")
        sb.write_xml_attr(value)
        sb.write_view("\"")
      }
      None => ()
    }
    match control.format.print_object {
      Some(value) => sb.write_view(" print=\"\{if value { 1 } else { 0 }}\"")
      None => ()
    }
    match control.format.locked {
      Some(value) => sb.write_view(" locked=\"\{if value { 1 } else { 0 }}\"")
      None => ()
    }
    let move_with_cells = !(control.format.positioning is Some(Absolute))
    let size_with_cells = control.format.positioning is Some(TwoCell) ||
      control.format.positioning is None
    sb.write_view(
      "><anchor moveWithCells=\"\{if move_with_cells { 1 } else { 0 }}\" sizeWithCells=\"\{if size_with_cells { 1 } else { 0 }}\" xmlns:xdr=\"http://schemas.openxmlformats.org/drawingml/2006/spreadsheetDrawing\">",
    )
    sb.write_view(
      "<from><xdr:col>\{col - 1}</xdr:col><xdr:colOff>0</xdr:colOff><xdr:row>\{row - 1}</xdr:row><xdr:rowOff>0</xdr:rowOff></from>",
    )
    sb.write_view(
      "<to><xdr:col>\{end_col}</xdr:col><xdr:colOff>\{end_x.to_int64() * 9525L}</xdr:colOff><xdr:row>\{end_row}</xdr:row><xdr:rowOff>\{end_y.to_int64() * 9525L}</xdr:rowOff></to>",
    )
    sb.write_view("</anchor></controlPr></control>")
  }
  sb.write_view("</controls></mc:Choice><mc:Fallback/></mc:AlternateContent>")
}
