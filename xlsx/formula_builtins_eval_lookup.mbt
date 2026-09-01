///|
fn eval_transpose(call : EvalCall) -> FormulaValue raise XlsxError {
  match call.args {
    [a0] => {
      let base_range = range_from_expr_or_value(
        call.workbook,
        call.sheet_name,
        a0,
        call.values[0],
        call.ctx,
      )
      List(transpose_range_values(base_range).values)
    }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_take(call : EvalCall) -> FormulaValue raise XlsxError {
  take_values(call.workbook, call.sheet_name, call.args, call.values, call.ctx)
}

///|
fn eval_drop(call : EvalCall) -> FormulaValue raise XlsxError {
  drop_values(call.workbook, call.sheet_name, call.args, call.values, call.ctx)
}

///|
fn eval_choosecols(call : EvalCall) -> FormulaValue raise XlsxError {
  choosecols_values(
    call.workbook,
    call.sheet_name,
    call.args,
    call.values,
    call.ctx,
  )
}

///|
fn eval_chooserows(call : EvalCall) -> FormulaValue raise XlsxError {
  chooserows_values(
    call.workbook,
    call.sheet_name,
    call.args,
    call.values,
    call.ctx,
  )
}

///|
fn eval_hstack(call : EvalCall) -> FormulaValue raise XlsxError {
  stack_from_values(
    call.workbook,
    call.sheet_name,
    call.args,
    call.values,
    call.ctx,
    true,
  )
}

///|
fn eval_vstack(call : EvalCall) -> FormulaValue raise XlsxError {
  stack_from_values(
    call.workbook,
    call.sheet_name,
    call.args,
    call.values,
    call.ctx,
    false,
  )
}

///|
fn eval_expand(call : EvalCall) -> FormulaValue raise XlsxError {
  expand_values(
    call.workbook,
    call.sheet_name,
    call.args,
    call.values,
    call.ctx,
  )
}

///|
fn eval_wraprows(call : EvalCall) -> FormulaValue raise XlsxError {
  wrap_values(
    call.workbook,
    call.sheet_name,
    call.args,
    call.values,
    call.ctx,
    true,
  )
}

///|
fn eval_wrapcols(call : EvalCall) -> FormulaValue raise XlsxError {
  wrap_values(
    call.workbook,
    call.sheet_name,
    call.args,
    call.values,
    call.ctx,
    false,
  )
}

///|
fn eval_tocol(call : EvalCall) -> FormulaValue raise XlsxError {
  tocol_torow_values(
    call.workbook,
    call.sheet_name,
    call.args,
    call.values,
    call.ctx,
    false,
  )
}

///|
fn eval_torow(call : EvalCall) -> FormulaValue raise XlsxError {
  tocol_torow_values(
    call.workbook,
    call.sheet_name,
    call.args,
    call.values,
    call.ctx,
    false,
  )
}

///|
fn eval_sort(call : EvalCall) -> FormulaValue raise XlsxError {
  sort_values(call.workbook, call.sheet_name, call.args, call.values, call.ctx)
}

///|
fn eval_sortby(call : EvalCall) -> FormulaValue raise XlsxError {
  sortby_values(
    call.workbook,
    call.sheet_name,
    call.args,
    call.values,
    call.ctx,
  )
}

///|
fn eval_filter(call : EvalCall) -> FormulaValue raise XlsxError {
  filter_values(
    call.workbook,
    call.sheet_name,
    call.args,
    call.values,
    call.ctx,
  )
}

///|
fn eval_unique(call : EvalCall) -> FormulaValue raise XlsxError {
  if call.args.length() >= 1 && call.args.length() <= 3 {
    let by_col = if call.args.length() >= 2 {
      match value_as_bool(call.values[1]) {
        Ok(flag) => flag
        Err(err) => return err
      }
    } else {
      false
    }
    let exactly_once = if call.args.length() == 3 {
      match value_as_bool(call.values[2]) {
        Ok(flag) => flag
        Err(err) => return err
      }
    } else {
      false
    }
    let range = match call.args[0] {
      Range(_, _, _) | Cell(_, _) =>
        eval_range_expr(call.workbook, call.sheet_name, call.args[0], call.ctx)
      _ =>
        match call.values[0] {
          Error(err) => return Error(err)
          List(list) =>
            if list.length() == 0 {
              return Error(formula_error_value)
            } else {
              { rows: 1, cols: list.length(), values: list, }
            }
          _ => { rows: 1, cols: 1, values: [call.values[0]], }
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
fn eval_index(call : EvalCall) -> FormulaValue raise XlsxError {
  match call.args {
    [a0, _] | [a0, _, _] => {
      let range = eval_range_expr(call.workbook, call.sheet_name, a0, call.ctx)
      let row_num = match value_as_int(call.values[1]) {
        Ok(num) => num
        Err(err) => return err
      }
      let col_num = if call.args is [_, _, _] {
        match value_as_int(call.values[2]) {
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
fn eval_match(call : EvalCall) -> FormulaValue raise XlsxError {
  match call.args {
    [_, a1] | [_, a1, _] => {
      let lookup = call.values[0]
      let range = eval_range_expr(call.workbook, call.sheet_name, a1, call.ctx)
      let match_type = if call.args is [_, _, _] {
        match value_as_int(call.values[2]) {
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
fn eval_vlookup(call : EvalCall) -> FormulaValue raise XlsxError {
  match call.args {
    [_, a1, _] | [_, a1, _, _] => {
      let lookup = call.values[0]
      let table = eval_range_expr(call.workbook, call.sheet_name, a1, call.ctx)
      let col_index = match value_as_int(call.values[2]) {
        Ok(num) => num
        Err(err) => return err
      }
      let range_lookup = if call.args is [_, _, _, _] {
        match lookup_range_flag(call.values[3]) {
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
fn eval_hlookup(call : EvalCall) -> FormulaValue raise XlsxError {
  match call.args {
    [_, a1, _] | [_, a1, _, _] => {
      let lookup = call.values[0]
      let table = eval_range_expr(call.workbook, call.sheet_name, a1, call.ctx)
      let row_index = match value_as_int(call.values[2]) {
        Ok(num) => num
        Err(err) => return err
      }
      let range_lookup = if call.args is [_, _, _, _] {
        match lookup_range_flag(call.values[3]) {
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
fn eval_lookup(call : EvalCall) -> FormulaValue raise XlsxError {
  if call.args.length() == 2 || call.args.length() == 3 {
    let lookup = call.values[0]
    if call.args.length() == 2 {
      let array_range = range_from_expr_or_value(
        call.workbook,
        call.sheet_name,
        call.args[1],
        call.values[1],
        call.ctx,
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
        call.workbook,
        call.sheet_name,
        call.args[1],
        call.values[1],
        call.ctx,
      )
      let result_range = range_from_expr_or_value(
        call.workbook,
        call.sheet_name,
        call.args[2],
        call.values[2],
        call.ctx,
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
fn eval_xlookup(call : EvalCall) -> FormulaValue raise XlsxError {
  if call.args.length() >= 3 && call.args.length() <= 6 {
    let lookup = call.values[0]
    let lookup_range = range_from_expr_or_value(
      call.workbook,
      call.sheet_name,
      call.args[1],
      call.values[1],
      call.ctx,
    )
    let return_range = range_from_expr_or_value(
      call.workbook,
      call.sheet_name,
      call.args[2],
      call.values[2],
      call.ctx,
    )
    let if_not_found = if call.args.length() >= 4 {
      call.values[3]
    } else {
      Error(formula_error_na)
    }
    let match_mode = if call.args.length() >= 5 {
      match value_as_int(call.values[4]) {
        Ok(num) => num
        Err(err) => return err
      }
    } else {
      0
    }
    let search_mode = if call.args.length() >= 6 {
      match value_as_int(call.values[5]) {
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
fn eval_anchorarray(call : EvalCall) -> FormulaValue {
  anchorarray_values(call.workbook, call.sheet_name, call.args, call.values)
}

///|
fn eval_address(call : EvalCall) -> FormulaValue raise XlsxError {
  if call.values.length() >= 2 && call.values.length() <= 5 {
    let row_num = match value_as_int(call.values[0]) {
      Ok(num) => num
      Err(err) => return err
    }
    let col_num = match value_as_int(call.values[1]) {
      Ok(num) => num
      Err(err) => return err
    }
    if row_num <= 0 ||
      row_num > cell_ref_max_rows ||
      col_num <= 0 ||
      col_num > cell_ref_max_cols {
      return Error(formula_error_value)
    }
    let abs_num = if call.values.length() >= 3 {
      match value_as_int(call.values[2]) {
        Ok(num) => num
        Err(err) => return err
      }
    } else {
      1
    }
    if abs_num < 1 || abs_num > 4 {
      return Error(formula_error_value)
    }
    let a1 = if call.values.length() >= 4 {
      match value_as_bool(call.values[3]) {
        Ok(flag) => flag
        Err(err) => return err
      }
    } else {
      true
    }
    let sheet_text = if call.values.length() == 5 {
      match value_as_string(call.values[4]) {
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
fn eval_indirect(call : EvalCall) -> FormulaValue raise XlsxError {
  match call.values {
    [v0] | [v0, _] => {
      let ref_text = match value_as_string(v0) {
        Ok(text) => text
        Err(err) => return err
      }
      let a1 = if call.values is [_, v1] {
        match value_as_bool(v1) {
          Ok(flag) => flag
          Err(err) => return err
        }
      } else {
        true
      }
      let (sheet_text, ref_part) = split_sheet_ref(ref_text)
      let target_sheet = if sheet_text == "" {
        call.sheet_name
      } else {
        sheet_text
      }
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
                call.workbook,
                target_sheet,
                start_ref,
                end_ref,
                call.ctx,
              ),
            )
          }
          None =>
            match parse_cell_ref_token(ref_part) {
              Some(reference) =>
                resolve_cell_value(
                  call.workbook,
                  target_sheet,
                  reference,
                  call.ctx,
                )
              None => {
                let (start_ref, end_ref) = parse_range_ref_token(ref_part) catch {
                  _ => return Error(formula_error_ref)
                }
                List(
                  collect_range_values(
                    call.workbook,
                    target_sheet,
                    start_ref,
                    end_ref,
                    call.ctx,
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
                call.workbook,
                target_sheet,
                start_ref,
                end_ref,
                call.ctx,
              ),
            )
          }
          None =>
            match parse_r1c1_token(ref_part) {
              Some((row, col)) => {
                let reference = cell_ref_from(row, col) catch {
                  _ => return Error(formula_error_ref)
                }
                resolve_cell_value(
                  call.workbook,
                  target_sheet,
                  reference,
                  call.ctx,
                )
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
fn eval_hyperlink(call : EvalCall) -> FormulaValue {
  if call.values.length() == 1 || call.values.length() == 2 {
    match value_as_string(call.values[call.values.length() - 1]) {
      Ok(text) => String(text)
      Err(err) => err
    }
  } else {
    Error(formula_error_value)
  }
}

///|
fn eval_choose(call : EvalCall) -> FormulaValue {
  if call.values.length() >= 2 {
    let index_text = match value_as_string(call.values[0]) {
      Ok(text) => text
      Err(err) => return err
    }
    let idx = @string.parse_int(index_text, base=10) catch {
      _ => return Error(formula_error_value)
    }
    if call.values.length() <= idx {
      Error(formula_error_value)
    } else if idx <= 0 {
      call.values[0]
    } else {
      call.values[idx]
    }
  } else {
    Error(formula_error_value)
  }
}
