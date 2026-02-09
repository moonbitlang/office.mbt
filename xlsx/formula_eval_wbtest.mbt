///|
fn wb_range(
  values : Array[FormulaValue],
  rows : Int,
  cols : Int,
) -> RangeValues {
  { values, rows, cols }
}

///|
fn wb_is_error(value : FormulaValue, expected : String) -> Bool {
  match value {
    Error(err) => err == expected
    _ => false
  }
}

///|
fn wb_is_number(value : FormulaValue) -> Bool {
  match value {
    Number(_) => true
    _ => false
  }
}

///|
fn wb_number_eq(value : FormulaValue, expected : Double) -> Bool {
  match value {
    Number(num) => num == expected
    _ => false
  }
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

///|
test "formula eval wb: sequence randarray and slice guards" {
  inspect(
    wb_is_error(
      sequence_values([FormulaValue::String("bad-rows")][:]),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    wb_is_error(
      sequence_values(
        [FormulaValue::Number(1.0), FormulaValue::String("bad-cols")][:],
      ),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    wb_is_error(
      sequence_values([
        FormulaValue::Number(1.0),
        FormulaValue::Number(1.0),
        FormulaValue::String("bad-start"),
      ][:]),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    wb_is_error(
      sequence_values([
        FormulaValue::Number(1.0),
        FormulaValue::Number(1.0),
        FormulaValue::Number(1.0),
        FormulaValue::String("bad-step"),
      ][:]),
      formula_error_value,
    ),
    content="true",
  )

  let empty_rand_args : Array[FormulaValue] = []
  let rand_default = randarray_values(empty_rand_args[:])
  inspect(
    match rand_default {
      List(list) => list.length() == 1
      _ => false
    },
    content="true",
  )

  let rand_float = randarray_values([
    FormulaValue::Number(1.0),
    FormulaValue::Number(2.0),
    FormulaValue::Number(0.0),
    FormulaValue::Number(1.0),
    FormulaValue::Bool(false),
  ][:])
  let rand_float_ok = match rand_float {
    FormulaValue::List(list) => list.length() == 2 && wb_is_number(list[0])
    _ => false
  }
  inspect(rand_float_ok, content="true")
  inspect(
    wb_is_error(
      randarray_values([
        FormulaValue::String("bad-rows"),
      ][:]),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    wb_is_error(
      randarray_values([
        FormulaValue::Number(1.0),
        FormulaValue::String("bad-cols"),
      ][:]),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    wb_is_error(
      randarray_values([
        FormulaValue::Number(1.0),
        FormulaValue::Number(1.0),
        FormulaValue::String("bad-min"),
      ][:]),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    wb_is_error(
      randarray_values([
        FormulaValue::Number(1.0),
        FormulaValue::Number(1.0),
        FormulaValue::Number(0.0),
        FormulaValue::String("bad-max"),
      ][:]),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    wb_is_error(
      randarray_values([
        FormulaValue::Number(1.0),
        FormulaValue::Number(1.0),
        FormulaValue::Number(0.0),
        FormulaValue::Number(1.0),
        FormulaValue::String("bad-whole"),
      ][:]),
      formula_error_value,
    ),
    content="true",
  )

  let range = wb_range([
    Number(1.0),
    Number(2.0),
    Number(3.0),
    Number(4.0),
  ], 2, 2)
  inspect(
    match slice_range_values(range, 0, 0, 0, 1) {
      Err(Error(err)) => err == formula_error_value
      _ => false
    },
    content="true",
  )
  inspect(
    match slice_range_values(range, -1, 1, 0, 1) {
      Err(Error(err)) => err == formula_error_value
      _ => false
    },
    content="true",
  )
  inspect(
    match slice_range_values(range, 1, 2, 0, 1) {
      Err(Error(err)) => err == formula_error_value
      _ => false
    },
    content="true",
  )
}

///|
test "formula eval wb: range transforms and index guards" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let ctx = CalcContext::new()
  let base_expr = Expr::Number(0.0)
  let base_list : FormulaValue = List([
    Number(1.0),
    Number(2.0),
    Number(3.0),
    Number(4.0),
  ])

  inspect(
    wb_is_error(
      take_values(
        workbook,
        "Sheet1",
        [base_expr, Expr::Number(0.0)][:],
        [base_list, FormulaValue::String("bad-rows")][:],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    wb_is_error(
      take_values(
        workbook,
        "Sheet1",
        [base_expr, Expr::Number(0.0), Expr::Number(0.0)][:],
        [base_list, Number(1.0), FormulaValue::String("bad-cols")][:],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    wb_is_error(
      drop_values(
        workbook,
        "Sheet1",
        [base_expr, Expr::Number(0.0)][:],
        [base_list, FormulaValue::String("bad-rows")][:],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    wb_is_error(
      drop_values(
        workbook,
        "Sheet1",
        [base_expr, Expr::Number(0.0), Expr::Number(0.0)][:],
        [base_list, Number(1.0), FormulaValue::String("bad-cols")][:],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    wb_is_error(
      drop_values(
        workbook,
        "Sheet1",
        [base_expr, Expr::Number(0.0)][:],
        [base_list, Number(1.0)][:],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    wb_is_error(
      expand_values(
        workbook,
        "Sheet1",
        [base_expr, Expr::Number(0.0)][:],
        [base_list, FormulaValue::String("bad-rows")][:],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    wb_is_error(
      expand_values(
        workbook,
        "Sheet1",
        [base_expr, Expr::Number(0.0), Expr::Number(0.0)][:],
        [base_list, Number(1.0), FormulaValue::String("bad-cols")][:],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    wb_is_error(
      expand_values(
        workbook,
        "Sheet1",
        [base_expr, Expr::Number(0.0), Expr::Number(0.0), Expr::Number(0.0)][:],
        [base_list, Number(1.0), Number(4.0), Error(formula_error_ref)][:],
        ctx,
      ),
      formula_error_ref,
    ),
    content="true",
  )
  inspect(
    wb_is_error(
      wrap_values(
        workbook,
        "Sheet1",
        [base_expr][:],
        [base_list][:],
        ctx,
        true,
      ),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    wb_is_error(
      wrap_values(
        workbook,
        "Sheet1",
        [base_expr, Expr::Number(0.0)][:],
        [base_list, FormulaValue::String("bad-count")][:],
        ctx,
        true,
      ),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    wb_is_error(
      wrap_values(
        workbook,
        "Sheet1",
        [base_expr, Expr::Number(0.0), Expr::Number(0.0)][:],
        [base_list, Number(2.0), Error(formula_error_ref)][:],
        ctx,
        false,
      ),
      formula_error_ref,
    ),
    content="true",
  )
  let wrapped_default_pad = wrap_values(
    workbook,
    "Sheet1",
    [base_expr, Expr::Number(0.0)][:],
    [base_list, Number(3.0)][:],
    ctx,
    true,
  )
  inspect(
    match wrapped_default_pad {
      List(list) => list.length() == 6
      _ => false
    },
    content="true",
  )

  let error_range = wb_range([Error(formula_error_ref)], 1, 1)
  inspect(
    match flatten_range_values(error_range, true, 0) {
      Err(Error(err)) => err == formula_error_ref
      _ => false
    },
    content="true",
  )
  inspect(
    match flatten_range_values(error_range, true, 2) {
      Err(Error(err)) => err == formula_error_calc
      _ => false
    },
    content="true",
  )
  inspect(
    match flatten_range_values(wb_range([Empty], 1, 1), false, 1) {
      Err(Error(err)) => err == formula_error_calc
      _ => false
    },
    content="true",
  )

  inspect(
    match choose_indices([FormulaValue::String("bad-idx")][:], 3) {
      Err(Error(err)) => err == formula_error_value
      _ => false
    },
    content="true",
  )
  let no_indices : Array[FormulaValue] = []
  inspect(
    match choose_indices(no_indices[:], 3) {
      Err(Error(err)) => err == formula_error_value
      _ => false
    },
    content="true",
  )
}

///|
test "formula eval wb: sort filter and tocol-torow guards" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let ctx = CalcContext::new()
  let vec_range = wb_range([Number(1.0), Number(2.0)], 1, 2)
  let matrix_range = wb_range([
    Number(1.0),
    Number(2.0),
    Number(3.0),
    Number(4.0),
  ], 2, 2)

  inspect(
    match sort_range_values(vec_range, 0, 1) {
      Err(Error(err)) => err == formula_error_value
      _ => false
    },
    content="true",
  )
  inspect(
    match sort_range_values(vec_range, 1, 0) {
      Err(Error(err)) => err == formula_error_value
      _ => false
    },
    content="true",
  )
  inspect(
    match sort_range_values(wb_range([Error(formula_error_ref)], 1, 1), 1, 1) {
      Err(Error(err)) => err == formula_error_ref
      _ => false
    },
    content="true",
  )

  inspect(
    match sortby_vector(matrix_range, 2) {
      Err(Error(err)) => err == formula_error_value
      _ => false
    },
    content="true",
  )
  inspect(
    match sortby_vector(wb_range([Error(formula_error_ref)], 1, 1), 1) {
      Err(Error(err)) => err == formula_error_ref
      _ => false
    },
    content="true",
  )

  let sortby_cols = sortby_values(
    workbook,
    "Sheet1",
    [Expr::Number(0.0), Expr::Number(0.0)][:],
    [
      FormulaValue::List([
        FormulaValue::Number(30.0),
        FormulaValue::Number(10.0),
        FormulaValue::Number(20.0),
      ]),
      FormulaValue::List([
        FormulaValue::Number(2.0),
        FormulaValue::Number(3.0),
        FormulaValue::Number(1.0),
      ]),
    ][:],
    ctx,
  )
  let sortby_cols_ok = match sortby_cols {
    FormulaValue::List(list) =>
      list.length() == 3 &&
      wb_number_eq(list[0], 20.0) &&
      wb_number_eq(list[1], 30.0) &&
      wb_number_eq(list[2], 10.0)
    _ => false
  }
  inspect(sortby_cols_ok, content="true")

  inspect(
    wb_is_error(
      sort_values(
        workbook,
        "Sheet1",
        [
          Expr::Number(0.0),
          Expr::Number(0.0),
        ][:],
        [
          FormulaValue::List([
            FormulaValue::Number(1.0),
            FormulaValue::Number(2.0),
          ]),
          FormulaValue::String("bad-index"),
        ][:],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    wb_is_error(
      sort_values(
        workbook,
        "Sheet1",
        [
          Expr::Number(0.0),
          Expr::Number(0.0),
          Expr::Number(0.0),
        ][:],
        [
          FormulaValue::List([
            FormulaValue::Number(1.0),
            FormulaValue::Number(2.0),
          ]),
          FormulaValue::Number(1.0),
          FormulaValue::String("bad-order"),
        ][:],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    wb_is_error(
      sort_values(
        workbook,
        "Sheet1",
        [
          Expr::Number(0.0),
          Expr::Number(0.0),
          Expr::Number(0.0),
          Expr::Number(0.0),
        ][:],
        [
          FormulaValue::List([
            FormulaValue::Number(1.0),
            FormulaValue::Number(2.0),
          ]),
          FormulaValue::Number(1.0),
          FormulaValue::Number(1.0),
          FormulaValue::String("bad-by-col"),
        ][:],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    wb_is_error(filter_range_values(matrix_range, vec_range, None), formula_error_value),
    content="true",
  )
  inspect(
    wb_is_error(filter_range_values(vec_range, matrix_range, None), formula_error_value),
    content="true",
  )
  inspect(
    wb_is_error(
      filter_range_values(
        vec_range,
        wb_range([FormulaValue::String("bad"), Bool(true)], 1, 2),
        None,
      ),
      formula_error_value,
    ),
    content="true",
  )

  inspect(
    wb_is_error(
      tocol_torow_values(
        workbook,
        "Sheet1",
        [Expr::Number(0.0), Expr::Number(0.0)][:],
        [
          FormulaValue::List([FormulaValue::Number(1.0)]),
          FormulaValue::String("bad-ignore"),
        ][:],
        ctx,
        true,
      ),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    wb_is_error(
      tocol_torow_values(
        workbook,
        "Sheet1",
        [Expr::Number(0.0), Expr::Number(0.0), Expr::Number(0.0)][:],
        [
          FormulaValue::List([FormulaValue::Number(1.0)]),
          FormulaValue::Number(0.0),
          FormulaValue::String("bad-scan"),
        ][:],
        ctx,
        false,
      ),
      formula_error_value,
    ),
    content="true",
  )
}
