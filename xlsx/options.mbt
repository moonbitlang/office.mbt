///|
let default_max_package_bytes : Int = 128 * 1024 * 1024

///|
let default_max_archive_entries : Int = 8192

///|
let default_max_entry_uncompressed_bytes : Int = 64 * 1024 * 1024

///|
let default_max_total_uncompressed_bytes : Int = 256 * 1024 * 1024

///|
let default_max_total_preserved_source_bytes : Int = default_max_package_bytes +
  65_535

///|
let default_max_xml_part_bytes : Int = 16 * 1024 * 1024

///|
let default_max_total_xml_bytes : Int = 128 * 1024 * 1024

///|
let default_max_xml_markup_tokens : Int = 2_000_000

///|
let default_max_materialized_cells : Int = 1_000_000

///|
let default_max_materialized_row_column_dimensions : Int = 1_000_000

///|
let default_max_kdf_iterations : Int = 1_000_000

///|
let default_max_workbook_sheets : Int = 1024

///|
let default_max_parser_items : Int = 2_000_000

///|
let default_max_parser_work_units : Int = 512 * 1024 * 1024

///|
/// A complete fail-closed resource policy for reading an XLSX package.
///
/// The type is opaque so every public read path receives a validated,
/// internally consistent policy. ZIP limits are enforced while inflating;
/// `max_xml_part_bytes` is enforced before any individual XML part is decoded,
/// aggregate decoded XML, markup tokens, materialized worksheet cells, and
/// retained row/column dimensions are bounded across the complete workbook
/// parse. Semantic ceilings also bound workbook fan-out, XML-backed parser
/// items, derived materialization, and cumulative parser work;
/// `max_kdf_iterations` bounds encrypted-package password derivation.
pub struct ReadLimits {
  priv max_package_bytes : Int
  priv max_archive_entries : Int
  priv max_entry_uncompressed_bytes : Int
  priv max_total_uncompressed_bytes : Int
  priv max_total_preserved_source_bytes : Int
  priv max_xml_part_bytes : Int
  priv max_total_xml_bytes : Int
  priv max_xml_markup_tokens : Int
  priv max_materialized_cells : Int
  priv max_materialized_row_column_dimensions : Int
  priv max_kdf_iterations : Int
  priv max_workbook_sheets : Int
  priv max_parser_items : Int
  priv max_parser_work_units : Int
}

///|
/// Returns the production XLSX read policy: 128 MiB source packages, 8,192
/// entries, 64 MiB per entry, 256 MiB aggregate expansion, 16 MiB per XML part,
/// 128 MiB decoded XML, two million markup tokens, one million materialized
/// cells, one million retained row/column dimensions, 1,024 sheets, two million
/// parser items, 512 Mi parser work units, and one million Agile KDF iterations.
/// Call `with_values` for stricter limits.
pub fn ReadLimits::new() -> ReadLimits {
  {
    max_package_bytes: default_max_package_bytes,
    max_archive_entries: default_max_archive_entries,
    max_entry_uncompressed_bytes: default_max_entry_uncompressed_bytes,
    max_total_uncompressed_bytes: default_max_total_uncompressed_bytes,
    max_total_preserved_source_bytes: default_max_total_preserved_source_bytes,
    max_xml_part_bytes: default_max_xml_part_bytes,
    max_total_xml_bytes: default_max_total_xml_bytes,
    max_xml_markup_tokens: default_max_xml_markup_tokens,
    max_materialized_cells: default_max_materialized_cells,
    max_materialized_row_column_dimensions: default_max_materialized_row_column_dimensions,
    max_kdf_iterations: default_max_kdf_iterations,
    max_workbook_sheets: default_max_workbook_sheets,
    max_parser_items: default_max_parser_items,
    max_parser_work_units: default_max_parser_work_units,
  }
}

