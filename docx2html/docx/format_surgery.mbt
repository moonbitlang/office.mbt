///|
/// F1 span-batch formatting surgery: paragraph-local UTF-16 spans resolve
/// through the reader projection and the token map to physical runs, and
/// each touched run takes the SMALLEST honest mutation — an in-place
/// minimal `rPr` edit when the spans cover all of its projecting text, a
/// lexical clone-split (unchanged head, formatted middle, unchanged tail)
/// when a boundary falls inside it, and NOTHING when the requested
/// properties already hold (a partial span inside an already-correct run
/// stays unsplit). Clones are assembled from source byte slices, so run
/// attributes, `rPr` children, entity spellings, and rsids survive
/// byte-identical; only a fragment's `xml:space` may be added or upgraded
/// to `preserve`, never removed.
///
/// The refusal vocabulary below is the stable formatting taxonomy,
/// mirroring N0c2's phase discipline: every phase runs to completion over
/// the whole batch before the next begins, so a later span's earlier-phase
/// defect always beats an earlier span's later-phase defect.
#warnings("-struct_never_constructed")
priv struct ParagraphFormatSpan {
  start : Int
  end : Int
}

///|
/// Stable refusal classes for formatting surgery. One renderer produces
/// the user-facing message so every class keeps a stable reason, and no
/// class ever echoes document content.
///
/// `FormatBudgetExceeded` is declared for taxonomy stability before any
/// budget constructs it, the same arrangement N0c2 records for its own
/// budget class.
#warnings("-unused_constructor")
priv enum FormatSurgeryRefusal {
  FormatInvalidParagraph
  FormatInvalidRange
  EmptyFormatSpan
  UnorderedFormatSpans
  FormatSpanOverlap
  FormatMultiPhysicalParagraph
  FormatNonScalarBoundary
  FormatCDataContext
  FormatVisibleBarrier
  FormatSuppressedRegion
  FormatRestrictedRegion
  ProjectedAtom
  FormatFieldInstruction
  FormatMalformedField
  FormatRefusedField
  FormatCheckboxControl
  FormatDuplicateSource
  FormatCrossParagraphSourceReuse
  FormatUnsupportedTextSource
  UnsplittableRun
  UnsupportedNamespaceBinding
  FormatDuplicateRpr
  FormatDuplicateProperty
  FormatRprChange
  AmbiguousRprOrder
  UnsupportedRpr
  FormatBudgetExceeded
  FormatInternalPlanConflict
} derive(Debug)

///|
fn format_surgery_refusal_reason(kind : FormatSurgeryRefusal) -> String {
  match kind {
    FormatInvalidParagraph => "the addressed paragraph does not exist"
    FormatInvalidRange => "a span is outside the paragraph projection"
    EmptyFormatSpan => "a formatting span must select at least one unit"
    UnorderedFormatSpans => "spans must be ordered by ascending start offset"
    FormatSpanOverlap => "spans overlap in projection coordinates"
    FormatMultiPhysicalParagraph =>
      "the logical paragraph joins multiple physical paragraphs"
    FormatNonScalarBoundary =>
      "a span endpoint does not fall on a scalar source boundary"
    FormatCDataContext => "the addressed text draws from a CDATA section"
    FormatVisibleBarrier => "the span crosses visible non-text content"
    FormatSuppressedRegion => "the span crosses suppressed content"
    FormatRestrictedRegion => "the span touches a restricted region"
    ProjectedAtom =>
      "the span selects a projected atom (tab, symbol, or hyphen) v1 does not format"
    FormatFieldInstruction =>
      "the addressed text carries field instruction machinery"
    FormatMalformedField => "the addressed text sits in a malformed field"
    FormatRefusedField =>
      "the addressed text sits in a field the classifier refused"
    FormatCheckboxControl =>
      "the addressed text sits inside a checkbox content control"
    FormatDuplicateSource => "the addressed element is projected more than once"
    FormatCrossParagraphSourceReuse =>
      "the addressed run also contributes to another paragraph"
    FormatUnsupportedTextSource =>
      "the addressed content is not a mapped ordinary text element"
    UnsplittableRun =>
      "the run cannot be split: it carries content other than run properties and mapped text"
    UnsupportedNamespaceBinding =>
      "the run's namespace binding is not one this planner can vouch for"
    FormatDuplicateRpr => "the run declares duplicate rPr elements"
    FormatDuplicateProperty => "the rPr declares a targeted property twice"
    FormatRprChange => "the run carries an in-flight tracked property change"
    AmbiguousRprOrder => "the rPr has no unique legal insertion point"
    UnsupportedRpr => "the rPr carries a shape this planner refuses to edit"
    FormatBudgetExceeded => "formatting surgery exceeded its planning budget"
    FormatInternalPlanConflict => "internal formatting-surgery plan conflict"
  }
}

///|
/// The stable PUBLIC slug for a refusal class, construct-matched beside
/// the taxonomy so no reader holds a second drifting copy.
fn format_surgery_refusal_slug(kind : FormatSurgeryRefusal) -> String {
  match kind {
    FormatInvalidParagraph => "invalid-paragraph"
    FormatInvalidRange => "invalid-range"
    EmptyFormatSpan => "empty-range"
    UnorderedFormatSpans => "unordered-spans"
    FormatSpanOverlap => "span-overlap"
    FormatMultiPhysicalParagraph => "multi-physical-paragraph"
    FormatNonScalarBoundary => "non-scalar-boundary"
    FormatCDataContext => "cdata"
    FormatVisibleBarrier => "visible-barrier"
    FormatSuppressedRegion => "suppressed-region"
    FormatRestrictedRegion => "restricted-region"
    ProjectedAtom => "projected-atom"
    FormatFieldInstruction => "field-instruction"
    FormatMalformedField => "malformed-field"
    FormatRefusedField => "refused-field"
    FormatCheckboxControl => "checkbox-control"
    FormatDuplicateSource => "duplicate-source"
    FormatCrossParagraphSourceReuse => "cross-paragraph-reuse"
    FormatUnsupportedTextSource => "unsupported-source"
    UnsplittableRun => "unsplittable-run"
    UnsupportedNamespaceBinding => "unsupported-namespace"
    FormatDuplicateRpr => "duplicate-rpr"
    FormatDuplicateProperty => "duplicate-property"
    FormatRprChange => "rpr-change"
    AmbiguousRprOrder => "ambiguous-rpr-order"
    UnsupportedRpr => "unsupported-rpr"
    FormatBudgetExceeded => "budget-exceeded"
    FormatInternalPlanConflict => "internal"
  }
}

///|
fn format_surgery_refuse(
  kind : FormatSurgeryRefusal,
  context : String,
) -> DocxError {
  Unsupported(
    message="formatting surgery [\{@debug.Repr(kind)}]: \{format_surgery_refusal_reason(kind)} (\{context}) <reason:\{format_surgery_refusal_slug(kind)}>",
  )
}

