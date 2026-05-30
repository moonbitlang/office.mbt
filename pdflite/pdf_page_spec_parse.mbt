///|
priv struct PdfDocumentPageSpecContext {
  end_page : Int
  document : PdfDocument
  source : String
}

///|
fn PdfDocumentPageSpecContext::bad(
  self : PdfDocumentPageSpecContext,
) -> Unit raise @core.PdfError {
  raise BadPageSpecification(self.source)
}

///|
fn PdfDocumentPageSpecContext::selectors(
  self : PdfDocumentPageSpecContext,
) -> @spec.PdfPageSpecSelectors {
  {
    resolve_references: spec => self.resolve_page_labels(spec),
    select_dimensions: (candidates, portrait) => {
      self.select_dimensions(candidates, portrait)
    },
    select_annotated: candidates => self.select_annotated(candidates),
  }
}

///|
/// Parse a cpdf page specification against this document.
pub fn PdfDocument::parse_pagespec(
  self : PdfDocument,
  spec : String,
) -> Array[Int] raise @core.PdfError {
  let end_page = self.endpage()
  let context = { end_page, document: self, source: spec }
  @spec.pdf_parse_pagespec_with_selectors(
    end_page,
    spec,
    Some(context.selectors()),
  )
}

///|
/// Source-spelled wrapper for `PdfDocument::parse_pagespec`.
pub fn pdf_parse_pagespec(
  document : PdfDocument,
  spec : String,
) -> Array[Int] raise @core.PdfError {
  document.parse_pagespec(spec)
}
