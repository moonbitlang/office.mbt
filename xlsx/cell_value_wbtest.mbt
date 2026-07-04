///|
test "cell value wb: parse yes bool literal" {
  inspect(parse_cell_bool("yes"), content="true")
}

///|
test "cell value wb: invalid numeric raw parse raises InvalidXml" {
  let result : Result[CellValue, Error] = Ok(
    cell_value_from_raw(Number, "not-a-number"),
  ) catch {
    e => Err(e)
  }
  inspect(result is Err(XlsxError::InvalidXml(_)), content="true")
}
