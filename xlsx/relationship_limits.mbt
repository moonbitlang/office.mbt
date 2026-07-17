///|
fn relationship_start_tag_end(text : StringView) -> Int? {
  let mut quote : UInt16? = None
  for index in 0..<text.length() {
    let unit = text[index]
    match quote {
      Some(value) => if unit == value { quote = None }
      None =>
        if unit == ('"' : UInt16) || unit == ('\'' : UInt16) {
          quote = Some(unit)
        } else if unit == ('>' : UInt16) {
          return Some(index)
        }
    }
  }
  None
}

///|
fn relationship_attribute_view(
  tag : StringView,
  name : StringView,
) -> StringView? raise XlsxError {
  @ooxml.attr_value_view(tag, name) catch {
    InvalidXml(msg~) => raise InvalidXml(msg~)
    ReadCancelled => raise ReadCancelled
  }
}

///|
fn charge_relationship_attribute(
  value : StringView,
  kind : String,
  maximum : Int,
  total : Ref[Int],
  total_maximum : Int,
) -> Unit raise XlsxError {
  if value.length() > maximum {
    raise ResourceLimitExceeded(kind~, limit=maximum, actual=value.length())
  }
  if value.length() > total_maximum - total.val {
    raise ResourceLimitExceeded(
      kind="total_relationship_chars",
      limit=total_maximum,
      actual=bounded_actual_above_limit(total_maximum),
    )
  }
  total.val = total.val + value.length()
}

///|
/// Preflights every relationship part before any relationship map or resolved
/// path is materialized. Attribute values stay borrowed until their individual
/// and package-wide ceilings have been charged. This makes the limits
/// cumulative even though downstream readers intentionally build separate maps
/// for different relationship types.
fn preflight_archive_relationship_limits(
  archive : @zip.Archive,
  limits : ReadLimits,
  transcoder? : (String, Bytes) -> String raise XlsxError,
  cancelled? : () -> Bool = () => false,
) -> Unit raise XlsxError {
  let records = Ref(0)
  let attribute_chars = Ref(0)
  for entry in archive.entries() {
    check_read_cancelled(cancelled)
    if !entry.name().has_suffix(".rels") {
      continue
    }
    let xml = decode_utf8(entry.data(), transcoder)
    let mut first = true
    for chunk in xml.split("<Relationship ") {
      check_read_cancelled(cancelled)
      if first {
        first = false
        continue
      }
      records.val = records.val + 1
      if records.val > limits.max_relationship_records {
        raise ResourceLimitExceeded(
          kind="relationship_records",
          limit=limits.max_relationship_records,
          actual=records.val,
        )
      }
      let end = match relationship_start_tag_end(chunk) {
        Some(value) => value
        None => raise InvalidXml(msg="relationship tag not closed")
      }
      let tag = chunk[:end]
      match relationship_attribute_view(tag, "Id") {
        Some(value) =>
          charge_relationship_attribute(
            value,
            "relationship_id_chars",
            limits.max_relationship_id_chars,
            attribute_chars,
            limits.max_total_relationship_chars,
          )
        None => ()
      }
      match relationship_attribute_view(tag, "Type") {
        Some(value) =>
          charge_relationship_attribute(
            value,
            "relationship_type_chars",
            limits.max_relationship_type_chars,
            attribute_chars,
            limits.max_total_relationship_chars,
          )
        None => ()
      }
      match relationship_attribute_view(tag, "Target") {
        Some(value) =>
          charge_relationship_attribute(
            value,
            "relationship_target_chars",
            limits.max_relationship_target_chars,
            attribute_chars,
            limits.max_total_relationship_chars,
          )
        None => ()
      }
      // TargetMode is normally one of two short tokens. Charge it under the
      // type ceiling so an irrelevant attacker-sized value cannot hide outside
      // the package-wide relationship budget.
      match relationship_attribute_view(tag, "TargetMode") {
        Some(value) =>
          charge_relationship_attribute(
            value,
            "relationship_mode_chars",
            limits.max_relationship_type_chars,
            attribute_chars,
            limits.max_total_relationship_chars,
          )
        None => ()
      }
    }
  }
}
