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
  settings_root_insert? : String = "",
  runs? : String = "<w:r><w:t>Hello world</w:t></w:r>",
) -> String {
  let source = edit_fixture(directory, name + "-source.docx", runs)
  let archive = @zip.read(@afs.read_file(source).binary())
  let rebuilt = @zip.Archive::new()
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
  let rebuilt = @zip.Archive::new()
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
    @zip.write(rebuilt),
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
      msg="an unreferenced settings part must not block: \{unrelated_failure}",
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
      msg="an overridden part is not a signature: \{override_failure}",
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
    // The choice and the fallback DISAGREEING is the same situation:
    // Word would read one, this toolkit reads the other, and neither
    // reading is the document's own answer.
    let disagreeing = preflight_fixture(
      directory,
      "disagreeing",
      "<mc:AlternateContent xmlns:mc=\"http://schemas.openxmlformats.org/markup-compatibility/2006\"><mc:Choice Requires=\"w14\"><w:trackRevisions/></mc:Choice><mc:Fallback><w:trackRevisions w:val=\"false\"/></mc:Fallback></mc:AlternateContent>",
      [],
    )
    let (disagreeing_failure, disagreeing_published) = format_input_probe(
      disagreeing,
      directory + "/disagreeing-out.docx",
    )
    guard disagreeing_failure is Some(disagreeing_message) else {
      fail("a protection that depends on the reader is not resolved here")
    }
    assert_true(
      disagreeing_message.contains("compatibility alternatives"),
      msg=disagreeing_message,
    )
    assert_false(disagreeing_published, msg="nothing may be published")
    // A fallback that turns tracking OFF, with a choice that says the
    // same, is simply off: agreement is not ambiguity.
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
    assert_true(
      agreeing_failure is None,
      msg="branches that agree decide the question: \{agreeing_failure}",
    )
    assert_true(agreeing_published, msg="the edit publishes")
    // A value the schema does not define is neither on nor off.
    let nonsense = preflight_fixture(
      directory,
      "nonsense",
      "<w:trackRevisions w:val=\"maybe\"/>",
      [],
    )
    let (nonsense_failure, _) = format_input_probe(
      nonsense,
      directory + "/nonsense-out.docx",
    )
    guard nonsense_failure is Some(nonsense_message) else {
      fail("an undefined on/off value is not a verdict")
    }
    assert_true(
      nonsense_message.contains("outside the schema"),
      msg=nonsense_message,
    )
    // Ignorable content is content EVERY consumer drops, so a setting
    // inside it is not this document's setting. (The fixture's settings
    // root declares `mc:Ignorable="w14"` already.)
    let ignorable = preflight_fixture(
      directory,
      "ignorable",
      "<w14:wrap><w:trackRevisions/></w14:wrap>",
      [],
    )
    let (ignorable_failure, ignorable_published) = format_input_probe(
      ignorable,
      directory + "/ignorable-out.docx",
    )
    assert_true(
      ignorable_failure is None,
      msg="ignorable content is dropped, not obeyed: \{ignorable_failure}",
    )
    assert_true(ignorable_published, msg="the edit publishes")
    // The same wrapper asking for its CONTENT to be processed promotes
    // what it holds to the settings level, where it counts.
    let processed = preflight_fixture(
      directory,
      "processed",
      "<w14:wrap mc:ProcessContent=\"w14:wrap\"><w:trackRevisions/></w14:wrap>",
      [],
    )
    let (processed_failure, processed_published) = format_input_probe(
      processed,
      directory + "/processed-out.docx",
    )
    guard processed_failure is Some(processed_message) else {
      fail("promoted content is a settings child")
    }
    assert_true(
      processed_message.contains("records revisions"),
      msg=processed_message,
    )
    assert_false(processed_published, msg="nothing may be published")
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
      msg="a nested spelling is not a settings child: \{nested_failure}",
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
      msg="read-only RECOMMENDED is advice: \{recommended_failure}",
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
    assert_true(failure is None, msg="\{failure}")
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
      msg="an origin alone is not a signature: \{scaffolding_failure}",
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
      msg="an unreachable signature part is not a package signature: \{orphan_failure}",
    )
    assert_true(orphan_published, msg="the edit publishes")
  })
}

///|
/// Round-7 fidelity: what MCE actually promotes, understands, and
/// selects — judged the way a WML consumer judges it.
async test "the preflight reads compatibility markup with WML fidelity" {
  with_docx_session_test_dir(directory => {
    // An ignorable wrapper NOBODY asked to process is dropped whole by
    // one consumer and kept whole by the rest — its content is never at
    // the settings level, even when an unrelated ProcessContent names a
    // different wrapper.
    let opaque = preflight_fixture(
      directory,
      "opaque",
      "<w14:opaque><w:trackRevisions/></w14:opaque>" +
      "<w14:unwrap mc:ProcessContent=\"w14:unwrap\" xmlns:mc=\"http://schemas.openxmlformats.org/markup-compatibility/2006\"><w:zoom w:percent=\"90\"/></w14:unwrap>",
      [],
    )
    let (opaque_failure, opaque_published) = format_input_probe(
      opaque,
      directory + "/opaque-out.docx",
    )
    assert_true(
      opaque_failure is None,
      msg="an unprocessed wrapper hides nothing at this level: \{opaque_failure}",
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
      msg="WML is understood here: \{wml_must_failure}",
    )
    assert_true(wml_must_published, msg="the edit publishes")
    // A choice REQUIRING WML is the branch every consumer of this
    // document takes, so the fallback behind it decides nothing.
    let decided = preflight_fixture(
      directory,
      "decided",
      "<mc:AlternateContent xmlns:mc=\"http://schemas.openxmlformats.org/markup-compatibility/2006\">" +
      "<mc:Choice Requires=\"w\"><w:trackRevisions w:val=\"false\"/></mc:Choice>" +
      "<mc:Fallback><w:trackRevisions/></mc:Fallback>" +
      "</mc:AlternateContent>",
      [],
    )
    let (decided_failure, decided_published) = format_input_probe(
      decided,
      directory + "/decided-out.docx",
    )
    assert_true(
      decided_failure is None,
      msg="a WML choice decides for every consumer: \{decided_failure}",
    )
    assert_true(decided_published, msg="the edit publishes")
    // And the SELECTED WML choice is read: tracking on in the branch
    // every consumer takes refuses as tracking, not as ambiguity.
    let selected = preflight_fixture(
      directory,
      "selected",
      "<mc:AlternateContent xmlns:mc=\"http://schemas.openxmlformats.org/markup-compatibility/2006\">" +
      "<mc:Choice Requires=\"w\"><w:trackRevisions/></mc:Choice>" +
      "<mc:Fallback><w:trackRevisions w:val=\"false\"/></mc:Fallback>" +
      "</mc:AlternateContent>",
      [],
    )
    let (selected_failure, selected_published) = format_input_probe(
      selected,
      directory + "/selected-out.docx",
    )
    guard selected_failure is Some(selected_message) else {
      fail("the WML branch is what this document says")
    }
    assert_true(
      selected_message.contains("records revisions"),
      msg=selected_message,
    )
    assert_false(selected_published, msg="nothing may be published")
  })
}

