///|
// Per-formula handlers for the math family. Each maps one (or a few aliases of)
// one Excel formula to its implementation; eval_function routes to these via a HashMap.

///|
fn eval_sum(call : EvalCall) -> FormulaValue {
  sum_values(call.values)
}

///|
fn eval_subtotal(call : EvalCall) -> FormulaValue {
  subtotal_values(call.values)
}

///|
fn eval_aggregate(call : EvalCall) -> FormulaValue {
  aggregate_values(call.values)
}

///|
fn eval_product(call : EvalCall) -> FormulaValue {
  product_values(call.values)
}

///|
fn eval_sign(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] =>
      match value_as_number(v0) {
        Ok(num) =>
          Number(if num < 0.0 { -1.0 } else if num > 0.0 { 1.0 } else { 0.0 })
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_seriessum(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0, v1, v2, v3] => {
      let x = match value_as_number(v0) {
        Ok(num) => num
        Err(err) => return err
      }
      let n = match value_as_number(v1) {
        Ok(num) => num
        Err(err) => return err
      }
      let m = match value_as_number(v2) {
        Ok(num) => num
        Err(err) => return err
      }
      let coefficients = list_from_value(v3)
      let mut result = 0.0
      let mut idx = 0.0
      for coefficient in coefficients {
        if formula_value_string(coefficient) == "" {
          continue
        }
        let num = match value_as_number(coefficient) {
          Ok(num) => num
          Err(err) => return err
        }
        result = result + num * @math.pow(x, n + m * idx)
        idx = idx + 1.0
      }
      Number(round_significant_digits(result, 15))
    }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_sumif(call : EvalCall) -> FormulaValue raise XlsxError {
  match call.args {
    [a0, _] | [a0, _, _] => {
      let range_values = eval_range_expr(
        call.workbook,
        call.sheet_name,
        a0,
        call.ctx,
      )
      let sum_range = if call.args is [_, _, a2] {
        Some(eval_range_expr(call.workbook, call.sheet_name, a2, call.ctx))
      } else {
        None
      }
      sumif_values(range_values, call.values[1], sum_range)
    }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_sumproduct(call : EvalCall) -> FormulaValue raise XlsxError {
  if call.args.length() >= 1 {
    let ranges : Array[RangeValues] = []
    let scalars : Array[FormulaValue] = []
    let mut has_range = false
    let mut has_scalar = false
    for i in 0..<call.args.length() {
      match call.args[i] {
        Range(_, _, _) | Cell(_, _) => {
          has_range = true
          ranges.push(
            eval_range_expr(
              call.workbook,
              call.sheet_name,
              call.args[i],
              call.ctx,
            ),
          )
        }
        _ =>
          match call.values[i] {
            Error(err) => return Error(err)
            _ => {
              has_scalar = true
              scalars.push(call.values[i])
            }
          }
      }
    }
    if has_range && has_scalar {
      Error(formula_error_value)
    } else if has_range {
      sumproduct_values(ranges)
    } else {
      sumproduct_scalars(scalars)
    }
  } else {
    Error(formula_error_value)
  }
}

///|
fn eval_sumsq(call : EvalCall) -> FormulaValue {
  sumsq_values(call.values)
}

///|
fn eval_sumx2my2(call : EvalCall) -> FormulaValue raise XlsxError {
  match call.args {
    [a0, a1] => {
      let left = eval_range_expr(call.workbook, call.sheet_name, a0, call.ctx)
      let right = eval_range_expr(call.workbook, call.sheet_name, a1, call.ctx)
      sumx_values("SUMX2MY2", left, right)
    }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_sumx2py2(call : EvalCall) -> FormulaValue raise XlsxError {
  match call.args {
    [a0, a1] => {
      let left = eval_range_expr(call.workbook, call.sheet_name, a0, call.ctx)
      let right = eval_range_expr(call.workbook, call.sheet_name, a1, call.ctx)
      sumx_values("SUMX2PY2", left, right)
    }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_sumxmy2(call : EvalCall) -> FormulaValue raise XlsxError {
  match call.args {
    [a0, a1] => {
      let left = eval_range_expr(call.workbook, call.sheet_name, a0, call.ctx)
      let right = eval_range_expr(call.workbook, call.sheet_name, a1, call.ctx)
      sumx_values("SUMXMY2", left, right)
    }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_sumifs(call : EvalCall) -> FormulaValue raise XlsxError {
  if call.args.length() >= 3 {
    if call.args.length() % 2 != 1 {
      Error(formula_error_na)
    } else {
      let sum_range = eval_range_expr(
        call.workbook,
        call.sheet_name,
        call.args[0],
        call.ctx,
      )
      let ranges : Array[RangeValues] = []
      let criterias : Array[FormulaCriteria] = []
      for i in 0..<((call.args.length() - 1) / 2) {
        let offset = 1 + i * 2
        let range_values = eval_range_expr(
          call.workbook,
          call.sheet_name,
          call.args[offset],
          call.ctx,
        )
        ranges.push(range_values)
        criterias.push(parse_formula_criteria(call.values[offset + 1]))
      }
      let matches = ifs_match(ranges, criterias)
      let mut sum = 0.0
      for cell in matches {
        match sum_range.get(cell.row, cell.col) {
          Some(value) =>
            match value_as_number_opt(value) {
              Some(num) => sum = sum + num
              None => ()
            }
          None => return Error(formula_error_value)
        }
      }
      Number(sum)
    }
  } else {
    Error(formula_error_value)
  }
}

///|
fn eval_gcd(call : EvalCall) -> FormulaValue {
  gcd_values(call.values)
}

///|
fn eval_lcm(call : EvalCall) -> FormulaValue {
  lcm_values(call.values)
}

///|
fn eval_combin(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0, v1] =>
      match (value_as_number(v0), value_as_number(v1)) {
        (Ok(num), Ok(chosen)) => combin_values(num, chosen)
        (Err(err), _) => err
        (_, Err(err)) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_combina(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0, v1] =>
      match (value_as_number(v0), value_as_number(v1)) {
        (Ok(num), Ok(chosen)) => {
          let n = trunc_double(num)
          let k = trunc_double(chosen)
          if n < k {
            Error(formula_error_value)
          } else if n == 0.0 {
            Number(n)
          } else {
            combin_values(n + k - 1.0, n - 1.0)
          }
        }
        (Err(err), _) => err
        (_, Err(err)) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_complex(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0, v1] | [v0, v1, _] =>
      match (value_as_number(v0), value_as_number(v1)) {
        (Ok(real), Ok(imag)) => {
          let mut suffix = "i"
          if call.values is [_, _, v2] {
            match value_as_string(v2) {
              Ok(text) => {
                let lower = text.to_lower()
                if lower != "i" && lower != "j" {
                  return Error(formula_error_value)
                }
                suffix = lower
              }
              Err(err) => return err
            }
          }
          String(complex_to_string(complex_new(real, imag), suffix))
        }
        (Err(err), _) => err
        (_, Err(err)) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_fact(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] =>
      match value_as_number(v0) {
        Ok(num) =>
          if num < 0.0 {
            Error(formula_error_num)
          } else {
            Number(factorial_double(num))
          }
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_factdouble(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] =>
      match value_as_number(v0) {
        Ok(num) =>
          if num < 0.0 {
            Error(formula_error_num)
          } else {
            Number(double_factorial_double(num))
          }
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_multinomial(call : EvalCall) -> FormulaValue {
  multinomial_values(call.values)
}

///|
fn eval_mdeterm(call : EvalCall) -> FormulaValue raise XlsxError {
  match call.values {
    [v0] => {
      let range = range_from_expr_or_value(
        call.workbook,
        call.sheet_name,
        call.args[0],
        v0,
        call.ctx,
      )
      match number_matrix_from_range(range, true) {
        Ok(matrix) => Number(matrix_det(matrix))
        Err(err) => err
      }
    }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_minverse(call : EvalCall) -> FormulaValue raise XlsxError {
  match call.values {
    [v0] => {
      let range = range_from_expr_or_value(
        call.workbook,
        call.sheet_name,
        call.args[0],
        v0,
        call.ctx,
      )
      match number_matrix_from_range(range, true) {
        Ok(matrix) => {
          let det_value = matrix_det(matrix)
          if det_value == 0.0 {
            Error(formula_error_num)
          } else {
            let adj = matrix_adjugate(matrix)
            let scale = 1.0 / det_value
            for row in 0..<adj.length() {
              for col in 0..<adj[row].length() {
                let value = adj[row][col]
                if value == 0.0 && scale < 0.0 {
                  adj[row][col] = -0.0
                } else {
                  adj[row][col] = value * scale
                }
              }
            }
            List(matrix_values(adj))
          }
        }
        Err(err) => err
      }
    }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_mmult(call : EvalCall) -> FormulaValue raise XlsxError {
  match call.values {
    [v0, v1] =>
      match (v0, v1) {
        (Number(lhs), Number(rhs)) => Number(lhs * rhs)
        _ => {
          let left_range = range_from_expr_or_value(
            call.workbook,
            call.sheet_name,
            call.args[0],
            v0,
            call.ctx,
          )
          let right_range = range_from_expr_or_value(
            call.workbook,
            call.sheet_name,
            call.args[1],
            v1,
            call.ctx,
          )
          match
            (
              number_matrix_from_range(left_range, false),
              number_matrix_from_range(right_range, false),
            ) {
            (Ok(left), Ok(right)) =>
              match matrix_multiply(left, right) {
                Ok(matrix) => List(matrix_values(matrix))
                Err(err) => err
              }
            (Err(err), _) => err
            (_, Err(err)) => err
          }
        }
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_munit(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] =>
      match munit_dimension(v0) {
        Ok(dimension) => List(munit_range_values(dimension).values)
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_abs(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] =>
      match value_as_number(v0) {
        Ok(num) => Number(abs_double(num))
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_int(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] =>
      match value_as_number(v0) {
        Ok(num) => Number(Double::floor(num))
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_ln(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] =>
      match value_as_number(v0) {
        Ok(num) => Number(@math.ln(num))
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_exp(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] =>
      match value_as_number(v0) {
        Ok(num) => Number(@math.exp(num))
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_decimal(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0, v1] =>
      match (value_as_string(v0), value_as_number(v1)) {
        (Ok(text), Ok(radix)) => {
          let base = Double::to_int(trunc_double(radix))
          let text_value = strip_hex_prefix(text)
          let parsed = @string.parse_int(text_value, base~) catch {
            _ => return Error(formula_error_value)
          }
          Number(Double::from_int(parsed))
        }
        (Err(err), _) => err
        (_, Err(err)) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_roman(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] | [v0, _] =>
      match value_as_number(v0) {
        Ok(num) => {
          let mut form = 0
          if call.values is [_, v1] {
            match value_as_number(v1) {
              Ok(raw) => {
                let mut mode = Double::to_int(trunc_double(raw))
                if mode < 0 {
                  mode = 0
                } else if mode > 4 {
                  mode = 4
                }
                form = mode
              }
              Err(err) => return err
            }
          }
          String(roman_string(num, form))
        }
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_arabic(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] =>
      match value_as_string(v0) {
        Ok(text) => arabic_string_value(text)
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_base(call : EvalCall) -> FormulaValue {
  base_values(call.values)
}

///|
fn eval_bin2dec(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] =>
      match value_as_number(v0) {
        Ok(_) => bin2dec_string(formula_value_string(v0))
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_bin2hex(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] | [v0, _] =>
      match value_as_number(v0) {
        Ok(_) => {
          let decimal = bin2dec_string(formula_value_string(v0))
          match decimal {
            Error(_) => decimal
            _ => {
              let new_values : Array[FormulaValue] = [decimal]
              if call.values is [_, places] {
                new_values.push(places)
              }
              dec2x_values("BIN2HEX", new_values)
            }
          }
        }
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_bin2oct(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] | [v0, _] =>
      match value_as_number(v0) {
        Ok(_) => {
          let decimal = bin2dec_string(formula_value_string(v0))
          match decimal {
            Error(_) => decimal
            _ => {
              let new_values : Array[FormulaValue] = [decimal]
              if call.values is [_, places] {
                new_values.push(places)
              }
              dec2x_values("BIN2OCT", new_values)
            }
          }
        }
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_dec2bin(call : EvalCall) -> FormulaValue {
  dec2x_values("DEC2BIN", call.values)
}

///|
fn eval_dec2hex(call : EvalCall) -> FormulaValue {
  dec2x_values("DEC2HEX", call.values)
}

///|
fn eval_dec2oct(call : EvalCall) -> FormulaValue {
  dec2x_values("DEC2OCT", call.values)
}

///|
fn eval_hex2bin(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] | [v0, _] =>
      match value_as_string(v0) {
        Ok(text) => {
          let decimal = hex2dec_string(text)
          match decimal {
            Error(_) => decimal
            _ => {
              let new_values : Array[FormulaValue] = [decimal]
              if call.values is [_, places] {
                new_values.push(places)
              }
              dec2x_values("HEX2BIN", new_values)
            }
          }
        }
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_hex2dec(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] =>
      match value_as_string(v0) {
        Ok(text) => hex2dec_string(text)
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_hex2oct(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] | [v0, _] =>
      match value_as_string(v0) {
        Ok(text) => {
          let decimal = hex2dec_string(text)
          match decimal {
            Error(_) => decimal
            _ => {
              let new_values : Array[FormulaValue] = [decimal]
              if call.values is [_, places] {
                new_values.push(places)
              }
              dec2x_values("HEX2OCT", new_values)
            }
          }
        }
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_oct2bin(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] | [v0, _] =>
      match value_as_number(v0) {
        Ok(_) => {
          let decimal = oct2dec_string(formula_value_string(v0))
          let new_values : Array[FormulaValue] = [decimal]
          if call.values is [_, places] {
            new_values.push(places)
          }
          dec2x_values("OCT2BIN", new_values)
        }
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_oct2dec(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] =>
      match value_as_number(v0) {
        Ok(_) => oct2dec_string(formula_value_string(v0))
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_oct2hex(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] | [v0, _] =>
      match value_as_number(v0) {
        Ok(_) => {
          let decimal = oct2dec_string(formula_value_string(v0))
          let new_values : Array[FormulaValue] = [decimal]
          if call.values is [_, places] {
            new_values.push(places)
          }
          dec2x_values("OCT2HEX", new_values)
        }
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_besseli(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0, v1] =>
      match (value_as_number(v0), value_as_number(v1)) {
        (Ok(x), Ok(n)) => number_or_num_error(bessel_i(x, n))
        (Err(err), _) => err
        (_, Err(err)) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_besselj(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0, v1] =>
      match (value_as_number(v0), value_as_number(v1)) {
        (Ok(x), Ok(n)) => number_or_num_error(bessel_j(x, n))
        (Err(err), _) => err
        (_, Err(err)) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_besselk(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0, v1] =>
      match (value_as_number(v0), value_as_number(v1)) {
        (Ok(x), Ok(n)) =>
          if x <= 0.0 || n < 0.0 {
            Error(formula_error_num)
          } else {
            let order = Double::floor(n)
            let result = if order == 0.0 {
              bessel_k0(x)
            } else if order == 1.0 {
              bessel_k1(x)
            } else {
              bessel_k2(x, n)
            }
            number_or_num_error(result)
          }
        (Err(err), _) => err
        (_, Err(err)) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_bessely(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0, v1] =>
      match (value_as_number(v0), value_as_number(v1)) {
        (Ok(x), Ok(n)) =>
          if x <= 0.0 || n < 0.0 {
            Error(formula_error_num)
          } else {
            let order = Double::floor(n)
            let result = if order == 0.0 {
              bessel_y0(x)
            } else if order == 1.0 {
              bessel_y1(x)
            } else {
              bessel_y2(x, n)
            }
            number_or_num_error(result)
          }
        (Err(err), _) => err
        (_, Err(err)) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_delta(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] | [v0, _] => {
      let number1 = match value_as_number(v0) {
        Ok(num) => num
        Err(err) => return err
      }
      let number2 = if call.values is [_, v1] {
        match value_as_number(v1) {
          Ok(num) => num
          Err(err) => return err
        }
      } else {
        0.0
      }
      Number(if number1 == number2 { 1.0 } else { 0.0 })
    }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_erf(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] | [v0, _] =>
      match value_as_number(v0) {
        Ok(lower) =>
          if call.values is [_, v1] {
            match value_as_number(v1) {
              Ok(upper) =>
                number_or_num_error(erf_double(upper) - erf_double(lower))
              Err(err) => err
            }
          } else {
            number_or_num_error(erf_double(lower))
          }
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_erfdotprecise(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] =>
      match value_as_number(v0) {
        Ok(value) => number_or_num_error(erf_double(value))
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_erfc(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] =>
      match value_as_number(v0) {
        Ok(value) => number_or_num_error(erfc_double(value))
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_erfcdotprecise(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] =>
      match value_as_number(v0) {
        Ok(value) => number_or_num_error(erfc_double(value))
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_convert(call : EvalCall) -> FormulaValue {
  convert_values(call.values)
}

///|
fn eval_euroconvert(call : EvalCall) -> FormulaValue {
  euroconvert_values(call.values)
}

///|
fn eval_gestep(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] | [v0, _] => {
      let number = match value_as_number(v0) {
        Ok(num) => num
        Err(err) => return err
      }
      let step = if call.values is [_, v1] {
        match value_as_number(v1) {
          Ok(num) => num
          Err(err) => return err
        }
      } else {
        0.0
      }
      Number(if number >= step { 1.0 } else { 0.0 })
    }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_bitand(call : EvalCall) -> FormulaValue {
  bitwise_values("BITAND", call.values)
}

///|
fn eval_bitlshift(call : EvalCall) -> FormulaValue {
  bitwise_values("BITLSHIFT", call.values)
}

///|
fn eval_bitor(call : EvalCall) -> FormulaValue {
  bitwise_values("BITOR", call.values)
}

///|
fn eval_bitrshift(call : EvalCall) -> FormulaValue {
  bitwise_values("BITRSHIFT", call.values)
}

///|
fn eval_bitxor(call : EvalCall) -> FormulaValue {
  bitwise_values("BITXOR", call.values)
}

///|
fn eval_acos(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] =>
      match value_as_number(v0) {
        Ok(num) => number_or_num_error(@math.acos(num))
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_acosh(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] =>
      match value_as_number(v0) {
        Ok(num) => number_or_num_error(@math.acosh(num))
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_acot(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] =>
      match value_as_number(v0) {
        Ok(num) => number_or_num_error(@math.PI / 2.0 - @math.atan(num))
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_acoth(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] =>
      match value_as_number(v0) {
        Ok(num) => number_or_num_error(@math.atanh(1.0 / num))
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_asin(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] =>
      match value_as_number(v0) {
        Ok(num) => number_or_num_error(@math.asin(num))
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_asinh(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] =>
      match value_as_number(v0) {
        Ok(num) => number_or_num_error(@math.asinh(num))
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_atan(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] =>
      match value_as_number(v0) {
        Ok(num) => number_or_num_error(@math.atan(num))
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_atanh(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] =>
      match value_as_number(v0) {
        Ok(num) => number_or_num_error(@math.atanh(num))
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_atan2(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0, v1] =>
      match (value_as_number(v0), value_as_number(v1)) {
        (Ok(y), Ok(x)) => number_or_num_error(@math.atan2(x, y))
        (Err(err), _) => err
        (_, Err(err)) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_cos(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] =>
      match value_as_number(v0) {
        Ok(num) => number_or_num_error(@math.cos(num))
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_cosh(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] =>
      match value_as_number(v0) {
        Ok(num) => number_or_num_error(@math.cosh(num))
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_sin(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] =>
      match value_as_number(v0) {
        Ok(num) => number_or_num_error(@math.sin(num))
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_sinh(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] =>
      match value_as_number(v0) {
        Ok(num) => number_or_num_error(@math.sinh(num))
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_tan(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] =>
      match value_as_number(v0) {
        Ok(num) => number_or_num_error(@math.tan(num))
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_tanh(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] =>
      match value_as_number(v0) {
        Ok(num) => number_or_num_error(@math.tanh(num))
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_cot(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] =>
      match value_as_number(v0) {
        Ok(num) =>
          if num == 0.0 {
            Error(formula_error_div)
          } else {
            number_or_num_error(1.0 / @math.tan(num))
          }
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_coth(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] =>
      match value_as_number(v0) {
        Ok(num) =>
          if num == 0.0 {
            Error(formula_error_div)
          } else {
            let exp_pos = @math.exp(num)
            let exp_neg = @math.exp(-num)
            number_or_num_error((exp_pos + exp_neg) / (exp_pos - exp_neg))
          }
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_csc(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] =>
      match value_as_number(v0) {
        Ok(num) =>
          if num == 0.0 {
            Error(formula_error_div)
          } else {
            number_or_num_error(1.0 / @math.sin(num))
          }
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_csch(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] =>
      match value_as_number(v0) {
        Ok(num) =>
          if num == 0.0 {
            Error(formula_error_div)
          } else {
            number_or_num_error(1.0 / @math.sinh(num))
          }
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_sec(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] =>
      match value_as_number(v0) {
        Ok(num) => number_or_num_error(@math.cos(num))
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_sech(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] =>
      match value_as_number(v0) {
        Ok(num) => number_or_num_error(1.0 / @math.cosh(num))
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_degrees(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] =>
      match value_as_number(v0) {
        Ok(num) =>
          if num == 0.0 {
            Error(formula_error_div)
          } else {
            Number(180.0 / @math.PI * num)
          }
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_radians(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] =>
      match value_as_number(v0) {
        Ok(num) => Number(@math.PI / 180.0 * num)
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_rand(call : EvalCall) -> FormulaValue {
  match call.values {
    [] => Number(formula_rand().double())
    _ => Error(formula_error_value)
  }
}

///|
fn eval_randarray(call : EvalCall) -> FormulaValue {
  randarray_values(call.values)
}

///|
fn eval_randbetween(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0, v1] =>
      match (value_as_number(v0), value_as_number(v1)) {
        (Ok(bottom), Ok(top)) =>
          if top < bottom {
            Error(formula_error_num)
          } else {
            // Keep sampling overflow-safe for very wide bounds by staying in Double space.
            let bottom_int = trunc_double(bottom)
            let top_int = trunc_double(top)
            let range = top_int - bottom_int + 1.0
            let rand_value = Double::floor(formula_rand().double() * range)
            Number(bottom_int + rand_value)
          }
        (Err(err), _) => err
        (_, Err(err)) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_pi(call : EvalCall) -> FormulaValue {
  match call.values {
    [] => Number(@math.PI)
    _ => Error(formula_error_value)
  }
}

///|
fn eval_sqrtpi(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] =>
      match value_as_number(v0) {
        Ok(num) => Number(@math.pow(num * @math.PI, 0.5))
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_log(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] | [v0, _] =>
      match value_as_number(v0) {
        Ok(num) => {
          let mut base = 10.0
          if call.values is [_, v1] {
            match value_as_number(v1) {
              Ok(value) => base = value
              Err(err) => return err
            }
          }
          if num == 0.0 || base == 0.0 {
            Error(formula_error_num)
          } else if base == 1.0 {
            Error(formula_error_div)
          } else {
            Number(@math.ln(num) / @math.ln(base))
          }
        }
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_log10(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] =>
      match value_as_number(v0) {
        Ok(num) => Number(@math.log10(num))
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_imabs(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] =>
      match parse_complex_value(v0) {
        Ok(num) =>
          number_or_num_error(round_significant_digits(complex_abs(num), 15))
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_imaginary(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] =>
      match parse_complex_value(v0) {
        Ok(num) => number_or_num_error(round_significant_digits(num.imag, 15))
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_imargument(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] =>
      match parse_complex_value(v0) {
        Ok(num) =>
          number_or_num_error(round_significant_digits(complex_arg(num), 15))
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_imconjugate(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] =>
      match parse_complex_value_with_suffix(v0) {
        Ok((num, suffix)) =>
          String(complex_to_string(complex_conj(num), suffix))
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_imcos(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] =>
      match parse_complex_value_with_suffix(v0) {
        Ok((num, suffix)) => String(complex_to_string(complex_cos(num), suffix))
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_imcosh(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] =>
      match parse_complex_value_with_suffix(v0) {
        Ok((num, suffix)) =>
          String(complex_to_string(complex_cosh(num), suffix))
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_imcot(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] =>
      match parse_complex_value_with_suffix(v0) {
        Ok((num, suffix)) =>
          String(
            complex_to_string(
              complex_div(complex_cos(num), complex_sin(num)),
              suffix,
            ),
          )
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_imcsc(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] =>
      match parse_complex_value_with_suffix(v0) {
        Ok((num, suffix)) => {
          let result = complex_div(complex_new(1.0, 0.0), complex_sin(num))
          if complex_is_invalid(result) {
            Error(formula_error_num)
          } else {
            String(complex_to_string(result, suffix))
          }
        }
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_imcsch(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] =>
      match parse_complex_value_with_suffix(v0) {
        Ok((num, suffix)) => {
          let result = complex_div(complex_new(1.0, 0.0), complex_sinh(num))
          if complex_is_invalid(result) {
            Error(formula_error_num)
          } else {
            String(complex_to_string(result, suffix))
          }
        }
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_imdiv(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0, v1] =>
      match (parse_complex_value_with_suffix(v0), parse_complex_value(v1)) {
        (Ok((left, suffix)), Ok(right)) => {
          let result = complex_div(left, right)
          if complex_is_invalid(result) {
            Error(formula_error_num)
          } else {
            String(complex_to_string(result, suffix))
          }
        }
        (Err(err), _) => err
        (_, Err(err)) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_imexp(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] =>
      match parse_complex_value_with_suffix(v0) {
        Ok((num, suffix)) => String(complex_to_string(complex_exp(num), suffix))
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_imln(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] =>
      match parse_complex_value_with_suffix(v0) {
        Ok((num, suffix)) => {
          let result = complex_log(num)
          if complex_is_invalid(result) {
            Error(formula_error_num)
          } else {
            String(complex_to_string(result, suffix))
          }
        }
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_imlog10(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] =>
      match parse_complex_value_with_suffix(v0) {
        Ok((num, suffix)) => {
          let result = complex_scale(complex_log(num), 1.0 / @math.ln(10.0))
          if complex_is_invalid(result) {
            Error(formula_error_num)
          } else {
            String(complex_to_string(result, suffix))
          }
        }
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_imlog2(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] =>
      match parse_complex_value_with_suffix(v0) {
        Ok((num, suffix)) => {
          let result = complex_scale(complex_log(num), 1.0 / @math.ln(2.0))
          if complex_is_invalid(result) {
            Error(formula_error_num)
          } else {
            String(complex_to_string(result, suffix))
          }
        }
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_impower(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0, v1] =>
      match (parse_complex_value_with_suffix(v0), parse_complex_value(v1)) {
        (Ok((base, suffix)), Ok(exponent)) =>
          if base.real == 0.0 &&
            base.imag == 0.0 &&
            exponent.real == 0.0 &&
            exponent.imag == 0.0 {
            Error(formula_error_num)
          } else {
            let result = complex_pow(base, exponent)
            if complex_is_invalid(result) {
              Error(formula_error_num)
            } else {
              String(complex_to_string(result, suffix))
            }
          }
        (Err(err), _) => err
        (_, Err(err)) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_improduct(call : EvalCall) -> FormulaValue {
  let mut product = complex_new(1.0, 0.0)
  for value in flatten_values(call.values) {
    match value {
      Error(err) => return Error(err)
      Empty => ()
      Number(num) => product = complex_mul(product, complex_new(num, 0.0))
      Bool(flag) => {
        let num = if flag { 1.0 } else { 0.0 }
        product = complex_mul(product, complex_new(num, 0.0))
      }
      String(text) =>
        if text == "" {
          ()
        } else {
          match parse_complex_text(text) {
            Ok(num) => product = complex_mul(product, num)
            Err(err) => return err
          }
        }
      List(_) => ()
    }
  }
  String(complex_to_string(product, "i"))
}

///|
fn eval_imreal(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] =>
      match parse_complex_value(v0) {
        Ok(num) => String(format_number(num.real))
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_imsec(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] =>
      match parse_complex_value_with_suffix(v0) {
        Ok((num, suffix)) => {
          let result = complex_div(complex_new(1.0, 0.0), complex_cos(num))
          String(complex_to_string(result, suffix))
        }
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_imsech(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] =>
      match parse_complex_value_with_suffix(v0) {
        Ok((num, suffix)) => {
          let result = complex_div(complex_new(1.0, 0.0), complex_cosh(num))
          String(complex_to_string(result, suffix))
        }
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_imsin(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] =>
      match parse_complex_value_with_suffix(v0) {
        Ok((num, suffix)) => String(complex_to_string(complex_sin(num), suffix))
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_imsinh(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] =>
      match parse_complex_value_with_suffix(v0) {
        Ok((num, suffix)) =>
          String(complex_to_string(complex_sinh(num), suffix))
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_imsqrt(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] =>
      match parse_complex_value_with_suffix(v0) {
        Ok((num, suffix)) =>
          String(complex_to_string(complex_sqrt(num), suffix))
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_imsub(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0, v1] =>
      match (parse_complex_value(v0), parse_complex_value(v1)) {
        (Ok(left), Ok(right)) =>
          String(complex_to_string(complex_sub(left, right), "i"))
        (Err(err), _) => err
        (_, Err(err)) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_imsum(call : EvalCall) -> FormulaValue {
  match call.values {
    [_, ..] => {
      let mut result = complex_new(0.0, 0.0)
      for value in flatten_values(call.values) {
        match value {
          Error(err) => return Error(err)
          _ =>
            match parse_complex_value(value) {
              Ok(num) => result = complex_add(result, num)
              Err(err) => return err
            }
        }
      }
      String(complex_to_string(result, "i"))
    }
    [] => Error(formula_error_value)
  }
}

///|
fn eval_imtan(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] =>
      match parse_complex_value_with_suffix(v0) {
        Ok((num, suffix)) => String(complex_to_string(complex_tan(num), suffix))
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_floor(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0, v1] =>
      match (value_as_number(v0), value_as_number(v1)) {
        (Ok(num), Ok(significance)) =>
          if significance < 0.0 && num >= 0.0 {
            Error(formula_error_num)
          } else {
            let (whole, frac) = modf_double(num / significance)
            let mut val = whole
            if frac != 0.0 && num < 0.0 && frac < 0.0 {
              val = val - 1.0
            }
            Number(val * significance)
          }
        (Err(err), _) => err
        (_, Err(err)) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_ceiling(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] | [v0, _] =>
      match value_as_number(v0) {
        Ok(num) => {
          let mut significance = if num < 0.0 { -1.0 } else { 1.0 }
          if call.values is [_, v1] {
            match value_as_number(v1) {
              Ok(value) => significance = value
              Err(err) => return err
            }
          }
          if significance < 0.0 && num > 0.0 {
            Error(formula_error_value)
          } else if call.values is [_] {
            Number(Double::ceil(num))
          } else {
            let (whole, frac) = modf_double(num / significance)
            let mut val = whole
            if frac > 0.0 {
              val = val + 1.0
            }
            Number(val * significance)
          }
        }
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_ceilingdotmath(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] =>
      match value_as_number(v0) {
        Ok(num) => Number(Double::ceil(num))
        Err(err) => err
      }
    [v0, v1] | [v0, v1, _] =>
      match value_as_number(v0) {
        Ok(num) => {
          let mut significance = if num < 0.0 { -1.0 } else { 1.0 }
          let mut mode = 1.0
          match value_as_number(v1) {
            Ok(value) => significance = value
            Err(err) => return err
          }
          if call.values is [_, _, v2] {
            match value_as_number(v2) {
              Ok(value) => mode = value
              Err(err) => return err
            }
          }
          let (whole, frac) = modf_double(num / significance)
          let mut val = whole
          if frac != 0.0 {
            if num > 0.0 {
              val = val + 1.0
            } else if mode < 0.0 {
              val = val - 1.0
            }
          }
          Number(val * significance)
        }
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_ceilingdotprecise(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] =>
      match value_as_number(v0) {
        Ok(num) => Number(Double::ceil(num))
        Err(err) => err
      }
    [v0, v1] =>
      match value_as_number(v0) {
        Ok(num) =>
          match value_as_number(v1) {
            Ok(significance) => {
              let abs_significance = abs_double(significance)
              if abs_significance == 0.0 {
                Number(0.0)
              } else {
                let (whole, frac) = modf_double(num / abs_significance)
                let mut val = whole
                if frac != 0.0 && num > 0.0 {
                  val = val + 1.0
                }
                Number(val * abs_significance)
              }
            }
            Err(err) => err
          }
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_floordotmath(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] =>
      match value_as_number(v0) {
        Ok(num) => Number(Double::floor(num))
        Err(err) => err
      }
    [v0, v1] | [v0, v1, _] =>
      match value_as_number(v0) {
        Ok(num) => {
          let mut significance = if num < 0.0 { -1.0 } else { 1.0 }
          let mut mode = 1.0
          match value_as_number(v1) {
            Ok(value) => significance = value
            Err(err) => return err
          }
          if call.values is [_, _, v2] {
            match value_as_number(v2) {
              Ok(value) => mode = value
              Err(err) => return err
            }
          }
          let (whole, frac) = modf_double(num / significance)
          let mut val = whole
          if frac != 0.0 && num < 0.0 && mode > 0.0 {
            val = val - 1.0
          }
          Number(val * significance)
        }
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_floordotprecise(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] =>
      match value_as_number(v0) {
        Ok(num) => Number(Double::floor(num))
        Err(err) => err
      }
    [v0, v1] =>
      match value_as_number(v0) {
        Ok(num) =>
          match value_as_number(v1) {
            Ok(significance) => {
              let abs_significance = abs_double(significance)
              if abs_significance == 0.0 {
                Number(0.0)
              } else {
                let (whole, frac) = modf_double(num / abs_significance)
                let mut val = whole
                if frac != 0.0 && num < 0.0 {
                  val = val - 1.0
                }
                Number(val * abs_significance)
              }
            }
            Err(err) => err
          }
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_isodotceiling(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] =>
      match value_as_number(v0) {
        Ok(num) => Number(Double::ceil(num))
        Err(err) => err
      }
    [v0, v1] =>
      match value_as_number(v0) {
        Ok(num) =>
          match value_as_number(v1) {
            Ok(significance) => {
              let abs_significance = abs_double(significance)
              if abs_significance == 0.0 {
                Number(0.0)
              } else {
                let (whole, frac) = modf_double(num / abs_significance)
                let mut val = whole
                if frac != 0.0 && num > 0.0 {
                  val = val + 1.0
                }
                Number(val * abs_significance)
              }
            }
            Err(err) => err
          }
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_trunc(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] | [v0, _] =>
      match value_as_number(v0) {
        Ok(num) => {
          let digits = if call.values is [_, v1] {
            match value_as_number(v1) {
              Ok(value) => Double::to_int(value)
              Err(err) => return err
            }
          } else {
            0
          }
          Number(round_down_with_digits(num, digits))
        }
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_round(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0, v1] =>
      match (value_as_number(v0), value_as_number(v1)) {
        (Ok(num), Ok(digits)) =>
          Number(round_with_digits(num, Double::to_int(digits)))
        (Err(err), _) => err
        (_, Err(err)) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_roundup(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0, v1] =>
      match (value_as_number(v0), value_as_number(v1)) {
        (Ok(num), Ok(digits)) =>
          Number(round_up_with_digits(num, Double::to_int(digits)))
        (Err(err), _) => err
        (_, Err(err)) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_rounddown(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0, v1] =>
      match (value_as_number(v0), value_as_number(v1)) {
        (Ok(num), Ok(digits)) =>
          Number(round_down_with_digits(num, Double::to_int(digits)))
        (Err(err), _) => err
        (_, Err(err)) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_sqrt(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] =>
      match value_as_number(v0) {
        Ok(num) =>
          if num < 0.0 {
            Error(formula_error_num)
          } else {
            Number(@math.pow(num, 0.5))
          }
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_power(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0, v1] =>
      match (value_as_number(v0), value_as_number(v1)) {
        (Ok(lhs), Ok(rhs)) => Number(@math.pow(lhs, rhs))
        (Err(err), _) => err
        (_, Err(err)) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_even(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] =>
      match value_as_number(v0) {
        Ok(num) => {
          let sign = num < 0.0
          let (whole, frac) = modf_double(num / 2.0)
          let mut val = whole * 2.0
          if frac != 0.0 {
            if sign {
              val = val - 2.0
            } else {
              val = val + 2.0
            }
          }
          Number(val)
        }
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_odd(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] =>
      match value_as_number(v0) {
        Ok(num) =>
          if num == 0.0 {
            Number(1.0)
          } else {
            let sign = num < 0.0
            let (whole, frac) = modf_double((num - 1.0) / 2.0)
            let mut val = whole * 2.0 + 1.0
            if frac != 0.0 {
              if sign {
                val = val - 2.0
              } else {
                val = val + 2.0
              }
            }
            Number(val)
          }
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_mround(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0, v1] =>
      match (value_as_number(v0), value_as_number(v1)) {
        (Ok(num), Ok(multiple)) =>
          if multiple == 0.0 {
            Error(formula_error_num)
          } else if (multiple < 0.0 && num > 0.0) ||
            (multiple > 0.0 && num < 0.0) {
            Error(formula_error_num)
          } else {
            let (whole, frac) = modf_double(num / multiple)
            let mut rounded = whole
            if trunc_double(frac + 0.5) > 0.0 {
              rounded = rounded + 1.0
            }
            Number(rounded * multiple)
          }
        (Err(err), _) => err
        (_, Err(err)) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_mod(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0, v1] =>
      match (value_as_number(v0), value_as_number(v1)) {
        (Ok(num), Ok(divisor)) =>
          if divisor == 0.0 {
            Error(formula_error_div)
          } else {
            let quotient = num / divisor
            let truncated = Double::floor(quotient)
            Number(num - divisor * truncated)
          }
        (Err(err), _) => err
        (_, Err(err)) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_quotient(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0, v1] =>
      match (value_as_number(v0), value_as_number(v1)) {
        (Ok(num), Ok(divisor)) =>
          if divisor == 0.0 {
            Error(formula_error_div)
          } else {
            Number(trunc_double(num / divisor))
          }
        (Err(err), _) => err
        (_, Err(err)) => err
      }
    _ => Error(formula_error_value)
  }
}
