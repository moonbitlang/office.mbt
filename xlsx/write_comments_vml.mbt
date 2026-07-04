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
fn write_comments_xml(comments : ArrayView[Comment]) -> String {
  fn write_rich_text_color(sb : StringBuilder, font : RichTextFont) -> Unit {
    let tint = match font.color_tint {
      Some(v) => if v == 0.0 { None } else { Some(v) }
      None => None
    }
    match font.color_theme {
      Some(value) => {
        sb.write_view("<color theme=\"\{value}\"")
        match tint {
          Some(v) => sb.write_view(" tint=\"\{v}\"")
          None => ()
        }
        sb.write_view("/>")
        return
      }
      None => ()
    }
    match font.color_indexed {
      Some(value) => {
        sb.write_view("<color indexed=\"\{value}\"")
        match tint {
          Some(v) => sb.write_view(" tint=\"\{v}\"")
          None => ()
        }
        sb.write_view("/>")
        return
      }
      None => ()
    }
    match font.color {
      Some(color) => {
        let normalized = color.replace_all(old="#", new="")
        let rgb = if normalized.length() == 6 {
          "FF" + normalized
        } else {
          normalized
        }
        sb.write_view("<color rgb=\"\{escape_xml_attr(rgb)}\"")
        match tint {
          Some(v) => sb.write_view(" tint=\"\{v}\"")
          None => ()
        }
        sb.write_view("/>")
      }
      None => ()
    }
  }

  let authors : Array[String] = []
  let author_ids : Map[String, Int] = {}
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
  let sb = StringBuilder::new()
  sb.write_view("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n")
  sb.write_view(
    "<comments xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\">\n",
  )
  sb.write_view("  <authors>\n")
  for author in authors {
    sb.write_view("    <author>")
    sb.write_view(escape_xml_text(author))
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
    sb.write_view(escape_xml_attr(comment.cell))
    sb.write_view("\" authorId=\"\{author_id}\">\n")
    sb.write_view("      <text>")
    if text_value != "" {
      if text_value.has_prefix(" ") ||
        text_value.has_suffix(" ") ||
        text_value.contains("\n") {
        sb.write_view("<t xml:space=\"preserve\">")
      } else {
        sb.write_view("<t>")
      }
      sb.write_view(escape_xml_text(text_value))
      sb.write_view("</t>")
    }
    for run in runs {
      sb.write_view("<r>")
      match run.font {
        Some(font) => {
          sb.write_view("<rPr>")
          if font.bold {
            sb.write_view("<b/>")
          }
          if font.italic {
            sb.write_view("<i/>")
          }
          if font.strike {
            sb.write_view("<strike/>")
          }
          if font.outline {
            sb.write_view("<outline/>")
          }
          if font.shadow {
            sb.write_view("<shadow/>")
          }
          if font.condense {
            sb.write_view("<condense/>")
          }
          if font.extended {
            sb.write_view("<extend/>")
          }
          match font.underline {
            Some(value) =>
              sb.write_view("<u val=\"\{escape_xml_attr(value)}\"/>")
            None => ()
          }
          match font.size {
            Some(size) => sb.write_view("<sz val=\"\{size}\"/>")
            None => ()
          }
          match font.charset {
            Some(value) => sb.write_view("<charset val=\"\{value}\"/>")
            None => ()
          }
          match font.family_number {
            Some(value) => sb.write_view("<family val=\"\{value}\"/>")
            None => ()
          }
          match font.family {
            Some(family) =>
              sb.write_view("<rFont val=\"\{escape_xml_attr(family)}\"/>")
            None => ()
          }
          match font.color {
            Some(_) => write_rich_text_color(sb, font)
            None =>
              if font.color_theme is Some(_) ||
                font.color_indexed is Some(_) ||
                font.color_tint is Some(_) {
                write_rich_text_color(sb, font)
              }
          }
          match font.vert_align {
            Some(value) =>
              sb.write_view("<vertAlign val=\"\{escape_xml_attr(value)}\"/>")
            None => ()
          }
          match font.scheme {
            Some(value) =>
              sb.write_view("<scheme val=\"\{escape_xml_attr(value)}\"/>")
            None => ()
          }
          sb.write_view("</rPr>")
        }
        None => ()
      }
      if run.text.has_prefix(" ") ||
        run.text.has_suffix(" ") ||
        run.text.contains("\n") {
        sb.write_view("<t xml:space=\"preserve\">")
      } else {
        sb.write_view("<t>")
      }
      sb.write_view(escape_xml_text(run.text))
      sb.write_view("</t></r>")
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
) -> String raise XlsxError {
  let sb = StringBuilder::new()
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
fn extract_vml_shapetype(xml : StringView) -> String? {
  let xml_str = xml.to_owned()
  let start = match xml_str.find("<v:shapetype") {
    Some(pos) => pos
    None => return None
  }
  let end = match xml_str.find("</v:shapetype>") {
    Some(pos) => pos + "</v:shapetype>".length()
    None => return None
  }
  let slice = xml_str.unsafe_substring(start~, end~)
  Some(slice.to_string())
}

///|
fn extract_vml_shapes(xml : StringView) -> Array[String] {
  let shapes : Array[String] = []
  let xml_str = xml.to_owned()
  let needle = "<v:shape"
  let mut start_pos = 0
  while start_pos < xml_str.length() {
    let rest = xml_str.unsafe_substring(start=start_pos, end=xml_str.length())
    let rel = match rest.find(needle) {
      Some(pos) => pos
      None => break
    }
    let start = start_pos + rel
    let after = start + needle.length()
    let next_char = if after < xml_str.length() {
      xml_str.get_char(after)
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
    let shape_rest = xml_str.unsafe_substring(start~, end=xml_str.length())
    let end_rel = match shape_rest.find("</v:shape>") {
      Some(pos) => pos
      None => break
    }
    let end = start + end_rel + "</v:shape>".length()
    let slice = xml_str.unsafe_substring(start~, end~)
    shapes.push(slice.to_string())
    start_pos = end
  }
  shapes
}

///|
fn vml_shape_id(shape_xml : StringView) -> String? {
  let xml_str = shape_xml.to_owned()
  let id_key = "id=\""
  let start = match xml_str.find(id_key) {
    Some(pos) => pos + id_key.length()
    None => return None
  }
  let rest = xml_str.unsafe_substring(start~, end=xml_str.length())
  let end_rel = match rest.find("\"") {
    Some(pos) => pos
    None => return None
  }
  let end = start + end_rel
  let slice = xml_str.unsafe_substring(start~, end~)
  Some(slice.to_string())
}

///|
fn filter_vml_shapes_by_id(
  base_xml : String,
  remove_ids : Array[String],
) -> String {
  if remove_ids.length() == 0 {
    return base_xml
  }
  if !base_xml.contains("<v:shape") {
    return base_xml
  }
  let remove_map : Map[String, Bool] = {}
  for id in remove_ids {
    remove_map[id] = true
  }
  let shapes = extract_vml_shapes(base_xml)
  let kept : Array[String] = []
  for shape in shapes {
    match vml_shape_id(shape) {
      Some(id) =>
        if remove_map.contains(id) {
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
  let sb = StringBuilder::new()
  sb.write_view(prefix)
  for shape in kept {
    sb.write_view(shape)
  }
  sb.write_view(suffix)
  sb.to_string()
}

///|
fn merge_vml_drawings(base_xml : String, comment_xml : String) -> String {
  if !base_xml.contains("</xml>") {
    return comment_xml
  }
  let mut merged = base_xml
  if !merged.contains("_x0000_t202") {
    match extract_vml_shapetype(comment_xml) {
      Some(shape_type) => {
        let insert_at = merged
          .find("<v:shape")
          .unwrap_or(merged.find("</xml>").unwrap_or(merged.length()))
        let prefix = merged.unsafe_substring(start=0, end=insert_at)
        let suffix = merged.unsafe_substring(
          start=insert_at,
          end=merged.length(),
        )
        let sb = StringBuilder::new()
        sb.write_view(prefix)
        sb.write_view(shape_type)
        sb.write_view(suffix)
        merged = sb.to_string()
      }
      None => ()
    }
  }
  let shapes = extract_vml_shapes(comment_xml)
  if shapes.length() == 0 {
    return merged
  }
  let insert_at = merged.find("</xml>").unwrap_or(merged.length())
  let prefix = merged.unsafe_substring(start=0, end=insert_at)
  let suffix = merged.unsafe_substring(start=insert_at, end=merged.length())
  let sb = StringBuilder::new()
  sb.write_view(prefix)
  for shape in shapes {
    sb.write_view(shape)
  }
  sb.write_view(suffix)
  sb.to_string()
}

///|
fn merge_vml_drawings_with_shapetype(
  base_xml : String,
  extra_xml : String,
  shape_type_id : StringView,
) -> String {
  if !base_xml.contains("</xml>") {
    return extra_xml
  }
  let mut merged = base_xml
  let shape_token = "id=\"\{shape_type_id.to_owned()}\""
  if !merged.contains(shape_token) {
    match extract_vml_shapetype(extra_xml) {
      Some(shape_type) => {
        let insert_at = merged
          .find("<v:shape")
          .unwrap_or(merged.find("</xml>").unwrap_or(merged.length()))
        let prefix = merged.unsafe_substring(start=0, end=insert_at)
        let suffix = merged.unsafe_substring(
          start=insert_at,
          end=merged.length(),
        )
        let sb = StringBuilder::new()
        sb.write_view(prefix)
        sb.write_view(shape_type)
        sb.write_view(suffix)
        merged = sb.to_string()
      }
      None => ()
    }
  }
  let shapes = extract_vml_shapes(extra_xml)
  if shapes.length() == 0 {
    return merged
  }
  let insert_at = merged.find("</xml>").unwrap_or(merged.length())
  let prefix = merged.unsafe_substring(start=0, end=insert_at)
  let suffix = merged.unsafe_substring(start=insert_at, end=merged.length())
  let sb = StringBuilder::new()
  sb.write_view(prefix)
  for shape in shapes {
    sb.write_view(shape)
  }
  sb.write_view(suffix)
  sb.to_string()
}

///|
fn write_header_footer_vml(
  sheet_id : Int,
  images : ArrayView[HeaderFooterImage],
) -> String {
  let sb = StringBuilder::new()
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
    sb.write_view(escape_xml_attr(shape_name))
    sb.write_view(
      "\" o:spid=\"_x0000_s\{shape_id}\" type=\"#_x0000_t75\" style=\"",
    )
    sb.write_view(escape_xml_attr(style))
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
