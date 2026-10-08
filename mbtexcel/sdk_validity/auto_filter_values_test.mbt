///|
#cfg(target="native")
async test "multi-value auto filters are Microsoft OpenXML schema-valid" {
  let wb = @xlsx.Workbook::new()
  ignore(wb.add_sheet("Expressions"))
  wb.set_auto_filter("Expressions", "B1:D50", [
    { column: "B", expression: "x == EMEA or x == APAC or x == AMER", },
    { column: "D", expression: "x > 1 and x < 10", },
  ])
  ignore(wb.add_sheet("Values"))
  wb.set_auto_filter_values("Values", "B1:D50", [
    {
      column: "B",
      values: ["North America", "or", "say \"hi\"", "blanks", "*", "A&B"],
    },
    { column: "D", values: ["1", "2", "3", "4"], },
  ])
  let dir = @async/fs.tmpdir(prefix="mbtexcel-filter-values-")
  validate_via_sdk(dir, "filters", @xlsx.write(wb))
}
