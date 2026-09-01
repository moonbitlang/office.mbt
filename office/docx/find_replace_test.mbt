// The replace transaction, end to end: plan, validate, readback,
// publish atomically — and nothing written on any refusal.

///|
/// Run one replace against a fixture whose single paragraph carries
/// `runs`, returning (failure text, published output bytes).
async fn replace_probe(
  directory : String,
  name : String,
  runs : String,
  needle : String,
  replacement : String,
  nth? : Int,
  expect? : Int,
  allow_zero? : Bool = false,
) -> (@docx.DocxFindReplaceResult?, String?, Bytes?) {
  let input = edit_fixture(directory, name + "-in.docx", runs)
  let output = directory + "/" + name + "-out.docx"
  let mut failure : String? = None
  let mut result : @docx.DocxFindReplaceResult? = None
  try {
    result = Some(
      @docx.transact_docx_find_replace(
        @transaction.transaction_options(input, output_path=output),
        needle~,
        replacement~,
        nth?,
        expect?,
        allow_zero~,
      ),
    )
  } catch {
    error => failure = Some("\{error}")
  }
  let mut bytes : Bytes? = None
  try {
    let file = @afs.read_file(output)
    bytes = Some(file.binary())
  } catch {
    _ => ()
  }
  (result, failure, bytes)
}

///|
/// The happy path: replace across runs, published atomically, and the
/// published document re-reads with the expected text.
async test "replace transaction publishes and the output re-reads" {
  with_docx_session_test_dir(directory => {
    let (result, failure, published) = replace_probe(
      directory, "happy", "<w:r><w:t>Hel</w:t></w:r><w:r><w:t>lo world</w:t></w:r>",
      "lo wo", "p wo",
    )
    assert_true(failure is None, msg="unexpected failure")
    guard result is Some(outcome) else { fail("expected a result") }
    assert_eq(outcome.report().replaced(), 1)
    assert_true(outcome.transaction().changed)
    guard published is Some(bytes) else { fail("expected a published output") }
    let reread = @word.read_docx_annotated(bytes)
    assert_true(reread.result().document.to_raw_text().contains("Help world"))
  })
}

///|
/// Zero matches without allow-zero refuses and writes NOTHING; with
/// allow-zero the same call succeeds and changes nothing.
async test "replace refuses zero matches and publishes nothing" {
  with_docx_session_test_dir(directory => {
    let (result, failure, published) = replace_probe(
      directory, "zero", "<w:r><w:t>alpha</w:t></w:r>", "absent", "x",
    )
    assert_true(result is None)
    guard failure is Some(message) else {
      fail("expected the no-match refusal")
    }
    assert_true(
      message.contains("office.replace.no_match"),
      msg="got '" + message + "'",
    )
    assert_true(published is None, msg="a refused replace must write nothing")
    let (ok, none, out) = replace_probe(
      directory,
      "zero-ok",
      "<w:r><w:t>alpha</w:t></w:r>",
      "absent",
      "x",
      allow_zero=true,
    )
    assert_true(none is None, msg="allow-zero failed")
    guard ok is Some(outcome) else { fail("expected a result") }
    assert_false(outcome.transaction().changed)
    assert_true(out is Some(_))
  })
}

///|
/// `expect` asserts the selected count; a mismatch refuses and writes
/// nothing, and the matching expectation goes through.
async test "replace expect mismatch refuses before publication" {
  with_docx_session_test_dir(directory => {
    let (result, failure, published) = replace_probe(
      directory,
      "expect",
      "<w:r><w:t>aa and aa</w:t></w:r>",
      "aa",
      "b",
      expect=3,
    )
    assert_true(result is None)
    guard failure is Some(message) else { fail("expected the expect refusal") }
    assert_true(
      message.contains("office.replace.expect_mismatch"),
      msg="got '" + message + "'",
    )
    assert_true(published is None)
    let (ok, none, _) = replace_probe(
      directory,
      "expect-ok",
      "<w:r><w:t>aa and aa</w:t></w:r>",
      "aa",
      "b",
      expect=2,
    )
    assert_true(none is None, msg="expect=2 failed")
    assert_true(ok is Some(_))
  })
}

///|
/// A restricted candidate in scope refuses the WHOLE transaction and
/// writes nothing; `nth` at the editable candidate still goes through,
/// and the field's cached result survives untouched.
async test "replace with a restricted candidate publishes nothing" {
  with_docx_session_test_dir(directory => {
    let runs =
      #|<w:r><w:t>seven</w:t></w:r></w:p><w:p><w:r><w:fldChar w:fldCharType="begin"/></w:r><w:r><w:fldChar w:fldCharType="separate"/></w:r><w:r><w:t>seven</w:t></w:r><w:r><w:fldChar w:fldCharType="end"/></w:r>
    let (result, failure, published) = replace_probe(
      directory, "restricted", runs, "seven", "eight",
    )
    assert_true(result is None)
    guard failure is Some(message) else { fail("expected the refusal") }
    assert_true(message.contains("field-region"), msg="got '" + message + "'")
    assert_true(published is None)
    let (ok, none, out) = replace_probe(
      directory,
      "restricted-nth",
      runs,
      "seven",
      "eight",
      nth=1,
    )
    assert_true(none is None, msg="nth=1 failed")
    assert_true(ok is Some(_))
    guard out is Some(bytes) else { fail("expected output") }
    let text = @word.read_docx_annotated(bytes).result().document.to_raw_text()
    assert_true(text.contains("eight"))
    // The field's cached result is untouched.
    assert_true(text.contains("seven"))
  })
}

