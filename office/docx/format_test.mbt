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
    assert_true(failure is None, msg="unexpected failure: \{Repr(failure)}")
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
    assert_true(failure is None, msg="unexpected failure: \{Repr(failure)}")
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
    assert_true(failure is None, msg="unexpected failure: \{Repr(failure)}")
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
      msg="unexpected failure: \{Repr(allow_failure)}",
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
      msg="expect 0 must be satisfiable: \{Repr(asserted_failure)}",
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
    let rebuilt = @zip.Archive()
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
      @zip.write_preserving(rebuilt),
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
  settings_root_insert? : String = "",
  runs? : String = "<w:r><w:t>Hello world</w:t></w:r>",
) -> String {
  let source = edit_fixture(directory, name + "-source.docx", runs)
  let archive = @zip.read(@afs.read_file(source).binary())
  let rebuilt = @zip.Archive()
  for entry in archive.entries() {
    let entry_name = entry.name()
    guard archive.get(entry_name) is Some(payload) else { continue }
    if entry_name == "word/settings.xml" &&
      (settings_body != "" || settings_root_insert != "") {
      let mut text = @utf8.decode(payload)
      if settings_root_insert != "" {
        text = text.replace(
          old="mc:Ignorable=\"w14\"",
          new="mc:Ignorable=\"w14\"" + settings_root_insert,
        )
      }
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
    @zip.write_preserving(rebuilt),
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
      msg="unenforced protection must not block: \{Repr(unenforced_failure)}",
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
      msg="trackRevisions=false must not block: \{Repr(untracked_failure)}",
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
      msg="a foreign trackRevisions must not block: \{Repr(foreign_failure)}",
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
      msg="a commented setting must not block: \{Repr(commented_failure)}",
    )
    // A fork NESTED inside the fallback this toolkit took is still a
    // fork: a consumer that understands the inner vocabulary reads the
    // protected branch, so the protection depends on who opens the
    // document.
    let nested_fork = preflight_fixture(
      directory,
      "nested-fork",
      "<mc:AlternateContent xmlns:mc=\"http://schemas.openxmlformats.org/markup-compatibility/2006\">" +
      "<mc:Choice Requires=\"x\" xmlns:x=\"urn:example:x\"><w:documentProtection w:enforcement=\"0\"/></mc:Choice>" +
      "<mc:Fallback><mc:AlternateContent><mc:Choice Requires=\"w14\"><w:documentProtection w:edit=\"readOnly\" w:enforcement=\"1\"/></mc:Choice>" +
      "<mc:Fallback><w:documentProtection w:enforcement=\"0\"/></mc:Fallback></mc:AlternateContent></mc:Fallback>" +
      "</mc:AlternateContent>",
      [],
    )
    let (nested_fork_failure, nested_fork_published) = format_input_probe(
      nested_fork,
      directory + "/nested-fork-out.docx",
    )
    guard nested_fork_failure is Some(nested_fork_message) else {
      fail("a nested fork still forks the protection")
    }
    assert_true(
      nested_fork_message.contains("compatibility alternatives") ||
      nested_fork_message.contains("more than once"),
      msg=nested_fork_message,
    )
    assert_false(nested_fork_published, msg="nothing may be published")
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
      ambiguous_message.contains("declared more than once"),
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
    // Annotations run their own transaction rather than an edit session,
    // so they ask for the preflight themselves — and must still get it.
    let mut annotation_failure : String? = None
    try
      @docx.transact_docx_annotations(
        @transaction.transaction_options(
          tracked,
          output_path=directory + "/shared-annotated.docx",
        ),
        @docx.parse_annotation_batch(
          "{\"schema\": \"docx.annotation-batch/1\", \"ops\": [" +
          "{\"op\": \"comment_add\", \"anchor\": {\"at\": \"/docx/body/p[1]\"}, " +
          "\"author\": \"Ada\", \"body\": [\"Please revise\"]}]}",
        ),
      )
      |> ignore
    catch {
      error => annotation_failure = Some("\{error}")
    }
    guard annotation_failure is Some(annotation_message) else {
      fail("annotations must reach the shared preflight")
    }
    assert_true(
      annotation_message.contains("records revisions"),
      msg=annotation_message,
    )
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
    assert_true(failure is None, msg="\{Repr(failure)}")
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
    assert_true(failure is None, msg="\{Repr(failure)}")
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
    assert_true(failure is None, msg="\{Repr(failure)}")
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
    spans[0].source_runs.clear()
    spans.clear()
    affected.clear()
    selected.clear()
    assert_eq(report.spans().length(), 1)
    assert_true(
      report.spans()[0].source_runs.length() > 0,
      msg="a span's own array is the caller's copy too",
    )
    assert_eq(report.affected().length(), 1)
    assert_eq(report.selected().length(), 1)
  })
}

///|
/// A fixture repackaged part by part: entries renamed, text substituted,
/// and extra parts added, so a test can move the main document part or
/// re-spell a relationship target without hand-writing a package.
async fn repackaged_fixture(
  directory : String,
  name : String,
  renames : Array[(String, String)],
  edits : Array[(String, String, String)],
  additions : Array[(String, String)],
  runs? : String = "<w:r><w:t>Hello world</w:t></w:r>",
) -> String {
  let source = edit_fixture(directory, name + "-source.docx", runs)
  let archive = @zip.read(@afs.read_file(source).binary())
  let rebuilt = @zip.Archive()
  for entry in archive.entries() {
    let old_name = entry.name()
    guard archive.get(old_name) is Some(payload) else { continue }
    let mut entry_name = old_name
    for rename in renames {
      if rename.0 == old_name {
        entry_name = rename.1
      }
    }
    let mut text : String? = None
    for edit in edits {
      if edit.0 == entry_name {
        let current = match text {
          Some(value) => value
          None => @utf8.decode(payload)
        }
        guard current.contains(edit.1) else {
          fail("\{entry_name} does not contain \{edit.1}")
        }
        text = Some(current.replace(old=edit.1, new=edit.2))
      }
    }
    match text {
      Some(value) => rebuilt.add(entry_name, @utf8.encode(value))
      None => rebuilt.add(entry_name, payload.to_owned())
    }
  }
  for addition in additions {
    rebuilt.add(addition.0, @utf8.encode(addition.1))
  }
  let path = directory + "/" + name + ".docx"
  @afs.write_file(
    path,
    @zip.write_preserving(rebuilt),
    create_mode=CreateNew,
    permission=0o600,
  )
  path
}

