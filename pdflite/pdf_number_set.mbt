///|
priv struct PdfNumberSet {
  values : @hashmap.HashMap[Int, Bool]
}

///|
fn pdf_number_set(numbers : ArrayView[Int]) -> PdfNumberSet {
  let values : @hashmap.HashMap[Int, Bool] = @hashmap.HashMap::new()
  for number in numbers {
    values[number] = true
  }
  { values, }
}

///|
fn PdfNumberSet::contains(self : PdfNumberSet, number : Int) -> Bool {
  self.values.contains(number)
}

///|
fn PdfNumberSet::add(self : PdfNumberSet, number : Int) -> Unit {
  self.values[number] = true
}

///|
fn pdf_push_unique_number(
  numbers : Array[Int],
  seen : PdfNumberSet,
  number : Int,
) -> Unit {
  if !seen.contains(number) {
    numbers.push(number)
    seen.add(number)
  }
}
