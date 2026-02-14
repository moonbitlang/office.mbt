///|
pub struct CalcPropsOptions {
  mut calc_id : UInt?
  mut calc_mode : String?
  mut full_calc_on_load : Bool?
  mut ref_mode : String?
  mut iterate : Bool?
  mut iterate_count : UInt?
  mut iterate_delta : Double?
  mut full_precision : Bool?
  mut calc_completed : Bool?
  mut calc_on_save : Bool?
  mut concurrent_calc : Bool?
  mut concurrent_manual_count : UInt?
  mut force_full_calc : Bool?
} derive(Eq, Show)

///|
pub fn CalcPropsOptions::new() -> CalcPropsOptions {
  {
    calc_id: None,
    calc_mode: None,
    full_calc_on_load: None,
    ref_mode: None,
    iterate: None,
    iterate_count: None,
    iterate_delta: None,
    full_precision: None,
    calc_completed: None,
    calc_on_save: None,
    concurrent_calc: None,
    concurrent_manual_count: None,
    force_full_calc: None,
  }
}

///|
pub fn CalcPropsOptions::with_values(
  calc_id? : UInt,
  calc_mode? : String,
  full_calc_on_load? : Bool,
  ref_mode? : String,
  iterate? : Bool,
  iterate_count? : UInt,
  iterate_delta? : Double,
  full_precision? : Bool,
  calc_completed? : Bool,
  calc_on_save? : Bool,
  concurrent_calc? : Bool,
  concurrent_manual_count? : UInt,
  force_full_calc? : Bool,
) -> CalcPropsOptions {
  {
    calc_id,
    calc_mode,
    full_calc_on_load,
    ref_mode,
    iterate,
    iterate_count,
    iterate_delta,
    full_precision,
    calc_completed,
    calc_on_save,
    concurrent_calc,
    concurrent_manual_count,
    force_full_calc,
  }
}

///|
pub struct WorkbookPropsOptions {
  mut date_1904 : Bool?
  mut filter_privacy : Bool?
  mut code_name : String?
} derive(Show)

///|
fn WorkbookPropsOptions::new() -> WorkbookPropsOptions {
  { date_1904: None, filter_privacy: None, code_name: None }
}

///|
pub fn WorkbookPropsOptions::with_values(
  date_1904? : Bool,
  filter_privacy? : Bool,
  code_name? : String,
) -> WorkbookPropsOptions {
  { date_1904, filter_privacy, code_name }
}

///|
pub(all) enum CustomPropertyValue {
  Integer(Int)
  Float(Double)
  Boolean(Bool)
  Text(String)
  DateTime(String)
} derive(Show)

///|
pub struct CustomProperty {
  name : String
  value : CustomPropertyValue?
} derive(Show)

///|
pub fn CustomProperty::new(
  name : String,
  value : CustomPropertyValue?,
) -> CustomProperty {
  { name, value }
}

///|
pub struct WorkbookProtectionOptions {
  algorithm_name : String
  password : String
  lock_structure : Bool
  lock_windows : Bool
} derive(Show)

///|
fn WorkbookProtectionOptions::new() -> WorkbookProtectionOptions {
  {
    algorithm_name: "",
    password: "",
    lock_structure: false,
    lock_windows: false,
  }
}

///|
pub fn WorkbookProtectionOptions::with_values(
  algorithm_name? : String = "",
  password? : String = "",
  lock_structure? : Bool = false,
  lock_windows? : Bool = false,
) -> WorkbookProtectionOptions {
  { algorithm_name, password, lock_structure, lock_windows }
}

///|
struct WorkbookProtection {
  mut lock_structure : Bool
  mut lock_windows : Bool
  mut algorithm_name : String
  mut hash_value : String
  mut salt_value : String
  mut spin_count : Int
} derive(Show)

///|
let workbook_protection_spin_count = 100000

///|
fn calc_props_is_empty(options : CalcPropsOptions) -> Bool {
  options.calc_id is None &&
  options.calc_mode is None &&
  options.full_calc_on_load is None &&
  options.ref_mode is None &&
  options.iterate is None &&
  options.iterate_count is None &&
  options.iterate_delta is None &&
  options.full_precision is None &&
  options.calc_completed is None &&
  options.calc_on_save is None &&
  options.concurrent_calc is None &&
  options.concurrent_manual_count is None &&
  options.force_full_calc is None
}

///|
fn workbook_props_is_empty(options : WorkbookPropsOptions) -> Bool {
  options.date_1904 is None &&
  options.filter_privacy is None &&
  options.code_name is None
}

///|
fn normalize_calc_mode(mode : StringView) -> String? {
  match mode.to_string().to_lower() {
    "manual" => Some("manual")
    "auto" => Some("auto")
    "autonotable" => Some("autoNoTable")
    _ => None
  }
}

///|
fn normalize_ref_mode(mode : StringView) -> String? {
  match mode.to_string().to_upper() {
    "A1" => Some("A1")
    "R1C1" => Some("R1C1")
    _ => None
  }
}

///|
fn normalize_calc_props(
  options : CalcPropsOptions,
) -> CalcPropsOptions raise XlsxError {
  let normalized = options
  match options.calc_mode {
    None => ()
    Some(value) =>
      match normalize_calc_mode(value) {
        Some(result) => normalized.calc_mode = Some(result)
        None => raise InvalidWorkbookProperty(msg="invalid calc mode")
      }
  }
  match options.ref_mode {
    None => ()
    Some(value) =>
      match normalize_ref_mode(value) {
        Some(result) => normalized.ref_mode = Some(result)
        None => raise InvalidWorkbookProperty(msg="invalid reference mode")
      }
  }
  normalized
}

///|
fn workbook_protection_from_options(
  options : WorkbookProtectionOptions,
) -> WorkbookProtection raise XlsxError {
  let protection : WorkbookProtection = {
    lock_structure: options.lock_structure,
    lock_windows: options.lock_windows,
    algorithm_name: "",
    hash_value: "",
    salt_value: "",
    spin_count: 0,
  }
  if options.password != "" {
    let algorithm = if options.algorithm_name == "" {
      "SHA-512"
    } else {
      options.algorithm_name
    }
    let (hash_value, salt_value) = gen_iso_password_hash(
      options.password,
      algorithm,
      "",
      workbook_protection_spin_count,
    )
    protection.algorithm_name = algorithm
    protection.hash_value = hash_value
    protection.salt_value = salt_value
    protection.spin_count = workbook_protection_spin_count
  }
  protection
}

///|
fn verify_workbook_protection_password(
  protection : WorkbookProtection,
  password : StringView,
) -> Unit raise XlsxError {
  if protection.algorithm_name == "" || protection.hash_value == "" {
    raise InvalidWorkbookProtection(msg="workbook protection password mismatch")
  }
  let (hash_value, _salt) = gen_iso_password_hash(
    password,
    protection.algorithm_name,
    protection.salt_value,
    protection.spin_count,
  )
  if protection.hash_value != hash_value {
    raise InvalidWorkbookProtection(msg="workbook protection password mismatch")
  }
}

///|
fn bool_attr(value : Bool) -> String {
  if value {
    "1"
  } else {
    "0"
  }
}