///|
/// A relationship inside a compatibility branch is one SOME consumer
/// resolves: the settings it names must still be read.
async test "the preflight follows relationships in compatibility branches" {
  with_docx_session_test_dir(directory => {
    let forked = repackaged_fixture(
      directory,
      "forked-rels",
      [],
      [
        (
          "word/_rels/document.xml.rels",
          "<Relationship Id=\"rId3\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/settings\" Target=\"settings.xml\"/>",
          "<mc:AlternateContent xmlns:mc=\"http://schemas.openxmlformats.org/markup-compatibility/2006\">" +
          "<mc:Choice Requires=\"x\" xmlns:x=\"urn:example:x\">" +
          "<Relationship Id=\"rId3\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/settings\" Target=\"settings.xml\"/>" +
          "</mc:Choice><mc:Fallback/></mc:AlternateContent>",
        ),
        (
          "word/settings.xml", "</w:settings>", "<w:trackRevisions/></w:settings>",
        ),
      ],
      [],
    )
    let (failure, published) = format_input_probe(
      forked,
      directory + "/forked-rels-out.docx",
    )
    guard failure is Some(message) else {
      fail("a branch-hidden settings relationship still names the settings")
    }
    assert_true(
      message.contains("records revisions") || message.contains("settings"),
      msg=message,
    )
    assert_false(published, msg="nothing may be published")
  })
}

///|
/// Round-8 fidelity: reachability decides in relationship parts too,
/// and a nested `mc:Ignorable` retires the inherited process-content
/// rules for its namespaces.
async test "the preflight applies reachability and generation resets" {
  with_docx_session_test_dir(directory => {
    // A rels choice requiring only the RELATIONSHIPS vocabulary is the
    // branch every OPC consumer takes: the fallback behind it names a
    // different settings part, and decides nothing.
    let decided_rels = repackaged_fixture(
      directory,
      "decided-rels",
      [],
      [
        (
          "word/_rels/document.xml.rels",
          "<Relationship Id=\"rId3\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/settings\" Target=\"settings.xml\"/>",
          "<mc:AlternateContent xmlns:mc=\"http://schemas.openxmlformats.org/markup-compatibility/2006\" xmlns:r=\"http://schemas.openxmlformats.org/package/2006/relationships\">" +
          "<mc:Choice Requires=\"r\">" +
          "<Relationship Id=\"rId3\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/settings\" Target=\"settings.xml\"/>" +
          "</mc:Choice><mc:Fallback>" +
          "<Relationship Id=\"rId9\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/settings\" Target=\"webSettings.xml\"/>" +
          "</mc:Fallback></mc:AlternateContent>",
        ),
      ],
      [],
    )
    let (decided_failure, decided_published) = format_input_probe(
      decided_rels,
      directory + "/decided-rels-out.docx",
    )
    assert_true(
      decided_failure is None,
      msg="a decided rels choice is not a fork: \{decided_failure}",
    )
    assert_true(decided_published, msg="the edit publishes")
    // A nested Ignorable re-declaration RETIRES the inherited
    // process-content rules for its namespaces: `w14:outer` was
    // promotable at the root, but beneath the re-declaration it is
    // ignorable content nobody asked to process, and Word drops it
    // whole — together with the tracking flag inside it.
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
      msg="a retired rule promotes nothing: \{retired_failure}",
    )
    assert_true(retired_published, msg="the edit publishes")
  })
}

