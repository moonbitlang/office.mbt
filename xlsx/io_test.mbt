///|
struct MemWriter {
  data : Array[Byte]
}

///|
fn MemWriter::new() -> MemWriter {
  { data: [] }
}

///|
async fn MemWriter::write_once(
  self : MemWriter,
  bytes : Bytes,
  offset~ : Int,
  len~ : Int,
) -> Int {
  let start = if offset < 0 { 0 } else { offset }
  let end = start + len
  let safe_end = if end > bytes.length() { bytes.length() } else { end }
  if safe_end < start {
    return 0
  }
  for value in bytes[start:safe_end] {
    self.data.push(value)
  }
  safe_end - start
}

///|
async fn MemWriter::write(self : MemWriter, data : &@async/io.Data) -> Unit {
  let bytes = data.binary()
  for value in bytes {
    self.data.push(value)
  }
}

///|
async fn MemWriter::write_reader(
  self : MemWriter,
  reader : &@async/io.Reader,
) -> Unit {
  while true {
    let chunk = reader.read_some()
    match chunk {
      Some(bytes) =>
        for value in bytes {
          self.data.push(value)
        }
      None => break
    }
  }
}

///|
impl @async/io.Writer for MemWriter with write_once(
  self : MemWriter,
  bytes : Bytes,
  offset~ : Int,
  len~ : Int,
) {
  self.write_once(bytes, offset~, len~)
}

///|
impl @async/io.Writer for MemWriter with write(
  self : MemWriter,
  data : &@async/io.Data,
) {
  self.write(data)
}

///|
impl @async/io.Writer for MemWriter with write_reader(
  self : MemWriter,
  reader : &@async/io.Reader,
) {
  self.write_reader(reader)
}

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
async test "save_as rejects unsupported extension" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let result : Result[Unit, Error] = try? workbook.save_as("bad.foo")
  match result {
    Err(XlsxError::InvalidSheetOperation(msg~)) =>
      inspect(msg, content="unsupported workbook file format")
    _ => fail("expected unsupported workbook file format error")
  }
}

///|
async test "save_as sets workbook content type by extension" {
  let stamp = @env.now().to_string()
  let path_xltx = "mbtexcel_type_\{stamp}.xltx"
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.save_as(path_xltx)
  let types_xml = {
    let data = @async/fs.read_file(path_xltx) catch {
      err => fail("read file failed: \{err}")
    }
    let archive = @zip.read(data.binary()) catch {
      err => fail("zip read failed: \{err}")
    }
    match archive.get("[Content_Types].xml") {
      Some(value) =>
        @encoding/utf8.decode(value) catch {
          _ => fail("content types utf8 decode failed")
        }
      None => fail("missing content types")
    }
  }
  inspect(
    types_xml.contains(
      "application/vnd.openxmlformats-officedocument.spreadsheetml.template.main+xml",
    ),
    content="true",
  )
  @async/fs.remove(path_xltx) catch {
    err => fail("remove file failed: \{err}")
  }
  let path_xlam = "mbtexcel_type_\{stamp}.xlam"
  let workbook2 = Workbook::new()
  ignore(workbook2.add_sheet("Sheet1"))
  workbook2.save_as(path_xlam)
  let types_xml2 = {
    let data = @async/fs.read_file(path_xlam) catch {
      err => fail("read file failed: \{err}")
    }
    let archive = @zip.read(data.binary()) catch {
      err => fail("zip read failed: \{err}")
    }
    match archive.get("[Content_Types].xml") {
      Some(value) =>
        @encoding/utf8.decode(value) catch {
          _ => fail("content types utf8 decode failed")
        }
      None => fail("missing content types")
    }
  }
  inspect(
    types_xml2.contains("application/vnd.ms-excel.addin.macroEnabled.main+xml"),
    content="true",
  )
  @async/fs.remove(path_xlam) catch {
    err => fail("remove file failed: \{err}")
  }
  let path_xltm = "mbtexcel_type_\{stamp}.xltm"
  let workbook3 = Workbook::new()
  ignore(workbook3.add_sheet("Sheet1"))
  workbook3.save_as(path_xltm)
  let types_xml3 = {
    let data = @async/fs.read_file(path_xltm) catch {
      err => fail("read file failed: \{err}")
    }
    let archive = @zip.read(data.binary()) catch {
      err => fail("zip read failed: \{err}")
    }
    match archive.get("[Content_Types].xml") {
      Some(value) =>
        @encoding/utf8.decode(value) catch {
          _ => fail("content types utf8 decode failed")
        }
      None => fail("missing content types")
    }
  }
  inspect(
    types_xml3.contains(
      "application/vnd.ms-excel.template.macroEnabled.main+xml",
    ),
    content="true",
  )
  @async/fs.remove(path_xltm) catch {
    err => fail("remove file failed: \{err}")
  }
  let path_vba_xlsx = "mbtexcel_type_\{stamp}_vba.xlsx"
  let workbook4 = Workbook::new()
  ignore(workbook4.add_sheet("Sheet1"))
  let vba_header : Array[Byte] = [
    0xd0, 0xcf, 0x11, 0xe0, 0xa1, 0xb1, 0x1a, 0xe1,
  ]
  workbook4.add_vba_project(Bytes::from_array(vba_header))
  workbook4.save_as(path_vba_xlsx)
  let types_xml4 = {
    let data = @async/fs.read_file(path_vba_xlsx) catch {
      err => fail("read file failed: \{err}")
    }
    let archive = @zip.read(data.binary()) catch {
      err => fail("zip read failed: \{err}")
    }
    match archive.get("[Content_Types].xml") {
      Some(value) =>
        @encoding/utf8.decode(value) catch {
          _ => fail("content types utf8 decode failed")
        }
      None => fail("missing content types")
    }
  }
  inspect(
    types_xml4.contains("application/vnd.ms-excel.sheet.macroEnabled.main+xml"),
    content="false",
  )
  @async/fs.remove(path_vba_xlsx) catch {
    err => fail("remove file failed: \{err}")
  }
}