///|
/// Map the F0 rPr engine's refusal onto the formatting taxonomy. The
/// engine's messages are this package's own stable strings — matching them
/// here is the same arrangement `mapped_plan_failure` uses for splice
/// messages, and the fallback class is honest about what it is. The
/// engine message is NOT echoed into the rendered refusal: it can carry
/// source QNames, and this taxonomy promises to never echo document
/// content.
fn format_surgery_map_rpr_refusal(
  message : String,
  context : String,
) -> DocxError {
  let kind = if message.contains("duplicate rPr") {
    FormatDuplicateRpr
  } else if message.contains("duplicate") && message.contains("properties") {
    FormatDuplicateProperty
  } else if message.contains("rPrChange") {
    FormatRprChange
  } else if message.contains("out of schema order") ||
    message.contains("after the trailing extension block") {
    AmbiguousRprOrder
  } else {
    UnsupportedRpr
  }
  format_surgery_refuse(kind, context)
}

///|
/// How one touched run was realized.
#warnings("-unused_constructor")
priv enum FormatRunAction {
  FormattedInPlace
  SplitIntoSegments(Int)
  AlreadySatisfied
} derive(Debug)

///|
#warnings("-unused_field")
priv struct FormatRunOutcome {
  run_identity : Int
  fully_covered : Bool
  action : FormatRunAction
}

///|
/// The aggregate receipt for one planned batch. Formatting never changes
/// the projection, so `expected_projection` is the paragraph's projection
/// UNCHANGED — the exact string the oracle holds the re-read document to.
#warnings("-unused_field")
priv struct FormatSurgeryReceipt {
  paragraph_index : Int
  expected_projection : String
  outcomes : Array[FormatRunOutcome]
  runs_changed : Int
  runs_already_satisfied : Int
  splits : Int
}

///|
/// The namespace URIs of the rPr extension vocabularies this planner will
/// vouch for when their prefixes appear as trailing extension content.
/// Anything else is simply not vouched, and the rPr engine refuses it.
fn format_extension_uri(uri : String) -> Bool {
  uri == "http://schemas.microsoft.com/office/word/2010/wordml" ||
  uri == "http://schemas.microsoft.com/office/word/2012/wordml" ||
  uri == "http://schemas.microsoft.com/office/word/2015/wordml/symex" ||
  uri == "http://schemas.microsoft.com/office/word/2016/wordml/cid" ||
  uri == "http://schemas.microsoft.com/office/word/2018/wordml" ||
  uri == "http://schemas.microsoft.com/office/word/2018/wordml/cex" ||
  uri == "http://schemas.microsoft.com/office/word/2020/wordml/sdtdatahash"
}

///|
/// The prefix an element is SPELLED with, from its own open tag — "" when
/// it carries no colon.
fn format_surgery_element_prefix(
  source : BytesView,
  element : ScannedElement,
) -> String {
  let mut at = element.byte_start + 1
  let name_start = at
  let stop = run_surgery_open_tag_end(element)
  while at < stop &&
        source[at] != b'>' &&
        source[at] != b'/' &&
        source[at] != b' ' &&
        source[at] != b'\t' &&
        source[at] != b'\n' &&
        source[at] != b'\r' {
    if source[at] == b':' {
      let builder = StringBuilder()
      for index in name_start..<at {
        if source[index] < b'\x80' {
          builder.write_char(source[index].to_int().unsafe_to_char())
        }
      }
      return builder.to_string()
    }
    at += 1
  }
  ""
}

///|
/// Whether this element IS a checkbox content control. The shared
/// ancestry detector walks strict ancestors, but a checkbox sdt's own
/// glyph contributions carry the sdt itself as their source — the
/// self-inclusive case an enclosure walk must also recognize.
fn format_surgery_is_checkbox_sdt(
  elements : Array[ScannedElement],
  element : ScannedElement,
) -> Bool {
  if !(is_wml_uri(element.uri) && element.local_name == "sdt") {
    return false
  }
  let mut child = element.first_child_index
  while child >= 0 {
    let properties = elements[child]
    if is_wml_uri(properties.uri) && properties.local_name == "sdtPr" {
      let mut declared = properties.first_child_index
      while declared >= 0 {
        let marker = elements[declared]
        if is_w14_uri(marker.uri) && marker.local_name == "checkbox" {
          return true
        }
        declared = marker.next_sibling_index
      }
      return false
    }
    child = properties.next_sibling_index
  }
  false
}

///|
/// Whether an element's open tag carries an identity-bearing attribute
/// (local name `id` under any prefix — `xml:id`, `w:id`, bare `id`).
/// Cloning such an element would duplicate the identity and violate
/// XML ID uniqueness, so a split refuses instead.
fn format_surgery_open_tag_has_identity_attribute(
  source : BytesView,
  element : ScannedElement,
) -> Bool {
  let stop = run_surgery_open_tag_end(element)
  let mut at = element.byte_start + 1
  // Skip the element name.
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
    // Attribute name.
    let name_start = at
    while at < stop && source[at] != b'=' && !is_xml_ws(source[at]) {
      at += 1
    }
    let builder = StringBuilder()
    for index in name_start..<at {
      if source[index] < b'\x80' {
        builder.write_char(source[index].to_int().unsafe_to_char())
      }
    }
    let (_, attribute_local) = split_qname(builder.to_string())
    if attribute_local == "id" {
      return true
    }
    // Skip to and over the quoted value.
    while at < stop && source[at] != b'"' && source[at] != b'\'' {
      at += 1
    }
    if at >= stop {
      break
    }
    let quote = source[at]
    at += 1
    while at < stop && source[at] != quote {
      at += 1
    }
    at += 1
  }
  false
}

///|
/// The transparent seams a run may own that provably render nothing, so
/// a run-wide formatting edit cannot change how they appear. The list is
/// an ALLOWLIST on purpose: an unrecognized transparent construct — or
/// one the reader ignores for projection but Word still paints, as with
/// `w:annotationRef` — must refuse rather than be formatted silently.
fn format_surgery_invisible_seam(element : ScannedElement) -> Bool {
  if !is_wml_uri(element.uri) {
    return false
  }
  if element.local_name == "rPr" {
    // Run properties hold formatting, not content. For a run this
    // batch touches the rPr engine proves that; for one it does not
    // touch, the interstitial pass below proves it.
    return true
  }
  // The markers below render nothing — but only as the LEAVES the
  // schema says they are. The reader does not walk into them, so a
  // child would be painted content nobody could see.
  if element.first_child_index >= 0 {
    return false
  }
  element.local_name
  is ("proofErr"
  | "bookmarkStart"
  | "bookmarkEnd"
  | "commentRangeStart"
  | "commentRangeEnd"
  | "lastRenderedPageBreak")
}