///|
/// Round-9 fidelity: entity-spelled bindings, alternate-rooted parts,
/// unsatisfiable chains, and generation undo order.
async test "the preflight and readback survive round-nine adversaria" {
  with_docx_session_test_dir(directory => {
    // An entity-spelled WML binding still MEANS WML: an honest bold
    // request on such a document must go through, not read back as
    // foreign collateral.
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
      msg="an entity-spelled binding means what it decodes to: \{entity_failure}",
    )
    assert_true(entity_published, msg="the edit publishes")
    // A settings part whose ROOT is an alternate resolves to a different
    // root per consumer: a protected root in the choice refuses even
    // when the fallback root is unprotected.
    let forked_root = repackaged_fixture(
      directory,
      "forked-root",
      [],
      [
        (
          "word/settings.xml",
          "<w:settings",
          "<mc0:AlternateContent xmlns:mc0=\"http://schemas.openxmlformats.org/markup-compatibility/2006\" xmlns:x=\"urn:example:x\">" +
          "<mc0:Choice Requires=\"x\"><w:settings xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:trackRevisions/></w:settings></mc0:Choice>" +
          "<mc0:Fallback><w:settings",
        ),
        (
          "word/settings.xml", "</w:settings>", "</w:settings></mc0:Fallback></mc0:AlternateContent>",
        ),
      ],
      [],
    )
    let (forked_failure, forked_published) = format_input_probe(
      forked_root,
      directory + "/forked-root-out.docx",
    )
    guard forked_failure is Some(forked_message) else {
      fail("a protected possible root is a protection")
    }
    // Whichever voice speaks — the possible-roots walk, or the MCE
    // reader refusing to read an alternate-rooted part at all — the
    // document is refused, never silently edited.
    assert_true(
      forked_message.contains("compatibility alternatives") ||
      forked_message.contains("records revisions") ||
      forked_message.contains("could not be read"),
      msg=forked_message,
    )
    assert_false(forked_published, msg="nothing may be published")
    // A signature chain whose hops demand CONTRADICTORY capabilities is
    // a path no consumer walks: origin only when `x` is supported, the
    // signature relationship only when it is not.
    let contradictory = repackaged_fixture(
      directory,
      "contradictory",
      [],
      [
        (
          "_rels/.rels",
          "</Relationships>",
          "<mc:AlternateContent xmlns:mc=\"http://schemas.openxmlformats.org/markup-compatibility/2006\" xmlns:x=\"urn:example:x\">" +
          "<mc:Choice Requires=\"x\"><Relationship Id=\"rIdSigOrigin\" Type=\"http://schemas.openxmlformats.org/package/2006/relationships/digital-signature/origin\" Target=\"_xmlsignatures/origin.sigs\"/></mc:Choice>" +
          "<mc:Fallback/></mc:AlternateContent></Relationships>",
        ),
        (
          "[Content_Types].xml", "</Types>", "<Default Extension=\"sigs\" ContentType=\"application/vnd.openxmlformats-package.digital-signature-origin\"/><Override PartName=\"/_xmlsignatures/sig1.xml\" ContentType=\"application/vnd.openxmlformats-package.digital-signature-xmlsignature+xml\"/></Types>",
        ),
      ],
      [
        ("_xmlsignatures/origin.sigs", "<origin/>"),
        (
          "_xmlsignatures/_rels/origin.sigs.rels",
          "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\" xmlns:mc=\"http://schemas.openxmlformats.org/markup-compatibility/2006\" xmlns:x=\"urn:example:x\">" +
          "<mc:AlternateContent><mc:Choice Requires=\"x\"/><mc:Fallback><Relationship Id=\"rIdSig1\" Type=\"http://schemas.openxmlformats.org/package/2006/relationships/digital-signature/signature\" Target=\"sig1.xml\"/></mc:Fallback></mc:AlternateContent></Relationships>",
        ),
        ("_xmlsignatures/sig1.xml", "<Signature/>"),
      ],
    )
    let (contradictory_failure, contradictory_published) = format_input_probe(
      contradictory,
      directory + "/contradictory-out.docx",
    )
    assert_true(
      contradictory_failure is None,
      msg="an unwalkable chain signs nothing: \{contradictory_failure}",
    )
    assert_true(contradictory_published, msg="the edit publishes")
    // `Ignorable="v v2"` binding one URI twice must UNDO to the outer
    // generation, so the root's promotion rule applies again after the
    // scope closes and the tracking flag inside the next wrapper is
    // seen.
    let double_bound = preflight_fixture(
      directory,
      "double-bound",
      "<w14:a xmlns:v=\"http://schemas.microsoft.com/office/word/2010/wordml\" xmlns:v2=\"http://schemas.microsoft.com/office/word/2010/wordml\" mc2:Ignorable=\"v v2\" xmlns:mc2=\"http://schemas.openxmlformats.org/markup-compatibility/2006\"><w14:c/></w14:a>" +
      "<w14:b><w:trackRevisions/></w14:b>",
      [],
      settings_root_insert=" mc:ProcessContent=\"w14:*\"",
    )
    let (double_failure, double_published) = format_input_probe(
      double_bound,
      directory + "/double-bound-out.docx",
    )
    guard double_failure is Some(double_message) else {
      fail("the outer generation must survive the doubled undo")
    }
    assert_true(
      double_message.contains("records revisions") ||
      double_message.contains("compatibility alternatives"),
      msg=double_message,
    )
    assert_false(double_published, msg="nothing may be published")
  })
}

///|
/// Round-10 fidelity: root branches obey ordered-choice semantics, and
/// a replacement across many paragraphs is read back in one pass.
async test "the preflight orders root branches and the replace readback batches" {
  with_docx_session_test_dir(directory => {
    // Two consecutive choices requiring the SAME namespace: any
    // consumer satisfying `x` selects the first, so a settings target
    // named only by the second is one nothing reaches, and it must not
    // fork the settings answer. (MCE in the package ROOT rels never
    // gets this far: identification refuses such a package outright.)
    let unreachable = repackaged_fixture(
      directory,
      "unreachable-branch",
      [],
      [
        (
          "word/_rels/document.xml.rels",
          "<Relationship Id=\"rId3\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/settings\" Target=\"settings.xml\"/>",
          "<mc:AlternateContent xmlns:mc=\"http://schemas.openxmlformats.org/markup-compatibility/2006\" xmlns:x=\"urn:example:x\">" +
          "<mc:Choice Requires=\"x\"/>" +
          "<mc:Choice Requires=\"x\"><Relationship Id=\"rId3a\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/settings\" Target=\"webSettings.xml\"/></mc:Choice>" +
          "<mc:Fallback><Relationship Id=\"rId3\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/settings\" Target=\"settings.xml\"/></mc:Fallback>" +
          "</mc:AlternateContent>",
        ),
      ],
      [],
    )
    let (unreachable_failure, unreachable_published) = format_input_probe(
      unreachable,
      directory + "/unreachable-branch-out.docx",
    )
    assert_true(
      unreachable_failure is None,
      msg="an unreachable branch forks nothing: \{unreachable_failure}",
    )
    assert_true(unreachable_published, msg="the edit publishes")
    // The replace readback across many paragraphs runs in one batch.
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
    assert_eq(replaced.report.replaced, 200)
  })
}

