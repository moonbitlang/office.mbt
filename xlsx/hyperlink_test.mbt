///|
test "hyperlink roundtrip" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.set_cell_hyperlink(
    "Sheet1",
    "A1",
    "https://example.com",
    HyperlinkType::External,
    display="Example",
    tooltip="Tip",
  )
  workbook.set_cell_hyperlink(
    "Sheet1",
    "B2",
    "Sheet1!C3",
    HyperlinkType::Location,
  )
  let parsed = read(write(workbook))
  inspect(
    parsed.get_cell_hyperlink("Sheet1", "A1"),
    content=(
      #|Some({reference: "A1", target: "https://example.com", link_type: External, display: Some("Example"), tooltip: Some("Tip")})
    ),
  )
  inspect(
    parsed.get_cell_hyperlink("Sheet1", "B2"),
    content=(
      #|Some({reference: "B2", target: "Sheet1!C3", link_type: Location, display: None, tooltip: None})
    ),
  )
}

///|
test "hyperlink updates on insert" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.set_cell_hyperlink(
    "Sheet1",
    "B2",
    "https://example.com",
    HyperlinkType::External,
  )
  workbook.insert_rows("Sheet1", 1, 1)
  inspect(workbook.get_cell_hyperlink("Sheet1", "B2"), content="None")
  inspect(
    workbook.get_cell_hyperlink("Sheet1", "B3"),
    content=(
      #|Some({reference: "B3", target: "https://example.com", link_type: External, display: None, tooltip: None})
    ),
  )
  workbook.insert_cols("Sheet1", 1, 1)
  inspect(workbook.get_cell_hyperlink("Sheet1", "B3"), content="None")
  inspect(
    workbook.get_cell_hyperlink("Sheet1", "C3"),
    content=(
      #|Some({reference: "C3", target: "https://example.com", link_type: External, display: None, tooltip: None})
    ),
  )
}
