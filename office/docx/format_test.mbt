// The formatting transaction, end to end: preflight, plan, validate
// with three checks, publish atomically — and nothing written on any
// refusal.

///|
/// Run one formatting request against a fixture whose single paragraph
/// carries `runs`, returning (result, failure text, published bytes).
async fn format_probe(
  directory : String,
  name : String,
  runs : String,
  format : @word.DocxDirectFormat,
  text? : String,
  within? : String,
  nth? : Int,
  range? : (Int, Int),
  expect? : Int,
  allow_zero? : Bool = false,
) -> (@docx.DocxFormatResult?, String?, Bytes?) {
  let input = edit_fixture(directory, name + "-in.docx", runs)
  let output = directory + "/" + name + "-out.docx"
  let mut failure : String? = None
  let mut result : @docx.DocxFormatResult? = None
  try {
    result = Some(
      @docx.transact_docx_format(
        @transaction.transaction_options(input, output_path=output),
        format~,
        text?,
        within?,
        nth?,
        range?,
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
/// The happy path: a text-selected span is formatted, published
/// atomically, and the published document carries the property where it
/// was asked for and nowhere else.
async test "format transaction publishes and the output carries the request" {
  with_docx_session_test_dir(directory => {
    let (result, failure, published) = format_probe(
      directory,
      "happy",
      "<w:r><w:t>Hello world</w:t></w:r>",
      @word.docx_direct_format(bold=true),
      text="world",
    )
    assert_true(failure is None, msg="unexpected failure: \{failure}")
    guard result is Some(outcome) else { fail("expected a result") }
    let report = outcome.report()
    assert_eq(report.mode(), "text")
    assert_eq(report.spans().length(), 1)
    assert_eq(report.runs_changed(), 1)
    assert_eq(report.splits(), 1)
    assert_true(outcome.transaction().changed)
    guard published is Some(bytes) else { fail("expected a published output") }
    let reread = @word.read_docx_annotated(bytes)
    // The text is unchanged...
    assert_true(reread.result().document.to_raw_text().contains("Hello world"))
    // ...the selected span carries bold...
    assert_eq(
      @word.docx_paragraph_direct_format(
        reread,
        reread.main_story_source(),
        path=report.affected()[0].path(),
        start=6,
        end=11,
        format=@word.docx_direct_format(bold=true),
      ),
      None,
    )
    // ...and the unselected head does not.
    assert_true(
      @word.docx_paragraph_direct_format(
        reread,
        reread.main_story_source(),
        path=report.affected()[0].path(),
        start=0,
        end=5,
        format=@word.docx_direct_format(bold=true),
      )
      is Some(_),
    )
  })
}

///|
/// An explicit range addresses one paragraph, and the receipt echoes
/// the selector it was given.
async test "format transaction addresses an explicit range" {
  with_docx_session_test_dir(directory => {
    let (result, failure, published) = format_probe(
      directory,
      "ranged",
      "<w:r><w:t>alpha</w:t></w:r>",
      @word.docx_direct_format(italic=true),
      within="p[1]",
      range=(1, 3),
    )
    assert_true(failure is None, msg="unexpected failure: \{failure}")
    guard result is Some(outcome) else { fail("expected a result") }
    let report = outcome.report()
    assert_eq(report.mode(), "range")
    assert_eq(report.requested_range(), Some((1, 3)))
    assert_eq(report.requested_within(), Some("p[1]"))
    assert_eq(report.requested_text(), None)
    guard published is Some(bytes) else { fail("expected a published output") }
    let reread = @word.read_docx_annotated(bytes)
    assert_eq(
      @word.docx_paragraph_direct_format(
        reread,
        reread.main_story_source(),
        path="p[1]",
        start=1,
        end=3,
        format=@word.docx_direct_format(italic=true),
      ),
      None,
    )
  })
}

///|
/// A semantic no-op still runs every check, publishes an unchanged
/// document, and says so: the span was selected, no run was rewritten.
async test "format transaction reports a satisfied request as unchanged" {
  with_docx_session_test_dir(directory => {
    let (result, failure, _) = format_probe(
      directory,
      "noop",
      "<w:r><w:rPr><w:b/><w:bCs/></w:rPr><w:t>Hello world</w:t></w:r>",
      @word.docx_direct_format(bold=true),
      text="world",
    )
    assert_true(failure is None, msg="unexpected failure: \{failure}")
    guard result is Some(outcome) else { fail("expected a result") }
    let report = outcome.report()
    assert_eq(report.spans().length(), 1)
    assert_eq(report.runs_changed(), 0)
    assert_eq(report.runs_already_satisfied(), 1)
    assert_eq(report.byte_edits(), 0)
    assert_false(outcome.transaction().changed)
  })
}

///|
/// The outcome policies: zero refuses unless allowed, `expect` asserts
/// the selected count, and `expect 0` is a satisfiable claim.
async test "format transaction enforces its outcome policies" {
  with_docx_session_test_dir(directory => {
    let (_, zero_failure, zero_published) = format_probe(
      directory,
      "zero",
      "<w:r><w:t>Hello world</w:t></w:r>",
      @word.docx_direct_format(bold=true),
      text="absent",
    )
    guard zero_failure is Some(message) else {
      fail("expected a zero-match refusal")
    }
    assert_true(message.contains("no span was selected"), msg=message)
    assert_true(zero_published is None, msg="nothing may be published")
    let (allowed, allow_failure, _) = format_probe(
      directory,
      "zero-allowed",
      "<w:r><w:t>Hello world</w:t></w:r>",
      @word.docx_direct_format(bold=true),
      text="absent",
      allow_zero=true,
    )
    assert_true(
      allow_failure is None,
      msg="unexpected failure: \{allow_failure}",
    )
    guard allowed is Some(outcome) else { fail("expected a result") }
    assert_false(outcome.transaction().changed)
    let (_, expect_failure, _) = format_probe(
      directory,
      "expect-wrong",
      "<w:r><w:t>ab ab</w:t></w:r>",
      @word.docx_direct_format(bold=true),
      text="ab",
      expect=1,
    )
    guard expect_failure is Some(expect_message) else {
      fail("expected an expect refusal")
    }
    assert_true(expect_message.contains("expected 1 span"), msg=expect_message)
    let (asserted, asserted_failure, _) = format_probe(
      directory,
      "expect-zero",
      "<w:r><w:t>Hello world</w:t></w:r>",
      @word.docx_direct_format(bold=true),
      text="absent",
      expect=0,
    )
    assert_true(
      asserted_failure is None,
      msg="expect 0 must be satisfiable: \{asserted_failure}",
    )
    assert_true(asserted is Some(_))
  })
}

///|
/// A planner refusal aborts the transaction and publishes nothing.
async test "format transaction refuses what the planner refuses" {
  with_docx_session_test_dir(directory => {
    let (_, failure, published) = format_probe(
      directory,
      "atom",
      "<w:r><w:t>a</w:t><w:tab/><w:t>b</w:t></w:r>",
      @word.docx_direct_format(bold=true),
      within="p[1]",
      range=(0, 3),
    )
    guard failure is Some(message) else { fail("expected a refusal") }
    assert_true(message.contains("projected-atom"), msg=message)
    assert_true(published is None, msg="nothing may be published")
  })
}

///|
/// The shared mutation preflight: a document that records revisions is
/// not formatted at all, because the edit would arrive untracked.
async test "format transaction refuses a revision-tracking document" {
  with_docx_session_test_dir(directory => {
    let input = edit_fixture(
      directory, "tracked-in.docx", "<w:r><w:t>Hello world</w:t></w:r>",
    )
    // Rewrite the fixture's settings to record revisions.
    let archive = @zip.read(@afs.read_file(input).binary())
    let rebuilt = @zip.Archive::new()
    let mut settings_seen = false
    for entry in archive.entries() {
      let name = entry.name()
      guard archive.get(name) is Some(payload) else { continue }
      if name == "word/settings.xml" {
        settings_seen = true
        let text = @utf8.decode(payload)
        rebuilt.add(
          name,
          @utf8.encode(
            text.replace(
              old="</w:settings>",
              new="<w:trackRevisions/></w:settings>",
            ),
          ),
        )
      } else {
        rebuilt.add(name, payload.to_owned())
      }
    }
    assert_true(settings_seen, msg="the fixture has no settings part")
    let tracked = directory + "/tracked.docx"
    @afs.write_file(
      tracked,
      @zip.write(rebuilt),
      create_mode=CreateNew,
      permission=0o600,
    )
    let output = directory + "/tracked-out.docx"
    let mut failure : String? = None
    try
      @docx.transact_docx_format(
        @transaction.transaction_options(tracked, output_path=output),
        format=@word.docx_direct_format(bold=true),
        text="world",
      )
      |> ignore
    catch {
      error => failure = Some("\{error}")
    }
    guard failure is Some(message) else {
      fail("expected a tracked-changes refusal")
    }
    assert_true(message.contains("records revisions"), msg=message)
  })
}
