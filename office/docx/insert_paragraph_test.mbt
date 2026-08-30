// The insert transaction end to end: mint, splice, verify by readback,
// publish atomically — and nothing written on any refusal.

///|
/// The happy path: insert after a stamped paragraph; the published
/// document re-reads with the minted identity at the reported path,
/// addressable through the stable selector chain, and the delta
/// identity gate accepts the fresh id.
async test "insert-paragraph publishes a minted addressable paragraph" {
  with_docx_session_test_dir(directory => {
    let input = edit_fixture(
      directory, "ins-in.docx", "<w:r><w:t>first</w:t></w:r></w:p><w:p w14:paraId=\"00000001\"><w:r><w:t>second</w:t></w:r>",
    )
    let output = directory + "/ins-out.docx"
    let result = @docx.transact_docx_insert_paragraph(
      @transaction.transaction_options(input, output_path=output),
      at="p[2]",
      before=false,
      content={
        style: None,
        runs: [
          { text: "minted ", bold: false, italic: false, underline: false, },
          { text: "body", bold: true, italic: false, underline: false, },
        ],
      },
    )
    assert_eq(result.report().path(), "p[3]")
    let minted = result.report().para_id()
    assert_eq(@word.validated_para_id(minted), Some(minted))
    assert_true(minted != "00000001")
    assert_true(result.transaction().changed)
    let published = @afs.read_file(output).binary()
    let reread = @word.read_docx_annotated(published)
    assert_true(reread.result().document.to_raw_text().contains("minted body"))
    let anchors = @word.docx_paragraph_anchor_index(
      reread,
      reread.main_story_source(),
    )
    guard anchors.anchor_at("p[3]") is Some(anchor) else {
      fail("expected the inserted anchor")
    }
    assert_eq(anchor.status(), "unique")
    assert_eq(anchor.para_id(), Some(minted))
  })
}

///|
/// Refusals publish nothing: an undefined style, a nested anchor, and
/// an absent anchor each refuse typed with no output file.
async test "insert-paragraph refusals publish nothing" {
  with_docx_session_test_dir(directory => {
    let input = edit_fixture(
      directory, "insref-in.docx", "<w:r><w:t>only</w:t></w:r>",
    )
    for
      case in [
        ("p[1]", Some("Ghost"), "styles part does not define"),
        ("p[7]", None, "does not resolve"),
        ("tbl[1]/tr[1]/tc[1]/p[1]", None, "direct body"),
      ] {
      let (at, style, needle) = case
      let output = directory + "/insref-out.docx"
      let mut failure : String? = None
      ignore(
        @docx.transact_docx_insert_paragraph(
          @transaction.transaction_options(input, output_path=output),
          at~,
          before=true,
          content={
            style,
            runs: [{ text: "x", bold: false, italic: false, underline: false, }],
          },
        ),
      ) catch {
        error => failure = Some("\{error}")
      }
      guard failure is Some(message) else {
        fail("expected a refusal for \{at}")
      }
      assert_true(message.contains(needle), msg="got '" + message + "'")
      let mut published = false
      try {
        ignore(@afs.read_file(output))
        published = true
      } catch {
        _ => ()
      }
      assert_false(published, msg="a refused insert must write nothing")
    }
  })
}
