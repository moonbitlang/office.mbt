///|
fn docx_read_test_body() -> Array[@document.DocumentElement] {
  [
    @word.paragraph(
      [@word.run([@word.text("Roadmap")])],
      properties=@word.paragraph_properties(
        style_id=Some("Heading1"),
        style_name=Some("heading 1"),
      ),
    ),
    @word.table([
      @word.table_row([
        @word.table_cell([
          @word.paragraph([
            @word.hyperlink(
              [@word.run([@word.text("MoonBit")])],
              href=Some("https://www.moonbitlang.com/"),
            ),
          ]),
        ]),
      ]),
    ]),
    @word.paragraph([
      @word.run([
        @word.text("Footnote"),
        @word.note_reference("footnote", "0"),
        @word.note_reference("endnote", "0"),
      ]),
    ]),
  ]
}

///|
fn docx_read_test_bytes() -> Bytes raise {
  @word.write_docx_with_annotations(
    docx_read_test_body(),
    comments=[
      @word.comment_spec(author="Ada", initials="AL", from=0, to=0, [
        @word.paragraph([@word.run([@word.text("Review this")])]),
      ]),
    ],
    footnotes=[
      @word.note_spec([@word.paragraph([@word.run([@word.text("A source")])])]),
    ],
    endnotes=[
      @word.note_spec([@word.paragraph([@word.run([@word.text("An ending")])])]),
    ],
  ) catch {
    Unsupported(message~) => raise CliError(message)
    error => raise error
  }
}

///|
fn docx_read_test_projection() -> DocxProjection raise {
  open_docx_projection("fixture.docx", docx_read_test_bytes(), 1000)
}

///|
test "DOCX projection emits canonical round-tripping story paths" {
  let projection = docx_read_test_projection()
  let paths = projection.entries.map(entry => entry.path)
  assert_true(paths.contains("/docx/body/p[1]"))
  assert_true(paths.contains("/docx/body/tbl[1]/tr[1]/tc[1]/p[1]"))
  assert_true(
    paths.contains("/docx/body/tbl[1]/tr[1]/tc[1]/p[1]/hyperlink[1]/r[1]"),
  )
  assert_true(paths.contains("/docx/footnotes/note[id=\"1\"]/p[1]"))
  assert_true(paths.contains("/docx/endnotes/note[id=\"1\"]/p[1]"))
  assert_true(paths.contains("/docx/comments/comment[id=\"0\"]/p[1]"))
  for entry in projection.entries {
    assert_eq(@lib.parse_selector(entry.path).render(), entry.path)
  }
  let roots = projection.entries
    .filter(entry => entry.role is (StoryRoot | AnnotationCollection))
    .map(entry => entry.path)
  inspect(
    roots.join("\n"),
    content=(
      #|/docx/body
      #|/docx/footnotes
      #|/docx/endnotes
      #|/docx/comments
    ),
  )
}

///|
test "DOCX outline reports semantic annotation counts" {
  let payload = docx_outline_payload(docx_read_test_projection())
  guard payload is Object(fields) &&
    fields.get("counts") is Some(Object(counts)) else {
    fail("expected outline counts")
  }
  json_inspect(counts.get("footnotes"), content=[1])
  json_inspect(counts.get("endnotes"), content=[1])
  json_inspect(counts.get("comments"), content=[1])
}

///|
fn assert_docx_capability_payload_contract(
  name : String,
  payload : Json,
) -> Unit raise {
  guard @lib.capability_commands().search_by(command => command.name == name)
    is Some(command_index) else {
    fail("missing capability command \{name}")
  }
  let command = @lib.capability_commands()[command_index]
  guard payload is Object(fields) else {
    fail("expected object payload for \{name}")
  }
  let declared = command.outputs.map(field => field.name)
  for key, _ in fields {
    if !declared.contains(key) {
      fail("\{name} payload field '\{key}' is not declared")
    }
  }
  for field in command.outputs {
    if field.required && !fields.contains(field.name) {
      fail("\{name} required output '\{field.name}' was not emitted")
    }
  }
}

///|
test "DOCX capability declarations cover every payload field" {
  let projection = docx_read_test_projection()
  assert_docx_capability_payload_contract(
    "outline",
    docx_outline_payload(projection),
  )
  let comment = resolve_projection_selector(
    projection, "/docx/comments/comment[id=\"0\"]",
  )
  assert_docx_capability_payload_contract(
    "get",
    get_docx_payload(projection, comment, 100_000),
  )
  let text = build_docx_text_result(projection, None, 0, 2, 100_000)
  assert_docx_capability_payload_contract(
    "text",
    docx_text_payload(projection, text, None),
  )
  let spec : DocxQuerySpec = {
    under: None,
    kind: Some("p"),
    text: None,
    stable_id: None,
    properties: [],
    ignore_case: false,
    offset: 0,
    limit: 2,
  }
  let query = build_docx_query_result(projection, None, spec)
  assert_docx_capability_payload_contract(
    "query",
    docx_query_payload(projection, query, spec),
  )
}

