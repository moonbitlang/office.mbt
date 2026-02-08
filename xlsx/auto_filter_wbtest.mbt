///|
test "auto filter wb: parse_filter_tokens rejects non-3 token input" {
  let bad_tokens : Result[(Int, String), Error] = try? parse_filter_tokens([
    "x", "==",
  ])
  inspect(bad_tokens is Err(XlsxError::InvalidAutoFilter(_)), content="true")
}

///|
test "auto filter wb: custom_filter_operator equal and invalid branches" {
  inspect(custom_filter_operator(2), content="equal")
  let bad_op : Result[String, Error] = try? custom_filter_operator(99)
  inspect(bad_op is Err(XlsxError::InvalidAutoFilter(_)), content="true")
}
