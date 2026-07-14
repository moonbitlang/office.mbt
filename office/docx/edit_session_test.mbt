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
      let mut matched = false
      for fingerprint in fingerprints {
        if fingerprint.part() == main {
          assert_true(fingerprint.byte_length() > 0)
          fingerprint.crc32() |> ignore
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
async test "D1 session isolates adopted plans from later caller mutations" {
  with_docx_session_test_dir(directory => {
    let input = "\{directory}/input.docx"
    let output = "\{directory}/output.docx"
    let original = @word_fixture.new_blank_docx()
    let archive = @zip.read(original)
    guard archive.get("word/document.xml") is Some(source) else {
      fail("fixture is missing word/document.xml")
    }
    guard source.find(b"</w:body>") is Some(insert_at) else {
      fail("fixture main document has no body close tag")
    }
    write_docx_session_file(input, original)
    let report = @docx.transact_docx(
      @transaction.transaction_options(input, output_path=output),
      session => {
        let plan = @splice.SplicePlan::new()
        plan.pin_part("word/document.xml", source)
        plan.edit_part(
          "word/document.xml",
          @splice.span_edit(
            start=insert_at,
            end=insert_at,
            b"<!--queued-before-adoption-->\n",
          ),
        )
        session.queue_plan(plan)

        // The callback still owns `plan`; mutating its containers after
        // adoption must not change the session's validated snapshot.
        plan.edit_part(
          "word/document.xml",
          @splice.span_edit(
            start=insert_at,
            end=insert_at,
            b"<!--late-caller-edit-->\n",
          ),
        )
        plan.add_part("word/late-caller-part.bin", b"late")
        assert_eq(session.pending_parts(), ["word/document.xml"])
      },
    )
    assert_true(report.committed)
    let result = @zip.read(@afs.read_file(output).binary())
    guard result.get("word/document.xml") is Some(document) else {
      fail("candidate lost word/document.xml")
    }
    let text = @utf8.decode(document, ignore_bom=true)
    assert_true(text.contains("queued-before-adoption"))
    assert_false(text.contains("late-caller-edit"))
    assert_true(result.get("word/late-caller-part.bin") is None)
  })
}

///|
async test "D1 session rejects sibling-dense XML before indexing" {
  with_docx_session_test_dir(directory => {
    let input = "\{directory}/input.docx"
    let archive = @zip.read(@word_fixture.new_blank_docx())
    let document = StringBuilder()
    document.write_string(
      "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:body>",
    )
    for _ in 0..<70_000 {
      document.write_string("<w:p/>")
    }
    document.write_string("</w:body></w:document>")
    assert_true(
      archive.replace("word/document.xml", @utf8.encode(document.to_string())),
    )
    let source = @zip.write(archive)
    assert_true(source.length() < 1024 * 1024)
    write_docx_session_file(input, source)
    let callback_called = Ref(false)
    let code = docx_session_error_code(() => {
      @docx.transact_docx(@transaction.transaction_options(input), _ => {
        callback_called.val = true
      })
    })
    assert_eq(code, "office.docx.resource_limit")
    assert_false(callback_called.val)
    assert_eq(@afs.read_file(input).binary(), source)
  })
}

///|
async test "D1 semantic planners bound unreferenced relationship stories" {
  with_docx_session_test_dir(directory => {
    let input = "\{directory}/input.docx"
    let output = "\{directory}/output.docx"
    let original = @word_fixture.write_docx_with_comments(
      [
        @word_fixture.paragraph([
          @word_fixture.run([@word_fixture.text("Claim")]),
        ]),
      ],
      [
        @word_fixture.comment_spec(author="Ada", from=0, to=0, [
          @word_fixture.paragraph([
            @word_fixture.run([@word_fixture.text("Explain")]),
          ]),
        ]),
      ],
    )
    let archive = @zip.read(original)
    guard archive.get("word/_rels/document.xml.rels") is Some(rels_bytes) else {
      fail("fixture is missing main relationships")
    }
    let rels = @utf8.decode(rels_bytes, ignore_bom=true)
    let wired_rels = rels.replace(
      old="</Relationships>",
      new=(
        #|<Relationship Id="rIdUnreferencedHeader" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/header" Target="unreferenced-header.xml"/></Relationships>
      ),
    )
    assert_true(
      archive.replace("word/_rels/document.xml.rels", @utf8.encode(wired_rels)),
    )
    guard archive.get("[Content_Types].xml") is Some(types_bytes) else {
      fail("fixture is missing content types")
    }
    let types = @utf8.decode(types_bytes, ignore_bom=true)
    let wired_types = types.replace(
      old="</Types>",
      new=(
        #|<Override PartName="/word/unreferenced-header.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.header+xml"/></Types>
      ),
    )
    assert_true(
      archive.replace("[Content_Types].xml", @utf8.encode(wired_types)),
    )
    let header = StringBuilder()
    header.write_string(
      "<w:hdr xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\">",
    )
    for _ in 0..<70_000 {
      header.write_string("<w:p/>")
    }
    header.write_string("</w:hdr>")
    archive.add(
      "word/unreferenced-header.xml",
      @utf8.encode(header.to_string()),
    )
    let source = @zip.write(archive)
    write_docx_session_file(input, source)
    let reply = @word_fixture.comment_spec(author="Bob", from=0, to=0, [
      @word_fixture.paragraph([
        @word_fixture.run([@word_fixture.text("bounded reply")]),
      ]),
    ])
    let code = docx_session_error_code(() => {
      @docx.transact_docx(
        @transaction.transaction_options(input, output_path=output),
        session => session.queue_comment_reply(parent_id="0", reply) |> ignore,
      )
    })
    assert_eq(code, "office.docx.resource_limit")
    assert_false(@afs.exists(output))
    assert_eq(@afs.read_file(input).binary(), source)
  })
}

///|
async test "D1 session bounds comment fragments before derived allocation" {
  with_docx_session_test_dir(directory => {
    let blank_path = "\{directory}/blank.docx"
    let blank_output = "\{directory}/blank-output.docx"
    let blank = @word_fixture.new_blank_docx()
    write_docx_session_file(blank_path, blank)
    let oversized_text = "x".repeat(1024 * 1024 + 1)
    let oversized = @word_fixture.comment_spec(author="D1", from=0, to=0, [
      @word_fixture.paragraph([
        @word_fixture.run([@word_fixture.text(oversized_text)]),
      ]),
    ])
    let addition_code = docx_session_error_code(() => {
      @docx.transact_docx(
        @transaction.transaction_options(blank_path, output_path=blank_output),
        session => {
          session.queue_comment_addition(
            at_relative="p[1]",
            to_relative="p[1]",
            oversized,
          )
          |> ignore
        },
      )
    })
    assert_eq(addition_code, "office.docx.resource_limit")
    assert_false(@afs.exists(blank_output))
    assert_eq(@afs.read_file(blank_path).binary(), blank)
    let threaded_path = "\{directory}/threaded.docx"
    let threaded_output = "\{directory}/threaded-output.docx"
    let threaded = @word_fixture.write_docx_with_comments(
      [
        @word_fixture.paragraph([
          @word_fixture.run([@word_fixture.text("Claim")]),
        ]),
      ],
      [
        @word_fixture.comment_spec(author="Ada", from=0, to=0, [
          @word_fixture.paragraph([
            @word_fixture.run([@word_fixture.text("Explain")]),
          ]),
        ]),
      ],
    )
    write_docx_session_file(threaded_path, threaded)
    let reply_body = [
      @word_fixture.paragraph([
        @word_fixture.run([@word_fixture.text("bounded")]),
      ]),
    ]
    let reply = @word_fixture.comment_spec(
      author="Bob",
      from=0,
      to=0,
      reply_body,
    )
    let extra = @word_fixture.paragraph([
      @word_fixture.run([@word_fixture.text("wide")]),
    ])
    for _ in 0..<5_000 {
      reply_body.push(extra)
    }
    let reply_code = docx_session_error_code(() => {
      @docx.transact_docx(
        @transaction.transaction_options(
          threaded_path,
          output_path=threaded_output,
        ),
        session => session.queue_comment_reply(parent_id="0", reply) |> ignore,
      )
    })
    assert_eq(reply_code, "office.docx.resource_limit")
    assert_false(@afs.exists(threaded_output))
    assert_eq(@afs.read_file(threaded_path).binary(), threaded)
  })
}

///|
async test "D1 session rejects a second semantic comment operation" {
  with_docx_session_test_dir(directory => {
    let input = "\{directory}/input.docx"
    let output = "\{directory}/output.docx"
    let original = @word_fixture.new_blank_docx()
    write_docx_session_file(input, original)
    let specification = @word_fixture.comment_spec(author="D1", from=0, to=0, [
      @word_fixture.paragraph([
        @word_fixture.run([@word_fixture.text("one at a time")]),
      ]),
    ])
    let first_id = Ref("")
    let code = docx_session_error_code(() => {
      @docx.transact_docx(
        @transaction.transaction_options(input, output_path=output),
        session => {
          first_id.val = session.queue_comment_addition(
            at_relative="p[1]",
            to_relative="p[1]",
            specification,
          )
          session.queue_comment_addition(
            at_relative="p[1]",
            to_relative="p[1]",
            specification,
          )
          |> ignore
        },
      )
    })
    assert_eq(first_id.val, "0")
    assert_eq(code, "office.docx.stale_semantic_state")
    assert_false(@afs.exists(output))
    assert_eq(@afs.read_file(input).binary(), original)
  })
}

///|
async test "D1 session rejects generic and semantic plan composition in either order" {
  with_docx_session_test_dir(directory => {
    let input = "\{directory}/input.docx"
    let generic_first_output = "\{directory}/generic-first.docx"
    let semantic_first_output = "\{directory}/semantic-first.docx"
    let original = @word_fixture.new_blank_docx()
    write_docx_session_file(input, original)
    let specification = @word_fixture.comment_spec(author="D1", from=0, to=0, [
      @word_fixture.paragraph([
        @word_fixture.run([@word_fixture.text("snapshot-bound")]),
      ]),
    ])
    let generic_first = docx_session_error_code(() => {
      @docx.transact_docx(
        @transaction.transaction_options(
          input,
          output_path=generic_first_output,
        ),
        session => {
          session.queue_added_part("word/generic.bin", b"generic")
          session.queue_comment_addition(
            at_relative="p[1]",
            to_relative="p[1]",
            specification,
          )
          |> ignore
        },
      )
    })
    assert_eq(generic_first, "office.docx.stale_semantic_state")
    assert_false(@afs.exists(generic_first_output))
    let semantic_first = docx_session_error_code(() => {
      @docx.transact_docx(
        @transaction.transaction_options(
          input,
          output_path=semantic_first_output,
        ),
        session => {
          session.queue_comment_addition(
            at_relative="p[1]",
            to_relative="p[1]",
            specification,
          )
          |> ignore
          session.queue_added_part("word/generic.bin", b"generic")
        },
      )
    })
    assert_eq(semantic_first, "office.docx.stale_semantic_state")
    assert_false(@afs.exists(semantic_first_output))
    assert_eq(@afs.read_file(input).binary(), original)
  })
}

///|
async test "D1 validator rejects equivalent numeric comment identities" {
  with_docx_session_test_dir(directory => {
    let input = "\{directory}/input.docx"
    let output = "\{directory}/output.docx"
    let original = @word_fixture.write_docx_with_comments(
      [
        @word_fixture.paragraph([
          @word_fixture.run([@word_fixture.text("Claim")]),
        ]),
      ],
      [
        @word_fixture.comment_spec(author="Ada", from=0, to=0, [
          @word_fixture.paragraph([
            @word_fixture.run([@word_fixture.text("Original")]),
          ]),
        ]),
      ],
    )
    let archive = @zip.read(original)
    let annotated = @word.read_docx_annotated_archive(archive)
    guard annotated.comments_part() is Some(comments_part) else {
      fail("fixture is missing its comments part")
    }
    guard annotated.story_root_span("/comments") is Some(comments_root) else {
      fail("fixture is missing its comments root span")
    }
    guard comments_root.close_tag_start() is Some(insert_at) else {
      fail("fixture comments root must use an explicit close tag")
    }
    guard archive.get(comments_part) is Some(comments_source) else {
      fail("fixture comments part is unreadable")
    }
    let duplicate = @word.comment_definition_fragment(
      @word_fixture.comment_spec(author="Mallory", from=0, to=0, [
        @word_fixture.paragraph([
          @word_fixture.run([@word_fixture.text("Duplicate identity")]),
        ]),
      ]),
      id="00",
    )
    let plan = @splice.SplicePlan::new()
    plan.pin_part(comments_part, comments_source)
    plan.edit_part(
      comments_part,
      @splice.span_edit(start=insert_at, end=insert_at, @utf8.encode(duplicate)),
    )
    write_docx_session_file(input, original)
    let code = docx_session_error_code(() => {
      @docx.transact_docx(
        @transaction.transaction_options(input, output_path=output),
        session => session.queue_plan(plan),
      )
    })
    assert_eq(code, "office.transaction.validation_failed")
    assert_false(@afs.exists(output))
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
        let comment_id = session.queue_comment_addition(
          at_relative="p[1]",
          to_relative="p[1]",
          specification,
        )
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
async test "D1 session plans replies and resolution from its archive" {
  with_docx_session_test_dir(directory => {
    let input = "\{directory}/input.docx"
    let replied_path = "\{directory}/replied.docx"
    let resolved_path = "\{directory}/resolved.docx"
    let original = @word_fixture.write_docx_with_comments(
      [
        @word_fixture.paragraph([
          @word_fixture.run([@word_fixture.text("Claim")]),
        ]),
      ],
      [
        @word_fixture.comment_spec(author="Ada", from=0, to=0, [
          @word_fixture.paragraph([
            @word_fixture.run([@word_fixture.text("Explain")]),
          ]),
        ]),
      ],
    )
    write_docx_session_file(input, original)
    let reply_id = Ref("")
    let reply = @docx.transact_docx(
      @transaction.transaction_options(input, output_path=replied_path),
      session => {
        let specification = @word_fixture.comment_spec(
          author="Bob",
          from=0,
          to=0,
          [
            @word_fixture.paragraph([
              @word_fixture.run([@word_fixture.text("Evidence")]),
            ]),
          ],
        )
        reply_id.val = session.queue_comment_reply(parent_id="0", specification)
      },
    )
    assert_true(reply.committed)
    assert_eq(reply_id.val, "1")
    let resolution = @docx.transact_docx(
      @transaction.transaction_options(replied_path, output_path=resolved_path),
      session => session.queue_comment_resolution(comment_id="0", done=true),
    )
    assert_true(resolution.committed)
    let resolved = @word_fixture.read_docx_annotated(
      @afs.read_file(resolved_path).binary(),
    )
    assert_eq(resolved.annotations().comments().length(), 2)
    assert_eq(resolved.annotations().comments()[0].done(), Some(true))
    assert_eq(resolved.annotations().comments()[1].parent_id(), Some("0"))
    assert_eq(@afs.read_file(input).binary(), original)
  })
}

///|
async test "D1 session rejects unsafe plans and keeps failed adoption atomic" {
  with_docx_session_test_dir(directory => {
    let input = "\{directory}/input.docx"
    let original = @word_fixture.new_blank_docx()
    let fixture_archive = @zip.read(original)
    guard fixture_archive.get("word/document.xml") is Some(main_source) else {
      fail("fixture is missing word/document.xml")
    }
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
    let oversized_manifest = docx_session_error_code(() => {
      @docx.transact_docx(@transaction.transaction_options(input), session => {
        for index in 0..<257 {
          session.queue_added_part(
            "word/generated/part-\{index}.xml",
            @utf8.encode("<x/>"),
          )
        }
      })
    })
    assert_eq(oversized_manifest, "office.docx.resource_limit")
    let report = @docx.transact_docx(@transaction.transaction_options(input), session => {
      let part = session.annotated().main_story_part()
      let plan = @splice.SplicePlan::new()
      plan.pin_part(part, main_source)
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
