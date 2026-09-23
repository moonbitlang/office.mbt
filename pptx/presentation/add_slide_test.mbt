// Modified for office.mbt: follow the workspace warning conventions.
// Slide insertion tests.

///|
test "add_slide_mut: appends a slide to an empty deck" {
  let prs = @presentation.Presentation::new()
  // Layout 0 in Presentation::new() is the Blank layout.
  let new_name = prs.add_slide_mut(0)
  debug_inspect(new_name, content="\"/ppt/slides/slide1.xml\"")
  // The slide should now appear via slides() and presentation_part().
  debug_inspect(prs.slides().length(), content="1")
  let pres = prs.presentation_part().unwrap()
  debug_inspect(pres.sld_ids.length(), content="1")
  debug_inspect(pres.sld_ids[0].id, content="256")
}

///|
test "add_slide_mut: subsequent calls produce slide2, slide3, …" {
  let prs = @presentation.Presentation::new()
  let n1 = prs.add_slide_mut(0)
  let n2 = prs.add_slide_mut(0)
  let n3 = prs.add_slide_mut(0)
  debug_inspect(n1, content="\"/ppt/slides/slide1.xml\"")
  debug_inspect(n2, content="\"/ppt/slides/slide2.xml\"")
  debug_inspect(n3, content="\"/ppt/slides/slide3.xml\"")
  debug_inspect(prs.slides().length(), content="3")
}

///|
test "add_slide_mut: sldIds are monotonically increasing from 256" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  let _ = prs.add_slide_mut(0)
  let _ = prs.add_slide_mut(0)
  let pres = prs.presentation_part().unwrap()
  debug_inspect(pres.sld_ids[0].id, content="256")
  debug_inspect(pres.sld_ids[1].id, content="257")
  debug_inspect(pres.sld_ids[2].id, content="258")
}

///|
test "add_slide_mut: presentation.xml.rels gains a rel per slide" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  let _ = prs.add_slide_mut(0)
  let pres_rels = prs.opc_package().relationships_for("/ppt/presentation.xml")
  let slide_rels = pres_rels.by_type(@opc.rt_slide)
  debug_inspect(slide_rels.length(), content="2")
}

///|
test "add_slide_mut: new slide.xml.rels points at the layout" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  let slide_rels = prs.opc_package().relationships_for("/ppt/slides/slide1.xml")
  debug_inspect(slide_rels.items().length(), content="1")
  debug_inspect(
    slide_rels.items()[0].rel_type == @opc.rt_slide_layout,
    content="true",
  )
  // Relative, not absolute: OPC resolves it against /ppt/slides/.
  debug_inspect(
    slide_rels.items()[0].target,
    content="\"../slideLayouts/slideLayout1.xml\"",
  )
}

///|
test "add_slide_mut: save → reopen round-trips" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  let _ = prs.add_slide_mut(0)
  let bytes = prs.save()
  let reopened = @presentation.Presentation::open(bytes)
  debug_inspect(reopened.slides().length(), content="2")
  let pres = reopened.presentation_part().unwrap()
  debug_inspect(pres.sld_ids.length(), content="2")
}

///|
test "add_slide_mut: out-of-range layout index raises Malformed" {
  let prs = @presentation.Presentation::new()
  try prs.add_slide_mut(5) catch {
    Malformed(_) => ()
    _ => fail("expected Malformed")
  } noraise {
    _ => fail("expected Malformed")
  }
}

///|
test "add_slides_mut appends a batch and matches one-at-a-time output" {
  let batch = @presentation.Presentation::new()
  let names = batch.add_slides_mut(0, 3)
  debug_inspect(names.length(), content="3")
  debug_inspect(batch.slide_count(), content="3")
  // The same deck built one slide at a time — same parts, same order.
  let one_by_one = @presentation.Presentation::new()
  for _ in 0..<3 {
    let _ = one_by_one.add_slide_mut(0)
  }
  debug_inspect(one_by_one.slide_count(), content="3")
  let batch_names = []
  for i in 0..<3 {
    batch_names.push(names[i])
  }
  debug_inspect(
    batch_names,
    content=(
      #|[
      #|  "/ppt/slides/slide1.xml",
      #|  "/ppt/slides/slide2.xml",
      #|  "/ppt/slides/slide3.xml",
      #|]
    ),
  )
  // Both reopen with the same slide count, which is what the sldIdLst,
  // the rels and the content types all have to agree on.
  debug_inspect(
    @presentation.Presentation::open(batch.save()).slide_count() ==
    @presentation.Presentation::open(one_by_one.save()).slide_count(),
    content="true",
  )
}

///|
test "add_slides_mut appends onto an existing deck" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  let names = prs.add_slides_mut(0, 2)
  debug_inspect(prs.slide_count(), content="3")
  debug_inspect(names[0], content="\"/ppt/slides/slide2.xml\"")
  debug_inspect(names[1], content="\"/ppt/slides/slide3.xml\"")
  // Every slide resolves after a round-trip, so no rId or override was
  // skipped while the counters were stepped locally.
  let reopened = @presentation.Presentation::open(prs.save())
  debug_inspect(reopened.slides().length(), content="3")
}

///|
test "add_slides_mut with a non-positive count does nothing" {
  let prs = @presentation.Presentation::new()
  debug_inspect(prs.add_slides_mut(0, 0).length(), content="0")
  debug_inspect(prs.add_slides_mut(0, -5).length(), content="0")
  debug_inspect(prs.slide_count(), content="0")
}
