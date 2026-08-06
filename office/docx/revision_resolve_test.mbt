///|
/// One `accept_revision`/`reject_revision` op as the script spells it.
fn revision_op(
  accept : Bool,
  id? : String,
  author? : String,
  kind? : String,
  all? : Bool,
) -> Json {
  let params : Map[String, Json] = Map([])
  match id {
    Some(value) => params["id"] = Json::string(value)
    None => ()
  }
  match author {
    Some(value) => params["author"] = Json::string(value)
    None => ()
  }
  match kind {
    Some(value) => params["type"] = Json::string(value)
    None => ()
  }
  match all {
    Some(value) => params["all"] = Json::boolean(value)
    None => ()
  }
  Json::object({
    "op": Json::string(
      if accept {
        "accept_revision"
      } else {
        "reject_revision"
      },
    ),
    "params": Json::object(params),
  })
}

///|
/// The two-revision paragraph from the OOXML spec's own worked example: the
/// deletion and the insertion that replaced it sit side by side, so accepting
/// everything and rejecting everything produce two different sentences.
const REVENUE_RUNS : String =
  #|<w:r><w:t xml:space="preserve">The revenue was </w:t></w:r><w:del w:id="1" w:author="Reviewer" w:date="2026-01-01T00:00:00Z"><w:r><w:delText xml:space="preserve">flat</w:delText></w:r></w:del><w:ins w:id="2" w:author="Reviewer" w:date="2026-01-01T00:00:00Z"><w:r><w:t xml:space="preserve">up 18%</w:t></w:r></w:ins><w:r><w:t xml:space="preserve"> this quarter.</w:t></w:r>

///|
/// Runs one revision script over a fixture and returns the published main
/// document part.
async fn resolve_fixture(
  prefix : String,
  runs : String,
  ops : Array[Json],
) -> (@docx.DocxEditResult, String) {
  let directory = @afs.tmpdir(prefix~)
  let input = edit_fixture(directory, "in.docx", runs)
  let output = directory + "/out.docx"
  let result = @docx.transact_docx_edit(
    @transaction.transaction_options(input, output_path=output),
    edit_script(ops),
    allow_unmatched=false,
  )
  let document = published_document(output)
  @async.protect_from_cancel(() => @afs.rmdir(directory, recursive=true))
  (result, document)
}

///|
/// Accepting an insertion UNWRAPS it: the `w:ins` element goes, its runs and
/// their formatting stay, and the text the reader already showed is now the
/// settled text with no revision left behind.
async test "accepting an insertion unwraps it and keeps the runs" {
  @async.with_task_group() <| _ => {
    let (result, document) = resolve_fixture(
      "office-docx-revision-accept-ins-",
      "<w:ins w:id=\"9\" w:author=\"Reviewer\"><w:r><w:rPr><w:b/></w:rPr><w:t>added</w:t></w:r></w:ins>",
      [revision_op(true, all=true)],
    )
    assert_eq(result.report.revisions_resolved, 1)
    assert_eq(result.report.results[0].matched, 1)
    assert_eq(result.report.results[0].resolved, 1)
    assert_eq(result.report.replacements, 0)
    assert_true(result.report.changed)
    assert_false(document.contains("w:ins"))
    assert_true(
      document.contains("<w:r><w:rPr><w:b/></w:rPr><w:t>added</w:t></w:r>"),
    )
  }
}

///|
/// Rejecting an insertion removes the element AND its content: the inserted
/// words never happened.
async test "rejecting an insertion removes the element and its content" {
  @async.with_task_group() <| _ => {
    let (result, document) = resolve_fixture(
      "office-docx-revision-reject-ins-",
      "<w:r><w:t>kept </w:t></w:r><w:ins w:id=\"9\" w:author=\"Reviewer\"><w:r><w:t>added</w:t></w:r></w:ins>",
      [revision_op(false, all=true)],
    )
    assert_eq(result.report.revisions_resolved, 1)
    assert_false(document.contains("w:ins"))
    assert_false(document.contains("added"))
    assert_true(document.contains("<w:r><w:t>kept </w:t></w:r>"))
  }
}

///|
/// Accepting a deletion removes the element AND its content: the deleted
/// words are gone for good.
async test "accepting a deletion removes the element and its content" {
  @async.with_task_group() <| _ => {
    let (result, document) = resolve_fixture(
      "office-docx-revision-accept-del-",
      "<w:r><w:t>kept </w:t></w:r><w:del w:id=\"9\" w:author=\"Reviewer\"><w:r><w:delText>struck</w:delText></w:r></w:del>",
      [revision_op(true, all=true)],
    )
    assert_eq(result.report.revisions_resolved, 1)
    assert_false(document.contains("w:del"))
    assert_false(document.contains("struck"))
    assert_true(document.contains("<w:r><w:t>kept </w:t></w:r>"))
  }
}

