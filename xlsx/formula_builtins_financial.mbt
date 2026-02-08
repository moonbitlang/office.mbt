///|
fn value_as_number_opt_financial(value : FormulaValue) -> Double? {
  match normalize_scalar(value) {
    Number(num) => Some(num)
    Bool(flag) => Some(if flag { 1.0 } else { 0.0 })
    Empty => Some(0.0)
    String(text) => parse_double_opt(text)
    Error(_) => Some(0.0)
    List(_) => None
  }
}

///|
fn value_as_number_financial(value : FormulaValue) -> Double {
  match value_as_number_opt_financial(value) {
    Some(num) => num
    None => 0.0
  }
}

///|
fn validate_frequency(freq : Double) -> Bool {
  freq == 1.0 || freq == 2.0 || freq == 4.0
}

///|
fn get_year_days(year : Int, basis : Int) -> Int {
  match basis {
    1 => if is_leap_year(year) { 366 } else { 365 }
    3 => 365
    _ => 360
  }
}

///|
fn is_30_basis_method(basis : Int) -> Bool {
  basis == 0 || basis == 4
}

///|
fn get_days_in_month_range(from_month : Int, to_month : Int) -> Int {
  if from_month > to_month {
    return 0
  }
  (to_month - from_month + 1) * 30
}

///|
fn get_day_on_basis(year : Int, month : Int, day : Int, basis : Int) -> Int {
  if !is_30_basis_method(basis) {
    return day
  }
  let dim = days_in_month(year, month)
  if day > 30 || day >= dim {
    30
  } else {
    day
  }
}

///|
fn coupdays_between(
  from_serial : Double,
  to_serial : Double,
  basis : Int,
) -> Double {
  let (from_year, from_month, from_day_raw) = match
    date_parts_from_serial(from_serial) {
    Some(parts) => parts
    None => return 0.0
  }
  let (to_year, to_month, to_day_raw) = match
    date_parts_from_serial(to_serial) {
    Some(parts) => parts
    None => return 0.0
  }
  let mut from_day = get_day_on_basis(
    from_year, from_month, from_day_raw, basis,
  )
  let mut to_day = get_day_on_basis(to_year, to_month, to_day_raw, basis)
  if !is_30_basis_method(basis) {
    let from_adj = match
      excel_serial_from_date(from_year, from_month, from_day) {
      Some(serial) => serial
      None => return 0.0
    }
    let to_adj = match excel_serial_from_date(to_year, to_month, to_day) {
      Some(serial) => serial
      None => return 0.0
    }
    return to_adj - from_adj
  }
  if basis == 0 {
    if (from_month == 2 || from_day < 30) && to_day_raw == 31 {
      to_day = 31
    }
  } else {
    if from_month == 2 && from_day == 30 {
      from_day = days_in_month(from_year, 2)
    }
    if to_month == 2 && to_day == 30 {
      to_day = days_in_month(to_year, 2)
    }
  }
  let mut days = 0
  if from_year < to_year || (from_year == to_year && from_month < to_month) {
    days = 30 - from_day + 1
    from_day = 1
    let mut year = from_year
    let mut month = from_month + 1
    if month > 12 {
      month = 1
      year = year + 1
    }
    if year < to_year {
      days = days + get_days_in_month_range(month, 12)
      year = year + 1
      month = 1
    }
    days = days + get_days_in_month_range(month, to_month - 1)
  }
  days = days + to_day - from_day
  if days > 0 {
    Double::from_int(days)
  } else {
    0.0
  }
}

///|
fn coupon_date_serial(
  name : String,
  settlement_serial : Double,
  maturity_serial : Double,
  frequency : Double,
) -> Result[Double, FormulaValue] {
  let (settle_year, settle_month, settle_day) = match
    date_parts_from_serial(settlement_serial) {
    Some(parts) => parts
    None => return Err(Error(formula_error_value))
  }
  let (mat_year, mat_month, mat_day) = match
    date_parts_from_serial(maturity_serial) {
    Some(parts) => parts
    None => return Err(Error(formula_error_value))
  }
  let maturity_months = (mat_year - settle_year) * 12 +
    (mat_month - settle_month)
  let coupon = 12 / Double::to_int(trunc_double(frequency))
  let mod_months = maturity_months % coupon
  let mut year = settle_year
  let mut month = settle_month
  if mod_months == 0 && settle_day >= mat_day {
    month = month + coupon
  } else {
    month = month + mod_months
  }
  if name != "COUPNCD" {
    month = month - coupon
  }
  let (year_norm, month_norm) = normalize_year_month(year, month)
  year = year_norm
  month = month_norm
  let mut day = mat_day
  let days = days_in_month(year, month)
  if days_in_month(mat_year, mat_month) == mat_day {
    day = days
  } else if day > 27 && day > days {
    day = days
  }
  match excel_serial_from_date(year, month, day) {
    Some(serial) => Ok(serial)
    None => Err(Error(formula_error_num))
  }
}

///|
fn prepare_coupon_args(
  values : ArrayView[FormulaValue],
) -> Result[(Double, Double, Double, Int), FormulaValue] {
  if values.length() != 3 && values.length() != 4 {
    return Err(Error(formula_error_value))
  }
  let settlement = match value_as_date_serial(values[0]) {
    Ok(num) => num
    Err(err) => return Err(err)
  }
  let maturity = match value_as_date_serial(values[1]) {
    Ok(num) => num
    Err(err) => return Err(err)
  }
  if settlement >= maturity {
    return Err(Error(formula_error_num))
  }
  let frequency = match value_as_number(values[2]) {
    Ok(num) => num
    Err(err) => return Err(err)
  }
  if !validate_frequency(frequency) {
    return Err(Error(formula_error_num))
  }
  let basis = if values.length() == 4 {
    match value_as_number(values[3]) {
      Ok(num) => Double::to_int(trunc_double(num))
      Err(err) => return Err(err)
    }
  } else {
    0
  }
  Ok((settlement, maturity, frequency, basis))
}

///|
fn coupdaybs_value(
  settlement : Double,
  maturity : Double,
  frequency : Double,
  basis : Int,
) -> Result[Double, FormulaValue] {
  let pcd = match
    coupon_date_serial("COUPPCD", settlement, maturity, frequency) {
    Ok(serial) => serial
    Err(err) => return Err(err)
  }
  Ok(coupdays_between(pcd, settlement, basis))
}

///|
fn coupdays_value(
  settlement : Double,
  maturity : Double,
  frequency : Double,
  basis : Int,
) -> Result[Double, FormulaValue] {
  if basis == 1 {
    let pcd = match
      coupon_date_serial("COUPPCD", settlement, maturity, frequency) {
      Ok(serial) => serial
      Err(err) => return Err(err)
    }
    let months = 12 / Double::to_int(trunc_double(frequency))
    let next = match date_parts_from_serial(pcd) {
      Some((year, month, day)) => {
        let (new_year, new_month, new_day) = normalize_date_parts(
          year,
          month + months,
          day,
        )
        match excel_serial_from_date(new_year, new_month, new_day) {
          Some(serial) => serial
          None => return Err(Error(formula_error_num))
        }
      }
      None => return Err(Error(formula_error_value))
    }
    return Ok(coupdays_between(pcd, next, basis))
  }
  let year_days = get_year_days(0, basis)
  Ok(Double::from_int(year_days) / frequency)
}

///|
fn coupdaysnc_value(
  settlement : Double,
  maturity : Double,
  frequency : Double,
  basis : Int,
) -> Result[Double, FormulaValue] {
  let ncd = match
    coupon_date_serial("COUPNCD", settlement, maturity, frequency) {
    Ok(serial) => serial
    Err(err) => return Err(err)
  }
  Ok(coupdays_between(settlement, ncd, basis))
}

///|
fn coupnum_value(
  settlement : Double,
  maturity : Double,
  frequency : Double,
) -> Result[Double, FormulaValue] {
  match yearfrac_value(settlement, maturity, 0) {
    Number(num) => Ok(Double::ceil(num * frequency))
    Error(err) => Err(Error(err))
    _ => Err(Error(formula_error_value))
  }
}

///|
fn yearfrac_number(
  start_serial : Double,
  end_serial : Double,
  basis : Int,
) -> Result[Double, FormulaValue] {
  match yearfrac_value(start_serial, end_serial, basis) {
    Number(num) => Ok(num)
    Error(err) => Err(Error(err))
    _ => Err(Error(formula_error_value))
  }
}

///|
fn round_half_up(value : Double) -> Double {
  if value < 0.0 {
    -Double::from_int(Double::to_int(trunc_double(-value + 0.5)))
  } else {
    Double::from_int(Double::to_int(trunc_double(value + 0.5)))
  }
}

///|
fn amor_date_serial(value : FormulaValue) -> Result[Double, FormulaValue] {
  let normalized = normalize_scalar(value)
  match normalized {
    String(text) => {
      let trimmed = text.trim().to_string()
      if trimmed == "" {
        Err(Error(formula_error_value))
      } else {
        value_as_date_serial(String(trimmed))
      }
    }
    _ => value_as_date_serial(normalized)
  }
}

///|
priv struct AmorArgs {
  cost : Double
  date_purchased : Double
  first_period : Double
  salvage : Double
  period : Int
  rate : Double
  basis : Int
}

///|
fn prepare_amor_args(
  values : ArrayView[FormulaValue],
) -> Result[AmorArgs, FormulaValue] {
  if values.length() != 6 && values.length() != 7 {
    return Err(Error(formula_error_value))
  }
  let cost = match value_as_number(values[0]) {
    Ok(num) => num
    Err(_) => return Err(Error(formula_error_value))
  }
  if cost < 0.0 {
    return Err(Error(formula_error_value))
  }
  let date_purchased = match amor_date_serial(values[1]) {
    Ok(num) => num
    Err(err) => return Err(err)
  }
  let first_period = match amor_date_serial(values[2]) {
    Ok(num) => num
    Err(err) => return Err(err)
  }
  if first_period < date_purchased {
    return Err(Error(formula_error_num))
  }
  let salvage = match value_as_number(values[3]) {
    Ok(num) => num
    Err(_) => return Err(Error(formula_error_num))
  }
  if salvage < 0.0 || salvage > cost {
    return Err(Error(formula_error_num))
  }
  let period_value = match value_as_number(values[4]) {
    Ok(num) => num
    Err(_) => return Err(Error(formula_error_num))
  }
  if period_value < 0.0 {
    return Err(Error(formula_error_num))
  }
  let rate = match value_as_number(values[5]) {
    Ok(num) => num
    Err(_) => return Err(Error(formula_error_num))
  }
  if rate < 0.0 {
    return Err(Error(formula_error_num))
  }
  let basis_value = if values.length() == 7 {
    match value_as_number(values[6]) {
      Ok(num) => num
      Err(_) => return Err(Error(formula_error_num))
    }
  } else {
    0.0
  }
  Ok({
    cost,
    date_purchased,
    first_period,
    salvage,
    period: Double::to_int(trunc_double(period_value)),
    rate,
    basis: Double::to_int(trunc_double(basis_value)),
  })
}

///|
fn amordegrc_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  let args = match prepare_amor_args(values) {
    Ok(value) => value
    Err(err) => return err
  }
  if args.rate >= 0.5 {
    return Error(formula_error_num)
  }
  let assets_life = 1.0 / args.rate
  let mut amor_coeff = 2.5
  if assets_life < 3.0 {
    amor_coeff = 1.0
  } else if assets_life < 5.0 {
    amor_coeff = 1.5
  } else if assets_life <= 6.0 {
    amor_coeff = 2.0
  }
  let rate = args.rate * amor_coeff
  let frac = match
    yearfrac_number(args.date_purchased, args.first_period, args.basis) {
    Ok(num) => num
    Err(err) => return err
  }
  let mut cost = args.cost
  let mut n_rate = round_half_up(frac * cost * rate)
  cost = cost - n_rate
  if args.period == 0 {
    return number_or_num_error(round_significant_digits(n_rate, 15))
  }
  let mut rest = cost - args.salvage
  for idx in 0..<args.period {
    n_rate = round_half_up(cost * rate)
    rest = rest - n_rate
    if rest < 0.0 {
      let remaining = args.period - idx
      if remaining == 1 {
        return number_or_num_error(
          round_significant_digits(round_half_up(cost * 0.5), 15),
        )
      }
      return Number(0.0)
    }
    cost = cost - n_rate
  }
  number_or_num_error(round_significant_digits(n_rate, 15))
}

///|
fn amorlinc_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  let args = match prepare_amor_args(values) {
    Ok(value) => value
    Err(err) => return err
  }
  let frac = match
    yearfrac_number(args.date_purchased, args.first_period, args.basis) {
    Ok(num) => num
    Err(err) => return err
  }
  let rate1 = frac * args.cost * args.rate
  if args.period == 0 {
    return number_or_num_error(round_significant_digits(rate1, 15))
  }
  let rate2 = args.cost * args.rate
  if rate2 == 0.0 {
    return Number(0.0)
  }
  let delta = args.cost - args.salvage
  let periods = Double::to_int(trunc_double((delta - rate1) / rate2))
  if args.period <= periods {
    return number_or_num_error(round_significant_digits(rate2, 15))
  }
  if args.period - 1 == periods {
    let result = delta - rate2 * Double::from_int(periods) - rate1
    return number_or_num_error(round_significant_digits(result, 15))
  }
  Number(0.0)
}

///|
priv struct ConversionUnit {
  group : Int
  allow_prefix : Bool
}

