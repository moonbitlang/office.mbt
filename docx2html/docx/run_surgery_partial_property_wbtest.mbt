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
/// EXHAUSTIVE single-range batches over one paragraph: every (i, j) with
/// i <= j, as a replacement and — when non-empty — as a deletion. Sampled
/// geometries can only demonstrate the pairs they happen to hit, which is
/// why the identity set they produced was not the permitted set.
fn partial_exhaustive_batches_for(
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

  for i in 0..<=width {
    for j in i..<=width {
      if i == j {
        build([(i, j, "X")])
      } else {
        build([(i, j, "X")])
        build([(i, j, "")])
      }
    }
  }
  // Composition shapes the single-range sweep cannot express.
  if width >= 3 {
    build([(0, 1, "A"), (2, 3, "C")])
    build([(0, 0, "P"), (1, width - 1, "M"), (width, width, "S")])
  }
  batches
}

///|
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
    // the atomless-run synthesis path — singly, and composed, since two
    // insertions there share one carrier and one anchor.
    build([(0, 0, "N0c2")])
    build([(0, 0, "X"), (0, 0, "Y")])
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
fn partial_space_declaration_span(
  source : BytesView,
  element : ScannedElement,
) -> (Int, Int)? {
  // The `xml:space="..."` attribute inside an open tag, located by the
  // test rather than borrowed from production.
  let needle = "xml:space=\""
  let limit = element.content_start
  let mut at = element.byte_start
  while at + needle.length() <= limit {
    let mut matched = true
    for offset in 0..<needle.length() {
      if source[at + offset].to_int() != needle[offset].to_int() {
        matched = false
        break
      }
    }
    if matched {
      let mut close = at + needle.length()
      while close < limit && source[close].to_int() != 0x22 {
        close = close + 1
      }
      if close < limit {
        return Some((at, close + 1))
      }
      return None
    }
    at = at + 1
  }
  None
}

