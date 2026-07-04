///|
let pdf_progress_enabled : Ref[Bool] = { val: false }

///|
let pdf_progress_fragments : Ref[Array[String]] = { val: [] }

///|
/// Return whether progress output capture is enabled.
pub fn pdf_progress() -> Bool {
  pdf_progress_enabled.val
}

///|
/// Enable or disable progress output capture.
pub fn pdf_set_progress(enabled : Bool) -> Unit {
  pdf_progress_enabled.val = enabled
}

///|
fn pdf_progress_emit(fragment : String) -> Unit {
  if pdf_progress_enabled.val {
    pdf_progress_fragments.val.push(fragment)
  }
}

///|
/// Clear captured progress output.
pub fn pdf_clear_progress_output() -> Unit {
  pdf_progress_fragments.val = []
}

///|
/// Return all captured progress output as one string.
pub fn pdf_progress_output() -> String {
  pdf_progress_fragments.val.join("")
}

///|
/// Emit a progress line followed by a newline when progress is enabled.
pub fn pdf_progress_line(text : String) -> Unit {
  pdf_progress_emit(text + "\n")
}

///|
/// Emit progress text without a trailing newline when progress is enabled.
pub fn pdf_progress_line_no_end(text : String) -> Unit {
  pdf_progress_emit(text)
}

///|
/// Emit a page number fragment when progress is enabled.
pub fn pdf_progress_page(page : Int) -> Unit {
  pdf_progress_emit(page.to_string())
}

///|
/// Emit an end-page progress marker when progress is enabled.
pub fn pdf_progress_endpage() -> Unit {
  pdf_progress_emit(".")
}

///|
/// Emit the final progress newline when progress is enabled.
pub fn pdf_progress_done() -> Unit {
  pdf_progress_emit("\n")
}
