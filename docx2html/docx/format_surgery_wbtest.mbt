///|
/// F1 oracle, N0c2's methodology verbatim: never verify a plan against the
/// projection that built it — apply the edits, re-read with the REAL
/// reader, and hold the paragraph's projection UNCHANGED (formatting never
/// moves text); then hold every byte outside the declared edit union at
/// its shifted offset, and hold the formatted runs to the INDEPENDENT
/// direct-format oracle.
fn format_fixture_source(body : String) -> String {
  "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\" xmlns:w14=\"http://schemas.microsoft.com/office/word/2010/wordml\" xmlns:v=\"urn:schemas-microsoft-com:vml\"><w:body>\{body}</w:body></w:document>"
}

///|
fn format_span(start : Int, end : Int) -> ParagraphFormatSpan {
  { start, end, }
}

///|
/// Plan, splice, and run the standing witnesses; returns the spliced
/// document string and the receipt for test-specific assertions.
fn assert_format_edits(
  body : String,
  paragraph~ : Int,
  spans : Array[ParagraphFormatSpan],
  bold? : Bool,
  italic? : Bool,
  underline? : Bool,
  color? : String,
) -> (String, FormatSurgeryReceipt) raise {
  let source = format_fixture_source(body)
  let bytes = @utf8.encode(source)
  let projection = surgery_native_projection(source)
  let format = docx_direct_format(bold?, italic?, underline?, color?)
  let (byte_edits, receipt) = plan_paragraph_format_edits(
    projection, bytes, paragraph, spans, format,
  )
  assert_eq(receipt.paragraph_index, paragraph)
  // The receipt's expectation is the paragraph's CURRENT projection.
  let expected = StringBuilder()
  for contribution in projection.paragraphs[paragraph].contributions {
    expected.write_string(contribution.value)
  }
  assert_eq(receipt.expected_projection, expected.to_string())
  let spliced_bytes = apply_run_surgery_edits(bytes, byte_edits)
  let spliced = @utf8.decode(spliced_bytes)
  // Through the real reader: the projection is UNCHANGED.
  let reprojected = surgery_native_projection(spliced)
  assert_true(paragraph < reprojected.paragraphs.length())
  let after = StringBuilder()
  for contribution in reprojected.paragraphs[paragraph].contributions {
    after.write_string(contribution.value)
  }
  assert_eq(after.to_string(), receipt.expected_projection)
  current_reader_story_text(spliced) |> ignore
  assert_untouched_bytes_survive(bytes, spliced_bytes, byte_edits)
  // XML ID uniqueness, through the REAL scan's elements and a
  // quote-aware attribute walk — every spelling of every element's
  // identity attributes, not one literal substring.
  let ids : Array[String] = []
  for element in reprojected.scan.elements() {
    for value in collect_identity_values(spliced_bytes, element) {
      assert_false(ids.contains(value), msg="duplicated id " + value)
      ids.push(value)
    }
  }
  // EVERY result run whose projection lies wholly inside the requested
  // span union must satisfy the INDEPENDENT F0 verifier — cross-run,
  // multi-span, and split variants alike, not just hand-picked runs.
  for run in reprojected.paragraphs[paragraph].runs {
    // Contribution-by-contribution coverage, never a convex hull: a
    // tolerated run's contributions can be discontinuous around a
    // nested run, and the hull's gap would false-skip verification.
    let mut has_text = false
    let mut inside = true
    for contribution in reprojected.paragraphs[paragraph].contributions {
      if contribution.run_source == Some(run.source) &&
        contribution.kind is ProjectedText(_) {
        let local_start = contribution.projection_start -
          reprojected.paragraphs[paragraph].projection_start
        let local_end = contribution.projection_end -
          reprojected.paragraphs[paragraph].projection_start
        if local_end <= local_start {
          continue
        }
        has_text = true
        let mut cursor = local_start
        for span in spans {
          if span.start <= cursor && cursor < span.end {
            cursor = span.end
          }
        }
        if cursor < local_end {
          inside = false
        }
      }
    }
    if !has_text {
      continue
    }
    if inside {
      let SourceElementId(identity) = run.source
      let element = reprojected.scan.elements()[identity]
      let spliced_all = @utf8.encode(spliced)
      let out : Array[Byte] = []
      for index in element.byte_start..<element.byte_end {
        out.push(spliced_all[index])
      }
      assert_eq(
        verify_run_format(
          Bytes::from_array(out),
          prefix="w",
          extension_prefixes=["w14"],
          format~,
        ),
        None,
      )
    }
  }
  (spliced, receipt)
}

///|
fn assert_format_refusal(
  body : String,
  paragraph~ : Int,
  spans : Array[ParagraphFormatSpan],
  refusal~ : String,
  bold? : Bool,
  color? : String,
) -> Unit raise {
  assert_format_refusal_in(
    format_fixture_source(body),
    paragraph~,
    spans,
    refusal~,
    bold?,
    color?,
  )
}

///|
fn assert_format_refusal_in(
  source : String,
  paragraph~ : Int,
  spans : Array[ParagraphFormatSpan],
  refusal~ : String,
  bold? : Bool,
  color? : String,
) -> Unit raise {
  let bytes = @utf8.encode(source)
  let projection = surgery_native_projection(source)
  let format = docx_direct_format(bold?, color?)
  try
    plan_paragraph_format_edits(projection, bytes, paragraph, spans, format)
    |> ignore
  catch {
    Unsupported(message~) =>
      assert_true(
        message.contains("formatting surgery [\{refusal}]"),
        msg="expected [\{refusal}] in: \{message}",
      )
    _ => fail("expected a typed formatting-surgery refusal")
  } noraise {
    _ => fail("expected refusal [\{refusal}]")
  }
}

