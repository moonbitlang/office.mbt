///|
fn eval_function(
  workbook : Workbook,
  sheet_name : String,
  name : String,
  args : ArrayView[Expr],
  ctx : CalcContext,
) -> FormulaValue raise XlsxError {
  match name {
    "ROW" =>
      match args {
        [] =>
          current_cell_rc(ctx).map_or(Error(formula_error_value), rc => {
            Number(Double::from_int(rc.0))
          })
        [arg] =>
          ref_bounds_opt(arg).map_or(Error(formula_error_value), bounds => {
            let (row1, _col1, row2, _col2) = bounds
            Number(Double::from_int(Int::min(row1, row2)))
          })
        _ => Error(formula_error_value)
      }
    "COLUMN" =>
      match args {
        [] =>
          current_cell_rc(ctx).map_or(Error(formula_error_value), rc => {
            Number(Double::from_int(rc.1))
          })
        [arg] =>
          ref_bounds_opt(arg).map_or(Error(formula_error_value), bounds => {
            let (_row1, col1, _row2, col2) = bounds
            Number(Double::from_int(Int::min(col1, col2)))
          })
        _ => Error(formula_error_value)
      }
    "ROWS" =>
      match args {
        [arg] =>
          ref_bounds_opt(arg).map_or(Error(formula_error_value), bounds => {
            let (row1, _col1, row2, _col2) = bounds
            Number(
              Double::from_int(Int::max(row1, row2) - Int::min(row1, row2) + 1),
            )
          })
        _ => Error(formula_error_value)
      }
    "COLUMNS" =>
      match args {
        [arg] =>
          ref_bounds_opt(arg).map_or(Error(formula_error_value), bounds => {
            let (_row1, col1, _row2, col2) = bounds
            Number(
              Double::from_int(Int::max(col1, col2) - Int::min(col1, col2) + 1),
            )
          })
        _ => Error(formula_error_value)
      }
    "FORMULATEXT" =>
      match args {
        [arg] => formula_text_value(workbook, sheet_name, arg)
        _ => Error(formula_error_value)
      }
    _ => {
      let values : Array[FormulaValue] = []
      for arg in args {
        values.push(eval_expr(workbook, sheet_name, arg, ctx))
      }
      let call : EvalCall = { workbook, sheet_name, name, args, values, ctx, }
      raising_handlers()
      .get(name)
      .map(h => h(call))
      .unwrap_or_else(() => {
        plain_handlers()
        .get(name)
        .map(h => h(call))
        .unwrap_or_else(() => {
          eval_function_unknown(workbook, sheet_name, name, args, ctx)
        })
      })
    }
  }
}

///|
priv struct EvalCall {
  workbook : Workbook
  sheet_name : String
  name : String
  args : ArrayView[Expr]
  values : Array[FormulaValue]
  ctx : CalcContext
}

///|
type RaisingHandler = (EvalCall) -> FormulaValue raise XlsxError

///|
type PlainHandler = (EvalCall) -> FormulaValue

///|
let raising_handlers_cached : @ref.Ref[
  @hashmap.HashMap[String, RaisingHandler]?,
] = Ref(None)

///|
let plain_handlers_cached : @ref.Ref[@hashmap.HashMap[String, PlainHandler]?] = Ref(
  None,
)

///|
fn raising_handlers() -> @hashmap.HashMap[String, RaisingHandler] {
  raising_handlers_cached.val.unwrap_or_else(() => {
    let m = build_raising_handlers()
    raising_handlers_cached.val = Some(m)
    m
  })
}

///|
fn plain_handlers() -> @hashmap.HashMap[String, PlainHandler] {
  plain_handlers_cached.val.unwrap_or_else(() => {
    let m = build_plain_handlers()
    plain_handlers_cached.val = Some(m)
    m
  })
}

///|
fn build_raising_handlers() -> @hashmap.HashMap[String, RaisingHandler] {
  HashMap([
    ("SUMIF", eval_sumif),
    ("SUMPRODUCT", eval_sumproduct),
    ("SUMX2MY2", eval_sumx2my2),
    ("SUMX2PY2", eval_sumx2py2),
    ("SUMXMY2", eval_sumxmy2),
    ("SUMIFS", eval_sumifs),
    ("MDETERM", eval_mdeterm),
    ("MINVERSE", eval_minverse),
    ("MMULT", eval_mmult),
    ("GROWTH", eval_growth),
    ("TREND", eval_trend),
    ("COUNTBLANK", eval_countblank),
    ("COUNTIF", eval_countif),
    ("COUNTIFS", eval_countifs),
    ("DAVERAGE", eval_daverage),
    ("DMAX", eval_daverage),
    ("DMIN", eval_daverage),
    ("DPRODUCT", eval_daverage),
    ("DSTDEV", eval_daverage),
    ("DSTDEVP", eval_daverage),
    ("DSUM", eval_daverage),
    ("DVAR", eval_daverage),
    ("DVARP", eval_daverage),
    ("DCOUNT", eval_dcount),
    ("DCOUNTA", eval_dcount),
    ("DGET", eval_dget),
    ("AVERAGEIF", eval_averageif),
    ("AVERAGEIFS", eval_averageifs),
    ("MAXIFS", eval_maxifs),
    ("MINIFS", eval_minifs),
    ("CHISQdotTEST", eval_chisqdottest),
    ("CHISQ.TEST", eval_chisqdottest),
    ("_XLFN.CHISQ.TEST", eval_chisqdottest),
    ("FdotTEST", eval_fdottest),
    ("F.TEST", eval_fdottest),
    ("_XLFN.F.TEST", eval_fdottest),
    (
      "FREQUENCY",
      call => {
        frequency_values(
          call.workbook,
          call.sheet_name,
          call.args,
          call.values,
          call.ctx,
        )
      },
    ),
    (
      "CHITEST",
      call => {
        chitest_values(
          call.workbook,
          call.sheet_name,
          call.args,
          call.values,
          call.ctx,
        )
      },
    ),
    (
      "FTEST",
      call => {
        ftest_values(
          call.workbook,
          call.sheet_name,
          call.args,
          call.values,
          call.ctx,
        )
      },
    ),
    ("ARRAYTOTEXT", eval_arraytotext),
    ("TRANSPOSE", eval_transpose),
    ("TAKE", eval_take),
    ("_XLFN.TAKE", eval_take),
    ("DROP", eval_drop),
    ("_XLFN.DROP", eval_drop),
    ("CHOOSECOLS", eval_choosecols),
    ("_XLFN.CHOOSECOLS", eval_choosecols),
    ("CHOOSEROWS", eval_chooserows),
    ("_XLFN.CHOOSEROWS", eval_chooserows),
    ("HSTACK", eval_hstack),
    ("_XLFN.HSTACK", eval_hstack),
    ("VSTACK", eval_vstack),
    ("_XLFN.VSTACK", eval_vstack),
    ("EXPAND", eval_expand),
    ("_XLFN.EXPAND", eval_expand),
    ("WRAPROWS", eval_wraprows),
    ("_XLFN.WRAPROWS", eval_wraprows),
    ("WRAPCOLS", eval_wrapcols),
    ("_XLFN.WRAPCOLS", eval_wrapcols),
    ("TOCOL", eval_tocol),
    ("_XLFN.TOCOL", eval_tocol),
    ("TOROW", eval_torow),
    ("_XLFN.TOROW", eval_torow),
    ("SORT", eval_sort),
    ("_XLFN.SORT", eval_sort),
    ("SORTBY", eval_sortby),
    ("_XLFN.SORTBY", eval_sortby),
    ("FILTER", eval_filter),
    ("_XLFN.FILTER", eval_filter),
    ("UNIQUE", eval_unique),
    ("_XLFN.UNIQUE", eval_unique),
    ("INDEX", eval_index),
    ("MATCH", eval_match),
    ("VLOOKUP", eval_vlookup),
    ("HLOOKUP", eval_hlookup),
    ("LOOKUP", eval_lookup),
    ("XLOOKUP", eval_xlookup),
    ("_XLFN.XLOOKUP", eval_xlookup),
    ("ADDRESS", eval_address),
    ("INDIRECT", eval_indirect),
  ])
}

