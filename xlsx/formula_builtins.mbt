///|
fn eval_function(
  workbook : Workbook,
  sheet_name : String,
  name : String,
  args : ArrayView[Expr],
  ctx : CalcContext,
) -> FormulaValue raise XlsxError {
  if name == "ROW" {
    return match args {
      [] =>
        match current_cell_rc(ctx) {
          Some((row, _col)) => Number(Double::from_int(row))
          None => Error(formula_error_value)
        }
      [arg] =>
        match ref_bounds_opt(arg) {
          Some((row1, _col1, row2, _col2)) => {
            let row = if row1 < row2 { row1 } else { row2 }
            Number(Double::from_int(row))
          }
          None => Error(formula_error_value)
        }
      _ => Error(formula_error_value)
    }
  }
  if name == "COLUMN" {
    return match args {
      [] =>
        match current_cell_rc(ctx) {
          Some((_row, col)) => Number(Double::from_int(col))
          None => Error(formula_error_value)
        }
      [arg] =>
        match ref_bounds_opt(arg) {
          Some((_row1, col1, _row2, col2)) => {
            let col = if col1 < col2 { col1 } else { col2 }
            Number(Double::from_int(col))
          }
          None => Error(formula_error_value)
        }
      _ => Error(formula_error_value)
    }
  }
  if name == "ROWS" {
    return match args {
      [arg] =>
        match ref_bounds_opt(arg) {
          Some((row1, _col1, row2, _col2)) => {
            let min_row = if row1 < row2 { row1 } else { row2 }
            let max_row = if row1 > row2 { row1 } else { row2 }
            Number(Double::from_int(max_row - min_row + 1))
          }
          None => Error(formula_error_value)
        }
      _ => Error(formula_error_value)
    }
  }
  if name == "COLUMNS" {
    return match args {
      [arg] =>
        match ref_bounds_opt(arg) {
          Some((_row1, col1, _row2, col2)) => {
            let min_col = if col1 < col2 { col1 } else { col2 }
            let max_col = if col1 > col2 { col1 } else { col2 }
            Number(Double::from_int(max_col - min_col + 1))
          }
          None => Error(formula_error_value)
        }
      _ => Error(formula_error_value)
    }
  }
  if name == "FORMULATEXT" {
    return match args {
      [arg] => formula_text_value(workbook, sheet_name, arg)
      _ => Error(formula_error_value)
    }
  }
  let values : Array[FormulaValue] = []
  for arg in args {
    values.push(eval_expr(workbook, sheet_name, arg, ctx))
  }
  raising_handlers()
  .get(name)
  .map(h => h(workbook, sheet_name, name, args, values, ctx))
  .unwrap_or_else(() => {
    plain_handlers()
    .get(name)
    .map(h => h(workbook, sheet_name, name, args, values, ctx))
    .unwrap_or_else(() => {
      eval_function_unknown(workbook, sheet_name, name, args, ctx)
    })
  })
}

///|
type RaisingHandler = (
  Workbook,
  String,
  String,
  ArrayView[Expr],
  Array[FormulaValue],
  CalcContext,
) -> FormulaValue raise XlsxError

///|
type PlainHandler = (
  Workbook,
  String,
  String,
  ArrayView[Expr],
  Array[FormulaValue],
  CalcContext,
) -> FormulaValue

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
  let m : @hashmap.HashMap[String, RaisingHandler] = HashMap([])
  eval_register_raising(m)
  m
}

///|
fn build_plain_handlers() -> @hashmap.HashMap[String, PlainHandler] {
  let m : @hashmap.HashMap[String, PlainHandler] = HashMap([])
  eval_register_plain(m)
  m
}

///|
fn eval_register_raising(m : @hashmap.HashMap[String, RaisingHandler]) -> Unit {
  m.set("SUM", eval_function_math_1)
  m.set("SUBTOTAL", eval_function_math_1)
  m.set("AGGREGATE", eval_function_math_1)
  m.set("PRODUCT", eval_function_math_1)
  m.set("SIGN", eval_function_math_1)
  m.set("SERIESSUM", eval_function_math_1)
  m.set("SUMIF", eval_function_math_1)
  m.set("SUMPRODUCT", eval_function_math_1)
  m.set("SUMSQ", eval_function_math_1)
  m.set("SUMX2MY2", eval_function_math_1)
  m.set("SUMX2PY2", eval_function_math_1)
  m.set("SUMXMY2", eval_function_math_1)
  m.set("SUMIFS", eval_function_math_1)
  m.set("GCD", eval_function_math_1)
  m.set("LCM", eval_function_math_1)
  m.set("COMBIN", eval_function_math_1)
  m.set("COMBINA", eval_function_math_1)
  m.set("_XLFN.COMBINA", eval_function_math_1)
  m.set("COMPLEX", eval_function_math_1)
  m.set("FACT", eval_function_math_1)
  m.set("FACTDOUBLE", eval_function_math_1)
  m.set("MULTINOMIAL", eval_function_math_1)
  m.set("MDETERM", eval_function_math_1)
  m.set("MINVERSE", eval_function_math_1)
  m.set("MMULT", eval_function_math_1)
  m.set("MUNIT", eval_function_math_1)
  m.set("_XLFN.MUNIT", eval_function_math_1)
  m.set("ABS", eval_function_math_1)
  m.set("INT", eval_function_math_1)
  m.set("LN", eval_function_math_1)
  m.set("EXP", eval_function_math_1)
  m.set("DECIMAL", eval_function_math_1)
  m.set("_XLFN.DECIMAL", eval_function_math_1)
  m.set("ROMAN", eval_function_math_1)
  m.set("ARABIC", eval_function_math_1)
  m.set("_XLFN.ARABIC", eval_function_math_1)
  m.set("BASE", eval_function_math_1)
  m.set("BIN2DEC", eval_function_math_1)
  m.set("BIN2HEX", eval_function_math_1)
  m.set("BIN2OCT", eval_function_math_1)
  m.set("DEC2BIN", eval_function_math_1)
  m.set("DEC2BIN", eval_function_math_1)
  m.set("DEC2HEX", eval_function_math_1)
  m.set("DEC2HEX", eval_function_math_1)
  m.set("DEC2OCT", eval_function_math_1)
  m.set("DEC2OCT", eval_function_math_1)
  m.set("HEX2BIN", eval_function_math_1)
  m.set("HEX2DEC", eval_function_math_1)
  m.set("HEX2OCT", eval_function_math_1)
  m.set("OCT2BIN", eval_function_math_1)
  m.set("OCT2DEC", eval_function_math_1)
  m.set("OCT2HEX", eval_function_math_1)
  m.set("BESSELI", eval_function_math_1)
  m.set("BESSELJ", eval_function_math_1)
  m.set("BESSELK", eval_function_math_1)
  m.set("BESSELY", eval_function_math_1)
  m.set("DELTA", eval_function_math_1)
  m.set("ERF", eval_function_math_1)
  m.set("ERFdotPRECISE", eval_function_math_1)
  m.set("ERF.PRECISE", eval_function_math_1)
  m.set("_XLFN.ERF.PRECISE", eval_function_math_1)
  m.set("ERFC", eval_function_math_1)
  m.set("ERFCdotPRECISE", eval_function_math_1)
  m.set("ERFC.PRECISE", eval_function_math_1)
  m.set("_XLFN.ERFC.PRECISE", eval_function_math_1)
  m.set("CONVERT", eval_function_math_1)
  m.set("EUROCONVERT", eval_function_math_1)
  m.set("GESTEP", eval_function_math_1)
  m.set("BITAND", eval_function_math_1)
  m.set("BITAND", eval_function_math_1)
  m.set("BITLSHIFT", eval_function_math_1)
  m.set("BITLSHIFT", eval_function_math_1)
  m.set("AVERAGE", eval_function_stats_1)
  m.set("AVERAGEA", eval_function_stats_1)
  m.set("STDEV", eval_function_stats_1)
  m.set("STDEV.S", eval_function_stats_1)
  m.set("STDEVA", eval_function_stats_1)
  m.set("STDEVP", eval_function_stats_1)
  m.set("STDEV.P", eval_function_stats_1)
  m.set("STDEVPA", eval_function_stats_1)
  m.set("VAR", eval_function_stats_1)
  m.set("VAR.S", eval_function_stats_1)
  m.set("VARA", eval_function_stats_1)
  m.set("VARP", eval_function_stats_1)
  m.set("VAR.P", eval_function_stats_1)
  m.set("VARPA", eval_function_stats_1)
  m.set("TRIMMEAN", eval_function_stats_1)
  m.set("AVEDEV", eval_function_stats_1)
  m.set("DEVSQ", eval_function_stats_1)
  m.set("GEOMEAN", eval_function_stats_1)
  m.set("HARMEAN", eval_function_stats_1)
  m.set("KURT", eval_function_stats_1)
  m.set("SKEW", eval_function_stats_1)
  m.set("SKEW.P", eval_function_stats_1)
  m.set("STANDARDIZE", eval_function_stats_1)
  m.set("LARGE", eval_function_stats_1)
  m.set("SMALL", eval_function_stats_1)
  m.set("MODE", eval_function_stats_1)
  m.set("MODE.SNGL", eval_function_stats_1)
  m.set("MODE.MULT", eval_function_stats_1)
  m.set("PERCENTILE", eval_function_stats_1)
  m.set("PERCENTILE.INC", eval_function_stats_1)
  m.set("PERCENTILE.EXC", eval_function_stats_1)
  m.set("PERCENTRANK", eval_function_stats_1)
  m.set("PERCENTRANK.INC", eval_function_stats_1)
  m.set("PERCENTRANK.EXC", eval_function_stats_1)
  m.set("QUARTILE", eval_function_stats_1)
  m.set("QUARTILE.INC", eval_function_stats_1)
  m.set("QUARTILE.EXC", eval_function_stats_1)
  m.set("RANK", eval_function_stats_1)
  m.set("RANK.EQ", eval_function_stats_1)
  m.set("CORREL", eval_function_stats_1)
  m.set("COVAR", eval_function_stats_1)
  m.set("COVARIANCE.P", eval_function_stats_1)
  m.set("COVARIANCE.S", eval_function_stats_1)
  m.set("PEARSON", eval_function_stats_1)
  m.set("RSQ", eval_function_stats_1)
  m.set("SLOPE", eval_function_stats_1)
  m.set("INTERCEPT", eval_function_stats_1)
  m.set("FORECAST", eval_function_stats_1)
  m.set("FORECAST.LINEAR", eval_function_stats_1)
  m.set("GROWTH", eval_function_stats_1)
  m.set("TREND", eval_function_stats_1)
  m.set("FISHER", eval_function_stats_1)
  m.set("FISHERINV", eval_function_stats_1)
  m.set("STEYX", eval_function_stats_1)
  m.set("MEDIAN", eval_function_stats_1)
  m.set("MIN", eval_function_stats_1)
  m.set("MAX", eval_function_stats_1)
  m.set("MINA", eval_function_stats_1)
  m.set("MAXA", eval_function_stats_1)
  m.set("COUNT", eval_function_stats_1)
  m.set("COUNTA", eval_function_stats_1)
  m.set("COUNTBLANK", eval_function_stats_1)
  m.set("FREQUENCY", eval_function_stats_1)
  m.set("COUNTIF", eval_function_stats_1)
  m.set("COUNTIFS", eval_function_stats_1)
  m.set("DAVERAGE", eval_function_stats_2)
  m.set("DMAX", eval_function_stats_2)
  m.set("DMIN", eval_function_stats_2)
  m.set("DPRODUCT", eval_function_stats_2)
  m.set("DSTDEV", eval_function_stats_2)
  m.set("DSTDEVP", eval_function_stats_2)
  m.set("DSUM", eval_function_stats_2)
  m.set("DVAR", eval_function_stats_2)
  m.set("DVARP", eval_function_stats_2)
  m.set("DCOUNT", eval_function_stats_2)
  m.set("DCOUNTA", eval_function_stats_2)
  m.set("DGET", eval_function_stats_2)
  m.set("AVERAGEIF", eval_function_stats_2)
  m.set("AVERAGEIFS", eval_function_stats_2)
  m.set("MAXIFS", eval_function_stats_2)
  m.set("MINIFS", eval_function_stats_2)
  m.set("PERMUT", eval_function_stats_2)
  m.set("PERMUTATIONA", eval_function_stats_2)
  m.set("WEIBULL", eval_function_stats_2)
  m.set("WEIBULLdotDIST", eval_function_stats_2)
  m.set("WEIBULL.DIST", eval_function_stats_2)
  m.set("_XLFN.WEIBULL.DIST", eval_function_stats_2)
  m.set("BETAdotDIST", eval_function_stats_2)
  m.set("BETA.DIST", eval_function_stats_2)
  m.set("_XLFN.BETA.DIST", eval_function_stats_2)
  m.set("BETADIST", eval_function_stats_2)
  m.set("BETAINV", eval_function_stats_2)
  m.set("BETAdotINV", eval_function_stats_2)
  m.set("BETA.INV", eval_function_stats_2)
  m.set("_XLFN.BETA.INV", eval_function_stats_2)
  m.set("CONFIDENCE", eval_function_stats_2)
  m.set("CONFIDENCEdotNORM", eval_function_stats_2)
  m.set("CONFIDENCE.NORM", eval_function_stats_2)
  m.set("_XLFN.CONFIDENCE.NORM", eval_function_stats_2)
  m.set("CONFIDENCEdotT", eval_function_stats_2)
  m.set("CONFIDENCE.T", eval_function_stats_2)
  m.set("_XLFN.CONFIDENCE.T", eval_function_stats_2)
  m.set("NORMdotDIST", eval_function_stats_2)
  m.set("NORM.DIST", eval_function_stats_2)
  m.set("_XLFN.NORM.DIST", eval_function_stats_2)
  m.set("NORMDIST", eval_function_stats_2)
  m.set("NORMdotINV", eval_function_stats_2)
  m.set("NORM.INV", eval_function_stats_2)
  m.set("_XLFN.NORM.INV", eval_function_stats_2)
  m.set("NORMINV", eval_function_stats_2)
  m.set("NORMdotSdotDIST", eval_function_stats_2)
  m.set("NORM.S.DIST", eval_function_stats_2)
  m.set("_XLFN.NORM.S.DIST", eval_function_stats_2)
  m.set("NORMSDIST", eval_function_stats_2)
  m.set("NORMdotSdotINV", eval_function_stats_2)
  m.set("NORM.S.INV", eval_function_stats_2)
  m.set("_XLFN.NORM.S.INV", eval_function_stats_2)
  m.set("NORMSINV", eval_function_stats_2)
  m.set("LOGNORMdotDIST", eval_function_stats_2)
  m.set("LOGNORM.DIST", eval_function_stats_2)
  m.set("_XLFN.LOGNORM.DIST", eval_function_stats_2)
  m.set("LOGNORMDIST", eval_function_stats_2)
  m.set("LOGINV", eval_function_stats_2)
  m.set("LOGNORMdotINV", eval_function_stats_2)
  m.set("LOGNORM.INV", eval_function_stats_2)
  m.set("_XLFN.LOGNORM.INV", eval_function_stats_2)
  m.set("GAMMA", eval_function_stats_2)
  m.set("GAMMAdotDIST", eval_function_stats_2)
  m.set("GAMMA.DIST", eval_function_stats_2)
  m.set("_XLFN.GAMMA.DIST", eval_function_stats_2)
  m.set("GAMMADIST", eval_function_stats_2)
  m.set("GAMMAdotINV", eval_function_stats_2)
  m.set("GAMMA.INV", eval_function_stats_2)
  m.set("_XLFN.GAMMA.INV", eval_function_stats_2)
  m.set("GAMMAINV", eval_function_stats_2)
  m.set("GAMMALN", eval_function_stats_2)
  m.set("GAMMALNdotPRECISE", eval_function_stats_2)
  m.set("GAMMALN.PRECISE", eval_function_stats_2)
  m.set("_XLFN.GAMMALN.PRECISE", eval_function_stats_2)
  m.set("EXPONdotDIST", eval_function_stats_2)
  m.set("EXPON.DIST", eval_function_stats_2)
  m.set("_XLFN.EXPON.DIST", eval_function_stats_2)
  m.set("EXPONDIST", eval_function_stats_2)
  m.set("POISSONdotDIST", eval_function_stats_2)
  m.set("POISSON.DIST", eval_function_stats_2)
  m.set("_XLFN.POISSON.DIST", eval_function_stats_2)
  m.set("POISSON", eval_function_stats_2)
  m.set("PROB", eval_function_stats_2)
  m.set("BINOMdotDIST", eval_function_stats_2)
  m.set("BINOM.DIST", eval_function_stats_2)
  m.set("_XLFN.BINOM.DIST", eval_function_stats_2)
  m.set("BINOMDIST", eval_function_stats_2)
  m.set("BINOMdotDISTdotRANGE", eval_function_stats_2)
  m.set("BINOM.DIST.RANGE", eval_function_stats_2)
  m.set("_XLFN.BINOM.DIST.RANGE", eval_function_stats_2)
  m.set("BINOMdotINV", eval_function_stats_3)
  m.set("BINOM.INV", eval_function_stats_3)
  m.set("_XLFN.BINOM.INV", eval_function_stats_3)
  m.set("CRITBINOM", eval_function_stats_3)
  m.set("HYPGEOMdotDIST", eval_function_stats_3)
  m.set("HYPGEOM.DIST", eval_function_stats_3)
  m.set("_XLFN.HYPGEOM.DIST", eval_function_stats_3)
  m.set("HYPGEOMDIST", eval_function_stats_3)
  m.set("NEGBINOMdotDIST", eval_function_stats_3)
  m.set("NEGBINOM.DIST", eval_function_stats_3)
  m.set("_XLFN.NEGBINOM.DIST", eval_function_stats_3)
  m.set("NEGBINOMDIST", eval_function_stats_3)
  m.set("GAUSS", eval_function_stats_3)
  m.set("PHI", eval_function_stats_3)
  m.set("CHIDIST", eval_function_stats_3)
  m.set("CHIINV", eval_function_stats_3)
  m.set("CHISQdotDIST", eval_function_stats_3)
  m.set("CHISQ.DIST", eval_function_stats_3)
  m.set("_XLFN.CHISQ.DIST", eval_function_stats_3)
  m.set("CHISQdotDISTdotRT", eval_function_stats_3)
  m.set("CHISQ.DIST.RT", eval_function_stats_3)
  m.set("_XLFN.CHISQ.DIST.RT", eval_function_stats_3)
  m.set("CHISQdotINV", eval_function_stats_3)
  m.set("CHISQ.INV", eval_function_stats_3)
  m.set("_XLFN.CHISQ.INV", eval_function_stats_3)
  m.set("CHISQdotINVdotRT", eval_function_stats_3)
  m.set("CHISQ.INV.RT", eval_function_stats_3)
  m.set("_XLFN.CHISQ.INV.RT", eval_function_stats_3)
  m.set("CHITEST", eval_function_stats_3)
  m.set("CHISQdotTEST", eval_function_stats_3)
  m.set("CHISQ.TEST", eval_function_stats_3)
  m.set("_XLFN.CHISQ.TEST", eval_function_stats_3)
  m.set("FdotDIST", eval_function_stats_3)
  m.set("F.DIST", eval_function_stats_3)
  m.set("_XLFN.F.DIST", eval_function_stats_3)
  m.set("FDIST", eval_function_stats_3)
  m.set("FdotDISTdotRT", eval_function_stats_3)
  m.set("F.DIST.RT", eval_function_stats_3)
  m.set("_XLFN.F.DIST.RT", eval_function_stats_3)
  m.set("FdotINV", eval_function_stats_3)
  m.set("F.INV", eval_function_stats_3)
  m.set("_XLFN.F.INV", eval_function_stats_3)
  m.set("FdotINVdotRT", eval_function_stats_3)
  m.set("F.INV.RT", eval_function_stats_3)
  m.set("_XLFN.F.INV.RT", eval_function_stats_3)
  m.set("FINV", eval_function_stats_3)
  m.set("FTEST", eval_function_stats_3)
  m.set("FdotTEST", eval_function_stats_3)
  m.set("F.TEST", eval_function_stats_3)
  m.set("_XLFN.F.TEST", eval_function_stats_3)
  m.set("TdotDIST", eval_function_stats_3)
  m.set("T.DIST", eval_function_stats_3)
  m.set("_XLFN.T.DIST", eval_function_stats_3)
  m.set("TdotDISTdot2T", eval_function_stats_3)
  m.set("T.DIST.2T", eval_function_stats_3)
  m.set("_XLFN.T.DIST.2T", eval_function_stats_3)
  m.set("TdotDISTdotRT", eval_function_stats_3)
  m.set("T.DIST.RT", eval_function_stats_3)
  m.set("_XLFN.T.DIST.RT", eval_function_stats_3)
  m.set("TDIST", eval_function_stats_3)
  m.set("TdotINV", eval_function_stats_3)
  m.set("T.INV", eval_function_stats_3)
  m.set("_XLFN.T.INV", eval_function_stats_3)
  m.set("TdotINVdot2T", eval_function_stats_3)
  m.set("T.INV.2T", eval_function_stats_3)
  m.set("_XLFN.T.INV.2T", eval_function_stats_3)
  m.set("TINV", eval_function_stats_3)
  m.set("TdotTEST", eval_function_stats_3)
  m.set("T.TEST", eval_function_stats_3)
  m.set("_XLFN.T.TEST", eval_function_stats_3)
  m.set("TTEST", eval_function_stats_3)
  m.set("ZdotTEST", eval_function_stats_3)
  m.set("Z.TEST", eval_function_stats_3)
  m.set("_XLFN.Z.TEST", eval_function_stats_3)
  m.set("ZTEST", eval_function_stats_3)
  m.set("DOLLAR", eval_function_text)
  m.set("LEN", eval_function_text)
  m.set("LENB", eval_function_text)
  m.set("LOWER", eval_function_text)
  m.set("UPPER", eval_function_text)
  m.set("PROPER", eval_function_text)
  m.set("DBCS", eval_function_text)
  m.set("TRIM", eval_function_text)
  m.set("LEFT", eval_function_text)
  m.set("LEFTB", eval_function_text)
  m.set("RIGHT", eval_function_text)
  m.set("RIGHTB", eval_function_text)
  m.set("MID", eval_function_text)
  m.set("MIDB", eval_function_text)
  m.set("REPT", eval_function_text)
  m.set("REPLACE", eval_function_text)
  m.set("REPLACEB", eval_function_text)
  m.set("SUBSTITUTE", eval_function_text)
  m.set("FIND", eval_function_text)
  m.set("FINDB", eval_function_text)
  m.set("SEARCH", eval_function_text)
  m.set("SEARCHB", eval_function_text)
  m.set("EXACT", eval_function_text)
  m.set("FIXED", eval_function_text)
  m.set("VALUE", eval_function_text)
  m.set("VALUETOTEXT", eval_function_text)
  m.set("TEXT", eval_function_text)
  m.set("ARRAYTOTEXT", eval_function_text)
  m.set("TEXTAFTER", eval_function_text)
  m.set("TEXTBEFORE", eval_function_text)
  m.set("_XLFN.TEXTAFTER", eval_function_text)
  m.set("_XLFN.TEXTBEFORE", eval_function_text)
  m.set("TEXTSPLIT", eval_function_text)
  m.set("_XLFN.TEXTSPLIT", eval_function_text)
  m.set("TEXTJOIN", eval_function_text)
  m.set("CHAR", eval_function_text)
  m.set("UNICHAR", eval_function_text)
  m.set("CLEAN", eval_function_text)
  m.set("ENCODEURL", eval_function_text)
  m.set("BAHTTEXT", eval_function_text)
  m.set("CODE", eval_function_text)
  m.set("UNICODE", eval_function_text)
  m.set("CONCAT", eval_function_text)
  m.set("CONCATENATE", eval_function_text)
  m.set("T", eval_function_text)
  m.set("TRANSPOSE", eval_function_lookup)
  m.set("SEQUENCE", eval_function_lookup)
  m.set("_XLFN.SEQUENCE", eval_function_lookup)
  m.set("TAKE", eval_function_lookup)
  m.set("_XLFN.TAKE", eval_function_lookup)
  m.set("DROP", eval_function_lookup)
  m.set("_XLFN.DROP", eval_function_lookup)
  m.set("CHOOSECOLS", eval_function_lookup)
  m.set("_XLFN.CHOOSECOLS", eval_function_lookup)
  m.set("CHOOSEROWS", eval_function_lookup)
  m.set("_XLFN.CHOOSEROWS", eval_function_lookup)
  m.set("HSTACK", eval_function_lookup)
  m.set("_XLFN.HSTACK", eval_function_lookup)
  m.set("VSTACK", eval_function_lookup)
  m.set("_XLFN.VSTACK", eval_function_lookup)
  m.set("EXPAND", eval_function_lookup)
  m.set("_XLFN.EXPAND", eval_function_lookup)
  m.set("WRAPROWS", eval_function_lookup)
  m.set("_XLFN.WRAPROWS", eval_function_lookup)
  m.set("WRAPCOLS", eval_function_lookup)
  m.set("_XLFN.WRAPCOLS", eval_function_lookup)
  m.set("TOCOL", eval_function_lookup)
  m.set("_XLFN.TOCOL", eval_function_lookup)
  m.set("TOROW", eval_function_lookup)
  m.set("_XLFN.TOROW", eval_function_lookup)
  m.set("SORT", eval_function_lookup)
  m.set("_XLFN.SORT", eval_function_lookup)
  m.set("SORTBY", eval_function_lookup)
  m.set("_XLFN.SORTBY", eval_function_lookup)
  m.set("FILTER", eval_function_lookup)
  m.set("_XLFN.FILTER", eval_function_lookup)
  m.set("UNIQUE", eval_function_lookup)
  m.set("_XLFN.UNIQUE", eval_function_lookup)
  m.set("INDEX", eval_function_lookup)
  m.set("MATCH", eval_function_lookup)
  m.set("VLOOKUP", eval_function_lookup)
  m.set("HLOOKUP", eval_function_lookup)
  m.set("LOOKUP", eval_function_lookup)
  m.set("XLOOKUP", eval_function_lookup)
  m.set("_XLFN.XLOOKUP", eval_function_lookup)
  m.set("ANCHORARRAY", eval_function_lookup)
  m.set("_XLFN.ANCHORARRAY", eval_function_lookup)
  m.set("ADDRESS", eval_function_lookup)
  m.set("INDIRECT", eval_function_lookup)
  m.set("HYPERLINK", eval_function_lookup)
  m.set("CHOOSE", eval_function_lookup)
}

