///|
/// Versioned inventory schema for installed consumed-input contracts.
pub const SCHEMA_INVENTORY : String = "office.input-contracts/1"

///|
/// Versioned schema for one installed consumed-input contract.
pub const SCHEMA_RECORD : String = "office.input-contract/1"

///|
/// Canonical, owner-populated content of one consumed-input contract.
pub(all) struct Core {
  id : String
  summary : String
  consumed_by : Array[String]
  envelope : Json
  definitions : Array[Json]
  operations : Array[Json]
  constraints : Array[String]
  limits : Json
  examples : Array[Json]
}

///|
/// Converts ordered strings to their canonical JSON array form.
pub fn contract_strings(values : Array[String]) -> Json {
  Json::array(values.map(Json::string))
}

///|
/// Converts ordered name/type pairs to their canonical JSON object form.
pub fn contract_members(entries : Array[(String, String)]) -> Json {
  let members : Map[String, Json] = Map([])
  for name_and_type in entries {
    members[name_and_type.0] = Json::string(name_and_type.1)
  }
  Json::object(members)
}

///|
/// Builds one closed reusable object definition.
pub fn contract_object(
  name : String,
  entries : Array[(String, String)],
  required? : Array[String] = [],
  constraints? : Array[String] = [],
) -> Json {
  Json::object({
    "name": Json::string(name),
    "type": Json::string("object"),
    "members": contract_members(entries),
    "required": contract_strings(required),
    "additional_members": Json::boolean(false),
    "constraints": contract_strings(constraints),
  })
}

///|
/// Builds one named reusable scalar or union definition.
pub fn contract_type(
  name : String,
  type_name : String,
  constraints? : Array[String] = [],
) -> Json {
  Json::object({
    "name": Json::string(name),
    "type": Json::string(type_name),
    "constraints": contract_strings(constraints),
  })
}

///|
/// Builds the closed top-level envelope definition.
pub fn contract_envelope(
  entries : Array[(String, String)],
  required : Array[String],
) -> Json {
  contract_object("envelope", entries, required~)
}

///|
/// Canonical JSON payload covered by a contract fingerprint.
pub fn core_json(core : Core) -> Json {
  Json::object({
    "id": Json::string(core.id),
    "summary": Json::string(core.summary),
    "consumed_by": contract_strings(core.consumed_by),
    "envelope": core.envelope,
    "definitions": Json::array(core.definitions),
    "operations": Json::array(core.operations),
    "constraints": contract_strings(core.constraints),
    "limits": core.limits,
    "examples": Json::array(core.examples),
  })
}

///|
/// Cross-target SHA-256 fingerprint of canonical compact JSON.
pub fn fingerprint(core : Core) -> String {
  "sha256:" +
  @crypto.bytes_to_hex_string(
    @crypto.sha256(@utf8.encode(core_json(core).stringify())),
  )
}

///|
/// Emits one complete versioned contract record.
pub fn record(core : Core) -> Json {
  Json::object({
    "schema": Json::string(SCHEMA_RECORD),
    "id": Json::string(core.id),
    "fingerprint": Json::string(fingerprint(core)),
    "summary": Json::string(core.summary),
    "consumed_by": contract_strings(core.consumed_by),
    "envelope": core.envelope,
    "definitions": Json::array(core.definitions),
    "operations": Json::array(core.operations),
    "constraints": contract_strings(core.constraints),
    "limits": core.limits,
    "examples": Json::array(core.examples),
  })
}

///|
/// Emits the ordered inventory and its canonical aggregate fingerprint.
pub fn inventory(cores : Array[Core]) -> Json {
  let summaries : Array[Json] = []
  for core in cores {
    summaries.push(
      Json::object({
        "id": Json::string(core.id),
        "fingerprint": Json::string(fingerprint(core)),
        "summary": Json::string(core.summary),
        "consumed_by": contract_strings(core.consumed_by),
      }),
    )
  }
  let inventory_fingerprint = "sha256:" +
    @crypto.bytes_to_hex_string(
      @crypto.sha256(@utf8.encode(Json::array(summaries).stringify())),
    )
  Json::object({
    "schema": Json::string(SCHEMA_INVENTORY),
    "fingerprint": Json::string(inventory_fingerprint),
    "contracts": Json::array(summaries),
  })
}