///|
/// The licenses a correct plan may consume for THIS request: derived from
/// the source tree and the requested ranges, with multiplicity. Every
/// plan edit must consume one, so an extra edit — even one that
/// reprojects identically, like an empty CDATA at a content boundary —
/// has nothing to spend and fails.
fn partial_expected_licenses(
  source : BytesView,
  paragraph : ReaderProjectionParagraph,
  elements : Array[ScannedElement],
  requested : Array[ParagraphTextEdit],
) -> Array[(Int, Int, Bool)] {
  let licenses : Array[(Int, Int, Bool)] = []
  for contribution in paragraph.contributions {
    let start = contribution.projection_start - paragraph.projection_start
    let end = contribution.projection_end - paragraph.projection_start
    let SourceElementId(identity) = contribution.source
    let element = elements[identity]
    match contribution.kind {
      Transparent | SuppressedContent | VisibleNonText => ()
      ProjectedText(FromText) => {
        guard is_wml_uri(element.uri) && element.local_name == "t" else {
          licenses.push((element.byte_start, element.byte_end, false))
          continue
        }
        if element.content_start == element.byte_end {
          // Self-closing: only its marker, and only if something asks.
          for edit in requested {
            if start <= edit.start && edit.start <= end {
              licenses.push((element.byte_end - 2, element.byte_end, true))
            }
          }
          continue
        }
        guard element.text_map is Some(map) else { continue }
        // One license per requested range that reaches into this host.
        let after = StringBuilder()
        let mut cursor = 0
        let mut touched = false
        for edit in requested {
          let touches = if edit.start == edit.end {
            start <= edit.start && edit.start <= end
          } else {
            edit.start < end && edit.end > start
          }
          if !touches {
            continue
          }
          touched = true
          let clipped_start = if edit.start > start {
            edit.start
          } else {
            start
          }
          let clipped_end = if edit.end < end { edit.end } else { end }
          let range_start = clipped_start - start
          let range_end = clipped_end - start
          match
            (map.byte_offset_at(range_start), map.byte_offset_at(range_end)) {
            (Some(from), Some(to)) => licenses.push((from, to, true))
            _ => ()
          }
          after.write_string(
            contribution.value
            .view(start_offset=cursor, end_offset=range_start)
            .to_owned(),
          )
          after.write_string(edit.replacement)
          cursor = range_end
        }
        if !touched {
          continue
        }
        after.write_string(
          contribution.value.view(start_offset=cursor).to_owned(),
        )
        // The xml:space license exists only when the POST-BATCH content
        // needs preservation — computed here, not asked of the planner.
        let final_content = after.to_string()
        let needs = if final_content.length() == 0 {
          false
        } else {
          let head = final_content.view(start_offset=0, end_offset=1).to_owned()
          let tail = final_content
            .view(start_offset=final_content.length() - 1)
            .to_owned()
          fn edge(one : String) -> Bool {
            let mut code = 0
            for char in one {
              code = char.to_int()
            }
            code == 0x20 || code == 0x09 || code == 0x0A || code == 0x0D
          }

          edge(head) || edge(tail)
        }
        if needs {
          match partial_space_declaration_span(source, element) {
            Some((from, to)) => licenses.push((from, to, true))
            None =>
              licenses.push(
                (element.content_start - 1, element.content_start - 1, true),
              )
          }
        }
      }
      ProjectedText(_) =>
        // An atom is consumed WHOLE by a covering range, or sat beside by
        // an insertion at exactly one of its two projection boundaries.
        for edit in requested {
          if edit.start != edit.end && edit.start <= start && end <= edit.end {
            licenses.push((element.byte_start, element.byte_end, true))
          }
          if edit.start == edit.end && edit.start == start {
            licenses.push((element.byte_start, element.byte_start, true))
          }
          if edit.start == edit.end && edit.start == end {
            licenses.push((element.byte_end, element.byte_end, true))
          }
        }
    }
  }
  // A paragraph that projects nothing: one synthesis license per
  // non-empty insertion requested, at the single form-determined site.
  let mut projecting = 0
  for contribution in paragraph.contributions {
    if contribution.kind is ProjectedText(_) {
      projecting += 1
    }
  }
  if projecting == 0 && paragraph.runs.length() == 1 {
    let SourceElementId(run_identity) = paragraph.runs[0].source
    let run_element = elements[run_identity]
    for edit in requested {
      if edit.start == edit.end && edit.replacement != "" {
        if run_element.content_start == run_element.byte_end {
          licenses.push((run_element.byte_end - 2, run_element.byte_end, true))
        } else {
          let mut anchor = run_element.content_start
          let mut child = run_element.first_child_index
          while child >= 0 {
            let candidate = elements[child]
            if is_wml_uri(candidate.uri) && candidate.local_name == "rPr" {
              anchor = candidate.byte_end
            }
            child = candidate.next_sibling_index
          }
          licenses.push((anchor, anchor, true))
        }
      }
    }
  }
  licenses
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
) -> (Array[String], String, Int) raise {
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
  let licenses = partial_expected_licenses(
    bytes[:],
    paragraph,
    elements,
    batch.edits,
  )
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
      return ([], named, 0)
    }
    // A resource limit is not a partial-surgery refusal class: it
    // propagates rather than counting toward refusal diversity.
    error => raise error
  }
  let (byte_edits, receipt) = planned
  // Claim 2: every edit CONSUMES a license derived from the request. A
  // license is spent when it is used, so a plan cannot pay for two edits
  // with one permission — the multiplicity matters as much as the spans.
  let spent : Array[Bool] = []
  for _ in licenses {
    spent.push(false)
  }
  for edit in byte_edits {
    let mut paid = false
    for index, license in licenses {
      if spent[index] {
        continue
      }
      let (from, to, exact) = license
      let matches = if exact {
        edit.byte_start == from && edit.byte_end == to
      } else {
        edit.byte_start >= from && edit.byte_end <= to
      }
      if matches {
        spent[index] = true
        paid = true
        break
      }
    }
    assert_true(
      paid,
      msg="edit [\{edit.byte_start},\{edit.byte_end}) has no unspent license",
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
  (batch.pairs, "", receipt.touched_source_count)
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
        let (planned_pairs, refusal, carriers) = assert_partial_batch(
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
    planned_pairs >= 16,
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
  // Isolated fixtures give only category-vs-raw pairs. This one puts an
  // entity, a numeric reference and atoms adjacent to each other so the
  // CROSS-category ordered pairs (entity>numref, numref>atom, ...) enter
  // the corpus at all.
  (
    "mixed-categories", "<w:p><w:r><w:t>&amp;&#38;</w:t><w:tab/><w:noBreakHyphen/><w:t>&#60;z</w:t></w:r></w:p>",
  ),
  // Two mixed fixtures, not one: which ordered pairs a sweep can express
  // depends on the paragraph's WIDTH (the geometries are computed from
  // it), so a single arrangement reaches some cross-category keys and
  // not others.
  // atom-start>entity needs an ATOM boundary on the left and an entity
  // edge on the right, which only this arrangement produces.
  (
    "atom-then-entity", "<w:p><w:r><w:t>&amp;</w:t><w:tab/><w:noBreakHyphen/><w:t>&amp;</w:t></w:r></w:p>",
  ),
  (
    "entity-atoms-raw", "<w:p><w:r><w:t>&amp;</w:t><w:tab/><w:noBreakHyphen/><w:t>abc</w:t></w:r></w:p>",
  ),
  // Reference-adjacent-to-raw in BOTH orders, and a numeric reference
  // beside atoms: combinations the isolated fixtures cannot express.
  ("numref-then-raw", "<w:p><w:r><w:t>&#38;abc</w:t></w:r></w:p>"),
  ("raw-then-numref", "<w:p><w:r><w:t>abc&#38;</w:t></w:r></w:p>"),
  ("entity-then-raw", "<w:p><w:r><w:t>&amp;abc</w:t></w:r></w:p>"),
  (
    "atom-then-numref", "<w:p><w:r><w:t>&#38;</w:t><w:tab/><w:noBreakHyphen/><w:t>&#38;</w:t></w:r></w:p>",
  ),
  (
    "mixed-references", "<w:p><w:r><w:t>&amp;&#38;</w:t><w:tab/><w:t>&#60;&gt;</w:t><w:noBreakHyphen/><w:t>&amp;z</w:t></w:r></w:p>",
  ),
]

///|
test "the lexical matrix the grammar does not reach is proved the same way" {
  let pairs : Map[String, Int] = Map([])
  let refusals : Map[String, Int] = Map([])
  let mut planned = 0
  let mut multi_carrier = 0
  for entry in partial_lexical_bodies {
    let (label, body) = entry
    let source = "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\" xmlns:v=\"urn:schemas-microsoft-com:vml\"><w:body>\{body}</w:body></w:document>"
    let projection = surgery_native_projection(source)
    let elements = projection.scan.elements()
    for paragraph_index in 0..<projection.paragraphs.length() {
      for
        batch in partial_exhaustive_batches_for(
          projection, elements, paragraph_index,
        ) {
        let fresh = surgery_native_projection(source)
        let (planned_pairs, refusal, carriers) = assert_partial_batch(
          source, fresh, batch,
        )
        if refusal != "" {
          refusals[refusal] = refusals.get(refusal).unwrap_or(0) + 1
        } else {
          planned += 1
          if batch.edits.length() > 1 && carriers > 1 {
            multi_carrier += 1
          }
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
  // Measured at this commit: 598 batches planned over 66 distinct
  // ordered pairs, 16 of them multi-edit across multiple carriers. The
  // EXACT identity set is the real pin; these are volume floors.
  assert_true(planned >= 550, msg="only \{planned} lexical batches planned")
  // Entity and numeric-reference boundaries plan in BOTH orders; their
  // interiors are unresolvable and refuse below.
  // EXACT identity set, both directions. Inclusion alone would let a
  // pair vanish unnoticed if another appeared, and — worse — would stay
  // green when the planner starts ACCEPTING something it should refuse,
  // since a new key is an unexpected acceptance.
  for key in partial_expected_pairs {
    assert_true(
      pairs.get(key).unwrap_or(0) >= 1,
      msg="ordered pair no longer planned: " + key,
    )
  }
  for key, _ in pairs {
    assert_true(
      partial_expected_pairs.contains(key),
      msg="unexpected ordered pair accepted: " + key,
    )
  }
  let lexical_pairs = pairs.size()
  assert_true(
    lexical_pairs >= 66,
    msg="only \{lexical_pairs} distinct ordered pairs in the lexical family",
  )
  // BOTH orders of every mixed pair: a planner refusing only the
  // unasserted order would otherwise lose a handful of plans while every
  // floor stayed green.
  assert_true(seen("replace:entity-edge>entity-edge") >= 3)
  assert_true(seen("replace:raw-edge>entity-edge") >= 1)
  assert_true(seen("replace:entity-edge>raw-edge") >= 1)
  assert_true(seen("delete:entity-edge>raw-edge") >= 1)
  assert_true(seen("insert:entity-edge>entity-edge") >= 3)
  assert_true(seen("replace:numref-edge>numref-edge") >= 2)
  assert_true(seen("replace:raw-edge>numref-edge") >= 1)
  assert_true(seen("replace:numref-edge>raw-edge") >= 1)
  assert_true(seen("delete:numref-edge>raw-edge") >= 1)
  assert_true(seen("insert:numref-edge>numref-edge") >= 2)
  assert_true(seen("replace:raw-edge>atom-start-edge") >= 1)
  assert_true(seen("replace:atom-end-edge>raw-interior") >= 1)
  assert_true(seen("replace:raw-interior>atom-start-edge") >= 1)
  // CROSS-category pairs: isolated fixtures only ever produce
  // category-vs-raw keys, so a planner could reject entity>numref or
  // numref>atom while every other floor stayed green. The
  // mixed-categories fixture puts an entity, a numeric reference and two
  // ADJACENT atoms side by side — adjacency matters, because at a
  // coincident boundary the finer text-token class masks the atom.
  assert_true(seen("replace:entity-edge>numref-edge") >= 1)
  assert_true(seen("replace:numref-edge>entity-edge") >= 1)
  assert_true(seen("replace:entity-edge>atom-start-edge") >= 1)
  assert_true(seen("replace:numref-edge>atom-start-edge") >= 1)
  assert_true(seen("replace:atom-start-edge>numref-edge") >= 1)
  assert_true(seen("replace:atom-start-edge>entity-edge") >= 1)
  // Multi-edit batches spanning MORE THAN ONE carrier must actually
  // PLAN. Without this the suite accepts a regression that refuses every
  // general composition with InternalPlanConflict: each refusal is typed,
  // so nothing else notices.
  assert_true(
    multi_carrier >= 10,
    msg="only \{multi_carrier} multi-carrier batches planned",
  )
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

///|
test "the source allowlist rejects a plan that widens beyond the request" {
  // The oracle's own discrimination check. Editing the first unit of
  // `a&amp;b&lt;c&gt;d` must not license rewriting the untouched later
  // `&lt;`: the projection would be unchanged and the untouched-byte walk
  // exempts whatever the plan declares, so the allowlist is the only
  // witness that can catch it.
  let source = "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:body><w:p><w:r><w:t>a&amp;b&lt;c&gt;d</w:t></w:r></w:p></w:body></w:document>"
  let projection = surgery_native_projection(source)
  let elements = projection.scan.elements()
  let paragraph = projection.paragraphs[0]
  let requested : Array[ParagraphTextEdit] = [
    { start: 0, end: 1, replacement: "A" },
  ]
  let allowed = partial_expected_licenses(
    @utf8.encode(source)[:],
    paragraph,
    elements,
    requested,
  )
  // Locate the `&lt;` entity's bytes through the host's token map.
  let mut host : ScannedElement? = None
  for contribution in paragraph.contributions {
    if contribution.kind is ProjectedText(FromText) {
      let SourceElementId(identity) = contribution.source
      host = Some(elements[identity])
    }
  }
  guard host is Some(element) else { fail("expected a text host") }
  guard element.text_map is Some(map) else { fail("expected a token map") }
  let mut entity_span : (Int, Int)? = None
  for token in map.tokens {
    if token.kind is EntityRef && token.projection_start == 3 {
      entity_span = Some((token.byte_start, token.byte_end))
    }
  }
  guard entity_span is Some((from, to)) else {
    fail("expected the second entity token")
  }
  let mut licensed = false
  for span in allowed {
    let (span_from, span_to, _) = span
    if from >= span_from && to <= span_to {
      licensed = true
    }
  }
  assert_false(
    licensed,
    msg="the allowlist must not license an untouched later entity",
  )
  // And the requested range itself IS licensed, so the check is not
  // vacuously rejecting everything.
  guard map.byte_offset_at(0) is Some(request_from) else { fail("offset 0") }
  guard map.byte_offset_at(1) is Some(request_to) else { fail("offset 1") }
  let mut request_licensed = false
  for span in allowed {
    let (span_from, span_to, _) = span
    if request_from >= span_from && request_to <= span_to {
      request_licensed = true
    }
  }
  assert_true(request_licensed)
}

///|
test "the allowlist pins the half-open rule and the synthesis anchors" {
  // Two discrimination checks the property suite cannot make, because
  // both defects reproject identically and pass byte accounting.
  //
  // (1) HALF-OPEN. `<w:t>ab</w:t><w:t>cd</w:t>` with [0,1) and [2,3):
  // the second edit only ABUTS the first host, so nothing inside the
  // first host beyond its own requested range may be licensed. Under a
  // closed intersection the first host's content END would be, and a
  // widened plan could insert an empty CDATA there — well-formed,
  // identical projection, and it poisons that host's token map forever.
  let abutting = "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:body><w:p><w:r><w:t>ab</w:t><w:t>cd</w:t></w:r></w:p></w:body></w:document>"
  let projection = surgery_native_projection(abutting)
  let elements = projection.scan.elements()
  let paragraph = projection.paragraphs[0]
  let allowed = partial_expected_licenses(
    @utf8.encode(abutting)[:],
    paragraph,
    elements,
    [
      ({ start: 0, end: 1, replacement: "A" } : ParagraphTextEdit),
      { start: 2, end: 3, replacement: "C" },
    ],
  )
  let mut first_host : ScannedElement? = None
  for contribution in paragraph.contributions {
    if contribution.kind is ProjectedText(FromText) && first_host is None {
      let SourceElementId(identity) = contribution.source
      first_host = Some(elements[identity])
    }
  }
  guard first_host is Some(host) else { fail("expected a first text host") }
  let mut licensed_tail = false
  for span in allowed {
    let (from, to, _) = span
    if host.content_end >= from &&
      host.content_end <= to &&
      from >= host.content_start {
      licensed_tail = true
    }
  }
  assert_false(
    licensed_tail,
    msg="an abutting edit must not license the neighbour's content end",
  )
  // (2) SYNTHESIS ANCHORS. A paragraph that projects text needs no run
  // anchor at all. The run carries an `rPr` so its post-rPr anchor sits
  // OUTSIDE every `w:t` open tag — otherwise the touched host's open-tag
  // span would already license that coordinate and the check would pass
  // whether or not the anchor rule held.
  let simple = "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:body><w:p><w:r><w:rPr><w:b/></w:rPr><w:tab/><w:t>ab</w:t></w:r></w:p></w:body></w:document>"
  let simple_projection = surgery_native_projection(simple)
  let simple_elements = simple_projection.scan.elements()
  let simple_paragraph = simple_projection.paragraphs[0]
  // Edit only inside the text, leaving the tab untouched.
  let simple_allowed = partial_expected_licenses(
    @utf8.encode(simple)[:],
    simple_paragraph,
    simple_elements,
    [({ start: 1, end: 2, replacement: "A" } : ParagraphTextEdit)],
  )
  let SourceElementId(run_identity) = simple_paragraph.runs[0].source
  let run_element = simple_elements[run_identity]
  // The post-rPr anchor coordinate itself.
  let mut anchor = run_element.content_start
  let mut child = run_element.first_child_index
  while child >= 0 {
    let candidate = simple_elements[child]
    if is_wml_uri(candidate.uri) && candidate.local_name == "rPr" {
      anchor = candidate.byte_end
    }
    child = candidate.next_sibling_index
  }
  assert_true(anchor > run_element.content_start)
  let mut licensed_anchor = false
  for span in simple_allowed {
    let (from, to, _) = span
    if anchor >= from && anchor <= to {
      licensed_anchor = true
    }
  }
  assert_false(
    licensed_anchor,
    msg="a text-projecting paragraph must license no run synthesis anchor",
  )
  // And the run's content end is never a synthesis location either.
  let mut licensed_end = false
  for span in simple_allowed {
    let (from, to, _) = span
    if run_element.content_end >= from &&
      run_element.content_end <= to &&
      from > run_element.content_start {
      licensed_end = true
    }
  }
  assert_false(licensed_end, msg="run content end is never a synthesis site")
}

///|
test "partial: a multi-edit batch across two runs plans" {
  // The general composition shape the property floors now require and
  // this test pins exactly: two edits, two carriers, two runs.
  assert_partial_edits(
    "<w:p><w:r><w:t>ab</w:t></w:r><w:r><w:t>cd</w:t></w:r></w:p>",
    paragraph=0,
    [partial_edit(0, 2, "head"), partial_edit(2, 4, "")],
    expected="head",
  )
  // And across two hosts inside ONE run.
  assert_partial_edits(
    "<w:p><w:r><w:t>ab</w:t><w:t>cd</w:t></w:r></w:p>",
    paragraph=0,
    [partial_edit(0, 1, "A"), partial_edit(2, 3, "C")],
    expected="AbCd",
  )
}

///|
/// Every ordered (shape, start-kind, end-kind) key the lexical family
/// plans. The family enumerates EXHAUSTIVELY — every (i, j) range over
/// every fixture — so this is the permitted set over those bodies, not a
/// sample of it, and it is held as an identity set: a planner that starts
/// refusing any single pair fails with that pair's key.
let partial_expected_pairs : Array[String] = [
  "insert:bare>bare", "delete:raw-edge>raw-edge", "insert:raw-edge>raw-edge", "replace:raw-edge>raw-edge",
  "insert:seam-edge>seam-edge", "delete:entity-edge>raw-edge", "delete:numref-edge>raw-edge",
  "delete:raw-edge>entity-edge", "delete:raw-edge>numref-edge", "delete:raw-edge>raw-interior",
  "delete:raw-interior>raw-edge", "replace:entity-edge>raw-edge", "replace:numref-edge>raw-edge",
  "replace:raw-edge>entity-edge", "replace:raw-edge>numref-edge", "delete:atom-end-edge>raw-edge",
  "delete:raw-edge>atom-end-edge", "replace:raw-edge>raw-interior", "replace:raw-interior>raw-edge",
  "delete:entity-edge>entity-edge", "delete:entity-edge>numref-edge", "delete:numref-edge>entity-edge",
  "delete:numref-edge>numref-edge", "insert:entity-edge>entity-edge", "insert:numref-edge>numref-edge",
  "replace:atom-end-edge>raw-edge", "replace:raw-edge>atom-end-edge", "delete:atom-start-edge>raw-edge",
  "delete:entity-edge>raw-interior", "delete:numref-edge>raw-interior", "delete:raw-edge>atom-start-edge",
  "delete:raw-interior>numref-edge", "replace:entity-edge>entity-edge", "replace:entity-edge>numref-edge",
  "replace:numref-edge>entity-edge", "replace:numref-edge>numref-edge", "delete:entity-edge>atom-end-edge",
  "delete:raw-interior>raw-interior", "insert:raw-interior>raw-interior", "replace:atom-start-edge>raw-edge",
  "replace:entity-edge>raw-interior", "replace:numref-edge>raw-interior", "replace:raw-edge>atom-start-edge",
  "replace:raw-interior>numref-edge", "delete:atom-end-edge>raw-interior", "delete:raw-interior>atom-end-edge",
  "replace:entity-edge>atom-end-edge", "replace:raw-interior>raw-interior", "delete:atom-start-edge>entity-edge",
  "delete:atom-start-edge>numref-edge", "delete:entity-edge>atom-start-edge", "delete:numref-edge>atom-start-edge",
  "replace:atom-end-edge>raw-interior", "replace:raw-interior>atom-end-edge", "delete:atom-start-edge>raw-interior",
  "delete:raw-interior>atom-start-edge", "replace:atom-start-edge>entity-edge", "replace:atom-start-edge>numref-edge",
  "replace:entity-edge>atom-start-edge", "replace:numref-edge>atom-start-edge", "delete:atom-start-edge>atom-end-edge",
  "replace:atom-start-edge>raw-interior", "replace:raw-interior>atom-start-edge",
  "replace:atom-start-edge>atom-end-edge", "delete:atom-start-edge>atom-start-edge",
  "replace:atom-start-edge>atom-start-edge",
]
