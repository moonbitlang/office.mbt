///|
fn image_external_fixture_path_for_test(path : String) -> String {
  match @env.current_dir() {
    Some(current_dir) => current_dir + "/" + path
    None => path
  }
}

///|
fn image_external_name_for_test(text : String) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(@ascii.encode(text))
}

///|
async fn image_external_fixture_document_for_test(
  path : String,
) -> @pdflite.PdfDocument? {
  let read_result = try? @fs.read_file(
    image_external_fixture_path_for_test(path),
  )
  match read_result {
    Ok(data) => Some(@pdflite.pdf_read_document_from_bytes(data.binary()))
    Err(_) => None
  }
}

///|
fn image_external_images_for_test(
  document : @pdflite.PdfDocument,
) -> Array[@pdflite.PdfImage] raise {
  let subtype_key = image_external_name_for_test("/Subtype")
  let image_name = image_external_name_for_test("/Image")
  let resources = @pdflite.pdf_dictionary([])
  let images : Array[@pdflite.PdfImage] = []
  for number in document.object_numbers() {
    let object = document.lookup_object_or_null(number)
    if object.lookup_immediate(subtype_key) == Some(PdfNameObject(image_name)) {
      images.push(document.get_image_24bpp(resources, object))
    }
  }
  images
}

///|
async fn image_external_images_from_fixture_for_test(
  path : String,
) -> Array[@pdflite.PdfImage]? {
  match image_external_fixture_document_for_test(path) {
    Some(document) => Some(image_external_images_for_test(document))
    None => None
  }
}

///|
async test "external DCT image fixture extracts encoded JPEG XObject" {
  match
    image_external_images_from_fixture_for_test(
      "image/external_fixtures/downloads/pdflatex-image.pdf",
    ) {
    None => ()
    Some(images) => {
      @test.assert_eq(images.length(), 1)
      match images[0] {
        PdfJPEG(data, decode) => {
          @test.assert_eq(data.length() > 40000, true)
          @test.assert_eq(decode, Some([0.0, 1.0, 0.0, 1.0, 0.0, 1.0]))
        }
        _ => fail("expected JPEG image payload")
      }
    }
  }
}

///|
async test "external CCITT image fixture decodes to RGB24" {
  match
    image_external_images_from_fixture_for_test(
      "image/external_fixtures/downloads/imagemagick-CCITTFaxDecode.pdf",
    ) {
    None => ()
    Some(images) => {
      @test.assert_eq(images.length(), 1)
      match images[0] {
        PdfRawImage(width, height, layout, data) => {
          @test.assert_eq(width, 16)
          @test.assert_eq(height, 16)
          @test.assert_eq(layout, PdfBPP24)
          @test.assert_eq(data.length(), 16 * 16 * 3)
        }
        _ => fail("expected raw RGB24 image payload")
      }
    }
  }
}

///|
async test "external indexed CMYK image fixture decodes to RGB24" {
  match
    image_external_images_from_fixture_for_test(
      "image/external_fixtures/downloads/cmyk-image.pdf",
    ) {
    None => ()
    Some(images) => {
      @test.assert_eq(images.length(), 1)
      match images[0] {
        PdfRawImage(width, height, layout, data) => {
          @test.assert_eq(width, 756)
          @test.assert_eq(height, 1008)
          @test.assert_eq(layout, PdfBPP24)
          @test.assert_eq(data.length(), 756 * 1008 * 3)
        }
        _ => fail("expected indexed CMYK image as raw RGB24 payload")
      }
    }
  }
}