///|
/// The preflight follows the package's own relationships. A document
/// whose main part is not `word/document.xml`, or whose settings target
/// is spelled with a dot segment, still has its settings read — and a
/// settings-shaped part nothing refers to is not this document's
/// settings.
async test "the preflight reads the settings the package points at" {
  with_docx_session_test_dir(directory => {
    // The main document part moved, so a `word/_rels/document.xml.rels`
    // assumption would find nothing at all.
    let rehomed = repackaged_fixture(
      directory,
      "rehomed",
      [
        ("word/document.xml", "word/document2.xml"),
        ("word/_rels/document.xml.rels", "word/_rels/document2.xml.rels"),
      ],
      [
        (
          "[Content_Types].xml", "PartName=\"/word/document.xml\"", "PartName=\"/word/document2.xml\"",
        ),
        (
          "_rels/.rels", "Target=\"word/document.xml\"", "Target=\"word/document2.xml\"",
        ),
        (
          "word/settings.xml", "</w:settings>", "<w:trackRevisions/></w:settings>",
        ),
      ],
      [],
    )
    let (rehomed_failure, rehomed_published) = format_input_probe(
      rehomed,
      directory + "/rehomed-out.docx",
    )
    guard rehomed_failure is Some(rehomed_message) else {
      fail("a rehomed main part must still have its settings read")
    }
    assert_true(
      rehomed_message.contains("records revisions"),
      msg=rehomed_message,
    )
    assert_false(rehomed_published, msg="nothing may be published")
    // A dot-segmented target names the same part.
    let dotted = repackaged_fixture(
      directory,
      "dotted",
      [],
      [
        (
          "word/_rels/document.xml.rels", "Target=\"settings.xml\"", "Target=\"./settings.xml\"",
        ),
        (
          "word/settings.xml", "</w:settings>", "<w:trackRevisions/></w:settings>",
        ),
      ],
      [],
    )
    let (dotted_failure, _) = format_input_probe(
      dotted,
      directory + "/dotted-out.docx",
    )
    guard dotted_failure is Some(dotted_message) else {
      fail("a dot-segmented target names the settings part")
    }
    assert_true(
      dotted_message.contains("records revisions"),
      msg=dotted_message,
    )
    // A settings-shaped part with no relationship to this document is
    // some other package's business.
    let unrelated = repackaged_fixture(
      directory,
      "unrelated",
      [],
      [
        (
          "[Content_Types].xml", "<Override PartName=\"/word/settings.xml\"", "<Override PartName=\"/word/settings2.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.settings+xml\"/><Override PartName=\"/word/settings.xml\"",
        ),
      ],
      [
        (
          "word/settings2.xml", "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><w:settings xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:trackRevisions/></w:settings>",
        ),
      ],
    )
    let (unrelated_failure, unrelated_published) = format_input_probe(
      unrelated,
      directory + "/unrelated-out.docx",
    )
    assert_true(
      unrelated_failure is None,
      msg="an unreferenced settings part must not block: \{Repr(unrelated_failure)}",
    )
    assert_true(unrelated_published, msg="the edit publishes")
  })
}

///|
/// A discovered signature's content type is read the way OPC reads any
/// part's: its Override if it has one, and the Default for its extension
/// only otherwise.
async test "the preflight reads a signature's content type by precedence" {
  with_docx_session_test_dir(directory => {
    let by_default = repackaged_fixture(
      directory,
      "sig-default",
      [],
      [
        (
          "_rels/.rels", "</Relationships>", "<Relationship Id=\"rIdSigOrigin\" Type=\"http://schemas.openxmlformats.org/package/2006/relationships/digital-signature/origin\" Target=\"_xmlsignatures/origin.sigs\"/></Relationships>",
        ),
        (
          "[Content_Types].xml", "</Types>", "<Default Extension=\"sigs\" ContentType=\"application/vnd.openxmlformats-package.digital-signature-origin\"/><Default Extension=\"sigx\" ContentType=\"APPLICATION/VND.OPENXMLFORMATS-PACKAGE.DIGITAL-SIGNATURE-XMLSIGNATURE+XML\"/></Types>",
        ),
      ],
      [
        ("_xmlsignatures/origin.sigs", "<origin/>"),
        (
          "_xmlsignatures/_rels/origin.sigs.rels", "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"rIdSig1\" Type=\"http://schemas.openxmlformats.org/package/2006/relationships/digital-signature/signature\" Target=\"sig1.sigx\"/></Relationships>",
        ),
        ("_xmlsignatures/sig1.sigx", "<Signature/>"),
      ],
    )
    let (default_failure, default_published) = format_input_probe(
      by_default,
      directory + "/sig-default-out.docx",
    )
    guard default_failure is Some(default_message) else {
      fail("a signature typed by Default is a signature")
    }
    assert_true(
      default_message.contains("digital signature"),
      msg=default_message,
    )
    assert_false(default_published, msg="nothing may be published")
    // The same package, with the signature part's OWN Override saying
    // something else: the Override is what the part is.
    let overridden = repackaged_fixture(
      directory,
      "sig-override",
      [],
      [
        (
          "_rels/.rels", "</Relationships>", "<Relationship Id=\"rIdSigOrigin\" Type=\"http://schemas.openxmlformats.org/package/2006/relationships/digital-signature/origin\" Target=\"_xmlsignatures/origin.sigs\"/></Relationships>",
        ),
        (
          "[Content_Types].xml", "</Types>", "<Default Extension=\"sigs\" ContentType=\"application/vnd.openxmlformats-package.digital-signature-origin\"/><Default Extension=\"sigx\" ContentType=\"application/vnd.openxmlformats-package.digital-signature-xmlsignature+xml\"/><Override PartName=\"/_xmlsignatures/sig1.sigx\" ContentType=\"application/xml\"/></Types>",
        ),
      ],
      [
        ("_xmlsignatures/origin.sigs", "<origin/>"),
        (
          "_xmlsignatures/_rels/origin.sigs.rels", "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"rIdSig1\" Type=\"http://schemas.openxmlformats.org/package/2006/relationships/digital-signature/signature\" Target=\"sig1.sigx\"/></Relationships>",
        ),
        ("_xmlsignatures/sig1.sigx", "<note/>"),
      ],
    )
    let (override_failure, override_published) = format_input_probe(
      overridden,
      directory + "/sig-override-out.docx",
    )
    assert_true(
      override_failure is None,
      msg="an overridden part is not a signature: \{Repr(override_failure)}",
    )
    assert_true(override_published, msg="the edit publishes")
  })
}

