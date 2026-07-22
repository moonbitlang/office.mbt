///|
/// The strict `office.template.data/1` input: one flat `values` object,
/// keys in the placeholder key grammar, values limited to string, number,
/// or boolean. Anything else — null, arrays, nesting, unknown top-level
/// members, duplicate keys, over-bounds sizes, or string values carrying
/// code points the XML serializers cannot represent — is rejected BEFORE
/// any document is opened.

///|
pub const SCHEMA_TEMPLATE_DATA : String = "office.template.data/1"

///|
/// Errors raised while parsing a template data document.
pub suberror TemplateDataError {
  TemplateDataError(String)
} derive(@debug.Debug)

///|
/// One substitutable value, typed so a whole-cell XLSX placeholder can
/// keep the value's native type.
pub(all) enum TemplateValue {
  TextValue(String)
  NumberValue(Double)
  BoolValue(Bool)
} derive(Eq, @debug.Debug)

///|
/// Deterministic text form used for substring substitution: strings pass
/// through, integral numbers within the double-exact range render without
/// a fraction, everything else uses the core double formatter (identical
/// across backends), booleans render lowercase.
pub fn TemplateValue::render(self : TemplateValue) -> String {
  match self {
    TextValue(text) => text
    NumberValue(value) => {
      let truncated = value.to_int64()
      if truncated.to_double() == value &&
        value >= -9007199254740992.0 &&
        value <= 9007199254740992.0 {
        truncated.to_string()
      } else {
        value.to_string()
      }
    }
    BoolValue(flag) => if flag { "true" } else { "false" }
  }
}

///|
/// Whether a data string value can survive both XML serializers: control
/// characters below 0x20 (except tab, LF, CR), unpaired surrogates, and
/// the XML non-characters U+FFFE/U+FFFF are rejected. Values are rejected
/// at parse time rather than lossily sanitized at publication.
fn template_value_text_ok(text : String) -> Bool {
  for unit in text {
    let code = unit.to_int()
    if code < 0x20 && code != 0x09 && code != 0x0A && code != 0x0D {
      return false
    }
    // iteration combines surrogate pairs, so a surrogate seen here is
    // unpaired
    if (code >= 0xD800 && code <= 0xDFFF) || code == 0xFFFE || code == 0xFFFF {
      return false
    }
  }
  true
}

///|
/// Rejects duplicate object keys anywhere in the raw document text. A
/// post-parse map silently keeps one duplicate; for template data a
/// duplicated key is an authoring error that must surface. The scan
/// tracks object frames and their seen keys; strings are skipped with
/// full escape handling. Runs before `@json.parse`, so malformed JSON is
/// reported by the real parser rather than this pre-scan.
fn check_duplicate_keys(
  text : String,
  on_member? : ((Array[String], String, Int) -> Unit raise TemplateDataError)? = None,
) -> Unit raise TemplateDataError {
  let units = text.code_units()
  let length = units.length()
  let frames : Array[ScanFrame] = []
  let mut index = 0
  while index < length {
    let unit = units[index].to_int()
    if unit == '"'.to_int() {
      // read the string; when an object frame is expecting a key, record
      // its identity as the raw code-unit sequence (escapes verbatim) —
      // two lexically identical keys collide post-parse, and the strict
      // key grammar has no escapable characters, so verbatim identity is
      // exact for well-formed data. Values with arbitrary unicode are
      // skipped without materializing characters.
      let identity = StringBuilder::new()
      let mut escaped = false
      index += 1
      let string_start = index
      let mut closed = false
      while index < length {
        let piece = units[index].to_int()
        if piece == '\\'.to_int() {
          escaped = true
          identity.write_string("\{piece},")
          if index + 1 < length {
            identity.write_string("\{units[index + 1].to_int()},")
            index += 2
          } else {
            index += 1
          }
          continue
        }
        if piece == '"'.to_int() {
          closed = true
          index += 1
          break
        }
        identity.write_string("\{piece},")
        index += 1
      }
      if !closed {
        return
      }
      match frames.last() {
        Some(frame) if frame.is_object && frame.expecting_key => {
          // a \uXXXX spelling decodes to a character the verbatim
          // identity cannot see (\u0061 aliases "a" and @json.parse is
          // last-wins), so any escape in a KEY is rejected outright —
          // grammar keys never need one
          if escaped {
            raise TemplateDataError(
              "data keys must not use JSON escape sequences",
            )
          }
          let key = identity.to_string()
          if frame.seen.contains(key) {
            raise TemplateDataError("duplicate key in the data document")
          }
          frame.seen.add(key)
          frame.expecting_key = false
          // escaped keys raised above, so the raw span IS the key text —
          // labels and the callback want characters, not the identity
          // encoding the seen-set uses
          let literal = text.substring(start=string_start, end=index - 1)
          frame.pending_key = literal
          match on_member {
            Some(callback) => {
              let labels = frames.map(open => open.label)
              callback(labels, literal, index)
            }
            None => ()
          }
        }
        _ => ()
      }
      continue
    }
    if unit == '{'.to_int() || unit == '['.to_int() {
      let label = match frames.last() {
        Some(parent) if parent.is_object => parent.pending_key
        _ => ""
      }
      frames.push({
        is_object: unit == '{'.to_int(),
        seen: Set::new(),
        expecting_key: unit == '{'.to_int(),
        label,
        pending_key: "",
      })
    } else if unit == '}'.to_int() || unit == ']'.to_int() {
      ignore(frames.pop())
    } else if unit == ','.to_int() {
      match frames.last() {
        Some(frame) if frame.is_object => frame.expecting_key = true
        _ => ()
      }
    }
    index += 1
  }
}

