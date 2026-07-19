///|
let package_relationships_namespace_for_validation = "http://schemas.openxmlformats.org/package/2006/relationships"

///|
fn is_relationship_package_part(name : StringView) -> Bool {
  name.to_owned().to_lower().has_suffix(".rels")
}

///|
fn relationship_scanner_attribute_view(
  scanner : @ooxml.XmlStartTagScanner,
  name : StringView,
) -> StringView? raise XlsxError {
  scanner.attribute_view("", name) catch {
    InvalidXml(msg~) => raise InvalidXml(msg~)
    ReadCancelled => raise ReadCancelled
  }
}

///|
fn relationship_scanner_attribute(
  scanner : @ooxml.XmlStartTagScanner,
  name : StringView,
) -> String? raise XlsxError {
  scanner.attribute("", name) catch {
    InvalidXml(msg~) => raise InvalidXml(msg~)
    ReadCancelled => raise ReadCancelled
  }
}

///|
/// Visits relationship start tags through the namespace-aware XML scanner.
/// In particular, XML whitespace after the QName and declared QName prefixes
/// are accepted instead of relying on one serialized spelling such as
/// `<Relationship `.
fn for_each_relationship_start_tag(
  xml : StringView,
  visit : (@ooxml.XmlStartTagScanner) -> Bool raise XlsxError,
  cancelled? : () -> Bool = () => false,
) -> Unit raise XlsxError {
  let scanner = @ooxml.XmlStartTagScanner::new(xml, cancelled~)
  let mut scanning = true
  while scanning {
    let advanced = scanner.next() catch {
      InvalidXml(msg~) => raise InvalidXml(msg~)
      ReadCancelled => raise ReadCancelled
    }
    if !advanced {
      scanning = false
      continue
    }
    if scanner.namespace_uri() == package_relationships_namespace_for_validation &&
      scanner.local_name() == "Relationship" {
      if !visit(scanner) {
        scanning = false
      }
    }
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
  decode? : (BytesView) -> String raise XlsxError,
  budget? : ReadBudget,
  cancelled? : () -> Bool = () => false,
) -> Unit raise XlsxError {
  let records = Ref(0)
  let attribute_chars = Ref(0)
  for entry in archive.entries() {
    check_read_cancelled(cancelled)
    if !is_relationship_package_part(entry.name()) {
      continue
    }
    let xml = match decode {
      Some(value) => value(entry.data())
      None => decode_utf8(entry.data(), transcoder)
    }
    match budget {
      Some(value) => {
        value.checkpoint()
        // The namespace-aware visitor below is an additional full pass beyond
        // the source preflight performed by the shared decoder.
        value.charge_work(xml.length())
      }
      None => ()
    }
    for_each_relationship_start_tag(
      xml,
      scanner => {
        check_read_cancelled(cancelled)
        records.val = records.val + 1
        if records.val > limits.max_relationship_records {
          raise ResourceLimitExceeded(
            kind="relationship_records",
            limit=limits.max_relationship_records,
            actual=records.val,
          )
        }
        match relationship_scanner_attribute_view(scanner, "Id") {
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
        match relationship_scanner_attribute_view(scanner, "Type") {
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
        match relationship_scanner_attribute_view(scanner, "Target") {
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
        match relationship_scanner_attribute_view(scanner, "TargetMode") {
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
        true
      },
      cancelled~,
    )
  }
}
