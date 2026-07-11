// Blackbox tests for the `xlsx.query/1` content-selector search: selectors
// parse strictly, predicates match the right cells, and the payload reuses
// the `xlsx.cells/1` per-cell shape.

///|
/// A small fixture: text, three numbers, a formula, and a bool.
fn query_book() -> @xlsx.Workbook raise {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Data"))
  workbook.set_cell("Data", "A1", "Region")
  workbook.set_cell_int("Data", "B1", 100)
  workbook.set_cell_int("Data", "B2", 250)
  workbook.set_cell_int("Data", "B3", 50)
  workbook.set_cell_formula("Data", "B4", "SUM(B1:B3)")
  workbook.set_cell_bool("Data", "C1", true)
  workbook
}

///|
/// Runs a query and returns (match_count, matched refs in scan order).
fn run_query(
  workbook : @xlsx.Workbook,
  sheet : String,
  selector : String,
  range? : String = "",
) -> (Int, Array[String]) raise {
  let payload = @inspect.query(workbook, sheet, selector, file="t.xlsx", range~)
  let map = match payload {
    Object(map) => map
    _ => fail("query payload must be an object")
  }
  let count = match map.get("match_count") {
    Some(Number(n, ..)) => n.to_int()
    _ => fail("missing match_count")
  }
  let refs = []
  match map.get("matches") {
    Some(Array(items)) =>
      for item in items {
        match item {
          Object(cell) =>
            match cell.get("ref") {
              Some(String(reference)) => refs.push(reference)
              _ => fail("match missing ref")
            }
          _ => fail("match must be an object")
        }
      }
    _ => fail("missing matches array")
  }
  (count, refs)
}

///|
test "query type predicates classify by raw value kind" {
  let workbook = query_book()
  let (formula_n, formula_refs) = run_query(
    workbook, "Data", "cell[type=formula]",
  )
  inspect(formula_n, content="1")
  inspect(formula_refs[0], content="B4")
  // B4's formula has no cached numeric value, so it is not a `number`.
  let (number_n, number_refs) = run_query(workbook, "Data", "cell[type=number]")
  inspect(number_n, content="3")
  inspect(number_refs.join(","), content="B1,B2,B3")
  let (string_n, string_refs) = run_query(workbook, "Data", "cell[type=string]")
  inspect(string_n, content="1")
  inspect(string_refs[0], content="A1")
  let (bool_n, bool_refs) = run_query(workbook, "Data", "cell[type=bool]")
  inspect(bool_n, content="1")
  inspect(bool_refs[0], content="C1")
}

///|
test "query value predicates compare numeric cells" {
  let workbook = query_book()
  inspect(run_query(workbook, "Data", "cell[value>=100]").0, content="2")
  inspect(run_query(workbook, "Data", "cell[value>100]").0, content="1")
  inspect(run_query(workbook, "Data", "cell[value<100]").0, content="1")
  inspect(run_query(workbook, "Data", "cell[value<=50]").0, content="1")
  inspect(run_query(workbook, "Data", "cell[value=250]").0, content="1")
  inspect(run_query(workbook, "Data", "cell[value!=100]").0, content="2")
  // Predicates AND together.
  let (count, refs) = run_query(
    workbook, "Data", "cell[type=number][value>100]",
  )
  inspect(count, content="1")
  inspect(refs[0], content="B2")
}

///|
test "query formula and text predicates" {
  let workbook = query_book()
  inspect(run_query(workbook, "Data", "cell[formula~=SUM]").0, content="1")
  inspect(run_query(workbook, "Data", "cell[formula~=AVERAGE]").0, content="0")
  inspect(run_query(workbook, "Data", "cell[formula]").0, content="1")
  let (contains_n, contains_refs) = run_query(
    workbook, "Data", "cell[text~=egi]",
  )
  inspect(contains_n, content="1")
  inspect(contains_refs[0], content="A1")
  inspect(run_query(workbook, "Data", "cell[text=Region]").0, content="1")
  inspect(run_query(workbook, "Data", "cell[text=region]").0, content="0")
}

///|
test "a bare cell selector matches every populated cell" {
  let workbook = query_book()
  let (count, refs) = run_query(workbook, "Data", "cell")
  inspect(count, content="6")
  inspect(refs.join(","), content="A1,B1,C1,B2,B3,B4")
}

///|
test "query honors an explicit --range and reports the scanned range" {
  let workbook = query_book()
  // Only B1:B3 is scanned, so B4's formula and the 250 outside are considered
  // per the range; value>=100 inside B1:B3 is B1 and B2.
  let (count, refs) = run_query(
    workbook,
    "Data",
    "cell[value>=100]",
    range="B1:B3",
  )
  inspect(count, content="2")
  inspect(refs.join(","), content="B1,B2")
  // The payload echoes the scanned range and selector.
  let payload = @inspect.query(
    workbook,
    "Data",
    "cell[type=number]",
    file="t.xlsx",
    range="A1:B2",
  )
  match payload {
    Object(map) => {
      match map.get("range") {
        Some(String(scanned)) => inspect(scanned, content="A1:B2")
        _ => fail("range must echo the scanned A1:B2")
      }
      match map.get("schema") {
        Some(String(schema)) => inspect(schema, content="xlsx.query/1")
        _ => fail("schema must be set")
      }
    }
    _ => fail("payload must be an object")
  }
}

///|
test "query over an empty sheet yields no matches and an empty range" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Blank"))
  let (count, _) = run_query(workbook, "Blank", "cell[type=formula]")
  inspect(count, content="0")
  let payload = @inspect.query(
    workbook,
    "Blank",
    "cell",
    file="t.xlsx",
    range="",
  )
  match payload {
    Object(map) =>
      match map.get("range") {
        Some(String(scanned)) => inspect(scanned, content="")
        _ => fail("range must be the empty string for an empty sheet")
      }
    _ => fail("payload must be an object")
  }
}

///|
test "query rejects malformed selectors with a typed error" {
  let workbook = query_book()
  let cases = [
    ("rows[1]", "selector must be 'cell'"),
    ("cell[bogus]", "unknown predicate 'bogus'"),
    ("cell[type=decimal]", "unknown type 'decimal'"),
    ("cell[value>x]", "value predicate expects a number"),
    ("cell[value100]", "a value predicate needs an operator"),
    ("cell[type=formula", "missing a closing ']'"),
  ]
  for case in cases {
    let (selector, want) = case
    try {
      ignore(
        @inspect.query(workbook, "Data", selector, file="t.xlsx", range=""),
      )
      fail("expected '\{selector}' to be rejected")
    } catch {
      @inspect.QueryError(message) => assert_true(message.contains(want))
      err => fail("expected a QueryError for '\{selector}', got \{err}")
    }
  }
}
