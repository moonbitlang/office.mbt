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
  builder.add_annotation_story(annotated, "comments", "comment", [
    ("dup", body),
    ("dup", body),
  ])
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
