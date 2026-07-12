///|
let transaction_max_path_length = 4096

///|
let transaction_max_identifier_length = 96

///|
let transaction_max_message_length = 512

///|
let transaction_max_part_count = 256

///|
let transaction_max_part_length = 1024

///|
let transaction_max_warnings = 64

///|
priv enum TextScan {
  Valid
  TooLong
  Invalid
}

///|
fn scan_text(text : String, limit : Int) -> TextScan {
  let unit_length = text.length()
  let mut unit_offset = 0
  let mut scalar_count = 0
  while unit_offset < unit_length {
    let unit = text[unit_offset]
    if unit.is_leading_surrogate() {
      if unit_offset + 1 >= unit_length ||
        !text[unit_offset + 1].is_trailing_surrogate() {
        return Invalid
      }
      unit_offset = unit_offset + 2
    } else if unit.is_trailing_surrogate() {
      return Invalid
    } else {
      unit_offset = unit_offset + 1
    }
    scalar_count = scalar_count + 1
    if scalar_count > limit {
      return TooLong
    }
  }
  Valid
}

///|
fn bounded_text(text : String, limit : Int) -> String {
  if scan_text(text, limit) is Valid {
    return text
  }
  if scan_text(text, transaction_max_message_length * 4) is Invalid {
    return "<invalid UTF-16>"
  }
  let output = StringBuilder::new()
  let mut count = 0
  for character in text {
    if count == limit {
      output.write_string("…") |> ignore
      break
    }
    output.write_char(character) |> ignore
    count = count + 1
  }
  output.to_string()
}

///|
/// A stable failure from the format-neutral transaction boundary.
pub(all) suberror TransactionError {
  TransactionError(code~ : String, message~ : String, details~ : Json?)
}

///|
pub impl Show for TransactionError with fn output(self, logger) {
  match self {
    TransactionError(code~, message~, ..) =>
      logger.write_string("transaction error \{code}: \{message}")
  }
}

///|
fn transaction_error(
  code : String,
  message : String,
  details? : Json,
) -> TransactionError {
  TransactionError(
    code~,
    message=bounded_text(message, transaction_max_message_length),
    details~,
  )
}

///|
/// Converts a transaction failure into the shared `office.output/1` error
/// contract used by canonical CLI handlers.
pub fn TransactionError::to_protocol_error(
  self : TransactionError,
) -> @office.ProtocolError {
  match self {
    TransactionError(code~, message~, details~) =>
      match details {
        Some(value) => @office.protocol_error(code, message, details=value)
        None => @office.protocol_error(code, message)
      }
  }
}

///|
fn checked_path(path : String, label : String) -> Unit raise TransactionError {
  if path.length() == 0 {
    raise transaction_error(
      "office.transaction.invalid_options",
      "\{label} must not be empty",
      details=Json::object({ "field": Json::string(label) }),
    )
  }
  match scan_text(path, transaction_max_path_length) {
    Valid => ()
    Invalid =>
      raise transaction_error(
        "office.transaction.invalid_options",
        "\{label} contains an isolated UTF-16 surrogate",
        details=Json::object({ "field": Json::string(label) }),
      )
    TooLong =>
      raise transaction_error(
        "office.transaction.invalid_options",
        "\{label} exceeds \{transaction_max_path_length} characters",
        details=Json::object({
          "field": Json::string(label),
          "limit": Json::number(transaction_max_path_length.to_double()),
        }),
      )
  }
}

///|
fn is_identifier_character(character : Char) -> Bool {
  character.is_ascii_alphabetic() ||
  character.is_ascii_digit() ||
  character == '.' ||
  character == '_' ||
  character == '-'
}

///|
fn checked_identifier(
  value : String,
  label : String,
) -> Unit raise TransactionError {
  if value.length() == 0 {
    raise transaction_error(
      "office.transaction.invalid_contract",
      "\{label} must not be empty",
    )
  }
  match scan_text(value, transaction_max_identifier_length) {
    Valid => ()
    Invalid =>
      raise transaction_error(
        "office.transaction.invalid_contract",
        "\{label} contains an isolated UTF-16 surrogate",
      )
    TooLong =>
      raise transaction_error(
        "office.transaction.invalid_contract",
        "\{label} exceeds \{transaction_max_identifier_length} characters",
      )
  }
  for character in value {
    if !is_identifier_character(character) {
      raise transaction_error(
        "office.transaction.invalid_contract",
        "\{label} may contain only ASCII letters, digits, '.', '_', and '-'",
      )
    }
  }
}

