///|
async test "open file and reader with password" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.set_cell("Sheet1", "A1", "secret")
  let bytes = write_with_password(workbook, "pass")
  let stamp = @env.now().to_string()
  let path = "mbtexcel_password_\{stamp}.xlsx"
  @async/fs.write_file(path, bytes, create=0o644) catch {
    err => fail("write file failed: \{err}")
  }
  let file = @async/fs.open(path, mode=@async/fs.Mode::ReadOnly) catch {
    err => fail("open file failed: \{err}")
  }
  let parsed = open_reader(file, password="pass")
  file.close()
  inspect(parsed.get_cell("Sheet1", "A1"), content="Some(\"secret\")")
  let parsed2 = open_file(path, password="pass")
  inspect(parsed2.get_cell("Sheet1", "A1"), content="Some(\"secret\")")
  @async/fs.remove(path) catch {
    err => fail("remove file failed: \{err}")
  }
}