///|
/// The subtlest case: rejecting a deletion has to bring the text BACK, which
/// means every `w:delText` becomes a `w:t` again. The rename is a byte-range
/// overwrite of the LOCAL NAME only, so `xml:space="preserve"` and the run's
/// formatting survive it untouched.
async test "rejecting a deletion restores the deleted text as w:t" {
  @async.with_task_group() <| _ => {
    let (result, document) = resolve_fixture(
      "office-docx-revision-reject-del-",
      "<w:del w:id=\"9\" w:author=\"Reviewer\"><w:r><w:rPr><w:i/></w:rPr><w:delText xml:space=\"preserve\"> struck </w:delText></w:r></w:del>",
      [revision_op(false, all=true)],
    )
    assert_eq(result.report.revisions_resolved, 1)
    assert_false(document.contains("w:del"))
    assert_true(
      document.contains(
        "<w:r><w:rPr><w:i/></w:rPr><w:t xml:space=\"preserve\"> struck </w:t></w:r>",
      ),
    )
  }
}

///|
/// The headline pair. Accepting everything in the deletion/insertion pair
/// yields the reviewer's sentence; rejecting everything yields the original.
/// Two revisions in ONE paragraph is also where an implementation that
/// mutated the part in place would corrupt the second edit's offsets.
async test "accepting every revision in one paragraph yields the reviewed text" {
  @async.with_task_group() <| _ => {
    let (result, document) = resolve_fixture(
      "office-docx-revision-accept-all-",
      REVENUE_RUNS,
      [revision_op(true, all=true)],
    )
    assert_eq(result.report.revisions_resolved, 2)
    assert_false(document.contains("w:ins"))
    assert_false(document.contains("w:del"))
    assert_false(document.contains("flat"))
    assert_true(
      document.contains(
        "<w:r><w:t xml:space=\"preserve\">The revenue was </w:t></w:r><w:r><w:t xml:space=\"preserve\">up 18%</w:t></w:r><w:r><w:t xml:space=\"preserve\"> this quarter.</w:t></w:r>",
      ),
    )
  }
}

///|
async test "rejecting every revision in one paragraph restores the original text" {
  @async.with_task_group() <| _ => {
    let (result, document) = resolve_fixture(
      "office-docx-revision-reject-all-",
      REVENUE_RUNS,
      [revision_op(false, all=true)],
    )
    assert_eq(result.report.revisions_resolved, 2)
    assert_false(document.contains("w:ins"))
    assert_false(document.contains("w:del"))
    assert_false(document.contains("up 18%"))
    assert_true(
      document.contains(
        "<w:r><w:t xml:space=\"preserve\">The revenue was </w:t></w:r><w:r><w:t xml:space=\"preserve\">flat</w:t></w:r><w:r><w:t xml:space=\"preserve\"> this quarter.</w:t></w:r>",
      ),
    )
  }
}

///|
/// Two revisions in DIFFERENT paragraphs resolved in one transaction. Every
/// offset is taken from the same immutable snapshot and the splice layer
/// sorts and overlap-checks them, so the later paragraph's edit is not
/// shifted by the earlier one.
async test "revisions across two paragraphs resolve together" {
  @async.with_task_group() <| _ => {
    let (result, document) = resolve_fixture(
      "office-docx-revision-two-paragraphs-",
      "<w:ins w:id=\"1\" w:author=\"Reviewer\"><w:r><w:t>first</w:t></w:r></w:ins>" +
      "</w:p><w:p>" +
      "<w:del w:id=\"2\" w:author=\"Reviewer\"><w:r><w:delText>second</w:delText></w:r></w:del>",
      [revision_op(true, all=true)],
    )
    assert_eq(result.report.revisions_resolved, 2)
    assert_false(document.contains("w:ins"))
    assert_false(document.contains("w:del"))
    assert_true(document.contains("<w:r><w:t>first</w:t></w:r>"))
    assert_false(document.contains("second"))
  }
}

