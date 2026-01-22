///|
test "get base color priority" {
  let workbook = Workbook::new()
  inspect(workbook.get_base_color("AABBCC", 0), content="AABBCC")
  inspect(workbook.get_base_color("FFAABBCC", 0), content="AABBCC")
  inspect(workbook.get_base_color("", 2), content="FF0000")
  inspect(workbook.get_base_color("", 0, theme_color=4), content="4F81BD")
}
