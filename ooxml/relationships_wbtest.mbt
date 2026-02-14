///|
test "relationships xml" {
  let rels = Relationships::new()
  ignore(rels.add_auto(rel_type="type-a", target="xl/workbook.xml"))
  ignore(
    rels.add_auto(
      rel_type="type-b",
      target="xl/sheet.xml?x=1&y=2",
      target_mode="External",
    ),
  )
  ignore(
    rels.add_auto(
      rel_type="ty<pe>&\"'",
      target="tgt<>&\"'",
      target_mode="Ex<>&\"'",
    ),
  )
  inspect(
    rels.to_xml(),
    content=(
      #|<?xml version="1.0" encoding="UTF-8"?>
      #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
      #|  <Relationship Id="rId1" Type="type-a" Target="xl/workbook.xml"/>
      #|  <Relationship Id="rId2" Type="type-b" Target="xl/sheet.xml?x=1&amp;y=2" TargetMode="External"/>
      #|  <Relationship Id="rId3" Type="ty&lt;pe&gt;&amp;&quot;&apos;" Target="tgt&lt;&gt;&amp;&quot;&apos;" TargetMode="Ex&lt;&gt;&amp;&quot;&apos;"/>
      #|</Relationships>
    ),
  )
}
