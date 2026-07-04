///|
/// One file to embed in a PDF portfolio.
///
/// `filename` is used for the portfolio name-tree key and its basename is used
/// for the file specification names. `data` is the raw embedded-file payload.
pub(all) struct PdfPortfolioEntry {
  filename : String
  data : PdfBytes
  relationship : String?
  description : String?
} derive(Debug, Eq, ToJson)

///|
/// Construct a portfolio entry, copying the supplied data view.
pub fn pdf_portfolio_entry(
  filename : String,
  data : BytesView,
  relationship? : String? = None,
  description? : String? = None,
) -> PdfPortfolioEntry {
  { filename, data: data.to_owned(), relationship, description }
}
