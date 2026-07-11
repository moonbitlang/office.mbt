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
      #|{"schema": "docx.batch/3", "ops": []}
    ),
    "unsupported schema 'docx.batch/3' (this build accepts docx.batch/1 and docx.batch/2)",
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
    "ops[0].params.rows[0][0].row_span must be between 1 and 1",
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
fn expect_script_text_error(
  script : String,
  expected_prefix : String,
) -> Unit raise {
  try @batch.check_script_text(script) catch {
    BatchError(message) =>
      if !message.has_prefix(expected_prefix) {
        fail("unexpected message: \{message}")
      }
  } noraise {
    _ => fail("expected the script text to be refused: \{expected_prefix}")
  }
}

///|
test "review round 2: duplicate keys are refused with the object's path" {
  expect_script_text_error(
    (
      #|{"schema": "docx.batch/1", "schema": "docx.batch/1", "ops": []}
    ),
    "the script repeats the key \"schema\"",
  )
  expect_script_text_error(
    (
      #|{"schema": "docx.batch/1", "ops": [{"op": "paragraph", "params": {"text": "a"}}, {"op": "paragraph", "op": "table", "params": {"text": "a"}}]}
    ),
    "ops[1] repeats the key \"op\"",
  )
  expect_script_text_error(
    (
      #|{"schema": "docx.batch/1", "ops": [{"op": "paragraph", "params": {"text": "a", "text": "b"}}]}
    ),
    "ops[0].params repeats the key \"text\"",
  )
  // The same key on DIFFERENT objects is fine, as are key-looking strings
  // in value or array position.
  @batch.check_script_text(
    (
      #|{"schema": "docx.batch/1", "ops": [{"op": "paragraph", "params": {"text": "op"}}, {"op": "paragraph", "params": {"runs": [{"text": "text"}, {"text": "text"}]}}]}
    ),
  )
  // Escapes inside strings do not desync the scanner.
  @batch.check_script_text(
    (
      #|{"schema": "docx.batch/1", "ops": [{"op": "paragraph", "params": {"text": "quote \" and slash \\"}}]}
    ),
  )
}

///|
test "review round 3: escape-equivalent and astral key spellings are caught" {
  // "\u006f\u0070" decodes to "op" — @json.parse would collapse them
  // last-wins; the scanner must compare DECODED keys.
  expect_script_text_error(
    (
      #|{"schema": "docx.batch/1", "ops": [{"op": "paragraph", "\u006f\u0070": "table", "params": {"text": "a"}}]}
    ),
    "ops[0] repeats the key \"op\"",
  )
  // A raw astral key and its escaped surrogate-pair spelling collide, and
  // the scanner advances correctly across the raw pair.
  expect_script_text_error(
    (
      #|{"😀": 1, "\ud83d\ude00": 2}
    ),
    "the script repeats the key \"😀\"",
  )
  // Astral keys that differ do not collide.
  @batch.check_script_text(
    (
      #|{"😀": 1, "😁": 2}
    ),
  )
}

///|
test "review round 4: key comparison is lossless over UTF-16 units" {
  // DISTINCT lone surrogates are distinct keys to @json.parse and must
  // not be folded into a false duplicate.
  @batch.check_script_text(
    (
      #|{"\ud800": 1, "\ud801": 2}
    ),
  )
  // ...and a lone surrogate does not collide with a literal U+FFFD key.
  @batch.check_script_text(
    (
      #|{"\ud800": 1, "�": 2}
    ),
  )
  // IDENTICAL lone surrogates do collide, rendered readably.
  expect_script_text_error(
    (
      #|{"\ud800": 1, "\ud800": 2}
    ),
    "the script repeats the key \"\\uD800\"",
  )
  // Escaped surrogate-pair spellings compare by unit sequence, so the
  // duplicate renders as the recombined character.
  expect_script_text_error(
    (
      #|{"\ud83d\ude00": 1, "\ud83d\ude00": 2}
    ),
    "the script repeats the key \"😀\"",
  )
}

