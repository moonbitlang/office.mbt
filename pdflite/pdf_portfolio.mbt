///|
/// Build a PDF portfolio, also known as a PDF collection.
///
/// The original document is left unchanged. `mod_date` can be supplied for
/// deterministic output; otherwise the current cpdf-style date is used.
pub fn PdfDocument::portfolio(
  self : PdfDocument,
  entries : ArrayView[@portfolio.PdfPortfolioEntry],
  mod_date? : @core.PdfBytes? = None,
) -> PdfDocument raise @core.PdfError {
  ignore(self.catalog())
  let document = self.copy()
  let resolved_mod_date = match mod_date {
    Some(date) => date
    None => pdf_portfolio_current_mod_date()
  }
  let embedded_files = @syntax.PdfIndirect(
    document.add_object(
      document.build_name_tree(
        document.pdf_portfolio_name_tree_entries(entries, resolved_mod_date),
      ),
    ),
  )
  document.replace_chain(
    [
      pdf_portfolio_root_key(),
      pdf_portfolio_names_key(),
      pdf_portfolio_embedded_files_key(),
    ],
    embedded_files,
  )
  document.replace_chain(
    [pdf_portfolio_root_key(), pdf_portfolio_collection_key()],
    pdf_portfolio_collection(),
  )
  document
}

///|
/// Compatibility wrapper for `PdfDocument::portfolio`.
pub fn pdf_portfolio(
  document : PdfDocument,
  entries : ArrayView[@portfolio.PdfPortfolioEntry],
  mod_date? : @core.PdfBytes? = None,
) -> PdfDocument raise @core.PdfError {
  document.portfolio(entries, mod_date~)
}
