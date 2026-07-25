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
fn write_comments_vml(
  sheet_id : Int,
  comments : ArrayView[Comment],
  shape_id_start? : Int = 1025,
  budget? : WritePartBudget,
) -> String raise XlsxError {
  if shape_id_start <= 0 || comments.length() > 0x7fffffff - shape_id_start {
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
  let mut shape_id = shape_id_start
  for comment in comments {
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
    shape_id = shape_id + 1
  }
  sb.write_view("</xml>")
  sb.to_string()
}

///|
priv struct VmlShapeSpan {
  start : Int
  end : Int
}

///|
fn extract_vml_shape_spans(xml : StringView) -> Array[VmlShapeSpan] {
  let spans : Array[VmlShapeSpan] = []
  let needle = "<v:shape"
  let mut start_pos = 0
  while start_pos < xml.length() {
    let rest = xml[start_pos:]
    let rel = match rest.find(needle) {
      Some(pos) => pos
      None => break
    }
    let start = start_pos + rel
    let after = start + needle.length()
    let next_char = if after < xml.length() {
      xml.get_char(after)
    } else {
      None
    }
    let is_shape = match next_char {
      Some(' ') | Some('>') | Some('/') => true
      _ => false
    }
    if !is_shape {
      start_pos = start + 1
      continue
    }
    let shape_rest = xml[start:]
    let end_rel = match shape_rest.find("</v:shape>") {
      Some(pos) => pos
      None => break
    }
    let end = start + end_rel + "</v:shape>".length()
    spans.push({ start, end })
    start_pos = end
  }
  spans
}

///|
fn extract_vml_shapetype(xml : StringView) -> StringView? {
  let start = match xml.find("<v:shapetype") {
    Some(pos) => pos
    None => return None
  }
  let tail = xml[start:]
  let end = match tail.find("</v:shapetype>") {
    Some(pos) => start + pos + "</v:shapetype>".length()
    None => return None
  }
  Some(xml[start:end])
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
fn vml_shape_id(shape_xml : StringView) -> StringView? {
  let id_key = "id=\""
  let start = match shape_xml.find(id_key) {
    Some(pos) => pos + id_key.length()
    None => return None
  }
  let rest = shape_xml[start:]
  let end_rel = match rest.find("\"") {
    Some(pos) => pos
    None => return None
  }
  let end = start + end_rel
  Some(shape_xml[start:end])
}

///|
fn vml_shape_is_comment(shape_xml : StringView) -> Bool raise XlsxError {
  let client_data = "<x:ClientData"
  let start = match shape_xml.find(client_data) {
    Some(pos) => pos + client_data.length()
    None => return false
  }
  let rest = shape_xml[start:]
  let end = match rest.find(">") {
    Some(pos) => pos
    None => raise InvalidXml(msg="VML ClientData tag not closed")
  }
  attr_value(rest[:end], "ObjectType") == Some("Note")
}

///|
fn vml_comment_cell(shape_xml : StringView) -> String? raise XlsxError {
  if !vml_shape_is_comment(shape_xml) {
    return None
  }
  let client_data = "<x:ClientData"
  let start = shape_xml.find(client_data).unwrap() + client_data.length()
  let rest = shape_xml[start:]
  let open_end = match rest.find(">") {
    Some(pos) => pos
    None => raise InvalidVmlDrawing(msg="comment VML ClientData tag not closed")
  }
  let body = rest[open_end + 1:]
  let row_text = match extract_xml_text_tag(body, "x:Row") {
    Some(value) => value
    None => raise InvalidVmlDrawing(msg="comment VML row is missing")
  }
  let col_text = match extract_xml_text_tag(body, "x:Column") {
    Some(value) => value
    None => raise InvalidVmlDrawing(msg="comment VML column is missing")
  }
  let row0 = @string.parse_int(row_text.trim(), base=10) catch {
    _ => raise InvalidVmlDrawing(msg="comment VML row is invalid")
  }
  let col0 = @string.parse_int(col_text.trim(), base=10) catch {
    _ => raise InvalidVmlDrawing(msg="comment VML column is invalid")
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
fn vml_shape_numeric_id(shape_xml : StringView) -> Int? {
  let prefix = "_x0000_s"
  match vml_shape_id(shape_xml) {
    Some(id) =>
      if !id.has_prefix(prefix) {
        None
      } else {
        try @string.parse_int(id[prefix.length():], base=10) catch {
          _ => None
        } noraise {
          value => if value > 0 { Some(value) } else { None }
        }
      }
    None => None
  }
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
  let mut max_shape_id = 1024
  for span in extract_vml_shape_spans(base_xml) {
    let shape = base_xml[span.start:span.end]
    match vml_shape_numeric_id(shape) {
      Some(id) => if id > max_shape_id { max_shape_id = id }
      None => ()
    }
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
  if max_shape_id >= 0x7fffffff {
    raise InvalidVmlDrawing(msg="comment VML shape id space is exhausted")
  }
  (remove_vml_shape_spans(base_xml, remove, budget?), missing, max_shape_id + 1)
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
  let shapes = extract_vml_shapes(base_xml)
  let kept : Array[StringView] = []
  for shape in shapes {
    match vml_shape_id(shape) {
      Some(id) =>
        if remove_map.contains(id.to_owned()) {
          continue
        } else {
          kept.push(shape)
        }
      None => kept.push(shape)
    }
  }
  let insert_at = base_xml.find("<v:shape").unwrap_or(base_xml.length())
  let end = base_xml.find("</xml>").unwrap_or(base_xml.length())
  let prefix = base_xml.unsafe_substring(start=0, end=insert_at)
  let suffix = base_xml.unsafe_substring(start=end, end=base_xml.length())
  let sb = LimitedXmlBuilder::new(budget)
  sb.write_view(prefix)
  for shape in kept {
    sb.write_view(shape)
  }
  sb.write_view(suffix)
  sb.to_string()
}

///|
fn merge_vml_drawings(
  base_xml : String,
  comment_xml : String,
  budget? : WritePartBudget,
) -> String raise XlsxError {
  if !base_xml.contains("</xml>") {
    return comment_xml
  }
  let shape_type = if !base_xml.contains("_x0000_t202") {
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
  let end = base_xml.find("</xml>").unwrap_or(base_xml.length())
  let shape_type_at = match shape_type {
    Some(_) => base_xml.find("<v:shape").unwrap_or(end)
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
  if !base_xml.contains("</xml>") {
    return extra_xml
  }
  let shape_token = "id=\"\{shape_type_id.to_owned()}\""
  let shape_type = if !base_xml.contains(shape_token) {
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
  let end = base_xml.find("</xml>").unwrap_or(base_xml.length())
  let shape_type_at = match shape_type {
    Some(_) => base_xml.find("<v:shape").unwrap_or(end)
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
    Some(id) => inspect(id.to_owned(), content="_x0000_s1025")
    None => fail("expected VML shape id")
  }
  inspect(extract_vml_shapes("<xml><v:shape").length(), content="0")
  inspect(extract_vml_shapes("<xml><v:shape id=\"x\">").length(), content="0")
  debug_inspect(vml_shape_id("<v:shape id=\"x></v:shape>"), content="None")
  debug_inspect(vml_shape_id("<v:shape></v:shape>"), content="None")
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
  let (reconciled, missing, next_shape_id) = reconcile_vml_comment_shapes(
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
  inspect(next_shape_id, content="2049")
  let generated_missing = write_comments_vml(
    1,
    missing,
    shape_id_start=next_shape_id,
  )
  inspect(generated_missing.contains("_x0000_s2049"), content="true")
  inspect(generated_missing.contains("<x:Row>1</x:Row>"), content="true")
  inspect(generated_missing.contains("<x:Column>1</x:Column>"), content="true")
  let without_a1 = remove_vml_comment_shapes_at_cell(reconciled, "A1")
  inspect(without_a1.contains("_x0000_s1026"), content="false")
  inspect(without_a1.contains("_x0000_s2048"), content="true")
  inspect(without_a1.contains("<meta keep=\"true\"/>"), content="true")
  inspect(without_a1.contains("<tail keep=\"true\"/>"), content="true")

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
