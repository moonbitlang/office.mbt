// Blackbox witnesses for the formatting planner's public seam (F2a),
// through the public API only: plan, splice, re-read with the real
// reader, and hold the result to the INDEPENDENT direct-format
// readback — the check the projection cannot make, since formatting
// never moves text.

///|
fn format_fixture_body(body : String) -> String {
  "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\" xmlns:w14=\"http://schemas.microsoft.com/office/word/2010/wordml\" xmlns:v=\"urn:schemas-microsoft-com:vml\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\"><w:body>\{body}<w:sectPr/></w:body></w:document>"
}

///|
fn format_fixture(body : String) -> @docx.DocxAnnotatedResult raise {
  @docx.read_docx_annotated(fixture_docx(format_fixture_body(body)))
}

///|
/// Apply a plan to the same fixture and re-read it.
fn format_apply(
  body : String,
  plan : @splice.SplicePlan,
) -> @docx.DocxAnnotatedResult raise {
  let spliced = @splice.splice_docx_archive(
    try! @mbtzip.read(fixture_docx(format_fixture_body(body))),
    plan,
    max_output_bytes=1 << 22,
  )
  @docx.read_docx_annotated(spliced)
}

///|
test "format plans text-selected spans and the readback agrees" {
  let body = "<w:p><w:r><w:t>Hello world</w:t></w:r></w:p>"
  let annotated = format_fixture(body)
  let (plan, receipt) = @docx.plan_docx_format(
    annotated,
    annotated.main_story_source(),
    format=@docx.docx_direct_format(bold=true),
    text="world",
  )
  assert_eq(receipt.mode(), "text")
  debug_inspect(receipt.selected(), content="[1]")
  assert_eq(receipt.spans().length(), 1)
  assert_eq(receipt.spans()[0].path(), "p[1]")
  assert_eq(receipt.spans()[0].text(), "world")
  assert_eq(receipt.spans()[0].start(), 6)
  debug_inspect(
    receipt.spans()[0].source_runs(),
    content=(
      #|["p[1]/r[1]"]
    ),
  )
  assert_eq(receipt.runs_changed(), 1)
  assert_eq(receipt.splits(), 1)
  assert_eq(receipt.affected().length(), 1)
  // Formatting never moves text: the expectation is the UNCHANGED
  // projection.
  assert_eq(receipt.affected()[0].expected(), "Hello world")
  let reread = format_apply(body, plan)
  // The projection is unchanged...
  assert_eq(
    @docx.docx_paragraph_projection(
      reread,
      reread.main_story_source(),
      path="p[1]",
    ),
    Some("Hello world"),
  )
  // ...and the selected range now carries the property explicitly,
  // while the unselected head does not.
  assert_eq(
    @docx.docx_paragraph_direct_format(
      reread,
      reread.main_story_source(),
      path="p[1]",
      start=6,
      end=11,
      format=@docx.docx_direct_format(bold=true),
    ),
    None,
  )
  assert_true(
    @docx.docx_paragraph_direct_format(
      reread,
      reread.main_story_source(),
      path="p[1]",
      start=0,
      end=5,
      format=@docx.docx_direct_format(bold=true),
    )
    is Some(_),
  )
}

///|
test "format addresses an explicit range inside one paragraph" {
  let body = "<w:p><w:r><w:t>alpha</w:t></w:r></w:p><w:p><w:r><w:t>beta</w:t></w:r></w:p>"
  let annotated = format_fixture(body)
  let (plan, receipt) = @docx.plan_docx_format(
    annotated,
    annotated.main_story_source(),
    format=@docx.docx_direct_format(italic=true),
    within="p[2]",
    range=(1, 3),
  )
  assert_eq(receipt.mode(), "range")
  debug_inspect(receipt.selected(), content="[]")
  assert_eq(receipt.spans().length(), 1)
  assert_eq(receipt.spans()[0].path(), "p[2]")
  assert_eq(receipt.spans()[0].text(), "et")
  let reread = format_apply(body, plan)
  assert_eq(
    @docx.docx_paragraph_projection(
      reread,
      reread.main_story_source(),
      path="p[2]",
    ),
    Some("beta"),
  )
  assert_eq(
    @docx.docx_paragraph_direct_format(
      reread,
      reread.main_story_source(),
      path="p[2]",
      start=1,
      end=3,
      format=@docx.docx_direct_format(italic=true),
    ),
    None,
  )
  // The other paragraph is untouched.
  assert_true(
    @docx.docx_paragraph_direct_format(
      reread,
      reread.main_story_source(),
      path="p[1]",
      start=0,
      end=5,
      format=@docx.docx_direct_format(italic=true),
    )
    is Some(_),
  )
}

