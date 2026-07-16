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
/// A complete fail-closed resource policy for reading an XLSX package.
///
/// The type is opaque so every public read path receives a validated,
/// internally consistent policy. ZIP limits are enforced while inflating;
/// `max_xml_part_bytes` is enforced before any individual XML part is decoded.
pub struct ReadLimits {
  priv max_package_bytes : Int
  priv max_archive_entries : Int
  priv max_entry_uncompressed_bytes : Int
  priv max_total_uncompressed_bytes : Int
  priv max_total_preserved_source_bytes : Int
  priv max_xml_part_bytes : Int
}

///|
/// Returns the production XLSX read policy: 128 MiB source packages, 8,192
/// entries, 64 MiB per entry, 256 MiB aggregate expansion, and 16 MiB per XML
/// part. Call `with_values` when a stricter boundary is required.
pub fn ReadLimits::new() -> ReadLimits {
  {
    max_package_bytes: default_max_package_bytes,
    max_archive_entries: default_max_archive_entries,
    max_entry_uncompressed_bytes: default_max_entry_uncompressed_bytes,
    max_total_uncompressed_bytes: default_max_total_uncompressed_bytes,
    max_total_preserved_source_bytes: default_max_total_preserved_source_bytes,
    max_xml_part_bytes: default_max_xml_part_bytes,
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
) -> ReadLimits raise XlsxError {
  if max_package_bytes <= 0 ||
    max_archive_entries <= 0 ||
    max_entry_uncompressed_bytes <= 0 ||
    max_total_uncompressed_bytes <= 0 ||
    max_total_preserved_source_bytes <= 0 ||
    max_xml_part_bytes <= 0 {
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
