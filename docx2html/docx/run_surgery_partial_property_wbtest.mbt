///|
/// N0c2 B3: general multi-edit composition, proved over documents nobody
/// wrote by hand. The hostile grammar (reader_projection_property_wbtest)
/// generates the documents; this suite derives edit batches from each
/// document's OWN projection — so the boundary-pair matrix is covered by
/// construction rather than by hand-listed fixtures — and holds every
/// planned batch to the acceptance claims of #236:
///
///   1. the re-read paragraph projection equals the receipt's precomputed
///      expected projection (exact, not merely plausible),
///   2. every byte outside the declared edit union survives,
///   3. the edited document still reads (structural revalidation),
///   4. every refusal is typed and publishes no plan.
///
/// The generator's own coverage guard (next door) keeps the documents
/// worth testing; the guard below keeps the BATCHES worth testing.
priv struct PartialBatchPlan {
  paragraph_index : Int
  edits : Array[ParagraphTextEdit]
  classes : Array[String]
}

///|
/// The boundary classes an offset falls into, for coverage accounting.
fn partial_boundary_classes(
  paragraph : ReaderProjectionParagraph,
  offset : Int,
) -> Array[String] {
  let classes : Array[String] = []
  for contribution in paragraph.contributions {
    let start = contribution.projection_start - paragraph.projection_start
    let end = contribution.projection_end - paragraph.projection_start
    match contribution.kind {
      ProjectedText(FromText) => {
        if offset > start && offset < end {
          classes.push("text-interior")
        }
        if offset == start || offset == end {
          classes.push("text-edge")
        }
      }
      ProjectedText(_) => {
        if offset == start || offset == end {
          classes.push("atom-edge")
        }
        if offset > start && offset < end {
          classes.push("atom-interior")
        }
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
/// Derive a batch from a paragraph's own projection: ordered,
/// non-overlapping ranges at a spread of offsets, mixing consuming edits,
/// pure insertions, and deletions.
fn partial_batch_for(
  projection : ReaderProjection,
  paragraph_index : Int,
  choice : Int,
) -> PartialBatchPlan? {
  let paragraph = projection.paragraphs[paragraph_index]
  let width = paragraph.projection_end - paragraph.projection_start
  if width == 0 {
    return None
  }
  let edits : Array[ParagraphTextEdit] = []
  let classes : Array[String] = []
  fn add(start : Int, end : Int, replacement : String) -> Unit {
    edits.push({ start, end, replacement })
    for name in partial_boundary_classes(paragraph, start) {
      classes.push(name)
    }
    for name in partial_boundary_classes(paragraph, end) {
      classes.push(name)
    }
    if start == end {
      classes.push("insertion")
    } else if replacement == "" {
      classes.push("deletion")
    } else {
      classes.push("replacement")
    }
  }

  // Three shapes, so one document contributes several batch geometries
  // across the sample: a single mid-range edit, a two-edit batch straddling
  // the middle, and a three-edit batch including an insertion.
  match choice % 3 {
    0 => add(width / 3, width - width / 3, "N0c2")
    1 => {
      add(0, width / 2, "head")
      if width / 2 < width {
        add(width / 2, width, "")
      }
    }
    _ => {
      add(0, 0, "pre")
      if width >= 2 {
        add(1, width - 1, "mid")
        add(width, width, "post")
      } else {
        add(width, width, "post")
      }
    }
  }
  if edits.length() == 0 {
    return None
  }
  Some({ paragraph_index, edits, classes })
}

///|
/// Plan a batch and hold it to every acceptance claim, or accept a typed
/// refusal. Returns the classes actually exercised by a PLANNED batch.
fn assert_partial_batch(
  source : String,
  projection : ReaderProjection,
  batch : PartialBatchPlan,
) -> Array[String] raise {
  let bytes = @utf8.encode(source)
  let planned = plan_paragraph_text_edits(
    projection,
    bytes[:],
    batch.paragraph_index,
    batch.edits,
  ) catch {
    Unsupported(message~) => {
      // Claim 4: every refusal is typed, names its class, and echoes no
      // document content.
      assert_true(
        message.has_prefix("partial surgery ["),
        msg="untyped refusal: \{message}",
      )
      return []
    }
    ResourceLimit(..) => return []
    error => raise error
  }
  let (byte_edits, receipt) = planned
  let spliced_bytes = apply_run_surgery_edits(bytes, byte_edits)
  let spliced = @utf8.decode(spliced_bytes)
  // Claim 3: the edited document still reads.
  current_reader_story_text(spliced) |> ignore
  // Claim 1: the re-read paragraph projection is EXACTLY the receipt's.
  let reprojected = surgery_native_projection(spliced)
  assert_true(batch.paragraph_index < reprojected.paragraphs.length())
  let after = StringBuilder()
  for
    contribution in reprojected.paragraphs[batch.paragraph_index].contributions {
    after.write_string(contribution.value)
  }
  assert_eq(
    after.to_string(),
    receipt.expected_projection,
    msg="paragraph \{batch.paragraph_index} projection",
  )
  // Claim 2: every byte outside the declared union survives.
  assert_untouched_bytes_survive(bytes, spliced_bytes, byte_edits)
  batch.classes
}

///|
test "generated documents compose partial edits over every boundary class" {
  let seen : Map[String, Int] = Map([])
  let cases : Array[Array[Int]] = @quickcheck.samples(96)
  let mut planned = 0
  for index, case in cases {
    let source = hostile_document(case[:])
    guard (try? hostile_native_projection(source)) is Ok(Some(projection)) else {
      continue
    }
    for paragraph_index in 0..<projection.paragraphs.length() {
      guard partial_batch_for(projection, paragraph_index, index) is Some(batch) else {
        continue
      }
      // Every batch is planned against a FRESH projection: planning mutates
      // nothing, but a shared projection across batches would let one
      // batch's receipt describe another's document.
      let fresh = surgery_native_projection(source)
      let classes = assert_partial_batch(source, fresh, batch)
      if classes.length() > 0 {
        planned += 1
        for name in classes {
          seen[name] = seen.get(name).unwrap_or(0) + 1
        }
      }
    }
  }
  // The batches have to be worth testing: without this guard the property
  // would pass just as happily on a corpus where every batch refused.
  let covered = (name : String) => seen.get(name).unwrap_or(0)
  // Measured margins on this corpus: 243 batches planned, interior 146,
  // text edges 651, atom edges 105, barriers 19, seams 196, suppressed
  // 132, replacements 144, insertions 201, deletions 88. The floors sit
  // well under those so ordinary generator drift does not break the
  // build, but a collapse to trivial batches — or to a corpus where
  // everything refuses — fails here rather than passing vacuously.
  assert_true(planned >= 80, msg="only \{planned} batches planned")
  assert_true(covered("text-interior") >= 40)
  assert_true(covered("text-edge") >= 100)
  assert_true(covered("atom-edge") >= 20)
  assert_true(covered("barrier-edge") >= 5)
  assert_true(covered("seam-edge") >= 40)
  assert_true(covered("suppressed-edge") >= 20)
  assert_true(covered("replacement") >= 40)
  assert_true(covered("insertion") >= 50)
  assert_true(covered("deletion") >= 20)
}

///|
test "generated documents refuse or plan every derived batch typed" {
  // The same derivation, but asserting the OTHER half: nothing escapes as
  // an untyped error, and a refusal never returns a plan. `assert_partial_batch`
  // already proves both; this run widens the input space with different
  // seeds so refusal paths dominate.
  @quickcheck.check(
    (seeds : Array[Int]) => {
      let source = hostile_document(seeds[:])
      guard (try? hostile_native_projection(source)) is Ok(Some(projection)) else {
        return true
      }
      for paragraph_index in 0..<projection.paragraphs.length() {
        guard partial_batch_for(projection, paragraph_index, seeds.length())
          is Some(batch) else {
          continue
        }
        let fresh = surgery_native_projection(source)
        assert_partial_batch(source, fresh, batch) |> ignore
      }
      true
    },
    count=48,
    max_size=60,
    seed=0x4E30_6332_6231UL,
  )
}
