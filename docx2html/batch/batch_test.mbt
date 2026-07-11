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
      #|{"schema": "docx.batch/1", "ops": [{"op": "paragraph", "params": {"runs": [{"link": {"href": "https://a.example", "runs": [{"link": {"href": "https://b.example", "text": "x"}}]}}]}}]}
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
        message ==
        "ops[0].params.runs[0].image.path: image bytes for 'gone.png' were not provided",
        content="true",
      )
  } noraise {
    _ => fail("expected build to fail")
  }
}

///|
test "review round 2: numbers must be exact in-range integers" {
  // Truncation like 2.9 -> 2 must never happen silently.
  expect_batch_error(
    (
      #|{"schema": "docx.batch/1", "ops": [{"op": "paragraph", "params": {"text": "a", "list": {"ordered": true, "level": 2.9}}}]}
    ),
    "ops[0].params.list.level must be an integer",
  )
  expect_batch_error(
    (
      #|{"schema": "docx.batch/1", "ops": [{"op": "paragraph", "params": {"text": "a", "list": {"ordered": true, "level": 10}}}]}
    ),
    "ops[0].params.list.level must be between 1 and 9",
  )
  expect_batch_error(
    (
      #|{"schema": "docx.batch/1", "ops": [{"op": "paragraph", "params": {"runs": [{"text": "a", "size": 0}]}}]}
    ),
    "ops[0].params.runs[0].size must be between 1 and 1638",
  )
  expect_batch_error(
    (
      #|{"schema": "docx.batch/1", "ops": [{"op": "paragraph", "params": {"runs": [{"text": "a", "size": 1639}]}}]}
    ),
    "ops[0].params.runs[0].size must be between 1 and 1638",
  )
  expect_batch_error(
    (
      #|{"schema": "docx.batch/1", "ops": [{"op": "table", "params": {"rows": [[{"text": "a", "col_span": 2147483647}]]}}]}
    ),
    "ops[0].params.rows[0][0].col_span must be between 1 and 63",
  )
  expect_batch_error(
    (
      #|{"schema": "docx.batch/1", "ops": [{"op": "table", "params": {"rows": [[{"text": "a", "row_span": 0}]]}}]}
    ),
    "ops[0].params.rows[0][0].row_span must be between 1 and 10000",
  )
  expect_batch_error(
    (
      #|{"schema": "docx.batch/1", "ops": [{"op": "table", "params": {"header_rows": -1, "rows": [[{"text": "a"}]]}}]}
    ),
    "ops[0].params.header_rows must be between 0 and 1",
  )
  expect_batch_error(
    (
      #|{"schema": "docx.batch/1", "ops": [{"op": "table", "params": {"header_rows": 2, "rows": [[{"text": "a"}]]}}]}
    ),
    "ops[0].params.header_rows must be between 0 and 1",
  )
}

