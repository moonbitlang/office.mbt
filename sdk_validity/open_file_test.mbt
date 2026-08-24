// The two `open_file` wrappers are the only root-package tests that touch the
// filesystem. They live here rather than beside the rest of the e2e suite
// because they are native-only, and the package they came from compiles for js
// as well -- which is what made their `moonbitlang/async/fs` import look
// unused there.

///|
#cfg(target="native")
async test "mbtexcel open_file wrapper" {
  let workbook = @mbtexcel.new_workbook()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.set_cell("Sheet1", "C3", "file")
  let bytes = @mbtexcel.write(workbook)
  let stamp = @env.now().to_string()
  let path = "mbtexcel_open_file_\{stamp}.xlsx"
  @async/fs.write_file(
    path,
    bytes,
    create_mode=CreateOrTruncate,
    permission=0o644,
  ) catch {
    err => fail("write file failed: \{err}")
  }
  let parsed = @mbtexcel.open_file(path)
  debug_inspect(parsed.get_cell("Sheet1", "C3"), content="Some(\"file\")")
  @async/fs.remove(path) catch {
    err => fail("remove file failed: \{err}")
  }
}

///|
#cfg(target="native")
async test "mbtexcel open_file wrapper with transcoder branch" {
  let workbook = @mbtexcel.new_workbook()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.set_cell("Sheet1", "C3", "file")
  let bytes = @mbtexcel.write(workbook)
  let stamp = @env.now().to_string()
  let path = "mbtexcel_open_file_transcoder_\{stamp}.xlsx"
  @async/fs.write_file(
    path,
    bytes,
    create_mode=CreateOrTruncate,
    permission=0o644,
  ) catch {
    err => fail("write file failed: \{err}")
  }
  let parsed = @mbtexcel.open_file(path, transcoder=fn(
    _charset : String,
    b : Bytes,
  ) -> String {
    @encoding/utf8.decode(b) catch {
      _ => ""
    }
  })
  debug_inspect(parsed.get_cell("Sheet1", "C3"), content="Some(\"file\")")
  @async/fs.remove(path) catch {
    err => fail("remove file failed: \{err}")
  }
}
