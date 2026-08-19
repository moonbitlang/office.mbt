// The field-classification bridge (#434 PR 5b): the EXISTING field state
// machine runs unchanged over the reader-native projection through a
// minimal facade. The machine consumes only physical facts -- each
// contribution's source identity and owning physical paragraph, the
// carrier event stream, and the scan itself -- and writes the three field
// annotations back per contribution, so the facade is index-aligned
// throwaway structure, not a second implementation.

///|
/// The physical paragraph owning a source, for carrier resolution: the
/// nearest `w:p` ancestor. Content outside every paragraph gets a sentinel
/// no parent index can equal, so its carrier resolves to `None` exactly as
/// the legacy walker's flow-level contributions do.
fn reader_projection_owning_paragraph(
  elements : Array[ScannedElement],
  source_identity : Int,
) -> Int {
  let mut current = elements[source_identity].parent_index
  while current >= 0 {
    let element = elements[current]
    if is_wml_uri(element.uri) && element.local_name == "p" {
      return current
    }
    current = element.parent_index
  }
  -2
}

///|
/// Classifies complex fields over a reader-native projection by running
/// `classify_reader_order_fields` on a facade, then copying the per-
/// contribution annotations back and storing the index. A separate
/// post-adapter step, exactly as the legacy pipeline separates the walk
/// from classification.
fn classify_reader_projection_fields(
  projection : ReaderProjection,
  budget? : ReaderOrderFieldBudget,
) -> Unit raise DocxError {
  let elements = projection.scan.elements()
  let facade_paragraphs : Array[ReaderOrderParagraph] = []
  for paragraph in projection.paragraphs {
    let contributions : Array[ReaderOrderContribution] = []
    for contribution in paragraph.contributions {
      let SourceElementId(source_identity) = contribution.source
      contributions.push({
        kind: HardBarrier,
        value: "",
        source_identity,
        paragraph_identity: reader_projection_owning_paragraph(
          elements, source_identity,
        ),
        run_identity: None,
        source_span: contribution.source_span,
        field_identity: None,
        field_region: OutsideField,
        field_refusal: None,
        projection_start: -1,
        projection_end: -1,
        logical_run_index: -1,
      })
    }
    facade_paragraphs.push({
      from_text_box: false,
      sources: [],
      contributions,
      logical_index: -1,
      projection_start: 0,
      projection_end: 0,
    })
  }
  let facade : ReaderOrderProjection = {
    source_part: projection.source_part,
    source_elements: elements,
    paragraphs: facade_paragraphs,
    field_carriers: projection.field_carriers,
    field_index: empty_reader_order_field_index(),
  }
  let index = classify_reader_order_fields(facade, budget?)
  for paragraph_index, paragraph in projection.paragraphs {
    let facade_contributions = facade_paragraphs[paragraph_index].contributions
    for contribution_index, contribution in paragraph.contributions {
      let annotated = facade_contributions[contribution_index]
      contribution.field_identity = annotated.field_identity
      contribution.field_region = annotated.field_region
      contribution.field_refusal = annotated.field_refusal
    }
  }
  projection.field_index = index
}
