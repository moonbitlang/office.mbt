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
    extend: true,
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
    extend: false,
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
    extend: false,
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
    extend: false,
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
    extend: false,
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
    extend: false,
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
  let comments = [
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
  let comments = [wb_comment("C3", "Bob", "note", [])]
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
  debug_inspect(vml_shape_id(shapes[0]), content="Some(\"_x0000_s1025\")")
  inspect(extract_vml_shapes("<xml><v:shape").length(), content="0")
  inspect(extract_vml_shapes("<xml><v:shape id=\"x\">").length(), content="0")
  debug_inspect(vml_shape_id("<v:shape id=\"x></v:shape>"), content="None")
  debug_inspect(vml_shape_id("<v:shape></v:shape>"), content="None")
}

///|
test "write comments vml wb: filter and merge branches" {
  let comments = [
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