///|
/// The byte slice of `p[paragraph]`'s `run`th registered run in a spliced
/// document, for the independent direct-format oracle.
fn format_result_run_slice(
  spliced : String,
  paragraph : Int,
  run : Int,
) -> Bytes raise {
  let projection = surgery_native_projection(spliced)
  let bytes = @utf8.encode(spliced)
  guard paragraph < projection.paragraphs.length() else {
    fail("paragraph \{paragraph} missing after splice")
  }
  let runs = projection.paragraphs[paragraph].runs
  guard run < runs.length() else {
    fail("run \{run} missing after splice: \{runs.length()} runs")
  }
  let SourceElementId(identity) = runs[run].source
  let element = projection.scan.elements()[identity]
  let out : Array[Byte] = []
  for index in element.byte_start..<element.byte_end {
    out.push(bytes[index])
  }
  Bytes::from_array(out)
}

///|
test "format: full coverage edits the rPr in place" {
  let (spliced, receipt) = assert_format_edits(
    "<w:p><w:r><w:t>alpha</w:t></w:r></w:p>",
    paragraph=0,
    [format_span(0, 5)],
    bold=true,
  )
  assert_true(
    spliced.contains("<w:r><w:rPr><w:b/><w:bCs/></w:rPr><w:t>alpha</w:t></w:r>"),
  )
  assert_eq(receipt.runs_changed, 1)
  assert_eq(receipt.splits, 0)
  assert_eq(receipt.runs_already_satisfied, 0)
  guard receipt.outcomes[0].action is FormattedInPlace else {
    fail("expected an in-place edit")
  }
  assert_true(receipt.outcomes[0].fully_covered)
  // The independent oracle agrees.
  assert_eq(
    verify_run_format(
      format_result_run_slice(spliced, 0, 0),
      prefix="w",
      format=docx_direct_format(bold=true),
    ),
    None,
  )
}

///|
test "format: left, middle, and right spans clone-split" {
  let body = "<w:p><w:r><w:t>alphabet</w:t></w:r></w:p>"
  let (left, left_receipt) = assert_format_edits(
    body,
    paragraph=0,
    [format_span(0, 3)],
    bold=true,
  )
  assert_true(
    left.contains(
      "<w:r><w:rPr><w:b/><w:bCs/></w:rPr><w:t>alp</w:t></w:r><w:r><w:t>habet</w:t></w:r>",
    ),
  )
  assert_eq(left_receipt.splits, 1)
  guard left_receipt.outcomes[0].action is SplitIntoSegments(2) else {
    fail("expected two segments")
  }
  let (middle, middle_receipt) = assert_format_edits(
    body,
    paragraph=0,
    [format_span(2, 5)],
    bold=true,
  )
  assert_true(
    middle.contains(
      "<w:r><w:t>al</w:t></w:r><w:r><w:rPr><w:b/><w:bCs/></w:rPr><w:t>pha</w:t></w:r><w:r><w:t>bet</w:t></w:r>",
    ),
  )
  guard middle_receipt.outcomes[0].action is SplitIntoSegments(3) else {
    fail("expected three segments")
  }
  // The middle clone satisfies the oracle; its neighbours do not.
  assert_eq(
    verify_run_format(
      format_result_run_slice(middle, 0, 1),
      prefix="w",
      format=docx_direct_format(bold=true),
    ),
    None,
  )
  assert_true(
    verify_run_format(
      format_result_run_slice(middle, 0, 0),
      prefix="w",
      format=docx_direct_format(bold=true),
    )
    is Some(_),
  )
  let (right, _) = assert_format_edits(
    body,
    paragraph=0,
    [format_span(5, 8)],
    bold=true,
  )
  assert_true(
    right.contains(
      "<w:r><w:t>alpha</w:t></w:r><w:r><w:rPr><w:b/><w:bCs/></w:rPr><w:t>bet</w:t></w:r>",
    ),
  )
}

///|
test "format: an existing rPr is cloned whole and minimally extended" {
  let body = "<w:p><w:r><w:rPr><w:rStyle w:val=\"Em\"/><w:i/></w:rPr><w:t>abcdef</w:t></w:r></w:p>"
  let (spliced, _) = assert_format_edits(
    body,
    paragraph=0,
    [format_span(2, 4)],
    bold=true,
  )
  // Every clone keeps rStyle and italic byte-identical; the covered one
  // gains bold at its schema position, after rStyle and before i.
  assert_true(
    spliced.contains(
      "<w:r><w:rPr><w:rStyle w:val=\"Em\"/><w:i/></w:rPr><w:t>ab</w:t></w:r>" +
      "<w:r><w:rPr><w:rStyle w:val=\"Em\"/><w:b/><w:bCs/><w:i/></w:rPr><w:t>cd</w:t></w:r>" +
      "<w:r><w:rPr><w:rStyle w:val=\"Em\"/><w:i/></w:rPr><w:t>ef</w:t></w:r>",
    ),
  )
}

///|
test "format: multiple and abutting spans in one run produce one partition" {
  let body = "<w:p><w:r><w:t>abcdefgh</w:t></w:r></w:p>"
  let (spliced, receipt) = assert_format_edits(
    body,
    paragraph=0,
    [format_span(1, 3), format_span(3, 5), format_span(6, 7)],
    bold=true,
  )
  assert_eq(receipt.splits, 1)
  assert_eq(receipt.runs_changed, 1)
  guard receipt.outcomes[0].action is SplitIntoSegments(5) else {
    fail("expected five segments: \{@debug.Repr(receipt.outcomes[0].action)}")
  }
  assert_true(
    spliced.contains(
      "<w:r><w:t>a</w:t></w:r>" +
      "<w:r><w:rPr><w:b/><w:bCs/></w:rPr><w:t>bcde</w:t></w:r>" +
      "<w:r><w:t>f</w:t></w:r>" +
      "<w:r><w:rPr><w:b/><w:bCs/></w:rPr><w:t>g</w:t></w:r>" +
      "<w:r><w:t>h</w:t></w:r>",
    ),
  )
}

