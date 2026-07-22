///|
/// End-to-end DOCX replay: the full user-facing loop through real bytes.
test "docx dump replays to an equivalent document" {
  let body : Array[@document.DocumentElement] = [
    @document.paragraph(
      [
        @document.run(
          [@document.text("Title")],
          properties=@document.run_properties(is_bold=true),
        ),
      ],
      properties=@document.paragraph_properties(style_id=Some("Heading1")),
    ),
    @document.paragraph([@document.run([@document.text("Body text")])]),
  ]
  let bytes = @word.write_docx(body)
  let annotated = @word.read_docx_annotated(bytes[:])
  let d1 = @dump.dump_docx_document(
    annotated,
    source_file="rt.docx",
    source_bytes=bytes.length(),
  )
  let replayed_bytes = @dump.replay_docx_dump(d1)
  let replayed = @word.read_docx_annotated(replayed_bytes[:])
  let d2 = @dump.dump_docx_document(
    replayed,
    source_file="rt.docx",
    source_bytes=replayed_bytes.length(),
  )
  assert_eq(Json::array(d1.ops).stringify(), Json::array(d2.ops).stringify())
  // semantic spot check on the replayed document itself
  guard replayed.result().document
    is Document(children=[Paragraph(properties~, ..), ..], ..) else {
    fail("unexpected replayed shape")
  }
  assert_eq(properties.style_id, Some("Heading1"))
}

///|
test "docx replay refuses wrong formats and schemas" {
  let base : @dump.DumpEnvelope = {
    format: "docx",
    source_file: "x.docx",
    source_bytes: 1,
    source_sha256: None,
    batch_schema: "docx.batch/2",
    create_sheet: None,
    ops: [],
    assets: {},
    residual: [],
    warnings: [],
  }
  match (try? @dump.replay_docx_dump({ ..base, format: "xlsx" })) {
    Err(@dump.ReplayInvalidFormat(_)) => ()
    _ => fail("expected a format refusal")
  }
  match
    (try? @dump.replay_docx_dump({ ..base, batch_schema: "docx.batch/1" })) {
    Err(@dump.ReplayInvalidFormat(_)) => ()
    _ => fail("expected a schema refusal")
  }
}

///|
test "docx replay fails typed when an image asset is missing" {
  let envelope : @dump.DumpEnvelope = {
    format: "docx",
    source_file: "x.docx",
    source_bytes: 1,
    source_sha256: None,
    batch_schema: "docx.batch/2",
    create_sheet: None,
    ops: [
      Json::object({
        "op": Json::string("paragraph"),
        "params": Json::object({
          "runs": Json::array([
            Json::object({
              "image": Json::object({
                "path": Json::string("sha256-missing"),
                "content_type": Json::string("image/png"),
              }),
            }),
          ]),
        }),
      }),
    ],
    assets: {},
    residual: [],
    warnings: [],
  }
  match (try? @dump.replay_docx_dump(envelope)) {
    Err(@dump.ReplayFailed(_)) => ()
    Err(_) => fail("expected ReplayFailed")
    Ok(_) => fail("a dangling asset path must not replay")
  }
}

///|
/// Note ids are per-script dense indexes; a chunked stream must remap
/// them or chunk 2's references silently pair with chunk 1's bodies.
/// This builds >10000 ops with a distinct footnote in each chunk and
/// asserts each reference resolves to ITS OWN body after replay.
test "chunked docx replay remaps note ids across scripts" {
  let ops : Array[Json] = []
  let note_paragraph = (text : String) => {
    Json::object({
      "op": Json::string("paragraph"),
      "params": Json::object({
        "runs": Json::array([
          Json::object({ "text": Json::string("ref ") }),
          Json::object({
            "footnote": Json::object({ "text": Json::string(text) }),
          }),
        ]),
      }),
    })
  }
  ops.push(note_paragraph("first chunk note"))
  for index in 0..<10000 {
    ops.push(
      Json::object({
        "op": Json::string("paragraph"),
        "params": Json::object({ "text": Json::string("filler \{index}") }),
      }),
    )
  }
  // this op lands in the SECOND chunk
  ops.push(note_paragraph("second chunk note"))
  let envelope : @dump.DumpEnvelope = {
    format: "docx",
    source_file: "big.docx",
    source_bytes: 1,
    source_sha256: None,
    batch_schema: "docx.batch/2",
    create_sheet: None,
    ops,
    assets: {},
    residual: [],
    warnings: [],
  }
  let bytes = @dump.replay_docx_dump(envelope)
  let annotated = @word.read_docx_annotated(bytes[:])
  // both notes must exist as distinct bodies with their own text
  let bodies = annotated.footnote_bodies()
  let mut first = false
  let mut second = false
  for entry in bodies {
    let (_, body) = entry
    let rendered = "\{to_repr(body)}"
    if rendered.contains("first chunk note") {
      first = true
    }
    if rendered.contains("second chunk note") {
      second = true
    }
  }
  assert_true(first)
  assert_true(second)
  // and the references pair correctly: re-dump and check both note specs
  // carry their own text in op order
  let d2 = @dump.dump_docx_document(
    annotated,
    source_file="big.docx",
    source_bytes=bytes.length(),
  )
  let first_op = d2.ops[0].stringify()
  assert_true(first_op.contains("first chunk note"))
  assert_false(first_op.contains("second chunk note"))
  let last_op = d2.ops[d2.ops.length() - 1].stringify()
  assert_true(last_op.contains("second chunk note"))
  assert_false(last_op.contains("first chunk note"))
}