///|
/// `--expect 0` is a satisfiable assertion: zero matches SUCCEEDS under
/// it, publishing an unchanged output. The first version checked the
/// generic zero-refusal first, which made the advertised `--expect 0`
/// impossible to ever pass.
async test "replace expect zero holds on zero matches" {
  with_docx_session_test_dir(directory => {
    let (ok, failure, out) = replace_probe(
      directory,
      "expect-zero",
      "<w:r><w:t>alpha</w:t></w:r>",
      "absent",
      "x",
      expect=0,
    )
    assert_true(failure is None, msg="expect 0 refused on zero matches")
    guard ok is Some(outcome) else { fail("expected a result") }
    assert_eq(outcome.report().replaced(), 0)
    assert_false(outcome.transaction().changed)
    assert_true(out is Some(_))
    // And a nonzero count still fails the assertion.
    let (none, refusal, _) = replace_probe(
      directory,
      "expect-zero-miss",
      "<w:r><w:t>alpha</w:t></w:r>",
      "alpha",
      "x",
      expect=0,
    )
    assert_true(none is None)
    guard refusal is Some(message) else { fail("expected the mismatch") }
    assert_true(message.contains("office.replace.expect_mismatch"))
  })
}

///|
/// Replacing text with itself selects a candidate and changes no bytes,
/// and the CHANGED signal must say so: it comes from the transaction,
/// which watched the bytes, not from the selected count.
async test "replace identity selects but does not change" {
  with_docx_session_test_dir(directory => {
    let (ok, failure, _) = replace_probe(
      directory, "identity", "<w:r><w:t>alpha</w:t></w:r>", "alpha", "alpha",
    )
    assert_true(failure is None, msg="identity replacement refused")
    guard ok is Some(outcome) else { fail("expected a result") }
    assert_eq(outcome.report().replaced(), 1)
    assert_false(outcome.transaction().changed)
  })
}

///|
/// A raising preflight aborts the transaction BEFORE publication: the
/// caller sees its own failure, sees the report it refused over, and no
/// output file exists. This is the hook the CLI budgets its JSON report
/// through.
async test "replace preflight refusal publishes nothing" {
  with_docx_session_test_dir(directory => {
    let input = edit_fixture(
      directory, "preflight-in.docx", "<w:r><w:t>alpha</w:t></w:r>",
    )
    let output = directory + "/preflight-out.docx"
    let seen : Ref[Int?] = Ref(None)
    let mut failure : String? = None
    ignore(
      @docx.transact_docx_find_replace(
        @transaction.transaction_options(input, output_path=output),
        needle="alpha",
        replacement="beta",
        preflight=report => {
          seen.val = Some(report.replaced())
          raise @transaction.transaction_failure(
            "office.replace.report_too_large", "refused by the trial preflight",
          )
        },
      ),
    ) catch {
      error => failure = Some("\{error}")
    }
    assert_eq(seen.val, Some(1))
    guard failure is Some(message) else { fail("expected the refusal") }
    assert_true(
      message.contains("office.replace.report_too_large"),
      msg="got '" + message + "'",
    )
    let mut published = false
    try {
      ignore(@afs.read_file(output))
      published = true
    } catch {
      _ => ()
    }
    assert_false(published, msg="a refused preflight must write nothing")
  })
}

///|
/// Existing paraId dirt SURVIVES a text edit: Word's uniqueness rule is
/// part-scoped and real documents carry duplicates, so the candidate
/// gate compares the identity INVENTORY against the source instead of
/// refusing dirt outright. The edit publishes; the duplicate ids
/// survive byte-identical.
async test "replace preserves and tolerates duplicate paraIds" {
  with_docx_session_test_dir(directory => {
    let runs =
      #|<w:r><w:t>alpha</w:t></w:r></w:p><w:p w14:paraId="1A2B3C4D"><w:r><w:t>alpha</w:t></w:r>
    let (ok, failure, out) = replace_probe(
      directory,
      "dirty",
      "<w:r><w:t>alpha</w:t></w:r></w:p><w:p w14:paraId=\"1A2B3C4D\"><w:r><w:t>beta</w:t></w:r></w:p><w:p w14:paraId=\"1A2B3C4D\">" +
      runs,
      "alpha",
      "gamma",
      nth=1,
    )
    assert_true(
      failure is None,
      msg="dirty-package replace refused: " + failure.unwrap_or(""),
    )
    assert_true(ok is Some(_))
    guard out is Some(bytes) else { fail("expected a published output") }
    let text = @word.read_docx_annotated(bytes).result().document.to_raw_text()
    assert_true(text.contains("gamma"))
  })
}

