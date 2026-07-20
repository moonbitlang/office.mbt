///|
/// The versioned dump envelope schema identifier.
pub const SCHEMA_DUMP : String = "office.dump/1"

///|
/// One machine-readable record of source content the dump could not express
/// as replayable ops. Records are ordered like the features they describe so
/// they participate in the fixpoint comparison.
pub(all) struct DumpResidual {
  code : String
  severity : String
  scope : String
  location : Json
  asset : String?
  detail : String
} derive(Eq, ToJson)

///|
/// One non-fatal dump diagnostic.
pub(all) struct DumpWarning {
  code : String
  message : String
} derive(Eq, ToJson)

///|
/// A complete semantic dump: ordered batch ops in the target engine's exact
/// JSON shapes, plus provenance, replay parameters, and explicit residuals.
pub(all) struct DumpEnvelope {
  format : String
  source_file : String
  source_bytes : Int
  source_sha256 : String?
  batch_schema : String
  create_sheet : String?
  ops : Array[Json]
  residual : Array[DumpResidual]
  warnings : Array[DumpWarning]
}

///|
fn residual_json(record : DumpResidual) -> Json {
  let fields : Map[String, Json] = {
    "code": Json::string(record.code),
    "severity": Json::string(record.severity),
    "scope": Json::string(record.scope),
    "location": record.location,
  }
  match record.asset {
    Some(asset) => fields["asset"] = Json::string(asset)
    None => ()
  }
  fields["detail"] = Json::string(record.detail)
  Json::object(fields)
}

///|
/// The single-document JSON form of the envelope.
pub fn DumpEnvelope::to_json_document(self : DumpEnvelope) -> Json {
  let replay : Map[String, Json] = {
    "batch_schema": Json::string(self.batch_schema),
  }
  match self.create_sheet {
    Some(sheet) =>
      replay["create"] = Json::object({ "sheet": Json::string(sheet) })
    None => replay["create"] = Json::object({})
  }
  replay["limits"] = Json::object({
    "max_ops": Json::number(@batch.MAX_BATCH_OPS.to_double()),
    "max_new_styles": Json::number(@batch.MAX_TOTAL_NEW_STYLES.to_double()),
    "max_script_bytes": Json::number(@batch.MAX_BATCH_SCRIPT_BYTES.to_double()),
  })
  Json::object({
    "schema": Json::string(SCHEMA_DUMP),
    "format": Json::string(self.format),
    "source": {
      let source : Map[String, Json] = {
        "file": Json::string(self.source_file),
        "bytes": Json::number(self.source_bytes.to_double()),
      }
      match self.source_sha256 {
        Some(digest) => source["sha256"] = Json::string(digest)
        None => ()
      }
      Json::object(source)
    },
    "replay": Json::object(replay),
    "ops": Json::array(self.ops),
    "residual": Json::array(self.residual.map(residual_json)),
    "warnings": Json::array(
      self.warnings.map(warning => {
        Json::object({
          "code": Json::string(warning.code),
          "message": Json::string(warning.message),
        })
      }),
    ),
    "stats": Json::object({
      "ops": Json::number(self.ops.length().to_double()),
      "residual": Json::number(self.residual.length().to_double()),
      "warnings": Json::number(self.warnings.length().to_double()),
    }),
  })
}

///|
/// The streaming JSONL form: header, one line per op/residual/warning, and
/// a terminal `end` record carrying the counts a consumer must verify.
pub fn DumpEnvelope::to_jsonl_lines(self : DumpEnvelope) -> Array[String] {
  let lines : Array[String] = []
  let document = self.to_json_document()
  guard document is Object(fields) else { return lines }
  let header : Map[String, Json] = { "record": Json::string("header") }
  for key in ["schema", "format", "source", "replay"] {
    match fields.get(key) {
      Some(value) => header[key] = value
      None => ()
    }
  }
  lines.push(Json::object(header).stringify())
  for index, op in self.ops {
    guard op is Object(op_fields) else { continue }
    let line : Map[String, Json] = {
      "record": Json::string("op"),
      "index": Json::number(index.to_double()),
    }
    for key in ["op", "params"] {
      match op_fields.get(key) {
        Some(value) => line[key] = value
        None => ()
      }
    }
    lines.push(Json::object(line).stringify())
  }
  for record in self.residual {
    guard residual_json(record) is Object(residual_fields) else { continue }
    let line : Map[String, Json] = { "record": Json::string("residual") }
    for key, value in residual_fields {
      line[key] = value
    }
    lines.push(Json::object(line).stringify())
  }
  for warning in self.warnings {
    lines.push(
      Json::object({
        "record": Json::string("warning"),
        "code": Json::string(warning.code),
        "message": Json::string(warning.message),
      }).stringify(),
    )
  }
  // integrity digest over the concatenated canonical op lines, so a
  // truncated or reordered stream is detectable on replay
  let op_payload = StringBuilder::new()
  for line in lines {
    if line.contains("\"record\":\"op\"") {
      op_payload.write_string(line)
      op_payload.write_char('\n')
    }
  }
  lines.push(
    Json::object({
      "record": Json::string("end"),
      "stats": Json::object({
        "ops": Json::number(self.ops.length().to_double()),
        "residual": Json::number(self.residual.length().to_double()),
        "warnings": Json::number(self.warnings.length().to_double()),
      }),
      "ops_sha256": Json::string(sha256_hex_string(op_payload.to_string())),
    }).stringify(),
  )
  lines
}

///|
/// Lowercase hex SHA-256 of a string's UTF-8 bytes.
pub fn sha256_hex_string(text : String) -> String {
  @crypto.bytes_to_hex_string(@crypto.sha256(@utf8.encode(text)))
}
