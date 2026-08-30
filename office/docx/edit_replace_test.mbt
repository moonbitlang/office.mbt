///|
/// Builds a one-paragraph DOCX whose body run markup is exactly
/// `runs`, so every test controls how Word split the text.
async fn edit_fixture(
  directory : String,
  name : String,
  runs : String,
) -> String {
  let source_bytes = @afs.read_file(
    "../docx2html/tests/cram/fixtures/single-paragraph.docx",
  ).binary()
  let archive = @zip.read(source_bytes)
  let rebuilt = @zip.Archive::new()
  for entry in archive.entries() {
    let entry_name = entry.name()
    guard archive.get(entry_name) is Some(payload) else { continue }
    let replaced = if entry_name == "word/document.xml" {
      let text = @utf8.decode(payload)
      @utf8.encode(
        text.replace(
          old="<w:r><w:t>Walking on imported air</w:t></w:r>",
          new=runs,
        ),
      )
    } else {
      payload.to_owned()
    }
    rebuilt.add(entry_name, replaced)
  }
  let path = directory + "/" + name
  @afs.write_file(
    path,
    @zip.write(rebuilt),
    create_mode=CreateNew,
    permission=0o600,
  )
  path
}

///|
fn edit_script(ops : Array[Json]) -> @docx.DocxEditScript raise {
  @docx.parse_docx_edit_script(
    Json::object({
      "schema": Json::string(@docx.SCHEMA_DOCX_EDIT),
      "ops": Json::array(ops),
    }).stringify(),
  )
}

///|
fn replace_op(find : String, replace : String, occurrence? : Int) -> Json {
  let params : Map[String, Json] = {
    "find": Json::string(find),
    "replace": Json::string(replace),
  }
  match occurrence {
    Some(ordinal) => params["occurrence"] = Json::number(ordinal.to_double())
    None => ()
  }
  Json::object({
    "op": Json::string("replace_text"),
    "params": Json::object(params),
  })
}

///|
async fn published_document(path : String) -> String {
  let archive = @zip.read(@afs.read_file(path).binary())
  guard archive.get("word/document.xml") is Some(document) else {
    fail("published package has no main document part")
  }
  @utf8.decode(document)
}

///|
/// A match wholly inside one run is rewritten in place, the surrounding
/// text survives, and the published package passes the transaction's own
/// strict DOCX validator.
async test "docx edit replaces a match inside one run" {
  @async.with_task_group() <| group => {
    let directory = @afs.tmpdir(prefix="office-docx-edit-single-")
    group.add_defer() <| () => {
      @async.protect_from_cancel(() => @afs.rmdir(directory, recursive=true))
    }
    let input = edit_fixture(
      directory, "in.docx", "<w:r><w:t>The draft report is a draft</w:t></w:r>",
    )
    let output = directory + "/out.docx"
    let result = @docx.transact_docx_edit(
      @transaction.transaction_options(input, output_path=output),
      edit_script([replace_op("draft", "final")]),
      allow_unmatched=false,
    )
    assert_eq(result.report.replacements, 2)
    assert_eq(result.report.results[0].matched, 2)
    assert_eq(result.report.results[0].replacements, 2)
    assert_eq(result.report.unsupported_total, 0)
    assert_eq(result.report.unmatched_total, 0)
    assert_true(result.report.changed)
    assert_eq(result.report.stories_scanned, ["/body"])
    assert_true(
      result.transaction.preservation.changed.contains("word/document.xml"),
    )
    assert_true(
      published_document(output).contains("The final report is a final"),
    )
  }
}

