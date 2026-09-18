///|
test "excel date to time 1900" {
  let t0 = @xlsx.excel_date_to_time(1.0)
  debug_inspect(
    (t0.year(), t0.month(), t0.day(), t0.hour(), t0.minute(), t0.second()),
    content="(1900, 1, 1, 0, 0, 0)",
  )
  let t1 = @xlsx.excel_date_to_time(1.5)
  debug_inspect(
    (t1.year(), t1.month(), t1.day(), t1.hour(), t1.minute(), t1.second()),
    content="(1900, 1, 1, 12, 0, 0)",
  )
}

///|
test "excel date to time 1904" {
  let t0 = @xlsx.excel_date_to_time(0.0, use_1904_format=true)
  debug_inspect(
    (t0.year(), t0.month(), t0.day(), t0.hour(), t0.minute(), t0.second()),
    content="(1904, 1, 1, 0, 0, 0)",
  )
  let t1 = @xlsx.excel_date_to_time(1.25, use_1904_format=true)
  debug_inspect(
    (t1.year(), t1.month(), t1.day(), t1.hour(), t1.minute(), t1.second()),
    content="(1904, 1, 2, 6, 0, 0)",
  )

  // Crosses month boundary via `add_days_to_date`.
  let t2 = @xlsx.excel_date_to_time(40.0, use_1904_format=true)
  debug_inspect(
    (t2.year(), t2.month(), t2.day(), t2.hour(), t2.minute(), t2.second()),
    content="(1904, 2, 10, 0, 0, 0)",
  )

  // Rounds up to 86400 seconds -> adds a day.
  let t3 = @xlsx.excel_date_to_time(0.9999999, use_1904_format=true)
  debug_inspect(
    (t3.year(), t3.month(), t3.day(), t3.hour(), t3.minute(), t3.second()),
    content="(1904, 1, 2, 0, 0, 0)",
  )

  // Crosses year boundary via `add_days_to_date` month rollover.
  let t4 = @xlsx.excel_date_to_time(366.0, use_1904_format=true)
  debug_inspect(
    (t4.year(), t4.month(), t4.day(), t4.hour(), t4.minute(), t4.second()),
    content="(1905, 1, 1, 0, 0, 0)",
  )
}

///|
test "excel date to time invalid" {
  for
    value in [
      -1.0,
      2_958_465.9999999,
      2_958_466.0,
      2_000_000_000.0,
      2_147_483_647.0,
      1.0 / 0.0,
      0.0 / 0.0,
    ] {
    let result : Result[@time.ZonedDateTime, Error] = Ok(
      @xlsx.excel_date_to_time(value),
    ) catch {
      e => Err(e)
    }
    inspect(result is Err(_), content="true")
  }
  let latest = @xlsx.excel_date_to_time(2_958_465.0)
  debug_inspect(
    (latest.year(), latest.month(), latest.day()),
    content="(9999, 12, 31)",
  )
  let latest_1904 = @xlsx.excel_date_to_time(2_957_003.0, use_1904_format=true)
  debug_inspect(
    (latest_1904.year(), latest_1904.month(), latest_1904.day()),
    content="(9999, 12, 31)",
  )
  let after_1904 : Result[@time.ZonedDateTime, Error] = Ok(
    @xlsx.excel_date_to_time(2_957_004.0, use_1904_format=true),
  ) catch {
    error => Err(error)
  }
  inspect(after_1904 is Err(_), content="true")
  let spill_1904 : Result[@time.ZonedDateTime, Error] = Ok(
    @xlsx.excel_date_to_time(2_957_003.9999999, use_1904_format=true),
  ) catch {
    error => Err(error)
  }
  inspect(spill_1904 is Err(_), content="true")
}

///|
test "excel date to time 1900 leap-year bug day 60" {
  // Day 60 is the Excel 1900 leap-year bug (1900-02-29), which is not a real
  // calendar date. Our `excel_date_to_time` rejects it.
  let result : Result[@time.ZonedDateTime, Error] = Ok(
    @xlsx.excel_date_to_time(60.0),
  ) catch {
    e => Err(e)
  }
  inspect(result is Err(_), content="true")
}
