///|
/// Construct a filesystem-backed portfolio entry.
pub fn pdf_portfolio_file_entry(
  filename : String,
  relationship? : String? = None,
  description? : String? = None,
) -> PdfPortfolioFileEntry {
  { filename, relationship, description }
}

///|
/// Read files from disk and build a PDF portfolio.
///
/// PDF object construction is delegated to the core `PdfDocument::portfolio`
/// API; this package only owns the native filesystem reads.
pub async fn pdf_portfolio_from_files(
  document : @pdflite.PdfDocument,
  entries : ArrayView[PdfPortfolioFileEntry],
  mod_date? : @pdflite.PdfBytes? = None,
) -> @pdflite.PdfDocument {
  let loaded : Array[@pdflite.PdfPortfolioEntry] = []
  for entry in entries {
    loaded.push(
      @pdflite.pdf_portfolio_entry(
        entry.filename,
        @fs.read_file(entry.filename).binary(),
        relationship=entry.relationship,
        description=entry.description,
      ),
    )
  }
  @pdflite.pdf_portfolio(document, loaded, mod_date~)
}
