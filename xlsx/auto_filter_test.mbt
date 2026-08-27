///|
test "auto filter set and roundtrip" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let options : Array[@xlsx.AutoFilterOption] = [
    { column: "B", expression: "x == 10", },
    { column: "C", expression: "x > 5", },
  ]
  workbook.set_auto_filter("Sheet1", "A1:C3", options)
  debug_inspect(
    workbook.get_auto_filter("Sheet1"),
    content=(
      #|Some(
      #|  {
      #|    range_ref: "A1:C3",
      #|    columns: [
      #|      { col: 2, filters: Some(["10"]), custom_filters: None },
      #|      {
      #|        col: 3,
      #|        filters: None,
      #|        custom_filters: Some(
      #|          {
      #|            and_filter: false,
      #|            filters: [{ operator: "greaterThan", value: "5" }],
      #|          },
      #|        ),
      #|      },
      #|    ],
      #|  },
      #|)
    ),
  )
  let parsed = @xlsx.read(@xlsx.write(workbook))
  debug_inspect(
    parsed.get_auto_filter("Sheet1"),
    content=(
      #|Some(
      #|  {
      #|    range_ref: "A1:C3",
      #|    columns: [
      #|      { col: 2, filters: Some(["10"]), custom_filters: None },
      #|      {
      #|        col: 3,
      #|        filters: None,
      #|        custom_filters: Some(
      #|          {
      #|            and_filter: false,
      #|            filters: [{ operator: "greaterThan", value: "5" }],
      #|          },
      #|        ),
      #|      },
      #|    ],
      #|  },
      #|)
    ),
  )
}

///|
test "auto filter or expression" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let options : Array[@xlsx.AutoFilterOption] = [
    { column: "A", expression: "x == 1 or x == 3", },
  ]
  workbook.set_auto_filter("Sheet1", "A1:B5", options)
  debug_inspect(
    workbook.get_auto_filter("Sheet1"),
    content=(
      #|Some(
      #|  {
      #|    range_ref: "A1:B5",
      #|    columns: [{ col: 1, filters: Some(["1", "3"]), custom_filters: None }],
      #|  },
      #|)
    ),
  )
}

///|
test "auto filter adjusts on insert" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let options : Array[@xlsx.AutoFilterOption] = [
    { column: "C", expression: "x >= 5", },
  ]
  workbook.set_auto_filter("Sheet1", "A1:C3", options)
  workbook.insert_cols("Sheet1", 2, 1)
  debug_inspect(
    workbook.get_auto_filter("Sheet1"),
    content=(
      #|Some(
      #|  {
      #|    range_ref: "A1:D3",
      #|    columns: [
      #|      {
      #|        col: 4,
      #|        filters: None,
      #|        custom_filters: Some(
      #|          {
      #|            and_filter: false,
      #|            filters: [{ operator: "greaterThanOrEqual", value: "5" }],
      #|          },
      #|        ),
      #|      },
      #|    ],
      #|  },
      #|)
    ),
  )
}

///|
test "auto filter invalid expression" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let options : Array[@xlsx.AutoFilterOption] = [
    { column: "A", expression: "x >< 1", },
  ]
  let result : Result[Unit, Error] = Ok(
    workbook.set_auto_filter("Sheet1", "A1:A2", options),
  ) catch {
    e => Err(e)
  }
  debug_inspect(
    result,
    content=(
      #|Err(InvalidAutoFilter(msg="auto filter operator invalid"))
    ),
  )
}

///|
test "auto filter: quoted tokens, wildcards, blanks/nonblanks" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))

  // Tokenize quotes + escaped quotes inside quotes.
  workbook.set_auto_filter("Sheet1", "A1:A2", [
    { column: "A", expression: "x == \"a\"\"b\"", },
  ])
  debug_inspect(
    workbook.get_auto_filter("Sheet1"),
    content=(
      #|Some(
      #|  {
      #|    range_ref: "A1:A2",
      #|    columns: [{ col: 1, filters: Some(["a\"b"]), custom_filters: None }],
      #|  },
      #|)
    ),
  )

  // Wildcards make this a custom filter (op 22).
  workbook.set_auto_filter("Sheet1", "A1:A2", [
    { column: "A", expression: "x == A*", },
  ])
  let f1 = match workbook.get_auto_filter("Sheet1") {
    Some(v) => v
    None => fail("missing auto filter")
  }
  inspect(f1.columns[0].custom_filters is Some(_), content="true")

  // blanks/nonblanks normalization.
  workbook.set_auto_filter("Sheet1", "A1:A2", [
    { column: "A", expression: "x != blanks", },
  ])
  let f2 = match workbook.get_auto_filter("Sheet1") {
    Some(v) => v
    None => fail("missing auto filter")
  }
  inspect(f2.columns[0].custom_filters is Some(_), content="true")
  workbook.set_auto_filter("Sheet1", "A1:A2", [
    { column: "A", expression: "x == nonblanks", },
  ])
  let f3 = match workbook.get_auto_filter("Sheet1") {
    Some(v) => v
    None => fail("missing auto filter")
  }
  inspect(f3.columns[0].custom_filters is Some(_), content="true")
}