///|
/// The whole point: Word splits text freely, so a match that starts in
/// one `<w:r>` and ends in another is still one replacement. The value
/// inherits the STARTING run's formatting, and the bold `rPr` of that
/// run survives untouched.
async test "docx edit replaces a match spanning run boundaries" {
  @async.with_task_group() <| group => {
    let directory = @afs.tmpdir(prefix="office-docx-edit-split-")
    group.add_defer() <| () => {
      @async.protect_from_cancel(() => @afs.rmdir(directory, recursive=true))
    }
    let input = edit_fixture(
      directory,
      "in.docx",
      "<w:r><w:rPr><w:b/></w:rPr><w:t>The dr</w:t></w:r>" +
      "<w:r><w:rPr><w:b/></w:rPr><w:t>af</w:t></w:r>" +
      "<w:r><w:rPr><w:b/></w:rPr><w:t>t report</w:t></w:r>",
    )
    let output = directory + "/out.docx"
    let result = @docx.transact_docx_edit(
      @transaction.transaction_options(input, output_path=output),
      edit_script([replace_op("draft", "final")]),
      allow_unmatched=false,
    )
    assert_eq(result.report.replacements, 1)
    assert_eq(result.report.unsupported_total, 0)
    let document = published_document(output)
    // the replacement lands whole in the run the match started in
    assert_true(
      document.contains("<w:t xml:space=\"preserve\">The final</w:t>"),
    )
    assert_true(document.contains("<w:t xml:space=\"preserve\"> report</w:t>"))
    // formatting preserved: the surviving runs keep their bold rPr
    assert_true(document.contains("<w:rPr><w:b/></w:rPr>"))
    assert_eq(result.report.locations[0].location, "/docx/body/p[1]")
  }
}

///|
/// `occurrence` selects exactly one match in document order; every other
/// occurrence is left byte-for-byte alone.
async test "docx edit occurrence replaces only the nth match" {
  @async.with_task_group() <| group => {
    let directory = @afs.tmpdir(prefix="office-docx-edit-nth-")
    group.add_defer() <| () => {
      @async.protect_from_cancel(() => @afs.rmdir(directory, recursive=true))
    }
    let input = edit_fixture(
      directory, "in.docx", "<w:r><w:t>Q3 then Q3 then Q3</w:t></w:r>",
    )
    let output = directory + "/out.docx"
    let result = @docx.transact_docx_edit(
      @transaction.transaction_options(input, output_path=output),
      edit_script([replace_op("Q3", "Q4", occurrence=2)]),
      allow_unmatched=false,
    )
    assert_eq(result.report.replacements, 1)
    assert_eq(result.report.results[0].matched, 3)
    assert_eq(result.report.results[0].replacements, 1)
    assert_true(published_document(output).contains("Q3 then Q4 then Q3"))
  }
}

///|
/// An op that finds nothing refuses by default: a typo'd needle can
/// never silently publish an unchanged copy.
async test "docx edit refuses an unmatched find" {
  @async.with_task_group() <| group => {
    let directory = @afs.tmpdir(prefix="office-docx-edit-miss-")
    group.add_defer() <| () => {
      @async.protect_from_cancel(() => @afs.rmdir(directory, recursive=true))
    }
    let input = edit_fixture(
      directory, "in.docx", "<w:r><w:t>The draft report</w:t></w:r>",
    )
    let output = directory + "/never.docx"
    try
      @docx.transact_docx_edit(
        @transaction.transaction_options(input, output_path=output),
        edit_script([replace_op("nowhere", "x")]),
        allow_unmatched=false,
      )
      |> ignore
    catch {
      @docx.DocxEditRefused(report) => {
        assert_eq(report.unmatched_total, 1)
        assert_eq(report.unmatched[0].location, "ops[0]")
        assert_eq(
          report.unmatched[0].detail,
          "\"nowhere\" occurs 0 time(s); 1 required",
        )
        assert_eq(report.replacements, 0)
      }
      _ => fail("expected the typed refusal")
    } noraise {
      _ => fail("an unmatched find must refuse")
    }
    if @afs.exists(output) {
      fail("refusal must not publish")
    }
  }
}

