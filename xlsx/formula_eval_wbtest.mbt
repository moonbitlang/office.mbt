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

  let range = wb_range(
    [Number(1.0), Number(2.0), Number(3.0), Number(4.0)],
    2,
    2,
  )
  inspect(range_column(range, -1) is None, content="true")
  inspect(range_row(range, 2) is None, content="true")
}

///|
test "formula eval wb: munit and transpose guard paths" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let ctx = CalcContext::new()

  let munit_bad_arity = munit_range_values_from_expr(
    workbook,
    "Sheet1",
    [],
    ctx,
  )
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
    workbook,
    "Sheet1",
    [String("not-number")],
    ctx,
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
    workbook,
    "Sheet1",
    [],
    ctx,
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
    workbook,
    "Sheet1",
    [Number(7.0)],
    ctx,
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
      Ok(matrix) =>
        matrix.length() == 1 && matrix[0].length() == 1 && matrix[0][0] == 1.0
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
      sequence_values(
        [
          FormulaValue::Number(1.0),
          FormulaValue::Number(1.0),
          FormulaValue::String("bad-start"),
        ][:],
      ),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    wb_is_error(
      sequence_values(
        [
          FormulaValue::Number(1.0),
          FormulaValue::Number(1.0),
          FormulaValue::Number(1.0),
          FormulaValue::String("bad-step"),
        ][:],
      ),
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

  let rand_float = randarray_values(
    [
      FormulaValue::Number(1.0),
      FormulaValue::Number(2.0),
      FormulaValue::Number(0.0),
      FormulaValue::Number(1.0),
      FormulaValue::Bool(false),
    ][:],
  )
  let rand_float_ok = match rand_float {
    FormulaValue::List(list) => list.length() == 2 && wb_is_number(list[0])
    _ => false
  }
  inspect(rand_float_ok, content="true")
  inspect(
    wb_is_error(
      randarray_values([FormulaValue::String("bad-rows")][:]),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    wb_is_error(
      randarray_values(
        [FormulaValue::Number(1.0), FormulaValue::String("bad-cols")][:],
      ),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    wb_is_error(
      randarray_values(
        [
          FormulaValue::Number(1.0),
          FormulaValue::Number(1.0),
          FormulaValue::String("bad-min"),
        ][:],
      ),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    wb_is_error(
      randarray_values(
        [
          FormulaValue::Number(1.0),
          FormulaValue::Number(1.0),
          FormulaValue::Number(0.0),
          FormulaValue::String("bad-max"),
        ][:],
      ),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    wb_is_error(
      randarray_values(
        [
          FormulaValue::Number(1.0),
          FormulaValue::Number(1.0),
          FormulaValue::Number(0.0),
          FormulaValue::Number(1.0),
          FormulaValue::String("bad-whole"),
        ][:],
      ),
      formula_error_value,
    ),
    content="true",
  )

  let range = wb_range(
    [Number(1.0), Number(2.0), Number(3.0), Number(4.0)],
    2,
    2,
  )
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
      wrap_values(workbook, "Sheet1", [base_expr][:], [base_list][:], ctx, true),
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
  let matrix_range = wb_range(
    [Number(1.0), Number(2.0), Number(3.0), Number(4.0)],
    2,
    2,
  )

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
        [Expr::Number(0.0), Expr::Number(0.0)][:],
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
        [Expr::Number(0.0), Expr::Number(0.0), Expr::Number(0.0)][:],
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
    wb_is_error(
      filter_range_values(matrix_range, vec_range, None),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    wb_is_error(
      filter_range_values(vec_range, matrix_range, None),
      formula_error_value,
    ),
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

///|
fn wb_shape_eq(shape : (Int, Int)?, rows : Int, cols : Int) -> Bool {
  match shape {
    Some((shape_rows, shape_cols)) => shape_rows == rows && shape_cols == cols
    None => false
  }
}

///|
fn wb_shape_none(shape : (Int, Int)?) -> Bool {
  match shape {
    None => true
    _ => false
  }
}

///|
fn wb_shape_some(shape : (Int, Int)?) -> Bool {
  match shape {
    Some(_) => true
    None => false
  }
}

///|
fn wb_shape(
  workbook : Workbook,
  sheet_name : String,
  expr : Expr,
) -> (Int, Int)? {
  array_shape_from_expr(workbook, sheet_name, expr, CalcContext::new()) catch {
    _ => None
  }
}

///|
test "formula eval wb: shape helper branches part 3" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))

  inspect(
    wb_shape_none(array_shape_binary(Some((1, 2)), Some((2, 1)))),
    content="true",
  )
  inspect(wb_shape_none(array_shape_binary(None, Some((1, 1)))), content="true")

  inspect(
    effective_range_bounds(workbook, "Sheet1", 3, 1, 1, 1),
    content="(3, 1, 1, 1)",
  )
  inspect(
    effective_range_bounds(workbook, "Missing", 1, 5000, 1, 4),
    content="(1, 5000, 1, 4)",
  )
  inspect(
    effective_range_bounds(workbook, "Sheet1", 1, 5000, 1, 4),
    content="(1, 2500, 1, 4)",
  )
  inspect(
    effective_range_bounds(workbook, "Sheet1", 1, 4, 1, 5000),
    content="(1, 4, 1, 2500)",
  )

  let empty_values : Array[FormulaValue] = []
  let empty_list_range = range_from_expr_or_value(
    workbook,
    "Sheet1",
    Expr::Number(1.0),
    FormulaValue::List(empty_values),
    CalcContext::new(),
  )
  inspect(empty_list_range.rows, content="1")
  inspect(empty_list_range.cols, content="1")
  inspect(
    match empty_list_range.values[0] {
      Empty => true
      _ => false
    },
    content="true",
  )

  let transpose_bad = range_from_expr_or_value(
    workbook,
    "Sheet1",
    Expr::FuncCall("TRANSPOSE", [Expr::Number(1.0), Expr::Number(2.0)]),
    FormulaValue::List([FormulaValue::Number(1.0)]),
    CalcContext::new(),
  )
  inspect(transpose_bad.rows, content="1")
  inspect(transpose_bad.cols, content="1")
  inspect(
    match transpose_bad.values[0] {
      Error(err) => err == formula_error_value
      _ => false
    },
    content="true",
  )

  let seq_mismatch = range_from_expr_or_value(
    workbook,
    "Sheet1",
    Expr::FuncCall("SEQUENCE", [Expr::Number(1.0), Expr::Number(2.0)]),
    FormulaValue::List([FormulaValue::Number(1.0)]),
    CalcContext::new(),
  )
  inspect(seq_mismatch.rows, content="1")
  inspect(seq_mismatch.cols, content="1")

  let seq_shape_none = range_from_expr_or_value(
    workbook,
    "Sheet1",
    Expr::FuncCall("SEQUENCE", [Expr::String("bad")]),
    FormulaValue::List([FormulaValue::Number(1.0)]),
    CalcContext::new(),
  )
  inspect(seq_shape_none.rows, content="1")
  inspect(seq_shape_none.cols, content="1")

  inspect(
    wb_is_error(
      eval_numeric_binary(BinaryOp::Concat, Number(1.0), Number(2.0)),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    wb_is_error(
      eval_numeric_binary(BinaryOp::Add, String("bad"), Number(2.0)),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    wb_is_error(
      eval_numeric_binary(BinaryOp::Add, Number(1.0), String("bad")),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    wb_is_error(
      eval_list_binary(BinaryOp::Add, Number(1.0), Number(2.0)),
      formula_error_value,
    ),
    content="true",
  )
}

///|
test "formula eval wb: array shape dispatcher guards part 3" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  ignore(workbook.add_sheet("Data"))
  let sheet1 = match workbook.sheet("Sheet1") {
    Some(value) => value
    None => {
      inspect(false, content="true")
      return
    }
  }
  sheet1.set_cell_value("A1", Numeric(1.0))
  sheet1.set_cell_value("B1", Numeric(2.0))
  sheet1.set_cell_value("A2", Numeric(3.0))
  sheet1.set_cell_value("B2", Numeric(4.0))
  sheet1.set_cell_value("A3", Numeric(5.0))
  sheet1.set_cell_value("D1", Error(formula_error_ref))
  sheet1.set_cell_formula("A4", "SEQUENCE(2,3)")
  sheet1.set_cell_formula("A5", "1+")

  inspect(
    wb_shape_eq(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::Unary(UnaryOp::Plus, Expr::Number(1.0)),
      ),
      1,
      1,
    ),
    content="true",
  )
  inspect(
    wb_shape_eq(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::List([Expr::Number(1.0), Expr::Number(2.0), Expr::Number(3.0)]),
      ),
      1,
      3,
    ),
    content="true",
  )

  inspect(
    wb_shape_none(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::FuncCall("TRANSPOSE", [Expr::Number(1.0), Expr::Number(2.0)]),
      ),
    ),
    content="true",
  )
  inspect(
    wb_shape_none(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::FuncCall("_XLFN.MUNIT", [Expr::String("bad")]),
      ),
    ),
    content="true",
  )
  inspect(
    wb_shape_none(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::FuncCall("MUNIT", [Expr::Number(2.0), Expr::Number(3.0)]),
      ),
    ),
    content="true",
  )
  inspect(
    wb_shape_none(wb_shape(workbook, "Sheet1", Expr::FuncCall("SEQUENCE", []))),
    content="true",
  )
  inspect(
    wb_shape_none(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::FuncCall("SEQUENCE", [Expr::String("bad")]),
      ),
    ),
    content="true",
  )
  inspect(
    wb_shape_none(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::FuncCall("SEQUENCE", [Expr::Number(1.0), Expr::String("bad")]),
      ),
    ),
    content="true",
  )
  inspect(
    wb_shape_eq(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::FuncCall("SEQUENCE", [Expr::Number(2.0)]),
      ),
      2,
      1,
    ),
    content="true",
  )
  inspect(
    wb_shape_none(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::FuncCall("SEQUENCE", [Expr::Number(0.0), Expr::Number(1.0)]),
      ),
    ),
    content="true",
  )

  inspect(
    wb_shape_none(wb_shape(workbook, "Sheet1", Expr::FuncCall("RANDARRAY", []))),
    content="true",
  )
  inspect(
    wb_shape_none(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::FuncCall("RANDARRAY", [Expr::String("bad")]),
      ),
    ),
    content="true",
  )
  inspect(
    wb_shape_none(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::FuncCall("RANDARRAY", [Expr::Number(1.0), Expr::String("bad")]),
      ),
    ),
    content="true",
  )
  inspect(
    wb_shape_none(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::FuncCall("RANDARRAY", [Expr::Number(0.0), Expr::Number(1.0)]),
      ),
    ),
    content="true",
  )
  inspect(
    wb_shape_eq(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::FuncCall("RANDARRAY", [Expr::Number(2.0), Expr::Number(3.0)]),
      ),
      2,
      3,
    ),
    content="true",
  )
  inspect(
    wb_shape_none(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::FuncCall("RANDARRAY", [
          Expr::Number(1.0),
          Expr::Number(1.0),
          Expr::Number(0.0),
          Expr::Number(1.0),
          Expr::Bool(true),
          Expr::Number(7.0),
        ]),
      ),
    ),
    content="true",
  )

  inspect(
    wb_shape_eq(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::FuncCall("MINVERSE", [Expr::Range("", "A1", "B2")]),
      ),
      2,
      2,
    ),
    content="true",
  )
  inspect(
    wb_shape_none(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::FuncCall("MINVERSE", [Expr::Range("", "A1", "B3")]),
      ),
    ),
    content="true",
  )
  inspect(
    wb_shape_none(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::FuncCall("MINVERSE", [
          Expr::Range("", "A1", "B2"),
          Expr::Number(1.0),
        ]),
      ),
    ),
    content="true",
  )
  inspect(
    wb_shape_none(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::FuncCall("MMULT", [Expr::Range("", "A1", "B2")]),
      ),
    ),
    content="true",
  )
  inspect(
    wb_shape_none(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::FuncCall("MMULT", [
          Expr::Range("", "A1", "B2"),
          Expr::Range("", "A1", "A1"),
        ]),
      ),
    ),
    content="true",
  )

  inspect(
    wb_shape_none(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::FuncCall("TEXTSPLIT", [Expr::Cell("", "D1"), Expr::String(",")]),
      ),
    ),
    content="true",
  )
  inspect(
    wb_shape_none(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::FuncCall("TEXTSPLIT", [Expr::String("a,b"), Expr::Cell("", "D1")]),
      ),
    ),
    content="true",
  )
  inspect(
    wb_shape_none(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::FuncCall("TEXTSPLIT", [Expr::String("a,b"), Expr::String("")]),
      ),
    ),
    content="true",
  )
  inspect(
    wb_shape_none(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::FuncCall("TEXTSPLIT", [
          Expr::String("a,b"),
          Expr::String(","),
          Expr::Cell("", "D1"),
        ]),
      ),
    ),
    content="true",
  )
  inspect(
    wb_shape_none(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::FuncCall("TEXTSPLIT", [
          Expr::String("a,b"),
          Expr::String(","),
          Expr::String(""),
          Expr::String("bad"),
        ]),
      ),
    ),
    content="true",
  )
  inspect(
    wb_shape_none(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::FuncCall("TEXTSPLIT", [
          Expr::String("a,b"),
          Expr::String(","),
          Expr::String(""),
          Expr::Bool(false),
          Expr::String("bad"),
        ]),
      ),
    ),
    content="true",
  )
  inspect(
    wb_shape_none(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::FuncCall("TEXTSPLIT", [
          Expr::String("a,b"),
          Expr::String(","),
          Expr::String(""),
          Expr::Bool(false),
          Expr::Number(2.0),
        ]),
      ),
    ),
    content="true",
  )
  inspect(
    wb_shape_none(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::FuncCall("TEXTSPLIT", [
          Expr::String(""),
          Expr::String(","),
          Expr::String(""),
          Expr::Bool(true),
        ]),
      ),
    ),
    content="true",
  )
  inspect(
    wb_shape_eq(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::FuncCall("TEXTSPLIT", [Expr::String("a,b"), Expr::String(",")]),
      ),
      1,
      2,
    ),
    content="true",
  )
  inspect(
    wb_shape_none(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::FuncCall("TEXTSPLIT", [Expr::String("a,b")]),
      ),
    ),
    content="true",
  )

  inspect(
    wb_shape_none(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::FuncCall("FREQUENCY", [
          Expr::List([Expr::Number(1.0)]),
          Expr::Range("", "D1", "D1"),
        ]),
      ),
    ),
    content="true",
  )
  inspect(
    wb_shape_none(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::FuncCall("FREQUENCY", [Expr::List([Expr::Number(1.0)])]),
      ),
    ),
    content="true",
  )
  inspect(
    wb_shape_none(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::FuncCall("MODE.MULT", [Expr::Number(1.0)]),
      ),
    ),
    content="true",
  )
  inspect(
    wb_shape_some(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::FuncCall("MODE.MULT", [
          Expr::List([Expr::Number(1.0), Expr::Number(1.0), Expr::Number(2.0)]),
        ]),
      ),
    ),
    content="true",
  )
  inspect(
    wb_shape_none(wb_shape(workbook, "Sheet1", Expr::FuncCall("MODE.MULT", []))),
    content="true",
  )

  inspect(
    wb_shape_none(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::FuncCall("ANCHORARRAY", [Expr::Number(1.0)]),
      ),
    ),
    content="true",
  )
  inspect(
    wb_shape_none(
      wb_shape(workbook, "Sheet1", Expr::FuncCall("ANCHORARRAY", [])),
    ),
    content="true",
  )
  inspect(
    wb_shape_none(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::FuncCall("ANCHORARRAY", [Expr::Cell("Missing", "A1")]),
      ),
    ),
    content="true",
  )
  inspect(
    wb_shape_none(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::FuncCall("ANCHORARRAY", [Expr::Cell("", "bad_ref")]),
      ),
    ),
    content="true",
  )
  inspect(
    wb_shape_eq(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::FuncCall("ANCHORARRAY", [Expr::Cell("Sheet1", "A1")]),
      ),
      1,
      1,
    ),
    content="true",
  )
  inspect(
    wb_shape_none(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::FuncCall("ANCHORARRAY", [Expr::Cell("", "A5")]),
      ),
    ),
    content="true",
  )
  inspect(
    wb_shape_eq(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::FuncCall("ANCHORARRAY", [Expr::Cell("", "A4")]),
      ),
      2,
      3,
    ),
    content="true",
  )

  inspect(
    wb_shape_none(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::FuncCall("INDIRECT", [Expr::Bool(true)]),
      ),
    ),
    content="true",
  )
  inspect(
    wb_shape_none(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::FuncCall("INDIRECT", [Expr::String("A1"), Expr::String("bad")]),
      ),
    ),
    content="true",
  )
  inspect(
    wb_shape_eq(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::FuncCall("INDIRECT", [Expr::String("Data!A1:B2")]),
      ),
      2,
      2,
    ),
    content="true",
  )
  inspect(
    wb_shape_none(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::FuncCall("INDIRECT", [Expr::String("bad!:A1")]),
      ),
    ),
    content="true",
  )
  inspect(
    wb_shape_none(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::FuncCall("INDIRECT", [Expr::String("A1:bad!")]),
      ),
    ),
    content="true",
  )
  inspect(
    wb_shape_eq(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::FuncCall("INDIRECT", [Expr::String("A1")]),
      ),
      1,
      1,
    ),
    content="true",
  )
  inspect(
    wb_shape_some(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::FuncCall("INDIRECT", [Expr::String("A")]),
      ),
    ),
    content="true",
  )
  inspect(
    wb_shape_none(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::FuncCall("INDIRECT", [Expr::String("bad!")]),
      ),
    ),
    content="true",
  )
  inspect(
    wb_shape_eq(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::FuncCall("INDIRECT", [
          Expr::String("R1C1:R2C2"),
          Expr::Bool(false),
        ]),
      ),
      2,
      2,
    ),
    content="true",
  )
  inspect(
    wb_shape_none(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::FuncCall("INDIRECT", [Expr::String("BAD:R2C2"), Expr::Bool(false)]),
      ),
    ),
    content="true",
  )
  inspect(
    wb_shape_none(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::FuncCall("INDIRECT", [Expr::String("R1C1:BAD"), Expr::Bool(false)]),
      ),
    ),
    content="true",
  )
  inspect(
    wb_shape_none(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::FuncCall("INDIRECT", [
          Expr::String("R0C1:R1C1"),
          Expr::Bool(false),
        ]),
      ),
    ),
    content="true",
  )
  inspect(
    wb_shape_none(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::FuncCall("INDIRECT", [
          Expr::String("R1C1:R0C1"),
          Expr::Bool(false),
        ]),
      ),
    ),
    content="true",
  )
  inspect(
    wb_shape_eq(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::FuncCall("INDIRECT", [Expr::String("R1C1"), Expr::Bool(false)]),
      ),
      1,
      1,
    ),
    content="true",
  )
  inspect(
    wb_shape_none(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::FuncCall("INDIRECT", [Expr::String("BAD"), Expr::Bool(false)]),
      ),
    ),
    content="true",
  )
  inspect(
    wb_shape_none(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::FuncCall("INDIRECT", [
          Expr::String("A1"),
          Expr::Bool(false),
          Expr::Number(1.0),
        ]),
      ),
    ),
    content="true",
  )
}

