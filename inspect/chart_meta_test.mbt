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
      #|[]
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