///|
test "review round 3: number lexemes must be plain decimal integers" {
  expect_script_text_error(
    (
      #|{"schema": "docx.batch/1", "ops": [{"op": "paragraph", "params": {"runs": [{"text": "a", "size": 0.999999999999999999999999}]}}]}
    ),
    "ops[0].params.runs[0].size must be a plain decimal integer",
  )
  expect_script_text_error(
    (
      #|{"schema": "docx.batch/1", "ops": [{"op": "table", "params": {"header_rows": 1e2, "rows": [[{"text": "a"}]]}}]}
    ),
    "ops[0].params.header_rows must be a plain decimal integer",
  )
  expect_script_text_error(
    (
      #|{"schema": "docx.batch/1", "ops": [{"op": "paragraph", "params": {"text": "a", "list": {"ordered": true, "level": 2.9}}}]}
    ),
    "ops[0].params.list.level must be a plain decimal integer",
  )
  // Plain integers (including negative ones) pass the lexical layer; range
  // checks live in the parser.
  @batch.check_script_text(
    (
      #|{"schema": "docx.batch/1", "ops": [{"op": "table", "params": {"header_rows": -1, "rows": [[{"text": "a"}]]}}]}
    ),
  )
}

///|
test "review round 3: XML-unrepresentable characters and highlight 'none' are rejected" {
  // A lone escaped surrogate parses into the string; the text guard
  // rejects it before the writer would abort in UTF-8 encoding.
  expect_batch_error(
    (
      #|{"schema": "docx.batch/1", "ops": [{"op": "paragraph", "params": {"text": "a\ud800b"}}]}
    ),
    "ops[0].params.text contains a character XML cannot represent (code 55296",
  )
  expect_batch_error(
    (
      #|{"schema": "docx.batch/1", "ops": [{"op": "paragraph", "params": {"text": "a\uffffb"}}]}
    ),
    "ops[0].params.text contains a character XML cannot represent (code 65535",
  )
  expect_batch_error(
    (
      #|{"schema": "docx.batch/1", "ops": [{"op": "paragraph", "params": {"runs": [{"link": {"href": "https://a.example/\uffff", "text": "x"}}]}}]}
    ),
    "ops[0].params.runs[0].link.href contains a character XML cannot represent",
  )
  // 'none' is normalized to absent by the reader, so it cannot round-trip.
  expect_batch_error(
    (
      #|{"schema": "docx.batch/1", "ops": [{"op": "paragraph", "params": {"runs": [{"text": "a", "highlight": "none"}]}}]}
    ),
    "ops[0].params.runs[0].highlight: omit the key instead of 'none'",
  )
}

