///|
fn build_non_utf8_workbook_bytes() -> Bytes raise {
  let workbook = @xlsx.Workbook::new()
  ignore(try! workbook.add_sheet("Sheet1"))
  try! workbook.set_cell("Sheet1", "A1", "alpha")
  let raw = try! @xlsx.write(workbook)
  let archive = @zip.read(raw) catch {
    err => fail("zip read failed: \{repr(err)}")
  }
  let updated = @zip.Archive::new()
  for entry in archive.entries() {
    let data = if entry.name() == "xl/workbook.xml" {
      let xml = @encoding/utf8.decode(entry.data()) catch {
        _ => fail("workbook.xml decode failed")
      }
      let updated_xml = xml.replace(
        old="encoding=\"UTF-8\"",
        new="encoding=\"ISO-8859-1\"",
      )
      @encoding/utf8.encode(updated_xml)
    } else {
      entry.data().to_owned()
    }
    updated.add(
      entry.name(),
      data,
      compression=entry.compression(),
      data_descriptor=entry.data_descriptor(),
    )
  }
  @zip.write(updated) catch {
    err => fail("zip write failed: \{repr(err)}")
  }
}

///|
test "read uses transcoder for non-utf8 xml" {
  let bytes = build_non_utf8_workbook_bytes()
  let called = @ref.new(false)
  fn transcode(
    _encoding : String,
    data : Bytes,
  ) -> String raise @xlsx.XlsxError {
    if _encoding.is_empty() {
      ignore(@xlsx.read(b""))
    }
    called.val = true
    @encoding/utf8.decode(data) catch {
      _ => ""
    }
  }

  let parsed = @xlsx.read(bytes, transcoder=transcode)
  guard called.val else { fail("transcoder not called") }
  debug_inspect(parsed.get_cell("Sheet1", "A1"), content="Some(\"alpha\")")
}

///|
async test "workbook read_zip_reader uses charset_transcoder" {
  let bytes = build_non_utf8_workbook_bytes()
  let called = @ref.new(false)
  fn transcode(
    _encoding : String,
    data : Bytes,
  ) -> String raise @xlsx.XlsxError {
    if _encoding.is_empty() {
      ignore(@xlsx.read(b""))
    }
    called.val = true
    @encoding/utf8.decode(data) catch {
      _ => ""
    }
  }

  let builder = @xlsx.Workbook::new().charset_transcoder(transcode)
  let (reader, writer) = @async/io.pipe()
  let parsed = @async.with_task_group(group => {
    group.spawn_bg(() => {
      defer writer.close()
      writer.write(bytes)
    })
    builder.read_zip_reader(reader)
  })
  guard called.val else { fail("transcoder not called") }
  debug_inspect(parsed.get_cell("Sheet1", "A1"), content="Some(\"alpha\")")
}

///|
test "read handles builtin charset without a transcoder" {
  // build_non_utf8_workbook_bytes declares ISO-8859-1, which the built-in
  // decoder now handles - no transcoder needed
  let bytes = build_non_utf8_workbook_bytes()
  let parsed = @xlsx.read(bytes)
  debug_inspect(
    parsed.get_cell("Sheet1", "A1"),
    content=(
      #|Some("alpha")
    ),
  )
}
