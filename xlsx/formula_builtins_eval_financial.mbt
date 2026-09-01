///|
// Per-formula handlers for the financial family. Each maps one (or a few aliases of)
// one Excel formula to its implementation; eval_function routes to these via a HashMap.

///|
fn eval_accrint(call : EvalCall) -> FormulaValue {
  accrint_values(call.values, use_1904_dates=call.ctx.use_1904_dates)
}

///|
fn eval_accrintm(call : EvalCall) -> FormulaValue {
  accrintm_values(call.values, use_1904_dates=call.ctx.use_1904_dates)
}

///|
fn eval_amordegrc(call : EvalCall) -> FormulaValue {
  amordegrc_values(call.values, use_1904_dates=call.ctx.use_1904_dates)
}

///|
fn eval_amorlinc(call : EvalCall) -> FormulaValue {
  amorlinc_values(call.values, use_1904_dates=call.ctx.use_1904_dates)
}

///|
fn eval_coupdaybs(call : EvalCall) -> FormulaValue {
  coupdaybs_values(call.values, use_1904_dates=call.ctx.use_1904_dates)
}

///|
fn eval_coupdays(call : EvalCall) -> FormulaValue {
  coupdays_values(call.values, use_1904_dates=call.ctx.use_1904_dates)
}

///|
fn eval_coupdaysnc(call : EvalCall) -> FormulaValue {
  coupdaysnc_values(call.values, use_1904_dates=call.ctx.use_1904_dates)
}

///|
fn eval_coupncd(call : EvalCall) -> FormulaValue {
  coupncd_values(call.values, use_1904_dates=call.ctx.use_1904_dates)
}

///|
fn eval_coupnum(call : EvalCall) -> FormulaValue {
  coupnum_values(call.values, use_1904_dates=call.ctx.use_1904_dates)
}

///|
fn eval_couppcd(call : EvalCall) -> FormulaValue {
  couppcd_values(call.values, use_1904_dates=call.ctx.use_1904_dates)
}

///|
fn eval_cumipmt(call : EvalCall) -> FormulaValue {
  cumip_values("CUMIPMT", call.values)
}

///|
fn eval_cumprinc(call : EvalCall) -> FormulaValue {
  cumip_values("CUMPRINC", call.values)
}

///|
fn eval_duration(call : EvalCall) -> FormulaValue {
  duration_values(call.values, use_1904_dates=call.ctx.use_1904_dates)
}

///|
fn eval_db(call : EvalCall) -> FormulaValue {
  db_values(call.values)
}

///|
fn eval_ddb(call : EvalCall) -> FormulaValue {
  ddb_values(call.values)
}

///|
fn eval_fv(call : EvalCall) -> FormulaValue {
  fv_values(call.values)
}

///|
fn eval_fvschedule(call : EvalCall) -> FormulaValue {
  fvschedule_values(call.values)
}

///|
fn eval_disc(call : EvalCall) -> FormulaValue {
  disc_intrate_values(
    "DISC",
    call.values,
    use_1904_dates=call.ctx.use_1904_dates,
  )
}

///|
fn eval_intrate(call : EvalCall) -> FormulaValue {
  disc_intrate_values(
    "INTRATE",
    call.values,
    use_1904_dates=call.ctx.use_1904_dates,
  )
}

///|
fn eval_irr(call : EvalCall) -> FormulaValue {
  irr_values(call.values)
}

///|
fn eval_mduration(call : EvalCall) -> FormulaValue {
  mduration_values(call.values, use_1904_dates=call.ctx.use_1904_dates)
}

///|
fn eval_mirr(call : EvalCall) -> FormulaValue {
  mirr_values(call.values)
}

///|
fn eval_dollarde(call : EvalCall) -> FormulaValue {
  dollar_fraction_values("DOLLARDE", call.values)
}

///|
fn eval_dollarfr(call : EvalCall) -> FormulaValue {
  dollar_fraction_values("DOLLARFR", call.values)
}

///|
fn eval_effect(call : EvalCall) -> FormulaValue {
  effect_values(call.values)
}

///|
fn eval_ipmt(call : EvalCall) -> FormulaValue {
  ipmt_values("IPMT", call.values)
}

