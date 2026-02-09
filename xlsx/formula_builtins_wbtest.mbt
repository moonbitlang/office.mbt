///|
fn is_formula_error(value : FormulaValue, expected : String) -> Bool {
  match value {
    Error(err) => err == expected
    _ => false
  }
}

///|
fn is_formula_number(value : FormulaValue, expected : Double) -> Bool {
  match value {
    Number(num) => num == expected
    _ => false
  }
}

///|
test "formula builtins wb: row column and formulatxt guards" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let ctx = CalcContext::new()

  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "ROW", [][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "ROW",
        [Expr::Number(1.0), Expr::Number(2.0)][:],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "COLUMN", [][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "COLUMN", [Expr::String("x")][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(
        workbook,
        "Sheet1",
        "COLUMN",
        [Expr::Number(1.0), Expr::Number(2.0)][:],
        ctx,
      ),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "ROWS", [Expr::Bool(true)][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "COLUMNS", [Expr::Bool(true)][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "COLUMNS", [][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
  inspect(
    is_formula_error(
      eval_function(workbook, "Sheet1", "FORMULATEXT", [][:], ctx),
      formula_error_value,
    ),
    content="true",
  )
}

///|
test "formula builtins wb: percentile inc k guards" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let ctx = CalcContext::new()

  let out_of_range = eval_function(
    workbook,
    "Sheet1",
    "PERCENTILE.INC",
    [Expr::Number(1.0), Expr::Number(2.0)][:],
    ctx,
  )
  inspect(is_formula_error(out_of_range, formula_error_na), content="true")

  let bad_k = eval_function(
    workbook,
    "Sheet1",
    "PERCENTILE.INC",
    [Expr::Number(1.0), Expr::String("bad")][:],
    ctx,
  )
  inspect(is_formula_error(bad_k, formula_error_value), content="true")
}

///|
test "formula builtins wb: quartile rank and rounding guard paths" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let ctx = CalcContext::new()

  let quartile_bad = eval_function(
    workbook,
    "Sheet1",
    "QUARTILE.INC",
    [Expr::Number(1.0), Expr::String("bad")][:],
    ctx,
  )
  inspect(is_formula_error(quartile_bad, formula_error_value), content="true")

  let rank_bad_order = eval_function(
    workbook,
    "Sheet1",
    "RANK",
    [Expr::Number(1.0), Expr::Number(2.0), Expr::String("bad")][:],
    ctx,
  )
  inspect(is_formula_error(rank_bad_order, formula_error_value), content="true")

  let trunc_bad_digits = eval_function(
    workbook,
    "Sheet1",
    "TRUNC",
    [Expr::Number(1.25), Expr::String("bad")][:],
    ctx,
  )
  inspect(
    is_formula_error(trunc_bad_digits, formula_error_value),
    content="true",
  )

  let trunc_default_digits = eval_function(
    workbook,
    "Sheet1",
    "TRUNC",
    [Expr::Number(1.99)][:],
    ctx,
  )
  inspect(is_formula_number(trunc_default_digits, 1.0), content="true")

  let round_bad_left = eval_function(
    workbook,
    "Sheet1",
    "ROUND",
    [Expr::String("bad"), Expr::Number(1.0)][:],
    ctx,
  )
  inspect(is_formula_error(round_bad_left, formula_error_value), content="true")

  let round_bad_right = eval_function(
    workbook,
    "Sheet1",
    "ROUND",
    [Expr::Number(1.0), Expr::String("bad")][:],
    ctx,
  )
  inspect(
    is_formula_error(round_bad_right, formula_error_value),
    content="true",
  )

  let roundup_bad_left = eval_function(
    workbook,
    "Sheet1",
    "ROUNDUP",
    [Expr::String("bad"), Expr::Number(1.0)][:],
    ctx,
  )
  inspect(
    is_formula_error(roundup_bad_left, formula_error_value),
    content="true",
  )

  let roundup_bad_right = eval_function(
    workbook,
    "Sheet1",
    "ROUNDUP",
    [Expr::Number(1.0), Expr::String("bad")][:],
    ctx,
  )
  inspect(
    is_formula_error(roundup_bad_right, formula_error_value),
    content="true",
  )

  let rounddown_bad_left = eval_function(
    workbook,
    "Sheet1",
    "ROUNDDOWN",
    [Expr::String("bad"), Expr::Number(1.0)][:],
    ctx,
  )
  inspect(
    is_formula_error(rounddown_bad_left, formula_error_value),
    content="true",
  )

  let rounddown_bad_right = eval_function(
    workbook,
    "Sheet1",
    "ROUNDDOWN",
    [Expr::Number(1.0), Expr::String("bad")][:],
    ctx,
  )
  inspect(
    is_formula_error(rounddown_bad_right, formula_error_value),
    content="true",
  )

  let sqrt_neg = eval_function(
    workbook,
    "Sheet1",
    "SQRT",
    [Expr::Number(-1.0)][:],
    ctx,
  )
  inspect(is_formula_error(sqrt_neg, formula_error_num), content="true")

  let power_bad_left = eval_function(
    workbook,
    "Sheet1",
    "POWER",
    [Expr::String("bad"), Expr::Number(2.0)][:],
    ctx,
  )
  inspect(is_formula_error(power_bad_left, formula_error_value), content="true")

  let power_bad_right = eval_function(
    workbook,
    "Sheet1",
    "POWER",
    [Expr::Number(2.0), Expr::String("bad")][:],
    ctx,
  )
  inspect(
    is_formula_error(power_bad_right, formula_error_value),
    content="true",
  )
}

///|
test "formula builtins wb: dcount sumproduct sumifs guard paths" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let sheet = match workbook.sheet("Sheet1") {
    Some(value) => value
    None => fail("sheet missing")
  }
  sheet.set_cell_value("A1", String("Field"))
  sheet.set_cell_value("A2", Numeric(10.0))
  sheet.set_cell_value("C1", String("Field"))
  sheet.set_cell_value("C2", String(">5"))
  sheet.set_cell_value("B1", Numeric(1.0))
  sheet.set_cell_value("B2", Numeric(1.0))
  let ctx = CalcContext::new()

  let dcount_two_args = eval_function(
    workbook,
    "Sheet1",
    "DCOUNT",
    [Expr::Range("", "A1", "A2"), Expr::Range("", "C1", "C2")][:],
    ctx,
  )
  inspect(is_formula_number(dcount_two_args, 1.0), content="true")

  let sumproduct_mixed = eval_function(
    workbook,
    "Sheet1",
    "SUMPRODUCT",
    [Expr::Range("", "A2", "A2"), Expr::Number(3.0)][:],
    ctx,
  )
  inspect(
    is_formula_error(sumproduct_mixed, formula_error_value),
    content="true",
  )

  let sumifs_even_arity = eval_function(
    workbook,
    "Sheet1",
    "SUMIFS",
    [Expr::Number(1.0), Expr::Number(1.0), Expr::Number(1.0), Expr::Number(1.0)][:],
    ctx,
  )
  inspect(is_formula_error(sumifs_even_arity, formula_error_na), content="true")

  sheet.set_cell_value("A1", String("text"))
  let sumifs_non_numeric_sum = eval_function(
    workbook,
    "Sheet1",
    "SUMIFS",
    [
      Expr::Range("", "A1", "A1"),
      Expr::Range("", "B1", "B1"),
      Expr::Number(1.0),
    ][:],
    ctx,
  )
  inspect(is_formula_number(sumifs_non_numeric_sum, 0.0), content="true")

  sheet.set_cell_value("A1", Numeric(1.0))
  let sumifs_out_of_bounds = eval_function(
    workbook,
    "Sheet1",
    "SUMIFS",
    [
      Expr::Range("", "A1", "A1"),
      Expr::Range("", "B1", "B2"),
      Expr::Number(1.0),
    ][:],
    ctx,
  )
  inspect(
    is_formula_error(sumifs_out_of_bounds, formula_error_value),
    content="true",
  )
}

///|
test "formula builtins wb: complex aggregate mixed input paths" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let ctx = CalcContext::new()

  let improduct_mixed = eval_function(
    workbook,
    "Sheet1",
    "IMPRODUCT",
    [
      Expr::Cell("", "Z99"),
      Expr::Number(2.0),
      Expr::Bool(true),
      Expr::List([Expr::List([Expr::Number(3.0)])]),
    ][:],
    ctx,
  )
  inspect(
    match improduct_mixed {
      String(_) => true
      _ => false
    },
    content="true",
  )

  let imsum_error = eval_function(
    workbook,
    "Sheet1",
    "IMSUM",
    [Expr::FuncCall("NA", [])][:],
    ctx,
  )
  inspect(is_formula_error(imsum_error, formula_error_na), content="true")
}
