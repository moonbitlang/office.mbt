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
      format=@docx.docx_direct_format(bold=true),
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
      format=@docx.docx_direct_format(bold=true),
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
      format=@docx.docx_direct_format(bold=true),
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
      format=@docx.docx_direct_format(bold=true),
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
      format=@docx.docx_direct_format(bold=true),
    )
    is Some(_),
  )
}

///|
/// Both readback accessors refuse a collided path rather than
/// answering for a claimant, and a binding they cannot vouch for is a
/// discrepancy rather than a raise.
test "format readbacks refuse what they cannot answer for" {
  // BOTH claimants already satisfy the request, so a first-claimant
  // regression would answer None: only the collision refusal can make
  // this Some, and it must say so by name.
  let collided = format_fixture(
    "<w:p><w:r><w:rPr><w:b/><w:bCs/></w:rPr><w:t>same</w:t></w:r><w:p><w:r><w:rPr><w:b/><w:bCs/></w:rPr><w:t>same</w:t></w:r></w:p></w:p>",
  )
  let collided_verdict = @docx.docx_paragraph_direct_format(
    collided,
    collided.main_story_source(),
    path="p[1]",
    start=0,
    end=4,
    format=@docx.docx_direct_format(bold=true),
  )
  assert_true(collided_verdict is Some(_))
  guard collided_verdict is Some(collided_message) else {
    fail("expected a collision discrepancy")
  }
  assert_true(
    collided_message.contains("logical paragraphs"),
    msg=collided_message,
  )
  assert_true(
    @docx.docx_paragraph_format_preserved(
      collided,
      collided.main_story_source(),
      collided,
      collided.main_story_source(),
      path="p[1]",
      spans=[(0, 4)],
      format=@docx.docx_direct_format(bold=true),
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

///|
/// Round 3's High: an omitted property means UNTOUCHED, so preservation
/// must judge selected units too — only the properties the request
/// names may differ there.
test "format preservation guards unrelated properties inside spans" {
  let before = format_fixture(
    "<w:p><w:r><w:rPr><w:i/><w:iCs/></w:rPr><w:t>ab</w:t></w:r></w:p>",
  )
  // Bold arrives, italic vanishes: the projection is unchanged and
  // bold really does hold, so only preservation can catch it.
  let clobbered = format_fixture(
    "<w:p><w:r><w:rPr><w:b/><w:bCs/></w:rPr><w:t>ab</w:t></w:r></w:p>",
  )
  assert_eq(
    @docx.docx_paragraph_direct_format(
      clobbered,
      clobbered.main_story_source(),
      path="p[1]",
      start=0,
      end=2,
      format=@docx.docx_direct_format(bold=true),
    ),
    None,
  )
  assert_true(
    @docx.docx_paragraph_format_preserved(
      before,
      before.main_story_source(),
      clobbered,
      clobbered.main_story_source(),
      path="p[1]",
      spans=[(0, 2)],
      format=@docx.docx_direct_format(bold=true),
    )
    is Some(_),
  )
  // The faithful edit — bold added, italic kept — preserves.
  let faithful = format_fixture(
    "<w:p><w:r><w:rPr><w:b/><w:bCs/><w:i/><w:iCs/></w:rPr><w:t>ab</w:t></w:r></w:p>",
  )
  assert_eq(
    @docx.docx_paragraph_format_preserved(
      before,
      before.main_story_source(),
      faithful,
      faithful.main_story_source(),
      path="p[1]",
      spans=[(0, 2)],
      format=@docx.docx_direct_format(bold=true),
    ),
    None,
  )
  // And the real planner's own output preserves.
  let body = "<w:p><w:r><w:rPr><w:i/><w:iCs/></w:rPr><w:t>abcd</w:t></w:r></w:p>"
  let source_read = format_fixture(body)
  let (plan, _) = @docx.plan_docx_format(
    source_read,
    source_read.main_story_source(),
    format=@docx.docx_direct_format(bold=true),
    within="p[1]",
    range=(1, 3),
  )
  let planned = format_apply(body, plan)
  assert_eq(
    @docx.docx_paragraph_format_preserved(
      source_read,
      source_read.main_story_source(),
      planned,
      planned.main_story_source(),
      path="p[1]",
      spans=[(1, 3)],
      format=@docx.docx_direct_format(bold=true),
    ),
    None,
  )
}

///|
/// Round 3's Medium: a split legitimately re-homes an empty text
/// element into its own clone. That clone paints nothing, so it is not
/// collateral and preservation must not false-fail on it.
test "format preservation tolerates a split's empty text clone" {
  let body = "<w:p><w:r><w:t></w:t><w:t>abc</w:t></w:r></w:p>"
  let annotated = format_fixture(body)
  let (plan, _) = @docx.plan_docx_format(
    annotated,
    annotated.main_story_source(),
    format=@docx.docx_direct_format(bold=true),
    within="p[1]",
    range=(0, 1),
  )
  let after = format_apply(body, plan)
  assert_eq(
    @docx.docx_paragraph_format_preserved(
      annotated,
      annotated.main_story_source(),
      after,
      after.main_story_source(),
      path="p[1]",
      spans=[(0, 1)],
      format=@docx.docx_direct_format(bold=true),
    ),
    None,
  )
}

///|
/// Round 4's Highs and Medium: the checks must not pass on a document
/// that cannot hold the formatting, must not lose an rPr's own
/// attributes, and must not false-fail legal spellings the planner
/// itself produces.
test "format readbacks judge coverage, shells, and spellings" {
  // A selected unit carried by NO run cannot hold direct formatting,
  // even though a neighbouring run satisfies the request.
  let runless = format_fixture(
    "<w:p><w:t>a</w:t><w:r><w:rPr><w:b/><w:bCs/></w:rPr><w:t>b</w:t></w:r></w:p>",
  )
  let verdict = @docx.docx_paragraph_direct_format(
    runless,
    runless.main_story_source(),
    path="p[1]",
    start=0,
    end=2,
    format=@docx.docx_direct_format(bold=true),
  )
  assert_true(verdict is Some(_))
  guard verdict is Some(message) else { fail("expected a coverage verdict") }
  assert_true(message.contains("not carried by any run"), msg=message)
  // An rPr's OWN attributes are not part of the empty-shell
  // equivalence: changing one while adding bold is still a change
  // nobody asked for.
  let shell_before = format_fixture(
    "<w:p><w:r><w:rPr w14:textId=\"A\"></w:rPr><w:t>ab</w:t></w:r></w:p>",
  )
  let shell_after = format_fixture(
    "<w:p><w:r><w:rPr w14:textId=\"B\"><w:b/><w:bCs/></w:rPr><w:t>ab</w:t></w:r></w:p>",
  )
  assert_true(
    @docx.docx_paragraph_format_preserved(
      shell_before,
      shell_before.main_story_source(),
      shell_after,
      shell_after.main_story_source(),
      path="p[1]",
      spans=[(0, 2)],
      format=@docx.docx_direct_format(bold=true),
    )
    is Some(_),
  )
  // The same attribute kept is faithful.
  let shell_kept = format_fixture(
    "<w:p><w:r><w:rPr w14:textId=\"A\"><w:b/><w:bCs/></w:rPr><w:t>ab</w:t></w:r></w:p>",
  )
  assert_eq(
    @docx.docx_paragraph_format_preserved(
      shell_before,
      shell_before.main_story_source(),
      shell_kept,
      shell_kept.main_story_source(),
      path="p[1]",
      spans=[(0, 2)],
      format=@docx.docx_direct_format(bold=true),
    ),
    None,
  )
  // A self-closing rPr the planner expands, and a close tag spelled
  // with whitespace, are both faithful.
  for
    spelling in [
      "<w:p><w:r><w:rPr/><w:t>ab</w:t></w:r></w:p>", "<w:p><w:r><w:rPr ></w:rPr ><w:t>ab</w:t></w:r></w:p>",
    ] {
    let before = format_fixture(spelling)
    let (plan, _) = @docx.plan_docx_format(
      before,
      before.main_story_source(),
      format=@docx.docx_direct_format(bold=true),
      within="p[1]",
      range=(0, 2),
    )
    let after = format_apply(spelling, plan)
    assert_eq(
      @docx.docx_paragraph_format_preserved(
        before,
        before.main_story_source(),
        after,
        after.main_story_source(),
        path="p[1]",
        spans=[(0, 2)],
        format=@docx.docx_direct_format(bold=true),
      ),
      None,
      msg=spelling,
    )
    assert_eq(
      @docx.docx_paragraph_direct_format(
        after,
        after.main_story_source(),
        path="p[1]",
        start=0,
        end=2,
        format=@docx.docx_direct_format(bold=true),
      ),
      None,
      msg=spelling,
    )
  }
}

///|
/// Round 5: the paragraph MARK carries formatting of its own in
/// `w:pPr/w:rPr`. It projects nothing, so no unit or run speaks for it,
/// and no v1 request touches it — a change there is collateral.
test "format preservation guards the paragraph mark" {
  let before = format_fixture(
    "<w:p><w:pPr><w:rPr><w:i/><w:iCs/></w:rPr></w:pPr><w:r><w:t>ab</w:t></w:r></w:p>",
  )
  // Bold arrives on the run as asked, but the mark's italic became an
  // underline: projection and the positive check both pass.
  let clobbered = format_fixture(
    "<w:p><w:pPr><w:rPr><w:u w:val=\"single\"/></w:rPr></w:pPr><w:r><w:rPr><w:b/><w:bCs/></w:rPr><w:t>ab</w:t></w:r></w:p>",
  )
  assert_eq(
    @docx.docx_paragraph_direct_format(
      clobbered,
      clobbered.main_story_source(),
      path="p[1]",
      start=0,
      end=2,
      format=@docx.docx_direct_format(bold=true),
    ),
    None,
  )
  let verdict = @docx.docx_paragraph_format_preserved(
    before,
    before.main_story_source(),
    clobbered,
    clobbered.main_story_source(),
    path="p[1]",
    spans=[(0, 2)],
    format=@docx.docx_direct_format(bold=true),
  )
  assert_true(verdict is Some(_))
  guard verdict is Some(message) else { fail("expected a mark discrepancy") }
  assert_true(message.contains("paragraph mark"), msg=message)
  // The planner's own output keeps the mark untouched.
  let body = "<w:p><w:pPr><w:rPr><w:i/><w:iCs/></w:rPr></w:pPr><w:r><w:t>ab</w:t></w:r></w:p>"
  let (plan, _) = @docx.plan_docx_format(
    before,
    before.main_story_source(),
    format=@docx.docx_direct_format(bold=true),
    within="p[1]",
    range=(0, 2),
  )
  let after = format_apply(body, plan)
  assert_eq(
    @docx.docx_paragraph_format_preserved(
      before,
      before.main_story_source(),
      after,
      after.main_story_source(),
      path="p[1]",
      spans=[(0, 2)],
      format=@docx.docx_direct_format(bold=true),
    ),
    None,
  )
}

///|
/// Round 5's Low: a longer name that merely starts with a shorter one
/// must not be counted as it. Without the name-boundary check the
/// depth walk mis-parses this rPr and reports a difference where there
/// is none.
test "format preservation distinguishes rPrChange from rPr" {
  let before = format_fixture(
    "<w:p><w:r><w:rPr><w:rPrChange w:id=\"1\" w:author=\"a\" w:date=\"2020-01-01T00:00:00Z\"/><w:b/></w:rPr><w:t>ab</w:t></w:r></w:p>",
  )
  let after = format_fixture(
    "<w:p><w:r><w:rPr><w:rPrChange w:id=\"1\" w:author=\"a\" w:date=\"2020-01-01T00:00:00Z\"/><w:b/><w:bCs/></w:rPr><w:t>ab</w:t></w:r></w:p>",
  )
  // Only bold-family children differ, and bold is what was requested.
  assert_eq(
    @docx.docx_paragraph_format_preserved(
      before,
      before.main_story_source(),
      after,
      after.main_story_source(),
      path="p[1]",
      spans=[(0, 2)],
      format=@docx.docx_direct_format(bold=true),
    ),
    None,
  )
  // A change to the tracked-change record itself is not bold's to make.
  let tampered = format_fixture(
    "<w:p><w:r><w:rPr><w:rPrChange w:id=\"2\" w:author=\"a\" w:date=\"2020-01-01T00:00:00Z\"/><w:b/><w:bCs/></w:rPr><w:t>ab</w:t></w:r></w:p>",
  )
  assert_true(
    @docx.docx_paragraph_format_preserved(
      before,
      before.main_story_source(),
      tampered,
      tampered.main_story_source(),
      path="p[1]",
      spans=[(0, 2)],
      format=@docx.docx_direct_format(bold=true),
    )
    is Some(_),
  )
}

///|
/// Round 6: a request authorizes only the ATTRIBUTES it needs. An
/// underline may change its `val`; its colour is nobody's to touch, and
/// an absolute colour may drop theme linkage but keep the rest.
test "format preservation authorizes attributes, not whole properties" {
  let before = format_fixture(
    "<w:p><w:r><w:rPr><w:u w:val=\"double\" w:color=\"FF0000\"/></w:rPr><w:t>ab</w:t></w:r></w:p>",
  )
  // The planner's own output: val becomes single, the colour survives.
  let (plan, _) = @docx.plan_docx_format(
    before,
    before.main_story_source(),
    format=@docx.docx_direct_format(underline=true),
    within="p[1]",
    range=(0, 2),
  )
  let faithful = format_apply(
    "<w:p><w:r><w:rPr><w:u w:val=\"double\" w:color=\"FF0000\"/></w:rPr><w:t>ab</w:t></w:r></w:p>",
    plan,
  )
  assert_eq(
    @docx.docx_paragraph_format_preserved(
      before,
      before.main_story_source(),
      faithful,
      faithful.main_story_source(),
      path="p[1]",
      spans=[(0, 2)],
      format=@docx.docx_direct_format(underline=true),
    ),
    None,
  )
  // A result that also repainted the underline's colour passes the
  // positive check and the projection, and is caught here.
  let recoloured = format_fixture(
    "<w:p><w:r><w:rPr><w:u w:val=\"single\" w:color=\"00FF00\"/></w:rPr><w:t>ab</w:t></w:r></w:p>",
  )
  assert_eq(
    @docx.docx_paragraph_direct_format(
      recoloured,
      recoloured.main_story_source(),
      path="p[1]",
      start=0,
      end=2,
      format=@docx.docx_direct_format(underline=true),
    ),
    None,
  )
  assert_true(
    @docx.docx_paragraph_format_preserved(
      before,
      before.main_story_source(),
      recoloured,
      recoloured.main_story_source(),
      path="p[1]",
      spans=[(0, 2)],
      format=@docx.docx_direct_format(underline=true),
    )
    is Some(_),
  )
  // An absolute colour legitimately drops theme linkage.
  let themed = format_fixture(
    "<w:p><w:r><w:rPr><w:color w:val=\"auto\" w:themeColor=\"accent1\"/></w:rPr><w:t>ab</w:t></w:r></w:p>",
  )
  let (colour_plan, _) = @docx.plan_docx_format(
    themed,
    themed.main_story_source(),
    format=@docx.docx_direct_format(color="00B050"),
    within="p[1]",
    range=(0, 2),
  )
  let coloured = format_apply(
    "<w:p><w:r><w:rPr><w:color w:val=\"auto\" w:themeColor=\"accent1\"/></w:rPr><w:t>ab</w:t></w:r></w:p>",
    colour_plan,
  )
  assert_eq(
    @docx.docx_paragraph_format_preserved(
      themed,
      themed.main_story_source(),
      coloured,
      coloured.main_story_source(),
      path="p[1]",
      spans=[(0, 2)],
      format=@docx.docx_direct_format(color="00B050"),
    ),
    None,
  )
}

///|
/// Round 6: the reader takes the FIRST pPr and the planner refuses
/// none, so a trailing empty one must not erase an earlier mark's
/// formatting from the comparison.
test "format preservation reads every paragraph mark" {
  let before = format_fixture(
    "<w:p><w:pPr><w:rPr><w:i/><w:iCs/></w:rPr></w:pPr><w:pPr/><w:r><w:t>ab</w:t></w:r></w:p>",
  )
  let clobbered = format_fixture(
    "<w:p><w:pPr><w:rPr><w:u w:val=\"single\"/></w:rPr></w:pPr><w:pPr/><w:r><w:rPr><w:b/><w:bCs/></w:rPr><w:t>ab</w:t></w:r></w:p>",
  )
  assert_true(
    @docx.docx_paragraph_format_preserved(
      before,
      before.main_story_source(),
      clobbered,
      clobbered.main_story_source(),
      path="p[1]",
      spans=[(0, 2)],
      format=@docx.docx_direct_format(bold=true),
    )
    is Some(_),
  )
}

///|
/// Round 7: preservation must see ALL of a paragraph's formatting —
/// paragraph properties beyond the mark's own rPr, and runs the reader
/// never registered because it suppressed their container.
test "format preservation sees paragraph properties and suppressed runs" {
  // Alignment is paragraph formatting no v1 request authorizes.
  let aligned = format_fixture(
    "<w:p><w:pPr><w:jc w:val=\"left\"/></w:pPr><w:r><w:t>ab</w:t></w:r></w:p>",
  )
  let realigned = format_fixture(
    "<w:p><w:pPr><w:jc w:val=\"right\"/></w:pPr><w:r><w:rPr><w:b/><w:bCs/></w:rPr><w:t>ab</w:t></w:r></w:p>",
  )
  assert_eq(
    @docx.docx_paragraph_direct_format(
      realigned,
      realigned.main_story_source(),
      path="p[1]",
      start=0,
      end=2,
      format=@docx.docx_direct_format(bold=true),
    ),
    None,
  )
  assert_true(
    @docx.docx_paragraph_format_preserved(
      aligned,
      aligned.main_story_source(),
      realigned,
      realigned.main_story_source(),
      path="p[1]",
      spans=[(0, 2)],
      format=@docx.docx_direct_format(bold=true),
    )
    is Some(_),
  )
  // A deleted run's properties are OOXML nobody asked to change, even
  // though the reader reduces its container to one suppressed trace.
  let deleted = format_fixture(
    "<w:p><w:r><w:t>ab</w:t></w:r><w:del w:id=\"1\" w:author=\"A\" w:date=\"2026-01-01T00:00:00Z\"><w:r><w:rPr><w:i/><w:iCs/></w:rPr><w:delText>x</w:delText></w:r></w:del></w:p>",
  )
  let repainted = format_fixture(
    "<w:p><w:r><w:rPr><w:b/><w:bCs/></w:rPr><w:t>ab</w:t></w:r><w:del w:id=\"1\" w:author=\"A\" w:date=\"2026-01-01T00:00:00Z\"><w:r><w:rPr><w:u w:val=\"single\"/></w:rPr><w:delText>x</w:delText></w:r></w:del></w:p>",
  )
  assert_eq(
    @docx.docx_paragraph_direct_format(
      repainted,
      repainted.main_story_source(),
      path="p[1]",
      start=0,
      end=2,
      format=@docx.docx_direct_format(bold=true),
    ),
    None,
  )
  assert_true(
    @docx.docx_paragraph_format_preserved(
      deleted,
      deleted.main_story_source(),
      repainted,
      repainted.main_story_source(),
      path="p[1]",
      spans=[(0, 2)],
      format=@docx.docx_direct_format(bold=true),
    )
    is Some(_),
  )
  // The planner's own faithful output over the same shapes preserves.
  let body = "<w:p><w:pPr><w:jc w:val=\"left\"/></w:pPr><w:r><w:t>ab</w:t></w:r><w:del w:id=\"1\" w:author=\"A\" w:date=\"2026-01-01T00:00:00Z\"><w:r><w:rPr><w:i/><w:iCs/></w:rPr><w:delText>x</w:delText></w:r></w:del></w:p>"
  let before = format_fixture(body)
  let (plan, _) = @docx.plan_docx_format(
    before,
    before.main_story_source(),
    format=@docx.docx_direct_format(bold=true),
    within="p[1]",
    range=(0, 2),
  )
  let after = format_apply(body, plan)
  assert_eq(
    @docx.docx_paragraph_format_preserved(
      before,
      before.main_story_source(),
      after,
      after.main_story_source(),
      path="p[1]",
      spans=[(0, 2)],
      format=@docx.docx_direct_format(bold=true),
    ),
    None,
  )
}

///|
/// The batched positive check answers for a whole paragraph's spans,
/// so a transaction pays for the carrier index once.
test "format verifies many spans of a paragraph together" {
  let body = "<w:p><w:r><w:t>ab cd ab</w:t></w:r></w:p>"
  let annotated = format_fixture(body)
  let (plan, receipt) = @docx.plan_docx_format(
    annotated,
    annotated.main_story_source(),
    format=@docx.docx_direct_format(bold=true),
    text="ab",
  )
  let after = format_apply(body, plan)
  let spans : Array[(Int, Int)] = []
  for span in receipt.spans() {
    spans.push((span.start(), span.end()))
  }
  assert_eq(
    @docx.docx_paragraph_direct_format_spans(
      after,
      after.main_story_source(),
      path="p[1]",
      spans~,
      format=@docx.docx_direct_format(bold=true),
    ),
    None,
  )
  // An unformatted span in the same batch is reported.
  assert_true(
    @docx.docx_paragraph_direct_format_spans(
      after,
      after.main_story_source(),
      path="p[1]",
      spans=[(0, 2), (3, 5)],
      format=@docx.docx_direct_format(bold=true),
    )
    is Some(_),
  )
}

///|
/// Round 8: paragraph properties can sit a level down — the reader
/// PROMOTES an mc:AlternateContent branch's children into the logical
/// paragraph — and a suppressed run's TEXT is content too, not an
/// empty shell a split may create.
test "format preservation sees promoted properties and suppressed text" {
  let mc = "xmlns:mc=\"http://schemas.openxmlformats.org/markup-compatibility/2006\""
  let promoted = format_fixture(
    "<w:p><mc:AlternateContent \{mc}><mc:Choice Requires=\"w14\"><w:pPr><w:jc w:val=\"left\"/></w:pPr></mc:Choice><mc:Fallback><w:pPr><w:jc w:val=\"left\"/></w:pPr></mc:Fallback></mc:AlternateContent><w:r><w:t>ab</w:t></w:r></w:p>",
  )
  let realigned = format_fixture(
    "<w:p><mc:AlternateContent \{mc}><mc:Choice Requires=\"w14\"><w:pPr><w:jc w:val=\"right\"/></w:pPr></mc:Choice><mc:Fallback><w:pPr><w:jc w:val=\"right\"/></w:pPr></mc:Fallback></mc:AlternateContent><w:r><w:rPr><w:b/><w:bCs/></w:rPr><w:t>ab</w:t></w:r></w:p>",
  )
  assert_true(
    @docx.docx_paragraph_format_preserved(
      promoted,
      promoted.main_story_source(),
      realigned,
      realigned.main_story_source(),
      path="p[1]",
      spans=[(0, 2)],
      format=@docx.docx_direct_format(bold=true),
    )
    is Some(_),
  )
  // A suppressed run holding real TEXT is content whose formatting
  // nobody asked to change.
  let deleted_text = format_fixture(
    "<w:p><w:r><w:t>ab</w:t></w:r><w:del w:id=\"1\" w:author=\"A\" w:date=\"2026-01-01T00:00:00Z\"><w:r><w:rPr><w:i/><w:iCs/></w:rPr><w:t>x</w:t></w:r></w:del></w:p>",
  )
  let repainted_text = format_fixture(
    "<w:p><w:r><w:rPr><w:b/><w:bCs/></w:rPr><w:t>ab</w:t></w:r><w:del w:id=\"1\" w:author=\"A\" w:date=\"2026-01-01T00:00:00Z\"><w:r><w:rPr><w:u w:val=\"single\"/></w:rPr><w:t>x</w:t></w:r></w:del></w:p>",
  )
  assert_true(
    @docx.docx_paragraph_format_preserved(
      deleted_text,
      deleted_text.main_story_source(),
      repainted_text,
      repainted_text.main_story_source(),
      path="p[1]",
      spans=[(0, 2)],
      format=@docx.docx_direct_format(bold=true),
    )
    is Some(_),
  )
  // And the split's empty-text clone is still tolerated.
  let body = "<w:p><w:r><w:t></w:t><w:t>abc</w:t></w:r></w:p>"
  let before = format_fixture(body)
  let (plan, _) = @docx.plan_docx_format(
    before,
    before.main_story_source(),
    format=@docx.docx_direct_format(bold=true),
    within="p[1]",
    range=(0, 1),
  )
  let after = format_apply(body, plan)
  assert_eq(
    @docx.docx_paragraph_format_preserved(
      before,
      before.main_story_source(),
      after,
      after.main_story_source(),
      path="p[1]",
      spans=[(0, 1)],
      format=@docx.docx_direct_format(bold=true),
    ),
    None,
  )
}

///|
/// Round 9: formatting carriers are not only runs and paragraph
/// properties. A content control's `sdtPr`/`sdtEndPr` hold run
/// properties too — and enumerating the CARRIER ELEMENT rather than a
/// list of known containers is what makes the inventory closed.
test "format preservation sees every run-property carrier" {
  let before = format_fixture(
    "<w:p><w:sdt><w:sdtPr/><w:sdtEndPr><w:rPr><w:i/><w:iCs/></w:rPr></w:sdtEndPr><w:sdtContent><w:r><w:t>x</w:t></w:r></w:sdtContent></w:sdt><w:r><w:t>ab</w:t></w:r></w:p>",
  )
  let repainted = format_fixture(
    "<w:p><w:sdt><w:sdtPr/><w:sdtEndPr><w:rPr><w:u w:val=\"single\"/></w:rPr></w:sdtEndPr><w:sdtContent><w:r><w:t>x</w:t></w:r></w:sdtContent></w:sdt><w:r><w:rPr><w:b/><w:bCs/></w:rPr><w:t>ab</w:t></w:r></w:p>",
  )
  // The projection and the positive check both accept it.
  assert_eq(
    @docx.docx_paragraph_direct_format(
      repainted,
      repainted.main_story_source(),
      path="p[1]",
      start=1,
      end=3,
      format=@docx.docx_direct_format(bold=true),
    ),
    None,
  )
  assert_true(
    @docx.docx_paragraph_format_preserved(
      before,
      before.main_story_source(),
      repainted,
      repainted.main_story_source(),
      path="p[1]",
      spans=[(1, 3)],
      format=@docx.docx_direct_format(bold=true),
    )
    is Some(_),
  )
  // The same carrier left alone is faithful.
  let faithful = format_fixture(
    "<w:p><w:sdt><w:sdtPr/><w:sdtEndPr><w:rPr><w:i/><w:iCs/></w:rPr></w:sdtEndPr><w:sdtContent><w:r><w:t>x</w:t></w:r></w:sdtContent></w:sdt><w:r><w:rPr><w:b/><w:bCs/></w:rPr><w:t>ab</w:t></w:r></w:p>",
  )
  assert_eq(
    @docx.docx_paragraph_format_preserved(
      before,
      before.main_story_source(),
      faithful,
      faithful.main_story_source(),
      path="p[1]",
      spans=[(1, 3)],
      format=@docx.docx_direct_format(bold=true),
    ),
    None,
  )
}

///|
/// Round 10: a nested paragraph answers for its own carriers only when
/// the reader REGISTERED it. One inside a suppressed container never
/// becomes a logical paragraph, so its carriers are this paragraph's
/// to compare.
test "format preservation descends into unregistered nested paragraphs" {
  let before = format_fixture(
    "<w:p><w:r><w:t>ab</w:t></w:r><w:del w:id=\"1\" w:author=\"A\" w:date=\"2026-01-01T00:00:00Z\"><w:p><w:pPr><w:rPr><w:i/><w:iCs/></w:rPr></w:pPr></w:p></w:del></w:p>",
  )
  let repainted = format_fixture(
    "<w:p><w:r><w:rPr><w:b/><w:bCs/></w:rPr><w:t>ab</w:t></w:r><w:del w:id=\"1\" w:author=\"A\" w:date=\"2026-01-01T00:00:00Z\"><w:p><w:pPr><w:rPr><w:u w:val=\"single\"/></w:rPr></w:pPr></w:p></w:del></w:p>",
  )
  assert_eq(
    @docx.docx_paragraph_direct_format(
      repainted,
      repainted.main_story_source(),
      path="p[1]",
      start=0,
      end=2,
      format=@docx.docx_direct_format(bold=true),
    ),
    None,
  )
  assert_true(
    @docx.docx_paragraph_format_preserved(
      before,
      before.main_story_source(),
      repainted,
      repainted.main_story_source(),
      path="p[1]",
      spans=[(0, 2)],
      format=@docx.docx_direct_format(bold=true),
    )
    is Some(_),
  )
  // A REGISTERED sibling paragraph still answers for itself: changing
  // its own formatting is not this paragraph's discrepancy.
  let sibling_before = format_fixture(
    "<w:p><w:r><w:t>ab</w:t></w:r></w:p><w:p><w:pPr><w:rPr><w:i/><w:iCs/></w:rPr></w:pPr><w:r><w:t>cd</w:t></w:r></w:p>",
  )
  let sibling_after = format_fixture(
    "<w:p><w:r><w:rPr><w:b/><w:bCs/></w:rPr><w:t>ab</w:t></w:r></w:p><w:p><w:pPr><w:rPr><w:u w:val=\"single\"/></w:rPr></w:pPr><w:r><w:t>cd</w:t></w:r></w:p>",
  )
  assert_eq(
    @docx.docx_paragraph_format_preserved(
      sibling_before,
      sibling_before.main_story_source(),
      sibling_after,
      sibling_after.main_story_source(),
      path="p[1]",
      spans=[(0, 2)],
      format=@docx.docx_direct_format(bold=true),
    ),
    None,
  )
}

///|
/// Round 11: formatting can MOVE between text-less runs while an
/// ordered list of carrier properties stays identical. Every entry
/// binds its properties to WHAT THEY FORMAT, so a marker swap is
/// caught.
test "format preservation binds formatting to what it formats" {
  let before = format_fixture(
    "<w:p><w:r><w:t>ab</w:t></w:r><w:r><w:rPr><w:i/><w:iCs/></w:rPr><w:footnoteReference w:id=\"1\"/></w:r><w:r><w:endnoteReference w:id=\"2\"/></w:r></w:p>",
  )
  // Italic moved from the footnote marker to the endnote marker: the
  // multiset of carrier properties is unchanged.
  let moved = format_fixture(
    "<w:p><w:r><w:rPr><w:b/><w:bCs/></w:rPr><w:t>ab</w:t></w:r><w:r><w:footnoteReference w:id=\"1\"/></w:r><w:r><w:rPr><w:i/><w:iCs/></w:rPr><w:endnoteReference w:id=\"2\"/></w:r></w:p>",
  )
  assert_eq(
    @docx.docx_paragraph_direct_format(
      moved,
      moved.main_story_source(),
      path="p[1]",
      start=0,
      end=2,
      format=@docx.docx_direct_format(bold=true),
    ),
    None,
  )
  assert_true(
    @docx.docx_paragraph_format_preserved(
      before,
      before.main_story_source(),
      moved,
      moved.main_story_source(),
      path="p[1]",
      spans=[(0, 2)],
      format=@docx.docx_direct_format(bold=true),
    )
    is Some(_),
  )
  // Leaving both markers alone is faithful.
  let faithful = format_fixture(
    "<w:p><w:r><w:rPr><w:b/><w:bCs/></w:rPr><w:t>ab</w:t></w:r><w:r><w:rPr><w:i/><w:iCs/></w:rPr><w:footnoteReference w:id=\"1\"/></w:r><w:r><w:endnoteReference w:id=\"2\"/></w:r></w:p>",
  )
  assert_eq(
    @docx.docx_paragraph_format_preserved(
      before,
      before.main_story_source(),
      faithful,
      faithful.main_story_source(),
      path="p[1]",
      spans=[(0, 2)],
      format=@docx.docx_direct_format(bold=true),
    ),
    None,
  )
  // A property-less marker run keeps its slot: giving it formatting is
  // a change even though nothing was taken away.
  let adorned = format_fixture(
    "<w:p><w:r><w:rPr><w:b/><w:bCs/></w:rPr><w:t>ab</w:t></w:r><w:r><w:rPr><w:i/><w:iCs/></w:rPr><w:footnoteReference w:id=\"1\"/></w:r><w:r><w:rPr><w:u w:val=\"single\"/></w:rPr><w:endnoteReference w:id=\"2\"/></w:r></w:p>",
  )
  assert_true(
    @docx.docx_paragraph_format_preserved(
      before,
      before.main_story_source(),
      adorned,
      adorned.main_story_source(),
      path="p[1]",
      spans=[(0, 2)],
      format=@docx.docx_direct_format(bold=true),
    )
    is Some(_),
  )
}

///|
/// Round 12: two content controls both own an `sdtEndPr`, so a
/// container's NAME cannot identify it. End-character formatting
/// moving from one control to the other is caught by the carrier's
/// structural path.
test "format preservation identifies carriers structurally" {
  let before = format_fixture(
    "<w:p><w:sdt><w:sdtPr/><w:sdtEndPr><w:rPr><w:i/><w:iCs/></w:rPr></w:sdtEndPr><w:sdtContent><w:r><w:t>x</w:t></w:r></w:sdtContent></w:sdt><w:sdt><w:sdtPr/><w:sdtEndPr/><w:sdtContent><w:r><w:t>y</w:t></w:r></w:sdtContent></w:sdt><w:r><w:t>ab</w:t></w:r></w:p>",
  )
  let moved = format_fixture(
    "<w:p><w:sdt><w:sdtPr/><w:sdtEndPr/><w:sdtContent><w:r><w:t>x</w:t></w:r></w:sdtContent></w:sdt><w:sdt><w:sdtPr/><w:sdtEndPr><w:rPr><w:i/><w:iCs/></w:rPr></w:sdtEndPr><w:sdtContent><w:r><w:t>y</w:t></w:r></w:sdtContent></w:sdt><w:r><w:rPr><w:b/><w:bCs/></w:rPr><w:t>ab</w:t></w:r></w:p>",
  )
  assert_eq(
    @docx.docx_paragraph_direct_format(
      moved,
      moved.main_story_source(),
      path="p[1]",
      start=2,
      end=4,
      format=@docx.docx_direct_format(bold=true),
    ),
    None,
  )
  assert_true(
    @docx.docx_paragraph_format_preserved(
      before,
      before.main_story_source(),
      moved,
      moved.main_story_source(),
      path="p[1]",
      spans=[(2, 4)],
      format=@docx.docx_direct_format(bold=true),
    )
    is Some(_),
  )
  // Leaving both controls alone is faithful — and the planner's own
  // output over the same document preserves.
  let body = "<w:p><w:sdt><w:sdtPr/><w:sdtEndPr><w:rPr><w:i/><w:iCs/></w:rPr></w:sdtEndPr><w:sdtContent><w:r><w:t>x</w:t></w:r></w:sdtContent></w:sdt><w:sdt><w:sdtPr/><w:sdtEndPr/><w:sdtContent><w:r><w:t>y</w:t></w:r></w:sdtContent></w:sdt><w:r><w:t>ab</w:t></w:r></w:p>"
  let (plan, _) = @docx.plan_docx_format(
    before,
    before.main_story_source(),
    format=@docx.docx_direct_format(bold=true),
    within="p[1]",
    range=(2, 4),
  )
  let after = format_apply(body, plan)
  assert_eq(
    @docx.docx_paragraph_format_preserved(
      before,
      before.main_story_source(),
      after,
      after.main_story_source(),
      path="p[1]",
      spans=[(2, 4)],
      format=@docx.docx_direct_format(bold=true),
    ),
    None,
  )
}

///|
/// Round 13: a carrier's key must be namespace-QUALIFIED, must bind a
/// `pPr` to where it sits, and must survive the renumbering that
/// splitting causes.
test "format preservation keys carriers by qualified, split-stable provenance" {
  let mc = "xmlns:mc=\"http://schemas.openxmlformats.org/markup-compatibility/2006\""
  // A foreign `sdtEndPr` is not the WML one: moving the properties
  // between them loses the end-character formatting.
  let qualified_before = format_fixture(
    "<w:p xmlns:x=\"urn:example:x\"><w:sdt><w:sdtPr/><w:sdtEndPr><w:rPr><w:i/><w:iCs/></w:rPr></w:sdtEndPr><x:sdtEndPr/><w:sdtContent><w:r><w:t>x</w:t></w:r></w:sdtContent></w:sdt><w:r><w:t>ab</w:t></w:r></w:p>",
  )
  let qualified_moved = format_fixture(
    "<w:p xmlns:x=\"urn:example:x\"><w:sdt><w:sdtPr/><w:sdtEndPr/><x:sdtEndPr><w:rPr><w:i/><w:iCs/></w:rPr></x:sdtEndPr><w:sdtContent><w:r><w:t>x</w:t></w:r></w:sdtContent></w:sdt><w:r><w:rPr><w:b/><w:bCs/></w:rPr><w:t>ab</w:t></w:r></w:p>",
  )
  assert_true(
    @docx.docx_paragraph_format_preserved(
      qualified_before,
      qualified_before.main_story_source(),
      qualified_moved,
      qualified_moved.main_story_source(),
      path="p[1]",
      spans=[(1, 3)],
      format=@docx.docx_direct_format(bold=true),
    )
    is Some(_),
  )
  // An identical `pPr` moved from a Choice into the Fallback changes
  // which one applies.
  let branch_before = format_fixture(
    "<w:p><mc:AlternateContent \{mc}><mc:Choice Requires=\"w14\"><w:pPr><w:jc w:val=\"center\"/></w:pPr></mc:Choice><mc:Fallback/></mc:AlternateContent><w:r><w:t>ab</w:t></w:r></w:p>",
  )
  let branch_moved = format_fixture(
    "<w:p><mc:AlternateContent \{mc}><mc:Choice Requires=\"w14\"/><mc:Fallback><w:pPr><w:jc w:val=\"center\"/></w:pPr></mc:Fallback></mc:AlternateContent><w:r><w:rPr><w:b/><w:bCs/></w:rPr><w:t>ab</w:t></w:r></w:p>",
  )
  assert_true(
    @docx.docx_paragraph_format_preserved(
      branch_before,
      branch_before.main_story_source(),
      branch_moved,
      branch_moved.main_story_source(),
      path="p[1]",
      spans=[(0, 2)],
      format=@docx.docx_direct_format(bold=true),
    )
    is Some(_),
  )
  // And a carrier nested INSIDE a run survives the split that
  // renumbers its neighbours: the planner's own output preserves.
  let nested = "<w:p><w:r><w:t>abc</w:t></w:r><w:r><w:sdt><w:sdtPr/><w:sdtEndPr><w:rPr><w:i/><w:iCs/></w:rPr></w:sdtEndPr><w:sdtContent><w:t>z</w:t></w:sdtContent></w:sdt></w:r></w:p>"
  let nested_before = format_fixture(nested)
  let (plan, _) = @docx.plan_docx_format(
    nested_before,
    nested_before.main_story_source(),
    format=@docx.docx_direct_format(bold=true),
    within="p[1]",
    range=(1, 2),
  )
  let nested_after = format_apply(nested, plan)
  assert_eq(
    @docx.docx_paragraph_format_preserved(
      nested_before,
      nested_before.main_story_source(),
      nested_after,
      nested_after.main_story_source(),
      path="p[1]",
      spans=[(1, 2)],
      format=@docx.docx_direct_format(bold=true),
    ),
    None,
  )
}

///|
/// Round 14: two runs holding identical content are different
/// OCCURRENCES. A carrier key therefore records where its run sits, in
/// projection units, so formatting moving between look-alike runs is a
/// difference.
test "format preservation distinguishes look-alike run occurrences" {
  let before = format_fixture(
    "<w:p><w:r><w:sdt><w:sdtPr/><w:sdtEndPr><w:rPr><w:i/><w:iCs/></w:rPr></w:sdtEndPr><w:sdtContent><w:t>x</w:t></w:sdtContent></w:sdt></w:r><w:r><w:sdt><w:sdtPr/><w:sdtEndPr/><w:sdtContent><w:t>x</w:t></w:sdtContent></w:sdt></w:r><w:r><w:t>ab</w:t></w:r></w:p>",
  )
  let moved = format_fixture(
    "<w:p><w:r><w:sdt><w:sdtPr/><w:sdtEndPr/><w:sdtContent><w:t>x</w:t></w:sdtContent></w:sdt></w:r><w:r><w:sdt><w:sdtPr/><w:sdtEndPr><w:rPr><w:i/><w:iCs/></w:rPr></w:sdtEndPr><w:sdtContent><w:t>x</w:t></w:sdtContent></w:sdt></w:r><w:r><w:rPr><w:b/><w:bCs/></w:rPr><w:t>ab</w:t></w:r></w:p>",
  )
  assert_eq(
    @docx.docx_paragraph_direct_format(
      moved,
      moved.main_story_source(),
      path="p[1]",
      start=2,
      end=4,
      format=@docx.docx_direct_format(bold=true),
    ),
    None,
  )
  assert_true(
    @docx.docx_paragraph_format_preserved(
      before,
      before.main_story_source(),
      moved,
      moved.main_story_source(),
      path="p[1]",
      spans=[(2, 4)],
      format=@docx.docx_direct_format(bold=true),
    )
    is Some(_),
  )
  // The planner's own output over the same document preserves.
  let body = "<w:p><w:r><w:sdt><w:sdtPr/><w:sdtEndPr><w:rPr><w:i/><w:iCs/></w:rPr></w:sdtEndPr><w:sdtContent><w:t>x</w:t></w:sdtContent></w:sdt></w:r><w:r><w:sdt><w:sdtPr/><w:sdtEndPr/><w:sdtContent><w:t>x</w:t></w:sdtContent></w:sdt></w:r><w:r><w:t>ab</w:t></w:r></w:p>"
  let (plan, _) = @docx.plan_docx_format(
    before,
    before.main_story_source(),
    format=@docx.docx_direct_format(bold=true),
    within="p[1]",
    range=(2, 4),
  )
  let after = format_apply(body, plan)
  assert_eq(
    @docx.docx_paragraph_format_preserved(
      before,
      before.main_story_source(),
      after,
      after.main_story_source(),
      path="p[1]",
      spans=[(2, 4)],
      format=@docx.docx_direct_format(bold=true),
    ),
    None,
  )
}

///|
/// Round 15: the same spelling can mean a different vocabulary. An
/// inherited rebinding changes what a property IS without changing a
/// byte of it, so preservation pins the namespace environment the
/// paragraph's own elements demonstrate.
test "format preservation pins the namespace environment" {
  let before = format_fixture(
    "<w:p xmlns:x=\"http://schemas.microsoft.com/office/word/2010/wordml\"><w:r><w:rPr><x:glow/></w:rPr><w:t>ab</w:t></w:r></w:p>",
  )
  // Bold arrives as asked, but `x` now names a different vocabulary:
  // the extension formatting silently became something else.
  let rebound = format_fixture(
    "<w:p xmlns:x=\"http://schemas.microsoft.com/office/word/2012/wordml\"><w:r><w:rPr><w:b/><w:bCs/><x:glow/></w:rPr><w:t>ab</w:t></w:r></w:p>",
  )
  assert_eq(
    @docx.docx_paragraph_direct_format(
      rebound,
      rebound.main_story_source(),
      path="p[1]",
      start=0,
      end=2,
      format=@docx.docx_direct_format(bold=true),
    ),
    None,
  )
  let verdict = @docx.docx_paragraph_format_preserved(
    before,
    before.main_story_source(),
    rebound,
    rebound.main_story_source(),
    path="p[1]",
    spans=[(0, 2)],
    format=@docx.docx_direct_format(bold=true),
  )
  assert_true(verdict is Some(_))
  guard verdict is Some(message) else { fail("expected a binding verdict") }
  assert_true(message.contains("namespace bindings"), msg=message)
  // The planner's own output keeps the binding, and preserves.
  let body = "<w:p xmlns:x=\"http://schemas.microsoft.com/office/word/2010/wordml\"><w:r><w:rPr><x:glow/></w:rPr><w:t>ab</w:t></w:r></w:p>"
  let (plan, _) = @docx.plan_docx_format(
    before,
    before.main_story_source(),
    format=@docx.docx_direct_format(bold=true),
    within="p[1]",
    range=(0, 2),
  )
  let after = format_apply(body, plan)
  assert_eq(
    @docx.docx_paragraph_format_preserved(
      before,
      before.main_story_source(),
      after,
      after.main_story_source(),
      path="p[1]",
      spans=[(0, 2)],
      format=@docx.docx_direct_format(bold=true),
    ),
    None,
  )
}

///|
/// Round 16: bindings belong to the property that uses them, not to
/// the paragraph. Two runs may each bind the same prefix differently,
/// and an ATTRIBUTE prefix never appears as an element prefix at all.
test "format preservation binds namespaces per property" {
  // Two runs, each binding `x` to a different vocabulary; the wrong
  // result exchanges them, so a paragraph-wide set is unchanged.
  let before = format_fixture(
    "<w:p><w:r xmlns:x=\"http://schemas.microsoft.com/office/word/2010/wordml\"><w:rPr><x:glow/></w:rPr><w:t>a</w:t></w:r><w:r xmlns:x=\"http://schemas.microsoft.com/office/word/2012/wordml\"><w:rPr><x:glow/></w:rPr><w:t>b</w:t></w:r></w:p>",
  )
  let swapped = format_fixture(
    "<w:p><w:r xmlns:x=\"http://schemas.microsoft.com/office/word/2012/wordml\"><w:rPr><w:b/><w:bCs/><x:glow/></w:rPr><w:t>a</w:t></w:r><w:r xmlns:x=\"http://schemas.microsoft.com/office/word/2010/wordml\"><w:rPr><w:b/><w:bCs/><x:glow/></w:rPr><w:t>b</w:t></w:r></w:p>",
  )
  // The rPr engine declines to judge a run that declares a namespace
  // locally, so the positive check reports that rather than a clean
  // pass — and preservation names the exchange regardless.
  assert_true(
    @docx.docx_paragraph_direct_format(
      swapped,
      swapped.main_story_source(),
      path="p[1]",
      start=0,
      end=2,
      format=@docx.docx_direct_format(bold=true),
    )
    is Some(_),
  )
  assert_true(
    @docx.docx_paragraph_format_preserved(
      before,
      before.main_story_source(),
      swapped,
      swapped.main_story_source(),
      path="p[1]",
      spans=[(0, 2)],
      format=@docx.docx_direct_format(bold=true),
    )
    is Some(_),
  )
  // An ATTRIBUTE prefix rebinding, which no element spelling reveals.
  let attribute_before = format_fixture(
    "<w:p xmlns:x=\"http://schemas.microsoft.com/office/word/2010/wordml\" xmlns:y=\"http://schemas.microsoft.com/office/word/2010/wordml\"><w:r><w:rPr><x:glow y:val=\"1\"/></w:rPr><w:t>ab</w:t></w:r></w:p>",
  )
  let attribute_rebound = format_fixture(
    "<w:p xmlns:x=\"http://schemas.microsoft.com/office/word/2010/wordml\" xmlns:y=\"http://schemas.microsoft.com/office/word/2012/wordml\"><w:r><w:rPr><w:b/><w:bCs/><x:glow y:val=\"1\"/></w:rPr><w:t>ab</w:t></w:r></w:p>",
  )
  // The positive check accepts this one — the run itself declares
  // nothing — so only preservation can see the rebinding.
  assert_eq(
    @docx.docx_paragraph_direct_format(
      attribute_rebound,
      attribute_rebound.main_story_source(),
      path="p[1]",
      start=0,
      end=2,
      format=@docx.docx_direct_format(bold=true),
    ),
    None,
  )
  assert_true(
    @docx.docx_paragraph_format_preserved(
      attribute_before,
      attribute_before.main_story_source(),
      attribute_rebound,
      attribute_rebound.main_story_source(),
      path="p[1]",
      spans=[(0, 2)],
      format=@docx.docx_direct_format(bold=true),
    )
    is Some(_),
  )
  // The planner refuses a run that declares a namespace locally, so
  // the swap fixture is never something it could produce. Its own
  // output over the paragraph-scoped document is what must preserve.
  let body = "<w:p xmlns:x=\"http://schemas.microsoft.com/office/word/2010/wordml\" xmlns:y=\"http://schemas.microsoft.com/office/word/2010/wordml\"><w:r><w:rPr><x:glow y:val=\"1\"/></w:rPr><w:t>ab</w:t></w:r></w:p>"
  let (plan, _) = @docx.plan_docx_format(
    attribute_before,
    attribute_before.main_story_source(),
    format=@docx.docx_direct_format(bold=true),
    within="p[1]",
    range=(0, 2),
  )
  let after = format_apply(body, plan)
  assert_eq(
    @docx.docx_paragraph_format_preserved(
      attribute_before,
      attribute_before.main_story_source(),
      after,
      after.main_story_source(),
      path="p[1]",
      spans=[(0, 2)],
      format=@docx.docx_direct_format(bold=true),
    ),
    None,
  )
}

///|
/// Round 17: an unprefixed extension element means whatever `xmlns`
/// currently says, and ordinary whitespace splitting must not read as
/// a change of meaning.
test "format preservation reads default bindings and tolerates xml:space" {
  // The DEFAULT binding changes vocabulary without touching a byte of
  // the property.
  let before = format_fixture(
    "<w:p xmlns=\"http://schemas.microsoft.com/office/word/2010/wordml\" xmlns:x=\"http://schemas.microsoft.com/office/word/2010/wordml\"><w:r><w:rPr><x:glow x:rad=\"101600\"><srgbClr x:val=\"FF0000\"/></x:glow></w:rPr><w:t>ab</w:t></w:r></w:p>",
  )
  let rebound = format_fixture(
    "<w:p xmlns=\"http://schemas.microsoft.com/office/word/2012/wordml\" xmlns:x=\"http://schemas.microsoft.com/office/word/2010/wordml\"><w:r><w:rPr><w:b/><w:bCs/><x:glow x:rad=\"101600\"><srgbClr x:val=\"FF0000\"/></x:glow></w:rPr><w:t>ab</w:t></w:r></w:p>",
  )
  assert_eq(
    @docx.docx_paragraph_direct_format(
      rebound,
      rebound.main_story_source(),
      path="p[1]",
      start=0,
      end=2,
      format=@docx.docx_direct_format(bold=true),
    ),
    None,
  )
  assert_true(
    @docx.docx_paragraph_format_preserved(
      before,
      before.main_story_source(),
      rebound,
      rebound.main_story_source(),
      path="p[1]",
      spans=[(0, 2)],
      format=@docx.docx_direct_format(bold=true),
    )
    is Some(_),
  )
  // And the ordinary request that motivated the scoping: bolding a
  // word whose split leaves a trailing space, so the clone acquires
  // `xml:space`. Nothing about its meaning changed.
  let body = "<w:p><w:r><w:t>a b</w:t></w:r></w:p>"
  let plain = format_fixture(body)
  let (plan, _) = @docx.plan_docx_format(
    plain,
    plain.main_story_source(),
    format=@docx.docx_direct_format(bold=true),
    within="p[1]",
    range=(0, 2),
  )
  let after = format_apply(body, plan)
  assert_true(after.result().document.to_raw_text().contains("a b"))
  assert_eq(
    @docx.docx_paragraph_direct_format(
      after,
      after.main_story_source(),
      path="p[1]",
      start=0,
      end=2,
      format=@docx.docx_direct_format(bold=true),
    ),
    None,
  )
  assert_eq(
    @docx.docx_paragraph_format_preserved(
      plain,
      plain.main_story_source(),
      after,
      after.main_story_source(),
      path="p[1]",
      spans=[(0, 2)],
      format=@docx.docx_direct_format(bold=true),
    ),
    None,
  )
}

///|
/// Round 18: a run may hold a large subtree, and a paragraph may hold
/// many carriers inside it. Signatures are bounded and computed once,
/// so a legal document does not make its own readback impossible —
/// while still telling look-alike runs apart.
test "format preservation stays bounded on a heavy run" {
  let properties = StringBuilder()
  for _ in 0..<2000 {
    properties.write_string("<w:rPr/>")
  }
  let body = "<w:p><w:r><w:foo>" +
    properties.to_string() +
    "</w:foo></w:r><w:r><w:t>x</w:t></w:r></w:p>"
  let before = format_fixture(body)
  let (plan, receipt) = @docx.plan_docx_format(
    before,
    before.main_story_source(),
    format=@docx.docx_direct_format(bold=true),
    within="p[1]",
    range=(0, 1),
  )
  assert_eq(receipt.runs_changed(), 1)
  let after = format_apply(body, plan)
  // The readback completes, and agrees.
  assert_eq(
    @docx.docx_paragraph_direct_format(
      after,
      after.main_story_source(),
      path="p[1]",
      start=0,
      end=1,
      format=@docx.docx_direct_format(bold=true),
    ),
    None,
  )
  assert_eq(
    @docx.docx_paragraph_format_preserved(
      before,
      before.main_story_source(),
      after,
      after.main_story_source(),
      path="p[1]",
      spans=[(0, 1)],
      format=@docx.docx_direct_format(bold=true),
    ),
    None,
  )
  // And a bounded key still distinguishes look-alike runs: the marker
  // swap from the earlier witness is caught by the same machinery.
  let markers_before = format_fixture(
    "<w:p><w:r><w:rPr><w:i/><w:iCs/></w:rPr><w:footnoteReference w:id=\"1\"/></w:r><w:r><w:endnoteReference w:id=\"2\"/></w:r><w:r><w:t>ab</w:t></w:r></w:p>",
  )
  let markers_moved = format_fixture(
    "<w:p><w:r><w:footnoteReference w:id=\"1\"/></w:r><w:r><w:rPr><w:i/><w:iCs/></w:rPr><w:endnoteReference w:id=\"2\"/></w:r><w:r><w:rPr><w:b/><w:bCs/></w:rPr><w:t>ab</w:t></w:r></w:p>",
  )
  assert_true(
    @docx.docx_paragraph_format_preserved(
      markers_before,
      markers_before.main_story_source(),
      markers_moved,
      markers_moved.main_story_source(),
      path="p[1]",
      spans=[(2, 4)],
      format=@docx.docx_direct_format(bold=true),
    )
    is Some(_),
  )
}

///|
/// Round 19: a deep ancestry with many carriers under it must cost the
/// ancestry once, not once per carrier — and the keys must still tell
/// two different owners apart.
test "format preservation stays bounded under deep ancestry" {
  // Deep and wide enough that a per-carrier ancestry walk would not
  // finish: the cost must come from the document, not from their
  // product.
  let wrappers = 200
  let carriers = 40000
  let inner = StringBuilder()
  for _ in 0..<carriers {
    inner.write_string("<w:rPr/>")
  }
  let nested = StringBuilder()
  for _ in 0..<wrappers {
    nested.write_string("<w:foo>")
  }
  nested.write_string(inner.to_string())
  for _ in 0..<wrappers {
    nested.write_string("</w:foo>")
  }
  let body = "<w:p><w:r>" +
    nested.to_string() +
    "</w:r><w:r><w:t>x</w:t></w:r></w:p>"
  let before = format_fixture(body)
  let (plan, receipt) = @docx.plan_docx_format(
    before,
    before.main_story_source(),
    format=@docx.docx_direct_format(bold=true),
    within="p[1]",
    range=(0, 1),
  )
  assert_eq(receipt.runs_changed(), 1)
  let after = format_apply(body, plan)
  assert_eq(
    @docx.docx_paragraph_format_preserved(
      before,
      before.main_story_source(),
      after,
      after.main_story_source(),
      path="p[1]",
      spans=[(0, 1)],
      format=@docx.docx_direct_format(bold=true),
    ),
    None,
  )
  // Two owners at the same depth remain distinguishable: the
  // content-control swap from the earlier witness still fails.
  let controls_before = format_fixture(
    "<w:p><w:sdt><w:sdtPr/><w:sdtEndPr><w:rPr><w:i/><w:iCs/></w:rPr></w:sdtEndPr><w:sdtContent><w:r><w:t>x</w:t></w:r></w:sdtContent></w:sdt><w:sdt><w:sdtPr/><w:sdtEndPr/><w:sdtContent><w:r><w:t>y</w:t></w:r></w:sdtContent></w:sdt><w:r><w:t>ab</w:t></w:r></w:p>",
  )
  let controls_moved = format_fixture(
    "<w:p><w:sdt><w:sdtPr/><w:sdtEndPr/><w:sdtContent><w:r><w:t>x</w:t></w:r></w:sdtContent></w:sdt><w:sdt><w:sdtPr/><w:sdtEndPr><w:rPr><w:i/><w:iCs/></w:rPr></w:sdtEndPr><w:sdtContent><w:r><w:t>y</w:t></w:r></w:sdtContent></w:sdt><w:r><w:rPr><w:b/><w:bCs/></w:rPr><w:t>ab</w:t></w:r></w:p>",
  )
  assert_true(
    @docx.docx_paragraph_format_preserved(
      controls_before,
      controls_before.main_story_source(),
      controls_moved,
      controls_moved.main_story_source(),
      path="p[1]",
      spans=[(2, 4)],
      format=@docx.docx_direct_format(bold=true),
    )
    is Some(_),
  )
}
