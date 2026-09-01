///|
// Per-formula handlers for the financial family. Each maps one (or a few aliases of)
// one Excel formula to its implementation; eval_function routes to these via a HashMap.

///|
fn eval_accrint(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue {
  accrint_values(values, use_1904_dates=ctx.use_1904_dates)
}

///|
fn eval_accrintm(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue {
  accrintm_values(values, use_1904_dates=ctx.use_1904_dates)
}

///|
fn eval_amordegrc(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue {
  amordegrc_values(values, use_1904_dates=ctx.use_1904_dates)
}

///|
fn eval_amorlinc(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue {
  amorlinc_values(values, use_1904_dates=ctx.use_1904_dates)
}

///|
fn eval_coupdaybs(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue {
  coupdaybs_values(values, use_1904_dates=ctx.use_1904_dates)
}

///|
fn eval_coupdays(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue {
  coupdays_values(values, use_1904_dates=ctx.use_1904_dates)
}

///|
fn eval_coupdaysnc(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue {
  coupdaysnc_values(values, use_1904_dates=ctx.use_1904_dates)
}

///|
fn eval_coupncd(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue {
  coupncd_values(values, use_1904_dates=ctx.use_1904_dates)
}

///|
fn eval_coupnum(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue {
  coupnum_values(values, use_1904_dates=ctx.use_1904_dates)
}

///|
fn eval_couppcd(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue {
  couppcd_values(values, use_1904_dates=ctx.use_1904_dates)
}

///|
fn eval_cumipmt(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  cumip_values("CUMIPMT", values)
}

///|
fn eval_cumprinc(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  cumip_values("CUMPRINC", values)
}

///|
fn eval_duration(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue {
  duration_values(values, use_1904_dates=ctx.use_1904_dates)
}

///|
fn eval_db(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  db_values(values)
}

///|
fn eval_ddb(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  ddb_values(values)
}

///|
fn eval_fv(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  fv_values(values)
}

///|
fn eval_fvschedule(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  fvschedule_values(values)
}

///|
fn eval_disc(
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
fn eval_intrate(
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
fn eval_irr(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  irr_values(values)
}

///|
fn eval_mduration(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue {
  mduration_values(values, use_1904_dates=ctx.use_1904_dates)
}

///|
fn eval_mirr(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  mirr_values(values)
}

///|
fn eval_dollarde(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  dollar_fraction_values("DOLLARDE", values)
}

///|
fn eval_dollarfr(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  dollar_fraction_values("DOLLARFR", values)
}

///|
fn eval_effect(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  effect_values(values)
}

///|
fn eval_ipmt(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  ipmt_values("IPMT", values)
}

///|
fn eval_ispmt(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  ispmt_values(values)
}

///|
fn eval_nominal(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  nominal_values(values)
}

///|
fn eval_nper(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  nper_values(values)
}

///|
fn eval_npv(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  npv_values(values)
}

///|
fn eval_oddfprice(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue {
  oddfprice_values(values, use_1904_dates=ctx.use_1904_dates)
}

///|
fn eval_oddfyield(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue {
  oddfyield_values(values, use_1904_dates=ctx.use_1904_dates)
}

///|
fn eval_oddlprice(
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
fn eval_oddlyield(
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
fn eval_pduration(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  pduration_values(values)
}

///|
fn eval_pmt(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  pmt_values(values)
}

///|
fn eval_ppmt(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  ipmt_values("PPMT", values)
}

///|
fn eval_price(
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
fn eval_pricedisc(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue {
  pricedisc_values(values, use_1904_dates=ctx.use_1904_dates)
}

///|
fn eval_pricemat(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue {
  pricemat_values(values, use_1904_dates=ctx.use_1904_dates)
}

///|
fn eval_pv(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  pv_values(values)
}

///|
fn eval_rate(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  rate_values(values)
}

///|
fn eval_received(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue {
  received_values(values, use_1904_dates=ctx.use_1904_dates)
}

///|
fn eval_rri(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  rri_values(values)
}

///|
fn eval_sln(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  sln_values(values)
}

///|
fn eval_syd(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  syd_values(values)
}

///|
fn eval_tbilleq(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue {
  tbilleq_values(values, use_1904_dates=ctx.use_1904_dates)
}

///|
fn eval_tbillprice(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue {
  tbillprice_values(values, use_1904_dates=ctx.use_1904_dates)
}

///|
fn eval_tbillyield(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue {
  tbillyield_values(values, use_1904_dates=ctx.use_1904_dates)
}

///|
fn eval_xirr(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  xirr_values(values)
}

///|
fn eval_xnpv(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  xnpv_values(values)
}

///|
fn eval_yield(
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
fn eval_yielddisc(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue {
  yielddisc_values(values, use_1904_dates=ctx.use_1904_dates)
}

///|
fn eval_yieldmat(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue {
  yieldmat_values(values, use_1904_dates=ctx.use_1904_dates)
}

///|
fn eval_vdb(
  _workbook : Workbook,
  _sheet_name : String,
  _name : String,
  _args : ArrayView[Expr],
  values : Array[FormulaValue],
  _ctx : CalcContext,
) -> FormulaValue {
  vdb_values(values)
}
