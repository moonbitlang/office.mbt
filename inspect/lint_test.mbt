// Blackbox tests for the `xlsx.lint/1` payload: formula cells that evaluate
// to an error, found by recomputing each formula.

///|
/// (finding_count, the matched refs in scan order) of a lint run.
fn lint_findings(
  workbook : @xlsx.Workbook,
  sheet? : String = "",
) -> (Int, Array[String]) raise {
  let map = match @inspect.lint(workbook, file="t.xlsx", sheet~) {
    Object(map) => map
    _ => fail("lint payload must be an object")
  }
  let count = match map.get("finding_count") {
    Some(Number(n, ..)) => n.to_int()
    _ => fail("missing finding_count")
  }
  let refs = []
  match map.get("findings") {
    Some(Array(items)) =>
      for item in items {
        match item {
          Object(finding) =>
            match finding.get("ref") {
              Some(String(reference)) => refs.push(reference)
              _ => fail("finding missing ref")
            }
          _ => fail("finding must be an object")
        }
      }
    _ => fail("missing findings array")
  }
  (count, refs)
}

///|
fn lint_book() -> @xlsx.Workbook raise {
  let workbook = @xlsx.Workbook::new()
  let data = workbook.add_sheet("Data")
  data.set_cell_value("A1", Numeric(10.0))
  data.set_cell_formula("A2", "A1/0") // #DIV/0!
  data.set_cell_formula("A3", "SUM(A1:A1)") // ok -> 10
  data.set_cell_formula("A4", "NOPE(1)") // #NAME?
  let other = workbook.add_sheet("Other")
  other.set_cell_formula("B1", "NA()") // #N/A
  other.set_cell_formula("B2", "1+1") // ok -> 2
  workbook
}

///|
test "lint reports formula cells that evaluate to an error, across sheets" {
  let workbook = lint_book()
  let (count, refs) = lint_findings(workbook)
  inspect(count, content="3")
  // Sheet order (Data before Other), then stored cell order.
  inspect(refs.join(","), content="A2,A4,B1")
}

///|
test "lint honors --sheet and finds nothing when all formulas are healthy" {
  let workbook = lint_book()
  inspect(lint_findings(workbook, sheet="Data").0, content="2")
  inspect(lint_findings(workbook, sheet="Other").0, content="1")
  // A workbook whose formulas all compute cleanly yields no findings.
  let clean = @xlsx.Workbook::new()
  let sheet = clean.add_sheet("S")
  sheet.set_cell_value("A1", Numeric(3.0))
  sheet.set_cell_formula("A2", "A1*2")
  inspect(lint_findings(clean).0, content="0")
}

///|
test "lint finding carries kind, location, code, and formula" {
  let workbook = @xlsx.Workbook::new()
  let sheet = workbook.add_sheet("Data")
  sheet.set_cell_formula("C3", "1/0")
  inspect(
    @inspect.lint(workbook, file="book.xlsx").stringify(indent=2),
    content=(
      #|{
      #|  "schema": "xlsx.lint/1",
      #|  "file": "book.xlsx",
      #|  "finding_count": 1,
      #|  "findings": [
      #|    {
      #|      "kind": "formula_error",
      #|      "sheet": "Data",
      #|      "ref": "C3",
      #|      "code": "#DIV/0!",
      #|      "formula": "1/0"
      #|    }
      #|  ]
      #|}
    ),
  )
}

///|
test "lint raises on an unknown --sheet" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Data"))
  let result : Result[Json, Error] = Ok(
    @inspect.lint(workbook, file="t.xlsx", sheet="Missing"),
  ) catch {
    err => Err(err)
  }
  assert_true(result is Err(@xlsx.XlsxError::SheetNotFound(_)))
}
