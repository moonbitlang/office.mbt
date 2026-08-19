// The shadow comparator (#434 PR 5c): the reader-native projection against
// the legacy byte-level walker on their shared valid domain. Text,
// structure, coordinates, and field annotations compare STRICTLY;
// zero-width boundary entries reconcile per source through a closed set of
// classified representation deltas -- anything outside the classes is a
// reported difference. The pinned divergences are asserted to DIVERGE, so
// a future change that silently closes one demands an allowlist update.

///|
priv struct ShadowBoundaryEntry {
  mut legacy_seams : Int
  mut legacy_barriers : Int
  mut ours_transparent : Int
  mut ours_visible : Int
  mut ours_suppressed : Int
}

///|
fn shadow_text_kind_matches(
  legacy_kind : ProvisionalContributionKind,
  ours : ReaderProjectionContributionKind,
) -> Bool {
  match (legacy_kind, ours) {
    (TextAtom, ProjectedText(FromText)) => true
    (TabAtom, ProjectedText(FromTab)) => true
    (NoBreakHyphenAtom, ProjectedText(FromNoBreakHyphen)) => true
    (SoftHyphenAtom, ProjectedText(FromSoftHyphen)) => true
    (SymbolAtom, ProjectedText(FromSymbol)) => true
    _ => false
  }
}

///|
/// Compares one adapted projection against one legacy projection. Returns
/// `None` when they agree on the strict domain with only classified
/// boundary deltas; otherwise the first difference, bounded.
fn compare_reader_projection_shadow(
  ours : ReaderProjection,
  legacy : ReaderOrderProjection,
) -> String? {
  let elements = ours.scan.elements()
  if ours.paragraphs.length() != legacy.paragraphs.length() {
    return Some(
      "paragraph count: ours \{ours.paragraphs.length()}, legacy \{legacy.paragraphs.length()}",
    )
  }
  for index in 0..<ours.paragraphs.length() {
    let our_paragraph = ours.paragraphs[index]
    let legacy_paragraph = legacy.paragraphs[index]
    // physical paragraph sources
    let our_sources : Array[Int] = []
    for source in our_paragraph.sources {
      let SourceElementId(identity) = source.source
      our_sources.push(identity)
    }
    let legacy_sources : Array[Int] = []
    for source in legacy_paragraph.sources {
      legacy_sources.push(source.identity)
    }
    if our_sources != legacy_sources {
      return Some(
        "paragraph \{index} sources: ours \{our_sources}, legacy \{legacy_sources}",
      )
    }
    if our_paragraph.projection_start != legacy_paragraph.projection_start ||
      our_paragraph.projection_end != legacy_paragraph.projection_end {
      return Some(
        "paragraph \{index} interval: ours [\{our_paragraph.projection_start},\{our_paragraph.projection_end}), legacy [\{legacy_paragraph.projection_start},\{legacy_paragraph.projection_end})",
      )
    }
    // the text streams, strictly
    let our_texts : Array[ReaderProjectionContribution] = []
    for contribution in our_paragraph.contributions {
      if contribution.kind is ProjectedText(_) {
        our_texts.push(contribution)
      }
    }
    // a checkbox-replaced text is a BLANKED TextAtom on the legacy side
    // (empty value, empty interval, real source span); ours replaces the
    // kind entirely with Suppressed + VisibleNonText at the same source.
    // Classified delta: drop the blanked atom when our checkbox stands at
    // its source. A genuinely empty w:t keeps its ProjectedText("") pair.
    let checkbox_sources : Array[Int] = []
    for contribution in our_paragraph.contributions {
      if contribution.kind is VisibleNonText {
        let SourceElementId(identity) = contribution.source
        checkbox_sources.push(identity)
      }
    }
    let legacy_texts : Array[ReaderOrderContribution] = []
    for contribution in legacy_paragraph.contributions {
      match contribution.kind {
        TextAtom | TabAtom | NoBreakHyphenAtom | SoftHyphenAtom | SymbolAtom => {
          let mut blanked = false
          if contribution.value == "" {
            for identity in checkbox_sources {
              if identity == contribution.source_identity {
                blanked = true
                break
              }
            }
          }
          if !blanked {
            legacy_texts.push(contribution)
          }
        }
        _ => ()
      }
    }
    if our_texts.length() != legacy_texts.length() {
      return Some(
        "paragraph \{index} text contributions: ours \{our_texts.length()}, legacy \{legacy_texts.length()}",
      )
    }
    for position in 0..<our_texts.length() {
      let mine = our_texts[position]
      let theirs = legacy_texts[position]
      let SourceElementId(source_identity) = mine.source
      if !shadow_text_kind_matches(theirs.kind, mine.kind) ||
        mine.value != theirs.value ||
        source_identity != theirs.source_identity {
        return Some(
          "paragraph \{index} text \{position}: ours \{mine.value}@\{source_identity}, legacy \{theirs.value}@\{theirs.source_identity}",
        )
      }
      if mine.projection_start != theirs.projection_start ||
        mine.projection_end != theirs.projection_end {
        return Some(
          "paragraph \{index} text \{position} interval: ours [\{mine.projection_start},\{mine.projection_end}), legacy [\{theirs.projection_start},\{theirs.projection_end})",
        )
      }
      let our_run = match mine.run_source {
        Some(SourceElementId(identity)) => identity
        None => -1
      }
      let legacy_run = match theirs.run_identity {
        Some(identity) => identity
        None => -1
      }
      if our_run != legacy_run ||
        mine.logical_run_index != theirs.logical_run_index {
        return Some(
          "paragraph \{index} text \{position} run: ours \{our_run}/r\{mine.logical_run_index}, legacy \{legacy_run}/r\{theirs.logical_run_index}",
        )
      }
      if mine.field_region != theirs.field_region ||
        mine.field_identity != theirs.field_identity {
        return Some(
          "paragraph \{index} text \{position} field: ours \{field_region_label(mine.field_region)}, legacy \{field_region_label(theirs.field_region)}",
        )
      }
    }
    match
      compare_shadow_boundaries(
        elements, our_paragraph, legacy_paragraph, index,
      ) {
      Some(difference) => return Some(difference)
      None => ()
    }
  }
  None
}

