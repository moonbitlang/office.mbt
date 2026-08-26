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
