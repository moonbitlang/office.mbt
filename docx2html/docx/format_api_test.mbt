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

///|
/// Round 1's Critical: a tolerated nested paragraph makes two logical
/// paragraphs share one path. Formatting refuses that address rather
/// than picking a claimant — in both selector modes.
test "format refuses a path two logical paragraphs claim" {
  let annotated = format_fixture(
    "<w:p><w:r><w:t>same</w:t></w:r><w:p><w:r><w:t>same</w:t></w:r></w:p></w:p>",
  )
  let mut text_message = ""
  try
    @docx.plan_docx_format(
      annotated,
      annotated.main_story_source(),
      format=@docx.docx_direct_format(bold=true),
      text="same",
    )
    |> ignore
  catch {
    error => text_message = repr(error)
  } noraise {
    _ => fail("expected an ambiguous-address refusal")
  }
  assert_true(text_message.contains("logical paragraphs"), msg=text_message)
  let mut range_message = ""
  try
    @docx.plan_docx_format(
      annotated,
      annotated.main_story_source(),
      format=@docx.docx_direct_format(bold=true),
      within="p[1]",
      range=(0, 4),
    )
    |> ignore
  catch {
    error => range_message = repr(error)
  } noraise {
    _ => fail("expected an ambiguous-address refusal")
  }
  assert_true(range_message.contains("logical paragraphs"), msg=range_message)
}

///|
/// The receipt echoes the selector the caller used, so a report can
/// reconstruct the request — including the distinction a count cannot
/// make, between "all candidates, and there was one" and `nth=1`.
test "format receipts echo their selector" {
  let annotated = format_fixture(
    "<w:p><w:r><w:t>ab ab</w:t></w:r></w:p><w:p><w:r><w:t>ab</w:t></w:r></w:p>",
  )
  let (_, all) = @docx.plan_docx_format(
    annotated,
    annotated.main_story_source(),
    format=@docx.docx_direct_format(bold=true),
    text="ab",
    within="p[1]",
  )
  assert_eq(all.requested_text(), Some("ab"))
  assert_eq(all.requested_within(), Some("p[1]"))
  assert_eq(all.requested_nth(), None)
  assert_eq(all.requested_range(), None)
  debug_inspect(all.selected(), content="[1, 2]")
  // The distinction a count cannot make: ONE candidate selected
  // implicitly, versus the same one selected by ordinal. Both receipts
  // carry one span; only the echo tells them apart.
  let (_, implicit) = @docx.plan_docx_format(
    annotated,
    annotated.main_story_source(),
    format=@docx.docx_direct_format(bold=true),
    text="ab",
    within="p[2]",
  )
  assert_eq(implicit.spans().length(), 1)
  assert_eq(implicit.requested_nth(), None)
  let (_, single) = @docx.plan_docx_format(
    annotated,
    annotated.main_story_source(),
    format=@docx.docx_direct_format(bold=true),
    text="ab",
    within="p[2]",
    nth=1,
  )
  assert_eq(single.spans().length(), 1)
  assert_eq(single.requested_nth(), Some(1))
  assert_eq(single.requested_within(), Some("p[2]"))
  // A zero-candidate receipt still says what was asked for.
  let (_, empty) = @docx.plan_docx_format(
    annotated,
    annotated.main_story_source(),
    format=@docx.docx_direct_format(bold=true),
    text="absent",
  )
  assert_eq(empty.spans().length(), 0)
  assert_eq(empty.requested_text(), Some("absent"))
  // Range mode echoes its coordinates.
  let (_, ranged) = @docx.plan_docx_format(
    annotated,
    annotated.main_story_source(),
    format=@docx.docx_direct_format(bold=true),
    within="p[2]",
    range=(0, 2),
  )
  assert_eq(ranged.requested_range(), Some((0, 2)))
  assert_eq(ranged.requested_text(), None)
}

