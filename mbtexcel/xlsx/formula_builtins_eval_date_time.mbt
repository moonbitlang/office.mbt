///|
fn eval_date(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0, v1, v2] =>
      match (value_as_int(v0), value_as_int(v1), value_as_int(v2)) {
        (Ok(year), Ok(month), Ok(day)) =>
          match
            excel_serial_from_date(
              year,
              month,
              day,
              use_1904_dates=call.ctx.use_1904_dates,
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
fn eval_time(call : EvalCall) -> FormulaValue {
  match call.values {
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
fn eval_datevalue(call : EvalCall) -> FormulaValue {
  match call.values {
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
              use_1904_dates=call.ctx.use_1904_dates,
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
fn eval_timevalue(call : EvalCall) -> FormulaValue {
  match call.values {
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
fn eval_datedif(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0, v1, v2] => {
      let start_serial = match
        value_as_date_serial(v0, use_1904_dates=call.ctx.use_1904_dates) {
        Ok(value) => value
        Err(err) => return err
      }
      let end_serial = match
        value_as_date_serial(v1, use_1904_dates=call.ctx.use_1904_dates) {
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
            use_1904_dates=call.ctx.use_1904_dates,
          ) {
          Some(parts) => parts
          None => return Error(formula_error_num)
        }
        let (ey, em, ed) = match
          date_parts_from_serial(
            end_serial,
            use_1904_dates=call.ctx.use_1904_dates,
          ) {
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
              use_1904_dates=call.ctx.use_1904_dates,
            ).unwrap()
            let end_base = excel_serial_from_date(
              target_year,
              em,
              ed,
              use_1904_dates=call.ctx.use_1904_dates,
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
fn eval_days(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0, v1] => {
      let end_serial = match
        value_as_date_serial(v0, use_1904_dates=call.ctx.use_1904_dates) {
        Ok(value) => value
        Err(err) => return err
      }
      let start_serial = match
        value_as_date_serial(v1, use_1904_dates=call.ctx.use_1904_dates) {
        Ok(value) => value
        Err(err) => return err
      }
      Number(end_serial - start_serial)
    }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_days360(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0, v1] | [v0, v1, _] => {
      let start_serial = match
        value_as_date_serial(v0, use_1904_dates=call.ctx.use_1904_dates) {
        Ok(value) => value
        Err(err) => return err
      }
      let end_serial = match
        value_as_date_serial(v1, use_1904_dates=call.ctx.use_1904_dates) {
        Ok(value) => value
        Err(err) => return err
      }
      let (sy, sm, sd) = match
        date_parts_from_serial(
          start_serial,
          use_1904_dates=call.ctx.use_1904_dates,
        ) {
        Some(parts) => parts
        None => return Error(formula_error_num)
      }
      let (ey, em, ed) = match
        date_parts_from_serial(
          end_serial,
          use_1904_dates=call.ctx.use_1904_dates,
        ) {
        Some(parts) => parts
        None => return Error(formula_error_num)
      }
      let mut start_day = sd
      let mut end_day = ed
      let end_year = ey
      let mut end_month = em
      let use_european = if call.values is [_, _, v2] {
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
fn eval_isoweeknum(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] => {
      let serial = match
        value_as_date_serial(v0, use_1904_dates=call.ctx.use_1904_dates) {
        Ok(value) => value
        Err(err) => return err
      }
      // Serial zero is the 1900 system's artificial day before its epoch,
      // but is the real 1904-01-01 epoch in a date-1904 workbook.
      if !call.ctx.use_1904_dates && serial < 1.0 {
        return Error(formula_error_num)
      }
      // Excel assigns the fictitious 1900-02-29 (including its time
      // fraction) to ISO week 9. It cannot pass through the Gregorian helper
      // below because 1900 was not actually a leap year.
      if is_1900_phantom_date_serial(serial, call.ctx.use_1904_dates) {
        return Number(9.0)
      }
      let (year, month, day) = match
        date_parts_from_serial(serial, use_1904_dates=call.ctx.use_1904_dates) {
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
fn eval_edate(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0, v1] => {
      let (year, month, day) = match
        date_parts_from_value(v0, use_1904_dates=call.ctx.use_1904_dates) {
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
          use_1904_dates=call.ctx.use_1904_dates,
        ) {
        Some(serial) => Number(serial)
        None => Error(formula_error_num)
      }
    }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_eomonth(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0, v1] => {
      let (year, month, _) = match
        date_parts_from_value(v0, use_1904_dates=call.ctx.use_1904_dates) {
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
          use_1904_dates=call.ctx.use_1904_dates,
        ) {
        Some(serial) => Number(serial)
        None => Error(formula_error_num)
      }
    }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_yearfrac(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0, v1] | [v0, v1, _] => {
      let start_serial = match
        value_as_date_serial(v0, use_1904_dates=call.ctx.use_1904_dates) {
        Ok(value) => value
        Err(err) => return err
      }
      let end_serial = match
        value_as_date_serial(v1, use_1904_dates=call.ctx.use_1904_dates) {
        Ok(value) => value
        Err(err) => return err
      }
      let basis = if call.values is [_, _, v2] {
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
        use_1904_dates=call.ctx.use_1904_dates,
      )
    }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_weekday(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] | [v0, _] => {
      let (year, month, day) = match
        date_parts_from_value(v0, use_1904_dates=call.ctx.use_1904_dates) {
        Ok(parts) => parts
        Err(err) => return err
      }
      let mut return_type = 1
      if call.values is [_, v1] {
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
fn eval_weeknum(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] | [v0, _] => {
      let (year, month, day) = match
        date_parts_from_value(v0, use_1904_dates=call.ctx.use_1904_dates) {
        Ok(parts) => parts
        Err(err) => return err
      }
      let mut return_type = 1
      if call.values is [_, v1] {
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
fn eval_networkdays(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0, v1] | [v0, v1, _] => {
      let start_serial = match
        value_as_date_serial(v0, use_1904_dates=call.ctx.use_1904_dates) {
        Ok(value) => value
        Err(err) => return err
      }
      let end_serial = match
        value_as_date_serial(v1, use_1904_dates=call.ctx.use_1904_dates) {
        Ok(value) => value
        Err(err) => return err
      }
      let holidays = if call.values is [_, _, v2] {
        collect_holidays(v2, use_1904_dates=call.ctx.use_1904_dates)
      } else {
        []
      }
      networkdays_intl_value(
        start_serial,
        end_serial,
        Number(1.0),
        holidays,
        use_1904_dates=call.ctx.use_1904_dates,
      )
    }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_networkdays_intl(call : EvalCall) -> FormulaValue {
  if call.values.length() >= 2 && call.values.length() <= 4 {
    let start_serial = match
      value_as_date_serial(
        call.values[0],
        use_1904_dates=call.ctx.use_1904_dates,
      ) {
      Ok(value) => value
      Err(err) => return err
    }
    let end_serial = match
      value_as_date_serial(
        call.values[1],
        use_1904_dates=call.ctx.use_1904_dates,
      ) {
      Ok(value) => value
      Err(err) => return err
    }
    let weekend_value = if call.values.length() >= 3 {
      call.values[2]
    } else {
      Number(1.0)
    }
    let holidays = if call.values.length() == 4 {
      collect_holidays(call.values[3], use_1904_dates=call.ctx.use_1904_dates)
    } else {
      []
    }
    networkdays_intl_value(
      start_serial,
      end_serial,
      weekend_value,
      holidays,
      use_1904_dates=call.ctx.use_1904_dates,
    )
  } else {
    Error(formula_error_value)
  }
}

///|
fn eval_workday(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0, v1] | [v0, v1, _] => {
      let start_serial = match
        value_as_date_serial(v0, use_1904_dates=call.ctx.use_1904_dates) {
        Ok(value) => value
        Err(err) => return err
      }
      let days = match value_as_number(v1) {
        Ok(num) => num
        Err(err) => return err
      }
      let holidays = if call.values is [_, _, v2] {
        collect_holidays(v2, use_1904_dates=call.ctx.use_1904_dates)
      } else {
        []
      }
      workday_intl_value(
        start_serial,
        days,
        Number(1.0),
        holidays,
        use_1904_dates=call.ctx.use_1904_dates,
      )
    }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_workday_intl(call : EvalCall) -> FormulaValue {
  if call.values.length() >= 2 && call.values.length() <= 4 {
    let start_serial = match
      value_as_date_serial(
        call.values[0],
        use_1904_dates=call.ctx.use_1904_dates,
      ) {
      Ok(value) => value
      Err(err) => return err
    }
    let days = match value_as_number(call.values[1]) {
      Ok(num) => num
      Err(err) => return err
    }
    let weekend_value = if call.values.length() >= 3 {
      call.values[2]
    } else {
      Number(1.0)
    }
    let holidays = if call.values.length() == 4 {
      collect_holidays(call.values[3], use_1904_dates=call.ctx.use_1904_dates)
    } else {
      []
    }
    workday_intl_value(
      start_serial,
      days,
      weekend_value,
      holidays,
      use_1904_dates=call.ctx.use_1904_dates,
    )
  } else {
    Error(formula_error_value)
  }
}

///|
fn eval_now(call : EvalCall) -> FormulaValue {
  match call.values {
    [] => {
      let now_ms = @env.now()
      let total_seconds = UInt64::to_double(now_ms) / 1000.0
      let days = Double::floor(total_seconds / 86400.0)
      let seconds_in_day = total_seconds - days * 86400.0
      let epoch_serial = if call.ctx.use_1904_dates { 24107.0 } else { 25569.0 }
      let serial = days + epoch_serial + seconds_in_day / 86400.0
      Number(serial)
    }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_today(call : EvalCall) -> FormulaValue {
  match call.values {
    [] => {
      let now_ms = @env.now()
      let total_seconds = UInt64::to_double(now_ms) / 1000.0
      let days = Double::floor(total_seconds / 86400.0)
      let epoch_serial = if call.ctx.use_1904_dates { 24107.0 } else { 25569.0 }
      Number(days + epoch_serial)
    }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_year(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] =>
      match
        excel_serial_date_parts(v0, use_1904_dates=call.ctx.use_1904_dates) {
        Ok((year, _, _)) => Number(Double::from_int(year))
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_month(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] =>
      match
        excel_serial_date_parts(v0, use_1904_dates=call.ctx.use_1904_dates) {
        Ok((_, month, _)) => Number(Double::from_int(month))
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_day(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] =>
      match
        excel_serial_date_parts(v0, use_1904_dates=call.ctx.use_1904_dates) {
        Ok((_, _, day)) => Number(Double::from_int(day))
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_hour(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] =>
      match excel_serial_parts(v0, use_1904_dates=call.ctx.use_1904_dates) {
        Ok((_, _, _, hour, _, _)) => Number(Double::from_int(hour))
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_minute(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] =>
      match excel_serial_parts(v0, use_1904_dates=call.ctx.use_1904_dates) {
        Ok((_, _, _, _, minute, _)) => Number(Double::from_int(minute))
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}

///|
fn eval_second(call : EvalCall) -> FormulaValue {
  match call.values {
    [v0] =>
      match excel_serial_parts(v0, use_1904_dates=call.ctx.use_1904_dates) {
        Ok((_, _, _, _, _, second)) => Number(Double::from_int(second))
        Err(err) => err
      }
    _ => Error(formula_error_value)
  }
}
