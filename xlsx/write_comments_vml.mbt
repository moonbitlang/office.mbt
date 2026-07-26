///|
fn write_comments_xml(
  comments : ArrayView[Comment],
  budget? : WritePartBudget,
) -> String raise XlsxError {
  let normalized : Array[Comment] = []
  for comment in comments {
    normalized.push(normalize_comment(comment))
  }
  let authors : Array[String] = []
  let author_ids : Map[String, Int] = Map([])
  for comment in normalized {
    if !author_ids.contains(comment.author) {
      author_ids[comment.author] = authors.length()
      authors.push(comment.author)
    }
  }
  let sb = LimitedXmlBuilder::new(budget)
  sb.write_view("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n")
  sb.write_view(
    "<comments xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\">\n",
  )
  sb.write_view("  <authors>\n")
  for author in authors {
    sb.write_view("    <author>")
    sb.write_xml_text(author)
    sb.write_view("</author>\n")
  }
  sb.write_view("  </authors>\n")
  sb.write_view("  <commentList>\n")
  for comment in normalized {
    let author_id = author_ids.get(comment.author).unwrap_or(0)
    sb.write_view("    <comment ref=\"")
    sb.write_xml_attr(comment.cell)
    sb.write_view("\" authorId=\"\{author_id}\">\n")
    sb.write_view("      <text>")
    if comment.paragraph.length() == 0 && comment.text != "" {
      sb.write_t_element(comment.text)
    }
    for run in comment.paragraph {
      sb.write_view("<r>")
      sb.write_rich_text_run(run)
      sb.write_view("</r>")
    }
    sb.write_view("</text>\n")
    sb.write_view("    </comment>\n")
  }
  sb.write_view("  </commentList>\n")
  sb.write_view("</comments>")
  sb.to_string()
}

///|
fn vml_shape_id_range_is_valid(shape_id_start : Int, count : Int) -> Bool {
  if shape_id_start <= 0 || count < 0 {
    false
  } else if count == 0 {
    true
  } else {
    count - 1 <= 0x7fffffff - shape_id_start
  }
}

///|
fn write_comments_vml(
  sheet_id : Int,
  comments : ArrayView[Comment],
  shape_id_start? : Int = 1025,
  budget? : WritePartBudget,
) -> String raise XlsxError {
  if !vml_shape_id_range_is_valid(shape_id_start, comments.length()) {
    raise InvalidVmlDrawing(msg="comment VML shape id range is invalid")
  }
  let sb = LimitedXmlBuilder::new(budget)
  sb.write_view("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n")
  sb.write_view(
    "<xml xmlns:v=\"urn:schemas-microsoft-com:vml\" xmlns:o=\"urn:schemas-microsoft-com:office:office\" xmlns:x=\"urn:schemas-microsoft-com:office:excel\">\n",
  )
  sb.write_view("  <o:shapelayout v:ext=\"edit\">\n")
  sb.write_view("    <o:idmap v:ext=\"edit\" data=\"\{sheet_id}\"/>\n")
  sb.write_view("  </o:shapelayout>\n")
  sb.write_view(
    "  <v:shapetype id=\"_x0000_t202\" coordsize=\"21600,21600\" o:spt=\"202\" path=\"m0,0l0,21600,21600,21600,21600,0xe\">\n",
  )
  sb.write_view("    <v:stroke joinstyle=\"miter\"/>\n")
  sb.write_view("    <v:path o:connecttype=\"rect\"/>\n")
  sb.write_view("  </v:shapetype>\n")
  for index, comment in comments {
    let shape_id = shape_id_start + index
    let (row, col) = cell_ref_to_rc(comment.cell)
    let row0 = row - 1
    let col0 = col - 1
    let anchor = "\{col0}, 15, \{row0}, 2, \{col0 + 2}, 15, \{row0 + 3}, 16"
    sb.write_view(
      "  <v:shape id=\"_x0000_s\{shape_id}\" type=\"#_x0000_t202\" style=\"position:absolute;73.5pt;width:108pt;height:59.25pt;z-index:1;visibility:hidden\" fillcolor=\"#ffffe1\" o:insetmode=\"auto\">\n",
    )
    sb.write_view("    <v:fill color2=\"#ffffe1\"/>\n")
    sb.write_view("    <v:shadow on=\"t\" color=\"black\" obscured=\"t\"/>\n")
    sb.write_view("    <v:path o:connecttype=\"none\"/>\n")
    sb.write_view("    <v:textbox style=\"mso-direction-alt:auto\">\n")
    sb.write_view("      <div style=\"text-align:left\"/>\n")
    sb.write_view("    </v:textbox>\n")
    sb.write_view("    <x:ClientData ObjectType=\"Note\">\n")
    sb.write_view("      <x:MoveWithCells/>\n")
    sb.write_view("      <x:SizeWithCells/>\n")
    sb.write_view("      <x:Anchor>\{anchor}</x:Anchor>\n")
    sb.write_view("      <x:AutoFill>False</x:AutoFill>\n")
    sb.write_view("      <x:Row>\{row0}</x:Row>\n")
    sb.write_view("      <x:Column>\{col0}</x:Column>\n")
    sb.write_view("    </x:ClientData>\n")
    sb.write_view("  </v:shape>\n")
  }
  sb.write_view("</xml>")
  sb.to_string()
}

///|
priv struct VmlShapeSpan {
  start : Int
  close_start : Int
  end : Int
}

///|
fn xml_sequence_end_after_from(
  xml : StringView,
  start : Int,
  sequence : StringView,
) -> Int? {
  if start < 0 || start > xml.length() {
    return None
  }
  match xml[start:].find(sequence) {
    Some(relative) => Some(start + relative + sequence.length())
    None => None
  }
}

