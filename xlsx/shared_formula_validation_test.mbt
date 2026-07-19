///|
fn malformed_shared_formula_package(
  old : String,
  replacement : String,
) -> Bytes raise {
  let workbook = @xlsx.Workbook::new()
  let sheet = workbook.add_sheet("Data")
  sheet.set_cell_formula_opts(
    "A1",
    "D1+1",
    opts=@xlsx.FormulaOpts::shared("A1:C1"),
  )
  let archive = @zip.read(@xlsx.write(workbook))
  let path = "xl/worksheets/sheet1.xml"
  let xml = match archive.get(path) {
    Some(value) =>
      @encoding/utf8.decode(value) catch {
        _ => fail("shared-formula worksheet is not UTF-8")
      }
    None => fail("missing shared-formula worksheet")
  }
  let updated = xml.replace(old~, new=replacement)
  if updated == xml {
    fail("shared-formula corruption marker was not found")
  }
  assert_true(archive.replace(path, @encoding/utf8.encode(updated)))
  @zip.write(archive)
}

///|
fn expect_shared_formula_read_error(
  label : String,
  bytes : BytesView,
  expected : String,
) -> Unit raise {
  let result : Result[@xlsx.Workbook, Error] = Ok(@xlsx.read(bytes)) catch {
    error => Err(error)
  }
  match result {
    Err(@xlsx.InvalidXml(msg~)) => assert_eq(msg, expected)
    Err(error) => fail("\{label}: unexpected error \{error}")
    Ok(_) => fail("\{label}: malformed shared-formula group was accepted")
  }
}

///|
test "XLSX read rejects missing, out-of-range, and conflicting shared masters" {
  let master =
    #|<f t="shared" ref="A1:C1" si="0">D1+1</f>
  let follower =
    #|<f t="shared" si="0"></f>
  expect_shared_formula_read_error(
    "missing master",
    malformed_shared_formula_package(master, follower),
    "shared formula follower has no master",
  )
  expect_shared_formula_read_error(
    "out-of-range follower",
    malformed_shared_formula_package(
      master, "<f t=\"shared\" ref=\"A1:B1\" si=\"0\">D1+1</f>",
    ),
    "shared formula follower is outside the master range",
  )
  expect_shared_formula_read_error(
    "conflicting masters",
    malformed_shared_formula_package(
      follower, "<f t=\"shared\" ref=\"A1:C1\" si=\"0\">E1+1</f>",
    ),
    "shared formula index has conflicting masters",
  )
}

///|
test "XLSX read ignores expressions stored on shared-formula followers" {
  let bytes = malformed_shared_formula_package(
    "<f t=\"shared\" si=\"0\"></f>", "<f t=\"shared\" si=\"0\">PRODUCER_GARBAGE+1</f>",
  )
  let workbook = @xlsx.read(bytes)
  guard workbook.sheet("Data") is Some(sheet) else {
    fail("missing shared-formula worksheet")
  }
  guard sheet.get_cell_formula_info_rc(1, 2) is Some(follower) else {
    fail("missing shared-formula follower metadata")
  }
  assert_eq(follower.formula, "")
  assert_eq(follower.shared_index, Some(0))
  guard sheet.shared_formula_masters().get(0) is Some(master) else {
    fail("missing shared-formula master")
  }
  assert_eq(master.translate_to(1, 2), "E1+1")
  let (bounded, work) = master.translate_to_limited(
    1,
    2,
    maximum_input_chars=4,
    maximum_output_chars=4,
    maximum_work_units=256,
  )
  assert_eq(bounded, "E1+1")
  assert_true(work > 0)
  try
    master.translate_to_limited(
      1,
      2,
      maximum_input_chars=3,
      maximum_output_chars=4,
      maximum_work_units=256,
    )
  catch {
    ResourceLimitExceeded(kind~, limit~, actual~) => {
      assert_eq(kind, "shared_formula_input_chars")
      assert_eq(limit, 3)
      assert_eq(actual, 4)
    }
    _ => fail("unexpected bounded shared-formula error")
  } noraise {
    _ => fail("expected bounded shared-formula rejection")
  }
}

