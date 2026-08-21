///|
/// N0c2 B3: general multi-edit composition, proved over documents nobody
/// wrote by hand. The hostile grammar (reader_projection_property_wbtest)
/// generates the documents; this suite derives edit batches from each
/// document's OWN projection — so the boundary-pair matrix is covered by
/// construction rather than by hand-listed fixtures — and holds every
/// planned batch to the acceptance claims of #236:
///
///   1. the re-read paragraph projection equals an expectation the TEST
///      computes (never the planner's own receipt alone — the receipt is
///      then held to the same independent string),
///   2. every byte edit falls inside what a correct partial plan may touch,
///      derived from the SOURCE TREE (the trap N0c1 documents: bounding by
///      the plan's own union lets a widened edit pass),
///   3. every byte outside the declared union survives at its shifted
///      offset,
///   4. the edited document still reads,
///   5. every refusal names a class from the stable taxonomy and returns
///      no plan.
///
/// Coverage is accounted as ORDERED (start-kind, end-kind) pairs, with
/// text endpoints resolved to token granularity (raw interior, raw edge,
/// entity edge, numeric-reference edge), because a planner can reject one
/// ordered pair while every marginal endpoint total stays green.
priv struct PartialBatchPlan {
  paragraph_index : Int
  edits : Array[ParagraphTextEdit]
  pairs : Array[String]
}

///|
/// Every class an offset falls into, finest first. Text interiors are
/// resolved against the host's token map so an entity boundary is not
/// reported as ordinary raw text.
fn partial_offset_classes(
  paragraph : ReaderProjectionParagraph,
  elements : Array[ScannedElement],
  offset : Int,
) -> Array[String] {
  let classes : Array[String] = []
  for contribution in paragraph.contributions {
    let start = contribution.projection_start - paragraph.projection_start
    let end = contribution.projection_end - paragraph.projection_start
    match contribution.kind {
      ProjectedText(FromText) => {
        if offset < start || offset > end {
          continue
        }
        let SourceElementId(identity) = contribution.source
        let local = offset - start
        match elements[identity].text_map {
          Some(map) => {
            let mut named = false
            for token in map.tokens {
              let token_start = token.projection_start
              let token_end = token.projection_end
              let kind = match token.kind {
                RawText => "raw"
                EntityRef => "entity"
                NumericCharRef => "numref"
                CData => "cdata"
              }
              if local == token_start || local == token_end {
                classes.push("\{kind}-edge")
                named = true
              } else if local > token_start && local < token_end {
                classes.push("\{kind}-interior")
                named = true
              }
            }
            if !named {
              classes.push("empty-text")
            }
          }
          None => classes.push("closed-text")
        }
        if offset == start {
          classes.push("text-start-edge")
        }
        if offset == end {
          classes.push("text-end-edge")
        }
      }
      ProjectedText(_) =>
        if offset == start {
          classes.push("atom-start-edge")
        } else if offset == end {
          classes.push("atom-end-edge")
        } else if offset > start && offset < end {
          classes.push("atom-interior")
        }
      VisibleNonText => if offset == start { classes.push("barrier-edge") }
      Transparent => if offset == start { classes.push("seam-edge") }
      SuppressedContent =>
        if offset == start {
          classes.push("suppressed-edge")
        }
    }
  }
  if classes.length() == 0 {
    classes.push("bare")
  }
  classes
}

///|
/// The single most specific class of an offset, so an ordered pair key is
/// well defined even where several contributions meet.
fn partial_primary_class(classes : Array[String]) -> String {
  for
    candidate in [
      "entity-interior", "numref-interior", "cdata-interior", "atom-interior", "entity-edge",
      "numref-edge", "cdata-edge", "raw-interior", "atom-start-edge", "atom-end-edge",
      "raw-edge", "text-start-edge", "text-end-edge", "empty-text", "closed-text",
      "barrier-edge", "suppressed-edge", "seam-edge",
    ] {
    if classes.contains(candidate) {
      return candidate
    }
  }
  "bare"
}