///|
/// The one edit a document that records revisions must still accept:
/// resolving the revisions it already carries. Refusing it would leave a
/// caller with tracked changes and no verb that can clear them — but the
/// waiver is narrow, and a signature or an enforced protection still
/// refuses the same script.
async test "the preflight lets a tracked document resolve its own revisions" {
  with_docx_session_test_dir(directory => {
    let tracked = preflight_fixture(
      directory,
      "resolvable",
      "<w:trackRevisions/>",
      [],
      runs=REVENUE_RUNS,
    )
    let accepted = directory + "/resolvable-out.docx"
    let result = @docx.transact_docx_edit(
      @transaction.transaction_options(tracked, output_path=accepted),
      edit_script([revision_op(true, all=true)]),
      allow_unmatched=false,
    )
    assert_true(result.report.revisions_resolved > 0)
    let published = @zip.read(@afs.read_file(accepted).binary())
    guard published.get("word/document.xml") is Some(payload) else {
      fail("no document part")
    }
    let document = @utf8.decode(payload)
    assert_true(document.contains("up 18%"), msg=document)
    assert_false(document.contains("<w:del "), msg=document)
    // The SAME document refuses an ordinary text edit: the waiver is for
    // resolving revisions, not for editing tracked documents.
    let mut failure : String? = None
    try
      @docx.transact_docx_find_replace(
        @transaction.transaction_options(
          tracked,
          output_path=directory + "/resolvable-replaced.docx",
        ),
        needle="revenue",
        replacement="profit",
      )
      |> ignore
    catch {
      error => failure = Some("\{error}")
    }
    guard failure is Some(message) else { fail("expected a refusal") }
    assert_true(message.contains("records revisions"), msg=message)
    // And the waiver does not reach the other two conditions.
    let signed = signed_fixture(
      directory,
      "signed-tracked",
      "<w:trackRevisions/>",
      runs=REVENUE_RUNS,
    )
    let mut signed_failure : String? = None
    try
      @docx.transact_docx_edit(
        @transaction.transaction_options(
          signed,
          output_path=directory + "/signed-tracked-out.docx",
        ),
        edit_script([revision_op(true, all=true)]),
        allow_unmatched=false,
      )
      |> ignore
    catch {
      error => signed_failure = Some("\{error}")
    }
    guard signed_failure is Some(signed_message) else {
      fail("a signed package refuses every verb")
    }
    assert_true(
      signed_message.contains("digital signature"),
      msg=signed_message,
    )
    let protected_input = preflight_fixture(
      directory,
      "protected-tracked",
      "<w:documentProtection w:edit=\"readOnly\" w:enforcement=\"1\"/><w:trackRevisions/>",
      [],
      runs=REVENUE_RUNS,
    )
    let mut protected_failure : String? = None
    try
      @docx.transact_docx_edit(
        @transaction.transaction_options(
          protected_input,
          output_path=directory + "/protected-tracked-out.docx",
        ),
        edit_script([revision_op(true, all=true)]),
        allow_unmatched=false,
      )
      |> ignore
    catch {
      error => protected_failure = Some("\{error}")
    }
    guard protected_failure is Some(protected_message) else {
      fail("an enforced protection refuses every verb")
    }
    assert_true(
      protected_message.contains("editing protection"),
      msg=protected_message,
    )
  })
}

///|
/// The settings part is READ, not scanned. Every case here turns on the
/// difference: a foreign attribute is not `w:val`, a setting inside
/// compatibility markup is still a setting, and a part that does not
/// parse is not evidence of anything.
async test "the preflight reads settings as XML" {
  with_docx_session_test_dir(directory => {
    // A foreign `val` leaves the WML attribute ABSENT, and an absent
    // `w:val` on an on/off element means on.
    let foreign_val = preflight_fixture(
      directory,
      "foreign-val",
      "<w:trackRevisions xmlns:x=\"urn:example:x\" x:val=\"false\"/>",
      [],
    )
    let (foreign_failure, _) = format_input_probe(
      foreign_val,
      directory + "/foreign-val-out.docx",
    )
    guard foreign_failure is Some(foreign_message) else {
      fail("a foreign val does not disable a WML flag")
    }
    assert_true(
      foreign_message.contains("records revisions"),
      msg=foreign_message,
    )
    // A setting this toolkit's reader would PASS OVER is not a setting
    // it may ignore: the reader selects the fallback and suppresses
    // every choice, so a protection declared only in a choice is one
    // whose effect depends on who opens the document.
    let wrapped = preflight_fixture(
      directory,
      "wrapped",
      "<mc:AlternateContent xmlns:mc=\"http://schemas.openxmlformats.org/markup-compatibility/2006\"><mc:Choice Requires=\"w14\"><w:trackRevisions/></mc:Choice></mc:AlternateContent>",
      [],
    )
    let (wrapped_failure, _) = format_input_probe(
      wrapped,
      directory + "/wrapped-out.docx",
    )
    guard wrapped_failure is Some(wrapped_message) else {
      fail("a suppressed protection is not an absent one")
    }
    assert_true(
      wrapped_message.contains("compatibility alternatives"),
      msg=wrapped_message,
    )
    // Branches that AGREE refuse all the same: the contract is about
    // the fork being there, not about which way it resolves.
    let agreeing = preflight_fixture(
      directory,
      "agreeing",
      "<mc:AlternateContent xmlns:mc=\"http://schemas.openxmlformats.org/markup-compatibility/2006\"><mc:Choice Requires=\"w14\"><w:trackRevisions w:val=\"0\"/></mc:Choice><mc:Fallback><w:trackRevisions w:val=\"false\"/></mc:Fallback></mc:AlternateContent>",
      [],
    )
    let (agreeing_failure, agreeing_published) = format_input_probe(
      agreeing,
      directory + "/agreeing-out.docx",
    )
    guard agreeing_failure is Some(agreeing_message) else {
      fail("a fork on the settings surface refuses")
    }
    assert_true(
      agreeing_message.contains("compatibility alternatives"),
      msg=agreeing_message,
    )
    assert_false(agreeing_published, msg="nothing may be published")
    // A settings ELEMENT is a child of `w:settings`. The same spelling
    // nested inside another element is not this document's setting, and
    // reading it as one would refuse documents that never asked for it.
    let nested = preflight_fixture(
      directory,
      "nested",
      "<w:compat><w:trackRevisions/></w:compat>",
      [],
    )
    let (nested_failure, nested_published) = format_input_probe(
      nested,
      directory + "/nested-out.docx",
    )
    assert_true(
      nested_failure is None,
      msg="a nested spelling is not a settings child: \{Repr(nested_failure)}",
    )
    assert_true(nested_published, msg="the edit publishes")
    // A settings part that DEMANDS an application namespace this
    // toolkit does not understand is one it cannot judge.
    let demanding = repackaged_fixture(
      directory,
      "demanding",
      [],
      [
        (
          "word/settings.xml", "mc:Ignorable=\"w14\"", "mc:Ignorable=\"w14\" mc:MustUnderstand=\"w14\"",
        ),
      ],
      [],
    )
    let (demanding_failure, demanding_published) = format_input_probe(
      demanding,
      directory + "/demanding-out.docx",
    )
    guard demanding_failure is Some(demanding_message) else {
      fail("a settings part this toolkit cannot read is not evidence")
    }
    assert_true(
      demanding_message.contains("could not be read"),
      msg=demanding_message,
    )
    assert_false(demanding_published, msg="nothing may be published")
    // A settings part that does not parse refuses BEFORE the package
    // validation that would also object, with a code that says why.
    let malformed = repackaged_fixture(
      directory,
      "malformed",
      [],
      [("word/settings.xml", "</w:settings>", "<w:trackRevisions>")],
      [],
    )
    let (malformed_failure, malformed_published) = format_input_probe(
      malformed,
      directory + "/malformed-out.docx",
    )
    guard malformed_failure is Some(malformed_message) else {
      fail("an unparseable settings part is not evidence of safety")
    }
    assert_true(
      malformed_message.contains("could not be read"),
      msg=malformed_message,
    )
    assert_false(malformed_published, msg="nothing may be published")
  })
}