///|
fn build_plain_handlers() -> @hashmap.HashMap[String, PlainHandler] {
  HashMap([
    ("SIGN", eval_sign),
    ("SERIESSUM", eval_seriessum),
    ("COMBIN", eval_combin),
    ("COMBINA", eval_combina),
    ("_XLFN.COMBINA", eval_combina),
    ("COMPLEX", eval_complex),
    ("FACT", eval_fact),
    ("FACTDOUBLE", eval_factdouble),
    ("MUNIT", eval_munit),
    ("_XLFN.MUNIT", eval_munit),
    ("ABS", eval_abs),
    ("INT", eval_int),
    ("LN", eval_ln),
    ("EXP", eval_exp),
    ("DECIMAL", eval_decimal),
    ("_XLFN.DECIMAL", eval_decimal),
    ("ROMAN", eval_roman),
    ("ARABIC", eval_arabic),
    ("_XLFN.ARABIC", eval_arabic),
    ("BIN2DEC", eval_bin2dec),
    ("BIN2HEX", eval_bin2hex),
    ("BIN2OCT", eval_bin2oct),
    ("HEX2BIN", eval_hex2bin),
    ("HEX2DEC", eval_hex2dec),
    ("HEX2OCT", eval_hex2oct),
    ("OCT2BIN", eval_oct2bin),
    ("OCT2DEC", eval_oct2dec),
    ("OCT2HEX", eval_oct2hex),
    ("BESSELI", eval_besseli),
    ("BESSELJ", eval_besselj),
    ("BESSELK", eval_besselk),
    ("BESSELY", eval_bessely),
    ("DELTA", eval_delta),
    ("ERF", eval_erf),
    ("ERFdotPRECISE", eval_erfdotprecise),
    ("ERF.PRECISE", eval_erfdotprecise),
    ("_XLFN.ERF.PRECISE", eval_erfdotprecise),
    ("ERFC", eval_erfc),
    ("ERFCdotPRECISE", eval_erfcdotprecise),
    ("ERFC.PRECISE", eval_erfcdotprecise),
    ("_XLFN.ERFC.PRECISE", eval_erfcdotprecise),
    ("GESTEP", eval_gestep),
    ("ACOS", eval_acos),
    ("ACOSH", eval_acosh),
    ("ACOT", eval_acot),
    ("_XLFN.ACOT", eval_acot),
    ("ACOTH", eval_acoth),
    ("_XLFN.ACOTH", eval_acoth),
    ("ASIN", eval_asin),
    ("ASINH", eval_asinh),
    ("ATAN", eval_atan),
    ("ATANH", eval_atanh),
    ("ATAN2", eval_atan2),
    ("COS", eval_cos),
    ("COSH", eval_cosh),
    ("SIN", eval_sin),
    ("SINH", eval_sinh),
    ("TAN", eval_tan),
    ("TANH", eval_tanh),
    ("COT", eval_cot),
    ("_XLFN.COT", eval_cot),
    ("COTH", eval_coth),
    ("_XLFN.COTH", eval_coth),
    ("CSC", eval_csc),
    ("_XLFN.CSC", eval_csc),
    ("CSCH", eval_csch),
    ("_XLFN.CSCH", eval_csch),
    ("SEC", eval_sec),
    ("_XLFN.SEC", eval_sec),
    ("SECH", eval_sech),
    ("_XLFN.SECH", eval_sech),
    ("DEGREES", eval_degrees),
    ("RADIANS", eval_radians),
    ("RAND", eval_rand),
    ("RANDBETWEEN", eval_randbetween),
    ("PI", eval_pi),
    ("SQRTPI", eval_sqrtpi),
    ("LOG", eval_log),
    ("LOG10", eval_log10),
    ("IMABS", eval_imabs),
    ("IMAGINARY", eval_imaginary),
    ("IMARGUMENT", eval_imargument),
    ("IMCONJUGATE", eval_imconjugate),
    ("IMCOS", eval_imcos),
    ("IMCOSH", eval_imcosh),
    ("IMCOT", eval_imcot),
    ("IMCSC", eval_imcsc),
    ("IMCSCH", eval_imcsch),
    ("IMDIV", eval_imdiv),
    ("IMEXP", eval_imexp),
    ("IMLN", eval_imln),
    ("IMLOG10", eval_imlog10),
    ("IMLOG2", eval_imlog2),
    ("IMPOWER", eval_impower),
    ("IMPRODUCT", eval_improduct),
    ("IMREAL", eval_imreal),
    ("IMSEC", eval_imsec),
    ("IMSECH", eval_imsech),
    ("IMSIN", eval_imsin),
    ("IMSINH", eval_imsinh),
    ("IMSQRT", eval_imsqrt),
    ("IMSUB", eval_imsub),
    ("IMSUM", eval_imsum),
    ("IMTAN", eval_imtan),
    ("FLOOR", eval_floor),
    ("CEILING", eval_ceiling),
    ("CEILINGdotMATH", eval_ceilingdotmath),
    ("CEILING.MATH", eval_ceilingdotmath),
    ("_XLFN.CEILING.MATH", eval_ceilingdotmath),
    ("CEILINGdotPRECISE", eval_ceilingdotprecise),
    ("CEILING.PRECISE", eval_ceilingdotprecise),
    ("_XLFN.CEILING.PRECISE", eval_ceilingdotprecise),
    ("FLOORdotMATH", eval_floordotmath),
    ("FLOOR.MATH", eval_floordotmath),
    ("_XLFN.FLOOR.MATH", eval_floordotmath),
    ("FLOORdotPRECISE", eval_floordotprecise),
    ("FLOOR.PRECISE", eval_floordotprecise),
    ("_XLFN.FLOOR.PRECISE", eval_floordotprecise),
    ("ISOdotCEILING", eval_isodotceiling),
    ("ISO.CEILING", eval_isodotceiling),
    ("_XLFN.ISO.CEILING", eval_isodotceiling),
    ("TRUNC", eval_trunc),
    ("ROUND", eval_round),
    ("ROUNDUP", eval_roundup),
    ("ROUNDDOWN", eval_rounddown),
    ("SQRT", eval_sqrt),
    ("POWER", eval_power),
    ("EVEN", eval_even),
    ("ODD", eval_odd),
    ("MROUND", eval_mround),
    ("MOD", eval_mod),
    ("QUOTIENT", eval_quotient),
    ("SUM", call => sum_values(call.values)),
    ("SUBTOTAL", call => subtotal_values(call.values)),
    ("AGGREGATE", call => aggregate_values(call.values)),
    ("PRODUCT", call => product_values(call.values)),
    ("SUMSQ", call => sumsq_values(call.values)),
    ("GCD", call => gcd_values(call.values)),
    ("LCM", call => lcm_values(call.values)),
    ("MULTINOMIAL", call => multinomial_values(call.values)),
    ("BASE", call => base_values(call.values)),
    ("DEC2BIN", call => dec2x_values("DEC2BIN", call.values)),
    ("DEC2HEX", call => dec2x_values("DEC2HEX", call.values)),
    ("DEC2OCT", call => dec2x_values("DEC2OCT", call.values)),
    ("CONVERT", call => convert_values(call.values)),
    ("EUROCONVERT", call => euroconvert_values(call.values)),
    ("BITAND", call => bitwise_values("BITAND", call.values)),
    ("BITLSHIFT", call => bitwise_values("BITLSHIFT", call.values)),
    ("BITOR", call => bitwise_values("BITOR", call.values)),
    ("BITRSHIFT", call => bitwise_values("BITRSHIFT", call.values)),
    ("BITXOR", call => bitwise_values("BITXOR", call.values)),
    ("RANDARRAY", call => randarray_values(call.values)),
    ("_XLFN.RANDARRAY", call => randarray_values(call.values)),
    ("STDEV", eval_stdev),
    ("STDEV.S", eval_stdev),
    ("STDEVA", eval_stdeva),
    ("STDEVP", eval_stdevp),
    ("STDEV.P", eval_stdevp),
    ("STDEVPA", eval_stdevpa),
    ("VAR", eval_var),
    ("VAR.S", eval_var),
    ("VARA", eval_vara),
    ("VARP", eval_varp),
    ("VAR.P", eval_varp),
    ("VARPA", eval_varpa),
    ("AVEDEV", eval_avedev),
    ("DEVSQ", eval_devsq),
    ("GEOMEAN", eval_geomean),
    ("HARMEAN", eval_harmean),
    ("KURT", eval_kurt),
    ("SKEW", eval_skew),
    ("SKEW.P", eval_skew_p),
    ("STANDARDIZE", eval_standardize),
    ("LARGE", eval_large),
    ("SMALL", eval_small),
    ("MODE", eval_mode),
    ("MODE.SNGL", eval_mode_sngl),
    ("MODE.MULT", eval_mode_mult),
    ("PERCENTILE", eval_percentile),
    ("PERCENTILE.INC", eval_percentile_inc),
    ("PERCENTILE.EXC", eval_percentile_exc),
    ("PERCENTRANK", eval_percentrank),
    ("PERCENTRANK.INC", eval_percentrank_inc),
    ("PERCENTRANK.EXC", eval_percentrank_exc),
    ("QUARTILE", eval_quartile),
    ("QUARTILE.INC", eval_quartile_inc),
    ("QUARTILE.EXC", eval_quartile_exc),
    ("RANK", eval_rank),
    ("RANK.EQ", eval_rank),
    ("CORREL", eval_correl),
    ("COVAR", eval_covar),
    ("COVARIANCE.P", eval_covariance_p),
    ("COVARIANCE.S", eval_covariance_s),
    ("PEARSON", eval_pearson),
    ("RSQ", eval_rsq),
    ("SLOPE", eval_slope),
    ("INTERCEPT", eval_intercept),
    ("FORECAST", eval_forecast),
    ("FORECAST.LINEAR", eval_forecast_linear),
    ("FISHER", eval_fisher),
    ("FISHERINV", eval_fisherinv),
    ("STEYX", eval_steyx),
    ("PERMUT", eval_permut),
    ("PERMUTATIONA", eval_permutationa),
    ("WEIBULLdotDIST", eval_weibulldotdist),
    ("WEIBULL.DIST", eval_weibulldotdist),
    ("_XLFN.WEIBULL.DIST", eval_weibulldotdist),
    ("CONFIDENCEdotNORM", eval_confidencedotnorm),
    ("CONFIDENCE.NORM", eval_confidencedotnorm),
    ("_XLFN.CONFIDENCE.NORM", eval_confidencedotnorm),
    ("CONFIDENCEdotT", eval_confidencedott),
    ("CONFIDENCE.T", eval_confidencedott),
    ("_XLFN.CONFIDENCE.T", eval_confidencedott),
    ("NORMdotSdotDIST", eval_normdotsdotdist),
    ("NORM.S.DIST", eval_normdotsdotdist),
    ("_XLFN.NORM.S.DIST", eval_normdotsdotdist),
    ("NORMdotSdotINV", eval_normdotsdotinv),
    ("NORM.S.INV", eval_normdotsdotinv),
    ("_XLFN.NORM.S.INV", eval_normdotsdotinv),
    ("LOGNORMdotDIST", eval_lognormdotdist),
    ("LOGNORM.DIST", eval_lognormdotdist),
    ("_XLFN.LOGNORM.DIST", eval_lognormdotdist),
    ("LOGNORMdotINV", eval_lognormdotinv),
    ("LOGNORM.INV", eval_lognormdotinv),
    ("_XLFN.LOGNORM.INV", eval_lognormdotinv),
    ("GAMMAdotDIST", eval_gammadotdist),
    ("GAMMA.DIST", eval_gammadotdist),
    ("_XLFN.GAMMA.DIST", eval_gammadotdist),
    ("GAMMALNdotPRECISE", eval_gammalndotprecise),
    ("GAMMALN.PRECISE", eval_gammalndotprecise),
    ("_XLFN.GAMMALN.PRECISE", eval_gammalndotprecise),
    ("EXPONdotDIST", eval_expondotdist),
    ("EXPON.DIST", eval_expondotdist),
    ("_XLFN.EXPON.DIST", eval_expondotdist),
    ("POISSONdotDIST", eval_poissondotdist),
    ("POISSON.DIST", eval_poissondotdist),
    ("_XLFN.POISSON.DIST", eval_poissondotdist),
    ("BINOMdotDIST", eval_binomdotdist),
    ("BINOM.DIST", eval_binomdotdist),
    ("_XLFN.BINOM.DIST", eval_binomdotdist),
    ("BINOMdotDISTdotRANGE", eval_binomdotdistdotrange),
    ("BINOM.DIST.RANGE", eval_binomdotdistdotrange),
    ("_XLFN.BINOM.DIST.RANGE", eval_binomdotdistdotrange),
    ("HYPGEOMdotDIST", eval_hypgeomdotdist),
    ("HYPGEOM.DIST", eval_hypgeomdotdist),
    ("_XLFN.HYPGEOM.DIST", eval_hypgeomdotdist),
    ("NEGBINOMdotDIST", eval_negbinomdotdist),
    ("NEGBINOM.DIST", eval_negbinomdotdist),
    ("_XLFN.NEGBINOM.DIST", eval_negbinomdotdist),
    ("CHISQdotDIST", eval_chisqdotdist),
    ("CHISQ.DIST", eval_chisqdotdist),
    ("_XLFN.CHISQ.DIST", eval_chisqdotdist),
    ("CHISQdotDISTdotRT", eval_chisqdotdistdotrt),
    ("CHISQ.DIST.RT", eval_chisqdotdistdotrt),
    ("_XLFN.CHISQ.DIST.RT", eval_chisqdotdistdotrt),
    ("CHISQdotINVdotRT", eval_chisqdotinvdotrt),
    ("CHISQ.INV.RT", eval_chisqdotinvdotrt),
    ("_XLFN.CHISQ.INV.RT", eval_chisqdotinvdotrt),
    ("AVERAGE", call => average_values(call.values)),
    ("AVERAGEA", call => averagea_values(call.values)),
    ("TRIMMEAN", call => trimmean_values(call.values)),
    ("MEDIAN", call => median_values(call.values)),
    ("MIN", call => min_values(call.values)),
    ("MAX", call => max_values(call.values)),
    ("MINA", call => mina_values(call.values)),
    ("MAXA", call => maxa_values(call.values)),
    ("COUNT", call => count_values(call.values)),
    ("COUNTA", call => counta_values(call.values)),
    ("WEIBULL", call => weibull_value(call.values)),
    ("BETAdotDIST", call => beta_dist_values(call.values)),
    ("BETA.DIST", call => beta_dist_values(call.values)),
    ("_XLFN.BETA.DIST", call => beta_dist_values(call.values)),
    ("BETADIST", call => betadist_values(call.values)),
    ("BETAINV", call => betainv_values(call.values)),
    ("BETAdotINV", call => betainv_values(call.values)),
    ("BETA.INV", call => betainv_values(call.values)),
    ("_XLFN.BETA.INV", call => betainv_values(call.values)),
    ("CONFIDENCE", call => confidence_values(call.values)),
    ("NORMdotDIST", call => normdist_values(call.values)),
    ("NORM.DIST", call => normdist_values(call.values)),
    ("_XLFN.NORM.DIST", call => normdist_values(call.values)),
    ("NORMDIST", call => normdist_values(call.values)),
    ("NORMdotINV", call => norminv_values(call.values)),
    ("NORM.INV", call => norminv_values(call.values)),
    ("_XLFN.NORM.INV", call => norminv_values(call.values)),
    ("NORMINV", call => norminv_values(call.values)),
    ("NORMSDIST", call => norms_dist_values(call.values)),
    ("NORMSINV", call => norms_inv_values(call.values)),
    ("LOGNORMDIST", call => lognormdist_values(call.values)),
    ("LOGINV", call => loginv_values(call.values)),
    ("GAMMA", call => gamma_value(call.values)),
    ("GAMMADIST", call => gamma_dist_values(call.values)),
    ("GAMMAdotINV", call => gamma_inv_values(call.values)),
    ("GAMMA.INV", call => gamma_inv_values(call.values)),
    ("_XLFN.GAMMA.INV", call => gamma_inv_values(call.values)),
    ("GAMMAINV", call => gamma_inv_values(call.values)),
    ("GAMMALN", call => gammaln_values(call.values)),
    ("EXPONDIST", call => expon_dist_values(call.values)),
    ("POISSON", call => poisson_values(call.values)),
    ("PROB", call => prob_values(call.values)),
    ("BINOMDIST", call => binomdist_values(call.values)),
    ("BINOMdotINV", call => binom_inv_values(call.values)),
    ("BINOM.INV", call => binom_inv_values(call.values)),
    ("_XLFN.BINOM.INV", call => binom_inv_values(call.values)),
    ("CRITBINOM", call => binom_inv_values(call.values)),
    ("HYPGEOMDIST", call => hypgeomdist_values(call.values)),
    ("NEGBINOMDIST", call => negbinomdist_values(call.values)),
    ("GAUSS", call => gauss_value(call.values)),
    ("PHI", call => phi_value(call.values)),
    ("CHIDIST", call => chidist_values(call.values)),
    ("CHIINV", call => chiinv_values(call.values)),
    ("CHISQdotINV", call => chisq_inv_values(call.values)),
    ("CHISQ.INV", call => chisq_inv_values(call.values)),
    ("_XLFN.CHISQ.INV", call => chisq_inv_values(call.values)),
    ("FdotDIST", call => fdist_values(call.values)),
    ("F.DIST", call => fdist_values(call.values)),
    ("_XLFN.F.DIST", call => fdist_values(call.values)),
    ("FDIST", call => fdist_rt_values(call.values)),
    ("FdotDISTdotRT", call => fdist_rt_values(call.values)),
    ("F.DIST.RT", call => fdist_rt_values(call.values)),
    ("_XLFN.F.DIST.RT", call => fdist_rt_values(call.values)),
    ("FdotINV", call => finv_values(call.values)),
    ("F.INV", call => finv_values(call.values)),
    ("_XLFN.F.INV", call => finv_values(call.values)),
    ("FdotINVdotRT", call => finv_rt_values(call.values)),
    ("F.INV.RT", call => finv_rt_values(call.values)),
    ("_XLFN.F.INV.RT", call => finv_rt_values(call.values)),
    ("FINV", call => finv_rt_values(call.values)),
    ("TdotDIST", call => tdist_values(call.values)),
    ("T.DIST", call => tdist_values(call.values)),
    ("_XLFN.T.DIST", call => tdist_values(call.values)),
    ("TdotDISTdot2T", call => tdist_2t_values(call.values)),
    ("T.DIST.2T", call => tdist_2t_values(call.values)),
    ("_XLFN.T.DIST.2T", call => tdist_2t_values(call.values)),
    ("TdotDISTdotRT", call => tdist_rt_values(call.values)),
    ("T.DIST.RT", call => tdist_rt_values(call.values)),
    ("_XLFN.T.DIST.RT", call => tdist_rt_values(call.values)),
    ("TDIST", call => tdist_legacy_values(call.values)),
    ("TdotINV", call => tinv_values(call.values)),
    ("T.INV", call => tinv_values(call.values)),
    ("_XLFN.T.INV", call => tinv_values(call.values)),
    ("TdotINVdot2T", call => tinv_2t_values(call.values)),
    ("T.INV.2T", call => tinv_2t_values(call.values)),
    ("_XLFN.T.INV.2T", call => tinv_2t_values(call.values)),
    ("TINV", call => tinv_2t_values(call.values)),
    ("TdotTEST", call => ttest_values(call.values)),
    ("T.TEST", call => ttest_values(call.values)),
    ("_XLFN.T.TEST", call => ttest_values(call.values)),
    ("TTEST", call => ttest_values(call.values)),
    ("ZdotTEST", call => ztest_values(call.values)),
    ("Z.TEST", call => ztest_values(call.values)),
    ("_XLFN.Z.TEST", call => ztest_values(call.values)),
    ("ZTEST", call => ztest_values(call.values)),
    (
      "DISC",
      call => {
        disc_intrate_values(
          "DISC",
          call.values,
          use_1904_dates=call.ctx.use_1904_dates,
        )
      },
    ),
    (
      "INTRATE",
      call => {
        disc_intrate_values(
          "INTRATE",
          call.values,
          use_1904_dates=call.ctx.use_1904_dates,
        )
      },
    ),
    (
      "ODDLPRICE",
      call => {
        oddl_values(
          "ODDLPRICE",
          call.values,
          use_1904_dates=call.ctx.use_1904_dates,
        )
      },
    ),
    (
      "ODDLYIELD",
      call => {
        oddl_values(
          "ODDLYIELD",
          call.values,
          use_1904_dates=call.ctx.use_1904_dates,
        )
      },
    ),
    (
      "PRICE",
      call => {
        price_yield_values(
          "PRICE",
          call.values,
          use_1904_dates=call.ctx.use_1904_dates,
        )
      },
    ),
    (
      "YIELD",
      call => {
        price_yield_values(
          "YIELD",
          call.values,
          use_1904_dates=call.ctx.use_1904_dates,
        )
      },
    ),
    (
      "ACCRINT",
      call => {
        accrint_values(call.values, use_1904_dates=call.ctx.use_1904_dates)
      },
    ),
    (
      "ACCRINTM",
      call => {
        accrintm_values(call.values, use_1904_dates=call.ctx.use_1904_dates)
      },
    ),
    (
      "AMORDEGRC",
      call => {
        amordegrc_values(call.values, use_1904_dates=call.ctx.use_1904_dates)
      },
    ),
    (
      "AMORLINC",
      call => {
        amorlinc_values(call.values, use_1904_dates=call.ctx.use_1904_dates)
      },
    ),
    (
      "COUPDAYBS",
      call => {
        coupdaybs_values(call.values, use_1904_dates=call.ctx.use_1904_dates)
      },
    ),
    (
      "COUPDAYS",
      call => {
        coupdays_values(call.values, use_1904_dates=call.ctx.use_1904_dates)
      },
    ),
    (
      "COUPDAYSNC",
      call => {
        coupdaysnc_values(call.values, use_1904_dates=call.ctx.use_1904_dates)
      },
    ),
    (
      "COUPNCD",
      call => {
        coupncd_values(call.values, use_1904_dates=call.ctx.use_1904_dates)
      },
    ),
    (
      "COUPNUM",
      call => {
        coupnum_values(call.values, use_1904_dates=call.ctx.use_1904_dates)
      },
    ),
    (
      "COUPPCD",
      call => {
        couppcd_values(call.values, use_1904_dates=call.ctx.use_1904_dates)
      },
    ),
    ("CUMIPMT", call => cumip_values("CUMIPMT", call.values)),
    ("CUMPRINC", call => cumip_values("CUMPRINC", call.values)),
    (
      "DURATION",
      call => {
        duration_values(call.values, use_1904_dates=call.ctx.use_1904_dates)
      },
    ),
    ("DB", call => db_values(call.values)),
    ("DDB", call => ddb_values(call.values)),
    ("FV", call => fv_values(call.values)),
    ("FVSCHEDULE", call => fvschedule_values(call.values)),
    ("IRR", call => irr_values(call.values)),
    (
      "MDURATION",
      call => {
        mduration_values(call.values, use_1904_dates=call.ctx.use_1904_dates)
      },
    ),
    ("MIRR", call => mirr_values(call.values)),
    ("DOLLARDE", call => dollar_fraction_values("DOLLARDE", call.values)),
    ("DOLLARFR", call => dollar_fraction_values("DOLLARFR", call.values)),
    ("EFFECT", call => effect_values(call.values)),
    ("IPMT", call => ipmt_values("IPMT", call.values)),
    ("ISPMT", call => ispmt_values(call.values)),
    ("NOMINAL", call => nominal_values(call.values)),
    ("NPER", call => nper_values(call.values)),
    ("NPV", call => npv_values(call.values)),
    (
      "ODDFPRICE",
      call => {
        oddfprice_values(call.values, use_1904_dates=call.ctx.use_1904_dates)
      },
    ),
    (
      "ODDFYIELD",
      call => {
        oddfyield_values(call.values, use_1904_dates=call.ctx.use_1904_dates)
      },
    ),
    ("PDURATION", call => pduration_values(call.values)),
    ("PMT", call => pmt_values(call.values)),
    ("PPMT", call => ipmt_values("PPMT", call.values)),
    (
      "PRICEDISC",
      call => {
        pricedisc_values(call.values, use_1904_dates=call.ctx.use_1904_dates)
      },
    ),
    (
      "PRICEMAT",
      call => {
        pricemat_values(call.values, use_1904_dates=call.ctx.use_1904_dates)
      },
    ),
    ("PV", call => pv_values(call.values)),
    ("RATE", call => rate_values(call.values)),
    (
      "RECEIVED",
      call => {
        received_values(call.values, use_1904_dates=call.ctx.use_1904_dates)
      },
    ),
    ("RRI", call => rri_values(call.values)),
    ("SLN", call => sln_values(call.values)),
    ("SYD", call => syd_values(call.values)),
    (
      "TBILLEQ",
      call => {
        tbilleq_values(call.values, use_1904_dates=call.ctx.use_1904_dates)
      },
    ),
    (
      "TBILLPRICE",
      call => {
        tbillprice_values(call.values, use_1904_dates=call.ctx.use_1904_dates)
      },
    ),
    (
      "TBILLYIELD",
      call => {
        tbillyield_values(call.values, use_1904_dates=call.ctx.use_1904_dates)
      },
    ),
    ("XIRR", call => xirr_values(call.values)),
    ("XNPV", call => xnpv_values(call.values)),
    (
      "YIELDDISC",
      call => {
        yielddisc_values(call.values, use_1904_dates=call.ctx.use_1904_dates)
      },
    ),
    (
      "YIELDMAT",
      call => {
        yieldmat_values(call.values, use_1904_dates=call.ctx.use_1904_dates)
      },
    ),
    ("VDB", call => vdb_values(call.values)),
    ("DATE", eval_date),
    ("TIME", eval_time),
    ("DATEVALUE", eval_datevalue),
    ("TIMEVALUE", eval_timevalue),
    ("DATEDIF", eval_datedif),
    ("DAYS", eval_days),
    ("DAYS360", eval_days360),
    ("ISOWEEKNUM", eval_isoweeknum),
    ("EDATE", eval_edate),
    ("EOMONTH", eval_eomonth),
    ("YEARFRAC", eval_yearfrac),
    ("WEEKDAY", eval_weekday),
    ("WEEKNUM", eval_weeknum),
    ("NETWORKDAYS", eval_networkdays),
    ("NETWORKDAYS.INTL", eval_networkdays_intl),
    ("WORKDAY", eval_workday),
    ("WORKDAY.INTL", eval_workday_intl),
    ("NOW", eval_now),
    ("TODAY", eval_today),
    ("YEAR", eval_year),
    ("MONTH", eval_month),
    ("DAY", eval_day),
    ("HOUR", eval_hour),
    ("MINUTE", eval_minute),
    ("SECOND", eval_second),
    ("LEN", eval_len),
    ("LENB", eval_lenb),
    ("LOWER", eval_lower),
    ("UPPER", eval_upper),
    ("PROPER", eval_proper),
    ("DBCS", eval_dbcs),
    ("TRIM", eval_trim),
    ("LEFT", eval_left),
    ("LEFTB", eval_leftb),
    ("RIGHT", eval_right),
    ("RIGHTB", eval_rightb),
    ("MID", eval_mid),
    ("MIDB", eval_midb),
    ("REPT", eval_rept),
    ("REPLACE", eval_replace),
    ("REPLACEB", eval_replaceb),
    ("SUBSTITUTE", eval_substitute),
    ("FIND", eval_find),
    ("FINDB", eval_findb),
    ("SEARCH", eval_search),
    ("SEARCHB", eval_searchb),
    ("EXACT", eval_exact),
    ("FIXED", eval_fixed),
    ("VALUE", eval_value),
    ("VALUETOTEXT", eval_valuetotext),
    ("TEXT", eval_text),
    ("TEXTAFTER", eval_textafter),
    ("TEXTBEFORE", eval_textafter),
    ("_XLFN.TEXTAFTER", eval_textafter),
    ("_XLFN.TEXTBEFORE", eval_textafter),
    ("TEXTSPLIT", eval_textsplit),
    ("_XLFN.TEXTSPLIT", eval_textsplit),
    ("TEXTJOIN", eval_textjoin),
    ("CHAR", eval_char),
    ("UNICHAR", eval_unichar),
    ("CLEAN", eval_clean),
    ("ENCODEURL", eval_encodeurl),
    ("BAHTTEXT", eval_bahttext),
    ("CODE", eval_code),
    ("UNICODE", eval_unicode),
    ("T", eval_t),
    ("DOLLAR", call => dollar_values(call.values)),
    ("CONCAT", call => concat_values(call.values)),
    ("CONCATENATE", call => concat_values(call.values)),
    ("ANCHORARRAY", eval_anchorarray),
    ("_XLFN.ANCHORARRAY", eval_anchorarray),
    ("HYPERLINK", eval_hyperlink),
    ("CHOOSE", eval_choose),
    ("SEQUENCE", call => sequence_values(call.values)),
    ("_XLFN.SEQUENCE", call => sequence_values(call.values)),
    ("DISPIMG", eval_dispimg),
    ("_XLFN.DISPIMG", eval_dispimg),
    ("ISBLANK", eval_isblank),
    ("ISERR", eval_iserr),
    ("ISEVEN", eval_iseven),
    ("ISODD", eval_isodd),
    ("ISERROR", eval_iserror),
    ("ISLOGICAL", eval_islogical),
    ("ISNA", eval_isna),
    ("ISNUMBER", eval_isnumber),
    ("ISTEXT", eval_istext),
    ("ISNONTEXT", eval_isnontext),
    ("ISREF", eval_isref),
    ("ISFORMULA", eval_isformula),
    ("ERRORdotTYPE", eval_errordottype),
    ("ERROR.TYPE", eval_errordottype),
    ("SHEET", eval_sheet),
    ("SHEETS", eval_sheets),
    ("TYPE", eval_type),
    ("NA", eval_na),
    ("N", eval_n),
    ("AND", eval_and),
    ("OR", eval_or),
    ("NOT", eval_not),
    ("XOR", eval_xor),
    ("IF", eval_if),
    ("IFERROR", eval_iferror),
    ("IFNA", eval_ifna),
    ("IFS", eval_ifs),
    ("SWITCH", eval_switch),
    ("TRUE", _call => Bool(true)),
    ("FALSE", _call => Bool(false)),
  ])
}

