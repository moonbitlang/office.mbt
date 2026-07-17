///|
fn parse_comment_authors(xml : StringView) -> Array[String] raise XlsxError {
  let authors : Array[String] = []
  let body = match extract_tag_body(xml, "authors") {
    Some(value) => value
    None => return authors
  }
  let mut first = true
  for chunk in body.split("<author>") {
    if first {
      first = false
      continue
    }
    let text = chunk.to_owned()
    let end = match text.find("</author>") {
      Some(pos) => pos
      None => continue
    }
    let name = unescape_xml_text(text[:end])
    authors.push(name)
  }
  authors
}

///|
fn parse_comments_xml(xml : StringView) -> Array[Comment] raise XlsxError {
  let comments : Array[Comment] = []
  let authors = parse_comment_authors(xml)
  let body = match extract_tag_body(xml, "commentList") {
    Some(value) => value
    None => return comments
  }
  let mut first = true
  for chunk in body.split("<comment ") {
    if first {
      first = false
      continue
    }
    let text = chunk.to_owned()
    let end = match text.find(">") {
      Some(pos) => pos
      None => raise InvalidXml(msg="comment tag not closed")
    }
    let tag = text[:end]
    let ref_value = match attr_value(tag, "ref") {
      Some(value) => value
      None => raise InvalidXml(msg="comment ref missing")
    }
    let (row, col) = cell_ref_to_rc(ref_value)
    let cell = cell_ref_from(row, col)
    let author_id = match attr_value(tag, "authorId") {
      Some(value) => @string.parse_int(value, base=10) catch { _ => 0 }
      None => 0
    }
    let author = if author_id >= 0 && author_id < authors.length() {
      authors[author_id]
    } else {
      ""
    }
    let rest = text[end + 1:]
    let text_body = match extract_tag_body_from(rest, "text") {
      Some(value) => value
      None => ""
    }
    let paragraph = if text_body.contains("<r") {
      parse_rich_text_runs(text_body) catch {
        _ => []
      }
    } else {
      []
    }
    let text_value = parse_text_nodes(text_body)
    comments.push({
      cell,
      author,
      author_id: Some(author_id),
      text: text_value,
      paragraph,
      width: None,
      height: None,
    })
  }
  comments
}

///|
fn parse_table_part_ids(xml : StringView) -> Array[String] raise XlsxError {
  let ids : Array[String] = []
  let body = match extract_tag_body(xml, "tableParts") {
    Some(value) => value
    None => return ids
  }
  let mut first = true
  for chunk in body.split("<tablePart ") {
    if first {
      first = false
      continue
    }
    let text = chunk.to_owned()
    let end = match text.find("/>") {
      Some(pos) => pos
      None =>
        match text.find(">") {
          Some(pos) => pos
          None => raise InvalidXml(msg="tablePart tag not closed")
        }
    }
    let tag = text[:end]
    let id = match attr_value(tag, "r:id") {
      Some(value) => value
      None => raise InvalidXml(msg="tablePart id missing")
    }
    ids.push(id)
  }
  ids
}

///|
fn parse_pivot_table_part_ids(
  xml : StringView,
) -> Array[String] raise XlsxError {
  let ids : Array[String] = []
  let body = match extract_tag_body(xml, "pivotTableParts") {
    Some(value) => value
    None => return ids
  }
  let mut first = true
  for chunk in body.split("<pivotTablePart ") {
    if first {
      first = false
      continue
    }
    let text = chunk.to_owned()
    let end = match text.find("/>") {
      Some(pos) => pos
      None =>
        match text.find(">") {
          Some(pos) => pos
          None => raise InvalidXml(msg="pivotTablePart tag not closed")
        }
    }
    let tag = text[:end]
    let id = match attr_value(tag, "r:id") {
      Some(value) => value
      None => raise InvalidXml(msg="pivotTablePart id missing")
    }
    ids.push(id)
  }
  ids
}

///|
fn parse_sheet_slicer_rel_ids(
  xml : StringView,
) -> Array[String] raise XlsxError {
  let ids : Array[String] = []
  let xml_str = xml.to_owned()
  let mut first = true
  for chunk in xml_str.split("<x14:slicer ") {
    if first {
      first = false
      continue
    }
    let text = chunk.to_owned()
    let end = match text.find("/>") {
      Some(pos) => pos
      None =>
        match text.find(">") {
          Some(pos) => pos
          None => raise InvalidXml(msg="x14:slicer tag not closed")
        }
    }
    let tag = text[:end]
    let id = match attr_value(tag, "r:id") {
      Some(value) => value
      None => raise InvalidXml(msg="x14:slicer id missing")
    }
    ids.push(id)
  }
  ids
}

///|
priv struct ParsedSlicerPartEntry {
  name : String
  cache : String
  caption : String
  display_header : Bool?
}

