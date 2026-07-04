///|
test "image types wb: normalize image extension rejects dot-only and empty" {
  let dot_only : Result[String, Error] = Ok(normalize_image_extension(".")) catch {
    e => Err(e)
  }
  inspect(dot_only is Err(XlsxError::InvalidSheetBackground(_)), content="true")

  let empty : Result[String, Error] = Ok(normalize_image_extension("")) catch {
    e => Err(e)
  }
  inspect(empty is Err(XlsxError::InvalidSheetBackground(_)), content="true")
}

///|
test "image types wb: content type recognizes tif alias" {
  debug_inspect(image_content_type("tif"), content="Some(\"image/tiff\")")
}