///|
fn eval_ispmt(call : EvalCall) -> FormulaValue {
  ispmt_values(call.values)
}

///|
fn eval_nominal(call : EvalCall) -> FormulaValue {
  nominal_values(call.values)
}

///|
fn eval_nper(call : EvalCall) -> FormulaValue {
  nper_values(call.values)
}

///|
fn eval_npv(call : EvalCall) -> FormulaValue {
  npv_values(call.values)
}

///|
fn eval_oddfprice(call : EvalCall) -> FormulaValue {
  oddfprice_values(call.values, use_1904_dates=call.ctx.use_1904_dates)
}

///|
fn eval_oddfyield(call : EvalCall) -> FormulaValue {
  oddfyield_values(call.values, use_1904_dates=call.ctx.use_1904_dates)
}

///|
fn eval_oddlprice(call : EvalCall) -> FormulaValue {
  oddl_values("ODDLPRICE", call.values, use_1904_dates=call.ctx.use_1904_dates)
}

///|
fn eval_oddlyield(call : EvalCall) -> FormulaValue {
  oddl_values("ODDLYIELD", call.values, use_1904_dates=call.ctx.use_1904_dates)
}

///|
fn eval_pduration(call : EvalCall) -> FormulaValue {
  pduration_values(call.values)
}

///|
fn eval_pmt(call : EvalCall) -> FormulaValue {
  pmt_values(call.values)
}

///|
fn eval_ppmt(call : EvalCall) -> FormulaValue {
  ipmt_values("PPMT", call.values)
}

///|
fn eval_price(call : EvalCall) -> FormulaValue {
  price_yield_values(
    "PRICE",
    call.values,
    use_1904_dates=call.ctx.use_1904_dates,
  )
}

///|
fn eval_pricedisc(call : EvalCall) -> FormulaValue {
  pricedisc_values(call.values, use_1904_dates=call.ctx.use_1904_dates)
}

///|
fn eval_pricemat(call : EvalCall) -> FormulaValue {
  pricemat_values(call.values, use_1904_dates=call.ctx.use_1904_dates)
}

///|
fn eval_pv(call : EvalCall) -> FormulaValue {
  pv_values(call.values)
}

///|
fn eval_rate(call : EvalCall) -> FormulaValue {
  rate_values(call.values)
}

///|
fn eval_received(call : EvalCall) -> FormulaValue {
  received_values(call.values, use_1904_dates=call.ctx.use_1904_dates)
}

///|
fn eval_rri(call : EvalCall) -> FormulaValue {
  rri_values(call.values)
}

///|
fn eval_sln(call : EvalCall) -> FormulaValue {
  sln_values(call.values)
}

///|
fn eval_syd(call : EvalCall) -> FormulaValue {
  syd_values(call.values)
}

///|
fn eval_tbilleq(call : EvalCall) -> FormulaValue {
  tbilleq_values(call.values, use_1904_dates=call.ctx.use_1904_dates)
}

///|
fn eval_tbillprice(call : EvalCall) -> FormulaValue {
  tbillprice_values(call.values, use_1904_dates=call.ctx.use_1904_dates)
}

///|
fn eval_tbillyield(call : EvalCall) -> FormulaValue {
  tbillyield_values(call.values, use_1904_dates=call.ctx.use_1904_dates)
}

///|
fn eval_xirr(call : EvalCall) -> FormulaValue {
  xirr_values(call.values)
}

///|
fn eval_xnpv(call : EvalCall) -> FormulaValue {
  xnpv_values(call.values)
}

///|
fn eval_yield(call : EvalCall) -> FormulaValue {
  price_yield_values(
    "YIELD",
    call.values,
    use_1904_dates=call.ctx.use_1904_dates,
  )
}

///|
fn eval_yielddisc(call : EvalCall) -> FormulaValue {
  yielddisc_values(call.values, use_1904_dates=call.ctx.use_1904_dates)
}

///|
fn eval_yieldmat(call : EvalCall) -> FormulaValue {
  yieldmat_values(call.values, use_1904_dates=call.ctx.use_1904_dates)
}

///|
fn eval_vdb(call : EvalCall) -> FormulaValue {
  vdb_values(call.values)
}
