///|
test "excel date to time 1900" {
  let t0 = excel_date_to_time(1.0)
  inspect(
    (t0.year(), t0.month(), t0.day(), t0.hour(), t0.minute(), t0.second()),
    content="(1900, 1, 1, 0, 0, 0)",
  )
  let t1 = excel_date_to_time(1.5)
  inspect(
    (t1.year(), t1.month(), t1.day(), t1.hour(), t1.minute(), t1.second()),
    content="(1900, 1, 1, 12, 0, 0)",
  )
}

///|
test "excel date to time 1904" {
  let t0 = excel_date_to_time(0.0, use_1904_format=true)
  inspect(
    (t0.year(), t0.month(), t0.day(), t0.hour(), t0.minute(), t0.second()),
    content="(1904, 1, 1, 0, 0, 0)",
  )
  let t1 = excel_date_to_time(1.25, use_1904_format=true)
  inspect(
    (t1.year(), t1.month(), t1.day(), t1.hour(), t1.minute(), t1.second()),
    content="(1904, 1, 2, 6, 0, 0)",
  )
}

///|
test "excel date to time invalid" {
  let result : Result[@time.ZonedDateTime, Error] = try? excel_date_to_time(
    -1.0,
  )
  inspect(result is Err(_), content="true")
}