///|
test "auto filter: quoted values keep spaces without quote delimiters" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("S"))
  workbook.set_auto_filter("S", "A1:D50", [
    { column: "A", expression: "x == \"North America\"" },
    { column: "B", expression: "x >= \"1 000\"" },
    { column: "C", expression: "x == \"\"" },
  ])
  debug_inspect(
    workbook.get_auto_filter("S"),
    content=(
      #|Some(
      #|  {
      #|    range_ref: "A1:D50",
      #|    columns: [
      #|      { col: 1, filters: Some(["North America"]), custom_filters: None },
      #|      {
      #|        col: 2,
      #|        filters: None,
      #|        custom_filters: Some(
      #|          {
      #|            and_filter: false,
      #|            filters: [{ operator: "greaterThanOrEqual", value: "1 000" }],
      #|          },
      #|        ),
      #|      },
      #|      { col: 3, filters: Some([""]), custom_filters: None },
      #|    ],
      #|  },
      #|)
    ),
  )
  // Escaped doubled quote inside a quoted value is a literal quote.
  workbook.set_auto_filter("S", "A1:A2", [
    { column: "A", expression: "x == \"say \"\"hi\"\"\"" },
  ])
  debug_inspect(
    workbook.get_auto_filter("S"),
    content=(
      #|Some(
      #|  {
      #|    range_ref: "A1:A2",
      #|    columns: [{ col: 1, filters: Some(["say \"hi\""]), custom_filters: None }],
      #|  },
      #|)
    ),
  )
  // Roundtrip keeps the unquoted value.
  let parsed = @xlsx.read(@xlsx.write(workbook))
  match parsed.get_auto_filter("S") {
    Some(filter) =>
      debug_inspect(
        filter.columns[0].filters,
        content=(
          #|Some(["say \"hi\""])
        ),
      )
    None => fail("missing auto filter")
  }
}

///|
test "auto filter: quoted value written to xml without delimiters" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("S"))
  workbook.set_auto_filter("S", "A1:D50", [
    { column: "A", expression: "x == \"North America\"" },
  ])
  let archive = @zip.read(@xlsx.write(workbook))
  guard archive.get("xl/worksheets/sheet1.xml") is Some(bytes) else {
    fail("no sheet1.xml")
  }
  let xml = @encoding/utf8.decode(bytes)
  inspect(xml.contains("<filter val=\"North America\"/>"), content="true")
  inspect(xml.contains("&quot;"), content="false")
}

///|
test "auto filter: unclosed quote raises InvalidAutoFilter" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let result : Result[Unit, Error] = Ok(
    workbook.set_auto_filter("Sheet1", "A1:A2", [
      { column: "A", expression: "x == \"North America" },
    ]),
  ) catch {
    e => Err(e)
  }
  debug_inspect(
    result,
    content=(
      #|Err(InvalidAutoFilter(msg="auto filter expression unclosed quote"))
    ),
  )
}

///|
test "auto filter: invalid token count and blanks operator" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let bad_tokens : Result[Unit, Error] = Ok(
    workbook.set_auto_filter("Sheet1", "A1:A2", [
      { column: "A", expression: "x ==", },
    ]),
  ) catch {
    e => Err(e)
  }
  debug_inspect(
    bad_tokens,
    content=(
      #|Err(InvalidAutoFilter(msg="auto filter expression invalid"))
    ),
  )
  let bad_tokens2 : Result[Unit, Error] = Ok(
    workbook.set_auto_filter("Sheet1", "A1:A2", [
      { column: "A", expression: "x == 1 2", },
    ]),
  ) catch {
    e => Err(e)
  }
  debug_inspect(
    bad_tokens2,
    content=(
      #|Err(InvalidAutoFilter(msg="auto filter expression invalid"))
    ),
  )
  let bad_blanks_op : Result[Unit, Error] = Ok(
    workbook.set_auto_filter("Sheet1", "A1:A2", [
      { column: "A", expression: "x > blanks", },
    ]),
  ) catch {
    e => Err(e)
  }
  debug_inspect(
    bad_blanks_op,
    content=(
      #|Err(InvalidAutoFilter(msg="auto filter operator invalid"))
    ),
  )
}