///|
test "format: a cross-run span splits the edges and edits the middle" {
  let body = "<w:p><w:r><w:t>one</w:t></w:r><w:r><w:t>two</w:t></w:r><w:r><w:t>three</w:t></w:r></w:p>"
  let (spliced, receipt) = assert_format_edits(
    body,
    paragraph=0,
    [format_span(2, 8)],
    bold=true,
  )
  assert_eq(receipt.runs_changed, 3)
  assert_eq(receipt.splits, 2)
  assert_true(
    spliced.contains(
      "<w:r><w:t>on</w:t></w:r><w:r><w:rPr><w:b/><w:bCs/></w:rPr><w:t>e</w:t></w:r>" +
      "<w:r><w:rPr><w:b/><w:bCs/></w:rPr><w:t>two</w:t></w:r>" +
      "<w:r><w:rPr><w:b/><w:bCs/></w:rPr><w:t>th</w:t></w:r><w:r><w:t>ree</w:t></w:r>",
    ),
  )
}

///|
test "format: multiple w:t elements group into segments across their seams" {
  // One run, two w:t: the span covers the tail of the first and the head
  // of the second, so ONE covered clone carries fragments of both.
  let body = "<w:p><w:r><w:t>abc</w:t><w:t>def</w:t></w:r></w:p>"
  let (spliced, receipt) = assert_format_edits(
    body,
    paragraph=0,
    [format_span(2, 4)],
    bold=true,
  )
  guard receipt.outcomes[0].action is SplitIntoSegments(3) else {
    fail("expected three segments")
  }
  assert_true(
    spliced.contains(
      "<w:r><w:t>ab</w:t></w:r>" +
      "<w:r><w:rPr><w:b/><w:bCs/></w:rPr><w:t>c</w:t><w:t>d</w:t></w:r>" +
      "<w:r><w:t>ef</w:t></w:r>",
    ),
  )
}

///|
test "format: entity spellings survive cloning byte-identically" {
  // Projection "a&b<c"; the span formats just the ampersand, whose
  // `&amp;` spelling must land in the covered clone untouched.
  let body = "<w:p><w:r><w:t>a&amp;b&lt;c</w:t></w:r></w:p>"
  let (spliced, _) = assert_format_edits(
    body,
    paragraph=0,
    [format_span(1, 2)],
    bold=true,
  )
  assert_true(
    spliced.contains(
      "<w:r><w:t>a</w:t></w:r>" +
      "<w:r><w:rPr><w:b/><w:bCs/></w:rPr><w:t>&amp;</w:t></w:r>" +
      "<w:r><w:t>b&lt;c</w:t></w:r>",
    ),
  )
}

///|
test "format: emoji boundaries are scalar or refused" {
  let body = "<w:p><w:r><w:t>a\u{1F600}b</w:t></w:r></w:p>"
  // Whole-emoji coverage is legal...
  let (spliced, _) = assert_format_edits(
    body,
    paragraph=0,
    [format_span(1, 3)],
    bold=true,
  )
  assert_true(
    spliced.contains(
      "<w:r><w:rPr><w:b/><w:bCs/></w:rPr><w:t>\u{1F600}</w:t></w:r>",
    ),
  )
  // ...a boundary between its surrogate halves is not.
  assert_format_refusal(
    body,
    paragraph=0,
    [format_span(0, 2)],
    refusal="FormatNonScalarBoundary",
    bold=true,
  )
}

///|
test "format: a numeric reference is one scalar token" {
  // U+1F600 spelled as a numeric reference projects two UTF-16 units;
  // a boundary inside the token cannot resolve.
  let body = "<w:p><w:r><w:t>a&#128512;b</w:t></w:r></w:p>"
  assert_format_refusal(
    body,
    paragraph=0,
    [format_span(0, 2)],
    refusal="FormatNonScalarBoundary",
    bold=true,
  )
  let (spliced, _) = assert_format_edits(
    body,
    paragraph=0,
    [format_span(1, 3)],
    bold=true,
  )
  assert_true(
    spliced.contains(
      "<w:r><w:rPr><w:b/><w:bCs/></w:rPr><w:t>&#128512;</w:t></w:r>",
    ),
  )
}

///|
test "format: xml:space policy on split fragments" {
  // A covered fragment ending in a space gains preserve; the untouched
  // neighbour fragment does not.
  let body = "<w:p><w:r><w:t xml:space=\"preserve\">ab cd</w:t></w:r></w:p>"
  let (spliced, _) = assert_format_edits(
    body,
    paragraph=0,
    [format_span(0, 3)],
    bold=true,
  )
  // The original declaration is preserved on every clone: never removed
  // merely because a fragment no longer needs it.
  assert_true(
    spliced.contains(
      "<w:r><w:rPr><w:b/><w:bCs/></w:rPr><w:t xml:space=\"preserve\">ab </w:t></w:r>" +
      "<w:r><w:t xml:space=\"preserve\">cd</w:t></w:r>",
    ),
  )
  // Without a declaration, only the needy fragment gains one.
  let bare = "<w:p><w:r><w:t>ab cd</w:t></w:r></w:p>"
  let (bare_spliced, _) = assert_format_edits(
    bare,
    paragraph=0,
    [format_span(0, 3)],
    bold=true,
  )
  assert_true(
    bare_spliced.contains(
      "<w:r><w:rPr><w:b/><w:bCs/></w:rPr><w:t xml:space=\"preserve\">ab </w:t></w:r>" +
      "<w:r><w:t>cd</w:t></w:r>",
    ),
  )
  // An existing `default` is upgraded on the needy fragment and kept
  // byte-identical on the other.
  let defaulted = "<w:p><w:r><w:t xml:space=\"default\">ab cd</w:t></w:r></w:p>"
  let (defaulted_spliced, _) = assert_format_edits(
    defaulted,
    paragraph=0,
    [format_span(0, 3)],
    bold=true,
  )
  assert_true(
    defaulted_spliced.contains(
      "<w:r><w:rPr><w:b/><w:bCs/></w:rPr><w:t xml:space=\"preserve\">ab </w:t></w:r>" +
      "<w:r><w:t xml:space=\"default\">cd</w:t></w:r>",
    ),
  )
}

