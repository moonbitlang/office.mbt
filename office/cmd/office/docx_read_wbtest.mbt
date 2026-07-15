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
  let payload = docx_outline_payload(docx_read_test_projection()).data
  guard payload is Object(fields) &&
    fields.get("counts") is Some(Object(counts)) else {
    fail("expected outline counts")
  }
  json_inspect(counts.get("footnotes"), content=[1])
  json_inspect(counts.get("endnotes"), content=[1])
  json_inspect(counts.get("comments"), content=[1])
}

///|
test "DOCX projection reports physical story sources and authority" {
  let projection = docx_read_test_projection()
  for
    expected in [
      ("/docx/body", "word/document.xml"),
      ("/docx/footnotes", "word/footnotes.xml"),
      ("/docx/endnotes", "word/endnotes.xml"),
      ("/docx/comments", "word/comments.xml"),
      ("/docx/comments/comment[id=\"0\"]", "word/comments.xml"),
    ] {
    let (path, part) = expected
    let entry = resolve_projection_selector(projection, path)
    guard entry.source is Object(source) else {
      fail("expected object source for \{path}")
    }
    assert_eq(source.get("part"), Some(Json::string(part)))
    assert_eq(source.get("authority"), Some(Json::string("relationship")))
  }
}

///|
test "DOCX annotation anchors expose canonical story selectors" {
  let projection = docx_read_test_projection()
  let comment = resolve_projection_selector(
    projection, "/docx/comments/comment[id=\"0\"]",
  )
  guard comment.metadata is Object(metadata) &&
    metadata.get("anchors") is Some(Array(anchors)) &&
    anchors.get(0) is Some(Object(anchor)) else {
    fail("expected comment anchor metadata")
  }
  assert_eq(anchor.get("story"), Some(Json::string("/docx/body")))
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
    docx_outline_payload(projection).data,
  )
  let comment = resolve_projection_selector(
    projection, "/docx/comments/comment[id=\"0\"]",
  )
  assert_docx_capability_payload_contract(
    "get",
    get_docx_payload(projection, comment, 100_000).data,
  )
  assert_docx_capability_payload_contract(
    "text",
    docx_text_payload(projection, None, None, 0, 2, 100_000).data,
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
  assert_docx_capability_payload_contract(
    "query",
    docx_query_payload(projection, None, spec, 100_000).data,
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
  let payload = get_docx_payload(projection, comment, 100_000).data.stringify()
  assert_true(payload.contains("\"schema\":\"office.docx.element/1\""))
  assert_true(payload.contains("\"text\":\"Review this\""))
  assert_true(payload.contains("\"author\":\"Ada\""))
}

///|
test "DOCX text and query paginate in deterministic document order" {
  let projection = docx_read_test_projection()
  let text = docx_text_payload(projection, None, None, 1, 3, 100_000).data
  guard text is Object(text_fields) &&
    text_fields.get("entries") is Some(Array(text_records)) else {
    fail("expected bounded text records")
  }
  assert_eq(text_fields.get("matched_total"), Some(Json::number(6)))
  assert_eq(text_records.length(), 3)
  let text_paths : Array[String] = []
  for record in text_records {
    guard record is Object(fields) && fields.get("path") is Some(String(path)) else {
      fail("expected text record path")
    }
    text_paths.push(path)
  }
  inspect(
    text_paths.join("\n"),
    content=(
      #|/docx/body/tbl[1]/tr[1]/tc[1]/p[1]
      #|/docx/body/p[2]
      #|/docx/footnotes/note[id="1"]/p[1]
    ),
  )
  let query = docx_query_payload(
      projection,
      None,
      {
        under: None,
        kind: Some("p"),
        text: Some("source"),
        stable_id: None,
        properties: [],
        ignore_case: true,
        offset: 0,
        limit: 10,
      },
      100_000,
    ).data
  guard query is Object(query_fields) &&
    query_fields.get("matches") is Some(Array(query_records)) &&
    query_records.get(0) is Some(Object(query_record)) else {
    fail("expected bounded query record")
  }
  assert_eq(query_fields.get("matched_total"), Some(Json::number(1)))
  assert_eq(
    query_record.get("path"),
    Some(Json::string("/docx/footnotes/note[id=\"1\"]/p[1]")),
  )
}

///|
test "DOCX query uses only its declared property set" {
  let projection = docx_read_test_projection()
  let links = docx_query_payload(
      projection,
      None,
      {
        under: None,
        kind: Some("hyperlink"),
        text: None,
        stable_id: None,
        properties: [{ name: "href", value: "https://www.moonbitlang.com/" }],
        ignore_case: false,
        offset: 0,
        limit: 10,
      },
      100_000,
    ).data
  guard links is Object(link_fields) &&
    link_fields.get("matches") is Some(Array(link_records)) &&
    link_records.get(0) is Some(Object(link)) &&
    link.get("path") is Some(String(path)) else {
    fail("expected bounded hyperlink query result")
  }
  assert_eq(link_fields.get("matched_total"), Some(Json::number(1)))
  assert_true(path.contains("/hyperlink[1]"))
}

///|
test "DOCX exact queries cover the full supported XML token length" {
  let long_id = "i".repeat(@lib.SELECTOR_MAX_VALUE_LENGTH + 1)
  let long_property = "p".repeat(@lib.SELECTOR_MAX_VALUE_LENGTH + 1)
  validate_query_value(long_id, "id", false)
  validate_query_value(long_property, "property", true)
  let annotated = @docx.read_docx_annotated(docx_read_test_bytes())
  let builder = DocxProjectionBuilder::new(100)
  let body = [@document.paragraph([@document.run([@document.text("x")])])]
  let footnotes = annotation_story_plan("footnotes", "note", [])
  let endnotes = annotation_story_plan("endnotes", "note", [])
  let comments = annotation_story_plan("comments", "comment", [(long_id, body)])
  let annotation_index = annotation_projection_index(
    annotated, footnotes, endnotes, comments,
  )
  builder.add_annotation_story(annotation_index, comments, None)
  let item = { ..builder.entries[1], properties: { "author": long_property } }
  assert_eq(item.path, "/docx/comments/comment[1]")
  assert_eq(item.stable_id, Some(long_id))
  let spec : DocxQuerySpec = {
    under: None,
    kind: Some("comment"),
    text: None,
    stable_id: Some(long_id),
    properties: [{ name: "author", value: long_property }],
    ignore_case: false,
    offset: 0,
    limit: 1,
  }
  let work = DocxQueryWorkBudget::new(4 * 1024 * 1024)
  assert_true(
    entry_matches_query(
      item,
      PreparedDocxQuery::build(spec, None, work),
      DocxTextBudget::new("query text scan characters", 1),
      work,
    ),
  )
  try
    validate_query_value(
      "x".repeat(docx_cli_max_xml_token_chars + 1),
      "id",
      false,
    )
  catch {
    CliFailure(error) => {
      assert_eq(error.code, "office.invalid_arguments")
      guard error.details is Some(Object(details)) else {
        fail("expected query length details")
      }
      assert_eq(
        details.get("maximum_characters"),
        Some(Json::number(docx_cli_max_xml_token_chars.to_double())),
      )
    }
  } noraise {
    _ => fail("expected query value above the XML token limit to fail")
  }
}

///|
test "DOCX query matching is linear-work and Unicode simple-case aware" {
  let work = DocxQueryWorkBudget::new(100_000)
  let adversarial = DocxLinearPattern::compile(
    "a".repeat(127) + "b",
    false,
    work,
  )
  assert_false(adversarial.is_in("a".repeat(4096), work))
  assert_true(adversarial.is_in("a".repeat(127) + "b", work))
  let unicode = DocxLinearPattern::compile("école", true, work)
  assert_true(unicode.is_in("L'ÉCOLE MoonBit", work))
  let supplementary = DocxLinearPattern::compile("𐐨", true, work)
  assert_true(supplementary.is_in("𐐀", work))
}

///|
test "DOCX query predicate work has an independent hard budget" {
  let equality_work = DocxQueryWorkBudget::new(16)
  try query_strings_equal("x".repeat(32), "x".repeat(32), equality_work) catch {
    CliFailure(error) => {
      assert_eq(error.code, "office.docx.resource_limit")
      guard error.details is Some(Object(details)) else {
        fail("expected predicate work details")
      }
      assert_eq(
        details.get("resource"),
        Some(Json::string("query predicate work units")),
      )
    }
  } noraise {
    _ => fail("expected exact comparison work to be bounded")
  }
  let pattern_work = DocxQueryWorkBudget::new(32)
  let pattern = DocxLinearPattern::compile("a", false, pattern_work)
  try pattern.is_in("a".repeat(32), pattern_work) catch {
    CliFailure(error) => assert_eq(error.code, "office.docx.resource_limit")
  } noraise {
    _ => fail("expected substring work to be bounded")
  }
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
  builder.add_annotation_story(annotation_index, comments, None)
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
test "missing annotation ids remain empty and positional" {
  let body = [@document.paragraph([@document.run([@document.text("x")])])]
  let plan = annotation_story_plan("comments", "comment", [("", body)])
  assert_eq(plan.paths, ["/docx/comments/comment[1]"])
  assert_eq(plan.missing_ids, 1)
  assert_eq(plan.duplicate_ids, 0)
  assert_eq(plan.unrepresentable_ids, 0)
  assert_false(plan.paths[0].contains("undefined"))
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
  let path_roots : @sorted_map.SortedMap[String, String] = SortedMap([])
  add_annotation_path_roots(path_roots, footnotes)
  add_annotation_path_roots(path_roots, endnotes)
  add_annotation_path_roots(path_roots, comments)
  assert_eq(
    canonical_index_path("/comments/comment[1]/p[1]", path_roots),
    Some("/docx/comments/comment[id=\"0\"]/p[1]"),
  )
  assert_eq(
    canonical_index_path("/footnotes/note[1]/p[1]/r[1]", path_roots),
    Some("/docx/footnotes/note[id=\"1\"]/p[1]/r[1]"),
  )
  assert_eq(
    canonical_index_path("/body/p[1]/r[1]", path_roots),
    Some("/docx/body/p[1]/r[1]"),
  )
  assert_eq(
    canonical_index_path("/comments/comment[99]/p[1]", path_roots),
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
test "projection and successful command output limits fail explicitly" {
  let annotated = @docx.read_docx_annotated(docx_read_test_bytes())
  try projection_from_annotated("small.docx", annotated, 2) catch {
    CliFailure(error) => assert_eq(error.code, "office.docx.resource_limit")
  } noraise {
    _ => fail("expected projection resource limit")
  }
  try
    bounded_docx_payload(
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
test "successful command output accounting includes its trailing line feed" {
  assert_eq(checked_docx_human_output("abc", 4), "abc")
  try checked_docx_human_output("abc", 3) catch {
    CliFailure(error) => {
      assert_eq(error.code, "office.docx.resource_limit")
      guard error.details is Some(Object(details)) else {
        fail("expected output limit details")
      }
      assert_eq(
        details.get("resource"),
        Some(Json::string("successful command output characters")),
      )
      assert_eq(details.get("limit"), Some(Json::number(3)))
      assert_eq(details.get("actual"), Some(Json::number(4)))
    }
  } noraise {
    _ => fail("expected the trailing line feed to exceed the ceiling")
  }
}

///|
test "deep generated DOCX paths are classified as resource limits" {
  let mut nested = @word.paragraph([@word.run([@word.text("deep")])])
  for _ in 0..<40 {
    nested = @word.table([@word.table_row([@word.table_cell([nested])])])
  }
  let builder = DocxProjectionBuilder::new(1000)
  try
    builder.add_story("/docx/body", "body", [nested], Json::empty_object())
  catch {
    CliFailure(error) => {
      assert_eq(error.code, "office.docx.resource_limit")
      guard error.details is Some(Object(details)) else {
        fail("expected selector-depth resource details")
      }
      assert_eq(
        details.get("resource"),
        Some(Json::string("selector path segments")),
      )
      assert_eq(
        details.get("limit"),
        Some(Json::number(@lib.SELECTOR_MAX_DEPTH.to_double())),
      )
    }
  } noraise {
    _ => fail("expected deep generated selector paths to hit a resource limit")
  }
}

///|
test "compact JSON preflight matches serializer character accounting" {
  let value = Json::object({
    "escaped": Json::string("quote \" slash \\ controls \b\t\n\f\r \u{0001}"),
    "unicode": Json::string("月🌙"),
    "values": Json::array([
      Json::boolean(true),
      Json::boolean(false),
      Json::number(123.5),
    ]),
  })
  let serialized = value.stringify()
  let mut characters = 0
  for _ in serialized {
    characters += 1
  }
  let budget = DocxOutputBudget::new(characters + docx_cli_output_framing_chars)
  budget.reserve_json(value)
  assert_eq(budget.used, characters + docx_cli_output_framing_chars)
}

///|
test "bounded DOCX payloads account for their exact serialized envelopes" {
  let projection = docx_read_test_projection()
  let paragraph = resolve_projection_selector(projection, "/docx/body/p[1]")
  let query_spec : DocxQuerySpec = {
    under: None,
    kind: Some("p"),
    text: None,
    stable_id: None,
    properties: [{ name: "style_id", value: "Heading1" }],
    ignore_case: false,
    offset: 0,
    limit: 10,
  }
  let payloads = [
    docx_outline_payload(projection, max_output_chars=100_000),
    get_docx_payload(projection, paragraph, 100_000),
    docx_text_payload(projection, None, None, 0, 10, 100_000),
    docx_query_payload(projection, None, query_spec, 100_000),
  ]
  for payload in payloads {
    let output = checked_docx_json_output(payload)
    let mut characters = 0
    for _ in output {
      characters += 1
    }
    assert_eq(characters + docx_cli_output_framing_chars, payload.budget.used)
  }
  let warnings = [@lib.protocol_warning("escaped\"code", "line\n月")]
  let warned = bounded_docx_payload(
    Json::object({ "value": Json::string("ok") }),
    warnings,
    1000,
  )
  let warned_output = checked_docx_json_output(warned)
  let mut warned_characters = 0
  for _ in warned_output {
    warned_characters += 1
  }
  assert_eq(
    warned_characters + docx_cli_output_framing_chars,
    warned.budget.used,
  )
  let sections : Array[Json] = []
  let section_fields : Map[String, Json] = { "sections": Json::array(sections) }
  let nested = bounded_docx_payload(Json::object(section_fields), [], 1000)
  sections.push(
    bounded_section_json(
      {
        ends_after_paragraph: Some(12),
        headers: [
          { variant: "default", part: 0 },
          { variant: "first", part: 1 },
        ],
        footers: [{ variant: "even", part: 2 }],
      },
      nested.budget,
      false,
    ),
  )
  ignore(
    checked_docx_json_output({
      data: Json::object(section_fields),
      budget: nested.budget,
      warnings: nested.warnings,
    }),
  )
}

///|
test "DOCX output builders reject growth before returning oversized output" {
  let projection = docx_read_test_projection()
  let entry = resolve_projection_selector(projection, "/docx/body/p[1]")
  try docx_get_human(entry, "x".repeat(1000), [], maximum=40) catch {
    CliFailure(error) => assert_eq(error.code, "office.docx.resource_limit")
  } noraise {
    _ => fail("expected bounded human output construction to fail")
  }
  try docx_outline_payload(projection, max_output_chars=40) catch {
    CliFailure(error) => assert_eq(error.code, "office.docx.resource_limit")
  } noraise {
    _ => fail("expected bounded outline retention to fail")
  }
  let wide = {
    ..projection.entries[0],
    children: Array::make(docx_cli_hard_max_elements, entry.path),
  }
  try get_docx_payload(projection, wide, 1) catch {
    CliFailure(error) => assert_eq(error.code, "office.docx.resource_limit")
  } noraise {
    _ => fail("expected get skeleton to fail before retaining child records")
  }
  try docx_text_payload(projection, None, None, 0, 10_000, 1) catch {
    CliFailure(error) => assert_eq(error.code, "office.docx.resource_limit")
  } noraise {
    _ => fail("expected text skeleton to fail before retaining records")
  }
  let query_spec : DocxQuerySpec = {
    under: None,
    kind: None,
    text: None,
    stable_id: None,
    properties: [],
    ignore_case: false,
    offset: 0,
    limit: 1000,
  }
  try docx_query_payload(projection, None, query_spec, 1) catch {
    CliFailure(error) => assert_eq(error.code, "office.docx.resource_limit")
  } noraise {
    _ => fail("expected query skeleton to fail before retaining records")
  }
}

///|
test "DOCX heading classification shares inspect semantics and bounds folding" {
  let paragraph = @word.paragraph(
    [@word.run([@word.text("not a heading")])],
    properties=@word.paragraph_properties(
      style_name=Some("Heading 1" + "x".repeat(1024 * 1024)),
    ),
  )
  assert_eq(docx_heading_level(paragraph), None)
  assert_eq(
    docx_heading_level(
      @word.paragraph(
        [@word.run([@word.text("exact id")])],
        properties=@word.paragraph_properties(style_id=Some("Heading2")),
      ),
    ),
    Some(2),
  )
  assert_eq(
    docx_heading_level(
      @word.paragraph(
        [@word.run([@word.text("wrong id case")])],
        properties=@word.paragraph_properties(style_id=Some("heading2")),
      ),
    ),
    None,
  )
  assert_eq(
    docx_heading_level(
      @word.paragraph(
        [@word.run([@word.text("bare name")])],
        properties=@word.paragraph_properties(style_name=Some("HEADING")),
      ),
    ),
    Some(1),
  )
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
  let collector = DocxTextCollector::new_reported("preview", 160, 160, 0, false)
  try! collector.write_literal_string("z".repeat(2 * 1024 * 1024))
  assert_eq(collector.used, 160)
  assert_true(collector.truncated)
}

///|
test "literal newlines consume scan budgets even when presentation trims them" {
  let newline_only = @word.paragraph([@word.run([@word.text("\n".repeat(161))])])
  let (preview, truncated) = collect_docx_text_prefix(newline_only, 160)
  assert_eq(preview, "")
  assert_true(truncated)
  let projection = docx_read_test_projection()
  let entry = { ..projection.entries[0], element: Some(newline_only) }
  let aggregate = DocxTextBudget::new("query text scan characters", 16)
  try entry_text_with_budget(entry, aggregate) catch {
    CliFailure(error) => {
      assert_eq(error.code, "office.docx.resource_limit")
      guard error.details is Some(Object(details)) else {
        fail("expected newline scan resource details")
      }
      assert_eq(
        details.get("resource"),
        Some(Json::string("query text scan characters")),
      )
    }
  } noraise {
    _ => fail("expected literal newlines to exhaust the scan budget")
  }
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
test "DOCX structured reads accept explicit ZIP directory records" {
  let archive = try! @zip.read(docx_read_test_bytes())
  archive.add("word/", b"")
  archive.add("word/media/", b"")
  let projection = open_docx_projection(
    "directories.docx",
    @zip.write(archive),
    1000,
  )
  assert_true(find_projection_entry(projection, "/docx/body") is Some(_))
}

///|
test "DOCX structured reads warn and continue on broken section references" {
  let archive = try! @zip.read(docx_read_test_bytes())
  guard archive.get("word/document.xml") is Some(document_bytes) else {
    fail("fixture has no main document part")
  }
  let document = try! @utf8.decode(document_bytes, ignore_bom=true)
  let malformed = document.replace(
    old="</w:body>",
    new="<w:sectPr><w:headerReference w:type=\"default\"/></w:sectPr></w:body>",
  )
  assert_true(archive.replace("word/document.xml", @utf8.encode(malformed)))
  let projection = open_docx_projection(
    "missing-header-id.docx",
    @zip.write(archive),
    1000,
  )
  assert_true(find_projection_entry(projection, "/docx/body") is Some(_))
  assert_true(
    projection.warnings.any(warning => {
      warning.code == "office.docx.reader_warning" &&
      warning.message.contains("without r:id was ignored")
    }),
  )
}

///|
test "DOCX preflight rejects foreign-namespace officeDocument relationships" {
  let archive = try! @zip.read(docx_read_test_bytes())
  let root_relationships =
    #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships" xmlns:foreign="urn:foreign"><foreign:Relationship Id="main" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>
  assert_true(archive.replace("_rels/.rels", @utf8.encode(root_relationships)))
  try open_docx_projection("foreign.docx", @zip.write(archive), 1000) catch {
    CliFailure(error) => assert_eq(error.code, "office.invalid_package")
    _ => fail("expected a structured CLI package failure")
  } noraise {
    _ => fail("expected foreign-namespace relationship rejection")
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
  let paragraph = resolve_projection_selector(projection, "/docx/body/p[1]")
  let unsafe_text_entry = {
    ..paragraph,
    path: unsafe_path,
    element: Some(@word.paragraph([@word.run([@word.text("text\u{009b}")])])),
  }
  let unsafe_query_entry = {
    ..unsafe_text_entry,
    kind: unsafe_kind,
    element: Some(@word.paragraph([@word.run([@word.text("preview\u{009b}")])])),
  }
  let query_spec : DocxQuerySpec = {
    under: None,
    kind: None,
    text: None,
    stable_id: None,
    properties: [],
    ignore_case: false,
    offset: 0,
    limit: 1,
  }
  let outputs = [
    docx_get_human(unsafe_entry, "value\u{009b}", []),
    docx_text_human(
      { ..projection, entries: [unsafe_text_entry] },
      None,
      0,
      1,
      [],
    ),
    docx_query_human(
      { ..projection, entries: [unsafe_query_entry] },
      None,
      query_spec,
      [],
    ),
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