///|
test "DOCX get distinguishes stable items and positional descendants" {
  let projection = docx_read_test_projection()
  let comment = resolve_projection_selector(
    projection, "/docx/comments/comment[id=\"0\"]",
  )
  assert_true(comment.stability is Stable)
  assert_eq(comment.properties.get("author"), Some("Ada"))
  let paragraph = resolve_projection_selector(
    projection, "/docx/comments/comment[id=\"0\"]/p[1]",
  )
  assert_true(paragraph.stability is SnapshotRelative)
  let payload = get_docx_payload(projection, comment, 100_000).stringify()
  assert_true(payload.contains("\"schema\":\"office.docx.element/1\""))
  assert_true(payload.contains("\"text\":\"Review this\""))
  assert_true(payload.contains("\"author\":\"Ada\""))
}

///|
test "DOCX text and query paginate in deterministic document order" {
  let projection = docx_read_test_projection()
  let text = build_docx_text_result(projection, None, 1, 3, 100_000)
  assert_eq(text.matched_total, 6)
  assert_eq(text.records.length(), 3)
  inspect(
    text.records.map(record => record.path).join("\n"),
    content=(
      #|/docx/body/tbl[1]/tr[1]/tc[1]/p[1]
      #|/docx/body/p[2]
      #|/docx/footnotes/note[id="1"]/p[1]
    ),
  )
  let query = build_docx_query_result(projection, None, {
    under: None,
    kind: Some("p"),
    text: Some("source"),
    stable_id: None,
    properties: [],
    ignore_case: true,
    offset: 0,
    limit: 10,
  })
  assert_eq(query.matched_total, 1)
  assert_eq(query.records[0].entry.path, "/docx/footnotes/note[id=\"1\"]/p[1]")
}

///|
test "DOCX query uses only its declared property set" {
  let projection = docx_read_test_projection()
  let links = build_docx_query_result(projection, None, {
    under: None,
    kind: Some("hyperlink"),
    text: None,
    stable_id: None,
    properties: [{ name: "href", value: "https://www.moonbitlang.com/" }],
    ignore_case: false,
    offset: 0,
    limit: 10,
  })
  assert_eq(links.matched_total, 1)
  assert_true(links.records[0].entry.path.contains("/hyperlink[1]"))
}

///|
test "DOCX resolver reports malformed, missing, and unsupported stable selectors" {
  let projection = docx_read_test_projection()
  for
    case in [
      ("/docx/body/p[999]", "office.docx.selector_not_found"),
      ("/docx/body/p[id=\"7\"]", "office.docx.unsupported_stable_id"),
      ("/xlsx/sheet[name=\"Data\"]", "office.docx.selector_format_mismatch"),
    ] {
    let (path, expected) = case
    try resolve_projection_selector(projection, path) catch {
      CliFailure(error) => assert_eq(error.code, expected)
    } noraise {
      _ => fail("expected selector failure for \{path}")
    }
  }
  try
    resolve_projection_selector(projection, "/docx/comments/comment[@id=0]")
  catch {
    CliFailure(error) =>
      assert_eq(error.code, "office.selector.unsupported_predicate")
  } noraise {
    _ => fail("expected malformed selector failure")
  }
}

///|
test "duplicate annotation ids stay positional and stable lookup is ambiguous" {
  let annotated = @docx.read_docx_annotated(docx_read_test_bytes())
  let builder = DocxProjectionBuilder::new(100)
  let body = [@document.paragraph([@document.run([@document.text("x")])])]
  let footnotes = annotation_story_plan("footnotes", "note", [])
  let endnotes = annotation_story_plan("endnotes", "note", [])
  let comments = annotation_story_plan("comments", "comment", [
    ("dup", body),
    ("dup", body),
  ])
  let annotation_index = annotation_projection_index(
    annotated, footnotes, endnotes, comments,
  )
  builder.add_annotation_story(annotation_index, comments)
  assert_eq(builder.entries[1].path, "/docx/comments/comment[1]")
  assert_eq(builder.entries[4].path, "/docx/comments/comment[2]")
  assert_true(
    builder.warnings.any(warning => {
      warning.code == "office.docx.duplicate_annotation_id"
    }),
  )
  let projection : DocxProjection = {
    file: "duplicate.docx",
    annotated,
    entries: builder.entries,
    entry_index: builder.entry_index,
    warnings: builder.warnings,
  }
  try
    resolve_projection_selector(
      projection, "/docx/comments/comment[id=\"dup\"]",
    )
  catch {
    CliFailure(error) =>
      assert_eq(error.code, "office.docx.selector_ambiguous_id")
  } noraise {
    _ => fail("expected duplicate id ambiguity")
  }
}

