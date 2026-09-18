///|
fn large_plain_structural_edit_fixture() -> @xlsx.Workbook raise {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.new_sheet("Data"))
  // Crosses the 4096-item checkpoint boundary without using shared formulas,
  // so the test exercises the ordinary structural staging loops.
  for row in 1..<=4097 {
    workbook.set_cell_int("Data", "A\{row}", row)
  }
  workbook
}

///|
fn assert_plain_structural_edit_cancellation_is_atomic(
  edit : (@xlsx.Workbook, () -> Bool) -> Unit raise,
) -> Unit raise {
  let workbook = large_plain_structural_edit_fixture()
  let before = @xlsx.write(workbook)
  let checks = [0]
  let result : Result[Unit, Error] = Ok(
    edit(workbook, () => {
      checks[0] += 1
      // Validation and preflight consume the first checkpoints. This threshold
      // delivers cancellation only after ordinary-cell staging has begun.
      checks[0] >= 16
    }),
  ) catch {
    error => Err(error)
  }
  assert_true(result is Err(@xlsx.ReadCancelled))
  assert_true(checks[0] >= 16)
  assert_eq(@xlsx.write(workbook), before)
}

///|
test "plain structural edits poll late cancellation atomically" {
  assert_plain_structural_edit_cancellation_is_atomic((workbook, cancelled) => {
    workbook.insert_rows("Data", 2, 1, cancelled~)
  })
  assert_plain_structural_edit_cancellation_is_atomic((workbook, cancelled) => {
    workbook.remove_rows("Data", 2, 1, cancelled~)
  })
  assert_plain_structural_edit_cancellation_is_atomic((workbook, cancelled) => {
    workbook.insert_cols("Data", 2, 1, cancelled~)
  })
  assert_plain_structural_edit_cancellation_is_atomic((workbook, cancelled) => {
    workbook.remove_cols("Data", 2, 1, cancelled~)
  })
  assert_plain_structural_edit_cancellation_is_atomic((workbook, cancelled) => {
    workbook.duplicate_row_to("Data", 1, 2, cancelled~)
  })
}

///|
test "defined-name staging polls late cancellation atomically" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.new_sheet("Data"))
  workbook.set_cell_str("Data", "A1", "value")
  workbook.set_defined_name(
    @xlsx.DefinedName::new(
      "LongName",
      "Data!A1+" + "1+".repeat(6000) + "1",
      scope="Data",
    ),
  )
  let before = @xlsx.write(workbook)
  let checks = [0]
  let result : Result[Unit, Error] = Ok(
    workbook.insert_rows("Data", 1, 1, cancelled=() => {
      checks[0] += 1
      checks[0] >= 6
    }),
  ) catch {
    error => Err(error)
  }
  assert_true(result is Err(@xlsx.ReadCancelled))
  assert_true(checks[0] >= 6)
  assert_eq(@xlsx.write(workbook), before)
}
