///|
/// Mutable set of PDF object numbers used to de-duplicate traversal results.
pub struct PdfNumberSet {
  values : @hashmap.HashMap[Int, Bool]
}

///|
/// Build a number set pre-populated with the given object numbers.
pub fn pdf_number_set(numbers : ArrayView[Int]) -> PdfNumberSet {
  let values : @hashmap.HashMap[Int, Bool] = HashMap([])
  for number in numbers {
    values[number] = true
  }
  { values, }
}

///|
/// Return whether the set already contains `number`.
pub fn PdfNumberSet::contains(self : PdfNumberSet, number : Int) -> Bool {
  self.values.contains(number)
}

///|
/// Add `number` to the set.
pub fn PdfNumberSet::add(self : PdfNumberSet, number : Int) -> Unit {
  self.values[number] = true
}

///|
/// Push `number` into `numbers` only when it has not been seen before.
pub fn pdf_push_unique_number(
  numbers : Array[Int],
  seen : PdfNumberSet,
  number : Int,
) -> Unit {
  if !seen.contains(number) {
    numbers.push(number)
    seen.add(number)
  }
}
