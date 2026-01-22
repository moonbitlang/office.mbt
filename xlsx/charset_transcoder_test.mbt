///|
test "read uses transcoder for non-utf8 xml" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.set_cell("Sheet1", "A1", "alpha")
  let raw = write(workbook)
  let archive = @zip.read(raw) catch { err => fail("zip read failed: \{err}") }
  let updated = @zip.Archive::new()
  for entry in archive.entries() {
    let data = if entry.name == "xl/workbook.xml" {
      let xml = @encoding/utf8.decode(entry.data) catch {
        _ => fail("workbook.xml decode failed")
      }
      let updated_xml = xml.replace(
        old="encoding=\"UTF-8\"",
        new="encoding=\"ISO-8859-1\"",
      )
      @encoding/utf8.encode(updated_xml)
    } else {
      entry.data
    }
    updated.add(
      entry.name,
      data,
      compression=entry.compression,
      data_descriptor=entry.data_descriptor,
    )
  }
  let bytes = @zip.write(updated) catch {
    err => fail("zip write failed: \{err}")
  }
  let called = @ref.new(false)
  fn transcode(_encoding : String, data : Bytes) -> String raise XlsxError {
    if _encoding.is_empty() {
      ignore(read(b""))
    }
    called.val = true
    @encoding/utf8.decode(data) catch {
      _ => ""
    }
  }

  let parsed = read(bytes, transcoder=transcode)
  guard called.val else { fail("transcoder not called") }
  inspect(parsed.get_cell("Sheet1", "A1"), content="Some(\"alpha\")")
}
