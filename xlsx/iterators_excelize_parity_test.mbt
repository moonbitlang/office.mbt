///|
#cfg(target="native")
fn trim_trailing_empty(values : Array[String]) -> Array[String] {
  let mut end = values.length()
  while end > 0 && values[end - 1] == "" {
    end = end - 1
  }
  values[:end].to_owned()
}

///|
#cfg(target="native")
fn normalize_2d(values : Array[Array[String]]) -> Array[Array[String]] {
  let out : Array[Array[String]] = []
  for row in values {
    out.push(trim_trailing_empty(row))
  }
  out
}

///|
#cfg(target="native")
fn eq_1d(a : Array[String], b : Array[String]) -> Bool {
  if a.length() != b.length() {
    return false
  }
  for i in 0..<a.length() {
    if a[i] != b[i] {
      return false
    }
  }
  true
}

///|
#cfg(target="native")
fn eq_2d(a : Array[Array[String]], b : Array[Array[String]]) -> Bool {
  if a.length() != b.length() {
    return false
  }
  for i in 0..<a.length() {
    if !eq_1d(a[i], b[i]) {
      return false
    }
  }
  true
}

///|
test "rows/cols/get_rows/get_cols validate sheet name" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let rows_result : Result[@xlsx.Rows, Error] = Ok(workbook.rows("Sheet:1")) catch {
    e => Err(e)
  }
  inspect(
    rows_result is Err(@xlsx.XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let cols_result : Result[@xlsx.Cols, Error] = Ok(workbook.cols("Sheet:1")) catch {
    e => Err(e)
  }
  inspect(
    cols_result is Err(@xlsx.XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let get_rows_result : Result[Array[Array[String]], Error] = Ok(
    workbook.get_rows("Sheet:1"),
  ) catch {
    e => Err(e)
  }
  inspect(
    get_rows_result is Err(@xlsx.XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let get_cols_result : Result[Array[Array[String]], Error] = Ok(
    workbook.get_cols("Sheet:1"),
  ) catch {
    e => Err(e)
  }
  inspect(
    get_cols_result is Err(@xlsx.XlsxError::InvalidSheetName(_)),
    content="true",
  )
}

///|
#cfg(target="native")
async test "excelize Book1 iterators match get_rows/get_cols" {
  let path = "fixtures/excelize/test/Book1.xlsx"
  let archive = @zip.read(@async/fs.read_file(path).binary())
  let sheet_path = "xl/worksheets/sheet2.xml"
  let sheet_xml = match archive.get(sheet_path) {
    Some(bytes) => @encoding/utf8.decode(bytes)
    None => fail("missing Book1 worksheet")
  }
  // Book1 predates strict shared-formula validation and contains intersecting
  // si=0/si=1 ranges. Normalize that unrelated defect in memory so this test
  // continues to exercise the original third-party iterator fixture.
  let normalized_sheet_xml = sheet_xml
    .replace(old="ref=\"F11:H11\"", new="ref=\"F11:F11\"")
    .replace(
      old="<f t=\"shared\" si=\"0\"></f>",
      new="<f t=\"shared\" si=\"1\"></f>",
    )
  assert_true(normalized_sheet_xml != sheet_xml)
  assert_true(
    archive.replace(sheet_path, @encoding/utf8.encode(normalized_sheet_xml)),
  )
  let workbook = @xlsx.read(@zip.write(archive))
  let total = workbook.get_cell_value("Sheet1", "A19") catch {
    err => fail("get_cell_value failed: \{repr(err)}")
  }
  debug_inspect(total, content="Some(\"Total:\")")
  let sheet = "Sheet2"
  let rows = workbook.rows(sheet) catch {
    err => fail("rows failed: \{repr(err)}")
  }
  let collected_rows : Array[Array[String]] = []
  while rows.next() {
    let cols = rows.columns() catch {
      err => fail("rows columns failed: \{repr(err)}")
    }
    collected_rows.push(trim_trailing_empty(cols))
  }
  let returned_rows = workbook.get_rows(sheet) catch {
    err => fail("get_rows failed: \{repr(err)}")
  }
  let normalized_returned_rows = normalize_2d(returned_rows)
  inspect(collected_rows.length(), content="11")
  inspect(normalized_returned_rows.length(), content="11")
  inspect(eq_2d(collected_rows, normalized_returned_rows), content="true")
  let cols = workbook.cols(sheet) catch {
    err => fail("cols failed: \{repr(err)}")
  }
  let collected_cols : Array[Array[String]] = []
  while cols.next() {
    collected_cols.push(trim_trailing_empty(cols.rows()))
  }
  debug_inspect(cols.error(), content="None")
  let returned_cols = workbook.get_cols(sheet) catch {
    err => fail("get_cols failed: \{repr(err)}")
  }
  let normalized_returned_cols = normalize_2d(returned_cols)
  inspect(collected_cols.length(), content="9")
  inspect(normalized_returned_cols.length(), content="9")
  inspect(eq_2d(collected_cols, normalized_returned_cols), content="true")
}