///|
/// The transparent WRAPPERS whose children the reader actually
/// traverses, so their descendants arrive as contributions of their own
/// and are judged on their own merits. Classification is by QNAME
/// because that is what the reader dispatches on: child presence proves
/// nothing (`w:annotationRef` is ignored WITH its children, and would
/// otherwise pass as a wrapper).
///
/// `w:drawing`, `w:object` and the VML shape family are deliberately
/// ABSENT: this codebase already calls them hard barriers, and a
/// drawable inside a formatted run is content no span selected.
fn format_surgery_transparent_wrapper(element : ScannedElement) -> Bool {
  if is_wml_uri(element.uri) {
    return element.local_name
      is ("ins" | "smartTag" | "sdt" | "sdtContent" | "hyperlink")
  }
  if element.uri ==
    "http://schemas.openxmlformats.org/markup-compatibility/2006" {
    return element.local_name is ("AlternateContent" | "Choice" | "Fallback")
  }
  false
}

///|
/// Whether a transparent contribution is ACCOUNTED FOR: either the
/// reader walks into it (a wrapper, whose contents speak for
/// themselves) or it provably renders nothing. Everything else may be
/// painted, and formatting around it would be a false receipt.
fn format_surgery_transparent_is_accounted(element : ScannedElement) -> Bool {
  // A drawable container is a hard barrier wherever it sits: the
  // codebase already says so, and a drawing inside a formatted run is
  // content no span selected.
  if run_surgery_is_hard_barrier_container(element) {
    return false
  }
  format_surgery_transparent_wrapper(element) ||
  format_surgery_invisible_seam(element)
}

///|
/// Whether an `rPr` subtree holds NOTHING but formatting: every child a
/// ranked CT_RPr property with no element content, or a recognized
/// extension whose subtree carries no WML. This mirrors the rPr
/// engine's own admission rules, for the runs the engine never sees.
fn format_surgery_rpr_is_formatting_only(
  elements : Array[ScannedElement],
  rpr : ScannedElement,
) -> Bool {
  let mut child = rpr.first_child_index
  while child >= 0 {
    let entry = elements[child]
    if is_wml_uri(entry.uri) {
      guard rpr_rank(entry.local_name) is Some(_) else { return false }
      if entry.first_child_index >= 0 {
        return false
      }
    } else if format_extension_uri(entry.uri) {
      if format_surgery_subtree_carries_wml(elements, entry) {
        return false
      }
    } else {
      return false
    }
    child = entry.next_sibling_index
  }
  true
}

///|
/// Whether any element in this subtree belongs to the WML vocabulary —
/// the shape an extension wrapper must not conceal.
fn format_surgery_subtree_carries_wml(
  elements : Array[ScannedElement],
  element : ScannedElement,
) -> Bool {
  let mut child = element.first_child_index
  while child >= 0 {
    let entry = elements[child]
    if is_wml_uri(entry.uri) {
      return true
    }
    if format_surgery_subtree_carries_wml(elements, entry) {
      return true
    }
    child = entry.next_sibling_index
  }
  false
}

///|
/// Whether an element OR ANY DESCENDANT carries an identity-bearing
/// attribute: the whole subtree is what a clone copies.
fn format_surgery_subtree_has_identity_attribute(
  source : BytesView,
  elements : Array[ScannedElement],
  element : ScannedElement,
) -> Bool {
  if format_surgery_open_tag_has_identity_attribute(source, element) {
    return true
  }
  let mut child = element.first_child_index
  while child >= 0 {
    let entry = elements[child]
    if format_surgery_subtree_has_identity_attribute(source, elements, entry) {
      return true
    }
    child = entry.next_sibling_index
  }
  false
}

///|
/// One projecting piece of a run's mapped text, in `w:t`-local UTF-16
/// coordinates, tagged with whether the batch covers it.
priv struct FormatPiece {
  wt_identity : Int
  local_from : Int
  local_to : Int
  covered : Bool
}

