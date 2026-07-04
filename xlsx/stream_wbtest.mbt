///|
test "stream wb: apply_row_opts rejects non-positive row" {
  let sheet = Worksheet::new("Sheet1")
  let opts = RowOpts::with_values()
  let result : Result[Unit, Error] = Ok(apply_row_opts(sheet, 0, opts)) catch {
    e => Err(e)
  }
  debug_inspect(
    result,
    content=(
      #|Err(InvalidCellRef(value="0:0"))
    ),
  )
}
