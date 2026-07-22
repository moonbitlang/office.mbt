///|
/// Contract tests for `parse_template_document`: the additive `regions`
/// member, its addressing forms, record gates, bounds, and the
/// disjoint-union rule. Every refusal pins the exact message — a reject
/// helper that only checks "some error" passes vacuously.

///|
fn expect_document_error(
  text : String,
  expected : String,
  max_keys? : Int = 4096,
  max_regions? : Int = 64,
  max_region_records? : Int = 4096,
  max_total_region_rows? : Int = 10000,
) -> Unit raise {
  try
    @template.parse_template_document(
      text,
      max_keys~,
      max_regions~,
      max_region_records~,
      max_total_region_rows~,
    )
  catch {
    @template.TemplateDataError(message) => assert_eq(message, expected)
  } noraise {
    _ => fail("expected refusal: " + expected)
  }
}

///|
test "document parser: scalar-only document yields empty regions" {
  let data = @template.parse_template_document(
    "{\"schema\": \"office.template.data/1\", \"values\": {\"name\": \"Ada\", \"count\": 3}}",
  )
  assert_eq(data.regions.length(), 0)
  assert_eq(data.values.size(), 2)
  assert_eq(data.values.get("name"), Some(@template.TextValue("Ada")))
  assert_eq(data.values.get("count"), Some(@template.NumberValue(3)))
}

///|
test "document parser: both addressing forms parse structurally" {
  let data = @template.parse_template_document(
    "{\"schema\": \"office.template.data/1\", \"values\": {\"title\": \"Invoice\"}, " +
    "\"regions\": {" +
    "\"items\": {\"sheet\": \"Line Items\", \"row\": 5, \"records\": [" +
    "{\"item\": \"Widget\", \"qty\": 2}, {\"item\": \"Gadget\", \"qty\": 1}]}, " +
    "\"terms\": {\"path\": \"/docx/body/tbl[1]/tr[2]\", \"records\": [{\"term\": \"Net 30\"}]}" +
    "}}",
  )
  assert_eq(data.regions.length(), 2)
  // document order is preserved
  assert_eq(data.regions[0].name, "items")
  assert_eq(data.regions[1].name, "terms")
  assert_eq(
    data.regions[0].address,
    @template.SheetRow(sheet="Line Items", row=5),
  )
  assert_eq(
    data.regions[1].address,
    @template.TableRow(story=@template.BodyStory, table=1, row=2),
  )
  assert_eq(data.regions[0].records.length(), 2)
  assert_eq(
    data.regions[0].records[1].get("item"),
    Some(@template.TextValue("Gadget")),
  )
  assert_eq(data.regions[1].records.length(), 1)
}

///|
test "document parser: header and footer table paths parse; merge layers decide support" {
  let data = @template.parse_template_document(
    "{\"schema\": \"office.template.data/1\", \"values\": {}, " +
    "\"regions\": {" +
    "\"a\": {\"path\": \"/docx/header[2]/tbl[1]/tr[1]\", \"records\": [{\"k\": 1}]}, " +
    "\"b\": {\"path\": \"/docx/footer[1]/tbl[3]/tr[4]\", \"records\": [{\"k\": 2}]}" +
    "}}",
  )
  assert_eq(
    data.regions[0].address,
    @template.TableRow(story=@template.HeaderStory(2), table=1, row=1),
  )
  assert_eq(
    data.regions[1].address,
    @template.TableRow(story=@template.FooterStory(1), table=3, row=4),
  )
}

///|
test "document parser: scalar parser still rejects regions (staged rollout stays truthful)" {
  try
    @template.parse_template_data(
      "{\"schema\": \"office.template.data/1\", \"values\": {}, \"regions\": {}}",
    )
  catch {
    @template.TemplateDataError(message) =>
      assert_eq(
        message, "unknown top-level member \"regions\" (expected schema, values)",
      )
  } noraise {
    _ => fail("scalar parser must reject a regions member")
  }
}