///|
test "XLSX calculation resolves shared-formula followers through their master" {
  let source = @xlsx.Workbook::new()
  let sheet = source.add_sheet("Data")
  sheet.set_cell_value("A1", Numeric(1.0))
  sheet.set_cell_value("B1", Numeric(2.0))
  sheet.set_cell_value("A2", Numeric(3.0))
  sheet.set_cell_value("B2", Numeric(4.0))
  sheet.set_cell_formula_opts(
    "C1",
    "A1+B1",
    opts=@xlsx.FormulaOpts::shared("C1:C2"),
  )
  let parsed = @xlsx.read(@xlsx.write(source))
  inspect(parsed.calc_cell_value("Data", "C1"), content="3")
  inspect(parsed.calc_cell_value("Data", "C2"), content="7")
}

///|
test "XLSX read accepts a singleton shared-formula ST_Ref" {
  let source = @xlsx.Workbook::new()
  let sheet = source.add_sheet("Data")
  sheet.set_cell_formula_opts(
    "A1",
    "1+1",
    opts=@xlsx.FormulaOpts::shared("A1:A1"),
  )
  let archive = @zip.read(@xlsx.write(source))
  let path = "xl/worksheets/sheet1.xml"
  let xml = match archive.get(path) {
    Some(value) =>
      @encoding/utf8.decode(value) catch {
        _ => fail("shared-formula worksheet is not UTF-8")
      }
    None => fail("missing shared-formula worksheet")
  }
  let updated = xml.replace(old="ref=\"A1:A1\"", new="ref=\"A1\"")
  assert_true(updated != xml)
  assert_true(archive.replace(path, @encoding/utf8.encode(updated)))
  let parsed = @xlsx.read(@zip.write(archive))
  guard parsed.sheet("Data") is Some(parsed_sheet) else {
    fail("missing singleton shared-formula worksheet")
  }
  guard parsed_sheet.shared_formula_masters().get(0) is Some(master) else {
    fail("missing singleton shared-formula master")
  }
  assert_eq(master.translate_to(1, 1), "1+1")
}

///|
fn shared_formula_edit_fixture() -> @xlsx.Workbook raise {
  let workbook = @xlsx.Workbook::new()
  let sheet = workbook.add_sheet("Data")
  sheet.set_cell_formula_opts(
    "C1",
    "A1+B1",
    opts=@xlsx.FormulaOpts::shared("C1:C3"),
  )
  workbook
}

///|
fn assert_structural_edit_deshared(
  workbook : @xlsx.Workbook,
  references : ArrayView[String],
) -> Unit raise {
  guard workbook.sheet("Data") is Some(sheet) else {
    fail("missing structurally edited worksheet")
  }
  assert_eq(sheet.shared_formula_masters().length(), 0)
  for reference in references {
    assert_true(sheet.get_cell_formula(reference) is Some(_))
  }
  let roundtripped = @xlsx.read(@xlsx.write(workbook))
  guard roundtripped.sheet("Data") is Some(roundtripped_sheet) else {
    fail("missing roundtripped structurally edited worksheet")
  }
  assert_eq(roundtripped_sheet.shared_formula_masters().length(), 0)
  for reference in references {
    assert_true(roundtripped_sheet.get_cell_formula(reference) is Some(_))
  }
}

///|
test "row and column edits materialize shared formulas before moving cells" {
  let insert_rows = shared_formula_edit_fixture()
  insert_rows.insert_rows("Data", 1, 1)
  assert_structural_edit_deshared(insert_rows, ["C2", "C3", "C4"])

  let remove_rows = shared_formula_edit_fixture()
  remove_rows.remove_rows("Data", 2, 1)
  assert_structural_edit_deshared(remove_rows, ["C1", "C2"])

  let insert_cols = shared_formula_edit_fixture()
  insert_cols.insert_cols("Data", 3, 1)
  assert_structural_edit_deshared(insert_cols, ["D1", "D2", "D3"])

  let remove_cols = shared_formula_edit_fixture()
  remove_cols.remove_cols("Data", 2, 1)
  assert_structural_edit_deshared(remove_cols, ["B1", "B2", "B3"])

  let duplicate_row = shared_formula_edit_fixture()
  duplicate_row.duplicate_row_to("Data", 1, 4)
  assert_structural_edit_deshared(duplicate_row, ["C1", "C2", "C3", "C4"])
}