///|
/// Two settings relationships naming different parts is legal OPC and
/// meaningless WML, so nothing downstream refuses it and the preflight
/// must.
async test "the preflight refuses a package with two settings parts" {
  with_docx_session_test_dir(directory => {
    let ambiguous = repackaged_fixture(
      directory,
      "two-settings",
      [],
      [
        (
          "[Content_Types].xml", "<Override PartName=\"/word/settings.xml\"", "<Override PartName=\"/word/settings3.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.settings+xml\"/><Override PartName=\"/word/settings.xml\"",
        ),
        (
          "word/_rels/document.xml.rels", "</Relationships>", "<Relationship Id=\"rIdSettings3\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/settings\" Target=\"settings3.xml\"/></Relationships>",
        ),
      ],
      [
        (
          "word/settings3.xml", "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><w:settings xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"/>",
        ),
      ],
    )
    let (failure, published) = format_input_probe(
      ambiguous,
      directory + "/two-settings-out.docx",
    )
    guard failure is Some(message) else {
      fail("two settings parts cannot both be this document's settings")
    }
    assert_true(message.contains("more than one settings part"), msg=message)
    assert_false(published, msg="nothing may be published")
  })
}

///|
/// The preflight judges the REQUEST, not its outcome: a request that
/// would have changed nothing is still a request to edit a document
/// this toolkit does not edit.
async test "the preflight refuses before it knows whether anything would change" {
  with_docx_session_test_dir(directory => {
    let tracked = preflight_fixture(directory, "noop", "<w:trackRevisions/>", [])
    // Nothing would match, and zero matches are explicitly allowed.
    let mut zero_failure : String? = None
    try
      @docx.transact_docx_format(
        @transaction.transaction_options(
          tracked,
          output_path=directory + "/noop-zero.docx",
        ),
        format=@word.docx_direct_format(bold=true),
        text="nothing here matches",
        allow_zero=true,
      )
      |> ignore
    catch {
      error => zero_failure = Some("\{error}")
    }
    guard zero_failure is Some(zero_message) else {
      fail("the preflight judges the request, not the match count")
    }
    assert_true(zero_message.contains("records revisions"), msg=zero_message)
    // And a dry run is still a request to edit.
    let mut dry_failure : String? = None
    try
      @docx.transact_docx_format(
        @transaction.transaction_options(
          tracked,
          output_path=directory + "/noop-dry.docx",
          dry_run=true,
        ),
        format=@word.docx_direct_format(bold=true),
        text="world",
      )
      |> ignore
    catch {
      error => dry_failure = Some("\{error}")
    }
    guard dry_failure is Some(dry_message) else {
      fail("a dry run of a refused edit is still refused")
    }
    assert_true(dry_message.contains("records revisions"), msg=dry_message)
  })
}

///|
/// Write protection is a second protection element, and only the
/// password-carrying form is enforcement.
async test "the preflight refuses password write protection" {
  with_docx_session_test_dir(directory => {
    let recommended = preflight_fixture(
      directory,
      "recommended",
      "<w:writeProtection w:recommended=\"1\"/>",
      [],
    )
    let (recommended_failure, recommended_published) = format_input_probe(
      recommended,
      directory + "/recommended-out.docx",
    )
    assert_true(
      recommended_failure is None,
      msg="read-only RECOMMENDED is advice: \{Repr(recommended_failure)}",
    )
    assert_true(recommended_published, msg="the edit publishes")
    let enforced = preflight_fixture(
      directory,
      "write-protected",
      "<w:writeProtection w:algorithmName=\"SHA-512\" w:hashValue=\"abc\" w:saltValue=\"def\" w:spinCount=\"100000\"/>",
      [],
    )
    let (enforced_failure, enforced_published) = format_input_probe(
      enforced,
      directory + "/write-protected-out.docx",
    )
    guard enforced_failure is Some(message) else {
      fail("password write protection is enforcement")
    }
    assert_true(message.contains("write protected"), msg=message)
    assert_false(enforced_published, msg="nothing may be published")
    // The legacy spelling is the same protection.
    let legacy = preflight_fixture(
      directory,
      "legacy-protected",
      "<w:writeProtection w:hash=\"abc\" w:salt=\"def\"/>",
      [],
    )
    let (legacy_failure, _) = format_input_probe(
      legacy,
      directory + "/legacy-protected-out.docx",
    )
    guard legacy_failure is Some(legacy_message) else {
      fail("the legacy password spelling is enforcement too")
    }
    assert_true(legacy_message.contains("write protected"), msg=legacy_message)
  })
}

