///|
fn random_native_fill_incrementing_for_test(
  output : FixedArray[Byte],
  length : Int,
) -> Int {
  for index in 0..<length {
    output[index] = index.to_byte()
  }
  1
}

///|
test "private native secure random bytes wrapper reports raises" {
  let negative : Result[@core.PdfBytes, Error] = try? pdf_secure_random_bytes_with_provider(
    -1,
    fn(_, _) { 1 },
  )
  guard negative is Err(_) else { fail("expected negative length to raise") }

  let unavailable : Result[@core.PdfBytes, Error] = try? pdf_secure_random_bytes_with_provider(
    4,
    fn(_, _) { 0 },
  )
  guard unavailable is Err(_) else {
    fail("expected provider failure to raise")
  }

  @test.assert_eq(
    pdf_secure_random_bytes_with_provider(
      4, random_native_fill_incrementing_for_test,
    ),
    Bytes::from_array([b'\x00', b'\x01', b'\x02', b'\x03']),
  )
}