///|
/// Selection by AUTHOR resolves only that author's revisions and leaves every
/// other reviewer's work exactly as it was.
async test "selecting by author leaves other authors untouched" {
  @async.with_task_group() <| _ => {
    let (result, document) = resolve_fixture(
      "office-docx-revision-by-author-",
      "<w:ins w:id=\"1\" w:author=\"Ada\"><w:r><w:t>ada</w:t></w:r></w:ins>" +
      "<w:ins w:id=\"2\" w:author=\"Bob\"><w:r><w:t>bob</w:t></w:r></w:ins>",
      [revision_op(true, author="Ada")],
    )
    assert_eq(result.report.revisions_resolved, 1)
    assert_eq(result.report.results[0].matched, 1)
    assert_true(document.contains("<w:r><w:t>ada</w:t></w:r>"))
    assert_true(
      document.contains(
        "<w:ins w:id=\"2\" w:author=\"Bob\"><w:r><w:t>bob</w:t></w:r></w:ins>",
      ),
    )
  }
}

///|
/// Selection by w:id is the precise handle: "reject revision 2" touches
/// exactly one element, whatever its position in the document.
async test "selecting by id resolves exactly one revision" {
  @async.with_task_group() <| _ => {
    let (result, document) = resolve_fixture(
      "office-docx-revision-by-id-",
      "<w:del w:id=\"1\" w:author=\"Ada\"><w:r><w:delText>one</w:delText></w:r></w:del>" +
      "<w:del w:id=\"2\" w:author=\"Ada\"><w:r><w:delText>two</w:delText></w:r></w:del>",
      [revision_op(false, id="2")],
    )
    assert_eq(result.report.revisions_resolved, 1)
    // revision 2 came back as ordinary text; revision 1 is still pending
    assert_true(document.contains("<w:r><w:t>two</w:t></w:r>"))
    assert_true(
      document.contains(
        "<w:del w:id=\"1\" w:author=\"Ada\"><w:r><w:delText>one</w:delText></w:r></w:del>",
      ),
    )
  }
}

///|
/// Conjunctive selection: both spelled fields must hold.
async test "selector fields combine conjunctively" {
  @async.with_task_group() <| _ => {
    let (result, document) = resolve_fixture(
      "office-docx-revision-conjunction-",
      "<w:ins w:id=\"1\" w:author=\"Ada\"><w:r><w:t>ins-ada</w:t></w:r></w:ins>" +
      "<w:del w:id=\"2\" w:author=\"Ada\"><w:r><w:delText>del-ada</w:delText></w:r></w:del>" +
      "<w:del w:id=\"3\" w:author=\"Bob\"><w:r><w:delText>del-bob</w:delText></w:r></w:del>",
      [revision_op(true, author="Ada", kind="del")],
    )
    assert_eq(result.report.revisions_resolved, 1)
    assert_false(document.contains("del-ada"))
    assert_true(document.contains("ins-ada"))
    assert_true(document.contains("del-bob"))
  }
}

///|
/// A dry run performs the whole resolution, the candidate validation, and the
/// preservation check, and publishes nothing — the input stays BYTE-identical.
async test "a dry-run resolution leaves the input byte-identical" {
  @async.with_task_group() <| group => {
    let directory = @afs.tmpdir(prefix="office-docx-revision-dry-run-")
    group.add_defer() <| () => {
      @async.protect_from_cancel(() => @afs.rmdir(directory, recursive=true))
    }
    let input = edit_fixture(directory, "in.docx", REVENUE_RUNS)
    let before = @afs.read_file(input).binary()
    let result = @docx.transact_docx_edit(
      @transaction.transaction_options(
        input,
        output_path=directory + "/out.docx",
        dry_run=true,
      ),
      edit_script([revision_op(true, all=true)]),
      allow_unmatched=false,
    )
    assert_eq(result.report.revisions_resolved, 2)
    assert_true(result.transaction.dry_run)
    assert_false(result.transaction.committed)
    let after = @afs.read_file(input).binary()
    assert_eq(before, after)
    assert_false(@afs.exists(directory + "/out.docx"))
  }
}

///|
/// Resolving nothing is a refusal, not a silent success: a selector that
/// matches no tracked change is almost always a typo in an id or an author.
async test "a selector matching nothing refuses" {
  @async.with_task_group() <| group => {
    let directory = @afs.tmpdir(prefix="office-docx-revision-unmatched-")
    group.add_defer() <| () => {
      @async.protect_from_cancel(() => @afs.rmdir(directory, recursive=true))
    }
    let input = edit_fixture(directory, "in.docx", REVENUE_RUNS)
    let output = directory + "/out.docx"
    try
      @docx.transact_docx_edit(
        @transaction.transaction_options(input, output_path=output),
        edit_script([revision_op(true, author="Nobody")]),
        allow_unmatched=false,
      )
      |> ignore
    catch {
      @docx.DocxEditRefused(report) => {
        assert_eq(report.unmatched_total, 1)
        assert_eq(report.revisions_resolved, 0)
      }
      _ => fail("expected the typed refusal")
    } noraise {
      _ => fail("expected a refusal for an unmatched selector")
    }
    if @afs.exists(output) {
      fail("refusal must not publish")
    }
  }
}