///|
fn eval_function_unknown(
  workbook : Workbook,
  sheet_name : String,
  name : String,
  args : ArrayView[Expr],
  ctx : CalcContext,
) -> FormulaValue raise XlsxError {
  if args.length() == 0 {
    match defined_name_value(workbook, sheet_name, name, ctx) {
      Some(value) => value
      None => Error(formula_error_name)
    }
  } else {
    Error(formula_error_name)
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
    { n: 1000.0, s: "M", },
    { n: 900.0, s: "CM", },
    { n: 500.0, s: "D", },
    { n: 400.0, s: "CD", },
    { n: 100.0, s: "C", },
    { n: 90.0, s: "XC", },
    { n: 50.0, s: "L", },
    { n: 40.0, s: "XL", },
    { n: 10.0, s: "X", },
    { n: 9.0, s: "IX", },
    { n: 5.0, s: "V", },
    { n: 4.0, s: "IV", },
    { n: 1.0, s: "I", },
  ],
  [
    { n: 1000.0, s: "M", },
    { n: 950.0, s: "LM", },
    { n: 900.0, s: "CM", },
    { n: 500.0, s: "D", },
    { n: 450.0, s: "LD", },
    { n: 400.0, s: "CD", },
    { n: 100.0, s: "C", },
    { n: 95.0, s: "VC", },
    { n: 90.0, s: "XC", },
    { n: 50.0, s: "L", },
    { n: 45.0, s: "VL", },
    { n: 40.0, s: "XL", },
    { n: 10.0, s: "X", },
    { n: 9.0, s: "IX", },
    { n: 5.0, s: "V", },
    { n: 4.0, s: "IV", },
    { n: 1.0, s: "I", },
  ],
  [
    { n: 1000.0, s: "M", },
    { n: 990.0, s: "XM", },
    { n: 950.0, s: "LM", },
    { n: 900.0, s: "CM", },
    { n: 500.0, s: "D", },
    { n: 490.0, s: "XD", },
    { n: 450.0, s: "LD", },
    { n: 400.0, s: "CD", },
    { n: 100.0, s: "C", },
    { n: 99.0, s: "IC", },
    { n: 90.0, s: "XC", },
    { n: 50.0, s: "L", },
    { n: 45.0, s: "VL", },
    { n: 40.0, s: "XL", },
    { n: 10.0, s: "X", },
    { n: 9.0, s: "IX", },
    { n: 5.0, s: "V", },
    { n: 4.0, s: "IV", },
    { n: 1.0, s: "I", },
  ],
  [
    { n: 1000.0, s: "M", },
    { n: 995.0, s: "VM", },
    { n: 990.0, s: "XM", },
    { n: 950.0, s: "LM", },
    { n: 900.0, s: "CM", },
    { n: 500.0, s: "D", },
    { n: 495.0, s: "VD", },
    { n: 490.0, s: "XD", },
    { n: 450.0, s: "LD", },
    { n: 400.0, s: "CD", },
    { n: 100.0, s: "C", },
    { n: 99.0, s: "IC", },
    { n: 90.0, s: "XC", },
    { n: 50.0, s: "L", },
    { n: 45.0, s: "VL", },
    { n: 40.0, s: "XL", },
    { n: 10.0, s: "X", },
    { n: 9.0, s: "IX", },
    { n: 5.0, s: "V", },
    { n: 4.0, s: "IV", },
    { n: 1.0, s: "I", },
  ],
  [
    { n: 1000.0, s: "M", },
    { n: 999.0, s: "IM", },
    { n: 995.0, s: "VM", },
    { n: 990.0, s: "XM", },
    { n: 950.0, s: "LM", },
    { n: 900.0, s: "CM", },
    { n: 500.0, s: "D", },
    { n: 499.0, s: "ID", },
    { n: 495.0, s: "VD", },
    { n: 490.0, s: "XD", },
    { n: 450.0, s: "LD", },
    { n: 400.0, s: "CD", },
    { n: 100.0, s: "C", },
    { n: 99.0, s: "IC", },
    { n: 90.0, s: "XC", },
    { n: 50.0, s: "L", },
    { n: 45.0, s: "VL", },
    { n: 40.0, s: "XL", },
    { n: 10.0, s: "X", },
    { n: 9.0, s: "IX", },
    { n: 5.0, s: "V", },
    { n: 4.0, s: "IV", },
    { n: 1.0, s: "I", },
  ],
]