///|
/// With `allow_unmatched`, zero matches is a no-op: the transaction
/// reuses the exact input bytes, so the output is byte-identical.
async test "docx edit with allow_unmatched publishes byte-identical bytes" {
  @async.with_task_group() <| group => {
    let directory = @afs.tmpdir(prefix="office-docx-edit-noop-")
    group.add_defer() <| () => {
      @async.protect_from_cancel(() => @afs.rmdir(directory, recursive=true))
    }
    let input = edit_fixture(
      directory, "in.docx", "<w:r><w:t>The draft report</w:t></w:r>",
    )
    let output = directory + "/out.docx"
    let result = @docx.transact_docx_edit(
      @transaction.transaction_options(input, output_path=output),
      edit_script([replace_op("nowhere", "x")]),
      allow_unmatched=true,
    )
    assert_eq(result.report.replacements, 0)
    assert_false(result.report.changed)
    assert_eq(result.report.unmatched_total, 1)
    assert_eq(@afs.read_file(output).binary(), @afs.read_file(input).binary())
  }
}

///|
/// `--dry-run` runs the full edit and validation and publishes nothing;
/// the input is byte-identical afterwards.
async test "docx edit dry run leaves the input byte-identical" {
  @async.with_task_group() <| group => {
    let directory = @afs.tmpdir(prefix="office-docx-edit-dry-")
    group.add_defer() <| () => {
      @async.protect_from_cancel(() => @afs.rmdir(directory, recursive=true))
    }
    let input = edit_fixture(
      directory, "in.docx", "<w:r><w:t>The draft report</w:t></w:r>",
    )
    let before = @afs.read_file(input).binary()
    let output = directory + "/out.docx"
    let result = @docx.transact_docx_edit(
      @transaction.transaction_options(input, output_path=output, dry_run=true),
      edit_script([replace_op("draft", "final")]),
      allow_unmatched=false,
    )
    assert_eq(result.report.replacements, 1)
    assert_true(result.report.changed)
    assert_eq(@afs.read_file(input).binary(), before)
    if @afs.exists(output) {
      fail("a dry run must not publish")
    }
  }
}

///|
/// A match reaching into content the byte-span rewriter cannot own
/// refuses instead of mangling it: the run below mixes text with a
/// break, so its text is not independently rewritable.
async test "docx edit refuses a match over unrewritable content" {
  @async.with_task_group() <| group => {
    let directory = @afs.tmpdir(prefix="office-docx-edit-opaque-")
    group.add_defer() <| () => {
      @async.protect_from_cancel(() => @afs.rmdir(directory, recursive=true))
    }
    let input = edit_fixture(
      directory, "in.docx", "<w:r><w:t>The draft report</w:t><w:br/></w:r>",
    )
    let output = directory + "/never.docx"
    try
      @docx.transact_docx_edit(
        @transaction.transaction_options(input, output_path=output),
        edit_script([replace_op("draft", "final")]),
        allow_unmatched=false,
      )
      |> ignore
    catch {
      @docx.DocxEditRefused(report) => {
        assert_eq(report.unsupported_total, 1)
        assert_eq(report.unsupported[0].location, "/docx/body/p[1]")
        assert_eq(
          report.unsupported[0].detail,
          "a match overlaps content the edit cannot rewrite",
        )
        assert_eq(report.replacements, 0)
      }
      _ => fail("expected the typed refusal")
    } noraise {
      _ => fail("an unsafe match must refuse")
    }
    if @afs.exists(output) {
      fail("refusal must not publish")
    }
  }
}

///|
/// A match that starts outside a hyperlink and ends inside it has no
/// safe rewrite (the text would have to move into the link), so it
/// refuses with its own detail.
async test "docx edit refuses a match crossing a hyperlink boundary" {
  @async.with_task_group() <| group => {
    let directory = @afs.tmpdir(prefix="office-docx-edit-link-")
    group.add_defer() <| () => {
      @async.protect_from_cancel(() => @afs.rmdir(directory, recursive=true))
    }
    let input = edit_fixture(
      directory,
      "in.docx",
      "<w:r><w:t>The dr</w:t></w:r>" +
      "<w:hyperlink w:anchor=\"top\"><w:r><w:t>aft report</w:t></w:r></w:hyperlink>",
    )
    let output = directory + "/never.docx"
    try
      @docx.transact_docx_edit(
        @transaction.transaction_options(input, output_path=output),
        edit_script([replace_op("draft", "final")]),
        allow_unmatched=false,
      )
      |> ignore
    catch {
      @docx.DocxEditRefused(report) => {
        assert_eq(report.unsupported_total, 1)
        assert_eq(
          report.unsupported[0].detail,
          "a match crosses a hyperlink boundary",
        )
      }
      _ => fail("expected the typed refusal")
    } noraise {
      _ => fail("a hyperlink-crossing match must refuse")
    }
    if @afs.exists(output) {
      fail("refusal must not publish")
    }
  }
}