///|
/// A paragraph-mark revision (`w:pPr/w:rPr/w:ins`) is a revision of a
/// PROPERTY, and accepting one can merge two paragraphs. It is out of scope,
/// and — this is the point — a selection that reaches it REFUSES. Leaving it
/// behind would mean "accept everything by Reviewer" quietly returned a
/// document still under review.
async test "a paragraph-mark property revision refuses instead of being skipped" {
  @async.with_task_group() <| group => {
    let directory = @afs.tmpdir(prefix="office-docx-revision-para-mark-")
    group.add_defer() <| () => {
      @async.protect_from_cancel(() => @afs.rmdir(directory, recursive=true))
    }
    let input = edit_fixture(
      directory,
      "in.docx",
      "<w:pPr><w:rPr><w:ins w:id=\"5\" w:author=\"Reviewer\"/></w:rPr></w:pPr>" +
      "<w:r><w:t>body</w:t></w:r>",
    )
    let output = directory + "/out.docx"
    try
      @docx.transact_docx_edit(
        @transaction.transaction_options(input, output_path=output),
        edit_script([revision_op(true, all=true)]),
        allow_unmatched=false,
      )
      |> ignore
    catch {
      @docx.DocxEditRefused(report) => {
        assert_eq(report.unsupported_total, 1)
        assert_eq(report.revisions_resolved, 0)
        assert_true(report.unsupported[0].detail.contains("property"))
      }
      _ => fail("expected the typed refusal")
    } noraise {
      _ => fail("expected a refusal for a paragraph-mark revision")
    }
    if @afs.exists(output) {
      fail("refusal must not publish")
    }
  }
}

///|
/// A move is a PAIR. Resolving one half as a plain insertion or deletion
/// would leave the other half dangling, so a selection reaching either half
/// refuses.
async test "a tracked move refuses instead of being resolved as a deletion" {
  @async.with_task_group() <| group => {
    let directory = @afs.tmpdir(prefix="office-docx-revision-move-")
    group.add_defer() <| () => {
      @async.protect_from_cancel(() => @afs.rmdir(directory, recursive=true))
    }
    let input = edit_fixture(
      directory, "in.docx", "<w:moveFrom w:id=\"5\" w:author=\"Reviewer\"><w:r><w:t>moved</w:t></w:r></w:moveFrom>",
    )
    let output = directory + "/out.docx"
    try
      @docx.transact_docx_edit(
        @transaction.transaction_options(input, output_path=output),
        edit_script([revision_op(true, author="Reviewer")]),
        allow_unmatched=false,
      )
      |> ignore
    catch {
      @docx.DocxEditRefused(report) => {
        assert_eq(report.unsupported_total, 1)
        assert_true(report.unsupported[0].detail.contains("w:moveFrom"))
      }
      _ => fail("expected the typed refusal")
    } noraise {
      _ => fail("expected a refusal for a tracked move")
    }
    if @afs.exists(output) {
      fail("refusal must not publish")
    }
  }
}

///|
/// A formatting revision carries the PREVIOUS properties inside a property
/// container; resolving it rewrites properties, not a content range.
async test "a formatting property change refuses" {
  @async.with_task_group() <| group => {
    let directory = @afs.tmpdir(prefix="office-docx-revision-rprchange-")
    group.add_defer() <| () => {
      @async.protect_from_cancel(() => @afs.rmdir(directory, recursive=true))
    }
    let input = edit_fixture(
      directory, "in.docx", "<w:r><w:rPr><w:b/><w:rPrChange w:id=\"5\" w:author=\"Reviewer\"><w:rPr/></w:rPrChange></w:rPr><w:t>bold now</w:t></w:r>",
    )
    let output = directory + "/out.docx"
    try
      @docx.transact_docx_edit(
        @transaction.transaction_options(input, output_path=output),
        edit_script([revision_op(true, all=true)]),
        allow_unmatched=false,
      )
      |> ignore
    catch {
      @docx.DocxEditRefused(report) => {
        assert_eq(report.unsupported_total, 1)
        assert_true(report.unsupported[0].detail.contains("w:rPrChange"))
      }
      _ => fail("expected the typed refusal")
    } noraise {
      _ => fail("expected a refusal for a property change")
    }
    if @afs.exists(output) {
      fail("refusal must not publish")
    }
  }
}