///|
let conversion_units : Map[String, ConversionUnit] = {
  "g": { group: category_weight_and_mass, allow_prefix: true },
  "sg": { group: category_weight_and_mass, allow_prefix: false },
  "lbm": { group: category_weight_and_mass, allow_prefix: false },
  "u": { group: category_weight_and_mass, allow_prefix: true },
  "ozm": { group: category_weight_and_mass, allow_prefix: false },
  "grain": { group: category_weight_and_mass, allow_prefix: false },
  "cwt": { group: category_weight_and_mass, allow_prefix: false },
  "shweight": { group: category_weight_and_mass, allow_prefix: false },
  "uk_cwt": { group: category_weight_and_mass, allow_prefix: false },
  "lcwt": { group: category_weight_and_mass, allow_prefix: false },
  "hweight": { group: category_weight_and_mass, allow_prefix: false },
  "stone": { group: category_weight_and_mass, allow_prefix: false },
  "ton": { group: category_weight_and_mass, allow_prefix: false },
  "uk_ton": { group: category_weight_and_mass, allow_prefix: false },
  "LTON": { group: category_weight_and_mass, allow_prefix: false },
  "brton": { group: category_weight_and_mass, allow_prefix: false },
  "m": { group: category_distance, allow_prefix: true },
  "mi": { group: category_distance, allow_prefix: false },
  "Nmi": { group: category_distance, allow_prefix: false },
  "in": { group: category_distance, allow_prefix: false },
  "ft": { group: category_distance, allow_prefix: false },
  "yd": { group: category_distance, allow_prefix: false },
  "ang": { group: category_distance, allow_prefix: true },
  "ell": { group: category_distance, allow_prefix: false },
  "ly": { group: category_distance, allow_prefix: false },
  "parsec": { group: category_distance, allow_prefix: false },
  "pc": { group: category_distance, allow_prefix: false },
  "Pica": { group: category_distance, allow_prefix: false },
  "Picapt": { group: category_distance, allow_prefix: false },
  "pica": { group: category_distance, allow_prefix: false },
  "survey_mi": { group: category_distance, allow_prefix: false },
  "yr": { group: category_time, allow_prefix: false },
  "day": { group: category_time, allow_prefix: false },
  "d": { group: category_time, allow_prefix: false },
  "hr": { group: category_time, allow_prefix: false },
  "mn": { group: category_time, allow_prefix: false },
  "min": { group: category_time, allow_prefix: false },
  "sec": { group: category_time, allow_prefix: true },
  "s": { group: category_time, allow_prefix: true },
  "Pa": { group: category_pressure, allow_prefix: true },
  "p": { group: category_pressure, allow_prefix: true },
  "atm": { group: category_pressure, allow_prefix: true },
  "at": { group: category_pressure, allow_prefix: true },
  "mmHg": { group: category_pressure, allow_prefix: true },
  "psi": { group: category_pressure, allow_prefix: true },
  "Torr": { group: category_pressure, allow_prefix: true },
  "N": { group: category_force, allow_prefix: true },
  "dyn": { group: category_force, allow_prefix: true },
  "dy": { group: category_force, allow_prefix: true },
  "lbf": { group: category_force, allow_prefix: false },
  "pond": { group: category_force, allow_prefix: true },
  "J": { group: category_energy, allow_prefix: true },
  "e": { group: category_energy, allow_prefix: true },
  "c": { group: category_energy, allow_prefix: true },
  "cal": { group: category_energy, allow_prefix: true },
  "eV": { group: category_energy, allow_prefix: true },
  "ev": { group: category_energy, allow_prefix: true },
  "HPh": { group: category_energy, allow_prefix: false },
  "hh": { group: category_energy, allow_prefix: false },
  "Wh": { group: category_energy, allow_prefix: true },
  "wh": { group: category_energy, allow_prefix: true },
  "flb": { group: category_energy, allow_prefix: false },
  "BTU": { group: category_energy, allow_prefix: false },
  "btu": { group: category_energy, allow_prefix: false },
  "HP": { group: category_power, allow_prefix: false },
  "h": { group: category_power, allow_prefix: false },
  "W": { group: category_power, allow_prefix: true },
  "w": { group: category_power, allow_prefix: true },
  "PS": { group: category_power, allow_prefix: false },
  "T": { group: category_magnetism, allow_prefix: true },
  "ga": { group: category_magnetism, allow_prefix: true },
  "C": { group: category_temperature, allow_prefix: false },
  "cel": { group: category_temperature, allow_prefix: false },
  "F": { group: category_temperature, allow_prefix: false },
  "fah": { group: category_temperature, allow_prefix: false },
  "K": { group: category_temperature, allow_prefix: false },
  "kel": { group: category_temperature, allow_prefix: false },
  "Rank": { group: category_temperature, allow_prefix: false },
  "Reau": { group: category_temperature, allow_prefix: false },
  "l": { group: category_volume_and_liquid_measure, allow_prefix: true },
  "L": { group: category_volume_and_liquid_measure, allow_prefix: true },
  "lt": { group: category_volume_and_liquid_measure, allow_prefix: true },
  "tsp": { group: category_volume_and_liquid_measure, allow_prefix: false },
  "tspm": { group: category_volume_and_liquid_measure, allow_prefix: false },
  "tbs": { group: category_volume_and_liquid_measure, allow_prefix: false },
  "oz": { group: category_volume_and_liquid_measure, allow_prefix: false },
  "cup": { group: category_volume_and_liquid_measure, allow_prefix: false },
  "pt": { group: category_volume_and_liquid_measure, allow_prefix: false },
  "us_pt": { group: category_volume_and_liquid_measure, allow_prefix: false },
  "uk_pt": { group: category_volume_and_liquid_measure, allow_prefix: false },
  "qt": { group: category_volume_and_liquid_measure, allow_prefix: false },
  "uk_qt": { group: category_volume_and_liquid_measure, allow_prefix: false },
  "gal": { group: category_volume_and_liquid_measure, allow_prefix: false },
  "uk_gal": { group: category_volume_and_liquid_measure, allow_prefix: false },
  "ang3": { group: category_volume_and_liquid_measure, allow_prefix: true },
  "ang^3": { group: category_volume_and_liquid_measure, allow_prefix: true },
  "barrel": { group: category_volume_and_liquid_measure, allow_prefix: false },
  "bushel": { group: category_volume_and_liquid_measure, allow_prefix: false },
  "in3": { group: category_volume_and_liquid_measure, allow_prefix: false },
  "in^3": { group: category_volume_and_liquid_measure, allow_prefix: false },
  "ft3": { group: category_volume_and_liquid_measure, allow_prefix: false },
  "ft^3": { group: category_volume_and_liquid_measure, allow_prefix: false },
  "ly3": { group: category_volume_and_liquid_measure, allow_prefix: false },
  "ly^3": { group: category_volume_and_liquid_measure, allow_prefix: false },
  "m3": { group: category_volume_and_liquid_measure, allow_prefix: true },
  "m^3": { group: category_volume_and_liquid_measure, allow_prefix: true },
  "mi3": { group: category_volume_and_liquid_measure, allow_prefix: false },
  "mi^3": { group: category_volume_and_liquid_measure, allow_prefix: false },
  "yd3": { group: category_volume_and_liquid_measure, allow_prefix: false },
  "yd^3": { group: category_volume_and_liquid_measure, allow_prefix: false },
  "Nmi3": { group: category_volume_and_liquid_measure, allow_prefix: false },
  "Nmi^3": { group: category_volume_and_liquid_measure, allow_prefix: false },
  "Pica3": { group: category_volume_and_liquid_measure, allow_prefix: false },
  "Pica^3": { group: category_volume_and_liquid_measure, allow_prefix: false },
  "Picapt3": { group: category_volume_and_liquid_measure, allow_prefix: false },
  "Picapt^3": { group: category_volume_and_liquid_measure, allow_prefix: false },
  "GRT": { group: category_volume_and_liquid_measure, allow_prefix: false },
  "regton": { group: category_volume_and_liquid_measure, allow_prefix: false },
  "MTON": { group: category_volume_and_liquid_measure, allow_prefix: false },
  "ha": { group: category_area, allow_prefix: true },
  "uk_acre": { group: category_area, allow_prefix: false },
  "us_acre": { group: category_area, allow_prefix: false },
  "ang2": { group: category_area, allow_prefix: true },
  "ang^2": { group: category_area, allow_prefix: true },
  "ar": { group: category_area, allow_prefix: true },
  "ft2": { group: category_area, allow_prefix: false },
  "ft^2": { group: category_area, allow_prefix: false },
  "in2": { group: category_area, allow_prefix: false },
  "in^2": { group: category_area, allow_prefix: false },
  "ly2": { group: category_area, allow_prefix: false },
  "ly^2": { group: category_area, allow_prefix: false },
  "m2": { group: category_area, allow_prefix: true },
  "m^2": { group: category_area, allow_prefix: true },
  "Morgen": { group: category_area, allow_prefix: false },
  "mi2": { group: category_area, allow_prefix: false },
  "mi^2": { group: category_area, allow_prefix: false },
  "Nmi2": { group: category_area, allow_prefix: false },
  "Nmi^2": { group: category_area, allow_prefix: false },
  "Pica2": { group: category_area, allow_prefix: false },
  "Pica^2": { group: category_area, allow_prefix: false },
  "Picapt2": { group: category_area, allow_prefix: false },
  "Picapt^2": { group: category_area, allow_prefix: false },
  "yd2": { group: category_area, allow_prefix: false },
  "yd^2": { group: category_area, allow_prefix: false },
  "byte": { group: category_information, allow_prefix: true },
  "bit": { group: category_information, allow_prefix: true },
  "m/s": { group: category_speed, allow_prefix: true },
  "m/sec": { group: category_speed, allow_prefix: true },
  "m/h": { group: category_speed, allow_prefix: true },
  "m/hr": { group: category_speed, allow_prefix: true },
  "mph": { group: category_speed, allow_prefix: false },
  "admkn": { group: category_speed, allow_prefix: false },
  "kn": { group: category_speed, allow_prefix: false },
}

///|
let conversion_multipliers : Map[String, Double] = {
  "Y": 1.0e24,
  "Z": 1.0e21,
  "E": 1.0e18,
  "P": 1.0e15,
  "T": 1.0e12,
  "G": 1.0e9,
  "M": 1.0e6,
  "k": 1.0e3,
  "h": 1.0e2,
  "e": 1.0e1,
  "da": 1.0e1,
  "d": 1.0e-1,
  "c": 1.0e-2,
  "m": 1.0e-3,
  "u": 1.0e-6,
  "n": 1.0e-9,
  "p": 1.0e-12,
  "f": 1.0e-15,
  "a": 1.0e-18,
  "z": 1.0e-21,
  "y": 1.0e-24,
  "Yi": @math.pow(2.0, 80.0),
  "Zi": @math.pow(2.0, 70.0),
  "Ei": @math.pow(2.0, 60.0),
  "Pi": @math.pow(2.0, 50.0),
  "Ti": @math.pow(2.0, 40.0),
  "Gi": @math.pow(2.0, 30.0),
  "Mi": @math.pow(2.0, 20.0),
  "ki": @math.pow(2.0, 10.0),
}

