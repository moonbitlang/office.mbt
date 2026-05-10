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
async fn image_external_fixture_bytes_for_test(path : String) -> Bytes? {
  let read_result = try? @fs.read_file(
    image_external_fixture_path_for_test(path),
  )
  match read_result {
    Ok(data) => Some(data.binary())
    Err(_) => None
  }
}

///|
fn image_external_bytes_start_with_at_for_test(
  haystack : BytesView,
  needle : BytesView,
  start : Int,
) -> Bool {
  if start < 0 || start + needle.length() > haystack.length() {
    false
  } else {
    for index in 0..<needle.length() {
      if haystack[start + index] != needle[index] {
        break false
      }
    } nobreak {
      true
    }
  }
}

///|
fn image_external_find_last_bytes_for_test(
  haystack : BytesView,
  needle : BytesView,
) -> Int {
  if needle.length() == 0 {
    haystack.length()
  } else if haystack.length() < needle.length() {
    -1
  } else {
    for start = haystack.length() - needle.length()
        start >= 0
        start = start - 1 {
      if image_external_bytes_start_with_at_for_test(haystack, needle, start) {
        break start
      }
    } nobreak {
      -1
    }
  }
}

///|
fn image_external_push_ascii_for_test(
  output : Array[Byte],
  text : String,
) -> Unit {
  for byte in @ascii.encode(text) {
    output.push(byte)
  }
}