///|
test "delimiter-rich unique annotation ids remain canonical and stable" {
  let id = "review/one]=\"ready\""
  let path = stable_annotation_path("comments", "comment", id)
  assert_eq(
    path,
    Some("/docx/comments/comment[id=\"review/one]=\\\"ready\\\"\"]"),
  )
  guard path is Some(value) else { fail("expected stable path") }
  assert_eq(@lib.parse_selector(value).render(), value)
}

///|
test "annotation metadata paths rewrite to emitted stable roots" {
  let annotated = @docx.read_docx_annotated(docx_read_test_bytes())
  let footnotes = annotation_story_plan(
    "footnotes",
    "note",
    annotated.footnote_bodies(),
  )
  let endnotes = annotation_story_plan(
    "endnotes",
    "note",
    annotated.endnote_bodies(),
  )
  let comments = annotation_story_plan(
    "comments",
    "comment",
    annotated.comment_bodies(),
  )
  let annotation_index = annotation_projection_index(
    annotated, footnotes, endnotes, comments,
  )
  assert_eq(
    canonical_index_path(
      "/comments/comment[1]/p[1]",
      annotation_index.path_roots,
    ),
    Some("/docx/comments/comment[id=\"0\"]/p[1]"),
  )
  assert_eq(
    canonical_index_path(
      "/footnotes/note[1]/p[1]/r[1]",
      annotation_index.path_roots,
    ),
    Some("/docx/footnotes/note[id=\"1\"]/p[1]/r[1]"),
  )
  assert_eq(
    canonical_index_path("/body/p[1]/r[1]", annotation_index.path_roots),
    Some("/docx/body/p[1]/r[1]"),
  )
  assert_eq(
    canonical_index_path(
      "/comments/comment[99]/p[1]",
      annotation_index.path_roots,
    ),
    None,
  )
  let projection = projection_from_annotated("fixture.docx", annotated, 1000)
  for
    path in [
      "/docx/comments/comment[id=\"0\"]/p[1]", "/docx/footnotes/note[id=\"1\"]/p[1]/r[1]",
    ] {
    assert_true(find_projection_entry(projection, path) is Some(_))
  }
}

///|
test "projection and serialized output limits fail explicitly" {
  let annotated = @docx.read_docx_annotated(docx_read_test_bytes())
  try projection_from_annotated("small.docx", annotated, 2) catch {
    CliFailure(error) => assert_eq(error.code, "office.docx.resource_limit")
  } noraise {
    _ => fail("expected projection resource limit")
  }
  try
    checked_docx_json_output(
      Json::object({ "payload": Json::string("x".repeat(200)) }),
      [],
      40,
    )
  catch {
    CliFailure(error) => assert_eq(error.code, "office.docx.resource_limit")
  } noraise {
    _ => fail("expected output resource limit")
  }
}

///|
test "DOCX projection lookup uses its canonical path index" {
  let projection = docx_read_test_projection()
  for index, entry in projection.entries {
    assert_eq(projection.entry_index.get(entry.path), Some(index))
    guard find_projection_entry(projection, entry.path) is Some(found) else {
      fail("indexed projection entry was not found")
    }
    assert_eq(found.path, entry.path)
  }
  assert_true(find_projection_entry(projection, "/docx/body/p[999]") is None)
}

///|
test "DOCX warning retention and deduplication sets share one hard cap" {
  let builder = DocxProjectionBuilder::new(1)
  for index in 0..<1000 {
    builder.warn("office.docx.reader_warning", "diagnostic \{index}")
  }
  assert_eq(builder.warnings.length(), docx_cli_max_warnings)
  assert_eq(
    builder.warnings[docx_cli_max_warnings - 1].code,
    "office.docx.warnings_truncated",
  )
  let mut retained_keys = 0
  for _ in builder.warning_keys {
    retained_keys += 1
  }
  assert_eq(retained_keys, docx_cli_max_warnings - 1)
}

///|
test "DOCX preview truncation excludes discarded paragraph separators" {
  let exact = @word.paragraph([@word.run([@word.text("x".repeat(159))])])
  let (exact_text, exact_truncated) = collect_docx_text_prefix(exact, 160)
  assert_eq(exact_text, "x".repeat(159))
  assert_false(exact_truncated)
  let over = @word.paragraph([@word.run([@word.text("x".repeat(161))])])
  let (over_text, over_truncated) = collect_docx_text_prefix(over, 160)
  assert_eq(over_text, "x".repeat(160))
  assert_true(over_truncated)
  let internal = @word.document([
    exact,
    @word.paragraph([@word.run([@word.text("y")])]),
  ])
  let (_, internal_truncated) = collect_docx_text_prefix(internal, 160)
  assert_true(internal_truncated)
  let collector = DocxTextCollector::new("preview", 160, false)
  try! collector.write_string("z".repeat(2 * 1024 * 1024))
  assert_eq(collector.used, 160)
  assert_true(collector.truncated)
}

