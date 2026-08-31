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
  dry_run? : Bool = false,
  preflight? : (@docx.DocxFormatReport) -> Unit raise,
) -> (@docx.DocxFormatResult?, String?, Bytes?) {
  let input = edit_fixture(directory, name + "-in.docx", runs)
  let output = directory + "/" + name + "-out.docx"
  let mut failure : String? = None
  let mut result : @docx.DocxFormatResult? = None
  try {
    result = Some(
      @docx.transact_docx_format(
        @transaction.transaction_options(input, output_path=output, dry_run~),
        format~,
        text?,
        within?,
        nth?,
        range?,
        expect?,
        allow_zero~,
        preflight?,
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

///|
/// Build a fixture archive whose settings part carries `settings_body`
/// inserted before `</w:settings>`, and whose extra entries are added
/// verbatim.
async fn preflight_fixture(
  directory : String,
  name : String,
  settings_body : String,
  extra : Array[(String, String)],
  content_types_insert? : String,
) -> String {
  let source = edit_fixture(
    directory,
    name + "-source.docx",
    "<w:r><w:t>Hello world</w:t></w:r>",
  )
  let archive = @zip.read(@afs.read_file(source).binary())
  let rebuilt = @zip.Archive::new()
  for entry in archive.entries() {
    let entry_name = entry.name()
    guard archive.get(entry_name) is Some(payload) else { continue }
    if entry_name == "word/settings.xml" && settings_body != "" {
      let text = @utf8.decode(payload)
      rebuilt.add(
        entry_name,
        @utf8.encode(
          text.replace(old="</w:settings>", new=settings_body + "</w:settings>"),
        ),
      )
    } else if entry_name == "[Content_Types].xml" &&
      content_types_insert is Some(insert) {
      let text = @utf8.decode(payload)
      rebuilt.add(
        entry_name,
        @utf8.encode(text.replace(old="</Types>", new=insert + "</Types>")),
      )
    } else {
      rebuilt.add(entry_name, payload.to_owned())
    }
  }
  for pair in extra {
    rebuilt.add(pair.0, @utf8.encode(pair.1))
  }
  let path = directory + "/" + name + ".docx"
  @afs.write_file(
    path,
    @zip.write(rebuilt),
    create_mode=CreateNew,
    permission=0o600,
  )
  path
}

///|
/// Run a format request against an arbitrary input path.
async fn format_input_probe(input : String, output : String) -> (String?, Bool) {
  let mut failure : String? = None
  try
    @docx.transact_docx_format(
      @transaction.transaction_options(input, output_path=output),
      format=@word.docx_direct_format(bold=true),
      text="world",
    )
    |> ignore
  catch {
    error => failure = Some("\{error}")
  }
  let mut published = false
  try {
    @afs.read_file(output) |> ignore
    published = true
  } catch {
    _ => ()
  }
  (failure, published)
}

///|
/// The preflight's three conditions, each judged on what the package
/// actually declares rather than on where things happen to sit.
async test "the mutation preflight judges declarations, not paths" {
  with_docx_session_test_dir(directory => {
    // A signature part, declared by CONTENT TYPE under a custom name:
    // a path-prefix check would miss it.
    let signed = preflight_fixture(
      directory,
      "signed",
      "",
      [("custom/sig1.xml", "<Signature/>")],
      content_types_insert="<Override PartName=\"/custom/sig1.xml\" ContentType=\"application/vnd.openxmlformats-package.digital-signature-xmlsignature+xml\"/>",
    )
    let (signed_failure, signed_published) = format_input_probe(
      signed,
      directory + "/signed-out.docx",
    )
    guard signed_failure is Some(signed_message) else {
      fail("expected a signed-package refusal")
    }
    assert_true(
      signed_message.contains("digital signature"),
      msg=signed_message,
    )
    assert_false(signed_published, msg="nothing may be published")
    // An ORIGIN part alone is scaffolding, not a signature.
    let origin = preflight_fixture(
      directory,
      "origin",
      "",
      [("_xmlsignatures/origin.sigs", "")],
      content_types_insert="<Override PartName=\"/_xmlsignatures/origin.sigs\" ContentType=\"application/vnd.openxmlformats-package.digital-signature-origin\"/>",
    )
    let (origin_failure, origin_published) = format_input_probe(
      origin,
      directory + "/origin-out.docx",
    )
    assert_true(
      origin_failure is None,
      msg="an origin part is not a signature: \{origin_failure}",
    )
    assert_true(origin_published, msg="an unsigned package publishes")
    // Protection that is DECLARED but not enforced is a preference.
    let unenforced = preflight_fixture(
      directory,
      "unenforced",
      "<w:documentProtection w:edit=\"readOnly\" w:enforcement=\"0\"/>",
      [],
    )
    let (unenforced_failure, _) = format_input_probe(
      unenforced,
      directory + "/unenforced-out.docx",
    )
    assert_true(
      unenforced_failure is None,
      msg="unenforced protection must not block: \{unenforced_failure}",
    )
    // Enforced protection refuses.
    let enforced = preflight_fixture(
      directory,
      "enforced",
      "<w:documentProtection w:edit=\"readOnly\" w:enforcement=\"1\"/>",
      [],
    )
    let (enforced_failure, enforced_published) = format_input_probe(
      enforced,
      directory + "/enforced-out.docx",
    )
    guard enforced_failure is Some(enforced_message) else {
      fail("expected a protection refusal")
    }
    assert_true(
      enforced_message.contains("editing protection"),
      msg=enforced_message,
    )
    assert_false(enforced_published, msg="nothing may be published")
    // `trackRevisions` turned OFF is not tracking.
    let untracked = preflight_fixture(
      directory,
      "untracked",
      "<w:trackRevisions w:val=\"false\"/>",
      [],
    )
    let (untracked_failure, _) = format_input_probe(
      untracked,
      directory + "/untracked-out.docx",
    )
    assert_true(
      untracked_failure is None,
      msg="trackRevisions=false must not block: \{untracked_failure}",
    )
    // An entity-spelled ON is still on.
    let entity = preflight_fixture(
      directory,
      "entity",
      "<w:trackRevisions w:val=\"&#116;rue\"/>",
      [],
    )
    let (entity_failure, _) = format_input_probe(
      entity,
      directory + "/entity-out.docx",
    )
    guard entity_failure is Some(entity_message) else {
      fail("expected an entity-spelled tracking refusal")
    }
    assert_true(
      entity_message.contains("records revisions"),
      msg=entity_message,
    )
    // A FOREIGN element of the same local name is not this setting.
    let foreign = preflight_fixture(
      directory,
      "foreign",
      "<x:trackRevisions xmlns:x=\"urn:example:x\"/>",
      [],
    )
    let (foreign_failure, _) = format_input_probe(
      foreign,
      directory + "/foreign-out.docx",
    )
    assert_true(
      foreign_failure is None,
      msg="a foreign trackRevisions must not block: \{foreign_failure}",
    )
    // And one inside a COMMENT is not an element at all.
    let commented = preflight_fixture(
      directory,
      "commented",
      "<!-- <w:trackRevisions/> -->",
      [],
    )
    let (commented_failure, _) = format_input_probe(
      commented,
      directory + "/commented-out.docx",
    )
    assert_true(
      commented_failure is None,
      msg="a commented setting must not block: \{commented_failure}",
    )
    // Contradictory duplicates refuse rather than pick a winner.
    let ambiguous = preflight_fixture(
      directory,
      "ambiguous",
      "<w:trackRevisions w:val=\"false\"/><w:trackRevisions/>",
      [],
    )
    let (ambiguous_failure, _) = format_input_probe(
      ambiguous,
      directory + "/ambiguous-out.docx",
    )
    guard ambiguous_failure is Some(ambiguous_message) else {
      fail("expected an ambiguity refusal")
    }
    assert_true(
      ambiguous_message.contains("more than once"),
      msg=ambiguous_message,
    )
  })
}

///|
/// The preflight guards EVERY mutating verb, not only formatting.
async test "the mutation preflight guards the shared path" {
  with_docx_session_test_dir(directory => {
    let tracked = preflight_fixture(
      directory,
      "shared",
      "<w:trackRevisions/>",
      [],
    )
    let mut failure : String? = None
    try
      @docx.transact_docx_find_replace(
        @transaction.transaction_options(
          tracked,
          output_path=directory + "/shared-out.docx",
        ),
        needle="world",
        replacement="there",
      )
      |> ignore
    catch {
      error => failure = Some("\{error}")
    }
    guard failure is Some(message) else {
      fail("replace must reach the shared preflight")
    }
    assert_true(message.contains("records revisions"), msg=message)
  })
}

///|
/// Two paragraphs, one request: the report groups spans by paragraph and
/// the readback's correspondence check sees both, so a multi-paragraph
/// edit is not a single-paragraph edit that got lucky.
async test "format transaction spans several paragraphs at once" {
  with_docx_session_test_dir(directory => {
    let (result, failure, published) = format_probe(
      directory,
      "multi",
      "<w:r><w:t>Hello world</w:t></w:r></w:p><w:p w14:paraId=\"0A0B0C0D\"><w:r><w:t>Second world</w:t></w:r>",
      @word.docx_direct_format(bold=true),
      text="world",
    )
    assert_true(failure is None, msg="\{failure}")
    guard result is Some(value) else { fail("no result") }
    let report = value.report()
    assert_eq(report.spans().length(), 2)
    let paths = report.affected_paths()
    assert_eq(paths.length(), 2)
    assert_true(paths[0] != paths[1], msg=paths.join(","))
    guard published is Some(bytes) else { fail("nothing published") }
    let archive = @zip.read(bytes)
    guard archive.get("word/document.xml") is Some(payload) else {
      fail("no document part")
    }
    let document = @utf8.decode(payload)
    // Both selected spans carry the request, and both paragraphs keep
    // the text they had.
    assert_eq(
      document.split("<w:b/>").collect().length() - 1,
      2,
      msg="one bold per selected span",
    )
    assert_true(document.contains("Hello "), msg=document)
    assert_true(document.contains("Second "), msg=document)
    // The second paragraph's stable identity survived the edit, so the
    // span that named it can be named again.
    assert_true(document.contains("w14:paraId=\"0A0B0C0D\""), msg=document)
  })
}

///|
/// A stable `p[id="…"]` scope narrows the same request to one paragraph,
/// and the report echoes what the scope resolved to.
async test "format transaction honours a stable paragraph scope" {
  with_docx_session_test_dir(directory => {
    let (result, failure, published) = format_probe(
      directory,
      "scoped",
      "<w:r><w:t>Hello world</w:t></w:r></w:p><w:p w14:paraId=\"0A0B0C0D\"><w:r><w:t>Second world</w:t></w:r>",
      @word.docx_direct_format(bold=true),
      text="world",
      within="p[id=\"0A0B0C0D\"]",
    )
    assert_true(failure is None, msg="\{failure}")
    guard result is Some(value) else { fail("no result") }
    let report = value.report()
    assert_eq(report.spans().length(), 1)
    assert_eq(report.requested_within(), Some("p[id=\"0A0B0C0D\"]"))
    assert_true(report.resolved_within() is Some(_), msg="scope must echo")
    assert_eq(report.affected_paths().length(), 1)
    guard published is Some(bytes) else { fail("nothing published") }
    let archive = @zip.read(bytes)
    guard archive.get("word/document.xml") is Some(payload) else {
      fail("no document part")
    }
    let document = @utf8.decode(payload)
    assert_eq(document.split("<w:b/>").collect().length() - 1, 1)
    // The bold landed in the SCOPED paragraph, not the first one.
    guard document.find("0A0B0C0D") is Some(scope_at) else {
      fail("no scoped paragraph")
    }
    guard document.find("<w:b/>") is Some(bold_at) else { fail("no bold") }
    assert_true(bold_at > scope_at, msg="the bold belongs after the scope")
  })
}

///|
/// A dry run plans, validates, and reports — and writes nothing.
async test "format transaction dry run publishes nothing" {
  with_docx_session_test_dir(directory => {
    let (result, failure, published) = format_probe(
      directory,
      "dry",
      "<w:r><w:t>Hello world</w:t></w:r>",
      @word.docx_direct_format(bold=true),
      text="world",
      dry_run=true,
    )
    assert_true(failure is None, msg="\{failure}")
    guard result is Some(value) else { fail("no result") }
    assert_eq(value.report().spans().length(), 1)
    assert_true(published is None, msg="a dry run must not write")
  })
}

///|
/// The caller's own preflight runs against the report BEFORE anything is
/// published, so refusing there leaves no file behind.
async test "format transaction lets the caller refuse the plan" {
  with_docx_session_test_dir(directory => {
    let seen : Ref[Int] = Ref(0)
    let (result, failure, published) = format_probe(
      directory,
      "preflight",
      "<w:r><w:t>Hello world</w:t></w:r>",
      @word.docx_direct_format(bold=true),
      text="world",
      preflight=report => {
        seen.val = report.spans().length()
        raise @transaction.transaction_failure(
          "office.format.caller_refused", "the caller declined this plan",
        )
      },
    )
    assert_eq(seen.val, 1, msg="the preflight sees the plan it judges")
    assert_true(result is None, msg="a refused plan has no result")
    guard failure is Some(message) else { fail("expected a refusal") }
    assert_true(message.contains("declined this plan"), msg=message)
    assert_true(published is None, msg="a refused plan writes nothing")
  })
}

///|
/// Report arrays are the caller's to keep: mutating what an accessor
/// returns must not reach back into the report.
async test "format report accessors hand out copies" {
  with_docx_session_test_dir(directory => {
    let (result, _, _) = format_probe(
      directory,
      "copies",
      "<w:r><w:t>Hello world</w:t></w:r>",
      @word.docx_direct_format(bold=true),
      text="world",
    )
    guard result is Some(value) else { fail("no result") }
    let report = value.report()
    let spans = report.spans()
    let affected = report.affected()
    let selected = report.selected()
    spans.clear()
    affected.clear()
    selected.clear()
    assert_eq(report.spans().length(), 1)
    assert_eq(report.affected().length(), 1)
    assert_eq(report.selected().length(), 1)
  })
}