///|
/// Round-11 fidelity: reachability is one question asked of one
/// consumer, from the relationship that finds the part to the branch
/// inside it.
async test "the preflight conjoins conditions from relationship to setting" {
  with_docx_session_test_dir(directory => {
    // The settings part is reachable only under `w14`; the protection
    // inside it sits in the FALLBACK of a `Requires="w14"` choice. The
    // consumers who reach the part take the unprotected branch, and the
    // consumers who would take the fallback never see the part.
    let disjoint = repackaged_fixture(
      directory,
      "disjoint",
      [],
      [
        (
          "word/_rels/document.xml.rels",
          "<Relationship Id=\"rId3\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/settings\" Target=\"settings.xml\"/>",
          "<mc:AlternateContent xmlns:mc=\"http://schemas.openxmlformats.org/markup-compatibility/2006\" xmlns:w14x=\"http://schemas.microsoft.com/office/word/2010/wordml\">" +
          "<mc:Choice Requires=\"w14x\"><Relationship Id=\"rId3\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/settings\" Target=\"settings.xml\"/></mc:Choice>" +
          "<mc:Fallback/></mc:AlternateContent>",
        ),
        (
          "word/settings.xml",
          "</w:settings>",
          "<mc:AlternateContent><mc:Choice Requires=\"w14\"><w:zoom w:percent=\"90\"/></mc:Choice>" +
          "<mc:Fallback><w:trackRevisions/></mc:Fallback></mc:AlternateContent></w:settings>",
        ),
      ],
      [],
    )
    let (disjoint_failure, disjoint_published) = format_input_probe(
      disjoint,
      directory + "/disjoint-out.docx",
    )
    assert_true(
      disjoint_failure is None,
      msg="nobody both reaches the part and takes the fallback: \{disjoint_failure}",
    )
    assert_true(disjoint_published, msg="the edit publishes")
    // Passing over a MULTI-requirement choice negates by disjunction: an
    // inner choice with the same requirements as its outer one leaves
    // the inner fallback unreachable, and a tracking flag there decides
    // nothing.
    let nested_same = preflight_fixture(
      directory,
      "nested-same",
      "<mc:AlternateContent xmlns:mc=\"http://schemas.openxmlformats.org/markup-compatibility/2006\" xmlns:w15=\"http://schemas.microsoft.com/office/word/2012/wordml\">" +
      "<mc:Choice Requires=\"w14 w15\">" +
      "<mc:AlternateContent><mc:Choice Requires=\"w14 w15\"><w:zoom w:percent=\"80\"/></mc:Choice>" +
      "<mc:Fallback><w:trackRevisions/></mc:Fallback></mc:AlternateContent>" +
      "</mc:Choice><mc:Fallback/></mc:AlternateContent>",
      [],
    )
    let (nested_failure, nested_published) = format_input_probe(
      nested_same,
      directory + "/nested-same-out.docx",
    )
    assert_true(
      nested_failure is None,
      msg="the inner fallback is unreachable: \{nested_failure}",
    )
    assert_true(nested_published, msg="the edit publishes")
  })
}

