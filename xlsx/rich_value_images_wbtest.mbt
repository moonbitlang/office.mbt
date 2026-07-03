///|
test "parse_rich_values does not create a phantom entry from rvData" {
  let xml =
    #|<?xml version="1.0" encoding="UTF-8"?>
    #|<rvData count="2">
    #|  <rv s="0"><v>0</v><v>alt one</v></rv>
    #|  <rv s="1"><v>2</v></rv>
    #|</rvData>
  let values = parse_rich_values(xml)
  // exactly two rich values, index 0 is the first (not a phantom)
  inspect(values.length(), content="2")
  let (s0, v0) = values[0]
  inspect(s0, content="0")
  debug_inspect(
    v0,
    content=(
      #|["0", "alt one"]
    ),
  )
  let (s1, v1) = values[1]
  inspect(s1, content="1")
  debug_inspect(
    v1,
    content=(
      #|["2"]
    ),
  )
}

///|
test "parse_value_metadata reads block record values" {
  let xml =
    #|<metadata>
    #|  <valueMetadata count="2">
    #|    <bk><rc t="1" v="0"/></bk>
    #|    <bk><rc t="1" v="3"/></bk>
    #|  </valueMetadata>
    #|</metadata>
  debug_inspect(
    parse_value_metadata(xml),
    content=(
      #|[0, 3]
    ),
  )
}

///|
test "parse_rich_value_structures extracts ordered key names" {
  let xml =
    #|<rvStructures count="1">
    #|  <s t="_localImage">
    #|    <k n="_rvRel:LocalImageIdentifier" t="i"/>
    #|    <k n="Text" t="s"/>
    #|  </s>
    #|</rvStructures>
  let structures = parse_rich_value_structures(xml)
  inspect(structures.length(), content="1")
  debug_inspect(
    structures[0],
    content=(
      #|["_rvRel:LocalImageIdentifier", "Text"]
    ),
  )
}

///|
test "parse_rich_value_rel_ids reads ordered relationship ids" {
  let xml =
    #|<richValueRels xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
    #|  <rel r:id="rId1"/>
    #|  <rel r:id="rId2"/>
    #|</richValueRels>
  debug_inspect(
    parse_rich_value_rel_ids(xml),
    content=(
      #|["rId1", "rId2"]
    ),
  )
}
