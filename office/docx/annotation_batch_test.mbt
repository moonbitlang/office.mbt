///|
/// End-to-end nets for D4 annotation-batch mutation (#164): a multi-op
/// fold (add -> reply-by-label -> resolve-by-label) over one existing
/// DOCX, plus the strict refusal shapes and preservation.

///|
async fn with_annotation_dir(run : async (String) -> Unit) -> Unit {
  @async.with_task_group() <| group => {
    let directory = @afs.tmpdir(prefix="office-docx-annotate-")
    group.add_defer() <| () => {
      @async.protect_from_cancel(() => @afs.rmdir(directory, recursive=true))
    }
    run(directory)
  }
}

///|
fn annotation_fixture() -> Bytes raise {
  @word_fixture.write_docx([
    @word_fixture.paragraph([
      @word_fixture.run([@word_fixture.text("First paragraph")]),
    ]),
    @word_fixture.paragraph([
      @word_fixture.run([@word_fixture.text("Second paragraph")]),
    ]),
  ])
}

///|
async fn published_part(path : String, part : String) -> String? {
  let bytes = @afs.read_file(path).binary()
  let archive = @zip.read(bytes[:])
  match archive.get(part) {
    Some(payload) => Some(@utf8.decode(payload))
    None => None
  }
}

///|
async test "annotation batch folds add, reply, and resolve in one script" {
  with_annotation_dir() <| directory => {
    let input = directory + "/base.docx"
    @afs.write_file(
      input,
      annotation_fixture(),
      create_mode=CreateNew,
      permission=0o600,
    )
    let output = directory + "/annotated.docx"
    let batch = @docx.parse_annotation_batch(
      "{\"schema\": \"docx.annotation-batch/1\", \"ops\": [" +
      "{\"op\": \"comment_add\", \"anchor\": {\"at\": \"/docx/body/p[1]\"}, " +
      "\"author\": \"Ada\", \"body\": [\"Please revise\"], \"label\": \"root\"}, " +
      "{\"op\": \"comment_reply\", \"parent\": {\"label\": \"root\"}, " +
      "\"author\": \"Bob\", \"body\": [\"Done\"], \"label\": \"answer\"}, " +
      "{\"op\": \"comment_resolve\", \"target\": {\"label\": \"root\"}}" +
      "]}",
    )
    let result = @docx.transact_docx_annotations(
      @transaction.transaction_options(input, output_path=output),
      batch,
    )
    assert_eq(result.report.ops_applied, 3)
    assert_true(result.report.changed)
    // two comments minted with distinct ids
    assert_eq(result.report.labels.length(), 2)
    // per-op anchor/target are surfaced in the report (codex #216)
    assert_eq(result.report.results[0].op, "comment_add")
    assert_eq(result.report.results[0].anchor, Some("/docx/body/p[1]"))
    assert_eq(result.report.results[0].anchor_to, None)
    assert_eq(result.report.results[0].target, None)
    assert_eq(result.report.results[1].op, "comment_reply")
    assert_eq(result.report.results[1].anchor, None)
    // the reply's target is the root comment (its parent), not its own id
    assert_eq(
      result.report.results[1].target,
      Some(result.report.results[0].comment_id),
    )
    assert_eq(result.report.results[2].op, "comment_resolve")
    assert_eq(result.report.results[2].done, Some(true))
    assert_eq(
      result.report.results[2].target,
      Some(result.report.results[0].comment_id),
    )
    // the comments part carries both bodies
    guard published_part(output, "word/comments.xml") is Some(comments) else {
      fail("published comments.xml missing")
    }
    assert_true(comments.contains("Please revise"))
    assert_true(comments.contains("Done"))
    // resolution is recorded in commentsExtended
    guard published_part(output, "word/commentsExtended.xml") is Some(ext) else {
      fail("published commentsExtended.xml missing")
    }
    assert_true(ext.contains("w15:done") || ext.contains("done=\"1\""))
    // the changed-part manifest is the union across all three ops
    assert_true(result.report.changed_parts.contains("word/document.xml"))
    assert_true(result.report.changed_parts.contains("word/comments.xml"))
  }
}

