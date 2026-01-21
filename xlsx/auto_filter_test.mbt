///|
test "auto filter set and roundtrip" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let options : Array[AutoFilterOption] = [
    { column: "B", expression: "x == 10" },
    { column: "C", expression: "x > 5" },
  ]
  workbook.set_auto_filter("Sheet1", "A1:C3", options)
  inspect(
    workbook.get_auto_filter("Sheet1"),
    content=(
      #|Some({range_ref: "A1:C3", columns: [{col: 2, filters: Some(["10"]), custom_filters: None}, {col: 3, filters: None, custom_filters: Some({and_filter: false, filters: [{operator: "greaterThan", value: "5"}]})}]})
    ),
  )
  let parsed = read(write(workbook))
  inspect(
    parsed.get_auto_filter("Sheet1"),
    content=(
      #|Some({range_ref: "A1:C3", columns: [{col: 2, filters: Some(["10"]), custom_filters: None}, {col: 3, filters: None, custom_filters: Some({and_filter: false, filters: [{operator: "greaterThan", value: "5"}]})}]})
    ),
  )
}

///|
test "auto filter or expression" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let options : Array[AutoFilterOption] = [
    { column: "A", expression: "x == 1 or x == 3" },
  ]
  workbook.set_auto_filter("Sheet1", "A1:B5", options)
  inspect(
    workbook.get_auto_filter("Sheet1"),
    content=(
      #|Some({range_ref: "A1:B5", columns: [{col: 1, filters: Some(["1", "3"]), custom_filters: None}]})
    ),
  )
}

///|
test "auto filter adjusts on insert" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let options : Array[AutoFilterOption] = [
    { column: "C", expression: "x >= 5" },
  ]
  workbook.set_auto_filter("Sheet1", "A1:C3", options)
  workbook.insert_cols("Sheet1", 2, 1)
  inspect(
    workbook.get_auto_filter("Sheet1"),
    content=(
      #|Some({range_ref: "A1:D3", columns: [{col: 4, filters: None, custom_filters: Some({and_filter: false, filters: [{operator: "greaterThanOrEqual", value: "5"}]})}]})
    ),
  )
}

///|
test "auto filter invalid expression" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let options : Array[AutoFilterOption] = [
    { column: "A", expression: "x >< 1" },
  ]
  let result : Result[Unit, Error] = try? workbook.set_auto_filter(
    "Sheet1", "A1:A2", options,
  )
  inspect(
    result,
    content=(
      #|Err(InvalidAutoFilter(msg="auto filter operator invalid"))
    ),
  )
}