///|
fn build_unit_conversions() -> Map[Int, Map[String, Double]] {
  let conversions : Map[Int, Map[String, Double]] = {}
  conversions[category_weight_and_mass] = {
    "g": 1.0,
    "sg": 6.85217658567918e-05,
    "lbm": 2.20462262184878e-03,
    "u": 6.02214179421676e+23,
    "ozm": 3.52739619495804e-02,
    "grain": 1.54323583529414e+01,
    "cwt": 2.20462262184878e-05,
    "shweight": 2.20462262184878e-05,
    "uk_cwt": 1.96841305522212e-05,
    "lcwt": 1.96841305522212e-05,
    "hweight": 1.96841305522212e-05,
    "stone": 1.57473044417770e-04,
    "ton": 1.10231131092439e-06,
    "uk_ton": 9.84206527611061e-07,
    "LTON": 9.84206527611061e-07,
    "brton": 9.84206527611061e-07,
  }
  conversions[category_distance] = {
    "m": 1.0,
    "mi": 6.21371192237334e-04,
    "Nmi": 5.39956803455724e-04,
    "in": 3.93700787401575e+01,
    "ft": 3.28083989501312e+00,
    "yd": 1.09361329833771e+00,
    "ang": 1.0e+10,
    "ell": 8.74890638670166e-01,
    "ly": 1.05700083402462e-16,
    "parsec": 3.24077928966473e-17,
    "pc": 3.24077928966473e-17,
    "Pica": 2.83464566929134e+03,
    "Picapt": 2.83464566929134e+03,
    "pica": 2.36220472440945e+02,
    "survey_mi": 6.21369949494950e-04,
  }
  conversions[category_time] = {
    "yr": 3.16880878140289e-08,
    "day": 1.15740740740741e-05,
    "d": 1.15740740740741e-05,
    "hr": 2.77777777777778e-04,
    "mn": 1.66666666666667e-02,
    "min": 1.66666666666667e-02,
    "sec": 1.0,
    "s": 1.0,
  }
  conversions[category_pressure] = {
    "Pa": 1.0,
    "p": 1.0,
    "atm": 9.86923266716013e-06,
    "at": 9.86923266716013e-06,
    "mmHg": 7.50063755419211e-03,
    "psi": 1.45037737730209e-04,
    "Torr": 7.50061682704170e-03,
  }
  conversions[category_force] = {
    "N": 1.0,
    "dyn": 1.0e+5,
    "dy": 1.0e+5,
    "lbf": 2.24808923655339e-01,
    "pond": 1.01971621297793e+02,
  }
  conversions[category_energy] = {
    "J": 1.0,
    "e": 9.99999519343231e+06,
    "c": 2.39006249473467e-01,
    "cal": 2.38846190642017e-01,
    "eV": 6.24145700000000e+18,
    "ev": 6.24145700000000e+18,
    "HPh": 3.72506430801000e-07,
    "hh": 3.72506430801000e-07,
    "Wh": 2.77777916238711e-04,
    "wh": 2.77777916238711e-04,
    "flb": 2.37304222192651e+01,
    "BTU": 9.47815067349015e-04,
    "btu": 9.47815067349015e-04,
  }
  conversions[category_power] = {
    "HP": 1.0,
    "h": 1.0,
    "W": 7.45699871582270e+02,
    "w": 7.45699871582270e+02,
    "PS": 1.01386966542400e+00,
  }
  conversions[category_magnetism] = { "T": 1.0, "ga": 10000.0 }
  conversions[category_volume_and_liquid_measure] = {
    "l": 1.0,
    "L": 1.0,
    "lt": 1.0,
    "tsp": 2.02884136211058e+02,
    "tspm": 2.0e+02,
    "tbs": 6.76280454036860e+01,
    "oz": 3.38140227018430e+01,
    "cup": 4.22675283773038e+00,
    "pt": 2.11337641886519e+00,
    "us_pt": 2.11337641886519e+00,
    "uk_pt": 1.75975398639270e+00,
    "qt": 1.05668820943259e+00,
    "uk_qt": 8.79876993196351e-01,
    "gal": 2.64172052358148e-01,
    "uk_gal": 2.19969248299088e-01,
    "ang3": 1.0e+27,
    "ang^3": 1.0e+27,
    "barrel": 6.28981077043211e-03,
    "bushel": 2.83775932584017e-02,
    "in3": 6.10237440947323e+01,
    "in^3": 6.10237440947323e+01,
    "ft3": 3.53146667214886e-02,
    "ft^3": 3.53146667214886e-02,
    "ly3": 1.18093498844171e-51,
    "ly^3": 1.18093498844171e-51,
    "m3": 1.0e-03,
    "m^3": 1.0e-03,
    "mi3": 2.39912758578928e-13,
    "mi^3": 2.39912758578928e-13,
    "yd3": 1.30795061931439e-03,
    "yd^3": 1.30795061931439e-03,
    "Nmi3": 1.57426214685811e-13,
    "Nmi^3": 1.57426214685811e-13,
    "Pica3": 2.27769904358706e+07,
    "Pica^3": 2.27769904358706e+07,
    "Picapt3": 2.27769904358706e+07,
    "Picapt^3": 2.27769904358706e+07,
    "GRT": 3.53146667214886e-04,
    "regton": 3.53146667214886e-04,
    "MTON": 8.82866668037215e-04,
  }
  conversions[category_area] = {
    "ha": 1.0,
    "uk_acre": 2.47105381467165e+00,
    "us_acre": 2.47104393046628e+00,
    "ang2": 1.0e+24,
    "ang^2": 1.0e+24,
    "ar": 1.0e+02,
    "ft2": 1.07639104167097e+05,
    "ft^2": 1.07639104167097e+05,
    "in2": 1.55000310000620e+07,
    "in^2": 1.55000310000620e+07,
    "ly2": 1.11725076312873e-28,
    "ly^2": 1.11725076312873e-28,
    "m2": 1.0e+04,
    "m^2": 1.0e+04,
    "Morgen": 4.0e+00,
    "mi2": 3.86102158542446e-03,
    "mi^2": 3.86102158542446e-03,
    "Nmi2": 2.91553349598123e-03,
    "Nmi^2": 2.91553349598123e-03,
    "Pica2": 8.03521607043214e+10,
    "Pica^2": 8.03521607043214e+10,
    "Picapt2": 8.03521607043214e+10,
    "Picapt^2": 8.03521607043214e+10,
    "yd2": 1.19599004630108e+04,
    "yd^2": 1.19599004630108e+04,
  }
  conversions[category_information] = { "bit": 1.0, "byte": 0.125 }
  conversions[category_speed] = {
    "m/s": 1.0,
    "m/sec": 1.0,
    "m/h": 3.60e+03,
    "m/hr": 3.60e+03,
    "mph": 2.23693629205440e+00,
    "admkn": 1.94260256941567e+00,
    "kn": 1.94384449244060e+00,
  }
  conversions
}

///|
let unit_conversions : Map[Int, Map[String, Double]] = build_unit_conversions()

///|
fn get_unit_details(uom_text : String) -> (String, Int, Double, Bool) {
  if uom_text.length() == 0 {
    return ("", 0, 0.0, false)
  }
  match conversion_units.get(uom_text) {
    Some(unit) => return (uom_text, unit.group, 1.0, true)
    None => ()
  }
  let mut uom = uom_text
  let mut multiplier_type = uom.unsafe_substring(start=0, end=1)
  uom = uom.unsafe_substring(start=1, end=uom.length())
  match
    (conversion_units.get(uom), conversion_multipliers.get(multiplier_type)) {
    (Some(unit), Some(multiplier)) =>
      if !unit.allow_prefix {
        return ("", 0, 0.0, false)
      } else {
        return (uom, unit.group, multiplier, true)
      }
    _ => ()
  }
  if uom.length() > 0 {
    multiplier_type = multiplier_type + uom.unsafe_substring(start=0, end=1)
    uom = uom.unsafe_substring(start=1, end=uom.length())
  }
  match
    (conversion_units.get(uom), conversion_multipliers.get(multiplier_type)) {
    (Some(unit), Some(multiplier)) =>
      if !unit.allow_prefix {
        ("", 0, 0.0, false)
      } else {
        (uom, unit.group, multiplier, true)
      }
    _ => ("", 0, 0.0, false)
  }
}

///|
fn resolve_temperature_synonyms(uom : String) -> String {
  match uom {
    "fah" => "F"
    "cel" => "C"
    "kel" => "K"
    _ => uom
  }
}

///|
fn convert_temperature(
  from_uom : String,
  to_uom : String,
  value : Double,
) -> Double {
  let from_unit = resolve_temperature_synonyms(from_uom)
  let to_unit = resolve_temperature_synonyms(to_uom)
  if from_unit == to_unit {
    return value
  }
  let mut result = value
  match from_unit {
    "F" => result = (result - 32.0) / 1.8 + 273.15
    "C" => result = result + 273.15
    "Rank" => result = result / 1.8
    "Reau" => result = result * 1.25 + 273.15
    _ => ()
  }
  match to_unit {
    "F" => result = (result - 273.15) * 1.8 + 32.0
    "C" => result = result - 273.15
    "Rank" => result = result * 1.8
    "Reau" => result = (result - 273.15) * 0.8
    _ => ()
  }
  result
}

///|
fn convert_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 3 {
    return Error(formula_error_value)
  }
  let number = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let from_unit = match value_as_string(values[1]) {
    Ok(value) => value
    Err(err) => return err
  }
  let to_unit = match value_as_string(values[2]) {
    Ok(value) => value
    Err(err) => return err
  }
  let (from_uom, from_category, from_multiplier, ok1) = get_unit_details(
    from_unit,
  )
  let (to_uom, to_category, to_multiplier, ok2) = get_unit_details(to_unit)
  if !ok1 || !ok2 || from_category != to_category {
    return Error(formula_error_na)
  }
  let value = number * from_multiplier
  let result = if from_uom == to_uom && from_multiplier == to_multiplier {
    value / from_multiplier
  } else if from_uom == to_uom {
    value / to_multiplier
  } else if from_category == category_temperature {
    convert_temperature(from_uom, to_uom, value)
  } else {
    let conversions = match unit_conversions.get(from_category) {
      Some(map) => map
      None => return Error(formula_error_na)
    }
    let from_conversion = match conversions.get(from_uom) {
      Some(num) => num
      None => return Error(formula_error_na)
    }
    let to_conversion = match conversions.get(to_uom) {
      Some(num) => num
      None => return Error(formula_error_na)
    }
    let base_value = value * (1.0 / from_conversion)
    base_value * to_conversion / to_multiplier
  }
  number_or_num_error(round_significant_digits(result, 15))
}

///|
fn euroconvert_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() < 3 {
    return Error(formula_error_value)
  }
  if values.length() > 5 {
    return Error(formula_error_value)
  }
  let number = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let source_currency = match value_as_string(values[1]) {
    Ok(text) => text.to_upper()
    Err(err) => return err
  }
  let target_currency = match value_as_string(values[2]) {
    Ok(text) => text.to_upper()
    Err(err) => return err
  }
  let mut full_precision = false
  if values.length() >= 4 {
    full_precision = match value_as_bool(values[3]) {
      Ok(flag) => flag
      Err(err) => return err
    }
  }
  let mut triangulation_precision = 0.0
  if values.length() == 5 {
    triangulation_precision = match value_as_number(values[4]) {
      Ok(num) => num
      Err(err) => return err
    }
  }
  let convert_table : Map[String, (Double, Int)] = {
    "EUR": (1.0, 2),
    "ATS": (13.7603, 2),
    "BEF": (40.3399, 0),
    "DEM": (1.95583, 2),
    "ESP": (166.386, 0),
    "FIM": (5.94573, 2),
    "FRF": (6.55957, 2),
    "IEP": (0.787564, 2),
    "ITL": (1936.27, 0),
    "LUF": (40.3399, 0),
    "NLG": (2.20371, 2),
    "PTE": (200.482, 2),
    "GRD": (340.750, 2),
    "SIT": (239.640, 2),
    "MTL": (0.429300, 2),
    "CYP": (0.585274, 2),
    "SKK": (30.1260, 2),
    "EEK": (15.6466, 2),
    "LVL": (0.702804, 2),
    "LTL": (3.45280, 2),
  }
  let (source_rate, _source_decimals) = match
    convert_table.get(source_currency) {
    Some(value) => value
    None => return Error(formula_error_value)
  }
  let (target_rate, target_decimals) = match
    convert_table.get(target_currency) {
    Some(value) => value
    None => return Error(formula_error_value)
  }
  if source_currency == target_currency {
    return Number(number)
  }
  let mut result = if source_currency == "EUR" {
    number * target_rate
  } else {
    let mut intermediate = number / source_rate
    if triangulation_precision != 0.0 {
      let ratio = @math.pow(10.0, triangulation_precision)
      intermediate = Double::round(intermediate * ratio) / ratio
    }
    intermediate * target_rate
  }
  if !full_precision {
    let ratio = @math.pow(10.0, Double::from_int(target_decimals))
    result = Double::round(result * ratio) / ratio
  }
  number_or_num_error(round_significant_digits(result, 15))
}

///|
fn fv_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() < 3 {
    return Error(formula_error_value)
  }
  if values.length() > 5 {
    return Error(formula_error_value)
  }
  let rate = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let nper = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  let pmt = match value_as_number(values[2]) {
    Ok(num) => num
    Err(err) => return err
  }
  let pv = if values.length() >= 4 {
    match value_as_number(values[3]) {
      Ok(num) => num
      Err(err) => return err
    }
  } else {
    0.0
  }
  let typ = if values.length() == 5 {
    match value_as_number(values[4]) {
      Ok(num) => num
      Err(err) => return err
    }
  } else {
    0.0
  }
  if typ != 0.0 && typ != 1.0 {
    return Error(formula_error_na)
  }
  let result = if rate != 0.0 {
    let factor = @math.pow(1.0 + rate, nper)
    -pv * factor - pmt * (1.0 + rate * typ) * (factor - 1.0) / rate
  } else {
    -pv - pmt * nper
  }
  number_or_num_error(round_significant_digits(result, 15))
}

///|
fn fvschedule_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 2 {
    return Error(formula_error_value)
  }
  let principal = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let schedule = flatten_values([values[1]])
  let mut result = principal
  for value in schedule {
    match normalize_scalar(value) {
      Empty => ()
      Error(_) => ()
      String(text) =>
        if text == "" {
          ()
        } else {
          match parse_double_opt(text) {
            Some(num) => result = result * (1.0 + num)
            None => return Error(formula_error_value)
          }
        }
      _ =>
        match value_as_number(value) {
          Ok(num) => result = result * (1.0 + num)
          Err(err) => return err
        }
    }
  }
  number_or_num_error(round_significant_digits(result, 15))
}

///|
fn calc_npv(rate : Double, values : ArrayView[FormulaValue]) -> Double {
  let mut result = 0.0
  let mut period = 1
  for value in values {
    match value_as_number_opt_financial(value) {
      Some(num) => {
        result = result + num / @math.pow(1.0 + rate, Double::from_int(period))
        period = period + 1
      }
      None => ()
    }
  }
  result
}

///|
fn npv_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() < 2 {
    return Error(formula_error_value)
  }
  let rate = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let mut result = 0.0
  let mut period = 1
  for idx in 1..<values.length() {
    match value_as_number_opt_financial(values[idx]) {
      Some(num) => {
        result = result + num / @math.pow(1.0 + rate, Double::from_int(period))
        period = period + 1
      }
      None => ()
    }
  }
  number_or_num_error(round_significant_digits(result, 15))
}

///|
fn pv_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() < 3 {
    return Error(formula_error_value)
  }
  if values.length() > 5 {
    return Error(formula_error_value)
  }
  let rate = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let nper = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  let pmt = match value_as_number(values[2]) {
    Ok(num) => num
    Err(err) => return err
  }
  let fv = if values.length() >= 4 {
    match value_as_number(values[3]) {
      Ok(num) => num
      Err(err) => return err
    }
  } else {
    0.0
  }
  let typ = if values.length() == 5 {
    match value_as_number(values[4]) {
      Ok(num) => num
      Err(err) => return err
    }
  } else {
    0.0
  }
  let result = if rate == 0.0 {
    -pmt * nper - fv
  } else {
    let factor = @math.pow(1.0 + rate, nper)
    ((1.0 - factor) / rate * pmt * (1.0 + rate * typ) - fv) / factor
  }
  number_or_num_error(round_significant_digits(result, 15))
}

