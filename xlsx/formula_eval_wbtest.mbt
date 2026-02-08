///|
fn wb_range(
  values : Array[FormulaValue],
  rows : Int,
  cols : Int,
) -> RangeValues {
  { values, rows, cols }
}

///|
test "formula eval wb: anchorarray and range guards" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))

  let anchor_err = anchorarray_values(
    workbook,
    "Sheet1",
    [Cell("", "bad_ref")][:],
    [FormulaValue::Number(1.0)][:],
  )
  inspect(
    match anchor_err {
      Error(err) => err == formula_error_value
      _ => false
    },
    content="true",
  )

  let range = wb_range([Number(1.0), Number(2.0), Number(3.0), Number(4.0)], 2, 2)
  inspect(range_column(range, -1) is None, content="true")
  inspect(range_row(range, 2) is None, content="true")
}

///|
test "formula eval wb: munit and transpose guard paths" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let ctx = CalcContext::new()

  let munit_bad_arity = munit_range_values_from_expr(workbook, "Sheet1", [], ctx)
  inspect(munit_bad_arity.rows, content="1")
  inspect(munit_bad_arity.cols, content="1")
  inspect(munit_bad_arity.values.length(), content="1")
  inspect(
    match munit_bad_arity.values[0] {
      Error(err) => err == formula_error_value
      _ => false
    },
    content="true",
  )

  let munit_bad_value = munit_range_values_from_expr(
    workbook, "Sheet1", [String("not-number")], ctx,
  )
  inspect(munit_bad_value.values.length(), content="1")
  inspect(
    match munit_bad_value.values[0] {
      Error(err) => err == formula_error_value
      _ => false
    },
    content="true",
  )

  let transpose_bad_arity = transpose_range_values_from_expr(
    workbook, "Sheet1", [], ctx,
  )
  inspect(transpose_bad_arity.rows, content="1")
  inspect(transpose_bad_arity.cols, content="1")
  inspect(transpose_bad_arity.values.length(), content="1")
  inspect(
    match transpose_bad_arity.values[0] {
      Error(err) => err == formula_error_value
      _ => false
    },
    content="true",
  )

  let transpose_scalar = transpose_range_values_from_expr(
    workbook, "Sheet1", [Number(7.0)], ctx,
  )
  inspect(transpose_scalar.values.length(), content="1")
  inspect(
    match transpose_scalar.values[0] {
      Number(num) => num == 7.0
      _ => false
    },
    content="true",
  )
  inspect(transpose_scalar.rows, content="1")
  inspect(transpose_scalar.cols, content="1")
}

///|
test "formula eval wb: matrix and trend helper guards" {
  let empty_range_result = number_matrix_from_range(wb_range([], 0, 0), false)
  inspect(
    match empty_range_result {
      Err(Error(err)) => err == formula_error_value
      _ => false
    },
    content="true",
  )

  let bool_matrix_result = number_matrix_from_range(
    wb_range([Bool(true)], 1, 1),
    false,
  )
  inspect(
    match bool_matrix_result {
      Ok(matrix) => matrix.length() == 1 && matrix[0].length() == 1 && matrix[0][0] == 1.0
      _ => false
    },
    content="true",
  )

  let minor = matrix_minor([[1.0, 2.0], [3.0, 4.0], [5.0, 6.0]], 1)
  inspect(minor, content="[[3], [5]]")

  inspect(new_matrix(0, 2), content="[]")

  let trend_x_bad = prepare_trend_growth_mtx_x([[0.0]])
  inspect(
    match trend_x_bad {
      Err(Error(err)) => err == formula_error_num
      _ => false
    },
    content="true",
  )

  let trend_y_bad = prepare_trend_growth_mtx_y(false, [[0.0]])
  inspect(
    match trend_y_bad {
      Err(Error(err)) => err == formula_error_num
      _ => false
    },
    content="true",
  )
}