///|
fn xml_declaration_end_after_from(xml : StringView, start : Int) -> Int? {
  let mut index = start
  let mut quote : UInt16? = None
  let mut subset_depth = 0
  while index < xml.length() {
    let unit = xml[index]
    match quote {
      Some(delimiter) => if unit == delimiter { quote = None }
      None =>
        if unit == ('"' : UInt16) || unit == ('\'' : UInt16) {
          quote = Some(unit)
        } else if unit == ('[' : UInt16) {
          subset_depth = subset_depth + 1
        } else if unit == (']' : UInt16) && subset_depth > 0 {
          subset_depth = subset_depth - 1
        } else if unit == ('>' : UInt16) && subset_depth == 0 {
          return Some(index + 1)
        }
    }
    index = index + 1
  }
  None
}

///|
/// Returns `start` for element markup. Comments, CDATA, processing
/// instructions, and declarations return the first index after that markup;
/// malformed non-element markup consumes the remainder of the source.
fn skip_vml_non_element_markup(xml : StringView, start : Int) -> Int {
  if xml_sequence_at(xml, start, "<!--") {
    return xml_sequence_end_after_from(xml, start + 4, "-->").unwrap_or(
      xml.length(),
    )
  }
  if xml_sequence_at(xml, start, "<![CDATA[") {
    return xml_sequence_end_after_from(xml, start + 9, "]]>").unwrap_or(
      xml.length(),
    )
  }
  if xml_sequence_at(xml, start, "<?") {
    return xml_sequence_end_after_from(xml, start + 2, "?>").unwrap_or(
      xml.length(),
    )
  }
  if xml_sequence_at(xml, start, "<!") {
    return xml_declaration_end_after_from(xml, start + 2).unwrap_or(
      xml.length(),
    )
  }
  start
}

///|
fn mask_vml_non_element_markup(xml : StringView) -> String {
  let output = StringBuilder::new()
  let mut cursor = 0
  let mut index = 0
  while index < xml.length() {
    if xml[index] != ('<' : UInt16) {
      index = index + 1
      continue
    }
    let after = skip_vml_non_element_markup(xml, index)
    if after == index {
      index = index + 1
      continue
    }
    output.write_view(xml[cursor:index])
    for _ in index..<after {
      output.write_char(' ')
    }
    cursor = after
    index = after
  }
  output.write_view(xml[cursor:])
  output.to_string()
}

///|
fn extract_vml_element_spans(
  xml : StringView,
  element_name : StringView,
) -> Array[VmlShapeSpan] {
  let spans : Array[VmlShapeSpan] = []
  let masked = mask_vml_non_element_markup(xml)
  let mut index = 0
  while index < masked.length() {
    let start = match
      find_xml_open_tag_start_from(masked, element_name, index) {
      Some(value) => value
      None => break
    }
    let open_end = match xml_open_tag_end_from(masked, start + 1) {
      Some(value) => value
      None => break
    }
    let self_closing = masked[start + 1:open_end].trim().has_suffix("/")
    let (close_start, end) = if self_closing {
      (open_end, open_end + 1)
    } else {
      match find_xml_close_tag_from(masked, element_name, open_end + 1) {
        Some((close_start, close_end)) => (close_start, close_end + 1)
        None => break
      }
    }
    spans.push({ start, close_start, end })
    index = end
  }
  spans
}

///|
fn vml_direct_element_span(
  xml : StringView,
  element_name : StringView,
) -> VmlShapeSpan? {
  let masked = mask_vml_non_element_markup(xml)
  let mut depth = 0
  let mut index = 0
  while index < masked.length() {
    let relative = match masked[index:].find("<") {
      Some(value) => value
      None => return None
    }
    let start = index + relative
    let open_end = match xml_open_tag_end_from(masked, start + 1) {
      Some(value) => value
      None => return None
    }
    let closing = start + 1 < masked.length() &&
      masked[start + 1] == ('/' : UInt16)
    if closing {
      if depth > 0 {
        depth = depth - 1
      }
      index = open_end + 1
      continue
    }
    let self_closing = masked[start + 1:open_end].trim().has_suffix("/")
    if depth == 0 &&
      find_xml_open_tag_start_from(masked, element_name, start) == Some(start) {
      if self_closing {
        return Some({ start, close_start: open_end, end: open_end + 1 })
      }
      return match find_xml_close_tag_from(masked, element_name, open_end + 1) {
        Some((close_start, close_end)) =>
          Some({ start, close_start, end: close_end + 1 })
        None => None
      }
    }
    if !self_closing {
      depth = depth + 1
    }
    index = open_end + 1
  }
  None
}

///|
fn extract_vml_shape_spans(xml : StringView) -> Array[VmlShapeSpan] {
  extract_vml_element_spans(xml, "v:shape")
}

///|
fn vml_live_element_text(
  xml : StringView,
  element_name : StringView,
) -> String? {
  let span = match vml_direct_element_span(xml, element_name) {
    Some(value) => value
    None => return None
  }
  let open_end = xml_open_tag_end_from(xml, span.start + 1).unwrap()
  if span.close_start <= open_end {
    Some("")
  } else {
    Some(unescape_xml_text(xml[open_end + 1:span.close_start]))
  }
}