///|
test "format batches every candidate across paragraphs" {
  let body = "<w:p><w:r><w:t>ab cd</w:t></w:r></w:p><w:p><w:r><w:t>cd ab</w:t></w:r></w:p>"
  let annotated = format_fixture(body)
  let (plan, receipt) = @docx.plan_docx_format(
    annotated,
    annotated.main_story_source(),
    format=@docx.docx_direct_format(bold=true),
    text="cd",
  )
  debug_inspect(receipt.selected(), content="[1, 2]")
  assert_eq(receipt.affected().length(), 2)
  assert_eq(receipt.runs_changed(), 2)
  assert_eq(receipt.splits(), 2)
  let reread = format_apply(body, plan)
  for probe in [("p[1]", 3, 5), ("p[2]", 0, 2)] {
    let (path, start, end) = probe
    assert_eq(
      @docx.docx_paragraph_direct_format(
        reread,
        reread.main_story_source(),
        path~,
        start~,
        end~,
        format=@docx.docx_direct_format(bold=true),
      ),
      None,
      msg=path,
    )
  }
}

///|
test "format selects one candidate by ordinal" {
  let body = "<w:p><w:r><w:t>ab ab ab</w:t></w:r></w:p>"
  let annotated = format_fixture(body)
  let (plan, receipt) = @docx.plan_docx_format(
    annotated,
    annotated.main_story_source(),
    format=@docx.docx_direct_format(bold=true),
    text="ab",
    nth=2,
  )
  debug_inspect(receipt.selected(), content="[2]")
  assert_eq(receipt.spans()[0].start(), 3)
  let reread = format_apply(body, plan)
  assert_eq(
    @docx.docx_paragraph_direct_format(
      reread,
      reread.main_story_source(),
      path="p[1]",
      start=3,
      end=5,
      format=@docx.docx_direct_format(bold=true),
    ),
    None,
  )
  assert_true(
    @docx.docx_paragraph_direct_format(
      reread,
      reread.main_story_source(),
      path="p[1]",
      start=0,
      end=2,
      format=@docx.docx_direct_format(bold=true),
    )
    is Some(_),
  )
}

///|
test "format plans nothing when the request already holds" {
  let annotated = format_fixture(
    "<w:p><w:r><w:rPr><w:b/><w:bCs/></w:rPr><w:t>Hello</w:t></w:r></w:p>",
  )
  let (_, receipt) = @docx.plan_docx_format(
    annotated,
    annotated.main_story_source(),
    format=@docx.docx_direct_format(bold=true),
    text="ell",
  )
  assert_eq(receipt.byte_edits(), 0)
  assert_eq(receipt.runs_changed(), 0)
  assert_eq(receipt.runs_already_satisfied(), 1)
  assert_eq(receipt.splits(), 0)
  // The span is still SELECTED — a no-op suppresses planning, never
  // selection or validation.
  assert_eq(receipt.spans().length(), 1)
}

///|
test "format reports zero candidates without planning" {
  let annotated = format_fixture("<w:p><w:r><w:t>Hello</w:t></w:r></w:p>")
  let (_, receipt) = @docx.plan_docx_format(
    annotated,
    annotated.main_story_source(),
    format=@docx.docx_direct_format(bold=true),
    text="absent",
  )
  assert_eq(receipt.spans().length(), 0)
  assert_eq(receipt.byte_edits(), 0)
  debug_inspect(receipt.selected(), content="[]")
}

