///|
test "excel date to time 1900" {
  let t0 = excel_date_to_time(1.0)
  debug_inspect(
    (t0.year(), t0.month(), t0.day(), t0.hour(), t0.minute(), t0.second()),
    content="(1900, 1, 1, 0, 0, 0)",
  )
  let t1 = excel_date_to_time(1.5)
  debug_inspect(
    (t1.year(), t1.month(), t1.day(), t1.hour(), t1.minute(), t1.second()),
    content="(1900, 1, 1, 12, 0, 0)",
  )
}

///|
test "excel date to time 1904" {
  let t0 = excel_date_to_time(0.0, use_1904_format=true)
  debug_inspect(
    (t0.year(), t0.month(), t0.day(), t0.hour(), t0.minute(), t0.second()),
    content="(1904, 1, 1, 0, 0, 0)",
  )
  let t1 = excel_date_to_time(1.25, use_1904_format=true)
  debug_inspect(
    (t1.year(), t1.month(), t1.day(), t1.hour(), t1.minute(), t1.second()),
    content="(1904, 1, 2, 6, 0, 0)",
  )

  // Crosses month boundary via `add_days_to_date`.
  let t2 = excel_date_to_time(40.0, use_1904_format=true)
  debug_inspect(
    (t2.year(), t2.month(), t2.day(), t2.hour(), t2.minute(), t2.second()),
    content="(1904, 2, 10, 0, 0, 0)",
  )

  // Rounds up to 86400 seconds -> adds a day.
  let t3 = excel_date_to_time(0.9999999, use_1904_format=true)
  debug_inspect(
    (t3.year(), t3.month(), t3.day(), t3.hour(), t3.minute(), t3.second()),
    content="(1904, 1, 2, 0, 0, 0)",
  )

  // Crosses year boundary via `add_days_to_date` month rollover.
  let t4 = excel_date_to_time(366.0, use_1904_format=true)
  debug_inspect(
    (t4.year(), t4.month(), t4.day(), t4.hour(), t4.minute(), t4.second()),
    content="(1905, 1, 1, 0, 0, 0)",
  )
}

///|
test "excel date to time invalid" {
  let result : Result[@time.ZonedDateTime, Error] = Ok(excel_date_to_time(-1.0)) catch {
    e => Err(e)
  }
  inspect(result is Err(_), content="true")
}

///|
test "excel date to time 1900 leap-year bug day 60" {
  // Day 60 is the Excel 1900 leap-year bug (1900-02-29), which is not a real
  // calendar date. Our `excel_date_to_time` rejects it.
  let result : Result[@time.ZonedDateTime, Error] = Ok(excel_date_to_time(60.0)) catch {
    e => Err(e)
  }
  inspect(result is Err(_), content="true")
}
