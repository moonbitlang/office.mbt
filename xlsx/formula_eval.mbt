///|
fn eval_defined_name_ref(
  workbook : Workbook,
  sheet_name : String,
  defined_name : DefinedName,
  ctx : CalcContext,
) -> FormulaValue raise XlsxError {
  let scope_key = defined_name_scope_key(defined_name.scope)
  let workbook_key = defined_name_scope_key("Workbook")
  let target_sheet = if scope_key == workbook_key {
    sheet_name
  } else {
    defined_name.scope
  }
  let expr = parse_formula_expr(defined_name.refers_to) catch {
    _ => return Error(formula_error_value)
  }
  eval_expr(workbook, target_sheet, expr, ctx)
}

///|
fn find_defined_name(
  workbook : Workbook,
  sheet_name : String,
  name : String,
) -> DefinedName? {
  let name_upper = name.to_upper()
  let sheet_key = defined_name_scope_key(sheet_name)
  let workbook_key = defined_name_scope_key("Workbook")
  let mut workbook_match : DefinedName? = None
  for defined_name in workbook.defined_names {
    if defined_name.name.to_upper() != name_upper {
      continue
    }
    let scope_key = defined_name_scope_key(defined_name.scope)
    if scope_key == sheet_key {
      return Some(defined_name)
    }
    if scope_key == workbook_key {
      workbook_match = Some(defined_name)
    }
  }
  workbook_match
}

///|
fn defined_name_expr(
  workbook : Workbook,
  sheet_name : String,
  name : String,
) -> Expr? {
  match find_defined_name(workbook, sheet_name, name) {
    Some(value) => {
      let expr = parse_formula_expr(value.refers_to) catch { _ => return None }
      Some(expr)
    }
    None => None
  }
}

///|
fn defined_name_value(
  workbook : Workbook,
  sheet_name : String,
  name : String,
  ctx : CalcContext,
) -> FormulaValue? raise XlsxError {
  match find_defined_name(workbook, sheet_name, name) {
    Some(value) => Some(eval_defined_name_ref(workbook, sheet_name, value, ctx))
    None => None
  }
}

///|
fn anchorarray_values(
  workbook : Workbook,
  sheet_name : String,
  args : ArrayView[Expr],
  values : ArrayView[FormulaValue],
) -> FormulaValue {
  if args.length() != 1 {
    return Error(formula_error_value)
  }
  let (target_sheet, reference) = match args[0] {
    Cell(sheet, reference) =>
      if sheet == "" {
        (sheet_name, reference)
      } else {
        (sheet, reference)
      }
    _ => return Error(formula_error_value)
  }
  let sheet = match workbook.sheet(target_sheet) {
    Some(value) => value
    None => return Error(formula_error_value)
  }
  let formula = sheet.get_cell_formula(reference) catch {
    _ => return Error(formula_error_value)
  }
  match formula {
    None => Empty
    Some(_) =>
      match values[0] {
        Error(err) => Error(err)
        List(list) => List(list)
        _ => List([values[0]])
      }
  }
}

///|
fn range_vector(range : RangeValues) -> Array[FormulaValue]? {
  if range.rows == 1 {
    let out : Array[FormulaValue] = []
    for col in 0..<range.cols {
      out.push(range.values[col])
    }
    Some(out)
  } else if range.cols == 1 {
    let out : Array[FormulaValue] = []
    for row in 0..<range.rows {
      out.push(range.values[row * range.cols])
    }
    Some(out)
  } else {
    None
  }
}

///|
fn range_column(range : RangeValues, index : Int) -> Array[FormulaValue]? {
  if index < 0 || index >= range.cols {
    return None
  }
  let out : Array[FormulaValue] = []
  for row in 0..<range.rows {
    out.push(range.values[row * range.cols + index])
  }
  Some(out)
}

///|
fn range_row(range : RangeValues, index : Int) -> Array[FormulaValue]? {
  if index < 0 || index >= range.rows {
    return None
  }
  let out : Array[FormulaValue] = []
  let offset = index * range.cols
  for col in 0..<range.cols {
    out.push(range.values[offset + col])
  }
  Some(out)
}

///|
fn transpose_range_values(range : RangeValues) -> RangeValues {
  let out : Array[FormulaValue] = []
  for col in 0..<range.cols {
    for row in 0..<range.rows {
      out.push(range.values[row * range.cols + col])
    }
  }
  { values: out, rows: range.cols, cols: range.rows }
}

///|
fn is_munit_func(name : String) -> Bool {
  name == "MUNIT" || name == "_XLFN.MUNIT"
}

///|
fn munit_dimension(value : FormulaValue) -> Result[Int, FormulaValue] {
  match value_as_number(value) {
    Ok(num) =>
      if num < 0.0 {
        Err(Error(formula_error_value))
      } else {
        Ok(Double::to_int(trunc_double(num)))
      }
    Err(err) => Err(err)
  }
}

///|
fn munit_range_values(dimension : Int) -> RangeValues {
  let out : Array[FormulaValue] = []
  for row in 0..<dimension {
    for col in 0..<dimension {
      let value = if row == col { 1.0 } else { 0.0 }
      out.push(Number(value))
    }
  }
  { values: out, rows: dimension, cols: dimension }
}

///|
fn munit_range_values_from_expr(
  workbook : Workbook,
  sheet_name : String,
  args : Array[Expr],
  ctx : CalcContext,
) -> RangeValues raise XlsxError {
  if args.length() != 1 {
    return { values: [Error(formula_error_value)], rows: 1, cols: 1 }
  }
  let dimension_value = eval_expr(workbook, sheet_name, args[0], ctx)
  match munit_dimension(dimension_value) {
    Ok(dimension) => munit_range_values(dimension)
    Err(err) => { values: [err], rows: 1, cols: 1 }
  }
}

///|
fn transpose_range_values_from_expr(
  workbook : Workbook,
  sheet_name : String,
  args : Array[Expr],
  ctx : CalcContext,
) -> RangeValues raise XlsxError {
  if args.length() != 1 {
    return { values: [Error(formula_error_value)], rows: 1, cols: 1 }
  }
  let arg_expr = args[0]
  let arg_value = eval_expr(workbook, sheet_name, arg_expr, ctx)
  let base_range = range_from_expr_or_value(
    workbook, sheet_name, arg_expr, arg_value, ctx,
  )
  transpose_range_values(base_range)
}

///|
fn number_matrix_from_range(
  range : RangeValues,
  require_square : Bool,
) -> Result[Array[Array[Double]], FormulaValue] {
  if range.rows <= 0 || range.cols <= 0 {
    return Err(Error(formula_error_value))
  }
  if require_square && range.rows != range.cols {
    return Err(Error(formula_error_value))
  }
  let out : Array[Array[Double]] = []
  for row in 0..<range.rows {
    let row_values : Array[Double] = []
    let offset = row * range.cols
    for col in 0..<range.cols {
      let value = range.values[offset + col]
      match value {
        Number(num) => row_values.push(num)
        Bool(flag) => row_values.push(if flag { 1.0 } else { 0.0 })
        _ => return Err(Error(formula_error_value))
      }
    }
    out.push(row_values)
  }
  Ok(out)
}

///|
fn matrix_minor(
  matrix : Array[Array[Double]],
  index : Int,
) -> Array[Array[Double]] {
  let out : Array[Array[Double]] = []
  for row in 0..<matrix.length() {
    if row == 0 {
      continue
    }
    let values : Array[Double] = []
    for col in 0..<matrix[row].length() {
      if col == index {
        continue
      }
      values.push(matrix[row][col])
    }
    out.push(values)
  }
  out
}

///|
fn matrix_det(matrix : Array[Array[Double]]) -> Double {
  if matrix.length() == 2 {
    let m00 = matrix[0][0]
    let m01 = matrix[0][1]
    let m10 = matrix[1][0]
    let m11 = matrix[1][1]
    return m00 * m11 - m10 * m01
  }
  let mut result = 0.0
  let mut sign = 1.0
  for col in 0..<matrix.length() {
    result = result +
      sign * matrix[0][col] * matrix_det(matrix_minor(matrix, col))
    sign = sign * -1.0
  }
  result
}

///|
fn matrix_minor_at(
  matrix : Array[Array[Double]],
  remove_row : Int,
  remove_col : Int,
) -> Array[Array[Double]] {
  let out : Array[Array[Double]] = []
  for row in 0..<matrix.length() {
    if row == remove_row {
      continue
    }
    let values : Array[Double] = []
    for col in 0..<matrix[row].length() {
      if col == remove_col {
        continue
      }
      values.push(matrix[row][col])
    }
    out.push(values)
  }
  out
}

///|
fn matrix_cofactor(
  matrix : Array[Array[Double]],
  row : Int,
  col : Int,
) -> Double {
  let sign = if (row + col) % 2 == 0 { 1.0 } else { -1.0 }
  sign * matrix_det(matrix_minor_at(matrix, row, col))
}

///|
fn matrix_adjugate(matrix : Array[Array[Double]]) -> Array[Array[Double]] {
  let size = matrix.length()
  let out : Array[Array[Double]] = []
  for _ in 0..<size {
    out.push(Array::make(size, 0.0))
  }
  for row in 0..<size {
    for col in 0..<size {
      out[row][col] = matrix_cofactor(matrix, col, row)
    }
  }
  out
}

///|
fn matrix_values(matrix : Array[Array[Double]]) -> Array[FormulaValue] {
  let out : Array[FormulaValue] = []
  for row in 0..<matrix.length() {
    for col in 0..<matrix[row].length() {
      out.push(Number(matrix[row][col]))
    }
  }
  out
}

///|
fn matrix_multiply(
  left : Array[Array[Double]],
  right : Array[Array[Double]],
) -> Result[Array[Array[Double]], FormulaValue] {
  let rows = left.length()
  let cols = left[0].length()
  let right_rows = right.length()
  let right_cols = right[0].length()
  if cols != right_rows {
    return Err(Error(formula_error_value))
  }
  let out : Array[Array[Double]] = []
  for row in 0..<rows {
    let values = Array::make(right_cols, 0.0)
    for col in 0..<right_cols {
      let mut sum = 0.0
      for idx in 0..<right_rows {
        sum = sum + left[row][idx] * right[idx][col]
      }
      values[col] = sum
    }
    out.push(values)
  }
  Ok(out)
}

///|
fn new_matrix(cols : Int, rows : Int) -> Array[Array[Double]] {
  if cols <= 0 || rows <= 0 {
    return []
  }
  let out : Array[Array[Double]] = []
  for _ in 0..<cols {
    out.push(Array::make(rows, 0.0))
  }
  out
}

///|
fn approx_sub(a : Double, b : Double) -> Double {
  if ((a < 0.0 && b < 0.0) || (a > 0.0 && b > 0.0)) &&
    Double::abs(a - b) < 2.22045e-016 {
    0.0
  } else {
    a - b
  }
}

///|
fn matrix_clone(matrix : Array[Array[Double]]) -> Array[Array[Double]] {
  let out : Array[Array[Double]] = []
  for col in 0..<matrix.length() {
    let column = matrix[col]
    let copy = Array::make(column.length(), 0.0)
    for row in 0..<column.length() {
      copy[row] = column[row]
    }
    out.push(copy)
  }
  out
}

///|
fn transpose_number_matrix(
  matrix : Array[Array[Double]],
) -> Array[Array[Double]] {
  let out : Array[Array[Double]] = []
  for row in 0..<matrix.length() {
    for col in 0..<matrix[row].length() {
      while out.length() <= col {
        out.push([])
      }
      let column = out[col]
      while column.length() <= row {
        column.push(0.0)
      }
      column[row] = matrix[row][col]
    }
  }
  out
}

///|
priv struct TrendGrowthMatrixInfo {
  trend_type : Int
  n_cx : Int
  n_rx : Int
  m : Int
  n : Int
  mtx_x : Array[Array[Double]]
  mtx_y : Array[Array[Double]]
}

///|
fn prepare_trend_growth_mtx_x(
  mtx_x : Array[Array[Double]],
) -> Result[Array[Array[Double]], FormulaValue] {
  let out : Array[Array[Double]] = []
  for row in 0..<mtx_x.length() {
    for col in 0..<mtx_x[row].length() {
      let value = mtx_x[row][col]
      if value == 0.0 {
        return Err(Error(formula_error_num))
      }
      while out.length() <= col {
        out.push([])
      }
      let column = out[col]
      while column.length() <= row {
        column.push(0.0)
      }
      column[row] = value
    }
  }
  Ok(out)
}

///|
fn prepare_trend_growth_mtx_y(
  b_log : Bool,
  mtx_y : Array[Array[Double]],
) -> Result[Array[Array[Double]], FormulaValue] {
  let out : Array[Array[Double]] = []
  for row in 0..<mtx_y.length() {
    for col in 0..<mtx_y[row].length() {
      let value = mtx_y[row][col]
      if value == 0.0 {
        return Err(Error(formula_error_num))
      }
      while out.length() <= col {
        out.push([])
      }
      let column = out[col]
      while column.length() <= row {
        column.push(0.0)
      }
      column[row] = value
    }
  }
  if !b_log {
    return Ok(out)
  }
  let log_out : Array[Array[Double]] = []
  for row in 0..<mtx_y.length() {
    for col in 0..<mtx_y[row].length() {
      let value = mtx_y[row][col]
      if value <= 0.0 {
        return Err(Error(formula_error_num))
      }
      while log_out.length() <= col {
        log_out.push([])
      }
      let column = log_out[col]
      while column.length() <= row {
        column.push(0.0)
      }
      column[row] = @math.ln(value)
    }
  }
  Ok(log_out)
}

///|
fn prepare_trend_growth(
  b_log : Bool,
  mtx_x : Array[Array[Double]],
  mtx_y : Array[Array[Double]],
) -> Result[TrendGrowthMatrixInfo, FormulaValue] {
  let n_ry = mtx_y.length()
  let n_cy = mtx_y[0].length()
  let cnt_y = n_cy * n_ry
  let new_y = match prepare_trend_growth_mtx_y(b_log, mtx_y) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let mut new_x : Array[Array[Double]] = []
  let mut n_rx = 0
  let mut n_cx = 0
  let mut trend_type = 0
  let mut m = 0
  let mut n = 0
  if mtx_x.length() != 0 {
    n_rx = mtx_x.length()
    n_cx = mtx_x[0].length()
    new_x = match prepare_trend_growth_mtx_x(mtx_x) {
      Ok(value) => value
      Err(err) => return Err(err)
    }
    if n_cx == n_cy && n_rx == n_ry {
      trend_type = 1
      m = 1
      n = cnt_y
    } else if n_cy != 1 && n_ry != 1 {
      return Err(Error(formula_error_ref))
    } else if n_cy == 1 {
      if n_rx != n_ry {
        return Err(Error(formula_error_ref))
      }
      trend_type = 2
      m = n_cx
      n = n_ry
    } else if n_cx != n_cy {
      return Err(Error(formula_error_ref))
    } else {
      trend_type = 3
      m = n_rx
      n = n_cy
    }
  } else {
    new_x = new_matrix(n_cy, n_ry)
    n_cx = n_cy
    n_rx = n_ry
    let mut value = 1.0
    for row in 0..<n_ry {
      for col in 0..<n_cy {
        new_x[col][row] = value
        value = value + 1.0
      }
    }
    trend_type = 1
    m = 1
    n = cnt_y
  }
  Ok({ trend_type, n_cx, n_rx, m, n, mtx_x: new_x, mtx_y: new_y })
}

///|
fn calc_position(mtx : Array[Array[Double]], idx : Int) -> (Int, Int) {
  let row_size = mtx[0].length()
  let col = if row_size > 1 { idx / row_size } else { idx }
  let row = idx - col * row_size
  (row, col)
}

///|
fn get_double(mtx : Array[Array[Double]], idx : Int) -> Double {
  let (row, col) = calc_position(mtx, idx)
  mtx[col][row]
}

///|
fn put_double(mtx : Array[Array[Double]], idx : Int, value : Double) -> Unit {
  let (row, col) = calc_position(mtx, idx)
  mtx[col][row] = value
}

///|
fn calc_mean_over_all(mtx : Array[Array[Double]], n : Int) -> Double {
  let mut sum = 0.0
  for col in 0..<mtx.length() {
    for row in 0..<mtx[col].length() {
      sum = sum + mtx[col][row]
    }
  }
  sum / Double::from_int(n)
}

///|
fn calc_sum_product(
  mtx_a : Array[Array[Double]],
  mtx_b : Array[Array[Double]],
  m : Int,
) -> Double {
  let mut sum = 0.0
  for idx in 0..<m {
    sum = sum + get_double(mtx_a, idx) * get_double(mtx_b, idx)
  }
  sum
}

///|
fn calc_column_means(
  mtx_x : Array[Array[Double]],
  mtx_res : Array[Array[Double]],
  c : Int,
  r : Int,
) -> Unit {
  for i in 0..<c {
    let mut sum = 0.0
    for k in 0..<r {
      sum = sum + mtx_x[i][k]
    }
    put_double(mtx_res, i, sum / Double::from_int(r))
  }
}

///|
fn calc_columns_delta(
  mtx : Array[Array[Double]],
  column_means : Array[Array[Double]],
  c : Int,
  r : Int,
) -> Unit {
  for i in 0..<c {
    for k in 0..<r {
      mtx[i][k] = approx_sub(mtx[i][k], get_double(column_means, i))
    }
  }
}

///|
fn calc_sign(value : Double) -> Double {
  if value > 0.0 {
    1.0
  } else {
    -1.0
  }
}

///|
fn calc_cols_maximum_norm(
  mtx_a : Array[Array[Double]],
  c : Int,
  r : Int,
  n : Int,
) -> Double {
  let mut norm = 0.0
  for row in r..<n {
    let value = Double::abs(mtx_a[c][row])
    if norm < value {
      norm = value
    }
  }
  norm
}

///|
fn calc_fast_mult(
  mtx_a : Array[Array[Double]],
  mtx_b : Array[Array[Double]],
  mtx_r : Array[Array[Double]],
  n : Int,
  m : Int,
  l : Int,
) -> Unit {
  for row in 0..<n {
    for col in 0..<l {
      let mut sum = 0.0
      for k in 0..<m {
        sum = sum + mtx_a[k][row] * mtx_b[col][k]
      }
      mtx_r[col][row] = sum
    }
  }
}

///|
fn calc_rows_euclidean_norm(
  mtx_a : Array[Array[Double]],
  c : Int,
  r : Int,
  n : Int,
) -> Double {
  let mut norm = 0.0
  for row in r..<n {
    let value = mtx_a[c][row]
    norm = norm + value * value
  }
  Double::sqrt(norm)
}

///|
fn calc_rows_sum_product(
  mtx_a : Array[Array[Double]],
  a : Int,
  mtx_b : Array[Array[Double]],
  b : Int,
  r : Int,
  n : Int,
) -> Double {
  let mut result = 0.0
  for row in r..<n {
    result = result + mtx_a[a][row] * mtx_b[b][row]
  }
  result
}

///|
fn calc_solve_with_upper_right_triangle(
  mtx_a : Array[Array[Double]],
  vec_r : Array[Double],
  mtx_s : Array[Array[Double]],
  k : Int,
  b_is_transposed : Bool,
) -> Unit {
  for idx in 0..<k {
    let row_p1 = k - idx
    let row = row_p1 - 1
    let mut sum = get_double(mtx_s, row)
    for col in row_p1..<k {
      if b_is_transposed {
        sum = sum - mtx_a[row][col] * get_double(mtx_s, col)
      } else {
        sum = sum - mtx_a[col][row] * get_double(mtx_s, col)
      }
    }
    put_double(mtx_s, row, sum / vec_r[row])
  }
}

///|
fn calc_row_qr_decomposition(
  mtx_a : Array[Array[Double]],
  vec_r : Array[Double],
  k : Int,
  n : Int,
) -> Bool {
  for col in 0..<k {
    let scale = calc_cols_maximum_norm(mtx_a, col, col, n)
    if scale == 0.0 {
      return false
    }
    for row in col..<n {
      mtx_a[col][row] = mtx_a[col][row] / scale
    }
    let euclid = calc_rows_euclidean_norm(mtx_a, col, col, n)
    let factor = 1.0 / euclid / (euclid + Double::abs(mtx_a[col][col]))
    let signum = calc_sign(mtx_a[col][col])
    mtx_a[col][col] = mtx_a[col][col] + signum * euclid
    vec_r[col] = -signum * scale * euclid
    for c in (col + 1)..<k {
      let sum = calc_rows_sum_product(mtx_a, col, mtx_a, c, col, n)
      for row in col..<n {
        mtx_a[c][row] = mtx_a[c][row] - sum * factor * mtx_a[col][row]
      }
    }
  }
  true
}

///|
fn calc_apply_cols_householder_transformation(
  mtx_a : Array[Array[Double]],
  r : Int,
  mtx_y : Array[Array[Double]],
  n : Int,
) -> Unit {
  let denominator = calc_cols_sum_product(mtx_a, r, mtx_a, r, r, n)
  let numerator = calc_cols_sum_product(mtx_a, r, mtx_y, 0, r, n)
  let factor = 2.0 * (numerator / denominator)
  for col in r..<n {
    put_double(mtx_y, col, get_double(mtx_y, col) - factor * mtx_a[col][r])
  }
}

///|
fn calc_row_means(
  mtx_x : Array[Array[Double]],
  mtx_res : Array[Array[Double]],
  c : Int,
  r : Int,
) -> Unit {
  for k in 0..<r {
    let mut sum = 0.0
    for i in 0..<c {
      sum = sum + mtx_x[i][k]
    }
    mtx_res[k][0] = sum / Double::from_int(c)
  }
}

///|
fn calc_rows_delta(
  mtx : Array[Array[Double]],
  row_means : Array[Array[Double]],
  c : Int,
  r : Int,
) -> Unit {
  for k in 0..<r {
    for i in 0..<c {
      mtx[i][k] = approx_sub(mtx[i][k], row_means[k][0])
    }
  }
}

///|
fn calc_column_maximum_norm(
  mtx_a : Array[Array[Double]],
  r : Int,
  c : Int,
  n : Int,
) -> Double {
  let mut norm = 0.0
  for col in c..<n {
    let value = Double::abs(mtx_a[col][r])
    if norm < value {
      norm = value
    }
  }
  norm
}

///|
fn calc_cols_euclidean_norm(
  mtx_a : Array[Array[Double]],
  r : Int,
  c : Int,
  n : Int,
) -> Double {
  let mut norm = 0.0
  for col in c..<n {
    let value = mtx_a[col][r]
    norm = norm + value * value
  }
  Double::sqrt(norm)
}

///|
fn calc_cols_sum_product(
  mtx_a : Array[Array[Double]],
  a : Int,
  mtx_b : Array[Array[Double]],
  b : Int,
  c : Int,
  n : Int,
) -> Double {
  let mut result = 0.0
  for col in c..<n {
    result = result + mtx_a[col][a] * mtx_b[col][b]
  }
  result
}

///|
fn calc_col_qr_decomposition(
  mtx_a : Array[Array[Double]],
  vec_r : Array[Double],
  k : Int,
  n : Int,
) -> Bool {
  for row in 0..<k {
    let scale = calc_column_maximum_norm(mtx_a, row, row, n)
    if scale == 0.0 {
      return false
    }
    for col in row..<n {
      mtx_a[col][row] = mtx_a[col][row] / scale
    }
    let euclid = calc_cols_euclidean_norm(mtx_a, row, row, n)
    let factor = 1.0 / euclid / (euclid + Double::abs(mtx_a[row][row]))
    let signum = calc_sign(mtx_a[row][row])
    mtx_a[row][row] = mtx_a[row][row] + signum * euclid
    vec_r[row] = -signum * scale * euclid
    for r in (row + 1)..<k {
      let sum = calc_cols_sum_product(mtx_a, row, mtx_a, r, row, n)
      for col in row..<n {
        mtx_a[col][r] = mtx_a[col][r] - sum * factor * mtx_a[col][row]
      }
    }
  }
  true
}

///|
fn calc_apply_rows_householder_transformation(
  mtx_a : Array[Array[Double]],
  c : Int,
  mtx_y : Array[Array[Double]],
  n : Int,
) -> Unit {
  let denominator = calc_rows_sum_product(mtx_a, c, mtx_a, c, c, n)
  let numerator = calc_rows_sum_product(mtx_a, c, mtx_y, 0, c, n)
  let factor = 2.0 * (numerator / denominator)
  for row in c..<n {
    put_double(mtx_y, row, get_double(mtx_y, row) - factor * mtx_a[c][row])
  }
}