///|
/// Round-12 fidelity: dialects are capabilities too, mutual exclusion
/// is not ambiguity, and satisfiability is exact at any width.
async test "the preflight models dialects and exclusion exactly" {
  with_docx_session_test_dir(directory => {
    // In a TRANSITIONAL part, a choice requiring the STRICT dialect is
    // not universal: a Transitional-only consumer takes the fallback,
    // and the enforced protection there is real for it.
    let strict_gate = preflight_fixture(
      directory,
      "strict-gate",
      "<mc:AlternateContent xmlns:mc=\"http://schemas.openxmlformats.org/markup-compatibility/2006\" xmlns:ws=\"http://purl.oclc.org/ooxml/wordprocessingml/main\">" +
      "<mc:Choice Requires=\"ws\"><w:documentProtection w:edit=\"readOnly\" w:enforcement=\"0\"/></mc:Choice>" +
      "<mc:Fallback><w:documentProtection w:edit=\"readOnly\" w:enforcement=\"1\"/></mc:Fallback>" +
      "</mc:AlternateContent>",
      [],
    )
    let (strict_failure, strict_published) = format_input_probe(
      strict_gate,
      directory + "/strict-gate-out.docx",
    )
    guard strict_failure is Some(strict_message) else {
      fail("a Transitional-only consumer meets the enforced fallback")
    }
    assert_true(
      strict_message.contains("editing protection") ||
      strict_message.contains("compatibility alternatives"),
      msg=strict_message,
    )
    assert_false(strict_published, msg="nothing may be published")
    // A choice's settings part and its fallback's are seen by DISJOINT
    // consumers: two unprotected parts, each judged alone, refuse
    // nothing.
    let exclusive = repackaged_fixture(
      directory,
      "exclusive",
      [],
      [
        (
          "[Content_Types].xml", "<Override PartName=\"/word/settings.xml\"", "<Override PartName=\"/word/settings-b.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.settings+xml\"/><Override PartName=\"/word/settings.xml\"",
        ),
        (
          "word/_rels/document.xml.rels",
          "<Relationship Id=\"rId3\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/settings\" Target=\"settings.xml\"/>",
          "<mc:AlternateContent xmlns:mc=\"http://schemas.openxmlformats.org/markup-compatibility/2006\" xmlns:x=\"urn:example:x\">" +
          "<mc:Choice Requires=\"x\"><Relationship Id=\"rId3\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/settings\" Target=\"settings.xml\"/></mc:Choice>" +
          "<mc:Fallback><Relationship Id=\"rId3b\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/settings\" Target=\"settings-b.xml\"/></mc:Fallback>" +
          "</mc:AlternateContent>",
        ),
      ],
      [
        (
          "word/settings-b.xml", "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><w:settings xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:zoom w:percent=\"110\"/></w:settings>",
        ),
      ],
    )
    let (exclusive_failure, exclusive_published) = format_input_probe(
      exclusive,
      directory + "/exclusive-out.docx",
    )
    assert_true(
      exclusive_failure is None,
      msg="mutually exclusive parts are not a fork: \{exclusive_failure}",
    )
    assert_true(exclusive_published, msg="the edit publishes")
    // And a TRACKED part behind the fallback still refuses: exclusion
    // narrows who sees it, not whether it counts.
    let exclusive_tracked = repackaged_fixture(
      directory,
      "exclusive-tracked",
      [],
      [
        (
          "[Content_Types].xml", "<Override PartName=\"/word/settings.xml\"", "<Override PartName=\"/word/settings-b.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.settings+xml\"/><Override PartName=\"/word/settings.xml\"",
        ),
        (
          "word/_rels/document.xml.rels",
          "<Relationship Id=\"rId3\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/settings\" Target=\"settings.xml\"/>",
          "<mc:AlternateContent xmlns:mc=\"http://schemas.openxmlformats.org/markup-compatibility/2006\" xmlns:x=\"urn:example:x\">" +
          "<mc:Choice Requires=\"x\"><Relationship Id=\"rId3\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/settings\" Target=\"settings.xml\"/></mc:Choice>" +
          "<mc:Fallback><Relationship Id=\"rId3b\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/settings\" Target=\"settings-b.xml\"/></mc:Fallback>" +
          "</mc:AlternateContent>",
        ),
      ],
      [
        (
          "word/settings-b.xml", "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><w:settings xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:trackRevisions/></w:settings>",
        ),
      ],
    )
    let (tracked_failure, tracked_published) = format_input_probe(
      exclusive_tracked,
      directory + "/exclusive-tracked-out.docx",
    )
    guard tracked_failure is Some(tracked_message) else {
      fail("the consumers who see the tracked part are real")
    }
    assert_true(
      tracked_message.contains("records revisions"),
      msg=tracked_message,
    )
    assert_false(tracked_published, msg="nothing may be published")
    // Width does not defeat exactness: several passed pair-choices and a
    // repeated pair leave the repeat's sibling unreachable, however many
    // clauses are in scope.
    let wide = preflight_fixture(
      directory,
      "wide",
      "<mc:AlternateContent xmlns:mc=\"http://schemas.openxmlformats.org/markup-compatibility/2006\" " +
      "xmlns:na=\"urn:x:a\" xmlns:nb=\"urn:x:b\" xmlns:nc=\"urn:x:c\" xmlns:nd=\"urn:x:d\" " +
      "xmlns:ne=\"urn:x:e\" xmlns:nf=\"urn:x:f\" xmlns:ng=\"urn:x:g\" xmlns:nh=\"urn:x:h\" " +
      "xmlns:ni=\"urn:x:i\" xmlns:nj=\"urn:x:j\">" +
      "<mc:Choice Requires=\"na nb\"/><mc:Choice Requires=\"nc nd\"/>" +
      "<mc:Choice Requires=\"ne nf\"/><mc:Choice Requires=\"ng nh\"/>" +
      "<mc:Choice Requires=\"ni nj\"/>" +
      "<mc:Choice Requires=\"ni nj\"><w:trackRevisions/></mc:Choice>" +
      "<mc:Fallback/></mc:AlternateContent>",
      [],
    )
    let (wide_failure, wide_published) = format_input_probe(
      wide,
      directory + "/wide-out.docx",
    )
    assert_true(
      wide_failure is None,
      msg="the repeated pair's sibling is unreachable at any width: \{wide_failure}",
    )
    assert_true(wide_published, msg="the edit publishes")
  })
}

///|
/// Round-13 fidelity: many paths to one part stay EXACT — seventeen
/// ordered choices to settings A above a fallback to settings B give
/// every consumer exactly one part, and no width of paths turns that
/// into a fork.
async test "the preflight keeps many-path reachability exact" {
  with_docx_session_test_dir(directory => {
    let ns_decls = StringBuilder()
    let choices = StringBuilder()
    for index in 0..<17 {
      ns_decls.write_string(" xmlns:n\{index}=\"urn:x:\{index}\"")
      choices.write_string(
        "<mc:Choice Requires=\"n\{index}\"><Relationship Id=\"rId3\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/settings\" Target=\"settings.xml\"/></mc:Choice>",
      )
    }
    let many_paths = repackaged_fixture(
      directory,
      "many-paths",
      [],
      [
        (
          "[Content_Types].xml", "<Override PartName=\"/word/settings.xml\"", "<Override PartName=\"/word/settings-b.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.settings+xml\"/><Override PartName=\"/word/settings.xml\"",
        ),
        (
          "word/_rels/document.xml.rels",
          "<Relationship Id=\"rId3\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/settings\" Target=\"settings.xml\"/>",
          "<mc:AlternateContent xmlns:mc=\"http://schemas.openxmlformats.org/markup-compatibility/2006\"" +
          ns_decls.to_string() +
          ">" +
          choices.to_string() +
          "<mc:Fallback><Relationship Id=\"rId3b\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/settings\" Target=\"settings-b.xml\"/></mc:Fallback>" +
          "</mc:AlternateContent>",
        ),
      ],
      [
        (
          "word/settings-b.xml", "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><w:settings xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:zoom w:percent=\"110\"/></w:settings>",
        ),
      ],
    )
    let (failure, published) = format_input_probe(
      many_paths,
      directory + "/many-paths-out.docx",
    )
    assert_true(
      failure is None,
      msg="seventeen exclusive paths are not a fork: \{failure}",
    )
    assert_true(published, msg="the edit publishes")
  })
}

