///|
test "stream wb: apply_row_opts rejects non-positive row" {
  let sheet = Worksheet::new("Sheet1")
  let opts = RowOpts::new()
  let result : Result[Unit, Error] = try? apply_row_opts(sheet, 0, opts)
  inspect(
    result,
    content=(
      #|Err(InvalidCellRef(value="0:0"))
    ),
  )
}