///|
fn calc_rate(
  nper : Double,
  pmt : Double,
  pv : Double,
  fv : Double,
  typ : Double,
  guess : Double,
) -> Double {
  let mut rate = guess
  let mut iter = 0
  let mut is_close = false
  while iter < rate_max_iterations && !is_close {
    let t1 = @math.pow(rate + 1.0, nper)
    let t2 = @math.pow(rate + 1.0, nper - 1.0)
    let rt = rate * typ + 1.0
    let p0 = pmt * (t1 - 1.0)
    let f1 = fv + t1 * pv + p0 * rt / rate
    let n1 = nper * t2 * pv
    let n2 = p0 * rt / @math.pow(rate, 2.0)
    let f2 = n1 - n2
    let f3 = (nper * pmt * t2 * rt + p0 * typ) / rate
    let delta = f1 / (f2 + f3)
    if Double::abs(delta) < rate_precision {
      is_close = true
    }
    iter = iter + 1
    rate = rate - delta
  }
  rate
}

///|
fn rate_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() < 3 {
    return Error(formula_error_value)
  }
  if values.length() > 6 {
    return Error(formula_error_value)
  }
  let nper = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let pmt = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  let pv = match value_as_number(values[2]) {
    Ok(num) => num
    Err(err) => return err
  }
  let fv = if values.length() >= 4 {
    match value_as_number(values[3]) {
      Ok(num) => num
      Err(err) => return err
    }
  } else {
    0.0
  }
  let mut typ = 0.0
  if values.length() >= 5 {
    match value_as_number(values[4]) {
      Ok(num) => if num != 0.0 { typ = 1.0 }
      Err(err) => return err
    }
  }
  let guess = if values.length() == 6 {
    match value_as_number(values[5]) {
      Ok(num) => num
      Err(err) => return err
    }
  } else {
    0.1
  }
  let result = calc_rate(nper, pmt, pv, fv, typ, guess)
  number_or_num_error(round_significant_digits(result, 15))
}

///|
fn irr_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() < 1 {
    return Error(formula_error_value)
  }
  if values.length() > 2 {
    return Error(formula_error_value)
  }
  let list_values = flatten_values([values[0]])
  let guess = if values.length() == 2 {
    match value_as_number(values[1]) {
      Ok(num) => num
      Err(err) => return err
    }
  } else {
    0.1
  }
  let mut x1 = 0.0
  let mut x2 = guess
  let mut f1 = calc_npv(x1, list_values)
  let mut f2 = calc_npv(x2, list_values)
  for _ in 0..<max_financial_iterations {
    if f1 * f2 < 0.0 {
      break
    }
    if Double::abs(f1) < Double::abs(f2) {
      x1 = x1 + 1.6 * (x1 - x2)
      f1 = calc_npv(x1, list_values)
      continue
    }
    x2 = x2 + 1.6 * (x2 - x1)
    f2 = calc_npv(x2, list_values)
  }
  if f1 * f2 > 0.0 {
    return Error(formula_error_num)
  }
  let f = calc_npv(x1, list_values)
  let mut rtb = 0.0
  let mut dx = 0.0
  if f < 0.0 {
    rtb = x1
    dx = x2 - x1
  } else {
    rtb = x2
    dx = x1 - x2
  }
  let mut x_mid = rtb
  for _ in 0..<max_financial_iterations {
    dx = dx * 0.5
    x_mid = rtb + dx
    let f_mid = calc_npv(x_mid, list_values)
    if f_mid <= 0.0 {
      rtb = x_mid
    }
    if Double::abs(f_mid) < financial_precision ||
      Double::abs(dx) < financial_precision {
      break
    }
  }
  number_or_num_error(round_significant_digits(x_mid, 15))
}

///|
fn mirr_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 3 {
    return Error(formula_error_value)
  }
  let list_values = flatten_values([values[0]])
  let finance_rate = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  let reinvest_rate = match value_as_number(values[2]) {
    Ok(num) => num
    Err(err) => return err
  }
  let n = list_values.length()
  let fr = 1.0 + finance_rate
  let rr = 1.0 + reinvest_rate
  let mut npv_pos = 0.0
  let mut npv_neg = 0.0
  for idx in 0..<n {
    let value = value_as_number_financial(list_values[idx])
    if value >= 0.0 {
      npv_pos = npv_pos + value / @math.pow(rr, Double::from_int(idx))
    } else {
      npv_neg = npv_neg + value / @math.pow(fr, Double::from_int(idx))
    }
  }
  if npv_neg == 0.0 || npv_pos == 0.0 || reinvest_rate <= -1.0 {
    return Error(formula_error_div)
  }
  let result = @math.pow(
      -npv_pos * @math.pow(rr, Double::from_int(n)) / (npv_neg * rr),
      1.0 / (Double::from_int(n) - 1.0),
    ) -
    1.0
  number_or_num_error(round_significant_digits(result, 15))
}

///|
fn prepare_x_args(
  values : Array[FormulaValue],
  dates : Array[FormulaValue],
) -> Result[(Array[Double], Array[Double]), FormulaValue] {
  let value_args : Array[Double] = []
  for value in values {
    match value_as_number(value) {
      Ok(num) => value_args.push(num)
      Err(err) => return Err(err)
    }
  }
  if value_args.length() < 2 {
    return Err(Error(formula_error_num))
  }
  let date_args : Array[Double] = []
  let mut last_date = 0.0
  for date in dates {
    match normalize_scalar(date) {
      Empty => return Err(Error(formula_error_value))
      _ =>
        match value_as_number(date) {
          Ok(num) => {
            if num < last_date {
              return Err(Error(formula_error_value))
            }
            date_args.push(num)
            last_date = num
          }
          Err(err) => return Err(err)
        }
    }
  }
  if value_args.length() != date_args.length() {
    return Err(Error(formula_error_num))
  }
  Ok((value_args, date_args))
}

///|
fn xirr_part1(
  values : Array[Double],
  dates : Array[Double],
  rate : Double,
) -> Double {
  let r = rate + 1.0
  let mut result = values[0]
  let first_date = dates[0]
  for idx in 1..<values.length() {
    result = result +
      values[idx] / @math.pow(r, (dates[idx] - first_date) / 365.0)
  }
  result
}

///|
fn xirr_part2(
  values : Array[Double],
  dates : Array[Double],
  rate : Double,
) -> Double {
  let r = rate + 1.0
  let mut result = 0.0
  let first_date = dates[0]
  for idx in 1..<values.length() {
    let frac = (dates[idx] - first_date) / 365.0
    result = result - frac * values[idx] / @math.pow(r, frac + 1.0)
  }
  result
}

///|
fn xirr_compute(
  values : Array[Double],
  dates : Array[Double],
  guess : Double,
) -> FormulaValue {
  let mut has_positive = false
  let mut has_negative = false
  for value in values {
    if value > 0.0 {
      has_positive = true
    }
    if value < 0.0 {
      has_negative = true
    }
  }
  if !has_positive || !has_negative {
    return Error(formula_error_num)
  }
  let mut result = guess
  let mut count = 0
  let mut failed = false
  while true {
    let result_value = xirr_part1(values, dates, result)
    let new_rate = result - result_value / xirr_part2(values, dates, result)
    let eps_rate = Double::abs(new_rate - result)
    result = new_rate
    count = count + 1
    if eps_rate <= xirr_precision || Double::abs(result_value) <= xirr_precision {
      break
    }
    if count > xirr_max_iterations {
      failed = true
      break
    }
  }
  if failed || Double::is_nan(result) || Double::is_inf(result) {
    return Error(formula_error_num)
  }
  number_or_num_error(round_significant_digits(result, 15))
}

///|
fn xirr_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 2 && values.length() != 3 {
    return Error(formula_error_value)
  }
  let raw_values = flatten_values([values[0]])
  let raw_dates = flatten_values([values[1]])
  let (value_args, date_args) = match prepare_x_args(raw_values, raw_dates) {
    Ok(result) => result
    Err(err) => return err
  }
  let mut guess = 0.0
  if values.length() == 3 {
    match value_as_number(values[2]) {
      Ok(num) => {
        if num <= -1.0 {
          return Error(formula_error_value)
        }
        guess = num
      }
      Err(_) => return Error(formula_error_num)
    }
  }
  xirr_compute(value_args, date_args, guess)
}

///|
fn xnpv_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 3 {
    return Error(formula_error_value)
  }
  let rate = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  if rate <= 0.0 {
    return Error(formula_error_value)
  }
  let raw_values = flatten_values([values[1]])
  let raw_dates = flatten_values([values[2]])
  let (value_args, date_args) = match prepare_x_args(raw_values, raw_dates) {
    Ok(result) => result
    Err(err) => return err
  }
  let date1 = date_args[0]
  let mut result = 0.0
  for idx in 0..<value_args.length() {
    result = result +
      value_args[idx] / @math.pow(1.0 + rate, (date_args[idx] - date1) / 365.0)
  }
  number_or_num_error(round_significant_digits(result, 15))
}

///|
fn dollar_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() == 0 {
    return Error(formula_error_value)
  }
  if values.length() > 2 {
    return Error(formula_error_value)
  }
  let number = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let mut decimals = 2
  let mut rounded = number
  if values.length() == 2 {
    let decimals_value = match value_as_number(values[1]) {
      Ok(num) => num
      Err(err) => return err
    }
    if decimals_value >= 128.0 {
      return Error(formula_error_value)
    }
    let digits = Double::to_int(decimals_value)
    if digits < 0 {
      rounded = round_down_with_digits(number, digits)
      decimals = 0
    } else {
      decimals = digits
    }
  }
  let symbol = "$"
  let abs_value = abs_double(rounded)
  let formatted = format_fixed_number(abs_value, decimals, true, 1)
  if rounded < 0.0 {
    String("(\{symbol}\{formatted})")
  } else {
    String("\{symbol}\{formatted}")
  }
}

///|
fn dollar_fraction_values(
  name : String,
  values : ArrayView[FormulaValue],
) -> FormulaValue {
  if values.length() != 2 {
    return Error(formula_error_value)
  }
  let dollar = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let frac = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  if frac < 0.0 {
    return Error(formula_error_num)
  }
  if frac == 0.0 {
    return Error(formula_error_div)
  }
  let (_whole, cents_raw) = modf_double(dollar)
  let mut cents = cents_raw
  let exponent = Double::ceil(@math.log10(frac))
  if name == "DOLLARDE" {
    cents = cents / frac
    cents = cents * @math.pow(10.0, exponent)
  } else {
    cents = cents * frac
    cents = cents * @math.pow(10.0, -exponent)
  }
  let result = Double::floor(dollar) + cents
  number_or_num_error(round_significant_digits(result, 15))
}

///|
fn effect_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 2 {
    return Error(formula_error_value)
  }
  let rate = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let npery = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  if rate <= 0.0 || npery < 1.0 {
    return Error(formula_error_num)
  }
  let result = @math.pow(1.0 + rate / npery, npery) - 1.0
  number_or_num_error(round_significant_digits(result, 15))
}

///|
fn nominal_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 2 {
    return Error(formula_error_value)
  }
  let rate = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let npery = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  if rate <= 0.0 || npery < 1.0 {
    return Error(formula_error_num)
  }
  let result = npery * (@math.pow(rate + 1.0, 1.0 / npery) - 1.0)
  number_or_num_error(round_significant_digits(result, 15))
}

///|
fn nper_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() < 3 {
    return Error(formula_error_value)
  }
  if values.length() > 5 {
    return Error(formula_error_value)
  }
  let rate = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let pmt = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  let pv = match value_as_number(values[2]) {
    Ok(num) => num
    Err(err) => return err
  }
  let fv = if values.length() >= 4 {
    match value_as_number(values[3]) {
      Ok(num) => num
      Err(err) => return err
    }
  } else {
    0.0
  }
  let typ = if values.length() == 5 {
    match value_as_number(values[4]) {
      Ok(num) => num
      Err(err) => return err
    }
  } else {
    0.0
  }
  if typ != 0.0 && typ != 1.0 {
    return Error(formula_error_na)
  }
  if pmt == 0.0 {
    return Error(formula_error_num)
  }
  let result = if rate != 0.0 {
    let term = pmt * (1.0 + rate * typ) / rate
    @math.ln((term - fv) / (pv + term)) / @math.ln(1.0 + rate)
  } else {
    (-pv - fv) / pmt
  }
  number_or_num_error(round_significant_digits(result, 15))
}

///|
fn calc_pmt(
  rate : Double,
  nper : Double,
  pv : Double,
  fv : Double,
  typ : Double,
) -> Double {
  if rate != 0.0 {
    let factor = @math.pow(1.0 + rate, nper)
    (-fv - pv * factor) / (1.0 + rate * typ) / ((factor - 1.0) / rate)
  } else {
    (-pv - fv) / nper
  }
}