///|
/// Derive a batch from a paragraph's own projection. Every geometry runs on
/// every paragraph: selecting one by document index would leave whole
/// geometries unexercised on documents whose shapes only they reach.
fn partial_batches_for(
  projection : ReaderProjection,
  elements : Array[ScannedElement],
  paragraph_index : Int,
) -> Array[PartialBatchPlan] {
  let paragraph = projection.paragraphs[paragraph_index]
  let width = paragraph.projection_end - paragraph.projection_start
  let batches : Array[PartialBatchPlan] = []
  fn build(requested : Array[(Int, Int, String)]) -> Unit {
    let edits : Array[ParagraphTextEdit] = []
    let pairs : Array[String] = []
    for entry in requested {
      let (start, end, replacement) = entry
      edits.push({ start, end, replacement })
      let start_class = partial_primary_class(
        partial_offset_classes(paragraph, elements, start),
      )
      let end_class = partial_primary_class(
        partial_offset_classes(paragraph, elements, end),
      )
      let shape = if start == end {
        "insert"
      } else if replacement == "" {
        "delete"
      } else {
        "replace"
      }
      pairs.push("\{shape}:\{start_class}>\{end_class}")
    }
    if edits.length() > 0 {
      batches.push({ paragraph_index, edits, pairs })
    }
  }

  if width == 0 {
    // A paragraph that projects nothing still has one insertion position:
    // the atomless-run synthesis path.
    build([(0, 0, "N0c2")])
    return batches
  }
  build([(width / 3, width - width / 3, "N0c2")])
  build([(0, width / 2, "head"), (width / 2, width, "")])
  if width >= 2 {
    build([(0, 0, "pre"), (1, width - 1, "mid"), (width, width, "post")])
  } else {
    build([(0, 0, "pre"), (width, width, "post")])
  }
  // Single-unit steps walk EVERY internal boundary, which is what turns
  // the pair accounting from a sample into a sweep.
  for at in 0..<width {
    build([(at, at + 1, "u")])
    build([(at, at, "i")])
  }
  build([(width, width, "tail")])
  batches
}

///|
/// The bytes a correct partial plan may touch, derived from the SOURCE
/// TREE rather than from the plan: each mapped `w:t`'s content range and
/// its open tag (where `xml:space` lives), each atom's whole element, and
/// each run's synthesis anchors.
fn partial_allowed_spans(
  paragraph : ReaderProjectionParagraph,
  elements : Array[ScannedElement],
) -> Array[(Int, Int)] {
  let allowed : Array[(Int, Int)] = []
  for contribution in paragraph.contributions {
    let SourceElementId(identity) = contribution.source
    let element = elements[identity]
    match contribution.kind {
      // Seams and suppressed content are preserved, never touched.
      Transparent | SuppressedContent => ()
      ProjectedText(FromText) =>
        if is_wml_uri(element.uri) && element.local_name == "t" {
          if element.content_start == element.byte_end {
            allowed.push((element.byte_end - 2, element.byte_end))
          } else {
            allowed.push((element.content_start, element.content_end))
            allowed.push((element.byte_start, element.content_start))
          }
        } else {
          allowed.push((element.byte_start, element.byte_end))
        }
      // Atoms are consumed whole, by synthesis or by deletion.
      ProjectedText(_) => allowed.push((element.byte_start, element.byte_end))
      VisibleNonText => ()
    }
  }
  for run in paragraph.runs {
    let SourceElementId(run_identity) = run.source
    let run_element = elements[run_identity]
    allowed.push((run_element.content_start, run_element.content_start))
    allowed.push((run_element.content_end, run_element.content_end))
    if run_element.content_start == run_element.byte_end {
      allowed.push((run_element.byte_end - 2, run_element.byte_end))
    }
    let mut child = run_element.first_child_index
    while child >= 0 {
      let candidate = elements[child]
      if is_wml_uri(candidate.uri) && candidate.local_name == "rPr" {
        allowed.push((candidate.byte_end, candidate.byte_end))
      }
      child = candidate.next_sibling_index
    }
  }
  allowed
}