///|
/// Plan a batch of formatting spans inside one physical paragraph.
///
/// `requested` spans are paragraph-local UTF-16 projection coordinates,
/// non-empty, ordered, non-overlapping (abutting is legal). The returned
/// edits are absolute story-part byte offsets, non-overlapping, ascending.
/// Constructed only by the whitebox suites until the F2 transaction seam
/// lands, matching how N0c2's planner is staged.
#warnings("-unused_value")
fn plan_paragraph_format_edits(
  projection : ReaderProjection,
  source : BytesView,
  paragraph_index : Int,
  requested : Array[ParagraphFormatSpan],
  format : DocxDirectFormat,
) -> (Array[RunSurgeryEdit], FormatSurgeryReceipt) raise DocxError {
  // Phase 1a: every span is valid and non-empty.
  guard paragraph_index >= 0 && paragraph_index < projection.paragraphs.length() else {
    raise format_surgery_refuse(
      FormatInvalidParagraph,
      "paragraph \{paragraph_index}",
    )
  }
  let paragraph = projection.paragraphs[paragraph_index]
  let width = paragraph.projection_end - paragraph.projection_start
  for ordinal, span in requested {
    guard span.start >= 0 && span.start <= span.end && span.end <= width else {
      raise format_surgery_refuse(
        FormatInvalidRange,
        "span \{ordinal} in paragraph \{paragraph_index}",
      )
    }
  }
  for ordinal, span in requested {
    if span.start == span.end {
      raise format_surgery_refuse(
        EmptyFormatSpan,
        "span \{ordinal} in paragraph \{paragraph_index}",
      )
    }
  }
  // Phase 1b: ordered by ascending start.
  for ordinal, span in requested {
    if ordinal > 0 && span.start < requested[ordinal - 1].start {
      raise format_surgery_refuse(
        UnorderedFormatSpans,
        "span \{ordinal} in paragraph \{paragraph_index}",
      )
    }
  }
  // Phase 1c: non-overlapping (abutting is legal).
  for ordinal, span in requested {
    if ordinal > 0 && span.start < requested[ordinal - 1].end {
      raise format_surgery_refuse(
        FormatSpanOverlap,
        "span \{ordinal} in paragraph \{paragraph_index}",
      )
    }
  }
  // Phase 2: paragraph ownership — one physical source.
  guard paragraph.sources.length() == 1 else {
    raise format_surgery_refuse(
      FormatMultiPhysicalParagraph,
      "paragraph \{paragraph_index} has \{paragraph.sources.length()} physical sources",
    )
  }
  let elements = projection.scan.elements()
  // The ordered projecting contributions with paragraph-local spans, and
  // the projection they concatenate to (the receipt's UNCHANGED
  // expectation).
  let parts : Array[PartialProjectingPart] = []
  let before = StringBuilder()
  for contribution in paragraph.contributions {
    before.write_string(contribution.value)
    guard contribution.kind is ProjectedText(text_kind) else { continue }
    parts.push({
      contribution,
      local_start: contribution.projection_start - paragraph.projection_start,
      local_end: contribution.projection_end - paragraph.projection_start,
      is_text: text_kind is FromText,
    })
  }
  let before_projection = before.to_string()
  // Phase 3: structural restrictions, batch-wide.
  fn require_supported_run(
    run : ReaderProjectionRun,
    ordinal : Int,
  ) -> Unit raise DocxError {
    match run.field_region {
      FieldInstruction =>
        raise format_surgery_refuse(
          FormatFieldInstruction,
          "span \{ordinal} in paragraph \{paragraph_index}",
        )
      MalformedField =>
        raise format_surgery_refuse(
          FormatMalformedField,
          "span \{ordinal} in paragraph \{paragraph_index}",
        )
      _ => ()
    }
    if run.field_refusal is Some(_) {
      raise format_surgery_refuse(
        FormatRefusedField,
        "span \{ordinal} in paragraph \{paragraph_index}",
      )
    }
    if run.field_region is FieldResult {
      raise format_surgery_refuse(
        FormatRestrictedRegion,
        "span \{ordinal} in paragraph \{paragraph_index}",
      )
    }
  }

  fn require_supported_contribution(
    contribution : ReaderProjectionContribution,
    ordinal : Int,
  ) -> Unit raise DocxError {
    match contribution.field_region {
      FieldInstruction =>
        raise format_surgery_refuse(
          FormatFieldInstruction,
          "span \{ordinal} in paragraph \{paragraph_index}",
        )
      MalformedField =>
        raise format_surgery_refuse(
          FormatMalformedField,
          "span \{ordinal} in paragraph \{paragraph_index}",
        )
      FieldResult =>
        raise format_surgery_refuse(
          FormatRestrictedRegion,
          "span \{ordinal} in paragraph \{paragraph_index}",
        )
      _ => ()
    }
  }

  fn require_singly_projected(
    contribution : ReaderProjectionContribution,
    ordinal : Int,
  ) -> Unit raise DocxError {
    let mut count = 0
    for part in parts {
      if part.contribution.source == contribution.source {
        count += 1
      }
    }
    if count > 1 {
      raise format_surgery_refuse(
        FormatDuplicateSource,
        "span \{ordinal} in paragraph \{paragraph_index}",
      )
    }
  }

  fn resolve_run(
    run_source : SourceElementId?,
    ordinal : Int,
  ) -> ReaderProjectionRun raise DocxError {
    guard run_source is Some(source_id) else {
      raise format_surgery_refuse(
        FormatUnsupportedTextSource,
        "span \{ordinal} in paragraph \{paragraph_index} draws from content outside any run",
      )
    }
    let mut found : ReaderProjectionRun? = None
    for run in paragraph.runs {
      if run.source == source_id {
        found = Some(run)
      }
    }
    guard found is Some(run) else {
      raise format_surgery_refuse(
        FormatInternalPlanConflict,
        "span \{ordinal} in paragraph \{paragraph_index}",
      )
    }
    run
  }

  fn require_host_element(
    identity : Int,
    ordinal : Int,
  ) -> Unit raise DocxError {
    let element = elements[identity]
    if run_surgery_inside_checkbox_control(elements, element) {
      raise format_surgery_refuse(
        FormatCheckboxControl,
        "span \{ordinal} in paragraph \{paragraph_index}",
      )
    }
    if run_surgery_restricted_ancestor(elements, element) is Some(_) {
      raise format_surgery_refuse(
        FormatRestrictedRegion,
        "span \{ordinal} in paragraph \{paragraph_index}",
      )
    }
    for index, other in projection.paragraphs {
      if index != paragraph_index {
        for candidate in other.runs {
          for part in parts {
            if part.contribution.source == SourceElementId(identity) &&
              part.contribution.run_source == Some(candidate.source) {
              raise format_surgery_refuse(
                FormatCrossParagraphSourceReuse,
                "span \{ordinal} in paragraph \{paragraph_index} reuses a run of paragraph \{index}",
              )
            }
          }
        }
      }
    }
  }

  // The set of touched runs, in first-touch order.
  let touched_runs : Array[ReaderProjectionRun] = []
  for ordinal, span in requested {
    // Zero-width barriers strictly inside the span refuse.
    for contribution in paragraph.contributions {
      let position = contribution.projection_start - paragraph.projection_start
      if contribution.projection_start == contribution.projection_end &&
        position > span.start &&
        position < span.end {
        match contribution.kind {
          VisibleNonText =>
            raise format_surgery_refuse(
              FormatVisibleBarrier,
              "span \{ordinal} in paragraph \{paragraph_index}",
            )
          SuppressedContent =>
            raise format_surgery_refuse(
              FormatSuppressedRegion,
              "span \{ordinal} in paragraph \{paragraph_index}",
            )
          Transparent => {
            let SourceElementId(seam_identity) = contribution.source
            let seam = elements[seam_identity]
            if run_surgery_is_hard_barrier_container(seam) {
              raise format_surgery_refuse(
                FormatVisibleBarrier,
                "span \{ordinal} in paragraph \{paragraph_index}",
              )
            }
            // Transparent content strictly inside the span may still be
            // painted (`w:annotationRef` is), and it need not belong to
            // a run this batch touches — so it would sit unformatted in
            // the middle of a span the receipt calls formatted. Only a
            // QNAME the reader walks into (a wrapper) or one that
            // provably renders nothing can be vouched for; child
            // presence proves nothing, because the reader ignores
            // `w:annotationRef` WITH its children.
            if !format_surgery_transparent_is_accounted(seam) {
              raise format_surgery_refuse(
                FormatVisibleBarrier,
                "span \{ordinal} in paragraph \{paragraph_index}: a transparent leaf inside the span cannot be proven to render nothing",
              )
            }
          }
          _ => ()
        }
      }
    }
    let intersecting : Array[PartialProjectingPart] = []
    for part in parts {
      if part.local_start < span.end && part.local_end > span.start {
        intersecting.push(part)
      }
    }
    guard intersecting.length() > 0 else {
      raise format_surgery_refuse(
        FormatInternalPlanConflict,
        "span \{ordinal} in paragraph \{paragraph_index} covers no projecting content",
      )
    }
    for part in intersecting {
      // V1 formats ordinary mapped text only: a projected atom (tab,
      // symbol, hyphen) inside the selection refuses whether covered
      // wholly or split.
      if !part.is_text {
        raise format_surgery_refuse(
          ProjectedAtom,
          "span \{ordinal} in paragraph \{paragraph_index}",
        )
      }
      let run = resolve_run(part.contribution.run_source, ordinal)
      require_supported_run(run, ordinal)
      require_supported_contribution(part.contribution, ordinal)
      require_singly_projected(part.contribution, ordinal)
      let SourceElementId(identity) = part.contribution.source
      require_host_element(identity, ordinal)
      let element = elements[identity]
      guard is_wml_uri(element.uri) && element.local_name == "t" else {
        raise format_surgery_refuse(
          FormatUnsupportedTextSource,
          "span \{ordinal} in paragraph \{paragraph_index}",
        )
      }
      guard element.text_map is Some(map) else {
        raise format_surgery_refuse(
          FormatUnsupportedTextSource,
          "span \{ordinal} in paragraph \{paragraph_index} addresses a self-closing text element",
        )
      }
      if map.contains_cdata {
        raise format_surgery_refuse(
          FormatCDataContext,
          "span \{ordinal} in paragraph \{paragraph_index}",
        )
      }
      let mut seen = false
      for existing in touched_runs {
        if existing.source == run.source {
          seen = true
        }
      }
      if !seen {
        touched_runs.push(run)
      }
    }
    // Every run whose element span overlaps the span's byte window is
    // structurally involved and carries field state of its own, whether
    // or not it contributes — nested tolerated runs register out of
    // index order, so the PHYSICAL window is what sees them.
    let mut window_start = -1
    let mut window_end = -1
    for part in intersecting {
      let span_bytes = part.contribution.source_span
      if window_start < 0 || span_bytes.byte_start < window_start {
        window_start = span_bytes.byte_start
      }
      if span_bytes.byte_end > window_end {
        window_end = span_bytes.byte_end
      }
    }
    for candidate in paragraph.runs {
      let SourceElementId(candidate_identity) = candidate.source
      let candidate_element = elements[candidate_identity]
      if candidate_element.byte_start < window_end &&
        candidate_element.byte_end > window_start {
        require_supported_run(candidate, ordinal)
      }
    }
  }
  // Phase 3b: scalar endpoints, batch-wide and BEFORE any satisfaction
  // or in-place shortcut — an endpoint interior to a text part must
  // resolve through its token map even when the run turns out to be
  // already satisfied or fully covered.
  for ordinal, span in requested {
    for endpoint in [span.start, span.end] {
      for part in parts {
        if part.is_text &&
          part.local_start < endpoint &&
          endpoint < part.local_end {
          let SourceElementId(identity) = part.contribution.source
          guard elements[identity].text_map is Some(map) else {
            raise format_surgery_refuse(
              FormatInternalPlanConflict,
              "span \{ordinal} in paragraph \{paragraph_index} lost its map",
            )
          }
          guard map.byte_offset_at(endpoint - part.local_start) is Some(_) else {
            raise format_surgery_refuse(
              FormatNonScalarBoundary,
              "span \{ordinal} in paragraph \{paragraph_index}",
            )
          }
        }
      }
    }
  }
  // An rPr belonging to a run this batch does NOT touch never reaches
  // the rPr engine, so nothing else would notice content hiding in it.
  // Proven here, for every such rPr sitting inside a span.
  for ordinal, span in requested {
    for contribution in paragraph.contributions {
      let position = contribution.projection_start - paragraph.projection_start
      guard contribution.projection_start == contribution.projection_end &&
        position > span.start &&
        position < span.end else {
        continue
      }
      let SourceElementId(seam_identity) = contribution.source
      let seam = elements[seam_identity]
      guard is_wml_uri(seam.uri) && seam.local_name == "rPr" else { continue }
      let mut owner_touched = false
      for touched in touched_runs {
        if contribution.run_source == Some(touched.source) {
          owner_touched = true
        }
      }
      if !owner_touched &&
        !format_surgery_rpr_is_formatting_only(elements, seam) {
        raise format_surgery_refuse(
          FormatVisibleBarrier,
          "span \{ordinal} in paragraph \{paragraph_index}: an untouched run's properties hold content this planner cannot prove renders nothing",
        )
      }
    }
  }
  // Per-run hyperlink ancestry: a formatting span may CROSS a hyperlink
  // boundary between sibling runs (each run keeps its wrapper), but a
  // tolerated run whose OWN contributions cross hyperlink ancestry cannot
  // be mutated soundly.
  for run in touched_runs {
    // The WHOLE run is the mutation footprint, so EVERY contribution it
    // owns — selected or not, projecting or zero-width — must pass the
    // host gates before any shortcut: duplicate projection, field
    // state, checkbox and restricted ancestry. `parts` holds projecting
    // text only, so this walk reads the paragraph's full contribution
    // list.
    for contribution in paragraph.contributions {
      if contribution.run_source == Some(run.source) {
        if contribution.kind is ProjectedText(_) {
          let mut count = 0
          for other in parts {
            if other.contribution.source == contribution.source {
              count += 1
            }
          }
          if count > 1 {
            raise format_surgery_refuse(
              FormatDuplicateSource,
              "paragraph \{paragraph_index}: a touched run is projected more than once",
            )
          }
        }
        match contribution.field_region {
          FieldInstruction =>
            raise format_surgery_refuse(
              FormatFieldInstruction,
              "paragraph \{paragraph_index}",
            )
          MalformedField =>
            raise format_surgery_refuse(
              FormatMalformedField,
              "paragraph \{paragraph_index}",
            )
          FieldResult =>
            raise format_surgery_refuse(
              FormatRestrictedRegion,
              "paragraph \{paragraph_index}",
            )
          _ => ()
        }
        let SourceElementId(owned_identity) = contribution.source
        let owned_element = elements[owned_identity]
        if format_surgery_is_checkbox_sdt(elements, owned_element) ||
          run_surgery_inside_checkbox_control(elements, owned_element) {
          raise format_surgery_refuse(
            FormatCheckboxControl,
            "paragraph \{paragraph_index}: the run encloses a checkbox control",
          )
        }
        if run_surgery_restricted_ancestor(elements, owned_element) is Some(_) {
          raise format_surgery_refuse(
            FormatRestrictedRegion,
            "paragraph \{paragraph_index}: the run encloses restricted content",
          )
        }
        // Zero-width VISIBLE or SUPPRESSED content the run owns cannot
        // be included in or excluded from a span — it has no width to
        // select — yet the footprint would format it along with the
        // run. A note reference at a run edge is exactly that shape,
        // so v1 refuses rather than formatting content no span chose.
        match contribution.kind {
          VisibleNonText =>
            raise format_surgery_refuse(
              FormatVisibleBarrier,
              "paragraph \{paragraph_index}: the run carries visible non-text content",
            )
          SuppressedContent =>
            raise format_surgery_refuse(
              FormatSuppressedRegion,
              "paragraph \{paragraph_index}: the run carries suppressed content",
            )
          Transparent => {
            // The reader's "transparent" verdict is about PROJECTION,
            // not about rendering: `w:annotationRef` is the visible
            // comment mark and would take the run's new formatting.
            // So the rule here is an ALLOWLIST of seams that provably
            // render nothing — everything else refuses, including
            // constructs this planner has never seen.
            let SourceElementId(seam_identity) = contribution.source
            let seam = elements[seam_identity]
            guard format_surgery_transparent_is_accounted(seam) else {
              raise format_surgery_refuse(
                FormatVisibleBarrier,
                "paragraph \{paragraph_index}: the run carries content this planner cannot prove renders nothing",
              )
            }
          }
          _ => ()
        }
      }
    }
    // A run with a NESTED registered run inside its byte span is a
    // tolerated physical shape this planner refuses to mutate: the
    // nested run's text is outside this run's own contributions, yet
    // an rPr edit here would wrap it in the new formatting.
    let SourceElementId(footprint_identity) = run.source
    let footprint_element = elements[footprint_identity]
    for candidate in paragraph.runs {
      if candidate.source != run.source {
        let SourceElementId(candidate_identity) = candidate.source
        let candidate_element = elements[candidate_identity]
        if candidate_element.byte_start >= footprint_element.byte_start &&
          candidate_element.byte_end <= footprint_element.byte_end {
          raise format_surgery_refuse(
            FormatUnsupportedTextSource,
            "paragraph \{paragraph_index}: the run nests another run inside its footprint",
          )
        }
      }
    }
    // A run claimed by another paragraph cannot be this paragraph's
    // footprint.
    for index, other in projection.paragraphs {
      if index != paragraph_index {
        for candidate in other.runs {
          if candidate.source == run.source {
            raise format_surgery_refuse(
              FormatCrossParagraphSourceReuse,
              "paragraph \{paragraph_index} would mutate a run of paragraph \{index}",
            )
          }
        }
      }
    }
    let mut anchor : Int?? = None
    for part in parts {
      if part.contribution.run_source == Some(run.source) {
        let SourceElementId(identity) = part.contribution.source
        let link = run_surgery_hyperlink_ancestor(elements, elements[identity])
        match anchor {
          None => anchor = Some(link)
          Some(first) =>
            if first != link {
              raise format_surgery_refuse(
                FormatRestrictedRegion,
                "paragraph \{paragraph_index}: a run's contributions cross hyperlink ancestry",
              )
            }
        }
      }
    }
  }
  // Phase 4: per-run coverage partition and boundary resolution.
  let edits : Array[RunSurgeryEdit] = []
  let outcomes : Array[FormatRunOutcome] = []
  let mut runs_changed = 0
  let mut runs_already_satisfied = 0
  let mut splits = 0
  for run in touched_runs {
    let SourceElementId(run_identity) = run.source
    let run_element = elements[run_identity]
    // The run's own binding, from its own tag. A default-namespace run
    // has no derivable ATTRIBUTE binding (default namespaces do not
    // apply to attributes), so v1 refuses it here rather than guessing.
    let run_prefix = format_surgery_element_prefix(source, run_element)
    guard run_prefix != "" else {
      raise format_surgery_refuse(
        UnsupportedNamespaceBinding,
        "paragraph \{paragraph_index}: the run binds WML as its default namespace",
      )
    }
    // Vouch extension prefixes by NAMESPACE URI, from the scan: an rPr
    // child whose element resolves to a recognized extension vocabulary
    // is warranted under the prefix it is spelled with.
    let extension_prefixes : Array[String] = []
    let mut run_child = run_element.first_child_index
    while run_child >= 0 {
      let child = elements[run_child]
      if is_wml_uri(child.uri) && child.local_name == "rPr" {
        let mut rpr_child = child.first_child_index
        while rpr_child >= 0 {
          let entry = elements[rpr_child]
          if format_extension_uri(entry.uri) {
            let entry_prefix = format_surgery_element_prefix(source, entry)
            if entry_prefix != run_prefix &&
              entry_prefix != "" &&
              !extension_prefixes.contains(entry_prefix) {
              extension_prefixes.push(entry_prefix)
            }
          }
          rpr_child = entry.next_sibling_index
        }
      }
      run_child = child.next_sibling_index
    }
    // The run's projecting parts, in order, with their coverage.
    let run_parts : Array[PartialProjectingPart] = []
    for part in parts {
      if part.contribution.run_source == Some(run.source) {
        run_parts.push(part)
      }
    }
    let mut fully_covered = true
    for part in run_parts {
      let mut cursor = part.local_start
      for span in requested {
        let from = if span.start > cursor { span.start } else { cursor }
        let to = if span.end < part.local_end {
          span.end
        } else {
          part.local_end
        }
        if from > cursor && from < part.local_end {
          fully_covered = false
        }
        if to > from {
          cursor = to
        }
      }
      if cursor < part.local_end {
        fully_covered = false
      }
    }
    // Satisfaction first: an already-correct run — fully OR partially
    // covered — takes no edit and no split.
    let run_slice = source[run_element.byte_start:run_element.byte_end]
    let baseline = plan_run_format(
      run_slice,
      prefix=run_prefix,
      extension_prefixes~,
      format~,
    ) catch {
      Unsupported(message~) =>
        raise format_surgery_map_rpr_refusal(
          message,
          "paragraph \{paragraph_index}",
        )
      error => raise error
    }
    if !baseline.changed() {
      outcomes.push({ run_identity, fully_covered, action: AlreadySatisfied, })
      runs_already_satisfied += 1
      continue
    }
    if fully_covered {
      // In-place minimal rPr edit, rebased to absolute offsets.
      for edit in baseline.edits() {
        edits.push({
          byte_start: run_element.byte_start + edit.start(),
          byte_end: run_element.byte_start + edit.end(),
          replacement: edit.replacement(),
        })
      }
      outcomes.push({ run_identity, fully_covered, action: FormattedInPlace, })
      runs_changed += 1
      continue
    }
    // Clone-split. The run must consist of exactly: an optional leading
    // rPr, then mapped `w:t` elements, tiling its content contiguously.
    let (segment_count, replacement) = format_surgery_split_run(
      projection, source, run_element, run_parts, requested, run_prefix, extension_prefixes,
      format,
    ) catch {
      Unsupported(message~) => {
        if message.contains("formatting surgery [") {
          raise Unsupported(message~)
        }
        raise format_surgery_map_rpr_refusal(
          message,
          "paragraph \{paragraph_index}",
        )
      }
      error => raise error
    }
    edits.push({
      byte_start: run_element.byte_start,
      byte_end: run_element.byte_end,
      replacement,
    })
    outcomes.push({
      run_identity,
      fully_covered,
      action: SplitIntoSegments(segment_count),
    })
    runs_changed += 1
    splits += 1
  }
  // Ordering: distinct runs are disjoint, and within one run the F0 edits
  // are already ascending; the explicit ordinal keeps the sort stable.
  let ordered : Array[(RunSurgeryEdit, Int)] = []
  for index, edit in edits {
    ordered.push((edit, index))
  }
  ordered.sort_by_key(entry => {
    (
      entry.0.byte_start,
      if entry.0.byte_end > entry.0.byte_start {
        1
      } else {
        0
      },
      entry.1,
    )
  })
  edits.clear()
  for entry in ordered {
    edits.push(entry.0)
  }
  // Internal validation: the byte plan must be non-overlapping.
  let mut last_end = -1
  for edit in edits {
    if edit.byte_start < last_end {
      raise format_surgery_refuse(
        FormatInternalPlanConflict,
        "byte edits overlap in paragraph \{paragraph_index}",
      )
    }
    last_end = edit.byte_end
  }
  let receipt = FormatSurgeryReceipt::{
    paragraph_index,
    expected_projection: before_projection,
    outcomes,
    runs_changed,
    runs_already_satisfied,
    splits,
  }
  (edits, receipt)
}