///|
fn vml_client_data_parts(
  shape_xml : StringView,
) -> (String?, StringView)? raise XlsxError {
  let shape_spans = extract_vml_shape_spans(shape_xml)
  if shape_spans.length() == 0 {
    return None
  }
  let shape_span = shape_spans[0]
  let shape_open_end = xml_open_tag_end_from(shape_xml, shape_span.start + 1).unwrap()
  if shape_span.close_start <= shape_open_end {
    return None
  }
  let shape_body = shape_xml[shape_open_end + 1:shape_span.close_start]
  let span = match vml_direct_element_span(shape_body, "x:ClientData") {
    Some(value) => value
    None => return None
  }
  let open_end = xml_open_tag_end_from(shape_body, span.start + 1).unwrap()
  let name_end = span.start + 1 + "x:ClientData".length()
  let object_type = attr_value(shape_body[name_end:open_end], "ObjectType")
  let body = if span.close_start <= open_end {
    shape_body[open_end:open_end]
  } else {
    shape_body[open_end + 1:span.close_start]
  }
  Some((object_type, body))
}

///|
fn parse_vml_coordinate(value : String?) -> Int? {
  match value {
    Some(text) =>
      try @string.parse_int(text.trim(), base=10) catch {
        _ => None
      } noraise {
        coordinate => Some(coordinate)
      }
    None => None
  }
}

///|
fn vml_client_data_coordinates(body : StringView) -> (Int, Int)? {
  let row = parse_vml_coordinate(vml_live_element_text(body, "x:Row"))
  let column = parse_vml_coordinate(vml_live_element_text(body, "x:Column"))
  match (row, column) {
    (Some(row0), Some(col0)) => return Some((row0, col0))
    _ => ()
  }
  let anchor = match vml_live_element_text(body, "x:Anchor") {
    Some(value) => value
    None => return None
  }
  let parts : Array[StringView] = []
  for part in anchor.split(",") {
    parts.push(part)
  }
  if parts.length() < 4 {
    return None
  }
  let col0 = try @string.parse_int(parts[0].trim(), base=10) catch {
    _ => return None
  } noraise {
    value => value
  }
  let row0 = try @string.parse_int(parts[2].trim(), base=10) catch {
    _ => return None
  } noraise {
    value => value
  }
  Some((row0, col0))
}

///|
fn extract_vml_shapetype(xml : StringView) -> StringView? {
  let spans = extract_vml_element_spans(xml, "v:shapetype")
  if spans.length() == 0 {
    None
  } else {
    Some(xml[spans[0].start:spans[0].end])
  }
}

///|
fn vml_has_shapetype_id(
  xml : StringView,
  shape_type_id : StringView,
) -> Bool raise XlsxError {
  for span in extract_vml_element_spans(xml, "v:shapetype") {
    let open_end = xml_open_tag_end_from(xml, span.start + 1).unwrap()
    let name_end = span.start + 1 + "v:shapetype".length()
    if attr_value(xml[name_end:open_end], "id") ==
      Some(shape_type_id.to_owned()) {
      return true
    }
  }
  false
}

///|
fn vml_xml_body_end(xml : StringView) -> Int? {
  let masked = mask_vml_non_element_markup(xml)
  match find_xml_close_tag_from(masked, "xml", 0) {
    Some((start, _)) => Some(start)
    None => None
  }
}

///|
fn extract_vml_shapes(xml : StringView) -> Array[StringView] {
  let shapes : Array[StringView] = []
  for span in extract_vml_shape_spans(xml) {
    shapes.push(xml[span.start:span.end])
  }
  shapes
}

///|
fn vml_shape_id(shape_xml : StringView) -> String? raise XlsxError {
  let open_end = match xml_open_tag_end_from(shape_xml, "<v:shape".length()) {
    Some(pos) => pos
    None => return None
  }
  attr_value(shape_xml["<v:shape".length():open_end], "id")
}

///|
fn vml_shape_is_comment(shape_xml : StringView) -> Bool raise XlsxError {
  match vml_client_data_parts(shape_xml) {
    Some((Some("Note"), _)) => true
    _ => false
  }
}

///|
fn vml_comment_cell(shape_xml : StringView) -> String? raise XlsxError {
  if !vml_shape_is_comment(shape_xml) {
    return None
  }
  let body = match vml_client_data_parts(shape_xml) {
    Some((Some("Note"), body)) => body
    _ => return None
  }
  let (row0, col0) = match vml_client_data_coordinates(body) {
    Some(value) => value
    None => {
      let row_text = vml_live_element_text(body, "x:Row")
      let col_text = vml_live_element_text(body, "x:Column")
      if row_text is None {
        raise InvalidVmlDrawing(msg="comment VML row is missing")
      }
      if parse_vml_coordinate(row_text) is None {
        raise InvalidVmlDrawing(msg="comment VML row is invalid")
      }
      if col_text is None {
        raise InvalidVmlDrawing(msg="comment VML column is missing")
      }
      raise InvalidVmlDrawing(msg="comment VML column is invalid")
    }
  }
  if row0 < 0 ||
    row0 >= cell_ref_max_rows ||
    col0 < 0 ||
    col0 >= cell_ref_max_cols {
    raise InvalidVmlDrawing(
      msg="comment VML cell is outside the worksheet grid",
    )
  }
  Some(cell_ref_from(row0 + 1, col0 + 1))
}

///|
fn parse_vml_shape_numeric_id(value : StringView) -> Int? {
  let prefix = "_x0000_s"
  if !value.has_prefix(prefix) {
    return None
  }
  try @string.parse_int(value[prefix.length():], base=10) catch {
    _ => None
  } noraise {
    value => if value > 0 { Some(value) } else { None }
  }
}

