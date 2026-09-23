// Modified for office.mbt: follow the workspace warning conventions.
// Tests for Presentation::define_master.

///|
fn rect(x : Int64, y : Int64, cx : Int64, cy : Int64) -> @slide.Transform {
  @slide.Transform::new(offset={ x: Emu(x), y: Emu(y), }, extent={
    cx: Emu(cx),
    cy: Emu(cy),
  })
}

///|
fn brand_master() -> @presentation.MasterDefinition {
  @presentation.MasterDefinition::new("Brand")
  .with_placeholder(Title, rect(838200L, 365125L, 10515600L, 1325563L))
  .with_placeholder(
    Body,
    rect(838200L, 1825625L, 10515600L, 4351338L),
    default_text="Click to edit",
  )
  .with_footer("ACME Confidential")
  .with_slide_number(true)
  .with_date(true)
}

///|
test "define_master: appends a master, registered in sldMasterIdLst" {
  let prs = @presentation.Presentation::new()
  let before = prs.slide_masters().length()
  let idx = prs.define_master(brand_master())
  debug_inspect(idx == before, content="true") // appended at the end
  debug_inspect(prs.slide_masters().length() == before + 1, content="true")
  let pres = prs.presentation_part().unwrap()
  debug_inspect(pres.sld_master_ids.length() == before + 1, content="true")
}

///|
test "define_master: master part carries placeholders + footer text" {
  let prs = @presentation.Presentation::new()
  let _ = prs.define_master(brand_master())
  let master = prs.pkg
    .part_by_name("/ppt/slideMasters/slideMaster2.xml")
    .unwrap()
  let xml = @oxml.bytes_to_string(master.bytes)
  debug_inspect(xml.contains("type=\"title\""), content="true")
  debug_inspect(xml.contains("type=\"body\""), content="true")
  debug_inspect(xml.contains("type=\"ftr\""), content="true")
  debug_inspect(xml.contains("type=\"sldNum\""), content="true")
  debug_inspect(xml.contains("type=\"dt\""), content="true")
  debug_inspect(xml.contains("ACME Confidential"), content="true")
  debug_inspect(xml.contains("Click to edit"), content="true")
  debug_inspect(xml.contains("<p:clrMap "), content="true")
  debug_inspect(xml.contains("<p:sldLayoutIdLst>"), content="true")
  // A master without an explicit background still gets the default bgRef
  // (a master with no <p:bg> trips PowerPoint's repair banner).
  debug_inspect(xml.contains("<p:bg>"), content="true")
}

///|
test "define_master: layout part exists and references the master" {
  let prs = @presentation.Presentation::new()
  let _ = prs.define_master(brand_master())
  debug_inspect(
    prs.pkg.part_by_name("/ppt/slideLayouts/slideLayout2.xml") is Some(_),
    content="true",
  )
  // The layout's .rels points back at the master.
  let rels = prs.pkg
    .part_by_name("/ppt/slideLayouts/_rels/slideLayout2.xml.rels")
    .unwrap()
  let rels_xml = @oxml.bytes_to_string(rels.bytes)
  debug_inspect(rels_xml.contains("slideMaster2.xml"), content="true")
}

///|
test "define_master: deck saves and reopens with both masters" {
  let prs = @presentation.Presentation::new()
  let _ = prs.define_master(brand_master())
  let reopened = @presentation.Presentation::open(prs.save())
  debug_inspect(reopened.slide_masters().length(), content="2")
  // The new master + layout survived the zip round-trip.
  debug_inspect(
    reopened.pkg.part_by_name("/ppt/slideMasters/slideMaster2.xml") is Some(_),
    content="true",
  )
  debug_inspect(
    reopened.pkg.part_by_name("/ppt/slideLayouts/slideLayout2.xml") is Some(_),
    content="true",
  )
}

