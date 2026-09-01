///|
// Per-formula handlers for the info family. Each maps one (or a few aliases of)
// one Excel formula to its implementation; eval_function routes to these via a HashMap.

///|
fn eval_dispimg(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0, _] => v0
    _ => Error(formula_error_value)
  }
}

///|
fn eval_isblank(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] =>
      match normalize_scalar(v0) {
        Empty => Bool(true)
        _ => Bool(false)
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_iserr(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] =>
      match normalize_scalar(v0) {
        Error(err) => Bool(is_known_error_code(err) && err != formula_error_na)
        _ => Bool(false)
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_iseven(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] =>
      match normalize_scalar(v0) {
        Empty => Bool(true)
        _ =>
          match value_as_number(v0) {
            Ok(num) => {
              let even = if num == 1.0 { false } else { num == num / 2.0 * 2.0 }
              Bool(even)
            }
            Err(err) => err
          }
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_isodd(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] =>
      match value_as_number(v0) {
        Ok(num) => {
          let n = Double::to_int(num)
          Bool(n != n / 2 * 2)
        }
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_iserror(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] =>
      match normalize_scalar(v0) {
        Error(err) => Bool(is_known_error_code(err))
        _ => Bool(false)
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_islogical(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] =>
      match normalize_scalar(v0) {
        Bool(_) => Bool(true)
        String(text) => Bool(text == "TRUE" || text == "FALSE")
        _ => Bool(false)
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_isna(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] =>
      match normalize_scalar(v0) {
        Error(err) => Bool(err == formula_error_na)
        _ => Bool(false)
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_isnumber(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] =>
      match normalize_scalar(v0) {
        Number(_) => Bool(true)
        _ => Bool(false)
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_istext(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] =>
      match normalize_scalar(v0) {
        String(text) =>
          match parse_double_opt(text) {
            Some(_) => Bool(false)
            None => Bool(true)
          }
        _ => Bool(false)
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_isnontext(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] =>
      match normalize_scalar(v0) {
        String(_) => Bool(false)
        _ => Bool(true)
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_isref(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  args : ArrayView[Expr],
  _values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match args {
    [a0] => Bool(is_ref_expr(a0))
    _ => Error(formula_error_value)
  }
}

///|
fn eval_isformula(
  workbook : Workbook,
  sheet_name : String,
  _name : String,
  args : ArrayView[Expr],
  _values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match args {
    [a0] =>
      match a0 {
        Cell(sheet, reference) => {
          let target_sheet = if sheet == "" { sheet_name } else { sheet }
          Bool(cell_has_formula(workbook, target_sheet, reference))
        }
        _ => Bool(false)
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_errordottype(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] => error_type_value(v0)
    _ => Error(formula_error_value)
  }
}

///|
fn eval_sheet(
  workbook : Workbook,
  sheet_name : String,
  _name : String,
  args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match args {
    [] =>
      match sheet_index_opt(workbook, sheet_name) {
        Some(index) => Number(Double::from_int(index + 1))
        None => Error(formula_error_na)
      }
    [arg] => {
      let target_sheet = match arg {
        Cell(sheet, _) => if sheet == "" { sheet_name } else { sheet }
        Range(sheet, _, _) => if sheet == "" { sheet_name } else { sheet }
        _ => formula_value_string(values[0])
      }
      match sheet_index_opt(workbook, target_sheet) {
        Some(index) => Number(Double::from_int(index + 1))
        None => Error(formula_error_na)
      }
    }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_sheets(
  workbook : Workbook,
  _sheet_name : String,
  _name : String,
  args : ArrayView[Expr],
  _values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match args {
    [] => Number(Double::from_int(workbook.sheets().length()))
    [arg] =>
      match arg {
        Cell(_, _) | Range(_, _, _) => Number(1.0)
        _ => Error(formula_error_na)
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_type(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] => type_value(v0)
    _ => Error(formula_error_value)
  }
}

///|
fn eval_na(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [] => Error(formula_error_na)
    _ => Error(formula_error_value)
  }
}

///|
fn eval_n(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] =>
      match normalize_scalar(v0) {
        Error(err) => Error(err)
        Number(num) => Number(num)
        Bool(flag) => Number(if flag { 1.0 } else { 0.0 })
        String(text) =>
          match parse_double_opt(text) {
            Some(num) => Number(num)
            None => if text == "TRUE" { Number(1.0) } else { Number(0.0) }
          }
        Empty | List(_) => Number(0.0)
      }
    _ => Error(formula_error_value)
  }
}
