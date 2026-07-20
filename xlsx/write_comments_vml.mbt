///|
fn truncate_comment_content(comment : Comment) -> (String, Array[RichTextRun]) {
  let mut remaining = max_cell_chars
  let mut text = comment.text
  if text != "" {
    let units = count_utf16_units(text)
    if units > remaining {
      text = truncate_utf16_units(text, remaining)
      remaining = 0
    } else {
      remaining = remaining - units
    }
  }
  let runs = rich_text_truncate_runs(comment.paragraph, remaining)
  (text, runs)
}

///|
fn write_comments_xml(
  comments : ArrayView[Comment],
  budget? : WritePartBudget,
) -> String raise XlsxError {
  let authors : Array[String] = []
  let author_ids : Map[String, Int] = Map([])
  for comment in comments {
    let base_author = if comment.author == "" {
      "Author"
    } else {
      comment.author
    }
    let author = if count_utf16_units(base_author) > max_comment_author_chars {
      truncate_utf16_units(base_author, max_comment_author_chars)
    } else {
      base_author
    }
    if !author_ids.contains(author) {
      author_ids[author] = authors.length()
      authors.push(author)
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
  for comment in comments {
    let base_author = if comment.author == "" {
      "Author"
    } else {
      comment.author
    }
    let author = if count_utf16_units(base_author) > max_comment_author_chars {
      truncate_utf16_units(base_author, max_comment_author_chars)
    } else {
      base_author
    }
    let author_id = author_ids.get(author).unwrap_or(0)
    let (text_value, runs) = truncate_comment_content(comment)
    sb.write_view("    <comment ref=\"")
    sb.write_xml_attr(comment.cell)
    sb.write_view("\" authorId=\"\{author_id}\">\n")
    sb.write_view("      <text>")
    if text_value != "" {
      sb.write_t_element(text_value)
    }
    for run in runs {
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
    "  <v:shapetype id=\"_x0000_t202\" coordsize=\"21600,21600\" o:spt=\"202\" path=\"m0,0l0,21600,21600,21600,21600,0xe\">\n",
  )
  sb.write_view("    <v:stroke joinstyle=\"miter\"/>\n")
  sb.write_view("    <v:path o:connecttype=\"rect\"/>\n")
  sb.write_view("  </v:shapetype>\n")
  let mut shape_id = 1025
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
    shapes.push(xml[start:end])
    start_pos = end
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
  let long_author = "A".repeat(max_comment_author_chars + 5)
  let long_text = "B".repeat(max_cell_chars + 10)
  let comments : ReadOnlyArray[Comment] = [
    wb_comment("A1", "", " lead\n", [
      { text: "Rich", font: Some(rich_font) },
      { text: "Theme", font: Some(theme_font) },
      { text: "Indexed", font: Some(indexed_font) },
      { text: "ThemeTint", font: Some(theme_tint_font) },
      { text: "IndexedNoTint", font: Some(indexed_no_tint_font) },
      { text: "TintOnly", font: Some(tint_only_font) },
    ]),
    wb_comment("B2", long_author, long_text, []),
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