///|
fn checked_message(
  value : String,
  label : String,
) -> Unit raise TransactionError {
  match scan_text(value, transaction_max_message_length) {
    Valid => ()
    Invalid =>
      raise transaction_error(
        "office.transaction.invalid_contract",
        "\{label} contains an isolated UTF-16 surrogate",
      )
    TooLong =>
      raise transaction_error(
        "office.transaction.invalid_contract",
        "\{label} exceeds \{transaction_max_message_length} characters",
      )
  }
}

///|
/// Immutable destination and publication policy for one transaction.
pub struct TransactionOptions {
  input_path : String
  output_path : String?
  dry_run : Bool
  overwrite : Bool
  permission : Int
}

///|
/// Builds checked transaction options. `output_path=None` means in-place;
/// separate outputs are no-replace unless `overwrite=true`.
pub fn transaction_options(
  input_path : String,
  output_path? : String,
  dry_run? : Bool = false,
  overwrite? : Bool = false,
  permission? : Int = 0o600,
) -> TransactionOptions raise TransactionError {
  checked_path(input_path, "input_path")
  match output_path {
    Some(path) => checked_path(path, "output_path")
    None => ()
  }
  if permission < 0 || permission > 0o777 {
    raise transaction_error(
      "office.transaction.invalid_options",
      "permission must be between 0000 and 0777",
      details=Json::object({ "field": Json::string("permission") }),
    )
  }
  { input_path, output_path, dry_run, overwrite, permission }
}

///|
/// One deterministic finding returned by a deeper format validator.
pub struct ValidationFinding {
  code : String
  message : String
}

///|
pub fn validation_finding(
  code : String,
  message : String,
) -> ValidationFinding raise TransactionError {
  checked_identifier(code, "validation finding code")
  checked_message(message, "validation finding message")
  { code, message }
}

///|
/// A named, side-effect-free validation hook run after the mandatory portable
/// OPC gate and before any temporary file is created.
pub struct TransactionValidator {
  name : String
  validate : (@office.DocumentFormat, BytesView) -> Array[ValidationFinding] raise
}

///|
pub fn transaction_validator(
  name : String,
  validate : (@office.DocumentFormat, BytesView) -> Array[ValidationFinding] raise,
) -> TransactionValidator raise TransactionError {
  checked_identifier(name, "validator name")
  { name, validate }
}

///|
fn TransactionValidator::run(
  self : TransactionValidator,
  format : @office.DocumentFormat,
  bytes : BytesView,
) -> Array[ValidationFinding] raise {
  (self.validate)(format, bytes)
}

///|
/// Candidate package bytes, optional mutation warnings, and an optional exact
/// allowlist of archive parts that may change, be added, or be removed.
pub struct TransactionMutation {
  bytes : Bytes
  declared_parts : ReadOnlyArray[String]?
  warnings : ReadOnlyArray[@office.ProtocolWarning]
}

///|
fn checked_warning(
  warning : @office.ProtocolWarning,
) -> @office.ProtocolWarning raise TransactionError {
  checked_identifier(warning.code, "warning code")
  checked_message(warning.message, "warning message")
  @office.protocol_warning(warning.code, warning.message)
}

///|
fn checked_warnings(
  warnings : Array[@office.ProtocolWarning],
) -> ReadOnlyArray[@office.ProtocolWarning] raise TransactionError {
  if warnings.length() > transaction_max_warnings {
    raise transaction_error(
      "office.transaction.invalid_contract",
      "mutation exceeds \{transaction_max_warnings} warnings",
    )
  }
  let result = []
  for warning in warnings {
    result.push(checked_warning(warning))
  }
  ReadOnlyArray::from_array(result)
}

///|
fn checked_part_name(name : String) -> Unit raise TransactionError {
  match scan_text(name, transaction_max_part_length) {
    Invalid =>
      raise transaction_error(
        "office.transaction.invalid_manifest", "declared part contains an isolated UTF-16 surrogate",
      )
    TooLong =>
      raise transaction_error(
        "office.transaction.invalid_manifest",
        "declared part exceeds \{transaction_max_part_length} characters",
      )
    Valid => ()
  }
  if name.length() == 0 || name.has_prefix("/") || name.contains("\\") {
    raise transaction_error(
      "office.transaction.invalid_manifest",
      "declared parts must be canonical relative ZIP entry names",
      details=Json::object({ "part": Json::string(bounded_text(name, 160)) }),
    )
  }
  for component in name.split("/") {
    if component.length() == 0 || component == "." || component == ".." {
      raise transaction_error(
        "office.transaction.invalid_manifest",
        "declared parts must not contain empty, '.', or '..' components",
        details=Json::object({ "part": Json::string(bounded_text(name, 160)) }),
      )
    }
  }
}