///|
test "annotation batch parser refusals" {
  fn expect(text : String, fragment : String) -> Unit raise {
    try @docx.parse_annotation_batch(text) |> ignore catch {
      @docx.DocxAnnotationParseError(message) =>
        assert_true(message.contains(fragment))
    } noraise {
      _ => fail("expected refusal: " + fragment)
    }
  }

  expect("{", "not valid JSON")
  expect("{\"ops\": []}", "needs \"schema\"")
  // unknown members must fail loudly rather than be silently ignored
  expect(
    "{\"schema\": \"docx.annotation-batch/1\", \"ops\": [], \"extra\": 1}", "unknown member",
  )
  expect(
    "{\"schema\": \"docx.annotation-batch/1\", \"ops\": [{\"op\": \"nope\"}]}", "unknown op",
  )
  // forward label reference
  expect(
    "{\"schema\": \"docx.annotation-batch/1\", \"ops\": [" +
    "{\"op\": \"comment_reply\", \"parent\": {\"label\": \"future\"}, \"author\": \"A\", \"body\": [\"x\"]}]}",
    "before it is defined",
  )
  // duplicate label
  expect(
    "{\"schema\": \"docx.annotation-batch/1\", \"ops\": [" +
    "{\"op\": \"comment_add\", \"anchor\": {\"at\": \"/docx/body/p[1]\"}, \"author\": \"A\", \"body\": [\"x\"], \"label\": \"d\"}, " +
    "{\"op\": \"comment_add\", \"anchor\": {\"at\": \"/docx/body/p[1]\"}, \"author\": \"A\", \"body\": [\"y\"], \"label\": \"d\"}]}",
    "duplicate label",
  )
  // non-body-paragraph anchor
  expect(
    "{\"schema\": \"docx.annotation-batch/1\", \"ops\": [" +
    "{\"op\": \"comment_add\", \"anchor\": {\"at\": \"/docx/body/tbl[1]/tr[1]\"}, \"author\": \"A\", \"body\": [\"x\"]}]}",
    "single body paragraph",
  )
  // annotation anchors require the selector parser's canonical rendering and
  // expose their tighter owner-defined ordinal ceiling.
  expect(
    "{\"schema\": \"docx.annotation-batch/1\", \"ops\": [" +
    "{\"op\": \"comment_add\", \"anchor\": {\"at\": \"/docx/body/p[01]\"}, \"author\": \"A\", \"body\": [\"x\"]}]}",
    "canonical selector spelling",
  )
  ignore(
    @docx.parse_annotation_batch(
      "{\"schema\": \"docx.annotation-batch/1\", \"ops\": [" +
      "{\"op\": \"comment_add\", \"anchor\": {\"at\": \"/docx/body/p[9999999]\"}, \"author\": \"A\", \"body\": [\"x\"]}]}",
    ),
  )
  expect(
    "{\"schema\": \"docx.annotation-batch/1\", \"ops\": [" +
    "{\"op\": \"comment_add\", \"anchor\": {\"at\": \"/docx/body/p[10000000]\"}, \"author\": \"A\", \"body\": [\"x\"]}]}",
    "paragraph index is out of range",
  )
  // empty body
  expect(
    "{\"schema\": \"docx.annotation-batch/1\", \"ops\": [" +
    "{\"op\": \"comment_add\", \"anchor\": {\"at\": \"/docx/body/p[1]\"}, \"author\": \"A\", \"body\": []}]}",
    "at least one paragraph",
  )
  // unknown members inside op / anchor / reference objects also refuse
  expect(
    "{\"schema\": \"docx.annotation-batch/1\", \"ops\": [" +
    "{\"op\": \"comment_add\", \"anchor\": {\"at\": \"/docx/body/p[1]\"}, \"author\": \"A\", \"body\": [\"x\"], \"typo\": 1}]}",
    "unknown member",
  )
  expect(
    "{\"schema\": \"docx.annotation-batch/1\", \"ops\": [" +
    "{\"op\": \"comment_add\", \"anchor\": {\"at\": \"/docx/body/p[1]\", \"nope\": 1}, \"author\": \"A\", \"body\": [\"x\"]}]}",
    "unknown member",
  )
  expect(
    "{\"schema\": \"docx.annotation-batch/1\", \"ops\": [" +
    "{\"op\": \"comment_resolve\", \"target\": {\"comment_id\": \"1\", \"stray\": 1}}]}",
    "unknown member",
  )
  // a typo'd discriminator is an unknown member, not merely a missing op
  expect(
    "{\"schema\": \"docx.annotation-batch/1\", \"ops\": [" +
    "{\"opp\": \"comment_add\", \"anchor\": {\"at\": \"/docx/body/p[1]\"}, \"author\": \"A\", \"body\": [\"x\"]}]}",
    "unknown member",
  )
  // a genuinely omitted op (no stray members) still reports the missing op
  expect(
    "{\"schema\": \"docx.annotation-batch/1\", \"ops\": [" +
    "{\"author\": \"A\", \"body\": [\"x\"]}]}",
    "needs a non-empty string \"op\"",
  )
}

