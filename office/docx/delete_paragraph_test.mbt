// The delete transaction end to end: resolve, plan, verify by identity
// readback, publish atomically — and nothing written on any refusal.

///|
async fn delete_nothing_written(path : String) -> Unit {
  // Existence, not readability: a read that fails for ANY reason would
  // satisfy a naive absence check, so a zero-length or unreadable leak
  // would read as "nothing written".
  assert_false(
    @afs.exists(path),
    msg="a refused delete must write nothing: " + path,
  )
}

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
    let mut refused_code = ""
    ignore(
      @docx.transact_docx_delete_paragraph(
        @transaction.transaction_options(input, output_path=refused),
        at="p[1]",
        expect_text="omega",
      ),
    ) catch {
      error => refused_code = "\{error}"
    }
    assert_true(refused_code.contains("office.delete.expect_text_mismatch"))
    delete_nothing_written(refused)
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
      index, case in [
        ("p[1]", "final direct body paragraph"),
        ("p[7]", "does not resolve"),
        ("p[id=\"ZZ\"]", "eight hex digits"),
        ("p[id=\"00000009\"]", "no paragraph in the body story"),
      ] {
      let (at, needle) = case
      // Distinct per case: two refusals sharing one path would let a
      // leak from the first hide behind the second's absence.
      let output = directory + "/delref-\{index}.docx"
      let mut refused_code = ""
      ignore(
        @docx.transact_docx_delete_paragraph(
          @transaction.transaction_options(input, output_path=output),
          at~,
        ),
      ) catch {
        error => refused_code = "\{error}"
      }
      assert_true(
        refused_code.contains(needle),
        msg="'\{at}' -> " + refused_code,
      )
      delete_nothing_written(output)
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
    delete_nothing_written(dry)
    let refused = directory + "/delpre-out.docx"
    let mut refused_code = ""
    ignore(
      @docx.transact_docx_delete_paragraph(
        @transaction.transaction_options(input, output_path=refused),
        at="p[1]",
        preflight=report => {
          assert_eq(report.text(), "gone")
          raise @transaction.transaction_failure(
            "office.delete.preflight_probe", "the caller's preflight refuses",
          )
        },
      ),
    ) catch {
      error => refused_code = "\{error}"
    }
    assert_true(refused_code.contains("office.delete.preflight_probe"))
    delete_nothing_written(refused)
  })
}

///|
/// Every typed refusal code, driven through the transaction that emits
/// it. A code nothing asserts is a code a rewording can silently move —
/// and these exist precisely so an agent can tell a retryable address
/// mistake from a permanent structural refusal.
async test "delete-paragraph refusals carry their typed codes" {
  with_docx_session_test_dir(directory => {
    let index_of_probe = Ref(0)
    let table = "<w:tbl><w:tr><w:tc><w:p><w:r><w:t>cell</w:t></w:r></w:p></w:tc></w:tr></w:tbl>"
    for
      probe in [
        // (body runs, target, expected code)
        ("<w:r><w:t>only</w:t></w:r>", "p[1]", "office.delete.final_paragraph"),
        ("<w:r><w:t>a</w:t></w:r>", "p[9]", "office.delete.target_not_found"),
        (
          // A raw nested path is a GRAMMAR problem (the CLI blocks it
          // before the engine sees it)…
          "<w:r><w:t>a</w:t></w:r></w:p>" +
          table +
          "<w:p><w:r><w:t>b</w:t></w:r>",
          "tbl[1]/tr[1]/tc[1]/p[1]",
          "office.delete.target_grammar",
        ),
        (
          // …while a STABLE identity naming that same paragraph is a
          // structural refusal: `office find` just reported it, and it
          // can never be deleted.
          "<w:r><w:t>a</w:t></w:r></w:p><w:tbl><w:tr><w:tc><w:p w14:paraId=\"0000C0DE\"><w:r><w:t>cell</w:t></w:r></w:p></w:tc></w:tr></w:tbl><w:p><w:r><w:t>b</w:t></w:r>",
          "p[id=\"0000C0DE\"]", "office.delete.target_not_direct",
        ),
        (
          "<w:r><w:footnoteReference w:id=\"1\"/></w:r></w:p><w:p><w:r><w:t>b</w:t></w:r>",
          "p[1]", "office.delete.blocked_construct",
        ),
        (
          "<w:r><w:t>a</w:t></w:r></w:p>" +
          table +
          "<w:p/>" +
          table +
          "<w:p><w:r><w:t>b</w:t></w:r>",
          "p[2]",
          "office.delete.table_separator",
        ),
        (
          "<w:r><w:fldChar w:fldCharType=\"begin\"/></w:r></w:p><w:p><w:r><w:t>mid</w:t></w:r></w:p><w:p><w:r><w:fldChar w:fldCharType=\"end\"/></w:r></w:p><w:p><w:r><w:t>b</w:t></w:r>",
          "p[2]", "office.delete.field_region",
        ),
        (
          "<w:r><w:t>a</w:t></w:r></w:p><w:bookmarkStart w:id=\"3\" w:name=\"R\"/><w:p><w:r><w:t>mid</w:t></w:r></w:p><w:bookmarkEnd w:id=\"3\"/><w:p><w:r><w:t>b</w:t></w:r>",
          "p[2]", "office.delete.open_range",
        ),
        (
          "<w:bookmarkStart w:id=\"4\" w:name=\"_GoBack\"/><w:r><w:t>a</w:t></w:r></w:p><w:p><w:r><w:t>b</w:t></w:r>",
          "p[1]", "office.delete.bookmark_unpairable",
        ),
      ] {
      let (runs, at, code) = probe
      // Named by INDEX, never by the expected code: a path carrying the
      // answer makes any error that echoes a path satisfy the oracle.
      index_of_probe.val += 1
      let ordinal = index_of_probe.val
      let input = edit_fixture(directory, "code-\{ordinal}.docx", runs)
      let output = directory + "/code-out-\{ordinal}.docx"
      let mut reported = ""
      ignore(
        @docx.transact_docx_delete_paragraph(
          @transaction.transaction_options(input, output_path=output),
          at~,
        ),
      ) catch {
        error => reported = "\{error}"
      }
      assert_true(
        reported.contains(code),
        msg="'\{at}' expected \{code}, got: " + reported,
      )
      delete_nothing_written(output)
    }
  })
}