///|
/// Two ops matching the same text have no defined outcome, so the whole
/// transaction refuses rather than letting op order decide silently.
async test "docx edit refuses overlapping matches from two ops" {
  @async.with_task_group() <| group => {
    let directory = @afs.tmpdir(prefix="office-docx-edit-clash-")
    group.add_defer() <| () => {
      @async.protect_from_cancel(() => @afs.rmdir(directory, recursive=true))
    }
    let input = edit_fixture(directory, "in.docx", "<w:r><w:t>abcd</w:t></w:r>")
    let output = directory + "/never.docx"
    try
      @docx.transact_docx_edit(
        @transaction.transaction_options(input, output_path=output),
        edit_script([replace_op("abc", "X"), replace_op("bcd", "Y")]),
        allow_unmatched=false,
      )
      |> ignore
    catch {
      @docx.DocxEditRefused(report) => {
        assert_eq(report.conflicts_total, 1)
        assert_eq(report.conflicts[0].location, "/docx/body/p[1]")
        assert_eq(
          report.conflicts[0].detail,
          "matches for \"abc\" and \"bcd\" overlap",
        )
      }
      _ => fail("expected the typed refusal")
    } noraise {
      _ => fail("overlapping matches must refuse")
    }
    if @afs.exists(output) {
      fail("refusal must not publish")
    }
  }
}

///|
/// Two ops whose matches merely touch (no shared code unit) both apply.
async test "docx edit applies two adjacent non-overlapping ops" {
  @async.with_task_group() <| group => {
    let directory = @afs.tmpdir(prefix="office-docx-edit-pair-")
    group.add_defer() <| () => {
      @async.protect_from_cancel(() => @afs.rmdir(directory, recursive=true))
    }
    let input = edit_fixture(directory, "in.docx", "<w:r><w:t>abcd</w:t></w:r>")
    let output = directory + "/out.docx"
    let result = @docx.transact_docx_edit(
      @transaction.transaction_options(input, output_path=output),
      edit_script([replace_op("ab", "X"), replace_op("cd", "Y")]),
      allow_unmatched=false,
    )
    assert_eq(result.report.replacements, 2)
    assert_true(
      published_document(output).contains(
        "<w:t xml:space=\"preserve\">XY</w:t>",
      ),
    )
  }
}

///|
/// A needle present only in an out-of-scope story refuses: silently
/// leaving a match behind would be a fidelity lie.
async test "docx edit refuses a needle in an out-of-scope story" {
  @async.with_task_group() <| group => {
    let directory = @afs.tmpdir(prefix="office-docx-edit-scope-")
    group.add_defer() <| () => {
      @async.protect_from_cancel(() => @afs.rmdir(directory, recursive=true))
    }
    // the fixture's only "draft" lives in a comment body, never in the
    // body, header, or footer stories
    let input = directory + "/commented.docx"
    @afs.write_file(
      input,
      @afs.read_file("../docx2html/tests/cram/fixtures/commented.docx").binary(),
      create_mode=CreateNew,
      permission=0o600,
    )
    let output = directory + "/never.docx"
    try
      @docx.transact_docx_edit(
        @transaction.transaction_options(input, output_path=output),
        edit_script([replace_op("next draft", "next release")]),
        allow_unmatched=true,
      )
      |> ignore
    catch {
      @docx.DocxEditRefused(report) => {
        assert_eq(report.unsupported_total, 1)
        assert_eq(
          report.unsupported[0].detail,
          "matches in comments stories are not editable in v1",
        )
      }
      _ => fail("expected the typed refusal")
    } noraise {
      _ => fail("an out-of-scope match must refuse")
    }
    if @afs.exists(output) {
      fail("refusal must not publish")
    }
  }
}

