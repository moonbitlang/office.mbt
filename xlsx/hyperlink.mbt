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
