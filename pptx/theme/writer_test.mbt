// Theme writer round-trip tests.

///|
/// Parse → serialize → parse, return the second-parse Theme so tests
/// can compare against the first parse.
fn roundtrip_theme(bytes : FixedArray[Byte]) -> @theme.Theme raise {
  let first = @theme.Theme::parse(bytes)
  let serialized = first.serialize()
  @theme.Theme::parse(serialized)
}

///|
test "Theme::serialize: round-trips the office-like fixture" {
  let t0 = @theme.Theme::parse(office_like_theme())
  let t1 = roundtrip_theme(office_like_theme())
  debug_inspect(t0 == t1, content="true")
}

///|
test "Theme::serialize: preserves the theme name attribute" {
  let t1 = roundtrip_theme(office_like_theme())
  debug_inspect(t1.name, content="\"Office Theme\"")
}

///|
test "Theme::serialize: every clrScheme slot round-trips" {
  let t1 = roundtrip_theme(office_like_theme())
  let cs = t1.color_scheme
  // dk1 / lt1 are sysClr; the rest are srgbClr.
  match cs.dk1.base {
    Sys(s) => {
      debug_inspect(s.val, content="\"windowText\"")
      debug_inspect(s.last_clr.unwrap().to_hex(), content="\"000000\"")
    }
    _ => fail("expected Sys for dk1")
  }
  match cs.accent1.base {
    Srgb(rgb) => debug_inspect(rgb.to_hex(), content="\"5B9BD5\"")
    _ => fail("expected Srgb for accent1")
  }
  match cs.fol_hlink.base {
    Srgb(rgb) => debug_inspect(rgb.to_hex(), content="\"954F72\"")
    _ => fail("expected Srgb for folHlink")
  }
}

///|
test "Theme::serialize: fontScheme major/minor + script overrides preserved" {
  let t1 = roundtrip_theme(office_like_theme())
  let major = t1.font_scheme.major_font
  debug_inspect(major.latin, content="\"Calibri Light\"")
  debug_inspect(major.ea, content="\"\"")
  debug_inspect(major.scripts.length(), content="2")
  debug_inspect(major.scripts[0].script, content="\"Jpan\"")
  debug_inspect(major.scripts[0].typeface, content="\"Yu Gothic Light\"")
  let minor = t1.font_scheme.minor_font
  debug_inspect(minor.latin, content="\"Calibri\"")
  debug_inspect(minor.scripts.length(), content="0")
}

///|
test "Theme::serialize: theme-level extensions preserved" {
  // `<a:fmtScheme>`, `<a:objectDefaults>`, `<a:extraClrSchemeLst>` are
  // not modeled and ride on `Theme.extension`. Round-trip via
  // `serialize` → `parse` keeps them.
  let t1 = roundtrip_theme(office_like_theme())
  // The fixture has all three plus the fmtScheme captured inside
  // themeElements (which goes into theme.extension per ADR-004).
  // Order isn't guaranteed across the read/write boundary; check
  // presence by local-name membership.
  let names = t1.extension.map(e => e.name.local_name)
  debug_inspect(names.contains("fmtScheme"), content="true")
  debug_inspect(names.contains("objectDefaults"), content="true")
  debug_inspect(names.contains("extraClrSchemeLst"), content="true")
}

///|
test "Theme::serialize: srgbClr slot with modeled transform round-trips" {
  let xml = "<?xml version=\"1.0\"?><a:theme xmlns:a=\"" +
    drawing +
    "\"><a:themeElements><a:clrScheme name=\"x\">" +
    "<a:dk1><a:srgbClr val=\"000000\"/></a:dk1>" +
    "<a:lt1><a:srgbClr val=\"FFFFFF\"/></a:lt1>" +
    "<a:dk2><a:srgbClr val=\"222222\"/></a:dk2>" +
    "<a:lt2><a:srgbClr val=\"EEEEEE\"/></a:lt2>" +
    // accent1 carries a modifier — the slot wrapper + colour + tint
    // must all survive verbatim.
    "<a:accent1><a:srgbClr val=\"112233\"><a:tint val=\"50000\"/></a:srgbClr></a:accent1>" +
    "<a:accent2><a:srgbClr val=\"112233\"/></a:accent2>" +
    "<a:accent3><a:srgbClr val=\"112233\"/></a:accent3>" +
    "<a:accent4><a:srgbClr val=\"112233\"/></a:accent4>" +
    "<a:accent5><a:srgbClr val=\"112233\"/></a:accent5>" +
    "<a:accent6><a:srgbClr val=\"112233\"/></a:accent6>" +
    "<a:hlink><a:srgbClr val=\"AAAAAA\"/></a:hlink>" +
    "<a:folHlink><a:srgbClr val=\"BBBBBB\"/></a:folHlink>" +
    "</a:clrScheme>" +
    "<a:fontScheme name=\"x\">" +
    "<a:majorFont><a:latin typeface=\"X\"/><a:ea typeface=\"\"/><a:cs typeface=\"\"/></a:majorFont>" +
    "<a:minorFont><a:latin typeface=\"X\"/><a:ea typeface=\"\"/><a:cs typeface=\"\"/></a:minorFont>" +
    "</a:fontScheme>" +
    "</a:themeElements></a:theme>"
  let t0 = @theme.Theme::parse(@oxml.string_to_bytes(xml))
  let t1 = roundtrip_theme(@oxml.string_to_bytes(xml))
  debug_inspect(t0 == t1, content="true")
  debug_inspect(t1.color_scheme.accent1.transforms.length(), content="1")
}
