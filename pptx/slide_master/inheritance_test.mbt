// Modified for office.mbt: follow the workspace warning conventions.
// Inheritance resolver tests.
//
// We assemble a small theme + master + layout fixture by hand (rather than
// reusing the parser test fixtures) so each test asserts the exact values
// it depends on.

///|
fn fixed_color_mapping(
  bg1 : @units.ThemeColor,
  tx1 : @units.ThemeColor,
) -> @slide_master.ColorMapping {
  // Most slots are accent1/etc — only the two we vary matter for the
  // tests; the remaining values are just spec-valid filler.
  {
    bg1,
    tx1,
    bg2: Lt2,
    tx2: Dk2,
    accent1: Accent1,
    accent2: Accent2,
    accent3: Accent3,
    accent4: Accent4,
    accent5: Accent5,
    accent6: Accent6,
    hlink: Hlink,
    fol_hlink: FolHlink,
  }
}

///|
fn srgb(hex : String) -> @oxml.Color raise @units.UnitsError {
  @oxml.Color::srgb(@units.RgbColor::parse_hex(hex))
}

///|
fn fixture_scheme() -> @theme.ColorScheme raise @units.UnitsError {
  // Twelve distinct colours so every slot resolves to a unique RGB.
  {
    name: "Test",
    dk1: srgb("000001"),
    lt1: srgb("FFFFF1"),
    dk2: srgb("000002"),
    lt2: srgb("FFFFF2"),
    accent1: srgb("AAAA01"),
    accent2: srgb("AAAA02"),
    accent3: srgb("AAAA03"),
    accent4: srgb("AAAA04"),
    accent5: srgb("AAAA05"),
    accent6: srgb("AAAA06"),
    hlink: srgb("BBBB01"),
    fol_hlink: srgb("BBBB02"),
    extension: [],
  }
}

///|
fn fixture_master() -> @slide_master.SlideMaster {
  // Master maps bg1=lt1 (the standard PPT default), tx1=dk1.
  {
    color_mapping: fixed_color_mapping(Lt1, Dk1),
    layout_refs: [],
    extension: [],
  }
}

///|
fn layout_inheriting() -> @slide_master.SlideLayout {
  {
    name: "Inherits",
    layout_type: Title,
    clr_map_override: MasterMapping,
    extension: [],
  }
}

///|
fn layout_overriding() -> @slide_master.SlideLayout {
  // Layout flips bg1=dk1 (dark slides), tx1=lt1.
  let cm = fixed_color_mapping(Dk1, Lt1)
  {
    name: "Override",
    layout_type: Title,
    clr_map_override: Override(cm),
    extension: [],
  }
}

// --- effective_color_mapping ---

///|
test "MasterMapping → master's clrMap" {
  let cm = @slide_master.effective_color_mapping(
    fixture_master(),
    layout_inheriting(),
  )
  assert_true(cm.bg1 is Lt1)
  assert_true(cm.tx1 is Dk1)
}

///|
test "Override → layout's explicit mapping" {
  let cm = @slide_master.effective_color_mapping(
    fixture_master(),
    layout_overriding(),
  )
  assert_true(cm.bg1 is Dk1)
  assert_true(cm.tx1 is Lt1)
}

// --- resolve_slide_color ---

///|
test "resolve_slide_color: through inherited mapping then theme" {
  // Slide reference bg1, master maps bg1=lt1, theme lt1 = #FFFFF1.
  let result = @slide_master.resolve_slide_color(
    Bg1,
    fixture_master(),
    layout_inheriting(),
    fixture_scheme(),
  )
  match result.unwrap().base {
    Srgb(rgb) => assert_eq(rgb.to_hex(), "FFFFF1")
    _ => fail("expected Srgb")
  }
}

///|
test "resolve_slide_color: layout override takes precedence" {
  // Same slide reference bg1, but the layout overrides to map bg1=dk1.
  // Theme dk1 = #000001.
  let result = @slide_master.resolve_slide_color(
    Bg1,
    fixture_master(),
    layout_overriding(),
    fixture_scheme(),
  )
  match result.unwrap().base {
    Srgb(rgb) => assert_eq(rgb.to_hex(), "000001")
    _ => fail("expected Srgb")
  }
}

///|
test "resolve_slide_color: accent passthrough" {
  // accent3 → accent3 (identity in fixture mapping) → theme accent3
  let result = @slide_master.resolve_slide_color(
    Accent3,
    fixture_master(),
    layout_inheriting(),
    fixture_scheme(),
  )
  match result.unwrap().base {
    Srgb(rgb) => assert_eq(rgb.to_hex(), "AAAA03")
    _ => fail("expected Srgb")
  }
}

///|
test "resolve_slide_color: master-level slot has no slide mapping" {
  // Dk1/Lt1/Dk2/Lt2/PhClr aren't legal mapping inputs, so resolution returns None.
  let none = @slide_master.resolve_slide_color(
    Dk1,
    fixture_master(),
    layout_inheriting(),
    fixture_scheme(),
  )
  assert_true(none is None)
}

// --- lookup_theme_slot ---

///|
test "lookup_theme_slot: bg1 and lt1 resolve to the same slot" {
  let scheme = fixture_scheme()
  let bg1_choice = @slide_master.lookup_theme_slot(Bg1, scheme)
  let lt1_choice = @slide_master.lookup_theme_slot(Lt1, scheme)
  assert_eq(bg1_choice, lt1_choice)
}

///|
test "lookup_theme_slot: tx1 and dk1 resolve to the same slot" {
  let scheme = fixture_scheme()
  let tx1_choice = @slide_master.lookup_theme_slot(Tx1, scheme)
  let dk1_choice = @slide_master.lookup_theme_slot(Dk1, scheme)
  assert_eq(tx1_choice, dk1_choice)
}

///|
test "lookup_theme_slot: each accent maps distinctly" {
  let s = fixture_scheme()
  // Spot-check: accent1 != accent2, accent5 != accent6
  assert_true(
    @slide_master.lookup_theme_slot(Accent1, s) !=
    @slide_master.lookup_theme_slot(Accent2, s),
  )
  assert_true(
    @slide_master.lookup_theme_slot(Accent5, s) !=
    @slide_master.lookup_theme_slot(Accent6, s),
  )
}