///|
/// Several spans in ONE paragraph are planned as one batch, and a
/// refusal anywhere in the batch aborts everything — formatting never
/// half-applies what it selected.
test "format batches many spans per paragraph and aborts as a whole" {
  let body = "<w:p><w:r><w:t>ab cd ab</w:t></w:r></w:p>"
  let annotated = format_fixture(body)
  let (plan, receipt) = @docx.plan_docx_format(
    annotated,
    annotated.main_story_source(),
    format=@docx.docx_direct_format(bold=true),
    text="ab",
  )
  debug_inspect(receipt.selected(), content="[1, 2]")
  assert_eq(receipt.affected().length(), 1)
  assert_eq(receipt.affected()[0].splits(), 1)
  let reread = format_apply(body, plan)
  for probe in [(0, 2), (6, 8)] {
    let (start, end) = probe
    assert_eq(
      @docx.docx_paragraph_direct_format(
        reread,
        reread.main_story_source(),
        path="p[1]",
        start~,
        end~,
        format=@docx.docx_direct_format(bold=true),
      ),
      None,
    )
  }
  // A later candidate that refuses aborts the earlier valid one too: no
  // plan is returned at all.
  let mixed = format_fixture(
    "<w:p><w:r><w:t>ab</w:t></w:r></w:p><w:p><w:ins w:id=\"1\" w:author=\"a\" w:date=\"2020-01-01T00:00:00Z\"><w:r><w:t>ab</w:t></w:r></w:ins></w:p>",
  )
  let mut message = ""
  try
    @docx.plan_docx_format(
      mixed,
      mixed.main_story_source(),
      format=@docx.docx_direct_format(bold=true),
      text="ab",
    )
    |> ignore
  catch {
    error => message = repr(error)
  } noraise {
    _ => fail("expected the batch to abort")
  }
  assert_true(message.contains("restricted-region"), msg=message)
}

///|
/// The preservation readback proves the negative the positive check
/// cannot: formatting stayed inside its spans. A faithful edit passes;
/// a whole-run edit where a split was required is caught even though
/// the projection is unchanged.
test "format preservation readback catches formatting outside the span" {
  let body = "<w:p><w:r><w:t>alpha</w:t></w:r></w:p>"
  let annotated = format_fixture(body)
  let (plan, _) = @docx.plan_docx_format(
    annotated,
    annotated.main_story_source(),
    format=@docx.docx_direct_format(bold=true),
    within="p[1]",
    range=(0, 2),
  )
  let faithful = format_apply(body, plan)
  assert_eq(
    @docx.docx_paragraph_format_preserved(
      annotated,
      annotated.main_story_source(),
      faithful,
      faithful.main_story_source(),
      path="p[1]",
      spans=[(0, 2)],
    ),
    None,
  )
  // The sabotage: the SAME span formatted by rewriting the whole run.
  let sabotaged = @docx.read_docx_annotated(
    fixture_docx(
      format_fixture_body(
        "<w:p><w:r><w:rPr><w:b/><w:bCs/></w:rPr><w:t>alpha</w:t></w:r></w:p>",
      ),
    ),
  )
  // The positive check still passes — the span really is bold...
  assert_eq(
    @docx.docx_paragraph_direct_format(
      sabotaged,
      sabotaged.main_story_source(),
      path="p[1]",
      start=0,
      end=2,
      format=@docx.docx_direct_format(bold=true),
    ),
    None,
  )
  // ...and the projection is unchanged. Only provenance catches it.
  assert_true(
    @docx.docx_paragraph_format_preserved(
      annotated,
      annotated.main_story_source(),
      sabotaged,
      sabotaged.main_story_source(),
      path="p[1]",
      spans=[(0, 2)],
    )
    is Some(_),
  )
}

///|
/// Text mode is body-only in v1, and so is range mode: a range into
/// another story would carry body addressing metadata that is false.
test "format edits the body story only" {
  // A fixture with a comments story, so a non-body source exists.
  let annotated = @docx.read_docx_annotated(
    fixture_docx(
      format_fixture_body("<w:p><w:r><w:t>Hello</w:t></w:r></w:p>"),
      comments_xml=Some(
        "<w:comments xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:comment w:id=\"0\"><w:p><w:r><w:t>note</w:t></w:r></w:p></w:comment></w:comments>",
      ),
      footnotes_xml=Some(
        "<w:footnotes xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:footnote w:id=\"1\"><w:p><w:r><w:t>foot</w:t></w:r></w:p></w:footnote></w:footnotes>",
      ),
    ),
  )
  let others : Array[@docx.DocxStoryPartSource] = []
  if annotated.comments_story_source() is Some(comments) {
    others.push(comments)
  }
  if annotated.footnotes_story_source() is Some(footnotes) {
    others.push(footnotes)
  }
  for source in annotated.header_story_sources() {
    others.push(source)
  }
  assert_true(others.length() > 0, msg="the fixture has no non-body story")
  for source in others {
    let mut message = ""
    try
      @docx.plan_docx_format(
        annotated,
        source,
        format=@docx.docx_direct_format(bold=true),
        within="p[1]",
        range=(0, 1),
      )
      |> ignore
    catch {
      error => message = repr(error)
    } noraise {
      _ => fail("expected a body-only refusal for " + source.part())
    }
    assert_true(message.contains("body story only"), msg=message)
  }
}

