///|
fn PdfDocument::load_reconstructed_plan(
  self : PdfDocument,
  data : BytesView,
  plan : @reader.PdfReaderReconstructionPlan,
  include_xref_stream_trailers : Bool,
  user_password : BytesView?,
  owner_password : BytesView?,
) -> Unit raise @core.PdfError {
  self.load_reconstructed_classic_xref_plain_objects(data, plan.classic_xrefs)
  self.load_reconstructed_object_xrefs(
    data,
    plan.object_xrefs,
    plan.xref_coverage,
  )
  if include_xref_stream_trailers {
    self.load_reconstructed_xref_stream_objects(data, plan.xref_stream_sections)
    self.load_reconstructed_physical_object_stream_members()
  }
  self.set_trailer_and_root(self.select_reconstructed_trailer(plan.trailers))
  if include_xref_stream_trailers && self.is_encrypted() {
    self.load_reconstructed_xref_stream_embedded_objects_with_passwords(
      @reader.pdf_reader_reconstruction_xref_stream_entries(
        plan.xref_stream_sections,
      ),
      user_password,
      owner_password,
    )
  }
  self.sanitize_reader_trailer()
}