///|
fn pmt_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() < 3 {
    return Error(formula_error_value)
  }
  if values.length() > 5 {
    return Error(formula_error_value)
  }
  let rate = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let nper = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  let pv = match value_as_number(values[2]) {
    Ok(num) => num
    Err(err) => return err
  }
  let fv = if values.length() >= 4 {
    match value_as_number(values[3]) {
      Ok(num) => num
      Err(err) => return err
    }
  } else {
    0.0
  }
  let typ = if values.length() == 5 {
    match value_as_number(values[4]) {
      Ok(num) => num
      Err(err) => return err
    }
  } else {
    0.0
  }
  if typ != 0.0 && typ != 1.0 {
    return Error(formula_error_na)
  }
  let result = calc_pmt(rate, nper, pv, fv, typ)
  number_or_num_error(round_significant_digits(result, 15))
}

///|
fn calc_ipmt(
  typ : Double,
  per : Double,
  pmt : Double,
  pv : Double,
  rate : Double,
) -> (Double, Double) {
  let mut capital = pv
  let mut interest = 0.0
  let mut principal = 0.0
  let per_int = Double::to_int(per)
  let mut i = 1
  while i <= per_int {
    if typ != 0.0 && i == 1 {
      interest = 0.0
    } else {
      interest = -capital * rate
    }
    principal = pmt - interest
    capital = capital + principal
    i = i + 1
  }
  (interest, principal)
}

///|
fn ipmt_values(name : String, values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() < 4 {
    return Error(formula_error_value)
  }
  if values.length() > 6 {
    return Error(formula_error_value)
  }
  let rate = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let per = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  let nper = match value_as_number(values[2]) {
    Ok(num) => num
    Err(err) => return err
  }
  let pv = match value_as_number(values[3]) {
    Ok(num) => num
    Err(err) => return err
  }
  let fv = if values.length() >= 5 {
    match value_as_number(values[4]) {
      Ok(num) => num
      Err(err) => return err
    }
  } else {
    0.0
  }
  let typ = if values.length() == 6 {
    match value_as_number(values[5]) {
      Ok(num) => num
      Err(err) => return err
    }
  } else {
    0.0
  }
  if typ != 0.0 && typ != 1.0 {
    return Error(formula_error_na)
  }
  if per <= 0.0 || per > nper {
    return Error(formula_error_na)
  }
  let payment = calc_pmt(rate, nper, pv, fv, typ)
  let (interest, principal) = calc_ipmt(typ, per, payment, pv, rate)
  let value = if name == "IPMT" { interest } else { principal }
  number_or_num_error(round_significant_digits(value, 15))
}

///|
fn cumip_values(
  name : String,
  values : ArrayView[FormulaValue],
) -> FormulaValue {
  if values.length() != 6 {
    return Error(formula_error_value)
  }
  let rate = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let nper = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  let pv = match value_as_number(values[2]) {
    Ok(num) => num
    Err(err) => return err
  }
  let start = match value_as_number(values[3]) {
    Ok(num) => num
    Err(err) => return err
  }
  let end = match value_as_number(values[4]) {
    Ok(num) => num
    Err(err) => return err
  }
  let typ = match value_as_number(values[5]) {
    Ok(num) => num
    Err(err) => return err
  }
  if typ != 0.0 && typ != 1.0 {
    return Error(formula_error_na)
  }
  if start < 1.0 || start > end {
    return Error(formula_error_na)
  }
  let mut total = 0.0
  let mut per = start
  while per <= end {
    let args : Array[FormulaValue] = [
      Number(rate),
      Number(per),
      Number(nper),
      Number(pv),
      Number(0.0),
      Number(typ),
    ]
    let result = ipmt_values(
      if name == "CUMIPMT" {
        "IPMT"
      } else {
        "PPMT"
      },
      args,
    )
    match result {
      Number(num) => total = total + num
      Error(err) => return Error(err)
      _ => return Error(formula_error_value)
    }
    per = per + 1.0
  }
  number_or_num_error(round_significant_digits(total, 15))
}

///|
fn ispmt_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 4 {
    return Error(formula_error_value)
  }
  let rate = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let per = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  let nper = match value_as_number(values[2]) {
    Ok(num) => num
    Err(err) => return err
  }
  let pv = match value_as_number(values[3]) {
    Ok(num) => num
    Err(err) => return err
  }
  let mut pr = pv
  let payment = pv / nper
  let mut num = 0.0
  let per_int = Double::to_int(per)
  let nper_int = Double::to_int(nper)
  let mut i = 0
  while i <= per_int {
    num = rate * pr * -1.0
    pr = pr - payment
    if i == nper_int {
      num = 0.0
    }
    i = i + 1
  }
  number_or_num_error(round_significant_digits(num, 15))
}

///|
fn rri_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 3 {
    return Error(formula_error_value)
  }
  let nper = match value_as_number(values[0]) {
    Ok(num) => num
    Err(_) => return Error(formula_error_num)
  }
  let pv = match value_as_number(values[1]) {
    Ok(num) => num
    Err(_) => return Error(formula_error_num)
  }
  let fv = match value_as_number(values[2]) {
    Ok(num) => num
    Err(_) => return Error(formula_error_num)
  }
  if nper <= 0.0 || pv <= 0.0 || fv < 0.0 {
    return Error(formula_error_num)
  }
  let result = @math.pow(fv / pv, 1.0 / nper) - 1.0
  number_or_num_error(round_significant_digits(result, 15))
}

///|
fn sln_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 3 {
    return Error(formula_error_value)
  }
  let cost = match value_as_number(values[0]) {
    Ok(num) => num
    Err(_) => return Error(formula_error_num)
  }
  let salvage = match value_as_number(values[1]) {
    Ok(num) => num
    Err(_) => return Error(formula_error_num)
  }
  let life = match value_as_number(values[2]) {
    Ok(num) => num
    Err(_) => return Error(formula_error_num)
  }
  if life <= 0.0 {
    return Error(formula_error_num)
  }
  let result = (cost - salvage) / life
  number_or_num_error(round_significant_digits(result, 15))
}

///|
fn syd_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 4 {
    return Error(formula_error_value)
  }
  let cost = match value_as_number(values[0]) {
    Ok(num) => num
    Err(_) => return Error(formula_error_num)
  }
  let salvage = match value_as_number(values[1]) {
    Ok(num) => num
    Err(_) => return Error(formula_error_num)
  }
  let life = match value_as_number(values[2]) {
    Ok(num) => num
    Err(_) => return Error(formula_error_num)
  }
  let per = match value_as_number(values[3]) {
    Ok(num) => num
    Err(_) => return Error(formula_error_num)
  }
  if life <= 0.0 || per <= 0.0 {
    return Error(formula_error_num)
  }
  if per > life {
    return Error(formula_error_num)
  }
  let result = (cost - salvage) *
    (life - per + 1.0) *
    2.0 /
    (life * (life + 1.0))
  number_or_num_error(round_significant_digits(result, 15))
}

///|
fn db_args_invalid(
  cost : Double,
  salvage : Double,
  life : Double,
  period : Double,
) -> Bool {
  cost <= 0.0 || salvage / cost < 0.0 || life <= 0.0 || period < 1.0
}

///|
fn db_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() < 4 {
    return Error(formula_error_value)
  }
  if values.length() > 5 {
    return Error(formula_error_value)
  }
  let cost = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let salvage = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  let life = match value_as_number(values[2]) {
    Ok(num) => num
    Err(err) => return err
  }
  let period = match value_as_number(values[3]) {
    Ok(num) => num
    Err(err) => return err
  }
  let month = if values.length() == 5 {
    match value_as_number(values[4]) {
      Ok(num) => num
      Err(err) => return err
    }
  } else {
    12.0
  }
  if cost == 0.0 {
    return Number(0.0)
  }
  if db_args_invalid(cost, salvage, life, period) || month < 1.0 {
    return Error(formula_error_na)
  }
  let dr_raw = 1.0 - @math.pow(salvage / cost, 1.0 / life)
  let dr = Double::round(dr_raw * 1000.0) / 1000.0
  let mut pd = 0.0
  let mut depreciation = 0.0
  let period_int = Double::to_int(trunc_double(period))
  let life_limit = Double::to_int(trunc_double(life + 1.0))
  for per in 1..<=period_int {
    if per == 1 {
      depreciation = cost * dr * month / 12.0
    } else if per == life_limit {
      depreciation = (cost - pd) * dr * (12.0 - month) / 12.0
    } else {
      depreciation = (cost - pd) * dr
    }
    pd = pd + depreciation
  }
  number_or_num_error(round_significant_digits(depreciation, 15))
}

///|
fn ddb_double(
  cost : Double,
  salvage : Double,
  life : Double,
  period : Double,
  factor : Double,
) -> Double {
  let mut pd = 0.0
  let mut depreciation = 0.0
  let period_int = Double::to_int(trunc_double(period))
  for _ in 1..<=period_int {
    let term = (cost - pd) * (factor / life)
    let cap = cost - salvage - pd
    depreciation = if term < cap { term } else { cap }
    pd = pd + depreciation
  }
  depreciation
}

///|
fn ddb_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() < 4 {
    return Error(formula_error_value)
  }
  if values.length() > 5 {
    return Error(formula_error_value)
  }
  let cost = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let salvage = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  let life = match value_as_number(values[2]) {
    Ok(num) => num
    Err(err) => return err
  }
  let period = match value_as_number(values[3]) {
    Ok(num) => num
    Err(err) => return err
  }
  let factor = if values.length() == 5 {
    match value_as_number(values[4]) {
      Ok(num) => num
      Err(err) => return err
    }
  } else {
    2.0
  }
  if cost == 0.0 {
    return Number(0.0)
  }
  if db_args_invalid(cost, salvage, life, period) ||
    factor <= 0.0 ||
    period > life {
    return Error(formula_error_na)
  }
  let depreciation = ddb_double(cost, salvage, life, period, factor)
  number_or_num_error(round_significant_digits(depreciation, 15))
}

///|
fn prepare_vdb_args(values : ArrayView[FormulaValue]) -> FormulaValue {
  let cost = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  if cost < 0.0 {
    return Error(formula_error_num)
  }
  let salvage = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  if salvage < 0.0 {
    return Error(formula_error_num)
  }
  let life = match value_as_number(values[2]) {
    Ok(num) => num
    Err(err) => return err
  }
  if life <= 0.0 {
    return Error(formula_error_num)
  }
  let start_period = match value_as_number(values[3]) {
    Ok(num) => num
    Err(err) => return err
  }
  if start_period < 0.0 {
    return Error(formula_error_num)
  }
  let end_period = match value_as_number(values[4]) {
    Ok(num) => num
    Err(err) => return err
  }
  if start_period > end_period {
    return Error(formula_error_num)
  }
  if end_period > life {
    return Error(formula_error_num)
  }
  let factor = if values.length() > 5 {
    match value_as_number(values[5]) {
      Ok(num) => num
      Err(_) => return Error(formula_error_num)
    }
  } else {
    2.0
  }
  if factor < 0.0 {
    return Error(formula_error_value)
  }
  List([
    Number(cost),
    Number(salvage),
    Number(life),
    Number(start_period),
    Number(end_period),
    Number(factor),
  ])
}

///|
fn vdb_partial(
  cost : Double,
  salvage : Double,
  life : Double,
  life1 : Double,
  period : Double,
  factor : Double,
) -> Double {
  let end_int = Double::ceil(period)
  let mut cs = cost - salvage
  let mut now_sln = false
  let mut vdb_total = 0.0
  let mut ddb = 0.0
  let mut sln = 0.0
  let mut term = 0.0
  let mut i = 1.0
  while i <= end_int {
    if !now_sln {
      ddb = ddb_double(cost, salvage, life, i, factor)
      sln = cs / (life1 - i + 1.0)
      if sln > ddb && i != end_int {
        term = sln
        now_sln = true
      } else {
        term = ddb
        cs = cs - ddb
      }
    } else {
      term = sln
    }
    if i == end_int {
      term = term * (period + 1.0 - end_int)
    }
    vdb_total = vdb_total + term
    i = i + 1.0
  }
  vdb_total
}

///|
fn vdb_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() < 5 || values.length() > 7 {
    return Error(formula_error_value)
  }
  let prepared = prepare_vdb_args(values)
  let list = match prepared {
    List(items) => items
    Error(err) => return Error(err)
    _ => return Error(formula_error_value)
  }
  let cost = match list[0] {
    Number(num) => num
    _ => return Error(formula_error_value)
  }
  let salvage = match list[1] {
    Number(num) => num
    _ => return Error(formula_error_value)
  }
  let life = match list[2] {
    Number(num) => num
    _ => return Error(formula_error_value)
  }
  let start_period = match list[3] {
    Number(num) => num
    _ => return Error(formula_error_value)
  }
  let end_period = match list[4] {
    Number(num) => num
    _ => return Error(formula_error_value)
  }
  let factor = match list[5] {
    Number(num) => num
    _ => return Error(formula_error_value)
  }
  let no_switch = if values.length() > 6 {
    match value_as_bool(values[6]) {
      Ok(flag) => flag
      Err(_) => return Error(formula_error_num)
    }
  } else {
    false
  }
  let start_int = Double::floor(start_period)
  let end_int = Double::ceil(end_period)
  if no_switch {
    let mut vdb_total = 0.0
    let mut i = start_int + 1.0
    while i <= end_int {
      let mut term = ddb_double(cost, salvage, life, i, factor)
      if i == start_int + 1.0 {
        let upper = if end_period < start_int + 1.0 {
          end_period
        } else {
          start_int + 1.0
        }
        term = term * (upper - start_period)
      } else if i == end_int {
        term = term * (end_period + 1.0 - end_int)
      }
      vdb_total = vdb_total + term
      i = i + 1.0
    }
    return number_or_num_error(round_significant_digits(vdb_total, 15))
  }
  let adjusted_cost = cost -
    vdb_partial(cost, salvage, life, life, start_period, factor)
  let result = vdb_partial(
    adjusted_cost,
    salvage,
    life,
    life - start_period,
    end_period - start_period,
    factor,
  )
  number_or_num_error(round_significant_digits(result, 15))
}

