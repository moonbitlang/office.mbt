// Modified for office.mbt: follow the workspace warning conventions.
// Tests for the generic typed-placeholder builder.

///|
test "Slide::with_placeholder appends a typed placeholder, idempotent per kind+idx" {
  let s0 = @slide.Slide::parse(slide_with_bg(""))
  let s1 = s0.with_placeholder(Title, 0, text="Hello")
  debug_inspect(s1.title() is Some(_), content="true")
  // Re-setting the same kind+idx replaces rather than duplicates.
  let s2 = s1.with_placeholder(Title, 0, text="Updated")
  debug_inspect(s2.placeholders().length(), content="1")
  // Round-trips through serialize → parse.
  let re = @slide.Slide::parse(s2.serialize())
  debug_inspect(re.placeholders().length(), content="1")
  match re.title() {
    Some(AutoShape(sp)) =>
      debug_inspect(sp.placeholder.unwrap().ph_type, content="\"title\"")
    _ => fail("expected a title AutoShape after round-trip")
  }
}

///|
test "Slide::with_placeholder: distinct idx coexist (two content areas)" {
  let s = @slide.Slide::parse(slide_with_bg(""))
    .with_placeholder(Body, 1, text="Left")
    .with_placeholder(Body, 2, text="Right")
  debug_inspect(s.placeholders().length(), content="2")
}

///|
test "Slide::with_placeholder: no text yields an empty-body placeholder" {
  let s = @slide.Slide::parse(slide_with_bg("")).with_placeholder(Title, 0)
  debug_inspect(s.title() is Some(_), content="true")
  // Survives a round-trip with the placeholder metadata intact.
  let re = @slide.Slide::parse(s.serialize())
  debug_inspect(re.title() is Some(_), content="true")
}