///|
test "format: an already-satisfied run stays unsplit" {
  let body = "<w:p><w:r><w:rPr><w:b/><w:bCs/></w:rPr><w:t>abcd</w:t></w:r></w:p>"
  let source = format_fixture_source(body)
  let bytes = @utf8.encode(source)
  let projection = surgery_native_projection(source)
  let (edits, receipt) = plan_paragraph_format_edits(
    projection,
    bytes,
    0,
    [format_span(1, 3)],
    docx_direct_format(bold=true),
  )
  assert_eq(edits.length(), 0)
  assert_eq(receipt.runs_changed, 0)
  assert_eq(receipt.runs_already_satisfied, 1)
  assert_eq(receipt.splits, 0)
  guard receipt.outcomes[0].action is AlreadySatisfied else {
    fail("expected an already-satisfied outcome")
  }
  // Mixed: the satisfied run stays untouched while its neighbour splits.
  let mixed = "<w:p><w:r><w:rPr><w:b/><w:bCs/></w:rPr><w:t>ab</w:t></w:r><w:r><w:t>cd</w:t></w:r></w:p>"
  let (spliced, mixed_receipt) = assert_format_edits(
    mixed,
    paragraph=0,
    [format_span(1, 3)],
    bold=true,
  )
  assert_eq(mixed_receipt.runs_already_satisfied, 1)
  assert_eq(mixed_receipt.runs_changed, 1)
  assert_eq(mixed_receipt.splits, 1)
  assert_true(
    spliced.contains(
      "<w:r><w:rPr><w:b/><w:bCs/></w:rPr><w:t>ab</w:t></w:r>" +
      "<w:r><w:rPr><w:b/><w:bCs/></w:rPr><w:t>c</w:t></w:r><w:r><w:t>d</w:t></w:r>",
    ),
  )
}

///|
test "format: a hyperlink boundary between sibling runs is allowed" {
  let body = "<w:p><w:r><w:t>ab</w:t></w:r><w:hyperlink r:id=\"rId9\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\"><w:r><w:t>cd</w:t></w:r></w:hyperlink></w:p>"
  let (spliced, receipt) = assert_format_edits(
    body,
    paragraph=0,
    [format_span(1, 3)],
    bold=true,
  )
  assert_eq(receipt.runs_changed, 2)
  assert_eq(receipt.splits, 2)
  // Each run keeps its wrapper: the linked clone stays inside the
  // hyperlink element.
  assert_true(
    spliced.contains(
      "<w:r><w:t>a</w:t></w:r><w:r><w:rPr><w:b/><w:bCs/></w:rPr><w:t>b</w:t></w:r>",
    ),
  )
  assert_true(
    spliced.contains(
      "<w:hyperlink r:id=\"rId9\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\"><w:r><w:rPr><w:b/><w:bCs/></w:rPr><w:t>c</w:t></w:r><w:r><w:t>d</w:t></w:r></w:hyperlink>",
    ),
  )
}

///|
test "format: paraId and rsids survive a split" {
  let body = "<w:p w14:paraId=\"1A2B3C4D\"><w:r w:rsidR=\"00AB12CD\"><w:t>abcd</w:t></w:r></w:p>"
  let (spliced, _) = assert_format_edits(
    body,
    paragraph=0,
    [format_span(1, 3)],
    bold=true,
  )
  assert_true(spliced.contains("<w:p w14:paraId=\"1A2B3C4D\">"))
  // Every clone carries the source run's attributes byte-identically.
  assert_true(
    spliced.contains(
      "<w:r w:rsidR=\"00AB12CD\"><w:t>a</w:t></w:r>" +
      "<w:r w:rsidR=\"00AB12CD\"><w:rPr><w:b/><w:bCs/></w:rPr><w:t>bc</w:t></w:r>" +
      "<w:r w:rsidR=\"00AB12CD\"><w:t>d</w:t></w:r>",
    ),
  )
}

///|
test "format: extension content is vouched by namespace URI" {
  // The w14 prefix resolves to the recognized 2010 wordml extension
  // namespace, so the trailing glow block is warranted and bold inserts
  // before it — in place, no split.
  let body = "<w:p><w:r><w:rPr><w:i/><w14:glow w14:rad=\"101600\"/></w:rPr><w:t>ab</w:t></w:r></w:p>"
  let (spliced, receipt) = assert_format_edits(
    body,
    paragraph=0,
    [format_span(0, 2)],
    bold=true,
  )
  assert_eq(receipt.splits, 0)
  assert_true(
    spliced.contains(
      "<w:rPr><w:b/><w:bCs/><w:i/><w14:glow w14:rad=\"101600\"/></w:rPr>",
    ),
  )
}

///|
test "format: color and underline compose with theme removal" {
  let body = "<w:p><w:r><w:rPr><w:color w:val=\"auto\" w:themeColor=\"accent1\"/></w:rPr><w:t>ab</w:t></w:r></w:p>"
  let (spliced, _) = assert_format_edits(
    body,
    paragraph=0,
    [format_span(0, 2)],
    color="00B050",
    underline=true,
  )
  assert_true(
    spliced.contains(
      "<w:rPr><w:color w:val=\"00B050\"/><w:u w:val=\"single\"/></w:rPr>",
    ),
  )
  assert_eq(
    verify_run_format(
      format_result_run_slice(spliced, 0, 0),
      prefix="w",
      format=docx_direct_format(color="00B050", underline=true),
    ),
    None,
  )
}

