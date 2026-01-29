///|
test "conditional formats parsed on read" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let opt = ConditionalFormatOptions::new("cell")
  opt.set_criteria(">")
  opt.set_value("6")
  workbook.set_conditional_format("Sheet1", "A1:A2", [opt])
  let parsed = read(write(workbook))
  let formats = parsed.get_conditional_formats("Sheet1")
  let opts = match formats.get("A1:A2") {
    Some(value) => value
    None => fail("missing formats")
  }
  inspect(opts.length(), content="1")
  inspect(opts[0].format_type, content="cell")
  inspect(opts[0].criteria, content="greater than")
}
