///|
fn parse_str(script : String) -> @batch.BatchScript raise {
  @batch.parse_batch(@json.parse(script))
}

///|
fn expect_batch_error(script : String, expected_prefix : String) -> Unit raise {
  try {
    let _ = parse_str(script)
  } catch {
    @batch.BatchError(message) =>
      if !message.has_prefix(expected_prefix) {
        fail("unexpected message: \{message}")
      }
    err => fail("expected BatchError, got \{repr(err)}")
  } noraise {
    _ => fail("expected the script to be rejected")
  }
}

///|
test "strict validation names the op index and key" {
  expect_batch_error("[]", "the script must be a JSON object")
  expect_batch_error(
    (
      #|{"schema": "docx.batch/2", "ops": []}
    ),
    "unsupported schema 'docx.batch/2'",
  )
  expect_batch_error(
    (
      #|{"schema": "docx.batch/1", "ops": [], "extra": 1}
    ),
    "the script has an unknown key 'extra'",
  )
  expect_batch_error(
    (
      #|{"schema": "docx.batch/1", "ops": [{"op": "chart", "params": {}}]}
    ),
    "ops[0].op 'chart' is unknown",
  )
  expect_batch_error(
    (
      #|{"schema": "docx.batch/1", "ops": [{"op": "paragraph", "params": {"text": "a", "bogus": 1}}]}
    ),
    "ops[0].params has an unknown key 'bogus'",
  )
  expect_batch_error(
    (
      #|{"schema": "docx.batch/1", "ops": [{"op": "paragraph", "params": {"runs": [{"text": "a", "bold": "yes"}]}}]}
    ),
    "ops[0].params.runs[0].bold must be a boolean",
  )
  expect_batch_error(
    (
      #|{"schema": "docx.batch/1", "ops": [{"op": "paragraph", "params": {"runs": [{"link": {"runs": [{"link": {"text": "x"}}]}}]}}]}
    ),
    "ops[0].params.runs[0].link.runs[0]: links cannot nest inside links",
  )
  expect_batch_error(
    (
      #|{"schema": "docx.batch/1", "ops": [{"op": "paragraph", "params": {"runs": [{"image": {"path": "logo.bmp"}}]}}]}
    ),
    "ops[0].params.runs[0].image: cannot infer the content type from 'logo.bmp'",
  )
}

///|
test "a full script parses and builds the expected body" {
  let script = parse_str(
    (
      #|{
      #|  "schema": "docx.batch/1",
      #|  "ops": [
      #|    {"op": "paragraph", "params": {"text": "Title", "style": "Heading1"}},
      #|    {"op": "paragraph", "params": {"runs": [
      #|      {"text": "bold", "bold": true},
      #|      {"link": {"href": "https://example.com", "text": "site"}},
      #|      {"image": {"path": "dot.png", "alt": "a dot"}}
      #|    ], "align": "center"}},
      #|    {"op": "paragraph", "params": {"text": "item", "list": {"ordered": true, "level": 2}}},
      #|    {"op": "table", "params": {"header_rows": 1, "rows": [
      #|      [{"text": "H1"}, {"text": "H2"}],
      #|      [{"text": "wide", "col_span": 2}]
      #|    ]}}
      #|  ]
      #|}
    ),
  )
  debug_inspect(script.op_count(), content="4")
  debug_inspect(
    script.image_paths(),
    content=(
      #|["dot.png"]
    ),
  )
  let body = script.build_body({ "dot.png": b"\x89PNG fake" })
  debug_inspect(body.length(), content="4")
  guard body[0] is Paragraph(properties~, ..)
  debug_inspect(properties.style_id, content="Some(\"Heading1\")")
  guard body[2] is Paragraph(properties=list_props, ..)
  debug_inspect(
    list_props.numbering,
    content=(
      #|Some({ is_ordered: true, level: 2 })
    ),
  )
  guard body[3] is Table(children~, ..)
  guard children is [TableRow(is_header~, ..), _]
  debug_inspect(is_header, content="true")
}

///|
test "missing image bytes fail closed at build time" {
  let script = parse_str(
    (
      #|{"schema": "docx.batch/1", "ops": [{"op": "paragraph", "params": {"runs": [{"image": {"path": "gone.png"}}]}}]}
    ),
  )
  try {
    let _ = script.build_body(Map([]))
  } catch {
    BatchError(message) =>
      inspect(
        message.has_prefix("image bytes for 'gone.png' were not provided"),
        content="true",
      )
  } noraise {
    _ => fail("expected build to fail")
  }
}