///|
fn calc_trend_growth_simple_regression(
  b_constant : Bool,
  b_growth : Bool,
  mtx_y : Array[Array[Double]],
  mtx_x : Array[Array[Double]],
  new_x : Array[Array[Double]],
  mtx_res : Array[Array[Double]],
  mean_y : Double,
  n : Int,
) -> Unit {
  let mut mean_x = 0.0
  if b_constant {
    mean_x = calc_mean_over_all(mtx_x, n)
    for col in 0..<mtx_x.length() {
      for row in 0..<mtx_x[col].length() {
        mtx_x[col][row] = approx_sub(mtx_x[col][row], mean_x)
      }
    }
  }
  let sum_xy = calc_sum_product(mtx_x, mtx_y, n)
  let sum_x2 = calc_sum_product(mtx_x, mtx_x, n)
  let slope = sum_xy / sum_x2
  if b_constant {
    let intercept = mean_y - slope * mean_x
    for col in 0..<mtx_res.length() {
      for row in 0..<mtx_res[col].length() {
        let help = new_x[col][row] * slope + intercept
        mtx_res[col][row] = if b_growth { @math.exp(help) } else { help }
      }
    }
  } else {
    for col in 0..<mtx_res.length() {
      for row in 0..<mtx_res[col].length() {
        let help = new_x[col][row] * slope
        mtx_res[col][row] = if b_growth { @math.exp(help) } else { help }
      }
    }
  }
}

///|
fn calc_trend_growth_multiple_regression_part1(
  b_constant : Bool,
  b_growth : Bool,
  mtx_y : Array[Array[Double]],
  mtx_x : Array[Array[Double]],
  new_x : Array[Array[Double]],
  mtx_res : Array[Array[Double]],
  mean_y : Double,
  r_xn : Int,
  k : Int,
  n : Int,
) -> Unit {
  let vec_r = Array::make(n, 0.0)
  let means = new_matrix(k, 1)
  let slopes = new_matrix(1, k)
  if means.length() == 0 || slopes.length() == 0 {
    return
  }
  if b_constant {
    calc_column_means(mtx_x, means, k, n)
    calc_columns_delta(mtx_x, means, k, n)
  }
  if !calc_row_qr_decomposition(mtx_x, vec_r, k, n) {
    return
  }
  let mut is_singular = false
  for row in 0..<k {
    if vec_r[row] == 0.0 {
      is_singular = true
    }
  }
  if is_singular {
    return
  }
  for col in 0..<k {
    calc_apply_rows_householder_transformation(mtx_x, col, mtx_y, n)
  }
  for col in 0..<k {
    put_double(slopes, col, get_double(mtx_y, col))
  }
  calc_solve_with_upper_right_triangle(mtx_x, vec_r, slopes, k, false)
  calc_fast_mult(new_x, slopes, mtx_res, r_xn, k, 1)
  if b_constant {
    let intercept = mean_y - calc_sum_product(means, slopes, k)
    for row in 0..<r_xn {
      mtx_res[0][row] = mtx_res[0][row] + intercept
    }
  }
  if b_growth {
    for idx in 0..<r_xn {
      put_double(mtx_res, idx, @math.exp(get_double(mtx_res, idx)))
    }
  }
}

///|
fn calc_trend_growth_multiple_regression_part2(
  b_constant : Bool,
  b_growth : Bool,
  mtx_y : Array[Array[Double]],
  mtx_x : Array[Array[Double]],
  new_x : Array[Array[Double]],
  mtx_res : Array[Array[Double]],
  mean_y : Double,
  n_cxn : Int,
  k : Int,
  n : Int,
) -> Unit {
  let vec_r = Array::make(n, 0.0)
  let means = new_matrix(k, 1)
  let slopes = new_matrix(k, 1)
  if means.length() == 0 || slopes.length() == 0 {
    return
  }
  if b_constant {
    calc_row_means(mtx_x, means, n, k)
    calc_rows_delta(mtx_x, means, n, k)
  }
  if !calc_col_qr_decomposition(mtx_x, vec_r, k, n) {
    return
  }
  let mut is_singular = false
  for row in 0..<k {
    if vec_r[row] == 0.0 {
      is_singular = true
    }
  }
  if is_singular {
    return
  }
  for row in 0..<k {
    calc_apply_cols_householder_transformation(mtx_x, row, mtx_y, n)
  }
  for col in 0..<k {
    put_double(slopes, col, get_double(mtx_y, col))
  }
  calc_solve_with_upper_right_triangle(mtx_x, vec_r, slopes, k, true)
  calc_fast_mult(slopes, new_x, mtx_res, 1, k, n_cxn)
  if b_constant {
    let intercept = mean_y - calc_sum_product(means, slopes, k)
    for col in 0..<n_cxn {
      mtx_res[col][0] = mtx_res[col][0] + intercept
    }
  }
  if b_growth {
    for idx in 0..<n_cxn {
      put_double(mtx_res, idx, @math.exp(get_double(mtx_res, idx)))
    }
  }
}

///|
fn calc_trend_growth_regression(
  b_constant : Bool,
  b_growth : Bool,
  trend_type : Int,
  n_cxn : Int,
  n_rxn : Int,
  k : Int,
  n : Int,
  mtx_y : Array[Array[Double]],
  mtx_x : Array[Array[Double]],
  new_x : Array[Array[Double]],
  mtx_res : Array[Array[Double]],
) -> Unit {
  if mtx_res.length() == 0 {
    return
  }
  let mut mean_y = 0.0
  let mut work_x = mtx_x
  let mut work_y = mtx_y
  if b_constant {
    work_x = matrix_clone(mtx_x)
    work_y = matrix_clone(mtx_y)
    mean_y = calc_mean_over_all(work_y, n)
    for col in 0..<work_y.length() {
      for row in 0..<work_y[col].length() {
        work_y[col][row] = approx_sub(work_y[col][row], mean_y)
      }
    }
  }
  match trend_type {
    1 =>
      calc_trend_growth_simple_regression(
        b_constant, b_growth, work_y, work_x, new_x, mtx_res, mean_y, n,
      )
    2 =>
      calc_trend_growth_multiple_regression_part1(
        b_constant, b_growth, work_y, work_x, new_x, mtx_res, mean_y, n_rxn, k, n,
      )
    _ =>
      calc_trend_growth_multiple_regression_part2(
        b_constant, b_growth, work_y, work_x, new_x, mtx_res, mean_y, n_cxn, k, n,
      )
  }
}

///|
fn calc_trend_growth(
  mtx_y : Array[Array[Double]],
  mtx_x : Array[Array[Double]],
  new_x : Array[Array[Double]],
  b_constant : Bool,
  b_growth : Bool,
) -> Result[Array[Array[Double]], FormulaValue] {
  let info = match prepare_trend_growth(b_growth, mtx_x, mtx_y) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let trend_type = info.trend_type
  let mut n_cxn = info.n_cx
  let mut n_rxn = info.n_rx
  let k = info.m
  let n = info.n
  let work_x = info.mtx_x
  let work_y = info.mtx_y
  if (b_constant && n < k + 1) || (!b_constant && n < k) || n < 1 || k < 1 {
    return Ok([])
  }
  let mut work_new_x = new_x
  if work_new_x.length() == 0 {
    work_new_x = matrix_clone(work_x)
  } else {
    n_rxn = work_new_x[0].length()
    n_cxn = work_new_x.length()
    if (trend_type == 2 && k != n_cxn) || (trend_type == 3 && k != n_rxn) {
      return Ok([])
    }
  }
  let mtx_res = match trend_type {
    1 => new_matrix(n_cxn, n_rxn)
    2 => new_matrix(1, n_rxn)
    _ => new_matrix(n_cxn, 1)
  }
  calc_trend_growth_regression(
    b_constant, b_growth, trend_type, n_cxn, n_rxn, k, n, work_y, work_x, work_new_x,
    mtx_res,
  )
  Ok(mtx_res)
}

///|
fn unique_row_key(
  range : RangeValues,
  row : Int,
) -> Result[String, FormulaValue] {
  let sb = StringBuilder::new()
  let start = row * range.cols
  for col in 0..<range.cols {
    let value = range.values[start + col]
    match normalize_scalar(value) {
      Error(err) => return Err(Error(err))
      _ => sb.write_view(formula_value_string(value))
    }
  }
  Ok(sb.to_string())
}

///|
fn unique_range_values(
  range : RangeValues,
  by_col : Bool,
  exactly_once : Bool,
) -> Result[RangeValues, FormulaValue] {
  let base = if by_col { transpose_range_values(range) } else { range }
  let counts : Map[String, Int] = {}
  for row in 0..<base.rows {
    let key = match unique_row_key(base, row) {
      Ok(value) => value
      Err(err) => return Err(err)
    }
    match counts.get(key) {
      Some(count) => counts[key] = count + 1
      None => counts[key] = 1
    }
  }
  let out : Array[FormulaValue] = []
  let mut kept_rows = 0
  for row in 0..<base.rows {
    let key = match unique_row_key(base, row) {
      Ok(value) => value
      Err(err) => return Err(err)
    }
    let count = match counts.get(key) {
      Some(value) => value
      None => 0
    }
    let keep = if exactly_once { count == 1 } else { count >= 1 }
    if keep {
      let start = row * base.cols
      for col in 0..<base.cols {
        out.push(base.values[start + col])
      }
      kept_rows = kept_rows + 1
    }
    ignore(counts.remove(key))
  }
  let mut result = { values: out, rows: kept_rows, cols: base.cols }
  if by_col {
    result = transpose_range_values(result)
  }
  Ok(result)
}

///|
fn sequence_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() < 1 || values.length() > 4 {
    return Error(formula_error_value)
  }
  let rows = match value_as_int(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let cols = if values.length() >= 2 {
    match value_as_int(values[1]) {
      Ok(num) => num
      Err(err) => return err
    }
  } else {
    1
  }
  if rows <= 0 || cols <= 0 {
    return Error(formula_error_value)
  }
  let start = if values.length() >= 3 {
    match value_as_number(values[2]) {
      Ok(num) => num
      Err(err) => return err
    }
  } else {
    1.0
  }
  let step = if values.length() == 4 {
    match value_as_number(values[3]) {
      Ok(num) => num
      Err(err) => return err
    }
  } else {
    1.0
  }
  let out : Array[FormulaValue] = []
  for row in 0..<rows {
    for col in 0..<cols {
      let idx = row * cols + col
      let value = start + step * Double::from_int(idx)
      out.push(Number(value))
    }
  }
  List(out)
}

///|
fn randarray_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() > 5 {
    return Error(formula_error_value)
  }
  let rows = if values.length() >= 1 {
    match value_as_int(values[0]) {
      Ok(num) => num
      Err(err) => return err
    }
  } else {
    1
  }
  let cols = if values.length() >= 2 {
    match value_as_int(values[1]) {
      Ok(num) => num
      Err(err) => return err
    }
  } else {
    1
  }
  if rows <= 0 || cols <= 0 {
    return Error(formula_error_value)
  }
  let min = if values.length() >= 3 {
    match value_as_number(values[2]) {
      Ok(num) => num
      Err(err) => return err
    }
  } else {
    0.0
  }
  let max = if values.length() >= 4 {
    match value_as_number(values[3]) {
      Ok(num) => num
      Err(err) => return err
    }
  } else {
    1.0
  }
  let whole_number = if values.length() == 5 {
    match value_as_bool(values[4]) {
      Ok(flag) => flag
      Err(err) => return err
    }
  } else {
    false
  }
  if min > max {
    return Error(formula_error_value)
  }
  let out : Array[FormulaValue] = []
  if whole_number {
    let min_int = Double::to_int(trunc_double(min))
    let max_int = Double::to_int(trunc_double(max))
    if min_int > max_int {
      return Error(formula_error_value)
    }
    let range = max_int - min_int + 1
    for _i in 0..<(rows * cols) {
      let rand_value = if range > 0 { rand_state.int(limit=range) } else { 0 }
      out.push(Number(Double::from_int(rand_value + min_int)))
    }
  } else {
    let span = max - min
    for _i in 0..<(rows * cols) {
      let value = min + rand_state.double() * span
      out.push(Number(value))
    }
  }
  List(out)
}

///|
fn slice_range_values(
  range : RangeValues,
  row_start : Int,
  row_count : Int,
  col_start : Int,
  col_count : Int,
) -> Result[RangeValues, FormulaValue] {
  if row_count <= 0 || col_count <= 0 {
    return Err(Error(formula_error_value))
  }
  if row_start < 0 || col_start < 0 {
    return Err(Error(formula_error_value))
  }
  if row_start + row_count > range.rows || col_start + col_count > range.cols {
    return Err(Error(formula_error_value))
  }
  let out : Array[FormulaValue] = []
  for row in 0..<row_count {
    let offset = (row_start + row) * range.cols + col_start
    for col in 0..<col_count {
      out.push(range.values[offset + col])
    }
  }
  Ok({ values: out, rows: row_count, cols: col_count })
}

