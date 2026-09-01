///|
// Per-formula handlers for the lookup family. Each maps one (or a few aliases of)
// one Excel formula to its implementation; eval_function routes to these via a HashMap.

///|
fn eval_transpose(
  workbook : Workbook,
  sheet_name : String,
  _name : String,
  args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue raise XlsxError {
  match args {
    [a0] => {
      let base_range = range_from_expr_or_value(
        workbook,
        sheet_name,
        a0,
        values[0],
        ctx,
      )
      List(transpose_range_values(base_range).values)
    }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_sequence(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  sequence_values(values)
}

///|
fn eval_take(
  workbook : Workbook,
  sheet_name : String,
  _name : String,
  args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue raise XlsxError {
  take_values(workbook, sheet_name, args, values, ctx)
}

///|
fn eval_drop(
  workbook : Workbook,
  sheet_name : String,
  _name : String,
  args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue raise XlsxError {
  drop_values(workbook, sheet_name, args, values, ctx)
}

///|
fn eval_choosecols(
  workbook : Workbook,
  sheet_name : String,
  _name : String,
  args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue raise XlsxError {
  choosecols_values(workbook, sheet_name, args, values, ctx)
}

///|
fn eval_chooserows(
  workbook : Workbook,
  sheet_name : String,
  _name : String,
  args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue raise XlsxError {
  chooserows_values(workbook, sheet_name, args, values, ctx)
}

///|
fn eval_hstack(
  workbook : Workbook,
  sheet_name : String,
  _name : String,
  args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue raise XlsxError {
  stack_from_values(workbook, sheet_name, args, values, ctx, true)
}

///|
fn eval_vstack(
  workbook : Workbook,
  sheet_name : String,
  _name : String,
  args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue raise XlsxError {
  stack_from_values(workbook, sheet_name, args, values, ctx, false)
}

///|
fn eval_expand(
  workbook : Workbook,
  sheet_name : String,
  _name : String,
  args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue raise XlsxError {
  expand_values(workbook, sheet_name, args, values, ctx)
}

///|
fn eval_wraprows(
  workbook : Workbook,
  sheet_name : String,
  _name : String,
  args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue raise XlsxError {
  wrap_values(workbook, sheet_name, args, values, ctx, true)
}

///|
fn eval_wrapcols(
  workbook : Workbook,
  sheet_name : String,
  _name : String,
  args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue raise XlsxError {
  wrap_values(workbook, sheet_name, args, values, ctx, false)
}

///|
fn eval_tocol(
  workbook : Workbook,
  sheet_name : String,
  _name : String,
  args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue raise XlsxError {
  tocol_torow_values(workbook, sheet_name, args, values, ctx, false)
}

///|
fn eval_torow(
  workbook : Workbook,
  sheet_name : String,
  _name : String,
  args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue raise XlsxError {
  tocol_torow_values(workbook, sheet_name, args, values, ctx, false)
}

///|
fn eval_sort(
  workbook : Workbook,
  sheet_name : String,
  _name : String,
  args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue raise XlsxError {
  sort_values(workbook, sheet_name, args, values, ctx)
}

///|
fn eval_sortby(
  workbook : Workbook,
  sheet_name : String,
  _name : String,
  args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue raise XlsxError {
  sortby_values(workbook, sheet_name, args, values, ctx)
}

///|
fn eval_filter(
  workbook : Workbook,
  sheet_name : String,
  _name : String,
  args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue raise XlsxError {
  filter_values(workbook, sheet_name, args, values, ctx)
}

///|
fn eval_unique(
  workbook : Workbook,
  sheet_name : String,
  _name : String,
  args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue raise XlsxError {
  if args.length() >= 1 && args.length() <= 3 {
    let by_col = if args.length() >= 2 {
      match value_as_bool(values[1]) {
        Ok(flag) => flag
        Err(err) => return err
      }
    } else {
      false
    }
    let exactly_once = if args.length() == 3 {
      match value_as_bool(values[2]) {
        Ok(flag) => flag
        Err(err) => return err
      }
    } else {
      false
    }
    let range = match args[0] {
      Range(_, _, _) | Cell(_, _) =>
        eval_range_expr(workbook, sheet_name, args[0], ctx)
      _ =>
        match values[0] {
          Error(err) => return Error(err)
          List(list) =>
            if list.length() == 0 {
              return Error(formula_error_value)
            } else {
              { rows: 1, cols: list.length(), values: list, }
            }
          _ => { rows: 1, cols: 1, values: [values[0]], }
        }
    }
    match unique_range_values(range, by_col, exactly_once) {
      Ok(result) => List(result.values)
      Err(err) => err
    }
  } else {
    Error(formula_error_value)
  }
}

///|
fn eval_index(
  workbook : Workbook,
  sheet_name : String,
  _name : String,
  args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue raise XlsxError {
  match args {
    [a0, _] | [a0, _, _] => {
      let range = eval_range_expr(workbook, sheet_name, a0, ctx)
      let row_num = match value_as_int(values[1]) {
        Ok(num) => num
        Err(err) => return err
      }
      let col_num = if args is [_, _, _] {
        match value_as_int(values[2]) {
          Ok(num) => num
          Err(err) => return err
        }
      } else {
        1
      }
      if row_num <= 0 || col_num <= 0 {
        Error(formula_error_value)
      } else if row_num > range.rows || col_num > range.cols {
        Error(formula_error_ref)
      } else {
        let index = (row_num - 1) * range.cols + (col_num - 1)
        range.values[index]
      }
    }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_match(
  workbook : Workbook,
  sheet_name : String,
  _name : String,
  args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue raise XlsxError {
  match args {
    [_, a1] | [_, a1, _] => {
      let lookup = values[0]
      let range = eval_range_expr(workbook, sheet_name, a1, ctx)
      let match_type = if args is [_, _, _] {
        match value_as_int(values[2]) {
          Ok(num) => num
          Err(err) => return err
        }
      } else {
        1
      }
      match_range_value(lookup, range, match_type)
    }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_vlookup(
  workbook : Workbook,
  sheet_name : String,
  _name : String,
  args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue raise XlsxError {
  match args {
    [_, a1, _] | [_, a1, _, _] => {
      let lookup = values[0]
      let table = eval_range_expr(workbook, sheet_name, a1, ctx)
      let col_index = match value_as_int(values[2]) {
        Ok(num) => num
        Err(err) => return err
      }
      let range_lookup = if args is [_, _, _, _] {
        match lookup_range_flag(values[3]) {
          Ok(flag) => flag
          Err(err) => return err
        }
      } else {
        true
      }
      vlookup_value(lookup, table, col_index, range_lookup)
    }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_hlookup(
  workbook : Workbook,
  sheet_name : String,
  _name : String,
  args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue raise XlsxError {
  match args {
    [_, a1, _] | [_, a1, _, _] => {
      let lookup = values[0]
      let table = eval_range_expr(workbook, sheet_name, a1, ctx)
      let row_index = match value_as_int(values[2]) {
        Ok(num) => num
        Err(err) => return err
      }
      let range_lookup = if args is [_, _, _, _] {
        match lookup_range_flag(values[3]) {
          Ok(flag) => flag
          Err(err) => return err
        }
      } else {
        true
      }
      hlookup_value(lookup, table, row_index, range_lookup)
    }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_lookup(
  workbook : Workbook,
  sheet_name : String,
  _name : String,
  args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue raise XlsxError {
  if args.length() == 2 || args.length() == 3 {
    let lookup = values[0]
    if args.length() == 2 {
      let array_range = range_from_expr_or_value(
        workbook,
        sheet_name,
        args[1],
        values[1],
        ctx,
      )
      if array_range.rows == 0 || array_range.cols == 0 {
        return Error(formula_error_value)
      }
      if array_range.rows == 1 || array_range.cols == 1 {
        let lookup_vec = if array_range.rows == 1 {
          range_row_required(array_range, 0)
        } else {
          range_column_required(array_range, 0)
        }
        let idx = match lookup_best_index(lookup, lookup_vec) {
          Ok(value) => value
          Err(err) => return err
        }
        match idx {
          Some(i) => lookup_vec[i]
          None => Error(formula_error_na)
        }
      } else {
        let use_cols = array_range.rows >= array_range.cols
        let lookup_list = if use_cols {
          range_column_required(array_range, 0)
        } else {
          range_row_required(array_range, 0)
        }
        let result_list = if use_cols {
          range_column_required(array_range, array_range.cols - 1)
        } else {
          range_row_required(array_range, array_range.rows - 1)
        }
        let idx = match lookup_best_index(lookup, lookup_list) {
          Ok(value) => value
          Err(err) => return err
        }
        match idx {
          Some(i) => result_list[i]
          None => Error(formula_error_na)
        }
      }
    } else {
      let lookup_range = range_from_expr_or_value(
        workbook,
        sheet_name,
        args[1],
        values[1],
        ctx,
      )
      let result_range = range_from_expr_or_value(
        workbook,
        sheet_name,
        args[2],
        values[2],
        ctx,
      )
      if lookup_range.rows == 0 ||
        lookup_range.cols == 0 ||
        result_range.rows == 0 ||
        result_range.cols == 0 {
        return Error(formula_error_value)
      }
      let lookup_list = match range_vector(lookup_range) {
        Some(list) => list
        None => return Error(formula_error_na)
      }
      let result_list = match range_vector(result_range) {
        Some(list) => list
        None => return Error(formula_error_na)
      }
      if lookup_list.length() != result_list.length() {
        return Error(formula_error_na)
      }
      let idx = match lookup_best_index(lookup, lookup_list) {
        Ok(value) => value
        Err(err) => return err
      }
      match idx {
        Some(i) => result_list[i]
        None => Error(formula_error_na)
      }
    }
  } else {
    Error(formula_error_value)
  }
}

///|
fn eval_xlookup(
  workbook : Workbook,
  sheet_name : String,
  _name : String,
  args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue raise XlsxError {
  if args.length() >= 3 && args.length() <= 6 {
    let lookup = values[0]
    let lookup_range = range_from_expr_or_value(
      workbook,
      sheet_name,
      args[1],
      values[1],
      ctx,
    )
    let return_range = range_from_expr_or_value(
      workbook,
      sheet_name,
      args[2],
      values[2],
      ctx,
    )
    let if_not_found = if args.length() >= 4 {
      values[3]
    } else {
      Error(formula_error_na)
    }
    let match_mode = if args.length() >= 5 {
      match value_as_int(values[4]) {
        Ok(num) => num
        Err(err) => return err
      }
    } else {
      0
    }
    let search_mode = if args.length() >= 6 {
      match value_as_int(values[5]) {
        Ok(num) => num
        Err(err) => return err
      }
    } else {
      1
    }
    if match_mode != -1 && match_mode != 0 && match_mode != 1 && match_mode != 2 {
      return Error(formula_error_value)
    }
    if search_mode != 1 &&
      search_mode != -1 &&
      search_mode != 2 &&
      search_mode != -2 {
      return Error(formula_error_value)
    }
    let is_row = lookup_range.rows == 1
    let is_col = lookup_range.cols == 1
    if !is_row && !is_col {
      return Error(formula_error_value)
    }
    let lookup_values = if is_row {
      range_row_required(lookup_range, 0)
    } else {
      range_column_required(lookup_range, 0)
    }
    let match_idx = match
      xlookup_find_index(lookup, lookup_values, match_mode, search_mode) {
      Ok(value) => value
      Err(err) => return err
    }
    let idx = match match_idx {
      Some(value) => value
      None => return if_not_found
    }
    if is_row {
      if return_range.cols != lookup_range.cols {
        return Error(formula_error_value)
      }
      if return_range.rows == 1 {
        return_range.values[idx]
      } else {
        List(range_column_required(return_range, idx))
      }
    } else {
      if return_range.rows != lookup_range.rows {
        return Error(formula_error_value)
      }
      if return_range.cols == 1 {
        return_range.values[idx * return_range.cols]
      } else {
        List(range_row_required(return_range, idx))
      }
    }
  } else {
    Error(formula_error_value)
  }
}

///|
fn eval_anchorarray(
  workbook : Workbook,
  sheet_name : String,
  _name : String,
  args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  anchorarray_values(workbook, sheet_name, args, values)
}

///|
fn eval_address(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue raise XlsxError {
  if values.length() >= 2 && values.length() <= 5 {
    let row_num = match value_as_int(values[0]) {
      Ok(num) => num
      Err(err) => return err
    }
    let col_num = match value_as_int(values[1]) {
      Ok(num) => num
      Err(err) => return err
    }
    if row_num <= 0 ||
      row_num > cell_ref_max_rows ||
      col_num <= 0 ||
      col_num > cell_ref_max_cols {
      return Error(formula_error_value)
    }
    let abs_num = if values.length() >= 3 {
      match value_as_int(values[2]) {
        Ok(num) => num
        Err(err) => return err
      }
    } else {
      1
    }
    if abs_num < 1 || abs_num > 4 {
      return Error(formula_error_value)
    }
    let a1 = if values.length() >= 4 {
      match value_as_bool(values[3]) {
        Ok(flag) => flag
        Err(err) => return err
      }
    } else {
      true
    }
    let sheet_text = if values.length() == 5 {
      match value_as_string(values[4]) {
        Ok(text) => text
        Err(err) => return err
      }
    } else {
      ""
    }
    let address = if a1 {
      address_a1(row_num, col_num, abs_num)
    } else {
      address_r1c1(row_num, col_num, abs_num)
    }
    let text = if sheet_text == "" {
      address
    } else {
      sheet_text + "!" + address
    }
    String(text)
  } else {
    Error(formula_error_value)
  }
}

///|
fn eval_indirect(
  workbook : Workbook,
  sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue raise XlsxError {
  match values {
    [v0] | [v0, _] => {
      let ref_text = match value_as_string(v0) {
        Ok(text) => text
        Err(err) => return err
      }
      let a1 = if values is [_, v1] {
        match value_as_bool(v1) {
          Ok(flag) => flag
          Err(err) => return err
        }
      } else {
        true
      }
      let (sheet_text, ref_part) = split_sheet_ref(ref_text)
      let target_sheet = if sheet_text == "" { sheet_name } else { sheet_text }
      if a1 {
        match ref_part.find(":") {
          Some(idx) => {
            let start_token = ref_part.unsafe_substring(start=0, end=idx)
            let end_token = ref_part.unsafe_substring(
              start=idx + 1,
              end=ref_part.length(),
            )
            let (start_ref, _start_end) = parse_range_ref_token(start_token) catch {
              _ => return Error(formula_error_ref)
            }
            let (_end_start, end_ref) = parse_range_ref_token(end_token) catch {
              _ => return Error(formula_error_ref)
            }
            List(
              collect_range_values(
                workbook, target_sheet, start_ref, end_ref, ctx,
              ),
            )
          }
          None =>
            match parse_cell_ref_token(ref_part) {
              Some(reference) =>
                resolve_cell_value(workbook, target_sheet, reference, ctx)
              None => {
                let (start_ref, end_ref) = parse_range_ref_token(ref_part) catch {
                  _ => return Error(formula_error_ref)
                }
                List(
                  collect_range_values(
                    workbook, target_sheet, start_ref, end_ref, ctx,
                  ),
                )
              }
            }
        }
      } else {
        match ref_part.find(":") {
          Some(idx) => {
            let start_token = ref_part.unsafe_substring(start=0, end=idx)
            let end_token = ref_part.unsafe_substring(
              start=idx + 1,
              end=ref_part.length(),
            )
            let (row1, col1) = match parse_r1c1_token(start_token) {
              Some(value) => value
              None => return Error(formula_error_ref)
            }
            let (row2, col2) = match parse_r1c1_token(end_token) {
              Some(value) => value
              None => return Error(formula_error_ref)
            }
            let start_ref = cell_ref_from(row1, col1) catch {
              _ => return Error(formula_error_ref)
            }
            let end_ref = cell_ref_from(row2, col2) catch {
              _ => return Error(formula_error_ref)
            }
            List(
              collect_range_values(
                workbook, target_sheet, start_ref, end_ref, ctx,
              ),
            )
          }
          None =>
            match parse_r1c1_token(ref_part) {
              Some((row, col)) => {
                let reference = cell_ref_from(row, col) catch {
                  _ => return Error(formula_error_ref)
                }
                resolve_cell_value(workbook, target_sheet, reference, ctx)
              }
              None => Error(formula_error_ref)
            }
        }
      }
    }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_hyperlink(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  if values.length() == 1 || values.length() == 2 {
    match value_as_string(values[values.length() - 1]) {
      Ok(text) => String(text)
      Err(err) => err
    }
  } else {
    Error(formula_error_value)
  }
}

///|
fn eval_choose(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  if values.length() >= 2 {
    let index_text = match value_as_string(values[0]) {
      Ok(text) => text
      Err(err) => return err
    }
    let idx = @string.parse_int(index_text, base=10) catch {
      _ => return Error(formula_error_value)
    }
    if values.length() <= idx {
      Error(formula_error_value)
    } else if idx <= 0 {
      values[0]
    } else {
      values[idx]
    }
  } else {
    Error(formula_error_value)
  }
}
