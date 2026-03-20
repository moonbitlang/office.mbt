///|
fn normalize_image_extension(extension : StringView) -> String raise XlsxError {
  let value = extension.to_string()
  let trimmed = match value.strip_prefix(".") {
    Some(rest) => {
      let s = rest.to_string()
      if s == "" {
        raise InvalidSheetBackground(msg="image extension missing")
      }
      s
    }
    None => value
  }
  if trimmed == "" {
    raise InvalidSheetBackground(msg="image extension missing")
  }
  trimmed.to_lower()
}

///|
fn image_content_type(extension : StringView) -> String? {
  match extension.to_lower() {
    "bmp" => Some("image/bmp")
    "emf" => Some("image/emf")
    "emz" => Some("image/emz")
    "gif" => Some("image/gif")
    "ico" => Some("image/x-icon")
    "jpeg" => Some("image/jpeg")
    "jpg" => Some("image/jpeg")
    "png" => Some("image/png")
    "svg" => Some("image/svg+xml")
    "tif" => Some("image/tiff")
    "tiff" => Some("image/tiff")
    "wmf" => Some("image/wmf")
    "wmz" => Some("image/wmz")
    _ => None
  }
}
