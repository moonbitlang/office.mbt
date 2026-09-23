// Modified for office.mbt: follow the workspace warning conventions.
// Tests for `Presentation::set_notes_mut` (speaker notes builder).

///|
test "set_notes_mut: first call creates the notesSlide part + slide rel" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  prs.set_notes_mut(0, "Hello from the notes pane")

  // The notes part landed.
  let notes_part = prs.pkg.part_by_name("/ppt/notesSlides/notesSlide1.xml")
  debug_inspect(notes_part is Some(_), content="true")

  // The source slide gained a rt_notes_slide relationship pointing at it.
  let mut found_rt_notes = false
  for p in prs.pkg.parts() {
    if p.name.has_prefix("/ppt/slides/") && p.name.has_suffix(".xml") {
      let rels = prs.pkg.relationships_for(p.name)
      if !rels.by_type(@opc.rt_notes_slide).is_empty() {
        found_rt_notes = true
      }
    }
  }
  debug_inspect(found_rt_notes, content="true")
}

///|
test "set_notes_mut: notesSlide carries the text in a body placeholder" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  prs.set_notes_mut(0, "Remember to thank the team")
  let notes = prs.notes_slides()
  debug_inspect(notes.length(), content="1")
  let n = notes[0]
  debug_inspect(n.shapes.length(), content="1")
  match n.shapes[0] {
    AutoShape(a) => {
      let ph = a.placeholder.unwrap()
      debug_inspect(ph.ph_type, content="\"body\"")
      debug_inspect(ph.idx, content="1")
      let tb = a.text_body.unwrap()
      debug_inspect(
        tb.paragraphs[0].plain_text(),
        content="\"Remember to thank the team\"",
      )
    }
    _ => fail("expected AutoShape placeholder")
  }
}

///|
test "set_notes_mut: Override content type registered" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  prs.set_notes_mut(0, "notes")
  let cts = prs.pkg.content_types()
  let has_notes_override = cts.overrides
    .iter()
    .any(kv => {
      kv.0 == "/ppt/notesSlides/notesSlide1.xml" && kv.1 == @oxml.ct_notes_slide
    })
  debug_inspect(has_notes_override, content="true")
}

///|
test "set_notes_mut: notesSlide.rels points back at source slide" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  prs.set_notes_mut(0, "x")
  let notes_rels = prs.pkg.relationships_for("/ppt/notesSlides/notesSlide1.xml")
  let back = notes_rels.by_type(@opc.rt_slide)
  debug_inspect(back.length(), content="1")
  debug_inspect(back[0].target.has_suffix(".xml"), content="true")
  debug_inspect(back[0].target_mode is Internal, content="true")
}

///|
test "set_notes_mut: second call replaces bytes, doesn't create a new part" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  prs.set_notes_mut(0, "first version")
  prs.set_notes_mut(0, "second version")
  // Still exactly one notesSlide part.
  let notes_parts = prs.pkg
    .parts()
    .iter()
    .filter(p => p.content_type == @oxml.ct_notes_slide)
    .collect()
  debug_inspect(notes_parts.length(), content="1")
  let n = prs.notes_slides()[0]
  match n.shapes[0] {
    AutoShape(a) =>
      debug_inspect(
        a.text_body.unwrap().paragraphs[0].plain_text(),
        content="\"second version\"",
      )
    _ => fail("expected AutoShape")
  }
}

///|
test "set_notes_mut: out-of-range slide_idx raises Malformed" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  try prs.set_notes_mut(99, "nope") catch {
    Malformed(_) => ()
    _ => fail("expected Malformed")
  } noraise {
    _ => fail("expected Malformed")
  }
}

///|
test "set_notes_mut: full save → reopen round-trips" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  prs.set_notes_mut(0, "round-trip me")
  let bytes = prs.save()
  let prs2 = @presentation.Presentation::open(bytes)
  let notes = prs2.notes_slides()
  debug_inspect(notes.length(), content="1")
  match notes[0].shapes[0] {
    AutoShape(a) =>
      debug_inspect(
        a.text_body.unwrap().paragraphs[0].plain_text(),
        content="\"round-trip me\"",
      )
    _ => fail("expected AutoShape")
  }
}

///|
test "set_notes_mut: XML-special chars in text get escaped safely" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  prs.set_notes_mut(0, "Q&A: <intro> & </outro>")
  let bytes = prs.save()
  let prs2 = @presentation.Presentation::open(bytes)
  match prs2.notes_slides()[0].shapes[0] {
    AutoShape(a) =>
      debug_inspect(
        a.text_body.unwrap().paragraphs[0].plain_text(),
        content="\"Q&A: <intro> & </outro>\"",
      )
    _ => fail("expected AutoShape")
  }
}

// --- notes-master synthesis ---

///|
test "set_notes_mut: synthesises a notesMaster on first call" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  // Before: no notes master in the package.
  let before = prs.pkg
    .parts()
    .iter()
    .filter(p => p.content_type == @oxml.ct_notes_master)
    .count()
  debug_inspect(before, content="0")
  prs.set_notes_mut(0, "first")
  // After: exactly one notesMaster part.
  let after = prs.pkg
    .parts()
    .iter()
    .filter(p => p.content_type == @oxml.ct_notes_master)
    .count()
  debug_inspect(after, content="1")
}

///|
test "set_notes_mut: notesMaster references a duplicate theme (theme2)" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  prs.set_notes_mut(0, "x")
  let nm_rels = prs.pkg.relationships_for("/ppt/notesMasters/notesMaster1.xml")
  let theme_rels = nm_rels.by_type(@opc.rt_theme)
  debug_inspect(theme_rels.length(), content="1")
  // Points at theme2.xml — a duplicate of theme1 that PowerPoint
  // requires for the notes master (sharing the main theme triggers
  // the repair banner).
  debug_inspect(theme_rels[0].target.has_suffix("theme2.xml"), content="true")
  // And the duplicate theme part is actually present.
  debug_inspect(
    prs.pkg.part_by_name("/ppt/theme/theme2.xml") is Some(_),
    content="true",
  )
}

///|
test "set_notes_mut: presentation.xml gains a notesMasterIdLst entry" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  prs.set_notes_mut(0, "x")
  let pres = prs.presentation_part().unwrap()
  debug_inspect(pres.notes_master_id is Some(_), content="true")
}

///|
test "set_notes_mut: second call reuses the existing notesMaster" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  let _ = prs.add_slide_mut(0)
  prs.set_notes_mut(0, "first")
  prs.set_notes_mut(1, "second")
  // Still exactly one notesMaster part.
  let nm_count = prs.pkg
    .parts()
    .iter()
    .filter(p => p.content_type == @oxml.ct_notes_master)
    .count()
  debug_inspect(nm_count, content="1")
}

///|
test "set_notes_mut: notesSlide.rels also points at the notesMaster" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  prs.set_notes_mut(0, "x")
  let nm_in_notes = prs.pkg
    .relationships_for("/ppt/notesSlides/notesSlide1.xml")
    .by_type(@opc.rt_notes_master)
  debug_inspect(nm_in_notes.length(), content="1")
}
