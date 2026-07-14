///|
async fn with_docx_session_test_dir(run : async (String) -> Unit) -> Unit {
  @async.with_task_group() <| group => {
    let directory = @afs.tmpdir(prefix="office-docx-session-")
    group.add_defer() <| () => {
      @async.protect_from_cancel(() => @afs.rmdir(directory, recursive=true))
    }
    run(directory)
  }
}

///|
async fn write_docx_session_file(path : String, bytes : Bytes) -> Unit {
  @afs.write_file(path, bytes, create_mode=CreateNew, permission=0o600)
}

///|
async fn docx_session_error_code(
  run : async () -> @transaction.TransactionReport,
) -> String {
  try run() catch {
    @transaction.TransactionError(code~, ..) => code
    error => fail("expected TransactionError, received \{error}")
  } noraise {
    _ => fail("expected DOCX session failure")
  }
}

///|
async test "D1 session no-op reuses the exact transaction source" {
  with_docx_session_test_dir(directory => {
    let input = "\{directory}/input.docx"
    let original = @word_fixture.new_blank_docx()
    write_docx_session_file(input, original)
    let report = @docx.transact_docx(@transaction.transaction_options(input), session => {
      assert_true(session.is_noop())
      debug_inspect(session.pending_parts(), content="[]")
      let fingerprints = session.source_part_fingerprints()
      assert_true(fingerprints.length() > 0)
      for index in 1..<fingerprints.length() {
        assert_true(
          fingerprints[index - 1].part().compare(fingerprints[index].part()) <=
          0,
        )
      }
      let main = session.annotated().main_story_part()
      guard session.source_part(main) is Some(main_bytes) else {
        fail("session did not retain its indexed main part")
      }
      let mut matched = false
      for fingerprint in fingerprints {
        if fingerprint.part() == main {
          assert_eq(fingerprint.byte_length(), main_bytes.length())
          assert_eq(fingerprint.crc32(), @zip.crc32(main_bytes))
          matched = true
        }
      }
      assert_true(matched)
    })
    assert_false(report.changed)
    assert_false(report.committed)
    assert_true(report.preservation.whole_file_identical)
    assert_true(report.preservation.manifest_enforced)
    assert_eq(report.validations.length(), 2)
    assert_eq(report.validations[1].name, "office-docx-package")
    assert_eq(@afs.read_file(input).binary(), original)
  })
}

///|
async test "D1 session adopts annotation plans with an exact preservation manifest" {
  with_docx_session_test_dir(directory => {
    let input = "\{directory}/input.docx"
    let output = "\{directory}/output.docx"
    let original = @word_fixture.new_blank_docx()
    write_docx_session_file(input, original)
    let allocated = Ref("")
    let report = @docx.transact_docx(
      @transaction.transaction_options(input, output_path=output),
      session => {
        let specification = @word_fixture.comment_spec(
          author="D1",
          from=0,
          to=0,
          [
            @word_fixture.paragraph([
              @word_fixture.run([@word_fixture.text("preserved review")]),
            ]),
          ],
        )
        let (plan, comment_id) = @word.plan_comment_addition(
          session.annotated(),
          session.source_bytes(),
          at_relative="p[1]",
          to_relative="p[1]",
          specification,
        )
        debug_inspect(plan.unpinned_edited_parts(), content="[]")
        session.queue_plan(plan)
        allocated.val = comment_id
        debug_inspect(
          session.pending_parts(),
          content=(
            #|[
            #|  "word/comments.xml",
            #|  "word/document.xml",
            #|  "[Content_Types].xml",
            #|  "word/_rels/document.xml.rels",
            #|]
          ),
        )
      },
    )
    assert_eq(allocated.val, "0")
    assert_true(report.changed)
    assert_true(report.committed)
    assert_true(report.preservation.manifest_enforced)
    assert_eq(report.preservation.changed.length(), 3)
    assert_eq(report.preservation.added.length(), 1)
    assert_eq(report.preservation.added[0], "word/comments.xml")
    assert_eq(report.validations.length(), 2)
    let candidate = @afs.read_file(output).binary()
    let annotated = @word_fixture.read_docx_annotated(candidate)
    assert_eq(annotated.annotations().comments().length(), 1)
    assert_eq(annotated.annotations().comments()[0].author(), Some("D1"))
    assert_eq(@afs.read_file(input).binary(), original)
  })
}

///|
async test "D1 session rejects unsafe plans and keeps failed adoption atomic" {
  with_docx_session_test_dir(directory => {
    let input = "\{directory}/input.docx"
    let original = @word_fixture.new_blank_docx()
    write_docx_session_file(input, original)
    let unpinned = docx_session_error_code(() => {
      @docx.transact_docx(@transaction.transaction_options(input), session => {
        let part = session.annotated().main_story_part()
        let plan = @splice.SplicePlan::new()
        plan.edit_part(part, @splice.span_edit(start=0, end=0, b""))
        session.queue_plan(plan)
      })
    })
    assert_eq(unpinned, "office.docx.unpinned_plan")
    let stale = docx_session_error_code(() => {
      @docx.transact_docx(@transaction.transaction_options(input), session => {
        let part = session.annotated().main_story_part()
        let plan = @splice.SplicePlan::new()
        plan.pin_part(part, @utf8.encode("<different/>"))
        plan.edit_part(part, @splice.span_edit(start=0, end=0, b""))
        session.queue_plan(plan)
      })
    })
    assert_eq(stale, "office.docx.stale_plan")
    let ranged = docx_session_error_code(() => {
      @docx.transact_docx(@transaction.transaction_options(input), session => {
        session.queue_span_edit(
          session.annotated().main_story_part(),
          start=0,
          end=1_000_000,
          b"",
        )
      })
    })
    assert_eq(ranged, "office.docx.invalid_range")
    let malformed = docx_session_error_code(() => {
      @docx.transact_docx(@transaction.transaction_options(input), session => {
        session.queue_span_edit(
          session.annotated().main_story_part(),
          start=0,
          end=0,
          @utf8.encode("<broken>"),
        )
      })
    })
    assert_eq(malformed, "office.docx.invalid_edit")
    let report = @docx.transact_docx(@transaction.transaction_options(input), session => {
      let part = session.annotated().main_story_part()
      guard session.source_part(part) is Some(source) else {
        fail("missing main part")
      }
      let plan = @splice.SplicePlan::new()
      plan.pin_part(part, source)
      plan.edit_part(part, @splice.span_edit(start=0, end=5, b""))
      plan.edit_part(part, @splice.span_edit(start=3, end=7, b""))
      try session.queue_plan(plan) catch {
        TransactionError(code~, ..) =>
          assert_eq(code, "office.docx.overlapping_edits")
      } noraise {
        _ => fail("expected overlapping plan rejection")
      }
      assert_true(session.is_noop())
      debug_inspect(session.pending_parts(), content="[]")
    })
    assert_false(report.changed)
    assert_eq(@afs.read_file(input).binary(), original)
    let invalid_output = "\{directory}/invalid-output.docx"
    let unwired = docx_session_error_code(() => {
      @docx.transact_docx(
        @transaction.transaction_options(input, output_path=invalid_output),
        session => session.queue_added_part("word/unwired.bin", b"unwired"),
      )
    })
    assert_eq(unwired, "office.transaction.validation_failed")
    assert_false(@afs.exists(invalid_output))
    assert_eq(@afs.read_file(input).binary(), original)
  })
}
