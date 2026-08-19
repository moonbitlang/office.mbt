// The shadow comparator (#434 PR 5c): the reader-native projection against
// the legacy byte-level walker on their shared valid domain. Text,
// structure, coordinates, and field annotations compare STRICTLY;
// zero-width boundary entries reconcile per source through a closed set of
// classified representation deltas -- anything outside the classes is a
// reported difference. The pinned divergences are asserted to DIVERGE, so
// a future change that silently closes one demands an allowlist update.

///|
/// One entry of either stream, viewed uniformly for the ordered match.
priv enum ShadowKind {
  ShadowText
  ShadowSeam
  ShadowBarrier
} derive(Debug, Eq)

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
fn shadow_element_is(
  elements : Array[ScannedElement],
  identity : Int,
  local_name : String,
) -> Bool {
  let element = elements[identity]
  is_wml_uri(element.uri) && element.local_name == local_name
}

///|
fn shadow_descends_from(
  elements : Array[ScannedElement],
  descendant : Int,
  ancestor : Int,
) -> Bool {
  let mut current = descendant
  while current >= 0 {
    if current == ancestor {
      return true
    }
    current = elements[current].parent_index
  }
  false
}

///|
/// Compares one adapted projection against one legacy projection. Strict
/// on everything consumers address: text streams (kind, value, source,
/// span, run pairing, run index, interval, field annotations incl.
/// refusals), paragraph sources with spans, paragraph intervals and
/// logical indices, run records (order, identity, span, index), the
/// carrier-event streams, and the full field indexes. Zero-width
/// boundary entries match IN ORDER per source and kind class, with a
/// CLOSED set of one-sided skips -- anything else is the first
/// difference returned.
fn compare_reader_projection_shadow(
  ours : ReaderProjection,
  legacy : ReaderOrderProjection,
) -> String? {
  let elements = ours.scan.elements()
  // the carrier-event streams, exactly
  let our_events : Array[String] = []
  for event in ours.field_carriers {
    our_events.push("\{event.paragraph_identity}/\{event.carrier_identity}")
  }
  let legacy_events : Array[String] = []
  for event in legacy.field_carriers {
    legacy_events.push("\{event.paragraph_identity}/\{event.carrier_identity}")
  }
  if our_events != legacy_events {
    return Some(
      "carrier events: ours [\{our_events.join(" ")}], legacy [\{legacy_events.join(" ")}]",
    )
  }
  // the full field indexes, exactly
  if describe_field_index(ours.field_index) !=
    describe_field_index(legacy.field_index) {
    return Some(
      "field index: ours <\{describe_field_index(ours.field_index)}>, legacy <\{describe_field_index(legacy.field_index)}>",
    )
  }
  if ours.paragraphs.length() != legacy.paragraphs.length() {
    return Some(
      "paragraph count: ours \{ours.paragraphs.length()}, legacy \{legacy.paragraphs.length()}",
    )
  }
  for index in 0..<ours.paragraphs.length() {
    let our_paragraph = ours.paragraphs[index]
    let legacy_paragraph = legacy.paragraphs[index]
    if our_paragraph.logical_index != legacy_paragraph.logical_index {
      return Some(
        "paragraph \{index} logical index: ours \{our_paragraph.logical_index}, legacy \{legacy_paragraph.logical_index}",
      )
    }
    // physical paragraph sources, with spans
    if our_paragraph.sources.length() != legacy_paragraph.sources.length() {
      return Some("paragraph \{index} source count differs")
    }
    for position in 0..<our_paragraph.sources.length() {
      let mine = our_paragraph.sources[position]
      let theirs = legacy_paragraph.sources[position]
      let SourceElementId(identity) = mine.source
      if identity != theirs.identity ||
        mine.source_span.byte_start != theirs.source_span.byte_start ||
        mine.source_span.byte_end != theirs.source_span.byte_end {
        return Some(
          "paragraph \{index} source \{position}: ours \{identity}, legacy \{theirs.identity}",
        )
      }
    }
    if our_paragraph.projection_start != legacy_paragraph.projection_start ||
      our_paragraph.projection_end != legacy_paragraph.projection_end {
      return Some(
        "paragraph \{index} interval: ours [\{our_paragraph.projection_start},\{our_paragraph.projection_end}), legacy [\{legacy_paragraph.projection_start},\{legacy_paragraph.projection_end})",
      )
    }
    // run records against the legacy source run lists: order, identity,
    // span. (Legacy nests run records under each paragraph source.)
    let legacy_runs : Array[ReaderOrderRunSource] = []
    for source in legacy_paragraph.sources {
      for run in source.runs {
        legacy_runs.push(run)
      }
    }
    if our_paragraph.runs.length() != legacy_runs.length() {
      let ours_list : Array[String] = []
      for run in our_paragraph.runs {
        let SourceElementId(identity) = run.source
        ours_list.push("\{identity}")
      }
      let legacy_list : Array[String] = []
      for run in legacy_runs {
        legacy_list.push("\{run.identity}")
      }
      return Some(
        "paragraph \{index} run records: ours [\{ours_list.join(",")}], legacy [\{legacy_list.join(",")}]",
      )
    }
    for position in 0..<our_paragraph.runs.length() {
      let mine = our_paragraph.runs[position]
      let theirs = legacy_runs[position]
      let SourceElementId(identity) = mine.source
      if identity != theirs.identity ||
        mine.logical_index != position ||
        mine.source_span.byte_start != theirs.source_span.byte_start ||
        mine.source_span.byte_end != theirs.source_span.byte_end {
        return Some(
          "paragraph \{index} run \{position}: ours \{identity}, legacy \{theirs.identity}",
        )
      }
    }
    match
      compare_shadow_streams(elements, our_paragraph, legacy_paragraph, index) {
      Some(difference) => return Some(difference)
      None => ()
    }
  }
  None
}

