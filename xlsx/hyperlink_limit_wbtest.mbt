///|
test "hyperlink limit exceeded" {
  let sheet = Worksheet::new("Sheet1")
  let dummy : Hyperlink = {
    reference: "Z1",
    target: "",
    link_type: External,
    location: None,
    display: None,
    tooltip: None,
  }
  let many : Array[Hyperlink] = Array::make(65530, dummy)
  sheet.hyperlinks.append(many[:])
  let result : Result[Unit, Error] = try? sheet.set_cell_hyperlink(
    "A1",
    "https://example.com",
    External,
  )
  inspect(result is Err(HyperlinkLimitExceeded(_)), content="true")
}
