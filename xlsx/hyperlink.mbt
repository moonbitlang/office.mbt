///|
pub(all) enum HyperlinkType {
  External
  Location
  Unset
} derive(Eq, Debug)

///|
pub struct Hyperlink {
  reference : String
  target : String
  link_type : HyperlinkType
  /// Workbook-internal location fragment. Always set for `Location`
  /// links; also set for `External` links whose XML carried both an
  /// `r:id` and a `location` attribute, which Excelize tracks
  /// independently.
  location : String?
  display : String?
  tooltip : String?
} derive(Debug)

///|
pub struct HyperlinkOpts {
  mut display : String?
  mut tooltip : String?
} derive(Debug)

///|
pub fn HyperlinkOpts::new() -> HyperlinkOpts {
  { display: None, tooltip: None }
}

///|
pub fn HyperlinkOpts::with_values(
  display? : String,
  tooltip? : String,
) -> HyperlinkOpts {
  let opts = HyperlinkOpts::new()
  match display {
    Some(value) => opts.display = Some(value)
    None => ()
  }
  match tooltip {
    Some(value) => opts.tooltip = Some(value)
    None => ()
  }
  opts
}

///|
let max_sheet_hyperlinks = 65530

///|
/// Keeps every writer-produced relationship start tag below the default
/// 16 MiB OOXML-part ceiling even when every character needs XML escaping.
let max_hyperlink_target_chars : Int = 1024 * 1024

///|
fn is_ascii_uri_scheme_start(character : Char) -> Bool {
  let scalar = character.to_int()
  (scalar >= 'A'.to_int() && scalar <= 'Z'.to_int()) ||
  (scalar >= 'a'.to_int() && scalar <= 'z'.to_int())
}

///|
fn is_ascii_uri_scheme_character(character : Char) -> Bool {
  let scalar = character.to_int()
  is_ascii_uri_scheme_start(character) ||
  (scalar >= '0'.to_int() && scalar <= '9'.to_int()) ||
  character == '+' ||
  character == '-' ||
  character == '.'
}

///|
/// Returns a normalized explicit URI scheme.
fn explicit_hyperlink_uri_scheme(target : StringView) -> String? {
  let trimmed = target.trim()
  match trimmed.split_once(":") {
    None => None
    Some((raw_scheme, _)) => {
      if raw_scheme.length() == 0 {
        return None
      }
      let mut first = true
      for character in raw_scheme {
        if first {
          if !is_ascii_uri_scheme_start(character) {
            return None
          }
          first = false
        } else if !is_ascii_uri_scheme_character(character) {
          return None
        }
      }
      Some(raw_scheme.to_lower().to_owned())
    }
  }
}

///|
fn is_allowed_external_hyperlink_scheme(scheme : StringView) -> Bool {
  match scheme {
    "http"
    | "https"
    | "mailto"
    | "ftp"
    | "ftps"
    | "sftp"
    | "news"
    | "tel"
    | "sms"
    | "file"
    | "about"
    | "ppaction" => true
    _ => false
  }
}

///|
/// Unqualified A1 ranges such as `A1:B2` and `A:A` resemble URI schemes at
/// their first colon. Recognize the complete range before applying the URI
/// scheme guard to workbook-internal locations.
fn is_unqualified_hyperlink_location_range(target : StringView) -> Bool {
  let trimmed = target.trim()
  match trimmed.split_once(":") {
    None => false
    Some((start, end)) => {
      if end.contains(":") {
        return false
      }
      (parse_cell_ref(start) is Some(_) && parse_cell_ref(end) is Some(_)) ||
      (parse_column_ref(start) is Some(_) && parse_column_ref(end) is Some(_)) ||
      (parse_row_ref(start) is Some(_) && parse_row_ref(end) is Some(_))
    }
  }
}

///|
fn validate_hyperlink_xml_text(
  value : StringView,
  field : StringView,
) -> Unit raise XlsxError {
  for character in value {
    if !is_valid_xml_output_character(character) {
      raise InvalidHyperlink(
        msg="\{field} contains forbidden XML code point \{character.to_int()}",
      )
    }
  }
}

///|
fn validate_hyperlink_values(
  target : StringView,
  link_type : HyperlinkType,
  display : StringView,
  tooltip : StringView,
) -> Unit raise XlsxError {
  if target.trim() == "" {
    raise InvalidHyperlink(msg="hyperlink target is empty")
  }
  if target.length() > max_hyperlink_target_chars {
    raise InvalidHyperlink(msg="hyperlink target is too long")
  }
  validate_hyperlink_xml_text(target, "hyperlink target")
  validate_hyperlink_xml_text(display, "hyperlink display")
  validate_hyperlink_xml_text(tooltip, "hyperlink tooltip")
  if link_type == External && target.contains("\\") {
    raise InvalidHyperlink(
      msg="external hyperlink target must use URI forward slashes",
    )
  }
  match explicit_hyperlink_uri_scheme(target) {
    Some(scheme) =>
      match link_type {
        External =>
          if !is_allowed_external_hyperlink_scheme(scheme) {
            raise InvalidHyperlink(
              msg="unsafe external hyperlink scheme '\{scheme}:'",
            )
          }
        Location =>
          if !is_unqualified_hyperlink_location_range(target) {
            raise InvalidHyperlink(
              msg="location hyperlink target must not use URI scheme '\{scheme}:'",
            )
          }
        Unset => ()
      }
    None => ()
  }
}

///|
fn hyperlink_matches_type(link : Hyperlink, link_type : HyperlinkType?) -> Bool {
  match link_type {
    None => true
    Some(Unset) => false
    // Excelize filters External by r:id presence and Location by the
    // location attribute independently, so an external link that also
    // carries a location fragment matches both filters.
    Some(Location) => link.link_type == Location || link.location is Some(_)
    Some(wanted) => link.link_type == wanted
  }
}

///|
test "hyperlink ceiling permits replacement and rejects a new identity" {
  let sheet = Worksheet::new("Sheet1")
  let dummy : Hyperlink = {
    reference: "Z1",
    target: "https://example.com",
    link_type: External,
    location: None,
    display: None,
    tooltip: None,
  }
  let many : Array[Hyperlink] = Array::make(max_sheet_hyperlinks - 1, dummy)
  sheet.hyperlinks.append(many)
  sheet.set_cell_hyperlink("A1", "https://before.example", External)
  inspect(sheet.get_hyperlinks().length(), content="65530")
  sheet.set_cell_hyperlink("A1", "https://after.example", External)
  debug_inspect(
    sheet.get_cell_hyperlink("A1").map(link => link.target),
    content=(
      #|Some("https://after.example")
    ),
  )
  let result : Result[Unit, Error] = Ok(
    sheet.set_cell_hyperlink("B1", "https://example.com", External),
  ) catch {
    e => Err(e)
  }
  debug_inspect(
    result,
    content=(
      #|Err(HyperlinkLimitExceeded(limit=65530))
    ),
  )
}
