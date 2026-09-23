// Modified for office.mbt: follow the workspace warning conventions.
// Immutable builder tests.

///|
test "with_added_slide: original presentation untouched" {
  let prs0 = @presentation.Presentation::new()
  let (prs1, name) = prs0.with_added_slide(layout_index=0)
  debug_inspect(name, content="\"/ppt/slides/slide1.xml\"")
  // Original has no slides; new value has one.
  debug_inspect(prs0.slides().length(), content="0")
  debug_inspect(prs1.slides().length(), content="1")
}

///|
test "with_added_slide: chained calls accumulate independently" {
  let prs0 = @presentation.Presentation::new()
  let (prs1, _) = prs0.with_added_slide(layout_index=0)
  let (prs2, _) = prs1.with_added_slide(layout_index=0)
  debug_inspect(prs0.slides().length(), content="0")
  debug_inspect(prs1.slides().length(), content="1")
  debug_inspect(prs2.slides().length(), content="2")
}

///|
test "with_slide_updated: original presentation's slide untouched" {
  let prs0 = @presentation.Presentation::new()
  let (prs1, _) = prs0.with_added_slide(layout_index=0)
  // The added slide is empty.
  debug_inspect(prs1.slides()[0].shapes.length(), content="0")
  let tb = @slide.AutoShape::textbox(
    id=2,
    name="T",
    x=Emu(0L),
    y=Emu(0L),
    cx=Emu(100L),
    cy=Emu(100L),
    "Hi",
  )
  let s = prs1.slides()[0]
  let prs2 = prs1.with_slide_updated(0, s.with_shape(AutoShape(tb)))
  // prs1's slide is still empty; prs2's has the textbox.
  debug_inspect(prs1.slides()[0].shapes.length(), content="0")
  debug_inspect(prs2.slides()[0].shapes.length(), content="1")
}

///|
test "with_added_slide + with_slide_updated: save + reopen round-trips" {
  let prs = @presentation.Presentation::new()
  let (prs, _) = prs.with_added_slide(layout_index=0)
  let s = prs.slides()[0]
  let tb = @slide.AutoShape::textbox(
    id=2,
    name="T",
    x=Emu(0L),
    y=Emu(0L),
    cx=Emu(914400L),
    cy=Emu(457200L),
    "Immutable!",
  )
  let prs = prs.with_slide_updated(0, s.with_shape(AutoShape(tb)))
  let bytes = prs.save()
  let reopened = @presentation.Presentation::open(bytes)
  let slides = reopened.slides()
  debug_inspect(slides.length(), content="1")
  match slides[0].shapes[0] {
    AutoShape(a) =>
      debug_inspect(a.text_body.unwrap().plain_text(), content="\"Immutable!\"")
    _ => fail("expected AutoShape")
  }
}

///|
test "Presentation::clone: cloned package mutation doesn't reach original" {
  let prs0 = @presentation.Presentation::new()
  let prs1 = prs0.clone()
  // Mutate the clone via the existing `_mut` API.
  let _ = prs1.add_slide_mut(0)
  debug_inspect(prs0.slides().length(), content="0")
  debug_inspect(prs1.slides().length(), content="1")
}

///|
test "with_added_slide: out-of-range layout raises Malformed" {
  let prs = @presentation.Presentation::new()
  try prs.with_added_slide(layout_index=99) catch {
    Malformed(_) => ()
    _ => fail("expected Malformed")
  } noraise {
    _ => fail("expected Malformed")
  }
}
