///|
test "a dump document parses back and replays" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Data"))
  workbook.set_cell("Data", "A1", "Region")
  workbook.set_cell_int("Data", "B1", 12)
  workbook.set_cell_formula("Data", "C1", "B1*2")
  let original = @dump.dump_xlsx_workbook(
    workbook,
    source_file="r.xlsx",
    source_bytes=1,
  )
  // serialize to JSON, parse back, replay, and re-dump: stable
  let document = original.to_json_document()
  let parsed = @dump.parse_dump_envelope(document)
  assert_eq(parsed.format, "xlsx")
  assert_eq(parsed.create_sheet, Some("Data"))
  assert_eq(
    Json::array(parsed.ops).stringify(),
    Json::array(original.ops).stringify(),
  )
  let replayed = @dump.replay_xlsx_dump(parsed)
  let redumped = @dump.dump_xlsx_workbook(
    replayed,
    source_file="r.xlsx",
    source_bytes=1,
  )
  assert_eq(
    Json::array(original.ops).stringify(),
    Json::array(redumped.ops).stringify(),
  )
}

///|
fn rejects(document : Json) -> Bool {
  (try? @dump.parse_dump_envelope(document)) is Err(_)
}

///|
test "malformed dumps are rejected" {
  // wrong schema
  assert_true(
    rejects(Json::object({ "schema": Json::string("office.dump/2") })),
  )
  // missing ops
  assert_true(
    rejects(
      Json::object({
        "schema": Json::string("office.dump/1"),
        "format": Json::string("xlsx"),
        "replay": Json::object({ "batch_schema": Json::string("xlsx.batch/1") }),
      }),
    ),
  )
  // a non-object op
  assert_true(
    rejects(
      Json::object({
        "schema": Json::string("office.dump/1"),
        "format": Json::string("xlsx"),
        "replay": Json::object({ "batch_schema": Json::string("xlsx.batch/1") }),
        "ops": Json::array([Json::string("not an op")]),
      }),
    ),
  )
  // missing replay block
  assert_true(
    rejects(
      Json::object({
        "schema": Json::string("office.dump/1"),
        "format": Json::string("xlsx"),
      }),
    ),
  )
}
