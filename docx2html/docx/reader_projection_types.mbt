// The reader-native projection (#434): what the reader actually did,
// with physical provenance attached. Built by `reader_projection_adapter.mbt`
// from one joined read. Since PR 7 this is the ONLY projection semantics;
// the legacy byte-level walker is deleted.

///|
#warnings("-unused_field")
priv struct ReaderSourceSpan {
  byte_start : Int
  byte_end : Int
}

///|
fn reader_element_span(element : ScannedElement) -> ReaderSourceSpan {
  { byte_start: element.byte_start, byte_end: element.byte_end }
}

///|
fn reader_atom_span(element : ScannedElement) -> ReaderSourceSpan {
  if is_wml_uri(element.uri) &&
    element.local_name == "t" &&
    element.text_map is Some(_) {
    { byte_start: element.content_start, byte_end: element.content_end }
  } else {
    reader_element_span(element)
  }
}

///|
/// The four-way contribution kind, one level finer than the legacy
/// TransparentSeam/HardBarrier pair: a barrier that is VISIBLE (a break, a
/// reference, an image, a checkbox) is distinguished from suppressed
/// content, and text keeps its atom kind.
priv enum ReaderProjectionContributionKind {
  ProjectedText(ReaderProjectedTextKind)
  VisibleNonText
  Transparent
  SuppressedContent
} derive(Debug, Eq)

///|
/// One reader decision in story order. Only `ProjectedText` occupies UTF-16
/// width; everything else is a zero-width position marker. `source` always
/// indexes the story's scan.
#warnings("-unused_field")
priv struct ReaderProjectionContribution {
  kind : ReaderProjectionContributionKind
  value : String
  source : SourceElementId
  /// The innermost physical run this contribution sits in, when any.
  run_source : SourceElementId?
  source_span : ReaderSourceSpan
  /// Half-open UTF-16 interval in the reader's story text; zero-width
  /// contributions get an empty interval at the position they sit.
  mut projection_start : Int
  mut projection_end : Int
  /// Index of this contribution's run within its paragraph by order of
  /// first appearance, or -1 when it belongs to no run.
  mut logical_run_index : Int
  /// Field annotations, populated by `classify_reader_projection_fields`.
  mut field_identity : Int?
  mut field_region : ReaderFieldRegion
  mut field_refusal : Int?
}

///|
/// One physical run observed inside a logical paragraph, in order of first
/// appearance. Registered structurally on entering the run, so an atomless
/// run stays addressable without any effect.
#warnings("-unused_field")
priv struct ReaderProjectionRun {
  source : SourceElementId
  /// Position among the paragraph's runs in first-appearance order -- the
  /// r[j] a surgery address names. Atomless runs participate, exactly as
  /// the legacy walker's zero-width run-open seams made them.
  mut logical_index : Int
  /// The run's own field region and refusal, populated by
  /// `classify_reader_projection_fields` through a run slot: a run with
  /// NO contributions still sits somewhere, and surgery must refuse an
  /// instruction-region, malformed-field or refused-field run even when
  /// nothing inside it projected. The refusal matters separately from
  /// the region: truncation is discovered at story END, after regions
  /// are assigned, so a truncated field's result run keeps FieldResult
  /// and carries the refusal alone.
  mut field_region : ReaderFieldRegion
  mut field_refusal : Int?
}

///|
/// One physical source paragraph of a logical paragraph: deleted
/// paragraph-mark prefixes stay separate entries even though their content
/// joined the terminal paragraph.
#warnings("-unused_field")
priv struct ReaderProjectionParagraphSource {
  source : SourceElementId
  source_span : ReaderSourceSpan
}

///|
#warnings("-unused_field")
priv struct ReaderProjectionParagraph {
  sources : Array[ReaderProjectionParagraphSource]
  runs : Array[ReaderProjectionRun]
  contributions : Array[ReaderProjectionContribution]
  mut logical_index : Int
  mut projection_start : Int
  mut projection_end : Int
}

///|
#warnings("-unused_field")
priv struct ReaderProjection {
  scan : StoryScan
  paragraphs : Array[ReaderProjectionParagraph]
  /// One event per direct physical child of each visited paragraph, in
  /// the walk's document order (nested paragraphs' groups interleave at
  /// their positions) -- the stream the field classification consumes.
  field_carriers : Array[ReaderFieldCarrierEvent]
  /// Populated by `classify_reader_projection_fields`.
  mut field_index : ReaderFieldIndex
}