///|
fn eval_register_plain(m : @hashmap.HashMap[String, PlainHandler]) -> Unit {
  m.set("BITOR", eval_function_math_2)
  m.set("BITOR", eval_function_math_2)
  m.set("BITRSHIFT", eval_function_math_2)
  m.set("BITRSHIFT", eval_function_math_2)
  m.set("BITXOR", eval_function_math_2)
  m.set("BITXOR", eval_function_math_2)
  m.set("ACOS", eval_function_math_2)
  m.set("ACOSH", eval_function_math_2)
  m.set("ACOT", eval_function_math_2)
  m.set("_XLFN.ACOT", eval_function_math_2)
  m.set("ACOTH", eval_function_math_2)
  m.set("_XLFN.ACOTH", eval_function_math_2)
  m.set("ASIN", eval_function_math_2)
  m.set("ASINH", eval_function_math_2)
  m.set("ATAN", eval_function_math_2)
  m.set("ATANH", eval_function_math_2)
  m.set("ATAN2", eval_function_math_2)
  m.set("COS", eval_function_math_2)
  m.set("COSH", eval_function_math_2)
  m.set("SIN", eval_function_math_2)
  m.set("SINH", eval_function_math_2)
  m.set("TAN", eval_function_math_2)
  m.set("TANH", eval_function_math_2)
  m.set("COT", eval_function_math_2)
  m.set("_XLFN.COT", eval_function_math_2)
  m.set("COTH", eval_function_math_2)
  m.set("_XLFN.COTH", eval_function_math_2)
  m.set("CSC", eval_function_math_2)
  m.set("_XLFN.CSC", eval_function_math_2)
  m.set("CSCH", eval_function_math_2)
  m.set("_XLFN.CSCH", eval_function_math_2)
  m.set("SEC", eval_function_math_2)
  m.set("_XLFN.SEC", eval_function_math_2)
  m.set("SECH", eval_function_math_2)
  m.set("_XLFN.SECH", eval_function_math_2)
  m.set("DEGREES", eval_function_math_2)
  m.set("RADIANS", eval_function_math_2)
  m.set("RAND", eval_function_math_2)
  m.set("RANDARRAY", eval_function_math_2)
  m.set("_XLFN.RANDARRAY", eval_function_math_2)
  m.set("RANDBETWEEN", eval_function_math_2)
  m.set("PI", eval_function_math_2)
  m.set("SQRTPI", eval_function_math_2)
  m.set("LOG", eval_function_math_2)
  m.set("LOG10", eval_function_math_2)
  m.set("IMABS", eval_function_math_2)
  m.set("IMAGINARY", eval_function_math_2)
  m.set("IMARGUMENT", eval_function_math_2)
  m.set("IMCONJUGATE", eval_function_math_2)
  m.set("IMCOS", eval_function_math_2)
  m.set("IMCOSH", eval_function_math_2)
  m.set("IMCOT", eval_function_math_2)
  m.set("IMCSC", eval_function_math_2)
  m.set("IMCSCH", eval_function_math_2)
  m.set("IMDIV", eval_function_math_2)
  m.set("IMEXP", eval_function_math_2)
  m.set("IMLN", eval_function_math_2)
  m.set("IMLOG10", eval_function_math_2)
  m.set("IMLOG2", eval_function_math_2)
  m.set("IMPOWER", eval_function_math_2)
  m.set("IMPRODUCT", eval_function_math_2)
  m.set("IMREAL", eval_function_math_2)
  m.set("IMSEC", eval_function_math_2)
  m.set("IMSECH", eval_function_math_2)
  m.set("IMSIN", eval_function_math_2)
  m.set("IMSINH", eval_function_math_2)
  m.set("IMSQRT", eval_function_math_2)
  m.set("IMSUB", eval_function_math_2)
  m.set("IMSUM", eval_function_math_2)
  m.set("IMTAN", eval_function_math_2)
  m.set("FLOOR", eval_function_math_2)
  m.set("CEILING", eval_function_math_2)
  m.set("CEILINGdotMATH", eval_function_math_2)
  m.set("CEILING.MATH", eval_function_math_2)
  m.set("_XLFN.CEILING.MATH", eval_function_math_2)
  m.set("CEILINGdotPRECISE", eval_function_math_3)
  m.set("CEILING.PRECISE", eval_function_math_3)
  m.set("_XLFN.CEILING.PRECISE", eval_function_math_3)
  m.set("FLOORdotMATH", eval_function_math_3)
  m.set("FLOOR.MATH", eval_function_math_3)
  m.set("_XLFN.FLOOR.MATH", eval_function_math_3)
  m.set("FLOORdotPRECISE", eval_function_math_3)
  m.set("FLOOR.PRECISE", eval_function_math_3)
  m.set("_XLFN.FLOOR.PRECISE", eval_function_math_3)
  m.set("ISOdotCEILING", eval_function_math_3)
  m.set("ISO.CEILING", eval_function_math_3)
  m.set("_XLFN.ISO.CEILING", eval_function_math_3)
  m.set("TRUNC", eval_function_math_3)
  m.set("ROUND", eval_function_math_3)
  m.set("ROUNDUP", eval_function_math_3)
  m.set("ROUNDDOWN", eval_function_math_3)
  m.set("SQRT", eval_function_math_3)
  m.set("POWER", eval_function_math_3)
  m.set("EVEN", eval_function_math_3)
  m.set("ODD", eval_function_math_3)
  m.set("MROUND", eval_function_math_3)
  m.set("MOD", eval_function_math_3)
  m.set("QUOTIENT", eval_function_math_3)
  m.set("ACCRINT", eval_function_financial)
  m.set("ACCRINTM", eval_function_financial)
  m.set("AMORDEGRC", eval_function_financial)
  m.set("AMORLINC", eval_function_financial)
  m.set("COUPDAYBS", eval_function_financial)
  m.set("COUPDAYS", eval_function_financial)
  m.set("COUPDAYSNC", eval_function_financial)
  m.set("COUPNCD", eval_function_financial)
  m.set("COUPNUM", eval_function_financial)
  m.set("COUPPCD", eval_function_financial)
  m.set("CUMIPMT", eval_function_financial)
  m.set("CUMIPMT", eval_function_financial)
  m.set("CUMPRINC", eval_function_financial)
  m.set("CUMPRINC", eval_function_financial)
  m.set("DURATION", eval_function_financial)
  m.set("DB", eval_function_financial)
  m.set("DDB", eval_function_financial)
  m.set("FV", eval_function_financial)
  m.set("FVSCHEDULE", eval_function_financial)
  m.set("DISC", eval_function_financial)
  m.set("INTRATE", eval_function_financial)
  m.set("IRR", eval_function_financial)
  m.set("MDURATION", eval_function_financial)
  m.set("MIRR", eval_function_financial)
  m.set("DOLLARDE", eval_function_financial)
  m.set("DOLLARDE", eval_function_financial)
  m.set("DOLLARFR", eval_function_financial)
  m.set("DOLLARFR", eval_function_financial)
  m.set("EFFECT", eval_function_financial)
  m.set("IPMT", eval_function_financial)
  m.set("IPMT", eval_function_financial)
  m.set("ISPMT", eval_function_financial)
  m.set("NOMINAL", eval_function_financial)
  m.set("NPER", eval_function_financial)
  m.set("NPV", eval_function_financial)
  m.set("ODDFPRICE", eval_function_financial)
  m.set("ODDFYIELD", eval_function_financial)
  m.set("ODDLPRICE", eval_function_financial)
  m.set("ODDLYIELD", eval_function_financial)
  m.set("PDURATION", eval_function_financial)
  m.set("PMT", eval_function_financial)
  m.set("PPMT", eval_function_financial)
  m.set("PPMT", eval_function_financial)
  m.set("PRICE", eval_function_financial)
  m.set("PRICEDISC", eval_function_financial)
  m.set("PRICEMAT", eval_function_financial)
  m.set("PV", eval_function_financial)
  m.set("RATE", eval_function_financial)
  m.set("RECEIVED", eval_function_financial)
  m.set("RRI", eval_function_financial)
  m.set("SLN", eval_function_financial)
  m.set("SYD", eval_function_financial)
  m.set("TBILLEQ", eval_function_financial)
  m.set("TBILLPRICE", eval_function_financial)
  m.set("TBILLYIELD", eval_function_financial)
  m.set("XIRR", eval_function_financial)
  m.set("XNPV", eval_function_financial)
  m.set("YIELD", eval_function_financial)
  m.set("YIELDDISC", eval_function_financial)
  m.set("YIELDMAT", eval_function_financial)
  m.set("VDB", eval_function_financial)
  m.set("DATE", eval_function_date_time)
  m.set("TIME", eval_function_date_time)
  m.set("DATEVALUE", eval_function_date_time)
  m.set("TIMEVALUE", eval_function_date_time)
  m.set("DATEDIF", eval_function_date_time)
  m.set("DAYS", eval_function_date_time)
  m.set("DAYS360", eval_function_date_time)
  m.set("ISOWEEKNUM", eval_function_date_time)
  m.set("EDATE", eval_function_date_time)
  m.set("EOMONTH", eval_function_date_time)
  m.set("YEARFRAC", eval_function_date_time)
  m.set("WEEKDAY", eval_function_date_time)
  m.set("WEEKNUM", eval_function_date_time)
  m.set("NETWORKDAYS", eval_function_date_time)
  m.set("NETWORKDAYS.INTL", eval_function_date_time)
  m.set("WORKDAY", eval_function_date_time)
  m.set("WORKDAY.INTL", eval_function_date_time)
  m.set("NOW", eval_function_date_time)
  m.set("TODAY", eval_function_date_time)
  m.set("YEAR", eval_function_date_time)
  m.set("MONTH", eval_function_date_time)
  m.set("DAY", eval_function_date_time)
  m.set("HOUR", eval_function_date_time)
  m.set("MINUTE", eval_function_date_time)
  m.set("SECOND", eval_function_date_time)
  m.set("DISPIMG", eval_function_info)
  m.set("_XLFN.DISPIMG", eval_function_info)
  m.set("ISBLANK", eval_function_info)
  m.set("ISERR", eval_function_info)
  m.set("ISEVEN", eval_function_info)
  m.set("ISODD", eval_function_info)
  m.set("ISERROR", eval_function_info)
  m.set("ISLOGICAL", eval_function_info)
  m.set("ISNA", eval_function_info)
  m.set("ISNUMBER", eval_function_info)
  m.set("ISTEXT", eval_function_info)
  m.set("ISNONTEXT", eval_function_info)
  m.set("ISREF", eval_function_info)
  m.set("ISFORMULA", eval_function_info)
  m.set("ERRORdotTYPE", eval_function_info)
  m.set("ERROR.TYPE", eval_function_info)
  m.set("SHEET", eval_function_info)
  m.set("SHEETS", eval_function_info)
  m.set("TYPE", eval_function_info)
  m.set("NA", eval_function_info)
  m.set("N", eval_function_info)
  m.set("TRUE", eval_function_logical)
  m.set("FALSE", eval_function_logical)
  m.set("AND", eval_function_logical)
  m.set("OR", eval_function_logical)
  m.set("NOT", eval_function_logical)
  m.set("XOR", eval_function_logical)
  m.set("IF", eval_function_logical)
  m.set("IFERROR", eval_function_logical)
  m.set("IFNA", eval_function_logical)
  m.set("IFS", eval_function_logical)
  m.set("SWITCH", eval_function_logical)
}

