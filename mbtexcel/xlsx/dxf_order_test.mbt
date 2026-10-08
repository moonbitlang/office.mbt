///|
test "differential formats follow CT_Dxf child order" {
  let workbook = @xlsx.Workbook::new()
  workbook.add_sheet("Sheet1") |> ignore
  let style = @xlsx.Style::number_format("0.0000")
    .with_font(@xlsx.Font::with_values(bold=true))
    .with_fill(@xlsx.Fill::pattern(pattern=1, color="FFFF00"))
    .with_alignment(@xlsx.Alignment::with_values(vertical="center"))
    .with_border([@xlsx.Border::with_values("left", style=1)])
  workbook.new_conditional_style(style) |> ignore
  let archive = @zip.read(@xlsx.write(workbook))
  let xml = @encoding/utf8.decode(archive.get("xl/styles.xml").unwrap())
  let start = xml.find("<dxf>").unwrap()
  let end = xml.find("</dxf>").unwrap()
  let dxf = xml[start:end]
  let mut previous = -1
  let mut ordered = true
  // ECMA-376 CT_Dxf: font, numFmt, fill, alignment, border, protection.
  for tag in ["<font>", "<numFmt ", "<fill>", "<alignment ", "<border>"] {
    let position = dxf.find(tag).unwrap()
    if position <= previous {
      ordered = false
    }
    previous = position
  }
  debug_inspect(ordered, content="true")
}
