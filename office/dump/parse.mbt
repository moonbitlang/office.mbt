///|
/// Errors raised while parsing an `office.dump/1` document back into an
/// envelope. Malformed or truncated dumps fail here rather than producing a
/// partial replay.
pub suberror DumpParseError {
  DumpParseError(String)
} derive(@debug.Debug)

///|
fn require_object(
  value : Json,
  what : String,
) -> Map[String, Json] raise DumpParseError {
  guard value is Object(fields) else {
    raise DumpParseError("\{what} must be a JSON object")
  }
  fields
}

///|
fn require_string(
  fields : Map[String, Json],
  key : String,
) -> String raise DumpParseError {
  match fields.get(key) {
    Some(String(text)) => text
    _ => raise DumpParseError("missing or non-string field \"\{key}\"")
  }
}

///|
/// Parses an `office.dump/1` JSON document into a `DumpEnvelope`. Only the
/// fields replay needs are required (schema, format, replay batch schema
/// and create sheet, ops); residual/warnings/source are carried when
/// present but never required, so a dump trimmed to its replayable core
/// still parses.
pub fn parse_dump_envelope(
  document : Json,
) -> DumpEnvelope raise DumpParseError {
  let fields = require_object(document, "dump document")
  guard require_string(fields, "schema") == SCHEMA_DUMP else {
    raise DumpParseError("dump schema is not \{SCHEMA_DUMP}")
  }
  let format = require_string(fields, "format")
  let replay = require_object(
    match fields.get("replay") {
      Some(value) => value
      None => raise DumpParseError("missing \"replay\" block")
    },
    "replay block",
  )
  let batch_schema = require_string(replay, "batch_schema")
  let create_sheet = match replay.get("create") {
    Some(Object(create)) =>
      match create.get("sheet") {
        Some(String(sheet)) => Some(sheet)
        _ => None
      }
    _ => None
  }
  let ops = match fields.get("ops") {
    Some(Array(items)) => items
    _ => raise DumpParseError("missing or non-array \"ops\"")
  }
  // every op must be an object with an "op" string; reject early so replay
  // never applies a malformed op
  for op in ops {
    let op_fields = require_object(op, "op")
    ignore(require_string(op_fields, "op"))
  }
  let source = match fields.get("source") {
    Some(Object(source)) => source
    _ => Map::new()
  }
  {
    format,
    source_file: match source.get("file") {
      Some(String(file)) => file
      _ => ""
    },
    source_bytes: match source.get("bytes") {
      Some(Number(bytes, ..)) => bytes.to_int()
      _ => 0
    },
    source_sha256: match source.get("sha256") {
      Some(String(digest)) => Some(digest)
      _ => None
    },
    batch_schema,
    create_sheet,
    ops,
    residual: [],
    warnings: [],
  }
}