///|
/// Parser contract: the schema, the operation vocabulary, unknown
/// members, and the needle grammar all fail loudly.
test "docx edit script parser is strict" {
  let valid = "{\"schema\":\"docx.edit/1\",\"ops\":[{\"op\":\"replace_text\",\"params\":{\"find\":\"a\",\"replace\":\"b\"}}]}"
  assert_eq(@docx.parse_docx_edit_script(valid).length(), 1)
  for
    case in [
      ("{", "edit script is not valid JSON"),
      ("[]", "edit script must be a JSON object"),
      (
        "{\"schema\":\"docx.edit/3\",\"ops\":[]}", "unsupported edit schema \"docx.edit/3\"",
      ),
      (
        "{\"schema\":\"docx.edit/1\",\"ops\":[],\"extra\":1}", "the edit script has unknown member \"extra\"",
      ),
      (
        "{\"schema\":\"docx.edit/1\",\"ops\":[]}", "edit script needs at least one operation",
      ),
      (
        "{\"schema\":\"docx.edit/1\",\"ops\":[{\"op\":\"delete_text\",\"params\":{}}]}",
        "unknown op \"delete_text\"",
      ),
      (
        "{\"schema\":\"docx.edit/1\",\"ops\":[{\"op\":\"replace_text\",\"params\":{\"find\":\"a\",\"replace\":\"b\",\"regex\":true}}]}",
        "ops[0].params has unknown member \"regex\"",
      ),
      (
        "{\"schema\":\"docx.edit/1\",\"ops\":[{\"op\":\"replace_text\",\"params\":{\"find\":\"\",\"replace\":\"b\"}}]}",
        "replace_text \"find\" must not be empty",
      ),
      (
        "{\"schema\":\"docx.edit/1\",\"ops\":[{\"op\":\"replace_text\",\"params\":{\"find\":\"a\\nb\",\"replace\":\"c\"}}]}",
        "replace_text \"find\" carries characters the run serializer cannot match or emit (control characters, line breaks, unpaired surrogates, or XML non-characters)",
      ),
      (
        "{\"schema\":\"docx.edit/1\",\"ops\":[{\"op\":\"replace_text\",\"params\":{\"find\":\"a\",\"replace\":\"b\",\"occurrence\":0}}]}",
        "ops[0].params.occurrence must be between 1 and 1000000",
      ),
      (
        "{\"schema\":\"docx.edit/1\",\"ops\":[{\"op\":\"replace_text\",\"params\":{\"find\":\"a\",\"replace\":\"b\",\"occurrence\":1.5}}]}",
        "ops[0].params.occurrence must be a plain integer",
      ),
    ] {
    let (script, expected) = case
    try @docx.parse_docx_edit_script(script) |> ignore catch {
      DocxEditParseError(reason) => assert_eq(reason, expected)
    } noraise {
      _ => fail("expected a parse refusal for: " + script)
    }
  }
}

///|
fn set_run_text_op(at : String, expect : String, text : String) -> Json {
  Json::object({
    "op": Json::string("set_run_text"),
    "params": Json::object({
      "at": Json::string(at),
      "expect": Json::string(expect),
      "text": Json::string(text),
    }),
  })
}

///|
fn edit_script_v2(ops : Array[Json]) -> @docx.DocxEditScript raise {
  @docx.parse_docx_edit_script(
    Json::object({
      "schema": Json::string(@docx.SCHEMA_DOCX_EDIT_V2),
      "ops": Json::array(ops),
    }).stringify(),
  )
}