///|
fn pduration_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 3 {
    return Error(formula_error_value)
  }
  let rate = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let pv = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  let fv = match value_as_number(values[2]) {
    Ok(num) => num
    Err(err) => return err
  }
  if rate <= 0.0 || pv <= 0.0 || fv <= 0.0 {
    return Error(formula_error_num)
  }
  let result = (@math.ln(fv) - @math.ln(pv)) / @math.ln(1.0 + rate)
  number_or_num_error(round_significant_digits(result, 15))
}

///|
fn accrint_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() < 6 || values.length() > 8 {
    return Error(formula_error_value)
  }
  let issue = match value_as_date_serial(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let settlement = match value_as_date_serial(values[2]) {
    Ok(num) => num
    Err(err) => return err
  }
  let rate = match value_as_number(values[3]) {
    Ok(num) => num
    Err(err) => return err
  }
  let par = match value_as_number(values[4]) {
    Ok(num) => num
    Err(err) => return err
  }
  let frequency = match value_as_number(values[5]) {
    Ok(num) => num
    Err(err) => return err
  }
  if !validate_frequency(frequency) {
    return Error(formula_error_num)
  }
  let basis = if values.length() >= 7 {
    match value_as_number(values[6]) {
      Ok(num) => Double::to_int(trunc_double(num))
      Err(err) => return err
    }
  } else {
    0
  }
  if values.length() == 8 {
    match value_as_bool(values[7]) {
      Ok(_) => ()
      Err(err) => return err
    }
  }
  let frac = match yearfrac_number(issue, settlement, basis) {
    Ok(num) => num
    Err(err) => return err
  }
  let result = par * rate * frac
  number_or_num_error(round_significant_digits(result, 15))
}

///|
fn accrintm_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 4 && values.length() != 5 {
    return Error(formula_error_value)
  }
  let issue = match value_as_date_serial(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let settlement = match value_as_date_serial(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  if settlement < issue {
    return Error(formula_error_num)
  }
  let rate = match value_as_number(values[2]) {
    Ok(num) => num
    Err(err) => return err
  }
  let par = match value_as_number(values[3]) {
    Ok(num) => num
    Err(err) => return err
  }
  if par <= 0.0 {
    return Error(formula_error_num)
  }
  let basis = if values.length() == 5 {
    match value_as_number(values[4]) {
      Ok(num) => Double::to_int(trunc_double(num))
      Err(err) => return err
    }
  } else {
    0
  }
  let frac = match yearfrac_number(issue, settlement, basis) {
    Ok(num) => num
    Err(err) => return err
  }
  let result = frac * rate * par
  number_or_num_error(round_significant_digits(result, 15))
}

///|
fn coupdaybs_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  let (settlement, maturity, frequency, basis) = match
    prepare_coupon_args(values) {
    Ok(args) => args
    Err(err) => return err
  }
  let result = match coupdaybs_value(settlement, maturity, frequency, basis) {
    Ok(num) => num
    Err(err) => return err
  }
  Number(result)
}

///|
fn coupdays_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  let (settlement, maturity, frequency, basis) = match
    prepare_coupon_args(values) {
    Ok(args) => args
    Err(err) => return err
  }
  let result = match coupdays_value(settlement, maturity, frequency, basis) {
    Ok(num) => num
    Err(err) => return err
  }
  Number(result)
}

///|
fn coupdaysnc_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  let (settlement, maturity, frequency, basis) = match
    prepare_coupon_args(values) {
    Ok(args) => args
    Err(err) => return err
  }
  let result = match coupdaysnc_value(settlement, maturity, frequency, basis) {
    Ok(num) => num
    Err(err) => return err
  }
  Number(result)
}

///|
fn coupncd_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  let (settlement, maturity, frequency, _basis) = match
    prepare_coupon_args(values) {
    Ok(args) => args
    Err(err) => return err
  }
  let result = match
    coupon_date_serial("COUPNCD", settlement, maturity, frequency) {
    Ok(serial) => serial
    Err(err) => return err
  }
  Number(result)
}

///|
fn coupnum_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  let (settlement, maturity, frequency, _basis) = match
    prepare_coupon_args(values) {
    Ok(args) => args
    Err(err) => return err
  }
  let result = match coupnum_value(settlement, maturity, frequency) {
    Ok(num) => num
    Err(err) => return err
  }
  Number(result)
}

///|
fn couppcd_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  let (settlement, maturity, frequency, _basis) = match
    prepare_coupon_args(values) {
    Ok(args) => args
    Err(err) => return err
  }
  let result = match
    coupon_date_serial("COUPPCD", settlement, maturity, frequency) {
    Ok(serial) => serial
    Err(err) => return err
  }
  Number(result)
}