///|
async test "annotation range comment_add surfaces two valid selectors" {
  with_annotation_dir() <| directory => {
    let input = directory + "/base.docx"
    @afs.write_file(
      input,
      annotation_fixture(),
      create_mode=CreateNew,
      permission=0o600,
    )
    let output = directory + "/ranged.docx"
    let batch = @docx.parse_annotation_batch(
      "{\"schema\": \"docx.annotation-batch/1\", \"ops\": [" +
      "{\"op\": \"comment_add\", \"anchor\": {\"at\": \"/docx/body/p[1]\", \"to\": \"/docx/body/p[2]\"}, " +
      "\"author\": \"Ada\", \"body\": [\"Spans two paragraphs\"]}" +
      "]}",
    )
    let result = @docx.transact_docx_annotations(
      @transaction.transaction_options(input, output_path=output),
      batch,
    )
    let add = result.report.results[0]
    // a range is two individually valid canonical selectors, not a ".."
    // literal — both are the exact canonical /docx/body/p[K] form
    assert_eq(add.anchor, Some("/docx/body/p[1]"))
    assert_eq(add.anchor_to, Some("/docx/body/p[2]"))
  }
}

///|
async test "annotation batch with no ops republishes the source bytes exactly" {
  with_annotation_dir() <| directory => {
    let input = directory + "/base.docx"
    let source = annotation_fixture()
    @afs.write_file(input, source, create_mode=CreateNew, permission=0o600)
    let output = directory + "/noop.docx"
    let batch = @docx.parse_annotation_batch(
      "{\"schema\": \"docx.annotation-batch/1\", \"ops\": []}",
    )
    let result = @docx.transact_docx_annotations(
      @transaction.transaction_options(input, output_path=output),
      batch,
    )
    assert_eq(result.report.ops_applied, 0)
    assert_false(result.report.changed)
    assert_eq(result.report.changed_parts.length(), 0)
    // the published bytes are byte-for-byte the source (reuse-original)
    let published = @afs.read_file(output).binary()
    assert_eq(published, source)
  }
}

///|
async test "annotation reply to a missing comment id refuses, nothing published" {
  with_annotation_dir() <| directory => {
    let input = directory + "/base.docx"
    @afs.write_file(
      input,
      annotation_fixture(),
      create_mode=CreateNew,
      permission=0o600,
    )
    let output = directory + "/out.docx"
    let batch = @docx.parse_annotation_batch(
      "{\"schema\": \"docx.annotation-batch/1\", \"ops\": [" +
      "{\"op\": \"comment_reply\", \"parent\": {\"comment_id\": \"9999\"}, " +
      "\"author\": \"A\", \"body\": [\"x\"]}]}",
    )
    let failed = try {
      @docx.transact_docx_annotations(
        @transaction.transaction_options(input, output_path=output),
        batch,
      )
      |> ignore
      false
    } catch {
      _ => true
    }
    assert_true(failed)
    assert_false(@afs.exists(output))
  }
}