///|
fn vml_used_shape_numeric_ids(
  base_xml : StringView,
) -> (Map[Int, Bool], Int) raise XlsxError {
  let used : Map[Int, Bool] = Map([])
  let mut maximum = 1024
  for span in extract_vml_shape_spans(base_xml) {
    let shape = base_xml[span.start:span.end]
    let open_end = match xml_open_tag_end_from(shape, "<v:shape".length()) {
      Some(value) => value
      None => continue
    }
    let attributes = shape["<v:shape".length():open_end]
    for attribute_name in ["id", "o:spid"] {
      match attr_value(attributes, attribute_name) {
        Some(value) =>
          match parse_vml_shape_numeric_id(value) {
            Some(id) => {
              used[id] = true
              if id > maximum {
                maximum = id
              }
            }
            None => ()
          }
        None => ()
      }
    }
  }
  (used, maximum)
}

///|
fn vml_shape_id_range_is_free(
  used : Map[Int, Bool],
  start : Int,
  count : Int,
) -> Bool {
  if !vml_shape_id_range_is_valid(start, count) {
    return false
  }
  for offset in 0..<count {
    if used.contains(start + offset) {
      return false
    }
  }
  true
}

///|
fn reserve_vml_shape_id_range(
  used : Map[Int, Bool],
  start : Int,
  count : Int,
) -> Unit {
  for offset in 0..<count {
    used[start + offset] = true
  }
}

///|
fn allocate_vml_shape_id_range(
  used : Map[Int, Bool],
  preferred_after : Int,
  minimum : Int,
  count : Int,
) -> Int raise XlsxError {
  if count == 0 {
    return minimum
  }
  if count < 0 || minimum <= 0 || count - 1 > 0x7fffffff - minimum {
    raise InvalidVmlDrawing(msg="VML shape id space is exhausted")
  }
  if preferred_after < 0x7fffffff {
    let preferred = (preferred_after + 1).max(minimum)
    if vml_shape_id_range_is_free(used, preferred, count) {
      return preferred
    }
  }
  let maximum_start = 0x7fffffff - (count - 1)
  let mut candidate = minimum
  while candidate <= maximum_start {
    let mut collision : Int? = None
    for offset in 0..<count {
      let id = candidate + offset
      if used.contains(id) {
        collision = Some(id)
        break
      }
    }
    match collision {
      None => return candidate
      Some(id) => if id >= maximum_start { break } else { candidate = id + 1 }
    }
  }
  raise InvalidVmlDrawing(msg="VML shape id space is exhausted")
}

///|
fn remove_vml_shape_spans(
  base_xml : String,
  remove : ArrayView[VmlShapeSpan],
  budget? : WritePartBudget,
) -> String raise XlsxError {
  if remove.length() == 0 {
    return base_xml
  }
  let sb = LimitedXmlBuilder::new(budget)
  let mut cursor = 0
  for span in remove {
    sb.write_view(base_xml[cursor:span.start])
    cursor = span.end
  }
  sb.write_view(base_xml[cursor:])
  sb.to_string()
}

///|
fn remove_vml_comment_shapes_at_cell(
  base_xml : String,
  cell : String,
  budget? : WritePartBudget,
) -> String raise XlsxError {
  let remove : Array[VmlShapeSpan] = []
  for span in extract_vml_shape_spans(base_xml) {
    match vml_comment_cell(base_xml[span.start:span.end]) {
      Some(shape_cell) => if shape_cell == cell { remove.push(span) }
      None => ()
    }
  }
  remove_vml_shape_spans(base_xml, remove, budget?)
}

///|
fn reconcile_vml_comment_shapes(
  base_xml : String,
  comments : ArrayView[Comment],
  budget? : WritePartBudget,
) -> (String, Array[Comment], Int) raise XlsxError {
  let wanted : Map[String, Bool] = Map([])
  for comment in comments {
    wanted[comment.cell] = true
  }
  let seen : Map[String, Bool] = Map([])
  let remove : Array[VmlShapeSpan] = []
  for span in extract_vml_shape_spans(base_xml) {
    let shape = base_xml[span.start:span.end]
    match vml_comment_cell(shape) {
      Some(cell) =>
        if wanted.contains(cell) {
          if seen.contains(cell) {
            remove.push(span)
          } else {
            seen[cell] = true
          }
        }
      None => ()
    }
  }
  let missing : Array[Comment] = []
  for comment in comments {
    if !seen.contains(comment.cell) {
      missing.push(comment)
    }
  }
  let reconciled = remove_vml_shape_spans(base_xml, remove, budget?)
  let (_, max_shape_id) = vml_used_shape_numeric_ids(reconciled)
  (reconciled, missing, max_shape_id)
}

///|
fn filter_vml_shapes_by_id(
  base_xml : String,
  remove_ids : Array[String],
  budget? : WritePartBudget,
) -> String raise XlsxError {
  if remove_ids.length() == 0 {
    return base_xml
  }
  if !base_xml.contains("<v:shape") {
    return base_xml
  }
  let remove_map : Map[String, Bool] = Map([])
  for id in remove_ids {
    remove_map[id] = true
  }
  let remove : Array[VmlShapeSpan] = []
  for span in extract_vml_shape_spans(base_xml) {
    match vml_shape_id(base_xml[span.start:span.end]) {
      Some(id) => if remove_map.contains(id) { remove.push(span) }
      None => ()
    }
  }
  remove_vml_shape_spans(base_xml, remove, budget?)
}

