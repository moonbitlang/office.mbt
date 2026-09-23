// Modified for office.mbt: follow the workspace warning conventions.
// Tests for pinpoint shape editing.
// Reuses `typical_title_slide()` from parser_test.mbt: shapes are
// AutoShape(id=2, "Title 1"), AutoShape(id=3, "Subtitle 2"), Picture(id=4).

///|
/// A slide carrying one unmodelled shape (`<p:contentPart>`), which parses
/// as `Shape::Unknown` — used to check the id/name accessors return `None`.
fn slide_with_unknown_shape() -> FixedArray[Byte] {
  let xml = "<?xml version=\"1.0\"?><p:sld xmlns:p=\"" +
    pml_ns +
    "\" xmlns:a=\"" +
    dml_ns +
    "\"><p:cSld><p:spTree>" +
    "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>" +
    "<p:grpSpPr/>" +
    "<p:contentPart r:id=\"rId9\" xmlns:r=\"" +
    off_rel_ns +
    "\"/>" +
    "</p:spTree></p:cSld></p:sld>"
  @oxml.string_to_bytes(xml)
}

// --- Shape::id / name ---

///|
test "Shape::id / name read every typed variant; Unknown is None" {
  let slide = @slide.Slide::parse(typical_title_slide())
  debug_inspect(slide.shapes[0].id().unwrap(), content="2")
  debug_inspect(slide.shapes[0].name().unwrap(), content="\"Title 1\"")
  debug_inspect(slide.shapes[2].id().unwrap(), content="4") // the picture
  let unknown = @slide.Slide::parse(slide_with_unknown_shape())
  debug_inspect(unknown.shapes[0].id() is None, content="true")
  debug_inspect(unknown.shapes[0].name() is None, content="true")
}

// --- map_shapes ---

///|
test "Slide::map_shapes applies f to every shape" {
  let slide = @slide.Slide::parse(typical_title_slide())
  // Rename every AutoShape; leave other kinds untouched.
  let renamed = slide.map_shapes(s => {
    match s {
      AutoShape(a) => AutoShape({ ..a, name: "X", })
      other => other
    }
  })
  debug_inspect(renamed.shapes[0].name().unwrap(), content="\"X\"")
  debug_inspect(renamed.shapes[1].name().unwrap(), content="\"X\"")
  debug_inspect(renamed.shapes[2].name().unwrap(), content="\"Pic\"") // picture unchanged
  // Original is untouched (immutable, ADR-003).
  debug_inspect(slide.shapes[0].name().unwrap(), content="\"Title 1\"")
}

// --- by index ---

///|
test "Slide::with_shape_at replaces by index" {
  let slide = @slide.Slide::parse(typical_title_slide())
  // Replace shape 0 with a copy of the picture (shape 2).
  let edited = slide.with_shape_at(0, slide.shapes[2])
  debug_inspect(edited.shapes[0].id().unwrap(), content="4")
  debug_inspect(edited.shapes.length(), content="3")
}

///|
test "Slide::with_shape_mapped transforms only the indexed shape" {
  let slide = @slide.Slide::parse(typical_title_slide())
  let edited = slide.with_shape_mapped(1, s => {
    match s {
      AutoShape(a) => AutoShape({ ..a, name: "Only2", })
      other => other
    }
  })
  debug_inspect(edited.shapes[0].name().unwrap(), content="\"Title 1\"") // untouched
  debug_inspect(edited.shapes[1].name().unwrap(), content="\"Only2\"")
}

///|
test "Slide::with_shape_at / mapped / without raise on bad index" {
  let slide = @slide.Slide::parse(typical_title_slide())
  try slide.with_shape_at(99, slide.shapes[0]) catch {
    _ => ()
  } noraise {
    _ => fail("expected an error")
  }
  try slide.with_shape_mapped(-1, s => s) catch {
    _ => ()
  } noraise {
    _ => fail("expected an error")
  }
  try slide.without_shape(99) catch {
    _ => ()
  } noraise {
    _ => fail("expected an error")
  }
}

// --- by id ---

///|
test "Slide::with_shape_by_id transforms the matching shape only" {
  let slide = @slide.Slide::parse(typical_title_slide())
  let edited = slide.with_shape_by_id(3, s => {
    match s {
      AutoShape(a) => AutoShape({ ..a, name: "ById", })
      other => other
    }
  })
  debug_inspect(edited.shapes[0].name().unwrap(), content="\"Title 1\"") // id 2 untouched
  debug_inspect(edited.shapes[1].name().unwrap(), content="\"ById\"") // id 3 changed
  debug_inspect(edited.shapes[2].name().unwrap(), content="\"Pic\"") // id 4 untouched
}

///|
test "Slide::with_shape_by_id raises when the id is absent" {
  let slide = @slide.Slide::parse(typical_title_slide())
  try slide.with_shape_by_id(999, s => s) catch {
    _ => ()
  } noraise {
    _ => fail("expected an error")
  }
}

