///|
/// Scanned reconstruction inputs needed by the higher-level document loader.
pub(all) struct PdfReaderReconstructionPlan {
  classic_xref_sections : Array[(Int, PdfXRefSection)]
  xref_stream_sections : Array[PdfXRefSection]
  xref_coverage : PdfReconstructedXRefCoverage
  classic_xrefs : Array[PdfClassicXRefEntry]
  object_xrefs : Array[PdfClassicXRefEntry]
  trailers : Array[@syntax.PdfObject]
}

///|
/// Parser and verifier callbacks needed by the scanner-side reconstruction plan.
pub(all) struct PdfReaderReconstructionCallbacks {
  read_classic_xref_section_at : (@core.ByteCursor, Int) -> (
    PdfXRefSection,
    Int,
  ) raise @core.PdfError
  read_xref_stream_section_at : (@core.ByteCursor, Int) -> (PdfXRefSection, Int) raise @core.PdfError
  read_object_xref_at_current : (
    @core.ByteCursor,
    Int,
    ArrayView[PdfClassicXRefEntry],
    PdfClassicXRefIndex,
  ) -> (PdfClassicXRefEntry?, Int?) raise @core.PdfError
  read_trailer_at : (@core.ByteCursor, Int) -> @syntax.PdfObject raise @core.PdfError
  read_xref_stream_trailer_at : (@core.ByteCursor, Int) -> @syntax.PdfObject raise @core.PdfError
  verify_classic_xref_entry : (
    BytesView,
    ArrayView[PdfClassicXRefEntry],
    PdfClassicXRefIndex,
    PdfClassicXRefEntry,
  ) -> Bool
}

///|
/// Build the scanner-side reconstruction plan for a byte view.
///
/// Parser and verifier callbacks stay with the higher-level reader package,
/// while this package owns scan ordering and derived xref metadata.
pub fn pdf_reader_reconstruction_plan(
  data : BytesView,
  include_xref_stream_trailers : Bool,
  callbacks : PdfReaderReconstructionCallbacks,
) -> PdfReaderReconstructionPlan raise @core.PdfError {
  let classic_xref_sections = pdf_reader_reconstruction_classic_xref_sections(
    data,
    callbacks.read_classic_xref_section_at,
  )
  let xref_stream_sections = if include_xref_stream_trailers {
    pdf_reader_reconstruction_xref_stream_sections(
      data,
      callbacks.read_xref_stream_section_at,
    )
  } else {
    []
  }
  let xref_coverage = pdf_reader_reconstruction_xref_coverage(
    data,
    classic_xref_sections,
    xref_stream_sections,
    callbacks.verify_classic_xref_entry,
  )
  let classic_xrefs = pdf_reader_reconstruction_classic_xref_entries(
    classic_xref_sections,
  )
  let object_xrefs = pdf_reader_reconstruction_object_xrefs(
    data,
    callbacks.read_object_xref_at_current,
  )
  let trailers = pdf_reader_reconstruction_trailers(
    data,
    include_xref_stream_trailers,
    callbacks.read_trailer_at,
    callbacks.read_xref_stream_trailer_at,
  )
  {
    classic_xref_sections,
    xref_stream_sections,
    xref_coverage,
    classic_xrefs,
    object_xrefs,
    trailers,
  }
}
