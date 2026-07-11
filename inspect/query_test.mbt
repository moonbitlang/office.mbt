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
  // A predicate argument is trimmed (whitespace after the operator too), so
  // this still finds "Region"; an all-whitespace argument is rejected.
  inspect(run_query(workbook, "Data", "cell[text=  Region  ]").0, content="1")
  inspect(run_query(workbook, "Data", "cell[formula~=  SUM ]").0, content="1")
  try {
    ignore(
      @inspect.query(
        workbook,
        "Data",
        "cell[text=   ]",
        file="t.xlsx",
        range="",
      ),
    )
    fail("expected an all-whitespace argument to be rejected")
  } catch {
    @inspect.QueryError(message) =>
      assert_true(message.contains("text= needs a non-empty value"))
    err => fail("expected a QueryError, got \{err}")
  }
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
    // A non-finite bound is not a useful comparison.
    ("cell[value>NaN]", "value predicate expects a finite number"),
    ("cell[value<=Infinity]", "value predicate expects a finite number"),
    // An empty text/needle would match everything or nothing by accident.
    ("cell[text=]", "text= needs a non-empty value"),
    ("cell[text~=]", "text~= needs a non-empty value"),
    ("cell[formula~=]", "formula~= needs a non-empty value"),
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

///|
test "query reports a missing sheet identically with or without --range" {
  let workbook = query_book()
  for range in ["", "A1:B2"] {
    try {
      ignore(@inspect.query(workbook, "Missing", "cell", file="t.xlsx", range~))
      fail("expected the missing sheet to be rejected")
    } catch {
      @inspect.QueryError(message) =>
        assert_eq(message, "sheet 'Missing' not found")
      err => fail("expected a QueryError, got \{err}")
    }
  }
}

///|
test "text predicates skip a styled blank cell, like type=string" {
  let workbook = query_book()
  // A bare styled cell stores a synthetic empty string; it is populated (has
  // a style) but carries no real text.
  let style_id = workbook.new_style(@xlsx.Style::number_format("0.00"))
  workbook.set_cell_style("Data", "Z1", style_id)
  // The bare selector still sees it (it has a style), so it is a real cell...
  let (bare, bare_refs) = run_query(workbook, "Data", "cell")
  inspect(bare, content="7")
  assert_true(bare_refs.contains("Z1"))
  // ...but text and type=string predicates require real stored text.
  inspect(run_query(workbook, "Data", "cell[type=string]").0, content="1")
  inspect(run_query(workbook, "Data", "cell[text~=0]").0, content="0")
}
