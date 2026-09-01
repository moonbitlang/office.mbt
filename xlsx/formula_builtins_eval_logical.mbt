///|
// Per-formula handlers for the logical family. Each maps one (or a few aliases of)
// one Excel formula to its implementation; eval_function routes to these via a HashMap.

///|
fn eval_true(_call : EvalCall) -> FormulaValue {
  Bool(true)
}

///|
fn eval_false(_call : EvalCall) -> FormulaValue {
  Bool(false)
}

///|
fn eval_and(call : EvalCall) -> FormulaValue {
  if call.values.length() == 0 || call.values.length() > 30 {
    Error(formula_error_value)
  } else {
    let mut result = true
    for value in call.values {
      match value {
        Empty => ()
        Error(err) => return Error(err)
        Number(num) => result = result && num != 0.0
        Bool(flag) => result = result && flag
        String(text) =>
          if text == "TRUE" {
            ()
          } else if text == "FALSE" {
            return Bool(false)
          } else {
            return Error(formula_error_value)
          }
        List(_) => return Error(formula_error_value)
      }
    }
    Bool(result)
  }
}

///|
fn eval_or(call : EvalCall) -> FormulaValue {
  if call.values.length() == 0 || call.values.length() > 30 {
    Error(formula_error_value)
  } else {
    for value in flatten_values(call.values) {
      match normalize_scalar(value) {
        Error(err) => return Error(err)
        Number(num) => if num != 0.0 { return Bool(true) }
        Bool(flag) => if flag { return Bool(true) }
        String(text) =>
          if text == "FALSE" {
            ()
          } else if text == "TRUE" {
            return Bool(true)
          } else {
            return Error(formula_error_value)
          }
        Empty | List(_) => ()
      }
    }
    Bool(false)
  }
}

///|
fn eval_not(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] =>
      match normalize_scalar(v0) {
        Error(err) => Error(err)
        Bool(flag) => Bool(!flag)
        Number(num) => Bool(!(num != 0.0))
        String(text) =>
          if text.to_upper() == "TRUE" {
            Bool(false)
          } else if text.to_upper() == "FALSE" {
            Bool(true)
          } else {
            Error(formula_error_value)
          }
        _ => Error(formula_error_value)
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_xor(call : EvalCall) -> FormulaValue {
  if call.values.length() == 0 {
    Error(formula_error_value)
  } else {
    let mut count = 0
    let mut ok = false
    for value in flatten_values(call.values) {
      match normalize_scalar(value) {
        Error(err) => return Error(err)
        Number(num) => {
          ok = true
          if num != 0.0 {
            count = count + 1
          }
        }
        Bool(flag) => {
          ok = true
          if flag {
            count = count + 1
          }
        }
        String(_) => ()
        Empty | List(_) => ()
      }
    }
    if !ok {
      Error(formula_error_value)
    } else {
      Bool(count % 2 != 0)
    }
  }
}

///|
fn eval_if(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] =>
      match value_as_bool(v0) {
        Ok(cond) => Bool(cond)
        Err(err) => err
      }
    [v0, v1] =>
      match value_as_bool(v0) {
        Ok(cond) => if cond { v1 } else { Bool(false) }
        Err(err) => err
      }
    [v0, v1, v2] =>
      match value_as_bool(v0) {
        Ok(cond) => if cond { v1 } else { v2 }
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_iferror(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0, v1] =>
      match normalize_scalar(v0) {
        Error(_) => v1
        Empty => Number(0.0)
        _ => v0
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_ifna(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0, v1] =>
      match normalize_scalar(v0) {
        Error(err) => if err == formula_error_na { v1 } else { v0 }
        _ => v0
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_ifs(call : EvalCall) -> FormulaValue {
  if call.values.length() < 2 || call.values.length() % 2 != 0 {
    Error(formula_error_value)
  } else {
    for i in 0..<(call.values.length() / 2) {
      match value_as_bool(call.values[i * 2]) {
        Ok(flag) => if flag { return call.values[i * 2 + 1] }
        Err(err) => return err
      }
    }
    Error(formula_error_na)
  }
}

///|
fn eval_switch(call : EvalCall) -> FormulaValue {
  if call.values.length() < 3 {
    Error(formula_error_value)
  } else {
    let target = call.values[0]
    let arg_count = call.values.length() - 1
    let switch_count = arg_count / 2
    let has_default = arg_count % 2 != 0
    let mut result = if has_default {
      call.values[call.values.length() - 1]
    } else {
      Error(formula_error_na)
    }
    for i in 0..<switch_count {
      let match_value = call.values[1 + i * 2]
      match compare_values(target, match_value) {
        Ok(0) => {
          result = call.values[1 + i * 2 + 1]
          break
        }
        Ok(_) => ()
        Err(err) => return err
      }
    }
    result
  }
}
