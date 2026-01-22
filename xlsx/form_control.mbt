///|
pub struct FormControl {
  cell : String
  control_type : String
  text : String
} derive(Eq, Show)

///|
pub fn FormControl::new(
  cell : String,
  control_type : String,
  text? : String = "",
) -> FormControl raise XlsxError {
  if cell == "" {
    raise XlsxError::InvalidSheetOperation(msg="form control cell empty")
  }
  if control_type == "" {
    raise XlsxError::InvalidSheetOperation(msg="form control type empty")
  }
  ignore(cell_ref_to_rc(cell))
  { cell, control_type, text }
}

///|
fn write_form_controls_vml(
  sheet_id : Int,
  controls : ArrayView[FormControl],
) -> String raise XlsxError {
  let sb = StringBuilder::new()
  sb.write_view("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n")
  sb.write_view(
    "<xml xmlns:v=\"urn:schemas-microsoft-com:vml\" xmlns:o=\"urn:schemas-microsoft-com:office:office\" xmlns:x=\"urn:schemas-microsoft-com:office:excel\">\n",
  )
  sb.write_view("  <o:shapelayout v:ext=\"edit\">\n")
  sb.write_view("    <o:idmap v:ext=\"edit\" data=\"\{sheet_id}\"/>\n")
  sb.write_view("  </o:shapelayout>\n")
  sb.write_view(
    "  <v:shapetype id=\"_x0000_t202\" coordsize=\"21600,21600\" o:spt=\"202\" path=\"m0,0l0,21600,21600,21600,21600,0xe\">\n",
  )
  sb.write_view("    <v:stroke joinstyle=\"miter\"/>\n")
  sb.write_view("    <v:path o:connecttype=\"rect\"/>\n")
  sb.write_view("  </v:shapetype>\n")
  let mut shape_id = 2048
  for control in controls {
    let (row, col) = cell_ref_to_rc(control.cell)
    let row0 = row - 1
    let col0 = col - 1
    let anchor = "\{col0}, 15, \{row0}, 2, \{col0 + 2}, 15, \{row0 + 3}, 16"
    sb.write_view(
      "  <v:shape id=\"_x0000_s\{shape_id}\" type=\"#_x0000_t202\" style=\"position:absolute;73.5pt;width:108pt;height:36pt;z-index:2\" o:insetmode=\"auto\">\n",
    )
    if control.text != "" {
      sb.write_view("    <v:textbox style=\"mso-direction-alt:auto\">\n")
      sb.write_view("      <div style=\"text-align:left\">")
      sb.write_view(escape_xml_text(control.text))
      sb.write_view("</div>\n")
      sb.write_view("    </v:textbox>\n")
    }
    sb.write_view("    <x:ClientData ObjectType=\"")
    sb.write_view(escape_xml_attr(control.control_type))
    sb.write_view("\">\n")
    sb.write_view("      <x:Anchor>\{anchor}</x:Anchor>\n")
    if control.text != "" {
      sb.write_view("      <x:Text>")
      sb.write_view(escape_xml_text(control.text))
      sb.write_view("</x:Text>\n")
    }
    sb.write_view("      <x:Row>\{row0}</x:Row>\n")
    sb.write_view("      <x:Column>\{col0}</x:Column>\n")
    sb.write_view("    </x:ClientData>\n")
    sb.write_view("  </v:shape>\n")
    shape_id = shape_id + 1
  }
  sb.write_view("</xml>")
  sb.to_string()
}