///|
test "review round 2: enums, blanks, and XOR shapes are rejected with exact addresses" {
  expect_batch_error(
    (
      #|{"schema": "docx.batch/1", "ops": [{"op": "paragraph", "params": {"text": "a", "style": "Heading7"}}]}
    ),
    "ops[0].params.style 'Heading7' is unknown",
  )
  expect_batch_error(
    (
      #|{"schema": "docx.batch/1", "ops": [{"op": "paragraph", "params": {"text": "a", "style": ""}}]}
    ),
    "ops[0].params.style '' is unknown",
  )
  expect_batch_error(
    (
      #|{"schema": "docx.batch/1", "ops": [{"op": "paragraph", "params": {"text": "a", "align": "justify"}}]}
    ),
    "ops[0].params.align 'justify' is unknown",
  )
  expect_batch_error(
    (
      #|{"schema": "docx.batch/1", "ops": [{"op": "paragraph", "params": {"runs": [{"text": "a", "highlight": "banana"}]}}]}
    ),
    "ops[0].params.runs[0].highlight 'banana' is not an ST_HighlightColor name",
  )
  expect_batch_error(
    (
      #|{"schema": "docx.batch/1", "ops": [{"op": "paragraph", "params": {"runs": [{"text": "a", "font": ""}]}}]}
    ),
    "ops[0].params.runs[0].font must not be empty",
  )
  expect_batch_error(
    (
      #|{"schema": "docx.batch/1", "ops": [{"op": "paragraph", "params": {}}]}
    ),
    "ops[0].params needs text or runs",
  )
  expect_batch_error(
    (
      #|{"schema": "docx.batch/1", "ops": [{"op": "paragraph", "params": {"runs": []}}]}
    ),
    "ops[0].params.runs must not be empty",
  )
  expect_batch_error(
    (
      #|{"schema": "docx.batch/1", "ops": [{"op": "paragraph", "params": {"list": {"level": 2}, "text": "a"}}]}
    ),
    "ops[0].params.list needs \"ordered\"",
  )
  expect_batch_error(
    (
      #|{"schema": "docx.batch/1", "ops": [{"op": "table", "params": {"rows": []}}]}
    ),
    "ops[0].params.rows must not be empty",
  )
  expect_batch_error(
    (
      #|{"schema": "docx.batch/1", "ops": [{"op": "table", "params": {"rows": [[]]}}]}
    ),
    "ops[0].params.rows[0] must have at least one cell",
  )
  expect_batch_error(
    (
      #|{"schema": "docx.batch/1", "ops": [{"op": "table", "params": {"rows": [[{}]]}}]}
    ),
    "ops[0].params.rows[0][0] needs text or paragraphs",
  )
  expect_batch_error(
    (
      #|{"schema": "docx.batch/1", "ops": [{"op": "table", "params": {"rows": [[{"paragraphs": []}]]}}]}
    ),
    "ops[0].params.rows[0][0].paragraphs must not be empty",
  )
  expect_batch_error(
    (
      #|{"schema": "docx.batch/1", "ops": [{"op": "paragraph", "params": {"runs": [{"link": {"href": "https://a.example", "anchor": "top", "text": "x"}}]}}]}
    ),
    "ops[0].params.runs[0].link: href and anchor are mutually exclusive",
  )
  expect_batch_error(
    (
      #|{"schema": "docx.batch/1", "ops": [{"op": "paragraph", "params": {"runs": [{"link": {"text": "x"}}]}}]}
    ),
    "ops[0].params.runs[0].link needs an href or an anchor",
  )
  expect_batch_error(
    (
      #|{"schema": "docx.batch/1", "ops": [{"op": "paragraph", "params": {"runs": [{"link": {"href": "", "text": "x"}}]}}]}
    ),
    "ops[0].params.runs[0].link.href must not be empty",
  )
  expect_batch_error(
    (
      #|{"schema": "docx.batch/1", "ops": [{"op": "paragraph", "params": {"runs": [{"image": {"path": "a.png", "content_type": "image/bmp"}}]}}]}
    ),
    "ops[0].params.runs[0].image.content_type 'image/bmp' is unsupported",
  )
  expect_batch_error(
    (
      #|{"schema": "docx.batch/1", "ops": [{"op": "paragraph", "params": {"runs": [{"image": {"path": "a.png", "alt": "  "}}]}}]}
    ),
    "ops[0].params.runs[0].image.alt must not be blank",
  )
  // XML-illegal control characters cannot survive serialization; the JSON
  // escapes decode to real controls before validation sees them.
  expect_batch_error(
    (
      #|{"schema": "docx.batch/1", "ops": [{"op": "paragraph", "params": {"text": "a\u0001b"}}]}
    ),
    "ops[0].params.text contains an unserializable control character (code 1)",
  )
  expect_batch_error(
    (
      #|{"schema": "docx.batch/1", "ops": [{"op": "paragraph", "params": {"text": "a\nb"}}]}
    ),
    "ops[0].params.text contains an unserializable control character (code 10)",
  )
}

///|
test "review round 2: duplicate keys are refused, not last-wins" {
  fn expect_duplicate(script : String, key : String) raise {
    try @batch.check_duplicate_keys(script) catch {
      BatchError(message) =>
        if !message.has_prefix("the script repeats the key \"\{key}\"") {
          fail("unexpected message: \{message}")
        }
    } noraise {
      _ => fail("expected duplicate key '\{key}' to be refused")
    }
  }

  expect_duplicate(
    (
      #|{"schema": "docx.batch/1", "schema": "docx.batch/1", "ops": []}
    ),
    "schema",
  )
  expect_duplicate(
    (
      #|{"schema": "docx.batch/1", "ops": [{"op": "paragraph", "op": "table", "params": {"text": "a"}}]}
    ),
    "op",
  )
  // The same key on DIFFERENT objects is fine, as are key-looking strings
  // in value or array position.
  @batch.check_duplicate_keys(
    (
      #|{"schema": "docx.batch/1", "ops": [{"op": "paragraph", "params": {"text": "op"}}, {"op": "paragraph", "params": {"runs": [{"text": "text"}, {"text": "text"}]}}]}
    ),
  )
  // Escapes inside strings do not desync the scanner.
  @batch.check_duplicate_keys(
    (
      #|{"schema": "docx.batch/1", "ops": [{"op": "paragraph", "params": {"text": "quote \" and slash \\"}}]}
    ),
  )
}

///|
test "review round 2: the ops cap is enforced at 10000" {
  fn script_with_ops(count : Int) -> String {
    let builder = StringBuilder::new()
    builder.write_string(
      (
        #|{"schema": "docx.batch/1", "ops": [
      ),
    )
    for index in 0..<count {
      if index > 0 {
        builder.write_string(",")
      }
      builder.write_string(
        (
          #|{"op": "paragraph", "params": {"text": "x"}}
        ),
      )
    }
    builder.write_string("]}")
    builder.to_string()
  }

  let at_cap = parse_str(script_with_ops(10000))
  debug_inspect(at_cap.op_count(), content="10000")
  expect_batch_error(
    script_with_ops(10001),
    "the script has 10001 ops; the cap is 10000",
  )
}