///|
test "format formats what replace cannot: a hyperlink-boundary span" {
  // The candidate crosses a hyperlink boundary, so find reports it as
  // NOT actionable — that is the replacement verdict. Formatting has
  // its own, and this span is perfectly formattable.
  let body = "<w:p><w:r><w:t>ab</w:t></w:r><w:hyperlink r:id=\"rId9\"><w:r><w:t>cd</w:t></w:r></w:hyperlink></w:p>"
  let annotated = format_fixture(body)
  let found = @docx.find_docx_matches(
    annotated,
    annotated.main_story_source(),
    needle="bc",
  )
  assert_eq(found.matches().length(), 1)
  assert_false(found.matches()[0].actionable())
  let (plan, receipt) = @docx.plan_docx_format(
    annotated,
    annotated.main_story_source(),
    format=@docx.docx_direct_format(bold=true),
    text="bc",
  )
  assert_eq(receipt.runs_changed(), 2)
  let reread = format_apply(body, plan)
  assert_eq(
    @docx.docx_paragraph_direct_format(
      reread,
      reread.main_story_source(),
      path="p[1]",
      start=1,
      end=3,
      format=@docx.docx_direct_format(bold=true),
    ),
    None,
  )
}

///|
test "format refuses selector and scope mistakes" {
  let annotated = format_fixture("<w:p><w:r><w:t>Hello</w:t></w:r></w:p>")
  fn refuse(
    text : String?,
    within : String?,
    nth : Int?,
    range : (Int, Int)?,
  ) -> String raise {
    let mut message = ""
    try
      @docx.plan_docx_format(
        annotated,
        annotated.main_story_source(),
        format=@docx.docx_direct_format(bold=true),
        text?,
        within?,
        nth?,
        range?,
      )
      |> ignore
    catch {
      error => message = repr(error)
    } noraise {
      _ => fail("expected a refusal")
    }
    message
  }

  // Neither selector, both selectors, nth with a range.
  assert_true(refuse(None, None, None, None).contains("exactly one selector"))
  assert_true(
    refuse(Some("Hello"), Some("p[1]"), None, Some((0, 1))).contains(
      "exactly one selector",
    ),
  )
  assert_true(
    refuse(None, Some("p[1]"), Some(1), Some((0, 1))).contains(
      "nth selects among",
    ),
  )
  // A range needs its paragraph, and the paragraph must exist.
  assert_true(
    refuse(None, None, None, Some((0, 1))).contains("needs the paragraph"),
  )
  assert_true(
    refuse(None, Some("p[9]"), None, Some((0, 1))).contains(
      "does not name a paragraph",
    ),
  )
  // Range bounds are checked against the paragraph's own width.
  assert_true(
    refuse(None, Some("p[1]"), None, Some((0, 99))).contains("is outside"),
  )
  assert_true(
    refuse(None, Some("p[1]"), None, Some((2, 2))).contains("is outside"),
  )
  // A structural refusal from the planner aborts the batch.
  let tabbed = format_fixture(
    "<w:p><w:r><w:t>a</w:t><w:tab/><w:t>b</w:t></w:r></w:p>",
  )
  let mut message = ""
  try
    @docx.plan_docx_format(
      tabbed,
      tabbed.main_story_source(),
      format=@docx.docx_direct_format(bold=true),
      within="p[1]",
      range=(0, 3),
    )
    |> ignore
  catch {
    error => message = repr(error)
  } noraise {
    _ => fail("expected a planner refusal")
  }
  assert_true(message.contains("projected-atom"), msg=message)
}

///|
test "format plans are pinned to the read they were planned against" {
  let annotated = format_fixture("<w:p><w:r><w:t>Hello</w:t></w:r></w:p>")
  let (plan, _) = @docx.plan_docx_format(
    annotated,
    annotated.main_story_source(),
    format=@docx.docx_direct_format(bold=true),
    text="Hello",
  )
  // Applying to a DIFFERENT snapshot refuses as stale.
  let mut message = ""
  try
    @splice.splice_docx_archive(
      try! @mbtzip.read(
        fixture_docx(
          format_fixture_body("<w:p><w:r><w:t>Goodbye</w:t></w:r></w:p>"),
        ),
      ),
      plan,
      max_output_bytes=1 << 22,
    )
    |> ignore
  catch {
    error => message = repr(error)
  } noraise {
    _ => fail("expected a stale-plan refusal")
  }
  assert_true(message.length() > 0)
}