///|
/// Builds a validated XLSX read policy. All ceilings must be positive; the
/// per-entry and per-XML ceilings cannot exceed the aggregate expansion limit.
pub fn ReadLimits::with_values(
  max_package_bytes? : Int = default_max_package_bytes,
  max_archive_entries? : Int = default_max_archive_entries,
  max_entry_uncompressed_bytes? : Int = default_max_entry_uncompressed_bytes,
  max_total_uncompressed_bytes? : Int = default_max_total_uncompressed_bytes,
  max_total_preserved_source_bytes? : Int = default_max_total_preserved_source_bytes,
  max_xml_part_bytes? : Int = default_max_xml_part_bytes,
  max_total_xml_bytes? : Int = default_max_total_xml_bytes,
  max_xml_markup_tokens? : Int = default_max_xml_markup_tokens,
  max_materialized_cells? : Int = default_max_materialized_cells,
  max_materialized_row_column_dimensions? : Int = default_max_materialized_row_column_dimensions,
  max_kdf_iterations? : Int = default_max_kdf_iterations,
  max_workbook_sheets? : Int = default_max_workbook_sheets,
  max_parser_items? : Int = default_max_parser_items,
  max_parser_work_units? : Int = default_max_parser_work_units,
) -> ReadLimits raise XlsxError {
  if max_package_bytes <= 0 ||
    max_archive_entries <= 0 ||
    max_entry_uncompressed_bytes <= 0 ||
    max_total_uncompressed_bytes <= 0 ||
    max_total_preserved_source_bytes <= 0 ||
    max_xml_part_bytes <= 0 ||
    max_total_xml_bytes <= 0 ||
    max_xml_markup_tokens <= 0 ||
    max_materialized_cells <= 0 ||
    max_materialized_row_column_dimensions <= 0 ||
    max_kdf_iterations <= 0 ||
    max_workbook_sheets <= 0 ||
    max_parser_items <= 0 ||
    max_parser_work_units <= 0 {
    raise InvalidOptions(msg="XLSX read limits must be positive")
  }
  if max_entry_uncompressed_bytes > max_total_uncompressed_bytes {
    raise InvalidOptions(
      msg="XLSX entry limit exceeds aggregate uncompressed limit",
    )
  }
  if max_xml_part_bytes > max_entry_uncompressed_bytes {
    raise InvalidOptions(msg="XLSX XML limit exceeds entry limit")
  }
  {
    max_package_bytes,
    max_archive_entries,
    max_entry_uncompressed_bytes,
    max_total_uncompressed_bytes,
    max_total_preserved_source_bytes,
    max_xml_part_bytes,
    max_total_xml_bytes,
    max_xml_markup_tokens,
    max_materialized_cells,
    max_materialized_row_column_dimensions,
    max_kdf_iterations,
    max_workbook_sheets,
    max_parser_items,
    max_parser_work_units,
  }
}

///|
/// Returns the maximum accepted compressed XLSX package size in bytes.
pub fn ReadLimits::max_package_bytes(self : ReadLimits) -> Int {
  self.max_package_bytes
}

///|
/// Returns the maximum number of ZIP entries accepted in one package.
pub fn ReadLimits::max_archive_entries(self : ReadLimits) -> Int {
  self.max_archive_entries
}

///|
/// Returns the maximum inflated size of one ZIP entry in bytes.
pub fn ReadLimits::max_entry_uncompressed_bytes(self : ReadLimits) -> Int {
  self.max_entry_uncompressed_bytes
}

///|
/// Returns the maximum aggregate inflated size of all ZIP entries in bytes.
pub fn ReadLimits::max_total_uncompressed_bytes(self : ReadLimits) -> Int {
  self.max_total_uncompressed_bytes
}

///|
/// Returns the maximum aggregate compressed source bytes a bounded archive may
/// preserve for lossless republishing.
pub fn ReadLimits::max_total_preserved_source_bytes(self : ReadLimits) -> Int {
  self.max_total_preserved_source_bytes
}

///|
/// Returns the maximum size of one XML-like OOXML part in bytes.
pub fn ReadLimits::max_xml_part_bytes(self : ReadLimits) -> Int {
  self.max_xml_part_bytes
}

///|
/// Returns the maximum aggregate XML-like bytes decoded during one read.
pub fn ReadLimits::max_total_xml_bytes(self : ReadLimits) -> Int {
  self.max_total_xml_bytes
}

///|
/// Returns the maximum aggregate markup-token starts scanned while decoding.
pub fn ReadLimits::max_xml_markup_tokens(self : ReadLimits) -> Int {
  self.max_xml_markup_tokens
}

///|
/// Returns the maximum worksheet cells materialized across the workbook.
pub fn ReadLimits::max_materialized_cells(self : ReadLimits) -> Int {
  self.max_materialized_cells
}

///|
/// Returns the maximum retained row/column dimensions across the workbook.
pub fn ReadLimits::max_materialized_row_column_dimensions(
  self : ReadLimits,
) -> Int {
  self.max_materialized_row_column_dimensions
}

