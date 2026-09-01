///|
// Per-formula handlers for the stats family. Each maps one (or a few aliases of)
// one Excel formula to its implementation; eval_function routes to these via a HashMap.

///|
fn eval_average(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  average_values(values)
}

///|
fn eval_averagea(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  averagea_values(values)
}

///|
fn eval_stdev(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [_, ..] => stdev_values(false, values)
    [] => Error(formula_error_value)
  }
}

///|
fn eval_stdeva(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [_, ..] => stdev_values(true, values)
    [] => Error(formula_error_value)
  }
}

///|
fn eval_stdevp(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [_, ..] =>
      match variance_values(values, false, false) {
        Number(variance) => {
          let result = @math.pow(variance, 0.5)
          Number(round_significant_digits(result, 15))
        }
        value => value
      }
    [] => Error(formula_error_value)
  }
}

///|
fn eval_stdevpa(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [_, ..] =>
      match variance_values(values, false, true) {
        Number(variance) => {
          let result = @math.pow(variance, 0.5)
          Number(round_significant_digits(result, 15))
        }
        value => value
      }
    [] => Error(formula_error_value)
  }
}

///|
fn eval_var(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [_, ..] => variance_values(values, true, false)
    [] => Error(formula_error_value)
  }
}

///|
fn eval_vara(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [_, ..] => variance_values(values, true, true)
    [] => Error(formula_error_value)
  }
}

///|
fn eval_varp(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [_, ..] => variance_values(values, false, false)
    [] => Error(formula_error_value)
  }
}

///|
fn eval_varpa(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [_, ..] => variance_values(values, false, true)
    [] => Error(formula_error_value)
  }
}

///|
fn eval_trimmean(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  trimmean_values(values)
}

///|
fn eval_avedev(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [_, ..] => avedev_values(values)
    [] => Error(formula_error_value)
  }
}

///|
fn eval_devsq(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [_, ..] => devsq_values(values)
    [] => Error(formula_error_value)
  }
}

///|
fn eval_geomean(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [_, ..] => geomean_values(values)
    [] => Error(formula_error_value)
  }
}

///|
fn eval_harmean(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [_, ..] => harmean_values(values)
    [] => Error(formula_error_value)
  }
}

///|
fn eval_kurt(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [_, ..] => kurt_values(values)
    [] => Error(formula_error_value)
  }
}

///|
fn eval_skew(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [_, ..] => skew_values("SKEW", values)
    [] => Error(formula_error_value)
  }
}

///|
fn eval_skew_p(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [_, ..] => skew_values("SKEW.P", values)
    [] => Error(formula_error_value)
  }
}

///|
fn eval_standardize(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [_, _, _] => standardize_values(values)
    _ => Error(formula_error_value)
  }
}

///|
fn eval_large(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0, v1] => kth_values("LARGE", v0, v1)
    _ => Error(formula_error_value)
  }
}

///|
fn eval_small(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0, v1] => kth_values("SMALL", v0, v1)
    _ => Error(formula_error_value)
  }
}

///|
fn eval_mode(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [_, ..] => mode_values(values)
    [] => Error(formula_error_value)
  }
}

///|
fn eval_mode_sngl(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [_, ..] => mode_values(values)
    [] => Error(formula_error_value)
  }
}

///|
fn eval_mode_mult(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [_, ..] => mode_mult_values(values)
    [] => Error(formula_error_value)
  }
}

