// Modified for office.mbt: follow the workspace warning conventions.
// Font resolution: theme references and per-script fallback.

///|
/// A collection shaped like the ones Office writes: an empty `ea` slot with
/// the real CJK faces carried by `<a:font script="…">` entries instead.
fn office_shaped_collection() -> @theme.FontCollection {
  {
    latin: "Calibri",
    ea: "",
    cs: "",
    scripts: [
      { script: "Jpan", typeface: "ＭＳ Ｐゴシック", },
      { script: "Hans", typeface: "宋体", },
      { script: "Arab", typeface: "Times New Roman", },
    ],
    extension: [],
  }
}

///|
fn scheme_of(
  major : @theme.FontCollection,
  minor : @theme.FontCollection,
) -> @theme.FontScheme {
  { name: "Test", major_font: major, minor_font: minor, extension: [], }
}

///|
test "ThemeFontRef round-trips all six references" {
  let all = [
    @theme.ThemeFontRef::MajorLatin,
    MajorEastAsian,
    MajorComplexScript,
    MinorLatin,
    MinorEastAsian,
    MinorComplexScript,
  ]
  for r in all {
    debug_inspect(
      @theme.ThemeFontRef::from_xml(r.to_xml()) == Some(r),
      content="true",
    )
  }
  debug_inspect(
    @theme.ThemeFontRef::MinorEastAsian.to_xml(),
    content="\"+mn-ea\"",
  )
}

///|
test "ThemeFontRef: a literal typeface is not a reference" {
  debug_inspect(
    @theme.ThemeFontRef::from_xml("Calibri") is None,
    content="true",
  )
  debug_inspect(@theme.ThemeFontRef::from_xml("") is None, content="true")
  // Close but not one of the six.
  debug_inspect(@theme.ThemeFontRef::from_xml("+mn-xx") is None, content="true")
}

///|
test "FontScheme::resolve_typeface follows references and passes literals" {
  let scheme = scheme_of(
    {
      latin: "Calibri Light",
      ea: "Yu Gothic",
      cs: "",
      scripts: [],
      extension: [],
    },
    { latin: "Calibri", ea: "Meiryo", cs: "Arial", scripts: [], extension: [], },
  )
  debug_inspect(scheme.resolve_typeface("+mj-lt"), content="\"Calibri Light\"")
  debug_inspect(scheme.resolve_typeface("+mj-ea"), content="\"Yu Gothic\"")
  debug_inspect(scheme.resolve_typeface("+mn-lt"), content="\"Calibri\"")
  debug_inspect(scheme.resolve_typeface("+mn-ea"), content="\"Meiryo\"")
  debug_inspect(scheme.resolve_typeface("+mn-cs"), content="\"Arial\"")
  // Literals pass straight through.
  debug_inspect(scheme.resolve_typeface("Meiryo UI"), content="\"Meiryo UI\"")
}

///|
test "ScriptSlot::of_script splits east-asian from complex from latin" {
  for s in ["Jpan", "Hans", "Hant", "Hang", "Bopo"] {
    debug_inspect(
      @theme.ScriptSlot::of_script(s) is EastAsianSlot,
      content="true",
    )
  }
  for s in ["Arab", "Hebr", "Thai", "Deva", "Tibt"] {
    debug_inspect(
      @theme.ScriptSlot::of_script(s) is ComplexScriptSlot,
      content="true",
    )
  }
  // Alphabetic scripts and unknown tags both use the Latin slot.
  for s in ["Cyrl", "Grek", "Zzzz"] {
    debug_inspect(@theme.ScriptSlot::of_script(s) is LatinSlot, content="true")
  }
}

///|
test "typeface_for_script: a script entry beats the slot" {
  let c = office_shaped_collection()
  debug_inspect(
    c.typeface_for_script("Jpan"),
    content="\"ＭＳ Ｐゴシック\"",
  )
  debug_inspect(c.typeface_for_script("Hans"), content="\"宋体\"")
  debug_inspect(c.typeface_for_script("Arab"), content="\"Times New Roman\"")
}

///|
test "typeface_for_script: an empty slot falls back to latin, not to nothing" {
  // This is the Office default shape — `<a:ea typeface=""/>` — so a script
  // with no entry must not resolve to the empty string.
  let c = office_shaped_collection()
  debug_inspect(c.typeface_for_script("Hang"), content="\"Calibri\"")
  debug_inspect(c.typeface_for_script("Cyrl"), content="\"Calibri\"")
}

///|
test "typeface_for_script: a populated slot serves scripts with no entry" {
  let c : @theme.FontCollection = {
    latin: "Calibri",
    ea: "Meiryo",
    cs: "Arial",
    scripts: [],
    extension: [],
  }
  debug_inspect(c.typeface_for_script("Jpan"), content="\"Meiryo\"")
  debug_inspect(c.typeface_for_script("Hang"), content="\"Meiryo\"")
  debug_inspect(c.typeface_for_script("Arab"), content="\"Arial\"")
  debug_inspect(c.typeface_for_script("Grek"), content="\"Calibri\"")
}