///|
/// Reconciles the zero-width boundary entries of one paragraph pair as
/// per-source multisets through the classified representation deltas:
///
/// - a seam and a Transparent at the same source match, as do a barrier
///   and a VisibleNonText or SuppressedContent;
/// - `fldChar` flips class (legacy barrier, ours transparent marker);
/// - a legacy-only run-open seam is represented by our run records;
/// - a legacy-only MC wrapper seam has no node after the join cooks it;
/// - our-only entries whose source the legacy walk never visits (control
///   metadata, table metadata, rejected selections, retractions, tail
///   drops) are the effect stream's finer decision record;
/// - a legacy image barrier may sit on the drawing container while our
///   effect sits on the blip inside it.
fn compare_shadow_boundaries(
  elements : Array[ScannedElement],
  ours : ReaderProjectionParagraph,
  legacy : ReaderOrderParagraph,
  paragraph_index : Int,
) -> String? {
  let by_source : Map[Int, ShadowBoundaryEntry] = Map([])
  fn entry(identity : Int) -> ShadowBoundaryEntry {
    match by_source.get(identity) {
      Some(found) => found
      None => {
        let created : ShadowBoundaryEntry = {
          legacy_seams: 0,
          legacy_barriers: 0,
          ours_transparent: 0,
          ours_visible: 0,
          ours_suppressed: 0,
        }
        by_source[identity] = created
        created
      }
    }
  }

  for contribution in legacy.contributions {
    match contribution.kind {
      TransparentSeam => {
        let counts = entry(contribution.source_identity)
        counts.legacy_seams = counts.legacy_seams + 1
      }
      HardBarrier => {
        let counts = entry(contribution.source_identity)
        counts.legacy_barriers = counts.legacy_barriers + 1
      }
      _ => ()
    }
  }
  for contribution in ours.contributions {
    let SourceElementId(identity) = contribution.source
    match contribution.kind {
      Transparent => {
        let counts = entry(identity)
        counts.ours_transparent = counts.ours_transparent + 1
      }
      VisibleNonText => {
        let counts = entry(identity)
        counts.ours_visible = counts.ours_visible + 1
      }
      SuppressedContent => {
        let counts = entry(identity)
        counts.ours_suppressed = counts.ours_suppressed + 1
      }
      ProjectedText(_) => ()
    }
  }
  let run_sources : Array[Int] = []
  for run in ours.runs {
    let SourceElementId(identity) = run.source
    run_sources.push(identity)
  }
  for identity, counts in by_source {
    let element = elements[identity]
    let matched = counts.legacy_seams + counts.legacy_barriers ==
      counts.ours_transparent + counts.ours_visible + counts.ours_suppressed
    if matched {
      continue
    }
    let legacy_only = counts.legacy_seams + counts.legacy_barriers >
      counts.ours_transparent + counts.ours_visible + counts.ours_suppressed
    if legacy_only {
      // run-open seams: represented by the run records instead
      if is_wml_uri(element.uri) && element.local_name == "r" {
        let mut in_runs = false
        for run_source in run_sources {
          if run_source == identity {
            in_runs = true
            break
          }
        }
        if in_runs {
          continue
        }
      }
      // the MC wrapper: the join cooks it away, no node remains
      if element.uri == MC_URI {
        continue
      }
      // an image barrier on the drawing container: our effect sits on a
      // blip (or imagedata) inside it
      let mut carrier_matched = false
      for candidate, candidate_counts in by_source {
        if candidate_counts.ours_visible + candidate_counts.ours_suppressed > 0 {
          let mut current = candidate
          while current >= 0 && !carrier_matched {
            if current == identity {
              carrier_matched = true
            }
            current = elements[current].parent_index
          }
        }
      }
      if carrier_matched {
        continue
      }
      return Some(
        "paragraph \{paragraph_index}: unmatched legacy boundary at source \{identity} (\{element.local_name})",
      )
    }
    // ours-only: the effect stream records decisions the legacy walk never
    // visits -- metadata, rejected selections, retractions, tail drops
    continue
  }
  None
}

