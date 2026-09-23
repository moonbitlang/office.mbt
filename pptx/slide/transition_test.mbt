// Tests for the typed slide transition (`<p:transition>`).

///|
/// Wrap a `<p:transition>` string into a parseable `<p:sld>`. The transition
/// follows `<p:cSld>` per CT_Slide ordering. An empty `tr` yields a slide with
/// no transition.
fn slide_with_transition(tr : String) -> FixedArray[Byte] {
  let xml = "<?xml version=\"1.0\"?><p:sld xmlns:p=\"" +
    pml_ns +
    "\" xmlns:a=\"" +
    dml_ns +
    "\" xmlns:r=\"" +
    off_rel_ns +
    "\"><p:cSld><p:spTree>" +
    "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>" +
    "<p:grpSpPr/></p:spTree></p:cSld>" +
    tr +
    "</p:sld>"
  @oxml.string_to_bytes(xml)
}

///|
/// Attach `t` to a minimal slide, serialise, and re-parse — the parser↔writer
/// round-trip used to assert model fidelity across every transition kind.
fn roundtrip_transition(
  t : @slide.Transition,
) -> @slide.Transition? raise @slide.SlideError {
  let base = @slide.Slide::parse(slide_with_transition(""))
  let bytes = base.with_transition(t).serialize()
  @slide.Slide::parse(bytes).transition
}

// --- direction / speed enums: from_xml ∘ to_xml is identity ---

///|
test "transition enums: from_xml round-trips every to_xml value" {
  let speeds : Array[@slide.TransitionSpeed] = [Slow, Medium, Fast]
  for v in speeds {
    debug_inspect(
      @slide.TransitionSpeed::from_xml(v.to_xml()) == v,
      content="true",
    )
  }
  let sides : Array[@slide.TransitionSide] = [Left, Up, Right, Down]
  for v in sides {
    debug_inspect(
      @slide.TransitionSide::from_xml(v.to_xml()) == v,
      content="true",
    )
  }
  let dirs : Array[@slide.TransitionDirection] = [
    Left,
    Up,
    Right,
    Down,
    LeftUp,
    RightUp,
    LeftDown,
    RightDown,
  ]
  for v in dirs {
    debug_inspect(
      @slide.TransitionDirection::from_xml(v.to_xml()) == v,
      content="true",
    )
  }
  let orients : Array[@slide.TransitionOrientation] = [Horizontal, Vertical]
  for v in orients {
    debug_inspect(
      @slide.TransitionOrientation::from_xml(v.to_xml()) == v,
      content="true",
    )
  }
  let inouts : Array[@slide.TransitionInOut] = [In, Out]
  for v in inouts {
    debug_inspect(
      @slide.TransitionInOut::from_xml(v.to_xml()) == v,
      content="true",
    )
  }
  let corners : Array[@slide.TransitionCorner] = [
    LeftUp,
    RightUp,
    LeftDown,
    RightDown,
  ]
  for v in corners {
    debug_inspect(
      @slide.TransitionCorner::from_xml(v.to_xml()) == v,
      content="true",
    )
  }
}

// --- parse: attributes ---

///|
test "transition: parse spd / advClick / advTm attributes" {
  let slide = @slide.Slide::parse(
    slide_with_transition(
      "<p:transition spd=\"slow\" advClick=\"0\" advTm=\"5000\"><p:push dir=\"r\"/></p:transition>",
    ),
  )
  match slide.transition {
    Some(t) => {
      debug_inspect(t.kind, content="Push(Right)")
      debug_inspect(t.speed, content="Slow")
      debug_inspect(t.advance_on_click, content="false")
      debug_inspect(t.advance_after, content="Some(5000)")
    }
    None => fail("expected a transition")
  }
}

///|
test "transition: absent attributes fall back to schema defaults" {
  let slide = @slide.Slide::parse(
    slide_with_transition("<p:transition><p:fade/></p:transition>"),
  )
  match slide.transition {
    Some(t) => {
      debug_inspect(t.kind, content="Fade(false)")
      debug_inspect(t.speed, content="Fast")
      debug_inspect(t.advance_on_click, content="true")
      debug_inspect(t.advance_after is None, content="true")
    }
    None => fail("expected a transition")
  }
}

///|
test "transition: a slide with no <p:transition> has None" {
  let slide = @slide.Slide::parse(slide_with_transition(""))
  debug_inspect(slide.transition is None, content="true")
}

// --- parse: per-kind attribute decoding ---

///|
test "transition: fade thruBlk decodes" {
  let slide = @slide.Slide::parse(
    slide_with_transition(
      "<p:transition><p:fade thruBlk=\"1\"/></p:transition>",
    ),
  )
  match slide.transition {
    Some(t) => debug_inspect(t.kind, content="Fade(true)")
    None => fail("expected a transition")
  }
}

///|
test "transition: split orient + dir decode" {
  let slide = @slide.Slide::parse(
    slide_with_transition(
      "<p:transition><p:split orient=\"vert\" dir=\"in\"/></p:transition>",
    ),
  )
  match slide.transition {
    Some(t) => debug_inspect(t.kind, content="Split(Vertical, In)")
    None => fail("expected a transition")
  }
}

///|
test "transition: wheel spokes decode (explicit + default)" {
  let eight = @slide.Slide::parse(
    slide_with_transition(
      "<p:transition><p:wheel spokes=\"8\"/></p:transition>",
    ),
  )
  match eight.transition {
    Some(t) => debug_inspect(t.kind, content="Wheel(8)")
    None => fail("expected a transition")
  }
  let dflt = @slide.Slide::parse(
    slide_with_transition("<p:transition><p:wheel/></p:transition>"),
  )
  match dflt.transition {
    Some(t) => debug_inspect(t.kind, content="Wheel(4)")
    None => fail("expected a transition")
  }
}

