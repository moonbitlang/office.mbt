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
} derive(Eq, Show)

///|
let max_sheet_hyperlinks = 65529
