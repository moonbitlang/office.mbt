///|
#cfg(target="native")
async test "excelize fixture encryptAES.xlsx opens with password" {
  let encrypted_bytes = @async/fs.read_file(
    "fixtures/excelize/test/encryptAES.xlsx",
  ) catch {
    err => fail("read file failed: \{err}")
  }
  let encrypted_bytes = encrypted_bytes.binary()
  let decrypted = @xlsx.decrypt(
    encrypted_bytes,
    options=@xlsx.Options::with_values(password="password"),
  )
  let archive = @zip.read(decrypted) catch {
    err => fail("zip read failed: \{repr(err)}")
  }
  let shared_strings_xml = match archive.get("xl/sharedStrings.xml") {
    Some(value) =>
      @encoding/utf8.decode(value) catch {
        _ => fail("sharedStrings.xml utf8 decode failed")
      }
    None => fail("missing sharedStrings.xml")
  }
  inspect(shared_strings_xml.contains("SECRET"), content="true")
  let workbook = @xlsx.open_file(
    "fixtures/excelize/test/encryptAES.xlsx",
    password="password",
  )
  debug_inspect(workbook.search_sheet("Sheet1", "SECRET"), content="[\"A1\"]")
  debug_inspect(
    workbook.get_cell_value("Sheet1", "A1"),
    content="Some(\"SECRET\")",
  )
}

///|
#cfg(target="native")
async test "excelize fixture encryptAES.xlsx wrong password errors" {
  let result : Result[@xlsx.Workbook, Error] = Ok(
    @xlsx.open_file("fixtures/excelize/test/encryptAES.xlsx", password="passwd"),
  ) catch {
    e => Err(e)
  }
  inspect(result is Err(@xlsx.XlsxError::InvalidPassword), content="true")
}