///|
test "document parser: addressing refusals" {
  let head = "{\"schema\": \"office.template.data/1\", \"values\": {}, \"regions\": {\"items\": {"
  let tail = ", \"records\": [{\"k\": 1}]}}}"
  expect_document_error(
    head +
    "\"sheet\": \"S\", \"row\": 1, \"path\": \"/docx/body/tbl[1]/tr[1]\"" +
    tail,
    "region \"items\" mixes addressing forms; use sheet+row or path, not both",
  )
  expect_document_error(
    head + "\"sheet\": \"S\"" + tail,
    "region \"items\" needs an address: sheet+row together, or path",
  )
  expect_document_error(
    head + "\"row\": 1" + tail,
    "region \"items\" needs an address: sheet+row together, or path",
  )
  expect_document_error(
    "{\"schema\": \"office.template.data/1\", \"values\": {}, \"regions\": {\"items\": {\"records\": [{\"k\": 1}]}}}",
    "region \"items\" needs an address: sheet+row together, or path",
  )
  expect_document_error(
    head + "\"sheet\": 7, \"row\": 1" + tail,
    "region \"items\" sheet must be a non-empty string",
  )
  expect_document_error(
    head + "\"sheet\": \"\", \"row\": 1" + tail,
    "region \"items\" sheet must be a non-empty string",
  )
  expect_document_error(
    head + "\"sheet\": \"S\", \"row\": \"5\"" + tail,
    "region \"items\" row must be a number",
  )
  // lexical strictness: spellings that ROUND to an in-range integer are
  // rejected too (1048576.0000000001 parses to exactly 1048576.0; "5.0"
  // and "1e3" denote integers but are not plain integer literals)
  for
    bad_row in [
      "0", "-3", "5.5", "1e300", "1048577", "5.0", "1e3", "5.0000000000000001", "1048576.0000000001",
    ] {
    expect_document_error(
      head + "\"sheet\": \"S\", \"row\": " + bad_row + tail,
      "region \"items\" row must be an integer between 1 and 1048576",
    )
  }
  expect_document_error(
    head + "\"path\": 9" + tail,
    "region \"items\" path must be a string",
  )
  for
    bad_path in [
      "docx/body/tbl[1]/tr[1]", "/docx/body/tbl[0]/tr[1]", "/docx/body/tbl[1]", "/docx/body/tbl[1]/tr[1]/extra",
      "/docx/body/tbl[1]/tr[01]", "/docx/body/tbl[12345678]/tr[1]", "/docx/header/tbl[1]/tr[1]",
      "/docx/header[100]/tbl[1]/tr[1]", "/docx/section[1]/tbl[1]/tr[1]", "/xlsx/body/tbl[1]/tr[1]",
      "/docx/body/p[1]", "",
    ] {
    expect_document_error(
      head + "\"path\": \"" + bad_path + "\"" + tail,
      "region \"items\" path \"" +
      bad_path +
      "\" is not a table-row path (/docx/body/tbl[N]/tr[M])",
    )
  }
}

///|
test "document parser: regions container refusals" {
  expect_document_error(
    "{\"schema\": \"office.template.data/1\", \"values\": {}, \"regions\": []}",
    "regions must be an object of named regions",
  )
  // an array-shaped regions member reports the structural error even when
  // an item carries a lexically bad "row" — the raw gate speaks only for
  // real named regions (array items have no name)
  expect_document_error(
    "{\"schema\": \"office.template.data/1\", \"values\": {}, \"regions\": [{\"row\": 5.5}]}",
    "regions must be an object of named regions",
  )
  expect_document_error(
    "{\"schema\": \"office.template.data/1\", \"values\": {}, \"regions\": {}}",
    "regions must name at least one region when present",
  )
  expect_document_error(
    "{\"schema\": \"office.template.data/1\", \"values\": {}, \"regions\": {" +
    "\"a\": {\"sheet\": \"S\", \"row\": 1, \"records\": [{\"k\": 1}]}, " +
    "\"b\": {\"sheet\": \"S\", \"row\": 2, \"records\": [{\"k\": 1}]}, " +
    "\"c\": {\"sheet\": \"S\", \"row\": 3, \"records\": [{\"k\": 1}]}}}",
    "regions carries 3 entries; the limit is 2",
    max_regions=2,
  )
  expect_document_error(
    "{\"schema\": \"office.template.data/1\", \"values\": {}, \"regions\": {" +
    "\"bad name\": {\"sheet\": \"S\", \"row\": 1, \"records\": [{\"k\": 1}]}}}",
    "region name \"bad name\" is outside the placeholder key grammar",
  )
  expect_document_error(
    "{\"schema\": \"office.template.data/1\", \"values\": {}, \"regions\": {\"items\": 5}}",
    "region \"items\" must be an object",
  )
  expect_document_error(
    "{\"schema\": \"office.template.data/1\", \"values\": {}, \"regions\": {" +
    "\"items\": {\"sheet\": \"S\", \"row\": 1, \"records\": [{\"k\": 1}], \"repeat\": true}}}",
    "region \"items\" has unknown member \"repeat\" (expected sheet, row, path, records)",
  )
}

///|
test "document parser: records refusals and bounds" {
  let head = "{\"schema\": \"office.template.data/1\", \"values\": {}, \"regions\": {\"items\": {\"sheet\": \"S\", \"row\": 1"
  expect_document_error(
    head + "}}}",
    "region \"items\" needs a \"records\" array",
  )
  expect_document_error(
    head + ", \"records\": {\"k\": 1}}}}",
    "region \"items\" needs a \"records\" array",
  )
  expect_document_error(
    head + ", \"records\": []}}}",
    "region \"items\" records must not be empty (row deletion is out of scope)",
  )
  expect_document_error(
    head + ", \"records\": [{\"k\": 1}, {\"k\": 2}, {\"k\": 3}]}}}",
    "region \"items\" carries 3 records; the limit is 2",
    max_region_records=2,
  )
  expect_document_error(
    "{\"schema\": \"office.template.data/1\", \"values\": {}, \"regions\": {" +
    "\"a\": {\"sheet\": \"S\", \"row\": 1, \"records\": [{\"k\": 1}, {\"k\": 2}]}, " +
    "\"b\": {\"sheet\": \"S\", \"row\": 9, \"records\": [{\"k\": 1}, {\"k\": 2}]}}}",
    "regions write 4 rows in total; the limit is 3",
    max_total_region_rows=3,
  )
  expect_document_error(
    head + ", \"records\": [7]}}}",
    "region \"items\" record 0 must be an object",
  )
}

