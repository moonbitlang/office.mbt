// Tests for the chart-XML metadata scanner. Inputs are synthetic fragments
// shaped like the retained `c:chart` markup, including malformed ones — the
// scanner must degrade gracefully, never panic.

///|
test "chart_kinds finds combo kinds once each, in canonical order" {
  let xml =
    #|<c:chart><c:plotArea><c:barChart><c:ser/></c:barChart>
    #|<c:lineChart attr="1"><c:ser/></c:lineChart>
    #|<c:barChart></c:barChart></c:plotArea></c:chart>
  debug_inspect(
    @inspect.chart_kinds(xml),
    content=(
      #|["barChart", "lineChart"]
    ),
  )
  debug_inspect(
    @inspect.chart_kinds("<c:chart/>"),
    content=(
      #|[]
    ),
  )
}

///|
test "chart_series extracts tx/cat/val refs" {
  let xml =
    #|<c:ser><c:tx><c:strRef><c:f>Data!$B$1</c:f></c:strRef></c:tx>
    #|<c:cat><c:numRef><c:f>Data!$A$2:$A$6</c:f></c:numRef></c:cat>
    #|<c:val><c:numRef><c:f>Data!$B$2:$B$6</c:f></c:numRef></c:val></c:ser>
    #|<c:ser><c:val><c:numRef><c:f>Data!$C$2:$C$6</c:f></c:numRef></c:val></c:ser>
  debug_inspect(
    @inspect.chart_series(xml),
    content=(
      #|[
      #|  {
      #|    name: Some("Data!$B$1"),
      #|    categories: Some("Data!$A$2:$A$6"),
      #|    values: Some("Data!$B$2:$B$6"),
      #|  },
      #|  { name: None, categories: None, values: Some("Data!$C$2:$C$6") },
      #|]
    ),
  )
}

///|
test "chart_series maps scatter xVal/yVal to categories/values" {
  let xml =
    #|<c:ser><c:xVal><c:numRef><c:f>Data!$A$2:$A$9</c:f></c:numRef></c:xVal>
    #|<c:yVal><c:numRef><c:f>Data!$B$2:$B$9</c:f></c:numRef></c:yVal></c:ser>
  debug_inspect(
    @inspect.chart_series(xml),
    content=(
      #|[
      #|  {
      #|    name: None,
      #|    categories: Some("Data!$A$2:$A$9"),
      #|    values: Some("Data!$B$2:$B$9"),
      #|  },
      #|]
    ),
  )
}

///|
test "chart_series tolerates malformed fragments" {
  // Unclosed series block: scanned to the end, no panic.
  debug_inspect(
    @inspect.chart_series("<c:ser><c:val><c:f>Data!$B$2</c:f>"),
    content=(
      #|[{ name: None, categories: None, values: None }]
    ),
  )
  // Empty ref and missing f: both dropped.
  debug_inspect(
    @inspect.chart_series(
      "<c:ser><c:val><c:f></c:f></c:val><c:cat></c:cat></c:ser>",
    ),
    content=(
      #|[{ name: None, categories: None, values: None }]
    ),
  )
  debug_inspect(
    @inspect.chart_series(""),
    content=(
      #|[]
    ),
  )
}

///|
test "chart scanner handles attributes, whitespace, and self-closing tags" {
  // `<c:ser >` (trailing space), a kind whose `>` is on the next line, an
  // attributed inner element, and a self-closing `<c:tx/>` are all valid XML.
  let xml =
    #|<c:barChart
    #|><c:ser ><c:tx/>
    #|<c:cat foo="1"><c:numRef><c:f>Data!$A$1:$A$3</c:f></c:numRef></c:cat>
    #|<c:val><c:numRef><c:f>Data!$B$1:$B$3</c:f></c:numRef></c:val></c:ser></c:barChart>
  debug_inspect(
    @inspect.chart_kinds(xml),
    content=(
      #|["barChart"]
    ),
  )
  debug_inspect(
    @inspect.chart_series(xml),
    content=(
      #|[
      #|  {
      #|    name: None,
      #|    categories: Some("Data!$A$1:$A$3"),
      #|    values: Some("Data!$B$1:$B$3"),
      #|  },
      #|]
    ),
  )
}