///|
fn parse_slicer_part_entries(
  xml : StringView,
) -> Array[ParsedSlicerPartEntry] raise XlsxError {
  let entries : Array[ParsedSlicerPartEntry] = []
  let xml_str = xml.to_owned()
  let mut first = true
  for chunk in xml_str.split("<slicer ") {
    if first {
      first = false
      continue
    }
    let text = chunk.to_owned()
    let end = match text.find("/>") {
      Some(pos) => pos
      None =>
        match text.find(">") {
          Some(pos) => pos
          None => raise InvalidXml(msg="slicer tag not closed")
        }
    }
    let tag = text[:end]
    let name = match attr_value(tag, "name") {
      Some(value) => unescape_xml_text(value)
      None => raise InvalidXml(msg="slicer name missing")
    }
    let cache = match attr_value(tag, "cache") {
      Some(value) => unescape_xml_text(value)
      None => raise InvalidXml(msg="slicer cache missing")
    }
    let caption = match attr_value(tag, "caption") {
      Some(value) => unescape_xml_text(value)
      None => ""
    }
    let display_header = match attr_value(tag, "showCaption") {
      Some(value) => Some(parse_bool_attr(value))
      None => None
    }
    entries.push({ name, cache, caption, display_header })
  }
  entries
}

///|
priv struct SlicerCacheDef {
  name : String
  source_name : String
  item_desc : Bool
  table_id : Int?
  table_column : Int?
  pivot_tab_id : Int?
  pivot_table_name : String?
}

///|
fn parse_slicer_cache_definition(
  xml : StringView,
) -> SlicerCacheDef raise XlsxError {
  let tag = match tag_attributes_in(xml, "slicerCacheDefinition") {
    Some(value) => value
    None => raise InvalidXml(msg="slicerCacheDefinition missing")
  }
  let name = match attr_value(tag, "name") {
    Some(value) => unescape_xml_text(value)
    None => raise InvalidXml(msg="slicer cache name missing")
  }
  let source_name = match attr_value(tag, "sourceName") {
    Some(value) => unescape_xml_text(value)
    None => ""
  }
  let mut item_desc = false
  let mut table_id : Int? = None
  let mut table_column : Int? = None
  let mut pivot_tab_id : Int? = None
  let mut pivot_table_name : String? = None
  match tag_attributes_in(xml, "x15:tableSlicerCache") {
    Some(cache_tag) => {
      match attr_value(cache_tag, "tableId") {
        Some(value) =>
          try @string.parse_int(value, base=10) catch {
            _ => raise InvalidXml(msg="slicer cache tableId invalid")
          } noraise {
            val => table_id = Some(val)
          }
        None => ()
      }
      match attr_value(cache_tag, "column") {
        Some(value) =>
          try @string.parse_int(value, base=10) catch {
            _ => raise InvalidXml(msg="slicer cache column invalid")
          } noraise {
            val => table_column = Some(val)
          }
        None => ()
      }
      match attr_value(cache_tag, "sortOrder") {
        Some(value) =>
          if unescape_xml_text(value) == "descending" {
            item_desc = true
          }
        None => ()
      }
    }
    None => ()
  }
  match tag_attributes_in(xml, "tabular") {
    Some(tabular_tag) =>
      match attr_value(tabular_tag, "sortOrder") {
        Some(value) =>
          if unescape_xml_text(value) == "descending" {
            item_desc = true
          }
        None => ()
      }
    None => ()
  }
  match extract_tag_body_from(xml, "pivotTables") {
    Some(pivot_tables_body) =>
      match tag_attributes_in(pivot_tables_body, "pivotTable") {
        Some(pivot_tag) => {
          match attr_value(pivot_tag, "tabId") {
            Some(value) =>
              try @string.parse_int(value, base=10) catch {
                _ => raise InvalidXml(msg="slicer cache tabId invalid")
              } noraise {
                val => pivot_tab_id = Some(val)
              }
            None => ()
          }
          match attr_value(pivot_tag, "name") {
            Some(value) => pivot_table_name = Some(unescape_xml_text(value))
            None => ()
          }
        }
        None => ()
      }
    None => ()
  }
  {
    name,
    source_name,
    item_desc,
    table_id,
    table_column,
    pivot_tab_id,
    pivot_table_name,
  }
}

///|
fn parse_slicer_cache_definitions(
  workbook_rels_xml : StringView,
  workbook_part : StringView,
  part_names : Map[String, String],
  archive : @zip.Archive,
  decode : (BytesView) -> String raise XlsxError,
) -> Map[String, SlicerCacheDef] raise XlsxError {
  let defs : Map[String, SlicerCacheDef] = Map([])
  let targets = parse_internal_relationship_targets(
    workbook_rels_xml, rel_slicer_cache,
  )
  for _rel_id, target in targets {
    let cache_path = actual_archive_part_path(
      part_names,
      resolve_part_rel_target(workbook_part, target),
    )
    let cache_bytes = match archive.get(cache_path) {
      Some(value) => value
      None => raise MissingPart(path=cache_path)
    }
    let cache_xml = decode(cache_bytes)
    let def = parse_slicer_cache_definition(cache_xml)
    defs[def.name] = def
  }
  defs
}

