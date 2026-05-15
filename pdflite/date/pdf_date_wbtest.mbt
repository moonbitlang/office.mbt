///|
test "private date two-digit parser rejects short input" {
  let result : Result[Int, Error] = try? pdf_date_two_digits(
    @ascii.encode("1"),
    0,
  )
  guard result is Err(@core.PdfError::BadDate) else {
    fail("expected @core.PdfError::BadDate")
  }
}
