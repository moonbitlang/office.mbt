///|
fn level(
  format : @numbering.NumberFormat,
  text : String,
  start? : Int = 1,
  restart? : Int? = None,
  is_legal? : Bool = false,
) -> @numbering.Level {
  {
    format,
    text,
    start,
    restart,
    is_legal,
    suffix: SuffTab,
    indent_left: None,
    indent_hanging: None,
  }
}

///|
/// One instance (numId 1) over an abstract definition with the given
/// levels, which is the shape every real numbering.xml has.
fn numbering_of(levels : Array[@numbering.Level]) -> @numbering.Numbering {
  let by_depth : Map[Int, @numbering.Level] = Map([])
  for i, l in levels {
    by_depth[i] = l
  }
  @numbering.Numbering::new({ 100: { levels: by_depth } }, {
    1: { abstract_id: 100, overrides: Map([]), start_overrides: Map([]) },
  })
}

///|
test "counter formats render as Word does" {
  inspect(@numbering.format_counter(1, Decimal), content="1")
  inspect(@numbering.format_counter(42, Decimal), content="42")
  inspect(@numbering.format_counter(1, LowerLetter), content="a")
  inspect(@numbering.format_counter(26, LowerLetter), content="z")
  // OOXML repeats rather than carrying: 27 is "aa", not "ab"
  inspect(@numbering.format_counter(27, LowerLetter), content="aa")
  inspect(@numbering.format_counter(28, LowerLetter), content="bb")
  inspect(@numbering.format_counter(3, UpperLetter), content="C")
  inspect(@numbering.format_counter(4, LowerRoman), content="iv")
  inspect(@numbering.format_counter(9, LowerRoman), content="ix")
  inspect(@numbering.format_counter(1990, UpperRoman), content="MCMXC")
  inspect(@numbering.format_counter(3, Bullet), content="")
}

///|
test "a simple decimal list counts up" {
  let n = numbering_of([level(Decimal, "%1.")])
  let c = @numbering.Counters::new()
  inspect(c.advance(n, 1, 0).unwrap(), content="1.")
  inspect(c.advance(n, 1, 0).unwrap(), content="2.")
  inspect(c.advance(n, 1, 0).unwrap(), content="3.")
}

///|
test "w:start sets the first value" {
  let n = numbering_of([level(Decimal, "%1.", start=5)])
  let c = @numbering.Counters::new()
  inspect(c.advance(n, 1, 0).unwrap(), content="5.")
  inspect(c.advance(n, 1, 0).unwrap(), content="6.")
}

///|
test "bullets print their glyph, not a counter" {
  let n = numbering_of([level(Bullet, "\u{2022}")])
  let c = @numbering.Counters::new()
  inspect(c.advance(n, 1, 0).unwrap(), content="•")
  inspect(c.advance(n, 1, 0).unwrap(), content="•")
}

///|
test "numFmt none shows no label at all" {
  let n = numbering_of([level(NoNumber, "%1.")])
  let c = @numbering.Counters::new()
  assert_true(c.advance(n, 1, 0) is None)
}

///|
test "multi-level lvlText substitutes every ancestor" {
  let n = numbering_of([
    level(Decimal, "%1."),
    level(Decimal, "%1.%2"),
    level(Decimal, "%1.%2.%3"),
  ])
  let c = @numbering.Counters::new()
  inspect(c.advance(n, 1, 0).unwrap(), content="1.")
  inspect(c.advance(n, 1, 1).unwrap(), content="1.1")
  inspect(c.advance(n, 1, 1).unwrap(), content="1.2")
  inspect(c.advance(n, 1, 2).unwrap(), content="1.2.1")
  inspect(c.advance(n, 1, 2).unwrap(), content="1.2.2")
  // back out to the top: sublevels restart
  inspect(c.advance(n, 1, 0).unwrap(), content="2.")
  inspect(c.advance(n, 1, 1).unwrap(), content="2.1")
  inspect(c.advance(n, 1, 2).unwrap(), content="2.1.1")
}

