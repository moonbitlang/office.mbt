// The reader-native projection (#434 PR 5): what the reader actually did,
// with physical provenance attached. Built by `reader_projection_adapter.mbt`
// from one joined read; the legacy byte-level walker survives only as a
// white-box oracle over the shared valid domain.

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
priv struct ReaderProjectionContribution {
  kind : ReaderProjectionContributionKind
  value : String
  source : SourceElementId
  /// The innermost physical run this contribution sits in, when any.
  run_source : SourceElementId?
  source_span : ReaderOrderSourceSpan
  /// Half-open UTF-16 interval in the reader's story text; zero-width
  /// contributions get an empty interval at the position they sit.
  mut projection_start : Int
  mut projection_end : Int
  /// Index of this contribution's run within its paragraph by order of
  /// first appearance, or -1 when it belongs to no run.
  mut logical_run_index : Int
}

///|
/// One physical run observed inside a logical paragraph, in order of first
/// appearance. Registered structurally on entering the run, so an atomless
/// run stays addressable without any effect.
priv struct ReaderProjectionRun {
  source : SourceElementId
  source_span : ReaderOrderSourceSpan
}

///|
/// One physical source paragraph of a logical paragraph: deleted
/// paragraph-mark prefixes stay separate entries even though their content
/// joined the terminal paragraph.
priv struct ReaderProjectionParagraphSource {
  source : SourceElementId
  source_span : ReaderOrderSourceSpan
}

///|
priv struct ReaderProjectionParagraph {
  sources : Array[ReaderProjectionParagraphSource]
  runs : Array[ReaderProjectionRun]
  contributions : Array[ReaderProjectionContribution]
  mut logical_index : Int
  mut projection_start : Int
  mut projection_end : Int
}

///|
priv struct ReaderProjection {
  source_part : String
  scan : StoryScan
  paragraphs : Array[ReaderProjectionParagraph]
}

///|
/// Why a read's output could not be projected. Provenance failures are
/// typed refusals -- the adapter never invents an identity.
priv enum ReaderProjectionRefusal {
  MissingSourceIdentity(node_name~ : String)
  SourceIdentityOutOfRange(SourceElementId)
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
/// `assign_reader_order_logical_coordinates`.
fn assign_reader_projection_coordinates(projection : ReaderProjection) -> Unit {
  let mut offset = 0
  for index, paragraph in projection.paragraphs {
    paragraph.logical_index = index
    paragraph.projection_start = offset
    let run_indices : Map[Int, Int] = Map([])
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
