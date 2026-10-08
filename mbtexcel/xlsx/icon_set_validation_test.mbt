///|
test "base icon sets accept all seventeen schema values" {
  let workbook = @xlsx.Workbook::new()
  let sheet = workbook.add_sheet("S")
  let names = [
    "3Arrows", "3ArrowsGray", "3Flags", "3Signs", "3Symbols", "3Symbols2", "3TrafficLights1",
    "3TrafficLights2", "4Arrows", "4ArrowsGray", "4Rating", "4RedToBlack", "4TrafficLights",
    "5Arrows", "5ArrowsGray", "5Quarters", "5Rating",
  ]
  let mut matching = 0
  for i, name in names {
    let opt = @xlsx.ConditionalFormatOptions::new("icon_set")
    opt.set_icon_style(name)
    sheet.set_conditional_format("A1:A3", [opt])
    if sheet.conditional_formats()[i].contains("iconSet=\"\{name}\"") {
      matching += 1
    }
  }
  @debug.debug_inspect(matching, content="17")
}

///|
test "x14-only icon sets fail without adding partial rules" {
  let workbook = @xlsx.Workbook::new()
  let sheet = workbook.add_sheet("S")
  let valid = @xlsx.ConditionalFormatOptions::new("icon_set")
  valid.set_icon_style("3Arrows")
  sheet.set_conditional_format("A1:A3", [valid])
  let before = sheet.conditional_formats().to_owned()
  let rejected : Array[Bool] = []
  for name in ["3Stars", "3Triangles", "5Boxes"] {
    let opt = @xlsx.ConditionalFormatOptions::new("icon_set")
    opt.set_icon_style(name)
    let result : Result[Unit, Error] = Ok(
      sheet.set_conditional_format("B1:B3", [valid, opt]),
    ) catch {
      e => Err(e)
    }
    rejected.push(result is Err(@xlsx.XlsxError::InvalidConditionalFormat(_)))
  }
  @debug.debug_inspect(rejected, content="[true, true, true]")
  @debug.debug_inspect(
    sheet.conditional_formats().to_owned() == before,
    content="true",
  )
}
