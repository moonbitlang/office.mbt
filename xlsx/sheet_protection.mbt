///|
let sheet_protection_spin_count = 100000

///|
fn gen_sheet_password(plaintext : StringView) -> String {
  let bytes = @encoding/utf16.encode(
    plaintext,
    bom=false,
    endianness=@encoding/utf16.Endian::Little,
  )
  let mut password : Int64 = 0
  let mut char_pos = 1
  let mut i = 0
  while i + 1 < bytes.length() {
    let lo = bytes[i].to_int()
    let hi = bytes[i + 1].to_int()
    let value = (hi << 8) | lo
    let shifted = value.to_int64() << char_pos
    char_pos = char_pos + 1
    let rotated = shifted >> 15
    let masked = shifted & 0x7fff
    password = password ^ (masked | rotated)
    i = i + 2
  }
  let len_units = (bytes.length() / 2).to_int64()
  password = password ^ len_units
  let xor_const : Int64 = 0xCE4B
  password = password ^ xor_const
  format_hex_upper(password)
}

///|
fn format_hex_upper(value : Int64) -> String {
  let digits = "0123456789ABCDEF".to_array()
  let mask : Int64 = 0xffff
  let mut n = value & mask
  if n == 0 {
    return "0"
  }
  let sb = StringBuilder::new()
  while n > 0 {
    let digit = (n & 0xf).to_int()
    sb.write_char(digits[digit])
    n = n >> 4
  }
  sb.to_string().rev()
}

///|
fn normalize_sheet_hash_algorithm(name : StringView) -> String? {
  match name.to_string() {
    "MD4" => Some("md4")
    "MD5" => Some("md5")
    "SHA-1" => Some("sha1")
    "SHA-256" => Some("sha256")
    "SHA-384" => Some("sha384")
    "SHA-512" => Some("sha512")
    _ => None
  }
}

///|
fn gen_iso_password_hash(
  password : StringView,
  algorithm_name : StringView,
  salt : StringView,
  spin_count : Int,
) -> (String, String) raise XlsxError {
  let pass_len = count_utf16_units(password)
  if pass_len <= 0 || pass_len > max_password_length {
    raise XlsxError::InvalidPasswordLength(len=pass_len)
  }
  let algorithm = match normalize_sheet_hash_algorithm(algorithm_name) {
    Some(value) => value
    None =>
      raise XlsxError::InvalidSheetProtection(msg="unsupported hash algorithm")
  }
  let salt_value = if salt == "" {
    random_bytes(16)
  } else {
    base64_decode(salt) catch {
      _ => raise XlsxError::InvalidBase64(msg="salt value invalid")
    }
  }
  let password_bytes = @encoding/utf16.encode(
    password,
    bom=false,
    endianness=@encoding/utf16.Endian::Little,
  )
  let initial = @crypto.hash_concat(algorithm, [salt_value, password_bytes])
  let mut key = initial
  for i in 0..<spin_count {
    let iter = u32_le_bytes(i)
    key = @crypto.hash_concat(algorithm, [key, iter])
  }
  let hash_value = base64_encode(key)
  let salt_text = base64_encode(salt_value)
  (hash_value, salt_text)
}

///|
fn sheet_protection_from_options(
  options : SheetProtectionOptions,
) -> SheetProtection raise XlsxError {
  let protection : SheetProtection = {
    algorithm_name: "",
    password: "",
    hash_value: "",
    salt_value: "",
    spin_count: 0,
    sheet: true,
    objects: !options.edit_objects,
    scenarios: !options.edit_scenarios,
    format_cells: !options.format_cells,
    format_columns: !options.format_columns,
    format_rows: !options.format_rows,
    insert_columns: !options.insert_columns,
    insert_rows: !options.insert_rows,
    insert_hyperlinks: !options.insert_hyperlinks,
    delete_columns: !options.delete_columns,
    delete_rows: !options.delete_rows,
    select_locked_cells: !options.select_locked_cells,
    sort: !options.sort,
    auto_filter: !options.auto_filter,
    pivot_tables: !options.pivot_tables,
    select_unlocked_cells: !options.select_unlocked_cells,
  }
  if options.password != "" {
    if options.algorithm_name == "" {
      protection.password = gen_sheet_password(options.password)
    } else {
      let (hash_value, salt_value) = gen_iso_password_hash(
        options.password,
        options.algorithm_name,
        "",
        sheet_protection_spin_count,
      )
      protection.algorithm_name = options.algorithm_name
      protection.hash_value = hash_value
      protection.salt_value = salt_value
      protection.spin_count = sheet_protection_spin_count
    }
  }
  protection
}

///|
fn verify_sheet_protection_password(
  protection : SheetProtection,
  password : StringView,
) -> Unit raise XlsxError {
  if protection.algorithm_name == "" {
    if protection.password == "" {
      raise XlsxError::InvalidSheetProtection(msg="sheet not protected")
    }
    if protection.password != gen_sheet_password(password) {
      raise XlsxError::InvalidSheetProtection(
        msg="sheet protection password mismatch",
      )
    }
    return
  }
  let (hash_value, _salt) = gen_iso_password_hash(
    password,
    protection.algorithm_name,
    protection.salt_value,
    protection.spin_count,
  )
  if protection.hash_value != hash_value {
    raise XlsxError::InvalidSheetProtection(
      msg="sheet protection password mismatch",
    )
  }
}