///|
/// Assemble the clone-split replacement for one partially covered run:
/// consecutive same-coverage fragments group into segments, each segment
/// becomes one cloned run (open tag and rPr byte-identical; the covered
/// segments' rPr formatted through the F0 engine), and fragment text is
/// cloned by byte range through the token map so entity spellings
/// survive. Returns (segment count, replacement string).
fn format_surgery_split_run(
  projection : ReaderProjection,
  source : BytesView,
  run_element : ScannedElement,
  run_parts : Array[PartialProjectingPart],
  requested : Array[ParagraphFormatSpan],
  run_prefix : String,
  extension_prefixes : Array[String],
  format : DocxDirectFormat,
) -> (Int, String) raise DocxError {
  let elements = projection.scan.elements()
  guard !run_surgery_is_self_closing(run_element) else {
    raise format_surgery_refuse(
      FormatInternalPlanConflict,
      "a self-closing run cannot be partially covered",
    )
  }
  // Children shape: optional leading rPr, then mapped `w:t` elements,
  // tiling the content region with no gaps.
  let mut rpr : ScannedElement? = None
  let wts : Array[ScannedElement] = []
  let mut child_index = run_element.first_child_index
  let mut expected_at = run_element.content_start
  let mut first = true
  while child_index >= 0 {
    let child = elements[child_index]
    guard child.byte_start == expected_at else {
      raise format_surgery_refuse(
        UnsplittableRun,
        "the run's children do not tile its content",
      )
    }
    if first && is_wml_uri(child.uri) && child.local_name == "rPr" {
      rpr = Some(child)
    } else if is_wml_uri(child.uri) &&
      child.local_name == "t" &&
      child.text_map is Some(map) &&
      !map.contains_cdata {
      wts.push(child)
    } else {
      raise format_surgery_refuse(
        UnsplittableRun,
        "the run carries a child that is not run properties or mapped text",
      )
    }
    first = false
    expected_at = child.byte_end
    child_index = child.next_sibling_index
  }
  guard expected_at == run_element.content_end else {
    raise format_surgery_refuse(
      UnsplittableRun,
      "the run's children do not tile its content",
    )
  }
  guard wts.length() > 0 else {
    raise format_surgery_refuse(
      FormatInternalPlanConflict,
      "a partially covered run has no mapped text",
    )
  }
  // Cloning duplicates every attribute in its footprint; an
  // identity-bearing one (xml:id and friends) must not be duplicated,
  // so the split refuses — for the run's open tag, for every mapped
  // text element, and for the WHOLE rPr subtree the clones copy.
  if format_surgery_open_tag_has_identity_attribute(source, run_element) {
    raise format_surgery_refuse(
      UnsplittableRun,
      "the run carries an identity-bearing attribute a split would duplicate",
    )
  }
  for wt in wts {
    if format_surgery_open_tag_has_identity_attribute(source, wt) {
      raise format_surgery_refuse(
        UnsplittableRun,
        "a text element carries an identity-bearing attribute a split would duplicate",
      )
    }
  }
  match rpr {
    Some(element) =>
      if format_surgery_subtree_has_identity_attribute(
          source, elements, element,
        ) {
        raise format_surgery_refuse(
          UnsplittableRun,
          "the run properties carry an identity-bearing attribute a split would duplicate",
        )
      }
    None => ()
  }
  // Pieces: per `w:t`, wt-local boundaries at every covered-interval edge.
  let pieces : Array[FormatPiece] = []
  for wt in wts {
    let mut wt_part : PartialProjectingPart? = None
    for part in run_parts {
      if part.contribution.source == SourceElementId(wt.identity) {
        wt_part = Some(part)
      }
    }
    guard wt_part is Some(part) else {
      // A `w:t` that projects nothing (empty content): a neutral piece
      // cloned verbatim into whichever segment is current.
      pieces.push({
        wt_identity: wt.identity,
        local_from: 0,
        local_to: 0,
        covered: pieces.length() > 0 && pieces[pieces.length() - 1].covered,
      })
      continue
    }
    let width = part.local_end - part.local_start
    let cuts : Array[Int] = [0]
    for span in requested {
      let from = span.start - part.local_start
      let to = span.end - part.local_start
      if from > 0 && from < width && !cuts.contains(from) {
        cuts.push(from)
      }
      if to > 0 && to < width && !cuts.contains(to) {
        cuts.push(to)
      }
    }
    if width == 0 {
      // A mapped `w:t` that projects nothing still exists in the source
      // and must survive the split verbatim.
      pieces.push({
        wt_identity: wt.identity,
        local_from: 0,
        local_to: 0,
        covered: pieces.length() > 0 && pieces[pieces.length() - 1].covered,
      })
      continue
    }
    if !cuts.contains(width) {
      cuts.push(width)
    }
    cuts.sort()
    for index in 0..<(cuts.length() - 1) {
      let from = cuts[index]
      let to = cuts[index + 1]
      let absolute_from = part.local_start + from
      let mut covered = false
      for span in requested {
        if span.start <= absolute_from && absolute_from < span.end {
          covered = true
        }
      }
      pieces.push({
        wt_identity: wt.identity,
        local_from: from,
        local_to: to,
        covered,
      })
    }
  }
  // Segments: maximal same-coverage groups of consecutive pieces.
  // Abutting pieces of one `w:t` coalesce first, so two abutting spans
  // yield ONE cloned fragment, not two adjacent text elements.
  let coalesced : Array[FormatPiece] = []
  for piece in pieces {
    if coalesced.length() > 0 {
      let last = coalesced[coalesced.length() - 1]
      if last.wt_identity == piece.wt_identity &&
        last.covered == piece.covered &&
        last.local_to == piece.local_from {
        coalesced[coalesced.length() - 1] = {
          wt_identity: last.wt_identity,
          local_from: last.local_from,
          local_to: piece.local_to,
          covered: last.covered,
        }
        continue
      }
    }
    coalesced.push(piece)
  }
  let segments : Array[(Bool, Array[FormatPiece])] = []
  for piece in coalesced {
    if segments.length() > 0 &&
      segments[segments.length() - 1].0 == piece.covered {
      segments[segments.length() - 1].1.push(piece)
    } else if piece.local_from == piece.local_to && segments.length() > 0 {
      // A zero-width neutral piece stays with the current segment.
      segments[segments.length() - 1].1.push(piece)
    } else {
      segments.push((piece.covered, [piece]))
    }
  }
  guard segments.length() > 1 else {
    raise format_surgery_refuse(
      FormatInternalPlanConflict,
      "a partial run resolved to a single segment",
    )
  }
  let run_open = format_surgery_decode(
    source[run_element.byte_start:run_element.content_start],
  )
  let run_close = format_surgery_decode(
    source[run_element.content_end:run_element.byte_end],
  )
  let rpr_bytes = match rpr {
    Some(element) =>
      format_surgery_decode(source[element.byte_start:element.byte_end])
    None => ""
  }
  let rendered = StringBuilder()
  let mut emitted = 0
  for segment in segments {
    let (covered, segment_pieces) = segment
    let body = StringBuilder()
    for piece in segment_pieces {
      let wt = elements[piece.wt_identity]
      guard wt.text_map is Some(map) else {
        raise format_surgery_refuse(
          FormatInternalPlanConflict,
          "a split host lost its map",
        )
      }
      if piece.local_from == piece.local_to && piece.local_from == 0 {
        // A neutral empty `w:t`: cloned verbatim.
        let whole_projection = format_surgery_wt_projection(projection, wt)
        if whole_projection == "" {
          body.write_string(
            format_surgery_decode(source[wt.byte_start:wt.byte_end]),
          )
          continue
        }
      }
      if piece.local_from == piece.local_to {
        continue
      }
      guard map.byte_offset_at(piece.local_from) is Some(byte_from) &&
        map.byte_offset_at(piece.local_to) is Some(byte_to) else {
        raise format_surgery_refuse(
          FormatNonScalarBoundary,
          "a span boundary inside the split run",
        )
      }
      let fragment_text = format_surgery_wt_projection(projection, wt)
        .view(start_offset=piece.local_from, end_offset=piece.local_to)
        .to_owned()
      body.write_string(
        format_surgery_clone_wt(source, wt, byte_from, byte_to, fragment_text),
      )
    }
    let body_text = body.to_string()
    if body_text == "" {
      continue
    }
    emitted += 1
    let candidate = run_open + rpr_bytes + body_text + run_close
    if covered {
      let candidate_bytes = @utf8.encode(candidate)
      let plan = plan_run_format(
        candidate_bytes,
        prefix=run_prefix,
        extension_prefixes~,
        format~,
      )
      let mut formatted = candidate
      let plan_edits = plan.edits()
      let mut index = plan_edits.length() - 1
      while index >= 0 {
        let edit = plan_edits[index]
        // F0 offsets are byte offsets into the candidate; the candidate
        // is assembled from the same UTF-8 the offsets were computed
        // against, so char and byte offsets agree only when ASCII — use
        // byte-level splicing to stay honest.
        formatted = format_surgery_splice_string(
          formatted,
          edit.start(),
          edit.end(),
          edit.replacement(),
        )
        index -= 1
      }
      rendered.write_string(formatted)
    } else {
      rendered.write_string(candidate)
    }
  }
  guard emitted > 1 else {
    raise format_surgery_refuse(
      FormatInternalPlanConflict,
      "a partial run rendered fewer than two clones",
    )
  }
  (emitted, rendered.to_string())
}