///|
fn resolve_slicer_sources_after_read(
  workbook : Workbook,
  slicer_cache_defs : Map[String, SlicerCacheDef],
) -> Unit {
  fn worksheet_name_from_tab_id(workbook : Workbook, tab_id : Int) -> String? {
    let count = workbook.sheets.length()
    if count == 0 {
      return None
    }
    let candidates : Array[Int] = []
    candidates.push(tab_id)
    candidates.push(tab_id + 1)
    candidates.push(tab_id - 1)
    for id in candidates {
      if id >= 1 && id <= count {
        return Some(workbook.sheets[id - 1].name)
      }
    }
    None
  }

  let table_by_id : Map[Int, (String, Table)] = Map([])
  for sheet in workbook.sheets {
    for table in sheet.tables() {
      if table.id > 0 {
        table_by_id[table.id] = (sheet.name, table)
      }
    }
  }
  for sheet in workbook.sheets {
    let slicers = sheet.slicers
    let mut i = 0
    while i < slicers.length() {
      let slicer = slicers[i]
      match slicer_cache_defs.get(slicer.cache) {
        Some(def) => {
          let mut table_sheet = slicer.table_sheet
          let mut table_name = slicer.table_name
          let mut source_name = slicer.source_name
          let mut item_desc = slicer.item_desc
          if def.source_name != "" {
            source_name = def.source_name
          }
          item_desc = def.item_desc
          match def.table_id {
            Some(table_id) =>
              match table_by_id.get(table_id) {
                Some((sheet_name, table)) => {
                  table_sheet = sheet_name
                  table_name = table.name
                  match def.table_column {
                    Some(col) => {
                      let idx = col - 1
                      if idx >= 0 && idx < table.columns.length() {
                        source_name = table.columns[idx]
                      }
                    }
                    None => ()
                  }
                }
                None => ()
              }
            None => ()
          }
          match def.pivot_table_name {
            Some(pivot_name) => if table_name == "" { table_name = pivot_name }
            None => ()
          }
          match def.pivot_tab_id {
            Some(tab_id) =>
              match worksheet_name_from_tab_id(workbook, tab_id) {
                Some(sheet_name) =>
                  if table_sheet == "" {
                    table_sheet = sheet_name
                  }
                None => ()
              }
            None => ()
          }
          if table_sheet != slicer.table_sheet ||
            table_name != slicer.table_name ||
            source_name != slicer.source_name ||
            item_desc != slicer.item_desc {
            slicers[i] = {
              name: slicer.name,
              cache: slicer.cache,
              source_name,
              cell: slicer.cell,
              table_sheet,
              table_name,
              caption: slicer.caption,
              macro_name: slicer.macro_name,
              width: slicer.width,
              height: slicer.height,
              display_header: slicer.display_header,
              item_desc,
              format: slicer.format,
            }
          }
        }
        None => ()
      }
      i = i + 1
    }
  }
}

///|
test "read_sheet_rel_parts wb: parse_comment_authors handles missing and malformed entries" {
  debug_inspect(parse_comment_authors("<comments/>"), content="[]")
  let xml =
    #|<comments>
    #|  <authors>
    #|    <author>Alice
    #|    <author>Bob</author>
    #|  </authors>
    #|</comments>
  debug_inspect(parse_comment_authors(xml), content="[\"Bob\"]")
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
  let malformed_result : Result[Array[Comment], Error] = Ok(
    parse_comments_xml(malformed_tag),
  ) catch {
    e => Err(e)
  }
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
  let missing_ref_result : Result[Array[Comment], Error] = Ok(
    parse_comments_xml(missing_ref),
  ) catch {
    e => Err(e)
  }
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
  debug_inspect(parse_table_part_ids(xml), content="[\"rIdTable\"]")

  let missing_id =
    #|<worksheet>
    #|  <tableParts count="1">
    #|    <tablePart />
    #|  </tableParts>
    #|</worksheet>
  let result : Result[Array[String], Error] = Ok(
    parse_table_part_ids(missing_id),
  ) catch {
    e => Err(e)
  }
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
  debug_inspect(parse_pivot_table_part_ids(xml), content="[\"rIdPivot\"]")

  let missing_id =
    #|<worksheet>
    #|  <pivotTableParts count="1">
    #|    <pivotTablePart />
    #|  </pivotTableParts>
    #|</worksheet>
  let result : Result[Array[String], Error] = Ok(
    parse_pivot_table_part_ids(missing_id),
  ) catch {
    e => Err(e)
  }
  match result {
    Err(XlsxError::InvalidXml(msg~)) =>
      inspect(msg, content="pivotTablePart id missing")
    _ => fail("expected InvalidXml pivotTablePart id missing")
  }
}