///|
test "transition: cover eight-direction decodes corner value" {
  let slide = @slide.Slide::parse(
    slide_with_transition("<p:transition><p:cover dir=\"ru\"/></p:transition>"),
  )
  match slide.transition {
    Some(t) => debug_inspect(t.kind, content="Cover(RightUp)")
    None => fail("expected a transition")
  }
}

// --- round-trip: every kind ---

///|
test "transition: round-trip across every kind" {
  let kinds : Array[@slide.TransitionKind] = [
    NoEffect,
    Blinds(Horizontal),
    Checker(Vertical),
    Circle,
    Comb(Horizontal),
    Cover(LeftDown),
    Cut(true),
    Diamond,
    Dissolve,
    Fade(false),
    Newsflash,
    Plus,
    Pull(RightUp),
    Push(Down),
    Random,
    RandomBar(Vertical),
    Split(Horizontal, Out),
    Strips(LeftUp),
    Wedge,
    Wheel(3),
    Wipe(Up),
    Zoom(In),
  ]
  for k in kinds {
    let t = @slide.Transition::of_kind(k)
    debug_inspect(roundtrip_transition(t) == Some(t), content="true")
  }
}

///|
test "transition: round-trip preserves speed + advance timing" {
  let t = @slide.Transition::push(Left)
    .with_speed(Medium)
    .with_on_click(false)
    .with_advance_after(3000)
  debug_inspect(roundtrip_transition(t) == Some(t), content="true")
}

// --- builders ---

///|
test "transition: of_kind applies schema defaults" {
  let t = @slide.Transition::of_kind(Dissolve)
  debug_inspect(t.kind, content="Dissolve")
  debug_inspect(t.speed, content="Fast")
  debug_inspect(t.advance_on_click, content="true")
  debug_inspect(t.advance_after is None, content="true")
}

///|
test "transition: convenience constructors" {
  debug_inspect(@slide.Transition::fade().kind, content="Fade(false)")
  debug_inspect(
    @slide.Transition::fade(through_black=true).kind,
    content="Fade(true)",
  )
  debug_inspect(@slide.Transition::cut().kind, content="Cut(false)")
  debug_inspect(@slide.Transition::push(Right).kind, content="Push(Right)")
  debug_inspect(@slide.Transition::wipe(Up).kind, content="Wipe(Up)")
  debug_inspect(@slide.Transition::cover(LeftUp).kind, content="Cover(LeftUp)")
  debug_inspect(
    @slide.Transition::split(Vertical, In).kind,
    content="Split(Vertical, In)",
  )
  debug_inspect(@slide.Transition::zoom(Out).kind, content="Zoom(Out)")
  debug_inspect(@slide.Transition::dissolve().kind, content="Dissolve")
  debug_inspect(@slide.Transition::none().kind, content="NoEffect")
}

///|
test "transition: timing builders" {
  let t = @slide.Transition::fade()
    .with_advance_after(2000)
    .with_on_click(false)
    .with_speed(Slow)
  debug_inspect(t.advance_after, content="Some(2000)")
  debug_inspect(t.advance_on_click, content="false")
  debug_inspect(t.speed, content="Slow")
  debug_inspect(t.without_advance_after().advance_after is None, content="true")
}

// --- Slide builders ---

///|
test "Slide::with_transition / without_transition" {
  let base = @slide.Slide::parse(slide_with_transition(""))
  let with_t = base.with_transition(@slide.Transition::wipe(Right))
  debug_inspect(
    with_t.transition == Some(@slide.Transition::wipe(Right)),
    content="true",
  )
  debug_inspect(with_t.without_transition().transition is None, content="true")
  // with_transition replaces rather than stacks.
  let replaced = with_t.with_transition(@slide.Transition::fade())
  debug_inspect(
    replaced.transition == Some(@slide.Transition::fade()),
    content="true",
  )
}

// --- attribute omission (canonical output) ---

///|
test "transition: default attributes are omitted on serialise" {
  let base = @slide.Slide::parse(slide_with_transition(""))
  // Fast + advance-on-click + no advTm: only the effect child should appear.
  let xml = @oxml.bytes_to_string(
    base.with_transition(@slide.Transition::fade()).serialize(),
  )
  debug_inspect(xml.contains("<p:transition>"), content="true")
  debug_inspect(xml.contains("spd="), content="false")
  debug_inspect(xml.contains("advClick="), content="false")
  // Non-default values are emitted.
  let xml2 = @oxml.bytes_to_string(
    base
    .with_transition(
      @slide.Transition::fade().with_speed(Slow).with_on_click(false),
    )
    .serialize(),
  )
  debug_inspect(xml2.contains("spd=\"slow\""), content="true")
  debug_inspect(xml2.contains("advClick=\"0\""), content="true")
}

// --- lossless preservation ---

///|
test "transition: <p:sndAc> sound child preserved via extension" {
  let slide = @slide.Slide::parse(
    slide_with_transition(
      "<p:transition><p:fade/><p:sndAc><p:stSnd><p:snd r:embed=\"rId9\"/></p:stSnd></p:sndAc></p:transition>",
    ),
  )
  match slide.transition {
    Some(t) => {
      debug_inspect(t.kind, content="Fade(false)")
      debug_inspect(t.extension.length(), content="1")
      debug_inspect(t.extension[0].name.local_name, content="\"sndAc\"")
    }
    None => fail("expected a transition")
  }
  // And it survives a full round-trip.
  let again = @slide.Slide::parse(slide.serialize())
  debug_inspect(again.transition == slide.transition, content="true")
}
