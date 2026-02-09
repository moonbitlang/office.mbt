///|
fn eval_function(
  workbook : Workbook,
  sheet_name : String,
  name : String,
  args : ArrayView[Expr],
  ctx : CalcContext,
) -> FormulaValue raise XlsxError {
  if name == "ROW" {
    return if args.length() == 0 {
      match current_cell_rc(ctx) {
        Some((row, _col)) => Number(Double::from_int(row))
        None => Error(formula_error_value)
      }
    } else if args.length() == 1 {
      match ref_bounds_opt(args[0]) {
        Some((row1, _col1, row2, _col2)) => {
          let row = if row1 < row2 { row1 } else { row2 }
          Number(Double::from_int(row))
        }
        None => Error(formula_error_value)
      }
    } else {
      Error(formula_error_value)
    }
  }
  if name == "COLUMN" {
    return if args.length() == 0 {
      match current_cell_rc(ctx) {
        Some((_row, col)) => Number(Double::from_int(col))
        None => Error(formula_error_value)
      }
    } else if args.length() == 1 {
      match ref_bounds_opt(args[0]) {
        Some((_row1, col1, _row2, col2)) => {
          let col = if col1 < col2 { col1 } else { col2 }
          Number(Double::from_int(col))
        }
        None => Error(formula_error_value)
      }
    } else {
      Error(formula_error_value)
    }
  }
  if name == "ROWS" {
    return if args.length() == 1 {
      match ref_bounds_opt(args[0]) {
        Some((row1, _col1, row2, _col2)) => {
          let min_row = if row1 < row2 { row1 } else { row2 }
          let max_row = if row1 > row2 { row1 } else { row2 }
          Number(Double::from_int(max_row - min_row + 1))
        }
        None => Error(formula_error_value)
      }
    } else {
      Error(formula_error_value)
    }
  }
  if name == "COLUMNS" {
    return if args.length() == 1 {
      match ref_bounds_opt(args[0]) {
        Some((_row1, col1, _row2, col2)) => {
          let min_col = if col1 < col2 { col1 } else { col2 }
          let max_col = if col1 > col2 { col1 } else { col2 }
          Number(Double::from_int(max_col - min_col + 1))
        }
        None => Error(formula_error_value)
      }
    } else {
      Error(formula_error_value)
    }
  }
  if name == "FORMULATEXT" {
    return if args.length() == 1 {
      formula_text_value(workbook, sheet_name, args[0])
    } else {
      Error(formula_error_value)
    }
  }
  let values : Array[FormulaValue] = []
  for arg in args {
    values.push(eval_expr(workbook, sheet_name, arg, ctx))
  }
  match name {
    "TRUE" => Bool(true)
    "FALSE" => Bool(false)
    "SUM" => sum_values(values)
    "SUBTOTAL" => subtotal_values(values)
    "AGGREGATE" => aggregate_values(values)
    "PRODUCT" => product_values(values)
    "AVERAGE" => average_values(values)
    "AVERAGEA" => averagea_values(values)
    "STDEV" | "STDEV.S" =>
      if values.length() >= 1 {
        stdev_values(false, values)
      } else {
        Error(formula_error_value)
      }
    "STDEVA" =>
      if values.length() >= 1 {
        stdev_values(true, values)
      } else {
        Error(formula_error_value)
      }
    "STDEVP" | "STDEV.P" =>
      if values.length() >= 1 {
        match variance_values(values, false, false) {
          Number(variance) => {
            let result = @math.pow(variance, 0.5)
            Number(round_significant_digits(result, 15))
          }
          value => value
        }
      } else {
        Error(formula_error_value)
      }
    "STDEVPA" =>
      if values.length() >= 1 {
        match variance_values(values, false, true) {
          Number(variance) => {
            let result = @math.pow(variance, 0.5)
            Number(round_significant_digits(result, 15))
          }
          value => value
        }
      } else {
        Error(formula_error_value)
      }
    "VAR" | "VAR.S" =>
      if values.length() >= 1 {
        variance_values(values, true, false)
      } else {
        Error(formula_error_value)
      }
    "VARA" =>
      if values.length() >= 1 {
        variance_values(values, true, true)
      } else {
        Error(formula_error_value)
      }
    "VARP" | "VAR.P" =>
      if values.length() >= 1 {
        variance_values(values, false, false)
      } else {
        Error(formula_error_value)
      }
    "VARPA" =>
      if values.length() >= 1 {
        variance_values(values, false, true)
      } else {
        Error(formula_error_value)
      }
    "TRIMMEAN" => trimmean_values(values)
    "AVEDEV" =>
      if values.length() >= 1 {
        avedev_values(values)
      } else {
        Error(formula_error_value)
      }
    "DEVSQ" =>
      if values.length() >= 1 {
        devsq_values(values)
      } else {
        Error(formula_error_value)
      }
    "GEOMEAN" =>
      if values.length() >= 1 {
        geomean_values(values)
      } else {
        Error(formula_error_value)
      }
    "HARMEAN" =>
      if values.length() >= 1 {
        harmean_values(values)
      } else {
        Error(formula_error_value)
      }
    "KURT" =>
      if values.length() >= 1 {
        kurt_values(values)
      } else {
        Error(formula_error_value)
      }
    "SKEW" =>
      if values.length() >= 1 {
        skew_values("SKEW", values)
      } else {
        Error(formula_error_value)
      }
    "SKEW.P" =>
      if values.length() >= 1 {
        skew_values("SKEW.P", values)
      } else {
        Error(formula_error_value)
      }
    "STANDARDIZE" =>
      if values.length() == 3 {
        standardize_values(values)
      } else {
        Error(formula_error_value)
      }
    "LARGE" =>
      if values.length() == 2 {
        kth_values("LARGE", values[0], values[1])
      } else {
        Error(formula_error_value)
      }
    "SMALL" =>
      if values.length() == 2 {
        kth_values("SMALL", values[0], values[1])
      } else {
        Error(formula_error_value)
      }
    "MODE" =>
      if values.length() >= 1 {
        mode_values(values)
      } else {
        Error(formula_error_value)
      }
    "MODE.SNGL" =>
      if values.length() >= 1 {
        mode_values(values)
      } else {
        Error(formula_error_value)
      }
    "MODE.MULT" =>
      if values.length() >= 1 {
        mode_mult_values(values)
      } else {
        Error(formula_error_value)
      }
    "PERCENTILE" =>
      if values.length() == 2 {
        match value_as_number(values[1]) {
          Ok(k) =>
            if k < 0.0 || k > 1.0 {
              Error(formula_error_na)
            } else {
              percentile_values(values[0], k, false, false)
            }
          Err(err) => err
        }
      } else {
        Error(formula_error_value)
      }
    "PERCENTILE.INC" =>
      if values.length() == 2 {
        match value_as_number(values[1]) {
          Ok(k) =>
            if k < 0.0 || k > 1.0 {
              Error(formula_error_na)
            } else {
              percentile_values(values[0], k, false, false)
            }
          Err(err) => err
        }
      } else {
        Error(formula_error_value)
      }
    "PERCENTILE.EXC" =>
      if values.length() == 2 {
        match value_as_number(values[1]) {
          Ok(k) =>
            if k <= 0.0 || k >= 1.0 {
              Error(formula_error_num)
            } else {
              percentile_values(values[0], k, true, true)
            }
          Err(err) => err
        }
      } else {
        Error(formula_error_value)
      }
    "PERCENTRANK" =>
      if values.length() == 2 || values.length() == 3 {
        match value_as_number(values[1]) {
          Ok(x) => {
            let significance = if values.length() == 3 {
              match value_as_number(values[2]) {
                Ok(num) => num
                Err(err) => return err
              }
            } else {
              3.0
            }
            percentrank_values("PERCENTRANK", values[0], x, significance)
          }
          Err(err) => err
        }
      } else {
        Error(formula_error_value)
      }
    "PERCENTRANK.INC" =>
      if values.length() == 2 || values.length() == 3 {
        match value_as_number(values[1]) {
          Ok(x) => {
            let significance = if values.length() == 3 {
              match value_as_number(values[2]) {
                Ok(num) => num
                Err(err) => return err
              }
            } else {
              3.0
            }
            percentrank_values("PERCENTRANK.INC", values[0], x, significance)
          }
          Err(err) => err
        }
      } else {
        Error(formula_error_value)
      }
    "PERCENTRANK.EXC" =>
      if values.length() == 2 || values.length() == 3 {
        match value_as_number(values[1]) {
          Ok(x) => {
            let significance = if values.length() == 3 {
              match value_as_number(values[2]) {
                Ok(num) => num
                Err(err) => return err
              }
            } else {
              3.0
            }
            percentrank_values("PERCENTRANK.EXC", values[0], x, significance)
          }
          Err(err) => err
        }
      } else {
        Error(formula_error_value)
      }
    "QUARTILE" =>
      if values.length() == 2 {
        match value_as_number(values[1]) {
          Ok(quart) => quartile_values("QUARTILE", values[0], quart, false)
          Err(err) => err
        }
      } else {
        Error(formula_error_value)
      }
    "QUARTILE.INC" =>
      if values.length() == 2 {
        match value_as_number(values[1]) {
          Ok(quart) => quartile_values("QUARTILE.INC", values[0], quart, false)
          Err(err) => err
        }
      } else {
        Error(formula_error_value)
      }
    "QUARTILE.EXC" =>
      if values.length() == 2 {
        match value_as_number(values[1]) {
          Ok(quart) => quartile_values("QUARTILE.EXC", values[0], quart, true)
          Err(err) => err
        }
      } else {
        Error(formula_error_value)
      }
    "RANK" | "RANK.EQ" =>
      if values.length() == 2 || values.length() == 3 {
        let order = if values.length() == 3 {
          match value_as_number(values[2]) {
            Ok(num) => Some(num)
            Err(err) => return err
          }
        } else {
          None
        }
        rank_values(values[0], values[1], order)
      } else {
        Error(formula_error_value)
      }
    "SIGN" =>
      if values.length() == 1 {
        match value_as_number(values[0]) {
          Ok(num) =>
            Number(if num < 0.0 { -1.0 } else if num > 0.0 { 1.0 } else { 0.0 })
          Err(err) => err
        }
      } else {
        Error(formula_error_value)
      }
    "SERIESSUM" =>
      if values.length() == 4 {
        let x = match value_as_number(values[0]) {
          Ok(num) => num
          Err(err) => return err
        }
        let n = match value_as_number(values[1]) {
          Ok(num) => num
          Err(err) => return err
        }
        let m = match value_as_number(values[2]) {
          Ok(num) => num
          Err(err) => return err
        }
        let coefficients = list_from_value(values[3])
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
      } else {
        Error(formula_error_value)
      }
    "CORREL" =>
      if values.length() == 2 {
        correl_values(values[0], values[1])
      } else {
        Error(formula_error_value)
      }
    "COVAR" =>
      if values.length() == 2 {
        covar_values("COVAR", values[0], values[1])
      } else {
        Error(formula_error_value)
      }
    "COVARIANCE.P" =>
      if values.length() == 2 {
        covar_values("COVARIANCE.P", values[0], values[1])
      } else {
        Error(formula_error_value)
      }
    "COVARIANCE.S" =>
      if values.length() == 2 {
        covar_values("COVARIANCE.S", values[0], values[1])
      } else {
        Error(formula_error_value)
      }
    "PEARSON" =>
      if values.length() == 2 {
        pearson_product_values("PEARSON", values)
      } else {
        Error(formula_error_value)
      }
    "RSQ" =>
      if values.length() == 2 {
        pearson_product_values("RSQ", values)
      } else {
        Error(formula_error_value)
      }
    "SLOPE" =>
      if values.length() == 2 {
        pearson_product_values("SLOPE", values)
      } else {
        Error(formula_error_value)
      }
    "INTERCEPT" =>
      if values.length() == 2 {
        pearson_product_values("INTERCEPT", values)
      } else {
        Error(formula_error_value)
      }
    "FORECAST" =>
      if values.length() == 3 {
        pearson_product_values("FORECAST", values)
      } else {
        Error(formula_error_value)
      }
    "FORECAST.LINEAR" =>
      if values.length() == 3 {
        pearson_product_values("FORECAST.LINEAR", values)
      } else {
        Error(formula_error_value)
      }
    "GROWTH" =>
      trend_growth_values(workbook, sheet_name, "GROWTH", args, values, ctx)
    "TREND" =>
      trend_growth_values(workbook, sheet_name, "TREND", args, values, ctx)
    "FISHER" =>
      if values.length() == 1 {
        fisher_value(values[0])
      } else {
        Error(formula_error_value)
      }
    "FISHERINV" =>
      if values.length() == 1 {
        fisherinv_value(values[0])
      } else {
        Error(formula_error_value)
      }
    "STEYX" =>
      if values.length() == 2 {
        steyx_values(values)
      } else {
        Error(formula_error_value)
      }
    "MEDIAN" => median_values(values)
    "MIN" => min_values(values)
    "MAX" => max_values(values)
    "MINA" => mina_values(values)
    "MAXA" => maxa_values(values)
    "COUNT" => count_values(values)
    "COUNTA" => counta_values(values)
    "COUNTBLANK" =>
      if args.length() == 1 {
        let range_values = eval_range_expr(workbook, sheet_name, args[0], ctx)
        countblank_values(range_values)
      } else {
        Error(formula_error_value)
      }
    "FREQUENCY" => frequency_values(workbook, sheet_name, args, values, ctx)
    "COUNTIF" =>
      if args.length() == 2 {
        let range_values = eval_range_expr(workbook, sheet_name, args[0], ctx)
        countif_values(range_values, values[1])
      } else {
        Error(formula_error_value)
      }
    "COUNTIFS" =>
      if args.length() >= 2 {
        if args.length() % 2 != 0 {
          Error(formula_error_na)
        } else {
          let ranges : Array[RangeValues] = []
          let criterias : Array[FormulaCriteria] = []
          for i in 0..<(args.length() / 2) {
            let range_values = eval_range_expr(
              workbook,
              sheet_name,
              args[i * 2],
              ctx,
            )
            ranges.push(range_values)
            criterias.push(parse_formula_criteria(values[i * 2 + 1]))
          }
          let matches = ifs_match(ranges, criterias)
          Number(Double::from_int(matches.length()))
        }
      } else {
        Error(formula_error_value)
      }
    "DAVERAGE"
    | "DMAX"
    | "DMIN"
    | "DPRODUCT"
    | "DSTDEV"
    | "DSTDEVP"
    | "DSUM"
    | "DVAR"
    | "DVARP" =>
      if args.length() == 3 {
        let database = eval_range_expr(workbook, sheet_name, args[0], ctx)
        let criteria = eval_range_expr(workbook, sheet_name, args[2], ctx)
        database_values(name, database, values[1], criteria)
      } else {
        Error(formula_error_value)
      }
    "DCOUNT" | "DCOUNTA" =>
      if args.length() >= 2 && args.length() <= 3 {
        let database = eval_range_expr(workbook, sheet_name, args[0], ctx)
        let field = if args.length() == 3 {
          match args[1] {
            FuncCall(name, _) if name == "" => Empty
            _ => values[1]
          }
        } else {
          Empty
        }
        let criteria_idx = if args.length() == 3 { 2 } else { 1 }
        let criteria = eval_range_expr(
          workbook,
          sheet_name,
          args[criteria_idx],
          ctx,
        )
        dcount_values(name, database, field, criteria)
      } else {
        Error(formula_error_value)
      }
    "DGET" =>
      if args.length() == 3 {
        let database = eval_range_expr(workbook, sheet_name, args[0], ctx)
        let criteria = eval_range_expr(workbook, sheet_name, args[2], ctx)
        dget_values(database, values[1], criteria)
      } else {
        Error(formula_error_value)
      }
    "SUMIF" =>
      if args.length() == 2 || args.length() == 3 {
        let range_values = eval_range_expr(workbook, sheet_name, args[0], ctx)
        let sum_range = if args.length() == 3 {
          Some(eval_range_expr(workbook, sheet_name, args[2], ctx))
        } else {
          None
        }
        sumif_values(range_values, values[1], sum_range)
      } else {
        Error(formula_error_value)
      }
    "SUMPRODUCT" =>
      if args.length() >= 1 {
        let ranges : Array[RangeValues] = []
        let scalars : Array[FormulaValue] = []
        let mut has_range = false
        let mut has_scalar = false
        for i in 0..<args.length() {
          match args[i] {
            Range(_, _, _) | Cell(_, _) => {
              has_range = true
              ranges.push(eval_range_expr(workbook, sheet_name, args[i], ctx))
            }
            _ =>
              match values[i] {
                Error(err) => return Error(err)
                _ => {
                  has_scalar = true
                  scalars.push(values[i])
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
    "SUMSQ" => sumsq_values(values)
    "SUMX2MY2" =>
      if args.length() == 2 {
        let left = eval_range_expr(workbook, sheet_name, args[0], ctx)
        let right = eval_range_expr(workbook, sheet_name, args[1], ctx)
        sumx_values("SUMX2MY2", left, right)
      } else {
        Error(formula_error_value)
      }
    "SUMX2PY2" =>
      if args.length() == 2 {
        let left = eval_range_expr(workbook, sheet_name, args[0], ctx)
        let right = eval_range_expr(workbook, sheet_name, args[1], ctx)
        sumx_values("SUMX2PY2", left, right)
      } else {
        Error(formula_error_value)
      }
    "SUMXMY2" =>
      if args.length() == 2 {
        let left = eval_range_expr(workbook, sheet_name, args[0], ctx)
        let right = eval_range_expr(workbook, sheet_name, args[1], ctx)
        sumx_values("SUMXMY2", left, right)
      } else {
        Error(formula_error_value)
      }
    "SUMIFS" =>
      if args.length() >= 3 {
        if args.length() % 2 != 1 {
          Error(formula_error_na)
        } else {
          let sum_range = eval_range_expr(workbook, sheet_name, args[0], ctx)
          let ranges : Array[RangeValues] = []
          let criterias : Array[FormulaCriteria] = []
          for i in 0..<((args.length() - 1) / 2) {
            let offset = 1 + i * 2
            let range_values = eval_range_expr(
              workbook,
              sheet_name,
              args[offset],
              ctx,
            )
            ranges.push(range_values)
            criterias.push(parse_formula_criteria(values[offset + 1]))
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
    "AVERAGEIF" =>
      if args.length() == 2 || args.length() == 3 {
        let range_values = eval_range_expr(workbook, sheet_name, args[0], ctx)
        let average_range = if args.length() == 3 {
          Some(eval_range_expr(workbook, sheet_name, args[2], ctx))
        } else {
          None
        }
        averageif_values(range_values, values[1], average_range)
      } else {
        Error(formula_error_value)
      }
    "AVERAGEIFS" =>
      if args.length() >= 3 {
        if args.length() % 2 != 1 {
          Error(formula_error_na)
        } else {
          let average_range = eval_range_expr(
            workbook,
            sheet_name,
            args[0],
            ctx,
          )
          let ranges : Array[RangeValues] = []
          let criterias : Array[FormulaCriteria] = []
          for i in 0..<((args.length() - 1) / 2) {
            let offset = 1 + i * 2
            let range_values = eval_range_expr(
              workbook,
              sheet_name,
              args[offset],
              ctx,
            )
            ranges.push(range_values)
            criterias.push(parse_formula_criteria(values[offset + 1]))
          }
          let matches = ifs_match(ranges, criterias)
          let mut sum = 0.0
          let mut count = 0
          for cell in matches {
            match average_range.get(cell.row, cell.col) {
              Some(value) =>
                match value_as_number_opt(value) {
                  Some(num) => {
                    sum = sum + num
                    count = count + 1
                  }
                  None => ()
                }
              None => return Error(formula_error_value)
            }
          }
          if count == 0 {
            Error(formula_error_div)
          } else {
            Number(sum / Double::from_int(count))
          }
        }
      } else {
        Error(formula_error_value)
      }
    "MAXIFS" =>
      if args.length() >= 3 {
        if args.length() % 2 != 1 {
          Error(formula_error_na)
        } else {
          let max_range = eval_range_expr(workbook, sheet_name, args[0], ctx)
          let ranges : Array[RangeValues] = []
          let criterias : Array[FormulaCriteria] = []
          for i in 0..<((args.length() - 1) / 2) {
            let offset = 1 + i * 2
            let range_values = eval_range_expr(
              workbook,
              sheet_name,
              args[offset],
              ctx,
            )
            ranges.push(range_values)
            criterias.push(parse_formula_criteria(values[offset + 1]))
          }
          let matches = ifs_match(ranges, criterias)
          maxifs_values(max_range, matches)
        }
      } else {
        Error(formula_error_value)
      }
    "MINIFS" =>
      if args.length() >= 3 {
        if args.length() % 2 != 1 {
          Error(formula_error_na)
        } else {
          let min_range = eval_range_expr(workbook, sheet_name, args[0], ctx)
          let ranges : Array[RangeValues] = []
          let criterias : Array[FormulaCriteria] = []
          for i in 0..<((args.length() - 1) / 2) {
            let offset = 1 + i * 2
            let range_values = eval_range_expr(
              workbook,
              sheet_name,
              args[offset],
              ctx,
            )
            ranges.push(range_values)
            criterias.push(parse_formula_criteria(values[offset + 1]))
          }
          let matches = ifs_match(ranges, criterias)
          minifs_values(min_range, matches)
        }
      } else {
        Error(formula_error_value)
      }
    "GCD" => gcd_values(values)
    "LCM" => lcm_values(values)
    "COMBIN" =>
      if values.length() == 2 {
        match (value_as_number(values[0]), value_as_number(values[1])) {
          (Ok(num), Ok(chosen)) => combin_values(num, chosen)
          (Err(err), _) => err
          (_, Err(err)) => err
        }
      } else {
        Error(formula_error_value)
      }
    "COMBINA" | "_XLFN.COMBINA" =>
      if values.length() == 2 {
        match (value_as_number(values[0]), value_as_number(values[1])) {
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
      } else {
        Error(formula_error_value)
      }
    "COMPLEX" =>
      if values.length() < 2 {
        Error(formula_error_value)
      } else if values.length() > 3 {
        Error(formula_error_value)
      } else {
        match (value_as_number(values[0]), value_as_number(values[1])) {
          (Ok(real), Ok(imag)) => {
            let mut suffix = "i"
            if values.length() == 3 {
              match value_as_string(values[2]) {
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
      }
    "FACT" =>
      if values.length() == 1 {
        match value_as_number(values[0]) {
          Ok(num) =>
            if num < 0.0 {
              Error(formula_error_num)
            } else {
              Number(factorial_double(num))
            }
          Err(err) => err
        }
      } else {
        Error(formula_error_value)
      }
    "FACTDOUBLE" =>
      if values.length() == 1 {
        match value_as_number(values[0]) {
          Ok(num) =>
            if num < 0.0 {
              Error(formula_error_num)
            } else {
              Number(double_factorial_double(num))
            }
          Err(err) => err
        }
      } else {
        Error(formula_error_value)
      }
    "MULTINOMIAL" => multinomial_values(values)
    "MDETERM" =>
      if values.length() == 1 {
        let range = range_from_expr_or_value(
          workbook,
          sheet_name,
          args[0],
          values[0],
          ctx,
        )
        match number_matrix_from_range(range, true) {
          Ok(matrix) => Number(matrix_det(matrix))
          Err(err) => err
        }
      } else {
        Error(formula_error_value)
      }
    "MINVERSE" =>
      if values.length() == 1 {
        let range = range_from_expr_or_value(
          workbook,
          sheet_name,
          args[0],
          values[0],
          ctx,
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
      } else {
        Error(formula_error_value)
      }
    "MMULT" =>
      if values.length() == 2 {
        match (values[0], values[1]) {
          (Number(lhs), Number(rhs)) => Number(lhs * rhs)
          _ => {
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
      } else {
        Error(formula_error_value)
      }
    "MUNIT" | "_XLFN.MUNIT" =>
      if values.length() == 1 {
        match munit_dimension(values[0]) {
          Ok(dimension) => List(munit_range_values(dimension).values)
          Err(err) => err
        }
      } else {
        Error(formula_error_value)
      }
    "TRANSPOSE" =>
      if args.length() == 1 {
        let base_range = range_from_expr_or_value(
          workbook,
          sheet_name,
          args[0],
          values[0],
          ctx,
        )
        List(transpose_range_values(base_range).values)
      } else {
        Error(formula_error_value)
      }
    "PERMUT" =>
      if values.length() == 2 {
        match (value_as_number(values[0]), value_as_number(values[1])) {
          (Ok(num), Ok(chosen)) =>
            if num < chosen {
              Error(formula_error_na)
            } else {
              let result = factorial_double(num) /
                factorial_double(num - chosen)
              Number(round_half_away_from_zero(result))
            }
          (Err(err), _) => err
          (_, Err(err)) => err
        }
      } else {
        Error(formula_error_value)
      }
    "PERMUTATIONA" =>
      if values.length() == 2 {
        match (value_as_number(values[0]), value_as_number(values[1])) {
          (Ok(num), Ok(chosen)) => {
            let number = Double::floor(num)
            let number_chosen = Double::floor(chosen)
            if number < 0.0 || number_chosen < 0.0 {
              Error(formula_error_na)
            } else {
              Number(@math.pow(number, number_chosen))
            }
          }
          (Err(err), _) => err
          (_, Err(err)) => err
        }
      } else {
        Error(formula_error_value)
      }
    "ABS" =>
      if values.length() == 1 {
        match value_as_number(values[0]) {
          Ok(num) => Number(abs_double(num))
          Err(err) => err
        }
      } else {
        Error(formula_error_value)
      }
    "INT" =>
      if values.length() == 1 {
        match value_as_number(values[0]) {
          Ok(num) => Number(Double::floor(num))
          Err(err) => err
        }
      } else {
        Error(formula_error_value)
      }
    "LN" =>
      if values.length() == 1 {
        match value_as_number(values[0]) {
          Ok(num) => Number(@math.ln(num))
          Err(err) => err
        }
      } else {
        Error(formula_error_value)
      }
    "EXP" =>
      if values.length() == 1 {
        match value_as_number(values[0]) {
          Ok(num) => Number(@math.exp(num))
          Err(err) => err
        }
      } else {
        Error(formula_error_value)
      }
    "DECIMAL" | "_XLFN.DECIMAL" =>
      if values.length() == 2 {
        match (value_as_string(values[0]), value_as_number(values[1])) {
          (Ok(text), Ok(radix)) => {
            let base = Double::to_int(trunc_double(radix))
            let text_value = strip_hex_prefix(text)
            let parsed = @strconv.parse_int(text_value, base~) catch {
              _ => return Error(formula_error_value)
            }
            Number(Double::from_int(parsed))
          }
          (Err(err), _) => err
          (_, Err(err)) => err
        }
      } else {
        Error(formula_error_value)
      }
    "ROMAN" =>
      if values.length() == 0 {
        Error(formula_error_value)
      } else if values.length() > 2 {
        Error(formula_error_value)
      } else {
        match value_as_number(values[0]) {
          Ok(num) => {
            let mut form = 0
            if values.length() == 2 {
              match value_as_number(values[1]) {
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
      }
    "ARABIC" | "_XLFN.ARABIC" =>
      if values.length() == 1 {
        match value_as_string(values[0]) {
          Ok(text) => arabic_string_value(text)
          Err(err) => err
        }
      } else {
        Error(formula_error_value)
      }
    "BASE" => base_values(values)
    "BIN2DEC" =>
      if values.length() == 1 {
        match value_as_number(values[0]) {
          Ok(_) => bin2dec_string(formula_value_string(values[0]))
          Err(err) => err
        }
      } else {
        Error(formula_error_value)
      }
    "BIN2HEX" =>
      if values.length() < 1 {
        Error(formula_error_value)
      } else if values.length() > 2 {
        Error(formula_error_value)
      } else {
        match value_as_number(values[0]) {
          Ok(_) => {
            let decimal = bin2dec_string(formula_value_string(values[0]))
            match decimal {
              Error(_) => decimal
              _ => {
                let new_values : Array[FormulaValue] = [decimal]
                if values.length() == 2 {
                  new_values.push(values[1])
                }
                dec2x_values("BIN2HEX", new_values)
              }
            }
          }
          Err(err) => err
        }
      }
    "BIN2OCT" =>
      if values.length() < 1 {
        Error(formula_error_value)
      } else if values.length() > 2 {
        Error(formula_error_value)
      } else {
        match value_as_number(values[0]) {
          Ok(_) => {
            let decimal = bin2dec_string(formula_value_string(values[0]))
            match decimal {
              Error(_) => decimal
              _ => {
                let new_values : Array[FormulaValue] = [decimal]
                if values.length() == 2 {
                  new_values.push(values[1])
                }
                dec2x_values("BIN2OCT", new_values)
              }
            }
          }
          Err(err) => err
        }
      }
    "DEC2BIN" => dec2x_values("DEC2BIN", values)
    "DEC2HEX" => dec2x_values("DEC2HEX", values)
    "DEC2OCT" => dec2x_values("DEC2OCT", values)
    "HEX2BIN" =>
      if values.length() < 1 {
        Error(formula_error_value)
      } else if values.length() > 2 {
        Error(formula_error_value)
      } else {
        match value_as_string(values[0]) {
          Ok(text) => {
            let decimal = hex2dec_string(text)
            match decimal {
              Error(_) => decimal
              _ => {
                let new_values : Array[FormulaValue] = [decimal]
                if values.length() == 2 {
                  new_values.push(values[1])
                }
                dec2x_values("HEX2BIN", new_values)
              }
            }
          }
          Err(err) => err
        }
      }
    "HEX2DEC" =>
      if values.length() == 1 {
        match value_as_string(values[0]) {
          Ok(text) => hex2dec_string(text)
          Err(err) => err
        }
      } else {
        Error(formula_error_value)
      }
    "HEX2OCT" =>
      if values.length() < 1 {
        Error(formula_error_value)
      } else if values.length() > 2 {
        Error(formula_error_value)
      } else {
        match value_as_string(values[0]) {
          Ok(text) => {
            let decimal = hex2dec_string(text)
            match decimal {
              Error(_) => decimal
              _ => {
                let new_values : Array[FormulaValue] = [decimal]
                if values.length() == 2 {
                  new_values.push(values[1])
                }
                dec2x_values("HEX2OCT", new_values)
              }
            }
          }
          Err(err) => err
        }
      }
    "OCT2BIN" =>
      if values.length() < 1 {
        Error(formula_error_value)
      } else if values.length() > 2 {
        Error(formula_error_value)
      } else {
        match value_as_number(values[0]) {
          Ok(_) => {
            let decimal = oct2dec_string(formula_value_string(values[0]))
            let new_values : Array[FormulaValue] = [decimal]
            if values.length() == 2 {
              new_values.push(values[1])
            }
            dec2x_values("OCT2BIN", new_values)
          }
          Err(err) => err
        }
      }
    "OCT2DEC" =>
      if values.length() == 1 {
        match value_as_number(values[0]) {
          Ok(_) => oct2dec_string(formula_value_string(values[0]))
          Err(err) => err
        }
      } else {
        Error(formula_error_value)
      }
    "OCT2HEX" =>
      if values.length() < 1 {
        Error(formula_error_value)
      } else if values.length() > 2 {
        Error(formula_error_value)
      } else {
        match value_as_number(values[0]) {
          Ok(_) => {
            let decimal = oct2dec_string(formula_value_string(values[0]))
            let new_values : Array[FormulaValue] = [decimal]
            if values.length() == 2 {
              new_values.push(values[1])
            }
            dec2x_values("OCT2HEX", new_values)
          }
          Err(err) => err
        }
      }
    "BESSELI" =>
      if values.length() == 2 {
        match (value_as_number(values[0]), value_as_number(values[1])) {
          (Ok(x), Ok(n)) => number_or_num_error(bessel_i(x, n))
          (Err(err), _) => err
          (_, Err(err)) => err
        }
      } else {
        Error(formula_error_value)
      }
    "BESSELJ" =>
      if values.length() == 2 {
        match (value_as_number(values[0]), value_as_number(values[1])) {
          (Ok(x), Ok(n)) => number_or_num_error(bessel_j(x, n))
          (Err(err), _) => err
          (_, Err(err)) => err
        }
      } else {
        Error(formula_error_value)
      }
    "BESSELK" =>
      if values.length() == 2 {
        match (value_as_number(values[0]), value_as_number(values[1])) {
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
      } else {
        Error(formula_error_value)
      }
    "BESSELY" =>
      if values.length() == 2 {
        match (value_as_number(values[0]), value_as_number(values[1])) {
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
      } else {
        Error(formula_error_value)
      }
    "DELTA" =>
      if values.length() < 1 {
        Error(formula_error_value)
      } else if values.length() > 2 {
        Error(formula_error_value)
      } else {
        let number1 = match value_as_number(values[0]) {
          Ok(num) => num
          Err(err) => return err
        }
        let number2 = if values.length() == 2 {
          match value_as_number(values[1]) {
            Ok(num) => num
            Err(err) => return err
          }
        } else {
          0.0
        }
        Number(if number1 == number2 { 1.0 } else { 0.0 })
      }
    "ERF" =>
      if values.length() < 1 {
        Error(formula_error_value)
      } else if values.length() > 2 {
        Error(formula_error_value)
      } else {
        match value_as_number(values[0]) {
          Ok(lower) =>
            if values.length() == 2 {
              match value_as_number(values[1]) {
                Ok(upper) =>
                  number_or_num_error(erf_double(upper) - erf_double(lower))
                Err(err) => err
              }
            } else {
              number_or_num_error(erf_double(lower))
            }
          Err(err) => err
        }
      }
    "ERFdotPRECISE" | "ERF.PRECISE" | "_XLFN.ERF.PRECISE" =>
      if values.length() == 1 {
        match value_as_number(values[0]) {
          Ok(value) => number_or_num_error(erf_double(value))
          Err(err) => err
        }
      } else {
        Error(formula_error_value)
      }
    "ERFC" =>
      if values.length() == 1 {
        match value_as_number(values[0]) {
          Ok(value) => number_or_num_error(erfc_double(value))
          Err(err) => err
        }
      } else {
        Error(formula_error_value)
      }
    "ERFCdotPRECISE" | "ERFC.PRECISE" | "_XLFN.ERFC.PRECISE" =>
      if values.length() == 1 {
        match value_as_number(values[0]) {
          Ok(value) => number_or_num_error(erfc_double(value))
          Err(err) => err
        }
      } else {
        Error(formula_error_value)
      }
    "WEIBULL" => weibull_value(values)
    "WEIBULLdotDIST" | "WEIBULL.DIST" | "_XLFN.WEIBULL.DIST" =>
      weibull_value(values)
    "BETAdotDIST" | "BETA.DIST" | "_XLFN.BETA.DIST" => beta_dist_values(values)
    "BETADIST" => betadist_values(values)
    "BETAINV" => betainv_values(values)
    "BETAdotINV" | "BETA.INV" | "_XLFN.BETA.INV" => betainv_values(values)
    "CONFIDENCE" => confidence_values(values)
    "CONFIDENCEdotNORM" | "CONFIDENCE.NORM" | "_XLFN.CONFIDENCE.NORM" =>
      confidence_values(values)
    "CONFIDENCEdotT" | "CONFIDENCE.T" | "_XLFN.CONFIDENCE.T" =>
      confidence_t_values(values)
    "NORMdotDIST" | "NORM.DIST" | "_XLFN.NORM.DIST" => normdist_values(values)
    "NORMDIST" => normdist_values(values)
    "NORMdotINV" | "NORM.INV" | "_XLFN.NORM.INV" => norminv_values(values)
    "NORMINV" => norminv_values(values)
    "NORMdotSdotDIST" | "NORM.S.DIST" | "_XLFN.NORM.S.DIST" =>
      norm_s_dist_values(values)
    "NORMSDIST" => norms_dist_values(values)
    "NORMdotSdotINV" | "NORM.S.INV" | "_XLFN.NORM.S.INV" =>
      norm_s_inv_values(values)
    "NORMSINV" => norms_inv_values(values)
    "LOGNORMdotDIST" | "LOGNORM.DIST" | "_XLFN.LOGNORM.DIST" =>
      lognorm_dist_values(values)
    "LOGNORMDIST" => lognormdist_values(values)
    "LOGINV" => loginv_values(values)
    "LOGNORMdotINV" | "LOGNORM.INV" | "_XLFN.LOGNORM.INV" =>
      loginv_values(values)
    "GAMMA" => gamma_value(values)
    "GAMMAdotDIST" | "GAMMA.DIST" | "_XLFN.GAMMA.DIST" =>
      gamma_dist_values(values)
    "GAMMADIST" => gamma_dist_values(values)
    "GAMMAdotINV" | "GAMMA.INV" | "_XLFN.GAMMA.INV" => gamma_inv_values(values)
    "GAMMAINV" => gamma_inv_values(values)
    "GAMMALN" => gammaln_values(values)
    "GAMMALNdotPRECISE" | "GAMMALN.PRECISE" | "_XLFN.GAMMALN.PRECISE" =>
      gammaln_precise_values(values)
    "EXPONdotDIST" | "EXPON.DIST" | "_XLFN.EXPON.DIST" =>
      expon_dist_values(values)
    "EXPONDIST" => expon_dist_values(values)
    "POISSONdotDIST" | "POISSON.DIST" | "_XLFN.POISSON.DIST" =>
      poisson_values(values)
    "POISSON" => poisson_values(values)
    "PROB" => prob_values(values)
    "BINOMdotDIST" | "BINOM.DIST" | "_XLFN.BINOM.DIST" =>
      binomdist_values(values)
    "BINOMDIST" => binomdist_values(values)
    "BINOMdotDISTdotRANGE" | "BINOM.DIST.RANGE" | "_XLFN.BINOM.DIST.RANGE" =>
      binom_dist_range_values(values)
    "BINOMdotINV" | "BINOM.INV" | "_XLFN.BINOM.INV" => binom_inv_values(values)
    "CRITBINOM" => binom_inv_values(values)
    "HYPGEOMdotDIST" | "HYPGEOM.DIST" | "_XLFN.HYPGEOM.DIST" =>
      hypgeom_dist_values(values)
    "HYPGEOMDIST" => hypgeomdist_values(values)
    "NEGBINOMdotDIST" | "NEGBINOM.DIST" | "_XLFN.NEGBINOM.DIST" =>
      negbinom_dist_values(values)
    "NEGBINOMDIST" => negbinomdist_values(values)
    "GAUSS" => gauss_value(values)
    "PHI" => phi_value(values)
    "CHIDIST" => chidist_values(values)
    "CHIINV" => chiinv_values(values)
    "CHISQdotDIST" | "CHISQ.DIST" | "_XLFN.CHISQ.DIST" =>
      chisq_dist_values(values)
    "CHISQdotDISTdotRT" | "CHISQ.DIST.RT" | "_XLFN.CHISQ.DIST.RT" =>
      chidist_values(values)
    "CHISQdotINV" | "CHISQ.INV" | "_XLFN.CHISQ.INV" => chisq_inv_values(values)
    "CHISQdotINVdotRT" | "CHISQ.INV.RT" | "_XLFN.CHISQ.INV.RT" =>
      chiinv_values(values)
    "CHITEST" => chitest_values(workbook, sheet_name, args, values, ctx)
    "CHISQdotTEST" | "CHISQ.TEST" | "_XLFN.CHISQ.TEST" =>
      chitest_values(workbook, sheet_name, args, values, ctx)
    "FdotDIST" | "F.DIST" | "_XLFN.F.DIST" => fdist_values(values)
    "FDIST" => fdist_rt_values(values)
    "FdotDISTdotRT" | "F.DIST.RT" | "_XLFN.F.DIST.RT" => fdist_rt_values(values)
    "FdotINV" | "F.INV" | "_XLFN.F.INV" => finv_values(values)
    "FdotINVdotRT" | "F.INV.RT" | "_XLFN.F.INV.RT" => finv_rt_values(values)
    "FINV" => finv_rt_values(values)
    "FTEST" => ftest_values(workbook, sheet_name, args, values, ctx)
    "FdotTEST" | "F.TEST" | "_XLFN.F.TEST" =>
      ftest_values(workbook, sheet_name, args, values, ctx)
    "ACCRINT" => accrint_values(values)
    "ACCRINTM" => accrintm_values(values)
    "AMORDEGRC" => amordegrc_values(values)
    "AMORLINC" => amorlinc_values(values)
    "COUPDAYBS" => coupdaybs_values(values)
    "COUPDAYS" => coupdays_values(values)
    "COUPDAYSNC" => coupdaysnc_values(values)
    "COUPNCD" => coupncd_values(values)
    "COUPNUM" => coupnum_values(values)
    "COUPPCD" => couppcd_values(values)
    "CUMIPMT" => cumip_values("CUMIPMT", values)
    "CUMPRINC" => cumip_values("CUMPRINC", values)
    "DURATION" => duration_values(values)
    "DB" => db_values(values)
    "DDB" => ddb_values(values)
    "FV" => fv_values(values)
    "FVSCHEDULE" => fvschedule_values(values)
    "DISC" => disc_intrate_values("DISC", values)
    "INTRATE" => disc_intrate_values("INTRATE", values)
    "IRR" => irr_values(values)
    "MDURATION" => mduration_values(values)
    "MIRR" => mirr_values(values)
    "DOLLAR" => dollar_values(values)
    "DOLLARDE" => dollar_fraction_values("DOLLARDE", values)
    "DOLLARFR" => dollar_fraction_values("DOLLARFR", values)
    "EFFECT" => effect_values(values)
    "CONVERT" => convert_values(values)
    "EUROCONVERT" => euroconvert_values(values)
    "IPMT" => ipmt_values("IPMT", values)
    "ISPMT" => ispmt_values(values)
    "NOMINAL" => nominal_values(values)
    "NPER" => nper_values(values)
    "NPV" => npv_values(values)
    "ODDFPRICE" => oddfprice_values(values)
    "ODDFYIELD" => oddfyield_values(values)
    "ODDLPRICE" => oddl_values("ODDLPRICE", values)
    "ODDLYIELD" => oddl_values("ODDLYIELD", values)
    "PDURATION" => pduration_values(values)
    "PMT" => pmt_values(values)
    "PPMT" => ipmt_values("PPMT", values)
    "PRICE" => price_yield_values("PRICE", values)
    "PRICEDISC" => pricedisc_values(values)
    "PRICEMAT" => pricemat_values(values)
    "PV" => pv_values(values)
    "RATE" => rate_values(values)
    "RECEIVED" => received_values(values)
    "RRI" => rri_values(values)
    "SLN" => sln_values(values)
    "SYD" => syd_values(values)
    "TBILLEQ" => tbilleq_values(values)
    "TBILLPRICE" => tbillprice_values(values)
    "TBILLYIELD" => tbillyield_values(values)
    "XIRR" => xirr_values(values)
    "XNPV" => xnpv_values(values)
    "YIELD" => price_yield_values("YIELD", values)
    "YIELDDISC" => yielddisc_values(values)
    "YIELDMAT" => yieldmat_values(values)
    "VDB" => vdb_values(values)
    "TdotDIST" | "T.DIST" | "_XLFN.T.DIST" => tdist_values(values)
    "TdotDISTdot2T" | "T.DIST.2T" | "_XLFN.T.DIST.2T" => tdist_2t_values(values)
    "TdotDISTdotRT" | "T.DIST.RT" | "_XLFN.T.DIST.RT" => tdist_rt_values(values)
    "TDIST" => tdist_legacy_values(values)
    "TdotINV" | "T.INV" | "_XLFN.T.INV" => tinv_values(values)
    "TdotINVdot2T" | "T.INV.2T" | "_XLFN.T.INV.2T" => tinv_2t_values(values)
    "TINV" => tinv_2t_values(values)
    "TdotTEST" | "T.TEST" | "_XLFN.T.TEST" => ttest_values(values)
    "TTEST" => ttest_values(values)
    "ZdotTEST" | "Z.TEST" | "_XLFN.Z.TEST" => ztest_values(values)
    "ZTEST" => ztest_values(values)
    "GESTEP" =>
      if values.length() < 1 {
        Error(formula_error_value)
      } else if values.length() > 2 {
        Error(formula_error_value)
      } else {
        let number = match value_as_number(values[0]) {
          Ok(num) => num
          Err(err) => return err
        }
        let step = if values.length() == 2 {
          match value_as_number(values[1]) {
            Ok(num) => num
            Err(err) => return err
          }
        } else {
          0.0
        }
        Number(if number >= step { 1.0 } else { 0.0 })
      }
    "BITAND" => bitwise_values("BITAND", values)
    "BITLSHIFT" => bitwise_values("BITLSHIFT", values)
    "BITOR" => bitwise_values("BITOR", values)
    "BITRSHIFT" => bitwise_values("BITRSHIFT", values)
    "BITXOR" => bitwise_values("BITXOR", values)
    "ACOS" =>
      if values.length() == 1 {
        match value_as_number(values[0]) {
          Ok(num) => number_or_num_error(@math.acos(num))
          Err(err) => err
        }
      } else {
        Error(formula_error_value)
      }
    "ACOSH" =>
      if values.length() == 1 {
        match value_as_number(values[0]) {
          Ok(num) => number_or_num_error(@math.acosh(num))
          Err(err) => err
        }
      } else {
        Error(formula_error_value)
      }
    "ACOT" | "_XLFN.ACOT" =>
      if values.length() == 1 {
        match value_as_number(values[0]) {
          Ok(num) => number_or_num_error(@math.PI / 2.0 - @math.atan(num))
          Err(err) => err
        }
      } else {
        Error(formula_error_value)
      }
    "ACOTH" | "_XLFN.ACOTH" =>
      if values.length() == 1 {
        match value_as_number(values[0]) {
          Ok(num) => number_or_num_error(@math.atanh(1.0 / num))
          Err(err) => err
        }
      } else {
        Error(formula_error_value)
      }
    "ASIN" =>
      if values.length() == 1 {
        match value_as_number(values[0]) {
          Ok(num) => number_or_num_error(@math.asin(num))
          Err(err) => err
        }
      } else {
        Error(formula_error_value)
      }
    "ASINH" =>
      if values.length() == 1 {
        match value_as_number(values[0]) {
          Ok(num) => number_or_num_error(@math.asinh(num))
          Err(err) => err
        }
      } else {
        Error(formula_error_value)
      }
    "ATAN" =>
      if values.length() == 1 {
        match value_as_number(values[0]) {
          Ok(num) => number_or_num_error(@math.atan(num))
          Err(err) => err
        }
      } else {
        Error(formula_error_value)
      }
    "ATANH" =>
      if values.length() == 1 {
        match value_as_number(values[0]) {
          Ok(num) => number_or_num_error(@math.atanh(num))
          Err(err) => err
        }
      } else {
        Error(formula_error_value)
      }
    "ATAN2" =>
      if values.length() == 2 {
        match (value_as_number(values[0]), value_as_number(values[1])) {
          (Ok(y), Ok(x)) => number_or_num_error(@math.atan2(x, y))
          (Err(err), _) => err
          (_, Err(err)) => err
        }
      } else {
        Error(formula_error_value)
      }
    "COS" =>
      if values.length() == 1 {
        match value_as_number(values[0]) {
          Ok(num) => number_or_num_error(@math.cos(num))
          Err(err) => err
        }
      } else {
        Error(formula_error_value)
      }
    "COSH" =>
      if values.length() == 1 {
        match value_as_number(values[0]) {
          Ok(num) => number_or_num_error(@math.cosh(num))
          Err(err) => err
        }
      } else {
        Error(formula_error_value)
      }
    "SIN" =>
      if values.length() == 1 {
        match value_as_number(values[0]) {
          Ok(num) => number_or_num_error(@math.sin(num))
          Err(err) => err
        }
      } else {
        Error(formula_error_value)
      }
    "SINH" =>
      if values.length() == 1 {
        match value_as_number(values[0]) {
          Ok(num) => number_or_num_error(@math.sinh(num))
          Err(err) => err
        }
      } else {
        Error(formula_error_value)
      }
    "TAN" =>
      if values.length() == 1 {
        match value_as_number(values[0]) {
          Ok(num) => number_or_num_error(@math.tan(num))
          Err(err) => err
        }
      } else {
        Error(formula_error_value)
      }
    "TANH" =>
      if values.length() == 1 {
        match value_as_number(values[0]) {
          Ok(num) => number_or_num_error(@math.tanh(num))
          Err(err) => err
        }
      } else {
        Error(formula_error_value)
      }
    "COT" | "_XLFN.COT" =>
      if values.length() == 1 {
        match value_as_number(values[0]) {
          Ok(num) =>
            if num == 0.0 {
              Error(formula_error_div)
            } else {
              number_or_num_error(1.0 / @math.tan(num))
            }
          Err(err) => err
        }
      } else {
        Error(formula_error_value)
      }
    "COTH" | "_XLFN.COTH" =>
      if values.length() == 1 {
        match value_as_number(values[0]) {
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
      } else {
        Error(formula_error_value)
      }
    "CSC" | "_XLFN.CSC" =>
      if values.length() == 1 {
        match value_as_number(values[0]) {
          Ok(num) =>
            if num == 0.0 {
              Error(formula_error_div)
            } else {
              number_or_num_error(1.0 / @math.sin(num))
            }
          Err(err) => err
        }
      } else {
        Error(formula_error_value)
      }
    "CSCH" | "_XLFN.CSCH" =>
      if values.length() == 1 {
        match value_as_number(values[0]) {
          Ok(num) =>
            if num == 0.0 {
              Error(formula_error_div)
            } else {
              number_or_num_error(1.0 / @math.sinh(num))
            }
          Err(err) => err
        }
      } else {
        Error(formula_error_value)
      }
    "SEC" | "_XLFN.SEC" =>
      if values.length() == 1 {
        match value_as_number(values[0]) {
          Ok(num) => number_or_num_error(@math.cos(num))
          Err(err) => err
        }
      } else {
        Error(formula_error_value)
      }
    "SECH" | "_XLFN.SECH" =>
      if values.length() == 1 {
        match value_as_number(values[0]) {
          Ok(num) => number_or_num_error(1.0 / @math.cosh(num))
          Err(err) => err
        }
      } else {
        Error(formula_error_value)
      }
    "DEGREES" =>
      if values.length() == 1 {
        match value_as_number(values[0]) {
          Ok(num) =>
            if num == 0.0 {
              Error(formula_error_div)
            } else {
              Number(180.0 / @math.PI * num)
            }
          Err(err) => err
        }
      } else {
        Error(formula_error_value)
      }
    "RADIANS" =>
      if values.length() == 1 {
        match value_as_number(values[0]) {
          Ok(num) => Number(@math.PI / 180.0 * num)
          Err(err) => err
        }
      } else {
        Error(formula_error_value)
      }
    "RAND" =>
      if values.length() == 0 {
        Number(rand_state.double())
      } else {
        Error(formula_error_value)
      }
    "RANDARRAY" | "_XLFN.RANDARRAY" => randarray_values(values)
    "RANDBETWEEN" =>
      if values.length() == 2 {
        match (value_as_number(values[0]), value_as_number(values[1])) {
          (Ok(bottom), Ok(top)) =>
            if top < bottom {
              Error(formula_error_num)
            } else {
              let bottom_int = Double::to_int(trunc_double(bottom))
              let top_int = Double::to_int(trunc_double(top))
              let range = top_int - bottom_int + 1
              let rand_value = if range > 0 {
                rand_state.int(limit=range)
              } else {
                0
              }
              Number(Double::from_int(rand_value + bottom_int))
            }
          (Err(err), _) => err
          (_, Err(err)) => err
        }
      } else {
        Error(formula_error_value)
      }
    "PI" =>
      if values.length() == 0 {
        Number(@math.PI)
      } else {
        Error(formula_error_value)
      }
    "SQRTPI" =>
      if values.length() == 1 {
        match value_as_number(values[0]) {
          Ok(num) => Number(@math.pow(num * @math.PI, 0.5))
          Err(err) => err
        }
      } else {
        Error(formula_error_value)
      }
    "LOG" =>
      if values.length() == 0 {
        Error(formula_error_value)
      } else if values.length() > 2 {
        Error(formula_error_value)
      } else {
        match value_as_number(values[0]) {
          Ok(num) => {
            let mut base = 10.0
            if values.length() == 2 {
              match value_as_number(values[1]) {
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
      }
    "LOG10" =>
      if values.length() == 1 {
        match value_as_number(values[0]) {
          Ok(num) => Number(@math.log10(num))
          Err(err) => err
        }
      } else {
        Error(formula_error_value)
      }
    "IMABS" =>
      if values.length() == 1 {
        match parse_complex_value(values[0]) {
          Ok(num) =>
            number_or_num_error(round_significant_digits(complex_abs(num), 15))
          Err(err) => err
        }
      } else {
        Error(formula_error_value)
      }
    "IMAGINARY" =>
      if values.length() == 1 {
        match parse_complex_value(values[0]) {
          Ok(num) => number_or_num_error(round_significant_digits(num.imag, 15))
          Err(err) => err
        }
      } else {
        Error(formula_error_value)
      }
    "IMARGUMENT" =>
      if values.length() == 1 {
        match parse_complex_value(values[0]) {
          Ok(num) =>
            number_or_num_error(round_significant_digits(complex_arg(num), 15))
          Err(err) => err
        }
      } else {
        Error(formula_error_value)
      }
    "IMCONJUGATE" =>
      if values.length() == 1 {
        match parse_complex_value_with_suffix(values[0]) {
          Ok((num, suffix)) =>
            String(complex_to_string(complex_conj(num), suffix))
          Err(err) => err
        }
      } else {
        Error(formula_error_value)
      }
    "IMCOS" =>
      if values.length() == 1 {
        match parse_complex_value_with_suffix(values[0]) {
          Ok((num, suffix)) =>
            String(complex_to_string(complex_cos(num), suffix))
          Err(err) => err
        }
      } else {
        Error(formula_error_value)
      }
    "IMCOSH" =>
      if values.length() == 1 {
        match parse_complex_value_with_suffix(values[0]) {
          Ok((num, suffix)) =>
            String(complex_to_string(complex_cosh(num), suffix))
          Err(err) => err
        }
      } else {
        Error(formula_error_value)
      }
    "IMCOT" =>
      if values.length() == 1 {
        match parse_complex_value_with_suffix(values[0]) {
          Ok((num, suffix)) =>
            String(
              complex_to_string(
                complex_div(complex_cos(num), complex_sin(num)),
                suffix,
              ),
            )
          Err(err) => err
        }
      } else {
        Error(formula_error_value)
      }
    "IMCSC" =>
      if values.length() == 1 {
        match parse_complex_value_with_suffix(values[0]) {
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
      } else {
        Error(formula_error_value)
      }
    "IMCSCH" =>
      if values.length() == 1 {
        match parse_complex_value_with_suffix(values[0]) {
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
      } else {
        Error(formula_error_value)
      }
    "IMDIV" =>
      if values.length() == 2 {
        match
          (
            parse_complex_value_with_suffix(values[0]),
            parse_complex_value(values[1]),
          ) {
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
      } else {
        Error(formula_error_value)
      }
    "IMEXP" =>
      if values.length() == 1 {
        match parse_complex_value_with_suffix(values[0]) {
          Ok((num, suffix)) =>
            String(complex_to_string(complex_exp(num), suffix))
          Err(err) => err
        }
      } else {
        Error(formula_error_value)
      }
    "IMLN" =>
      if values.length() == 1 {
        match parse_complex_value_with_suffix(values[0]) {
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
      } else {
        Error(formula_error_value)
      }
    "IMLOG10" =>
      if values.length() == 1 {
        match parse_complex_value_with_suffix(values[0]) {
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
      } else {
        Error(formula_error_value)
      }
    "IMLOG2" =>
      if values.length() == 1 {
        match parse_complex_value_with_suffix(values[0]) {
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
      } else {
        Error(formula_error_value)
      }
    "IMPOWER" =>
      if values.length() == 2 {
        match
          (
            parse_complex_value_with_suffix(values[0]),
            parse_complex_value(values[1]),
          ) {
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
      } else {
        Error(formula_error_value)
      }
    "IMPRODUCT" => {
      let mut product = complex_new(1.0, 0.0)
      for value in flatten_values(values) {
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
    "IMREAL" =>
      if values.length() == 1 {
        match parse_complex_value(values[0]) {
          Ok(num) => String(format_number(num.real))
          Err(err) => err
        }
      } else {
        Error(formula_error_value)
      }
    "IMSEC" =>
      if values.length() == 1 {
        match parse_complex_value_with_suffix(values[0]) {
          Ok((num, suffix)) => {
            let result = complex_div(complex_new(1.0, 0.0), complex_cos(num))
            String(complex_to_string(result, suffix))
          }
          Err(err) => err
        }
      } else {
        Error(formula_error_value)
      }
    "IMSECH" =>
      if values.length() == 1 {
        match parse_complex_value_with_suffix(values[0]) {
          Ok((num, suffix)) => {
            let result = complex_div(complex_new(1.0, 0.0), complex_cosh(num))
            String(complex_to_string(result, suffix))
          }
          Err(err) => err
        }
      } else {
        Error(formula_error_value)
      }
    "IMSIN" =>
      if values.length() == 1 {
        match parse_complex_value_with_suffix(values[0]) {
          Ok((num, suffix)) =>
            String(complex_to_string(complex_sin(num), suffix))
          Err(err) => err
        }
      } else {
        Error(formula_error_value)
      }
    "IMSINH" =>
      if values.length() == 1 {
        match parse_complex_value_with_suffix(values[0]) {
          Ok((num, suffix)) =>
            String(complex_to_string(complex_sinh(num), suffix))
          Err(err) => err
        }
      } else {
        Error(formula_error_value)
      }
    "IMSQRT" =>
      if values.length() == 1 {
        match parse_complex_value_with_suffix(values[0]) {
          Ok((num, suffix)) =>
            String(complex_to_string(complex_sqrt(num), suffix))
          Err(err) => err
        }
      } else {
        Error(formula_error_value)
      }
    "IMSUB" =>
      if values.length() == 2 {
        match (parse_complex_value(values[0]), parse_complex_value(values[1])) {
          (Ok(left), Ok(right)) =>
            String(complex_to_string(complex_sub(left, right), "i"))
          (Err(err), _) => err
          (_, Err(err)) => err
        }
      } else {
        Error(formula_error_value)
      }
    "IMSUM" =>
      if values.length() >= 1 {
        let mut result = complex_new(0.0, 0.0)
        for value in flatten_values(values) {
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
      } else {
        Error(formula_error_value)
      }
    "IMTAN" =>
      if values.length() == 1 {
        match parse_complex_value_with_suffix(values[0]) {
          Ok((num, suffix)) =>
            String(complex_to_string(complex_tan(num), suffix))
          Err(err) => err
        }
      } else {
        Error(formula_error_value)
      }
    "FLOOR" =>
      if values.length() == 2 {
        match (value_as_number(values[0]), value_as_number(values[1])) {
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
      } else {
        Error(formula_error_value)
      }
    "CEILING" =>
      if values.length() == 0 {
        Error(formula_error_value)
      } else if values.length() > 2 {
        Error(formula_error_value)
      } else {
        match value_as_number(values[0]) {
          Ok(num) => {
            let mut significance = if num < 0.0 { -1.0 } else { 1.0 }
            if values.length() > 1 {
              match value_as_number(values[1]) {
                Ok(value) => significance = value
                Err(err) => return err
              }
            }
            if significance < 0.0 && num > 0.0 {
              Error(formula_error_value)
            } else if values.length() == 1 {
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
      }
    "CEILINGdotMATH" | "CEILING.MATH" | "_XLFN.CEILING.MATH" =>
      if values.length() == 0 {
        Error(formula_error_value)
      } else if values.length() > 3 {
        Error(formula_error_value)
      } else {
        match value_as_number(values[0]) {
          Ok(num) =>
            if values.length() == 1 {
              Number(Double::ceil(num))
            } else {
              let mut significance = if num < 0.0 { -1.0 } else { 1.0 }
              let mut mode = 1.0
              match value_as_number(values[1]) {
                Ok(value) => significance = value
                Err(err) => return err
              }
              if values.length() > 2 {
                match value_as_number(values[2]) {
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
      }
    "CEILINGdotPRECISE" | "CEILING.PRECISE" | "_XLFN.CEILING.PRECISE" =>
      if values.length() == 0 {
        Error(formula_error_value)
      } else if values.length() > 2 {
        Error(formula_error_value)
      } else {
        match value_as_number(values[0]) {
          Ok(num) =>
            if values.length() == 1 {
              Number(Double::ceil(num))
            } else {
              match value_as_number(values[1]) {
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
            }
          Err(err) => err
        }
      }
    "FLOORdotMATH" | "FLOOR.MATH" | "_XLFN.FLOOR.MATH" =>
      if values.length() == 0 {
        Error(formula_error_value)
      } else if values.length() > 3 {
        Error(formula_error_value)
      } else {
        match value_as_number(values[0]) {
          Ok(num) =>
            if values.length() == 1 {
              Number(Double::floor(num))
            } else {
              let mut significance = if num < 0.0 { -1.0 } else { 1.0 }
              let mut mode = 1.0
              match value_as_number(values[1]) {
                Ok(value) => significance = value
                Err(err) => return err
              }
              if values.length() > 2 {
                match value_as_number(values[2]) {
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
      }
    "FLOORdotPRECISE" | "FLOOR.PRECISE" | "_XLFN.FLOOR.PRECISE" =>
      if values.length() == 0 {
        Error(formula_error_value)
      } else if values.length() > 2 {
        Error(formula_error_value)
      } else {
        match value_as_number(values[0]) {
          Ok(num) =>
            if values.length() == 1 {
              Number(Double::floor(num))
            } else {
              match value_as_number(values[1]) {
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
            }
          Err(err) => err
        }
      }
    "ISOdotCEILING" | "ISO.CEILING" | "_XLFN.ISO.CEILING" =>
      if values.length() == 0 {
        Error(formula_error_value)
      } else if values.length() > 2 {
        Error(formula_error_value)
      } else {
        match value_as_number(values[0]) {
          Ok(num) =>
            if values.length() == 1 {
              Number(Double::ceil(num))
            } else {
              match value_as_number(values[1]) {
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
            }
          Err(err) => err
        }
      }
    "TRUNC" =>
      if values.length() == 1 || values.length() == 2 {
        match value_as_number(values[0]) {
          Ok(num) => {
            let digits = if values.length() == 2 {
              match value_as_number(values[1]) {
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
      } else {
        Error(formula_error_value)
      }
    "ROUND" =>
      if values.length() == 2 {
        match (value_as_number(values[0]), value_as_number(values[1])) {
          (Ok(num), Ok(digits)) =>
            Number(round_with_digits(num, Double::to_int(digits)))
          (Err(err), _) => err
          (_, Err(err)) => err
        }
      } else {
        Error(formula_error_value)
      }
    "ROUNDUP" =>
      if values.length() == 2 {
        match (value_as_number(values[0]), value_as_number(values[1])) {
          (Ok(num), Ok(digits)) =>
            Number(round_up_with_digits(num, Double::to_int(digits)))
          (Err(err), _) => err
          (_, Err(err)) => err
        }
      } else {
        Error(formula_error_value)
      }
    "ROUNDDOWN" =>
      if values.length() == 2 {
        match (value_as_number(values[0]), value_as_number(values[1])) {
          (Ok(num), Ok(digits)) =>
            Number(round_down_with_digits(num, Double::to_int(digits)))
          (Err(err), _) => err
          (_, Err(err)) => err
        }
      } else {
        Error(formula_error_value)
      }
    "SQRT" =>
      if values.length() == 1 {
        match value_as_number(values[0]) {
          Ok(num) =>
            if num < 0.0 {
              Error(formula_error_num)
            } else {
              Number(@math.pow(num, 0.5))
            }
          Err(err) => err
        }
      } else {
        Error(formula_error_value)
      }
    "POWER" =>
      if values.length() == 2 {
        match (value_as_number(values[0]), value_as_number(values[1])) {
          (Ok(lhs), Ok(rhs)) => Number(@math.pow(lhs, rhs))
          (Err(err), _) => err
          (_, Err(err)) => err
        }
      } else {
        Error(formula_error_value)
      }
    "EVEN" =>
      if values.length() == 1 {
        match value_as_number(values[0]) {
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
      } else {
        Error(formula_error_value)
      }
    "ODD" =>
      if values.length() == 1 {
        match value_as_number(values[0]) {
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
      } else {
        Error(formula_error_value)
      }
    "MROUND" =>
      if values.length() == 2 {
        match (value_as_number(values[0]), value_as_number(values[1])) {
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
      } else {
        Error(formula_error_value)
      }
    "MOD" =>
      if values.length() == 2 {
        match (value_as_number(values[0]), value_as_number(values[1])) {
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
      } else {
        Error(formula_error_value)
      }
    "QUOTIENT" =>
      if values.length() == 2 {
        match (value_as_number(values[0]), value_as_number(values[1])) {
          (Ok(num), Ok(divisor)) =>
            if divisor == 0.0 {
              Error(formula_error_div)
            } else {
              Number(trunc_double(num / divisor))
            }
          (Err(err), _) => err
          (_, Err(err)) => err
        }
      } else {
        Error(formula_error_value)
      }
    "AND" =>
      if values.length() == 0 || values.length() > 30 {
        Error(formula_error_value)
      } else {
        let mut result = true
        for value in values {
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
    "OR" =>
      if values.length() == 0 || values.length() > 30 {
        Error(formula_error_value)
      } else {
        for value in flatten_values(values) {
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
    "NOT" =>
      if values.length() == 1 {
        match normalize_scalar(values[0]) {
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
      } else {
        Error(formula_error_value)
      }
    "XOR" =>
      if values.length() == 0 {
        Error(formula_error_value)
      } else {
        let mut count = 0
        let mut ok = false
        for value in flatten_values(values) {
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
    "LEN" =>
      if values.length() == 1 {
        match value_as_string(values[0]) {
          Ok(text) => Number(Double::from_int(text.length()))
          Err(err) => err
        }
      } else {
        Error(formula_error_value)
      }
    "LENB" =>
      if values.length() == 1 {
        match value_as_string(values[0]) {
          Ok(text) => Number(Double::from_int(dbcs_byte_length(text)))
          Err(err) => err
        }
      } else {
        Error(formula_error_value)
      }
    "LOWER" =>
      if values.length() == 1 {
        match value_as_string(values[0]) {
          Ok(text) => String(text.to_lower())
          Err(err) => err
        }
      } else {
        Error(formula_error_value)
      }
    "UPPER" =>
      if values.length() == 1 {
        match value_as_string(values[0]) {
          Ok(text) => String(text.to_upper())
          Err(err) => err
        }
      } else {
        Error(formula_error_value)
      }
    "PROPER" =>
      if values.length() == 1 {
        match value_as_string(values[0]) {
          Ok(text) => String(proper_case(text))
          Err(err) => err
        }
      } else {
        Error(formula_error_value)
      }
    "DBCS" =>
      if values.length() == 1 {
        match value_as_string(values[0]) {
          Ok(text) =>
            if dbcs_enabled(workbook) {
              String(dbcs_convert(text))
            } else {
              String(text)
            }
          Err(err) => err
        }
      } else {
        Error(formula_error_value)
      }
    "TRIM" =>
      if values.length() == 1 {
        match value_as_string(values[0]) {
          Ok(text) => String(trim_excel_text(text))
          Err(err) => err
        }
      } else {
        Error(formula_error_value)
      }
    "LEFT" =>
      if values.length() == 1 || values.length() == 2 {
        let text = match value_as_string(values[0]) {
          Ok(text) => text
          Err(err) => return err
        }
        let count = if values.length() == 2 {
          match value_as_int(values[1]) {
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
      } else {
        Error(formula_error_value)
      }
    "LEFTB" =>
      if values.length() == 1 || values.length() == 2 {
        let text = match value_as_string(values[0]) {
          Ok(text) => text
          Err(err) => return err
        }
        let count = if values.length() == 2 {
          match value_as_int(values[1]) {
            Ok(num) => num
            Err(err) => return err
          }
        } else {
          1
        }
        if count < 0 {
          Error(formula_error_value)
        } else {
          let bytes = @encoding/utf8.encode(text)
          let len = bytes.length()
          if count >= len {
            String(text)
          } else {
            String(bytes_to_string(bytes[0:count]))
          }
        }
      } else {
        Error(formula_error_value)
      }
    "RIGHT" =>
      if values.length() == 1 || values.length() == 2 {
        let text = match value_as_string(values[0]) {
          Ok(text) => text
          Err(err) => return err
        }
        let count = if values.length() == 2 {
          match value_as_int(values[1]) {
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
      } else {
        Error(formula_error_value)
      }
    "RIGHTB" =>
      if values.length() == 1 || values.length() == 2 {
        let text = match value_as_string(values[0]) {
          Ok(text) => text
          Err(err) => return err
        }
        let count = if values.length() == 2 {
          match value_as_int(values[1]) {
            Ok(num) => num
            Err(err) => return err
          }
        } else {
          1
        }
        if count < 0 {
          Error(formula_error_value)
        } else {
          let bytes = @encoding/utf8.encode(text)
          let len = bytes.length()
          if count >= len {
            String(text)
          } else {
            let start = len - count
            String(bytes_to_string(bytes[start:len]))
          }
        }
      } else {
        Error(formula_error_value)
      }
    "MID" =>
      if values.length() == 3 {
        let text = match value_as_string(values[0]) {
          Ok(text) => text
          Err(err) => return err
        }
        let start_num = match value_as_int(values[1]) {
          Ok(num) => num
          Err(err) => return err
        }
        let count = match value_as_int(values[2]) {
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
      } else {
        Error(formula_error_value)
      }
    "MIDB" =>
      if values.length() == 3 {
        let text = match value_as_string(values[0]) {
          Ok(text) => text
          Err(err) => return err
        }
        let start_num = match value_as_int(values[1]) {
          Ok(num) => num
          Err(err) => return err
        }
        let count = match value_as_int(values[2]) {
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
          String(sb.to_string())
        }
      } else {
        Error(formula_error_value)
      }
    "REPT" =>
      if values.length() == 2 {
        let text = match value_as_string(values[0]) {
          Ok(text) => text
          Err(err) => return err
        }
        let times = match value_as_int(values[1]) {
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
      } else {
        Error(formula_error_value)
      }
    "REPLACE" =>
      if values.length() == 4 {
        let text = match value_as_string(values[0]) {
          Ok(text) => text
          Err(err) => return err
        }
        let start_num = match value_as_int(values[1]) {
          Ok(num) => num
          Err(err) => return err
        }
        let count = match value_as_int(values[2]) {
          Ok(num) => num
          Err(err) => return err
        }
        let new_text = match value_as_string(values[3]) {
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
          let sb = StringBuilder::new()
          sb.write_view(text.unsafe_substring(start=0, end=start))
          sb.write_view(new_text)
          sb.write_view(text.unsafe_substring(start=end, end=len))
          String(sb.to_string())
        }
      } else {
        Error(formula_error_value)
      }
    "REPLACEB" =>
      if values.length() == 4 {
        let text = match value_as_string(values[0]) {
          Ok(text) => text
          Err(err) => return err
        }
        let start_num = match value_as_int(values[1]) {
          Ok(num) => num
          Err(err) => return err
        }
        let count = match value_as_int(values[2]) {
          Ok(num) => num
          Err(err) => return err
        }
        let new_text = match value_as_string(values[3]) {
          Ok(text) => text
          Err(err) => return err
        }
        if start_num <= 0 || count < 0 {
          Error(formula_error_value)
        } else {
          let bytes = @encoding/utf8.encode(text)
          let len = bytes.length()
          let mut start = start_num - 1
          if start > len {
            start = len
          }
          let mut end = start + count
          if end > len {
            end = len
          }
          let sb = StringBuilder::new()
          sb.write_view(bytes_to_string(bytes[0:start]))
          sb.write_view(new_text)
          sb.write_view(bytes_to_string(bytes[end:len]))
          String(sb.to_string())
        }
      } else {
        Error(formula_error_value)
      }
    "SUBSTITUTE" =>
      if values.length() == 3 || values.length() == 4 {
        let text = match value_as_string(values[0]) {
          Ok(text) => text
          Err(err) => return err
        }
        let old_text = match value_as_string(values[1]) {
          Ok(text) => text
          Err(err) => return err
        }
        let new_text = match value_as_string(values[2]) {
          Ok(text) => text
          Err(err) => return err
        }
        if old_text.length() == 0 {
          Error(formula_error_value)
        } else if values.length() == 4 {
          let instance = match value_as_int(values[3]) {
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
                    let sb = StringBuilder::new()
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
          let sb = StringBuilder::new()
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
      } else {
        Error(formula_error_value)
      }
    "FIND" =>
      if values.length() == 2 || values.length() == 3 {
        let find_text = match value_as_string(values[0]) {
          Ok(text) => text
          Err(err) => return err
        }
        let within_text = match value_as_string(values[1]) {
          Ok(text) => text
          Err(err) => return err
        }
        let start_num = if values.length() == 3 {
          match value_as_int(values[2]) {
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
      } else {
        Error(formula_error_value)
      }
    "FINDB" =>
      if values.length() == 2 || values.length() == 3 {
        let find_text = match value_as_string(values[0]) {
          Ok(text) => text
          Err(err) => return err
        }
        let within_text = match value_as_string(values[1]) {
          Ok(text) => text
          Err(err) => return err
        }
        let start_num = if values.length() == 3 {
          match value_as_int(values[2]) {
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
      } else {
        Error(formula_error_value)
      }
    "SEARCH" =>
      if values.length() == 2 || values.length() == 3 {
        let find_text = match value_as_string(values[0]) {
          Ok(text) => text
          Err(err) => return err
        }
        let within_text = match value_as_string(values[1]) {
          Ok(text) => text
          Err(err) => return err
        }
        let start_num = if values.length() == 3 {
          match value_as_int(values[2]) {
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
      } else {
        Error(formula_error_value)
      }
    "SEARCHB" =>
      if values.length() == 2 || values.length() == 3 {
        let find_text = match value_as_string(values[0]) {
          Ok(text) => text
          Err(err) => return err
        }
        let within_text = match value_as_string(values[1]) {
          Ok(text) => text
          Err(err) => return err
        }
        let start_num = if values.length() == 3 {
          match value_as_int(values[2]) {
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
      } else {
        Error(formula_error_value)
      }
    "EXACT" =>
      if values.length() == 2 {
        let left = match value_as_string(values[0]) {
          Ok(text) => text
          Err(err) => return err
        }
        let right = match value_as_string(values[1]) {
          Ok(text) => text
          Err(err) => return err
        }
        Bool(left == right)
      } else {
        Error(formula_error_value)
      }
    "FIXED" =>
      if values.length() >= 1 && values.length() <= 3 {
        let number = match value_as_number(values[0]) {
          Ok(num) => num
          Err(err) => return err
        }
        let mut decimals = if values.length() == 1 {
          decimal_places_from_text(formula_value_string(values[0]))
        } else {
          match value_as_int(values[1]) {
            Ok(num) => num
            Err(err) => return err
          }
        }
        if decimals < 0 {
          decimals = 0
        }
        let no_commas = if values.length() == 3 {
          match value_as_bool(values[2]) {
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
    "VALUE" =>
      if values.length() == 1 {
        match value_as_number_text(values[0]) {
          Ok(num) => Number(num)
          Err(err) => err
        }
      } else {
        Error(formula_error_value)
      }
    "VALUETOTEXT" =>
      if values.length() == 1 || values.length() == 2 {
        let format = if values.length() == 2 {
          match value_as_int(values[1]) {
            Ok(num) => num
            Err(err) => return err
          }
        } else {
          0
        }
        if format != 0 && format != 1 {
          Error(formula_error_value)
        } else {
          let text = formula_value_string(values[0])
          match value_as_number(values[0]) {
            Ok(_) => String(text)
            Err(_) =>
              if format == 1 {
                String("\"" + text + "\"")
              } else {
                String(text)
              }
          }
        }
      } else {
        Error(formula_error_value)
      }
    "TEXT" =>
      if values.length() == 2 {
        let format_text = match value_as_string(values[1]) {
          Ok(text) => text
          Err(err) => return err
        }
        match value_as_number_text(values[0]) {
          Ok(num) =>
            String(
              format_number_code(
                format_number(num),
                format_text,
                Options::new(),
              ),
            )
          Err(err) => err
        }
      } else {
        Error(formula_error_value)
      }
    "ARRAYTOTEXT" =>
      if values.length() == 1 || values.length() == 2 {
        let format = if values.length() == 2 {
          match value_as_int(values[1]) {
            Ok(num) => num
            Err(err) => return err
          }
        } else {
          0
        }
        if format != 0 && format != 1 {
          return Error(formula_error_value)
        }
        let range = match args[0] {
          Range(_, _, _) | Cell(_, _) =>
            eval_range_expr(workbook, sheet_name, args[0], ctx)
          _ => { rows: 1, cols: 1, values: [values[0]] }
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
          let joined = if format == 1 {
            cells.join(",")
          } else {
            cells.join(", ")
          }
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
    "TEXTAFTER" | "TEXTBEFORE" | "_XLFN.TEXTAFTER" | "_XLFN.TEXTBEFORE" =>
      if values.length() >= 2 && values.length() <= 6 {
        let text = match value_as_string(values[0]) {
          Ok(value) => value
          Err(err) => return err
        }
        let delimiter = match value_as_string(values[1]) {
          Ok(value) => value
          Err(err) => return err
        }
        if text == "" {
          return Error(formula_error_na)
        }
        let instance_num = if values.length() >= 3 {
          match value_as_int(values[2]) {
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
        let match_mode = if values.length() >= 4 {
          match value_as_int(values[3]) {
            Ok(num) => num
            Err(err) => return err
          }
        } else {
          0
        }
        if match_mode != 0 && match_mode != 1 {
          return Error(formula_error_value)
        }
        let match_end = if values.length() >= 5 {
          match value_as_bool(values[4]) {
            Ok(flag) => flag
            Err(err) => return err
          }
        } else {
          false
        }
        let if_not_found = if values.length() == 6 { values[5] } else { Empty }
        let idx_opt = text_after_before_index(
          text, delimiter, instance_num, match_mode, match_end,
        )
        let idx = match idx_opt {
          Some(value) => value
          None => return if_not_found
        }
        if name == "TEXTAFTER" || name == "_XLFN.TEXTAFTER" {
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
    "TEXTSPLIT" | "_XLFN.TEXTSPLIT" =>
      if values.length() >= 2 && values.length() <= 6 {
        textsplit_values(values)
      } else {
        Error(formula_error_value)
      }
    "TEXTJOIN" =>
      if values.length() >= 3 {
        let delimiter = match value_as_string(values[0]) {
          Ok(text) => text
          Err(err) => return err
        }
        let ignore_empty = match value_as_bool(values[1]) {
          Ok(flag) => flag
          Err(err) => return err
        }
        let parts : Array[String] = []
        for i in 2..<values.length() {
          match textjoin_collect_value(values[i], ignore_empty, parts) {
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
    "SEQUENCE" | "_XLFN.SEQUENCE" => sequence_values(values)
    "TAKE" | "_XLFN.TAKE" =>
      take_values(workbook, sheet_name, args, values, ctx)
    "DROP" | "_XLFN.DROP" =>
      drop_values(workbook, sheet_name, args, values, ctx)
    "CHOOSECOLS" | "_XLFN.CHOOSECOLS" =>
      choosecols_values(workbook, sheet_name, args, values, ctx)
    "CHOOSEROWS" | "_XLFN.CHOOSEROWS" =>
      chooserows_values(workbook, sheet_name, args, values, ctx)
    "HSTACK" | "_XLFN.HSTACK" =>
      stack_from_values(workbook, sheet_name, args, values, ctx, true)
    "VSTACK" | "_XLFN.VSTACK" =>
      stack_from_values(workbook, sheet_name, args, values, ctx, false)
    "EXPAND" | "_XLFN.EXPAND" =>
      expand_values(workbook, sheet_name, args, values, ctx)
    "WRAPROWS" | "_XLFN.WRAPROWS" =>
      wrap_values(workbook, sheet_name, args, values, ctx, true)
    "WRAPCOLS" | "_XLFN.WRAPCOLS" =>
      wrap_values(workbook, sheet_name, args, values, ctx, false)
    "TOCOL" | "_XLFN.TOCOL" =>
      tocol_torow_values(workbook, sheet_name, args, values, ctx, false)
    "TOROW" | "_XLFN.TOROW" =>
      tocol_torow_values(workbook, sheet_name, args, values, ctx, false)
    "SORT" | "_XLFN.SORT" =>
      sort_values(workbook, sheet_name, args, values, ctx)
    "SORTBY" | "_XLFN.SORTBY" =>
      sortby_values(workbook, sheet_name, args, values, ctx)
    "FILTER" | "_XLFN.FILTER" =>
      filter_values(workbook, sheet_name, args, values, ctx)
    "UNIQUE" | "_XLFN.UNIQUE" =>
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
                  { rows: 1, cols: list.length(), values: list }
                }
              _ => { rows: 1, cols: 1, values: [values[0]] }
            }
        }
        match unique_range_values(range, by_col, exactly_once) {
          Ok(result) => List(result.values)
          Err(err) => err
        }
      } else {
        Error(formula_error_value)
      }
    "DATE" =>
      if values.length() == 3 {
        match
          (
            value_as_int(values[0]),
            value_as_int(values[1]),
            value_as_int(values[2]),
          ) {
          (Ok(year), Ok(month), Ok(day)) =>
            match excel_serial_from_date(year, month, day) {
              Some(serial) => Number(serial)
              None => Error(formula_error_num)
            }
          (Err(err), _, _) => err
          (_, Err(err), _) => err
          (_, _, Err(err)) => err
        }
      } else {
        Error(formula_error_value)
      }
    "TIME" =>
      if values.length() == 3 {
        match
          (
            value_as_int(values[0]),
            value_as_int(values[1]),
            value_as_int(values[2]),
          ) {
          (Ok(hours), Ok(minutes), Ok(seconds)) =>
            match excel_time_fraction(hours, minutes, seconds) {
              Some(value) => Number(value)
              None => Error(formula_error_num)
            }
          (Err(err), _, _) => err
          (_, Err(err), _) => err
          (_, _, Err(err)) => err
        }
      } else {
        Error(formula_error_value)
      }
    "DATEVALUE" =>
      if values.length() == 1 {
        let text = match value_as_string(values[0]) {
          Ok(value) => value
          Err(err) => return err
        }
        match parse_date_parts(text) {
          Some((year, month, day)) =>
            match excel_serial_from_date(year, month, day) {
              Some(serial) => Number(serial)
              None => Error(formula_error_value)
            }
          None => Error(formula_error_value)
        }
      } else {
        Error(formula_error_value)
      }
    "TIMEVALUE" =>
      if values.length() == 1 {
        let text = match value_as_string(values[0]) {
          Ok(value) => value
          Err(err) => return err
        }
        match parse_time_parts(text) {
          Some((hours, minutes, seconds)) =>
            // parse_time_parts only yields non-negative components.
            Number(excel_time_fraction(hours, minutes, seconds).unwrap())
          None => Error(formula_error_value)
        }
      } else {
        Error(formula_error_value)
      }
    "DATEDIF" =>
      if values.length() == 3 {
        let start_serial = match value_as_date_serial(values[0]) {
          Ok(value) => value
          Err(err) => return err
        }
        let end_serial = match value_as_date_serial(values[1]) {
          Ok(value) => value
          Err(err) => return err
        }
        if start_serial > end_serial {
          Error(formula_error_num)
        } else if start_serial == end_serial {
          Number(0.0)
        } else {
          let unit = match value_as_string(values[2]) {
            Ok(text) => text.to_lower()
            Err(err) => return err
          }
          // value_as_date_serial rejects negatives; serial-to-date conversion is total on non-negative serials.
          let (sy, sm, sd) = date_parts_from_serial(start_serial).unwrap()
          let (ey, em, ed) = date_parts_from_serial(end_serial).unwrap()
          match unit {
            "y" => {
              let mut diff = ey - sy
              if em < sm || (em == sm && ed < sd) {
                diff = diff - 1
              }
              Number(Double::from_int(diff))
            }
            "m" => {
              let mut diff = (ey - sy) * 12 + (em - sm)
              if ed < sd {
                diff = diff - 1
              }
              Number(Double::from_int(diff))
            }
            "d" => Number(end_serial - start_serial)
            "ym" => {
              let mut diff = em - sm
              if ed < sd {
                diff = diff - 1
              }
              if diff < 0 {
                diff = diff + 12
              }
              Number(Double::from_int(diff))
            }
            "yd" => {
              let mut target_year = sy
              if em < sm || (em == sm && ed < sd) {
                target_year = sy + 1
              }
              let start_base = excel_serial_from_date(sy, sm, sd).unwrap()
              let end_base = excel_serial_from_date(target_year, em, ed).unwrap()
              Number(end_base - start_base)
            }
            "md" => {
              let diff = if ed >= sd {
                ed - sd
              } else {
                let (prev_year, prev_month) = normalize_year_month(ey, em - 1)
                let dim = days_in_month(prev_year, prev_month)
                dim - sd + ed
              }
              Number(Double::from_int(diff))
            }
            _ => Error(formula_error_value)
          }
        }
      } else {
        Error(formula_error_value)
      }
    "DAYS" =>
      if values.length() == 2 {
        let end_serial = match value_as_date_serial(values[0]) {
          Ok(value) => value
          Err(err) => return err
        }
        let start_serial = match value_as_date_serial(values[1]) {
          Ok(value) => value
          Err(err) => return err
        }
        Number(end_serial - start_serial)
      } else {
        Error(formula_error_value)
      }
    "DAYS360" =>
      if values.length() == 2 || values.length() == 3 {
        let start_serial = match value_as_date_serial(values[0]) {
          Ok(value) => value
          Err(err) => return err
        }
        let end_serial = match value_as_date_serial(values[1]) {
          Ok(value) => value
          Err(err) => return err
        }
        let (sy, sm, sd) = date_parts_from_serial(start_serial).unwrap()
        let (ey, em, ed) = date_parts_from_serial(end_serial).unwrap()
        let mut start_day = sd
        let mut end_day = ed
        let end_year = ey
        let mut end_month = em
        let use_european = if values.length() == 3 {
          match value_as_bool(values[2]) {
            Ok(flag) => flag
            Err(err) => return err
          }
        } else {
          false
        }
        if use_european {
          if start_day == 31 {
            start_day = 30
          }
          if end_day == 31 {
            end_day = 30
          }
        } else {
          if days_in_month(sy, sm) == start_day {
            start_day = 30
          }
          if end_day > 30 {
            if start_day < 30 {
              end_month = end_month + 1
              end_day = 1
            } else {
              end_day = 30
            }
          }
        }
        let (norm_year, norm_month) = normalize_year_month(end_year, end_month)
        let diff = (norm_year - sy) * 360 +
          (norm_month - sm) * 30 +
          (end_day - start_day)
        Number(Double::from_int(diff))
      } else {
        Error(formula_error_value)
      }
    "ISOWEEKNUM" =>
      if values.length() == 1 {
        let (year, month, day) = match date_parts_from_value(values[0]) {
          Ok(parts) => parts
          Err(err) => return err
        }
        match iso_week_number(year, month, day) {
          Some(week) => Number(Double::from_int(week))
          None => Error(formula_error_num)
        }
      } else {
        Error(formula_error_value)
      }
    "EDATE" =>
      if values.length() == 2 {
        let (year, month, day) = match date_parts_from_value(values[0]) {
          Ok(parts) => parts
          Err(err) => return err
        }
        let months = match value_as_number(values[1]) {
          Ok(num) => Double::to_int(trunc_double(num))
          Err(err) => return err
        }
        let (new_year, new_month) = normalize_year_month(year, month + months)
        let max_day = days_in_month(new_year, new_month)
        let new_day = if day > max_day { max_day } else { day }
        match excel_serial_from_date(new_year, new_month, new_day) {
          Some(serial) => Number(serial)
          None => Error(formula_error_num)
        }
      } else {
        Error(formula_error_value)
      }
    "EOMONTH" =>
      if values.length() == 2 {
        let (year, month, _) = match date_parts_from_value(values[0]) {
          Ok(parts) => parts
          Err(err) => return err
        }
        let months = match value_as_number(values[1]) {
          Ok(num) => Double::to_int(trunc_double(num))
          Err(err) => return err
        }
        let (new_year, new_month) = normalize_year_month(year, month + months)
        let new_day = days_in_month(new_year, new_month)
        match excel_serial_from_date(new_year, new_month, new_day) {
          Some(serial) => Number(serial)
          None => Error(formula_error_num)
        }
      } else {
        Error(formula_error_value)
      }
    "YEARFRAC" =>
      if values.length() == 2 || values.length() == 3 {
        let start_serial = match value_as_date_serial(values[0]) {
          Ok(value) => value
          Err(err) => return err
        }
        let end_serial = match value_as_date_serial(values[1]) {
          Ok(value) => value
          Err(err) => return err
        }
        let basis = if values.length() == 3 {
          match value_as_number(values[2]) {
            Ok(num) => Double::to_int(trunc_double(num))
            Err(err) => return err
          }
        } else {
          0
        }
        yearfrac_value(start_serial, end_serial, basis)
      } else {
        Error(formula_error_value)
      }
    "WEEKDAY" =>
      if values.length() == 1 || values.length() == 2 {
        let (year, month, day) = match date_parts_from_value(values[0]) {
          Ok(parts) => parts
          Err(err) => return err
        }
        let mut return_type = 1
        if values.length() == 2 {
          return_type = match value_as_number(values[1]) {
            Ok(num) => Double::to_int(trunc_double(num))
            Err(err) => return err
          }
        }
        if return_type == 2 {
          return_type = 11
        }
        let weekday = weekday_sun1(year, month, day)
        if return_type == 1 {
          Number(Double::from_int(weekday))
        } else if return_type == 3 {
          let value = (weekday + 6 - 1) % 7
          Number(Double::from_int(value))
        } else if return_type >= 11 && return_type <= 17 {
          let value = (weekday + 6 - (return_type - 10)) % 7 + 1
          Number(Double::from_int(value))
        } else {
          Error(formula_error_value)
        }
      } else {
        Error(formula_error_value)
      }
    "WEEKNUM" =>
      if values.length() == 1 || values.length() == 2 {
        let (year, month, day) = match date_parts_from_value(values[0]) {
          Ok(parts) => parts
          Err(err) => return err
        }
        let mut return_type = 1
        if values.length() == 2 {
          return_type = match value_as_number(values[1]) {
            Ok(num) => Double::to_int(trunc_double(num))
            Err(err) => return err
          }
        }
        let days = day_of_year(year, month, day)
        let mut week_mod = days % 7
        if week_mod == 0 {
          week_mod = 7
        }
        let mut week_num = (days + 6) / 7
        let first_weekday = weekday_sun1(year, 1, 1) - 1
        let offset = match return_type {
          1 | 17 => 0
          2 | 11 | 21 => 1
          12 | 13 | 14 | 15 | 16 => return_type - 10
          _ => return Error(formula_error_num)
        }
        let mut padding = offset + 7 - first_weekday
        if padding > 7 {
          padding = padding - 7
        }
        if week_mod > padding {
          week_num = week_num + 1
        }
        if return_type == 21 && (first_weekday == 0 || first_weekday > 4) {
          week_num = week_num - 1
          if week_num < 1 {
            week_num = 52
            let prev_first_weekday = weekday_sun1(year - 1, 1, 1) - 1
            if prev_first_weekday < 4 {
              week_num = week_num + 1
            }
          }
        }
        Number(Double::from_int(week_num))
      } else {
        Error(formula_error_value)
      }
    "NETWORKDAYS" =>
      if values.length() == 2 || values.length() == 3 {
        let start_serial = match value_as_date_serial(values[0]) {
          Ok(value) => value
          Err(err) => return err
        }
        let end_serial = match value_as_date_serial(values[1]) {
          Ok(value) => value
          Err(err) => return err
        }
        let holidays = if values.length() == 3 {
          collect_holidays(values[2])
        } else {
          []
        }
        networkdays_intl_value(start_serial, end_serial, Number(1.0), holidays)
      } else {
        Error(formula_error_value)
      }
    "NETWORKDAYS.INTL" =>
      if values.length() >= 2 && values.length() <= 4 {
        let start_serial = match value_as_date_serial(values[0]) {
          Ok(value) => value
          Err(err) => return err
        }
        let end_serial = match value_as_date_serial(values[1]) {
          Ok(value) => value
          Err(err) => return err
        }
        let weekend_value = if values.length() >= 3 {
          values[2]
        } else {
          Number(1.0)
        }
        let holidays = if values.length() == 4 {
          collect_holidays(values[3])
        } else {
          []
        }
        networkdays_intl_value(
          start_serial, end_serial, weekend_value, holidays,
        )
      } else {
        Error(formula_error_value)
      }
    "WORKDAY" =>
      if values.length() == 2 || values.length() == 3 {
        let start_serial = match value_as_date_serial(values[0]) {
          Ok(value) => value
          Err(err) => return err
        }
        let days = match value_as_number(values[1]) {
          Ok(num) => num
          Err(err) => return err
        }
        let holidays = if values.length() == 3 {
          collect_holidays(values[2])
        } else {
          []
        }
        workday_intl_value(start_serial, days, Number(1.0), holidays)
      } else {
        Error(formula_error_value)
      }
    "WORKDAY.INTL" =>
      if values.length() >= 2 && values.length() <= 4 {
        let start_serial = match value_as_date_serial(values[0]) {
          Ok(value) => value
          Err(err) => return err
        }
        let days = match value_as_number(values[1]) {
          Ok(num) => num
          Err(err) => return err
        }
        let weekend_value = if values.length() >= 3 {
          values[2]
        } else {
          Number(1.0)
        }
        let holidays = if values.length() == 4 {
          collect_holidays(values[3])
        } else {
          []
        }
        workday_intl_value(start_serial, days, weekend_value, holidays)
      } else {
        Error(formula_error_value)
      }
    "NOW" =>
      if values.length() == 0 {
        let now_ms = @env.now()
        let total_seconds = UInt64::to_double(now_ms) / 1000.0
        let days = Double::floor(total_seconds / 86400.0)
        let seconds_in_day = total_seconds - days * 86400.0
        let serial = days + 25569.0 + seconds_in_day / 86400.0
        Number(serial)
      } else {
        Error(formula_error_value)
      }
    "TODAY" =>
      if values.length() == 0 {
        let now_ms = @env.now()
        let total_seconds = UInt64::to_double(now_ms) / 1000.0
        let days = Double::floor(total_seconds / 86400.0)
        Number(days + 25569.0)
      } else {
        Error(formula_error_value)
      }
    "YEAR" =>
      if values.length() == 1 {
        match excel_serial_parts(values[0]) {
          Ok((year, _, _, _, _, _)) => Number(Double::from_int(year))
          Err(err) => err
        }
      } else {
        Error(formula_error_value)
      }
    "MONTH" =>
      if values.length() == 1 {
        match excel_serial_parts(values[0]) {
          Ok((_, month, _, _, _, _)) => Number(Double::from_int(month))
          Err(err) => err
        }
      } else {
        Error(formula_error_value)
      }
    "DAY" =>
      if values.length() == 1 {
        match excel_serial_parts(values[0]) {
          Ok((_, _, day, _, _, _)) => Number(Double::from_int(day))
          Err(err) => err
        }
      } else {
        Error(formula_error_value)
      }
    "HOUR" =>
      if values.length() == 1 {
        match excel_serial_parts(values[0]) {
          Ok((_, _, _, hour, _, _)) => Number(Double::from_int(hour))
          Err(err) => err
        }
      } else {
        Error(formula_error_value)
      }
    "MINUTE" =>
      if values.length() == 1 {
        match excel_serial_parts(values[0]) {
          Ok((_, _, _, _, minute, _)) => Number(Double::from_int(minute))
          Err(err) => err
        }
      } else {
        Error(formula_error_value)
      }
    "SECOND" =>
      if values.length() == 1 {
        match excel_serial_parts(values[0]) {
          Ok((_, _, _, _, _, second)) => Number(Double::from_int(second))
          Err(err) => err
        }
      } else {
        Error(formula_error_value)
      }
    "INDEX" =>
      if args.length() == 2 || args.length() == 3 {
        let range = eval_range_expr(workbook, sheet_name, args[0], ctx)
        let row_num = match value_as_int(values[1]) {
          Ok(num) => num
          Err(err) => return err
        }
        let col_num = if args.length() == 3 {
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
      } else {
        Error(formula_error_value)
      }
    "MATCH" =>
      if args.length() == 2 || args.length() == 3 {
        let lookup = values[0]
        let range = eval_range_expr(workbook, sheet_name, args[1], ctx)
        let match_type = if args.length() == 3 {
          match value_as_int(values[2]) {
            Ok(num) => num
            Err(err) => return err
          }
        } else {
          1
        }
        match_range_value(lookup, range, match_type)
      } else {
        Error(formula_error_value)
      }
    "VLOOKUP" =>
      if args.length() == 3 || args.length() == 4 {
        let lookup = values[0]
        let table = eval_range_expr(workbook, sheet_name, args[1], ctx)
        let col_index = match value_as_int(values[2]) {
          Ok(num) => num
          Err(err) => return err
        }
        let range_lookup = if args.length() == 4 {
          match lookup_range_flag(values[3]) {
            Ok(flag) => flag
            Err(err) => return err
          }
        } else {
          true
        }
        vlookup_value(lookup, table, col_index, range_lookup)
      } else {
        Error(formula_error_value)
      }
    "HLOOKUP" =>
      if args.length() == 3 || args.length() == 4 {
        let lookup = values[0]
        let table = eval_range_expr(workbook, sheet_name, args[1], ctx)
        let row_index = match value_as_int(values[2]) {
          Ok(num) => num
          Err(err) => return err
        }
        let range_lookup = if args.length() == 4 {
          match lookup_range_flag(values[3]) {
            Ok(flag) => flag
            Err(err) => return err
          }
        } else {
          true
        }
        hlookup_value(lookup, table, row_index, range_lookup)
      } else {
        Error(formula_error_value)
      }
    "LOOKUP" =>
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
    "XLOOKUP" | "_XLFN.XLOOKUP" =>
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
        if match_mode != -1 &&
          match_mode != 0 &&
          match_mode != 1 &&
          match_mode != 2 {
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
    "ANCHORARRAY" | "_XLFN.ANCHORARRAY" =>
      anchorarray_values(workbook, sheet_name, args, values)
    "ADDRESS" =>
      if values.length() >= 2 && values.length() <= 5 {
        let row_num = match value_as_int(values[0]) {
          Ok(num) => num
          Err(err) => return err
        }
        let col_num = match value_as_int(values[1]) {
          Ok(num) => num
          Err(err) => return err
        }
        if row_num <= 0 || col_num <= 0 {
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
    "INDIRECT" =>
      if values.length() == 1 || values.length() == 2 {
        let ref_text = match value_as_string(values[0]) {
          Ok(text) => text
          Err(err) => return err
        }
        let a1 = if values.length() == 2 {
          match value_as_bool(values[1]) {
            Ok(flag) => flag
            Err(err) => return err
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
      } else {
        Error(formula_error_value)
      }
    "CHAR" =>
      if values.length() == 1 {
        match value_as_number(values[0]) {
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
      } else {
        Error(formula_error_value)
      }
    "UNICHAR" =>
      if values.length() == 1 {
        match value_as_number(values[0]) {
          Ok(num) =>
            if num <= 0.0 || num > 55295.0 {
              Error(formula_error_value)
            } else {
              let code = Double::to_int(trunc_double(num))
              String(char_from_code(code))
            }
          Err(err) => err
        }
      } else {
        Error(formula_error_value)
      }
    "CLEAN" =>
      if values.length() == 1 {
        clean_text_value(values[0])
      } else {
        Error(formula_error_value)
      }
    "ENCODEURL" =>
      if values.length() == 1 {
        encode_url_value(values[0])
      } else {
        Error(formula_error_value)
      }
    "BAHTTEXT" =>
      if values.length() == 1 {
        bahttext_values(values)
      } else {
        Error(formula_error_value)
      }
    "CODE" =>
      if values.length() == 1 {
        code_value("CODE", values[0])
      } else {
        Error(formula_error_value)
      }
    "UNICODE" =>
      if values.length() == 1 {
        code_value("UNICODE", values[0])
      } else {
        Error(formula_error_value)
      }
    "HYPERLINK" =>
      if values.length() == 1 || values.length() == 2 {
        match value_as_string(values[values.length() - 1]) {
          Ok(text) => String(text)
          Err(err) => err
        }
      } else {
        Error(formula_error_value)
      }
    "DISPIMG" | "_XLFN.DISPIMG" =>
      if values.length() == 2 {
        values[0]
      } else {
        Error(formula_error_value)
      }
    "CHOOSE" =>
      if values.length() >= 2 {
        let index_text = match value_as_string(values[0]) {
          Ok(text) => text
          Err(err) => return err
        }
        let idx = @strconv.parse_int(index_text, base=10) catch {
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
    "CONCAT" | "CONCATENATE" => concat_values(values)
    "IF" =>
      if values.length() == 0 || values.length() > 3 {
        Error(formula_error_value)
      } else {
        match value_as_bool(values[0]) {
          Ok(cond) =>
            if values.length() == 1 {
              Bool(cond)
            } else if cond {
              values[1]
            } else if values.length() >= 3 {
              values[2]
            } else {
              Bool(false)
            }
          Err(err) => err
        }
      }
    "IFERROR" =>
      if values.length() == 2 {
        match normalize_scalar(values[0]) {
          Error(_) => values[1]
          Empty => Number(0.0)
          _ => values[0]
        }
      } else {
        Error(formula_error_value)
      }
    "IFNA" =>
      if values.length() == 2 {
        match normalize_scalar(values[0]) {
          Error(err) =>
            if err == formula_error_na {
              values[1]
            } else {
              values[0]
            }
          _ => values[0]
        }
      } else {
        Error(formula_error_value)
      }
    "IFS" =>
      if values.length() < 2 || values.length() % 2 != 0 {
        Error(formula_error_value)
      } else {
        for i in 0..<(values.length() / 2) {
          match value_as_bool(values[i * 2]) {
            Ok(flag) => if flag { return values[i * 2 + 1] }
            Err(err) => return err
          }
        }
        Error(formula_error_na)
      }
    "SWITCH" =>
      if values.length() < 3 {
        Error(formula_error_value)
      } else {
        let target = values[0]
        let arg_count = values.length() - 1
        let switch_count = arg_count / 2
        let has_default = arg_count % 2 != 0
        let mut result = if has_default {
          values[values.length() - 1]
        } else {
          Error(formula_error_na)
        }
        for i in 0..<switch_count {
          let match_value = values[1 + i * 2]
          match compare_values(target, match_value) {
            Ok(0) => {
              result = values[1 + i * 2 + 1]
              break
            }
            Ok(_) => ()
            Err(err) => return err
          }
        }
        result
      }
    "ISBLANK" =>
      if values.length() == 1 {
        match normalize_scalar(values[0]) {
          Empty => Bool(true)
          _ => Bool(false)
        }
      } else {
        Error(formula_error_value)
      }
    "ISERR" =>
      if values.length() == 1 {
        match normalize_scalar(values[0]) {
          Error(err) =>
            Bool(is_known_error_code(err) && err != formula_error_na)
          _ => Bool(false)
        }
      } else {
        Error(formula_error_value)
      }
    "ISEVEN" =>
      if values.length() == 1 {
        match normalize_scalar(values[0]) {
          Empty => Bool(true)
          _ =>
            match value_as_number(values[0]) {
              Ok(num) => {
                let even = if num == 1.0 {
                  false
                } else {
                  num == num / 2.0 * 2.0
                }
                Bool(even)
              }
              Err(err) => err
            }
        }
      } else {
        Error(formula_error_value)
      }
    "ISODD" =>
      if values.length() == 1 {
        match value_as_number(values[0]) {
          Ok(num) => {
            let n = Double::to_int(num)
            Bool(n != n / 2 * 2)
          }
          Err(err) => err
        }
      } else {
        Error(formula_error_value)
      }
    "ISERROR" =>
      if values.length() == 1 {
        match normalize_scalar(values[0]) {
          Error(err) => Bool(is_known_error_code(err))
          _ => Bool(false)
        }
      } else {
        Error(formula_error_value)
      }
    "ISLOGICAL" =>
      if values.length() == 1 {
        match normalize_scalar(values[0]) {
          Bool(_) => Bool(true)
          String(text) => Bool(text == "TRUE" || text == "FALSE")
          _ => Bool(false)
        }
      } else {
        Error(formula_error_value)
      }
    "ISNA" =>
      if values.length() == 1 {
        match normalize_scalar(values[0]) {
          Error(err) => Bool(err == formula_error_na)
          _ => Bool(false)
        }
      } else {
        Error(formula_error_value)
      }
    "ISNUMBER" =>
      if values.length() == 1 {
        match normalize_scalar(values[0]) {
          Number(_) => Bool(true)
          _ => Bool(false)
        }
      } else {
        Error(formula_error_value)
      }
    "ISTEXT" =>
      if values.length() == 1 {
        match normalize_scalar(values[0]) {
          String(text) =>
            match parse_double_opt(text) {
              Some(_) => Bool(false)
              None => Bool(true)
            }
          _ => Bool(false)
        }
      } else {
        Error(formula_error_value)
      }
    "ISNONTEXT" =>
      if values.length() == 1 {
        match normalize_scalar(values[0]) {
          String(_) => Bool(false)
          _ => Bool(true)
        }
      } else {
        Error(formula_error_value)
      }
    "ISREF" =>
      if args.length() == 1 {
        Bool(is_ref_expr(args[0]))
      } else {
        Error(formula_error_value)
      }
    "ISFORMULA" =>
      if args.length() == 1 {
        match args[0] {
          Cell(sheet, reference) => {
            let target_sheet = if sheet == "" { sheet_name } else { sheet }
            Bool(cell_has_formula(workbook, target_sheet, reference))
          }
          _ => Bool(false)
        }
      } else {
        Error(formula_error_value)
      }
    "ERRORdotTYPE" | "ERROR.TYPE" =>
      if values.length() == 1 {
        error_type_value(values[0])
      } else {
        Error(formula_error_value)
      }
    "SHEET" =>
      if args.length() == 0 {
        match sheet_index_opt(workbook, sheet_name) {
          Some(index) => Number(Double::from_int(index + 1))
          None => Error(formula_error_na)
        }
      } else if args.length() == 1 {
        let target_sheet = match args[0] {
          Cell(sheet, _) => if sheet == "" { sheet_name } else { sheet }
          Range(sheet, _, _) => if sheet == "" { sheet_name } else { sheet }
          _ => formula_value_string(values[0])
        }
        match sheet_index_opt(workbook, target_sheet) {
          Some(index) => Number(Double::from_int(index + 1))
          None => Error(formula_error_na)
        }
      } else {
        Error(formula_error_value)
      }
    "SHEETS" =>
      if args.length() == 0 {
        Number(Double::from_int(workbook.sheets().length()))
      } else if args.length() == 1 {
        match args[0] {
          Cell(_, _) | Range(_, _, _) => Number(1.0)
          _ => Error(formula_error_na)
        }
      } else {
        Error(formula_error_value)
      }
    "TYPE" =>
      if values.length() == 1 {
        type_value(values[0])
      } else {
        Error(formula_error_value)
      }
    "T" =>
      if values.length() == 1 {
        match normalize_scalar(values[0]) {
          Error(err) => Error(err)
          Number(_) | Empty | List(_) => String("")
          String(text) => String(text)
          Bool(flag) => String(if flag { "TRUE" } else { "FALSE" })
        }
      } else {
        Error(formula_error_value)
      }
    "NA" =>
      if values.length() == 0 {
        Error(formula_error_na)
      } else {
        Error(formula_error_value)
      }
    "N" =>
      if values.length() == 1 {
        match normalize_scalar(values[0]) {
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
      } else {
        Error(formula_error_value)
      }
    _ =>
      if args.length() == 0 {
        match defined_name_value(workbook, sheet_name, name, ctx) {
          Some(value) => value
          None => Error(formula_error_name)
        }
      } else {
        Error(formula_error_name)
      }
  }
}

///|
fn range_column_required(
  range : RangeValues,
  index : Int,
) -> Array[FormulaValue] {
  range_column(range, index).unwrap_or([])
}

///|
fn range_row_required(range : RangeValues, index : Int) -> Array[FormulaValue] {
  range_row(range, index).unwrap_or([])
}

///|
fn sum_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  let mut sum = 0.0
  for value in flatten_values(values) {
    match normalize_scalar(value) {
      Error(err) => return Error(err)
      Number(num) => sum = sum + num
      Bool(flag) => {
        let num = if flag { 1.0 } else { 0.0 }
        sum = sum + num
      }
      String(text) =>
        match parse_double_opt(text) {
          Some(num) => sum = sum + num
          None => ()
        }
      Empty | List(_) => ()
    }
  }
  Number(sum)
}

///|
fn sumsq_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  let mut sum = 0.0
  for value in values {
    match value {
      List(list) =>
        for cell in list {
          match cell {
            Number(num) => sum = sum + num * num
            String(text) =>
              if text == "" {
                ()
              } else {
                match parse_double_opt(text) {
                  Some(num) => sum = sum + num * num
                  None => return Error(formula_error_value)
                }
              }
            Bool(_) => return Error(formula_error_value)
            Error(_) => return Error(formula_error_value)
            Empty => ()
            List(_) => ()
          }
        }
      _ =>
        match normalize_scalar(value) {
          Number(num) => sum = sum + num * num
          Bool(flag) => {
            let num = if flag { 1.0 } else { 0.0 }
            sum = sum + num * num
          }
          String(text) =>
            if text == "" {
              ()
            } else {
              match parse_double_opt(text) {
                Some(num) => sum = sum + num * num
                None => return Error(formula_error_value)
              }
            }
          Error(_) | Empty | List(_) => ()
        }
    }
  }
  Number(sum)
}

///|
fn gcd_lcm_collect(
  value : FormulaValue,
  numbers : Array[Double],
  allow_empty_string : Bool,
) -> Result[Unit, FormulaValue] {
  match value {
    List(list) => {
      for item in list {
        match gcd_lcm_collect(item, numbers, allow_empty_string) {
          Ok(_) => ()
          Err(err) => return Err(err)
        }
      }
      Ok(())
    }
    Error(err) => Err(Error(err))
    Number(num) => {
      numbers.push(num)
      Ok(())
    }
    Bool(flag) => {
      numbers.push(if flag { 1.0 } else { 0.0 })
      Ok(())
    }
    String(text) =>
      if text == "" {
        if allow_empty_string {
          Ok(())
        } else {
          Err(Error(formula_error_value))
        }
      } else {
        match parse_double_opt(text) {
          Some(num) => {
            numbers.push(num)
            Ok(())
          }
          None => Err(Error(formula_error_value))
        }
      }
    Empty => {
      numbers.push(0.0)
      Ok(())
    }
  }
}

///|
fn gcd_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() == 0 {
    return Error(formula_error_value)
  }
  let numbers : Array[Double] = []
  for value in values {
    match gcd_lcm_collect(value, numbers, false) {
      Ok(_) => ()
      Err(err) => return err
    }
  }
  if numbers.length() == 0 {
    return Error(formula_error_value)
  }
  if numbers[0] < 0.0 {
    return Error(formula_error_value)
  }
  if numbers.length() == 1 {
    return Number(numbers[0])
  }
  let mut result = numbers[0]
  for i in 1..<numbers.length() {
    if numbers[i] < 0.0 {
      return Error(formula_error_value)
    }
    result = gcd_double(result, numbers[i])
  }
  Number(result)
}

///|
fn lcm_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() == 0 {
    return Error(formula_error_value)
  }
  let numbers : Array[Double] = []
  for value in values {
    match gcd_lcm_collect(value, numbers, true) {
      Ok(_) => ()
      Err(err) => return err
    }
  }
  if numbers.length() == 0 {
    return Error(formula_error_value)
  }
  if numbers[0] < 0.0 {
    return Error(formula_error_value)
  }
  if numbers.length() == 1 {
    return Number(numbers[0])
  }
  let mut result = numbers[0]
  for i in 1..<numbers.length() {
    if numbers[i] < 0.0 {
      return Error(formula_error_value)
    }
    result = lcm_double(result, numbers[i])
  }
  Number(result)
}

///|
let roman_table : Array[Array[RomanNumeral]] = [
  [
    { n: 1000.0, s: "M" },
    { n: 900.0, s: "CM" },
    { n: 500.0, s: "D" },
    { n: 400.0, s: "CD" },
    { n: 100.0, s: "C" },
    { n: 90.0, s: "XC" },
    { n: 50.0, s: "L" },
    { n: 40.0, s: "XL" },
    { n: 10.0, s: "X" },
    { n: 9.0, s: "IX" },
    { n: 5.0, s: "V" },
    { n: 4.0, s: "IV" },
    { n: 1.0, s: "I" },
  ],
  [
    { n: 1000.0, s: "M" },
    { n: 950.0, s: "LM" },
    { n: 900.0, s: "CM" },
    { n: 500.0, s: "D" },
    { n: 450.0, s: "LD" },
    { n: 400.0, s: "CD" },
    { n: 100.0, s: "C" },
    { n: 95.0, s: "VC" },
    { n: 90.0, s: "XC" },
    { n: 50.0, s: "L" },
    { n: 45.0, s: "VL" },
    { n: 40.0, s: "XL" },
    { n: 10.0, s: "X" },
    { n: 9.0, s: "IX" },
    { n: 5.0, s: "V" },
    { n: 4.0, s: "IV" },
    { n: 1.0, s: "I" },
  ],
  [
    { n: 1000.0, s: "M" },
    { n: 990.0, s: "XM" },
    { n: 950.0, s: "LM" },
    { n: 900.0, s: "CM" },
    { n: 500.0, s: "D" },
    { n: 490.0, s: "XD" },
    { n: 450.0, s: "LD" },
    { n: 400.0, s: "CD" },
    { n: 100.0, s: "C" },
    { n: 99.0, s: "IC" },
    { n: 90.0, s: "XC" },
    { n: 50.0, s: "L" },
    { n: 45.0, s: "VL" },
    { n: 40.0, s: "XL" },
    { n: 10.0, s: "X" },
    { n: 9.0, s: "IX" },
    { n: 5.0, s: "V" },
    { n: 4.0, s: "IV" },
    { n: 1.0, s: "I" },
  ],
  [
    { n: 1000.0, s: "M" },
    { n: 995.0, s: "VM" },
    { n: 990.0, s: "XM" },
    { n: 950.0, s: "LM" },
    { n: 900.0, s: "CM" },
    { n: 500.0, s: "D" },
    { n: 495.0, s: "VD" },
    { n: 490.0, s: "XD" },
    { n: 450.0, s: "LD" },
    { n: 400.0, s: "CD" },
    { n: 100.0, s: "C" },
    { n: 99.0, s: "IC" },
    { n: 90.0, s: "XC" },
    { n: 50.0, s: "L" },
    { n: 45.0, s: "VL" },
    { n: 40.0, s: "XL" },
    { n: 10.0, s: "X" },
    { n: 9.0, s: "IX" },
    { n: 5.0, s: "V" },
    { n: 4.0, s: "IV" },
    { n: 1.0, s: "I" },
  ],
  [
    { n: 1000.0, s: "M" },
    { n: 999.0, s: "IM" },
    { n: 995.0, s: "VM" },
    { n: 990.0, s: "XM" },
    { n: 950.0, s: "LM" },
    { n: 900.0, s: "CM" },
    { n: 500.0, s: "D" },
    { n: 499.0, s: "ID" },
    { n: 495.0, s: "VD" },
    { n: 490.0, s: "XD" },
    { n: 450.0, s: "LD" },
    { n: 400.0, s: "CD" },
    { n: 100.0, s: "C" },
    { n: 99.0, s: "IC" },
    { n: 90.0, s: "XC" },
    { n: 50.0, s: "L" },
    { n: 45.0, s: "VL" },
    { n: 40.0, s: "XL" },
    { n: 10.0, s: "X" },
    { n: 9.0, s: "IX" },
    { n: 5.0, s: "V" },
    { n: 4.0, s: "IV" },
    { n: 1.0, s: "I" },
  ],
]

///|
fn roman_string(value : Double, form : Int) -> String {
  let table = roman_table[form]
  let sb = StringBuilder::new()
  let mut remaining = trunc_double(value)
  for numeral in table {
    while remaining >= numeral.n {
      sb.write_view(numeral.s)
      remaining = remaining - numeral.n
    }
  }
  sb.to_string()
}

///|
let bitwise_max_value : Double = @math.pow(2.0, 48.0) - 1.0

///|
fn bitwise_number(value : FormulaValue) -> Result[Double, FormulaValue] {
  match value {
    List(list) =>
      if list.length() == 0 {
        Ok(0.0)
      } else {
        bitwise_number(list[0])
      }
    Number(num) => Ok(num)
    Bool(flag) => Ok(if flag { 1.0 } else { 0.0 })
    Empty => Ok(0.0)
    String(text) =>
      match parse_double_opt(text) {
        Some(num) => Ok(num)
        None => Err(Error(formula_error_num))
      }
    Error(err) => Err(Error(err))
  }
}

///|
fn bitwise_values(
  name : String,
  values : ArrayView[FormulaValue],
) -> FormulaValue {
  if values.length() != 2 {
    return Error(formula_error_value)
  }
  match (bitwise_number(values[0]), bitwise_number(values[1])) {
    (Ok(num1), Ok(num2)) =>
      if num1 < 0.0 ||
        num1 > bitwise_max_value ||
        num2 < 0.0 ||
        num2 > bitwise_max_value {
        Error(formula_error_num)
      } else {
        let a = Double::to_int(trunc_double(num1))
        let b = Double::to_int(trunc_double(num2))
        let result = match name {
          "BITAND" => Int::land(a, b)
          "BITOR" => Int::lor(a, b)
          "BITXOR" => Int::lxor(a, b)
          "BITLSHIFT" => a << b
          "BITRSHIFT" => a >> b
          _ => 0
        }
        Number(Double::from_int(result))
      }
    (Err(err), _) => err
    (_, Err(err)) => err
  }
}

///|
fn arabic_char_value(ch : Char) -> Int {
  match ch {
    'I' => 1
    'V' => 5
    'X' => 10
    'L' => 50
    'C' => 100
    'D' => 500
    'M' => 1000
    _ => 0
  }
}

///|
fn arabic_string_value(text : String) -> FormulaValue {
  if count_utf16_units(text) > 255 {
    return Error(formula_error_value)
  }
  let upper = text.to_upper()
  let chars = upper.to_array()
  if chars.length() == 0 {
    return Number(0.0)
  }
  let mut index = chars.length() - 1
  let mut actual_start = 0
  while index >= 0 && chars[index] == ' ' {
    index = index - 1
  }
  while actual_start <= index && chars[actual_start] == ' ' {
    actual_start = actual_start + 1
  }
  let mut is_negative = false
  if actual_start <= index && chars[actual_start] == '-' {
    is_negative = true
    actual_start = actual_start + 1
  }
  if actual_start > index {
    return Number(0.0)
  }
  let mut number = 0
  let mut subtract_number = 0
  let mut prev_char_value = -1
  while index >= actual_start {
    let start_index = index
    let start_char = chars[start_index]
    index = index - 1
    while index >= actual_start && chars[index] == start_char {
      index = index - 1
    }
    let current_char_value = arabic_char_value(start_char)
    let current_part_value = (start_index - index) * current_char_value
    if current_char_value >= prev_char_value {
      number = number + current_part_value - subtract_number
      prev_char_value = current_char_value
      subtract_number = 0
    } else {
      subtract_number = subtract_number + current_part_value
    }
  }
  if subtract_number != 0 {
    number = number - subtract_number
  }
  if is_negative {
    number = -number
  }
  Number(Double::from_int(number))
}

///|
fn base_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() < 2 {
    return Error(formula_error_value)
  }
  if values.length() > 3 {
    return Error(formula_error_value)
  }
  let number = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let radix = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  let base = Double::to_int(trunc_double(radix))
  if base < 2 || base > 36 {
    return Error(formula_error_value)
  }
  let mut min_length = 0
  if values.length() == 3 {
    match value_as_string(values[2]) {
      Ok(text) =>
        min_length = @strconv.parse_int(text, base=10) catch {
          _ => return Error(formula_error_value)
        }
      Err(err) => return err
    }
  }
  let number_int = Double::to_int(trunc_double(number))
  let mut text = Int::to_string(number_int, radix=base).to_upper()
  if min_length > text.length() {
    let pad = "0".repeat(min_length - text.length())
    text = pad + text
  }
  String(text)
}

///|
fn dec2x_limits(name : String) -> (Double, Double, Int) {
  match name {
    "DEC2BIN" | "HEX2BIN" | "OCT2BIN" => (511.0, -512.0, 2)
    "BIN2HEX" | "DEC2HEX" | "OCT2HEX" => (549755813887.0, -549755813888.0, 16)
    "BIN2OCT" | "DEC2OCT" | "HEX2OCT" => (536870911.0, -536870912.0, 8)
    _ => (0.0, 0.0, 10)
  }
}

///|
fn dec2x_values(
  name : String,
  values : ArrayView[FormulaValue],
) -> FormulaValue {
  if values.length() < 1 {
    return Error(formula_error_value)
  }
  if values.length() > 2 {
    return Error(formula_error_value)
  }
  let decimal = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let (max_limit, min_limit, base) = dec2x_limits(name)
  if decimal < min_limit || decimal > max_limit {
    return Error(formula_error_num)
  }
  let decimal_int = Double::to_int64(trunc_double(decimal))
  let raw = Int64::reinterpret_as_uint64(decimal_int)
  let mut digits = UInt64::to_string(raw, radix=base)
  if values.length() == 2 {
    let places_num = match value_as_number(values[1]) {
      Ok(num) => num
      Err(err) => return err
    }
    if places_num < 0.0 || places_num > 10.0 {
      return Error(formula_error_num)
    }
    let places = Double::to_int(trunc_double(places_num))
    if digits.length() > places {
      return Error(formula_error_num)
    }
    let pad = "0".repeat(places - digits.length())
    digits = pad + digits
    return String(digits.to_upper())
  }
  if decimal < 0.0 && digits.length() > 10 {
    let chars = digits.to_array()
    let start = chars.length() - 10
    let sb = StringBuilder::new()
    for i in start..<chars.length() {
      sb.write_char(chars[i])
    }
    return String(sb.to_string().to_upper())
  }
  String(digits.to_upper())
}

///|
fn bin2dec_string(text : String) -> FormulaValue {
  let chars = text.to_array()
  let mut decimal = 0.0
  let length = chars.length()
  for i in 1..<=length {
    let idx = length - i
    let ch = chars[idx]
    if i == 10 && ch == '1' {
      decimal = decimal + @math.pow(-2.0, Double::from_int(i - 1))
      continue
    }
    if ch == '1' {
      decimal = decimal + @math.pow(2.0, Double::from_int(i - 1))
      continue
    }
    if ch != '0' {
      return Error(formula_error_num)
    }
  }
  Number(decimal)
}

///|
fn hex_digit_value(ch : Char) -> Int? {
  if ch >= '0' && ch <= '9' {
    Some(ch.to_int() - '0'.to_int())
  } else if ch >= 'A' && ch <= 'F' {
    Some(ch.to_int() - 'A'.to_int() + 10)
  } else if ch >= 'a' && ch <= 'f' {
    Some(ch.to_int() - 'a'.to_int() + 10)
  } else {
    None
  }
}

///|
fn hex2dec_string(text : String) -> FormulaValue {
  let chars = text.to_array()
  let mut decimal = 0.0
  let length = chars.length()
  for i in 1..<=length {
    let idx = length - i
    let ch = chars[idx]
    match hex_digit_value(ch) {
      Some(value) => {
        if i == 10 && ch == 'F' {
          decimal = decimal + @math.pow(-16.0, Double::from_int(i - 1))
          continue
        }
        decimal = decimal +
          Double::from_int(value) * @math.pow(16.0, Double::from_int(i - 1))
      }
      None => return Error(formula_error_num)
    }
  }
  Number(decimal)
}

///|
fn oct2dec_string(text : String) -> FormulaValue {
  let chars = text.to_array()
  let mut decimal = 0.0
  let length = chars.length()
  for i in 1..<=length {
    let idx = length - i
    let ch = chars[idx]
    let digit = @strconv.parse_int(String::from_array([ch]), base=10) catch {
      _ => return Error(formula_error_num)
    }
    if digit < 0 || digit > 7 {
      return Error(formula_error_num)
    }
    if i == 10 && ch == '7' {
      decimal = decimal + @math.pow(-8.0, Double::from_int(i - 1))
      continue
    }
    decimal = decimal +
      Double::from_int(digit) * @math.pow(8.0, Double::from_int(i - 1))
  }
  Number(decimal)
}

///|
fn combin_values(number : Double, chosen : Double) -> FormulaValue {
  let n = trunc_double(number)
  let k = trunc_double(chosen)
  if k > n {
    return Error(formula_error_value)
  }
  if k == n || k == 0.0 {
    return Number(1.0)
  }
  let mut val = 1.0
  let k_int = Double::to_int(k)
  for i in 1..<=k_int {
    let c = Double::from_int(i)
    val = val * (n + 1.0 - c) / c
  }
  Number(Double::ceil(val))
}

///|
fn factorial_double(number : Double) -> Double {
  let n = trunc_double(number)
  if n < 2.0 {
    return 1.0
  }
  let n_int = Double::to_int(n)
  let mut value = 1.0
  for i in 2..<=n_int {
    value = value * Double::from_int(i)
  }
  value
}

///|
fn binom_coeff_double(n : Double, k : Double) -> Double {
  factorial_double(n) / (factorial_double(k) * factorial_double(n - k))
}

///|
fn double_factorial_double(number : Double) -> Double {
  let n = trunc_double(number)
  if n < 2.0 {
    return 1.0
  }
  let mut value = 1.0
  let mut i = Double::to_int(n)
  while i > 1 {
    value = value * Double::from_int(i)
    i = i - 2
  }
  value
}

///|
fn multinomial_collect(
  value : FormulaValue,
  numbers : Array[Double],
) -> Result[Unit, FormulaValue] {
  match value {
    List(list) => {
      for item in list {
        match multinomial_collect(item, numbers) {
          Ok(_) => ()
          Err(err) => return Err(err)
        }
      }
      Ok(())
    }
    Error(err) => Err(Error(err))
    Number(num) => {
      numbers.push(num)
      Ok(())
    }
    Bool(flag) => {
      numbers.push(if flag { 1.0 } else { 0.0 })
      Ok(())
    }
    String(text) =>
      if text == "" {
        Ok(())
      } else {
        match parse_double_opt(text) {
          Some(num) => {
            numbers.push(num)
            Ok(())
          }
          None => Err(Error(formula_error_value))
        }
      }
    Empty => Ok(())
  }
}

///|
fn multinomial_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  let numbers : Array[Double] = []
  for value in values {
    match multinomial_collect(value, numbers) {
      Ok(_) => ()
      Err(err) => return err
    }
  }
  let mut numerator = 0.0
  let mut denominator = 1.0
  for num in numbers {
    numerator = numerator + num
    denominator = denominator * factorial_double(num)
  }
  Number(factorial_double(numerator) / denominator)
}

///|
fn product_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  let mut product = 1.0
  for value in values {
    match value {
      List(list) =>
        for cell in list {
          match normalize_scalar(cell) {
            Error(err) => return Error(err)
            Number(num) => product = product * num
            Bool(_) | String(_) | Empty | List(_) => ()
          }
        }
      _ =>
        match normalize_scalar(value) {
          Error(err) => return Error(err)
          Number(num) => product = product * num
          Bool(flag) => {
            let num = if flag { 1.0 } else { 0.0 }
            product = product * num
          }
          String(text) =>
            match parse_double_opt(text) {
              Some(num) => product = product * num
              None => return Error(formula_error_value)
            }
          Empty | List(_) => ()
        }
    }
  }
  Number(product)
}

///|
fn average_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  let mut sum = 0.0
  let mut count = 0
  for value in flatten_values(values) {
    match normalize_scalar(value) {
      Error(err) => return Error(err)
      Number(num) => {
        sum = sum + num
        count = count + 1
      }
      String(text) =>
        match parse_double_opt(text) {
          Some(num) => {
            sum = sum + num
            count = count + 1
          }
          None => ()
        }
      Bool(_) | Empty | List(_) => ()
    }
  }
  if count == 0 {
    Error(formula_error_div)
  } else {
    Number(sum / Double::from_int(count))
  }
}

///|
fn averagea_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  let mut sum = 0.0
  let mut count = 0
  for value in flatten_values(values) {
    match normalize_scalar(value) {
      Error(err) => return Error(err)
      Number(num) => {
        sum = sum + num
        count = count + 1
      }
      Bool(flag) => {
        let num = if flag { 1.0 } else { 0.0 }
        sum = sum + num
        count = count + 1
      }
      String(text) =>
        if text == "" {
          ()
        } else if text == "TRUE" || text == "FALSE" {
          let num = if text == "TRUE" { 1.0 } else { 0.0 }
          sum = sum + num
          count = count + 1
        } else {
          match parse_double_opt(text) {
            Some(num) => {
              sum = sum + num
              count = count + 1
            }
            None => count = count + 1
          }
        }
      Empty | List(_) => ()
    }
  }
  if count == 0 {
    Error(formula_error_div)
  } else {
    Number(sum / Double::from_int(count))
  }
}

///|
fn stdev_add(
  sum : Double,
  count : Int,
  value : Double,
  mean : Double,
) -> (Double, Int) {
  let delta = value - mean
  let next_sum = if sum < 0.0 { delta * delta } else { sum + delta * delta }
  (next_sum, count + 1)
}

///|
fn stdev_values(
  stdeva : Bool,
  values : ArrayView[FormulaValue],
) -> FormulaValue {
  let mean_value = if stdeva {
    averagea_values(values)
  } else {
    average_values(values)
  }
  let mean = match mean_value {
    Number(num) => num
    value => return value
  }
  let mut sum = -1.0
  let mut count = -1
  for value in flatten_values(values) {
    match normalize_scalar(value) {
      Number(num) => {
        let (next_sum, next_count) = stdev_add(sum, count, num, mean)
        sum = next_sum
        count = next_count
      }
      Bool(flag) =>
        if stdeva {
          let num = if flag { 1.0 } else { 0.0 }
          let (next_sum, next_count) = stdev_add(sum, count, num, mean)
          sum = next_sum
          count = next_count
        }
      String(text) =>
        if text == "TRUE" || text == "FALSE" {
          if stdeva {
            let num = if text == "TRUE" { 1.0 } else { 0.0 }
            let (next_sum, next_count) = stdev_add(sum, count, num, mean)
            sum = next_sum
            count = next_count
          }
        } else {
          match parse_double_opt(text) {
            Some(num) => {
              let (next_sum, next_count) = stdev_add(sum, count, num, mean)
              sum = next_sum
              count = next_count
            }
            None => ()
          }
        }
      _ => ()
    }
  }
  if count > 0 && sum >= 0.0 {
    let result = @math.pow(sum / Double::from_int(count), 0.5)
    Number(round_significant_digits(result, 15))
  } else {
    Error(formula_error_div)
  }
}

///|
fn variance_values(
  values : ArrayView[FormulaValue],
  sample : Bool,
  count_text_zero : Bool,
) -> FormulaValue {
  let mut sum = 0.0
  let mut sum_sq = 0.0
  let mut count = 0
  let minimum = if sample { 1 } else { 0 }
  for value in flatten_values(values) {
    match normalize_scalar(value) {
      Error(err) => return Error(err)
      Number(num) => {
        sum = sum + num
        sum_sq = sum_sq + num * num
        count = count + 1
      }
      Bool(flag) => {
        let num = if flag { 1.0 } else { 0.0 }
        sum = sum + num
        sum_sq = sum_sq + num * num
        count = count + 1
      }
      String(text) =>
        if text == "" {
          ()
        } else if text == "TRUE" || text == "FALSE" {
          let num = if text == "TRUE" { 1.0 } else { 0.0 }
          sum = sum + num
          sum_sq = sum_sq + num * num
          count = count + 1
        } else {
          match parse_double_opt(text) {
            Some(num) => {
              sum = sum + num
              sum_sq = sum_sq + num * num
              count = count + 1
            }
            None => if count_text_zero { count = count + 1 } else { () }
          }
        }
      List(_) | Empty => ()
    }
  }
  if count > minimum {
    let count_d = Double::from_int(count)
    let min_d = Double::from_int(minimum)
    let variance = (sum_sq * count_d - sum * sum) /
      (count_d * (count_d - min_d))
    Number(round_significant_digits(variance, 15))
  } else {
    Error(formula_error_div)
  }
}

///|
fn trimmean_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 2 {
    return Error(formula_error_value)
  }
  let percent = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  if percent < 0.0 || percent >= 1.0 {
    return Error(formula_error_num)
  }
  let numbers : Array[Double] = []
  let list_values : Array[FormulaValue] = [values[0]]
  for value in flatten_values(list_values) {
    match normalize_scalar(value) {
      Number(num) => numbers.push(num)
      _ => ()
    }
  }
  if numbers.length() == 0 {
    return Error(formula_error_div)
  }
  numbers.sort()
  let discard = Double::floor(
    Double::from_int(numbers.length()) * percent / 2.0,
  ).to_int()
  let start = discard
  let end = numbers.length() - discard
  let mut sum = 0.0
  let count = end - start
  for i in start..<end {
    sum = sum + numbers[i]
  }
  Number(sum / Double::from_int(count))
}

///|
fn beta_dist_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() < 4 || values.length() > 6 {
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
  if alpha <= 0.0 || beta <= 0.0 {
    return Error(formula_error_num)
  }
  let cumulative = match value_as_bool(values[3]) {
    Ok(flag) => flag
    Err(err) => return err
  }
  let mut a = 0.0
  let mut b = 1.0
  if values.length() > 4 {
    a = match value_as_number(values[4]) {
      Ok(num) => num
      Err(err) => return err
    }
  }
  if values.length() == 6 {
    b = match value_as_number(values[5]) {
      Ok(num) => num
      Err(err) => return err
    }
  }
  if x < a || x > b {
    return Error(formula_error_num)
  }
  if a == b {
    return Error(formula_error_num)
  }
  let scale = b - a
  let normalized = (x - a) / scale
  let raw = if cumulative {
    get_beta_dist(normalized, alpha, beta)
  } else {
    get_beta_dist_pdf(normalized, alpha, beta) / scale
  }
  number_or_num_error(round_significant_digits(raw, 15))
}

///|
fn betadist_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() < 3 || values.length() > 5 {
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
  if alpha <= 0.0 || beta <= 0.0 {
    return Error(formula_error_num)
  }
  let mut a = 0.0
  let mut b = 1.0
  if values.length() > 3 {
    a = match value_as_number(values[3]) {
      Ok(num) => num
      Err(err) => return err
    }
  }
  if values.length() == 5 {
    b = match value_as_number(values[4]) {
      Ok(num) => num
      Err(err) => return err
    }
  }
  if x < a || x > b {
    return Error(formula_error_num)
  }
  if a == b {
    return Error(formula_error_num)
  }
  let normalized = (x - a) / (b - a)
  let raw = get_beta_dist(normalized, alpha, beta)
  number_or_num_error(round_significant_digits(raw, 15))
}

///|
fn get_beta_inv(probability : Double, alpha : Double, beta : Double) -> Double {
  if probability <= 0.0 {
    return 0.0
  }
  if probability >= 1.0 {
    return 1.0
  }
  let mut low = 0.0
  let mut high = 1.0
  let mut mid = 0.5
  for _ in 0..<200 {
    mid = (low + high) * 0.5
    let cdf = get_beta_dist(mid, alpha, beta)
    if cdf > probability {
      high = mid
    } else {
      low = mid
    }
  }
  mid
}

///|
fn betainv_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() < 3 || values.length() > 5 {
    return Error(formula_error_value)
  }
  let probability = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  if probability <= 0.0 || probability >= 1.0 {
    return Error(formula_error_num)
  }
  let alpha = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  let beta = match value_as_number(values[2]) {
    Ok(num) => num
    Err(err) => return err
  }
  if alpha <= 0.0 || beta <= 0.0 {
    return Error(formula_error_num)
  }
  let mut a = 0.0
  let mut b = 1.0
  if values.length() > 3 {
    a = match value_as_number(values[3]) {
      Ok(num) => num
      Err(err) => return err
    }
  }
  if values.length() == 5 {
    b = match value_as_number(values[4]) {
      Ok(num) => num
      Err(err) => return err
    }
  }
  if a == b {
    return Error(formula_error_num)
  }
  let mid = get_beta_inv(probability, alpha, beta)
  let scaled = a + mid * (b - a)
  number_or_num_error(round_significant_digits(scaled, 15))
}

///|
fn normdist_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 4 {
    return Error(formula_error_value)
  }
  let x = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let mean = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  let std_dev = match value_as_number(values[2]) {
    Ok(num) => num
    Err(err) => return err
  }
  let cumulative = match value_as_bool(values[3]) {
    Ok(flag) => flag
    Err(err) => return err
  }
  if std_dev < 0.0 {
    return Error(formula_error_na)
  }
  let raw = if cumulative {
    norm_cdf(x, mean, std_dev)
  } else {
    norm_pdf(x, mean, std_dev)
  }
  number_or_num_error(round_significant_digits(raw, 15))
}

///|
fn norminv_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 3 {
    return Error(formula_error_value)
  }
  let probability = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let mean = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  let std_dev = match value_as_number(values[2]) {
    Ok(num) => num
    Err(err) => return err
  }
  if probability < 0.0 || probability > 1.0 {
    return Error(formula_error_na)
  }
  if std_dev < 0.0 {
    return Error(formula_error_na)
  }
  let inv = match norminv_double(probability) {
    Ok(value) => value
    Err(err) => return err
  }
  let raw = inv * std_dev + mean
  number_or_num_error(round_significant_digits(raw, 15))
}

///|
fn norm_s_dist_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 2 {
    return Error(formula_error_value)
  }
  let x = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let cumulative = match value_as_bool(values[1]) {
    Ok(flag) => flag
    Err(err) => return err
  }
  let raw = if cumulative { get_norm_s_dist(x) } else { norm_pdf(x, 0.0, 1.0) }
  number_or_num_error(round_significant_digits(raw, 15))
}

///|
fn norms_dist_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 1 {
    return Error(formula_error_value)
  }
  let x = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  number_or_num_error(round_significant_digits(get_norm_s_dist(x), 15))
}

///|
fn norm_s_inv_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 1 {
    return Error(formula_error_value)
  }
  let probability = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  if probability < 0.0 || probability > 1.0 {
    return Error(formula_error_na)
  }
  let inv = match norminv_double(probability) {
    Ok(value) => value
    Err(err) => return err
  }
  number_or_num_error(round_significant_digits(inv, 15))
}

///|
fn norms_inv_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  norm_s_inv_values(values)
}

///|
fn confidence_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 3 {
    return Error(formula_error_value)
  }
  let alpha = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let std_dev = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  let size = match value_as_number(values[2]) {
    Ok(num) => num
    Err(err) => return err
  }
  if alpha <= 0.0 || alpha >= 1.0 || std_dev <= 0.0 || size < 1.0 {
    return Error(formula_error_num)
  }
  let inv = match norminv_double(alpha / 2.0) {
    Ok(value) => value
    Err(err) => return err
  }
  let raw = -inv * (std_dev / Double::sqrt(size))
  number_or_num_error(round_significant_digits(raw, 15))
}

///|
fn confidence_t_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 3 {
    return Error(formula_error_value)
  }
  let alpha = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let std_dev = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  let size = match value_as_number(values[2]) {
    Ok(num) => num
    Err(err) => return err
  }
  if alpha <= 0.0 || alpha >= 1.0 || std_dev <= 0.0 || size < 1.0 {
    return Error(formula_error_num)
  }
  if size == 1.0 {
    return Error(formula_error_div)
  }
  let iterator = { fp: alpha, fdf: size - 1.0, nt: 2.0, kind: TDist }
  let result = calc_iterate_inverse(iterator, size / 2.0, size)
  let raw = std_dev * result / Double::sqrt(size)
  number_or_num_error(round_significant_digits(raw, 15))
}

///|
fn loginv_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 3 {
    return Error(formula_error_value)
  }
  let probability = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let mean = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  let std_dev = match value_as_number(values[2]) {
    Ok(num) => num
    Err(err) => return err
  }
  if probability <= 0.0 || probability >= 1.0 || std_dev <= 0.0 {
    return Error(formula_error_num)
  }
  let inv = match norminv_double(probability) {
    Ok(value) => value
    Err(err) => return err
  }
  let raw = @math.exp(mean + std_dev * inv)
  number_or_num_error(round_significant_digits(raw, 15))
}

///|
fn gamma_value(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 1 {
    return Error(formula_error_value)
  }
  let number = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  if number <= 0.0 {
    return Error(formula_error_na)
  }
  let raw = get_gamma(number)
  number_or_num_error(round_significant_digits(raw, 15))
}

///|
fn gamma_pdf(x : Double, alpha : Double, beta : Double) -> Double {
  let denom = @math.pow(beta, alpha) * get_gamma(alpha)
  @math.pow(x, alpha - 1.0) * @math.exp(-x / beta) / denom
}

///|
fn gamma_cdf(x : Double, alpha : Double, beta : Double) -> Double {
  get_low_reg_igamma(alpha, x / beta)
}

///|
fn gamma_dist_values(values : ArrayView[FormulaValue]) -> FormulaValue {
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
  if x < 0.0 {
    return Error(formula_error_num)
  }
  if alpha <= 0.0 || beta <= 0.0 {
    return Error(formula_error_num)
  }
  let raw = if cumulative {
    gamma_cdf(x, alpha, beta)
  } else {
    gamma_pdf(x, alpha, beta)
  }
  number_or_num_error(round_significant_digits(raw, 15))
}

///|
fn gammainv_double(
  probability : Double,
  alpha : Double,
  beta : Double,
) -> Double {
  let mut x_lo = 0.0
  let mut x_hi = alpha * beta * 5.0
  let mut dx = 1024.0
  let mut x = 1.0
  let mut x_new = 1.0
  let mut result = 0.0
  let mut count = 0
  while Double::abs(dx) > 8.88e-016 && count <= 256 {
    result = gamma_cdf(x, alpha, beta)
    let diff = result - probability
    if diff == 0.0 {
      dx = 0.0
    } else if diff < 0.0 {
      x_lo = x
    } else {
      x_hi = x
    }
    let pdf = gamma_pdf(x, alpha, beta)
    if pdf != 0.0 {
      dx = diff / pdf
      x_new = x - dx
    }
    if x_new < x_lo || x_new > x_hi || pdf == 0.0 {
      x_new = (x_lo + x_hi) / 2.0
      dx = x_new - x
    }
    x = x_new
    count = count + 1
  }
  x
}

///|
fn gamma_inv_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 3 {
    return Error(formula_error_value)
  }
  let probability = match value_as_number(values[0]) {
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
  if probability < 0.0 || probability >= 1.0 {
    return Error(formula_error_num)
  }
  if alpha <= 0.0 || beta <= 0.0 {
    return Error(formula_error_num)
  }
  let raw = gammainv_double(probability, alpha, beta)
  number_or_num_error(round_significant_digits(raw, 15))
}

///|
fn gammaln_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 1 {
    return Error(formula_error_value)
  }
  let x = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  if x <= 0.0 {
    return Error(formula_error_na)
  }
  let raw = get_log_gamma(x)
  number_or_num_error(round_significant_digits(raw, 15))
}

///|
fn gammaln_precise_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 1 {
    return Error(formula_error_value)
  }
  let x = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  if x <= 0.0 {
    return Error(formula_error_num)
  }
  let raw = get_log_gamma(x)
  number_or_num_error(round_significant_digits(raw, 15))
}

///|
fn lognorm_dist_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 4 {
    return Error(formula_error_value)
  }
  let x = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let mean = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  let std_dev = match value_as_number(values[2]) {
    Ok(num) => num
    Err(err) => return err
  }
  let cumulative = match value_as_bool(values[3]) {
    Ok(flag) => flag
    Err(err) => return err
  }
  if x <= 0.0 || std_dev <= 0.0 {
    return Error(formula_error_num)
  }
  if cumulative {
    let z = (@math.ln(x) - mean) / std_dev
    return number_or_num_error(round_significant_digits(get_norm_s_dist(z), 15))
  }
  let denom = Double::sqrt(2.0 * @math.PI) * std_dev * x
  let exponent = -(@math.pow(@math.ln(x) - mean, 2.0) /
    (2.0 * std_dev * std_dev))
  let raw = @math.exp(exponent) / denom
  number_or_num_error(round_significant_digits(raw, 15))
}

///|
fn lognormdist_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 3 {
    return Error(formula_error_value)
  }
  let x = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let mean = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  let std_dev = match value_as_number(values[2]) {
    Ok(num) => num
    Err(err) => return err
  }
  if x <= 0.0 || std_dev <= 0.0 {
    return Error(formula_error_num)
  }
  let z = (@math.ln(x) - mean) / std_dev
  number_or_num_error(round_significant_digits(get_norm_s_dist(z), 15))
}

///|
fn expon_dist_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 3 {
    return Error(formula_error_value)
  }
  let x = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let lambda = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  let cumulative = match value_as_bool(values[2]) {
    Ok(flag) => flag
    Err(err) => return err
  }
  if x < 0.0 || lambda <= 0.0 {
    return Error(formula_error_num)
  }
  let raw = if cumulative {
    1.0 - @math.exp(-lambda * x)
  } else {
    lambda * @math.exp(-lambda * x)
  }
  number_or_num_error(round_significant_digits(raw, 15))
}

///|
fn poisson_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 3 {
    return Error(formula_error_value)
  }
  let x = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let mean = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  let cumulative = match value_as_bool(values[2]) {
    Ok(flag) => flag
    Err(err) => return err
  }
  if x < 0.0 || mean <= 0.0 {
    return Error(formula_error_na)
  }
  let raw = if cumulative {
    let mut sum = 0.0
    let limit = Double::to_int(Double::floor(x))
    for i in 0..<=limit {
      let i_double = Double::from_int(i)
      sum = sum + @math.pow(mean, i_double) / factorial_double(i_double)
    }
    @math.exp(-mean) * sum
  } else {
    @math.exp(-mean) * @math.pow(mean, x) / factorial_double(x)
  }
  number_or_num_error(round_significant_digits(raw, 15))
}

///|
fn binomdist_double(x : Double, n : Double, p : Double) -> Double {
  binom_coeff_double(n, x) * @math.pow(p, x) * @math.pow(1.0 - p, n - x)
}

///|
fn binominv_double(n : Double, p : Double, alpha : Double) -> Double {
  let q = 1.0 - p
  let mut i = 0.0
  let mut sum = 0.0
  let n = Double::floor(n)
  if q > p {
    let mut factor = @math.pow(q, n)
    sum = factor
    while i < n && sum < alpha {
      factor = factor * (n - i) / (i + 1.0) * p / q
      sum = sum + factor
      i = i + 1.0
    }
    return i
  }
  let mut factor = @math.pow(p, n)
  sum = 1.0 - factor
  while i < n && sum >= alpha {
    factor = factor * (n - i) / (i + 1.0) * q / p
    sum = sum - factor
    i = i + 1.0
  }
  n - i
}

///|
fn binomdist_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 4 {
    return Error(formula_error_value)
  }
  let successes = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let trials = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  if successes < 0.0 || successes > trials {
    return Error(formula_error_num)
  }
  let probability = match value_as_number(values[2]) {
    Ok(num) => num
    Err(err) => return err
  }
  if probability < 0.0 || probability > 1.0 {
    return Error(formula_error_num)
  }
  let cumulative = match value_as_bool(values[3]) {
    Ok(flag) => flag
    Err(err) => return err
  }
  let raw = if cumulative {
    let mut sum = 0.0
    let limit = Double::to_int(Double::floor(successes))
    for i in 0..<=limit {
      let i_double = Double::from_int(i)
      sum = sum + binomdist_double(i_double, trials, probability)
    }
    sum
  } else {
    binomdist_double(successes, trials, probability)
  }
  number_or_num_error(round_significant_digits(raw, 15))
}

///|
fn binom_dist_range_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() < 3 {
    return Error(formula_error_value)
  }
  if values.length() > 4 {
    return Error(formula_error_value)
  }
  let trials = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let probability = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  if probability < 0.0 || probability > 1.0 {
    return Error(formula_error_num)
  }
  let number_s = match value_as_number(values[2]) {
    Ok(num) => num
    Err(err) => return err
  }
  if number_s < 0.0 || number_s > trials {
    return Error(formula_error_num)
  }
  let number_s2 = if values.length() == 4 {
    match value_as_number(values[3]) {
      Ok(num) => num
      Err(err) => return err
    }
  } else {
    number_s
  }
  if number_s2 < 0.0 || number_s2 > trials {
    return Error(formula_error_num)
  }
  let mut sum = 0.0
  let mut i = number_s
  while i <= number_s2 {
    sum = sum + binomdist_double(i, trials, probability)
    i = i + 1.0
  }
  number_or_num_error(round_significant_digits(sum, 15))
}

///|
fn binom_inv_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 3 {
    return Error(formula_error_value)
  }
  let trials = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  if trials < 0.0 {
    return Error(formula_error_num)
  }
  let probability = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  if probability <= 0.0 || probability >= 1.0 {
    return Error(formula_error_num)
  }
  let alpha = match value_as_number(values[2]) {
    Ok(num) => num
    Err(err) => return err
  }
  if alpha <= 0.0 || alpha >= 1.0 {
    return Error(formula_error_num)
  }
  let raw = binominv_double(trials, probability, alpha)
  number_or_num_error(round_significant_digits(raw, 15))
}

///|
fn hypgeom_args_invalid(
  sample_s : Double,
  number_sample : Double,
  population_s : Double,
  number_pop : Double,
) -> Bool {
  let upper = if number_sample < population_s {
    number_sample
  } else {
    population_s
  }
  let lower_raw = number_sample - number_pop + population_s
  let lower = if lower_raw > 0.0 { lower_raw } else { 0.0 }
  sample_s < 0.0 ||
  sample_s > upper ||
  sample_s < lower ||
  number_sample <= 0.0 ||
  number_sample > number_pop ||
  population_s <= 0.0 ||
  population_s > number_pop ||
  number_pop <= 0.0
}

///|
fn hypgeom_raw(
  sample_s : Double,
  number_sample : Double,
  population_s : Double,
  number_pop : Double,
) -> Double {
  binom_coeff_double(population_s, sample_s) *
  binom_coeff_double(number_pop - population_s, number_sample - sample_s) /
  binom_coeff_double(number_pop, number_sample)
}

///|
fn hypgeom_dist_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 5 {
    return Error(formula_error_value)
  }
  let sample_s = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let number_sample = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  let population_s = match value_as_number(values[2]) {
    Ok(num) => num
    Err(err) => return err
  }
  let number_pop = match value_as_number(values[3]) {
    Ok(num) => num
    Err(err) => return err
  }
  if hypgeom_args_invalid(sample_s, number_sample, population_s, number_pop) {
    return Error(formula_error_num)
  }
  let cumulative = match value_as_bool(values[4]) {
    Ok(flag) => flag
    Err(err) => return err
  }
  let raw = if cumulative {
    let mut sum = 0.0
    let limit = Double::to_int(Double::floor(sample_s))
    for i in 0..<=limit {
      let i_double = Double::from_int(i)
      sum = sum + hypgeom_raw(i_double, number_sample, population_s, number_pop)
    }
    sum
  } else {
    hypgeom_raw(sample_s, number_sample, population_s, number_pop)
  }
  number_or_num_error(round_significant_digits(raw, 15))
}

///|
fn hypgeomdist_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 4 {
    return Error(formula_error_value)
  }
  let sample_s = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let number_sample = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  let population_s = match value_as_number(values[2]) {
    Ok(num) => num
    Err(err) => return err
  }
  let number_pop = match value_as_number(values[3]) {
    Ok(num) => num
    Err(err) => return err
  }
  if hypgeom_args_invalid(sample_s, number_sample, population_s, number_pop) {
    return Error(formula_error_num)
  }
  let raw = hypgeom_raw(sample_s, number_sample, population_s, number_pop)
  number_or_num_error(round_significant_digits(raw, 15))
}

///|
fn negbinom_dist_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 4 {
    return Error(formula_error_value)
  }
  let failures = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let successes = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  let probability = match value_as_number(values[2]) {
    Ok(num) => num
    Err(err) => return err
  }
  let cumulative = match value_as_bool(values[3]) {
    Ok(flag) => flag
    Err(err) => return err
  }
  if failures < 0.0 || successes < 1.0 || probability < 0.0 || probability > 1.0 {
    return Error(formula_error_num)
  }
  let raw = if cumulative {
    1.0 - get_beta_dist(1.0 - probability, failures + 1.0, successes)
  } else {
    binom_coeff_double(failures + successes - 1.0, successes - 1.0) *
    @math.pow(probability, successes) *
    @math.pow(1.0 - probability, failures)
  }
  number_or_num_error(round_significant_digits(raw, 15))
}

///|
fn negbinomdist_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 3 {
    return Error(formula_error_value)
  }
  let failures = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let successes = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  let probability = match value_as_number(values[2]) {
    Ok(num) => num
    Err(err) => return err
  }
  if failures < 0.0 || successes < 1.0 || probability < 0.0 || probability > 1.0 {
    return Error(formula_error_num)
  }
  let raw = binom_coeff_double(failures + successes - 1.0, successes - 1.0) *
    @math.pow(probability, successes) *
    @math.pow(1.0 - probability, failures)
  number_or_num_error(round_significant_digits(raw, 15))
}

///|
fn gauss_value(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 1 {
    return Error(formula_error_value)
  }
  let x = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let raw = get_norm_s_dist(x) - 0.5
  number_or_num_error(round_significant_digits(raw, 15))
}

///|
fn phi_value(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 1 {
    return Error(formula_error_value)
  }
  let x = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let raw = 0.39894228040143268 * @math.exp(-(x * x) / 2.0)
  number_or_num_error(round_significant_digits(raw, 15))
}

///|
fn tdist_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 3 {
    return Error(formula_error_value)
  }
  let x = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let degrees = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  let cumulative = match value_as_bool(values[2]) {
    Ok(flag) => flag
    Err(err) => return err
  }
  if cumulative {
    if degrees < 1.0 {
      return Error(formula_error_num)
    }
    let raw = get_t_dist(x, degrees, 4.0)
    return number_or_num_error(round_significant_digits(raw, 14))
  }
  if degrees < 0.0 {
    return Error(formula_error_num)
  }
  if degrees == 0.0 {
    return Error(formula_error_div)
  }
  let raw = get_t_dist(x, degrees, 3.0)
  number_or_num_error(round_significant_digits(raw, 15))
}

///|
fn tdist_2t_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 2 {
    return Error(formula_error_value)
  }
  let x = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let degrees = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  if x < 0.0 || degrees < 1.0 {
    return Error(formula_error_num)
  }
  let raw = get_t_dist(x, degrees, 2.0)
  number_or_num_error(round_significant_digits(raw, 14))
}

///|
fn tdist_rt_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 2 {
    return Error(formula_error_value)
  }
  let x = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let degrees = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  if degrees < 1.0 {
    return Error(formula_error_num)
  }
  let mut value = get_t_dist(x, degrees, 1.0)
  if x < 0.0 {
    value = 1.0 - value
  }
  number_or_num_error(round_significant_digits(value, 14))
}

///|
fn tdist_legacy_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 3 {
    return Error(formula_error_value)
  }
  let x = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let degrees = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  let tails = match value_as_number(values[2]) {
    Ok(num) => num
    Err(err) => return err
  }
  if x < 0.0 || degrees < 1.0 || (tails != 1.0 && tails != 2.0) {
    return Error(formula_error_num)
  }
  let raw = get_t_dist(x, degrees, tails)
  number_or_num_error(round_significant_digits(raw, 14))
}

///|
fn tinv_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 2 {
    return Error(formula_error_value)
  }
  let probability = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let degrees = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  if probability <= 0.0 || probability >= 1.0 || degrees < 1.0 {
    return Error(formula_error_num)
  }
  let iterator = if probability < 0.5 {
    { fp: 1.0 - probability, fdf: degrees, nt: 4.0, kind: TDist }
  } else {
    { fp: probability, fdf: degrees, nt: 4.0, kind: TDist }
  }
  let mut result = calc_iterate_inverse(iterator, degrees / 2.0, degrees)
  if probability < 0.5 {
    result = -result
  }
  number_or_num_error(round_significant_digits(result, 15))
}

///|
fn tinv_2t_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 2 {
    return Error(formula_error_value)
  }
  let probability = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let degrees = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  if probability <= 0.0 || probability > 1.0 || degrees < 1.0 {
    return Error(formula_error_num)
  }
  let iterator = { fp: probability, fdf: degrees, nt: 2.0, kind: TDist }
  let result = calc_iterate_inverse(iterator, degrees / 2.0, degrees)
  number_or_num_error(round_significant_digits(result, 15))
}

///|
fn number_strict_opt(value : FormulaValue) -> Double? {
  match normalize_scalar(value) {
    Number(num) => Some(num)
    _ => None
  }
}

///|
fn ttest_unpaired(
  array1 : ArrayView[FormulaValue],
  array2 : ArrayView[FormulaValue],
  unequal : Bool,
) -> (Double, Double, Bool) {
  let mut sum1 = 0.0
  let mut sum_sqr1 = 0.0
  let mut cnt1 = 0.0
  for value in array1 {
    match number_strict_opt(value) {
      Some(num) => {
        sum1 = sum1 + num
        sum_sqr1 = sum_sqr1 + num * num
        cnt1 = cnt1 + 1.0
      }
      None => ()
    }
  }
  let mut sum2 = 0.0
  let mut sum_sqr2 = 0.0
  let mut cnt2 = 0.0
  for value in array2 {
    match number_strict_opt(value) {
      Some(num) => {
        sum2 = sum2 + num
        sum_sqr2 = sum_sqr2 + num * num
        cnt2 = cnt2 + 1.0
      }
      None => ()
    }
  }
  if cnt1 < 2.0 || cnt2 < 2.0 {
    return (0.0, 0.0, false)
  }
  if unequal {
    let fs1 = (sum_sqr1 - sum1 * sum1 / cnt1) / (cnt1 - 1.0) / cnt1
    let fs2 = (sum_sqr2 - sum2 * sum2 / cnt2) / (cnt2 - 1.0) / cnt2
    if fs1 + fs2 == 0.0 {
      return (0.0, 0.0, false)
    }
    let c = fs1 / (fs1 + fs2)
    let t_value = Double::abs(sum1 / cnt1 - sum2 / cnt2) /
      Double::sqrt(fs1 + fs2)
    let df = 1.0 / (c * c / (cnt1 - 1.0) + (1.0 - c) * (1.0 - c) / (cnt2 - 1.0))
    return (t_value, df, true)
  }
  let fs1 = (sum_sqr1 - sum1 * sum1 / cnt1) / (cnt1 - 1.0)
  let fs2 = (sum_sqr2 - sum2 * sum2 / cnt2) / (cnt2 - 1.0)
  let denom = (cnt1 - 1.0) * fs1 + (cnt2 - 1.0) * fs2
  let t_value = Double::abs(sum1 / cnt1 - sum2 / cnt2) /
    Double::sqrt(denom) *
    Double::sqrt(cnt1 * cnt2 * (cnt1 + cnt2 - 2.0) / (cnt1 + cnt2))
  let df = cnt1 + cnt2 - 2.0
  (t_value, df, true)
}

///|
fn ttest_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 4 {
    return Error(formula_error_value)
  }
  let (array1, array2) = match (values[0], values[1]) {
    (List(left), List(right)) => (left, right)
    _ => return Error(formula_error_num)
  }
  let tails = match value_as_number(values[2]) {
    Ok(num) => num
    Err(err) => return err
  }
  let test_type = match value_as_number(values[3]) {
    Ok(num) => num
    Err(err) => return err
  }
  if tails != 1.0 && tails != 2.0 {
    return Error(formula_error_num)
  }
  if test_type != 1.0 && test_type != 2.0 && test_type != 3.0 {
    return Error(formula_error_num)
  }
  let (t_value, df) = if test_type == 1.0 {
    if array1.length() != array2.length() {
      return Error(formula_error_na)
    }
    let mut sum1 = 0.0
    let mut sum2 = 0.0
    let mut sum_sqr_d = 0.0
    let mut cnt = 0.0
    for i in 0..<array1.length() {
      match (number_strict_opt(array1[i]), number_strict_opt(array2[i])) {
        (Some(lhs), Some(rhs)) => {
          sum1 = sum1 + lhs
          sum2 = sum2 + rhs
          let diff = lhs - rhs
          sum_sqr_d = sum_sqr_d + diff * diff
          cnt = cnt + 1.0
        }
        _ => ()
      }
    }
    if cnt < 1.0 {
      return Error(formula_error_num)
    }
    let sum_d = sum1 - sum2
    let divider = cnt * sum_sqr_d - sum_d * sum_d
    if divider == 0.0 {
      return Error(formula_error_div)
    }
    let t_val = Double::abs(sum_d) * Double::sqrt((cnt - 1.0) / divider)
    (t_val, cnt - 1.0)
  } else {
    let (t_val, df_val, ok) = ttest_unpaired(array1, array2, test_type == 3.0)
    if !ok {
      return Error(formula_error_num)
    }
    (t_val, df_val)
  }
  let result = get_t_dist(t_value, df, tails)
  number_or_num_error(round_significant_digits(result, 15))
}

///|
fn ztest_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() < 2 {
    return Error(formula_error_value)
  }
  if values.length() > 3 {
    return Error(formula_error_value)
  }
  let avg_input : Array[FormulaValue] = [values[0]]
  let mean = match average_values(avg_input) {
    Number(num) => num
    _ => return Error(formula_error_na)
  }
  let x = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  let sigma = if values.length() == 3 {
    match value_as_number(values[2]) {
      Ok(num) => num
      Err(err) => return err
    }
  } else {
    let stdev_input : Array[FormulaValue] = [values[0]]
    match stdev_values(false, stdev_input) {
      Number(num) => num
      value => return value
    }
  }
  let list = list_from_value(values[0])
  let count = Double::from_int(list.length())
  let denom = sigma / Double::sqrt(count)
  if denom == 0.0 {
    return Error(formula_error_div)
  }
  let z = (mean - x) / denom
  let result = 1.0 - get_norm_s_dist(z)
  number_or_num_error(round_significant_digits(result, 15))
}

///|
fn prob_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() < 3 {
    return Error(formula_error_value)
  }
  if values.length() > 4 {
    return Error(formula_error_value)
  }
  let (x_range, prob_range) = match (values[0], values[1]) {
    (List(xs), List(ps)) => (xs, ps)
    _ => return Error(formula_error_num)
  }
  if x_range.length() == 0 || prob_range.length() == 0 {
    return Error(formula_error_num)
  }
  if x_range.length() != prob_range.length() {
    return Error(formula_error_na)
  }
  let lower = match value_as_number(values[2]) {
    Ok(num) => num
    Err(err) => return err
  }
  let upper = if values.length() == 4 {
    match value_as_number(values[3]) {
      Ok(num) => num
      Err(err) => return err
    }
  } else {
    lower
  }
  let mut sum = 0.0
  let mut res = 0.0
  for i in 0..<x_range.length() {
    match (normalize_scalar(x_range[i]), normalize_scalar(prob_range[i])) {
      (Number(x), Number(p)) => {
        if p < 0.0 || p > 1.0 {
          return Error(formula_error_num)
        }
        sum = sum + p
        if x >= lower && x <= upper {
          res = res + p
        }
      }
      _ => return Error(formula_error_num)
    }
  }
  if Double::abs(sum - 1.0) > 1.0e-7 {
    return Error(formula_error_num)
  }
  number_or_num_error(round_significant_digits(res, 15))
}

///|
fn chidist_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 2 {
    return Error(formula_error_value)
  }
  let x = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let degrees = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  let result = round_chisq_result(get_chidist(x, degrees))
  number_or_num_error(result)
}

///|
fn chiinv_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 2 {
    return Error(formula_error_value)
  }
  let probability = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let degrees = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  if probability <= 0.0 || probability > 1.0 || degrees < 1.0 {
    return Error(formula_error_num)
  }
  if probability == 1.0 {
    return Number(0.0)
  }
  let iterator = { fp: 1.0 - probability, fdf: degrees, nt: 0.0, kind: ChiSq }
  let result = calc_iterate_inverse(iterator, degrees / 2.0, degrees)
  number_or_num_error(result)
}

///|
fn chisq_dist_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 3 {
    return Error(formula_error_value)
  }
  let x = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let degrees = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  let cumulative = match value_as_bool(values[2]) {
    Ok(flag) => flag
    Err(err) => return err
  }
  if x < 0.0 {
    return Error(formula_error_num)
  }
  let max_deg = @math.pow(10.0, 10.0)
  if degrees < 1.0 || degrees >= max_deg {
    return Error(formula_error_num)
  }
  if cumulative {
    number_or_num_error(get_chisq_dist_cdf(x, degrees))
  } else {
    number_or_num_error(get_chisq_dist_pdf(x, degrees))
  }
}

///|
fn chisq_inv_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 2 {
    return Error(formula_error_value)
  }
  let probability = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let degrees = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  if probability < 0.0 || probability >= 1.0 {
    return Error(formula_error_num)
  }
  let max_deg = @math.pow(10.0, 10.0)
  if degrees < 1.0 || degrees > max_deg {
    return Error(formula_error_num)
  }
  if probability == 0.0 {
    return Number(0.0)
  }
  let iterator = { fp: probability, fdf: degrees, nt: 0.0, kind: ChiSq }
  let result = calc_iterate_inverse(iterator, degrees / 2.0, degrees)
  number_or_num_error(result)
}

///|
fn chitest_values(
  workbook : Workbook,
  sheet_name : String,
  args : ArrayView[Expr],
  values : ArrayView[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue raise XlsxError {
  if values.length() != 2 {
    return Error(formula_error_value)
  }
  let actual_range = range_from_expr_or_value(
    workbook,
    sheet_name,
    args[0],
    values[0],
    ctx,
  )
  let expected_range = range_from_expr_or_value(
    workbook,
    sheet_name,
    args[1],
    values[1],
    ctx,
  )
  if actual_range.rows == 0 || actual_range.cols == 0 {
    return Error(formula_error_value)
  }
  if actual_range.rows != expected_range.rows ||
    actual_range.cols != expected_range.cols {
    return Error(formula_error_na)
  }
  if actual_range.rows * actual_range.cols == 1 {
    return Error(formula_error_na)
  }
  let mut result = 0.0
  for idx in 0..<actual_range.values.length() {
    let actual = match value_as_number(actual_range.values[idx]) {
      Ok(num) => num
      Err(err) => return err
    }
    let expected = match value_as_number(expected_range.values[idx]) {
      Ok(num) => num
      Err(err) => return err
    }
    if expected == 0.0 {
      return Error(formula_error_div)
    }
    if expected < 0.0 {
      return Error(formula_error_num)
    }
    let diff = actual - expected
    result = result + diff * diff / expected
  }
  let degrees = if actual_range.rows == 1 {
    actual_range.cols - 1
  } else if actual_range.cols == 1 {
    actual_range.rows - 1
  } else {
    (actual_range.cols - 1) * (actual_range.rows - 1)
  }
  let value = round_chisq_result(get_chidist(result, Double::from_int(degrees)))
  number_or_num_error(value)
}

///|
fn fdist_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 4 {
    return Error(formula_error_value)
  }
  let x = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let deg1 = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  let deg2 = match value_as_number(values[2]) {
    Ok(num) => num
    Err(err) => return err
  }
  let cumulative = match value_as_bool(values[3]) {
    Ok(flag) => flag
    Err(err) => return err
  }
  if x < 0.0 {
    return Error(formula_error_num)
  }
  let max_deg = @math.pow(10.0, 10.0)
  if deg1 < 1.0 || deg1 >= max_deg {
    return Error(formula_error_num)
  }
  if deg2 < 1.0 || deg2 >= max_deg {
    return Error(formula_error_num)
  }
  let raw = if cumulative {
    get_f_dist_cdf(x, deg1, deg2)
  } else {
    get_f_dist_pdf(x, deg1, deg2)
  }
  number_or_num_error(round_significant_digits(raw, 15))
}

///|
fn fdist_rt_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 3 {
    return Error(formula_error_value)
  }
  let x = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let deg1 = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  let deg2 = match value_as_number(values[2]) {
    Ok(num) => num
    Err(err) => return err
  }
  if x < 0.0 {
    return Error(formula_error_num)
  }
  let max_deg = @math.pow(10.0, 10.0)
  if deg1 < 1.0 || deg1 >= max_deg {
    return Error(formula_error_num)
  }
  if deg2 < 1.0 || deg2 >= max_deg {
    return Error(formula_error_num)
  }
  let raw = get_f_dist_rt(x, deg1, deg2)
  number_or_num_error(round_significant_digits(raw, 15))
}

///|
fn finv_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 3 {
    return Error(formula_error_value)
  }
  let probability = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let deg1 = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  let deg2 = match value_as_number(values[2]) {
    Ok(num) => num
    Err(err) => return err
  }
  if probability <= 0.0 || probability > 1.0 {
    return Error(formula_error_num)
  }
  let max_deg = @math.pow(10.0, 10.0)
  if deg1 < 1.0 || deg1 >= max_deg {
    return Error(formula_error_num)
  }
  if deg2 < 1.0 || deg2 >= max_deg {
    return Error(formula_error_num)
  }
  let beta_inv = get_beta_inv(1.0 - probability, deg2 / 2.0, deg1 / 2.0)
  let result = (1.0 / beta_inv - 1.0) * (deg2 / deg1)
  number_or_num_error(round_significant_digits(result, 15))
}

///|
fn finv_rt_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 3 {
    return Error(formula_error_value)
  }
  let probability = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let deg1 = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  let deg2 = match value_as_number(values[2]) {
    Ok(num) => num
    Err(err) => return err
  }
  if probability <= 0.0 || probability > 1.0 {
    return Error(formula_error_num)
  }
  let max_deg = @math.pow(10.0, 10.0)
  if deg1 < 1.0 || deg1 >= max_deg {
    return Error(formula_error_num)
  }
  if deg2 < 1.0 || deg2 >= max_deg {
    return Error(formula_error_num)
  }
  let beta_inv = get_beta_inv(probability, deg2 / 2.0, deg1 / 2.0)
  let result = (1.0 / beta_inv - 1.0) * (deg2 / deg1)
  number_or_num_error(round_significant_digits(result, 15))
}

///|
fn ftest_collect(values : Array[FormulaValue]) -> (Double, Double) {
  let mut n = 0.0
  let mut mean = 0.0
  let mut accu = 0.0
  for value in values {
    match value_as_number_opt(value) {
      Some(num) => {
        let x = num - mean
        let y = x / (n + 1.0)
        mean = mean + y
        accu = accu + n * x * y
        n = n + 1.0
      }
      None => ()
    }
  }
  (n, accu)
}

///|
fn ftest_values(
  workbook : Workbook,
  sheet_name : String,
  args : ArrayView[Expr],
  values : ArrayView[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue raise XlsxError {
  if values.length() != 2 {
    return Error(formula_error_value)
  }
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
  let (n1, accu1) = ftest_collect(left_range.values)
  if n1 <= 1.0 {
    return Error(formula_error_div)
  }
  let f1 = accu1 / (n1 - 1.0)
  if f1 == 0.0 {
    return Error(formula_error_div)
  }
  let (n2, accu2) = ftest_collect(right_range.values)
  if n2 <= 1.0 {
    return Error(formula_error_div)
  }
  let f2 = accu2 / (n2 - 1.0)
  if f2 == 0.0 {
    return Error(formula_error_div)
  }
  let fd = get_f_dist_rt(f1 / f2, n1 - 1.0, n2 - 1.0)
  let mut probability = (1.0 - fd) * 2.0
  if probability > 1.0 {
    probability = 2.0 - probability
  }
  number_or_num_error(round_significant_digits(probability, 15))
}

///|
