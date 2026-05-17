///|
fn pdf_portfolio_name(text : String) -> PdfName {
  pdf_name_of_bytes(@ascii.encode(text))
}

///|
let pdf_portfolio_root_key_name : PdfName = pdf_portfolio_name("/Root")

///|
fn pdf_portfolio_root_key() -> PdfName {
  pdf_portfolio_root_key_name
}

///|
let pdf_portfolio_names_key_name : PdfName = pdf_portfolio_name("/Names")

///|
fn pdf_portfolio_names_key() -> PdfName {
  pdf_portfolio_names_key_name
}

///|
let pdf_portfolio_embedded_files_key_name : PdfName = pdf_portfolio_name(
  "/EmbeddedFiles",
)

///|
fn pdf_portfolio_embedded_files_key() -> PdfName {
  pdf_portfolio_embedded_files_key_name
}

///|
let pdf_portfolio_collection_key_name : PdfName = pdf_portfolio_name(
  "/Collection",
)

///|
fn pdf_portfolio_collection_key() -> PdfName {
  pdf_portfolio_collection_key_name
}

///|
let pdf_portfolio_view_key_name : PdfName = pdf_portfolio_name("/View")

///|
fn pdf_portfolio_view_key() -> PdfName {
  pdf_portfolio_view_key_name
}

///|
let pdf_portfolio_table_view_name : PdfName = pdf_portfolio_name("/T")

///|
fn pdf_portfolio_table_view() -> PdfName {
  pdf_portfolio_table_view_name
}

///|
let pdf_portfolio_params_key_name : PdfName = pdf_portfolio_name("/Params")

///|
fn pdf_portfolio_params_key() -> PdfName {
  pdf_portfolio_params_key_name
}

///|
let pdf_portfolio_mod_date_key_name : PdfName = pdf_portfolio_name("/ModDate")

///|
fn pdf_portfolio_mod_date_key() -> PdfName {
  pdf_portfolio_mod_date_key_name
}

///|
let pdf_portfolio_size_key_name : PdfName = pdf_portfolio_name("/Size")

///|
fn pdf_portfolio_size_key() -> PdfName {
  pdf_portfolio_size_key_name
}

///|
let pdf_portfolio_length_key_name : PdfName = pdf_portfolio_name("/Length")

///|
fn pdf_portfolio_length_key() -> PdfName {
  pdf_portfolio_length_key_name
}

///|
let pdf_portfolio_type_key_name : PdfName = pdf_portfolio_name("/Type")

///|
fn pdf_portfolio_type_key() -> PdfName {
  pdf_portfolio_type_key_name
}

///|
let pdf_portfolio_file_spec_name : PdfName = pdf_portfolio_name("/FileSpec")

///|
fn pdf_portfolio_file_spec() -> PdfName {
  pdf_portfolio_file_spec_name
}

///|
let pdf_portfolio_desc_key_name : PdfName = pdf_portfolio_name("/Desc")

///|
fn pdf_portfolio_desc_key() -> PdfName {
  pdf_portfolio_desc_key_name
}

///|
let pdf_portfolio_f_key_name : PdfName = pdf_portfolio_name("/F")

///|
fn pdf_portfolio_f_key() -> PdfName {
  pdf_portfolio_f_key_name
}

///|
let pdf_portfolio_uf_key_name : PdfName = pdf_portfolio_name("/UF")

///|
fn pdf_portfolio_uf_key() -> PdfName {
  pdf_portfolio_uf_key_name
}

///|
let pdf_portfolio_af_relationship_key_name : PdfName = pdf_portfolio_name(
  "/AFRelationship",
)

///|
fn pdf_portfolio_af_relationship_key() -> PdfName {
  pdf_portfolio_af_relationship_key_name
}

///|
let pdf_portfolio_ef_key_name : PdfName = pdf_portfolio_name("/EF")

///|
fn pdf_portfolio_ef_key() -> PdfName {
  pdf_portfolio_ef_key_name
}

///|
let pdf_portfolio_unspecified_relationship_name : PdfName = pdf_portfolio_name(
  "/Unspecified",
)

///|
fn pdf_portfolio_unspecified_relationship() -> PdfName {
  pdf_portfolio_unspecified_relationship_name
}

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

///|
fn pdf_portfolio_is_path_separator(code_unit : UInt16) -> Bool {
  let value = code_unit.to_int()
  value == 47 || value == 92
}

///|
fn pdf_portfolio_basename(path : String) -> String {
  let mut start = 0
  for index in 0..<path.length() {
    if pdf_portfolio_is_path_separator(path.at(index)) {
      start = index + 1
    }
  }
  path[start:].to_owned()
}