// --- removal ---

///|
test "Slide::without_shape / without_shape_by_id drop one shape" {
  let slide = @slide.Slide::parse(typical_title_slide())
  let a = slide.without_shape(1)
  debug_inspect(a.shapes.length(), content="2")
  debug_inspect(a.shapes[0].id().unwrap(), content="2")
  debug_inspect(a.shapes[1].id().unwrap(), content="4")
  let b = slide.without_shape_by_id(4)
  debug_inspect(b.shapes.length(), content="2")
  debug_inspect(b.shapes.iter().all(s => s.id() != Some(4)), content="true")
  try slide.without_shape_by_id(999) catch {
    _ => ()
  } noraise {
    _ => fail("expected an error")
  }
}

// --- edits survive serialisation ---

///|
test "an id-targeted rename round-trips through serialize" {
  let slide = @slide.Slide::parse(typical_title_slide())
  let edited = slide.with_shape_by_id(3, s => {
    match s {
      AutoShape(a) => AutoShape({ ..a, name: "Persisted", })
      other => other
    }
  })
  let reparsed = @slide.Slide::parse(edited.serialize())
  debug_inspect(reparsed.shapes[1].name().unwrap(), content="\"Persisted\"")
}

// --- shape id allocation ---

///|
/// A group holding one rectangle, so the recursive id walk has something to
/// descend into. Group children share the slide's `<p:spTree>` id space.
fn group_with_child(group_id : Int, child_id : Int) -> @slide.Shape {
  let child = @slide.AutoShape::rect(
    id=child_id,
    name="Inner",
    x=Emu(0L),
    y=Emu(0L),
    cx=Emu(914_400L),
    cy=Emu(914_400L),
  )
  let g : @slide.GroupShape = {
    id: group_id,
    name: "Group",
    transform: None,
    child_offset: None,
    child_extent: None,
    children: [AutoShape(child)],
    hyperlink: None,
    extension: [],
  }
  Group(g)
}

///|
test "Shape::with_id sets the id on every typed variant" {
  let slide = @slide.Slide::parse(typical_title_slide())
  debug_inspect(slide.shapes[0].with_id(42).id().unwrap(), content="42")
  debug_inspect(slide.shapes[2].with_id(43).id().unwrap(), content="43")
  debug_inspect(
    group_with_child(10, 11).with_id(44).id().unwrap(),
    content="44",
  )
  // Unknown carries no typed id, so it comes back untouched.
  let unknown = @slide.Slide::parse(slide_with_unknown_shape()).shapes[0]
  debug_inspect(unknown.with_id(45) == unknown, content="true")
}

///|
test "Slide::next_shape_id clears the highest id in use" {
  let slide = @slide.Slide::parse(typical_title_slide())
  // ids 2, 3, 4 are taken.
  debug_inspect(slide.next_shape_id(), content="5")
  // A group's child competes for the same id space as its parent.
  let with_group = slide.with_shape(group_with_child(10, 20))
  debug_inspect(with_group.next_shape_id(), content="21")
}

///|
test "Slide::next_shape_id floors at 2 on an empty slide" {
  let empty = @slide.Slide::parse(typical_title_slide()).map_shapes(s => s)
  let cleared = { ..empty, shapes: [], }
  // id 1 belongs to the root spTree, so the first shape id is 2.
  debug_inspect(cleared.next_shape_id(), content="2")
}

///|
test "Slide::with_shape_auto_id renumbers a colliding shape" {
  let slide = @slide.Slide::parse(typical_title_slide())
  // Deliberately reuse id 2, which the title already holds.
  let clashing = @slide.AutoShape(
    @slide.AutoShape::rect(
      id=2,
      name="Clash",
      x=Emu(0L),
      y=Emu(0L),
      cx=Emu(914_400L),
      cy=Emu(914_400L),
    ),
  )
  debug_inspect(slide.with_shape(clashing).duplicate_shape_ids(), content="[2]")
  let fixed = slide.with_shape_auto_id(clashing)
  debug_inspect(fixed.shapes[3].id().unwrap(), content="5")
  debug_inspect(fixed.shapes[3].name().unwrap(), content="\"Clash\"")
  debug_inspect(fixed.duplicate_shape_ids(), content="[]")
}

///|
test "Slide::duplicate_shape_ids reports each clashing id once, ascending" {
  let slide = @slide.Slide::parse(typical_title_slide())
  debug_inspect(slide.duplicate_shape_ids(), content="[]")
  // Two shapes on id 4 and three on id 3 — each id is reported once.
  let clashing = slide
    .with_shape(group_with_child(4, 3))
    .with_shape(
      AutoShape(
        @slide.AutoShape::rect(
          id=3,
          name="Third",
          x=Emu(0L),
          y=Emu(0L),
          cx=Emu(914_400L),
          cy=Emu(914_400L),
        ),
      ),
    )
  debug_inspect(clashing.duplicate_shape_ids(), content="[3, 4]")
}
