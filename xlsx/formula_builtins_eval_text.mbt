///|
// Per-formula handlers for the text family. Each maps one (or a few aliases of)
// one Excel formula to its implementation; eval_function routes to these via a HashMap.

///|
fn eval_dollar(call : EvalCall) -> FormulaValue {
  dollar_values(call.values)
}

///|
fn eval_len(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] =>
      match value_as_string(v0) {
        Ok(text) => Number(Double::from_int(text.length()))
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_lenb(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] =>
      match value_as_string(v0) {
        Ok(text) => Number(Double::from_int(dbcs_byte_length(text)))
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_lower(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] =>
      match value_as_string(v0) {
        Ok(text) => String(text.to_lower())
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_upper(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] =>
      match value_as_string(v0) {
        Ok(text) => String(text.to_upper())
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_proper(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] =>
      match value_as_string(v0) {
        Ok(text) => String(proper_case(text))
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_dbcs(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] =>
      match value_as_string(v0) {
        Ok(text) =>
          if dbcs_enabled(call.workbook) {
            String(dbcs_convert(text))
          } else {
            String(text)
          }
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_trim(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] =>
      match value_as_string(v0) {
        Ok(text) => String(trim_excel_text(text))
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_left(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] | [v0, _] => {
      let text = match value_as_string(v0) {
        Ok(text) => text
        Err(err) => return err
      }
      let count = if call.values is [_, v1] {
        match value_as_int(v1) {
          Ok(num) => num
          Err(err) => return err
        }
      } else {
        1
      }
      if count < 0 {
        Error(formula_error_value)
      } else {
        let len = text.length()
        let end = if count > len { len } else { count }
        let start = 0
        String(text.unsafe_substring(start~, end~))
      }
    }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_leftb(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] | [v0, _] => {
      let text = match value_as_string(v0) {
        Ok(text) => text
        Err(err) => return err
      }
      let count = if call.values is [_, v1] {
        match value_as_int(v1) {
          Ok(num) => num
          Err(err) => return err
        }
      } else {
        1
      }
      if count < 0 {
        Error(formula_error_value)
      } else {
        let len = dbcs_byte_length(text)
        if count >= len {
          String(text)
        } else {
          String(dbcs_byte_range(text, 1, count))
        }
      }
    }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_right(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] | [v0, _] => {
      let text = match value_as_string(v0) {
        Ok(text) => text
        Err(err) => return err
      }
      let count = if call.values is [_, v1] {
        match value_as_int(v1) {
          Ok(num) => num
          Err(err) => return err
        }
      } else {
        1
      }
      if count < 0 {
        Error(formula_error_value)
      } else {
        let len = text.length()
        let start = if count >= len { 0 } else { len - count }
        let end = len
        String(text.unsafe_substring(start~, end~))
      }
    }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_rightb(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] | [v0, _] => {
      let text = match value_as_string(v0) {
        Ok(text) => text
        Err(err) => return err
      }
      let count = if call.values is [_, v1] {
        match value_as_int(v1) {
          Ok(num) => num
          Err(err) => return err
        }
      } else {
        1
      }
      if count < 0 {
        Error(formula_error_value)
      } else {
        let len = dbcs_byte_length(text)
        if count >= len {
          String(text)
        } else {
          String(dbcs_byte_range(text, len - count + 1, count))
        }
      }
    }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_mid(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0, v1, v2] => {
      let text = match value_as_string(v0) {
        Ok(text) => text
        Err(err) => return err
      }
      let start_num = match value_as_int(v1) {
        Ok(num) => num
        Err(err) => return err
      }
      let count = match value_as_int(v2) {
        Ok(num) => num
        Err(err) => return err
      }
      if start_num <= 0 || count < 0 {
        Error(formula_error_value)
      } else {
        let len = text.length()
        if start_num > len {
          String("")
        } else {
          let start = start_num - 1
          let mut end = start + count
          if end > len {
            end = len
          }
          String(text.unsafe_substring(start~, end~))
        }
      }
    }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_midb(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0, v1, v2] => {
      let text = match value_as_string(v0) {
        Ok(text) => text
        Err(err) => return err
      }
      let start_num = match value_as_int(v1) {
        Ok(num) => num
        Err(err) => return err
      }
      let count = match value_as_int(v2) {
        Ok(num) => num
        Err(err) => return err
      }
      if start_num <= 0 || count < 0 {
        Error(formula_error_value)
      } else if count == 0 {
        String("")
      } else if start_num > dbcs_byte_length(text) {
        String("")
      } else {
        String(dbcs_byte_range(text, start_num, count))
      }
    }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_rept(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0, v1] => {
      let text = match value_as_string(v0) {
        Ok(text) => text
        Err(err) => return err
      }
      let times = match value_as_int(v1) {
        Ok(num) => num
        Err(err) => return err
      }
      if times < 0 {
        Error(formula_error_value)
      } else if times == 0 || text.length() == 0 {
        String("")
      } else if text.length() > max_cell_chars / times {
        Error(formula_error_value)
      } else {
        String(text.repeat(times))
      }
    }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_replace(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0, v1, v2, v3] => {
      let text = match value_as_string(v0) {
        Ok(text) => text
        Err(err) => return err
      }
      let start_num = match value_as_int(v1) {
        Ok(num) => num
        Err(err) => return err
      }
      let count = match value_as_int(v2) {
        Ok(num) => num
        Err(err) => return err
      }
      let new_text = match value_as_string(v3) {
        Ok(text) => text
        Err(err) => return err
      }
      if start_num <= 0 || count < 0 {
        Error(formula_error_value)
      } else {
        let len = text.length()
        let mut start = start_num - 1
        if start > len {
          start = len
        }
        let mut end = start + count
        if end > len {
          end = len
        }
        let sb = StringBuilder()
        sb.write_view(text.unsafe_substring(start=0, end=start))
        sb.write_view(new_text)
        sb.write_view(text.unsafe_substring(start=end, end=len))
        String(sb.to_string())
      }
    }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_replaceb(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0, v1, v2, v3] => {
      let text = match value_as_string(v0) {
        Ok(text) => text
        Err(err) => return err
      }
      let start_num = match value_as_int(v1) {
        Ok(num) => num
        Err(err) => return err
      }
      let count = match value_as_int(v2) {
        Ok(num) => num
        Err(err) => return err
      }
      let new_text = match value_as_string(v3) {
        Ok(text) => text
        Err(err) => return err
      }
      if start_num <= 0 || count < 0 {
        Error(formula_error_value)
      } else {
        let len = dbcs_byte_length(text)
        let prefix_count = if start_num - 1 < len { start_num - 1 } else { len }
        let removed_end = start_num + count - 1
        let suffix_start = if removed_end < len {
          removed_end + 1
        } else {
          len + 1
        }
        let sb = StringBuilder()
        sb.write_view(dbcs_byte_range(text, 1, prefix_count))
        sb.write_view(new_text)
        // suffix runs from just past the replaced range to end of string
        sb.write_view(dbcs_byte_range(text, suffix_start, len))
        String(sb.to_string())
      }
    }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_substitute(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0, v1, v2] | [v0, v1, v2, _] => {
      let text = match value_as_string(v0) {
        Ok(text) => text
        Err(err) => return err
      }
      let old_text = match value_as_string(v1) {
        Ok(text) => text
        Err(err) => return err
      }
      let new_text = match value_as_string(v2) {
        Ok(text) => text
        Err(err) => return err
      }
      if old_text.length() == 0 {
        Error(formula_error_value)
      } else if call.values is [_, _, _, v3] {
        let instance = match value_as_int(v3) {
          Ok(num) => num
          Err(err) => return err
        }
        if instance <= 0 {
          Error(formula_error_value)
        } else {
          let mut index = 0
          let mut count = 0
          let len = text.length()
          let pattern_len = old_text.length()
          while true {
            match find_substring_from(text, old_text, index) {
              Some(found) => {
                count = count + 1
                if count == instance {
                  let sb = StringBuilder()
                  sb.write_view(text.unsafe_substring(start=0, end=found))
                  sb.write_view(new_text)
                  let tail_start = found + pattern_len
                  sb.write_view(
                    text.unsafe_substring(start=tail_start, end=len),
                  )
                  return String(sb.to_string())
                }
                index = found + pattern_len
              }
              None => break
            }
          }
          String(text)
        }
      } else {
        let mut index = 0
        let len = text.length()
        let pattern_len = old_text.length()
        let sb = StringBuilder()
        while true {
          match find_substring_from(text, old_text, index) {
            Some(found) => {
              sb.write_view(text.unsafe_substring(start=index, end=found))
              sb.write_view(new_text)
              index = found + pattern_len
            }
            None => {
              sb.write_view(text.unsafe_substring(start=index, end=len))
              break
            }
          }
        }
        String(sb.to_string())
      }
    }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_find(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0, v1] | [v0, v1, _] => {
      let find_text = match value_as_string(v0) {
        Ok(text) => text
        Err(err) => return err
      }
      let within_text = match value_as_string(v1) {
        Ok(text) => text
        Err(err) => return err
      }
      let start_num = if call.values is [_, _, v2] {
        match value_as_int(v2) {
          Ok(num) => num
          Err(err) => return err
        }
      } else {
        1
      }
      if start_num <= 0 {
        Error(formula_error_value)
      } else {
        let start = start_num - 1
        let len = within_text.length()
        if start > len {
          Error(formula_error_value)
        } else if find_text.length() == 0 {
          Number(Double::from_int(start_num))
        } else {
          match find_substring_from(within_text, find_text, start) {
            Some(idx) => Number(Double::from_int(idx + 1))
            None => Error(formula_error_value)
          }
        }
      }
    }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_findb(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0, v1] | [v0, v1, _] => {
      let find_text = match value_as_string(v0) {
        Ok(text) => text
        Err(err) => return err
      }
      let within_text = match value_as_string(v1) {
        Ok(text) => text
        Err(err) => return err
      }
      let start_num = if call.values is [_, _, v2] {
        match value_as_int(v2) {
          Ok(num) => num
          Err(err) => return err
        }
      } else {
        1
      }
      match find_dbcs(within_text, find_text, start_num, false) {
        Some(value) => Number(Double::from_int(value))
        None => Error(formula_error_value)
      }
    }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_search(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0, v1] | [v0, v1, _] => {
      let find_text = match value_as_string(v0) {
        Ok(text) => text
        Err(err) => return err
      }
      let within_text = match value_as_string(v1) {
        Ok(text) => text
        Err(err) => return err
      }
      let start_num = if call.values is [_, _, v2] {
        match value_as_int(v2) {
          Ok(num) => num
          Err(err) => return err
        }
      } else {
        1
      }
      if start_num <= 0 {
        Error(formula_error_value)
      } else {
        let start = start_num - 1
        let lower_text = within_text.to_lower()
        let lower_find = find_text.to_lower()
        let len = lower_text.length()
        if start > len {
          Error(formula_error_value)
        } else if lower_find.length() == 0 {
          Number(Double::from_int(start_num))
        } else {
          match wildcard_find(lower_text, lower_find, start) {
            Some(idx) => Number(Double::from_int(idx + 1))
            None => Error(formula_error_value)
          }
        }
      }
    }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_searchb(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0, v1] | [v0, v1, _] => {
      let find_text = match value_as_string(v0) {
        Ok(text) => text
        Err(err) => return err
      }
      let within_text = match value_as_string(v1) {
        Ok(text) => text
        Err(err) => return err
      }
      let start_num = if call.values is [_, _, v2] {
        match value_as_int(v2) {
          Ok(num) => num
          Err(err) => return err
        }
      } else {
        1
      }
      let lower_find = find_text.to_lower()
      let lower_text = within_text.to_lower()
      match find_dbcs(lower_text, lower_find, start_num, true) {
        Some(value) => Number(Double::from_int(value))
        None => Error(formula_error_value)
      }
    }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_exact(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0, v1] => {
      let left = match value_as_string(v0) {
        Ok(text) => text
        Err(err) => return err
      }
      let right = match value_as_string(v1) {
        Ok(text) => text
        Err(err) => return err
      }
      Bool(left == right)
    }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_fixed(call : EvalCall) -> FormulaValue {
  if call.values.length() >= 1 && call.values.length() <= 3 {
    let number = match value_as_number(call.values[0]) {
      Ok(num) => num
      Err(err) => return err
    }
    let mut decimals = if call.values.length() == 1 {
      decimal_places_from_text(formula_value_string(call.values[0]))
    } else {
      match value_as_int(call.values[1]) {
        Ok(num) => num
        Err(err) => return err
      }
    }
    if decimals < 0 {
      decimals = 0
    }
    let no_commas = if call.values.length() == 3 {
      match value_as_bool(call.values[2]) {
        Ok(flag) => flag
        Err(err) => return err
      }
    } else {
      false
    }
    String(format_fixed_number(number, decimals, !no_commas, 1))
  } else {
    Error(formula_error_value)
  }
}

///|
fn eval_value(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] =>
      match value_as_number_text(v0) {
        Ok(num) => Number(num)
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_valuetotext(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] | [v0, _] => {
      let format = if call.values is [_, v1] {
        match value_as_int(v1) {
          Ok(num) => num
          Err(err) => return err
        }
      } else {
        0
      }
      if format != 0 && format != 1 {
        Error(formula_error_value)
      } else {
        let text = formula_value_string(v0)
        match value_as_number(v0) {
          Ok(_) => String(text)
          Err(_) =>
            if format == 1 {
              String("\"" + text + "\"")
            } else {
              String(text)
            }
        }
      }
    }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_text(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0, v1] => {
      let format_text = match value_as_string(v1) {
        Ok(text) => text
        Err(err) => return err
      }
      match value_as_number_text(v0) {
        Ok(num) => {
          let formatted = format_number_code(
            format_number(num),
            format_text,
            Options::new(),
            use_1904_format=call.ctx.use_1904_dates,
          ) catch {
            _ => return Error(formula_error_value)
          }
          String(formatted)
        }
        Err(err) => err
      }
    }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_arraytotext(call : EvalCall) -> FormulaValue raise XlsxError {
  if call.values.length() == 1 || call.values.length() == 2 {
    let format = if call.values.length() == 2 {
      match value_as_int(call.values[1]) {
        Ok(num) => num
        Err(err) => return err
      }
    } else {
      0
    }
    if format != 0 && format != 1 {
      return Error(formula_error_value)
    }
    let range = match call.args[0] {
      Range(_, _, _) | Cell(_, _) =>
        eval_range_expr(call.workbook, call.sheet_name, call.args[0], call.ctx)
      _ => { rows: 1, cols: 1, values: [call.values[0]], }
    }
    let rows : Array[String] = []
    for row in 0..<range.rows {
      let cells : Array[String] = []
      for col in 0..<range.cols {
        let value = range.values[row * range.cols + col]
        match normalize_scalar(value) {
          Error(err) => return Error(err)
          _ => {
            let text = formula_value_string(value)
            match value_as_number(value) {
              Ok(_) => cells.push(text)
              Err(_) =>
                if format == 1 {
                  cells.push("\"" + text + "\"")
                } else {
                  cells.push(text)
                }
            }
          }
        }
      }
      let joined = if format == 1 { cells.join(",") } else { cells.join(", ") }
      rows.push(joined)
    }
    if format == 1 {
      String("{" + rows.join(";") + "}")
    } else {
      String(rows.join(", "))
    }
  } else {
    Error(formula_error_value)
  }
}

///|
fn eval_textafter(call : EvalCall) -> FormulaValue {
  if call.values.length() >= 2 && call.values.length() <= 6 {
    let text = match value_as_string(call.values[0]) {
      Ok(value) => value
      Err(err) => return err
    }
    let delimiter = match value_as_string(call.values[1]) {
      Ok(value) => value
      Err(err) => return err
    }
    if text == "" {
      return Error(formula_error_na)
    }
    let instance_num = if call.values.length() >= 3 {
      match value_as_int(call.values[2]) {
        Ok(num) => num
        Err(err) => return err
      }
    } else {
      1
    }
    if instance_num == 0 ||
      instance_num > text.length() ||
      -instance_num > text.length() {
      return Error(formula_error_value)
    }
    let match_mode = if call.values.length() >= 4 {
      match value_as_int(call.values[3]) {
        Ok(num) => num
        Err(err) => return err
      }
    } else {
      0
    }
    if match_mode != 0 && match_mode != 1 {
      return Error(formula_error_value)
    }
    let match_end = if call.values.length() >= 5 {
      match value_as_bool(call.values[4]) {
        Ok(flag) => flag
        Err(err) => return err
      }
    } else {
      false
    }
    let if_not_found = if call.values.length() == 6 {
      call.values[5]
    } else {
      Empty
    }
    let idx_opt = text_after_before_index(
      text, delimiter, instance_num, match_mode, match_end,
    )
    let idx = match idx_opt {
      Some(value) => value
      None => return if_not_found
    }
    if call.name == "TEXTAFTER" || call.name == "_XLFN.TEXTAFTER" {
      let start = idx + delimiter.length()
      if start >= text.length() {
        Empty
      } else {
        String(text.unsafe_substring(start~, end=text.length()))
      }
    } else if idx <= 0 {
      String("")
    } else {
      String(text.unsafe_substring(start=0, end=idx))
    }
  } else {
    Error(formula_error_value)
  }
}

///|
fn eval_textsplit(call : EvalCall) -> FormulaValue {
  if call.values.length() >= 2 && call.values.length() <= 6 {
    textsplit_values(call.values)
  } else {
    Error(formula_error_value)
  }
}

///|
fn eval_textjoin(call : EvalCall) -> FormulaValue {
  if call.values.length() >= 3 {
    let delimiter = match value_as_string(call.values[0]) {
      Ok(text) => text
      Err(err) => return err
    }
    let ignore_empty = match value_as_bool(call.values[1]) {
      Ok(flag) => flag
      Err(err) => return err
    }
    let parts : Array[String] = []
    for i in 2..<call.values.length() {
      match textjoin_collect_value(call.values[i], ignore_empty, parts) {
        Ok(_) => ()
        Err(err) => return err
      }
    }
    let result = parts.join(delimiter)
    if result.length() > max_cell_chars {
      Error(formula_error_value)
    } else {
      String(result)
    }
  } else {
    Error(formula_error_value)
  }
}

///|
fn eval_char(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] =>
      match value_as_number(v0) {
        Ok(num) => {
          let code = Double::to_int(trunc_double(num))
          if code < 0 || code > max_field_length {
            Error(formula_error_value)
          } else {
            String(char_from_code(code))
          }
        }
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_unichar(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] =>
      match value_as_number(v0) {
        Ok(num) =>
          if num <= 0.0 || num > 55295.0 {
            Error(formula_error_value)
          } else {
            let code = Double::to_int(trunc_double(num))
            String(char_from_code(code))
          }
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_clean(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] => clean_text_value(v0)
    _ => Error(formula_error_value)
  }
}

///|
fn eval_encodeurl(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] => encode_url_value(v0)
    _ => Error(formula_error_value)
  }
}

///|
fn eval_bahttext(call : EvalCall) -> FormulaValue {
  match call.values {
    [_] => bahttext_values(call.values)
    _ => Error(formula_error_value)
  }
}

///|
fn eval_code(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] => code_value("CODE", v0)
    _ => Error(formula_error_value)
  }
}

///|
fn eval_unicode(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] => code_value("UNICODE", v0)
    _ => Error(formula_error_value)
  }
}

///|
fn eval_concat(call : EvalCall) -> FormulaValue {
  concat_values(call.values)
}

///|
fn eval_t(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] =>
      match normalize_scalar(v0) {
        Error(err) => Error(err)
        Number(_) | Empty | List(_) => String("")
        String(text) => String(text)
        Bool(flag) => String(if flag { "TRUE" } else { "FALSE" })
      }
    _ => Error(formula_error_value)
  }
}