///|
/// Returns the maximum accepted Agile password-KDF work factor.
pub fn ReadLimits::max_kdf_iterations(self : ReadLimits) -> Int {
  self.max_kdf_iterations
}

///|
/// Returns the maximum number of logical sheets accepted in one workbook.
pub fn ReadLimits::max_workbook_sheets(self : ReadLimits) -> Int {
  self.max_workbook_sheets
}

///|
/// Returns the maximum cumulative XML-backed and derived items that a read may
/// inspect or materialize.
pub fn ReadLimits::max_parser_items(self : ReadLimits) -> Int {
  self.max_parser_items
}

///|
/// Returns the maximum cumulative XML source units plus derived expansion work
/// accepted by the parser.
pub fn ReadLimits::max_parser_work_units(self : ReadLimits) -> Int {
  self.max_parser_work_units
}

///|
/// A fail-closed resource policy for XLSX serialization. The archive ceilings
/// are enforced before each generated part is retained; `max_output_bytes` is
/// then enforced by ZIP's storage-free sizing pass before package allocation.
pub struct WriteLimits {
  priv max_output_bytes : Int
  priv max_archive_entries : Int
  priv max_entry_uncompressed_bytes : Int
  priv max_total_uncompressed_bytes : Int
}

///|
/// Builds a validated XLSX write policy. All ceilings must be positive and the
/// per-entry expansion ceiling cannot exceed the aggregate archive ceiling.
pub fn WriteLimits::with_values(
  max_output_bytes~ : Int,
  max_archive_entries~ : Int,
  max_entry_uncompressed_bytes~ : Int,
  max_total_uncompressed_bytes~ : Int,
) -> WriteLimits raise XlsxError {
  if max_output_bytes <= 0 ||
    max_archive_entries <= 0 ||
    max_entry_uncompressed_bytes <= 0 ||
    max_total_uncompressed_bytes <= 0 {
    raise InvalidOptions(msg="XLSX write limits must be positive")
  }
  if max_entry_uncompressed_bytes > max_total_uncompressed_bytes {
    raise InvalidOptions(
      msg="XLSX write entry limit exceeds aggregate uncompressed limit",
    )
  }
  {
    max_output_bytes,
    max_archive_entries,
    max_entry_uncompressed_bytes,
    max_total_uncompressed_bytes,
  }
}

///|
pub fn WriteLimits::max_output_bytes(self : WriteLimits) -> Int {
  self.max_output_bytes
}

///|
pub fn WriteLimits::max_archive_entries(self : WriteLimits) -> Int {
  self.max_archive_entries
}

///|
pub fn WriteLimits::max_entry_uncompressed_bytes(self : WriteLimits) -> Int {
  self.max_entry_uncompressed_bytes
}

///|
pub fn WriteLimits::max_total_uncompressed_bytes(self : WriteLimits) -> Int {
  self.max_total_uncompressed_bytes
}

///|
pub struct Options {
  max_calc_iterations : UInt
  password : String
  raw_cell_value : Bool
  tmp_dir : String
  short_date_pattern : String
  long_date_pattern : String
  long_time_pattern : String
  culture_info : String
} derive(Debug)

///|
pub fn Options::new() -> Options {
  {
    max_calc_iterations: 0,
    password: "",
    raw_cell_value: false,
    tmp_dir: "",
    short_date_pattern: "",
    long_date_pattern: "",
    long_time_pattern: "",
    culture_info: "",
  }
}

///|
pub fn Options::with_values(
  max_calc_iterations? : UInt = 0,
  password? : String = "",
  raw_cell_value? : Bool = false,
  tmp_dir? : String = "",
  short_date_pattern? : String = "",
  long_date_pattern? : String = "",
  long_time_pattern? : String = "",
  culture_info? : String = "",
) -> Options {
  {
    max_calc_iterations,
    password,
    raw_cell_value,
    tmp_dir,
    short_date_pattern,
    long_date_pattern,
    long_time_pattern,
    culture_info,
  }
}

///|
fn options_with_password(options : Options, password : String) -> Options {
  if password == "" || options.password == password {
    options
  } else {
    Options::with_values(
      max_calc_iterations=options.max_calc_iterations,
      password~,
      raw_cell_value=options.raw_cell_value,
      tmp_dir=options.tmp_dir,
      short_date_pattern=options.short_date_pattern,
      long_date_pattern=options.long_date_pattern,
      long_time_pattern=options.long_time_pattern,
      culture_info=options.culture_info,
    )
  }
}
