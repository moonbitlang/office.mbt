///|
async test "open file save and save_as" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.set_cell("Sheet1", "A1", "alpha")
  let stamp = @env.now().to_string()
  let path = "mbtexcel_io_\{stamp}.xlsx"
  workbook.save_as(path)
  let parsed = open_file(path)
  inspect(parsed.get_cell("Sheet1", "A1"), content="Some(\"alpha\")")
  parsed.set_cell("Sheet1", "A1", "beta")
  parsed.save()
  let parsed2 = open_file(path)
  inspect(parsed2.get_cell("Sheet1", "A1"), content="Some(\"beta\")")
  @async/fs.remove(path) catch {
    err => fail("remove file failed: \{err}")
  }
}

///|
test "write_to_buffer roundtrip" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.set_cell("Sheet1", "C3", "pipe")
  let bytes = workbook.write_to_buffer()
  let parsed = read(bytes)
  inspect(parsed.get_cell("Sheet1", "C3"), content="Some(\"pipe\")")
}
