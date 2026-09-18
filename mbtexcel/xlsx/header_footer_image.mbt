///|
pub(all) enum HeaderFooterImagePosition {
  Left
  Center
  Right
} derive(Eq, Debug)

///|
pub struct HeaderFooterImageOptions {
  position : HeaderFooterImagePosition
  data : Bytes
  file : String?
  extension : String
  is_footer : Bool
  first_page : Bool
  width : String
  height : String
} derive(Debug)

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
  {
    position,
    data,
    file: None,
    extension,
    is_footer,
    first_page,
    width,
    height,
  }
}

///|
pub fn HeaderFooterImageOptions::from_file(
  position : HeaderFooterImagePosition,
  file : String,
  is_footer? : Bool = false,
  first_page? : Bool = false,
  width? : String = "",
  height? : String = "",
) -> HeaderFooterImageOptions raise XlsxError {
  let extension = match extension_from_path(file) {
    Some(value) => ".\{value}"
    None =>
      raise UnsupportedFeature(msg="unsupported header/footer image extension")
  }
  {
    position,
    data: b"",
    file: Some(file),
    extension,
    is_footer,
    first_page,
    width,
    height,
  }
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
    Left => "L"
    Center => "C"
    Right => "R"
  }
  let mid = if is_footer { "F" } else { "H" }
  let suffix = if first_page { "FIRST" } else { "" }
  "\{base}\{mid}\{suffix}"
}