///|
test "shared formula limits reject aggregate structural fan-out before mutation" {
  let workbook = shared_formula_edit_fixture()
  let limits = @xlsx.SharedFormulaLimits::with_values(
    max_input_chars=64,
    max_output_chars=14,
    max_total_output_chars=14,
    max_work_units=1024,
  )
  let result : Result[Unit, Error] = Ok(
    workbook.insert_rows("Data", 1, 1, formula_limits=limits),
  ) catch {
    error => Err(error)
  }
  match result {
    Err(@xlsx.ResourceLimitExceeded(kind~, limit~, actual~)) => {
      assert_eq(kind, "shared_formula_total_output_chars")
      assert_eq(limit, 14)
      assert_eq(actual, 15)
    }
    Err(error) => fail("unexpected shared-formula fan-out error: \{error}")
    Ok(_) => fail("expected aggregate shared-formula fan-out rejection")
  }
  guard workbook.sheet("Data") is Some(sheet) else {
    fail("missing unchanged shared-formula worksheet")
  }
  assert_eq(sheet.shared_formula_masters().length(), 1)
  assert_true(sheet.get_cell_formula_info_rc(1, 3) is Some(_))
  assert_true(sheet.get_cell_formula_info_rc(3, 3) is Some(_))
  assert_true(sheet.get_cell_formula_info_rc(4, 3) is None)

  let work_limited = shared_formula_edit_fixture()
  let work_limits = @xlsx.SharedFormulaLimits::with_values(
    max_input_chars=64,
    max_output_chars=64,
    max_total_output_chars=64,
    max_work_units=14,
  )
  try work_limited.insert_cols("Data", 1, 1, formula_limits=work_limits) catch {
    ResourceLimitExceeded(kind~, limit~, actual~) => {
      assert_eq(kind, "shared_formula_work_units")
      assert_eq(limit, 14)
      assert_eq(actual, 15)
    }
    _ => fail("unexpected aggregate shared-formula work error")
  } noraise {
    _ => fail("expected aggregate shared-formula work rejection")
  }
}

///|
test "default shared formula limits stop the reported large fan-out" {
  let workbook = @xlsx.Workbook::new()
  let sheet = workbook.add_sheet("Data")
  let formula = "1+".repeat(4094) + "A1"
  sheet.set_cell_formula_opts(
    "A1",
    formula,
    opts=@xlsx.FormulaOpts::shared("A1:A8200"),
  )
  let result : Result[Unit, Error] = Ok(workbook.insert_rows("Data", 1, 1)) catch {
    error => Err(error)
  }
  match result {
    Err(@xlsx.ResourceLimitExceeded(kind~, limit~, actual~)) => {
      assert_eq(kind, "shared_formula_total_output_chars")
      assert_eq(
        limit,
        @xlsx.SharedFormulaLimits::new().max_total_output_chars(),
      )
      assert_true(actual > limit)
    }
    Err(error) => fail("unexpected default fan-out error: \{error}")
    Ok(_) => fail("expected default shared-formula fan-out rejection")
  }
  assert_eq(sheet.shared_formula_masters().length(), 1)
  assert_true(sheet.get_cell_formula_info_rc(1, 1) is Some(_))
  assert_true(sheet.get_cell_formula_info_rc(8200, 1) is Some(_))
  assert_true(sheet.get_cell_formula_info_rc(8201, 1) is None)
}

