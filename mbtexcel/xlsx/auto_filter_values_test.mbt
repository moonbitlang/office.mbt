///|
test "auto filter accepts an equality OR chain with three values" {
  let wb = @xlsx.Workbook::new()
  ignore(wb.add_sheet("S"))
  wb.set_auto_filter("S", "B1:D50", [
    { column: "B", expression: "x == EMEA or x == APAC or x == AMER", },
  ])
  debug_inspect(
    wb.get_auto_filter("S").unwrap().columns[0].filters,
    content="Some([\"EMEA\", \"APAC\", \"AMER\"])",
  )
  let reopened = @xlsx.read(@xlsx.write(wb))
  debug_inspect(
    reopened.get_auto_filter("S").unwrap().columns[0].filters,
    content="Some([\"EMEA\", \"APAC\", \"AMER\"])",
  )
}

///|
test "literal filter lists preserve text and do not alias caller arrays" {
  let wb = @xlsx.Workbook::new()
  ignore(wb.add_sheet("O'Brien"))
  let values = ["North America", "or", "say \"hi\"", "blanks", "*", "?", "A&B"]
  wb.set_auto_filter_values("O'Brien", "B1:D50", [
    { column: "B", values: ["replaced"], },
    { column: "D", values: ["EMEA", "APAC", "AMER", "LATAM"], },
    { column: "B", values, },
  ])
  values[0] = "mutated"
  let bytes = @xlsx.write(wb)
  let reopened = @xlsx.read(bytes)
  debug_inspect(
    reopened.get_auto_filter("O'Brien"),
    content=(
      #|Some(
      #|  {
      #|    range_ref: "B1:D50",
      #|    columns: [
      #|      {
      #|        col: 2,
      #|        filters: Some(["North America", "or", "say \"hi\"", "blanks", "*", "?", "A&B"]),
      #|        custom_filters: None,
      #|      },
      #|      {
      #|        col: 4,
      #|        filters: Some(["EMEA", "APAC", "AMER", "LATAM"]),
      #|        custom_filters: None,
      #|      },
      #|    ],
      #|  },
      #|)
    ),
  )
  let zip = @zip.read(bytes)
  let xml = @encoding/utf8.decode(zip.get("xl/worksheets/sheet1.xml").unwrap())
  debug_inspect(xml.contains("<filterColumn colId=\"0\">"), content="true")
  debug_inspect(xml.contains("<filterColumn colId=\"2\">"), content="true")
  debug_inspect(xml.contains("<filter val=\"A&amp;B\"/>"), content="true")
  debug_inspect(xml.contains("<customFilters"), content="false")
  let book = @encoding/utf8.decode(zip.get("xl/workbook.xml").unwrap())
  debug_inspect(book.contains("_xlnm._FilterDatabase"), content="true")
  debug_inspect(book.contains("$B$1:$D$50"), content="true")
}

///|
test "invalid filter lists and unsupported expressions leave the old filter intact" {
  let wb = @xlsx.Workbook::new()
  let sheet = wb.add_sheet("S")
  wb.set_auto_filter_values("S", "B1:D50", [{ column: "B", values: ["keep"], }])
  let errors : Array[Bool] = []
  let invalid_options : Array[@xlsx.AutoFilterValuesOption] = [
    { column: "A", values: ["a"], },
    { column: "E", values: ["a"], },
    { column: "?", values: ["a"], },
    { column: "", values: ["a"], },
    { column: "B", values: [], },
  ]
  for option in invalid_options {
    let rejected = try {
      sheet.set_auto_filter_values("B1:D50", [
        { column: "C", values: ["new"], },
        option,
      ])
      false
    } catch {
      InvalidAutoFilter(_) => true
      _ => false
    }
    errors.push(rejected)
  }
  for
    expression in [
      "x > 1 or x > 2 or x > 3", "x == a and x == b and x == c", "x == a or x == b and x == c",
      "x == a or x == b or x == c*", "x == a xor x == b", "x == a or",
    ] {
    let rejected = try {
      wb.set_auto_filter("S", "B1:D50", [{ column: "B", expression, }])
      false
    } catch {
      InvalidAutoFilter(_) => true
      _ => false
    }
    errors.push(rejected)
  }
  debug_inspect(
    errors,
    content=(
      #|[true, true, true, true, true, true, true, true, true, true, true]
    ),
  )
  debug_inspect(
    sheet.auto_filter().unwrap().columns[0].filters,
    content="Some([\"keep\"])",
  )
  sheet.set_auto_filter_values("B1:D50", [])
  debug_inspect(sheet.auto_filter().unwrap().columns.length(), content="0")
}

///|
test "long equality chains support OR aliases and quoted values" {
  let wb = @xlsx.Workbook::new()
  ignore(wb.add_sheet("S"))
  wb.set_auto_filter("S", "A1:A50", [
    {
      column: "A",
      expression: "x == \"North America\" OR x eq \"or\" || x = \"say \"\"hi\"\"\" or x == EMEA",
    },
  ])
  debug_inspect(
    @xlsx.read(@xlsx.write(wb)).get_auto_filter("S").unwrap().columns[0].filters,
    content=(
      #|Some(["North America", "or", "say \"hi\"", "EMEA"])
    ),
  )
}

///|
test "literal filters respect stream writer exclusion" {
  let wb = @xlsx.Workbook::new()
  let sheet = wb.add_sheet("S")
  ignore(wb.new_stream_writer("S"))
  let rejected = try {
    wb.set_auto_filter_values("S", "A1:A3", [{ column: "A", values: ["a"], }])
    false
  } catch {
    StreamModeConflict(_) => true
    _ => false
  }
  debug_inspect(rejected, content="true")
  debug_inspect(sheet.auto_filter(), content="None")
}
