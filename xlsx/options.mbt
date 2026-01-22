///|
let default_unzip_size_limit : Int = 1000 << 24

///|
let default_unzip_xml_size_limit : Int = 1 << 24

///|
pub struct Options {
  max_calc_iterations : UInt
  password : String
  raw_cell_value : Bool
  unzip_size_limit : Int
  unzip_xml_size_limit : Int
  tmp_dir : String
  short_date_pattern : String
  long_date_pattern : String
  long_time_pattern : String
  culture_info : String
} derive(Eq, Show)

///|
pub fn Options::new() -> Options {
  {
    max_calc_iterations: 0,
    password: "",
    raw_cell_value: false,
    unzip_size_limit: 0,
    unzip_xml_size_limit: 0,
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
  unzip_size_limit? : Int = 0,
  unzip_xml_size_limit? : Int = 0,
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
    unzip_size_limit,
    unzip_xml_size_limit,
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
      unzip_size_limit=options.unzip_size_limit,
      unzip_xml_size_limit=options.unzip_xml_size_limit,
      tmp_dir=options.tmp_dir,
      short_date_pattern=options.short_date_pattern,
      long_date_pattern=options.long_date_pattern,
      long_time_pattern=options.long_time_pattern,
      culture_info=options.culture_info,
    )
  }
}

///|
fn normalize_unzip_limits(options : Options) -> Options raise XlsxError {
  let mut unzip_size_limit = options.unzip_size_limit
  let mut unzip_xml_size_limit = options.unzip_xml_size_limit
  if unzip_size_limit <= 0 {
    unzip_size_limit = default_unzip_size_limit
    if unzip_xml_size_limit > unzip_size_limit {
      unzip_size_limit = unzip_xml_size_limit
    }
  }
  if unzip_xml_size_limit <= 0 {
    unzip_xml_size_limit = default_unzip_xml_size_limit
    if unzip_size_limit < unzip_xml_size_limit {
      unzip_xml_size_limit = unzip_size_limit
    }
  }
  if unzip_xml_size_limit > unzip_size_limit {
    raise XlsxError::InvalidOptions(
      msg="unzip xml size limit exceeds total unzip limit",
    )
  }
  Options::with_values(
    max_calc_iterations=options.max_calc_iterations,
    password=options.password,
    raw_cell_value=options.raw_cell_value,
    unzip_size_limit~,
    unzip_xml_size_limit~,
    tmp_dir=options.tmp_dir,
    short_date_pattern=options.short_date_pattern,
    long_date_pattern=options.long_date_pattern,
    long_time_pattern=options.long_time_pattern,
    culture_info=options.culture_info,
  )
}