///|
test "mixed formats per level compose in one label" {
  let n = numbering_of([
    level(UpperRoman, "%1."),
    level(UpperLetter, "%1.%2."),
    level(Decimal, "%1.%2.%3"),
  ])
  let c = @numbering.Counters::new()
  inspect(c.advance(n, 1, 0).unwrap(), content="I.")
  inspect(c.advance(n, 1, 1).unwrap(), content="I.A.")
  inspect(c.advance(n, 1, 2).unwrap(), content="I.A.1")
  inspect(c.advance(n, 1, 1).unwrap(), content="I.B.")
}

///|
test "isLgl renders every level decimal" {
  let n = numbering_of([
    level(UpperRoman, "%1."),
    level(UpperLetter, "%1.%2", is_legal=true),
  ])
  let c = @numbering.Counters::new()
  inspect(c.advance(n, 1, 0).unwrap(), content="I.")
  // the legal level shows "1.1", not "I.A"
  inspect(c.advance(n, 1, 1).unwrap(), content="1.1")
}

///|
test "lvlRestart 0 keeps a sublevel counting across parents" {
  let n = numbering_of([
    level(Decimal, "%1."),
    level(Decimal, "%2)", restart=Some(0)),
  ])
  let c = @numbering.Counters::new()
  ignore(c.advance(n, 1, 0))
  inspect(c.advance(n, 1, 1).unwrap(), content="1)")
  inspect(c.advance(n, 1, 1).unwrap(), content="2)")
  // a new top-level item does not reset it
  ignore(c.advance(n, 1, 0))
  inspect(c.advance(n, 1, 1).unwrap(), content="3)")
}

///|
test "startOverride forces a level's first value" {
  let n = @numbering.Numbering::new(
    { 100: { levels: { 0: level(Decimal, "%1.") } } },
    { 1: { abstract_id: 100, overrides: Map([]), start_overrides: { 0: 7 } } },
  )
  let c = @numbering.Counters::new()
  inspect(c.advance(n, 1, 0).unwrap(), content="7.")
  inspect(c.advance(n, 1, 0).unwrap(), content="8.")
}

///|
test "an instance level override beats the abstract definition" {
  let n = @numbering.Numbering::new(
    { 100: { levels: { 0: level(Decimal, "%1.") } } },
    {
      1: {
        abstract_id: 100,
        overrides: { 0: level(UpperLetter, "(%1)") },
        start_overrides: Map([]),
      },
    },
  )
  let c = @numbering.Counters::new()
  inspect(c.advance(n, 1, 0).unwrap(), content="(A)")
}

///|
test "separate numIds count independently" {
  let n = @numbering.Numbering::new(
    { 100: { levels: { 0: level(Decimal, "%1.") } } },
    {
      1: { abstract_id: 100, overrides: Map([]), start_overrides: Map([]) },
      2: { abstract_id: 100, overrides: Map([]), start_overrides: Map([]) },
    },
  )
  let c = @numbering.Counters::new()
  inspect(c.advance(n, 1, 0).unwrap(), content="1.")
  inspect(c.advance(n, 2, 0).unwrap(), content="1.")
  inspect(c.advance(n, 1, 0).unwrap(), content="2.")
  inspect(c.advance(n, 2, 0).unwrap(), content="2.")
}

///|
test "an unknown numId still produces a usable label" {
  let n = @numbering.Numbering::empty()
  let c = @numbering.Counters::new()
  // Word's default for depth 0 is decimal "%1."
  inspect(c.advance(n, 99, 0).unwrap(), content="1.")
  inspect(c.advance(n, 99, 0).unwrap(), content="2.")
}

///|
test "starting at a sublevel uses ancestors' start values" {
  let n = numbering_of([level(Decimal, "%1.", start=1), level(Decimal, "%1.%2")])
  let c = @numbering.Counters::new()
  // no level-0 item yet: the ancestor contributes its start
  inspect(c.advance(n, 1, 1).unwrap(), content="1.1")
}

///|
test "unknown numFmt values fall back to decimal, not blank" {
  debug_inspect(@numbering.number_format("cardinalText"), content="Decimal")
  debug_inspect(@numbering.number_format("ideographDigital"), content="Decimal")
  debug_inspect(@numbering.number_format("bullet"), content="Bullet")
  debug_inspect(@numbering.number_format("none"), content="NoNumber")
  debug_inspect(@numbering.number_format("lowerRoman"), content="LowerRoman")
}