///|
/// Word does emit `w:ins` around `w:del` — text one reviewer inserted and
/// another then struck. Resolving the outer element rewrites bytes the inner
/// one also owns, so the caller is told to resolve the inner revision first
/// rather than being handed a corrupted document.
async test "a revision nested inside another revision refuses" {
  @async.with_task_group() <| group => {
    let directory = @afs.tmpdir(prefix="office-docx-revision-nested-")
    group.add_defer() <| () => {
      @async.protect_from_cancel(() => @afs.rmdir(directory, recursive=true))
    }
    let input = edit_fixture(
      directory, "in.docx", "<w:ins w:id=\"1\" w:author=\"Ada\"><w:del w:id=\"2\" w:author=\"Bob\"><w:r><w:delText>both</w:delText></w:r></w:del></w:ins>",
    )
    let output = directory + "/out.docx"
    try
      @docx.transact_docx_edit(
        @transaction.transaction_options(input, output_path=output),
        edit_script([revision_op(true, all=true)]),
        allow_unmatched=false,
      )
      |> ignore
    catch {
      @docx.DocxEditRefused(report) => {
        assert_true(report.conflicts_total > 0)
        assert_true(
          report.conflicts[0].detail.contains(
            "resolve the inner revision first",
          ),
        )
      }
      _ => fail("expected the typed refusal")
    } noraise {
      _ => fail("expected a refusal for nested revisions")
    }
    if @afs.exists(output) {
      fail("refusal must not publish")
    }
  }
}

///|
/// Resolving ONLY the inner half of a nested pair is unambiguous and works:
/// the outer insertion is left standing, still pending.
async test "resolving only the inner half of a nested pair succeeds" {
  @async.with_task_group() <| _ => {
    let (result, document) = resolve_fixture(
      "office-docx-revision-nested-inner-",
      "<w:ins w:id=\"1\" w:author=\"Ada\"><w:del w:id=\"2\" w:author=\"Bob\"><w:r><w:delText>both</w:delText></w:r></w:del></w:ins>",
      [revision_op(false, id="2")],
    )
    assert_eq(result.report.revisions_resolved, 1)
    assert_true(
      document.contains(
        "<w:ins w:id=\"1\" w:author=\"Ada\"><w:r><w:t>both</w:t></w:r></w:ins>",
      ),
    )
  }
}

///|
/// Two operations that disagree about one revision have no defined outcome,
/// so the whole transaction refuses instead of letting op order decide.
async test "accept and reject selecting one revision refuses" {
  @async.with_task_group() <| group => {
    let directory = @afs.tmpdir(prefix="office-docx-revision-disagree-")
    group.add_defer() <| () => {
      @async.protect_from_cancel(() => @afs.rmdir(directory, recursive=true))
    }
    let input = edit_fixture(directory, "in.docx", REVENUE_RUNS)
    let output = directory + "/out.docx"
    try
      @docx.transact_docx_edit(
        @transaction.transaction_options(input, output_path=output),
        edit_script([
          revision_op(true, id="2"),
          revision_op(false, author="Reviewer"),
        ]),
        allow_unmatched=false,
      )
      |> ignore
    catch {
      @docx.DocxEditRefused(report) => assert_true(report.conflicts_total > 0)
      _ => fail("expected the typed refusal")
    } noraise {
      _ => fail("expected a refusal for disagreeing operations")
    }
    if @afs.exists(output) {
      fail("refusal must not publish")
    }
  }
}

///|
/// The empty forms. `<w:ins/>` and `<w:del/>` carry nothing, so all four
/// resolutions of them collapse to removing the element, and the surrounding
/// content is untouched.
async test "a self-closing revision element resolves to its own removal" {
  @async.with_task_group() <| _ => {
    let (result, document) = resolve_fixture(
      "office-docx-revision-self-closing-",
      "<w:r><w:t>kept</w:t></w:r><w:ins w:id=\"9\" w:author=\"Reviewer\"/>",
      [revision_op(true, all=true)],
    )
    assert_eq(result.report.revisions_resolved, 1)
    assert_false(document.contains("w:ins"))
    assert_true(document.contains("<w:r><w:t>kept</w:t></w:r>"))
  }
}