///|
test "DOCX text budgets retain an independent per-element ceiling" {
  let projection = docx_read_test_projection()
  let oversized = {
    ..projection.entries[0],
    element: Some(
      @word.paragraph([
        @word.run([@word.text("x".repeat(docx_cli_max_element_text_chars + 1))]),
      ]),
    ),
  }
  let aggregate = DocxTextBudget::new(
    "query text scan characters",
    docx_cli_max_element_text_chars * 2,
  )
  try entry_text_with_budget(oversized, aggregate) catch {
    CliFailure(error) => {
      assert_eq(error.code, "office.docx.resource_limit")
      guard error.details is Some(Object(details)) else {
        fail("expected per-element resource details")
      }
      assert_eq(
        details.get("resource"),
        Some(Json::string("element text characters")),
      )
      assert_eq(
        details.get("limit"),
        Some(Json::number(docx_cli_max_element_text_chars.to_double())),
      )
    }
  } noraise {
    _ => fail("expected the independent per-element ceiling")
  }
}

///|
test "DOCX reader classifies only exact parser guard failures as resources" {
  let CliFailure(resource) = docx_reader_failure(
    InvalidXml(message="XML token budget exceeded"),
    "fixture.docx",
  )
  assert_eq(resource.code, "office.docx.resource_limit")
  let CliFailure(ordinary) = docx_reader_failure(
    InvalidXml(message="invalid limit element"),
    "fixture.docx",
  )
  assert_eq(ordinary.code, "office.docx.read_failed")
  let CliFailure(depth) = docx_reader_failure(
    InvalidXml(message="XML nesting too deep"),
    "fixture.docx",
  )
  assert_eq(depth.code, "office.docx.resource_limit")
}

///|
test "DOCX OPC classification cannot be forged by an entry name" {
  let archive = try! @zip.read(docx_read_test_bytes())
  archive.add("word/XML source budget exceeded.bin", b"ordinary")
  try validate_docx_read_archive("spoof.docx", archive) catch {
    CliFailure(error) => assert_eq(error.code, "office.invalid_package")
  } noraise {
    _ => fail("expected the undeclared spoof part to invalidate the package")
  }
}

///|
test "DOCX human output escapes control sequences in paths, kinds, and text" {
  let projection = docx_read_test_projection()
  let unsafe_path = "/docx/body/\u{009b}story"
  let unsafe_kind = "body\u{009b}"
  let unsafe_entry = {
    ..projection.entries[0],
    path: unsafe_path,
    kind: unsafe_kind,
  }
  let text_result : DocxTextResult = {
    records: [
      {
        path: unsafe_path,
        stability: "snapshot-relative",
        text: "text\u{009b}",
      },
    ],
    matched_total: 1,
    offset: 0,
    limit: 1,
    scanned_elements: 1,
  }
  let query_result : DocxQueryResult = {
    records: [
      {
        entry: unsafe_entry,
        preview: "preview\u{009b}",
        preview_truncated: false,
      },
    ],
    matched_total: 1,
    offset: 0,
    limit: 1,
    scanned_elements: 1,
    under: None,
  }
  let outputs = [
    docx_get_human(unsafe_entry, "value\u{009b}", []),
    docx_text_human(text_result, []),
    docx_query_human(query_result, []),
    docx_outline_human({ ..projection, entries: [unsafe_entry] }),
  ]
  for output in outputs {
    assert_false(output.contains("\u{009b}"))
    assert_true(output.contains("\\u009b"))
  }
}

///|
async test "bounded DOCX file reads use the DOCX resource code" {
  try
    read_bounded_file(
      "../docx2html/tests/cram/fixtures/single-paragraph.docx",
      1,
      "office.file_read_failed",
      "input package",
      limit_code="office.docx.resource_limit",
    )
  catch {
    CliFailure(error) => {
      assert_eq(error.code, "office.docx.resource_limit")
      guard error.details is Some(Object(fields)) else {
        fail("expected resource-limit details")
      }
      assert_eq(fields.get("limit"), Some(Json::number(1)))
      assert_true(fields.contains("actual"))
    }
    _ => fail("unexpected bounded DOCX read failure")
  } noraise {
    _ => fail("expected bounded DOCX read to fail")
  }
}
