///|
test "a cloned registry reopens independently after layout has sealed its caller" {
  let registry = @fonts.FontRegistry::new()
  let metrics = @fonts.face("Carlito")
  registry.register_standard("Base", metrics, standard="Helvetica") |> ignore
  registry.face("Base") |> ignore
  let copy = registry.clone()
  assert_true(registry.is_sealed())
  assert_false(copy.is_sealed())
  copy.register_standard("Extra", metrics, standard="Helvetica") |> ignore
  assert_false(registry.is_registered("Extra"))
  assert_true(copy.is_registered("Extra"))
}

///|
test "explicit metrics retain the same typographic values without an OS/2 table" {
  let metrics = @fonts.FaceMetrics::new(
    family="Probe",
    units_per_em=1000,
    ascender=800,
    descender=-200,
    line_gap=100,
    advances=[600],
    cmap=Map([]),
  )
  inspect(metrics.typographic_descent_pt(10), content="-2")
  inspect(metrics.typographic_line_height_pt(10), content="11")
}