///|
fn eval_percentile(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0, v1] =>
      match value_as_number(v1) {
        Ok(k) =>
          if k < 0.0 || k > 1.0 {
            Error(formula_error_na)
          } else {
            percentile_values(v0, k, false, false)
          }
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_percentile_inc(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0, v1] =>
      match value_as_number(v1) {
        Ok(k) =>
          if k < 0.0 || k > 1.0 {
            Error(formula_error_na)
          } else {
            percentile_values(v0, k, false, false)
          }
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_percentile_exc(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0, v1] =>
      match value_as_number(v1) {
        Ok(k) =>
          if k <= 0.0 || k >= 1.0 {
            Error(formula_error_num)
          } else {
            percentile_values(v0, k, true, true)
          }
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_percentrank(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0, v1] | [v0, v1, _] =>
      match value_as_number(v1) {
        Ok(x) => {
          let significance = if values is [_, _, v2] {
            match value_as_number(v2) {
              Ok(num) => num
              Err(err) => return err
            }
          } else {
            3.0
          }
          percentrank_values("PERCENTRANK", v0, x, significance)
        }
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_percentrank_inc(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0, v1] | [v0, v1, _] =>
      match value_as_number(v1) {
        Ok(x) => {
          let significance = if values is [_, _, v2] {
            match value_as_number(v2) {
              Ok(num) => num
              Err(err) => return err
            }
          } else {
            3.0
          }
          percentrank_values("PERCENTRANK.INC", v0, x, significance)
        }
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_percentrank_exc(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0, v1] | [v0, v1, _] =>
      match value_as_number(v1) {
        Ok(x) => {
          let significance = if values is [_, _, v2] {
            match value_as_number(v2) {
              Ok(num) => num
              Err(err) => return err
            }
          } else {
            3.0
          }
          percentrank_values("PERCENTRANK.EXC", v0, x, significance)
        }
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_quartile(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0, v1] =>
      match value_as_number(v1) {
        Ok(quart) => quartile_values("QUARTILE", v0, quart, false)
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_quartile_inc(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0, v1] =>
      match value_as_number(v1) {
        Ok(quart) => quartile_values("QUARTILE.INC", v0, quart, false)
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_quartile_exc(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0, v1] =>
      match value_as_number(v1) {
        Ok(quart) => quartile_values("QUARTILE.EXC", v0, quart, true)
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_rank(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0, v1] | [v0, v1, _] => {
      let order = if values is [_, _, v2] {
        match value_as_number(v2) {
          Ok(num) => Some(num)
          Err(err) => return err
        }
      } else {
        None
      }
      rank_values(v0, v1, order)
    }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_correl(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0, v1] => correl_values(v0, v1)
    _ => Error(formula_error_value)
  }
}

///|
fn eval_covar(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0, v1] => covar_values("COVAR", v0, v1)
    _ => Error(formula_error_value)
  }
}

///|
fn eval_covariance_p(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0, v1] => covar_values("COVARIANCE.P", v0, v1)
    _ => Error(formula_error_value)
  }
}

///|
fn eval_covariance_s(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0, v1] => covar_values("COVARIANCE.S", v0, v1)
    _ => Error(formula_error_value)
  }
}

///|
fn eval_pearson(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [_, _] => pearson_product_values("PEARSON", values)
    _ => Error(formula_error_value)
  }
}

///|
fn eval_rsq(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [_, _] => pearson_product_values("RSQ", values)
    _ => Error(formula_error_value)
  }
}

///|
fn eval_slope(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [_, _] => pearson_product_values("SLOPE", values)
    _ => Error(formula_error_value)
  }
}

///|
fn eval_intercept(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [_, _] => pearson_product_values("INTERCEPT", values)
    _ => Error(formula_error_value)
  }
}

///|
fn eval_forecast(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [_, _, _] => pearson_product_values("FORECAST", values)
    _ => Error(formula_error_value)
  }
}

///|
fn eval_forecast_linear(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [_, _, _] => pearson_product_values("FORECAST.LINEAR", values)
    _ => Error(formula_error_value)
  }
}

///|
fn eval_growth(
  workbook : Workbook,
  sheet_name : String,
  _name : String,
  args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue raise XlsxError {
  trend_growth_values(workbook, sheet_name, "GROWTH", args, values, ctx)
}

///|
fn eval_trend(
  workbook : Workbook,
  sheet_name : String,
  _name : String,
  args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue raise XlsxError {
  trend_growth_values(workbook, sheet_name, "TREND", args, values, ctx)
}

///|
fn eval_fisher(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] => fisher_value(v0)
    _ => Error(formula_error_value)
  }
}

///|
fn eval_fisherinv(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] => fisherinv_value(v0)
    _ => Error(formula_error_value)
  }
}

///|
fn eval_steyx(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [_, _] => steyx_values(values)
    _ => Error(formula_error_value)
  }
}

///|
fn eval_median(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  median_values(values)
}

///|
fn eval_min(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  min_values(values)
}

///|
fn eval_max(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  max_values(values)
}

///|
fn eval_mina(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  mina_values(values)
}

///|
fn eval_maxa(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  maxa_values(values)
}

///|
fn eval_count(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  count_values(values)
}

///|
fn eval_counta(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  counta_values(values)
}