///|
test "format: the request-shape refusal matrix" {
  let body = "<w:p><w:r><w:t>abcd</w:t></w:r></w:p>"
  assert_format_refusal(
    body,
    paragraph=1,
    [format_span(0, 1)],
    refusal="FormatInvalidParagraph",
    bold=true,
  )
  assert_format_refusal(
    body,
    paragraph=0,
    [format_span(0, 99)],
    refusal="FormatInvalidRange",
    bold=true,
  )
  assert_format_refusal(
    body,
    paragraph=0,
    [format_span(2, 2)],
    refusal="EmptyFormatSpan",
    bold=true,
  )
  assert_format_refusal(
    body,
    paragraph=0,
    [format_span(2, 3), format_span(0, 1)],
    refusal="UnorderedFormatSpans",
    bold=true,
  )
  assert_format_refusal(
    body,
    paragraph=0,
    [format_span(0, 3), format_span(2, 4)],
    refusal="FormatSpanOverlap",
    bold=true,
  )
}

///|
test "format: the structural refusal matrix" {
  // A covered tab is a projected atom v1 does not format.
  assert_format_refusal(
    "<w:p><w:r><w:t>a</w:t><w:tab/><w:t>b</w:t></w:r></w:p>",
    paragraph=0,
    [format_span(0, 3)],
    refusal="ProjectedAtom",
    bold=true,
  )
  // Suppressed content strictly inside the span.
  assert_format_refusal(
    "<w:p><w:r><w:t>ab</w:t></w:r><w:del w:id=\"1\" w:author=\"a\" w:date=\"2020-01-01T00:00:00Z\"><w:r><w:delText>x</w:delText></w:r></w:del><w:r><w:t>cd</w:t></w:r></w:p>",
    paragraph=0,
    [format_span(1, 3)],
    refusal="FormatSuppressedRegion",
    bold=true,
  )
  // A tracked insertion is a restricted region even wholly inside.
  assert_format_refusal(
    "<w:p><w:ins w:id=\"1\" w:author=\"a\" w:date=\"2020-01-01T00:00:00Z\"><w:r><w:t>abc</w:t></w:r></w:ins></w:p>",
    paragraph=0,
    [format_span(0, 2)],
    refusal="FormatRestrictedRegion",
    bold=true,
  )
  // Field instruction machinery.
  assert_format_refusal(
    "<w:p><w:r><w:fldChar w:fldCharType=\"begin\"/></w:r><w:r><w:t>PAGE</w:t></w:r><w:r><w:fldChar w:fldCharType=\"end\"/></w:r></w:p>",
    paragraph=0,
    [format_span(0, 2)],
    refusal="FormatFieldInstruction",
    bold=true,
  )
  // CDATA-backed text.
  assert_format_refusal(
    "<w:p><w:r><w:t><![CDATA[ab]]></w:t></w:r></w:p>",
    paragraph=0,
    [format_span(0, 1)],
    refusal="FormatCDataContext",
    bold=true,
  )
}

///|
test "format: rPr defects map onto the formatting taxonomy" {
  assert_format_refusal(
    "<w:p><w:r><w:rPr><w:b/></w:rPr><w:rPr><w:i/></w:rPr><w:t>ab</w:t></w:r></w:p>",
    paragraph=0,
    [format_span(0, 2)],
    refusal="FormatDuplicateRpr",
    bold=true,
  )
  assert_format_refusal(
    "<w:p><w:r><w:rPr><w:i/><w:rPrChange w:id=\"1\" w:author=\"a\" w:date=\"2020-01-01T00:00:00Z\"><w:rPr><w:b/></w:rPr></w:rPrChange></w:rPr><w:t>ab</w:t></w:r></w:p>",
    paragraph=0,
    [format_span(0, 2)],
    refusal="FormatRprChange",
    bold=true,
  )
  assert_format_refusal(
    "<w:p><w:r><w:rPr><w:b/><w:b/></w:rPr><w:t>ab</w:t></w:r></w:p>",
    paragraph=0,
    [format_span(0, 2)],
    refusal="FormatDuplicateProperty",
    bold=true,
  )
  assert_format_refusal(
    "<w:p><w:r><w:rPr><w:sz w:val=\"24\"/><w:i/></w:rPr><w:t>ab</w:t></w:r></w:p>",
    paragraph=0,
    [format_span(0, 2)],
    refusal="AmbiguousRprOrder",
    bold=true,
  )
}

///|
test "format: a run with structural extras cannot be split" {
  // `w:lastRenderedPageBreak` is transparent to the projection, so the
  // partial span reaches the splitter — which refuses the child it
  // cannot clone soundly.
  assert_format_refusal(
    "<w:p><w:r><w:t>ab</w:t><w:lastRenderedPageBreak/><w:t>cd</w:t></w:r></w:p>",
    paragraph=0,
    [format_span(1, 2)],
    refusal="UnsplittableRun",
    bold=true,
  )
}

///|
test "format: a default-namespace run has no vouchable attribute binding" {
  let source = "<document xmlns=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><body><p><r><t>abcd</t></r></p></body></document>"
  assert_format_refusal_in(
    source,
    paragraph=0,
    [format_span(1, 3)],
    refusal="UnsupportedNamespaceBinding",
    bold=true,
  )
}