///|
fn merge_vml_drawings(
  base_xml : String,
  comment_xml : String,
  budget? : WritePartBudget,
) -> String raise XlsxError {
  let end = match vml_xml_body_end(base_xml) {
    Some(value) => value
    None => return comment_xml
  }
  let shape_type = if !vml_has_shapetype_id(base_xml, "_x0000_t202") {
    match extract_vml_shapetype(comment_xml) {
      Some(value) => Some(value)
      None => None
    }
  } else {
    None
  }
  let shapes = extract_vml_shapes(comment_xml)
  if shape_type is None && shapes.length() == 0 {
    return base_xml
  }
  let base_shape_spans = extract_vml_shape_spans(base_xml)
  let shape_type_at = match shape_type {
    Some(_) =>
      if base_shape_spans.length() > 0 {
        base_shape_spans[0].start
      } else {
        end
      }
    None => end
  }
  let sb = LimitedXmlBuilder::new(budget)
  sb.write_view(base_xml[:shape_type_at])
  match shape_type {
    Some(value) => sb.write_view(value)
    None => ()
  }
  sb.write_view(base_xml[shape_type_at:end])
  for shape in shapes {
    sb.write_view(shape)
  }
  sb.write_view(base_xml[end:])
  sb.to_string()
}

///|
fn merge_vml_drawings_with_shapetype(
  base_xml : String,
  extra_xml : String,
  shape_type_id : StringView,
  budget? : WritePartBudget,
) -> String raise XlsxError {
  let end = match vml_xml_body_end(base_xml) {
    Some(value) => value
    None => return extra_xml
  }
  let shape_type = if !vml_has_shapetype_id(base_xml, shape_type_id) {
    match extract_vml_shapetype(extra_xml) {
      Some(value) => Some(value)
      None => None
    }
  } else {
    None
  }
  let shapes = extract_vml_shapes(extra_xml)
  if shape_type is None && shapes.length() == 0 {
    return base_xml
  }
  let base_shape_spans = extract_vml_shape_spans(base_xml)
  let shape_type_at = match shape_type {
    Some(_) =>
      if base_shape_spans.length() > 0 {
        base_shape_spans[0].start
      } else {
        end
      }
    None => end
  }
  let sb = LimitedXmlBuilder::new(budget)
  sb.write_view(base_xml[:shape_type_at])
  match shape_type {
    Some(value) => sb.write_view(value)
    None => ()
  }
  sb.write_view(base_xml[shape_type_at:end])
  for shape in shapes {
    sb.write_view(shape)
  }
  sb.write_view(base_xml[end:])
  sb.to_string()
}

///|
fn write_header_footer_vml(
  sheet_id : Int,
  images : ArrayView[HeaderFooterImage],
  budget? : WritePartBudget,
) -> String raise XlsxError {
  let sb = LimitedXmlBuilder::new(budget)
  sb.write_view("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n")
  sb.write_view(
    "<xml xmlns:v=\"urn:schemas-microsoft-com:vml\" xmlns:o=\"urn:schemas-microsoft-com:office:office\" xmlns:x=\"urn:schemas-microsoft-com:office:excel\">\n",
  )
  sb.write_view("  <o:shapelayout v:ext=\"edit\">\n")
  sb.write_view("    <o:idmap v:ext=\"edit\" data=\"\{sheet_id}\"/>\n")
  sb.write_view("  </o:shapelayout>\n")
  sb.write_view(
    "  <v:shapetype id=\"_x0000_t75\" coordsize=\"21600,21600\" o:spt=\"75\" o:preferrelative=\"t\" path=\"m@4@5l@4@11@9@11@9@5xe\" filled=\"f\" stroked=\"f\">\n",
  )
  sb.write_view("    <v:stroke joinstyle=\"miter\"/>\n")
  sb.write_view("    <v:formulas>\n")
  sb.write_view("      <v:f eqn=\"if lineDrawn pixelLineWidth 0\"/>\n")
  sb.write_view("      <v:f eqn=\"sum @0 1 0\"/>\n")
  sb.write_view("      <v:f eqn=\"sum 0 0 @1\"/>\n")
  sb.write_view("      <v:f eqn=\"prod @2 1 2\"/>\n")
  sb.write_view("      <v:f eqn=\"prod @3 21600 pixelWidth\"/>\n")
  sb.write_view("      <v:f eqn=\"prod @3 21600 pixelHeight\"/>\n")
  sb.write_view("      <v:f eqn=\"sum @0 0 1\"/>\n")
  sb.write_view("      <v:f eqn=\"prod @6 1 2\"/>\n")
  sb.write_view("      <v:f eqn=\"prod @7 21600 pixelWidth\"/>\n")
  sb.write_view("      <v:f eqn=\"sum @8 21600 0\"/>\n")
  sb.write_view("      <v:f eqn=\"prod @7 21600 pixelHeight\"/>\n")
  sb.write_view("      <v:f eqn=\"sum @10 21600 0\"/>\n")
  sb.write_view("    </v:formulas>\n")
  sb.write_view(
    "    <v:path o:extrusionok=\"f\" gradientshapeok=\"t\" o:connecttype=\"rect\"/>\n",
  )
  sb.write_view("    <o:lock v:ext=\"edit\" aspectratio=\"t\"/>\n")
  sb.write_view("  </v:shapetype>\n")
  let mut shape_id = 1025
  let mut rel_id = 1
  for image in images {
    let shape_name = header_footer_image_shape_id(
      image.position,
      image.is_footer,
      image.first_page,
    )
    let style = "position:absolute;margin-left:0;margin-top:0;width:\{image.width};height:\{image.height};z-index:1"
    sb.write_view("  <v:shape id=\"")
    sb.write_xml_attr(shape_name)
    sb.write_view(
      "\" o:spid=\"_x0000_s\{shape_id}\" type=\"#_x0000_t75\" style=\"",
    )
    sb.write_xml_attr(style)
    sb.write_view("\">\n")
    sb.write_view("    <v:imagedata o:relid=\"rId\{rel_id}\" o:title=\"\"/>\n")
    sb.write_view("    <o:lock v:ext=\"edit\" rotation=\"t\"/>\n")
    sb.write_view("  </v:shape>\n")
    shape_id = shape_id + 1
    rel_id = rel_id + 1
  }
  sb.write_view("</xml>")
  sb.to_string()
}