///|
fn eval_countblank(
  workbook : Workbook,
  sheet_name : String,
  _name : String,
  args : ArrayView[Expr],
  _values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue raise XlsxError {
  match args {
    [a0] => {
      let range_values = eval_range_expr(workbook, sheet_name, a0, ctx)
      countblank_values(range_values)
    }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_frequency(
  workbook : Workbook,
  sheet_name : String,
  _name : String,
  args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue raise XlsxError {
  frequency_values(workbook, sheet_name, args, values, ctx)
}

///|
fn eval_countif(
  workbook : Workbook,
  sheet_name : String,
  _name : String,
  args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue raise XlsxError {
  match args {
    [a0, _] => {
      let range_values = eval_range_expr(workbook, sheet_name, a0, ctx)
      countif_values(range_values, values[1])
    }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_countifs(
  workbook : Workbook,
  sheet_name : String,
  _name : String,
  args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue raise XlsxError {
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
}

///|
fn eval_daverage(
  workbook : Workbook,
  sheet_name : String,
  name : String,
  args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue raise XlsxError {
  match args {
    [a0, _, a2] => {
      let database = eval_range_expr(workbook, sheet_name, a0, ctx)
      let criteria = eval_range_expr(workbook, sheet_name, a2, ctx)
      database_values(name, database, values[1], criteria)
    }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_dcount(
  workbook : Workbook,
  sheet_name : String,
  name : String,
  args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue raise XlsxError {
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
}

///|
fn eval_dget(
  workbook : Workbook,
  sheet_name : String,
  _name : String,
  args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue raise XlsxError {
  match args {
    [a0, _, a2] => {
      let database = eval_range_expr(workbook, sheet_name, a0, ctx)
      let criteria = eval_range_expr(workbook, sheet_name, a2, ctx)
      dget_values(database, values[1], criteria)
    }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_averageif(
  workbook : Workbook,
  sheet_name : String,
  _name : String,
  args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue raise XlsxError {
  match args {
    [a0, _] | [a0, _, _] => {
      let range_values = eval_range_expr(workbook, sheet_name, a0, ctx)
      let average_range = if args is [_, _, a2] {
        Some(eval_range_expr(workbook, sheet_name, a2, ctx))
      } else {
        None
      }
      averageif_values(range_values, values[1], average_range)
    }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_averageifs(
  workbook : Workbook,
  sheet_name : String,
  _name : String,
  args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue raise XlsxError {
  if args.length() >= 3 {
    if args.length() % 2 != 1 {
      Error(formula_error_na)
    } else {
      let average_range = eval_range_expr(workbook, sheet_name, args[0], ctx)
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
}

///|
fn eval_maxifs(
  workbook : Workbook,
  sheet_name : String,
  _name : String,
  args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue raise XlsxError {
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
}

///|
fn eval_minifs(
  workbook : Workbook,
  sheet_name : String,
  _name : String,
  args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue raise XlsxError {
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
}

///|
fn eval_permut(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0, v1] =>
      match (value_as_number(v0), value_as_number(v1)) {
        (Ok(num), Ok(chosen)) =>
          if num < chosen {
            Error(formula_error_na)
          } else {
            let result = factorial_double(num) / factorial_double(num - chosen)
            Number(round_half_away_from_zero(result))
          }
        (Err(err), _) => err
        (_, Err(err)) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_permutationa(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0, v1] =>
      match (value_as_number(v0), value_as_number(v1)) {
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
    _ => Error(formula_error_value)
  }
}

///|
fn eval_weibull(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  weibull_value(values)
}

///|
fn eval_weibulldotdist(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  weibull_value(values)
}

///|
fn eval_betadotdist(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  beta_dist_values(values)
}

///|
fn eval_betadist(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  betadist_values(values)
}

///|
fn eval_betainv(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  betainv_values(values)
}

///|
fn eval_betadotinv(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  betainv_values(values)
}

///|
fn eval_confidence(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  confidence_values(values)
}

///|
fn eval_confidencedotnorm(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  confidence_values(values)
}

///|
fn eval_confidencedott(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  confidence_t_values(values)
}

///|
fn eval_normdotdist(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  normdist_values(values)
}

///|
fn eval_normdist(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  normdist_values(values)
}

///|
fn eval_normdotinv(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  norminv_values(values)
}

///|
fn eval_norminv(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  norminv_values(values)
}

///|
fn eval_normdotsdotdist(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  norm_s_dist_values(values)
}

///|
fn eval_normsdist(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  norms_dist_values(values)
}

///|
fn eval_normdotsdotinv(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  norm_s_inv_values(values)
}

///|
fn eval_normsinv(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  norms_inv_values(values)
}

///|
fn eval_lognormdotdist(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  lognorm_dist_values(values)
}

///|
fn eval_lognormdist(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  lognormdist_values(values)
}

///|
fn eval_loginv(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  loginv_values(values)
}

///|
fn eval_lognormdotinv(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  loginv_values(values)
}

///|
fn eval_gamma(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  gamma_value(values)
}

///|
fn eval_gammadotdist(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  gamma_dist_values(values)
}

///|
fn eval_gammadist(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  gamma_dist_values(values)
}

///|
fn eval_gammadotinv(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  gamma_inv_values(values)
}

///|
fn eval_gammainv(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  gamma_inv_values(values)
}

///|
fn eval_gammaln(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  gammaln_values(values)
}

///|
fn eval_gammalndotprecise(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  gammaln_precise_values(values)
}

///|
fn eval_expondotdist(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  expon_dist_values(values)
}

///|
fn eval_expondist(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  expon_dist_values(values)
}

///|
fn eval_poissondotdist(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  poisson_values(values)
}

///|
fn eval_poisson(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  poisson_values(values)
}

///|
fn eval_prob(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  prob_values(values)
}

///|
fn eval_binomdotdist(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  binomdist_values(values)
}

///|
fn eval_binomdist(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  binomdist_values(values)
}

///|
fn eval_binomdotdistdotrange(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  binom_dist_range_values(values)
}

///|
fn eval_binomdotinv(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  binom_inv_values(values)
}

///|
fn eval_critbinom(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  binom_inv_values(values)
}

///|
fn eval_hypgeomdotdist(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  hypgeom_dist_values(values)
}

///|
fn eval_hypgeomdist(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  hypgeomdist_values(values)
}

///|
fn eval_negbinomdotdist(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  negbinom_dist_values(values)
}

///|
fn eval_negbinomdist(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  negbinomdist_values(values)
}

///|
fn eval_gauss(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  gauss_value(values)
}

///|
fn eval_phi(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  phi_value(values)
}

///|
fn eval_chidist(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  chidist_values(values)
}

///|
fn eval_chiinv(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  chiinv_values(values)
}

///|
fn eval_chisqdotdist(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  chisq_dist_values(values)
}

///|
fn eval_chisqdotdistdotrt(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  chidist_values(values)
}

///|
fn eval_chisqdotinv(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  chisq_inv_values(values)
}

///|
fn eval_chisqdotinvdotrt(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  chiinv_values(values)
}

///|
fn eval_chitest(
  workbook : Workbook,
  sheet_name : String,
  _name : String,
  args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue raise XlsxError {
  chitest_values(workbook, sheet_name, args, values, ctx)
}

///|
fn eval_chisqdottest(
  workbook : Workbook,
  sheet_name : String,
  _name : String,
  args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue raise XlsxError {
  chitest_values(workbook, sheet_name, args, values, ctx)
}

///|
fn eval_fdotdist(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  fdist_values(values)
}

///|
fn eval_fdist(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  fdist_rt_values(values)
}

///|
fn eval_fdotdistdotrt(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  fdist_rt_values(values)
}

///|
fn eval_fdotinv(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  finv_values(values)
}

///|
fn eval_fdotinvdotrt(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  finv_rt_values(values)
}

///|
fn eval_finv(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  finv_rt_values(values)
}

///|
fn eval_ftest(
  workbook : Workbook,
  sheet_name : String,
  _name : String,
  args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue raise XlsxError {
  ftest_values(workbook, sheet_name, args, values, ctx)
}

///|
fn eval_fdottest(
  workbook : Workbook,
  sheet_name : String,
  _name : String,
  args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue raise XlsxError {
  ftest_values(workbook, sheet_name, args, values, ctx)
}

///|
fn eval_tdotdist(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  tdist_values(values)
}

///|
fn eval_tdotdistdot2t(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  tdist_2t_values(values)
}

///|
fn eval_tdotdistdotrt(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  tdist_rt_values(values)
}

///|
fn eval_tdist(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  tdist_legacy_values(values)
}

///|
fn eval_tdotinv(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  tinv_values(values)
}

///|
fn eval_tdotinvdot2t(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  tinv_2t_values(values)
}

///|
fn eval_tinv(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  tinv_2t_values(values)
}

///|
fn eval_tdottest(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  ttest_values(values)
}

///|
fn eval_ttest(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  ttest_values(values)
}

///|
fn eval_zdottest(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  ztest_values(values)
}

///|
fn eval_ztest(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  ztest_values(values)
}
