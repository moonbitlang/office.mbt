///|
test "write workbook xml wb: covers active-tab fallback and defined-name guards" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  ignore(workbook.add_sheet("Sheet2"))
  workbook.set_sheet_visible("Sheet1", false, very_hidden=true)
  workbook.active_sheet_index = -1

  workbook.defined_names.push({
    name: "",
    refers_to: "Sheet1!$A$1",
    scope: "Workbook",
    comment: "",
  })
  workbook.defined_names.push({
    name: "SkipRef",
    refers_to: "",
    scope: "Workbook",
    comment: "",
  })
  workbook.defined_names.push({
    name: "ScopedMissing",
    refers_to: "Sheet1!$A$1",
    scope: "Ghost",
    comment: "note",
  })

  let xml = write_workbook_xml(workbook, 100, [], [], [])
  inspect(xml.contains("<workbookView activeTab=\"0\"/>"), content="true")
  inspect(xml.contains("state=\"veryHidden\""), content="true")
  inspect(xml.contains("name=\"SkipRef\""), content="false")
  inspect(
    xml.contains("<definedName name=\"ScopedMissing\" comment=\"note\">"),
    content="true",
  )
  inspect(xml.contains("localSheetId="), content="false")
}

///|
test "write workbook xml wb: write_workbook_pr_xml handles sparse options" {
  let date_xml = match
    write_workbook_pr_xml(WorkbookPropsOptions::with_values(date_1904=true)) {
    Some(value) => value
    None => fail("expected workbookPr xml for date_1904")
  }
  inspect(date_xml.contains("date1904=\"1\""), content="true")
  inspect(date_xml.contains("filterPrivacy="), content="false")
  inspect(date_xml.contains("codeName="), content="false")

  let filter_xml = match
    write_workbook_pr_xml(
      WorkbookPropsOptions::with_values(filter_privacy=true),
    ) {
    Some(value) => value
    None => fail("expected workbookPr xml for filter_privacy")
  }
  inspect(filter_xml.contains("date1904="), content="false")
  inspect(filter_xml.contains("filterPrivacy=\"1\""), content="true")
  inspect(filter_xml.contains("codeName="), content="false")
}
