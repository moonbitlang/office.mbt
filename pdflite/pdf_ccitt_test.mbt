///|
fn ccitt_public_bytes_for_test(
  values : ArrayView[Int],
) -> @pdflite.PdfBytes raise {
  @pdflite.pdf_bytes_of_int_array(values)
}

///|
fn ccitt_public_name_for_test(text : String) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn ccitt_public_wrap_view_for_test(
  prefix : ArrayView[Int],
  data : BytesView,
  suffix : ArrayView[Int],
) -> @pdflite.PdfBytes raise {
  let output : Array[Byte] = []
  for value in prefix {
    output.push(@pdflite.pdf_byte_of_int(value))
  }
  for byte in data {
    output.push(byte)
  }
  for value in suffix {
    output.push(@pdflite.pdf_byte_of_int(value))
  }
  Bytes::from_array(output)
}

///|
fn ccitt_public_decode_stream_for_test(
  encoded : @pdflite.PdfBytes,
  decodeparms_entries : ArrayView[(@pdflite.PdfName, @pdflite.PdfObject)],
) -> @pdflite.PdfBytes raise {
  let stream = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (ccitt_public_name_for_test("/Length"), PdfInteger(encoded.length())),
      (
        ccitt_public_name_for_test("/Filter"),
        PdfNameObject(ccitt_public_name_for_test("/CCITTFaxDecode")),
      ),
      (
        ccitt_public_name_for_test("/DecodeParms"),
        @pdflite.pdf_dictionary(decodeparms_entries),
      ),
    ]),
    StreamGot(encoded),
  )
  guard @pdflite.pdf_decode_stream(stream) is PdfStreamObject(decoded_stream) else {
    fail("expected decoded CCITT stream")
  }
  guard decoded_stream.data is StreamGot(decoded) else {
    fail("expected immediate decoded CCITT stream bytes")
  }
  decoded
}

///|
test "public CCITT Group 3 encoder matches CamlPDF byte helper semantics" {
  let raw = ccitt_public_bytes_for_test([0xF0, 0x00])
  let encoded = @pdflite.pdf_ccitt_encode(8, 2, raw)
  @test.assert_eq(
    encoded,
    ccitt_public_bytes_for_test([0xB6, 0x6A, 0x28, 0x00, 0x80, 0x08]),
  )
  let wrapped = ccitt_public_wrap_view_for_test([0xAA], raw[:], [0x55])
  @test.assert_eq(
    @pdflite.pdf_ccitt_encode_view(8, 2, wrapped[1:wrapped.length() - 1]),
    encoded,
  )
  @test.assert_eq(
    ccitt_public_decode_stream_for_test(encoded, [
      (ccitt_public_name_for_test("/Columns"), PdfInteger(8)),
      (ccitt_public_name_for_test("/Rows"), PdfInteger(2)),
    ]),
    raw,
  )
}

///|
test "public CCITT Group 4 encoder matches CamlPDF byte helper semantics" {
  let raw = ccitt_public_bytes_for_test([0xC0, 0xB0, 0x80])
  let encoded = @pdflite.pdf_ccitt_g4_encode(4, 3, raw)
  let wrapped = ccitt_public_wrap_view_for_test([0xAA, 0xBB], raw[:], [0x55])
  @test.assert_eq(
    @pdflite.pdf_ccitt_g4_encode_view(4, 3, wrapped[2:wrapped.length() - 1]),
    encoded,
  )
  @test.assert_eq(
    ccitt_public_decode_stream_for_test(encoded, [
      (ccitt_public_name_for_test("/K"), PdfInteger(-1)),
      (ccitt_public_name_for_test("/Columns"), PdfInteger(4)),
      (ccitt_public_name_for_test("/Rows"), PdfInteger(3)),
    ]),
    raw,
  )
}