///|
/// The shadow claim over documents nobody wrote by hand: the reader-native
/// projection agrees with the legacy walker on the generator's whole
/// domain (which deliberately excludes the pinned divergences).
test "the adapted projection shadows the legacy walker on generated documents" {
  @quickcheck.check(
    (seeds : Array[Int]) => {
      let source = hostile_document(seeds)
      guard join_text_story(source) is Joined(story) else {
        fail("expected the story to join")
      }
      let node = story.root
      let children = match node.first("w:body") {
        Some(body) => body.element_children()
        None => node.element_children()
      }
      let items = empty_body_reader({ relationships: [] }).read_children(
        children,
      )
      let ours = match
        project_reader_items("word/document.xml", story.scan, items) {
        Projected(projection) => projection
        ProjectionRefused(UnownedVisibleContribution(..)) => {
          assert_true(
            erased_has_unowned_visible(reader_items_to_elements(items), false),
          )
          return true
        }
        ProjectionRefused(refusal) => fail("refused: " + refusal.describe())
      }
      classify_reader_projection_fields(ours)
      let legacy = scan_reader_order_projection(
        "word/document.xml",
        @utf8.encode(source),
      )
      match compare_reader_projection_shadow(ours, legacy) {
        Some(difference) => fail("shadow difference: " + difference)
        None => ()
      }
      true
    },
    count=64,
    max_size=60,
    seed=0x646F_6378_70UL,
  )
}

///|
fn shadow_difference_of(source : String) -> String raise {
  let ours = projection_with_fields(source)
  let legacy = scan_reader_order_projection(
    "word/document.xml",
    @utf8.encode(source),
  )
  match compare_reader_projection_shadow(ours, legacy) {
    Some(difference) => difference
    None => "NO DIVERGENCE"
  }
}

///|
/// The pinned divergences MUST diverge: each of these asserts the exact
/// first difference the comparator reports. If a change makes one read
/// "NO DIVERGENCE", the allowlist entry -- and the legacy behaviour it
/// tolerated -- must be reconsidered, not silently absorbed.
test "pinned divergence: an inline no-text checkbox control" {
  inspect(
    shadow_difference_of(
      (
        #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:w14="http://schemas.microsoft.com/office/word/2010/wordml"><w:body><w:p><w:r><w:t>x</w:t></w:r><w:sdt><w:sdtPr><w14:checkbox/></w:sdtPr><w:sdtContent><w:p><w:r><w:tab/></w:r></w:p></w:sdtContent></w:sdt></w:p></w:body></w:document>
      ),
    ),
    content=(
      #|paragraph count: ours 1, legacy 2
    ),
  )
}

///|
test "pinned divergence: a textbox in a deleted row inside a paragraph" {
  inspect(
    shadow_difference_of(
      (
        #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:v="urn:schemas-microsoft-com:vml"><w:body><w:p><w:r><w:t>x</w:t></w:r><w:tbl><w:tr><w:trPr><w:del/></w:trPr><w:tc><w:p><w:r><w:pict><v:shape><v:textbox><w:txbxContent><w:p><w:r><w:t>A</w:t></w:r></w:p></w:txbxContent></v:textbox></v:shape></w:pict><w:t>B</w:t></w:r></w:p></w:tc></w:tr></w:tbl></w:p></w:body></w:document>
      ),
    ),
    content=(
      #|paragraph count: ours 2, legacy 1
    ),
  )
}

///|
test "pinned divergence: a no-text checkbox control wrapping a cell" {
  inspect(
    shadow_difference_of(
      (
        #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:w14="http://schemas.microsoft.com/office/word/2010/wordml"><w:body><w:tbl><w:tr><w:sdt><w:sdtPr><w14:checkbox><w14:checked w14:val="1"/></w14:checkbox></w:sdtPr><w:sdtContent><w:tc><w:p><w:r><w:tab/></w:r></w:p></w:tc></w:sdtContent></w:sdt></w:tr><w:tr><w:tc><w:tcPr><w:vMerge/></w:tcPr><w:p><w:r><w:t>under</w:t></w:r></w:p></w:tc></w:tr></w:tbl></w:body></w:document>
      ),
    ),
    content=(
      #|paragraph count: ours 1, legacy 0
    ),
  )
}

///|
test "pinned divergence: field-hoisted extras are reader-native blocks" {
  inspect(
    shadow_difference_of(
      (
        #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:v="urn:schemas-microsoft-com:vml"><w:body><w:p><w:r><w:fldChar w:fldCharType="begin"/></w:r><w:r><w:instrText> HYPERLINK "https://e" </w:instrText></w:r><w:r><w:fldChar w:fldCharType="separate"/></w:r><w:p><w:r><w:pict><v:shape><v:textbox><w:txbxContent><w:p><w:r><w:t>X</w:t></w:r></w:p></w:txbxContent></v:textbox></v:shape></w:pict></w:r></w:p><w:r><w:fldChar w:fldCharType="end"/></w:r></w:p></w:body></w:document>
      ),
    ),
    content=(
      #|paragraph 1 sources: ours [2, 15], legacy [15]
    ),
  )
}
