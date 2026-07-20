// Whitebox regressions for the subtype-gate attribute scanner: spellings
// the public workbook API cannot produce but foreign chart XML can.

///|
test "attribute values never read as attribute names" {
  // `val = 'col'` inside the note value is data, not an attribute
  let decoy = "<c:barDir note=\"plain val = 'col'\" val='bar'/>"
  let vals = chart_svg_tag_vals(decoy, "c:barDir")
  assert_true(vals is ["bar"])
  assert_false(chart_svg_supported_subtype(decoy, "barChart"))
}

///|
test "quoted greater-than does not end the element scan" {
  let xml = "<c:grouping note=\"left > right\" val='stacked'/>"
  assert_true(chart_svg_tag_vals(xml, "c:grouping") is ["stacked"])
  assert_false(chart_svg_supported_subtype(xml, "lineChart"))
}

///|
test "scanner accepts writer spellings and whitespace variants" {
  assert_true(
    chart_svg_tag_vals("<c:barDir val=\"col\"/>", "c:barDir") is ["col"],
  )
  assert_true(
    chart_svg_tag_vals("<c:barDir val = 'col' />", "c:barDir") is ["col"],
  )
  assert_true(chart_svg_tag_vals("<c:barDirExt val='bar'/>", "c:barDir") is [])
  assert_true(
    chart_svg_tag_vals(
      "<c:grouping val=\"clustered\"/><c:grouping val=\"stacked\"/>", "c:grouping",
    )
    is ["clustered", "stacked"],
  )
}

///|
test "scanner terminates on incomplete inputs" {
  for
    sample in [
      "<c:grouping", "<c:grouping ", "<c:grouping val=", "<c:grouping val='standard",
      "<c:grouping note=\"plain >", "<c:groupingExt val='stacked'/><c:grouping",
      "<c:grouping val=standard/>",
    ] {
    ignore(chart_svg_tag_vals(sample, "c:grouping"))
  }
}

///|
test "a decoy-spelled horizontal bar chart keeps the placeholder" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Data"))
  workbook.set_cell("Data", "A1", "one")
  workbook.set_cell_int("Data", "B1", 10)
  let xml =
    #|<c:chart><c:plotArea><c:barChart><c:barDir note="plain val = 'col'" val='bar'/><c:grouping val='clustered'/><c:ser><c:cat><c:strRef><c:f>Data!$A$1:$A$1</c:f></c:strRef></c:cat><c:val><c:numRef><c:f>Data!$B$1:$B$1</c:f></c:numRef></c:val></c:ser></c:barChart></c:plotArea></c:chart>
  assert_true(chart_svg_figure(workbook, xml, anchor="D2") is None)
}
