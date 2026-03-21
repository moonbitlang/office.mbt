///|
#cfg(target = "native")
async test "set sheet background from file" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let stamp = @env.now().to_string()
  let path = "mbtexcel_sheet_bg_\{stamp}.png"
  let bytes = Bytes::from_array([0x89, 0x50, 0x4e, 0x47])
  @async/fs.write_file(path, bytes, create=0o644) catch {
    err => fail("write file failed: \{err}")
  }
  workbook.set_sheet_background_from_file("Sheet1", path)
  let sheet = match workbook.sheet("Sheet1") {
    Some(value) => value
    None => fail("missing Sheet1")
  }
  let background = match sheet.sheet_background() {
    Some(value) => value
    None => fail("missing background")
  }
  inspect(background.extension, content="png")
  inspect(background.content_type, content="image/png")
  inspect(background.data.length(), content="4")
  @async/fs.remove(path) catch {
    err => fail("remove file failed: \{err}")
  }
}
