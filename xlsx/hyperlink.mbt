///|
pub(all) enum HyperlinkType {
  External
  Location
  Unset
} derive(Eq, Show)

///|
pub struct Hyperlink {
  reference : String
  target : String
  link_type : HyperlinkType
  display : String?
  tooltip : String?
} derive(Show)

///|
pub struct HyperlinkOpts {
  mut display : String?
  mut tooltip : String?
} derive(Show)

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