///|
/// The decoded projection of one mapped `w:t`, from its own contribution.
fn format_surgery_wt_projection(
  projection : ReaderProjection,
  wt : ScannedElement,
) -> String {
  for paragraph in projection.paragraphs {
    for contribution in paragraph.contributions {
      if contribution.source == SourceElementId(wt.identity) {
        return contribution.value
      }
    }
  }
  ""
}

///|
/// Clone one `w:t` around a content byte range, applying the xml:space
/// policy to the FRAGMENT: add or upgrade to `preserve` when the fragment
/// needs it; never remove an existing declaration.
fn format_surgery_clone_wt(
  source : BytesView,
  wt : ScannedElement,
  byte_from : Int,
  byte_to : Int,
  fragment_text : String,
) -> String raise DocxError {
  let open_bytes = format_surgery_decode(source[wt.byte_start:wt.content_start])
  let close_bytes = format_surgery_decode(source[wt.content_end:wt.byte_end])
  let content = format_surgery_decode(source[byte_from:byte_to])
  let wants_space = run_surgery_needs_space_preserve(fragment_text)
  let open_tag = if wants_space {
    match run_surgery_space_declaration(source, wt) {
      Some((from, to)) =>
        match run_surgery_space_declaration_is_preserve(source, (from, to)) {
          Some(true) => open_bytes
          Some(false) =>
            format_surgery_splice_string(
              open_bytes,
              from - wt.byte_start,
              to - wt.byte_start,
              "xml:space=\"preserve\"",
            )
          None =>
            raise format_surgery_refuse(
              FormatUnsupportedTextSource,
              "an xml:space declaration cannot be decoded",
            )
        }
      None =>
        format_surgery_splice_string(
          open_bytes,
          wt.content_start - wt.byte_start - 1,
          wt.content_start - wt.byte_start - 1,
          " xml:space=\"preserve\"",
        )
    }
  } else {
    open_bytes
  }
  open_tag + content + close_bytes
}

///|
/// Splice a replacement into a string at BYTE offsets of its UTF-8
/// encoding — the offsets this planner works in.
fn format_surgery_splice_string(
  text : String,
  byte_from : Int,
  byte_to : Int,
  replacement : String,
) -> String raise DocxError {
  let bytes = @utf8.encode(text)
  let head = format_surgery_decode(bytes[0:byte_from])
  let tail = format_surgery_decode(bytes[byte_to:bytes.length()])
  head + replacement + tail
}

///|
fn format_surgery_decode(bytes : BytesView) -> String raise DocxError {
  @utf8.decode(bytes.to_owned()) catch {
    _ =>
      raise format_surgery_refuse(
        FormatInternalPlanConflict,
        "a cloned byte range is not valid UTF-8",
      )
  }
}