///|
fn disc_intrate_values(
  name : String,
  values : ArrayView[FormulaValue],
) -> FormulaValue {
  if values.length() != 4 && values.length() != 5 {
    return Error(formula_error_value)
  }
  let settlement = match value_as_date_serial(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let maturity = match value_as_date_serial(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  if maturity <= settlement {
    return Error(formula_error_num)
  }
  let pr_investment = match value_as_number(values[2]) {
    Ok(num) => num
    Err(err) => return err
  }
  if pr_investment <= 0.0 {
    return Error(formula_error_num)
  }
  let redemption = match value_as_number(values[3]) {
    Ok(num) => num
    Err(err) => return err
  }
  if redemption <= 0.0 {
    return Error(formula_error_num)
  }
  let basis = if values.length() == 5 {
    match value_as_number(values[4]) {
      Ok(num) => Double::to_int(trunc_double(num))
      Err(err) => return err
    }
  } else {
    0
  }
  let frac = match yearfrac_number(settlement, maturity, basis) {
    Ok(num) => num
    Err(err) => return err
  }
  let result = if name == "INTRATE" {
    (redemption - pr_investment) / pr_investment / frac
  } else {
    (redemption - pr_investment) / redemption / frac
  }
  number_or_num_error(round_significant_digits(result, 15))
}

///|
fn received_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 4 && values.length() != 5 {
    return Error(formula_error_value)
  }
  let settlement = match value_as_date_serial(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let maturity = match value_as_date_serial(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  if maturity <= settlement {
    return Error(formula_error_num)
  }
  let investment = match value_as_number(values[2]) {
    Ok(num) => num
    Err(err) => return err
  }
  let discount = match value_as_number(values[3]) {
    Ok(num) => num
    Err(err) => return err
  }
  if discount <= 0.0 {
    return Error(formula_error_num)
  }
  let basis = if values.length() == 5 {
    match value_as_number(values[4]) {
      Ok(num) => Double::to_int(trunc_double(num))
      Err(_) => return Error(formula_error_num)
    }
  } else {
    0
  }
  let frac = match yearfrac_number(settlement, maturity, basis) {
    Ok(num) => num
    Err(err) => return err
  }
  let result = investment / (1.0 - discount * frac)
  number_or_num_error(round_significant_digits(result, 15))
}

///|
fn prepare_duration_args(
  values : ArrayView[FormulaValue],
) -> Result[(Double, Double, Double, Double, Double, Int), FormulaValue] {
  if values.length() != 5 && values.length() != 6 {
    return Err(Error(formula_error_value))
  }
  let settlement = match value_as_date_serial(values[0]) {
    Ok(num) => num
    Err(err) => return Err(err)
  }
  let maturity = match value_as_date_serial(values[1]) {
    Ok(num) => num
    Err(err) => return Err(err)
  }
  if settlement >= maturity {
    return Err(Error(formula_error_num))
  }
  let coupon = match value_as_number(values[2]) {
    Ok(num) => num
    Err(err) => return Err(err)
  }
  if coupon < 0.0 {
    return Err(Error(formula_error_num))
  }
  let yld = match value_as_number(values[3]) {
    Ok(num) => num
    Err(err) => return Err(err)
  }
  if yld < 0.0 {
    return Err(Error(formula_error_num))
  }
  let frequency = match value_as_number(values[4]) {
    Ok(num) => num
    Err(err) => return Err(err)
  }
  if !validate_frequency(frequency) {
    return Err(Error(formula_error_num))
  }
  let basis = if values.length() == 6 {
    match value_as_number(values[5]) {
      Ok(num) => Double::to_int(trunc_double(num))
      Err(err) => return Err(err)
    }
  } else {
    0
  }
  Ok((settlement, maturity, coupon, yld, frequency, basis))
}

///|
fn duration_calc(
  settlement : Double,
  maturity : Double,
  coupon : Double,
  yld : Double,
  frequency : Double,
  basis : Int,
) -> Result[Double, FormulaValue] {
  let frac = match yearfrac_number(settlement, maturity, basis) {
    Ok(num) => num
    Err(err) => return Err(err)
  }
  let coups = match coupnum_value(settlement, maturity, frequency) {
    Ok(num) => num
    Err(err) => return Err(err)
  }
  let coupon_cash = coupon * 100.0 / frequency
  let mut yld_factor = yld / frequency
  yld_factor = yld_factor + 1.0
  let diff = frac * frequency - coups
  let mut duration = 0.0
  let mut price = 0.0
  let coups_int = Double::to_int(trunc_double(coups))
  let mut t = 1
  while t < coups_int {
    let t_value = Double::from_int(t)
    let t_diff = t_value + diff
    let add = coupon_cash / @math.pow(yld_factor, t_diff)
    price = price + add
    duration = duration + t_diff * add
    t = t + 1
  }
  let add = (coupon_cash + 100.0) / @math.pow(yld_factor, coups + diff)
  price = price + add
  duration = duration + (coups + diff) * add
  Ok(duration / price / frequency)
}

///|
fn duration_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  let (settlement, maturity, coupon, yld, frequency, basis) = match
    prepare_duration_args(values) {
    Ok(args) => args
    Err(err) => return err
  }
  let result = match
    duration_calc(settlement, maturity, coupon, yld, frequency, basis) {
    Ok(num) => num
    Err(err) => return err
  }
  number_or_num_error(round_significant_digits(result, 15))
}

///|
fn mduration_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  let (settlement, maturity, coupon, yld, frequency, basis) = match
    prepare_duration_args(values) {
    Ok(args) => args
    Err(err) => return err
  }
  let duration = match
    duration_calc(settlement, maturity, coupon, yld, frequency, basis) {
    Ok(num) => num
    Err(err) => return err
  }
  let result = duration / (1.0 + yld / frequency)
  number_or_num_error(round_significant_digits(result, 15))
}

///|
fn price_value(
  settlement : Double,
  maturity : Double,
  rate : Double,
  yld : Double,
  redemption : Double,
  frequency : Double,
  basis : Int,
) -> Result[Double, FormulaValue] {
  if settlement >= maturity {
    return Err(Error(formula_error_num))
  }
  if basis < 0 || basis > 4 {
    return Err(Error(formula_error_num))
  }
  let e = match coupdays_value(settlement, maturity, frequency, basis) {
    Ok(num) => num
    Err(err) => return Err(err)
  }
  let dsc = match coupdaysnc_value(settlement, maturity, frequency, basis) {
    Ok(num) => num / e
    Err(err) => return Err(err)
  }
  let n = match coupnum_value(settlement, maturity, frequency) {
    Ok(num) => num
    Err(err) => return Err(err)
  }
  let a = match coupdaybs_value(settlement, maturity, frequency, basis) {
    Ok(num) => num
    Err(err) => return Err(err)
  }
  let rate_per = rate / frequency
  let yld_per = yld / frequency
  let mut result = 0.0
  if n > 1.0 {
    let p1 = 1.0 + yld_per
    result = redemption / @math.pow(p1, n - 1.0 + dsc)
    result = result - 100.0 * rate_per * a / e
    let t1 = 100.0 * rate_per
    let t2 = 1.0 + yld_per
    let n_int = Double::to_int(trunc_double(n))
    for k in 0..<n_int {
      let k_value = Double::from_int(k)
      result = result + t1 / @math.pow(t2, k_value + dsc)
    }
  } else {
    let dsc_value = e - a
    let t1 = 100.0 * rate_per + redemption
    let t2 = yld_per * (dsc_value / e) + 1.0
    let t3 = 100.0 * rate_per * (a / e)
    result = t1 / t2 - t3
  }
  Ok(result)
}

///|
fn yield_value(
  settlement : Double,
  maturity : Double,
  rate : Double,
  pr : Double,
  redemption : Double,
  frequency : Double,
  basis : Int,
) -> FormulaValue {
  if settlement >= maturity {
    return Error(formula_error_num)
  }
  let mut yield1 = 0.0
  let mut yield2 = 1.0
  let mut price1 = match
    price_value(
      settlement, maturity, rate, yield1, redemption, frequency, basis,
    ) {
    Ok(num) => num
    Err(err) => return err
  }
  let mut price2 = match
    price_value(
      settlement, maturity, rate, yield2, redemption, frequency, basis,
    ) {
    Ok(num) => num
    Err(err) => return err
  }
  let mut yield_n = (yield2 - yield1) * 0.5
  let mut price_n = 0.0
  let mut iter = 0
  while iter < 100 && price_n != pr {
    price_n = match
      price_value(
        settlement, maturity, rate, yield_n, redemption, frequency, basis,
      ) {
      Ok(num) => num
      Err(err) => return err
    }
    if pr == price1 {
      return number_or_num_error(round_significant_digits(yield1, 15))
    } else if pr == price2 {
      return number_or_num_error(round_significant_digits(yield2, 15))
    } else if pr == price_n {
      return number_or_num_error(round_significant_digits(yield_n, 15))
    } else if pr < price2 {
      yield2 = yield2 * 2.0
      price2 = match
        price_value(
          settlement, maturity, rate, yield2, redemption, frequency, basis,
        ) {
        Ok(num) => num
        Err(err) => return err
      }
      yield_n = (yield2 - yield1) * 0.5
    } else {
      if pr < price_n {
        yield1 = yield_n
        price1 = price_n
      } else {
        yield2 = yield_n
        price2 = price_n
      }
      let f1 = (yield2 - yield1) * ((pr - price2) / (price1 - price2))
      yield_n = yield2 - f1
    }
    iter = iter + 1
  }
  number_or_num_error(round_significant_digits(yield_n, 15))
}

///|
fn check_price_yield_args(
  name : String,
  rate : Double,
  pr_yld : Double,
  redemption : Double,
  frequency : Double,
) -> FormulaValue {
  if rate < 0.0 {
    return Error(formula_error_num)
  }
  if name == "PRICE" {
    if pr_yld < 0.0 || redemption <= 0.0 {
      return Error(formula_error_num)
    }
  } else if pr_yld <= 0.0 || redemption < 0.0 {
    return Error(formula_error_num)
  }
  if !validate_frequency(frequency) {
    return Error(formula_error_num)
  }
  Empty
}

///|
fn price_yield_values(
  name : String,
  values : ArrayView[FormulaValue],
) -> FormulaValue {
  if values.length() != 6 && values.length() != 7 {
    return Error(formula_error_value)
  }
  let settlement = match value_as_date_serial(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let maturity = match value_as_date_serial(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  let rate = match value_as_number(values[2]) {
    Ok(num) => num
    Err(err) => return err
  }
  let pr_yld = match value_as_number(values[3]) {
    Ok(num) => num
    Err(err) => return err
  }
  let redemption = match value_as_number(values[4]) {
    Ok(num) => num
    Err(err) => return err
  }
  let frequency = match value_as_number(values[5]) {
    Ok(num) => num
    Err(err) => return err
  }
  let check = check_price_yield_args(name, rate, pr_yld, redemption, frequency)
  match check {
    Empty => ()
    _ => return check
  }
  let basis = if values.length() == 7 {
    match value_as_number(values[6]) {
      Ok(num) => Double::to_int(trunc_double(num))
      Err(err) => return err
    }
  } else {
    0
  }
  if name == "PRICE" {
    let result = match
      price_value(
        settlement, maturity, rate, pr_yld, redemption, frequency, basis,
      ) {
      Ok(num) => num
      Err(err) => return err
    }
    return number_or_num_error(round_significant_digits(result, 15))
  }
  yield_value(settlement, maturity, rate, pr_yld, redemption, frequency, basis)
}

///|
fn pricedisc_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 4 && values.length() != 5 {
    return Error(formula_error_value)
  }
  let settlement = match value_as_date_serial(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let maturity = match value_as_date_serial(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  if maturity <= settlement {
    return Error(formula_error_num)
  }
  let discount = match value_as_number(values[2]) {
    Ok(num) => num
    Err(err) => return err
  }
  if discount <= 0.0 {
    return Error(formula_error_num)
  }
  let redemption = match value_as_number(values[3]) {
    Ok(num) => num
    Err(err) => return err
  }
  if redemption <= 0.0 {
    return Error(formula_error_num)
  }
  let basis = if values.length() == 5 {
    match value_as_number(values[4]) {
      Ok(num) => Double::to_int(trunc_double(num))
      Err(err) => return err
    }
  } else {
    0
  }
  let frac = match yearfrac_number(settlement, maturity, basis) {
    Ok(num) => num
    Err(err) => return err
  }
  let result = redemption * (1.0 - discount * frac)
  number_or_num_error(round_significant_digits(result, 15))
}

///|
fn pricemat_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 5 && values.length() != 6 {
    return Error(formula_error_value)
  }
  let settlement = match value_as_date_serial(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let maturity = match value_as_date_serial(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  let issue = match value_as_date_serial(values[2]) {
    Ok(num) => num
    Err(err) => return err
  }
  if settlement >= maturity {
    return Error(formula_error_num)
  }
  if issue >= settlement {
    return Error(formula_error_num)
  }
  let rate = match value_as_number(values[3]) {
    Ok(num) => num
    Err(err) => return err
  }
  if rate < 0.0 {
    return Error(formula_error_num)
  }
  let yld = match value_as_number(values[4]) {
    Ok(num) => num
    Err(err) => return err
  }
  if yld < 0.0 {
    return Error(formula_error_num)
  }
  let basis = if values.length() == 6 {
    match value_as_number(values[5]) {
      Ok(num) => Double::to_int(trunc_double(num))
      Err(err) => return err
    }
  } else {
    0
  }
  let dsm = match yearfrac_number(settlement, maturity, basis) {
    Ok(num) => num
    Err(err) => return err
  }
  let dis = match yearfrac_number(issue, settlement, basis) {
    Ok(num) => num
    Err(err) => return err
  }
  let dim = match yearfrac_number(issue, maturity, basis) {
    Ok(num) => num
    Err(err) => return err
  }
  let result = ((1.0 + dim * rate) / (1.0 + dsm * yld) - dis * rate) * 100.0
  number_or_num_error(round_significant_digits(result, 15))
}

///|
fn tbilleq_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 3 {
    return Error(formula_error_value)
  }
  let settlement = match value_as_date_serial(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let maturity = match value_as_date_serial(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  let dsm = maturity - settlement
  if dsm > 365.0 || maturity <= settlement {
    return Error(formula_error_num)
  }
  let discount = match value_as_number(values[2]) {
    Ok(num) => num
    Err(err) => return err
  }
  if discount <= 0.0 {
    return Error(formula_error_num)
  }
  let result = 365.0 * discount / (360.0 - discount * dsm)
  number_or_num_error(round_significant_digits(result, 15))
}

///|
fn tbillprice_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 3 {
    return Error(formula_error_value)
  }
  let settlement = match value_as_date_serial(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let maturity = match value_as_date_serial(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  let dsm = maturity - settlement
  if dsm > 365.0 || maturity <= settlement {
    return Error(formula_error_num)
  }
  let discount = match value_as_number(values[2]) {
    Ok(num) => num
    Err(err) => return err
  }
  if discount <= 0.0 {
    return Error(formula_error_num)
  }
  let result = 100.0 * (1.0 - discount * dsm / 360.0)
  number_or_num_error(round_significant_digits(result, 15))
}

///|
fn tbillyield_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 3 {
    return Error(formula_error_value)
  }
  let settlement = match value_as_date_serial(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let maturity = match value_as_date_serial(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  let dsm = maturity - settlement
  if dsm > 365.0 || maturity <= settlement {
    return Error(formula_error_num)
  }
  let pr = match value_as_number(values[2]) {
    Ok(num) => num
    Err(err) => return err
  }
  if pr <= 0.0 {
    return Error(formula_error_num)
  }
  let result = (100.0 - pr) / pr * (360.0 / dsm)
  number_or_num_error(round_significant_digits(result, 15))
}

///|
fn yielddisc_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 4 && values.length() != 5 {
    return Error(formula_error_value)
  }
  let settlement = match value_as_date_serial(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let maturity = match value_as_date_serial(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  let pr = match value_as_number(values[2]) {
    Ok(num) => num
    Err(err) => return err
  }
  if pr <= 0.0 {
    return Error(formula_error_num)
  }
  let redemption = match value_as_number(values[3]) {
    Ok(num) => num
    Err(err) => return err
  }
  if redemption <= 0.0 {
    return Error(formula_error_num)
  }
  let basis = if values.length() == 5 {
    match value_as_number(values[4]) {
      Ok(num) => Double::to_int(trunc_double(num))
      Err(err) => return err
    }
  } else {
    0
  }
  let frac = match yearfrac_number(settlement, maturity, basis) {
    Ok(num) => num
    Err(err) => return err
  }
  let result = (redemption / pr - 1.0) / frac
  number_or_num_error(round_significant_digits(result, 15))
}

///|
fn yieldmat_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 5 && values.length() != 6 {
    return Error(formula_error_value)
  }
  let settlement = match value_as_date_serial(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let maturity = match value_as_date_serial(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  let issue = match value_as_date_serial(values[2]) {
    Ok(num) => num
    Err(err) => return err
  }
  if issue >= settlement {
    return Error(formula_error_num)
  }
  let rate = match value_as_number(values[3]) {
    Ok(num) => num
    Err(err) => return err
  }
  if rate < 0.0 {
    return Error(formula_error_num)
  }
  let pr = match value_as_number(values[4]) {
    Ok(num) => num
    Err(err) => return err
  }
  if pr <= 0.0 {
    return Error(formula_error_num)
  }
  let basis = if values.length() == 6 {
    match value_as_number(values[5]) {
      Ok(num) => Double::to_int(trunc_double(num))
      Err(err) => return err
    }
  } else {
    0
  }
  let dim = match yearfrac_number(issue, maturity, basis) {
    Ok(num) => num
    Err(err) => return err
  }
  let dis = match yearfrac_number(issue, settlement, basis) {
    Ok(num) => num
    Err(err) => return err
  }
  let dsm = match yearfrac_number(settlement, maturity, basis) {
    Ok(num) => num
    Err(err) => return err
  }
  let numerator = 1.0 + dim * rate
  let denominator = pr / 100.0 + dis * rate
  let result = (numerator / denominator - 1.0) / dsm
  number_or_num_error(round_significant_digits(result, 15))
}

///|
fn aggr_between(
  start_period : Double,
  end_period : Double,
  initial_value : Array[Double],
  f : (Array[Double], Double) -> Array[Double],
) -> Array[Double] {
  let mut value = initial_value
  let start_int = Double::to_int(trunc_double(start_period))
  let end_int = Double::to_int(trunc_double(end_period))
  if start_int <= end_int {
    let mut idx = start_int
    while idx <= end_int {
      value = f(value, Double::from_int(idx))
      idx = idx + 1
    }
  } else {
    let mut idx = start_int
    while idx >= end_int {
      value = f(value, Double::from_int(idx))
      if idx == end_int {
        break
      }
      idx = idx - 1
    }
  }
  value
}

///|
fn change_month_serial(
  serial : Double,
  num_months : Double,
  return_last_month : Bool,
) -> Double {
  let (year, month, day) = match date_parts_from_serial(serial) {
    Some(parts) => parts
    None => return serial
  }
  let mut offset_day = 0
  if return_last_month && day == days_in_month(year, month) {
    offset_day = -1
  }
  let (new_year, new_month, new_day) = normalize_date_parts(
    year,
    month + Double::to_int(trunc_double(num_months)),
    day + offset_day,
  )
  if return_last_month {
    let last_day = days_in_month(new_year, new_month)
    return match excel_serial_from_date(new_year, new_month, last_day) {
      Some(serial_value) => serial_value
      None => serial
    }
  }
  match excel_serial_from_date(new_year, new_month, new_day) {
    Some(serial_value) => serial_value
    None => serial
  }
}

///|
fn dates_aggregate(
  start_date : Double,
  end_date : Double,
  num_months : Double,
  f : (Double, Double) -> Double,
  acc : Double,
  return_last_month : Bool,
) -> (Double, Double, Double) {
  let mut front_date = start_date
  let mut trailing_date = end_date
  let mut stop = if num_months > 0.0 {
    front_date >= end_date
  } else {
    end_date >= front_date
  }
  let mut result = acc
  while !stop {
    trailing_date = front_date
    front_date = change_month_serial(front_date, num_months, return_last_month)
    result = result + f(front_date, trailing_date)
    stop = if num_months > 0.0 {
      front_date >= end_date
    } else {
      end_date >= front_date
    }
  }
  (front_date, trailing_date, result)
}

///|
fn coup_number(
  maturity : Double,
  settlement : Double,
  num_months : Double,
) -> Double {
  let (mat_year, mat_month, mat_day) = match date_parts_from_serial(maturity) {
    Some(parts) => parts
    None => return 0.0
  }
  let (settle_year, settle_month, settle_day) = match
    date_parts_from_serial(settlement) {
    Some(parts) => parts
    None => return 0.0
  }
  let end_of_month_temp = days_in_month(mat_year, mat_month) == mat_day
  let mut end_of_month = end_of_month_temp
  if !end_of_month_temp &&
    mat_month != 2 &&
    mat_day > 28 &&
    mat_day < days_in_month(mat_year, mat_month) {
    end_of_month = days_in_month(settle_year, settle_month) == settle_day
  }
  let start_date = change_month_serial(settlement, 0.0, end_of_month)
  let mut coupons = 0.0
  if start_date > settlement {
    coupons = coupons + 1.0
  }
  let date = change_month_serial(start_date, num_months, end_of_month)
  let f = fn(_pcd : Double, _ncd : Double) -> Double { 1.0 }
  let (_, _, result) = dates_aggregate(
    date, maturity, num_months, f, coupons, end_of_month,
  )
  result
}

///|
fn prepare_odd_yld_or_pr_arg(
  name : String,
  value : FormulaValue,
) -> Result[Double, FormulaValue] {
  let yld_or_pr = match value_as_number(value) {
    Ok(num) => num
    Err(err) => return Err(err)
  }
  if (name == "ODDFPRICE" || name == "ODDLPRICE") && yld_or_pr < 0.0 {
    return Err(Error(formula_error_num))
  }
  if (name == "ODDFYIELD" || name == "ODDLYIELD") && yld_or_pr <= 0.0 {
    return Err(Error(formula_error_num))
  }
  Ok(yld_or_pr)
}

///|
fn prepare_oddf_args(
  name : String,
  values : ArrayView[FormulaValue],
) -> Result[
  (Double, Double, Double, Double, Double, Double, Double, Double, Int),
  FormulaValue,
] {
  let settlement = match value_as_date_serial(values[0]) {
    Ok(num) => num
    Err(err) => return Err(err)
  }
  let maturity = match value_as_date_serial(values[1]) {
    Ok(num) => num
    Err(err) => return Err(err)
  }
  let issue = match value_as_date_serial(values[2]) {
    Ok(num) => num
    Err(err) => return Err(err)
  }
  let first_coupon = match value_as_date_serial(values[3]) {
    Ok(num) => num
    Err(err) => return Err(err)
  }
  if issue >= settlement {
    return Err(Error(formula_error_num))
  }
  if settlement >= first_coupon {
    return Err(Error(formula_error_num))
  }
  if first_coupon >= maturity {
    return Err(Error(formula_error_num))
  }
  let rate = match value_as_number(values[4]) {
    Ok(num) => num
    Err(err) => return Err(err)
  }
  if rate < 0.0 {
    return Err(Error(formula_error_num))
  }
  let yld_or_pr = match prepare_odd_yld_or_pr_arg(name, values[5]) {
    Ok(num) => num
    Err(err) => return Err(err)
  }
  let redemption = match value_as_number(values[6]) {
    Ok(num) => num
    Err(err) => return Err(err)
  }
  if redemption <= 0.0 {
    return Err(Error(formula_error_num))
  }
  let frequency = match value_as_number(values[7]) {
    Ok(num) => num
    Err(err) => return Err(err)
  }
  if !validate_frequency(frequency) {
    return Err(Error(formula_error_num))
  }
  let basis = if values.length() == 9 {
    match value_as_number(values[8]) {
      Ok(num) => Double::to_int(trunc_double(num))
      Err(err) => return Err(err)
    }
  } else {
    0
  }
  Ok(
    (
      settlement, maturity, issue, first_coupon, rate, yld_or_pr, redemption, frequency,
      basis,
    ),
  )
}

///|
fn oddfprice_calc(
  settlement : Double,
  maturity : Double,
  issue : Double,
  first_coupon : Double,
  rate : Double,
  yld : Double,
  redemption : Double,
  frequency : Double,
  basis : Int,
) -> Result[Double, FormulaValue] {
  if basis < 0 || basis > 4 {
    return Err(Error(formula_error_num))
  }
  let (mat_year, mat_month, mat_day) = match date_parts_from_serial(maturity) {
    Some(parts) => parts
    None => return Err(Error(formula_error_value))
  }
  let return_last_month = days_in_month(mat_year, mat_month) == mat_day
  let num_months = 12.0 / frequency
  let num_months_neg = -num_months
  let mat = change_month_serial(maturity, num_months_neg, return_last_month)
  let f = fn(_d1 : Double, _d2 : Double) -> Double { 0.0 }
  let (pcd, _, _) = dates_aggregate(
    mat, first_coupon, num_months_neg, f, 0.0, return_last_month,
  )
  if pcd != first_coupon {
    return Err(Error(formula_error_num))
  }
  let e = match coupdays_value(settlement, maturity, frequency, basis) {
    Ok(num) => num
    Err(err) => return Err(err)
  }
  let n = match coupnum_value(settlement, maturity, frequency) {
    Ok(num) => num
    Err(err) => return Err(err)
  }
  let dfc = coupdays_between(issue, first_coupon, basis)
  if dfc < e {
    let dsc = coupdays_between(settlement, first_coupon, basis)
    let a = coupdays_between(issue, settlement, basis)
    let x = yld / frequency + 1.0
    let y = dsc / e
    let p3 = @math.pow(x, n - 1.0 + y)
    let term1 = redemption / p3
    let term2 = 100.0 * rate / frequency * dfc / e / @math.pow(x, y)
    let term3 = aggr_between(2.0, Double::floor(n), [0.0], fn(
      acc : Array[Double],
      index : Double,
    ) -> Array[Double] {
      [acc[0] + 100.0 * rate / frequency / @math.pow(x, index - 1.0 + y)]
    })
    let term4 = a / e * (rate / frequency) * 100.0
    return Ok(term1 + term2 + term3[0] - term4)
  }
  let nc = match coupnum_value(issue, first_coupon, frequency) {
    Ok(num) => num
    Err(err) => return Err(err)
  }
  let mut last_coupon = first_coupon
  let ag = aggr_between(Double::floor(nc), 1.0, [0.0, 0.0], fn(
    acc : Array[Double],
    index : Double,
  ) -> Array[Double] {
    let (last_year, last_month, last_day) = match
      date_parts_from_serial(last_coupon) {
      Some(parts) => parts
      None => return acc
    }
    let (early_year, early_month, early_day) = normalize_date_parts(
      last_year,
      last_month + Double::to_int(trunc_double(num_months_neg)),
      last_day,
    )
    let early_coupon = match
      excel_serial_from_date(early_year, early_month, early_day) {
      Some(serial) => serial
      None => return acc
    }
    let mut nl = e
    if basis == 1 {
      nl = coupdays_between(early_coupon, last_coupon, basis)
    }
    let mut dci = coupdays_between(issue, last_coupon, basis)
    if index > 1.0 {
      dci = nl
    }
    let start_date = if issue > early_coupon { issue } else { early_coupon }
    let end_date = if settlement < last_coupon {
      settlement
    } else {
      last_coupon
    }
    let a = coupdays_between(start_date, end_date, basis)
    last_coupon = early_coupon
    let dcnl = acc[0] + dci / nl
    let anl = acc[1] + a / nl
    [dcnl, anl]
  })
  let dcnl = ag[0]
  let anl = ag[1]
  let dsc = if basis == 2 || basis == 3 {
    let ncd = match
      coupon_date_serial("COUPNCD", settlement, first_coupon, frequency) {
      Ok(serial) => serial
      Err(err) => return Err(err)
    }
    coupdays_between(settlement, ncd, basis)
  } else {
    let pcd = match
      coupon_date_serial("COUPPCD", settlement, first_coupon, frequency) {
      Ok(serial) => serial
      Err(err) => return Err(err)
    }
    let a = coupdays_between(pcd, settlement, basis)
    e - a
  }
  let nq = coup_number(first_coupon, settlement, num_months)
  let n_final = match coupnum_value(first_coupon, maturity, frequency) {
    Ok(num) => num
    Err(err) => return Err(err)
  }
  let x = yld / frequency + 1.0
  let y = dsc / e
  let p3 = @math.pow(x, y + nq + n_final)
  let term1 = redemption / p3
  let term2 = 100.0 * rate / frequency * dcnl / @math.pow(x, nq + y)
  let term3 = aggr_between(1.0, Double::floor(n_final), [0.0], fn(
    acc : Array[Double],
    index : Double,
  ) -> Array[Double] {
    [acc[0] + 100.0 * rate / frequency / @math.pow(x, index + nq + y)]
  })
  let term4 = 100.0 * rate / frequency * anl
  Ok(term1 + term2 + term3[0] - term4)
}

///|
fn oddfprice_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 8 && values.length() != 9 {
    return Error(formula_error_value)
  }
  let (
    settlement,
    maturity,
    issue,
    first_coupon,
    rate,
    yld,
    redemption,
    frequency,
    basis,
  ) = match prepare_oddf_args("ODDFPRICE", values) {
    Ok(args) => args
    Err(err) => return err
  }
  let result = match
    oddfprice_calc(
      settlement, maturity, issue, first_coupon, rate, yld, redemption, frequency,
      basis,
    ) {
    Ok(num) => num
    Err(err) => return err
  }
  number_or_num_error(round_significant_digits(result, 15))
}

///|
fn get_oddfprice(
  f : (Double) -> Double,
  x : Double,
  cnt : Double,
  prec : Double,
) -> Double {
  let max_cnt = 20.0
  let d = (f(x + prec) - f(x - prec)) / (2.0 * prec)
  let new_x = x - f(x) / d
  if Double::abs(new_x - x) < prec {
    new_x
  } else if cnt > max_cnt {
    new_x
  } else {
    get_oddfprice(f, new_x, cnt + 1.0, prec)
  }
}

///|
fn oddfyield_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 8 && values.length() != 9 {
    return Error(formula_error_value)
  }
  let (
    settlement,
    maturity,
    issue,
    first_coupon,
    rate,
    pr,
    redemption,
    frequency,
    basis,
  ) = match prepare_oddf_args("ODDFYIELD", values) {
    Ok(args) => args
    Err(err) => return err
  }
  if basis < 0 || basis > 4 {
    return Error(formula_error_num)
  }
  let years = coupdays_between(settlement, maturity, basis)
  let px = pr - 100.0
  let num = rate * years * 100.0 - px
  let denum = px / 4.0 + years * px / 2.0 + years * 100.0
  let guess = num / denum
  let f = fn(yld : Double) -> Double {
    match
      oddfprice_calc(
        settlement, maturity, issue, first_coupon, rate, yld, redemption, frequency,
        basis,
      ) {
      Ok(price) => pr - price
      Err(_) => 0.0 / 0.0
    }
  }
  let result = get_oddfprice(f, guess, 0.0, 1.0e-7)
  if Double::is_nan(result) || Double::is_inf(result) {
    Error(formula_error_num)
  } else {
    number_or_num_error(round_significant_digits(result, 15))
  }
}

///|
fn prepare_oddl_args(
  name : String,
  values : ArrayView[FormulaValue],
) -> Result[
  (Double, Double, Double, Double, Double, Double, Double, Int),
  FormulaValue,
] {
  let settlement = match value_as_date_serial(values[0]) {
    Ok(num) => num
    Err(err) => return Err(err)
  }
  let maturity = match value_as_date_serial(values[1]) {
    Ok(num) => num
    Err(err) => return Err(err)
  }
  let last_interest = match value_as_date_serial(values[2]) {
    Ok(num) => num
    Err(err) => return Err(err)
  }
  if last_interest >= settlement {
    return Err(Error(formula_error_num))
  }
  if settlement >= maturity {
    return Err(Error(formula_error_num))
  }
  let rate = match value_as_number(values[3]) {
    Ok(num) => num
    Err(err) => return Err(err)
  }
  if rate < 0.0 {
    return Err(Error(formula_error_num))
  }
  let yld_or_pr = match prepare_odd_yld_or_pr_arg(name, values[4]) {
    Ok(num) => num
    Err(err) => return Err(err)
  }
  let redemption = match value_as_number(values[5]) {
    Ok(num) => num
    Err(err) => return Err(err)
  }
  if redemption <= 0.0 {
    return Err(Error(formula_error_num))
  }
  let frequency = match value_as_number(values[6]) {
    Ok(num) => num
    Err(err) => return Err(err)
  }
  if !validate_frequency(frequency) {
    return Err(Error(formula_error_num))
  }
  let basis = if values.length() == 8 {
    match value_as_number(values[7]) {
      Ok(num) => Double::to_int(trunc_double(num))
      Err(err) => return Err(err)
    }
  } else {
    0
  }
  Ok(
    (
      settlement, maturity, last_interest, rate, yld_or_pr, redemption, frequency,
      basis,
    ),
  )
}

///|
fn oddl_values(name : String, values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 7 && values.length() != 8 {
    return Error(formula_error_value)
  }
  let (
    settlement,
    maturity,
    last_interest,
    rate,
    pr_or_yld,
    redemption,
    frequency,
    basis,
  ) = match prepare_oddl_args(name, values) {
    Ok(args) => args
    Err(err) => return err
  }
  if basis < 0 || basis > 4 {
    return Error(formula_error_num)
  }
  let num_months = 12.0 / frequency
  let nc = match coupnum_value(last_interest, maturity, frequency) {
    Ok(num) => num
    Err(err) => return err
  }
  let mut early_coupon = last_interest
  let ag = aggr_between(1.0, Double::floor(nc), [0.0, 0.0, 0.0], fn(
    acc : Array[Double],
    index : Double,
  ) -> Array[Double] {
    let late_coupon = change_month_serial(early_coupon, num_months, false)
    let nl = coupdays_between(early_coupon, late_coupon, basis)
    let mut dci = coupdays_between(early_coupon, maturity, basis)
    if index < nc {
      dci = nl
    }
    let mut a = 0.0
    if late_coupon < settlement {
      a = dci
    } else if early_coupon < settlement {
      a = coupdays_between(early_coupon, settlement, basis)
    }
    let start_date = if settlement > early_coupon {
      settlement
    } else {
      early_coupon
    }
    let end_date = if maturity < late_coupon { maturity } else { late_coupon }
    let dsc = coupdays_between(start_date, end_date, basis)
    early_coupon = late_coupon
    let dcnl = acc[0] + dci / nl
    let anl = acc[1] + a / nl
    let dscnl = acc[2] + dsc / nl
    [dcnl, anl, dscnl]
  })
  let dcnl = ag[0]
  let anl = ag[1]
  let dscnl = ag[2]
  let x = 100.0 * rate / frequency
  let term1 = dcnl * x + redemption
  if name == "ODDLPRICE" {
    let term2 = dscnl * pr_or_yld / frequency + 1.0
    let term3 = anl * x
    let result = term1 / term2 - term3
    return number_or_num_error(round_significant_digits(result, 15))
  }
  let term2 = anl * x + pr_or_yld
  let term3 = frequency / dscnl
  let result = (term1 - term2) / term2 * term3
  number_or_num_error(round_significant_digits(result, 15))
}

///|