///|
fn roman_string(value : Double, form : Int) -> String {
  let table = roman_table[form]
  let sb = StringBuilder()
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
  guard values is [v0, v1] else { return Error(formula_error_value) }
  match (bitwise_number(v0), bitwise_number(v1)) {
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
        min_length = @string.parse_int(text, base=10) catch {
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
    let sb = StringBuilder()
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
    let digit = @string.parse_int(String::from_array([ch]), base=10) catch {
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
  guard values is [v0, v1] else { return Error(formula_error_value) }
  let percent = match value_as_number(v1) {
    Ok(num) => num
    Err(err) => return err
  }
  if percent < 0.0 || percent >= 1.0 {
    return Error(formula_error_num)
  }
  let numbers : Array[Double] = []
  let list_values : Array[FormulaValue] = [v0]
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
  guard values is [v0, v1, v2, v3] else { return Error(formula_error_value) }
  let x = match value_as_number(v0) {
    Ok(num) => num
    Err(err) => return err
  }
  let mean = match value_as_number(v1) {
    Ok(num) => num
    Err(err) => return err
  }
  let std_dev = match value_as_number(v2) {
    Ok(num) => num
    Err(err) => return err
  }
  let cumulative = match value_as_bool(v3) {
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
  guard values is [v0, v1, v2] else { return Error(formula_error_value) }
  let probability = match value_as_number(v0) {
    Ok(num) => num
    Err(err) => return err
  }
  let mean = match value_as_number(v1) {
    Ok(num) => num
    Err(err) => return err
  }
  let std_dev = match value_as_number(v2) {
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
  guard values is [v0, v1] else { return Error(formula_error_value) }
  let x = match value_as_number(v0) {
    Ok(num) => num
    Err(err) => return err
  }
  let cumulative = match value_as_bool(v1) {
    Ok(flag) => flag
    Err(err) => return err
  }
  let raw = if cumulative { get_norm_s_dist(x) } else { norm_pdf(x, 0.0, 1.0) }
  number_or_num_error(round_significant_digits(raw, 15))
}

///|
fn norms_dist_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  guard values is [v0] else { return Error(formula_error_value) }
  let x = match value_as_number(v0) {
    Ok(num) => num
    Err(err) => return err
  }
  number_or_num_error(round_significant_digits(get_norm_s_dist(x), 15))
}

///|
fn norm_s_inv_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  guard values is [v0] else { return Error(formula_error_value) }
  let probability = match value_as_number(v0) {
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
  guard values is [v0, v1, v2] else { return Error(formula_error_value) }
  let alpha = match value_as_number(v0) {
    Ok(num) => num
    Err(err) => return err
  }
  let std_dev = match value_as_number(v1) {
    Ok(num) => num
    Err(err) => return err
  }
  let size = match value_as_number(v2) {
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
  guard values is [v0, v1, v2] else { return Error(formula_error_value) }
  let alpha = match value_as_number(v0) {
    Ok(num) => num
    Err(err) => return err
  }
  let std_dev = match value_as_number(v1) {
    Ok(num) => num
    Err(err) => return err
  }
  let size = match value_as_number(v2) {
    Ok(num) => num
    Err(err) => return err
  }
  if alpha <= 0.0 || alpha >= 1.0 || std_dev <= 0.0 || size < 1.0 {
    return Error(formula_error_num)
  }
  if size == 1.0 {
    return Error(formula_error_div)
  }
  let iterator = { fp: alpha, fdf: size - 1.0, nt: 2.0, kind: TDist, }
  let result = calc_iterate_inverse(iterator, size / 2.0, size)
  let raw = std_dev * result / Double::sqrt(size)
  number_or_num_error(round_significant_digits(raw, 15))
}

///|
fn loginv_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  guard values is [v0, v1, v2] else { return Error(formula_error_value) }
  let probability = match value_as_number(v0) {
    Ok(num) => num
    Err(err) => return err
  }
  let mean = match value_as_number(v1) {
    Ok(num) => num
    Err(err) => return err
  }
  let std_dev = match value_as_number(v2) {
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
  guard values is [v0] else { return Error(formula_error_value) }
  let number = match value_as_number(v0) {
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
  guard values is [v0, v1, v2, v3] else { return Error(formula_error_value) }
  let x = match value_as_number(v0) {
    Ok(num) => num
    Err(err) => return err
  }
  let alpha = match value_as_number(v1) {
    Ok(num) => num
    Err(err) => return err
  }
  let beta = match value_as_number(v2) {
    Ok(num) => num
    Err(err) => return err
  }
  let cumulative = match value_as_bool(v3) {
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
  guard values is [v0, v1, v2] else { return Error(formula_error_value) }
  let probability = match value_as_number(v0) {
    Ok(num) => num
    Err(err) => return err
  }
  let alpha = match value_as_number(v1) {
    Ok(num) => num
    Err(err) => return err
  }
  let beta = match value_as_number(v2) {
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
  guard values is [v0] else { return Error(formula_error_value) }
  let x = match value_as_number(v0) {
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
  guard values is [v0] else { return Error(formula_error_value) }
  let x = match value_as_number(v0) {
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
  guard values is [v0, v1, v2, v3] else { return Error(formula_error_value) }
  let x = match value_as_number(v0) {
    Ok(num) => num
    Err(err) => return err
  }
  let mean = match value_as_number(v1) {
    Ok(num) => num
    Err(err) => return err
  }
  let std_dev = match value_as_number(v2) {
    Ok(num) => num
    Err(err) => return err
  }
  let cumulative = match value_as_bool(v3) {
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
  guard values is [v0, v1, v2] else { return Error(formula_error_value) }
  let x = match value_as_number(v0) {
    Ok(num) => num
    Err(err) => return err
  }
  let mean = match value_as_number(v1) {
    Ok(num) => num
    Err(err) => return err
  }
  let std_dev = match value_as_number(v2) {
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
  guard values is [v0, v1, v2] else { return Error(formula_error_value) }
  let x = match value_as_number(v0) {
    Ok(num) => num
    Err(err) => return err
  }
  let lambda = match value_as_number(v1) {
    Ok(num) => num
    Err(err) => return err
  }
  let cumulative = match value_as_bool(v2) {
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
  guard values is [v0, v1, v2] else { return Error(formula_error_value) }
  let x = match value_as_number(v0) {
    Ok(num) => num
    Err(err) => return err
  }
  let mean = match value_as_number(v1) {
    Ok(num) => num
    Err(err) => return err
  }
  let cumulative = match value_as_bool(v2) {
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
  guard values is [v0, v1, v2, v3] else { return Error(formula_error_value) }
  let successes = match value_as_number(v0) {
    Ok(num) => num
    Err(err) => return err
  }
  let trials = match value_as_number(v1) {
    Ok(num) => num
    Err(err) => return err
  }
  if successes < 0.0 || successes > trials {
    return Error(formula_error_num)
  }
  let probability = match value_as_number(v2) {
    Ok(num) => num
    Err(err) => return err
  }
  if probability < 0.0 || probability > 1.0 {
    return Error(formula_error_num)
  }
  let cumulative = match value_as_bool(v3) {
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
  guard values is [v0, v1, v2] else { return Error(formula_error_value) }
  let trials = match value_as_number(v0) {
    Ok(num) => num
    Err(err) => return err
  }
  if trials < 0.0 {
    return Error(formula_error_num)
  }
  let probability = match value_as_number(v1) {
    Ok(num) => num
    Err(err) => return err
  }
  if probability <= 0.0 || probability >= 1.0 {
    return Error(formula_error_num)
  }
  let alpha = match value_as_number(v2) {
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
  guard values is [v0, v1, v2, v3, v4] else {
    return Error(formula_error_value)
  }
  let sample_s = match value_as_number(v0) {
    Ok(num) => num
    Err(err) => return err
  }
  let number_sample = match value_as_number(v1) {
    Ok(num) => num
    Err(err) => return err
  }
  let population_s = match value_as_number(v2) {
    Ok(num) => num
    Err(err) => return err
  }
  let number_pop = match value_as_number(v3) {
    Ok(num) => num
    Err(err) => return err
  }
  if hypgeom_args_invalid(sample_s, number_sample, population_s, number_pop) {
    return Error(formula_error_num)
  }
  let cumulative = match value_as_bool(v4) {
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
  guard values is [v0, v1, v2, v3] else { return Error(formula_error_value) }
  let sample_s = match value_as_number(v0) {
    Ok(num) => num
    Err(err) => return err
  }
  let number_sample = match value_as_number(v1) {
    Ok(num) => num
    Err(err) => return err
  }
  let population_s = match value_as_number(v2) {
    Ok(num) => num
    Err(err) => return err
  }
  let number_pop = match value_as_number(v3) {
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
  guard values is [v0, v1, v2, v3] else { return Error(formula_error_value) }
  let failures = match value_as_number(v0) {
    Ok(num) => num
    Err(err) => return err
  }
  let successes = match value_as_number(v1) {
    Ok(num) => num
    Err(err) => return err
  }
  let probability = match value_as_number(v2) {
    Ok(num) => num
    Err(err) => return err
  }
  let cumulative = match value_as_bool(v3) {
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
  guard values is [v0, v1, v2] else { return Error(formula_error_value) }
  let failures = match value_as_number(v0) {
    Ok(num) => num
    Err(err) => return err
  }
  let successes = match value_as_number(v1) {
    Ok(num) => num
    Err(err) => return err
  }
  let probability = match value_as_number(v2) {
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
  guard values is [v0] else { return Error(formula_error_value) }
  let x = match value_as_number(v0) {
    Ok(num) => num
    Err(err) => return err
  }
  let raw = get_norm_s_dist(x) - 0.5
  number_or_num_error(round_significant_digits(raw, 15))
}

///|
fn phi_value(values : ArrayView[FormulaValue]) -> FormulaValue {
  guard values is [v0] else { return Error(formula_error_value) }
  let x = match value_as_number(v0) {
    Ok(num) => num
    Err(err) => return err
  }
  let raw = 0.39894228040143268 * @math.exp(-(x * x) / 2.0)
  number_or_num_error(round_significant_digits(raw, 15))
}

///|
fn tdist_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  guard values is [v0, v1, v2] else { return Error(formula_error_value) }
  let x = match value_as_number(v0) {
    Ok(num) => num
    Err(err) => return err
  }
  let degrees = match value_as_number(v1) {
    Ok(num) => num
    Err(err) => return err
  }
  let cumulative = match value_as_bool(v2) {
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
  guard values is [v0, v1] else { return Error(formula_error_value) }
  let x = match value_as_number(v0) {
    Ok(num) => num
    Err(err) => return err
  }
  let degrees = match value_as_number(v1) {
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
  guard values is [v0, v1] else { return Error(formula_error_value) }
  let x = match value_as_number(v0) {
    Ok(num) => num
    Err(err) => return err
  }
  let degrees = match value_as_number(v1) {
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
  guard values is [v0, v1, v2] else { return Error(formula_error_value) }
  let x = match value_as_number(v0) {
    Ok(num) => num
    Err(err) => return err
  }
  let degrees = match value_as_number(v1) {
    Ok(num) => num
    Err(err) => return err
  }
  let tails = match value_as_number(v2) {
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
  guard values is [v0, v1] else { return Error(formula_error_value) }
  let probability = match value_as_number(v0) {
    Ok(num) => num
    Err(err) => return err
  }
  let degrees = match value_as_number(v1) {
    Ok(num) => num
    Err(err) => return err
  }
  if probability <= 0.0 || probability >= 1.0 || degrees < 1.0 {
    return Error(formula_error_num)
  }
  let iterator = if probability < 0.5 {
    { fp: 1.0 - probability, fdf: degrees, nt: 4.0, kind: TDist, }
  } else {
    { fp: probability, fdf: degrees, nt: 4.0, kind: TDist, }
  }
  let mut result = calc_iterate_inverse(iterator, degrees / 2.0, degrees)
  if probability < 0.5 {
    result = -result
  }
  number_or_num_error(round_significant_digits(result, 15))
}

///|
fn tinv_2t_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  guard values is [v0, v1] else { return Error(formula_error_value) }
  let probability = match value_as_number(v0) {
    Ok(num) => num
    Err(err) => return err
  }
  let degrees = match value_as_number(v1) {
    Ok(num) => num
    Err(err) => return err
  }
  if probability <= 0.0 || probability > 1.0 || degrees < 1.0 {
    return Error(formula_error_num)
  }
  let iterator = { fp: probability, fdf: degrees, nt: 2.0, kind: TDist, }
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
  guard values is [v0, v1, v2, v3] else { return Error(formula_error_value) }
  let (array1, array2) = match (v0, v1) {
    (List(left), List(right)) => (left, right)
    _ => return Error(formula_error_num)
  }
  let tails = match value_as_number(v2) {
    Ok(num) => num
    Err(err) => return err
  }
  let test_type = match value_as_number(v3) {
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
  guard values is [v0, v1] else { return Error(formula_error_value) }
  let x = match value_as_number(v0) {
    Ok(num) => num
    Err(err) => return err
  }
  let degrees = match value_as_number(v1) {
    Ok(num) => num
    Err(err) => return err
  }
  let result = round_chisq_result(get_chidist(x, degrees))
  number_or_num_error(result)
}

///|
fn chiinv_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  guard values is [v0, v1] else { return Error(formula_error_value) }
  let probability = match value_as_number(v0) {
    Ok(num) => num
    Err(err) => return err
  }
  let degrees = match value_as_number(v1) {
    Ok(num) => num
    Err(err) => return err
  }
  if probability <= 0.0 || probability > 1.0 || degrees < 1.0 {
    return Error(formula_error_num)
  }
  if probability == 1.0 {
    return Number(0.0)
  }
  let iterator = { fp: 1.0 - probability, fdf: degrees, nt: 0.0, kind: ChiSq, }
  let result = calc_iterate_inverse(iterator, degrees / 2.0, degrees)
  number_or_num_error(result)
}

///|
fn chisq_dist_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  guard values is [v0, v1, v2] else { return Error(formula_error_value) }
  let x = match value_as_number(v0) {
    Ok(num) => num
    Err(err) => return err
  }
  let degrees = match value_as_number(v1) {
    Ok(num) => num
    Err(err) => return err
  }
  let cumulative = match value_as_bool(v2) {
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
  guard values is [v0, v1] else { return Error(formula_error_value) }
  let probability = match value_as_number(v0) {
    Ok(num) => num
    Err(err) => return err
  }
  let degrees = match value_as_number(v1) {
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
  let iterator = { fp: probability, fdf: degrees, nt: 0.0, kind: ChiSq, }
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
  guard values is [v0, v1, v2, v3] else { return Error(formula_error_value) }
  let x = match value_as_number(v0) {
    Ok(num) => num
    Err(err) => return err
  }
  let deg1 = match value_as_number(v1) {
    Ok(num) => num
    Err(err) => return err
  }
  let deg2 = match value_as_number(v2) {
    Ok(num) => num
    Err(err) => return err
  }
  let cumulative = match value_as_bool(v3) {
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
  guard values is [v0, v1, v2] else { return Error(formula_error_value) }
  let x = match value_as_number(v0) {
    Ok(num) => num
    Err(err) => return err
  }
  let deg1 = match value_as_number(v1) {
    Ok(num) => num
    Err(err) => return err
  }
  let deg2 = match value_as_number(v2) {
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
  guard values is [v0, v1, v2] else { return Error(formula_error_value) }
  let probability = match value_as_number(v0) {
    Ok(num) => num
    Err(err) => return err
  }
  let deg1 = match value_as_number(v1) {
    Ok(num) => num
    Err(err) => return err
  }
  let deg2 = match value_as_number(v2) {
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
  guard values is [v0, v1, v2] else { return Error(formula_error_value) }
  let probability = match value_as_number(v0) {
    Ok(num) => num
    Err(err) => return err
  }
  let deg1 = match value_as_number(v1) {
    Ok(num) => num
    Err(err) => return err
  }
  let deg2 = match value_as_number(v2) {
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
  guard values is [v0, v1] else { return Error(formula_error_value) }
  let left_range = range_from_expr_or_value(
    workbook,
    sheet_name,
    args[0],
    v0,
    ctx,
  )
  let right_range = range_from_expr_or_value(
    workbook,
    sheet_name,
    args[1],
    v1,
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