///|
fn eval_function_math_1(
  workbook : Workbook,
  sheet_name : String,
  name : String,
  args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue raise XlsxError {
  match name {
    "SUM" => sum_values(values)
    "SUBTOTAL" => subtotal_values(values)
    "AGGREGATE" => aggregate_values(values)
    "PRODUCT" => product_values(values)
    "SIGN" => sign_values(workbook, sheet_name, name, args, values, ctx)
    "SERIESSUM" =>
      seriessum_values(workbook, sheet_name, name, args, values, ctx)
    "SUMIF" => sumif_values2(workbook, sheet_name, name, args, values, ctx)
    "SUMPRODUCT" =>
      sumproduct_values2(workbook, sheet_name, name, args, values, ctx)
    "SUMSQ" => sumsq_values(values)
    "SUMX2MY2" => sumx2my2_values(workbook, sheet_name, name, args, values, ctx)
    "SUMX2PY2" => sumx2py2_values(workbook, sheet_name, name, args, values, ctx)
    "SUMXMY2" => sumxmy2_values(workbook, sheet_name, name, args, values, ctx)
    "SUMIFS" => sumifs_values(workbook, sheet_name, name, args, values, ctx)
    "GCD" => gcd_values(values)
    "LCM" => lcm_values(values)
    "COMBIN" => combin_values2(workbook, sheet_name, name, args, values, ctx)
    "COMBINA" | "_XLFN.COMBINA" =>
      combina_xlfn_combina_values(workbook, sheet_name, name, args, values, ctx)
    "COMPLEX" => complex_values(workbook, sheet_name, name, args, values, ctx)
    "FACT" => fact_values(workbook, sheet_name, name, args, values, ctx)
    "FACTDOUBLE" =>
      factdouble_values(workbook, sheet_name, name, args, values, ctx)
    "MULTINOMIAL" => multinomial_values(values)
    "MDETERM" => mdeterm_values(workbook, sheet_name, name, args, values, ctx)
    "MINVERSE" => minverse_values(workbook, sheet_name, name, args, values, ctx)
    "MMULT" => mmult_values(workbook, sheet_name, name, args, values, ctx)
    "MUNIT" | "_XLFN.MUNIT" =>
      munit_xlfn_munit_values(workbook, sheet_name, name, args, values, ctx)
    "ABS" => abs_values(workbook, sheet_name, name, args, values, ctx)
    "INT" => int_values(workbook, sheet_name, name, args, values, ctx)
    "LN" => ln_values(workbook, sheet_name, name, args, values, ctx)
    "EXP" => exp_values(workbook, sheet_name, name, args, values, ctx)
    "DECIMAL" | "_XLFN.DECIMAL" =>
      decimal_xlfn_decimal_values(workbook, sheet_name, name, args, values, ctx)
    "ROMAN" => roman_values(workbook, sheet_name, name, args, values, ctx)
    "ARABIC" | "_XLFN.ARABIC" =>
      arabic_xlfn_arabic_values(workbook, sheet_name, name, args, values, ctx)
    "BASE" => base_values(values)
    "BIN2DEC" => bin2dec_values(workbook, sheet_name, name, args, values, ctx)
    "BIN2HEX" => bin2hex_values(workbook, sheet_name, name, args, values, ctx)
    "BIN2OCT" => bin2oct_values(workbook, sheet_name, name, args, values, ctx)
    "DEC2BIN" => dec2x_values("DEC2BIN", values)
    "DEC2HEX" => dec2x_values("DEC2HEX", values)
    "DEC2OCT" => dec2x_values("DEC2OCT", values)
    "HEX2BIN" => hex2bin_values(workbook, sheet_name, name, args, values, ctx)
    "HEX2DEC" => hex2dec_values(workbook, sheet_name, name, args, values, ctx)
    "HEX2OCT" => hex2oct_values(workbook, sheet_name, name, args, values, ctx)
    "OCT2BIN" => oct2bin_values(workbook, sheet_name, name, args, values, ctx)
    "OCT2DEC" => oct2dec_values(workbook, sheet_name, name, args, values, ctx)
    "OCT2HEX" => oct2hex_values(workbook, sheet_name, name, args, values, ctx)
    "BESSELI" => besseli_values(workbook, sheet_name, name, args, values, ctx)
    "BESSELJ" => besselj_values(workbook, sheet_name, name, args, values, ctx)
    "BESSELK" => besselk_values(workbook, sheet_name, name, args, values, ctx)
    "BESSELY" => bessely_values(workbook, sheet_name, name, args, values, ctx)
    "DELTA" => delta_values(workbook, sheet_name, name, args, values, ctx)
    "ERF" => erf_values(workbook, sheet_name, name, args, values, ctx)
    "ERFdotPRECISE" | "ERF.PRECISE" | "_XLFN.ERF.PRECISE" =>
      erfdotpreciseerf_precise_xlfn_erf_precise_values(
        workbook, sheet_name, name, args, values, ctx,
      )
    "ERFC" => erfc_values(workbook, sheet_name, name, args, values, ctx)
    "ERFCdotPRECISE" | "ERFC.PRECISE" | "_XLFN.ERFC.PRECISE" =>
      erfcdotpreciseerfc_precise_xlfn_erfc_precise_values(
        workbook, sheet_name, name, args, values, ctx,
      )
    "CONVERT" => convert_values(values)
    "EUROCONVERT" => euroconvert_values(values)
    "GESTEP" => gestep_values(workbook, sheet_name, name, args, values, ctx)
    "BITAND" => bitwise_values("BITAND", values)
    "BITLSHIFT" => bitwise_values("BITLSHIFT", values)
    _ => Error(formula_error_name)
  }
}

///|
fn eval_function_math_2(
  workbook : Workbook,
  sheet_name : String,
  name : String,
  args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue {
  match name {
    "BITOR" => bitwise_values("BITOR", values)
    "BITRSHIFT" => bitwise_values("BITRSHIFT", values)
    "BITXOR" => bitwise_values("BITXOR", values)
    "ACOS" => acos_values(workbook, sheet_name, name, args, values, ctx)
    "ACOSH" => acosh_values(workbook, sheet_name, name, args, values, ctx)
    "ACOT" | "_XLFN.ACOT" =>
      acot_xlfn_acot_values(workbook, sheet_name, name, args, values, ctx)
    "ACOTH" | "_XLFN.ACOTH" =>
      acoth_xlfn_acoth_values(workbook, sheet_name, name, args, values, ctx)
    "ASIN" => asin_values(workbook, sheet_name, name, args, values, ctx)
    "ASINH" => asinh_values(workbook, sheet_name, name, args, values, ctx)
    "ATAN" => atan_values(workbook, sheet_name, name, args, values, ctx)
    "ATANH" => atanh_values(workbook, sheet_name, name, args, values, ctx)
    "ATAN2" => atan2_values(workbook, sheet_name, name, args, values, ctx)
    "COS" => cos_values(workbook, sheet_name, name, args, values, ctx)
    "COSH" => cosh_values(workbook, sheet_name, name, args, values, ctx)
    "SIN" => sin_values(workbook, sheet_name, name, args, values, ctx)
    "SINH" => sinh_values(workbook, sheet_name, name, args, values, ctx)
    "TAN" => tan_values(workbook, sheet_name, name, args, values, ctx)
    "TANH" => tanh_values(workbook, sheet_name, name, args, values, ctx)
    "COT" | "_XLFN.COT" =>
      cot_xlfn_cot_values(workbook, sheet_name, name, args, values, ctx)
    "COTH" | "_XLFN.COTH" =>
      coth_xlfn_coth_values(workbook, sheet_name, name, args, values, ctx)
    "CSC" | "_XLFN.CSC" =>
      csc_xlfn_csc_values(workbook, sheet_name, name, args, values, ctx)
    "CSCH" | "_XLFN.CSCH" =>
      csch_xlfn_csch_values(workbook, sheet_name, name, args, values, ctx)
    "SEC" | "_XLFN.SEC" =>
      sec_xlfn_sec_values(workbook, sheet_name, name, args, values, ctx)
    "SECH" | "_XLFN.SECH" =>
      sech_xlfn_sech_values(workbook, sheet_name, name, args, values, ctx)
    "DEGREES" => degrees_values(workbook, sheet_name, name, args, values, ctx)
    "RADIANS" => radians_values(workbook, sheet_name, name, args, values, ctx)
    "RAND" => rand_values(workbook, sheet_name, name, args, values, ctx)
    "RANDARRAY" | "_XLFN.RANDARRAY" => randarray_values(values)
    "RANDBETWEEN" =>
      randbetween_values(workbook, sheet_name, name, args, values, ctx)
    "PI" => pi_values(workbook, sheet_name, name, args, values, ctx)
    "SQRTPI" => sqrtpi_values(workbook, sheet_name, name, args, values, ctx)
    "LOG" => log_values(workbook, sheet_name, name, args, values, ctx)
    "LOG10" => log10_values(workbook, sheet_name, name, args, values, ctx)
    "IMABS" => imabs_values(workbook, sheet_name, name, args, values, ctx)
    "IMAGINARY" =>
      imaginary_values(workbook, sheet_name, name, args, values, ctx)
    "IMARGUMENT" =>
      imargument_values(workbook, sheet_name, name, args, values, ctx)
    "IMCONJUGATE" =>
      imconjugate_values(workbook, sheet_name, name, args, values, ctx)
    "IMCOS" => imcos_values(workbook, sheet_name, name, args, values, ctx)
    "IMCOSH" => imcosh_values(workbook, sheet_name, name, args, values, ctx)
    "IMCOT" => imcot_values(workbook, sheet_name, name, args, values, ctx)
    "IMCSC" => imcsc_values(workbook, sheet_name, name, args, values, ctx)
    "IMCSCH" => imcsch_values(workbook, sheet_name, name, args, values, ctx)
    "IMDIV" => imdiv_values(workbook, sheet_name, name, args, values, ctx)
    "IMEXP" => imexp_values(workbook, sheet_name, name, args, values, ctx)
    "IMLN" => imln_values(workbook, sheet_name, name, args, values, ctx)
    "IMLOG10" => imlog10_values(workbook, sheet_name, name, args, values, ctx)
    "IMLOG2" => imlog2_values(workbook, sheet_name, name, args, values, ctx)
    "IMPOWER" => impower_values(workbook, sheet_name, name, args, values, ctx)
    "IMPRODUCT" =>
      improduct_values(workbook, sheet_name, name, args, values, ctx)
    "IMREAL" => imreal_values(workbook, sheet_name, name, args, values, ctx)
    "IMSEC" => imsec_values(workbook, sheet_name, name, args, values, ctx)
    "IMSECH" => imsech_values(workbook, sheet_name, name, args, values, ctx)
    "IMSIN" => imsin_values(workbook, sheet_name, name, args, values, ctx)
    "IMSINH" => imsinh_values(workbook, sheet_name, name, args, values, ctx)
    "IMSQRT" => imsqrt_values(workbook, sheet_name, name, args, values, ctx)
    "IMSUB" => imsub_values(workbook, sheet_name, name, args, values, ctx)
    "IMSUM" => imsum_values(workbook, sheet_name, name, args, values, ctx)
    "IMTAN" => imtan_values(workbook, sheet_name, name, args, values, ctx)
    "FLOOR" => floor_values(workbook, sheet_name, name, args, values, ctx)
    "CEILING" => ceiling_values(workbook, sheet_name, name, args, values, ctx)
    "CEILINGdotMATH" | "CEILING.MATH" | "_XLFN.CEILING.MATH" =>
      ceilingdotmathceiling_math_xlfn_ceiling_math_values(
        workbook, sheet_name, name, args, values, ctx,
      )
    _ => Error(formula_error_name)
  }
}

///|
fn eval_function_math_3(
  workbook : Workbook,
  sheet_name : String,
  name : String,
  args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue {
  match name {
    "CEILINGdotPRECISE" | "CEILING.PRECISE" | "_XLFN.CEILING.PRECISE" =>
      ceilingdotpreciseceiling_precise_xlfn_ceiling_precise_values(
        workbook, sheet_name, name, args, values, ctx,
      )
    "FLOORdotMATH" | "FLOOR.MATH" | "_XLFN.FLOOR.MATH" =>
      floordotmathfloor_math_xlfn_floor_math_values(
        workbook, sheet_name, name, args, values, ctx,
      )
    "FLOORdotPRECISE" | "FLOOR.PRECISE" | "_XLFN.FLOOR.PRECISE" =>
      floordotprecisefloor_precise_xlfn_floor_precise_values(
        workbook, sheet_name, name, args, values, ctx,
      )
    "ISOdotCEILING" | "ISO.CEILING" | "_XLFN.ISO.CEILING" =>
      isodotceilingiso_ceiling_xlfn_iso_ceiling_values(
        workbook, sheet_name, name, args, values, ctx,
      )
    "TRUNC" => trunc_values(workbook, sheet_name, name, args, values, ctx)
    "ROUND" => round_values(workbook, sheet_name, name, args, values, ctx)
    "ROUNDUP" => roundup_values(workbook, sheet_name, name, args, values, ctx)
    "ROUNDDOWN" =>
      rounddown_values(workbook, sheet_name, name, args, values, ctx)
    "SQRT" => sqrt_values(workbook, sheet_name, name, args, values, ctx)
    "POWER" => power_values(workbook, sheet_name, name, args, values, ctx)
    "EVEN" => even_values(workbook, sheet_name, name, args, values, ctx)
    "ODD" => odd_values(workbook, sheet_name, name, args, values, ctx)
    "MROUND" => mround_values(workbook, sheet_name, name, args, values, ctx)
    "MOD" => mod_values(workbook, sheet_name, name, args, values, ctx)
    "QUOTIENT" => quotient_values(workbook, sheet_name, name, args, values, ctx)
    _ => Error(formula_error_name)
  }
}

///|
fn eval_function_stats_1(
  workbook : Workbook,
  sheet_name : String,
  name : String,
  args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue raise XlsxError {
  match name {
    "AVERAGE" => average_values(values)
    "AVERAGEA" => averagea_values(values)
    "STDEV" | "STDEV.S" =>
      stdevstdev_s_values(workbook, sheet_name, name, args, values, ctx)
    "STDEVA" => stdeva_values(workbook, sheet_name, name, args, values, ctx)
    "STDEVP" | "STDEV.P" =>
      stdevpstdev_p_values(workbook, sheet_name, name, args, values, ctx)
    "STDEVPA" => stdevpa_values(workbook, sheet_name, name, args, values, ctx)
    "VAR" | "VAR.S" =>
      varvar_s_values(workbook, sheet_name, name, args, values, ctx)
    "VARA" => vara_values(workbook, sheet_name, name, args, values, ctx)
    "VARP" | "VAR.P" =>
      varpvar_p_values(workbook, sheet_name, name, args, values, ctx)
    "VARPA" => varpa_values(workbook, sheet_name, name, args, values, ctx)
    "TRIMMEAN" => trimmean_values(values)
    "AVEDEV" => avedev_values2(workbook, sheet_name, name, args, values, ctx)
    "DEVSQ" => devsq_values2(workbook, sheet_name, name, args, values, ctx)
    "GEOMEAN" => geomean_values2(workbook, sheet_name, name, args, values, ctx)
    "HARMEAN" => harmean_values2(workbook, sheet_name, name, args, values, ctx)
    "KURT" => kurt_values2(workbook, sheet_name, name, args, values, ctx)
    "SKEW" => skew_values2(workbook, sheet_name, name, args, values, ctx)
    "SKEW.P" => skew_p_values(workbook, sheet_name, name, args, values, ctx)
    "STANDARDIZE" =>
      standardize_values2(workbook, sheet_name, name, args, values, ctx)
    "LARGE" => large_values(workbook, sheet_name, name, args, values, ctx)
    "SMALL" => small_values(workbook, sheet_name, name, args, values, ctx)
    "MODE" => mode_values2(workbook, sheet_name, name, args, values, ctx)
    "MODE.SNGL" =>
      mode_sngl_values(workbook, sheet_name, name, args, values, ctx)
    "MODE.MULT" =>
      mode_mult_values2(workbook, sheet_name, name, args, values, ctx)
    "PERCENTILE" =>
      percentile_values2(workbook, sheet_name, name, args, values, ctx)
    "PERCENTILE.INC" =>
      percentile_inc_values(workbook, sheet_name, name, args, values, ctx)
    "PERCENTILE.EXC" =>
      percentile_exc_values(workbook, sheet_name, name, args, values, ctx)
    "PERCENTRANK" =>
      percentrank_values2(workbook, sheet_name, name, args, values, ctx)
    "PERCENTRANK.INC" =>
      percentrank_inc_values(workbook, sheet_name, name, args, values, ctx)
    "PERCENTRANK.EXC" =>
      percentrank_exc_values(workbook, sheet_name, name, args, values, ctx)
    "QUARTILE" =>
      quartile_values2(workbook, sheet_name, name, args, values, ctx)
    "QUARTILE.INC" =>
      quartile_inc_values(workbook, sheet_name, name, args, values, ctx)
    "QUARTILE.EXC" =>
      quartile_exc_values(workbook, sheet_name, name, args, values, ctx)
    "RANK" | "RANK.EQ" =>
      rankrank_eq_values(workbook, sheet_name, name, args, values, ctx)
    "CORREL" => correl_values2(workbook, sheet_name, name, args, values, ctx)
    "COVAR" => covar_values2(workbook, sheet_name, name, args, values, ctx)
    "COVARIANCE.P" =>
      covariance_p_values(workbook, sheet_name, name, args, values, ctx)
    "COVARIANCE.S" =>
      covariance_s_values(workbook, sheet_name, name, args, values, ctx)
    "PEARSON" => pearson_values(workbook, sheet_name, name, args, values, ctx)
    "RSQ" => rsq_values(workbook, sheet_name, name, args, values, ctx)
    "SLOPE" => slope_values(workbook, sheet_name, name, args, values, ctx)
    "INTERCEPT" =>
      intercept_values(workbook, sheet_name, name, args, values, ctx)
    "FORECAST" => forecast_values(workbook, sheet_name, name, args, values, ctx)
    "FORECAST.LINEAR" =>
      forecast_linear_values(workbook, sheet_name, name, args, values, ctx)
    "GROWTH" => growth_values(workbook, sheet_name, name, args, values, ctx)
    "TREND" => trend_values(workbook, sheet_name, name, args, values, ctx)
    "FISHER" => fisher_values(workbook, sheet_name, name, args, values, ctx)
    "FISHERINV" =>
      fisherinv_values(workbook, sheet_name, name, args, values, ctx)
    "STEYX" => steyx_values2(workbook, sheet_name, name, args, values, ctx)
    "MEDIAN" => median_values(values)
    "MIN" => min_values(values)
    "MAX" => max_values(values)
    "MINA" => mina_values(values)
    "MAXA" => maxa_values(values)
    "COUNT" => count_values(values)
    "COUNTA" => counta_values(values)
    "COUNTBLANK" =>
      countblank_values2(workbook, sheet_name, name, args, values, ctx)
    "FREQUENCY" => frequency_values(workbook, sheet_name, args, values, ctx)
    "COUNTIF" => countif_values2(workbook, sheet_name, name, args, values, ctx)
    "COUNTIFS" => countifs_values(workbook, sheet_name, name, args, values, ctx)
    _ => Error(formula_error_name)
  }
}

///|
fn eval_function_stats_2(
  workbook : Workbook,
  sheet_name : String,
  name : String,
  args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue raise XlsxError {
  match name {
    "DAVERAGE"
    | "DMAX"
    | "DMIN"
    | "DPRODUCT"
    | "DSTDEV"
    | "DSTDEVP"
    | "DSUM"
    | "DVAR"
    | "DVARP" => daverage_values(workbook, sheet_name, name, args, values, ctx)
    "DCOUNT" | "DCOUNTA" =>
      dcountdcounta_values(workbook, sheet_name, name, args, values, ctx)
    "DGET" => dget_values2(workbook, sheet_name, name, args, values, ctx)
    "AVERAGEIF" =>
      averageif_values2(workbook, sheet_name, name, args, values, ctx)
    "AVERAGEIFS" =>
      averageifs_values(workbook, sheet_name, name, args, values, ctx)
    "MAXIFS" => maxifs_values2(workbook, sheet_name, name, args, values, ctx)
    "MINIFS" => minifs_values2(workbook, sheet_name, name, args, values, ctx)
    "PERMUT" => permut_values(workbook, sheet_name, name, args, values, ctx)
    "PERMUTATIONA" =>
      permutationa_values(workbook, sheet_name, name, args, values, ctx)
    "WEIBULL" => weibull_value(values)
    "WEIBULLdotDIST" | "WEIBULL.DIST" | "_XLFN.WEIBULL.DIST" =>
      weibulldotdistweibull_dist_xlfn_weibull_dist_values(
        workbook, sheet_name, name, args, values, ctx,
      )
    "BETAdotDIST" | "BETA.DIST" | "_XLFN.BETA.DIST" => beta_dist_values(values)
    "BETADIST" => betadist_values(values)
    "BETAINV" => betainv_values(values)
    "BETAdotINV" | "BETA.INV" | "_XLFN.BETA.INV" => betainv_values(values)
    "CONFIDENCE" => confidence_values(values)
    "CONFIDENCEdotNORM" | "CONFIDENCE.NORM" | "_XLFN.CONFIDENCE.NORM" =>
      confidencedotnormconfidence_norm_xlfn_confidence_norm_values(
        workbook, sheet_name, name, args, values, ctx,
      )
    "CONFIDENCEdotT" | "CONFIDENCE.T" | "_XLFN.CONFIDENCE.T" =>
      confidencedottconfidence_t_xlfn_confidence_t_values(
        workbook, sheet_name, name, args, values, ctx,
      )
    "NORMdotDIST" | "NORM.DIST" | "_XLFN.NORM.DIST" => normdist_values(values)
    "NORMDIST" => normdist_values(values)
    "NORMdotINV" | "NORM.INV" | "_XLFN.NORM.INV" => norminv_values(values)
    "NORMINV" => norminv_values(values)
    "NORMdotSdotDIST" | "NORM.S.DIST" | "_XLFN.NORM.S.DIST" =>
      normdotsdotdistnorm_s_dist_xlfn_norm_s_dist_values(
        workbook, sheet_name, name, args, values, ctx,
      )
    "NORMSDIST" => norms_dist_values(values)
    "NORMdotSdotINV" | "NORM.S.INV" | "_XLFN.NORM.S.INV" =>
      normdotsdotinvnorm_s_inv_xlfn_norm_s_inv_values(
        workbook, sheet_name, name, args, values, ctx,
      )
    "NORMSINV" => norms_inv_values(values)
    "LOGNORMdotDIST" | "LOGNORM.DIST" | "_XLFN.LOGNORM.DIST" =>
      lognormdotdistlognorm_dist_xlfn_lognorm_dist_values(
        workbook, sheet_name, name, args, values, ctx,
      )
    "LOGNORMDIST" => lognormdist_values(values)
    "LOGINV" => loginv_values(values)
    "LOGNORMdotINV" | "LOGNORM.INV" | "_XLFN.LOGNORM.INV" =>
      lognormdotinvlognorm_inv_xlfn_lognorm_inv_values(
        workbook, sheet_name, name, args, values, ctx,
      )
    "GAMMA" => gamma_value(values)
    "GAMMAdotDIST" | "GAMMA.DIST" | "_XLFN.GAMMA.DIST" =>
      gammadotdistgamma_dist_xlfn_gamma_dist_values(
        workbook, sheet_name, name, args, values, ctx,
      )
    "GAMMADIST" => gamma_dist_values(values)
    "GAMMAdotINV" | "GAMMA.INV" | "_XLFN.GAMMA.INV" => gamma_inv_values(values)
    "GAMMAINV" => gamma_inv_values(values)
    "GAMMALN" => gammaln_values(values)
    "GAMMALNdotPRECISE" | "GAMMALN.PRECISE" | "_XLFN.GAMMALN.PRECISE" =>
      gammalndotprecisegammaln_precise_xlfn_gammaln_precise_values(
        workbook, sheet_name, name, args, values, ctx,
      )
    "EXPONdotDIST" | "EXPON.DIST" | "_XLFN.EXPON.DIST" =>
      expondotdistexpon_dist_xlfn_expon_dist_values(
        workbook, sheet_name, name, args, values, ctx,
      )
    "EXPONDIST" => expon_dist_values(values)
    "POISSONdotDIST" | "POISSON.DIST" | "_XLFN.POISSON.DIST" =>
      poissondotdistpoisson_dist_xlfn_poisson_dist_values(
        workbook, sheet_name, name, args, values, ctx,
      )
    "POISSON" => poisson_values(values)
    "PROB" => prob_values(values)
    "BINOMdotDIST" | "BINOM.DIST" | "_XLFN.BINOM.DIST" =>
      binomdotdistbinom_dist_xlfn_binom_dist_values(
        workbook, sheet_name, name, args, values, ctx,
      )
    "BINOMDIST" => binomdist_values(values)
    "BINOMdotDISTdotRANGE" | "BINOM.DIST.RANGE" | "_XLFN.BINOM.DIST.RANGE" =>
      binomdotdistdotrangebinom_dist_range_xlfn_binom_dist_range_values(
        workbook, sheet_name, name, args, values, ctx,
      )
    _ => Error(formula_error_name)
  }
}

///|
fn eval_function_stats_3(
  workbook : Workbook,
  sheet_name : String,
  name : String,
  args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue raise XlsxError {
  match name {
    "BINOMdotINV" | "BINOM.INV" | "_XLFN.BINOM.INV" => binom_inv_values(values)
    "CRITBINOM" => binom_inv_values(values)
    "HYPGEOMdotDIST" | "HYPGEOM.DIST" | "_XLFN.HYPGEOM.DIST" =>
      hypgeomdotdisthypgeom_dist_xlfn_hypgeom_dist_values(
        workbook, sheet_name, name, args, values, ctx,
      )
    "HYPGEOMDIST" => hypgeomdist_values(values)
    "NEGBINOMdotDIST" | "NEGBINOM.DIST" | "_XLFN.NEGBINOM.DIST" =>
      negbinomdotdistnegbinom_dist_xlfn_negbinom_dist_values(
        workbook, sheet_name, name, args, values, ctx,
      )
    "NEGBINOMDIST" => negbinomdist_values(values)
    "GAUSS" => gauss_value(values)
    "PHI" => phi_value(values)
    "CHIDIST" => chidist_values(values)
    "CHIINV" => chiinv_values(values)
    "CHISQdotDIST" | "CHISQ.DIST" | "_XLFN.CHISQ.DIST" =>
      chisqdotdistchisq_dist_xlfn_chisq_dist_values(
        workbook, sheet_name, name, args, values, ctx,
      )
    "CHISQdotDISTdotRT" | "CHISQ.DIST.RT" | "_XLFN.CHISQ.DIST.RT" =>
      chisqdotdistdotrtchisq_dist_rt_xlfn_chisq_dist_rt_values(
        workbook, sheet_name, name, args, values, ctx,
      )
    "CHISQdotINV" | "CHISQ.INV" | "_XLFN.CHISQ.INV" => chisq_inv_values(values)
    "CHISQdotINVdotRT" | "CHISQ.INV.RT" | "_XLFN.CHISQ.INV.RT" =>
      chisqdotinvdotrtchisq_inv_rt_xlfn_chisq_inv_rt_values(
        workbook, sheet_name, name, args, values, ctx,
      )
    "CHITEST" => chitest_values(workbook, sheet_name, args, values, ctx)
    "CHISQdotTEST" | "CHISQ.TEST" | "_XLFN.CHISQ.TEST" =>
      chisqdottestchisq_test_xlfn_chisq_test_values(
        workbook, sheet_name, name, args, values, ctx,
      )
    "FdotDIST" | "F.DIST" | "_XLFN.F.DIST" => fdist_values(values)
    "FDIST" => fdist_rt_values(values)
    "FdotDISTdotRT" | "F.DIST.RT" | "_XLFN.F.DIST.RT" => fdist_rt_values(values)
    "FdotINV" | "F.INV" | "_XLFN.F.INV" => finv_values(values)
    "FdotINVdotRT" | "F.INV.RT" | "_XLFN.F.INV.RT" => finv_rt_values(values)
    "FINV" => finv_rt_values(values)
    "FTEST" => ftest_values(workbook, sheet_name, args, values, ctx)
    "FdotTEST" | "F.TEST" | "_XLFN.F.TEST" =>
      fdottestf_test_xlfn_f_test_values(
        workbook, sheet_name, name, args, values, ctx,
      )
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
    _ => Error(formula_error_name)
  }
}

///|
fn eval_function_financial(
  workbook : Workbook,
  sheet_name : String,
  name : String,
  args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue {
  match name {
    "ACCRINT" => accrint_values(values, use_1904_dates=ctx.use_1904_dates)
    "ACCRINTM" => accrintm_values(values, use_1904_dates=ctx.use_1904_dates)
    "AMORDEGRC" => amordegrc_values(values, use_1904_dates=ctx.use_1904_dates)
    "AMORLINC" => amorlinc_values(values, use_1904_dates=ctx.use_1904_dates)
    "COUPDAYBS" => coupdaybs_values(values, use_1904_dates=ctx.use_1904_dates)
    "COUPDAYS" => coupdays_values(values, use_1904_dates=ctx.use_1904_dates)
    "COUPDAYSNC" => coupdaysnc_values(values, use_1904_dates=ctx.use_1904_dates)
    "COUPNCD" => coupncd_values(values, use_1904_dates=ctx.use_1904_dates)
    "COUPNUM" => coupnum_values(values, use_1904_dates=ctx.use_1904_dates)
    "COUPPCD" => couppcd_values(values, use_1904_dates=ctx.use_1904_dates)
    "CUMIPMT" => cumip_values("CUMIPMT", values)
    "CUMPRINC" => cumip_values("CUMPRINC", values)
    "DURATION" => duration_values(values, use_1904_dates=ctx.use_1904_dates)
    "DB" => db_values(values)
    "DDB" => ddb_values(values)
    "FV" => fv_values(values)
    "FVSCHEDULE" => fvschedule_values(values)
    "DISC" => disc_values(workbook, sheet_name, name, args, values, ctx)
    "INTRATE" => intrate_values(workbook, sheet_name, name, args, values, ctx)
    "IRR" => irr_values(values)
    "MDURATION" => mduration_values(values, use_1904_dates=ctx.use_1904_dates)
    "MIRR" => mirr_values(values)
    "DOLLARDE" => dollar_fraction_values("DOLLARDE", values)
    "DOLLARFR" => dollar_fraction_values("DOLLARFR", values)
    "EFFECT" => effect_values(values)
    "IPMT" => ipmt_values("IPMT", values)
    "ISPMT" => ispmt_values(values)
    "NOMINAL" => nominal_values(values)
    "NPER" => nper_values(values)
    "NPV" => npv_values(values)
    "ODDFPRICE" => oddfprice_values(values, use_1904_dates=ctx.use_1904_dates)
    "ODDFYIELD" => oddfyield_values(values, use_1904_dates=ctx.use_1904_dates)
    "ODDLPRICE" =>
      oddlprice_values(workbook, sheet_name, name, args, values, ctx)
    "ODDLYIELD" =>
      oddlyield_values(workbook, sheet_name, name, args, values, ctx)
    "PDURATION" => pduration_values(values)
    "PMT" => pmt_values(values)
    "PPMT" => ipmt_values("PPMT", values)
    "PRICE" => price_values(workbook, sheet_name, name, args, values, ctx)
    "PRICEDISC" => pricedisc_values(values, use_1904_dates=ctx.use_1904_dates)
    "PRICEMAT" => pricemat_values(values, use_1904_dates=ctx.use_1904_dates)
    "PV" => pv_values(values)
    "RATE" => rate_values(values)
    "RECEIVED" => received_values(values, use_1904_dates=ctx.use_1904_dates)
    "RRI" => rri_values(values)
    "SLN" => sln_values(values)
    "SYD" => syd_values(values)
    "TBILLEQ" => tbilleq_values(values, use_1904_dates=ctx.use_1904_dates)
    "TBILLPRICE" => tbillprice_values(values, use_1904_dates=ctx.use_1904_dates)
    "TBILLYIELD" => tbillyield_values(values, use_1904_dates=ctx.use_1904_dates)
    "XIRR" => xirr_values(values)
    "XNPV" => xnpv_values(values)
    "YIELD" => yield_values(workbook, sheet_name, name, args, values, ctx)
    "YIELDDISC" => yielddisc_values(values, use_1904_dates=ctx.use_1904_dates)
    "YIELDMAT" => yieldmat_values(values, use_1904_dates=ctx.use_1904_dates)
    "VDB" => vdb_values(values)
    _ => Error(formula_error_name)
  }
}

///|
fn eval_function_date_time(
  workbook : Workbook,
  sheet_name : String,
  name : String,
  args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue {
  match name {
    "DATE" => date_values(workbook, sheet_name, name, args, values, ctx)
    "TIME" => time_values(workbook, sheet_name, name, args, values, ctx)
    "DATEVALUE" =>
      datevalue_values(workbook, sheet_name, name, args, values, ctx)
    "TIMEVALUE" =>
      timevalue_values(workbook, sheet_name, name, args, values, ctx)
    "DATEDIF" => datedif_values(workbook, sheet_name, name, args, values, ctx)
    "DAYS" => days_values(workbook, sheet_name, name, args, values, ctx)
    "DAYS360" => days360_values(workbook, sheet_name, name, args, values, ctx)
    "ISOWEEKNUM" =>
      isoweeknum_values(workbook, sheet_name, name, args, values, ctx)
    "EDATE" => edate_values(workbook, sheet_name, name, args, values, ctx)
    "EOMONTH" => eomonth_values(workbook, sheet_name, name, args, values, ctx)
    "YEARFRAC" => yearfrac_values(workbook, sheet_name, name, args, values, ctx)
    "WEEKDAY" => weekday_values(workbook, sheet_name, name, args, values, ctx)
    "WEEKNUM" => weeknum_values(workbook, sheet_name, name, args, values, ctx)
    "NETWORKDAYS" =>
      networkdays_values(workbook, sheet_name, name, args, values, ctx)
    "NETWORKDAYS.INTL" =>
      networkdays_intl_values(workbook, sheet_name, name, args, values, ctx)
    "WORKDAY" => workday_values(workbook, sheet_name, name, args, values, ctx)
    "WORKDAY.INTL" =>
      workday_intl_values(workbook, sheet_name, name, args, values, ctx)
    "NOW" => now_values(workbook, sheet_name, name, args, values, ctx)
    "TODAY" => today_values(workbook, sheet_name, name, args, values, ctx)
    "YEAR" => year_values(workbook, sheet_name, name, args, values, ctx)
    "MONTH" => month_values(workbook, sheet_name, name, args, values, ctx)
    "DAY" => day_values(workbook, sheet_name, name, args, values, ctx)
    "HOUR" => hour_values(workbook, sheet_name, name, args, values, ctx)
    "MINUTE" => minute_values(workbook, sheet_name, name, args, values, ctx)
    "SECOND" => second_values(workbook, sheet_name, name, args, values, ctx)
    _ => Error(formula_error_name)
  }
}

///|
fn eval_function_text(
  workbook : Workbook,
  sheet_name : String,
  name : String,
  args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue raise XlsxError {
  match name {
    "DOLLAR" => dollar_values(values)
    "LEN" => len_values(workbook, sheet_name, name, args, values, ctx)
    "LENB" => lenb_values(workbook, sheet_name, name, args, values, ctx)
    "LOWER" => lower_values(workbook, sheet_name, name, args, values, ctx)
    "UPPER" => upper_values(workbook, sheet_name, name, args, values, ctx)
    "PROPER" => proper_values(workbook, sheet_name, name, args, values, ctx)
    "DBCS" => dbcs_values(workbook, sheet_name, name, args, values, ctx)
    "TRIM" => trim_values(workbook, sheet_name, name, args, values, ctx)
    "LEFT" => left_values(workbook, sheet_name, name, args, values, ctx)
    "LEFTB" => leftb_values(workbook, sheet_name, name, args, values, ctx)
    "RIGHT" => right_values(workbook, sheet_name, name, args, values, ctx)
    "RIGHTB" => rightb_values(workbook, sheet_name, name, args, values, ctx)
    "MID" => mid_values(workbook, sheet_name, name, args, values, ctx)
    "MIDB" => midb_values(workbook, sheet_name, name, args, values, ctx)
    "REPT" => rept_values(workbook, sheet_name, name, args, values, ctx)
    "REPLACE" => replace_values(workbook, sheet_name, name, args, values, ctx)
    "REPLACEB" => replaceb_values(workbook, sheet_name, name, args, values, ctx)
    "SUBSTITUTE" =>
      substitute_values(workbook, sheet_name, name, args, values, ctx)
    "FIND" => find_values(workbook, sheet_name, name, args, values, ctx)
    "FINDB" => findb_values(workbook, sheet_name, name, args, values, ctx)
    "SEARCH" => search_values(workbook, sheet_name, name, args, values, ctx)
    "SEARCHB" => searchb_values(workbook, sheet_name, name, args, values, ctx)
    "EXACT" => exact_values(workbook, sheet_name, name, args, values, ctx)
    "FIXED" => fixed_values(workbook, sheet_name, name, args, values, ctx)
    "VALUE" => value_values(workbook, sheet_name, name, args, values, ctx)
    "VALUETOTEXT" =>
      valuetotext_values(workbook, sheet_name, name, args, values, ctx)
    "TEXT" => text_values(workbook, sheet_name, name, args, values, ctx)
    "ARRAYTOTEXT" =>
      arraytotext_values(workbook, sheet_name, name, args, values, ctx)
    "TEXTAFTER" | "TEXTBEFORE" | "_XLFN.TEXTAFTER" | "_XLFN.TEXTBEFORE" =>
      textaftertextbefore_xlfn_textafter_xlfn_textbefore_values(
        workbook, sheet_name, name, args, values, ctx,
      )
    "TEXTSPLIT" | "_XLFN.TEXTSPLIT" =>
      textsplit_xlfn_textsplit_values(
        workbook, sheet_name, name, args, values, ctx,
      )
    "TEXTJOIN" => textjoin_values(workbook, sheet_name, name, args, values, ctx)
    "CHAR" => char_values(workbook, sheet_name, name, args, values, ctx)
    "UNICHAR" => unichar_values(workbook, sheet_name, name, args, values, ctx)
    "CLEAN" => clean_values(workbook, sheet_name, name, args, values, ctx)
    "ENCODEURL" =>
      encodeurl_values(workbook, sheet_name, name, args, values, ctx)
    "BAHTTEXT" =>
      bahttext_values2(workbook, sheet_name, name, args, values, ctx)
    "CODE" => code_values(workbook, sheet_name, name, args, values, ctx)
    "UNICODE" => unicode_values(workbook, sheet_name, name, args, values, ctx)
    "CONCAT" | "CONCATENATE" => concat_values(values)
    "T" => t_values(workbook, sheet_name, name, args, values, ctx)
    _ => Error(formula_error_name)
  }
}

///|
fn eval_function_lookup(
  workbook : Workbook,
  sheet_name : String,
  name : String,
  args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue raise XlsxError {
  match name {
    "TRANSPOSE" =>
      transpose_values(workbook, sheet_name, name, args, values, ctx)
    "SEQUENCE" | "_XLFN.SEQUENCE" => sequence_values(values)
    "TAKE" | "_XLFN.TAKE" =>
      take_xlfn_take_values(workbook, sheet_name, name, args, values, ctx)
    "DROP" | "_XLFN.DROP" =>
      drop_xlfn_drop_values(workbook, sheet_name, name, args, values, ctx)
    "CHOOSECOLS" | "_XLFN.CHOOSECOLS" =>
      choosecols_xlfn_choosecols_values(
        workbook, sheet_name, name, args, values, ctx,
      )
    "CHOOSEROWS" | "_XLFN.CHOOSEROWS" =>
      chooserows_xlfn_chooserows_values(
        workbook, sheet_name, name, args, values, ctx,
      )
    "HSTACK" | "_XLFN.HSTACK" =>
      hstack_xlfn_hstack_values(workbook, sheet_name, name, args, values, ctx)
    "VSTACK" | "_XLFN.VSTACK" =>
      vstack_xlfn_vstack_values(workbook, sheet_name, name, args, values, ctx)
    "EXPAND" | "_XLFN.EXPAND" =>
      expand_xlfn_expand_values(workbook, sheet_name, name, args, values, ctx)
    "WRAPROWS" | "_XLFN.WRAPROWS" =>
      wraprows_xlfn_wraprows_values(
        workbook, sheet_name, name, args, values, ctx,
      )
    "WRAPCOLS" | "_XLFN.WRAPCOLS" =>
      wrapcols_xlfn_wrapcols_values(
        workbook, sheet_name, name, args, values, ctx,
      )
    "TOCOL" | "_XLFN.TOCOL" =>
      tocol_xlfn_tocol_values(workbook, sheet_name, name, args, values, ctx)
    "TOROW" | "_XLFN.TOROW" =>
      torow_xlfn_torow_values(workbook, sheet_name, name, args, values, ctx)
    "SORT" | "_XLFN.SORT" =>
      sort_xlfn_sort_values(workbook, sheet_name, name, args, values, ctx)
    "SORTBY" | "_XLFN.SORTBY" =>
      sortby_xlfn_sortby_values(workbook, sheet_name, name, args, values, ctx)
    "FILTER" | "_XLFN.FILTER" =>
      filter_xlfn_filter_values(workbook, sheet_name, name, args, values, ctx)
    "UNIQUE" | "_XLFN.UNIQUE" =>
      unique_xlfn_unique_values(workbook, sheet_name, name, args, values, ctx)
    "INDEX" => index_values(workbook, sheet_name, name, args, values, ctx)
    "MATCH" => match_values(workbook, sheet_name, name, args, values, ctx)
    "VLOOKUP" => vlookup_values(workbook, sheet_name, name, args, values, ctx)
    "HLOOKUP" => hlookup_values(workbook, sheet_name, name, args, values, ctx)
    "LOOKUP" => lookup_values(workbook, sheet_name, name, args, values, ctx)
    "XLOOKUP" | "_XLFN.XLOOKUP" =>
      xlookup_xlfn_xlookup_values(workbook, sheet_name, name, args, values, ctx)
    "ANCHORARRAY" | "_XLFN.ANCHORARRAY" =>
      anchorarray_xlfn_anchorarray_values(
        workbook, sheet_name, name, args, values, ctx,
      )
    "ADDRESS" => address_values(workbook, sheet_name, name, args, values, ctx)
    "INDIRECT" => indirect_values(workbook, sheet_name, name, args, values, ctx)
    "HYPERLINK" =>
      hyperlink_values(workbook, sheet_name, name, args, values, ctx)
    "CHOOSE" => choose_values(workbook, sheet_name, name, args, values, ctx)
    _ => Error(formula_error_name)
  }
}

///|
fn eval_function_info(
  workbook : Workbook,
  sheet_name : String,
  name : String,
  args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue {
  match name {
    "DISPIMG" | "_XLFN.DISPIMG" =>
      dispimg_xlfn_dispimg_values(workbook, sheet_name, name, args, values, ctx)
    "ISBLANK" => isblank_values(workbook, sheet_name, name, args, values, ctx)
    "ISERR" => iserr_values(workbook, sheet_name, name, args, values, ctx)
    "ISEVEN" => iseven_values(workbook, sheet_name, name, args, values, ctx)
    "ISODD" => isodd_values(workbook, sheet_name, name, args, values, ctx)
    "ISERROR" => iserror_values(workbook, sheet_name, name, args, values, ctx)
    "ISLOGICAL" =>
      islogical_values(workbook, sheet_name, name, args, values, ctx)
    "ISNA" => isna_values(workbook, sheet_name, name, args, values, ctx)
    "ISNUMBER" => isnumber_values(workbook, sheet_name, name, args, values, ctx)
    "ISTEXT" => istext_values(workbook, sheet_name, name, args, values, ctx)
    "ISNONTEXT" =>
      isnontext_values(workbook, sheet_name, name, args, values, ctx)
    "ISREF" => isref_values(workbook, sheet_name, name, args, values, ctx)
    "ISFORMULA" =>
      isformula_values(workbook, sheet_name, name, args, values, ctx)
    "ERRORdotTYPE" | "ERROR.TYPE" =>
      errordottypeerror_type_values(
        workbook, sheet_name, name, args, values, ctx,
      )
    "SHEET" => sheet_values(workbook, sheet_name, name, args, values, ctx)
    "SHEETS" => sheets_values(workbook, sheet_name, name, args, values, ctx)
    "TYPE" => type_values(workbook, sheet_name, name, args, values, ctx)
    "NA" => na_values(workbook, sheet_name, name, args, values, ctx)
    "N" => n_values(workbook, sheet_name, name, args, values, ctx)
    _ => Error(formula_error_name)
  }
}

///|
fn eval_function_logical(
  workbook : Workbook,
  sheet_name : String,
  name : String,
  args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue {
  match name {
    "TRUE" => Bool(true)
    "FALSE" => Bool(false)
    "AND" => and_values(workbook, sheet_name, name, args, values, ctx)
    "OR" => or_values(workbook, sheet_name, name, args, values, ctx)
    "NOT" => not_values(workbook, sheet_name, name, args, values, ctx)
    "XOR" => xor_values(workbook, sheet_name, name, args, values, ctx)
    "IF" => if_values(workbook, sheet_name, name, args, values, ctx)
    "IFERROR" => iferror_values(workbook, sheet_name, name, args, values, ctx)
    "IFNA" => ifna_values(workbook, sheet_name, name, args, values, ctx)
    "IFS" => ifs_values(workbook, sheet_name, name, args, values, ctx)
    "SWITCH" => switch_values(workbook, sheet_name, name, args, values, ctx)
    _ => Error(formula_error_name)
  }
}

///|
fn sign_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
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
fn seriessum_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
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
fn sumif_values2(
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
      let sum_range = if args is [_, _, a2] {
        Some(eval_range_expr(workbook, sheet_name, a2, ctx))
      } else {
        None
      }
      sumif_values(range_values, values[1], sum_range)
    }
    _ => Error(formula_error_value)
  }
}

///|
fn sumproduct_values2(
  workbook : Workbook,
  sheet_name : String,
  _name : String,
  args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue raise XlsxError {
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
}

///|
fn sumx2my2_values(
  workbook : Workbook,
  sheet_name : String,
  _name : String,
  args : ArrayView[Expr],
  _values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue raise XlsxError {
  match args {
    [a0, a1] => {
      let left = eval_range_expr(workbook, sheet_name, a0, ctx)
      let right = eval_range_expr(workbook, sheet_name, a1, ctx)
      sumx_values("SUMX2MY2", left, right)
    }
    _ => Error(formula_error_value)
  }
}

///|
fn sumx2py2_values(
  workbook : Workbook,
  sheet_name : String,
  _name : String,
  args : ArrayView[Expr],
  _values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue raise XlsxError {
  match args {
    [a0, a1] => {
      let left = eval_range_expr(workbook, sheet_name, a0, ctx)
      let right = eval_range_expr(workbook, sheet_name, a1, ctx)
      sumx_values("SUMX2PY2", left, right)
    }
    _ => Error(formula_error_value)
  }
}

///|
fn sumxmy2_values(
  workbook : Workbook,
  sheet_name : String,
  _name : String,
  args : ArrayView[Expr],
  _values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue raise XlsxError {
  match args {
    [a0, a1] => {
      let left = eval_range_expr(workbook, sheet_name, a0, ctx)
      let right = eval_range_expr(workbook, sheet_name, a1, ctx)
      sumx_values("SUMXMY2", left, right)
    }
    _ => Error(formula_error_value)
  }
}

///|
fn sumifs_values(
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
}

///|
fn combin_values2(
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
        (Ok(num), Ok(chosen)) => combin_values(num, chosen)
        (Err(err), _) => err
        (_, Err(err)) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn combina_xlfn_combina_values(
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
fn complex_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0, v1] | [v0, v1, _] =>
      match (value_as_number(v0), value_as_number(v1)) {
        (Ok(real), Ok(imag)) => {
          let mut suffix = "i"
          if values is [_, _, v2] {
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
fn fact_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
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
fn factdouble_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
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
fn mdeterm_values(
  workbook : Workbook,
  sheet_name : String,
  _name : String,
  args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue raise XlsxError {
  match values {
    [v0] => {
      let range = range_from_expr_or_value(
        workbook,
        sheet_name,
        args[0],
        v0,
        ctx,
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
fn minverse_values(
  workbook : Workbook,
  sheet_name : String,
  _name : String,
  args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue raise XlsxError {
  match values {
    [v0] => {
      let range = range_from_expr_or_value(
        workbook,
        sheet_name,
        args[0],
        v0,
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
    }
    _ => Error(formula_error_value)
  }
}

///|
fn mmult_values(
  workbook : Workbook,
  sheet_name : String,
  _name : String,
  args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue raise XlsxError {
  match values {
    [v0, v1] =>
      match (v0, v1) {
        (Number(lhs), Number(rhs)) => Number(lhs * rhs)
        _ => {
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
fn munit_xlfn_munit_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] =>
      match munit_dimension(v0) {
        Ok(dimension) => List(munit_range_values(dimension).values)
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn abs_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] =>
      match value_as_number(v0) {
        Ok(num) => Number(abs_double(num))
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn int_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] =>
      match value_as_number(v0) {
        Ok(num) => Number(Double::floor(num))
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn ln_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] =>
      match value_as_number(v0) {
        Ok(num) => Number(@math.ln(num))
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn exp_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] =>
      match value_as_number(v0) {
        Ok(num) => Number(@math.exp(num))
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn decimal_xlfn_decimal_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
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
fn roman_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] | [v0, _] =>
      match value_as_number(v0) {
        Ok(num) => {
          let mut form = 0
          if values is [_, v1] {
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
fn arabic_xlfn_arabic_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] =>
      match value_as_string(v0) {
        Ok(text) => arabic_string_value(text)
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn bin2dec_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] =>
      match value_as_number(v0) {
        Ok(_) => bin2dec_string(formula_value_string(v0))
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn bin2hex_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] | [v0, _] =>
      match value_as_number(v0) {
        Ok(_) => {
          let decimal = bin2dec_string(formula_value_string(v0))
          match decimal {
            Error(_) => decimal
            _ => {
              let new_values : Array[FormulaValue] = [decimal]
              if values is [_, places] {
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
fn bin2oct_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] | [v0, _] =>
      match value_as_number(v0) {
        Ok(_) => {
          let decimal = bin2dec_string(formula_value_string(v0))
          match decimal {
            Error(_) => decimal
            _ => {
              let new_values : Array[FormulaValue] = [decimal]
              if values is [_, places] {
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
fn hex2bin_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] | [v0, _] =>
      match value_as_string(v0) {
        Ok(text) => {
          let decimal = hex2dec_string(text)
          match decimal {
            Error(_) => decimal
            _ => {
              let new_values : Array[FormulaValue] = [decimal]
              if values is [_, places] {
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
fn hex2dec_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] =>
      match value_as_string(v0) {
        Ok(text) => hex2dec_string(text)
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn hex2oct_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] | [v0, _] =>
      match value_as_string(v0) {
        Ok(text) => {
          let decimal = hex2dec_string(text)
          match decimal {
            Error(_) => decimal
            _ => {
              let new_values : Array[FormulaValue] = [decimal]
              if values is [_, places] {
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
fn oct2bin_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] | [v0, _] =>
      match value_as_number(v0) {
        Ok(_) => {
          let decimal = oct2dec_string(formula_value_string(v0))
          let new_values : Array[FormulaValue] = [decimal]
          if values is [_, places] {
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
fn oct2dec_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] =>
      match value_as_number(v0) {
        Ok(_) => oct2dec_string(formula_value_string(v0))
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn oct2hex_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] | [v0, _] =>
      match value_as_number(v0) {
        Ok(_) => {
          let decimal = oct2dec_string(formula_value_string(v0))
          let new_values : Array[FormulaValue] = [decimal]
          if values is [_, places] {
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
fn besseli_values(
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
        (Ok(x), Ok(n)) => number_or_num_error(bessel_i(x, n))
        (Err(err), _) => err
        (_, Err(err)) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn besselj_values(
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
        (Ok(x), Ok(n)) => number_or_num_error(bessel_j(x, n))
        (Err(err), _) => err
        (_, Err(err)) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn besselk_values(
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
fn bessely_values(
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
fn delta_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] | [v0, _] => {
      let number1 = match value_as_number(v0) {
        Ok(num) => num
        Err(err) => return err
      }
      let number2 = if values is [_, v1] {
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
fn erf_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] | [v0, _] =>
      match value_as_number(v0) {
        Ok(lower) =>
          if values is [_, v1] {
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
fn erfdotpreciseerf_precise_xlfn_erf_precise_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] =>
      match value_as_number(v0) {
        Ok(value) => number_or_num_error(erf_double(value))
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn erfc_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] =>
      match value_as_number(v0) {
        Ok(value) => number_or_num_error(erfc_double(value))
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn erfcdotpreciseerfc_precise_xlfn_erfc_precise_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] =>
      match value_as_number(v0) {
        Ok(value) => number_or_num_error(erfc_double(value))
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn gestep_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] | [v0, _] => {
      let number = match value_as_number(v0) {
        Ok(num) => num
        Err(err) => return err
      }
      let step = if values is [_, v1] {
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
fn acos_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] =>
      match value_as_number(v0) {
        Ok(num) => number_or_num_error(@math.acos(num))
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn acosh_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] =>
      match value_as_number(v0) {
        Ok(num) => number_or_num_error(@math.acosh(num))
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn acot_xlfn_acot_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] =>
      match value_as_number(v0) {
        Ok(num) => number_or_num_error(@math.PI / 2.0 - @math.atan(num))
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn acoth_xlfn_acoth_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] =>
      match value_as_number(v0) {
        Ok(num) => number_or_num_error(@math.atanh(1.0 / num))
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn asin_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] =>
      match value_as_number(v0) {
        Ok(num) => number_or_num_error(@math.asin(num))
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn asinh_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] =>
      match value_as_number(v0) {
        Ok(num) => number_or_num_error(@math.asinh(num))
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn atan_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] =>
      match value_as_number(v0) {
        Ok(num) => number_or_num_error(@math.atan(num))
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn atanh_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] =>
      match value_as_number(v0) {
        Ok(num) => number_or_num_error(@math.atanh(num))
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn atan2_values(
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
        (Ok(y), Ok(x)) => number_or_num_error(@math.atan2(x, y))
        (Err(err), _) => err
        (_, Err(err)) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn cos_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] =>
      match value_as_number(v0) {
        Ok(num) => number_or_num_error(@math.cos(num))
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn cosh_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] =>
      match value_as_number(v0) {
        Ok(num) => number_or_num_error(@math.cosh(num))
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn sin_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] =>
      match value_as_number(v0) {
        Ok(num) => number_or_num_error(@math.sin(num))
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn sinh_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] =>
      match value_as_number(v0) {
        Ok(num) => number_or_num_error(@math.sinh(num))
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn tan_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] =>
      match value_as_number(v0) {
        Ok(num) => number_or_num_error(@math.tan(num))
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn tanh_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] =>
      match value_as_number(v0) {
        Ok(num) => number_or_num_error(@math.tanh(num))
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn cot_xlfn_cot_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
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
fn coth_xlfn_coth_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
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
fn csc_xlfn_csc_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
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
fn csch_xlfn_csch_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
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
fn sec_xlfn_sec_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] =>
      match value_as_number(v0) {
        Ok(num) => number_or_num_error(@math.cos(num))
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn sech_xlfn_sech_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] =>
      match value_as_number(v0) {
        Ok(num) => number_or_num_error(1.0 / @math.cosh(num))
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn degrees_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
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
fn radians_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] =>
      match value_as_number(v0) {
        Ok(num) => Number(@math.PI / 180.0 * num)
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn rand_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [] => Number(formula_rand().double())
    _ => Error(formula_error_value)
  }
}

///|
fn randbetween_values(
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
fn pi_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [] => Number(@math.PI)
    _ => Error(formula_error_value)
  }
}

///|
fn sqrtpi_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] =>
      match value_as_number(v0) {
        Ok(num) => Number(@math.pow(num * @math.PI, 0.5))
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn log_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] | [v0, _] =>
      match value_as_number(v0) {
        Ok(num) => {
          let mut base = 10.0
          if values is [_, v1] {
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
fn log10_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] =>
      match value_as_number(v0) {
        Ok(num) => Number(@math.log10(num))
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn imabs_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
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
fn imaginary_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] =>
      match parse_complex_value(v0) {
        Ok(num) => number_or_num_error(round_significant_digits(num.imag, 15))
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn imargument_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
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
fn imconjugate_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
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
fn imcos_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] =>
      match parse_complex_value_with_suffix(v0) {
        Ok((num, suffix)) => String(complex_to_string(complex_cos(num), suffix))
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn imcosh_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
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
fn imcot_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
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
fn imcsc_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
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
fn imcsch_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
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
fn imdiv_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
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
fn imexp_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] =>
      match parse_complex_value_with_suffix(v0) {
        Ok((num, suffix)) => String(complex_to_string(complex_exp(num), suffix))
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn imln_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
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
fn imlog10_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
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
fn imlog2_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
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
fn impower_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
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
fn improduct_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
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

///|
fn imreal_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] =>
      match parse_complex_value(v0) {
        Ok(num) => String(format_number(num.real))
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn imsec_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
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
fn imsech_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
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
fn imsin_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] =>
      match parse_complex_value_with_suffix(v0) {
        Ok((num, suffix)) => String(complex_to_string(complex_sin(num), suffix))
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn imsinh_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
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
fn imsqrt_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
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
fn imsub_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
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
fn imsum_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [_, ..] => {
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
    }
    [] => Error(formula_error_value)
  }
}

///|
fn imtan_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] =>
      match parse_complex_value_with_suffix(v0) {
        Ok((num, suffix)) => String(complex_to_string(complex_tan(num), suffix))
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn floor_values(
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
fn ceiling_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] | [v0, _] =>
      match value_as_number(v0) {
        Ok(num) => {
          let mut significance = if num < 0.0 { -1.0 } else { 1.0 }
          if values is [_, v1] {
            match value_as_number(v1) {
              Ok(value) => significance = value
              Err(err) => return err
            }
          }
          if significance < 0.0 && num > 0.0 {
            Error(formula_error_value)
          } else if values is [_] {
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
fn ceilingdotmathceiling_math_xlfn_ceiling_math_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
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
          if values is [_, _, v2] {
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
fn ceilingdotpreciseceiling_precise_xlfn_ceiling_precise_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
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
fn floordotmathfloor_math_xlfn_floor_math_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
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
          if values is [_, _, v2] {
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
fn floordotprecisefloor_precise_xlfn_floor_precise_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
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
fn isodotceilingiso_ceiling_xlfn_iso_ceiling_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
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
fn trunc_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] | [v0, _] =>
      match value_as_number(v0) {
        Ok(num) => {
          let digits = if values is [_, v1] {
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
fn round_values(
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
        (Ok(num), Ok(digits)) =>
          Number(round_with_digits(num, Double::to_int(digits)))
        (Err(err), _) => err
        (_, Err(err)) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn roundup_values(
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
        (Ok(num), Ok(digits)) =>
          Number(round_up_with_digits(num, Double::to_int(digits)))
        (Err(err), _) => err
        (_, Err(err)) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn rounddown_values(
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
        (Ok(num), Ok(digits)) =>
          Number(round_down_with_digits(num, Double::to_int(digits)))
        (Err(err), _) => err
        (_, Err(err)) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn sqrt_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
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
fn power_values(
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
        (Ok(lhs), Ok(rhs)) => Number(@math.pow(lhs, rhs))
        (Err(err), _) => err
        (_, Err(err)) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn even_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
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
fn odd_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
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
fn mround_values(
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
fn mod_values(
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
fn quotient_values(
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

///|
fn stdevstdev_s_values(
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
fn stdeva_values(
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
fn stdevpstdev_p_values(
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
fn stdevpa_values(
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
fn varvar_s_values(
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
fn vara_values(
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
fn varpvar_p_values(
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
fn varpa_values(
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
fn avedev_values2(
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
fn devsq_values2(
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
fn geomean_values2(
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
fn harmean_values2(
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
fn kurt_values2(
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
fn skew_values2(
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
fn skew_p_values(
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
fn standardize_values2(
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
fn large_values(
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
fn small_values(
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
fn mode_values2(
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
fn mode_sngl_values(
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
fn mode_mult_values2(
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
fn percentile_values2(
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
fn percentile_inc_values(
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
fn percentile_exc_values(
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
fn percentrank_values2(
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
fn percentrank_inc_values(
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
fn percentrank_exc_values(
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
fn quartile_values2(
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
fn quartile_inc_values(
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
fn quartile_exc_values(
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
fn rankrank_eq_values(
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
fn correl_values2(
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
fn covar_values2(
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
fn covariance_p_values(
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
fn covariance_s_values(
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
fn pearson_values(
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
fn rsq_values(
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
fn slope_values(
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
fn intercept_values(
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
fn forecast_values(
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
fn forecast_linear_values(
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
fn growth_values(
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
fn trend_values(
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
fn fisher_values(
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
fn fisherinv_values(
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
fn steyx_values2(
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
fn countblank_values2(
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
fn countif_values2(
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
fn countifs_values(
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
fn daverage_values(
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
fn dcountdcounta_values(
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
fn dget_values2(
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
fn averageif_values2(
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
fn averageifs_values(
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
fn maxifs_values2(
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
fn minifs_values2(
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
fn permut_values(
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
fn permutationa_values(
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
fn weibulldotdistweibull_dist_xlfn_weibull_dist_values(
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
fn confidencedotnormconfidence_norm_xlfn_confidence_norm_values(
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
fn confidencedottconfidence_t_xlfn_confidence_t_values(
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
fn normdotsdotdistnorm_s_dist_xlfn_norm_s_dist_values(
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
fn normdotsdotinvnorm_s_inv_xlfn_norm_s_inv_values(
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
fn lognormdotdistlognorm_dist_xlfn_lognorm_dist_values(
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
fn lognormdotinvlognorm_inv_xlfn_lognorm_inv_values(
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
fn gammadotdistgamma_dist_xlfn_gamma_dist_values(
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
fn gammalndotprecisegammaln_precise_xlfn_gammaln_precise_values(
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
fn expondotdistexpon_dist_xlfn_expon_dist_values(
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
fn poissondotdistpoisson_dist_xlfn_poisson_dist_values(
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
fn binomdotdistbinom_dist_xlfn_binom_dist_values(
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
fn binomdotdistdotrangebinom_dist_range_xlfn_binom_dist_range_values(
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
fn hypgeomdotdisthypgeom_dist_xlfn_hypgeom_dist_values(
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
fn negbinomdotdistnegbinom_dist_xlfn_negbinom_dist_values(
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
fn chisqdotdistchisq_dist_xlfn_chisq_dist_values(
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
fn chisqdotdistdotrtchisq_dist_rt_xlfn_chisq_dist_rt_values(
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
fn chisqdotinvdotrtchisq_inv_rt_xlfn_chisq_inv_rt_values(
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
fn chisqdottestchisq_test_xlfn_chisq_test_values(
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
fn fdottestf_test_xlfn_f_test_values(
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
fn disc_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue {
  disc_intrate_values("DISC", values, use_1904_dates=ctx.use_1904_dates)
}

///|
fn intrate_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue {
  disc_intrate_values("INTRATE", values, use_1904_dates=ctx.use_1904_dates)
}

///|
fn oddlprice_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue {
  oddl_values("ODDLPRICE", values, use_1904_dates=ctx.use_1904_dates)
}

///|
fn oddlyield_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue {
  oddl_values("ODDLYIELD", values, use_1904_dates=ctx.use_1904_dates)
}

///|
fn price_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue {
  price_yield_values("PRICE", values, use_1904_dates=ctx.use_1904_dates)
}

///|
fn yield_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue {
  price_yield_values("YIELD", values, use_1904_dates=ctx.use_1904_dates)
}

///|
fn date_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0, v1, v2] =>
      match (value_as_int(v0), value_as_int(v1), value_as_int(v2)) {
        (Ok(year), Ok(month), Ok(day)) =>
          match
            excel_serial_from_date(
              year,
              month,
              day,
              use_1904_dates=ctx.use_1904_dates,
            ) {
            Some(serial) => Number(serial)
            None => Error(formula_error_num)
          }
        (Err(err), _, _) => err
        (_, Err(err), _) => err
        (_, _, Err(err)) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn time_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0, v1, v2] =>
      match (value_as_int(v0), value_as_int(v1), value_as_int(v2)) {
        (Ok(hours), Ok(minutes), Ok(seconds)) =>
          match excel_time_fraction(hours, minutes, seconds) {
            Some(value) => Number(value)
            None => Error(formula_error_num)
          }
        (Err(err), _, _) => err
        (_, Err(err), _) => err
        (_, _, Err(err)) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn datevalue_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] => {
      let text = match value_as_string(v0) {
        Ok(value) => value
        Err(err) => return err
      }
      match parse_date_parts(text) {
        Some((year, month, day)) =>
          match
            excel_serial_from_date(
              year,
              month,
              day,
              use_1904_dates=ctx.use_1904_dates,
            ) {
            Some(serial) => Number(serial)
            None => Error(formula_error_value)
          }
        None => Error(formula_error_value)
      }
    }
    _ => Error(formula_error_value)
  }
}

///|
fn timevalue_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] => {
      let text = match value_as_string(v0) {
        Ok(value) => value
        Err(err) => return err
      }
      match parse_time_parts(text) {
        Some((hours, minutes, seconds)) =>
          // parse_time_parts only yields non-negative components.
          Number(excel_time_fraction(hours, minutes, seconds).unwrap())
        None => Error(formula_error_value)
      }
    }
    _ => Error(formula_error_value)
  }
}

///|
fn datedif_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0, v1, v2] => {
      let start_serial = match
        value_as_date_serial(v0, use_1904_dates=ctx.use_1904_dates) {
        Ok(value) => value
        Err(err) => return err
      }
      let end_serial = match
        value_as_date_serial(v1, use_1904_dates=ctx.use_1904_dates) {
        Ok(value) => value
        Err(err) => return err
      }
      if start_serial > end_serial {
        Error(formula_error_num)
      } else if start_serial == end_serial {
        Number(0.0)
      } else {
        let unit = match value_as_string(v2) {
          Ok(text) => text.to_lower()
          Err(err) => return err
        }
        let (sy, sm, sd) = match
          date_parts_from_serial(
            start_serial,
            use_1904_dates=ctx.use_1904_dates,
          ) {
          Some(parts) => parts
          None => return Error(formula_error_num)
        }
        let (ey, em, ed) = match
          date_parts_from_serial(end_serial, use_1904_dates=ctx.use_1904_dates) {
          Some(parts) => parts
          None => return Error(formula_error_num)
        }
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
            let start_base = excel_serial_from_date(
              sy,
              sm,
              sd,
              use_1904_dates=ctx.use_1904_dates,
            ).unwrap()
            let end_base = excel_serial_from_date(
              target_year,
              em,
              ed,
              use_1904_dates=ctx.use_1904_dates,
            ).unwrap()
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
    }
    _ => Error(formula_error_value)
  }
}

///|
fn days_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0, v1] => {
      let end_serial = match
        value_as_date_serial(v0, use_1904_dates=ctx.use_1904_dates) {
        Ok(value) => value
        Err(err) => return err
      }
      let start_serial = match
        value_as_date_serial(v1, use_1904_dates=ctx.use_1904_dates) {
        Ok(value) => value
        Err(err) => return err
      }
      Number(end_serial - start_serial)
    }
    _ => Error(formula_error_value)
  }
}

///|
fn days360_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0, v1] | [v0, v1, _] => {
      let start_serial = match
        value_as_date_serial(v0, use_1904_dates=ctx.use_1904_dates) {
        Ok(value) => value
        Err(err) => return err
      }
      let end_serial = match
        value_as_date_serial(v1, use_1904_dates=ctx.use_1904_dates) {
        Ok(value) => value
        Err(err) => return err
      }
      let (sy, sm, sd) = match
        date_parts_from_serial(start_serial, use_1904_dates=ctx.use_1904_dates) {
        Some(parts) => parts
        None => return Error(formula_error_num)
      }
      let (ey, em, ed) = match
        date_parts_from_serial(end_serial, use_1904_dates=ctx.use_1904_dates) {
        Some(parts) => parts
        None => return Error(formula_error_num)
      }
      let mut start_day = sd
      let mut end_day = ed
      let end_year = ey
      let mut end_month = em
      let use_european = if values is [_, _, v2] {
        match value_as_bool(v2) {
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
    }
    _ => Error(formula_error_value)
  }
}

///|
fn isoweeknum_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] => {
      let serial = match
        value_as_date_serial(v0, use_1904_dates=ctx.use_1904_dates) {
        Ok(value) => value
        Err(err) => return err
      }
      // Serial zero is the 1900 system's artificial day before its epoch,
      // but is the real 1904-01-01 epoch in a date-1904 workbook.
      if !ctx.use_1904_dates && serial < 1.0 {
        return Error(formula_error_num)
      }
      // Excel assigns the fictitious 1900-02-29 (including its time
      // fraction) to ISO week 9. It cannot pass through the Gregorian helper
      // below because 1900 was not actually a leap year.
      if is_1900_phantom_date_serial(serial, ctx.use_1904_dates) {
        return Number(9.0)
      }
      let (year, month, day) = match
        date_parts_from_serial(serial, use_1904_dates=ctx.use_1904_dates) {
        Some(parts) => parts
        None => return Error(formula_error_num)
      }
      match iso_week_number(year, month, day) {
        Some(week) => Number(Double::from_int(week))
        None => Error(formula_error_num)
      }
    }
    _ => Error(formula_error_value)
  }
}

///|
fn edate_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0, v1] => {
      let (year, month, day) = match
        date_parts_from_value(v0, use_1904_dates=ctx.use_1904_dates) {
        Ok(parts) => parts
        Err(err) => return err
      }
      let months = match value_as_number(v1) {
        Ok(num) => Double::to_int(trunc_double(num))
        Err(err) => return err
      }
      let (new_year, new_month) = normalize_year_month(year, month + months)
      let max_day = days_in_month(new_year, new_month)
      let new_day = if day > max_day { max_day } else { day }
      match
        excel_serial_from_date(
          new_year,
          new_month,
          new_day,
          use_1904_dates=ctx.use_1904_dates,
        ) {
        Some(serial) => Number(serial)
        None => Error(formula_error_num)
      }
    }
    _ => Error(formula_error_value)
  }
}

///|
fn eomonth_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0, v1] => {
      let (year, month, _) = match
        date_parts_from_value(v0, use_1904_dates=ctx.use_1904_dates) {
        Ok(parts) => parts
        Err(err) => return err
      }
      let months = match value_as_number(v1) {
        Ok(num) => Double::to_int(trunc_double(num))
        Err(err) => return err
      }
      let (new_year, new_month) = normalize_year_month(year, month + months)
      let new_day = days_in_month(new_year, new_month)
      match
        excel_serial_from_date(
          new_year,
          new_month,
          new_day,
          use_1904_dates=ctx.use_1904_dates,
        ) {
        Some(serial) => Number(serial)
        None => Error(formula_error_num)
      }
    }
    _ => Error(formula_error_value)
  }
}

///|
fn yearfrac_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0, v1] | [v0, v1, _] => {
      let start_serial = match
        value_as_date_serial(v0, use_1904_dates=ctx.use_1904_dates) {
        Ok(value) => value
        Err(err) => return err
      }
      let end_serial = match
        value_as_date_serial(v1, use_1904_dates=ctx.use_1904_dates) {
        Ok(value) => value
        Err(err) => return err
      }
      let basis = if values is [_, _, v2] {
        match value_as_number(v2) {
          Ok(num) => Double::to_int(trunc_double(num))
          Err(err) => return err
        }
      } else {
        0
      }
      yearfrac_value(
        start_serial,
        end_serial,
        basis,
        use_1904_dates=ctx.use_1904_dates,
      )
    }
    _ => Error(formula_error_value)
  }
}

///|
fn weekday_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] | [v0, _] => {
      let (year, month, day) = match
        date_parts_from_value(v0, use_1904_dates=ctx.use_1904_dates) {
        Ok(parts) => parts
        Err(err) => return err
      }
      let mut return_type = 1
      if values is [_, v1] {
        return_type = match value_as_number(v1) {
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
    }
    _ => Error(formula_error_value)
  }
}

///|
fn weeknum_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] | [v0, _] => {
      let (year, month, day) = match
        date_parts_from_value(v0, use_1904_dates=ctx.use_1904_dates) {
        Ok(parts) => parts
        Err(err) => return err
      }
      let mut return_type = 1
      if values is [_, v1] {
        return_type = match value_as_number(v1) {
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
    }
    _ => Error(formula_error_value)
  }
}

///|
fn networkdays_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0, v1] | [v0, v1, _] => {
      let start_serial = match
        value_as_date_serial(v0, use_1904_dates=ctx.use_1904_dates) {
        Ok(value) => value
        Err(err) => return err
      }
      let end_serial = match
        value_as_date_serial(v1, use_1904_dates=ctx.use_1904_dates) {
        Ok(value) => value
        Err(err) => return err
      }
      let holidays = if values is [_, _, v2] {
        collect_holidays(v2, use_1904_dates=ctx.use_1904_dates)
      } else {
        []
      }
      networkdays_intl_value(
        start_serial,
        end_serial,
        Number(1.0),
        holidays,
        use_1904_dates=ctx.use_1904_dates,
      )
    }
    _ => Error(formula_error_value)
  }
}

///|
fn networkdays_intl_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue {
  if values.length() >= 2 && values.length() <= 4 {
    let start_serial = match
      value_as_date_serial(values[0], use_1904_dates=ctx.use_1904_dates) {
      Ok(value) => value
      Err(err) => return err
    }
    let end_serial = match
      value_as_date_serial(values[1], use_1904_dates=ctx.use_1904_dates) {
      Ok(value) => value
      Err(err) => return err
    }
    let weekend_value = if values.length() >= 3 {
      values[2]
    } else {
      Number(1.0)
    }
    let holidays = if values.length() == 4 {
      collect_holidays(values[3], use_1904_dates=ctx.use_1904_dates)
    } else {
      []
    }
    networkdays_intl_value(
      start_serial,
      end_serial,
      weekend_value,
      holidays,
      use_1904_dates=ctx.use_1904_dates,
    )
  } else {
    Error(formula_error_value)
  }
}

///|
fn workday_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0, v1] | [v0, v1, _] => {
      let start_serial = match
        value_as_date_serial(v0, use_1904_dates=ctx.use_1904_dates) {
        Ok(value) => value
        Err(err) => return err
      }
      let days = match value_as_number(v1) {
        Ok(num) => num
        Err(err) => return err
      }
      let holidays = if values is [_, _, v2] {
        collect_holidays(v2, use_1904_dates=ctx.use_1904_dates)
      } else {
        []
      }
      workday_intl_value(
        start_serial,
        days,
        Number(1.0),
        holidays,
        use_1904_dates=ctx.use_1904_dates,
      )
    }
    _ => Error(formula_error_value)
  }
}

///|
fn workday_intl_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue {
  if values.length() >= 2 && values.length() <= 4 {
    let start_serial = match
      value_as_date_serial(values[0], use_1904_dates=ctx.use_1904_dates) {
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
      collect_holidays(values[3], use_1904_dates=ctx.use_1904_dates)
    } else {
      []
    }
    workday_intl_value(
      start_serial,
      days,
      weekend_value,
      holidays,
      use_1904_dates=ctx.use_1904_dates,
    )
  } else {
    Error(formula_error_value)
  }
}

///|
fn now_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue {
  match values {
    [] => {
      let now_ms = @env.now()
      let total_seconds = UInt64::to_double(now_ms) / 1000.0
      let days = Double::floor(total_seconds / 86400.0)
      let seconds_in_day = total_seconds - days * 86400.0
      let epoch_serial = if ctx.use_1904_dates { 24107.0 } else { 25569.0 }
      let serial = days + epoch_serial + seconds_in_day / 86400.0
      Number(serial)
    }
    _ => Error(formula_error_value)
  }
}

///|
fn today_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue {
  match values {
    [] => {
      let now_ms = @env.now()
      let total_seconds = UInt64::to_double(now_ms) / 1000.0
      let days = Double::floor(total_seconds / 86400.0)
      let epoch_serial = if ctx.use_1904_dates { 24107.0 } else { 25569.0 }
      Number(days + epoch_serial)
    }
    _ => Error(formula_error_value)
  }
}

///|
fn year_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] =>
      match excel_serial_date_parts(v0, use_1904_dates=ctx.use_1904_dates) {
        Ok((year, _, _)) => Number(Double::from_int(year))
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn month_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] =>
      match excel_serial_date_parts(v0, use_1904_dates=ctx.use_1904_dates) {
        Ok((_, month, _)) => Number(Double::from_int(month))
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn day_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] =>
      match excel_serial_date_parts(v0, use_1904_dates=ctx.use_1904_dates) {
        Ok((_, _, day)) => Number(Double::from_int(day))
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn hour_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] =>
      match excel_serial_parts(v0, use_1904_dates=ctx.use_1904_dates) {
        Ok((_, _, _, hour, _, _)) => Number(Double::from_int(hour))
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn minute_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] =>
      match excel_serial_parts(v0, use_1904_dates=ctx.use_1904_dates) {
        Ok((_, _, _, _, minute, _)) => Number(Double::from_int(minute))
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn second_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] =>
      match excel_serial_parts(v0, use_1904_dates=ctx.use_1904_dates) {
        Ok((_, _, _, _, _, second)) => Number(Double::from_int(second))
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn len_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] =>
      match value_as_string(v0) {
        Ok(text) => Number(Double::from_int(text.length()))
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn lenb_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] =>
      match value_as_string(v0) {
        Ok(text) => Number(Double::from_int(dbcs_byte_length(text)))
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn lower_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] =>
      match value_as_string(v0) {
        Ok(text) => String(text.to_lower())
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn upper_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] =>
      match value_as_string(v0) {
        Ok(text) => String(text.to_upper())
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn proper_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] =>
      match value_as_string(v0) {
        Ok(text) => String(proper_case(text))
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn dbcs_values(
  workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] =>
      match value_as_string(v0) {
        Ok(text) =>
          if dbcs_enabled(workbook) {
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
fn trim_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] =>
      match value_as_string(v0) {
        Ok(text) => String(trim_excel_text(text))
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn left_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] | [v0, _] => {
      let text = match value_as_string(v0) {
        Ok(text) => text
        Err(err) => return err
      }
      let count = if values is [_, v1] {
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
fn leftb_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] | [v0, _] => {
      let text = match value_as_string(v0) {
        Ok(text) => text
        Err(err) => return err
      }
      let count = if values is [_, v1] {
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
fn right_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] | [v0, _] => {
      let text = match value_as_string(v0) {
        Ok(text) => text
        Err(err) => return err
      }
      let count = if values is [_, v1] {
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
fn rightb_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] | [v0, _] => {
      let text = match value_as_string(v0) {
        Ok(text) => text
        Err(err) => return err
      }
      let count = if values is [_, v1] {
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
fn mid_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
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
fn midb_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
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
fn rept_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
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
fn replace_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
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
fn replaceb_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
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
fn substitute_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
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
      } else if values is [_, _, _, v3] {
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
fn find_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0, v1] | [v0, v1, _] => {
      let find_text = match value_as_string(v0) {
        Ok(text) => text
        Err(err) => return err
      }
      let within_text = match value_as_string(v1) {
        Ok(text) => text
        Err(err) => return err
      }
      let start_num = if values is [_, _, v2] {
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
fn findb_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0, v1] | [v0, v1, _] => {
      let find_text = match value_as_string(v0) {
        Ok(text) => text
        Err(err) => return err
      }
      let within_text = match value_as_string(v1) {
        Ok(text) => text
        Err(err) => return err
      }
      let start_num = if values is [_, _, v2] {
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
fn search_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0, v1] | [v0, v1, _] => {
      let find_text = match value_as_string(v0) {
        Ok(text) => text
        Err(err) => return err
      }
      let within_text = match value_as_string(v1) {
        Ok(text) => text
        Err(err) => return err
      }
      let start_num = if values is [_, _, v2] {
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
fn searchb_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0, v1] | [v0, v1, _] => {
      let find_text = match value_as_string(v0) {
        Ok(text) => text
        Err(err) => return err
      }
      let within_text = match value_as_string(v1) {
        Ok(text) => text
        Err(err) => return err
      }
      let start_num = if values is [_, _, v2] {
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
fn exact_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
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
fn fixed_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
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
}

///|
fn value_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] =>
      match value_as_number_text(v0) {
        Ok(num) => Number(num)
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn valuetotext_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] | [v0, _] => {
      let format = if values is [_, v1] {
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
fn text_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue {
  match values {
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
            use_1904_format=ctx.use_1904_dates,
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
fn arraytotext_values(
  workbook : Workbook,
  sheet_name : String,
  _name : String,
  args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue raise XlsxError {
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
      _ => { rows: 1, cols: 1, values: [values[0]], }
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
fn textaftertextbefore_xlfn_textafter_xlfn_textbefore_values(
  _workbook : Workbook,
  _sheet_name : String,
  name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
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
}

///|
fn textsplit_xlfn_textsplit_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  if values.length() >= 2 && values.length() <= 6 {
    textsplit_values(values)
  } else {
    Error(formula_error_value)
  }
}

///|
fn textjoin_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
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
}

///|
fn char_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
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
fn unichar_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
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
fn clean_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] => clean_text_value(v0)
    _ => Error(formula_error_value)
  }
}

///|
fn encodeurl_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] => encode_url_value(v0)
    _ => Error(formula_error_value)
  }
}

///|
fn bahttext_values2(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [_] => bahttext_values(values)
    _ => Error(formula_error_value)
  }
}

///|
fn code_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] => code_value("CODE", v0)
    _ => Error(formula_error_value)
  }
}

///|
fn unicode_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] => code_value("UNICODE", v0)
    _ => Error(formula_error_value)
  }
}

///|
fn t_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
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

///|
fn transpose_values(
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
fn take_xlfn_take_values(
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
fn drop_xlfn_drop_values(
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
fn choosecols_xlfn_choosecols_values(
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
fn chooserows_xlfn_chooserows_values(
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
fn hstack_xlfn_hstack_values(
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
fn vstack_xlfn_vstack_values(
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
fn expand_xlfn_expand_values(
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
fn wraprows_xlfn_wraprows_values(
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
fn wrapcols_xlfn_wrapcols_values(
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
fn tocol_xlfn_tocol_values(
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
fn torow_xlfn_torow_values(
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
fn sort_xlfn_sort_values(
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
fn sortby_xlfn_sortby_values(
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
fn filter_xlfn_filter_values(
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
fn unique_xlfn_unique_values(
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
fn index_values(
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
fn match_values(
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
fn vlookup_values(
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
fn hlookup_values(
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
fn lookup_values(
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
fn xlookup_xlfn_xlookup_values(
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
fn anchorarray_xlfn_anchorarray_values(
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
fn address_values(
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
fn indirect_values(
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
fn hyperlink_values(
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
fn choose_values(
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

///|
fn dispimg_xlfn_dispimg_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0, _] => v0
    _ => Error(formula_error_value)
  }
}

///|
fn isblank_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] =>
      match normalize_scalar(v0) {
        Empty => Bool(true)
        _ => Bool(false)
      }
    _ => Error(formula_error_value)
  }
}

///|
fn iserr_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] =>
      match normalize_scalar(v0) {
        Error(err) => Bool(is_known_error_code(err) && err != formula_error_na)
        _ => Bool(false)
      }
    _ => Error(formula_error_value)
  }
}

///|
fn iseven_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] =>
      match normalize_scalar(v0) {
        Empty => Bool(true)
        _ =>
          match value_as_number(v0) {
            Ok(num) => {
              let even = if num == 1.0 { false } else { num == num / 2.0 * 2.0 }
              Bool(even)
            }
            Err(err) => err
          }
      }
    _ => Error(formula_error_value)
  }
}

///|
fn isodd_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] =>
      match value_as_number(v0) {
        Ok(num) => {
          let n = Double::to_int(num)
          Bool(n != n / 2 * 2)
        }
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn iserror_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] =>
      match normalize_scalar(v0) {
        Error(err) => Bool(is_known_error_code(err))
        _ => Bool(false)
      }
    _ => Error(formula_error_value)
  }
}

///|
fn islogical_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] =>
      match normalize_scalar(v0) {
        Bool(_) => Bool(true)
        String(text) => Bool(text == "TRUE" || text == "FALSE")
        _ => Bool(false)
      }
    _ => Error(formula_error_value)
  }
}

///|
fn isna_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] =>
      match normalize_scalar(v0) {
        Error(err) => Bool(err == formula_error_na)
        _ => Bool(false)
      }
    _ => Error(formula_error_value)
  }
}

///|
fn isnumber_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] =>
      match normalize_scalar(v0) {
        Number(_) => Bool(true)
        _ => Bool(false)
      }
    _ => Error(formula_error_value)
  }
}

///|
fn istext_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] =>
      match normalize_scalar(v0) {
        String(text) =>
          match parse_double_opt(text) {
            Some(_) => Bool(false)
            None => Bool(true)
          }
        _ => Bool(false)
      }
    _ => Error(formula_error_value)
  }
}

///|
fn isnontext_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] =>
      match normalize_scalar(v0) {
        String(_) => Bool(false)
        _ => Bool(true)
      }
    _ => Error(formula_error_value)
  }
}

///|
fn isref_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  args : ArrayView[Expr],
  _values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match args {
    [a0] => Bool(is_ref_expr(a0))
    _ => Error(formula_error_value)
  }
}

///|
fn isformula_values(
  workbook : Workbook,
  sheet_name : String,
  _name : String,
  args : ArrayView[Expr],
  _values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match args {
    [a0] =>
      match a0 {
        Cell(sheet, reference) => {
          let target_sheet = if sheet == "" { sheet_name } else { sheet }
          Bool(cell_has_formula(workbook, target_sheet, reference))
        }
        _ => Bool(false)
      }
    _ => Error(formula_error_value)
  }
}

///|
fn errordottypeerror_type_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] => error_type_value(v0)
    _ => Error(formula_error_value)
  }
}

///|
fn sheet_values(
  workbook : Workbook,
  sheet_name : String,
  _name : String,
  args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match args {
    [] =>
      match sheet_index_opt(workbook, sheet_name) {
        Some(index) => Number(Double::from_int(index + 1))
        None => Error(formula_error_na)
      }
    [arg] => {
      let target_sheet = match arg {
        Cell(sheet, _) => if sheet == "" { sheet_name } else { sheet }
        Range(sheet, _, _) => if sheet == "" { sheet_name } else { sheet }
        _ => formula_value_string(values[0])
      }
      match sheet_index_opt(workbook, target_sheet) {
        Some(index) => Number(Double::from_int(index + 1))
        None => Error(formula_error_na)
      }
    }
    _ => Error(formula_error_value)
  }
}

///|
fn sheets_values(
  workbook : Workbook,
  _sheet_name : String,
  _name : String,
  args : ArrayView[Expr],
  _values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match args {
    [] => Number(Double::from_int(workbook.sheets().length()))
    [arg] =>
      match arg {
        Cell(_, _) | Range(_, _, _) => Number(1.0)
        _ => Error(formula_error_na)
      }
    _ => Error(formula_error_value)
  }
}

///|
fn type_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] => type_value(v0)
    _ => Error(formula_error_value)
  }
}

///|
fn na_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [] => Error(formula_error_na)
    _ => Error(formula_error_value)
  }
}

///|
fn n_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0] =>
      match normalize_scalar(v0) {
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
    _ => Error(formula_error_value)
  }
}

///|
fn and_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
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
}

///|
fn or_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
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
}

///|
fn not_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
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
fn xor_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
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
}

///|
fn if_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
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
fn iferror_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
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
fn ifna_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  match values {
    [v0, v1] =>
      match normalize_scalar(v0) {
        Error(err) => if err == formula_error_na { v1 } else { v0 }
        _ => v0
      }
    _ => Error(formula_error_value)
  }
}

///|
fn ifs_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
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
}

///|
fn switch_values(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
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