///|
/// Part names are OPC identities, not ZIP strings: a relationship that
/// names the settings part in another case names the same part, and a
/// part's Override outranks the Default for its extension.
async test "the preflight resolves parts by OPC identity" {
  with_docx_session_test_dir(directory => {
    let recased = repackaged_fixture(
      directory,
      "recased",
      [],
      [
        (
          "word/_rels/document.xml.rels", "Target=\"settings.xml\"", "Target=\"SETTINGS.XML\"",
        ),
        (
          "word/settings.xml", "</w:settings>", "<w:trackRevisions/></w:settings>",
        ),
      ],
      [],
    )
    let (recased_failure, recased_published) = format_input_probe(
      recased,
      directory + "/recased-out.docx",
    )
    guard recased_failure is Some(recased_message) else {
      fail("a differently-cased target names the same settings part")
    }
    assert_true(
      recased_message.contains("records revisions"),
      msg=recased_message,
    )
    assert_false(recased_published, msg="nothing may be published")
  })
}

///|
/// A paragraph inside a table cell is a paragraph. The preservation
/// check is paragraph-scoped by design — a cell's `w:tcPr` is outside
/// the plan's declared byte edits — so this pins that the splice keeps
/// it rather than that the check compares it.
async test "format transaction reaches a paragraph inside a table" {
  with_docx_session_test_dir(directory => {
    let (result, failure, published) = format_probe(
      directory,
      "table",
      "<w:r><w:t>Hello world</w:t></w:r></w:p>" +
      "<w:tbl><w:tblPr><w:tblW w:w=\"0\" w:type=\"auto\"/></w:tblPr>" +
      "<w:tblGrid><w:gridCol w:w=\"4675\"/></w:tblGrid>" +
      "<w:tr><w:tc><w:tcPr><w:tcW w:w=\"4675\" w:type=\"dxa\"/>" +
      "<w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"FFFF00\"/></w:tcPr>" +
      "<w:p><w:r><w:t>cell world</w:t></w:r></w:p>" +
      "</w:tc></w:tr></w:tbl><w:p>",
      @word.docx_direct_format(italic=true),
      text="cell world",
    )
    assert_true(failure is None, msg="\{Repr(failure)}")
    guard result is Some(value) else { fail("no result") }
    let report = value.report()
    assert_eq(report.spans().length(), 1)
    // The affected paragraph is the one in the cell, not the body's.
    let paths = report.affected_paths()
    assert_eq(paths.length(), 1)
    assert_true(paths[0].contains("tbl"), msg=paths[0])
    guard published is Some(bytes) else { fail("nothing published") }
    let archive = @zip.read(bytes)
    guard archive.get("word/document.xml") is Some(payload) else {
      fail("no document part")
    }
    let document = @utf8.decode(payload)
    assert_eq(document.split("<w:i/>").collect().length() - 1, 1)
    // The cell's own formatting is untouched by the splice.
    assert_true(document.contains("w:fill=\"FFFF00\""), msg=document)
    assert_true(document.contains("<w:tcW w:w=\"4675\""), msg=document)
    assert_true(document.contains("Hello world"), msg=document)
  })
}

///|
/// A package with a real OPC signature chain: the package relates to an
/// origin part, and the origin relates to the signature. Discovery is a
/// walk, so a fixture that only drops a signature-typed part in the zip
/// would not be signed.
async fn signed_fixture(
  directory : String,
  name : String,
  settings_body : String,
  runs? : String = "<w:r><w:t>Hello world</w:t></w:r>",
  origin_only? : Bool = false,
) -> String {
  let additions : Array[(String, String)] = [
    ("_xmlsignatures/origin.sigs", "<origin/>"),
  ]
  if !origin_only {
    additions.push(
      (
        "_xmlsignatures/_rels/origin.sigs.rels", "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"rIdSig1\" Type=\"http://schemas.openxmlformats.org/package/2006/relationships/digital-signature/signature\" Target=\"sig1.xml\"/></Relationships>",
      ),
    )
    additions.push(("_xmlsignatures/sig1.xml", "<Signature/>"))
  }
  let edits : Array[(String, String, String)] = [
    (
      "_rels/.rels", "</Relationships>", "<Relationship Id=\"rIdSigOrigin\" Type=\"http://schemas.openxmlformats.org/package/2006/relationships/digital-signature/origin\" Target=\"_xmlsignatures/origin.sigs\"/></Relationships>",
    ),
    (
      "[Content_Types].xml",
      "</Types>",
      "<Default Extension=\"sigs\" ContentType=\"application/vnd.openxmlformats-package.digital-signature-origin\"/>" +
      (if origin_only {
        ""
      } else {
        "<Override PartName=\"/_xmlsignatures/sig1.xml\" ContentType=\"application/vnd.openxmlformats-package.digital-signature-xmlsignature+xml\"/>"
      }) +
      "</Types>",
    ),
  ]
  if settings_body != "" {
    edits.push(
      ("word/settings.xml", "</w:settings>", settings_body + "</w:settings>"),
    )
  }
  repackaged_fixture(directory, name, [], edits, additions, runs~)
}

///|
/// A signature is DISCOVERED, not spotted: the package relates to an
/// origin and the origin relates to the signature. A signature-typed
/// part nothing points at is not a signature any consumer would find.
async test "the preflight discovers signatures through their relationships" {
  with_docx_session_test_dir(directory => {
    let signed = signed_fixture(directory, "chained", "")
    let (signed_failure, signed_published) = format_input_probe(
      signed,
      directory + "/chained-out.docx",
    )
    guard signed_failure is Some(signed_message) else {
      fail("a related signature is a signature")
    }
    assert_true(
      signed_message.contains("digital signature"),
      msg=signed_message,
    )
    assert_false(signed_published, msg="nothing may be published")
    // An origin with no signature relationship is scaffolding.
    let scaffolding = signed_fixture(
      directory,
      "scaffolding",
      "",
      origin_only=true,
    )
    let (scaffolding_failure, scaffolding_published) = format_input_probe(
      scaffolding,
      directory + "/scaffolding-out.docx",
    )
    assert_true(
      scaffolding_failure is None,
      msg="an origin alone is not a signature: \{Repr(scaffolding_failure)}",
    )
    assert_true(scaffolding_published, msg="the edit publishes")
    // A signature-typed part nothing relates to is not discoverable.
    let orphan = repackaged_fixture(
      directory,
      "orphan",
      [],
      [
        (
          "[Content_Types].xml", "</Types>", "<Override PartName=\"/custom/sig.xml\" ContentType=\"application/vnd.openxmlformats-package.digital-signature-xmlsignature+xml\"/></Types>",
        ),
      ],
      [("custom/sig.xml", "<Signature/>")],
    )
    let (orphan_failure, orphan_published) = format_input_probe(
      orphan,
      directory + "/orphan-out.docx",
    )
    assert_true(
      orphan_failure is None,
      msg="an unreachable signature part is not a package signature: \{Repr(orphan_failure)}",
    )
    assert_true(orphan_published, msg="the edit publishes")
  })
}