///|
fn wb_comment(
  cell : String,
  author : String,
  text : String,
  paragraph : Array[RichTextRun],
) -> Comment {
  { cell, author, author_id: None, text, paragraph, width: None, height: None }
}

///|
test "write comments vml wb: rich comment xml branches" {
  let rich_font : RichTextFont = {
    bold: true,
    italic: true,
    strike: true,
    outline: true,
    shadow: true,
    condense: true,
    extended: true,
    underline: Some("single"),
    size: Some(12.0),
    color: Some("00112233"),
    color_theme: None,
    color_indexed: None,
    color_tint: Some(0.5),
    charset: Some(134),
    family_number: Some(2),
    scheme: Some("minor"),
    vert_align: Some("superscript"),
    family: Some("Calibri"),
  }
  let theme_font : RichTextFont = {
    bold: false,
    italic: false,
    strike: false,
    outline: false,
    shadow: false,
    condense: false,
    extended: false,
    underline: None,
    size: None,
    color: None,
    color_theme: Some(5),
    color_indexed: None,
    color_tint: Some(0.0),
    charset: None,
    family_number: None,
    scheme: None,
    vert_align: None,
    family: None,
  }
  let indexed_font : RichTextFont = {
    bold: false,
    italic: false,
    strike: false,
    outline: false,
    shadow: false,
    condense: false,
    extended: false,
    underline: None,
    size: None,
    color: None,
    color_theme: None,
    color_indexed: Some(64),
    color_tint: Some(0.25),
    charset: None,
    family_number: None,
    scheme: None,
    vert_align: None,
    family: None,
  }
  let theme_tint_font : RichTextFont = {
    bold: false,
    italic: false,
    strike: false,
    outline: false,
    shadow: false,
    condense: false,
    extended: false,
    underline: None,
    size: None,
    color: None,
    color_theme: Some(2),
    color_indexed: None,
    color_tint: Some(0.5),
    charset: None,
    family_number: None,
    scheme: None,
    vert_align: None,
    family: None,
  }
  let indexed_no_tint_font : RichTextFont = {
    bold: false,
    italic: false,
    strike: false,
    outline: false,
    shadow: false,
    condense: false,
    extended: false,
    underline: None,
    size: None,
    color: None,
    color_theme: None,
    color_indexed: Some(7),
    color_tint: None,
    charset: None,
    family_number: None,
    scheme: None,
    vert_align: None,
    family: None,
  }
  let tint_only_font : RichTextFont = {
    bold: false,
    italic: false,
    strike: false,
    outline: false,
    shadow: false,
    condense: false,
    extended: false,
    underline: None,
    size: None,
    color: None,
    color_theme: None,
    color_indexed: None,
    color_tint: Some(0.75),
    charset: None,
    family_number: None,
    scheme: None,
    vert_align: None,
    family: None,
  }
  let comments : ReadOnlyArray[Comment] = [
    wb_comment("A1", "", "", [
      { text: "Rich", font: Some(rich_font) },
      { text: "Theme", font: Some(theme_font) },
      { text: "Indexed", font: Some(indexed_font) },
      { text: "ThemeTint", font: Some(theme_tint_font) },
      { text: "IndexedNoTint", font: Some(indexed_no_tint_font) },
      { text: "TintOnly", font: Some(tint_only_font) },
    ]),
    wb_comment("B2", "Bob", " lead\n", []),
  ]
  let xml = write_comments_xml(comments)
  inspect(xml.contains("<author>Author</author>"), content="true")
  inspect(xml.contains("<t xml:space=\"preserve\">"), content="true")
  inspect(xml.contains("<b/>"), content="true")
  inspect(xml.contains("<i/>"), content="true")
  inspect(xml.contains("<strike/>"), content="true")
  inspect(xml.contains("<outline/>"), content="true")
  inspect(xml.contains("<shadow/>"), content="true")
  inspect(xml.contains("<condense/>"), content="true")
  inspect(xml.contains("<extend/>"), content="true")
  inspect(xml.contains("<u val=\"single\"/>"), content="true")
  inspect(xml.contains("<charset val=\"134\"/>"), content="true")
  inspect(xml.contains("<family val=\"2\"/>"), content="true")
  inspect(xml.contains("<rFont val=\"Calibri\"/>"), content="true")
  inspect(xml.contains("<vertAlign val=\"superscript\"/>"), content="true")
  inspect(xml.contains("<scheme val=\"minor\"/>"), content="true")
  inspect(
    xml.contains("<color rgb=\"00112233\" tint=\"0.5\"/>"),
    content="true",
  )
  inspect(xml.contains("<color theme=\"5\"/>"), content="true")
  inspect(xml.contains("<color indexed=\"64\" tint=\"0.25\"/>"), content="true")
  inspect(xml.contains("<color theme=\"2\" tint=\"0.5\"/>"), content="true")
  inspect(xml.contains("<color indexed=\"7\"/>"), content="true")
  inspect(xml.contains("TintOnly"), content="true")
}

///|
test "write comments vml wb: invalid comments reject without truncation" {
  let invalid_comments : Array[Comment] = [
    wb_comment("A1", "A".repeat(max_comment_author_chars + 1), "valid", []),
    wb_comment("A1", "Alice", "B".repeat(max_comment_content_chars + 1), []),
    wb_comment("A1", "Alice", "", [
      { text: "C".repeat(max_comment_content_chars + 1), font: None },
    ]),
    wb_comment("A1", "Alice", "plain", [{ text: "rich", font: None }]),
  ]
  for comment in invalid_comments {
    let one : ReadOnlyArray[Comment] = [comment]
    let result : Result[String, Error] = Ok(write_comments_xml(one)) catch {
      error => Err(error)
    }
    inspect(result is Err(XlsxError::InvalidComment(_)), content="true")
  }
}

