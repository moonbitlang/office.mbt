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
fn mixed_case_docx_session_fixture() -> Bytes raise {
  let archive = @zip.Archive::new()
  archive.add(
    "[CONTENT_TYPES].XML",
    @utf8.encode(
      "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\"><Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/><Override PartName=\"/CUSTOM/MAIN.XML\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml\"/></Types>",
    ),
  )
  archive.add(
    "_rels/.rels",
    @utf8.encode(
      "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"main\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"custom/main.xml\"/></Relationships>",
    ),
  )
  archive.add(
    "CUSTOM/MAIN.XML",
    @utf8.encode(
      "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:body><w:p/><w:sectPr/></w:body></w:document>",
    ),
  )
  archive.add(
    "custom/_RELS/main.xml.RELS",
    @utf8.encode(
      "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"/>",
    ),
  )
  @zip.write(archive)
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
    assert_eq(report.validations.length(), 3)
    assert_eq(report.validations[0].name, "office-docx-bounded")
    assert_eq(report.validations[1].name, "office-portable-opc")
    assert_eq(report.validations[2].name, "office-docx-package")
    assert_eq(@afs.read_file(input).binary(), original)
  })
}

///|
async test "D1 resolves case-equivalent OPC targets to exact part spelling" {
  with_docx_session_test_dir(directory => {
    let input = "\{directory}/mixed.docx"
    let output = "\{directory}/mixed-output.docx"
    let original = mixed_case_docx_session_fixture()
    let archive = @zip.read(original)
    guard archive.get("CUSTOM/MAIN.XML") is Some(document) else {
      fail("mixed-case fixture is missing its main part")
    }
    guard document.find(b"</w:body>") is Some(insert_at) else {
      fail("mixed-case fixture main part has no body close")
    }
    write_docx_session_file(input, original)
    let report = @docx.transact_docx(
      @transaction.transaction_options(input, output_path=output),
      session => {
        assert_eq(session.annotated().main_story_part(), "CUSTOM/MAIN.XML")
        session.queue_span_edit(
          "CUSTOM/MAIN.XML",
          start=insert_at,
          end=insert_at,
          b"<!--case-preserved-->",
        )
      },
    )
    assert_true(report.committed)
    let result = @zip.read(@afs.read_file(output).binary())
    guard result.get("CUSTOM/MAIN.XML") is Some(actual) else {
      fail("candidate lost the exact main-part spelling")
    }
    assert_true(actual.find(b"<!--case-preserved-->") is Some(_))
    assert_true(result.get("custom/main.xml") is None)
  })
}

///|
async test "D1 semantic annotations preserve exact metadata part spelling" {
  with_docx_session_test_dir(directory => {
    let input = "\{directory}/mixed-semantic.docx"
    let added_path = "\{directory}/mixed-added.docx"
    let resolved_path = "\{directory}/mixed-resolved.docx"
    let original = mixed_case_docx_session_fixture()
    write_docx_session_file(input, original)
    let specification = @word_fixture.comment_spec(
      author="Case",
      from=0,
      to=0,
      [
        @word_fixture.paragraph([
          @word_fixture.run([@word_fixture.text("preserve physical names")]),
        ]),
      ],
    )
    let addition = @docx.transact_docx(
      @transaction.transaction_options(input, output_path=added_path),
      session => {
        inspect(
          session.queue_comment_addition(
            at_relative="p[1]",
            to_relative="p[1]",
            specification,
          ),
          content="0",
        )
      },
    )
    assert_true(addition.committed)
    let resolution = @docx.transact_docx(
      @transaction.transaction_options(added_path, output_path=resolved_path),
      session => session.queue_comment_resolution(comment_id="0", done=true),
    )
    assert_true(resolution.committed)
    let result = @zip.read(@afs.read_file(resolved_path).binary())
    guard result.get("custom/_RELS/main.xml.RELS") is Some(rels_bytes) else {
      fail("semantic edits lost the exact relationships-part spelling")
    }
    assert_true(
      @utf8.decode(rels_bytes, ignore_bom=true).contains("commentsExtended.xml"),
    )
    guard result.get("[CONTENT_TYPES].XML") is Some(types_bytes) else {
      fail("semantic edits lost the exact content-types spelling")
    }
    assert_true(
      @utf8.decode(types_bytes, ignore_bom=true).contains(
        "/CUSTOM/commentsExtended.xml",
      ),
    )
    assert_true(result.get("CUSTOM/_rels/MAIN.XML.rels") is None)
    assert_true(result.get("[Content_Types].xml") is None)
    let verified = @word_fixture.read_docx_annotated(
      @afs.read_file(resolved_path).binary(),
    )
    assert_eq(verified.annotations().comments()[0].done(), Some(true))
  })
}

