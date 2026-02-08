///|
fn is_formula_error(value : FormulaValue, expected : String) -> Bool {
  match value {
    Error(err) => err == expected
    _ => false
  }
}

///|
test "formula builtins wb: row column and formulatxt guards" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let ctx = CalcContext::new()

  inspect(
    is_formula_error(eval_function(workbook, "Sheet1", "ROW", [][:], ctx), formula_error_value),
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
