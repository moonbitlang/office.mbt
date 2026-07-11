// White-box pins for the lexical `w:date` validator: the accepted
// xsd:dateTime subset and, one by one, every rejection class.

///|
fn expect_date(date : String, ok~ : Bool) -> Unit raise {
  let valid = try {
    check_comment_date(date)
    true
  } catch {
    _ => false
  }
  if valid != ok {
    fail("date '\{date}': expected ok=\{ok}, got \{valid}")
  }
}

///|
test "comment dates: the accepted xsd:dateTime subset" {
  for
    date in (
      [
        "2026-07-11T09:30:00", "2026-07-11T09:30:00Z", "2026-07-11T09:30:00.5", "2026-07-11T09:30:00.123456Z",
        "2026-07-11T09:30:00+05:30", "2026-07-11T09:30:00-14:00", "2026-07-11T00:00:00+00:00",
        "2024-02-29T23:59:59Z", // leap year
         "2000-02-29T00:00:00Z", // %400 leap year
         "0001-01-01T00:00:00Z", "2026-07-11T24:00:00", // XSD end-of-day
         "2026-07-11T24:00:00.000Z", // end-of-day with zero fraction+zone
         "12345-01-01T00:00:00Z", // years may exceed four digits
         "-0001-02-28T12:00:00", // negative (astronomical) years
         "-0004-02-29T00:00:00", // ...with the leap rule on the digits
      ] : ReadOnlyArray[String]) {
    expect_date(date, ok=true)
  }
  for
    date in (
      [
        "", "2026-07-11", // date only
         "2026-07-11 09:30:00", // space instead of T
         "2026-7-11T09:30:00", // 1-digit month
         "26-07-11T09:30:00", // 2-digit year
         "0000-01-01T00:00:00Z", // xsd 1.0 has no year 0000
         "2026-13-01T00:00:00", "2026-00-10T00:00:00", "2026-04-31T00:00:00", // April has 30 days
         "2026-02-29T00:00:00", // not a leap year
         "1900-02-29T00:00:00", // %100 non-leap
         "2100-02-29T00:00:00", "2026-07-11T25:00:00", // hour past end-of-day
         "2026-07-11T24:00:01", // hour 24 demands zero seconds
         "2026-07-11T24:01:00", // ...and zero minutes
         "2026-07-11T24:00:00.5", // ...and a zero fraction
         "012345-01-01T00:00:00Z", // no leading zero past four digits
         "-0000-01-01T00:00:00", // negative zero year is still year 0000
         "123-01-01T00:00:00", // years need at least four digits
         "2026-07-11T09:60:00", "2026-07-11T09:30:60", "2026-07-11T09:30:00.", // fraction with no digits
         "2026-07-11T09:30:00.5X", // junk after the fraction
         "2026-07-11T09:30:00X", // junk instead of a zone
         "2026-07-11T09:30:00+15:00", // beyond +-14:00
         "2026-07-11T09:30:00+14:30", "2026-07-11T09:30:00+05:3", // 1-digit zone minutes
         "2026-07-11T09:30:00+0530", // missing zone colon
         "2026-07-11T09:30:00Zz", // junk after the zone
      ] : ReadOnlyArray[String]) {
    expect_date(date, ok=false)
  }
}
