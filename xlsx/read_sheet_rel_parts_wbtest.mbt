///|
test "read_sheet_rel_parts wb: parse_comment_authors handles missing and malformed entries" {
  inspect(parse_comment_authors("<comments/>"), content="[]")
  let xml =
    #|<comments>
    #|  <authors>
    #|    <author>Alice
    #|    <author>Bob</author>
    #|  </authors>
    #|</comments>
  inspect(parse_comment_authors(xml), content="[\"Bob\"]")
}

///|
test "read_sheet_rel_parts wb: parse_comments_xml edge branches and errors" {
  let no_list =
    #|<comments>
    #|  <authors><author>A</author></authors>
    #|</comments>
  inspect(parse_comments_xml(no_list).length(), content="0")

  let malformed_tag =
    #|<comments>
    #|  <commentList>
    #|    <comment ref="A1"
    #|  </commentList>
    #|</comments>
  let malformed_result : Result[Array[Comment], Error] = try? parse_comments_xml(
    malformed_tag,
  )
  match malformed_result {
    Err(XlsxError::InvalidXml(msg~)) =>
      inspect(msg, content="comment tag not closed")
    _ => fail("expected InvalidXml comment tag not closed")
  }

  let missing_ref =
    #|<comments>
    #|  <commentList>
    #|    <comment authorId="0"><text><t>x</t></text></comment>
    #|  </commentList>
    #|</comments>
  let missing_ref_result : Result[Array[Comment], Error] = try? parse_comments_xml(
    missing_ref,
  )
  match missing_ref_result {
    Err(XlsxError::InvalidXml(msg~)) =>
      inspect(msg, content="comment ref missing")
    _ => fail("expected InvalidXml comment ref missing")
  }

  let mixed =
    #|<comments>
    #|  <authors><author>A</author></authors>
    #|  <commentList>
    #|    <comment ref="A1"></comment>
    #|    <comment ref="B1" authorId="9"><text><r><t>bad</text></comment>
    #|  </commentList>
    #|</comments>
  let comments = parse_comments_xml(mixed)
  inspect(comments.length(), content="2")
  inspect(comments[0].author, content="A")
  inspect(comments[0].text, content="")
  inspect(comments[1].author, content="")
  inspect(comments[1].paragraph.length(), content="0")
}

///|
test "read_sheet_rel_parts wb: parse_table_part_ids supports expanded tags and validates id" {
  let xml =
    #|<worksheet>
    #|  <tableParts count="1">
    #|    <tablePart r:id="rIdTable"></tablePart>
    #|  </tableParts>
    #|</worksheet>
  inspect(parse_table_part_ids(xml), content="[\"rIdTable\"]")

  let missing_id =
    #|<worksheet>
    #|  <tableParts count="1">
    #|    <tablePart />
    #|  </tableParts>
    #|</worksheet>
  let result : Result[Array[String], Error] = try? parse_table_part_ids(
    missing_id,
  )
  match result {
    Err(XlsxError::InvalidXml(msg~)) =>
      inspect(msg, content="tablePart id missing")
    _ => fail("expected InvalidXml tablePart id missing")
  }
}

///|
test "read_sheet_rel_parts wb: parse_pivot_table_part_ids supports expanded tags and validates id" {
  let xml =
    #|<worksheet>
    #|  <pivotTableParts count="1">
    #|    <pivotTablePart r:id="rIdPivot"></pivotTablePart>
    #|  </pivotTableParts>
    #|</worksheet>
  inspect(parse_pivot_table_part_ids(xml), content="[\"rIdPivot\"]")

  let missing_id =
    #|<worksheet>
    #|  <pivotTableParts count="1">
    #|    <pivotTablePart />
    #|  </pivotTableParts>
    #|</worksheet>
  let result : Result[Array[String], Error] = try? parse_pivot_table_part_ids(
    missing_id,
  )
  match result {
    Err(XlsxError::InvalidXml(msg~)) =>
      inspect(msg, content="pivotTablePart id missing")
    _ => fail("expected InvalidXml pivotTablePart id missing")
  }
}
