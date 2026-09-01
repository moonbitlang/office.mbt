///|
// Per-formula handlers for the info family. Each maps one (or a few aliases of)
// one Excel formula to its implementation; eval_function routes to these via a HashMap.

///|
fn eval_dispimg(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0, _] => v0
    _ => Error(formula_error_value)
  }
}

///|
fn eval_isblank(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] =>
      match normalize_scalar(v0) {
        Empty => Bool(true)
        _ => Bool(false)
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_iserr(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] =>
      match normalize_scalar(v0) {
        Error(err) => Bool(is_known_error_code(err) && err != formula_error_na)
        _ => Bool(false)
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_iseven(call : EvalCall) -> FormulaValue {
  match call.values {
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
fn eval_isodd(call : EvalCall) -> FormulaValue {
  match call.values {
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
fn eval_iserror(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] =>
      match normalize_scalar(v0) {
        Error(err) => Bool(is_known_error_code(err))
        _ => Bool(false)
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_islogical(call : EvalCall) -> FormulaValue {
  match call.values {
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
fn eval_isna(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] =>
      match normalize_scalar(v0) {
        Error(err) => Bool(err == formula_error_na)
        _ => Bool(false)
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_isnumber(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] =>
      match normalize_scalar(v0) {
        Number(_) => Bool(true)
        _ => Bool(false)
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_istext(call : EvalCall) -> FormulaValue {
  match call.values {
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
fn eval_isnontext(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] =>
      match normalize_scalar(v0) {
        String(_) => Bool(false)
        _ => Bool(true)
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_isref(call : EvalCall) -> FormulaValue {
  match call.args {
    [a0] => Bool(is_ref_expr(a0))
    _ => Error(formula_error_value)
  }
}

///|
fn eval_isformula(call : EvalCall) -> FormulaValue {
  match call.args {
    [a0] =>
      match a0 {
        Cell(sheet, reference) => {
          let target_sheet = if sheet == "" { call.sheet_name } else { sheet }
          Bool(cell_has_formula(call.workbook, target_sheet, reference))
        }
        _ => Bool(false)
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_errordottype(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] => error_type_value(v0)
    _ => Error(formula_error_value)
  }
}

///|
fn eval_sheet(call : EvalCall) -> FormulaValue {
  match call.args {
    [] =>
      match sheet_index_opt(call.workbook, call.sheet_name) {
        Some(index) => Number(Double::from_int(index + 1))
        None => Error(formula_error_na)
      }
    [arg] => {
      let target_sheet = match arg {
        Cell(sheet, _) => if sheet == "" { call.sheet_name } else { sheet }
        Range(sheet, _, _) => if sheet == "" { call.sheet_name } else { sheet }
        _ => formula_value_string(call.values[0])
      }
      match sheet_index_opt(call.workbook, target_sheet) {
        Some(index) => Number(Double::from_int(index + 1))
        None => Error(formula_error_na)
      }
    }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_sheets(call : EvalCall) -> FormulaValue {
  match call.args {
    [] => Number(Double::from_int(call.workbook.sheets().length()))
    [arg] =>
      match arg {
        Cell(_, _) | Range(_, _, _) => Number(1.0)
        _ => Error(formula_error_na)
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_type(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] => type_value(v0)
    _ => Error(formula_error_value)
  }
}

///|
fn eval_na(call : EvalCall) -> FormulaValue {
  match call.values {
    [] => Error(formula_error_na)
    _ => Error(formula_error_value)
  }
}

///|
fn eval_n(call : EvalCall) -> FormulaValue {
  match call.values {
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
