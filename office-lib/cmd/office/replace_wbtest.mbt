// The replace report budget, in isolation: the helper the preflight
// uses must refuse over-ceiling records with the typed code and pass
// records that fit.

///|
test "replace report budget refuses only over-ceiling records" {
  let small : Json = Json::object({ "note": Json::string("fits") })
  ensure_replace_report_budget(small, 4096)
  let mut text = "x"
  while text.length() < 2048 {
    text = text + text
  }
  let fat : Json = Json::object({ "note": Json::string(text) })
  try {
    ensure_replace_report_budget(fat, 1024)
    fail("expected the budget refusal")
  } catch {
    error => {
      let message = "\{error}"
      assert_true(
        message.contains("office.replace.report_too_large"),
        msg="got '" + message + "'",
      )
      assert_true(message.contains("nothing was written"))
    }
  }
}
