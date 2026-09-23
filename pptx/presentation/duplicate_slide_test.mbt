// Modified for office.mbt: follow the workspace warning conventions.
// Slide duplication tests.
//
// `stamp_slide` / `marker_of` are shared with move_slide_test.mbt (same
// blackbox test package).

///|
test "duplicate_slide_mut: appends an identical copy" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  stamp_slide(prs, 0, "Orig")
  let new_name = prs.duplicate_slide_mut(0)
  debug_inspect(new_name, content="\"/ppt/slides/slide2.xml\"")
  let slides = prs.slides()
  debug_inspect(slides.length(), content="2")
  debug_inspect(marker_of(slides[0]), content="\"Orig\"")
  debug_inspect(marker_of(slides[1]), content="\"Orig\"")
}

///|
test "duplicate_slide_mut: new sldId + presentation rel are wired" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  let _ = prs.duplicate_slide_mut(0)
  let pres = prs.presentation_part().unwrap()
  debug_inspect(pres.sld_ids.length(), content="2")
  // Distinct slide ids.
  debug_inspect(pres.sld_ids[0].id != pres.sld_ids[1].id, content="true")
  let pres_rels = prs.opc_package().relationships_for("/ppt/presentation.xml")
  debug_inspect(pres_rels.by_type(@opc.rt_slide).length(), content="2")
}

///|
test "duplicate_slide_mut: clone re-references the source's parts" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  prs.add_picture_mut(
    0,
    fake_png(),
    x=Emu(0L),
    y=Emu(0L),
    cx=Emu(100L),
    cy=Emu(100L),
  )
  let new_name = prs.duplicate_slide_mut(0)
  // Only one image part exists — the clone shares it (shared media reference).
  debug_inspect(
    prs.opc_package().part_by_name("/ppt/media/image1.png") is Some(_),
    content="true",
  )
  debug_inspect(
    prs.opc_package().part_by_name("/ppt/media/image2.png") is None,
    content="true",
  )
  // Both slides' .rels point at the same image target.
  let orig_rels = prs.opc_package().relationships_for("/ppt/slides/slide1.xml")
  let clone_rels = prs.opc_package().relationships_for(new_name)
  debug_inspect(
    orig_rels.by_type(@opc.rt_image).length() ==
    clone_rels.by_type(@opc.rt_image).length(),
    content="true",
  )
  debug_inspect(
    clone_rels.by_type(@opc.rt_image)[0].target,
    content="\"../media/image1.png\"",
  )
}

///|
test "duplicate_slide_mut: save → reopen round-trips both slides" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  stamp_slide(prs, 0, "dupme")
  let _ = prs.duplicate_slide_mut(0)
  let reopened = @presentation.Presentation::open(prs.save())
  let slides = reopened.slides()
  debug_inspect(slides.length(), content="2")
  debug_inspect(marker_of(slides[0]), content="\"dupme\"")
  debug_inspect(marker_of(slides[1]), content="\"dupme\"")
}

///|
test "duplicate_slide_mut: shared image survives deleting the original" {
  // Deletion + duplication together: a clone keeps a shared part alive when the source
  // slide is removed (reference-counted GC sees the clone's reference).
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  prs.add_picture_mut(
    0,
    fake_png(),
    x=Emu(0L),
    y=Emu(0L),
    cx=Emu(100L),
    cy=Emu(100L),
  )
  let _ = prs.duplicate_slide_mut(0)
  prs.remove_slide_mut(0)
  debug_inspect(prs.slides().length(), content="1")
  // The clone still references image1.png, so it must NOT be collected.
  debug_inspect(
    prs.opc_package().part_by_name("/ppt/media/image1.png") is Some(_),
    content="true",
  )
}

///|
test "duplicate_slide_mut: out-of-range index raises Malformed" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  try prs.duplicate_slide_mut(7) catch {
    Malformed(_) => ()
    _ => fail("expected Malformed")
  } noraise {
    _ => fail("expected Malformed")
  }
}

///|
test "with_duplicated_slide: immutable — original unchanged" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  let (bigger, name) = prs.with_duplicated_slide(0)
  debug_inspect(name, content="\"/ppt/slides/slide2.xml\"")
  debug_inspect(prs.slides().length(), content="1")
  debug_inspect(bigger.slides().length(), content="2")
}