///|
test "docx.edit/2 parses set_run_text and stays homogeneous" {
  let script = edit_script_v2([set_run_text_op("p[1]/r[1]", "old", "new")])
  assert_eq(script.length(), 1)
  assert_eq(script.schema(), @docx.SCHEMA_DOCX_EDIT_V2)
  // /1 rejects the op with a schema pointer
  let cases = [
    (
      "{\"schema\":\"docx.edit/1\",\"ops\":[{\"op\":\"set_run_text\",\"params\":{\"at\":\"p[1]/r[1]\",\"expect\":\"a\",\"text\":\"b\"}}]}",
      "op \"set_run_text\" needs \"schema\": \"docx.edit/2\"",
    ),
    (
      "{\"schema\":\"docx.edit/2\",\"ops\":[{\"op\":\"set_run_text\",\"params\":{\"at\":\"p[1]/r[1]\",\"expect\":\"a\",\"text\":\"b\"}},{\"op\":\"replace_text\",\"params\":{\"find\":\"x\",\"replace\":\"y\"}}]}",
      "ops[1] mixes \"replace_text\" with set_run_text; a script stays homogeneous",
    ),
    (
      "{\"schema\":\"docx.edit/2\",\"ops\":[{\"op\":\"replace_text\",\"params\":{\"find\":\"x\",\"replace\":\"y\"}},{\"op\":\"set_run_text\",\"params\":{\"at\":\"p[1]/r[1]\",\"expect\":\"a\",\"text\":\"b\"}}]}",
      "ops[1] mixes set_run_text with another operation family; a script stays homogeneous",
    ),
    (
      "{\"schema\":\"docx.edit/2\",\"ops\":[{\"op\":\"set_run_text\",\"params\":{\"at\":\"p[1]/r[1]\",\"expect\":\"a\",\"text\":\"b\\tc\"}}]}",
      "set_run_text \"text\" carries characters the run serializer cannot match or emit (control characters, line breaks, unpaired surrogates, or XML non-characters)",
    ),
  ]
  for case in cases {
    let (script_text, expected) = case
    try @docx.parse_docx_edit_script(script_text) |> ignore catch {
      DocxEditParseError(reason) => assert_eq(reason, expected)
    } noraise {
      _ => fail("expected a parse refusal for: " + script_text)
    }
  }
  // /1 scripts still parse and report their schema
  let v1 = edit_script([replace_op("a", "b")])
  assert_eq(v1.schema(), @docx.SCHEMA_DOCX_EDIT)
}

///|
/// The shipped end-to-end path: an addressed run replacement through
/// `transact_docx_edit`, published atomically, with the /2 report shape.
async test "docx.edit/2 sets a run's text end to end" {
  @async.with_task_group() <| group => {
    let directory = @afs.tmpdir(prefix="office-docx-setrun-")
    group.add_defer() <| () => {
      @async.protect_from_cancel(() => @afs.rmdir(directory, recursive=true))
    }
    let input = edit_fixture(
      directory, "in.docx", "<w:r><w:t>alpha</w:t></w:r><w:r><w:t>beta</w:t></w:r>",
    )
    let output = directory + "/out.docx"
    let result = @docx.transact_docx_edit(
      @transaction.transaction_options(input, output_path=output),
      edit_script_v2([set_run_text_op("p[1]/r[2]", "beta", "BETA")]),
      allow_unmatched=false,
    )
    assert_eq(result.report.ops_applied, 1)
    assert_eq(result.report.replacements, 1)
    assert_eq(result.report.results[0].op, "set_run_text")
    assert_eq(result.report.results[0].at, Some("p[1]/r[2]"))
    assert_eq(result.report.results[0].matched, 1)
    assert_true(result.report.changed)
    assert_true(result.transaction.committed)
    let published = published_document(output)
    assert_true(published.contains(">alpha<"))
    assert_true(published.contains(">BETA<"))
    assert_false(published.contains(">beta<"))
  }
}

