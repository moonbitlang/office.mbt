///|
fn approx_eq(a : Double, b : Double) -> Bool {
  (a - b).abs() < 0.000000000001
}

///|
test "hsl to rgb samples" {
  let (r1, g1, b1) = hsl_to_rgb(0.0, 1.0, 0.4)
  assert_eq(r1, (204).to_byte())
  assert_eq(g1, (0).to_byte())
  assert_eq(b1, (0).to_byte())
  let (r2, g2, b2) = hsl_to_rgb(0.0, 1.0, 0.6)
  assert_eq(r2, (255).to_byte())
  assert_eq(g2, (51).to_byte())
  assert_eq(b2, (51).to_byte())
}

///|
test "rgb to hsl samples" {
  let (h1, s1, l1) = rgb_to_hsl((255).to_byte(), (255).to_byte(), (0).to_byte())
  assert_true(approx_eq(h1, 0.16666666666666666))
  assert_true(approx_eq(s1, 1.0))
  assert_true(approx_eq(l1, 0.5))
  let (h2, s2, l2) = rgb_to_hsl((0).to_byte(), (255).to_byte(), (255).to_byte())
  assert_true(approx_eq(h2, 0.5))
  assert_true(approx_eq(s2, 1.0))
  assert_true(approx_eq(l2, 0.5))
  let (h3, s3, l3) = rgb_to_hsl(
    (250).to_byte(),
    (100).to_byte(),
    (50).to_byte(),
  )
  assert_true(approx_eq(h3, 0.041666666666666664))
  assert_true(approx_eq(s3, 0.9523809523809524))
  assert_true(approx_eq(l3, 0.5882352941176471))
  let (h4, s4, l4) = rgb_to_hsl(
    (50).to_byte(),
    (100).to_byte(),
    (250).to_byte(),
  )
  assert_true(approx_eq(h4, 0.625))
  assert_true(approx_eq(s4, 0.9523809523809524))
  assert_true(approx_eq(l4, 0.5882352941176471))
  let (h5, s5, l5) = rgb_to_hsl(
    (250).to_byte(),
    (50).to_byte(),
    (100).to_byte(),
  )
  assert_true(approx_eq(h5, 0.9583333333333334))
  assert_true(approx_eq(s5, 0.9523809523809524))
  assert_true(approx_eq(l5, 0.5882352941176471))
}

///|
test "theme color samples" {
  let results = [
    theme_color("000000", -0.1),
    theme_color("000000", 0.0),
    theme_color("00FF00", 0.2),
    theme_color("000000", 1.0),
    theme_color("!!!!!!", 1.0),
  ]
  debug_inspect(
    results,
    content="[\"FF000000\", \"FF000000\", \"FF33FF33\", \"FFFFFFFF\", \"FFFFFFFF\"]",
  )
}
