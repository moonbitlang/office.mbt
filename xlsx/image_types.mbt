///|
fn normalize_image_extension(extension : StringView) -> String raise XlsxError {
  let value = extension.to_owned()
  let trimmed = match value.strip_prefix(".") {
    Some(rest) => {
      let s = rest.to_owned()
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

///|
priv struct ImagePartIdentity {
  extension : String
  content_type : String
}

///|
fn canonical_image_extension_for_content_type(
  content_type : StringView,
) -> String? {
  match content_type.to_owned().to_lower() {
    "image/bmp" => Some("bmp")
    "image/emf" => Some("emf")
    "image/emz" => Some("emz")
    "image/gif" => Some("gif")
    "image/x-icon" => Some("ico")
    "image/jpeg" => Some("jpeg")
    "image/png" => Some("png")
    "image/svg+xml" => Some("svg")
    "image/tiff" => Some("tiff")
    "image/wmf" => Some("wmf")
    "image/wmz" => Some("wmz")
    _ => None
  }
}

///|
/// Resolves an embedded image's identity from `[Content_Types].xml`, never
/// from a filename guess. A compatible filename extension is preserved (for
/// example `jpg`/`tif`); an override on an unconventional name receives the
/// canonical extension for its declared supported media type.
fn image_part_identity(
  content_types : @ooxml.PackageContentTypes,
  part_name : StringView,
  role : StringView,
  cancelled? : () -> Bool = () => false,
) -> ImagePartIdentity raise XlsxError {
  let declared = declared_part_content_type(
    content_types,
    logical_archive_part_path(part_name),
    role,
    cancelled~,
  )
  let content_type = declared.to_lower()
  let canonical = match
    canonical_image_extension_for_content_type(content_type) {
    Some(value) => value
    None => raise InvalidXml(msg="\{role.to_owned()} content type is invalid")
  }
  let extension = match extension_from_path(part_name) {
    Some(candidate) =>
      match image_content_type(candidate) {
        Some(value) if value == content_type => candidate
        _ => canonical
      }
    None => canonical
  }
  { extension, content_type }
}

///|
fn load_image_part(
  archive : @zip.Archive,
  content_types : @ooxml.PackageContentTypes,
  path : StringView,
  role : StringView,
  cancelled? : () -> Bool = () => false,
) -> (BytesView, ImagePartIdentity) raise XlsxError {
  let bytes = match archive.get(path) {
    Some(value) => value
    None => raise MissingPart(path=path.to_owned())
  }
  let identity = image_part_identity(content_types, path, role, cancelled~)
  (bytes, identity)
}

///|
/// Shared manifest for package-private image reader tests. Production readers
/// always receive the manifest parsed from the archive.
fn image_reader_test_content_types() -> @ooxml.PackageContentTypes {
  try! @ooxml.parse_package_content_types(
    (
      #|<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
      #|  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
      #|  <Default Extension="bmp" ContentType="image/bmp"/>
      #|  <Default Extension="emf" ContentType="image/emf"/>
      #|  <Default Extension="emz" ContentType="image/emz"/>
      #|  <Default Extension="gif" ContentType="image/gif"/>
      #|  <Default Extension="ico" ContentType="image/x-icon"/>
      #|  <Default Extension="jpeg" ContentType="image/jpeg"/>
      #|  <Default Extension="jpg" ContentType="image/jpeg"/>
      #|  <Default Extension="png" ContentType="image/png"/>
      #|  <Default Extension="svg" ContentType="image/svg+xml"/>
      #|  <Default Extension="tif" ContentType="image/tiff"/>
      #|  <Default Extension="tiff" ContentType="image/tiff"/>
      #|  <Default Extension="wmf" ContentType="image/wmf"/>
      #|  <Default Extension="wmz" ContentType="image/wmz"/>
      #|</Types>
      #|
    ),
  )
}

///|
test "image part identity comes from supported manifest declarations" {
  let missing = try! @ooxml.parse_package_content_types(
    "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\"><Default Extension=\"xml\" ContentType=\"application/xml\"/></Types>",
  )
  let conflicting = try! @ooxml.parse_package_content_types(
    "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\"><Default Extension=\"png\" ContentType=\"text/plain\"/></Types>",
  )
  for
    entry in [
      (missing, "drawing image content type is missing"),
      (conflicting, "drawing image content type is invalid"),
    ] {
    let (content_types, expected) = entry
    try
      image_part_identity(content_types, "xl/media/image1.png", "drawing image")
    catch {
      InvalidXml(msg~) => assert_eq(msg, expected)
      _ => fail("unexpected image content-type error")
    } noraise {
      _ => fail("expected image content-type rejection")
    }
  }

  let overridden_types = try! @ooxml.parse_package_content_types(
    "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\"><Default Extension=\"bin\" ContentType=\"application/octet-stream\"/><Override PartName=\"/xl/media/opaque.bin\" ContentType=\"image/png\"/></Types>",
  )
  let identity = image_part_identity(
    overridden_types, "xl/media/opaque.bin", "drawing image",
  )
  assert_eq(identity.extension, "png")
  assert_eq(identity.content_type, "image/png")

  let supported_conflict = try! @ooxml.parse_package_content_types(
    "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\"><Override PartName=\"/xl/media/image1.png\" ContentType=\"image/jpeg\"/></Types>",
  )
  let jpeg = image_part_identity(
    supported_conflict, "xl/media/image1.png", "drawing image",
  )
  assert_eq(jpeg.extension, "jpeg")
  assert_eq(jpeg.content_type, "image/jpeg")
}

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
