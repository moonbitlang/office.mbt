///|
pub(all) enum HeaderFooterImagePosition {
  Left
  Center
  Right
} derive(Eq, Show)

///|
pub struct HeaderFooterImageOptions {
  position : HeaderFooterImagePosition
  data : Bytes
  extension : String
  is_footer : Bool
  first_page : Bool
  width : String
  height : String
} derive(Eq, Show)

///|
pub fn HeaderFooterImageOptions::new(
  position : HeaderFooterImagePosition,
  data : Bytes,
  extension : String,
  is_footer? : Bool = false,
  first_page? : Bool = false,
  width? : String = "",
  height? : String = "",
) -> HeaderFooterImageOptions {
  { position, data, extension, is_footer, first_page, width, height }
}

///|
struct HeaderFooterImage {
  position : HeaderFooterImagePosition
  data : Bytes
  extension : String
  content_type : String
  is_footer : Bool
  first_page : Bool
  width : String
  height : String
}

///|
fn header_footer_image_shape_id(
  position : HeaderFooterImagePosition,
  is_footer : Bool,
  first_page : Bool,
) -> String {
  let base = match position {
    HeaderFooterImagePosition::Left => "L"
    HeaderFooterImagePosition::Center => "C"
    HeaderFooterImagePosition::Right => "R"
  }
  let mid = if is_footer { "F" } else { "H" }
  let suffix = if first_page { "FIRST" } else { "" }
  "\{base}\{mid}\{suffix}"
}