///|
test "define_master: a slide can be added on the new layout" {
  let prs = @presentation.Presentation::new()
  let _ = prs.define_master(brand_master())
  // slide_layouts() now lists the blank layout + the new one; add on the last.
  let last = prs.slide_layouts().length() - 1
  let _ = prs.add_slide_mut(last)
  debug_inspect(prs.slides().length(), content="1")
  // Round-trips.
  let reopened = @presentation.Presentation::open(prs.save())
  debug_inspect(reopened.slides().length(), content="1")
}

///|
test "define_master: new master gets its own theme (repair-clean)" {
  let prs = @presentation.Presentation::new()
  let themes_before = count_theme_parts(prs)
  let _ = prs.define_master(brand_master())
  // A dedicated theme part was added — two masters sharing one theme trips
  // PowerPoint's repair prompt.
  debug_inspect(count_theme_parts(prs) == themes_before + 1, content="true")
  // The new master references a theme other than the original master's.
  let m1 = @oxml.bytes_to_string(
    prs.pkg
    .part_by_name("/ppt/slideMasters/_rels/slideMaster1.xml.rels")
    .unwrap().bytes,
  )
  let m2 = @oxml.bytes_to_string(
    prs.pkg
    .part_by_name("/ppt/slideMasters/_rels/slideMaster2.xml.rels")
    .unwrap().bytes,
  )
  // slideMaster1 uses theme1; slideMaster2 must not.
  debug_inspect(m1.contains("theme1.xml"), content="true")
  debug_inspect(m2.contains("theme1.xml"), content="false")
}

///|
test "define_master: layout declares the placeholders so slides inherit geometry" {
  let prs = @presentation.Presentation::new()
  let _ = prs.define_master(brand_master())
  // The generated layout carries the footer / date / number placeholders
  // (with positions) — without them a slide's footer renders unpositioned.
  let layout = @oxml.bytes_to_string(
    prs.pkg.part_by_name("/ppt/slideLayouts/slideLayout2.xml").unwrap().bytes,
  )
  debug_inspect(layout.contains("type=\"ftr\""), content="true")
  debug_inspect(layout.contains("type=\"dt\""), content="true")
  debug_inspect(layout.contains("type=\"sldNum\""), content="true")
  // …and the footer placeholder has an explicit position to inherit.
  debug_inspect(layout.contains("<a:off x=\"3124200\""), content="true")
}

///|
fn count_theme_parts(prs : @presentation.Presentation) -> Int {
  let mut n = 0
  for p in prs.pkg.parts() {
    if p.name.contains("/ppt/theme/theme") {
      n = n + 1
    }
  }
  n
}

///|
test "define_master: new master id clears existing layout ids (no collision)" {
  let prs = @presentation.Presentation::new()
  let _ = prs.define_master(brand_master())
  let pres = prs.presentation_part().unwrap()
  debug_inspect(pres.sld_master_ids.length(), content="2")
  // slideMaster1 is 2147483648 with its layout at 2147483649; master/layout
  // ids share one space, so the new master must clear 2147483649 (reusing it
  // trips PowerPoint's repair). The first free id is 2147483650.
  debug_inspect(pres.sld_master_ids[1].id >= 2147483650L, content="true")
}

///|
test "MasterDefinition::with_background: master cSld carries the fill" {
  let prs = @presentation.Presentation::new()
  let fill = @oxml.Fill::SolidFill(
    @oxml.Color::srgb(@units.RgbColor::new(0x0A, 0x1B, 0x2C)),
  )
  let def = @presentation.MasterDefinition::new("Tinted").with_background(
    Properties(@slide.BackgroundProperties::of_fill(fill)),
  )
  let idx = prs.define_master(def)
  debug_inspect(idx, content="1") // second master, after the template's own
  let xml = @oxml.bytes_to_string(
    prs.pkg.part_by_name("/ppt/slideMasters/slideMaster2.xml").unwrap().bytes,
  )
  debug_inspect(xml.find("<p:bg>") is Some(_), content="true")
  debug_inspect(xml.find("0A1B2C") is Some(_), content="true")
}
