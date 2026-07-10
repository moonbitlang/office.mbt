///|
#cfg(target="native")
async test "open file and reader with password" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.set_cell("Sheet1", "A1", "secret")
  let bytes = @xlsx.write_with_password(workbook, "pass")
  let stamp = @env.now().to_string()
  let path = "mbtexcel_password_\{stamp}.xlsx"
  @async/fs.write_file(
    path,
    bytes,
    create_mode=CreateOrTruncate,
    permission=0o644,
  ) catch {
    err => fail("write file failed: \{err}")
  }
  let file = @async/fs.open(path, mode=ReadOnly) catch {
    err => fail("open file failed: \{err}")
  }
  let parsed = @xlsx.open_reader(file, password="pass")
  file.close()
  debug_inspect(parsed.get_cell("Sheet1", "A1"), content="Some(\"secret\")")
  let parsed2 = @xlsx.open_file(path, password="pass")
  debug_inspect(parsed2.get_cell("Sheet1", "A1"), content="Some(\"secret\")")
  @async/fs.remove(path) catch {
    err => fail("remove file failed: \{err}")
  }
}

///|
#cfg(target="native")
async test "options password used for write_to_buffer and save_as" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.set_cell("Sheet1", "A1", "secret")
  let opts = @xlsx.Options::with_values(password="pass")
  let bytes = workbook.write_to_buffer(options=opts)
  let result : Result[@xlsx.Workbook, Error] = Ok(@xlsx.read(bytes)) catch {
    e => Err(e)
  }
  match result {
    Err(@xlsx.XlsxError::EncryptedPackage) => ()
    Err(_) => fail("expected encrypted package error")
    Ok(_) => fail("expected encrypted package error")
  }
  let parsed = @xlsx.read_with_password(bytes, "pass")
  debug_inspect(parsed.get_cell("Sheet1", "A1"), content="Some(\"secret\")")
  let stamp = @env.now().to_string()
  let path = "mbtexcel_password_opts_\{stamp}.xlsx"
  workbook.save_as(path, options=opts)
  let parsed2 = @xlsx.open_file(path, password="pass")
  debug_inspect(parsed2.get_cell("Sheet1", "A1"), content="Some(\"secret\")")
  @async/fs.remove(path) catch {
    err => fail("remove file failed: \{err}")
  }
}
