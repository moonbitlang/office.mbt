///|
test "XLSX batch result accounting uses the parsed plan boundary" {
  let script =
    #|{"schema":"xlsx.batch/1","ops":[
    #|  {"op":"set","params":{"sheet":"Data","cell":"A1","value":"one"}},
    #|  {"op":"formula","params":{"sheet":"Data","cell":"B1","formula":"=LEN(A1)"}},
    #|  {"op":"style","params":{"sheet":"Data","range":"A1:B1","bold":true}}
    #|]}
  let plan = @office_xlsx.parse_batch(@utf8.encode(script))
  guard xlsx_batch_stats_json(plan.stats()) is Object(fields) else {
    fail("batch stats must be an object")
  }
  assert_eq(fields.get("operation_count"), Some(Json::number(3.0)))
  assert_eq(fields.get("touched_cells"), Some(Json::number(4.0)))
  assert_eq(fields.get("style_cells"), Some(Json::number(2.0)))
  assert_eq(fields.get("new_style_records"), Some(Json::number(1.0)))
}

///|
test "XLSX batch script failures retain a stable bounded protocol code" {
  let long_path = "script-" + "x".repeat(500)
  let CliFailure(error) = xlsx_batch_failure(
    "unknown top-level key 'typo'", long_path,
  )
  assert_eq(error.code, "office.xlsx.invalid_batch_script")
  guard error.details is Some(Object(details)) else {
    fail("batch failure must identify its script")
  }
  guard details.get("script") is Some(String(path)) else {
    fail("batch failure script detail must be a string")
  }
  assert_true(path.length() < long_path.length())
}

///|
test "XLSX create and batch capability variants declare transactional schemas" {
  guard @lib.find_capability_command("create") is Some(create) else {
    fail("create capability must exist")
  }
  assert_eq(create.formats, ["xlsx"])
  assert_eq(create.variants.length(), 1)
  assert_eq(create.variants[0].result_schema, @lib.SCHEMA_XLSX_CREATE_RESULT)
  guard @lib.find_capability_command("batch") is Some(batch) else {
    fail("batch capability must exist")
  }
  assert_eq(batch.formats, ["xlsx"])
  assert_eq(batch.variants.length(), 1)
  assert_eq(batch.variants[0].result_schema, @lib.SCHEMA_XLSX_BATCH_RESULT)
  assert_true(batch.variants[0].constraints.contains("zero-op-reuses-original"))
}