///|
/// An out-of-bounds ordinal names the count it exceeded.
test "format refuses an ordinal beyond the candidate count" {
  let annotated = format_fixture("<w:p><w:r><w:t>ab ab</w:t></w:r></w:p>")
  let mut message = ""
  try
    @docx.plan_docx_format(
      annotated,
      annotated.main_story_source(),
      format=@docx.docx_direct_format(bold=true),
      text="ab",
      nth=3,
    )
    |> ignore
  catch {
    error => message = repr(error)
  } noraise {
    _ => fail("expected an ordinal refusal")
  }
  assert_true(message.contains("2 candidate"), msg=message)
}

///|
/// Round 2's High and Medium: preservation is judged PER PROJECTION
/// UNIT, so a split cannot look like a change, a discontinuous
/// tolerated run cannot false-fail, and a text-less run cannot be
/// formatted unnoticed.
test "format preservation is per-unit, not per-run" {
  // A faithful split preserves every unit outside the span.
  let body = "<w:p><w:r><w:t>alphabet</w:t></w:r></w:p>"
  let annotated = format_fixture(body)
  let (plan, _) = @docx.plan_docx_format(
    annotated,
    annotated.main_story_source(),
    format=@docx.docx_direct_format(bold=true),
    within="p[1]",
    range=(2, 5),
  )
  let after = format_apply(body, plan)
  assert_eq(
    @docx.docx_paragraph_format_preserved(
      annotated,
      annotated.main_story_source(),
      after,
      after.main_story_source(),
      path="p[1]",
      spans=[(2, 5)],
    ),
    None,
  )
  // An already-satisfied run that legitimately stays UNSPLIT passes,
  // even though it straddles the span.
  let satisfied = "<w:p><w:r><w:rPr><w:b/><w:bCs/></w:rPr><w:t>alphabet</w:t></w:r></w:p>"
  let satisfied_read = format_fixture(satisfied)
  let (satisfied_plan, satisfied_receipt) = @docx.plan_docx_format(
    satisfied_read,
    satisfied_read.main_story_source(),
    format=@docx.docx_direct_format(bold=true),
    within="p[1]",
    range=(2, 5),
  )
  assert_eq(satisfied_receipt.byte_edits(), 0)
  let satisfied_after = format_apply(satisfied, satisfied_plan)
  assert_eq(
    @docx.docx_paragraph_format_preserved(
      satisfied_read,
      satisfied_read.main_story_source(),
      satisfied_after,
      satisfied_after.main_story_source(),
      path="p[1]",
      spans=[(2, 5)],
    ),
    None,
  )
  // A TEXT-LESS run formatted as collateral is caught, though it
  // projects nothing and every other check passes.
  let with_reference = "<w:p><w:r><w:t>ab</w:t></w:r><w:r><w:footnoteReference w:id=\"1\"/></w:r></w:p>"
  let reference_read = format_fixture(with_reference)
  let collateral = format_fixture(
    "<w:p><w:r><w:t>ab</w:t></w:r><w:r><w:rPr><w:b/><w:bCs/></w:rPr><w:footnoteReference w:id=\"1\"/></w:r></w:p>",
  )
  assert_true(
    @docx.docx_paragraph_format_preserved(
      reference_read,
      reference_read.main_story_source(),
      collateral,
      collateral.main_story_source(),
      path="p[1]",
      spans=[(0, 2)],
    )
    is Some(_),
  )
}

///|
/// Both readback accessors refuse a collided path rather than
/// answering for a claimant, and a binding they cannot vouch for is a
/// discrepancy rather than a raise.
test "format readbacks refuse what they cannot answer for" {
  let collided = format_fixture(
    "<w:p><w:r><w:t>same</w:t></w:r><w:p><w:r><w:t>same</w:t></w:r></w:p></w:p>",
  )
  assert_true(
    @docx.docx_paragraph_direct_format(
      collided,
      collided.main_story_source(),
      path="p[1]",
      start=0,
      end=4,
      format=@docx.docx_direct_format(bold=true),
    )
    is Some(_),
  )
  assert_true(
    @docx.docx_paragraph_format_preserved(
      collided,
      collided.main_story_source(),
      collided,
      collided.main_story_source(),
      path="p[1]",
      spans=[(0, 4)],
    )
    is Some(_),
  )
  // A default-namespace run has no vouchable attribute binding: the
  // readback reports that instead of raising.
  let default_ns = @docx.read_docx_annotated(
    fixture_docx(
      "<document xmlns=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><body><p><r><t>ab</t></r></p><sectPr/></body></document>",
    ),
  )
  let verdict = @docx.docx_paragraph_direct_format(
    default_ns,
    default_ns.main_story_source(),
    path="p[1]",
    start=0,
    end=2,
    format=@docx.docx_direct_format(bold=true),
  )
  assert_true(verdict is Some(_))
}