///|
test "shared formula structural edits are cancellable and atomic" {
  let workbook = shared_formula_edit_fixture()
  let checks = [0]
  let result : Result[Unit, Error] = Ok(
    workbook.insert_rows("Data", 1, 1, cancelled=() => {
      checks[0] += 1
      true
    }),
  ) catch {
    error => Err(error)
  }
  assert_eq(checks[0], 1)
  assert_true(result is Err(@xlsx.ReadCancelled))
  guard workbook.sheet("Data") is Some(sheet) else {
    fail("missing cancelled shared-formula worksheet")
  }
  assert_eq(sheet.shared_formula_masters().length(), 1)
  assert_true(sheet.get_cell_formula_info_rc(1, 3) is Some(_))
  assert_true(sheet.get_cell_formula_info_rc(4, 3) is None)
}

///|
test "row removal does not translate shared formulas it discards" {
  let workbook = @xlsx.Workbook::new()
  let sheet = workbook.add_sheet("Data")
  sheet.set_cell_formula_opts(
    "A1",
    "B1+AN_OVERSIZED_LITERAL",
    opts=@xlsx.FormulaOpts::shared("A1:A3"),
  )
  let tiny = @xlsx.SharedFormulaLimits::with_values(
    max_input_chars=1,
    max_output_chars=1,
    max_total_output_chars=1,
    max_work_units=1,
  )
  workbook.remove_rows("Data", 1, 3, formula_limits=tiny)
  let (max_row, max_col) = sheet.used_bounds_limited(maximum_stored_cells=1)
  assert_eq(max_row, 0)
  assert_eq(max_col, 0)
  assert_eq(sheet.shared_formula_masters().length(), 0)

  let column_workbook = @xlsx.Workbook::new()
  let column_sheet = column_workbook.add_sheet("Data")
  column_sheet.set_cell_formula_opts(
    "A1",
    "A2+AN_OVERSIZED_LITERAL",
    opts=@xlsx.FormulaOpts::shared("A1:C1"),
  )
  column_workbook.remove_cols("Data", 1, 3, formula_limits=tiny)
  let (column_max_row, column_max_col) = column_sheet.used_bounds_limited(
    maximum_stored_cells=1,
  )
  assert_eq(column_max_row, 0)
  assert_eq(column_max_col, 0)
  assert_eq(column_sheet.shared_formula_masters().length(), 0)
}

///|
test "calculation shares formula output and cancellation budgets" {
  let workbook = @xlsx.Workbook::new()
  let sheet = workbook.add_sheet("Data")
  sheet.set_cell_value("A1", Numeric(1.0))
  sheet.set_cell_value("A2", Numeric(2.0))
  sheet.set_cell_value("A3", Numeric(3.0))
  sheet.set_cell_formula_opts(
    "B1",
    "A1",
    opts=@xlsx.FormulaOpts::shared("B1:B3"),
  )
  sheet.set_cell_formula("C1", "SUM(B1:B3)")
  let tiny = @xlsx.SharedFormulaLimits::with_values(
    max_input_chars=16,
    max_output_chars=3,
    max_total_output_chars=3,
    max_work_units=1024,
  )
  try workbook.calc_cell_value("Data", "C1", formula_limits=tiny) catch {
    ResourceLimitExceeded(kind~, limit~, actual~) => {
      assert_eq(kind, "shared_formula_total_output_chars")
      assert_eq(limit, 3)
      assert_eq(actual, 4)
    }
    _ => fail("unexpected calculated fan-out error")
  } noraise {
    _ => fail("expected aggregate calculation fan-out rejection")
  }
  try workbook.calc_cell_value("Data", "B2", cancelled=() => true) catch {
    ReadCancelled => ()
    _ => fail("unexpected calculated cancellation error")
  } noraise {
    _ => fail("expected calculated shared-formula cancellation")
  }
}

///|
fn shared_formula_spill_probe_fixture() -> @xlsx.Workbook raise {
  let workbook = @xlsx.Workbook::new()
  let sheet = workbook.add_sheet("Data")
  sheet.set_cell_formula_opts(
    "B1",
    "2",
    opts=@xlsx.FormulaOpts::shared("B1:B2"),
  )
  sheet.set_cell_formula("D1", "SEQUENCE(B2)")
  workbook
}