///|
/// Ordered two-pointer matching over one paragraph pair's FULL
/// contribution streams. Text entries must match exactly. Zero-width
/// entries match by source and kind class (seam~Transparent,
/// barrier~VisibleNonText|SuppressedContent, and the documented fldChar
/// class flip). The one-sided skips form a CLOSED set:
///
/// legacy-only:
///  - a run-open SEAM at a `w:r` that stands in our run records (runs
///    are first-class records, not seams);
///  - a SEAM at an MC `AlternateContent` wrapper (the join cooked it);
///  - a checkbox-BLANKED text atom (empty value) whose source carries our
///    Suppressed + VisibleNonText replacement pair, consumed together;
///  - an image BARRIER whose matching visible/suppressed effect sits on a
///    descendant (our effect names the blip, legacy the container) --
///    consumed one-for-one with that ours entry.
///
/// ours-only (each capped at one per source and kind):
///  - Transparent at metadata the legacy walk never visits (`sdtPr`,
///    `tblPr`, `tblGrid`, `trPr`, `tcPr`, `sectPr`) or at a `fldChar`
///    (the class flip's transparent half when legacy emitted nothing);
///  - Suppressed at rejected selections and retractions the legacy walk
///    rolls back or never enters (`sdt`, `sdtContent`, MC `Choice` or
///    `Fallback`, `tc`, `tr`, `p`, `del`, `instrText`, `txbxContent`).
fn compare_shadow_streams(
  elements : Array[ScannedElement],
  ours : ReaderProjectionParagraph,
  legacy : ReaderOrderParagraph,
  paragraph_index : Int,
) -> String? {
  let run_sources : Array[Int] = []
  for run in ours.runs {
    let SourceElementId(identity) = run.source
    run_sources.push(identity)
  }
  let mut i = 0
  let mut j = 0
  let ours_skip_seen : Map[String, Bool] = Map([])
  while i < legacy.contributions.length() || j < ours.contributions.length() {
    let legacy_head = if i < legacy.contributions.length() {
      Some(legacy.contributions[i])
    } else {
      None
    }
    let our_head = if j < ours.contributions.length() {
      Some(ours.contributions[j])
    } else {
      None
    }
    // text heads must pair exactly
    let legacy_is_text = match legacy_head {
      Some(contribution) =>
        match contribution.kind {
          TextAtom
          | TabAtom
          | NoBreakHyphenAtom
          | SoftHyphenAtom
          | SymbolAtom => true
          _ => false
        }
      None => false
    }
    let our_is_text = match our_head {
      Some(contribution) => contribution.kind is ProjectedText(_)
      None => false
    }
    if legacy_is_text && our_is_text {
      guard legacy_head is Some(theirs) && our_head is Some(mine) else {
        return Some("unreachable")
      }
      let SourceElementId(source_identity) = mine.source
      if !shadow_text_kind_matches(theirs.kind, mine.kind) ||
        mine.value != theirs.value ||
        source_identity != theirs.source_identity {
        return Some(
          "paragraph \{paragraph_index} text: ours \{mine.value}@\{source_identity}, legacy \{theirs.value}@\{theirs.source_identity}",
        )
      }
      if mine.source_span.byte_start != theirs.source_span.byte_start ||
        mine.source_span.byte_end != theirs.source_span.byte_end {
        return Some(
          "paragraph \{paragraph_index} text span at \{source_identity} differs",
        )
      }
      if mine.projection_start != theirs.projection_start ||
        mine.projection_end != theirs.projection_end {
        return Some(
          "paragraph \{paragraph_index} text interval at \{source_identity}: ours [\{mine.projection_start},\{mine.projection_end}), legacy [\{theirs.projection_start},\{theirs.projection_end})",
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
          "paragraph \{paragraph_index} text run at \{source_identity}: ours \{our_run}/r\{mine.logical_run_index}, legacy \{legacy_run}/r\{theirs.logical_run_index}",
        )
      }
      if mine.field_region != theirs.field_region ||
        mine.field_identity != theirs.field_identity ||
        mine.field_refusal != theirs.field_refusal {
        return Some(
          "paragraph \{paragraph_index} text field at \{source_identity} differs",
        )
      }
      i = i + 1
      j = j + 1
      continue
    }
    // legacy blanked checkbox text: consumed with our replacement pair.
    // The pair must be plausible as a REPLACEMENT: the source is a
    // replaceable text atom that originally projected something (an
    // empty w:t is never replaced), sitting under a control.
    if legacy_is_text {
      guard legacy_head is Some(theirs) else { return Some("unreachable") }
      if theirs.value == "" &&
        j + 1 < ours.contributions.length() &&
        ours.contributions[j].kind is SuppressedContent &&
        ours.contributions[j + 1].kind is VisibleNonText {
        let SourceElementId(first) = ours.contributions[j].source
        let SourceElementId(second) = ours.contributions[j + 1].source
        if first == theirs.source_identity && second == theirs.source_identity {
          let element = elements[theirs.source_identity]
          let replaceable = is_wml_uri(element.uri) &&
            (match element.local_name {
              "t" =>
                match element.text_map {
                  Some(mapped) => mapped.projection.length() > 0
                  None => false
                }
              "noBreakHyphen" | "softHyphen" | "sym" => true
              _ => false
            })
          let mut under_control = false
          let mut ancestor = element.parent_index
          while ancestor >= 0 {
            if shadow_element_is(elements, ancestor, "sdt") {
              under_control = true
              break
            }
            ancestor = elements[ancestor].parent_index
          }
          if replaceable && under_control {
            i = i + 1
            j = j + 2
            continue
          }
        }
      }
    }
    // zero-width vs zero-width: source + kind class, in order
    if !legacy_is_text && !our_is_text && legacy_head is Some(theirs) {
      match our_head {
        Some(mine) => {
          let SourceElementId(our_source) = mine.source
          let source_element = elements[theirs.source_identity]
          let class_matches = match (theirs.kind, mine.kind) {
            (TransparentSeam, Transparent) => true
            // a legacy barrier pairs with VISIBLE only where the reader
            // actually classifies the element as visible non-text
            (HardBarrier, VisibleNonText) =>
              (
                is_wml_uri(source_element.uri) &&
                (match source_element.local_name {
                  "br" | "cr" =>
                    match source_element.break_type {
                      None
                      | Some("textWrapping")
                      | Some("page")
                      | Some("column") => true
                      _ => false
                    }
                  "footnoteReference"
                  | "endnoteReference"
                  | "commentReference" => true
                  _ => false
                })
              ) ||
              !is_wml_uri(source_element.uri)
            // ... and with SUPPRESSED only where suppression is the
            // reader's real classification (a supported break flipped to
            // suppressed is a bug, not a delta)
            (HardBarrier, SuppressedContent) =>
              (
                is_wml_uri(source_element.uri) &&
                (match source_element.local_name {
                  "pict"
                  | "del"
                  | "instrText"
                  | "txbxContent"
                  | "footnoteRef"
                  | "endnoteRef"
                  | "sym" => true
                  "br" | "cr" =>
                    match source_element.break_type {
                      None
                      | Some("textWrapping")
                      | Some("page")
                      | Some("column") => false
                      _ => true
                    }
                  _ => false
                })
              ) ||
              !is_wml_uri(source_element.uri)
            // the documented class flip: legacy models a field marker as
            // a barrier, ours as a transparent marker
            (HardBarrier, Transparent) =>
              shadow_element_is(elements, theirs.source_identity, "fldChar")
            _ => false
          }
          if class_matches && our_source == theirs.source_identity {
            // positions and metadata of paired zero-width entries compare
            // strictly too
            if mine.projection_start != theirs.projection_start ||
              mine.projection_end != theirs.projection_end {
              return Some(
                "paragraph \{paragraph_index} boundary interval at \{our_source} differs",
              )
            }
            if mine.source_span.byte_start != theirs.source_span.byte_start ||
              mine.source_span.byte_end != theirs.source_span.byte_end {
              return Some(
                "paragraph \{paragraph_index} boundary span at \{our_source} differs",
              )
            }
            // a matched boundary consumes the surplus cap at its source
            // and kind, so a duplicated effect cannot ride behind it
            let kind_label = match mine.kind {
              Transparent => "b"
              VisibleNonText => "v"
              SuppressedContent => "s"
              ProjectedText(_) => "t"
            }
            ours_skip_seen["\{our_source}:\{kind_label}"] = true
            i = i + 1
            j = j + 1
            continue
          }
          // image barrier on the container, our effect on a descendant
          if theirs.kind is HardBarrier &&
            (mine.kind is VisibleNonText || mine.kind is SuppressedContent) &&
            shadow_descends_from(elements, our_source, theirs.source_identity) {
            i = i + 1
            j = j + 1
            continue
          }
        }
        None => ()
      }
    }
    // legacy-only skips
    if legacy_head is Some(theirs) && !legacy_is_text {
      let mut skip = false
      match theirs.kind {
        TransparentSeam => {
          if shadow_element_is(elements, theirs.source_identity, "r") {
            for identity in run_sources {
              if identity == theirs.source_identity {
                skip = true
                break
              }
            }
          }
          let element = elements[theirs.source_identity]
          if element.uri == MC_URI && element.local_name == "AlternateContent" {
            skip = true
          }
        }
        _ => ()
      }
      if skip {
        i = i + 1
        continue
      }
    }
    // ours-only skips, capped at one per source and kind
    if our_head is Some(mine) && !our_is_text {
      let SourceElementId(our_source) = mine.source
      let element = elements[our_source]
      let allowed = match mine.kind {
        Transparent =>
          // foreign-namespace metadata markers the reader classifies as
          // boundaries (v:shadow, v:shapetype, office-word:wrap ...):
          // legacy contributes nothing for them outside paragraphs
          (!is_wml_uri(element.uri) && element.uri != MC_URI) ||
          (
            is_wml_uri(element.uri) &&
            element.local_name
            is ("sdt"
            | "sdtPr"
            | "tblPr"
            | "tblGrid"
            | "trPr"
            | "tcPr"
            | "sectPr"
            | "fldChar"
            | "bookmarkStart"
            | "bookmarkEnd"
            | "commentRangeStart"
            | "commentRangeEnd"
            | "proofErr"
            | "lastRenderedPageBreak"
            | "annotationRef")
          )
        // a no-text control synthesizes its checkbox AT the control; the
        // legacy block site drops the construct wholesale, so the visible
        // checkbox is ours alone -- the known checkbox-family delta
        // synthesized checkboxes: a no-text control synthesizes AT the
        // control (sdt), and a FORMCHECKBOX complex field synthesizes a
        // run sourced at its begin-carrier run (r). Legacy models neither
        // as a contribution.
        VisibleNonText =>
          is_wml_uri(element.uri) && element.local_name is ("sdt" | "r")
        SuppressedContent =>
          // ours-only Suppressed is accepted broadly (capped once per
          // source): the effect stream records every rejection the legacy
          // walk never visits -- control and MC rejections, table
          // metadata, warned unknowns, retractions, drops. This is SOUND
          // because suppression of content that mattered would also drop
          // its text, and the text streams compare strictly; the
          // dangerous kinds (VisibleNonText, Transparent) stay tightly
          // classed above.
          true
        _ => false
      }
      if allowed {
        let kind_label = match mine.kind {
          Transparent => "b"
          VisibleNonText => "v"
          SuppressedContent => "s"
          ProjectedText(_) => "t"
        }
        let key = "\{our_source}:\{kind_label}"
        match ours_skip_seen.get(key) {
          Some(_) =>
            return Some(
              "paragraph \{paragraph_index}: duplicated ours-only boundary at source \{our_source}",
            )
          None => {
            ours_skip_seen[key] = true
            j = j + 1
            continue
          }
        }
      }
    }
    // nothing matched
    let legacy_at = match legacy_head {
      Some(theirs) => "\{theirs.source_identity}"
      None => "-"
    }
    let ours_at = match our_head {
      Some(mine) => {
        let SourceElementId(identity) = mine.source
        "\{identity}"
      }
      None => "-"
    }
    return Some(
      "paragraph \{paragraph_index}: unmatched boundary (legacy at \{legacy_at}, ours at \{ours_at})",
    )
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
      #|carrier events: ours [2/3 2/5], legacy [2/3 2/5 9/10]
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
      #|carrier events: ours [2/3 2/5 16/17], legacy [2/3 2/5]
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
      #|carrier events: ours [17/18], legacy []
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
      #|paragraph 0: unmatched boundary (legacy at 11, ours at 3)
    ),
  )
}

///|
/// The archived FOURTH divergence class, pinned end-to-end: flow-level
/// visible content after the final paragraph. The adapter refuses with a
/// typed UnownedVisibleContribution -- it will not invent an address --
/// while the legacy walker models the content into a projection anyway.
/// PR 6 turns this refusal into an N0c1 mutation refusal.
test "pinned divergence: unowned flow content refuses where legacy projects" {
  let source =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:t>owned</w:t></w:r></w:p><w:r><w:t>tail</w:t></w:r></w:body></w:document>
  guard join_text_story(source) is Joined(story) else {
    fail("expected the story to join")
  }
  guard story.root.first("w:body") is Some(body) else {
    fail("expected a body")
  }
  let items = empty_body_reader({ relationships: [] }).read_children(
    body.element_children(),
  )
  guard project_reader_items("word/document.xml", story.scan, items)
    is ProjectionRefused(UnownedVisibleContribution(..) as refusal) else {
    fail("expected the unowned-content refusal")
  }
  inspect(
    refusal.describe(),
    content="visible content at source element 6 is owned by no paragraph",
  )
  // the legacy walker happily projects the same story
  let legacy = field_test_projection(source)
  inspect(legacy.paragraphs.length(), content="1")
}