///|
/// The shared-gate parity matrix: every reused N0c2 gate refuses under the
/// FORMATTING taxonomy too, on the same fixture shapes the text planner
/// pins.
test "format: the shared-gate parity matrix" {
  // A zero-width visible barrier (w:br) strictly inside the span.
  assert_format_refusal(
    "<w:p><w:r><w:t>ab</w:t><w:br/><w:t>cd</w:t></w:r></w:p>",
    paragraph=0,
    [format_span(1, 3)],
    refusal="FormatVisibleBarrier",
    bold=true,
  )
  // A logically joined paragraph is multi-physical.
  assert_format_refusal(
    "<w:p><w:pPr><w:rPr><w:del/></w:rPr></w:pPr><w:r><w:t>first</w:t></w:r></w:p><w:p><w:r><w:t>second</w:t></w:r></w:p>",
    paragraph=0,
    [format_span(0, 1)],
    refusal="FormatMultiPhysicalParagraph",
    bold=true,
  )
  // A `separate` with no begin is malformed outright.
  assert_format_refusal(
    "<w:p><w:r><w:fldChar w:fldCharType=\"separate\"/></w:r><w:r><w:t>text</w:t></w:r></w:p>",
    paragraph=0,
    [format_span(0, 1)],
    refusal="FormatMalformedField",
    bold=true,
  )
  // A truncated field's result carries the classifier's refusal.
  assert_format_refusal(
    "<w:p><w:r><w:fldChar w:fldCharType=\"begin\"/></w:r><w:r><w:instrText>PAGE</w:instrText></w:r><w:r><w:fldChar w:fldCharType=\"separate\"/></w:r><w:r><w:t>7</w:t></w:r></w:p>",
    paragraph=0,
    [format_span(0, 1)],
    refusal="FormatRefusedField",
    bold=true,
  )
  // Checkbox content controls refuse by ancestry.
  assert_format_refusal(
    "<w:p><w:sdt><w:sdtPr><w14:checkbox/></w:sdtPr><w:sdtContent><w:r><w:t>first</w:t></w:r><w:r><w:t>extra</w:t></w:r></w:sdtContent></w:sdt></w:p>",
    paragraph=0,
    [format_span(0, 1)],
    refusal="FormatCheckboxControl",
    bold=true,
  )
  // A runless direct w:t has no run shell to carry formatting.
  assert_format_refusal(
    "<w:p><w:r><w:t>ab</w:t></w:r><w:t>cd</w:t></w:p>",
    paragraph=0,
    [format_span(1, 3)],
    refusal="FormatUnsupportedTextSource",
    bold=true,
  )
}

///|
test "format: duplicated projection and cross-paragraph reuse refuse" {
  // Force the duplicate-projection defect the same way the N0c2 suite
  // does: append an existing contribution again.
  let source = format_fixture_source("<w:p><w:r><w:t>ab</w:t></w:r></w:p>")
  let bytes = @utf8.encode(source)
  let projection = surgery_native_projection(source)
  let paragraph = projection.paragraphs[0]
  let mut duplicated = false
  for contribution in paragraph.contributions {
    if contribution.kind is ProjectedText(FromText) && !duplicated {
      paragraph.contributions.push(contribution)
      duplicated = true
    }
  }
  assert_true(duplicated)
  try
    plan_paragraph_format_edits(
      projection,
      bytes,
      0,
      [format_span(0, 1)],
      docx_direct_format(bold=true),
    )
    |> ignore
  catch {
    Unsupported(message~) =>
      assert_true(message.contains("[FormatDuplicateSource]"), msg=message)
    _ => fail("expected a typed refusal")
  } noraise {
    _ => fail("expected refusal [FormatDuplicateSource]")
  }
  // And a run claimed by two paragraphs.
  let reuse_source = format_fixture_source(
    "<w:p><w:r><w:t>one</w:t></w:r></w:p><w:p><w:r><w:t>two</w:t></w:r></w:p>",
  )
  let reuse_bytes = @utf8.encode(reuse_source)
  let reuse_projection = surgery_native_projection(reuse_source)
  reuse_projection.paragraphs[1].runs.push(
    reuse_projection.paragraphs[0].runs[0],
  )
  try
    plan_paragraph_format_edits(
      reuse_projection,
      reuse_bytes,
      0,
      [format_span(0, 1)],
      docx_direct_format(bold=true),
    )
    |> ignore
  catch {
    Unsupported(message~) =>
      assert_true(
        message.contains("[FormatCrossParagraphSourceReuse]"),
        msg=message,
      )
    _ => fail("expected a typed refusal")
  } noraise {
    _ => fail("expected refusal [FormatCrossParagraphSourceReuse]")
  }
}

///|
/// Every restricted construct refuses under the formatting taxonomy too —
/// each by name, because an aggregate threshold cannot show that each
/// construct individually reached the refusal.
test "format: every restricted construct refuses" {
  let mc = "xmlns:mc=\"http://schemas.openxmlformats.org/markup-compatibility/2006\""
  for
    probe in [
      (
        "sdt", "<w:p><w:sdt><w:sdtPr><w:alias w:val=\"Client\"/></w:sdtPr><w:sdtContent><w:r><w:t>ab</w:t></w:r></w:sdtContent></w:sdt></w:p>",
      ),
      (
        "ins", "<w:p><w:ins w:id=\"9\" w:author=\"Ada\" w:date=\"2001-01-01T00:00:00Z\"><w:r><w:t>ab</w:t></w:r></w:ins></w:p>",
      ),
      (
        "mc:Fallback",
        "<w:p><mc:AlternateContent \{mc}><mc:Choice Requires=\"wps\"><w:r><w:t>zz</w:t></w:r></mc:Choice><mc:Fallback><w:r><w:t>ab</w:t></w:r></mc:Fallback></mc:AlternateContent></w:p>",
      ),
      (
        "txbxContent", "<w:p><w:r><w:pict><v:shape><v:textbox><w:txbxContent><w:p><w:r><w:t>ab</w:t></w:r></w:p></w:txbxContent></v:textbox></v:shape></w:pict></w:r></w:p>",
      ),
    ] {
    let (name, body) = probe
    let source = format_fixture_source(body)
    let bytes = @utf8.encode(source)
    let projection = surgery_native_projection(source)
    let mut target = -1
    for index, paragraph in projection.paragraphs {
      if paragraph.projection_end - paragraph.projection_start >= 2 {
        if target < 0 {
          target = index
        }
      }
    }
    assert_true(target >= 0, msg=name)
    try
      plan_paragraph_format_edits(
        projection,
        bytes,
        target,
        [format_span(0, 2)],
        docx_direct_format(bold=true),
      )
      |> ignore
    catch {
      Unsupported(message~) =>
        assert_true(
          message.contains("[FormatRestrictedRegion]") ||
          message.contains("[FormatCrossParagraphSourceReuse]"),
          msg="\{name}: \{message}",
        )
      _ => fail("expected a typed refusal for \{name}")
    } noraise {
      _ => fail("expected a refusal for \{name}")
    }
  }
}

