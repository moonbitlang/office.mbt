///|
fn contract_operation_names(
  operations : Array[Json],
  field : String,
) -> Array[String] raise {
  let names : Array[String] = []
  for operation in operations {
    guard operation is Object(fields) && fields.get(field) is Some(String(name)) else {
      fail("contract operation is missing its discriminator")
    }
    names.push(name)
  }
  names
}

///|
test "input contract inventory is stable, ordered, and versioned" {
  let first = input_contract_inventory()
  assert_eq(first.stringify(), input_contract_inventory().stringify())
  guard first is Object(fields) else { fail("inventory must be an object") }
  assert_eq(fields.get("schema"), Some(Json::string(schema_input_contracts)))
  assert_eq(
    fields.get("fingerprint"),
    Some(
      Json::string(
        "sha256:fbcc5de5f488d0e8095765b9fa55d4b37569e41a36984405c5159ea46cb00b78",
      ),
    ),
  )
  guard fields.get("contracts") is Some(Array(records)) else {
    fail("inventory must carry contracts")
  }
  let ids : Array[String] = []
  for record in records {
    guard record is Object(item) &&
      item.get("id") is Some(String(id)) &&
      item.get("fingerprint") is Some(String(fingerprint)) else {
      fail("invalid inventory record")
    }
    ids.push(id)
    assert_true(fingerprint.has_prefix("sha256:"))
    assert_eq(fingerprint.length(), 71)
  }
  assert_eq(ids, [
    "xlsx.batch/1", "docx.batch/2", "office.template.data/1", "docx.annotation-batch/1",
  ])
}

///|
test "every advertised example passes its production parser" {
  for example in xlsx_input_contract().examples {
    ignore(@office_xlsx.parse_batch(@utf8.encode(example.stringify())))
  }
  for example in docx_input_contract().examples {
    ignore(@office_docx.parse_docx_authoring_script(example.stringify()))
  }
  for example in template_input_contract().examples {
    ignore(@template.parse_template_document(example.stringify()))
  }
  for example in annotation_input_contract().examples {
    ignore(@office_docx.parse_annotation_batch(example.stringify()))
  }
}

///|
test "operation inventories come from their production parser owners" {
  let xlsx = xlsx_input_contract()
  assert_eq(
    Json::array(xlsx.operations).stringify(),
    Json::array(copied_array_member(@batch.capabilities(), "ops")).stringify(),
  )
  assert_eq(
    contract_operation_names(docx_input_contract().operations, "op"),
    @docx_batch.operation_names(),
  )
  assert_eq(
    contract_operation_names(annotation_input_contract().operations, "name"),
    @office_docx.annotation_batch_operation_names(),
  )
  guard docx_input_contract().limits is Object(docx_limits) &&
    template_input_contract().limits is Object(template_limits) else {
    fail("contract limits must be objects")
  }
  assert_eq(
    docx_limits.get("max_emitted_media_parts"),
    Some(Json::number(@docx.MAX_AUTHORED_MEDIA_PARTS.to_double())),
  )
  assert_eq(
    docx_limits.get("max_emitted_media_bytes"),
    Some(Json::number(@docx.MAX_AUTHORED_MEDIA_BYTES.to_double())),
  )
  assert_eq(
    template_limits.get("max_docx_story_ordinal"),
    Some(Json::number(@template.MAX_TEMPLATE_STORY_ORDINAL.to_double())),
  )
  assert_eq(
    template_limits.get("max_docx_path_ordinal_digits"),
    Some(Json::number(@template.MAX_TEMPLATE_PATH_ORDINAL_DIGITS.to_double())),
  )
}

///|
test "schema help emits versioned JSONL and unknown ids have bounded typed suggestions" {
  assert_true(resolve_help_query(Some("schemas"), None, None) is Schemas)
  guard resolve_help_query(Some("schema"), Some("xlsx.batch/1"), None)
    is Schema(id) else {
    fail("expected one schema query")
  }
  assert_eq(id, "xlsx.batch/1")
  let lines = records_for_query(Schema(id))
  guard lines is [Object(record)] else {
    fail("schema JSONL must be one input-contract record")
  }
  assert_eq(record.get("schema"), Some(Json::string(schema_input_contract)))
  assert_true(render_overview(true).contains("office help schemas"))
  try resolve_help_query(Some("schema"), Some("docx.batc/2"), None) catch {
    CliFailure(error) => {
      assert_eq(error.code, "office.unknown_schema")
      guard error.details is Some(Object(details)) &&
        details.get("suggestions") is Some(Array(suggestions)) else {
        fail("unknown schema must include suggestions")
      }
      assert_true(suggestions.length() <= input_contract_ids().length())
      assert_true(error.message.length() < 180)
    }
  } noraise {
    _ => fail("unknown schema should fail")
  }
}
