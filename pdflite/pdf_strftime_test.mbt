///|
fn strftime_sample_time() -> @date.PdfStrftimeTime {
  {
    tm_sec: 5,
    tm_min: 4,
    tm_hour: 13,
    tm_mday: 3,
    tm_mon: 8,
    tm_year: 123,
    tm_wday: 0,
    tm_yday: 6,
    tm_isdst: false,
  }
}

///|
test "pdf_strftime_with_time formats cpdf supported fields" {
  let time = strftime_sample_time()
  @test.assert_eq(
    @date.pdf_strftime_with_time(
      time, "%a|%A|%b|%B|%d|%e|%H|%I|%j|%m|%M|%p|%S|%T|%u|%w|%Y|%%",
    ),
    "Sun|Sunday|Sep|September|03| 3|13|01|006|09|04|p.m|05|13:04:05|7|0|2023|%",
  )
}

///|
test "pdf_strftime_with_time preserves cpdf source quirks" {
  let dummy = @date.pdf_strftime_dummy_time()
  @test.assert_eq(@date.pdf_dummy, dummy)
  @test.assert_eq(
    @date.pdf_strftime_with_time(dummy, "%Y:%j:%I"),
    "3900:000:00",
  )
  @test.assert_eq(@date.pdf_strftime_with_time(dummy, "%s"), "%s")
  @test.assert_eq(@date.pdf_strftime_with_time(dummy, "%%Y"), "%3900")
}

///|
test "pdf_strftime_with_time reports fallback names for invalid fields" {
  let invalid = { ..strftime_sample_time(), tm_wday: 9, tm_mon: 99 }
  @test.assert_eq(
    @date.pdf_strftime_with_time(invalid, "%a|%A|%b|%B"),
    "str|strf_AFail|str|strf_Bfail",
  )
}
