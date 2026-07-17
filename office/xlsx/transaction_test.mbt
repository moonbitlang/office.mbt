///|
async fn with_xlsx_transaction_dir(run : async (String) -> Unit) -> Unit {
  @async.with_task_group() <| group => {
    let directory = @afs.tmpdir(prefix="office-xlsx-transaction-")
    group.add_defer() <| () => {
      @async.protect_from_cancel(() => @afs.rmdir(directory, recursive=true))
    }
    run(directory)
  }
}

///|
fn xlsx_transaction_fixture() -> Bytes raise {
  let workbook = @excel.new_workbook()
  ignore(workbook.add_sheet("Data"))
  workbook.set_cell("Data", "A1", "before")
  @excel.write(workbook)
}

///|
async fn write_xlsx_transaction_file(path : String, bytes : Bytes) -> Unit {
  @afs.write_file(path, bytes, create_mode=CreateNew, permission=0o600)
}

///|
async fn xlsx_transaction_error_code(
  run : async () -> @transaction.TransactionReport,
) -> String {
  try run() catch {
    @transaction.TransactionError(code~, ..) => code
    error => fail("expected TransactionError, received \{error}")
  } noraise {
    _ => fail("expected transaction failure")
  }
}

///|
test "XLSX batch parsing is the encoded shared boundary" {
  let plan = @xlsx.parse_batch(
    @utf8.encode(
      "{\"schema\":\"xlsx.batch/1\",\"ops\":[{\"op\":\"set\",\"params\":{\"sheet\":\"Data\",\"cell\":\"A1\",\"value\":\"after\"}}]}",
    ),
  )
  assert_eq(plan.operation_count(), 1)
  assert_eq(plan.stats().touched_cells, 1L)
}

///|
async test "fresh XLSX creation uses complete validation and atomic publication" {
  with_xlsx_transaction_dir(directory => {
    let output = "\{directory}/created.xlsx"
    let result = @xlsx.create_workbook(
      @transaction.create_transaction_options(output),
      "Data",
    )
    assert_eq(result.sheet, "Data")
    assert_true(result.transaction.committed)
    assert_true(result.transaction.changed)
    assert_eq(result.transaction.validations.length(), 2)
    assert_eq(result.transaction.validations[0].name, "office-portable-opc")
    assert_eq(result.transaction.validations[1].name, "office-xlsx-bounded")
    let reopened = @excel.read(@afs.read_file(output).binary())
    assert_eq(reopened.get_sheet_list(), ["Data"])
    assert_true(result.transaction.preservation.added.length() > 0)
  })
}

///|
async test "fresh XLSX creation normalizes invalid worksheet names" {
  with_xlsx_transaction_dir(directory => {
    let output = "\{directory}/invalid.xlsx"
    let code = try {
      ignore(
        @xlsx.create_workbook(
          @transaction.create_transaction_options(output),
          "bad/name",
        ),
      )
      ""
    } catch {
      @transaction.TransactionError(code~, ..) => code
      error => fail("expected TransactionError, received \{error}")
    }
    assert_eq(code, "office.xlsx.invalid_sheet_name")
    assert_false(@afs.exists(output))
  })
}

///|
async test "XLSX batch applies once and reports full rewrite preservation" {
  with_xlsx_transaction_dir(directory => {
    let input = "\{directory}/input.xlsx"
    let original = xlsx_transaction_fixture()
    write_xlsx_transaction_file(input, original)
    let script =
      #|{"schema":"xlsx.batch/1","ops":[
      #|  {"op":"set","params":{"sheet":"Data","cell":"A1","value":"after"}},
      #|  {"op":"formula","params":{"sheet":"Data","cell":"B1","formula":"=LEN(A1)"}},
      #|  {"op":"style","params":{"sheet":"Data","range":"A1:B1","bold":true}}
      #|]}
    let plan = @xlsx.parse_batch(@utf8.encode(script))
    let result = @xlsx.transact_batch(
      @transaction.transaction_options(input),
      plan,
    )
    assert_eq(result.stats.operation_count, 3)
    assert_eq(result.stats.touched_cells, 4L)
    assert_true(result.transaction.changed)
    assert_true(result.transaction.committed)
    let warnings = result.transaction.warning_records()
    assert_true(warnings.length() >= 1)
    assert_eq(warnings[0].code, "office.xlsx.full_rewrite")
    let reopened = @excel.read(@afs.read_file(input).binary())
    assert_eq(reopened.get_cell("Data", "A1"), Some("after"))
    assert_eq(reopened.get_cell_formula("Data", "B1"), Some("LEN(A1)"))
    assert_true(reopened.get_cell_style("Data", "A1").unwrap_or(0) > 0)
    assert_true(result.transaction.preservation.changed.length() > 0)
  })
}

///|
async test "XLSX dry-run validates the candidate without publishing" {
  with_xlsx_transaction_dir(directory => {
    let input = "\{directory}/input.xlsx"
    let output = "\{directory}/output.xlsx"
    let original = xlsx_transaction_fixture()
    write_xlsx_transaction_file(input, original)
    let plan = @xlsx.parse_batch(
      @utf8.encode(
        "{\"schema\":\"xlsx.batch/1\",\"ops\":[{\"op\":\"set\",\"params\":{\"sheet\":\"Data\",\"cell\":\"A1\",\"value\":\"dry\"}}]}",
      ),
    )
    let result = @xlsx.transact_batch(
      @transaction.transaction_options(input, output_path=output, dry_run=true),
      plan,
    )
    assert_true(result.transaction.dry_run)
    assert_false(result.transaction.committed)
    assert_true(result.transaction.changed)
    assert_eq(@afs.read_file(input).binary(), original)
    assert_false(@afs.exists(output))
  })
}

///|
async test "XLSX operation failure leaves source and destination untouched" {
  with_xlsx_transaction_dir(directory => {
    let input = "\{directory}/input.xlsx"
    let output = "\{directory}/output.xlsx"
    let original = xlsx_transaction_fixture()
    write_xlsx_transaction_file(input, original)
    let plan = @xlsx.parse_batch(
      @utf8.encode(
        "{\"schema\":\"xlsx.batch/1\",\"ops\":[{\"op\":\"set\",\"params\":{\"sheet\":\"Missing\",\"cell\":\"A1\",\"value\":1}}]}",
      ),
    )
    let code = xlsx_transaction_error_code(() => {
      let result = @xlsx.transact_batch(
        @transaction.transaction_options(input, output_path=output),
        plan,
      )
      result.transaction
    })
    assert_eq(code, "office.xlsx.batch_operation_failed")
    assert_eq(@afs.read_file(input).binary(), original)
    assert_false(@afs.exists(output))
  })
}

///|
async test "zero-op in-place XLSX batch reuses exact source bytes" {
  with_xlsx_transaction_dir(directory => {
    let input = "\{directory}/input.xlsx"
    let original = xlsx_transaction_fixture()
    write_xlsx_transaction_file(input, original)
    let plan = @xlsx.parse_batch(
      @utf8.encode("{\"schema\":\"xlsx.batch/1\",\"ops\":[]}"),
    )
    let result = @xlsx.transact_batch(
      @transaction.transaction_options(input),
      plan,
    )
    assert_false(result.transaction.changed)
    assert_false(result.transaction.committed)
    assert_true(result.transaction.preservation.whole_file_identical)
    assert_eq(result.transaction.warning_records().length(), 0)
    assert_eq(@afs.read_file(input).binary(), original)
  })
}