///|
test "review round 3: row_span is bounded by the remaining rows, like the writer" {
  expect_batch_error(
    (
      #|{"schema": "docx.batch/1", "ops": [{"op": "table", "params": {"rows": [[{"text": "a"}], [{"text": "tall", "row_span": 2}]]}}]}
    ),
    "ops[0].params.rows[1][0].row_span must be between 1 and 1",
  )
  // A span filling the whole table from row 0 is fine.
  let script = parse_str(
    (
      #|{"schema": "docx.batch/1", "ops": [{"op": "table", "params": {"rows": [[{"text": "tall", "row_span": 2}, {"text": "b"}], [{"text": "b2"}]]}}]}
    ),
  )
  debug_inspect(script.op_count(), content="1")
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

///|
test "K1: docx.batch/2 comment ops parse, map op indexes to block indexes" {
  let script = parse_str(
    (
      #|{"schema": "docx.batch/2", "ops": [
      #|  {"op": "paragraph", "params": {"text": "First"}},
      #|  {"op": "comment", "params": {"on": 0, "text": "A note",
      #|   "author": "Reviewer", "initials": "R", "date": "2026-07-11T09:30:00Z"}},
      #|  {"op": "paragraph", "params": {"text": "Second"}},
      #|  {"op": "table", "params": {"rows": [[{"text": "cell"}]]}},
      #|  {"op": "paragraph", "params": {"text": "Third"}},
      #|  {"op": "comment", "params": {"on": {"from": 2, "to": 4},
      #|   "paragraphs": [{"text": "Multi,"}, {"text": "paragraph."}],
      #|   "author": "B"}}
      #|]}
    ),
  )
  // Comment ops are ops (op_count) but produce no body blocks: the body
  // has 4 blocks and anchors are BLOCK indexes (the table at op 3 is
  // block 2, so op 4 is block 3 — comments in between shift nothing).
  inspect(script.op_count(), content="6")
  inspect(script.comment_count(), content="2")
  inspect(script.build_body(Map([])).length(), content="4")
  let comments = script.build_comments()
  inspect(comments.length(), content="2")
  let point = comments[0]
  inspect(point.at(), content="ops[1]")
  inspect(point.author(), content="Reviewer")
  debug_inspect(point.initials(), content="Some(\"R\")")
  debug_inspect(point.date(), content="Some(\"2026-07-11T09:30:00Z\")")
  debug_inspect(point.from_block(), content="Some(0)")
  debug_inspect(point.to_block(), content="Some(0)")
  debug_inspect(point.reply_to(), content="None")
  debug_inspect(point.done(), content="None")
  inspect(point.body().length(), content="1")
  let range = comments[1]
  inspect(range.at(), content="ops[5]")
  inspect(range.author(), content="B")
  debug_inspect(range.initials(), content="None")
  debug_inspect(range.date(), content="None")
  // op 2 -> block 1; op 4 -> block 3: the range passes OVER the table.
  debug_inspect(range.from_block(), content="Some(1)")
  debug_inspect(range.to_block(), content="Some(3)")
  inspect(range.body().length(), content="2")
  // The reverse mapping (block -> script op) that writer-failure
  // attribution uses: comment ops produce no blocks.
  debug_inspect(script.block_op(0), content="Some(0)")
  debug_inspect(script.block_op(1), content="Some(2)")
  debug_inspect(script.block_op(2), content="Some(3)")
  debug_inspect(script.block_op(3), content="Some(4)")
  debug_inspect(script.block_op(4), content="None")
  // The date is NOT validated here — lexical xsd:dateTime is the
  // writer's job (attributed to the op via at()); any string parses.
  let lax = parse_str(
    (
      #|{"schema": "docx.batch/2", "ops": [
      #|  {"op": "paragraph", "params": {"text": "x"}},
      #|  {"op": "comment", "params": {"on": 0, "text": "n", "author": "A",
      #|   "date": "not-a-date"}}
      #|]}
    ),
  )
  debug_inspect(lax.build_comments()[0].date(), content="Some(\"not-a-date\")")
}

///|
test "K1: comment ops fail closed with exact op addresses" {
  // Version gate: /1 scripts cannot carry comments.
  expect_batch_error(
    (
      #|{"schema": "docx.batch/1", "ops": [
      #|  {"op": "paragraph", "params": {"text": "x"}},
      #|  {"op": "comment", "params": {"on": 0, "text": "n", "author": "A"}}
      #|]}
    ),
    "ops[1].op 'comment' needs \"schema\": \"docx.batch/2\"",
  )
  // WHO: author is required, non-empty, attribute-safe; initials likewise.
  expect_batch_error(
    (
      #|{"schema": "docx.batch/2", "ops": [
      #|  {"op": "paragraph", "params": {"text": "x"}},
      #|  {"op": "comment", "params": {"on": 0, "text": "n"}}
      #|]}
    ),
    "ops[1].params needs \"author\"",
  )
  expect_batch_error(
    (
      #|{"schema": "docx.batch/2", "ops": [
      #|  {"op": "paragraph", "params": {"text": "x"}},
      #|  {"op": "comment", "params": {"on": 0, "text": "n", "author": ""}}
      #|]}
    ),
    "ops[1].params.author must not be empty",
  )
  expect_batch_error(
    (
      #|{"schema": "docx.batch/2", "ops": [
      #|  {"op": "paragraph", "params": {"text": "x"}},
      #|  {"op": "comment", "params": {"on": 0, "text": "n", "author": "A\tB"}}
      #|]}
    ),
    "ops[1].params.author contains a control character",
  )
  expect_batch_error(
    (
      #|{"schema": "docx.batch/2", "ops": [
      #|  {"op": "paragraph", "params": {"text": "x"}},
      #|  {"op": "comment", "params": {"on": 0, "text": "n", "author": "A", "initials": ""}}
      #|]}
    ),
    "ops[1].params.initials must not be empty",
  )
  expect_batch_error(
    (
      #|{"schema": "docx.batch/2", "ops": [
      #|  {"op": "paragraph", "params": {"text": "x"}},
      #|  {"op": "comment", "params": {"on": 0, "text": "n", "author": "A", "date": 5}}
      #|]}
    ),
    "ops[1].params.date must be a string",
  )
  // WHERE: earlier paragraph ops only.
  expect_batch_error(
    (
      #|{"schema": "docx.batch/2", "ops": [
      #|  {"op": "paragraph", "params": {"text": "x"}},
      #|  {"op": "comment", "params": {"text": "n", "author": "A"}}
      #|]}
    ),
    "ops[1].params needs \"on\"",
  )
  expect_batch_error(
    (
      #|{"schema": "docx.batch/2", "ops": [
      #|  {"op": "comment", "params": {"on": 0, "text": "n", "author": "A"}}
      #|]}
    ),
    "ops[0].params.on: ops[0] is the first op, so there is nothing earlier to anchor to",
  )
  expect_batch_error(
    (
      #|{"schema": "docx.batch/2", "ops": [
      #|  {"op": "paragraph", "params": {"text": "x"}},
      #|  {"op": "comment", "params": {"on": 1, "text": "n", "author": "A"}}
      #|]}
    ),
    "ops[1].params.on must reference an EARLIER op (0..0, got 1)",
  )
  expect_batch_error(
    (
      #|{"schema": "docx.batch/2", "ops": [
      #|  {"op": "paragraph", "params": {"text": "x"}},
      #|  {"op": "comment", "params": {"on": 5, "text": "n", "author": "A"}}
      #|]}
    ),
    "ops[1].params.on must reference an EARLIER op (0..0, got 5)",
  )
  expect_batch_error(
    (
      #|{"schema": "docx.batch/2", "ops": [
      #|  {"op": "table", "params": {"rows": [[{"text": "c"}]]}},
      #|  {"op": "comment", "params": {"on": 0, "text": "n", "author": "A"}}
      #|]}
    ),
    "ops[1].params.on targets a table (ops[0]); comment anchors must be paragraph ops",
  )
  expect_batch_error(
    (
      #|{"schema": "docx.batch/2", "ops": [
      #|  {"op": "paragraph", "params": {"text": "x"}},
      #|  {"op": "comment", "params": {"on": 0, "text": "n", "author": "A"}},
      #|  {"op": "comment", "params": {"on": 1, "text": "n", "author": "A"}}
      #|]}
    ),
    "ops[2].params.on targets another comment (ops[1]); comment anchors must be paragraph ops",
  )
  expect_batch_error(
    (
      #|{"schema": "docx.batch/2", "ops": [
      #|  {"op": "paragraph", "params": {"text": "x"}},
      #|  {"op": "paragraph", "params": {"text": "y"}},
      #|  {"op": "comment", "params": {"on": {"from": 1, "to": 0}, "text": "n", "author": "A"}}
      #|]}
    ),
    "ops[2].params.on: \"to\" (ops[0]) precedes \"from\" (ops[1]); the range is inclusive and must be ordered",
  )
  expect_batch_error(
    (
      #|{"schema": "docx.batch/2", "ops": [
      #|  {"op": "paragraph", "params": {"text": "x"}},
      #|  {"op": "comment", "params": {"on": {"from": 0}, "text": "n", "author": "A"}}
      #|]}
    ),
    "ops[1].params.on needs \"to\"",
  )
  expect_batch_error(
    (
      #|{"schema": "docx.batch/2", "ops": [
      #|  {"op": "paragraph", "params": {"text": "x"}},
      #|  {"op": "comment", "params": {"on": true, "text": "n", "author": "A"}}
      #|]}
    ),
    "ops[1].params.on must be an op index or {\"from\": i, \"to\": j}",
  )
  expect_batch_error(
    (
      #|{"schema": "docx.batch/2", "ops": [
      #|  {"op": "paragraph", "params": {"text": "x"}},
      #|  {"op": "comment", "params": {"on": 0.5, "text": "n", "author": "A"}}
      #|]}
    ),
    "ops[1].params.on must be an integer (got 0.5)",
  )
  // WHAT: exactly one of text/paragraphs, and plain content only.
  expect_batch_error(
    (
      #|{"schema": "docx.batch/2", "ops": [
      #|  {"op": "paragraph", "params": {"text": "x"}},
      #|  {"op": "comment", "params": {"on": 0, "author": "A"}}
      #|]}
    ),
    "ops[1].params needs text or paragraphs (the comment body)",
  )
  expect_batch_error(
    (
      #|{"schema": "docx.batch/2", "ops": [
      #|  {"op": "paragraph", "params": {"text": "x"}},
      #|  {"op": "comment", "params": {"on": 0, "text": "n", "paragraphs": [], "author": "A"}}
      #|]}
    ),
    "ops[1].params: text and paragraphs are mutually exclusive",
  )
  expect_batch_error(
    (
      #|{"schema": "docx.batch/2", "ops": [
      #|  {"op": "paragraph", "params": {"text": "x"}},
      #|  {"op": "comment", "params": {"on": 0, "paragraphs": [], "author": "A"}}
      #|]}
    ),
    "ops[1].params.paragraphs must not be empty",
  )
  expect_batch_error(
    (
      #|{"schema": "docx.batch/2", "ops": [
      #|  {"op": "paragraph", "params": {"text": "x"}},
      #|  {"op": "comment", "params": {"on": 0, "author": "A",
      #|   "paragraphs": [{"runs": [{"link": {"href": "https://a.example", "text": "l"}}]}]}}
      #|]}
    ),
    "ops[1].params.paragraphs[0].runs[0]: hyperlinks are not allowed in comment bodies (plain content only)",
  )
  expect_batch_error(
    (
      #|{"schema": "docx.batch/2", "ops": [
      #|  {"op": "paragraph", "params": {"text": "x"}},
      #|  {"op": "comment", "params": {"on": 0, "author": "A",
      #|   "paragraphs": [{"runs": [{"image": {"path": "logo.png"}}]}]}}
      #|]}
    ),
    "ops[1].params.paragraphs[0].runs[0]: images are not allowed in comment bodies (plain content only)",
  )
}

///|
test "K1: /1 and /2 accept the same content ops" {
  // The same paragraph+table script parses under either declaration —
  // /2 widens /1, it does not fork it.
  for schema in (["docx.batch/1", "docx.batch/2"] : ReadOnlyArray[String]) {
    let script = parse_str(
      "{\"schema\": \"" +
      schema +
      "\", \"ops\": [" +
      "{\"op\": \"paragraph\", \"params\": {\"text\": \"a\"}}," +
      "{\"op\": \"table\", \"params\": {\"rows\": [[{\"text\": \"c\"}]]}}]}",
    )
    inspect(script.op_count(), content="2")
    inspect(script.comment_count(), content="0")
    inspect(script.build_body(Map([])).length(), content="2")
  }
}

///|
test "K2: reply_to and done parse into the thread surface" {
  let script = parse_str(
    (
      #|{"schema": "docx.batch/2", "ops": [
      #|  {"op": "paragraph", "params": {"text": "Claim"}},
      #|  {"op": "comment", "params": {"on": 0, "text": "Check this",
      #|   "author": "Ada", "done": false}},
      #|  {"op": "comment", "params": {"reply_to": 1, "text": "Resolved",
      #|   "author": "Bob", "done": true}},
      #|  {"op": "comment", "params": {"reply_to": 2, "text": "Agreed",
      #|   "author": "Cid"}}
      #|]}
    ),
  )
  inspect(script.comment_count(), content="3")
  let comments = script.build_comments()
  let parent = comments[0]
  debug_inspect(parent.reply_to(), content="None")
  debug_inspect(parent.done(), content="Some(false)")
  // reply_to is reported as the DENSE COMMENT INDEX (= writer id), not
  // the op index: op 2 answers op 1, which is comment 0.
  let reply = comments[1]
  debug_inspect(reply.reply_to(), content="Some(0)")
  debug_inspect(reply.done(), content="Some(true)")
  debug_inspect(reply.from_block(), content="None")
  debug_inspect(reply.to_block(), content="None")
  // Chains: op 3 answers op 2, which is comment 1.
  let chained = comments[2]
  debug_inspect(chained.reply_to(), content="Some(1)")
  debug_inspect(chained.done(), content="None")
}

///|
test "K2: reply ops fail closed with exact op addresses" {
  expect_batch_error(
    (
      #|{"schema": "docx.batch/2", "ops": [
      #|  {"op": "paragraph", "params": {"text": "x"}},
      #|  {"op": "comment", "params": {"on": 0, "reply_to": 0, "text": "n", "author": "A"}}
      #|]}
    ),
    "ops[1].params: on and reply_to are mutually exclusive (a reply inherits its parent's anchor)",
  )
  expect_batch_error(
    (
      #|{"schema": "docx.batch/2", "ops": [
      #|  {"op": "paragraph", "params": {"text": "x"}},
      #|  {"op": "comment", "params": {"text": "n", "author": "A"}}
      #|]}
    ),
    "ops[1].params needs \"on\" (an earlier paragraph-op index, or {\"from\": i, \"to\": j}) or \"reply_to\" (an earlier comment-op index)",
  )
  // A reply must answer an EARLIER COMMENT op.
  expect_batch_error(
    (
      #|{"schema": "docx.batch/2", "ops": [
      #|  {"op": "paragraph", "params": {"text": "x"}},
      #|  {"op": "comment", "params": {"reply_to": 0, "text": "n", "author": "A"}}
      #|]}
    ),
    "ops[1].params.reply_to targets ops[0], which is not a comment op (replies answer comments; use on to anchor to content)",
  )
  expect_batch_error(
    (
      #|{"schema": "docx.batch/2", "ops": [
      #|  {"op": "paragraph", "params": {"text": "x"}},
      #|  {"op": "comment", "params": {"on": 0, "text": "n", "author": "A"}},
      #|  {"op": "comment", "params": {"reply_to": 2, "text": "n", "author": "B"}}
      #|]}
    ),
    "ops[2].params.reply_to must reference an EARLIER op (got 2); replies answer comments that already exist",
  )
  expect_batch_error(
    (
      #|{"schema": "docx.batch/2", "ops": [
      #|  {"op": "paragraph", "params": {"text": "x"}},
      #|  {"op": "comment", "params": {"on": 0, "text": "n", "author": "A"}},
      #|  {"op": "comment", "params": {"reply_to": 1.5, "text": "n", "author": "B"}}
      #|]}
    ),
    "ops[2].params.reply_to must be an integer (got 1.5)",
  )
  expect_batch_error(
    (
      #|{"schema": "docx.batch/2", "ops": [
      #|  {"op": "paragraph", "params": {"text": "x"}},
      #|  {"op": "comment", "params": {"on": 0, "text": "n", "author": "A", "done": "yes"}}
      #|]}
    ),
    "ops[1].params.done must be a boolean",
  )
  // Anchoring a comment ONTO another comment still points at reply_to.
  expect_batch_error(
    (
      #|{"schema": "docx.batch/2", "ops": [
      #|  {"op": "paragraph", "params": {"text": "x"}},
      #|  {"op": "comment", "params": {"on": 0, "text": "n", "author": "A"}},
      #|  {"op": "comment", "params": {"on": 1, "text": "n", "author": "B"}}
      #|]}
    ),
    "ops[2].params.on targets another comment (ops[1]); comment anchors must be paragraph ops (to answer a comment, use reply_to)",
  )
}

///|
test "K3: footnote and endnote inline keys parse with dense indexes" {
  let script = parse_str(
    (
      #|{"schema": "docx.batch/2", "ops": [
      #|  {"op": "paragraph", "params": {"runs": [
      #|    {"text": "Cited"},
      #|    {"footnote": {"text": "First source."}},
      #|    {"text": " twice"},
      #|    {"footnote": {"paragraphs": [{"text": "Second,"}, {"text": "longer."}]}}
      #|  ]}},
      #|  {"op": "table", "params": {"rows": [[{"paragraphs": [{"runs": [
      #|    {"text": "in a cell"},
      #|    {"endnote": {"text": "Cell note."}}
      #|  ]}]}]]}}
      #|]}
    ),
  )
  debug_inspect(script.note_counts(), content="(2, 1)")
  let footnotes = script.build_footnotes()
  inspect(footnotes.length(), content="2")
  inspect(footnotes[0].at(), content="ops[0].params.runs[1].footnote")
  inspect(footnotes[1].at(), content="ops[0].params.runs[3].footnote")
  inspect(footnotes[1].body().length(), content="2")
  let endnotes = script.build_endnotes()
  inspect(
    endnotes[0].at(),
    content="ops[1].params.rows[0][0].paragraphs[0].runs[1].endnote",
  )
  // The built body carries the dense per-kind references.
  let body = script.build_body(Map([]))
  guard body[0] is Paragraph(children~, ..)
  guard children[1] is Run(children=ref_children, ..)
  guard ref_children[0] is NoteReference(note_type~, note_id~)
  inspect(note_type, content="footnote")
  inspect(note_id, content="0")
}

///|
test "K3: note keys fail closed" {
  // /1 scripts cannot carry notes.
  expect_batch_error(
    (
      #|{"schema": "docx.batch/1", "ops": [
      #|  {"op": "paragraph", "params": {"runs": [{"footnote": {"text": "n"}}]}}
      #|]}
    ),
    "ops[0].params.runs[0].footnote needs \"schema\": \"docx.batch/2\"",
  )
  // Notes cannot nest in comment bodies or other notes.
  expect_batch_error(
    (
      #|{"schema": "docx.batch/2", "ops": [
      #|  {"op": "paragraph", "params": {"text": "x"}},
      #|  {"op": "comment", "params": {"on": 0, "author": "A",
      #|   "paragraphs": [{"runs": [{"endnote": {"text": "n"}}]}]}}
      #|]}
    ),
    "ops[1].params.paragraphs[0].runs[0]: notes cannot nest inside comment or note bodies",
  )
  expect_batch_error(
    (
      #|{"schema": "docx.batch/2", "ops": [
      #|  {"op": "paragraph", "params": {"runs": [
      #|    {"footnote": {"paragraphs": [{"runs": [{"footnote": {"text": "inner"}}]}]}}
      #|  ]}}
      #|]}
    ),
    "ops[0].params.runs[0].footnote.paragraphs[0].runs[0]: notes cannot nest inside comment or note bodies",
  )
  // Note objects are strict.
  expect_batch_error(
    (
      #|{"schema": "docx.batch/2", "ops": [
      #|  {"op": "paragraph", "params": {"runs": [{"footnote": {"text": "n", "bogus": 1}}]}}
      #|]}
    ),
    "ops[0].params.runs[0].footnote has an unknown key 'bogus'",
  )
  expect_batch_error(
    (
      #|{"schema": "docx.batch/2", "ops": [
      #|  {"op": "paragraph", "params": {"runs": [{"footnote": {}}]}}
      #|]}
    ),
    "ops[0].params.runs[0].footnote needs text or paragraphs",
  )
  // A note key is exclusive within its run object.
  expect_batch_error(
    (
      #|{"schema": "docx.batch/2", "ops": [
      #|  {"op": "paragraph", "params": {"runs": [{"footnote": {"text": "n"}, "bold": true}]}}
      #|]}
    ),
    "ops[0].params.runs[0] has an unknown key 'bold'",
  )
  // Links may not carry notes: the canonical write surface keeps note
  // references at top run level.
  expect_batch_error(
    (
      #|{"schema": "docx.batch/2", "ops": [
      #|  {"op": "paragraph", "params": {"runs": [
      #|    {"link": {"href": "https://a.example", "runs": [{"footnote": {"text": "n"}}]}}
      #|  ]}}
      #|]}
    ),
    "ops[0].params.runs[0].link.runs[0].footnote: notes cannot sit inside hyperlinks",
  )
}