///|
test "write comments vml wb: vml writer and extraction branches" {
  let comments : ReadOnlyArray[Comment] = [wb_comment("C3", "Bob", "note", [])]
  let vml = write_comments_vml(7, comments)
  inspect(vml.contains("<o:idmap v:ext=\"edit\" data=\"7\"/>"), content="true")
  inspect(vml.contains("_x0000_s1025"), content="true")
  inspect(extract_vml_shapetype(vml) is Some(_), content="true")
  debug_inspect(extract_vml_shapetype("<xml></xml>"), content="None")
  debug_inspect(
    extract_vml_shapetype("<xml><v:shapetype id=\"x\"></xml>"),
    content="None",
  )

  let shapes = extract_vml_shapes(vml)
  inspect(shapes.length(), content="1")
  match vml_shape_id(shapes[0]) {
    Some(id) => inspect(id, content="_x0000_s1025")
    None => fail("expected VML shape id")
  }
  inspect(extract_vml_shapes("<xml><v:shape").length(), content="0")
  inspect(extract_vml_shapes("<xml><v:shape id=\"x\">").length(), content="0")
  debug_inspect(vml_shape_id("<v:shape id=\"x></v:shape>"), content="None")
  debug_inspect(vml_shape_id("<v:shape></v:shape>"), content="None")
  let xml_whitespace_shapes = "<xml>" +
    "<v:shape\tid=\"tab\"/>" +
    "<v:shape\nid=\"line-feed\"/>" +
    "<v:shape\rid=\"carriage-return\"/>" +
    "<v:shape id=\"space\"/>" +
    "</xml>"
  inspect(extract_vml_shapes(xml_whitespace_shapes).length(), content="4")
  let self_closing_before_note = "<xml>" +
    "<v:shape id='_x0000_s2000'/>" +
    "<v:shape id=\"_x0000_s1025\"><x:ClientData ObjectType=\"Note\">" +
    "<x:Row>0</x:Row><x:Column>0</x:Column>" +
    "</x:ClientData></v:shape></xml>"
  inspect(extract_vml_shapes(self_closing_before_note).length(), content="2")
  let (_, self_closing_maximum) = vml_used_shape_numeric_ids(
    self_closing_before_note,
  )
  inspect(self_closing_maximum, content="2000")
  let without_note = remove_vml_comment_shapes_at_cell(
    self_closing_before_note, "A1",
  )
  inspect(without_note.contains("_x0000_s2000"), content="true")
  inspect(without_note.contains("_x0000_s1025"), content="false")

  let literal_shapes = "<xml>" +
    "<!-- </xml><v:shapetype id=\"_x0000_t202\"></v:shapetype>" +
    "<v:shape id=\"_x0000_s2147483647\"></v:shape> -->" +
    "<![CDATA[<v:shape id=\"_x0000_s2147483646\"></v:shape>]]>" +
    "<?probe value=\"<v:shape id='_x0000_s2147483645'/>\"?>" +
    "<v:shape id=\"_x0000_s1025\">" +
    "<!-- </v:shape> --><![CDATA[</v:shape>]]>" +
    "<x:ClientData ObjectType=\"Note\"><x:Row>0</x:Row>" +
    "<x:Column>0</x:Column></x:ClientData></v:shape></xml>"
  let live_shapes = extract_vml_shapes(literal_shapes)
  inspect(live_shapes.length(), content="1")
  debug_inspect(vml_shape_id(live_shapes[0]), content="Some(\"_x0000_s1025\")")
  debug_inspect(vml_comment_cell(live_shapes[0]), content="Some(\"A1\")")
  let (_, literal_maximum) = vml_used_shape_numeric_ids(literal_shapes)
  inspect(literal_maximum, content="1025")
  inspect(extract_vml_shapetype(literal_shapes) is None, content="true")
  inspect(
    vml_xml_body_end(literal_shapes).unwrap() >
    literal_shapes.find("</xml>").unwrap(),
    content="true",
  )
}

