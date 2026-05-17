///|
test "pdf_current_time returns native local time fields in tm ranges" {
  let time = try! @pdflite.pdf_current_time()
  @test.assert_eq(time.tm_sec >= 0 && time.tm_sec <= 60, true)
  @test.assert_eq(time.tm_min >= 0 && time.tm_min <= 59, true)
  @test.assert_eq(time.tm_hour >= 0 && time.tm_hour <= 23, true)
  @test.assert_eq(time.tm_mday >= 1 && time.tm_mday <= 31, true)
  @test.assert_eq(time.tm_mon >= 0 && time.tm_mon <= 11, true)
  @test.assert_eq(time.tm_wday >= 0 && time.tm_wday <= 6, true)
  @test.assert_eq(time.tm_yday >= 0 && time.tm_yday <= 365, true)
}

///|
test "pdf_strftime uses explicit time or native current time" {
  let time : @pdflite.PdfStrftimeTime = {
    tm_sec: 59,
    tm_min: 58,
    tm_hour: 23,
    tm_mday: 31,
    tm_mon: 11,
    tm_year: 124,
    tm_wday: 2,
    tm_yday: 365,
    tm_isdst: false,
  }
  @test.assert_eq(
    try! @pdflite.pdf_strftime("%Y-%m-%d %T", time=Some(time)),
    "2024-12-31 23:58:59",
  )
  @test.assert_eq((try! @pdflite.pdf_strftime("%Y")).length() >= 4, true)
}
