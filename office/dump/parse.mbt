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
/// Parses an `office.dump/1` JSON document into the replayable core of a
/// `DumpEnvelope`: schema, format, replay batch schema and create sheet,
/// and the ops. The `stats.ops` count is required and must equal the actual
/// op count, so a truncated or padded op stream is rejected rather than
/// replayed into a partial workbook. `source` provenance is carried when
/// well-formed. Assets ARE reconstructed — docx replay feeds them to the
/// writer as image payloads — and each one is integrity-checked (base64
/// decodes, size matches, payload hashes to its own id). `residual` and
/// `warnings` are NOT reconstructed: they are re-derived when a replayed
/// document is dumped again and replay does not use them.
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
  // the create block is always present; the create SHEET is required for
  // an xlsx dump (its replay starts from a named sheet) and absent for a
  // docx dump (its writer builds the whole document). A missing sheet on
  // an xlsx dump is a malformed dump, not a deferred replay failure.
  let create = require_object(
    match replay.get("create") {
      Some(value) => value
      None => raise DumpParseError("missing \"replay.create\" block")
    },
    "replay.create block",
  )
  let create_sheet = if format == "xlsx" {
    Some(require_string(create, "sheet"))
  } else {
    match create.get("sheet") {
      Some(String(sheet)) => Some(sheet)
      Some(_) => raise DumpParseError("non-string \"replay.create.sheet\"")
      None => None
    }
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
  // integrity: the declared op count must match the actual op stream, so a
  // truncated or padded dump cannot silently produce a partial workbook
  let stats = require_object(
    match fields.get("stats") {
      Some(value) => value
      None => raise DumpParseError("missing \"stats\" block")
    },
    "stats block",
  )
  let declared_ops = match stats.get("ops") {
    Some(Number(count, ..)) => count
    _ => raise DumpParseError("missing or non-numeric \"stats.ops\"")
  }
  // compare as doubles so a fractional count (e.g. 1.5) cannot truncate to
  // a matching integer
  guard declared_ops == ops.length().to_double() else {
    raise DumpParseError(
      "stats.ops (\{declared_ops}) does not match the op stream length (\{ops.length()})",
    )
  }
  // assets are reconstructed with full integrity checks: the payload must
  // decode, match its declared size, and hash to its own id — an envelope
  // with a lying digest is malformed, not a deferred replay failure
  let assets : Map[String, DumpAsset] = {}
  match fields.get("assets") {
    Some(Object(entries)) =>
      for id, entry in entries {
        let asset = require_object(entry, "asset \"\{id}\"")
        let content_type = require_string(asset, "content_type")
        let data = require_string(asset, "data")
        let declared_size = match asset.get("size") {
          Some(Number(size, ..)) => size
          _ =>
            raise DumpParseError(
              "asset \"\{id}\" has a missing or non-numeric size",
            )
        }
        let decoded = @base64.decode(data) catch {
          _ =>
            raise DumpParseError("asset \"\{id}\" payload is not valid base64")
        }
        guard declared_size == decoded.length().to_double() else {
          raise DumpParseError(
            "asset \"\{id}\" declares \{declared_size} bytes but decodes to \{decoded.length()}",
          )
        }
        guard id == "sha256-" + sha256_hex_bytes(decoded) else {
          raise DumpParseError(
            "asset \"\{id}\" payload does not hash to its id",
          )
        }
        assets[id] = { content_type, size: decoded.length(), data }
      }
    Some(_) => raise DumpParseError("non-object \"assets\"")
    None => ()
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
    assets,
    residual: [],
    warnings: [],
  }
}