///|
async test "D1 comment addition preserves true Strict OOXML dialect" {
  with_docx_session_test_dir(directory => {
    let input = "\{directory}/strict-input.docx"
    let output = "\{directory}/strict-output.docx"
    let strict_wml = "http://purl.oclc.org/ooxml/wordprocessingml/main"
    let strict_office = "http://purl.oclc.org/ooxml/officeDocument/relationships/"
    let transitional_wml = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
    let builder = @opc.PackageBuilder::new()
    builder.add_default(
      "rels", "application/vnd.openxmlformats-package.relationships+xml",
    )
    builder.add_default("xml", "application/xml")
    builder.add_override(
      "/word/document.xml", "application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml",
    )
    builder.add_relationship(
      "rIdMain",
      strict_office + "officeDocument",
      "word/document.xml",
    )
    builder.add_part(
      "word/document.xml",
      @utf8.encode(
        "<w:document xmlns:w=\"\{strict_wml}\"><w:body><w:p><w:r><w:t>Strict source</w:t></w:r></w:p><w:sectPr/></w:body></w:document>",
      ),
    )
    write_docx_session_file(input, builder.build())
    let specification = @word_fixture.comment_spec(
      author="Strict",
      from=0,
      to=0,
      [
        @word_fixture.paragraph([
          @word_fixture.run([@word_fixture.text("Strict comment")]),
        ]),
      ],
    )
    let report = @docx.transact_docx(
      @transaction.transaction_options(input, output_path=output),
      session => {
        inspect(
          session.queue_comment_addition(
            at_relative="p[1]",
            to_relative="p[1]",
            specification,
          ),
          content="0",
        )
      },
    )
    assert_true(report.committed)
    let result = @zip.read(@afs.read_file(output).binary())
    guard result.get("word/document.xml") is Some(document_bytes) else {
      fail("Strict candidate lost its main part")
    }
    guard result.get("word/comments.xml") is Some(comments_bytes) else {
      fail("Strict candidate lost its comments part")
    }
    guard result.get("word/_rels/document.xml.rels") is Some(rels_bytes) else {
      fail("Strict candidate lost its main relationships")
    }
    let document = @utf8.decode(document_bytes, ignore_bom=true)
    let comments = @utf8.decode(comments_bytes, ignore_bom=true)
    let relationships = @utf8.decode(rels_bytes, ignore_bom=true)
    assert_true(document.contains(strict_wml))
    assert_true(comments.contains(strict_wml))
    assert_false(document.contains(transitional_wml))
    assert_false(comments.contains(transitional_wml))
    assert_true(relationships.contains(strict_office + "comments"))
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
async test "D1 span edits cannot introduce a foreign XML declaration" {
  with_docx_session_test_dir(directory => {
    let input = "\{directory}/input.docx"
    let output = "\{directory}/output.docx"
    let original = @word_fixture.new_blank_docx()
    let archive = @zip.read(original)
    guard archive.get("word/document.xml") is Some(document) else {
      fail("fixture is missing word/document.xml")
    }
    guard document.find(b"UTF-8") is Some(encoding_at) else {
      fail("fixture main part has no UTF-8 declaration")
    }
    write_docx_session_file(input, original)
    let code = docx_session_error_code(() => {
      @docx.transact_docx(
        @transaction.transaction_options(input, output_path=output),
        session => {
          session.queue_span_edit(
            "word/document.xml",
            start=encoding_at,
            end=encoding_at + b"UTF-8".length(),
            b"ISO-8859-1",
          )
        },
      )
    })
    assert_eq(code, "office.docx.unsupported_encoding")
    assert_false(@afs.exists(output))
    assert_eq(@afs.read_file(input).binary(), original)
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
async test "D1 bounded identifier rejects relationship-dense candidates before portable parsing" {
  with_docx_session_test_dir(directory => {
    let input = "\{directory}/input.docx"
    let output = "\{directory}/output.docx"
    let original = @word_fixture.new_blank_docx()
    write_docx_session_file(input, original)
    let relationships = StringBuilder()
    relationships.write_string(
      "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">",
    )
    for index in 0..<30_000 {
      relationships.write_string(
        "<Relationship Id=\"rId\{index}\" Type=\"urn:office-d1:test\" Target=\"https://example.invalid/\{index}\" TargetMode=\"External\"/>",
      )
    }
    relationships.write_string("</Relationships>")
    let candidate_part = @utf8.encode(relationships.to_string())
    assert_true(candidate_part.length() < 8 * 1024 * 1024)
    let callback_finished = Ref(false)
    let code = docx_session_error_code(() => {
      @docx.transact_docx(
        @transaction.transaction_options(input, output_path=output),
        session => {
          session.queue_added_part(
            "word/_rels/hostile.xml.rels", candidate_part,
          )
          callback_finished.val = true
        },
      )
    })
    assert_true(callback_finished.val)
    assert_eq(code, "office.docx.resource_limit")
    assert_false(@afs.exists(output))
    assert_eq(@afs.read_file(input).binary(), original)
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
async test "D1 generic plans cannot introduce a second comments target" {
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
    guard archive.get("word/_rels/document.xml.rels") is Some(rels) else {
      fail("fixture is missing main relationships")
    }
    guard rels.find(b"</Relationships>") is Some(rels_insert) else {
      fail("fixture main relationships have no closing tag")
    }
    guard archive.get("[Content_Types].xml") is Some(types) else {
      fail("fixture is missing content types")
    }
    guard types.find(b"</Types>") is Some(types_insert) else {
      fail("fixture content types have no closing tag")
    }
    write_docx_session_file(input, original)
    let code = docx_session_error_code(() => {
      @docx.transact_docx(
        @transaction.transaction_options(input, output_path=output),
        session => {
          session.queue_span_edit(
            "word/_rels/document.xml.rels",
            start=rels_insert,
            end=rels_insert,
            @utf8.encode(
              (
                #|<Relationship Id="rIdSecondaryComments" Type="http://purl.oclc.org/ooxml/officeDocument/relationships/comments" Target="comments-secondary.xml"/>
              ),
            ),
          )
          session.queue_span_edit(
            "[Content_Types].xml",
            start=types_insert,
            end=types_insert,
            @utf8.encode(
              (
                #|<Override PartName="/word/comments-secondary.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.comments+xml"/>
              ),
            ),
          )
          session.queue_added_part(
            "word/comments-secondary.xml",
            @utf8.encode(
              (
                #|<w:comments xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:comment w:id="1" w:author="Mallory"><w:p/></w:comment></w:comments>
              ),
            ),
          )
        },
      )
    })
    assert_eq(code, "office.transaction.validation_failed")
    assert_false(@afs.exists(output))
    assert_eq(@afs.read_file(input).binary(), original)
  })
}

///|
async test "D1 generic plans cannot publish dangling markers in unreferenced stories" {
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
    guard archive.get("word/_rels/document.xml.rels") is Some(rels_bytes) else {
      fail("fixture is missing main relationships")
    }
    let rels = @utf8.decode(rels_bytes, ignore_bom=true).replace(
      old="</Relationships>",
      new=(
        #|<Relationship Id="rIdHiddenHeader" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/header" Target="hidden-header.xml"/></Relationships>
      ),
    )
    assert_true(
      archive.replace("word/_rels/document.xml.rels", @utf8.encode(rels)),
    )
    guard archive.get("[Content_Types].xml") is Some(types_bytes) else {
      fail("fixture is missing content types")
    }
    let types = @utf8.decode(types_bytes, ignore_bom=true).replace(
      old="</Types>",
      new=(
        #|<Override PartName="/word/hidden-header.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.header+xml"/></Types>
      ),
    )
    assert_true(archive.replace("[Content_Types].xml", @utf8.encode(types)))
    archive.add(
      "word/hidden-header.xml",
      @utf8.encode(
        (
          #|<w:hdr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:p><w:r><w:commentReference w:id="1"/></w:r></w:p></w:hdr>
        ),
      ),
    )
    guard archive.get("word/document.xml") is Some(document) else {
      fail("fixture is missing its main document")
    }
    guard document.find(b"Claim") is Some(text_at) else {
      fail("fixture is missing body text")
    }
    let source = @zip.write(archive)
    write_docx_session_file(input, source)
    let code = docx_session_error_code(() => {
      @docx.transact_docx(
        @transaction.transaction_options(input, output_path=output),
        session => {
          session.queue_span_edit(
            "word/document.xml",
            start=text_at,
            end=text_at + 5,
            b"Proof",
          )
        },
      )
    })
    assert_eq(code, "office.transaction.validation_failed")
    assert_false(@afs.exists(output))
    assert_eq(@afs.read_file(input).binary(), source)
  })
}

///|
async test "D1 generic plans cannot publish duplicate global paraIds" {
  with_docx_session_test_dir(directory => {
    let input = "\{directory}/input.docx"
    let output = "\{directory}/output.docx"
    let original = @word_fixture.write_docx([
      @word_fixture.paragraph([@word_fixture.run([@word_fixture.text("First")])]),
      @word_fixture.paragraph([
        @word_fixture.run([@word_fixture.text("Second")]),
      ]),
    ])
    let archive = @zip.read(original)
    guard archive.get("word/document.xml") is Some(document_bytes) else {
      fail("fixture is missing its main document")
    }
    let document = @utf8.decode(document_bytes, ignore_bom=true)
    let namespaced = if document.contains(
        "xmlns:w14=\"http://schemas.microsoft.com/office/word/2010/wordml\"",
      ) {
      document
    } else {
      document.replace(
        old="<w:document ",
        new="<w:document xmlns:w14=\"http://schemas.microsoft.com/office/word/2010/wordml\" ",
      )
    }
    let duplicated = namespaced.replace_all(
      old="<w:p>",
      new="<w:p w14:paraId=\"DEADBEEF\">",
    )
    assert_eq(duplicated.split("w14:paraId").length(), 3)
    write_docx_session_file(input, original)
    let code = docx_session_error_code(() => {
      @docx.transact_docx(
        @transaction.transaction_options(input, output_path=output),
        session => {
          session.queue_span_edit(
            "word/document.xml",
            start=0,
            end=document_bytes.length(),
            @utf8.encode(duplicated),
          )
        },
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
    assert_eq(report.validations.length(), 3)
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
    let oversized_valid_name = docx_session_error_code(() => {
      @docx.transact_docx(@transaction.transaction_options(input), session => {
        session.queue_added_part("word/" + "a".repeat(1_024) + ".xml", b"<x/>")
      })
    })
    assert_eq(oversized_valid_name, "office.docx.resource_limit")
    let oversized_invalid_name = docx_session_error_code(() => {
      @docx.transact_docx(@transaction.transaction_options(input), session => {
        session.queue_added_part("/" + "a".repeat(1_024), b"<x/>")
      })
    })
    assert_eq(oversized_invalid_name, "office.docx.resource_limit")
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
    assert_eq(unwired, "office.docx.invalid_package")
    assert_false(@afs.exists(invalid_output))
    assert_eq(@afs.read_file(input).binary(), original)
  })
}
