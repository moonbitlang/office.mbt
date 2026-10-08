///|
test "form controls have worksheet references and control property parts" {
  let wb = @xlsx.Workbook::new()
  let sheet = wb.add_sheet("Widgets")
  let control = @xlsx.FormControl::new("A3", "checkBox", text="Rush order")
  control.set_cell_link("G2")
  sheet.add_form_control(control)
  let zip = @zip.read(@xlsx.write(wb))
  debug_inspect(
    zip.get("xl/ctrlProps/ctrlProp1.xml") is Some(_),
    content="true",
  )
  let xml = @encoding/utf8.decode(zip.get("xl/worksheets/sheet1.xml").unwrap())
  debug_inspect(xml.contains("<controls>"), content="true")
}

///|
test "all control kinds use distinct package parts across worksheets" {
  let wb = @xlsx.Workbook::new()
  let kinds = ["CheckBox", "Radio", "Spin", "Scroll", "Button", "GBox", "Label"]
  for name in ["First", "Second"] {
    let sheet = wb.add_sheet(name)
    for i, kind in kinds {
      let control = @xlsx.FormControl::new("A\{i * 5 + 1}", kind)
      if kind == "CheckBox" || kind == "Radio" {
        control.set_checked(true)
        control.set_cell_link("G2")
      }
      if kind == "Spin" || kind == "Scroll" {
        control.set_current_val(5)
        control.set_min_val(1)
        control.set_max_val(20)
        control.set_inc_change(2)
        control.set_page_change(3)
        control.set_horizontally(true)
      }
      sheet.add_form_control(control)
    }
  }
  let archive = @zip.read(@xlsx.write(wb))
  let mut matched = 0
  for sheet in 0..<2 {
    let rels = @encoding/utf8.decode(
      archive.get("xl/worksheets/_rels/sheet\{sheet + 1}.xml.rels").unwrap(),
    )
    let xml = @encoding/utf8.decode(
      archive.get("xl/worksheets/sheet\{sheet + 1}.xml").unwrap(),
    )
    let vml = @encoding/utf8.decode(
      archive.get("xl/drawings/vmlDrawing\{sheet + 1}.vml").unwrap(),
    )
    for i, kind in kinds {
      let id = sheet * 7 + i + 1
      let props = @encoding/utf8.decode(
        archive.get("xl/ctrlProps/ctrlProp\{id}.xml").unwrap(),
      )
      if props.contains("objectType=\"\{kind}\"") &&
        rels.contains(
          "Id=\"rId\{i + 2}\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/ctrlProp\" Target=\"../ctrlProps/ctrlProp\{id}.xml\"",
        ) &&
        xml.contains("shapeId=\"\{2048 + i}\" r:id=\"rId\{i + 2}\"") &&
        vml.contains("id=\"_x0000_s\{2048 + i}\"") {
        matched += 1
      }
    }
  }
  debug_inspect(matched, content="14")
  let checkbox = @encoding/utf8.decode(
    archive.get("xl/ctrlProps/ctrlProp1.xml").unwrap(),
  )
  debug_inspect(checkbox.contains("checked=\"Checked\""), content="true")
  debug_inspect(checkbox.contains("fmlaLink=\"G2\""), content="true")
  let scroll = @encoding/utf8.decode(
    archive.get("xl/ctrlProps/ctrlProp4.xml").unwrap(),
  )
  debug_inspect(
    scroll.contains(
      "val=\"5\" min=\"1\" max=\"20\" inc=\"2\" page=\"3\" horiz=\"1\"",
    ),
    content="true",
  )
  let content_types = @encoding/utf8.decode(
    archive.get("[Content_Types].xml").unwrap(),
  )
  debug_inspect(
    content_types.contains(
      "PartName=\"/xl/ctrlProps/ctrlProp14.xml\" ContentType=\"application/vnd.ms-excel.controlproperties+xml\"",
    ),
    content="true",
  )
}

///|
test "modern control references share collision-free VML IDs with retained notes" {
  let wb = @xlsx.Workbook::new()
  let sheet = wb.add_sheet("Widgets")
  sheet.add_comment(plain_comment("A1", "Author", "Note"))
  sheet.add_vml_drawing_xml(
    "<xml xmlns:v=\"urn:schemas-microsoft-com:vml\" xmlns:o=\"urn:schemas-microsoft-com:office:office\" xmlns:x=\"urn:schemas-microsoft-com:office:excel\">" +
    "<v:shapetype id=\"_x0000_t202\"/><v:shape id=\"_x0000_s2048\"><x:ClientData ObjectType=\"Note\"><x:Row>0</x:Row><x:Column>0</x:Column></x:ClientData></v:shape></xml>",
  )
  let control = @xlsx.FormControl::new("B2", "CheckBox")
  control.set_width(20)
  control.set_height(10)
  sheet.add_form_control(control)
  let zip = @zip.read(@xlsx.write(wb))
  let xml = @encoding/utf8.decode(zip.get("xl/worksheets/sheet1.xml").unwrap())
  let vml = @encoding/utf8.decode(
    zip.get("xl/drawings/vmlDrawing1.vml").unwrap(),
  )
  debug_inspect(xml.contains("shapeId=\"2049\" r:id=\"rId3\""), content="true")
  debug_inspect(vml.contains("id=\"_x0000_s2049\""), content="true")
  debug_inspect(vml.contains("<v:shapetype id=\"_x0000_t201\""), content="true")
  debug_inspect(
    vml.contains("<x:Anchor>1, 0, 1, 0, 1, 20, 1, 10</x:Anchor>"),
    content="true",
  )
  debug_inspect(
    xml.contains(
      "<to><xdr:col>1</xdr:col><xdr:colOff>190500</xdr:colOff><xdr:row>1</xdr:row><xdr:rowOff>95250</xdr:rowOff></to>",
    ),
    content="true",
  )
}

///|
test "form controls use the standard host-control VML shape definition" {
  let wb = @xlsx.Workbook::new()
  let sheet = wb.add_sheet("Widgets")
  sheet.add_form_control(@xlsx.FormControl::new("A1", "Button", text="Run"))
  let zip = @zip.read(@xlsx.write(wb))
  let vml = @encoding/utf8.decode(
    zip.get("xl/drawings/vmlDrawing1.vml").unwrap(),
  )
  // Excel for Mac must recognize the complete host-control definition.
  // Otherwise saving converts it into a custom master without its path,
  // and reopening renders the control as a curved arrow.
  debug_inspect(
    vml.contains(
      "<v:shapetype id=\"_x0000_t201\" coordsize=\"21600,21600\" o:spt=\"201\" path=\"m,l,21600r21600,l21600,xe\">\n" +
      "    <v:stroke joinstyle=\"miter\"/>\n" +
      "    <v:path shadowok=\"f\" o:extrusionok=\"f\" strokeok=\"f\" fillok=\"f\" o:connecttype=\"rect\"/>\n" +
      "    <o:lock v:ext=\"edit\" shapetype=\"t\"/>\n" +
      "  </v:shapetype>",
    ),
    content="true",
  )
}