///|
fn take_values(
  workbook : Workbook,
  sheet_name : String,
  args : ArrayView[Expr],
  values : ArrayView[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue raise XlsxError {
  if values.length() < 2 || values.length() > 3 {
    return Error(formula_error_value)
  }
  let rows_value = match value_as_int(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  let cols_value = if values.length() == 3 {
    match value_as_int(values[2]) {
      Ok(num) => num
      Err(err) => return err
    }
  } else {
    0
  }
  let range = range_from_expr_or_value(
    workbook,
    sheet_name,
    args[0],
    values[0],
    ctx,
  )
  let rows_count = if rows_value == 0 { range.rows } else { rows_value }
  let cols_count = if values.length() == 3 {
    if cols_value == 0 {
      range.cols
    } else {
      cols_value
    }
  } else {
    range.cols
  }
  if rows_count == 0 || cols_count == 0 {
    return Error(formula_error_value)
  }
  let row_count = Double::abs(Double::from_int(rows_count)).to_int()
  let col_count = Double::abs(Double::from_int(cols_count)).to_int()
  if row_count > range.rows || col_count > range.cols {
    return Error(formula_error_value)
  }
  let row_start = if rows_count > 0 { 0 } else { range.rows - row_count }
  let col_start = if cols_count > 0 { 0 } else { range.cols - col_count }
  match slice_range_values(range, row_start, row_count, col_start, col_count) {
    Ok(result) => List(result.values)
    Err(err) => err
  }
}

///|
fn drop_values(
  workbook : Workbook,
  sheet_name : String,
  args : ArrayView[Expr],
  values : ArrayView[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue raise XlsxError {
  if values.length() < 2 || values.length() > 3 {
    return Error(formula_error_value)
  }
  let rows_value = match value_as_int(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  let cols_value = if values.length() == 3 {
    match value_as_int(values[2]) {
      Ok(num) => num
      Err(err) => return err
    }
  } else {
    0
  }
  let range = range_from_expr_or_value(
    workbook,
    sheet_name,
    args[0],
    values[0],
    ctx,
  )
  let drop_rows = Double::abs(Double::from_int(rows_value)).to_int()
  let drop_cols = Double::abs(Double::from_int(cols_value)).to_int()
  if drop_rows > range.rows || drop_cols > range.cols {
    return Error(formula_error_value)
  }
  let row_start = if rows_value >= 0 { drop_rows } else { 0 }
  let col_start = if cols_value >= 0 { drop_cols } else { 0 }
  let row_count = range.rows - drop_rows
  let col_count = range.cols - drop_cols
  match slice_range_values(range, row_start, row_count, col_start, col_count) {
    Ok(result) => List(result.values)
    Err(err) => err
  }
}

///|
fn flatten_range_values(
  range : RangeValues,
  scan_by_column : Bool,
  ignore : Int,
) -> Result[Array[FormulaValue], FormulaValue] {
  let out : Array[FormulaValue] = []
  let keep_value = fn(value : FormulaValue) -> Result[Bool, FormulaValue] {
    match normalize_scalar(value) {
      Error(err) =>
        if ignore == 2 || ignore == 3 {
          Ok(false)
        } else {
          Err(Error(err))
        }
      Empty => if ignore == 1 || ignore == 3 { Ok(false) } else { Ok(true) }
      _ => Ok(true)
    }
  }
  if scan_by_column {
    for col in 0..<range.cols {
      for row in 0..<range.rows {
        let value = range.values[row * range.cols + col]
        match keep_value(value) {
          Ok(true) => out.push(value)
          Ok(false) => ()
          Err(err) => return Err(err)
        }
      }
    }
  } else {
    for row in 0..<range.rows {
      let offset = row * range.cols
      for col in 0..<range.cols {
        let value = range.values[offset + col]
        match keep_value(value) {
          Ok(true) => out.push(value)
          Ok(false) => ()
          Err(err) => return Err(err)
        }
      }
    }
  }
  if out.length() == 0 {
    Err(Error(formula_error_calc))
  } else {
    Ok(out)
  }
}

///|
fn choose_indices(
  values : ArrayView[FormulaValue],
  total : Int,
) -> Result[Array[Int], FormulaValue] {
  let out : Array[Int] = []
  for value in values {
    let idx = match value_as_int(value) {
      Ok(num) => num
      Err(err) => return Err(err)
    }
    if idx == 0 {
      return Err(Error(formula_error_value))
    }
    let resolved = if idx > 0 { idx - 1 } else { total + idx }
    if resolved < 0 || resolved >= total {
      return Err(Error(formula_error_value))
    }
    out.push(resolved)
  }
  if out.length() == 0 {
    Err(Error(formula_error_value))
  } else {
    Ok(out)
  }
}

///|
fn stack_from_values(
  workbook : Workbook,
  sheet_name : String,
  args : ArrayView[Expr],
  values : ArrayView[FormulaValue],
  ctx : CalcContext,
  horizontal : Bool,
) -> FormulaValue raise XlsxError {
  if values.length() == 0 {
    return Error(formula_error_value)
  }
  let ranges : Array[RangeValues] = []
  let mut max_rows = 0
  let mut max_cols = 0
  for i in 0..<values.length() {
    let range = range_from_expr_or_value(
      workbook,
      sheet_name,
      args[i],
      values[i],
      ctx,
    )
    if range.rows > max_rows {
      max_rows = range.rows
    }
    if range.cols > max_cols {
      max_cols = range.cols
    }
    ranges.push(range)
  }
  let mut total_rows = if horizontal { max_rows } else { 0 }
  let mut total_cols = if horizontal { 0 } else { max_cols }
  for range in ranges {
    if horizontal {
      total_cols = total_cols + range.cols
    } else {
      total_rows = total_rows + range.rows
    }
  }
  if total_rows == 0 || total_cols == 0 {
    return Error(formula_error_value)
  }
  let out : Array[FormulaValue] = Array::make(total_rows * total_cols, Empty)
  if horizontal {
    let mut col_offset = 0
    for range in ranges {
      for row in 0..<total_rows {
        for col in 0..<range.cols {
          let value = if row < range.rows {
            range.values[row * range.cols + col]
          } else {
            Error(formula_error_na)
          }
          let idx = row * total_cols + col_offset + col
          out[idx] = value
        }
      }
      col_offset = col_offset + range.cols
    }
  } else {
    let mut row_offset = 0
    for range in ranges {
      for row in 0..<range.rows {
        let out_row = row_offset + row
        for col in 0..<total_cols {
          let value = if col < range.cols {
            range.values[row * range.cols + col]
          } else {
            Error(formula_error_na)
          }
          let idx = out_row * total_cols + col
          out[idx] = value
        }
      }
      row_offset = row_offset + range.rows
    }
  }
  List(out)
}

///|
fn choosecols_values(
  workbook : Workbook,
  sheet_name : String,
  args : ArrayView[Expr],
  values : ArrayView[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue raise XlsxError {
  if values.length() < 2 {
    return Error(formula_error_value)
  }
  let range = range_from_expr_or_value(
    workbook,
    sheet_name,
    args[0],
    values[0],
    ctx,
  )
  let indices = match choose_indices(values[1:], range.cols) {
    Ok(list) => list
    Err(err) => return err
  }
  let out : Array[FormulaValue] = []
  for row in 0..<range.rows {
    let offset = row * range.cols
    for col in indices {
      out.push(range.values[offset + col])
    }
  }
  List(out)
}

///|
fn chooserows_values(
  workbook : Workbook,
  sheet_name : String,
  args : ArrayView[Expr],
  values : ArrayView[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue raise XlsxError {
  if values.length() < 2 {
    return Error(formula_error_value)
  }
  let range = range_from_expr_or_value(
    workbook,
    sheet_name,
    args[0],
    values[0],
    ctx,
  )
  let indices = match choose_indices(values[1:], range.rows) {
    Ok(list) => list
    Err(err) => return err
  }
  let out : Array[FormulaValue] = []
  for row in indices {
    let offset = row * range.cols
    for col in 0..<range.cols {
      out.push(range.values[offset + col])
    }
  }
  List(out)
}

///|
fn expand_values(
  workbook : Workbook,
  sheet_name : String,
  args : ArrayView[Expr],
  values : ArrayView[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue raise XlsxError {
  if values.length() < 2 || values.length() > 4 {
    return Error(formula_error_value)
  }
  let range = range_from_expr_or_value(
    workbook,
    sheet_name,
    args[0],
    values[0],
    ctx,
  )
  let rows = match value_as_int(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  let cols = if values.length() >= 3 {
    match value_as_int(values[2]) {
      Ok(num) => num
      Err(err) => return err
    }
  } else {
    range.cols
  }
  if rows < range.rows || cols < range.cols || rows <= 0 || cols <= 0 {
    return Error(formula_error_value)
  }
  let pad_value = if values.length() == 4 {
    match normalize_scalar(values[3]) {
      Error(err) => return Error(err)
      List(_) => return Error(formula_error_value)
      value => value
    }
  } else {
    Error(formula_error_na)
  }
  let out : Array[FormulaValue] = Array::make(rows * cols, pad_value)
  for row in 0..<range.rows {
    let in_offset = row * range.cols
    let out_offset = row * cols
    for col in 0..<range.cols {
      out[out_offset + col] = range.values[in_offset + col]
    }
  }
  List(out)
}

///|
fn wrap_values(
  workbook : Workbook,
  sheet_name : String,
  args : ArrayView[Expr],
  values : ArrayView[FormulaValue],
  ctx : CalcContext,
  by_rows : Bool,
) -> FormulaValue raise XlsxError {
  if values.length() < 2 || values.length() > 3 {
    return Error(formula_error_value)
  }
  let range = range_from_expr_or_value(
    workbook,
    sheet_name,
    args[0],
    values[0],
    ctx,
  )
  let vector = match range_vector(range) {
    Some(list) => list
    None => return Error(formula_error_value)
  }
  let count = match value_as_int(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  if count <= 0 {
    return Error(formula_error_value)
  }
  let pad_value = if values.length() == 3 {
    match normalize_scalar(values[2]) {
      Error(err) => return Error(err)
      List(_) => return Error(formula_error_value)
      value => value
    }
  } else {
    Error(formula_error_na)
  }
  let total = vector.length()
  let rows = if by_rows {
    let full = (total + count - 1) / count
    full
  } else {
    count
  }
  let cols = if by_rows {
    count
  } else {
    let full = (total + count - 1) / count
    full
  }
  let out : Array[FormulaValue] = Array::make(rows * cols, pad_value)
  for i in 0..<total {
    let row = if by_rows { i / count } else { i % count }
    let col = if by_rows { i % count } else { i / count }
    out[row * cols + col] = vector[i]
  }
  List(out)
}

///|
fn tocol_torow_values(
  workbook : Workbook,
  sheet_name : String,
  args : ArrayView[Expr],
  values : ArrayView[FormulaValue],
  ctx : CalcContext,
  scan_by_column_default : Bool,
) -> FormulaValue raise XlsxError {
  if values.length() < 1 || values.length() > 3 {
    return Error(formula_error_value)
  }
  let ignore = if values.length() >= 2 {
    match value_as_int(values[1]) {
      Ok(num) => num
      Err(err) => return err
    }
  } else {
    0
  }
  if ignore < 0 || ignore > 3 {
    return Error(formula_error_value)
  }
  let scan_by_column = if values.length() == 3 {
    match value_as_bool(values[2]) {
      Ok(flag) => flag
      Err(err) => return err
    }
  } else {
    scan_by_column_default
  }
  let range = range_from_expr_or_value(
    workbook,
    sheet_name,
    args[0],
    values[0],
    ctx,
  )
  match flatten_range_values(range, scan_by_column, ignore) {
    Ok(list) => List(list)
    Err(err) => err
  }
}

///|
fn sort_range_values(
  range : RangeValues,
  sort_index : Int,
  sort_order : Int,
) -> Result[RangeValues, FormulaValue] {
  if sort_index < 1 || sort_index > range.cols {
    return Err(Error(formula_error_value))
  }
  if sort_order != 1 && sort_order != -1 {
    return Err(Error(formula_error_value))
  }
  let entries : Array[(Int, FormulaValue)] = []
  let key_col = sort_index - 1
  for row in 0..<range.rows {
    let key = match range.get(row, key_col) {
      Some(value) => value
      None => return Err(Error(formula_error_value))
    }
    match key {
      Error(err) => return Err(Error(err))
      _ => entries.push((row, key))
    }
  }
  entries.sort_by((left, right) => {
    let (left_idx, left_key) = left
    let (right_idx, right_key) = right
    let cmp = match compare_values(left_key, right_key) {
      Ok(value) => value
      Err(_) => 0
    }
    if cmp == 0 {
      left_idx - right_idx
    } else {
      sort_order * cmp
    }
  })
  let out : Array[FormulaValue] = []
  for entry in entries {
    let (row, _) = entry
    let offset = row * range.cols
    for col in 0..<range.cols {
      out.push(range.values[offset + col])
    }
  }
  Ok({ values: out, rows: range.rows, cols: range.cols })
}

///|
fn sortby_vector(
  range : RangeValues,
  expected_len : Int,
) -> Result[Array[FormulaValue], FormulaValue] {
  let vector = match range_vector(range) {
    Some(list) => list
    None => return Err(Error(formula_error_value))
  }
  if vector.length() != expected_len {
    return Err(Error(formula_error_value))
  }
  for value in vector {
    match value {
      Error(err) => return Err(Error(err))
      _ => ()
    }
  }
  Ok(vector)
}

///|
fn sortby_values(
  workbook : Workbook,
  sheet_name : String,
  args : ArrayView[Expr],
  values : ArrayView[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue raise XlsxError {
  if args.length() < 2 {
    return Error(formula_error_value)
  }
  match values[0] {
    Error(err) => return Error(err)
    List(list) => if list.length() == 0 { return Error(formula_error_value) }
    _ => ()
  }
  let range = range_from_expr_or_value(
    workbook,
    sheet_name,
    args[0],
    values[0],
    ctx,
  )
  let sort_by_rows = range.rows > 1 || range.cols == 1
  let expected_len = if sort_by_rows { range.rows } else { range.cols }
  let key_sets : Array[(Array[FormulaValue], Int)] = []
  let mut idx = 1
  while idx < args.length() {
    match values[idx] {
      Error(err) => return Error(err)
      List(list) => if list.length() == 0 { return Error(formula_error_value) }
      _ => ()
    }
    let key_range = range_from_expr_or_value(
      workbook,
      sheet_name,
      args[idx],
      values[idx],
      ctx,
    )
    let key_vector = match sortby_vector(key_range, expected_len) {
      Ok(list) => list
      Err(err) => return err
    }
    let sort_order = if idx + 1 < values.length() {
      match value_as_int(values[idx + 1]) {
        Ok(num) => num
        Err(err) => return err
      }
    } else {
      1
    }
    if sort_order != 1 && sort_order != -1 {
      return Error(formula_error_value)
    }
    key_sets.push((key_vector, sort_order))
    idx = idx + 2
  }
  if key_sets.length() == 0 {
    return Error(formula_error_value)
  }
  let entries : Array[Int] = []
  for i in 0..<expected_len {
    entries.push(i)
  }
  entries.sort_by((left, right) => {
    let mut cmp = 0
    for item in key_sets {
      let (keys, order) = item
      let left_key = keys[left]
      let right_key = keys[right]
      let key_cmp = match compare_values(left_key, right_key) {
        Ok(value) => value
        Err(_) => 0
      }
      if key_cmp != 0 {
        cmp = order * key_cmp
        break
      }
    }
    if cmp == 0 {
      left - right
    } else {
      cmp
    }
  })
  let out : Array[FormulaValue] = []
  if sort_by_rows {
    for row in entries {
      let offset = row * range.cols
      for col in 0..<range.cols {
        out.push(range.values[offset + col])
      }
    }
    List(out)
  } else {
    for col in entries {
      for row in 0..<range.rows {
        out.push(range.values[row * range.cols + col])
      }
    }
    List(out)
  }
}

///|
fn sort_values(
  workbook : Workbook,
  sheet_name : String,
  args : ArrayView[Expr],
  values : ArrayView[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue raise XlsxError {
  if args.length() < 1 || args.length() > 4 {
    return Error(formula_error_value)
  }
  let sort_index = if values.length() >= 2 {
    match value_as_int(values[1]) {
      Ok(num) => num
      Err(err) => return err
    }
  } else {
    1
  }
  let sort_order = if values.length() >= 3 {
    match value_as_int(values[2]) {
      Ok(num) => num
      Err(err) => return err
    }
  } else {
    1
  }
  let by_col = if values.length() == 4 {
    match value_as_bool(values[3]) {
      Ok(flag) => flag
      Err(err) => return err
    }
  } else {
    false
  }
  if sort_index < 1 {
    return Error(formula_error_value)
  }
  let range = range_from_expr_or_value(
    workbook,
    sheet_name,
    args[0],
    values[0],
    ctx,
  )
  let base = if by_col { transpose_range_values(range) } else { range }
  match sort_range_values(base, sort_index, sort_order) {
    Ok(sorted) => {
      let result = if by_col { transpose_range_values(sorted) } else { sorted }
      List(result.values)
    }
    Err(err) => err
  }
}

///|
fn filter_range_values(
  range : RangeValues,
  mask : RangeValues,
  if_empty : FormulaValue?,
) -> FormulaValue {
  let values = match range_vector(range) {
    Some(list) => list
    None => return Error(formula_error_value)
  }
  let include_values = match range_vector(mask) {
    Some(list) => list
    None => return Error(formula_error_value)
  }
  if values.length() != include_values.length() {
    return Error(formula_error_value)
  }
  let out : Array[FormulaValue] = []
  for i in 0..<values.length() {
    let keep = match value_as_bool(include_values[i]) {
      Ok(flag) => flag
      Err(err) => return err
    }
    if keep {
      out.push(values[i])
    }
  }
  if out.length() == 0 {
    match if_empty {
      Some(value) => value
      None => Error(formula_error_calc)
    }
  } else {
    List(out)
  }
}

///|
fn filter_values(
  workbook : Workbook,
  sheet_name : String,
  args : ArrayView[Expr],
  values : ArrayView[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue raise XlsxError {
  if args.length() < 2 || args.length() > 3 {
    return Error(formula_error_value)
  }
  let range = range_from_expr_or_value(
    workbook,
    sheet_name,
    args[0],
    values[0],
    ctx,
  )
  let mask = range_from_expr_or_value(
    workbook,
    sheet_name,
    args[1],
    values[1],
    ctx,
  )
  let if_empty = if args.length() == 3 { Some(values[2]) } else { None }
  filter_range_values(range, mask, if_empty)
}

///|
fn sorted_numbers_from_range(
  range : RangeValues,
) -> Result[Array[Double], FormulaValue] {
  let numbers : Array[Double] = []
  for col in 0..<range.cols {
    for row in 0..<range.rows {
      let value = range.values[row * range.cols + col]
      match normalize_scalar(value) {
        Error(err) => return Err(Error(err))
        Number(num) => numbers.push(num)
        _ => ()
      }
    }
  }
  numbers.sort()
  Ok(numbers)
}

///|
fn frequency_values(
  workbook : Workbook,
  sheet_name : String,
  args : ArrayView[Expr],
  values : ArrayView[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue raise XlsxError {
  if args.length() != 2 {
    return Error(formula_error_value)
  }
  let data_range = range_from_expr_or_value(
    workbook,
    sheet_name,
    args[0],
    values[0],
    ctx,
  )
  let bins_range = range_from_expr_or_value(
    workbook,
    sheet_name,
    args[1],
    values[1],
    ctx,
  )
  let data = match sorted_numbers_from_range(data_range) {
    Ok(list) => list
    Err(err) => return err
  }
  let bins = match sorted_numbers_from_range(bins_range) {
    Ok(list) => list
    Err(err) => return err
  }
  let out : Array[FormulaValue] = []
  let mut idx = 0
  for bin in bins {
    let mut count = 0
    while idx < data.length() && data[idx] <= bin {
      count = count + 1
      idx = idx + 1
    }
    out.push(Number(Double::from_int(count)))
  }
  out.push(Number(Double::from_int(data.length() - idx)))
  if out.length() > 2 {
    let temp = out[1]
    out[1] = out[2]
    out[2] = temp
  }
  List(out)
}

///|
fn range_from_expr_or_value(
  workbook : Workbook,
  sheet_name : String,
  expr : Expr,
  value : FormulaValue,
  ctx : CalcContext,
) -> RangeValues raise XlsxError {
  let range_from_value = fn(value : FormulaValue) -> RangeValues {
    match value {
      List(list) =>
        if list.length() == 0 {
          { rows: 1, cols: 1, values: [Empty] }
        } else {
          { rows: 1, cols: list.length(), values: list }
        }
      _ => { rows: 1, cols: 1, values: [value] }
    }
  }
  match expr {
    Range(_, _, _) | Cell(_, _) =>
      eval_range_expr(workbook, sheet_name, expr, ctx)
    FuncCall(name, args) =>
      if is_munit_func(name) {
        munit_range_values_from_expr(workbook, sheet_name, args, ctx)
      } else if name == "TRANSPOSE" {
        transpose_range_values_from_expr(workbook, sheet_name, args, ctx)
      } else {
        match value {
          List(list) =>
            match array_shape_from_expr(workbook, sheet_name, expr, ctx) {
              Some((rows, cols)) =>
                if rows > 0 && cols > 0 && rows * cols == list.length() {
                  { rows, cols, values: list }
                } else {
                  range_from_value(value)
                }
              None => range_from_value(value)
            }
          _ => range_from_value(value)
        }
      }
    _ => range_from_value(value)
  }
}

///|
fn formula_value_from_cell_value(value : CellValue) -> FormulaValue {
  match value {
    Numeric(num) => Number(num)
    String(text) => String(text)
    Bool(value) => Bool(value)
    Error(text) => Error(text)
  }
}

///|
fn formula_value_to_cell(value : FormulaValue) -> (CellValueType, String) {
  match value {
    Number(num) => (Number, format_number(num))
    String(text) => (String, text)
    Bool(value) => (Bool, if value { "1" } else { "0" })
    Error(text) => (Error, text)
    Empty => (String, "")
    List(list) =>
      if list.length() > 0 {
        formula_value_to_cell(list[0])
      } else {
        (String, "")
      }
  }
}

///|
fn array_shape_binary(left : (Int, Int)?, right : (Int, Int)?) -> (Int, Int)? {
  match (left, right) {
    (Some((1, 1)), Some(shape)) => Some(shape)
    (Some(shape), Some((1, 1))) => Some(shape)
    (Some((lrows, lcols)), Some((rrows, rcols))) =>
      if lrows == rrows && lcols == rcols {
        Some((lrows, lcols))
      } else {
        None
      }
    _ => None
  }
}

///|
fn effective_range_bounds(
  workbook : Workbook,
  sheet_name : String,
  min_row : Int,
  max_row : Int,
  min_col : Int,
  max_col : Int,
) -> (Int, Int, Int, Int) {
  let rows = max_row - min_row + 1
  let cols = max_col - min_col + 1
  if rows <= 0 || cols <= 0 {
    return (min_row, max_row, min_col, max_col)
  }
  if rows * cols <= max_range_cells {
    return (min_row, max_row, min_col, max_col)
  }
  let sheet = match workbook.sheet(sheet_name) {
    Some(value) => value
    None => return (min_row, max_row, min_col, max_col)
  }
  let mut max_used_row = 0
  let mut max_used_col = 0
  for cell in sheet.cells() {
    if cell.row < min_row ||
      cell.row > max_row ||
      cell.col < min_col ||
      cell.col > max_col {
      continue
    }
    if cell.row > max_used_row {
      max_used_row = cell.row
    }
    if cell.col > max_used_col {
      max_used_col = cell.col
    }
  }
  let mut new_max_row = max_row
  let mut new_max_col = max_col
  if max_row == excel_max_rows {
    new_max_row = if max_used_row > 0 { max_used_row } else { min_row }
  }
  if max_col == excel_max_cols {
    new_max_col = if max_used_col > 0 { max_used_col } else { min_col }
  }
  let new_rows = new_max_row - min_row + 1
  let new_cols = new_max_col - min_col + 1
  if new_rows > 0 && new_cols > 0 && new_rows * new_cols > max_range_cells {
    if new_rows >= new_cols {
      let allowed_rows = max_range_cells / new_cols
      let final_rows = if allowed_rows > 0 { allowed_rows } else { 1 }
      new_max_row = min_row + final_rows - 1
    } else {
      let allowed_cols = max_range_cells / new_rows
      let final_cols = if allowed_cols > 0 { allowed_cols } else { 1 }
      new_max_col = min_col + final_cols - 1
    }
  }
  (min_row, new_max_row, min_col, new_max_col)
}

///|
fn function_may_spill(name : String) -> Bool {
  match name {
    "TRANSPOSE"
    | "MUNIT"
    | "_XLFN.MUNIT"
    | "SEQUENCE"
    | "_XLFN.SEQUENCE"
    | "RANDARRAY"
    | "_XLFN.RANDARRAY"
    | "MINVERSE"
    | "MMULT"
    | "TREND"
    | "GROWTH"
    | "XLOOKUP"
    | "_XLFN.XLOOKUP"
    | "TEXTSPLIT"
    | "_XLFN.TEXTSPLIT"
    | "FREQUENCY"
    | "MODE.MULT"
    | "ANCHORARRAY"
    | "_XLFN.ANCHORARRAY"
    | "INDIRECT"
    | "SORT"
    | "_XLFN.SORT"
    | "SORTBY"
    | "_XLFN.SORTBY"
    | "UNIQUE"
    | "_XLFN.UNIQUE"
    | "FILTER"
    | "_XLFN.FILTER"
    | "TAKE"
    | "_XLFN.TAKE"
    | "DROP"
    | "_XLFN.DROP"
    | "CHOOSECOLS"
    | "_XLFN.CHOOSECOLS"
    | "CHOOSEROWS"
    | "_XLFN.CHOOSEROWS"
    | "HSTACK"
    | "_XLFN.HSTACK"
    | "VSTACK"
    | "_XLFN.VSTACK"
    | "EXPAND"
    | "_XLFN.EXPAND"
    | "WRAPROWS"
    | "_XLFN.WRAPROWS"
    | "WRAPCOLS"
    | "_XLFN.WRAPCOLS"
    | "TOCOL"
    | "_XLFN.TOCOL"
    | "TOROW"
    | "_XLFN.TOROW" => true
    _ => false
  }
}

///|
fn array_shape_from_expr(
  workbook : Workbook,
  sheet_name : String,
  expr : Expr,
  ctx : CalcContext,
) -> (Int, Int)? raise XlsxError {
  match expr {
    Number(_) | String(_) | Bool(_) => Some((1, 1))
    Cell(_, _) => Some((1, 1))
    Range(sheet, start_ref, end_ref) => {
      let target_sheet = if sheet == "" { sheet_name } else { sheet }
      let (row1, col1) = cell_ref_to_rc(start_ref)
      let (row2, col2) = cell_ref_to_rc(end_ref)
      let min_row = if row1 < row2 { row1 } else { row2 }
      let max_row = if row1 > row2 { row1 } else { row2 }
      let min_col = if col1 < col2 { col1 } else { col2 }
      let max_col = if col1 > col2 { col1 } else { col2 }
      let (min_row, max_row, min_col, max_col) = effective_range_bounds(
        workbook, target_sheet, min_row, max_row, min_col, max_col,
      )
      let rows = max_row - min_row + 1
      let cols = max_col - min_col + 1
      Some((rows, cols))
    }
    Unary(_, inner) => array_shape_from_expr(workbook, sheet_name, inner, ctx)
    Binary(_, left, right) =>
      array_shape_binary(
        array_shape_from_expr(workbook, sheet_name, left, ctx),
        array_shape_from_expr(workbook, sheet_name, right, ctx),
      )
    List(items) => Some((1, items.length()))
    FuncCall(name, args) =>
      if args.length() == 0 {
        match defined_name_expr(workbook, sheet_name, name) {
          Some(value) => array_shape_from_expr(workbook, sheet_name, value, ctx)
          None => None
        }
      } else if !function_may_spill(name) {
        Some((1, 1))
      } else {
        let values : Array[FormulaValue] = []
        for arg in args {
          values.push(eval_expr(workbook, sheet_name, arg, ctx))
        }
        match name {
          "TRANSPOSE" =>
            if args.length() == 1 {
              let base_range = range_from_expr_or_value(
                workbook,
                sheet_name,
                args[0],
                values[0],
                ctx,
              )
              Some((base_range.cols, base_range.rows))
            } else {
              None
            }
          "MUNIT" | "_XLFN.MUNIT" =>
            if values.length() == 1 {
              match munit_dimension(values[0]) {
                Ok(dimension) => Some((dimension, dimension))
                Err(_) => None
              }
            } else {
              None
            }
          "SEQUENCE" | "_XLFN.SEQUENCE" =>
            if values.length() >= 1 && values.length() <= 4 {
              let rows = match value_as_int(values[0]) {
                Ok(num) => num
                Err(_) => return None
              }
              let cols = if values.length() >= 2 {
                match value_as_int(values[1]) {
                  Ok(num) => num
                  Err(_) => return None
                }
              } else {
                1
              }
              if rows <= 0 || cols <= 0 {
                None
              } else {
                Some((rows, cols))
              }
            } else {
              None
            }
          "RANDARRAY" | "_XLFN.RANDARRAY" =>
            if values.length() <= 5 {
              let rows = if values.length() >= 1 {
                match value_as_int(values[0]) {
                  Ok(num) => num
                  Err(_) => return None
                }
              } else {
                1
              }
              let cols = if values.length() >= 2 {
                match value_as_int(values[1]) {
                  Ok(num) => num
                  Err(_) => return None
                }
              } else {
                1
              }
              if rows <= 0 || cols <= 0 {
                None
              } else {
                Some((rows, cols))
              }
            } else {
              None
            }
          "MINVERSE" =>
            if args.length() == 1 {
              let range = range_from_expr_or_value(
                workbook,
                sheet_name,
                args[0],
                values[0],
                ctx,
              )
              if range.rows <= 0 || range.cols <= 0 || range.rows != range.cols {
                None
              } else {
                Some((range.rows, range.cols))
              }
            } else {
              None
            }
          "MMULT" =>
            if args.length() == 2 {
              let left_range = range_from_expr_or_value(
                workbook,
                sheet_name,
                args[0],
                values[0],
                ctx,
              )
              let right_range = range_from_expr_or_value(
                workbook,
                sheet_name,
                args[1],
                values[1],
                ctx,
              )
              if left_range.rows <= 0 ||
                left_range.cols <= 0 ||
                right_range.rows <= 0 ||
                right_range.cols <= 0 ||
                left_range.cols != right_range.rows {
                None
              } else {
                Some((left_range.rows, right_range.cols))
              }
            } else {
              None
            }
          "TEXTSPLIT" | "_XLFN.TEXTSPLIT" =>
            if values.length() >= 2 && values.length() <= 6 {
              let text = match value_as_string(values[0]) {
                Ok(value) => value
                Err(_) => return None
              }
              let col_delimiter = match value_as_string(values[1]) {
                Ok(value) => value
                Err(_) => return None
              }
              if col_delimiter == "" {
                return None
              }
              let row_delimiter = if values.length() >= 3 {
                match value_as_string(values[2]) {
                  Ok(value) => value
                  Err(_) => return None
                }
              } else {
                ""
              }
              let ignore_empty = if values.length() >= 4 {
                match value_as_bool(values[3]) {
                  Ok(flag) => flag
                  Err(_) => return None
                }
              } else {
                false
              }
              let match_mode = if values.length() >= 5 {
                match value_as_int(values[4]) {
                  Ok(num) => num
                  Err(_) => return None
                }
              } else {
                0
              }
              if match_mode != 0 && match_mode != 1 {
                return None
              }
              let ignore_case = match_mode == 1
              let row_texts = if row_delimiter == "" {
                [text]
              } else {
                split_text_parts(text, row_delimiter, ignore_empty, ignore_case)
              }
              let mut max_cols = 0
              for row_text in row_texts {
                let cols = split_text_parts(
                  row_text, col_delimiter, ignore_empty, ignore_case,
                )
                if cols.length() > max_cols {
                  max_cols = cols.length()
                }
              }
              if row_texts.length() == 0 || max_cols == 0 {
                None
              } else {
                Some((row_texts.length(), max_cols))
              }
            } else {
              None
            }
          "FREQUENCY" =>
            if args.length() == 2 {
              let bins_range = range_from_expr_or_value(
                workbook,
                sheet_name,
                args[1],
                values[1],
                ctx,
              )
              match sorted_numbers_from_range(bins_range) {
                Ok(bins) => Some((bins.length() + 1, 1))
                Err(_) => None
              }
            } else {
              None
            }
          "MODE.MULT" =>
            if values.length() >= 1 {
              match mode_mult_values(values) {
                List(list) => Some((list.length(), 1))
                Error(_) => None
                _ => Some((1, 1))
              }
            } else {
              None
            }
          "ANCHORARRAY" | "_XLFN.ANCHORARRAY" =>
            if args.length() == 1 {
              match args[0] {
                Cell(sheet, reference) => {
                  let target_sheet = if sheet == "" {
                    sheet_name
                  } else {
                    sheet
                  }
                  let target = match workbook.sheet(target_sheet) {
                    Some(value) => value
                    None => return None
                  }
                  let formula = target.get_cell_formula(reference) catch {
                    _ => None
                  }
                  match formula {
                    Some(text) => {
                      let inner_expr = parse_formula_expr(text) catch {
                        _ => return None
                      }
                      array_shape_from_expr(
                        workbook, target_sheet, inner_expr, ctx,
                      )
                    }
                    None => Some((1, 1))
                  }
                }
                _ => None
              }
            } else {
              None
            }
          "INDIRECT" =>
            if values.length() == 1 || values.length() == 2 {
              let ref_text = match value_as_string(values[0]) {
                Ok(text) => text
                Err(_) => return None
              }
              let a1 = if values.length() == 2 {
                match value_as_bool(values[1]) {
                  Ok(flag) => flag
                  Err(_) => return None
                }
              } else {
                true
              }
              let (sheet_text, ref_part) = split_sheet_ref(ref_text)
              let target_sheet = if sheet_text == "" {
                sheet_name
              } else {
                sheet_text
              }
              let shape_from_range_refs = fn(
                target_sheet : String,
                start_ref : String,
                end_ref : String,
              ) -> (Int, Int)? raise XlsxError {
                let (row1, col1) = cell_ref_to_rc(start_ref)
                let (row2, col2) = cell_ref_to_rc(end_ref)
                let min_row = if row1 < row2 { row1 } else { row2 }
                let max_row = if row1 > row2 { row1 } else { row2 }
                let min_col = if col1 < col2 { col1 } else { col2 }
                let max_col = if col1 > col2 { col1 } else { col2 }
                let (min_row, max_row, min_col, max_col) = effective_range_bounds(
                  workbook, target_sheet, min_row, max_row, min_col, max_col,
                )
                let rows = max_row - min_row + 1
                let cols = max_col - min_col + 1
                if rows <= 0 || cols <= 0 {
                  None
                } else {
                  Some((rows, cols))
                }
              }
              if a1 {
                match ref_part.find(":") {
                  Some(idx) => {
                    let start_token = ref_part.unsafe_substring(
                      start=0,
                      end=idx,
                    )
                    let end_token = ref_part.unsafe_substring(
                      start=idx + 1,
                      end=ref_part.length(),
                    )
                    let (start_ref, _start_end) = parse_range_ref_token(
                      start_token,
                    ) catch {
                      _ => return None
                    }
                    let (_end_start, end_ref) = parse_range_ref_token(end_token) catch {
                      _ => return None
                    }
                    shape_from_range_refs(target_sheet, start_ref, end_ref)
                  }
                  None =>
                    match parse_cell_ref_token(ref_part) {
                      Some(_) => Some((1, 1))
                      None => {
                        let (start_ref, end_ref) = parse_range_ref_token(
                          ref_part,
                        ) catch {
                          _ => return None
                        }
                        shape_from_range_refs(target_sheet, start_ref, end_ref)
                      }
                    }
                }
              } else {
                match ref_part.find(":") {
                  Some(idx) => {
                    let start_token = ref_part.unsafe_substring(
                      start=0,
                      end=idx,
                    )
                    let end_token = ref_part.unsafe_substring(
                      start=idx + 1,
                      end=ref_part.length(),
                    )
                    let (row1, col1) = match parse_r1c1_token(start_token) {
                      Some(value) => value
                      None => return None
                    }
                    let (row2, col2) = match parse_r1c1_token(end_token) {
                      Some(value) => value
                      None => return None
                    }
                    let start_ref = cell_ref_from(row1, col1) catch {
                      _ => return None
                    }
                    let end_ref = cell_ref_from(row2, col2) catch {
                      _ => return None
                    }
                    shape_from_range_refs(target_sheet, start_ref, end_ref)
                  }
                  None =>
                    match parse_r1c1_token(ref_part) {
                      Some(_) => Some((1, 1))
                      None => None
                    }
                }
              }
            } else {
              None
            }
          "TREND" | "GROWTH" =>
            if values.length() >= 1 && values.length() <= 4 {
              let know_y_range = range_from_expr_or_value(
                workbook,
                sheet_name,
                args[0],
                values[0],
                ctx,
              )
              let know_y = match number_matrix_from_range(know_y_range, false) {
                Ok(matrix) => matrix
                Err(_) => return None
              }
              let mut know_x : Array[Array[Double]] = []
              if values.length() >= 2 {
                let know_x_range = range_from_expr_or_value(
                  workbook,
                  sheet_name,
                  args[1],
                  values[1],
                  ctx,
                )
                know_x = match number_matrix_from_range(know_x_range, false) {
                  Ok(matrix) => matrix
                  Err(_) => return None
                }
              }
              let mut new_x : Array[Array[Double]] = []
              if values.length() >= 3 {
                let new_x_range = range_from_expr_or_value(
                  workbook,
                  sheet_name,
                  args[2],
                  values[2],
                  ctx,
                )
                let base = match number_matrix_from_range(new_x_range, false) {
                  Ok(matrix) => matrix
                  Err(_) => return None
                }
                new_x = transpose_number_matrix(base)
              }
              let mut constant = true
              if values.length() == 4 {
                constant = match value_as_bool(values[3]) {
                  Ok(flag) => flag
                  Err(_) => return None
                }
              }
              let is_growth = name == "GROWTH"
              match
                calc_trend_growth(know_y, know_x, new_x, constant, is_growth) {
                Ok(matrix) =>
                  if matrix.length() == 0 || matrix[0].length() == 0 {
                    None
                  } else {
                    Some((matrix.length(), matrix[0].length()))
                  }
                Err(_) => None
              }
            } else {
              None
            }
          "SORT" | "_XLFN.SORT" =>
            if args.length() >= 1 && args.length() <= 4 {
              let range = range_from_expr_or_value(
                workbook,
                sheet_name,
                args[0],
                values[0],
                ctx,
              )
              if range.rows <= 0 || range.cols <= 0 {
                None
              } else {
                Some((range.rows, range.cols))
              }
            } else {
              None
            }
          "SORTBY" | "_XLFN.SORTBY" =>
            if args.length() >= 2 {
              let range = range_from_expr_or_value(
                workbook,
                sheet_name,
                args[0],
                values[0],
                ctx,
              )
              if range.rows <= 0 || range.cols <= 0 {
                None
              } else {
                Some((range.rows, range.cols))
              }
            } else {
              None
            }
          "UNIQUE" | "_XLFN.UNIQUE" =>
            if args.length() >= 1 && args.length() <= 3 {
              let by_col = if args.length() >= 2 {
                match value_as_bool(values[1]) {
                  Ok(flag) => flag
                  Err(_) => return None
                }
              } else {
                false
              }
              let exactly_once = if args.length() == 3 {
                match value_as_bool(values[2]) {
                  Ok(flag) => flag
                  Err(_) => return None
                }
              } else {
                false
              }
              let range = range_from_expr_or_value(
                workbook,
                sheet_name,
                args[0],
                values[0],
                ctx,
              )
              match unique_range_values(range, by_col, exactly_once) {
                Ok(result) => Some((result.rows, result.cols))
                Err(_) => None
              }
            } else {
              None
            }
          "FILTER" | "_XLFN.FILTER" =>
            if args.length() >= 2 && args.length() <= 3 {
              let range = range_from_expr_or_value(
                workbook,
                sheet_name,
                args[0],
                values[0],
                ctx,
              )
              let mask = range_from_expr_or_value(
                workbook,
                sheet_name,
                args[1],
                values[1],
                ctx,
              )
              let if_empty = if args.length() == 3 {
                Some(values[2])
              } else {
                None
              }
              let is_row = range.rows == 1
              let is_col = range.cols == 1
              if !is_row && !is_col {
                return None
              }
              match filter_range_values(range, mask, if_empty) {
                List(list) =>
                  if is_row {
                    Some((1, list.length()))
                  } else {
                    Some((list.length(), 1))
                  }
                Error(_) => None
                _ => Some((1, 1))
              }
            } else {
              None
            }
          "XLOOKUP" | "_XLFN.XLOOKUP" =>
            if args.length() >= 3 && args.length() <= 6 {
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
              if lookup_range.rows <= 0 ||
                lookup_range.cols <= 0 ||
                return_range.rows <= 0 ||
                return_range.cols <= 0 {
                None
              } else {
                let is_row = lookup_range.rows == 1
                let is_col = lookup_range.cols == 1
                if !is_row && !is_col {
                  None
                } else if is_row {
                  if return_range.cols != lookup_range.cols {
                    None
                  } else if return_range.rows <= 1 {
                    Some((1, 1))
                  } else {
                    Some((return_range.rows, 1))
                  }
                } else if return_range.rows != lookup_range.rows {
                  None
                } else if return_range.cols <= 1 {
                  Some((1, 1))
                } else {
                  Some((1, return_range.cols))
                }
              }
            } else {
              None
            }
          "TAKE" | "_XLFN.TAKE" =>
            if values.length() >= 2 && values.length() <= 3 {
              let range = range_from_expr_or_value(
                workbook,
                sheet_name,
                args[0],
                values[0],
                ctx,
              )
              let rows_value = match value_as_int(values[1]) {
                Ok(num) => num
                Err(_) => return None
              }
              let cols_value = if values.length() == 3 {
                match value_as_int(values[2]) {
                  Ok(num) => num
                  Err(_) => return None
                }
              } else {
                0
              }
              let rows_count = if rows_value == 0 {
                range.rows
              } else {
                rows_value
              }
              let cols_count = if values.length() == 3 {
                if cols_value == 0 {
                  range.cols
                } else {
                  cols_value
                }
              } else {
                range.cols
              }
              if rows_count == 0 || cols_count == 0 {
                None
              } else {
                let row_count = Double::abs(Double::from_int(rows_count)).to_int()
                let col_count = Double::abs(Double::from_int(cols_count)).to_int()
                if row_count <= 0 ||
                  col_count <= 0 ||
                  row_count > range.rows ||
                  col_count > range.cols {
                  None
                } else {
                  Some((row_count, col_count))
                }
              }
            } else {
              None
            }
          "DROP" | "_XLFN.DROP" =>
            if values.length() >= 2 && values.length() <= 3 {
              let range = range_from_expr_or_value(
                workbook,
                sheet_name,
                args[0],
                values[0],
                ctx,
              )
              let rows_value = match value_as_int(values[1]) {
                Ok(num) => num
                Err(_) => return None
              }
              let cols_value = if values.length() == 3 {
                match value_as_int(values[2]) {
                  Ok(num) => num
                  Err(_) => return None
                }
              } else {
                0
              }
              let drop_rows = Double::abs(Double::from_int(rows_value)).to_int()
              let drop_cols = Double::abs(Double::from_int(cols_value)).to_int()
              let row_count = range.rows - drop_rows
              let col_count = range.cols - drop_cols
              if row_count <= 0 ||
                col_count <= 0 ||
                drop_rows > range.rows ||
                drop_cols > range.cols {
                None
              } else {
                Some((row_count, col_count))
              }
            } else {
              None
            }
          "CHOOSECOLS" | "_XLFN.CHOOSECOLS" =>
            if values.length() >= 2 {
              let range = range_from_expr_or_value(
                workbook,
                sheet_name,
                args[0],
                values[0],
                ctx,
              )
              match choose_indices(values[1:], range.cols) {
                Ok(indices) => Some((range.rows, indices.length()))
                Err(_) => None
              }
            } else {
              None
            }
          "CHOOSEROWS" | "_XLFN.CHOOSEROWS" =>
            if values.length() >= 2 {
              let range = range_from_expr_or_value(
                workbook,
                sheet_name,
                args[0],
                values[0],
                ctx,
              )
              match choose_indices(values[1:], range.rows) {
                Ok(indices) => Some((indices.length(), range.cols))
                Err(_) => None
              }
            } else {
              None
            }
          "HSTACK" | "_XLFN.HSTACK" | "VSTACK" | "_XLFN.VSTACK" =>
            if values.length() >= 1 {
              let horizontal = name == "HSTACK" || name == "_XLFN.HSTACK"
              let mut max_rows = 0
              let mut max_cols = 0
              let mut total_rows = 0
              let mut total_cols = 0
              for i in 0..<values.length() {
                let range = range_from_expr_or_value(
                  workbook,
                  sheet_name,
                  args[i],
                  values[i],
                  ctx,
                )
                if range.rows > max_rows {
                  max_rows = range.rows
                }
                if range.cols > max_cols {
                  max_cols = range.cols
                }
                if horizontal {
                  total_cols = total_cols + range.cols
                } else {
                  total_rows = total_rows + range.rows
                }
              }
              let rows = if horizontal { max_rows } else { total_rows }
              let cols = if horizontal { total_cols } else { max_cols }
              if rows <= 0 || cols <= 0 {
                None
              } else {
                Some((rows, cols))
              }
            } else {
              None
            }
          "EXPAND" | "_XLFN.EXPAND" =>
            if values.length() >= 2 && values.length() <= 4 {
              let range = range_from_expr_or_value(
                workbook,
                sheet_name,
                args[0],
                values[0],
                ctx,
              )
              let rows = match value_as_int(values[1]) {
                Ok(num) => num
                Err(_) => return None
              }
              let cols = if values.length() >= 3 {
                match value_as_int(values[2]) {
                  Ok(num) => num
                  Err(_) => return None
                }
              } else {
                range.cols
              }
              if rows < range.rows ||
                cols < range.cols ||
                rows <= 0 ||
                cols <= 0 {
                None
              } else {
                Some((rows, cols))
              }
            } else {
              None
            }
          "WRAPROWS" | "_XLFN.WRAPROWS" | "WRAPCOLS" | "_XLFN.WRAPCOLS" =>
            if values.length() >= 2 && values.length() <= 3 {
              let range = range_from_expr_or_value(
                workbook,
                sheet_name,
                args[0],
                values[0],
                ctx,
              )
              let vector = match range_vector(range) {
                Some(list) => list
                None => return None
              }
              let count = match value_as_int(values[1]) {
                Ok(num) => num
                Err(_) => return None
              }
              if count <= 0 {
                None
              } else {
                let total = vector.length()
                if total == 0 {
                  None
                } else if name == "WRAPROWS" || name == "_XLFN.WRAPROWS" {
                  let rows = (total + count - 1) / count
                  Some((rows, count))
                } else {
                  let cols = (total + count - 1) / count
                  Some((count, cols))
                }
              }
            } else {
              None
            }
          "TOCOL" | "_XLFN.TOCOL" | "TOROW" | "_XLFN.TOROW" =>
            if values.length() >= 1 && values.length() <= 3 {
              let ignore = if values.length() >= 2 {
                match value_as_int(values[1]) {
                  Ok(num) => num
                  Err(_) => return None
                }
              } else {
                0
              }
              if ignore < 0 || ignore > 3 {
                return None
              }
              let scan_by_column = if values.length() == 3 {
                match value_as_bool(values[2]) {
                  Ok(flag) => flag
                  Err(_) => return None
                }
              } else {
                false
              }
              let range = range_from_expr_or_value(
                workbook,
                sheet_name,
                args[0],
                values[0],
                ctx,
              )
              match flatten_range_values(range, scan_by_column, ignore) {
                Ok(list) =>
                  if name == "TOCOL" || name == "_XLFN.TOCOL" {
                    Some((list.length(), 1))
                  } else {
                    Some((1, list.length()))
                  }
                Err(_) => None
              }
            } else {
              None
            }
          _ => None
        }
      }
  }
}

///|
fn eval_numeric_binary(
  op : BinaryOp,
  left : FormulaValue,
  right : FormulaValue,
) -> FormulaValue {
  match (value_as_number(left), value_as_number(right)) {
    (Ok(lhs), Ok(rhs)) =>
      match op {
        Add => Number(lhs + rhs)
        Sub => Number(lhs - rhs)
        Mul => Number(lhs * rhs)
        Div =>
          if rhs == 0.0 {
            Error(formula_error_div)
          } else {
            Number(lhs / rhs)
          }
        Pow => Number(@math.pow(lhs, rhs))
        _ => Error(formula_error_value)
      }
    (Err(err), _) => err
    (_, Err(err)) => err
  }
}

///|
fn eval_list_binary(
  op : BinaryOp,
  left : FormulaValue,
  right : FormulaValue,
) -> FormulaValue {
  let left_list = match left {
    List(list) => Some(list)
    _ => None
  }
  let right_list = match right {
    List(list) => Some(list)
    _ => None
  }
  match (left_list, right_list) {
    (Some(lhs), Some(rhs)) =>
      if lhs.length() != rhs.length() {
        Error(formula_error_value)
      } else {
        let out : Array[FormulaValue] = []
        for i in 0..<lhs.length() {
          out.push(eval_numeric_binary(op, lhs[i], rhs[i]))
        }
        List(out)
      }
    (Some(lhs), None) => {
      let out : Array[FormulaValue] = []
      for item in lhs {
        out.push(eval_numeric_binary(op, item, right))
      }
      List(out)
    }
    (None, Some(rhs)) => {
      let out : Array[FormulaValue] = []
      for item in rhs {
        out.push(eval_numeric_binary(op, left, item))
      }
      List(out)
    }
    _ => Error(formula_error_value)
  }
}

///|
fn is_negative_zero(value : Double) -> Bool {
  if value != 0.0 {
    return false
  }
  let inv = 1.0 / value
  inv.is_inf() && inv < 0.0
}

///|
fn format_number(value : Double) -> String {
  if is_negative_zero(value) {
    return "-0"
  }
  let text = value.to_string()
  if text.contains("e") || text.contains("E") {
    return text
  }
  if !text.contains(".") {
    return text
  }
  let chars = text.to_array()
  let mut end = chars.length()
  while end > 0 && chars[end - 1] == '0' {
    end = end - 1
  }
  if end > 0 && chars[end - 1] == '.' {
    end = end - 1
  }
  let sb = StringBuilder::new()
  for i in 0..<end {
    sb.write_char(chars[i])
  }
  let trimmed = sb.to_string()
  if trimmed == "" {
    "0"
  } else {
    trimmed
  }
}

///|
fn formula_value_string(value : FormulaValue) -> String {
  match value {
    String(text) => text
    Number(num) => format_number(num)
    Bool(value) => if value { "TRUE" } else { "FALSE" }
    Error(text) => text
    Empty => ""
    List(list) =>
      if list.length() > 0 {
        formula_value_string(list[0])
      } else {
        ""
      }
  }
}

///|
fn value_as_string(value : FormulaValue) -> Result[String, FormulaValue] {
  match normalize_scalar(value) {
    Error(err) => Err(Error(err))
    _ => Ok(formula_value_string(value))
  }
}

///|
fn char_from_code(code : Int) -> String {
  String::from_array([code.unsafe_to_char()])
}

///|
fn code_value(name : String, value : FormulaValue) -> FormulaValue {
  let text = match value_as_string(value) {
    Ok(value) => value
    Err(err) => return err
  }
  if text.length() == 0 {
    return if name == "CODE" { Number(0.0) } else { Error(formula_error_value) }
  }
  match text.get_char(0) {
    Some(ch) => Number(Double::from_int(ch.to_int()))
    None =>
      if name == "CODE" {
        Number(0.0)
      } else {
        Error(formula_error_value)
      }
  }
}

///|
fn clean_text_value(value : FormulaValue) -> FormulaValue {
  let text = match value_as_string(value) {
    Ok(value) => value
    Err(err) => return err
  }
  let sb = StringBuilder::new()
  for ch in text {
    if ch.to_int() > 31 {
      sb.write_char(ch)
    }
  }
  String(sb.to_string())
}

///|
let hex_digits : Array[Char] = "0123456789ABCDEF".to_array()

///|
fn encode_url_byte(sb : StringBuilder, byte : Byte) -> Unit {
  let value = byte.to_int()
  if (value >= 0x30 && value <= 0x39) ||
    (value >= 0x41 && value <= 0x5a) ||
    (value >= 0x61 && value <= 0x7a) ||
    value == 0x2d ||
    value == 0x2e ||
    value == 0x5f ||
    value == 0x7e {
    sb.write_char(Int::unsafe_to_char(value))
  } else {
    sb.write_char('%')
    sb.write_char(hex_digits[value / 16])
    sb.write_char(hex_digits[value % 16])
  }
}

///|
fn encode_url_value(value : FormulaValue) -> FormulaValue {
  let text = match value_as_string(value) {
    Ok(value) => value
    Err(err) => return err
  }
  let bytes = @encoding/utf8.encode(text)
  let sb = StringBuilder::new()
  for byte in bytes {
    encode_url_byte(sb, byte)
  }
  String(sb.to_string())
}

///|
let th0 = "ศูนย์"

///|
let th1 = "หนึ่ง"

///|
let th2 = "สอง"

///|
let th3 = "สาม"

///|
let th4 = "สี่"

///|
let th5 = "ห้า"

///|
let th6 = "หก"

///|
let th7 = "เจ็ด"

///|
let th8 = "แปด"

///|
let th9 = "เก้า"

///|
let th10 = "สิบ"

///|
let th11 = "เอ็ด"

///|
let th20 = "ยี่"

///|
let th1e2 = "ร้อย"

///|
let th1e3 = "พัน"

///|
let th1e4 = "หมื่น"

///|
let th1e5 = "แสน"

///|
let th1e6 = "ล้าน"

///|
let thDot0 = "ถ้วน"

///|
let thBaht = "บาท"

///|
let thSatang = "สตางค์"

///|
let thMinus = "ลบ"

///|
let bahttext_digits : Array[String] = [
  th0, th1, th2, th3, th4, th5, th6, th7, th8, th9,
]

///|
fn bahttext_append_digit(text : String, digit : Int) -> String {
  if digit >= 0 && digit <= 9 {
    text + bahttext_digits[digit]
  } else {
    text
  }
}

///|
fn bahttext_append_pow10(text : String, digit : Int, pow10 : Int) -> String {
  let mut out = bahttext_append_digit(text, digit)
  match pow10 {
    2 => out = out + th1e2
    3 => out = out + th1e3
    4 => out = out + th1e4
    5 => out = out + th1e5
    _ => ()
  }
  out
}

///|
fn bahttext_append_block(text : String, val : Int) -> String {
  let mut out = text
  let mut value = val
  if value >= 100000 {
    out = bahttext_append_pow10(out, value / 100000, 5)
    value = value % 100000
  }
  if value >= 10000 {
    out = bahttext_append_pow10(out, value / 10000, 4)
    value = value % 10000
  }
  if value >= 1000 {
    out = bahttext_append_pow10(out, value / 1000, 3)
    value = value % 1000
  }
  if value >= 100 {
    out = bahttext_append_pow10(out, value / 100, 2)
    value = value % 100
  }
  if value > 0 {
    let n10 = value / 10
    let n1 = value % 10
    if n10 >= 1 {
      if n10 >= 3 {
        out = bahttext_append_digit(out, n10)
      } else if n10 == 2 {
        out = out + th20
      }
      out = out + th10
    }
    if n10 > 0 && n1 == 1 {
      out = out + th11
    } else if n1 > 0 {
      out = bahttext_append_digit(out, n1)
    }
  }
  out
}

///|
fn bahttext_split_block(val : Double, size : Double) -> (Double, Int) {
  let (integer, frac) = modf_double((val + 0.1) / size)
  let frac_value = frac * size + 0.1
  (integer, Double::to_int(trunc_double(frac_value)))
}

///|
fn bahttext_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 1 {
    return Error(formula_error_value)
  }
  let number = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let minus = number < 0.0
  let num = Double::floor(Double::abs(number) * 100.0 + 0.5)
  let (baht, satang) = bahttext_split_block(num, 100.0)
  let mut text = ""
  let mut baht_value = baht
  if baht_value == 0.0 {
    if satang == 0 {
      text = text + th0
    }
  } else {
    while baht_value > 0.0 {
      let (next_baht, n_block) = bahttext_split_block(baht_value, 1.0e6)
      let mut block = ""
      if n_block > 0 {
        block = bahttext_append_block(block, n_block)
      }
      if next_baht > 0.0 {
        block = th1e6 + block
      }
      text = block + text
      baht_value = next_baht
    }
  }
  if text.length() > 0 {
    text = text + thBaht
  }
  if satang == 0 {
    text = text + thDot0
  } else {
    text = bahttext_append_block(text, satang)
    text = text + thSatang
  }
  if minus {
    text = thMinus + text
  }
  String(text)
}

///|
fn value_as_int(value : FormulaValue) -> Result[Int, FormulaValue] {
  match value_as_number(value) {
    Ok(num) => Ok(Double::to_int(trunc_double(num)))
    Err(err) => Err(err)
  }
}

///|
fn find_substring_from(text : String, pattern : String, start : Int) -> Int? {
  let len = text.length()
  if start < 0 || start > len {
    return None
  }
  if pattern.length() == 0 {
    return Some(start)
  }
  let tail = text.unsafe_substring(start~, end=len)
  match tail.find(pattern) {
    Some(idx) => Some(start + idx)
    None => None
  }
}

///|
fn split_text_parts(
  text : String,
  delimiter : String,
  ignore_empty : Bool,
  ignore_case : Bool,
) -> Array[String] {
  let parts : Array[String] = []
  if delimiter.length() == 0 {
    return parts
  }
  let search_text = if ignore_case { text.to_lower() } else { text }
  let search_delim = if ignore_case { delimiter.to_lower() } else { delimiter }
  let delim_len = delimiter.length()
  let mut pos = 0
  while true {
    match find_substring_from(search_text, search_delim, pos) {
      Some(idx) => {
        let part = text.unsafe_substring(start=pos, end=idx)
        if !ignore_empty || part != "" {
          parts.push(part)
        }
        pos = idx + delim_len
      }
      None => break
    }
  }
  let tail = text.unsafe_substring(start=pos, end=text.length())
  if !ignore_empty || tail != "" {
    parts.push(tail)
  }
  parts
}

///|
fn wildcard_match_prefix(
  text : String,
  pattern : String,
  text_idx : Int,
  pattern_idx : Int,
  memo : Map[(Int, Int), Bool],
) -> Bool {
  match memo.get((text_idx, pattern_idx)) {
    Some(result) => return result
    None => ()
  }
  let text_len = text.length()
  let pattern_len = pattern.length()
  let result = if pattern_idx == pattern_len {
    true
  } else {
    let token = pattern[pattern_idx]
    if token == '~' {
      if pattern_idx + 1 >= pattern_len {
        if text_idx < text_len && text[text_idx] == '~' {
          wildcard_match_prefix(
            text,
            pattern,
            text_idx + 1,
            pattern_idx + 1,
            memo,
          )
        } else {
          false
        }
      } else {
        let next = pattern[pattern_idx + 1]
        if text_idx < text_len && text[text_idx] == next {
          wildcard_match_prefix(
            text,
            pattern,
            text_idx + 1,
            pattern_idx + 2,
            memo,
          )
        } else {
          false
        }
      }
    } else if token == '*' {
      if wildcard_match_prefix(text, pattern, text_idx, pattern_idx + 1, memo) {
        true
      } else if text_idx < text_len {
        wildcard_match_prefix(text, pattern, text_idx + 1, pattern_idx, memo)
      } else {
        false
      }
    } else if token == '?' {
      if text_idx < text_len {
        wildcard_match_prefix(
          text,
          pattern,
          text_idx + 1,
          pattern_idx + 1,
          memo,
        )
      } else {
        false
      }
    } else if text_idx < text_len && text[text_idx] == token {
      wildcard_match_prefix(text, pattern, text_idx + 1, pattern_idx + 1, memo)
    } else {
      false
    }
  }
  memo[(text_idx, pattern_idx)] = result
  result
}

///|
fn wildcard_match_full_prefix(
  text : String,
  pattern : String,
  text_idx : Int,
  pattern_idx : Int,
  memo : Map[(Int, Int), Bool],
) -> Bool {
  match memo.get((text_idx, pattern_idx)) {
    Some(result) => return result
    None => ()
  }
  let text_len = text.length()
  let pattern_len = pattern.length()
  let result = if pattern_idx == pattern_len {
    text_idx == text_len
  } else {
    let token = pattern[pattern_idx]
    if token == '~' {
      if pattern_idx + 1 >= pattern_len {
        if text_idx < text_len && text[text_idx] == '~' {
          wildcard_match_full_prefix(
            text,
            pattern,
            text_idx + 1,
            pattern_idx + 1,
            memo,
          )
        } else {
          false
        }
      } else {
        let next = pattern[pattern_idx + 1]
        if text_idx < text_len && text[text_idx] == next {
          wildcard_match_full_prefix(
            text,
            pattern,
            text_idx + 1,
            pattern_idx + 2,
            memo,
          )
        } else {
          false
        }
      }
    } else if token == '*' {
      if wildcard_match_full_prefix(
          text,
          pattern,
          text_idx,
          pattern_idx + 1,
          memo,
        ) {
        true
      } else if text_idx < text_len {
        wildcard_match_full_prefix(
          text,
          pattern,
          text_idx + 1,
          pattern_idx,
          memo,
        )
      } else {
        false
      }
    } else if token == '?' {
      if text_idx < text_len {
        wildcard_match_full_prefix(
          text,
          pattern,
          text_idx + 1,
          pattern_idx + 1,
          memo,
        )
      } else {
        false
      }
    } else if text_idx < text_len && text[text_idx] == token {
      wildcard_match_full_prefix(
        text,
        pattern,
        text_idx + 1,
        pattern_idx + 1,
        memo,
      )
    } else {
      false
    }
  }
  memo[(text_idx, pattern_idx)] = result
  result
}

///|
fn wildcard_match_full(text : String, pattern : String) -> Bool {
  let memo : Map[(Int, Int), Bool] = {}
  wildcard_match_full_prefix(text, pattern, 0, 0, memo)
}

///|
fn wildcard_find(text : String, pattern : String, start : Int) -> Int? {
  let len = text.length()
  if start < 0 || start > len {
    return None
  }
  for idx in start..<=len {
    let memo : Map[(Int, Int), Bool] = {}
    if wildcard_match_prefix(text, pattern, idx, 0, memo) {
      return Some(idx)
    }
  }
  None
}

///|
fn dbcs_byte_len_char(ch : Char) -> Int {
  if ch.to_int() <= 0x7f {
    1
  } else {
    2
  }
}

///|
/// Extracts the DBCS byte range `[start_num, start_num + count)` (1-based,
/// inclusive of `start_num`) from `text`, treating each non-ASCII
/// character as two bytes and each ASCII character as one, the way Excel
/// counts bytes for LEFTB/RIGHTB/MIDB/REPLACEB. When the range boundary
/// splits a wide character, only that character's leading UTF-8 byte is
/// emitted, matching Excel's single-byte remnant. This keeps every
/// `*B` function on one consistent DBCS model instead of slicing raw
/// UTF-8 bytes (which would mangle even boundary-aligned wide-character
/// cuts into per-byte code points).
fn dbcs_byte_range(text : String, start_num : Int, count : Int) -> String {
  if count <= 0 {
    return ""
  }
  let sb = StringBuilder::new()
  let mut offset = 0
  let mut taken = 0
  for ch in text {
    if taken == count {
      break
    }
    offset = offset + 1
    let mut dbcs = false
    if dbcs_byte_len_char(ch) == 2 {
      dbcs = true
      offset = offset + 1
    }
    if offset + 1 > start_num {
      if dbcs {
        if taken + 2 > count {
          let bytes = @encoding/utf8.encode(String::from_array([ch]))
          if bytes.length() > 0 {
            sb.write_char(Int::unsafe_to_char(bytes[0].to_int()))
          }
          break
        }
        sb.write_char(ch)
        taken = taken + 2
      } else {
        sb.write_char(ch)
        taken = taken + 1
      }
    }
  }
  sb.to_string()
}

///|
fn dbcs_byte_length(text : String) -> Int {
  let mut total = 0
  for ch in text {
    total = total + dbcs_byte_len_char(ch)
  }
  total
}

///|
fn dbcs_enabled(workbook : Workbook) -> Bool {
  let lang = workbook.core_properties().language
  if lang == "" {
    return false
  }
  let normalized = lang.to_lower().replace(old="_", new="-")
  normalized == "ja-jp" || normalized == "zh-cn" || normalized == "zh-tw"
}

///|
fn dbcs_convert(text : String) -> String {
  let sb = StringBuilder::new()
  for ch in text {
    let r = ch.to_int()
    let code = if r == 32 { 12288 } else { r + 65248 }
    if (code < 32 || code > 126) && r != 165 && code < 65381 {
      sb.write_char(Int::unsafe_to_char(code))
    } else {
      sb.write_char(ch)
    }
  }
  sb.to_string()
}

///|
fn dbcs_index_from_offset(text : String, start_num : Int) -> Int? {
  if start_num <= 0 {
    return None
  }
  let chars = text.to_array()
  let mut offset = 1
  for i in 0..<chars.length() {
    let len = dbcs_byte_len_char(chars[i])
    let end = offset + len - 1
    if start_num <= end {
      return Some(i)
    }
    offset = offset + len
  }
  None
}

///|
fn dbcs_byte_offset_for_index(text : String, index : Int) -> Int {
  let chars = text.to_array()
  let mut offset = 1
  let mut i = 0
  while i < index && i < chars.length() {
    offset = offset + dbcs_byte_len_char(chars[i])
    i = i + 1
  }
  offset
}

///|
fn wildcard_match_prefix_dbcs(
  text : String,
  pattern : String,
  text_idx : Int,
  pattern_idx : Int,
  memo : Map[(Int, Int), Bool],
) -> Bool {
  match memo.get((text_idx, pattern_idx)) {
    Some(result) => return result
    None => ()
  }
  let text_len = text.length()
  let pattern_len = pattern.length()
  let result = if pattern_idx == pattern_len {
    true
  } else {
    let token = pattern[pattern_idx]
    if token == '~' {
      if pattern_idx + 1 >= pattern_len {
        if text_idx < text_len && text[text_idx] == '~' {
          wildcard_match_prefix_dbcs(
            text,
            pattern,
            text_idx + 1,
            pattern_idx + 1,
            memo,
          )
        } else {
          false
        }
      } else {
        let next = pattern[pattern_idx + 1]
        if text_idx < text_len && text[text_idx] == next {
          wildcard_match_prefix_dbcs(
            text,
            pattern,
            text_idx + 1,
            pattern_idx + 2,
            memo,
          )
        } else {
          false
        }
      }
    } else if token == '*' {
      if wildcard_match_prefix_dbcs(
          text,
          pattern,
          text_idx,
          pattern_idx + 1,
          memo,
        ) {
        true
      } else if text_idx < text_len {
        wildcard_match_prefix_dbcs(
          text,
          pattern,
          text_idx + 1,
          pattern_idx,
          memo,
        )
      } else {
        false
      }
    } else if token == '?' {
      if text_idx < text_len && text[text_idx].to_int() <= 0x7f {
        wildcard_match_prefix_dbcs(
          text,
          pattern,
          text_idx + 1,
          pattern_idx + 1,
          memo,
        )
      } else {
        false
      }
    } else if text_idx < text_len && text[text_idx] == token {
      wildcard_match_prefix_dbcs(
        text,
        pattern,
        text_idx + 1,
        pattern_idx + 1,
        memo,
      )
    } else {
      false
    }
  }
  memo[(text_idx, pattern_idx)] = result
  result
}

///|
fn wildcard_find_dbcs(text : String, pattern : String, start : Int) -> Int? {
  let len = text.length()
  if start < 0 || start > len {
    return None
  }
  for idx in start..<=len {
    let memo : Map[(Int, Int), Bool] = {}
    if wildcard_match_prefix_dbcs(text, pattern, idx, 0, memo) {
      return Some(idx)
    }
  }
  None
}

///|
fn find_dbcs(
  text : String,
  pattern : String,
  start_num : Int,
  wildcard : Bool,
) -> Int? {
  if start_num <= 0 {
    return None
  }
  let total = dbcs_byte_length(text)
  if start_num > total {
    return None
  }
  if pattern.length() == 0 {
    return Some(start_num)
  }
  let start_idx = match dbcs_index_from_offset(text, start_num) {
    Some(idx) => idx
    None => return None
  }
  let found_idx = if wildcard {
    wildcard_find_dbcs(text, pattern, start_idx)
  } else {
    find_substring_from(text, pattern, start_idx)
  }
  match found_idx {
    Some(idx) => Some(dbcs_byte_offset_for_index(text, idx))
    None => None
  }
}

///|
fn concat_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  let sb = StringBuilder::new()
  for value in flatten_values(values) {
    match normalize_scalar(value) {
      Error(err) => return Error(err)
      _ => sb.write_view(formula_value_string(value))
    }
  }
  String(sb.to_string())
}

///|
fn proper_case(text : String) -> String {
  let sb = StringBuilder::new()
  let mut prev_letter = false
  for ch in text {
    let is_letter = ch.is_ascii_alphabetic()
    if !prev_letter && is_letter {
      sb.write_char(ch.to_ascii_uppercase())
    } else {
      sb.write_char(ch.to_ascii_lowercase())
    }
    prev_letter = is_letter
  }
  sb.to_string()
}

///|
fn decimal_places_from_text(text : String) -> Int {
  match text.find(".") {
    Some(pos) => {
      let tail = text.unsafe_substring(start=pos + 1, end=text.length())
      let mut count = 0
      for ch in tail {
        if ch.is_ascii_digit() {
          count = count + 1
        } else {
          break
        }
      }
      count
    }
    None => 0
  }
}

///|
fn textjoin_collect_value(
  value : FormulaValue,
  ignore_empty : Bool,
  out : Array[String],
) -> Result[Unit, FormulaValue] {
  match value {
    List(list) => {
      for item in list {
        match textjoin_collect_value(item, ignore_empty, out) {
          Ok(_) => ()
          Err(err) => return Err(err)
        }
      }
      Ok(())
    }
    _ =>
      match normalize_scalar(value) {
        Error(err) => Err(Error(err))
        Empty =>
          if !ignore_empty {
            out.push("")
            Ok(())
          } else {
            Ok(())
          }
        String(text) =>
          if text != "" || !ignore_empty {
            out.push(text)
            Ok(())
          } else {
            Ok(())
          }
        Number(_) | Bool(_) => {
          out.push(formula_value_string(value))
          Ok(())
        }
        List(_) => Ok(())
      }
  }
}

///|
fn textsplit_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() < 2 || values.length() > 6 {
    return Error(formula_error_value)
  }
  let text = match value_as_string(values[0]) {
    Ok(value) => value
    Err(err) => return err
  }
  let col_delimiter = match value_as_string(values[1]) {
    Ok(value) => value
    Err(err) => return err
  }
  if col_delimiter == "" {
    return Error(formula_error_value)
  }
  let row_delimiter = if values.length() >= 3 {
    match value_as_string(values[2]) {
      Ok(value) => value
      Err(err) => return err
    }
  } else {
    ""
  }
  let ignore_empty = if values.length() >= 4 {
    match value_as_bool(values[3]) {
      Ok(flag) => flag
      Err(err) => return err
    }
  } else {
    false
  }
  let match_mode = if values.length() >= 5 {
    match value_as_int(values[4]) {
      Ok(num) => num
      Err(err) => return err
    }
  } else {
    0
  }
  if match_mode != 0 && match_mode != 1 {
    return Error(formula_error_value)
  }
  let ignore_case = match_mode == 1
  let pad_value = if values.length() == 6 {
    match normalize_scalar(values[5]) {
      Error(err) => return Error(err)
      List(_) => return Error(formula_error_value)
      value => value
    }
  } else {
    Error(formula_error_na)
  }
  let row_texts = if row_delimiter == "" {
    [text]
  } else {
    split_text_parts(text, row_delimiter, ignore_empty, ignore_case)
  }
  let rows : Array[Array[String]] = []
  let mut max_cols = 0
  for row_text in row_texts {
    let cols = split_text_parts(
      row_text, col_delimiter, ignore_empty, ignore_case,
    )
    if cols.length() > max_cols {
      max_cols = cols.length()
    }
    rows.push(cols)
  }
  let out : Array[FormulaValue] = []
  for row in rows {
    for col in 0..<max_cols {
      if col < row.length() {
        out.push(String(row[col]))
      } else {
        out.push(pad_value)
      }
    }
  }
  List(out)
}

///|
fn text_after_before_index(
  text : String,
  delimiter : String,
  instance_num : Int,
  match_mode : Int,
  match_end : Bool,
) -> Int? {
  if instance_num == 0 {
    return None
  }
  let search_text = if match_mode == 1 { text.to_lower() } else { text }
  let search_delim = if match_mode == 1 {
    delimiter.to_lower()
  } else {
    delimiter
  }
  let mut found = -1
  let mut start_pos = if instance_num < 0 { search_text.length() } else { 0 }
  let count = if instance_num < 0 { -instance_num } else { instance_num }
  for i in 0..<count {
    if instance_num > 0 {
      match find_substring_from(search_text, search_delim, start_pos) {
        Some(idx) => {
          found = idx
          start_pos = idx + search_delim.length()
        }
        None =>
          if match_end && i == count - 1 {
            found = search_text.length()
          } else {
            return None
          }
      }
    } else {
      let slice = search_text.unsafe_substring(start=0, end=start_pos)
      match slice.rev_find(search_delim) {
        Some(idx) => {
          found = idx
          start_pos = idx
        }
        None =>
          if match_end && i == count - 1 {
            found = 0
          } else {
            return None
          }
      }
    }
  }
  Some(found)
}

///|
fn compare_strings(left : String, right : String) -> Int {
  let l = left.to_array()
  let r = right.to_array()
  let limit = if l.length() < r.length() { l.length() } else { r.length() }
  for i in 0..<limit {
    if l[i] != r[i] {
      return l[i].to_int() - r[i].to_int()
    }
  }
  l.length() - r.length()
}

///|
fn value_rank(value : FormulaValue) -> Int {
  match value {
    Number(_) => 0
    Empty => 0
    String(_) => 1
    Bool(_) => 2
    Error(_) => 3
    List(_) => 4
  }
}

///|
fn compare_values(
  lhs : FormulaValue,
  rhs : FormulaValue,
) -> Result[Int, FormulaValue] {
  match (lhs, rhs) {
    (Error(err), _) => Err(Error(err))
    (_, Error(err)) => Err(Error(err))
    _ => {
      let left = normalize_scalar(lhs)
      let right = normalize_scalar(rhs)
      let lrank = value_rank(left)
      let rrank = value_rank(right)
      if lrank != rrank {
        return Ok(if lrank < rrank { -1 } else { 1 })
      }
      match (left, right) {
        (Number(a), Number(b)) =>
          Ok(if a < b { -1 } else if a > b { 1 } else { 0 })
        (String(a), String(b)) => Ok(compare_strings(a, b))
        (Bool(a), Bool(b)) =>
          Ok(if a == b { 0 } else if !a && b { -1 } else { 1 })
        _ => Ok(0)
      }
    }
  }
}

///|
fn compare_lookup_values(
  lhs : FormulaValue,
  rhs : FormulaValue,
) -> Result[Int?, FormulaValue] {
  match (lhs, rhs) {
    (Error(err), _) => Err(Error(err))
    (_, Error(err)) => Err(Error(err))
    _ => {
      let left = normalize_scalar(lhs)
      let right = normalize_scalar(rhs)
      let lrank = value_rank(left)
      let rrank = value_rank(right)
      if lrank != rrank {
        return Ok(None)
      }
      match (left, right) {
        (Number(a), Number(b)) =>
          Ok(Some(if a < b { -1 } else if a > b { 1 } else { 0 }))
        (String(a), String(b)) => Ok(Some(compare_strings(a, b)))
        (Bool(a), Bool(b)) =>
          Ok(Some(if a == b { 0 } else if !a && b { -1 } else { 1 }))
        _ => Ok(None)
      }
    }
  }
}

///|
fn match_range_value(
  lookup : FormulaValue,
  range : RangeValues,
  match_type : Int,
) -> FormulaValue {
  let values = match range_vector(range) {
    Some(list) => list
    None => return Error(formula_error_na)
  }
  if match_type != 0 && match_type != 1 && match_type != -1 {
    return Error(formula_error_na)
  }
  match lookup {
    Error(err) => return Error(err)
    _ => ()
  }
  if match_type == 0 {
    for i in 0..<values.length() {
      match compare_values(values[i], lookup) {
        Ok(0) => return Number(Double::from_int(i + 1))
        Ok(_) => ()
        Err(err) => return err
      }
    }
    return Error(formula_error_na)
  }
  let mut best_idx : Int? = None
  for i in 0..<values.length() {
    match compare_values(values[i], lookup) {
      Ok(cmp) =>
        if match_type == 1 {
          if cmp <= 0 {
            best_idx = Some(i)
          }
        } else if cmp >= 0 {
          best_idx = Some(i)
        }
      Err(err) => return err
    }
  }
  match best_idx {
    Some(idx) => Number(Double::from_int(idx + 1))
    None => Error(formula_error_na)
  }
}

///|
fn lookup_range_flag(value : FormulaValue) -> Result[Bool, FormulaValue] {
  match normalize_scalar(value) {
    Bool(flag) => Ok(flag)
    Number(num) => Ok(num != 0.0)
    Empty => Ok(false)
    String(text) => {
      let parsed = @string.parse_bool(text) catch {
        _ => return Err(Error(formula_error_value))
      }
      Ok(parsed)
    }
    Error(err) => Err(Error(err))
    List(_) => Err(Error(formula_error_value))
  }
}

///|
fn vlookup_value(
  lookup : FormulaValue,
  table : RangeValues,
  col_index : Int,
  range_lookup : Bool,
) -> FormulaValue {
  match lookup {
    Error(err) => return Error(err)
    _ => ()
  }
  if col_index <= 0 {
    return Error(formula_error_value)
  }
  if col_index > table.cols {
    return Error(formula_error_ref)
  }
  if range_lookup {
    let mut best_row : Int? = None
    for row in 0..<table.rows {
      let key = table.values[row * table.cols]
      match compare_values(key, lookup) {
        Ok(cmp) => if cmp <= 0 { best_row = Some(row) }
        Err(err) => return err
      }
    }
    match best_row {
      Some(row) => table.values[row * table.cols + (col_index - 1)]
      None => Error(formula_error_na)
    }
  } else {
    for row in 0..<table.rows {
      let key = table.values[row * table.cols]
      match compare_values(key, lookup) {
        Ok(0) => return table.values[row * table.cols + (col_index - 1)]
        Ok(_) => ()
        Err(err) => return err
      }
    }
    Error(formula_error_na)
  }
}

///|
fn hlookup_value(
  lookup : FormulaValue,
  table : RangeValues,
  row_index : Int,
  range_lookup : Bool,
) -> FormulaValue {
  match lookup {
    Error(err) => return Error(err)
    _ => ()
  }
  match lookup {
    List(list) => if list.length() > 1 { return Error(formula_error_na) }
    _ => ()
  }
  if row_index <= 0 {
    return Error(formula_error_value)
  }
  if row_index > table.rows {
    return Error(formula_error_ref)
  }
  if range_lookup {
    let mut best_col : Int? = None
    for col in 0..<table.cols {
      let key = table.values[col]
      match compare_values(key, lookup) {
        Ok(cmp) => if cmp <= 0 { best_col = Some(col) }
        Err(err) => return err
      }
    }
    match best_col {
      Some(col) => table.values[(row_index - 1) * table.cols + col]
      None => Error(formula_error_na)
    }
  } else {
    for col in 0..<table.cols {
      let key = table.values[col]
      match compare_values(key, lookup) {
        Ok(0) => return table.values[(row_index - 1) * table.cols + col]
        Ok(_) => ()
        Err(err) => return err
      }
    }
    Error(formula_error_na)
  }
}

///|
fn lookup_best_index(
  lookup : FormulaValue,
  values : Array[FormulaValue],
) -> Result[Int?, FormulaValue] {
  let mut best_idx : Int? = None
  for i in 0..<values.length() {
    match compare_lookup_values(values[i], lookup) {
      Ok(Some(cmp)) =>
        if cmp <= 0 {
          match best_idx {
            None => best_idx = Some(i)
            Some(best) =>
              match compare_values(values[i], values[best]) {
                Ok(order) => if order > 0 { best_idx = Some(i) }
                Err(err) => return Err(err)
              }
          }
        }
      Ok(None) => ()
      Err(err) => return Err(err)
    }
  }
  Ok(best_idx)
}

///|
fn xlookup_find_index(
  lookup : FormulaValue,
  values : Array[FormulaValue],
  match_mode : Int,
  search_mode : Int,
) -> Result[Int?, FormulaValue] {
  match lookup {
    Error(err) => return Err(Error(err))
    _ => ()
  }
  if values.length() == 0 {
    return Ok(None)
  }
  if match_mode == 2 {
    let pattern_text = match value_as_string(lookup) {
      Ok(text) => text.to_lower()
      Err(err) => return Err(err)
    }
    let mut idx = if search_mode == -1 || search_mode == -2 {
      values.length() - 1
    } else {
      0
    }
    let end = if search_mode == -1 || search_mode == -2 {
      -1
    } else {
      values.length()
    }
    while idx != end {
      let target_text = match value_as_string(values[idx]) {
        Ok(text) => text.to_lower()
        Err(err) => return Err(err)
      }
      if wildcard_match_full(target_text, pattern_text) {
        return Ok(Some(idx))
      }
      idx = if search_mode == -1 || search_mode == -2 {
        idx - 1
      } else {
        idx + 1
      }
    }
    return Ok(None)
  }
  if match_mode == 0 {
    let mut idx = if search_mode == -1 || search_mode == -2 {
      values.length() - 1
    } else {
      0
    }
    let end = if search_mode == -1 || search_mode == -2 {
      -1
    } else {
      values.length()
    }
    while idx != end {
      match compare_values(values[idx], lookup) {
        Ok(0) => return Ok(Some(idx))
        Ok(_) => ()
        Err(err) => return Err(err)
      }
      idx = if search_mode == -1 || search_mode == -2 {
        idx - 1
      } else {
        idx + 1
      }
    }
    return Ok(None)
  }
  if match_mode != -1 && match_mode != 1 {
    return Err(Error(formula_error_value))
  }
  let mut best_idx : Int? = None
  for i in 0..<values.length() {
    match compare_values(values[i], lookup) {
      Ok(cmp) =>
        if (match_mode == -1 && cmp <= 0) || (match_mode == 1 && cmp >= 0) {
          match best_idx {
            None => best_idx = Some(i)
            Some(best) =>
              match compare_values(values[i], values[best]) {
                Ok(order) =>
                  if (match_mode == -1 && order > 0) ||
                    (match_mode == 1 && order < 0) {
                    best_idx = Some(i)
                  }
                Err(err) => return Err(err)
              }
          }
        }
      Err(err) => return Err(err)
    }
  }
  Ok(best_idx)
}

///|
fn normalize_scalar(value : FormulaValue) -> FormulaValue {
  match value {
    List(list) =>
      if list.length() > 0 {
        normalize_scalar(list[0])
      } else {
        Empty
      }
    _ => value
  }
}

///|
fn value_as_number(value : FormulaValue) -> Result[Double, FormulaValue] {
  match normalize_scalar(value) {
    Number(num) => Ok(num)
    Bool(flag) => Ok(if flag { 1.0 } else { 0.0 })
    Empty => Ok(0.0)
    String(text) => {
      let parsed = @string.parse_double(text) catch {
        _ => return Err(Error(formula_error_value))
      }
      Ok(parsed)
    }
    Error(err) => Err(Error(err))
    List(_) => Err(Error(formula_error_value))
  }
}

///|
fn value_as_number_text(value : FormulaValue) -> Result[Double, FormulaValue] {
  match normalize_scalar(value) {
    Number(num) => Ok(num)
    Bool(flag) => Ok(if flag { 1.0 } else { 0.0 })
    Empty => Ok(0.0)
    String(text) =>
      match parse_value_number(text) {
        Some(num) => Ok(num)
        None => Err(Error(formula_error_value))
      }
    Error(err) => Err(Error(err))
    List(_) => Err(Error(formula_error_value))
  }
}

///|
fn parse_double_opt(text : StringView) -> Double? {
  let parsed = @string.parse_double(text) catch { _ => return None }
  Some(parsed)
}

///|
fn parse_value_number(text : String) -> Double? {
  let trimmed = text.trim().to_string()
  if trimmed == "" {
    return Some(0.0)
  }
  let mut negative = false
  let mut body = trimmed
  if body.has_prefix("(") && body.has_suffix(")") && body.length() >= 2 {
    negative = true
    body = body[1:body.length() - 1].to_string()
  }
  let mut percent = false
  if body.has_suffix("%") && body.length() >= 1 {
    percent = true
    body = body[:body.length() - 1].to_string()
  }
  let sb = StringBuilder::new()
  for ch in body {
    if ch != ',' {
      sb.write_char(ch)
    }
  }
  let cleaned = sb.to_string().trim().to_string()
  if cleaned == "" {
    return None
  }
  let parsed = @string.parse_double(cleaned) catch { _ => return None }
  let mut value = if percent { parsed / 100.0 } else { parsed }
  if negative {
    value = -value
  }
  Some(value)
}

///|
priv struct Complex {
  real : Double
  imag : Double
}

///|
fn complex_new(real : Double, imag : Double) -> Complex {
  { real, imag }
}

///|
fn complex_add(left : Complex, right : Complex) -> Complex {
  { real: left.real + right.real, imag: left.imag + right.imag }
}

///|
fn complex_sub(left : Complex, right : Complex) -> Complex {
  { real: left.real - right.real, imag: left.imag - right.imag }
}

///|
fn complex_mul(left : Complex, right : Complex) -> Complex {
  {
    real: left.real * right.real - left.imag * right.imag,
    imag: left.real * right.imag + left.imag * right.real,
  }
}

///|
fn complex_div(left : Complex, right : Complex) -> Complex {
  let denom = right.real * right.real + right.imag * right.imag
  {
    real: (left.real * right.real + left.imag * right.imag) / denom,
    imag: (left.imag * right.real - left.real * right.imag) / denom,
  }
}

///|
fn complex_scale(value : Complex, factor : Double) -> Complex {
  { real: value.real * factor, imag: value.imag * factor }
}

///|
fn complex_abs(value : Complex) -> Double {
  Double::sqrt(value.real * value.real + value.imag * value.imag)
}

///|
fn complex_arg(value : Complex) -> Double {
  @math.atan2(value.imag, value.real)
}

///|
fn complex_conj(value : Complex) -> Complex {
  { real: value.real, imag: -value.imag }
}

///|
fn complex_exp(value : Complex) -> Complex {
  let scale = @math.exp(value.real)
  { real: scale * @math.cos(value.imag), imag: scale * @math.sin(value.imag) }
}

///|
fn complex_log(value : Complex) -> Complex {
  { real: @math.ln(complex_abs(value)), imag: complex_arg(value) }
}

///|
fn complex_pow(base : Complex, exponent : Complex) -> Complex {
  complex_exp(complex_mul(exponent, complex_log(base)))
}

///|
fn complex_sqrt(value : Complex) -> Complex {
  let r = complex_abs(value)
  let real = Double::sqrt((r + value.real) / 2.0)
  let sign = if value.imag < 0.0 { -1.0 } else { 1.0 }
  let imag = sign * Double::sqrt((r - value.real) / 2.0)
  { real, imag }
}

///|
fn complex_sin(value : Complex) -> Complex {
  {
    real: @math.sin(value.real) * @math.cosh(value.imag),
    imag: @math.cos(value.real) * @math.sinh(value.imag),
  }
}

///|
fn complex_cos(value : Complex) -> Complex {
  {
    real: @math.cos(value.real) * @math.cosh(value.imag),
    imag: -@math.sin(value.real) * @math.sinh(value.imag),
  }
}

///|
fn complex_tan(value : Complex) -> Complex {
  complex_div(complex_sin(value), complex_cos(value))
}

///|
fn complex_sinh(value : Complex) -> Complex {
  {
    real: @math.sinh(value.real) * @math.cos(value.imag),
    imag: @math.cosh(value.real) * @math.sin(value.imag),
  }
}

///|
fn complex_cosh(value : Complex) -> Complex {
  {
    real: @math.cosh(value.real) * @math.cos(value.imag),
    imag: @math.sinh(value.real) * @math.sin(value.imag),
  }
}

///|
fn complex_is_invalid(value : Complex) -> Bool {
  Double::is_nan(value.real) ||
  Double::is_nan(value.imag) ||
  Double::is_inf(value.real) ||
  Double::is_inf(value.imag)
}

///|
fn complex_suffix_from_text(text : String) -> String {
  let trimmed = text.trim().to_string()
  if trimmed == "" {
    return "i"
  }
  let chars = trimmed.to_array()
  let last = chars[chars.length() - 1]
  let sb = StringBuilder::new()
  sb.write_char(last)
  sb.to_string()
}

///|
fn normalize_complex_text(text : StringView) -> String {
  let trimmed = text.trim().to_string()
  if trimmed == "" {
    return ""
  }
  let lower = trimmed.to_lower()
  let mut normalized = lower.replace_all(old="j", new="i")
  if normalized == "i" {
    normalized = "1i"
  }
  normalized = normalized.replace_all(old="+i", new="+1i")
  normalized = normalized.replace_all(old="-i", new="-1i")
  normalized
}

///|
fn split_complex_body(body : String) -> (String, String) {
  let chars = body.to_array()
  let mut split = -1
  let mut idx = 1
  while idx < chars.length() {
    let ch = chars[idx]
    if (ch == '+' || ch == '-') &&
      chars[idx - 1] != 'e' &&
      chars[idx - 1] != 'E' {
      split = idx
    }
    idx = idx + 1
  }
  if split < 0 {
    ("0", body)
  } else {
    let left = body.unsafe_substring(start=0, end=split)
    let right = body.unsafe_substring(start=split, end=body.length())
    (left, right)
  }
}

///|
fn parse_complex_text(text : StringView) -> Result[Complex, FormulaValue] {
  let normalized = normalize_complex_text(text)
  if normalized == "" {
    return Err(Error(formula_error_num))
  }
  if normalized.has_suffix("i") {
    let body = normalized.strip_suffix("i").unwrap().to_string()
    let (real_text, imag_text) = split_complex_body(body)
    match (parse_double_opt(real_text), parse_double_opt(imag_text)) {
      (Some(real), Some(imag)) => Ok(complex_new(real, imag))
      _ => Err(Error(formula_error_num))
    }
  } else {
    match parse_double_opt(normalized) {
      Some(real) => Ok(complex_new(real, 0.0))
      None => Err(Error(formula_error_num))
    }
  }
}

///|
fn parse_complex_value(value : FormulaValue) -> Result[Complex, FormulaValue] {
  match value_as_string(value) {
    Ok(text) => parse_complex_text(text)
    Err(err) => Err(err)
  }
}

///|
fn parse_complex_value_with_suffix(
  value : FormulaValue,
) -> Result[(Complex, String), FormulaValue] {
  match value_as_string(value) {
    Ok(text) => {
      let suffix = complex_suffix_from_text(text)
      match parse_complex_text(text) {
        Ok(num) => Ok((num, suffix))
        Err(err) => Err(err)
      }
    }
    Err(err) => Err(err)
  }
}

///|
fn complex_to_string(value : Complex, suffix : String) -> String {
  let real_raw = round_significant_digits(value.real, 15)
  let imag_raw = round_significant_digits(value.imag, 15)
  let real = if real_raw == 0.0 { 0.0 } else { real_raw }
  let imag = if imag_raw == 0.0 { 0.0 } else { imag_raw }
  let real_text = format_number(real)
  if imag == 0.0 {
    return real_text
  }
  let abs_imag = if imag < 0.0 { -imag } else { imag }
  let imag_text = format_number(abs_imag)
  let imag_part = if imag_text == "1" { suffix } else { imag_text + suffix }
  if real == 0.0 {
    if imag < 0.0 {
      return "-" + imag_part
    }
    return imag_part
  }
  let join = if imag < 0.0 { "-" } else { "+" }
  real_text + join + imag_part
}

///|
fn parse_date_parts(text : String) -> (Int, Int, Int)? {
  let trimmed = text.trim().to_string()
  if trimmed == "" {
    return None
  }
  let parts : Array[String] = []
  let mut current = StringBuilder::new()
  for ch in trimmed {
    if ch.is_ascii_digit() {
      current.write_char(ch)
    } else if ch == '/' || ch == '-' {
      let part = current.to_string()
      if part == "" {
        return None
      }
      parts.push(part)
      current = StringBuilder::new()
    } else if ch.is_ascii_whitespace() {
      continue
    } else {
      return None
    }
  }
  let last = current.to_string()
  if last == "" {
    return None
  }
  parts.push(last)
  if parts.length() != 3 {
    return None
  }
  let p0 = @string.parse_int(parts[0], base=10) catch { _ => return None }
  let p1 = @string.parse_int(parts[1], base=10) catch { _ => return None }
  let p2 = @string.parse_int(parts[2], base=10) catch { _ => return None }
  let year = if parts[0].length() == 4 {
    p0
  } else if parts[2].length() == 4 {
    p2
  } else if p2 <= 29 {
    2000 + p2
  } else {
    1900 + p2
  }
  let month = if parts[0].length() == 4 { p1 } else { p0 }
  let day = if parts[0].length() == 4 { p2 } else { p1 }
  Some((year, month, day))
}

///|
fn parse_time_parts(text : String) -> (Int, Int, Int)? {
  let trimmed = text.trim().to_upper()
  if trimmed == "" {
    return None
  }
  let mut is_pm = false
  let mut is_am = false
  let mut core = trimmed
  if core.has_suffix("AM") {
    is_am = true
    core = core[:core.length() - 2].trim().to_string()
  } else if core.has_suffix("PM") {
    is_pm = true
    core = core[:core.length() - 2].trim().to_string()
  }
  let parts : Array[String] = []
  let mut current = StringBuilder::new()
  for ch in core {
    if ch.is_ascii_digit() {
      current.write_char(ch)
    } else if ch == ':' {
      let part = current.to_string()
      if part == "" {
        return None
      }
      parts.push(part)
      current = StringBuilder::new()
    } else if ch.is_ascii_whitespace() {
      continue
    } else {
      return None
    }
  }
  let last = current.to_string()
  if last == "" {
    return None
  }
  parts.push(last)
  if parts.length() == 0 || parts.length() > 3 {
    return None
  }
  let hour = @string.parse_int(parts[0], base=10) catch { _ => return None }
  let minute = if parts.length() >= 2 {
    @string.parse_int(parts[1], base=10) catch {
      _ => return None
    }
  } else {
    0
  }
  let second = if parts.length() == 3 {
    @string.parse_int(parts[2], base=10) catch {
      _ => return None
    }
  } else {
    0
  }
  let mut hours = hour
  if is_am {
    if hours == 12 {
      hours = 0
    }
  } else if is_pm {
    if hours < 12 {
      hours = hours + 12
    }
  }
  Some((hours, minute, second))
}

///|
fn strip_hex_prefix(text : String) -> String {
  match text.strip_prefix("0x") {
    Some(rest) => rest.to_string()
    None =>
      match text.strip_prefix("0X") {
        Some(rest) => rest.to_string()
        None => text
      }
  }
}

///|
fn value_as_bool(value : FormulaValue) -> Result[Bool, FormulaValue] {
  match normalize_scalar(value) {
    Bool(flag) => Ok(flag)
    Number(num) => Ok(num == 1.0)
    Empty => Ok(false)
    String(text) => {
      let parsed = @string.parse_bool(text) catch {
        _ => return Err(Error(formula_error_value))
      }
      Ok(parsed)
    }
    Error(err) => Err(Error(err))
    List(_) => Err(Error(formula_error_value))
  }
}

///|
fn value_as_number_opt(value : FormulaValue) -> Double? {
  match normalize_scalar(value) {
    Number(num) => Some(num)
    Bool(flag) => Some(if flag { 1.0 } else { 0.0 })
    String(text) => parse_double_opt(text)
    _ => None
  }
}

///|
fn is_digits(text : StringView) -> Bool {
  if text == "" {
    return false
  }
  for ch in text {
    if ch < '0' || ch > '9' {
      return false
    }
  }
  true
}

///|
fn parse_criteria_number(text : StringView) -> Double? {
  match text.strip_suffix("%") {
    Some(stripped) =>
      match parse_double_opt(stripped) {
        Some(num) => Some(num / 100.0)
        None => None
      }
    None => parse_double_opt(text)
  }
}

///|
fn build_criteria_pattern(text : StringView) -> String {
  let chars = text.to_array()
  let sb = StringBuilder::new()
  let mut idx = 0
  while idx < chars.length() {
    let ch = chars[idx]
    if ch == '~' {
      if idx + 1 < chars.length() {
        let next = chars[idx + 1]
        sb.write_char(next)
        idx = idx + 2
      } else {
        sb.write_char('~')
        idx = idx + 1
      }
    } else if ch == '*' {
      sb.write_char('.')
      sb.write_char('*')
      idx = idx + 1
    } else if ch == '?' {
      sb.write_char('.')
      idx = idx + 1
    } else {
      sb.write_char(ch)
      idx = idx + 1
    }
  }
  sb.to_string()
}

///|
fn parse_formula_criteria(value : FormulaValue) -> FormulaCriteria {
  let text = formula_value_string(value)
  if text == "" {
    return { kind: Unset, condition: Empty }
  }
  if is_digits(text) {
    return {
      kind: Eq,
      condition: match parse_criteria_number(text) {
        Some(num) => Number(num)
        None => String(text)
      },
    }
  }
  let mut condition_text = text
  let kind = if text.has_prefix("<>") {
    condition_text = text[2:].to_string()
    FormulaCriteriaType::Ne
  } else if text.has_prefix("<=") {
    condition_text = text[2:].to_string()
    Le
  } else if text.has_prefix(">=") {
    condition_text = text[2:].to_string()
    Ge
  } else if text.has_prefix("<") {
    condition_text = text[1:].to_string()
    Lt
  } else if text.has_prefix(">") {
    condition_text = text[1:].to_string()
    Gt
  } else if text.has_prefix("=") {
    condition_text = text[1:].to_string()
    Eq
  } else {
    Regexp
  }
  match kind {
    Regexp => ()
    _ =>
      return {
        kind,
        condition: match parse_criteria_number(condition_text) {
          Some(num) => Number(num)
          None => String(condition_text)
        },
      }
  }
  let pattern = ".*" + build_criteria_pattern(condition_text) + ".*"
  let mut condition : FormulaValue = String(pattern)
  match parse_double_opt(pattern) {
    Some(num) => condition = Number(num)
    None => ()
  }
  { kind, condition }
}

///|
fn formula_criteria_condition_is_string(criteria : FormulaCriteria) -> Bool {
  match criteria.condition {
    String(_) => true
    _ => false
  }
}

///|
fn compare_criteria_values(left : FormulaValue, right : FormulaValue) -> Int? {
  let lhs = normalize_scalar(left)
  let rhs = normalize_scalar(right)
  match (lhs, rhs) {
    (Number(a), Number(b)) =>
      Some(if a < b { -1 } else if a > b { 1 } else { 0 })
    (Bool(a), Bool(b)) => {
      let la = if a { 1.0 } else { 0.0 }
      let rb = if b { 1.0 } else { 0.0 }
      Some(if la < rb { -1 } else if la > rb { 1 } else { 0 })
    }
    (Bool(a), Number(b)) => {
      let la = if a { 1.0 } else { 0.0 }
      Some(if la < b { -1 } else if la > b { 1 } else { 0 })
    }
    (Number(a), Bool(b)) => {
      let rb = if b { 1.0 } else { 0.0 }
      Some(if a < rb { -1 } else if a > rb { 1 } else { 0 })
    }
    (String(a), String(b)) => Some(compare_strings(a, b))
    (String(_), Number(_) | Bool(_)) => Some(1)
    (Number(_) | Bool(_), String(_)) => Some(-1)
    _ => None
  }
}

///|
fn regex_match_from(
  text : Array[Char],
  pattern : Array[Char],
  i : Int,
  j : Int,
  memo : Map[(Int, Int), Bool],
) -> Bool {
  match memo.get((i, j)) {
    Some(result) => return result
    None => ()
  }
  let result = if j == pattern.length() {
    i == text.length()
  } else if j + 1 < pattern.length() &&
    pattern[j] == '.' &&
    pattern[j + 1] == '*' {
    if regex_match_from(text, pattern, i, j + 2, memo) {
      true
    } else if i < text.length() {
      regex_match_from(text, pattern, i + 1, j, memo)
    } else {
      false
    }
  } else if i < text.length() && (pattern[j] == '.' || pattern[j] == text[i]) {
    regex_match_from(text, pattern, i + 1, j + 1, memo)
  } else {
    false
  }
  memo[(i, j)] = result
  result
}

///|
fn regex_like_match(text : StringView, pattern : StringView) -> Bool {
  let text_chars = text.to_array()
  let pattern_chars = pattern.to_array()
  let memo : Map[(Int, Int), Bool] = {}
  regex_match_from(text_chars, pattern_chars, 0, 0, memo)
}

///|
fn formula_criteria_eval(
  value : FormulaValue,
  criteria : FormulaCriteria,
) -> Bool {
  match criteria.kind {
    Unset => false
    Eq =>
      formula_value_string(value) == formula_value_string(criteria.condition)
    Ne =>
      formula_value_string(value) != formula_value_string(criteria.condition)
    Regexp =>
      regex_like_match(
        formula_value_string(value),
        formula_value_string(criteria.condition),
      )
    Lt | Le | Gt | Ge =>
      match compare_criteria_values(value, criteria.condition) {
        Some(result) =>
          match criteria.kind {
            Lt => result < 0
            Le => result <= 0
            Gt => result > 0
            Ge => result >= 0
            _ => false
          }
        None => false
      }
  }
}

///|
priv struct CalcDatabase {
  mut row : Int
  col : Int
  index_map : Map[Int, Int]
  database : RangeValues
  criteria : RangeValues
}

///|
fn calc_database_column_index(
  database : RangeValues,
  field : FormulaValue,
) -> Int {
  let normalized = normalize_scalar(field)
  match normalized {
    Error(_) => return -1
    _ => ()
  }
  match value_as_number_opt(normalized) {
    Some(num) => return Double::to_int(trunc_double(num)) - 1
    None => ()
  }
  let field_text = formula_value_string(normalized).to_lower()
  if field_text == "" {
    return -1
  }
  for idx in 0..<database.cols {
    match database.get(0, idx) {
      Some(value) =>
        if formula_value_string(value).to_lower() == field_text {
          return idx
        }
      None => ()
    }
  }
  -1
}

///|
fn calc_database_new(
  database : RangeValues,
  field : FormulaValue,
  criteria : RangeValues,
) -> CalcDatabase? {
  let invalid = database.rows < 2 ||
    database.cols < 1 ||
    criteria.rows < 2 ||
    criteria.cols < 1
  if invalid {
    return None
  }
  let mut col = -1
  let normalized_field = normalize_scalar(field)
  let has_field = match normalized_field {
    Empty => false
    _ => true
  }
  if has_field {
    col = calc_database_column_index(database, field)
    if col < 0 || col >= database.cols {
      return None
    }
  }
  Some({ row: 0, col, index_map: {}, database, criteria })
}

///|
fn calc_database_value(db : CalcDatabase) -> FormulaValue {
  if db.col == -1 {
    match db.database.get(db.row, db.database.cols - 1) {
      Some(value) => value
      None => Empty
    }
  } else {
    match db.database.get(db.row, db.col) {
      Some(value) => value
      None => Empty
    }
  }
}

///|
fn calc_database_criteria_eval(db : CalcDatabase) -> Bool {
  let columns = db.criteria.cols
  let rows = db.criteria.rows
  if db.index_map.get(0) is None {
    for j in 0..<columns {
      let header = match db.criteria.get(0, j) {
        Some(value) => value
        None => Empty
      }
      let idx = calc_database_column_index(db.database, header)
      if idx < 0 {
        return false
      }
      db.index_map[j] = idx
    }
  }
  let mut matched = false
  let mut i = 1
  while !matched && i < rows {
    let mut row_match = true
    let mut j = 0
    while row_match && j < columns {
      let criteria_value = match db.criteria.get(i, j) {
        Some(value) => value
        None => Empty
      }
      if formula_value_string(criteria_value) != "" {
        let criteria = parse_formula_criteria(criteria_value)
        let col_index = match db.index_map.get(j) {
          Some(value) => value
          None => return false
        }
        let cell = match db.database.get(db.row, col_index) {
          Some(value) => value
          None => Empty
        }
        if !formula_criteria_eval(cell, criteria) {
          row_match = false
        }
      }
      j = j + 1
    }
    if row_match {
      matched = true
    }
    i = i + 1
  }
  matched
}

///|
fn calc_database_next(db : CalcDatabase) -> Bool {
  let rows = db.database.rows
  let mut matched = false
  while !matched && db.row < rows {
    db.row = db.row + 1
    if db.row < rows {
      matched = calc_database_criteria_eval(db)
    }
  }
  matched
}

///|
fn database_collect_values(
  database : RangeValues,
  field : FormulaValue,
  criteria : RangeValues,
) -> Result[Array[FormulaValue], FormulaValue] {
  let db = match calc_database_new(database, field, criteria) {
    Some(value) => value
    None => return Err(Error(formula_error_value))
  }
  let values : Array[FormulaValue] = []
  while calc_database_next(db) {
    values.push(calc_database_value(db))
  }
  Ok(values)
}

///|
fn database_count_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  let mut count = 0
  for value in values {
    match normalize_scalar(value) {
      Number(_) => count = count + 1
      String(text) =>
        match parse_double_opt(text) {
          Some(_) => count = count + 1
          None => ()
        }
      Bool(_) => ()
      Error(_) => ()
      Empty => ()
      List(_) => ()
    }
  }
  Number(Double::from_int(count))
}

///|
fn database_values(
  name : String,
  database : RangeValues,
  field : FormulaValue,
  criteria : RangeValues,
) -> FormulaValue {
  let values = match database_collect_values(database, field, criteria) {
    Ok(items) => items
    Err(err) => return err
  }
  match name {
    "DMAX" => max_values(values)
    "DMIN" => min_values(values)
    "DPRODUCT" => product_values(values)
    "DSUM" => sum_values(values)
    "DSTDEV" => stdev_values(false, values)
    "DSTDEVP" =>
      match variance_values(values, false, false) {
        Number(variance) => {
          let result = @math.pow(variance, 0.5)
          Number(round_significant_digits(result, 15))
        }
        Error(err) => Error(err)
        _ => Error(formula_error_value)
      }
    "DVAR" => variance_values(values, true, false)
    "DVARP" => variance_values(values, false, false)
    _ => average_values(values)
  }
}

///|
fn dcount_values(
  name : String,
  database : RangeValues,
  field : FormulaValue,
  criteria : RangeValues,
) -> FormulaValue {
  let values = match database_collect_values(database, field, criteria) {
    Ok(items) => items
    Err(err) => return err
  }
  if name == "DCOUNT" {
    database_count_values(values)
  } else {
    counta_values(values)
  }
}

///|
fn dget_values(
  database : RangeValues,
  field : FormulaValue,
  criteria : RangeValues,
) -> FormulaValue {
  let db = match calc_database_new(database, field, criteria) {
    Some(value) => value
    None => return Error(formula_error_value)
  }
  let mut value = FormulaValue::Error(formula_error_value)
  if calc_database_next(db) {
    value = calc_database_value(db)
    if calc_database_next(db) {
      return Error(formula_error_num)
    }
  }
  value
}

///|
fn abs_double(value : Double) -> Double {
  if value < 0.0 {
    -value
  } else {
    value
  }
}

///|
fn trunc_double(value : Double) -> Double {
  if value < 0.0 {
    -Double::floor(-value)
  } else {
    Double::floor(value)
  }
}

///|
fn modf_double(value : Double) -> (Double, Double) {
  let truncated = trunc_double(value)
  (truncated, value - truncated)
}

///|
fn normalize_year_month(year : Int, month : Int) -> (Int, Int) {
  let mut y = year
  let mut m = month
  while m <= 0 {
    m = m + 12
    y = y - 1
  }
  while m > 12 {
    m = m - 12
    y = y + 1
  }
  (y, m)
}

///|
fn normalize_date_parts(year : Int, month : Int, day : Int) -> (Int, Int, Int) {
  let (year_value, month_value) = normalize_year_month(year, month)
  let mut y = year_value
  let mut m = month_value
  let mut d = day
  while d <= 0 {
    m = m - 1
    if m <= 0 {
      m = 12
      y = y - 1
    }
    d = d + days_in_month(y, m)
  }
  let mut dim = days_in_month(y, m)
  while d > dim {
    d = d - dim
    m = m + 1
    if m > 12 {
      m = 1
      y = y + 1
    }
    dim = days_in_month(y, m)
  }
  (y, m, d)
}

///|
fn days_before_year(year : Int) -> Int {
  let mut days = 0
  let mut y = 1900
  if year >= 1900 {
    while y < year {
      let inc = if is_leap_year(y) { 366 } else { 365 }
      days = days + inc
      y = y + 1
    }
  } else {
    while y > year {
      y = y - 1
      let dec = if is_leap_year(y) { 366 } else { 365 }
      days = days - dec
    }
  }
  days
}

///|
fn days_before_month(year : Int, month : Int) -> Int {
  let mut days = 0
  for m in 1..<month {
    days = days + days_in_month(year, m)
  }
  days
}

///|
fn excel_serial_from_date(year : Int, month : Int, day : Int) -> Double? {
  if year < 0 || year > 9999 {
    return None
  }
  let (y, m, d) = normalize_date_parts(year, month, day)
  if y < 0 || y > 9999 {
    return None
  }
  let mut days = days_before_year(y)
  days = days + days_before_month(y, m)
  days = days + (d - 1)
  let mut serial = days + 1
  if serial >= 60 {
    serial = serial + 1
  }
  if serial < 0 {
    None
  } else {
    Some(Double::from_int(serial))
  }
}

///|
fn excel_time_fraction(hours : Int, minutes : Int, seconds : Int) -> Double? {
  if hours < 0 || minutes < 0 || seconds < 0 {
    return None
  }
  let total = hours * 3600 + minutes * 60 + seconds
  let wrapped = total % 86400
  Some(Double::from_int(wrapped) / 86400.0)
}

///|
fn excel_serial_parts(
  value : FormulaValue,
) -> Result[(Int, Int, Int, Int, Int, Int), FormulaValue] {
  match value_as_number(value) {
    Ok(num) =>
      match excel_serial_to_parts(num) {
        Some(parts) => Ok(parts)
        None => Err(Error(formula_error_num))
      }
    Err(err) => Err(err)
  }
}

///|
fn date_parts_from_serial(serial : Double) -> (Int, Int, Int)? {
  match excel_serial_to_parts(serial) {
    Some((year, month, day, _, _, _)) => Some((year, month, day))
    None => None
  }
}

///|
fn value_as_date_serial(value : FormulaValue) -> Result[Double, FormulaValue] {
  match normalize_scalar(value) {
    Number(num) =>
      if num < 0.0 {
        Err(Error(formula_error_num))
      } else {
        Ok(num)
      }
    Bool(flag) => Ok(if flag { 1.0 } else { 0.0 })
    Empty => Ok(0.0)
    String(text) => {
      let trimmed = text.trim().to_string()
      match parse_date_parts(trimmed) {
        Some((year, month, day)) =>
          match excel_serial_from_date(year, month, day) {
            Some(serial) => Ok(serial)
            None => Err(Error(formula_error_value))
          }
        None =>
          match parse_value_number(trimmed) {
            Some(num) =>
              if num < 0.0 {
                Err(Error(formula_error_num))
              } else {
                Ok(num)
              }
            None => Err(Error(formula_error_value))
          }
      }
    }
    Error(err) => Err(Error(err))
    List(_) => Err(Error(formula_error_value))
  }
}

///|
fn date_parts_from_value(
  value : FormulaValue,
) -> Result[(Int, Int, Int), FormulaValue] {
  match value_as_date_serial(value) {
    Ok(serial) =>
      match date_parts_from_serial(serial) {
        Some(parts) => Ok(parts)
        None => Err(Error(formula_error_num))
      }
    Err(err) => Err(err)
  }
}

///|
fn days_in_year(year : Int) -> Int {
  if is_leap_year(year) {
    366
  } else {
    365
  }
}

///|
fn day_of_year(year : Int, month : Int, day : Int) -> Int {
  days_before_month(year, month) + day
}

///|
fn weekday_monday1(year : Int, month : Int, day : Int) -> Int {
  let mut days = days_before_year(year)
  days = days + days_before_month(year, month)
  days = days + (day - 1)
  let mut idx = days % 7
  if idx < 0 {
    idx = idx + 7
  }
  idx + 1
}

///|
fn weekday_sun1(year : Int, month : Int, day : Int) -> Int {
  let monday = weekday_monday1(year, month, day)
  if monday == 7 {
    1
  } else {
    monday + 1
  }
}

///|
fn iso_week_number(year : Int, month : Int, day : Int) -> Int? {
  let serial = match excel_serial_from_date(year, month, day) {
    Some(value) => value
    None => return None
  }
  let weekday = weekday_monday1(year, month, day)
  let thursday_serial = serial + Double::from_int(4 - weekday)
  let (iso_year, _, _) = match date_parts_from_serial(thursday_serial) {
    Some(parts) => parts
    None => return None
  }
  let week1_serial = match excel_serial_from_date(iso_year, 1, 4) {
    Some(value) => value
    None => return None
  }
  let week1_weekday = weekday_monday1(iso_year, 1, 4)
  let week1_thursday = week1_serial + Double::from_int(4 - week1_weekday)
  let offset = (thursday_serial - week1_thursday) / 7.0
  Some(Double::to_int(Double::floor(offset)) + 1)
}

///|
fn weekend_mask_from_value(
  value : FormulaValue,
) -> Result[(Array[Int], Int), FormulaValue] {
  let weekend_mask : Array[Int] = [0, 0, 0, 0, 0, 0, 0]
  let mut workdays = 0
  let parse_code = fn(code : Int) -> Result[Unit, FormulaValue] {
    let indices = match code {
      1 => [5, 6]
      2 => [6, 0]
      3 => [0, 1]
      4 => [1, 2]
      5 => [2, 3]
      6 => [3, 4]
      7 => [4, 5]
      11 => [6]
      12 => [0]
      13 => [1]
      14 => [2]
      15 => [3]
      16 => [4]
      17 => [5]
      _ => return Err(Error(formula_error_value))
    }
    for idx in indices {
      weekend_mask[idx] = 1
    }
    Ok(())
  }
  match normalize_scalar(value) {
    String(text) => {
      let trimmed = text.trim().to_string()
      if trimmed.length() == 7 {
        let mut idx = 0
        for ch in trimmed {
          if ch == '0' {
            weekend_mask[idx] = 0
          } else if ch == '1' {
            weekend_mask[idx] = 1
          } else {
            return Err(Error(formula_error_value))
          }
          idx = idx + 1
        }
      } else {
        match parse_value_number(trimmed) {
          Some(num) => {
            let code = Double::to_int(trunc_double(num))
            match parse_code(code) {
              Ok(_) => ()
              Err(err) => return Err(err)
            }
          }
          None => return Err(Error(formula_error_value))
        }
      }
    }
    _ =>
      match value_as_number(value) {
        Ok(num) => {
          let code = Double::to_int(trunc_double(num))
          match parse_code(code) {
            Ok(_) => ()
            Err(err) => return Err(err)
          }
        }
        Err(err) => return Err(err)
      }
  }
  for mask in weekend_mask {
    if mask == 0 {
      workdays = workdays + 1
    }
  }
  Ok((weekend_mask, workdays))
}

///|
fn is_workday_mask(weekend_mask : Array[Int], serial : Double) -> Bool {
  match date_parts_from_serial(serial) {
    Some((year, month, day)) => {
      let weekday = weekday_monday1(year, month, day)
      weekend_mask[weekday - 1] == 0
    }
    None => false
  }
}

///|
fn collect_holidays(value : FormulaValue) -> Array[Int] {
  let holidays : Array[Int] = []
  for item in flatten_values([value]) {
    match value_as_date_serial(item) {
      Ok(serial) => holidays.push(Double::to_int(Double::ceil(serial)))
      Err(_) => ()
    }
  }
  holidays
}

///|
fn workday_intl_adjust(
  end_date : Int,
  sign : Int,
  holidays : Array[Int],
  weekend_mask : Array[Int],
  start_serial : Double,
) -> Int {
  let mut adjusted = end_date
  for holiday in holidays {
    if sign > 0 {
      if holiday > adjusted {
        break
      }
      if holiday > Double::to_int(Double::ceil(start_serial)) {
        if is_workday_mask(weekend_mask, Double::from_int(holiday)) {
          adjusted = adjusted + sign
          while !is_workday_mask(weekend_mask, Double::from_int(adjusted)) {
            adjusted = adjusted + sign
          }
        }
      }
    } else {
      if holiday < adjusted {
        continue
      }
      if holiday < Double::to_int(Double::ceil(start_serial)) {
        if is_workday_mask(weekend_mask, Double::from_int(holiday)) {
          adjusted = adjusted + sign
          while !is_workday_mask(weekend_mask, Double::from_int(adjusted)) {
            adjusted = adjusted + sign
          }
        }
      }
    }
  }
  adjusted
}

///|
fn networkdays_intl_value(
  start_serial : Double,
  end_serial : Double,
  weekend_value : FormulaValue,
  holidays : Array[Int],
) -> FormulaValue {
  holidays.sort()
  let (weekend_mask, workdays) = match weekend_mask_from_value(weekend_value) {
    Ok(value) => value
    Err(err) => return err
  }
  if workdays == 0 {
    return Error(formula_error_value)
  }
  let mut start = start_serial
  let mut end = end_serial
  let mut sign = 1
  if start > end {
    sign = -1
    let temp = start
    start = end
    end = temp
  }
  let offset = end - start
  let weeks = Double::to_int(Double::floor(offset / 7.0))
  let mut count = weeks * workdays
  let mut days_mod = Double::to_int(Double::floor(offset)) % 7
  while days_mod >= 0 {
    if is_workday_mask(weekend_mask, end - Double::from_int(days_mod)) {
      count = count + 1
    }
    days_mod = days_mod - 1
  }
  for holiday in holidays {
    let holiday_serial = Double::from_int(holiday)
    if is_workday_mask(weekend_mask, holiday_serial) &&
      holiday_serial >= start &&
      holiday_serial <= end {
      count = count - 1
    }
  }
  Number(Double::from_int(sign * count))
}

///|
fn workday_intl_value(
  start_serial : Double,
  days : Double,
  weekend_value : FormulaValue,
  holidays : Array[Int],
) -> FormulaValue {
  holidays.sort()
  if days == 0.0 {
    return Number(Double::ceil(start_serial))
  }
  let (weekend_mask, workdays) = match weekend_mask_from_value(weekend_value) {
    Ok(value) => value
    Err(err) => return err
  }
  if workdays == 0 {
    return Error(formula_error_value)
  }
  let mut sign = 1
  if days < 0.0 {
    sign = -1
  }
  let days_int = Double::to_int(trunc_double(days))
  let offset = days_int / workdays
  let mut days_mod = days_int % workdays
  let mut end_date = Double::to_int(Double::ceil(start_serial)) + offset * 7
  if days_mod == 0 {
    while !is_workday_mask(weekend_mask, Double::from_int(end_date)) {
      end_date = end_date - sign
    }
  } else {
    while days_mod != 0 {
      end_date = end_date + sign
      if is_workday_mask(weekend_mask, Double::from_int(end_date)) {
        if days_mod < 0 {
          days_mod = days_mod + 1
        } else {
          days_mod = days_mod - 1
        }
      }
    }
  }
  let adjusted = workday_intl_adjust(
    end_date, sign, holidays, weekend_mask, start_serial,
  )
  Number(Double::from_int(adjusted))
}

///|
fn yearfrac_basis_cond(
  sy : Int,
  sm : Int,
  sd : Int,
  ey : Int,
  em : Int,
  ed : Int,
) -> Bool {
  (is_leap_year(sy) && (sm < 2 || (sm == 2 && sd <= 29))) ||
  (is_leap_year(ey) && (em > 2 || (em == 2 && ed == 29)))
}

///|
fn yearfrac_basis0(
  start_serial : Double,
  end_serial : Double,
) -> (Double, Double) {
  let (sy, sm, sd) = match date_parts_from_serial(start_serial) {
    Some(parts) => parts
    None => return (0.0, 0.0)
  }
  let (ey, em, ed) = match date_parts_from_serial(end_serial) {
    Some(parts) => parts
    None => return (0.0, 0.0)
  }
  let mut start_day = sd
  let mut end_day = ed
  if start_day == 31 {
    start_day = 30
  }
  if start_day == 30 && end_day == 31 {
    end_day = 30
  } else if sm == 2 && start_day == days_in_month(sy, sm) {
    start_day = 30
    if em == 2 && end_day == days_in_month(ey, em) {
      end_day = 30
    }
  }
  let diff = (ey - sy) * 360 + (em - sm) * 30 + (end_day - start_day)
  (Double::from_int(diff), 360.0)
}

///|
fn yearfrac_basis1(
  start_serial : Double,
  end_serial : Double,
) -> (Double, Double) {
  let (sy, sm, sd) = match date_parts_from_serial(start_serial) {
    Some(parts) => parts
    None => return (0.0, 0.0)
  }
  let (ey, em, ed) = match date_parts_from_serial(end_serial) {
    Some(parts) => parts
    None => return (0.0, 0.0)
  }
  let day_diff = end_serial - start_serial
  let is_year_different = sy != ey
  let days_in_year_value = if is_year_different &&
    (ey != sy + 1 || sm < em || (sm == em && sd < ed)) {
    let mut day_count = 0
    for y in sy..<=ey {
      day_count = day_count + days_in_year(y)
    }
    Double::from_int(day_count) / Double::from_int(ey - sy + 1)
  } else if !is_year_different && is_leap_year(sy) {
    366.0
  } else if is_year_different && yearfrac_basis_cond(sy, sm, sd, ey, em, ed) {
    366.0
  } else {
    365.0
  }
  (day_diff, days_in_year_value)
}

///|
fn yearfrac_basis4(
  start_serial : Double,
  end_serial : Double,
) -> (Double, Double) {
  let (sy, sm, sd) = match date_parts_from_serial(start_serial) {
    Some(parts) => parts
    None => return (0.0, 0.0)
  }
  let (ey, em, ed) = match date_parts_from_serial(end_serial) {
    Some(parts) => parts
    None => return (0.0, 0.0)
  }
  let mut start_day = sd
  let mut end_day = ed
  if start_day == 31 {
    start_day = 30
  }
  if end_day == 31 {
    end_day = 30
  }
  let diff = (ey - sy) * 360 + (em - sm) * 30 + (end_day - start_day)
  (Double::from_int(diff), 360.0)
}

///|
fn yearfrac_value(
  start_serial : Double,
  end_serial : Double,
  basis : Int,
) -> FormulaValue {
  if start_serial == end_serial {
    return Number(0.0)
  }
  let (day_diff, days_in_year) = match basis {
    0 => yearfrac_basis0(start_serial, end_serial)
    1 => yearfrac_basis1(start_serial, end_serial)
    2 => (end_serial - start_serial, 360.0)
    3 => (end_serial - start_serial, 365.0)
    4 => yearfrac_basis4(start_serial, end_serial)
    _ => return Error(formula_error_num)
  }
  if days_in_year == 0.0 {
    Error(formula_error_value)
  } else {
    Number(day_diff / days_in_year)
  }
}

///|
fn gcd_double(left : Double, right : Double) -> Double {
  let mut x = trunc_double(left)
  let mut y = trunc_double(right)
  if x == 0.0 {
    return y
  }
  if y == 0.0 {
    return x
  }
  while x != y {
    if x > y {
      x = x - y
    } else {
      y = y - x
    }
  }
  x
}

///|
fn lcm_double(left : Double, right : Double) -> Double {
  let x = trunc_double(left)
  let y = trunc_double(right)
  if x == 0.0 && y == 0.0 {
    return 0.0
  }
  x * y / gcd_double(x, y)
}

///|
fn round_half_away_from_zero(value : Double) -> Double {
  if value < 0.0 {
    -Double::floor(-value + 0.5)
  } else {
    Double::floor(value + 0.5)
  }
}

///|
fn round_significant_digits(value : Double, digits : Int) -> Double {
  if value == 0.0 {
    return 0.0
  }
  let abs_value = Double::abs(value)
  let exponent = Double::floor(@math.log10(abs_value))
  let scale = @math.pow(10.0, Double::from_int(digits - 1) - exponent)
  round_half_away_from_zero(value * scale) / scale
}

///|
fn round_chisq_result(value : Double) -> Double {
  let abs_value = Double::abs(value)
  if abs_value >= 0.1 || abs_value < 0.01 {
    round_significant_digits(value, 15)
  } else {
    value
  }
}

///|
fn number_or_num_error(value : Double) -> FormulaValue {
  if Double::is_nan(value) || Double::is_inf(value) {
    Error(formula_error_num)
  } else {
    Number(value)
  }
}

///|
fn weibull_value(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 4 {
    return Error(formula_error_value)
  }
  let x = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let alpha = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  let beta = match value_as_number(values[2]) {
    Ok(num) => num
    Err(err) => return err
  }
  let cumulative = match value_as_bool(values[3]) {
    Ok(flag) => flag
    Err(err) => return err
  }
  if alpha <= 0.0 || beta <= 0.0 {
    return Error(formula_error_na)
  }
  let exponent = @math.pow(x / beta, alpha)
  if cumulative {
    let result = 1.0 - @math.exp(-exponent)
    number_or_num_error(round_significant_digits(result, 15))
  } else {
    let denom = @math.pow(beta, alpha)
    let result = alpha /
      denom *
      @math.pow(x, alpha - 1.0) *
      @math.exp(-exponent)
    number_or_num_error(round_significant_digits(result, 15))
  }
}

///|
fn get_beta_helper_cont_frac(fx : Double, fa : Double, fb : Double) -> Double {
  let mut a1 = 1.0
  let mut b1 = 1.0
  let mut b2 = 1.0 - (fa + fb) / (fa + 1.0) * fx
  let mut a2 = 0.0
  let mut fnorm = 1.0
  let mut cf = 1.0
  if b2 == 0.0 {
    a2 = 0.0
    fnorm = 1.0
    cf = 1.0
  } else {
    a2 = 1.0
    fnorm = 1.0 / b2
    cf = a2 * fnorm
  }
  let mut cfnew = 1.0
  let mut rm = 1.0
  let max_iter = 50000.0
  let mach_eps = 2.22045e-016
  let mut finished = false
  while rm < max_iter && !finished {
    let apl2m = fa + 2.0 * rm
    let d2m = rm * (fb - rm) * fx / ((apl2m - 1.0) * apl2m)
    let d2m1 = -(fa + rm) * (fa + fb + rm) * fx / (apl2m * (apl2m + 1.0))
    a1 = (a2 + d2m * a1) * fnorm
    b1 = (b2 + d2m * b1) * fnorm
    a2 = a1 + d2m1 * a2 * fnorm
    b2 = b1 + d2m1 * b2 * fnorm
    if b2 != 0.0 {
      fnorm = 1.0 / b2
      cfnew = a2 * fnorm
      finished = Double::abs(cf - cfnew) < Double::abs(cf) * mach_eps
    }
    cf = cfnew
    rm = rm + 1.0
  }
  cf
}

///|
fn get_lanczos_sum(fz : Double) -> Double {
  let num : Array[Double] = [
    23531376880.41075968857200767445163675473, 42919803642.64909876895789904700198885093,
    35711959237.35566804944018545154716670596, 17921034426.03720969991975575445893111267,
    6039542586.35202800506429164430729792107, 1439720407.311721673663223072794912393972,
    248874557.8620541565114603864132294232163, 31426415.58540019438061423162831820536287,
    2876370.628935372441225409051620849613599, 186056.2653952234950402949897160456992822,
    8071.672002365816210638002902272250613822, 210.8242777515793458725097339207133627117,
    2.506628274631000270164908177133837338626,
  ]
  let denom : Array[Double] = [
    0.0, 39916800.0, 120543840.0, 150917976.0, 105258076.0, 45995730.0, 13339535.0,
    2637558.0, 357423.0, 32670.0, 1925.0, 66.0, 1.0,
  ]
  let mut sum_num = 0.0
  let mut sum_denom = 0.0
  if fz <= 1.0 {
    sum_num = num[12]
    sum_denom = denom[12]
    for i in 0..<12 {
      let idx = 11 - i
      sum_num = sum_num * fz + num[idx]
      sum_denom = sum_denom * fz + denom[idx]
    }
  } else {
    let z_inv = 1.0 / fz
    sum_num = num[0]
    sum_denom = denom[0]
    for i in 1..<=12 {
      sum_num = sum_num * z_inv + num[i]
      sum_denom = sum_denom * z_inv + denom[i]
    }
  }
  sum_num / sum_denom
}

///|
fn get_log_beta(falpha : Double, fbeta : Double) -> Double {
  let mut fa = falpha
  let mut fb = fbeta
  if falpha > fbeta {
    fa = falpha
    fb = fbeta
  } else {
    fa = fbeta
    fb = falpha
  }
  let fg = 6.024680040776729583740234375
  let fgm = fg - 0.5
  let mut lanczos = get_lanczos_sum(fa)
  lanczos = lanczos / get_lanczos_sum(fa + fb)
  lanczos = lanczos * get_lanczos_sum(fb)
  let mut log_lanczos = @math.ln(lanczos)
  let fabgm = fa + fb + fgm
  log_lanczos = log_lanczos +
    0.5 * (@math.ln(fabgm) - @math.ln(fa + fgm) - @math.ln(fb + fgm))
  let temp_a = fb / (fa + fgm)
  let temp_b = fa / (fb + fgm)
  let mut result = -fa * @math.ln_1p(temp_a) - fb * @math.ln_1p(temp_b) - fgm
  result = result + log_lanczos
  result
}

///|
fn get_beta(falpha : Double, fbeta : Double) -> Double {
  @math.exp(get_log_beta(falpha, fbeta))
}

///|
fn get_beta_dist_pdf(fx : Double, fa : Double, fb : Double) -> Double {
  if fx <= 0.0 || fx >= 1.0 {
    return 0.0
  }
  let log_dbl_max = @math.ln(1.79769e+308)
  let log_dbl_min = @math.ln(2.22507e-308)
  let mut log_y = @math.ln(0.5 - fx + 0.5)
  if fx < 0.1 {
    log_y = @math.ln_1p(-fx)
  }
  let log_x = @math.ln(fx)
  let a_log_x = (fa - 1.0) * log_x
  let b_log_y = (fb - 1.0) * log_y
  let log_beta = get_log_beta(fa, fb)
  if a_log_x < log_dbl_max &&
    a_log_x > log_dbl_min &&
    b_log_y < log_dbl_max &&
    b_log_y > log_dbl_min &&
    log_beta < log_dbl_max &&
    log_beta > log_dbl_min &&
    a_log_x + b_log_y < log_dbl_max &&
    a_log_x + b_log_y > log_dbl_min {
    @math.pow(fx, fa - 1.0) *
    @math.pow(0.5 - fx + 0.5, fb - 1.0) /
    get_beta(fa, fb)
  } else {
    @math.exp(a_log_x + b_log_y - log_beta)
  }
}

///|
fn get_beta_dist(fxin : Double, falpha : Double, fbeta : Double) -> Double {
  if fxin <= 0.0 {
    return 0.0
  }
  if fxin >= 1.0 {
    return 1.0
  }
  if fbeta == 1.0 {
    return @math.pow(fxin, falpha)
  }
  if falpha == 1.0 {
    return -@math.expm1(fbeta * @math.ln_1p(-fxin))
  }
  let mut fy = 0.5 - fxin + 0.5
  let mut f_x = fxin
  let mut ln_x = @math.ln(fxin)
  let mut ln_y = @math.ln_1p(-fxin)
  let mut fa = falpha
  let mut fb = fbeta
  let reflect = fxin > falpha / (falpha + fbeta)
  if reflect {
    fa = fbeta
    fb = falpha
    f_x = fy
    fy = fxin
    ln_x = ln_y
    ln_y = @math.ln(fxin)
  }
  let mut result = get_beta_helper_cont_frac(f_x, fa, fb) / fa
  let fp = fa / (fa + fb)
  let fq = fb / (fa + fb)
  let temp = if fa > 1.0 && fb > 1.0 && fp < 0.97 && fq < 0.97 {
    get_beta_dist_pdf(f_x, fa, fb) * f_x * fy
  } else {
    @math.exp(fa * ln_x + fb * ln_y - get_log_beta(fa, fb))
  }
  result = result * temp
  if reflect {
    result = 0.5 - result + 0.5
  }
  result
}

///|
fn get_t_dist(t : Double, df : Double, ntype : Double) -> Double {
  match ntype {
    1.0 => 0.5 * get_beta_dist(df / (df + t * t), df / 2.0, 0.5)
    2.0 => get_beta_dist(df / (df + t * t), df / 2.0, 0.5)
    3.0 =>
      @math.pow(1.0 + t * t / df, -(df + 1.0) / 2.0) /
      (Double::sqrt(df) * get_beta(0.5, df / 2.0))
    4.0 => {
      let x = df / (t * t + df)
      let r = 0.5 * get_beta_dist(x, 0.5 * df, 0.5)
      if t < 0.0 {
        r
      } else {
        1.0 - r
      }
    }
    _ => 0.0
  }
}

///|
fn get_gamma_series(fa : Double, fx : Double) -> Double {
  let half_eps = 2.22045e-016 / 2.0
  let mut denom = fa
  let mut summand = 1.0 / fa
  let mut sum = summand
  let mut count = 1
  while summand / sum > half_eps && count <= 10000 {
    denom = denom + 1.0
    summand = summand * fx / denom
    sum = sum + summand
    count = count + 1
  }
  sum
}

///|
fn get_gamma_cont_fraction(fa : Double, fx : Double) -> Double {
  let big_inv = 2.22045e-016
  let half_eps = big_inv / 2.0
  let big = 1.0 / big_inv
  let mut count = 0.0
  let mut y = 1.0 - fa
  let mut denom = fx + 2.0 - fa
  let mut pkm1 = fx + 1.0
  let mut pkm2 = 1.0
  let mut qkm1 = denom * fx
  let mut qkm2 = fx
  let mut approx = pkm1 / qkm1
  let mut finished = false
  while !finished && count < 10000.0 {
    count = count + 1.0
    y = y + 1.0
    denom = denom + 2.0
    let num = y * count
    let f1 = pkm1 * denom
    let f2 = pkm2 * num
    let pk = f1 - f2
    let f3 = qkm1 * denom
    let f4 = qkm2 * num
    let qk = f3 - f4
    if qk != 0.0 {
      let r = pk / qk
      finished = Double::abs((approx - r) / r) <= half_eps
      approx = r
    }
    pkm2 = pkm1
    pkm1 = pk
    qkm2 = qkm1
    qkm1 = qk
    if Double::abs(pk) > big {
      pkm2 = pkm2 * big_inv
      pkm1 = pkm1 * big_inv
      qkm2 = qkm2 * big_inv
      qkm1 = qkm1 * big_inv
    }
  }
  approx
}

///|
fn get_log_gamma_helper(fz : Double) -> Double {
  let fg = 6.024680040776729583740234375
  let zg_help = fz + fg - 0.5
  @math.ln(get_lanczos_sum(fz)) + (fz - 0.5) * @math.ln(zg_help) - zg_help
}

///|
fn get_gamma_helper(fz : Double) -> Double {
  let fg = 6.024680040776729583740234375
  let zg_help = fz + fg - 0.5
  let half_power = @math.pow(zg_help, fz / 2.0 - 0.25)
  let mut gamma = get_lanczos_sum(fz)
  gamma = gamma * half_power
  gamma = gamma / @math.exp(zg_help)
  gamma = gamma * half_power
  if fz <= 20.0 && fz == Double::floor(fz) {
    gamma = round_half_away_from_zero(gamma)
  }
  gamma
}

///|
fn get_log_gamma(fz : Double) -> Double {
  let max_gamma_argument = 171.624376956302
  if fz >= max_gamma_argument {
    return get_log_gamma_helper(fz)
  }
  if fz >= 1.0 {
    return @math.ln(get_gamma_helper(fz))
  }
  if fz >= 0.5 {
    return @math.ln(get_gamma_helper(fz + 1.0) / fz)
  }
  get_log_gamma_helper(fz + 2.0) - @math.ln(fz + 1.0) - @math.ln(fz)
}

///|
fn get_gamma(fz : Double) -> Double {
  @math.exp(get_log_gamma(fz))
}

///|
fn get_low_reg_igamma(fa : Double, fx : Double) -> Double {
  let ln_factor = fa * @math.ln(fx) - fx - get_log_gamma(fa)
  let factor = @math.exp(ln_factor)
  if fx > fa + 1.0 {
    1.0 - factor * get_gamma_cont_fraction(fa, fx)
  } else {
    factor * get_gamma_series(fa, fx)
  }
}

///|
fn get_chisq_dist_cdf(fx : Double, fdf : Double) -> Double {
  if fx <= 0.0 {
    return 0.0
  }
  get_low_reg_igamma(fdf / 2.0, fx / 2.0)
}

///|
fn get_chisq_dist_pdf(fx : Double, fdf : Double) -> Double {
  if fdf * fx > 1391000.0 {
    return @math.exp(
      (0.5 * fdf - 1.0) * @math.ln(fx * 0.5) -
      0.5 * fx -
      @math.ln(2.0) -
      get_log_gamma(0.5 * fdf),
    )
  }
  let mut count = 0.0
  let mut value = 0.0
  let fdf_mod = fdf - Double::floor(fdf / 2.0) * 2.0
  if fdf_mod < 0.5 {
    value = 0.5
    count = 2.0
  } else {
    value = 1.0 / Double::sqrt(fx * 2.0 * @math.PI)
    count = 1.0
  }
  while count < fdf {
    value = value * fx / count
    count = count + 2.0
  }
  if fx >= 1425.0 {
    @math.exp(@math.ln(value) - fx / 2.0)
  } else {
    value * @math.exp(-fx / 2.0)
  }
}

///|
fn get_norm_s_dist(value : Double) -> Double {
  0.5 * erfc_double(-value / Double::sqrt(2.0))
}

///|
fn norm_pdf(value : Double, mean : Double, std_dev : Double) -> Double {
  let z = (value - mean) / std_dev
  let denom = Double::sqrt(2.0 * @math.PI) * std_dev
  @math.exp(-0.5 * z * z) / denom
}

///|
fn norm_cdf(value : Double, mean : Double, std_dev : Double) -> Double {
  get_norm_s_dist((value - mean) / std_dev)
}

///|
let norminv_a : Array[Double] = [
  -39.69683028665376, 220.9460984245205, -275.9285104469687, 138.357751867269, -30.66479806614716,
  2.506628277459239,
]

///|
let norminv_b : Array[Double] = [
  -54.47609879822406, 161.5858368580409, -155.6989798598866, 66.80131188771972, -13.28068155288572,
]

///|
let norminv_c : Array[Double] = [
  -0.007784894002430293, -0.3223964580411365, -2.400758277161838, -2.549732539343734,
  4.374664141464968, 2.938163982698783,
]

///|
let norminv_d : Array[Double] = [
  0.007784695709041462, 0.3224671290700398, 2.445134137142996, 3.754408661907416,
]

///|
fn norminv_double(prob : Double) -> Result[Double, FormulaValue] {
  let p_low = 0.02425
  let p_high = 1.0 - p_low
  if prob > 0.0 && prob < p_low {
    let q = Double::sqrt(-2.0 * @math.ln(prob))
    let numerator = (
        (
          ((norminv_c[0] * q + norminv_c[1]) * q + norminv_c[2]) * q +
          norminv_c[3]
        ) *
        q +
        norminv_c[4]
      ) *
      q +
      norminv_c[5]
    let denominator = (
        ((norminv_d[0] * q + norminv_d[1]) * q + norminv_d[2]) * q +
        norminv_d[3]
      ) *
      q +
      1.0
    Ok(numerator / denominator)
  } else if prob >= p_low && prob <= p_high {
    let q = prob - 0.5
    let r = q * q
    let numerator = (
        (
          (
            ((norminv_a[0] * r + norminv_a[1]) * r + norminv_a[2]) * r +
            norminv_a[3]
          ) *
          r +
          norminv_a[4]
        ) *
        r +
        norminv_a[5]
      ) *
      q
    let denominator = (
        (
          ((norminv_b[0] * r + norminv_b[1]) * r + norminv_b[2]) * r +
          norminv_b[3]
        ) *
        r +
        norminv_b[4]
      ) *
      r +
      1.0
    Ok(numerator / denominator)
  } else if prob > p_high && prob < 1.0 {
    let q = Double::sqrt(-2.0 * @math.ln(1.0 - prob))
    let numerator = (
        (
          ((norminv_c[0] * q + norminv_c[1]) * q + norminv_c[2]) * q +
          norminv_c[3]
        ) *
        q +
        norminv_c[4]
      ) *
      q +
      norminv_c[5]
    let denominator = (
        ((norminv_d[0] * q + norminv_d[1]) * q + norminv_d[2]) * q +
        norminv_d[3]
      ) *
      q +
      1.0
    Ok(-numerator / denominator)
  } else {
    Err(Error(formula_error_num))
  }
}

///|
fn get_chidist(x : Double, degrees : Double) -> Double {
  let log_sqrt_pi = @math.ln(Double::sqrt(@math.PI))
  let sqrt_pi = 1.0 / Double::sqrt(@math.PI)
  let mut e = 0.0
  let mut s = 0.0
  let mut z = 0.0
  let mut c = 0.0
  let mut y = 0.0
  let a = x / 2.0
  let mut x1 = x
  let even = Double::to_int(trunc_double(degrees)) % 2 == 0
  if degrees > 1.0 {
    y = @math.exp(-a)
  }
  s = 2.0 * get_norm_s_dist(-Double::sqrt(x1))
  if even {
    s = y
  }
  if degrees > 2.0 {
    x1 = (degrees - 1.0) / 2.0
    z = if even { 1.0 } else { 0.5 }
    if a > 20.0 {
      e = if even { 0.0 } else { log_sqrt_pi }
      c = @math.ln(a)
      while z <= x1 {
        e = @math.ln(z) + e
        s = s + @math.exp(c * z - a - e)
        z = z + 1.0
      }
      return s
    }
    e = if even { 1.0 } else { sqrt_pi / Double::sqrt(a) }
    c = 0.0
    while z <= x1 {
      e = e * (a / z)
      c = c + e
      z = z + 1.0
    }
    return c * y + s
  }
  s
}

///|
fn get_f_dist_cdf(x : Double, deg1 : Double, deg2 : Double) -> Double {
  1.0 - get_beta_dist(deg2 / (deg2 + deg1 * x), deg2 / 2.0, deg1 / 2.0)
}

///|
fn get_f_dist_pdf(x : Double, deg1 : Double, deg2 : Double) -> Double {
  let half_sum = (deg1 + deg2) / 2.0
  let gamma_num = get_gamma(half_sum)
  let gamma_den = get_gamma(deg1 / 2.0) * get_gamma(deg2 / 2.0)
  let scale = @math.pow(deg1 / deg2, deg1 / 2.0)
  let numerator = @math.pow(x, (deg1 - 2.0) / 2.0)
  let denominator = @math.pow(1.0 + deg1 / deg2 * x, half_sum)
  gamma_num / gamma_den * scale * (numerator / denominator)
}

///|
fn get_f_dist_rt(x : Double, deg1 : Double, deg2 : Double) -> Double {
  1.0 - get_beta_dist(deg1 * x / (deg1 * x + deg2), deg1 / 2.0, deg2 / 2.0)
}

///|
fn has_change_of_sign(u : Double, w : Double) -> Bool {
  (u < 0.0 && w > 0.0) || (u > 0.0 && w < 0.0)
}

///|
priv enum InverseKind {
  TDist
  ChiSq
}

///|
priv struct InverseIterator {
  fp : Double
  fdf : Double
  nt : Double
  kind : InverseKind
}

///|
fn InverseIterator::call(self : InverseIterator, x : Double) -> Double {
  match self.kind {
    ChiSq => self.fp - get_chisq_dist_cdf(x, self.fdf)
    TDist => self.fp - get_t_dist(x, self.fdf, self.nt)
  }
}

///|
fn inverse_quadratic_interpolation(
  iterator : InverseIterator,
  ax_in : Double,
  ay_in : Double,
  bx_in : Double,
  by_in : Double,
) -> Double {
  let y_eps = 1.0e-307
  let x_eps = 2.22045e-016
  let mut ax = ax_in
  let mut ay = ay_in
  let mut bx = bx_in
  let mut by = by_in
  let mut px = ax
  let mut py = ay
  let mut qx = bx
  let mut qy = by
  let mut rx = ax
  let mut ry = ay
  let mut sx = 0.5 * (ax + bx)
  let mut has_to_interpolate = true
  let mut count = 0
  while count < 500 &&
        Double::abs(ry) > y_eps &&
        bx - ax >
        (if Double::abs(ax) > Double::abs(bx) {
          Double::abs(ax)
        } else {
          Double::abs(bx)
        }) *
        x_eps {
    if has_to_interpolate {
      if py != qy && qy != ry && ry != py {
        sx = px * ry * qy / (ry - py) / (qy - py) +
          rx * qy * py / (qy - ry) / (py - ry) +
          qx * py * ry / (py - qy) / (ry - qy)
        has_to_interpolate = ax < sx && sx < bx
      } else {
        has_to_interpolate = false
      }
    }
    if !has_to_interpolate {
      sx = 0.5 * (ax + bx)
      qx = bx
      qy = by
      has_to_interpolate = true
    }
    px = qx
    qx = rx
    rx = sx
    py = qy
    qy = ry
    ry = iterator.call(rx)
    if has_change_of_sign(ay, ry) {
      bx = rx
      by = ry
    } else {
      ax = rx
      ay = ry
    }
    has_to_interpolate = has_to_interpolate &&
      Double::abs(ry) * 2.0 <= Double::abs(qy)
    count = count + 1
  }
  rx
}

///|
fn calc_iterate_inverse(
  iterator : InverseIterator,
  ax_in : Double,
  bx_in : Double,
) -> Double {
  let mut ax = ax_in
  let mut bx = bx_in
  let mut ay = iterator.call(ax)
  let mut by = iterator.call(bx)
  let mut count = 0
  while count < 1000 && !has_change_of_sign(ay, by) {
    if Double::abs(ay) <= Double::abs(by) {
      let temp = ax
      ax = ax + 2.0 * (ax - bx)
      if ax < 0.0 {
        ax = 0.0
      }
      bx = temp
      by = ay
      ay = iterator.call(ax)
    } else {
      let temp = bx
      bx = bx + 2.0 * (bx - ax)
      ax = temp
      ay = by
      by = iterator.call(bx)
    }
    count = count + 1
  }
  if ay == 0.0 || by == 0.0 {
    0.0
  } else {
    inverse_quadratic_interpolation(iterator, ax, ay, bx, by)
  }
}

///|
fn erf_double(value : Double) -> Double {
  if value == 0.0 {
    return 0.0
  }
  let mut x = value
  let mut sign = 1.0
  if x < 0.0 {
    sign = -1.0
    x = -x
  }
  let x2 = x * x
  let mut term = x
  let mut sum = term
  let mut n = 1
  let max_iter = 2000
  let threshold = @math.pow(10.0, -18.0)
  while n < max_iter && Double::abs(term) > threshold {
    let n_int = n
    let numerator = -x2 * Double::from_int(2 * n_int - 1)
    let denominator = Double::from_int(n_int * (2 * n_int + 1))
    term = term * numerator / denominator
    sum = sum + term
    n = n + 1
  }
  let scale = 2.0 / Double::sqrt(@math.PI)
  sign * scale * sum
}

///|
fn erfc_double(value : Double) -> Double {
  1.0 - erf_double(value)
}

///|
fn fisher_value(value : FormulaValue) -> FormulaValue {
  let num = match value_as_number(value) {
    Ok(num) => num
    Err(err) => return err
  }
  if num <= -1.0 || num >= 1.0 {
    return Error(formula_error_na)
  }
  let result = 0.5 * @math.ln((1.0 + num) / (1.0 - num))
  number_or_num_error(round_significant_digits(result, 15))
}

///|
fn fisherinv_value(value : FormulaValue) -> FormulaValue {
  let num = match value_as_number(value) {
    Ok(num) => num
    Err(err) => return err
  }
  let exp_val = @math.exp(2.0 * num)
  let result = (exp_val - 1.0) / (exp_val + 1.0)
  number_or_num_error(round_significant_digits(result, 15))
}

///|
fn bessel_bassel(x : Double, n : Double, modified : Bool) -> Double {
  let mut x1 = x * 0.5
  let x2 = x1 * x1
  x1 = @math.pow(x1, n)
  let mut n1 = factorial_double(n)
  let mut n2 = 1.0
  let mut n3 = 0.0
  let mut n4 = n
  let mut add = false
  let mut result = x1 / n1
  let mut prev = result * 0.9
  let mut iter = 100
  while result != prev && iter != 0 {
    x1 = x1 * x2
    n3 = n3 + 1.0
    n1 = n1 * n3
    n4 = n4 + 1.0
    n2 = n2 * n4
    prev = result
    let term = x1 / n1 / n2
    if modified || add {
      result = result + term
    } else {
      result = result - term
    }
    iter = iter - 1
    add = !add
  }
  result
}

///|
fn bessel_i(x : Double, n : Double) -> Double {
  bessel_bassel(x, n, true)
}

///|
fn bessel_j(x : Double, n : Double) -> Double {
  bessel_bassel(x, n, false)
}

///|
fn bessel_k0(x : Double) -> Double {
  if x <= 2.0 {
    let n2 = x * 0.5
    let y = n2 * n2
    -@math.ln(n2) * bessel_i(x, 0.0) +
    (
      -0.57721566 +
      y *
      (
        0.42278420 +
        y *
        (
          0.23069756 +
          y * (0.0348859 + y * (0.00262698 + y * (0.0001075 + y * 0.0000074)))
        )
      )
    )
  } else {
    let y = 2.0 / x
    @math.exp(-x) /
    Double::sqrt(x) *
    (
      1.25331414 +
      y *
      (
        -0.07832358 +
        y *
        (
          0.02189568 +
          y *
          (-0.01062446 + y * (0.00587872 + y * (-0.0025154 + y * 0.00053208)))
        )
      )
    )
  }
}

///|
fn bessel_k1(x : Double) -> Double {
  if x <= 2.0 {
    let n2 = x * 0.5
    let y = n2 * n2
    @math.ln(n2) * bessel_i(x, 1.0) +
    (
      1.0 +
      y *
      (
        0.15443144 +
        y *
        (
          -0.67278579 +
          y *
          (
            -0.18156897 +
            y * (-0.01919402 + y * (-0.00110404 + y * -0.00004686))
          )
        )
      )
    ) /
    x
  } else {
    let y = 2.0 / x
    @math.exp(-x) /
    Double::sqrt(x) *
    (
      1.25331414 +
      y *
      (
        0.23498619 +
        y *
        (
          -0.0365562 +
          y *
          (0.01504268 + y * (-0.00780353 + y * (0.00325614 + y * -0.00068245)))
        )
      )
    )
  }
}

///|
fn bessel_k2(x : Double, n : Double) -> Double {
  let tox = 2.0 / x
  let mut bkm = bessel_k0(x)
  let mut bk = bessel_k1(x)
  let mut bkp = 0.0
  let mut i = 1.0
  while i < n {
    bkp = bkm + i * tox * bk
    bkm = bk
    bk = bkp
    i = i + 1.0
  }
  bk
}

///|
fn bessel_y0(x : Double) -> Double {
  if x < 8.0 {
    let y = x * x
    let f1 = -2957821389.0 +
      y *
      (
        7062834065.0 +
        y *
        (
          -512359803.6 +
          y * (10879881.29 + y * (-86327.92757 + y * 228.4622733))
        )
      )
    let f2 = 40076544269.0 +
      y *
      (
        745249964.8 +
        y * (7189466.438 + y * (47447.26470 + y * (226.1030244 + y)))
      )
    f1 / f2 + 0.636619772 * bessel_j(x, 0.0) * @math.ln(x)
  } else {
    let z = 8.0 / x
    let y = z * z
    let xx = x - 0.785398164
    let f1 = 1.0 +
      y *
      (
        -0.001098628627 +
        y *
        (0.00002734510407 + y * (-0.000002073370639 + y * 0.0000002093887211))
      )
    let f2 = -0.01562499995 +
      y *
      (
        0.0001430488765 +
        y *
        (
          -0.000006911147651 +
          y * (0.0000007621095161 + y * -0.0000000934945152)
        )
      )
    Double::sqrt(0.636619772 / x) *
    (@math.sin(xx) * f1 + z * @math.cos(xx) * f2)
  }
}

///|
fn bessel_y1(x : Double) -> Double {
  if x < 8.0 {
    let y = x * x
    let f1 = x *
      (
        -4900604943000.0 +
        y *
        (
          1275274390000.0 +
          y *
          (
            -51534381390.0 +
            y * (734926455.1 + y * (-4237922.726 + y * 8511.937935))
          )
        )
      )
    let f2 = 24995805700000.0 +
      y *
      (
        424441966400.0 +
        y *
        (
          3733650367.0 +
          y * (22459040.02 + y * (102042.605 + y * (354.9632885 + y)))
        )
      )
    f1 / f2 + 0.636619772 * (bessel_j(x, 1.0) * @math.ln(x) - 1.0 / x)
  } else {
    Double::sqrt(0.636619772 / x) * @math.sin(x - 2.356194491)
  }
}

///|
fn bessel_y2(x : Double, n : Double) -> Double {
  let tox = 2.0 / x
  let mut bym = bessel_y0(x)
  let mut by = bessel_y1(x)
  let mut byp = 0.0
  let mut i = 1.0
  while i < n {
    byp = i * tox * by - bym
    bym = by
    by = byp
    i = i + 1.0
  }
  by
}

///|
fn round_with_digits(value : Double, digits : Int) -> Double {
  if digits >= 0 {
    let scale = Double::from_int(pow10_int(digits))
    round_half_away_from_zero(value * scale) / scale
  } else {
    let scale = Double::from_int(pow10_int(-digits))
    round_half_away_from_zero(value / scale) * scale
  }
}

///|
fn round_down_with_digits(value : Double, digits : Int) -> Double {
  if digits >= 0 {
    let scale = Double::from_int(pow10_int(digits))
    trunc_double(value * scale) / scale
  } else {
    let scale = Double::from_int(pow10_int(-digits))
    trunc_double(value / scale) * scale
  }
}

///|
fn round_up_with_digits(value : Double, digits : Int) -> Double {
  if digits >= 0 {
    let scale = Double::from_int(pow10_int(digits))
    let scaled = value * scale
    let truncated = trunc_double(scaled)
    let adjusted = if scaled == truncated {
      truncated
    } else if scaled > 0.0 {
      truncated + 1.0
    } else {
      truncated - 1.0
    }
    adjusted / scale
  } else {
    let scale = Double::from_int(pow10_int(-digits))
    let scaled = value / scale
    let truncated = trunc_double(scaled)
    let adjusted = if scaled == truncated {
      truncated
    } else if scaled > 0.0 {
      truncated + 1.0
    } else {
      truncated - 1.0
    }
    adjusted * scale
  }
}

///|
fn trim_excel_text(text : StringView) -> String {
  let sb = StringBuilder::new()
  let mut seen_text = false
  let mut pending_space = false
  for ch in text {
    if ch.is_ascii_whitespace() {
      if seen_text {
        pending_space = true
      }
    } else {
      if pending_space {
        sb.write_char(' ')
        pending_space = false
      }
      sb.write_char(ch)
      seen_text = true
    }
  }
  sb.to_string()
}

///|
fn eval_expr(
  workbook : Workbook,
  sheet_name : String,
  expr : Expr,
  ctx : CalcContext,
) -> FormulaValue raise XlsxError {
  match expr {
    Number(num) => Number(num)
    String(text) => String(text)
    Bool(value) => Bool(value)
    Cell(sheet, reference) =>
      resolve_cell_value(
        workbook,
        if sheet == "" {
          sheet_name
        } else {
          sheet
        },
        reference,
        ctx,
      )
    Range(sheet, start_ref, end_ref) =>
      List(
        collect_range_values(
          workbook,
          if sheet == "" {
            sheet_name
          } else {
            sheet
          },
          start_ref,
          end_ref,
          ctx,
        ),
      )
    Unary(op, inner) =>
      eval_unary(op, eval_expr(workbook, sheet_name, inner, ctx))
    Binary(op, left, right) =>
      eval_binary(
        op,
        eval_expr(workbook, sheet_name, left, ctx),
        eval_expr(workbook, sheet_name, right, ctx),
      )
    FuncCall(name, args) => eval_function(workbook, sheet_name, name, args, ctx)
    List(items) => {
      let out : Array[FormulaValue] = []
      for item in items {
        out.push(eval_expr(workbook, sheet_name, item, ctx))
      }
      List(out)
    }
  }
}

///|
fn eval_unary(op : UnaryOp, value : FormulaValue) -> FormulaValue {
  match op {
    Plus => value
    Minus =>
      match value_as_number(value) {
        Ok(num) => Number(-num)
        Err(err) => err
      }
    Percent =>
      match value_as_number(value) {
        Ok(num) => Number(num / 100.0)
        Err(err) => err
      }
  }
}

///|
fn eval_binary(
  op : BinaryOp,
  left : FormulaValue,
  right : FormulaValue,
) -> FormulaValue {
  match op {
    Concat => String(formula_value_string(left) + formula_value_string(right))
    Eq | Ne | Lt | Le | Gt | Ge =>
      match compare_values(left, right) {
        Ok(result) => {
          let ok = match op {
            Eq => result == 0
            Ne => result != 0
            Lt => result < 0
            Le => result <= 0
            Gt => result > 0
            Ge => result >= 0
            _ => false
          }
          Bool(ok)
        }
        Err(err) => err
      }
    _ =>
      match (left, right) {
        (List(_), _) | (_, List(_)) => eval_list_binary(op, left, right)
        _ => eval_numeric_binary(op, left, right)
      }
  }
}
