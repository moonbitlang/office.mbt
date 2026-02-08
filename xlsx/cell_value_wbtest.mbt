///|
test "cell value wb: parse yes bool literal" {
  inspect(parse_cell_bool("yes"), content="true")
}

///|
test "cell value wb: invalid numeric raw parse raises InvalidXml" {
  let result : Result[CellValue, Error] = try? cell_value_from_raw(
    Number,
    "not-a-number",
  )
  inspect(result is Err(XlsxError::InvalidXml(_)), content="true")
}