///|
/// One open JSON container during the raw scan: its seen keys, whether the
/// next string is a key, the member key under which the container itself
/// was opened (array items carry ""), and the most recent key read (the
/// label a child container opened next inherits).
priv struct ScanFrame {
  is_object : Bool
  seen : Set[String]
  mut expecting_key : Bool
  label : String
  mut pending_key : String
}

///|
/// Parses and validates an `office.template.data/1` document. Bounds:
/// at most `max_keys` values, each string value at most
/// `max_value_units` UTF-16 code units.
pub fn parse_template_data(
  text : String,
  max_keys? : Int = 4096,
  max_value_units? : Int = 65536,
) -> Map[String, TemplateValue] raise TemplateDataError {
  check_duplicate_keys(text)
  let document = @json.parse(text) catch {
    _ => raise TemplateDataError("data document is not valid JSON")
  }
  guard document is Object(fields) else {
    raise TemplateDataError("data document must be a JSON object")
  }
  for key, _ in fields {
    if key != "schema" && key != "values" {
      raise TemplateDataError(
        "unknown top-level member \"" + key + "\" (expected schema, values)",
      )
    }
  }
  guard fields.get("schema") is Some(String(schema)) else {
    raise TemplateDataError(
      "data document needs \"schema\": \"" + SCHEMA_TEMPLATE_DATA + "\"",
    )
  }
  guard schema == SCHEMA_TEMPLATE_DATA else {
    raise TemplateDataError(
      "unsupported data schema \"" +
      schema +
      "\" (expected " +
      SCHEMA_TEMPLATE_DATA +
      ")",
    )
  }
  guard fields.get("values") is Some(Object(entries)) else {
    raise TemplateDataError("data document needs a \"values\" object")
  }
  parse_scalar_entries(entries, max_keys, max_value_units, "", "values")
}

///|
/// Validates one flat scalar object (the `values` member, or one region
/// record) under the shared gates: key grammar, string bounds and
/// serializability, finite numbers, no null/array/nesting. `prefix` scopes
/// error messages to the container ("" for `values`, a region/record label
/// for records); `container` names it in the key-count message.
fn parse_scalar_entries(
  entries : Map[String, Json],
  max_keys : Int,
  max_value_units : Int,
  prefix : String,
  container : String,
) -> Map[String, TemplateValue] raise TemplateDataError {
  if entries.size() > max_keys {
    raise TemplateDataError(
      prefix +
      container +
      " carries \{entries.size()} keys; the limit is \{max_keys}",
    )
  }
  let values : Map[String, TemplateValue] = {}
  for key, value in entries {
    if !template_key_ok(key) {
      raise TemplateDataError(
        prefix +
        "value key \"" +
        key +
        "\" is outside the placeholder key grammar",
      )
    }
    match value {
      String(item) => {
        if item.code_units().length() > max_value_units {
          raise TemplateDataError(
            prefix +
            "value for \"" +
            key +
            "\" exceeds \{max_value_units} units",
          )
        }
        if !template_value_text_ok(item) {
          raise TemplateDataError(
            prefix +
            "value for \"" +
            key +
            "\" carries characters the document serializers cannot represent",
          )
        }
        values[key] = TextValue(item)
      }
      Number(number, ..) => {
        // JSON has no infinity, but an overflowing literal (1e309)
        // parses to one — which would substitute the word "Infinity"
        // into published documents; reject like any other non-scalar
        if number != number || number.is_inf() {
          raise TemplateDataError(
            prefix + "value for \"" + key + "\" is not a finite number",
          )
        }
        values[key] = NumberValue(number)
      }
      True => values[key] = BoolValue(true)
      False => values[key] = BoolValue(false)
      Null =>
        raise TemplateDataError(
          prefix +
          "value for \"" +
          key +
          "\" is null; only string, number, and boolean values are supported",
        )
      _ =>
        raise TemplateDataError(
          prefix +
          "value for \"" +
          key +
          "\" is not a scalar; only string, number, and boolean values are supported",
        )
    }
  }
  values
}
