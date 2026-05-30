///|
fn pdf_portfolio_stream(
  entry : @portfolio.PdfPortfolioEntry,
  mod_date : PdfBytes,
) -> @syntax.PdfObject {
  @syntax.pdf_stream(
    PdfDictionary([
      (
        pdf_portfolio_params_key(),
        PdfDictionary([
          (pdf_portfolio_mod_date_key(), PdfString(mod_date)),
          (pdf_portfolio_size_key(), PdfInteger(entry.data.length())),
        ]),
      ),
      (pdf_portfolio_length_key(), PdfInteger(entry.data.length())),
    ]),
    StreamGot(entry.data),
  )
}

///|
fn PdfDocument::pdf_portfolio_file_spec(
  self : PdfDocument,
  entry : @portfolio.PdfPortfolioEntry,
  mod_date : PdfBytes,
) -> @syntax.PdfObject {
  let basename = pdf_portfolio_basename(entry.filename)
  let basename_bytes = @utf8.encode(basename)
  let contents = self.add_object(pdf_portfolio_stream(entry, mod_date))
  PdfDictionary([
    (pdf_portfolio_type_key(), PdfNameObject(pdf_portfolio_file_spec())),
    (
      pdf_portfolio_desc_key(),
      PdfString(@utf8.encode(pdf_portfolio_description(entry, basename))),
    ),
    (pdf_portfolio_f_key(), PdfString(basename_bytes)),
    (pdf_portfolio_uf_key(), PdfString(basename_bytes)),
    (
      pdf_portfolio_af_relationship_key(),
      PdfNameObject(pdf_portfolio_relationship_name(entry.relationship)),
    ),
    (
      pdf_portfolio_ef_key(),
      PdfDictionary([
        (pdf_portfolio_f_key(), PdfIndirect(contents)),
        (pdf_portfolio_uf_key(), PdfIndirect(contents)),
      ]),
    ),
  ])
}

///|
fn PdfDocument::pdf_portfolio_name_tree_entries(
  self : PdfDocument,
  entries : ArrayView[@portfolio.PdfPortfolioEntry],
  mod_date : PdfBytes,
) -> Array[(PdfBytes, @syntax.PdfObject)] {
  [
    for index, entry in entries => {
      let key = @utf8.encode(index.to_string() + "/" + entry.filename)
      let file_spec = self.add_object(
        self.pdf_portfolio_file_spec(entry, mod_date),
      )
      (key, PdfIndirect(file_spec))
    }
  ]
}

///|
fn pdf_portfolio_collection() -> @syntax.PdfObject {
  PdfDictionary([
    (pdf_portfolio_view_key(), PdfNameObject(pdf_portfolio_table_view())),
  ])
}