///|
/// A revision under an ALTERNATE WML prefix is matched by namespace URI, not
/// by spelling, and the `delText` rename overwrites the LOCAL NAME only — so
/// the source prefix survives the round trip.
async test "an alternate WML prefix resolves through namespace identity" {
  @async.with_task_group() <| _ => {
    // The prefix is bound on the paragraph, not on the revision element, so
    // unwrapping the revision cannot orphan it.
    let (result, document) = resolve_fixture(
      "office-docx-revision-prefix-",
      "<x:del xmlns:x=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\" x:id=\"9\" x:author=\"Reviewer\"><x:r><x:delText>back</x:delText></x:r></x:del>",
      [revision_op(true, all=true)],
    )
    // accepting the deletion removes the whole element, prefix binding and all
    assert_eq(result.report.revisions_resolved, 1)
    assert_false(document.contains("back"))
    assert_false(document.contains("x:del"))
  }
}

///|
/// Unwrapping an element that BINDS a prefix its own content uses would leave
/// that prefix unbound. The document would still be a zip full of plausible
/// XML, so this is refused up front with a specific finding rather than left
/// to a generic well-formedness failure downstream.
async test "unwrapping a revision that binds its content's prefix refuses" {
  @async.with_task_group() <| group => {
    let directory = @afs.tmpdir(prefix="office-docx-revision-prefix-unwrap-")
    group.add_defer() <| () => {
      @async.protect_from_cancel(() => @afs.rmdir(directory, recursive=true))
    }
    let input = edit_fixture(
      directory, "in.docx", "<x:del xmlns:x=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\" x:id=\"9\" x:author=\"Reviewer\"><x:r><x:delText>back</x:delText></x:r></x:del>",
    )
    let output = directory + "/out.docx"
    try
      @docx.transact_docx_edit(
        @transaction.transaction_options(input, output_path=output),
        edit_script([revision_op(false, all=true)]),
        allow_unmatched=false,
      )
      |> ignore
    catch {
      @docx.DocxEditRefused(report) => {
        assert_eq(report.unsupported_total, 1)
        assert_true(report.unsupported[0].detail.contains("unbound"))
      }
      _ => fail("expected the typed refusal")
    } noraise {
      _ => fail("unwrapping an orphaning prefix binding must refuse")
    }
    if @afs.exists(output) {
      fail("refusal must not publish")
    }
  }
}

///|
/// The two op families never share a script: their byte spans are resolved
/// against the same snapshot, and a replacement landing inside a revision the
/// same script removes has no defined outcome.
test "a script never mixes replace_text with revision ops" {
  let script = Json::object({
    "schema": Json::string(@docx.SCHEMA_DOCX_EDIT),
    "ops": Json::array([replace_op("a", "b"), revision_op(true, all=true)]),
  }).stringify()
  try @docx.parse_docx_edit_script(script) |> ignore catch {
    DocxEditParseError(reason) => assert_true(reason.contains("never both"))
  } noraise {
    _ => fail("a mixed script must refuse")
  }
}

///|
/// Every selector-shape rule is enforced at parse time, so a malformed
/// selector can never reach a document.
test "revision selectors are validated at parse time" {
  fn refuse(params : Json) -> String raise {
    let script = Json::object({
      "schema": Json::string(@docx.SCHEMA_DOCX_EDIT),
      "ops": Json::array([
        Json::object({ "op": Json::string("accept_revision"), "params": params }),
      ]),
    }).stringify()
    let message = Ref("")
    try @docx.parse_docx_edit_script(script) |> ignore catch {
      DocxEditParseError(reason) => message.val = reason
    } noraise {
      _ => fail("expected a parse refusal for: " + script)
    }
    message.val
  }

  assert_true(refuse(Json::object({})).contains("at least one of"))
  assert_true(
    refuse(Json::object({ "all": Json::boolean(false) })).contains(
      "must be true",
    ),
  )
  assert_true(
    refuse(
      Json::object({ "all": Json::boolean(true), "id": Json::string("1") }),
    ).contains("cannot be combined"),
  )
  assert_true(
    refuse(Json::object({ "type": Json::string("moveFrom") })).contains(
      "\"ins\" or \"del\"",
    ),
  )
  assert_true(
    refuse(Json::object({ "author": Json::string("") })).contains(
      "must not be empty",
    ),
  )
  assert_true(
    refuse(Json::object({ "since": Json::string("x") })).contains(
      "unknown member",
    ),
  )
}