///|
test "auto filter: custom operators, and-expression, and column validation" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))

  // < and <= map to custom filter operators.
  workbook.set_auto_filter("Sheet1", "A1:A2", [
    { column: "A", expression: "x < 3", },
  ])
  debug_inspect(
    workbook.get_auto_filter("Sheet1"),
    content=(
      #|Some(
      #|  {
      #|    range_ref: "A1:A2",
      #|    columns: [
      #|      {
      #|        col: 1,
      #|        filters: None,
      #|        custom_filters: Some({ and_filter: false, filters: [{ operator: "lessThan", value: "3" }] }),
      #|      },
      #|    ],
      #|  },
      #|)
    ),
  )
  workbook.set_auto_filter("Sheet1", "A1:A2", [
    { column: "A", expression: "x <= 3", },
  ])
  debug_inspect(
    workbook.get_auto_filter("Sheet1"),
    content=(
      #|Some(
      #|  {
      #|    range_ref: "A1:A2",
      #|    columns: [
      #|      {
      #|        col: 1,
      #|        filters: None,
      #|        custom_filters: Some(
      #|          {
      #|            and_filter: false,
      #|            filters: [{ operator: "lessThanOrEqual", value: "3" }],
      #|          },
      #|        ),
      #|      },
      #|    ],
      #|  },
      #|)
    ),
  )

  // blanks/nonblanks (including the != nonblanks normalization path).
  workbook.set_auto_filter("Sheet1", "A1:A2", [
    { column: "A", expression: "x != nonblanks", },
  ])
  debug_inspect(
    workbook.get_auto_filter("Sheet1"),
    content=(
      #|Some(
      #|  {
      #|    range_ref: "A1:A2",
      #|    columns: [{ col: 1, filters: Some(["blanks"]), custom_filters: None }],
      #|  },
      #|)
    ),
  )

  // Two custom filters with an `and` expression.
  workbook.set_auto_filter("Sheet1", "A1:A2", [
    { column: "A", expression: "x > 1 and x < 3", },
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
    { column: "", expression: "x == 1", },
    { column: "A", expression: "", },
    { column: "A", expression: "x == 1", },
  ])
  debug_inspect(
    workbook.get_auto_filter("Sheet1"),
    content=(
      #|Some(
      #|  {
      #|    range_ref: "A1:A2",
      #|    columns: [{ col: 1, filters: Some(["1"]), custom_filters: None }],
      #|  },
      #|)
    ),
  )

  // Column invalid.
  let bad_col : Result[Unit, Error] = Ok(
    workbook.set_auto_filter("Sheet1", "A1:A2", [
      { column: "1", expression: "x == 1", },
    ]),
  ) catch {
    e => Err(e)
  }
  debug_inspect(
    bad_col,
    content=(
      #|Err(InvalidAutoFilter(msg="auto filter column invalid"))
    ),
  )

  // Column out of range.
  let out_of_range : Result[Unit, Error] = Ok(
    workbook.set_auto_filter("Sheet1", "A1:A2", [
      { column: "B", expression: "x == 1", },
    ]),
  ) catch {
    e => Err(e)
  }
  debug_inspect(
    out_of_range,
    content=(
      #|Err(InvalidAutoFilter(msg="auto filter column out of range"))
    ),
  )

  // Duplicate column is replaced.
  workbook.set_auto_filter("Sheet1", "A1:A2", [
    { column: "A", expression: "x == 1", },
    { column: "A", expression: "x == 2", },
  ])
  debug_inspect(
    workbook.get_auto_filter("Sheet1"),
    content=(
      #|Some(
      #|  {
      #|    range_ref: "A1:A2",
      #|    columns: [{ col: 1, filters: Some(["2"]), custom_filters: None }],
      #|  },
      #|)
    ),
  )
}

///|
test "auto filter clear" {
  let workbook = @xlsx.Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.clear_auto_filter()
  debug_inspect(sheet.auto_filter(), content="None")
}
