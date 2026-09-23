// Run → theme font resolution and the per-script builders.

///|
/// The shape Office actually writes: an empty `ea` slot, with the CJK faces
/// carried by `<a:font script="…">` entries.
fn office_scheme() -> @theme.FontScheme {
  let minor : @theme.FontCollection = {
    latin: "Calibri",
    ea: "",
    cs: "",
    scripts: [
      { script: "Jpan", typeface: "ＭＳ Ｐゴシック", },
      { script: "Arab", typeface: "Times New Roman", },
    ],
    extension: [],
  }
  let major : @theme.FontCollection = {
    latin: "Calibri Light",
    ea: "",
    cs: "",
    scripts: [{ script: "Jpan", typeface: "ＭＳ Ｐ明朝", }],
    extension: [],
  }
  { name: "Office", major_font: major, minor_font: minor, extension: [], }
}

///|
test "resolve_run_fonts: a run with no fonts takes the theme's" {
  let r = @slide.resolve_run_fonts(
    @slide.RunProperties::default(),
    office_scheme(),
  )
  debug_inspect(r.latin, content="\"Calibri\"")
  debug_inspect(r.east_asian, content="\"\"")
  debug_inspect(r.complex_script, content="\"\"")
}

///|
test "resolve_run_fonts: major picks the heading collection" {
  let r = @slide.resolve_run_fonts(
    @slide.RunProperties::default(),
    office_scheme(),
    major=true,
  )
  debug_inspect(r.latin, content="\"Calibri Light\"")
}

///|
test "resolve_run_fonts: theme references are followed, literals are not" {
  // This is what a parsed deck looks like: `latin` holds "+mn-lt", not a font.
  let themed = @slide.RunProperties::default()
    .with_font("+mn-lt")
    .with_east_asian_font("+mj-lt")
  let r = @slide.resolve_run_fonts(themed, office_scheme())
  debug_inspect(r.latin, content="\"Calibri\"")
  debug_inspect(r.east_asian, content="\"Calibri Light\"")
  let literal = @slide.RunProperties::default().with_font("Meiryo UI")
  debug_inspect(
    @slide.resolve_run_fonts(literal, office_scheme()).latin,
    content="\"Meiryo UI\"",
  )
}

///|
test "resolve_run_font_for_script: Japanese resolves through the script entry" {
  // The theme's `ea` slot is empty, so nothing on the
  // run or in `ea` names the font this text actually renders with.
  let scheme = office_scheme()
  let plain = @slide.RunProperties::default()
  debug_inspect(
    @slide.resolve_run_font_for_script(plain, scheme, "Jpan"),
    content="\"ＭＳ Ｐゴシック\"",
  )
  debug_inspect(
    @slide.resolve_run_font_for_script(plain, scheme, "Jpan", major=true),
    content="\"ＭＳ Ｐ明朝\"",
  )
  debug_inspect(
    @slide.resolve_run_font_for_script(plain, scheme, "Arab"),
    content="\"Times New Roman\"",
  )
  // A script with neither an entry nor a slot falls back to latin.
  debug_inspect(
    @slide.resolve_run_font_for_script(plain, scheme, "Hang"),
    content="\"Calibri\"",
  )
}

///|
test "resolve_run_font_for_script: an explicit run font overrides the theme" {
  let rp = @slide.RunProperties::default().with_east_asian_font("Meiryo")
  debug_inspect(
    @slide.resolve_run_font_for_script(rp, office_scheme(), "Jpan"),
    content="\"Meiryo\"",
  )
  // …but a Latin script still uses the Latin slot, not the override.
  debug_inspect(
    @slide.resolve_run_font_for_script(rp, office_scheme(), "Grek"),
    content="\"Calibri\"",
  )
}

///|
test "resolve_run_font_for_script: a reference resolving to empty keeps falling back" {
  // `+mn-ea` points at the theme's empty `ea`; the script entry must still win.
  let rp = @slide.RunProperties::default().with_east_asian_font("+mn-ea")
  debug_inspect(
    @slide.resolve_run_font_for_script(rp, office_scheme(), "Jpan"),
    content="\"ＭＳ Ｐゴシック\"",
  )
}

// --- builders ---

///|
test "with_east_asian_font / with_complex_script_font set only their slot" {
  let rp = @slide.RunProperties::default()
    .with_font("Calibri")
    .with_east_asian_font("Meiryo")
    .with_complex_script_font("Arial")
  debug_inspect(rp.latin, content="Some(\"Calibri\")")
  debug_inspect(rp.east_asian, content="Some(\"Meiryo\")")
  debug_inspect(rp.complex_script, content="Some(\"Arial\")")
}

///|
test "with_font_for_all_scripts sets all three slots" {
  let rp = @slide.RunProperties::default().with_font_for_all_scripts("Meiryo")
  debug_inspect(rp.latin, content="Some(\"Meiryo\")")
  debug_inspect(rp.east_asian, content="Some(\"Meiryo\")")
  debug_inspect(rp.complex_script, content="Some(\"Meiryo\")")
  // And that is enough for CJK to render in it whatever the theme says.
  debug_inspect(
    @slide.resolve_run_font_for_script(rp, office_scheme(), "Jpan"),
    content="\"Meiryo\"",
  )
}
