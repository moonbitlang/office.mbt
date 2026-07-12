///|
/// A structured, machine-actionable warning attached to an Office response.
pub(all) struct ProtocolWarning {
  code : String
  message : String
}

///|
/// A structured failure carried by the `office.output/1` protocol.
pub(all) struct ProtocolError {
  code : String
  message : String
  details : Json?
}

///|
/// Creates a warning for an Office protocol response.
pub fn protocol_warning(code : String, message : String) -> ProtocolWarning {
  { code, message }
}

///|
/// Creates a structured Office protocol error.
pub fn protocol_error(
  code : String,
  message : String,
  details? : Json,
) -> ProtocolError {
  { code, message, details }
}

///|
fn warning_to_json(warning : ProtocolWarning) -> Json {
  Json::object({
    "code": Json::string(warning.code),
    "message": Json::string(warning.message),
  })
}

///|
fn warnings_to_json(warnings : Array[ProtocolWarning]) -> Json {
  Json::array(warnings.map(warning_to_json))
}

///|
/// Wraps successful command data in the deterministic `office.output/1`
/// envelope. The `warnings` member is omitted when there are no warnings.
pub fn output_success(
  data : Json,
  warnings? : Array[ProtocolWarning] = [],
) -> Json {
  let fields : Map[String, Json] = {
    "schema": Json::string("office.output/1"),
    "success": Json::boolean(true),
    "data": data,
  }
  if !warnings.is_empty() {
    fields["warnings"] = warnings_to_json(warnings)
  }
  Json::object(fields)
}

///|
/// Wraps a command failure in the deterministic `office.output/1` envelope.
/// The `warnings` member is omitted when there are no warnings.
pub fn output_failure(
  error : ProtocolError,
  warnings? : Array[ProtocolWarning] = [],
) -> Json {
  let error_fields : Map[String, Json] = {
    "code": Json::string(error.code),
    "message": Json::string(error.message),
  }
  match error.details {
    Some(details) => error_fields["details"] = details
    None => ()
  }
  let fields : Map[String, Json] = {
    "schema": Json::string("office.output/1"),
    "success": Json::boolean(false),
    "error": Json::object(error_fields),
  }
  if !warnings.is_empty() {
    fields["warnings"] = warnings_to_json(warnings)
  }
  Json::object(fields)
}