///|
test "spill probing propagates shared formula cancellation and limits" {
  let cancelled = shared_formula_spill_probe_fixture()
  try cancelled.calc_cell_value("Data", "D2", cancelled=() => true) catch {
    ReadCancelled => ()
    _ => fail("unexpected spill cancellation error")
  } noraise {
    value => fail("expected spill cancellation, got \{value}")
  }

  let limited = shared_formula_spill_probe_fixture()
  let limits = @xlsx.SharedFormulaLimits::with_values(
    max_input_chars=16,
    max_output_chars=16,
    max_total_output_chars=16,
    max_work_units=1,
  )
  try limited.calc_cell_value("Data", "D2", formula_limits=limits) catch {
    ResourceLimitExceeded(kind~, limit~, actual~) => {
      assert_eq(kind, "shared_formula_work_units")
      assert_eq(limit, 1)
      assert_true(actual > limit)
    }
    _ => fail("unexpected spill resource error")
  } noraise {
    value => fail("expected spill resource rejection, got \{value}")
  }
}

///|
test "XLSX read rejects overlapping shared-formula master ranges" {
  let workbook = @xlsx.Workbook::new()
  let sheet = workbook.add_sheet("Data")
  sheet.set_cell_formula_opts(
    "A1",
    "B1+1",
    opts=@xlsx.FormulaOpts::shared("A1:A2"),
  )
  sheet.set_cell_formula_opts(
    "C1",
    "D1+1",
    opts=@xlsx.FormulaOpts::shared("C1:C2"),
  )
  let archive = @zip.read(@xlsx.write(workbook))
  let path = "xl/worksheets/sheet1.xml"
  let xml = match archive.get(path) {
    Some(value) =>
      @encoding/utf8.decode(value) catch {
        _ => fail("shared-formula worksheet is not UTF-8")
      }
    None => fail("missing shared-formula worksheet")
  }
  let updated = xml.replace(old="ref=\"A1:A2\"", new="ref=\"A1:C1\"")
  assert_true(updated != xml)
  assert_true(archive.replace(path, @encoding/utf8.encode(updated)))
  expect_shared_formula_read_error(
    "overlapping masters",
    @zip.write(archive),
    "shared formula master ranges overlap",
  )
}

///|
test "XLSX shared-formula indices cover the OOXML unsigned range" {
  let workbook = @xlsx.Workbook::new()
  let sheet = workbook.add_sheet("Data")
  sheet.set_cell_formula_opts(
    "A1",
    "D1+1",
    opts=@xlsx.FormulaOpts::shared("A1:C1"),
  )
  let archive = @zip.read(@xlsx.write(workbook))
  let path = "xl/worksheets/sheet1.xml"
  let xml = match archive.get(path) {
    Some(value) =>
      @encoding/utf8.decode(value) catch {
        _ => fail("shared-formula worksheet is not UTF-8")
      }
    None => fail("missing shared-formula worksheet")
  }
  let updated = xml.replace_all(old="si=\"0\"", new="si=\"4294967295\"")
  assert_true(updated != xml)
  assert_true(archive.replace(path, @encoding/utf8.encode(updated)))
  let parsed = @xlsx.read(@zip.write(archive))
  guard parsed.sheet("Data") is Some(parsed_sheet) else {
    fail("missing parsed shared-formula worksheet")
  }
  guard parsed_sheet.shared_formula_masters().get(0xFFFFFFFF) is Some(master) else {
    fail("missing maximum unsigned shared-formula index")
  }
  assert_eq(master.translate_to(1, 3), "F1+1")
  let roundtripped = @xlsx.read(@xlsx.write(parsed))
  guard roundtripped.sheet("Data") is Some(roundtripped_sheet) else {
    fail("missing roundtripped shared-formula worksheet")
  }
  assert_true(roundtripped_sheet.shared_formula_masters().contains(0xFFFFFFFF))
}

///|
test "XLSX read rejects negative shared-formula indices" {
  expect_shared_formula_read_error(
    "negative index",
    malformed_shared_formula_package("si=\"0\"", "si=\"-1\""),
    "formula si invalid",
  )
}
