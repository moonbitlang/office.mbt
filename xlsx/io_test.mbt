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