///|
/// The whole refusal taxonomy, pinned by name: every class keeps its slug
/// and a non-empty reason, including the classes nothing constructs yet.
test "format: the refusal taxonomy is pinned by name" {
  let classes : Array[(FormatSurgeryRefusal, String)] = [
    (FormatInvalidParagraph, "invalid-paragraph"),
    (FormatInvalidRange, "invalid-range"),
    (EmptyFormatSpan, "empty-range"),
    (UnorderedFormatSpans, "unordered-spans"),
    (FormatSpanOverlap, "span-overlap"),
    (FormatMultiPhysicalParagraph, "multi-physical-paragraph"),
    (FormatNonScalarBoundary, "non-scalar-boundary"),
    (FormatCDataContext, "cdata"),
    (FormatVisibleBarrier, "visible-barrier"),
    (FormatSuppressedRegion, "suppressed-region"),
    (FormatRestrictedRegion, "restricted-region"),
    (ProjectedAtom, "projected-atom"),
    (FormatFieldInstruction, "field-instruction"),
    (FormatMalformedField, "malformed-field"),
    (FormatRefusedField, "refused-field"),
    (FormatCheckboxControl, "checkbox-control"),
    (FormatDuplicateSource, "duplicate-source"),
    (FormatCrossParagraphSourceReuse, "cross-paragraph-reuse"),
    (FormatUnsupportedTextSource, "unsupported-source"),
    (UnsplittableRun, "unsplittable-run"),
    (UnsupportedNamespaceBinding, "unsupported-namespace"),
    (FormatDuplicateRpr, "duplicate-rpr"),
    (FormatDuplicateProperty, "duplicate-property"),
    (FormatRprChange, "rpr-change"),
    (AmbiguousRprOrder, "ambiguous-rpr-order"),
    (UnsupportedRpr, "unsupported-rpr"),
    (FormatBudgetExceeded, "budget-exceeded"),
    (FormatInternalPlanConflict, "internal"),
  ]
  assert_eq(classes.length(), 28)
  for entry in classes {
    let (kind, slug) = entry
    assert_eq(format_surgery_refusal_slug(kind), slug)
    assert_true(format_surgery_refusal_reason(kind).length() > 0)
  }
}

///|
/// The High from review round 1: a non-scalar endpoint must refuse even
/// when the satisfaction or full-coverage shortcut would otherwise skip
/// byte planning entirely.
test "format: non-scalar endpoints refuse before any shortcut" {
  // Already-bold emoji, span bisecting the surrogate pair: the
  // already-satisfied path must not swallow the defect.
  assert_format_refusal(
    "<w:p><w:r><w:rPr><w:b/><w:bCs/></w:rPr><w:t>\u{1F600}</w:t></w:r></w:p>",
    paragraph=0,
    [format_span(0, 1)],
    refusal="FormatNonScalarBoundary",
    bold=true,
  )
  // Unformatted emoji, abutting spans meeting INSIDE the pair: full
  // coverage must not swallow it either.
  assert_format_refusal(
    "<w:p><w:r><w:t>\u{1F600}</w:t></w:r></w:p>",
    paragraph=0,
    [format_span(0, 1), format_span(1, 2)],
    refusal="FormatNonScalarBoundary",
    bold=true,
  )
  // Same shape through a numeric character reference.
  assert_format_refusal(
    "<w:p><w:r><w:rPr><w:b/><w:bCs/></w:rPr><w:t>&#128512;</w:t></w:r></w:p>",
    paragraph=0,
    [format_span(0, 1)],
    refusal="FormatNonScalarBoundary",
    bold=true,
  )
}

///|
/// The whole run is the split footprint, so a duplicated UNSELECTED
/// contribution of a touched run refuses — the partition must never
/// silently choose one occurrence.
test "format: a duplicated unselected contribution of a split run refuses" {
  let source = format_fixture_source(
    "<w:p><w:r><w:t>ab</w:t><w:t>cd</w:t></w:r></w:p>",
  )
  let bytes = @utf8.encode(source)
  let projection = surgery_native_projection(source)
  let paragraph = projection.paragraphs[0]
  // Duplicate the SECOND text's contribution — the span selects only
  // the first.
  let mut duplicated = false
  for contribution in paragraph.contributions {
    if contribution.kind is ProjectedText(FromText) &&
      contribution.value == "cd" &&
      !duplicated {
      paragraph.contributions.push(contribution)
      duplicated = true
    }
  }
  assert_true(duplicated)
  try
    plan_paragraph_format_edits(
      projection,
      bytes,
      0,
      [format_span(0, 1)],
      docx_direct_format(bold=true),
    )
    |> ignore
  catch {
    Unsupported(message~) =>
      assert_true(message.contains("[FormatDuplicateSource]"), msg=message)
    _ => fail("expected a typed refusal")
  } noraise {
    _ => fail("expected refusal [FormatDuplicateSource]")
  }
}

///|
/// Hostile spellings inside the split footprint survive byte-for-byte:
/// single-quoted and oddly spaced attributes, entity text, and the run's
/// own attribute list — pinned by FULL-document equality, which no
/// alternative mutation can slip past.
test "format: hostile spellings survive the split byte-for-byte" {
  let body = "<w:p><w:r  w:rsidR='00AB12CD' ><w:rPr><w:i/></w:rPr><w:t xml:space = 'default' >a&amp;b cd</w:t></w:r></w:p>"
  let (spliced, _) = assert_format_edits(
    body,
    paragraph=0,
    [format_span(0, 4)],
    bold=true,
  )
  inspect(
    spliced,
    content=(
      #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:w14="http://schemas.microsoft.com/office/word/2010/wordml" xmlns:v="urn:schemas-microsoft-com:vml"><w:body><w:p><w:r  w:rsidR='00AB12CD' ><w:rPr><w:b/><w:bCs/><w:i/></w:rPr><w:t xml:space="preserve" >a&amp;b </w:t></w:r><w:r  w:rsidR='00AB12CD' ><w:rPr><w:i/></w:rPr><w:t xml:space = 'default' >cd</w:t></w:r></w:p></w:body></w:document>
    ),
  )
}