///|
/// Round-19 fidelity: present rels fail closed, and a branch with two
/// sibling roots is no document.
async test "the preflight fails closed on rels and multi-root branches" {
  with_docx_session_test_dir(directory => {
    // A PRESENT origin rels part that cannot be parsed hides nothing:
    // the package refuses as unreadable instead of publishing over a
    // signature the analysis could not see.
    let broken_rels = repackaged_fixture(
      directory,
      "broken-rels",
      [],
      [
        (
          "_rels/.rels", "</Relationships>", "<Relationship Id=\"rIdSigOrigin\" Type=\"http://schemas.openxmlformats.org/package/2006/relationships/digital-signature/origin\" Target=\"_xmlsignatures/origin.sigs\"/></Relationships>",
        ),
      ],
      [
        ("_xmlsignatures/origin.sigs", "<origin/>"),
        ("_xmlsignatures/_rels/origin.sigs.rels", "<Relationships"),
      ],
    )
    let (broken_failure, broken_published) = format_input_probe(
      broken_rels,
      directory + "/broken-rels-out.docx",
    )
    guard broken_failure is Some(broken_message) else {
      fail("an unreadable present rels part is not evidence of safety")
    }
    assert_true(
      broken_message.contains("could not be read") ||
      broken_message.contains("invalid"),
      msg=broken_message,
    )
    assert_false(broken_published, msg="nothing may be published")
    // A choice holding TWO sibling settings roots is no document for
    // its consumers: the tracked sibling decides nothing, and the
    // single-root fallback publishes.
    let twin_roots = repackaged_fixture(
      directory,
      "twin-roots",
      [],
      [
        (
          "word/settings.xml",
          "<w:settings",
          "<mc0:AlternateContent xmlns:mc0=\"http://schemas.openxmlformats.org/markup-compatibility/2006\" xmlns:x=\"urn:example:x\">" +
          "<mc0:Choice Requires=\"x\">" +
          "<w:settings xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"/>" +
          "<w:settings xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"/>" +
          "</mc0:Choice><mc0:Fallback><w:settings",
        ),
        (
          "word/settings.xml", "</w:settings>", "</w:settings></mc0:Fallback></mc0:AlternateContent>",
        ),
      ],
      [],
    )
    let (twin_failure, twin_published) = format_input_probe(
      twin_roots,
      directory + "/twin-roots-out.docx",
    )
    // An alternate-rooted settings part is a FORK on a protection
    // surface: the contract refuses it in its own voice.
    guard twin_failure is Some(twin_message) else {
      fail("a fork on the settings surface refuses")
    }
    assert_true(
      twin_message.contains("compatibility alternatives"),
      msg=twin_message,
    )
    assert_false(twin_published, msg="nothing may be published")
  })
}

///|
/// Round-21 fidelity: an element that declares ITSELF ignorable is one
/// some consumer drops, and the root beside it is that consumer's
/// document.
async test "the preflight honours self-declared ignorability" {
  with_docx_session_test_dir(directory => {
    let self_ignorable = repackaged_fixture(
      directory,
      "self-ignorable",
      [],
      [
        (
          "word/settings.xml",
          "<w:settings",
          "<mc0:AlternateContent xmlns:mc0=\"http://schemas.openxmlformats.org/markup-compatibility/2006\" xmlns:y=\"urn:example:y\">" +
          "<mc0:Choice Requires=\"y\">" +
          "<x:noise xmlns:x=\"urn:example:x\" mc0:Ignorable=\"x\"/>" +
          "<w:settings xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:trackRevisions/></w:settings>" +
          "</mc0:Choice><mc0:Fallback><w:settings",
        ),
        (
          "word/settings.xml", "</w:settings>", "</w:settings></mc0:Fallback></mc0:AlternateContent>",
        ),
      ],
      [],
    )
    let (failure, published) = format_input_probe(
      self_ignorable,
      directory + "/self-ignorable-out.docx",
    )
    guard failure is Some(message) else {
      fail(
        "the consumers who drop the self-ignorable noise read the tracked root",
      )
    }
    assert_true(
      message.contains("records revisions") ||
      message.contains("compatibility alternatives") ||
      message.contains("could not be read"),
      msg=message,
    )
    assert_false(published, msg="nothing may be published")
  })
}

///|
/// THE COMPATIBILITY CONTRACT: `mc:AlternateContent` on a protection
/// surface — the settings part, or a relationship part the preflight
/// follows — refuses, typed, whatever the branches say. Different
/// consumers can read different protections there, and this preflight
/// reads as one consumer and says so instead of guessing. (A
/// 591-document corpus sample carries zero such constructs, so the
/// refusal is invisible to real documents.)
async test "compatibility alternatives on a protection surface refuse" {
  with_docx_session_test_dir(directory => {
    // Even branches that AGREE refuse: the contract is about the fork
    // being there, not about which way it resolves.
    let settings_fork = preflight_fixture(
      directory,
      "settings-fork",
      "<mc:AlternateContent xmlns:mc=\"http://schemas.openxmlformats.org/markup-compatibility/2006\">" +
      "<mc:Choice Requires=\"w14\"><w:trackRevisions w:val=\"0\"/></mc:Choice>" +
      "<mc:Fallback><w:trackRevisions w:val=\"false\"/></mc:Fallback>" +
      "</mc:AlternateContent>",
      [],
    )
    let (settings_failure, settings_published) = format_input_probe(
      settings_fork,
      directory + "/settings-fork-out.docx",
    )
    guard settings_failure is Some(settings_message) else {
      fail("a fork on the settings surface refuses")
    }
    assert_true(
      settings_message.contains("compatibility alternatives"),
      msg=settings_message,
    )
    assert_false(settings_published, msg="nothing may be published")
    // The same rule for the document's relationships: a fork can steer
    // which settings part a consumer follows.
    let rels_fork = repackaged_fixture(
      directory,
      "rels-fork",
      [],
      [
        (
          "word/_rels/document.xml.rels",
          "<Relationship Id=\"rId3\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/settings\" Target=\"settings.xml\"/>",
          "<mc:AlternateContent xmlns:mc=\"http://schemas.openxmlformats.org/markup-compatibility/2006\" xmlns:r=\"http://schemas.openxmlformats.org/package/2006/relationships\">" +
          "<mc:Choice Requires=\"r\"><Relationship Id=\"rId3\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/settings\" Target=\"settings.xml\"/></mc:Choice>" +
          "<mc:Fallback><Relationship Id=\"rId3\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/settings\" Target=\"settings.xml\"/></mc:Fallback>" +
          "</mc:AlternateContent>",
        ),
      ],
      [],
    )
    let (rels_failure, rels_published) = format_input_probe(
      rels_fork,
      directory + "/rels-fork-out.docx",
    )
    guard rels_failure is Some(rels_message) else {
      fail("a fork on the relationships surface refuses")
    }
    assert_true(
      rels_message.contains("compatibility alternatives"),
      msg=rels_message,
    )
    assert_false(rels_published, msg="nothing may be published")
    // A protection visible ONLY in a branch is exactly what the
    // contract closes: refused, never resolved past.
    let hidden = preflight_fixture(
      directory,
      "hidden-protection",
      "<mc:AlternateContent xmlns:mc=\"http://schemas.openxmlformats.org/markup-compatibility/2006\">" +
      "<mc:Choice Requires=\"w14\"><w:documentProtection w:edit=\"readOnly\" w:enforcement=\"1\"/></mc:Choice>" +
      "<mc:Fallback/></mc:AlternateContent>",
      [],
    )
    let (hidden_failure, hidden_published) = format_input_probe(
      hidden,
      directory + "/hidden-protection-out.docx",
    )
    guard hidden_failure is Some(hidden_message) else {
      fail("a branch-hidden protection refuses")
    }
    assert_true(
      hidden_message.contains("compatibility alternatives"),
      msg=hidden_message,
    )
    assert_false(hidden_published, msg="nothing may be published")
  })
}

