// Blackbox tests for the `xlsx.calc/1` payload: a cell's typed *computed*
// value, in the same `{type, value}` shape as `xlsx.cells/1`'s `raw` field.

///|
/// The stringified `result` field of the calc payload, or "absent" when the
/// formula computes to an empty result (the key is omitted).
fn result_str(
  workbook : @xlsx.Workbook,
  sheet : String,
  reference : String,
) -> String raise {
  match @inspect.calc(workbook, file="t.xlsx", sheet, reference) {
    Object(map) =>
      match map.get("result") {
        Some(result) => result.stringify()
        None => "absent"
      }
    _ => fail("calc payload must be an object")
  }
}

///|
test "calc payload reports the typed computed value per kind" {
  let workbook = @xlsx.Workbook::new()
  let sheet = workbook.add_sheet("Data")
  sheet.set_cell_value("A1", Numeric(10.0))
  sheet.set_cell_value("A2", Numeric(20.0))
  sheet.set_cell_formula("A3", "SUM(A1:A2)")
  sheet.set_cell_formula("A4", "A1/0")
  sheet.set_cell_formula("A5", "\"a\"&\"b\"")
  sheet.set_cell_formula("A6", "1=1")
  inspect(
    result_str(workbook, "Data", "A3"),
    content=(
      #|{"type":"number","value":30}
    ),
  )
  inspect(
    result_str(workbook, "Data", "A4"),
    content=(
      #|{"type":"error","value":"#DIV/0!"}
    ),
  )
  inspect(
    result_str(workbook, "Data", "A5"),
    content=(
      #|{"type":"string","value":"ab"}
    ),
  )
  inspect(
    result_str(workbook, "Data", "A6"),
    content=(
      #|{"type":"bool","value":true}
    ),
  )
  // A never-touched cell computes to an empty result: `result` is omitted.
  inspect(result_str(workbook, "Data", "Z9"), content="absent")
}

///|
test "calc payload carries the full envelope" {
  let workbook = @xlsx.Workbook::new()
  let sheet = workbook.add_sheet("Data")
  sheet.set_cell_value("A1", Numeric(7.0))
  sheet.set_cell_formula("B1", "A1*6")
  inspect(
    @inspect.calc(workbook, file="book.xlsx", "Data", "B1").stringify(indent=2),
    content=(
      #|{
      #|  "schema": "xlsx.calc/1",
      #|  "file": "book.xlsx",
      #|  "sheet": "Data",
      #|  "ref": "B1",
      #|  "result": {
      #|    "type": "number",
      #|    "value": 42
      #|  }
      #|}
    ),
  )
}

///|
test "calc payload raises on a missing sheet" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Data"))
  let result : Result[Json, Error] = Ok(
    @inspect.calc(workbook, file="t.xlsx", "Missing", "A1"),
  ) catch {
    err => Err(err)
  }
  assert_true(result is Err(@xlsx.XlsxError::SheetNotFound(_)))
}
