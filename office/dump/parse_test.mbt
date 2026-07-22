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
/// A well-formed dump body with one op, for mutating into malformed cases.
fn valid_dump_fields() -> Map[String, Json] {
  {
    "schema": Json::string("office.dump/1"),
    "format": Json::string("xlsx"),
    "replay": Json::object({
      "batch_schema": Json::string("xlsx.batch/1"),
      "create": Json::object({ "sheet": Json::string("Data") }),
    }),
    "ops": Json::array([
      Json::object({
        "op": Json::string("set"),
        "params": Json::object({
          "sheet": Json::string("Data"),
          "cell": Json::string("A1"),
          "value": Json::string("x"),
        }),
      }),
    ]),
    "stats": Json::object({ "ops": Json::number(1) }),
  }
}

///|
test "malformed dumps are rejected" {
  // a complete valid dump parses
  assert_false(rejects(Json::object(valid_dump_fields())))
  // wrong schema
  assert_true(
    rejects(Json::object({ "schema": Json::string("office.dump/2") })),
  )
  // each required field missing → rejected
  for key in ["schema", "format", "replay", "ops", "stats"] {
    let fields = valid_dump_fields()
    fields.remove(key)
    assert_true(rejects(Json::object(fields)))
  }
  // a stats.ops count that disagrees with the op stream → rejected
  let padded = valid_dump_fields()
  padded["stats"] = Json::object({ "ops": Json::number(2) })
  assert_true(rejects(Json::object(padded)))
  // a fractional stats.ops must not truncate to a matching integer
  let fractional = valid_dump_fields()
  fractional["stats"] = Json::object({ "ops": Json::number(1.5) })
  assert_true(rejects(Json::object(fractional)))
  // a missing create sheet → rejected by the parser, not deferred to replay
  let no_sheet = valid_dump_fields()
  no_sheet["replay"] = Json::object({
    "batch_schema": Json::string("xlsx.batch/1"),
    "create": Json::object({}),
  })
  assert_true(rejects(Json::object(no_sheet)))
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

///|
/// PR5: a docx envelope parses without a create sheet, and assets are
/// reconstructed only when their integrity holds — the payload must
/// decode, match its declared size, and hash to its own id.
test "docx envelopes and asset integrity at parse" {
  let payload : Bytes = "asset-bytes"
  let data = @b64.encode(payload)
  let id = "sha256-" + @dump.sha256_hex_bytes(payload)
  let keyed = (key : String, entry : Json) => {
    let map : Map[String, Json] = {}
    map[key] = entry
    Json::object(map)
  }
  let document = (assets : Json) => {
    Json::object({
      "schema": Json::string("office.dump/1"),
      "format": Json::string("docx"),
      "replay": Json::object({
        "batch_schema": Json::string("docx.batch/2"),
        "create": Json::object({}),
      }),
      "ops": Json::array([
        Json::object({
          "op": Json::string("paragraph"),
          "params": Json::object({ "text": Json::string("x") }),
        }),
      ]),
      "assets": assets,
      "stats": Json::object({ "ops": Json::number(1) }),
    })
  }
  // a well-formed asset reconstructs
  let good = @dump.parse_dump_envelope(
    document(
      keyed(
        id,
        Json::object({
          "content_type": Json::string("image/png"),
          "size": Json::number(payload.length().to_double()),
          "data": Json::string(data),
        }),
      ),
    ),
  )
  assert_eq(good.format, "docx")
  assert_true(good.create_sheet is None)
  assert_eq(good.assets.size(), 1)
  // a lying digest is a malformed dump
  match
    (try? @dump.parse_dump_envelope(
      document(
        keyed(
          "sha256-0000000000000000000000000000000000000000000000000000000000000000",
          Json::object({
            "content_type": Json::string("image/png"),
            "size": Json::number(payload.length().to_double()),
            "data": Json::string(data),
          }),
        ),
      ),
    )) {
    Err(@dump.DumpParseError(reason)) =>
      assert_true(reason.contains("does not hash"))
    Ok(_) => fail("a lying digest must not parse")
  }
  // a size mismatch is a malformed dump
  match
    (try? @dump.parse_dump_envelope(
      document(
        keyed(
          id,
          Json::object({
            "content_type": Json::string("image/png"),
            "size": Json::number(999),
            "data": Json::string(data),
          }),
        ),
      ),
    )) {
    Err(@dump.DumpParseError(reason)) => assert_true(reason.contains("bytes"))
    Ok(_) => fail("a size mismatch must not parse")
  }
  // invalid base64 is a malformed dump
  match
    (try? @dump.parse_dump_envelope(
      document(
        keyed(
          id,
          Json::object({
            "content_type": Json::string("image/png"),
            "size": Json::number(payload.length().to_double()),
            "data": Json::string("!!!not-base64!!!"),
          }),
        ),
      ),
    )) {
    Err(@dump.DumpParseError(reason)) => assert_true(reason.contains("base64"))
    Ok(_) => fail("invalid base64 must not parse")
  }
  // an xlsx envelope still requires its create sheet
  match
    (try? @dump.parse_dump_envelope(
      Json::object({
        "schema": Json::string("office.dump/1"),
        "format": Json::string("xlsx"),
        "replay": Json::object({
          "batch_schema": Json::string("xlsx.batch/1"),
          "create": Json::object({}),
        }),
        "ops": Json::array([]),
        "stats": Json::object({ "ops": Json::number(0) }),
      }),
    )) {
    Err(@dump.DumpParseError(reason)) => assert_true(reason.contains("sheet"))
    Ok(_) => fail("an xlsx dump without a create sheet must not parse")
  }
}