///|
/// Round 2's Medium: a tolerated run that ENCLOSES a checkbox control
/// (its glyph contributions are zero-width and unselected) must refuse
/// with the structural class before any in-place shortcut.
test "format: a run enclosing a checkbox refuses before the shortcut" {
  assert_format_refusal(
    "<w:p><w:r><w:t>a</w:t><w:sdt><w:sdtPr><w14:checkbox/></w:sdtPr><w:sdtContent><w:t>x</w:t></w:sdtContent></w:sdt></w:r></w:p>",
    paragraph=0,
    [format_span(0, 1)],
    refusal="FormatCheckboxControl",
    bold=true,
  )
  // The same class of escape through a tracked insertion the run
  // tolerates as its own child.
  assert_format_refusal(
    "<w:p><w:r><w:t>a</w:t><w:ins w:id=\"9\" w:author=\"Ada\" w:date=\"2001-01-01T00:00:00Z\"><w:t>x</w:t></w:ins></w:r></w:p>",
    paragraph=0,
    [format_span(0, 1)],
    refusal="FormatRestrictedRegion",
    bold=true,
  )
}

///|
/// Round 3's Medium: an identity-bearing attribute must never be
/// duplicated by a clone-split — on the run or on a text element — while
/// full coverage (which clones nothing) still formats in place.
test "format: identity-bearing attributes refuse the split" {
  assert_format_refusal(
    "<w:p><w:r xml:id=\"r1\"><w:t>abcd</w:t></w:r></w:p>",
    paragraph=0,
    [format_span(1, 3)],
    refusal="UnsplittableRun",
    bold=true,
  )
  assert_format_refusal(
    "<w:p><w:r><w:t xml:id=\"t1\">abcd</w:t></w:r></w:p>",
    paragraph=0,
    [format_span(1, 3)],
    refusal="UnsplittableRun",
    bold=true,
  )
  // Full coverage clones nothing, so the identity survives uniquely.
  let (spliced, receipt) = assert_format_edits(
    "<w:p><w:r xml:id=\"r1\"><w:t>abcd</w:t></w:r></w:p>",
    paragraph=0,
    [format_span(0, 4)],
    bold=true,
  )
  assert_eq(receipt.splits, 0)
  assert_true(
    spliced.contains(
      "<w:r xml:id=\"r1\"><w:rPr><w:b/><w:bCs/></w:rPr><w:t>abcd</w:t></w:r>",
    ),
  )
}

///|
/// The values of identity-bearing attributes (local name `id` under any
/// prefix) in one element's open tag — quote-aware, whitespace-tolerant.
fn collect_identity_values(
  source : Bytes,
  element : ScannedElement,
) -> Array[String] {
  let values : Array[String] = []
  let stop = run_surgery_open_tag_end(element)
  let mut at = element.byte_start + 1
  while at < stop &&
        source[at] != b'>' &&
        source[at] != b'/' &&
        !is_xml_ws(source[at]) {
    at += 1
  }
  while at < stop {
    if is_xml_ws(source[at]) {
      at += 1
      continue
    }
    if source[at] == b'>' || source[at] == b'/' {
      break
    }
    let name_start = at
    while at < stop && source[at] != b'=' && !is_xml_ws(source[at]) {
      at += 1
    }
    let name_builder = StringBuilder()
    for index in name_start..<at {
      if source[index] < b'\x80' {
        name_builder.write_char(source[index].to_int().unsafe_to_char())
      }
    }
    let (_, attribute_local) = split_qname(name_builder.to_string())
    while at < stop && source[at] != b'"' && source[at] != b'\'' {
      at += 1
    }
    if at >= stop {
      break
    }
    let quote = source[at]
    at += 1
    let value_start = at
    while at < stop && source[at] != quote {
      at += 1
    }
    if attribute_local == "id" {
      let value_builder = StringBuilder()
      for index in value_start..<at {
        if source[index] < b'\x80' {
          value_builder.write_char(source[index].to_int().unsafe_to_char())
        }
      }
      values.push(value_builder.to_string())
    }
    at += 1
  }
  values
}

///|
/// Round 4's Medium: the cloned rPr SUBTREE is part of the split
/// footprint too — an identity on the container or any descendant
/// refuses.
test "format: identity inside the rPr subtree refuses the split" {
  assert_format_refusal(
    "<w:p><w:r><w:rPr xml:id=\"rp1\"><w:i/></w:rPr><w:t>abcd</w:t></w:r></w:p>",
    paragraph=0,
    [format_span(1, 3)],
    refusal="UnsplittableRun",
    bold=true,
  )
  assert_format_refusal(
    "<w:p><w:r><w:rPr><w:i xml:id=\"i1\"/></w:rPr><w:t>abcd</w:t></w:r></w:p>",
    paragraph=0,
    [format_span(1, 3)],
    refusal="UnsplittableRun",
    bold=true,
  )
}

///|
/// Round 5's Medium: a tolerated run nesting another run cannot be
/// mutated — the nested text is outside the outer run's own coverage,
/// yet an outer rPr edit would wrap it in the new formatting.
test "format: a run nesting another run refuses" {
  assert_format_refusal(
    "<w:p><w:r><w:t>ab</w:t><w:r><w:t>XX</w:t></w:r><w:t>cd</w:t></w:r></w:p>",
    paragraph=0,
    [format_span(0, 2), format_span(4, 6)],
    refusal="FormatUnsupportedTextSource",
    bold=true,
  )
  // Even full-span coverage refuses: the nested run would inherit the
  // outer formatting without carrying it explicitly, which the direct
  // readback could never verify.
  assert_format_refusal(
    "<w:p><w:r><w:t>ab</w:t><w:r><w:t>XX</w:t></w:r><w:t>cd</w:t></w:r></w:p>",
    paragraph=0,
    [format_span(0, 6)],
    refusal="FormatUnsupportedTextSource",
    bold=true,
  )
}
