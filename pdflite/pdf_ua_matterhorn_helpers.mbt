///|
fn pdf_ua_matterhorn_int_array_contains(
  values : ArrayView[Int],
  target : Int,
) -> Bool {
  for value in values {
    if value == target {
      return true
    }
  }
  false
}