///|
test "document parser: record content shares the scalar gates" {
  let head = "{\"schema\": \"office.template.data/1\", \"values\": {}, \"regions\": {\"items\": {\"sheet\": \"S\", \"row\": 1, \"records\": ["
  let tail = "]}}}"
  expect_document_error(
    head + "{\"bad key\": 1}" + tail,
    "region \"items\" record 0: value key \"bad key\" is outside the placeholder key grammar",
  )
  expect_document_error(
    head + "{\"k\": null}" + tail,
    "region \"items\" record 0: value for \"k\" is null; only string, number, and boolean values are supported",
  )
  expect_document_error(
    head + "{\"k\": [1]}" + tail,
    "region \"items\" record 0: value for \"k\" is not a scalar; only string, number, and boolean values are supported",
  )
  expect_document_error(
    head + "{\"k\": 1e309}" + tail,
    "region \"items\" record 0: value for \"k\" is not a finite number",
  )
}

///|
test "document parser: record string bounds use the shared limit" {
  try
    @template.parse_template_document(
      "{\"schema\": \"office.template.data/1\", \"values\": {}, \"regions\": {" +
      "\"items\": {\"sheet\": \"S\", \"row\": 1, \"records\": [{\"k\": \"ab\"}]}}}",
      max_value_units=1,
    )
  catch {
    @template.TemplateDataError(message) =>
      assert_eq(
        message, "region \"items\" record 0: value for \"k\" exceeds 1 units",
      )
  } noraise {
    _ => fail("expected the record string to exceed the unit bound")
  }
}

///|
test "document parser: duplicates win over the lexical row gate" {
  // the gate defers until the whole scan completes, so a bad first "row"
  // followed by a duplicate still reports the duplicate (codex round 2)
  expect_document_error(
    "{\"schema\": \"office.template.data/1\", \"values\": {}, \"regions\": {" +
    "\"items\": {\"sheet\": \"S\", \"row\": 5.5, \"row\": 5, \"records\": [{\"k\": 1}]}}}",
    "duplicate key in the data document",
  )
}

///|
test "document parser: duplicate keys are rejected inside records and region names" {
  expect_document_error(
    "{\"schema\": \"office.template.data/1\", \"values\": {}, \"regions\": {" +
    "\"items\": {\"sheet\": \"S\", \"row\": 1, \"records\": [{\"k\": 1, \"k\": 2}]}}}",
    "duplicate key in the data document",
  )
  expect_document_error(
    "{\"schema\": \"office.template.data/1\", \"values\": {}, \"regions\": {" +
    "\"items\": {\"sheet\": \"S\", \"row\": 1, \"records\": [{\"k\": 1}]}, " +
    "\"items\": {\"sheet\": \"S\", \"row\": 2, \"records\": [{\"k\": 1}]}}}",
    "duplicate key in the data document",
  )
}

///|
test "document parser: values and record keys are a disjoint union" {
  expect_document_error(
    "{\"schema\": \"office.template.data/1\", \"values\": {\"qty\": 1}, \"regions\": {" +
    "\"items\": {\"sheet\": \"S\", \"row\": 1, \"records\": [{\"item\": \"a\"}, {\"qty\": 2}]}}}",
    "key \"qty\" appears in values and in region \"items\" record 1; region record keys must not collide with values",
  )
  // keys repeating across records of one region — or across regions — are fine
  let data = @template.parse_template_document(
    "{\"schema\": \"office.template.data/1\", \"values\": {\"title\": \"T\"}, \"regions\": {" +
    "\"a\": {\"sheet\": \"S\", \"row\": 1, \"records\": [{\"k\": 1}, {\"k\": 2}]}, " +
    "\"b\": {\"sheet\": \"S\", \"row\": 9, \"records\": [{\"k\": 3}]}}}",
  )
  assert_eq(data.regions.length(), 2)
}

///|
test "document parser: top-level contract matches the scalar parser" {
  expect_document_error(
    "{\"schema\": \"office.template.data/1\", \"values\": {}, \"extra\": 1}", "unknown top-level member \"extra\" (expected schema, values, regions)",
  )
  expect_document_error(
    "{\"values\": {}}", "data document needs \"schema\": \"office.template.data/1\"",
  )
  expect_document_error("[1]", "data document must be a JSON object")
  expect_document_error("{", "data document is not valid JSON")
}