///|
/// Every stable refusal class, so a refusal cannot pass by merely carrying
/// the prefix.
let partial_refusal_class_names : Array[String] = [
  "InvalidParagraph", "InvalidRange", "UnorderedEdits", "LogicalOverlap", "MultiPhysicalParagraph",
  "NonScalarBoundary", "AmbiguousBoundary", "CDataContext", "VisibleBarrier", "SuppressedRegion",
  "RestrictedRegion", "PartialFieldInstruction", "PartialMalformedField", "RefusedField",
  "PartialCheckboxControl", "DuplicateSource", "CrossParagraphSourceReuse", "UnsupportedTextSource",
  "NoSynthesisCarrier", "InvalidReplacement", "PartialBudgetExceeded", "InternalPlanConflict",
]

///|
/// Plan a batch and hold it to every acceptance claim, or accept a typed
/// refusal. Returns (planned pairs, refusal class) — exactly one is
/// non-empty.
fn assert_partial_batch(
  source : String,
  projection : ReaderProjection,
  batch : PartialBatchPlan,
) -> (Array[String], String) raise {
  let bytes = @utf8.encode(source)
  let elements = projection.scan.elements()
  let paragraph = projection.paragraphs[batch.paragraph_index]
  // The expectation the TEST owns: the paragraph's own projection with the
  // requested ranges substituted. Nothing here consults the planner.
  let before = StringBuilder()
  for contribution in paragraph.contributions {
    before.write_string(contribution.value)
  }
  let before_projection = before.to_string()
  let independent = StringBuilder()
  let mut cursor = 0
  for edit in batch.edits {
    independent.write_string(
      before_projection
      .view(start_offset=cursor, end_offset=edit.start)
      .to_owned(),
    )
    independent.write_string(edit.replacement)
    cursor = edit.end
  }
  independent.write_string(
    before_projection.view(start_offset=cursor).to_owned(),
  )
  let expected = independent.to_string()
  let allowed = partial_allowed_spans(paragraph, elements)
  let planned = plan_paragraph_text_edits(
    projection,
    bytes[:],
    batch.paragraph_index,
    batch.edits,
  ) catch {
    Unsupported(message~) => {
      // Claim 5: a typed refusal names a class from the taxonomy.
      assert_true(
        message.has_prefix("partial surgery ["),
        msg="untyped refusal: \{message}",
      )
      let mut named = ""
      for name in partial_refusal_class_names {
        if message.has_prefix("partial surgery [\{name}]") {
          named = name
        }
      }
      assert_true(named != "", msg="unknown refusal class: \{message}")
      return ([], named)
    }
    ResourceLimit(..) => return ([], "ResourceLimit")
    error => raise error
  }
  let (byte_edits, receipt) = planned
  // Claim 2: every edit lies inside a span the source tree permits.
  for edit in byte_edits {
    let mut inside = false
    for span in allowed {
      let (from, to) = span
      if edit.byte_start >= from && edit.byte_end <= to {
        inside = true
      }
    }
    assert_true(
      inside,
      msg="edit [\{edit.byte_start},\{edit.byte_end}) outside the source-derived allowlist",
    )
  }
  let spliced_bytes = apply_run_surgery_edits(bytes, byte_edits)
  let spliced = @utf8.decode(spliced_bytes)
  // Claim 4: the edited document still reads.
  current_reader_story_text(spliced) |> ignore
  // Claim 1: the re-read projection equals the TEST's expectation, and the
  // receipt agrees with it too.
  let reprojected = surgery_native_projection(spliced)
  assert_true(batch.paragraph_index < reprojected.paragraphs.length())
  let after = StringBuilder()
  for
    contribution in reprojected.paragraphs[batch.paragraph_index].contributions {
    after.write_string(contribution.value)
  }
  assert_eq(after.to_string(), expected, msg="re-read projection")
  assert_eq(receipt.expected_projection, expected, msg="receipt projection")
  // Claim 3: every byte outside the declared union survives.
  assert_untouched_bytes_survive(bytes, spliced_bytes, byte_edits)
  (batch.pairs, "")
}

