// `calc_cell_typed` returns a formula's computed value as a typed `CellValue`
// (like `get_cell_value_raw` does for the *stored* value) instead of the
// stringified `calc_cell_value`. These tests pin the typed result per kind and
// assert it stays consistent with the raw string form.

///|
/// The typed result and the raw string of the same cell must agree: an empty
/// result is `None`/`""`, a bool is `1`/`0` raw, an error and a string are
/// verbatim, and a number's raw form parses back to the typed double.
fn assert_typed_consistent(
  workbook : @xlsx.Workbook,
  sheet : String,
  reference : String,
) -> Unit raise {
  let typed = workbook.calc_cell_typed(sheet, reference)
  let raw = workbook.calc_cell_value(sheet, reference, raw=true)
  match typed {
    None => assert_eq(raw, "")
    Some(String(text)) => assert_eq(raw, text)
    Some(Bool(flag)) => assert_eq(raw, if flag { "1" } else { "0" })
    Some(Error(code)) => assert_eq(raw, code)
    Some(Numeric(number)) => {
      let parsed = @string.parse_double(raw)
      assert_true((parsed - number).abs() <= 1.0e-9 * (number.abs() + 1.0))
    }
  }
}

///|
test "calc_cell_typed returns the typed computed value per kind" {
  let workbook = @xlsx.Workbook::new()
  let sheet = workbook.add_sheet("S")
  sheet.set_cell_value("A1", Numeric(1.0))
  sheet.set_cell_value("A2", Numeric(2.0))
  sheet.set_cell_value("A3", Numeric(3.0))
  sheet.set_cell_formula("B1", "SUM(A1:A3)") // number 6
  sheet.set_cell_formula("B2", "\"x\"&\"y\"") // string "xy"
  sheet.set_cell_formula("B3", "1=1") // bool true
  sheet.set_cell_formula("B4", "1<>1") // bool false
  sheet.set_cell_formula("B5", "1/0") // error #DIV/0!
  sheet.set_cell_formula("B6", "NA()") // error #N/A
  match workbook.calc_cell_typed("S", "B1") {
    Some(Numeric(number)) => inspect(number, content="6")
    other => fail("B1 should be numeric, got \{to_repr(other)}")
  }
  match workbook.calc_cell_typed("S", "B2") {
    Some(String(text)) => inspect(text, content="xy")
    other => fail("B2 should be a string, got \{to_repr(other)}")
  }
  match workbook.calc_cell_typed("S", "B3") {
    Some(Bool(flag)) => inspect(flag, content="true")
    other => fail("B3 should be a bool, got \{to_repr(other)}")
  }
  match workbook.calc_cell_typed("S", "B4") {
    Some(Bool(flag)) => inspect(flag, content="false")
    other => fail("B4 should be a bool, got \{to_repr(other)}")
  }
  match workbook.calc_cell_typed("S", "B5") {
    Some(Error(code)) => inspect(code, content="#DIV/0!")
    other => fail("B5 should be an error, got \{to_repr(other)}")
  }
  match workbook.calc_cell_typed("S", "B6") {
    Some(Error(code)) => inspect(code, content="#N/A")
    other => fail("B6 should be an error, got \{to_repr(other)}")
  }
  // Every one stays consistent with the raw string form.
  for reference in ["B1", "B2", "B3", "B4", "B5", "B6"] {
    assert_typed_consistent(workbook, "S", reference)
  }
}

///|
test "calc_cell_typed reads stored values and reports an empty cell as None" {
  let workbook = @xlsx.Workbook::new()
  let sheet = workbook.add_sheet("S")
  sheet.set_cell_value("A1", Numeric(42.0))
  sheet.set_cell_value("A2", String("hello"))
  sheet.set_cell_value("A3", Bool(true))
  // A non-formula cell reports its stored value, typed.
  match workbook.calc_cell_typed("S", "A1") {
    Some(Numeric(number)) => inspect(number, content="42")
    other => fail("A1 should be numeric, got \{to_repr(other)}")
  }
  match workbook.calc_cell_typed("S", "A2") {
    Some(String(text)) => inspect(text, content="hello")
    other => fail("A2 should be a string, got \{to_repr(other)}")
  }
  match workbook.calc_cell_typed("S", "A3") {
    Some(Bool(flag)) => inspect(flag, content="true")
    other => fail("A3 should be a bool, got \{to_repr(other)}")
  }
  // A blank cell is an empty result, distinct from an empty string.
  assert_true(workbook.calc_cell_typed("S", "Z9") is None)
  for reference in ["A1", "A2", "A3", "Z9"] {
    assert_typed_consistent(workbook, "S", reference)
  }
  // The row/col overload agrees with the A1 form.
  match workbook.calc_cell_typed_rc("S", 1, 1) {
    Some(Numeric(number)) => inspect(number, content="42")
    other => fail("A1 (rc) should be numeric, got \{to_repr(other)}")
  }
}

///|
test "calc_cell_typed surfaces a computed empty string distinct from a blank" {
  let workbook = @xlsx.Workbook::new()
  let sheet = workbook.add_sheet("S")
  // IF(...,"") yields a real empty-string value; calc_cell_typed keeps it as
  // Some(String("")), while a never-touched cell stays None. Both stringify to
  // "" via calc_cell_value, so the typed form carries strictly more detail.
  sheet.set_cell_formula("A1", "IF(TRUE,\"\",\"x\")")
  match workbook.calc_cell_typed("S", "A1") {
    Some(String(text)) => inspect(text, content="")
    other => fail("A1 should be an (empty) string, got \{to_repr(other)}")
  }
  assert_true(workbook.calc_cell_typed("S", "B9") is None)
  assert_typed_consistent(workbook, "S", "A1")
  assert_typed_consistent(workbook, "S", "B9")
}

///|
test "calc_cell_typed raises on a missing sheet" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("S"))
  let result : Result[@xlsx.CellValue?, Error] = Ok(
    workbook.calc_cell_typed("Missing", "A1"),
  ) catch {
    err => Err(err)
  }
  assert_true(result is Err(@xlsx.XlsxError::SheetNotFound(_)))
}