///|
test "tag matching requires a delimiter" {
  // `<c:serAx>` and `<c:barCharting>` must not match `c:ser`/`c:barChart`.
  debug_inspect(
    @inspect.chart_series("<c:serAx><c:val><c:f>X!$A$1</c:f></c:val></c:serAx>"),
    content=(
      #|[]
    ),
  )
  debug_inspect(
    @inspect.chart_kinds("<c:barCharting><x/></c:barCharting>"),
    content=(
      #|[]
    ),
  )
}

///|
test "chart refs are XML-entity-decoded" {
  let xml =
    #|<c:ser><c:val><c:numRef><c:f>'R&amp;D &lt;EU&gt; &#65;&#x42;'!$A$1</c:f></c:numRef></c:val></c:ser>
  debug_inspect(
    @inspect.chart_series(xml),
    content=(
      #|[{ name: None, categories: None, values: Some("'R&D <EU> AB'!$A$1") }]
    ),
  )
  // Unknown and unterminated entities pass through verbatim.
  let odd =
    #|<c:ser><c:val><c:f>A&unknown;B&amp</c:f></c:val></c:ser>
  debug_inspect(
    @inspect.chart_series(odd),
    content=(
      #|[{ name: None, categories: None, values: Some("A&unknown;B&amp") }]
    ),
  )
}

///|
test "scanner ignores comments and reads CDATA as text" {
  // A commented-out chart kind is not a kind; markup inside CDATA is data.
  debug_inspect(
    @inspect.chart_kinds(
      "<!-- <c:barChart> --><c:lineChart><c:ser/></c:lineChart>",
    ),
    content=(
      #|["lineChart"]
    ),
  )
  debug_inspect(
    @inspect.chart_kinds("<x><![CDATA[<c:barChart>]]></x>"),
    content=(
      #|[]
    ),
  )
  // A CDATA-wrapped c:f still yields its (decoded) text.
  let xml =
    #|<c:ser><c:val><c:numRef><c:f><![CDATA['A&B <raw>'!$A$1]]></c:f></c:numRef></c:val></c:ser>
  debug_inspect(
    @inspect.chart_series(xml),
    content=(
      #|[{ name: None, categories: None, values: Some("'A&B <raw>'!$A$1") }]
    ),
  )
}

///|
test "quoted attribute values may contain markup characters" {
  // The `/>` inside the attribute must not read as self-closing, and the
  // series content after it must be found.
  let xml =
    #|<c:ser note="/>"><c:val><c:numRef><c:f>D!$B$1</c:f></c:numRef></c:val></c:ser>
  debug_inspect(
    @inspect.chart_series(xml),
    content=(
      #|[{ name: None, categories: None, values: Some("D!$B$1") }]
    ),
  )
}

///|
test "a self-closing series does not swallow later series" {
  let xml =
    #|<c:ser/><c:ser><c:val><c:numRef><c:f>D!$C$1</c:f></c:numRef></c:val></c:ser>
  debug_inspect(
    @inspect.chart_series(xml),
    content=(
      #|[
      #|  { name: None, categories: None, values: None },
      #|  { name: None, categories: None, values: Some("D!$C$1") },
      #|]
    ),
  )
}

///|
test "numeric character references decode across the full Unicode range" {
  let xml =
    #|<c:ser><c:val><c:f>&#0000065;&#1114111;&#x10FFFF;&#1114112;</c:f></c:val></c:ser>
  debug_inspect(
    @inspect.chart_series(xml),
    content=(
      #|[{ name: None, categories: None, values: Some("A􏿿􏿿&#1114112;") }]
    ),
  )
}

///|
test "processing instructions are not chart structure" {
  // A PI whose data contains "<!--" must not open a phantom comment that
  // swallows the real chart, and markup inside a PI is not structure.
  debug_inspect(
    @inspect.chart_kinds(
      "<?agent <!--?><c:chart><c:barChart><c:ser/></c:barChart></c:chart>",
    ),
    content=(
      #|["barChart"]
    ),
  )
  debug_inspect(
    @inspect.chart_kinds("<?pi <c:lineChart> ?>"),
    content=(
      #|[]
    ),
  )
  // Unterminated PI: the rest is PI data.
  debug_inspect(
    @inspect.chart_kinds("<?pi <c:barChart>"),
    content=(
      #|[]
    ),
  )
}