///|
/// Refusals: a stale expectation aborts the transaction typed, and a
/// self-replacement publishes nothing.
async test "docx.edit/2 refuses stale expectations and no-ops cleanly" {
  @async.with_task_group() <| group => {
    let directory = @afs.tmpdir(prefix="office-docx-setrun-refuse-")
    group.add_defer() <| () => {
      @async.protect_from_cancel(() => @afs.rmdir(directory, recursive=true))
    }
    let input = edit_fixture(
      directory, "in.docx", "<w:r><w:t>alpha</w:t></w:r><w:r><w:t>beta</w:t></w:r>",
    )
    let output = directory + "/out.docx"
    let mut refused = false
    try
      @docx.transact_docx_edit(
        @transaction.transaction_options(input, output_path=output),
        edit_script_v2([set_run_text_op("p[1]/r[2]", "stale", "BETA")]),
        allow_unmatched=false,
      )
      |> ignore
    catch {
      @transaction.TransactionError(code~, ..) => {
        refused = true
        assert_eq(code, "office.docx.invalid_plan")
      }
      _ => fail("expected a typed transaction refusal")
    } noraise {
      _ => ()
    }
    assert_true(refused)
    assert_false(@afs.exists(output))
    // self-replacement: validated, nothing queued, nothing published
    let result = @docx.transact_docx_edit(
      @transaction.transaction_options(input, output_path=output),
      edit_script_v2([set_run_text_op("p[1]/r[2]", "beta", "beta")]),
      allow_unmatched=false,
    )
    assert_eq(result.report.replacements, 0)
    assert_false(result.report.changed)
    // a no-op WITH an output path still publishes: the exact source
    // bytes, reused verbatim
    assert_true(result.transaction.preservation.whole_file_identical)
    assert_eq(@afs.read_file(output).binary(), @afs.read_file(input).binary())
  }
}

///|
/// paraId R2b: a stable head addresses the run through IDENTITY. The
/// result records both spellings — the request and the ordinal address
/// it resolved to in this snapshot — and an ambiguous id refuses the
/// whole transaction, publishing nothing.
async test "docx.edit/2 set_run_text resolves a stable paragraph head" {
  @async.with_task_group() <| group => {
    let directory = @afs.tmpdir(prefix="office-docx-edit-stable-")
    group.add_defer() <| () => {
      @async.protect_from_cancel(() => @afs.rmdir(directory, recursive=true))
    }
    let input = edit_fixture(
      directory, "in.docx", "<w:r><w:t>first</w:t></w:r></w:p><w:p w14:paraId=\"1A2B3C4D\"><w:r><w:t>target</w:t></w:r>",
    )
    let output = directory + "/out.docx"
    let result = @docx.transact_docx_edit(
      @transaction.transaction_options(input, output_path=output),
      edit_script_v2([
        set_run_text_op("p[id=\"1A2B3C4D\"]/r[1]", "target", "landed"),
      ]),
      allow_unmatched=false,
    )
    assert_eq(result.report.replacements, 1)
    assert_eq(result.report.results[0].resolved_at, Some("p[2]/r[1]"))
    assert_true(published_document(output).contains("landed"))
  }
}

///|
async test "docx.edit/2 stable head refuses a duplicate id" {
  @async.with_task_group() <| group => {
    let directory = @afs.tmpdir(prefix="office-docx-edit-dup-")
    group.add_defer() <| () => {
      @async.protect_from_cancel(() => @afs.rmdir(directory, recursive=true))
    }
    let input = edit_fixture(
      directory, "in.docx", "<w:r><w:t>a</w:t></w:r></w:p><w:p w14:paraId=\"1A2B3C4D\"><w:r><w:t>b</w:t></w:r></w:p><w:p w14:paraId=\"1a2b3c4d\"><w:r><w:t>c</w:t></w:r>",
    )
    let output = directory + "/out.docx"
    let mut failure : String? = None
    ignore(
      @docx.transact_docx_edit(
        @transaction.transaction_options(input, output_path=output),
        edit_script_v2([set_run_text_op("p[id=\"1A2B3C4D\"]/r[1]", "b", "x")]),
        allow_unmatched=false,
      ),
    ) catch {
      error => failure = Some("\{error}")
    }
    guard failure is Some(message) else { fail("expected the refusal") }
    assert_true(
      message.contains("office.docx.para_id_ambiguous"),
      msg="got '" + message + "'",
    )
    let mut published = false
    try {
      ignore(@afs.read_file(output))
      published = true
    } catch {
      _ => ()
    }
    assert_false(published, msg="a refused stable edit must write nothing")
  }
}

