// The delete transaction end to end: resolve, plan, verify by identity
// readback, publish atomically — and nothing written on any refusal.

///|
/// The happy path by stable identity: the published document re-reads
/// without the deleted identity, the successor answers at the path,
/// and the story is one paragraph shorter.
async test "delete-paragraph publishes without the deleted identity" {
  with_docx_session_test_dir(directory => {
    let input = edit_fixture(
      directory, "del-in.docx", "<w:r><w:t>first</w:t></w:r></w:p><w:p w14:paraId=\"00000001\"><w:r><w:t>second</w:t></w:r></w:p><w:p w14:paraId=\"00000002\"><w:r><w:t>third</w:t></w:r>",
    )
    let output = directory + "/del-out.docx"
    let result = @docx.transact_docx_delete_paragraph(
      @transaction.transaction_options(input, output_path=output),
      at="p[id=\"00000001\"]",
    )
    assert_eq(result.report().path(), "p[2]")
    assert_eq(result.report().para_id(), Some("00000001"))
    assert_eq(result.report().text(), "second")
    assert_eq(result.report().successor_para_id(), Some("00000002"))
    assert_true(result.transaction().changed)
    let published = @afs.read_file(output).binary()
    let reread = @word.read_docx_annotated(published)
    let text = reread.result().document.to_raw_text()
    assert_true(!text.contains("second"))
    assert_true(text.contains("first") && text.contains("third"))
    let anchors = @word.docx_paragraph_anchor_index(
      reread,
      reread.main_story_source(),
    )
    assert_eq(anchors.paragraphs_with_para_id("00000001"), [])
    guard anchors.anchor_at("p[2]") is Some(anchor) else {
      fail("expected the successor at the deleted path")
    }
    assert_eq(anchor.para_id(), Some("00000002"))
    assert_true(anchors.anchor_at("p[3]") is None)
  })
}

///|
/// `expect_text` is the ordinal guard: a mismatch refuses with nothing
/// written; the match deletes.
async test "delete-paragraph expect_text guards ordinal addressing" {
  with_docx_session_test_dir(directory => {
    let input = edit_fixture(
      directory, "delex-in.docx", "<w:r><w:t>alpha</w:t></w:r></w:p><w:p><w:r><w:t>omega</w:t></w:r>",
    )
    let refused = directory + "/delex-refused.docx"
    let outcome = try? @docx.transact_docx_delete_paragraph(
      @transaction.transaction_options(input, output_path=refused),
      at="p[1]",
      expect_text="omega",
    )
    guard outcome is Err(error) else {
      fail("expected the expect_text refusal")
    }
    assert_true("\{error}".contains("office.delete.expect_text_mismatch"))
    assert_true((try? @afs.read_file(refused)) is Err(_))
    let output = directory + "/delex-out.docx"
    let result = @docx.transact_docx_delete_paragraph(
      @transaction.transaction_options(input, output_path=output),
      at="p[1]",
      expect_text="alpha",
    )
    assert_eq(result.report().text(), "alpha")
  })
}

///|
/// Refusals publish nothing: the final direct body paragraph, an
/// unresolvable path, a bad stable spelling — each typed, no output.
async test "delete-paragraph refusals publish nothing" {
  with_docx_session_test_dir(directory => {
    let input = edit_fixture(
      directory, "delref-in.docx", "<w:r><w:t>only</w:t></w:r>",
    )
    for
      case in [
        ("p[1]", "final direct body paragraph"),
        ("p[7]", "does not resolve"),
        ("p[id=\"ZZ\"]", "eight hex digits"),
        ("p[id=\"00000009\"]", "no paragraph in the body story"),
      ] {
      let (at, needle) = case
      let output = directory + "/delref-\{at.length()}.docx"
      let outcome = try? @docx.transact_docx_delete_paragraph(
        @transaction.transaction_options(input, output_path=output),
        at~,
      )
      guard outcome is Err(error) else {
        fail("expected a refusal for '\{at}'")
      }
      assert_true("\{error}".contains(needle), msg="'\{at}' -> \{error}")
      assert_true((try? @afs.read_file(output)) is Err(_))
    }
  })
}

///|
/// A dry run exercises the identical pipeline and writes nothing; a
/// raising preflight refuses with nothing written.
async test "delete-paragraph dry run and preflight write nothing" {
  with_docx_session_test_dir(directory => {
    let input = edit_fixture(
      directory, "deldry-in.docx", "<w:r><w:t>gone</w:t></w:r></w:p><w:p><w:r><w:t>stays</w:t></w:r>",
    )
    let dry = directory + "/deldry-out.docx"
    let result = @docx.transact_docx_delete_paragraph(
      @transaction.transaction_options(input, output_path=dry, dry_run=true),
      at="p[1]",
    )
    assert_eq(result.report().text(), "gone")
    assert_true((try? @afs.read_file(dry)) is Err(_))
    let refused = directory + "/delpre-out.docx"
    let outcome = try? @docx.transact_docx_delete_paragraph(
      @transaction.transaction_options(input, output_path=refused),
      at="p[1]",
      preflight=report => {
        assert_eq(report.text(), "gone")
        raise @transaction.transaction_failure(
          "office.delete.preflight_probe", "the caller's preflight refuses",
        )
      },
    )
    guard outcome is Err(error) else { fail("expected the preflight refusal") }
    assert_true("\{error}".contains("office.delete.preflight_probe"))
    assert_true((try? @afs.read_file(refused)) is Err(_))
  })
}
