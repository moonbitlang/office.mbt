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
let max_sheet_hyperlinks = 65529

///|
/// Keeps every writer-produced relationship start tag below the default
/// 16 MiB OOXML-part ceiling even when every character needs XML escaping.
let max_hyperlink_target_chars : Int = 1024 * 1024

///|
test "hyperlink limit exceeded" {
  let sheet = Worksheet::new("Sheet1")
  let dummy : Hyperlink = {
    reference: "Z1",
    target: "",
    link_type: External,
    location: None,
    display: None,
    tooltip: None,
  }
  let many : Array[Hyperlink] = Array::make(65530, dummy)
  sheet.hyperlinks.append(many)
  let result : Result[Unit, Error] = Ok(
    sheet.set_cell_hyperlink("A1", "https://example.com", External),
  ) catch {
    e => Err(e)
  }
  inspect(result is Err(HyperlinkLimitExceeded(_)), content="true")
}
