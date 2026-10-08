///|
test "OOXML integer units survive conversion in both directions" {
  let mut angles = 0
  let mut percentages = 0
  for n = -100000; n <= 100000; n = n + 1 {
    if @units.Angle::from_ooxml(n).to_ooxml() != n {
      angles += 1
    }
    if @units.Percentage::from_ooxml(n).to_ooxml() != n {
      percentages += 1
    }
  }
  debug_inspect((angles, percentages), content="(0, 0)")
}