///|
fn checked_parts(
  parts : Array[String],
) -> ReadOnlyArray[String] raise TransactionError {
  if parts.length() > transaction_max_part_count {
    raise transaction_error(
      "office.transaction.invalid_manifest",
      "preservation manifest exceeds \{transaction_max_part_count} parts",
      details=Json::object({
        "limit": Json::number(transaction_max_part_count.to_double()),
      }),
    )
  }
  let result = []
  for part in parts {
    checked_part_name(part)
    if result.contains(part) {
      raise transaction_error(
        "office.transaction.invalid_manifest",
        "preservation manifest contains duplicate part '\{bounded_text(part, 160)}'",
      )
    }
    result.push(part)
  }
  result.sort()
  ReadOnlyArray::from_array(result)
}

///|
/// Builds a candidate without a declared-part preservation allowlist.
pub fn transaction_mutation(
  bytes : Bytes,
  warnings? : Array[@office.ProtocolWarning] = [],
) -> TransactionMutation raise TransactionError {
  { bytes, declared_parts: None, warnings: checked_warnings(warnings) }
}

///|
/// Builds a candidate whose changed/added/removed ZIP entries must all appear
/// in `declared_parts`. Passing an empty array asserts payload-level no-op.
pub fn transaction_mutation_with_manifest(
  bytes : Bytes,
  declared_parts : Array[String],
  warnings? : Array[@office.ProtocolWarning] = [],
) -> TransactionMutation raise TransactionError {
  {
    bytes,
    declared_parts: Some(checked_parts(declared_parts)),
    warnings: checked_warnings(warnings),
  }
}

///|
pub(all) enum TransactionMode {
  InPlace
  Output
} derive(Debug, Eq)

///|
pub fn TransactionMode::name(self : TransactionMode) -> String {
  match self {
    InPlace => "in-place"
    Output => "output"
  }
}

///|
/// A successful validation stage recorded in the transaction report.
pub struct ValidationSummary {
  name : String
  passed : Bool
  finding_count : Int
}

///|
/// Payload-level comparison of the original and candidate OOXML archives.
pub struct PreservationReport {
  whole_file_identical : Bool
  manifest_enforced : Bool
  changed : ReadOnlyArray[String]
  added : ReadOnlyArray[String]
  removed : ReadOnlyArray[String]
  unchanged : ReadOnlyArray[String]
  zip_metadata_policy : String
}

///|
/// Deterministic result of a validated Office transaction.
pub struct TransactionReport {
  format : @office.DocumentFormat
  input_path : String
  output_path : String
  mode : TransactionMode
  dry_run : Bool
  changed : Bool
  committed : Bool
  original_size : Int
  result_size : Int
  validations : ReadOnlyArray[ValidationSummary]
  preservation : PreservationReport
  warnings : ReadOnlyArray[@office.ProtocolWarning]
}

///|
fn json_strings(values : ReadOnlyArray[String]) -> Json {
  let result = []
  for value in values {
    result.push(Json::string(value))
  }
  Json::array(result)
}

///|
fn validation_json(summary : ValidationSummary) -> Json {
  Json::object({
    "name": Json::string(summary.name),
    "passed": Json::boolean(summary.passed),
    "finding_count": Json::number(summary.finding_count.to_double()),
  })
}

///|
fn preservation_json(report : PreservationReport) -> Json {
  Json::object({
    "whole_file_identical": Json::boolean(report.whole_file_identical),
    "manifest_enforced": Json::boolean(report.manifest_enforced),
    "changed": json_strings(report.changed),
    "added": json_strings(report.added),
    "removed": json_strings(report.removed),
    "unchanged_count": Json::number(report.unchanged.length().to_double()),
    "zip_metadata_policy": Json::string(report.zip_metadata_policy),
  })
}

///|
/// Serializes the report as the `office.transaction/1` data object.
pub fn TransactionReport::to_json(self : TransactionReport) -> Json {
  let validations = []
  for validation in self.validations {
    validations.push(validation_json(validation))
  }
  Json::object({
    "schema": Json::string("office.transaction/1"),
    "format": Json::string(self.format.name()),
    "input": Json::string(self.input_path),
    "output": Json::string(self.output_path),
    "mode": Json::string(self.mode.name()),
    "dry_run": Json::boolean(self.dry_run),
    "changed": Json::boolean(self.changed),
    "committed": Json::boolean(self.committed),
    "original_size": Json::number(self.original_size.to_double()),
    "result_size": Json::number(self.result_size.to_double()),
    "validations": Json::array(validations),
    "preservation": preservation_json(self.preservation),
  })
}

///|
/// Wraps the report and its warnings in the shared `office.output/1` envelope.
pub fn TransactionReport::to_output(self : TransactionReport) -> Json {
  let warnings = []
  for warning in self.warnings {
    warnings.push(warning)
  }
  @office.output_success(self.to_json(), warnings~)
}