///|
/// Why a read's output could not be projected. Provenance failures are
/// typed refusals -- the adapter never invents an identity.
priv enum ReaderProjectionRefusal {
  MissingSourceIdentity(node_name~ : String)
  SourceIdentityOutOfRange(SourceElementId)
  /// A node whose physical element is not the shape its role requires --
  /// e.g. a synthesized run whose carrier is not a `w:r`.
  SourceShapeMismatch(
    source~ : SourceElementId,
    expected~ : String,
    actual~ : String
  )
  /// Visible content that no logical paragraph ever owns (flow-level
  /// content after the final paragraph). Zero-width markers in the same
  /// position are dropped instead: nothing addresses them.
  UnownedVisibleContribution(source~ : SourceElementId)
}

///|
priv enum ReaderProjectionBuildResult {
  Projected(ReaderProjection)
  ProjectionRefused(ReaderProjectionRefusal)
}

///|
fn ReaderProjectionRefusal::describe(self : ReaderProjectionRefusal) -> String {
  match self {
    MissingSourceIdentity(node_name~) =>
      "a \{node_name} node carries no physical identity"
    SourceIdentityOutOfRange(SourceElementId(index)) =>
      "source identity \{index} is outside the scan"
    SourceShapeMismatch(source=SourceElementId(index), expected~, actual~) =>
      "source element \{index} is a \{actual}, not the \{expected} its role requires"
    UnownedVisibleContribution(source=SourceElementId(index)) =>
      "visible content at source element \{index} is owned by no paragraph"
  }
}

///|
/// The `"\n\n"` BodyReader writes between paragraphs, in UTF-16 units --
/// the same constant the legacy projection uses.
let reader_projection_separator_units : Int = 2

///|
/// Assigns logical indices, first-appearance run numbering, and UTF-16
/// story intervals -- the exact convention of
/// the legacy coordinate-assignment convention.
fn assign_reader_projection_coordinates(projection : ReaderProjection) -> Unit {
  let mut offset = 0
  for index, paragraph in projection.paragraphs {
    paragraph.logical_index = index
    paragraph.projection_start = offset
    // seed the numbering from the runs list: an atomless run occupies its
    // first-appearance position even though no contribution names it
    let run_indices : Map[Int, Int] = Map([])
    for run in paragraph.runs {
      let SourceElementId(identity) = run.source
      run.logical_index = run_indices.length()
      run_indices[identity] = run.logical_index
    }
    for contribution in paragraph.contributions {
      contribution.logical_run_index = match contribution.run_source {
        Some(SourceElementId(identity)) =>
          match run_indices.get(identity) {
            Some(assigned) => assigned
            None => {
              let assigned = run_indices.length()
              run_indices[identity] = assigned
              assigned
            }
          }
        None => -1
      }
      contribution.projection_start = offset
      offset = offset + contribution.value.length()
      contribution.projection_end = offset
    }
    paragraph.projection_end = offset
    offset = offset + reader_projection_separator_units
  }
}

///|
/// Caller-owned cumulative limits for one projection build. Extras and
/// transformed subtrees can multiply occurrences, so the adapter carries
/// its own caps rather than inheriting the reader's.
priv struct ReaderProjectionBudget {
  mut visits_left : Int
  mut contributions_left : Int
  mut retained_left : Int
}

///|
/// Input-linear defaults: generous multiples of the physical element
/// count, far above any real document's fan-out.
fn reader_projection_budget(scan : StoryScan) -> ReaderProjectionBudget {
  let elements = scan.elements().length()
  let scaled = fn(factor : Int) -> Int {
    let value = elements * factor + 1024
    if value < 0 {
      2147483647
    } else {
      value
    }
  }
  {
    visits_left: scaled(64),
    contributions_left: scaled(16),
    retained_left: scaled(16),
  }
}

///|
fn ReaderProjectionBudget::charge_visit(
  self : ReaderProjectionBudget,
) -> Unit raise DocxError {
  self.visits_left = self.visits_left - 1
  if self.visits_left < 0 {
    raise @core.docx_xml_resource_limit_error(DocxXmlTokens)
  }
}

///|
fn ReaderProjectionBudget::charge_contribution(
  self : ReaderProjectionBudget,
) -> Unit raise DocxError {
  self.contributions_left = self.contributions_left - 1
  if self.contributions_left < 0 {
    raise @core.docx_xml_resource_limit_error(DocxXmlTokens)
  }
}

///|
fn ReaderProjectionBudget::charge_retained(
  self : ReaderProjectionBudget,
) -> Unit raise DocxError {
  self.retained_left = self.retained_left - 1
  if self.retained_left < 0 {
    raise @core.docx_xml_resource_limit_error(DocxXmlTokens)
  }
}