///|
/// Round-14 fidelity: clause logic is SET logic, and the path bound
/// cannot depend on declaration order.
async test "the preflight reasons about clauses as sets" {
  with_docx_session_test_dir(directory => {
    // Two paths to one settings part whose clauses differ only once the
    // prefixes are RESOLVED: one passed choice requires w14 twice (two
    // prefixes, one namespace), the other requires w14 and x. The
    // consumers who support w14 but not x reach the part through the
    // second path and see the protection its w14 branch carries.
    let resolved = repackaged_fixture(
      directory,
      "resolved-clauses",
      [],
      [
        (
          "word/_rels/document.xml.rels",
          "<Relationship Id=\"rId3\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/settings\" Target=\"settings.xml\"/>",
          "<mc:AlternateContent xmlns:mc=\"http://schemas.openxmlformats.org/markup-compatibility/2006\" xmlns:wa=\"http://schemas.microsoft.com/office/word/2010/wordml\" xmlns:wb=\"http://schemas.microsoft.com/office/word/2010/wordml\">" +
          "<mc:Choice Requires=\"wa wb\"/>" +
          "<mc:Fallback><Relationship Id=\"rId3\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/settings\" Target=\"settings.xml\"/></mc:Fallback>" +
          "</mc:AlternateContent>" +
          "<mc:AlternateContent xmlns:mc=\"http://schemas.openxmlformats.org/markup-compatibility/2006\" xmlns:wc=\"http://schemas.microsoft.com/office/word/2010/wordml\" xmlns:x=\"urn:example:x\">" +
          "<mc:Choice Requires=\"wc x\"/>" +
          "<mc:Fallback><Relationship Id=\"rId3b\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/settings\" Target=\"settings.xml\"/></mc:Fallback>" +
          "</mc:AlternateContent>",
        ),
        (
          "word/settings.xml", "</w:settings>", "<mc:AlternateContent xmlns:mc=\"http://schemas.openxmlformats.org/markup-compatibility/2006\"><mc:Choice Requires=\"w14\"><w:documentProtection w:edit=\"readOnly\" w:enforcement=\"1\"/></mc:Choice><mc:Fallback/></mc:AlternateContent></w:settings>",
        ),
      ],
      [],
    )
    let (resolved_failure, resolved_published) = format_input_probe(
      resolved,
      directory + "/resolved-clauses-out.docx",
    )
    guard resolved_failure is Some(resolved_message) else {
      fail("the w14-but-not-x consumer sees the protection")
    }
    assert_true(
      resolved_message.contains("editing protection") ||
      resolved_message.contains("compatibility alternatives"),
      msg=resolved_message,
    )
    assert_false(resolved_published, msg="nothing may be published")
    // Sixty-four conditional paths followed by one UNCONDITIONAL path
    // to the same part: the weaker newcomer retires them all, so the
    // bound cannot depend on the order the paths were declared in.
    let ns_decls = StringBuilder()
    let alternates = StringBuilder()
    for index in 0..<64 {
      ns_decls.write_string(" xmlns:m\{index}=\"urn:m:\{index}\"")
      alternates.write_string(
        "<mc:AlternateContent xmlns:mc=\"http://schemas.openxmlformats.org/markup-compatibility/2006\">" +
        "<mc:Choice Requires=\"m\{index}\"><Relationship Id=\"rIdc\{index}\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/settings\" Target=\"settings.xml\"/></mc:Choice>" +
        "<mc:Fallback/></mc:AlternateContent>",
      )
    }
    let ordered = repackaged_fixture(
      directory,
      "ordered-bound",
      [],
      [
        (
          "word/_rels/document.xml.rels",
          "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">",
          "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"" +
          ns_decls.to_string() +
          ">" +
          alternates.to_string(),
        ),
      ],
      [],
    )
    let (ordered_failure, ordered_published) = format_input_probe(
      ordered,
      directory + "/ordered-bound-out.docx",
    )
    assert_true(
      ordered_failure is None,
      msg="the unconditional path retires the bounded ones: \{ordered_failure}",
    )
    assert_true(ordered_published, msg="the edit publishes")
  })
}

///|
/// Round-15 fidelity: promotion reaches roots, descent carries the
/// wrapper's own condition, and normalization keeps the antichain small.
async test "the preflight promotes roots and normalizes clauses" {
  with_docx_session_test_dir(directory => {
    // A rels part whose effective root arrives through a PROMOTED
    // wrapper: the consumers who find `x` ignorable read the promoted
    // Relationships, whose settings part enforces protection.
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
      fail("the promoted root's settings are real for its consumers")
    }
    assert_true(
      promoted_message.contains("editing protection") ||
      promoted_message.contains("could not be read") ||
      promoted_message.contains("settings"),
      msg=promoted_message,
    )
    assert_false(promoted_published, msg="nothing may be published")
    // A protection under a wrapper promoted only when `x` is
    // UNSUPPORTED, inside a part reachable only when `x` IS supported:
    // no consumer sees both, and the edit publishes.
    let contradictory_wrap = repackaged_fixture(
      directory,
      "contradictory-wrap",
      [],
      [
        (
          "word/_rels/document.xml.rels",
          "<Relationship Id=\"rId3\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/settings\" Target=\"settings.xml\"/>",
          "<mc:AlternateContent xmlns:mc=\"http://schemas.openxmlformats.org/markup-compatibility/2006\" xmlns:x=\"urn:example:x\">" +
          "<mc:Choice Requires=\"x\"><Relationship Id=\"rId3\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/settings\" Target=\"settings.xml\"/></mc:Choice>" +
          "<mc:Fallback/></mc:AlternateContent>",
        ),
        (
          "word/settings.xml", "mc:Ignorable=\"w14\"", "mc:Ignorable=\"w14 x14\" mc:ProcessContent=\"x14:wrap\" xmlns:x14=\"urn:example:x\"",
        ),
        (
          "word/settings.xml", "</w:settings>", "<x14:wrap xmlns:x14=\"urn:example:x\"><w:trackRevisions/></x14:wrap></w:settings>",
        ),
      ],
      [],
    )
    let (wrap_failure, wrap_published) = format_input_probe(
      contradictory_wrap,
      directory + "/contradictory-wrap-out.docx",
    )
    assert_true(
      wrap_failure is None,
      msg="no consumer both reaches the part and promotes the wrapper: \{wrap_failure}",
    )
    assert_true(wrap_published, msg="the edit publishes")
  })
}