///|
/// MCE WITHOUT forks reads as a WML consumer reads it, and publishes or
/// refuses on what that reading says — no alternate content, no
/// contract refusal.
async test "forkless compatibility markup reads as WML" {
  with_docx_session_test_dir(directory => {
    // An ignorable wrapper nobody asked to process is dropped whole.
    let opaque_input = preflight_fixture(
      directory,
      "opaque",
      "<w14:opaque><w:trackRevisions/></w14:opaque>",
      [],
    )
    let (opaque_failure, opaque_published) = format_input_probe(
      opaque_input,
      directory + "/opaque-out.docx",
    )
    assert_true(
      opaque_failure is None,
      msg="an unprocessed wrapper hides nothing at this level: \{Repr(opaque_failure)}",
    )
    assert_true(opaque_published, msg="the edit publishes")
    // MustUnderstand naming WML names something this toolkit understands.
    let wml_must = repackaged_fixture(
      directory,
      "wml-must",
      [],
      [
        (
          "word/settings.xml", "mc:Ignorable=\"w14\"", "mc:Ignorable=\"w14\" mc:MustUnderstand=\"w\"",
        ),
      ],
      [],
    )
    let (wml_must_failure, wml_must_published) = format_input_probe(
      wml_must,
      directory + "/wml-must-out.docx",
    )
    assert_true(
      wml_must_failure is None,
      msg="WML is understood here: \{Repr(wml_must_failure)}",
    )
    assert_true(wml_must_published, msg="the edit publishes")
    // A nested Ignorable re-declaration retires the inherited
    // process-content rule: the wrapper's content is dropped whole, and
    // the tracking flag inside the NEXT wrapper — where the root's rule
    // still applies — is seen.
    let retired = preflight_fixture(
      directory,
      "retired",
      "<w14:scope xmlns:mc2=\"http://schemas.openxmlformats.org/markup-compatibility/2006\" mc2:Ignorable=\"w14\" mc2:ProcessContent=\"w14:scope\">" +
      "<w14:outer><w:trackRevisions/></w14:outer>" +
      "</w14:scope>",
      [],
      settings_root_insert=" mc:ProcessContent=\"w14:scope w14:outer\"",
    )
    let (retired_failure, retired_published) = format_input_probe(
      retired,
      directory + "/retired-out.docx",
    )
    assert_true(
      retired_failure is None,
      msg="a retired rule promotes nothing: \{Repr(retired_failure)}",
    )
    assert_true(retired_published, msg="the edit publishes")
    // An entity-spelled WML binding still MEANS WML end to end.
    let entity_bound = repackaged_fixture(
      directory,
      "entity-bound",
      [],
      [
        (
          "word/document.xml", "xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"",
          "xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/&#x6d;ain\"",
        ),
      ],
      [],
    )
    let (entity_failure, entity_published) = format_input_probe(
      entity_bound,
      directory + "/entity-bound-out.docx",
    )
    assert_true(
      entity_failure is None,
      msg="an entity-spelled binding means what it decodes to: \{Repr(entity_failure)}",
    )
    assert_true(entity_published, msg="the edit publishes")
    // A wrapper the effective reading PROMOTES surfaces what it holds:
    // an x-wrapped Relationships in the document rels still names the
    // settings, and the enforced protection there refuses.
    let promoted_root = repackaged_fixture(
      directory,
      "promoted-root",
      [],
      [
        (
          "word/_rels/document.xml.rels",
          "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">",
          "<x:wrap xmlns:x=\"urn:example:x\" xmlns:mc=\"http://schemas.openxmlformats.org/markup-compatibility/2006\" mc:Ignorable=\"x\" mc:ProcessContent=\"x:wrap\">" +
          "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">",
        ),
        (
          "word/_rels/document.xml.rels", "</Relationships>", "</Relationships></x:wrap>",
        ),
        (
          "word/settings.xml", "</w:settings>", "<w:documentProtection w:edit=\"readOnly\" w:enforcement=\"1\"/></w:settings>",
        ),
      ],
      [],
    )
    let (promoted_failure, promoted_published) = format_input_probe(
      promoted_root,
      directory + "/promoted-root-out.docx",
    )
    guard promoted_failure is Some(promoted_message) else {
      fail("the promoted root's settings are real")
    }
    assert_true(
      promoted_message.contains("editing protection") ||
      promoted_message.contains("could not be read"),
      msg=promoted_message,
    )
    assert_false(promoted_published, msg="nothing may be published")
  })
}

