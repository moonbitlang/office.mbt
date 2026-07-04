///|
/// Platform-independent time record used by cpdf-style strftime.
///
/// `tm_year` is years since 1900 and `tm_mon` is zero-based, matching C/Unix
/// `struct tm` and OCaml's `Unix.tm`.
pub(all) struct PdfStrftimeTime {
  tm_sec : Int
  tm_min : Int
  tm_hour : Int
  tm_mday : Int
  tm_mon : Int
  tm_year : Int
  tm_wday : Int
  tm_yday : Int
  tm_isdst : Bool
} derive(Debug, Eq, ToJson)

///|
/// Source-spelled cpdf dummy strftime time value.
pub let pdf_dummy : PdfStrftimeTime = {
  tm_sec: 0,
  tm_min: 0,
  tm_hour: 0,
  tm_mday: 1,
  tm_mon: 0,
  tm_year: 2000,
  tm_wday: 0,
  tm_yday: 0,
  tm_isdst: false,
}

///|
/// Dummy cpdf strftime time value.
pub fn pdf_strftime_dummy_time() -> PdfStrftimeTime {
  pdf_dummy
}

///|
fn pdf_strftime_weekday_full(time : PdfStrftimeTime) -> String {
  match time.tm_wday {
    0 => "Sunday"
    1 => "Monday"
    2 => "Tuesday"
    3 => "Wednesday"
    4 => "Thursday"
    5 => "Friday"
    6 => "Saturday"
    _ => "strf_AFail"
  }
}

///|
fn pdf_strftime_weekday_abbrev(time : PdfStrftimeTime) -> String {
  pdf_strftime_weekday_full(time).unsafe_substring(start=0, end=3)
}

///|
fn pdf_strftime_month_full(time : PdfStrftimeTime) -> String {
  match time.tm_mon {
    0 => "January"
    1 => "February"
    2 => "March"
    3 => "April"
    4 => "May"
    5 => "June"
    6 => "July"
    7 => "August"
    8 => "September"
    9 => "October"
    10 => "November"
    11 => "December"
    _ => "strf_Bfail"
  }
}

///|
fn pdf_strftime_month_abbrev(time : PdfStrftimeTime) -> String {
  pdf_strftime_month_full(time).unsafe_substring(start=0, end=3)
}

///|
fn pdf_strftime_pad2(value : Int, pad : String) -> String {
  let text = value.to_string()
  if text.length() == 1 {
    pad + text
  } else {
    text
  }
}

///|
fn pdf_strftime_pad3(value : Int) -> String {
  let text = value.to_string()
  match text.length() {
    1 => "00" + text
    2 => "0" + text
    _ => text
  }
}

///|
fn pdf_strftime_hour12(time : PdfStrftimeTime) -> String {
  pdf_strftime_pad2(time.tm_hour % 12, "0")
}

///|
fn pdf_strftime_ampm(time : PdfStrftimeTime) -> String {
  if time.tm_hour >= 12 {
    "p.m"
  } else {
    "a.m"
  }
}

///|
fn pdf_strftime_time(time : PdfStrftimeTime) -> String {
  pdf_strftime_pad2(time.tm_hour, "0") +
  ":" +
  pdf_strftime_pad2(time.tm_min, "0") +
  ":" +
  pdf_strftime_pad2(time.tm_sec, "0")
}

///|
fn pdf_strftime_weekday_monday_based(time : PdfStrftimeTime) -> String {
  match time.tm_wday {
    0 => "7"
    n => (n + 1).to_string()
  }
}

///|
fn pdf_strftime_year(time : PdfStrftimeTime) -> String {
  (time.tm_year + 1900).to_string()
}

///|
fn pdf_strftime_replace_all(
  text : String,
  old : String,
  new : String,
) -> String {
  let mut output = text
  while output.contains(old) {
    output = output.replace(old~, new~)
  }
  output
}

///|
fn pdf_strftime_replace_pair(
  text : String,
  time : PdfStrftimeTime,
  pair : (String, (PdfStrftimeTime) -> String),
) -> String {
  pdf_strftime_replace_all(text, pair.0, (pair.1)(time))
}

///|
let pdf_strftime_pairs : Array[(String, (PdfStrftimeTime) -> String)] = [
  ("%a", pdf_strftime_weekday_abbrev),
  ("%A", pdf_strftime_weekday_full),
  ("%b", pdf_strftime_month_abbrev),
  ("%B", pdf_strftime_month_full),
  ("%d", fn(time) { pdf_strftime_pad2(time.tm_mday, "0") }),
  ("%e", fn(time) { pdf_strftime_pad2(time.tm_mday, " ") }),
  ("%H", fn(time) { pdf_strftime_pad2(time.tm_hour, "0") }),
  ("%I", pdf_strftime_hour12),
  ("%j", fn(time) { pdf_strftime_pad3(time.tm_yday) }),
  ("%m", fn(time) { pdf_strftime_pad2(time.tm_mon + 1, "0") }),
  ("%M", fn(time) { pdf_strftime_pad2(time.tm_min, "0") }),
  ("%p", pdf_strftime_ampm),
  ("%S", fn(time) { pdf_strftime_pad2(time.tm_sec, "0") }),
  ("%T", pdf_strftime_time),
  ("%u", pdf_strftime_weekday_monday_based),
  ("%w", fn(time) { time.tm_wday.to_string() }),
  ("%Y", pdf_strftime_year),
  ("%%", fn(_) { "%" }),
]

///|
/// Format `text` using cpdf's C-style strftime subset and an explicit time.
///
/// This follows the OCaml implementation's replacement order and field
/// semantics, including zero-based `%j` and the absence of a `%s` replacement.
pub fn pdf_strftime_with_time(time : PdfStrftimeTime, text : String) -> String {
  let mut output = text
  for pair in pdf_strftime_pairs {
    output = pdf_strftime_replace_pair(output, time, pair)
  }
  output
}