///|
/// Round-16 fidelity: `MustUnderstand` is a positive requirement — a
/// consumer that processes the branch supports what it names, so nobody
/// both reaches the part through it and promotes an ignorable wrapper
/// of that namespace inside it.
async test "the preflight reads MustUnderstand as a requirement" {
  with_docx_session_test_dir(directory => {
    let understood = repackaged_fixture(
      directory,
      "must-understand",
      [],
      [
        (
          "word/_rels/document.xml.rels",
          "<Relationship Id=\"rId3\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/settings\" Target=\"settings.xml\"/>",
          "<mc:AlternateContent xmlns:mc=\"http://schemas.openxmlformats.org/markup-compatibility/2006\" xmlns:y=\"urn:example:y\" xmlns:x=\"urn:example:x\">" +
          "<mc:Choice Requires=\"y\" mc:MustUnderstand=\"x\"><Relationship Id=\"rId3\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/settings\" Target=\"settings.xml\"/></mc:Choice>" +
          "<mc:Fallback/></mc:AlternateContent>",
        ),
        (
          "word/settings.xml", "mc:Ignorable=\"w14\"", "mc:Ignorable=\"w14 x14\" mc:ProcessContent=\"x14:wrap\" xmlns:x14=\"urn:example:x\"",
        ),
        (
          "word/settings.xml", "</w:settings>", "<x14:wrap xmlns:x14=\"urn:example:x\"><w:trackRevisions/></x14:wrap></w:settings>",
        ),
      ],
      [],
    )
    let (failure, published) = format_input_probe(
      understood,
      directory + "/must-understand-out.docx",
    )
    assert_true(
      failure is None,
      msg="reaching the part means supporting x, and promotion means not: \{failure}",
    )
    assert_true(published, msg="the edit publishes")
  })
}

///|
/// Round-17 fidelity: reading a part means supporting its dialect, so a
/// protection behind a path that DEMANDED the dialect unsupported is
/// nobody's protection.
async test "the preflight requires the dialect of what it reads" {
  with_docx_session_test_dir(directory => {
    let dialect_gap = repackaged_fixture(
      directory,
      "dialect-gap",
      [],
      [
        (
          "word/_rels/document.xml.rels",
          "<Relationship Id=\"rId3\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/settings\" Target=\"settings.xml\"/>",
          "<mc:AlternateContent xmlns:mc=\"http://schemas.openxmlformats.org/markup-compatibility/2006\" xmlns:wt=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\">" +
          "<mc:Choice Requires=\"wt\"/>" +
          "<mc:Fallback><Relationship Id=\"rId3\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/settings\" Target=\"settings.xml\"/></mc:Fallback>" +
          "</mc:AlternateContent>",
        ),
        (
          "word/settings.xml", "</w:settings>", "<w:documentProtection w:edit=\"readOnly\" w:enforcement=\"1\"/></w:settings>",
        ),
      ],
      [],
    )
    let (failure, published) = format_input_probe(
      dialect_gap,
      directory + "/dialect-gap-out.docx",
    )
    assert_true(
      failure is None,
      msg="whoever reaches the part cannot read it, and whoever reads it never reaches it: \{failure}",
    )
    assert_true(published, msg="the edit publishes")
  })
}