///|
test "write comments vml wb: filter and merge branches" {
  let comments : ReadOnlyArray[Comment] = [
    wb_comment("A1", "A", "x", []),
    wb_comment("B2", "B", "y", []),
  ]
  let base = write_comments_vml(1, comments)

  inspect(filter_vml_shapes_by_id(base, []) == base, content="true")
  inspect(
    filter_vml_shapes_by_id("<xml></xml>", ["_x0000_s1025"]) == "<xml></xml>",
    content="true",
  )

  let removed = filter_vml_shapes_by_id(base, ["_x0000_s1025"])
  inspect(removed.contains("_x0000_s1025"), content="false")
  inspect(removed.contains("_x0000_s1026"), content="true")
  let no_id_xml = "<xml><v:shape></v:shape></xml>"
  inspect(
    filter_vml_shapes_by_id(no_id_xml, ["_x0000_s1025"]) == no_id_xml,
    content="true",
  )
  let custom = "<xml><meta keep=\"true\"/>" +
    "<v:shape id=\"_x0000_s1026\" style=\"width:86pt;height:24pt\" " +
    "fillcolor=\"#123456\"><x:ClientData ObjectType=\"Note\">" +
    "<x:Row>0</x:Row><x:Column>0</x:Column></x:ClientData></v:shape>" +
    "<!--keep--><v:shape id=\"_x0000_s1027\">" +
    "<x:ClientData ObjectType=\"Note\"><x:Row>0</x:Row>" +
    "<x:Column>0</x:Column></x:ClientData></v:shape>" +
    "<v:shape id=\"_x0000_s2048\"><x:ClientData ObjectType=\"Button\">" +
    "</x:ClientData></v:shape><tail keep=\"true\"/></xml>"
  let (reconciled, missing, max_shape_id) = reconcile_vml_comment_shapes(
    custom, comments,
  )
  inspect(
    reconciled.contains("style=\"width:86pt;height:24pt\""),
    content="true",
  )
  inspect(reconciled.contains("fillcolor=\"#123456\""), content="true")
  inspect(reconciled.contains("_x0000_s1026"), content="true")
  inspect(reconciled.contains("_x0000_s1027"), content="false")
  inspect(reconciled.contains("_x0000_s2048"), content="true")
  inspect(reconciled.contains("<!--keep-->"), content="true")
  inspect(reconciled.contains("<meta keep=\"true\"/>"), content="true")
  inspect(reconciled.contains("<tail keep=\"true\"/>"), content="true")
  inspect(missing.length(), content="1")
  inspect(missing[0].cell, content="B2")
  inspect(max_shape_id, content="2048")
  let next_shape_id = max_shape_id + 1
  inspect(next_shape_id, content="2049")
  let generated_missing = write_comments_vml(
    1,
    missing,
    shape_id_start=next_shape_id,
  )
  inspect(generated_missing.contains("_x0000_s2049"), content="true")
  inspect(generated_missing.contains("<x:Row>1</x:Row>"), content="true")
  inspect(generated_missing.contains("<x:Column>1</x:Column>"), content="true")
  inspect(merge_vml_drawings("broken", base), content=base)
  let inserted = merge_vml_drawings("<xml></xml>", base)
  inspect(inserted.contains("_x0000_t202"), content="true")
  inspect(inserted.contains("_x0000_s1025"), content="true")
  inspect(merge_vml_drawings(base, "<xml></xml>") == base, content="true")
  let shape_only = "<xml><v:shape id=\"_x0000_s9001\"></v:shape></xml>"
  let inserted_no_type = merge_vml_drawings("<xml></xml>", shape_only)
  inspect(inserted_no_type.contains("_x0000_s9001"), content="true")
  inspect(inserted_no_type.contains("_x0000_t202"), content="false")

  inspect(
    merge_vml_drawings_with_shapetype("broken", base, "_x0000_t202"),
    content=base,
  )
  let inserted_hf = merge_vml_drawings_with_shapetype(
    "<xml></xml>", base, "_x0000_t202",
  )
  inspect(inserted_hf.contains("_x0000_t202"), content="true")
  inspect(inserted_hf.contains("_x0000_s1025"), content="true")
  let inserted_hf_no_type = merge_vml_drawings_with_shapetype(
    "<xml></xml>", shape_only, "_x0000_t202",
  )
  inspect(inserted_hf_no_type.contains("_x0000_s9001"), content="true")
  inspect(inserted_hf_no_type.contains("_x0000_t202"), content="false")
  inspect(
    merge_vml_drawings_with_shapetype(base, "<xml></xml>", "_x0000_t202") ==
    base,
    content="true",
  )
}

///|
test "write comments vml wb: live ClientData, coordinates, and free IDs" {
  let spoofed_control = "<v:shape id='_x0000_s2048'>" +
    "<!-- <x:ClientData ObjectType='Note'><x:Row>0</x:Row>" +
    "<x:Column>0</x:Column></x:ClientData> -->" +
    "<![CDATA[<x:ClientData ObjectType=\"Note\"/>]]>" +
    "<x:ClientData ObjectType='Button'><x:Row>0</x:Row>" +
    "<x:Column>0</x:Column></x:ClientData></v:shape>"
  inspect(vml_shape_is_comment(spoofed_control), content="false")
  debug_inspect(vml_comment_cell(spoofed_control), content="None")

  let whitespace_note = "<v:shape id=\"_x0000_s1025\">" +
    "<x:ClientData ObjectType=\"Note\"><x:Row \n>0</x:Row \r>" +
    "<x:Column\t>1</x:Column ></x:ClientData></v:shape>"
  debug_inspect(vml_comment_cell(whitespace_note), content="Some(\"B1\")")
  let anchor_note = "<v:shape id=\"_x0000_s1026\">" +
    "<x:ClientData ObjectType=\"Note\">" +
    "<x:Anchor>1, 0, 2, 0, 3, 0, 5, 0</x:Anchor>" +
    "</x:ClientData></v:shape>"
  debug_inspect(vml_comment_cell(anchor_note), content="Some(\"B3\")")

  let retained = "<xml>" +
    "<v:shape id=\"_x0000_s4095\"/>" +
    "<v:shape id=\"friendly\" o:spid=\"_x0000_s4096\"/>" +
    "<v:shape id=\"_x0000_s2147483647\"/></xml>"
  let (used, maximum) = vml_used_shape_numeric_ids(retained)
  inspect(used.contains(4095), content="true")
  inspect(used.contains(4096), content="true")
  inspect(used.contains(2147483647), content="true")
  inspect(maximum, content="2147483647")
  let comment_start = allocate_vml_shape_id_range(used, maximum, 1025, 2)
  inspect(comment_start, content="1025")
  reserve_vml_shape_id_range(used, comment_start, 2)
  inspect(allocate_vml_shape_id_range(used, maximum, 1025, 1), content="1027")
  inspect(vml_shape_id_range_is_valid(2147483647, 1), content="true")
  inspect(vml_shape_id_range_is_valid(2147483647, 2), content="false")
  let at_upper_bound = write_comments_vml(
    1,
    [wb_comment("A1", "A", "x", [])],
    shape_id_start=2147483647,
  )
  inspect(at_upper_bound.contains("_x0000_s2147483647"), content="true")
}
