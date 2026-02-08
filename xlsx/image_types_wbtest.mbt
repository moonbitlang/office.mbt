///|
test "image types wb: normalize image extension rejects dot-only and empty" {
  let dot_only : Result[String, Error] = try? normalize_image_extension(".")
  inspect(dot_only is Err(XlsxError::InvalidSheetBackground(_)), content="true")

  let empty : Result[String, Error] = try? normalize_image_extension("")
  inspect(empty is Err(XlsxError::InvalidSheetBackground(_)), content="true")
}

///|
test "image types wb: content type recognizes tif alias" {
  inspect(image_content_type("tif"), content="Some(\"image/tiff\")")
}