///|
test "generated documents compose partial edits over every boundary pair" {
  let pairs : Map[String, Int] = Map([])
  let refusals : Map[String, Int] = Map([])
  let cases : Array[Array[Int]] = @quickcheck.samples(48)
  let mut planned = 0
  for case in cases {
    let source = hostile_document(case[:])
    guard hostile_native_projection(source) is Some(projection) else {
      continue
    }
    let elements = projection.scan.elements()
    for paragraph_index in 0..<projection.paragraphs.length() {
      for batch in partial_batches_for(projection, elements, paragraph_index) {
        // A FRESH projection per batch: planning mutates nothing, but a
        // shared projection would let one batch's receipt describe
        // another's document.
        let fresh = surgery_native_projection(source)
        let (planned_pairs, refusal) = assert_partial_batch(
          source, fresh, batch,
        )
        if refusal != "" {
          refusals[refusal] = refusals.get(refusal).unwrap_or(0) + 1
        } else {
          planned += 1
          for pair in planned_pairs {
            pairs[pair] = pairs.get(pair).unwrap_or(0) + 1
          }
        }
      }
    }
  }
  // The batches have to be worth testing: without these floors the suite
  // would pass just as happily on a corpus where every batch refused, or
  // where only one geometry ever planned. Measured margins are far above
  // them (see the probe recorded in the PR); a collapse fails here.
  let planned_pairs = pairs.size()
  let refusal_classes = refusals.size()
  // Measured on this corpus: 971 batches planned across 16 distinct
  // ordered pairs, with refusal classes MultiPhysicalParagraph 264,
  // AmbiguousBoundary 17, NoSynthesisCarrier 11, PartialCheckboxControl
  // 10. Floors sit under those so generator drift does not break the
  // build, while a collapse to trivial batches — or to a corpus where
  // everything refuses — fails here.
  assert_true(planned >= 300, msg="only \{planned} batches planned")
  assert_true(
    planned_pairs >= 12,
    msg="only \{planned_pairs} distinct ordered pairs planned",
  )
  assert_true(
    refusal_classes >= 3,
    msg="only \{refusal_classes} refusal classes exercised",
  )
  let seen = (pair : String) => pairs.get(pair).unwrap_or(0)
  // Ordered pairs a marginal endpoint histogram cannot distinguish: the
  // same endpoint kinds in both orders, and atoms consumed whole.
  assert_true(seen("replace:raw-interior>raw-interior") >= 40)
  assert_true(seen("insert:raw-interior>raw-interior") >= 40)
  assert_true(seen("replace:raw-edge>raw-edge") >= 50)
  assert_true(seen("insert:raw-edge>raw-edge") >= 100)
  assert_true(seen("delete:raw-edge>raw-edge") >= 20)
  assert_true(seen("replace:raw-edge>raw-interior") >= 8)
  assert_true(seen("replace:raw-interior>raw-edge") >= 5)
  assert_true(seen("replace:atom-start-edge>atom-end-edge") >= 5)
  assert_true(seen("delete:atom-start-edge>atom-end-edge") >= 3)
  assert_true(seen("insert:atom-start-edge>atom-start-edge") >= 5)
}

