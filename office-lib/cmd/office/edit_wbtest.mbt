///|
fn edit_sample_report() -> @office_docx.DocxEditReport {
  {
    ops_applied: 1,
    replacements: 1,
    revisions_resolved: 0,
    results: [
      {
        op: "replace_text",
        find: "draft",
        replace: "final",
        occurrence: None,
        at: None,
        expect: None,
        text: None,
        resolved_at: None,
        selector_id: None,
        selector_author: None,
        selector_type: None,
        selector_all: false,
        matched: 1,
        replacements: 1,
        resolved: 0,
      },
    ],
    unmatched: [],
    unmatched_total: 0,
    unsupported: [],
    unsupported_total: 0,
    conflicts: [],
    conflicts_total: 0,
    locations: [{ location: "/docx/body/p[1]", detail: "draft", }],
    locations_truncated: false,
    stories_scanned: ["/body"],
    changed: true,
  }
}

///|
/// The capability registry is the contract: the result record may emit
/// only declared keys, and must emit every required one.
test "edit result record declares every field it emits" {
  guard @lib.find_capability_command("edit") is Some(command) else {
    fail("expected the edit capability")
  }
  let declared = command.outputs.map(field => field.name)
  let record = edit_report_json(
    schema="docx.edit/1",
    "in.docx",
    "script.json",
    "out.docx",
    edit_sample_report(),
    transaction=Json::object({}),
  )
  guard record is Object(fields) else { fail("expected an object record") }
  for name, _ in fields {
    if !declared.contains(name) {
      fail("undeclared output: " + name)
    }
  }
  for field in command.outputs {
    if field.required && !fields.contains(field.name) {
      fail("missing required output: " + field.name)
    }
  }
  assert_eq(
    fields.get("schema"),
    Some(Json::string(@office_docx.SCHEMA_DOCX_EDIT_RESULT)),
  )
  assert_eq(fields.get("format"), Some(Json::string("docx")))
  // an op replacing every occurrence reports a null occurrence
  guard fields.get("results") is Some(Array([Object(entry)])) else {
    fail("expected one result entry")
  }
  assert_eq(entry.get("occurrence"), Some(Json::null()))
  // a replace_text entry carries the revision half of the fixed key set,
  // nulled: an agent reads results[] without branching on op first
  assert_eq(entry.get("selector"), Some(Json::null()))
  assert_eq(entry.get("resolved"), Some(Json::number(0.0)))
}

///|
/// The mirror of the above for a revision op: the same fixed key set, with
/// the replace_text half nulled and the selector spelled out.
test "revision result entries publish a selector and null the needle" {
  guard @lib.find_capability_command("edit") is Some(command) else {
    fail("expected the edit capability")
  }
  let declared = command.outputs.map(field => field.name)
  let sample : @office_docx.DocxEditReport = {
    ops_applied: 1,
    replacements: 0,
    revisions_resolved: 1,
    results: [
      {
        op: "accept_revision",
        find: "",
        replace: "",
        occurrence: None,
        at: None,
        expect: None,
        text: None,
        resolved_at: None,
        selector_id: None,
        selector_author: Some("Reviewer"),
        selector_type: Some("ins"),
        selector_all: false,
        matched: 1,
        replacements: 0,
        resolved: 1,
      },
    ],
    unmatched: [],
    unmatched_total: 0,
    unsupported: [],
    unsupported_total: 0,
    conflicts: [],
    conflicts_total: 0,
    locations: [
      { location: "/docx/body/p[1]", detail: "accept w:ins id=\"2\"", },
    ],
    locations_truncated: false,
    stories_scanned: ["/body"],
    changed: true,
  }
  let record = edit_report_json(
    schema="docx.edit/1",
    "in.docx",
    "script.json",
    "out.docx",
    sample,
    transaction=Json::object({}),
  )
  guard record is Object(fields) else { fail("expected an object record") }
  for name, _ in fields {
    if !declared.contains(name) {
      fail("undeclared output: " + name)
    }
  }
  assert_eq(fields.get("revisions_resolved"), Some(Json::number(1.0)))
  guard fields.get("results") is Some(Array([Object(entry)])) else {
    fail("expected one result entry")
  }
  assert_eq(entry.get("find"), Some(Json::null()))
  assert_eq(entry.get("replace"), Some(Json::null()))
  assert_eq(entry.get("occurrence"), Some(Json::null()))
  assert_eq(entry.get("resolved"), Some(Json::number(1.0)))
  assert_eq(
    entry.get("selector"),
    Some(
      Json::object({
        "id": Json::null(),
        "author": Json::string("Reviewer"),
        "type": Json::string("ins"),
        "all": Json::boolean(false),
      }),
    ),
  )
}

///|
/// The generated help is truthful about the surface: a separate output,
/// literal matching, and the strictness escape hatch.
test "edit help publishes its bounded mutation controls" {
  let help = edit_command().render_help()
  for
    expected in [
      "--out", "--dry-run", "--overwrite", "--allow-unmatched", "docx.edit/1",
    ] {
    assert_true(help.contains(expected))
  }
  assert_false(help.to_lower().contains("regex"))
  guard @lib.find_capability_command("edit") is Some(command) else {
    fail("expected the edit capability")
  }
  assert_eq(command.formats, ["docx"])
  let rendered = capability_help_text(command)
  assert_true(rendered.contains("LITERAL"))
  assert_true(rendered.contains("occurrence: N"))
}
