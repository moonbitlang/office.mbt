///|
fn normalize_image_extension(extension : StringView) -> String raise XlsxError {
  let value = extension.to_string()
  let trimmed = if value.has_prefix(".") {
    if value.length() <= 1 {
      raise XlsxError::InvalidSheetBackground(msg="image extension missing")
    }
    let view = value[1:] catch {
        _ =>
          raise XlsxError::InvalidSheetBackground(msg="invalid image extension")
      }
    view.to_string()
  } else {
    value
  }
  if trimmed == "" {
    raise XlsxError::InvalidSheetBackground(msg="image extension missing")
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