///|
fn image_external_corrupt_startxref_pointer_for_test(
  bytes : Bytes,
) -> Bytes raise {
  let marker = @ascii.encode("startxref\n")
  let marker_position = image_external_find_last_bytes_for_test(bytes, marker)
  if marker_position < 0 {
    fail("expected startxref marker")
  }
  let number_start = marker_position + marker.length()
  let mut number_end = number_start
  while number_end < bytes.length() && bytes[number_end] != b'\n' {
    number_end += 1
  }
  let output : Array[Byte] = []
  for index in 0..<number_start {
    output.push(bytes[index])
  }
  image_external_push_ascii_for_test(
    output,
    (bytes.length() + 4096).to_string(),
  )
  for index in number_end..<bytes.length() {
    output.push(bytes[index])
  }
  Bytes::from_array(output)
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
fn image_external_reparse_compressed_for_test(
  document : @pdflite.PdfDocument,
) -> @pdflite.PdfDocument raise {
  @pdflite.pdf_read_document_from_bytes(
    @pdflite.pdf_write_document_with_compressed_xref_stream(document),
  )
}

///|
fn image_external_assert_jpeg_for_test(
  images : Array[@pdflite.PdfImage],
) -> Unit raise {
  @test.assert_eq(images.length(), 1)
  match images[0] {
    PdfJPEG(data, decode) => {
      @test.assert_eq(data.length() > 40000, true)
      @test.assert_eq(decode, Some([0.0, 1.0, 0.0, 1.0, 0.0, 1.0]))
    }
    _ => fail("expected JPEG image payload")
  }
}

///|
fn image_external_assert_raw_rgb_for_test(
  images : Array[@pdflite.PdfImage],
  width : Int,
  height : Int,
  message : String,
) -> Unit raise {
  @test.assert_eq(images.length(), 1)
  match images[0] {
    PdfRawImage(actual_width, actual_height, layout, data) => {
      @test.assert_eq(actual_width, width)
      @test.assert_eq(actual_height, height)
      @test.assert_eq(layout, PdfBPP24)
      @test.assert_eq(data.length(), width * height * 3)
    }
    _ => fail(message)
  }
}

///|
async test "external DCT image fixture extracts encoded JPEG XObject" {
  match
    image_external_images_from_fixture_for_test(
      "image/external_fixtures/downloads/pdflatex-image.pdf",
    ) {
    None => ()
    Some(images) => image_external_assert_jpeg_for_test(images)
  }
}

///|
async test "external DCT image fixture survives compressed rewrite" {
  match
    image_external_fixture_document_for_test(
      "image/external_fixtures/downloads/pdflatex-image.pdf",
    ) {
    None => ()
    Some(document) => {
      image_external_assert_jpeg_for_test(
        image_external_images_for_test(document),
      )
      let reparsed = image_external_reparse_compressed_for_test(document)
      image_external_assert_jpeg_for_test(
        image_external_images_for_test(reparsed),
      )
    }
  }
}

///|
async test "external DCT image fixture reconstructs xref stream with bad startxref" {
  match
    image_external_fixture_bytes_for_test(
      "image/external_fixtures/downloads/pdflatex-image.pdf",
    ) {
    None => ()
    Some(bytes) => {
      let corrupted = image_external_corrupt_startxref_pointer_for_test(bytes)
      let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
        corrupted,
      )
      guard strict is Err(_) else {
        fail("expected bad startxref to require malformed reconstruction")
      }
      let document = @pdflite.pdf_read_document_from_bytes(corrupted)
      @test.assert_eq(document.first_xref(), 0)
      image_external_assert_jpeg_for_test(
        image_external_images_for_test(document),
      )
      let reparsed = image_external_reparse_compressed_for_test(document)
      image_external_assert_jpeg_for_test(
        image_external_images_for_test(reparsed),
      )
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
    Some(images) =>
      image_external_assert_raw_rgb_for_test(
        images, 16, 16, "expected raw RGB24 image payload",
      )
  }
}

///|
async test "external CCITT image fixture survives compressed rewrite" {
  match
    image_external_fixture_document_for_test(
      "image/external_fixtures/downloads/imagemagick-CCITTFaxDecode.pdf",
    ) {
    None => ()
    Some(document) => {
      image_external_assert_raw_rgb_for_test(
        image_external_images_for_test(document),
        16,
        16,
        "expected raw RGB24 image payload",
      )
      let reparsed = image_external_reparse_compressed_for_test(document)
      image_external_assert_raw_rgb_for_test(
        image_external_images_for_test(reparsed),
        16,
        16,
        "expected raw RGB24 image payload after rewrite",
      )
    }
  }
}

///|
async test "external CCITT image fixture reconstructs malformed startxref" {
  match
    image_external_fixture_bytes_for_test(
      "image/external_fixtures/downloads/imagemagick-CCITTFaxDecode.pdf",
    ) {
    None => ()
    Some(bytes) => {
      let corrupted = image_external_corrupt_startxref_pointer_for_test(bytes)
      let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
        corrupted,
      )
      guard strict is Err(_) else {
        fail("expected bad startxref to require malformed reconstruction")
      }
      let recovered = @pdflite.pdf_read_document_from_bytes(corrupted)
      @test.assert_eq(recovered.first_xref(), 0)
      image_external_assert_raw_rgb_for_test(
        image_external_images_for_test(recovered),
        16,
        16,
        "expected raw RGB24 image payload after reconstruction",
      )
      image_external_assert_raw_rgb_for_test(
        image_external_images_for_test(
          image_external_reparse_compressed_for_test(recovered),
        ),
        16,
        16,
        "expected raw RGB24 image payload after reconstructed rewrite",
      )
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
    Some(images) =>
      image_external_assert_raw_rgb_for_test(
        images, 756, 1008, "expected indexed CMYK image as raw RGB24 payload",
      )
  }
}

///|
async test "external indexed CMYK image fixture survives compressed rewrite" {
  match
    image_external_fixture_document_for_test(
      "image/external_fixtures/downloads/cmyk-image.pdf",
    ) {
    None => ()
    Some(document) => {
      image_external_assert_raw_rgb_for_test(
        image_external_images_for_test(document),
        756,
        1008,
        "expected indexed CMYK image as raw RGB24 payload",
      )
      let reparsed = image_external_reparse_compressed_for_test(document)
      image_external_assert_raw_rgb_for_test(
        image_external_images_for_test(reparsed),
        756,
        1008,
        "expected indexed CMYK image as raw RGB24 payload after rewrite",
      )
    }
  }
}
