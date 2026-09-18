///|
test "chart parsed on read" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let opts = @xlsx.ChartOptions::new(Col)
  opts.series.push(
    @xlsx.ChartSeries::new(
      "Sheet1!$A$2:$A$4",
      "Sheet1!$B$2:$B$4",
      name="Sheet1!$B$1",
    ),
  )
  opts.title = "Sales"
  workbook.add_chart_with_options("Sheet1", "C3", opts)
  let parsed = @xlsx.read(@xlsx.write(workbook))
  let sheet = match parsed.sheet("Sheet1") {
    Some(value) => value
    None => fail("missing sheet")
  }
  inspect(sheet.charts().length(), content="1")
  inspect(sheet.charts()[0].xml.contains("<c:barChart>"), content="true")
}
