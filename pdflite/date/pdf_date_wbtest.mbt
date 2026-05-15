///|
test "private date two-digit parser rejects short input" {
  let result : Result[Int, Error] = try? pdf_date_two_digits(
    @ascii.encode("1"),
    0,
  )
  guard result is Err(PdfError::BadDate) else {
    fail("expected PdfError::BadDate")
  }
}