///|
async test "open_reader from pipe" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.set_cell("Sheet1", "B2", "gamma")
  let bytes = workbook.write_to_buffer()
  let (reader, writer) = @async/io.pipe()
  let parsed = @async.with_task_group(fn(group) {
    group.spawn_bg(() => {
      defer writer.close()
      writer.write(bytes)
    })
    open_reader(reader)
  })
  inspect(parsed.get_cell("Sheet1", "B2"), content="Some(\"gamma\")")
}

///|
async test "read_zip_reader from pipe" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.set_cell("Sheet1", "E5", "reader")
  let bytes = workbook.write_to_buffer()
  let (reader, writer) = @async/io.pipe()
  let parsed = @async.with_task_group(fn(group) {
    group.spawn_bg(() => {
      defer writer.close()
      writer.write(bytes)
    })
    read_zip_reader(reader)
  })
  inspect(parsed.get_cell("Sheet1", "E5"), content="Some(\"reader\")")
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

///|
test "custom zip writer used" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.set_cell("Sheet1", "A1", "alpha")
  let called = @ref.new(false)
  workbook.set_zip_writer(archive => {
    called.val = true
    @zip.write(archive)
  })
  let bytes = workbook.write_to_buffer()
  guard called.val else { fail("zip writer was not called") }
  let parsed = read(bytes)
  inspect(parsed.get_cell("Sheet1", "A1"), content="Some(\"alpha\")")
}

///|
async test "write wrapper" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.set_cell("Sheet1", "A1", "alpha")
  let writer = MemWriter::new()
  workbook.write(writer)
  let bytes = Bytes::from_array(writer.data)
  let parsed = read(bytes)
  inspect(parsed.get_cell("Sheet1", "A1"), content="Some(\"alpha\")")
}

///|
async test "write_to returns byte length" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.set_cell("Sheet1", "D4", "delta")
  let bytes = workbook.write_to_buffer()
  let writer = MemWriter::new()
  let size = workbook.write_to(writer)
  let written = Bytes::from_array(writer.data)
  inspect(size == bytes.length(), content="true")
  inspect(written == bytes, content="true")
}