///|
/// Protection is an enforced RESTRICTION: `w:enforcement` beside
/// `w:edit="none"` and no formatting lock restricts nothing, and Word
/// edits such a document freely.
async test "enforcement without a restriction is not protection" {
  with_docx_session_test_dir(directory => {
    let unrestricted = preflight_fixture(
      directory,
      "unrestricted",
      "<w:documentProtection w:edit=\"none\" w:enforcement=\"1\"/>",
      [],
    )
    let (unrestricted_failure, unrestricted_published) = format_input_probe(
      unrestricted,
      directory + "/unrestricted-out.docx",
    )
    assert_true(
      unrestricted_failure is None,
      msg="edit=none restricts nothing: \{Repr(unrestricted_failure)}",
    )
    assert_true(unrestricted_published, msg="the edit publishes")
    // A formatting lock alone IS a restriction.
    let formatting_lock = preflight_fixture(
      directory,
      "formatting-lock",
      "<w:documentProtection w:formatting=\"1\" w:enforcement=\"1\"/>",
      [],
    )
    let (formatting_failure, formatting_published) = format_input_probe(
      formatting_lock,
      directory + "/formatting-lock-out.docx",
    )
    guard formatting_failure is Some(formatting_message) else {
      fail("an enforced formatting lock restricts formatting")
    }
    assert_true(
      formatting_message.contains("editing protection"),
      msg=formatting_message,
    )
    assert_false(formatting_published, msg="nothing may be published")
    // Enforcement with NEITHER edit nor formatting restricts nothing.
    let bare = preflight_fixture(
      directory,
      "bare-enforcement",
      "<w:documentProtection w:enforcement=\"1\"/>",
      [],
    )
    let (bare_failure, bare_published) = format_input_probe(
      bare,
      directory + "/bare-enforcement-out.docx",
    )
    assert_true(
      bare_failure is None,
      msg="enforcement of nothing restricts nothing: \{Repr(bare_failure)}",
    )
    assert_true(bare_published, msg="the edit publishes")
  })
}

///|
/// The replace readback across many paragraphs runs in one batch — the
/// scale case kept from the batching rounds.
async test "the replace readback batches across paragraphs" {
  with_docx_session_test_dir(directory => {
    let builder = StringBuilder()
    for index in 0..<200 {
      if index > 0 {
        builder.write_string("</w:p><w:p>")
      }
      builder.write_string("<w:r><w:t>target \{index}</w:t></w:r>")
    }
    let many = edit_fixture(directory, "many-replace.docx", builder.to_string())
    let replaced = @docx.transact_docx_find_replace(
      @transaction.transaction_options(
        many,
        output_path=directory + "/many-replace-out.docx",
      ),
      needle="target",
      replacement="done",
    )
    assert_eq(replaced.report.replaced(), 200)
  })
}

///|
/// Round-24 fidelity: an attribute means what the ELEMENT'S dialect
/// says. The other dialect's spelling is a foreign attribute, not the
/// flag.
async test "the preflight reads attributes in the element's own dialect" {
  with_docx_session_test_dir(directory => {
    // A Strict-spelled `val` on a Transitional element leaves the
    // Transitional flag ABSENT, and an absent on/off flag means on.
    let cross_val = preflight_fixture(
      directory,
      "cross-val",
      "<w:trackRevisions xmlns:ws=\"http://purl.oclc.org/ooxml/wordprocessingml/main\" ws:val=\"false\"/>",
      [],
    )
    let (cross_failure, cross_published) = format_input_probe(
      cross_val,
      directory + "/cross-val-out.docx",
    )
    guard cross_failure is Some(cross_message) else {
      fail("a cross-dialect val does not disable a Transitional flag")
    }
    assert_true(cross_message.contains("records revisions"), msg=cross_message)
    assert_false(cross_published, msg="nothing may be published")
    // A Strict-spelled `enforcement="0"` cannot switch off a
    // Transitional element's enforced protection.
    let cross_enforcement = preflight_fixture(
      directory,
      "cross-enforcement",
      "<w:documentProtection xmlns:ws=\"http://purl.oclc.org/ooxml/wordprocessingml/main\" w:edit=\"readOnly\" w:enforcement=\"1\" ws:enforcement=\"0\"/>",
      [],
    )
    let (enforcement_failure, enforcement_published) = format_input_probe(
      cross_enforcement,
      directory + "/cross-enforcement-out.docx",
    )
    guard enforcement_failure is Some(enforcement_message) else {
      fail("a cross-dialect enforcement does not unlock the protection")
    }
    assert_true(
      enforcement_message.contains("editing protection"),
      msg=enforcement_message,
    )
    assert_false(enforcement_published, msg="nothing may be published")
  })
}

///|
/// A MALFORMED fork refuses too — in whichever typed voice reaches it
/// first. The invariant is that no fork on a protection surface is ever
/// edited past; which refusal speaks when the fork is also broken XML
/// or broken OPC is not part of it.
async test "malformed forks refuse in some typed voice" {
  with_docx_session_test_dir(directory => {
    // An empty alternate in the DOCUMENT rels: MCE-invalid (no branch),
    // caught by whichever gate reads it first.
    let empty_fork = repackaged_fixture(
      directory,
      "empty-fork",
      [],
      [
        (
          "word/_rels/document.xml.rels", "</Relationships>", "<mc:AlternateContent xmlns:mc=\"http://schemas.openxmlformats.org/markup-compatibility/2006\"/></Relationships>",
        ),
      ],
      [],
    )
    let (fork_failure, fork_published) = format_input_probe(
      empty_fork,
      directory + "/empty-fork-out.docx",
    )
    guard fork_failure is Some(fork_message) else {
      fail("a malformed fork still refuses")
    }
    assert_true(
      fork_message.contains("compatibility alternatives") ||
      fork_message.contains("invalid") ||
      fork_message.contains("could not be read"),
      msg=fork_message,
    )
    assert_false(fork_published, msg="nothing may be published")
    // The same shape in the ROOT rels is refused by identification
    // before any of this runs.
    let root_fork = repackaged_fixture(
      directory,
      "root-fork",
      [],
      [
        (
          "_rels/.rels", "</Relationships>", "<mc:AlternateContent xmlns:mc=\"http://schemas.openxmlformats.org/markup-compatibility/2006\"/></Relationships>",
        ),
      ],
      [],
    )
    let (root_failure, root_published) = format_input_probe(
      root_fork,
      directory + "/root-fork-out.docx",
    )
    guard root_failure is Some(root_message) else {
      fail("a malformed root fork still refuses")
    }
    assert_true(
      root_message.contains("compatibility alternatives") ||
      root_message.contains("invalid") ||
      root_message.contains("could not be read") ||
      root_message.contains("identification"),
      msg=root_message,
    )
    assert_false(root_published, msg="nothing may be published")
  })
}