///|
/// Round-18 fidelity: a part this toolkit's profile never reaches is
/// analyzed structurally rather than demanded readable, and each
/// exclusive part is judged for its own consumers.
async test "the preflight analyzes unreached parts without demanding them" {
  with_docx_session_test_dir(directory => {
    // The w14 choice's settings part declares MustUnderstand="w14":
    // every consumer reaching it satisfies that, and this toolkit —
    // which never reaches it — must not refuse over a projection nobody
    // asked it for. The fallback part is ordinary and unprotected.
    let unreachable_must = repackaged_fixture(
      directory,
      "unreached-must",
      [],
      [
        (
          "[Content_Types].xml", "<Override PartName=\"/word/settings.xml\"", "<Override PartName=\"/word/settings-w14.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.settings+xml\"/><Override PartName=\"/word/settings.xml\"",
        ),
        (
          "word/_rels/document.xml.rels",
          "<Relationship Id=\"rId3\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/settings\" Target=\"settings.xml\"/>",
          "<mc:AlternateContent xmlns:mc=\"http://schemas.openxmlformats.org/markup-compatibility/2006\" xmlns:w14a=\"http://schemas.microsoft.com/office/word/2010/wordml\">" +
          "<mc:Choice Requires=\"w14a\"><Relationship Id=\"rId3w\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/settings\" Target=\"settings-w14.xml\"/></mc:Choice>" +
          "<mc:Fallback><Relationship Id=\"rId3\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/settings\" Target=\"settings.xml\"/></mc:Fallback>" +
          "</mc:AlternateContent>",
        ),
      ],
      [
        (
          "word/settings-w14.xml", "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><w:settings xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\" xmlns:mc=\"http://schemas.openxmlformats.org/markup-compatibility/2006\" xmlns:w14=\"http://schemas.microsoft.com/office/word/2010/wordml\" mc:MustUnderstand=\"w14\"><w:zoom w:percent=\"100\"/></w:settings>",
        ),
      ],
    )
    let (must_failure, must_published) = format_input_probe(
      unreachable_must,
      directory + "/unreached-must-out.docx",
    )
    assert_true(
      must_failure is None,
      msg="a part our profile never reaches is not ours to demand: \{must_failure}",
    )
    assert_true(must_published, msg="the edit publishes")
    // And a TRACKED part behind the same unreachable path still
    // refuses: structural analysis reads it even though our projection
    // never would.
    let tracked_must = repackaged_fixture(
      directory,
      "unreached-tracked",
      [],
      [
        (
          "[Content_Types].xml", "<Override PartName=\"/word/settings.xml\"", "<Override PartName=\"/word/settings-w14.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.settings+xml\"/><Override PartName=\"/word/settings.xml\"",
        ),
        (
          "word/_rels/document.xml.rels",
          "<Relationship Id=\"rId3\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/settings\" Target=\"settings.xml\"/>",
          "<mc:AlternateContent xmlns:mc=\"http://schemas.openxmlformats.org/markup-compatibility/2006\" xmlns:w14a=\"http://schemas.microsoft.com/office/word/2010/wordml\">" +
          "<mc:Choice Requires=\"w14a\"><Relationship Id=\"rId3w\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/settings\" Target=\"settings-w14.xml\"/></mc:Choice>" +
          "<mc:Fallback><Relationship Id=\"rId3\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/settings\" Target=\"settings.xml\"/></mc:Fallback>" +
          "</mc:AlternateContent>",
        ),
      ],
      [
        (
          "word/settings-w14.xml", "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><w:settings xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:trackRevisions/></w:settings>",
        ),
      ],
    )
    let (tracked_failure, tracked_published) = format_input_probe(
      tracked_must,
      directory + "/unreached-tracked-out.docx",
    )
    guard tracked_failure is Some(tracked_message) else {
      fail("the consumers who reach the tracked part are real")
    }
    // The flag lives behind a path this toolkit cannot take, so the
    // honest voice is the unresolved-alternatives refusal.
    assert_true(
      tracked_message.contains("records revisions") ||
      tracked_message.contains("compatibility alternatives"),
      msg=tracked_message,
    )
    assert_false(tracked_published, msg="nothing may be published")
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
          "<w:settings xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:trackRevisions/></w:settings>" +
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
    // Whichever voice speaks — the single-root rule publishing, or the
    // MCE reader refusing an alternate-rooted part outright — the twin
    // roots never refuse AS TRACKING.
    match twin_failure {
      Some(message) => {
        assert_true(message.contains("could not be read"), msg=message)
        assert_false(twin_published, msg="nothing published on refusal")
      }
      None => assert_true(twin_published, msg="the edit publishes")
    }
  })
}

///|
/// Round-20 fidelity: ignorable siblings do not hide a root, and a
/// repeated prefix is one requirement.
async test "the preflight drops ignorable siblings and dedupes requirements" {
  with_docx_session_test_dir(directory => {
    // The choice holds ignorable noise BESIDE a tracked settings root:
    // consumers of the choice who drop the noise read exactly that
    // tracked root, so the tracking is real and refuses.
    let noisy = repackaged_fixture(
      directory,
      "noisy-branch",
      [],
      [
        (
          "word/settings.xml",
          "<w:settings",
          "<mc0:AlternateContent xmlns:mc0=\"http://schemas.openxmlformats.org/markup-compatibility/2006\" xmlns:y=\"urn:example:y\">" +
          "<mc0:Choice Requires=\"y\" xmlns:x=\"urn:example:x\" mc0:Ignorable=\"x\">" +
          "<x:noise/>" +
          "<w:settings xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:trackRevisions/></w:settings>" +
          "</mc0:Choice><mc0:Fallback><w:settings",
        ),
        (
          "word/settings.xml", "</w:settings>", "</w:settings></mc0:Fallback></mc0:AlternateContent>",
        ),
      ],
      [],
    )
    let (noisy_failure, noisy_published) = format_input_probe(
      noisy,
      directory + "/noisy-branch-out.docx",
    )
    guard noisy_failure is Some(noisy_message) else {
      fail("the consumers who drop the noise read the tracked root")
    }
    assert_true(
      noisy_message.contains("records revisions") ||
      noisy_message.contains("compatibility alternatives") ||
      noisy_message.contains("could not be read"),
      msg=noisy_message,
    )
    assert_false(noisy_published, msg="nothing may be published")
    // One prefix repeated sixty-five times is ONE requirement, not a
    // complexity refusal.
    let repeats = StringBuilder()
    for index in 0..<65 {
      if index > 0 {
        repeats.write_string(" ")
      }
      repeats.write_string("w14")
    }
    let repeated = preflight_fixture(
      directory,
      "repeated-requires",
      "<mc:AlternateContent xmlns:mc=\"http://schemas.openxmlformats.org/markup-compatibility/2006\">" +
      "<mc:Choice Requires=\"" +
      repeats.to_string() +
      "\"><w:zoom w:percent=\"90\"/></mc:Choice>" +
      "<mc:Fallback/></mc:AlternateContent>",
      [],
    )
    let (repeated_failure, repeated_published) = format_input_probe(
      repeated,
      directory + "/repeated-requires-out.docx",
    )
    assert_true(
      repeated_failure is None,
      msg="a repeated prefix is one requirement: \{repeated_failure}",
    )
    assert_true(repeated_published, msg="the edit publishes")
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
