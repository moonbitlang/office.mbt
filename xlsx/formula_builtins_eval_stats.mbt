///|
fn eval_stdev(call : EvalCall) -> FormulaValue {
  match call.values {
    [_, ..] => stdev_values(false, call.values)
    [] => Error(formula_error_value)
  }
}

///|
fn eval_stdeva(call : EvalCall) -> FormulaValue {
  match call.values {
    [_, ..] => stdev_values(true, call.values)
    [] => Error(formula_error_value)
  }
}

///|
fn eval_stdevp(call : EvalCall) -> FormulaValue {
  match call.values {
    [_, ..] =>
      match variance_values(call.values, false, false) {
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
fn eval_stdevpa(call : EvalCall) -> FormulaValue {
  match call.values {
    [_, ..] =>
      match variance_values(call.values, false, true) {
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
fn eval_var(call : EvalCall) -> FormulaValue {
  match call.values {
    [_, ..] => variance_values(call.values, true, false)
    [] => Error(formula_error_value)
  }
}

///|
fn eval_vara(call : EvalCall) -> FormulaValue {
  match call.values {
    [_, ..] => variance_values(call.values, true, true)
    [] => Error(formula_error_value)
  }
}

///|
fn eval_varp(call : EvalCall) -> FormulaValue {
  match call.values {
    [_, ..] => variance_values(call.values, false, false)
    [] => Error(formula_error_value)
  }
}

///|
fn eval_varpa(call : EvalCall) -> FormulaValue {
  match call.values {
    [_, ..] => variance_values(call.values, false, true)
    [] => Error(formula_error_value)
  }
}

///|
fn eval_avedev(call : EvalCall) -> FormulaValue {
  match call.values {
    [_, ..] => avedev_values(call.values)
    [] => Error(formula_error_value)
  }
}

///|
fn eval_devsq(call : EvalCall) -> FormulaValue {
  match call.values {
    [_, ..] => devsq_values(call.values)
    [] => Error(formula_error_value)
  }
}

///|
fn eval_geomean(call : EvalCall) -> FormulaValue {
  match call.values {
    [_, ..] => geomean_values(call.values)
    [] => Error(formula_error_value)
  }
}

///|
fn eval_harmean(call : EvalCall) -> FormulaValue {
  match call.values {
    [_, ..] => harmean_values(call.values)
    [] => Error(formula_error_value)
  }
}

///|
fn eval_kurt(call : EvalCall) -> FormulaValue {
  match call.values {
    [_, ..] => kurt_values(call.values)
    [] => Error(formula_error_value)
  }
}

///|
fn eval_skew(call : EvalCall) -> FormulaValue {
  match call.values {
    [_, ..] => skew_values("SKEW", call.values)
    [] => Error(formula_error_value)
  }
}

///|
fn eval_skew_p(call : EvalCall) -> FormulaValue {
  match call.values {
    [_, ..] => skew_values("SKEW.P", call.values)
    [] => Error(formula_error_value)
  }
}

///|
fn eval_standardize(call : EvalCall) -> FormulaValue {
  match call.values {
    [_, _, _] => standardize_values(call.values)
    _ => Error(formula_error_value)
  }
}

///|
fn eval_large(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0, v1] => kth_values("LARGE", v0, v1)
    _ => Error(formula_error_value)
  }
}

///|
fn eval_small(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0, v1] => kth_values("SMALL", v0, v1)
    _ => Error(formula_error_value)
  }
}

///|
fn eval_mode(call : EvalCall) -> FormulaValue {
  match call.values {
    [_, ..] => mode_values(call.values)
    [] => Error(formula_error_value)
  }
}

///|
fn eval_mode_sngl(call : EvalCall) -> FormulaValue {
  match call.values {
    [_, ..] => mode_values(call.values)
    [] => Error(formula_error_value)
  }
}

///|
fn eval_mode_mult(call : EvalCall) -> FormulaValue {
  match call.values {
    [_, ..] => mode_mult_values(call.values)
    [] => Error(formula_error_value)
  }
}

///|
fn eval_percentile(call : EvalCall) -> FormulaValue {
  match call.values {
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
fn eval_percentile_inc(call : EvalCall) -> FormulaValue {
  match call.values {
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
fn eval_percentile_exc(call : EvalCall) -> FormulaValue {
  match call.values {
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
fn eval_percentrank(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0, v1] | [v0, v1, _] =>
      match value_as_number(v1) {
        Ok(x) => {
          let significance = if call.values is [_, _, v2] {
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
fn eval_percentrank_inc(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0, v1] | [v0, v1, _] =>
      match value_as_number(v1) {
        Ok(x) => {
          let significance = if call.values is [_, _, v2] {
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
fn eval_percentrank_exc(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0, v1] | [v0, v1, _] =>
      match value_as_number(v1) {
        Ok(x) => {
          let significance = if call.values is [_, _, v2] {
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
fn eval_quartile(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0, v1] =>
      match value_as_number(v1) {
        Ok(quart) => quartile_values("QUARTILE", v0, quart, false)
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_quartile_inc(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0, v1] =>
      match value_as_number(v1) {
        Ok(quart) => quartile_values("QUARTILE.INC", v0, quart, false)
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_quartile_exc(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0, v1] =>
      match value_as_number(v1) {
        Ok(quart) => quartile_values("QUARTILE.EXC", v0, quart, true)
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_rank(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0, v1] | [v0, v1, _] => {
      let order = if call.values is [_, _, v2] {
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
fn eval_correl(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0, v1] => correl_values(v0, v1)
    _ => Error(formula_error_value)
  }
}

///|
fn eval_covar(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0, v1] => covar_values("COVAR", v0, v1)
    _ => Error(formula_error_value)
  }
}

///|
fn eval_covariance_p(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0, v1] => covar_values("COVARIANCE.P", v0, v1)
    _ => Error(formula_error_value)
  }
}

///|
fn eval_covariance_s(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0, v1] => covar_values("COVARIANCE.S", v0, v1)
    _ => Error(formula_error_value)
  }
}

///|
fn eval_pearson(call : EvalCall) -> FormulaValue {
  match call.values {
    [_, _] => pearson_product_values("PEARSON", call.values)
    _ => Error(formula_error_value)
  }
}

///|
fn eval_rsq(call : EvalCall) -> FormulaValue {
  match call.values {
    [_, _] => pearson_product_values("RSQ", call.values)
    _ => Error(formula_error_value)
  }
}

///|
fn eval_slope(call : EvalCall) -> FormulaValue {
  match call.values {
    [_, _] => pearson_product_values("SLOPE", call.values)
    _ => Error(formula_error_value)
  }
}

///|
fn eval_intercept(call : EvalCall) -> FormulaValue {
  match call.values {
    [_, _] => pearson_product_values("INTERCEPT", call.values)
    _ => Error(formula_error_value)
  }
}

///|
fn eval_forecast(call : EvalCall) -> FormulaValue {
  match call.values {
    [_, _, _] => pearson_product_values("FORECAST", call.values)
    _ => Error(formula_error_value)
  }
}

///|
fn eval_forecast_linear(call : EvalCall) -> FormulaValue {
  match call.values {
    [_, _, _] => pearson_product_values("FORECAST.LINEAR", call.values)
    _ => Error(formula_error_value)
  }
}

///|
fn eval_growth(call : EvalCall) -> FormulaValue raise XlsxError {
  trend_growth_values(
    call.workbook,
    call.sheet_name,
    "GROWTH",
    call.args,
    call.values,
    call.ctx,
  )
}

///|
fn eval_trend(call : EvalCall) -> FormulaValue raise XlsxError {
  trend_growth_values(
    call.workbook,
    call.sheet_name,
    "TREND",
    call.args,
    call.values,
    call.ctx,
  )
}

///|
fn eval_fisher(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] => fisher_value(v0)
    _ => Error(formula_error_value)
  }
}

///|
fn eval_fisherinv(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] => fisherinv_value(v0)
    _ => Error(formula_error_value)
  }
}

///|
fn eval_steyx(call : EvalCall) -> FormulaValue {
  match call.values {
    [_, _] => steyx_values(call.values)
    _ => Error(formula_error_value)
  }
}

///|
fn eval_countblank(call : EvalCall) -> FormulaValue raise XlsxError {
  match call.args {
    [a0] => {
      let range_values = eval_range_expr(
        call.workbook,
        call.sheet_name,
        a0,
        call.ctx,
      )
      countblank_values(range_values)
    }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_countif(call : EvalCall) -> FormulaValue raise XlsxError {
  match call.args {
    [a0, _] => {
      let range_values = eval_range_expr(
        call.workbook,
        call.sheet_name,
        a0,
        call.ctx,
      )
      countif_values(range_values, call.values[1])
    }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_countifs(call : EvalCall) -> FormulaValue raise XlsxError {
  if call.args.length() >= 2 {
    if call.args.length() % 2 != 0 {
      Error(formula_error_na)
    } else {
      let ranges : Array[RangeValues] = []
      let criterias : Array[FormulaCriteria] = []
      for i in 0..<(call.args.length() / 2) {
        let range_values = eval_range_expr(
          call.workbook,
          call.sheet_name,
          call.args[i * 2],
          call.ctx,
        )
        ranges.push(range_values)
        criterias.push(parse_formula_criteria(call.values[i * 2 + 1]))
      }
      let matches = ifs_match(ranges, criterias)
      Number(Double::from_int(matches.length()))
    }
  } else {
    Error(formula_error_value)
  }
}

///|
fn eval_daverage(call : EvalCall) -> FormulaValue raise XlsxError {
  match call.args {
    [a0, _, a2] => {
      let database = eval_range_expr(
        call.workbook,
        call.sheet_name,
        a0,
        call.ctx,
      )
      let criteria = eval_range_expr(
        call.workbook,
        call.sheet_name,
        a2,
        call.ctx,
      )
      database_values(call.name, database, call.values[1], criteria)
    }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_dcount(call : EvalCall) -> FormulaValue raise XlsxError {
  if call.args.length() >= 2 && call.args.length() <= 3 {
    let database = eval_range_expr(
      call.workbook,
      call.sheet_name,
      call.args[0],
      call.ctx,
    )
    let field = if call.args.length() == 3 {
      match call.args[1] {
        FuncCall(name, _) if name == "" => Empty
        _ => call.values[1]
      }
    } else {
      Empty
    }
    let criteria_idx = if call.args.length() == 3 { 2 } else { 1 }
    let criteria = eval_range_expr(
      call.workbook,
      call.sheet_name,
      call.args[criteria_idx],
      call.ctx,
    )
    dcount_values(call.name, database, field, criteria)
  } else {
    Error(formula_error_value)
  }
}

///|
fn eval_dget(call : EvalCall) -> FormulaValue raise XlsxError {
  match call.args {
    [a0, _, a2] => {
      let database = eval_range_expr(
        call.workbook,
        call.sheet_name,
        a0,
        call.ctx,
      )
      let criteria = eval_range_expr(
        call.workbook,
        call.sheet_name,
        a2,
        call.ctx,
      )
      dget_values(database, call.values[1], criteria)
    }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_averageif(call : EvalCall) -> FormulaValue raise XlsxError {
  match call.args {
    [a0, _] | [a0, _, _] => {
      let range_values = eval_range_expr(
        call.workbook,
        call.sheet_name,
        a0,
        call.ctx,
      )
      let average_range = if call.args is [_, _, a2] {
        Some(eval_range_expr(call.workbook, call.sheet_name, a2, call.ctx))
      } else {
        None
      }
      averageif_values(range_values, call.values[1], average_range)
    }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_averageifs(call : EvalCall) -> FormulaValue raise XlsxError {
  if call.args.length() >= 3 {
    if call.args.length() % 2 != 1 {
      Error(formula_error_na)
    } else {
      let average_range = eval_range_expr(
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
fn eval_maxifs(call : EvalCall) -> FormulaValue raise XlsxError {
  if call.args.length() >= 3 {
    if call.args.length() % 2 != 1 {
      Error(formula_error_na)
    } else {
      let max_range = eval_range_expr(
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
      maxifs_values(max_range, matches)
    }
  } else {
    Error(formula_error_value)
  }
}

///|
fn eval_minifs(call : EvalCall) -> FormulaValue raise XlsxError {
  if call.args.length() >= 3 {
    if call.args.length() % 2 != 1 {
      Error(formula_error_na)
    } else {
      let min_range = eval_range_expr(
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
      minifs_values(min_range, matches)
    }
  } else {
    Error(formula_error_value)
  }
}

///|
fn eval_permut(call : EvalCall) -> FormulaValue {
  match call.values {
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
fn eval_permutationa(call : EvalCall) -> FormulaValue {
  match call.values {
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
fn eval_weibulldotdist(call : EvalCall) -> FormulaValue {
  weibull_value(call.values)
}

///|
fn eval_confidencedotnorm(call : EvalCall) -> FormulaValue {
  confidence_values(call.values)
}

///|
fn eval_confidencedott(call : EvalCall) -> FormulaValue {
  confidence_t_values(call.values)
}

///|
fn eval_normdotsdotdist(call : EvalCall) -> FormulaValue {
  norm_s_dist_values(call.values)
}

///|
fn eval_normdotsdotinv(call : EvalCall) -> FormulaValue {
  norm_s_inv_values(call.values)
}

///|
fn eval_lognormdotdist(call : EvalCall) -> FormulaValue {
  lognorm_dist_values(call.values)
}

///|
fn eval_lognormdotinv(call : EvalCall) -> FormulaValue {
  loginv_values(call.values)
}

///|
fn eval_gammadotdist(call : EvalCall) -> FormulaValue {
  gamma_dist_values(call.values)
}

///|
fn eval_gammalndotprecise(call : EvalCall) -> FormulaValue {
  gammaln_precise_values(call.values)
}

///|
fn eval_expondotdist(call : EvalCall) -> FormulaValue {
  expon_dist_values(call.values)
}

///|
fn eval_poissondotdist(call : EvalCall) -> FormulaValue {
  poisson_values(call.values)
}

///|
fn eval_binomdotdist(call : EvalCall) -> FormulaValue {
  binomdist_values(call.values)
}

///|
fn eval_binomdotdistdotrange(call : EvalCall) -> FormulaValue {
  binom_dist_range_values(call.values)
}

///|
fn eval_hypgeomdotdist(call : EvalCall) -> FormulaValue {
  hypgeom_dist_values(call.values)
}

///|
fn eval_negbinomdotdist(call : EvalCall) -> FormulaValue {
  negbinom_dist_values(call.values)
}

///|
fn eval_chisqdotdist(call : EvalCall) -> FormulaValue {
  chisq_dist_values(call.values)
}

///|
fn eval_chisqdotdistdotrt(call : EvalCall) -> FormulaValue {
  chidist_values(call.values)
}

///|
fn eval_chisqdotinvdotrt(call : EvalCall) -> FormulaValue {
  chiinv_values(call.values)
}

///|
fn eval_chisqdottest(call : EvalCall) -> FormulaValue raise XlsxError {
  chitest_values(
    call.workbook,
    call.sheet_name,
    call.args,
    call.values,
    call.ctx,
  )
}

///|
fn eval_fdottest(call : EvalCall) -> FormulaValue raise XlsxError {
  ftest_values(call.workbook, call.sheet_name, call.args, call.values, call.ctx)
}
