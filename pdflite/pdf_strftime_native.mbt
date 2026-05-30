///|
#borrow(output)
extern "C" fn pdf_current_time_ffi(output : FixedArray[Int]) -> Int = "pdflite_local_time"

///|
/// Return the current local time on the native target.
pub fn pdf_current_time() -> @date.PdfStrftimeTime raise @core.PdfError {
  let output = FixedArray::make(9, 0)
  if pdf_current_time_ffi(output) != 1 {
    raise BadDate
  }
  {
    tm_sec: output[0],
    tm_min: output[1],
    tm_hour: output[2],
    tm_mday: output[3],
    tm_mon: output[4],
    tm_year: output[5],
    tm_wday: output[6],
    tm_yday: output[7],
    tm_isdst: output[8] != 0,
  }
}

///|
/// Format `text` using cpdf's strftime subset.
///
/// When `time` is omitted, the native local time is used.
pub fn pdf_strftime(
  text : String,
  time? : @date.PdfStrftimeTime? = None,
) -> String raise @core.PdfError {
  let resolved = match time {
    Some(value) => value
    None => pdf_current_time()
  }
  @date.pdf_strftime_with_time(resolved, text)
}