///|
test "formula eval wb: array shape advanced function branches part 3" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let sheet = match workbook.sheet("Sheet1") {
    Some(value) => value
    None => {
      inspect(false, content="true")
      return
    }
  }
  sheet.set_cell_value("A1", Numeric(1.0))
  sheet.set_cell_value("A2", Numeric(2.0))
  sheet.set_cell_value("A3", Numeric(3.0))
  sheet.set_cell_value("B1", Numeric(2.0))
  sheet.set_cell_value("B2", Numeric(4.0))
  sheet.set_cell_value("B3", Numeric(6.0))
  sheet.set_cell_value("C1", Error(formula_error_ref))

  inspect(
    wb_shape_none(wb_shape(workbook, "Sheet1", Expr::FuncCall("TREND", []))),
    content="true",
  )
  inspect(
    wb_shape_none(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::FuncCall("TREND", [Expr::String("bad")]),
      ),
    ),
    content="true",
  )
  inspect(
    wb_shape_none(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::FuncCall("TREND", [
          Expr::Range("", "A1", "A3"),
          Expr::String("bad"),
        ]),
      ),
    ),
    content="true",
  )
  inspect(
    wb_shape_none(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::FuncCall("TREND", [
          Expr::Range("", "A1", "A3"),
          Expr::Range("", "A1", "A3"),
          Expr::String("bad"),
        ]),
      ),
    ),
    content="true",
  )
  inspect(
    wb_shape_none(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::FuncCall("TREND", [
          Expr::Range("", "A1", "A3"),
          Expr::Range("", "A1", "A3"),
          Expr::Range("", "A1", "A3"),
          Expr::String("bad"),
        ]),
      ),
    ),
    content="true",
  )
  inspect(
    wb_shape_none(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::FuncCall("TREND", [
          Expr::Range("", "A1", "A3"),
          Expr::Range("", "A1", "A2"),
        ]),
      ),
    ),
    content="true",
  )

  inspect(
    wb_shape_none(wb_shape(workbook, "Sheet1", Expr::FuncCall("SORT", []))),
    content="true",
  )
  inspect(
    wb_shape_eq(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::FuncCall("SORTBY", [
          Expr::List([Expr::Number(3.0), Expr::Number(1.0), Expr::Number(2.0)]),
          Expr::List([
            Expr::Number(30.0),
            Expr::Number(10.0),
            Expr::Number(20.0),
          ]),
        ]),
      ),
      1,
      3,
    ),
    content="true",
  )
  inspect(
    wb_shape_none(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::FuncCall("SORTBY", [Expr::List([Expr::Number(1.0)])]),
      ),
    ),
    content="true",
  )

  inspect(
    wb_shape_none(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::FuncCall("UNIQUE", [
          Expr::List([Expr::Number(1.0), Expr::Number(1.0)]),
          Expr::String("bad"),
        ]),
      ),
    ),
    content="true",
  )
  inspect(
    wb_shape_none(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::FuncCall("UNIQUE", [
          Expr::List([Expr::Number(1.0), Expr::Number(1.0)]),
          Expr::Bool(false),
          Expr::String("bad"),
        ]),
      ),
    ),
    content="true",
  )
  inspect(
    wb_shape_none(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::FuncCall("UNIQUE", [Expr::Range("", "C1", "C1")]),
      ),
    ),
    content="true",
  )
  inspect(
    wb_shape_none(wb_shape(workbook, "Sheet1", Expr::FuncCall("UNIQUE", []))),
    content="true",
  )

  inspect(
    wb_shape_none(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::FuncCall("FILTER", [
          Expr::FuncCall("SEQUENCE", [Expr::Number(2.0), Expr::Number(2.0)]),
          Expr::List([Expr::Bool(true), Expr::Bool(false)]),
        ]),
      ),
    ),
    content="true",
  )
  inspect(
    wb_shape_eq(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::FuncCall("FILTER", [
          Expr::List([Expr::Number(1.0), Expr::Number(2.0)]),
          Expr::List([Expr::Bool(true), Expr::Bool(false)]),
        ]),
      ),
      1,
      1,
    ),
    content="true",
  )
  inspect(
    wb_shape_none(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::FuncCall("FILTER", [
          Expr::List([Expr::Number(1.0), Expr::Number(2.0)]),
          Expr::List([Expr::String("bad"), Expr::Bool(true)]),
        ]),
      ),
    ),
    content="true",
  )
  inspect(
    wb_shape_eq(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::FuncCall("FILTER", [
          Expr::List([Expr::Number(1.0), Expr::Number(2.0)]),
          Expr::List([Expr::Bool(false), Expr::Bool(false)]),
          Expr::Number(99.0),
        ]),
      ),
      1,
      1,
    ),
    content="true",
  )
  inspect(
    wb_shape_none(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::FuncCall("FILTER", [Expr::List([Expr::Number(1.0)])]),
      ),
    ),
    content="true",
  )

  inspect(
    wb_shape_none(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::FuncCall("XLOOKUP", [
          Expr::Number(1.0),
          Expr::List([Expr::Number(1.0)]),
        ]),
      ),
    ),
    content="true",
  )
  inspect(
    wb_shape_none(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::FuncCall("XLOOKUP", [
          Expr::Number(1.0),
          Expr::FuncCall("SEQUENCE", [Expr::Number(2.0), Expr::Number(2.0)]),
          Expr::List([Expr::Number(1.0), Expr::Number(2.0)]),
        ]),
      ),
    ),
    content="true",
  )
  inspect(
    wb_shape_none(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::FuncCall("XLOOKUP", [
          Expr::Number(1.0),
          Expr::List([Expr::Number(1.0), Expr::Number(2.0)]),
          Expr::List([Expr::Number(1.0), Expr::Number(2.0), Expr::Number(3.0)]),
        ]),
      ),
    ),
    content="true",
  )
  inspect(
    wb_shape_eq(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::FuncCall("XLOOKUP", [
          Expr::Number(1.0),
          Expr::List([Expr::Number(1.0), Expr::Number(2.0)]),
          Expr::List([Expr::Number(10.0), Expr::Number(20.0)]),
        ]),
      ),
      1,
      1,
    ),
    content="true",
  )
  inspect(
    wb_shape_none(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::FuncCall("XLOOKUP", [
          Expr::Number(1.0),
          Expr::FuncCall("TRANSPOSE", [
            Expr::List([Expr::Number(1.0), Expr::Number(2.0)]),
          ]),
          Expr::List([Expr::Number(1.0), Expr::Number(2.0)]),
        ]),
      ),
    ),
    content="true",
  )
  inspect(
    wb_shape_eq(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::FuncCall("XLOOKUP", [
          Expr::Number(1.0),
          Expr::FuncCall("TRANSPOSE", [
            Expr::List([Expr::Number(1.0), Expr::Number(2.0)]),
          ]),
          Expr::FuncCall("TRANSPOSE", [
            Expr::List([Expr::Number(10.0), Expr::Number(20.0)]),
          ]),
        ]),
      ),
      1,
      1,
    ),
    content="true",
  )
  inspect(
    wb_shape_eq(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::FuncCall("XLOOKUP", [
          Expr::Number(1.0),
          Expr::FuncCall("TRANSPOSE", [
            Expr::List([Expr::Number(1.0), Expr::Number(2.0)]),
          ]),
          Expr::FuncCall("SEQUENCE", [Expr::Number(2.0), Expr::Number(2.0)]),
        ]),
      ),
      1,
      2,
    ),
    content="true",
  )

  inspect(
    wb_shape_none(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::FuncCall("TAKE", [
          Expr::List([Expr::Number(1.0)]),
          Expr::String("bad"),
        ]),
      ),
    ),
    content="true",
  )
  inspect(
    wb_shape_none(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::FuncCall("TAKE", [
          Expr::List([Expr::Number(1.0)]),
          Expr::Number(1.0),
          Expr::String("bad"),
        ]),
      ),
    ),
    content="true",
  )
  inspect(
    wb_shape_eq(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::FuncCall("TAKE", [
          Expr::List([Expr::Number(1.0), Expr::Number(2.0)]),
          Expr::Number(0.0),
        ]),
      ),
      1,
      2,
    ),
    content="true",
  )
  inspect(
    wb_shape_eq(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::FuncCall("TAKE", [
          Expr::List([Expr::Number(1.0), Expr::Number(2.0)]),
          Expr::Number(1.0),
          Expr::Number(0.0),
        ]),
      ),
      1,
      2,
    ),
    content="true",
  )
  inspect(
    wb_shape_none(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::FuncCall("TAKE", [
          Expr::List([Expr::Number(1.0), Expr::Number(2.0)]),
          Expr::Number(3.0),
        ]),
      ),
    ),
    content="true",
  )
  inspect(
    wb_shape_none(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::FuncCall("TAKE", [Expr::List([Expr::Number(1.0)])]),
      ),
    ),
    content="true",
  )

  inspect(
    wb_shape_none(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::FuncCall("DROP", [
          Expr::List([Expr::Number(1.0)]),
          Expr::String("bad"),
        ]),
      ),
    ),
    content="true",
  )
  inspect(
    wb_shape_none(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::FuncCall("DROP", [
          Expr::List([Expr::Number(1.0)]),
          Expr::Number(1.0),
          Expr::String("bad"),
        ]),
      ),
    ),
    content="true",
  )
  inspect(
    wb_shape_none(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::FuncCall("DROP", [
          Expr::List([Expr::Number(1.0), Expr::Number(2.0)]),
          Expr::Number(2.0),
        ]),
      ),
    ),
    content="true",
  )
  inspect(
    wb_shape_eq(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::FuncCall("DROP", [
          Expr::List([Expr::Number(1.0), Expr::Number(2.0)]),
          Expr::Number(0.0),
        ]),
      ),
      1,
      2,
    ),
    content="true",
  )
  inspect(
    wb_shape_none(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::FuncCall("DROP", [Expr::List([Expr::Number(1.0)])]),
      ),
    ),
    content="true",
  )

  inspect(
    wb_shape_none(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::FuncCall("CHOOSECOLS", [
          Expr::List([Expr::Number(1.0), Expr::Number(2.0)]),
          Expr::Number(0.0),
        ]),
      ),
    ),
    content="true",
  )
  inspect(
    wb_shape_none(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::FuncCall("CHOOSECOLS", [Expr::List([Expr::Number(1.0)])]),
      ),
    ),
    content="true",
  )
  inspect(
    wb_shape_none(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::FuncCall("CHOOSEROWS", [
          Expr::FuncCall("TRANSPOSE", [
            Expr::List([Expr::Number(1.0), Expr::Number(2.0)]),
          ]),
          Expr::Number(0.0),
        ]),
      ),
    ),
    content="true",
  )
  inspect(
    wb_shape_none(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::FuncCall("CHOOSEROWS", [Expr::List([Expr::Number(1.0)])]),
      ),
    ),
    content="true",
  )

  inspect(
    wb_shape_none(wb_shape(workbook, "Sheet1", Expr::FuncCall("HSTACK", []))),
    content="true",
  )
  inspect(
    wb_shape_none(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::FuncCall("EXPAND", [
          Expr::List([Expr::Number(1.0)]),
          Expr::String("bad"),
        ]),
      ),
    ),
    content="true",
  )
  inspect(
    wb_shape_none(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::FuncCall("EXPAND", [
          Expr::List([Expr::Number(1.0)]),
          Expr::Number(1.0),
          Expr::String("bad"),
        ]),
      ),
    ),
    content="true",
  )
  inspect(
    wb_shape_none(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::FuncCall("EXPAND", [
          Expr::List([Expr::Number(1.0), Expr::Number(2.0)]),
          Expr::Number(1.0),
          Expr::Number(1.0),
        ]),
      ),
    ),
    content="true",
  )
  inspect(
    wb_shape_none(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::FuncCall("EXPAND", [Expr::List([Expr::Number(1.0)])]),
      ),
    ),
    content="true",
  )

  inspect(
    wb_shape_none(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::FuncCall("WRAPROWS", [Expr::List([Expr::Number(1.0)])]),
      ),
    ),
    content="true",
  )
  inspect(
    wb_shape_none(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::FuncCall("WRAPROWS", [
          Expr::FuncCall("SEQUENCE", [Expr::Number(2.0), Expr::Number(2.0)]),
          Expr::Number(2.0),
        ]),
      ),
    ),
    content="true",
  )
  inspect(
    wb_shape_none(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::FuncCall("WRAPROWS", [
          Expr::List([Expr::Number(1.0)]),
          Expr::String("bad"),
        ]),
      ),
    ),
    content="true",
  )
  inspect(
    wb_shape_none(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::FuncCall("WRAPROWS", [
          Expr::List([Expr::Number(1.0)]),
          Expr::Number(0.0),
        ]),
      ),
    ),
    content="true",
  )
  inspect(
    wb_shape_eq(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::FuncCall("WRAPROWS", [
          Expr::List([Expr::Number(1.0), Expr::Number(2.0), Expr::Number(3.0)]),
          Expr::Number(2.0),
        ]),
      ),
      2,
      2,
    ),
    content="true",
  )
  inspect(
    wb_shape_eq(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::FuncCall("WRAPCOLS", [
          Expr::List([Expr::Number(1.0), Expr::Number(2.0), Expr::Number(3.0)]),
          Expr::Number(2.0),
        ]),
      ),
      2,
      2,
    ),
    content="true",
  )

  inspect(
    wb_shape_none(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::FuncCall("TOCOL", [
          Expr::List([Expr::Number(1.0)]),
          Expr::String("bad"),
        ]),
      ),
    ),
    content="true",
  )
  inspect(
    wb_shape_none(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::FuncCall("TOCOL", [
          Expr::List([Expr::Number(1.0)]),
          Expr::Number(4.0),
        ]),
      ),
    ),
    content="true",
  )
  inspect(
    wb_shape_none(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::FuncCall("TOCOL", [
          Expr::List([Expr::Number(1.0)]),
          Expr::Number(0.0),
          Expr::String("bad"),
        ]),
      ),
    ),
    content="true",
  )
  inspect(
    wb_shape_none(
      wb_shape(
        workbook,
        "Sheet1",
        Expr::FuncCall("TOCOL", [
          Expr::List([Expr::Number(1.0)]),
          Expr::Number(0.0),
          Expr::Bool(false),
          Expr::Number(1.0),
        ]),
      ),
    ),
    content="true",
  )
}