///|
/// Round 1's High, pinned: EVERY stable head is judged before ANY op
/// is planned. A script whose second op carries an ambiguous id
/// refuses whole — the valid first op must not have planned anything,
/// and nothing is published.
async test "docx.edit/2 judges all stable heads before planning any op" {
  @async.with_task_group() <| group => {
    let directory = @afs.tmpdir(prefix="office-docx-edit-order-")
    group.add_defer() <| () => {
      @async.protect_from_cancel(() => @afs.rmdir(directory, recursive=true))
    }
    let input = edit_fixture(
      directory, "in.docx", "<w:r><w:t>plain</w:t></w:r></w:p><w:p w14:paraId=\"1A2B3C4D\"><w:r><w:t>dup one</w:t></w:r></w:p><w:p w14:paraId=\"1a2b3c4d\"><w:r><w:t>dup two</w:t></w:r>",
    )
    let output = directory + "/out.docx"
    let mut failure : String? = None
    ignore(
      @docx.transact_docx_edit(
        @transaction.transaction_options(input, output_path=output),
        edit_script_v2([
          set_run_text_op("p[1]/r[1]", "plain", "changed"),
          set_run_text_op("p[id=\"1A2B3C4D\"]/r[1]", "dup one", "x"),
        ]),
        allow_unmatched=false,
      ),
    ) catch {
      error => failure = Some("\{error}")
    }
    guard failure is Some(message) else { fail("expected the refusal") }
    assert_true(message.contains("office.docx.para_id_ambiguous"))
    let mut published = false
    try {
      ignore(@afs.read_file(output))
      published = true
    } catch {
      _ => ()
    }
    assert_false(published, msg="op 1 must not publish past op 2's refusal")
  }
}

///|
/// Round 1's empty-id split, pinned: `p[id=""]/r[1]` parses (spelling
/// is structural) and refuses at TRANSACTION time as para_id_invalid.
async test "docx.edit/2 empty stable id refuses typed at transaction time" {
  @async.with_task_group() <| group => {
    let directory = @afs.tmpdir(prefix="office-docx-edit-empty-")
    group.add_defer() <| () => {
      @async.protect_from_cancel(() => @afs.rmdir(directory, recursive=true))
    }
    let input = edit_fixture(
      directory, "in.docx", "<w:r><w:t>alpha</w:t></w:r>",
    )
    let output = directory + "/out.docx"
    let mut failure : String? = None
    ignore(
      @docx.transact_docx_edit(
        @transaction.transaction_options(input, output_path=output),
        edit_script_v2([set_run_text_op("p[id=\"\"]/r[1]", "alpha", "x")]),
        allow_unmatched=false,
      ),
    ) catch {
      error => failure = Some("\{error}")
    }
    guard failure is Some(message) else { fail("expected the refusal") }
    assert_true(
      message.contains("office.docx.para_id_invalid"),
      msg="got '" + message + "'",
    )
  }
}

///|
/// The same seven-unit edge through the edit parser: `p[id="]/r[1]`
/// refuses at PARSE (the head's prefix and suffix must be distinct
/// quotes), never reaching a panicking slice.
async test "docx.edit/2 seven-unit stable head refuses at parse" {
  let mut refused = false
  try
    ignore(edit_script_v2([set_run_text_op("p[id=\"]/r[1]", "a", "b")]))
  catch {
    _ => refused = true
  } noraise {
    _ => ()
  }
  assert_true(refused, msg="seven-unit head must refuse at parse")
}