///|
fn pdf_portfolio_relationship_name(relationship : String?) -> PdfName {
  match relationship {
    Some(text) => pdf_portfolio_name("/" + text)
    None => pdf_portfolio_unspecified_relationship()
  }
}

///|
fn pdf_portfolio_description(
  entry : PdfPortfolioEntry,
  basename : String,
) -> String {
  match entry.description {
    Some(description) => description
    None => basename
  }
}

///|
fn pdf_portfolio_pad2(value : Int) -> String {
  if value < 10 {
    "0" + value.to_string()
  } else {
    value.to_string()
  }
}

///|
fn pdf_portfolio_pad4(value : Int) -> String {
  if value < 10 {
    "000" + value.to_string()
  } else if value < 100 {
    "00" + value.to_string()
  } else if value < 1000 {
    "0" + value.to_string()
  } else {
    value.to_string()
  }
}

///|
fn pdf_portfolio_is_leap_year(year : Int) -> Bool {
  (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
}

///|
fn pdf_portfolio_days_in_month(year : Int, month : Int) -> Int {
  match month {
    1 | 3 | 5 | 7 | 8 | 10 | 12 => 31
    4 | 6 | 9 | 11 => 30
    2 => if pdf_portfolio_is_leap_year(year) { 29 } else { 28 }
    _ => 30
  }
}

///|
fn pdf_portfolio_date_text_from_unix_millis(milliseconds : UInt64) -> String {
  let total_seconds = (milliseconds / (1000 : UInt64)).reinterpret_as_int64()
  let mut days = (total_seconds / 86400L).to_int()
  let seconds_of_day = (total_seconds % 86400L).to_int()
  let hour = seconds_of_day / 3600
  let minute = seconds_of_day % 3600 / 60
  let second = seconds_of_day % 60
  let mut year = 1970
  let mut year_days = if pdf_portfolio_is_leap_year(year) { 366 } else { 365 }
  while days >= year_days {
    days -= year_days
    year += 1
    year_days = if pdf_portfolio_is_leap_year(year) { 366 } else { 365 }
  }
  let mut month = 1
  while days >= pdf_portfolio_days_in_month(year, month) {
    days -= pdf_portfolio_days_in_month(year, month)
    month += 1
  }
  let day = days + 1
  "D:" +
  pdf_portfolio_pad4(year) +
  pdf_portfolio_pad2(month) +
  pdf_portfolio_pad2(day) +
  pdf_portfolio_pad2(hour) +
  pdf_portfolio_pad2(minute) +
  pdf_portfolio_pad2(second)
}

///|
fn pdf_portfolio_current_mod_date() -> PdfBytes {
  let text = match @env.get_env_var("CPDF_REPRODUCIBLE_DATES") {
    Some("true") =>
      pdf_strftime_with_time(pdf_strftime_dummy_time(), "D:%Y%m%d%H%M%S")
    _ => pdf_portfolio_date_text_from_unix_millis(@env.now())
  }
  @ascii.encode(text)
}

///|
fn pdf_portfolio_stream(
  entry : PdfPortfolioEntry,
  mod_date : PdfBytes,
) -> PdfObject {
  pdf_stream(
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
  entry : PdfPortfolioEntry,
  mod_date : PdfBytes,
) -> PdfObject {
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
  entries : ArrayView[PdfPortfolioEntry],
  mod_date : PdfBytes,
) -> Array[(PdfBytes, PdfObject)] {
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
fn pdf_portfolio_collection() -> PdfObject {
  PdfDictionary([
    (pdf_portfolio_view_key(), PdfNameObject(pdf_portfolio_table_view())),
  ])
}

///|
/// Build a PDF portfolio, also known as a PDF collection.
///
/// The original document is left unchanged. `mod_date` can be supplied for
/// deterministic output; otherwise the current cpdf-style date is used.
pub fn PdfDocument::portfolio(
  self : PdfDocument,
  entries : ArrayView[PdfPortfolioEntry],
  mod_date? : PdfBytes? = None,
) -> PdfDocument raise PdfError {
  ignore(self.catalog())
  let document = self.copy()
  let resolved_mod_date = match mod_date {
    Some(date) => date
    None => pdf_portfolio_current_mod_date()
  }
  let embedded_files = PdfIndirect(
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
  entries : ArrayView[PdfPortfolioEntry],
  mod_date? : PdfBytes? = None,
) -> PdfDocument raise PdfError {
  document.portfolio(entries, mod_date~)
}