///|
test "formula eval wb: date serial and weekend helper branches part 4" {
  inspect(
    match value_as_date_serial(Bool(true)) {
      Ok(num) => num == 1.0
      _ => false
    },
    content="true",
  )
  inspect(
    match value_as_date_serial(String("2024-01-01")) {
      Ok(num) => num > 45000.0
      _ => false
    },
    content="true",
  )
  inspect(
    match value_as_date_serial(String("-1")) {
      Err(Error(err)) => err == formula_error_num
      _ => false
    },
    content="true",
  )
  inspect(
    match value_as_date_serial(String("12.5")) {
      Ok(num) => num == 12.5
      _ => false
    },
    content="true",
  )
  inspect(
    match value_as_date_serial(String("not-a-date")) {
      Err(Error(err)) => err == formula_error_value
      _ => false
    },
    content="true",
  )
  inspect(
    match value_as_date_serial(Error(formula_error_na)) {
      Err(Error(err)) => err == formula_error_na
      _ => false
    },
    content="true",
  )

  inspect(date_parts_from_serial(-1.0) is None, content="true")
  inspect(
    match date_parts_from_value(Error(formula_error_ref)) {
      Err(Error(err)) => err == formula_error_ref
      _ => false
    },
    content="true",
  )

  inspect(days_in_year(2024), content="366")
  inspect(days_in_year(2023), content="365")
  inspect(
    match weekday_monday1(-1, 1, 1) {
      value => value >= 1 && value <= 7
    },
    content="true",
  )
  inspect(weekday_sun1(2024, 6, 23), content="1")
  inspect(iso_week_number(10000, 1, 1) is None, content="true")
  inspect(
    match iso_week_number(9999, 12, 31) {
      Some(value) => value > 0
      None => false
    },
    content="true",
  )

  inspect(
    match weekend_mask_from_value(Number(2.0)) {
      Ok((mask, workdays)) => mask[6] == 1 && mask[0] == 1 && workdays == 5
      _ => false
    },
    content="true",
  )
  inspect(
    match weekend_mask_from_value(Number(12.0)) {
      Ok((mask, workdays)) => mask[0] == 1 && workdays == 6
      _ => false
    },
    content="true",
  )
  inspect(
    match weekend_mask_from_value(String("0101010")) {
      Ok((mask, workdays)) =>
        mask[0] == 0 &&
        mask[1] == 1 &&
        mask[2] == 0 &&
        mask[3] == 1 &&
        mask[4] == 0 &&
        mask[5] == 1 &&
        mask[6] == 0 &&
        workdays == 4
      _ => false
    },
    content="true",
  )
  inspect(
    match weekend_mask_from_value(String("01010x0")) {
      Err(Error(err)) => err == formula_error_value
      _ => false
    },
    content="true",
  )
  inspect(
    match weekend_mask_from_value(String("2")) {
      Ok((mask, workdays)) => mask[6] == 1 && mask[0] == 1 && workdays == 5
      _ => false
    },
    content="true",
  )
  inspect(
    match weekend_mask_from_value(String("abc")) {
      Err(Error(err)) => err == formula_error_value
      _ => false
    },
    content="true",
  )
  inspect(
    match weekend_mask_from_value(Number(99.0)) {
      Err(Error(err)) => err == formula_error_value
      _ => false
    },
    content="true",
  )
  inspect(
    match weekend_mask_from_value(Error(formula_error_na)) {
      Err(Error(err)) => err == formula_error_na
      _ => false
    },
    content="true",
  )

  let weekend_mask : Array[Int] = [0, 0, 0, 0, 0, 1, 1]
  inspect(is_workday_mask(weekend_mask, -1.0), content="false")
}