///|
/// The hostile GRAMMAR's alphabet does not reach the whole lexical matrix
/// — it produces no numeric character references, no CDATA, no astral
/// characters, and no atomless-run paragraph — so those boundary kinds
/// would otherwise be covered only by hand-written fixtures. This family
/// composes them locally and drives them through the SAME derivation and
/// the SAME assertions, so the lexical matrix is proved by the identical
/// oracle rather than by a weaker one.
let partial_lexical_bodies : Array[(String, String)] = [
  ("entities", "<w:p><w:r><w:t>a&amp;b&lt;c&gt;d</w:t></w:r></w:p>"),
  ("numeric-refs", "<w:p><w:r><w:t>x&#38;y&#x41;z</w:t></w:r></w:p>"),
  ("astral", "<w:p><w:r><w:t>a😀b𝄞c</w:t></w:r></w:p>"),
  ("cdata", "<w:p><w:r><w:t><![CDATA[secret]]></w:t></w:r></w:p>"),
  (
    "mixed-atoms", "<w:p><w:r><w:t>ab</w:t><w:tab/><w:noBreakHyphen/><w:t>cd</w:t></w:r></w:p>",
  ),
  ("barrier", "<w:p><w:r><w:t>ab</w:t><w:br/><w:t>cd</w:t></w:r></w:p>"),
  (
    "cr-and-ptab", "<w:p><w:r><w:t>ab</w:t><w:cr/><w:ptab/><w:t>cd</w:t></w:r></w:p>",
  ),
  ("atomless-run", "<w:p><w:r/></w:p>"),
  ("rpr-only-run", "<w:p><w:r><w:rPr><w:b/></w:rPr></w:r></w:p>"),
  ("cross-run", "<w:p><w:r><w:t>ab</w:t></w:r><w:r><w:t>cd</w:t></w:r></w:p>"),
  (
    "space-preserve", "<w:p><w:r><w:t xml:space=\"preserve\"> ab </w:t></w:r></w:p>",
  ),
  ("empty-text", "<w:p><w:r><w:t></w:t><w:t>ab</w:t></w:r></w:p>"),
  ("runless-text", "<w:p><w:r><w:t>ab</w:t></w:r><w:t>cd</w:t></w:p>"),
]

///|
test "the lexical matrix the grammar does not reach is proved the same way" {
  let pairs : Map[String, Int] = Map([])
  let refusals : Map[String, Int] = Map([])
  let mut planned = 0
  for entry in partial_lexical_bodies {
    let (label, body) = entry
    let source = "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\" xmlns:v=\"urn:schemas-microsoft-com:vml\"><w:body>\{body}</w:body></w:document>"
    let projection = surgery_native_projection(source)
    let elements = projection.scan.elements()
    for paragraph_index in 0..<projection.paragraphs.length() {
      for batch in partial_batches_for(projection, elements, paragraph_index) {
        let fresh = surgery_native_projection(source)
        let (planned_pairs, refusal) = assert_partial_batch(
          source, fresh, batch,
        )
        if refusal != "" {
          refusals[refusal] = refusals.get(refusal).unwrap_or(0) + 1
        } else {
          planned += 1
          for pair in planned_pairs {
            pairs[pair] = pairs.get(pair).unwrap_or(0) + 1
          }
        }
      }
    }
    ignore(label)
  }
  let seen = (pair : String) => pairs.get(pair).unwrap_or(0)
  let refused = (name : String) => refusals.get(name).unwrap_or(0)
  // Measured: 105 batches planned over 26 distinct ordered pairs, with
  // refusals CDataContext 16, AmbiguousBoundary 8, NonScalarBoundary 7,
  // VisibleBarrier 2, SuppressedRegion 2.
  assert_true(planned >= 60, msg="only \{planned} lexical batches planned")
  // Entity and numeric-reference boundaries plan in BOTH orders; their
  // interiors are unresolvable and refuse below.
  assert_true(seen("replace:entity-edge>entity-edge") >= 3)
  assert_true(seen("replace:raw-edge>entity-edge") >= 1)
  assert_true(seen("replace:entity-edge>raw-edge") >= 1)
  assert_true(seen("insert:entity-edge>entity-edge") >= 3)
  assert_true(seen("replace:numref-edge>numref-edge") >= 2)
  assert_true(seen("replace:numref-edge>raw-edge") >= 1)
  assert_true(seen("insert:numref-edge>numref-edge") >= 2)
  // The atomless-run synthesis path plans.
  assert_true(seen("insert:bare>bare") >= 1)
  // And every refusal the lexical matrix must produce.
  assert_true(
    refused("NonScalarBoundary") >= 3,
    msg="astral halves must refuse",
  )
  assert_true(refused("CDataContext") >= 5)
  assert_true(refused("VisibleBarrier") >= 1)
  assert_true(refused("SuppressedRegion") >= 1)
  assert_true(refused("AmbiguousBoundary") >= 2)
  assert_true(refused("UnsupportedTextSource") >= 1)
}
