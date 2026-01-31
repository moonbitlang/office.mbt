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

///|
test "auto filter: quoted tokens, wildcards, blanks/nonblanks" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))

  // Tokenize quotes + escaped quotes inside quotes.
  workbook.set_auto_filter("Sheet1", "A1:A2", [
    { column: "A", expression: "x == \"a\"\"b\"" },
  ])
  inspect(
    workbook.get_auto_filter("Sheet1"),
    content=(
      #|Some({range_ref: "A1:A2", columns: [{col: 1, filters: Some(["\"a\"\"b\""]), custom_filters: None}]})
    ),
  )

  // Wildcards make this a custom filter (op 22).
  workbook.set_auto_filter("Sheet1", "A1:A2", [
    { column: "A", expression: "x == A*" },
  ])
  let f1 = match workbook.get_auto_filter("Sheet1") {
    Some(v) => v
    None => fail("missing auto filter")
  }
  inspect(f1.columns[0].custom_filters is Some(_), content="true")

  // blanks/nonblanks normalization.
  workbook.set_auto_filter("Sheet1", "A1:A2", [
    { column: "A", expression: "x != blanks" },
  ])
  let f2 = match workbook.get_auto_filter("Sheet1") {
    Some(v) => v
    None => fail("missing auto filter")
  }
  inspect(f2.columns[0].custom_filters is Some(_), content="true")
  workbook.set_auto_filter("Sheet1", "A1:A2", [
    { column: "A", expression: "x == nonblanks" },
  ])
  let f3 = match workbook.get_auto_filter("Sheet1") {
    Some(v) => v
    None => fail("missing auto filter")
  }
  inspect(f3.columns[0].custom_filters is Some(_), content="true")
}

///|
test "auto filter: invalid token count and blanks operator" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let bad_tokens : Result[Unit, Error] = try? workbook.set_auto_filter(
    "Sheet1",
    "A1:A2",
    [{ column: "A", expression: "x ==" }],
  )
  inspect(
    bad_tokens,
    content=(
      #|Err(InvalidAutoFilter(msg="auto filter expression invalid"))
    ),
  )
  let bad_tokens2 : Result[Unit, Error] = try? workbook.set_auto_filter(
    "Sheet1",
    "A1:A2",
    [{ column: "A", expression: "x == 1 2" }],
  )
  inspect(
    bad_tokens2,
    content=(
      #|Err(InvalidAutoFilter(msg="auto filter expression invalid"))
    ),
  )
  let bad_blanks_op : Result[Unit, Error] = try? workbook.set_auto_filter(
    "Sheet1",
    "A1:A2",
    [{ column: "A", expression: "x > blanks" }],
  )
  inspect(
    bad_blanks_op,
    content=(
      #|Err(InvalidAutoFilter(msg="auto filter operator invalid"))
    ),
  )
}

///|
test "auto filter: custom operators, and-expression, and column validation" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))

  // < and <= map to custom filter operators.
  workbook.set_auto_filter("Sheet1", "A1:A2", [
    { column: "A", expression: "x < 3" },
  ])
  inspect(
    workbook.get_auto_filter("Sheet1"),
    content=(
      #|Some({range_ref: "A1:A2", columns: [{col: 1, filters: None, custom_filters: Some({and_filter: false, filters: [{operator: "lessThan", value: "3"}]})}]})
    ),
  )
  workbook.set_auto_filter("Sheet1", "A1:A2", [
    { column: "A", expression: "x <= 3" },
  ])
  inspect(
    workbook.get_auto_filter("Sheet1"),
    content=(
      #|Some({range_ref: "A1:A2", columns: [{col: 1, filters: None, custom_filters: Some({and_filter: false, filters: [{operator: "lessThanOrEqual", value: "3"}]})}]})
    ),
  )

  // blanks/nonblanks (including the != nonblanks normalization path).
  workbook.set_auto_filter("Sheet1", "A1:A2", [
    { column: "A", expression: "x != nonblanks" },
  ])
  inspect(
    workbook.get_auto_filter("Sheet1"),
    content=(
      #|Some({range_ref: "A1:A2", columns: [{col: 1, filters: Some(["blanks"]), custom_filters: None}]})
    ),
  )

  // Two custom filters with an `and` expression.
  workbook.set_auto_filter("Sheet1", "A1:A2", [
    { column: "A", expression: "x > 1 and x < 3" },
  ])
  let f1 = match workbook.get_auto_filter("Sheet1") {
    Some(v) => v
    None => fail("missing auto filter")
  }
  let cf = match f1.columns[0].custom_filters {
    Some(v) => v
    None => fail("missing custom filters")
  }
  inspect(cf.and_filter, content="true")
  inspect(cf.filters.length(), content="2")

  // Empty options are ignored.
  workbook.set_auto_filter("Sheet1", "A1:A2", [
    { column: "", expression: "x == 1" },
    { column: "A", expression: "" },
    { column: "A", expression: "x == 1" },
  ])
  inspect(
    workbook.get_auto_filter("Sheet1"),
    content=(
      #|Some({range_ref: "A1:A2", columns: [{col: 1, filters: Some(["1"]), custom_filters: None}]})
    ),
  )

  // Column invalid.
  let bad_col : Result[Unit, Error] = try? workbook.set_auto_filter(
    "Sheet1",
    "A1:A2",
    [{ column: "1", expression: "x == 1" }],
  )
  inspect(
    bad_col,
    content=(
      #|Err(InvalidAutoFilter(msg="auto filter column invalid"))
    ),
  )

  // Column out of range.
  let out_of_range : Result[Unit, Error] = try? workbook.set_auto_filter(
    "Sheet1",
    "A1:A2",
    [{ column: "B", expression: "x == 1" }],
  )
  inspect(
    out_of_range,
    content=(
      #|Err(InvalidAutoFilter(msg="auto filter column out of range"))
    ),
  )

  // Duplicate column is replaced.
  workbook.set_auto_filter("Sheet1", "A1:A2", [
    { column: "A", expression: "x == 1" },
    { column: "A", expression: "x == 2" },
  ])
  inspect(
    workbook.get_auto_filter("Sheet1"),
    content=(
      #|Some({range_ref: "A1:A2", columns: [{col: 1, filters: Some(["2"]), custom_filters: None}]})
    ),
  )
}

///|
test "auto filter clear" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.clear_auto_filter()
  inspect(sheet.auto_filter(), content="None")
}