///|
/// paraId R2b: a stable scope drives the replace transaction — the
/// report names the ordinal path it resolved to, and an ambiguous id
/// refuses the transaction before anything is planned.
async test "replace resolves a stable scope and reports both spellings" {
  with_docx_session_test_dir(directory => {
    let runs =
      #|<w:r><w:t>alpha</w:t></w:r></w:p><w:p w14:paraId="5C5C5C5C"><w:r><w:t>alpha beta</w:t></w:r>
    let input = edit_fixture(directory, "stable-in.docx", runs)
    let output = directory + "/stable-out.docx"
    let result = @docx.transact_docx_find_replace(
      @transaction.transaction_options(input, output_path=output),
      needle="alpha",
      replacement="gamma",
      within="p[id=\"5C5C5C5C\"]",
    )
    assert_eq(result.report().replaced(), 1)
    assert_eq(result.report().resolved_within(), Some("p[2]"))
    let text = @word.read_docx_annotated(@afs.read_file(output).binary()).result().document.to_raw_text()
    // Only the scoped paragraph changed; the first alpha survives.
    assert_true(text.contains("alpha"))
    assert_true(text.contains("gamma beta"))
  })
}

///|
/// Round 1's near-miss, pinned: a scope that BEGINS like a stable
/// spelling but is malformed refuses typed — it must never fall
/// through to the prefix matcher where zero matches plus --expect 0
/// would publish an output.
async test "replace near-miss stable scope refuses instead of matching nothing" {
  with_docx_session_test_dir(directory => {
    let input = edit_fixture(
      directory, "nearmiss-in.docx", "<w:r><w:t>alpha</w:t></w:r>",
    )
    let output = directory + "/nearmiss-out.docx"
    let mut failure : String? = None
    ignore(
      @docx.transact_docx_find_replace(
        @transaction.transaction_options(input, output_path=output),
        needle="alpha",
        replacement="x",
        within="p[id =\"1A2B3C4D\"]",
        expect=0,
      ),
    ) catch {
      error => failure = Some("\{error}")
    }
    guard failure is Some(message) else { fail("expected the refusal") }
    assert_true(
      message.contains("office.docx.para_id_invalid"),
      msg="got '" + message + "'",
    )
    let mut published = false
    try {
      ignore(@afs.read_file(output))
      published = true
    } catch {
      _ => ()
    }
    assert_false(published, msg="a near-miss scope must publish nothing")
  })
}

///|
/// Round 2's edge, pinned: `p[id="]` is seven units whose single quote
/// satisfies both the prefix and the suffix — it must refuse typed,
/// never panic in the slice.
async test "replace seven-unit stable scope refuses typed" {
  with_docx_session_test_dir(directory => {
    let input = edit_fixture(
      directory, "seven-in.docx", "<w:r><w:t>alpha</w:t></w:r>",
    )
    let output = directory + "/seven-out.docx"
    let mut failure : String? = None
    ignore(
      @docx.transact_docx_find_replace(
        @transaction.transaction_options(input, output_path=output),
        needle="alpha",
        replacement="x",
        within="p[id=\"]",
      ),
    ) catch {
      error => failure = Some("\{error}")
    }
    guard failure is Some(message) else { fail("expected the refusal") }
    assert_true(
      message.contains("office.docx.para_id_invalid"),
      msg="got '" + message + "'",
    )
  })
}

///|
/// The validator's capture is its OWN: a caller preflight that mutates
/// what the report hands out must not reach the readback's evidence.
async test "replace preflight cannot sabotage the readback capture" {
  @async.with_task_group() <| group => {
    let directory = @afs.tmpdir(prefix="office-docx-replace-sabotage-")
    group.add_defer() <| () => {
      @async.protect_from_cancel(() => @afs.rmdir(directory, recursive=true))
    }
    let input = edit_fixture(
      directory, "sabotage.docx", "<w:r><w:t>Hello world</w:t></w:r>",
    )
    let output = directory + "/sabotage-out.docx"
    let result = @docx.transact_docx_find_replace(
      @transaction.transaction_options(input, output_path=output),
      needle="world",
      replacement="there",
      preflight=report => {
        // Emptying every array the report exposes must change nothing
        // about what the readback compares.
        report.affected().clear()
        report.matches().clear()
        report.selected().clear()
        report.affected_paths().clear()
      },
    )
    assert_eq(result.report.replaced(), 1)
    assert_eq(result.report.affected().length(), 1)
    let published = @zip.read(@afs.read_file(output).binary())
    guard published.get("word/document.xml") is Some(payload) else {
      fail("no document part")
    }
    assert_true(@utf8.decode(payload).contains("Hello there"))
  }
}
