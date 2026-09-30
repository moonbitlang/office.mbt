///|
/// `FaceMetrics::new` with `advances`, `cmap` and `units_per_em` as given
/// and plausible vertical metrics, or the error it raises as text.
fn built(
  advances : Array[Int],
  cmap : Map[Int, Int],
  units_per_em? : Int = 1000,
) -> Result[@fonts.FaceMetrics, String] {
  Ok(
    @fonts.FaceMetrics::new(
      family="Probe",
      units_per_em~,
      ascender=718,
      descender=-207,
      line_gap=231,
      advances~,
      cmap~,
    ),
  ) catch {
    e => Err(e.to_string())
  }
}

///|
test "FaceMetrics::new builds a face that measures with what it was given" {
  guard built([500, 600], Map([(0x41, 1)])) is Ok(face) else {
    fail("expected a face")
  }
  inspect(face.advance_pt(0x41, 10.0), content="6")
  // a character the cmap lacks takes glyph 0's advance
  inspect(face.advance_pt(0x42, 10.0), content="5")
  inspect(face.has_char(0x41), content="true")
  inspect(face.line_height_pt(10.0), content="11.56")
}

///|
test "FaceMetrics::new copies its tables" {
  let advances = [500, 600]
  let cmap : Map[Int, Int] = Map([(0x41, 1)])
  guard built(advances, cmap) is Ok(face) else { fail("expected a face") }
  advances[1] = 9999
  cmap[0x41] = 0
  inspect(face.advance_pt(0x41, 10.0), content="6")
}

///|
test "FaceMetrics::new refuses metrics a face could not measure with" {
  let error = fn(result : Result[@fonts.FaceMetrics, String]) {
    match result {
      Ok(_) => "accepted"
      Err(message) => message
    }
  }
  // no advances at all: every lookup would index an empty table
  inspect(
    error(built([], Map([]))),
    content="invalid face metrics for Probe: no advances",
  )
  // units_per_em of zero would scale every advance to infinity
  inspect(
    error(built([500], Map([]), units_per_em=0)),
    content="invalid face metrics for Probe: units_per_em 0 is not positive",
  )
  inspect(
    error(built([500], Map([]), units_per_em=-1000)),
    content="invalid face metrics for Probe: units_per_em -1000 is not positive",
  )
  // a glyph index outside the advances
  inspect(
    error(built([500], Map([(0x41, -1)]))),
    content="invalid face metrics for Probe: U+0041 maps to glyph -1, outside the 1 advances",
  )
  inspect(
    error(built([500], Map([(0x41, 1)]))),
    content="invalid face metrics for Probe: U+0041 maps to glyph 1, outside the 1 advances",
  )
  // a key that is no codepoint
  inspect(
    error(built([500], Map([(-5, 0)]))),
    content="invalid face metrics for Probe: -5 is not a codepoint",
  )
  // a negative advance
  inspect(
    error(built([500, -1], Map([]))),
    content="invalid face metrics for Probe: glyph 1 advances by -1",
  )
}
